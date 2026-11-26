// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Alternative hypothesis of a one- or two-sample location test.
public enum GlifiAlternativeHypothesis: Sendable, Equatable {
    /// The two-sided alternative: the difference is not zero.
    case twoSided
    /// The one-sided alternative: the first group's location is less.
    case less
    /// The one-sided alternative: the first group's location is greater.
    case greater
}

/// `WelchT-v1` result for two independent samples with unequal variances.
public struct GlifiWelchTTestResult: Equatable, Sendable {
    /// Versioned test identifier.
    public static let identifier = "WelchT-v1"

    /// `t = (x̄₁-x̄₂) / sqrt(s₁²/n₁+s₂²/n₂)`.
    public let statistic: Double
    /// Welch–Satterthwaite degrees of freedom `ν`.
    public let degreesOfFreedom: Double
    /// Asymptotic p-value for the declared alternative.
    public let pValue: Double
    /// Alternative hypothesis the p-value was computed against.
    public let alternative: GlifiAlternativeHypothesis
}

/// `OneWayANOVA-v1` result over `k≥2` independent groups.
public struct GlifiOneWayANOVAResult: Equatable, Sendable {
    /// Versioned test identifier.
    public static let identifier = "OneWayANOVA-v1"

    /// `F = (SS_between/(k-1)) / (SS_within/(N-k))`.
    public let fStatistic: Double
    /// `k-1`.
    public let numeratorDegreesOfFreedom: Int
    /// `N-k`.
    public let denominatorDegreesOfFreedom: Int
    /// Upper-tail asymptotic p-value.
    public let pValue: Double
}

/// Bounded, deterministic statistical foundation: Welch's t-test, one-way
/// ANOVA, and the underlying t/F asymptotic p-values (GS-MET-001-21).
public enum GlifiStatisticalFoundation {
    /// Two-sided or one-sided p-value of Student's t distribution.
    ///
    /// Uses the identity `P(|T|>|t|) = I_x(ν/2, 1/2)` with `x=ν/(ν+t²)`.
    public static func tDistributionPValue(
        statistic: Double,
        degreesOfFreedom: Double,
        alternative: GlifiAlternativeHypothesis
    ) throws -> Double {
        guard statistic.isFinite, degreesOfFreedom.isFinite, degreesOfFreedom > 0 else {
            throw statisticalFailure(
                "statistics.invalid-distribution-parameters",
                category: .invalidInput
            )
        }
        let twoSided: Double
        if statistic == 0 {
            twoSided = 1
        } else {
            // Log odds preserve both tiny t values and tails whose squared t
            // would overflow, without subtracting a rounded probability from 1.
            twoSided = try regularizedIncompleteBetaFromLogOdds(
                2 * log(abs(statistic)) - log(degreesOfFreedom),
                degreesOfFreedom / 2,
                0.5
            )
        }
        switch alternative {
        case .twoSided:
            return twoSided
        case .greater:
            return statistic >= 0 ? twoSided / 2 : 1 - twoSided / 2
        case .less:
            return statistic <= 0 ? twoSided / 2 : 1 - twoSided / 2
        }
    }

    /// Upper-tail p-value of the F distribution: `P(F_{df1,df2} > f)`.
    ///
    /// Uses the identity `P(F>f) = I_x(df2/2, df1/2)` with `x=df2/(df2+df1·f)`.
    public static func fDistributionUpperTailPValue(
        statistic: Double,
        numeratorDegreesOfFreedom: Double,
        denominatorDegreesOfFreedom: Double
    ) throws -> Double {
        guard statistic.isFinite, statistic >= 0,
            numeratorDegreesOfFreedom.isFinite, denominatorDegreesOfFreedom.isFinite,
            numeratorDegreesOfFreedom > 0, denominatorDegreesOfFreedom > 0
        else {
            throw statisticalFailure(
                "statistics.invalid-distribution-parameters",
                category: .invalidInput
            )
        }
        guard statistic > 0 else { return 1 }
        return try regularizedIncompleteBetaFromLogOdds(
            log(numeratorDegreesOfFreedom) + log(statistic) - log(denominatorDegreesOfFreedom),
            denominatorDegreesOfFreedom / 2,
            numeratorDegreesOfFreedom / 2
        )
    }

