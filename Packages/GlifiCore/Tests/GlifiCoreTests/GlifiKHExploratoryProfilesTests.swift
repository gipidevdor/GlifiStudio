// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Primary e secondary coincidono con PAVA indipendente stats::isoreg di R")
func khClosureOrdinalRBaseOracle() throws {
    let pairs = khClosurePairs()
    let coordinates = [0.0, 1, 3, 7]
    let fitted = coordinates.map { a in coordinates.map { abs(a - $0) } }
    let expectedPrimary = [
        0.23354968324845687, 0.58387420812114221, 0.58387420812114221,
        1.2845232578665129, 1.4012980994907411, 1.2845232578665129,
    ]
    let expectedSecondary = [
        0.49361404187383628, 0.49361404187383628, 1.1106315942161316,
        1.1106315942161316, 1.2340351046845908, 1.2340351046845908,
    ]
    for (ties, expected) in [
        (GlifiMDSOrdinalTies.primary, expectedPrimary), (.secondary, expectedSecondary),
    ] {
        let actual = try ordinalDisparities(pairs, fitted: fitted, count: 4, ties: ties)
        for (index, pair) in pairs.enumerated() {
            #expect(abs(actual[pair.row][pair.column] - expected[index]) < 1e-13)
        }
    }
    #expect(
        try ordinalDisparities(pairs, fitted: fitted, count: 4)
            == ordinalDisparities(pairs, fitted: fitted, count: 4, ties: .secondary))
}

@Test("Primary ammette lo zero stress con tie liberi, conservando il default secondary")
func khClosureOrdinalPrimaryAnalyticalAndLegacy() throws {
    let delta = [[0.0, 1, 1], [1, 0, 1], [1, 1, 0]]
    let primary = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
        delta, dimensions: 1, seed: 17, maximumIterations: 1_000,
        initialization: .random, ties: .primary)
    let secondary = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
        delta, dimensions: 1, seed: 17, maximumIterations: 1_000,
        initialization: .random, ties: .secondary)
    let legacy = try GlifiExploratoryAnalysis.multidimensionalScaling(
        delta, dimensions: 1, method: .ordinal, seed: 17, maximumIterations: 1_000,
        initialization: .random)
    #expect(primary.stress < 1e-24)
    #expect(abs(secondary.stress - 1.0 / 9) < 1e-10)
    #expect(secondary == legacy)
    #expect(primary.methodIdentifier == GlifiMDSOrdinalTies.primary.methodIdentifier)
    #expect(
        secondary.methodIdentifier == "MDS-ordinal-SMACOF-secondary-ties-normalized-raw-stress-v1")
}

@Test("La proiezione primary coincide con l'enumerazione esaustiva delle partizioni monotone")
func khClosureOrdinalPrimaryExhaustiveOracle() throws {
    let pairs = khClosurePairs()
    var generator = GlifiSplitMix64(seed: 300)
    for _ in 0..<64 {
        let values = pairs.map { _ in Double(generator.next() % 17 + 1) }
        var fitted = Array(repeating: Array(repeating: 0.0, count: 4), count: 4)
        for (pair, value) in zip(pairs, values) {
            fitted[pair.row][pair.column] = value
            fitted[pair.column][pair.row] = value
        }
        let order = pairs.indices.sorted {
            if pairs[$0].dissimilarity != pairs[$1].dissimilarity {
                return pairs[$0].dissimilarity < pairs[$1].dissimilarity
            }
            return values[$0] == values[$1] ? $0 < $1 : values[$0] < values[$1]
        }
        let ordered = order.map { values[$0] }
        var best = [Double]()
        var loss = Double.infinity
        for mask in 0..<(1 << (pairs.count - 1)) {
            var groups: [[Int]] = [[]]
            for index in ordered.indices {
                groups[groups.count - 1].append(index)
                if index < ordered.count - 1, mask & (1 << index) != 0 { groups.append([]) }
            }
            let means = groups.map { group in
                group.reduce(0.0) { $0 + ordered[$1] } / Double(group.count)
            }
            guard zip(means, means.dropFirst()).allSatisfy({ $0 <= $1 }) else { continue }
            var result = [Double](repeating: 0, count: ordered.count)
            for (group, mean) in zip(groups, means) { for index in group { result[index] = mean } }
            let objective = zip(ordered, result).reduce(0.0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
            if objective < loss {
                loss = objective
                best = result
            }
        }
        let multiplier = sqrt(Double(pairs.count) / best.reduce(0) { $0 + $1 * $1 })
        let actual = try ordinalDisparities(pairs, fitted: fitted, count: 4, ties: .primary)
        for (position, index) in order.enumerated() {
            #expect(
                abs(actual[pairs[index].row][pairs[index].column] - best[position] * multiplier)
                    < 1e-12)
        }
    }
}

