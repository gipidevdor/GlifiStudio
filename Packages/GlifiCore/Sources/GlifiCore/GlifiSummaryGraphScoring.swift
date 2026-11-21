// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Explicit power-iteration and threshold parameters of sentence-graph scoring (GS-MET-001-19).
public struct GlifiSummaryGraphConfiguration: Codable, Equatable, Hashable, Sendable {
    /// Uniform teleportation, damping 0.85, L1 tolerance 1e-12 and at most 1,000 iterations.
    public static let standard = GlifiSummaryGraphConfiguration()
    /// Largest sentence graph accepted before quadratic pair enumeration.
    public static let maximumSentenceCount = 2_048
    /// Bound on `(directed edges + eligible nodes) × maximumIterations` before iteration.
    public static let maximumIterationWork = 100_000_000
    /// PageRank continuation probability in `[0, 1)`.
    public let damping: Double
    /// Positive finite L1 convergence tolerance.
    public let tolerance: Double
    /// Positive iteration bound, at most 10,000.
    public let maximumIterations: Int
    /// Strict cosine threshold in `[0, 1]`, used only by threshold LexRank.
    public let similarityThreshold: Double

    /// Creates declared parameters; the analysis validates them before graph construction.
    public init(
        damping: Double = 0.85, tolerance: Double = 1e-12,
        maximumIterations: Int = 1_000, similarityThreshold: Double = 0.1
    ) {
        self.damping = damping
        self.tolerance = tolerance
        self.maximumIterations = maximumIterations
        self.similarityThreshold = similarityThreshold
    }

    /// Whether every parameter is finite and inside its declared domain.
    public var isValid: Bool {
        damping.isFinite && damping >= 0 && damping < 1
            && tolerance.isFinite && tolerance > 0
            && maximumIterations > 0 && maximumIterations <= 10_000
            && similarityThreshold.isFinite && similarityThreshold >= 0 && similarityThreshold <= 1
    }
}

/// Persisted graph provenance and convergence, separate from sentence salience.
public struct GlifiSummaryGraphDiagnostics: Codable, Equatable, Sendable {
    /// Resolved parameters, including defaults.
    public let configuration: GlifiSummaryGraphConfiguration
    /// Versioned edge similarity.
    public let similarityIdentifier: String
    /// Centrality identity.
    public let centralityIdentifier: String
    /// Uniform redistribution of dangling mass and uniform teleportation over eligible nodes.
    public let danglingPolicyIdentifier: String
    /// Eligible sentence nodes, including isolated sentences.
    public let nodeCount: Int
    /// Number of undirected positive-weight edges; self-loops are excluded.
    public let edgeCount: Int
    /// Number of power-iteration steps performed.
    public let iterations: Int
    /// Whether the L1 stopping criterion was reached; an empty eligible graph is converged.
    public let converged: Bool
}

struct GlifiSummaryGraphScores {
    let scores: [Double]
    let eligibility: [Bool]
    let diagnostics: GlifiSummaryGraphDiagnostics
}

