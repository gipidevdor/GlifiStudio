// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation
import Testing

@MainActor
struct StudioStatisticsTests {
    private final class BundleAnchor {}

    @Test(.timeLimit(.minutes(1)))
    func findsTheItalianValueShownByTheResultTable() async throws {
        let model = StudioStatisticsModel()
        await model.updatePresentationLocale(Locale(identifier: "it_IT"))
        model.select(.bonferroni)
        model.input = "0,01 0,04"
        try await model.execute()
        let result = try #require(model.result)
        #expect(result.rows[0] == [.integer(1), .number(0.01), .number(0.02)])

        await afterVisibleRowsChange(model) { model.search = "0,02" }

        #expect(model.matchingRowCount == 1)
        #expect(model.visibleRows.map(\.id) == [0])
        #expect(model.result == result)
        #expect(!model.isDraftChanged)
    }

    @Test(arguments: ["it_IT", "en_US"])
    func findsDisplayedAndCanonicalCellsWithoutChangingTheirScientificValues(identifier: String)
        async throws
    {
        let locale = Locale(identifier: identifier)
        let bundle = Bundle(for: BundleAnchor.self)
        let italian = identifier == "it_IT"
        let rows: [[GlifiStudioStatisticsValue]] = [
            [.number(12_345.5)], [.number(0.0000000123)], [.integer(1_234_567)],
            [.positiveInfinity], [.negativeInfinity], [.undefined], [.text("Caffè sintetico")],
        ]
        let displayed = [
            italian ? "12.345,5" : "12,345.5", italian ? "1,23E-8" : "1.23E-8",
            italian ? "1.234.567" : "1,234,567", "+∞", "−∞",
            italian ? "Non definito" : "Undefined", "Caffè sintetico",
        ]
        for (index, expected) in displayed.enumerated() {
            #expect(
                StudioStatisticsPresentation.formatted(
                    rows[index][0], locale: locale, bundle: bundle) == expected)
            let matches = await StudioStatisticsPresentation.filteredRows(
                rows, query: expected, locale: locale, bundle: bundle)
            #expect(matches == [index])
        }
        for (query, expected) in [
            ("12345.5", [0]), ("1.23e-08", [1]), ("1234567", [2]),
            ("+Infinity", [3]), ("-Infinity", [4]), ("?", [5]), ("CAFFE", [6]), ("∞", [3, 4]),
        ] {
            let matches = await StudioStatisticsPresentation.filteredRows(
                rows, query: query, locale: locale, bundle: bundle)
            #expect(matches == expected)
        }

