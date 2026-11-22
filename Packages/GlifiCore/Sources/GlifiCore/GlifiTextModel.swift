// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Text formats admitted by the first ingestion boundary.
public enum GlifiTextFormat: String, Codable, Hashable, Sendable {
    case plainText
    case markdown
}

/// Bounded limits applied before decoding source bytes.
public struct GlifiTextImportLimits: Equatable, Sendable {
    /// Conservative maximum for the first bounded in-memory slice.
    public static let standard = GlifiTextImportLimits(maximumByteCount: 64 * 1_024 * 1_024)

    /// Maximum number of source bytes accepted before decoding.
    public let maximumByteCount: Int

    /// Creates a non-negative byte limit.
    public init(maximumByteCount: Int) {
        self.maximumByteCount = max(0, maximumByteCount)
    }
}

/// A validated immutable source snapshot for the initial text pipeline.
public struct GlifiImportedText: Equatable, Sendable {
    /// Identity of the immutable source snapshot.
    public let sourceRevisionID: SourceRevisionID
    /// Validated declared format.
    public let format: GlifiTextFormat
    /// Original bytes, including a byte-order mark when present.
    public let bytes: Data
    /// Deterministically extracted UTF-8 text used by linguistic and query operations.
    public let text: String
    /// Versioned extraction contract used to produce `text`.
    public let extractionContractIdentifier: String
    /// Total mapping from extracted UTF-8 positions back to immutable source bytes.
    public let spanMap: GlifiSpanMap
    /// SHA-256 digest of the original bytes.
    public let contentDigest: String
    /// Whether the original bytes began with the UTF-8 byte-order mark.
    public let hadByteOrderMark: Bool

    init(
        sourceRevisionID: SourceRevisionID,
        format: GlifiTextFormat,
        bytes: Data,
        text: String,
        extractionContractIdentifier: String,
        spanMap: GlifiSpanMap,
        contentDigest: String,
        hadByteOrderMark: Bool
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.format = format
        self.bytes = bytes
        self.text = text
        self.extractionContractIdentifier = extractionContractIdentifier
        self.spanMap = spanMap
        self.contentDigest = contentDigest
        self.hadByteOrderMark = hadByteOrderMark
    }
}

/// Validates bounded UTF-8 input without guessing or lossy replacement.
public struct GlifiTextImporter: Sendable {
    /// Creates a stateless strict text importer.
    public init() {}

    /// Validates, identifies, and decodes one bounded immutable text snapshot.
    public func importText(
        from data: Data,
        format: GlifiTextFormat,
        limits: GlifiTextImportLimits = .standard,
        sourceRevisionID: SourceRevisionID = SourceRevisionID()
    ) throws -> GlifiImportedText {
        guard data.count <= limits.maximumByteCount else {
            throw GlifiFailure(
                code: "text.byte-limit-exceeded",
                category: .insufficientResources,
                operation: .importText,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.text.byte-limit-exceeded",
                arguments: ["maximumByteCount": String(limits.maximumByteCount)]
            )
        }

        let byteOrderMark = Data([0xEF, 0xBB, 0xBF])
        let hadByteOrderMark = data.starts(with: byteOrderMark)
        let payload = hadByteOrderMark ? data.dropFirst(byteOrderMark.count) : data[...]

        // Decodifica stretta: `String(data:encoding:)` rimuoverebbe un secondo BOM in silenzio.
        guard let sourceText = String(validating: payload, as: UTF8.self) else {
            throw GlifiFailure(
                code: "text.invalid-utf8",
                category: .invalidInput,
                operation: .importText,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.text.invalid-utf8"
            )
        }

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let sourceByteOffset = hadByteOrderMark ? byteOrderMark.count : 0
        let extraction: GlifiExtractedText
        switch format {
        case .plainText:
            let segments: [GlifiSpanMapSegment]
            if payload.isEmpty {
                segments = []
            } else {
                segments = [
                    GlifiSpanMapSegment(
                        outputRange: try GlifiUTF8Range(start: 0, end: payload.count),
                        inputRanges: [
                            try GlifiUTF8Range(
                                start: sourceByteOffset,
                                end: sourceByteOffset + payload.count
                            )
                        ],
                        kind: .exact
                    )
                ]
            }
            extraction = GlifiExtractedText(
                text: sourceText,
                spanMap: try GlifiSpanMap(
                    contractIdentifier: "plain-text-v1",
                    sourceRevisionID: sourceRevisionID,
                    inputByteCount: data.count,
                    outputByteCount: payload.count,
                    segments: segments
                )
            )
        case .markdown:
            extraction = try GlifiMarkdownExtractor().extract(
                sourceText,
                sourceRevisionID: sourceRevisionID,
                sourceByteOffset: sourceByteOffset,
                sourceByteCount: data.count
            )
        }
        return GlifiImportedText(
            sourceRevisionID: sourceRevisionID,
            format: format,
            bytes: data,
            text: extraction.text,
            extractionContractIdentifier: extraction.spanMap.contractIdentifier,
            spanMap: extraction.spanMap,
            contentDigest: "sha256:\(digest)",
            hadByteOrderMark: hadByteOrderMark
        )
    }
}

