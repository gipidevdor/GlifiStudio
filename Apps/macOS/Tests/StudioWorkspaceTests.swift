// SPDX-License-Identifier: BSD-3-Clause

import AppKit
import Foundation
import GlifiKit
import SwiftUI
import Testing

@MainActor
struct StudioWorkspaceTests {
    private final class BundleAnchor {}

    @Test("Un lettore ricreato conserva la selezione nativa corrente del documento")
    func studyRecreatedReaderRestoresTheCurrentSelection() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudySelection-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Studio.glifi"))
        let firstFile = root.appending(path: "prima.txt")
        let secondFile = root.appending(path: "seconda.txt")
        let content = "La città 👩🏽‍🔬 conserva l’unità scelta. Il testo rimane leggibile."
        try Data(content.utf8).write(to: firstFile)
        try Data("La nuova fonte mantiene il proprio contesto.".utf8).write(to: secondFile)
        let firstImport = try await session.importText(at: firstFile, format: .plainText)
        let firstID = try #require(firstImport.project.sources.first?.sourceRevisionID)
        let secondImport = try await session.importText(at: secondFile, format: .plainText)
        let secondID = try #require(
            secondImport.project.sources.first { $0.sourceRevisionID != firstID }?.sourceRevisionID)
        #expect(secondID != firstID)
        let study = StudioStudyModel()
        try await study.load(session: session)
        try await study.readSource(session: session, sourceID: firstID, slot: .first)
        let reading = try #require(study.firstReading)
        #expect(reading.highlight == nil)
        let render: (StudioStudyReading) -> StudioStudyTextReader = { reading in
            StudioStudyTextReader(
                reading: reading, accessibilityTitle: "Documento di studio",
                initialSelection: study.nativeSelection(.first)
            ) {
                range in
                study.setNativeSelection(range, sourceID: reading.sourceRevisionID, slot: .first)
            }
        }
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 600, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer {
            window.contentView = nil
            window.close()
        }
        let original = NSHostingView(rootView: render(reading))
        window.contentView = original
        window.orderBack(nil)
        original.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let originalText = try #require(descendant(of: NSTextView.self, in: original))
        let selected = (content as NSString).range(of: "👩🏽‍🔬 conserva")
        try #require(selected.location != NSNotFound && selected.length > 0)
        #expect(selected.location + selected.length <= (content as NSString).length)
        originalText.setSelectedRange(selected)
        try await Task.sleep(for: .milliseconds(50))
        #expect(study.hasNativeSelection(.first))
        try await study.previewNativeSelection(session: session, slot: .first)
        #expect(study.pendingPassage?.text == "👩🏽‍🔬 conserva")
        study.clearPendingPassage()

        // A different host recreates the representable, as the split-to-tab branch does.
        window.contentView = nil
        let recreated = NSHostingView(rootView: render(reading))
        window.contentView = recreated
        recreated.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let recreatedText = try #require(descendant(of: NSTextView.self, in: recreated))
        #expect(recreatedText !== originalText)
        #expect(study.hasNativeSelection(.first))
        #expect(recreatedText.selectedRange() == selected)
        #expect(recreatedText.string == content)

        // An update of the existing view must ignore its stale initialization input.
        let changed = (content as NSString).range(of: "l’unità scelta")
        recreatedText.setSelectedRange(changed)
        try await Task.sleep(for: .milliseconds(50))
        #expect(study.nativeSelection(.first) == changed)
        recreated.rootView = StudioStudyTextReader(
            reading: reading, accessibilityTitle: "Titolo aggiornato", initialSelection: selected
        ) { range in
            study.setNativeSelection(range, sourceID: firstID, slot: .first)
        }
        recreated.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        #expect(recreatedText.selectedRange() == changed)
        #expect(study.nativeSelection(.first) == changed)

        let caret = NSRange(location: changed.location + changed.length, length: 0)
        recreatedText.setSelectedRange(caret)
        try await Task.sleep(for: .milliseconds(50))
        #expect(study.nativeSelection(.first) == caret)
        let caretHost = NSHostingView(rootView: render(reading))
        window.contentView = caretHost
        caretHost.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        let caretText = try #require(descendant(of: NSTextView.self, in: caretHost))
        #expect(caretText.selectedRange() == caret)
        #expect(!study.hasNativeSelection(.first))

        // Out-of-bounds values must never reach AppKit, including overflowing end offsets.
        for invalid in [
            NSRange(location: Int.max, length: Int.max), NSRange(location: 0, length: Int.max),
            NSRange(location: -1, length: 0), NSRange(location: 0, length: -1),
        ] {
            let invalidHost = NSHostingView(
                rootView: StudioStudyTextReader(
                    reading: reading, accessibilityTitle: "Intervallo non valido",
                    initialSelection: invalid, onSelection: { _ in }))
            window.contentView = invalidHost
            invalidHost.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
            let text = try #require(descendant(of: NSTextView.self, in: invalidHost))
            #expect(text.selectedRange() == NSRange(location: 0, length: 0))
            #expect(text.string == content)
        }

        try await study.readSource(session: session, sourceID: secondID, slot: .first)
        let next = try #require(study.firstReading)
        #expect(next.navigationID != reading.navigationID)
        #expect(study.nativeSelection(.first) == nil)
        #expect(!study.hasNativeSelection(.first))
        window.contentView = recreated
        recreated.rootView = render(next)
        recreated.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        #expect(recreatedText.string == next.text)
        #expect(recreatedText.selectedRange() == NSRange(location: 0, length: 0))
        await session.close()
    }

    @Test("La raccolta da menu segue la lettura visibile dopo il ridimensionamento")
    func studyCompactCommandsUseTheVisibleReadingInsteadOfTheHiddenSelection() async throws {
        let fixture = try await makeStudyNavigationFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let study = fixture.home.study
        let session = try #require(fixture.home.researchProjectSession)
        let first = try #require(study.firstReading)
        let second = try #require(study.secondReading)
        study.setNativeSelection(
            NSRange(location: 0, length: (first.text as NSString).length),
            sourceID: first.sourceRevisionID, slot: .first)
        study.setNativeSelection(
            NSRange(location: 0, length: (second.text as NSString).length),
            sourceID: second.sourceRevisionID, slot: .second)
        study.showsComparison = true
        let wideTarget = StudioStudyReaderSlot.commandTarget(
            isComparing: true, isCompact: false, activeSlot: .second, compactSlot: .first)
        try await study.previewNativeSelection(session: session, slot: wideTarget)
        #expect(study.pendingSourceID == second.sourceRevisionID)
        study.clearPendingPassage()

        let compactTarget = StudioStudyReaderSlot.commandTarget(
            isComparing: true, isCompact: true, activeSlot: .second, compactSlot: .first)
        try await study.previewNativeSelection(session: session, slot: compactTarget)
        #expect(study.pendingSourceID == first.sourceRevisionID)
        #expect(study.pendingPassage?.text == first.text)
        await fixture.home.closeProject()
    }

    @Test(
        "Il foglio Studio conserva la bozza e impedisce la navigazione del workspace",
        arguments: [false, true])
    func studyModalPreventsWorkspaceNavigationAndKeepsItsDraft(isConclusion: Bool) async throws {
        let fixture = try await makeStudyNavigationFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let home = fixture.home
        var commandActions: StudioStudyActions?
        let controller = NSHostingController(
            rootView: StudyViewportProbe(
                home: home, showsStudy: true, dynamicTypeSize: .large,
                onStudyActionsChanged: { commandActions = $0 }))
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 1_280, height: 700),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderBack(nil)
        defer {
            if let sheet = window.attachedSheet { window.endSheet(sheet) }
            window.contentViewController = nil
            window.close()
        }
        controller.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        if isConclusion {
            let actions = try #require(commandActions)
            #expect(actions.canCreateConclusion)
            actions.newConclusion()
        } else {
            let session = try #require(home.researchProjectSession)
            try await home.study.previewPassage(
                session: session, slot: .first, selection: .sentences(first: 0, last: 0))
        }
        controller.view.layoutSubtreeIfNeeded()
        for _ in 0..<30 {
            if window.attachedSheet != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let sheet = try #require(window.attachedSheet)
        let content = try #require(sheet.contentView)
        let titleField = try #require(editableTextField(in: content))
        let draftTitle = "Titolo della bozza da conservare"
        titleField.stringValue = draftTitle
        titleField.delegate?.controlTextDidChange?(
            Notification(name: NSControl.textDidChangeNotification, object: titleField))
        try await Task.sleep(for: .milliseconds(50))
        #expect(titleField.stringValue == draftTitle)
        if !isConclusion { #expect(home.study.pendingTitle == draftTitle) }
        #expect(home.isWorkspaceNavigationProtected)

        home.performWorkspaceNavigation {
            controller.rootView = StudyViewportProbe(
                home: home, showsStudy: false, dynamicTypeSize: .large)
        }
        controller.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(controller.rootView.showsStudy)
        #expect(window.attachedSheet === sheet)
        #expect(titleField.stringValue == draftTitle)
        if window.attachedSheet === sheet {
            let escape = try #require(
                NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: sheet.windowNumber, context: nil,
                    characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                    isARepeat: false, keyCode: 53))
            #expect(sheet.performKeyEquivalent(with: escape))
            for _ in 0..<30 {
                if !home.isWorkspaceNavigationProtected, window.attachedSheet == nil { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(!home.isWorkspaceNavigationProtected)
            #expect(window.attachedSheet == nil)
            home.performWorkspaceNavigation {
                controller.rootView = StudyViewportProbe(
                    home: home, showsStudy: false, dynamicTypeSize: .large)
            }
            #expect(!controller.rootView.showsStudy)
        }
        await home.closeProject()
    }

    private func makeStudyNavigationFixture() async throws -> (root: URL, home: StudioHomeModel) {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudyNavigation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let home = StudioHomeModel()
        await home.attachDocument(
            at: root.appending(path: "Studio.glifi"), needsPackageInitialization: true)
        let first = root.appending(path: "prima.txt")
        let second = root.appending(path: "seconda.txt")
        try Data("La prima lettura mantiene il contenuto scelto.".utf8).write(to: first)
        try Data("La seconda lettura offre un confronto distinto.".utf8).write(to: second)
        await home.importSources(at: [first, second])
        let session = try #require(home.researchProjectSession)
        let sources = try #require(home.snapshot?.sources)
        try #require(sources.count == 2)
        try await home.study.load(session: session)
        try await home.study.readSource(
            session: session, sourceID: sources[0].sourceRevisionID, slot: .first)
        try await home.study.readSource(
            session: session, sourceID: sources[1].sourceRevisionID, slot: .second)
        return (root, home)
    }

    private func editableTextField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for child in view.subviews {
            if let field = editableTextField(in: child) { return field }
        }
        return nil
    }

    @Test("Una vecchia presentazione Studio non rimuove la protezione di quella corrente")
    func studyNavigationProtectionBelongsToTheCurrentPresentation() {
        let home = StudioHomeModel()
        let previous = UUID()
        let current = UUID()
        var navigations = 0
        home.setStudyNavigationProtection(true, owner: previous)
        home.setStudyNavigationProtection(true, owner: current)
        home.setStudyNavigationProtection(false, owner: previous)
        home.performWorkspaceNavigation { navigations += 1 }
        #expect(home.isWorkspaceNavigationProtected)
        #expect(navigations == 0)
        home.setStudyNavigationProtection(false, owner: current)
        home.performWorkspaceNavigation { navigations += 1 }
        #expect(!home.isWorkspaceNavigationProtected)
        #expect(navigations == 1)
    }

    @Test(
        "Aprire Studio non ingrandisce una finestra bassa, anche con il taccuino",
        arguments: [false, true], [DynamicTypeSize.large, .accessibility3])
    func studyWorkspaceFitsTheExistingWindowHeight(
        showsNotebook: Bool, dynamicTypeSize: DynamicTypeSize
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudyViewport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "Studio.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        let file = root.appending(path: "fonte.txt")
        try Data(
            "Studiare il contenuto collega le idee alle fonti. Una conclusione mantiene i passaggi verificabili. Il testo conserva la sua revisione originale."
                .utf8
        ).write(to: file)
        let imported = try await session.importText(at: file, format: .plainText)
        let sourceID = try #require(imported.project.sources.first?.sourceRevisionID)
        var state = try await session.studyState()
        for sentence in 0..<2 {
            state = try await session.collectStudyExcerpt(
                sourceRevisionID: sourceID, selection: .sentences(first: sentence, last: sentence),
                title: "Passaggio \(sentence + 1)", expectedRevision: state.revision)
        }
        for index in 0..<2 {
            let note = GlifiStudioStudyNote(
                id: UUID().uuidString.lowercased(), title: "Conclusione \(index + 1)",
                text: "La conclusione rimanda al documento e conserva il proprio contesto.",
                excerptIDs: state.excerpts.map(\.id))
            state.notes.append(note)
            state.order.append(note.id)
        }
        _ = try await session.saveStudyState(state, expectedRevision: state.revision)
        await session.close()
        let home = StudioHomeModel()
        await home.openProject(at: project)
        let activeSession = try #require(home.researchProjectSession)
        try await home.study.load(session: activeSession)
        try await home.study.readSource(session: activeSession, sourceID: sourceID, slot: .first)
        home.study.showsNotebook = showsNotebook

        let controller = NSHostingController(
            rootView: StudyViewportProbe(
                home: home, showsStudy: false, dynamicTypeSize: dynamicTypeSize))
        controller.sizingOptions = [.minSize]
        let requestedSize = NSSize(width: 1_280, height: 590)
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -20_000, y: -20_000), size: requestedSize),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderBack(nil)
        defer {
            window.contentViewController = nil
            window.close()
        }
        controller.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        window.setContentSize(requestedSize)
        let frameBeforeStudy = window.frame
        controller.rootView = StudyViewportProbe(
            home: home, showsStudy: true, dynamicTypeSize: dynamicTypeSize)
        controller.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        #expect(window.frame.height <= frameBeforeStudy.height + 1)
        #expect(window.contentMinSize.height <= requestedSize.height)
        #expect(controller.view.bounds.height <= requestedSize.height + 1)
        let text = try #require(descendant(of: NSTextView.self, in: controller.view))
        #expect(text.enclosingScrollView?.contentSize.height ?? 0 > 120)
        #expect(!text.isEditable)
        #expect(text.isSelectable)
        #expect(home.study.firstReading?.sourceRevisionID == sourceID)

        window.setContentSize(NSSize(width: 1_000, height: 500))
        controller.view.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(window.contentRect(forFrameRect: window.frame).height <= 501)
        #expect(text.enclosingScrollView?.contentSize.height ?? 0 > 80)
        #expect(home.study.showsNotebook == showsNotebook)
        await home.closeProject()
    }

    private struct StudyViewportProbe: View {
        let home: StudioHomeModel
        let showsStudy: Bool
        let dynamicTypeSize: DynamicTypeSize
        var onStudyActionsChanged: ((StudioStudyActions?) -> Void)? = nil

        var body: some View {
            NavigationSplitView {
                List {
                    Text("Fonti")
                    Text("Studio")
                    Text("Esporta")
                }
                .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 320)
            } detail: {
                if showsStudy {
                    StudioStudyView(
                        home: home, onImportSources: {}, onOpenProject: {},
                        onCommandActionsChanged: onStudyActionsChanged
                    ) {
                        HStack {
                            Text("Progetto di studio")
                            Spacer()
                            Text("Una fonte")
                        }
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                    }
                } else {
                    Text("Esporta").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .environment(\.locale, Locale(identifier: "it_IT"))
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
    }

    @Test("Il lettore nativo scorre fino alla fine di un testo lungo e conserva il contesto")
    func studyNativeReaderScrollsLongDocumentsAndPreservesSelectionOnResize() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudyScrolling-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Studio.glifi"))
        let lastSentence = "Ultima frase verificabile."
        let content =
            (0..<3_000).map { index in
                "Passaggio \(index): studiare il contenuto richiede una lettura attenta, il confronto delle fonti e conclusioni sempre riconducibili al documento originale."
            }.joined(separator: "\n") + "\n" + lastSentence
        let file = root.appending(path: "documento-lungo.txt")
        try Data(content.utf8).write(to: file)
        let imported = try await session.importText(at: file, format: .plainText)
        let sourceID = try #require(imported.project.sources.first?.sourceRevisionID)
        let source = try await session.sourceText(sourceRevisionID: sourceID)
        await session.close()
        let reading = StudioStudyReading(
            sourceRevisionID: sourceID, source: source, text: content, segments: [],
            characterCount: content.count, title: "Documento lungo", pdf: nil,
            pageNumber: nil, highlight: nil, navigationID: UUID())
        let reader = StudioStudyTextReader(
            reading: reading, accessibilityTitle: "Testo del documento", onSelection: { _ in })
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 800, height: 480),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: reader)
        window.contentView = host
        window.orderBack(nil)
        defer {
            window.contentView = nil
            window.close()
        }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let scroll = try #require(descendant(of: NSScrollView.self, in: host))
        let text = try #require(scroll.documentView as? NSTextView)
        #expect(text.string == content)
        #expect(scroll.contentSize.width > 700)
        #expect(scroll.contentSize.height > 400)
        let finalRange = (content as NSString).range(of: lastSentence)
        try #require(finalRange.location != NSNotFound)
        text.setSelectedRange(finalRange)
        text.scrollRangeToVisible(finalRange)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(text.frame.height > scroll.contentSize.height * 20)
        #expect(scroll.contentView.bounds.minY > scroll.contentSize.height)
        #expect(text.selectedRange() == finalRange)
        #expect(selectionIsVisible(finalRange, in: text, window: window))

        // An ordinary SwiftUI update must not reapply the initial scroll-to-start.
        let offsetBeforeUpdate = scroll.contentView.bounds.origin
        host.rootView = StudioStudyTextReader(
            reading: reading, accessibilityTitle: "Documento aggiornato", onSelection: { _ in })
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(text.selectedRange() == finalRange)
        #expect(abs(scroll.contentView.bounds.minY - offsetBeforeUpdate.y) <= 1)

        let wideHeight = text.frame.height
        window.setContentSize(NSSize(width: 360, height: 320))
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(scroll.contentSize.width < 400)
        #expect(scroll.contentSize.height > 250)
        #expect(text.selectedRange() == finalRange)
        #expect(scroll.contentView.bounds.minY > 0)
        text.scrollRangeToVisible(finalRange)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(text.frame.height > wideHeight)
        #expect(selectionIsVisible(finalRange, in: text, window: window))

        window.setContentSize(NSSize(width: 800, height: 480))
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(text.selectedRange() == finalRange)
        #expect(scroll.contentView.bounds.minY > 0)
        text.scrollRangeToVisible(finalRange)
        #expect(selectionIsVisible(finalRange, in: text, window: window))
    }

    private func descendant<NativeView: NSView>(of type: NativeView.Type, in view: NSView)
        -> NativeView?
    {
        if let match = view as? NativeView { return match }
        for child in view.subviews {
            if let match = descendant(of: type, in: child) { return match }
        }
        return nil
    }

    private func selectionIsVisible(_ range: NSRange, in text: NSTextView, window: NSWindow)
        -> Bool
    {
        let rectOnScreen = text.firstRect(forCharacterRange: range, actualRange: nil)
        let rect = text.convert(window.convertFromScreen(rectOnScreen), from: nil)
        return !rect.isEmpty && text.visibleRect.intersects(rect)
    }

    @Test("Aprire Studio durante un’altra operazione avvia la lettura appena il progetto è libero")
    func studyOpenedDuringAnOperationInitializesAfterItFinishes() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudyStartup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "Studio.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        let source = root.appending(path: "fonte.txt")
        try Data("Un contenuto importante da studiare.".utf8).write(to: source)
        _ = try await session.importText(at: source, format: .plainText)
        await session.close()
        let home = StudioHomeModel()
        await home.openProject(at: project)
        try #require(home.snapshot != nil)
        let gate = AsyncStream<Void>.makeStream()
        let started = AsyncStream<Void>.makeStream()
        let operation = Task { @MainActor in
            await home.runAdvancedAnalysis { _ in
                started.continuation.yield(())
                for await _ in gate.stream { break }
            }
        }
        defer {
            gate.continuation.finish()
            started.continuation.finish()
            operation.cancel()
        }
        var starting = started.stream.makeAsyncIterator()
        _ = await starting.next()
        try #require(home.isBusy)
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 1_100, height: 700),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(
            rootView: StudioStudyView(home: home, onImportSources: {}, onOpenProject: {}))
        window.contentView = host
        window.orderBack(nil)
        defer {
            window.contentView = nil
            window.close()
        }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(!home.study.hasLoaded)
        gate.continuation.finish()
        await operation.value
        for _ in 0..<150 {
            if home.study.hasLoaded, home.study.firstReading != nil, !home.isBusy { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(home.lastFailure == nil)
        #expect(home.study.hasLoaded)
        #expect(home.study.firstReading?.text == "Un contenuto importante da studiare.")
        #expect(!home.isBusy)
        // A later ordinary operation must not reload or replace the current reading.
        let navigation = home.study.firstReading?.navigationID
        await home.runAdvancedAnalysis { _ in }
        try await Task.sleep(for: .milliseconds(100))
        #expect(home.study.firstReading?.navigationID == navigation)
        await home.closeProject()
    }

    @Test(arguments: ["it_IT", "en_US"])
    func dynamicallyComposedLocalizationValuesResolveInTheSelectedLanguage(identifier: String)
        throws
    {
        let italian = identifier == "it_IT"
        let path = try #require(
            Bundle(for: BundleAnchor.self).path(
                forResource: italian ? "it" : "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let locale = Locale(identifier: identifier)
        let alternative = GlifiStudioStatisticsAlternative.twoSided
        let level = "interval"
        let alternativeLabel = String(
            localized: StudioLocalization.value("statistics.alternative.\(alternative.rawValue)"),
            bundle: bundle, locale: locale)
        let levelLabel = String(
            localized: StudioLocalization.value("statistics.level.\(level)"),
            bundle: bundle, locale: locale)
        #expect(alternativeLabel == (italian ? "Bilaterale" : "Two-sided"))
        #expect(levelLabel == (italian ? "Intervallo" : "Interval"))
        let exportFormats = [
            ("json", "JSON"), ("markdown", "Markdown"), ("csv", "CSV"), ("pdf", "PDF/A-2u"),
        ]
        for (format, expectedLabel) in exportFormats {
            #expect(
                String(
                    localized: StudioLocalization.value("export.format.\(format)"),
                    bundle: bundle, locale: locale) == expectedLabel)
        }
        #expect(
            String(localized: "statistics.table.count \(17)", bundle: bundle, locale: locale)
                == (italian ? "Righe corrispondenti: 17" : "Matching rows: 17"))
    }

    @Test(arguments: ["it_IT", "en_US"])
    func dynamicallyComposedKeysMatchNativeRenderingOfTheExpectedText(identifier: String)
        throws
    {
        let bundle = Bundle(for: BundleAnchor.self)
        let italian = identifier == "it_IT"
        let operation = GlifiStudioStatisticsOperation.welchT
        let alternative = GlifiStudioStatisticsAlternative.twoSided
        let operatorMethod = GlifiStudioCoreOperator.pca
        let table = "tokens"
        let validation = "supported"
        let level = "interval"
        let exportFormats = ["json", "markdown", "csv", "pdf"]
        let expected = [
            italian ? "Confrontare due medie · Welch" : "Compare two means · Welch",
            italian
                ? "Due righe, una per ciascuna serie. Nei metodi appaiati i valori nella stessa posizione costituiscono una coppia: lunghezze diverse o dati mancanti non vengono corretti."
                : "Two rows, one per series. For paired methods, values at the same position form a pair: unequal lengths and missing data are not corrected.",
            italian ? "Bilaterale" : "Two-sided",
            italian
                ? "Analisi delle componenti principali (PCA)"
                : "Principal component analysis (PCA)",
            italian ? "Token e annotazioni" : "Tokens and annotations",
            italian
                ? "Supportata nel contratto dichiarato" : "Supported within the stated contract",
            italian ? "Intervallo" : "Interval",
            italian ? "Righe corrispondenti: 17" : "Matching rows: 17",
            "JSON", "Markdown", "CSV", "PDF/A-2u",
        ]
        let content =
            [
                Text(
                    StudioLocalization.key("statistics.operation.\(operation.rawValue)"),
                    bundle: bundle
                ),
                Text(
                    StudioLocalization.key("statistics.input.\(operation.inputKind.rawValue)"),
                    bundle: bundle),
                Text(
                    StudioLocalization.key("statistics.alternative.\(alternative.rawValue)"),
                    bundle: bundle),
                Text(
                    StudioLocalization.key("operators.method.\(operatorMethod.rawValue)"),
                    bundle: bundle),
                Text(StudioLocalization.key("linguistic.table.\(table)"), bundle: bundle),
                Text(StudioLocalization.key("advanced.validation.\(validation)"), bundle: bundle),
                Text(StudioLocalization.key("statistics.level.\(level)"), bundle: bundle),
                // Ordinary localized message arguments remain interpolation, rather than key components.
                Text("statistics.table.count \(17)", bundle: bundle),
            ]
            + exportFormats.map { format in
                Text(StudioLocalization.key("export.format.\(format)"), bundle: bundle)
            }
        let locale = Locale(identifier: identifier)
        try #require(content.count == expected.count)
        for (text, expectedText) in zip(content, expected) {
            let observedSize = try fittingSize(of: text, locale: locale)
            let expectedSize = try fittingSize(of: Text(verbatim: expectedText), locale: locale)
            #expect(observedSize == expectedSize, Comment(rawValue: expectedText))
        }

        // These original constructors intentionally reproduce the interpolation defect.
        // Their fallback geometry must differ from the independently declared translations.
        let unbridgedOperation = Text(
            LocalizedStringKey("statistics.operation.\(operation.rawValue)"), bundle: bundle)
        let unbridgedAlternative = Text(
            LocalizedStringKey("statistics.alternative.\(alternative.rawValue)"), bundle: bundle)
        #expect(
            try fittingSize(of: unbridgedOperation, locale: locale)
                != fittingSize(of: Text(verbatim: expected[0]), locale: locale))
        #expect(
            try fittingSize(of: unbridgedAlternative, locale: locale)
                != fittingSize(of: Text(verbatim: expected[2]), locale: locale))
        for (format, expectedLabel) in zip(exportFormats, expected.suffix(exportFormats.count)) {
            let unbridgedFormat = Text("export.format.\(format)", bundle: bundle)
            #expect(
                try fittingSize(of: unbridgedFormat, locale: locale)
                    != fittingSize(of: Text(verbatim: expectedLabel), locale: locale))
        }
    }

    private func fittingSize(of text: Text, locale: Locale) throws -> NSSize {
        _ = NSApplication.shared
        let host = NSHostingView(
            rootView: text.font(.system(size: 17)).fixedSize()
                .environment(\.locale, locale))
        let size = host.fittingSize
        try #require(
            size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0)
        return size
    }

    @Test func submittingAnAmbiguousToolSearchKeepsTheCatalogOpen() {
        let method = StudioCoreMethodRoute.corpus(.pca)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [.themes, .corpusMethods], coreMethods: [method]) == nil)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [.themes], coreMethods: [method, .corpus(.lsa)]) == nil)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [.themes], coreMethods: [method]) == nil)
    }

    @Test func submittingAUniqueOrEmptyToolSearchUsesOnlyTheVisibleResults() {
        let method = StudioCoreMethodRoute.corpus(.pca)
        #expect(StudioToolCatalogDestination.submission(tools: [], coreMethods: []) == nil)
        #expect(
            StudioToolCatalogDestination.submission(tools: [.query], coreMethods: [])
                == .tool(.query))
        #expect(
            StudioToolCatalogDestination.submission(tools: [], coreMethods: [method])
                == .core(method))
        #expect(
            StudioToolCatalogDestination.submission(tools: [.query, .coding], coreMethods: [])
                == nil)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [], coreMethods: [method, .corpus(.lsa)]) == nil)
    }

    @Test func methodSearchDoesNotPreferItsSingleCoreResultOverMatchingTools() {
        let locale = Locale(identifier: "it_IT")
        let tools = StudioToolDestination.allCases.filter { $0.matches("PageRank", locale: locale) }
        let methods = StudioCoreMethodRoute.allCases.filter {
            $0.matches("PageRank", locale: locale)
        }
        #expect(tools == [.operators])
        #expect(methods == [.operators(.pageRank)])
        #expect(StudioToolCatalogDestination.submission(tools: tools, coreMethods: methods) == nil)
    }

    @Test func discoversMethodsByMultipleWordsWithoutChangingTheQueryLanguage() {
        let locale = Locale(identifier: "it_IT")
        let matches = StudioToolDestination.allCases.filter {
            $0.matches("  ZIPF   Heaps  ", locale: locale)
        }
        #expect(matches == [.lexicalLaws, .operators])
        #expect(StudioToolDestination.query.matches("kwic", locale: locale))
        #expect(StudioToolDestination.classifierValidation.matches("naive k-fold", locale: locale))
        #expect(!StudioToolDestination.query.matches("BM25", locale: locale))
    }

    @Test func browsingAnotherSourceKeepsTheConcordanceAndItsSelection() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkspaceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Workspace.glifi"), needsPackageInitialization: true)
        let first = root.appending(path: "first.txt")
        let second = root.appending(path: "second.md")
        try Data("La casa conserva le parole.".utf8).write(to: first)
        try Data("# Il mare\nUna fonte diversa.".utf8).write(to: second)
        await model.importSources(at: [first, second])
        model.queryDraft = "normalized:casa"
        await model.runQuery()
        let query = try #require(model.queryResult)
        let match = try #require(model.selectedQueryMatch)
        let original = try #require(model.sourceText)
        let other = try #require(
            model.snapshot?.sources.first { $0.sourceRevisionID != match.sourceRevisionID })

        await model.browseSource(other.sourceRevisionID)

        #expect(model.lastFailure == nil)
        #expect(model.browsedSourceText?.sourceRevisionID == other.sourceRevisionID)
        #expect(model.browsedSourceText?.text.contains("mare") == true)
        #expect(model.queryResult == query)
        #expect(model.selectedQueryMatchID == match.id)
        #expect(model.sourceText == original)

        await model.planInvestigation()
        let previousPlan = try #require(model.planResult)
        #expect(!model.isPlanDraftChanged)
        model.selectedIntent = .identifyThemes
        #expect(model.isPlanDraftChanged)
        #expect(model.planResult == previousPlan)

        await model.attachDocument(
            at: root.appending(path: "Another.glifi"), needsPackageInitialization: true)
        #expect(model.lastFailure == nil)
        #expect(model.browsedSourceText == nil)
        #expect(model.queryResult == nil)
    }
}

