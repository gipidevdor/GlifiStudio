// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One explicit partition of `K` units for a dispersion measure: ordered
/// sizes `n_i` and, for one lexical or categorical unit, per-part
/// frequencies `f_i`.
public struct GlifiDispersionPartition: Equatable, Sendable {
    /// Size `n_i` of each partition unit, in partition order.
    public let unitSizes: [Int]
    /// Frequency `f_i` of the measured unit within each partition unit.
    public let unitFrequencies: [Int]

    /// Creates a partition only after checking shape and non-negative counts.
    public init(unitSizes: [Int], unitFrequencies: [Int]) throws {
        guard !unitSizes.isEmpty else {
            throw dispersionFailure("dispersion.empty-partition", category: .invalidInput)
        }
        guard unitSizes.count == unitFrequencies.count else {
            throw dispersionFailure("dispersion.shape-mismatch", category: .invalidInput)
        }
        guard unitSizes.allSatisfy({ $0 >= 0 }), unitFrequencies.allSatisfy({ $0 >= 0 }) else {
            throw dispersionFailure("dispersion.negative-count", category: .invalidInput)
        }
        self.unitSizes = unitSizes
        self.unitFrequencies = unitFrequencies
    }

    /// `K`, the number of units in the partition.
    public var unitCount: Int { unitSizes.count }
    /// `N = Σn_i`.
    public var totalSize: Int { unitSizes.reduce(0, +) }
    /// `F = Σf_i`.
    public var totalFrequency: Int { unitFrequencies.reduce(0, +) }
}

/// Result of one dispersion measurement over a `GlifiDispersionPartition`.
public struct GlifiDispersionResult: Equatable, Sendable {
    /// `0` for a distribution proportional to opportunity; higher for concentration.
    public static let griesDPIdentifier = "GriesDP-v1"
    /// `GriesDP-v1` normalized by its attainable maximum for the same partition.
    public static let griesDPNormIdentifier = "GriesDPnorm-v1"
    /// Equal-size-partition dispersion; not defined for unequal parts.
    public static let juillandDIdentifier = "JuillandD-equal-v1"

    /// `GriesDP-v1` over the declared partition.
    public let griesDP: Double
    /// `GriesDPnorm-v1`; `nil` for `K<2` or a non-positive denominator.
    public let griesDPNorm: Double?
    /// `JuillandD-equal-v1`; `nil` unless `K≥2`, every `n_i` is equal, and `F>0`.
    public let juillandD: Double?
}

/// Bounded, deterministic dispersion measures over one explicit partition.
public enum GlifiDispersionAnalysis {
    /// Computes `GriesDP-v1`, `GriesDPnorm-v1`, and `JuillandD-equal-v1` when applicable.
    ///
    /// Undefined for `F=0` or `N=0` per GS-MET-001-12: throws rather than
    /// reporting a value of zero for an absent unit.
    public static func dispersion(
        _ partition: GlifiDispersionPartition
    ) throws -> GlifiDispersionResult {
        let totalFrequency = partition.totalFrequency
        let totalSize = partition.totalSize
        guard totalFrequency > 0, totalSize > 0 else {
            throw dispersionFailure("dispersion.degenerate-totals", category: .insufficientData)
        }

        let griesDP =
            0.5
            * zip(partition.unitFrequencies, partition.unitSizes).reduce(0.0) { result, pair in
                result
                    + abs(
                        Double(pair.0) / Double(totalFrequency)
                            - Double(pair.1) / Double(totalSize)
                    )
            }

        var griesDPNorm: Double?
        if partition.unitCount >= 2 {
            let minimumOpportunity =
                partition.unitSizes.reduce(Double.infinity) {
                    min($0, Double($1) / Double(totalSize))
                }
            let denominator = 1 - minimumOpportunity
            griesDPNorm = denominator > 0 ? griesDP / denominator : nil
        }

        var juillandD: Double?
        if partition.unitCount >= 2,
            let firstSize = partition.unitSizes.first,
            partition.unitSizes.allSatisfy({ $0 == firstSize })
        {
            let unitCount = Double(partition.unitCount)
            let mean = Double(totalFrequency) / unitCount
            if mean > 0 {
                let variance =
                    partition.unitFrequencies.reduce(0.0) { result, frequency in
                        let deviation = Double(frequency) - mean
                        return result + deviation * deviation
                    } / unitCount
                juillandD = 1 - (variance.squareRoot() / mean) / (unitCount - 1).squareRoot()
            }
        }

        return GlifiDispersionResult(
            griesDP: griesDP,
            griesDPNorm: griesDPNorm,
            juillandD: juillandD
        )
    }
}

func dispersionFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
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
