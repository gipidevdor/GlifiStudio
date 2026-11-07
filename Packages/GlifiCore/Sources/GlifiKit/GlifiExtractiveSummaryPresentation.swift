// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Declared budget of an extractive summary, by versioned unit identifier.
public struct GlifiStudioSummaryBudget: Codable, Equatable, Sendable {
    /// Three sentences.
    public static let standard = GlifiStudioSummaryBudget(unit: "Budget-sentences-v1", limit: 3)

    /// `Budget-sentences-v1`, `Budget-lexical-tokens-v1` or `Budget-characters-v1`.
    public let unit: String
    /// Positive limit in `unit`.
    public let limit: Int

    /// Creates a budget from a versioned unit identifier, validated when used.
    public init(unit: String, limit: Int) {
        self.unit = unit
        self.limit = limit
    }

    init(_ value: GlifiSummaryBudget) {
        unit = value.unit.rawValue
        limit = value.limit
    }

    func coreValue() throws -> GlifiSummaryBudget {
        guard let unit = GlifiSummaryBudgetUnit(rawValue: unit) else {
            throw GlifiFailure(
                code: "summary.unknown-budget-unit",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.summary.unknown-budget-unit"
            )
        }
        return GlifiSummaryBudget(unit: unit, limit: limit)
    }
}

/// Declared sentence-scoring method of an extractive summary, by versioned identifier.
public struct GlifiStudioSummaryScoringMethod: Codable, Equatable, Sendable {
    /// `SentenceTFIDFMean-v1`.
    public static let standard = GlifiStudioSummaryScoringMethod(
        identifier: GlifiCorpusExtractiveSummaryAnalysis.standardMethod.rawValue)
    /// Every method identifier accepted by the engine, in declaration order.
    public static let supportedIdentifiers = GlifiSummaryScoringMethod.allCases.map(\.rawValue)

    /// `SentenceTFIDFMean-v1`, `CentroidCosine-v1` or `LexRankSentence-v1`.
    public let identifier: String

    /// Creates a method from a versioned identifier, validated when used.
    public init(identifier: String) {
        self.identifier = identifier
    }

    func coreValue() throws -> GlifiSummaryScoringMethod {
        guard let method = GlifiSummaryScoringMethod(rawValue: identifier) else {
            throw GlifiFailure(
                code: "summary.unknown-method",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.summary.unknown-method"
            )
        }
        return method
    }
}

/// Declared redundancy policy of an extractive summary, by versioned identifier.
public struct GlifiStudioSummaryRedundancy: Codable, Equatable, Sendable {
    /// `redundancy.none-v1`: selection walks the rank.
    public static let standard = GlifiStudioSummaryRedundancy(
        identifier: GlifiSummaryRedundancyPolicy.noneIdentifier, lambda: nil)
    /// Every policy identifier accepted by the engine.
    public static let supportedIdentifiers = [
        GlifiSummaryRedundancyPolicy.noneIdentifier,
        GlifiSummaryRedundancyPolicy.maximalMarginalRelevanceIdentifier,
    ]

    /// `redundancy.none-v1` or `MMR-v1`.
    public let identifier: String
    /// Trade-off `λ` of `MMR-v1` in `[0, 1]`; absent without redundancy control.
    public let lambda: Double?

    /// Creates a policy from a versioned identifier, validated when used.
    public init(identifier: String, lambda: Double?) {
        self.identifier = identifier
        self.lambda = lambda
    }

    /// `MMR-v1` with the given trade-off.
    public static func maximalMarginalRelevance(lambda: Double) -> GlifiStudioSummaryRedundancy {
        GlifiStudioSummaryRedundancy(
            identifier: GlifiSummaryRedundancyPolicy.maximalMarginalRelevanceIdentifier,
            lambda: lambda)
    }

    func coreValue() throws -> GlifiSummaryRedundancyPolicy {
        switch identifier {
        case GlifiSummaryRedundancyPolicy.noneIdentifier:
            guard lambda == nil else { throw Self.failure("summary.invalid-redundancy") }
            return .none
        case GlifiSummaryRedundancyPolicy.maximalMarginalRelevanceIdentifier:
            guard let lambda else { throw Self.failure("summary.invalid-redundancy") }
            return .maximalMarginalRelevance(lambda: lambda)
        default:
            throw Self.failure("summary.unknown-redundancy")
        }
    }

    private static func failure(_ code: String) -> GlifiFailure {
        GlifiFailure(
            code: code,
            category: .invalidInput,
            operation: .analyze,
            retryDisposition: .afterCorrection,
            retainedState: .lastCommittedGeneration,
            messageKey: "failure.\(code)"
        )
    }
}

extension GlifiStudioTermWeightingScheme {
    /// `TF-sublinear-v1`, `IDF-smooth-v1`, `RowNorm-none-v1`: the summary default.
    public static let summaryStandard = GlifiStudioTermWeightingScheme(
        GlifiCorpusExtractiveSummaryAnalysis.standardScheme)
}

