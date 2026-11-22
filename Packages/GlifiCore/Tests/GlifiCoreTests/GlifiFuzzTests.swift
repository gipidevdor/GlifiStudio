// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Fuzz deterministico (GS-SEC-001 THR-001, THR-009; RQ-044): generatori con seed dichiarato,
// nessuna dipendenza da tempo o rete. Ogni input deve produrre un esito tipizzato e, se
// accettato, rispettare gli invarianti di SpanMap, tokenizzazione e determinismo.

private struct FuzzGenerator {
    var random: GlifiSplitMix64

    init(seed: UInt64) {
        random = GlifiSplitMix64(seed: seed)
    }

    mutating func below(_ bound: Int) -> Int {
        Int(random.next() % UInt64(bound))
    }

    mutating func pick<T>(_ values: [T]) -> T {
        values[below(values.count)]
    }
}

/// Byte fragments mixing valid text, controls, BOMs and invalid UTF-8.
private let byteFragments: [[UInt8]] = [
    Array("casa ".utf8), Array("Città".utf8), Array("è".utf8), Array("perché ".utf8),
    Array("😀".utf8), Array("e\u{301}".utf8), [0x0A], [0x0D, 0x0A], [0x0D], [0x09], [0x00],
    [0xEF, 0xBB, 0xBF], [0xFE, 0xFF], [0xC3], [0xFF], [0xE2, 0x82], [0xED, 0xA0, 0x80],
    [0xF4, 0x90, 0x80, 0x80], Array(". ".utf8), Array("l'uomo ".utf8), Array("   ".utf8),
    [0x7F], [0x1B], Array("\u{202E}".utf8), Array("\u{200B}".utf8),
]

/// Markdown fragments stressing nesting, entities, HTML, links and fences.
private let markdownFragments: [String] = [
    "# ", "###### ", "####### ", "*", "**", "_", "__", "`", "```", "~~~", "\n", "\n\n", "> ",
    ">>>>>>>>>>", "- ", "1. ", "[", "]", "(", ")", "![", "<div>", "</div>", "<script>", "-->",
    "<!--", "&amp;", "&#x41;", "&#0;", "&#1114112;", "&bogus;", "\\", "\\*", "|a|b|", "---",
    "casa", "città", "è", "😀", " ", "\t", "[x]: http://a", "<http://a>", "***", "    code",
    String(repeating: "[", count: 64), String(repeating: "*", count: 64),
]

/// Query fragments of `glifi-query-v1`, valid and malformed.
private let queryFragments: [String] = [
    "casa", "mare", "normalized:casa", "form:Casa", "\"casa sul mare\"", "\"", "AND", "OR",
    "NOT", "NEAR/2", "BEFORE/1", "BEFORE/0", "NEAR/-1", "NEAR/99999", "(", ")", "[", "]",
    "{", "}", ":", "~", "form:/^Casa$/", "form:/(a+)+/", "form:/[/", "form:/a/i", "form:/x/z",
    "sconosciuto:casa", "*", "città", " ", "  ", "😀", "\\", "/", "TO",
]

private func expectSpanMapInvariants(_ imported: GlifiImportedText, byteCount: Int) {
    let map = imported.spanMap
    let output = Array(imported.text.utf8)
    let source = Array(imported.bytes)
    #expect(map.inputByteCount == byteCount)
    #expect(map.outputByteCount == imported.text.utf8.count)
    var cursor = 0
    for segment in map.segments {
        #expect(segment.outputRange.start == cursor)
        #expect(segment.outputRange.end >= segment.outputRange.start)
        cursor = segment.outputRange.end
        for range in segment.inputRanges {
            #expect(range.start >= 0 && range.end <= byteCount && range.start <= range.end)
        }
        // Lineage exact: i byte estratti coincidono con i byte sorgente mappati.
        if segment.kind == .exact, let input = segment.inputRanges.first,
            segment.inputRanges.count == 1, segment.outputRange.end <= output.count,
            input.end <= source.count
        {
            #expect(
                output[segment.outputRange.start..<segment.outputRange.end]
                    == source[input.start..<input.end])
        }
    }
    #expect(cursor == map.outputByteCount)
}

private func expectTokenizationInvariants(_ text: String) throws {
    let tokenization = try GlifiItalianTokenizer().tokenize(text)
    #expect(tokenization.sourceUTF8Length == text.utf8.count)
    var previousEnd = 0
    for token in tokenization.tokens {
        #expect(token.range.start >= previousEnd)
        #expect(token.range.end <= text.utf8.count)
        #expect(token.range.text(in: text) != nil)
        previousEnd = token.range.end
    }
}

private func fuzzImport(format: GlifiTextFormat, input: Data) throws -> GlifiImportedText? {
    let identity = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-0000000000f5")
    do {
        return try GlifiTextImporter().importText(
            from: input, format: format, sourceRevisionID: identity)
    } catch is GlifiFailure {
        return nil
    }
}