@MainActor struct StudioThematicWorkflowTests {
    @Test func everyAnalyticalFamilyHasAnExecutableRouteAndLocalizedRole() throws {
        let routes = StudioCoreMethodRoute.allCases
        #expect(Set(routes.map(\.id)).count == routes.count)
        #expect(
            Set(
                routes.compactMap { route -> StudioAdvancedTool? in
                    if case let .advanced(value) = route { return value }
                    return nil
                }) == Set(StudioAdvancedTool.allCases))
        #expect(
            Set(
                routes.compactMap { route -> StudioKHMatrixTool? in
                    if case let .khMatrix(value) = route { return value }
                    return nil
                }) == Set(StudioKHMatrixTool.allCases))
        #expect(
            Set(
                routes.compactMap { route -> StudioKHLanguageTool? in
                    if case let .khLanguage(value) = route { return value }
                    return nil
                }) == Set(StudioKHLanguageTool.allCases))
        let catalogURL = URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Shared/Resources/Localizable.xcstrings")
        let catalog = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        for route in routes {
            for key in [
                route.titleKey, route.purposeKey, route.theme.titleKey,
                route.theme.descriptionKey,
            ] {
                let localizations = try #require(
                    strings[key]?["localizations"] as? [String: Any],
                    "Missing context for \(route.id): \(key)")
                for language in ["it", "en"] {
                    let localized = try #require(localizations[language] as? [String: Any])
                    let unit = try #require(localized["stringUnit"] as? [String: Any])
                    let text = try #require(unit["value"] as? String)
                    #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    #expect(text != key)
                }
            }
        }
        #expect(Set(routes.map(\.theme)) == Set(StudioAnalysisTheme.allCases))
        #expect(StudioCoreMethodRoute.corpus(.hierarchical).theme == .structure)
        #expect(StudioCoreMethodRoute.operators(.pageRank).theme == .relationships)
        #expect(StudioCoreMethodRoute.statistics(.cohenKappa).theme == .coding)
        #expect(StudioCoreMethodRoute.evaluation(.lemmas).theme == .validation)
    }
}
