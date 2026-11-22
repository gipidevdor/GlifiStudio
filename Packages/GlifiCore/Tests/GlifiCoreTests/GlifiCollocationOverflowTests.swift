// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("Le tabelle di collocazione rifiutano ogni somma oltre Int.max prima del calcolo")
func collocationCountsRejectOverflowingUniverse() throws {
    let maximum = Int.max
    let invalid = [
        [maximum, 1, 0, 0], [maximum, 0, 1, 0], [maximum, 0, 0, 1],
        [0, maximum, 1, 0], [0, 0, maximum, 1], [maximum, maximum, maximum, maximum],
    ]
    for values in invalid {
        do {
            _ = try GlifiCooccurrenceCounts(
                jointCount: values[0], firstOnlyCount: values[1],
                secondOnlyCount: values[2], neitherCount: values[3])
            Issue.record("An unrepresentable count universe was accepted")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "collocation.count-overflow")
            #expect(failure.category == .invalidInput)
        }
    }
}

@Test("Il massimo universo rappresentabile conserva margini e misure finite")
func collocationCountsAcceptMaximumRepresentableUniverse() throws {
    let maximum = Int.max
    let counts = try GlifiCooccurrenceCounts(
        jointCount: maximum - 3, firstOnlyCount: 1, secondOnlyCount: 1, neitherCount: 1)
    #expect(counts.universeSize == maximum)
    #expect(counts.firstMarginal == maximum - 2)
    #expect(counts.secondMarginal == maximum - 2)
    let measures = GlifiCollocationAnalysis.measures(counts)
    #expect(measures.pmi?.isFinite == true)
    #expect(measures.npmi?.isFinite == true)
    #expect(measures.tScore?.isFinite == true)
    #expect(measures.logDice?.isFinite == true)

    let full = GlifiCollocationAnalysis.measures(
        try .init(jointCount: maximum, firstOnlyCount: 0, secondOnlyCount: 0, neitherCount: 0))
    #expect(full.pmi == 0)
    #expect(full.npmi == 1)
    #expect(full.dice == 1)
    #expect(full.jaccard == 1)
    #expect(full.tScore == 0)
    #expect(full.logDice == 14)

    let empty = GlifiCollocationAnalysis.measures(
        try .init(jointCount: 0, firstOnlyCount: 0, secondOnlyCount: 0, neitherCount: 0))
    #expect(empty.pmi == nil)
    #expect(empty.npmi == nil)
    #expect(empty.dice == nil)
    #expect(empty.jaccard == nil)
    #expect(empty.tScore == nil)
    #expect(empty.logDice == nil)
}
