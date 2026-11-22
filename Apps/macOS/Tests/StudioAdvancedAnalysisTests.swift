// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioAdvancedAnalysisTests {
    @Test(arguments: StudioAdvancedTool.allCases)
    func executesEveryProjectDrivenOperator(tool: StudioAdvancedTool) async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let model = configuredModel(tool: tool, ids: fixture.ids)

        try await model.execute(
            session: fixture.session, sourceRevisionIDs: Array(fixture.ids.reversed()),
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))

        let output = try #require(model.output)
        #expect(output.tool == tool)
        #expect(output.input.projectID == before.projectID)
        #expect(output.input.sourceRevisionIDs == fixture.ids.sorted())
        #expect(
            output.sourceNumbers == output.input.sourceRevisionIDs.map { fixture.numbers[$0] ?? 0 })
        #expect(output.rows.allSatisfy { $0.values.count == output.columns.count })
        #expect(output.rows.compactMap(\.sourceRevisionID).allSatisfy { fixture.ids.contains($0) })
        #expect(model.visibleRows.count <= StudioAdvancedAnalysisModel.pageSize)
        #expect(model.matchingRowCount == output.rows.count)
        #expect(
            try GlifiStudioTextAnalysisRequest.decode(output.canonicalRequest) == output.request)
        #expect(
            output.validationStatus
                == GlifiStudioTextAnalytics.validationStatus(forMethod: output.methodIdentifier))
        let json = try #require(
            JSONSerialization.jsonObject(with: output.encodedResult) as? [String: Any])
        #expect(json["requestDigest"] as? String == output.requestDigest)
        #expect(json["methodIdentifier"] as? String == output.methodIdentifier)
        #expect(try await fixture.session.snapshot() == before)

        if tool == .classification {
            let prediction = Set(fixture.ids.suffix(2))
            #expect(Set(output.rows.compactMap(\.sourceRevisionID)) == prediction)
            let captured = output.sourceLabels
            model.labels = [:]
            #expect(model.output?.sourceLabels == captured)
        }
        if tool.needsRules {
            #expect(output.codingRules == "*Mare\nmare")
            model.rules = "*Casa\ncasa"
            #expect(model.output?.codingRules == "*Mare\nmare")
        }
        await fixture.session.close()
    }

    @Test func paginatesFiltersAndPreservesTheCompleteResult() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(tool: .distances, ids: fixture.ids)
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(output.rows.count == 91)
        #expect(model.pageCount == 2)
        let first = model.visibleRows.map(\.id)
        model.showPage(1)
        #expect(first + model.visibleRows.map(\.id) == output.rows.map(\.id))
        let previous = model.visibleRows.map(\.id)
        model.showPage(2)
        model.showPage(-1)
        #expect(model.page == 1)
        #expect(model.visibleRows.map(\.id) == previous)

        model.search = "no-matching-row"
        for _ in 0..<100 where model.matchingRowCount != 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.matchingRowCount == 0)
        #expect(model.visibleRows.isEmpty)
        #expect(model.output?.rows.count == 91)
        model.search = ""
        for _ in 0..<100 where model.matchingRowCount != 91 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.matchingRowCount == 91)
        #expect(model.page == 0)
        #expect(model.visibleRows.map(\.id) == first)
        await fixture.session.close()
    }

    @Test func retainsPreviousOutputOnFailureAndCancellationThenResetsProjectData() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(tool: .topics, ids: fixture.ids)
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let previous = try #require(model.output)
        model.topicCount = 0
        do {
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
            Issue.record("Invalid topic count should fail")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.retainedState == "unchanged")
        }
        #expect(model.output?.requestDigest == previous.requestDigest)
        model.topicCount = 2
        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        do {
            try await cancelled.value
            Issue.record("Cancelled analysis should fail")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(model.output?.requestDigest == previous.requestDigest)
        model.rules = "*PrivateCode\nmare"
        model.search = "mare"
        model.reset()
        #expect(model.output == nil)
        #expect(model.labels.isEmpty)
        #expect(model.rules.isEmpty)
        #expect(model.search.isEmpty)
        #expect(model.visibleRows.isEmpty)
        #expect(model.matchingRowCount == 0)
        await fixture.session.close()
    }

    @Test func resetDuringImmediateExecutionPreventsPublicationAndAllowsRetry() async throws {
        let fixture = try await makeFixture(sourceCount: 2)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let model = configuredModel(tool: .distances, ids: fixture.ids)
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        _ = try #require(model.output)
        var entered = false
        let execution = Task.immediate { @MainActor in
            entered = true
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        #expect(entered)
        #expect(!execution.isCancelled)
        model.reset()
        do {
            try await execution.value
            Issue.record("An execution invalidated by reset must not publish its output")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "newRequest")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(!execution.isCancelled)
        #expect(model.output == nil)
        #expect(model.visibleRows.isEmpty)
        #expect(model.matchingRowCount == 0)
        #expect(model.page == 0)
        #expect(model.labels.isEmpty)
        #expect(model.rules.isEmpty)
        #expect(model.search.isEmpty)

        model.maximumTerms = 2
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let retried = try #require(model.output)
        #expect(retried.input.sourceRevisionIDs == fixture.ids.sorted())
        #expect(retried.input.terms.count == 2)
        #expect(!model.visibleRows.isEmpty)
        #expect(try await fixture.session.snapshot() == before)
        await fixture.session.close()
    }

    private func configuredModel(tool: StudioAdvancedTool, ids: [String])
        -> StudioAdvancedAnalysisModel
    {
        let model = StudioAdvancedAnalysisModel()
        model.tool = tool
        model.seed = 17
        model.maximumTerms = 100
        model.maximumIterations = 40
        model.gridWidth = 2
        model.gridHeight = 2
        model.epochs = 5
        model.sampleSize = 8
        model.burnIn = 5
        model.posteriorSamples = 2
        model.thinning = 1
        model.topicTermsShown = 5
        model.rules = "*Mare\nmare"
        for (index, id) in ids.enumerated() {
            if tool == .classification && index >= ids.count - 2 { continue }
            model.labels[id] = index.isMultiple(of: 2) ? "A" : "B"
        }
        return model
    }

    private func makeFixture(sourceCount: Int = 14) async throws -> (
        root: URL, session: GlifiStudioProjectSession, ids: [String], numbers: [String: Int]
    ) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiAdvancedClient-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Client.glifi", directoryHint: .isDirectory))
        for index in 0..<sourceCount {
            let url = root.appending(path: "source-\(index).txt")
            let text =
                String(repeating: "mare ", count: index + 1) + "casa sole luna documento \(index)."
            try Data(text.utf8).write(to: url)
            _ = try await session.importText(at: url, format: .plainText)
        }
        let snapshot = try await session.snapshot()
        let ids = snapshot.sources.map(\.sourceRevisionID)
        return (
            root, session, ids,
            Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0 + 1) })
        )
    }
}
