// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// `BootstrapBCa-v1` interval: bias-corrected and accelerated percentiles.
public struct GlifiBCaInterval: Codable, Equatable, Sendable {
    /// Versioned method identity.
    public static let identifier = "BootstrapBCa-v1"

    /// Statistic of the original sample.
    public let estimate: Double
    /// Confidence level.
    public let confidenceLevel: Double
    /// Bias correction `z₀ = Φ⁻¹(#{θ*<θ̂}/B)`.
    public let biasCorrection: Double
    /// Jackknife acceleration `a = Σ(θ̄-θ₍ᵢ₎)³ / (6[Σ(θ̄-θ₍ᵢ₎)²]^{3/2})`.
    public let acceleration: Double
    /// Adjusted lower percentile `α₁`.
    public let lowerProbability: Double
    /// Adjusted upper percentile `α₂`.
    public let upperProbability: Double
    /// Lower bound: type-7 quantile at `α₁`.
    public let lower: Double
    /// Upper bound: type-7 quantile at `α₂`.
    public let upper: Double
    /// Number of bootstrap resamples.
    public let resampleCount: Int
    /// Recorded seed.
    public let seed: UInt64
}

/// One planned contrast `Σcᵢμᵢ` over independent group means.
public struct GlifiContrastResult: Codable, Equatable, Sendable {
    /// Contrast coefficients in group order, summing to zero.
    public let coefficients: [Double]
    /// `Σcᵢx̄ᵢ`.
    public let estimate: Double
    /// `sqrt(MSE·Σcᵢ²/nᵢ)`.
    public let standardError: Double
    /// `estimate / standardError`.
    public let tStatistic: Double
    /// `N-k`.
    public let degreesOfFreedom: Int
    /// Raw two-sided p-value.
    public let pValue: Double
    /// `Bonferroni-v1` over the declared family of contrasts.
    public let bonferroniPValue: Double
    /// `BenjaminiHochberg-v1` over the declared family of contrasts.
    public let benjaminiHochbergPValue: Double
    /// Lower bound of the unadjusted interval.
    public let lower: Double
    /// Upper bound of the unadjusted interval.
    public let upper: Double
}

extension GlifiStatisticalFoundation {
    /// `PlannedContrast-v1` identity.
    public static let plannedContrastIdentifier = "PlannedContrast-v1"

    /// Quantile of Student's t by bisection on its CDF.
    public static func tQuantile(_ probability: Double, degreesOfFreedom: Double) throws -> Double {
        guard probability > 0, probability < 1, degreesOfFreedom > 0 else {
            throw inferenceFailure("statistics.invalid-probability", category: .invalidInput)
        }
        if probability == 0.5 { return 0 }
        let upperTail = probability > 0.5 ? 1 - probability : probability
        var lower = 0.0
        var upper = 1.0
        func tail(_ t: Double) throws -> Double {
            try tDistributionPValue(
                statistic: t,
                degreesOfFreedom: degreesOfFreedom,
                alternative: .greater
            )
        }
        while try tail(upper) > upperTail {
            lower = upper
            upper *= 2
            guard upper < 1e12 else {
                throw inferenceFailure("statistics.quantile-not-bracketed")
            }
        }
        for _ in 0..<200 {
            let middle = (lower + upper) / 2
            if try tail(middle) > upperTail { lower = middle } else { upper = middle }
            if upper - lower <= 1e-14 * max(1, upper) { break }
        }
        let magnitude = (lower + upper) / 2
        return probability > 0.5 ? magnitude : -magnitude
    }

    /// Computes `BootstrapBCa-v1` for the mean from the same replicates as the percentile method.
    public static func bootstrapMeanBCaInterval(
        _ sample: [Double],
        confidenceLevel: Double = 0.95,
        resampleCount: Int = 2_000,
        seed: UInt64
    ) throws -> GlifiBCaInterval {
        guard sample.count >= 2 else {
            throw inferenceFailure("statistics.insufficient-sample-size")
        }
        guard sample.allSatisfy(\.isFinite) else {
            throw inferenceFailure("statistics.non-finite-value", category: .invalidInput)
        }
        guard confidenceLevel > 0, confidenceLevel < 1,
            (1...maximumResampleCount).contains(resampleCount)
        else {
            throw inferenceFailure(
                "statistics.invalid-resampling-parameters",
                category: .invalidInput
            )
        }
        let replicates = try bootstrapMeanReplicates(
            sample,
            resampleCount: resampleCount,
            seed: seed
        )
        let total = sample.reduce(0, +)
        let jackknife = sample.map { (total - $0) / Double(sample.count - 1) }
        return try bcaInterval(
            estimate: total / Double(sample.count),
            sortedReplicates: replicates,
            jackknife: jackknife,
            confidenceLevel: confidenceLevel,
            seed: seed
        )
    }

