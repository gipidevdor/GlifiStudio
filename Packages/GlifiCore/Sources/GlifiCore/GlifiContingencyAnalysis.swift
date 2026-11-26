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
        let pValue = try chiSquareUpperTailProbability(
            chiSquare, degreesOfFreedom: degreesOfFreedom)
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
func chiSquareUpperTailProbability(_ chiSquare: Double, degreesOfFreedom: Int) throws -> Double {
    guard chiSquare.isFinite, chiSquare >= 0, degreesOfFreedom > 0 else {
        throw contingencyFailure("statistics.invalid-distribution-parameters")
    }
    guard chiSquare > 0 else { return 1 }
    return try regularizedUpperIncompleteGamma(Double(degreesOfFreedom) / 2, chiSquare / 2)
}

/// Original evaluation of the mathematical identities DLMF 8.7.1 and 8.9.2.
///
/// The series uses compensated summation; the uncontracted gamma fraction is
/// evaluated from its deepest denominator with doubled truncation depths.
private func regularizedUpperIncompleteGamma(_ shape: Double, _ argument: Double) throws -> Double {
    guard argument > 0 else { return 1 }
    let logarithm: Double
    let isComplement: Bool
    if argument < shape + 1 {
        var term = 1.0
        var sum = 1.0
        var compensation = 0.0
        var converged = false
        for index in 1...16_384 {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            term *= argument / (shape + Double(index))
            let adjusted = term - compensation
            let next = sum + adjusted
            compensation = (next - sum) - adjusted
            sum = next
            if term <= Double.ulpOfOne * sum {
                converged = true
                break
            }
        }
        guard converged else {
            throw contingencyFailure("statistics.non-finite-result")
        }
        logarithm = -argument + shape * log(argument) - logGamma(shape + 1) + log(sum)
        isComplement = true
    } else {
        var previous: Double?
        var convergedFraction: Double?
        var depth = 16
        while depth <= 16_384 {
            try Task.checkCancellation()
            var denominator = 1.0
            for index in stride(from: depth, through: 1, by: -1) {
                let half = Double(index / 2)
                let numerator = index.isMultiple(of: 2) ? half : half + 1 - shape
                denominator = 1 + (numerator / argument) / denominator
                guard denominator.isFinite, denominator != 0 else {
                    throw contingencyFailure("statistics.non-finite-result")
                }
            }
            let fraction = (1 / argument) / denominator
            if let previous, fraction > 0,
                abs(fraction - previous) <= 8 * Double.ulpOfOne * abs(fraction)
            {
                convergedFraction = fraction
                break
            }
            previous = fraction
            depth *= 2
        }
        guard let fraction = convergedFraction else {
            throw contingencyFailure("statistics.non-finite-result")
        }
        logarithm = -argument + shape * log(argument) - logGamma(shape) + log(fraction)
        isComplement = false
    }
    guard logarithm.isFinite else {
        throw contingencyFailure("statistics.non-finite-result")
    }
    // expm1 preserves a small upper tail when the lower probability is near 1.
    let probability = isComplement ? -expm1(logarithm) : exp(logarithm)
    guard probability.isFinite, probability >= -1e-12, probability <= 1 + 1e-12 else {
        throw contingencyFailure("statistics.non-finite-result")
    }
    return min(max(probability, 0), 1)
}

/// The platform's reentrant log-gamma function; no coefficient table is embedded.
///
/// The SDK marks `lgamma` as not thread-safe; `lgamma_r` uses caller-owned sign storage.
func logGamma(_ x: Double) -> Double {
    var sign: Int32 = 0
    return lgamma_r(x, &sign)
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
