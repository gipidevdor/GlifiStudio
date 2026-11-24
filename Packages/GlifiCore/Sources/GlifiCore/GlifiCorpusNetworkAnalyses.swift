// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Bounded parameters of a document-level co-occurrence analysis.
public struct GlifiCooccurrenceOptions: Codable, Equatable, Sendable {
    /// Conservative defaults.
    public static let standard = GlifiCooccurrenceOptions(
        validatedMaximumTermCount: 30,
        minimumJointCount: 1,
        maximumPairCount: 500
    )

    /// Largest number of terms, chosen by document frequency, then frequency.
    public let maximumTermCount: Int
    /// Smallest joint document count for a pair to be retained.
    public let minimumJointCount: Int
    /// Largest number of pairs stored in a collocation result.
    public let maximumPairCount: Int

    /// Creates valid bounds without silently correcting parameters.
    public init(
        maximumTermCount: Int,
        minimumJointCount: Int,
        maximumPairCount: Int
    ) throws {
        guard (2...200).contains(maximumTermCount),
            minimumJointCount >= 1,
            (1...5_000).contains(maximumPairCount)
        else {
            throw derivedAnalysisFailure("cooccurrence.invalid-options")
        }
        self.init(
            validatedMaximumTermCount: maximumTermCount,
            minimumJointCount: minimumJointCount,
            maximumPairCount: maximumPairCount
        )
    }

    private init(
        validatedMaximumTermCount: Int,
        minimumJointCount: Int,
        maximumPairCount: Int
    ) {
        maximumTermCount = validatedMaximumTermCount
        self.minimumJointCount = minimumJointCount
        self.maximumPairCount = maximumPairCount
    }

    /// Decodes only valid bounds.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            maximumTermCount: container.decode(Int.self, forKey: .maximumTermCount),
            minimumJointCount: container.decode(Int.self, forKey: .minimumJointCount),
            maximumPairCount: container.decode(Int.self, forKey: .maximumPairCount)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case maximumTermCount, minimumJointCount, maximumPairCount
    }
}

/// Document-presence co-occurrence over the most widespread terms.
struct GlifiDocumentCooccurrence {
    struct Pair {
        let firstIndex: Int
        let secondIndex: Int
        let counts: GlifiCooccurrenceCounts
    }

    let terms: [String]
    let documentCount: Int
    let pairs: [Pair]
    let evaluatedPairCount: Int

    init(_ analysis: GlifiCorpusAnalysis, options: GlifiCooccurrenceOptions) throws {
        let counts = GlifiDocumentTermCounts(analysis)
        guard counts.documentIDs.count >= 2 else {
            throw derivedAnalysisFailure(
                "cooccurrence.insufficient-documents",
                category: .insufficientData
            )
        }
        let selected = analysis.terms.sorted {
            if $0.documentFrequency != $1.documentFrequency {
                return $0.documentFrequency > $1.documentFrequency
            }
            if $0.frequency != $1.frequency { return $0.frequency > $1.frequency }
            return $0.term < $1.term
        }.prefix(options.maximumTermCount).map(\.term).sorted()
        guard selected.count >= 2 else {
            throw derivedAnalysisFailure(
                "cooccurrence.insufficient-terms",
                category: .insufficientData
            )
        }
        let columnByTerm = Dictionary(
            uniqueKeysWithValues: counts.terms.enumerated().map { ($1, $0) }
        )
        let presence: [Set<Int>] = selected.map { term in
            guard let column = columnByTerm[term] else { return [] }
            return Set(counts.rows.indices.filter { counts.rows[$0][column] != nil })
        }
        let universe = counts.documentIDs.count
        var pairs: [Pair] = []
        var evaluated = 0
        for first in selected.indices {
            for second in selected.indices where second > first {
                evaluated += 1
                let joint = presence[first].intersection(presence[second]).count
                guard joint >= options.minimumJointCount else { continue }
                let firstOnly = presence[first].count - joint
                let secondOnly = presence[second].count - joint
                pairs.append(
                    Pair(
                        firstIndex: first,
                        secondIndex: second,
                        counts: try GlifiCooccurrenceCounts(
                            jointCount: joint,
                            firstOnlyCount: firstOnly,
                            secondOnlyCount: secondOnly,
                            neitherCount: universe - joint - firstOnly - secondOnly
                        )
                    )
                )
            }
        }
        terms = selected
        documentCount = universe
        self.pairs = pairs
        evaluatedPairCount = evaluated
    }
}

