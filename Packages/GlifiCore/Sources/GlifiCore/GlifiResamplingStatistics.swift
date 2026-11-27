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
        try bootstrapMeanInterval(
            sample, confidenceLevel: confidenceLevel, resampleCount: resampleCount,
            seed: seed, checkpoint: { _ in try Task.checkCancellation() })
    }

    static func bootstrapMeanInterval(
        _ sample: [Double], confidenceLevel: Double, resampleCount: Int, seed: UInt64,
        checkpoint: (Int) throws -> Void
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
            seed: seed,
            checkpoint: checkpoint
        )
        let tail = (1 - confidenceLevel) / 2
        return GlifiBootstrapInterval(
            estimate: try resamplingLocation(sample).estimate,
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
        seed: UInt64,
        checkpoint: (Int) throws -> Void = { _ in try Task.checkCancellation() }
    ) throws -> [Double] {
        try checkpoint(0)
        let conditioned = try conditionedResamplingSample(sample)
        var progress = ResamplingObservationProgress()
        var generator = GlifiSplitMix64(seed: seed)
        var means: [Double] = []
        means.reserveCapacity(resampleCount)
        for iteration in 0..<resampleCount {
            if iteration > 0, iteration.isMultiple(of: 1_024) {
                try checkpoint(progress.completed)
            }
            var total = 0.0
            var drawn = 0
            while drawn < sample.count {
                let take = try progress.chunkCount(
                    upTo: sample.count - drawn, checkpoint: checkpoint)
                for _ in 0..<take {
                    total += conditioned.values[generator.index(below: sample.count)]
                }
                progress.consume(take)
                drawn += take
            }
            let mean =
                conditioned.constant
                ?? resamplingScale(total / Double(sample.count), by: conditioned.exponent)
            guard mean.isFinite else {
                throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
            }
            means.append(mean)
        }
        try checkpoint(progress.completed)
        let sorted = means.sorted()
        try checkpoint(progress.completed)
        return sorted
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
        try movingBlockBootstrapMeanInterval(
            sequence, blockLength: blockLength, confidenceLevel: confidenceLevel,
            resampleCount: resampleCount, seed: seed,
            checkpoint: { _ in try Task.checkCancellation() })
    }

    static func movingBlockBootstrapMeanInterval(
        _ sequence: [Double], blockLength: Int, confidenceLevel: Double,
        resampleCount: Int, seed: UInt64, checkpoint: (Int) throws -> Void
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
        if blockLength == 1 {
            // Keep MBB validation precedence, then reuse the identical draw stream and checkpoints.
            return try bootstrapMeanInterval(
                sequence, confidenceLevel: confidenceLevel,
                resampleCount: resampleCount, seed: seed, checkpoint: checkpoint)
        }
        try checkpoint(0)
        let conditioned = try conditionedResamplingSample(sequence)
        var progress = ResamplingObservationProgress()
        var generator = GlifiSplitMix64(seed: seed)
        let count = sequence.count
        var means: [Double] = []
        means.reserveCapacity(resampleCount)
        for iteration in 0..<resampleCount {
            if iteration > 0, iteration.isMultiple(of: 1_024) {
                try checkpoint(progress.completed)
            }
            var total = 0.0
            var drawn = 0
            while drawn < count {
                let start = generator.index(below: count - blockLength + 1)
                let take = min(blockLength, count - drawn)
                var offset = 0
                while offset < take {
                    let chunk = try progress.chunkCount(upTo: take - offset, checkpoint: checkpoint)
                    let end = offset + chunk
                    for position in offset..<end {
                        total += conditioned.values[start + position]
                    }
                    progress.consume(chunk)
                    offset = end
                }
                drawn += take
            }
            let mean =
                conditioned.constant
                ?? resamplingScale(total / Double(count), by: conditioned.exponent)
            guard mean.isFinite else {
                throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
            }
            means.append(mean)
        }
        try checkpoint(progress.completed)
        means.sort()
        try checkpoint(progress.completed)
        let tail = (1 - confidenceLevel) / 2
        return GlifiBootstrapInterval(
            estimate: try resamplingLocation(sequence).estimate,
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
        // Admission precedes conditioning, allocation and cancellation checkpoints.
        switch strategy {
        case .exact:
            guard
                let assignments = binomialCoefficient(sample1.count + sample2.count, sample1.count),
                assignments <= maximumExactPermutationCount
            else {
                throw resamplingFailure(
                    "statistics.exact-permutation-too-large", category: .invalidInput)
            }
        case .monteCarlo(let sampleCount, _):
            guard (1...maximumResampleCount).contains(sampleCount) else {
                throw resamplingFailure(
                    "statistics.invalid-resampling-parameters", category: .invalidInput)
            }
        }
        let pooled = sample1 + sample2
        let first = sample1.count
        let second = sample2.count
        let conditioned = try centeredInferenceCoordinates(pooled)
        let values = conditioned.values
        let total = values.reduce(0, +)
        func difference(firstSum: Double) -> Double {
            firstSum / Double(first) - (total - firstSum) / Double(second)
        }
        let normalizedObserved = difference(firstSum: values.prefix(first).reduce(0, +))
        let observed = resamplingScale(normalizedObserved, by: conditioned.exponent)
        guard observed.isFinite else {
            throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
        }
        // Roundoff tolerance is relative to the centered span, independent of units and offset.
        let tolerance = 1e-12 * (values.map(abs).max() ?? 0)
        func isExtreme(_ value: Double) -> Bool {
            switch alternative {
            case .twoSided: abs(value) >= abs(normalizedObserved) - tolerance
            case .greater: value >= normalizedObserved - tolerance
            case .less: value <= normalizedObserved + tolerance
            }
        }

        switch strategy {
        case .exact:
            var extreme = 0
            var evaluated = 0
            var chosen = Array(0..<first)
            while true {
                if evaluated.isMultiple(of: 4_096) { try Task.checkCancellation() }
                evaluated += 1
                if isExtreme(difference(firstSum: chosen.reduce(0.0) { $0 + values[$1] })) {
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
            var generator = GlifiSplitMix64(seed: seed)
            var shuffled = values
            var extreme = 0
            for iteration in 0..<sampleCount {
                if iteration.isMultiple(of: 1_024) { try Task.checkCancellation() }
                // Fisher–Yates parziale: bastano le prime `first` posizioni.
                for position in 0..<first {
                    let other = position + generator.index(below: shuffled.count - position)
                    shuffled.swapAt(position, other)
                }
                if isExtreme(difference(firstSum: shuffled[0..<first].reduce(0, +))) {
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
        let lower = sorted[lowerIndex]
        let upper = sorted[upperIndex]
        guard lower.isFinite, upper.isFinite else {
            throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
        }
        let difference = upper - lower
        let value: Double
        if difference.isFinite {
            // Retain the original ordered arithmetic, including its signed-zero result.
            value = lower + fraction * difference
        } else {
            guard fraction > 0 else { return lower }
            value = (1 - fraction) * lower + fraction * upper
        }
        guard value.isFinite else {
            throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
        }
        return value
    }

    /// Mean and optional leave-one-out means, preserving ordinary ordered sums.
    static func resamplingLocation(
        _ sample: [Double], includeJackknife: Bool = false
    ) throws -> (estimate: Double, jackknife: [Double]) {
        guard !sample.isEmpty, !includeJackknife || sample.count >= 2 else {
            throw resamplingFailure("statistics.insufficient-sample-size")
        }
        let conditioned = try conditionedResamplingSample(sample)
        let total = conditioned.values.reduce(0, +)
        let estimate =
            conditioned.constant
            ?? resamplingScale(
                total / Double(sample.count), by: conditioned.exponent)
        guard estimate.isFinite else {
            throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
        }
        guard includeJackknife else { return (estimate, []) }
        var jackknife: [Double] = []
        jackknife.reserveCapacity(sample.count)
        for (index, value) in conditioned.values.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let mean =
                conditioned.constant
                ?? resamplingScale(
                    (total - value) / Double(sample.count - 1), by: conditioned.exponent)
            guard mean.isFinite else {
                throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
            }
            jackknife.append(mean)
        }
        return (estimate, jackknife)
    }

    private static func conditionedResamplingSample(
        _ sample: [Double]
    ) throws -> (values: [Double], exponent: Int, constant: Double?) {
        var largest = 0.0
        let first = sample.first ?? 0
        var isConstant = true
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            largest = max(largest, abs(value))
            isConstant = isConstant && value == first
        }
        // Reserve headroom for rounding in ordered sums at the admitted sample sizes.
        // The exact max/count bound alone can still overflow after repeated additions.
        guard largest >= Double.greatestFiniteMagnitude / (2 * Double(sample.count)) else {
            return (sample, 0, nil)
        }
        let exponent = largest.exponent
        var values: [Double] = []
        values.reserveCapacity(sample.count)
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let normalized = resamplingScale(value, by: -exponent)
            guard value == 0 || normalized != 0 else {
                throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
            }
            values.append(normalized)
        }
        return (values, exponent, isConstant ? first : nil)
    }

    /// Centered coordinates in a common exact power-of-two unit.
    static func centeredInferenceCoordinates(
        _ sample: [Double]
    ) throws -> (values: [Double], exponent: Int) {
        let anchor = sample.first ?? 0
        var largest = 0.0
        var needsInputScaling = false
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            largest = max(largest, abs(value))
            needsInputScaling = needsInputScaling || !(value - anchor).isFinite
        }
        let inputExponent = needsInputScaling ? largest.exponent : 0
        let scaledAnchor = resamplingScale(anchor, by: -inputExponent)
        func offset(_ value: Double) -> Double {
            needsInputScaling
                ? resamplingScale(value, by: -inputExponent) - scaledAnchor : value - anchor
        }
        var largestOffset = 0.0
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            if needsInputScaling, value != 0,
                resamplingScale(value, by: -inputExponent) == 0
            {
                throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
            }
            largestOffset = max(largestOffset, abs(offset(value)))
        }
        guard largestOffset > 0 else { return (Array(repeating: 0, count: sample.count), 0) }
        let offsetExponent = largestOffset.exponent
        var values: [Double] = []
        values.reserveCapacity(sample.count)
        for (index, value) in sample.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let rawOffset = offset(value)
            let normalized = resamplingScale(rawOffset, by: -offsetExponent)
            guard rawOffset == 0 || normalized != 0 else {
                throw resamplingFailure("statistics.non-finite-result", category: .invalidInput)
            }
            values.append(normalized)
        }
        return (values, inputExponent + offsetExponent)
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

/// Work-based checkpoints shared across replicas; the diagnostic count saturates at Int.max.
private struct ResamplingObservationProgress {
    private var remaining = 4_096
    private(set) var completed = 0

    mutating func chunkCount(upTo count: Int, checkpoint: (Int) throws -> Void) throws -> Int {
        if remaining == 0 {
            try checkpoint(completed)
            remaining = 4_096
        }
        return min(count, remaining)
    }

    mutating func consume(_ count: Int) {
        remaining -= count
        let (next, overflow) = completed.addingReportingOverflow(count)
        completed = overflow ? Int.max : next
    }
}

private func resamplingScale(_ value: Double, by exponent: Int) -> Double {
    Double(sign: value.sign, exponent: exponent, significand: abs(value))
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
