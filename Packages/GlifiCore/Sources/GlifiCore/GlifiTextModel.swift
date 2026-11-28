// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Source formats admitted by the bounded ingestion boundary.
public enum GlifiTextFormat: String, Codable, Hashable, Sendable {
    case plainText
    case markdown
    case pdf
    case epub
}

/// Bounded limits applied before decoding source bytes.
public struct GlifiTextImportLimits: Equatable, Sendable {
    /// Conservative maximum for the first bounded in-memory slice.
    public static let standard = GlifiTextImportLimits(maximumByteCount: 64 * 1_024 * 1_024)

    /// Maximum number of source bytes accepted before decoding.
    public let maximumByteCount: Int

    /// Maximum canonical UTF-8 text captured by document importers.
    public let maximumExtractedByteCount: Int
    /// Maximum pages or spine documents admitted before extraction.
    public let maximumDocumentUnitCount: Int
    /// Maximum located text regions retained with the captured representation.
    public let maximumDocumentLocationCount: Int
    /// Maximum PDF pages that may require OCR in one import.
    public let maximumOCRPageCount: Int
    /// Maximum pixels allocated for one OCR page.
    public let maximumOCRPixelCount: Int
    /// Maximum entries admitted from an EPUB ZIP directory.
    public let maximumArchiveEntryCount: Int
    /// Maximum declared expanded archive bytes, cumulatively.
    public let maximumExpandedArchiveByteCount: Int
    /// Maximum expanded bytes for a single ZIP member.
    public let maximumArchiveEntryByteCount: Int

    /// Creates non-negative limits; rich-document ceilings cannot exceed the standard envelope.
    public init(
        maximumByteCount: Int, maximumExtractedByteCount: Int = 16 * 1_024 * 1_024,
        maximumDocumentUnitCount: Int = 2_048, maximumDocumentLocationCount: Int = 100_000,
        maximumOCRPageCount: Int = 128, maximumOCRPixelCount: Int = 4_194_304,
        maximumArchiveEntryCount: Int = 10_000,
        maximumExpandedArchiveByteCount: Int = 128 * 1_024 * 1_024,
        maximumArchiveEntryByteCount: Int = 16 * 1_024 * 1_024
    ) {
        self.maximumByteCount = max(0, maximumByteCount)
        self.maximumExtractedByteCount = min(max(0, maximumExtractedByteCount), 16 * 1_024 * 1_024)
        self.maximumDocumentUnitCount = min(max(0, maximumDocumentUnitCount), 2_048)
        self.maximumDocumentLocationCount = min(max(0, maximumDocumentLocationCount), 100_000)
        self.maximumOCRPageCount = min(max(0, maximumOCRPageCount), 128)
        self.maximumOCRPixelCount = min(max(0, maximumOCRPixelCount), 4_194_304)
        self.maximumArchiveEntryCount = min(max(0, maximumArchiveEntryCount), 10_000)
        self.maximumExpandedArchiveByteCount = min(
            max(0, maximumExpandedArchiveByteCount), 128 * 1_024 * 1_024)
        self.maximumArchiveEntryByteCount = min(
            max(0, maximumArchiveEntryByteCount), 16 * 1_024 * 1_024)
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
    /// Total mapping to UTF-8 source text; binary documents use their captured text representation.
    public let spanMap: GlifiSpanMap
    /// SHA-256 digest of the original bytes.
    public let contentDigest: String
    /// Captured document representation, persisted atomically with binary originals.
    package let documentExtraction: GlifiDocumentExtraction?
    /// Text whose UTF-8 offsets are addressed by the source side of the span map.
    package var sourceRepresentationText: String {
        get throws {
            if let documentExtraction { return documentExtraction.text }
            guard let original = String(validating: bytes, as: UTF8.self) else {
                throw documentImportFailure(
                    "document.invalid-source-representation", category: .corruption)
            }
            return original
        }
    }
    /// Admission charges both original input and the larger captured text representation.
    package var analysisByteCount: Int { max(bytes.count, text.utf8.count) }
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
        hadByteOrderMark: Bool,
        documentExtraction: GlifiDocumentExtraction? = nil
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.format = format
        self.bytes = bytes
        self.text = text
        self.extractionContractIdentifier = extractionContractIdentifier
        self.spanMap = spanMap
        self.contentDigest = contentDigest
        self.hadByteOrderMark = hadByteOrderMark
        self.documentExtraction = documentExtraction
    }
}

/// Imports bounded UTF-8 sources and captures binary document text without lossy decoding.
public struct GlifiTextImporter: Sendable {
    /// Creates a stateless strict text importer.
    public init() {}

    /// Validates and captures one bounded immutable source snapshot.
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

