// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("NMF contigua conserva bit per bit la definizione scalare per forme, seed e stopping")
func factorizationRefinementMatchesScalarDefinition() throws {
    for (rows, columns, rank) in [
        (4, 7, 1), (7, 5, 3), (9, 11, 4),
        (4, 129, 1), (4, 129, 4), (129, 4, 1), (129, 4, 4),
    ] {
        for seed in 1...4 {
            var generator = GlifiSplitMix64(seed: UInt64(seed))
            let matrix = (0..<rows).map { row in
                (0..<columns).map { column in
                    row == rows - 1 || column == columns - 1
                        ? 0 : Double(generator.index(below: 7) + 1)
                }
            }
            let w = (0..<rows).map { _ in
                (0..<rank).map { _ in Double(generator.index(below: 19) + 1) / 20 }
            }
            let h = (0..<rank).map { _ in
                (0..<columns).map { _ in Double(generator.index(below: 19) + 1) / 20 }
            }
            for tolerance in [-1.0, 0.5, 1e-8] {
                let expected = scalarFactorizationReference(
                    matrix, initialW: w, initialH: h, maximumIterations: 9, tolerance: tolerance)
                let actual = try GlifiMultivariateMethods.leeSeung(
                    matrix, initialW: w, initialH: h, maximumIterations: 9, tolerance: tolerance)
                #expect(factorizationBits(actual.w) == factorizationBits(expected.w))
                #expect(factorizationBits(actual.h) == factorizationBits(expected.h))
                #expect(actual.history.map(\.bitPattern) == expected.history.map(\.bitPattern))
                #expect(actual.converged == expected.converged)
                if tolerance < 0 { #expect(actual.history.count == 9) }
            }
        }
    }
}

@Test("NMF conserva inizializzazione e selezione dei restart contro la definizione scalare")
func factorizationRefinementPreservesSeededRestarts() throws {
    let matrix: [[Double]] = [[1, 2, 0, 3], [0, 1, 4, 1], [2, 0, 1, 0], [1, 3, 2, 1]]
    try expectSeededFactorizationReference(matrix, rank: 2, seed: 17)
}

@Test("NMF flat conserva i restart su matrici larghe e alte di rango uno e quattro")
func factorizationStoragePreservesRectangularSeededRestarts() throws {
    for (rows, columns, rank) in [(4, 257, 1), (4, 257, 4), (257, 4, 1), (257, 4, 4)] {
        let seed = UInt64(173 + rows + rank)
        var generator = GlifiSplitMix64(seed: seed)
        let matrix = (0..<rows).map { row in
            (0..<columns).map { column in
                row == rows - 1 || column == columns - 1
                    ? 0 : Double(generator.index(below: 9))
            }
        }
        try expectSeededFactorizationReference(matrix, rank: rank, seed: seed)
    }
}

private func expectSeededFactorizationReference(
    _ matrix: [[Double]], rank: Int, seed: UInt64
) throws {
    let restartCount = 3
    let maximumIterations = 12
    let tolerance = 1e-8
    var best: (w: [[Double]], h: [[Double]], history: [Double], converged: Bool)?
    var chosenRestart = -1
    for restart in 0..<restartCount {
        var generator = GlifiSplitMix64(seed: seed &+ UInt64(restart))
        func uniform() -> Double { Double((generator.next() >> 11) + 1) / Double(1 << 53) }
        let w = matrix.map { _ in (0..<rank).map { _ in uniform() } }
        let h = (0..<rank).map { _ in matrix[0].map { _ in uniform() } }
        let candidate = scalarFactorizationReference(
            matrix, initialW: w, initialH: h,
            maximumIterations: maximumIterations, tolerance: tolerance)
        if best == nil
            || (candidate.history.last ?? .infinity) < (best?.history.last ?? .infinity) - 1e-15
        {
            best = candidate
            chosenRestart = restart
        }
    }
    let expected = try #require(best)
    let actual = try GlifiMultivariateMethods.nonNegativeFactorization(
        matrix, rank: rank, seed: seed, restarts: restartCount,
        maximumIterations: maximumIterations, tolerance: tolerance)
    #expect(factorizationBits(actual.w) == factorizationBits(expected.w))
    #expect(factorizationBits(actual.h) == factorizationBits(expected.h))
    #expect(actual.objectiveHistory.map(\.bitPattern) == expected.history.map(\.bitPattern))
    #expect(actual.chosenRestart == chosenRestart)
    #expect(actual.iterations == expected.history.count)
    #expect(actual.converged == expected.converged)
    #expect(actual.objective.bitPattern == expected.history.last?.bitPattern)
}

@Test("NMF contigua interrompe i kernel senza consegnare un risultato parziale")
func factorizationRefinementObservesCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiMultivariateMethods.nonNegativeFactorization(
            [[1, 2], [3, 4]], rank: 1, seed: 1, maximumIterations: 10)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

private func factorizationBits(_ matrix: [[Double]]) -> [[UInt64]] {
    matrix.map { $0.map(\.bitPattern) }
}

// Direct Lee-Seung definition: independently allocated matrix products and transposes.
// This reference intentionally retains strided right-hand reads and a materialized WH.
private func scalarFactorizationReference(
    _ matrix: [[Double]], initialW: [[Double]], initialH: [[Double]],
    maximumIterations: Int, tolerance: Double
) -> (w: [[Double]], h: [[Double]], history: [Double], converged: Bool) {
    func transpose(_ values: [[Double]]) -> [[Double]] {
        let width = values.first?.count ?? 0
        return (0..<width).map { column in values.map { $0[column] } }
    }
    func multiply(_ left: [[Double]], _ right: [[Double]]) -> [[Double]] {
        let width = right.first?.count ?? 0
        return left.map { row in
            (0..<width).map { column in
                var total = 0.0
                for index in right.indices { total += row[index] * right[index][column] }
                return total
            }
        }
    }
    func objective(_ w: [[Double]], _ h: [[Double]]) -> Double {
        let product = multiply(w, h)
        return matrix.indices.reduce(0.0) { total, row in
            total
                + matrix[row].indices.reduce(0.0) {
                    $0 + (matrix[row][$1] - product[row][$1]) * (matrix[row][$1] - product[row][$1])
                }
        }
    }
    var w = initialW
    var h = initialH
    var previous = objective(w, h)
    var history: [Double] = []
    var converged = false
    for _ in 0..<maximumIterations {
        let wt = transpose(w)
        let numeratorH = multiply(wt, matrix)
        let denominatorH = multiply(multiply(wt, w), h)
        for factor in h.indices {
            for column in h[factor].indices {
                h[factor][column] *=
                    numeratorH[factor][column] / (denominatorH[factor][column] + 1e-12)
            }
        }
        let ht = transpose(h)
        let numeratorW = multiply(matrix, ht)
        let denominatorW = multiply(w, multiply(h, ht))
        for row in w.indices {
            for factor in w[row].indices {
                w[row][factor] *= numeratorW[row][factor] / (denominatorW[row][factor] + 1e-12)
            }
        }
        let current = objective(w, h)
        history.append(current)
        if abs(previous - current) <= tolerance * max(previous, 1e-300) {
            converged = true
            break
        }
        previous = current
    }
    return (w, h, history, converged)
}
