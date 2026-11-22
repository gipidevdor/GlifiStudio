// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// `SplitMix64-v1`: deterministic 64-bit pseudo-random generator with a recorded seed.
///
/// The sequence is fully defined by the seed; it is not suitable for cryptography.
public struct GlifiSplitMix64: Sendable {
    /// Versioned generator identity.
    public static let identifier = "SplitMix64-v1"

    private var state: UInt64

    /// Creates a generator whose sequence is fully determined by `seed`.
    public init(seed: UInt64) {
        state = seed
    }

    /// Next 64-bit value.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// Unbiased index in `0..<bound` by rejection of the incomplete final block.
    public mutating func index(below bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        let width = UInt64(bound)
        let threshold = (0 &- width) % width
        while true {
            let value = next()
            if value >= threshold { return Int(value % width) }
        }
    }
}

/// `BootstrapPercentile-v1` confidence interval for the mean.
public struct GlifiBootstrapInterval: Equatable, Sendable {
    /// Versioned method identity.
    public static let identifier = "BootstrapPercentile-v1"
    /// Quantile definition: linear interpolation between order statistics (type 7).
    public static let quantileIdentifier = "quantile-linear-type7-v1"

    /// Statistic of the original sample.
    public let estimate: Double
    /// Confidence level in `(0, 1)`.
    public let confidenceLevel: Double
    /// Lower percentile bound.
    public let lower: Double
    /// Upper percentile bound.
    public let upper: Double
    /// Number of bootstrap resamples `B`.
    public let resampleCount: Int
    /// Generator identity.
    public let generatorIdentifier: String
    /// Recorded seed.
    public let seed: UInt64
}

/// Declared enumeration strategy of a two-sample permutation test.
public enum GlifiPermutationStrategy: Sendable, Equatable {
    /// Every assignment of the pooled values to the first group.
    case exact
    /// Random relabelings with `(b+1)/(m+1)` p-value correction.
    case monteCarlo(sampleCount: Int, seed: UInt64)
}

/// `PermutationMeanDifference-v1` result for two independent samples.
public struct GlifiPermutationTestResult: Equatable, Sendable {
    /// Versioned test identity.
    public static let identifier = "PermutationMeanDifference-v1"

    /// Observed `x̄₁ - x̄₂`.
    public let observedDifference: Double
    /// Declared enumeration strategy.
    public let strategy: GlifiPermutationStrategy
    /// Relabelings evaluated (all assignments for the exact strategy).
    public let evaluatedCount: Int
    /// Relabelings at least as extreme as the observed one.
    public let extremeCount: Int
    /// Exact `b/m`, or Monte Carlo `(b+1)/(m+1)`.
    public let pValue: Double
    /// Alternative: `greater` means the first group tends to be larger.
    public let alternative: GlifiAlternativeHypothesis
}

extension GlifiStatisticalFoundation {
    /// Largest number of assignments enumerated by the exact permutation strategy.
    public static let maximumExactPermutationCount = 200_000
    /// Largest number of bootstrap resamples or Monte Carlo relabelings.
    public static let maximumResampleCount = 200_000

    /// Computes the `BootstrapPercentile-v1` interval of the mean.
    ///
    /// Resamples the independent unit with replacement `B` times using `SplitMix64-v1`,
    /// then takes the type-7 quantiles `(1-level)/2` and `(1+level)/2`.
    public static func bootstrapMeanInterval(
        _ sample: [Double],
        confidenceLevel: Double = 0.95,
        resampleCount: Int = 2_000,
        seed: UInt64
    ) throws -> GlifiBootstrapInterval {
        guard sample.count >= 2 else {
            throw resamplingFailure("statistics.insufficient-sample-size")
        }
        guard sample.allSatisfy(\.isFinite) else {
            throw resamplingFailure("statistics.non-finite-value", category: .invalidInput)
        }
        guard confidenceLevel > 0, confidenceLevel < 1,
            (1...maximumResampleCount).contains(resampleCount)
        else {
            throw resamplingFailure(
                "statistics.invalid-resampling-parameters", category: .invalidInput)
        }
        let means = try bootstrapMeanReplicates(
            sample,
            resampleCount: resampleCount,
            seed: seed
        )
        let tail = (1 - confidenceLevel) / 2
        return GlifiBootstrapInterval(
            estimate: sample.reduce(0, +) / Double(sample.count),
            confidenceLevel: confidenceLevel,
            lower: try quantileType7(means, probability: tail),
            upper: try quantileType7(means, probability: 1 - tail),
            resampleCount: resampleCount,
            generatorIdentifier: GlifiSplitMix64.identifier,
            seed: seed
        )
    }

