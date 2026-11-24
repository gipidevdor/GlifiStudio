// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("Il tokenizer conserva l'output legacy e misura soltanto workload espliciti")
func pipelineOptimizationTokenizer() throws {
    let benchmarkEnabled =
        ProcessInfo.processInfo.environment[
            "GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil
    let workloads: [(identifier: String, generator: String, text: String)]
    if benchmarkEnabled {
        workloads =
            [1_000, 4_000, 8_000].map { count in
                (
                    "tokenizer-punctuation-\(count)",
                    "semicolon repeated \(count) times without whitespace; full tokenizer including preparation",
                    String(repeating: ";", count: count)
                )
            } + [
                (
                    "tokenizer-unicode-prose-control",
                    "fixed Italian Unicode prose, 128 repetitions; full tokenizer including preparation",
                    String(
                        repeating: "L'acqua è già qui. Citta\u{0300}, dott. Rossi e 👨‍👩‍👧: perché?\n",
                        count: 128)
                ),
                (
                    "tokenizer-email-url-control",
                    "fixed legacy email and URL forms, 128 repetitions; full tokenizer including preparation",
                    String(
                        repeating:
                            "(!nome@esempio.it; 🙂utente@dominio.it, HTTPS://example.org/a?x=1; fine.\t",
                        count: 128)
                ),
            ]
    } else {
        workloads = [
            (
                "tokenizer-punctuation-smoke", "64 semicolons without whitespace",
                String(repeating: ";", count: 64)
            ),
            (
                "tokenizer-unicode-smoke", "fixed Italian Unicode and legacy special forms",
                "L'acqua è già qui. Citta\u{0300}; 🙂utente@dominio.it e HTTPS://example.org/a?x=1."
            ),
        ]
    }
    for workload in workloads {
        let expected = try LegacyOptimizationItalianTokenizer().tokenize(workload.text)
        let observed = try GlifiItalianTokenizer().tokenize(workload.text)
        #expect(observed == expected, Comment(rawValue: workload.identifier))
        try measurePipelineOptimization(
            identifier: workload.identifier,
            generator: workload.generator,
            fixtureDigest: pipelineBenchmarkDigest(Data(workload.text.utf8)),
            expected: expected,
            body: { try GlifiItalianTokenizer().tokenize(workload.text) },
            checksum: tokenizerOptimizationDigest
        )
    }
}

@Test("Punteggiatura, email e URL preservano tutti i limiti e i suffissi legacy")
func tokenizerOptimizationPreservesLegacySpecialBoundaries() throws {
    let urlPrefix = "https://example.org/"
    let inputs = [
        "", " \t\r\n", ";", ".,;:!?", "alpha.,;:!?beta", "alpha,beta;gamma:delta?epsilon!zeta.",
        "(!nome@esempio.it;,", "🙂utente@dominio.it!", "e\u{0301}.nome@dominio.it",
        "nome@città.it.", "a@b.it,resto", "a@b.it#alt@dominio.it", "a@@b.it",
        "HTTPS://example.org/a?x=1,,", "(https://example.org/a)", "!https://example.org/a",
        "prima\u{00A0}https://example.org/a\u{202F}dopo", "prima\u{200B}nome@dominio.it",
        "👨‍👩‍👧@dominio.it", "a\u{0300}@b.it;:!?", "€nome@esempio.it", "#nome@esempio.it",
        String(repeating: "a", count: 315) + "@b.it",
        String(repeating: "a", count: 316) + "@b.it",
        urlPrefix + String(repeating: "x", count: 2_048 - urlPrefix.count),
        urlPrefix + String(repeating: "x", count: 2_049 - urlPrefix.count),
        urlPrefix + String(repeating: "e\u{0301}", count: 2_048 - urlPrefix.count),
        String(repeating: ";", count: 2_049) + "nome@dominio.it,",
        "nome@dominio.it" + String(repeating: ";", count: 2_049),
        "http://example.org/" + String(repeating: "👨‍👩‍👧", count: 64) + ";!?",
    ]
    for (index, text) in inputs.enumerated() {
        #expect(
            try GlifiItalianTokenizer().tokenize(text)
                == LegacyOptimizationItalianTokenizer().tokenize(text),
            Comment(rawValue: "legacy boundary case \(index)"))
    }
}

