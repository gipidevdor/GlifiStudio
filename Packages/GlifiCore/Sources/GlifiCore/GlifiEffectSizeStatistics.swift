// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// `HedgesG-v1` with the normal-approximation interval of Cohen's d.
public struct GlifiStandardizedDifference: Codable, Equatable, Sendable {
    /// `CohenD-pooled-v1`.
    public let cohenD: Double
    /// Exact small-sample factor `J = Γ(ν/2)/(√(ν/2)·Γ((ν-1)/2))`, `ν = n₁+n₂-2`.
    public let correctionFactor: Double
    /// `g = J·d`.
    public let hedgesG: Double
    /// `SE(d) = sqrt((n₁+n₂)/(n₁n₂) + d²/(2(n₁+n₂)))`.
    public let standardError: Double
    /// Confidence level of the interval.
    public let confidenceLevel: Double
    /// Lower bound `d - z·SE(d)`.
    public let lower: Double
    /// Upper bound `d + z·SE(d)`.
    public let upper: Double
}

/// Fisher-z confidence interval of Pearson's r.
public struct GlifiCorrelationInterval: Codable, Equatable, Sendable {
    /// `PearsonFisherZ-v1` identity.
    public static let identifier = "PearsonFisherZ-v1"

    /// Confidence level.
    public let confidenceLevel: Double
    /// `tanh(atanh(r) - z/√(n-3))`.
    public let lower: Double
    /// `tanh(atanh(r) + z/√(n-3))`.
    public let upper: Double
}

extension GlifiStatisticalFoundation {
    /// `HedgesG-v1` identity.
    public static let hedgesIdentifier = "HedgesG-v1"
    /// `RankBiserial-v1` identity.
    public static let rankBiserialIdentifier = "RankBiserial-v1"
    /// `KruskalEpsilonSquared-v1` identity.
    public static let epsilonSquaredIdentifier = "KruskalEpsilonSquared-v1"
    /// `SpearmanExactPermutation-v1` identity.
    public static let spearmanExactIdentifier = "SpearmanExactPermutation-v1"
    /// Largest sample enumerated by the exact Spearman permutation law (`9! = 362 880`).
    public static let maximumExactSpearmanCount = 9

    /// Cohen's d, Hedges' g and the normal-approximation interval of d.
    public static func standardizedDifference(
        _ sample1: [Double],
        _ sample2: [Double],
        confidenceLevel: Double = 0.95
    ) throws -> GlifiStandardizedDifference {
        guard confidenceLevel > 0, confidenceLevel < 1 else {
            throw effectSizeFailure("statistics.invalid-confidence-level", category: .invalidInput)
        }
        let d = try cohenDPooled(sample1, sample2).d
        let first = Double(sample1.count)
        let second = Double(sample2.count)
        let degrees = first + second - 2
        guard degrees > 1 else {
            throw effectSizeFailure("statistics.insufficient-sample-size")
        }
        let factor = exp(
            lgamma(degrees / 2) - log((degrees / 2).squareRoot()) - lgamma((degrees - 1) / 2)
        )
        let standardError =
            ((first + second) / (first * second) + d * d / (2 * (first + second))).squareRoot()
        let z = try GlifiDistributionFunctions.normalQuantile((1 + confidenceLevel) / 2)
        return GlifiStandardizedDifference(
            cohenD: d,
            correctionFactor: factor,
            hedgesG: factor * d,
            standardError: standardError,
            confidenceLevel: confidenceLevel,
            lower: d - z * standardError,
            upper: d + z * standardError
        )
    }

    /// `RankBiserial-v1`: `r = 2U₁/(n₁n₂) - 1`, positive when the first sample is larger.
    public static func rankBiserial(u1: Double, firstCount: Int, secondCount: Int) -> Double {
        2 * u1 / (Double(firstCount) * Double(secondCount)) - 1
    }

