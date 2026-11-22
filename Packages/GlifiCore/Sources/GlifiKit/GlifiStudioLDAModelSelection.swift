// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Selection criteria shared by Swift clients and canonical headless requests.
public enum GlifiStudioTopicSelectionCriterion: String, Codable, Sendable {
    /// Minimizes held-out document-completion perplexity.
    case heldOutPerplexity
    /// Minimizes mean pairwise topic cosine similarity.
    case caoJuan2009
    /// Minimizes the declared singular-value/document-mass divergence.
    case arun2010
    /// Maximizes the declared reference half-Jeffreys topic score.
    case deveaud2014
    /// Maximizes the log harmonic mean of collapsed word likelihoods.
    case griffiths2004

    var core: GlifiTopicSelectionCriterion {
        switch self {
        case .heldOutPerplexity: .heldOutPerplexity
        case .caoJuan2009: .caoJuan2009
        case .arun2010: .arun2010
        case .deveaud2014: .deveaud2014
        case .griffiths2004: .griffiths2004
        }
    }
}

/// Resolved sampling and validation parameters; zero folds requests diagnostics only.
public struct GlifiStudioLDASelectionOptions: Codable, Equatable, Sendable {
    /// Resolved criterion and its optimization direction.
    public let criterion: GlifiStudioTopicSelectionCriterion
    /// Held-out document folds, or zero for diagnostics without cross-validation.
    public let folds: Int
    /// Positive symmetric document-topic Dirichlet prior.
    public let alpha: Double
    /// Positive symmetric topic-term Dirichlet prior.
    public let beta: Double
    /// Gibbs sweeps discarded before collecting posterior samples.
    public let burnIn: Int
    /// Number of retained posterior samples.
    public let sampleCount: Int
    /// Gibbs sweeps between retained samples.
    public let thinning: Int

    /// Creates explicit resolved options; execution validates their numerical domain.
    public init(
        criterion: GlifiStudioTopicSelectionCriterion = .heldOutPerplexity,
        folds: Int = 5, alpha: Double = 0.1, beta: Double = 0.01,
        burnIn: Int = 100, sampleCount: Int = 20, thinning: Int = 5
    ) {
        self.criterion = criterion
        self.folds = folds
        self.alpha = alpha
        self.beta = beta
        self.burnIn = burnIn
        self.sampleCount = sampleCount
        self.thinning = thinning
    }

    /// Decodes known option fields, rejecting unknown keys and explicit null defaults.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: TextAnalysisKey.self)
        let allowed: Set<String> = [
            "criterion", "folds", "alpha", "beta", "burnIn", "sampleCount", "thinning",
        ]
        guard fields.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
        self.init(
            criterion: try fields.decode(
                GlifiStudioTopicSelectionCriterion.self, forKey: TextAnalysisKey("criterion"),
                fallback: .heldOutPerplexity),
            folds: try fields.decode(Int.self, forKey: TextAnalysisKey("folds"), fallback: 5),
            alpha: try fields.decode(Double.self, forKey: TextAnalysisKey("alpha"), fallback: 0.1),
            beta: try fields.decode(Double.self, forKey: TextAnalysisKey("beta"), fallback: 0.01),
            burnIn: try fields.decode(Int.self, forKey: TextAnalysisKey("burnIn"), fallback: 100),
            sampleCount: try fields.decode(
                Int.self, forKey: TextAnalysisKey("sampleCount"), fallback: 20),
            thinning: try fields.decode(Int.self, forKey: TextAnalysisKey("thinning"), fallback: 5))
    }
}

/// Application-facing named diagnostics and undefined cases.
public struct GlifiStudioLDATuningMetrics: Encodable, Equatable, Sendable {
    /// Mean topic cosine similarity; absent for fewer than two topics.
    public let caoJuan2009: Double?
    /// Singular-value/document-mass score; absent outside its declared domain.
    public let arun2010: Double?
    /// Reference half-Jeffreys score; absent for undefined topic pairs.
    public let deveaud2014: Double?
    /// Log harmonic likelihood estimate; diagnostic rather than held-out accuracy.
    public let griffiths2004: Double?
    /// Reason per undefined metric; undefined does not mean zero.
    public let unavailableReasons: [String: String]

    init(_ value: GlifiLDATuningMetrics) {
        caoJuan2009 = value.caoJuan2009
        arun2010 = value.arun2010
        deveaud2014 = value.deveaud2014
        griffiths2004 = value.griffiths2004
        unavailableReasons = value.unavailableReasons
    }
}