// MARK: - Collocations

/// One term pair with its 2×2 document-presence table and measures.
public struct GlifiCorpusCollocationPair: Codable, Equatable, Sendable {
    /// Lexicographically first term.
    public let firstTerm: String
    /// Lexicographically second term.
    public let secondTerm: String
    /// Documents with both terms (`a`).
    public let jointCount: Int
    /// Documents with the first term only (`b`).
    public let firstOnlyCount: Int
    /// Documents with the second term only (`c`).
    public let secondOnlyCount: Int
    /// Documents with neither term (`d`).
    public let neitherCount: Int
    /// `PMI-v1`.
    public let pmi: Double?
    /// `NPMI-v1`.
    public let npmi: Double?
    /// `Dice-v1`.
    public let dice: Double?
    /// `Jaccard-v1`.
    public let jaccard: Double?
    /// `t-score-v1`.
    public let tScore: Double?
    /// `logDice-v1`.
    public let logDice: Double?
}

/// Collocation measures over document-presence co-occurrence.
public struct GlifiCorpusCollocationAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-collocation.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-document-collocation-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Context definition: presence of a term in a document.
    public let contextIdentifier: String
    /// Universe `M` of opportunities: the number of documents.
    public let universeSize: Int
    /// Bounds applied to term and pair selection.
    public let options: GlifiCooccurrenceOptions
    /// Selected terms in lexicographic order.
    public let selectedTerms: [String]
    /// Pairs evaluated before applying the joint-count threshold.
    public let evaluatedPairCount: Int
    /// Whether retained pairs exceeded `options.maximumPairCount`.
    public let isTruncated: Bool
    /// Retained pairs ordered by joint count, then `logDice-v1`, then terms.
    public let pairs: [GlifiCorpusCollocationPair]
}

/// Computes collocation measures from one corpus profile.
public struct GlifiCorpusCollocationAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Analyzes term-pair co-occurrence across the documents of `analysis`.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        options: GlifiCooccurrenceOptions = .standard
    ) throws -> GlifiCorpusCollocationAnalysis {
        try Task.checkCancellation()
        let cooccurrence = try GlifiDocumentCooccurrence(analysis, options: options)
        var rows = cooccurrence.pairs.map { pair -> GlifiCorpusCollocationPair in
            let measures = GlifiCollocationAnalysis.measures(pair.counts)
            return GlifiCorpusCollocationPair(
                firstTerm: cooccurrence.terms[pair.firstIndex],
                secondTerm: cooccurrence.terms[pair.secondIndex],
                jointCount: pair.counts.jointCount,
                firstOnlyCount: pair.counts.firstOnlyCount,
                secondOnlyCount: pair.counts.secondOnlyCount,
                neitherCount: pair.counts.neitherCount,
                pmi: measures.pmi,
                npmi: measures.npmi,
                dice: measures.dice,
                jaccard: measures.jaccard,
                tScore: measures.tScore,
                logDice: measures.logDice
            )
        }
        rows.sort {
            if $0.jointCount != $1.jointCount { return $0.jointCount > $1.jointCount }
            let left = $0.logDice ?? -.infinity
            let right = $1.logDice ?? -.infinity
            if left != right { return left > right }
            if $0.firstTerm != $1.firstTerm { return $0.firstTerm < $1.firstTerm }
            return $0.secondTerm < $1.secondTerm
        }
        let truncated = rows.count > options.maximumPairCount
        return GlifiCorpusCollocationAnalysis(
            analysisIdentifier: GlifiCorpusCollocationAnalysis.analysisIdentifier,
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: analysis.matrix.rowSourceRevisionIDs.map(\.canonicalValue),
            contextIdentifier: "document-presence-v1",
            universeSize: cooccurrence.documentCount,
            options: options,
            selectedTerms: cooccurrence.terms,
            evaluatedPairCount: cooccurrence.evaluatedPairCount,
            isTruncated: truncated,
            pairs: Array(rows.prefix(options.maximumPairCount))
        )
    }
}

// MARK: - Lexical network

