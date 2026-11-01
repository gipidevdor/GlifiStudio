// SPDX-License-Identifier: BSD-3-Clause

import Accelerate
import Foundation

/// Resource policy shared by the native exploratory operators.
public struct GlifiExploratoryLimits: Equatable, Sendable {
    /// Bounded defaults; quadratic algorithms have their own, lower object limit.
    public static let standard = GlifiExploratoryLimits()
    /// Maximum cells in a dense representation.
    public let maximumCells: Int
    /// Maximum objects in an all-pairs analysis.
    public let maximumPairwiseObjects: Int
    /// Maximum estimated work admitted before an iterative run.
    public let maximumWork: Int
    /// Creates explicit positive resource budgets.
    public init(
        maximumCells: Int = 5_000_000,
        maximumPairwiseObjects: Int = 2_000,
        maximumWork: Int = 500_000_000
    ) {
        self.maximumCells = max(0, maximumCells)
        self.maximumPairwiseObjects = max(0, maximumPairwiseObjects)
        self.maximumWork = max(0, maximumWork)
    }
}

/// Multidimensional scaling variants; their objectives are deliberately distinct.
public enum GlifiMDSMethod: String, Codable, Sendable {
    case classical
    case metric
    case kruskal
    case sammon
}

/// Coordinates and diagnostics of a bounded MDS run.
public struct GlifiMDSResult: Equatable, Sendable {
    /// Versioned algorithm, including the stress definition.
    public let methodIdentifier: String
    /// Coordinates in input order, centered on every axis.
    public let coordinates: [[Double]]
    /// Signed eigenvalues, present for classical MDS.
    public let eigenvalues: [Double]
    /// Raw stress, Stress-1, or Sammon error according to the method.
    public let stress: Double
    /// Initial and accepted objective values.
    public let objectiveHistory: [Double]
    /// Accepted optimization steps.
    public let iterations: Int
    /// Whether the stopping tolerance was reached.
    public let converged: Bool
    /// Recorded initialization seed for iterative variants.
    public let seed: UInt64
}

/// A rectangular, non-toroidal batch self-organizing map.
public struct GlifiSOMResult: Equatable, Sendable {
    /// Versioned algorithm with Gaussian neighborhoods and Euclidean matching.
    public static let identifier = "SOM-batch-gaussian-rectangular-v1"
    /// Grid width.
    public let width: Int
    /// Grid height.
    public let height: Int
    /// Prototype vectors in row-major grid order.
    public let prototypes: [[Double]]
    /// Best matching unit of each input row.
    public let assignments: [Int]
    /// Mean Euclidean distance to the best matching unit.
    public let quantizationError: Double
    /// Fraction of rows whose two nearest units are not grid neighbors.
    public let topographicError: Double
    /// Epochs actually completed.
    public let epochs: Int
    /// Whether prototypes stabilized.
    public let converged: Bool
    /// Recorded random initialization seed.
    public let seed: UInt64
}

/// Sampled PAM clustering with full-data assignment, as in CLARA.
public struct GlifiCLARAResult: Equatable, Sendable {
    /// Versioned sampling and swap procedure.
    public static let identifier = "CLARA-PAM-Euclidean-v1"
    /// Input row indexes of the medoids in canonical order.
    public let medoids: [Int]
    /// Medoid position assigned to every input row.
    public let assignments: [Int]
    /// Sum of Euclidean distances to assigned medoids.
    public let objective: Double
    /// Seed used for sampling without replacement.
    public let seed: UInt64
    /// Number of samples evaluated.
    public let samples: Int
    /// Actual sample size.
    public let sampleSize: Int
}

