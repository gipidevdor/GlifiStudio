// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracolo: R 4.6.0 (fisher.test; Krippendorff e Fleiss implementati in R sulla matrice di
// coincidenze e sulla formula di Fleiss) con options(digits=15).

/// Tre codificatori (righe in R) × dieci unità, `nil` per i giudizi mancanti.
private let reliabilityUnits: [[Double?]] = [
    [1, 1, nil], [2, 2, 3], [3, 3, 3], [3, 3, 3], [2, 2, 2],
    [1, 2, 3], [4, 4, 4], [1, 1, 2], [2, 2, 2], [nil, 5, 5],
]

@Test("Krippendorff alpha coincide con R ai livelli nominale, intervallo e ordinale")
func krippendorffLevelsMatchR() throws {
    let expected: [(GlifiMeasurementLevel, Double)] = [
        (.nominal, 0.675257731958763), (.interval, 0.862104187946885),
        (.ordinal, 0.804860524091293),
    ]
    for (level, value) in expected {
        let result = try GlifiAgreementAnalysis.krippendorffAlpha(reliabilityUnits, level: level)
        #expect(abs(result.alpha - value) < 1e-12)
        #expect(result.includedUnitCount == 10)
    }
    // Coerenza con l'implementazione nominale esistente sulle stesse etichette.
    let legacy = try GlifiAgreementAnalysis.krippendorffAlphaNominal(
        reliabilityUnits.map { $0.map { $0.map { String($0) } } }
    )
    #expect(abs(legacy.alpha - 0.675257731958763) < 1e-12)
    #expect(throws: GlifiFailure.self) {
        try GlifiAgreementAnalysis.krippendorffAlpha([[1, -1]], level: .ratio)
    }
    let interval = try GlifiAgreementAnalysis.krippendorffAlphaInterval(
        reliabilityUnits,
        level: .interval,
        resampleCount: 500,
        seed: 4
    )
    let repeated = try GlifiAgreementAnalysis.krippendorffAlphaInterval(
        reliabilityUnits,
        level: .interval,
        resampleCount: 500,
        seed: 4
    )
    #expect(interval == repeated)
    #expect(interval.lower <= 0.862104187946885)
    #expect(interval.upper <= 1)
}

@Test("Fleiss kappa coincide con R su quattro unità e tre codificatori")
func fleissKappaMatchesR() throws {
    let result = try GlifiAgreementAnalysis.fleissKappa([
        ["a", "a", "a"], ["a", "b", "b"], ["c", "c", "b"], ["a", "c", "c"],
    ])
    #expect(abs(result.kappa - 0.234042553191489) < 1e-12)
    #expect(abs(result.observedAgreement - 0.5) < 1e-12)
    #expect(abs(result.expectedAgreement - 0.347222222222222) < 1e-12)
    #expect(throws: GlifiFailure.self) { try GlifiAgreementAnalysis.fleissKappa([["a"], ["b"]]) }
}

@Test("Fisher esatto coincide con fisher.test e il Monte Carlo approssima il p esatto")
func fisherAndMonteCarloMatchReferences() throws {
    let balanced = try GlifiStatisticalFoundation.fisherExact([[3, 1], [1, 3]])
    #expect(abs(balanced.pValue - 0.485714285714286) < 1e-12)
    let greater = try GlifiStatisticalFoundation.fisherExact(
        [[3, 1], [1, 3]], alternative: .greater)
    #expect(abs(greater.pValue - 0.242857142857143) < 1e-12)
    let skewed = try GlifiStatisticalFoundation.fisherExact([[8, 1], [2, 5]])
    #expect(abs(skewed.pValue - 0.0349650349650349) < 1e-12)
    #expect(skewed.sampleOddsRatio == 20)

    // Per il 2×2 bilanciato il p esatto del χ² a margini fissati è 34/70 (tabelle con
    // |a-2|≥1 sotto la legge ipergeometrica): il Monte Carlo deve avvicinarlo.
    let simulated = try GlifiStatisticalFoundation.monteCarloChiSquare(
        [[3, 1], [1, 3]],
        simulationCount: 20_000,
        seed: 8
    )
    #expect(abs(simulated.statistic - 2) < 1e-12)
    #expect(abs(simulated.pValue - 34.0 / 70.0) < 0.02)
    let repeated = try GlifiStatisticalFoundation.monteCarloChiSquare(
        [[3, 1], [1, 3]],
        simulationCount: 20_000,
        seed: 8
    )
    #expect(simulated == repeated)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.monteCarloChiSquare([[0, 0], [1, 1]], seed: 1)
    }
}