    /// Sorted bootstrap replicates of the mean, drawn with `SplitMix64-v1`.
    static func bootstrapMeanReplicates(
        _ sample: [Double],
        resampleCount: Int,
        seed: UInt64
    ) throws -> [Double] {
        var generator = GlifiSplitMix64(seed: seed)
        var means: [Double] = []
        means.reserveCapacity(resampleCount)
        for iteration in 0..<resampleCount {
            if iteration.isMultiple(of: 1_024) { try Task.checkCancellation() }
            var total = 0.0
            for _ in sample.indices {
                total += sample[generator.index(below: sample.count)]
            }
            means.append(total / Double(sample.count))
        }
        return means.sorted()
    }

    /// `MovingBlockBootstrap-v1` percentile interval of the mean for dependent sequences.
    ///
    /// Each replicate concatenates `⌈n/L⌉` blocks of `L` consecutive observations whose start is
    /// drawn uniformly in `0...n-L` with `SplitMix64-v1`, truncated to `n`; with `L = 1` it draws
    /// exactly the indices of `BootstrapPercentile-v1`.
    public static func movingBlockBootstrapMeanInterval(
        _ sequence: [Double],
        blockLength: Int,
        confidenceLevel: Double = 0.95,
        resampleCount: Int = 2_000,
        seed: UInt64
    ) throws -> GlifiBootstrapInterval {
        guard sequence.count >= 2, (1...sequence.count).contains(blockLength) else {
            throw resamplingFailure("statistics.invalid-block-length", category: .invalidInput)
        }
        guard sequence.allSatisfy(\.isFinite) else {
            throw resamplingFailure("statistics.non-finite-value", category: .invalidInput)
        }
        guard confidenceLevel > 0, confidenceLevel < 1,
            (1...maximumResampleCount).contains(resampleCount)
        else {
            throw resamplingFailure(
                "statistics.invalid-resampling-parameters",
                category: .invalidInput
            )
        }
        var generator = GlifiSplitMix64(seed: seed)
        let count = sequence.count
        var means: [Double] = []
        means.reserveCapacity(resampleCount)
        for iteration in 0..<resampleCount {
            if iteration.isMultiple(of: 1_024) { try Task.checkCancellation() }
            var total = 0.0
            var drawn = 0
            while drawn < count {
                let start = generator.index(below: count - blockLength + 1)
                for offset in 0..<blockLength where drawn < count {
                    total += sequence[start + offset]
                    drawn += 1
                }
            }
            means.append(total / Double(count))
        }
        means.sort()
        let tail = (1 - confidenceLevel) / 2
        return GlifiBootstrapInterval(
            estimate: sequence.reduce(0, +) / Double(count),
            confidenceLevel: confidenceLevel,
            lower: try quantileType7(means, probability: tail),
            upper: try quantileType7(means, probability: 1 - tail),
            resampleCount: resampleCount,
            generatorIdentifier: GlifiSplitMix64.identifier,
            seed: seed
        )
    }