/// Native bounded implementations of the exploratory families used by KH Coder.
public enum GlifiExploratoryAnalysis {
    /// Computes MDS from an explicit symmetric dissimilarity matrix.
    public static func multidimensionalScaling(
        _ dissimilarities: [[Double]],
        dimensions: Int = 2,
        method: GlifiMDSMethod = .classical,
        seed: UInt64 = 0,
        maximumIterations: Int = 300,
        tolerance: Double = 1e-8,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiMDSResult {
        try validateDissimilarities(dissimilarities, limits: limits)
        let count = dissimilarities.count
        guard dimensions > 0, dimensions < count, (1...10_000).contains(maximumIterations),
            tolerance.isFinite, tolerance > 0
        else { throw exploratoryFailure("exploratory.invalid-parameters") }
        try requireWork(
            [count, count, dimensions, method == .classical ? count : maximumIterations], limits)
        let scale = dissimilarities.flatMap { $0 }.max() ?? 0
        guard scale > 0 else { throw exploratoryFailure("mds.zero-distances", .insufficientData) }
        // All output coordinate distances must remain representable by the native
        // squared-distance kernel, including scale-free objectives.
        guard (scale * scale).isFinite, scale * scale > 0 else {
            throw exploratoryFailure("exploratory.numeric-range")
        }
        let distances = dissimilarities.map { row in row.map { $0 / scale } }
        try requireWork([count, count, count], limits)
        let initial = try classicalMDS(distances, dimensions: dimensions)
        if method == .classical {
            let coordinates = initial.coordinates.map { $0.map { $0 * scale } }
            let stress = rawStress(distances, coordinates: initial.coordinates) * scale * scale
            guard stress.isFinite, coordinates.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            let eigenvalues = initial.values.map { $0 * scale * scale }
            guard eigenvalues.allSatisfy(\.isFinite) else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            return GlifiMDSResult(
                methodIdentifier: "MDS-classical-LAPACK-v1", coordinates: coordinates,
                eigenvalues: eigenvalues, stress: stress,
                objectiveHistory: [stress], iterations: 0, converged: true, seed: seed
            )
        }
        if method == .sammon {
            guard
                distances.indices.allSatisfy({ i in
                    distances.indices.allSatisfy { i == $0 || distances[i][$0] > 0 }
                })
            else { throw exploratoryFailure("mds.sammon-zero-distance") }
        }
        var generator = GlifiSplitMix64(seed: seed)
        var coordinates = initial.coordinates
        // A fixed, tiny perturbation resolves coincident initial coordinates for non-Euclidean data.
        for row in coordinates.indices {
            for axis in 0..<dimensions {
                coordinates[row][axis] +=
                    (Double(generator.next() >> 11) / 9_007_199_254_740_992 - 0.5) * 1e-6
            }
        }
        coordinates = centered(coordinates)
        var history = [try mdsObjective(distances, coordinates, method)]
        var converged = false
        for _ in 0..<maximumIterations {
            try Task.checkCancellation()
            let fitted = pairwiseEuclidean(coordinates)
            let targets = method == .kruskal ? disparities(distances, fitted) : distances
            var proposed = Array(repeating: Array(repeating: 0.0, count: dimensions), count: count)
            if method == .sammon {
                // Gradient with backtracking, using the exact Sammon objective for acceptance.
                let normalizer = upperSum(distances)
                for i in 0..<(count - 1) {
                    for j in (i + 1)..<count {
                        let d = max(fitted[i][j], 1e-15)
                        let factor = 2 * (d - targets[i][j]) / (targets[i][j] * d * normalizer)
                        for axis in 0..<dimensions {
                            let gradient = factor * (coordinates[i][axis] - coordinates[j][axis])
                            proposed[i][axis] -= gradient
                            proposed[j][axis] += gradient
                        }
                    }
                }
                for i in 0..<count {
                    for axis in 0..<dimensions { proposed[i][axis] += coordinates[i][axis] }
                }
            } else {
                // Complete, unit-weight SMACOF: X_next = B(X) X / n.
                for i in 0..<(count - 1) {
                    for j in (i + 1)..<count {
                        let ratio = targets[i][j] / max(fitted[i][j], 1e-15) / Double(count)
                        for axis in 0..<dimensions {
                            let value = ratio * (coordinates[i][axis] - coordinates[j][axis])
                            proposed[i][axis] += value
                            proposed[j][axis] -= value
                        }
                    }
                }
            }
            let previous = history[history.count - 1]
            if method == .kruskal {
                // For f = Stress1², the projected gradient scaled by D/(2n) gives
                // X_next = f*X + B(disparities)*X/n. Raw SMACOF alone minimizes a
                // different objective; the line search always checks Stress-1.
                for i in 0..<count {
                    for axis in 0..<dimensions {
                        proposed[i][axis] += previous * previous * coordinates[i][axis]
                    }
                }
            }
            var accepted: [[Double]]?
            var next = previous
            var step = 1.0
            for _ in 0..<32 {
                let candidate = centered(
                    coordinates.indices.map { i in
                        (0..<dimensions).map {
                            coordinates[i][$0] + step * (proposed[i][$0] - coordinates[i][$0])
                        }
                    })
                let objective = try mdsObjective(distances, candidate, method)
                if objective <= previous {
                    accepted = candidate
                    next = objective
                    break
                }
                step *= 0.5
            }
            guard let accepted else { break }
            coordinates = accepted
            history.append(next)
            if previous - next <= tolerance * max(previous, 1e-15) {
                converged = true
                break
            }
        }
        let multiplier = method == .metric ? scale * scale : 1.0
        let output = coordinates.map { $0.map { $0 * scale } }
        guard multiplier.isFinite, output.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw exploratoryFailure("exploratory.numeric-overflow")
        }
        let objectives = history.map { $0 * multiplier }
        guard objectives.allSatisfy(\.isFinite) else {
            throw exploratoryFailure("exploratory.numeric-overflow")
        }
        return GlifiMDSResult(
            methodIdentifier: method == .metric
                ? "MDS-metric-SMACOF-v1"
                : method == .kruskal ? "MDS-nonmetric-secondary-ties-Stress1-v2" : "MDS-Sammon-v1",
            coordinates: output, eigenvalues: [], stress: objectives.last ?? 0,
            objectiveHistory: objectives, iterations: history.count - 1,
            converged: converged, seed: seed
        )
    }

