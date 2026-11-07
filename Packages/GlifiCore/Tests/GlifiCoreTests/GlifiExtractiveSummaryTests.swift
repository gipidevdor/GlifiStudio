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
    #expect(GlifiCorpusExtractiveSummaryAnalysis.methodIdentifier == "SentenceTFIDFMean-v1")
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
    // Oracle: CENTROID_* lines of expected.txt.
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
    // Same units and ranges as the TF-IDF mean: only the score changes.
    let mean = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 2),
        scheme: scheme)
    #expect(mean.methodIdentifier == "SentenceTFIDFMean-v1")
    #expect(mean.sentences.map(\.range) == summary.sentences.map(\.range))
    #expect(mean.sentences.map(\.tokenCount) == summary.sentences.map(\.tokenCount))
}

@Test("CentroidCosine-v1: vettori nulli esclusi con diagnostica, payload senza isEligible")
func centroidCosineExcludesNullVectors() throws {
    // IDF-unsmoothed-v1 on a single document: every weight is log(1/1) = 0, every vector is null.
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
    // The TF-IDF mean ranks the same sentences at zero, but sentences with tokens stay eligible.
    let mean = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: single, budget: .standard, scheme: unsmoothed)
    #expect(mean.sentences.map(\.isEligible) == [true, false, true])
    #expect(mean.sentences.map(\.isSelected) == [true, false, true])

    // Two documents: the sentence equal to the centroid has cosine 1, its duplicate the next rank.
    let documents = try oracleDocuments()
    let scored = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 5),
        scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: .centroidCosine)
    for sentence in scored.sentences where sentence.isEligible {
        #expect(sentence.score > 0 && sentence.score <= 1 + 1e-12)
    }
    #expect(scored.selectedSentences.count == 4)
    #expect(scored.consumedBudget == 4)

    // Payload persisted before `isEligible`: the flag derives from the lexical tokens.
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

@Test("MMR-v1 coincide con l'oracolo Python: ordine di selezione, λ agli estremi e soglia")
func mmrSummaryMatchesPython() throws {
    let documents = try oracleDocuments()
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let two = GlifiSummaryBudget(unit: .sentences, limit: 2)
    func summary(
        _ budget: GlifiSummaryBudget, lambda: Double?
    ) throws -> GlifiCorpusExtractiveSummaryAnalysis {
        try GlifiCorpusExtractiveSummaryAnalysis(
            documents: documents, budget: budget, scheme: scheme, method: .centroidCosine,
            redundancy: lambda.map { .maximalMarginalRelevance(lambda: $0) } ?? .none)
    }
    // Oracle: MMR_* lines of expected.txt; relevance and ranks are those of CentroidCosine-v1.
    let mmr = try summary(two, lambda: 0.5)
    #expect(mmr.redundancyPolicy == "MMR-v1")
    #expect(mmr.redundancyLambda == 0.5)
    #expect(mmr.similarityIdentifier == "similarity.sentence-vector-cosine-v1")
    #expect(mmr.sentences.map(\.rank) == [1, 5, 2, 4, 3])
    #expect(mmr.sentences.map(\.isSelected) == [true, false, false, true, false])
    #expect(mmr.sentences.map(\.selectionOrder) == [1, nil, nil, 2, nil])
    #expect(mmr.consumedBudget == 2)
    let three = try summary(GlifiSummaryBudget(unit: .sentences, limit: 3), lambda: 0.5)
    #expect(three.sentences.map(\.selectionOrder) == [1, nil, 3, 2, nil])
    let tokens = try summary(GlifiSummaryBudget(unit: .lexicalTokens, limit: 3), lambda: 0.5)
    #expect(tokens.sentences.map(\.selectionOrder) == [1, nil, nil, nil, nil])
    #expect(tokens.consumedBudget == 3)
    // λ = 0 rewards novelty only; λ = 1 reproduces the rank walk, including the selection order.
    #expect(try summary(two, lambda: 0).sentences.map(\.selectionOrder) == [1, nil, nil, 2, nil])
    let relevance = try summary(two, lambda: 1)
    let walk = try summary(two, lambda: nil)
    #expect(relevance.sentences.map(\.isSelected) == walk.sentences.map(\.isSelected))
    #expect(relevance.sentences.map(\.selectionOrder) == [1, nil, 2, nil, nil])
    #expect(walk.sentences.map(\.selectionOrder) == [1, nil, 2, nil, nil])
    #expect(walk.redundancyPolicy == "redundancy.none-v1")
    #expect(walk.redundancyLambda == nil)
    #expect(walk.similarityIdentifier == nil)
    #expect(walk.sentences.map(\.score) == mmr.sentences.map(\.score))
    // MMR_THRESHOLD_S2: just below the threshold the second pick is sentence 3, just above it 2.
    let threshold = 0.562024411171168
    #expect(
        try summary(two, lambda: threshold - 1e-6).sentences.map(\.selectionOrder)
            == [1, nil, nil, 2, nil])
    #expect(
        try summary(two, lambda: threshold + 1e-6).sentences.map(\.selectionOrder)
            == [1, nil, 2, nil, nil])
}

