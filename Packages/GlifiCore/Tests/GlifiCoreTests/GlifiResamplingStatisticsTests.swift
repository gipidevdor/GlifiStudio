// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("SplitMix64 riproduce la sequenza di riferimento pubblicata")
func splitMix64MatchesReferenceSequence() {
    // Valori di riferimento per seed 0 e 42, verificati con un'implementazione indipendente.
    var zero = GlifiSplitMix64(seed: 0)
    #expect(zero.next() == 0xE220_A839_7B1D_CDAF)
    #expect(zero.next() == 0x6E78_9E6A_A1B9_65F4)
    #expect(zero.next() == 0x06C4_5D18_8009_454F)
    var fortyTwo = GlifiSplitMix64(seed: 42)
    #expect(fortyTwo.next() == 0xBDD7_3226_2FEB_6E95)
    #expect(fortyTwo.next() == 0x28EF_E333_B266_F103)

    var bounded = GlifiSplitMix64(seed: 9)
    var repeated = GlifiSplitMix64(seed: 9)
    for _ in 0..<1_000 {
        let value = bounded.index(below: 7)
        #expect((0..<7).contains(value))
        #expect(value == repeated.index(below: 7))
    }
}

@Test("Il quantile di tipo 7 interpola linearmente fra le statistiche d'ordine")
func quantileType7Interpolates() throws {
    let values: [Double] = [1, 2, 3, 4]
    #expect(try GlifiStatisticalFoundation.quantileType7(values, probability: 0) == 1)
    #expect(try GlifiStatisticalFoundation.quantileType7(values, probability: 0.25) == 1.75)
    #expect(try GlifiStatisticalFoundation.quantileType7(values, probability: 0.5) == 2.5)
    #expect(try GlifiStatisticalFoundation.quantileType7(values, probability: 1) == 4)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.quantileType7(values, probability: 1.5)
    }
}

@Test("Il bootstrap percentile è riproducibile dal seed e rispetta i vincoli")
func bootstrapPercentileIsReproducible() throws {
    let sample: [Double] = [2, 4, 4, 5, 7, 9, 10]
    let first = try GlifiStatisticalFoundation.bootstrapMeanInterval(
        sample,
        resampleCount: 4_000,
        seed: 2_026
    )
    let second = try GlifiStatisticalFoundation.bootstrapMeanInterval(
        sample,
        resampleCount: 4_000,
        seed: 2_026
    )

    #expect(first == second)
    #expect(first.generatorIdentifier == "SplitMix64-v1")
    #expect(first.seed == 2_026)
    #expect(abs(first.estimate - 41.0 / 7.0) < 1e-12)
    #expect(first.lower < first.estimate)
    #expect(first.upper > first.estimate)
    #expect(first.lower >= 2)
    #expect(first.upper <= 10)

    let constant = try GlifiStatisticalFoundation.bootstrapMeanInterval(
        [3, 3, 3],
        resampleCount: 50,
        seed: 1
    )
    #expect(constant.lower == 3)
    #expect(constant.upper == 3)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.bootstrapMeanInterval(
            sample,
            confidenceLevel: 1,
            seed: 1
        )
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.bootstrapMeanInterval([1], seed: 1)
    }
}

@Test("Il test di permutazione esatto enumera le sei assegnazioni")
func exactPermutationTestEnumeratesAssignments() throws {
    // x=[1,2], y=[3,4]: differenze delle 6 assegnazioni -2,-1,0,0,1,2; osservata -2.
    // Bilaterale |d|≥2: 2/6; less d≤-2: 1/6; greater d≥-2: 6/6.
    let both = try GlifiStatisticalFoundation.permutationMeanDifference(
        [1, 2],
        [3, 4],
        strategy: .exact
    )
    let less = try GlifiStatisticalFoundation.permutationMeanDifference(
        [1, 2],
        [3, 4],
        alternative: .less,
        strategy: .exact
    )
    let greater = try GlifiStatisticalFoundation.permutationMeanDifference(
        [1, 2],
        [3, 4],
        alternative: .greater,
        strategy: .exact
    )

    #expect(both.observedDifference == -2)
    #expect(both.evaluatedCount == 6)
    #expect(both.extremeCount == 2)
    #expect(abs(both.pValue - 1.0 / 3.0) < 1e-12)
    #expect(abs(less.pValue - 1.0 / 6.0) < 1e-12)
    #expect(greater.pValue == 1)
    #expect(GlifiStatisticalFoundation.binomialCoefficient(5, 2) == 10)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.permutationMeanDifference(
            Array(repeating: 1, count: 20),
            Array(repeating: 2, count: 20),
            strategy: .exact
        )
    }
}

@Test("Il test di permutazione Monte Carlo è riproducibile e corretto con (b+1)/(m+1)")
func monteCarloPermutationTestApproximatesExact() throws {
    let strategy = GlifiPermutationStrategy.monteCarlo(sampleCount: 20_000, seed: 7)
    let first = try GlifiStatisticalFoundation.permutationMeanDifference(
        [1, 2],
        [3, 4],
        strategy: strategy
    )
    let second = try GlifiStatisticalFoundation.permutationMeanDifference(
        [1, 2],
        [3, 4],
        strategy: strategy
    )

    #expect(first == second)
    #expect(first.pValue == Double(first.extremeCount + 1) / 20_001)
    // Errore standard ≈ √(1/3·2/3/20000) ≈ 0,0033: 0,02 corrisponde a circa 6 errori standard.
    #expect(abs(first.pValue - 1.0 / 3.0) < 0.02)

    let extreme = try GlifiStatisticalFoundation.permutationMeanDifference(
        [1, 2, 3, 4, 5, 6],
        [100, 101, 102, 103, 104, 105],
        alternative: .less,
        strategy: .monteCarlo(sampleCount: 999, seed: 3)
    )
    #expect(extreme.pValue >= 1.0 / 1_000)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.permutationMeanDifference(
            [1],
            [2],
            strategy: .monteCarlo(sampleCount: 0, seed: 1)
        )
    }
}
