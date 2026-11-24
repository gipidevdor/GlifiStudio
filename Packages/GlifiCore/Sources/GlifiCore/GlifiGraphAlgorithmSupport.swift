// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Admission budgets for bounded community, layout and spanning-tree algorithms.
public struct GlifiGraphAlgorithmLimits: Equatable, Sendable {
    /// Defaults: 2,000 nodes, 100,000 arcs, 1,000,000 pairwise cells and 200,000,000 work units.
    public static let standard = GlifiGraphAlgorithmLimits()
    /// Maximum input nodes, checked before graph-index allocation.
    public let maximumNodeCount: Int
    /// Maximum input arcs, including loops and repeated arcs, before projection.
    public let maximumEdgeCount: Int
    /// Maximum scalar cells across pairwise or exact-accumulator working buffers.
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
}

func graphAlgorithmFailure(
    _ code: String, category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.category.\(category.rawValue)")
}

func admitGraph<Node>(_ graph: GlifiDirectedGraph<Node>, limits: GlifiGraphAlgorithmLimits) throws {
    guard limits.maximumNodeCount >= 0, limits.maximumEdgeCount >= 0,
        limits.maximumPairwiseCells >= 0, limits.maximumWork >= 0
    else { throw graphAlgorithmFailure("network.invalid-limits") }
    guard graph.nodes.count <= limits.maximumNodeCount,
        graph.edges.count <= limits.maximumEdgeCount
    else { throw graphAlgorithmFailure("network.resource-limit", category: .insufficientResources) }
    try Task.checkCancellation()
}

func admitGraphWork(_ factors: [Int], limits: GlifiGraphAlgorithmLimits) throws {
    try admitGraphWork(phases: [factors], limits: limits)
}

/// Charges all phases against one budget, without overflowing either products or their sum.
func admitGraphWork(phases: [[Int]], limits: GlifiGraphAlgorithmLimits) throws {
    var remaining = limits.maximumWork
    for factors in phases {
        guard factors.allSatisfy({ $0 >= 0 }) else {
            throw graphAlgorithmFailure("network.resource-limit", category: .insufficientResources)
        }
        if factors.contains(0) { continue }
        var product = 1
        for factor in factors {
            guard product <= remaining / factor else {
                throw graphAlgorithmFailure(
                    "network.resource-limit", category: .insufficientResources)
            }
            product *= factor
        }
        remaining -= product
    }
}

func admitGraphPairs(_ count: Int, buffers: Int = 1, limits: GlifiGraphAlgorithmLimits) throws {
    guard count >= 0, buffers > 0,
        count == 0 || count <= limits.maximumPairwiseCells / count / buffers
    else { throw graphAlgorithmFailure("network.resource-limit", category: .insufficientResources) }
}

struct GlifiIndexedUndirectedEdge {
    let left: Int
    let right: Int
    let weight: Double
}

struct GlifiGraphPair: Hashable, Comparable {
    let left: Int
    let right: Int

    init(_ first: Int, _ second: Int) {
        left = min(first, second)
        right = max(first, second)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.left == rhs.left ? lhs.right < rhs.right : lhs.left < rhs.left
    }
}

/// Community projection: ignore loops/zero edges; sum all directions and multiedges.
///
/// Normalize first to avoid overflow. A uniform scale does not change modularity or walks.
struct GlifiPreparedCommunityGraph {
    let count: Int
    let edges: [GlifiIndexedUndirectedEdge]
    let adjacency: [[(node: Int, edge: Int)]]
    let strengths: [Double]
    let totalWeight: Double

    init<Node>(
        _ graph: GlifiDirectedGraph<Node>, limits: GlifiGraphAlgorithmLimits,
        weighted: Bool = true
    ) throws {
        try admitGraph(graph, limits: limits)
        let positions = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        let scale = graph.edges.lazy.filter { $0.source != $0.target }.map(\.weight).max() ?? 0
        var weights: [GlifiGraphPair: Double] = [:]
        for (index, edge) in graph.edges.enumerated()
        where edge.source != edge.target && edge.weight > 0 {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            guard let left = positions[edge.source], let right = positions[edge.target] else {
                throw graphAlgorithmFailure("network.unknown-edge-endpoint")
            }
            let weight = weighted ? edge.weight / scale : 1
            guard weight.isFinite, weight > 0 else {
                throw graphAlgorithmFailure("network.numeric-range")
            }
            weights[GlifiGraphPair(left, right), default: 0] += weight
        }
        count = graph.nodes.count
        edges = weights.keys.sorted().map {
            GlifiIndexedUndirectedEdge(left: $0.left, right: $0.right, weight: weights[$0] ?? 0)
        }
        var rows = [[(node: Int, edge: Int)]](repeating: [], count: count)
        var degree = [Double](repeating: 0, count: count)
        for (index, edge) in edges.enumerated() {
            rows[edge.left].append((edge.right, index))
            rows[edge.right].append((edge.left, index))
            degree[edge.left] += edge.weight
            degree[edge.right] += edge.weight
        }
        adjacency = rows
        strengths = degree
        totalWeight = edges.reduce(0) { $0 + $1.weight }
        guard totalWeight.isFinite else { throw graphAlgorithmFailure("network.numeric-range") }
    }

    func modularity(_ membership: [Int], resolution: Double) -> Double {
        guard totalWeight > 0 else { return 0 }
        var degrees = [Double](repeating: 0, count: count)
        var internalWeight = 0.0
        for node in 0..<count { degrees[membership[node]] += strengths[node] }
        for edge in edges where membership[edge.left] == membership[edge.right] {
            internalWeight += edge.weight
        }
        return internalWeight / totalWeight - resolution
            * degrees.reduce(0) {
                let fraction = $1 / (2 * totalWeight)
                return $0 + fraction * fraction
            }
    }
}

func canonicalGraphMembership(_ leaders: [Int]) -> [Int] {
    var numbering: [Int: Int] = [:]
    return leaders.map { leader in
        if let value = numbering[leader] { return value }
        let value = numbering.count
        numbering[leader] = value
        return value
    }
}

struct GlifiGraphPriorityQueue<Entry> {
    private var entries: [Entry] = []
    private let precedes: (Entry, Entry) -> Bool
    var count: Int { entries.count }

    init(precedes: @escaping (Entry, Entry) -> Bool) { self.precedes = precedes }

    mutating func insert(_ value: Entry) {
        entries.append(value)
        var index = entries.count - 1
        while index > 0 {
            let parent = (index - 1) / 2
            guard precedes(value, entries[parent]) else { break }
            entries[index] = entries[parent]
            index = parent
        }
        entries[index] = value
    }

    mutating func removeFirst() -> Entry? {
        guard let first = entries.first, let last = entries.popLast() else { return nil }
        guard !entries.isEmpty else { return first }
        var index = 0
        while index < entries.count / 2 {
            var child = index * 2 + 1
            if child + 1 < entries.count, precedes(entries[child + 1], entries[child]) {
                child += 1
            }
            guard precedes(entries[child], last) else { break }
            entries[index] = entries[child]
            index = child
        }
        entries[index] = last
        return first
    }
}
