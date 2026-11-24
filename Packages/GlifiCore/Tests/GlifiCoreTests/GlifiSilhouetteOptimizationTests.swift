// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Silhouette indicizzata conserva bitwise distanze, membri e riduzioni ordinarie")
func silhouetteOrdinaryMatchesReferenceBitwise() throws {
    for seed in 0..<8 {
        var state = UInt64(seed + 172)
        let points = (0..<64).map { row in
            (0..<7).map { column -> Double in
                state = state &* 6_364_136_223_846_793_005 &+ 1
                return Double(state >> 32) / 4_294_967_296 + Double(row % 5 + column)
            }
        }
        for clusterCount in [2, 7, 32] {
            let labels = points.indices.map { index in
                index % clusterCount == 0 ? Int.max : -(index % clusterCount)
            }
            try expectSilhouetteBits(points, labels)
        }
    }
    try expectSilhouetteBits([[0, -0.0], [0, 0], [0, 0], [0, 0]], [-2, -2, 8, 8])
    try expectSilhouetteBits([[0], [1], [3], [4], [20]], [3, 3, -5, -5, Int.min])
}

@Test("Silhouette prova il percorso ordinario ai confini ULP e ampiezza")
func silhouetteProvenOrdinaryBoundaryMatchesDefinition() throws {
    let labels = [0, 0, 1, 1]
    let lower = Double(sign: .plus, exponent: -458, significand: 1)
    #expect(silhouetteUsesProvenOrdinary([[lower], [lower.nextUp]]))
    #expect(!silhouetteUsesProvenOrdinary([[lower], [lower.nextDown]]))
    #expect(!silhouetteUsesProvenOrdinary([[lower / 2], [(lower / 2).nextDown]]))
    for coordinate in [lower.nextDown, lower, lower.nextUp] {
        try expectSilhouetteBits(
            [[coordinate], [coordinate.nextUp], [-coordinate], [-coordinate.nextUp]], labels)
    }
    for dimensions in [1, 3] {
        let upper = (Double.greatestFiniteMagnitude / (8 * Double(dimensions))).squareRoot()
        #expect(silhouetteUsesProvenOrdinary([[Double](repeating: upper, count: dimensions)]))
        #expect(
            !silhouetteUsesProvenOrdinary([[Double](repeating: upper.nextUp, count: dimensions)]))
        for coordinate in [upper.nextDown, upper, upper.nextUp] {
            let points = [coordinate, 0, -coordinate, -coordinate / 2].map {
                [Double](repeating: $0, count: dimensions)
            }
            try expectSilhouetteBits(points, labels)
        }
    }
    #expect(silhouetteUsesProvenOrdinary([[0, -0.0], [0, 0]]))
    #expect(silhouetteUsesProvenOrdinary([[3, 3], [3, 3]]))
    #expect(!silhouetteUsesProvenOrdinary([[Double.leastNonzeroMagnitude], [0]]))
    #expect(!silhouetteUsesProvenOrdinary([[Double.greatestFiniteMagnitude], [0]]))
    try expectSilhouetteBits([[3, 3], [3, 3], [3, 3], [3, 3]], labels)
}

@Test("Silhouette recupera quadrati e somme estremi mantenendo le medie fino al rapporto")
func silhouetteExtremesPreserveScale() throws {
    // Decimal80 oracle: Tests/Oracles/Python/silhouette_extremes.py.
    // Rational widths 19/21, 17/19; average 359/399.
    let expected = [
        0.90476190476190477, 0.89473684210526316, 0.89473684210526316, 0.90476190476190477,
    ]
    for scale in [1e-200, 1e200, Double.greatestFiniteMagnitude / 16] {
        let points = [0.0, 1, 10, 11].map { [$0 * scale] }
        let result = try GlifiMultivariateMethods.silhouette(points, assignments: [0, 0, 1, 1])
        for (value, reference) in zip(result.widths, expected) {
            #expect(value.isFinite)
            #expect(abs(value - reference) < 1e-12)
        }
        #expect(abs(result.average - 0.89974937343358397) < 1e-12)
    }
    // Independent Decimal fixture with powers of two, avoiding input rounding.
    for exponent in [-600, 600] {
        let scale = Double(sign: .plus, exponent: exponent, significand: 1)
        let result = try GlifiMultivariateMethods.silhouette(
            [0.0, 1, 3, 4].map { [$0 * scale] }, assignments: [0, 0, 1, 1])
        for (value, reference) in zip(
            result.widths, [0.7142857142857143, 0.6, 0.6, 0.7142857142857143])
        {
            #expect(abs(value - reference) < 1e-12)
        }
        #expect(abs(result.average - 0.65714285714285714) < 1e-12)
    }
    // Decimal80 negative branch: the within-cluster distance sum overflows.
    let negative = try GlifiMultivariateMethods.silhouette(
        [[0], [1e308], [1e308], [8e307]], assignments: [0, 0, 0, 1])
    for (value, reference) in zip(negative.widths, [-0.2, -0.6, -0.6, 0]) {
        #expect(abs(value - reference) < 1e-12)
    }
    #expect(abs(negative.average - -0.35) < 1e-12)
}

