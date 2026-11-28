// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiCorpusPreparationTests {
    @Test("Un composto malformato non elimina silenziosamente tag grammaticali")
    func invalidExpressionsAndUnknownCompositeTagsFailClosed() throws {
        #expect(throws: GlifiFailure.self) {
            try GlifiCorpusPreparation(compounds: ["città, metropolitana"]).validate()
        }
        let imported = try GlifiTextImporter().importText(
            from: Data("città metropolitana".utf8), format: .plainText)
        let range = try GlifiUTF8Range(start: 0, end: imported.text.utf8.count)
        let tokens = GlifiTokenization(
            contractIdentifier: "explicit-annotation-fixture", languageConfiguration: .italian,
            sourceUTF8Length: imported.text.utf8.count,
            tokens: [.init(range: range, kind: .word, analysisForm: "città metropolitana")],
            sentences: [.init(range: range)], availableQueryFields: [.partOfSpeech])
        let request = GlifiQueryAST(
            root: .term(field: .partOfSpeech, value: "Noun", matchMode: .exact))
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiQueryEvaluator().evaluate(request, in: imported, tokenization: tokens)
        }
        let surface = GlifiQueryAST(
            root: .term(field: .form, value: "città metropolitana", matchMode: .exact))
        #expect(
            try GlifiQueryEvaluator().evaluate(surface, in: imported, tokenization: tokens)
                .matchedScope)
    }

    @Test("La preparazione conserva i byte delle fonti e le coordinate dei composti")
    func expressionsRetainExactSourceRanges() throws {
        let source = "La città di Roma è grande. La città, di Roma cambia."
        let preparation = GlifiCorpusPreparation(
            stopwords: ["la", "di"], includedTerms: ["città di roma"],
            excludedTerms: ["grande"], compounds: ["città di Roma"])
        let document = try preparation.prepare(text: source, id: "source")
        #expect(document.text == source)
        #expect(document.tokens.map(\.base).filter { $0 == "città di roma" }.count == 1)
        #expect(!document.tokens.contains { ["la", "di", "grande"].contains($0.base) })
        let compound = try #require(document.tokens.first { $0.base == "città di roma" })
        #expect(compound.range.text(in: source) == "città di Roma")
        #expect(compound.surface == "città di Roma")
        #expect(document.linguisticContract.contains(try preparation.digest()))
    }

    @Test("Il composto non attraversa frase o paragrafo e prevale il più lungo")
    func longestObservedExpressionDoesNotCrossBoundaries() throws {
        let preparation = GlifiCorpusPreparation(compounds: ["nuova città", "nuova città italiana"])
        let document = try preparation.prepare(
            text: "Nuova città italiana. Nuova. Città italiana. Nuova\n\ncittà.", id: "source")
        #expect(document.tokens.first?.base == "nuova città italiana")
        #expect(document.tokens.filter { $0.base == "nuova città" }.isEmpty)
    }

    @Test("L'inclusione esplicita conserva una stopword osservata senza inventare termini")
    func explicitInclusionsHaveDeclaredPrecedence() throws {
        let config = GlifiCorpusPreparation(
            stopwords: ["città", "di"], includedTerms: ["città", "inesistente"])
        let document = try config.prepare(text: "Città di Roma", id: "source")
        #expect(document.tokens.map(\.base) == ["città", "roma"])
        #expect(!document.tokens.contains { $0.base == "inesistente" })
        #expect(throws: GlifiFailure.self) {
            try GlifiCorpusPreparation(includedTerms: ["Città"], excludedTerms: ["città"])
                .validate()
        }
    }

    @Test("Identità canonica delle liste e invalidazione semantica della configurazione")
    func configurationIdentityIsCanonical() throws {
        let first = GlifiCorpusPreparation(stopwords: ["città", "LA", "la"])
        let second = GlifiCorpusPreparation(stopwords: ["la", "citta\u{0300}"])
        #expect(try first.digest() == second.digest())
        #expect(try first.digest() != GlifiCorpusPreparation(stopwords: ["la"]).digest())
        let identity = try GlifiCorpusPreparation().prepare(text: "Città, Roma!", id: "source")
        #expect(identity.linguisticContract == "it-token-v1.normalized-surface")
        #expect(identity.tokens.map(\.base) == ["città", "roma"])
    }

    @Test("Lo stemming italiano è una scelta esplicita e conserva gli intervalli UTF-8")
    func stemmingRetainsObservedSurface() throws {
        let source = "I ragazzi mangiano."
        let document = try GlifiCorpusPreparation(base: .italianSnowballStem)
            .prepare(text: source, id: "source")
        let token = try #require(document.tokens.first { $0.surface == "ragazzi" })
        #expect(token.base == "ragazz")
        #expect(token.range.text(in: source) == "ragazzi")
    }

    @Test("La cancellazione precede tokenizzazione e pubblicazione di output")
    func cancellationPropagates() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try GlifiCorpusPreparation().prepare(text: "Città di Roma", id: "source")
        }
        await #expect(throws: CancellationError.self) { _ = try await task.value }
    }
}
