// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Counted unit of GS-MET-001-04 § Frequenze filtrate e n-grammi.
public enum GlifiNGramUnit: Codable, Equatable, Hashable, Sendable {
    /// Normalized lexical forms.
    case form
    /// `WordNGram-v1` of size `n` in `1...5`.
    case word(n: Int)
    /// `CharNGram-graphemes-v1` (or `-padded-v1`) of size `n` in `1...10`.
    case character(n: Int, padded: Bool)

    /// Versioned unit identity.
    public var identifier: String {
        switch self {
        case .form: "Form-v1"
        case .word: "WordNGram-v1"
        case let .character(_, padded):
            padded ? "CharNGram-graphemes-padded-v1" : "CharNGram-graphemes-v1"
        }
    }

    /// Size `n`, `1` for forms.
    public var size: Int {
        switch self {
        case .form: 1
        case let .word(n): n
        case let .character(n, _): n
        }
    }
}

/// Declared filters `TermFilter-v1`, applied after counting.
public struct GlifiTermFilter: Codable, Equatable, Hashable, Sendable {
    /// No filter.
    public static let none = GlifiTermFilter(
        stopwords: [], minimumLength: 1, minimumCount: 1, minimumDocumentFrequency: 1,
        maximumDocumentProportion: 1)

    /// Explicit stopword forms, normalized like tokens and sorted.
    public let stopwords: [String]
    /// Minimum form length in grapheme clusters (forms only).
    public let minimumLength: Int
    /// Inclusive minimum count.
    public let minimumCount: Int
    /// Inclusive minimum document frequency.
    public let minimumDocumentFrequency: Int
    /// Maximum `df/D` in `(0, 1]`.
    public let maximumDocumentProportion: Double

    /// Creates filters; stopwords are normalized (NFC, Italian lowercase) and deduplicated.
    public init(
        stopwords: [String],
        minimumLength: Int,
        minimumCount: Int,
        minimumDocumentFrequency: Int,
        maximumDocumentProportion: Double
    ) {
        let locale = Locale(identifier: "it_IT")
        self.stopwords = Array(
            Set(stopwords.map { $0.precomposedStringWithCanonicalMapping.lowercased(with: locale) })
        ).sorted()
        self.minimumLength = minimumLength
        self.minimumCount = minimumCount
        self.minimumDocumentFrequency = minimumDocumentFrequency
        self.maximumDocumentProportion = maximumDocumentProportion
    }

    var isValid: Bool {
        minimumLength >= 1 && minimumCount >= 1 && minimumDocumentFrequency >= 1
            && maximumDocumentProportion > 0 && maximumDocumentProportion <= 1
            && stopwords.count <= 10_000
    }
}

/// One counted unit that passed the filters.
public struct GlifiNGramFrequencyRow: Codable, Equatable, Sendable {
    /// Components: forms for word units, one string for forms and character n-grams.
    public let components: [String]
    /// Occurrences.
    public let count: Int
    /// Documents with at least one occurrence.
    public let documentFrequency: Int
    /// `count / denominator`, with the denominator taken before the filters.
    public let relativeFrequency: Double
}

/// Rows excluded by each filter, attributed to the first filter that excludes them.
public struct GlifiTermFilterExclusions: Codable, Equatable, Sendable {
    /// Excluded by `stopwords`.
    public let stopwords: Int
    /// Excluded by `minimumLength`.
    public let minimumLength: Int
    /// Excluded by `minimumCount`.
    public let minimumCount: Int
    /// Excluded by `minimumDocumentFrequency`.
    public let minimumDocumentFrequency: Int
    /// Excluded by `maximumDocumentProportion`.
    public let maximumDocumentProportion: Int
}

