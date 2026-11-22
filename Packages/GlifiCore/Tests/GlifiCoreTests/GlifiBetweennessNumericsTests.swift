// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("I contatori Brandes scalati conservano zero, somme e riporti anche oltre Double.max")
func betweennessNumericsScaledCountInvariants() {
    let one = GlifiNetworkAnalysis.BrandesPathCount.one
    let zero = GlifiNetworkAnalysis.BrandesPathCount.zero
    let two = one.adding(one)
    let three = two.adding(one)
    let four = two.adding(two)
    #expect(zero.dependencyContribution(dividingBy: one, dependency: 7).bitPattern == 0)
    #expect(zero.adding(one).dependencyContribution(dividingBy: one, dependency: 0) == 1)
    #expect(one.adding(zero).dependencyContribution(dividingBy: one, dependency: 0) == 1)
    #expect(one.dependencyContribution(dividingBy: two, dependency: 0) == 0.5)
    #expect(three.dependencyContribution(dividingBy: four, dependency: 3) == 3)
    #expect(three.adding(one).dependencyContribution(dividingBy: four, dependency: 0) == 1)
    let huge = brandesPowerOfTwo(1_080)
    let hugeTwice = huge.adding(huge)
    #expect(huge.dependencyContribution(dividingBy: hugeTwice, dependency: 0) == 0.5)
    #expect(huge.adding(one).dependencyContribution(dividingBy: huge, dependency: 0) == 1)
    #expect(one.adding(huge).dependencyContribution(dividingBy: huge, dependency: 0) == 1)
}

@Test("Il prodotto quota-dipendenza conserva contributi subnormali con quota arrotondata a zero")
func betweennessNumericsRecoversRepresentableUnderflowContribution() {
    let one = GlifiNetworkAnalysis.BrandesPathCount.one
    let denominator = brandesPowerOfTwo(1_080)
    // Exact rational: (1 / 2^1080) * 1024 = 2^-1070 = 16 * Double.leastNonzeroMagnitude.
    // The isolated ratio cannot be represented, but the complete contribution can.
    #expect(Double(sign: .plus, exponent: -1_080, significand: 1).bitPattern == 0)
    #expect(one.dependencyContribution(dividingBy: denominator, dependency: 1_023).bitPattern == 16)
    let nonBinaryDenominator = denominator.adding(brandesPowerOfTwo(1_079))
    // Exact rational: 1536 / (3 * 2^1079) = 2^-1070, also for a non-power-of-two count.
    #expect(
        one.dependencyContribution(dividingBy: nonBinaryDenominator, dependency: 1_535)
            .bitPattern == 16)
    let halfMinimumDenominator = brandesPowerOfTwo(1_075)
    #expect(
        one.dependencyContribution(dividingBy: halfMinimumDenominator, dependency: 0)
            .bitPattern == 0)
    // 3 / 2^1075 is exactly 1.5 subnormal units: round-to-even gives two units.
    #expect(
        one.dependencyContribution(dividingBy: halfMinimumDenominator, dependency: 2)
            .bitPattern == 2)
    #expect(
        one.dependencyContribution(dividingBy: brandesPowerOfTwo(1_074), dependency: 0)
            .bitPattern == 1)
}

@Test("Il confine di mezzo subnormale usa l'arrotondamento del rapporto esatto")
func betweennessNumericsAvoidsSubnormalDoubleRounding() {
    let one = GlifiNetworkAnalysis.BrandesPathCount.one
    var denominator = GlifiNetworkAnalysis.BrandesPathCount.zero
    var term = brandesPowerOfTwo(1_023)
    for _ in 0..<52 {
        denominator = denominator.adding(term)
        term = term.adding(term)
    }
    // Sum_{k=1023}^{1074} 2^k = 2^1075 - 2^1023. Its reciprocal is strictly
    // above half the least subnormal, and must round up to bit pattern one.
    #expect(one.dependencyContribution(dividingBy: denominator, dependency: 0).bitPattern == 1)
    let exactHalf = denominator.adding(brandesPowerOfTwo(1_023))
    #expect(one.dependencyContribution(dividingBy: exactHalf, dependency: 0).bitPattern == 0)
    let belowHalf = exactHalf.adding(brandesPowerOfTwo(1_023))
    #expect(one.dependencyContribution(dividingBy: belowHalf, dependency: 0).bitPattern == 0)
}

