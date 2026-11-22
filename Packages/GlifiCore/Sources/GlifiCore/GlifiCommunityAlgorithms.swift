// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Native deterministic community variants; identifiers describe their weighted contracts.
public enum GlifiCommunityMethod: String, Codable, CaseIterable, Sendable {
    /// Recomputed inverse-strength shortest-path betweenness after every removal.
    case edgeBetweenness = "GirvanNewman-inverse-strength-v1"
    /// Sparse weighted Clauset-Newman-Moore modularity agglomeration.
    case fastGreedy = "ClausetNewmanMoore-weighted-v1"
    /// Weighted t-step walks with mean-strength loops and adjacent Ward merges.
    case walktrap = "Walktrap-weighted-mean-loops-v1"
}

/// One agglomeration, using original node positions as stable cluster representatives.
public struct GlifiCommunityMerge: Equatable, Sendable {
    /// First original node position representing a merged community.
    public let left: Int
    /// Second original node position representing a merged community.
    public let right: Int
    /// Number of original nodes in the merged community.
    public let size: Int
}

/// Best modularity partition encountered along a deterministic hierarchy.
public struct GlifiGraphCommunityResult<Node: Hashable & Sendable>: Sendable {
    /// Versioned native algorithm and numerical contract.
    public let methodIdentifier: String
    /// Input directions/multiedges are summed; self-loops and zero edges are omitted.
    public let projectionIdentifier: String
    /// Selected community per input identity, numbered by first appearance.
    public let communityByNode: [Node: Int]
    /// Number of communities in the selected partition; zero for empty input.
    public let communityCount: Int
    /// Original-graph modularity Q at the selected partition and declared resolution.
    public let modularity: Double
    /// Positive modularity resolution gamma, admitted in (0,1000]; default one.
    public let resolution: Double
    /// Empty for divisive Girvan–Newman.
    public let merges: [GlifiCommunityMerge]
    /// Divisive removals; weights are the uniformly normalized undirected strengths.
    public let removedEdges: [GlifiGraphEdge<Node>]
    /// Includes the initial partition and each merge/removal, evaluated on the original graph.
    public let modularityHistory: [Double]
}

extension GlifiNetworkAnalysis {
    /// Finds the highest-modularity partition encountered by the selected native variant.
    ///
    /// Isolates stay singleton. Ties preserve the earliest partition and declared-node order.
    /// Girvan–Newman recomputes weighted shortest-path edge betweenness after every removal.
    /// CNM uses a sparse lazy heap of exact modularity gains. Walktrap uses t-step weighted
    /// walks, a self-loop of mean incident strength, and adjacent Ward agglomeration.
    /// References: Newman/Girvan (2004), Clauset/Newman/Moore (2004), Pons/Latapy (2005).
    public static func communities<Node>(
        _ graph: GlifiDirectedGraph<Node>, method: GlifiCommunityMethod,
        resolution: Double = 1, walkLength: Int = 4,
        limits: GlifiGraphAlgorithmLimits = .standard
    ) throws -> GlifiGraphCommunityResult<Node> {
        try admitGraph(graph, limits: limits)
        guard resolution.isFinite, resolution > 0, resolution <= 1_000,
            (1...64).contains(walkLength)
        else { throw graphAlgorithmFailure("network.invalid-community-parameters") }
        let prepared = try GlifiPreparedCommunityGraph(graph, limits: limits)
        let output: CommunityOutput
        switch method {
        case .edgeBetweenness:
            let logarithm = max(1, Int(log2(Double(max(2, prepared.count)))) + 1)
            try admitGraphWork(
                [
                    prepared.count, max(1, prepared.edges.count),
                    max(1, prepared.edges.count + prepared.count), logarithm,
                ], limits: limits)
            output = try girvanNewman(prepared, resolution: resolution)
        case .fastGreedy:
            try admitGraphWork(
                [max(1, prepared.count), max(1, prepared.edges.count + prepared.count)],
                limits: limits)
            output = try agglomerateCommunities(
                prepared, resolution: resolution, walkProfiles: nil)
        case .walktrap:
            try admitGraphPairs(prepared.count, buffers: 2, limits: limits)
            try admitGraphWork(
                [walkLength, prepared.count, max(1, prepared.edges.count + prepared.count)],
                limits: limits)
            try admitGraphWork(
                [prepared.count, prepared.count, max(1, prepared.edges.count)], limits: limits)
            let profiles = try communityWalkProfiles(prepared, length: walkLength)
            output = try agglomerateCommunities(
                prepared, resolution: resolution, walkProfiles: profiles)
        }
        try Task.checkCancellation()
        return GlifiGraphCommunityResult(
            methodIdentifier: method.rawValue,
            projectionIdentifier: "undirected-sum-normalized-ignore-loops-v1",
            communityByNode: Dictionary(uniqueKeysWithValues: zip(graph.nodes, output.membership)),
            communityCount: (output.membership.max() ?? -1) + 1,
            modularity: prepared.modularity(output.membership, resolution: resolution),
            resolution: resolution, merges: output.merges,
            removedEdges: output.removed.map {
                let edge = prepared.edges[$0]
                return GlifiGraphEdge(
                    source: graph.nodes[edge.left], target: graph.nodes[edge.right],
                    weight: edge.weight)
            },
            modularityHistory: output.history)
    }
}

