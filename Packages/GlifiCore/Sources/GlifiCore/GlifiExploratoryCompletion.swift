// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Initialization contract of iterative multidimensional scaling.
public enum GlifiMDSInitialization: String, Codable, Sendable {
    /// Classical coordinates, with the existing deterministic perturbation for older variants.
    case classical
    /// Independent uniform coordinates, centered and generated from the recorded run seed.
    case random
}

/// Ordinal disparity constraints for equal input dissimilarities.
public enum GlifiMDSOrdinalTies: String, Codable, Sendable {
    /// Equal input dissimilarities may receive different disparities, ordered by fitted distance.
    case primary
    /// Equal input dissimilarities receive the same disparity; the compatible default.
    case secondary

    /// Versioned normalized-raw-stress SMACOF contract.
    public var methodIdentifier: String {
        switch self {
        case .primary: "MDS-ordinal-SMACOF-primary-ties-normalized-raw-stress-v1"
        case .secondary: "MDS-ordinal-SMACOF-secondary-ties-normalized-raw-stress-v1"
        }
    }
}

/// A deterministic search retaining the diagnostics of every completed MDS run.
public struct GlifiMDSSearchResult: Equatable, Sendable {
    /// Versioned search and selection contract.
    public static let identifier = "MDS-multistart-SplitMix64-minimum-objective-v1"
    /// Runs in seed order, with run `r` using `seed &+ UInt64(r)`.
    public let runs: [GlifiMDSResult]
    /// Earliest run with the smallest final objective, including non-converged runs.
    public let chosenRun: Int
    /// The selected complete result.
    public var best: GlifiMDSResult { runs[chosenRun] }
}

/// Non-toroidal SOM geometry.
///
/// Hexagons use odd rows shifted half a cell to the right.
public enum GlifiSOMTopology: String, Codable, Sendable {
    case rectangular
    case hexagonal

    /// Versioned Gaussian neighborhood and geometry contract.
    public var methodIdentifier: String {
        switch self {
        case .rectangular: "SOM-batch-gaussian-rectangular-v1"
        case .hexagonal: "SOM-batch-gaussian-hexagonal-odd-row-v1"
        }
    }

    package func squaredDistance(_ first: Int, _ second: Int, width: Int) -> Double {
        let row = first / width
        let otherRow = second / width
        let dx: Double
        let dy: Double
        switch self {
        case .rectangular:
            dx = Double(first % width - second % width)
            dy = Double(row - otherRow)
        case .hexagonal:
            dx =
                Double(first % width - second % width)
                + Double((row % 2) - (otherRow % 2)) * 0.5
            dy = Double(row - otherRow) * (3.0.squareRoot() / 2)
        }
        return dx * dx + dy * dy
    }

    package func areNeighbors(_ first: Int, _ second: Int, width: Int) -> Bool {
        abs(squaredDistance(first, second, width: width) - 1) < 1e-12
    }
}

/// Ward composition over SOM codebooks; assignments retain row-major unit order.
public struct GlifiSOMCodebookClustering: Equatable, Sendable {
    /// Versioned composition contract.
    public static let identifier = "SOM-codebooks-Ward-v1"
    /// Existing Euclidean Ward merge tree.
    public let tree: GlifiHierarchicalClustering
    /// Cluster of each codebook in row-major grid order.
    public let assignments: [Int]
}

