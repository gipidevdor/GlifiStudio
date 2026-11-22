// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("LR e FLR token/type coincidono con l'esempio originale e radici Decimal indipendenti")
func termExtractionMatchesOriginalPaperAndDecimalOracle() throws {
    let candidates = try termExtractionPaperCandidates()
    let expected = [
        [
            2.9129506302439405, 3.1301691601465746, 2.632148025904985,
            2.632148025904985, 2.5697965868506506, 2.632148025904985, 4.898979485566356,
        ],
        [
            2.213363839400643, 2.213363839400643, 2.213363839400643,
            2.213363839400643, 1.9063685859938732, 2.213363839400643, 3.4641016151377544,
        ],
    ]
    let trigramFLR = [14.696938456699069, 10.392304845413264]
    for (index, mode) in [GlifiTermAdjacencyMode.token, .type].enumerated() {
        let result = try GlifiTermExtraction.score(
            candidates, adjacencyMode: mode, preprocessingIdentifier: "paper-example-v1")
        #expect(result.independentOccurrenceCount == 10)
        let byTerm = Dictionary(uniqueKeysWithValues: result.terms.map { ($0.components, $0) })
        for (offset, candidate) in candidates.enumerated() {
            let term = try #require(byTerm[candidate.components])
            #expect(term.frequency == candidate.frequency)
            #expect(termExtractionClose(term.lr, expected[index][offset]))
            #expect(
                termExtractionClose(term.flr, expected[index][offset] * Double(candidate.frequency))
            )
        }
        let trigram = try #require(result.components.first { $0.component == "trigram" })
        #expect(trigram.leftFrequency == 5 && trigram.rightFrequency == 3)
        #expect(trigram.leftTypeCount == 3 && trigram.rightTypeCount == 2)
        #expect(result.terms.first?.components == ["trigram"])
        #expect(termExtractionClose(try #require(result.terms.first).flr, trigramFLR[index]))
        #expect(
            try GlifiTermExtraction.score(
                candidates.reversed(), adjacencyMode: mode,
                preprocessingIdentifier: "paper-example-v1") == result)
    }
}

@Test("F conta le occorrenze indipendenti, le adiacenze includono componenti ripetuti e nested")
func termExtractionSeparatesIndependentFrequencyAndRepeatedAdjacency() throws {
    let candidates = try [
        GlifiTermCandidate(components: ["a", "a", "a"], frequency: 2),
        GlifiTermCandidate(components: ["a"], frequency: 3),
    ]
    let token = try GlifiTermExtraction.score(candidates, preprocessingIdentifier: "independent-v1")
    #expect(token.independentOccurrenceCount == 5)
    #expect(token.components[0].leftFrequency == 4 && token.components[0].rightFrequency == 4)
    #expect(token.components[0].leftTypeCount == 1 && token.components[0].rightTypeCount == 1)
    #expect(token.terms.map(\.frequency) == [3, 2])
    #expect(termExtractionClose(token.terms[0].flr, 15))
    #expect(termExtractionClose(token.terms[1].flr, 10))
    let type = try GlifiTermExtraction.score(
        candidates, adjacencyMode: .type, preprocessingIdentifier: "independent-v1")
    #expect(type.terms.allSatisfy { termExtractionClose($0.lr, 2) })
    let duplicates = try GlifiTermExtraction.score(
        [
            .init(components: ["x", "y"], frequency: 2),
            .init(components: ["x", "y"], frequency: 3),
        ], preprocessingIdentifier: "independent-v1")
    #expect(duplicates.terms.count == 1 && duplicates.terms[0].frequency == 5)
    #expect(termExtractionClose(duplicates.terms[0].lr, 6.0.squareRoot()))
}

