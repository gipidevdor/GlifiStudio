// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Stable linear membership storage; no pairwise matrix or per-cluster member arrays.
private struct SilhouetteMemberships {
    let offsets: [Int]
    let members: [Int]
    let groups: [Int]

    static func make(_ assignments: [Int], dimensions: Int) throws -> Self? {
        var labels = Set<Int>()
        for index in assignments.indices {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            labels.insert(assignments[index])
        }
        guard labels.count >= 2 else { throw silhouetteUndefined() }
        // Validation has already run. Every valid singleton has width zero.
        guard labels.count != assignments.count else { return nil }
        var comparisons = 0
        let ordered = try labels.sorted {
            comparisons += 1
            if comparisons.isMultiple(of: 4096) { try Task.checkCancellation() }
            return $0 < $1
        }
        var positions: [Int: Int] = [:]
        positions.reserveCapacity(ordered.count)
        for (position, label) in ordered.enumerated() {
            if position.isMultiple(of: 1024) { try Task.checkCancellation() }
            positions[label] = position
        }
        var counts = [Int](repeating: 0, count: ordered.count)
        var groups = [Int](repeating: 0, count: assignments.count)
        for index in assignments.indices {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            guard let group = positions[assignments[index]] else {
                throw exploratoryFailure("clustering.silhouette-membership")
            }
            groups[index] = group
            counts[group] += 1
        }
        var active = 0
        for (index, count) in counts.enumerated() {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            if count > 1 { active += count }
        }
        try requireWork([active, assignments.count - 1, dimensions], .standard)
        var offsets = [Int](repeating: 0, count: ordered.count + 1)
        for group in counts.indices {
            if group.isMultiple(of: 1024) { try Task.checkCancellation() }
            offsets[group + 1] = offsets[group] + counts[group]
        }
        var cursors = offsets
        var members = [Int](repeating: 0, count: assignments.count)
        for index in assignments.indices {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            let group = groups[index]
            members[cursors[group]] = index
            cursors[group] += 1
        }
        return Self(offsets: offsets, members: members, groups: groups)
    }
}

/// Positive floating magnitudes retained outside Double's physical exponent range.
///
/// The normalized significand also preserves subnormal distances until the ratio.
private struct SilhouetteMagnitude: Comparable {
    let significand: Double
    let exponent: Int

    static let zero = Self(0)

    init(_ value: Double) {
        significand = value == 0 ? 0 : value.significand
        exponent = value == 0 ? 0 : value.exponent
    }

    private init(significand: Double, exponent: Int) {
        self.significand = significand
        self.exponent = exponent
    }

    func multiplied(by value: Double) -> Self {
        guard significand != 0, value != 0 else { return .zero }
        let product = significand * value.significand
        return Self(
            significand: product >= 2 ? product / 2 : product,
            exponent: exponent + value.exponent + (product >= 2 ? 1 : 0)
        )
    }

    func divided(by other: Self) -> Double {
        guard significand != 0 else { return 0 }
        return Double(
            sign: .plus,
            exponent: exponent - other.exponent,
            significand: significand / other.significand
        )
    }

    static func < (left: Self, right: Self) -> Bool {
        if left.significand == 0 { return right.significand != 0 }
        if right.significand == 0 { return false }
        return left.exponent == right.exponent
            ? left.significand < right.significand : left.exponent < right.exponent
    }
}

private enum SilhouetteMean {
    case ordinary(Double)
    case scaled(SilhouetteMagnitude)

    var magnitude: SilhouetteMagnitude {
        switch self {
        case let .ordinary(value): SilhouetteMagnitude(value)
        case let .scaled(value): value
        }
    }

    func isLess(than other: Self) -> Bool {
        switch (self, other) {
        case let (.ordinary(left), .ordinary(right)): left < right
        case (.ordinary, .scaled), (.scaled, .ordinary), (.scaled, .scaled):
            magnitude < other.magnitude
        }
    }

    func width(comparedTo other: Self) -> Double {
        switch (self, other) {
        case let (.ordinary(a), .ordinary(b)):
            let denominator = max(a, b)
            return denominator > 0 ? (b - a) / denominator : 0
        case (.ordinary, .scaled), (.scaled, .ordinary), (.scaled, .scaled):
            let a = magnitude
            let b = other.magnitude
            guard a != .zero || b != .zero else { return 0 }
            return a <= b ? 1 - a.divided(by: b) : b.divided(by: a) - 1
        }
    }
}

/// Keeps the ordinary arithmetic order; retries only detected numeric extremes.
struct GlifiSilhouetteComputation {
    private let points: [[Double]]
    private let membership: SilhouetteMemberships
    private let dimensions: Int
    private var distanceCount = 0

