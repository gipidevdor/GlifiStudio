// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Transport-safe weighted arc; each algorithm declares whether weight is strength or cost.
public struct GlifiStudioGraphArc: Codable, Equatable, Sendable {
    /// Source node label; the graph validates that it belongs to the declared node set.
    public let source: String
    /// Target node label; direction handling is declared by the selected algorithm.
    public let target: String
    /// Finite nonnegative strength for communities or cost for Prim; omitted JSON defaults to one.
    public let weight: Double

    /// Creates an arc; the native graph validates its endpoints and nonnegative finite weight.
    public init(source: String, target: String, weight: Double = 1) {
        self.source = source
        self.target = target
        self.weight = weight
    }

    /// Decodes only declared graph fields, rejecting unknown keys and explicit null values.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: TextAnalysisKey.self)
        let allowed: Set<String> = ["source", "target", "weight"]
        guard values.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
        source = try values.decode(String.self, forKey: TextAnalysisKey("source"))
        target = try values.decode(String.self, forKey: TextAnalysisKey("target"))
        weight = try values.decode(Double.self, forKey: TextAnalysisKey("weight"), fallback: 1)
    }
}

/// Explicit node order defines deterministic tie breaks; Core validates uniqueness and arcs.
public struct GlifiStudioGraphInput: Codable, Equatable, Sendable {
    /// Input node identities in declared order, defining all aligned result arrays.
    public let nodes: [String]
    /// Declared weighted arcs; algorithms validate endpoints and specify their projection.
    public let edges: [GlifiStudioGraphArc]

    /// Preserves explicit node order and arcs; native admission validates identities and budgets.
    public init(nodes: [String], edges: [GlifiStudioGraphArc]) {
        self.nodes = nodes
        self.edges = edges
    }

    /// Decodes only declared graph fields, rejecting unknown keys and explicit null values.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: TextAnalysisKey.self)
        let allowed: Set<String> = ["nodes", "edges"]
        guard values.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
        nodes = try values.decode([String].self, forKey: TextAnalysisKey("nodes"))
        edges = try values.decode([GlifiStudioGraphArc].self, forKey: TextAnalysisKey("edges"))
    }

    fileprivate func core(limits: GlifiStudioGraphAlgorithmLimits) throws -> GlifiDirectedGraph<
        String
    > {
        guard limits.maximumNodeCount >= 0, limits.maximumEdgeCount >= 0,
            limits.maximumPairwiseCells >= 0, limits.maximumWork >= 0
        else { throw graphPresentationInputFailure("network.invalid-limits", .invalidInput) }
        guard nodes.count <= limits.maximumNodeCount, edges.count <= limits.maximumEdgeCount else {
            throw graphPresentationInputFailure("network.resource-limit", .insufficientResources)
        }
        try Task.checkCancellation()
        return try GlifiDirectedGraph(
            nodes: nodes,
            edges: edges.map {
                GlifiGraphEdge(source: $0.source, target: $0.target, weight: $0.weight)
            })
    }
}

/// Transport-safe resource budgets, checked before native graph allocation or work.
public struct GlifiStudioGraphAlgorithmLimits: Codable, Equatable, Sendable {
    /// Defaults: 2,000 nodes, 100,000 arcs, 1,000,000 pairwise cells and 200,000,000 work units.
    public static let standard = GlifiStudioGraphAlgorithmLimits()
    /// Maximum input nodes, checked before graph-index allocation.
    public let maximumNodeCount: Int
    /// Maximum input arcs, including loops and repeated arcs, before projection.
    public let maximumEdgeCount: Int
    /// Maximum admitted scalar cells across the inherent quadratic working buffers.
    public let maximumPairwiseCells: Int
    /// Maximum conservative operation-count estimate admitted before iterative work.
    public let maximumWork: Int

    /// Creates explicit budgets; negative values fail at operation admission rather than being corrected.
    public init(
        maximumNodeCount: Int = 2_000, maximumEdgeCount: Int = 100_000,
        maximumPairwiseCells: Int = 1_000_000, maximumWork: Int = 200_000_000
    ) {
        self.maximumNodeCount = maximumNodeCount
        self.maximumEdgeCount = maximumEdgeCount
        self.maximumPairwiseCells = maximumPairwiseCells
        self.maximumWork = maximumWork
    }

    fileprivate var core: GlifiGraphAlgorithmLimits {
        GlifiGraphAlgorithmLimits(
            maximumNodeCount: maximumNodeCount, maximumEdgeCount: maximumEdgeCount,
            maximumPairwiseCells: maximumPairwiseCells, maximumWork: maximumWork)
    }
}

/// Selectable native community algorithms; each result records its versioned contract.
public enum GlifiStudioGraphCommunityMethod: String, Codable, CaseIterable, Sendable {
    /// Divisive inverse-strength shortest-path edge betweenness.
    case edgeBetweenness
    /// Sparse Clauset-Newman-Moore modularity agglomeration.
    case fastGreedy
    /// Weighted random-walk Ward agglomeration with mean-strength self-loops.
    case walktrap

