// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One normalized term and its exact frequency in a text snapshot.
public struct GlifiTermFrequency: Equatable, Sendable {
    /// NFC, locale-aware lowercase term used as the frequency key.
    public let term: String
    /// Exact number of occurrences.
    public let count: Int

    /// Creates an immutable frequency row.
    public init(term: String, count: Int) {
        self.term = term
        self.count = count
    }
}

/// Deterministic descriptive profile for one imported text snapshot.
public struct GlifiTextProfile: Equatable, Sendable {
    /// Source revision from which the profile was derived.
    public let sourceRevisionID: SourceRevisionID
    /// Digest of the exact imported source bytes.
    public let contentDigest: String
    /// Declared and validated source format.
    public let format: GlifiTextFormat
    /// Size of the decoded text coordinate space in UTF-8 bytes.
    public let utf8ByteCount: Int
    /// Number of extended grapheme clusters.
    public let characterCount: Int
    /// Number of sentence intervals.
    public let sentenceCount: Int
    /// Number of all surface tokens, including punctuation.
    public let surfaceTokenCount: Int
    /// Number of tokens admitted to lexical statistics.
    public let lexicalTokenCount: Int
    /// Number of distinct normalized lexical forms.
    public let typeCount: Int
    /// Complete, deterministically ordered lexical frequencies.
    public let frequencies: [GlifiTermFrequency]
    /// Positional tokenization from which the counts were derived.
    public let tokenization: GlifiTokenization

    /// Creates an immutable descriptive profile with explicit lineage.
    public init(
        sourceRevisionID: SourceRevisionID,
        contentDigest: String,
        format: GlifiTextFormat,
        utf8ByteCount: Int,
        characterCount: Int,
        sentenceCount: Int,
        surfaceTokenCount: Int,
        lexicalTokenCount: Int,
        typeCount: Int,
        frequencies: [GlifiTermFrequency],
        tokenization: GlifiTokenization
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.contentDigest = contentDigest
        self.format = format
        self.utf8ByteCount = utf8ByteCount
        self.characterCount = characterCount
        self.sentenceCount = sentenceCount
        self.surfaceTokenCount = surfaceTokenCount
        self.lexicalTokenCount = lexicalTokenCount
        self.typeCount = typeCount
        self.frequencies = frequencies
        self.tokenization = tokenization
    }
}

/// Runs the first bounded, presentation-independent Italian text profile.
public struct GlifiTextAnalyzer: Sendable {
    private let tokenizer: any GlifiTokenizing

    /// Creates an analyzer with an injectable linguistic implementation.
    public init(tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()) {
        self.tokenizer = tokenizer
    }

    /// Computes deterministic descriptive counts and lexical frequencies.
    public func profile(_ importedText: GlifiImportedText) throws -> GlifiTextProfile {
        let tokenization = try tokenizer.tokenize(importedText.text)
        var counts: [String: Int] = [:]
        var lexicalTokenCount = 0
        let locale = Locale(identifier: "it_IT")

        for (index, token) in tokenization.tokens.enumerated() {
            if index.isMultiple(of: 4_096) {
                try Task.checkCancellation()
            }
            guard token.kind.contributesToLexicalStatistics,
                let surface = token.range.text(in: importedText.text)
            else {
                continue
            }

            lexicalTokenCount += 1
            let normalized = surface.precomposedStringWithCanonicalMapping.lowercased(with: locale)
            counts[normalized, default: 0] += 1
        }

        let frequencies = counts.map(GlifiTermFrequency.init(term:count:)).sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.term < $1.term
        }

        return GlifiTextProfile(
            sourceRevisionID: importedText.sourceRevisionID,
            contentDigest: importedText.contentDigest,
            format: importedText.format,
            utf8ByteCount: importedText.text.utf8.count,
            characterCount: importedText.text.count,
            sentenceCount: tokenization.sentences.count,
            surfaceTokenCount: tokenization.tokens.count,
            lexicalTokenCount: lexicalTokenCount,
            typeCount: counts.count,
            frequencies: frequencies,
            tokenization: tokenization
        )
    }
}
