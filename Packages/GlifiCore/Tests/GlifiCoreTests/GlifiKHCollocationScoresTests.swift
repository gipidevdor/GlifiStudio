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

@Test("Le sette scale globali KH includono MI base2, T e LL manuale senza fattore due")
func khCollocationSevenScalesIndependentOracle() throws {
    // Independent 80-digit Decimal entropy expression, not the product's deviance series.
    let cases: [(Int, Int, Int, Int, [Double])] = [
        (
            28, 184, 685, 1_108_539,
            [
                7.9440608846661647, 5.2700154925928802, 0.033293697978596909,
                0.064441887226697359, 129.09921713626184,
            ]
        ),
        (
            5, 10, 20, 100,
            [
                1.3219280948873624, 1.3416407864998738, 0.2,
                0.33333333333333331, 2.5582617502519129,
            ]
        ),
    ]
    #expect(GlifiKHCollocationScores.identifier == "KH-collocation-global-token-window-v1")
    for (joint, first, second, total, expected) in cases {
        let result = try GlifiKHCollocationAnalysis.scores(
            GlifiKHCollocationInput(
                jointCount: joint, nodeFrequency: first, collocateFrequency: second,
                corpusTokenCount: total, windowSpan: 10))
        for (actual, reference) in zip(
            [
                result.mutualInformation, result.tScore, result.jaccard, result.dice,
                result.logLikelihood,
            ],
            expected)
        {
            #expect(abs(try #require(actual) - reference) < 1e-12 * max(1, abs(reference)))
        }
    }
}

@Test("Le scale globali non clampano finestre sovrapposte e preservano residui Int.max")
func khCollocationSevenScalesDomainsAndResiduals() throws {
    for joint in [4, 8] {
        let result = try GlifiKHCollocationAnalysis.scores(
            GlifiKHCollocationInput(
                jointCount: joint, nodeFrequency: 3, collocateFrequency: 4,
                corpusTokenCount: 100, windowSpan: 3))
        #expect(result.logLikelihood == nil)
        #expect(try #require(result.dice) == Double(2 * joint) / 7)
        #expect(try #require(result.dice) > 1)
        if joint == 4 {
            #expect(try #require(result.jaccard) == 4.0 / 3)
            #expect(try #require(result.jaccard) > 1)
        } else {
            #expect(result.jaccard == nil)
        }
        #expect(result.mutualInformation != nil && result.tScore != nil)
    }
    let zero = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 0, nodeFrequency: 3, collocateFrequency: 4,
            corpusTokenCount: 100, windowSpan: 1))
    #expect(zero.mutualInformation == nil && zero.tScore == nil)
    #expect(zero.jaccard == 0 && zero.dice == 0)
    #expect(try #require(zero.logLikelihood) > 0)
    let independent = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 2, nodeFrequency: 10, collocateFrequency: 20,
            corpusTokenCount: 100, windowSpan: 1))
    #expect(independent.logLikelihood == 0)
    let extreme = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 1, nodeFrequency: 1, collocateFrequency: Int.max - 2,
            corpusTokenCount: Int.max, windowSpan: 1))
    let residual = 2 / Double(Int.max)
    #expect(try #require(extreme.tScore) > 0)
    #expect(abs(try #require(extreme.tScore) / residual - 1) < 1e-14)
    #expect(try #require(extreme.mutualInformation) > 0)
    #expect(abs(try #require(extreme.mutualInformation) / (residual / log(2)) - 1) < 1e-14)
    #expect(try #require(extreme.logLikelihood) > 0)
    #expect(abs(try #require(extreme.logLikelihood) / residual - 1) < 1e-14)
    let empty = try GlifiKHCollocationAnalysis.scores(
        GlifiKHCollocationInput(
            jointCount: 0, nodeFrequency: 0, collocateFrequency: 0,
            corpusTokenCount: 0, windowSpan: 1))
    #expect(empty.mutualInformation == nil && empty.tScore == nil)
    #expect(empty.jaccard == nil && empty.dice == nil && empty.logLikelihood == nil)
}

@Test("L'associazione KH tra documenti coincide con probabilità razionali e radici Decimal")
func khWordAssociationIndependentOracle() throws {
    let cases: [(Int, Int, Int, Int, [Double], Bool)] = [
        (12, 18, 8, 62, [0.2, 0.4, 0.2, 2, 0.31578947368421051, 0.4898979485566356], true),
        (60, 20, 15, 5, [0.75, 0.75, 0, 1, 0.63157894736842102, 0.7745966692414834], false),
    ]
    #expect(GlifiKHWordAssociationScores.identifier == "KH-word-association-document-v1")
    for (joint, firstOnly, secondOnly, neither, expected, positive) in cases {
        let result = try GlifiKHWordAssociationAnalysis.scores(
            GlifiCooccurrenceCounts(
                jointCount: joint, firstOnlyCount: firstOnly, secondOnlyCount: secondOnly,
                neitherCount: neither))
        for (actual, reference) in zip(
            [
                result.unconditionalProbability, result.conditionalProbability, result.differential,
                result.lift, result.jaccard, result.ochiai,
            ], expected)
        {
            #expect(abs(try #require(actual) - reference) < 1e-12)
        }
        #expect(result.isPositiveAssociation == positive)
    }
}

@Test("L'associazione restituisce anche esiti non positivi e distingue denominatori nulli")
func khWordAssociationDomainsAndExactDirection() async throws {
    let empty = try GlifiKHWordAssociationAnalysis.scores(
        GlifiCooccurrenceCounts(
            jointCount: 0, firstOnlyCount: 0, secondOnlyCount: 0, neitherCount: 0))
    #expect(empty.unconditionalProbability == nil && empty.conditionalProbability == nil)
    #expect(empty.differential == nil && empty.lift == nil)
    #expect(empty.jaccard == nil && empty.ochiai == nil && !empty.isPositiveAssociation)
    let noTerm = try GlifiKHWordAssociationAnalysis.scores(
        GlifiCooccurrenceCounts(
            jointCount: 0, firstOnlyCount: 3, secondOnlyCount: 0, neitherCount: 7))
    #expect(noTerm.unconditionalProbability == 0 && noTerm.conditionalProbability == 0)
    #expect(noTerm.differential == 0 && noTerm.lift == nil)
    #expect(noTerm.jaccard == 0 && noTerm.ochiai == nil && !noTerm.isPositiveAssociation)
    let negative = try GlifiKHWordAssociationAnalysis.scores(
        GlifiCooccurrenceCounts(
            jointCount: 1, firstOnlyCount: 9, secondOnlyCount: 19, neitherCount: 71))
    #expect(abs(try #require(negative.differential) + 0.1) < 1e-15)
    #expect(negative.lift == 0.5 && !negative.isPositiveAssociation)
    let counts = try GlifiCooccurrenceCounts(
        jointCount: 1, firstOnlyCount: 0, secondOnlyCount: Int.max - 3, neitherCount: 2)
    let extreme = try GlifiKHWordAssociationAnalysis.scores(counts)
    #expect(extreme.unconditionalProbability == extreme.conditionalProbability)
    #expect(extreme.isPositiveAssociation)
    #expect(try #require(extreme.differential) > 0)
    #expect(abs(try #require(extreme.differential) / (2 / Double(Int.max)) - 1) < 1e-14)
    #expect(throws: GlifiFailure.self) {
        try GlifiCooccurrenceCounts(
            jointCount: Int.max, firstOnlyCount: 1, secondOnlyCount: 0, neitherCount: 0)
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiKHWordAssociationAnalysis.scores(counts)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
