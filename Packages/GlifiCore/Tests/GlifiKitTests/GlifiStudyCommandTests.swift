// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiStudyCommandTests {
    @Test("Le sei operazioni di studio conservano risultati nativi JSON CLI e failure rigorose")
    func allStudyOperationsHaveNativeParity() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "StudyParity-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "Base.glifi")
        let session = try await GlifiStudioService().createProject(at: url)
        let imported = try await session.importTabular(
            data: Data("id,testo\na,Un testo italiano originale.\n".utf8), options: .init(),
            mapping: .init(textColumns: [2], identifierColumn: 1))
        let source = try #require(imported.sourceRevisionIDs.first)
        let state = try await session.collectStudyExcerpt(
            sourceRevisionID: source, selection: .characters(start: 0, end: 8), title: "Passaggio",
            expectedRevision: 0)
        let excerpt = try #require(state.excerpts.first)
        for operation in GlifiStudioStudyOperation.allCases {
            var parameters = Parameters()
            switch operation {
            case .state: break
            case .saveState:
                parameters.state = state
                parameters.expectedRevision = state.revision
            case .collect:
                parameters.sourceRevisionID = source
                parameters.selection = .characters(start: 9, end: 17)
                parameters.title = "Secondo passaggio"
                parameters.expectedRevision = state.revision
            case .resolve: parameters.excerptID = excerpt.id
            case .export: parameters.format = .json
            case .original: parameters.sourceRevisionID = source
            }
            let request = Request(operation: operation, parameters: parameters)
            let nativeURL = root.appending(path: "Native-\(operation.rawValue).glifi")
            let actualURL = root.appending(path: "Actual-\(operation.rawValue).glifi")
            try FileManager.default.copyItem(at: url, to: nativeURL)
            try FileManager.default.copyItem(at: url, to: actualURL)
            let native = try await GlifiStudioService().openProject(at: nativeURL)
            let actual = try await GlifiStudioService().openProject(at: actualURL)
            let expected = try await reference(operation, p: parameters, session: native)
            let observed = try await GlifiStudioStudyCommand.execute(
                json: CommandJSON.encode(request), session: actual)
            #expect(observed.json == expected.json)
            let warmed = try await actual.snapshot()
            var invalid = try #require(
                JSONSerialization.jsonObject(with: CommandJSON.encode(request)) as? [String: Any])
            var invalidParameters = try #require(invalid["parameters"] as? [String: Any])
            invalidParameters["unknown"] = true
            invalid["parameters"] = invalidParameters
            do {
                _ = try await GlifiStudioStudyCommand.execute(
                    json: JSONSerialization.data(withJSONObject: invalid), session: actual)
                Issue.record("Expected strict study parameter rejection")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "command.unknown-field")
                #expect(failure.category == "invalidInput")
                #expect(failure.retainedState == "unchanged")
            }
            #expect(try await actual.snapshot() == warmed)
            var fixtureURL: URL?
            if let directory = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"]
            {
                let copy = URL(fileURLWithPath: directory).appending(
                    path: "Study-\(operation.rawValue)-\(UUID()).glifi")
                try FileManager.default.copyItem(at: url, to: copy)
                fixtureURL = copy
            }
            try exportKitCLIParityFixture(
                command: "study-call", operation: String(describing: operation), request: request,
                result: expected, projectURL: fixtureURL)
            await native.close()
            await actual.close()
        }
        await session.close()
    }

    @Test("Il ripristino grande usa statePath esclusivo e il decoder export resta rigoroso")
    func largeStatePathAndStrictRestorationHaveNativeParity() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "StudyFile-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "Project.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        var state = try await session.studyState()
        state.notes = [
            .init(id: "a", title: "Prima", text: String(repeating: "a", count: 700_000)),
            .init(id: "b", title: "Seconda", text: String(repeating: "b", count: 700_000)),
        ]
        state.order = ["a", "b"]
        let bytes = try CommandJSON.encode(state)
        #expect(bytes.count > 1_048_576)
        let path = root.appending(path: "state.json")
        try bytes.write(to: path)
        var p = Parameters()
        p.statePath = path.path
        p.expectedRevision = 0
        let wire = Request(operation: .saveState, parameters: p)
        let nativeURL = root.appending(path: "Native.glifi")
        try FileManager.default.copyItem(at: project, to: nativeURL)
        let native = try await GlifiStudioService().openProject(at: nativeURL)
        let expectedState = try await native.saveStudyState(state, expectedRevision: 0)
        await native.close()
        if let directory = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"] {
            let inputs = URL(fileURLWithPath: directory).appending(
                path: "parityInputs/Study-\(UUID())")
            try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
            let stagedProject = inputs.appending(path: "Before.glifi")
            let stagedState = inputs.appending(path: "state.json")
            try FileManager.default.copyItem(at: project, to: stagedProject)
            try bytes.write(to: stagedState)
            var stagedParameters = p
            stagedParameters.statePath = stagedState.path
            try exportKitCLIParityFixture(
                command: "study-call", operation: "saveState",
                request: Request(operation: .saveState, parameters: stagedParameters),
                result: expectedState, projectURL: stagedProject, variant: "largeStatePath")
        }
        let changed = try await GlifiStudioStudyCommand.execute(
            json: CommandJSON.encode(wire), session: session)
        let restored = try JSONDecoder().decode(GlifiStudioStudyState.self, from: changed.json)
        #expect(changed.json == (try CommandJSON.encode(expectedState)))
        #expect(restored.revision == 1)
        #expect(restored.notes == state.notes)
        let exported = try await session.exportStudy()
        #expect(try GlifiStudioStudyExport.decode(json: exported).state == restored)
        let baseline = try await session.snapshot()
        p.state = .init(projectID: state.projectID)
        do {
            _ = try await GlifiStudioStudyCommand.execute(
                json: CommandJSON.encode(Request(operation: .saveState, parameters: p)),
                session: session)
            Issue.record("Expected mutually exclusive state inputs")
        } catch let failure {
            #expect(failure.code == "command.invalid-request")
        }
        var unknown = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        unknown["unknown"] = true
        #expect(throws: GlifiStudioFailure.self) {
            try GlifiStudioStudyExport.decode(json: JSONSerialization.data(withJSONObject: unknown))
        }
        var future = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        future["schemaVersion"] = 2
        #expect(throws: GlifiStudioFailure.self) {
            try GlifiStudioStudyExport.decode(json: JSONSerialization.data(withJSONObject: future))
        }
        #expect(try await session.snapshot() == baseline)
        await session.close()
        let reopened = try await GlifiStudioService().openProject(at: project)
        #expect(try await reopened.studyState() == restored)
        await reopened.close()
    }

    @Test("I payload nativi condivisi oltre budget falliscono prima di copie e codifica")
    func sharedNativeValuesAreBoundedBeforeEncoding() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "StudyBudget-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        var proposed = try await session.studyState()
        let text = String(repeating: "a", count: 1_048_576)
        proposed.notes = (0..<1_000).map { .init(id: "note-\($0)", title: "Nota", text: text) }
        proposed.order = proposed.notes.map(\.id)
        let before = try await session.snapshot()
        do {
            _ = try await session.saveStudyState(proposed, expectedRevision: 0)
            Issue.record("Expected cumulative native-state budget rejection")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.code == "study.resource-limit")
            #expect(failure.category == "insufficientResources")
        }
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    private func reference(
        _ operation: GlifiStudioStudyOperation, p: Parameters, session: GlifiStudioProjectSession
    ) async throws -> GlifiStudioCommandResult {
        switch operation {
        case .state: return try await GlifiStudioCommandResult(session.studyState())
        case .saveState:
            return try await GlifiStudioCommandResult(
                session.saveStudyState(
                    #require(p.state), expectedRevision: #require(p.expectedRevision)))
        case .collect:
            return try await GlifiStudioCommandResult(
                session.collectStudyExcerpt(
                    sourceRevisionID: #require(p.sourceRevisionID),
                    selection: #require(p.selection), title: #require(p.title),
                    expectedRevision: #require(p.expectedRevision)))
        case .resolve:
            return try await GlifiStudioCommandResult(
                session.resolveStudyExcerpt(excerptID: #require(p.excerptID)))
        case .export:
            return try await GlifiStudioCommandResult(
                session.exportStudy(format: #require(p.format)))
        case .original:
            return try await GlifiStudioCommandResult(
                session.studyOriginal(sourceRevisionID: #require(p.sourceRevisionID)))
        }
    }

    private struct Request: Encodable {
        let schema = "studio.glifi.study-command-request"
        let schemaVersion = 1
        let operation: GlifiStudioStudyOperation
        let parameters: Parameters
    }
    private struct Parameters: Codable {
        var state: GlifiStudioStudyState?
        var statePath: String?
        var expectedRevision: Int?
        var sourceRevisionID: String?
        var selection: GlifiStudioPassageSelection?
        var title: String?
        var excerptID: String?
        var format: GlifiStudioStudyExportFormat?
    }
}