@Test("MMR-v1 penalizza i duplicati, rifiuta λ fuori da [0, 1], decodifica payload senza ordine")
func mmrPenalizesDuplicatesAndRejectsInvalidLambda() throws {
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let documents = [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [
                try sentence(0, ["a", "b"]), try sentence(1, ["a", "b"]),
                try sentence(2, ["c", "d"]),
            ]
        )
    ]
    let two = GlifiSummaryBudget(unit: .sentences, limit: 2)
    // Rank walk: both identical sentences enter; MMR replaces the duplicate (cosine 1).
    let walk = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: two, scheme: scheme)
    #expect(walk.sentences.map(\.isSelected) == [true, true, false])
    let mmr = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: two, scheme: scheme,
        redundancy: .maximalMarginalRelevance(lambda: 0.5))
    #expect(mmr.sentences.map(\.isSelected) == [true, false, true])
    #expect(mmr.sentences.map(\.selectionOrder) == [1, nil, 2])
    #expect(mmr.sentences.map(\.rank) == walk.sentences.map(\.rank))
    #expect(mmr.sentences.map(\.score) == walk.sentences.map(\.score))

    // The same token sequence in two documents has different weights, so its cosine is below 1
    // (MMR_INFO_CROSS_DOCUMENT_SIMILARITY): both copies may enter. Oracle: MMR_CROSS_ORDER_*.
    let cross = [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [
                try sentence(0, ["a", "b"]), try sentence(1, Array(repeating: "a", count: 99)),
            ]
        ),
        GlifiSummaryDocument(
            sourceRevisionID: try revision(2),
            sentences: [
                try sentence(0, ["a", "b"]), try sentence(1, Array(repeating: "b", count: 99)),
            ]
        ),
    ]

    // Bind the independent cosine oracle and MMR's decision boundary to this fixture.
    let crossWeights = try GlifiTermWeighting.weigh(
        rows: [[0: 100, 1: 1], [0: 1, 1: 100]], columnCount: 2, scheme: scheme)
    let crossVectors = crossWeights.map { [$0[0] ?? 0, $0[1] ?? 0] } + [[0, 1]]
    let crossDistances = try GlifiTextMatrixOperators.dissimilarities(
        crossVectors, metric: .cosine)
    let duplicateCosine = 0.345806761841798
    #expect(abs(1 - crossDistances[0][1] - duplicateCosine) < 1e-12)
    let centroid = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: cross, budget: two, scheme: scheme, method: .centroidCosine)
    let penaltyDifference = duplicateCosine - (1 - crossDistances[0][2])
    let crossThreshold =
        penaltyDifference
        / (centroid.sentences[2].score - centroid.sentences[3].score + penaltyDifference)
    let transitions: [(Double, [Int?])] = [
        (crossThreshold - 1e-8, [1, nil, nil, 2]),
        (crossThreshold + 1e-8, [1, nil, 2, nil]),
    ]
    for (lambda, expectedOrder) in transitions {
        let boundary = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: cross, budget: two, scheme: scheme, method: .centroidCosine,
            redundancy: .maximalMarginalRelevance(lambda: lambda))
        #expect(boundary.sentences.map(\.selectionOrder) == expectedOrder)
    }

    let three = GlifiSummaryBudget(unit: .sentences, limit: 3)
    let balanced = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: cross, budget: three, scheme: scheme,
        redundancy: .maximalMarginalRelevance(lambda: 0.5))
    #expect(balanced.sentences.map(\.selectionOrder) == [3, 1, nil, 2])
    let novelty = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: cross, budget: three, scheme: scheme,
        redundancy: .maximalMarginalRelevance(lambda: 0))
    #expect(novelty.sentences.map(\.selectionOrder) == [1, 3, nil, 2])

    for lambda in [-0.1, 1.1, Double.nan, Double.infinity] {
        #expect(!GlifiSummaryRedundancyPolicy.maximalMarginalRelevance(lambda: lambda).isValid)
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiCorpusExtractiveSummaryAnalysis(
                documents: documents, budget: two, scheme: scheme,
                redundancy: .maximalMarginalRelevance(lambda: lambda))
        }
    }

    // Payload persisted before `MMR-v1`: no selection order, no lambda, no similarity.
    let encoded = try JSONEncoder().encode(mmr)
    #expect(
        try JSONDecoder().decode(GlifiCorpusExtractiveSummaryAnalysis.self, from: encoded) == mmr)
    var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]
    var sentences = object["sentences"] as? [[String: Any]] ?? []
    for index in sentences.indices {
        sentences[index].removeValue(forKey: "selectionOrder")
    }
    object["sentences"] = sentences
    object.removeValue(forKey: "redundancyLambda")
    object.removeValue(forKey: "similarityIdentifier")
    object["redundancyPolicy"] = "redundancy.none-v1"
    let legacy = try JSONDecoder().decode(
        GlifiCorpusExtractiveSummaryAnalysis.self,
        from: JSONSerialization.data(withJSONObject: object))
    #expect(legacy.sentences.map(\.selectionOrder) == [nil, nil, nil])
    #expect(legacy.sentences.map(\.isSelected) == mmr.sentences.map(\.isSelected))
    #expect(legacy.redundancyLambda == nil)
    #expect(legacy.similarityIdentifier == nil)
    let walkEncoded = try JSONEncoder().encode(walk)
    let walkObject = try JSONSerialization.jsonObject(with: walkEncoded) as? [String: Any]
    #expect(walkObject?["redundancyLambda"] == nil)
    #expect(walkObject?["similarityIdentifier"] == nil)
}

