// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

/// P-value bilaterale della t di Student con 3 gradi di libertà in forma chiusa:
/// `F(t) = 1/2 + (1/π)[atan(t/√3) + (t/√3)/(1+t²/3)]`.
private func twoSidedTPValueWithThreeDegrees(_ t: Double) -> Double {
    let u = t / 3.0.squareRoot()
    let cdf = 0.5 + (atan(u) + u / (1 + u * u)) / Double.pi
    return 2 * (1 - cdf)
}

@Test("Pearson coincide con il calcolo a mano su cinque coppie")
func pearsonMatchesHandComputation() throws {
    // x=[1..5] (media 3), y=[2,4,5,4,5] (media 4): Sxy=6, Sxx=10, Syy=6,
    // r=6/√60, r²=3/5, t²=r²·3/(1-r²)=9/2, df=3.
    let result = try GlifiStatisticalFoundation.pearsonCorrelation(
        [1, 2, 3, 4, 5],
        [2, 4, 5, 4, 5]
    )

    #expect(result.methodIdentifier == "PearsonR-v1")
    #expect(abs(result.coefficient - 6.0 / 60.0.squareRoot()) < 1e-12)
    #expect(result.degreesOfFreedom == 3)
    #expect(abs(result.tStatistic - 4.5.squareRoot()) < 1e-12)
    #expect(abs(result.pValue - twoSidedTPValueWithThreeDegrees(4.5.squareRoot())) < 1e-9)
}

@Test("La correlazione perfetta ha t infinita e p nullo senza divisioni per zero")
func perfectCorrelationHasInfiniteStatistic() throws {
    let result = try GlifiStatisticalFoundation.pearsonCorrelation([1, 2, 3], [2, 4, 6])
    #expect(result.coefficient == 1)
    #expect(result.tStatistic == .infinity)
    #expect(result.pValue == 0)

    let opposite = try GlifiStatisticalFoundation.pearsonCorrelation(
        [1, 2, 3],
        [3, 2, 1],
        alternative: .greater
    )
    #expect(opposite.coefficient == -1)
    #expect(opposite.pValue == 1)
}

@Test("Spearman usa i ranghi medi in presenza di tie")
func spearmanUsesMidranks() throws {
    // y=[5,6,7,8,7] → ranghi [1,2,3.5,5,3.5]; x → [1,2,3,4,5].
    // Sxy=8, Sxx=10, Syy=9,5: ρ=8/√95, t²=3ρ²/(1-ρ²)=192/31.
    let result = try GlifiStatisticalFoundation.spearmanCorrelation(
        [1, 2, 3, 4, 5],
        [5, 6, 7, 8, 7]
    )

    #expect(result.methodIdentifier == "SpearmanRho-v1")
    #expect(abs(result.coefficient - 8.0 / 95.0.squareRoot()) < 1e-12)
    #expect(abs(result.tStatistic - (192.0 / 31.0).squareRoot()) < 1e-12)
    let expected = twoSidedTPValueWithThreeDegrees((192.0 / 31.0).squareRoot())
    #expect(abs(result.pValue - expected) < 1e-9)
}

@Test("Le correlazioni rifiutano lunghezze diverse, campioni piccoli e varianza nulla")
func correlationRejectsInvalidInput() {
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.pearsonCorrelation([1, 2, 3], [1, 2])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.pearsonCorrelation([1, 2], [1, 2])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.pearsonCorrelation([1, 2, 3], [4, 4, 4])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.spearmanCorrelation([1, .nan, 3], [1, 2, 3])
    }
}

@Test("Mann–Whitney esatto coincide con la distribuzione enumerata di U")
func mannWhitneyExactMatchesEnumeratedDistribution() throws {
    // x=[1,3,5], y=[2,4,6,8]: R₁=1+3+5=9, U₁=9-6=3, U₂=9.
    // Distribuzione di U per (3,4), C(7,3)=35: frequenze 1,1,2,3 per U=0..3.
    // P(U≤3)=7/35, P(U≥3)=1-4/35=31/35, bilaterale=min(1,2·7/35)=0,4.
    let lower = try GlifiStatisticalFoundation.mannWhitneyU(
        [1, 3, 5],
        [2, 4, 6, 8],
        alternative: .less,
        method: .exact
    )
    let upper = try GlifiStatisticalFoundation.mannWhitneyU(
        [1, 3, 5],
        [2, 4, 6, 8],
        alternative: .greater,
        method: .exact
    )
    let both = try GlifiStatisticalFoundation.mannWhitneyU(
        [1, 3, 5],
        [2, 4, 6, 8],
        method: .exact
    )

    #expect(lower.u1 == 3)
    #expect(lower.u2 == 9)
    #expect(abs(lower.pValue - 7.0 / 35.0) < 1e-12)
    #expect(abs(upper.pValue - 31.0 / 35.0) < 1e-12)
    #expect(abs(both.pValue - 0.4) < 1e-12)
    #expect(both.zStatistic == nil)
}

