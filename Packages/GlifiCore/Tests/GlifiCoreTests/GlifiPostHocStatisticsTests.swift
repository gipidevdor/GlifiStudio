// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Valori di riferimento ottenuti da R 4.6.0 (stats::ptukey, qnorm, TukeyHSD,
// kruskal.test, cor.test) con options(digits=15): oracolo indipendente.
// ptukey di R ha un'accuratezza di circa 1e-9 (la quadratura di GlifiCore resta
// invariata entro 1e-15 quadruplicando i pannelli), quindi i p-value del range
// studentizzato sono confrontati a 5e-9 e gli intervalli di Tukey a 1e-7. Con gradi
// di libertà piccoli e non interi ptukey perde precisione (k=2, ν=3,448: 0,1122033
// contro 0,1122024 dell'identità esatta con pt di R), quindi Games–Howell è confrontato
// con R a 1e-6 e la precisione è garantita dall'identità esatta anche per ν frazionari.
private let referenceGroups: [[Double]] = [[3, 4, 5], [6, 7, 9], [1, 2, 2, 4]]

@Test("La distribuzione del range studentizzato coincide con ptukey di R")
func studentizedRangeMatchesR() throws {
    let cases: [(q: Double, k: Int, df: Double, reference: Double)] = [
        (3.5, 3, 10, 0.922896689161339),
        (2, 4, 5, 0.457516272781706),
        (4.2, 5, 20, 0.947646423321794),
        (3, 3, 1_000, 0.913945808478392),
        (6, 10, 3, 0.838126192338467),
        (2.5, 3, 2, 0.631658044638428),
        (5, 6, 60, 0.990179631905356),
    ]
    for entry in cases {
        let value = GlifiDistributionFunctions.studentizedRangeCDF(
            entry.q,
            groupCount: entry.k,
            degreesOfFreedom: entry.df
        )
        #expect(abs(value - entry.reference) < 5e-9)
    }
    // Oracolo esatto: per k=2, Q=√2|T_ν| quindi P(Q>q)=P(|T_ν|>q/√2).
    for (q, df) in [(1.0, 3.0), (3.0, 7.0), (5.5, 2.0), (2.2, 40.0), (3.0, 3.4482758620689653)] {
        let tail = GlifiDistributionFunctions.studentizedRangeUpperTail(
            q,
            groupCount: 2,
            degreesOfFreedom: df
        )
        let reference = try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: q / 2.0.squareRoot(),
            degreesOfFreedom: df,
            alternative: .twoSided
        )
        #expect(abs(tail - reference) < 1e-11)
    }
    #expect(
        GlifiDistributionFunctions.studentizedRangeCDF(0, groupCount: 3, degreesOfFreedom: 5) == 0)
}

@Test("Il quantile normale coincide con qnorm di R")
func normalQuantileMatchesR() throws {
    let cases: [(Double, Double)] = [
        (0.975, 1.95996398454005),
        (1e-10, -6.36134090240406),
        (0.3, -0.524400512708041),
        (0.999999, 4.75342430881709),
    ]
    for (probability, reference) in cases {
        #expect(abs(try GlifiDistributionFunctions.normalQuantile(probability) - reference) < 1e-12)
    }
    #expect(throws: GlifiFailure.self) { try GlifiDistributionFunctions.normalQuantile(1) }
}

@Test("Tukey HSD coincide con TukeyHSD di R, intervalli compresi")
func tukeyHSDMatchesR() throws {
    // R riporta «2-1» = x̄₂-x̄₁; qui le coppie sono i<j con differenza x̄ᵢ-x̄ⱼ.
    let result = try GlifiStatisticalFoundation.tukeyHSD(referenceGroups)
    let expected: [(difference: Double, lower: Double, upper: Double, p: Double)] = [
        (-3.33333333333333, -6.40425627540215, -0.262410391264515, 0.0355812847523661),
        (1.75, -1.12258537760134, 4.622585377601339, 0.2395488666796679),
        (5.08333333333333, 2.21074795573199, 7.955918710934673, 0.00306892904303591),
    ]
    #expect(
        result.map { [$0.firstGroupIndex, $0.secondGroupIndex] } == [[0, 1], [0, 2], [1, 2]])
    for (comparison, reference) in zip(result, expected) {
        #expect(abs(comparison.difference - reference.difference) < 1e-12)
        #expect(abs(try #require(comparison.lower) - reference.lower) < 1e-7)
        #expect(abs(try #require(comparison.upper) - reference.upper) < 1e-7)
        #expect(abs(comparison.pValue - reference.p) < 5e-9)
        #expect(comparison.degreesOfFreedom == 7)
    }
}

@Test("Games–Howell coincide con q, gradi di libertà Welch e ptukey di R")
func gamesHowellMatchesR() throws {
    let result = try GlifiStatisticalFoundation.gamesHowell(referenceGroups)
    let expected: [(q: Double, df: Double, p: Double)] = [
        (4.47213595499958, 3.44827586206897, 0.0851398452639205),
        (2.89827534923789, 4.93288590604027, 0.1967830500147777),
        (6.63592517728914, 3.88320870156356, 0.0216740700835191),
    ]
    for (comparison, reference) in zip(result, expected) {
        #expect(abs(comparison.statistic - reference.q) < 1e-12)
        #expect(abs(try #require(comparison.degreesOfFreedom) - reference.df) < 1e-12)
        #expect(abs(comparison.pValue - reference.p) < 1e-6)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.gamesHowell([[1, 1], [2, 3]])
    }
}

