// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Deterministic tokenizer implementing the bounded `it-token-v1` baseline.
public struct GlifiItalianTokenizer: GlifiTokenizing {
    /// Stable version of the linguistic contract implemented by this tokenizer.
    public static let contractIdentifier = "it-token-v1"

    /// Stable contract identity exposed through the tokenizer abstraction.
    public var tokenizationContractIdentifier: String { Self.contractIdentifier }

    private static let abbreviations: Set<String> = [
        "dott", "dr", "ecc", "ing", "prof", "sig", "sigg", "sigra",
    ]
    private static let trailingApostropheWords: Set<String> = ["be", "fa", "mo", "po", "sta", "va"]
    private static let maximumEmailCharacterCount = 320
    private static let maximumURLCharacterCount = 2_048

    /// Creates a stateless Italian tokenizer.
    public init() {}

    /// Produces deterministic surface tokens and sentence intervals.
    public func tokenize(_ text: String) throws -> GlifiTokenization {
        let clusters = try clusters(in: text)
        var tokens: [GlifiSurfaceToken] = []
        tokens.reserveCapacity(min(clusters.count, 4_096))
        var index = 0
        var specialRunEnd = -1
        var specialTrimmedEnd = -1

        while index < clusters.count {
            if index.isMultiple(of: 4_096) {
                try Task.checkCancellation()
            }

            let cluster = clusters[index]
            if cluster.isWhitespace {
                index += 1
                continue
            }

            if index > specialRunEnd {
                let bounds = try specialTokenBounds(startingAt: index, clusters: clusters)
                specialRunEnd = bounds.end
                specialTrimmedEnd = bounds.trimmedEnd
            }
            if let special = specialToken(
                startingAt: index, candidateEnd: max(index, specialTrimmedEnd),
                clusters: clusters, text: text)
            {
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

    private func clusters(in text: String) throws -> [Cluster] {
        if !text.isEmpty { try Task.checkCancellation() }
        var result: [Cluster] = []
        result.reserveCapacity(min(text.count, 4_096))
        var offset = 0
        for character in text {
            if result.count.isMultiple(of: 4_096) { try Task.checkCancellation() }
            let byteCount = String(character).utf8.count
            result.append(Cluster(character: character, start: offset, end: offset + byteCount))
            offset += byteCount
        }
        return result
    }

    /// Resolves the shared suffix bounds once for each run without whitespace.
    private func specialTokenBounds(
        startingAt start: Int,
        clusters: [Cluster]
    ) throws -> (end: Int, trimmedEnd: Int) {
        var end = start
        while end + 1 < clusters.count, !clusters[end + 1].isWhitespace {
            if end.isMultiple(of: 4_096) { try Task.checkCancellation() }
            end += 1
        }

        var trimmedEnd = end
        while trimmedEnd > start, clusters[trimmedEnd].isTerminalDelimiter {
            if trimmedEnd.isMultiple(of: 4_096) { try Task.checkCancellation() }
            trimmedEnd -= 1
        }
        return (end, trimmedEnd)
    }

    private func specialToken(
        startingAt start: Int,
        candidateEnd: Int,
        clusters: [Cluster],
        text: String
    ) -> (start: Cluster, end: Int, kind: GlifiTokenKind)? {
        // Cluster distance counts Characters after trimming, matching both existing limits.
        guard
            candidateEnd - start + 1
                <= max(Self.maximumEmailCharacterCount, Self.maximumURLCharacterCount)
        else { return nil }
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
        clusters: [Cluster],
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

    private func numberEnd(startingAt start: Int, clusters: [Cluster]) -> Int {
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

    private func taggedTokenEnd(startingAt start: Int, clusters: [Cluster]) -> Int {
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
        clusters: [Cluster]
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
        from start: Cluster,
        through end: Cluster,
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
        guard candidate.count <= Self.maximumEmailCharacterCount,
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
        guard candidate.count <= Self.maximumURLCharacterCount,
            let components = URLComponents(string: candidate),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return false
        }
        return components.host?.isEmpty == false
    }
}

private struct Cluster {
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
