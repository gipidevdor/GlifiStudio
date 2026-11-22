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
        let model = StudioCorpusMethodsModel()
        model.tool = .correspondence
        model.draft.maximumTerms = 20
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))

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
        await fixture.session.close()
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
            } onChange: {
                Task { @MainActor in self.observe() }
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

    private func makeFixture() async throws -> Fixture {
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
        for (index, text) in texts.enumerated() {
            let url = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            _ = try await session.importText(at: url, format: .plainText)
        }
        let ids = try await session.snapshot().sources.map(\.sourceRevisionID).sorted()
        return Fixture(
            root: root, session: session, ids: ids,
            numbers: Dictionary(
                uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset + 1) }))
    }
}
