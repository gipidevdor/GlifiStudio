// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One directed, weighted edge between two identified nodes.
public struct GlifiGraphEdge<Node: Hashable & Sendable>: Equatable, Sendable {
    /// Source node identity.
    public let source: Node
    /// Target node identity.
    public let target: Node
    /// Non-negative edge weight; `1` for an unweighted graph.
    public let weight: Double

    /// Creates one edge with an optional weight.
    public init(source: Node, target: Node, weight: Double = 1) {
        self.source = source
        self.target = target
        self.weight = weight
    }
}

/// One immutable directed graph `G=(V,E)` with stable node identity.
public struct GlifiDirectedGraph<Node: Hashable & Sendable>: Sendable {
    /// Nodes, in declared order; determines tie-break order downstream.
    public let nodes: [Node]
    /// Directed, weighted edges.
    ///
    /// Self-loops and multi-edges are both admitted.
    public let edges: [GlifiGraphEdge<Node>]

    /// Creates a graph only after checking node uniqueness, edge endpoints,
    /// and non-negative finite weights.
    public init(nodes: [Node], edges: [GlifiGraphEdge<Node>]) throws {
        guard Set(nodes).count == nodes.count else {
            throw networkFailure("network.duplicate-node", category: .invalidInput)
        }
        let nodeSet = Set(nodes)
        guard edges.allSatisfy({ nodeSet.contains($0.source) && nodeSet.contains($0.target) })
        else {
            throw networkFailure("network.unknown-edge-endpoint", category: .invalidInput)
        }
        guard edges.allSatisfy({ $0.weight.isFinite && $0.weight >= 0 }) else {
            throw networkFailure("network.negative-or-non-finite-weight", category: .invalidInput)
        }
        self.nodes = nodes
        self.edges = edges
    }
}

/// `Degree-v1` and `WeightedDegree-v1` per node; self-loops contribute to
/// both in- and out-degree of their node.
public struct GlifiDegreeResult<Node: Hashable & Sendable>: Sendable {
    /// Versioned identifier of `inDegree`/`outDegree`.
    public static var degreeIdentifier: String { "Degree-v1" }
    /// Versioned identifier of `weightedInDegree`/`weightedOutDegree`.
    public static var weightedDegreeIdentifier: String { "WeightedDegree-v1" }

    /// Number of incoming edges per node.
    public let inDegree: [Node: Int]
    /// Number of outgoing edges per node.
    public let outDegree: [Node: Int]
    /// Sum of incoming edge weights per node.
    public let weightedInDegree: [Node: Double]
    /// Sum of outgoing edge weights per node.
    public let weightedOutDegree: [Node: Double]
}

/// `PageRank-v1` result: a probability distribution over nodes.
public struct GlifiPageRankResult<Node: Hashable & Sendable>: Sendable {
    /// Versioned identifier.
    public static var identifier: String { "PageRank-v1" }

    /// `π`, summing to `1` over `nodes`.
    public let scores: [Node: Double]
    /// Number of power-iteration steps actually run.
    public let iterations: Int
    /// Whether the L1 delta fell under `tolerance` before `maximumIterations`.
    public let converged: Bool
}

/// `Betweenness-v1` result: unweighted shortest-path betweenness over
/// directed hop-distance, raw and not normalized.
public struct GlifiBetweennessResult<Node: Hashable & Sendable>: Sendable {
    /// Versioned identifier.
    public static var identifier: String { "Betweenness-v1" }

    /// Sum, over admissible ordered pairs, of the share of shortest paths
    /// through each node; ties split proportionally as Brandes' algorithm
    /// requires.
    public let scores: [Node: Double]
}

/// `HarmonicCloseness-v1` result over directed hop-distance.
public struct GlifiHarmonicClosenessResult<Node: Hashable & Sendable>: Sendable {
    /// Versioned identifier.
    public static var identifier: String { "HarmonicCloseness-v1" }

    /// `Σ_{u≠v} 1/d(v,u)`; unreachable `u` contributes zero.
    public let scores: [Node: Double]
}