@Test("Fuzz TXT: 2.000 input con byte ostili producono esiti tipizzati e SpanMap valide")
func fuzzPlainTextImport() throws {
    var generator = FuzzGenerator(seed: 0x5EED_0001)
    var accepted = 0
    for _ in 0..<2_000 {
        var bytes: [UInt8] = []
        for _ in 0..<generator.below(48) {
            bytes += generator.pick(byteFragments)
        }
        let data = Data(bytes)
        guard let imported = try fuzzImport(format: .plainText, input: data) else { continue }
        accepted += 1
        expectSpanMapInvariants(imported, byteCount: data.count)
        try expectTokenizationInvariants(imported.text)
        #expect(try fuzzImport(format: .plainText, input: data) == imported)
    }
    // Il generatore deve esercitare sia il rifiuto sia l'accettazione.
    #expect(accepted > 100 && accepted < 2_000)
}

@Test("Fuzz Markdown: 2.000 documenti annidati e malformati restano mappati sulla fonte")
func fuzzMarkdownImport() throws {
    var generator = FuzzGenerator(seed: 0x5EED_0002)
    var accepted = 0
    for _ in 0..<2_000 {
        var text = ""
        for _ in 0..<generator.below(40) {
            text += generator.pick(markdownFragments)
        }
        let data = Data(text.utf8)
        guard let imported = try fuzzImport(format: .markdown, input: data) else { continue }
        accepted += 1
        expectSpanMapInvariants(imported, byteCount: data.count)
        try expectTokenizationInvariants(imported.text)
        #expect(try fuzzImport(format: .markdown, input: data) == imported)
    }
    #expect(accepted > 1_000)
}

/// Query following the `glifi-query-v1` grammar, with bounded nesting.
private func grammaticalQuery(_ generator: inout FuzzGenerator, depth: Int) -> String {
    let terms = [
        "casa", "mare", "città", "normalized:casa", "form:Casa", "\"casa sul mare\"",
        "form:/^Casa$/", "form:/(a+)+b/", "form:/a/i", "normalized:mare",
    ]
    var parts = [generator.pick(terms)]
    for _ in 0..<generator.below(3) {
        let next =
            depth < 3 && generator.below(4) == 0
            ? "(" + grammaticalQuery(&generator, depth: depth + 1) + ")" : generator.pick(terms)
        parts.append(generator.pick(["AND", "OR", "NEAR/2", "BEFORE/1", "AND NOT"]))
        parts.append(next)
    }
    return parts.joined(separator: " ")
}

@Test("Fuzz query: 3.000 query valide e malformate hanno esito tipizzato e tempo limitato")
func fuzzQueryParseAndEvaluate() throws {
    var generator = FuzzGenerator(seed: 0x5EED_0003)
    let text = "La casa sul mare. Casa, città e mare: aaaaaaaaaaaaaaaaaaaaaaaaaaaaab."
    let imported = try GlifiTextImporter().importText(
        from: Data(text.utf8), format: .plainText,
        sourceRevisionID: try SourceRevisionID(
            canonicalValue: "source-revision:00000000-0000-0000-0000-0000000000f6"))
    let tokenization = try GlifiItalianTokenizer().tokenize(imported.text)
    let clock = ContinuousClock()
    let started = clock.now
    var parsed = 0
    var evaluated = 0
    for _ in 0..<3_000 {
        let query =
            generator.below(10) < 3
            ? (0..<(1 + generator.below(8))).map { _ in generator.pick(queryFragments) }
                .joined(separator: generator.below(4) == 0 ? "" : " ")
            : grammaticalQuery(&generator, depth: 0)
        let ast: GlifiQueryAST
        do {
            ast = try GlifiQueryParser().parse(query)
        } catch is GlifiFailure {
            continue
        }
        parsed += 1
        #expect(try GlifiQueryParser().parse(query) == ast)
        do {
            let result = try GlifiQueryEvaluator().evaluate(
                ast, in: imported, tokenization: tokenization)
            evaluated += 1
            for match in result.matches {
                #expect(match.range.start >= 0 && match.range.end <= imported.text.utf8.count)
            }
        } catch is GlifiFailure {
            continue
        }
    }
    #expect(parsed > 300)
    #expect(evaluated > 300)
    // THR-009: nessuna query, regex annidate incluse, esaurisce il budget del test.
    #expect(clock.now - started < .seconds(60))
}

@Test("Regressione dal fuzz: un secondo BOM è contenuto e non viene scartato in silenzio")
func secondByteOrderMarkIsPreservedAsContent() throws {
    for format in [GlifiTextFormat.plainText, .markdown] {
        let data = Data([0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF] + Array("casa".utf8))
        let imported = try #require(try fuzzImport(format: format, input: data))
        #expect(imported.hadByteOrderMark)
        #expect(imported.text == "\u{FEFF}casa")
        expectSpanMapInvariants(imported, byteCount: data.count)
    }
}
