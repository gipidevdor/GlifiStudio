// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Exact permutation tails preserve units and a common translation")
func inferencePermutationExactPreservesAffineUnits() throws {
    // Six assignments have differences -2,-1,0,0,1,2 before transformation.
    // A positive scale and a common translation preserve their ordering and ties.
    let transforms: [(offset: Double, scale: Double)] = [(0, 1e-14), (1e12, 1)]
    let alternatives: [(GlifiAlternativeHypothesis, Int)] = [
        (.twoSided, 2), (.less, 1), (.greater, 6),
    ]
    for transform in transforms {
        let values = (0..<4).map { transform.offset + Double($0) * transform.scale }
        for (alternative, expectedExtremeCount) in alternatives {
            let result = try GlifiStatisticalFoundation.permutationMeanDifference(
                Array(values.prefix(2)), Array(values.suffix(2)),
                alternative: alternative, strategy: .exact)
            #expect(result.evaluatedCount == 6)
            #expect(result.extremeCount == expectedExtremeCount)
            #expect(
                inferenceStabilityClose(
                    result.pValue, Double(expectedExtremeCount) / 6))
            #expect(inferenceStabilityClose(result.observedDifference, -2 * transform.scale))
        }
    }
}

@Test("Seeded Monte Carlo permutations preserve affine units and counts")
func inferencePermutationMonteCarloPreservesAffineUnits() throws {
    let strategy = GlifiPermutationStrategy.monteCarlo(sampleCount: 257, seed: 328)
    let baseline = try GlifiStatisticalFoundation.permutationMeanDifference(
        [0, 1], [2, 3], strategy: strategy)
    for transform in [(offset: 0.0, scale: 1e-14), (offset: 1e12, scale: 1.0)] {
        let values = (0..<4).map { transform.offset + Double($0) * transform.scale }
        let result = try GlifiStatisticalFoundation.permutationMeanDifference(
            Array(values.prefix(2)), Array(values.suffix(2)), strategy: strategy)
        #expect(result.strategy == baseline.strategy)
        #expect(result.evaluatedCount == baseline.evaluatedCount)
        #expect(result.extremeCount == baseline.extremeCount)
        #expect(result.pValue == baseline.pValue)
    }
}

@Test(
    "Location t tests retain representable deviation and inference at extreme scales",
    arguments: [1e308, 1e-300])
func inferenceLocationTUsesRepresentableScaledMoments(scale: Double) throws {
    // [scale,0] has mean scale/2, sample SD scale/sqrt(2), t=1, df=1.
    // The exact two-sided Cauchy tail at t=1 is 1/2.
    let oneSample = try GlifiStatisticalFoundation.oneSampleTTest([scale, 0])
    let paired = try GlifiStatisticalFoundation.pairedTTest([scale, 0], [0, 0])
    for result in [oneSample, paired] {
        #expect(result.mean.isFinite)
        #expect(result.standardDeviation.isFinite)
        #expect(inferenceStabilityClose(result.mean, scale / 2))
        #expect(inferenceStabilityClose(result.standardDeviation, scale / 2.0.squareRoot()))
        #expect(inferenceStabilityClose(result.statistic, 1))
        #expect(result.degreesOfFreedom == 1)
        #expect(inferenceStabilityClose(result.pValue, 0.5))
    }
}

@Test(
    "Cohen d retains the representable pooled deviation at extreme scales",
    arguments: [1e308, 1e-300])
func inferenceCohenDUsesRepresentableScaledMoments(scale: Double) throws {
    // Means differ by scale and the pooled SD is scale/sqrt(2), so d=sqrt(2).
    let result = try GlifiStatisticalFoundation.cohenDPooled([scale, 0], [0, -scale])
    #expect(result.pooledStandardDeviation.isFinite)
    #expect(inferenceStabilityClose(result.pooledStandardDeviation, scale / 2.0.squareRoot()))
    #expect(inferenceStabilityClose(result.d, 2.0.squareRoot()))
}

@Test("Bootstrap means of a large finite constant remain the same constant", arguments: [2, 3, 5])
func inferenceBootstrapMeanHandlesRepresentableLargeConstant(count: Int) throws {
    let value = 1e308
    let sample = Array(repeating: value, count: count)
    let independent = try GlifiStatisticalFoundation.bootstrapMeanInterval(
        sample, resampleCount: 32, seed: 328)
    let block = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
        sample, blockLength: 2, resampleCount: 32, seed: 328)
    for result in [independent, block] {
        #expect(result.estimate == value)
        #expect(result.lower == value)
        #expect(result.upper == value)
        #expect(result.lower.isFinite && result.upper.isFinite)
        #expect(result.resampleCount == 32)
        #expect(result.seed == 328)
    }
}

