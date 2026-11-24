// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Unequal-variance omnibus comparison of independent group means.
public struct GlifiStudioWelchANOVAResult: Codable, Equatable, Sendable {
    /// This numerical variant remains a candidate under the scientific validation protocol.
    public static let validationStatus = "candidate"

    /// Versioned candidate numerical contract.
    public let methodIdentifier: String
    /// Welch's corrected F statistic.
    public let fStatistic: Double
    /// Number of groups minus one.
    public let numeratorDegreesOfFreedom: Int
    /// Welch–Satterthwaite denominator degrees of freedom.
    public let denominatorDegreesOfFreedom: Double
    /// Upper-tail F approximation, separate from post-hoc comparisons.
    public let pValue: Double

    init(_ value: GlifiWelchANOVAResult) {
        methodIdentifier = GlifiWelchANOVAResult.identifier
        fStatistic = value.fStatistic
        numeratorDegreesOfFreedom = value.numeratorDegreesOfFreedom
        denominatorDegreesOfFreedom = value.denominatorDegreesOfFreedom
        pValue = value.pValue
    }
}

extension GlifiStudioTextAnalytics {
    /// Evaluates `WelchOneWayANOVA-v1` off the caller's actor; no missing observations are inferred.
    @concurrent public static func welchOneWayANOVA(
        _ groups: [[Double]]
    ) async throws(GlifiStudioFailure) -> GlifiStudioWelchANOVAResult {
        do {
            try Task.checkCancellation()
            return try GlifiStudioWelchANOVAResult(
                GlifiStatisticalFoundation.welchOneWayANOVA(groups))
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch is CancellationError {
            throw GlifiStudioFailure(
                code: "analysis.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        } catch {
            throw GlifiStudioFailure(
                code: "analysis.failed", category: "insufficientData", operation: "analyze",
                retryDisposition: "afterCorrection", retainedState: "unchanged",
                messageKey: "failure.category.insufficientData")
        }
    }
}
