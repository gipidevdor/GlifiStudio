// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La precedenza NOT, prossimità, AND e OR produce un AST stabile")
func queryParserAppliesStablePrecedence() throws {
    let ast = try GlifiQueryParser().parse("città OR acqua AND NOT mare")

    #expect(
        ast.root
            == .or([
                .term(field: .form, value: "città", matchMode: .exact),
                .and([
                    .term(field: .form, value: "acqua", matchMode: .exact),
                    .not(.term(field: .form, value: "mare", matchMode: .exact)),
                ]),
            ])
    )
}

@Test("Phrase, prossimità, range e regex conservano parametri espliciti")
func queryParserPreservesExplicitParameters() throws {
    let phrase = try GlifiQueryParser().parse("normalized:\"L'acqua alta\"~2")
    #expect(
        phrase.root
            == .phrase(field: .normalized, values: ["L'acqua", "alta"], slop: 2)
    )

    let proximity = try GlifiQueryParser().parse("casa BEFORE / 3 mare")
    #expect(
        proximity.root
            == .proximity(
                left: .term(field: .form, value: "casa", matchMode: .exact),
                right: .term(field: .form, value: "mare", matchMode: .exact),
                distance: 3,
                unit: .surfaceToken,
                ordered: true
            )
    )

    let range = try GlifiQueryParser().parse("metadata.anno:[2020 TO 2024}")
    #expect(
        range.root
            == .range(
                field: GlifiQueryField(rawValue: "metadata.anno"),
                value: GlifiQueryRange(
                    lower: "2020",
                    upper: "2024",
                    includesLower: true,
                    includesUpper: false
                )
            )
    )

    let regex = try GlifiQueryParser().parse("form:/citt.*/ic")
    #expect(
        regex.root
            == .regex(
                field: .form,
                pattern: "citt.*",
                flags: [.caseInsensitive, .canonicalEquivalence]
            )
    )
}

@Test("Escape, AND implicito e canonicalizzazione restano deterministici")
func queryParserIsCanonical() throws {
    let parser = GlifiQueryParser()
    let escapedKeyword = try parser.parse("\\AND città")
    #expect(
        escapedKeyword.root
            == .and([
                .term(field: .form, value: "AND", matchMode: .exact),
                .term(field: .form, value: "città", matchMode: .exact),
            ])
    )

    let first = try parser.parse("città OR mare")
    let decoded = try JSONDecoder().decode(GlifiQueryAST.self, from: first.canonicalData())
    #expect(decoded == first)
    #expect(try decoded.canonicalDigest() == first.canonicalDigest())
}

@Test("Il parser rifiuta campi, sintassi e regex non conformi con span UTF-8")
func queryParserRejectsInvalidSyntax() throws {
    let parser = GlifiQueryParser()
    for (query, expectedCode) in [
        ("sconosciuto:valore", "query.unknown-field"),
        ("\"frase", "query.unterminated-phrase"),
        ("casa NEAR/10001 mare", "query.invalid-proximity"),
        ("form:/casa/x", "query.regex-rejected"),
        ("metadata.anno:[* TO *]", "query.invalid-range"),
    ] {
        do {
            _ = try parser.parse(query)
            Issue.record("La query non valida non è stata rifiutata")
        } catch let failure as GlifiFailure {
            #expect(failure.code == expectedCode)
            #expect(failure.operation == .query)
            #expect(failure.arguments["start"] != nil)
            #expect(failure.arguments["end"] != nil)
        }
    }
}

