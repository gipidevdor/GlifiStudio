// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test(
    "Le comunità native separano due triangoli e conservano la modularità esatta",
    arguments: GlifiCommunityMethod.allCases)
func graphCompletionCommunities(_ method: GlifiCommunityMethod) throws {
    let graph = try completionGraph(
        6,
        [
            (0, 1, 1), (0, 2, 1), (1, 2, 1), (2, 3, 1),
            (3, 4, 1), (3, 5, 1), (4, 5, 1),
        ])
    let result = try GlifiNetworkAnalysis.communities(graph, method: method)
    #expect(result.communityCount == 2)
    #expect((0..<6).map { result.communityByNode[$0] } == [0, 0, 0, 1, 1, 1])
    #expect(abs(result.modularity - 5.0 / 14) < 1e-12)
    #expect(abs(result.modularity - completionModularity(graph, result.communityByNode)) < 1e-12)
    #expect(abs((result.modularityHistory.max() ?? -1) - result.modularity) < 1e-12)
    let renamed = try GlifiDirectedGraph(
        nodes: graph.nodes.map { "node-\($0)" },
        edges: graph.edges.reversed().map {
            GlifiGraphEdge(
                source: "node-\($0.source)", target: "node-\($0.target)", weight: $0.weight)
        })
    let other = try GlifiNetworkAnalysis.communities(renamed, method: method)
    #expect(
        graph.nodes.map { result.communityByNode[$0] }
            == renamed.nodes.map { other.communityByNode[$0] })
    #expect(result.modularityHistory == other.modularityHistory)
}

@Test("La betweenness degli archi coincide con l'enumerazione di tutti i cammini minimi")
func graphCompletionBetweennessExhaustive() throws {
    let pairs = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]
    for mask in 0..<64 {
        let graph = try completionGraph(
            4,
            pairs.enumerated().compactMap {
                mask & (1 << $0.offset) == 0 ? nil : ($0.element.0, $0.element.1, 1.0)
            })
        let prepared = try GlifiPreparedCommunityGraph(graph, limits: .standard)
        let actual = try communityEdgeBetweenness(
            prepared, active: Array(repeating: true, count: prepared.edges.count))
        let expected = completionEnumeratedBetweenness(prepared)
        #expect(zip(actual, expected).allSatisfy { abs($0 - $1) < 1e-12 })
    }
    let graph = try completionGraph(4, [(0, 1, 2), (0, 2, 1), (1, 2, 2), (1, 3, 1), (2, 3, 2)])
    let prepared = try GlifiPreparedCommunityGraph(graph, limits: .standard)
    let actual = try communityEdgeBetweenness(
        prepared, active: Array(repeating: true, count: prepared.edges.count))
    #expect(
        zip(actual, completionEnumeratedBetweenness(prepared)).allSatisfy { abs($0 - $1) < 1e-12 })
}

@Test("CNM sceglie a ogni passo il massimo guadagno di modularità, verificato indipendentemente")
func graphCompletionGreedyOracle() throws {
    var generator = GlifiSplitMix64(seed: 0x474E_434E_4D)
    for _ in 0..<48 {
        var edges: [(Int, Int, Double)] = []
        for left in 0..<6 {
            for right in 0..<left where generator.next().isMultiple(of: 2) {
                edges.append((left, right, Double(generator.next() % 5 + 1)))
            }
        }
        let graph = try completionGraph(6, edges)
        let result = try GlifiNetworkAnalysis.communities(graph, method: .fastGreedy)
        var membership = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, $0) })
        for merge in result.merges {
            let current = completionModularity(graph, membership)
            var bestGain = -Double.infinity
            for edge in graph.edges where membership[edge.source] != membership[edge.target] {
                let a = membership[edge.source] ?? -1
                let b = membership[edge.target] ?? -1
                let candidate = membership.mapValues { $0 == b ? a : $0 }
                bestGain = max(bestGain, completionModularity(graph, candidate) - current)
            }
            membership = membership.mapValues { $0 == merge.right ? merge.left : $0 }
            #expect(completionModularity(graph, membership) - current >= bestGain - 1e-12)
        }
        #expect(
            abs(result.modularity - completionModularity(graph, result.communityByNode)) < 1e-12)
    }
}

