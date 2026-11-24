// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Non-negative value that may be `+∞`; JSON encodes `+∞` as `"+Infinity"`.
public enum GlifiStudioExtendedValue: Codable, Equatable, Sendable {
    /// Finite value.
    case finite(Double)
    /// Positive infinity.
    case positiveInfinity

    init(_ value: GlifiExtendedNonNegative) {
        switch value {
        case let .finite(number): self = .finite(number)
        case .positiveInfinity: self = .positiveInfinity
        }
    }

    /// The binary64 value, `+∞` included.
    public var doubleValue: Double {
        switch self {
        case let .finite(value): value
        case .positiveInfinity: .infinity
        }
    }

    /// Decodes a number or the `"+Infinity"` marker.
    public init(from decoder: any Decoder) throws {
        self.init(try GlifiExtendedNonNegative(from: decoder))
    }

    /// Encodes a number or the `"+Infinity"` marker.
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .finite(value): try GlifiExtendedNonNegative.finite(value).encode(to: encoder)
        case .positiveInfinity: try GlifiExtendedNonNegative.positiveInfinity.encode(to: encoder)
        }
    }
}

/// `MTLD-bidirectional-v1` of one token sequence.
public struct GlifiStudioMTLDValue: Codable, Equatable, Sendable {
    /// Tokens in the sequence.
    public let tokenCount: Int
    /// Value on the original order.
    public let forward: GlifiStudioExtendedValue
    /// Value on the reversed order.
    public let backward: GlifiStudioExtendedValue
    /// Mean of the two directions.
    public let value: GlifiStudioExtendedValue

    init(_ value: GlifiMTLDValue) {
        tokenCount = value.tokenCount
        forward = GlifiStudioExtendedValue(value.forward)
        backward = GlifiStudioExtendedValue(value.backward)
        self.value = GlifiStudioExtendedValue(value.value)
    }
}

/// MTLD of one document; `mtld` is absent without lexical tokens.
public struct GlifiStudioDocumentLexicalDiversity: Codable, Equatable, Sendable {
    /// Analyzed document.
    public let sourceRevisionID: String
    /// MTLD, `nil` when the document has no lexical tokens.
    public let mtld: GlifiStudioMTLDValue?
}

/// Presentation-independent `MTLD-bidirectional-v1` result.
public struct GlifiStudioLexicalDiversityResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Measure identity.
    public let methodIdentifier: String
    /// Resolved threshold `τ`.
    public let threshold: Double
    /// Token-to-type mapping.
    public let typeMappingIdentifier: String
    /// Order of the pooled sequence.
    public let sequencePolicy: String
    /// MTLD of the concatenated sequence.
    public let pooled: GlifiStudioMTLDValue?
    /// Per-document values in canonical order.
    public let documents: [GlifiStudioDocumentLexicalDiversity]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusLexicalDiversityAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        methodIdentifier = value.methodIdentifier
        threshold = value.threshold
        typeMappingIdentifier = value.typeMappingIdentifier
        sequencePolicy = value.sequencePolicy
        pooled = value.pooled.map(GlifiStudioMTLDValue.init)
        documents = value.documents.map {
            GlifiStudioDocumentLexicalDiversity(
                sourceRevisionID: $0.sourceRevisionID,
                mtld: $0.mtld.map(GlifiStudioMTLDValue.init))
        }
    }
}