/// Centrality values of one term node.
public struct GlifiCorpusNetworkNode: Codable, Equatable, Sendable {
    /// Normalized lexical form.
    public let term: String
    /// `Degree-v1`: number of neighboring terms.
    public let degree: Int
    /// `WeightedDegree-v1`: sum of joint document counts.
    public let weightedDegree: Double
    /// `PageRank-v1` score.
    public let pageRank: Double
    /// Raw `Betweenness-v1` over the symmetric directed graph.
    public let betweenness: Double
    /// `HarmonicCloseness-v1`.
    public let harmonicCloseness: Double
    /// `WeightedBetweenness-v1` with `inverse-weight-distance-v1`.
    public let weightedBetweenness: Double
    /// `WeightedHarmonicCloseness-v1` with `inverse-weight-distance-v1`.
    public let weightedHarmonicCloseness: Double
    /// `EigenvectorCentrality-v1`, scaled to max 1.
    public let eigenvector: Double
    /// `WeakComponents-v1` index.
    public let weakComponent: Int
    /// `StrongComponents-v1` index.
    public let strongComponent: Int
    /// `Louvain-v1` community index.
    public let community: Int
}

/// One network edge with its weight and lineage.
public struct GlifiCorpusNetworkEdge: Codable, Equatable, Sendable {
    /// Source term.
    public let source: String
    /// Target term.
    public let target: String
    /// Edge weight used by the centralities.
    public let weight: Double
    /// Joint count supporting the edge.
    public let jointCount: Int
    /// `logDice-v1` of the supporting pair.
    public let logDice: Double?
    /// Documents containing both terms (document context), in canonical order.
    public let supportingSourceRevisionIDs: [String]
    /// First source positions supporting the edge (window context).
    public let occurrences: [GlifiWindowOccurrence]
}

/// Graph-level summary shared by lexical networks.
public struct GlifiNetworkSummary: Codable, Equatable, Sendable {
    /// Number of nodes.
    public let nodeCount: Int
    /// Number of edges (undirected pairs for symmetric graphs).
    public let edgeCount: Int
    /// Number of weak components.
    public let weakComponentCount: Int
    /// Number of strong components.
    public let strongComponentCount: Int
    /// Number of Louvain communities, `nil` when undefined.
    public let communityCount: Int?
    /// Modularity of the Louvain partition, `nil` when undefined.
    public let modularity: Double?
    /// Principal eigenvalue of the weighted adjacency, `nil` when undefined.
    public let eigenvalue: Double?
    /// `PageRank-v1` damping.
    public let pageRankDamping: Double
    /// Whether `PageRank-v1` converged within its iteration bound.
    public let pageRankConverged: Bool
    /// Whether the eigenvector iteration converged.
    public let eigenvectorConverged: Bool
}

/// Computes every node measure and graph summary of a lexical network.
enum GlifiLexicalNetworkMeasures {
    static func compute(
        nodes terms: [String],
        edges: [(source: String, target: String, weight: Double)],
        symmetric: Bool
    ) throws -> (nodes: [GlifiCorpusNetworkNode], summary: GlifiNetworkSummary) {
        var graphEdges: [GlifiGraphEdge<String>] = []
        for edge in edges {
            graphEdges.append(
                GlifiGraphEdge(source: edge.source, target: edge.target, weight: edge.weight))
            if symmetric {
                graphEdges.append(
                    GlifiGraphEdge(source: edge.target, target: edge.source, weight: edge.weight)
                )
            }
        }
        let graph = try GlifiDirectedGraph(nodes: terms, edges: graphEdges)
        let degrees = GlifiNetworkAnalysis.degree(graph)
        let pageRank = try GlifiNetworkAnalysis.pageRank(graph)
        try Task.checkCancellation()
        let betweenness = GlifiNetworkAnalysis.betweenness(graph)
        let closeness = GlifiNetworkAnalysis.harmonicCloseness(graph)
        let weightedBetweenness = GlifiNetworkAnalysis.weightedBetweenness(graph)
        let weightedCloseness = GlifiNetworkAnalysis.weightedHarmonicCloseness(graph)
        let eigenvector = try? GlifiNetworkAnalysis.eigenvectorCentrality(graph)
        let weak = GlifiNetworkAnalysis.weakComponents(graph)
        let strong = GlifiNetworkAnalysis.strongComponents(graph)
        let communities = try? GlifiNetworkAnalysis.louvain(graph)
        var nodes = terms.map { term in
            GlifiCorpusNetworkNode(
                term: term,
                degree: degrees.outDegree[term] ?? 0,
                weightedDegree: degrees.weightedOutDegree[term] ?? 0,
                pageRank: pageRank.scores[term] ?? 0,
                betweenness: betweenness.scores[term] ?? 0,
                harmonicCloseness: closeness.scores[term] ?? 0,
                weightedBetweenness: weightedBetweenness.scores[term] ?? 0,
                weightedHarmonicCloseness: weightedCloseness.scores[term] ?? 0,
                eigenvector: eigenvector?.scores[term] ?? 0,
                weakComponent: weak.componentByNode[term] ?? 0,
                strongComponent: strong.componentByNode[term] ?? 0,
                community: communities?.communityByNode[term] ?? 0
            )
        }
        nodes.sort {
            $0.pageRank == $1.pageRank ? $0.term < $1.term : $0.pageRank > $1.pageRank
        }
        return (
            nodes,
            GlifiNetworkSummary(
                nodeCount: terms.count,
                edgeCount: edges.count,
                weakComponentCount: weak.componentCount,
                strongComponentCount: strong.componentCount,
                communityCount: communities?.communityCount,
                modularity: communities?.modularity,
                eigenvalue: eigenvector?.eigenvalue,
                pageRankDamping: 0.85,
                pageRankConverged: pageRank.converged,
                eigenvectorConverged: eigenvector?.converged ?? false
            )
        )
    }
}

