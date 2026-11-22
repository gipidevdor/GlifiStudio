// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioCorpusMethodsTests {
    @Test func contrastEditorAcceptsOneDecimalConventionAndRejectsMixedInput() throws {
        var draft = StudioCorpusMethodsDraft()
        draft.contrasts = "0,5; 0,5; -1\n1 0 -1"
        #expect(try draft.comparisonOptions().contrasts == [[0.5, 0.5, -1], [1, 0, -1]])
        draft.contrasts = "0.5 0.5 -1"
        #expect(try draft.comparisonOptions().contrasts == [[0.5, 0.5, -1]])
        draft.contrasts = "0,5 0.5 -1"
        #expect(throws: GlifiStudioFailure.self) { try draft.comparisonOptions() }
        draft.contrasts = "nan 0 -1"
        #expect(throws: GlifiStudioFailure.self) { try draft.comparisonOptions() }
    }

    @Test(arguments: StudioCorpusMethod.allCases)
    func executesEveryPersistedCorpusMethod(method: StudioCorpusMethod) async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(method, ids: fixture.ids)
        let before = try await fixture.session.snapshot()
        let snapshot = try await model.execute(
            session: fixture.session, sourceRevisionIDs: Array(fixture.ids.reversed()),
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(output.tool == method)
        #expect(output.eligibleSourceRevisionIDs == fixture.ids.sorted())
        if method != .similarity { #expect(output.sourceRevisionIDs == fixture.ids.sorted()) }
        #expect(snapshot.projectID == before.projectID)
        #expect(snapshot.generation >= before.generation)
        #expect(snapshot.artifactCount > before.artifactCount)
        #expect(!model.summary.isEmpty || !model.tables.isEmpty)
        #expect(
            model.tables.allSatisfy { table in
                table.rows.allSatisfy { $0.values.count == table.columns.count }
            })
        #expect(
            model.tables.flatMap(\.rows).compactMap(\.sourceRevisionID).allSatisfy {
                fixture.ids.contains($0)
            })
        #expect(model.visibleRows.count <= StudioCorpusMethodsModel.pageSize)
        let json = try #require(
            JSONSerialization.jsonObject(with: output.encodedResult) as? [String: Any])
        if method == .similarity {
            #expect(json["projectID"] as? String == snapshot.projectID)
            #expect(json["targetSourceRevisionIDs"] as? [String] == output.groups.first)
            #expect(
                json["referenceSourceRevisionIDs"] as? [String] == output.groups.dropFirst().first)
        } else {
            let lineage = try #require(json["lineage"] as? [String: Any])
            #expect(lineage["projectID"] as? String == snapshot.projectID)
            #expect(lineage["generation"] as? Int == snapshot.generation)
        }
        let captured = output.draft
        model.draft.maximumTerms = 2
        model.draft.groupLabels = [:]
        #expect(model.output?.draft == captured)
        await fixture.session.close()
    }

    @Test func reusesTheKitArtifactAndPreservesTheOutputOnInvalidInput() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(.correspondence, ids: fixture.ids)
        let snapshot = try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "en"))
        let previous = try #require(model.output)
        guard case let .multivariate(result) = previous.payload else {
            Issue.record("Expected a multivariate result")
            return
        }
        let direct = try await fixture.session.analyzeMultivariate(
            sourceRevisionIDs: fixture.ids, method: .correspondence,
            maximumTermCount: previous.draft.maximumTerms,
            corpusOptions: previous.draft.corpusOptions())
        #expect(direct.lineage.artifactID == result.lineage.artifactID)
        #expect(direct.rowCoordinates == result.rowCoordinates)
        #expect(direct.axisValues == result.axisValues)
        #expect(direct.termSelectionIdentifier != nil)
        #expect(direct.corpusDigest != nil)
        #expect(try await fixture.session.snapshot().generation == snapshot.generation)
        model.draft.maximumTerms = 0
        do {
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "en"))
            Issue.record("An invalid term limit must fail")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "invalidInput")
        }
        #expect(model.output?.encodedResult == previous.encodedResult)
        #expect(model.output?.completedAt == previous.completedAt)
        await fixture.session.close()
    }

    @Test func pagesFiltersAndResetsTheProjectDraft() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(.windowCollocations, ids: fixture.ids)
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        let table = try #require(model.tables.first { $0.id == "pairs" })
        model.tableID = table.id
        for _ in 0..<100 where model.matchingCount != table.rows.count {
            try await Task.sleep(for: .milliseconds(10))
        }
        var ids: [Int] = []
        for page in 0..<model.pageCount {
            model.showPage(page)
            ids += model.visibleRows.map(\.id)
        }
        #expect(ids == table.rows.map(\.id))
        let previousPage = model.page
        model.showPage(-1)
        model.showPage(model.pageCount)
        #expect(model.page == previousPage)
        model.search = "zz-no-result-zz"
        for _ in 0..<100 where model.matchingCount != 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.matchingCount == 0)
        #expect(model.visibleRows.isEmpty)
        #expect(model.output?.encodedResult == output.encodedResult)
        model.reset()
        #expect(model.output == nil)
        #expect(model.tables.isEmpty)
        #expect(model.draft == StudioCorpusMethodsDraft())
        await fixture.session.close()
    }

    @Test func preCancelledWorkAndMissingGroupAssignmentsNeverReplaceThePreviousResult()
        async throws
    {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(.dispersion, ids: fixture.ids)
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let previous = try #require(model.output)
        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        do {
            _ = try await cancelled.value
            Issue.record("Cancellation must propagate")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
        }
        #expect(model.output?.encodedResult == previous.encodedResult)
        model.draft.tool = .groupMetrics
        model.draft.groupLabels = [:]
        do {
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
            Issue.record("Missing group assignments must fail")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "invalidInput")
        }
        #expect(model.output?.encodedResult == previous.encodedResult)
        await fixture.session.close()
    }

    @Test func multivariatePresentationDecodesJSONWrittenBeforeTheAdditiveFields() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let result = try await fixture.session.analyzeMultivariate(
            sourceRevisionIDs: fixture.ids,
            method: .hierarchical(linkage: "average", clusterCount: 2), maximumTermCount: 20)
        #expect(result.averageSilhouette != nil)
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        json.removeValue(forKey: "averageSilhouette")
        json.removeValue(forKey: "termSelectionIdentifier")
        json.removeValue(forKey: "corpusDigest")
        let legacy = try JSONDecoder().decode(
            GlifiStudioMultivariateResult.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.averageSilhouette == nil)
        #expect(legacy.termSelectionIdentifier == nil)
        #expect(legacy.corpusDigest == nil)
        #expect(legacy.rowCoordinates == result.rowCoordinates)
        #expect(legacy.clusterAssignments == result.clusterAssignments)
        await fixture.session.close()
    }

    @Test func resetDuringAnExecutionDoesNotRestoreThePreviousProject() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(.association, ids: fixture.ids)
        var started = false
        let execution = Task { @MainActor in
            started = true
            return try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        while !started { await Task.yield() }
        model.reset()
        do {
            _ = try await execution.value
            Issue.record("An execution invalidated by reset must be cancelled")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
        }
        #expect(model.output == nil)
        #expect(model.tables.isEmpty)
        #expect(model.draft == StudioCorpusMethodsDraft())
        await fixture.session.close()
    }

    @Test func resetDuringImmediateExecutionPreventsPublicationAndAllowsRetry() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(.association, ids: fixture.ids)
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        _ = try #require(model.output)
        let retryDraft = model.draft
        var entered = false
        let execution = Task.immediate { @MainActor in
            entered = true
            return try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        #expect(entered)
        #expect(!execution.isCancelled)
        model.reset()
        do {
            _ = try await execution.value
            Issue.record("A corpus analysis invalidated by reset must not publish")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "newRequest")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(!execution.isCancelled)
        #expect(model.output == nil)
        #expect(model.tables.isEmpty)
        #expect(model.visibleRows.isEmpty)
        #expect(model.summary.isEmpty)
        #expect(model.methodDetails.isEmpty)
        #expect(model.matchingCount == 0)
        #expect(model.page == 0)
        #expect(model.draft == StudioCorpusMethodsDraft())

        model.draft = retryDraft
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        #expect(model.output != nil)
        #expect(!model.tables.isEmpty)
        await fixture.session.close()
    }

    private func configuredModel(_ tool: StudioCorpusMethod, ids: [String])
        -> StudioCorpusMethodsModel
    {
        let model = StudioCorpusMethodsModel()
        model.tool = tool
        model.draft.maximumTerms = 20
        model.draft.maximumPairs = 1_000
        model.draft.bootstrapResamples = 99
        model.draft.permutationCount = 99
        model.draft.rank = 2
        model.draft.clusterCount = 2
        model.draft.restarts = 2
        model.draft.secondTerm = "mare"
        for (index, id) in ids.enumerated() {
            model.draft.groupLabels[id] = index < 3 ? "A" : (index < 6 ? "B" : "C")
        }
        return model
    }

    private struct Fixture {
        let root: URL
        let session: GlifiStudioProjectSession
        let ids: [String]
        let numbers: [String: Int]
    }

    private func makeFixture() async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiCorpusMethodsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Methods.glifi"))
        let identifiers = [
            "alfa", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota",
        ]
        for index in identifiers.indices {
            let region = index < 3 ? "mare" : (index < 6 ? "casa" : "libro")
            let tokens =
                ["lingua", "testo", "parola", identifiers[index]]
                + Array(repeating: region, count: index + 2)
                + Array(repeating: "mare", count: (index % 3) + 1)
            let url = root.appending(path: "source-\(index).txt")
            try Data((tokens.joined(separator: " ") + ". La ricerca confronta le fonti.").utf8)
                .write(to: url)
            _ = try await session.importText(at: url, format: .plainText)
        }
        let ids = try await session.snapshot().sources.map(\.sourceRevisionID).sorted()
        return Fixture(
            root: root, session: session, ids: ids,
            numbers: Dictionary(
                uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset + 1) }))
    }
}
