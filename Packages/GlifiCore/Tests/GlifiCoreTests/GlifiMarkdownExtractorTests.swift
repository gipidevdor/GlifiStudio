// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Markdown estrae struttura e inline senza eseguire destinazioni o HTML")
func markdownExtractionProducesVisibleText() throws {
    let source = """
        # Titolo

        > - Una **città** e [il mare](https://example.invalid).

        <!-- non visibile -->
        <em>Testo</em> con `codice` &amp; simboli.

        ```swift
        print("testo")
        ```
        """
    let imported = try GlifiTextImporter().importText(
        from: Data(source.utf8),
        format: .markdown
    )

    #expect(
        imported.text
            == "Titolo\n\nUna città e il mare.\n\n\nTesto con codice & simboli.\n\n\nprint(\"testo\")\n"
    )
    #expect(!imported.text.contains("example.invalid"))
    #expect(!imported.text.contains("non visibile"))
    #expect(imported.spanMap.outputByteCount == imported.text.utf8.count)
    #expect(imported.spanMap.inputByteCount == source.utf8.count)
}

@Test("SpanMap risolve una phrase Markdown in intervalli sorgente esatti")
func markdownSpanMapResolvesDiscontinuousMarkup() throws {
    let source = "Una **città** e [il mare](destinazione)."
    let imported = try GlifiTextImporter().importText(
        from: Data(source.utf8),
        format: .markdown
    )
    let extractedRange = try #require(utf8Range(of: "città e il mare", in: imported.text))
    let sourceRanges = try imported.spanMap.sourceRanges(for: extractedRange)
    let reconstructed = sourceRanges.compactMap { sourceText(for: $0, in: imported.bytes) }.joined()

    #expect(imported.text == "Una città e il mare.")
    #expect(sourceRanges.count == 3)
    #expect(reconstructed == "città e il mare")
}

@Test("Entità e BOM conservano la relazione derivazionale e gli offset sorgente")
func spanMapAccountsForEntitiesAndByteOrderMark() throws {
    let markdownBytes = Data([0xEF, 0xBB, 0xBF]) + Data("Acqua &amp; città".utf8)
    let markdown = try GlifiTextImporter().importText(
        from: markdownBytes,
        format: .markdown
    )
    let ampersand = try #require(utf8Range(of: "&", in: markdown.text))
    let ampersandSources = try markdown.spanMap.sourceRanges(for: ampersand)

    #expect(markdown.text == "Acqua & città")
    #expect(ampersandSources.count == 1)
    #expect(sourceText(for: ampersandSources[0], in: markdownBytes) == "&amp;")

    let plain = try GlifiTextImporter().importText(
        from: Data([0xEF, 0xBB, 0xBF]) + Data("Città".utf8),
        format: .plainText
    )
    let whole = try GlifiUTF8Range(start: 0, end: plain.text.utf8.count)
    #expect(try plain.spanMap.sourceRanges(for: whole) == [GlifiUTF8Range(start: 3, end: 9)])
}

@Test("SpanMap rifiuta coperture incomplete e richieste fuori rappresentazione")
func spanMapRejectsInvalidCoverage() throws {
    let sourceRevisionID = SourceRevisionID()
    #expect(throws: GlifiFailure.self) {
        try GlifiSpanMap(
            contractIdentifier: "test-v1",
            sourceRevisionID: sourceRevisionID,
            inputByteCount: 4,
            outputByteCount: 4,
            segments: [
                GlifiSpanMapSegment(
                    outputRange: try GlifiUTF8Range(start: 1, end: 4),
                    inputRanges: [try GlifiUTF8Range(start: 1, end: 4)],
                    kind: .exact
                )
            ]
        )
    }

    let imported = try GlifiTextImporter().importText(
        from: Data("testo".utf8),
        format: .plainText
    )
    #expect(throws: GlifiFailure.self) {
        try imported.spanMap.sourceRanges(for: GlifiUTF8Range(start: 0, end: 6))
    }
}

@Test("Markdown ostile termina al budget di lookahead")
func markdownExtractionRejectsQuadraticLookahead() {
    let source = String(repeating: "[", count: 10_000) + "testo"

    do {
        _ = try GlifiTextImporter().importText(
            from: Data(source.utf8),
            format: .markdown
        )
        Issue.record("Il documento avversario avrebbe dovuto esaurire il budget")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "text.markdown-complexity-limit-exceeded")
        #expect(failure.category == .insufficientResources)
    } catch {
        Issue.record("Tipo di failure inatteso")
    }
}

private func utf8Range(of needle: String, in text: String) -> GlifiUTF8Range? {
    guard let range = text.range(of: needle),
        let lower = range.lowerBound.samePosition(in: text.utf8),
        let upper = range.upperBound.samePosition(in: text.utf8)
    else {
        return nil
    }
    return try? GlifiUTF8Range(
        start: text.utf8.distance(from: text.utf8.startIndex, to: lower),
        end: text.utf8.distance(from: text.utf8.startIndex, to: upper)
    )
}

private func sourceText(for range: GlifiUTF8Range, in data: Data) -> String? {
    guard range.end <= data.count else { return nil }
    return String(data: data[range.start..<range.end], encoding: .utf8)
}
