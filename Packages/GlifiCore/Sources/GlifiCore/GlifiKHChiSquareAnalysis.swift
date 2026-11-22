// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Continuity-correction policy for a contingency-table independence test.
public enum GlifiKHChiSquareCorrection: String, Codable, Sendable {
    /// Apply Yates to 2×2 tables and Pearson to all other shapes.
    case automatic
    /// Use uncorrected Pearson chi square.
    case none
    /// Require a 2×2 table and apply the nonnegative Yates correction.
    case yates
}

/// An undefined test remains an observation rather than an invented p-value.
public enum GlifiKHChiSquareStatus: String, Codable, Sendable {
    case defined
    case zeroTotal
    case zeroMarginal
    case insufficientDimensions
}

/// KH/R chi square with uncorrected Pearson and standardized residuals kept distinct.
public struct GlifiKHChiSquareResult: Encodable, Equatable, Sendable {
    /// Versioned statistical definition; the resolved correction is returned separately.
    public static let identifier = "KH-chi-square-Yates-Pearson-residuals-v1"
    /// Exact method identity, independent of the caller's automatic policy.
    public var methodIdentifier: String { Self.identifier }
    /// Requested policy, including automatic selection.
    public let requestedCorrection: GlifiKHChiSquareCorrection
    /// Actual correction, never automatic; absent for an undefined test.
    public let appliedCorrection: GlifiKHChiSquareCorrection?
    /// Reason the statistic and p-value are defined or absent.
    public let status: GlifiKHChiSquareStatus
    /// Corrected or uncorrected chi-square statistic, according to the resolved policy.
    public let statistic: Double?
    /// Upper-tail chi-square probability; absent for a degenerate table.
    public let pValue: Double?
    /// Shape-based degrees of freedom, without silently dropping zero margins.
    public let degreesOfFreedom: Int
    /// Row-by-column expected counts; absent cells only when the total is zero.
    public let expected: [[Double?]]
    /// Uncorrected `(O−E)/sqrt(E)`, matching R `chisq.test(...)$residuals`.
    public let pearsonResiduals: [[Double?]]
    /// Uncorrected residuals divided by `sqrt(E*(1−rowShare)*(1−columnShare))`.
    public let standardizedResiduals: [[Double?]]
}

/// One code's presence/complement table over the retained groups.
public struct GlifiKHCodingCodeSignificance: Encodable, Equatable, Sendable {
    /// Code identity in the original rule order.
    public let code: String
    /// Rows are groups; columns are presence and absence, in that order.
    public let counts: [[Int]]
    /// Independence test, including a nonblocking degenerate status.
    public let test: GlifiKHChiSquareResult?
    /// Present only when fewer than two groups preclude constructing a test.
    public let undefinedReason: String?
}

/// Grouped coding counts and one independent significance test per code.
public struct GlifiKHCodingCrosstabResult: Encodable, Equatable, Sendable {
    /// Versioned workflow over the binary coding matrix.
    public static let identifier = "KH-coding-crosstab-chi-square-v1"
    /// Group identities in lexical order, matching the existing crosstab convention.
    public let groups: [String]
    /// Code identities in original rule order.
    public let codes: [String]
    /// Groups by codes, counting presence in each document once.
    public let counts: [[Int]]
    /// Included document exposure for each group.
    public let groupSizes: [Int]
    /// Documents excluded because the supplied group was nil.
    public let excludedDocumentCount: Int
    /// Complete presence/complement observations and significance in code order.
    public let significance: [GlifiKHCodingCodeSignificance]
}

