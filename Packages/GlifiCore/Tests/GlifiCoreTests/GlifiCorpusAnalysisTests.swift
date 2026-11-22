// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Il profilo corpus riproduce conteggi, diversità, dispersione, n-grammi e matrice")
func corpusAnalysisProducesSpecifiedValues() throws {
    let sourceOne = try importedText(
        "casa casa mare",
        revision: "00000000-0000-0000-0000-000000000001"
    )
    let sourceTwo = try importedText(
        "casa città",
        revision: "00000000-0000-0000-0000-000000000002"
    )
    let options = try analysisOptions(windowSize: 2, ngramSizes: [2])

    let analysis = try GlifiCorpusAnalyzer().analyze(
        [sourceTwo, sourceOne],
        options: options
    )
    let repeated = try GlifiCorpusAnalyzer().analyze(
        [sourceOne, sourceTwo],
        options: options
    )

    #expect(analysis == repeated)
    #expect(analysis.analysisIdentifier == "corpus-profile-it-v1")
    #expect(analysis.corpusDigest.hasPrefix("sha256:"))
    #expect(analysis.countDeterminismClass == "D0")
    #expect(analysis.floatingPointDeterminismClass == "D1")
    #expect(analysis.numericPolicyIdentifier == "IEEE-754-binary64-ordered-reduction-v1")
    #expect(analysis.referenceAbsoluteTolerance == 1e-12)
    #expect(analysis.characterUnitIdentifier == "unicode-extended-grapheme-cluster-v1")
    #expect(analysis.tokenizationContractIdentifier == "it-token-v1")
    #expect(analysis.normalizationIdentifier == "nfc-lowercase-it-v1")
    #expect(analysis.documentCount == 2)
    #expect(analysis.characterCount == 24)
    #expect(analysis.sentenceCount == 2)
    #expect(analysis.lexicalTokenCount == 5)
    #expect(analysis.typeCount == 3)

    #expect(analysis.terms.map(\.term) == ["casa", "città", "mare"])
    let casa = try #require(analysis.terms.first)
    #expect(casa.frequency == 3)
    #expect(casa.relativeFrequency == 0.6)
    #expect(casa.documentFrequency == 2)
    #expect(casa.range == 2)
    #expect(abs(casa.griesDP - (1.0 / 15.0)) < 1e-12)
    #expect(abs(analysis.terms[1].griesDP - 0.6) < 1e-12)
    #expect(abs(analysis.terms[2].griesDP - 0.4) < 1e-12)

    #expect(analysis.diversity.ttrIdentifier == "TTR-v1")
    #expect(analysis.diversity.msttrIdentifier == "MSTTR-v1")
    #expect(analysis.diversity.mattrIdentifier == "MATTR-v1")
    #expect(analysis.diversity.ttr == 0.6)
    #expect(analysis.diversity.msttr == 0.75)
    #expect(analysis.diversity.mattr == 0.875)
    #expect(
        analysis.ngrams
            == [
                GlifiWordNGram(values: ["casa", "casa"], count: 1),
                GlifiWordNGram(values: ["casa", "città"], count: 1),
                GlifiWordNGram(values: ["casa", "mare"], count: 1),
            ]
    )

    #expect(analysis.matrix.unitKind == "sourceRevision")
    #expect(analysis.matrix.tfIdentifier == "TF-raw-v1")
    #expect(analysis.matrix.idfIdentifier == "IDF-smooth-v1")
    #expect(analysis.matrix.tfidfIdentifier == "TFIDF-v1")
    #expect(analysis.matrix.terms == ["casa", "città", "mare"])
    #expect(analysis.matrix.cells.map(\.count) == [2, 1, 1, 1])
    #expect(analysis.matrix.cells.map(\.rowIndex) == [0, 0, 1, 1])
    #expect(analysis.matrix.cells.map(\.columnIndex) == [0, 2, 0, 1])
    #expect(analysis.matrix.cells[0].tfidfSmooth == 2)
    #expect(abs(analysis.matrix.cells[1].tfidfSmooth - (log(1.5) + 1)) < 1e-12)
}

