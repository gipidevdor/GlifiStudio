// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Ordinal SMACOF matches analytical equilateral and one-dimensional optima")
func completionOrdinalAnalyticalOracle() throws {
    let distances: [[Double]] = [[0, 1, 1], [1, 0, 1], [1, 1, 0]]
    let planar = try GlifiExploratoryAnalysis.multidimensionalScaling(
        distances, method: .ordinal, seed: 17, maximumIterations: 1_000)
    #expect(planar.methodIdentifier.contains("ordinal-SMACOF"))
    #expect(planar.stress < 1e-12)
    for row in 1..<3 {
        for column in 0..<row {
            #expect(
                abs(completionDistance(planar.coordinates[row], planar.coordinates[column]) - 1)
                    < 1e-5)
        }
    }
    let line = try GlifiExploratoryAnalysis.multidimensionalScaling(
        distances, dimensions: 1, method: .ordinal, seed: 17,
        maximumIterations: 1_000, initialization: .random)
    // The minimizing gaps are 2/3, 2/3, 4/3: raw stress / 3 = 1/9.
    #expect(abs(line.stress - 1.0 / 9) < 1e-10)
}

@Test("Ordinal PAVA matches exhaustive monotone partitions including weighted ties")
func completionOrdinalPAVAOracle() throws {
    // Six pair distances of four points, deliberately out of dissimilarity order.
    let coordinates = [[0.0], [1], [3], [7]]
    let fitted = coordinates.map { first in coordinates.map { completionDistance(first, $0) } }
    for levels in [[1.0, 2, 3, 4, 5, 6], [1, 1, 2, 2, 3, 3], [1, 1, 1, 1, 1, 1]] {
        let indices = [(1, 0), (2, 0), (2, 1), (3, 0), (3, 1), (3, 2)]
        let pairs = zip(indices, levels).map {
            GlifiOrdinalPair(row: $0.0.0, column: $0.0.1, dissimilarity: $0.1)
        }
        let observed = try ordinalDisparities(pairs, fitted: fitted, count: 4)
        let expected = completionEnumeratedIsotonic(
            indices.map { fitted[$0.0][$0.1] }, levels: levels)
        for (index, pair) in indices.enumerated() {
            #expect(abs(observed[pair.0][pair.1] - expected[index]) < 1e-12)
        }
        let norm = indices.reduce(0.0) { $0 + pow(observed[$1.0][$1.1], 2) }
        #expect(abs(norm - 6) < 1e-12)
    }
}

@Test("Ordinal SMACOF first step matches an independently assembled Guttman transform")
func completionOrdinalMajorizationOracle() throws {
    let dissimilarities: [[Double]] = [[0, 1, 2, 4], [1, 0, 3, 5], [2, 3, 0, 6], [4, 5, 6, 0]]
    let pairs = [(1, 0), (2, 0), (2, 1), (3, 0), (3, 1), (3, 2)]
    var random = GlifiSplitMix64(seed: 11)
    var initial = (0..<4).map { _ in
        (0..<2).map { _ in Double(random.next() >> 11) / 9_007_199_254_740_992 - 0.5 }
    }
    for axis in 0..<2 {
        let mean = initial.reduce(0.0) { $0 + $1[axis] / 4 }
        for row in 0..<4 { initial[row][axis] -= mean }
    }
    let norm = pairs.reduce(0.0) { $0 + pow(completionDistance(initial[$1.0], initial[$1.1]), 2) }
    initial = initial.map { $0.map { $0 * (6 / norm).squareRoot() } }
    let fitted = pairs.map { completionDistance(initial[$0.0], initial[$0.1]) }
    let targets = completionEnumeratedIsotonic(fitted, levels: [1, 2, 3, 4, 5, 6])
    var next = [[Double]](repeating: [0, 0], count: 4)
    for (index, pair) in pairs.enumerated() {
        for axis in 0..<2 {
            let value =
                targets[index] / fitted[index] / 4
                * (initial[pair.0][axis] - initial[pair.1][axis])
            next[pair.0][axis] += value
            next[pair.1][axis] -= value
        }
    }
    for axis in 0..<2 {
        let mean = next.reduce(0.0) { $0 + $1[axis] / 4 }
        for row in 0..<4 { next[row][axis] -= mean }
    }
    let native = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
        dissimilarities, seed: 11, maximumIterations: 1, initialization: .random)
    #expect(native.iterations == 1)
    for (actual, expected) in zip(native.coordinates.flatMap { $0 }, next.flatMap { $0 }) {
        #expect(abs(actual - expected) < 1e-12)
    }
    let finalDistances = pairs.map { completionDistance(next[$0.0], next[$0.1]) }
    let finalTargets = completionEnumeratedIsotonic(finalDistances, levels: [1, 2, 3, 4, 5, 6])
    let objective = zip(finalDistances, finalTargets).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) } / 6
    #expect(abs(native.stress - objective) < 1e-12)
}

