// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Result of a one-sample or paired Student t-test.
public struct GlifiLocationTTestResult: Equatable, Sendable {
    /// `OneSampleT-v1`.
    public static let oneSampleIdentifier = "OneSampleT-v1"
    /// `PairedT-v1`.
    public static let pairedIdentifier = "PairedT-v1"

    /// Versioned method identity.
    public let methodIdentifier: String
    /// Hypothesized location `μ₀` (of the differences for the paired test).
    public let hypothesizedMean: Double
    /// Sample mean (of the differences for the paired test).
    public let mean: Double
    /// Unbiased sample standard deviation.
    public let standardDeviation: Double
    /// Number of observations (complete pairs for the paired test).
    public let sampleCount: Int
    /// `t = (x̄-μ₀)/(s/√n)`.
    public let statistic: Double
    /// `n-1`.
    public let degreesOfFreedom: Int
    /// P-value for the declared alternative.
    public let pValue: Double
    /// Alternative hypothesis the p-value was computed against.
    public let alternative: GlifiAlternativeHypothesis
}

/// Declared computation of the `WilcoxonSignedRank-v1` p-value.
public enum GlifiWilcoxonMethod: Sendable, Equatable {
    /// Exact null distribution of `W⁺`; requires no ties among `|d|` and `n ≤ 50`.
    case exact
    /// Normal approximation with tie correction and an explicit continuity correction.
    case asymptotic(continuityCorrection: Bool)
}

/// `WilcoxonSignedRank-v1` result over paired differences.
public struct GlifiWilcoxonSignedRankResult: Equatable, Sendable {
    /// Versioned test identifier.
    public static let identifier = "WilcoxonSignedRank-v1"
    /// Zero policy: zero differences are removed before ranking.
    public static let zeroPolicyIdentifier = "drop-zero-differences-v1"

    /// Sum of the midranks of `|d|` over positive differences.
    public let positiveRankSum: Double
    /// Sum of the midranks of `|d|` over negative differences.
    public let negativeRankSum: Double
    /// Non-zero differences that were ranked.
    public let rankedCount: Int
    /// Zero differences removed by the declared zero policy.
    public let droppedZeroCount: Int
    /// Declared p-value computation.
    public let method: GlifiWilcoxonMethod
    /// Standard-normal statistic, present only for the asymptotic method.
    public let zStatistic: Double?
    /// P-value for the declared alternative.
    public let pValue: Double
    /// Alternative: `greater` means the differences tend to be positive.
    public let alternative: GlifiAlternativeHypothesis
}

/// `CohenD-pooled-v1` effect size for two independent groups.
public struct GlifiCohenDResult: Equatable, Sendable {
    /// Versioned effect-size identifier.
    public static let identifier = "CohenD-pooled-v1"

    /// `s_p = sqrt{[(n₁-1)s₁²+(n₂-1)s₂²]/(n₁+n₂-2)}`.
    public let pooledStandardDeviation: Double
    /// `d = (x̄₁-x̄₂)/s_p`.
    public let d: Double
}

extension GlifiStatisticalFoundation {
    /// Largest number of ranked differences for which the exact Wilcoxon law is enumerated.
    public static let maximumExactWilcoxonSampleCount = 50

