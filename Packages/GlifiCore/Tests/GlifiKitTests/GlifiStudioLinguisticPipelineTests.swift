// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("Le opzioni linguistiche risolvono i default e rifiutano chiavi ignote, null e basi ignote")
func studioLinguisticOptionsRejectAmbiguousInput() throws {
    let decoder = JSONDecoder()
    #expect(try decoder.decode(GlifiStudioLinguisticOptions.self, from: Data("{}".utf8)) == .init())
    for json in [
        "{\"extra\":true}", "{\"base\":null}", "{\"languageTag\":null}",
        "{\"includePartOfSpeech\":null}", "{\"base\":\"invented\"}",
    ] {
        #expect(throws: (any Error).self) {
            try decoder.decode(GlifiStudioLinguisticOptions.self, from: Data(json.utf8))
        }
    }
    let stem = GlifiStudioLinguisticOptions(base: .italianSnowballStem, includePartOfSpeech: true)
    #expect(
        try decoder.decode(GlifiStudioLinguisticOptions.self, from: JSONEncoder().encode(stem))
            == stem)
    #expect(stem.methodIdentifier != GlifiStudioLinguisticOptions().methodIdentifier)
    #expect(
        stem.methodIdentifier
            != GlifiStudioLinguisticOptions(base: .italianSnowballStem).methodIdentifier)
}

@Test("La facciata conserva offset UTF-8, null espliciti e provenienza senza tipi Core")
func studioLinguisticFacadePreservesOffsetsAndNullMetadata() async throws {
    let text = "Citta\u{0300}, città e 👩‍🔬. L'acqua è qui."
    let value = try await GlifiStudioLinguisticPipeline.annotate(text)
    #expect(value.text == text)
    #expect(value.methodIdentifier == GlifiStudioLinguisticOptions().methodIdentifier)
    for token in value.tokens {
        let bytes = Array(text.utf8)
        #expect(
            String(decoding: bytes[token.startUTF8..<token.endUTF8], as: UTF8.self) == token.surface
        )
        #expect(token.lemmaState == .notRequested && token.partOfSpeechState == .notRequested)
    }
    let data = try JSONEncoder().encode(value)
    #expect(try JSONDecoder().decode(GlifiStudioLinguisticAnnotation.self, from: data) == value)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let provenance = try #require(object["provenance"] as? [String: Any])
    #expect(provenance["modelVersion"] is NSNull)
    let tokens = try #require(object["tokens"] as? [[String: Any]])
    #expect(tokens.allSatisfy { $0["lemma"] is NSNull && $0["partOfSpeech"] is NSNull })
}

@Test("Codifica annotata mantiene il default e usa gli stem senza perdere evidenza o provenienza")
func studioAnnotatedCodingPreservesDefaultAndStemEvidence() async throws {
    let units = [
        GlifiStudioAutomaticCodingUnit(id: "one", text: "casa città"),
        GlifiStudioAutomaticCodingUnit(id: "two", text: "mangiando mele"),
    ]
    let rules = "*Casa\ncasa"
    let previous = try await GlifiStudioTextAnalytics.code(units, rules: rules)
    let current = try await GlifiStudioLinguisticPipeline.codeAnnotated(units, rules: rules)
    #expect(current.matrix == previous)
    #expect(current.provenanceByUnit.count == units.count)
    #expect(
        current.provenanceByUnit.allSatisfy {
            $0.codingContractIdentifier == "it-token-v1.normalized-surface"
        })
    let stem = try await GlifiStudioLinguisticPipeline.codeAnnotated(
        units, rules: "*Mangiare\nmang", options: .init(base: .italianSnowballStem))
    #expect(stem.matrix.values == [[0], [1]])
    #expect(stem.matrix.evidence[1][0].first?.start == 0)
    #expect(stem.matrix.evidence[1][0].first?.end == 9)
    #expect(stem.provenanceByUnit.allSatisfy { $0.stemmingIdentifier == "Snowball-Italian-3.1.0" })
    #expect(stem.methodIdentifier.contains("KH-coding-compatible-v2"))
}

@Test("Le regole ricevono lemma e POS Apple effettivi mantenendo gli intervalli originali")
func studioAnnotatedCodingUsesInstalledApplePredictions() async throws {
    let available = try await GlifiStudioLinguisticPipeline.availability()
    guard available.hasLemma && available.hasPartOfSpeech else { return }
    let text = "Le ragazze mangiavano mele."
    let options = GlifiStudioLinguisticOptions(base: .appleLemma, includePartOfSpeech: true)
    let annotation = try await GlifiStudioLinguisticPipeline.annotate(text, options: options)
    let token = try #require(annotation.tokens.first { $0.lemma != nil && $0.partOfSpeech != nil })
    let lemma = try #require(token.lemma)
    let pos = try #require(token.partOfSpeech)
    let result = try await GlifiStudioLinguisticPipeline.codeAnnotated(
        [.init(id: "source", text: text)], rules: "*Observed\n\(lemma)-->\(pos)", options: options)
    #expect(result.matrix.values == [[1]])
    #expect(
        result.matrix.evidence[0][0].contains {
            $0.start == token.startUTF8 && $0.end == token.endUTF8
        })
    #expect(result.provenanceByUnit[0].backendIdentifier == "com.apple.NaturalLanguage.NLTagger")
    #expect(result.provenanceByUnit[0].modelVersion == nil)
}

@Test(
    "La pipeline Kit conserva errori tipizzati, limiti e cancellazione senza dati nei diagnostici")
func studioLinguisticPipelinePreservesFailuresAndCancellation() async throws {
    do {
        _ = try await GlifiStudioLinguisticPipeline.annotate(
            "private-canary", options: .init(languageTag: "fr"))
        Issue.record("An unsupported language was accepted")
    } catch let failure {
        #expect(failure.category == "invalidInput")
        #expect(failure.retainedState == "unchanged")
        #expect(!String(describing: failure).contains("private-canary"))
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioLinguisticPipeline.annotate("ragazze")
    }
    do {
        _ = try await task.value
        Issue.record("Cancellation was ignored")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
    }
    await #expect(throws: GlifiStudioFailure.self) {
        try await GlifiStudioLinguisticPipeline.codeAnnotated(
            [.init(id: "source", text: String(repeating: "a", count: 1_048_577))], rules: "*A\na")
    }
}
