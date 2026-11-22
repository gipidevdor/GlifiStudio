// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Termini, phrase e KWIC mantengono offset e normalizzazione")
func queryEvaluatorProducesPositionalMatches() throws {
    let source = try imported("Casa, casa sul mare. La casa guarda il mare.")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let evaluator = GlifiQueryEvaluator()

    let normalized = try evaluator.evaluate(
        GlifiQueryParser().parse("normalized:casa"),
        in: source,
        tokenization: tokenization
    )
    #expect(normalized.matchedScope)
    #expect(normalized.matches.count == 3)
    #expect(normalized.matches[0].range.text(in: source.text) == "Casa")
    #expect(
        normalized.matches[0].rightContextRange?.text(in: source.text)?.contains("mare") == true)

    let exact = try evaluator.evaluate(
        GlifiQueryParser().parse("form:Casa"),
        in: source,
        tokenization: tokenization
    )
    #expect(exact.matches.count == 1)

    let phrase = try evaluator.evaluate(
        GlifiQueryParser().parse("\"casa sul mare\""),
        in: source,
        tokenization: tokenization
    )
    #expect(phrase.matches.count == 1)
    #expect(phrase.matches[0].range.text(in: source.text) == "casa sul mare")

    let slop = try evaluator.evaluate(
        GlifiQueryParser().parse("\"Casa casa\"~1"),
        in: source,
        tokenization: tokenization
    )
    #expect(slop.matches.first?.range.text(in: source.text) == "Casa, casa")
}

@Test("I termini Unicode conservano campi, forma esatta, digest e coordinate KWIC")
func queryEvaluatorPreservesUnicodeTermFieldsAndKWIC() throws {
    let fixture = try queryTermUnicodeFixture()
    let evaluator = GlifiQueryEvaluator()
    let limits = queryTermLimits(maximumResultCount: 1_000)
    let cases: [(field: GlifiQueryField, value: String, indices: [Int])] = [
        (.normalized, "E\u{0300}", [0, 1, 2]),
        (.normalized, "È", [0, 1, 2]),
        (.form, "È", [0, 2]),
        (.text, "E\u{0300}", [0, 2]),
        (.normalized, "CITTA\u{0300}", [3, 4, 5]),
        (.form, "CITTÀ", [3, 5]),
        (.text, "città", [4]),
        (.normalized, "NAÏVE", [6, 7]),
        (.form, "naïve", [6]),
        (.normalized, "ASSENTE\u{0300}", []),
    ]
    for (field, value, indices) in cases {
        let query = GlifiQueryAST(root: .term(field: field, value: value, matchMode: .exact))
        let expected = try GlifiQueryResult(
            queryDigest: query.canonicalDigest(),
            sourceRevisionID: fixture.source.sourceRevisionID,
            matchedScope: !indices.isEmpty,
            matches: queryTermExpectedMatches(
                indices, ranges: fixture.ranges, sourceRevisionID: fixture.source.sourceRevisionID),
            isTruncated: false)
        let result = try evaluator.evaluate(
            query, in: fixture.source, tokenization: fixture.tokenization, limits: limits)
        #expect(result == expected)
        let decoded = try GlifiQueryAST.decode(query.canonicalData(), limits: limits)
        #expect(
            try evaluator.evaluate(
                decoded, in: fixture.source, tokenization: fixture.tokenization, limits: limits)
                == expected)
    }
}

@Test("La normalizzazione del termine conserva troncatura zero, parziale e completa")
func queryEvaluatorPreservesNormalizedTermTruncation() throws {
    let fixture = try queryTermUnicodeFixture()
    let query = GlifiQueryAST(
        root: .term(field: .normalized, value: "E\u{0300}", matchMode: .exact))
    for maximumResultCount in [0, 1, 2, 3, 4] {
        let indices = Array([0, 1, 2].prefix(maximumResultCount))
        let result = try GlifiQueryEvaluator().evaluate(
            query, in: fixture.source, tokenization: fixture.tokenization,
            limits: queryTermLimits(maximumResultCount: maximumResultCount))
        #expect(
            result
                == GlifiQueryResult(
                    queryDigest: try query.canonicalDigest(),
                    sourceRevisionID: fixture.source.sourceRevisionID,
                    matchedScope: true,
                    matches: queryTermExpectedMatches(
                        indices, ranges: fixture.ranges,
                        sourceRevisionID: fixture.source.sourceRevisionID),
                    isTruncated: maximumResultCount < 3))
    }
}