@Test("La ricerca primary conserva parametro, seed e budget cumulativi")
func khClosureOrdinalSearchAndBudgets() throws {
    let delta = [[0.0, 1, 1, 3], [1, 0, 2, 3], [1, 2, 0, 2], [3, 3, 2, 0]]
    let search = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
        delta, dimensions: 1, starts: 3, seed: .max, maximumIterations: 20,
        ordinalTies: .primary)
    #expect(search.runs.map(\.seed) == [.max, 0, 1])
    #expect(search.best.stress == search.runs.map(\.stress).min())
    for result in search.runs {
        #expect(
            result
                == (try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
                    delta, dimensions: 1, seed: result.seed, maximumIterations: 20,
                    initialization: .random, ties: .primary)))
        #expect(
            zip(result.objectiveHistory, result.objectiveHistory.dropFirst()).allSatisfy {
                $1 <= $0
            })
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            delta, dimensions: 1, starts: 3, maximumIterations: 1,
            limits: .init(maximumWork: 100), ordinalTies: .primary)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
            delta, dimensions: 1, maximumIterations: 1,
            limits: .init(maximumCells: 100), ties: .primary)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            delta, method: .metric, ordinalTies: .primary)
    }
}

@Test("L'inizializzazione PCA SOM coincide con prcomp R a segni canonici")
func khClosureSOMPCAOracle() throws {
    let data = [[0.0, 1, 2], [2, -1, 0], [4, 3, 1], [1, 5, -2], [-2, 0, 3]]
    let expected = [
        [-5.2598221958025952, -0.36445636185782782, 3.7645336394524858],
        [-2.1110565976793456, 3.7762110743416626, 0.55538043561604156],
        [1.037709000443904, 7.916878510541153, -2.6537727682204029],
        [0.96229099955609643, -4.7168785105411528, 4.2537727682204025],
        [4.1110565976793456, -0.57621107434166241, 1.0446195643839584],
        [7.2598221958025952, 3.5644563618578284, -2.1645336394524861],
    ]
    let wide = try GlifiExploratoryAnalysis.khSelfOrganizingMapPCAInitialization(
        data, width: 3, height: 2)
    khClosureExpectClose(wide, expected)
    let tall = try GlifiExploratoryAnalysis.khSelfOrganizingMapPCAInitialization(
        data, width: 2, height: 3)
    for row in 0..<3 {
        for column in 0..<2 {
            khClosureExpectClose([tall[row * 2 + column]], [wide[column * 3 + row]])
        }
    }
}

@Test(
    "La PCA SOM conserva la seconda componente rappresentabile quando il quadrato va in underflow")
func khClosureSOMPCAMixedScaleOracle() throws {
    let input = [[1.0, 1e-200], [-1, 1e-200], [1, -1e-200], [-1, -1e-200]]
    let initial = try GlifiExploratoryAnalysis.khSelfOrganizingMapPCAInitialization(
        input, width: 2, height: 2)
    let radius = 2.309401076758503
    for (index, signs) in [(-1.0, -1.0), (1, -1), (-1, 1), (1, 1)].enumerated() {
        #expect(abs(initial[index][0] - signs.0 * radius) < 1e-12)
        #expect(abs(initial[index][1] / 1e-200 - signs.1 * radius) < 1e-12)
    }
}

@Test("Le due fasi online continuano gli stessi codebook e coincidono con l'oracolo R base")
func khClosureSOMTwoPhaseOracle() throws {
    let result = try GlifiExploratoryAnalysis.khSelfOrganizingMap(
        [[0, 1], [2, -1], [4, 3]], width: 2, height: 2,
        firstPhase: .init(steps: 5, initialLearningRate: 0.05, initialRadius: 2),
        secondPhase: .init(steps: 7, initialLearningRate: 0.02, initialRadius: 1.5),
        initialCodebooks: [[-1, 0], [1, 0], [-1, 2], [1, 2]])
    khClosureExpectClose(
        result.firstPhaseCodebooks,
        [
            [-0.99137604777669863, 0.0026527639313108963],
            [1.0011454399491229, 0.0026616880534262059],
            [-0.99026944489896807, 1.9940766250121194],
            [1.001828202382663, 1.9949826821080681],
        ])
    khClosureExpectClose(
        result.prototypes,
        [
            [-0.98666640453768484, 0.0040700579812887813],
            [1.0021643067595969, 0.0045475800306067227],
            [-0.98391218941451231, 1.9906230707816979],
            [1.0031977849497056, 1.9921861466165898],
        ])
    #expect(result.initialCodebooks == [[-1, 0], [1, 0], [-1, 2], [1, 2]])
    #expect(result.assignments == [2, 1, 3])
    #expect(abs(result.quantizationError - 1.9912827454600144) < 1e-12)
    #expect(abs(result.neighborhoodDistortion - 24.85621956951832) < 1e-12)
    #expect(result.topographicError == 0)
    #expect(result.completedSteps == 12)
}

