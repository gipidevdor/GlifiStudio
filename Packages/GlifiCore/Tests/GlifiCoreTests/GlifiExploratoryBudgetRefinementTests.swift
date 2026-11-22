// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("Secondary ordinal MDS admits its pair sort and simultaneous working storage")
func khRefinementOrdinalSecondaryBudgets() throws {
    let distances = khRefinementBudgetDistances()
    for limits in [
        GlifiExploratoryLimits(maximumCells: 16),
        GlifiExploratoryLimits(maximumWork: 16),
    ] {
        try khRefinementExpectResourceLimit {
            _ = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
                distances, dimensions: 1, seed: 17, maximumIterations: 1,
                limits: limits, initialization: .random, ties: .secondary)
        }
    }
}

@Test("Secondary multistart reserves run storage together with the active MDS workspace")
func khRefinementOrdinalSecondarySearchBudgets() throws {
    let distances = khRefinementBudgetDistances()
    for limits in [
        GlifiExploratoryLimits(maximumCells: 20),
        GlifiExploratoryLimits(maximumWork: 48),
    ] {
        try khRefinementExpectResourceLimit {
            _ = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
                distances, dimensions: 1, starts: 3, seed: 17, maximumIterations: 1,
                limits: limits, ordinalTies: .secondary)
        }
    }
}

@Test("Kruskal reserves repeated disparity sorts and every permitted backtracking candidate")
func khRefinementKruskalBacktrackingBudgets() throws {
    let distances = khRefinementBudgetDistances()
    try khRefinementExpectResourceLimit {
        _ = try GlifiExploratoryAnalysis.multidimensionalScaling(
            distances, dimensions: 1, method: .kruskal, maximumIterations: 1,
            limits: .init(maximumWork: 100), initialization: .random)
    }
    try khRefinementExpectResourceLimit {
        _ = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
            distances, dimensions: 1, method: .kruskal, starts: 3, maximumIterations: 1,
            limits: .init(maximumWork: 1_000))
    }
}

@Test("Sufficient MDS budgets preserve the complete seeded result and earliest minimum")
func khRefinementOrdinalSufficientBudgetParity() throws {
    let distances = khRefinementBudgetDistances()
    let result = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
        distances, dimensions: 1, starts: 3, seed: .max, maximumIterations: 4,
        ordinalTies: .secondary)
    let explicit = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
        distances, dimensions: 1, starts: 3, seed: .max, maximumIterations: 4,
        limits: .init(maximumCells: 1_000_000, maximumWork: 1_000_000),
        ordinalTies: .secondary)
    #expect(result == explicit)
    #expect(result.runs.map(\.seed) == [.max, 0, 1])
    let minimum = try #require(result.runs.map(\.stress).min())
    #expect(result.chosenRun == result.runs.firstIndex { $0.stress == minimum })
}

private func khRefinementBudgetDistances() -> [[Double]] {
    [[0, 1, 1, 3], [1, 0, 2, 3], [1, 2, 0, 2], [3, 3, 2, 0]]
}

private func khRefinementExpectResourceLimit(_ body: () throws -> Void) throws {
    do {
        try body()
        Issue.record("The complete exploratory workload exceeded its explicit resource budget")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "exploratory.resource-limit")
        #expect(failure.category == .insufficientResources)
        #expect(failure.retainedState == .unchanged)
    }
}