@Test("Una valutazione di termine già cancellata non avvia la scansione")
func queryEvaluatorPreservesTermCancellation() async throws {
    let fixture = try queryTermUnicodeFixture()
    let query = GlifiQueryAST(
        root: .term(field: .normalized, value: "CITTA\u{0300}", matchMode: .exact))
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiQueryEvaluator().evaluate(
            query, in: fixture.source, tokenization: fixture.tokenization)
    }
    do {
        _ = try await task.value
        Issue.record("A cancelled term evaluation succeeded")
    } catch is CancellationError {
        // Cancellation remains observable before any term comparison.
    }
}

@Test("Booleani e prossimità usano lo scope e l'ordine canonici")
func queryEvaluatorAppliesBooleanAndProximitySemantics() throws {
    let source = try imported("Casa, casa sul mare. La casa guarda il mare.")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let evaluator = GlifiQueryEvaluator()

    let selected = try evaluator.evaluate(
        GlifiQueryParser().parse("normalized:casa AND NOT oceano"),
        in: source,
        tokenization: tokenization
    )
    #expect(selected.matchedScope)
    #expect(selected.matches.count == 3)

    let rejected = try evaluator.evaluate(
        GlifiQueryParser().parse("normalized:casa AND NOT normalized:mare"),
        in: source,
        tokenization: tokenization
    )
    #expect(!rejected.matchedScope)
    #expect(rejected.matches.isEmpty)

    let proximity = try evaluator.evaluate(
        GlifiQueryParser().parse("normalized:casa BEFORE/1 normalized:mare"),
        in: source,
        tokenization: tokenization
    )
    #expect(proximity.matches.count == 1)
    #expect(proximity.matches[0].range.text(in: source.text) == "casa sul mare")

    let otherRevision = SourceRevisionID()
    let scoped = GlifiQueryAST(
        root: .within(
            .term(field: .normalized, value: "casa", matchMode: .exact),
            scope: .sourceRevision(otherRevision)
        )
    )
    let scopedResult = try evaluator.evaluate(scoped, in: source, tokenization: tokenization)
    #expect(!scopedResult.matchedScope)
}

@Test("Il sottoinsieme regex bounded evita costrutti di backtracking")
func queryEvaluatorUsesSafeRegexSubset() throws {
    let source = try imported("Casa città casetta mare 123.")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let evaluator = GlifiQueryEvaluator()

    let result = try evaluator.evaluate(
        GlifiQueryParser().parse("form:/^ca.*a$/i"),
        in: source,
        tokenization: tokenization
    )
    #expect(result.matches.map { $0.range.text(in: source.text) } == ["Casa", "casetta"])

    let digits = try evaluator.evaluate(
        GlifiQueryParser().parse("form:/^\\d+$/"),
        in: source,
        tokenization: tokenization
    )
    #expect(digits.matches.map { $0.range.text(in: source.text) } == ["123"])

    let rejected = GlifiQueryAST(
        root: .regex(field: .form, pattern: "(a+)+", flags: [])
    )
    #expect(throws: GlifiFailure.self) {
        try evaluator.evaluate(rejected, in: source, tokenization: tokenization)
    }
}

@Test("Il limite risultati marca esplicitamente la troncatura")
func queryEvaluatorMarksTruncation() throws {
    let source = try imported("uno uno uno uno")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let limits = GlifiQueryLimits(
        maximumQueryByteCount: 64,
        maximumDepth: 8,
        maximumNodeCount: 16,
        maximumPhraseTokenCount: 8,
        maximumProximityDistance: 8,
        maximumRegexByteCount: 16,
        maximumRegexInputByteCount: 64,
        maximumSourceCount: 4,
        maximumScannedByteCount: 1_024,
        maximumResultCount: 2,
        contextTokenCount: 1
    )
    let result = try GlifiQueryEvaluator().evaluate(
        GlifiQueryParser().parse("uno", limits: limits),
        in: source,
        tokenization: tokenization,
        limits: limits
    )

    #expect(result.matches.count == 2)
    #expect(result.isTruncated)
}