private struct CommunityOutput {
    let membership: [Int]
    let merges: [GlifiCommunityMerge]
    let removed: [Int]
    let history: [Double]
}

private struct CommunityCandidate {
    let left: Int
    let right: Int
    let leftRevision: Int
    let rightRevision: Int
    let score: Double
}

private func agglomerateCommunities(
    _ graph: GlifiPreparedCommunityGraph, resolution: Double, walkProfiles: [[Double]]?
) throws -> CommunityOutput {
    let n = graph.count
    var rows = [[Int: Double]](repeating: [:], count: n)
    for edge in graph.edges {
        rows[edge.left][edge.right] = edge.weight
        rows[edge.right][edge.left] = edge.weight
    }
    var sizes = [Int](repeating: 1, count: n)
    var degrees = graph.strengths
    var revisions = [Int](repeating: 0, count: n)
    var profiles = walkProfiles ?? []
    let maximize = walkProfiles == nil
    var heap = GlifiGraphPriorityQueue<CommunityCandidate> { left, right in
        if left.score != right.score {
            return maximize ? left.score > right.score : left.score < right.score
        }
        return left.left == right.left ? left.right < right.right : left.left < right.left
    }
    func score(_ left: Int, _ right: Int) throws -> Double {
        let value: Double
        if maximize {
            let a = degrees[left] / (2 * graph.totalWeight)
            let b = degrees[right] / (2 * graph.totalWeight)
            value = (rows[left][right] ?? 0) / graph.totalWeight - 2 * resolution * a * b
        } else {
            var square = 0.0
            for axis in 0..<n {
                if axis.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let difference = profiles[left][axis] - profiles[right][axis]
                square += difference * difference
            }
            value =
                Double(sizes[left]) * Double(sizes[right]) / Double(sizes[left] + sizes[right])
                * square
        }
        guard value.isFinite else { throw graphAlgorithmFailure("network.numeric-range") }
        return value
    }
    func candidate(_ a: Int, _ b: Int) throws -> CommunityCandidate {
        let left = min(a, b)
        let right = max(a, b)
        return try CommunityCandidate(
            left: left, right: right, leftRevision: revisions[left],
            rightRevision: revisions[right],
            score: score(left, right))
    }
    for edge in graph.edges { heap.insert(try candidate(edge.left, edge.right)) }
    var bestQ = graph.modularity(Array(0..<n), resolution: resolution)
    var currentQ = bestQ
    var bestMergeCount = 0
    var history = [bestQ]
    var merges: [GlifiCommunityMerge] = []
    while let next = heap.removeFirst() {
        try Task.checkCancellation()
        let a = next.left
        let b = next.right
        guard sizes[a] > 0, sizes[b] > 0,
            next.leftRevision == revisions[a], next.rightRevision == revisions[b],
            rows[a][b] != nil
        else { continue }
        let gain =
            (rows[a][b] ?? 0) / graph.totalWeight
            - 2 * resolution * (degrees[a] / (2 * graph.totalWeight))
            * (degrees[b] / (2 * graph.totalWeight))
        let combinedSize = sizes[a] + sizes[b]
        if !maximize {
            let fraction = Double(sizes[b]) / Double(combinedSize)
            for axis in 0..<n {
                profiles[a][axis] += fraction * (profiles[b][axis] - profiles[a][axis])
            }
        }
        sizes[a] = combinedSize
        sizes[b] = 0
        degrees[a] += degrees[b]
        revisions[a] += 1
        revisions[b] += 1
        rows[a][b] = nil
        for neighbor in rows[b].keys.sorted() where neighbor != a {
            rows[a][neighbor, default: 0] += rows[b][neighbor] ?? 0
            rows[neighbor][a] = rows[a][neighbor]
            rows[neighbor][b] = nil
        }
        rows[b].removeAll(keepingCapacity: false)
        for neighbor in rows[a].keys.sorted() { heap.insert(try candidate(a, neighbor)) }
        // Stale records are bounded by a constant multiple of the original sparse edge set.
        if heap.count > 2 * (graph.edges.count + n) {
            heap = GlifiGraphPriorityQueue<CommunityCandidate> { left, right in
                if left.score != right.score {
                    return maximize ? left.score > right.score : left.score < right.score
                }
                return left.left == right.left ? left.right < right.right : left.left < right.left
            }
            for left in 0..<n where sizes[left] > 0 {
                for right in rows[left].keys.sorted() where left < right {
                    heap.insert(try candidate(left, right))
                }
            }
        }
        currentQ += gain
        history.append(currentQ)
        merges.append(GlifiCommunityMerge(left: a, right: b, size: combinedSize))
        if currentQ > bestQ + 1e-12 {
            bestQ = currentQ
            bestMergeCount = merges.count
        }
    }
    // Reconstruct only the selected cut, instead of rescanning every node/edge after each merge.
    var parents = Array(0..<n)
    for merge in merges.prefix(bestMergeCount) { parents[merge.right] = merge.left }
    for node in 0..<n {
        var root = node
        while parents[root] != root { root = parents[root] }
        parents[node] = root
    }
    return CommunityOutput(
        membership: canonicalGraphMembership(parents), merges: merges,
        removed: [], history: history)
}

