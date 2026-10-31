// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracolo: Tests/Oracles/Python/summary.py (righe SUMMARY_* di expected.txt).
private func revision(_ index: Int) throws -> SourceRevisionID {
    try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index)")
}

private func sentence(_ index: Int, _ terms: [String]) throws -> GlifiSummaryCandidateSentence {
    GlifiSummaryCandidateSentence(
        range: try GlifiUTF8Range(start: index * 10, end: index * 10 + 5), terms: terms)
}

private func oracleDocuments() throws -> [GlifiSummaryDocument] {
    [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [
                try sentence(0, ["casa", "bella", "casa"]),
                try sentence(1, []),
                try sentence(2, ["bella", "giardino"]),
            ]
        ),
        GlifiSummaryDocument(
            sourceRevisionID: try revision(2),
            sentences: [
                try sentence(0, ["giardino", "verde"]),
                try sentence(1, ["casa"]),
            ]
        ),
    ]
}

private func close(_ value: Double, _ reference: Double) -> Bool {
    abs(value - reference) <= 1e-12 * max(1, abs(reference))
}

@Test("SentenceTFIDFMean-v1 coincide con l'oracolo Python: punteggi, rank e selezioni")
func extractiveSummaryMatchesPython() throws {
    let documents = try oracleDocuments()
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let bySentences = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 2),
        scheme: scheme)
    let scores = bySentences.sentences.map(\.score)
    let expected = [1.92198454876287, 0, 1.68982964258436, 1.20273255405408, 1]
    #expect(scores.count == expected.count)
    for (score, reference) in zip(scores, expected) {
        #expect(close(score, reference))
    }
    #expect(bySentences.sentences.map(\.rank) == [1, 5, 2, 3, 4])
    #expect(bySentences.sentences.map(\.sentenceIndex) == [0, 1, 2, 0, 1])
    #expect(bySentences.sentences.map(\.isSelected) == [true, false, true, false, false])
    #expect(bySentences.consumedBudget == 2)
    #expect(bySentences.rankedSentences.map(\.rank) == [1, 2, 3, 4, 5])
    #expect(bySentences.selectedSentences.map(\.sentenceIndex) == [0, 2])

    let byTokens = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .lexicalTokens, limit: 3),
        scheme: scheme)
    #expect(byTokens.sentences.map(\.isSelected) == [true, false, false, false, false])
    #expect(byTokens.consumedBudget == 3)
    #expect(byTokens.sentences.map(\.score) == bySentences.sentences.map(\.score))
}

@Test("Riassunto: frase senza token a punteggio zero mai scelta, parità per posizione, budget")
func extractiveSummaryEdgeCases() throws {
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let tied = [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [
                try sentence(0, ["a", "b"]),
                try sentence(1, []),
                try sentence(2, ["b", "a"]),
            ]
        )
    ]
    let summary = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: tied, budget: GlifiSummaryBudget(unit: .sentences, limit: 5), scheme: scheme)
    // Frasi duplicate: stesso punteggio, rank per posizione; la frase vuota resta ultima.
    #expect(summary.sentences[0].score == summary.sentences[2].score)
    #expect(summary.sentences.map(\.rank) == [1, 3, 2])
    #expect(summary.sentences.map(\.isSelected) == [true, false, true])
    #expect(summary.sentences[1].score == 0)
    #expect(summary.consumedBudget == 2)
    #expect(summary.eligibilityPolicy == "eligibility.lexical-tokens-required-v1")
    #expect(summary.tieBreakIdentifier == "tie-break.source-position-v1")
    #expect(summary.outputOrderIdentifier == "output-order.source-v1")

    // Un solo documento: l'IDF liscio resta definito e positivo.
    #expect(summary.sentences[0].score > 0)

    for limit in [0, -1, GlifiSummaryBudget.maximumLimit + 1] {
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiCorpusExtractiveSummaryAnalysis(
                documents: tied, budget: GlifiSummaryBudget(unit: .sentences, limit: limit),
                scheme: scheme)
        }
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: [], budget: .standard, scheme: scheme)
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: tied + tied, budget: .standard, scheme: scheme)
    }

    let empty = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: [GlifiSummaryDocument(sourceRevisionID: try revision(1), sentences: [])],
        budget: .standard, scheme: scheme)
    #expect(empty.sentences.isEmpty)
    #expect(empty.consumedBudget == 0)

    let encoded = try JSONEncoder().encode(summary)
    #expect(
        try JSONDecoder().decode(GlifiCorpusExtractiveSummaryAnalysis.self, from: encoded)
            == summary)
}