@Test("Le preannotazioni inglesi, giapponesi e italiane conservano POS, identità e byte originali")
func termExtractionUsesExplicitMultilingualAnnotationsAndExactEvidence() throws {
    let english = try termExtractionDocument(
        "en", contract: "caller-en-pos-v1",
        parts: [
            ("natural", "natural", "Noun", "", 0, 0),
            ("language", "language", "Noun", " ", 0, 0),
            ("runs", "run", "Verb", " ", 0, 0),
            ("data", "data", "Noun", " ", 0, 0),
            ("science", "science", "Noun", " ", 0, 0),
        ])
    let japanese = try termExtractionDocument(
        "ja", contract: "caller-ja-pos-v1",
        parts: [
            ("自然", "自然", "名詞", "", 0, 0),
            ("言語", "言語", "名詞", "", 0, 0),
            ("を", "を", "助詞", "", 0, 0),
            ("解析", "解析", "名詞", "", 0, 0),
        ])
    let italian = try termExtractionDocument(
        "it", contract: "caller-it-pos-v1",
        parts: [
            ("citta\u{0300}", "città", "Noun", "", 0, 0),
            ("aperta", "aperta", "Adjective", " ", 0, 0),
        ])
    let rule = try GlifiTermExtractionRule(
        identifier: "caller-maximal-noun-adjective-runs-v1",
        allowedPartsOfSpeech: ["Noun", "Adjective", "名詞"])
    let documents = [english, japanese, italian]
    let result = try GlifiTermExtraction.extract(documents, rule: rule)
    #expect(result.documentIDs == ["en", "ja", "it"])
    #expect(result.linguisticContracts == documents.map(\.linguisticContract))
    #expect(result.rule == rule)
    #expect(
        result.occurrences.map(\.components) == [
            ["natural", "language"], ["data", "science"], ["自然", "言語"], ["città", "aperta"],
        ])
    let expectedRanges = try [
        GlifiUTF8Range(start: 0, end: 16), GlifiUTF8Range(start: 22, end: 34),
        GlifiUTF8Range(start: 0, end: 12), GlifiUTF8Range(start: 0, end: 14),
    ]
    #expect(result.occurrences.map(\.range) == expectedRanges)
    #expect(result.occurrences.map(\.tokenRange) == [0..<2, 3..<5, 0..<2, 0..<2])
    #expect(
        result.occurrences[3].range.text(in: italian.text)?.utf8.elementsEqual(italian.text.utf8)
            == true)
    #expect(result.scores.independentOccurrenceCount == 4)
}

@Test("Un componente con molte adiacenze distinte conserva tutti i tipi e il punteggio scalare")
func termExtractionRetainsHighDegreeAdjacencyStatistics() throws {
    let candidates = try (0..<1_000).map {
        try GlifiTermCandidate(components: ["core", "term-\($0)"], frequency: 1)
    }
    let result = try GlifiTermExtraction.score(
        candidates, preprocessingIdentifier: "explicit-star-v1")
    let core = try #require(result.components.first { $0.component == "core" })
    #expect(core.leftFrequency == 0 && core.rightFrequency == 1_000)
    #expect(core.leftTypeCount == 0 && core.rightTypeCount == 1_000)
    #expect(result.components.count == 1_001 && result.terms.count == 1_000)
    // Product (0+1)(1000+1)(1+1)(0+1), followed by the fourth root.
    let expected = 2_002.0.squareRoot().squareRoot()
    #expect(result.terms.allSatisfy { termExtractionClose($0.lr, expected) })
}

@Test(
    "Le candidate non attraversano documenti, frasi, paragrafi, punteggiatura o esclusioni esplicite"
)
func termExtractionRespectsAllDeclaredCandidateBoundaries() throws {
    let rule = try GlifiTermExtractionRule(
        identifier: "noun-runs-v1", allowedPartsOfSpeech: ["Noun"], ignoredKeys: ["stop"])
    for value in [(", ", 0, 0), (" ", 1, 0), (" ", 0, 1)] {
        let document = try termExtractionDocument(
            "boundary",
            parts: [
                ("data", "data", "Noun", "", 0, 0),
                ("science", "science", "Noun", value.0, value.1, value.2),
            ])
        #expect(try GlifiTermExtraction.extract([document], rule: rule).occurrences.isEmpty)
    }
    let ignored = try termExtractionDocument(
        "ignored",
        parts: [
            ("data", "data", "Noun", "", 0, 0),
            ("stop", "stop", "Noun", " ", 0, 0),
            ("science", "science", "Noun", " ", 0, 0),
        ])
    #expect(try GlifiTermExtraction.extract([ignored], rule: rule).occurrences.isEmpty)
    let singletons = try ["a", "b"].map {
        try termExtractionDocument($0, parts: [($0, $0, "Noun", "", 0, 0)])
    }
    #expect(try GlifiTermExtraction.extract(singletons, rule: rule).occurrences.isEmpty)
    let individualRule = try GlifiTermExtractionRule(
        identifier: "noun-runs-singletons-v1", allowedPartsOfSpeech: ["Noun"], minimumComponents: 1)
    let observed = try GlifiTermExtraction.extract(singletons, rule: individualRule)
    #expect(
        observed.scores.components.allSatisfy { $0.leftFrequency == 0 && $0.rightFrequency == 0 })
    #expect(observed.scores.terms.allSatisfy { $0.lr == 1 && $0.flr == 1 })
}

