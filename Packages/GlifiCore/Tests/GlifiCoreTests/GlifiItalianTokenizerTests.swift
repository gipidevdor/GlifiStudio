// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("it-token-v1 coincide con tutti gli offset UTF-8 del seed")
func italianTokenizerMatchesSeedFixtures() throws {
    let fixture = try loadTokenFixture()
    let tokenizer = GlifiItalianTokenizer()

    for testCase in fixture.cases {
        let result = try tokenizer.tokenize(testCase.text)
        #expect(result.contractIdentifier == "it-token-v1", Comment(rawValue: testCase.id))
        #expect(result.sourceUTF8Length == testCase.utf8Length, Comment(rawValue: testCase.id))
        #expect(result.tokens.count == testCase.tokens.count, Comment(rawValue: testCase.id))
        #expect(result.sentences.count == testCase.sentences.count, Comment(rawValue: testCase.id))

        for (actual, expected) in zip(result.tokens, testCase.tokens) {
            #expect(actual.range.start == expected.start, Comment(rawValue: testCase.id))
            #expect(actual.range.end == expected.end, Comment(rawValue: testCase.id))
            #expect(
                actual.range.text(in: testCase.text) == expected.surface,
                Comment(rawValue: testCase.id))
            #expect(actual.kind.rawValue == expected.kind, Comment(rawValue: testCase.id))
            #expect(
                actual.components.count == expected.components.count, Comment(rawValue: testCase.id)
            )

            for (actualComponent, expectedComponent) in zip(actual.components, expected.components)
            {
                #expect(
                    actualComponent.range.start == expectedComponent.start,
                    Comment(rawValue: testCase.id)
                )
                #expect(
                    actualComponent.range.end == expectedComponent.end,
                    Comment(rawValue: testCase.id)
                )
                #expect(
                    actualComponent.range.text(in: testCase.text) == expectedComponent.surface,
                    Comment(rawValue: testCase.id)
                )
            }
        }

        for (actual, expected) in zip(result.sentences, testCase.sentences) {
            #expect(actual.range.start == expected.start, Comment(rawValue: testCase.id))
            #expect(actual.range.end == expected.end, Comment(rawValue: testCase.id))
            #expect(
                actual.range.text(in: testCase.text) == expected.surface,
                Comment(rawValue: testCase.id))
        }
    }
}

@Test("Token e frasi restano ordinati, bounded e senza sovrapposizioni")
func tokenizationPreservesStructuralInvariants() throws {
    let text = "Prima frase.\nSeconda: po' di città?!"
    let result = try GlifiItalianTokenizer().tokenize(text)

    #expect(result.sentences.count == 2)
    #expect(result.tokens.allSatisfy { $0.range.end <= text.utf8.count })
    for pair in zip(result.tokens, result.tokens.dropFirst()) {
        #expect(pair.0.range.end <= pair.1.range.start)
    }
}

@Test("URL, hashtag e mention restano unità speciali bounded")
func tokenizerRecognizesSpecialUnits() throws {
    let text = "Vedi https://example.org/a e #Città con @utente."
    let result = try GlifiItalianTokenizer().tokenize(text)
    let kindsAndSurfaces = result.tokens.compactMap { token in
        token.range.text(in: text).map { (token.kind, $0) }
    }

    #expect(kindsAndSurfaces.contains { $0 == (.url, "https://example.org/a") })
    #expect(kindsAndSurfaces.contains { $0 == (.hashtag, "#Città") })
    #expect(kindsAndSurfaces.contains { $0 == (.mention, "@utente") })
}

@Test("Il profilo Markdown usa soltanto il testo estratto con lineage")
func markdownProfileUsesExtractedText() throws {
    let imported = try GlifiTextImporter().importText(
        from: Data("# Titolo\nUna **città**.".utf8),
        format: .markdown
    )
    let profile = try GlifiTextAnalyzer().profile(imported)

    #expect(imported.text == "Titolo\nUna città.")
    #expect(imported.extractionContractIdentifier == "md-extract-v1")
    #expect(profile.lexicalTokenCount == 3)
    #expect(profile.frequencies.contains(GlifiTermFrequency(term: "città", count: 1)))
}

@Test("Il profilo è deterministico e ordina le frequenze con tie-break stabile")
func textProfileIsDeterministic() throws {
    let sourceRevisionID = SourceRevisionID(
        uuid: try #require(UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))
    )
    let imported = try GlifiTextImporter().importText(
        from: Data("Città città acqua.".utf8),
        format: .plainText,
        sourceRevisionID: sourceRevisionID
    )
    let analyzer = GlifiTextAnalyzer()
    let first = try analyzer.profile(imported)
    let second = try analyzer.profile(imported)

    #expect(first == second)
    #expect(first.lexicalTokenCount == 3)
    #expect(first.typeCount == 2)
    #expect(
        first.frequencies == [
            GlifiTermFrequency(term: "città", count: 2),
            GlifiTermFrequency(term: "acqua", count: 1),
        ])
}

private func loadTokenFixture() throws -> TokenFixture {
    var repositoryURL = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 {
        repositoryURL.deleteLastPathComponent()
    }
    let fixtureURL =
        repositoryURL
        .appending(path: "Fixtures/Linguistics/it-v1/token-boundaries.json")
    return try JSONDecoder().decode(TokenFixture.self, from: Data(contentsOf: fixtureURL))
}

private struct TokenFixture: Decodable {
    let cases: [TokenFixtureCase]
}

private struct TokenFixtureCase: Decodable {
    let id: String
    let text: String
    let utf8Length: Int
    let tokens: [TokenFixtureToken]
    let sentences: [TokenFixtureSpan]
}

private struct TokenFixtureToken: Decodable {
    let start: Int
    let end: Int
    let surface: String
    let kind: String
    let components: [TokenFixtureSpan]
}

private struct TokenFixtureSpan: Decodable {
    let start: Int
    let end: Int
    let surface: String
}