@Test("Il riassunto estrattivo si persiste dal testo, si riusa e risolve le frasi scelte")
func extractiveSummaryIsPersistedFromText() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiExtractiveSummary-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    let texts = [
        "La casa è bella. Il giardino è verde e grande. Sì.",
        "Il giardino della casa è verde.",
    ]
    var ids: [SourceRevisionID] = []
    for (index, text) in texts.enumerated() {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8), format: .plainText, sourceRevisionID: try revision(index + 1))
        _ = try await project.importText(imported)
        ids.append(imported.sourceRevisionID)
    }
    let result = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: GlifiSummaryBudget(unit: .sentences, limit: 2))
    let reused = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids.reversed(),
        budget: GlifiSummaryBudget(unit: .sentences, limit: 2))
    #expect(reused.artifactID == result.artifactID)
    #expect(reused.value == result.value)
    let summary = result.value
    #expect(summary.sourceRevisionIDs == ids.map(\.canonicalValue))
    #expect(summary.sentences.count == 4)
    #expect(summary.sentences.map(\.sentenceIndex) == [0, 1, 2, 0])
    #expect(summary.sentences.map(\.tokenCount) == [4, 6, 1, 6])
    #expect(Set(summary.sentences.map(\.rank)) == [1, 2, 3, 4])
    #expect(summary.selectedSentences.count == 2)
    #expect(summary.consumedBudget == 2)

    let resolved = try await engine.resolveSummarySentences(summary, in: project)
    #expect(resolved.map(\.sentence) == summary.selectedSentences)
    let combined = texts.joined(separator: "\n")
    for entry in resolved {
        #expect(!entry.text.isEmpty)
        #expect(combined.contains(entry.text))
    }

    // Budget e schema diversi sono nodi distinti; budget non valido rifiutato.
    let wider = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: GlifiSummaryBudget(unit: .sentences, limit: 4))
    #expect(wider.artifactID != result.artifactID)
    #expect(wider.value.selectedSentences.count == 4)
    #expect(wider.value.sentences.map(\.score) == summary.sentences.map(\.score))
    let stored: GlifiProjectDerivedResult<GlifiCorpusExtractiveSummaryAnalysis> =
        try await engine.storedDerivedResult(
            GlifiCorpusExtractiveSummaryAnalysis.self, artifactID: wider.artifactID, in: project)
    #expect(stored.value == wider.value)
    await #expect(throws: GlifiFailure.self) {
        _ = try await engine.analyzeExtractiveSummary(
            in: project, sourceRevisionIDs: ids,
            budget: GlifiSummaryBudget(unit: .sentences, limit: 0))
    }
    await #expect(throws: GlifiFailure.self) {
        _ = try await engine.analyzeExtractiveSummary(in: project, sourceRevisionIDs: [])
    }
}

@Test("CentroidCosine-v1 coincide con l'oracolo Python: punteggi, rank e selezioni")
func centroidCosineSummaryMatchesPython() throws {
    let documents = try oracleDocuments()
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let summary = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 2),
        scheme: scheme, method: .centroidCosine)
    // Oracolo: righe CENTROID_* di expected.txt.
    let expected = [
        0.914241630436781, 0, 0.746180682988278, 0.333113335182715, 0.63399246745524,
    ]
    let scores = summary.sentences.map(\.score)
    #expect(scores.count == expected.count)
    for (score, reference) in zip(scores, expected) {
        #expect(close(score, reference))
    }
    #expect(summary.methodIdentifier == "CentroidCosine-v1")
    #expect(summary.eligibilityPolicy == "eligibility.non-null-vector-v1")
    #expect(summary.sentences.map(\.rank) == [1, 5, 2, 4, 3])
    #expect(summary.sentences.map(\.isEligible) == [true, false, true, true, true])
    #expect(summary.sentences.map(\.isSelected) == [true, false, true, false, false])
    #expect(summary.consumedBudget == 2)
    let tokens = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .lexicalTokens, limit: 3),
        scheme: scheme, method: .centroidCosine)
    #expect(tokens.sentences.map(\.isSelected) == [true, false, false, false, false])
    #expect(tokens.consumedBudget == 3)
    // Stesse unità e intervalli della media TF-IDF: cambia solo il punteggio.
    let mean = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 2),
        scheme: scheme)
    #expect(mean.methodIdentifier == "SentenceTFIDFMean-v1")
    #expect(mean.sentences.map(\.range) == summary.sentences.map(\.range))
    #expect(mean.sentences.map(\.tokenCount) == summary.sentences.map(\.tokenCount))
}