    /// BCa interval from sorted replicates and leave-one-out jackknife values.
    static func bcaInterval(
        estimate: Double,
        sortedReplicates: [Double],
        jackknife: [Double],
        confidenceLevel: Double,
        seed: UInt64
    ) throws -> GlifiBCaInterval {
        let below = sortedReplicates.filter { $0 < estimate }.count
        guard below > 0, below < sortedReplicates.count else {
            throw inferenceFailure("statistics.bca-undefined")
        }
        let biasCorrection = try GlifiDistributionFunctions.normalQuantile(
            Double(below) / Double(sortedReplicates.count)
        )
        let jackknifeMean = jackknife.reduce(0, +) / Double(jackknife.count)
        var squares = 0.0
        var cubes = 0.0
        for value in jackknife {
            let deviation = jackknifeMean - value
            squares += deviation * deviation
            cubes += deviation * deviation * deviation
        }
        let acceleration = squares > 0 ? cubes / (6 * pow(squares, 1.5)) : 0
        let tail = (1 - confidenceLevel) / 2
        func adjusted(_ probability: Double) throws -> Double {
            let z = try GlifiDistributionFunctions.normalQuantile(probability)
            let shifted = biasCorrection + z
            return GlifiDistributionFunctions.normalCDF(
                biasCorrection + shifted / (1 - acceleration * shifted)
            )
        }
        let lowerProbability = try adjusted(tail)
        let upperProbability = try adjusted(1 - tail)
        return GlifiBCaInterval(
            estimate: estimate,
            confidenceLevel: confidenceLevel,
            biasCorrection: biasCorrection,
            acceleration: acceleration,
            lowerProbability: lowerProbability,
            upperProbability: upperProbability,
            lower: try quantileType7(sortedReplicates, probability: lowerProbability),
            upper: try quantileType7(sortedReplicates, probability: upperProbability),
            resampleCount: sortedReplicates.count,
            seed: seed
        )
    }

    /// Computes `PlannedContrast-v1` for a declared family of contrasts.
    ///
    /// Each contrast must have one coefficient per group, sum to zero and not be all zero.
    /// The pooled `MSE` of the one-way model is shared; Bonferroni and BH adjust the family.
    public static func plannedContrasts(
        _ groups: [[Double]],
        contrasts: [[Double]],
        confidenceLevel: Double = 0.95
    ) throws -> [GlifiContrastResult] {
        guard groups.count >= 2, groups.allSatisfy({ !$0.isEmpty }) else {
            throw inferenceFailure("statistics.insufficient-group-count")
        }
        guard groups.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw inferenceFailure("statistics.non-finite-value", category: .invalidInput)
        }
        guard !contrasts.isEmpty,
            contrasts.allSatisfy({ contrast in
                contrast.count == groups.count && contrast.allSatisfy(\.isFinite)
                    && contrast.contains { $0 != 0 }
                    && abs(contrast.reduce(0, +)) <= 1e-12 * contrast.map(abs).reduce(0, +)
            })
        else {
            throw inferenceFailure("statistics.invalid-contrast", category: .invalidInput)
        }
        guard confidenceLevel > 0, confidenceLevel < 1 else {
            throw inferenceFailure("statistics.invalid-confidence-level", category: .invalidInput)
        }
        let total = groups.reduce(0) { $0 + $1.count }
        let degrees = total - groups.count
        guard degrees > 0 else {
            throw inferenceFailure("statistics.insufficient-sample-size")
        }
        let means = groups.map { $0.reduce(0, +) / Double($0.count) }
        let within = zip(groups, means).reduce(0.0) { result, pair in
            result + pair.0.reduce(0.0) { $0 + ($1 - pair.1) * ($1 - pair.1) }
        }
        let meanSquare = within / Double(degrees)
        guard meanSquare > 0 else {
            throw inferenceFailure("statistics.degenerate-within-variance")
        }
        let critical = try tQuantile(
            (1 + confidenceLevel) / 2,
            degreesOfFreedom: Double(degrees)
        )
        var raw: [(Double, Double, Double, Double)] = []
        for contrast in contrasts {
            let estimate = zip(contrast, means).reduce(0) { $0 + $1.0 * $1.1 }
            let standardError =
                (meanSquare
                * zip(contrast, groups).reduce(0) { $0 + $1.0 * $1.0 / Double($1.1.count) })
                .squareRoot()
            let t = estimate / standardError
            let p = try tDistributionPValue(
                statistic: t,
                degreesOfFreedom: Double(degrees),
                alternative: .twoSided
            )
            raw.append((estimate, standardError, t, p))
        }
        let bonferroni = try bonferroniAdjustedPValues(raw.map(\.3))
        let hochberg = try benjaminiHochbergAdjustedPValues(raw.map(\.3))
        return raw.indices.map { index in
            let value = raw[index]
            return GlifiContrastResult(
                coefficients: contrasts[index],
                estimate: value.0,
                standardError: value.1,
                tStatistic: value.2,
                degreesOfFreedom: degrees,
                pValue: value.3,
                bonferroniPValue: bonferroni[index],
                benjaminiHochbergPValue: hochberg[index],
                lower: value.0 - critical * value.1,
                upper: value.0 + critical * value.1
            )
        }
    }
}

private func inferenceFailure(
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
