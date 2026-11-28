// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

nonisolated enum StudioArchivedWorkbench: String, CaseIterable, Sendable {
    case statistics, operators, evaluation, linguistic
}

@MainActor
struct StudioWorkbenchArchiveTests {
    @Test(
        "Ogni laboratorio conserva input effettivi e risultati dopo la riapertura",
        arguments: StudioArchivedWorkbench.allCases)
    func standaloneWorkbenchRoundTripAndCancellation(_ workbench: StudioArchivedWorkbench)
        async throws
    {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        switch workbench {
        case .statistics:
            let model = StudioStatisticsModel()
            model.input = "1 2 3 7"
            try await model.execute()
            let original = try #require(model.result)
            model.input = "999"
            let saved = try await model.saveArchive(session: fixture.session, title: "Statistiche")
            #expect(saved.sourceRevisionIDs.isEmpty)
            let read = try await reopen(saved, fixture: fixture)
            let restored = StudioStatisticsModel()
            try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            #expect(restored.input == "1 2 3 7")
            #expect(restored.result == original)
            #expect(!restored.capturedInputRows.isEmpty)
            let pending = Task.immediate {
                try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            }
            restored.reset()
            await #expect(throws: CancellationError.self) { try await pending.value }
            #expect(restored.result == nil)
        case .operators:
            let model = StudioOperatorsModel()
            model.request.numbers = "1 2\n3 5"
            try await model.execute()
            let original = try #require(model.result)
            model.request.numbers = "999"
            let saved = try await model.saveArchive(session: fixture.session, title: "Operatori")
            #expect(saved.sourceRevisionIDs.isEmpty)
            let read = try await reopen(saved, fixture: fixture)
            let restored = StudioOperatorsModel()
            try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            #expect(restored.request == original.request)
            #expect(restored.result == original)
            let pending = Task.immediate {
                try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            }
            restored.reset()
            await #expect(throws: CancellationError.self) { try await pending.value }
            #expect(restored.result == nil)
        case .evaluation:
            let model = StudioEvaluationModel()
            model.tool = .classification
            model.loadSyntheticExample()
            try await model.executeLinguistic(locale: .init(identifier: "it_IT"))
            let original = try #require(model.output)
            model.observations = []
            let saved = try await model.saveArchive(session: fixture.session, title: "Valutazione")
            #expect(saved.sourceRevisionIDs.isEmpty)
            let read = try await reopen(saved, fixture: fixture)
            let restored = StudioEvaluationModel()
            try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            #expect(restored.observations == original.input.observations)
            #expect(restored.output?.linguistic == original.linguistic)
            #expect(restored.output?.encodedResult == original.encodedResult)
            #expect(restored.rows.map(\.values) == original.linguisticRows.prefix(50).map(\.values))
            let pending = Task.immediate {
                try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            }
            restored.reset()
            await #expect(throws: CancellationError.self) { try await pending.value }
            #expect(restored.output == nil)
        case .linguistic:
            let model = StudioLinguisticModel()
            model.text = "La scuola apre al quartiere."
            model.base = .normalizedSurface
            try await model.execute(locale: .init(identifier: "it_IT"))
            let original = try #require(model.output)
            model.text = "Testo modificato dopo il calcolo."
            let saved = try await model.saveArchive(session: fixture.session, title: "Annotazioni")
            #expect(saved.sourceRevisionIDs.isEmpty)
            let read = try await reopen(saved, fixture: fixture)
            let restored = StudioLinguisticModel()
            try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            #expect(restored.text == original.input.text)
            #expect(restored.output?.encodedResult == original.encodedResult)
            #expect(
                restored.output?.tables.map(\.rows).map { $0.map(\.id) }
                    == original.tables.map(\.rows).map { $0.map(\.id) })
            let pending = Task.immediate {
                try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
            }
            restored.reset()
            await #expect(throws: CancellationError.self) { try await pending.value }
            #expect(restored.output == nil)
        }
    }

    @Test("La codifica linguistica ripristina matrice, evidenze, regole e provenienza")
    func linguisticCodingRetainsItsFullNativePresentation() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioLinguisticModel()
        model.tool = .coding
        model.units = [StudioLinguisticUnit(identifier: "uno", text: "La casa è aperta.")]
        model.rules = "*Casa\ncasa"
        try await model.execute(locale: .init(identifier: "it_IT"))
        let original = try #require(model.output)
        let saved = try await model.saveArchive(session: fixture.session, title: "Codifica")
        let restored = StudioLinguisticModel()
        try await restored.restoreArchive(try #require(saved.presentationJSON), saved: saved)
        #expect(restored.rules == "*Casa\ncasa")
        #expect(restored.units == original.input.units)
        #expect(restored.output?.encodedResult == original.encodedResult)
        #expect(restored.output?.payload.provenances == original.payload.provenances)
        #expect(
            restored.output?.tables.map { $0.rows.count } == original.tables.map { $0.rows.count })
        await fixture.session.close()
    }

    @Test("Le serie temporali conservano fonti, date e preparazione del corpus")
    func temporalArchiveRetainsProjectLineageAndCalendar() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let source = fixture.root.appending(path: "fonte.txt")
        try Data("La scuola apre. Scuola e famiglia.".utf8).write(to: source)
        _ = try await fixture.session.importText(at: source, format: .plainText)
        var research = try await fixture.session.researchState()
        research.preparation.stopwords = ["la"]
        _ = try await fixture.session.saveResearchState(
            research, expectedRevision: research.revision)
        let snapshot = try await fixture.session.snapshot()
        let id = try #require(snapshot.sources.first?.sourceRevisionID)
        let model = StudioEvaluationModel()
        model.originYear = 2026
        model.originMonth = 11
        model.temporalAnnotations = [
            id: .init(precision: .civilDate, year: 2026, month: 11, day: 1)
        ]
        model.selectedTerms = "scuola"
        try await model.executeTemporal(
            session: fixture.session, sourceRevisionIDs: [id], sourceNumbers: [id: 1],
            locale: .init(identifier: "it_IT"))
        let original = try #require(model.output)
        let saved = try await model.saveArchive(session: fixture.session, title: "Serie temporale")
        #expect(saved.sourceRevisionIDs == [id])
        #expect(saved.preparationDigest == original.temporal?.preparationDigest)
        let read = try await reopen(saved, fixture: fixture)
        let restored = StudioEvaluationModel()
        try await restored.restoreArchive(try #require(read.presentationJSON), saved: read)
        #expect(restored.originYear == 2026)
        #expect(restored.originMonth == 11)
        #expect(restored.temporalAnnotations == original.input.temporalAnnotations)
        #expect(restored.output?.temporal?.result == original.temporal?.result)
        #expect(
            restored.output?.temporal?.preparationDigest == original.temporal?.preparationDigest)
        #expect(restored.output?.encodedResult == original.encodedResult)
    }

    private func reopen(_ saved: GlifiStudioSavedAnalysis, fixture: Fixture) async throws
        -> GlifiStudioSavedAnalysis
    {
        await fixture.session.close()
        let reopened = try await GlifiStudioService().openProject(at: fixture.project)
        let read = try await reopened.savedAnalysis(artifactID: saved.artifactID)
        await reopened.close()
        return read
    }

    private struct Fixture {
        let root: URL
        let project: URL
        let session: GlifiStudioProjectSession
    }

    private func makeFixture() async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkbenchArchive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let project = root.appending(path: "Research.glifi")
        return Fixture(
            root: root, project: project,
            session: try await GlifiStudioService().createProject(at: project))
    }
}
