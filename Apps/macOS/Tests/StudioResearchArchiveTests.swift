// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioResearchArchiveTests {
    @Test("La riapertura ripristina matrice, parametri e tabelle KH senza ricalcolo")
    func matrixArchiveRestoresTheEffectiveSettingsAfterReopening() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioKHMatrixModel()
        model.tool = .sampleZScores
        model.matrix.values = [[1, 2], [3, 7]]
        model.matrix.rowLabels = ["A", "B"]
        model.matrix.columnLabels = ["Casa", "Scuola"]
        model.axis = .columns
        try await model.execute(locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        let result = try #require(output.typedResult)
        let archive = try await model.archiveData()
        let saved = try await fixture.session.saveCompletedAnalysis(
            request: GlifiStudioTextAnalysisRequest.decode(output.request), result: result,
            title: "Pesi standardizzati", sourceRevisionIDs: [], presentationJSON: archive)
        model.matrix.values[0][0] = 999
        await fixture.session.close()
        let reopened = try await GlifiStudioService().openProject(at: fixture.project)
        let restored = try await reopened.savedAnalysis(artifactID: saved.artifactID)
        let fresh = StudioKHMatrixModel()
        try await fresh.restoreArchive(try #require(restored.presentationJSON), saved: restored)
        #expect(fresh.matrix.values == [[1, 2], [3, 7]])
        #expect(fresh.matrix.rowLabels == ["A", "B"])
        #expect(fresh.matrix.columnLabels == ["Casa", "Scuola"])
        #expect(fresh.axis == .columns)
        #expect(fresh.output?.result == output.result)
        #expect(fresh.output?.tables.map(\.rows) == output.tables.map(\.rows))
        #expect(fresh.output?.typedResult == nil)
        #expect(fresh.output.map(fresh.outputMatchesDraft) == true)
        await reopened.close()
    }

    @Test("Il ripristino KH rifiuta un archivio incoerente e conserva il risultato precedente")
    func mismatchedArchiveCannotReplaceTheCurrentOutput() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioKHMatrixModel()
        model.matrix.values = [[1, 2], [3, 7]]
        try await model.execute()
        let output = try #require(model.output)
        let saved = try await fixture.session.saveCompletedAnalysis(
            request: GlifiStudioTextAnalysisRequest.decode(output.request),
            result: try #require(output.typedResult), title: "Matrice", sourceRevisionIDs: [],
            presentationJSON: try await model.archiveData())
        var fields = try #require(
            JSONSerialization.jsonObject(with: try await model.archiveData()) as? [String: Any])
        fields["methodIdentifier"] = "forged"
        let corrupted = try JSONSerialization.data(withJSONObject: fields)
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.restoreArchive(corrupted, saved: saved)
        }
        #expect(model.output?.result == output.result)
        #expect(model.matrix.values == [[1, 2], [3, 7]])
        let archive = try await model.archiveData()
        let pending = Task.immediate {
            try await model.restoreArchive(archive, saved: saved)
        }
        model.reset()
        await #expect(throws: CancellationError.self) { try await pending.value }
        #expect(model.output == nil)
        await fixture.session.close()
    }

    @Test("Un archivio in preparazione non viene pubblicato dopo il reset")
    func archiveEncodingChecksOwnershipAfterSuspending() async throws {
        let model = StudioKHMatrixModel()
        model.matrix.values = [[1, 2], [3, 7]]
        try await model.execute()
        let pending = Task.immediate { try await model.archiveData() }
        model.reset()
        await #expect(throws: CancellationError.self) { try await pending.value }
        #expect(model.output == nil)
    }

    @Test("Il ripristino conserva regole, etichette e stato del classificatore incrementale")
    func classifierArchiveRestoresTheTrainingStateAndCapturedDraft() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        var ids: [String] = []
        for (index, text) in ["Casa famiglia casa.", "Scuola classe scuola."].enumerated() {
            let url = fixture.root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            _ = try await fixture.session.importText(at: url, format: .plainText)
        }
        ids = try await fixture.session.snapshot().sources.map(\.sourceRevisionID).sorted()
        let numbers = Dictionary(
            uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset + 1) })
        let model = StudioKHLanguageModel()
        model.tool = .incrementalClassifier
        model.draft.labels = [ids[0]: "Casa", ids[1]: "Scuola"]
        model.draft.rules = "*Casa\ncasa"
        model.draft.smoothing = 0.5
        try await model.execute(
            session: fixture.session, sourceRevisionIDs: ids,
            sourceNumbers: numbers, locale: Locale(identifier: "it_IT"))
        let output = try #require(model.output)
        let archive = try await model.archiveData()
        let preparation = try #require(output.capturedPreparation)
        let saved = try await fixture.session.saveCompletedAnalysis(
            request: GlifiStudioTextAnalysisRequest.decode(output.encodedRequest),
            result: try #require(output.result), title: "Classificazione", sourceRevisionIDs: ids,
            presentationJSON: archive, preparationDigest: preparation.digest(),
            preparation: preparation)
        model.draft.labels = [:]
        let fresh = StudioKHLanguageModel()
        try await fresh.restoreArchive(archive, saved: saved)
        #expect(fresh.tool == .incrementalClassifier)
        #expect(fresh.draft.labels == output.draft.labels)
        #expect(fresh.draft.rules == "*Casa\ncasa")
        #expect(fresh.draft.smoothing == 0.5)
        #expect(fresh.classifierState == output.state)
        #expect(fresh.output?.result == nil)
        #expect(fresh.output?.encodedResult == output.encodedResult)
        #expect(fresh.output?.tables.map(\.rows) == output.tables.map(\.rows))
        #expect(fresh.output?.contentDigests == output.contentDigests)
        await fixture.session.close()
        let home = StudioHomeModel()
        await home.openProject(at: fixture.project)
        try await home.linkSavedResearchAnalysisToInvestigation(
            saved, question: "Quali risultati sono stati acquisiti dalla classificazione?")
        #expect(
            home.investigation?.question
                == "Quali risultati sono stati acquisiti dalla classificazione?")
        #expect(home.investigation?.selectedFindingIDs.isEmpty == false)
        #expect(home.lastInvestigationProjectID == home.snapshot?.projectID)
        await home.closeProject()
    }

    private func makeFixture() async throws -> (
        root: URL, project: URL, session: GlifiStudioProjectSession
    ) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiResearchArchive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let project = root.appending(path: "Research.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        return (root, project, session)
    }
}