extension GlifiExploratoryAnalysis {
    /// Fits ordinal, complete unit-weight SMACOF with explicit primary or secondary ties.
    ///
    /// Secondary ties share a disparity; primary ties may split. PAVA solves the least-squares
    /// projection; disparities are normalized to squared norm `n*(n-1)/2` to prevent
    /// collapse. The reported objective is normalized raw stress, not Kruskal Stress-1.
    /// Each Guttman transform and re-fitted disparity step must decrease that objective.
    /// Coordinates are dimensionless: ordinal dissimilarities specify order, not scale.
    public static func ordinalMultidimensionalScaling(
        _ dissimilarities: [[Double]], dimensions: Int = 2, seed: UInt64 = 0,
        maximumIterations: Int = 300, tolerance: Double = 1e-8,
        limits: GlifiExploratoryLimits = .standard,
        initialization: GlifiMDSInitialization = .classical,
        ties: GlifiMDSOrdinalTies = .secondary
    ) throws -> GlifiMDSResult {
        let count = dissimilarities.count
        _ = try validateExploratoryMatrix(dissimilarities, limits: limits)
        guard count >= 2, dimensions > 0, dimensions < count,
            dissimilarities.allSatisfy({ $0.count == count }),
            (1...10_000).contains(maximumIterations), tolerance.isFinite, tolerance > 0
        else { throw exploratoryFailure("exploratory.invalid-parameters") }
        guard count <= limits.maximumPairwiseObjects else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        try admitIterativeMDSResources(
            count: count, dimensions: dimensions, iterations: maximumIterations,
            starts: 1, method: .ordinal, ordinalTies: ties,
            classicalInitialization: initialization == .classical, limits: limits)
        for row in 0..<count {
            try Task.checkCancellation()
            guard dissimilarities[row][row] == 0 else {
                throw exploratoryFailure("mds.invalid-distances")
            }
            for column in 0..<row {
                guard dissimilarities[row][column] >= 0,
                    dissimilarities[row][column] == dissimilarities[column][row]
                else { throw exploratoryFailure("mds.invalid-distances") }
            }
        }
        guard dissimilarities.contains(where: { $0.contains(where: { $0 > 0 }) }) else {
            throw exploratoryFailure("mds.zero-distances", .insufficientData)
        }
        let pairs = try ordinalPairs(dissimilarities)
        var coordinates: [[Double]]
        switch initialization {
        case .classical:
            // Normalize before the classical initializer so ordinal ranks also admit
            // finite dissimilarities whose squares would overflow or underflow.
            let maximum = dissimilarities.reduce(0.0) { max($0, $1.max() ?? 0) }
            let normalized = dissimilarities.map { $0.map { $0 / maximum } }
            coordinates = try multidimensionalScaling(
                normalized, dimensions: dimensions, method: .classical, limits: limits
            ).coordinates
            // A classical solution may have fewer positive axes than requested.
            // Perturbing avoids an invariant collapsed axis in the Guttman transform.
            var random = GlifiSplitMix64(seed: seed)
            for row in coordinates.indices {
                for column in 0..<dimensions {
                    coordinates[row][column] += unitRandom(&random) * 1e-6
                }
            }
        case .random:
            coordinates = randomMDSCoordinates(count: count, dimensions: dimensions, seed: seed)
        }
        coordinates = try normalizeOrdinalCoordinates(coordinates)
        var fitted = try ordinalDistances(coordinates)
        var targets = try ordinalDisparities(pairs, fitted: fitted, count: count, ties: ties)
        var history = [try ordinalStress(fitted, targets)]
        var converged = false
        for _ in 0..<maximumIterations {
            try Task.checkCancellation()
            var next = Array(repeating: [Double](repeating: 0, count: dimensions), count: count)
            // V+ = J/n for a complete unit-weight graph. A coincident pair has B_ij=0,
            // the standard zero-distance extension of the Guttman transform.
            for row in 1..<count {
                if row.isMultiple(of: 32) { try Task.checkCancellation() }
                for column in 0..<row where fitted[row][column] > 0 {
                    let ratio = targets[row][column] / fitted[row][column] / Double(count)
                    for axis in 0..<dimensions {
                        let value = ratio * (coordinates[row][axis] - coordinates[column][axis])
                        next[row][axis] += value
                        next[column][axis] -= value
                    }
                }
            }
            next = centerOrdinalCoordinates(next)
            let nextFitted = try ordinalDistances(next)
            let nextTargets = try ordinalDisparities(
                pairs, fitted: nextFitted, count: count, ties: ties)
            let objective = try ordinalStress(nextFitted, nextTargets)
            let previous = history[history.count - 1]
            // A tiny floating-point increase terminates at the last valid configuration;
            // it never publishes an increased objective as an accepted majorization step.
            guard objective <= previous else { break }
            coordinates = next
            fitted = nextFitted
            targets = nextTargets
            history.append(objective)
            if previous - objective <= tolerance * max(previous, 1e-15) {
                converged = true
                break
            }
        }
        return GlifiMDSResult(
            methodIdentifier: ties.methodIdentifier,
            coordinates: coordinates, eigenvalues: [], stress: history.last ?? 0,
            objectiveHistory: history, iterations: history.count - 1,
            converged: converged, seed: seed)
    }