@Test("Ordinal MDS preserves ranks, ties, centered coordinates and monotonic objective")
func completionOrdinalProperties() throws {
    let distances: [[Double]] = [
        [0, 1, 1, 4, 5], [1, 0, 2, 3, 4], [1, 2, 0, 2, 3],
        [4, 3, 2, 0, 1], [5, 4, 3, 1, 0],
    ]
    let transformed = distances.map { $0.map { $0 * $0 * $0 } }
    for seed in 0..<8 {
        let original = try GlifiExploratoryAnalysis.multidimensionalScaling(
            distances, method: .ordinal, seed: UInt64(seed), initialization: .random)
        let changed = try GlifiExploratoryAnalysis.multidimensionalScaling(
            transformed, method: .ordinal, seed: UInt64(seed), initialization: .random)
        #expect(original == changed)
        #expect(original.objectiveHistory.allSatisfy { $0.isFinite && $0 >= 0 })
        #expect(
            zip(original.objectiveHistory, original.objectiveHistory.dropFirst()).allSatisfy {
                $1 <= $0
            })
        for axis in 0..<2 {
            #expect(abs(original.coordinates.reduce(0) { $0 + $1[axis] }) < 1e-12)
        }
    }
    let tiny = distances.map { $0.map { $0 * 1e-200 } }
    let huge = distances.map { $0.map { $0 * 1e200 } }
    for matrix in [tiny, huge] {
        let result = try GlifiExploratoryAnalysis.multidimensionalScaling(matrix, method: .ordinal)
        #expect(result.coordinates.allSatisfy { $0.allSatisfy(\.isFinite) })
    }
}

@Test("MDS multistart records actual independent runs and selects minimum objective")
func completionMDSMultistart() throws {
    let distances: [[Double]] = [[0, 1, 3, 2], [1, 0, 2, 4], [3, 2, 0, 1], [2, 4, 1, 0]]
    for method in [GlifiMDSMethod.ordinal, .metric, .kruskal, .sammon] {
        let search = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            distances, method: method, starts: 4, seed: UInt64.max - 1, maximumIterations: 50)
        let again = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            distances, method: method, starts: 4, seed: UInt64.max - 1, maximumIterations: 50)
        #expect(search == again)
        #expect(search.runs.map(\.seed) == [UInt64.max - 1, UInt64.max, 0, 1])
        #expect(search.best.stress == search.runs.map(\.stress).min())
        for run in search.runs {
            #expect(
                run
                    == (try GlifiExploratoryAnalysis.multidimensionalScaling(
                        distances, method: method, seed: run.seed, maximumIterations: 50,
                        initialization: .random)))
        }
    }
    #expect(
        randomMDSCoordinates(count: 4, dimensions: 2, seed: 1)
            != randomMDSCoordinates(count: 4, dimensions: 2, seed: 2))
}

@Test("New MDS contracts fail closed on malformed, collapsed and over-budget inputs")
func completionMDSFailureGates() throws {
    for matrix in [
        [[0.0, 1], [2, 0]], [[0, -1], [-1, 0]], [[0, 0], [0, 0]],
        [[0, Double.infinity], [Double.infinity, 0]], [[0, 1], [1]],
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiExploratoryAnalysis.multidimensionalScaling(
                matrix, dimensions: 1, method: .ordinal)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            [[0, 1], [1, 0]], dimensions: 1, starts: 10,
            limits: GlifiExploratoryLimits(maximumWork: 1))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            [[0, 1], [1, 0]], dimensions: 1, starts: 10,
            limits: GlifiExploratoryLimits(maximumCells: 100))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            [[0, 1], [1, 0]], dimensions: 1, method: .classical)
    }
    let duplicates: [[Double]] = [[0, 0, 1], [0, 0, 1], [1, 1, 0]]
    #expect(
        try GlifiExploratoryAnalysis.multidimensionalScaling(
            duplicates, dimensions: 1, method: .ordinal
        ).stress.isFinite)
}