/// Bounded contingency inference using the KH/R correction and residual conventions.
public enum GlifiKHChiSquareAnalysis {
    /// Tests a nonempty, rectangular, nonnegative integer table without deleting zero margins.
    public static func test(
        _ counts: [[Int]], correction: GlifiKHChiSquareCorrection = .automatic,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHChiSquareResult {
        try Task.checkCancellation()
        let shape = try khChiSquareShape(counts)
        let budget = KHChiSquareBudget(limits)
        try budget.cells([4, counts.count, shape])
        try budget.cells([counts.count + shape])
        try khChiSquareAdmitWork(rows: counts.count, columns: shape, budget: budget)
        return try khChiSquareCalculate(counts, correction: correction)
    }
}

/// Significance of code presence between explicit external groups, as in KH A.7.2.
public enum GlifiKHCodingCrosstabAnalysis {
    /// Preserves nil-group exclusion and counts each binary document/code observation once.
    public static func analyze(
        _ matrix: GlifiCodingMatrix, groups: [String?],
        correction: GlifiKHChiSquareCorrection = .automatic,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHCodingCrosstabResult {
        try Task.checkCancellation()
        let rows = matrix.values.count
        let columns = matrix.codes.count
        guard groups.count == rows, matrix.documentIDs.count == rows else {
            throw khChiSquareFailure("kh-crosstab.invalid-shape")
        }
        let budget = KHChiSquareBudget(limits)
        try budget.cells([rows, columns])
        try budget.work([rows, max(columns, 1)])
        var remainingBytes = 64 * 1_024 * 1_024
        var names = Set<String>()
        for code in matrix.codes { try budget.text(code, remaining: &remainingBytes) }
        for row in 0..<rows {
            if row.isMultiple(of: 1_024) { try Task.checkCancellation() }
            guard matrix.values[row].count == columns
            else { throw khChiSquareFailure("kh-crosstab.invalid-binary-matrix") }
            for (index, value) in matrix.values[row].enumerated() {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                guard value == 0 || value == 1 else {
                    throw khChiSquareFailure("kh-crosstab.invalid-binary-matrix")
                }
            }
            try budget.text(matrix.documentIDs[row], remaining: &remainingBytes)
            if let group = groups[row] {
                try budget.text(group, remaining: &remainingBytes)
                names.insert(group)
            }
        }
        let ordered = try names.sorted {
            try budget.work([$0.utf8.count + $1.utf8.count + 1])
            try Task.checkCancellation()
            return $0 < $1
        }
        let groupCount = ordered.count
        // All retained tables/diagnostics are admitted together before creating them.
        try budget.cells([9, groupCount, columns])
        try budget.cells([2, groupCount])
        try budget.cells([4, columns])
        try budget.cells([2])
        try budget.work([rows, max(columns, 1)])
        if groupCount >= 2 {
            try budget.work([columns, 32, groupCount, 2])
            try budget.work([columns, 16, khChiSquareIterationLimit(groupCount - 1)])
        }
        let positions = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })
        var counts = [[Int]](repeating: [Int](repeating: 0, count: columns), count: groupCount)
        var sizes = [Int](repeating: 0, count: groupCount)
        var excluded = 0
        for row in 0..<rows {
            if row.isMultiple(of: 1_024) { try Task.checkCancellation() }
            guard let group = groups[row], let index = positions[group] else {
                excluded += 1
                continue
            }
            sizes[index] += 1
            for code in 0..<columns {
                if code.isMultiple(of: 1_024) { try Task.checkCancellation() }
                counts[index][code] += matrix.values[row][code]
            }
        }
        var significance: [GlifiKHCodingCodeSignificance] = []
        for code in 0..<columns {
            try Task.checkCancellation()
            let table = ordered.indices.map { [counts[$0][code], sizes[$0] - counts[$0][code]] }
            let result =
                groupCount >= 2 ? try khChiSquareCalculate(table, correction: correction) : nil
            significance.append(
                GlifiKHCodingCodeSignificance(
                    code: matrix.codes[code], counts: table, test: result,
                    undefinedReason: groupCount < 2 ? "insufficient-groups" : nil))
        }
        try Task.checkCancellation()
        return GlifiKHCodingCrosstabResult(
            groups: ordered, codes: matrix.codes, counts: counts, groupSizes: sizes,
            excludedDocumentCount: excluded, significance: significance)
    }
}

private func khChiSquareShape(_ counts: [[Int]]) throws -> Int {
    guard let columns = counts.first?.count, columns > 0,
        counts.allSatisfy({ $0.count == columns })
    else { throw khChiSquareFailure("kh-chi-square.invalid-shape") }
    return columns
}

private func khChiSquareAdmitWork(rows: Int, columns: Int, budget: KHChiSquareBudget) throws {
    try budget.work([32, rows, columns])
    let degrees = (rows - 1) * (columns - 1)
    if degrees > 0 { try budget.work([16, khChiSquareIterationLimit(degrees)]) }
}

