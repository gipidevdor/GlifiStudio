// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A non-negative value that may be `+∞`, encoded without IEEE infinities in JSON.
///
/// A finite value is encoded as a number, `+∞` as the string `"+Infinity"`.
public enum GlifiExtendedNonNegative: Codable, Equatable, Sendable {
    /// Finite value.
    case finite(Double)
    /// Positive infinity.
    case positiveInfinity

    /// Wraps a binary64 value; `+∞` maps to `.positiveInfinity`.
    public init(_ value: Double) {
        self = value == .infinity ? .positiveInfinity : .finite(value)
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
        let container = try decoder.singleValueContainer()
        if let marker = try? container.decode(String.self) {
            guard marker == "+Infinity" else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unsupported extended value")
            }
            self = .positiveInfinity
        } else {
            let value = try container.decode(Double.self)
            guard value.isFinite, value >= 0 else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Extended value must be finite and ≥ 0")
            }
            self = .finite(value)
        }
    }

    /// Encodes a number or the `"+Infinity"` marker.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .finite(value): try container.encode(value)
        case .positiveInfinity: try container.encode("+Infinity")
        }
    }
}

/// `MTLD-bidirectional-v1` of one token sequence.
public struct GlifiMTLDValue: Codable, Equatable, Sendable {
    /// Versioned method identity.
    public static let identifier = "MTLD-bidirectional-v1"

    /// Tokens in the sequence.
    public let tokenCount: Int
    /// Value on the original order.
    public let forward: GlifiExtendedNonNegative
    /// Value on the reversed order.
    public let backward: GlifiExtendedNonNegative
    /// Mean of the two directions; `+∞` if either direction is `+∞`.
    public let value: GlifiExtendedNonNegative
}

/// Pure GS-MET-001-04 implementation of MTLD (McCarthy e Jarvis, 2010).
public enum GlifiMTLD {
    /// Candidate threshold of GS-MET-001-04.
    public static let standardThreshold = 0.72

    /// `MTLD-bidirectional-v1`, or `nil` for an empty sequence.
    public static func measure(_ sequence: [String], threshold: Double) throws -> GlifiMTLDValue? {
        guard threshold > 0, threshold < 1 else {
            throw derivedAnalysisFailure("diversity.invalid-threshold")
        }
        guard !sequence.isEmpty else {
            return nil
        }
        let forward = directional(sequence, threshold: threshold)
        let backward = directional(sequence.reversed(), threshold: threshold)
        // IEEE: la media con +∞ è +∞; entrambi finiti danno la media aritmetica.
        return GlifiMTLDValue(
            tokenCount: sequence.count,
            forward: GlifiExtendedNonNegative(forward),
            backward: GlifiExtendedNonNegative(backward),
            value: GlifiExtendedNonNegative((forward + backward) / 2)
        )
    }

    /// `N/fattori`, with the partial factor of the unfinished tail; `+∞` with zero factors.
    static func directional<Tokens: Sequence<String>>(
        _ tokens: Tokens, threshold: Double
    ) -> Double {
        var factors = 0.0
        var types: Set<String> = []
        var length = 0
        var total = 0
        for token in tokens {
            total += 1
            length += 1
            types.insert(token)
            if Double(types.count) / Double(length) <= threshold {
                factors += 1
                types.removeAll(keepingCapacity: true)
                length = 0
            }
        }
        if length > 0 {
            factors += (1 - Double(types.count) / Double(length)) / (1 - threshold)
        }
        return factors == 0 ? .infinity : Double(total) / factors
    }
}

/// MTLD of one document.
public struct GlifiDocumentLexicalDiversity: Codable, Equatable, Sendable {
    /// Analyzed document.
    public let sourceRevisionID: String
    /// MTLD, `nil` when the document has no lexical tokens.
    public let mtld: GlifiMTLDValue?
}

/// `MTLD-bidirectional-v1` per document and over the concatenated corpus sequence.
public struct GlifiCorpusLexicalDiversityAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-lexical-diversity.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-lexical-diversity-mtld-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Measure identity.
    public let methodIdentifier: String
    /// Resolved threshold `τ`.
    public let threshold: Double
    /// Token-to-type mapping.
    public let typeMappingIdentifier: String
    /// Order of the pooled sequence.
    public let sequencePolicy: String
    /// MTLD of the concatenated sequence, `nil` without lexical tokens.
    public let pooled: GlifiMTLDValue?
    /// Per-document values in canonical order.
    public let documents: [GlifiDocumentLexicalDiversity]

    /// Measures documents given as normalized lexical sequences in canonical order.
    public init(sequences: [(SourceRevisionID, [String])], threshold: Double) throws {
        guard !sequences.isEmpty else {
            throw derivedAnalysisFailure(
                "diversity.insufficient-sources", category: .insufficientData)
        }
        let ordered = sequences.sorted { $0.0.canonicalValue < $1.0.canonicalValue }
        analysisIdentifier = Self.analysisIdentifier
        methodIdentifier = GlifiMTLDValue.identifier
        self.threshold = threshold
        typeMappingIdentifier = "it-token-v1-nfc-lowercase-v1"
        sequencePolicy = "source-revision-order-concatenation-v1"
        pooled = try GlifiMTLD.measure(ordered.flatMap(\.1), threshold: threshold)
        documents = try ordered.map {
            GlifiDocumentLexicalDiversity(
                sourceRevisionID: $0.0.canonicalValue,
                mtld: try GlifiMTLD.measure($0.1, threshold: threshold)
            )
        }
    }
}