@Test("Campi privi di capability falliscono senza simulare zero risultati")
func queryEvaluatorRejectsUnavailableCapabilities() throws {
    let source = try imported("una casa")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let query = GlifiQueryAST(
        root: .term(field: .lemma, value: "casa", matchMode: .exact)
    )

    do {
        _ = try GlifiQueryEvaluator().evaluate(query, in: source, tokenization: tokenization)
        Issue.record("Il campo lemma non disponibile è stato trattato come supportato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "query.unsupported-field")
        #expect(failure.category == .insufficientData)
    }
}

@Test("Il contesto KWIC estremo resta nei token disponibili senza overflow")
func queryEvaluatorBoundsExtremeContext() throws {
    let source = try imported("uno due tre quattro")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let query = GlifiQueryAST(root: .term(field: .form, value: "due", matchMode: .exact))
    let result = try GlifiQueryEvaluator().evaluate(
        query, in: source, tokenization: tokenization,
        limits: queryTermLimits(maximumResultCount: Int.max, contextTokenCount: Int.max))

    let match = try #require(result.matches.first)
    #expect(match.range.text(in: source.text) == "due")
    #expect(match.leftContextRange?.text(in: source.text) == "uno")
    #expect(match.rightContextRange?.text(in: source.text) == "tre quattro")
    #expect(!result.isTruncated)
}

@Test("La prossimità trova anche operandi oltre il limite delle righe materializzate")
func queryEvaluatorDoesNotTruncateProximityOperands() throws {
    let source = try imported("a a a b")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let query = GlifiQueryAST(
        root: .proximity(
            left: .term(field: .form, value: "a", matchMode: .exact),
            right: .term(field: .form, value: "b", matchMode: .exact),
            distance: 0, unit: .surfaceToken, ordered: true))
    let result = try GlifiQueryEvaluator().evaluate(
        query, in: source, tokenization: tokenization,
        limits: queryTermLimits(maximumResultCount: 1))

    #expect(result.matchedScope)
    #expect(result.matches.map { $0.range.text(in: source.text) } == ["a b"])
    #expect(!result.isTruncated)
}

@Test("L'unione booleana conserva le prime righe canoniche indipendentemente dai figli")
func queryEvaluatorCanonicalizesBoundedBooleanUnions() throws {
    let source = try imported("a a a b b b")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let a = GlifiQueryNode.term(field: .form, value: "a", matchMode: .exact)
    let b = GlifiQueryNode.term(field: .form, value: "b", matchMode: .exact)
    for root in [GlifiQueryNode.or([a, b]), .or([b, a]), .and([a, b]), .and([b, a])] {
        let result = try GlifiQueryEvaluator().evaluate(
            GlifiQueryAST(root: root), in: source, tokenization: tokenization,
            limits: queryTermLimits(maximumResultCount: 2))

        #expect(result.matchedScope)
        #expect(result.matches.map(\.range) == Array(tokenization.tokens.prefix(2)).map(\.range))
        #expect(result.isTruncated)
    }
}

@Test("La prossimità bounded coincide con l'enumerazione indipendente dei piccoli input")
func queryEvaluatorMatchesExhaustiveProximityReference() throws {
    for bits in 0..<32 {
        let forms = (0..<5).map { bits & (1 << $0) == 0 ? "a" : "b" }
        let source = try imported(forms.joined(separator: " "))
        let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
        for ordered in [false, true] {
            var intervals: Set<[Int]> = []
            for left in forms.indices where forms[left] == "a" {
                for right in forms.indices where forms[right] == "b" {
                    guard !ordered || left < right, abs(left - right) - 1 <= 2 else {
                        continue
                    }
                    intervals.insert([min(left, right) * 2, max(left, right) * 2 + 1])
                }
            }
            let expected = try intervals.sorted { $0.lexicographicallyPrecedes($1) }.map {
                try GlifiUTF8Range(start: $0[0], end: $0[1])
            }
            let query = GlifiQueryAST(
                root: .proximity(
                    left: .term(field: .form, value: "a", matchMode: .exact),
                    right: .term(field: .form, value: "b", matchMode: .exact),
                    distance: 2, unit: .surfaceToken, ordered: ordered))
            for maximumResultCount in [0, 1, 2, 10] {
                let result = try GlifiQueryEvaluator().evaluate(
                    query, in: source, tokenization: tokenization,
                    limits: queryTermLimits(maximumResultCount: maximumResultCount))
                #expect(result.matchedScope == !expected.isEmpty)
                #expect(result.matches.map(\.range) == Array(expected.prefix(maximumResultCount)))
                #expect(result.isTruncated == (expected.count > maximumResultCount))
            }
        }
    }
}

@Test("I budget intermedi sono globali e non dipendono dal numero di righe richieste")
func queryEvaluatorEnforcesGlobalIntermediateBudgets() throws {
    let source = try imported("a a a b")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let query = GlifiQueryAST(
        root: .proximity(
            left: .term(field: .form, value: "a", matchMode: .exact),
            right: .term(field: .form, value: "b", matchMode: .exact),
            distance: 0, unit: .surfaceToken, ordered: true))
    let accepted = try GlifiQueryEvaluator().evaluate(
        query, in: source, tokenization: tokenization,
        limits: queryTermLimits(
            maximumResultCount: 1, maximumIntermediateAnchorCount: 5,
            maximumEvaluationStepCount: 17))
    #expect(accepted.matches.map { $0.range.text(in: source.text) } == ["a b"])
    for (anchors, steps, code) in [
        (4, 17, "query.intermediate-anchor-limit-exceeded"),
        (5, 16, "query.evaluation-step-limit-exceeded"),
    ] {
        do {
            _ = try GlifiQueryEvaluator().evaluate(
                query, in: source, tokenization: tokenization,
                limits: queryTermLimits(
                    maximumResultCount: 1, maximumIntermediateAnchorCount: anchors,
                    maximumEvaluationStepCount: steps))
            Issue.record("An exhausted global query budget succeeded")
        } catch let failure as GlifiFailure {
            #expect(failure.code == code)
            #expect(failure.category == .insufficientResources)
            #expect(failure.operation == .query)
        }
    }
}

@Test("L'indice di prossimità conserva intervalli annidati, sovrapposti e deduplicati")
func queryEvaluatorMatchesNestedIntervalReference() throws {
    let source = try imported("a b a b a b a")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let a = GlifiQueryNode.term(field: .form, value: "a", matchMode: .exact)
    let b = GlifiQueryNode.term(field: .form, value: "b", matchMode: .exact)
    let ab = GlifiQueryNode.phrase(field: .form, values: ["a", "b"], slop: 0)
    let aba = GlifiQueryNode.phrase(field: .form, values: ["a", "b", "a"], slop: 0)
    let variants: [(node: GlifiQueryNode, spans: [(Int, Int)])] = [
        (a, [(0, 1), (2, 3), (4, 5), (6, 7)]),
        (b, [(1, 2), (3, 4), (5, 6)]),
        (ab, [(0, 2), (2, 4), (4, 6)]),
        (aba, [(0, 3), (2, 5), (4, 7)]),
        (.or([a, aba]), [(0, 1), (0, 3), (2, 3), (2, 5), (4, 5), (4, 7), (6, 7)]),
        (.and([b, ab]), [(0, 2), (1, 2), (2, 4), (3, 4), (4, 6), (5, 6)]),
        (
            .proximity(left: a, right: b, distance: 0, unit: .surfaceToken, ordered: true),
            [(0, 2), (2, 4), (4, 6)]
        ),
    ]
    for left in variants {
        for right in variants {
            for ordered in [false, true] {
                for distance in [0, 1, Int.max] {
                    var intervals: Set<[Int]> = []
                    for l in left.spans {
                        for r in right.spans {
                            if l.1 <= r.0, r.0 - l.1 <= distance {
                                intervals.insert([l.0 * 2, r.1 * 2 - 1])
                            } else if !ordered, r.1 <= l.0, l.0 - r.1 <= distance {
                                intervals.insert([r.0 * 2, l.1 * 2 - 1])
                            }
                        }
                    }
                    let expected = try intervals.sorted { $0.lexicographicallyPrecedes($1) }.map {
                        try GlifiUTF8Range(start: $0[0], end: $0[1])
                    }
                    let query = GlifiQueryAST(
                        root: .proximity(
                            left: left.node, right: right.node, distance: distance,
                            unit: .surfaceToken, ordered: ordered))
                    for maximumResultCount in [0, 1, 4, 100] {
                        let result = try GlifiQueryEvaluator().evaluate(
                            query, in: source, tokenization: tokenization,
                            limits: queryTermLimits(
                                maximumResultCount: maximumResultCount,
                                maximumProximityDistance: Int.max))
                        #expect(result.matchedScope == !expected.isEmpty)
                        #expect(
                            result.matches.map(\.range)
                                == Array(expected.prefix(maximumResultCount)))
                        #expect(result.isTruncated == (expected.count > maximumResultCount))
                    }
                }
            }
        }
    }
}

