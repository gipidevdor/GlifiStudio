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

private func queryTermLimits(maximumResultCount: Int) -> GlifiQueryLimits {
    let standard = GlifiQueryLimits.standard
    return GlifiQueryLimits(
        maximumQueryByteCount: standard.maximumQueryByteCount,
        maximumDepth: standard.maximumDepth,
        maximumNodeCount: standard.maximumNodeCount,
        maximumPhraseTokenCount: standard.maximumPhraseTokenCount,
        maximumProximityDistance: standard.maximumProximityDistance,
        maximumRegexByteCount: standard.maximumRegexByteCount,
        maximumRegexInputByteCount: standard.maximumRegexInputByteCount,
        maximumSourceCount: standard.maximumSourceCount,
        maximumScannedByteCount: standard.maximumScannedByteCount,
        maximumResultCount: maximumResultCount,
        contextTokenCount: 1)
}

private func imported(_ text: String) throws -> GlifiImportedText {
    try GlifiTextImporter().importText(from: Data(text.utf8), format: .plainText)
}

private extension Collection where Element: Comparable {
    var isSorted: Bool {
        zip(self, dropFirst()).allSatisfy(<=)
    }
}
