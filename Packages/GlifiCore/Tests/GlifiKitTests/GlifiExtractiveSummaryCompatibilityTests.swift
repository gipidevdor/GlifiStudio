// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("I messaggi di riassunto precedenti conservano l'eleggibilità lessicale", arguments: [0, 3])
func summaryPresentationDecodesLegacyEligibility(tokenCount: Int) throws {
    var payload: [String: Any] = [
        "sourceRevisionID": "synthetic-source-revision",
        "sentenceIndex": 0,
        "startUTF8": 0,
        "endUTF8": 8,
        "tokenCount": tokenCount,
        "score": tokenCount > 0 ? 0.5 : 0,
        "rank": 1,
        "isSelected": tokenCount > 0,
    ]
    let legacy = try JSONDecoder().decode(
        GlifiStudioSummarySentence.self, from: JSONSerialization.data(withJSONObject: payload))
    #expect(legacy.isEligible == (tokenCount > 0))
    #expect(legacy.isSelected == (tokenCount > 0))

    // An explicit current value takes precedence over the fallback, including a null vector.
    payload["isEligible"] = false
    payload["isSelected"] = false
    let current = try JSONDecoder().decode(
        GlifiStudioSummarySentence.self, from: JSONSerialization.data(withJSONObject: payload))
    #expect(!current.isEligible)
    let encoded = try JSONEncoder().encode(current)
    #expect(try JSONDecoder().decode(GlifiStudioSummarySentence.self, from: encoded) == current)
}

@Test("I messaggi di riassunto precedenti non hanno ordine di selezione né politica MMR")
func summaryPresentationDecodesLegacySelectionOrder() throws {
    var payload: [String: Any] = [
        "sourceRevisionID": "synthetic-source-revision",
        "sentenceIndex": 1,
        "startUTF8": 0,
        "endUTF8": 8,
        "tokenCount": 2,
        "score": 0.5,
        "rank": 1,
        "isEligible": true,
        "isSelected": true,
    ]
    let legacy = try JSONDecoder().decode(
        GlifiStudioSummarySentence.self, from: JSONSerialization.data(withJSONObject: payload))
    #expect(legacy.selectionOrder == nil)
    #expect(legacy.isSelected)
    payload["selectionOrder"] = 2
    let current = try JSONDecoder().decode(
        GlifiStudioSummarySentence.self, from: JSONSerialization.data(withJSONObject: payload))
    #expect(current.selectionOrder == 2)
    let encoded = try JSONEncoder().encode(current)
    #expect(try JSONDecoder().decode(GlifiStudioSummarySentence.self, from: encoded) == current)

    #expect(GlifiStudioSummaryRedundancy.supportedIdentifiers == ["redundancy.none-v1", "MMR-v1"])
    #expect(
        GlifiStudioSummaryScoringMethod.supportedIdentifiers == [
            "SentenceTFIDFMean-v1", "CentroidCosine-v1", "LexRankSentence-v1",
            "TextRankSentence-v1",
        ])
    #expect(GlifiStudioSummaryRedundancy.standard.lambda == nil)
    let mmr = GlifiStudioSummaryRedundancy.maximalMarginalRelevance(lambda: 0.5)
    #expect(mmr.identifier == "MMR-v1")
    #expect(mmr.lambda == 0.5)
}