@Test("Brandes conserva risultati finiti e formula esatta oltre 2^1024 cammini")
func betweennessNumericsLayeredBinaryOverflow() throws {
    let layers = 1_026
    let graph = try betweennessLayeredGraph(width: 2, layers: layers)
    #expect(graph.nodes.count == 2_053)
    let scores = GlifiNetworkAnalysis.betweenness(graph).scores
    #expect(scores.count == graph.nodes.count)
    let finite = scores.values.allSatisfy { $0.isFinite }
    #expect(finite)
    guard finite else { return }
    #expect(scores[0]?.bitPattern == 0)
    // Each origin before layer l has half its paths through either node in layer l.
    // There are 2l-1 such origins and 2(L-l) destinations, giving (2l-1)(L-l).
    for node in graph.nodes.dropFirst() {
        let layer = (node - 1) / 2 + 1
        let expected = Double((2 * layer - 1) * (layers - layer))
        #expect(scores[node]?.bitPattern == expected.bitPattern)
    }
}

@Test("Brandes gestisce molteplicità estreme non potenze di due senza pretendere esattezza")
func betweennessNumericsLayeredTernaryOverflow() throws {
    let layers = 650
    let uniform = try betweennessLayeredGraph(width: 3, layers: layers)
    let omittedSink = layers * 3
    let graph = try GlifiDirectedGraph(
        nodes: Array(uniform.nodes.dropLast()),
        edges: uniform.edges.filter { $0.target != omittedSink })
    let scores = GlifiNetworkAnalysis.betweenness(graph).scores
    let finite = scores.values.allSatisfy { $0.isFinite }
    #expect(finite)
    guard finite else { return }
    #expect(scores[0]?.bitPattern == 0)
    for node in graph.nodes.dropFirst() {
        let layer = (node - 1) / 3 + 1
        // The final layer has two sinks: 3l-2 origins and 3(L-l)-1 destinations.
        // Every intermediate node receives one third, including fractional scores.
        let expected =
            layer == layers ? 0 : Double((3 * layer - 2) * (3 * (layers - layer) - 1)) / 3
        let actual = try #require(scores[node])
        #expect(abs(actual - expected) <= 1e-10 * max(1, expected))
    }
}

@Test("Brandes coincide con l'enumerazione dei cammini minimi in tutti i digrafi di quattro nodi")
func betweennessNumericsExhaustiveFourNodeGraphs() throws {
    let labels = [30, -5, 12, 0]
    let nodes = [labels[2], labels[0], labels[3], labels[1]]
    let possible = (0..<4).flatMap { source in
        (0..<4).filter { $0 != source }.map { (source, $0) }
    }
    for mask in 0..<(1 << possible.count) {
        var edges: [GlifiGraphEdge<Int>] = []
        for (index, pair) in possible.enumerated() where mask & (1 << index) != 0 {
            edges.append(
                GlifiGraphEdge(
                    source: labels[pair.0], target: labels[pair.1],
                    weight: index.isMultiple(of: 3) ? 0 : 1))
        }
        let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
        let actual = GlifiNetworkAnalysis.betweenness(graph).scores
        let expected = enumeratedBetweenness(graph)
        for node in nodes {
            let value = try #require(actual[node])
            let reference = try #require(expected[node])
            #expect(abs(value - reference) <= 1e-12)
        }
    }
}

@Test("Brandes conserva tutti i bit ordinari con nodi riordinati, pesi zero e archi paralleli")
func betweennessNumericsOrdinaryLegacyBits() throws {
    for seed in 1...12 {
        var generator = GlifiSplitMix64(seed: UInt64(seed + 174))
        let count = 5 + seed
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
        for order in [nodes, Array(nodes.reversed())] {
            let graph = try GlifiDirectedGraph(nodes: order, edges: edges)
            let actual = GlifiNetworkAnalysis.betweenness(graph).scores
            let expected = legacyBetweenness(graph)
            #expect(order.map { actual[$0]?.bitPattern } == order.map { expected[$0]?.bitPattern })
        }
    }
}

