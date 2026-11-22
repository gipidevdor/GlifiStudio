// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Algebraic Ward.D2 history on declared dissimilarities, without Euclidean variance claims.
public struct GlifiKHLegacyClusteringResult: Codable, Equatable, Sendable {
    /// Compatibility profile of R hclust's Ward.D2 recurrence on dissimilarities.
    public static let identifier = "KH-hclust-WardD2-dissimilarities-v1"
    /// Versioned compatibility method used for this history.
    public var methodIdentifier: String { Self.identifier }
    /// Number of objects in the declared input order.
    public let objectCount: Int
    /// Complete merge history; every wardIncrement is nil because no variance was computed.
    public let merges: [GlifiMerge]
}

/// Compatibility algorithms whose algebraic objectives differ from native Euclidean Ward.
public enum GlifiKHLegacyClustering {
    /// Applies the Ward.D2 Lance-Williams recurrence to finite symmetric nonnegative distances.
    ///
    /// The smallest dissimilarity is merged; exact ties choose the lexicographically smallest
    /// pair of current cluster identities. Singletons are 0..<n and merge s receives n+s.
    /// This is an algebraic compatibility profile, including for Jaccard/cosine dissimilarities;
    /// it makes no claim to minimize Euclidean within-cluster variance. Distances are scaled
    /// before squaring. Unrepresentable positive squares or output heights fail closed.
    public static func wardD2(
        dissimilarities: [[Double]], limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHLegacyClusteringResult {
        try Task.checkCancellation()
        let count = dissimilarities.count
        guard count >= 2, count <= limits.maximumPairwiseObjects else {
            throw exploratoryFailure("kh-ward.invalid-dissimilarities")
        }
        var cells = limits.maximumCells
        try khWardConsume([count, count, 2], remaining: &cells)
        try khWardConsume([count, 12], remaining: &cells)
        var work = limits.maximumWork
        try khWardConsume([count, count, count], remaining: &work)
        try khWardConsume([count, count, 3], remaining: &work)
        var maximum = 0.0
        for row in 0..<count {
            try Task.checkCancellation()
            guard dissimilarities[row].count == count, dissimilarities[row][row] == 0 else {
                throw exploratoryFailure("kh-ward.invalid-dissimilarities")
            }
            for column in 0..<count {
                if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let value = dissimilarities[row][column]
                guard value.isFinite, value >= 0 else {
                    throw exploratoryFailure("kh-ward.invalid-dissimilarities")
                }
                if column < row, value != dissimilarities[column][row] {
                    throw exploratoryFailure("kh-ward.invalid-dissimilarities")
                }
                maximum = max(maximum, value)
            }
        }
        let scale =
            maximum == 0 ? 1 : Double(sign: .plus, exponent: maximum.exponent, significand: 1)
        var squares: [[Double]] = []
        squares.reserveCapacity(count)
        for row in dissimilarities {
            try Task.checkCancellation()
            var normalized: [Double] = []
            normalized.reserveCapacity(count)
            for (column, value) in row.enumerated() {
                if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let ratio = value / scale
                let square = ratio * ratio
                guard value == 0 || square > 0 else {
                    throw exploratoryFailure("kh-ward.numeric-range")
                }
                normalized.append(square)
            }
            squares.append(normalized)
        }
        var active = [Bool](repeating: true, count: count)
        var sizes = [Int](repeating: 1, count: count)
        var identities = Array(0..<count)
        var merges: [GlifiMerge] = []
        merges.reserveCapacity(count - 1)
        for step in 0..<(count - 1) {
            try Task.checkCancellation()
            var best: (left: Int, right: Int, distance: Double)?
            for left in 0..<count where active[left] {
                if left.isMultiple(of: 64) { try Task.checkCancellation() }
                for right in (left + 1)..<count where active[right] {
                    let distance = squares[left][right]
                    let key = (
                        min(identities[left], identities[right]),
                        max(identities[left], identities[right])
                    )
                    if let previous = best {
                        let previousKey = (
                            min(identities[previous.left], identities[previous.right]),
                            max(identities[previous.left], identities[previous.right])
                        )
                        if distance > previous.distance
                            || (distance == previous.distance && key >= previousKey)
                        {
                            continue
                        }
                    }
                    best = (left, right, distance)
                }
            }
            guard let best else { throw exploratoryFailure("kh-ward.invalid-dissimilarities") }
            let left = best.left
            let right = best.right
            let height = best.distance.squareRoot() * scale
            guard height.isFinite, best.distance == 0 || height > 0 else {
                throw exploratoryFailure("kh-ward.numeric-range")
            }
            merges.append(
                GlifiMerge(
                    first: min(identities[left], identities[right]),
                    second: max(identities[left], identities[right]), height: height,
                    wardIncrement: nil, size: sizes[left] + sizes[right]))
            for other in 0..<count where active[other] && other != left && other != right {
                if other.isMultiple(of: 256) { try Task.checkCancellation() }
                let a = Double(sizes[left])
                let b = Double(sizes[right])
                let c = Double(sizes[other])
                let total = a + b + c
                // Since the selected pair is the global minimum, both differences are
                // nonnegative. This equivalent Ward.D2 recurrence avoids cancellation
                // of the subtractive term and preserves exactly equal-height ties.
                let value =
                    best.distance
                    + (a + c) / total * (squares[left][other] - best.distance)
                    + (b + c) / total * (squares[right][other] - best.distance)
                guard value.isFinite, value >= 0,
                    value > 0 || (squares[left][other] == 0 && squares[right][other] == 0)
                else { throw exploratoryFailure("kh-ward.numeric-range") }
                squares[left][other] = value
                squares[other][left] = value
            }
            sizes[left] += sizes[right]
            identities[left] = count + step
            active[right] = false
        }
        try Task.checkCancellation()
        return GlifiKHLegacyClusteringResult(objectCount: count, merges: merges)
    }
}

private func khWardConsume(_ factors: [Int], remaining: inout Int) throws {
    var product = 1
    for factor in factors {
        guard factor >= 0, product == 0 || factor <= remaining / product else {
            throw exploratoryFailure("kh-ward.resource-limit", .insufficientResources)
        }
        product *= factor
    }
    remaining -= product
}