@Test("Dunn coincide con z e p calcolati in R sui ranghi medi con tie")
func dunnMatchesR() throws {
    let result = try GlifiStatisticalFoundation.dunn(referenceGroups)
    let expected: [(z: Double, p: Double)] = [
        (-1.42447923968532, 0.1543077905231703),
        (1.1421242720303, 0.2534023676961842),
        (2.66495663473736, 0.0076998251159425),
    ]
    for (comparison, reference) in zip(result, expected) {
        #expect(abs(comparison.statistic - reference.z) < 1e-12)
        #expect(abs(comparison.pValue - reference.p) < 1e-12)
    }
    let raw = result.map(\.pValue)
    let bonferroni = try GlifiStatisticalFoundation.bonferroniAdjustedPValues(raw)
    let hochberg = try GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues(raw)
    let expectedBonferroni = [0.4629233715695109, 0.7602071030885525, 0.0230994753478275]
    let expectedHochberg = [0.2314616857847555, 0.2534023676961842, 0.0230994753478275]
    for index in 0..<3 {
        #expect(abs(bonferroni[index] - expectedBonferroni[index]) < 1e-12)
        #expect(abs(hochberg[index] - expectedHochberg[index]) < 1e-12)
    }
    // Kruskal–Wallis sugli stessi gruppi: H corretto = 7,101993865031 (R), ε²=H/(N-1).
    let kruskal = try GlifiStatisticalFoundation.kruskalWallis(referenceGroups)
    #expect(abs(kruskal.correctedHStatistic - 7.101993865031) < 1e-9)
    #expect(abs(kruskal.pValue - 0.0286960173966) < 1e-11)
    let epsilon = GlifiStatisticalFoundation.kruskalEpsilonSquared(
        correctedH: kruskal.correctedHStatistic,
        totalCount: 10
    )
    #expect(abs(epsilon - 7.101993865031 / 9) < 1e-9)
}

@Test("Hedges g e l'intervallo di d coincidono con R")
func standardizedDifferenceMatchesR() throws {
    let result = try GlifiStatisticalFoundation.standardizedDifference(
        [1, 2, 3, 5], [4, 5, 6, 8, 9])
    #expect(abs(result.cohenD + 1.895715684803708) < 1e-12)
    #expect(abs(result.correctionFactor - 0.888202907672751) < 1e-12)
    #expect(abs(result.hedgesG + 1.683780183363494) < 1e-12)
    #expect(abs(result.standardError - 0.806009992962963) < 1e-12)
    #expect(abs(result.lower + 3.475466242190496) < 1e-12)
    #expect(abs(result.upper + 0.315965127416919) < 1e-12)
}

@Test("Rank-biserial deriva da U₁ con segno positivo se il primo campione è maggiore")
func rankBiserialFollowsDefinition() {
    // U₁=0 su 3×4 → r=-1; U₁=n₁n₂ → r=1; U₁=n₁n₂/2 → r=0.
    #expect(GlifiStatisticalFoundation.rankBiserial(u1: 0, firstCount: 3, secondCount: 4) == -1)
    #expect(GlifiStatisticalFoundation.rankBiserial(u1: 12, firstCount: 3, secondCount: 4) == 1)
    #expect(GlifiStatisticalFoundation.rankBiserial(u1: 6, firstCount: 3, secondCount: 4) == 0)
}

@Test("L'intervallo di Fisher-z e il p esatto di Spearman coincidono con cor.test di R")
func correlationIntervalAndExactSpearmanMatchR() throws {
    let x: [Double] = [1, 2, 3, 4, 5, 6]
    let y: [Double] = [2, 1, 4, 3, 6, 5]
    let pearson = try GlifiStatisticalFoundation.pearsonCorrelation(x, y)
    #expect(abs(pearson.coefficient - 0.828571428571429) < 1e-12)
    let interval = try GlifiStatisticalFoundation.pearsonFisherInterval(
        coefficient: pearson.coefficient,
        sampleCount: x.count
    )
    #expect(abs(interval.lower - 0.0519293188472778) < 1e-12)
    #expect(abs(interval.upper - 0.9806845993491808) < 1e-12)

    // cor.test(method = "spearman", exact = TRUE): 0,0583333333333333 = 42/720.
    #expect(
        abs(try GlifiStatisticalFoundation.spearmanExactPValue(x, y) - 0.0583333333333333) < 1e-12)
    let five = try GlifiStatisticalFoundation.spearmanExactPValue(
        [1, 2, 3, 4, 5], [2, 1, 4, 3, 5])
    #expect(abs(five - 0.133333333333333) < 1e-12)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.spearmanExactPValue([1, 2, 2, 3], [1, 2, 3, 4])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.pearsonFisherInterval(coefficient: 1, sampleCount: 5)
    }
}