@Test("Hexagonal SOM matches an independent scalar batch oracle")
func completionHexagonalSOMOracle() throws {
    let matrix: [[Double]] = [[0, 1], [2, 3], [4, 0], [10, 11], [11, 10], [12, 12]]
    let observed = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 3, height: 2, seed: 27, epochs: 4, topology: .hexagonal)
    // Independent Python stdlib implementation: per-row weights without grouped sums,
    // odd-row embedded coordinates, SplitMix64 seed 27; no production helper reused.
    let expected = [
        [2.002673764577797, 0.6615430177732173],
        [5.424088404429741, 5.025548307728513],
        [10.582409121373372, 10.583097629508822],
        [2.0356541641587413, 2.501180125298102],
        [8.688745674800883, 8.922864923823333],
        [11.677911385518055, 11.678173357214844],
    ]
    for (a, b) in zip(observed.prototypes.flatMap { $0 }, expected.flatMap { $0 }) {
        #expect(abs(a - b) < 1e-11)
    }
    #expect(observed.assignments == [0, 3, 0, 2, 2, 5])
    #expect(abs(observed.quantizationError - 1.0873276812528467) < 1e-12)
    #expect(observed.topology == .hexagonal)
    #expect(observed.methodIdentifier == "SOM-batch-gaussian-hexagonal-odd-row-v1")
    #expect(
        observed
            == (try GlifiExploratoryAnalysis.selfOrganizingMap(
                matrix, width: 3, height: 2, seed: 27, epochs: 4, topology: .hexagonal)))
}

@Test("SOM preserves rectangular defaults and exposes bounded reciprocal hex neighbors")
func completionSOMTopologyProperties() throws {
    let matrix: [[Double]] = [[0], [1], [4], [5]]
    let legacy = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 2, height: 2, seed: 12, epochs: 3)
    let explicit = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 2, height: 2, seed: 12, epochs: 3, topology: .rectangular)
    #expect(legacy == explicit)
    #expect(legacy.methodIdentifier == GlifiSOMResult.identifier)
    for topology in [GlifiSOMTopology.rectangular, .hexagonal] {
        for unit in 0..<25 {
            let neighbors = somNeighbors(unit, width: 5, height: 5, topology: topology)
            #expect(!neighbors.contains(unit))
            #expect(neighbors.count <= (topology == .hexagonal ? 6 : 4))
            #expect(neighbors == Array(Set(neighbors)).sorted())
            for neighbor in neighbors {
                #expect(
                    somNeighbors(neighbor, width: 5, height: 5, topology: topology).contains(unit))
            }
        }
    }
    #expect(somNeighbors(12, width: 5, height: 5, topology: .hexagonal).count == 6)
    #expect(somNeighbors(12, width: 5, height: 5, topology: .rectangular).count == 4)
}

@Test("SOM U-matrix uses actual neighbors and the median, including even boundaries")
func completionSOMUMatrixOracle() throws {
    let prototypes = (0..<9).map { [Double($0)] }
    let hex = completionSOMFixture(prototypes, width: 3, height: 3, topology: .hexagonal)
    let values = try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(hex)
    // Unit 4 has neighbors 1,2,3,5,7,8: distances 3,2,1,1,3,4 -> median 2.5.
    #expect(values[4] == 2.5)
    // Upper-left unit 0 has neighbors 1,3: median(1,3)=2.
    #expect(values[0] == 2)
    let rectangle = completionSOMFixture(prototypes, width: 3, height: 3, topology: .rectangular)
    #expect(try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(rectangle)[4] == 2)
    let single = completionSOMFixture([[7]], width: 1, height: 1, topology: .hexagonal)
    #expect(try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(single) == [0])
    let invalid = completionSOMFixture([[0]], width: 2, height: 2, topology: .hexagonal)
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(invalid)
    }
    let overflowing = completionSOMFixture(
        [[-Double.greatestFiniteMagnitude], [Double.greatestFiniteMagnitude]],
        width: 2, height: 1, topology: .hexagonal)
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(overflowing)
    }
}

