// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioStatisticsTests {
    @Test(arguments: GlifiStudioStatisticsOperation.allCases)
    func executesEveryMethodAndRetainsTheCapturedDraft(operation: GlifiStudioStatisticsOperation)
        async throws
    {
        let model = StudioStatisticsModel()
        model.select(operation)
        model.loadSyntheticExample()
        try await model.execute()
        let result = try #require(model.result)
        #expect(result.request.operation == operation)
        #expect(model.pane == .results)
        #expect(model.visibleRows.count <= StudioStatisticsModel.pageSize)
        #expect(!model.isDraftChanged)
        model.input = "a different draft"
        model.parameters.seed = 999
        #expect(model.isDraftChanged)
        #expect(model.result == result)
        let direct = try await GlifiStudioStatisticsWorkbench.evaluate(result.request)
        #expect(direct == result)
        let encoded = try await StudioStatisticsModel.exportData(for: result)
        #expect(try JSONDecoder().decode(GlifiStudioStatisticsResult.self, from: encoded) == result)
    }

    @Test func preservesPreviousResultsOnInvalidInputAndCancellationThenClearsProjectData()
        async throws
    {
        let model = StudioStatisticsModel()
        model.loadSyntheticExample()
        try await model.execute()
        let result = try #require(model.result)
        model.input = "NaN"
        await #expect(throws: GlifiStudioFailure.self) { try await model.execute() }
        #expect(model.result == result)
        model.loadSyntheticExample()
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await model.execute()
        }
        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch let failure as GlifiStudioFailure { #expect(failure.category == "cancelled") }
        #expect(model.result == result)
        model.reset()
        #expect(model.result == nil)
        #expect(model.input.isEmpty)
        #expect(model.operation == .descriptive)
        #expect(!model.isDraftChanged)
    }

    @Test func visitsEveryAdjustedProbabilityWithoutRecomputingAndFiltersTheCapturedTable()
        async throws
    {
        let model = StudioStatisticsModel()
        model.select(.bonferroni)
        model.input = (1...120).map { String(Double($0) / 10_000) }.joined(separator: " ")
        try await model.execute()
        let result = try #require(model.result)
        #expect(model.pageCount == 3)
        #expect(model.inputPageCount == 3)
        var seen: [Int] = []
        for page in 0..<model.pageCount {
            model.showPage(page)
            seen += model.visibleRows.map(\.id)
        }
        #expect(seen == Array(result.rows.indices))
        var seenInputs: [Int] = []
        for page in 0..<model.inputPageCount {
            model.showInputPage(page)
            seenInputs += model.visibleInputRows.map(\.id)
        }
        #expect(seenInputs == Array(0..<120))
        model.showInputPage(3)
        #expect(model.inputPage == 2)
        model.showPage(3)
        #expect(model.page == 2)
        model.search = "no-such-row"
        for _ in 0..<100 where model.matchingRowCount != 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.visibleRows.isEmpty)
        #expect(model.result == result)
        model.search = ""
        for _ in 0..<100 where model.matchingRowCount != 120 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.matchingRowCount == 120)
        #expect(model.visibleRows.map(\.id) == Array(0..<50))
    }

    @Test func identifiesEveryDraftChangeWhileKeepingTheCapturedResult() async throws {
        let model = StudioStatisticsModel()
        model.loadSyntheticExample()
        try await model.execute()
        let result = try #require(model.result)
        let input = model.input
        model.input += " 20"
        #expect(model.isDraftChanged)
        model.input = input
        #expect(!model.isDraftChanged)
        let parameters = model.parameters
        model.parameters.confidenceLevel = 0.9
        #expect(model.isDraftChanged)
        model.parameters = parameters
        #expect(!model.isDraftChanged)
        let probabilities = model.probabilitiesDraft
        model.probabilitiesDraft = "0,1 0,9"
        #expect(model.isDraftChanged)
        model.probabilitiesDraft = probabilities
        #expect(!model.isDraftChanged)
        let contrasts = model.contrastsDraft
        model.contrastsDraft = "1 -1"
        #expect(model.isDraftChanged)
        model.contrastsDraft = contrasts
        #expect(!model.isDraftChanged)
        model.select(.anova)
        #expect(model.isDraftChanged)
        model.select(.descriptive)
        #expect(!model.isDraftChanged)
        #expect(model.result == result)
    }
}
