// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("L'espansione binaria conserva carry e bit di ogni esponente binary64")
func graphCompletionExactSumPackingAndCarry() throws {
    let fractions: [UInt64] = [0, 1, 0x000f_ffff_ffff_ffff]
    for exponent in 0..<2_047 {
        for fraction in fractions {
            let value = Double(bitPattern: (UInt64(exponent) << 52) | fraction)
            #expect(try GlifiGraphBinary64Sum(value).rounded == value)
        }
    }
    var allLowBits = GlifiGraphBinary64Sum()
    for bit in 0..<64 {
        allLowBits = try allLowBits.adding(
            Double(sign: .plus, exponent: bit - 1_074, significand: 1))
    }
    let carried = try allLowBits.adding(Double.leastNonzeroMagnitude)
    #expect(allLowBits < carried)
    #expect(carried.rounded == Double(sign: .plus, exponent: -1_010, significand: 1))
}

@Test("La somma binaria arrotonda nearest-even e conserva code esatte distinte")
func graphCompletionExactSumRoundingAndOrdering() throws {
    let one = try GlifiGraphBinary64Sum(1)
    let halfULP = Double(sign: .plus, exponent: -53, significand: 1)
    let halfway = try one.adding(halfULP)
    #expect(halfway.rounded == 1)
    let aboveHalfway = try halfway.adding(Double.leastNonzeroMagnitude)
    #expect(halfway < aboveHalfway)
    #expect(aboveHalfway.rounded == Double(1).nextUp)
    let oddHalfway = try GlifiGraphBinary64Sum(Double(1).nextUp).adding(halfULP)
    #expect(oddHalfway.rounded == Double(1).nextUp.nextUp)
    let large = try GlifiGraphBinary64Sum(9_007_199_254_740_992)
    let plusOne = try large.adding(1)
    let plusTwo = try large.adding(2)
    #expect(large < plusOne)
    #expect(plusOne < plusTwo)
    #expect(plusOne.rounded == large.rounded)
    #expect(plusTwo.rounded == 9_007_199_254_740_994)
    #expect(try plusOne.adding(1) == plusTwo)
}

@Test("La somma esatta coincide con un oracolo Int64 su diadici e permutazioni")
func graphCompletionExactSumDyadicOracle() throws {
    var generator = GlifiSplitMix64(seed: 0x4558_4143_5453_554d)
    for _ in 0..<256 {
        let numerators = (0..<24).map { _ in Int64(generator.next() % 100_001) }
        let numerator = numerators.reduce(0, +)
        var forward = GlifiGraphBinary64Sum()
        var reverse = GlifiGraphBinary64Sum()
        var prefix = GlifiGraphBinary64Sum()
        var suffix = GlifiGraphBinary64Sum()
        for (index, value) in numerators.enumerated() {
            let dyadic = Double(value) / 1_048_576
            forward = try forward.adding(dyadic)
            if index < 12 {
                prefix = try prefix.adding(dyadic)
            } else {
                suffix = try suffix.adding(dyadic)
            }
        }
        for value in numerators.reversed() {
            reverse = try reverse.adding(Double(value) / 1_048_576)
        }
        #expect(forward.rounded == Double(numerator) / 1_048_576)
        #expect(forward == reverse)
        #expect(try prefix.adding(suffix) == forward)
        let more = try forward.adding(1.0 / 1_048_576)
        #expect(forward < more)
        #expect(more.rounded == Double(numerator + 1) / 1_048_576)
    }
}

@Test("L'espansione distingue overflow di output e capacità interna, senza trap")
func graphCompletionExactSumOverflow() throws {
    let maximum = try GlifiGraphBinary64Sum(Double.greatestFiniteMagnitude)
    #expect(maximum.rounded == .greatestFiniteMagnitude)
    let tinyTail = try maximum.adding(Double.leastNonzeroMagnitude)
    #expect(maximum < tinyTail)
    #expect(tinyTail.rounded == .greatestFiniteMagnitude)
    let overflow = try maximum.adding(Double.greatestFiniteMagnitude.ulp / 2)
    #expect(overflow.rounded == .infinity)
    var full = maximum
    for _ in 0..<78 { full = try full.adding(full) }
    #expect(full.rounded == .infinity)
    #expect(throws: GlifiFailure.self) { try full.adding(full) }
    for value in [-1.0, .nan, .infinity] {
        #expect(throws: GlifiFailure.self) { try GlifiGraphBinary64Sum(value) }
    }
}

@Test(
    "La GN v2 distingue percorsi vicini e conserva pareggi oltre la precisione di una somma Double")
func graphCompletionExactShortestPathTails() throws {
    let close = try GlifiDirectedGraph(
        nodes: [0, 1, 2],
        edges: [
            GlifiGraphEdge(source: 0, target: 1, weight: 1),
            GlifiGraphEdge(source: 0, target: 2, weight: 1 / Double(2).nextUp),
            GlifiGraphEdge(source: 1, target: 2, weight: 1),
        ])
    let closePrepared = try GlifiPreparedCommunityGraph(close, limits: .standard)
    let closeScores = try communityEdgeBetweenness(closePrepared, active: [true, true, true])
    #expect(closeScores == [2, 0, 2])
    let large = 9_007_199_254_740_992.0
    let tied = try GlifiDirectedGraph(
        nodes: [0, 1, 2, 3],
        edges: [
            GlifiGraphEdge(source: 0, target: 1, weight: 1 / large),
            GlifiGraphEdge(source: 0, target: 3, weight: 1 / (large + 2)),
            GlifiGraphEdge(source: 1, target: 2, weight: 1),
            GlifiGraphEdge(source: 2, target: 3, weight: 1),
        ])
    let tiedPrepared = try GlifiPreparedCommunityGraph(tied, limits: .standard)
    let tiedScores = try communityEdgeBetweenness(tiedPrepared, active: [true, true, true, true])
    // Enumerating the six unordered pairs gives one half to each 0→3 path.
    #expect(tiedScores == [2.5, 0.5, 3.5, 2.5])
    let result = try GlifiNetworkAnalysis.communities(tied, method: .edgeBetweenness)
    #expect(result.methodIdentifier == "GirvanNewman-inverse-strength-exact-binary64-v2")
}

@Test("GN v2 ammette esplicitamente memoria e lavoro degli accumulatori")
func graphCompletionExactAccumulatorAdmission() throws {
    let graph = try GlifiDirectedGraph(
        nodes: [0, 1], edges: [GlifiGraphEdge(source: 0, target: 1)])
    for limits in [
        GlifiGraphAlgorithmLimits(maximumPairwiseCells: 305),
        GlifiGraphAlgorithmLimits(maximumWork: 407),
    ] {
        do {
            _ = try GlifiNetworkAnalysis.communities(
                graph, method: .edgeBetweenness, limits: limits)
            Issue.record("The exact accumulators bypassed admission")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "network.resource-limit")
            #expect(failure.category == .insufficientResources)
        }
    }
    let admitted = try GlifiNetworkAnalysis.communities(
        graph, method: .edgeBetweenness,
        limits: .init(maximumPairwiseCells: 306, maximumWork: 408))
    #expect(admitted.communityCount == 1)
    let isolated = try GlifiDirectedGraph<Int>(nodes: [0, 1], edges: [])
    let noAccumulators = try GlifiNetworkAnalysis.communities(
        isolated, method: .edgeBetweenness, limits: .init(maximumPairwiseCells: 0))
    #expect(noAccumulators.communityCount == 2)
}
