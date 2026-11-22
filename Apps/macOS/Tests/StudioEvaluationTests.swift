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

    @Test(arguments: [GlifiStudioTemporalOutsidePolicy.exclude, .reject])
    func instantCalendarBucketsRespectDSTAndTheExclusiveUpperBoundary(
        outsidePolicy: GlifiStudioTemporalOutsidePolicy
    ) async throws {
        let fixture = try await makeTemporalFixture(
            texts: ["casa casa mare", "casa mare", "mare", "casa casa casa", "mare mare"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let model = StudioEvaluationModel()
        model.instantBasis = true
        model.timeZoneIdentifier = "Europe/Rome"
        model.granularity = .day
        model.originYear = 2024
        model.originMonth = 3
        model.originDay = 30
        model.bucketCount = 3
        model.selectedTerms = "casa"
        let instants = [
            "2024-03-30T22:30:00Z", "2024-03-30T23:00:00Z",
            "2024-03-31T21:59:59Z", "2024-03-31T22:00:00Z", "2024-04-01T22:00:00Z",
        ]
        for (id, instant) in zip(fixture.ids, instants) {
            model.temporalAnnotations[id] = .init(
                precision: .instant, instant: instant, provenance: "manual.dst-scenario")
        }
        try await model.executeTemporal(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let output = try #require(model.output)
        let value = try #require(output.temporal)
        #expect(value.result.configuration.basis == .instants(timeZoneIdentifier: "Europe/Rome"))
        #expect(value.result.buckets.map { $0.aggregate.documentCount } == [1, 2, 1])
        #expect(value.result.buckets.map { $0.aggregate.tokenCount } == [3, 3, 3])
        #expect(value.result.buckets.map { $0.aggregate.terms.first?.frequency } == [2, 1, 3])
        #expect(value.result.excluded.map { $0.lineage.sourceRevisionID } == [fixture.ids[4]])
        #expect(value.result.excluded.first?.reasonIdentifier == "temporal.after-domain")
        let dst = value.result.buckets[1]
        guard case let .instant(start) = dst.start, case let .instant(end) = dst.end else {
            Issue.record("Instant boundaries were converted to civil dates")
            return
        }
        #expect(end.timeIntervalSince(start) == 23 * 60 * 60)
        #expect(value.documents.allSatisfy { $0.metadataProvenance == "manual.dst-scenario" })
        model.timeZoneIdentifier = "UTC"
        model.bucketWidth = 2
        #expect(model.isDraftChanged)
        #expect(model.output?.input.timeZoneIdentifier == "Europe/Rome")
        #expect(model.output?.input.bucketWidth == 1)
        model.timeZoneIdentifier = "Europe/Rome"
        model.bucketWidth = 1
        model.outsidePolicy = outsidePolicy
        if outsidePolicy == .reject {
            do {
                try await model.executeTemporal(
                    session: fixture.session, sourceRevisionIDs: fixture.ids,
                    sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
                Issue.record("An instant at the exclusive upper boundary was accepted")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "temporal.after-domain")
                #expect(failure.category == "invalidInput")
                #expect(failure.retainedState == "unchanged")
            }
            #expect(model.output?.id == output.id)
        } else {
            #expect(!model.isDraftChanged)
        }
        #expect(try await fixture.session.snapshot() == before)
        await fixture.session.close()
    }

    @Test(arguments: [
        GlifiStudioTemporalMissingPolicy.exclude, .separate, .reject,
    ])
    func missingTemporalMetadataKeepsItsDeclaredPolicyAndExposure(
        policy: GlifiStudioTemporalMissingPolicy
    ) async throws {
        let fixture = try await makeTemporalFixture(texts: ["casa casa mare", "mare"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let model = StudioEvaluationModel()
        model.bucketCount = 1
        model.selectedTerms = "casa"
        model.temporalAnnotations[fixture.ids[0]] = .init(
            precision: .civilDate, year: 2024, month: 1, day: 1,
            provenance: "manual.observed")
        model.temporalAnnotations[fixture.ids[1]] = .init(
            precision: .missing, provenance: "manual.unavailable")
        try await model.executeTemporal(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let previous = try #require(model.output)
        model.missingPolicy = policy
        if policy == .reject {
            do {
                try await model.executeTemporal(
                    session: fixture.session, sourceRevisionIDs: fixture.ids,
                    sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
                Issue.record("Missing temporal metadata was accepted by the reject policy")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "temporal.missing-date")
                #expect(failure.category == "insufficientData")
                #expect(failure.retainedState == "unchanged")
            }
            #expect(model.output?.id == previous.id)
        } else {
            try await model.executeTemporal(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
            let result = try #require(model.output?.temporal?.result)
            #expect(result.configuration.missingPolicy == policy)
            #expect(result.buckets.first?.aggregate.documentCount == 1)
            #expect(result.buckets.first?.aggregate.tokenCount == 3)
            #expect(result.buckets.first?.aggregate.terms.first?.frequency == 2)
            if policy == .separate {
                #expect(result.missing?.documentCount == 1)
                #expect(result.missing?.tokenCount == 1)
                #expect(result.missing?.terms.first?.frequency == 0)
                #expect(result.excluded.isEmpty)
            } else {
                #expect(result.missing == nil)
                #expect(result.excluded.map { $0.reasonIdentifier } == ["temporal.missing-date"])
                #expect(result.excluded.first?.lineage.sourceRevisionID == fixture.ids[1])
            }
        }
        #expect(try await fixture.session.snapshot() == before)
        await fixture.session.close()
    }

    @Test(arguments: [StudioTemporalPrecision.civilDate, .instant])
    func invalidTemporalDraftPreservesTheResultAndProjectThenAllowsCorrection(
        precision: StudioTemporalPrecision
    ) async throws {
        let fixture = try await makeTemporalFixture(texts: ["casa mare"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let id = try #require(fixture.ids.first)
        let model = StudioEvaluationModel()
        model.temporalAnnotations[id] = .init(precision: .civilMonth, year: 2024, month: 1)
        try await model.executeTemporal(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        let previous = try #require(model.output)
        model.temporalAnnotations[id] = .init(
            precision: precision, year: 2024, month: 2, day: 30,
            instant: "2024-03-31T02:30:00")
        do {
            try await model.executeTemporal(
                session: fixture.session, sourceRevisionIDs: fixture.ids,
                sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
            Issue.record("An invalid or unzoned temporal value was silently corrected")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "invalidInput")
            #expect(failure.retainedState == "unchanged")
            if precision == .civilDate { #expect(failure.code == "temporal.invalid-civil-date") }
        }
        #expect(model.output?.id == previous.id)
        #expect(model.output?.input == previous.input)
        #expect(try await fixture.session.snapshot() == before)
        model.temporalAnnotations[id] = .init(precision: .civilDate, year: 2024, month: 2, day: 29)
        try await model.executeTemporal(
            session: fixture.session, sourceRevisionIDs: fixture.ids,
            sourceNumbers: fixture.numbers, locale: .init(identifier: "it_IT"))
        #expect(model.output?.id != previous.id)
        #expect(model.output?.temporal?.result.buckets[1].aggregate.documentCount == 1)
        #expect(try await fixture.session.snapshot() == before)
        await fixture.session.close()
    }

    private func makeTemporalFixture(texts: [String]) async throws -> (
        root: URL, session: GlifiStudioProjectSession, ids: [String], numbers: [String: Int]
    ) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiTemporalScenario-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Time.glifi"))
        var ids: [String] = []
        for (index, text) in texts.enumerated() {
            let url = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            let imported = try await session.importText(at: url, format: .plainText)
            let added = Set(imported.project.sources.map(\.sourceRevisionID)).subtracting(ids)
            #expect(added.count == 1)
            ids.append(try #require(added.first))
        }
        return (
            root, session, ids,
            Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset + 1) })
        )
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
