// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One immutable I×J contingency table over two categorical dimensions.
public struct GlifiContingencyTable: Equatable, Sendable {
    /// Labels of the row dimension, in stored order.
    public let rowLabels: [String]
    /// Labels of the column dimension, in stored order.
    public let columnLabels: [String]
    /// Row-major non-negative observed counts, one row per `rowLabels` entry.
    public let cells: [[Int]]

    /// Creates a table only after checking shape and non-negative counts.
    public init(
        rowLabels: [String],
        columnLabels: [String],
        cells: [[Int]]
    ) throws {
        guard !rowLabels.isEmpty, !columnLabels.isEmpty else {
            throw contingencyFailure("contingency.empty-dimension", category: .invalidInput)
        }
        guard cells.count == rowLabels.count,
            cells.allSatisfy({ $0.count == columnLabels.count })
        else {
            throw contingencyFailure("contingency.shape-mismatch", category: .invalidInput)
        }
        guard cells.allSatisfy({ row in row.allSatisfy { $0 >= 0 } }) else {
            throw contingencyFailure("contingency.negative-cell", category: .invalidInput)
        }
        self.rowLabels = rowLabels
        self.columnLabels = columnLabels
        self.cells = cells
    }

    /// Sum of each row, in `rowLabels` order.
    public var rowMargins: [Int] { cells.map { $0.reduce(0, +) } }

    /// Sum of each column, in `columnLabels` order.
    public var columnMargins: [Int] {
        guard let columnCount = cells.first?.count else { return [] }
        return (0..<columnCount).map { column in cells.reduce(0) { $0 + $1[column] } }
    }

    /// Grand total of all observed counts.
    public var total: Int { rowMargins.reduce(0, +) }
}

/// `PearsonChiSquareRxC-v1` test with `CramersV-v1` effect size and residuals.
public struct GlifiContingencyAssociation: Equatable, Sendable {
    /// Versioned independence-test identifier.
    public static let chiSquareIdentifier = "PearsonChiSquareRxC-v1"
    /// Versioned non-directional effect-size identifier.
    public static let cramersVIdentifier = "CramersV-v1"

    /// Pearson `χ² = Σ(O-E)²/E` over the included rows and columns.
    public let chiSquareStatistic: Double
    /// `(rows included - 1) × (columns included - 1)`.
    public let degreesOfFreedom: Int
    /// Upper-tail asymptotic chi-square p-value.
    public let pValue: Double
    /// `CramersV-v1` non-directional effect size in `[0, 1]`.
    public let cramersV: Double
    /// Row-major standardized residuals; `nil` for an excluded row/column or a
    /// non-positive standardized denominator.
    public let standardizedResiduals: [[Double?]]
    /// Indices, in `GlifiContingencyTable.rowLabels` order, excluded for a zero margin.
    public let excludedRowIndices: [Int]
    /// Indices, in `GlifiContingencyTable.columnLabels` order, excluded for a zero margin.
    public let excludedColumnIndices: [Int]
}

/// Bounded, deterministic association statistics over one contingency table.
public enum GlifiContingencyAnalysis {
    /// Computes `PearsonChiSquareRxC-v1`, `CramersV-v1`, and standardized residuals.
    public static func associate(
        _ table: GlifiContingencyTable
    ) throws -> GlifiContingencyAssociation {
        let rowMargins = table.rowMargins
        let columnMargins = table.columnMargins
        let total = table.total
        guard total > 0 else {
            throw contingencyFailure("contingency.degenerate-total", category: .insufficientData)
        }
        let excludedRowIndices = rowMargins.indices.filter { rowMargins[$0] == 0 }
        let excludedColumnIndices = columnMargins.indices.filter { columnMargins[$0] == 0 }
        let includedRowIndices = rowMargins.indices.filter { rowMargins[$0] > 0 }
        let includedColumnIndices = columnMargins.indices.filter { columnMargins[$0] > 0 }
        guard includedRowIndices.count >= 2, includedColumnIndices.count >= 2 else {
            throw contingencyFailure(
                "contingency.insufficient-dimensions",
                category: .insufficientData
            )
        }

        var chiSquare = 0.0
        var residuals: [[Double?]] = Array(
            repeating: Array(repeating: nil, count: table.columnLabels.count),
            count: table.rowLabels.count
        )
        for rowIndex in includedRowIndices {
            for columnIndex in includedColumnIndices {
                let observed = Double(table.cells[rowIndex][columnIndex])
                let expected =
                    Double(rowMargins[rowIndex]) * Double(columnMargins[columnIndex])
                    / Double(total)
                guard expected.isFinite, expected > 0 else {
                    throw contingencyFailure(
                        "contingency.invalid-expected-count",
                        category: .invariantViolation
                    )
                }
                let pearsonResidual = (observed - expected) / expected.squareRoot()
                chiSquare += pearsonResidual * pearsonResidual
                let rowShare = Double(rowMargins[rowIndex]) / Double(total)
                let columnShare = Double(columnMargins[columnIndex]) / Double(total)
                let standardizedDenominator = expected * (1 - rowShare) * (1 - columnShare)
                residuals[rowIndex][columnIndex] =
                    standardizedDenominator > 0
                    ? (observed - expected) / standardizedDenominator.squareRoot()
                    : nil
            }
        }
        let degreesOfFreedom = (includedRowIndices.count - 1) * (includedColumnIndices.count - 1)
        guard degreesOfFreedom > 0 else {
            throw contingencyFailure(
                "contingency.degenerate-degrees-of-freedom",
                category: .insufficientData
            )
        }
        let pValue = chiSquareUpperTailProbability(chiSquare, degreesOfFreedom: degreesOfFreedom)
        let minimumDimension = min(includedRowIndices.count, includedColumnIndices.count)
        let cramersV = (chiSquare / (Double(total) * Double(minimumDimension - 1))).squareRoot()
        return GlifiContingencyAssociation(
            chiSquareStatistic: chiSquare,
            degreesOfFreedom: degreesOfFreedom,
            pValue: min(max(pValue, 0), 1),
            cramersV: cramersV,
            standardizedResiduals: residuals,
            excludedRowIndices: excludedRowIndices,
            excludedColumnIndices: excludedColumnIndices
        )
    }
}