    static func calculate(
        _ points: [[Double]], assignments: [Int]
    ) throws -> (widths: [Double], average: Double) {
        try Task.checkCancellation()
        guard points.count == assignments.count, points.count >= 2 else {
            throw silhouetteUndefined()
        }
        let dimensions = points[0].count
        guard dimensions > 0 else {
            throw exploratoryFailure("clustering.silhouette-shape")
        }
        guard points.count <= GlifiExploratoryLimits.standard.maximumCells / dimensions else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        var maximumAbsoluteCoordinate = 0.0
        var minimumNonzeroULP = Double.infinity
        for row in points.indices {
            if row.isMultiple(of: 256) { try Task.checkCancellation() }
            guard points[row].count == dimensions else {
                throw exploratoryFailure("clustering.silhouette-shape")
            }
            for column in points[row].indices {
                if column.isMultiple(of: 1024) { try Task.checkCancellation() }
                guard points[row][column].isFinite else {
                    throw exploratoryFailure("clustering.silhouette-nonfinite")
                }
                let coordinate = points[row][column]
                maximumAbsoluteCoordinate = max(maximumAbsoluteCoordinate, abs(coordinate))
                if coordinate != 0 { minimumNonzeroULP = min(minimumNonzeroULP, coordinate.ulp) }
            }
        }
        guard
            let membership = try SilhouetteMemberships.make(
                assignments, dimensions: dimensions
            )
        else {
            return ([Double](repeating: 0, count: points.count), 0)
        }
        if supportsOrdinaryDistances(
            maximumAbsoluteCoordinate: maximumAbsoluteCoordinate,
            minimumNonzeroULP: minimumNonzeroULP,
            dimensions: dimensions
        ) {
            return try ordinaryWidths(points, membership: membership)
        }
        var computation = Self(points: points, membership: membership, dimensions: dimensions)
        var widths = [Double](repeating: 0, count: points.count)
        for point in points.indices {
            if point.isMultiple(of: 256) { try Task.checkCancellation() }
            let own = membership.groups[point]
            let ownRange = membership.offsets[own]..<membership.offsets[own + 1]
            guard ownRange.count > 1 else { continue }
            let a = try computation.mean(point: point, members: ownRange, excludeSelf: true)
            var b: SilhouetteMean?
            for group in 0..<(membership.offsets.count - 1) where group != own {
                if group.isMultiple(of: 1024) { try Task.checkCancellation() }
                let candidate = try computation.mean(
                    point: point,
                    members: membership.offsets[group]..<membership.offsets[group + 1],
                    excludeSelf: false
                )
                if b.map({ candidate.isLess(than: $0) }) ?? true { b = candidate }
            }
            guard let b else { throw silhouetteUndefined() }
            widths[point] = a.width(comparedTo: b)
        }
        // Exactly the previous left-to-right reduction on ordinary inputs.
        var total = 0.0
        for index in widths.indices {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            total += widths[index]
        }
        return (widths, total / Double(widths.count))
    }

    /// Conservatively proves normal nonzero squares and finite distance sums.
    ///
    /// At a power-of-two boundary, the spacing towards zero can be half the ULP.
    /// The upper bound leaves a factor-of-two margin in the sum of squares.
    /// With at most five million members, neither means nor sums of these
    /// distances can subsequently underflow or overflow.
    static func supportsOrdinaryDistances(
        maximumAbsoluteCoordinate: Double,
        minimumNonzeroULP: Double,
        dimensions: Int
    ) -> Bool {
        minimumNonzeroULP >= 2 * Double.leastNormalMagnitude.squareRoot()
            && maximumAbsoluteCoordinate
                <= (Double.greatestFiniteMagnitude / (8 * Double(dimensions))).squareRoot()
    }

    private static func ordinaryWidths(
        _ points: [[Double]], membership: SilhouetteMemberships
    ) throws -> (widths: [Double], average: Double) {
        var widths = [Double](repeating: 0, count: points.count)
        var distanceCount = 0
        for point in points.indices {
            if point.isMultiple(of: 256) { try Task.checkCancellation() }
            let own = membership.groups[point]
            let ownRange = membership.offsets[own]..<membership.offsets[own + 1]
            guard ownRange.count > 1 else { continue }
            let left = points[point]
            var sum = 0.0
            for offset in ownRange {
                let member = membership.members[offset]
                if member == point { continue }
                distanceCount += 1
                if distanceCount.isMultiple(of: 1024) { try Task.checkCancellation() }
                sum += try provenOrdinaryDistance(left, points[member])
            }
            let a = sum / Double(ownRange.count - 1)
            var b = Double.infinity
            for group in 0..<(membership.offsets.count - 1) where group != own {
                if group.isMultiple(of: 1024) { try Task.checkCancellation() }
                let members = membership.offsets[group]..<membership.offsets[group + 1]
                var between = 0.0
                for offset in members {
                    distanceCount += 1
                    if distanceCount.isMultiple(of: 1024) { try Task.checkCancellation() }
                    between += try provenOrdinaryDistance(left, points[membership.members[offset]])
                }
                let candidate = between / Double(members.count)
                if candidate < b { b = candidate }
            }
            let denominator = max(a, b)
            widths[point] = denominator > 0 ? (b - a) / denominator : 0
        }
        var total = 0.0
        for index in widths.indices {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            total += widths[index]
        }
        return (widths, total / Double(widths.count))
    }