    /// `KruskalEpsilonSquared-v1`: `ε² = H/(N-1)` on the tie-corrected `H`.
    public static func kruskalEpsilonSquared(correctedH: Double, totalCount: Int) -> Double {
        correctedH / Double(totalCount - 1)
    }

    /// Fisher-z interval of Pearson's r; requires `n ≥ 4` and `|r| < 1`.
    public static func pearsonFisherInterval(
        coefficient: Double,
        sampleCount: Int,
        confidenceLevel: Double = 0.95
    ) throws -> GlifiCorrelationInterval {
        guard sampleCount >= 4 else {
            throw effectSizeFailure("statistics.insufficient-sample-size")
        }
        guard abs(coefficient) < 1 else {
            throw effectSizeFailure("statistics.perfect-correlation")
        }
        guard confidenceLevel > 0, confidenceLevel < 1 else {
            throw effectSizeFailure("statistics.invalid-confidence-level", category: .invalidInput)
        }
        let z = try GlifiDistributionFunctions.normalQuantile((1 + confidenceLevel) / 2)
        let center = atanh(coefficient)
        let halfWidth = z / Double(sampleCount - 3).squareRoot()
        return GlifiCorrelationInterval(
            confidenceLevel: confidenceLevel,
            lower: tanh(center - halfWidth),
            upper: tanh(center + halfWidth)
        )
    }

    /// Exact permutation p-value of Spearman's ρ over all `n!` rankings.
    ///
    /// Requires `3 ≤ n ≤ 9` and no ties in either variable; the two-sided p-value is
    /// `min(1, 2·min(P(ρ≤ρ₀), P(ρ≥ρ₀)))`.
    public static func spearmanExactPValue(
        _ x: [Double],
        _ y: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> Double {
        guard x.count == y.count else {
            throw effectSizeFailure("statistics.paired-length-mismatch", category: .invalidInput)
        }
        guard (3...maximumExactSpearmanCount).contains(x.count) else {
            throw effectSizeFailure("statistics.exact-sample-too-large", category: .invalidInput)
        }
        guard x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite) else {
            throw effectSizeFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let rankX = midranks(x)
        let rankY = midranks(y)
        guard rankX.tieGroupSizes.isEmpty, rankY.tieGroupSizes.isEmpty else {
            throw effectSizeFailure("statistics.exact-requires-no-ties")
        }
        // ρ è funzione decrescente di S = Σ(rx-ry)²: si confrontano gli interi S.
        let count = x.count
        let order = rankX.ranks.indices.sorted { rankX.ranks[$0] < rankX.ranks[$1] }
        let targets = order.map { Int(rankY.ranks[$0]) }
        let observed = targets.enumerated().reduce(0) {
            $0 + ($1.offset + 1 - $1.element) * ($1.offset + 1 - $1.element)
        }
        var permutation = Array(1...count)
        var atMost = 0
        var atLeast = 0
        var total = 0
        func visit() {
            total += 1
            let s = permutation.enumerated().reduce(0) {
                $0 + ($1.offset + 1 - $1.element) * ($1.offset + 1 - $1.element)
            }
            if s <= observed { atMost += 1 }
            if s >= observed { atLeast += 1 }
        }
        // Algoritmo di Heap, iterativo.
        var counters = [Int](repeating: 0, count: count)
        visit()
        var index = 0
        while index < count {
            if counters[index] < index {
                permutation.swapAt(index.isMultiple(of: 2) ? 0 : counters[index], index)
                visit()
                counters[index] += 1
                index = 0
            } else {
                counters[index] = 0
                index += 1
            }
        }
        // S piccolo ⇔ ρ grande.
        let greater = Double(atMost) / Double(total)
        let less = Double(atLeast) / Double(total)
        switch alternative {
        case .greater: return greater
        case .less: return less
        case .twoSided: return min(1, 2 * min(greater, less))
        }
    }
}

private func effectSizeFailure(
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