@Test("Type-7 quantiles remain convex for finite extremes of opposite signs")
func inferenceQuantileType7PreservesExtremeConvexCombinations() throws {
    let magnitude = 1e308
    let cases: [(probability: Double, expected: Double)] = [
        (0, -magnitude), (0.25, -magnitude / 2), (0.5, 0),
        (0.75, magnitude / 2), (1, magnitude),
    ]
    for entry in cases {
        let result = try GlifiStatisticalFoundation.quantileType7(
            [-magnitude, magnitude], probability: entry.probability)
        #expect(result.isFinite)
        #expect(inferenceStabilityClose(result, entry.expected))
    }
}

@Test("A nonrepresentable observed mean difference fails instead of returning infinity")
func inferencePermutationRejectsUnrepresentableObservedDifference() {
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.permutationMeanDifference(
            [1e308], [-1e308], strategy: .exact)
    }
}

@Test("A nonrepresentable final deviation fails instead of returning a false success")
func inferenceMomentsRejectUnrepresentableFinalDeviation() {
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.oneSampleTTest([-1.7e308, 1.7e308])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.cohenDPooled(
            [-1.7e308, 1.7e308], [-1.7e308, 1.7e308])
    }
}

@Test("BCa mean intervals preserve a large exact power-of-two change of units")
func inferenceBCaPreservesRepresentableLargeScale() throws {
    let sample: [Double] = [1, 2, 4, 8, 16]
    let scale = Double(sign: .plus, exponent: 500, significand: 1)
    let ordinary = try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
        sample, confidenceLevel: 0.9, resampleCount: 512, seed: 328)
    let scaled = try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
        sample.map { $0 * scale }, confidenceLevel: 0.9, resampleCount: 512, seed: 328)
    #expect(inferenceStabilityClose(scaled.estimate / scale, ordinary.estimate))
    #expect(inferenceStabilityClose(scaled.lower / scale, ordinary.lower))
    #expect(inferenceStabilityClose(scaled.upper / scale, ordinary.upper))
    #expect(inferenceStabilityClose(scaled.acceleration, ordinary.acceleration))
    #expect(scaled.biasCorrection == ordinary.biasCorrection)
    #expect(inferenceStabilityClose(scaled.lowerProbability, ordinary.lowerProbability))
    #expect(inferenceStabilityClose(scaled.upperProbability, ordinary.upperProbability))
}

@Test("Paired rank tests reject unrepresentable differences before manufacturing ties")
func inferencePairedRanksRejectOverflowedDifferences() {
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.wilcoxonSignedRank(
            [1e308, -1.1e308, 1.5e308], [-1e308, 1.1e308, -1.5e308],
            method: .asymptotic(continuityCorrection: false))
    }
}

@Test("Cohen d preserves small group contrasts over a common large offset")
func inferenceCohenDPreservesSmallContrastsOverLargeOffset() throws {
    let offset = 1e6
    let result = try GlifiStatisticalFoundation.cohenDPooled(
        [offset, offset, offset + 1], [offset, offset + 1, offset + 1])
    // Means differ by -1/3 and both sample variances are 1/3.
    #expect(inferenceStabilityClose(result.d, -1 / 3.0.squareRoot()))
    #expect(inferenceStabilityClose(result.pooledStandardDeviation, 1 / 3.0.squareRoot()))
}

@Test("Type-7 ordinary arithmetic retains its existing positive-zero bit pattern")
func inferenceQuantileType7RetainsOrderedArithmeticSignedZero() throws {
    let samples: [[Double]] = [[-0.0, 0.0], [-0.0, -0.0]]
    for values in samples {
        for probability in [0.0, 0.5, 1.0] {
            let value = try GlifiStatisticalFoundation.quantileType7(
                values, probability: probability)
            #expect(value.bitPattern == Double(0).bitPattern)
        }
    }
}

@Test("Paired t preserves the small spread of admissible relative-frequency metrics")
func inferencePairedTPreservesSmallRelativeFrequencySpread() throws {
    let ordinary = 999_999.0 / 1_000_000
    let shifted = 999_998.0 / 999_999
    let sample = Array(repeating: ordinary, count: 4) + [shifted]
    let difference = shifted - ordinary
    // Four a values and one a+d have sample SD abs(d)/sqrt(5), and
    // t=(5a+d)/abs(d) for zero hypothesis, without subtracting a rounded mean.
    let expectedDeviation = abs(difference) / 5.0.squareRoot()
    let expectedT = (5 * ordinary + difference) / abs(difference)
    let result = try GlifiStatisticalFoundation.pairedTTest(
        sample, Array(repeating: 0, count: 5))
    #expect(inferenceStabilityClose(result.standardDeviation, expectedDeviation))
    #expect(inferenceStabilityClose(result.statistic, expectedT))
    #expect(result.degreesOfFreedom == 4)
}

