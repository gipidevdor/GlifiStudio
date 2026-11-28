// SPDX-License-Identifier: BSD-3-Clause

import AppKit
import Foundation
import GlifiKit
import SwiftUI
import Testing

@MainActor
struct StudioEvaluationTests {
    private final class BundleAnchor {}

    private final class ExportGeometry {
        var frame: CGRect?
    }

    @Test("Risultati metodo e export restano raggiungibili in una finestra bassa")
    func evaluationResultsAndMethodRemainReachableInAShortWindow() async throws {
        let home = StudioHomeModel()
        let model = home.evaluation
        model.tool = .classification
        model.loadSyntheticExample()
        let example = model.observations
        try #require(!example.isEmpty)
        model.observations = (0..<200).map { index in
            let item = example[index % example.count]
            return .init(gold: item.gold, predicted: item.predicted)
        }
        try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
        let outputID = try #require(model.output).id
        let exportGeometry = ExportGeometry()
        let screenOrigin = NSScreen.main?.visibleFrame.origin ?? .zero
        let window = NSWindow(
            contentRect: NSRect(
                x: screenOrigin.x + 20, y: screenOrigin.y + 20, width: 1_000, height: 420),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AnyView(EmptyView()))
        host.sizingOptions = []
        host.setFrameSize(window.contentLayoutRect.size)
        window.contentView = host
        host.rootView = AnyView(
            StudioEvaluationView(model: home, onExportGeometryChange: { exportGeometry.frame = $0 })
                .environment(\.locale, Locale(identifier: "it_IT")))
        window.orderBack(nil)
        defer {
            window.contentView = nil
            window.close()
        }
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(abs(host.bounds.height - 420) <= 1)
        let table = try #require(tableViews(in: host).first { $0.numberOfRows > 0 })
        let tableViewport = try #require(table.enclosingScrollView?.contentView)
        let tableFrame = window.convertToScreen(
            tableViewport.convert(tableViewport.bounds, to: nil))
        let workspaceFrame = window.convertToScreen(host.convert(host.bounds, to: nil))
        #expect(tableViewport.bounds.height > 0)
        #expect(
            workspaceFrame.insetBy(dx: -1, dy: -1).contains(tableFrame),
            "Table viewport \(tableFrame) must fit inside workspace \(workspaceFrame)")

        // Operate on the real view's accessibility controls, whether Method is a disclosure or tab.
        let method = try #require(
            try await reachableElement(
                labels: localizedLabels("common.method"), requiresAction: true,
                host: host, window: window),
            "The method control must be reachable through the actual evaluation workspace")
        // AppKit's segment proxy can return false after changing the selection: verify the effect.
        _ = method.accessibilityPerformPress()
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        if method.accessibilityRole() == .radioButton {
            #expect((method.accessibilityValue() as? NSNumber)?.boolValue == true)
        }
        let lastObservation = Set(
            localizedLabels("evaluation.observation.number %lld").map {
                String(
                    format: $0, locale: Locale(identifier: "it_IT"), Int64(model.observations.count)
                )
            })
        _ = try #require(
            try await reachableElement(
                labels: lastObservation, requiresAction: false, host: host, window: window),
            "Scrolling must reach the final captured observation rather than only the results table"
        )
        // SwiftUI's virtual button is observed passively; its action is exercised in the app.
        let exportFrame = try #require(exportGeometry.frame)
        #expect(!exportFrame.isEmpty)
        #expect(
            host.bounds.insetBy(dx: -1, dy: -1).contains(exportFrame),
            "Export control \(exportFrame) must fit inside workspace \(host.bounds)")
        #expect(model.output?.id == outputID)
        #expect(model.observations.count == 200)
        #expect(home.lastFailure == nil)
    }

    private func localizedLabels(_ key: String) -> Set<String> {
        let bundle = Bundle(for: BundleAnchor.self)
        var values: Set<String> = [
            key, bundle.localizedString(forKey: key, value: key, table: nil),
        ]
        for language in ["it", "en"] {
            if let path = bundle.path(forResource: language, ofType: "lproj"),
                let localized = Bundle(path: path)
            {
                values.insert(localized.localizedString(forKey: key, value: key, table: nil))
            }
        }
        return values
    }

    private func reachableElement(
        labels: Set<String>, requiresAction: Bool, host: NSView, window: NSWindow
    ) async throws -> (any NSAccessibilityProtocol)? {
        for _ in 0..<8 {
            host.layoutSubtreeIfNeeded()
            let viewport = window.convertToScreen(host.convert(host.bounds, to: nil))
            if let found = accessibilityElements(in: host).first(where: { element in
                let names = [
                    element.accessibilityLabel(), element.accessibilityTitle(),
                    element.accessibilityValue() as? String,
                ].compactMap { $0 }
                let role = element.accessibilityRole()
                let isControl =
                    role == .button || role == .radioButton || role == .disclosureTriangle
                let frame = element.accessibilityFrame()
                return names.contains(where: labels.contains)
                    && (!requiresAction || isControl)
                    && !frame.isEmpty && viewport.insetBy(dx: -1, dy: -1).contains(frame)
            }) {
                return found
            }
            for scroll in scrollViews(in: host) {
                guard let document = scroll.documentView,
                    document.bounds.height > scroll.contentView.bounds.height + 1
                else { continue }
                let bottom =
                    document.isFlipped
                    ? max(
                        document.bounds.minY,
                        document.bounds.maxY - scroll.contentView.bounds.height)
                    : document.bounds.minY
                scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.minX, y: bottom))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }

    private func accessibilityElements(in root: NSView) -> [any NSAccessibilityProtocol] {
        var result: [any NSAccessibilityProtocol] = []
        var pending: [Any] = [root]
        var visited: Set<ObjectIdentifier> = []
        while let next = pending.popLast() {
            let object = next as AnyObject
            guard visited.insert(ObjectIdentifier(object)).inserted else { continue }
            if let view = next as? NSView {
                pending.append(contentsOf: view.subviews)
            }
            if let full = next as? any NSAccessibilityProtocol {
                pending.append(contentsOf: full.accessibilityChildren() ?? [])
                result.append(full)
            }
        }
        return result
    }

    private func scrollViews(in root: NSView) -> [NSScrollView] {
        (root as? NSScrollView).map { [$0] } ?? root.subviews.flatMap { scrollViews(in: $0) }
    }

    private func tableViews(in root: NSView) -> [NSTableView] {
        (root as? NSTableView).map { [$0] } ?? root.subviews.flatMap { tableViews(in: $0) }
    }

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
