// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioEvaluationTests {
    @Test func draftChangesTrackFrozenInputAndParameters() async throws {
        let model = StudioEvaluationModel()
        model.tool = .classification
        model.observations = [.init(gold: "N", predicted: "N")]
        #expect(!model.isDraftChanged)
        try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(!model.isDraftChanged)

        model.observations[0].gold = "V"
        #expect(model.isDraftChanged)
        #expect(model.output?.input == output.input)
        #expect(model.output?.id == output.id)
        model.observations[0].gold = "N"
        #expect(!model.isDraftChanged)

        model.zeroPolicy = .zero
        #expect(model.isDraftChanged)
        #expect(model.output?.input.zeroPolicy == .undefined)
        model.zeroPolicy = .undefined
        #expect(!model.isDraftChanged)
        model.tool = .lemmas
        #expect(model.isDraftChanged)
        #expect(model.output?.id == output.id)
        model.reset()
        #expect(!model.isDraftChanged)
    }

    @Test func resetDuringSuspendedEvaluationPreventsLatePublication() async throws {
        let model = StudioEvaluationModel()
        model.tool = .classification
        model.observations = (0..<StudioEvaluationModel.maximumObservations).map {
            .init(gold: "c\($0 % 200)", predicted: "c\(($0 + 1) % 200)")
        }
        var execution: Task<Void, any Error>?
        await withCheckedContinuation { started in
            execution = Task { @MainActor in
                started.resume()
                try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
            }
        }
        model.reset()
        let pending = try #require(execution)
        do {
            try await pending.value
            Issue.record("Reset execution published a stale result")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(model.output == nil)
        #expect(model.rows.isEmpty)
        #expect(model.observations.isEmpty)
    }

    @Test(arguments: [
        StudioEvaluationTool.classification, .lemmas, .boundaries, .namedEntities, .morphology,
    ])
    func linguisticInputsMatchTheFacadeWithoutAProject(tool: StudioEvaluationTool) async throws {
        let home = StudioHomeModel()
        let model = home.evaluation
        model.tool = tool
        model.loadSyntheticExample()
        #expect(home.snapshot == nil)
        await home.runCoreAnalysis {
            try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        }
        #expect(home.lastFailure == nil)
        let output = try #require(model.output)
        let value = try #require(output.linguistic)
        let reference: GlifiStudioLinguisticEvaluationResult
        switch tool {
        case .temporal: return
        case .classification:
            reference = try await GlifiStudioLinguisticEvaluation.classification(
                gold: model.observations.map(\.gold), predicted: model.observations.map(\.predicted)
            )
        case .lemmas:
            reference = try await GlifiStudioLinguisticEvaluation.lemmas(
                gold: model.observations.map(\.gold),
                predicted: model.observations.map(\.predicted),
                forms: model.observations.map(\.form),
                partsOfSpeech: model.observations.map(\.partOfSpeech))
        case .boundaries:
            reference = try await GlifiStudioEvaluationWorkbench.boundaries(
                gold: [[4]], predicted: [[4, 5]], texts: model.documents.map(\.text))
        case .namedEntities:
            reference = try await GlifiStudioEvaluationWorkbench.namedEntities(
                gold: [[.init(lowerBound: 0, upperBound: 4, type: "LOC")]],
                predicted: [[.init(lowerBound: 0, upperBound: 4, type: "ORG")]],
                texts: model.documents.map(\.text))
        case .morphology:
            reference = try await GlifiStudioLinguisticEvaluation.morphology(
                gold: [["Number": "Sing"]], predicted: [["Number": "Plur"]])
        }
        #expect(value == reference)
        #expect(model.rows.count <= StudioEvaluationModel.pageSize)
        #expect(output.linguisticRows.allSatisfy { $0.values.count == output.columnKeys.count })
        let encoded = try #require(output.encodedLinguisticResult)
        #expect(
            try JSONDecoder().decode(GlifiStudioLinguisticEvaluationResult.self, from: encoded)
                == reference)
        let original = output.input.observations
        model.observations = []
        model.documents = []
        #expect(model.output?.input.observations == original)
        #expect(home.snapshot == nil)
    }

    @Test func keepsThePreviousResultOnFailureAndCancellationAndPagesWithoutRecalculation()
        async throws
    {
        let model = StudioEvaluationModel()
        model.tool = .classification
        model.observations = (0..<10).map { .init(gold: "c\($0)", predicted: "c\($0)") }
        try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(output.rowCount > StudioEvaluationModel.pageSize)
        let first = model.rows.map(\.id)
        await model.showPage(1, locale: .init(identifier: "it_IT"))
        #expect(model.page == 1)
        #expect(model.rows.first?.id == StudioEvaluationModel.pageSize)
        #expect(model.output?.id == output.id)
        await model.showPage(-1, locale: .init(identifier: "it_IT"))
        #expect(model.page == 1)
        await model.showPage(0, locale: .init(identifier: "it_IT"))
        #expect(model.rows.map(\.id) == first)
        model.observations[0].gold = ""
        do {
            try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
            Issue.record("Expected invalid label")
        } catch let failure as GlifiStudioFailure { #expect(failure.category == "invalidInput") }
        #expect(model.output?.id == output.id)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        }
        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch let failure as GlifiStudioFailure { #expect(failure.category == "cancelled") }
        #expect(model.output?.id == output.id)
        model.temporalAnnotations["example"] = .init()
        model.reset()
        #expect(model.output == nil)
        #expect(model.rows.isEmpty)
        #expect(model.temporalAnnotations.isEmpty)
        #expect(model.observations.isEmpty)
    }

    @Test func resetDuringImmediateLinguisticExecutionPreventsPublicationAndAllowsRetry()
        async throws
    {
        let model = StudioEvaluationModel()
        model.tool = .classification
        model.observations = [.init(gold: "N", predicted: "N")]
        try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        _ = try #require(model.output)
        var entered = false
        let execution = Task.immediate { @MainActor in
            entered = true
            try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        }
        #expect(entered)
        #expect(!execution.isCancelled)
        model.reset()
        do {
            try await execution.value
            Issue.record("A linguistic evaluation invalidated by reset must not publish")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "newRequest")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(!execution.isCancelled)
        #expect(model.output == nil)
        #expect(model.rows.isEmpty)
        #expect(model.observations.isEmpty)
        #expect(model.documents.isEmpty)
        #expect(model.temporalAnnotations.isEmpty)
        #expect(model.selectedTerms.isEmpty)
        #expect(model.page == 0)

        model.observations = [.init(gold: "V", predicted: "N")]
        try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        let retried = try #require(model.output)
        #expect(retried.input.observations.first?.gold == "V")
        #expect(retried.linguistic?.accuracy?.correctCount == 0)
        #expect(!model.rows.isEmpty)
    }

    @Test func resetDuringImmediateTemporalExecutionPreventsPublicationAndAllowsRetry()
        async throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiTemporalReset-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Time.glifi"))
        let url = root.appending(path: "input.txt")
        try Data("casa casa mare".utf8).write(to: url)
        let imported = try await session.importText(at: url, format: .plainText)
        let id = try #require(imported.project.sources.first?.sourceRevisionID)
        let before = try await session.snapshot()
        let model = StudioEvaluationModel()
        model.tool = .temporal
        model.bucketCount = 2
        model.selectedTerms = "casa"
        model.temporalAnnotations[id] = .init(
            precision: .civilMonth, year: 2024, month: 2, provenance: "manual.reset-test")
        try await model.executeTemporal(
            session: session, sourceRevisionIDs: [id], sourceNumbers: [id: 1],
            locale: .init(identifier: "it_IT"))
        _ = try #require(model.output)
        var entered = false
        let execution = Task.immediate { @MainActor in
            entered = true
            try await model.executeTemporal(
                session: session, sourceRevisionIDs: [id], sourceNumbers: [id: 1],
                locale: .init(identifier: "it_IT"))
        }
        #expect(entered)
        #expect(!execution.isCancelled)
        model.reset()
        do {
            try await execution.value
            Issue.record("A temporal evaluation invalidated by reset must not publish")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "newRequest")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(!execution.isCancelled)
        #expect(model.output == nil)
        #expect(model.rows.isEmpty)
        #expect(model.temporalAnnotations.isEmpty)
        #expect(model.selectedTerms.isEmpty)
        #expect(model.page == 0)

        model.selectedTerms = "mare"
        model.temporalAnnotations[id] = .init(
            precision: .civilMonth, year: 2024, month: 1, provenance: "manual.retry")
        try await model.executeTemporal(
            session: session, sourceRevisionIDs: [id], sourceNumbers: [id: 1],
            locale: .init(identifier: "it_IT"))
        let retried = try #require(model.output?.temporal)
        #expect(retried.selectedTerms == ["mare"])
        #expect(retried.documents.first?.metadataProvenance == "manual.retry")
        #expect(!model.rows.isEmpty)
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    @Test func temporalMetadataAndCountsAreFrozenWithoutPersistingAssignments() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiTemporalClient-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Time.glifi"))
        let url = root.appending(path: "input.txt")
        try Data("casa casa mare".utf8).write(to: url)
        let imported = try await session.importText(at: url, format: .plainText)
        let id = try #require(imported.project.sources.first?.sourceRevisionID)
        let before = try await session.snapshot()
        let model = StudioEvaluationModel()
        model.tool = .temporal
        model.bucketCount = 2
        model.selectedTerms = "casa"
        model.temporalAnnotations[id] = .init(
            precision: .civilMonth, year: 2024, month: 2, provenance: "manual.test")
        try await model.executeTemporal(
            session: session, sourceRevisionIDs: [id], sourceNumbers: [id: 1],
            locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        let value = try #require(output.temporal)
        #expect(value.result.buckets[1].aggregate.tokenCount == 3)
        #expect(value.result.buckets[1].aggregate.terms.first?.frequency == 2)
        #expect(value.documents.first?.metadataProvenance == "manual.test")
        #expect(model.rows.allSatisfy { $0.values.count == 9 })
        #expect(!model.isDraftChanged)
        model.bucketCount = 3
        #expect(model.isDraftChanged)
        #expect(model.output?.input.bucketCount == 2)
        model.bucketCount = 2
        #expect(!model.isDraftChanged)
        model.temporalAnnotations[id] = .init(precision: .civilYear, year: 2020)
        #expect(model.isDraftChanged)
        model.selectedTerms = "mare"
        #expect(model.output?.id == output.id)
        #expect(model.output?.temporal?.selectedTerms == ["casa"])
        #expect(model.output?.temporal?.documents.first?.value == .civilMonth(year: 2024, month: 2))
        #expect(try await session.snapshot() == before)
        await session.close()
    }
}