/// Centrality of the term co-occurrence network.
public struct GlifiCorpusLexicalNetworkAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-lexical-network.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-document-cooccurrence-network-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Context definition: presence of a term in a document.
    public let contextIdentifier: String
    /// Graph construction: each undirected pair becomes two opposite edges.
    public let graphIdentifier: String
    /// Bounds applied to term and pair selection.
    public let options: GlifiCooccurrenceOptions
    /// Number of undirected edges (retained pairs).
    public let edgeCount: Int
    /// `PageRank-v1` damping.
    public let pageRankDamping: Double
    /// Whether `PageRank-v1` converged within its iteration bound.
    public let pageRankConverged: Bool
    /// Graph-level components, communities and eigenvalue.
    public let summary: GlifiNetworkSummary
    /// Nodes ordered by PageRank, then term.
    public let nodes: [GlifiCorpusNetworkNode]
    /// Edges with the documents supporting them.
    public let edges: [GlifiCorpusNetworkEdge]
}

/// Computes the term co-occurrence network from one corpus profile.
public struct GlifiCorpusLexicalNetworkAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Builds the network and computes degree, PageRank, betweenness and closeness.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        options: GlifiCooccurrenceOptions = .standard
    ) throws -> GlifiCorpusLexicalNetworkAnalysis {
        try Task.checkCancellation()
        let cooccurrence = try GlifiDocumentCooccurrence(analysis, options: options)
        let counts = GlifiDocumentTermCounts(analysis)
        let columnByTerm = Dictionary(
            uniqueKeysWithValues: counts.terms.enumerated().map { ($1, $0) }
        )
        var networkEdges: [GlifiCorpusNetworkEdge] = []
        for pair in cooccurrence.pairs {
            let first = cooccurrence.terms[pair.firstIndex]
            let second = cooccurrence.terms[pair.secondIndex]
            let supporting = counts.rows.indices.filter { row in
                guard let left = columnByTerm[first], let right = columnByTerm[second] else {
                    return false
                }
                return counts.rows[row][left] != nil && counts.rows[row][right] != nil
            }.map { counts.documentIDs[$0].canonicalValue }
            networkEdges.append(
                GlifiCorpusNetworkEdge(
                    source: first,
                    target: second,
                    weight: Double(pair.counts.jointCount),
                    jointCount: pair.counts.jointCount,
                    logDice: GlifiCollocationAnalysis.measures(pair.counts).logDice,
                    supportingSourceRevisionIDs: supporting,
                    occurrences: []
                )
            )
        }
        let measures = try GlifiLexicalNetworkMeasures.compute(
            nodes: cooccurrence.terms,
            edges: networkEdges.map { ($0.source, $0.target, $0.weight) },
            symmetric: true
        )
        return GlifiCorpusLexicalNetworkAnalysis(
            analysisIdentifier: GlifiCorpusLexicalNetworkAnalysis.analysisIdentifier,
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: analysis.matrix.rowSourceRevisionIDs.map(\.canonicalValue),
            contextIdentifier: "document-presence-v1",
            graphIdentifier: "symmetric-directed-pairs-weighted-by-joint-count-v1",
            options: options,
            edgeCount: cooccurrence.pairs.count,
            pageRankDamping: 0.85,
            pageRankConverged: measures.summary.pageRankConverged,
            summary: measures.summary,
            nodes: measures.nodes,
            edges: networkEdges
        )
    }
}