/// Upper-tail probability of a chi-square distribution: `P(χ²_df > x)`.
func chiSquareUpperTailProbability(_ chiSquare: Double, degreesOfFreedom: Int) -> Double {
    guard chiSquare.isFinite, chiSquare >= 0, degreesOfFreedom > 0 else { return 1 }
    if chiSquare == 0 { return 1 }
    return regularizedUpperIncompleteGamma(Double(degreesOfFreedom) / 2, chiSquare / 2)
}

/// Regularized upper incomplete gamma function `Q(a, x)`, via the Numerical
/// Recipes series/continued-fraction split (series for `x < a+1`, continued
/// fraction otherwise), each carried to double-precision convergence.
private func regularizedUpperIncompleteGamma(_ a: Double, _ x: Double) -> Double {
    guard a > 0, x >= 0 else { return 1 }
    guard x != 0 else { return 1 }
    if x < a + 1 {
        return 1 - regularizedLowerIncompleteGammaSeries(a, x)
    }
    return regularizedUpperIncompleteGammaContinuedFraction(a, x)
}

private func regularizedLowerIncompleteGammaSeries(_ a: Double, _ x: Double) -> Double {
    var sum = 1.0 / a
    var term = sum
    var n = a
    for _ in 0..<500 {
        n += 1
        term *= x / n
        sum += term
        if abs(term) < abs(sum) * 1e-16 { break }
    }
    return sum * exp(-x + a * log(x) - logGamma(a))
}

private func regularizedUpperIncompleteGammaContinuedFraction(_ a: Double, _ x: Double) -> Double {
    let tiny = 1e-300
    var b = x + 1 - a
    var c = 1 / tiny
    var d = 1 / b
    var h = d
    for i in 1...500 {
        let an = -Double(i) * (Double(i) - a)
        b += 2
        d = an * d + b
        if abs(d) < tiny { d = tiny }
        c = b + an / c
        if abs(c) < tiny { c = tiny }
        d = 1 / d
        let delta = d * c
        h *= delta
        if abs(delta - 1) < 1e-16 { break }
    }
    return exp(-x + a * log(x) - logGamma(a)) * h
}

/// Lanczos approximation (g=7, n=9) of `log Γ(x)`, accurate to double precision.
///
/// Shared across GlifiCore's statistical modules that need `logΓ`.
func logGamma(_ x: Double) -> Double {
    let coefficients: [Double] = [
        0.999_999_999_999_809_9,
        676.520_368_121_885_1,
        -1259.139_216_722_402_8,
        771.323_428_777_653_13,
        -176.615_029_162_140_59,
        12.507_343_278_686_905,
        -0.138_571_095_265_720_12,
        9.984_369_578_019_572e-6,
        1.505_632_735_149_312e-7,
    ]
    if x < 0.5 {
        return log(.pi / sin(.pi * x)) - logGamma(1 - x)
    }
    let xAdjusted = x - 1
    let t = xAdjusted + 7.5
    var accumulator = coefficients[0]
    for index in 1..<coefficients.count {
        accumulator += coefficients[index] / (xAdjusted + Double(index))
    }
    return 0.5 * log(2 * .pi) + (xAdjusted + 0.5) * log(t) - t + log(accumulator)
}

func contingencyFailure(
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
