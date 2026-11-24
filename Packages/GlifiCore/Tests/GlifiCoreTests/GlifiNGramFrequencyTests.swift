// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracolo: Tests/Oracles/R/ngrams.R (righe NGRAM_* di expected.txt).
private func sequences() throws -> [(SourceRevisionID, [String])] {
    let documents = [
        ["la", "casa", "è", "bella", "la", "casa"], ["una", "casa", "bella"],
        ["la", "città", "è", "grande"],
    ]
    return try documents.enumerated().map { index, forms in
        (
            try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index + 1)"),
            forms
        )
    }
}

private func row(
    _ analysis: GlifiCorpusNGramFrequencyAnalysis, _ components: [String]
) -> GlifiNGramFrequencyRow? {
    analysis.rows.first { $0.components == components }
}

@Test("N-grammi di caratteri con marcatori e di parole coincidono con i conteggi di R")
func ngramCountsMatchR() throws {
    let characters = try GlifiCorpusNGramFrequencyAnalysis(
        sequences: try sequences(), unit: .character(n: 3, padded: true), filter: .none,
        maximumRowCount: 1_000)
    #expect(characters.denominator == 44)
    #expect(characters.unitIdentifier == "CharNGram-graphemes-padded-v1")
    for (gram, count, df) in [("_ca", 3, 2), ("cas", 3, 2), ("asa", 3, 2), ("sa_", 3, 2)] {
        #expect(row(characters, [gram])?.count == count)
        #expect(row(characters, [gram])?.documentFrequency == df)
        #expect(abs((row(characters, [gram])?.relativeFrequency ?? 0) - 0.0681818181818182) < 1e-15)
    }
    #expect(row(characters, ["_è_"])?.count == 2)
    #expect(abs((row(characters, ["_è_"])?.relativeFrequency ?? 0) - 0.0454545454545455) < 1e-15)
    // Nessun n-gramma di caratteri attraversa il confine fra forme.
    #expect(row(characters, ["ll"]) == nil)
    #expect(characters.rows.allSatisfy { !$0.components[0].contains(" ") })

    let words = try GlifiCorpusNGramFrequencyAnalysis(
        sequences: try sequences(), unit: .word(n: 2), filter: .none, maximumRowCount: 1_000)
    #expect(words.denominator == 10)
    #expect(row(words, ["la", "casa"])?.count == 2)
    #expect(row(words, ["la", "casa"])?.documentFrequency == 1)
    #expect(abs((row(words, ["la", "casa"])?.relativeFrequency ?? 0) - 0.2) < 1e-15)
    #expect(row(words, ["casa", "bella"])?.count == 1)
    #expect(abs((row(words, ["casa", "bella"])?.relativeFrequency ?? 0) - 0.1) < 1e-15)
    #expect(row(words, ["una", "casa"])?.count == 1)
    #expect(row(words, ["è", "bella"])?.count == 1)
    #expect(words.rows.map(\.count) == words.rows.map(\.count).sorted(by: >))
}

@Test("Stopword e soglie si applicano dopo il conteggio con esclusioni attribuite")
func ngramFiltersMatchR() throws {
    let stopwordFilter = GlifiTermFilter(
        stopwords: ["LA", "è", "la"], minimumLength: 1, minimumCount: 1,
        minimumDocumentFrequency: 1, maximumDocumentProportion: 1)
    #expect(stopwordFilter.stopwords == ["la", "è"])
    let bigrams = try GlifiCorpusNGramFrequencyAnalysis(
        sequences: try sequences(), unit: .word(n: 2), filter: stopwordFilter,
        maximumRowCount: 1_000)
    #expect(bigrams.distinctUnitCount == 9)
    #expect(bigrams.exclusions.stopwords == 7)
    #expect(bigrams.rows.count == 2)
    // Il denominatore resta quello prima dei filtri e nessuna adiacenza nuova è creata.
    #expect(bigrams.denominator == 10)
    #expect(row(bigrams, ["casa", "bella"]) != nil)
    #expect(row(bigrams, ["casa", "casa"]) == nil)

    let forms = try GlifiCorpusNGramFrequencyAnalysis(
        sequences: try sequences(),
        unit: .form,
        filter: GlifiTermFilter(
            stopwords: [], minimumLength: 4, minimumCount: 2, minimumDocumentFrequency: 1,
            maximumDocumentProportion: 0.6),
        maximumRowCount: 1_000)
    #expect(forms.distinctUnitCount == 7)
    #expect(forms.exclusions.minimumLength == 3)
    #expect(forms.exclusions.minimumCount == 2)
    #expect(forms.exclusions.maximumDocumentProportion == 2)
    #expect(forms.rows.isEmpty)

    let truncated = try GlifiCorpusNGramFrequencyAnalysis(
        sequences: try sequences(), unit: .form, filter: .none, maximumRowCount: 2)
    #expect(truncated.isTruncated)
    #expect(truncated.rows.map(\.components) == [["casa"], ["la"]])
    for invalid in [
        GlifiTermFilter(
            stopwords: [], minimumLength: 0, minimumCount: 1, minimumDocumentFrequency: 1,
            maximumDocumentProportion: 1),
        GlifiTermFilter(
            stopwords: [], minimumLength: 1, minimumCount: 1, minimumDocumentFrequency: 1,
            maximumDocumentProportion: 0),
    ] {
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiCorpusNGramFrequencyAnalysis(
                sequences: try sequences(), unit: .form, filter: invalid, maximumRowCount: 10)
        }
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiCorpusNGramFrequencyAnalysis(
            sequences: try sequences(), unit: .character(n: 11, padded: false), filter: .none,
            maximumRowCount: 10)
    }
}

@Test("Le frequenze filtrate si persistono dal testo con la normalizzazione del profilo")
func ngramFrequenciesArePersistedFromText() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiNGrams-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    var ids: [SourceRevisionID] = []
    for (index, text) in ["La casa è bella; la Casa!", "Una casa bella.", "La città è grande."]
        .enumerated()
    {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index + 1)")
        )
        _ = try await project.importText(imported)
        ids.append(imported.sourceRevisionID)
    }
    let result = try await engine.analyzeNGramFrequencies(
        in: project, sourceRevisionIDs: ids, unit: .character(n: 3, padded: true))
    let reused = try await engine.analyzeNGramFrequencies(
        in: project, sourceRevisionIDs: ids, unit: .character(n: 3, padded: true))
    #expect(reused.artifactID == result.artifactID)
    #expect(result.value.denominator == 44)
    #expect(row(result.value, ["cas"])?.count == 3)
    let other = try await engine.analyzeNGramFrequencies(
        in: project, sourceRevisionIDs: ids, unit: .character(n: 3, padded: false))
    #expect(other.artifactID != result.artifactID)
}
