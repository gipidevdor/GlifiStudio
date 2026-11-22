// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("SOM preserves representable tiny norms and does not square away the tolerance")
func exploratoryReauditTinySOM() throws {
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1e-200]], width: 1, height: 1, seed: 0, epochs: 1,
        initialRadius: 1, finalRadius: 1, tolerance: 1e-300)
    #expect(result.quantizationError > 0)
    #expect(abs(result.quantizationError / 5e-201 - 1) < 1e-12)
    #expect(abs(result.prototypes[0][0] / 5e-201 - 1) < 1e-12)
    #expect(!result.converged)
}

@Test("SOM keeps extreme constant prototypes instead of losing weighted products")
func exploratoryReauditConstantSOM() throws {
    for value in [Double.leastNonzeroMagnitude, 1e308] {
        let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
            [[value], [value]], width: 2, height: 1, seed: 0, epochs: 2,
            initialRadius: 0.5, finalRadius: 0.5)
        #expect(result.prototypes == [[value], [value]])
        #expect(result.quantizationError == 0)
        #expect(result.converged)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.selfOrganizingMap(
            [[Double.leastNonzeroMagnitude], [1]], width: 2, height: 1, seed: 0)
    }
}

@Test("SOM radius interpolation retains finite geometric midpoints and the final update")
func exploratoryReauditRadiusSchedule() throws {
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1]], width: 2, height: 1, seed: 0, epochs: 3,
        initialRadius: 1e-160, finalRadius: 1e150)
    #expect(result.prototypes == [[0.5], [0.5]])
    // The true midpoint radius is 1e-5, so the change happens on the final epoch.
    #expect(!result.converged)
    let endpoint = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1]], width: 2, height: 1, seed: 0, epochs: 1,
        initialRadius: 1e-160, finalRadius: 1e150)
    #expect(endpoint.prototypes == [[0.5], [0.5]])
}

@Test("CLARA retains medoid identity and relative objectives under unit changes")
func exploratoryReauditCLARAScaleEquivariance() throws {
    for scale in [1.0, 1e-13, 1e-200, 1e200, 1e308] {
        let result = try GlifiExploratoryAnalysis.clara(
            [[0], [scale], [1.1 * scale]], clusterCount: 1, seed: 0,
            samples: 1, sampleSize: 3, maximumSwaps: 1)
        #expect(result.medoids == [1])
        #expect(result.assignments == [0, 0, 0])
        #expect(result.objective > 0)
        #expect(abs(result.objective / scale - 1.1) < 1e-12)
    }
    let two = try GlifiExploratoryAnalysis.clara(
        [[0], [1e-200]], clusterCount: 1, seed: 0, samples: 1, sampleSize: 2, maximumSwaps: 1)
    #expect(two.objective == 1e-200)
}

@Test("Exploratory admission includes all SOM phases and CLARA pairwise columns")
func exploratoryReauditWorkAndPairwiseAdmission() throws {
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.selfOrganizingMap(
            [[0], [1]], width: 2, height: 1, seed: 0, epochs: 1,
            limits: GlifiExploratoryLimits(maximumWork: 8))
    }
    let wide = (0..<4).map { [Double](repeating: Double($0), count: 20) }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.clara(
            wide, clusterCount: 1, seed: 0, samples: 1, sampleSize: 4, maximumSwaps: 1,
            limits: GlifiExploratoryLimits(maximumWork: 100))
    }
    for limits in [
        GlifiExploratoryLimits(maximumCells: 12),
        GlifiExploratoryLimits(maximumPairwiseObjects: 3),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiExploratoryAnalysis.clara(
                [[0], [1], [2], [3]], clusterCount: 1, seed: 0,
                samples: 1, sampleSize: 4, maximumSwaps: 1, limits: limits)
        }
    }
}

@Test("SOM U-matrix median does not underflow an even pair of subnormal distances")
func exploratoryReauditUMatrixSubnormalMedian() throws {
    let tiny = Double.leastNonzeroMagnitude
    let map = GlifiSOMResult(
        topology: .rectangular, width: 3, height: 1, prototypes: [[0], [tiny], [0]],
        assignments: [], quantizationError: 0, topographicError: 0,
        epochs: 1, converged: true, seed: 0)
    let result = try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(map)
    #expect(result == [tiny, tiny, tiny])
}

@Test("SOM Ward composition admits its own pairwise representation")
func exploratoryReauditSOMWardCells() throws {
    let map = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1]], width: 2, height: 2, seed: 0, epochs: 1)
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
            map, clusterCount: 2, limits: GlifiExploratoryLimits(maximumCells: 8))
    }
}

@Test("Non-Ward HAC preserves tiny Euclidean heights for single, complete and average")
func exploratoryReauditHACTinyDistances() throws {
    for linkage in [GlifiLinkage.single, .complete, .average] {
        let tree = try GlifiMultivariateMethods.hierarchicalClustering(
            [[0], [1e-200], [3e-200]], linkage: linkage)
        #expect(tree.merges[0].height > 0)
        #expect(abs(tree.merges[0].height / 1e-200 - 1) < 1e-12)
        let expected = linkage == .single ? 2e-200 : linkage == .complete ? 3e-200 : 2.5e-200
        #expect(abs(tree.merges[1].height / expected - 1) < 1e-12)
    }
}

@Test("Ward rejects unrepresentable positive increments and retains finite large heights")
func exploratoryReauditWardNumericRange() throws {
    do {
        _ = try GlifiMultivariateMethods.hierarchicalClustering([[0], [1e-200]], linkage: .ward)
        Issue.record("A positive unrepresentable Ward increment became zero")
    } catch let failure as GlifiFailure { #expect(failure.code == "hac.numeric-range") }
    let tree = try GlifiMultivariateMethods.hierarchicalClustering(
        [[0], [1.4e154]], linkage: .ward)
    #expect(tree.merges[0].wardIncrement?.isFinite == true)
    #expect(abs(tree.merges[0].height / 1.4e154 - 1) < 1e-12)
}

@Test("Ward retains a constant subnormal centroid through subsequent merges")
func exploratoryReauditWardConstantCentroid() throws {
    let tiny = Double.leastNonzeroMagnitude
    let tree = try GlifiMultivariateMethods.hierarchicalClustering(
        [[tiny], [tiny], [tiny]], linkage: .ward)
    #expect(tree.merges.count == 2)
    #expect(tree.merges.allSatisfy { $0.height == 0 && $0.wardIncrement == 0 })
}
