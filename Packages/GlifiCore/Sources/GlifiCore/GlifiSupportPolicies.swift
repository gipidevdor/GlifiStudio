// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Outcome of one family `SupportPolicy` (ADR-0026): class, deciding dimensions and rationale.
public struct GlifiSupportOutcome: Codable, Equatable, Sendable {
    /// Versioned policy identity.
    public let policyIdentifier: String
    /// Resulting support class; `insufficient` when the result is not eligible.
    public let supportClass: GlifiSupportClass
    /// Measured dimensions that determined the class, in declaration order.
    public let dimensions: [GlifiEvidenceAssessmentDimension]
    /// Stable rationale identifiers, including every caution cause.
    public let rationaleIdentifiers: [String]
}

/// Executable support policies of ADR-0026, one per analytical family.
///
/// Thresholds come from published conventions (see the ADR) and are product policy, not
/// universal truth; a class never replaces the dimensions that produced it.
public enum GlifiSupportPolicies {
    /// `support-policy.contingency-cramersv-v1`: Cohen's w thresholds scaled by `√d*`.
    public static func contingency(
        cramersV: Double,
        minimumDimension: Int,
        monteCarloPValue: Double,
        lowExpectedCellFraction: Double
    ) -> GlifiSupportOutcome {
        let scale = Double(max(minimumDimension - 1, 1)).squareRoot()
        let (small, medium, large) = (0.1 / scale, 0.3 / scale, 0.5 / scale)
        var supportClass: GlifiSupportClass
        var rationale: [String]
        if monteCarloPValue > 0.05 || cramersV < small {
            supportClass = .insufficient
            rationale = ["support.not-eligible"]
        } else if cramersV >= large, monteCarloPValue <= 0.01 {
            (supportClass, rationale) = (.strong, ["support.large-effect"])
        } else if cramersV >= medium {
            (supportClass, rationale) = (.moderate, ["support.medium-effect"])
        } else {
            (supportClass, rationale) = (.weak, ["support.small-effect"])
        }
        if supportClass != .insufficient, lowExpectedCellFraction > 0.2 {
            supportClass = .caution
            rationale.append("support.caution.low-expected-counts")
        }
        return GlifiSupportOutcome(
            policyIdentifier: "support-policy.contingency-cramersv-v1",
            supportClass: supportClass,
            dimensions: [
                dimension("cramers-v", cramersV, "effect-size"),
                dimension("monte-carlo-p", monteCarloPValue, "significance"),
                dimension("low-expected-cell-fraction", lowExpectedCellFraction, "diagnostic"),
            ],
            rationaleIdentifiers: rationale
        )
    }

    /// `support-policy.group-location-hedges-v1`: Cohen's d thresholds on Hedges' g.
    public static func groupLocation(
        hedgesG: Double,
        pValue: Double,
        smallestGroupSize: Int
    ) -> GlifiSupportOutcome {
        let magnitude = abs(hedgesG)
        var supportClass: GlifiSupportClass
        var rationale: [String]
        if pValue > 0.05 || magnitude < 0.2 {
            (supportClass, rationale) = (.insufficient, ["support.not-eligible"])
        } else if magnitude >= 0.8, pValue <= 0.01 {
            (supportClass, rationale) = (.strong, ["support.large-effect"])
        } else if magnitude >= 0.5 {
            (supportClass, rationale) = (.moderate, ["support.medium-effect"])
        } else {
            (supportClass, rationale) = (.weak, ["support.small-effect"])
        }
        if supportClass != .insufficient, smallestGroupSize < 5 {
            supportClass = .caution
            rationale.append("support.caution.small-groups")
        }
        return GlifiSupportOutcome(
            policyIdentifier: "support-policy.group-location-hedges-v1",
            supportClass: supportClass,
            dimensions: [
                dimension("hedges-g", hedgesG, "effect-size"),
                dimension("p-value", pValue, "significance"),
                .init(
                    identifier: "smallest-group-size",
                    value: .integer(Int64(smallestGroupSize)),
                    outcomeIdentifier: "diagnostic"
                ),
            ],
            rationaleIdentifiers: rationale
        )
    }

    /// `support-policy.collocation-tscore-npmi-v1`: frequency floor, t-score and NPMI.
    public static func collocation(
        jointCount: Int,
        tScore: Double?,
        npmi: Double?
    ) -> GlifiSupportOutcome {
        var supportClass: GlifiSupportClass
        var rationale: [String]
        if let t = tScore, let n = npmi, jointCount >= 3, t >= 2, n > 0 {
            if n >= 0.5, jointCount >= 5 {
                (supportClass, rationale) = (.strong, ["support.strong-association"])
            } else if n >= 0.25 {
                (supportClass, rationale) = (.moderate, ["support.moderate-association"])
            } else {
                (supportClass, rationale) = (.weak, ["support.weak-association"])
            }
            if jointCount < 5 {
                supportClass = .caution
                rationale.append("support.caution.low-frequency")
            }
        } else {
            (supportClass, rationale) = (.insufficient, ["support.not-eligible"])
        }
        return GlifiSupportOutcome(
            policyIdentifier: "support-policy.collocation-tscore-npmi-v1",
            supportClass: supportClass,
            dimensions: [
                .init(
                    identifier: "joint-count",
                    value: .integer(Int64(jointCount)),
                    outcomeIdentifier: "frequency"
                ),
                dimension("t-score", tScore ?? .nan, "significance"),
                dimension("npmi", npmi ?? .nan, "effect-size"),
            ],
            rationaleIdentifiers: rationale
        )
    }

