// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("La centralità armonica indicizzata coincide bitwise con la visita generica originale")
func harmonicTraversalMatchesLegacyBitsOnSyntheticGraphs() throws {
    for seed in 1...12 {
        var generator = GlifiSplitMix64(seed: UInt64(seed + 173))
        let count = 7 + seed * 3
        let identities = (0..<count).map { $0 * 17 - 500 }
        var nodes = identities
        for index in stride(from: nodes.count - 1, through: 1, by: -1) {
            nodes.swapAt(index, generator.index(below: index + 1))
        }
        var edges: [GlifiGraphEdge<Int>] = []
        for index in 0..<(count * 8) {
            let edge = GlifiGraphEdge(
                source: identities[generator.index(below: count)],
                target: identities[generator.index(below: count)],
                weight: index.isMultiple(of: 3) ? 0 : Double(index % 11))
            edges.append(edge)
            if index.isMultiple(of: 7) { edges.append(edge) }
        }
        expectLegacyHarmonicBits(try GlifiDirectedGraph(nodes: nodes, edges: edges))
    }
}

@Test("La riduzione armonica segue i nodi dichiarati anche quando l'ordine BFS cambia i bit")
func harmonicTraversalKeepsDeclaredReductionOrder() throws {
    let order = [4, 2, 6, 0, 5, 1, 7, 3]
    let graph = try GlifiDirectedGraph(
        nodes: order,
        edges: (0..<7).map { GlifiGraphEdge(source: $0, target: $0 + 1, weight: 0) })
    let declared = order.filter { $0 != 0 }.reduce(0.0) { $0 + 1 / Double($1) }
    let breadthFirst = (1..<8).reduce(0.0) { $0 + 1 / Double($1) }
    #expect(declared.bitPattern != breadthFirst.bitPattern)
    let actual = GlifiNetworkAnalysis.harmonicCloseness(graph)
    #expect(actual.scores[0]?.bitPattern == declared.bitPattern)
    expectLegacyHarmonicBits(graph)
    expectFloydHarmonicBits(graph)
}

@Test("Tutti i 4096 digrafi semplici di quattro nodi coincidono con Floyd–Warshall")
func harmonicTraversalMatchesEveryFourNodeDigraph() throws {
    let labels = [30, -5, 12, 0]
    let nodeOrder = [labels[2], labels[0], labels[3], labels[1]]
    let possibleEdges = (0..<4).flatMap { source in
        (0..<4).filter { $0 != source }.map { (source, $0) }
    }
    for mask in 0..<(1 << possibleEdges.count) {
        var edges: [GlifiGraphEdge<Int>] = []
        for (index, endpoints) in possibleEdges.enumerated() where mask & (1 << index) != 0 {
            edges.append(
                GlifiGraphEdge(
                    source: labels[endpoints.0], target: labels[endpoints.1],
                    weight: index.isMultiple(of: 3) ? 0 : 1))
        }
        expectFloydHarmonicBits(try GlifiDirectedGraph(nodes: nodeOrder, edges: edges))
    }
}