/// Predictive score and coverage for one held-out fold.
public struct GlifiStudioLDAHeldOutScore: Encodable, Equatable, Sendable {
    /// Log likelihood of scored known tokens only.
    public let logLikelihood: Double
    /// Known held-out tokens that contribute to the score.
    public let evaluatedTokenCount: Int
    /// Known context tokens used only for fold-in inference.
    public let observedTokenCount: Int
    /// Out-of-vocabulary tokens excluded explicitly from inference and scoring.
    public let ignoredTokenCount: Int
    /// Exponential of negative mean held-out token log likelihood.
    public let perplexity: Double

    init(_ value: GlifiLDAHeldOutScore) {
        logLikelihood = value.logLikelihood
        evaluatedTokenCount = value.evaluatedTokenCount
        observedTokenCount = value.observedTokenCount
        ignoredTokenCount = value.ignoredTokenCount
        perplexity = value.perplexity
    }
}

/// Diagnostics and prediction for one candidate topic count.
public struct GlifiStudioLDACandidateEvaluation: Encodable, Equatable, Sendable {
    /// Number of topics fitted for this candidate.
    public let topicCount: Int
    /// Named training diagnostics, including explicit undefined reasons.
    public let metrics: GlifiStudioLDATuningMetrics
    /// Coverage-weighted fold perplexity, absent when folds are disabled.
    public let heldOutPerplexity: Double?
    /// Per-fold predictive scores and token coverage.
    public let foldScores: [GlifiStudioLDAHeldOutScore]
    /// In-sample prediction, kept separate from held-out quality.
    public let trainingPerplexity: Double

    init(_ value: GlifiLDACandidateEvaluation) {
        topicCount = value.topicCount
        metrics = GlifiStudioLDATuningMetrics(value.metrics)
        heldOutPerplexity = value.heldOutPerplexity
        foldScores = value.foldScores.map(GlifiStudioLDAHeldOutScore.init)
        trainingPerplexity = value.trainingPerplexity
    }
}

/// Selected model and candidate diagnostics without engine types.
public struct GlifiStudioLDAModelSelectionResult: Encodable, Equatable, Sendable {
    /// Versioned native selection and fold-in contract.
    public let methodIdentifier = GlifiLDAModelSelectionResult.identifier
    /// Resolved criterion and its optimization direction.
    public let criterion: String
    /// Selected candidate; exact ties favor the smaller topic count.
    public let selectedTopicCount: Int
    /// Complete selected fit, without retaining every candidate dense model.
    public let selectedModel: GlifiStudioLDAResult
    /// Diagnostics in ascending candidate topic-count order.
    public let candidates: [GlifiStudioLDACandidateEvaluation]
    /// Fold identity per original input document, or empty when disabled.
    public let foldAssignments: [Int]
    /// Seed governing candidate inference and fold assignment.
    public let seed: UInt64

    init(_ value: GlifiLDAModelSelectionResult) {
        criterion = value.criterion.rawValue
        selectedTopicCount = value.selectedTopicCount
        selectedModel = GlifiStudioLDAResult(value.selectedModel)
        candidates = value.candidates.map(GlifiStudioLDACandidateEvaluation.init)
        foldAssignments = value.foldAssignments
        seed = value.seed
    }
}

/// Concurrent application-facing native topic-count selection.
public enum GlifiStudioLDAModelSelection {
    /// Computes validation and diagnostics outside the caller's actor, without project writes.
    @concurrent public static func select(
        documents: [[String]], candidateTopicCounts: [Int], seed: UInt64,
        options: GlifiStudioLDASelectionOptions = .init()
    ) async throws(GlifiStudioFailure) -> GlifiStudioLDAModelSelectionResult {
        do {
            return try GlifiStudioLDAModelSelectionResult(
                GlifiLDAModelSelection.select(
                    documents: documents, candidateTopicCounts: candidateTopicCounts, seed: seed,
                    criterion: options.criterion.core, folds: options.folds,
                    alpha: options.alpha, beta: options.beta, burnIn: options.burnIn,
                    sampleCount: options.sampleCount, thinning: options.thinning))
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch is CancellationError {
            throw textRequestFailure("operation.cancelled", category: "cancelled")
        } catch {
            throw textRequestFailure("lda-selection.failed", category: "insufficientData")
        }
    }
}
