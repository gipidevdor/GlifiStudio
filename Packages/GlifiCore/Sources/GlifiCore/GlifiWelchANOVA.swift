// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// `WelchOneWayANOVA-v1`: an omnibus test of independent group means without equal variances.
public struct GlifiWelchANOVAResult: Equatable, Sendable {
    /// Versioned numerical identity; distinct from the equal-variance ANOVA.
    public static let identifier = "WelchOneWayANOVA-v1"
    /// Welch's variance-corrected F statistic.
    public let fStatistic: Double
    /// Number of groups minus one.
    public let numeratorDegreesOfFreedom: Int
    /// Welch–Satterthwaite denominator degrees of freedom.
    public let denominatorDegreesOfFreedom: Double
    /// Upper-tail F approximation; not a post-hoc group comparison.
    public let pValue: Double
}

extension GlifiStatisticalFoundation {
    /// Maximum groups evaluated by the in-memory Welch omnibus test.
    public static let maximumWelchANOVAGroupCount = 100_000
    /// Maximum aggregate observations evaluated by the in-memory Welch omnibus test.
    public static let maximumWelchANOVAObservationCount = 1_000_000

    /// Tests equality of `k ≥ 2` independent normal-population means (Welch, 1951).
    ///
    /// Each group requires at least two finite observations and positive sample variance.
    /// No observations are excluded. A common power-of-two scale preserves the statistic
    /// while avoiding overflow in squared observations. Unrepresentable intermediate
    /// variances or statistics fail explicitly. Time is linear in observations; auxiliary
    /// storage is linear in groups. The result is an omnibus inference, with post-hoc tests
    /// and their multiplicity family specified separately (GS-MET-001-21).
    public static func welchOneWayANOVA(_ groups: [[Double]]) throws -> GlifiWelchANOVAResult {
        try Task.checkCancellation()
        guard groups.count >= 2 else {
            throw welchANOVAFailure("statistics.insufficient-group-count")
        }
        guard groups.count <= maximumWelchANOVAGroupCount else {
            throw welchANOVAFailure("statistics.limit-exceeded", category: .invalidInput)
        }
        var observationCount = 0
        var largest = 0.0
        let anchor = groups[0].first ?? 0
        var largestOffset = 0.0
        var needsPrescaling = false
        for group in groups {
            try Task.checkCancellation()
            guard group.count >= 2 else {
                throw welchANOVAFailure("statistics.insufficient-sample-size")
            }
            guard group.count <= maximumWelchANOVAObservationCount - observationCount else {
                throw welchANOVAFailure("statistics.limit-exceeded", category: .invalidInput)
            }
            observationCount += group.count
            for (index, value) in group.enumerated() {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                guard value.isFinite else {
                    throw welchANOVAFailure("statistics.non-finite-value", category: .invalidInput)
                }
                largest = max(largest, abs(value))
                let difference = value - anchor
                if difference.isFinite {
                    largestOffset = max(largestOffset, abs(difference))
                } else {
                    needsPrescaling = true
                }
            }
        }
        guard largest > 0 else {
            throw welchANOVAFailure("statistics.non-positive-variance")
        }
        // Subtract one common observed anchor before means to preserve small between-
        // and within-group variation at a large offset. Prescale only if subtraction
        // would overflow for opposite signs near binary64's maximum magnitude.
        let inputScale =
            needsPrescaling
            ? Double(sign: .plus, exponent: largest.exponent, significand: 1) : 1
        let scaledAnchor = anchor / inputScale
        if needsPrescaling {
            largestOffset = 0
            for group in groups {
                for (index, value) in group.enumerated() {
                    if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                    largestOffset = max(largestOffset, abs(value / inputScale - scaledAnchor))
                }
            }
        }
        guard largestOffset > 0 else {
            throw welchANOVAFailure("statistics.non-positive-variance")
        }
        let scale = Double(sign: .plus, exponent: largestOffset.exponent, significand: 1)
        func coordinate(_ value: Double) -> Double {
            (value / inputScale - scaledAnchor) / scale
        }
        var means: [Double] = []
        var variancesOverCounts: [Double] = []
        for group in groups {
            try Task.checkCancellation()
            let count = Double(group.count)
            let groupAnchor = group[0]
            let anchorCoordinate = coordinate(groupAnchor)
            // A common anchor alone leaves distant groups with a large offset when
            // computing their own variance. Subtract a local observed anchor first,
            // while retaining the same common scale for every group's means/variance.
            func localCoordinate(_ value: Double) -> Double {
                let difference = value - groupAnchor
                if difference.isFinite { return (difference / inputScale) / scale }
                // Opposite extreme signs may overflow the raw local subtraction.
                // Their bounded common coordinates can be subtracted safely instead.
                return coordinate(value) - anchorCoordinate
            }
            var sum = 0.0
            for (index, value) in group.enumerated() {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                sum += localCoordinate(value)
            }
            let localMean = sum / count
            var sumOfSquares = 0.0
            for (index, value) in group.enumerated() {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let difference = localCoordinate(value) - localMean
                sumOfSquares += difference * difference
            }
            let variance = sumOfSquares / Double(group.count - 1)
            guard variance > 0 else {
                throw welchANOVAFailure("statistics.non-positive-variance")
            }
            let varianceOverCount = variance / count
            guard varianceOverCount.isFinite, varianceOverCount > 0 else {
                throw welchANOVAFailure("statistics.non-finite-result", category: .invalidInput)
            }
            means.append(anchorCoordinate + localMean)
            variancesOverCounts.append(varianceOverCount)
        }
        // Ratios of inverse variances avoid constructing overflowing inverse weights.
        let minimum = variancesOverCounts.min() ?? 1
        let relativeWeights = variancesOverCounts.map { minimum / $0 }
        let totalWeight = relativeWeights.reduce(0, +)
        let weightedMean =
            zip(relativeWeights, means).reduce(0.0) { $0 + $1.0 * $1.1 }
            / totalWeight
        let groupCount = Double(groups.count)
        let correctionSum = groups.indices.reduce(0.0) {
            let remainder = 1 - relativeWeights[$1] / totalWeight
            return $0 + remainder * remainder / Double(groups[$1].count - 1)
        }
        let correction = correctionSum / (groupCount * groupCount - 1)
        let between = means.indices.reduce(0.0) {
            let difference = means[$1] - weightedMean
            return $0 + difference * difference / variancesOverCounts[$1]
        }
        let statistic = between / ((groupCount - 1) * (1 + 2 * (groupCount - 2) * correction))
        let denominatorDegrees = 1 / (3 * correction)
        guard statistic.isFinite, denominatorDegrees.isFinite else {
            throw welchANOVAFailure("statistics.non-finite-result", category: .invalidInput)
        }
        let probability = try fDistributionUpperTailPValue(
            statistic: statistic,
            numeratorDegreesOfFreedom: groupCount - 1,
            denominatorDegreesOfFreedom: denominatorDegrees
        )
        return GlifiWelchANOVAResult(
            fStatistic: statistic,
            numeratorDegreesOfFreedom: groups.count - 1,
            denominatorDegreesOfFreedom: denominatorDegrees,
            pValue: probability
        )
    }
}

private func welchANOVAFailure(
    _ code: String,
    category: GlifiFailureCategory = .insufficientData
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category), messageKey: "failure.\(code)"
    )
}
