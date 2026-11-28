// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDStudyWorld {
    var root: URL?
    var session: GlifiStudioProjectSession?
    var response: Data?
    var expectedResponse: Data?
    var operation = GlifiStudioStudyOperation.state
    var parameters: [String: Any] = [:]
    var failure: GlifiStudioFailure?
    var baseline: GlifiStudioProjectSnapshot?
    var baselineState: GlifiStudioStudyState?
    var sourceID = ""
    var workflowState: GlifiStudioStudyState?
    var rejected: [GlifiStudioFailure] = []
    let sourceText =
        "La città osserva il mare. 👩🏽‍🔬 La casa guarda il fiume.\nNota: a\u{0323}\u{0301}.\n"
    let quotes = ["La casa guarda il fiume.", "La città osserva il mare."]

    var projectURL: URL { get throws { try #require(root).appending(path: "Studio.glifi") } }
    var originalData: Data { Data(sourceText.utf8) }
    var originalDigest: String {
        "sha256:" + SHA256.hash(data: originalData).map { String(format: "%02x", $0) }.joined()
    }

    func prepare() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDDStudy-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        root = directory
        let source = directory.appending(path: "fonte-italiana.txt")
        try originalData.write(to: source)
        let active = try await GlifiStudioService().createProject(at: projectURL)
        session = active
        _ = try await active.importText(at: source, format: .plainText)
        let snapshot = try await active.snapshot()
        #expect(snapshot.sourceCount == 1)
        sourceID = try #require(snapshot.sources.first).sourceRevisionID
    }

    func prepareVariant(_ variant: String) async throws {
        try await prepare()
        operation = try #require(
            GlifiStudioStudyOperation.allCases.first { String(describing: $0) == variant })
        let active = try #require(session)
        if operation == .resolve || operation == .export {
            _ = try await collect(0, session: active, expectedRevision: 0)
        }
        baseline = try await active.snapshot()
        baselineState = try await active.studyState()
        parameters = try await parameters(for: operation)
    }

    func selection(_ index: Int) throws -> GlifiStudioPassageSelection {
        let range = try #require(sourceText.range(of: quotes[index]))
        return .bytes(
            start: sourceText.utf8.distance(from: sourceText.utf8.startIndex, to: range.lowerBound),
            end: sourceText.utf8.distance(from: sourceText.utf8.startIndex, to: range.upperBound))
    }

    private func collect(
        _ index: Int, session: GlifiStudioProjectSession, expectedRevision: Int
    ) async throws -> GlifiStudioStudyState {
        try await session.collectStudyExcerpt(
            sourceRevisionID: sourceID, selection: selection(index),
            title: index == 0 ? "Casa" : "Mare",
            groupID: nil, expectedRevision: expectedRevision)
    }

    private func parameters(for operation: GlifiStudioStudyOperation) async throws -> [String: Any]
    {
        let active = try #require(session)
        let state = try await active.studyState()
        switch operation {
        case .state: return [:]
        case .saveState:
            var draft = state
            draft.groups = [.init(id: "tema", title: "Luoghi")]
            draft.notes = [
                .init(
                    id: "nota-libera", title: "Osservazione", text: "Leggere i luoghi del testo.",
                    groupID: "tema")
            ]
            draft.order = state.excerpts.map(\.id) + ["nota-libera"]
            return ["state": try object(draft), "expectedRevision": state.revision]
        case .collect:
            return [
                "sourceRevisionID": sourceID, "selection": try object(selection(0)),
                "title": "Casa", "expectedRevision": state.revision,
            ]
        case .resolve: return ["excerptID": try #require(state.excerpts.first).id]
        case .export: return ["format": "json"]
        case .original: return ["sourceRevisionID": sourceID]
        }
    }

    private func typedResult(
        _ operation: GlifiStudioStudyOperation, session: GlifiStudioProjectSession
    ) async throws -> Data {
        switch operation {
        case .state: return try BDDVariantAssertions.encode(await session.studyState())
        case .saveState:
            let state = try JSONDecoder().decode(
                GlifiStudioStudyState.self,
                from: JSONSerialization.data(withJSONObject: #require(parameters["state"])))
            return try await BDDVariantAssertions.encode(
                session.saveStudyState(state, expectedRevision: state.revision))
        case .collect:
            return try await BDDVariantAssertions.encode(
                collect(0, session: session, expectedRevision: #require(baselineState).revision))
        case .resolve:
            return try await BDDVariantAssertions.encode(
                session.resolveStudyExcerpt(excerptID: #require(baselineState?.excerpts.first).id))
        case .export:
            return try BDDVariantAssertions.encode(await session.exportStudy(format: .json))
        case .original:
            return try BDDVariantAssertions.encode(
                await session.studyOriginal(sourceRevisionID: sourceID))
        }
    }

    private func command(_ operation: GlifiStudioStudyOperation, parameters: [String: Any]) throws
        -> Data
    {
        try JSONSerialization.data(
            withJSONObject: [
                "schema": "studio.glifi.study-command-request", "schemaVersion": 1,
                "operation": operation.rawValue, "parameters": parameters,
            ], options: [.sortedKeys])
    }

    private func cli(_ operation: GlifiStudioStudyOperation, parameters: [String: Any]) async throws
        -> Data
    {
        let directory = try #require(root)
        if let session { await session.close() }
        session = nil
        let requestURL = directory.appending(path: "studio-request.json")
        try command(operation, parameters: parameters).write(to: requestURL)
        let output = try await BDDSubprocess.run(
            executable: locateBDDCLI(),
            arguments: [
                "--format", "json", "study-call", try projectURL.path, "--request", requestURL.path,
            ],
            directory: directory)
        try #require(output.status == 0, "The real CLI must expose the study-call operation")
        let envelope = try #require(BDDVariantAssertions.object(output.stdout) as? [String: Any])
        #expect(envelope["command"] as? String == "study-call")
        #expect(envelope["outcome"] as? String == "succeeded")
        let result = try JSONSerialization.data(
            withJSONObject: #require(envelope["result"]),
            options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes])
        session = try await GlifiStudioService().openProject(at: projectURL)
        return result
    }

    func requestState() async throws { response = try await cli(.state, parameters: [:]) }

    func verifyEmptyState() async throws {
        let result = try BDDVariantAssertions.object(#require(response))
        try BDDVariantAssertions.expectFacts(
            result,
            json:
                #"{"revision":0,"excerpts.$count":0,"notes.$count":0,"groups.$count":0,"order.$count":0,"comparisonExcerptIDs.$count":0}"#
        )
        let active = try #require(session)
        #expect(response == (try BDDVariantAssertions.encode(await active.studyState())))
        let snapshot = try await active.snapshot()
        #expect(try await active.studyState().projectID == snapshot.projectID)
    }

    func execute(_ phase: String) async throws {
        response = nil
        failure = nil
        if phase == "nominale" {
            let active = try #require(session)
            await active.close()
            session = nil
            let nativeURL = try #require(root).appending(path: "Native.glifi")
            try FileManager.default.copyItem(at: projectURL, to: nativeURL)
            let native = try await GlifiStudioService().openProject(at: nativeURL)
            do {
                expectedResponse = try await typedResult(operation, session: native)
                await native.close()
            } catch {
                await native.close()
                throw error
            }
            response = try await cli(operation, parameters: parameters)
            return
        }
        let active = try #require(session)
        var params = parameters
        if phase == "JSON-invalido" { params["unexpected-study-canary"] = true }
        let request = try command(operation, parameters: params)
        do {
            if phase == "precancellata" {
                let task = Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await GlifiStudioStudyCommand.execute(json: request, session: active)
                }
                response = try await task.value.json
            } else {
                try #require(phase == "JSON-invalido")
                response = try await GlifiStudioStudyCommand.execute(json: request, session: active)
                    .json
            }
        } catch let failure as GlifiStudioFailure { self.failure = failure }
    }

    func verifyNominal(_ json: String) async throws {
        #expect(failure == nil)
        #expect(response == expectedResponse)
        let bytes = try #require(response)
        var facts = try BDDVariantAssertions.object(bytes)
        if operation == .export {
            let exported = try JSONDecoder().decode(Data.self, from: bytes)
            facts = try BDDVariantAssertions.object(exported)
        }
        try BDDVariantAssertions.expectFacts(facts, json: json)
        let active = try #require(session)
        if operation == .collect || operation == .resolve || operation == .export {
            let excerpt = try #require(try await active.studyState().excerpts.first)
            try await verifyAnchor(excerpt)
        }
        if operation == .original {
            let original = try await active.studyOriginal(sourceRevisionID: sourceID)
            #expect(original.sourceRevisionID == sourceID)
            #expect(original.data == originalData)
            #expect(original.contentDigest == originalDigest)
            #expect(original.format == .plainText)
        }
    }

    private func verifyAnchor(_ excerpt: GlifiStudioStudyExcerpt) async throws {
        let anchor = excerpt.anchor
        #expect(anchor.sourceRevisionID == sourceID)
        #expect(anchor.sourceContentDigest == originalDigest)
        #expect(anchor.representationIdentifier == "extracted-utf8-v1")
        #expect(anchor.representationDigest == originalDigest)
        #expect(!anchor.extractionContractIdentifier.isEmpty)
        #expect(quotes.contains(anchor.quote))
        let bytes = Array(originalData)
        try #require(
            anchor.startUTF8 >= 0 && anchor.endUTF8 <= bytes.count
                && anchor.startUTF8 < anchor.endUTF8)
        #expect(Data(bytes[anchor.startUTF8..<anchor.endUTF8]) == Data(anchor.quote.utf8))
        #expect(
            anchor.sourceRanges.map { [$0.startUTF8, $0.endUTF8] } == [
                [anchor.startUTF8, anchor.endUTF8]
            ])
        let hash = SHA256.hash(data: try BDDVariantAssertions.encode(anchor)).map {
            String(format: "%02x", $0)
        }.joined()
        #expect(excerpt.id == hash)
        let resolved = try await #require(session).resolveStudyExcerpt(excerptID: excerpt.id)
        #expect(resolved.excerpt == excerpt)
        #expect(resolved.extractedText == sourceText)
        #expect(resolved.sourceText == sourceText)
        #expect(resolved.sourceRanges == anchor.sourceRanges)
    }

    func verifyReopening() async throws {
        let active = try #require(session)
        let state = try await active.studyState()
        let snapshot = try await active.snapshot()
        await active.close()
        let reopened = try await GlifiStudioService().openProject(at: projectURL)
        session = reopened
        #expect(try await reopened.studyState() == state)
        #expect(try await reopened.snapshot() == snapshot)
        #expect(try await reopened.studyOriginal(sourceRevisionID: sourceID).data == originalData)
        #expect(try await reopened.snapshot() == snapshot)
    }

    func verifyFailure(code: String, category: String) async throws {
        let observed = try #require(failure)
        #expect(observed.code == code)
        #expect(observed.category == category)
        #expect(observed.retainedState == "unchanged")
        #expect(response == nil)
        #expect(observed.arguments.isEmpty)
        #expect(!String(describing: observed).contains("unexpected-study-canary"))
        try await verifyUnchanged()
    }

    private func verifyUnchanged() async throws {
        let active = try #require(session)
        #expect(try await active.snapshot() == #require(baseline))
        #expect(try await active.studyState() == #require(baselineState))
        #expect(try await active.studyOriginal(sourceRevisionID: sourceID).data == originalData)
        #expect(try await active.snapshot() == #require(baseline))
    }

    func collectWorkflow() async throws {
        let active = try #require(session)
        var state = try await collect(0, session: active, expectedRevision: 0)
        state = try await collect(1, session: active, expectedRevision: state.revision)
        #expect(state.excerpts.count == 2)
        #expect(state.excerpts.map(\.anchor.quote) == quotes)
        state.groups = [.init(id: "luoghi", title: "Luoghi del testo")]
        for index in state.excerpts.indices { state.excerpts[index].groupID = "luoghi" }
        state.notes = [
            .init(
                id: "conclusione", title: "Confronto dei luoghi",
                text: "La casa e il mare orientano la lettura.", groupID: "luoghi",
                excerptIDs: state.excerpts.map(\.id)),
            .init(id: "nota-libera", title: "Da approfondire", text: "Rileggere il finale."),
        ]
        state.order = ["nota-libera", state.excerpts[1].id, "conclusione", state.excerpts[0].id]
        state.comparisonExcerptIDs = [state.excerpts[1].id, state.excerpts[0].id]
        state.excerpts[0].title = "Casa nel paesaggio"
        workflowState = try await active.saveStudyState(state, expectedRevision: state.revision)
    }

    func verifyWorkflowState() async throws {
        let state = try #require(workflowState)
        #expect(state.revision == 3)
        #expect(state.excerpts.map(\.anchor.quote) == quotes)
        #expect(state.excerpts[0].title == "Casa nel paesaggio")
        #expect(state.notes[0].excerptIDs == state.excerpts.map(\.id))
        #expect(state.notes[1].excerptIDs.isEmpty)
        #expect(
            state.order == [
                "nota-libera", state.excerpts[1].id, "conclusione", state.excerpts[0].id,
            ])
        #expect(state.comparisonExcerptIDs == [state.excerpts[1].id, state.excerpts[0].id])
        #expect(try await #require(session).studyState() == state)
        for excerpt in state.excerpts { try await verifyAnchor(excerpt) }
        #expect(try await #require(session).snapshot().investigationEventCount == 0)
    }

    func reopenWorkflow() async throws {
        try await verifyReopening()
        #expect(try await #require(session).studyState() == #require(workflowState))
    }

    func verifyOriginals() async throws {
        for excerpt in try #require(workflowState).excerpts { try await verifyAnchor(excerpt) }
        let original = try await #require(session).studyOriginal(sourceRevisionID: sourceID)
        #expect(original.data == originalData)
        #expect(original.contentDigest == originalDigest)
    }

    func verifyExports() async throws {
        let active = try #require(session)
        let before = try await active.snapshot()
        let json = try await active.exportStudy(format: .json)
        #expect(json == (try await active.exportStudy(format: .json)))
        let envelope = try #require(BDDVariantAssertions.object(json) as? [String: Any])
        let expectedState = try #require(workflowState)
        #expect(envelope["schema"] as? String == "studio.glifi.study-export")
        #expect(envelope["projectID"] as? String == expectedState.projectID)
        #expect(
            try JSONDecoder().decode(
                GlifiStudioStudyState.self,
                from: JSONSerialization.data(withJSONObject: #require(envelope["state"])))
                == expectedState)
        let markdown = try await active.exportStudy(format: .markdown)
        #expect(markdown == (try await active.exportStudy(format: .markdown)))
        let text = try #require(String(data: markdown, encoding: .utf8))
        for quote in quotes { #expect(text.contains(quote)) }
        #expect(text.contains("La casa e il mare orientano la lettura."))
        let free = try #require(text.range(of: "Da approfondire"))
        let sea = try #require(text.range(of: "Mare"))
        let conclusion = try #require(text.range(of: "Confronto dei luoghi"))
        let house = try #require(text.range(of: "Casa nel paesaggio"))
        #expect(
            free.lowerBound < sea.lowerBound && sea.lowerBound < conclusion.lowerBound
                && conclusion.lowerBound < house.lowerBound)
        #expect(try await active.snapshot() == before)
    }

    func staleSave() async throws {
        let state = try #require(baselineState)
        do {
            _ = try await #require(session).saveStudyState(
                state, expectedRevision: state.revision - 1)
            Issue.record("A stale notebook revision was accepted")
        } catch let failure as GlifiStudioFailure { rejected.append(failure) }
    }

    func verifyStaleSave() async throws {
        #expect(rejected.count == 1)
        #expect(rejected.first?.code == "study.stale-revision")
        #expect(rejected.first?.category == "staleArtifact")
        try await verifyUnchanged()
    }

    private func rejectState(_ fields: [String: Any]) async throws {
        do {
            response = try await GlifiStudioStudyCommand.execute(
                json: command(
                    .saveState,
                    parameters: [
                        "state": fields, "expectedRevision": #require(baselineState).revision,
                    ]), session: #require(session)
            ).json
            Issue.record("An invalid study state was accepted")
        } catch let failure as GlifiStudioFailure { rejected.append(failure) }
    }

    func tamperAnchors() async throws {
        let state = try #require(baselineState)
        let original = try #require(object(state) as? [String: Any])
        for (key, value) in [
            ("quote", "Citazione alterata" as Any),
            ("sourceContentDigest", "sha256:" + String(repeating: "0", count: 64)),
            ("startUTF8", 1),
        ] {
            var fields = original
            var excerpts = try #require(fields["excerpts"] as? [[String: Any]])
            var anchor = try #require(excerpts[0]["anchor"] as? [String: Any])
            anchor[key] = value
            excerpts[0]["anchor"] = anchor
            fields["excerpts"] = excerpts
            try await rejectState(fields)
        }
        let originalQuote = "a\u{0323}\u{0301}"
        let alteredQuote = "a\u{0301}\u{0323}"
        #expect(originalQuote == alteredQuote)
        #expect(originalQuote.utf8.count == alteredQuote.utf8.count)
        #expect(!originalQuote.utf8.elementsEqual(alteredQuote.utf8))
        let range = try #require(originalData.range(of: Data(originalQuote.utf8)))
        let template = try #require(state.excerpts.first).anchor
        let forged = GlifiStudioStudyAnchor(
            sourceRevisionID: template.sourceRevisionID,
            sourceContentDigest: template.sourceContentDigest,
            representationIdentifier: template.representationIdentifier,
            representationDigest: template.representationDigest,
            extractionContractIdentifier: template.extractionContractIdentifier,
            startUTF8: range.lowerBound, endUTF8: range.upperBound, quote: alteredQuote,
            sourceRanges: [.init(startUTF8: range.lowerBound, endUTF8: range.upperBound)])
        let id = SHA256.hash(data: try BDDVariantAssertions.encode(forged))
            .map { String(format: "%02x", $0) }.joined()
        #expect(!state.excerpts.contains { $0.id == id })
        var proposed = state
        proposed.excerpts.append(
            .init(id: id, title: "Citazione con byte alterati", anchor: forged))
        proposed.order.append(id)
        try await rejectState(#require(object(proposed) as? [String: Any]))
    }

    func verifyRejectedAnchors() async throws {
        #expect(rejected.count == 4)
        #expect(
            rejected.map(\.code) == [
                "study.immutable-anchor", "study.immutable-anchor", "study.immutable-anchor",
                "study.invalid-anchor",
            ])
        #expect(
            rejected.allSatisfy { $0.category == "invalidInput" && $0.retainedState == "unchanged" }
        )
        try await verifyUnchanged()
    }

    func danglingReferences() async throws {
        let state = try #require(baselineState)
        let fields = try #require(object(state) as? [String: Any])
        var missingOrder = fields
        missingOrder["order"] = ["missing-item"]
        try await rejectState(missingOrder)
        var badPins = fields
        badPins["comparisonExcerptIDs"] = [state.excerpts[0].id, "missing-a", "missing-b"]
        try await rejectState(badPins)
        var badGroup = state
        badGroup.excerpts[0].groupID = "missing-group"
        try await rejectState(#require(object(badGroup) as? [String: Any]))
        var badNote = state
        badNote.notes = [
            .init(
                id: "nota", title: "Conclusione", text: "Nota personale",
                excerptIDs: ["missing-excerpt"])
        ]
        badNote.order.append("nota")
        try await rejectState(#require(object(badNote) as? [String: Any]))
        do {
            _ = try await #require(session).resolveStudyExcerpt(excerptID: "missing-excerpt")
            Issue.record("An unknown excerpt was resolved")
        } catch let failure as GlifiStudioFailure { rejected.append(failure) }
    }

    func verifyReferences() async throws {
        #expect(rejected.count == 5)
        #expect(
            rejected.allSatisfy { $0.code.hasPrefix("study.") && $0.retainedState == "unchanged" })
        #expect(
            rejected.map(\.code) == [
                "study.invalid-state", "study.resource-limit", "study.invalid-anchor",
                "study.invalid-note", "study.unknown-excerpt",
            ])
        #expect(
            rejected.map(\.category) == [
                "invalidInput", "insufficientResources", "invalidInput", "invalidInput",
                "invalidInput",
            ])
        try await verifyUnchanged()
    }

    func crossProject() async throws {
        let destination = try #require(root).appending(path: "Other.glifi")
        let other = try await GlifiStudioService().createProject(at: destination)
        let source = try #require(root).appending(path: "fonte-italiana.txt")
        _ = try await other.importText(at: source, format: .plainText)
        let before = try await other.snapshot()
        let state = try #require(baselineState)
        #expect(before.projectID != state.projectID)
        do {
            _ = try await other.saveStudyState(state, expectedRevision: 0)
            Issue.record("A notebook crossed the project identity boundary")
        } catch let failure as GlifiStudioFailure {
            rejected.append(failure)
            #expect(failure.code == "study.project-mismatch")
            #expect(failure.category == "invalidInput")
        }
        #expect(try await other.snapshot() == before)
        #expect(try await other.studyState().projectID == before.projectID)
        #expect(try await other.studyState().excerpts.isEmpty)
        await other.close()
    }

    func verifyCrossProject() async throws {
        #expect(rejected.count == 1)
        try await verifyUnchanged()
    }

    func cancelNative() async throws {
        for operation in GlifiStudioStudyOperation.allCases {
            let active = try #require(session)
            parameters = try await parameters(for: operation)
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await self.typedResult(operation, session: active)
            }
            do {
                _ = try await task.value
                Issue.record("A preventively cancelled study API completed")
            } catch let failure as GlifiStudioFailure { rejected.append(failure) }
        }
    }

    func verifyNativeCancellation() async throws {
        #expect(rejected.count == GlifiStudioStudyOperation.allCases.count)
        #expect(
            rejected.allSatisfy {
                $0.code == "study.cancelled" && $0.category == "cancelled"
                    && $0.retainedState == "unchanged" && $0.retryDisposition == "newRequest"
            })
        try await verifyUnchanged()
    }

    func restoreSplitGrapheme() async throws {
        let state = try #require(baselineState)
        let template = try #require(state.excerpts.first).anchor
        let bytes = originalData
        let scalar = Data("👩".utf8)
        let range = try #require(bytes.range(of: scalar))
        #expect(scalar.count == 4)
        #expect("👩🏽‍🔬".count == 1)
        let forged = GlifiStudioStudyAnchor(
            sourceRevisionID: template.sourceRevisionID,
            sourceContentDigest: template.sourceContentDigest,
            representationIdentifier: template.representationIdentifier,
            representationDigest: template.representationDigest,
            extractionContractIdentifier: template.extractionContractIdentifier,
            startUTF8: range.lowerBound, endUTF8: range.upperBound, quote: "👩",
            sourceRanges: [.init(startUTF8: range.lowerBound, endUTF8: range.upperBound)])
        let canonical = try BDDVariantAssertions.encode(forged)
        let id = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        #expect(!state.excerpts.contains { $0.id == id })
        #expect(Data(bytes[range]) == scalar)
        var proposed = state
        proposed.excerpts.append(.init(id: id, title: "Grafema spezzato", anchor: forged))
        proposed.order.append(id)
        do {
            _ = try await #require(session).saveStudyState(
                proposed, expectedRevision: state.revision)
            Issue.record("A valid scalar range split a captured extended grapheme cluster")
        } catch let failure as GlifiStudioFailure { rejected.append(failure) }
    }

    func verifySplitGraphemeRejected() async throws {
        #expect(rejected.count == 1)
        #expect(rejected.first?.code == "study.invalid-anchor")
        #expect(rejected.first?.category == "invalidInput")
        #expect(rejected.first?.retainedState == "unchanged")
        try await verifyUnchanged()
    }

    private func object<Value: Encodable>(_ value: Value) throws -> Any {
        try BDDVariantAssertions.object(BDDVariantAssertions.encode(value))
    }

    func cleanup() async throws {
        if let session { await session.close() }
        if let root { try FileManager.default.removeItem(at: root) }
    }
}

