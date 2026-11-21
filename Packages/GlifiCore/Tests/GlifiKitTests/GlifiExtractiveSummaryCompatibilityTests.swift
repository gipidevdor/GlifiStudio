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
            "TextRankSentence-v1", "TextRankSentence-configurable-v1",
            "LexRankSentence-continuous-v1", "LexRankSentence-threshold-v1",
        ])
    #expect(GlifiStudioSummaryRedundancy.standard.lambda == nil)
    let mmr = GlifiStudioSummaryRedundancy.maximalMarginalRelevance(lambda: 0.5)
    #expect(mmr.identifier == "MMR-v1")
    #expect(mmr.lambda == 0.5)
}

@Test("GlifiKit trasporta configurazione, convergenza, lineage e testo di TextRank/LexRank")
func summaryGraphPresentationPreservesContract() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitSummaryGraph-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.txt")
    let text = "Casa bella. Bella verde. Casa."
    try Data(text.utf8).write(to: source)
    let session = try await GlifiStudioService().createProject(at: root.appending(path: "P.glifi"))
    let imported = try await session.importText(at: source, format: .plainText)
    let sourceID = try #require(imported.project.sources.first?.sourceRevisionID)
    for method in [
        "TextRankSentence-configurable-v1", "LexRankSentence-continuous-v1",
        "LexRankSentence-threshold-v1",
    ] {
        #expect(GlifiStudioSummaryScoringMethod.supportedIdentifiers.contains(method))
        let result = try await session.analyzeExtractiveSummary(
            sourceRevisionIDs: [sourceID],
            method: GlifiStudioSummaryScoringMethod(identifier: method),
            graphConfiguration: GlifiStudioSummaryGraphConfiguration(damping: 0.5))
        #expect(result.methodIdentifier == method)
        #expect(result.graphDiagnostics?.configuration.damping == 0.5)
        #expect(result.graphDiagnostics?.converged == true)
        #expect(result.graphDiagnostics?.nodeCount == result.sentences.count)
        #expect(result.selected.allSatisfy { text.contains($0.text) })
        let encoded = try JSONEncoder().encode(result)
        #expect(
            try JSONDecoder().decode(GlifiStudioExtractiveSummaryResult.self, from: encoded)
                == result)
    }
    await session.close()
}