@Test("La ridondanza è un parametro del descrittore: Artifact distinti, stessi punteggi")
func mmrSummaryIsPersistedAsDistinctArtifact() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiMMRSummary-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    let texts = [
        "La casa è bella. La casa è bella. Il giardino è verde e grande.",
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
    let walk = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget, method: .centroidCosine)
    let mmr = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget, method: .centroidCosine,
        redundancy: .maximalMarginalRelevance(lambda: 0.5))
    #expect(mmr.artifactID != walk.artifactID)
    #expect(mmr.value.redundancyPolicy == "MMR-v1")
    #expect(mmr.value.redundancyLambda == 0.5)
    #expect(mmr.value.sentences.map(\.score) == walk.value.sentences.map(\.score))
    #expect(mmr.value.sentences.map(\.rank) == walk.value.sentences.map(\.rank))
    // The duplicated first sentence enters the rank walk twice and the MMR summary once.
    #expect(walk.value.sentences.map(\.isSelected) == [true, true, false, false])
    #expect(mmr.value.sentences.map(\.isSelected) == [true, false, true, false])
    #expect(mmr.value.sentences.map(\.selectionOrder) == [1, nil, 2, nil])
    #expect(mmr.value.consumedBudget == 2)
    let reused = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids.reversed(), budget: budget, method: .centroidCosine,
        redundancy: .maximalMarginalRelevance(lambda: 0.5))
    #expect(reused.artifactID == mmr.artifactID)
    #expect(reused.value == mmr.value)
    let other = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget, method: .centroidCosine,
        redundancy: .maximalMarginalRelevance(lambda: 0.7))
    #expect(other.artifactID != mmr.artifactID)
    let stored: GlifiProjectDerivedResult<GlifiCorpusExtractiveSummaryAnalysis> =
        try await engine.storedDerivedResult(
            GlifiCorpusExtractiveSummaryAnalysis.self, artifactID: mmr.artifactID, in: project)
    #expect(stored.value == mmr.value)
    let resolved = try await engine.resolveSummarySentences(mmr.value, in: project)
    #expect(resolved.map(\.sentence) == mmr.value.selectedSentences)
    for entry in resolved {
        #expect(texts.joined(separator: "\n").contains(entry.text))
    }
    await #expect(throws: GlifiFailure.self) {
        _ = try await engine.analyzeExtractiveSummary(
            in: project, sourceRevisionIDs: ids, budget: budget,
            redundancy: .maximalMarginalRelevance(lambda: 1.5))
    }
}

