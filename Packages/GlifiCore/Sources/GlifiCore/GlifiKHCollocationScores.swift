// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Global token frequencies and observed window pairs for two distinct lexical keys.
///
/// This is not a 2×2 table of window opportunities. Overlapping windows can make
/// `jointCount` larger than either global term frequency. `windowSpan` is the
/// number of admitted positions, for example 10 for five positions on each side.
public struct GlifiKHCollocationInput: Equatable, Sendable {
    /// Observed node–collocate pairs within the declared window.
    public let jointCount: Int
    /// Node occurrences in the complete target corpus, before vocabulary filtering.
    public let nodeFrequency: Int
    /// Collocate occurrences in that same complete corpus.
    public let collocateFrequency: Int
    /// Complete corpus token exposure, not a count of window opportunities.
    public let corpusTokenCount: Int
    /// Number of admitted offsets around each node occurrence, excluding offset zero.
    public let windowSpan: Int

    /// Validates global frequencies and the theoretical maximum number of window pairs.
    public init(
        jointCount: Int, nodeFrequency: Int, collocateFrequency: Int,
        corpusTokenCount: Int, windowSpan: Int
    ) throws {
        guard jointCount >= 0, nodeFrequency >= 0, collocateFrequency >= 0,
            corpusTokenCount >= 0, windowSpan > 0, nodeFrequency <= corpusTokenCount,
            collocateFrequency <= corpusTokenCount - nodeFrequency
        else { throw collocationFailure("kh-collocation.invalid-input") }
        for frequency in [nodeFrequency, collocateFrequency] {
            let capacity = frequency.multipliedReportingOverflow(by: windowSpan)
            guard capacity.overflow || jointCount <= capacity.partialValue else {
                throw collocationFailure("kh-collocation.inconsistent-window-count")
            }
        }
        let pairCapacity = nodeFrequency.multipliedReportingOverflow(by: collocateFrequency)
        guard pairCapacity.overflow || jointCount <= pairCapacity.partialValue else {
            throw collocationFailure("kh-collocation.inconsistent-window-count")
        }
        self.jointCount = jointCount
        self.nodeFrequency = nodeFrequency
        self.collocateFrequency = collocateFrequency
        self.corpusTokenCount = corpusTokenCount
        self.windowSpan = windowSpan
    }
}

/// The MI3 and Z conventions printed in KH Coder 3 manual A.5.6, page 40.
public struct GlifiKHCollocationScores: Equatable, Sendable {
    /// MI3 uses base-two logarithms and the global corpus token exposure.
    public static let mi3Identifier = "KH-Collocation-MI3-global-token-v1"
    /// Z uses the background exposure N−F1 and the explicit window span.
    public static let zIdentifier = "KH-Collocation-Z-global-token-window-v1"
    /// `log2(a³N/(F1F2))`; undefined when the observed pair count is zero.
    public let mi3: Double?
    /// `(a−E)/sqrt(E(1−p))`, with `p=F2/(N−F1)` and `E=pF1S`.
    ///
    /// Undefined when the background or binomial variance is zero.
    public let zScore: Double?
    /// Window expectation E, retaining the denominator convention used by Z.
    ///
    /// Undefined only when the background exposure N−F1 is zero.
    public let expectedWindowCount: Double?
}

/// Constant-space KH scores over an explicitly declared global token universe.
public enum GlifiKHCollocationAnalysis {
    /// Computes the manual's formulas without replacing global TF by window marginals.
    public static func scores(_ input: GlifiKHCollocationInput) throws
        -> GlifiKHCollocationScores
    {
        try Task.checkCancellation()
        let observed = Double(input.jointCount)
        var mi3: Double?
        if input.jointCount > 0 {
            // Separate logarithms avoid forming an integer cube or intermediate ratio.
            mi3 =
                3 * log2(observed) + log2(Double(input.corpusTokenCount))
                - log2(Double(input.nodeFrequency)) - log2(Double(input.collocateFrequency))
        }
        var expectation: Double?
        var zScore: Double?
        let background = input.corpusTokenCount - input.nodeFrequency
        if background > 0 {
            let trials = UInt128(input.nodeFrequency) * UInt128(input.windowSpan)
            let expected =
                Double(trials)
                * (Double(input.collocateFrequency) / Double(background))
            expectation = expected
            // Algebraically multiply the numerator and denominator by N−F1.
            // Exact integer subtraction preserves a small residual even when p
            // or E would round to one of its neighboring integer counts.
            let observedNumerator = UInt128(input.jointCount) * UInt128(background)
            let expectedNumerator = trials.multipliedReportingOverflow(
                by: UInt128(input.collocateFrequency))
            let difference: Double
            if expectedNumerator.overflow {
                // The expected product then exceeds 2^128 while the observed
                // product is below 2^126: subtraction cannot be ill-conditioned.
                difference =
                    observed * Double(background)
                    - Double(trials) * Double(input.collocateFrequency)
            } else if observedNumerator >= expectedNumerator.partialValue {
                difference = Double(observedNumerator - expectedNumerator.partialValue)
            } else {
                difference = -Double(expectedNumerator.partialValue - observedNumerator)
            }
            let denominator =
                (Double(trials) * Double(input.collocateFrequency)
                * Double(background - input.collocateFrequency)).squareRoot()
            if denominator > 0 { zScore = difference / denominator }
        }
        guard [mi3, expectation, zScore].allSatisfy({ $0?.isFinite ?? true }) else {
            throw collocationFailure("kh-collocation.numeric-overflow")
        }
        return GlifiKHCollocationScores(
            mi3: mi3, zScore: zScore, expectedWindowCount: expectation)
    }
}