@Test("Prim conserva costi nulli, componenti e minimo globale verificato per enumerazione")
func graphCompletionSpanningTree() throws {
    var generator = GlifiSplitMix64(seed: 0x5052_494D)
    for _ in 0..<32 {
        var edges: [(Int, Int, Double)] = []
        for left in 0..<5 {
            for right in 0..<left { edges.append((left, right, Double(generator.next() % 11))) }
        }
        let graph = try completionGraph(5, edges)
        let result = try GlifiNetworkAnalysis.minimumSpanningTree(graph)
        #expect(result.edges.count == 4)
        #expect(result.componentCount == 1)
        #expect(result.totalWeight == completionEnumeratedTreeWeight(graph))
    }
    let disconnected = try completionGraph(5, [(0, 1, 3), (1, 0, 0), (2, 3, 2), (3, 3, 0)])
    let forest = try GlifiNetworkAnalysis.minimumSpanningForest(disconnected)
    #expect(forest.totalWeight == 2)
    #expect(forest.componentCount == 3)
    #expect(forest.edges.count == 2)
    #expect(throws: GlifiFailure.self) {
        try GlifiNetworkAnalysis.minimumSpanningTree(disconnected)
    }
    let overflow = try completionGraph(
        3, [(0, 1, .greatestFiniteMagnitude), (1, 2, .greatestFiniteMagnitude)])
    #expect(throws: GlifiFailure.self) { try GlifiNetworkAnalysis.minimumSpanningTree(overflow) }
}

@Test("Walktrap sceglie l'incremento Ward minimo rispetto a potenze Markov dense indipendenti")
func graphCompletionWalktrapOracle() throws {
    var generator = GlifiSplitMix64(seed: 0x5741_4C4B)
    for _ in 0..<32 {
        var edges: [(Int, Int, Double)] = []
        for left in 0..<6 {
            for right in 0..<left where generator.next().isMultiple(of: 2) {
                edges.append((left, right, Double(generator.next() % 4 + 1)))
            }
        }
        let graph = try completionGraph(6, edges)
        let profiles = completionDenseWalkProfiles(graph, length: 4)
        let result = try GlifiNetworkAnalysis.communities(graph, method: .walktrap)
        var leaders = Array(0..<6)
        func ward(_ first: Int, _ second: Int) -> Double {
            let a = leaders.indices.filter { leaders[$0] == first }
            let b = leaders.indices.filter { leaders[$0] == second }
            let square = (0..<6).reduce(0.0) { sum, axis in
                let x = a.reduce(0.0) { $0 + profiles[$1][axis] } / Double(a.count)
                let y = b.reduce(0.0) { $0 + profiles[$1][axis] } / Double(b.count)
                return sum + (x - y) * (x - y)
            }
            return Double(a.count * b.count) / Double(a.count + b.count) * square
        }
        for merge in result.merges {
            var minimum = Double.infinity
            for edge in graph.edges where leaders[edge.source] != leaders[edge.target] {
                minimum = min(minimum, ward(leaders[edge.source], leaders[edge.target]))
            }
            #expect(ward(merge.left, merge.right) <= minimum + 1e-12)
            for node in leaders.indices where leaders[node] == merge.right {
                leaders[node] = merge.left
            }
        }
    }
}

@Test(
    "I layout sono deterministici, finiti e dichiarano il criterio di arresto",
    arguments: GlifiGraphLayoutMethod.allCases)
func graphCompletionLayouts(_ method: GlifiGraphLayoutMethod) throws {
    let graph = try completionGraph(6, [(0, 1, 1), (1, 2, 1), (2, 0, 1), (3, 4, 1)])
    let result = try GlifiNetworkAnalysis.layout(
        graph, method: method, seed: 42, maximumIterations: 80)
    let repeated = try GlifiNetworkAnalysis.layout(
        graph, method: method, seed: 42, maximumIterations: 80)
    #expect(result.positions == repeated.positions)
    #expect(result.positions.count == 6)
    #expect(result.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    #expect(result.iterations <= 80)
    #expect(
        zip(result.energyHistory, result.energyHistory.dropFirst()).allSatisfy { $1 <= $0 + 1e-12 })
    if method == .fruchtermanReingold {
        #expect(result.positions.allSatisfy { abs($0.x) <= 1 && abs($0.y) <= 1 })
    }
    let singleton = try completionGraph(1, [])
    #expect(
        try GlifiNetworkAnalysis.layout(singleton, method: method).positions == [
            GlifiGraphPoint(x: 0, y: 0)
        ])
}

