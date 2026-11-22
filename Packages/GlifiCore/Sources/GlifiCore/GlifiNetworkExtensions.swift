// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Connected components of a directed graph.
public struct GlifiComponentsResult<Node: Hashable & Sendable>: Sendable {
    /// `WeakComponents-v1` identity.
    public static var weakIdentifier: String { "WeakComponents-v1" }
    /// `StrongComponents-v1` identity.
    public static var strongIdentifier: String { "StrongComponents-v1" }

    /// Component index per node; components are numbered by first appearance in node order.
    public let componentByNode: [Node: Int]
    /// Number of components.
    public let componentCount: Int
}

/// Principal-eigenvector centrality.
public struct GlifiEigenvectorResult<Node: Hashable & Sendable>: Sendable {
    /// `EigenvectorCentrality-v1` identity.
    public static var identifier: String { "EigenvectorCentrality-v1" }

    /// Scores scaled so that the largest is 1.
    public let scores: [Node: Double]
    /// Principal eigenvalue of the weighted adjacency.
    public let eigenvalue: Double
    /// Iterations performed.
    public let iterations: Int
    /// Whether the iteration met its tolerance.
    public let converged: Bool
}

/// Community partition with its modularity.
public struct GlifiCommunityResult<Node: Hashable & Sendable>: Sendable {
    /// `Louvain-v1` identity.
    public static var identifier: String { "Louvain-v1" }

    /// Community index per node, numbered by first appearance in node order.
    public let communityByNode: [Node: Int]
    /// Number of communities.
    public let communityCount: Int
    /// `Q = Σ_c [L_c/m - (d_c/2m)²]` of the returned partition.
    public let modularity: Double
}

extension GlifiNetworkAnalysis {
    /// Distance of a weighted edge for path-based measures: `1/weight`.
    public static let inverseWeightDistanceIdentifier = "inverse-weight-distance-v1"

    /// `WeakComponents-v1`: components ignoring edge direction (union–find).
    public static func weakComponents<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiComponentsResult<Node> {
        let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        var parent = Array(graph.nodes.indices)
        func root(_ value: Int) -> Int {
            var current = value
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }
        for edge in graph.edges {
            guard let source = index[edge.source], let target = index[edge.target] else { continue }
            let left = root(source)
            let right = root(target)
            if left != right { parent[max(left, right)] = min(left, right) }
        }
        return numberedComponents(graph.nodes) { root(index[$0] ?? 0) }
    }

    /// `StrongComponents-v1`: Tarjan's algorithm, iterative.
    public static func strongComponents<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiComponentsResult<Node> {
        let count = graph.nodes.count
        let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        var adjacency = [[Int]](repeating: [], count: count)
        for edge in graph.edges {
            guard let source = index[edge.source], let target = index[edge.target] else { continue }
            adjacency[source].append(target)
        }
        var order = [Int](repeating: -1, count: count)
        var low = [Int](repeating: 0, count: count)
        var onStack = [Bool](repeating: false, count: count)
        var stack: [Int] = []
        var label = [Int](repeating: -1, count: count)
        var counter = 0
        var components = 0
        for start in 0..<count where order[start] == -1 {
            var work: [(node: Int, next: Int)] = [(start, 0)]
            order[start] = counter
            low[start] = counter
            counter += 1
            stack.append(start)
            onStack[start] = true
            while let top = work.last {
                let node = top.node
                if top.next < adjacency[node].count {
                    work[work.count - 1].next += 1
                    let neighbor = adjacency[node][top.next]
                    if order[neighbor] == -1 {
                        order[neighbor] = counter
                        low[neighbor] = counter
                        counter += 1
                        stack.append(neighbor)
                        onStack[neighbor] = true
                        work.append((neighbor, 0))
                    } else if onStack[neighbor] {
                        low[node] = min(low[node], order[neighbor])
                    }
                } else {
                    work.removeLast()
                    if let parent = work.last?.node {
                        low[parent] = min(low[parent], low[node])
                    }
                    if low[node] == order[node] {
                        while let member = stack.popLast() {
                            onStack[member] = false
                            label[member] = components
                            if member == node { break }
                        }
                        components += 1
                    }
                }
            }
        }
        return numberedComponents(graph.nodes) { label[index[$0] ?? 0] }
    }