    /// Computes `PermutationMeanDifference-v1` with the declared strategy.
    ///
    /// Exchangeability of the labels under the null hypothesis is a precondition of the
    /// design, not something this function can verify.
    public static func permutationMeanDifference(
        _ sample1: [Double],
        _ sample2: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided,
        strategy: GlifiPermutationStrategy
    ) throws -> GlifiPermutationTestResult {
        guard !sample1.isEmpty, !sample2.isEmpty else {
            throw resamplingFailure("statistics.empty-group")
        }
        guard sample1.allSatisfy(\.isFinite), sample2.allSatisfy(\.isFinite) else {
            throw resamplingFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let pooled = sample1 + sample2
        let total = pooled.reduce(0, +)
        let first = sample1.count
        let second = sample2.count
        func difference(firstSum: Double) -> Double {
            firstSum / Double(first) - (total - firstSum) / Double(second)
        }
        let observed = difference(firstSum: sample1.reduce(0, +))
        // Tolleranza relativa per confronti fra somme uguali calcolate in ordini diversi.
        let tolerance = 1e-12 * max(1, pooled.map(abs).max() ?? 1)
        func isExtreme(_ value: Double) -> Bool {
            switch alternative {
            case .twoSided: abs(value) >= abs(observed) - tolerance
            case .greater: value >= observed - tolerance
            case .less: value <= observed + tolerance
            }
        }

        switch strategy {
        case .exact:
            guard
                let assignments = binomialCoefficient(pooled.count, first),
                assignments <= maximumExactPermutationCount
            else {
                throw resamplingFailure(
                    "statistics.exact-permutation-too-large",
                    category: .invalidInput
                )
            }
            var extreme = 0
            var evaluated = 0
            var chosen = Array(0..<first)
            while true {
                if evaluated.isMultiple(of: 4_096) { try Task.checkCancellation() }
                evaluated += 1
                if isExtreme(difference(firstSum: chosen.reduce(0.0) { $0 + pooled[$1] })) {
                    extreme += 1
                }
                guard advanceCombination(&chosen, universe: pooled.count) else { break }
            }
            return GlifiPermutationTestResult(
                observedDifference: observed,
                strategy: strategy,
                evaluatedCount: evaluated,
                extremeCount: extreme,
                pValue: Double(extreme) / Double(evaluated),
                alternative: alternative
            )
        case .monteCarlo(let sampleCount, let seed):
            guard (1...maximumResampleCount).contains(sampleCount) else {
                throw resamplingFailure(
                    "statistics.invalid-resampling-parameters",
                    category: .invalidInput
                )
            }
            var generator = GlifiSplitMix64(seed: seed)
            var values = pooled
            var extreme = 0
            for iteration in 0..<sampleCount {
                if iteration.isMultiple(of: 1_024) { try Task.checkCancellation() }
                // Fisher–Yates parziale: bastano le prime `first` posizioni.
                for position in 0..<first {
                    let other = position + generator.index(below: values.count - position)
                    values.swapAt(position, other)
                }
                if isExtreme(difference(firstSum: values[0..<first].reduce(0, +))) {
                    extreme += 1
                }
            }
            return GlifiPermutationTestResult(
                observedDifference: observed,
                strategy: strategy,
                evaluatedCount: sampleCount,
                extremeCount: extreme,
                pValue: Double(extreme + 1) / Double(sampleCount + 1),
                alternative: alternative
            )
        }
    }

    /// Type-7 quantile of already sorted values: `x[h] + (h-⌊h⌋)(x[⌊h⌋+1]-x[⌊h⌋])`,
    /// with zero-based `h = (n-1)p`.
    static func quantileType7(_ sorted: [Double], probability: Double) throws -> Double {
        guard !sorted.isEmpty, (0...1).contains(probability) else {
            throw resamplingFailure("statistics.invalid-quantile", category: .invalidInput)
        }
        let position = Double(sorted.count - 1) * probability
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = min(lowerIndex + 1, sorted.count - 1)
        let fraction = position - Double(lowerIndex)
        return sorted[lowerIndex] + fraction * (sorted[upperIndex] - sorted[lowerIndex])
    }

    /// `C(n,k)` or `nil` on overflow.
    static func binomialCoefficient(_ n: Int, _ k: Int) -> Int? {
        guard k >= 0, k <= n else { return 0 }
        let k = min(k, n - k)
        var result = 1
        for step in 0..<k {
            let (product, overflow) = result.multipliedReportingOverflow(by: n - step)
            guard !overflow else { return nil }
            result = product / (step + 1)
        }
        return result
    }

    /// Advances `indices` to the next `k`-combination of `0..<universe` in lexicographic order.
    private static func advanceCombination(_ indices: inout [Int], universe: Int) -> Bool {
        let size = indices.count
        var position = size - 1
        while position >= 0, indices[position] == universe - size + position {
            position -= 1
        }
        guard position >= 0 else { return false }
        indices[position] += 1
        for next in (position + 1)..<size {
            indices[next] = indices[next - 1] + 1
        }
        return true
    }
}

private func resamplingFailure(
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
