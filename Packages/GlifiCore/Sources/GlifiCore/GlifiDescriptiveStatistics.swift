// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// The variance denominator is a declared analytical choice.
public enum GlifiVarianceConvention: String, Codable, Sendable {
    /// Uses denominator n.
    case population
    /// Uses denominator n-1, undefined for fewer than two values.
    case sample
}

/// One exact Q7-v1 quantile request and result.
public struct GlifiDescriptiveQuantile: Codable, Equatable, Sendable {
    /// Requested probability in [0,1].
    public let probability: Double
    /// Quantile value, or nil when no observations are valid.
    public let value: Double?
}

/// Finite observations with explicit units and excluded missing values.
public struct GlifiDescriptiveSummary: Codable, Equatable, Sendable {
    /// Versioned descriptive and quantile contract.
    public let methodIdentifier: String
    /// Shared unit of the observations.
    public let unitIdentifier: String
    /// Policy applied to absent observations.
    public let missingPolicyIdentifier: String
    /// Declared variance denominator.
    public let varianceConvention: GlifiVarianceConvention
    /// Number of finite observations.
    public let validCount: Int
    /// Number of nil observations excluded.
    public let missingCount: Int
    /// Smallest valid value.
    public let minimum: Double?
    /// Largest valid value.
    public let maximum: Double?
    /// Arithmetic mean of valid values.
    public let mean: Double?
    /// Exact Q7 median.
    public let median: Double?
    /// Variance under the chosen convention.
    public let variance: Double?
    /// Square root of variance.
    public let standardDeviation: Double?
    /// Exact Q7 quantiles in caller order.
    public let quantiles: [GlifiDescriptiveQuantile]
}

/// Exact bounded descriptive statistics from GS-MET-001-04.
public enum GlifiDescriptiveStatistics {
    /// Maximum admitted observations, including missing values.
    public static let maximumObservationCount = 1_000_000

    /// Nil observations are counted and excluded; non-finite numbers are invalid.
    ///
    /// Empty statistics and sample variance with n < 2 are explicitly undefined.
    public static func summarize(
        _ observations: [Double?], unitIdentifier: String,
        variance: GlifiVarianceConvention, probabilities: [Double] = [0.25, 0.5, 0.75]
    ) throws -> GlifiDescriptiveSummary {
        try Task.checkCancellation()
        guard observations.count <= maximumObservationCount, probabilities.count <= 1_024 else {
            throw failure("descriptive.input-limit", category: .insufficientResources)
        }
        guard !unitIdentifier.isEmpty,
            probabilities.allSatisfy({ $0.isFinite && (0...1).contains($0) })
        else { throw failure("descriptive.invalid-parameters") }
        var values: [Double] = []
        for (index, value) in observations.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            if let value {
                guard value.isFinite else { throw failure("descriptive.non-finite-input") }
                values.append(value)
            }
        }
        try sortFiniteValues(&values)
        let count = values.count
        func quantile(_ probability: Double) -> Double? {
            guard count > 0 else { return nil }
            let h = Double(count - 1) * probability
            let lower = Int(h.rounded(.down))
            let upper = min(lower + 1, count - 1)
            let fraction = h - Double(lower)
            return (1 - fraction) * values[lower] + fraction * values[upper]
        }
        // Preserve order statistics before reusing the same buffer for normalization.
        // Adding the origin back to a rounded shift does not always recover its input.
        let minimum = values.first
        let maximum = values.last
        let median = quantile(0.5)
        let quantiles = probabilities.map {
            GlifiDescriptiveQuantile(probability: $0, value: quantile($0))
        }
        var mean: Double?
        var varianceValue: Double?
        var standardDeviation: Double?
        if count > 0 {
            // Subtract an observed origin before scaling, preserving a small spread
            // around a large offset. Scaling raw values first loses significant bits.
            let origin = values[0]
            let scale = (maximum ?? origin) - origin
            // Sorted finite values have non-negative shifts bounded by the last shift.
            // Checking that bound avoids materializing a second array of all differences.
            guard scale.isFinite else {
                throw failure("descriptive.numeric-overflow")
            }
            for index in values.indices {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                values[index] = scale > 0 ? (values[index] - origin) / scale : 0
            }
            var scaledMean = 0.0
            for (index, value) in values.enumerated() {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                scaledMean += (value - scaledMean) / Double(index + 1)
            }
            mean = origin + scaledMean * scale
            let denominator: Int
            switch variance {
            case .population: denominator = count
            case .sample: denominator = count - 1
            }
            if denominator > 0 {
                var sum = 0.0
                for (index, value) in values.enumerated() {
                    if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                    let difference = value - scaledMean
                    sum += difference * difference
                }
                let deviation = sqrt(sum / Double(denominator)) * scale
                let computedVariance = deviation * deviation
                guard deviation.isFinite, computedVariance.isFinite else {
                    throw failure("descriptive.numeric-overflow")
                }
                guard sum == 0 || (deviation > 0 && computedVariance > 0) else {
                    throw failure("descriptive.numeric-underflow")
                }
                standardDeviation = deviation
                varianceValue = computedVariance
            }
        }
        return GlifiDescriptiveSummary(
            methodIdentifier: "Descriptive-Q7-v1", unitIdentifier: unitIdentifier,
            missingPolicyIdentifier: "exclude-and-count-v1", varianceConvention: variance,
            validCount: count, missingCount: observations.count - count,
            minimum: minimum, maximum: maximum, mean: mean, median: median,
            variance: varianceValue, standardDeviation: standardDeviation,
            quantiles: quantiles)
    }

    /// Orders already validated finite values exactly as the native comparison sort.
    ///
    /// An early inversion admits a bounded counted-sort candidate for at most 256
    /// distinct bit patterns. Zero values and higher cardinality retain the native
    /// sort, including its ordering of signed-zero ties. Counts occupy O(256) space;
    /// the original buffer is rewritten only after the candidate has fully succeeded.
    static func sortFiniteValues(_ values: inout [Double]) throws {
        try Task.checkCancellation()
        let probeCount = min(1_024, values.count)
        var hasEarlyInversion = false
        if probeCount > 1 {
            for index in 1..<probeCount where values[index - 1] > values[index] {
                hasEarlyInversion = true
                break
            }
        }
        guard hasEarlyInversion else {
            values.sort()
            return
        }
        var counts: [UInt64: Int] = [:]
        counts.reserveCapacity(256)
        for index in values.indices {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let value = values[index]
            guard value != 0 else {
                values.sort()
                return
            }
            counts[value.bitPattern, default: 0] += 1
            guard counts.count <= 256 else {
                values.sort()
                return
            }
        }
        let ordered = counts.keys.sorted { Double(bitPattern: $0) < Double(bitPattern: $1) }
        var position = 0
        for key in ordered {
            let value = Double(bitPattern: key)
            let repetitions = counts[key] ?? 0
            for _ in 0..<repetitions {
                if position.isMultiple(of: 1_024) { try Task.checkCancellation() }
                values[position] = value
                position += 1
            }
        }
    }

    private static func failure(
        _ code: String, category: GlifiFailureCategory = .invalidInput
    ) -> GlifiFailure {
        GlifiFailure(
            code: code, category: category, operation: .analyze,
            retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
            retainedState: .unchanged,
            messageKey: "failure.\(code)")
    }
}