    /// `EigenvectorCentrality-v1`: principal eigenvector of the weighted in-adjacency.
    ///
    /// Power iteration on `A + I` from the uniform vector (the shift keeps the dominant
    /// eigenvector and avoids oscillation on bipartite graphs); scores scaled to max 1.
    /// Parallel edges add their weights; self-loops are included.
    public static func eigenvectorCentrality<Node>(
        _ graph: GlifiDirectedGraph<Node>,
        tolerance: Double = 1e-13,
        maximumIterations: Int = 10_000
    ) throws -> GlifiEigenvectorResult<Node> {
        let count = graph.nodes.count
        guard count > 0 else {
            throw networkFailure("network.empty-graph", category: .insufficientData)
        }
        guard graph.edges.contains(where: { $0.weight > 0 }) else {
            throw networkFailure("network.no-weighted-edges", category: .insufficientData)
        }
        let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        var incoming = [[(Int, Double)]](repeating: [], count: count)
        for edge in graph.edges {
            guard let source = index[edge.source], let target = index[edge.target] else { continue }
            incoming[target].append((source, edge.weight))
        }
        var vector = [Double](repeating: 1 / Double(count).squareRoot(), count: count)
        var iterations = 0
        var converged = false
        while iterations < maximumIterations {
            iterations += 1
            var next = vector
            for node in 0..<count {
                for (source, weight) in incoming[node] { next[node] += weight * vector[source] }
            }
            let norm = next.reduce(0) { $0 + $1 * $1 }.squareRoot()
            guard norm > 0 else { break }
            next = next.map { $0 / norm }
            let change = zip(next, vector).reduce(0) { max($0, abs($1.0 - $1.1)) }
            vector = next
            if change < tolerance {
                converged = true
                break
            }
        }
        // Quoziente di Rayleigh su A (senza lo shift) per l'autovalore principale.
        var product = [Double](repeating: 0, count: count)
        for node in 0..<count {
            for (source, weight) in incoming[node] { product[node] += weight * vector[source] }
        }
        let eigenvalue = zip(product, vector).reduce(0) { $0 + $1.0 * $1.1 }
        let largest = vector.max() ?? 1
        return GlifiEigenvectorResult(
            scores: Dictionary(
                uniqueKeysWithValues: graph.nodes.enumerated().map {
                    ($1, largest > 0 ? vector[$0] / largest : 0)
                }
            ),
            eigenvalue: eigenvalue,
            iterations: iterations,
            converged: converged
        )
    }