/// Bounded, deterministic graph primitives (GS-MET-001-16).
public enum GlifiNetworkAnalysis {
    /// Computes `Degree-v1` and `WeightedDegree-v1` for every node.
    public static func degree<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiDegreeResult<Node> {
        var inDegree = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0) })
        var outDegree = inDegree
        var weightedInDegree = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) })
        var weightedOutDegree = weightedInDegree
        for edge in graph.edges {
            outDegree[edge.source, default: 0] += 1
            inDegree[edge.target, default: 0] += 1
            weightedOutDegree[edge.source, default: 0] += edge.weight
            weightedInDegree[edge.target, default: 0] += edge.weight
        }
        return GlifiDegreeResult(
            inDegree: inDegree,
            outDegree: outDegree,
            weightedInDegree: weightedInDegree,
            weightedOutDegree: weightedOutDegree
        )
    }

    /// Computes `PageRank-v1` by power iteration with uniform teleportation.
    ///
    /// A dangling node (zero out-weight) redistributes its full mass through
    /// the teleport vector, as required by the specification. Throws for an
    /// empty graph or `damping` outside `[0,1)`.
    public static func pageRank<Node>(
        _ graph: GlifiDirectedGraph<Node>,
        damping: Double = 0.85,
        tolerance: Double = 1e-10,
        maximumIterations: Int = 1000
    ) throws -> GlifiPageRankResult<Node> {
        guard !graph.nodes.isEmpty else {
            throw networkFailure("network.empty-graph", category: .insufficientData)
        }
        guard damping >= 0, damping < 1 else {
            throw networkFailure("network.invalid-damping", category: .invalidInput)
        }
        guard maximumIterations > 0 else {
            throw networkFailure("network.invalid-iteration-bound", category: .invalidInput)
        }
        guard tolerance.isFinite, tolerance > 0 else {
            throw networkFailure("network.invalid-tolerance", category: .invalidInput)
        }

        let count = graph.nodes.count
        let teleport = 1 / Double(count)
        // Resolve generic identities once; power iteration uses contiguous CSR rows.
        // Row and edge orders are unchanged, including parallel edges and zero weights.
        let nodeIndex = Dictionary(
            uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) })
        var rowCounts = [Int](repeating: 0, count: count)
        var rowScale = [Double](repeating: 0, count: count)
        // Row scaling cancels in transition probabilities and prevents the sum of finite
        // outgoing weights from overflowing (or a subnormal row from losing its mass).
        for (position, edge) in graph.edges.enumerated() {
            if position.isMultiple(of: 4_096) { try Task.checkCancellation() }
            guard let source = nodeIndex[edge.source] else {
                throw networkFailure("network.unknown-edge-endpoint")
            }
            rowCounts[source] += 1
            rowScale[source] = max(rowScale[source], edge.weight)
        }
        var rowOffsets = [Int](repeating: 0, count: count + 1)
        for node in 0..<count { rowOffsets[node + 1] = rowOffsets[node] + rowCounts[node] }
        var cursor = Array(rowOffsets.dropLast())
        var targets = [Int](repeating: 0, count: graph.edges.count)
        var weights = [Double](repeating: 0, count: graph.edges.count)
        var outWeight = [Double](repeating: 0, count: count)
        for (position, edge) in graph.edges.enumerated() {
            if position.isMultiple(of: 4_096) { try Task.checkCancellation() }
            guard let source = nodeIndex[edge.source], let target = nodeIndex[edge.target] else {
                throw networkFailure("network.unknown-edge-endpoint")
            }
            let scale = rowScale[source]
            let weight = scale > 0 ? edge.weight / scale : 0
            outWeight[source] += weight
            targets[cursor[source]] = target
            weights[cursor[source]] = weight
            cursor[source] += 1
        }

        var scores = [Double](repeating: teleport, count: count)
        var next = [Double](repeating: 0, count: count)
        var converged = false
        var iterationsUsed = 0
        for iteration in 1...maximumIterations {
            try Task.checkCancellation()
            iterationsUsed = iteration
            for node in 0..<count { next[node] = (1 - damping) * teleport }
            var danglingMass = 0.0
            for node in 0..<count {
                let total = outWeight[node]
                let score = scores[node]
                guard total > 0 else {
                    danglingMass += score
                    continue
                }
                let contribution = score / total
                for edge in rowOffsets[node]..<rowOffsets[node + 1] {
                    next[targets[edge]] += damping * weights[edge] * contribution
                }
            }
            let danglingContribution = damping * danglingMass * teleport
            for node in 0..<count {
                next[node] += danglingContribution
            }
            let delta = (0..<count).reduce(0.0) { $0 + abs(next[$1] - scores[$1]) }
            swap(&scores, &next)
            if delta < tolerance {
                converged = true
                break
            }
        }
        let identifiedScores = Dictionary(
            uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, scores[$0.offset]) })
        return GlifiPageRankResult(
            scores: identifiedScores, iterations: iterationsUsed, converged: converged)
    }

    /// Computes `Betweenness-v1` over unweighted, directed hop-distance
    /// using Brandes' algorithm: one BFS per source, then a reverse-order
    /// dependency accumulation.
    public static func betweenness<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiBetweennessResult<Node> {
        let outNeighbors = simpleOutNeighbors(graph)
        var betweenness = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) })
        for source in graph.nodes {
            var distance: [Node: Int] = [source: 0]
            var sigma: [Node: Double] = [source: 1]
            var predecessors: [Node: [Node]] = [:]
            var order: [Node] = []
            var queue = [source]
            var queueIndex = 0
            while queueIndex < queue.count {
                let current = queue[queueIndex]
                queueIndex += 1
                order.append(current)
                guard let currentDistance = distance[current] else { continue }
                for neighbor in outNeighbors[current] ?? [] {
                    if distance[neighbor] == nil {
                        distance[neighbor] = currentDistance + 1
                        queue.append(neighbor)
                    }
                    if distance[neighbor] == currentDistance + 1 {
                        sigma[neighbor, default: 0] += sigma[current] ?? 0
                        predecessors[neighbor, default: []].append(current)
                    }
                }
            }
            var dependency = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) })
            for node in order.reversed() where node != source {
                for predecessor in predecessors[node] ?? [] {
                    let ratio = (sigma[predecessor] ?? 0) / (sigma[node] ?? 1)
                    dependency[predecessor, default: 0] += ratio * (1 + (dependency[node] ?? 0))
                }
                betweenness[node, default: 0] += dependency[node] ?? 0
            }
        }
        return GlifiBetweennessResult(scores: betweenness)
    }

    /// Computes `HarmonicCloseness-v1` over unweighted, directed hop-distance
    /// via one BFS per source.
    public static func harmonicCloseness<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiHarmonicClosenessResult<Node> {
        let count = graph.nodes.count
        guard count > 0 else { return GlifiHarmonicClosenessResult(scores: [:]) }
        let adjacency = indexedSimpleOutNeighbors(graph)
        var distance = [Int](repeating: -1, count: count)
        var queue: [Int] = []
        queue.reserveCapacity(count)
        var values = [Double](repeating: 0, count: count)
        for source in 0..<count {
            // A source with no non-self neighbors cannot reach another node.
            guard adjacency.offsets[source] != adjacency.offsets[source + 1] else { continue }
            distance[source] = 0
            queue.append(source)
            var queueIndex = 0
            while queueIndex < queue.count {
                let current = queue[queueIndex]
                queueIndex += 1
                let nextDistance = distance[current] + 1
                for edge in adjacency.offsets[current]..<adjacency.offsets[current + 1] {
                    let neighbor = adjacency.targets[edge]
                    guard distance[neighbor] == -1 else { continue }
                    distance[neighbor] = nextDistance
                    queue.append(neighbor)
                }
            }
            // The floating reduction follows declared node order, never BFS order.
            var score = 0.0
            for node in 0..<count {
                let hops = distance[node]
                guard node != source, hops > 0 else { continue }
                score += 1 / Double(hops)
            }
            values[source] = score
            // Only reachable nodes were written; reuse both buffers for the next source.
            for node in queue { distance[node] = -1 }
            queue.removeAll(keepingCapacity: true)
        }
        return GlifiHarmonicClosenessResult(
            scores: Dictionary(
                uniqueKeysWithValues: graph.nodes.enumerated().map {
                    ($0.element, values[$0.offset])
                }))
    }

    /// Resolves identities once while retaining the legacy first-occurrence neighbor order.
    private static func indexedSimpleOutNeighbors<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> (offsets: [Int], targets: [Int]) {
        let outNeighbors = simpleOutNeighbors(graph)
        let nodeIndex = Dictionary(
            uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) })
        var offsets = [Int](repeating: 0, count: graph.nodes.count + 1)
        for (index, node) in graph.nodes.enumerated() {
            offsets[index + 1] = offsets[index] + (outNeighbors[node]?.count ?? 0)
        }
        var targets: [Int] = []
        targets.reserveCapacity(offsets[graph.nodes.count])
        for node in graph.nodes {
            for neighbor in outNeighbors[node] ?? [] {
                // GlifiDirectedGraph validates every endpoint before becoming immutable.
                guard let index = nodeIndex[neighbor] else {
                    preconditionFailure("Validated graph contains an unknown endpoint")
                }
                targets.append(index)
            }
        }
        return (offsets, targets)
    }

    /// Deduplicated out-neighbors per node, excluding self-loops: shortest
    /// hop-distance treats parallel edges and self-loops as a single step.
    private static func simpleOutNeighbors<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> [Node: [Node]] {
        var seen: [Node: Set<Node>] = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, []) })
        var ordered: [Node: [Node]] = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, []) })
        for edge in graph.edges where edge.source != edge.target {
            guard !seen[edge.source, default: []].contains(edge.target) else { continue }
            seen[edge.source, default: []].insert(edge.target)
            ordered[edge.source, default: []].append(edge.target)
        }
        return ordered
    }
}

func networkFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}
