// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Unit of an extractive-summary budget.
public enum GlifiSummaryBudgetUnit: String, Codable, Sendable {
    /// Maximum number of selected sentences.
    case sentences = "Budget-sentences-v1"
    /// Maximum total number of lexical tokens in the selected sentences.
    case lexicalTokens = "Budget-lexical-tokens-v1"
}

/// Declared budget of an extractive summary.
public struct GlifiSummaryBudget: Codable, Equatable, Hashable, Sendable {
    /// Largest budget accepted by the engine.
    public static let maximumLimit = 10_000
    /// Three sentences, the planner default.
    public static let standard = GlifiSummaryBudget(unit: .sentences, limit: 3)

    /// Unit the limit is expressed in.
    public let unit: GlifiSummaryBudgetUnit
    /// Positive limit in `unit`.
    public let limit: Int

    /// Creates a budget; validity is checked when the summary is computed.
    public init(unit: GlifiSummaryBudgetUnit, limit: Int) {
        self.unit = unit
        self.limit = limit
    }

    /// Whether the limit is positive and within the engine bound.
    public var isValid: Bool {
        limit >= 1 && limit <= Self.maximumLimit
    }
}

/// One candidate sentence of a document: source interval and normalized lexical tokens.
public struct GlifiSummaryCandidateSentence: Equatable, Sendable {
    /// Exact source interval of the sentence.
    public let range: GlifiUTF8Range
    /// Normalized lexical forms in source order, repetitions included.
    public let terms: [String]

    /// Creates a candidate from its interval and normalized tokens.
    public init(range: GlifiUTF8Range, terms: [String]) {
        self.range = range
        self.terms = terms
    }
}

/// Candidate sentences of one document in source order.
public struct GlifiSummaryDocument: Equatable, Sendable {
    /// Analyzed revision.
    public let sourceRevisionID: SourceRevisionID
    /// Sentences in source order; the index is the `SentenceID`.
    public let sentences: [GlifiSummaryCandidateSentence]

    /// Creates a document from its ordered candidate sentences.
    public init(sourceRevisionID: SourceRevisionID, sentences: [GlifiSummaryCandidateSentence]) {
        self.sourceRevisionID = sourceRevisionID
        self.sentences = sentences
    }
}

/// One scored sentence with its stable identity and source position.
public struct GlifiSummarySentence: Codable, Equatable, Sendable {
    /// Document that owns the sentence.
    public let sourceRevisionID: String
    /// Zero-based position among the sentences of the document (`SentenceID`).
    public let sentenceIndex: Int
    /// Exact source interval.
    public let range: GlifiUTF8Range
    /// Lexical tokens included in the score.
    public let tokenCount: Int
    /// `SentenceTFIDFMean-v1` score; zero without lexical tokens.
    public let score: Double
    /// One-based rank by descending score, ties broken by source position.
    public let rank: Int
    /// Whether the sentence enters the summary.
    public let isSelected: Bool
}