@Test(
    "Kamada–Kawai riconosce l'equilibrio esatto e riduce l'energia di una configurazione perturbata"
)
func graphCompletionKamadaKawaiEnergy() throws {
    let graph = try completionGraph(2, [(0, 1, 1)])
    let exact = try GlifiNetworkAnalysis.layout(
        graph, method: .kamadaKawai,
        initialPositions: [GlifiGraphPoint(x: -0.5, y: 0), GlifiGraphPoint(x: 0.5, y: 0)])
    #expect(exact.converged)
    #expect(exact.iterations == 0)
    #expect(exact.energyHistory == [0])
    let perturbed = try GlifiNetworkAnalysis.layout(
        graph, method: .kamadaKawai,
        initialPositions: [GlifiGraphPoint(x: -0.1, y: 0), GlifiGraphPoint(x: 0.1, y: 0)])
    #expect(perturbed.converged)
    #expect((perturbed.energyHistory.last ?? 1) < 1e-12)
    let first = try #require(perturbed.positions.first)
    let last = try #require(perturbed.positions.last)
    #expect(abs(hypot(first.x - last.x, first.y - last.y) - 1) < 1e-6)
}

@Test("Simpson distingue sottoinsiemi, vuoti e dissimilarità non metrica")
func graphCompletionSimpson() {
    let empty: Set<Int> = []
    #expect(GlifiSetSimilarity.simpson(empty, empty) == 1)
    #expect(GlifiSetSimilarity.simpson(empty, [1]) == 0)
    #expect(GlifiSetSimilarity.simpson([1], [1, 2]) == 1)
    #expect(GlifiSetSimilarity.simpson([1, 2, 3], [2, 3, 4, 5]) == 2.0 / 3)
    #expect(GlifiSetSimilarity.simpsonDistance([1], [2]) == 1)
    #expect(
        GlifiSetSimilarity.simpsonDistance([1], [1, 2])
            + GlifiSetSimilarity.simpsonDistance([1, 2], [2]) == 0)
}

@Test("La matrice Simpson usa la presenza e mantiene la convenzione degli insiemi vuoti")
func graphCompletionSimpsonMatrix() throws {
    let matrix = [[2.0, 1, 0], [3, 0, 0], [0, 0, 0]]
    #expect(
        try GlifiTextMatrixOperators.dissimilarities(matrix, metric: .simpson)
            == [[0, 0, 1], [0, 0, 1], [1, 1, 0]])
}

@Test(
    "I kernel rifiutano budget e parametri prima delle allocazioni principali e propagano la cancellazione"
)
func graphCompletionAdmissionAndCancellation() async throws {
    let graph = try completionGraph(4, [(0, 1, 1), (1, 2, 1), (2, 3, 1)])
    let limits = GlifiGraphAlgorithmLimits(maximumPairwiseCells: 1)
    #expect(throws: GlifiFailure.self) {
        try GlifiNetworkAnalysis.communities(graph, method: .walktrap, limits: limits)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiNetworkAnalysis.layout(graph, method: .kamadaKawai, limits: limits)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiNetworkAnalysis.communities(graph, method: .fastGreedy, resolution: .nan)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiNetworkAnalysis.layout(graph, method: .fruchtermanReingold, maximumIterations: 0)
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiNetworkAnalysis.communities(graph, method: .fastGreedy)
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled community work succeeded")
    } catch is CancellationError {}
}

private func completionGraph(_ count: Int, _ edges: [(Int, Int, Double)]) throws
    -> GlifiDirectedGraph<Int>
{
    try GlifiDirectedGraph(
        nodes: Array(0..<count),
        edges: edges.map { GlifiGraphEdge(source: $0.0, target: $0.1, weight: $0.2) })
}