@Test("Il profilo di una fonte vuota dichiara le metriche lessicali non definite")
func emptyDocumentAnalysisPreservesUndefinedDiversity() throws {
    let analysis = try GlifiCorpusAnalyzer().analyze(
        [try importedText("", revision: "00000000-0000-0000-0000-000000000001")],
        options: try analysisOptions(windowSize: 2, ngramSizes: [2])
    )

    #expect(analysis.documentCount == 1)
    #expect(analysis.characterCount == 0)
    #expect(analysis.sentenceCount == 0)
    #expect(analysis.lexicalTokenCount == 0)
    #expect(analysis.typeCount == 0)
    #expect(analysis.terms.isEmpty)
    #expect(analysis.diversity.ttr == nil)
    #expect(analysis.diversity.msttr == nil)
    #expect(analysis.diversity.mattr == nil)
    #expect(analysis.matrix.cells.isEmpty)
}

@Test("I limiti corpus falliscono prima di materializzare risultati non bounded")
func corpusAnalysisEnforcesBounds() throws {
    let one = try importedText(
        "casa casa mare",
        revision: "00000000-0000-0000-0000-000000000001"
    )
    let two = try importedText(
        "casa città",
        revision: "00000000-0000-0000-0000-000000000002"
    )

    try expectFailure(code: "analysis.empty-selection") {
        _ = try GlifiCorpusAnalyzer().analyze([])
    }
    try expectFailure(code: "analysis.document-limit-exceeded") {
        _ = try GlifiCorpusAnalyzer().analyze(
            [one, two],
            options: try analysisOptions(maximumDocumentCount: 1)
        )
    }
    try expectFailure(code: "analysis.byte-limit-exceeded") {
        _ = try GlifiCorpusAnalyzer().analyze(
            [one],
            options: try analysisOptions(maximumSourceByteCount: one.bytes.count - 1)
        )
    }
    try expectFailure(code: "analysis.vocabulary-limit-exceeded") {
        _ = try GlifiCorpusAnalyzer().analyze(
            [one],
            options: try analysisOptions(maximumVocabularySize: 1)
        )
    }
    try expectFailure(code: "analysis.ngram-limit-exceeded") {
        _ = try GlifiCorpusAnalyzer().analyze(
            [one, two],
            options: try analysisOptions(
                windowSize: 2,
                ngramSizes: [2],
                maximumDistinctNGramCount: 2
            )
        )
    }
    try expectFailure(code: "analysis.matrix-limit-exceeded") {
        _ = try GlifiCorpusAnalyzer().analyze(
            [one, two],
            options: try analysisOptions(maximumNonZeroCellCount: 3)
        )
    }
    try expectFailure(code: "analysis.invalid-options") {
        _ = try GlifiCorpusAnalysisOptions(
            diversityWindowSize: 0,
            ngramSizes: [2, 2],
            maximumDocumentCount: -1,
            maximumSourceByteCount: 0,
            maximumVocabularySize: 0,
            maximumDistinctNGramCount: 0,
            maximumNonZeroCellCount: 0
        )
    }
}

private func importedText(_ text: String, revision: String) throws -> GlifiImportedText {
    try GlifiTextImporter().importText(
        from: Data(text.utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(UUID(uuidString: revision))
        )
    )
}

private func analysisOptions(
    windowSize: Int = 100,
    ngramSizes: [Int] = [2, 3],
    maximumDocumentCount: Int = 1_000,
    maximumSourceByteCount: Int = 256 * 1_024 * 1_024,
    maximumVocabularySize: Int = 100_000,
    maximumDistinctNGramCount: Int = 100_000,
    maximumNonZeroCellCount: Int = 500_000
) throws -> GlifiCorpusAnalysisOptions {
    try GlifiCorpusAnalysisOptions(
        diversityWindowSize: windowSize,
        ngramSizes: ngramSizes,
        maximumDocumentCount: maximumDocumentCount,
        maximumSourceByteCount: maximumSourceByteCount,
        maximumVocabularySize: maximumVocabularySize,
        maximumDistinctNGramCount: maximumDistinctNGramCount,
        maximumNonZeroCellCount: maximumNonZeroCellCount
    )
}

private func expectFailure(
    code: String,
    _ operation: () throws -> Void
) throws {
    do {
        try operation()
        Issue.record("Era attesa la failure \(code)")
    } catch let failure as GlifiFailure {
        #expect(failure.code == code)
        #expect(failure.operation == .analyze)
        #expect(failure.retainedState == .lastCommittedGeneration)
    }
}
