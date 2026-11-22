// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// The independent vectors standardized by a matrix preparation.
public enum GlifiKHMatrixAxis: String, Codable, Sendable {
    case rows
    case columns
}

/// Explicit treatment of vectors whose sample standard deviation is zero.
public enum GlifiKHConstantPolicy: String, Codable, Sendable {
    case reject
    case zeros
}

/// A zero exposure may produce zeros only when every corresponding count is zero.
public enum GlifiKHZeroExposurePolicy: String, Codable, Sendable {
    case reject
    case zeros
}

/// Units in KH Coder's public A.6.8 conditional context-vector definition.
public enum GlifiKHContextLevel: String, Codable, Hashable, Sendable {
    case sentence
    case paragraph
    case h5
    case h4
    case h3
    case h2
    case h1
}

/// Counts in caller-declared units, with distinct target and context vocabularies.
public struct GlifiKHContextCounts: Codable, Equatable, Sendable {
    /// The caller-declared aggregation unit.
    public let level: GlifiKHContextLevel
    /// Finite coefficient of this level, initially one in the public KH export.
    public let alpha: Double
    /// Units by target words; a positive count selects a unit exactly once.
    public let targetCounts: [[Double]]
    /// The same units by context words, before conditioning on any target.
    public let contextCounts: [[Double]]

    /// Each pair of rows describes the same unit; alpha defaults to KH's selected-level weight.
    public init(
        level: GlifiKHContextLevel, alpha: Double = 1,
        targetCounts: [[Double]], contextCounts: [[Double]]
    ) {
        self.level = level
        self.alpha = alpha
        self.targetCounts = targetCounts
        self.contextCounts = contextCounts
    }
}

/// A selected context level and its explicitly resolved coefficient.
public struct GlifiKHContextWeight: Codable, Equatable, Sendable {
    /// The aggregation unit of the resolved coefficient.
    public let level: GlifiKHContextLevel
    /// The coefficient used in the weighted sum, including explicit zero or negative values.
    public let alpha: Double
}

/// Conditional context means, preserving both vocabularies and level provenance.
public struct GlifiKHWordContextResult: Codable, Equatable, Sendable {
    /// Versioned identity of the conditional-mean definition.
    public static let identifier = "KH-word-context-conditional-mean-v1"

    /// Unique target identities in output row order.
    public let targetIDs: [String]
    /// Unique context identities in output column order.
    public let contextIDs: [String]
    /// Selected levels and coefficients, in the caller's accumulation order.
    public let levelWeights: [GlifiKHContextWeight]
    /// One row per level, one column per target: units with a positive target count.
    public let supportCounts: [[Int]]
    /// Targets by context words, in the caller's original identity order.
    public let values: [[Double]]
}

/// Exponent of the CA singular values in the requested coordinates.
public enum GlifiKHCorrespondenceScaling: String, Codable, Sendable {
    /// Principal coordinates: D_mass^(-1/2) U Sigma.
    case principal
    /// Standard coordinates: D_mass^(-1/2) U.
    case standard
    /// Symmetric biplot coordinates: D_mass^(-1/2) U Sigma^(1/2).
    case symmetric
}

/// A coordinate projection of an existing CA result, without refitting its axes.
public struct GlifiKHCorrespondenceCoordinates: Codable, Equatable, Sendable {
    /// Versioned identity of the coordinate projection.
    public static let identifier = "CA-coordinate-scaling-v1"

    /// Identity of the existing decomposition whose axes were projected.
    public let sourceMethodIdentifier: String
    /// Scaling applied to row principal coordinates.
    public let rowScaling: GlifiKHCorrespondenceScaling
    /// Scaling applied to column principal coordinates.
    public let columnScaling: GlifiKHCorrespondenceScaling
    /// Original row identities after the decomposition's zero-mass exclusion.
    public let includedRows: [Int]
    /// Original column identities after the decomposition's zero-mass exclusion.
    public let includedColumns: [Int]
    /// Unchanged row probability masses.
    public let rowMasses: [Double]
    /// Unchanged column probability masses.
    public let columnMasses: [Double]
    /// Unchanged positive singular values of the retained axes.
    public let singularValues: [Double]
    /// Scaled coordinates in included-row order.
    public let rowCoordinates: [[Double]]
    /// Scaled coordinates in included-column order.
    public let columnCoordinates: [[Double]]
}