@Test("La prossimità selettiva non esplora il prodotto cartesiano degli operandi")
func queryEvaluatorIndexesSelectiveProximityWithinBudget() throws {
    let source = try imported(
        String(repeating: "a ", count: 1_001) + String(repeating: "b ", count: 1_001))
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let query = try GlifiQueryParser().parse("a BEFORE/0 b")
    let result = try GlifiQueryEvaluator().evaluate(
        query, in: source, tokenization: tokenization,
        limits: queryTermLimits(maximumResultCount: 1, maximumEvaluationStepCount: 16_000))

    #expect(result.matchedScope)
    #expect(result.matches.map(\.range) == [try GlifiUTF8Range(start: 2_000, end: 2_003)])
    #expect(!result.isTruncated)
}

@Test("Frasi e NFA regex rispettano lo stesso budget di passi della valutazione")
func queryEvaluatorBoundsPhraseAndRegexWork() throws {
    let source = try imported("aaaa c c c b")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let queries = [
        GlifiQueryAST(root: .phrase(field: .form, values: ["aaaa", "b"], slop: 3)),
        GlifiQueryAST(root: .regex(field: .form, pattern: "^a+$", flags: [])),
    ]
    for query in queries {
        #expect(
            try GlifiQueryEvaluator().evaluate(
                query, in: source, tokenization: tokenization
            ).matchedScope)
        do {
            _ = try GlifiQueryEvaluator().evaluate(
                query, in: source, tokenization: tokenization,
                limits: queryTermLimits(maximumResultCount: 1, maximumEvaluationStepCount: 5))
            Issue.record("An exhausted phrase or regex budget succeeded")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "query.evaluation-step-limit-exceeded")
            #expect(failure.category == .insufficientResources)
        }
    }
}