@Test("Brandes distingue identità in collisione e conserva le semantiche hop degli archi")
func betweennessNumericsCollidingIdentities() throws {
    let first = BetweennessCollisionNode(label: "日本語")
    let second = BetweennessCollisionNode(label: "e\u{301}")
    let third = BetweennessCollisionNode(label: "z")
    let isolated = BetweennessCollisionNode(label: "β")
    let graph = try GlifiDirectedGraph(
        nodes: [third, first, isolated, second],
        edges: [
            GlifiGraphEdge(source: first, target: second, weight: 0),
            GlifiGraphEdge(source: first, target: second, weight: .greatestFiniteMagnitude),
            GlifiGraphEdge(source: second, target: third, weight: 0),
            GlifiGraphEdge(source: second, target: second, weight: .leastNonzeroMagnitude),
            GlifiGraphEdge(source: third, target: first, weight: 7),
            GlifiGraphEdge(source: isolated, target: isolated, weight: 0),
        ])
    let actual = GlifiNetworkAnalysis.betweenness(graph).scores
    let legacy = legacyBetweenness(graph)
    let enumerated = enumeratedBetweenness(graph)
    for node in graph.nodes {
        #expect(actual[node]?.bitPattern == legacy[node]?.bitPattern)
        #expect(actual[node]?.bitPattern == enumerated[node]?.bitPattern)
    }
    for node in [first, second, third] { #expect(actual[node] == 1) }
    #expect(actual[isolated]?.bitPattern == 0)
    let empty = try GlifiDirectedGraph<Int>(nodes: [], edges: [])
    #expect(GlifiNetworkAnalysis.betweenness(empty).scores.isEmpty)
}

private struct BetweennessCollisionNode: Hashable, Sendable {
    let label: String

    func hash(into hasher: inout Hasher) { hasher.combine(0) }
}

private func brandesPowerOfTwo(_ exponent: Int) -> GlifiNetworkAnalysis.BrandesPathCount {
    var count = GlifiNetworkAnalysis.BrandesPathCount.one
    for _ in 0..<exponent { count = count.adding(count) }
    return count
}

private func betweennessLayeredGraph(width: Int, layers: Int) throws -> GlifiDirectedGraph<Int> {
    var edges: [GlifiGraphEdge<Int>] = []
    for offset in 0..<width { edges.append(GlifiGraphEdge(source: 0, target: 1 + offset)) }
    for layer in 1..<layers {
        for left in 0..<width {
            for right in 0..<width {
                edges.append(
                    GlifiGraphEdge(
                        source: 1 + (layer - 1) * width + left,
                        target: 1 + layer * width + right))
            }
        }
    }
    return try GlifiDirectedGraph(nodes: Array(0...(width * layers)), edges: edges)
}

/// Direct enumeration of every simple path, retaining shortest paths for each ordered pair.
///
/// This oracle shares no BFS, sigma recurrence or dependency accumulation with Brandes.
private func enumeratedBetweenness<Node>(_ graph: GlifiDirectedGraph<Node>) -> [Node: Double] {
    let count = graph.nodes.count
    var adjacency = [[Bool]](repeating: [Bool](repeating: false, count: count), count: count)
    for edge in graph.edges where edge.source != edge.target {
        guard let source = graph.nodes.firstIndex(of: edge.source),
            let target = graph.nodes.firstIndex(of: edge.target)
        else { continue }
        adjacency[source][target] = true
    }
    var scores = [Double](repeating: 0, count: count)
    for source in 0..<count {
        for target in 0..<count where target != source {
            var shortest = count
            var total = 0
            var through = [Int](repeating: 0, count: count)
            func visit(_ path: [Int]) {
                guard let last = path.last else { return }
                let length = path.count - 1
                if last == target {
                    if length < shortest {
                        shortest = length
                        total = 0
                        through = [Int](repeating: 0, count: count)
                    }
                    if length == shortest {
                        total += 1
                        for node in path.dropFirst().dropLast() { through[node] += 1 }
                    }
                    return
                }
                guard length < shortest else { return }
                for next in 0..<count where adjacency[last][next] && !path.contains(next) {
                    visit(path + [next])
                }
            }
            visit([source])
            if total > 0 {
                for node in 0..<count { scores[node] += Double(through[node]) / Double(total) }
            }
        }
    }
    return Dictionary(
        uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, scores[$0.offset]) })
}

/// Literal generic BFS and dependency accumulation from the finite-count implementation.
private func legacyBetweenness<Node>(_ graph: GlifiDirectedGraph<Node>) -> [Node: Double] {
    var seen = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, Set<Node>()) })
    var neighbors = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, [Node]()) })
    for edge in graph.edges where edge.source != edge.target {
        guard !seen[edge.source, default: []].contains(edge.target) else { continue }
        seen[edge.source, default: []].insert(edge.target)
        neighbors[edge.source, default: []].append(edge.target)
    }
    var scores = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) })
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
            for neighbor in neighbors[current] ?? [] {
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
            scores[node, default: 0] += dependency[node] ?? 0
        }
    }
    return scores
}
