// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One pairwise comparison of a post-hoc procedure, groups `i < j` in request order.
public struct GlifiPostHocComparison: Equatable, Sendable {
    /// Zero-based index of the first group.
    public let firstGroupIndex: Int
    /// Zero-based index of the second group.
    public let secondGroupIndex: Int
    /// `x̄ᵢ - x̄ⱼ` (mean ranks for Dunn).
    public let difference: Double
    /// Test statistic: `q` for Tukey and Games–Howell, `z` for Dunn.
    public let statistic: Double
    /// Degrees of freedom of the reference distribution, `nil` for Dunn.
    public let degreesOfFreedom: Double?
    /// P-value already adjusted by the procedure (Tukey, Games–Howell) or raw (Dunn).
    public let pValue: Double
    /// Lower simultaneous confidence bound of the difference (Tukey only).
    public let lower: Double?
    /// Upper simultaneous confidence bound of the difference (Tukey only).
    public let upper: Double?
}

extension GlifiStatisticalFoundation {
    /// `TukeyHSD-v1` identity.
    public static let tukeyIdentifier = "TukeyHSD-v1"
    /// `GamesHowell-v1` identity.
    public static let gamesHowellIdentifier = "GamesHowell-v1"
    /// `Dunn-v1` identity.
    public static let dunnIdentifier = "Dunn-v1"

    /// `TukeyHSD-v1` (Tukey–Kramer for unequal sizes) with simultaneous intervals.
    ///
    /// `q = |x̄ᵢ-x̄ⱼ| / sqrt(MSE/2·(1/nᵢ+1/nⱼ))`, `MSE = SS_within/(N-k)`, p-value
    /// `P(Q_{k,N-k} > q)` and interval `x̄ᵢ-x̄ⱼ ± q_{1-α;k,N-k}·sqrt(MSE/2·(1/nᵢ+1/nⱼ))`.
    public static func tukeyHSD(
        _ groups: [[Double]],
        confidenceLevel: Double = 0.95
    ) throws -> [GlifiPostHocComparison] {
        try validatePostHocGroups(groups, minimumSize: 1)
        guard confidenceLevel > 0, confidenceLevel < 1 else {
            throw postHocFailure("statistics.invalid-confidence-level", category: .invalidInput)
        }
        let total = groups.reduce(0) { $0 + $1.count }
        let degrees = total - groups.count
        guard degrees > 0 else {
            throw postHocFailure("statistics.insufficient-sample-size")
        }
        let means = groups.map { $0.reduce(0, +) / Double($0.count) }
        let within = zip(groups, means).reduce(0.0) { result, pair in
            result + pair.0.reduce(0.0) { $0 + ($1 - pair.1) * ($1 - pair.1) }
        }
        let meanSquare = within / Double(degrees)
        guard meanSquare > 0 else {
            throw postHocFailure("statistics.degenerate-within-variance")
        }
        let critical = try studentizedRangeQuantile(
            confidenceLevel,
            groupCount: groups.count,
            degreesOfFreedom: Double(degrees)
        )
        return pairs(groups.count).map { first, second in
            let difference = means[first] - means[second]
            let scale =
                (meanSquare / 2
                * (1 / Double(groups[first].count) + 1 / Double(groups[second].count)))
                .squareRoot()
            let q = abs(difference) / scale
            return GlifiPostHocComparison(
                firstGroupIndex: first,
                secondGroupIndex: second,
                difference: difference,
                statistic: q,
                degreesOfFreedom: Double(degrees),
                pValue: GlifiDistributionFunctions.studentizedRangeUpperTail(
                    q,
                    groupCount: groups.count,
                    degreesOfFreedom: Double(degrees)
                ),
                lower: difference - critical * scale,
                upper: difference + critical * scale
            )
        }
    }

    /// `GamesHowell-v1`: unequal variances, Welch degrees of freedom per pair.
    ///
    /// `q = |x̄ᵢ-x̄ⱼ| / sqrt((sᵢ²/nᵢ+sⱼ²/nⱼ)/2)`, p-value `P(Q_{k,νᵢⱼ} > q)`.
    public static func gamesHowell(_ groups: [[Double]]) throws -> [GlifiPostHocComparison] {
        try validatePostHocGroups(groups, minimumSize: 2)
        let summaries = try groups.map { group -> (mean: Double, varianceOverCount: Double) in
            let mean = group.reduce(0, +) / Double(group.count)
            let variance =
                group.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(group.count - 1)
            guard variance > 0 else {
                throw postHocFailure("statistics.non-positive-variance")
            }
            return (mean, variance / Double(group.count))
        }
        return pairs(groups.count).map { first, second in
            let a = summaries[first].varianceOverCount
            let b = summaries[second].varianceOverCount
            let degrees =
                (a + b) * (a + b)
                / (a * a / Double(groups[first].count - 1)
                    + b * b / Double(groups[second].count - 1))
            let difference = summaries[first].mean - summaries[second].mean
            let q = abs(difference) / ((a + b) / 2).squareRoot()
            return GlifiPostHocComparison(
                firstGroupIndex: first,
                secondGroupIndex: second,
                difference: difference,
                statistic: q,
                degreesOfFreedom: degrees,
                pValue: GlifiDistributionFunctions.studentizedRangeUpperTail(
                    q,
                    groupCount: groups.count,
                    degreesOfFreedom: degrees
                ),
                lower: nil,
                upper: nil
            )
        }
    }