@Test("I limiti di byte, profondità e nodi sono applicati prima del lavoro non bounded")
func queryParserEnforcesBudgets() throws {
    let parser = GlifiQueryParser()
    let tinyLimits = GlifiQueryLimits(
        maximumQueryByteCount: 8,
        maximumDepth: 2,
        maximumNodeCount: 2,
        maximumPhraseTokenCount: 2,
        maximumProximityDistance: 2,
        maximumRegexByteCount: 4,
        maximumRegexInputByteCount: 8,
        maximumSourceCount: 2,
        maximumScannedByteCount: 64,
        maximumResultCount: 2,
        contextTokenCount: 1
    )

    #expect(throws: GlifiFailure.self) {
        try parser.parse("troppo-lunga", limits: tinyLimits)
    }
    #expect(throws: GlifiFailure.self) {
        try parser.parse("(((a)))", limits: tinyLimits)
    }
    #expect(throws: GlifiFailure.self) {
        try parser.parse("a b c", limits: tinyLimits)
    }
}

@Test(
    "La profondità delle catene NEAR e BEFORE rispetta il limite dell'AST",
    arguments: ["NEAR", "BEFORE"])
func queryParserBoundsProximityDepth(_ operation: String) throws {
    let parser = GlifiQueryParser()
    let separator = " \(operation)/1 "
    let atLimit = Array(repeating: "casa", count: 33).joined(separator: separator)
    let query = try parser.parse(atLimit)
    #expect(try GlifiQueryAST.decode(query.canonicalData()) == query)

    let overLimit = Array(repeating: "casa", count: 34).joined(separator: separator)
    try expectParserDepthFailure(overLimit, limits: .standard)
}

@Test("Ogni arco booleano contribuisce alla profondità e la radice resta a zero")
func queryParserBoundsBooleanDepth() throws {
    let parser = GlifiQueryParser()
    for (text, depth) in [
        ("casa", 0), ("casa mare", 1), ("casa OR mare", 1),
        ("casa OR mare AND acqua", 2), ("casa OR mare AND NOT acqua", 3),
    ] {
        let limits = queryParserDepthLimits(depth)
        let query = try parser.parse(text, limits: limits)
        #expect(try GlifiQueryAST.decode(query.canonicalData(), limits: limits) == query)
        if depth > 0 {
            try expectParserDepthFailure(text, limits: queryParserDepthLimits(depth - 1))
        }
    }
}

@Test("Il controllo di profondità preserva le guardie sintattiche e la validazione regex separata")
func queryParserDepthPreservesExistingContracts() throws {
    try expectParserDepthFailure("((casa))", limits: queryParserDepthLimits(1))
    let query = try GlifiQueryParser().parse("form:/(a+)+/")
    #expect(query.root == .regex(field: .form, pattern: "(a+)+", flags: []))
    #expect(throws: GlifiFailure.self) {
        try GlifiQueryEvaluator().validate(query)
    }
}

private func queryParserDepthLimits(_ depth: Int) -> GlifiQueryLimits {
    let standard = GlifiQueryLimits.standard
    return GlifiQueryLimits(
        maximumQueryByteCount: standard.maximumQueryByteCount,
        maximumDepth: depth,
        maximumNodeCount: standard.maximumNodeCount,
        maximumPhraseTokenCount: standard.maximumPhraseTokenCount,
        maximumProximityDistance: standard.maximumProximityDistance,
        maximumRegexByteCount: standard.maximumRegexByteCount,
        maximumRegexInputByteCount: standard.maximumRegexInputByteCount,
        maximumSourceCount: standard.maximumSourceCount,
        maximumScannedByteCount: standard.maximumScannedByteCount,
        maximumResultCount: standard.maximumResultCount,
        contextTokenCount: standard.contextTokenCount
    )
}

private func expectParserDepthFailure(_ text: String, limits: GlifiQueryLimits) throws {
    do {
        _ = try GlifiQueryParser().parse(text, limits: limits)
        Issue.record("The parser accepted a query exceeding its depth limit")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "query.depth-limit-exceeded")
        #expect(failure.category == .insufficientResources)
        #expect(failure.operation == .query)
        #expect(failure.arguments["start"] != nil)
        #expect(failure.arguments["end"] != nil)
        #expect(!String(describing: failure).contains(text))
    }
}
