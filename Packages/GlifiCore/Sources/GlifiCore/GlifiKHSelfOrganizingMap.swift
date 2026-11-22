// SPDX-License-Identifier: BSD-3-Clause

import Accelerate
import Foundation

/// One inverse-time online training phase of the KH-compatible SOM profile.
public struct GlifiKHSOMPhase: Codable, Equatable, Sendable {
    /// Number of individual observations presented, in 1...10,000,000.
    public let steps: Int
    /// Initial inverse-time learning rate in (0,1].
    public let initialLearningRate: Double
    /// Positive finite radius, reduced linearly to one during the phase.
    public let initialRadius: Double

    /// Stores phase parameters; training validates them before allocating codebooks.
    public init(steps: Int, initialLearningRate: Double, initialRadius: Double) {
        self.steps = steps
        self.initialLearningRate = initialLearningRate
        self.initialRadius = initialRadius
    }
}

/// Two continuous online phases, with their initial and intermediate codebooks preserved.
public struct GlifiKHSOMResult: Equatable, Sendable {
    /// Native profile identifier, including sequential online updates and inverse-time decay.
    public let methodIdentifier: String
    /// PCA-linear initialization or explicit caller-supplied codebooks.
    public let initializationIdentifier: String
    /// Non-toroidal grid topology.
    public let topology: GlifiSOMTopology
    /// Number of columns in the row-major grid.
    public let width: Int
    /// Number of rows in the row-major grid.
    public let height: Int
    /// Validated parameters of the first training phase.
    public let firstPhase: GlifiKHSOMPhase
    /// Validated parameters of the second training phase.
    public let secondPhase: GlifiKHSOMPhase
    /// Codebooks before the first update, in original data units.
    public let initialCodebooks: [[Double]]
    /// Same codebooks after phase one; phase two continues these exact internal values.
    public let firstPhaseCodebooks: [[Double]]
    /// Final codebooks, in original data units and row-major grid order.
    public let prototypes: [[Double]]
    /// First minimum-distance unit for each input observation.
    public let assignments: [Int]
    /// Mean Euclidean distance to the winning unit, in original data units.
    public let quantizationError: Double
    /// Mean Gaussian-weighted squared distance to all units, using diagnostic radius one.
    public let neighborhoodDistortion: Double
    /// Fraction whose first two matching units are not immediate grid neighbors.
    public let topographicError: Double
    /// Completed observation updates; the profile always completes both declared schedules.
    public var completedSteps: Int { firstPhase.steps + secondPhase.steps }
}

