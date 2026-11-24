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

/// The seven global-token conventions printed in KH Coder 3 manual A.5.6, page 40.
public struct GlifiKHCollocationScores: Equatable, Sendable {
    /// Combined profile, distinct from statistics over a table of window opportunities.
    public static let identifier = "KH-collocation-global-token-window-v1"
    /// MI3 uses base-two logarithms and the global corpus token exposure.
    public static let mi3Identifier = "KH-Collocation-MI3-global-token-v1"
    /// Z uses the background exposure N−F1 and the explicit window span.
    public static let zIdentifier = "KH-Collocation-Z-global-token-window-v1"
    /// `log2(aN/(F1F2))`; undefined when the observed pair count is zero.
    public let mutualInformation: Double?
    /// `log2(a³N/(F1F2))`; undefined when the observed pair count is zero.
    public let mi3: Double?
    /// `(a-F1F2/N)/sqrt(a)` with an exact integer residual; undefined when a is zero.
    public let tScore: Double?
    /// `(a−E)/sqrt(E(1−p))`, with `p=F2/(N−F1)` and `E=pF1S`.
    ///
    /// Undefined when the background or binomial variance is zero.
    public let zScore: Double?
    /// Window expectation E, retaining the denominator convention used by Z.
    ///
    /// Undefined only when the background exposure N−F1 is zero.
    public let expectedWindowCount: Double?
    /// `a/(F1+F2-a)`, without a clamp; undefined when the denominator is nonpositive.
    public let jaccard: Double?
    /// `2a/(F1+F2)`, without a clamp; undefined when both global frequencies are zero.
    public let dice: Double?
    /// Manual entropy expression, equal to uncorrected G-squared divided by two.
    ///
    /// Undefined for zero corpus exposure or window overlap a exceeding either global TF.
    /// Zero cells and zero margins use the continuous convention 0*log(0)=0.
    public let logLikelihood: Double?
}

/// Constant-space KH scores over an explicitly declared global token universe.
public enum GlifiKHCollocationAnalysis {
    /// Computes the manual's formulas without replacing global TF by window marginals.
    public static func scores(_ input: GlifiKHCollocationInput) throws
        -> GlifiKHCollocationScores
    {
        try Task.checkCancellation()
        let observed = Double(input.jointCount)
        let globalProduct = UInt128(input.nodeFrequency) * UInt128(input.collocateFrequency)
        let observedProduct = UInt128(input.jointCount) * UInt128(input.corpusTokenCount)
        let residual = khCollocationDifference(observedProduct, globalProduct)
        var mutualInformation: Double?
        var mi3: Double?
        var tScore: Double?
        if input.jointCount > 0 {
            let relative = residual / Double(globalProduct)
            let information =
                abs(relative) <= 0.5
                ? log1p(relative) / log(2)
                : log2(Double(observedProduct) / Double(globalProduct))
            mutualInformation = information
            // Algebraically identical to log2(a^3*N/(F1*F2)), without a cube or lost residual.
            mi3 = information + 2 * log2(observed)
            tScore = residual / Double(input.corpusTokenCount) / observed.squareRoot()
        }
        // F1+F2 is representable because input validation requires that sum not exceed N.
        let frequencySum = input.nodeFrequency + input.collocateFrequency
        let union = frequencySum - input.jointCount
        let jaccard = union > 0 ? observed / Double(union) : nil
        let dice = frequencySum > 0 ? 2 * observed / Double(frequencySum) : nil
        let logLikelihood = try khCollocationLogLikelihood(input)
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
        guard
            [mutualInformation, mi3, tScore, expectation, zScore, jaccard, dice, logLikelihood]
                .allSatisfy({ $0?.isFinite ?? true })
        else {
            throw collocationFailure("kh-collocation.numeric-overflow")
        }
        return GlifiKHCollocationScores(
            mutualInformation: mutualInformation, mi3: mi3, tScore: tScore,
            zScore: zScore, expectedWindowCount: expectation,
            jaccard: jaccard, dice: dice, logLikelihood: logLikelihood)
    }
}

private func khCollocationDifference(_ first: UInt128, _ second: UInt128) -> Double {
    first >= second ? Double(first - second) : -Double(second - first)
}

