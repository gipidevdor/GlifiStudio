// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Bounded parameters of one two-group keyness comparison.
public struct GlifiKeynessOptions: Equatable, Sendable {
    /// Conservative defaults for the first inferential slice.
    public static let standard = GlifiKeynessOptions(
        validatedMaximumHypothesisCount: 100_000,
        lowExpectedCountThreshold: 5,
        confidenceLevel: 0.95
    )

    /// Largest admitted multiple-comparison family.
    public let maximumHypothesisCount: Int
    /// Threshold below which the asymptotic diagnostic is raised.
    public let lowExpectedCountThreshold: Double
    /// Level of the Katz and Woolf confidence intervals, in `(0, 1)`.
    public let confidenceLevel: Double

    /// Creates valid keyness bounds without silently correcting parameters.
    public init(
        maximumHypothesisCount: Int,
        lowExpectedCountThreshold: Double,
        confidenceLevel: Double = 0.95
    ) throws {
        guard maximumHypothesisCount >= 0,
            lowExpectedCountThreshold.isFinite,
            lowExpectedCountThreshold >= 0,
            confidenceLevel > 0, confidenceLevel < 1
        else {
            throw keynessFailure("keyness.invalid-options", category: .invalidInput)
        }
        self.init(
            validatedMaximumHypothesisCount: maximumHypothesisCount,
            lowExpectedCountThreshold: lowExpectedCountThreshold,
            confidenceLevel: confidenceLevel
        )
    }

    private init(
        validatedMaximumHypothesisCount: Int,
        lowExpectedCountThreshold: Double,
        confidenceLevel: Double
    ) {
        maximumHypothesisCount = validatedMaximumHypothesisCount
        self.lowExpectedCountThreshold = lowExpectedCountThreshold
        self.confidenceLevel = confidenceLevel
    }
}

/// Direction of a Haldane–Anscombe corrected log-ratio effect.
public enum GlifiKeynessDirection: String, Codable, Equatable, Sendable {
    /// The normalized term rate is higher in the target group.
    case target
    /// The normalized term rate is higher in the reference group.
    case reference
    /// The normalized term rates are equal.
    case equal
}

/// Complete G-test and effect-size result for one normalized term.
public struct GlifiKeynessTermResult: Codable, Equatable, Sendable {
    /// NFC, Italian-lowercased lexical form.
    public let term: String
    /// Exact occurrence count in the target group.
    public let targetFrequency: Int
    /// Exact occurrence count in the reference group.
    public let referenceFrequency: Int
    /// Target frequency divided by the target lexical-token count.
    public let targetRelativeFrequency: Double
    /// Reference frequency divided by the reference lexical-token count.
    public let referenceRelativeFrequency: Double
    /// `GTest-v1` likelihood-ratio statistic.
    public let gStatistic: Double
    /// Degrees of freedom of the non-degenerate 2×2 table.
    public let degreesOfFreedom: Int
    /// Raw p-value of the test selected by `FisherSelection-min-expected-5-v1`.
    public let pValue: Double
    /// `GTest-v1` asymptotic p-value, kept for every term.
    public let gTestPValue: Double
    /// `GTest-v1` or `FisherExactTwoSided-v1`, selected from the margins only.
    public let selectedTestIdentifier: String
    /// Benjamini–Hochberg adjusted q-value over the declared family.
    public let qValue: Double
    /// `OddsRatio-HA-v1` effect size.
    public let oddsRatioHaldaneAnscombe: Double
    /// `LogRatio-HA-v1` effect size in base two.
    public let log2RatioHaldaneAnscombe: Double
    /// Lower bound of `LogRatioCI-Katz-HA-v1`, base two.
    public let log2RatioLower: Double
    /// Upper bound of `LogRatioCI-Katz-HA-v1`, base two.
    public let log2RatioUpper: Double
    /// Lower bound of `OddsRatioCI-Woolf-HA-v1`.
    public let oddsRatioLower: Double
    /// Upper bound of `OddsRatioCI-Woolf-HA-v1`.
    public let oddsRatioUpper: Double
    /// Direction derived only from the signed log ratio.
    public let direction: GlifiKeynessDirection
    /// Smallest expected cell count in the term's 2×2 table.
    public let minimumExpectedCount: Double
    /// Whether the expected-count diagnostic threshold was crossed.
    public let hasLowExpectedCount: Bool
}