@Test("PCA gestisce assi singleton, rango nullo e dati estremi senza reinizializzazioni")
func khClosureSOMDegenerateAndExtremeData() throws {
    for value in [3.0, 1e-300, Double.greatestFiniteMagnitude] {
        let result = try GlifiExploratoryAnalysis.khSelfOrganizingMap(
            [[value], [value]], width: 2, height: 1)
        #expect(result.initialCodebooks == [[value], [value]])
        #expect(result.prototypes == [[value], [value]])
        #expect(result.quantizationError == 0)
        #expect(result.neighborhoodDistortion == 0)
        #expect(result.assignments == [0, 0])
    }
    let singleton = try GlifiExploratoryAnalysis.khSelfOrganizingMap([[1, 2]], width: 1, height: 1)
    #expect(singleton.prototypes == [[1, 2]])
    #expect(singleton.completedSteps == 12)
    #expect(singleton.topographicError == 0)
    let line = try GlifiExploratoryAnalysis.khSelfOrganizingMapPCAInitialization(
        [[0.0], [1], [2]], width: 1, height: 3)
    khClosureExpectClose(line, [[-1], [1], [3]])
    let tiny = try GlifiExploratoryAnalysis.khSelfOrganizingMapPCAInitialization(
        [[0.0], [1e-200], [2e-200]], width: 3, height: 1)
    #expect(tiny.allSatisfy { $0.allSatisfy(\.isFinite) })
    #expect(abs(tiny[0][0] / 1e-200 + 1) < 1e-12)
    // A positive squared distortion below binary64 range is rejected, never reported as zero.
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.khSelfOrganizingMap([[0], [1e-200]], width: 2, height: 1)
    }
}

@Test("SOM ammette il totale di fasi e buffer, rifiuta parametri incoerenti e cancella")
func khClosureSOMAdmissionAndCancellation() async throws {
    let phase = GlifiKHSOMPhase(steps: 1, initialLearningRate: 0.05, initialRadius: 1)
    for limits in [GlifiExploratoryLimits(maximumCells: 13), .init(maximumWork: 17)] {
        #expect(throws: GlifiFailure.self) {
            try GlifiExploratoryAnalysis.khSelfOrganizingMap(
                [[0], [1]], width: 2, height: 1, firstPhase: phase, secondPhase: phase,
                initialCodebooks: [[0], [1]], limits: limits)
        }
    }
    _ = try GlifiExploratoryAnalysis.khSelfOrganizingMap(
        [[0], [1]], width: 2, height: 1, firstPhase: phase, secondPhase: phase,
        initialCodebooks: [[0], [1]], limits: .init(maximumCells: 14, maximumWork: 18))
    for invalid in [
        GlifiKHSOMPhase(steps: 0, initialLearningRate: 0.05, initialRadius: 1),
        .init(steps: 1, initialLearningRate: .nan, initialRadius: 1),
        .init(steps: 1, initialLearningRate: 0.05, initialRadius: 0),
        .init(steps: 1, initialLearningRate: .leastNonzeroMagnitude, initialRadius: 1),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiExploratoryAnalysis.khSelfOrganizingMap(
                [[0], [1]], width: 2, height: 1, firstPhase: invalid)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.khSelfOrganizingMap(
            [[0], [1]], width: 2, height: 1, initialCodebooks: [[0]])
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiExploratoryAnalysis.khSelfOrganizingMap([[0], [1]], width: 2, height: 1)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    let ordinal = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
            [[0, 1, 1], [1, 0, 2], [1, 2, 0]], ties: .primary)
    }
    await #expect(throws: CancellationError.self) { try await ordinal.value }
}

private func khClosurePairs() -> [GlifiOrdinalPair] {
    zip([(1, 0), (2, 0), (2, 1), (3, 0), (3, 1), (3, 2)], [1.0, 1, 2, 2, 3, 3]).map {
        GlifiOrdinalPair(row: $0.0.0, column: $0.0.1, dissimilarity: $0.1)
    }
}

private func khClosureExpectClose(_ actual: [[Double]], _ expected: [[Double]]) {
    #expect(actual.count == expected.count)
    for (a, b) in zip(actual, expected) {
        #expect(a.count == b.count)
        for (x, y) in zip(a, b) { #expect(abs(x - y) <= 1e-12 * max(1, abs(y))) }
    }
}
