// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Associazione perfetta (b=c=0) produce NPMI=1, Dice=1, Jaccard=1 e valori esatti noti")
func collocationPerfectAssociationMatchesExactValues() throws {
    // a=1,b=0,c=0,d=3 → M=4; p(x,y)=p(x)=p(y)=1/4: caso in cui p²=p(x)p(y),
    // quindi NPMI=1 per la formula generale (non per il caso di continuità).
    let counts = try GlifiCooccurrenceCounts(
        jointCount: 1,
        firstOnlyCount: 0,
        secondOnlyCount: 0,
        neitherCount: 3
    )
    let measures = GlifiCollocationAnalysis.measures(counts)

    #expect(abs(try #require(measures.pmi) - log(4)) < 1e-12)
    #expect(abs(try #require(measures.npmi) - 1) < 1e-12)
    #expect(abs(try #require(measures.dice) - 1) < 1e-12)
    #expect(abs(try #require(measures.jaccard) - 1) < 1e-12)
    #expect(abs(try #require(measures.tScore) - 0.75) < 1e-12)
    #expect(abs(try #require(measures.logDice) - 14) < 1e-12)
}

@Test("p(x,y)=1 usa esplicitamente il valore di continuità NPMI=1, non la formula generale")
func collocationCompleteCoOccurrenceUsesContinuityValue() throws {
    let counts = try GlifiCooccurrenceCounts(
        jointCount: 5,
        firstOnlyCount: 0,
        secondOnlyCount: 0,
        neitherCount: 0
    )
    let measures = GlifiCollocationAnalysis.measures(counts)

    #expect(abs(try #require(measures.pmi)) < 1e-12)  // ln(1/(1·1)) = 0.
    #expect(measures.npmi == 1)
}

@Test("p(x,y)=0 lascia PMI, NPMI, t-score e logDice non definiti ma calcola Dice e Jaccard")
func collocationZeroJointLeavesPMIFamilyUndefined() throws {
    let counts = try GlifiCooccurrenceCounts(
        jointCount: 0,
        firstOnlyCount: 5,
        secondOnlyCount: 5,
        neitherCount: 10
    )
    let measures = GlifiCollocationAnalysis.measures(counts)

    #expect(measures.pmi == nil)
    #expect(measures.npmi == nil)
    #expect(measures.tScore == nil)
    #expect(measures.logDice == nil)
    #expect(measures.dice == 0)
    #expect(measures.jaccard == 0)
}

@Test("Un universo interamente vuoto lascia tutte le misure non definite")
func collocationEmptyUniverseLeavesEverythingUndefined() throws {
    let counts = try GlifiCooccurrenceCounts(
        jointCount: 0,
        firstOnlyCount: 0,
        secondOnlyCount: 0,
        neitherCount: 0
    )
    let measures = GlifiCollocationAnalysis.measures(counts)

    #expect(measures.pmi == nil)
    #expect(measures.npmi == nil)
    #expect(measures.dice == nil)
    #expect(measures.jaccard == nil)
    #expect(measures.tScore == nil)
    #expect(measures.logDice == nil)
}

@Test("I conteggi negativi vengono rifiutati con failure tipizzata")
func collocationRejectsNegativeCounts() throws {
    do {
        _ = try GlifiCooccurrenceCounts(
            jointCount: -1,
            firstOnlyCount: 0,
            secondOnlyCount: 0,
            neitherCount: 0
        )
        Issue.record("Il conteggio negativo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "collocation.negative-count")
    }
}