    /// Fits a batch SOM without updating the data or inventing standardized values.
    public static func selfOrganizingMap(
        _ matrix: [[Double]], width: Int, height: Int, seed: UInt64,
        epochs: Int = 100, initialRadius: Double = 2, finalRadius: Double = 0.5,
        tolerance: Double = 1e-8, limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiSOMResult {
        let columns = try validateExploratoryMatrix(matrix, limits: limits)
        guard width > 0, height > 0, width <= 1_024, height <= 1_024,
            width <= 1_024 / height, (1...10_000).contains(epochs),
            initialRadius.isFinite, finalRadius.isFinite, initialRadius > 0, finalRadius > 0,
            tolerance.isFinite, tolerance > 0,
            (2 * initialRadius * initialRadius).isFinite,
            (2 * finalRadius * finalRadius).isFinite,
            2 * initialRadius * initialRadius > 0, 2 * finalRadius * finalRadius > 0
        else { throw exploratoryFailure("exploratory.invalid-parameters") }
        let units = width * height
        try requireWork([matrix.count, units, columns, epochs], limits)
        guard units <= limits.maximumCells / columns else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        var generator = GlifiSplitMix64(seed: seed)
        var prototypes = (0..<units).map { _ in matrix[generator.index(below: matrix.count)] }
        var completed = 0
        var converged = false
        for epoch in 0..<epochs {
            try Task.checkCancellation()
            let fraction = epochs == 1 ? 1 : Double(epoch) / Double(epochs - 1)
            let radius = initialRadius * pow(finalRadius / initialRadius, fraction)
            let winners = matrix.map { nearest($0, prototypes) }
            // Batch sufficient statistics: sum and population per winning unit.
            // This is algebraically identical to weighting every input row independently.
            var groupSums = Array(repeating: Array(repeating: 0.0, count: columns), count: units)
            var populations = [Int](repeating: 0, count: units)
            for row in matrix.indices {
                if row.isMultiple(of: 256) { try Task.checkCancellation() }
                let winner = winners[row]
                populations[winner] += 1
                nativeAccumulate(matrix[row], scale: 1, into: &groupSums[winner])
            }
            let occupied = populations.indices.filter { populations[$0] > 0 }
            var sums = Array(repeating: Array(repeating: 0.0, count: columns), count: units)
            var weights = Array(repeating: 0.0, count: units)
            for unit in 0..<units {
                for winner in occupied {
                    let dx = Double(unit % width - winner % width)
                    let dy = Double(unit / width - winner / width)
                    let weight = exp(-(dx * dx + dy * dy) / (2 * radius * radius))
                    guard weight > 1e-15 else { continue }
                    weights[unit] += weight * Double(populations[winner])
                    nativeAccumulate(groupSums[winner], scale: weight, into: &sums[unit])
                }
            }
            var change = 0.0
            for unit in 0..<units where weights[unit] > 0 {
                let next = sums[unit].map { $0 / weights[unit] }
                change = max(change, vDSP.distanceSquared(next, prototypes[unit]))
                prototypes[unit] = next
            }
            guard prototypes.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            completed += 1
            // Compare stabilization only after the neighborhood has reached its final radius.
            if epoch == epochs - 1, change <= tolerance * tolerance { converged = true }
        }
        var error = 0.0
        var topographic = 0
        var assignments: [Int] = []
        for row in matrix {
            var winner = 0
            var second = 0
            var firstDistance = Double.infinity
            var secondDistance = Double.infinity
            for unit in prototypes.indices {
                let distance = vDSP.distanceSquared(row, prototypes[unit])
                if distance < firstDistance {
                    second = winner
                    secondDistance = firstDistance
                    winner = unit
                    firstDistance = distance
                } else if distance < secondDistance {
                    second = unit
                    secondDistance = distance
                }
            }
            assignments.append(winner)
            error += vDSP.distanceSquared(row, prototypes[winner]).squareRoot()
            if prototypes.count > 1 {
                if abs(winner % width - second % width) + abs(winner / width - second / width) != 1
                {
                    topographic += 1
                }
            }
        }
        guard error.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
        return GlifiSOMResult(
            width: width, height: height, prototypes: prototypes, assignments: assignments,
            quantizationError: error / Double(matrix.count),
            topographicError: Double(topographic) / Double(matrix.count), epochs: completed,
            converged: converged, seed: seed
        )
    }

    /// Fits CLARA using seeded samples and exhaustive improving PAM swaps inside each sample.
    public static func clara(
        _ matrix: [[Double]], clusterCount: Int, seed: UInt64,
        samples: Int = 5, sampleSize: Int = 100, maximumSwaps: Int = 100,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiCLARAResult {
        let columns = try validateExploratoryMatrix(matrix, limits: limits)
        guard clusterCount > 0, clusterCount <= matrix.count, sampleSize >= clusterCount,
            sampleSize <= 1_000, (1...100).contains(samples), (1...1_000).contains(maximumSwaps)
        else { throw exploratoryFailure("exploratory.invalid-parameters") }
        let size = min(sampleSize, matrix.count)
        try requireWork([size, size, clusterCount, clusterCount, samples, maximumSwaps], limits)
        try requireWork([matrix.count, columns, clusterCount, samples], limits)
        var generator = GlifiSplitMix64(seed: seed)
        var best: (medoids: [Int], assignments: [Int], objective: Double)?
        for _ in 0..<samples {
            try Task.checkCancellation()
            var indexes = Array(matrix.indices)
            for i in 0..<size { indexes.swapAt(i, i + generator.index(below: indexes.count - i)) }
            // Retain the previous best medoids, as in CLARA.
            var sample = Array(indexes.prefix(size))
            if let best {
                sample = best.medoids + sample.filter { !best.medoids.contains($0) }
                sample = Array(sample.prefix(size))
            }
            sample.sort()
            let distances = pairwiseEuclidean(sample.map { matrix[$0] })
            var medoids = Array(0..<clusterCount)
            func cost(_ selected: [Int]) -> Double {
                distances.reduce(0) { sum, row in sum + (selected.map { row[$0] }.min() ?? 0) }
            }
            var objective = cost(medoids)
            for _ in 0..<maximumSwaps {
                try Task.checkCancellation()
                var improvement: [Int]?
                var lowest = objective
                for position in medoids.indices {
                    for candidate in 0..<size where !medoids.contains(candidate) {
                        var swapped = medoids
                        swapped[position] = candidate
                        swapped.sort()
                        let value = cost(swapped)
                        if value < lowest - 1e-12 * max(1, lowest) {
                            lowest = value
                            improvement = swapped
                        }
                    }
                }
                guard let improvement else { break }
                medoids = improvement
                objective = lowest
            }
            let original = medoids.map { sample[$0] }.sorted()
            let centers = original.map { matrix[$0] }
            let assignments = matrix.map { nearest($0, centers) }
            let fullCost = matrix.indices.reduce(0.0) {
                $0 + vDSP.distanceSquared(matrix[$1], centers[assignments[$1]]).squareRoot()
            }
            guard fullCost.isFinite else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            if best == nil || fullCost < (best?.objective ?? .infinity) {
                best = (original, assignments, fullCost)
            }
        }
        guard let best else { throw exploratoryFailure("exploratory.invalid-parameters") }
        return GlifiCLARAResult(
            medoids: best.medoids, assignments: best.assignments, objective: best.objective,
            seed: seed, samples: samples, sampleSize: size
        )
    }
}

package func exploratoryFailure(
    _ code: String, _ category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.category.\(category.rawValue)"
    )
}

package func requireWork(_ factors: [Int], _ limits: GlifiExploratoryLimits) throws {
    var work = 1
    for factor in factors {
        guard factor >= 0, factor == 0 || work <= limits.maximumWork / factor else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        work *= factor
    }
}

package func validateExploratoryMatrix(
    _ matrix: [[Double]], limits: GlifiExploratoryLimits
) throws -> Int {
    guard !matrix.isEmpty, let columns = matrix.first?.count, columns > 0,
        matrix.allSatisfy({ $0.count == columns && $0.allSatisfy(\.isFinite) })
    else { throw exploratoryFailure("exploratory.invalid-matrix") }
    guard matrix.count <= limits.maximumCells / columns else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    try Task.checkCancellation()
    return columns
}

private func validateDissimilarities(
    _ matrix: [[Double]], limits: GlifiExploratoryLimits
) throws {
    _ = try validateExploratoryMatrix(matrix, limits: limits)
    let n = matrix.count
    guard n >= 2, matrix.allSatisfy({ $0.count == n }) else {
        throw exploratoryFailure("mds.invalid-distances")
    }
    guard n <= limits.maximumPairwiseObjects else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    for i in 0..<n {
        guard matrix[i][i] == 0 else { throw exploratoryFailure("mds.invalid-distances") }
        for j in 0..<i {
            guard matrix[i][j] >= 0, matrix[j][i] >= 0, matrix[i][j] == matrix[j][i] else {
                throw exploratoryFailure("mds.invalid-distances")
            }
        }
    }
}

private func nearest(_ row: [Double], _ centers: [[Double]]) -> Int {
    var best = 0
    var distance = Double.infinity
    for i in centers.indices {
        let value = vDSP.distanceSquared(row, centers[i])
        if value < distance {
            best = i
            distance = value
        }
    }
    return best
}

private func pairwiseEuclidean(_ coordinates: [[Double]]) -> [[Double]] {
    var distances = Array(
        repeating: Array(repeating: 0.0, count: coordinates.count), count: coordinates.count)
    for i in coordinates.indices {
        for j in 0..<i {
            let d = vDSP.distanceSquared(coordinates[i], coordinates[j]).squareRoot()
            distances[i][j] = d
            distances[j][i] = d
        }
    }
    return distances
}

private func centered(_ coordinates: [[Double]]) -> [[Double]] {
    let columns = coordinates[0].count
    let means = (0..<columns).map { column in
        coordinates.reduce(0) { $0 + $1[column] } / Double(coordinates.count)
    }
    return coordinates.map { row in row.indices.map { row[$0] - means[$0] } }
}

private func upperSum(_ matrix: [[Double]]) -> Double {
    matrix.indices.reduce(0) { sum, i in sum + matrix[i].prefix(i).reduce(0, +) }
}

private func rawStress(_ targets: [[Double]], coordinates: [[Double]]) -> Double {
    let fitted = pairwiseEuclidean(coordinates)
    return targets.indices.reduce(0) { sum, i in
        sum + (0..<i).reduce(0) { $0 + pow(fitted[i][$1] - targets[i][$1], 2) }
    }
}

package func mdsObjective(
    _ distances: [[Double]], _ coordinates: [[Double]], _ method: GlifiMDSMethod
) throws -> Double {
    let fitted = pairwiseEuclidean(coordinates)
    let targets = method == .kruskal ? disparities(distances, fitted) : distances
    var numerator = 0.0
    var denominator = 0.0
    for i in distances.indices {
        for j in 0..<i {
            let residual = fitted[i][j] - targets[i][j]
            numerator += residual * residual / (method == .sammon ? distances[i][j] : 1)
            denominator += method == .sammon ? distances[i][j] : fitted[i][j] * fitted[i][j]
        }
    }
    let result: Double
    switch method {
    case .classical, .metric: result = numerator
    case .kruskal:
        guard denominator > 0 else {
            throw exploratoryFailure("mds.collapsed-configuration", .insufficientData)
        }
        result = (numerator / denominator).squareRoot()
    case .sammon: result = numerator / denominator
    }
    guard result.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
    return result
}

private func disparities(_ distances: [[Double]], _ fitted: [[Double]]) -> [[Double]] {
    let pairs = distances.indices.flatMap { i in (0..<i).map { (i, $0) } }.sorted {
        let a = distances[$0.0][$0.1]
        let b = distances[$1.0][$1.1]
        return a == b ? ($0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0) : a < b
    }
    var blocks: [(start: Int, end: Int, sum: Double, count: Int)] = []
    for (index, pair) in pairs.enumerated() {
        if let last = blocks.last, index > 0,
            distances[pairs[index - 1].0][pairs[index - 1].1] == distances[pair.0][pair.1]
        {
            blocks[blocks.count - 1] = (
                last.start, index + 1, last.sum + fitted[pair.0][pair.1], last.count + 1
            )
        } else {
            blocks.append((index, index + 1, fitted[pair.0][pair.1], 1))
        }
    }
    var merged: [(start: Int, end: Int, sum: Double, count: Int)] = []
    for block in blocks {
        merged.append(block)
        while merged.count >= 2 {
            let a = merged[merged.count - 2]
            let b = merged[merged.count - 1]
            guard a.sum / Double(a.count) > b.sum / Double(b.count) else { break }
            merged.removeLast(2)
            merged.append((a.start, b.end, a.sum + b.sum, a.count + b.count))
        }
    }
    var result = distances.map { $0.map { _ in 0.0 } }
    for block in merged {
        let value = block.sum / Double(block.count)
        for index in block.start..<block.end {
            let pair = pairs[index]
            result[pair.0][pair.1] = value
            result[pair.1][pair.0] = value
        }
    }
    return result
}

private func classicalMDS(
    _ distances: [[Double]], dimensions: Int
) throws -> (coordinates: [[Double]], values: [Double]) {
    let count = distances.count
    let squared = distances.map { $0.map { $0 * $0 } }
    let means = squared.map { $0.reduce(0, +) / Double(count) }
    let grand = means.reduce(0, +) / Double(count)
    // LAPACK stores a square symmetric matrix column-major and returns eigenvectors in columns.
    var matrix = (0..<count).flatMap { column in
        (0..<count).map { row in -0.5 * (squared[row][column] - means[row] - means[column] + grand)
        }
    }
    var eigenvalues = [Double](repeating: 0, count: count)
    var job: Int8 = 86
    var triangle: Int8 = 85
    var n = __LAPACK_int(count)
    var leadingDimension = n
    var info: __LAPACK_int = 0
    var workspaceSize: __LAPACK_int = -1
    var query = 0.0
    // Every buffer has n*n or n initialized elements; LAPACK receives their validated dimensions.
    dsyev_(
        &job, &triangle, &n, &matrix, &leadingDimension, &eigenvalues, &query, &workspaceSize, &info
    )
    guard info == 0, query.isFinite, query > 0, query <= Double(Int32.max) else {
        throw exploratoryFailure("mds.eigendecomposition-failed", .insufficientData)
    }
    workspaceSize = __LAPACK_int(query)
    var workspace = [Double](repeating: 0, count: Int(workspaceSize))
    dsyev_(
        &job, &triangle, &n, &matrix, &leadingDimension, &eigenvalues, &workspace, &workspaceSize,
        &info)
    guard info == 0 else {
        throw exploratoryFailure("mds.eigendecomposition-failed", .insufficientData)
    }
    try Task.checkCancellation()
    let axes = (0..<count).reversed().filter { eigenvalues[$0] > 1e-12 }
    let selected = Array(axes.prefix(dimensions))
    var coordinates = Array(repeating: Array(repeating: 0.0, count: dimensions), count: count)
    for (axis, column) in selected.enumerated() {
        let first = (0..<count).first { abs(matrix[column * count + $0]) > 1e-12 } ?? 0
        let sign = matrix[column * count + first] < 0 ? -1.0 : 1.0
        let scale = sign * eigenvalues[column].squareRoot()
        for row in 0..<count { coordinates[row][axis] = matrix[column * count + row] * scale }
    }
    return (coordinates, eigenvalues.reversed())
}

private func nativeAccumulate(_ input: [Double], scale: Double, into output: inout [Double]) {
    precondition(input.count == output.count && !input.isEmpty)
    var factor = scale
    // Both buffers have the same initialized length. vDSP_vsmaD explicitly admits C == D.
    output.withUnsafeMutableBufferPointer { buffer in
        guard let address = buffer.baseAddress else {
            preconditionFailure("Missing initialized buffer")
        }
        vDSP_vsmaD(input, 1, &factor, address, 1, address, 1, vDSP_Length(input.count))
    }
}
