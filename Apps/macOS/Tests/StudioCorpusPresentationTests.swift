// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation
import Testing

@MainActor
struct StudioCorpusPresentationTests {
    @Test(.timeLimit(.minutes(1)))
    func switchingTablesInvalidatesPreviousRowsBeforeFiltering() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = try await makeModel(fixture)
        let output = try #require(model.output)

        let longest = try #require(model.tables.max { $0.rows.count < $1.rows.count })
        let shorter = try #require(
            model.tables.first { !$0.rows.isEmpty && $0.rows.count < longest.rows.count })
        model.tableID = longest.id
        try await waitForCondition {
            model.visibleRows.map(\.id)
                == Array(longest.rows.prefix(StudioCorpusMethodsModel.pageSize)).map(\.id)
                && model.matchingCount == longest.rows.count
        }
        try #require(!model.visibleRows.isEmpty)
        try #require(model.matchingCount > shorter.rows.count)

        // No suspension permits the asynchronous filter to publish between these statements.
        model.tableID = shorter.id

        #expect(model.selectedTable?.id == shorter.id)
        #expect(model.visibleRows.isEmpty)
        #expect(model.matchingCount == 0)
        #expect(model.page == 0)
        #expect(model.isPreparingPresentation)
        model.showPage(0)
        #expect(model.visibleRows.isEmpty)
        #expect(model.page == 0)
        try await waitForCondition { !model.isPreparingPresentation }
        #expect(model.matchingCount == shorter.rows.count)
        #expect(model.visibleRows.map(\.values) == shorter.rows.map(\.values))
        #expect(model.visibleRows.allSatisfy { shorter.rows.indices.contains($0.id) })
        #expect(model.output?.encodedResult == output.encodedResult)
        #expect(model.output?.completedAt == output.completedAt)
        await fixture.session.close()
    }

    @Test(.timeLimit(.minutes(1)))
    func latestAxisTableAndSearchMatchSerialPresentation() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = try await makeModel(fixture)
        let reference = try await makeModel(fixture)
        let output = try #require(model.output)
        let selectedTable = "rowCoordinates"
        try #require(model.tables.contains { $0.id == selectedTable })
        try #require(model.axisCount >= 3)
        let firstAxisRows = try #require(reference.tables.first { $0.id == selectedTable })
            .rows.map(\.values)

        model.axis = 2
        model.search = "no-such-result"
        model.tableID = selectedTable
        model.axis = 3
        model.search = "1"
        model.axis = 0
        model.axis = model.axisCount + 1

        #expect(model.axis == 3)
        #expect(model.isPreparingPresentation)
        #expect(model.visibleRows.isEmpty)
        #expect(model.matchingCount == 0)
        model.showPage(0)
        #expect(model.visibleRows.isEmpty)
        try await waitForCondition { !model.isPreparingPresentation }

        reference.axis = 3
        try await waitForCondition { !reference.isPreparingPresentation }
        let thirdAxisRows = try #require(reference.tables.first { $0.id == selectedTable })
            .rows.map(\.values)
        try #require(firstAxisRows != thirdAxisRows)
        reference.tableID = selectedTable
        try await waitForCondition { !reference.isPreparingPresentation }
        reference.search = "1"
        try await waitForCondition { !reference.isPreparingPresentation }

        #expect(model.axis == 3)
        #expect(model.tableID == selectedTable)
        #expect(model.search == "1")
        #expect(model.matchingCount == reference.matchingCount)
        #expect(model.visibleRows.map(\.id) == reference.visibleRows.map(\.id))
        #expect(model.visibleRows.map(\.values) == reference.visibleRows.map(\.values))
        #expect(
            model.selectedTable?.rows.map(\.values) == reference.selectedTable?.rows.map(\.values))
        #expect(model.output?.encodedResult == output.encodedResult)
        #expect(model.output?.completedAt == output.completedAt)
        await fixture.session.close()
    }

    @Test(.timeLimit(.minutes(1)))
    func resetInvalidatesPendingPresentationAndNewOutputStartsWithDefaultControls() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = try await makeModel(fixture)
        model.axis = 2
        model.search = "no-such-result"
        #expect(model.isPreparingPresentation)

        model.reset()

        #expect(!model.isPreparingPresentation)
        #expect(model.output == nil)
        #expect(model.tables.isEmpty)
        #expect(model.visibleRows.isEmpty)
        #expect(model.matchingCount == 0)
        #expect(model.page == 0)
        #expect(model.axis == 1)
        #expect(model.tableID.isEmpty)
        #expect(model.search.isEmpty)

        model.tool = .correspondence
        model.draft.maximumTerms = 20
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(!model.isPreparingPresentation)
        #expect(model.axis == 1)
        #expect(model.search.isEmpty)
        #expect(model.page == 0)
        #expect(model.tableID == model.tables.first?.id)
        #expect(model.visibleRows.map(\.id) == Array(0..<model.visibleRows.count))
        model.axis = 2
        model.search = "1"
        try await waitForCondition { !model.isPreparingPresentation }
        #expect(model.axis == 2)
        #expect(model.search == "1")
        #expect(model.output?.encodedResult == output.encodedResult)
        await fixture.session.close()
    }

    @Test(.timeLimit(.minutes(1)))
    func paginatesTheCurrentTableAfterSwitchingAwayAndBack() async throws {
        let fixture = try await makeFixture(expandedVocabulary: true)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = try await makeModel(fixture, maximumTerms: 100)
        let output = try #require(model.output)
        let longest = try #require(model.tables.max { $0.rows.count < $1.rows.count })
        let shorter = try #require(
            model.tables.first { !$0.rows.isEmpty && $0.rows.count < longest.rows.count })
        try #require(longest.rows.count > StudioCorpusMethodsModel.pageSize)
        model.tableID = longest.id
        try await waitForCondition { !model.isPreparingPresentation }
        model.showPage(model.pageCount - 1)
        try #require(model.page > 0)

        model.tableID = shorter.id
        #expect(model.isPreparingPresentation)
        #expect(model.page == 0)
        model.showPage(1)
        #expect(model.page == 0)
        #expect(model.visibleRows.isEmpty)
        try await waitForCondition { !model.isPreparingPresentation }
        #expect(model.matchingCount == shorter.rows.count)

        model.tableID = longest.id
        try await waitForCondition { !model.isPreparingPresentation }
        var visited: [Int] = []
        for page in 0..<model.pageCount {
            model.showPage(page)
            visited += model.visibleRows.map(\.id)
            #expect(model.visibleRows.allSatisfy { longest.rows.indices.contains($0.id) })
        }
        #expect(visited == Array(longest.rows.indices))
        let lastPage = model.page
        model.showPage(-1)
        model.showPage(model.pageCount)
        #expect(model.page == lastPage)
        #expect(model.output?.encodedResult == output.encodedResult)
        #expect(model.output?.completedAt == output.completedAt)
        await fixture.session.close()
    }

    private func makeModel(_ fixture: Fixture, maximumTerms: Int = 20) async throws
        -> StudioCorpusMethodsModel
    {
        let model = StudioCorpusMethodsModel()
        model.tool = .correspondence
        model.draft.maximumTerms = maximumTerms
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        return model
    }

    private func waitForCondition(
        _ condition: @escaping @MainActor @Sendable () -> Bool
    ) async throws {
        let waiter = ConditionWaiter(condition: condition)
        try await waiter.wait()
    }

    @MainActor
    private final class ConditionWaiter {
        private let condition: @MainActor @Sendable () -> Bool
        private var continuation: CheckedContinuation<Void, any Error>?

        init(condition: @escaping @MainActor @Sendable () -> Bool) {
            self.condition = condition
        }

        func wait() async throws {
            try Task.checkCancellation()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    observe()
                }
            } onCancel: {
                Task { @MainActor in self.cancel() }
            }
        }

        private func observe() {
            guard continuation != nil else { return }
            let ready = withObservationTracking {
                condition()
            } onChange: { [weak self] in
                Task { @MainActor in self?.observe() }
            }
            if ready {
                let continuation = self.continuation
                self.continuation = nil
                continuation?.resume()
            }
        }

        private func cancel() {
            let continuation = self.continuation
            self.continuation = nil
            continuation?.resume(throwing: CancellationError())
        }
    }

    private struct Fixture {
        let root: URL
        let session: GlifiStudioProjectSession
        let ids: [String]
        let numbers: [String: Int]
    }

    private func makeFixture(expandedVocabulary: Bool = false) async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiCorpusPresentation-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Presentation.glifi"))
        let texts = [
            "casa casa casa mare mare sole alfa.",
            "casa libro libro libro libro vento beta beta.",
            "mare libro luna luna luna luna luna gamma.",
            "sole sole sole sole vento vento luna delta delta.",
        ]
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        for (index, text) in texts.enumerated() {
            let additionalTerms =
                expandedVocabulary
                ? (0..<80).filter { $0 % texts.count == index }.map {
                    "item\(alphabet[$0 / alphabet.count])\(alphabet[$0 % alphabet.count])"
                }.joined(separator: " ") : ""
            let url = root.appending(path: "source-\(index).txt")
            try Data((text + " " + additionalTerms).utf8).write(to: url)
            _ = try await session.importText(at: url, format: .plainText)
        }
        let ids = try await session.snapshot().sources.map(\.sourceRevisionID).sorted()
        return Fixture(
            root: root, session: session, ids: ids,
            numbers: Dictionary(
                uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset + 1) }))
    }
}