private func khChiSquareCalculate(
    _ counts: [[Int]], correction: GlifiKHChiSquareCorrection
) throws -> GlifiKHChiSquareResult {
    let rows = counts.count
    let columns = try khChiSquareShape(counts)
    let useYates = rows == 2 && columns == 2 && correction != .none
    guard correction != .yates || (rows == 2 && columns == 2) else {
        throw khChiSquareFailure("kh-chi-square.invalid-correction")
    }
    var rowTotals = [Int](repeating: 0, count: rows)
    var columnTotals = [Int](repeating: 0, count: columns)
    var total = 0
    for row in 0..<rows {
        try Task.checkCancellation()
        for column in 0..<columns {
            if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let value = counts[row][column]
            guard value >= 0 else { throw khChiSquareFailure("kh-chi-square.negative-count") }
            let addition = total.addingReportingOverflow(value)
            guard !addition.overflow else {
                throw khChiSquareFailure("kh-chi-square.count-overflow")
            }
            total = addition.partialValue
            rowTotals[row] += value
            columnTotals[column] += value
        }
    }
    let degrees = (rows - 1) * (columns - 1)
    let status: GlifiKHChiSquareStatus
    if total == 0 {
        status = .zeroTotal
    } else if rows < 2 || columns < 2 {
        status = .insufficientDimensions
    } else if rowTotals.contains(0) || columnTotals.contains(0) {
        status = .zeroMarginal
    } else {
        status = .defined
    }
    var expected = [[Double?]](repeating: [Double?](repeating: nil, count: columns), count: rows)
    var pearson = [[Double?]](repeating: [Double?](repeating: nil, count: columns), count: rows)
    var standardized = [[Double?]](
        repeating: [Double?](repeating: nil, count: columns), count: rows)
    var statistic = 0.0
    var compensation = 0.0
    if total > 0 {
        for row in 0..<rows {
            try Task.checkCancellation()
            for column in 0..<columns {
                if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let rowTotal = rowTotals[row]
                let columnTotal = columnTotals[column]
                let product = UInt128(rowTotal) * UInt128(columnTotal)
                let observed = UInt128(counts[row][column]) * UInt128(total)
                let positive = observed >= product
                let difference = positive ? observed - product : product - observed
                let signed = (positive ? 1.0 : -1.0) * Double(difference) / Double(total)
                let expectation = Double(product) / Double(total)
                expected[row][column] = expectation
                guard expectation > 0 else { continue }
                let residual = signed / expectation.squareRoot()
                pearson[row][column] = residual
                let variance =
                    expectation * (Double(total - rowTotal) / Double(total))
                    * (Double(total - columnTotal) / Double(total))
                if variance > 0 { standardized[row][column] = signed / variance.squareRoot() }
                let magnitude: Double
                if useYates {
                    let twice = difference * 2
                    magnitude =
                        twice > UInt128(total)
                        ? Double(twice - UInt128(total)) / (2 * Double(total)) : 0
                } else {
                    magnitude = abs(signed)
                }
                // Int-bounded counts keep the square representable in binary64.
                // Forming it directly avoids a needless sqrt-and-square rounding.
                let squared = magnitude * magnitude / expectation
                let adjusted = squared - compensation
                let next = statistic + adjusted
                compensation = (next - statistic) - adjusted
                statistic = next
                guard statistic.isFinite, residual.isFinite,
                    standardized[row][column]?.isFinite ?? true
                else { throw khChiSquareFailure("kh-chi-square.numeric-range") }
            }
        }
    }
    let probability =
        status == .defined ? try khChiSquarePValue(statistic, degreesOfFreedom: degrees) : nil
    try Task.checkCancellation()
    return GlifiKHChiSquareResult(
        requestedCorrection: correction,
        appliedCorrection: status == .defined
            ? (useYates ? .yates : GlifiKHChiSquareCorrection.none) : nil,
        status: status, statistic: status == .defined ? statistic : nil, pValue: probability,
        degreesOfFreedom: degrees, expected: expected, pearsonResiduals: pearson,
        standardizedResiduals: standardized)
}