    fileprivate var core: GlifiCommunityMethod {
        switch self {
        case .edgeBetweenness: .edgeBetweenness
        case .fastGreedy: .fastGreedy
        case .walktrap: .walktrap
        }
    }
}

/// Selectable native two-dimensional layouts with explicit stopping diagnostics.
public enum GlifiStudioGraphLayoutMethod: String, Codable, CaseIterable, Sendable {
    /// Exact pairwise FR forces with linear cooling inside [-1,1] squared.
    case fruchtermanReingold
    /// Hop-distance spring energy with monotone Newton backtracking.
    case kamadaKawai

    fileprivate var core: GlifiGraphLayoutMethod {
        switch self {
        case .fruchtermanReingold: .fruchtermanReingold
        case .kamadaKawai: .kamadaKawai
        }
    }
}

/// Transport-safe dimensionless coordinates, aligned with the result node order.
public struct GlifiStudioGraphPoint: Codable, Equatable, Sendable {
    /// Dimensionless horizontal layout coordinate.
    public let x: Double
    /// Dimensionless vertical layout coordinate.
    public let y: Double
    /// Creates coordinates; a layout validates supplied initial positions before numerical work.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// One agglomeration using original node positions as stable representatives.
public struct GlifiStudioGraphCommunityMerge: Codable, Equatable, Sendable {
    /// First original node position representing a merged community.
    public let left: Int
    /// Second original node position representing a merged community.
    public let right: Int
    /// Number of original nodes in the merged community.
    public let size: Int
}

/// Complete selected community partition and hierarchy diagnostics without Core types.
public struct GlifiStudioGraphCommunityResult: Codable, Equatable, Sendable {
    /// Versioned native algorithm and numerical contract.
    public let methodIdentifier: String
    /// Versioned undirected projection: summed strengths, with input loops omitted.
    public let projectionIdentifier: String
    /// Input node identities in declared order, defining all aligned result arrays.
    public let nodes: [String]
    /// Community labels aligned with nodes, numbered by first appearance.
    public let membership: [Int]
    /// Number of communities in the selected partition; zero for empty input.
    public let communityCount: Int
    /// Original-graph modularity Q at the selected partition and declared resolution.
    public let modularity: Double
    /// Positive modularity resolution gamma, admitted in (0,1000]; default one.
    public let resolution: Double
    /// Agglomerations in execution order; empty for divisive edge betweenness.
    public let merges: [GlifiStudioGraphCommunityMerge]
    /// Divisive removal order, with uniformly normalized undirected strengths.
    public let removedEdges: [GlifiStudioGraphArc]
    /// Original-graph modularity for the initial partition and each hierarchy step.
    public let modularityHistory: [Double]
}

/// Complete layout coordinates, seed, stopping diagnostics and optional spring history.
public struct GlifiStudioGraphLayoutResult: Codable, Equatable, Sendable {
    /// Versioned native algorithm and numerical contract.
    public let methodIdentifier: String
    /// Input node identities in declared order, defining all aligned result arrays.
    public let nodes: [String]
    /// Dimensionless positions aligned with nodes; FR is bounded, KK is centered.
    public let positions: [GlifiStudioGraphPoint]
    /// Recorded seed for initial positions; explicit initial positions take precedence.
    public let seed: UInt64
    /// Completed cooling iterations or accepted Kamada-Kawai Newton steps.
    public let iterations: Int
    /// Whether the method-specific displacement or gradient stopping tolerance was met.
    public let converged: Bool
    /// Accepted Kamada-Kawai spring energies, including initialization; empty for FR.
    public let energyHistory: [Double]
}

/// Minimum-cost forest, with raw costs and component labels aligned to the input nodes.
public struct GlifiStudioMinimumSpanningForest: Codable, Equatable, Sendable {
    /// Versioned native algorithm and numerical contract.
    public let methodIdentifier: String
    /// Input node identities in declared order, defining all aligned result arrays.
    public let nodes: [String]
    /// Selected forest edges with raw minimum costs; zero-cost edges are retained.
    public let edges: [GlifiStudioGraphArc]
    /// Sum of selected raw edge costs; finite, with zero costs permitted.
    public let totalWeight: Double
    /// Component labels aligned with nodes, numbered by first appearance.
    public let membership: [Int]
    /// Number of connected components, including isolated nodes.
    public let componentCount: Int
}

/// Headless graph work leaves the caller's actor and preserves typed failures/cancellation.
public enum GlifiStudioGraphAlgorithms {
    /// Finds the best modularity cut using inverse-strength GN, sparse CNM or weighted Walktrap.
    ///
    /// Resolution is in (0,1000] and walkLength in 1...64; isolates stay singleton.
    @concurrent public static func communities(
        _ input: GlifiStudioGraphInput, method: GlifiStudioGraphCommunityMethod,
        resolution: Double = 1, walkLength: Int = 4,
        limits: GlifiStudioGraphAlgorithmLimits = .standard
    ) async throws(GlifiStudioFailure) -> GlifiStudioGraphCommunityResult {
        try graphPresentationFailure {
            let value = try GlifiNetworkAnalysis.communities(
                input.core(limits: limits), method: method.core,
                resolution: resolution, walkLength: walkLength, limits: limits.core)
            return try GlifiStudioGraphCommunityResult(
                methodIdentifier: value.methodIdentifier,
                projectionIdentifier: value.projectionIdentifier,
                nodes: input.nodes,
                membership: graphPresentationMembership(input.nodes, value.communityByNode),
                communityCount: value.communityCount, modularity: value.modularity,
                resolution: value.resolution,
                merges: value.merges.map {
                    GlifiStudioGraphCommunityMerge(left: $0.left, right: $0.right, size: $0.size)
                },
                removedEdges: value.removedEdges.map {
                    GlifiStudioGraphArc(source: $0.source, target: $0.target, weight: $0.weight)
                },
                modularityHistory: value.modularityHistory)
        }
    }

