// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore
@testable import GlifiKit

struct GlifiWorkbenchCaptureTests {
    @Test("I tre laboratori conservano DTO, UInt64 e zero firmato con parità native e CLI")
    func standaloneModesHaveCaptureParity() async throws {
        for fixture in try await Self.fixtures() {
            let root = FileManager.default.temporaryDirectory.appending(
                path: "GlifiWorkbench-\(UUID())")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: root) }
            let url = root.appending(path: "Workbench.glifi")
            let session = try await GlifiStudioService().createProject(at: url)
            var state = try await session.researchState()
            state.preparation.stopwords = ["cane"]
            _ = try await session.saveResearchState(state, expectedRevision: 0)
            let saved = try await session.captureWorkbenchAnalysis(
                command: fixture.command, requestJSON: fixture.request, resultJSON: fixture.result,
                methodIdentifier: fixture.method, title: fixture.command,
                createdAtUnixMilliseconds: 1_700_000_000_000)
            let snapshot = try await session.snapshot()
            let wire = Wire(
                parameters: Parameters(
                    command: fixture.command, requestJSON: fixture.request,
                    resultJSON: fixture.result,
                    methodIdentifier: fixture.method, title: fixture.command))
            let actual = try await GlifiStudioResearchCommand.execute(
                json: CommandJSON.encode(wire), session: session)
            #expect(actual.json == (try CommandJSON.encode(saved)))
            #expect(try await session.snapshot() == snapshot)
            #expect(saved.transportIdentifier == "workbench-capture-v1")
            let unwrapped = try GlifiStudioWorkbenchCapture(saved: saved)
            #expect(unwrapped.command == fixture.command)
            #expect(
                unwrapped.requestJSON
                    == (try CommandJSON.canonicalize(fixture.request, maximumByteCount: 1_048_576)))
            #expect(
                unwrapped.resultJSON
                    == (try CommandJSON.canonicalize(
                        fixture.result, maximumByteCount: 8 * 1_048_576)))
            #expect(
                try JSONDecoder().decode(
                    GlifiStudioCorpusPreparation.self, from: saved.preparationJSON
                ).isIdentity)
            if fixture.command == "statistics" {
                let decoded = try JSONDecoder().decode(
                    GlifiStudioStatisticsRequest.self, from: unwrapped.requestJSON)
                #expect(decoded.parameters.seed == UInt64.max)
                #expect(decoded.values[0][0]?.sign == .minus)
            }
            if fixture.command == "operator" {
                let decoded = try JSONDecoder().decode(
                    GlifiStudioCoreOperatorRequest.self, from: unwrapped.requestJSON)
                #expect(decoded.seed == UInt64.max)
            }
            if let directory = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"]
            {
                let copy = URL(fileURLWithPath: directory).appending(
                    path: "Workbench-\(fixture.command)-\(UUID()).glifi")
                try FileManager.default.copyItem(at: url, to: copy)
                try exportKitCLIParityFixture(
                    command: "research-call", operation: "workbenchCapture", request: wire,
                    result: actual, projectURL: copy, variant: fixture.command)
            }
            await session.close()
            let reopened = try await GlifiStudioService().openProject(at: url)
            let restored = try await reopened.savedAnalysis(artifactID: saved.artifactID)
            #expect(
                try GlifiStudioWorkbenchCapture(saved: restored).resultJSON == unwrapped.resultJSON)
            #expect(try await reopened.savedAnalyses().count == 1)
            await reopened.close()
        }
    }

    @Test("L'export di un risultato statistico con fonti dichiarate conserva il trasporto proprio")
    func genericCaptureCanEnterTheDescriptiveReport() async throws {
        let fixture = try #require(try await Self.fixtures().first)
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkbenchReport-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Project.glifi"))
        let imported = try await session.importTabular(
            data: Data("testo\nCane e gatto\n".utf8), options: .init(),
            mapping: .init(textColumns: [1]))
        let saved = try await session.captureWorkbenchAnalysis(
            command: fixture.command, requestJSON: fixture.request, resultJSON: fixture.result,
            methodIdentifier: fixture.method, title: "Statistica",
            sourceRevisionIDs: imported.sourceRevisionIDs)
        let investigation = try await session.createSavedAnalysisInvestigation(
            artifactID: saved.artifactID, question: "Quale output numerico è stato acquisito?")
        let export = root.appending(path: "Export")
        _ = try await session.exportInvestigation(
            .init(investigationHeadEventID: investigation.investigation.headEventID), to: export)
        let manifest = try GlifiScientificExporter.verifyExport(at: export)
        let companion = try #require(
            manifest.files.first { GlifiSavedResearchReport.isFileName($0.path) })
        let payload = try JSONDecoder().decode(
            GlifiSavedResearchAnalysis.self,
            from: Data(contentsOf: export.appending(path: companion.path)))
        #expect(payload.effectiveTransportIdentifier == "workbench-capture-v1")
        #expect(payload.requestJSON == saved.requestJSON)
        #expect(payload.resultJSON == saved.resultJSON)
        await session.close()
    }

    @Test("Budget e metodi incoerenti falliscono prima della decodifica o di qualsiasi commit")
    func captureLimitsAndAdmission() async throws {
        let fixture = try #require(try await Self.fixtures().first)
        let url = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkbenchLimit-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let before = try await session.snapshot()
        do {
            _ = try await session.captureSavedAnalysis(
                requestJSON: Data(), resultJSON: Data(repeating: 0, count: 8 * 1_048_576 + 1),
                title: "Limite", sourceRevisionIDs: [])
            Issue.record("Expected size limit before JSON parsing")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "insufficientResources")
        }
        do {
            _ = try await session.captureWorkbenchAnalysis(
                command: fixture.command, requestJSON: fixture.request, resultJSON: fixture.result,
                methodIdentifier: fixture.method, title: "Limite",
                presentationJSON: Data(repeating: 0, count: 8 * 1_048_576 + 1))
            Issue.record("Expected presentation byte limit")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "insufficientResources")
        }
        await #expect(throws: GlifiStudioFailure.self) {
            try await session.captureWorkbenchAnalysis(
                command: fixture.command, requestJSON: fixture.request, resultJSON: fixture.result,
                methodIdentifier: "invented-method", title: "Incoerente")
        }
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    @Test(
        "I path autorizzati trasportano risultati grandi mantenendo limiti, file regolari ed esclusività"
    )
    func largeFileCaptureUsesBoundedDescriptors() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkbenchFiles-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        var parameters = GlifiStudioStatisticsParameters()
        parameters.unitIdentifier = String(repeating: "misura", count: 100_000)
        let request = GlifiStudioStatisticsRequest(
            operation: .descriptive, values: [[1, 2, 3]], parameters: parameters)
        let result = try await GlifiStudioStatisticsWorkbench.evaluate(request)
        let requestJSON = try CommandJSON.encode(request)
        let resultJSON = try CommandJSON.encode(result)
        #expect(resultJSON.count > 1_048_576)
        let requestPath = root.appending(path: "request.json")
        let resultPath = root.appending(path: "result.json")
        let presentationPath = root.appending(path: "presentation.json")
        try requestJSON.write(to: requestPath)
        try resultJSON.write(to: resultPath)
        try Data("{}".utf8).write(to: presentationPath)
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Project.glifi"))
        let expected = try await session.captureWorkbenchAnalysis(
            command: "statistics", requestJSON: requestJSON, resultJSON: resultJSON,
            methodIdentifier: result.methodIdentifier, title: "Dati grandi",
            presentationJSON: Data("{}".utf8),
            createdAtUnixMilliseconds: 1_700_000_000_000)
        let wire = PathWire(
            parameters: PathParameters(
                requestPath: requestPath.path, resultPath: resultPath.path,
                presentationPath: presentationPath.path,
                methodIdentifier: result.methodIdentifier))
        let encoded = try CommandJSON.encode(wire)
        #expect(encoded.count < 1_048_576)
        let actual = try await GlifiStudioResearchCommand.execute(json: encoded, session: session)
        #expect(actual.json == (try CommandJSON.encode(expected)))
        let before = try await session.snapshot()
        let symlink = root.appending(path: "linked-result.json")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: resultPath)
        var linked = wire
        linked.parameters.resultPath = symlink.path
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioResearchCommand.execute(
                json: CommandJSON.encode(linked), session: session)
        }
        var ambiguous = wire
        ambiguous.parameters.resultJSON = Data("{}".utf8)
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioResearchCommand.execute(
                json: CommandJSON.encode(ambiguous), session: session)
        }
        let oversized = root.appending(path: "oversized.json")
        try Data(repeating: 0, count: 8 * 1_048_576 + 1).write(to: oversized)
        var tooLarge = wire
        tooLarge.parameters.resultPath = oversized.path
        do {
            _ = try await GlifiStudioResearchCommand.execute(
                json: CommandJSON.encode(tooLarge), session: session)
            Issue.record("Expected byte limit before parsing the result file")
        } catch {
            #expect(error.category == "insufficientResources")
        }
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    @Test(
        "La preparazione è dichiarata per il corpus temporale e non ereditata dalle richieste manuali"
    )
    func preparationIsEffectiveRatherThanInherited() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkbenchPreparation-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let imported = try await session.importTabular(
            data: Data("testo\ncane gatto\n".utf8), options: .init(),
            mapping: .init(textColumns: [1]))
        var state = try await session.researchState()
        state.preparation.stopwords = ["cane"]
        _ = try await session.saveResearchState(state, expectedRevision: state.revision)
        let manualRequest = GlifiStudioTextAnalysisRequest.dissimilarities(
            matrix: [[1, 0], [0, 1]], metric: .euclidean)
        let manual = try await session.runSavedAnalysis(
            requestJSON: manualRequest.canonicalData(), title: "Matrice manuale",
            sourceRevisionIDs: [])
        #expect(
            try JSONDecoder().decode(
                GlifiStudioCorpusPreparation.self, from: manual.preparationJSON
            ).isIdentity)
        let sourceID = try #require(imported.sourceRevisionIDs.first)
        let configuration = GlifiStudioTemporalConfiguration(
            basis: .civilDates, granularity: .month,
            origin: try GlifiStudioCivilDate(year: 2024, month: 1, day: 1), bucketWidth: 1,
            bucketCount: 2, missingPolicy: .separate, outsidePolicy: .exclude)
        let temporal = try await GlifiStudioEvaluationWorkbench.temporal(
            session: session,
            assignments: [
                .init(
                    sourceRevisionID: sourceID,
                    value: .civilMonth(year: 2024, month: 1), provenance: "synthetic.month-v1")
            ],
            terms: ["gatto"], configuration: configuration)
        #expect(temporal.documents[0].tokenCount == 1)
        let request = EvaluationCommandEnvelope(
            schema: GlifiStudioEvaluationCommand.schema, schemaVersion: 1, operation: .temporal,
            parameters: EvaluationTemporal(
                documents: temporal.documents, configuration: configuration))
        let saved = try await session.captureWorkbenchAnalysis(
            command: "evaluation", requestJSON: CommandJSON.encode(request),
            resultJSON: CommandJSON.encode(temporal.result),
            methodIdentifier: temporal.result.methodIdentifier,
            title: "Serie temporale", sourceRevisionIDs: [sourceID],
            preparationDigest: temporal.preparationDigest, preparation: temporal.preparation)
        #expect(saved.preparationDigest == temporal.preparationDigest)
        #expect(
            try JSONDecoder().decode(GlifiStudioCorpusPreparation.self, from: saved.preparationJSON)
                == temporal.preparation)
        _ = try GlifiStudioWorkbenchCapture(saved: saved)
        await session.close()
    }

    private struct Fixture {
        let command: String
        let request: Data
        let result: Data
        let method: String
    }

    private static func fixtures() async throws -> [Fixture] {
        var parameters = GlifiStudioStatisticsParameters()
        parameters.seed = UInt64.max
        let statistics = GlifiStudioStatisticsRequest(
            operation: .descriptive, values: [[-0.0, 1, 2]], parameters: parameters)
        let statisticsResult = try await GlifiStudioStatisticsWorkbench.evaluate(statistics)
        var op = GlifiStudioCoreOperatorRequest()
        op.operation = .kMeans
        op.numbers = "1 0\n0 1\n1 1\n2 1"
        op.seed = UInt64.max
        let operatorResult = try await GlifiStudioCoreOperators.execute(op)
        let evaluation = Data(
            """
            {"schema":"studio.glifi.evaluation-command-request","schemaVersion":1,
            "operation":"classification","parameters":{"gold":["A","A","B"],"predicted":["A","B","B"]}}
            """.utf8)
        let evaluationResult = try await GlifiStudioEvaluationCommand.execute(json: evaluation)
        let method = try JSONDecoder().decode(EvaluationMethod.self, from: evaluationResult.json)
            .methodIdentifier
        return [
            Fixture(
                command: "statistics", request: try CommandJSON.encode(statistics),
                result: try CommandJSON.encode(statisticsResult),
                method: statisticsResult.methodIdentifier),
            Fixture(
                command: "operator", request: try CommandJSON.encode(operatorResult.request),
                result: try CommandJSON.encode(operatorResult),
                method: operatorResult.methodIdentifiers.joined(separator: " + ")),
            Fixture(
                command: "evaluation", request: evaluation, result: evaluationResult.json,
                method: method),
        ]
    }

    private struct EvaluationMethod: Decodable { let methodIdentifier: String }
    private struct Wire: Codable {
        var schema = "studio.glifi.research-command-request"
        var schemaVersion = 1
        var operation = GlifiStudioResearchOperation.workbenchCapture
        var parameters: Parameters
    }
    private struct Parameters: Codable {
        var command: String
        var requestJSON: Data
        var resultJSON: Data
        var methodIdentifier: String
        var title: String
        var createdAtUnixMilliseconds: Int64 = 1_700_000_000_000
    }
    private struct PathWire: Codable {
        var schema = "studio.glifi.research-command-request"
        var schemaVersion = 1
        var operation = GlifiStudioResearchOperation.workbenchCapture
        var parameters: PathParameters
    }
    private struct PathParameters: Codable {
        var command = "statistics"
        var requestPath: String
        var resultPath: String
        var presentationPath: String
        var methodIdentifier: String
        var title = "Dati grandi"
        var createdAtUnixMilliseconds: Int64 = 1_700_000_000_000
        var resultJSON: Data?
    }
}