@Test(
    "Bootstrap scaling reserves headroom for ordered accumulation roundoff",
    arguments: [100, 1_000])
func inferenceBootstrapReservesAccumulationHeadroom(count: Int) throws {
    // The exact n*x is below max, but repeated binary64 addition can overflow.
    let value = (Double.greatestFiniteMagnitude / Double(count)).nextDown
    let sample = Array(repeating: value, count: count)
    let independent = try GlifiStatisticalFoundation.bootstrapMeanInterval(
        sample, resampleCount: 2, seed: 328)
    let block = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
        sample, blockLength: count, resampleCount: 2, seed: 328)
    for result in [independent, block] {
        #expect(result.estimate == value)
        #expect(result.lower == value)
        #expect(result.upper == value)
    }
}

@Test(
    "Cohen d retains finite extreme contrasts when normalization alone overflows",
    arguments: [0, -100], [1.0, -1.0])
func inferenceCohenDContrastNormalizationRetainsFiniteRatio(
    unitExponent: Int, direction: Double
) throws {
    let unit = Double(sign: .plus, exponent: unitExponent, significand: 1)
    let first = Array(repeating: direction * 1e308 * unit, count: 2)
    let second = [0.0, 0.9 * unit, -0.9 * unit]
    // The groups have sums of squares 0 and 2*(0.9*unit)^2, with 3 pooled df.
    let expectedDeviation = 0.9 * (2.0 / 3).squareRoot() * unit
    let expectedD = direction * 1e308 / (0.9 * (2.0 / 3).squareRoot())
    let forward = try GlifiStatisticalFoundation.cohenDPooled(first, second)
    let reversed = try GlifiStatisticalFoundation.cohenDPooled(second, first)
    #expect(inferenceStabilityClose(forward.pooledStandardDeviation, expectedDeviation))
    #expect(inferenceStabilityClose(reversed.pooledStandardDeviation, expectedDeviation))
    #expect(inferenceStabilityClose(forward.d, expectedD))
    #expect(inferenceStabilityClose(reversed.d, -expectedD))
}

@Test(
    "Location t retains finite extreme hypotheses when normalization alone overflows",
    arguments: [0, -100], [1.0, -1.0])
func inferenceLocationTContrastNormalizationRetainsFiniteRatio(
    unitExponent: Int, direction: Double
) throws {
    let unit = Double(sign: .plus, exponent: unitExponent, significand: 1)
    let sample = [0.0, 0.99 * unit, -0.99 * unit]
    let hypothesis = direction * 1e308 * unit
    // Mean 0 and sample SD 0.99*unit give t=-hypothesis*sqrt(3)/(0.99*unit).
    let expectedT = -direction * 1e308 / (0.99 / 3.0.squareRoot())
    let oneSample = try GlifiStatisticalFoundation.oneSampleTTest(
        sample, hypothesizedMean: hypothesis)
    let paired = try GlifiStatisticalFoundation.pairedTTest(
        sample, Array(repeating: 0, count: 3), hypothesizedDifference: hypothesis)
    for result in [oneSample, paired] {
        #expect(result.mean == 0)
        #expect(inferenceStabilityClose(result.standardDeviation, 0.99 * unit))
        #expect(inferenceStabilityClose(result.statistic, expectedT))
        #expect(result.degreesOfFreedom == 2)
        #expect(result.pValue == 0)
    }
}

@Test("Finite extreme contrast ratios retain subnormal reported deviations")
func inferenceContrastRatiosRetainSubnormalDeviations() throws {
    let minimum = Double.leastNonzeroMagnitude
    let cohen = try GlifiStatisticalFoundation.cohenDPooled(
        [2e-15, 2e-15], [0, 3 * minimum, -3 * minimum])
    // Decimal at 100 digits, using the exact binary64 input values:
    // d=Double(2e-15)/(sqrt(6)*Double.leastNonzeroMagnitude).
    #expect(cohen.pooledStandardDeviation == 2 * minimum)
    #expect(inferenceStabilityClose(cohen.d, 1.6526074779748667e308))

    let location = try GlifiStatisticalFoundation.oneSampleTTest(
        [0, 7 * minimum, -7 * minimum], hypothesizedMean: 3.56e-15)
    // Decimal at 100 digits: t=-Double(3.56e-15)*sqrt(3)/(7*minimum).
    #expect(location.standardDeviation == 7 * minimum)
    #expect(inferenceStabilityClose(location.statistic, -1.782903873155841e308))
    #expect(location.pValue == 0)
}