    /// Computes `OneSampleT-v1`: `t = (x̄-μ₀)/(s/√n)`, `df = n-1`.
    ///
    /// Requires `n≥2` finite values with positive variance.
    public static func oneSampleTTest(
        _ sample: [Double],
        hypothesizedMean: Double = 0,
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> GlifiLocationTTestResult {
        try locationTTest(
            sample,
            hypothesizedMean: hypothesizedMean,
            alternative: alternative,
            identifier: GlifiLocationTTestResult.oneSampleIdentifier
        )
    }

    /// Computes `PairedT-v1`: the one-sample t-test of the differences `x-y`.
    ///
    /// Pairs must be complete: samples of different length are rejected, never truncated.
    public static func pairedTTest(
        _ x: [Double],
        _ y: [Double],
        hypothesizedDifference: Double = 0,
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> GlifiLocationTTestResult {
        try locationTTest(
            try pairedDifferences(x, y),
            hypothesizedMean: hypothesizedDifference,
            alternative: alternative,
            identifier: GlifiLocationTTestResult.pairedIdentifier
        )
    }

    /// Computes `WilcoxonSignedRank-v1` over the paired differences `x-y`.
    public static func wilcoxonSignedRank(
        _ x: [Double],
        _ y: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided,
        method: GlifiWilcoxonMethod = .asymptotic(continuityCorrection: true)
    ) throws -> GlifiWilcoxonSignedRankResult {
        let differences = try pairedDifferences(x, y)
        let nonZero = differences.filter { $0 != 0 }
        guard !nonZero.isEmpty else {
            throw pairedStatisticsFailure("statistics.all-differences-zero")
        }
        let ranked = midranks(nonZero.map(abs))
        var positive = 0.0
        var negative = 0.0
        for (difference, rank) in zip(nonZero, ranked.ranks) {
            if difference > 0 { positive += rank } else { negative += rank }
        }
        let count = Double(nonZero.count)

        switch method {
        case .exact:
            guard ranked.tieGroupSizes.isEmpty else {
                throw pairedStatisticsFailure("statistics.exact-requires-no-ties")
            }
            guard nonZero.count <= maximumExactWilcoxonSampleCount else {
                throw pairedStatisticsFailure(
                    "statistics.exact-sample-too-large",
                    category: .invalidInput
                )
            }
            let distribution = wilcoxonDistribution(nonZero.count)
            let total = distribution.reduce(0, +)
            let index = Int(positive.rounded())
            let lower = distribution.prefix(index + 1).reduce(0, +) / total
            let upper = distribution.suffix(from: index).reduce(0, +) / total
            let pValue: Double
            switch alternative {
            case .less: pValue = lower
            case .greater: pValue = upper
            case .twoSided: pValue = min(1, 2 * min(lower, upper))
            }
            return GlifiWilcoxonSignedRankResult(
                positiveRankSum: positive,
                negativeRankSum: negative,
                rankedCount: nonZero.count,
                droppedZeroCount: differences.count - nonZero.count,
                method: method,
                zStatistic: nil,
                pValue: min(max(pValue, 0), 1),
                alternative: alternative
            )
        case .asymptotic(let continuityCorrection):
            let tieTerm = ranked.tieGroupSizes.reduce(0.0) {
                $0 + Double($1) * Double($1) * Double($1) - Double($1)
            }
            let variance = count * (count + 1) * (2 * count + 1) / 24 - tieTerm / 48
            guard variance > 0 else {
                throw pairedStatisticsFailure("statistics.degenerate-rank-variance")
            }
            let deviation = positive - count * (count + 1) / 4
            var shift = 0.0
            if continuityCorrection {
                switch alternative {
                case .twoSided: shift = deviation == 0 ? 0 : (deviation > 0 ? -0.5 : 0.5)
                case .greater: shift = -0.5
                case .less: shift = 0.5
                }
            }
            let z = (deviation + shift) / variance.squareRoot()
            let root = 2.0.squareRoot()
            let pValue: Double
            switch alternative {
            case .twoSided: pValue = erfc(abs(z) / root)
            case .greater: pValue = 0.5 * erfc(z / root)
            case .less: pValue = 0.5 * erfc(-z / root)
            }
            return GlifiWilcoxonSignedRankResult(
                positiveRankSum: positive,
                negativeRankSum: negative,
                rankedCount: nonZero.count,
                droppedZeroCount: differences.count - nonZero.count,
                method: method,
                zStatistic: z,
                pValue: min(max(pValue, 0), 1),
                alternative: alternative
            )
        }
    }

    /// Computes `CohenD-pooled-v1` for two independent groups with `n₁,n₂≥2` and `s_p>0`.
    public static func cohenDPooled(
        _ sample1: [Double],
        _ sample2: [Double]
    ) throws -> GlifiCohenDResult {
        guard sample1.count >= 2, sample2.count >= 2 else {
            throw pairedStatisticsFailure("statistics.insufficient-sample-size")
        }
        guard sample1.allSatisfy(\.isFinite), sample2.allSatisfy(\.isFinite) else {
            throw pairedStatisticsFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let first = try scaledLocationMoments(sample1)
        let second = try scaledLocationMoments(sample2)
        let scaleExponent: Int
        if first.sumOfSquares == 0 {
            scaleExponent = second.scaleExponent
        } else if second.sumOfSquares == 0 {
            scaleExponent = first.scaleExponent
        } else {
            scaleExponent = max(first.scaleExponent, second.scaleExponent)
        }
        let firstSquares = locationScale(
            first.sumOfSquares, by: 2 * (first.scaleExponent - scaleExponent))
        let secondSquares = locationScale(
            second.sumOfSquares, by: 2 * (second.scaleExponent - scaleExponent))
        let pooledVariance =
            (firstSquares + secondSquares) / Double(sample1.count + sample2.count - 2)
        guard pooledVariance > 0 else {
            throw pairedStatisticsFailure("statistics.non-positive-variance")
        }
        let normalizedDeviation = pooledVariance.squareRoot()
        let pooled = locationScale(normalizedDeviation, by: scaleExponent)
        let anchorDifference = first.anchor - second.anchor
        let normalizedAnchorDifference =
            anchorDifference.isFinite
            ? locationScale(anchorDifference, by: -scaleExponent)
            : locationScale(first.anchor, by: -scaleExponent)
                - locationScale(second.anchor, by: -scaleExponent)
        let firstMeanOffset = locationScale(
            first.meanOffset, by: first.scaleExponent - scaleExponent)
        let secondMeanOffset = locationScale(
            second.meanOffset, by: second.scaleExponent - scaleExponent)
        let normalizedDifference =
            normalizedAnchorDifference + firstMeanOffset - secondMeanOffset
        let d: Double
        if normalizedAnchorDifference.isInfinite, anchorDifference.isFinite {
            // Division before power-of-two restoration avoids an overflowing intermediate.
            // Keep the normalized denominator: the reported physical SD can be subnormal.
            d =
                locationScale(
                    anchorDifference / normalizedDeviation, by: -scaleExponent)
                + (firstMeanOffset - secondMeanOffset) / normalizedDeviation
        } else {
            d = normalizedDifference / normalizedDeviation
        }
        guard pooled.isFinite, pooled > 0, d.isFinite else {
            throw pairedStatisticsFailure("statistics.non-finite-result", category: .invalidInput)
        }
        return GlifiCohenDResult(pooledStandardDeviation: pooled, d: d)
    }

    /// Number of sign assignments of the ranks `1…n` giving each value of `W⁺`.
    ///
    /// Counts subsets of `{1,…,n}` by sum; the distribution has `n(n+1)/2+1` entries.
    static func wilcoxonDistribution(_ count: Int) -> [Double] {
        let maximum = count * (count + 1) / 2
        var counts = [Double](repeating: 0, count: maximum + 1)
        counts[0] = 1
        guard count > 0 else { return counts }
        for rank in 1...count {
            for sum in stride(from: maximum, through: rank, by: -1) {
                counts[sum] += counts[sum - rank]
            }
        }
        return counts
    }

    private static func locationTTest(
        _ sample: [Double],
        hypothesizedMean: Double,
        alternative: GlifiAlternativeHypothesis,
        identifier: String
    ) throws -> GlifiLocationTTestResult {
        guard sample.count >= 2 else {
            throw pairedStatisticsFailure("statistics.insufficient-sample-size")
        }
        guard sample.allSatisfy(\.isFinite), hypothesizedMean.isFinite else {
            throw pairedStatisticsFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let values = try scaledLocationMoments(sample)
        guard values.sumOfSquares > 0 else {
            throw pairedStatisticsFailure("statistics.non-positive-variance")
        }
        let normalizedDeviation =
            (values.sumOfSquares / Double(sample.count - 1)).squareRoot()
        let deviation = locationScale(normalizedDeviation, by: values.scaleExponent)
        let anchorDifference = values.anchor - hypothesizedMean
        let normalizedAnchorDifference =
            anchorDifference.isFinite
            ? locationScale(anchorDifference, by: -values.scaleExponent)
            : locationScale(values.anchor, by: -values.scaleExponent)
                - locationScale(hypothesizedMean, by: -values.scaleExponent)
        let normalizedStandardError = normalizedDeviation / Double(sample.count).squareRoot()
        let statistic: Double
        if normalizedAnchorDifference.isInfinite, anchorDifference.isFinite {
            // A finite contrast can overflow while changing units, before the final division.
            statistic =
                locationScale(
                    anchorDifference / normalizedStandardError, by: -values.scaleExponent)
                + values.meanOffset / normalizedStandardError
        } else {
            statistic =
                (normalizedAnchorDifference + values.meanOffset) / normalizedStandardError
        }
        guard deviation.isFinite, deviation > 0, statistic.isFinite else {
            throw pairedStatisticsFailure("statistics.non-finite-result", category: .invalidInput)
        }
        let degrees = sample.count - 1
        return GlifiLocationTTestResult(
            methodIdentifier: identifier,
            hypothesizedMean: hypothesizedMean,
            mean: values.mean,
            standardDeviation: deviation,
            sampleCount: sample.count,
            statistic: statistic,
            degreesOfFreedom: degrees,
            pValue: try tDistributionPValue(
                statistic: statistic,
                degreesOfFreedom: Double(degrees),
                alternative: alternative
            ),
            alternative: alternative
        )
    }

    private static func pairedDifferences(_ x: [Double], _ y: [Double]) throws -> [Double] {
        guard x.count == y.count else {
            throw pairedStatisticsFailure(
                "statistics.paired-length-mismatch",
                category: .invalidInput
            )
        }
        guard x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite) else {
            throw pairedStatisticsFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let differences = zip(x, y).map { $0 - $1 }
        guard differences.allSatisfy(\.isFinite) else {
            throw pairedStatisticsFailure("statistics.non-finite-result", category: .invalidInput)
        }
        return differences
    }

    private static func scaledLocationMoments(
        _ sample: [Double]
    ) throws -> LocationSampleMoments {
        let anchor = sample.first ?? 0
        var needsInputScaling = false
        var largestInput = 0.0
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            needsInputScaling = needsInputScaling || !(value - anchor).isFinite
            largestInput = max(largestInput, abs(value))
        }
        let inputExponent = needsInputScaling ? largestInput.exponent : 0
        let scaledAnchor = locationScale(anchor, by: -inputExponent)
        func offset(_ value: Double) -> Double {
            needsInputScaling
                ? locationScale(value, by: -inputExponent) - scaledAnchor : value - anchor
        }
        var largestOffset = 0.0
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            if needsInputScaling, value != 0,
                locationScale(value, by: -inputExponent) == 0
            {
                throw pairedStatisticsFailure(
                    "statistics.non-finite-result", category: .invalidInput)
            }
            largestOffset = max(largestOffset, abs(offset(value)))
        }
        guard largestOffset > 0 else {
            return LocationSampleMoments(
                anchor: anchor, mean: anchor, meanOffset: 0,
                scaleExponent: 0, sumOfSquares: 0)
        }
        let offsetExponent = largestOffset.exponent
        let scaleExponent = inputExponent + offsetExponent
        func coordinate(_ value: Double) -> Double {
            locationScale(offset(value), by: -offsetExponent)
        }
        var sum = 0.0
        var compensation = 0.0
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let normalized = coordinate(value)
            guard offset(value) == 0 || normalized != 0 else {
                throw pairedStatisticsFailure(
                    "statistics.non-finite-result", category: .invalidInput)
            }
            let adjusted = normalized - compensation
            let next = sum + adjusted
            compensation = (next - sum) - adjusted
            sum = next
        }
        let meanOffset = sum / Double(sample.count)
        let restoredOffset = locationScale(meanOffset, by: scaleExponent)
        var mean = anchor + restoredOffset
        if !mean.isFinite {
            mean = locationScale(
                scaledAnchor + locationScale(meanOffset, by: offsetExponent),
                by: inputExponent)
        }
        var squares = 0.0
        var squareCompensation = 0.0
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let deviation = coordinate(value) - meanOffset
            let adjusted = deviation * deviation - squareCompensation
            let next = squares + adjusted
            squareCompensation = (next - squares) - adjusted
            squares = next
        }
        guard mean.isFinite, squares.isFinite, squares > 0 else {
            throw pairedStatisticsFailure("statistics.non-finite-result", category: .invalidInput)
        }
        return LocationSampleMoments(
            anchor: anchor, mean: mean, meanOffset: meanOffset,
            scaleExponent: scaleExponent, sumOfSquares: squares)
    }

}

private struct LocationSampleMoments {
    let anchor: Double
    let mean: Double
    let meanOffset: Double
    let scaleExponent: Int
    let sumOfSquares: Double
}

private func locationScale(_ value: Double, by exponent: Int) -> Double {
    Double(sign: value.sign, exponent: exponent, significand: abs(value))
}

private func pairedStatisticsFailure(
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
