// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("MI3 e Z KH coincidono con l'oracolo razionale e Decimal a 80 cifre")
func khCollocationScoresMatchIndependentScalarOracle() throws {
    // Tests/Oracles/Python/kh_lexical_profiles.py evaluates exact integer ratios.
    let cases: [(Int, Int, Int, Int, Int, Double, Double, Double)] = [
        (28, 184, 685, 1_108_539, 10, 17.558770728781372, 1.137180776917143, 25.198290606706866),
        (8, 3, 4, 100, 10, 12.058893689053568, 1.2371134020618557, 6.209716054434575),
    ]
    for value in cases {
        let result = try GlifiKHCollocationAnalysis.scores(
            GlifiKHCollocationInput(
                jointCount: value.0, nodeFrequency: value.1, collocateFrequency: value.2,
                corpusTokenCount: value.3, windowSpan: value.4))
        #expect(abs(try #require(result.mi3) - value.5) < 1e-12)
        #expect(abs(try #require(result.expectedWindowCount) - value.6) < 1e-12)
        #expect(abs(try #require(result.zScore) - value.7) < 1e-12)
    }
}

@Test("Le finestre sovrapposte non sono sostituite da margini 2×2 e S influisce soltanto su Z")
func khCollocationRetainsGlobalTokenAndWindowUniverses() throws {
    let short = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 8, nodeFrequency: 3, collocateFrequency: 4,
            corpusTokenCount: 100, windowSpan: 3))
    let wide = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 8, nodeFrequency: 3, collocateFrequency: 4,
            corpusTokenCount: 100, windowSpan: 6))
    #expect(short.mi3 == wide.mi3)
    #expect(try #require(wide.expectedWindowCount) == 2 * #require(short.expectedWindowCount))
    #expect(short.zScore != wide.zScore)
}

@Test("Zero osservazioni, corpus vuoto e varianza nulla hanno esiti distinti e dichiarati")
func khCollocationUndefinedAndZeroJointPolicies() throws {
    let empty = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 0, nodeFrequency: 0, collocateFrequency: 0,
            corpusTokenCount: 0, windowSpan: 1))
    #expect(empty.mi3 == nil && empty.zScore == nil && empty.expectedWindowCount == nil)
    let absent = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 0, nodeFrequency: 3, collocateFrequency: 4,
            corpusTokenCount: 100, windowSpan: 10))
    #expect(absent.mi3 == nil)
    #expect(abs(try #require(absent.zScore) + (120.0 / 93).squareRoot()) < 1e-12)
    let saturated = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 1, nodeFrequency: 1, collocateFrequency: 2,
            corpusTokenCount: 3, windowSpan: 1))
    #expect(saturated.zScore == nil)
    #expect(saturated.expectedWindowCount == 1)
    #expect(saturated.mi3 != nil)
}

@Test("I conteggi KH impossibili falliscono prima del calcolo, senza somme o prodotti traboccanti")
func khCollocationRejectsInconsistentInputs() throws {
    for value in [
        (-1, 1, 1, 10, 1), (0, -1, 1, 10, 1), (0, 1, -1, 10, 1),
        (0, 1, 1, -1, 1), (0, 1, 1, 10, 0), (0, 1, 1, 10, -1),
        (0, 11, 0, 10, 1), (0, 6, 5, 10, 1), (1, 0, 3, 10, 2),
        (4, 1, 2, 100, 10), (9, 3, 4, 100, 2), (0, Int.max, Int.max, Int.max, 1),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiKHCollocationInput(
                jointCount: value.0, nodeFrequency: value.1, collocateFrequency: value.2,
                corpusTokenCount: value.3, windowSpan: value.4)
        }
    }
}

@Test("Z preserva residui esatti e varianza positiva vicino a Int.max")
func khCollocationPreservesNearSaturatedIntegerResiduals() throws {
    let result = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 1, nodeFrequency: 1, collocateFrequency: Int.max - 2,
            corpusTokenCount: Int.max, windowSpan: 1))
    let expected = 1 / Double(Int.max - 2).squareRoot()
    #expect(try #require(result.zScore) > 0)
    #expect(abs(try #require(result.zScore) / expected - 1) < 1e-14)
    let large = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: Int.max, nodeFrequency: Int.max / 3, collocateFrequency: Int.max / 3,
            corpusTokenCount: Int.max, windowSpan: Int.max))
    #expect(try #require(large.mi3).isFinite)
    #expect(try #require(large.expectedWindowCount).isFinite)
    #expect(try #require(large.zScore).isFinite)
}

@Test("I punteggi KH rispettano una cancellazione già richiesta")
func khCollocationCancellationPrecedesScoring() async throws {
    let input = try GlifiKHCollocationInput(
        jointCount: 8, nodeFrequency: 3, collocateFrequency: 4,
        corpusTokenCount: 100, windowSpan: 10)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiKHCollocationAnalysis.scores(input)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
