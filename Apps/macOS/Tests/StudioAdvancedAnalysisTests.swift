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

    @Test func completionTablesRetainEveryRunPrototypeAndFold() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        for tool in [StudioAdvancedTool.mdsSearch, .somAdvanced, .topicSelection] {
            let model = configuredModel(tool: tool, ids: fixture.ids)
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
            let output = try #require(model.output)
            #expect(output.tables.count > 1)
            #expect(
                output.tables.allSatisfy { table in
                    table.rows.allSatisfy { $0.values.count == table.columns.count }
                })
            for index in output.tables.indices {
                model.tableIndex = index
                let table = output.tables[index]
                #expect(model.matchingRowCount == table.rows.count)
                var seen: [Int] = []
                for page in 0..<model.pageCount {
                    model.showPage(page)
                    seen += model.visibleRows.map(\.id)
                }
                #expect(seen == Array(table.rows.indices))
                #expect(model.output?.requestDigest == output.requestDigest)
            }
            let json = try #require(
                JSONSerialization.jsonObject(with: output.encodedResult) as? [String: Any])
            let result = try #require(json["result"] as? [String: Any])
            switch tool {
            case .mdsSearch:
                let runs = try #require(result["runs"] as? [[String: Any]])
                #expect(runs.count == 3)
                #expect(
                    output.tables.first { $0.id == "advanced.table.mds-all-coordinates" }?.rows
                        .count == 3 * fixture.ids.count)
                #expect(
                    output.tables.first { $0.id == "advanced.table.mds-runs" }?.rows.count
                        == runs.count)
            case .somAdvanced:
                #expect(result["topology"] as? String == "hexagonal")
                #expect(result["codebookClustering"] is [String: Any])
                #expect(
                    output.tables.first { $0.id == "advanced.table.som-u-matrix" }?.rows.count == 4)
                #expect(output.tables.first { $0.id == "advanced.table.som-ward" }?.rows.count == 3)
            case .topicSelection:
                let candidates = try #require(result["candidates"] as? [[String: Any]])
                #expect(candidates.count == 2)
                #expect(
                    output.tables.first { $0.id == "advanced.table.lda-candidates" }?.rows.count
                        == candidates.count * 6)
                #expect(
                    output.tables.first { $0.id == "advanced.table.lda-fold-assignments" }?.rows
                        .count == fixture.ids.count)
                #expect(
                    output.tables.first { $0.id == "advanced.table.lda-held-out" }?.rows.count
                        == candidates.count * 2)
            case .mds, .som, .clara, .topics, .classification, .classifierValidation, .coding,
                .codeCrosstab, .distances, .correspondence, .hierarchical, .network:
                Issue.record("Unexpected completion tool")
            }
        }
        await fixture.session.close()
    }

    @Test(arguments: [GlifiStudioSOMTopology.rectangular, .hexagonal], [false, true])
    func advancedSOMRetainsGeometryAndOptionalWardWithoutChangingTheProject(
        topology: GlifiStudioSOMTopology, usesWard: Bool
    ) async throws {
        let fixture = try await makeFixture(sourceCount: 6)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let model = configuredModel(tool: .somAdvanced, ids: fixture.ids)
        model.somTopology = topology
        model.gridWidth = 2
        model.gridHeight = 3
        model.clustersSOMCodebooks = usesWard
        model.somCodebookClusterCount = 2
        model.somInitialRadius = 1.5
        model.somFinalRadius = 0.2
        model.somTolerance = 1e-7
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        guard
            case let .advanced(
                .somAdvanced(
                    _, width, height, seed, epochs, geometry, initial, final, tolerance, clusters)) =
                output.request
        else {
            Issue.record("Expected an advanced SOM request")
            return
        }
        #expect(width == 2 && height == 3 && seed == 17 && epochs == 5)
        #expect(geometry == topology && initial == 1.5 && final == 0.2 && tolerance == 1e-7)
        #expect(clusters == (usesWard ? 2 : nil))
        #expect(
            try GlifiStudioTextAnalysisRequest.decode(output.canonicalRequest) == output.request)
        let json = try #require(
            JSONSerialization.jsonObject(with: output.encodedResult) as? [String: Any])
        let result = try #require(json["result"] as? [String: Any])
        let map = try #require(result["map"] as? [String: Any])
        let prototypes = try #require(map["prototypes"] as? [[Double]])
        let distances = try #require(result["uMatrix"] as? [Double])
        #expect(result["topology"] as? String == topology.rawValue)
        #expect(
            prototypes.count == 6 && prototypes.allSatisfy { $0.count == output.input.terms.count })
        #expect(prototypes.flatMap { $0 }.allSatisfy { $0.isFinite })
        #expect(distances.count == 6 && distances.allSatisfy { $0.isFinite && $0 >= 0 })
        #expect(output.tables.first { $0.id == "advanced.table.som-u-matrix" }?.rows.count == 6)
        #expect(output.tables.contains { $0.id == "advanced.table.som-ward" } == usesWard)
        if usesWard {
            let clustering = try #require(result["codebookClustering"] as? [String: Any])
            let assignments = try #require(clustering["assignments"] as? [Int])
            #expect(assignments.count == 6 && Set(assignments).count == 2)
            #expect(output.tables.first { $0.id == "advanced.table.som-ward" }?.rows.count == 5)
        } else {
            #expect(result["codebookClustering"] == nil)
        }
        model.somTopology = topology == .rectangular ? .hexagonal : .rectangular
        model.clustersSOMCodebooks.toggle()
        #expect(model.isDraftChanged)
        #expect(model.output?.canonicalRequest == output.canonicalRequest)
        #expect(try await fixture.session.snapshot() == before)
        await fixture.session.close()
    }

    @Test func ordinalCoordinatesAndNewDraftFieldsKeepTheirCapturedIdentity() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(tool: .mdsSearch, ids: fixture.ids)
        model.dimensions = 1
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(output.isOneDimensional)
        #expect(output.isOrdinalMDS)
        #expect(!model.isDraftChanged)
        model.mdsStarts += 1
        #expect(model.isDraftChanged)
        model.mdsStarts -= 1
        #expect(!model.isDraftChanged)
        model.somTopology = .rectangular
        #expect(model.isDraftChanged)
        model.somTopology = .hexagonal
        #expect(!model.isDraftChanged)
        model.topicCandidatesDraft = "2"
        #expect(model.isDraftChanged)
        #expect(model.output?.requestDigest == output.requestDigest)
        model.tool = .mds
        model.mdsMethod = .ordinal
        model.distance = .cosine
        model.dimensions = 2
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        #expect(model.output?.isOrdinalMDS == true)
        guard let singleRequest = model.output?.request,
            case let .mds(matrix, _, method, _, _) = singleRequest
        else {
            Issue.record("Expected the ordinal single-run request")
            return
        }
        #expect(method == .ordinal)
        #expect(matrix.count == fixture.ids.count)
        model.tool = .distances
        model.distance = .simpson
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        guard let distanceRequest = model.output?.request,
            case let .dissimilarities(_, metric) = distanceRequest
        else {
            Issue.record("Expected the Simpson distance request")
            return
        }
        #expect(metric == .simpson)
        await fixture.session.close()
    }

    @Test(arguments: [GlifiStudioMDSMethod.metric, .kruskal, .sammon, .ordinal])
    func seededSearchRetainsTheDeclaredIterativeMethod(method: GlifiStudioMDSMethod) async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(tool: .mdsSearch, ids: fixture.ids)
        model.mdsSearchMethod = method
        model.mdsStarts = 2
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        guard
            case let .advanced(.mdsSearch(_, _, capturedMethod, starts, seed, _, _)) = output
                .request
        else {
            Issue.record("Expected a seeded search request")
            return
        }
        #expect(capturedMethod == method)
        #expect(starts == 2)
        #expect(seed == 17)
        #expect(output.tables.first { $0.id == "advanced.table.mds-runs" }?.rows.count == 2)
        await fixture.session.close()
    }

    @Test(arguments: [
        GlifiStudioTopicSelectionCriterion.heldOutPerplexity, .caoJuan2009,
        .arun2010, .deveaud2014, .griffiths2004,
    ])
    func topicSelectionPreservesEveryCriterionAndValidationChoice(
        criterion: GlifiStudioTopicSelectionCriterion
    ) async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(tool: .topicSelection, ids: fixture.ids)
        model.topicCriterion = criterion
        model.topicCandidatesDraft = "2"
        model.folds = criterion == .heldOutPerplexity ? 2 : 0
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        guard case let .advanced(.ldaSelection(_, candidates, _, options)) = output.request else {
            Issue.record("Expected a topic selection request")
            return
        }
        #expect(candidates == [2])
        #expect(options.criterion == criterion)
        #expect(options.folds == model.folds)
        #expect(output.tables.first { $0.id == "advanced.table.lda-candidates" }?.rows.count == 6)
        #expect(
            output.tables.contains { $0.id == "advanced.table.lda-held-out" } == (model.folds > 0))
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
        model.mdsStarts = 3
        model.mdsTolerance = 1e-6
        model.somTopology = .hexagonal
        model.clustersSOMCodebooks = true
        model.somCodebookClusterCount = 2
        model.topicCandidatesDraft = "2 3"
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