/// Filtered frequencies of forms, word n-grams or character n-grams.
public struct GlifiCorpusNGramFrequencyAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-ngram-frequencies.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-ngram-frequencies-v1"
    /// Largest number of distinct units counted.
    public static let maximumDistinctUnitCount = 100_000

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Counted unit.
    public let unit: GlifiNGramUnit
    /// Unit identity.
    public let unitIdentifier: String
    /// Declared filters.
    public let filter: GlifiTermFilter
    /// Filter contract.
    public let filterIdentifier: String
    /// Stopword policy for n-grams.
    public let stopwordPolicyIdentifier: String
    /// Analyzed documents `D`, canonically ordered.
    public let sourceRevisionIDs: [String]
    /// Units counted before the filters: the relative-frequency denominator.
    public let denominator: Int
    /// Distinct units before the filters.
    public let distinctUnitCount: Int
    /// Rows excluded by each filter.
    public let exclusions: GlifiTermFilterExclusions
    /// Whether rows beyond `maximumRowCount` were cut.
    public let isTruncated: Bool
    /// Rows by decreasing count, then increasing value.
    public let rows: [GlifiNGramFrequencyRow]

    /// Counts and filters documents given as normalized lexical sequences.
    public init(
        sequences: [(SourceRevisionID, [String])],
        unit: GlifiNGramUnit,
        filter: GlifiTermFilter,
        maximumRowCount: Int
    ) throws {
        guard !sequences.isEmpty else {
            throw derivedAnalysisFailure("ngrams.insufficient-sources", category: .insufficientData)
        }
        switch unit {
        case .form: break
        case let .word(n):
            guard (1...5).contains(n) else { throw derivedAnalysisFailure("ngrams.invalid-size") }
        case let .character(n, _):
            guard (1...10).contains(n) else { throw derivedAnalysisFailure("ngrams.invalid-size") }
        }
        guard filter.isValid, (1...100_000).contains(maximumRowCount) else {
            throw derivedAnalysisFailure("ngrams.invalid-filter")
        }
        let ordered = sequences.sorted { $0.0.canonicalValue < $1.0.canonicalValue }
        let stopwords = Set(filter.stopwords)
        var counts: [[String]: Int] = [:]
        var documentFrequency: [[String]: Int] = [:]
        var stopwordUnits: Set<[String]> = []
        var denominator = 0
        for (index, (_, forms)) in ordered.enumerated() {
            if index.isMultiple(of: 32) { try Task.checkCancellation() }
            var seen: Set<[String]> = []
            func record(_ value: [String], containsStopword: Bool) throws {
                denominator += 1
                if counts[value] == nil, counts.count >= Self.maximumDistinctUnitCount {
                    throw derivedAnalysisFailure("ngrams.limit-exceeded")
                }
                counts[value, default: 0] += 1
                if containsStopword { stopwordUnits.insert(value) }
                if seen.insert(value).inserted { documentFrequency[value, default: 0] += 1 }
            }
            switch unit {
            case .form:
                for form in forms {
                    try record([form], containsStopword: stopwords.contains(form))
                }
            case let .word(n):
                guard forms.count >= n else { continue }
                for start in 0...(forms.count - n) {
                    let window = Array(forms[start..<(start + n)])
                    try record(window, containsStopword: window.contains { stopwords.contains($0) })
                }
            case let .character(n, padded):
                for form in forms {
                    let graphemes = Array(padded ? "_" + form + "_" : form)
                    guard graphemes.count >= n else { continue }
                    for start in 0...(graphemes.count - n) {
                        try record(
                            [String(graphemes[start..<(start + n)])],
                            containsStopword: stopwords.contains(form))
                    }
                }
            }
        }
        let documentCount = Double(ordered.count)
        var excluded = (stopword: 0, length: 0, count: 0, df: 0, proportion: 0)
        var rows: [GlifiNGramFrequencyRow] = []
        for (value, count) in counts {
            let df = documentFrequency[value] ?? 0
            if stopwordUnits.contains(value) {
                excluded.stopword += 1
            } else if unit == .form, (value.first?.count ?? 0) < filter.minimumLength {
                excluded.length += 1
            } else if count < filter.minimumCount {
                excluded.count += 1
            } else if df < filter.minimumDocumentFrequency {
                excluded.df += 1
            } else if Double(df) / documentCount > filter.maximumDocumentProportion {
                excluded.proportion += 1
            } else {
                rows.append(
                    GlifiNGramFrequencyRow(
                        components: value, count: count, documentFrequency: df,
                        relativeFrequency: Double(count) / Double(denominator)))
            }
        }
        rows.sort {
            $0.count != $1.count
                ? $0.count > $1.count : $0.components.lexicographicallyPrecedes($1.components)
        }
        analysisIdentifier = Self.analysisIdentifier
        self.unit = unit
        unitIdentifier = unit.identifier
        self.filter = filter
        filterIdentifier = "TermFilter-v1"
        stopwordPolicyIdentifier = "stopword-policy.exclude-containing-v1"
        sourceRevisionIDs = ordered.map(\.0.canonicalValue)
        self.denominator = denominator
        distinctUnitCount = counts.count
        exclusions = GlifiTermFilterExclusions(
            stopwords: excluded.stopword, minimumLength: excluded.length,
            minimumCount: excluded.count, minimumDocumentFrequency: excluded.df,
            maximumDocumentProportion: excluded.proportion)
        isTruncated = rows.count > maximumRowCount
        self.rows = Array(rows.prefix(maximumRowCount))
    }
}
