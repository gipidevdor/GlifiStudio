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
    /// Stationary probability of the continuous cosine graph of the non-null sentence vectors.
    case lexRank = "LexRankSentence-v1"

    /// Eligibility policy: which scored sentences may enter the summary.
    public var eligibilityPolicy: String {
        switch self {
        case .sentenceTFIDFMean: "eligibility.lexical-tokens-required-v1"
        case .centroidCosine, .lexRank: "eligibility.non-null-vector-v1"
        }
    }
}

/// Versioned redundancy policy applied while selecting sentences (GS-MET-001-19).
public enum GlifiSummaryRedundancyPolicy: Equatable, Hashable, Sendable {
    /// Selection walks the rank; identical sentences may both enter.
    case none
    /// Maximal Marginal Relevance: `λ·rel(s) − (1−λ)·max_{u∈S} sim(s,u)` with `0 ≤ λ ≤ 1`,
    /// `rel` the method score and `sim` the cosine between sentence vectors.
    case maximalMarginalRelevance(lambda: Double)

    /// `redundancy.none-v1`.
    public static let noneIdentifier = "redundancy.none-v1"
    /// `MMR-v1`.
    public static let maximalMarginalRelevanceIdentifier = "MMR-v1"
    /// Cosine between the sentence vectors of the declared weighting scheme.
    public static let sentenceVectorCosineIdentifier = "similarity.sentence-vector-cosine-v1"

    /// Versioned identifier of the policy.
    public var identifier: String {
        switch self {
        case .none: Self.noneIdentifier
        case .maximalMarginalRelevance: Self.maximalMarginalRelevanceIdentifier
        }
    }

    /// Trade-off `λ` between relevance and novelty; nil without redundancy control.
    public var lambda: Double? {
        switch self {
        case .none: nil
        case let .maximalMarginalRelevance(lambda): lambda
        }
    }

    /// Similarity used by the penalty; nil without redundancy control.
    public var similarityIdentifier: String? {
        switch self {
        case .none: nil
        case .maximalMarginalRelevance: Self.sentenceVectorCosineIdentifier
        }
    }