        switch format {
        case .pdf:
            return try restoreDocument(
                from: data, format: format,
                extraction: GlifiPDFExtractor.extract(data, limits: limits),
                limits: limits, sourceRevisionID: sourceRevisionID)
        case .epub:
            return try restoreDocument(
                from: data, format: format,
                extraction: GlifiEPUBExtractor.extract(data, limits: limits),
                limits: limits, sourceRevisionID: sourceRevisionID)
        case .plainText, .markdown:
            break
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
        case .pdf, .epub:
            throw documentImportFailure(
                "document.invalid-text-dispatch", category: .invariantViolation)
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

    /// Rehydrates the committed representation without invoking PDFKit, Vision or XML parsing.
    package func restoreDocument(
        from data: Data, format: GlifiTextFormat, extraction: GlifiDocumentExtraction,
        limits: GlifiTextImportLimits = .standard,
        sourceRevisionID: SourceRevisionID
    ) throws -> GlifiImportedText {
        try Task.checkCancellation()
        guard data.count <= limits.maximumByteCount,
            extraction.text.utf8.count <= limits.maximumExtractedByteCount,
            extraction.locations.count <= limits.maximumDocumentLocationCount,
            let unitCount = extraction.metadata["documentUnitCount"].flatMap(Int.init),
            unitCount <= limits.maximumDocumentUnitCount
        else {
            throw documentImportFailure("document.resource-limit", category: .insufficientResources)
        }
        let validLocations: Bool
        switch format {
        case .pdf:
            validLocations = extraction.locations.allSatisfy {
                $0.pageNumber != nil && ($0.method == "pdf-text" || $0.method == "pdf-ocr")
            }
        case .epub:
            validLocations = extraction.locations.allSatisfy {
                $0.resourcePath != nil && $0.method == "epub-xhtml"
            }
        case .plainText, .markdown:
            validLocations = false
        }
        guard validLocations else { throw documentImportFailure("document.format-mismatch") }
        let count = extraction.text.utf8.count
        let segments: [GlifiSpanMapSegment]
        if count == 0 {
            segments = []
        } else {
            let range = try GlifiUTF8Range(start: 0, end: count)
            segments = [GlifiSpanMapSegment(outputRange: range, inputRanges: [range], kind: .exact)]
        }
        let map = try GlifiSpanMap(
            contractIdentifier: extraction.contractIdentifier, sourceRevisionID: sourceRevisionID,
            inputByteCount: count, outputByteCount: count, segments: segments)
        return GlifiImportedText(
            sourceRevisionID: sourceRevisionID, format: format, bytes: data,
            text: extraction.text, extractionContractIdentifier: extraction.contractIdentifier,
            spanMap: map,
            contentDigest: "sha256:"
                + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            hadByteOrderMark: false, documentExtraction: extraction)
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

    /// Applies the same invariants to serialized ranges as to native construction.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            start: fields.decode(Int.self, forKey: .start),
            end: fields.decode(Int.self, forKey: .end))
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
    /// Explicit prepared lexical representation; absent for the historical surface tokenizer.
    public let analysisForm: String?
    /// Resolved Italian lemma, only when that preparation was explicitly selected.
    public let lemma: String?
    /// Resolved raw Apple grammatical class, only when explicitly requested.
    public let partOfSpeech: String?

    /// Creates a surface token from validated positional data.
    public init(
        range: GlifiUTF8Range,
        kind: GlifiTokenKind,
        components: [GlifiTokenComponent] = [],
        analysisForm: String? = nil,
        lemma: String? = nil,
        partOfSpeech: String? = nil
    ) {
        self.range = range
        self.kind = kind
        self.components = components
        self.analysisForm = analysisForm
        self.lemma = lemma
        self.partOfSpeech = partOfSpeech
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
    /// Linguistic query fields explicitly available under this preparation contract.
    public let availableQueryFields: [GlifiQueryField]

    /// Creates an immutable tokenization result.
    public init(
        contractIdentifier: String,
        languageConfiguration: GlifiLanguageConfiguration,
        sourceUTF8Length: Int,
        tokens: [GlifiSurfaceToken],
        sentences: [GlifiSentence],
        availableQueryFields: [GlifiQueryField] = []
    ) {
        self.contractIdentifier = contractIdentifier
        self.languageConfiguration = languageConfiguration
        self.sourceUTF8Length = sourceUTF8Length
        self.tokens = tokens
        self.sentences = sentences
        self.availableQueryFields = availableQueryFields
    }
}

/// Substitution point for deterministic linguistic tokenizers.
public protocol GlifiTokenizing: Sendable {
    /// Stable contract identity used to plan reusable analytical nodes.
    var tokenizationContractIdentifier: String { get }
    /// Additional query fields resolved by this lexical backend.
    var availableQueryFields: [GlifiQueryField] { get }
    /// Tokenizes a valid Swift string while preserving exact UTF-8 source offsets.
    func tokenize(_ text: String) throws -> GlifiTokenization
}

extension GlifiTokenizing {
    /// Historical tokenizers expose observed form and normalized text only.
    public var availableQueryFields: [GlifiQueryField] { [] }
}