        let model = StudioStatisticsModel(bundle: bundle)
        await model.updatePresentationLocale(locale)
        model.select(.bonferroni)
        model.input = "0.0000000123 0.01 0.04"
        try await model.execute()
        let result = try #require(model.result)
        let exported = try await StudioStatisticsModel.exportData(for: result)
        for (query, expected) in [
            (italian ? "3,69E-8" : "3.69E-8", [0]),
            (italian ? "0,03" : "0.03", [1]), ("0.03", [1]),
        ] {
            model.search = query
            await model.updatePresentationLocale(locale)
            #expect(model.matchingRowCount == expected.count)
            #expect(model.visibleRows.map(\.id) == expected)
        }
        #expect(model.result == result)
        #expect(!model.isDraftChanged)
        #expect(try await StudioStatisticsModel.exportData(for: result) == exported)
    }

    @Test(arguments: ["it_IT", "en_US"])
    func findsUndefinedResultRowsInTheSelectedLocale(identifier: String) async throws {
        let locale = Locale(identifier: identifier)
        let model = StudioStatisticsModel(bundle: Bundle(for: BundleAnchor.self))
        await model.updatePresentationLocale(locale)
        model.select(.contingency)
        model.input = "20 10 0\n10 20 0\n0 0 0"
        try await model.execute()
        let result = try #require(model.result)
        #expect(result.rows.count == 9)
        for query in [identifier == "it_IT" ? "Non definito" : "Undefined", "?"] {
            model.search = query
            await model.updatePresentationLocale(locale)
            #expect(model.matchingRowCount == 5)
            #expect(model.visibleRows.map(\.id) == [2, 5, 6, 7, 8])
        }
        #expect(model.result == result)
    }

    @Test func localeChangesAndNewSearchesSupersedePendingFilters() async throws {
        let italian = Locale(identifier: "it_IT")
        let english = Locale(identifier: "en_US")
        let model = StudioStatisticsModel()
        await model.updatePresentationLocale(italian)
        model.select(.bonferroni)
        model.input = "0.01 0.04"
        try await model.execute()
        let result = try #require(model.result)

        model.search = "0,02"
        await model.updatePresentationLocale(italian)
        #expect(model.visibleRows.map(\.id) == [0])
        await model.updatePresentationLocale(english)
        #expect(model.matchingRowCount == 0)
        #expect(model.visibleRows.isEmpty)
        await model.updatePresentationLocale(italian)
        #expect(model.visibleRows.map(\.id) == [0])

        model.search = "0,02"
        let previousLocale = Task.immediate { @MainActor in
            await model.updatePresentationLocale(italian)
        }
        await model.updatePresentationLocale(english)
        await previousLocale.value
        #expect(model.matchingRowCount == 0)
        #expect(model.visibleRows.isEmpty)

        model.search = "0.02"
        let previousSearch = Task.immediate { @MainActor in
            await model.updatePresentationLocale(english)
        }
        model.search = "no-matching-cell"
        await model.updatePresentationLocale(english)
        await previousSearch.value
        #expect(model.matchingRowCount == 0)
        #expect(model.visibleRows.isEmpty)
        #expect(model.result == result)
        model.search = ""
        #expect(model.matchingRowCount == 2)
        #expect(model.visibleRows.map(\.id) == [0, 1])
    }

    @Test func resetRejectsPendingLocalizedFilterAndRetryUsesTheCurrentLocale() async throws {
        let italian = Locale(identifier: "it_IT")
        let model = StudioStatisticsModel()
        await model.updatePresentationLocale(italian)
        model.select(.bonferroni)
        model.input = "0.01 0.04"
        try await model.execute()
        model.search = "0,02"
        let pending = Task.immediate { @MainActor in
            await model.updatePresentationLocale(italian)
        }
        model.reset()
        await pending.value
        #expect(model.result == nil)
        #expect(model.visibleRows.isEmpty)
        #expect(model.matchingRowCount == 0)
        #expect(model.page == 0)
        #expect(model.search.isEmpty)
        #expect(!model.isDraftChanged)

        model.select(.bonferroni)
        model.input = "0.03 0.2"
        try await model.execute()
        let result = try #require(model.result)
        model.search = "0,06"
        await model.updatePresentationLocale(italian)
        #expect(model.visibleRows.map(\.id) == [0])
        #expect(model.matchingRowCount == 1)
        #expect(model.result == result)
    }

    @Test func cancelledLocaleChangeDoesNotOverrideTheActivePresentation() async throws {
        let italian = Locale(identifier: "it_IT")
        let english = Locale(identifier: "en_US")
        let model = StudioStatisticsModel()
        await model.updatePresentationLocale(english)
        model.select(.bonferroni)
        model.input = "0.01 0.04"
        try await model.execute()
        let result = try #require(model.result)
        model.search = "0,02"
        await model.updatePresentationLocale(english)
        #expect(model.matchingRowCount == 0)

        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await model.updatePresentationLocale(italian)
        }
        await cancelled.value
        #expect(model.matchingRowCount == 0)
        #expect(model.visibleRows.isEmpty)
        #expect(model.search == "0,02")
        #expect(model.result == result)

        await model.updatePresentationLocale(italian)
        #expect(model.visibleRows.map(\.id) == [0])
        #expect(model.matchingRowCount == 1)
    }

    @Test func cancelledPresentationWorkDoesNotReturnMatchingIndices() async {
        let filtering = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await StudioStatisticsPresentation.filteredRows(
                [[.number(0.02)]], query: "0,02", locale: Locale(identifier: "it_IT"))
        }
        #expect(await filtering.value.isEmpty)
    }

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

    @Test func immediateResetRejectsPublicationAndRetryCapturesOnlyTheNewInput() async throws {
        let model = StudioStatisticsModel()
        model.loadSyntheticExample()
        try await model.execute()
        _ = try #require(model.result)
        var entered = false
        let execution = Task.immediate { @MainActor in
            entered = true
            try await model.execute()
        }
        #expect(entered && !execution.isCancelled)
        model.reset()
        do {
            try await execution.value
            Issue.record("A statistical result published after reset")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "newRequest")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(!execution.isCancelled)
        #expect(model.result == nil && model.visibleRows.isEmpty)
        #expect(model.capturedInputRows.isEmpty && model.visibleInputRows.isEmpty)
        #expect(model.matchingRowCount == 0 && model.page == 0 && model.inputPage == 0)
        #expect(model.pane == .configuration && !model.isDraftChanged)
        model.input = "1 2 3"
        try await model.execute()
        let result = try #require(model.result)
        #expect(result.request.values == [[1, 2, 3]])
        #expect(model.capturedInputRows.count == 3)
        #expect(model.pane == .results && !model.isDraftChanged)
        #expect(result == (try await GlifiStudioStatisticsWorkbench.evaluate(result.request)))
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

    private func afterVisibleRowsChange(
        _ model: StudioStatisticsModel, mutation: @MainActor () -> Void
    ) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = model.visibleRows
            } onChange: {
                Task { @MainActor in continuation.resume() }
            }
            mutation()
        }
    }
}