@Test("Genuinely unrepresentable final contrast ratios retain typed failures")
func inferenceUnrepresentableFinalContrastStillFails() {
    let operations: [() throws -> Void] = [
        {
            _ = try GlifiStatisticalFoundation.cohenDPooled(
                [1.6e308, 1.6e308], [0, 0.9, -0.9])
        },
        {
            _ = try GlifiStatisticalFoundation.oneSampleTTest(
                [0, 0.9, -0.9], hypothesizedMean: 1e308)
        },
    ]
    for operation in operations {
        do {
            try operation()
            Issue.record("A nonrepresentable final contrast must retain its typed failure.")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "statistics.non-finite-result")
            #expect(failure.category == .invalidInput)
        } catch {
            Issue.record(error)
        }
    }
}

@Test(
    "Standardized effects retain finite uncertainty when only the squared effect overflows",
    arguments: [0, -100], [1.0, -1.0])
func inferenceStandardizedDifferenceAvoidsSquaredEffectOverflow(
    unitExponent: Int, direction: Double
) throws {
    let unit = Double(sign: .plus, exponent: unitExponent, significand: 1)
    let result = try GlifiStatisticalFoundation.standardizedDifference(
        Array(repeating: direction * 1e200 * unit, count: 2),
        [0, 0.9 * unit, -0.9 * unit])
    // With df=3, J=sqrt(pi/6), g=direction*1e200*sqrt(pi)/1.8.
    // The additive 5/6 in SE^2 is below binary64 resolution relative to d^2/10.
    let expectedD = direction * 1e200 / (0.9 * (2.0 / 3).squareRoot())
    let expectedG = direction * 1e200 * Double.pi.squareRoot() / 1.8
    let expectedError = 1e200 / 5.4.squareRoot()
    let expectedMargin = 1.959963984540054 * expectedError
    #expect(inferenceStabilityClose(result.cohenD, expectedD))
    #expect(inferenceStabilityClose(result.correctionFactor, (Double.pi / 6).squareRoot()))
    #expect(inferenceStabilityClose(result.hedgesG, expectedG))
    #expect(inferenceStabilityClose(result.standardError, expectedError))
    #expect(inferenceStabilityClose(result.lower, expectedD - expectedMargin))
    #expect(inferenceStabilityClose(result.upper, expectedD + expectedMargin))
}

@Test(
    "A genuinely unrepresentable standardized-effect interval retains a typed failure",
    arguments: [1.0, -1.0])
func inferenceStandardizedDifferenceRejectsUnrepresentableInterval(direction: Double) {
    do {
        _ = try GlifiStatisticalFoundation.standardizedDifference(
            Array(repeating: direction * 1e308, count: 2), [0, 0.9, -0.9])
        Issue.record("An unrepresentable interval must not return a non-finite result.")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.non-finite-result")
        #expect(failure.category == .invalidInput)
    } catch {
        Issue.record(error)
    }
}

@Test("Standardized-effect confidence remains defined immediately below one")
func inferenceStandardizedDifferenceRetainsAdjacentUnitConfidence() throws {
    let level = 1.0.nextDown
    let result = try GlifiStatisticalFoundation.standardizedDifference(
        [1, 2, 3], [2, 3, 4], confidenceLevel: level)
    // Python NormalDist lower-tail oracle: z=-qnorm(2^-54), with no rounded upper tail.
    #expect(result.confidenceLevel == level)
    #expect(inferenceStabilityClose(result.cohenD, -1))
    #expect(inferenceStabilityClose(result.standardError, 0.75.squareRoot()))
    #expect(inferenceStabilityClose(result.lower, -8.181395349007829))
    #expect(inferenceStabilityClose(result.upper, 6.18139534900783))
}

@Test("Fisher confidence remains defined immediately below one")
func inferenceFisherIntervalRetainsAdjacentUnitConfidence() throws {
    let level = 1.0.nextDown
    let result = try GlifiStatisticalFoundation.pearsonFisherInterval(
        coefficient: 0.5, sampleCount: 10, confidenceLevel: level)
    #expect(result.confidenceLevel == level)
    #expect(inferenceStabilityClose(result.lower, -0.9886931412605833))
    #expect(inferenceStabilityClose(result.upper, 0.9987373371398001))
}

private func inferenceStabilityClose(_ actual: Double, _ expected: Double) -> Bool {
    guard actual.isFinite, expected.isFinite else { return false }
    if expected == 0 { return actual == 0 }
    return abs(actual / expected - 1) <= 1e-12
}