@Test("Le run massime mantengono F indipendente e non creano candidate nested")
func termExtractionMaximalRunsDoNotInventNestedFrequency() throws {
    let rule = try GlifiTermExtractionRule(
        identifier: "noun-runs-v1", allowedPartsOfSpeech: ["Noun"])
    let first = try termExtractionDocument(
        "long",
        parts: [
            ("a", "a", "Noun", "", 0, 0), ("b", "b", "Noun", " ", 0, 0),
            ("c", "c", "Noun", " ", 0, 0),
        ])
    let second = try termExtractionDocument(
        "short",
        parts: [
            ("a", "a", "Noun", "", 0, 0), ("b", "b", "Noun", " ", 0, 0),
        ])
    let result = try GlifiTermExtraction.extract([first, second], rule: rule)
    #expect(result.occurrences.count == 2)
    #expect(result.scores.terms.count == 2)
    #expect(result.scores.terms.allSatisfy { $0.frequency == 1 })
    #expect(result.scores.independentOccurrenceCount == 2)
    let a = try #require(result.scores.components.first { $0.component == "a" })
    #expect(a.rightFrequency == 2 && a.rightTypeCount == 1)
}

@Test("Annotazioni mancanti e regole non valide falliscono senza inventare tokenizzazione o POS")
func termExtractionRejectsMissingAnnotationsAndInvalidRules() throws {
    let document = try GlifiCodingDocument(id: "plain", text: "natural language")
    let rule = try GlifiTermExtractionRule(
        identifier: "noun-runs-v1", allowedPartsOfSpeech: ["Noun"])
    do {
        _ = try GlifiTermExtraction.extract([document], rule: rule)
        Issue.record("Missing POS was accepted")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "term-extraction.missing-pos")
        #expect(failure.retainedState == .unchanged)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtractionRule(identifier: "", allowedPartsOfSpeech: ["Noun"])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtractionRule(identifier: "rules", allowedPartsOfSpeech: [])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtractionRule(
            identifier: "rules", allowedPartsOfSpeech: ["Noun"], minimumComponents: 3,
            maximumComponents: 2)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermCandidate(components: [], frequency: 1)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermCandidate(components: ["a"], frequency: 0)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermCandidate(components: [String(repeating: "a", count: 4_097)], frequency: 1)
    }
}

@Test(
    "Limiti di lavoro e componenti sono condivisi fra estrazione e scoring e non troncano risultati"
)
func termExtractionEnforcesSharedWorkAndCandidateLimits() throws {
    let candidate = try GlifiTermCandidate(components: ["a", "b"], frequency: 1)
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtraction.score([candidate], preprocessingIdentifier: "keys", maximumWork: 1)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtraction.score([candidate], preprocessingIdentifier: "keys", maximumWork: 0)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtraction.score(
            Array(repeating: candidate, count: GlifiTermExtraction.maximumCandidateCount + 1),
            preprocessingIdentifier: "keys")
    }
    let document = try termExtractionDocument(
        "long",
        parts: [
            ("a", "a", "Noun", "", 0, 0), ("b", "b", "Noun", " ", 0, 0),
            ("c", "c", "Noun", " ", 0, 0),
        ])
    let rule = try GlifiTermExtractionRule(
        identifier: "rules", allowedPartsOfSpeech: ["Noun"], maximumComponents: 2)
    do {
        _ = try GlifiTermExtraction.extract([document], rule: rule)
        Issue.record("An overlong maximal run was truncated or admitted")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "term-extraction.component-limit")
        #expect(failure.category == .insufficientResources && failure.retainedState == .unchanged)
    }
    let broad = try GlifiTermExtractionRule(identifier: "rules", allowedPartsOfSpeech: ["Noun"])
    #expect(throws: GlifiFailure.self) {
        try GlifiTermExtraction.extract([document], rule: broad, maximumWork: 10)
    }
    #expect(try GlifiTermExtraction.extract([document], rule: broad).occurrences.count == 1)
}