@MainActor
private var studyWorld: BDDStudyWorld { Scenario.state(BDDStudyWorld.init) }

@MainActor
func registerStudySteps() {
    AfterScenario { _ in try await studyWorld.cleanup() }
    Given("un progetto di studio con una fonte italiana originale") { _, _ in
        try await studyWorld.prepare()
    }
    Given("la variante di studio {string} su citazioni italiane originali") { match, _ in
        try await studyWorld.prepareVariant(match.first(\.string))
    }
    When("richiedo lo stato di studio tramite la CLI reale") { _, _ in
        try await studyWorld.requestState()
    }
    Then("lo studio contiene zero estratti note gruppi e selezioni di confronto") { _, _ in
        try await studyWorld.verifyEmptyState()
    }
    When("eseguo la variante di studio in fase {word}") { match, _ in
        try await studyWorld.execute(match.first(\.word))
    }
    Then(#/^il risultato di studio coincide con l'API nativa e con i fatti JSON (.+)$/#) {
        match, _ in try await studyWorld.verifyNominal(String(match.1))
    }
    Then("lo studio riaperto conserva contenuto e provenienza senza nuove scritture") { _, _ in
        try await studyWorld.verifyReopening()
    }
    Then("lo studio fallisce con codice {string} e categoria {string} senza scritture") {
        match, _ in
        try await studyWorld.verifyFailure(
            code: match[\.string, index: 0], category: match[\.string, index: 1])
    }
    When("raccolgo due passaggi originali e li collego a note gruppi ordine e confronto") { _, _ in
        try await studyWorld.collectWorkflow()
    }
    Then("il taccuino conserva citazioni esatte e conclusioni personali distinte dalle fonti") {
        _, _ in try await studyWorld.verifyWorkflowState()
    }
    When("riapro lo studio e torno alle fonti dei due passaggi") { _, _ in
        try await studyWorld.reopenWorkflow()
    }
    Then("revisioni digest intervalli e byte originali coincidono con quelli raccolti") { _, _ in
        try await studyWorld.verifyOriginals()
    }
    Then("gli export JSON e Markdown sono riproducibili e rispettano l'ordine del taccuino") {
        _, _ in try await studyWorld.verifyExports()
    }
    When("tento di salvare una revisione di studio superata") { _, _ in
        try await studyWorld.staleSave()
    }
    Then("il conflitto ottimistico conserva lo studio e l'intero progetto") { _, _ in
        try await studyWorld.verifyStaleSave()
    }
    When("tento di riscrivere citazione digest e coordinate dell'estratto raccolto") { _, _ in
        try await studyWorld.tamperAnchors()
    }
    Then("ogni anchor alterata è rifiutata e la fonte originale resta verificata") { _, _ in
        try await studyWorld.verifyRejectedAnchors()
    }
    When("propongo riferimenti di studio mancanti o più di due passaggi in confronto") { _, _ in
        try await studyWorld.danglingReferences()
    }
    Then("nessun riferimento invalido modifica estratti note o progetto") { _, _ in
        try await studyWorld.verifyReferences()
    }
    When("ripristino lo stato in un progetto diverso con gli stessi byte sorgenti") { _, _ in
        try await studyWorld.crossProject()
    }
    Then("il progetto destinatario rifiuta lo stato e conserva la propria identità") { _, _ in
        try await studyWorld.verifyCrossProject()
    }
    When("ripristino una nuova anchor con hash valido che divide un emoji composto") { _, _ in
        try await studyWorld.restoreSplitGrapheme()
    }
    Then("il ripristino rifiuta il grafema spezzato senza modificare lo studio") { _, _ in
        try await studyWorld.verifySplitGraphemeRejected()
    }
    When("precancello ciascuna delle sei API native di studio") { _, _ in
        try await studyWorld.cancelNative()
    }
    Then("ogni cancellazione è tipizzata e non scrive una nuova generazione") { _, _ in
        try await studyWorld.verifyNativeCancellation()
    }
}