    /// `support-policy.community-modularity-v1`: Newman–Girvan modularity bands.
    public static func community(modularity: Double, nodeCount: Int) -> GlifiSupportOutcome {
        var supportClass: GlifiSupportClass
        var rationale: [String]
        if modularity < 0.3 {
            (supportClass, rationale) = (.insufficient, ["support.not-eligible"])
        } else if modularity >= 0.5 {
            (supportClass, rationale) = (.strong, ["support.strong-structure"])
        } else {
            (supportClass, rationale) = (.moderate, ["support.moderate-structure"])
        }
        if supportClass != .insufficient, nodeCount < 10 {
            supportClass = .caution
            rationale.append("support.caution.small-network")
        }
        return GlifiSupportOutcome(
            policyIdentifier: "support-policy.community-modularity-v1",
            supportClass: supportClass,
            dimensions: [
                dimension("modularity", modularity, "effect-size"),
                .init(
                    identifier: "node-count",
                    value: .integer(Int64(nodeCount)),
                    outcomeIdentifier: "diagnostic"
                ),
            ],
            rationaleIdentifiers: rationale
        )
    }

    /// `support-policy.clustering-silhouette-v1`: Kaufman–Rousseeuw silhouette bands.
    public static func clustering(
        averageSilhouette: Double,
        smallestClusterSize: Int
    ) -> GlifiSupportOutcome {
        var supportClass: GlifiSupportClass
        var rationale: [String]
        if averageSilhouette <= 0.25 {
            (supportClass, rationale) = (.insufficient, ["support.no-substantial-structure"])
        } else if averageSilhouette > 0.7 {
            (supportClass, rationale) = (.strong, ["support.strong-structure"])
        } else if averageSilhouette > 0.5 {
            (supportClass, rationale) = (.moderate, ["support.reasonable-structure"])
        } else {
            (supportClass, rationale) = (.weak, ["support.weak-structure"])
        }
        if supportClass != .insufficient, smallestClusterSize < 2 {
            supportClass = .caution
            rationale.append("support.caution.singleton-cluster")
        }
        return GlifiSupportOutcome(
            policyIdentifier: "support-policy.clustering-silhouette-v1",
            supportClass: supportClass,
            dimensions: [
                dimension("average-silhouette", averageSilhouette, "effect-size"),
                .init(
                    identifier: "smallest-cluster-size",
                    value: .integer(Int64(smallestClusterSize)),
                    outcomeIdentifier: "diagnostic"
                ),
            ],
            rationaleIdentifiers: rationale
        )
    }

    /// `support-policy.correspondence-axis-v1`: average-inertia rule for one CA axis.
    public static func correspondenceAxis(
        inertiaShare: Double,
        axisCount: Int,
        totalInertia: Double
    ) -> GlifiSupportOutcome {
        let average = 1 / Double(max(axisCount, 1))
        var supportClass: GlifiSupportClass
        var rationale: [String]
        if inertiaShare <= average {
            (supportClass, rationale) = (.insufficient, ["support.below-average-inertia"])
        } else if inertiaShare >= 2 * average {
            (supportClass, rationale) = (.strong, ["support.dominant-axis"])
        } else {
            (supportClass, rationale) = (.moderate, ["support.above-average-axis"])
        }
        if supportClass != .insufficient, totalInertia < 0.05 {
            supportClass = .caution
            rationale.append("support.caution.low-total-inertia")
        }
        return GlifiSupportOutcome(
            policyIdentifier: "support-policy.correspondence-axis-v1",
            supportClass: supportClass,
            dimensions: [
                dimension("inertia-share", inertiaShare, "effect-size"),
                dimension("average-share", average, "reference"),
                dimension("total-inertia", totalInertia, "diagnostic"),
            ],
            rationaleIdentifiers: rationale
        )
    }

    /// `support-policy.similarity-descriptive-v1`: never a strength label.
    public static func similarity(sharedTypeCount: Int) -> GlifiSupportOutcome {
        GlifiSupportOutcome(
            policyIdentifier: "support-policy.similarity-descriptive-v1",
            supportClass: sharedTypeCount < 10 ? .caution : .descriptive,
            dimensions: [
                .init(
                    identifier: "shared-type-count",
                    value: .integer(Int64(sharedTypeCount)),
                    outcomeIdentifier: "diagnostic"
                )
            ],
            rationaleIdentifiers: sharedTypeCount < 10
                ? ["support.descriptive-only", "support.caution.small-shared-vocabulary"]
                : ["support.descriptive-only"]
        )
    }

    private static func dimension(
        _ identifier: String,
        _ value: Double,
        _ outcome: String
    ) -> GlifiEvidenceAssessmentDimension {
        GlifiEvidenceAssessmentDimension(
            identifier: identifier,
            value: value.isFinite ? .decimal(value) : .text("undefined"),
            outcomeIdentifier: outcome
        )
    }
}

extension GlifiMultivariateMethods {
    /// Silhouette widths (Rousseeuw 1987) with Euclidean distances; singletons get 0.
    public static func silhouette(
        _ points: [[Double]],
        assignments: [Int]
    ) throws -> (widths: [Double], average: Double) {
        try GlifiSilhouetteComputation.calculate(points, assignments: assignments)
    }
}