    /// Whether `λ` is finite and within `[0, 1]`.
    public var isValid: Bool {
        switch self {
        case .none: true
        case let .maximalMarginalRelevance(lambda): lambda.isFinite && lambda >= 0 && lambda <= 1
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
    /// One-based order in which the selection accepted the sentence; nil when not selected.
    public let selectionOrder: Int?

    init(
        sourceRevisionID: String, sentenceIndex: Int, range: GlifiUTF8Range, tokenCount: Int,
        score: Double, rank: Int, isEligible: Bool, isSelected: Bool, selectionOrder: Int?
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.sentenceIndex = sentenceIndex
        self.range = range
        self.tokenCount = tokenCount
        self.score = score
        self.rank = rank
        self.isEligible = isEligible
        self.isSelected = isSelected
        self.selectionOrder = selectionOrder
    }

    /// Payloads written before `CentroidCosine-v1` omit `isEligible`: lexical tokens were required;
    /// payloads written before `MMR-v1` omit `selectionOrder`.
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
        selectionOrder = try container.decodeIfPresent(Int.self, forKey: .selectionOrder)
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
    /// Backward-compatible identity of the default scoring method.
    public static let methodIdentifier = standardMethod.rawValue
    /// Damping factor `d` of `LexRankSentence-v1`.
    public static let lexRankDamping = 0.85
    /// Largest L1 change between iterations at which `LexRankSentence-v1` has converged.
    public static let lexRankTolerance = 1e-12
    /// Power iterations after which `LexRankSentence-v1` fails closed.
    public static let lexRankMaximumIterations = 1_000
    /// Largest number of graph nodes, the non-null sentence vectors, of `LexRankSentence-v1`.
    public static let lexRankMaximumNodes = 2_000
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
    /// Redundancy policy: `redundancy.none-v1` or `MMR-v1`.
    public let redundancyPolicy: String
    /// Trade-off `λ` of `MMR-v1`; nil without redundancy control, as in earlier payloads.
    public let redundancyLambda: Double?
    /// Similarity used by the redundancy penalty; nil without redundancy control.
    public let similarityIdentifier: String?
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
        method: GlifiSummaryScoringMethod = standardMethod,
        redundancy: GlifiSummaryRedundancyPolicy = .none
    ) throws {
        guard !documents.isEmpty else {
            throw derivedAnalysisFailure(
                "summary.insufficient-sources", category: .insufficientData)
        }
        guard budget.isValid else {
            throw derivedAnalysisFailure("summary.invalid-budget")
        }
        guard redundancy.isValid else {
            throw derivedAnalysisFailure("summary.invalid-redundancy")
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
        // Sentence vector: token count × document weight per type, sorted by column; shared by
        // the centroid method and by the MMR similarity.
        struct Vector {
            let entries: [(column: Int, value: Double)]
            let norm: Double
        }
        var vectors: [Vector] = []
        for (documentIndex, document) in ordered.enumerated() {
            for sentence in document.sentences {
                var counts: [Int: Int] = [:]
                for term in sentence.terms {
                    guard let column = columnIndex[term] else { continue }
                    counts[column, default: 0] += 1
                }
                let entries: [(column: Int, value: Double)] = counts.keys.sorted().compactMap {
                    column in
                    let value = Double(counts[column] ?? 0) * (weights[documentIndex][column] ?? 0)
                    return value == 0 ? nil : (column: column, value: value)
                }
                let norm = entries.reduce(0.0) { $0 + $1.value * $1.value }.squareRoot()
                vectors.append(Vector(entries: entries, norm: norm))
            }
        }
        func cosine(_ lhs: Vector, _ rhs: Vector) -> Double {
            guard lhs.norm > 0, rhs.norm > 0 else { return 0 }
            var dot = 0.0
            var left = 0
            var right = 0
            while left < lhs.entries.count, right < rhs.entries.count {
                let a = lhs.entries[left]
                let b = rhs.entries[right]
                if a.column == b.column {
                    dot += a.value * b.value
                    left += 1
                    right += 1
                } else if a.column < b.column {
                    left += 1
                } else {
                    right += 1
                }
            }
            return dot / (lhs.norm * rhs.norm)
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
            // The centroid is the mean of the non-null vectors. Null vectors score zero and are
            // never selected.
            var centroid: [Int: Double] = [:]
            var centroidCount = 0
            for vector in vectors where vector.norm > 0 {
                centroidCount += 1
                for entry in vector.entries {
                    centroid[entry.column, default: 0] += entry.value
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
            var position = 0
            for (documentIndex, document) in ordered.enumerated() {
                for (sentenceIndex, sentence) in document.sentences.enumerated() {
                    let vector = vectors[position]
                    position += 1
                    let isEligible = vector.norm > 0 && centroidNorm > 0
                    var dot = 0.0
                    if isEligible {
                        for entry in vector.entries {
                            dot += entry.value * (centroid[entry.column] ?? 0)
                        }
                    }
                    scored.append(
                        Scored(
                            document: documentIndex,
                            sentenceIndex: sentenceIndex,
                            range: sentence.range,
                            tokenCount: sentence.terms.count,
                            isEligible: isEligible,
                            score: isEligible ? dot / (vector.norm * centroidNorm) : 0
                        )
                    )
                }
            }
        case .lexRank:
            // Nodes are the non-null vectors; null vectors score zero and are never selected.
            let nodes = vectors.indices.filter { vectors[$0].norm > 0 }
            guard nodes.count <= Self.lexRankMaximumNodes else {
                throw derivedAnalysisFailure(
                    "summary.graph-limit-exceeded", category: .insufficientResources)
            }
            let transition = nodes.map { source in
                let row = nodes.map { target in cosine(vectors[source], vectors[target]) }
                let total = row.reduce(0, +)
                return row.map { $0 / total }
            }
            let stationary = try Self.lexRankStationary(transition)
            var centrality = Array(repeating: Double?.none, count: vectors.count)
            for (node, probability) in zip(nodes, stationary) {
                centrality[node] = probability
            }
            var position = 0
            for (documentIndex, document) in ordered.enumerated() {
                for (sentenceIndex, sentence) in document.sentences.enumerated() {
                    let probability = centrality[position]
                    position += 1
                    scored.append(
                        Scored(
                            document: documentIndex,
                            sentenceIndex: sentenceIndex,
                            range: sentence.range,
                            tokenCount: sentence.terms.count,
                            isEligible: probability != nil,
                            score: probability ?? 0
                        )
                    )
                }
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
        var order = Array(repeating: Int?.none, count: scored.count)
        var consumed = 0
        func cost(_ candidate: Scored) -> Int {
            switch budget.unit {
            case .sentences: 1
            case .lexicalTokens: candidate.tokenCount
            }
        }
        for (position, index) in rankedOrder.enumerated() {
            ranks[index] = position + 1
        }
        switch redundancy {
        case .none:
            var accepted = 0
            for index in rankedOrder {
                let candidate = scored[index]
                guard candidate.isEligible, consumed + cost(candidate) <= budget.limit else {
                    continue
                }
                consumed += cost(candidate)
                accepted += 1
                selected[index] = true
                order[index] = accepted
            }
        case let .maximalMarginalRelevance(lambda):
            // Greedy: each step takes the eligible, unselected sentence that fits the residual
            // budget with the largest `λ·score − (1−λ)·max cosine to the selected`; the first in
            // source order wins a tie; the loop stops when no sentence fits. The penalty of every
            // candidate is the running maximum over the accepted sentences, updated once per
            // acceptance: `k` accepted sentences cost `k·n` cosines.
            var penalties = Array(repeating: 0.0, count: scored.count)
            var accepted = 0
            while true {
                var best: Int?
                var bestObjective = -Double.infinity
                for index in scored.indices {
                    let candidate = scored[index]
                    guard candidate.isEligible, !selected[index],
                        consumed + cost(candidate) <= budget.limit
                    else { continue }
                    let objective = lambda * candidate.score - (1 - lambda) * penalties[index]
                    if objective > bestObjective {
                        bestObjective = objective
                        best = index
                    }
                }
                guard let best else { break }
                consumed += cost(scored[best])
                accepted += 1
                selected[best] = true
                order[best] = accepted
                if lambda < 1 {
                    for index in scored.indices where !selected[index] && scored[index].isEligible {
                        penalties[index] = max(
                            penalties[index], cosine(vectors[index], vectors[best]))
                    }
                }
            }
        }

        analysisIdentifier = Self.analysisIdentifier
        methodIdentifier = method.rawValue
        self.scheme = scheme
        combinedIdentifier = scheme.combinedIdentifier
        self.budget = budget
        consumedBudget = consumed
        redundancyPolicy = redundancy.identifier
        redundancyLambda = redundancy.lambda
        similarityIdentifier = redundancy.similarityIdentifier
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
                isSelected: selected[index],
                selectionOrder: order[index]
            )
        }
    }

    /// Power iteration `p ← (1 − d) / N + d · Mᵀp` from the uniform vector over a
    /// row-stochastic transition matrix; fails closed without convergence.
    static func lexRankStationary(_ transition: [[Double]]) throws -> [Double] {
        let count = transition.count
        guard count > 0 else { return [] }
        let teleport = (1 - lexRankDamping) / Double(count)
        var probabilities = Array(repeating: 1 / Double(count), count: count)
        for _ in 0..<lexRankMaximumIterations {
            var next = Array(repeating: 0.0, count: count)
            for target in 0..<count {
                var sum = 0.0
                for source in 0..<count {
                    sum += transition[source][target] * probabilities[source]
                }
                next[target] = teleport + lexRankDamping * sum
            }
            var change = 0.0
            for index in 0..<count {
                change += abs(next[index] - probabilities[index])
            }
            probabilities = next
            if change <= lexRankTolerance { return probabilities }
        }
        throw derivedAnalysisFailure(
            "summary.centrality-not-converged", category: .invariantViolation)
    }
}

/// One selected sentence resolved against its source text.
public struct GlifiResolvedSummarySentence: Codable, Equatable, Sendable {
    /// Scored sentence.
    public let sentence: GlifiSummarySentence
    /// Exact source text of the interval, unchanged.
    public let text: String
}
