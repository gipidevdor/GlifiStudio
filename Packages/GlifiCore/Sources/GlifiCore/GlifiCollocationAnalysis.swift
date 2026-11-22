// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One 2×2 co-occurrence table for a pair `(x,y)` over an explicit universe
/// of `M=a+b+c+d` opportunities.
public struct GlifiCooccurrenceCounts: Equatable, Sendable {
    /// `a`: joint observations of `x` and `y`.
    public let jointCount: Int
    /// `b`: observations of `x` only.
    public let firstOnlyCount: Int
    /// `c`: observations of `y` only.
    public let secondOnlyCount: Int
    /// `d`: observations of neither.
    public let neitherCount: Int

    /// Creates a table only after checking non-negative counts.
    public init(
        jointCount: Int,
        firstOnlyCount: Int,
        secondOnlyCount: Int,
        neitherCount: Int
    ) throws {
        guard jointCount >= 0, firstOnlyCount >= 0, secondOnlyCount >= 0, neitherCount >= 0 else {
            throw collocationFailure("collocation.negative-count", category: .invalidInput)
        }
        self.jointCount = jointCount
        self.firstOnlyCount = firstOnlyCount
        self.secondOnlyCount = secondOnlyCount
        self.neitherCount = neitherCount
    }

    /// `M = a+b+c+d`.
    public var universeSize: Int {
        jointCount + firstOnlyCount + secondOnlyCount + neitherCount
    }
    /// `a+b`: total observations of `x`.
    public var firstMarginal: Int { jointCount + firstOnlyCount }
    /// `a+c`: total observations of `y`.
    public var secondMarginal: Int { jointCount + secondOnlyCount }
}

/// Association measures for one `GlifiCooccurrenceCounts`.
///
/// Each is `nil` exactly where GS-MET-001-11 declares it undefined.
/// Smoothing is never implicit.
public struct GlifiCollocationMeasures: Equatable, Sendable {
    /// Versioned identifier of `pmi`.
    public static let pmiIdentifier = "PMI-v1"
    /// Versioned identifier of `npmi`.
    public static let npmiIdentifier = "NPMI-v1"
    /// Versioned identifier of `dice`.
    public static let diceIdentifier = "Dice-v1"
    /// Versioned identifier of `jaccard`.
    public static let jaccardIdentifier = "Jaccard-v1"
    /// Versioned identifier of `tScore`.
    public static let tScoreIdentifier = "t-score-v1"
    /// Versioned identifier of `logDice`.
    public static let logDiceIdentifier = "logDice-v1"

    /// `ln[p(x,y)/(p(x)p(y))]`; `nil` unless `p(x,y)>0`.
    public let pmi: Double?
    /// `PMI / -ln p(x,y)`; `nil` unless `0<p(x,y)≤1` (continuity value `1` at `p(x,y)=1`).
    public let npmi: Double?
    /// `2a / (2a+b+c)`; `nil` when the denominator is not positive.
    public let dice: Double?
    /// `a / (a+b+c)`; `nil` when the denominator is not positive.
    public let jaccard: Double?
    /// `(a-E_a) / sqrt(a)`; `nil` unless `a>0`.
    public let tScore: Double?
    /// `14 + log2[2a/(2a+b+c)]`; `nil` unless `a>0`.
    public let logDice: Double?
}

/// Bounded, deterministic collocation association measures (GS-MET-001-11).
public enum GlifiCollocationAnalysis {
    /// Computes every declared measure.
    ///
    /// Never throws: each measure reports `nil` where its own precondition
    /// is not met, rather than an out-of-domain value.
    public static func measures(_ counts: GlifiCooccurrenceCounts) -> GlifiCollocationMeasures {
        let joint = Double(counts.jointCount)
        let firstOnly = Double(counts.firstOnlyCount)
        let secondOnly = Double(counts.secondOnlyCount)
        let universe = Double(counts.universeSize)

        var pmi: Double?
        var npmi: Double?
        if counts.jointCount > 0 {
            let jointProbability = joint / universe
            let firstProbability = Double(counts.firstMarginal) / universe
            let secondProbability = Double(counts.secondMarginal) / universe
            let pmiValue = log(jointProbability / (firstProbability * secondProbability))
            pmi = pmiValue
            npmi = jointProbability >= 1 ? 1 : pmiValue / -log(jointProbability)
        }

        let diceDenominator = 2 * joint + firstOnly + secondOnly
        let dice = diceDenominator > 0 ? (2 * joint) / diceDenominator : nil

        let jaccardDenominator = joint + firstOnly + secondOnly
        let jaccard = jaccardDenominator > 0 ? joint / jaccardDenominator : nil

        var tScore: Double?
        var logDice: Double?
        if counts.jointCount > 0 {
            let expectedJoint =
                Double(counts.firstMarginal) * Double(counts.secondMarginal) / universe
            tScore = (joint - expectedJoint) / joint.squareRoot()
            logDice = 14 + log2((2 * joint) / diceDenominator)
        }

        return GlifiCollocationMeasures(
            pmi: pmi,
            npmi: npmi,
            dice: dice,
            jaccard: jaccard,
            tScore: tScore,
            logDice: logDice
        )
    }
}

func collocationFailure(
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