extension GlifiExploratoryAnalysis {
    /// Initializes a row-major grid along the first two unscaled principal components.
    ///
    /// Each grid axis spans [-2,2] standard deviations. PC1 follows the larger grid
    /// dimension (x on a tie); singleton axes have coordinate zero. Missing/zero PCA
    /// axes contribute zero, including a one-row or constant input. Signs follow the
    /// existing native SVD contract; degenerate eigenspaces need not match R's basis.
    public static func khSelfOrganizingMapPCAInitialization(
        _ matrix: [[Double]], width: Int, height: Int,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> [[Double]] {
        let columns = try validateExploratoryMatrix(matrix, limits: limits)
        let units = try khSOMGrid(width: width, height: height)
        try khSOMAdmission(
            rows: matrix.count, columns: columns, units: units, phases: [],
            pca: true, limits: limits)
        let normalized = try khSOMNormalized(matrix)
        let initial = try khSOMPCA(normalized.values, width: width, height: height, limits: limits)
        return try khSOMRestore(initial, scale: normalized.scale)
    }

    /// Fits the two-phase KH/R-som online profile without reinitializing between phases.
    ///
    /// Omitted schedules use 2*n and 10*n steps, learning rates 0.05/0.02 and initial
    /// radii min(width,height)/min(3,width,height). At step t=1...L, alpha is
    /// alpha0*C/(C+t), C=L/100, and radius is 1+(r0-1)*(L-t)/L. Each phase starts
    /// at observation zero and cycles the declared row order; there is no random stream.
    /// Gaussian neighborhoods and first-unit BMU ties follow the declared topology.
    /// Input is already prepared numerical data: no implicit z-scores or text weighting.
    /// The native scalar-update implementation is original; R RNG or degenerate PCA
    /// basis identity is not promised. Nonrepresentable restored diagnostics fail closed.
    public static func khSelfOrganizingMap(
        _ matrix: [[Double]], width: Int, height: Int,
        firstPhase: GlifiKHSOMPhase? = nil, secondPhase: GlifiKHSOMPhase? = nil,
        topology: GlifiSOMTopology = .hexagonal, initialCodebooks: [[Double]]? = nil,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHSOMResult {
        let columns = try validateExploratoryMatrix(matrix, limits: limits)
        let units = try khSOMGrid(width: width, height: height)
        if let initialCodebooks {
            guard initialCodebooks.count == units else {
                throw exploratoryFailure("som.invalid-codebooks")
            }
        }
        let first = try khSOMPhase(
            firstPhase, rows: matrix.count, multiplier: 2, alpha: 0.05,
            radius: Double(min(width, height)))
        let second = try khSOMPhase(
            secondPhase, rows: matrix.count, multiplier: 10, alpha: 0.02,
            radius: Double(min(3, min(width, height))))
        try khSOMAdmission(
            rows: matrix.count, columns: columns, units: units, phases: [first, second],
            pca: initialCodebooks == nil, limits: limits)
        if let initialCodebooks {
            for row in initialCodebooks {
                try Task.checkCancellation()
                guard row.count == columns, row.allSatisfy(\.isFinite) else {
                    throw exploratoryFailure("som.invalid-codebooks")
                }
            }
        }
        let normalized = try khSOMNormalized(matrix, codebooks: initialCodebooks)
        var codebooks =
            try normalized.codebooks
            ?? khSOMPCA(normalized.values, width: width, height: height, limits: limits)
        let initial = try initialCodebooks ?? khSOMRestore(codebooks, scale: normalized.scale)
        try khSOMTrain(
            normalized.values, codebooks: &codebooks, phase: first,
            width: width, topology: topology)
        let intermediate = try khSOMRestore(codebooks, scale: normalized.scale)
        try khSOMTrain(
            normalized.values, codebooks: &codebooks, phase: second,
            width: width, topology: topology)
        let diagnostics = try khSOMDiagnostics(
            normalized.values, codebooks: codebooks, width: width,
            topology: topology, scale: normalized.scale)
        let output = try khSOMRestore(codebooks, scale: normalized.scale)
        try Task.checkCancellation()
        return GlifiKHSOMResult(
            methodIdentifier: topology == .hexagonal
                ? "SOM-KH-online-inverse-two-phase-hexagonal-v1"
                : "SOM-KH-online-inverse-two-phase-rectangular-v1",
            initializationIdentifier: initialCodebooks == nil
                ? "SOM-PCA-linear-unscaled-canonical-v1" : "SOM-explicit-codebooks-v1",
            topology: topology, width: width, height: height, firstPhase: first,
            secondPhase: second,
            initialCodebooks: initial, firstPhaseCodebooks: intermediate, prototypes: output,
            assignments: diagnostics.assignments, quantizationError: diagnostics.error,
            neighborhoodDistortion: diagnostics.distortion,
            topographicError: diagnostics.topographic)
    }
}

private func khSOMGrid(width: Int, height: Int) throws -> Int {
    guard width > 0, height > 0, width <= 1_024, height <= 1_024, width <= 1_024 / height else {
        throw exploratoryFailure("som.invalid-grid")
    }
    return width * height
}

private func khSOMPhase(
    _ phase: GlifiKHSOMPhase?, rows: Int, multiplier: Int, alpha: Double, radius: Double
) throws -> GlifiKHSOMPhase {
    let result: GlifiKHSOMPhase
    if let phase {
        result = phase
    } else {
        let (steps, overflow) = rows.multipliedReportingOverflow(by: multiplier)
        guard !overflow else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        result = .init(steps: steps, initialLearningRate: alpha, initialRadius: radius)
    }
    guard (1...10_000_000).contains(result.steps), result.initialLearningRate.isFinite,
        result.initialLearningRate > 0, result.initialLearningRate <= 1,
        result.initialRadius.isFinite, result.initialRadius > 0,
        result.initialLearningRate * (Double(result.steps) / 100)
            / (Double(result.steps) / 100 + Double(result.steps)) > 0
    else { throw exploratoryFailure("som.invalid-phase") }
    return result
}

private func khSOMConsume(_ factors: [Int], budget: inout Int) throws {
    var product = 1
    for factor in factors {
        guard factor >= 0, product == 0 || factor <= budget / product else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        product *= factor
    }
    budget -= product
}

private func khSOMAdmission(
    rows: Int, columns: Int, units: Int, phases: [GlifiKHSOMPhase],
    pca: Bool, limits: GlifiExploratoryLimits
) throws {
    var cells = limits.maximumCells
    try khSOMConsume([3, rows, columns], budget: &cells)
    try khSOMConsume([4, units, columns], budget: &cells)
    var work = limits.maximumWork
    try khSOMConsume([rows, columns], budget: &work)
    if pca {
        let rank = min(rows, columns)
        guard rows <= GlifiLinearAlgebra.maximumCellCount / columns else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        try khSOMConsume([4, rows, columns], budget: &cells)
        try khSOMConsume([4, rank, rank], budget: &cells)
        try khSOMConsume([100, max(rows, columns), rank, rank], budget: &work)
    }
    for phase in phases {
        // One BMU scan and one online update across all codebook features per step.
        try khSOMConsume([2, phase.steps, units, columns], budget: &work)
    }
    try khSOMConsume([2, rows, units, columns], budget: &work)
    try Task.checkCancellation()
}

private func khSOMNormalized(_ matrix: [[Double]], codebooks: [[Double]]? = nil) throws
    -> (values: [[Double]], codebooks: [[Double]]?, scale: Double)
{
    var maximum = 0.0
    for rows in [matrix, codebooks ?? []] {
        for (index, row) in rows.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            for value in row { maximum = max(maximum, abs(value)) }
        }
    }
    let scale = maximum == 0 ? 1 : Double(sign: .plus, exponent: maximum.exponent, significand: 1)
    func normalized(_ rows: [[Double]]) throws -> [[Double]] {
        try rows.enumerated().map { index, row in
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            return try row.map { value in
                let scaled = value / scale
                guard scaled.isFinite, value == 0 || scaled.isNormal,
                    scaled * scale == value
                else { throw exploratoryFailure("exploratory.numeric-range") }
                return scaled
            }
        }
    }
    return (try normalized(matrix), try codebooks.map(normalized), scale)
}

private func khSOMPCA(
    _ data: [[Double]], width: Int, height: Int, limits: GlifiExploratoryLimits
) throws -> [[Double]] {
    let columns = data[0].count
    let means = (0..<columns).map { axis in
        let reference = data[0][axis]
        return reference + data.reduce(0.0) { $0 + ($1[axis] - reference) / Double(data.count) }
    }
    if data.count == 1 || width * height == 1 {
        return Array(repeating: means, count: width * height)
    }
    let centered = data.map { row in row.indices.map { row[$0] - means[$0] } }
    let svd = try khSOMPrincipalAxes(centered, units: width * height, limits: limits)
    try Task.checkCancellation()
    func offset(_ axis: Int, _ column: Int) -> Double {
        guard axis < svd.values.count else { return 0 }
        return svd.vectors[column][axis] * (svd.values[axis] / sqrt(Double(data.count - 1)))
    }
    return (0..<(width * height)).map { unit in
        let x = width == 1 ? 0 : 4 * Double(unit % width) / Double(width - 1) - 2
        let y = height == 1 ? 0 : 4 * Double(unit / width) / Double(height - 1) - 2
        return (0..<columns).map { column in
            means[column] + x * offset(width >= height ? 0 : 1, column)
                + y * offset(width >= height ? 1 : 0, column)
        }
    }
}

/// LAPACK avoids squaring tiny but representable singular values during PCA.
///
/// Only thin right vectors are computed (no U); the returned representation retains
/// two axes. The standard dgesvd API computes all min(m,n) thin right vectors.
private func khSOMPrincipalAxes(
    _ input: [[Double]], units: Int, limits: GlifiExploratoryLimits
) throws -> (values: [Double], vectors: [[Double]]) {
    try Task.checkCancellation()
    let rows = input.count
    let columns = input[0].count
    let rank = min(rows, columns)
    guard rows <= Int(__LAPACK_int.max), columns <= Int(__LAPACK_int.max) else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    var remaining = limits.maximumCells
    // Same cumulative live-buffer admission as the caller, plus the queried workspace.
    try khSOMConsume([7, rows, columns], budget: &remaining)
    try khSOMConsume([4, rank, rank], budget: &remaining)
    try khSOMConsume([4, units, columns], budget: &remaining)
    var matrix = (0..<columns).flatMap { column in input.map { $0[column] } }
    var values = [Double](repeating: 0, count: rank)
    var right = [Double](repeating: 0, count: rank * columns)
    var dummyU = [0.0]
    var jobU: Int8 = 78  // N: no left singular vectors.
    var jobV: Int8 = 83  // S: thin right singular vectors, stored transposed.
    var m = __LAPACK_int(rows)
    var n = __LAPACK_int(columns)
    var leading = m
    var leadingU: __LAPACK_int = 1
    var leadingV = __LAPACK_int(rank)
    var info: __LAPACK_int = 0
    var size: __LAPACK_int = -1
    var query = 0.0
    // Dimensions were admitted before allocation. A has m*n initialized entries,
    // VT has min(m,n)*n, S has min(m,n), and U is unused with jobU=N.
    dgesvd_(
        &jobU, &jobV, &m, &n, &matrix, &leading, &values, &dummyU, &leadingU,
        &right, &leadingV, &query, &size, &info)
    guard info == 0, query.isFinite, query >= 1,
        query <= Double(__LAPACK_int.max), query <= Double(remaining)
    else { throw exploratoryFailure("som.pca-workspace", .insufficientResources) }
    let workspaceCells = Int(query.rounded(.up))
    try khSOMConsume([workspaceCells], budget: &remaining)
    size = __LAPACK_int(workspaceCells)
    var workspace = [Double](repeating: 0, count: workspaceCells)
    try Task.checkCancellation()
    dgesvd_(
        &jobU, &jobV, &m, &n, &matrix, &leading, &values, &dummyU, &leadingU,
        &right, &leadingV, &workspace, &size, &info)
    try Task.checkCancellation()
    guard info == 0, values.allSatisfy({ $0.isFinite && $0 >= 0 }), right.allSatisfy(\.isFinite)
    else {
        throw exploratoryFailure("som.pca-decomposition-failed")
    }
    let axes = min(2, rank)
    var vectors = (0..<columns).map { column in (0..<axes).map { right[$0 + rank * column] } }
    for axis in 0..<axes {
        if let pivot = vectors.firstIndex(where: { abs($0[axis]) > 1e-12 }),
            vectors[pivot][axis] < 0
        {
            for column in 0..<columns { vectors[column][axis] = -vectors[column][axis] }
        }
    }
    return (Array(values.prefix(axes)), vectors)
}

private func khSOMDistance(_ first: [Double], _ second: [Double]) -> Double {
    var result = 0.0
    for axis in first.indices { result = hypot(result, first[axis] - second[axis]) }
    return result
}

private func khSOMTrain(
    _ data: [[Double]], codebooks: inout [[Double]], phase: GlifiKHSOMPhase,
    width: Int, topology: GlifiSOMTopology
) throws {
    let c = Double(phase.steps) / 100
    for step in 1...phase.steps {
        try Task.checkCancellation()
        let row = data[(step - 1) % data.count]
        var winner = 0
        var nearest = khSOMDistance(row, codebooks[0])
        for unit in codebooks.indices.dropFirst() {
            if unit.isMultiple(of: 32) { try Task.checkCancellation() }
            let distance = khSOMDistance(row, codebooks[unit])
            if distance < nearest {
                nearest = distance
                winner = unit
            }
        }
        let alpha = phase.initialLearningRate * c / (c + Double(step))
        let radius =
            1 + (phase.initialRadius - 1) * (Double(phase.steps - step) / Double(phase.steps))
        for unit in codebooks.indices {
            if unit.isMultiple(of: 32) { try Task.checkCancellation() }
            let grid = sqrt(topology.squaredDistance(unit, winner, width: width)) / radius
            let weight = alpha * exp(-0.5 * grid * grid)
            for axis in row.indices {
                codebooks[unit][axis] += weight * (row[axis] - codebooks[unit][axis])
            }
        }
    }
}

private func khSOMRestore(_ codebooks: [[Double]], scale: Double) throws -> [[Double]] {
    try codebooks.map { row in
        try row.map { value in
            let restored = value * scale
            guard restored.isFinite, value == 0 || restored != 0 else {
                throw exploratoryFailure("exploratory.numeric-range")
            }
            return restored
        }
    }
}

private func khSOMDiagnostics(
    _ data: [[Double]], codebooks: [[Double]], width: Int,
    topology: GlifiSOMTopology, scale: Double
) throws -> (assignments: [Int], error: Double, distortion: Double, topographic: Double) {
    var assignments: [Int] = []
    var error = KHSOMPositiveSum()
    var distortion = KHSOMPositiveSum()
    var topographic = 0
    var distances = [Double](repeating: 0, count: codebooks.count)
    for (index, row) in data.enumerated() {
        if index.isMultiple(of: 32) { try Task.checkCancellation() }
        var winner = 0
        var second: Int?
        for unit in codebooks.indices {
            distances[unit] = khSOMDistance(row, codebooks[unit])
            if unit > 0 {
                if distances[unit] < distances[winner] {
                    second = winner
                    winner = unit
                } else if second.map({ distances[unit] < distances[$0] }) ?? true {
                    second = unit
                }
            }
        }
        assignments.append(winner)
        error.add(distances[winner], squared: false)
        if let second, !topology.areNeighbors(winner, second, width: width) { topographic += 1 }
        for unit in codebooks.indices {
            let weight = exp(-0.5 * topology.squaredDistance(unit, winner, width: width))
            distortion.add(distances[unit], weight: weight, squared: true)
        }
    }
    let restoredError = try error.mean(rows: data.count, scale: scale, squared: false)
    let restoredDistortion = try distortion.mean(rows: data.count, scale: scale, squared: true)
    return (
        assignments, restoredError, restoredDistortion, Double(topographic) / Double(data.count)
    )
}

/// Accumulates positive diagnostics before restoring their physical scale.
private struct KHSOMPositiveSum {
    var scale = 0.0
    var sum = 0.0

    mutating func add(_ value: Double, weight: Double = 1, squared: Bool) {
        guard value > 0, weight > 0 else { return }
        if value > scale {
            let ratio = scale / value
            sum *= squared ? ratio * ratio : ratio
            scale = value
        }
        let ratio = value / scale
        sum += weight * (squared ? ratio * ratio : ratio)
    }

    func mean(rows: Int, scale originalScale: Double, squared: Bool) throws -> Double {
        if scale == 0 { return 0 }
        let physical = scale * originalScale
        var value = sum / Double(rows) * physical
        if squared { value *= physical }
        guard physical.isFinite, physical > 0, value.isFinite, value > 0 else {
            throw exploratoryFailure("exploratory.numeric-range")
        }
        return value
    }
}
