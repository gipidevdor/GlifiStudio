// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Testing

@testable import GlifiKit

struct GlifiResearchCommandTests {
    @Test("Il trasporto di ricerca conserva richieste, risultati e failure delle API native")
    func researchOperationsHaveNativeParity() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiResearchParity-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "Research.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        let data = Data("id,testo,gruppo\na,cane gatto,A\nb,gatto topo,B\nc,cane topo,A\n".utf8)
        let mapping = GlifiStudioTabularMapping(
            textColumns: [2], identifierColumn: 1,
            variables: [.init(column: 3, name: "gruppo")])
        let imported = try await session.importTabular(
            data: data, options: .init(), mapping: mapping)
        let ids = imported.sourceRevisionIDs
        let analysis = GlifiStudioTextAnalysisRequest.clara(
            matrix: [[1, 0], [0, 1], [1, 1]], clusterCount: 2, seed: 9, sampleSize: 3)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(analysis)
        let saved = try await session.captureSavedAnalysis(
            requestJSON: analysis.canonicalData(), resultJSON: JSONEncoder().encode(result),
            title: "Gruppi", sourceRevisionIDs: ids, createdAtUnixMilliseconds: 1_700_000_000_000)
        _ = try await session.createSavedAnalysisInvestigation(
            artifactID: saved.artifactID, question: "Quali gruppi sono stati acquisiti?")
        let state = try await session.researchState()
        let table = try await GlifiStudioTabularImporter.preview(data: data, options: .init())
        let statisticsRequest = GlifiStudioStatisticsRequest(
            operation: .descriptive, values: [[1, 2, 3]])
        let statisticsResult = try await GlifiStudioStatisticsWorkbench.evaluate(statisticsRequest)
        for operation in GlifiStudioResearchOperation.allCases {
            var parameters = Parameters()
            switch operation {
            case .workbenchCapture:
                parameters.command = "statistics"
                parameters.requestJSON = try CommandJSON.encode(statisticsRequest)
                parameters.resultJSON = try CommandJSON.encode(statisticsResult)
                parameters.methodIdentifier = statisticsResult.methodIdentifier
                parameters.title = "Statistica acquisita"
                parameters.createdAtUnixMilliseconds = 1_700_000_000_000
            case .state, .savedList: break
            case .saveState:
                parameters.state = state
                parameters.expectedRevision = state.revision
            case .select:
                parameters.filter = .init(fieldID: "gruppo", value: .text("A"), query: "cane")
            case .tabularPreview:
                parameters.data = data
                parameters.options = .init()
            case .tabularMap:
                parameters.table = table
                parameters.mapping = mapping
            case .tabularImport:
                parameters.data = Data("id,testo,gruppo\nd,nuovo testo,C\n".utf8)
                parameters.options = .init()
                parameters.mapping = mapping
            case .tabularSource: parameters.artifactID = imported.originalArtifactID
            case .savedRead, .savedExport: parameters.artifactID = saved.artifactID
            case .savedInvestigation:
                parameters.artifactID = saved.artifactID
                parameters.question = "Quali gruppi sono stati acquisiti?"
            case .savedRun:
                parameters.requestJSON = try analysis.canonicalData()
                parameters.title = "Gruppi"
                parameters.sourceRevisionIDs = ids
            case .capture:
                parameters.requestJSON = try analysis.canonicalData()
                parameters.resultJSON = try JSONEncoder().encode(result)
                parameters.title = "Gruppi"
                parameters.sourceRevisionIDs = ids
                parameters.createdAtUnixMilliseconds = 1_700_000_000_000
            case .deriveVariable:
                parameters.artifactID = saved.artifactID
                parameters.fieldID = "cluster"
                parameters.label = "Gruppo derivato"
                parameters.expectedRevision = state.revision
            }
            let wire = Request(operation: operation, parameters: parameters)
            let referenceURL = root.appending(path: "Native-\(operation.rawValue).glifi")
            let actualURL = root.appending(path: "Wire-\(operation.rawValue).glifi")
            try FileManager.default.copyItem(at: project, to: referenceURL)
            try FileManager.default.copyItem(at: project, to: actualURL)
            let reference = try await GlifiStudioService().openProject(at: referenceURL)
            let actualSession = try await GlifiStudioService().openProject(at: actualURL)
            let expected = try await native(operation, parameters, session: reference)
            let actual = try await GlifiStudioResearchCommand.execute(
                json: JSONEncoder().encode(wire), session: actualSession)
            #expect(actual.json == expected.json, "Operation: \(operation.rawValue)")
            let snapshot = try paritySnapshot(project, operation: operation)
            try exportKitCLIParityFixture(
                command: "research-call", operation: String(describing: operation), request: wire,
                result: expected, projectURL: snapshot)
            await reference.close()
            await actualSession.close()
        }
        await session.close()
    }

    @Test(
        "Il taglio gerarchico salvato diventa una variabile con provenienza senza nuovo clustering")
    func savedHierarchyBecomesADerivedVariable() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "GlifiResearchHAC-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let imported = try await session.importTabular(
            data: Data("id,testo\na,cane gatto\nb,gatto topo\nc,cane topo\n".utf8),
            options: .init(), mapping: .init(textColumns: [2], identifierColumn: 1))
        let request = GlifiStudioTextAnalysisRequest.hierarchical(
            matrix: [[0, 2, 1], [2, 0, 1], [1, 1, 0]], linkage: "average")
        let saved = try await session.runSavedAnalysis(
            requestJSON: request.canonicalData(), title: "Albero",
            sourceRevisionIDs: imported.sourceRevisionIDs)
        let before = try await session.researchState()
        let derived = try await session.deriveResearchVariable(
            artifactID: saved.artifactID, fieldID: "cluster", label: "Gruppo gerarchico",
            expectedRevision: before.revision, clusterCount: 2)
        #expect(derived.records.count == 3)
        #expect(
            derived.fields.first(where: { $0.id == "cluster" })?.derivation?.parameters[
                "clusterCount"] == "2")
        #expect(Set(derived.records.compactMap { $0.values["cluster"]?.codingValue }).count == 2)
        #expect(
            derived.records.allSatisfy { $0.derivationArtifactIDs?["cluster"] == saved.artifactID })
        #expect(try await session.savedAnalyses().count == 1)
        await session.close()
    }

    @Test("Richieste sconosciute e acquisizioni incoerenti non modificano il progetto")
    func rejectedResearchRequestsPreserveState() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "GlifiResearchRejected-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let before = try await session.snapshot()
        for parameters in ["{\"unexpected\":true}", "{\"title\":\"ignored\"}"] {
            let json =
                "{\"schema\":\"studio.glifi.research-command-request\",\"schemaVersion\":1,\"operation\":\"state\",\"parameters\":\(parameters)}"
            await #expect(throws: GlifiStudioFailure.self) {
                try await GlifiStudioResearchCommand.execute(
                    json: Data(json.utf8), session: session)
            }
        }
        let request = GlifiStudioTextAnalysisRequest.dissimilarities(
            matrix: [[1, 0], [0, 1]], metric: .euclidean)
        await #expect(throws: GlifiStudioFailure.self) {
            try await session.captureSavedAnalysis(
                requestJSON: request.canonicalData(), resultJSON: Data("{}".utf8),
                title: "Incoerente", sourceRevisionIDs: [])
        }
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    @Test(
        "Anteprime e stati oltre un MiB attraversano file JSON senza cambiare limiti o API native")
    func largeTableAndStateFilesHaveNativeParity() async throws {
        let fixture = try await fileFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let session = fixture.session
        let repeated = String(repeating: "x", count: 220)
        let data = Data(
            ("id,testo,nota\n"
                + (0..<5_000).map {
                    "row\($0),Testo \($0),\(repeated)\n"
                }.joined()).utf8)
        let table = try await GlifiStudioTabularImporter.preview(data: data, options: .init())
        let tableJSON = try CommandJSON.encode(table)
        #expect(tableJSON.count > 1_048_576)
        let tableURL = fixture.root.appending(path: "large-table.json")
        try tableJSON.write(to: tableURL)
        let mapping = GlifiStudioTabularMapping(textColumns: [2], identifierColumn: 1)
        let expectedMap = try await GlifiStudioCommandResult(
            GlifiStudioTabularImporter.map(table: table, mapping: mapping))
        let tableEnvelope = try fileRequest(
            .tabularMap,
            parameters: [
                "tablePath": tableURL.path, "mapping": try object(mapping),
            ])
        #expect(tableEnvelope.count < 1_048_576)
        let baseline = try await session.snapshot()
        let mapped = try await GlifiStudioResearchCommand.execute(
            json: tableEnvelope, session: session)
        #expect(mapped.json == expectedMap.json)
        #expect(try await session.snapshot() == baseline)

        var proposed = fixture.state
        for index in 0..<20 {
            let id = "large-\(index)"
            proposed.fields.append(.init(id: id, label: "Campo \(index)", type: .text))
            proposed.records[0].values[id] = .text(String(repeating: "v", count: 65_536))
        }
        let stateJSON = try CommandJSON.encode(proposed)
        #expect(stateJSON.count > 1_048_576)
        let stateURL = fixture.root.appending(path: "large-state.json")
        try stateJSON.write(to: stateURL)
        let nativeURL = fixture.root.appending(path: "Native.glifi")
        try FileManager.default.copyItem(at: fixture.project, to: nativeURL)
        let nativeSession = try await GlifiStudioService().openProject(at: nativeURL)
        let expectedState = try await nativeSession.saveResearchState(
            proposed, expectedRevision: proposed.revision)
        let stateEnvelope = try fileRequest(
            .saveState,
            parameters: [
                "statePath": stateURL.path, "expectedRevision": proposed.revision,
            ])
        #expect(stateEnvelope.count < 1_048_576)
        let changed = try await GlifiStudioResearchCommand.execute(
            json: stateEnvelope, session: session)
        #expect(changed.json == (try CommandJSON.encode(expectedState)))
        #expect(try await session.researchState() == expectedState)
        let nativeSnapshot = try await nativeSession.snapshot()
        #expect(try await session.snapshot() == nativeSnapshot)
        let snapshot = try await session.snapshot()
        await nativeSession.close()
        await session.close()
        let reopened = try await GlifiStudioService().openProject(at: fixture.project)
        #expect(try await reopened.researchState() == expectedState)
        #expect(try await reopened.snapshot() == snapshot)
        await reopened.close()
    }

    @Test("I file DTO rifiutano alias contraddittori JSON ignoto malformato e oggetti non regolari")
    func structuredFileAdmissionPreservesTheProject() async throws {
        let fixture = try await fileFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let baseline = try await fixture.session.snapshot()
        let variants: [(GlifiStudioResearchOperation, String, String, Data, [String: Any], Int)] = [
            (
                .tabularMap, "table", "tablePath", try CommandJSON.encode(fixture.table),
                [
                    "mapping": try object(
                        GlifiStudioTabularMapping(textColumns: [2], identifierColumn: 1))
                ], 64 * 1_048_576
            ),
            (
                .saveState, "state", "statePath", try CommandJSON.encode(fixture.state),
                ["expectedRevision": fixture.state.revision], 32 * 1_048_576
            ),
        ]
        for (operation, inlineKey, pathKey, json, base, maximum) in variants {
            let validURL = fixture.root.appending(path: "\(inlineKey)-valid.json")
            try json.write(to: validURL)
            var p = base
            p[pathKey] = validURL.path
            p[inlineKey] = try JSONSerialization.jsonObject(with: json)
            try await expectFileFailure(
                operation, parameters: p, code: "command.invalid-request",
                session: fixture.session, baseline: baseline)
            p = base
            let invalidURL = fixture.root.appending(path: "\(inlineKey)-invalid.json")
            p[pathKey] = invalidURL.path
            var unknown = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
            unknown["unexpected"] = true
            try JSONSerialization.data(withJSONObject: unknown).write(to: invalidURL)
            try await expectFileFailure(
                operation, parameters: p, code: "command.unknown-field",
                session: fixture.session, baseline: baseline)
            for bytes in [Data("{".utf8), Data([0xFF])] {
                try bytes.write(to: invalidURL)
                try await expectFileFailure(
                    operation, parameters: p, code: "text-analysis.invalid-request",
                    session: fixture.session, baseline: baseline)
            }

            let link = fixture.root.appending(path: "\(inlineKey)-link.json")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: validURL)
            p[pathKey] = link.path
            try await expectFileFailure(
                operation, parameters: p, code: "command.source-open-failed",
                category: "transientIO", session: fixture.session, baseline: baseline)
            let pipe = fixture.root.appending(path: "\(inlineKey)-pipe")
            try #require(Darwin.mkfifo(pipe.path, 0o600) == 0)
            p[pathKey] = pipe.path
            try await expectFileFailure(
                operation, parameters: p, code: "command.invalid-request",
                session: fixture.session, baseline: baseline)
            p[pathKey] = fixture.root.path
            try await expectFileFailure(
                operation, parameters: p, code: "command.invalid-request",
                session: fixture.session, baseline: baseline)

            let oversized = fixture.root.appending(path: "\(inlineKey)-oversized.json")
            try Data().write(to: oversized)
            let handle = try FileHandle(forWritingTo: oversized)
            try handle.truncate(atOffset: UInt64(maximum + 1))
            try handle.close()
            p[pathKey] = oversized.path
            try await expectFileFailure(
                operation, parameters: p, code: "command.resource-limit",
                category: "insufficientResources", session: fixture.session, baseline: baseline)
            p[pathKey] = validURL.path
            let request = try fileRequest(operation, parameters: p)
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await GlifiStudioResearchCommand.execute(
                    json: request, session: fixture.session)
            }
            do {
                _ = try await task.value
                Issue.record("Expected pre-cancelled DTO file rejection")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "command.cancelled")
                #expect(failure.category == "cancelled")
            }
            #expect(try await fixture.session.snapshot() == baseline)
        }
        await fixture.session.close()
    }

    @Test("I file DTO conservano le validazioni di dominio e non ammettono envelope inline grandi")
    func structuredFileTransportPreservesDomainLimits() async throws {
        let fixture = try await fileFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let baseline = try await fixture.session.snapshot()
        var state = fixture.state
        for index in 0..<257 {
            state.fields.append(.init(id: "field-\(index)", label: "Campo \(index)", type: .text))
        }
        let url = fixture.root.appending(path: "invalid-state.json")
        try CommandJSON.encode(state).write(to: url)
        try await expectFileFailure(
            .saveState,
            parameters: ["statePath": url.path, "expectedRevision": state.revision],
            code: "research.invalid-state", session: fixture.session, baseline: baseline)
        let tooLarge = Data(repeating: 0x20, count: 1_048_577)
        do {
            _ = try await GlifiStudioResearchCommand.execute(
                json: tooLarge, session: fixture.session)
            Issue.record("Expected unchanged research envelope budget")
        } catch let failure {
            #expect(failure.category == "insufficientResources")
        }
        #expect(try await fixture.session.snapshot() == baseline)
        await fixture.session.close()
    }

    private func fileFixture() async throws -> (
        root: URL, project: URL, session: GlifiStudioProjectSession,
        table: GlifiStudioTabularTable, state: GlifiStudioResearchState
    ) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiResearchFiles-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let project = root.appending(path: "Files.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        let data = Data("id,testo\na,Cane e gatto\n".utf8)
        _ = try await session.importTabular(
            data: data, options: .init(),
            mapping: .init(textColumns: [2], identifierColumn: 1))
        return (
            root, project, session,
            try await GlifiStudioTabularImporter.preview(data: data, options: .init()),
            try await session.researchState()
        )
    }

    private func fileRequest(_ operation: GlifiStudioResearchOperation, parameters: [String: Any])
        throws -> Data
    {
        try JSONSerialization.data(
            withJSONObject: [
                "schema": GlifiStudioResearchCommand.schema, "schemaVersion": 1,
                "operation": operation.rawValue, "parameters": parameters,
            ], options: [.sortedKeys])
    }

    private func object<Value: Encodable>(_ value: Value) throws -> Any {
        try JSONSerialization.jsonObject(with: CommandJSON.encode(value))
    }

    private func expectFileFailure(
        _ operation: GlifiStudioResearchOperation, parameters: [String: Any], code: String,
        category: String = "invalidInput", session: GlifiStudioProjectSession,
        baseline: GlifiStudioProjectSnapshot
    ) async throws {
        let request = try fileRequest(operation, parameters: parameters)
        do {
            _ = try await GlifiStudioResearchCommand.execute(json: request, session: session)
            Issue.record("Expected file DTO rejection: \(code)")
        } catch let failure {
            #expect(failure.code == code)
            #expect(failure.category == category)
        }
        #expect(try await session.snapshot() == baseline)
    }

    private func native(
        _ operation: GlifiStudioResearchOperation, _ p: Parameters,
        session: GlifiStudioProjectSession
    ) async throws -> GlifiStudioCommandResult {
        switch operation {
        case .workbenchCapture:
            return try await GlifiStudioCommandResult(
                session.captureWorkbenchAnalysis(
                    command: #require(p.command), requestJSON: #require(p.requestJSON),
                    resultJSON: #require(p.resultJSON),
                    methodIdentifier: #require(p.methodIdentifier),
                    title: #require(p.title), sourceRevisionIDs: p.sourceRevisionIDs ?? [],
                    createdAtUnixMilliseconds: p.createdAtUnixMilliseconds))
        case .state: return try await GlifiStudioCommandResult(session.researchState())
        case .saveState:
            return try await GlifiStudioCommandResult(
                session.saveResearchState(
                    #require(p.state), expectedRevision: #require(p.expectedRevision)))
        case .select:
            return try await GlifiStudioCommandResult(
                session.selectResearchSources(#require(p.filter)))
        case .tabularPreview:
            return try await GlifiStudioCommandResult(
                GlifiStudioTabularImporter.preview(
                    data: #require(p.data), options: #require(p.options)))
        case .tabularMap:
            return try await GlifiStudioCommandResult(
                GlifiStudioTabularImporter.map(
                    table: #require(p.table), mapping: #require(p.mapping)))
        case .tabularImport:
            return try await GlifiStudioCommandResult(
                session.importTabular(
                    data: #require(p.data), options: #require(p.options),
                    mapping: #require(p.mapping)))
        case .tabularSource:
            return try await GlifiStudioCommandResult(
                session.tabularSource(artifactID: #require(p.artifactID)))
        case .savedInvestigation:
            return try await GlifiStudioCommandResult(
                session.createSavedAnalysisInvestigation(
                    artifactID: #require(p.artifactID), question: #require(p.question)))
        case .savedList: return try await GlifiStudioCommandResult(session.savedAnalyses())
        case .savedRead:
            return try await GlifiStudioCommandResult(
                session.savedAnalysis(artifactID: #require(p.artifactID)))
        case .savedRun:
            return try await GlifiStudioCommandResult(
                session.runSavedAnalysis(
                    requestJSON: #require(p.requestJSON), title: #require(p.title),
                    sourceRevisionIDs: #require(p.sourceRevisionIDs)))
        case .capture:
            return try await GlifiStudioCommandResult(
                session.captureSavedAnalysis(
                    requestJSON: #require(p.requestJSON), resultJSON: #require(p.resultJSON),
                    title: #require(p.title),
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    createdAtUnixMilliseconds: p.createdAtUnixMilliseconds))
        case .savedExport:
            return try await GlifiStudioCommandResult(
                session.exportSavedAnalysis(artifactID: #require(p.artifactID)))
        case .deriveVariable:
            return try await GlifiStudioCommandResult(
                session.deriveResearchVariable(
                    artifactID: #require(p.artifactID), fieldID: #require(p.fieldID),
                    label: #require(p.label),
                    expectedRevision: #require(p.expectedRevision)))
        }
    }

    private func paritySnapshot(_ project: URL, operation: GlifiStudioResearchOperation) throws
        -> URL?
    {
        guard let directory = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"]
        else { return nil }
        let url = URL(fileURLWithPath: directory).appending(
            path: "Research-\(operation.rawValue)-\(UUID()).glifi")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: project, to: url)
        return url
    }

    private struct Request: Codable {
        var schema = "studio.glifi.research-command-request"
        var schemaVersion = 1
        let operation: GlifiStudioResearchOperation
        let parameters: Parameters
    }
    private struct Parameters: Codable {
        var command: String?
        var methodIdentifier: String?
        var state: GlifiStudioResearchState?
        var expectedRevision: Int?
        var filter: GlifiStudioResearchFilter?
        var data: Data?
        var options: GlifiStudioTabularOptions?
        var table: GlifiStudioTabularTable?
        var mapping: GlifiStudioTabularMapping?
        var artifactID: String?
        var fieldID: String?
        var label: String?
        var title: String?
        var question: String?
        var sourceRevisionIDs: [String]?
        var requestJSON: Data?
        var resultJSON: Data?
        var createdAtUnixMilliseconds: Int64?
    }
}
