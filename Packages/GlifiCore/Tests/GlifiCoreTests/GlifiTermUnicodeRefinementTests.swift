// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Term extraction preserves the first source spelling of canonically equal component keys")
func khRefinementTermExtractionCanonicalRepresentativeBytes() throws {
    let composed = "é"
    let decomposed = "e\u{301}"
    let rule = try GlifiTermExtractionRule(
        identifier: "first-source-noun-runs-v1", allowedPartsOfSpeech: ["Noun"])
    var mismatches: [String] = []
    // Vary lexical neighbors so dictionary storage order cannot accidentally
    // stand in for the required source order; both source orders are contracts.
    for index in 0..<24 {
        let first = try khRefinementTermDocument(
            id: "first", components: [composed, "left-\(index)"])
        let second = try khRefinementTermDocument(
            id: "second", components: [decomposed, "right-\(index)"])
        for documents in [[first, second], [second, first]] {
            let result = try GlifiTermExtraction.extract(documents, rule: rule)
            let representative = try #require(
                result.scores.components.first { $0.component == composed }
            ).component
            let expected = try #require(documents.first?.tokens.first?.base)
            if !representative.utf8.elementsEqual(expected.utf8) {
                mismatches.append(
                    "neighbor-\(index): \(Array(representative.utf8)) instead of \(Array(expected.utf8))"
                )
            }
            #expect(result.occurrences.count == 2)
            for (occurrence, document) in zip(result.occurrences, documents) {
                #expect(occurrence.components[0].utf8.elementsEqual(document.tokens[0].base.utf8))
                #expect(
                    occurrence.range.text(in: document.text)?.utf8.elementsEqual(document.text.utf8)
                        == true)
            }
            let observed = try #require(
                result.scores.components.first { $0.component == composed })
            #expect(observed.leftFrequency == 0 && observed.rightFrequency == 2)
            #expect(observed.leftTypeCount == 0 && observed.rightTypeCount == 2)
        }
    }
    #expect(
        mismatches.isEmpty, "Canonical equality must not randomize source spelling: \(mismatches)")
}

private func khRefinementTermDocument(
    id: String, components: [String]
) throws -> GlifiCodingDocument {
    let text = components.joined(separator: " ")
    var offset = 0
    let tokens = try components.map { component in
        let token = GlifiCodingToken(
            surface: component, base: component, partOfSpeech: "Noun",
            range: try GlifiUTF8Range(start: offset, end: offset + component.utf8.count),
            sentence: 0, paragraph: 0)
        offset += component.utf8.count + 1
        return token
    }
    return try GlifiCodingDocument(
        id: id, text: text, tokens: tokens, linguisticContract: "exact-caller-pos-v1")
}