/// A half-open byte interval in a declared UTF-8 representation.
public struct GlifiUTF8Range: Codable, Hashable, Sendable {
    /// Inclusive UTF-8 byte offset.
    public let start: Int
    /// Exclusive UTF-8 byte offset.
    public let end: Int

    /// Creates a non-empty half-open UTF-8 range.
    public init(start: Int, end: Int) throws {
        guard start >= 0, end > start else {
            throw GlifiFailure(
                code: "text.invalid-range",
                category: .invalidInput,
                operation: .tokenize,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.text.invalid-range"
            )
        }
        self.start = start
        self.end = end
    }

    /// Number of bytes covered by the range.
    public var count: Int {
        end - start
    }

    /// Resolves the interval only when both bounds are valid UTF-8 boundaries.
    public func text(in source: String) -> String? {
        let bytes = source.utf8
        guard end <= bytes.count,
            let lowerBound = bytes.index(
                bytes.startIndex,
                offsetBy: start,
                limitedBy: bytes.endIndex
            ),
            let upperBound = bytes.index(
                lowerBound,
                offsetBy: count,
                limitedBy: bytes.endIndex
            )
        else {
            return nil
        }

        return String(bytes: bytes[lowerBound..<upperBound], encoding: .utf8)
    }
}

/// Stable classes emitted by `it-token-v1`.
public enum GlifiTokenKind: String, Codable, CaseIterable, Sendable {
    case word
    case abbreviation
    case number
    case currency
    case emoji
    case email
    case url
    case hashtag
    case mention
    case punctuation

    var contributesToLexicalStatistics: Bool {
        self != .punctuation && self != .currency
    }
}

/// A component of a surface token, expressed in the same coordinate space.
public struct GlifiTokenComponent: Codable, Equatable, Sendable {
    /// Exact source interval of the component.
    public let range: GlifiUTF8Range

    /// Creates a component at an already validated interval.
    public init(range: GlifiUTF8Range) {
        self.range = range
    }
}

/// A token retaining position without storing a duplicate of its source surface.
public struct GlifiSurfaceToken: Codable, Equatable, Sendable {
    /// Exact source interval of the surface token.
    public let range: GlifiUTF8Range
    /// Stable semantic class of the token.
    public let kind: GlifiTokenKind
    /// Optional, ordered linguistic components within the token.
    public let components: [GlifiTokenComponent]

    /// Creates a surface token from validated positional data.
    public init(
        range: GlifiUTF8Range,
        kind: GlifiTokenKind,
        components: [GlifiTokenComponent] = []
    ) {
        self.range = range
        self.kind = kind
        self.components = components
    }
}

/// A sentence interval in the source UTF-8 coordinate space.
public struct GlifiSentence: Codable, Equatable, Sendable {
    /// Exact source interval of the sentence.
    public let range: GlifiUTF8Range

    /// Creates a sentence from a validated interval.
    public init(range: GlifiUTF8Range) {
        self.range = range
    }
}

/// Immutable output of one versioned tokenization pass.
public struct GlifiTokenization: Equatable, Sendable {
    /// Versioned linguistic contract used for the output.
    public let contractIdentifier: String
    /// Language and locale applied by the tokenizer.
    public let languageConfiguration: GlifiLanguageConfiguration
    /// Total length of the referenced source coordinate space.
    public let sourceUTF8Length: Int
    /// Ordered, non-overlapping surface tokens.
    public let tokens: [GlifiSurfaceToken]
    /// Ordered, non-overlapping sentence intervals.
    public let sentences: [GlifiSentence]

    /// Creates an immutable tokenization result.
    public init(
        contractIdentifier: String,
        languageConfiguration: GlifiLanguageConfiguration,
        sourceUTF8Length: Int,
        tokens: [GlifiSurfaceToken],
        sentences: [GlifiSentence]
    ) {
        self.contractIdentifier = contractIdentifier
        self.languageConfiguration = languageConfiguration
        self.sourceUTF8Length = sourceUTF8Length
        self.tokens = tokens
        self.sentences = sentences
    }
}

/// Substitution point for deterministic linguistic tokenizers.
public protocol GlifiTokenizing: Sendable {
    /// Stable contract identity used to plan reusable analytical nodes.
    var tokenizationContractIdentifier: String { get }
    /// Tokenizes a valid Swift string while preserving exact UTF-8 source offsets.
    func tokenize(_ text: String) throws -> GlifiTokenization
}
