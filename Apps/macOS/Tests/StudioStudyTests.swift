// SPDX-License-Identifier: BSD-3-Clause

import CoreGraphics
import CoreText
import Foundation
import GlifiKit
import Testing

nonisolated private enum StudioStudyCanceledModal: CaseIterable, Sendable {
    case note, excerpt, restore
}

@MainActor
struct StudioStudyTests {
    @Test("La selezione nativa rispetta emoji e confini dei caratteri Unicode")
    func nativeSelectionPreservesUnicodeCharacterBoundaries() async throws {
        let text = "Prima 👩🏽‍🔬, città e\u{301} dopo."
        let selected = try #require(text.range(of: "👩🏽‍🔬, città"))
        let selection = try await StudioStudyModel.characterSelection(
            text: text, range: NSRange(selected, in: text))
        #expect(selection == .characters(start: 6, end: 14))
        let emoji = (text as NSString).range(of: "👩🏽‍🔬")
        await #expect(throws: GlifiStudioFailure.self) {
            try await StudioStudyModel.characterSelection(
                text: text, range: NSRange(location: emoji.location, length: 1))
        }
        let combined = (text as NSString).range(of: "e\u{301}")
        await #expect(throws: GlifiStudioFailure.self) {
            try await StudioStudyModel.characterSelection(
                text: text, range: NSRange(location: combined.location + 1, length: 1))
        }
    }

    @Test("Lo studio riapre conclusioni, gruppi, confronto e riferimenti esatti")
    func notebookReopensWithConclusionsGroupsComparisonAndExactSourceReturn() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        model.addGroup(title: "Concetti importanti")
        try await model.save(session: fixture.session)
        let group = try #require(model.state.groups.first?.id)
        #expect(!model.showsNotebook)

        try await model.readSource(session: fixture.session, sourceID: fixture.first, slot: .first)
        let reading = try #require(model.firstReading)
        #expect(reading.source.text.contains("# Titolo"))
        #expect(!reading.text.contains("# Titolo"))
        let quote = "Città 👩🏽‍🔬 e mare."
        let bounds = try #require(reading.text.range(of: quote))
        model.setNativeSelection(
            NSRange(bounds, in: reading.text), sourceID: fixture.first, slot: .first)
        try await model.previewNativeSelection(session: fixture.session, slot: .first)
        #expect(model.pendingPassage?.text == quote)
        model.pendingTitle = "Primo argomento"
        model.pendingGroupID = group
        try await model.collect(session: fixture.session)
        #expect(model.showsNotebook)
        let first = try #require(model.state.excerpts.first)
        #expect(first.anchor.quote == quote)
        #expect(first.anchor.sourceRevisionID == fixture.first)
        model.showsNotebook = false

        try await model.readSource(
            session: fixture.session, sourceID: fixture.second, slot: .second)
        try await model.previewPassage(
            session: fixture.session, slot: .second, selection: .sentences(first: 0, last: 0))
        model.pendingTitle = "Secondo argomento"
        try await model.collect(session: fixture.session)
        #expect(model.showsNotebook)
        let second = try #require(model.state.excerpts.first { $0.id != first.id })
        model.setComparison([first.id, second.id])
        model.saveNote(
            id: nil, title: "Conclusione",
            text: "I due passaggi mettono in relazione studio e contesto.",
            groupID: group, excerptIDs: [first.id, second.id])
        let noteID = try #require(model.state.notes.first?.id)
        model.saveNote(
            id: nil, title: "Nota libera", text: "Un’idea da approfondire.", groupID: nil,
            excerptIDs: [])
        model.moveObject(id: noteID, by: 1)
        model.showsNotebook = false
        try await model.save(session: fixture.session)
        #expect(model.showsNotebook)
        let expected = model.state
        let exported = try await model.export(session: fixture.session, format: .json)
        #expect(
            try JSONDecoder().decode(GlifiStudioStudyExport.self, from: exported).state == expected)
        #expect(try await model.export(session: fixture.session, format: .json) == exported)
        let markdown = try await model.export(session: fixture.session, format: .markdown)
        #expect(String(decoding: markdown, as: UTF8.self).contains("Conclusione"))
        await fixture.session.close()

        let reopened = try await GlifiStudioService().openProject(at: fixture.project)
        let fresh = StudioStudyModel()
        try await fresh.load(session: reopened)
        #expect(fresh.state == expected)
        #expect(fresh.orderedNotes.map(\.title) == ["Nota libera", "Conclusione"])
        #expect(
            fresh.orderedNotes.first(where: { $0.id == noteID })?.excerptIDs == [
                first.id, second.id,
            ])
        try await fresh.openExcerpt(session: reopened, excerptID: first.id, slot: .first)
        let returned = try #require(fresh.firstReading)
        #expect(returned.sourceRevisionID == fixture.first)
        #expect(
            (returned.text as NSString).substring(with: try #require(returned.highlight)) == quote)
        try await fresh.openExcerpt(session: reopened, excerptID: second.id, slot: .second)
        #expect(fresh.showsComparison)
        #expect(fresh.secondReading?.sourceRevisionID == fixture.second)
        let original = try await reopened.studyOriginal(sourceRevisionID: fixture.first)
        #expect(String(decoding: original.data, as: UTF8.self).contains("# Titolo"))
        await reopened.close()
    }

    @Test("Un caricamento fallito o tardivo non sostituisce il contesto valido")
    func failedReadingAndLateCompletionPreserveValidContext() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        try await model.readSource(session: fixture.session, sourceID: fixture.first, slot: .first)
        let previous = try #require(model.firstReading)
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.readSource(
                session: fixture.session, sourceID: "invalid-source", slot: .first)
        }
        #expect(model.firstReading?.navigationID == previous.navigationID)
        #expect(model.firstReading?.text == previous.text)
        let pending = Task.immediate {
            try await model.readSource(
                session: fixture.session, sourceID: fixture.second, slot: .first)
        }
        model.reset()
        await #expect(throws: CancellationError.self) { try await pending.value }
        #expect(model.firstReading == nil)
        #expect(model.secondReading == nil)
        #expect(!model.hasLoaded)
        await fixture.session.close()
    }

    @Test("Annulla, ripeti e conflitti conservano le modifiche senza sovrascrivere altre finestre")
    func notebookUndoRedoAndConflictRetainDraft() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        model.saveNote(
            id: nil, title: "Appunto", text: "Una conclusione personale.", groupID: nil,
            excerptIDs: [])
        try await model.save(session: fixture.session)
        let noteID = try #require(model.state.notes.first?.id)
        model.undo()
        try await model.save(session: fixture.session)
        #expect(try await fixture.session.studyState().notes.isEmpty)
        model.redo()
        try await model.save(session: fixture.session)
        #expect(try await fixture.session.studyState().notes.first?.id == noteID)

        var external = try await fixture.session.studyState()
        external.groups.append(.init(id: "another-window", title: "Altra finestra"))
        _ = try await fixture.session.saveStudyState(external, expectedRevision: external.revision)
        model.saveNote(
            id: noteID, title: "Titolo modificato", text: "Bozza da conservare.", groupID: nil,
            excerptIDs: [])
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.save(session: fixture.session)
        }
        #expect(model.hasChanges)
        #expect(model.state.notes.first?.text == "Bozza da conservare.")
        try await model.reloadPreservingDraft(session: fixture.session)
        #expect(!model.hasChanges)
        #expect(model.state.groups.first?.title == "Altra finestra")
        #expect(model.recoveryDraft?.notes.first?.text == "Bozza da conservare.")
        model.restoreRecoveryDraft()
        #expect(model.hasChanges)
        #expect(model.state.revision == external.revision + 1)
        #expect(
            try await fixture.session.studyState().notes.first?.text == "Una conclusione personale."
        )
        await fixture.session.close()
    }

    @Test("Ricaricare vede una seconda sessione reale senza perdere bozza o lettura")
    func independentWindowReloadPreservesTheLocalDraftAndReading() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        await fixture.session.close()
        let home = StudioHomeModel()
        await home.openProject(at: fixture.project)
        let active = try #require(home.researchProjectSession)
        try await home.study.load(session: active)
        try await home.study.readSource(session: active, sourceID: fixture.first, slot: .first)
        let reading = try #require(home.study.firstReading)
        let independent = try await GlifiStudioService().openProject(at: fixture.project)
        home.advancedAnalysis.rules = "*Importante\ncittà"
        var external = try await independent.studyState()
        external.groups.append(.init(id: "independent-window", title: "Sessione indipendente"))
        _ = try await independent.saveStudyState(external, expectedRevision: external.revision)
        home.study.saveNote(
            id: nil, title: "Bozza locale", text: "Da non perdere.", groupID: nil, excerptIDs: [])
        await #expect(throws: GlifiStudioFailure.self) {
            try await home.study.save(session: active)
        }

        try await home.reloadStudyFromDisk()

        #expect(home.study.state.groups.first?.title == "Sessione indipendente")
        #expect(home.study.recoveryDraft?.notes.first?.text == "Da non perdere.")
        #expect(home.study.firstReading?.navigationID == reading.navigationID)
        #expect(home.study.firstReading?.text == reading.text)
        #expect(home.advancedAnalysis.rules == "*Importante\ncittà")
        let fresh = try #require(home.researchProjectSession)
        #expect(fresh !== active)
        home.study.saveNote(
            id: nil, title: "Dopo il recupero", text: "Una nuova conclusione verificata.",
            groupID: nil, excerptIDs: [])
        try await home.study.save(session: fresh)
        #expect(try await fresh.studyState().groups.first?.title == "Sessione indipendente")
        #expect(
            try await fresh.studyState().notes.first?.text == "Una nuova conclusione verificata.")
        await independent.close()
        await home.closeProject()
    }

    @Test("Una riapertura non valida conserva sessione, bozza e lettura precedenti")
    func failedCandidateReloadKeepsTheSessionDraftAndReading() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        await fixture.session.close()
        let home = StudioHomeModel()
        await home.openProject(at: fixture.project)
        let active = try #require(home.researchProjectSession)
        try await home.study.load(session: active)
        try await home.study.readSource(session: active, sourceID: fixture.first, slot: .first)
        home.study.saveNote(
            id: nil, title: "Bozza", text: "Contenuto importante.", groupID: nil, excerptIDs: [])
        let reading = try #require(home.study.firstReading)
        let draft = home.study.state
        home.queryDraft = "normalized:città"
        let snapshot = home.snapshot
        let manifest = fixture.project.appending(path: "manifest.json")
        let original = try Data(contentsOf: manifest)
        try Data("{invalid".utf8).write(to: manifest, options: .atomic)
        await #expect(throws: GlifiStudioFailure.self) { try await home.reloadStudyFromDisk() }
        #expect(home.researchProjectSession === active)
        #expect(home.study.state == draft)
        #expect(home.study.hasChanges)
        #expect(home.queryDraft == "normalized:città")
        #expect(home.snapshot == snapshot)
        #expect(home.study.firstReading?.navigationID == reading.navigationID)
        try original.write(to: manifest, options: .atomic)
        await home.closeProject()
    }

    @Test("Il ripristino JSON è esplicito e rifiuta file alterati e link simbolici")
    func jsonRestorationUsesTheCurrentRevisionAndStrictEnvelope() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        model.saveNote(
            id: nil, title: "Da conservare", text: "Conclusione originale.", groupID: nil,
            excerptIDs: [])
        try await model.save(session: fixture.session)
        let noteID = try #require(model.state.notes.first?.id)
        let exported = try await model.export(session: fixture.session, format: .json)
        let url = fixture.root.appending(path: "notebook.json")
        try exported.write(to: url)
        model.removeObject(id: noteID)
        try await model.save(session: fixture.session)
        let revision = model.state.revision
        try await model.prepareRestore(at: url)
        #expect(model.state.notes.isEmpty)
        #expect(model.proposedRestore?.notes.first?.id == noteID)
        try await model.restoreProposedNotebook(session: fixture.session)
        #expect(model.state.notes.first?.id == noteID)
        #expect(model.state.revision == revision + 1)
        #expect(model.proposedRestore == nil)

        var invalid = try #require(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        invalid["unexpected"] = true
        let invalidURL = fixture.root.appending(path: "invalid.json")
        try JSONSerialization.data(withJSONObject: invalid).write(to: invalidURL)
        let preserved = model.state
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.prepareRestore(at: invalidURL)
        }
        #expect(model.state == preserved)
        let link = fixture.root.appending(path: "linked.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: url)
        await #expect(throws: GlifiStudioFailure.self) { try await model.prepareRestore(at: link) }
        #expect(model.state == preserved)
        await fixture.session.close()
    }

    @Test("Ritentare il salvataggio della stessa conclusione non crea copie")
    func failedConclusionSaveRetriesTheSameEditorIntentExactlyOnce() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        let editor = StudioStudyEditor.newConclusion()
        guard case let .note(id) = editor else {
            Issue.record("Expected the conclusion editor intent")
            await fixture.session.close()
            return
        }
        model.saveNote(
            id: id, title: "Conclusione", text: "Prima versione da conservare.", groupID: nil,
            excerptIDs: [])
        let firstID = try #require(model.state.notes.first?.id)
        await fixture.session.close()
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.save(session: fixture.session)
        }
        #expect(model.hasChanges)
        #expect(model.state.notes.first?.text == "Prima versione da conservare.")

        let fresh = try await GlifiStudioService().openProject(at: fixture.project)
        model.saveNote(
            id: id, title: "Conclusione modificata",
            text: "Seconda versione dopo il tentativo fallito.", groupID: nil, excerptIDs: [])
        try await model.save(session: fresh)
        let saved = try await fresh.studyState()
        #expect(saved.notes.count == 1)
        #expect(saved.notes.map(\.id) == [firstID])
        #expect(saved.order == [firstID])
        #expect(saved.notes.first?.title == "Conclusione modificata")
        #expect(saved.notes.first?.text == "Seconda versione dopo il tentativo fallito.")
        #expect(!model.hasChanges)
        await fresh.close()
    }

    @Test(
        "Annullare un editor dopo un errore non pubblica la proposta con altre azioni",
        arguments: StudioStudyCanceledModal.allCases)
    private func canceledFailedModalDoesNotLeakIntoAnotherCommit(kind: StudioStudyCanceledModal)
        async throws
    {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        try await model.readSource(session: fixture.session, sourceID: fixture.first, slot: .first)
        try await model.previewPassage(
            session: fixture.session, slot: .first,
            selection: .sentences(first: 0, last: 0))
        model.pendingTitle = "Passaggio originale"
        try await model.collect(session: fixture.session)
        let excerptID = try #require(model.state.excerpts.first?.id)
        model.saveNote(
            id: "original-note", title: "Nota originale", text: "Contenuto originale.",
            groupID: nil, excerptIDs: [excerptID])
        try await model.save(session: fixture.session)
        model.addGroup(title: "Bozza preesistente")
        model.addGroup(title: "Da ripetere")
        model.undo()
        model.showsNotebook = false
        let before = model.state
        let previousUndo = model.canUndo
        let previousRedo = model.canRedo
        let recovery = model.recoveryDraft
        await fixture.session.close()

        switch kind {
        case .note:
            await #expect(throws: GlifiStudioFailure.self) {
                try await model.commitEditorChange(session: fixture.session) {
                    model.saveNote(
                        id: "canceled-note", title: "Da annullare", text: "Non pubblicare.",
                        groupID: nil, excerptIDs: [])
                }
            }
        case .excerpt:
            await #expect(throws: GlifiStudioFailure.self) {
                try await model.commitEditorChange(session: fixture.session) {
                    model.updateExcerpt(id: excerptID, title: "Titolo annullato", groupID: nil)
                }
            }
        case .restore:
            let proposed = GlifiStudioStudyState(
                projectID: model.state.projectID,
                notes: [
                    .init(
                        id: "restored-note", title: "Da non ripristinare", text: "Non pubblicare.")
                ],
                order: ["restored-note"])
            model.proposedRestore = proposed
            await #expect(throws: GlifiStudioFailure.self) {
                try await model.restoreProposedNotebook(session: fixture.session)
            }
            #expect(model.proposedRestore == proposed)
        }
        #expect(model.state == before)
        #expect(model.canUndo == previousUndo)
        #expect(model.canRedo == previousRedo)
        #expect(model.recoveryDraft == recovery)
        #expect(!model.showsNotebook)
        // Cancel closes the local editor; only its proposal is discarded, not the existing draft.
        model.proposedRestore = nil
        let fresh = try await GlifiStudioService().openProject(at: fixture.project)
        model.addGroup(title: "Azione successiva")
        try await model.save(session: fresh)
        let saved = try await fresh.studyState()
        #expect(saved.notes.map(\.id) == ["original-note"])
        #expect(saved.notes.first?.text == "Contenuto originale.")
        #expect(saved.excerpts.first?.title == "Passaggio originale")
        #expect(saved.order == before.order)
        #expect(saved.groups.map(\.title) == ["Bozza preesistente", "Azione successiva"])
        await fresh.close()
    }

    @Test("Il PDF nativo usa l’originale e il ritorno al passaggio conserva la pagina reale")
    func pdfOriginalReaderRestoresTheRealPageAndCapturedQuote() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let data = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        var box = CGRect(x: 0, y: 0, width: 640, height: 300)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        for text in ["Prima pagina verificata.", "Seconda pagina importante."] {
            context.beginPDFPage(nil)
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(
                    string: text,
                    attributes: [
                        NSAttributedString.Key(kCTFontAttributeName as String):
                            CTFontCreateWithName("Helvetica" as CFString, 24, nil)
                    ]))
            context.textPosition = CGPoint(x: 30, y: 140)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()
        let bytes = data as Data
        let url = fixture.root.appending(path: "source.pdf")
        try bytes.write(to: url)
        let imported = try await fixture.session.importText(at: url, format: .pdf)
        let id = try #require(
            imported.project.sources.first { $0.format == .pdf }?.sourceRevisionID)
        let model = StudioStudyModel()
        try await model.load(session: fixture.session)
        try await model.readSource(session: fixture.session, sourceID: id, slot: .first)
        let reading = try #require(model.firstReading)
        #expect(reading.pdf?.pageCount == 2)
        let quote = "Seconda pagina importante."
        let range = try #require(reading.text.range(of: quote))
        model.setNativeSelection(NSRange(range, in: reading.text), sourceID: id, slot: .first)
        try await model.previewNativeSelection(session: fixture.session, slot: .first)
        try await model.collect(session: fixture.session)
        let excerpt = try #require(model.state.excerpts.first)
        try await model.openExcerpt(session: fixture.session, excerptID: excerpt.id, slot: .first)
        #expect(model.firstReading?.pageNumber == 2)
        #expect(model.firstReading?.pdf?.pageCount == 2)
        #expect(try await fixture.session.studyOriginal(sourceRevisionID: id).data == bytes)
        await fixture.session.close()
    }

    private func makeFixture() async throws -> (
        root: URL, project: URL, session: GlifiStudioProjectSession, first: String, second: String
    ) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let project = root.appending(path: "Studio.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        let firstURL = root.appending(path: "first.md")
        let secondURL = root.appending(path: "second.txt")
        try Data("# Titolo\n\nCittà 👩🏽‍🔬 e mare.\nSeconda frase.".utf8).write(to: firstURL)
        try Data("Studiare documenti collega idee. Rivedere le fonti chiarisce il contesto.".utf8)
            .write(to: secondURL)
        let first = try await session.importText(at: firstURL, format: .markdown)
        let firstID = try #require(first.project.sources.first?.sourceRevisionID)
        let second = try await session.importText(at: secondURL, format: .plainText)
        let secondID = try #require(
            second.project.sources.first { $0.sourceRevisionID != firstID }?.sourceRevisionID)
        return (root, project, session, firstID, secondID)
    }
}