@Test("Identità in collisione, archi zero, paralleli e self-loop preservano le distanze hop")
func harmonicTraversalHandlesCollidingIdentitiesAndHopSemantics() throws {
    let head = HarmonicCollisionNode(label: "日本語")
    let middle = HarmonicCollisionNode(label: "e\u{301}")
    let tail = HarmonicCollisionNode(label: "z")
    let isolated = HarmonicCollisionNode(label: "β")
    let graph = try GlifiDirectedGraph(
        nodes: [tail, head, isolated, middle],
        edges: [
            GlifiGraphEdge(source: head, target: middle, weight: 0),
            GlifiGraphEdge(source: head, target: middle, weight: .greatestFiniteMagnitude),
            GlifiGraphEdge(source: middle, target: tail, weight: 0),
            GlifiGraphEdge(source: middle, target: middle, weight: .leastNonzeroMagnitude),
            GlifiGraphEdge(source: tail, target: head, weight: 7),
            GlifiGraphEdge(source: isolated, target: isolated, weight: 0),
        ])
    let result = GlifiNetworkAnalysis.harmonicCloseness(graph)
    for node in [head, middle, tail] { #expect(result.scores[node] == 1.5) }
    #expect(result.scores[isolated]?.bitPattern == 0)
    expectLegacyHarmonicBits(graph)
    expectFloydHarmonicBits(graph)
}

@Test("Buffer riusati e scorciatoie preservano vuoto, singleton, sink e componenti separate")
func harmonicTraversalHandlesEmptyIsolatesAndDisjointComponents() throws {
    expectLegacyHarmonicBits(try GlifiDirectedGraph<Int>(nodes: [], edges: []))
    let isolated = try GlifiDirectedGraph(
        nodes: [50, -4, 8],
        edges: [GlifiGraphEdge(source: 50, target: 50, weight: 0)])
    let zeroBits = [UInt64?](repeating: 0, count: isolated.nodes.count)
    let result = GlifiNetworkAnalysis.harmonicCloseness(isolated)
    #expect(isolated.nodes.map { result.scores[$0]?.bitPattern } == zeroBits)
    expectLegacyHarmonicBits(isolated)
    let disconnected = try GlifiDirectedGraph(
        nodes: [6, 0, 4, 2, 5, 1, 3, 7],
        edges: [
            GlifiGraphEdge(source: 0, target: 1),
            GlifiGraphEdge(source: 1, target: 2),
            GlifiGraphEdge(source: 2, target: 0),
            GlifiGraphEdge(source: 3, target: 4),
            GlifiGraphEdge(source: 5, target: 6),
        ])
    expectLegacyHarmonicBits(disconnected)
    expectFloydHarmonicBits(disconnected)
}

private struct HarmonicCollisionNode: Hashable, Sendable {
    let label: String

    func hash(into hasher: inout Hasher) { hasher.combine(0) }
}

private func expectLegacyHarmonicBits<Node>(_ graph: GlifiDirectedGraph<Node>) {
    let actual = GlifiNetworkAnalysis.harmonicCloseness(graph).scores
    let expected = legacyHarmonicScores(graph)
    #expect(actual.count == graph.nodes.count)
    let actualBits = graph.nodes.map { actual[$0]?.bitPattern }
    let expectedBits = graph.nodes.map { expected[$0]?.bitPattern }
    #expect(actualBits == expectedBits)
}

private func expectFloydHarmonicBits<Node>(_ graph: GlifiDirectedGraph<Node>) {
    let actual = GlifiNetworkAnalysis.harmonicCloseness(graph).scores
    let expected = floydHarmonicScores(graph)
    #expect(actual.count == graph.nodes.count)
    let actualBits = graph.nodes.map { actual[$0]?.bitPattern }
    let expectedBits = graph.nodes.map { expected[$0]?.bitPattern }
    #expect(actualBits == expectedBits)
}

/// Literal generic BFS and floating reduction from the previous implementation.
private func legacyHarmonicScores<Node>(_ graph: GlifiDirectedGraph<Node>) -> [Node: Double] {
    var seen = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, Set<Node>()) })
    var neighbors = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, [Node]()) })
    for edge in graph.edges where edge.source != edge.target {
        guard !seen[edge.source, default: []].contains(edge.target) else { continue }
        seen[edge.source, default: []].insert(edge.target)
        neighbors[edge.source, default: []].append(edge.target)
    }
    var scores: [Node: Double] = [:]
    for source in graph.nodes {
        var distance: [Node: Int] = [source: 0]
        var queue = [source]
        var queueIndex = 0
        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            guard let currentDistance = distance[current] else { continue }
            for neighbor in neighbors[current] ?? [] where distance[neighbor] == nil {
                distance[neighbor] = currentDistance + 1
                queue.append(neighbor)
            }
        }
        scores[source] = graph.nodes.reduce(0.0) { result, node in
            guard node != source, let hops = distance[node], hops > 0 else { return result }
            return result + 1 / Double(hops)
        }
    }
    return scores
}

/// Independent all-pairs dynamic programming; no BFS, queue or shared adjacency helper.
private func floydHarmonicScores<Node>(_ graph: GlifiDirectedGraph<Node>) -> [Node: Double] {
    let count = graph.nodes.count
    let unreachable = count + 1
    var distance = [[Int]](
        repeating: [Int](repeating: unreachable, count: count), count: count)
    for index in 0..<count { distance[index][index] = 0 }
    for edge in graph.edges where edge.source != edge.target {
        guard let source = graph.nodes.firstIndex(of: edge.source),
            let target = graph.nodes.firstIndex(of: edge.target)
        else {
            Issue.record("Unexpected endpoint outside the validated test graph")
            continue
        }
        distance[source][target] = 1
    }
    for intermediate in 0..<count {
        for source in 0..<count {
            for target in 0..<count {
                distance[source][target] = min(
                    distance[source][target],
                    distance[source][intermediate] + distance[intermediate][target])
            }
        }
    }
    var scores: [Node: Double] = [:]
    for source in 0..<count {
        var total = 0.0
        for target in 0..<count where target != source {
            let hops = distance[source][target]
            if hops < unreachable { total += 1 / Double(hops) }
        }
        scores[graph.nodes[source]] = total
    }
    return scores
}
