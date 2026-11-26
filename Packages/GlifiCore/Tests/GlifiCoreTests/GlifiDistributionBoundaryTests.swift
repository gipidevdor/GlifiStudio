// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Normal quantiles remain finite through the subnormal probability tail")
func normalQuantileSubnormalTailMatchesR() throws {
    // R 4.6.0 stats::qnorm, run as an external oracle; no R code is embedded.
    let cases: [(Double, Double)] = [
        (Double.leastNonzeroMagnitude, -38.467405617144344),
        (1e-320, -38.26912534303265),
        (1e-310, -37.66306033194952),
        (1e-308, -37.54067492154594),
        (Double.leastNormalMagnitude, -37.51937934714449),
        (1e-300, -37.0470962993612),
    ]
    var previous = -Double.infinity
    for (probability, expected) in cases {
        let actual = try GlifiDistributionFunctions.normalQuantile(probability)
        #expect(actual.isFinite)
        #expect(abs(actual - expected) <= 2e-13)
        #expect(actual > previous)
        previous = actual
    }
}

@Test("Normal quantiles preserve symmetry and probabilities adjacent to the median")
func normalQuantileCentralSymmetry() throws {
    #expect(try GlifiDistributionFunctions.normalQuantile(0.5) == 0)
    for probability in [0.25, 0.125, 0.03125, Double.ulpOfOne / 2] {
        let lower = try GlifiDistributionFunctions.normalQuantile(probability)
        let upper = try GlifiDistributionFunctions.normalQuantile(1 - probability)
        #expect(abs(lower + upper) < 1e-14)
    }
    // Linearization at zero: Phi'(0) = 1/sqrt(2*pi). The next cubic term is <1e-46.
    for probability in [(0.5).nextDown, (0.5).nextUp] {
        let expected = (probability - 0.5) * (2 * Double.pi).squareRoot()
        let actual = try GlifiDistributionFunctions.normalQuantile(probability)
        #expect(abs((actual - expected) / expected) < 1e-14)
    }
}

@Test("The t quantile rejects non-finite degrees even at the median")
func tQuantileValidatesParametersBeforeMedianShortcut() {
    for probability in [0.25, 0.5, 0.75] {
        for degrees in [Double.infinity, -Double.infinity, Double.nan] {
            #expect(throws: GlifiFailure.self) {
                try GlifiStatisticalFoundation.tQuantile(probability, degreesOfFreedom: degrees)
            }
        }
    }
}

@Test("The t and F tails retain small complements and large statistics")
func distributionRatiosPreserveExtremeTails() throws {
    let nearMedian = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: 1e-8, degreesOfFreedom: 1, alternative: .twoSided)
    #expect(abs(nearMedian - 0.9999999936338022) < 1e-15)
    let cauchyTail = try GlifiStatisticalFoundation.tDistributionPValue(
        statistic: 1e200, degreesOfFreedom: 1, alternative: .twoSided)
    // Cauchy's exact tail is 2*atan(1/t)/pi; R confirms this finite nonzero tail.
    let exactTail = 2 * atan(1e-200) / Double.pi
    #expect(cauchyTail > 0)
    #expect(abs(cauchyTail / exactTail - 1) < 1e-12)
    let fTail = try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
        statistic: 1e-8, numeratorDegreesOfFreedom: 0.1, denominatorDegreesOfFreedom: 1_000)
    #expect(abs(fTail - 0.6479616261284402) < 1e-11)
}

@Test("Chi-square tails obey the closed forms at one and two degrees")
func chiSquareReimplementationMatchesClosedForms() throws {
    for statistic in [1e-8, 0.1, 1, 3, 10, 50, 100, 1_000] {
        let one = try chiSquareUpperTailProbability(statistic, degreesOfFreedom: 1)
        let two = try chiSquareUpperTailProbability(statistic, degreesOfFreedom: 2)
        let expectedOne = erfc((statistic / 2).squareRoot())
        let expectedTwo = exp(-statistic / 2)
        #expect(abs(one / expectedOne - 1) < 1e-12)
        #expect(abs(two / expectedTwo - 1) < 1e-12)
    }
}

@Test("Log-gamma uses caller-owned sign storage under concurrent workloads")
func nativeLogGammaIsReentrant() async {
    // Gamma changes sign between (-1,0) and (0,infinity); each task has local storage.
    let inputs: [Double] = [-0.5, 0.5, 1, 1.5, 7, 40, 1_000]
    let references = inputs.map(logGamma)
    await withTaskGroup(of: Bool.self) { group in
        for task in 0..<32 {
            group.addTask {
                for round in 0..<128 {
                    let index = (task + round) % inputs.count
                    if logGamma(inputs[index]) != references[index] { return false }
                }
                return true
            }
        }
        for await matchesReference in group {
            #expect(matchesReference)
        }
    }
}

@Test("The normal tail remains accurate and monotone across the logarithmic branch")
func normalQuantileLogTailBoundaryMatchesR() throws {
    // External R stats::qnorm references on both sides of magnitude 8.
    let cases: [(Double, Double)] = [
        (1e-16, -8.222082216130437),
        (6.220960574271785e-16, -8),
        (1e-15, -7.941345326170995),
        (1e-14, -7.650628092935268),
    ]
    var previous = -Double.infinity
    for (probability, reference) in cases {
        let value = try GlifiDistributionFunctions.normalQuantile(probability)
        #expect(abs(value - reference) < 2e-13)
        #expect(value > previous)
        previous = value
    }
    let boundary = GlifiDistributionFunctions.normalCDF(-8)
    let values = try [boundary.nextDown, boundary, boundary.nextUp].map {
        try GlifiDistributionFunctions.normalQuantile($0)
    }
    #expect(values[0] <= values[1])
    #expect(values[1] <= values[2])
    #expect(values.allSatisfy { abs($0 + 8) < 2e-13 })
}