@Test("LexRankSentence-v1 coincide con l'oracolo Python: centralità, rank, selezioni e MMR")
func lexRankSummaryMatchesPython() throws {
    let documents = try oracleDocuments()
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let summary = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 2),
        scheme: scheme, method: .lexRank)
    // Oracle: LEXRANK_* lines of expected.txt.
    let expected = [
        0.301767474209051, 0, 0.248867874201183, 0.211108705743267, 0.238255945846499,
    ]
    let scores = summary.sentences.map(\.score)
    #expect(scores.count == expected.count)
    for (score, reference) in zip(scores, expected) {
        #expect(close(score, reference))
    }
    #expect(close(scores.reduce(0, +), 1))
    #expect(summary.methodIdentifier == "LexRankSentence-v1")
    #expect(summary.eligibilityPolicy == "eligibility.non-null-vector-v1")
    #expect(summary.sentences.map(\.rank) == [1, 5, 2, 4, 3])
    #expect(summary.sentences.map(\.isEligible) == [true, false, true, true, true])
    #expect(summary.sentences.map(\.isSelected) == [true, false, true, false, false])
    #expect(summary.sentences.map(\.selectionOrder) == [1, nil, 2, nil, nil])
    let tokens = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .lexicalTokens, limit: 3),
        scheme: scheme, method: .lexRank)
    #expect(tokens.sentences.map(\.isSelected) == [true, false, false, false, false])
    #expect(tokens.consumedBudget == 3)
    let mmr = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 3),
        scheme: scheme, method: .lexRank, redundancy: .maximalMarginalRelevance(lambda: 0.5))
    #expect(mmr.sentences.map(\.selectionOrder) == [1, nil, 3, 2, nil])
    #expect(mmr.sentences.map(\.score) == summary.sentences.map(\.score))
}

