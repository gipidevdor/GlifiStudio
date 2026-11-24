// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("KH algebraic Ward.D2 matches base-R hclust on Jaccard dissimilarities")
func khLegacyWardD2JaccardROracle() throws {
    // Independent dist(method="binary") + hclust(method="ward.D2") in the R oracle.
    let distances: [[Double]] = [
        [0, 0.5, 0.8, 1, 0.8], [0.5, 0, 0.8, 1, 0.8],
        [0.8, 0.8, 0, 0.75, 1], [1, 1, 0.75, 0, 0.75],
        [0.8, 0.8, 1, 0.75, 0],
    ]
    let result = try GlifiKHLegacyClustering.wardD2(dissimilarities: distances)
    #expect(result.objectCount == 5)
    #expect(result.methodIdentifier == "KH-hclust-WardD2-dissimilarities-v1")
    #expect(result.merges.map(\.first) == [0, 2, 4, 6])
    #expect(result.merges.map(\.second) == [1, 3, 5, 7])
    #expect(result.merges.map(\.size) == [2, 2, 3, 5])
    #expect(result.merges.allSatisfy { $0.wardIncrement == nil })
    khLegacyWardClose(
        result.merges.map(\.height), [0.5, 0.75, 0.87749643873921224, 1.09155851881610078])
    #expect(
        try JSONDecoder().decode(
            GlifiKHLegacyClusteringResult.self, from: JSONEncoder().encode(result)) == result)
    // The native vector Ward boundary continues to reject dissimilarities.
    #expect(throws: GlifiFailure.self) {
        try GlifiTextMatrixOperators.hierarchicalClustering(
            dissimilarities: distances, linkage: .ward)
    }
}

@Test("KH Ward.D2 agrees with independent centroid Ward on Euclidean vectors")
func khLegacyWardD2EuclideanAndScale() throws {
    let points: [[Double]] = [[0, 0], [1, 2], [4, 1], [7, -3], [8, 4]]
    let distances = points.map { left in
        points.map { right in hypot(left[0] - right[0], left[1] - right[1]) }
    }
    let direct = try GlifiMultivariateMethods.hierarchicalClustering(points, linkage: .ward)
    let algebraic = try GlifiKHLegacyClustering.wardD2(dissimilarities: distances)
    #expect(algebraic.merges.map(\.first) == direct.merges.map(\.first))
    #expect(algebraic.merges.map(\.second) == direct.merges.map(\.second))
    khLegacyWardClose(algebraic.merges.map(\.height), direct.merges.map(\.height))
    for exponent in [-400, 400] {
        let scale = Double(sign: .plus, exponent: exponent, significand: 1)
        let scaled = try GlifiKHLegacyClustering.wardD2(
            dissimilarities: distances.map { $0.map { $0 * scale } })
        #expect(scaled.merges.map(\.first) == algebraic.merges.map(\.first))
        #expect(scaled.merges.map(\.second) == algebraic.merges.map(\.second))
        khLegacyWardClose(scaled.merges.map { $0.height / scale }, algebraic.merges.map(\.height))
    }
}

@Test("KH Ward.D2 also matches base-R hclust on cosine dissimilarities")
func khLegacyWardD2CosineROracle() throws {
    let distances: [[Double]] = [
        [0, 0.32580013753675785, 0.89153477109067192, 0.25579159246474925],
        [0.32580013753675785, 0, 0.48810930311100853, 0.58187899499645457],
        [0.89153477109067192, 0.48810930311100853, 0, 0.46186176480295005],
        [0.25579159246474925, 0.58187899499645457, 0.46186176480295005, 0],
    ]
    let result = try GlifiKHLegacyClustering.wardD2(dissimilarities: distances)
    #expect(result.merges.map(\.first) == [0, 1, 4])
    #expect(result.merges.map(\.second) == [3, 2, 5])
    #expect(result.merges.map(\.size) == [2, 2, 4])
    khLegacyWardClose(
        result.merges.map(\.height),
        [0.25579159246474925, 0.48810930311100853, 0.75802354901694169])
}

@Test("KH Ward.D2 has explicit cluster-identity ties without claiming R's tied-tree ordering")
func khLegacyWardD2TiesAndZeros() throws {
    for value in [0.0, 1.0, Double.leastNonzeroMagnitude] {
        let matrix = (0..<4).map { row in (0..<4).map { column in row == column ? 0 : value } }
        let result = try GlifiKHLegacyClustering.wardD2(dissimilarities: matrix)
        #expect(result.merges.map(\.first) == [0, 2, 4])
        #expect(result.merges.map(\.second) == [1, 3, 5])
        #expect(result.merges.map(\.height) == [value, value, value])
    }
    let duplicates = try GlifiKHLegacyClustering.wardD2(
        dissimilarities: [[0, 0, 1], [0, 0, 1], [1, 1, 0]])
    #expect(duplicates.merges[0].height == 0)
    khLegacyWardClose(duplicates.merges.map(\.height), [0, sqrt(4.0 / 3)])
}

@Test("KH Ward.D2 rejects invalid inputs, underflow, overflow and exhausted budgets")
func khLegacyWardD2AdmissionAndNumericRange() throws {
    for matrix in [
        [[Double]](), [[0]], [[0, 1], [1]], [[0, 1], [2, 0]],
        [[1, 0], [0, 0]], [[0, -1], [-1, 0]], [[0, .infinity], [.infinity, 0]],
        [[0, .nan], [.nan, 0]],
        [[0, 1e-300, 1e300], [1e-300, 0, 1e300], [1e300, 1e300, 0]],
        [
            [0, 0, Double.greatestFiniteMagnitude],
            [0, 0, Double.greatestFiniteMagnitude],
            [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, 0],
        ],
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiKHLegacyClustering.wardD2(dissimilarities: matrix)
        }
    }
    let matrix: [[Double]] = [[0, 1, 2], [1, 0, 2], [2, 2, 0]]
    for limits in [
        GlifiExploratoryLimits(maximumCells: 53), .init(maximumWork: 53),
        .init(maximumPairwiseObjects: 2),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiKHLegacyClustering.wardD2(dissimilarities: matrix, limits: limits)
        }
    }
    #expect(
        try GlifiKHLegacyClustering.wardD2(
            dissimilarities: matrix,
            limits: .init(maximumCells: 54, maximumWork: 54)
        ).merges.count == 2)
}

@Test("KH Ward.D2 checks cancellation before matrix preparation")
func khLegacyWardD2Cancellation() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiKHLegacyClustering.wardD2(dissimilarities: [[0, 1], [1, 0]])
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled Ward.D2 unexpectedly completed")
    } catch is CancellationError {
    }
}

private func khLegacyWardClose(_ actual: [Double], _ expected: [Double]) {
    #expect(actual.count == expected.count)
    for (value, reference) in zip(actual, expected) {
        #expect(abs(value - reference) <= 1e-12 * max(1, abs(reference)))
    }
}
