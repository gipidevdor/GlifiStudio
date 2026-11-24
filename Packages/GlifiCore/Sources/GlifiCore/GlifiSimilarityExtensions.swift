// SPDX-License-Identifier: BSD-3-Clause

import Foundation

extension GlifiVectorSimilarity {
    /// `WeightedJaccard-v1` (Ruzicka): `Σ min(x,y) / Σ max(x,y)` on non-negative vectors.
    public static let weightedJaccardIdentifier = "WeightedJaccard-v1"
    /// `MultisetDice-v1`: `2 Σ min(x,y) / (Σx + Σy)` on non-negative counts.
    public static let multisetDiceIdentifier = "MultisetDice-v1"

    /// Computes `WeightedJaccard-v1`; both vectors must be non-negative and not both zero.
    public static func weightedJaccard(_ x: [Double], _ y: [Double]) throws -> Double {
        try validateNonNegative(x, y)
        let scale = max(x.max() ?? 0, y.max() ?? 0)
        guard scale > 0 else {
            throw similarityExtensionFailure("similarity.zero-vectors")
        }
        let minimum = zip(x, y).reduce(0) { $0 + min($1.0, $1.1) / scale }
        let maximum = zip(x, y).reduce(0) { $0 + max($1.0, $1.1) / scale }
        return minimum / maximum
    }

    /// Computes `MultisetDice-v1`; both vectors must be non-negative and not both zero.
    public static func multisetDice(_ x: [Double], _ y: [Double]) throws -> Double {
        try validateNonNegative(x, y)
        let scale = max(x.max() ?? 0, y.max() ?? 0)
        guard scale > 0 else {
            throw similarityExtensionFailure("similarity.zero-vectors")
        }
        let minimum = zip(x, y).reduce(0) { $0 + min($1.0, $1.1) / scale }
        let total = x.reduce(0) { $0 + $1 / scale } + y.reduce(0) { $0 + $1 / scale }
        return 2 * (minimum / total)
    }

    private static func validateNonNegative(_ x: [Double], _ y: [Double]) throws {
        guard x.count == y.count, !x.isEmpty,
            x.allSatisfy({ $0.isFinite && $0 >= 0 }),
            y.allSatisfy({ $0.isFinite && $0 >= 0 })
        else {
            throw similarityExtensionFailure("similarity.invalid-vectors")
        }
    }
}

extension GlifiProbabilityDivergence {
    /// `Lidstone-v1` smoothing identity: `p_i = (c_i + α)/(N + αV)`.
    public static let lidstoneIdentifier = "Lidstone-v1"

    /// Explicit additive smoothing of counts into a distribution over `V` categories.
    ///
    /// Smoothing is a declared transformation, never implicit (GS-MET-001-13).
    public static func lidstone(_ counts: [Double], alpha: Double) throws -> [Double] {
        guard !counts.isEmpty, alpha > 0, alpha.isFinite,
            counts.allSatisfy({ $0.isFinite && $0 >= 0 })
        else {
            throw similarityExtensionFailure("similarity.invalid-smoothing")
        }
        let scale = max(counts.max() ?? 0, alpha)
        let scaledAlpha = alpha / scale
        let numerators = counts.map { count in
            let combined = count + alpha
            return combined.isFinite ? combined / scale : count / scale + scaledAlpha
        }
        let total = numerators.reduce(0, +)
        return numerators.map { $0 / total }
    }
}

private func similarityExtensionFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: .invalidInput,
        operation: .analyze,
        retryDisposition: .afterCorrection,
        retainedState: .lastCommittedGeneration,
        messageKey: "failure.\(code)"
    )
}