// MARK: - Window network

/// Declared thresholds of a token-window network.
public struct GlifiWindowNetworkOptions: Codable, Equatable, Sendable {
    /// Defaults: standard window, edges weighted by joint count, no logDice threshold.
    public static let standard = GlifiWindowNetworkOptions(
        window: .standard,
        minimumLogDice: nil,
        usesWeightedJointCount: false
    )

    /// Window, joint-count threshold and pair bound.
    public let window: GlifiWindowCooccurrenceOptions
    /// Edges below this `logDice-v1` are dropped after measurement; `nil` keeps all.
    public let minimumLogDice: Double?
    /// Edge weight: distance-weighted joint count instead of the raw joint count.
    public let usesWeightedJointCount: Bool

    /// Creates validated network options.
    public init(
        window: GlifiWindowCooccurrenceOptions,
        minimumLogDice: Double?,
        usesWeightedJointCount: Bool
    ) {
        self.window = window
        self.minimumLogDice = minimumLogDice.flatMap { $0.isFinite ? $0 : nil }
        self.usesWeightedJointCount = usesWeightedJointCount
    }
}

/// Lexical network built from token-window co-occurrences.
public struct GlifiWindowNetworkAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.window-network.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-window-cooccurrence-network-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Graph construction rule.
    public let graphIdentifier: String
    /// Distance used by path-based centralities.
    public let distanceIdentifier: String
    /// Thresholds and window.
    public let options: GlifiWindowNetworkOptions
    /// Retained pairs before the logDice threshold.
    public let candidateEdgeCount: Int
    /// Graph-level components, communities and eigenvalue.
    public let summary: GlifiNetworkSummary
    /// Nodes ordered by PageRank, then term.
    public let nodes: [GlifiCorpusNetworkNode]
    /// Edges with their source positions.
    public let edges: [GlifiCorpusNetworkEdge]
}

/// Builds the window network from imported sources.
public struct GlifiWindowNetworkAnalyzer: Sendable {
    private let tokenizer: any GlifiTokenizing

    /// Creates an analyzer with an injectable versioned linguistic service.
    public init(tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()) {
        self.tokenizer = tokenizer
    }

    /// Builds the network: symmetric windows yield undirected edges, other windows directed.
    public func analyze(
        _ sources: [GlifiImportedText],
        options: GlifiWindowNetworkOptions = .standard
    ) throws -> GlifiWindowNetworkAnalysis {
        let collocations = try GlifiWindowCollocationAnalyzer(tokenizer: tokenizer)
            .analyze(sources, options: options.window)
        let retained = collocations.pairs.filter { pair in
            guard let threshold = options.minimumLogDice else { return true }
            return (pair.logDice ?? -.infinity) >= threshold
        }
        guard !retained.isEmpty else {
            throw derivedAnalysisFailure(
                "window-network.no-edges",
                category: .insufficientData
            )
        }
        let terms = Set(retained.flatMap { [$0.nodeTerm, $0.collocateTerm] }).sorted()
        let edges = retained.map { pair in
            GlifiCorpusNetworkEdge(
                source: pair.nodeTerm,
                target: pair.collocateTerm,
                weight: options.usesWeightedJointCount
                    ? pair.weightedJointCount : Double(pair.jointCount),
                jointCount: pair.jointCount,
                logDice: pair.logDice,
                supportingSourceRevisionIDs: Array(
                    Set(pair.occurrences.map(\.sourceRevisionID))
                ).sorted(),
                occurrences: pair.occurrences
            )
        }
        let measures = try GlifiLexicalNetworkMeasures.compute(
            nodes: terms,
            edges: edges.map { ($0.source, $0.target, $0.weight) },
            symmetric: options.window.isSymmetric
        )
        return GlifiWindowNetworkAnalysis(
            analysisIdentifier: GlifiWindowNetworkAnalysis.analysisIdentifier,
            sourceRevisionIDs: collocations.sourceRevisionIDs,
            graphIdentifier: options.window.isSymmetric
                ? "symmetric-window-undirected-v1" : "directional-window-directed-v1",
            distanceIdentifier: GlifiNetworkAnalysis.inverseWeightDistanceIdentifier,
            options: options,
            candidateEdgeCount: collocations.pairs.count,
            summary: measures.summary,
            nodes: measures.nodes,
            edges: edges
        )
    }
}