/// KH manual A.5.7 document probabilities, without an implicit positive-association filter.
public struct GlifiKHWordAssociationScores: Equatable, Sendable {
    /// Versioned identity of this declared document-frequency universe.
    public static let identifier = "KH-word-association-document-v1"
    /// Term document frequency divided by all documents; undefined for an empty universe.
    public let unconditionalProbability: Double?
    /// Joint frequency divided by condition DF, also the manual's Frequency sorting measure.
    public let conditionalProbability: Double?
    /// Conditional minus unconditional probability, preserving the exact integer residual.
    public let differential: Double?
    /// Conditional divided by unconditional probability; undefined for a zero denominator.
    public let lift: Double?
    /// Joint DF divided by the document union; undefined for a zero union.
    public let jaccard: Double?
    /// Joint DF divided by the geometric mean of both document frequencies.
    public let ochiai: Double?
    /// Exact a*N > conditionDF*termDF, even when rounded probabilities are identical.
    public let isPositiveAssociation: Bool
}

/// Constant-space word association over a validated document contingency table.
public enum GlifiKHWordAssociationAnalysis {
    /// Returns every defined measure and its exact direction without filtering the result.
    public static func scores(_ counts: GlifiCooccurrenceCounts) throws
        -> GlifiKHWordAssociationScores
    {
        try Task.checkCancellation()
        let total = counts.universeSize
        let first = counts.firstMarginal
        let second = counts.secondMarginal
        let joint = counts.jointCount
        let observedProduct = UInt128(joint) * UInt128(total)
        let marginalProduct = UInt128(first) * UInt128(second)
        let unconditional = total > 0 ? Double(second) / Double(total) : nil
        let conditional = first > 0 ? Double(joint) / Double(first) : nil
        let differential =
            first > 0 && total > 0
            ? khCollocationDifference(observedProduct, marginalProduct)
                / Double(UInt128(first) * UInt128(total)) : nil
        let lift = marginalProduct > 0 ? Double(observedProduct) / Double(marginalProduct) : nil
        // The checked nonnegative universe also bounds every partial document union.
        let union = first + counts.secondOnlyCount
        let jaccard = union > 0 ? Double(joint) / Double(union) : nil
        let ochiai =
            marginalProduct > 0
            ? Double(joint) / Double(marginalProduct).squareRoot() : nil
        guard
            [unconditional, conditional, differential, lift, jaccard, ochiai]
                .allSatisfy({ $0?.isFinite ?? true })
        else { throw collocationFailure("kh-word-association.numeric-overflow") }
        return GlifiKHWordAssociationScores(
            unconditionalProbability: unconditional, conditionalProbability: conditional,
            differential: differential, lift: lift, jaccard: jaccard, ochiai: ochiai,
            isPositiveAssociation: observedProduct > marginalProduct)
    }
}

private func khCollocationLogLikelihood(_ input: GlifiKHCollocationInput) throws -> Double? {
    let total = input.corpusTokenCount
    let first = input.nodeFrequency
    let second = input.collocateFrequency
    let observed = input.jointCount
    guard total > 0, observed <= min(first, second) else { return nil }
    // All four cells are nonnegative and at most N under the validated global margins.
    let cells = [
        (observed, first, second),
        (first - observed, first, total - second),
        (second - observed, total - first, second),
        (total - first - second + observed, total - first, total - second),
    ]
    var result = 0.0
    var correction = 0.0
    for (count, row, column) in cells {
        let product = UInt128(row) * UInt128(column)
        if product == 0 { continue }
        let expected = Double(product) / Double(total)
        let term: Double
        if count == 0 {
            term = expected
        } else {
            let difference = khCollocationDifference(UInt128(count) * UInt128(total), product)
            let relative = difference / Double(product)
            if abs(relative) <= 0.25 {
                // (1+r)*log1p(r)-r = sum(n>=2) (-1)^n*r^n/(n*(n-1)).
                // Exact integer residuals prevent false zero statistics near independence.
                var power = relative * relative
                var series = power / 2
                for order in 3...64 {
                    power *= relative
                    let component =
                        (order.isMultiple(of: 2) ? power : -power)
                        / Double(order * (order - 1))
                    series += component
                    if abs(component) <= abs(series) * Double.ulpOfOne { break }
                }
                term = expected * series
            } else {
                term = Double(count) * log(Double(count) / expected) - difference / Double(total)
            }
        }
        guard term.isFinite, term >= 0 else {
            throw collocationFailure("kh-collocation.numeric-overflow")
        }
        let adjusted = term - correction
        let updated = result + adjusted
        correction = (updated - result) - adjusted
        result = updated
    }
    return result
}