@Test("Silhouette conserva la forma delle distanze subnormali 1D e 2D")
func silhouetteSubnormalMeansRemainScaled() throws {
    let unit = Double.leastNonzeroMagnitude
    for dimensions in [1, 2] {
        let points = [0.0, 1, 10, 11].map {
            [Double](repeating: $0 * unit, count: dimensions)
        }
        let result = try GlifiMultivariateMethods.silhouette(points, assignments: [0, 0, 1, 1])
        for (value, reference) in zip(
            result.widths,
            [0.90476190476190477, 0.89473684210526316, 0.89473684210526316, 0.90476190476190477]
        ) {
            #expect(abs(value - reference) < 1e-12)
        }
        #expect(abs(result.average - 0.89974937343358397) < 1e-12)
    }
}

@Test("Silhouette sottrae le coordinate prima del recupero scalato")
func silhouetteLargeOriginRetainsSmallSpread() throws {
    let origin = 1e200
    let step = origin.ulp
    let result = try GlifiMultivariateMethods.silhouette(
        [0.0, 1, 10, 11].map { [origin + $0 * step] }, assignments: [0, 0, 1, 1])
    #expect(abs(result.average - 0.89974937343358397) < 1e-12)
}

@Test("Silhouette valida forma e finiti anche quando tutti i cluster sono singleton")
func silhouetteRejectsInvalidInputsBeforeSingletonShortcut() throws {
    for (points, labels) in [
        ([], []), ([[0]], [0]), ([[0], [1]], [0]), ([[0], [1]], [0, 0]),
        ([[], []], [0, 1]), ([[0, 1], [0]], [0, 1]),
        ([[Double.nan], [0]], [0, 1]), ([[0], [Double.infinity]], [0, 1]),
    ] as [([[Double]], [Int])] {
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.silhouette(points, assignments: labels)
        }
    }
    for points in [
        [[Double.greatestFiniteMagnitude], [-Double.greatestFiniteMagnitude], [0]],
        [[Double.greatestFiniteMagnitude, 0], [0, Double.greatestFiniteMagnitude], [0, 0]],
    ] {
        do {
            _ = try GlifiMultivariateMethods.silhouette(points, assignments: [0, 0, 1])
            Issue.record("Una distanza non rappresentabile deve fallire")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "clustering.silhouette-distance-range")
        }
    }
}

@Test("Silhouette applica budget a celle e lavoro effettivo preservando i singleton")
func silhouetteBudgetsUseActualDistanceWork() throws {
    let row = [Double](repeating: 0, count: 1000)
    do {
        _ = try GlifiMultivariateMethods.silhouette(
            [[Double]](repeating: row, count: 1000), assignments: (0..<1000).map { $0 % 2 })
        Issue.record("Il lavoro oltre budget deve fallire prima delle distanze")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "exploratory.resource-limit")
        #expect(failure.category == .insufficientResources)
    }
    let wide = [Double](repeating: 0, count: 2_500_001)
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.silhouette([wide, wide], assignments: [0, 1])
    }
    let points = (0..<3000).map { [$0.isMultiple(of: 2) ? Double.greatestFiniteMagnitude : 0] }
    let result = try GlifiMultivariateMethods.silhouette(points, assignments: Array(0..<3000))
    #expect(result.widths == [Double](repeating: 0, count: points.count))
    #expect(result.average.bitPattern == 0)
}

@Test("Silhouette propaga la cancellazione prima delle scorciatoie")
func silhouetteObservesCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiMultivariateMethods.silhouette([[0], [1]], assignments: [0, 1])
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

private func expectSilhouetteBits(_ points: [[Double]], _ labels: [Int]) throws {
    let expected = directSilhouette(points, labels)
    let actual = try GlifiMultivariateMethods.silhouette(points, assignments: labels)
    #expect(actual.widths.map(\.bitPattern) == expected.widths.map(\.bitPattern))
    #expect(actual.average.bitPattern == expected.average.bitPattern)
}

private func silhouetteUsesProvenOrdinary(_ points: [[Double]]) -> Bool {
    let values = points.flatMap { $0 }
    return GlifiSilhouetteComputation.supportsOrdinaryDistances(
        maximumAbsoluteCoordinate: values.map { abs($0) }.max() ?? 0,
        minimumNonzeroULP: values.filter { $0 != 0 }.map(\.ulp).min() ?? .infinity,
        dimensions: points[0].count
    )
}

/// Literal ordinary definition, independent of membership storage and numeric retry.
private func directSilhouette(
    _ points: [[Double]], _ assignments: [Int]
) -> (widths: [Double], average: Double) {
    func distance(_ left: Int, _ right: Int) -> Double {
        var total = 0.0
        for index in points[left].indices {
            let difference = points[left][index] - points[right][index]
            total += difference * difference
        }
        return total.squareRoot()
    }
    let clusters = Set(assignments).sorted()
    let widths = points.indices.map { point -> Double in
        let own = assignments[point]
        let mates = points.indices.filter { $0 != point && assignments[$0] == own }
        guard !mates.isEmpty else { return 0 }
        let a = mates.reduce(0) { $0 + distance(point, $1) } / Double(mates.count)
        let b =
            clusters.filter { $0 != own }.map { cluster -> Double in
                let members = points.indices.filter { assignments[$0] == cluster }
                return members.reduce(0) { $0 + distance(point, $1) } / Double(members.count)
            }.min() ?? 0
        let denominator = max(a, b)
        return denominator > 0 ? (b - a) / denominator : 0
    }
    return (widths, widths.reduce(0, +) / Double(widths.count))
}