@Test("I byte aggregati di una frase sono validati prima di normalizzazione e lavoro")
func queryEvaluatorBoundsProgrammaticPhraseBytesBeforeWork() throws {
    let evaluator = GlifiQueryEvaluator()
    let limits = queryTermLimits(
        maximumResultCount: 1, maximumEvaluationStepCount: 0, maximumQueryByteCount: 4)
    try evaluator.validate(
        GlifiQueryAST(root: .phrase(field: .normalized, values: ["é", "ab"], slop: 0)),
        limits: limits)
    let source = try imported("é ab")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    for values in [["e\u{0301}", "ab"], [String(repeating: "a", count: 65_537)]] {
        let query = GlifiQueryAST(root: .phrase(field: .normalized, values: values, slop: 0))
        do {
            _ = try evaluator.evaluate(
                query, in: source, tokenization: tokenization, limits: limits)
            Issue.record("An oversized programmatic phrase succeeded")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "query.byte-limit-exceeded")
            #expect(failure.category == .insufficientResources)
            #expect(failure.operation == .query)
        }
    }
}

@Test("L'inizializzatore query originale resta utilizzabile come valore funzione")
func queryLimitsPreserveLegacyInitializerFunctionReference() {
    let factory: (Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int) -> GlifiQueryLimits =
        GlifiQueryLimits.init
    let standard = GlifiQueryLimits.standard
    let limits = factory(
        standard.maximumQueryByteCount, standard.maximumDepth, standard.maximumNodeCount,
        standard.maximumPhraseTokenCount, standard.maximumProximityDistance,
        standard.maximumRegexByteCount, standard.maximumRegexInputByteCount,
        standard.maximumSourceCount, standard.maximumScannedByteCount,
        standard.maximumResultCount, standard.contextTokenCount)
    #expect(limits == standard)
}

@Test("La distanza estrema di una frase resta nei token disponibili senza overflow")
func queryEvaluatorBoundsExtremePhraseSlop() throws {
    let source = try imported("zero uno prova due tre")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let query = GlifiQueryAST(
        root: .phrase(field: .form, values: ["uno", "tre"], slop: Int.max))
    let result = try GlifiQueryEvaluator().evaluate(
        query, in: source, tokenization: tokenization,
        limits: queryTermLimits(maximumResultCount: Int.max, maximumProximityDistance: Int.max))

    #expect(result.matches.map { $0.range.text(in: source.text) } == ["uno prova due tre"])
    #expect(!result.isTruncated)
}

