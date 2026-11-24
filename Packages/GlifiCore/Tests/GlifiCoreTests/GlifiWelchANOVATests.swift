// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Welch ANOVA coincide con oneway.test di R su gruppi sbilanciati")
func welchANOVAMatchesR() throws {
    // R stats::oneway.test, var.equal=FALSE; 17 significant digits.
    let groups: [[Double]] = [[3, 4, 5], [6, 7, 9], [1, 2, 2, 4]]
    let result = try GlifiStatisticalFoundation.welchOneWayANOVA(groups)
    #expect(abs(result.fStatistic - 9.53739313787025) < 1e-12)
    #expect(result.numeratorDegreesOfFreedom == 2)
    #expect(abs(result.denominatorDegreesOfFreedom - 4.31788565443043) < 1e-12)
    #expect(abs(result.pValue - 0.0260464767746818) < 1e-12)
    for factor in [1e150, 1e-150] {
        let scaled = try GlifiStatisticalFoundation.welchOneWayANOVA(
            groups.map { $0.map { $0 * factor } }
        )
        #expect(abs(scaled.fStatistic - result.fStatistic) < 1e-12)
        #expect(abs(scaled.pValue - result.pValue) < 1e-12)
    }
    let reordered = try GlifiStatisticalFoundation.welchOneWayANOVA(groups.reversed())
    #expect(abs(reordered.fStatistic - result.fStatistic) < 1e-12)
}

@Test("Welch ANOVA a due gruppi equivale al quadrato del t di Welch")
func welchANOVATwoGroupsMatchTTest() throws {
    let first: [Double] = [2, 4, 6]
    let second: [Double] = [1, 2, 3]
    let omnibus = try GlifiStatisticalFoundation.welchOneWayANOVA([first, second])
    let location = try GlifiStatisticalFoundation.welchTTest(first, second)
    #expect(abs(omnibus.fStatistic - location.statistic * location.statistic) < 1e-12)
    #expect(abs(omnibus.denominatorDegreesOfFreedom - location.degreesOfFreedom) < 1e-12)
    #expect(abs(omnibus.pValue - location.pValue) < 1e-12)
}

@Test("Welch ANOVA rifiuta gruppi insufficienti, non finiti e degeneri")
func welchANOVARejectsInvalidInput() {
    for groups: [[Double]] in [
        [], [[1, 2]], [[1], [2, 3]], [[1, 1], [2, 3]], [[1, .nan], [2, 3]],
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.welchOneWayANOVA(groups)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.welchOneWayANOVA(Array(repeating: [1, 2], count: 100_001))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.welchOneWayANOVA([
            Array(repeating: 1, count: 1_000_001), [1, 2],
        ])
    }
}

