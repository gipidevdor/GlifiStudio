// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Valori di riferimento da R 4.6.0 (qt, qnorm, pnorm, quantile type=7, lm, t.test,
// wilcox.test) con options(digits=15).

@Test("Il quantile della t coincide con qt di R")
func tQuantileMatchesR() throws {
    let cases: [(Double, Double, Double)] = [
        (0.975, 7, 2.36462425159278),
        (0.025, 4, -2.77644510519779),
        (0.9, 2.5, 1.73025092880718),
    ]
    for (probability, degrees, reference) in cases {
        let value = try GlifiStatisticalFoundation.tQuantile(
            probability,
            degreesOfFreedom: degrees
        )
        #expect(abs(value - reference) < 1e-10)
    }
    #expect(try GlifiStatisticalFoundation.tQuantile(0.5, degreesOfFreedom: 3) == 0)
}

@Test("L'intervallo BCa coincide con la formula calcolata in R sugli stessi replicati")
func bcaIntervalMatchesR() throws {
    let sample: [Double] = [2, 4, 4, 5, 7, 9, 10]
    let replicates: [Double] = [
        4.1, 5.2, 5.9, 6.3, 4.8, 7.0, 5.5, 6.1, 5.85, 6.6, 4.4, 5.0, 7.3, 6.9, 5.7, 6.0,
        5.1, 4.9, 6.8, 5.3,
    ]
    let total = sample.reduce(0, +)
    let result = try GlifiStatisticalFoundation.bcaInterval(
        estimate: total / 7,
        sortedReplicates: replicates.sorted(),
        jackknife: sample.map { (total - $0) / 6 },
        confidenceLevel: 0.9,
        seed: 0
    )

    #expect(abs(result.biasCorrection - 0.125661346855074) < 1e-12)
    #expect(abs(result.acceleration - 0.0150803276332601) < 1e-12)
    #expect(abs(result.lowerProbability - 0.0869931710473042) < 1e-12)
    #expect(abs(result.upperProbability - 0.974097208439807) < 1e-12)
    #expect(abs(result.lower - 4.66114809995951) < 1e-11)
    #expect(abs(result.upper - 7.1523540881069) < 1e-11)

    let bootstrap = try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
        sample,
        resampleCount: 3_000,
        seed: 11
    )
    let repeated = try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
        sample,
        resampleCount: 3_000,
        seed: 11
    )
    #expect(bootstrap == repeated)
    #expect(bootstrap.lower < bootstrap.estimate)
    #expect(bootstrap.upper > bootstrap.estimate)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.bootstrapMeanBCaInterval([3, 3, 3], seed: 1)
    }
}

@Test("I contrasti pianificati coincidono con lm di R e correggono la famiglia")
func plannedContrastsMatchR() throws {
    let groups: [[Double]] = [[3, 4, 5], [6, 7, 9], [1, 2, 2, 4]]
    let results = try GlifiStatisticalFoundation.plannedContrasts(
        groups,
        contrasts: [[1, -0.5, -0.5], [0, 1, -1]]
    )
    let expected: [(Double, Double, Double, Double)] = [
        (-0.791666666666667, 0.884023764314634, -0.895526453726535, 0.400251008730844),
        (5.08333333333333, 0.975391659226635, 5.21158171207224, 0.0012371748295029),
    ]
    for (result, reference) in zip(results, expected) {
        #expect(abs(result.estimate - reference.0) < 1e-12)
        #expect(abs(result.standardError - reference.1) < 1e-12)
        #expect(abs(result.tStatistic - reference.2) < 1e-12)
        #expect(result.degreesOfFreedom == 7)
        #expect(abs(result.pValue - reference.3) < 1e-12)
        #expect(abs(result.bonferroniPValue - min(1, 2 * reference.3)) < 1e-12)
        let critical = 2.36462425159278
        #expect(abs(result.lower - (reference.0 - critical * reference.1)) < 1e-9)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.plannedContrasts(groups, contrasts: [[1, 1, -1]])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.plannedContrasts(groups, contrasts: [[1, -1]])
    }
}

@Test("t appaiato e Wilcoxon appaiato esatto coincidono con t.test e wilcox.test di R")
func pairedTestsMatchR() throws {
    let x: [Double] = [0.5, 0.25, 0.2, 0.4, 0.1]
    let y: [Double] = [0.1, 0.3, 0.05, 0.2, 0.0]
    let paired = try GlifiStatisticalFoundation.pairedTTest(x, y)
    #expect(abs(paired.statistic - 2.18747496647892) < 1e-12)
    #expect(paired.degreesOfFreedom == 4)
    #expect(abs(paired.pValue - 0.0939565837741843) < 1e-12)
    let critical = try GlifiStatisticalFoundation.tQuantile(0.975, degreesOfFreedom: 4)
    let halfWidth = critical * paired.standardDeviation / 5.0.squareRoot()
    #expect(abs(paired.mean - halfWidth + 0.0430794517144603) < 1e-10)
    #expect(abs(paired.mean + halfWidth - 0.36307945171446) < 1e-10)
    #expect(abs(paired.mean / paired.standardDeviation - 0.978268544825189) < 1e-12)
    let wilcoxon = try GlifiStatisticalFoundation.wilcoxonSignedRank(x, y, method: .exact)
    #expect(abs(wilcoxon.pValue - 0.125) < 1e-12)
}