@Test("Il fuzz a seed fisso conserva token, frasi e componenti del tokenizer legacy")
func tokenizerOptimizationPreservesLegacySeededInputs() throws {
    let fragments = [
        "a", "Città", "e\u{0301}", "l'acqua", "dell’arte", "po'", "dott.", "12,50", "€",
        "🙂", "👨‍👩‍👧", "@", ".", ",", ";", ":", "!", "?", "(", ")", "[", "]", "#",
        " ", "\t", "\n", "\r\n", "\u{00A0}", "\u{202F}", "\u{200B}",
        "nome@dominio.it", "https://example.org/a", "HTTPS://x.it/", "/", "-", "_",
    ]
    var random = GlifiSplitMix64(seed: 0x2035_EED1)
    for index in 0..<256 {
        var text = ""
        for _ in 0..<Int(random.next() % 32) {
            text += fragments[Int(random.next() % UInt64(fragments.count))]
        }
        #expect(
            try GlifiItalianTokenizer().tokenize(text)
                == LegacyOptimizationItalianTokenizer().tokenize(text),
            Comment(rawValue: "legacy fuzz seed 0x2035EED1, case \(index)"))
    }
}

@Test("La cancellazione già richiesta conserva l'esito del tokenizer legacy")
func tokenizerOptimizationPreservesCancellation() async throws {
    let text = String(repeating: ";", count: 100_000)
    let current = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiItalianTokenizer().tokenize(text)
    }
    let legacy = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try LegacyOptimizationItalianTokenizer().tokenize(text)
    }
    for task in [current, legacy] {
        do {
            _ = try await task.value
            Issue.record("A tokenizer ignored an already requested cancellation")
        } catch is CancellationError {
            // The low-level tokenizer preserves cooperative cancellation for its caller.
        }
    }
}

private struct TokenizerOptimizationFingerprint: Encodable {
    let contractIdentifier: String
    let languageCode: String
    let localeIdentifier: String
    let sourceUTF8Length: Int
    let tokens: [GlifiSurfaceToken]
    let sentences: [GlifiSentence]
}

private func tokenizerOptimizationDigest(_ result: GlifiTokenization) throws -> String {
    try pipelineBenchmarkDigest(
        TokenizerOptimizationFingerprint(
            contractIdentifier: result.contractIdentifier,
            languageCode: result.languageConfiguration.languageCode,
            localeIdentifier: result.languageConfiguration.localeIdentifier,
            sourceUTF8Length: result.sourceUTF8Length, tokens: result.tokens,
            sentences: result.sentences))
}

// Frozen equivalence reference copied before GS-DOR-203 product changes.
// Original GlifiItalianTokenizer.swift SHA-256:
// bb054f7f60b69bd75f84de0172ee473936d7eb77a37083a11c618cd2b0c67d83
// This is an implementation-equivalence reference, not an independent linguistic oracle.

/// Deterministic tokenizer implementing the bounded `it-token-v1` baseline.
private struct LegacyOptimizationItalianTokenizer: GlifiTokenizing {
    /// Stable version of the linguistic contract implemented by this tokenizer.
    static let contractIdentifier = "it-token-v1"

    /// Stable contract identity exposed through the tokenizer abstraction.
    var tokenizationContractIdentifier: String { Self.contractIdentifier }

    private static let abbreviations: Set<String> = [
        "dott", "dr", "ecc", "ing", "prof", "sig", "sigg", "sigra",
    ]
    private static let trailingApostropheWords: Set<String> = ["be", "fa", "mo", "po", "sta", "va"]

    /// Creates a stateless Italian tokenizer.
    init() {}

    /// Produces deterministic surface tokens and sentence intervals.
    func tokenize(_ text: String) throws -> GlifiTokenization {
        let clusters = clusters(in: text)
        var tokens: [GlifiSurfaceToken] = []
        tokens.reserveCapacity(min(clusters.count, 4_096))
        var index = 0

        while index < clusters.count {
            if index.isMultiple(of: 4_096) {
                try Task.checkCancellation()
            }

            let cluster = clusters[index]
            if cluster.isWhitespace {
                index += 1
                continue
            }

            if let special = specialToken(startingAt: index, clusters: clusters, text: text) {
                tokens.append(
                    try token(
                        from: special.start,
                        through: clusters[special.end],
                        kind: special.kind
                    )
                )
                index = special.end + 1
                continue
            }

            if cluster.character == "#" || cluster.character == "@",
                index + 1 < clusters.count,
                clusters[index + 1].isWordBase || clusters[index + 1].isDigit
            {
                let end = taggedTokenEnd(startingAt: index, clusters: clusters)
                tokens.append(
                    try token(
                        from: cluster,
                        through: clusters[end],
                        kind: cluster.character == "#" ? .hashtag : .mention
                    )
                )
                index = end + 1
                continue
            }

            if cluster.isWordBase {
                let result = wordToken(startingAt: index, clusters: clusters, text: text)
                tokens.append(
                    try token(
                        from: index,
                        through: result.end,
                        kind: result.kind,
                        apostropheIndex: result.apostropheIndex,
                        clusters: clusters
                    )
                )
                index = result.end + 1
                continue
            }

            if cluster.isDigit {
                let end = numberEnd(startingAt: index, clusters: clusters)
                tokens.append(
                    try token(from: clusters[index], through: clusters[end], kind: .number))
                index = end + 1
                continue
            }

            let kind: GlifiTokenKind
            if cluster.isCurrency {
                kind = .currency
            } else if cluster.isEmoji {
                kind = .emoji
            } else {
                kind = .punctuation
            }
            tokens.append(try token(from: cluster, through: cluster, kind: kind))
            index += 1
        }

        return GlifiTokenization(
            contractIdentifier: Self.contractIdentifier,
            languageConfiguration: .italian,
            sourceUTF8Length: text.utf8.count,
            tokens: tokens,
            sentences: try sentenceRanges(tokens: tokens, text: text)
        )
    }