// Kept internal for independent high-df scalar oracles, without changing the legacy CDF.
func khChiSquarePValue(_ statistic: Double, degreesOfFreedom degrees: Int) throws -> Double {
    try Task.checkCancellation()
    guard statistic.isFinite, statistic >= 0, degrees > 0 else {
        throw khChiSquareFailure("kh-chi-square.invalid-distribution")
    }
    if statistic == 0 { return 1 }
    if degrees <= 1_000 {
        let result = chiSquareUpperTailProbability(statistic, degreesOfFreedom: degrees)
        guard result.isFinite, (0...1).contains(result) else {
            throw khChiSquareFailure("kh-chi-square.cdf-numeric-range")
        }
        return result
    }
    let a = Double(degrees) / 2
    let x = statistic / 2
    let relative = (x - a) / a
    let inverse = 1 / a
    let square = inverse * inverse
    let stirling =
        inverse
        * (1.0 / 12 + square
            * (-1.0 / 360 + square
                * (1.0 / 1260
                    + square * (-1.0 / 1680 + square / 1188))))
    let logScale =
        a * khChiSquareLog1pMinusX(relative)
        + 0.5 * log(a / (2 * .pi)) - stirling
    let iterations = khChiSquareIterationLimit(degrees)
    let result: Double
    if x < a + 1 {
        var term = 1 / a
        var sum = term
        var compensation = 0.0
        var converged = false
        for index in 1...iterations {
            if index.isMultiple(of: 128) { try Task.checkCancellation() }
            term *= x / (a + Double(index))
            let adjusted = term - compensation
            let next = sum + adjusted
            compensation = (next - sum) - adjusted
            sum = next
            if term <= sum * 2e-16 {
                converged = true
                break
            }
        }
        guard converged else { throw khChiSquareFailure("kh-chi-square.cdf-convergence") }
        result = 1 - exp(logScale + log(sum))
    } else {
        let tiny = 1e-300
        var b = x + 1 - a
        var c = 1 / tiny
        var d = 1 / b
        var h = d
        var converged = false
        for index in 1...iterations {
            if index.isMultiple(of: 128) { try Task.checkCancellation() }
            let i = Double(index)
            let coefficient = -i * (i - a)
            b += 2
            d = coefficient * d + b
            c = b + coefficient / c
            if abs(d) < tiny { d = d.sign == .minus ? -tiny : tiny }
            if abs(c) < tiny { c = c.sign == .minus ? -tiny : tiny }
            d = 1 / d
            let change = d * c
            h *= change
            if abs(change - 1) <= 2e-16 {
                converged = true
                break
            }
        }
        guard converged, h > 0, h.isFinite else {
            throw khChiSquareFailure("kh-chi-square.cdf-convergence")
        }
        result = exp(logScale + log(h))
    }
    guard result.isFinite, (0...1).contains(result) else {
        throw khChiSquareFailure("kh-chi-square.cdf-numeric-range")
    }
    return result
}

private func khChiSquareLog1pMinusX(_ value: Double) -> Double {
    guard abs(value) < 0.01 else { return log1p(value) - value }
    var power = value * value
    var sum = -power / 2
    for index in 3...20 {
        power *= value
        sum += (index.isMultiple(of: 2) ? -power : power) / Double(index)
    }
    return sum
}

private func khChiSquareIterationLimit(_ degrees: Int) -> Int {
    degrees <= 1_000 ? 500 : Int(min(100_000, ceil(32 * sqrt(Double(degrees) / 2 + 1) + 256)))
}

private final class KHChiSquareBudget {
    private var remainingCells: Int
    private var remainingWork: Int
    init(_ limits: GlifiExploratoryLimits) {
        remainingCells = limits.maximumCells
        remainingWork = limits.maximumWork
    }
    func cells(_ factors: [Int]) throws { try consume(factors, remaining: &remainingCells) }
    func work(_ factors: [Int]) throws { try consume(factors, remaining: &remainingWork) }
    func text(_ text: String, remaining: inout Int) throws {
        let count = text.utf8.count
        guard count <= remaining else { throw khChiSquareLimit() }
        remaining -= count
        try work([count + 1])
    }
    private func consume(_ factors: [Int], remaining: inout Int) throws {
        if factors.contains(0) { return }
        var product = 1
        for factor in factors {
            guard factor == 0 || product <= remaining / factor else { throw khChiSquareLimit() }
            product *= factor
        }
        remaining -= product
    }
}

private func khChiSquareLimit() -> GlifiFailure {
    khChiSquareFailure("kh-chi-square.resource-limit", .insufficientResources)
}

private func khChiSquareFailure(
    _ code: String, _ category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: .unchanged, messageKey: "failure.\(code)")
}