/// Deterministic two-group keyness result with explicit population lineage.
public struct GlifiKeynessComparison: Codable, Equatable, Sendable {
    /// Versioned aggregate comparison contract.
    public let comparisonIdentifier: String
    /// Digest of groups, methods, thresholds, and ordering.
    public let comparisonDigest: String
    /// Digest of the target corpus profile.
    public let targetCorpusDigest: String
    /// Digest of the reference corpus profile.
    public let referenceCorpusDigest: String
    /// Canonically ordered target source revisions.
    public let targetSourceRevisionIDs: [SourceRevisionID]
    /// Canonically ordered reference source revisions.
    public let referenceSourceRevisionIDs: [SourceRevisionID]
    /// Number of target lexical tokens.
    public let targetTokenCount: Int
    /// Number of reference lexical tokens.
    public let referenceTokenCount: Int
    /// Statistical-test method identity.
    public let testIdentifier: String
    /// Rule that selects the exact test from the margins.
    public let testSelectionIdentifier: String
    /// Exact test used when the rule applies.
    public let exactTestIdentifier: String
    /// Confidence level of the intervals.
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
    /// Versioned expected-count diagnostic.
    public let diagnosticIdentifier: String
    /// Resolved threshold used by the expected-count diagnostic.
    public let lowExpectedCountThreshold: Double
    /// Determinism class for floating-point results.
    public let floatingPointDeterminismClass: String
    /// Versioned numeric precision and ordered-reduction policy.
    public let numericPolicyIdentifier: String
    /// Absolute tolerance applied by the reference seed.
    public let referenceAbsoluteTolerance: Double
    /// Declared deterministic final ordering.
    public let orderingIdentifier: String
    /// Complete comparison family in declared order.
    public let terms: [GlifiKeynessTermResult]
}

/// Computes the first bounded keyness comparison from compatible corpus profiles.
public struct GlifiKeynessAnalyzer: Sendable {
    /// Versioned identity of this comparison bundle.
    public static let comparisonIdentifier = "keyness-gtest-fisher-ha-ci-bh-v2"
    /// Pre-registered test-selection rule (Cochran 1954).
    public static let testSelectionIdentifier = "FisherSelection-min-expected-5-v1"

    /// Creates a stateless keyness analyzer.
    public init() {}