/// Weighted extension of Pons/Latapy: each self-loop has the mean incident edge strength.
///
/// For unit-weight simple graphs this is exactly the paper's one-loop transition matrix.
private func communityWalkProfiles(_ graph: GlifiPreparedCommunityGraph, length: Int) throws
    -> [[Double]]
{
    let n = graph.count
    var degree = graph.strengths
    var loops = [Double](repeating: 0, count: n)
    for node in 0..<n {
        loops[node] =
            graph.adjacency[node].isEmpty ? 1 : degree[node] / Double(graph.adjacency[node].count)
        degree[node] += loops[node]
    }
    var current = Array(repeating: Array(repeating: 0.0, count: n), count: n)
    var next = current
    for node in 0..<n { current[node][node] = 1 }
    for _ in 0..<length {
        try Task.checkCancellation()
        for origin in 0..<n {
            for target in 0..<n { next[origin][target] = 0 }
            for node in 0..<n where current[origin][node] > 0 {
                if node.isMultiple(of: 128) { try Task.checkCancellation() }
                let mass = current[origin][node] / degree[node]
                next[origin][node] += mass * loops[node]
                for entry in graph.adjacency[node] {
                    next[origin][entry.node] += mass * graph.edges[entry.edge].weight
                }
            }
        }
        swap(&current, &next)
    }
    for row in 0..<n {
        for column in 0..<n { current[row][column] /= degree[column].squareRoot() }
    }
    return current
}