    @inline(__always)
    private static func provenOrdinaryDistance(
        _ left: [Double], _ right: [Double]
    ) throws -> Double {
        var total = 0.0
        if left.count <= 1024 {
            for index in left.indices {
                let difference = left[index] - right[index]
                total += difference * difference
            }
        } else {
            for index in left.indices {
                if index.isMultiple(of: 1024) { try Task.checkCancellation() }
                let difference = left[index] - right[index]
                total += difference * difference
            }
        }
        return total.squareRoot()
    }

    private mutating func checkpoint() throws {
        distanceCount += 1
        if distanceCount.isMultiple(of: 1024) { try Task.checkCancellation() }
    }

    private mutating func ordinaryDistance(_ left: Int, _ right: Int) throws -> Double? {
        try checkpoint()
        var total = 0.0
        var underflow = false
        for index in 0..<dimensions {
            if dimensions > 1024, index.isMultiple(of: 1024) {
                try Task.checkCancellation()
            }
            let difference = points[left][index] - points[right][index]
            let square = difference * difference
            underflow = underflow || (difference != 0 && square < Double.leastNormalMagnitude)
            total += square
        }
        guard total.isFinite, !underflow else { return nil }
        return total.squareRoot()
    }

    private mutating func scaledDistance(
        _ left: Int, _ right: Int
    ) throws -> SilhouetteMagnitude {
        try checkpoint()
        var scale = 0.0
        for index in 0..<dimensions {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            let difference = points[left][index] - points[right][index]
            guard difference.isFinite else {
                throw exploratoryFailure("clustering.silhouette-distance-range")
            }
            scale = max(scale, abs(difference))
        }
        guard scale > 0 else { return .zero }
        var total = 0.0
        for index in 0..<dimensions {
            if index.isMultiple(of: 1024) { try Task.checkCancellation() }
            let normalized = (points[left][index] - points[right][index]) / scale
            total += normalized * normalized
        }
        let magnitude = SilhouetteMagnitude(scale).multiplied(by: total.squareRoot())
        guard magnitude <= SilhouetteMagnitude(Double.greatestFiniteMagnitude) else {
            throw exploratoryFailure("clustering.silhouette-distance-range")
        }
        return magnitude
    }

    private mutating func mean(
        point: Int, members: Range<Int>, excludeSelf: Bool
    ) throws -> SilhouetteMean {
        let count = members.count - (excludeSelf ? 1 : 0)
        var sum = 0.0
        var needsScaling = false
        for offset in members {
            let member = membership.members[offset]
            if excludeSelf, member == point { continue }
            guard let distance = try ordinaryDistance(point, member) else {
                needsScaling = true
                break
            }
            sum += distance
            if !sum.isFinite {
                needsScaling = true
                break
            }
        }
        let ordinary = sum / Double(count)
        if !needsScaling, ordinary.isNormal || sum == 0 { return .ordinary(ordinary) }
        var largest = SilhouetteMagnitude.zero
        for offset in members {
            let member = membership.members[offset]
            if excludeSelf, member == point { continue }
            largest = max(largest, try scaledDistance(point, member))
        }
        guard largest != .zero else { return .scaled(.zero) }
        var normalizedTotal = 0.0
        for offset in members {
            let member = membership.members[offset]
            if excludeSelf, member == point { continue }
            normalizedTotal += try scaledDistance(point, member).divided(by: largest)
        }
        return .scaled(largest.multiplied(by: normalizedTotal / Double(count)))
    }
}

private func silhouetteUndefined() -> GlifiFailure {
    GlifiFailure(
        code: "clustering.silhouette-undefined",
        category: .insufficientData,
        operation: .analyze,
        retryDisposition: .afterCorrection,
        retainedState: .lastCommittedGeneration,
        messageKey: "failure.clustering.silhouette-undefined"
    )
}