    /// Compares disjoint target and reference populations with fixed method variants.
    public func compare(
        target: GlifiCorpusAnalysis,
        reference: GlifiCorpusAnalysis,
        options: GlifiKeynessOptions = .standard
    ) throws -> GlifiKeynessComparison {
        try Task.checkCancellation()
        guard target.tokenizationContractIdentifier == reference.tokenizationContractIdentifier,
            target.normalizationIdentifier == reference.normalizationIdentifier
        else {
            throw keynessFailure("keyness.incompatible-linguistic-contracts")
        }
        guard !target.sourceRevisionIDs.isEmpty, !reference.sourceRevisionIDs.isEmpty else {
            throw keynessFailure("keyness.empty-group", category: .insufficientData)
        }
        let targetIDs = Set(target.sourceRevisionIDs)
        let referenceIDs = Set(reference.sourceRevisionIDs)
        guard targetIDs.count == target.sourceRevisionIDs.count,
            referenceIDs.count == reference.sourceRevisionIDs.count
        else {
            throw keynessFailure("keyness.duplicate-source", category: .invalidInput)
        }
        guard targetIDs.isDisjoint(with: referenceIDs) else {
            throw keynessFailure("keyness.overlapping-groups", category: .invalidInput)
        }
        guard target.lexicalTokenCount > 0, reference.lexicalTokenCount > 0 else {
            throw keynessFailure("keyness.empty-token-population", category: .insufficientData)
        }

        let targetCounts = Dictionary(
            uniqueKeysWithValues: target.terms.map {
                ($0.term, $0.frequency)
            })
        let referenceCounts = Dictionary(
            uniqueKeysWithValues: reference.terms.map {
                ($0.term, $0.frequency)
            })
        let terms = Set(targetCounts.keys).union(referenceCounts.keys).sorted()
        guard !terms.isEmpty else {
            throw keynessFailure("keyness.empty-family", category: .insufficientData)
        }
        guard terms.count <= options.maximumHypothesisCount else {
            throw keynessFailure(
                "keyness.hypothesis-limit-exceeded",
                category: .insufficientResources
            )
        }

        var provisional: [ProvisionalKeynessTerm] = []
        provisional.reserveCapacity(terms.count)
        for (position, term) in terms.enumerated() {
            if position.isMultiple(of: 4_096) { try Task.checkCancellation() }
            provisional.append(
                try evaluate(
                    term: term,
                    targetFrequency: targetCounts[term, default: 0],
                    referenceFrequency: referenceCounts[term, default: 0],
                    targetTokenCount: target.lexicalTokenCount,
                    referenceTokenCount: reference.lexicalTokenCount,
                    lowExpectedCountThreshold: options.lowExpectedCountThreshold,
                    criticalValue: try GlifiDistributionFunctions.normalQuantile(
                        (1 + options.confidenceLevel) / 2)
                )
            )
        }
        let adjustedPValues = benjaminiHochberg(provisional)
        var results = zip(provisional, adjustedPValues).map { row, qValue in
            GlifiKeynessTermResult(
                term: row.term,
                targetFrequency: row.targetFrequency,
                referenceFrequency: row.referenceFrequency,
                targetRelativeFrequency: row.targetRelativeFrequency,
                referenceRelativeFrequency: row.referenceRelativeFrequency,
                gStatistic: row.gStatistic,
                degreesOfFreedom: 1,
                pValue: row.pValue,
                gTestPValue: row.gTestPValue,
                selectedTestIdentifier: row.selectedTestIdentifier,
                qValue: qValue,
                oddsRatioHaldaneAnscombe: row.oddsRatioHaldaneAnscombe,
                log2RatioHaldaneAnscombe: row.log2RatioHaldaneAnscombe,
                log2RatioLower: row.log2RatioLower,
                log2RatioUpper: row.log2RatioUpper,
                oddsRatioLower: row.oddsRatioLower,
                oddsRatioUpper: row.oddsRatioUpper,
                direction: row.direction,
                minimumExpectedCount: row.minimumExpectedCount,
                hasLowExpectedCount: row.hasLowExpectedCount
            )
        }
        results.sort {
            let leftMagnitude = abs($0.log2RatioHaldaneAnscombe)
            let rightMagnitude = abs($1.log2RatioHaldaneAnscombe)
            return leftMagnitude == rightMagnitude
                ? $0.term < $1.term : leftMagnitude > rightMagnitude
        }

        return GlifiKeynessComparison(
            comparisonIdentifier: Self.comparisonIdentifier,
            comparisonDigest: try comparisonDigest(
                target: target,
                reference: reference,
                options: options
            ),
            targetCorpusDigest: target.corpusDigest,
            referenceCorpusDigest: reference.corpusDigest,
            targetSourceRevisionIDs: target.sourceRevisionIDs,
            referenceSourceRevisionIDs: reference.sourceRevisionIDs,
            targetTokenCount: target.lexicalTokenCount,
            referenceTokenCount: reference.lexicalTokenCount,
            testIdentifier: "GTest-v1",
            testSelectionIdentifier: Self.testSelectionIdentifier,
            exactTestIdentifier: "FisherExactTwoSided-v1",
            confidenceLevel: options.confidenceLevel,
            logRatioIntervalIdentifier: "LogRatioCI-Katz-HA-v1",
            oddsRatioIntervalIdentifier: "OddsRatioCI-Woolf-HA-v1",
            pValueIdentifier: "ChiSquareSurvival-df1-erfc-v1",
            correctionIdentifier: "BenjaminiHochberg-v1",
            oddsRatioIdentifier: "OddsRatio-HA-v1",
            logRatioIdentifier: "LogRatio-HA-v1-base2",
            diagnosticIdentifier: "asymptotic-minimum-expected-count-v1",
            lowExpectedCountThreshold: options.lowExpectedCountThreshold,
            floatingPointDeterminismClass: "D1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            referenceAbsoluteTolerance: 1e-12,
            orderingIdentifier: "absolute-log-ratio-descending-term-ascending-v1",
            terms: results
        )
    }