func summaryGraphScores(
    terms: [[String]], nonNullVectors: [Bool], method: GlifiSummaryScoringMethod,
    configuration: GlifiSummaryGraphConfiguration, cosine: (Int, Int) -> Double
) throws -> GlifiSummaryGraphScores {
    guard method.supportsGraphConfiguration else {
        throw derivedAnalysisFailure("summary.graph-configuration-without-method")
    }
    guard configuration.isValid else {
        throw derivedAnalysisFailure("summary.invalid-graph-configuration")
    }
    guard terms.count <= GlifiSummaryGraphConfiguration.maximumSentenceCount else {
        throw derivedAnalysisFailure(
            "summary.graph-sentence-limit", category: .insufficientResources)
    }
    let eligibility = terms.indices.map { index in
        method == .textRankConfigurable ? !terms[index].isEmpty : nonNullVectors[index]
    }
    let nodes = terms.indices.filter { eligibility[$0] }
    let sets = method == .textRankConfigurable ? terms.map(Set.init) : []
    let logLengths =
        method == .textRankConfigurable ? terms.map { $0.isEmpty ? 0 : log(Double($0.count)) } : []
    // Exact inverted occurrences avoid hashing every term for every sentence pair.
    // Each sentence contributes a term once; overlap counts remain integers and the
    // subsequent pair traversal retains the original edge and arithmetic order.
    var occurrences: [String: [Int]] = [:]
    var processedTerms = 0
    if method == .textRankConfigurable {
        for node in nodes {
            try Task.checkCancellation()
            for term in sets[node] {
                if processedTerms.isMultiple(of: 256) { try Task.checkCancellation() }
                processedTerms += 1
                occurrences[term, default: []].append(node)
            }
        }
    }
    var overlaps = [Int](repeating: 0, count: method == .textRankConfigurable ? terms.count : 0)
    func boundedCosine(_ left: Int, _ right: Int) throws -> Double {
        let value = cosine(left, right)
        guard value.isFinite else {
            throw derivedAnalysisFailure("summary.non-finite-graph-weight")
        }
        return min(1, max(0, value))
    }
    var edges: [GlifiGraphEdge<Int>] = []
    var edgeCount = 0
    for (position, left) in nodes.enumerated() {
        try Task.checkCancellation()
        if method == .textRankConfigurable {
            for term in sets[left] {
                if processedTerms.isMultiple(of: 256) { try Task.checkCancellation() }
                processedTerms += 1
                for right in occurrences[term] ?? [] where right > left { overlaps[right] += 1 }
            }
        }
        for right in nodes.dropFirst(position + 1) {
            let weight: Double
            switch method {
            case .textRankConfigurable:
                let denominator = logLengths[left] + logLengths[right]
                // Two one-token sentences have a zero log-length denominator: no edge is defined.
                weight = denominator > 0 ? Double(overlaps[right]) / denominator : 0
                overlaps[right] = 0
            case .lexRankContinuous:
                weight = try boundedCosine(left, right)
            case .lexRankThreshold:
                weight =
                    try boundedCosine(left, right) > configuration.similarityThreshold ? 1 : 0
            case .sentenceTFIDFMean, .centroidCosine, .lexRank, .textRank:
                throw derivedAnalysisFailure("summary.graph-configuration-without-method")
            }
            guard weight.isFinite, weight >= 0 else {
                throw derivedAnalysisFailure("summary.non-finite-graph-weight")
            }
            if weight > 0 {
                edges.append(GlifiGraphEdge(source: left, target: right, weight: weight))
                edges.append(GlifiGraphEdge(source: right, target: left, weight: weight))
                edgeCount += 1
            }
        }
    }
    var scores = [Double](repeating: 0, count: terms.count)
    var iterations = 0
    var converged = true
    if !nodes.isEmpty {
        guard
            edges.count + nodes.count
                <= GlifiSummaryGraphConfiguration.maximumIterationWork
                / configuration.maximumIterations
        else {
            throw derivedAnalysisFailure(
                "summary.graph-work-limit", category: .insufficientResources)
        }
        let centrality = try GlifiNetworkAnalysis.pageRank(
            GlifiDirectedGraph(nodes: nodes, edges: edges), damping: configuration.damping,
            tolerance: configuration.tolerance, maximumIterations: configuration.maximumIterations)
        for node in nodes { scores[node] = centrality.scores[node] ?? 0 }
        iterations = centrality.iterations
        converged = centrality.converged
    }
    let similarity: String
    switch method {
    case .textRankConfigurable: similarity = "similarity.sentence-overlap-log-length-v1"
    case .lexRankContinuous: similarity = "similarity.sentence-vector-cosine-v1"
    case .lexRankThreshold: similarity = "similarity.sentence-vector-cosine-threshold-binary-v1"
    case .sentenceTFIDFMean, .centroidCosine, .lexRank, .textRank:
        throw derivedAnalysisFailure("summary.graph-configuration-without-method")
    }
    return GlifiSummaryGraphScores(
        scores: scores, eligibility: eligibility,
        diagnostics: GlifiSummaryGraphDiagnostics(
            configuration: configuration, similarityIdentifier: similarity,
            centralityIdentifier: "PageRank-v1", danglingPolicyIdentifier: "dangling.uniform-v1",
            nodeCount: nodes.count, edgeCount: edgeCount, iterations: iterations,
            converged: converged))
}