    private func clusters(in text: String) -> [LegacyOptimizationCluster] {
        var result: [LegacyOptimizationCluster] = []
        result.reserveCapacity(min(text.count, 4_096))
        var offset = 0
        for character in text {
            let byteCount = String(character).utf8.count
            result.append(
                LegacyOptimizationCluster(
                    character: character, start: offset, end: offset + byteCount))
            offset += byteCount
        }
        return result
    }

    private func specialToken(
        startingAt start: Int,
        clusters: [LegacyOptimizationCluster],
        text: String
    ) -> (start: LegacyOptimizationCluster, end: Int, kind: GlifiTokenKind)? {
        var end = start
        while end + 1 < clusters.count, !clusters[end + 1].isWhitespace {
            end += 1
        }

        var candidateEnd = end
        while candidateEnd > start, clusters[candidateEnd].isTerminalDelimiter {
            candidateEnd -= 1
        }
        guard
            let candidate = try? GlifiUTF8Range(
                start: clusters[start].start,
                end: clusters[candidateEnd].end
            ).text(in: text)
        else {
            return nil
        }

        if isEmail(candidate) {
            return (clusters[start], candidateEnd, .email)
        }
        if isURL(candidate) {
            return (clusters[start], candidateEnd, .url)
        }
        return nil
    }

    private func wordToken(
        startingAt start: Int,
        clusters: [LegacyOptimizationCluster],
        text: String
    ) -> (end: Int, kind: GlifiTokenKind, apostropheIndex: Int?) {
        var end = start
        var apostropheIndex: Int?

        while end + 1 < clusters.count {
            let next = clusters[end + 1]
            if next.isWordBase || next.isDigit {
                end += 1
                continue
            }
            if next.isInternalConnector,
                end + 2 < clusters.count,
                clusters[end + 2].isWordBase || clusters[end + 2].isDigit
            {
                if next.isApostrophe, apostropheIndex == nil {
                    apostropheIndex = end + 1
                }
                end += 2
                continue
            }
            break
        }

        let range = try? GlifiUTF8Range(start: clusters[start].start, end: clusters[end].end)
        let word = range?.text(in: text)?.precomposedStringWithCanonicalMapping.lowercased()

        if end + 1 < clusters.count,
            clusters[end + 1].character == ".",
            let word,
            Self.abbreviations.contains(word)
        {
            return (end + 1, .abbreviation, apostropheIndex)
        }

        if end + 1 < clusters.count,
            clusters[end + 1].isApostrophe,
            let word,
            Self.trailingApostropheWords.contains(word)
        {
            return (end + 1, .word, nil)
        }

        return (end, .word, apostropheIndex)
    }

    private func numberEnd(startingAt start: Int, clusters: [LegacyOptimizationCluster]) -> Int {
        var end = start
        while end + 1 < clusters.count {
            if clusters[end + 1].isDigit {
                end += 1
                continue
            }
            if clusters[end + 1].isDecimalSeparator,
                end + 2 < clusters.count,
                clusters[end + 2].isDigit
            {
                end += 2
                continue
            }
            break
        }
        return end
    }

    private func taggedTokenEnd(startingAt start: Int, clusters: [LegacyOptimizationCluster]) -> Int
    {
        var end = start + 1
        while end + 1 < clusters.count {
            let next = clusters[end + 1]
            guard next.isWordBase || next.isDigit || next.character == "_" else {
                break
            }
            end += 1
        }
        return end
    }