@Test("La distribuzione esatta di U somma a C(m+n,m) e ha frequenze note")
func mannWhitneyDistributionCounts() {
    let distribution = GlifiStatisticalFoundation.mannWhitneyDistribution(3, 4)
    #expect(distribution.reduce(0, +) == 35)
    #expect(Array(distribution.prefix(4)) == [1, 1, 2, 3])
    #expect(distribution.count == 13)
    #expect(distribution == distribution.reversed())
}

@Test("Mann–Whitney asintotico applica la correzione dei tie")
func mannWhitneyAsymptoticAppliesTieCorrection() throws {
    // x=[1,2,2], y=[2,3,4]: ranghi 1,3,3,3,5,6; R₁=7, U₁=1; media 4,5;
    // un gruppo di tie t=3: Σ(t³-t)=24; var=9/12·(7-24/30)=4,65;
    // z=(1-4,5)/√4,65 senza correzione di continuità, (1-4,5+0,5)/√4,65 con.
    let plain = try GlifiStatisticalFoundation.mannWhitneyU(
        [1, 2, 2],
        [2, 3, 4],
        method: .asymptotic(continuityCorrection: false)
    )
    let corrected = try GlifiStatisticalFoundation.mannWhitneyU(
        [1, 2, 2],
        [2, 3, 4],
        method: .asymptotic(continuityCorrection: true)
    )

    #expect(plain.u1 == 1)
    #expect(abs((plain.zStatistic ?? .nan) + 3.5 / 4.65.squareRoot()) < 1e-12)
    #expect(abs((corrected.zStatistic ?? .nan) + 3.0 / 4.65.squareRoot()) < 1e-12)
    #expect(corrected.pValue > plain.pValue)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.mannWhitneyU([1, 2, 2], [2, 3, 4], method: .exact)
    }
}

@Test("Kruskal–Wallis senza tie coincide con H=7,2 e p=exp(-3,6)")
func kruskalWallisMatchesClosedForm() throws {
    // Gruppi [1,2,3],[4,5,6],[7,8,9]: R=6,15,24, N=9,
    // H=12/90·(36+225+576)/3-30=7,2; con df=2 la coda è exp(-H/2).
    let result = try GlifiStatisticalFoundation.kruskalWallis(
        [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    )

    #expect(abs(result.hStatistic - 7.2) < 1e-12)
    #expect(result.tieCorrection == 1)
    #expect(result.degreesOfFreedom == 2)
    #expect(abs(result.pValue - exp(-3.6)) < 1e-12)
}

@Test("Kruskal–Wallis con tie applica il fattore di correzione")
func kruskalWallisAppliesTieCorrection() throws {
    // Gruppi [1,2],[2,3]: ranghi 1;2,5;2,5;4, R=3,5 e 6,5, N=4,
    // H=12/20·(3,5²/2+6,5²/2)-15=1,35; C=1-6/60=0,9; H/C=1,5;
    // con df=1 la coda è erfc(√(H/2)).
    let result = try GlifiStatisticalFoundation.kruskalWallis([[1, 2], [2, 3]])

    #expect(abs(result.hStatistic - 1.35) < 1e-12)
    #expect(abs(result.tieCorrection - 0.9) < 1e-12)
    #expect(abs(result.correctedHStatistic - 1.5) < 1e-12)
    #expect(abs(result.pValue - erfc(0.75.squareRoot())) < 1e-9)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.kruskalWallis([[1, 1], [1, 1]])
    }
}

@Test("Bonferroni e Benjamini–Hochberg preservano l'ordine originale")
func multipleComparisonAdjustmentsMatchDefinitions() throws {
    // Bonferroni m=3: [0,01,0,04,0,5]·3 = [0,03,0,12,1].
    let bonferroni = try GlifiStatisticalFoundation.bonferroniAdjustedPValues([0.01, 0.04, 0.5])
    #expect(bonferroni.enumerated().allSatisfy { abs($1 - [0.03, 0.12, 1.0][$0]) < 1e-12 })

    // BH m=4, ordinati 0,005 0,01 0,03 0,04 → m·p/j = 0,02 0,02 0,04 0,04;
    // minimo da destra invariato; ordine originale [0,01, 0,04, 0,03, 0,005].
    let adjusted = try GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues(
        [0.01, 0.04, 0.03, 0.005]
    )
    let expected = [0.02, 0.04, 0.04, 0.02]
    #expect(adjusted.enumerated().allSatisfy { abs($1 - expected[$0]) < 1e-12 })
    #expect(zip(adjusted, [0.01, 0.04, 0.03, 0.005]).allSatisfy { $0 >= $1 })

    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.bonferroniAdjustedPValues([0.1, 1.5])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues([])
    }
}

@Test("I ranghi medi assegnano la media dei ranghi occupati e contano i tie")
func midranksAverageTiedPositions() {
    let result = GlifiStatisticalFoundation.midranks([10, 20, 20, 30, 20])
    #expect(result.ranks == [1, 3, 3, 5, 3])
    #expect(result.tieGroupSizes == [3])
}
