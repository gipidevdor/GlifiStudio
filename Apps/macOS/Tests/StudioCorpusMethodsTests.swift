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
        let reusedSnapshot = try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        #expect(reusedSnapshot == snapshot)
        let expectedCacheRead = try cacheReadJSON(
            output.encodedResult, generation: snapshot.generation)
        #expect(model.output?.encodedResult == expectedCacheRead)
        model.draft.diversityWindowSize = 0
        do {
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
            Issue.record("Invalid corpus options were accepted")
        } catch let failure as GlifiStudioFailure {
            let expected = GlifiStudioFailure(
                code: "analysis.invalid-options", category: "invalidInput", operation: "analyze",
                retryDisposition: "afterCorrection", retainedState: "lastCommittedGeneration",
                messageKey: "failure.analysis.invalid-options")
            #expect(failure == expected)
        }
        #expect(model.output?.encodedResult == expectedCacheRead)
        #expect(try await fixture.session.snapshot() == snapshot)
        await fixture.session.close()
        let reopened = try await GlifiStudioService().openProject(
            at: fixture.root.appending(path: "Methods.glifi"))
        let reopenedModel = configuredModel(method, ids: fixture.ids)
        let reopenedSnapshot = try await reopenedModel.execute(
            session: reopened, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        #expect(reopenedSnapshot == snapshot)
        #expect(reopenedModel.output?.encodedResult == expectedCacheRead)
        await reopened.close()
        let captured = output.draft
        model.draft.maximumTerms = 2
        model.draft.groupLabels = [:]
        #expect(model.output?.draft == captured)
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
        let plot = try #require(previous.visualizations.first)
        let expectedPlot = try GlifiStudioVisualizationBuilder.factorPlot(direct)
        #expect(plot == expectedPlot)
        #expect(plot.artifactID == result.lineage.artifactID)
        let mark = try #require(plot.marks.first)
        let selectedSource = model.selectVisualMark(mark, visualizationID: plot.id)
        #expect(selectedSource == mark.sourceRevisionIDs.first)
        #expect(model.selectedVisualMarkID == mark.id)
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
        #expect(model.output?.visualizations == previous.visualizations)
        #expect(model.selectedVisualMarkID == mark.id)
        await fixture.session.close()
    }

    @Test(arguments: StudioCorpusClusterUnit.allCases)
    func hierarchicalViewsUseTheDeclaredUnitsAndThePersistedArtifact(
        unit: StudioCorpusClusterUnit
    ) async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = configuredModel(.hierarchical, ids: fixture.ids)
        model.draft.clusterUnit = unit
        let snapshot = try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        guard case let .multivariate(result) = output.payload else {
            Issue.record("Expected a multivariate result")
            return
        }
        let expectedUnits = unit == .terms ? result.terms : result.sourceRevisionIDs
        #expect(result.clusterUnitKindIdentifier == unit.rawValue)
        #expect(result.clusterUnitIdentifiers == expectedUnits)
        #expect(result.clusterAssignments?.count == expectedUnits.count)
        let tree = try #require(output.visualizations.first)
        #expect(tree.family == .dendrogram)
        let expectedTree = try GlifiStudioVisualizationBuilder.dendrogram(result)
        #expect(tree == expectedTree)
        #expect(tree.artifactID == result.lineage.artifactID)
        #expect(tree.visibleObservationCount == expectedUnits.count)
        #expect(tree.totalObservationCount == expectedUnits.count)
        let leaves = tree.marks.filter { $0.kind == .point }
        #expect(Set(leaves.map(\.label)) == Set(expectedUnits))
        #expect(leaves.allSatisfy { Set($0.sourceRevisionIDs).isSubset(of: Set(fixture.ids)) })
        let assignments = try #require(model.tables.first { $0.id == "clusterAssignments" })
        #expect(assignments.rows.count == expectedUnits.count)
        if unit == .terms {
            #expect(assignments.rows.map { $0.values[0] } == result.terms)
            #expect(assignments.rows.allSatisfy { $0.sourceRevisionID == nil })
        } else {
            #expect(assignments.rows.compactMap(\.sourceRevisionID) == result.sourceRevisionIDs)
        }
        let leaf = try #require(leaves.first)
        #expect(model.selectVisualMark(leaf, visualizationID: "stale-view") == nil)
        #expect(model.selectedVisualMarkID == nil)
        #expect(
            model.selectVisualMark(leaf, visualizationID: tree.id)
                == leaf.sourceRevisionIDs.first)
        #expect(model.selectedVisualMarkID == leaf.id)
        #expect(try await fixture.session.snapshot() == snapshot)
        model.draft.clusterUnit = unit == .terms ? .documents : .terms
        #expect(model.output?.draft.clusterUnit == unit)
        #expect(model.output?.visualizations == output.visualizations)
        model.reset()
        #expect(model.output == nil)
        #expect(model.selectedVisualMarkID == nil)
        #expect(model.selectVisualMark(leaf, visualizationID: tree.id) == nil)
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

    @Test func nativeTermEditorsPreserveExplicitCandidatesAndSourceAnnotations() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioKHLanguageModel()
        model.draft.candidates[0].components = "lingua testo"
        model.draft.candidates[0].frequency = 3
        model.draft.preprocessingIdentifier = "test.explicit-components.v1"
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let scores = try #require(model.output)
        guard case let .termScores(candidates, provenance, _, _) = scores.request else {
            Issue.record("Expected explicit term candidates")
            return
        }
        #expect(
            candidates == [GlifiStudioTermCandidate(components: ["lingua", "testo"], frequency: 3)])
        #expect(provenance == "test.explicit-components.v1")
        model.tool = .termExtraction
        model.draft.annotationSourceID = try #require(fixture.ids.first)
        try await model.loadAnnotationSource(session: fixture.session)
        let source = try #require(model.annotationSource)
        #expect(source.text.hasPrefix("lingua testo"))
        var first = StudioKHTermTokenDraft()
        first.surface = "lingua"
        first.base = "lingua"
        first.partOfSpeech = "NOUN"
        first.endUTF8 = 6
        var second = StudioKHTermTokenDraft()
        second.surface = "testo"
        second.base = "testo"
        second.partOfSpeech = "NOUN"
        second.startUTF8 = 7
        second.endUTF8 = 12
        model.draft.tokens = [first, second]
        model.draft.linguisticContract = "test.manual-annotations.v1"
        model.draft.ruleIdentifier = "test.noun-compounds.v1"
        model.draft.allowedPartsOfSpeech = "NOUN"
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let extraction = try #require(model.output)
        let extractionResult = try #require(extraction.result)
        guard case let .advanced(.kh(.termExtraction(value))) = extractionResult.payload else {
            Issue.record("Expected source-bound term extraction")
            return
        }
        #expect(value.occurrences.count == 1)
        #expect(value.occurrences.first?.documentID == source.sourceRevisionID)
        #expect(value.occurrences.first?.startUTF8 == 0)
        #expect(value.occurrences.first?.endUTF8 == 12)
        #expect(extraction.sourceRevisionIDs == [source.sourceRevisionID])
        #expect(extraction.eligibleSourceRevisionIDs == fixture.ids)
        #expect(extraction.annotatedSource == source)
        let snapshot = try await fixture.session.snapshot()
        #expect(extraction.projectID == snapshot.projectID)
        #expect(extraction.generation == snapshot.generation)
        #expect(
            extraction.contentDigests[source.sourceRevisionID]
                == snapshot.sources.first {
                    $0.sourceRevisionID == source.sourceRevisionID
                }?.contentDigest)
        model.draft.tokens[0].partOfSpeech = ""
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        #expect(model.output?.encodedResult == extraction.encodedResult)
        model.reset()
        #expect(model.output == nil)
        #expect(model.annotationSource == nil)
        #expect(model.classifierState == nil)
        await fixture.session.close()
    }

    @Test func nativeClassifierContinuationUsesSufficientStatisticsAndExportsCanonicalResults()
        async throws
    {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioKHLanguageModel()
        model.tool = .incrementalClassifier
        let ids = Array(fixture.ids.prefix(5))
        for (index, id) in ids.prefix(4).enumerated() {
            model.draft.labels[id] = index < 2 ? "A" : "B"
        }
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let trained = try #require(model.classifierState)
        #expect(trained.documentCounts.reduce(0, +) == 4)
        model.tool = .continueClassifier
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let continued = try #require(model.output)
        #expect(continued.sourceRevisionIDs == ids)
        #expect(continued.sourceNumbers == fixture.numbers.filter { ids.contains($0.key) })
        #expect(Set(continued.contentDigests.keys) == Set(ids))
        #expect(
            continued.encodedRequest
                == (try GlifiStudioTextAnalysisRequest.advanced(.kh(continued.request))
                    .canonicalData()))
        guard
            case let .continueClassifier(state, documents, labels, predictions) = continued.request
        else {
            Issue.record("Expected a continuation request")
            return
        }
        #expect(state == trained)
        #expect(documents.count == 4)
        #expect(labels.count == 4)
        #expect(predictions.count == 1)
        #expect(continued.state?.documentCounts.reduce(0, +) == 8)
        let canonical = try await GlifiStudioKHAnalysis.execute(continued.request)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        #expect(continued.encodedResult == (try encoder.encode(canonical)))
        let stateURL = fixture.root.appending(path: "classifier-state.json")
        try JSONEncoder().encode(trained).write(to: stateURL)
        let restored = StudioKHLanguageModel()
        try await restored.importClassifierState(from: stateURL)
        #expect(restored.classifierState == trained)
        let invalidState = GlifiStudioNaiveBayesTrainingState(
            classes: trained.classes, vocabulary: trained.vocabulary,
            documentCounts: trained.documentCounts, tokenCounts: trained.tokenCounts, smoothing: 0)
        try JSONEncoder().encode(invalidState).write(to: stateURL)
        await #expect(throws: GlifiStudioFailure.self) {
            try await restored.importClassifierState(from: stateURL)
        }
        #expect(restored.classifierState == trained)
        for (malformedJSON, expectedCode) in [
            ("{\"unknown\":true}", "text-analysis.unknown-field"),
            ("not JSON", "ui.kh-language.invalid-input"),
        ] {
            try Data(malformedJSON.utf8).write(to: stateURL)
            do {
                try await restored.importClassifierState(from: stateURL)
                Issue.record("Malformed serialized state must be rejected before publication")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == expectedCode)
                #expect(failure.category == "invalidInput")
                #expect(failure.retryDisposition == "afterCorrection")
            }
            #expect(restored.classifierState == trained)
        }
        model.reset()
        #expect(model.classifierState == nil)
        await fixture.session.close()
    }

    @Test func nativeAgreementAndCodingFlowsKeepLabelsGroupsAndCorrectionsExplicit() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioKHLanguageModel()
        for (index, id) in fixture.ids.enumerated() {
            model.draft.labels[id] = index < 4 ? "A" : "B"
        }
        model.tool = .validateClassifierWithAgreement
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let validation = try #require(model.output)
        #expect(validation.metrics.contains { $0.key == "kappa" })
        #expect(validation.tables.contains { $0.id == "confusion" })
        model.tool = .codeCrosstabSignificance
        model.draft.rules = "*Mare\nmare"
        model.draft.correction = .none
        model.draft.labels[fixture.ids[0]] = ""
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        let coding = try #require(model.output)
        guard case let .codeCrosstabSignificance(units, rules, groups, correction) = coding.request
        else {
            Issue.record("Expected coding significance")
            return
        }
        #expect(units.count == fixture.ids.count)
        #expect(rules == "*Mare\nmare")
        #expect(groups.filter { $0 == nil }.count == 1)
        #expect(correction == .none)
        #expect(coding.metrics.first { $0.key == "excluded-documents" }?.value == "1")
        await fixture.session.close()
    }

    @Test func resettingLanguageWorkflowInvalidatesAResultWithoutCancellingTheCaller() async throws
    {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioKHLanguageModel()
        model.draft.candidates[0].components = "lingua testo"
        model.draft.preprocessingIdentifier = "test.manual-segmentation.v1"
        var entered = false
        let operation = Task.immediate { @MainActor in
            entered = true
            try await model.execute(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: Locale(identifier: "it_IT"))
        }
        #expect(entered)
        model.reset()
        await #expect(throws: GlifiStudioFailure.self) { try await operation.value }
        #expect(!operation.isCancelled)
        #expect(model.output == nil)
        #expect(model.classifierState == nil)
        #expect(model.annotationSource == nil)
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

    /// A cache read preserves every scientific byte and refreshes only request-snapshot lineage.
    private func cacheReadJSON(_ data: Data, generation: Int) throws -> Data {
        var text = String(decoding: data, as: UTF8.self)
        let expression = try NSRegularExpression(
            pattern: #""(sourceGeneration|generation)"\s*:\s*([0-9]+)"#)
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        #expect(matches.count == 2)
        for match in matches.reversed() {
            let range = try #require(Range(match.range(at: 2), in: text))
            text.replaceSubrange(range, with: String(generation))
        }
        return Data(text.utf8)
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
