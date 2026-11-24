// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Una distribuzione proporzionale all'opportunità produce DP e norma pari a zero")
func dispersionProportionalDistributionIsZero() throws {
    // f_i proporzionale a n_i (stessa costante 1): o_i = e_i per costruzione,
    // quindi GriesDP-v1 è zero indipendentemente dal calcolo in prova.
    let partition = try GlifiDispersionPartition(
        unitSizes: [10, 20, 30],
        unitFrequencies: [10, 20, 30]
    )

    let result = try GlifiDispersionAnalysis.dispersion(partition)

    #expect(abs(result.griesDP) < 1e-12)
    #expect(abs(try #require(result.griesDPNorm)) < 1e-12)
    // Partizione a dimensioni diseguali: Juilland D non è definito.
    #expect(result.juillandD == nil)
}

@Test("La concentrazione massima su parti uguali produce DP=2/3, norma=1 e JuillandD=0")
func dispersionMaximalConcentrationOnEqualPartsMatchesClosedForm() throws {
    // Tre parti di uguale dimensione 10 (N=30); tutta la frequenza (F=30) in una
    // sola parte: o=[1,0,0], e=[1/3,1/3,1/3].
    // DP = 0,5·(|1-1/3| + |0-1/3| + |0-1/3|) = 0,5·(4/3) = 2/3 per calcolo
    // indipendente su frazioni esatte.
    let partition = try GlifiDispersionPartition(
        unitSizes: [10, 10, 10],
        unitFrequencies: [30, 0, 0]
    )

    let result = try GlifiDispersionAnalysis.dispersion(partition)

    let expectedGriesDP = 2.0 / 3.0
    #expect(abs(result.griesDP - expectedGriesDP) < 1e-9)

    // minOpportunity = 10/30 = 1/3; denom = 1 - 1/3 = 2/3; norm = DP/denom = 1.
    let expectedNorm = 1.0
    #expect(abs(try #require(result.griesDPNorm) - expectedNorm) < 1e-9)

    // media = 30/3 = 10; varianza = ((30-10)² + (0-10)² + (0-10)²)/3 = 200;
    // sd = sqrt(200) = 10·sqrt(2); (sd/media)/sqrt(K-1) = sqrt(2)/sqrt(2) = 1;
    // D = 1 - 1 = 0 esatto.
    #expect(abs(try #require(result.juillandD)) < 1e-9)
}

@Test("Le dimensioni diseguali escludono sempre Juilland D indipendentemente dalla frequenza")
func dispersionUnequalPartitionNeverReportsJuillandD() throws {
    let partition = try GlifiDispersionPartition(
        unitSizes: [5, 15],
        unitFrequencies: [10, 10]
    )

    let result = try GlifiDispersionAnalysis.dispersion(partition)

    #expect(result.juillandD == nil)
    #expect(result.griesDPNorm != nil)
}

@Test("Una sola unità non definisce norma o Juilland D ma calcola comunque DP")
func dispersionSingleUnitOmitsNormAndJuillandD() throws {
    let partition = try GlifiDispersionPartition(unitSizes: [40], unitFrequencies: [12])

    let result = try GlifiDispersionAnalysis.dispersion(partition)

    #expect(abs(result.griesDP) < 1e-12)
    #expect(result.griesDPNorm == nil)
    #expect(result.juillandD == nil)
}

@Test("Totali degeneri e forme non valide vengono rifiutati con failure tipizzate")
func dispersionRejectsDegenerateAndInvalidInputs() throws {
    let zeroFrequencyPartition = try GlifiDispersionPartition(
        unitSizes: [10, 10],
        unitFrequencies: [0, 0]
    )
    do {
        _ = try GlifiDispersionAnalysis.dispersion(zeroFrequencyPartition)
        Issue.record("F=0 non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "dispersion.degenerate-totals")
    }

    do {
        _ = try GlifiDispersionPartition(unitSizes: [], unitFrequencies: [])
        Issue.record("La partizione vuota non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "dispersion.empty-partition")
    }

    do {
        _ = try GlifiDispersionPartition(unitSizes: [1, 2], unitFrequencies: [1])
        Issue.record("La forma incoerente non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "dispersion.shape-mismatch")
    }

    do {
        _ = try GlifiDispersionPartition(unitSizes: [-1], unitFrequencies: [1])
        Issue.record("Il conteggio negativo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "dispersion.negative-count")
    }
}
