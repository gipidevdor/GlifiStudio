// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("Exploratory completion: deterministic end-to-end Release workloads")
func khCompletionExploratoryBenchmark() throws {
    let small = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
        [[0, 1, 1], [1, 0, 1], [1, 1, 0]], dimensions: 1,
        seed: 17, initialization: .random)
    #expect(abs(small.stress - 1.0 / 9) < 1e-10)
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    for count in [32, 64] {
        let matrix = exploratoryBenchmarkDistances(count)
        let expected = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
            matrix, seed: 200, maximumIterations: 100, initialization: .random)
        try measurePipelineOptimization(
            identifier: "kh-completion-ordinal-\(count)",
            generator:
                "synthetic circular chord ranks, n=\(count), dimensions=2, maxIterations=100, random seed=200",
            fixtureDigest: try pipelineBenchmarkDigest(matrix), expected: expected,
            body: {
                try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
                    matrix, seed: 200, maximumIterations: 100, initialization: .random)
            }, checksum: { try pipelineBenchmarkDigest(ExploratoryMDSBenchmarkSnapshot($0)) })
    }
    let searchMatrix = exploratoryBenchmarkDistances(24)
    let search = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
        searchMatrix, starts: 4, seed: 700, maximumIterations: 100)
    try measurePipelineOptimization(
        identifier: "kh-completion-ordinal-search-24x4",
        generator:
            "synthetic circular chord ranks, n=24, dimensions=2, starts=4, maxIterations=100, first seed=700",
        fixtureDigest: try pipelineBenchmarkDigest(searchMatrix), expected: search,
        body: {
            try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
                searchMatrix, starts: 4, seed: 700, maximumIterations: 100)
        },
        checksum: {
            try pipelineBenchmarkDigest(
                ExploratoryMDSSearchBenchmarkSnapshot(
                    chosenRun: $0.chosenRun, runs: $0.runs.map(ExploratoryMDSBenchmarkSnapshot.init)
                ))
        })
    let data = (0..<1_000).map { row in
        (0..<8).map { column in sin(Double(row * (column + 1)) * 0.037) }
    }
    let expectedMap = try GlifiExploratoryAnalysis.selfOrganizingMap(
        data, width: 8, height: 8, seed: 27, epochs: 20, topology: .hexagonal)
    try measurePipelineOptimization(
        identifier: "kh-completion-hexagonal-som-1000x8-8x8",
        generator:
            "synthetic sin(row*(column+1)*0.037), rows=1000, columns=8, grid=8x8, epochs=20, seed=27",
        fixtureDigest: try pipelineBenchmarkDigest(data), expected: expectedMap,
        body: {
            try GlifiExploratoryAnalysis.selfOrganizingMap(
                data, width: 8, height: 8, seed: 27, epochs: 20, topology: .hexagonal)
        }, checksum: { try pipelineBenchmarkDigest(ExploratorySOMBenchmarkSnapshot($0)) })
}

private func exploratoryBenchmarkDistances(_ count: Int) -> [[Double]] {
    let points = (0..<count).map { index in
        let angle = Double(index) * 2 * .pi / Double(count)
        return [cos(angle), sin(angle)]
    }
    return points.map { a in
        points.map { b in
            let distance = hypot(a[0] - b[0], a[1] - b[1])
            return Double(Int((distance * 100).rounded()))
        }
    }
}

private struct ExploratoryMDSBenchmarkSnapshot: Encodable {
    let methodIdentifier: String
    let coordinates: [[Double]]
    let eigenvalues: [Double]
    let stress: Double
    let objectiveHistory: [Double]
    let iterations: Int
    let converged: Bool
    let seed: UInt64

    init(_ value: GlifiMDSResult) {
        methodIdentifier = value.methodIdentifier
        coordinates = value.coordinates
        eigenvalues = value.eigenvalues
        stress = value.stress
        objectiveHistory = value.objectiveHistory
        iterations = value.iterations
        converged = value.converged
        seed = value.seed
    }
}

private struct ExploratoryMDSSearchBenchmarkSnapshot: Encodable {
    let chosenRun: Int
    let runs: [ExploratoryMDSBenchmarkSnapshot]
}

private struct ExploratorySOMBenchmarkSnapshot: Encodable {
    let methodIdentifier: String
    let topology: GlifiSOMTopology
    let width: Int
    let height: Int
    let prototypes: [[Double]]
    let assignments: [Int]
    let quantizationError: Double
    let topographicError: Double
    let epochs: Int
    let converged: Bool
    let seed: UInt64

    init(_ value: GlifiSOMResult) {
        methodIdentifier = value.methodIdentifier
        topology = value.topology
        width = value.width
        height = value.height
        prototypes = value.prototypes
        assignments = value.assignments
        quantizationError = value.quantizationError
        topographicError = value.topographicError
        epochs = value.epochs
        converged = value.converged
        seed = value.seed
    }
}
