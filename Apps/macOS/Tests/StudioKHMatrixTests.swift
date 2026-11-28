// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioKHMatrixTests {
    @Test(arguments: StudioKHMatrixTool.allCases)
    func everyTypedProfileMatchesTheKitRequest(tool: StudioKHMatrixTool) async throws {
        let model = configuredModel(tool)
        let request = try await model.makeRequest()
        let direct = try await GlifiStudioKHAnalysis.execute(request)
        try await model.execute(locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        #expect(output.tool == tool)
        #expect(output.methodIdentifier == direct.methodIdentifier)
        #expect(output.validationStatus == direct.validationStatus)
        #expect(output.requestDigest == direct.requestDigest)
        #expect(!output.tables.isEmpty)
        #expect(
            output.tables.allSatisfy { table in
                table.rows.allSatisfy { $0.count == table.columns.count }
            })
        #expect(
            output.request
                == (try GlifiStudioTextAnalysisRequest.advanced(.kh(request)).canonicalData()))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        #expect(output.result == (try encoder.encode(direct)))
    }

    @Test("Gli input del corpus conservano esposizioni complete e universi di conteggio")
    func corpusAuxiliaryCountsUseCompleteDocuments() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiKHMatrix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "KH.glifi"))
        for (index, text) in ["Casa casa mare sole.", "Casa mare mare luna luna."].enumerated() {
            let file = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: file)
            _ = try await session.importText(at: file, format: .plainText)
        }
        let ids = try await session.snapshot().sources.map(\.sourceRevisionID)
        let model = StudioKHMatrixModel()
        model.maximumTerms = 2
        try await model.prepareInput(session: session, sourceRevisionIDs: ids)
        let input = try #require(model.input)
        #expect(input.terms == ["casa", "mare"])
        #expect(model.exposures.sorted() == [4, 5])
        #expect(model.exposures.reduce(0, +) == 9)
        #expect(model.matrix.values.flatMap { $0 }.reduce(0, +) == 6)
        #expect(model.documentFrequencies == [2, 2])
        model.tool = .collocationScores
        model.nodeTerm = "casa"
        model.collocateTerm = "mare"
        model.windowRadius = 1
        guard case let .collocationScores(counts) = try await model.makeRequest() else {
            Issue.record("Expected typed collocation counts")
            await session.close()
            return
        }
        #expect(counts.jointCount == 2)
        #expect(counts.nodeFrequency == 3)
        #expect(counts.collocateFrequency == 3)
        #expect(counts.corpusTokenCount == 9)
        #expect(counts.windowSpan == 2)
        model.tool = .wordAssociation
        model.conditionSourceIDs = [try #require(input.sourceRevisionIDs.first)]
        guard case let .wordAssociation(counts) = try await model.makeRequest() else {
            Issue.record("Expected document-condition counts")
            await session.close()
            return
        }
        #expect(counts.jointCount == 1)
        #expect(counts.conditionDocumentCount == 1)
        #expect(counts.termDocumentCount == 2)
        #expect(counts.totalDocumentCount == 2)
        model.tool = .documentScores
        try await model.execute()
        let captured = try #require(model.output)
        #expect(captured.provenance?.projectID == input.projectID)
        #expect(captured.provenance?.generation == input.generation)
        #expect(captured.provenance?.sourceRevisionIDs == input.sourceRevisionIDs)
        #expect(captured.provenance?.contentDigests == input.contentDigests)
        #expect(captured.provenance?.hasManualEdits == false)
        #expect(captured.rowLabels == input.sourceRevisionIDs)
        #expect(captured.columnLabels == input.terms)
        #expect(captured.tables.first?.rows.map { $0[0] } == input.sourceRevisionIDs)
        #expect(model.outputMatchesDraft(captured))
        model.matrix.rowLabels[0] = "Edited row identity"
        #expect(!model.outputMatchesDraft(captured))
        #expect(captured.rowLabels == input.sourceRevisionIDs)
        try await model.execute()
        #expect(model.output?.rowLabels[0] == "Edited row identity")
        #expect(model.output?.provenance?.hasManualEdits == true)
        model.jointCount = 12
        model.nodeFrequency = 20
        model.collocateFrequency = 30
        model.conditionDocumentCount = 1
        model.termDocumentCount = 2
        model.reset()
        #expect(model.input == nil)
        #expect(model.output == nil)
        #expect(!model.usesCorpusAuxiliary)
        #expect(model.nodeTerm.isEmpty)
        #expect(model.collocateTerm.isEmpty)
        #expect(model.corpusTokenCount == 0)
        #expect(model.totalDocumentCount == 0)
        #expect(model.conditionDocumentCount == 0)
        #expect(model.termDocumentCount == 0)
        #expect(model.jointCount == 0)
        #expect(model.nodeFrequency == 0)
        #expect(model.collocateFrequency == 0)
        #expect(model.exposures == [0, 0])
        #expect(model.documentFrequencies == [0, 0])
        #expect(model.matrix == StudioKHNumericMatrix())
        #expect(model.conditionSourceIDs.isEmpty)
        await session.close()
    }

    @Test("Una tabella inferenziale frazionaria non sostituisce il risultato valido")
    func invalidContingencyCountsPreserveTheLastOutput() async throws {
        let model = configuredModel(.chiSquare)
        try await model.execute()
        let previous = try #require(model.output)
        model.matrix.values[0][0] = 1.5
        await #expect(throws: GlifiStudioFailure.self) { try await model.execute() }
        #expect(model.output?.result == previous.result)
        #expect(model.output?.completedAt == previous.completedAt)
    }

    @Test("Un JSON di stato non valido restituisce una failure correggibile e conserva lo stato")
    func invalidClassifierStateRetainsTypedFailureAndPreviousState() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiClassifierState-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: root) } catch { Issue.record(error) }
        }
        let result = try await GlifiStudioKHAnalysis.execute(
            .incrementalClassifier(documents: [["casa"]], labels: ["A"], smoothing: 0.5))
        guard case let .advanced(.kh(.incrementalClassifier(initial))) = result.payload else {
            Issue.record("Expected the classifier training state")
            return
        }
        let file = root.appending(path: "state.json")
        try JSONEncoder().encode(initial.state).write(to: file)
        let model = StudioKHLanguageModel()
        try await model.importClassifierState(from: file)
        let previous = try #require(model.classifierState)
        let encoded = try await model.encodedClassifierState()
        for (json, expectedCode) in [
            ("{}", "ui.kh-language.invalid-input"),
            ("[]", "ui.kh-language.invalid-input"),
            ("{\"classes\":123}", "ui.kh-language.invalid-input"),
            ("not-json", "ui.kh-language.invalid-input"),
            ("{\"unexpected\":0}", "text-analysis.unknown-field"),
        ] {
            try Data(json.utf8).write(to: file)
            do {
                try await model.importClassifierState(from: file)
                Issue.record("Invalid classifier input must fail")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == expectedCode)
                #expect(failure.category == "invalidInput")
                #expect(failure.retryDisposition == "afterCorrection")
                #expect(failure.retainedState == "unchanged")
            }
            #expect(model.classifierState == previous)
            #expect(try await model.encodedClassifierState() == encoded)
        }
    }

    private func configuredModel(_ tool: StudioKHMatrixTool) -> StudioKHMatrixModel {
        let model = StudioKHMatrixModel()
        model.tool = tool
        model.matrix.values =
            tool == .hierarchicalWardD2 ? [[0, 1], [1, 0]] : [[4, 1], [1, 4]]
        model.exposures = [5, 5]
        model.documentFrequencies = [2, 2]
        model.corpusDocumentCount = 2
        model.jointCount = 2
        model.nodeFrequency = 4
        model.collocateFrequency = 3
        model.corpusTokenCount = 20
        model.windowSpan = 2
        model.conditionDocumentCount = 3
        model.termDocumentCount = 4
        model.totalDocumentCount = 8
        model.contextLevels[0].targets.values = [[1, 0], [0, 1]]
        model.contextLevels[0].contexts.values = [[2, 0], [0, 3]]
        return model
    }
}