private func completionModularity(_ graph: GlifiDirectedGraph<Int>, _ membership: [Int: Int])
    -> Double
{
    let total = graph.edges.filter { $0.source != $0.target }.reduce(0) { $0 + $1.weight }
    guard total > 0 else { return 0 }
    var strength = [Double](repeating: 0, count: graph.nodes.count)
    var internalWeight = 0.0
    for edge in graph.edges where edge.source != edge.target {
        strength[edge.source] += edge.weight
        strength[edge.target] += edge.weight
        if membership[edge.source] == membership[edge.target] { internalWeight += edge.weight }
    }
    let labels = Set(membership.values)
    let expected = labels.reduce(0.0) { sum, label in
        let fraction =
            graph.nodes.filter { membership[$0] == label }.reduce(0.0) { $0 + strength[$1] }
            / (2 * total)
        return sum + fraction * fraction
    }
    return internalWeight / total - expected
}

private func completionEnumeratedBetweenness(_ graph: GlifiPreparedCommunityGraph) -> [Double] {
    var result = [Double](repeating: 0, count: graph.edges.count)
    for source in 0..<graph.count {
        for target in 0..<source {
            var best = Double.infinity
            var paths: [[Int]] = []
            func visit(_ node: Int, cost: Double, seen: Set<Int>, edges: [Int]) {
                if node == target {
                    if cost < best {
                        best = cost
                        paths = [edges]
                    } else if cost == best {
                        paths.append(edges)
                    }
                    return
                }
                guard cost <= best else { return }
                for neighbor in graph.adjacency[node] where !seen.contains(neighbor.node) {
                    visit(
                        neighbor.node, cost: cost + 1 / graph.edges[neighbor.edge].weight,
                        seen: seen.union([neighbor.node]), edges: edges + [neighbor.edge])
                }
            }
            visit(source, cost: 0, seen: [source], edges: [])
            for path in paths { for edge in path { result[edge] += 1 / Double(paths.count) } }
        }
    }
    return result
}

private func completionEnumeratedTreeWeight(_ graph: GlifiDirectedGraph<Int>) -> Double {
    var best = Double.infinity
    for mask in 0..<(1 << graph.edges.count) where mask.nonzeroBitCount == graph.nodes.count - 1 {
        var labels = Array(graph.nodes.indices)
        var weight = 0.0
        for (index, edge) in graph.edges.enumerated() where mask & (1 << index) != 0 {
            let from = labels[edge.source]
            let to = labels[edge.target]
            for node in labels.indices where labels[node] == to { labels[node] = from }
            weight += edge.weight
        }
        if Set(labels).count == 1 { best = min(best, weight) }
    }
    return best
}

private func completionDenseWalkProfiles(_ graph: GlifiDirectedGraph<Int>, length: Int)
    -> [[Double]]
{
    let n = graph.nodes.count
    var adjacency = Array(repeating: Array(repeating: 0.0, count: n), count: n)
    for edge in graph.edges where edge.source != edge.target {
        adjacency[edge.source][edge.target] += edge.weight
        adjacency[edge.target][edge.source] += edge.weight
    }
    for node in 0..<n {
        let count = adjacency[node].filter { $0 > 0 }.count
        adjacency[node][node] = count == 0 ? 1 : adjacency[node].reduce(0, +) / Double(count)
    }
    let degrees = adjacency.map { $0.reduce(0, +) }
    let transition = adjacency.enumerated().map { row, values in values.map { $0 / degrees[row] } }
    var power = Array(repeating: Array(repeating: 0.0, count: n), count: n)
    for node in 0..<n { power[node][node] = 1 }
    for _ in 0..<length {
        var next = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for row in 0..<n {
            for column in 0..<n {
                for middle in 0..<n {
                    next[row][column] += power[row][middle] * transition[middle][column]
                }
            }
        }
        power = next
    }
    return power.map { row in row.enumerated().map { $0.element / sqrt(degrees[$0.offset]) } }
}
