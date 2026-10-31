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

/// Versioned sentence-scoring method of an extractive summary (GS-MET-001-19).
public enum GlifiSummaryScoringMethod: String, CaseIterable, Codable, Sendable {
    /// Mean of the document TF-IDF weights of the sentence tokens; zero without tokens.
    case sentenceTFIDFMean = "SentenceTFIDFMean-v1"
    /// Cosine between the sentence vector and the centroid of the non-null sentence vectors.
    case centroidCosine = "CentroidCosine-v1"

    /// Eligibility policy: which scored sentences may enter the summary.
    public var eligibilityPolicy: String {
        switch self {
        case .sentenceTFIDFMean: "eligibility.lexical-tokens-required-v1"
        case .centroidCosine: "eligibility.non-null-vector-v1"
        }
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
    /// Score of the declared method; zero for an ineligible sentence.
    public let score: Double
    /// One-based rank by descending score, ties broken by source position.
    public let rank: Int
    /// Whether the sentence may be selected under the eligibility policy of the method.
    public let isEligible: Bool
    /// Whether the sentence enters the summary.
    public let isSelected: Bool

    init(
        sourceRevisionID: String, sentenceIndex: Int, range: GlifiUTF8Range, tokenCount: Int,
        score: Double, rank: Int, isEligible: Bool, isSelected: Bool
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.sentenceIndex = sentenceIndex
        self.range = range
        self.tokenCount = tokenCount
        self.score = score
        self.rank = rank
        self.isEligible = isEligible
        self.isSelected = isSelected
    }

    /// Payloads written before `CentroidCosine-v1` omit `isEligible`: lexical tokens were required.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceRevisionID = try container.decode(String.self, forKey: .sourceRevisionID)
        sentenceIndex = try container.decode(Int.self, forKey: .sentenceIndex)
        range = try container.decode(GlifiUTF8Range.self, forKey: .range)
        tokenCount = try container.decode(Int.self, forKey: .tokenCount)
        score = try container.decode(Double.self, forKey: .score)
        rank = try container.decode(Int.self, forKey: .rank)
        isEligible =
            try container.decodeIfPresent(Bool.self, forKey: .isEligible) ?? (tokenCount > 0)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
    }
}

/// Extractive summary over the sentences of a group with a declared scoring method.
public struct GlifiCorpusExtractiveSummaryAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier =
        "studio.glifi.artifact.corpus-extractive-summary.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-extractive-summary-v1"
    /// Default scoring method.
    public static let standardMethod = GlifiSummaryScoringMethod.sentenceTFIDFMean
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
    /// Eligibility of the method: an ineligible sentence is ranked at zero but never selected.
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
        scheme: GlifiTermWeightingScheme,
        method: GlifiSummaryScoringMethod = standardMethod
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
            let isEligible: Bool
            let score: Double
        }
        var scored: [Scored] = []
        switch method {
        case .sentenceTFIDFMean:
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
                            isEligible: tokenCount > 0,
                            score: tokenCount == 0 ? 0 : sum / Double(tokenCount)
                        )
                    )
                }
            }
        case .centroidCosine:
            // Sentence vector: token count × document weight per type; the centroid is the
            // mean of the non-null vectors. Null vectors score zero and are never selected.
            struct Vector {
                let document: Int
                let sentenceIndex: Int
                let range: GlifiUTF8Range
                let tokenCount: Int
                let entries: [(column: Int, value: Double)]
                let norm: Double
            }
            var vectors: [Vector] = []
            var centroid: [Int: Double] = [:]
            var centroidCount = 0
            for (documentIndex, document) in ordered.enumerated() {
                for (sentenceIndex, sentence) in document.sentences.enumerated() {
                    var counts: [Int: Int] = [:]
                    for term in sentence.terms {
                        guard let column = columnIndex[term] else { continue }
                        counts[column, default: 0] += 1
                    }
                    let entries: [(column: Int, value: Double)] = counts.keys.sorted().compactMap {
                        column in
                        let value =
                            Double(counts[column] ?? 0) * (weights[documentIndex][column] ?? 0)
                        return value == 0 ? nil : (column: column, value: value)
                    }
                    let norm = entries.reduce(0.0) { $0 + $1.value * $1.value }.squareRoot()
                    if norm > 0 {
                        centroidCount += 1
                        for entry in entries {
                            centroid[entry.column, default: 0] += entry.value
                        }
                    }
                    vectors.append(
                        Vector(
                            document: documentIndex, sentenceIndex: sentenceIndex,
                            range: sentence.range, tokenCount: sentence.terms.count,
                            entries: entries, norm: norm))
                }
            }
            var centroidNorm = 0.0
            if centroidCount > 0 {
                for column in centroid.keys.sorted() {
                    centroid[column] = (centroid[column] ?? 0) / Double(centroidCount)
                    centroidNorm += (centroid[column] ?? 0) * (centroid[column] ?? 0)
                }
                centroidNorm = centroidNorm.squareRoot()
            }
            for vector in vectors {
                let isEligible = vector.norm > 0 && centroidNorm > 0
                var dot = 0.0
                if isEligible {
                    for entry in vector.entries {
                        dot += entry.value * (centroid[entry.column] ?? 0)
                    }
                }
                scored.append(
                    Scored(
                        document: vector.document,
                        sentenceIndex: vector.sentenceIndex,
                        range: vector.range,
                        tokenCount: vector.tokenCount,
                        isEligible: isEligible,
                        score: isEligible ? dot / (vector.norm * centroidNorm) : 0
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
            guard candidate.isEligible else { continue }
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
        methodIdentifier = method.rawValue
        self.scheme = scheme
        combinedIdentifier = scheme.combinedIdentifier
        self.budget = budget
        consumedBudget = consumed
        redundancyPolicy = "redundancy.none-v1"
        tieBreakIdentifier = "tie-break.source-position-v1"
        eligibilityPolicy = method.eligibilityPolicy
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
                isEligible: candidate.isEligible,
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
