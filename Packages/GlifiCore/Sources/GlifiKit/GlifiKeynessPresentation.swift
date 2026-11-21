// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Public bounded parameters for one keyness comparison.
public struct GlifiStudioKeynessOptions: Equatable, Sendable {
    /// Conservative defaults shared by native and headless clients.
    public static let standard = GlifiStudioKeynessOptions(.standard)

    let coreValue: GlifiKeynessOptions

    /// Largest admitted multiple-comparison family.
    public let maximumHypothesisCount: Int
    /// Expected-count threshold for the asymptotic diagnostic.
    public let lowExpectedCountThreshold: Double
    /// Level of the Katz and Woolf confidence intervals, in `(0, 1)`.
    public let confidenceLevel: Double

    /// Creates comparison bounds with the established 95% confidence level.
    public init(
        maximumHypothesisCount: Int,
        lowExpectedCountThreshold: Double
    ) throws {
        try self.init(
            maximumHypothesisCount: maximumHypothesisCount,
            lowExpectedCountThreshold: lowExpectedCountThreshold,
            confidenceLevel: 0.95)
    }

    /// Creates comparison bounds and a confidence level without silently correcting parameters.
    public init(
        maximumHypothesisCount: Int,
        lowExpectedCountThreshold: Double,
        confidenceLevel: Double
    ) throws {
        do {
            self.init(
                try GlifiKeynessOptions(
                    maximumHypothesisCount: maximumHypothesisCount,
                    lowExpectedCountThreshold: lowExpectedCountThreshold,
                    confidenceLevel: confidenceLevel
                )
            )
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        }
    }

    private init(_ value: GlifiKeynessOptions) {
        coreValue = value
        maximumHypothesisCount = value.maximumHypothesisCount
        lowExpectedCountThreshold = value.lowExpectedCountThreshold
        confidenceLevel = value.confidenceLevel
    }
}

/// Complete keyness values for one normalized term.
public struct GlifiStudioKeynessTerm: Codable, Equatable, Identifiable, Sendable {
    /// Stable row identity derived from the normalized term.
    public var id: String { term }
    /// NFC, Italian-lowercased lexical form.
    public let term: String
    /// Exact occurrence count in the target group.
    public let targetFrequency: Int
    /// Exact occurrence count in the reference group.
    public let referenceFrequency: Int
    /// Relative frequency in the target group.
    public let targetRelativeFrequency: Double
    /// Relative frequency in the reference group.
    public let referenceRelativeFrequency: Double
    /// `GTest-v1` statistic.
    public let gStatistic: Double
    /// Degrees of freedom.
    public let degreesOfFreedom: Int
    /// Raw p-value of the selected test.
    public let pValue: Double
    /// `GTest-v1` asymptotic p-value.
    public let gTestPValue: Double
    /// Test selected from the margins.
    public let selectedTestIdentifier: String
    /// Benjamini–Hochberg adjusted q-value.
    public let qValue: Double
    /// Haldane–Anscombe corrected odds ratio.
    public let oddsRatioHaldaneAnscombe: Double
    /// Haldane–Anscombe corrected base-two log ratio.
    public let log2RatioHaldaneAnscombe: Double
    /// Lower bound of the log-ratio interval, base two.
    public let log2RatioLower: Double
    /// Upper bound of the log-ratio interval, base two.
    public let log2RatioUpper: Double
    /// Lower bound of the odds-ratio interval.
    public let oddsRatioLower: Double
    /// Upper bound of the odds-ratio interval.
    public let oddsRatioUpper: Double
    /// Group favored by the signed effect.
    public let direction: String
    /// Smallest expected cell count.
    public let minimumExpectedCount: Double
    /// Whether the declared asymptotic diagnostic threshold was crossed.
    public let hasLowExpectedCount: Bool

    init(_ value: GlifiKeynessTermResult) {
        term = value.term
        targetFrequency = value.targetFrequency
        referenceFrequency = value.referenceFrequency
        targetRelativeFrequency = value.targetRelativeFrequency
        referenceRelativeFrequency = value.referenceRelativeFrequency
        gStatistic = value.gStatistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        gTestPValue = value.gTestPValue
        selectedTestIdentifier = value.selectedTestIdentifier
        log2RatioLower = value.log2RatioLower
        log2RatioUpper = value.log2RatioUpper
        oddsRatioLower = value.oddsRatioLower
        oddsRatioUpper = value.oddsRatioUpper
        qValue = value.qValue
        oddsRatioHaldaneAnscombe = value.oddsRatioHaldaneAnscombe
        log2RatioHaldaneAnscombe = value.log2RatioHaldaneAnscombe
        direction = value.direction.rawValue
        minimumExpectedCount = value.minimumExpectedCount
        hasLowExpectedCount = value.hasLowExpectedCount
    }
}

