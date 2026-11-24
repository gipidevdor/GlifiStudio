// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Counted unit: `form`, `word`, `character` or `character-padded`, with size `n`.
public struct GlifiStudioNGramUnit: Codable, Equatable, Sendable {
    /// `form`, `word`, `character` or `character-padded`.
    public let kind: String
    /// Size `n`; `1` for forms.
    public let n: Int

    /// Creates a unit, validated when used.
    public init(kind: String, n: Int) {
        self.kind = kind
        self.n = n
    }

    func coreValue() throws -> GlifiNGramUnit {
        switch kind {
        case "form" where n == 1: return .form
        case "word": return .word(n: n)
        case "character": return .character(n: n, padded: false)
        case "character-padded": return .character(n: n, padded: true)
        default:
            throw GlifiFailure(
                code: "ngrams.unknown-unit",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.ngrams.unknown-unit"
            )
        }
    }
}

/// Declared `TermFilter-v1` filters.
public struct GlifiStudioTermFilter: Codable, Equatable, Sendable {
    /// No filter.
    public static let none = GlifiStudioTermFilter(
        stopwords: [], minimumLength: 1, minimumCount: 1, minimumDocumentFrequency: 1,
        maximumDocumentProportion: 1)

    /// Explicit stopword forms.
    public let stopwords: [String]
    /// Minimum form length in grapheme clusters.
    public let minimumLength: Int
    /// Inclusive minimum count.
    public let minimumCount: Int
    /// Inclusive minimum document frequency.
    public let minimumDocumentFrequency: Int
    /// Maximum `df/D` in `(0, 1]`.
    public let maximumDocumentProportion: Double

    /// Creates filters, validated when used.
    public init(
        stopwords: [String], minimumLength: Int, minimumCount: Int,
        minimumDocumentFrequency: Int, maximumDocumentProportion: Double
    ) {
        self.stopwords = stopwords
        self.minimumLength = minimumLength
        self.minimumCount = minimumCount
        self.minimumDocumentFrequency = minimumDocumentFrequency
        self.maximumDocumentProportion = maximumDocumentProportion
    }

    var coreValue: GlifiTermFilter {
        GlifiTermFilter(
            stopwords: stopwords, minimumLength: minimumLength, minimumCount: minimumCount,
            minimumDocumentFrequency: minimumDocumentFrequency,
            maximumDocumentProportion: maximumDocumentProportion)
    }
}

/// One counted unit that passed the filters.
public struct GlifiStudioNGramFrequencyRow: Codable, Equatable, Sendable {
    /// Components of the unit.
    public let components: [String]
    /// Occurrences.
    public let count: Int
    /// Documents with at least one occurrence.
    public let documentFrequency: Int
    /// `count / denominator`.
    public let relativeFrequency: Double
}

/// Rows excluded by each filter.
public struct GlifiStudioTermFilterExclusions: Codable, Equatable, Sendable {
    /// Excluded by stopwords.
    public let stopwords: Int
    /// Excluded by minimum length.
    public let minimumLength: Int
    /// Excluded by minimum count.
    public let minimumCount: Int
    /// Excluded by minimum document frequency.
    public let minimumDocumentFrequency: Int
    /// Excluded by maximum document proportion.
    public let maximumDocumentProportion: Int
}

/// Presentation-independent filtered frequencies.
public struct GlifiStudioNGramFrequencyResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Unit identity.
    public let unitIdentifier: String
    /// Size `n`.
    public let n: Int
    /// Normalized, deduplicated filters.
    public let filter: GlifiStudioTermFilter
    /// Filter contract.
    public let filterIdentifier: String
    /// Stopword policy for n-grams.
    public let stopwordPolicyIdentifier: String
    /// Analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Units counted before the filters.
    public let denominator: Int
    /// Distinct units before the filters.
    public let distinctUnitCount: Int
    /// Rows excluded by each filter.
    public let exclusions: GlifiStudioTermFilterExclusions
    /// Whether rows beyond the row limit were cut.
    public let isTruncated: Bool
    /// Rows by decreasing count, then increasing value.
    public let rows: [GlifiStudioNGramFrequencyRow]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusNGramFrequencyAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        unitIdentifier = value.unitIdentifier
        n = value.unit.size
        filter = GlifiStudioTermFilter(
            stopwords: value.filter.stopwords, minimumLength: value.filter.minimumLength,
            minimumCount: value.filter.minimumCount,
            minimumDocumentFrequency: value.filter.minimumDocumentFrequency,
            maximumDocumentProportion: value.filter.maximumDocumentProportion)
        filterIdentifier = value.filterIdentifier
        stopwordPolicyIdentifier = value.stopwordPolicyIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs
        denominator = value.denominator
        distinctUnitCount = value.distinctUnitCount
        exclusions = GlifiStudioTermFilterExclusions(
            stopwords: value.exclusions.stopwords, minimumLength: value.exclusions.minimumLength,
            minimumCount: value.exclusions.minimumCount,
            minimumDocumentFrequency: value.exclusions.minimumDocumentFrequency,
            maximumDocumentProportion: value.exclusions.maximumDocumentProportion)
        isTruncated = value.isTruncated
        rows = value.rows.map {
            GlifiStudioNGramFrequencyRow(
                components: $0.components, count: $0.count,
                documentFrequency: $0.documentFrequency, relativeFrequency: $0.relativeFrequency)
        }
    }
}