    private func token(
        from start: Int,
        through end: Int,
        kind: GlifiTokenKind,
        apostropheIndex: Int? = nil,
        clusters: [LegacyOptimizationCluster]
    ) throws -> GlifiSurfaceToken {
        let first = clusters[start]
        let last = clusters[end]
        var components: [GlifiTokenComponent] = []
        if let apostropheIndex {
            components = [
                GlifiTokenComponent(
                    range: try GlifiUTF8Range(
                        start: first.start,
                        end: clusters[apostropheIndex].end
                    )
                ),
                GlifiTokenComponent(
                    range: try GlifiUTF8Range(
                        start: clusters[apostropheIndex].end,
                        end: last.end
                    )
                ),
            ]
        }
        return GlifiSurfaceToken(
            range: try GlifiUTF8Range(start: first.start, end: last.end),
            kind: kind,
            components: components
        )
    }

    private func token(
        from start: LegacyOptimizationCluster,
        through end: LegacyOptimizationCluster,
        kind: GlifiTokenKind
    ) throws -> GlifiSurfaceToken {
        GlifiSurfaceToken(
            range: try GlifiUTF8Range(start: start.start, end: end.end),
            kind: kind
        )
    }

    private func sentenceRanges(
        tokens: [GlifiSurfaceToken],
        text: String
    ) throws -> [GlifiSentence] {
        guard let first = tokens.first else {
            return []
        }

        var sentences: [GlifiSentence] = []
        var sentenceStart = first.range.start
        var previousEnd = first.range.end
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if index > 0,
                sentenceStart < previousEnd,
                gapContainsNewline(from: previousEnd, to: token.range.start, in: text)
            {
                sentences.append(
                    GlifiSentence(range: try GlifiUTF8Range(start: sentenceStart, end: previousEnd))
                )
                sentenceStart = token.range.start
            }

            previousEnd = token.range.end
            guard token.kind == .punctuation,
                let surface = token.range.text(in: text),
                surface == "." || surface == "!" || surface == "?"
            else {
                index += 1
                continue
            }

            var sentenceEnd = token.range.end
            while index + 1 < tokens.count,
                tokens[index + 1].range.start == sentenceEnd,
                isSentenceClosingPunctuation(tokens[index + 1], in: text)
            {
                index += 1
                sentenceEnd = tokens[index].range.end
            }
            sentences.append(
                GlifiSentence(range: try GlifiUTF8Range(start: sentenceStart, end: sentenceEnd))
            )
            if index + 1 < tokens.count {
                sentenceStart = tokens[index + 1].range.start
            }
            previousEnd = sentenceEnd
            index += 1
        }

        if sentences.last?.range.end != previousEnd {
            sentences.append(
                GlifiSentence(range: try GlifiUTF8Range(start: sentenceStart, end: previousEnd))
            )
        }
        return sentences
    }

    private func isSentenceClosingPunctuation(
        _ token: GlifiSurfaceToken,
        in text: String
    ) -> Bool {
        guard token.kind == .punctuation, let surface = token.range.text(in: text) else {
            return false
        }
        return [".", "!", "?", "\"", "'", "’", "”", ")", "]", "}"].contains(surface)
    }

    private func gapContainsNewline(from start: Int, to end: Int, in text: String) -> Bool {
        guard end > start,
            let range = try? GlifiUTF8Range(start: start, end: end),
            let gap = range.text(in: text)
        else {
            return false
        }
        return gap.contains("\n") || gap.contains("\r")
    }

    private func isEmail(_ candidate: String) -> Bool {
        guard candidate.count <= 320,
            candidate.filter({ $0 == "@" }).count == 1,
            let separator = candidate.firstIndex(of: "@")
        else {
            return false
        }
        let local = candidate[..<separator]
        let domain = candidate[candidate.index(after: separator)...]
        return !local.isEmpty && domain.contains(".") && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
    }

    private func isURL(_ candidate: String) -> Bool {
        guard candidate.count <= 2_048,
            let components = URLComponents(string: candidate),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return false
        }
        return components.host?.isEmpty == false
    }
}

private struct LegacyOptimizationCluster {
    let character: Character
    let start: Int
    let end: Int

    var isWhitespace: Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    var isWordBase: Bool {
        character.unicodeScalars.contains {
            CharacterSet.letters.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
        }
    }

    var isDigit: Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    var isCurrency: Bool {
        character.unicodeScalars.contains { $0.properties.generalCategory == .currencySymbol }
    }

    var isEmoji: Bool {
        character.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x7F)
        }
    }

    var isApostrophe: Bool {
        character == "'" || character == "’"
    }

    var isInternalConnector: Bool {
        isApostrophe || character == "-"
    }

    var isDecimalSeparator: Bool {
        character == "," || character == "."
    }

    var isTerminalDelimiter: Bool {
        character == "." || character == "," || character == ";" || character == ":"
            || character == "!" || character == "?"
    }
}