    /// Computes an unweighted positive-edge layout off the calling actor.
    ///
    /// Iterations are in 1...100,000; tolerance is finite and positive. FR uses [-1,1] squared,
    /// KK uses centered hop-distance springs and explicit virtual disconnected-component distances.
    @concurrent public static func layout(
        _ input: GlifiStudioGraphInput, method: GlifiStudioGraphLayoutMethod,
        seed: UInt64 = 0, maximumIterations: Int = 300, tolerance: Double = 1e-6,
        initialPositions: [GlifiStudioGraphPoint]? = nil,
        limits: GlifiStudioGraphAlgorithmLimits = .standard
    ) async throws(GlifiStudioFailure) -> GlifiStudioGraphLayoutResult {
        try graphPresentationFailure {
            let value = try GlifiNetworkAnalysis.layout(
                input.core(limits: limits), method: method.core,
                seed: seed, maximumIterations: maximumIterations, tolerance: tolerance,
                initialPositions: initialPositions?.map { GlifiGraphPoint(x: $0.x, y: $0.y) },
                limits: limits.core)
            return GlifiStudioGraphLayoutResult(
                methodIdentifier: value.methodIdentifier,
                nodes: value.nodes,
                positions: value.positions.map { GlifiStudioGraphPoint(x: $0.x, y: $0.y) },
                seed: value.seed, iterations: value.iterations, converged: value.converged,
                energyHistory: value.energyHistory)
        }
    }

    /// Computes Prim's minimum-cost spanning forest.
    ///
    /// Weights are costs, not strengths; zero is valid and reciprocal/parallel arcs use
    /// their minimum cost. No implicit affinity-to-distance transform is performed.
    @concurrent public static func minimumSpanningForest(
        _ input: GlifiStudioGraphInput, limits: GlifiStudioGraphAlgorithmLimits = .standard
    ) async throws(GlifiStudioFailure) -> GlifiStudioMinimumSpanningForest {
        try graphPresentationFailure {
            let value = try GlifiNetworkAnalysis.minimumSpanningForest(
                input.core(limits: limits), limits: limits.core)
            return try GlifiStudioMinimumSpanningForest(
                methodIdentifier: GlifiMinimumSpanningForest<String>.identifier,
                nodes: input.nodes,
                edges: value.edges.map {
                    GlifiStudioGraphArc(source: $0.source, target: $0.target, weight: $0.weight)
                },
                totalWeight: value.totalWeight,
                membership: graphPresentationMembership(input.nodes, value.componentByNode),
                componentCount: value.componentCount)
        }
    }
}

private func graphPresentationInputFailure(_ code: String, _ category: GlifiFailureCategory)
    -> GlifiFailure
{
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category), retainedState: .unchanged,
        messageKey: "failure.category.\(category.rawValue)")
}

private func graphPresentationMembership(_ nodes: [String], _ values: [String: Int]) throws -> [Int]
{
    try nodes.map {
        guard let value = values[$0] else {
            throw GlifiFailure(
                code: "network.incomplete-membership", category: .invariantViolation,
                operation: .analyze, retryDisposition: .never, retainedState: .validityUnknown,
                messageKey: "failure.category.invariantViolation")
        }
        return value
    }
}

private func graphPresentationFailure<Result>(_ body: () throws -> Result)
    throws(GlifiStudioFailure) -> Result
{
    do { return try body() } catch let failure as GlifiStudioFailure { throw failure } catch let
        failure as GlifiFailure
    { throw GlifiStudioFailure(failure) } catch is CancellationError {
        throw GlifiStudioFailure(
            GlifiFailure(
                code: "operation.cancelled", category: .cancelled,
                operation: .analyze, retryDisposition: .newRequest, retainedState: .unchanged,
                messageKey: "failure.operation.cancelled"))
    } catch {
        throw GlifiStudioFailure(
            GlifiFailure(
                code: "internal.unexpected", category: .invariantViolation,
                operation: .analyze, retryDisposition: .never, retainedState: .validityUnknown,
                messageKey: "failure.category.invariantViolation"))
    }
}