private func communityComponents(_ graph: GlifiPreparedCommunityGraph, active: [Bool]) -> [Int] {
    var labels = [Int](repeating: -1, count: graph.count)
    var number = 0
    for start in 0..<graph.count where labels[start] < 0 {
        var queue = [start]
        labels[start] = number
        var head = 0
        while head < queue.count {
            let node = queue[head]
            head += 1
            for entry in graph.adjacency[node] where active[entry.edge] && labels[entry.node] < 0 {
                labels[entry.node] = number
                queue.append(entry.node)
            }
        }
        number += 1
    }
    return labels
}

private func girvanNewman(_ graph: GlifiPreparedCommunityGraph, resolution: Double) throws
    -> CommunityOutput
{
    var active = [Bool](repeating: true, count: graph.edges.count)
    var best = communityComponents(graph, active: active)
    var bestQ = graph.modularity(best, resolution: resolution)
    var history = [bestQ]
    var removed: [Int] = []
    for _ in graph.edges.indices {
        try Task.checkCancellation()
        let scores = try communityEdgeBetweenness(graph, active: active)
        var selected: Int?
        for edge in graph.edges.indices where active[edge] {
            if selected == nil || scores[edge] > scores[selected ?? edge] { selected = edge }
        }
        guard let selected else { break }
        active[selected] = false
        removed.append(selected)
        let membership = communityComponents(graph, active: active)
        let q = graph.modularity(membership, resolution: resolution)
        history.append(q)
        if q > bestQ + 1e-12 {
            bestQ = q
            best = membership
        }
    }
    return CommunityOutput(membership: best, merges: [], removed: removed, history: history)
}

/// Brandes accumulation on inverse-strength shortest paths, recalculated by Girvan–Newman.
func communityEdgeBetweenness(_ graph: GlifiPreparedCommunityGraph, active: [Bool]) throws
    -> [Double]
{
    var scores = [Double](repeating: 0, count: graph.edges.count)
    for source in 0..<graph.count {
        try Task.checkCancellation()
        var distances = [Double](repeating: .infinity, count: graph.count)
        var paths = [Double](repeating: 0, count: graph.count)
        var predecessors = [[(node: Int, edge: Int)]](repeating: [], count: graph.count)
        var settled = [Bool](repeating: false, count: graph.count)
        var order: [Int] = []
        var heap = GlifiGraphPriorityQueue<(distance: Double, node: Int)> {
            $0.distance == $1.distance ? $0.node < $1.node : $0.distance < $1.distance
        }
        distances[source] = 0
        paths[source] = 1
        heap.insert((0, source))
        while let next = heap.removeFirst() {
            guard !settled[next.node], next.distance == distances[next.node] else { continue }
            settled[next.node] = true
            order.append(next.node)
            for neighbor in graph.adjacency[next.node] where active[neighbor.edge] {
                let distance = next.distance + 1 / graph.edges[neighbor.edge].weight
                guard distance.isFinite, distance > next.distance else {
                    throw graphAlgorithmFailure("network.numeric-range")
                }
                if distance < distances[neighbor.node] {
                    distances[neighbor.node] = distance
                    paths[neighbor.node] = paths[next.node]
                    predecessors[neighbor.node] = [(next.node, neighbor.edge)]
                    heap.insert((distance, neighbor.node))
                } else if distance == distances[neighbor.node] {
                    paths[neighbor.node] += paths[next.node]
                    guard paths[neighbor.node].isFinite else {
                        throw graphAlgorithmFailure("network.path-count-overflow")
                    }
                    predecessors[neighbor.node].append((next.node, neighbor.edge))
                }
            }
        }
        var dependency = [Double](repeating: 0, count: graph.count)
        for node in order.reversed() {
            for predecessor in predecessors[node] {
                let contribution = paths[predecessor.node] / paths[node] * (1 + dependency[node])
                scores[predecessor.edge] += contribution / 2
                dependency[predecessor.node] += contribution
            }
        }
    }
    return scores
}