@Test("LexRankSentence-v1: vettori nulli esclusi, simmetria, limite del grafo, convergenza")
func lexRankBoundsAndFailsClosed() throws {
    // IDF-unsmoothed-v1 on a single document: every vector is null, the graph is empty.
    let unsmoothed = GlifiTermWeightingScheme(
        termFrequency: .sublinear, inverseDocumentFrequency: .unsmoothed, normalization: .none)
    let single = [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [try sentence(0, ["a", "b"]), try sentence(1, []), try sentence(2, ["b"])]
        )
    ]
    let empty = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: single, budget: .standard, scheme: unsmoothed, method: .lexRank)
    #expect(empty.sentences.map(\.score) == [0, 0, 0])
    #expect(empty.sentences.map(\.isEligible) == [false, false, false])
    #expect(empty.consumedBudget == 0)

    // Duplicate sentences share the centrality (0.336511 against 0.326979 for the bridging
    // sentence); the tie is broken by source position.
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    let duplicates = [
        GlifiSummaryDocument(
            sourceRevisionID: try revision(1),
            sentences: [
                try sentence(0, ["x"]), try sentence(1, ["x", "y"]), try sentence(2, ["x"]),
            ]
        )
    ]
    let tied = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: duplicates, budget: GlifiSummaryBudget(unit: .sentences, limit: 1),
        scheme: scheme, method: .lexRank)
    #expect(tied.sentences[0].score == tied.sentences[2].score)
    #expect(tied.sentences[0].score > tied.sentences[1].score)
    #expect(tied.sentences.map(\.rank) == [1, 3, 2])
    #expect(tied.sentences.map(\.isSelected) == [true, false, false])

    // At the node limit the uniform graph is accepted; one node more fails closed.
    let limit = GlifiCorpusExtractiveSummaryAnalysis.lexRankMaximumNodes
    func uniform(_ count: Int) throws -> [GlifiSummaryDocument] {
        [
            GlifiSummaryDocument(
                sourceRevisionID: try revision(1),
                sentences: try (0..<count).map { try sentence($0, ["a"]) })
        ]
    }
    let bounded = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: try uniform(limit), budget: .standard, scheme: scheme, method: .lexRank)
    #expect(bounded.sentences.allSatisfy { close($0.score, 1 / Double(limit)) })
    #expect(bounded.sentences.prefix(3).map(\.rank) == [1, 2, 3])
    let tooLarge = #expect(throws: GlifiFailure.self) {
        _ = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: try uniform(limit + 1), budget: .standard, scheme: scheme,
            method: .lexRank)
    }
    #expect(tooLarge?.code == "summary.graph-limit-exceeded")
    #expect(tooLarge?.category == .insufficientResources)

    // A non-stochastic matrix diverges: the iteration bound fails closed.
    #expect(try GlifiCorpusExtractiveSummaryAnalysis.lexRankStationary([]) == [])
    #expect(try GlifiCorpusExtractiveSummaryAnalysis.lexRankStationary([[1]]) == [1])
    let diverging = #expect(throws: GlifiFailure.self) {
        _ = try GlifiCorpusExtractiveSummaryAnalysis.lexRankStationary([[2]])
    }
    #expect(diverging?.code == "summary.centrality-not-converged")
    #expect(diverging?.category == .invariantViolation)
}

@Test("LexRankSentence-v1 si persiste come Artifact distinto e si riusa")
func lexRankSummaryIsPersistedAsDistinctArtifact() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiLexRankSummary-\(UUID().uuidString)", directoryHint: .isDirectory)
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
    let centroid = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget, method: .centroidCosine)
    let lexRank = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, budget: budget, method: .lexRank)
    #expect(lexRank.artifactID != centroid.artifactID)
    #expect(lexRank.value.methodIdentifier == "LexRankSentence-v1")
    #expect(lexRank.value.sentences.map(\.range) == centroid.value.sentences.map(\.range))
    #expect(lexRank.value.sentences.map(\.isEligible) == centroid.value.sentences.map(\.isEligible))
    #expect(close(lexRank.value.sentences.map(\.score).reduce(0, +), 1))
    #expect(lexRank.value.selectedSentences.count == 2)
    let reused = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids.reversed(), budget: budget, method: .lexRank)
    #expect(reused.artifactID == lexRank.artifactID)
    #expect(reused.value == lexRank.value)
    let stored: GlifiProjectDerivedResult<GlifiCorpusExtractiveSummaryAnalysis> =
        try await engine.storedDerivedResult(
            GlifiCorpusExtractiveSummaryAnalysis.self, artifactID: lexRank.artifactID,
            in: project)
    #expect(stored.value == lexRank.value)
}
