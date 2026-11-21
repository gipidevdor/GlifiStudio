// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Declared weighting scheme with versioned GS-MET-001-07 identifiers.
public struct GlifiStudioTermWeightingScheme: Codable, Equatable, Sendable {
    /// `TF-raw-v1`, `TF-binary-v1`, `TF-L1-v1`, `TF-max-v1`, `TF-augmented-v1`, `TF-sublinear-v1`.
    public let termFrequency: String
    /// `IDF-none-v1`, `IDF-unsmoothed-v1` or `IDF-smooth-v1`.
    public let inverseDocumentFrequency: String
    /// `RowNorm-none-v1`, `RowNorm-L1-v1` or `RowNorm-L2-v1`.
    public let normalization: String

    /// Creates a scheme from versioned identifiers, validated when used.
    public init(termFrequency: String, inverseDocumentFrequency: String, normalization: String) {
        self.termFrequency = termFrequency
        self.inverseDocumentFrequency = inverseDocumentFrequency
        self.normalization = normalization
    }

    init(_ value: GlifiTermWeightingScheme) {
        termFrequency = value.termFrequency.rawValue
        inverseDocumentFrequency = value.inverseDocumentFrequency.rawValue
        normalization = value.normalization.rawValue
    }

    func coreValue() throws -> GlifiTermWeightingScheme {
        guard let tf = GlifiTermFrequencyVariant(rawValue: termFrequency),
            let idf = GlifiInverseDocumentFrequencyVariant(rawValue: inverseDocumentFrequency),
            let norm = GlifiRowNormalization(rawValue: normalization)
        else {
            throw GlifiFailure(
                code: "weighting.unknown-variant",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.weighting.unknown-variant"
            )
        }
        return GlifiTermWeightingScheme(
            termFrequency: tf, inverseDocumentFrequency: idf, normalization: norm)
    }
}

/// One observed cell with a positive count; its weight may be zero.
public struct GlifiStudioWeightedTermCell: Codable, Equatable, Sendable {
    /// Row index into `sourceRevisionIDs`.
    public let rowIndex: Int
    /// Column index into `terms`.
    public let columnIndex: Int
    /// Observed count.
    public let count: Int
    /// Weight under the declared scheme.
    public let weight: Double
}

/// Presentation-independent weighted document × term matrix.
public struct GlifiStudioTermWeightingResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Declared scheme.
    public let scheme: GlifiStudioTermWeightingScheme
    /// Combined weighting identity.
    public let combinedIdentifier: String
    /// Documents (rows).
    public let sourceRevisionIDs: [String]
    /// Vocabulary (columns).
    public let terms: [String]
    /// Document frequency per term.
    public let documentFrequencies: [Int]
    /// Observed cells ordered by row, then column, including zero weights.
    public let cells: [GlifiStudioWeightedTermCell]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusTermWeightingAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        scheme = GlifiStudioTermWeightingScheme(value.scheme)
        combinedIdentifier = value.combinedIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs
        terms = value.terms
        documentFrequencies = value.documentFrequencies
        cells = value.cells.map {
            GlifiStudioWeightedTermCell(
                rowIndex: $0.rowIndex, columnIndex: $0.columnIndex, count: $0.count,
                weight: $0.weight)
        }
    }
}

/// One query term with its collection statistics.
public struct GlifiStudioBM25QueryTerm: Codable, Equatable, Sendable {
    /// Normalized query term.
    public let term: String
    /// Whether the term belongs to the collection vocabulary.
    public let isInVocabulary: Bool
    /// Documents containing the term.
    public let documentFrequency: Int
    /// `BM25-v1` idf.
    public let inverseDocumentFrequency: Double
}

/// One ranked document.
public struct GlifiStudioBM25RankedDocument: Codable, Equatable, Sendable {
    /// Retrieval unit.
    public let sourceRevisionID: String
    /// Included lexical tokens.
    public let length: Int
    /// Ranking score, not a probability.
    public let score: Double
}

/// Presentation-independent `BM25-v1` ranking.
public struct GlifiStudioBM25Result: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Ranking formula.
    public let methodIdentifier: String
    /// `k1`.
    public let k1: Double
    /// `b`.
    public let b: Double
    /// Unique normalized query terms.
    public let queryTerms: [GlifiStudioBM25QueryTerm]
    /// `N`.
    public let documentCount: Int
    /// `avgdl`.
    public let averageLength: Double
    /// Documents by decreasing score, ties by identity.
    public let ranking: [GlifiStudioBM25RankedDocument]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusBM25Analysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        methodIdentifier = value.methodIdentifier
        k1 = value.parameters.k1
        b = value.parameters.b
        queryTerms = value.queryTerms.map {
            GlifiStudioBM25QueryTerm(
                term: $0.term, isInVocabulary: $0.isInVocabulary,
                documentFrequency: $0.documentFrequency,
                inverseDocumentFrequency: $0.inverseDocumentFrequency)
        }
        documentCount = value.documentCount
        averageLength = value.averageLength
        ranking = value.ranking.map {
            GlifiStudioBM25RankedDocument(
                sourceRevisionID: $0.sourceRevisionID, length: $0.length, score: $0.score)
        }
    }
}