    /// Searches actual random configurations with reproducible per-run diagnostics.
    ///
    /// Objectives are compared only within the same method. Ties retain the earliest
    /// run. There is no early stop between starts; cancellation aborts the whole search.
    public static func multidimensionalScalingSearch(
        _ dissimilarities: [[Double]], dimensions: Int = 2,
        method: GlifiMDSMethod = .ordinal, starts: Int = 10, seed: UInt64 = 0,
        maximumIterations: Int = 300, tolerance: Double = 1e-8,
        limits: GlifiExploratoryLimits = .standard,
        ordinalTies: GlifiMDSOrdinalTies = .secondary
    ) throws -> GlifiMDSSearchResult {
        guard method != .classical, (1...1_000).contains(starts), dimensions > 0,
            (1...10_000).contains(maximumIterations),
            method == .ordinal || ordinalTies == .secondary
        else { throw exploratoryFailure("exploratory.invalid-parameters") }
        let count = dissimilarities.count
        guard count >= 2, dimensions < count else {
            throw exploratoryFailure("exploratory.invalid-parameters")
        }
        try admitIterativeMDSResources(
            count: count, dimensions: dimensions, iterations: maximumIterations,
            starts: starts, method: method, ordinalTies: ordinalTies, limits: limits)
        var runs: [GlifiMDSResult] = []
        runs.reserveCapacity(starts)
        var chosen = 0
        for run in 0..<starts {
            try Task.checkCancellation()
            let result: GlifiMDSResult
            if method == .ordinal {
                result = try ordinalMultidimensionalScaling(
                    dissimilarities, dimensions: dimensions, seed: seed &+ UInt64(run),
                    maximumIterations: maximumIterations, tolerance: tolerance, limits: limits,
                    initialization: .random, ties: ordinalTies)
            } else {
                result = try multidimensionalScaling(
                    dissimilarities, dimensions: dimensions, method: method,
                    seed: seed &+ UInt64(run), maximumIterations: maximumIterations,
                    tolerance: tolerance, limits: limits, initialization: .random)
            }
            if !runs.isEmpty, result.stress < runs[chosen].stress {
                chosen = run
            }
            runs.append(result)
        }
        return GlifiMDSSearchResult(runs: runs, chosenRun: chosen)
    }

    /// Median Euclidean distance from each codebook to its immediate grid neighbors.
    ///
    /// A grid containing one unit has value zero; a boundary uses its actual neighbors.
    public static func selfOrganizingMapUMatrix(
        _ map: GlifiSOMResult, limits: GlifiExploratoryLimits = .standard
    ) throws -> [Double] {
        let columns = try validateSOMCodebooks(map, limits: limits)
        try requireWork([map.prototypes.count, 6, columns], limits)
        var result = [Double](repeating: 0, count: map.prototypes.count)
        for unit in map.prototypes.indices {
            if unit.isMultiple(of: 32) { try Task.checkCancellation() }
            let neighbors = somNeighbors(
                unit, width: map.width, height: map.height,
                topology: map.topology)
            let distances = try neighbors.map {
                try finiteEuclidean(map.prototypes[unit], map.prototypes[$0])
            }.sorted()
            if !distances.isEmpty {
                let middle = distances.count / 2
                if distances.count.isMultiple(of: 2) {
                    let first = distances[middle - 1]
                    let second = distances[middle]
                    let sum = first + second
                    result[unit] = sum.isFinite ? sum / 2 : first / 2 + second / 2
                } else {
                    result[unit] = distances[middle]
                }
            }
        }
        return result
    }