@Test("Il motore interroga la generazione persistita senza accesso laterale allo store")
func engineQueriesPersistedProject() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiProjectQueryTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let packageURL = root.appending(path: "Query.glifi", directoryHint: .isDirectory)
    let project = try GlifiProjectPackage.create(at: packageURL)
    let first = try imported("Una casa sul mare.")
    let second = try imported("La casa in città.")
    _ = try await project.importText(
        first,
        sourceID: SourceID(
            uuid: try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000001"))
        )
    )
    _ = try await project.importText(
        second,
        sourceID: SourceID(
            uuid: try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
        )
    )

    let result = try await GlifiEngine().query("normalized:casa", in: project)
    #expect(result.generation == 2)
    #expect(result.matchedSourceCount == 2)
    #expect(result.matches.count == 2)
    #expect(result.matches.allSatisfy { $0.match.lowercased() == "casa" })
    #expect(result.matches.map(\.sourceRevisionID.canonicalValue).isSorted)
}

@Test("La query Markdown conserva coordinate estratte e intervalli della fonte")
func engineQueriesMarkdownWithSourceLineage() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiMarkdownQueryTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let packageURL = root.appending(path: "Markdown.glifi", directoryHint: .isDirectory)
    let project = try GlifiProjectPackage.create(at: packageURL)
    let source = "Una **casa sul** [mare](destinazione)."
    let imported = try GlifiTextImporter().importText(
        from: Data(source.utf8),
        format: .markdown
    )
    _ = try await project.importText(imported)

    let result = try await GlifiEngine().query("\"casa sul mare\"", in: project)
    let match = try #require(result.matches.first)
    let reconstructed = match.sourceRanges.compactMap { range in
        String(data: imported.bytes[range.start..<range.end], encoding: .utf8)
    }.joined()

    #expect(match.match == "casa sul mare")
    #expect(match.range.text(in: imported.text) == "casa sul mare")
    #expect(match.sourceRanges.count == 3)
    #expect(reconstructed == "casa sul mare")
}

private func queryTermUnicodeFixture() throws -> (
    source: GlifiImportedText, tokenization: GlifiTokenization, ranges: [GlifiUTF8Range]
) {
    let source = try imported("È è E\u{0300} CITTÀ città CITTA\u{0300} naïve NAÏVE prova.")
    let tokenization = try GlifiItalianTokenizer().tokenize(source.text)
    let ranges = try [
        (0, 2), (3, 5), (6, 9), (10, 16), (17, 23),
        (24, 31), (32, 38), (39, 45), (46, 51), (51, 52),
    ].map { try GlifiUTF8Range(start: $0.0, end: $0.1) }
    #expect(tokenization.tokens.map(\.range) == ranges)
    return (source, tokenization, ranges)
}

private func queryTermExpectedMatches(
    _ indices: [Int], ranges: [GlifiUTF8Range], sourceRevisionID: SourceRevisionID
) -> [GlifiQueryMatch] {
    indices.map { index in
        GlifiQueryMatch(
            sourceRevisionID: sourceRevisionID,
            range: ranges[index],
            leftContextRange: index > 0 ? ranges[index - 1] : nil,
            rightContextRange: index + 1 < ranges.count ? ranges[index + 1] : nil)
    }
}

private func queryTermLimits(
    maximumResultCount: Int,
    maximumProximityDistance: Int = GlifiQueryLimits.standard.maximumProximityDistance,
    contextTokenCount: Int = 1,
    maximumIntermediateAnchorCount: Int = 100_000,
    maximumEvaluationStepCount: Int = 1_000_000,
    maximumQueryByteCount: Int = GlifiQueryLimits.standard.maximumQueryByteCount
) -> GlifiQueryLimits {
    let standard = GlifiQueryLimits.standard
    return GlifiQueryLimits(
        maximumQueryByteCount: maximumQueryByteCount,
        maximumDepth: standard.maximumDepth,
        maximumNodeCount: standard.maximumNodeCount,
        maximumPhraseTokenCount: standard.maximumPhraseTokenCount,
        maximumProximityDistance: maximumProximityDistance,
        maximumRegexByteCount: standard.maximumRegexByteCount,
        maximumRegexInputByteCount: standard.maximumRegexInputByteCount,
        maximumSourceCount: standard.maximumSourceCount,
        maximumScannedByteCount: standard.maximumScannedByteCount,
        maximumResultCount: maximumResultCount,
        contextTokenCount: contextTokenCount,
        maximumIntermediateAnchorCount: maximumIntermediateAnchorCount,
        maximumEvaluationStepCount: maximumEvaluationStepCount)
}

private func imported(_ text: String) throws -> GlifiImportedText {
    try GlifiTextImporter().importText(from: Data(text.utf8), format: .plainText)
}

private extension Collection where Element: Comparable {
    var isSorted: Bool {
        zip(self, dropFirst()).allSatisfy(<=)
    }
}