    private func evaluate(
        term: String,
        targetFrequency: Int,
        referenceFrequency: Int,
        targetTokenCount: Int,
        referenceTokenCount: Int,
        lowExpectedCountThreshold: Double,
        criticalValue: Double
    ) throws -> ProvisionalKeynessTerm {
        let targetOther = targetTokenCount - targetFrequency
        let referenceOther = referenceTokenCount - referenceFrequency
        let termTotal = targetFrequency + referenceFrequency
        let otherTotal = targetOther + referenceOther
        guard termTotal > 0, otherTotal > 0 else {
            throw keynessFailure("keyness.degenerate-margin", category: .insufficientData)
        }

        let total = Double(targetTokenCount) + Double(referenceTokenCount)
        let targetExpectedTerm = Double(targetTokenCount) * Double(termTotal) / total
        let targetExpectedOther = Double(targetTokenCount) * Double(otherTotal) / total
        let referenceExpectedTerm = Double(referenceTokenCount) * Double(termTotal) / total
        let referenceExpectedOther = Double(referenceTokenCount) * Double(otherTotal) / total
        let observations = [
            Double(targetFrequency), Double(targetOther),
            Double(referenceFrequency), Double(referenceOther),
        ]
        let expected = [
            targetExpectedTerm, targetExpectedOther,
            referenceExpectedTerm, referenceExpectedOther,
        ]
        guard expected.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw keynessFailure("keyness.invalid-expected-count", category: .invariantViolation)
        }
        let gStatistic =
            2
            * zip(observations, expected).reduce(0.0) { result, pair in
                pair.0 == 0 ? result : result + pair.0 * log(pair.0 / pair.1)
            }
        let pValue = erfc(sqrt(max(0, gStatistic) / 2))
        let adjustedTargetRate =
            (Double(targetFrequency) + 0.5) / (Double(targetTokenCount) + 1)
        let adjustedReferenceRate =
            (Double(referenceFrequency) + 0.5) / (Double(referenceTokenCount) + 1)
        let log2Ratio = log2(adjustedTargetRate / adjustedReferenceRate)
        let oddsRatio =
            ((Double(targetFrequency) + 0.5) / (Double(targetOther) + 0.5))
            / ((Double(referenceFrequency) + 0.5) / (Double(referenceOther) + 0.5))
        let minimumExpectedCount = expected.min() ?? 0
        // FisherSelection-min-expected-5-v1: dipende solo dai margini, mai dal p-value.
        let usesExactTest = minimumExpectedCount < 5
        let selectedPValue =
            usesExactTest
            ? try GlifiStatisticalFoundation.fisherExact([
                [targetFrequency, targetOther], [referenceFrequency, referenceOther],
            ]).pValue
            : min(max(pValue, 0), 1)
        // LogRatioCI-Katz-HA-v1 e OddsRatioCI-Woolf-HA-v1 sui conteggi corretti.
        let a = Double(targetFrequency) + 0.5
        let b = Double(targetOther) + 0.5
        let c = Double(referenceFrequency) + 0.5
        let d = Double(referenceOther) + 0.5
        let rateError =
            (1 / a - 1 / (Double(targetTokenCount) + 1) + 1 / c
            - 1 / (Double(referenceTokenCount) + 1)).squareRoot()
        let oddsError = (1 / a + 1 / b + 1 / c + 1 / d).squareRoot()
        let naturalLogRatio = log(adjustedTargetRate / adjustedReferenceRate)
        return ProvisionalKeynessTerm(
            term: term,
            targetFrequency: targetFrequency,
            referenceFrequency: referenceFrequency,
            targetRelativeFrequency: Double(targetFrequency) / Double(targetTokenCount),
            referenceRelativeFrequency: Double(referenceFrequency) / Double(referenceTokenCount),
            gStatistic: max(0, gStatistic),
            pValue: min(max(selectedPValue, 0), 1),
            gTestPValue: min(max(pValue, 0), 1),
            selectedTestIdentifier: usesExactTest ? "FisherExactTwoSided-v1" : "GTest-v1",
            oddsRatioHaldaneAnscombe: oddsRatio,
            log2RatioHaldaneAnscombe: log2Ratio,
            log2RatioLower: (naturalLogRatio - criticalValue * rateError) / log(2),
            log2RatioUpper: (naturalLogRatio + criticalValue * rateError) / log(2),
            oddsRatioLower: exp(log(oddsRatio) - criticalValue * oddsError),
            oddsRatioUpper: exp(log(oddsRatio) + criticalValue * oddsError),
            direction: log2Ratio > 0 ? .target : (log2Ratio < 0 ? .reference : .equal),
            minimumExpectedCount: minimumExpectedCount,
            hasLowExpectedCount: minimumExpectedCount < lowExpectedCountThreshold
        )
    }

    private func benjaminiHochberg(_ rows: [ProvisionalKeynessTerm]) -> [Double] {
        let orderedIndices = rows.indices.sorted {
            rows[$0].pValue == rows[$1].pValue
                ? rows[$0].term < rows[$1].term : rows[$0].pValue < rows[$1].pValue
        }
        var result = Array(repeating: 1.0, count: rows.count)
        var runningMinimum = 1.0
        for reversePosition in orderedIndices.indices.reversed() {
            let originalIndex = orderedIndices[reversePosition]
            let rank = reversePosition + 1
            let candidate = Double(rows.count) * rows[originalIndex].pValue / Double(rank)
            runningMinimum = min(runningMinimum, min(candidate, 1))
            result[originalIndex] = runningMinimum
        }
        return result
    }

    private func comparisonDigest(
        target: GlifiCorpusAnalysis,
        reference: GlifiCorpusAnalysis,
        options: GlifiKeynessOptions
    ) throws -> String {
        struct DigestInput: Encodable {
            let comparisonIdentifier: String
            let targetCorpusDigest: String
            let referenceCorpusDigest: String
            let lowExpectedCountThreshold: Double
            let confidenceLevel: Double
            let orderingIdentifier: String
        }
        let value = DigestInput(
            comparisonIdentifier: Self.comparisonIdentifier,
            targetCorpusDigest: target.corpusDigest,
            referenceCorpusDigest: reference.corpusDigest,
            lowExpectedCountThreshold: options.lowExpectedCountThreshold,
            confidenceLevel: options.confidenceLevel,
            orderingIdentifier: "absolute-log-ratio-descending-term-ascending-v1"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let hash = SHA256.hash(data: try encoder.encode(value))
        return "sha256:" + hash.map { String(format: "%02x", $0) }.joined()
    }
}

private struct ProvisionalKeynessTerm {
    let term: String
    let targetFrequency: Int
    let referenceFrequency: Int
    let targetRelativeFrequency: Double
    let referenceRelativeFrequency: Double
    let gStatistic: Double
    let pValue: Double
    let gTestPValue: Double
    let selectedTestIdentifier: String
    let oddsRatioHaldaneAnscombe: Double
    let log2RatioHaldaneAnscombe: Double
    let log2RatioLower: Double
    let log2RatioUpper: Double
    let oddsRatioLower: Double
    let oddsRatioUpper: Double
    let direction: GlifiKeynessDirection
    let minimumExpectedCount: Double
    let hasLowExpectedCount: Bool
}

func keynessFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}