@Test("CentroidCosine-v1: vettori nulli esclusi con diagnostica, payload senza isEligible")
func centroidCosineExcludesNullVectors() throws {
    // IDF-unsmoothed-v1 su un solo documento: ogni peso vale log(1/1) = 0, ogni vettore è nullo.
    let unsmoothed = GlifiTermWeightingScheme(
        termFrequency: .sublinear, inverseDocumentFrequency: .unsmoothed, normalization: .none)
    let single = [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [try sentence(0, ["a", "b"]), try sentence(1, []), try sentence(2, ["b"])]
        )
    ]
    let centroid = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: single, budget: .standard, scheme: unsmoothed, method: .centroidCosine)
    #expect(centroid.sentences.map(\.score) == [0, 0, 0])
    #expect(centroid.sentences.map(\.isEligible) == [false, false, false])
    #expect(centroid.sentences.map(\.isSelected) == [false, false, false])
    #expect(centroid.sentences.map(\.rank) == [1, 2, 3])
    #expect(centroid.consumedBudget == 0)
    // La media TF-IDF classifica le stesse frasi a zero ma le frasi con token restano eleggibili.
    let mean = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: single, budget: .standard, scheme: unsmoothed)
    #expect(mean.sentences.map(\.isEligible) == [true, false, true])
    #expect(mean.sentences.map(\.isSelected) == [true, false, true])

    // Due documenti: la frase identica al centroide ha coseno 1, la duplicata lo stesso rank+1.
    let documents = try oracleDocuments()
    let scored = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 5),
        scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: .centroidCosine)
    for sentence in scored.sentences where sentence.isEligible {
        #expect(sentence.score > 0 && sentence.score <= 1 + 1e-12)
    }
    #expect(scored.selectedSentences.count == 4)
    #expect(scored.consumedBudget == 4)

    // Payload persistito prima di `isEligible`: il flag deriva dai token lessicali.
    let encoded = try JSONEncoder().encode(scored)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    var sentences = object?["sentences"] as? [[String: Any]] ?? []
    #expect(sentences.count == 5)
    for index in sentences.indices {
        sentences[index].removeValue(forKey: "isEligible")
    }
    var legacy = object ?? [:]
    legacy["sentences"] = sentences
    let decoded = try JSONDecoder().decode(
        GlifiCorpusExtractiveSummaryAnalysis.self,
        from: JSONSerialization.data(withJSONObject: legacy))
    #expect(decoded.sentences.map(\.isEligible) == [true, false, true, true, true])
    #expect(decoded.sentences.map(\.isSelected) == scored.sentences.map(\.isSelected))
    let roundTrip = try JSONDecoder().decode(
        GlifiCorpusExtractiveSummaryAnalysis.self, from: encoded)
    #expect(roundTrip == scored)
}

@Test("Il metodo di punteggio è un parametro del descrittore: Artifact distinti, stesse frasi")
func centroidCosineSummaryIsPersistedAsDistinctArtifact() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiCentroidSummary-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    let texts = [
        "La casa è bella. Il giardino è verde e grande. Sì.",
        "Il giardino della casa è verde.",
    ]
    var ids: [SourceRevisionID] = []
    for (index, text) in texts.enumerated() {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8), format: .plainText, sourceRevisionID: try revision(index + 1))
        _ = try await project.importText(imported)
        ids.append(imported.sourceRevisionID)
    }
    let budget = GlifiSummaryBudget(unit: .sentences, limit: 2)
    let mean = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget)
    let centroid = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget, method: .centroidCosine)
    #expect(centroid.artifactID != mean.artifactID)
    #expect(centroid.value.methodIdentifier == "CentroidCosine-v1")
    #expect(centroid.value.sentences.map(\.range) == mean.value.sentences.map(\.range))
    #expect(centroid.value.sentences.map(\.isEligible) == [true, true, true, true])
    #expect(centroid.value.selectedSentences.count == 2)
    #expect(centroid.value.consumedBudget == 2)
    let reused = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids.reversed(), budget: budget, method: .centroidCosine)
    #expect(reused.artifactID == centroid.artifactID)
    #expect(reused.value == centroid.value)
    let stored: GlifiProjectDerivedResult<GlifiCorpusExtractiveSummaryAnalysis> =
        try await engine.storedDerivedResult(
            GlifiCorpusExtractiveSummaryAnalysis.self, artifactID: centroid.artifactID,
            in: project)
    #expect(stored.value == centroid.value)
    let resolved = try await engine.resolveSummarySentences(centroid.value, in: project)
    #expect(resolved.map(\.sentence) == centroid.value.selectedSentences)
    for entry in resolved {
        #expect(texts.joined(separator: "\n").contains(entry.text))
    }
}