/// One candidate sentence, scored and ranked.
public struct GlifiStudioSummarySentence: Codable, Equatable, Sendable {
    /// Document that owns the sentence.
    public let sourceRevisionID: String
    /// Zero-based position among the sentences of the document.
    public let sentenceIndex: Int
    /// Inclusive UTF-8 start offset in the source.
    public let startUTF8: Int
    /// Exclusive UTF-8 end offset in the source.
    public let endUTF8: Int
    /// Lexical tokens included in the score.
    public let tokenCount: Int
    /// Score of the declared sentence-scoring method.
    public let score: Double
    /// One-based rank by descending score, ties broken by source position.
    public let rank: Int
    /// Whether the sentence may be selected under the eligibility policy of the method.
    public let isEligible: Bool
    /// Whether the sentence enters the summary.
    public let isSelected: Bool
    /// One-based order in which the selection accepted the sentence; nil when not selected.
    public let selectionOrder: Int?

    init(_ value: GlifiSummarySentence) {
        sourceRevisionID = value.sourceRevisionID
        sentenceIndex = value.sentenceIndex
        startUTF8 = value.range.start
        endUTF8 = value.range.end
        tokenCount = value.tokenCount
        score = value.score
        rank = value.rank
        isEligible = value.isEligible
        isSelected = value.isSelected
        selectionOrder = value.selectionOrder
    }

    /// Decodes earlier presentation payloads using their lexical-token eligibility policy and
    /// without a selection order.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceRevisionID = try container.decode(String.self, forKey: .sourceRevisionID)
        sentenceIndex = try container.decode(Int.self, forKey: .sentenceIndex)
        startUTF8 = try container.decode(Int.self, forKey: .startUTF8)
        endUTF8 = try container.decode(Int.self, forKey: .endUTF8)
        tokenCount = try container.decode(Int.self, forKey: .tokenCount)
        score = try container.decode(Double.self, forKey: .score)
        rank = try container.decode(Int.self, forKey: .rank)
        isEligible =
            try container.decodeIfPresent(Bool.self, forKey: .isEligible) ?? (tokenCount > 0)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        selectionOrder = try container.decodeIfPresent(Int.self, forKey: .selectionOrder)
    }
}

/// One selected sentence with its exact source text.
public struct GlifiStudioSelectedSentence: Codable, Equatable, Sendable {
    /// Scored sentence.
    public let sentence: GlifiStudioSummarySentence
    /// Exact source text of the interval, unchanged.
    public let text: String
}

/// Presentation-independent extractive summary with its declared scoring method.
public struct GlifiStudioExtractiveSummaryResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Scoring method identity.
    public let methodIdentifier: String
    /// Declared document-term weighting scheme.
    public let scheme: GlifiStudioTermWeightingScheme
    /// Combined weighting identity.
    public let combinedIdentifier: String
    /// Declared budget.
    public let budget: GlifiStudioSummaryBudget
    /// Budget actually consumed.
    public let consumedBudget: Int
    /// Redundancy policy.
    public let redundancyPolicy: String
    /// Trade-off `λ` of `MMR-v1`; absent without redundancy control.
    public let redundancyLambda: Double?
    /// Similarity used by the redundancy penalty; absent without redundancy control.
    public let similarityIdentifier: String?
    /// Tie-break policy.
    public let tieBreakIdentifier: String
    /// Eligibility policy.
    public let eligibilityPolicy: String
    /// Order of `sentences`.
    public let outputOrderIdentifier: String
    /// Documents in canonical order.
    public let sourceRevisionIDs: [String]
    /// Every candidate sentence in source order.
    public let sentences: [GlifiStudioSummarySentence]
    /// Selected sentences in source order with their text.
    public let selected: [GlifiStudioSelectedSentence]

    init(
        _ result: GlifiProjectDerivedResult<GlifiCorpusExtractiveSummaryAnalysis>,
        resolved: [GlifiResolvedSummarySentence]
    ) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        methodIdentifier = value.methodIdentifier
        scheme = GlifiStudioTermWeightingScheme(value.scheme)
        combinedIdentifier = value.combinedIdentifier
        budget = GlifiStudioSummaryBudget(value.budget)
        consumedBudget = value.consumedBudget
        redundancyPolicy = value.redundancyPolicy
        redundancyLambda = value.redundancyLambda
        similarityIdentifier = value.similarityIdentifier
        tieBreakIdentifier = value.tieBreakIdentifier
        eligibilityPolicy = value.eligibilityPolicy
        outputOrderIdentifier = value.outputOrderIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs
        sentences = value.sentences.map(GlifiStudioSummarySentence.init)
        selected = resolved.map {
            GlifiStudioSelectedSentence(
                sentence: GlifiStudioSummarySentence($0.sentence), text: $0.text)
        }
    }
}