@Test("SOM codebook clustering composes exact Ward and retains unit identities")
func completionSOMWardComposition() throws {
    let prototypes = [[0.0], [1], [10], [11]]
    let map = completionSOMFixture(prototypes, width: 2, height: 2, topology: .hexagonal)
    let result = try GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
        map, clusterCount: 2)
    #expect(
        result.tree
            == (try GlifiMultivariateMethods.hierarchicalClustering(prototypes, linkage: .ward)))
    #expect(result.assignments == [0, 0, 1, 1])
    let single = completionSOMFixture([[7]], width: 1, height: 1, topology: .hexagonal)
    let trivial = try GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
        single, clusterCount: 1)
    #expect(trivial.tree.merges.isEmpty)
    #expect(trivial.assignments == [0])
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
            map, clusterCount: 2, limits: GlifiExploratoryLimits(maximumWork: 1))
    }
}

@Test("Completion APIs honor already-cancelled tasks before iterative work")
func completionExploratoryCancellation() async throws {
    for operation in 0..<5 {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            switch operation {
            case 0:
                _ = try GlifiExploratoryAnalysis.multidimensionalScaling(
                    [[0, 1], [1, 0]], dimensions: 1, method: .ordinal)
            case 1:
                _ = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
                    [[0, 1], [1, 0]], dimensions: 1)
            case 2:
                _ = try GlifiExploratoryAnalysis.selfOrganizingMap(
                    [[0], [1]], width: 2, height: 1, seed: 0, topology: .hexagonal)
            case 3:
                _ = try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(
                    completionSOMFixture([[0], [1]], width: 2, height: 1, topology: .hexagonal))
            default:
                _ = try GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
                    completionSOMFixture([[0], [1]], width: 2, height: 1, topology: .hexagonal),
                    clusterCount: 1)
            }
        }
        do {
            try await task.value
            Issue.record("Cancellation was ignored")
        } catch is CancellationError {}
    }
}

@Test("Ordinal MDS and hexagonal SOM stop when cancellation arrives during a run")
func completionExploratoryMidrunCancellation() async throws {
    for operation in 0..<2 {
        let task = Task.detached {
            if operation == 0 {
                let distances = (0..<150).map { row in
                    (0..<150).map { column in Double(abs(row - column)) }
                }
                _ = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
                    distances, seed: 12, maximumIterations: 1_000, initialization: .random)
            } else {
                let matrix = (0..<10_000).map { row in
                    (0..<4).map { column in sin(Double(row + column) * 0.01) }
                }
                _ = try GlifiExploratoryAnalysis.selfOrganizingMap(
                    matrix, width: 4, height: 4, seed: 12, epochs: 100, topology: .hexagonal)
            }
        }
        try await Task.sleep(for: .milliseconds(2))
        task.cancel()
        do {
            try await task.value
            Issue.record("Mid-run cancellation was ignored")
        } catch is CancellationError {}
    }
}

private func completionDistance(_ a: [Double], _ b: [Double]) -> Double {
    zip(a, b).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }.squareRoot()
}

private func completionSOMFixture(
    _ prototypes: [[Double]], width: Int, height: Int, topology: GlifiSOMTopology
) -> GlifiSOMResult {
    GlifiSOMResult(
        topology: topology, width: width, height: height,
        prototypes: prototypes, assignments: [], quantizationError: 0,
        topographicError: 0, epochs: 0, converged: true, seed: 0)
}

/// Independent exhaustive partition oracle; does not use PAVA or production block helpers.
private func completionEnumeratedIsotonic(_ values: [Double], levels: [Double]) -> [Double] {
    var best = [Double]()
    var minimum = Double.infinity
    for cuts in 0..<(1 << (values.count - 1)) {
        var groups: [[Int]] = [[0]]
        var valid = true
        for index in 1..<values.count {
            if cuts & (1 << (index - 1)) != 0 {
                if levels[index] == levels[index - 1] {
                    valid = false
                    break
                }
                groups.append([index])
            } else {
                groups[groups.count - 1].append(index)
            }
        }
        guard valid else { continue }
        let means = groups.map { group in
            group.reduce(0.0) { $0 + values[$1] } / Double(group.count)
        }
        guard zip(means, means.dropFirst()).allSatisfy({ $0 <= $1 }) else { continue }
        var candidate = [Double](repeating: 0, count: values.count)
        for (index, group) in groups.enumerated() {
            for item in group { candidate[item] = means[index] }
        }
        let error = zip(candidate, values).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) }
        if error < minimum {
            minimum = error
            best = candidate
        }
    }
    let norm = best.reduce(0) { $0 + $1 * $1 }
    return best.map { $0 * (Double(best.count) / norm).squareRoot() }
}