    /// Composes the existing Euclidean Ward implementation without another linkage formula.
    public static func clusterSelfOrganizingMapCodebooks(
        _ map: GlifiSOMResult, clusterCount: Int,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiSOMCodebookClustering {
        let columns = try validateSOMCodebooks(map, limits: limits)
        let count = map.prototypes.count
        guard clusterCount > 0, clusterCount <= count else {
            throw exploratoryFailure("exploratory.invalid-parameters")
        }
        try requireWork([count, count, count, columns], limits)
        if count == 1 {
            return GlifiSOMCodebookClustering(
                tree: GlifiHierarchicalClustering(linkage: .ward, merges: []), assignments: [0])
        }
        guard count <= limits.maximumPairwiseObjects, count <= limits.maximumCells / count else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        let tree = try GlifiMultivariateMethods.hierarchicalClustering(
            map.prototypes, linkage: .ward)
        let assignments = try GlifiMultivariateMethods.cut(
            tree, pointCount: count, clusterCount: clusterCount)
        return GlifiSOMCodebookClustering(tree: tree, assignments: assignments)
    }
}

package func randomMDSCoordinates(count: Int, dimensions: Int, seed: UInt64) -> [[Double]] {
    var random = GlifiSplitMix64(seed: seed)
    let values = (0..<count).map { _ in (0..<dimensions).map { _ in unitRandom(&random) } }
    return centerOrdinalCoordinates(values)
}

private func unitRandom(_ random: inout GlifiSplitMix64) -> Double {
    Double(random.next() >> 11) / 9_007_199_254_740_992 - 0.5
}

package struct GlifiOrdinalPair: Equatable {
    let row: Int
    let column: Int
    let dissimilarity: Double
}

private func ordinalPairs(_ dissimilarities: [[Double]]) throws -> [GlifiOrdinalPair] {
    var pairs: [GlifiOrdinalPair] = []
    pairs.reserveCapacity(dissimilarities.count * (dissimilarities.count - 1) / 2)
    for row in dissimilarities.indices {
        if row.isMultiple(of: 32) { try Task.checkCancellation() }
        for column in 0..<row {
            pairs.append(
                GlifiOrdinalPair(
                    row: row, column: column,
                    dissimilarity: dissimilarities[row][column]))
        }
    }
    pairs.sort {
        if $0.dissimilarity != $1.dissimilarity { return $0.dissimilarity < $1.dissimilarity }
        return $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row
    }
    try Task.checkCancellation()
    return pairs
}

/// The isotonic projection with exact tie groups and fixed squared norm.
package func ordinalDisparities(
    _ pairs: [GlifiOrdinalPair], fitted: [[Double]], count: Int,
    ties: GlifiMDSOrdinalTies = .secondary
) throws -> [[Double]] {
    struct Block {
        let start: Int
        var end: Int
        var sum: Double
        var weight: Int
        var mean: Double { sum / Double(weight) }
    }
    let ordered: [GlifiOrdinalPair]
    switch ties {
    case .secondary: ordered = pairs
    case .primary:
        try Task.checkCancellation()
        ordered = pairs.sorted {
            if $0.dissimilarity != $1.dissimilarity { return $0.dissimilarity < $1.dissimilarity }
            let left = fitted[$0.row][$0.column]
            let right = fitted[$1.row][$1.column]
            if left != right { return left < right }
            return $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row
        }
        try Task.checkCancellation()
    }
    var groups: [Block] = []
    for (index, pair) in ordered.enumerated() {
        if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
        let value = fitted[pair.row][pair.column]
        if ties == .secondary, index > 0, pair.dissimilarity == ordered[index - 1].dissimilarity,
            let last = groups.last
        {
            groups[groups.count - 1] = Block(
                start: last.start, end: index + 1, sum: last.sum + value, weight: last.weight + 1)
        } else {
            groups.append(Block(start: index, end: index + 1, sum: value, weight: 1))
        }
    }
    var blocks: [Block] = []
    for group in groups {
        blocks.append(group)
        while blocks.count >= 2 {
            let left = blocks[blocks.count - 2]
            let right = blocks[blocks.count - 1]
            guard left.mean > right.mean else { break }
            blocks.removeLast(2)
            blocks.append(
                Block(
                    start: left.start, end: right.end,
                    sum: left.sum + right.sum, weight: left.weight + right.weight))
        }
    }
    let norm = blocks.reduce(0.0) { $0 + Double($1.weight) * $1.mean * $1.mean }
    guard norm.isFinite, norm > 0 else {
        throw exploratoryFailure("mds.collapsed-configuration", .insufficientData)
    }
    let scale = (Double(pairs.count) / norm).squareRoot()
    var result = Array(repeating: [Double](repeating: 0, count: count), count: count)
    for block in blocks {
        let value = block.mean * scale
        guard value.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
        for index in block.start..<block.end {
            let pair = ordered[index]
            result[pair.row][pair.column] = value
            result[pair.column][pair.row] = value
        }
    }
    return result
}

package func admitIterativeMDSResources(
    count: Int, dimensions: Int, iterations: Int, starts: Int, method: GlifiMDSMethod,
    ordinalTies: GlifiMDSOrdinalTies = .secondary,
    classicalInitialization: Bool = false,
    limits: GlifiExploratoryLimits
) throws {
    guard count >= 2, count <= limits.maximumPairwiseObjects,
        count <= limits.maximumCells / count
    else { throw exploratoryFailure("exploratory.resource-limit", .insufficientResources) }
    let pairCount = count * (count - 1) / 2
    let comparisons = max(1, Int.bitWidth - pairCount.leadingZeroBitCount)
    var work = limits.maximumWork
    // Reserve the initial geometry plus every permitted optimization step, not just
    // accepted steps. The legacy variants can evaluate all 32 backtracking candidates.
    try consumeOrdinalBudget([count, count, dimensions, iterations + 1, starts], remaining: &work)
    switch method {
    case .ordinal:
        try consumeOrdinalBudget([pairCount, comparisons, starts], remaining: &work)
        try consumeOrdinalBudget([pairCount, iterations + 1, starts], remaining: &work)
        if ordinalTies == .primary {
            try consumeOrdinalBudget(
                [pairCount, comparisons, iterations + 1, starts], remaining: &work)
        }
    case .metric, .kruskal, .sammon:
        try consumeOrdinalBudget(
            [32, count, count, dimensions, iterations, starts], remaining: &work)
        if method == .kruskal {
            // One initial objective, one disparity fit before each step and up to
            // 32 candidate objectives: each independently sorts and fits the pairs.
            try consumeOrdinalBudget(
                [pairCount, comparisons, 33 * iterations + 1, starts], remaining: &work)
        }
    case .classical:
        throw exploratoryFailure("exploratory.invalid-parameters")
    }
    if classicalInitialization {
        try consumeOrdinalBudget([count, count, count, starts], remaining: &work)
    }
    var cells = limits.maximumCells
    // Input/working distances, pair records, both PAVA stacks and retained run diagnostics.
    try consumeOrdinalBudget([12, count, count], remaining: &cells)
    try consumeOrdinalBudget([3, count, dimensions], remaining: &cells)
    try consumeOrdinalBudget([starts, count, dimensions], remaining: &cells)
    try consumeOrdinalBudget([starts, iterations + 1], remaining: &cells)
}

private func consumeOrdinalBudget(_ factors: [Int], remaining: inout Int) throws {
    var product = 1
    for factor in factors {
        guard factor >= 0, product == 0 || factor <= remaining / product else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        product *= factor
    }
    remaining -= product
}

private func ordinalDistances(_ coordinates: [[Double]]) throws -> [[Double]] {
    var result = Array(
        repeating: [Double](repeating: 0, count: coordinates.count),
        count: coordinates.count)
    for row in coordinates.indices {
        if row.isMultiple(of: 32) { try Task.checkCancellation() }
        for column in 0..<row {
            let value = try finiteEuclidean(coordinates[row], coordinates[column])
            result[row][column] = value
            result[column][row] = value
        }
    }
    return result
}

private func finiteEuclidean(_ first: [Double], _ second: [Double]) throws -> Double {
    var norm = 0.0
    for column in first.indices { norm = hypot(norm, first[column] - second[column]) }
    guard norm.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
    return norm
}

private func ordinalStress(_ fitted: [[Double]], _ targets: [[Double]]) throws -> Double {
    var stress = 0.0
    for row in fitted.indices {
        for column in 0..<row {
            let residual = fitted[row][column] - targets[row][column]
            stress += residual * residual
        }
    }
    let pairs = fitted.count * (fitted.count - 1) / 2
    let result = stress / Double(pairs)
    guard result.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
    return result
}

private func centerOrdinalCoordinates(_ coordinates: [[Double]]) -> [[Double]] {
    guard let first = coordinates.first else { return coordinates }
    let means = first.indices.map { axis in
        coordinates.reduce(0.0) { $0 + $1[axis] / Double(coordinates.count) }
    }
    return coordinates.map { row in row.indices.map { row[$0] - means[$0] } }
}

private func normalizeOrdinalCoordinates(_ coordinates: [[Double]]) throws -> [[Double]] {
    let centered = centerOrdinalCoordinates(coordinates)
    let distances = try ordinalDistances(centered)
    let squareSum = distances.indices.reduce(0.0) { sum, row in
        sum + (0..<row).reduce(0.0) { $0 + distances[row][$1] * distances[row][$1] }
    }
    guard squareSum.isFinite, squareSum > 0 else {
        throw exploratoryFailure("mds.collapsed-configuration", .insufficientData)
    }
    let count = coordinates.count
    let multiplier = (Double(count * (count - 1) / 2) / squareSum).squareRoot()
    return centered.map { $0.map { $0 * multiplier } }
}

package func somNeighbors(
    _ unit: Int, width: Int, height: Int, topology: GlifiSOMTopology
) -> [Int] {
    let row = unit / width
    let column = unit % width
    var neighbors: [Int] = []
    for adjacentRow in max(0, row - 1)...min(height - 1, row + 1) {
        for adjacentColumn in max(0, column - 1)...min(width - 1, column + 1) {
            let candidate = adjacentRow * width + adjacentColumn
            if topology.areNeighbors(unit, candidate, width: width) { neighbors.append(candidate) }
        }
    }
    return neighbors
}

private func validateSOMCodebooks(
    _ map: GlifiSOMResult, limits: GlifiExploratoryLimits
) throws -> Int {
    let columns = try validateExploratoryMatrix(map.prototypes, limits: limits)
    guard map.width > 0, map.height > 0, map.width <= 1_024, map.height <= 1_024,
        map.width <= 1_024 / map.height, map.width * map.height == map.prototypes.count
    else { throw exploratoryFailure("som.invalid-grid") }
    return columns
}
