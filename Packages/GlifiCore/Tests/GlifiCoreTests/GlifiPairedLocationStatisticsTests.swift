// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("OneSampleT coincide con t=√2 e il p-value in forma chiusa con 4 gradi di libertà")
func oneSampleTMatchesClosedForm() throws {
    // x=[1..5], μ₀=2: x̄=3, s²=2,5, t=1/(√2,5/√5)=√2, df=4.
    // Per ν=4, con s=t/√(t²+4): P(|T|<t)=s·(1+(1-s²)/2); qui s²=1/3.
    let result = try GlifiStatisticalFoundation.oneSampleTTest(
        [1, 2, 3, 4, 5],
        hypothesizedMean: 2
    )

    #expect(result.methodIdentifier == "OneSampleT-v1")
    #expect(result.mean == 3)
    #expect(abs(result.standardDeviation - 2.5.squareRoot()) < 1e-12)
    #expect(abs(result.statistic - 2.0.squareRoot()) < 1e-12)
    #expect(result.degreesOfFreedom == 4)
    #expect(abs(result.pValue - (1 - 4 / (3 * 3.0.squareRoot()))) < 1e-9)
    let greater = try GlifiStatisticalFoundation.oneSampleTTest(
        [1, 2, 3, 4, 5],
        hypothesizedMean: 2,
        alternative: .greater
    )
    #expect(abs(greater.pValue - result.pValue / 2) < 1e-12)
}

@Test("PairedT è il t a un campione sulle differenze appaiate")
func pairedTMatchesDifferences() throws {
    // d=[2,3,4]: d̄=3, s=1, t=3√3, df=2; per ν=2 p=1-t/√(t²+2)=1-3√3/√29.
    let result = try GlifiStatisticalFoundation.pairedTTest([3, 5, 7], [1, 2, 3])

    #expect(result.methodIdentifier == "PairedT-v1")
    #expect(result.sampleCount == 3)
    #expect(abs(result.statistic - 3 * 3.0.squareRoot()) < 1e-12)
    #expect(result.degreesOfFreedom == 2)
    #expect(abs(result.pValue - (1 - 3 * 3.0.squareRoot() / 29.0.squareRoot())) < 1e-9)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.pairedTTest([1, 2, 3], [1, 2])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.pairedTTest([2, 3, 4], [1, 2, 3])
    }
}

@Test("Wilcoxon esatto scarta gli zeri e coincide con la legge enumerata di W⁺")
func wilcoxonExactMatchesEnumeratedLaw() throws {
    // d=[1,-2,3,4,0]: lo zero è scartato; ranghi 1,2,3,4; W⁺=8, W⁻=2.
    // Legge di W⁺ per n=4 (16 assegnazioni): 1,1,1,2,2,2,2,2,1,1,1.
    // P(W⁺≥8)=3/16, P(W⁺≤8)=14/16, bilaterale=6/16.
    let x: [Double] = [2, 0, 5, 6, 1]
    let y: [Double] = [1, 2, 2, 2, 1]
    let both = try GlifiStatisticalFoundation.wilcoxonSignedRank(x, y, method: .exact)
    let upper = try GlifiStatisticalFoundation.wilcoxonSignedRank(
        x,
        y,
        alternative: .greater,
        method: .exact
    )
    let lower = try GlifiStatisticalFoundation.wilcoxonSignedRank(
        x,
        y,
        alternative: .less,
        method: .exact
    )

    #expect(both.positiveRankSum == 8)
    #expect(both.negativeRankSum == 2)
    #expect(both.rankedCount == 4)
    #expect(both.droppedZeroCount == 1)
    #expect(both.zStatistic == nil)
    #expect(abs(both.pValue - 6.0 / 16.0) < 1e-12)
    #expect(abs(upper.pValue - 3.0 / 16.0) < 1e-12)
    #expect(abs(lower.pValue - 14.0 / 16.0) < 1e-12)
}

@Test("La legge esatta di W⁺ somma a 2ⁿ ed è simmetrica")
func wilcoxonDistributionCounts() {
    let distribution = GlifiStatisticalFoundation.wilcoxonDistribution(4)
    #expect(distribution == [1, 1, 1, 2, 2, 2, 2, 2, 1, 1, 1])
    let larger = GlifiStatisticalFoundation.wilcoxonDistribution(10)
    #expect(larger.reduce(0, +) == 1_024)
    #expect(larger == larger.reversed())
}

@Test("Wilcoxon asintotico applica la correzione dei tie e di continuità")
func wilcoxonAsymptoticAppliesTieCorrection() throws {
    // d=[1,1,-2,3]: |d| con ranghi 1,5;1,5;3;4; W⁺=7; media n(n+1)/4=5;
    // var=4·5·9/24-(2³-2)/48=7,375; z=2/√7,375 (senza) e 1,5/√7,375 (con).
    let x: [Double] = [2, 3, 1, 7]
    let y: [Double] = [1, 2, 3, 4]
    let plain = try GlifiStatisticalFoundation.wilcoxonSignedRank(
        x,
        y,
        method: .asymptotic(continuityCorrection: false)
    )
    let corrected = try GlifiStatisticalFoundation.wilcoxonSignedRank(x, y)

    #expect(plain.positiveRankSum == 7)
    #expect(abs((plain.zStatistic ?? .nan) - 2 / 7.375.squareRoot()) < 1e-12)
    #expect(abs((corrected.zStatistic ?? .nan) - 1.5 / 7.375.squareRoot()) < 1e-12)
    #expect(abs(plain.pValue - erfc(2 / 7.375.squareRoot() / 2.0.squareRoot())) < 1e-12)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.wilcoxonSignedRank(x, y, method: .exact)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.wilcoxonSignedRank([1, 2], [1, 2])
    }
}

@Test("CohenD-pooled coincide con d=-3 e rifiuta varianza nulla")
func cohenDPooledMatchesDefinition() throws {
    // [1,2,3] e [4,5,6]: medie 2 e 5, SS=2 e 2, s_p²=4/4=1, d=-3.
    let result = try GlifiStatisticalFoundation.cohenDPooled([1, 2, 3], [4, 5, 6])
    #expect(result.pooledStandardDeviation == 1)
    #expect(result.d == -3)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.cohenDPooled([2, 2], [2, 2])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.cohenDPooled([1], [2, 3])
    }
}