    /// `WeightedBetweenness-v1`: Brandes with Dijkstra over `inverse-weight-distance-v1`.
    ///
    /// Edges with weight zero are not traversable; parallel edges keep the shortest distance.
    /// Path lengths within a relative tolerance of `1e-12` count as equal.
    public static func weightedBetweenness<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiBetweennessResult<Node> {
        let (nodes, adjacency) = weightedAdjacency(graph)
        var scores = [Double](repeating: 0, count: nodes.count)
        for source in nodes.indices {
            let paths = shortestPaths(from: source, adjacency: adjacency)
            var dependency = [Double](repeating: 0, count: nodes.count)
            for node in paths.order.reversed() where node != source {
                for predecessor in paths.predecessors[node] {
                    dependency[predecessor] +=
                        paths.sigma[predecessor] / paths.sigma[node] * (1 + dependency[node])
                }
                scores[node] += dependency[node]
            }
        }
        return GlifiBetweennessResult(
            scores: Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1, scores[$0]) })
        )
    }

    /// `WeightedHarmonicCloseness-v1`: `Σ 1/d(v,u)` with `inverse-weight-distance-v1`.
    public static func weightedHarmonicCloseness<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> GlifiHarmonicClosenessResult<Node> {
        let (nodes, adjacency) = weightedAdjacency(graph)
        var scores: [Node: Double] = [:]
        for source in nodes.indices {
            let paths = shortestPaths(from: source, adjacency: adjacency)
            scores[nodes[source]] = paths.distance.enumerated().reduce(0) { total, entry in
                guard entry.offset != source, entry.element.isFinite, entry.element > 0 else {
                    return total
                }
                return total + 1 / entry.element
            }
        }
        return GlifiHarmonicClosenessResult(scores: scores)
    }

    /// Modularity of a partition of the undirected graph obtained by adding both directions.
    ///
    /// Edge weights are symmetrized as `w_uv = (A_uv + A_vu)/2`, self-loops excluded.
    public static func modularity<Node>(
        _ graph: GlifiDirectedGraph<Node>,
        communityByNode: [Node: Int]
    ) -> Double {
        let (nodes, weights) = undirectedWeights(graph)
        let community = nodes.map { communityByNode[$0] ?? -1 }
        return modularity(weights: weights, community: community)
    }

    /// `Louvain-v1`: deterministic Louvain optimization of modularity.
    ///
    /// Nodes are visited in declared order; a move is accepted only for a strict gain larger
    /// than `1e-12`, ties keep the current community; levels repeat until no improvement.
    public static func louvain<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) throws -> GlifiCommunityResult<Node> {
        let (nodes, weights) = undirectedWeights(graph)
        let total = weights.reduce(0) { $0 + $1.reduce(0) { $0 + $1.weight } }
        guard total > 0 else {
            throw networkFailure("network.no-weighted-edges", category: .insufficientData)
        }
        var membership = Array(nodes.indices)
        var levelWeights = weights
        while true {
            let (assignment, improved) = louvainLevel(levelWeights)
            guard improved else { break }
            membership = membership.map { assignment[$0] }
            let groupCount = (assignment.max() ?? -1) + 1
            var aggregated = [[Int: Double]](repeating: [:], count: groupCount)
            for row in levelWeights.indices {
                for entry in levelWeights[row] {
                    aggregated[assignment[row]][assignment[entry.column], default: 0] +=
                        entry.weight
                }
            }
            levelWeights = aggregated.map(Self.sortedRow)
            if groupCount == 1 { break }
        }
        var renumber: [Int: Int] = [:]
        let final = membership.map { value -> Int in
            if let existing = renumber[value] { return existing }
            let next = renumber.count
            renumber[value] = next
            return next
        }
        return GlifiCommunityResult(
            communityByNode: Dictionary(
                uniqueKeysWithValues: nodes.enumerated().map { ($1, final[$0]) }),
            communityCount: renumber.count,
            modularity: modularity(weights: weights, community: final)
        )
    }

    // MARK: - Private helpers

    private static func numberedComponents<Node>(
        _ nodes: [Node],
        label: (Node) -> Int
    ) -> GlifiComponentsResult<Node> {
        var renumber: [Int: Int] = [:]
        var result: [Node: Int] = [:]
        for node in nodes {
            let raw = label(node)
            if renumber[raw] == nil { renumber[raw] = renumber.count }
            result[node] = renumber[raw]
        }
        return GlifiComponentsResult(componentByNode: result, componentCount: renumber.count)
    }

    private static func weightedAdjacency<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> (nodes: [Node], adjacency: [[(Int, Double)]]) {
        let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        var best: [[Int: Double]] = Array(repeating: [:], count: graph.nodes.count)
        for edge in graph.edges where edge.source != edge.target && edge.weight > 0 {
            guard let source = index[edge.source], let target = index[edge.target] else { continue }
            let distance = 1 / edge.weight
            best[source][target] = min(best[source][target] ?? .infinity, distance)
        }
        return (graph.nodes, best.map { $0.sorted { $0.key < $1.key }.map { ($0.key, $0.value) } })
    }

    private static func shortestPaths(
        from source: Int,
        adjacency: [[(Int, Double)]]
    ) -> (distance: [Double], sigma: [Double], predecessors: [[Int]], order: [Int]) {
        let count = adjacency.count
        var distance = [Double](repeating: .infinity, count: count)
        var sigma = [Double](repeating: 0, count: count)
        var predecessors = [[Int]](repeating: [], count: count)
        var settled = [Bool](repeating: false, count: count)
        var order: [Int] = []
        distance[source] = 0
        sigma[source] = 1
        func equal(_ left: Double, _ right: Double) -> Bool {
            left.isFinite && right.isFinite
                && abs(left - right) <= 1e-12 * max(1, abs(left), abs(right))
        }
        // Dijkstra con heap binario su (distanza, nodo): O((V+E) log V), estrazione
        // deterministica; voci obsolete scartate alla lettura.
        var heap = GlifiMinimumHeap()
        heap.push(0, source)
        while let (value, current) = heap.pop() {
            guard !settled[current], value == distance[current] else { continue }
            settled[current] = true
            order.append(current)
            for (neighbor, length) in adjacency[current] where !settled[neighbor] {
                let candidate = distance[current] + length
                if equal(candidate, distance[neighbor]) {
                    sigma[neighbor] += sigma[current]
                    predecessors[neighbor].append(current)
                } else if candidate < distance[neighbor] {
                    distance[neighbor] = candidate
                    sigma[neighbor] = sigma[current]
                    predecessors[neighbor] = [current]
                    heap.push(candidate, neighbor)
                }
            }
        }
        return (distance, sigma, predecessors, order)
    }

    /// Sparse symmetric adjacency: one ascending `(column, weight)` list per node.
    typealias SparseRows = [[(column: Int, weight: Double)]]

    private static func sortedRow(_ row: [Int: Double]) -> [(column: Int, weight: Double)] {
        row.sorted { $0.key < $1.key }.map { (column: $0.key, weight: $0.value) }
    }

    private static func undirectedWeights<Node>(
        _ graph: GlifiDirectedGraph<Node>
    ) -> (nodes: [Node], weights: SparseRows) {
        let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
        var rows = [[Int: Double]](repeating: [:], count: graph.nodes.count)
        for edge in graph.edges where edge.source != edge.target {
            guard let source = index[edge.source], let target = index[edge.target] else { continue }
            rows[source][target, default: 0] += edge.weight / 2
            rows[target][source, default: 0] += edge.weight / 2
        }
        return (graph.nodes, rows.map(sortedRow))
    }

    private static func modularity(weights: SparseRows, community: [Int]) -> Double {
        let degrees = weights.map { $0.reduce(0) { $0 + $1.weight } }
        let twiceTotal = degrees.reduce(0, +)
        guard twiceTotal > 0 else { return 0 }
        var internalWeight: [Int: Double] = [:]
        var communityDegree: [Int: Double] = [:]
        for row in weights.indices {
            communityDegree[community[row], default: 0] += degrees[row]
            for entry in weights[row] where community[row] == community[entry.column] {
                internalWeight[community[row], default: 0] += entry.weight
            }
        }
        // Somma in ordine di comunità: l'ordine delle chiavi di un dizionario non è riproducibile.
        return communityDegree.keys.sorted().reduce(0) { total, key in
            let fraction = (communityDegree[key] ?? 0) / twiceTotal
            return total + (internalWeight[key] ?? 0) / twiceTotal - fraction * fraction
        }
    }

    private static func louvainLevel(_ weights: SparseRows) -> ([Int], Bool) {
        let count = weights.count
        let degrees = weights.map { $0.reduce(0) { $0 + $1.weight } }
        let twiceTotal = degrees.reduce(0, +)
        var community = Array(0..<count)
        var communityDegree = degrees
        var improved = false
        var moved = true
        var passes = 0
        while moved, passes < 1_000 {
            moved = false
            passes += 1
            for node in 0..<count {
                let current = community[node]
                var links: [Int: Double] = [:]
                for entry in weights[node] where entry.column != node && entry.weight != 0 {
                    links[community[entry.column], default: 0] += entry.weight
                }
                communityDegree[current] -= degrees[node]
                func gain(_ target: Int) -> Double {
                    (links[target] ?? 0) - communityDegree[target] * degrees[node] / twiceTotal
                }
                var best = current
                var bestGain = gain(current)
                for target in links.keys.sorted() where target != current {
                    let value = gain(target)
                    if value > bestGain + 1e-12 {
                        best = target
                        bestGain = value
                    }
                }
                communityDegree[best] += degrees[node]
                if best != current {
                    community[node] = best
                    moved = true
                    improved = true
                }
            }
        }
        var renumber: [Int: Int] = [:]
        let assignment = community.map { value -> Int in
            if let existing = renumber[value] { return existing }
            let next = renumber.count
            renumber[value] = next
            return next
        }
        return (assignment, improved)
    }
}

/// Binary min-heap of `(distance, node)` ordered by distance, then node index.
struct GlifiMinimumHeap {
    private var items: [(Double, Int)] = []

    private static func precedes(_ left: (Double, Int), _ right: (Double, Int)) -> Bool {
        left.0 == right.0 ? left.1 < right.1 : left.0 < right.0
    }

    mutating func push(_ value: Double, _ node: Int) {
        items.append((value, node))
        var child = items.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard Self.precedes(items[child], items[parent]) else { break }
            items.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> (Double, Int)? {
        guard let first = items.first else { return nil }
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var parent = 0
            while true {
                let left = 2 * parent + 1
                let right = left + 1
                var smallest = parent
                if left < items.count, Self.precedes(items[left], items[smallest]) {
                    smallest = left
                }
                if right < items.count, Self.precedes(items[right], items[smallest]) {
                    smallest = right
                }
                guard smallest != parent else { break }
                items.swapAt(parent, smallest)
                parent = smallest
            }
        }
        return first
    }
}