/// Original, bounded implementations of the matrix preparations documented by KH Coder.
public enum GlifiKHMatrixPreparation {
    /// Identity of sample standardization with an explicitly selected axis and constant policy.
    public static let sampleZScoreIdentifier = "KH-sample-z-score-v1"
    /// Identity of normalization by external, complete row exposures.
    public static let exposureIdentifier = "KH-per-thousand-external-exposure-v1"

    /// Uses sample variance (n - 1) along the declared axis.
    ///
    /// A vector needs at least two values.
    /// The constant policy never imputes a missing value or silently substitutes a population SD.
    public static func sampleZScores(
        _ matrix: [[Double]], axis: GlifiKHMatrixAxis,
        constantPolicy: GlifiKHConstantPolicy = .reject,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> [[Double]] {
        var work = limits.maximumWork
        let width = try khMatrixDimensions(matrix, work: &work, limits: limits)
        let length = axis == .rows ? width : matrix.count
        guard length >= 2 else {
            throw exploratoryFailure("kh-matrix.insufficient-sample", .insufficientData)
        }
        var cells = limits.maximumCells
        try khMatrixAdmit([matrix.count, width], remaining: &cells)
        try khMatrixAdmit([3, length], remaining: &cells)
        try khMatrixAdmit([8, matrix.count, width], remaining: &work)
        try khMatrixValidateValues(matrix, nonnegative: false)
        var result = matrix
        switch axis {
        case .rows:
            for row in matrix.indices {
                try Task.checkCancellation()
                result[row] = try khSampleZScores(matrix[row], constantPolicy: constantPolicy)
            }
        case .columns:
            for column in 0..<width {
                try Task.checkCancellation()
                let values = matrix.map { $0[column] }
                let standardized = try khSampleZScores(values, constantPolicy: constantPolicy)
                for row in matrix.indices { result[row][column] = standardized[row] }
            }
        }
        try Task.checkCancellation()
        return result
    }

    /// Divides by complete external row exposures even when the supplied vocabulary is filtered.
    ///
    /// Counts and exposures must be finite and nonnegative. They are not inferred from row sums.
    public static func perThousand(
        _ matrix: [[Double]], exposures: [Double],
        zeroExposurePolicy: GlifiKHZeroExposurePolicy = .reject,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> [[Double]] {
        var work = limits.maximumWork
        let width = try khMatrixDimensions(matrix, work: &work, limits: limits)
        guard exposures.count == matrix.count else {
            throw exploratoryFailure("kh-matrix.invalid-exposure")
        }
        try khMatrixAdmit([4, matrix.count, width], remaining: &work)
        try khMatrixValidateValues(matrix, nonnegative: true)
        var result = matrix
        for row in matrix.indices {
            try Task.checkCancellation()
            let exposure = exposures[row]
            guard exposure.isFinite, exposure >= 0 else {
                throw exploratoryFailure("kh-matrix.invalid-exposure")
            }
            if exposure == 0 {
                guard zeroExposurePolicy == .zeros, matrix[row].allSatisfy({ $0 == 0 }) else {
                    throw exploratoryFailure("kh-matrix.zero-exposure", .insufficientData)
                }
                continue
            }
            for column in 0..<width {
                if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
                result[row][column] = try khMatrixProduct(
                    [matrix[row][column], 1_000], dividedBy: exposure)
            }
        }
        try Task.checkCancellation()
        return result
    }

    /// Computes sum_l alpha_l mean(context_j | target_i > 0), as in KH manual A.6.8.
    ///
    /// Each unit is counted once regardless of the target's frequency. No supported unit means
    /// zero contribution for that target and level, matching the public KH export. Units and
    /// their hierarchy are supplied by the caller; this method never infers sentences or headings.
    public static func wordContext(
        _ levels: [GlifiKHContextCounts], targetIDs: [String], contextIDs: [String],
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHWordContextResult {
        var work = limits.maximumWork
        try khValidateContextInputs(
            levels, targetIDs: targetIDs, contextIDs: contextIDs, work: &work, limits: limits)
        let targets = targetIDs.count
        let contexts = contextIDs.count
        var values = [[Double]](
            repeating: [Double](repeating: 0, count: contexts), count: targets)
        var corrections = values
        var supports = [[Int]](
            repeating: [Int](repeating: 0, count: targets), count: levels.count)
        for (levelIndex, level) in levels.enumerated() {
            for target in 0..<targets {
                try Task.checkCancellation()
                let conditional = try khConditionalMeans(level, target: target, width: contexts)
                supports[levelIndex][target] = conditional.support
                for context in 0..<contexts {
                    if context.isMultiple(of: 1_024) { try Task.checkCancellation() }
                    let value = try khMatrixProduct(
                        [conditional.sums[context], conditional.scales[context], level.alpha],
                        dividedBy: Double(max(1, conditional.support)))
                    khCompensatedAdd(
                        value, sum: &values[target][context],
                        correction: &corrections[target][context])
                    guard values[target][context].isFinite else {
                        throw exploratoryFailure("kh-matrix.numeric-range")
                    }
                }
            }
        }
        try Task.checkCancellation()
        return GlifiKHWordContextResult(
            targetIDs: targetIDs, contextIDs: contextIDs,
            levelWeights: levels.map { GlifiKHContextWeight(level: $0.level, alpha: $0.alpha) },
            supportCounts: supports, values: values)
    }

    /// Re-expresses the existing principal coordinates with independently declared row/column scales.
    public static func correspondenceCoordinates(
        _ result: GlifiCorrespondenceResult,
        rowScaling: GlifiKHCorrespondenceScaling,
        columnScaling: GlifiKHCorrespondenceScaling,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHCorrespondenceCoordinates {
        try khValidateCorrespondence(result, limits: limits)
        let rows = try khScaleCorrespondence(
            result.rowCoordinates, singularValues: result.singularValues, scaling: rowScaling)
        let columns = try khScaleCorrespondence(
            result.columnCoordinates, singularValues: result.singularValues, scaling: columnScaling)
        try Task.checkCancellation()
        return GlifiKHCorrespondenceCoordinates(
            sourceMethodIdentifier: GlifiCorrespondenceResult.identifier,
            rowScaling: rowScaling, columnScaling: columnScaling,
            includedRows: result.includedRows, includedColumns: result.includedColumns,
            rowMasses: result.rowMasses, columnMasses: result.columnMasses,
            singularValues: result.singularValues, rowCoordinates: rows, columnCoordinates: columns)
    }
}

private func khMatrixAdmit(_ factors: [Int], remaining: inout Int) throws {
    var value = 1
    for factor in factors {
        guard factor >= 0, value == 0 || factor <= remaining / value else {
            throw exploratoryFailure("kh-matrix.resource-limit", .insufficientResources)
        }
        value *= factor
    }
    remaining -= value
}

private func khMatrixDimensions(
    _ matrix: [[Double]], work: inout Int, limits: GlifiExploratoryLimits
) throws -> Int {
    try Task.checkCancellation()
    guard let width = matrix.first?.count, width > 0 else {
        throw exploratoryFailure("kh-matrix.invalid-matrix")
    }
    var cells = limits.maximumCells
    try khMatrixAdmit([matrix.count, width], remaining: &cells)
    try khMatrixAdmit([matrix.count, width], remaining: &work)
    for row in matrix {
        try Task.checkCancellation()
        guard row.count == width else { throw exploratoryFailure("kh-matrix.invalid-matrix") }
    }
    return width
}

private func khMatrixValidateValues(_ matrix: [[Double]], nonnegative: Bool) throws {
    for row in matrix {
        try Task.checkCancellation()
        for (index, value) in row.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            guard value.isFinite, !nonnegative || value >= 0 else {
                throw exploratoryFailure("kh-matrix.invalid-value")
            }
        }
    }
}

private func khCompensatedAdd(_ value: Double, sum: inout Double, correction: inout Double) {
    let adjusted = value - correction
    let updated = sum + adjusted
    correction = (updated - sum) - adjusted
    sum = updated
}

private func khSampleZScores(
    _ values: [Double], constantPolicy: GlifiKHConstantPolicy
) throws -> [Double] {
    let reference = values[0]
    var differences = [Double](repeating: 0, count: values.count)
    var scale = 0.0
    var magnitude = 0.0
    var overflow = false
    for index in values.indices {
        if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
        let difference = values[index] - reference
        magnitude = max(magnitude, abs(values[index]))
        overflow = overflow || !difference.isFinite
        differences[index] = difference
        scale = max(scale, abs(difference))
    }
    if overflow {
        scale = 0
        for index in values.indices {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            differences[index] = values[index] / magnitude - reference / magnitude
            scale = max(scale, abs(differences[index]))
        }
    }
    guard scale > 0 else {
        guard constantPolicy == .zeros else {
            throw exploratoryFailure("kh-matrix.constant-vector", .insufficientData)
        }
        return [Double](repeating: 0, count: values.count)
    }
    var sum = 0.0
    var correction = 0.0
    for index in differences.indices {
        if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
        differences[index] /= scale
        khCompensatedAdd(differences[index], sum: &sum, correction: &correction)
    }
    let mean = sum / Double(values.count)
    sum = 0
    correction = 0
    for index in differences.indices {
        if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
        differences[index] -= mean
        khCompensatedAdd(
            differences[index] * differences[index], sum: &sum, correction: &correction)
    }
    let deviation = (sum / Double(values.count - 1)).squareRoot()
    guard deviation.isFinite, deviation > 0 else {
        throw exploratoryFailure("kh-matrix.numeric-range")
    }
    for index in differences.indices {
        if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
        differences[index] /= deviation
    }
    return differences
}

/// Separates exponents before multiplication/division to avoid spurious intermediate range loss.
private func khMatrixProduct(_ factors: [Double], dividedBy denominator: Double) throws -> Double {
    if factors.contains(0) { return 0 }
    var significand = 1.0
    var negative = false
    var exponent = -denominator.exponent
    for factor in factors {
        significand *= factor.significand
        if factor.sign == .minus { negative.toggle() }
        exponent += factor.exponent
    }
    significand /= denominator.significand
    let result = Double(
        sign: negative ? .minus : .plus, exponent: exponent, significand: significand)
    guard result.isFinite, result != 0 else {
        throw exploratoryFailure("kh-matrix.numeric-range")
    }
    return result
}

private func khValidateContextInputs(
    _ levels: [GlifiKHContextCounts], targetIDs: [String], contextIDs: [String],
    work: inout Int, limits: GlifiExploratoryLimits
) throws {
    try Task.checkCancellation()
    guard !levels.isEmpty, levels.count <= 7, !targetIDs.isEmpty, !contextIDs.isEmpty,
        Set(levels.map(\.level)).count == levels.count
    else { throw exploratoryFailure("kh-matrix.invalid-context-levels") }
    let targets = targetIDs.count
    let contexts = contextIDs.count
    var cells = limits.maximumCells
    try khMatrixAdmit([2, targets, contexts], remaining: &cells)
    try khMatrixAdmit([levels.count, targets], remaining: &cells)
    try khMatrixAdmit([3, contexts], remaining: &cells)
    for identifiers in [targetIDs, contextIDs] {
        for identifier in identifiers {
            try Task.checkCancellation()
            guard !identifier.isEmpty else {
                throw exploratoryFailure("kh-matrix.invalid-identities")
            }
            try khMatrixAdmit([identifier.utf8.count], remaining: &work)
        }
        guard Set(identifiers).count == identifiers.count else {
            throw exploratoryFailure("kh-matrix.invalid-identities")
        }
    }
    for level in levels {
        guard level.alpha.isFinite,
            level.targetCounts.count == level.contextCounts.count,
            level.targetCounts.first?.count == targets,
            level.contextCounts.first?.count == contexts
        else { throw exploratoryFailure("kh-matrix.invalid-context-levels") }
        _ = try khMatrixDimensions(level.targetCounts, work: &work, limits: limits)
        _ = try khMatrixDimensions(level.contextCounts, work: &work, limits: limits)
        try khMatrixAdmit([2, level.targetCounts.count, targets, contexts], remaining: &work)
        try khMatrixAdmit([4, targets, contexts], remaining: &work)
    }
    for level in levels {
        try khMatrixValidateValues(level.targetCounts, nonnegative: true)
        try khMatrixValidateValues(level.contextCounts, nonnegative: true)
    }
}

private func khConditionalMeans(
    _ level: GlifiKHContextCounts, target: Int, width: Int
) throws -> (support: Int, sums: [Double], scales: [Double]) {
    var support = 0
    var scales = [Double](repeating: 0, count: width)
    for unit in level.targetCounts.indices {
        if unit.isMultiple(of: 1_024) { try Task.checkCancellation() }
        guard level.targetCounts[unit][target] > 0 else { continue }
        support += 1
        for context in 0..<width {
            if context.isMultiple(of: 1_024) { try Task.checkCancellation() }
            scales[context] = max(scales[context], level.contextCounts[unit][context])
        }
    }
    var sums = [Double](repeating: 0, count: width)
    var corrections = sums
    for unit in level.targetCounts.indices {
        if unit.isMultiple(of: 1_024) { try Task.checkCancellation() }
        guard level.targetCounts[unit][target] > 0 else { continue }
        for context in 0..<width where scales[context] > 0 {
            if context.isMultiple(of: 1_024) { try Task.checkCancellation() }
            khCompensatedAdd(
                level.contextCounts[unit][context] / scales[context],
                sum: &sums[context], correction: &corrections[context])
        }
    }
    return (support, sums, scales)
}

private func khValidateCorrespondence(
    _ result: GlifiCorrespondenceResult, limits: GlifiExploratoryLimits
) throws {
    try Task.checkCancellation()
    let axes = result.singularValues.count
    guard axes > 0, result.rowMasses.count == result.includedRows.count,
        result.columnMasses.count == result.includedColumns.count,
        result.rowCoordinates.count == result.includedRows.count,
        result.columnCoordinates.count == result.includedColumns.count,
        !result.includedRows.isEmpty, !result.includedColumns.isEmpty
    else { throw exploratoryFailure("kh-matrix.invalid-correspondence") }
    var cells = limits.maximumCells
    try khMatrixAdmit([result.includedRows.count, axes], remaining: &cells)
    try khMatrixAdmit([result.includedColumns.count, axes], remaining: &cells)
    var work = limits.maximumWork
    try khMatrixAdmit([3, result.includedRows.count, axes], remaining: &work)
    try khMatrixAdmit([3, result.includedColumns.count, axes], remaining: &work)
    guard result.singularValues.allSatisfy({ $0.isFinite && $0 > 0 }) else {
        throw exploratoryFailure("kh-matrix.invalid-correspondence")
    }
    for (identities, masses, coordinates) in [
        (result.includedRows, result.rowMasses, result.rowCoordinates),
        (result.includedColumns, result.columnMasses, result.columnCoordinates),
    ] {
        guard identities.allSatisfy({ $0 >= 0 }),
            zip(identities, identities.dropFirst()).allSatisfy({ $0 < $1 }),
            masses.allSatisfy({ $0.isFinite && $0 > 0 }),
            abs(masses.reduce(0, +) - 1) <= 1e-10,
            coordinates.allSatisfy({ $0.count == axes })
        else { throw exploratoryFailure("kh-matrix.invalid-correspondence") }
        try khMatrixValidateValues(coordinates, nonnegative: false)
    }
}

private func khScaleCorrespondence(
    _ coordinates: [[Double]], singularValues: [Double], scaling: GlifiKHCorrespondenceScaling
) throws -> [[Double]] {
    var output = coordinates
    for row in coordinates.indices {
        try Task.checkCancellation()
        for axis in singularValues.indices {
            if axis.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let denominator: Double
            switch scaling {
            case .principal: denominator = 1
            case .standard: denominator = singularValues[axis]
            case .symmetric: denominator = singularValues[axis].squareRoot()
            }
            output[row][axis] = try khMatrixProduct(
                [coordinates[row][axis]], dividedBy: denominator)
        }
    }
    return output
}