    /// Computes `WelchT-v1` for two independent samples.
    ///
    /// Requires `n₁,n₂≥2` and both sample variances finite and positive.
    public static func welchTTest(
        _ sample1: [Double],
        _ sample2: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> GlifiWelchTTestResult {
        let statistics1 = try sampleMeanAndVariance(sample1)
        let statistics2 = try sampleMeanAndVariance(sample2)
        let varianceOverCount1 = statistics1.variance / Double(sample1.count)
        let varianceOverCount2 = statistics2.variance / Double(sample2.count)
        let standardError = (varianceOverCount1 + varianceOverCount2).squareRoot()
        let statistic = (statistics1.mean - statistics2.mean) / standardError
        let degreesOfFreedom =
            (varianceOverCount1 + varianceOverCount2) * (varianceOverCount1 + varianceOverCount2)
            / (varianceOverCount1 * varianceOverCount1 / Double(sample1.count - 1)
                + varianceOverCount2 * varianceOverCount2 / Double(sample2.count - 1))
        let pValue = try tDistributionPValue(
            statistic: statistic,
            degreesOfFreedom: degreesOfFreedom,
            alternative: alternative
        )
        return GlifiWelchTTestResult(
            statistic: statistic,
            degreesOfFreedom: degreesOfFreedom,
            pValue: pValue,
            alternative: alternative
        )
    }

    /// Computes `OneWayANOVA-v1` over `k≥2` independent, non-empty groups.
    public static func oneWayANOVA(_ groups: [[Double]]) throws -> GlifiOneWayANOVAResult {
        guard groups.count >= 2 else {
            throw statisticalFailure("statistics.insufficient-group-count")
        }
        guard groups.allSatisfy({ !$0.isEmpty }) else {
            throw statisticalFailure("statistics.empty-group")
        }
        guard groups.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw statisticalFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let groupCount = groups.count
        let totalCount = groups.reduce(0) { $0 + $1.count }
        guard totalCount > groupCount else {
            throw statisticalFailure("statistics.insufficient-sample-size")
        }
        let groupMeans = groups.map { $0.reduce(0, +) / Double($0.count) }
        let grandMean =
            zip(groups, groupMeans).reduce(0.0) { $0 + Double($1.0.count) * $1.1 }
            / Double(totalCount)
        let sumOfSquaresBetween = zip(groups, groupMeans).reduce(0.0) { result, pair in
            let deviation = pair.1 - grandMean
            return result + Double(pair.0.count) * deviation * deviation
        }
        let sumOfSquaresWithin = zip(groups, groupMeans).reduce(0.0) { result, pair in
            result
                + pair.0.reduce(0.0) { innerResult, value in
                    let deviation = value - pair.1
                    return innerResult + deviation * deviation
                }
        }
        let numeratorDegreesOfFreedom = groupCount - 1
        let denominatorDegreesOfFreedom = totalCount - groupCount
        guard sumOfSquaresWithin > 0 else {
            throw statisticalFailure(
                "statistics.degenerate-within-variance",
                category: .insufficientData
            )
        }
        let meanSquareBetween = sumOfSquaresBetween / Double(numeratorDegreesOfFreedom)
        let meanSquareWithin = sumOfSquaresWithin / Double(denominatorDegreesOfFreedom)
        let fStatistic = meanSquareBetween / meanSquareWithin
        let pValue = try fDistributionUpperTailPValue(
            statistic: fStatistic,
            numeratorDegreesOfFreedom: Double(numeratorDegreesOfFreedom),
            denominatorDegreesOfFreedom: Double(denominatorDegreesOfFreedom)
        )
        return GlifiOneWayANOVAResult(
            fStatistic: fStatistic,
            numeratorDegreesOfFreedom: numeratorDegreesOfFreedom,
            denominatorDegreesOfFreedom: denominatorDegreesOfFreedom,
            pValue: pValue
        )
    }

    private static func sampleMeanAndVariance(
        _ sample: [Double]
    ) throws -> (mean: Double, variance: Double) {
        guard sample.count >= 2 else {
            throw statisticalFailure("statistics.insufficient-sample-size")
        }
        guard sample.allSatisfy(\.isFinite) else {
            throw statisticalFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let mean = sample.reduce(0, +) / Double(sample.count)
        let variance =
            sample.reduce(0.0) { result, value in
                let deviation = value - mean
                return result + deviation * deviation
            } / Double(sample.count - 1)
        guard variance > 0 else {
            throw statisticalFailure(
                "statistics.non-positive-variance",
                category: .insufficientData
            )
        }
        return (mean, variance)
    }
}

/// Original implementation from the mathematical identities DLMF 8.17.4,
/// 8.17.22 and 8.17.23.
///
/// The continued fraction is evaluated from its deepest
/// denominator, with independently doubled truncation depths; no external
/// implementation or coefficient table is incorporated.
private func regularizedIncompleteBetaFromLogOdds(
    _ logOdds: Double,
    _ firstShape: Double,
    _ secondShape: Double
) throws -> Double {
    guard firstShape > 0, secondShape > 0,
        (firstShape + secondShape).isFinite, logOdds.isFinite
    else {
        throw statisticalFailure("statistics.non-finite-result", category: .invalidInput)
    }
    // logOdds = log((1-x)/x). Evaluate the smaller exponential only.
    let correction = log1p(exp(-abs(logOdds)))
    var logX = logOdds > 0 ? -logOdds - correction : -correction
    var logComplement = logOdds > 0 ? -correction : logOdds - correction
    var a = firstShape
    var b = secondShape
    let useComplement = logX >= log((a + 1) / (a + b + 2))
    if useComplement {
        swap(&logX, &logComplement)
        swap(&a, &b)
    }
    let x = exp(logX)
    let fraction = try incompleteBetaFractionFromBottom(a: a, b: b, x: x)
    let logProbability =
        logGamma(a + b) - logGamma(a) - logGamma(b)
        + a * logX + b * logComplement - log(a) + log(fraction)
    guard logProbability.isFinite else {
        throw statisticalFailure("statistics.non-finite-result", category: .invalidInput)
    }
    let probability = useComplement ? -expm1(logProbability) : exp(logProbability)
    guard probability.isFinite, probability >= -1e-12, probability <= 1 + 1e-12 else {
        throw statisticalFailure("statistics.non-finite-result", category: .invalidInput)
    }
    return min(max(probability, 0), 1)
}

private func incompleteBetaFractionFromBottom(a: Double, b: Double, x: Double) throws -> Double {
    var previous: Double?
    var depth = 16
    while depth <= 2_048 {
        try Task.checkCancellation()
        var denominator = 1.0
        for index in stride(from: depth, through: 1, by: -1) {
            let half = Double(index / 2)
            let offset = a + 2 * half
            let coefficient: Double
            if index.isMultiple(of: 2) {
                coefficient = (half / (offset - 1)) * ((b - half) / offset) * x
            } else {
                coefficient = -((a + half) / offset) * ((a + b + half) / (offset + 1)) * x
            }
            denominator = 1 + coefficient / denominator
            guard denominator.isFinite, denominator != 0 else {
                throw statisticalFailure("statistics.non-finite-result", category: .invalidInput)
            }
        }
        let fraction = 1 / denominator
        if let previous, fraction > 0,
            abs(fraction - previous) <= 8 * Double.ulpOfOne * abs(fraction)
        {
            return fraction
        }
        previous = fraction
        depth *= 2
    }
    // A bounded fraction without observed convergence cannot certify a p-value.
    throw statisticalFailure("statistics.non-finite-result", category: .invalidInput)
}

private func statisticalFailure(
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
