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

@Test("Il riuso Brandes ripulisce componenti, sink e isolati fra sorgenti intercalate")
func betweennessNumericsReusesBuffersAcrossDisjointComponents() throws {
    let edges: [GlifiGraphEdge<Int>] = [
        .init(source: 0, target: 2, weight: 0),
        .init(source: 0, target: 1),
        .init(source: 2, target: 3),
        .init(source: 1, target: 3, weight: 0),
        .init(source: 3, target: 4),
        .init(source: 0, target: 1, weight: 7),
        .init(source: 1, target: 1, weight: 0),
        .init(source: 5, target: 6),
        .init(source: 6, target: 7, weight: 0),
        .init(source: 7, target: 5),
        .init(source: 8, target: 9, weight: 0),
        .init(source: 9, target: 10),
        .init(source: 13, target: 13, weight: 0),
    ]
    let interleaved = [13, 3, 7, 0, 14, 9, 5, 1, 12, 8, 4, 10, 6, 2, 11]
    let orders = [
        interleaved, Array(interleaved.reversed()),
        Array(interleaved.dropFirst(4)) + Array(interleaved.prefix(4)), Array(0..<15),
    ]
    for nodes in orders {
        let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
        let actual = GlifiNetworkAnalysis.betweenness(graph).scores
        let legacy = legacyBetweenness(graph)
        let independent = enumeratedBetweenness(graph)
        #expect(actual.count == nodes.count)
        #expect(nodes.map { actual[$0]?.bitPattern } == nodes.map { legacy[$0]?.bitPattern })
        for node in nodes {
            let score = try #require(actual[node])
            let reference = try #require(independent[node])
            #expect(abs(score - reference) <= 1e-12)
        }
        #expect(actual[3] == 3)
        for node in [1, 2, 5, 6, 7, 9] { #expect(actual[node] == 1) }
        for node in [0, 4, 8, 10, 11, 12, 13, 14] {
            #expect(actual[node]?.bitPattern == 0)
        }
    }
}

@Test("Il riuso Brandes conserva i bit su componenti sintetiche e permutazioni delle sorgenti")
func betweennessNumericsReusesBuffersAcrossSeededComponents() throws {
    for seed in 1...12 {
        var generator = GlifiSplitMix64(seed: UInt64(seed + 177))
        let width = 5 + seed % 4
        let count = 6 * width + 8
        let identities = (0..<count).map { $0 * 19 - 700 }
        var edges: [GlifiGraphEdge<Int>] = []
        for component in 0..<6 {
            let base = component * width
            for offset in 0..<(width - 1) {
                edges.append(
                    .init(
                        source: identities[base + offset], target: identities[base + offset + 1],
                        weight: offset.isMultiple(of: 3) ? 0 : 1))
            }
            for index in 0..<(width * 3) {
                let source = generator.index(below: width - 1)
                let target = source + 1 + generator.index(below: width - source - 1)
                edges.append(
                    .init(
                        source: identities[base + source], target: identities[base + target],
                        weight: index.isMultiple(of: 3) ? 0 : Double(index % 7)))
            }
            if component.isMultiple(of: 2) {
                edges.append(.init(source: identities[base + width - 1], target: identities[base]))
            }
            edges.append(.init(source: identities[base], target: identities[base], weight: 0))
            edges.append(.init(source: identities[base], target: identities[base + 1], weight: 3))
        }
        var shuffled = identities
        for index in stride(from: count - 1, through: 1, by: -1) {
            shuffled.swapAt(index, generator.index(below: index + 1))
        }
        for nodes in [shuffled, Array(shuffled.reversed())] {
            let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
            let actual = GlifiNetworkAnalysis.betweenness(graph).scores
            let legacy = legacyBetweenness(graph)
            #expect(actual.count == count)
            #expect(nodes.map { actual[$0]?.bitPattern } == nodes.map { legacy[$0]?.bitPattern })
            for node in identities.suffix(8) { #expect(actual[node]?.bitPattern == 0) }
        }
    }
}

@Test("Il riuso del fallback Brandes conserva i bit fra sorgenti estreme, ordinarie e isolate")
func betweennessNumericsReusesExtendedCountersAcrossSourceOrders() throws {
    let layers = 650
    let uniform = try betweennessLayeredGraph(width: 3, layers: layers)
    let omittedSink = layers * 3
    let edges = uniform.edges.filter { $0.target != omittedSink }
    let count = omittedSink + 2
    // Early layers overflow, layer three is finite, and the last layer contains sinks.
    // The omitted sink and the final extra identity are isolated in this fixture.
    let priority = [0, 1_948, 1, 1_950, 7, 2, 1_951, 1_949, 4, 8, 3, 5, 9, 6]
    let selected = Set(priority)
    let remainder = (0..<count).map { ($0 * 37) % count }.filter { !selected.contains($0) }
    let nodes = priority + remainder
    let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
    let actual = GlifiNetworkAnalysis.betweenness(graph).scores
    let reference = legacyBetweenness(graph)
    #expect(actual.count == nodes.count)
    #expect(reference.count == nodes.count)
    let finite =
        actual.values.allSatisfy { $0.isFinite }
        && reference.values.allSatisfy { $0.isFinite }
    #expect(finite)
    guard finite else { return }
    #expect(nodes.map { actual[$0]?.bitPattern } == nodes.map { reference[$0]?.bitPattern })
    for node in [1_948, 1_949, 1_950, 1_951] { #expect(actual[node]?.bitPattern == 0) }
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

private typealias BrandesPathCount = GlifiNetworkAnalysis.BrandesPathCount

/// Literal generic BFS and dependency accumulation from the GS-VER-174 baseline.
///
/// The shared count representation isolates this differential test to layout and reset behavior;
/// independent formula and path-enumeration tests above verify the mathematical definition.
private func legacyBetweenness<Node>(_ graph: GlifiDirectedGraph<Node>) -> [Node: Double] {
    var seen = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, Set<Node>()) })
    var neighbors = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, [Node]()) })
    for edge in graph.edges where edge.source != edge.target {
        guard !seen[edge.source, default: []].contains(edge.target) else { continue }
        seen[edge.source, default: []].insert(edge.target)
        neighbors[edge.source, default: []].append(edge.target)
    }
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
        if sigma.values.contains(where: { !$0.isFinite }) {
            let counts = extendedBrandesPathCounts(
                source: source, order: order, predecessors: predecessors)
            for node in order.reversed() where node != source {
                guard let denominator = counts[node] else {
                    preconditionFailure("Missing reachable Brandes path count")
                }
                for predecessor in predecessors[node] ?? [] {
                    guard let numerator = counts[predecessor] else {
                        preconditionFailure("Missing Brandes predecessor path count")
                    }
                    dependency[predecessor, default: 0] += numerator.dependencyContribution(
                        dividingBy: denominator, dependency: dependency[node] ?? 0)
                }
                betweenness[node, default: 0] += dependency[node] ?? 0
            }
        } else {
            for node in order.reversed() where node != source {
                for predecessor in predecessors[node] ?? [] {
                    let ratio = (sigma[predecessor] ?? 0) / (sigma[node] ?? 1)
                    dependency[predecessor, default: 0] += ratio * (1 + (dependency[node] ?? 0))
                }
                betweenness[node, default: 0] += dependency[node] ?? 0
            }
        }
    }
    return betweenness
}

private func extendedBrandesPathCounts<Node>(
    source: Node, order: [Node], predecessors: [Node: [Node]]
) -> [Node: BrandesPathCount] {
    var counts: [Node: BrandesPathCount] = [source: .one]
    for node in order where node != source {
        var count = BrandesPathCount.zero
        for predecessor in predecessors[node] ?? [] {
            // BFS order places every shortest-path predecessor before its child.
            guard let previous = counts[predecessor] else {
                preconditionFailure("Invalid Brandes predecessor order")
            }
            count = count.adding(previous)
        }
        counts[node] = count
    }
    return counts
}
