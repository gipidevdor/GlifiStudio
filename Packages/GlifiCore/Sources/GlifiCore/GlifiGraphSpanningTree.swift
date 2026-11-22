// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Prim's minimum-cost spanning forest, retaining input node identities and raw costs.
public struct GlifiMinimumSpanningForest<Node: Hashable & Sendable>: Sendable {
    /// Versioned Prim forest contract over nonnegative raw costs.
    public static var identifier: String { "Prim-minimum-spanning-forest-v1" }
    /// Selected forest edges with raw minimum costs; zero-cost edges are retained.
    public let edges: [GlifiGraphEdge<Node>]
    /// Sum of selected raw edge costs; finite, with zero costs permitted.
    public let totalWeight: Double
    /// Component label per input identity, numbered by first appearance.
    public let componentByNode: [Node: Int]
    /// Number of connected components, including isolated nodes.
    public let componentCount: Int
}

extension GlifiNetworkAnalysis {
    /// Computes an undirected minimum-cost spanning forest.
    ///
    /// Omits loops and takes the smallest cost of parallel edges. Zero costs are valid.
    /// Unlike community weights, these values are costs.
    /// Each component starts at its first declared node; ties follow endpoint positions.
    public static func minimumSpanningForest<Node>(
        _ graph: GlifiDirectedGraph<Node>, limits: GlifiGraphAlgorithmLimits = .standard
    ) throws -> GlifiMinimumSpanningForest<Node> {
        try admitGraph(graph, limits: limits)
        let n = graph.nodes.count
        try admitGraphWork(
            [max(1, graph.edges.count + n), max(1, Int(log2(Double(max(2, n)))) + 1)],
            limits: limits)
        let positions = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        var costs: [GlifiGraphPair: Double] = [:]
        for (offset, edge) in graph.edges.enumerated() where edge.source != edge.target {
            if offset.isMultiple(of: 256) { try Task.checkCancellation() }
            guard let left = positions[edge.source], let right = positions[edge.target] else {
                throw graphAlgorithmFailure("network.unknown-edge-endpoint")
            }
            let pair = GlifiGraphPair(left, right)
            costs[pair] = min(costs[pair] ?? .infinity, edge.weight)
        }
        var rows = [[(node: Int, cost: Double)]](repeating: [], count: n)
        for pair in costs.keys.sorted() {
            let cost = costs[pair] ?? 0
            rows[pair.left].append((pair.right, cost))
            rows[pair.right].append((pair.left, cost))
        }
        var visited = [Bool](repeating: false, count: n)
        var components = [Int](repeating: -1, count: n)
        var edges: [GlifiGraphEdge<Node>] = []
        var component = 0
        var total = 0.0
        for root in 0..<n where !visited[root] {
            var heap = GlifiGraphPriorityQueue<SpanningCandidate> { left, right in
                left.cost == right.cost ? left.pair < right.pair : left.cost < right.cost
            }
            visited[root] = true
            components[root] = component
            for neighbor in rows[root] {
                heap.insert(
                    SpanningCandidate(parent: root, node: neighbor.node, cost: neighbor.cost))
            }
            while let candidate = heap.removeFirst() {
                try Task.checkCancellation()
                guard !visited[candidate.node] else { continue }
                visited[candidate.node] = true
                components[candidate.node] = component
                let pair = candidate.pair
                edges.append(
                    GlifiGraphEdge(
                        source: graph.nodes[pair.left], target: graph.nodes[pair.right],
                        weight: candidate.cost))
                total += candidate.cost
                guard total.isFinite else {
                    throw graphAlgorithmFailure("network.mst-cost-overflow")
                }
                for neighbor in rows[candidate.node] where !visited[neighbor.node] {
                    heap.insert(
                        SpanningCandidate(
                            parent: candidate.node, node: neighbor.node, cost: neighbor.cost))
                }
            }
            component += 1
        }
        try Task.checkCancellation()
        return GlifiMinimumSpanningForest(
            edges: edges, totalWeight: total,
            componentByNode: Dictionary(uniqueKeysWithValues: zip(graph.nodes, components)),
            componentCount: component)
    }

    /// Returns a minimum spanning tree, failing explicitly for an empty or disconnected graph.
    public static func minimumSpanningTree<Node>(
        _ graph: GlifiDirectedGraph<Node>, limits: GlifiGraphAlgorithmLimits = .standard
    ) throws -> GlifiMinimumSpanningForest<Node> {
        let result = try minimumSpanningForest(graph, limits: limits)
        guard result.componentCount == 1 else {
            throw graphAlgorithmFailure("network.mst-disconnected", category: .insufficientData)
        }
        return result
    }
}

private struct SpanningCandidate {
    let parent: Int
    let node: Int
    let cost: Double
    var pair: GlifiGraphPair { GlifiGraphPair(parent, node) }
}