@Test("Welch ANOVA osserva la cancellazione prima delle scansioni")
func welchANOVAObservesCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiStatisticalFoundation.welchOneWayANOVA([[1, 2], [2, 3]])
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch is CancellationError {
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Pearson conserva la correlazione per scale estreme finite")
func pearsonCorrelationIsScaleInvariant() throws {
    let x: [Double] = [-3, -1, 2, 5]
    let y: [Double] = [4, -2, 3, 6]
    for factor in [1.0, 1e150, 1e-150, 1e300, 1e-300] {
        let result = try GlifiStatisticalFoundation.pearsonCorrelation(
            x.map { $0 * factor }, y.map { $0 * factor }
        )
        #expect(abs(result.coefficient - 0.49669785125831173) < 1e-12)
        #expect(abs(result.pValue - 0.50330214874168822) < 1e-12)
    }
}

@Test("Pearson e Welch preservano piccole variazioni su un grande offset")
func statisticalTestsAreTranslationAndScaleInvariant() throws {
    let offset = 1e15
    let groups: [[Double]] = [[0, 1], [2, 3, 4]]
    // Independent reference: R on the equivalent translated small observations.
    let referenceF = 10.7142857142857
    let referenceDegrees = 2.88235294117647
    let referenceProbability = 0.0494162568625775
    let referenceCorrelation = 0.866025403784439
    for exponent in [-900, 0, 900] {
        let factor = Double(sign: .plus, exponent: exponent, significand: 1)
        let correlation = try GlifiStatisticalFoundation.pearsonCorrelation(
            [offset, offset, offset + 1].map { $0 * factor },
            [-offset, -offset + 1, -offset + 2].map { $0 * factor }
        )
        #expect(abs(correlation.coefficient - referenceCorrelation) < 1e-12)
        let omnibus = try GlifiStatisticalFoundation.welchOneWayANOVA(
            groups.map { $0.map { ($0 + offset) * factor } }
        )
        #expect(abs(omnibus.fStatistic - referenceF) < 1e-12)
        #expect(abs(omnibus.denominatorDegreesOfFreedom - referenceDegrees) < 1e-12)
        #expect(abs(omnibus.pValue - referenceProbability) < 1e-12)
    }
}

@Test("Pearson e Welch gestiscono anchor con differenze oltre il massimo binary64")
func statisticalAnchoringAvoidsSubtractionOverflow() throws {
    let largest = Double.greatestFiniteMagnitude
    let correlation = try GlifiStatisticalFoundation.pearsonCorrelation(
        [-largest, 0, largest], [-1, 0, 1]
    )
    #expect(abs(correlation.coefficient - 1) < 1e-12)
    let omnibus = try GlifiStatisticalFoundation.welchOneWayANOVA(
        [[-largest, -largest / 2], [largest / 2, largest]]
    )
    #expect(abs(omnibus.fStatistic - 18) < 1e-12)
    #expect(abs(omnibus.denominatorDegreesOfFreedom - 2) < 1e-12)
    // The common anchor 0 is safe, but the second group's own anchor -max is
    // opposite to +max. Equivalent small groups [[0,1],[-2,2]] give F=1/17,
    // df=(1/4+4)^2 / ((1/4)^2+4^2) = 289/257.
    let oppositeWithinGroup = try GlifiStatisticalFoundation.welchOneWayANOVA(
        [[0, largest / 2], [-largest, largest]])
    #expect(abs(oppositeWithinGroup.fStatistic - 1.0 / 17) < 1e-12)
    #expect(abs(oppositeWithinGroup.denominatorDegreesOfFreedom - 289.0 / 257) < 1e-12)
}

@Test("Welch conserva la varianza locale di gruppi con medie molto distanti")
func welchANOVADistantGroupAnchorsMatchDecimal() throws {
    // Decimal(80), evaluated independently in Oracles/Python/welch_precision.py.
    // Both groups have three observations, variances 1 and 1/3: df2 is exactly 3.2.
    // F is (9/4)A² - 3A + 1 for a positive second-group anchor, +3A for a negative one.
    for sign in [-1.0, 1.0] {
        let anchor = sign * 1e15
        let expectedF = sign > 0 ? 2.249999999999997e30 : 2.250000000000003e30
        let groups: [[Double]] = [[0, 1, 2], [anchor, anchor, anchor + 1]]
        for offset in [-1e15, 0, 1e15] {
            for exponent in [-900, 0, 900] {
                let scale = Double(sign: .plus, exponent: exponent, significand: 1)
                let translated = groups.map { $0.map { ($0 + offset) * scale } }
                for ordered in [
                    translated, Array(translated.reversed()),
                    translated.map { Array($0.reversed()) },
                ] {
                    let actual = try GlifiStatisticalFoundation.welchOneWayANOVA(ordered)
                    // A binary64 ULP near 1e30 exceeds 1e14: compare the dimensionless
                    // F ratio at the same 1e-12 tolerance, without relaxing any existing test.
                    #expect(abs(actual.fStatistic / expectedF - 1) < 1e-12)
                    #expect(abs(actual.denominatorDegreesOfFreedom - 3.2) < 1e-12)
                    #expect(actual.numeratorDegreesOfFreedom == 1)
                    #expect(actual.pValue.isFinite)
                    #expect((0...1).contains(actual.pValue))
                }
            }
        }
    }
}

@Test("Spearman esatto rifiuta NaN e infinito prima del ranking")
func exactSpearmanRejectsNonFiniteValues() {
    for value in [Double.nan, .infinity, -.infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.spearmanExactPValue([1, value, 3], [1, 2, 3])
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.spearmanExactPValue([1, 2, 3], [1, value, 3])
        }
    }
}

@Test("Le distribuzioni inferenziali rifiutano gradi di libertà infiniti")
func inferentialDistributionsRejectInfiniteDegrees() {
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: 1, degreesOfFreedom: .infinity, alternative: .twoSided)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
            statistic: 1, numeratorDegreesOfFreedom: .infinity, denominatorDegreesOfFreedom: 4)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
            statistic: 1, numeratorDegreesOfFreedom: 4, denominatorDegreesOfFreedom: .infinity)
    }
}