/// Presentation-independent keyness comparison for one project generation.
public struct GlifiStudioKeynessResult: Codable, Equatable, Sendable {
    /// Stable project identity.
    public let projectID: String
    /// Exact source generation captured before comparison.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the Artifact.
    public let generation: Int
    /// Immutable persisted Artifact identity.
    public let artifactID: String
    /// Semantic producer identity.
    public let analysisNodeID: String
    /// Versioned aggregate comparison contract.
    public let comparisonIdentifier: String
    /// Digest of both populations, methods, and resolved parameters.
    public let comparisonDigest: String
    /// Digest of the target population profile.
    public let targetCorpusDigest: String
    /// Digest of the reference population profile.
    public let referenceCorpusDigest: String
    /// Canonically ordered target source revisions.
    public let targetSourceRevisionIDs: [String]
    /// Canonically ordered reference source revisions.
    public let referenceSourceRevisionIDs: [String]
    /// Number of target lexical tokens.
    public let targetTokenCount: Int
    /// Number of reference lexical tokens.
    public let referenceTokenCount: Int
    /// Statistical-test method identity.
    public let testIdentifier: String
    /// Rule selecting the exact test.
    public let testSelectionIdentifier: String
    /// Exact test identity.
    public let exactTestIdentifier: String
    /// Interval confidence level.
    public let confidenceLevel: Double
    /// Log-ratio interval method.
    public let logRatioIntervalIdentifier: String
    /// Odds-ratio interval method.
    public let oddsRatioIntervalIdentifier: String
    /// P-value implementation and distribution identity.
    public let pValueIdentifier: String
    /// Multiple-comparison method identity.
    public let correctionIdentifier: String
    /// Odds-ratio method identity.
    public let oddsRatioIdentifier: String
    /// Signed log-ratio method identity.
    public let logRatioIdentifier: String
    /// Expected-count diagnostic identity.
    public let diagnosticIdentifier: String
    /// Resolved diagnostic threshold.
    public let lowExpectedCountThreshold: Double
    /// Determinism class of floating-point results.
    public let floatingPointDeterminismClass: String
    /// Versioned numeric policy.
    public let numericPolicyIdentifier: String
    /// Absolute tolerance applied by the reference seed.
    public let referenceAbsoluteTolerance: Double
    /// Declared deterministic row ordering.
    public let orderingIdentifier: String
    /// Complete multiple-comparison family.
    public let terms: [GlifiStudioKeynessTerm]

    init(_ result: GlifiProjectKeynessResult) {
        let comparison = result.comparison
        projectID = result.projectID.canonicalValue
        sourceGeneration = result.sourceGeneration
        generation = result.generation
        artifactID = result.artifactID.canonicalValue
        analysisNodeID = result.analysisNodeID.canonicalValue
        comparisonIdentifier = comparison.comparisonIdentifier
        comparisonDigest = comparison.comparisonDigest
        targetCorpusDigest = comparison.targetCorpusDigest
        referenceCorpusDigest = comparison.referenceCorpusDigest
        targetSourceRevisionIDs = comparison.targetSourceRevisionIDs.map(\.canonicalValue)
        referenceSourceRevisionIDs = comparison.referenceSourceRevisionIDs.map(\.canonicalValue)
        targetTokenCount = comparison.targetTokenCount
        referenceTokenCount = comparison.referenceTokenCount
        testIdentifier = comparison.testIdentifier
        testSelectionIdentifier = comparison.testSelectionIdentifier
        exactTestIdentifier = comparison.exactTestIdentifier
        confidenceLevel = comparison.confidenceLevel
        logRatioIntervalIdentifier = comparison.logRatioIntervalIdentifier
        oddsRatioIntervalIdentifier = comparison.oddsRatioIntervalIdentifier
        pValueIdentifier = comparison.pValueIdentifier
        correctionIdentifier = comparison.correctionIdentifier
        oddsRatioIdentifier = comparison.oddsRatioIdentifier
        logRatioIdentifier = comparison.logRatioIdentifier
        diagnosticIdentifier = comparison.diagnosticIdentifier
        lowExpectedCountThreshold = comparison.lowExpectedCountThreshold
        floatingPointDeterminismClass = comparison.floatingPointDeterminismClass
        numericPolicyIdentifier = comparison.numericPolicyIdentifier
        referenceAbsoluteTolerance = comparison.referenceAbsoluteTolerance
        orderingIdentifier = comparison.orderingIdentifier
        terms = comparison.terms.map(GlifiStudioKeynessTerm.init)
    }
}