/// `SentenceTFIDFMean-v1` extractive summary over the sentences of a group.
public struct GlifiCorpusExtractiveSummaryAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier =
        "studio.glifi.artifact.corpus-extractive-summary.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-extractive-summary-v1"
    /// Scoring method identity.
    public static let methodIdentifier = "SentenceTFIDFMean-v1"
    /// Sublinear TF, smoothed IDF, no row normalization: defined for one document too.
    public static let standardScheme = GlifiTermWeightingScheme(
        termFrequency: .sublinear,
        inverseDocumentFrequency: .smooth,
        normalization: .none
    )

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Scoring method identity.
    public let methodIdentifier: String
    /// Declared document-term weighting scheme.
    public let scheme: GlifiTermWeightingScheme
    /// Combined weighting identity.
    public let combinedIdentifier: String
    /// Declared budget.
    public let budget: GlifiSummaryBudget
    /// Budget actually consumed, in the budget unit.
    public let consumedBudget: Int
    /// Redundancy policy: none, duplicates keep their own score.
    public let redundancyPolicy: String
    /// Tie-break: canonical document order, then sentence position.
    public let tieBreakIdentifier: String
    /// Eligibility: a sentence without lexical tokens is ranked but never selected.
    public let eligibilityPolicy: String
    /// Order of `sentences`: canonical document order, then sentence position.
    public let outputOrderIdentifier: String
    /// Token-to-type mapping.
    public let typeMappingIdentifier: String
    /// Documents in canonical order.
    public let sourceRevisionIDs: [String]
    /// Every candidate sentence in source order, scored and ranked.
    public let sentences: [GlifiSummarySentence]

    /// Selected sentences in source order.
    public var selectedSentences: [GlifiSummarySentence] {
        sentences.filter(\.isSelected)
    }

    /// Every sentence ordered by rank.
    public var rankedSentences: [GlifiSummarySentence] {
        sentences.sorted { $0.rank < $1.rank }
    }

    /// Scores and selects the sentences of documents given with normalized tokens.
    public init(
        documents: [GlifiSummaryDocument],
        budget: GlifiSummaryBudget,
        scheme: GlifiTermWeightingScheme
    ) throws {
        guard !documents.isEmpty else {
            throw derivedAnalysisFailure(
                "summary.insufficient-sources", category: .insufficientData)
        }
        guard budget.isValid else {
            throw derivedAnalysisFailure("summary.invalid-budget")
        }
        let ordered = documents.sorted {
            $0.sourceRevisionID.canonicalValue < $1.sourceRevisionID.canonicalValue
        }
        guard Set(ordered.map(\.sourceRevisionID)).count == ordered.count else {
            throw derivedAnalysisFailure("summary.duplicate-source")
        }

        let vocabulary = Array(
            Set(ordered.flatMap { $0.sentences.flatMap(\.terms) })
        ).sorted()
        let columnIndex = Dictionary(
            uniqueKeysWithValues: vocabulary.enumerated().map { ($0.element, $0.offset) }
        )
        let rows: [[Int: Int]] = ordered.map { document in
            var counts: [Int: Int] = [:]
            for sentence in document.sentences {
                for term in sentence.terms {
                    guard let column = columnIndex[term] else { continue }
                    counts[column, default: 0] += 1
                }
            }
            return counts
        }
        let weights = try GlifiTermWeighting.weigh(
            rows: rows, columnCount: vocabulary.count, scheme: scheme)

        struct Scored {
            let document: Int
            let sentenceIndex: Int
            let range: GlifiUTF8Range
            let tokenCount: Int
            let score: Double
        }
        var scored: [Scored] = []
        for (documentIndex, document) in ordered.enumerated() {
            for (sentenceIndex, sentence) in document.sentences.enumerated() {
                let tokenCount = sentence.terms.count
                var sum = 0.0
                for term in sentence.terms {
                    guard let column = columnIndex[term] else { continue }
                    sum += weights[documentIndex][column] ?? 0
                }
                scored.append(
                    Scored(
                        document: documentIndex,
                        sentenceIndex: sentenceIndex,
                        range: sentence.range,
                        tokenCount: tokenCount,
                        score: tokenCount == 0 ? 0 : sum / Double(tokenCount)
                    )
                )
            }
        }
        let rankedOrder = scored.indices.sorted { lhs, rhs in
            let left = scored[lhs]
            let right = scored[rhs]
            if left.score != right.score { return left.score > right.score }
            if left.document != right.document { return left.document < right.document }
            return left.sentenceIndex < right.sentenceIndex
        }
        var ranks = Array(repeating: 0, count: scored.count)
        var selected = Array(repeating: false, count: scored.count)
        var consumed = 0
        for (position, index) in rankedOrder.enumerated() {
            ranks[index] = position + 1
            let candidate = scored[index]
            guard candidate.tokenCount > 0 else { continue }
            let cost: Int
            switch budget.unit {
            case .sentences: cost = 1
            case .lexicalTokens: cost = candidate.tokenCount
            }
            guard consumed + cost <= budget.limit else { continue }
            consumed += cost
            selected[index] = true
        }

        analysisIdentifier = Self.analysisIdentifier
        methodIdentifier = Self.methodIdentifier
        self.scheme = scheme
        combinedIdentifier = scheme.combinedIdentifier
        self.budget = budget
        consumedBudget = consumed
        redundancyPolicy = "redundancy.none-v1"
        tieBreakIdentifier = "tie-break.source-position-v1"
        eligibilityPolicy = "eligibility.lexical-tokens-required-v1"
        outputOrderIdentifier = "output-order.source-v1"
        typeMappingIdentifier = "it-token-v1-nfc-lowercase-v1"
        sourceRevisionIDs = ordered.map(\.sourceRevisionID.canonicalValue)
        sentences = scored.indices.map { index in
            let candidate = scored[index]
            return GlifiSummarySentence(
                sourceRevisionID: ordered[candidate.document].sourceRevisionID.canonicalValue,
                sentenceIndex: candidate.sentenceIndex,
                range: candidate.range,
                tokenCount: candidate.tokenCount,
                score: candidate.score,
                rank: ranks[index],
                isSelected: selected[index]
            )
        }
    }
}

/// One selected sentence resolved against its source text.
public struct GlifiResolvedSummarySentence: Codable, Equatable, Sendable {
    /// Scored sentence.
    public let sentence: GlifiSummarySentence
    /// Exact source text of the interval, unchanged.
    public let text: String
}