    /// `Dunn-v1`: pairwise mean-rank differences on the pooled midranks with tie correction.
    ///
    /// `z = (R̄ᵢ-R̄ⱼ) / sqrt([N(N+1)/12 - Σ(t³-t)/(12(N-1))]·(1/nᵢ+1/nⱼ))`, raw
    /// two-sided normal p-value; the family adjustment is a separate, declared step.
    public static func dunn(_ groups: [[Double]]) throws -> [GlifiPostHocComparison] {
        try validatePostHocGroups(groups, minimumSize: 1)
        let pooled = midranks(groups.flatMap { $0 })
        let count = Double(pooled.ranks.count)
        let tieTerm = pooled.tieGroupSizes.reduce(0.0) {
            $0 + Double($1) * Double($1) * Double($1) - Double($1)
        }
        let variance = count * (count + 1) / 12 - tieTerm / (12 * (count - 1))
        guard variance > 0 else {
            throw postHocFailure("statistics.degenerate-rank-variance")
        }
        var meanRanks: [Double] = []
        var offset = 0
        for group in groups {
            meanRanks.append(
                pooled.ranks[offset..<(offset + group.count)].reduce(0, +) / Double(group.count)
            )
            offset += group.count
        }
        return pairs(groups.count).map { first, second in
            let difference = meanRanks[first] - meanRanks[second]
            let z =
                difference
                / (variance
                * (1 / Double(groups[first].count) + 1 / Double(groups[second].count)))
                .squareRoot()
            return GlifiPostHocComparison(
                firstGroupIndex: first,
                secondGroupIndex: second,
                difference: difference,
                statistic: z,
                degreesOfFreedom: nil,
                pValue: min(max(erfc(abs(z) / 2.0.squareRoot()), 0), 1),
                lower: nil,
                upper: nil
            )
        }
    }

    /// Quantile of the studentized range by safeguarded bisection on its CDF.
    public static func studentizedRangeQuantile(
        _ probability: Double,
        groupCount: Int,
        degreesOfFreedom: Double
    ) throws -> Double {
        guard probability > 0, probability < 1, groupCount >= 2, degreesOfFreedom > 0 else {
            throw postHocFailure("statistics.invalid-probability", category: .invalidInput)
        }
        var lower = 0.0
        var upper = 1.0
        while GlifiDistributionFunctions.studentizedRangeCDF(
            upper,
            groupCount: groupCount,
            degreesOfFreedom: degreesOfFreedom
        ) < probability {
            lower = upper
            upper *= 2
            guard upper < 1e6 else {
                throw postHocFailure("statistics.quantile-not-bracketed")
            }
        }
        // Regula falsi con modifica di Illinois: convergenza superlineare e intervallo garantito.
        var lowerValue =
            GlifiDistributionFunctions.studentizedRangeCDF(
                lower,
                groupCount: groupCount,
                degreesOfFreedom: degreesOfFreedom
            ) - probability
        var upperValue =
            GlifiDistributionFunctions.studentizedRangeCDF(
                upper,
                groupCount: groupCount,
                degreesOfFreedom: degreesOfFreedom
            ) - probability
        var side = 0
        for _ in 0..<100 {
            let candidate = (lower * upperValue - upper * lowerValue) / (upperValue - lowerValue)
            let value =
                GlifiDistributionFunctions.studentizedRangeCDF(
                    candidate,
                    groupCount: groupCount,
                    degreesOfFreedom: degreesOfFreedom
                ) - probability
            if abs(value) < 1e-13 || upper - lower < 1e-12 { return candidate }
            if value * upperValue > 0 {
                upper = candidate
                upperValue = value
                if side == -1 { lowerValue /= 2 }
                side = -1
            } else {
                lower = candidate
                lowerValue = value
                if side == 1 { upperValue /= 2 }
                side = 1
            }
        }
        return (lower + upper) / 2
    }

    private static func pairs(_ count: Int) -> [(Int, Int)] {
        (0..<count).flatMap { first in ((first + 1)..<count).map { (first, $0) } }
    }

    private static func validatePostHocGroups(_ groups: [[Double]], minimumSize: Int) throws {
        guard groups.count >= 2 else {
            throw postHocFailure("statistics.insufficient-group-count")
        }
        guard groups.allSatisfy({ $0.count >= minimumSize }) else {
            throw postHocFailure(
                minimumSize > 1 ? "statistics.insufficient-sample-size" : "statistics.empty-group"
            )
        }
        guard groups.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw postHocFailure("statistics.non-finite-value", category: .invalidInput)
        }
    }
}

private func postHocFailure(
    _ code: String,
    category: GlifiFailureCategory = .insufficientData
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