@Test("Frequenze Int.max restano finite e gli accumuli impossibili sono errori tipizzati")
func termExtractionHandlesRepresentableFrequencyExtremes() throws {
    let maximum = try GlifiTermCandidate(components: ["a", "b"], frequency: Int.max)
    let result = try GlifiTermExtraction.score([maximum], preprocessingIdentifier: "keys")
    #expect(result.terms[0].lr.isFinite && result.terms[0].flr.isFinite)
    #expect(termExtractionClose(result.terms[0].lr, Double(Int.max).squareRoot()))
    #expect(result.components[0].rightFrequency == Int.max)
    for candidates in [
        try [
            GlifiTermCandidate(components: ["a"], frequency: Int.max),
            GlifiTermCandidate(components: ["a"], frequency: 1),
        ],
        try [GlifiTermCandidate(components: ["a", "a", "a"], frequency: Int.max)],
    ] {
        do {
            _ = try GlifiTermExtraction.score(candidates, preprocessingIdentifier: "keys")
            Issue.record("An overflowing frequency accumulation was accepted")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "term-extraction.frequency-overflow")
            #expect(failure.retainedState == .unchanged)
        }
    }
}

@Test("Una cancellazione già richiesta interrompe sia l'estrazione sia il calcolo LR")
func termExtractionCancellationPrecedesAllWork() async throws {
    let candidates = try termExtractionPaperCandidates()
    let scoreTask = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiTermExtraction.score(candidates, preprocessingIdentifier: "keys")
    }
    await #expect(throws: CancellationError.self) { try await scoreTask.value }
    let rule = try GlifiTermExtractionRule(identifier: "rules", allowedPartsOfSpeech: ["Noun"])
    let extractionTask = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        _ = try GlifiTermExtraction.extract([], rule: rule)
    }
    await #expect(throws: CancellationError.self) { try await extractionTask.value }
}

private func termExtractionClose(_ actual: Double, _ expected: Double) -> Bool {
    abs(actual - expected) <= 3e-13 * max(1, abs(expected))
}

private func termExtractionPaperCandidates() throws -> [GlifiTermCandidate] {
    try [
        GlifiTermCandidate(components: ["trigram", "statistics"], frequency: 1),
        GlifiTermCandidate(components: ["word", "trigram"], frequency: 2),
        GlifiTermCandidate(components: ["class", "trigram"], frequency: 1),
        GlifiTermCandidate(components: ["trigram", "extraction"], frequency: 1),
        GlifiTermCandidate(components: ["word", "trigram", "statistics"], frequency: 1),
        GlifiTermCandidate(components: ["character", "trigram"], frequency: 1),
        GlifiTermCandidate(components: ["trigram"], frequency: 3),
    ]
}

private func termExtractionDocument(
    _ id: String, contract: String = "caller-pos-v1",
    parts: [(String, String, String, String, Int, Int)]
) throws -> GlifiCodingDocument {
    var text = ""
    var tokens: [GlifiCodingToken] = []
    for part in parts {
        text += part.3
        let start = text.utf8.count
        text += part.0
        tokens.append(
            GlifiCodingToken(
                surface: part.0, base: part.1, partOfSpeech: part.2,
                range: try GlifiUTF8Range(start: start, end: text.utf8.count),
                sentence: part.4, paragraph: part.5))
    }
    return try GlifiCodingDocument(id: id, text: text, tokens: tokens, linguisticContract: contract)
}
