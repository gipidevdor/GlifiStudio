// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Content comes first: one reader, with comparison and the notebook requested explicitly.
struct StudioStudyView<WorkspaceContext: View>: View {
    @Bindable var home: StudioHomeModel
    let onImportSources: () -> Void
    let onOpenProject: () -> Void
    private let workspaceContext: WorkspaceContext
    private let onCommandActionsChanged: ((StudioStudyActions?) -> Void)?
    @Bindable private var study: StudioStudyModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var pdfSlots: Set<StudioStudyReaderSlot> = [.first, .second]
    @State private var compactSlot: StudioStudyReaderSlot = .first
    @State private var editor: StudioStudyEditor?
    @State private var showsOrganization = false
    @State private var exportData: Data?
    @State private var exportType = UTType.json
    @State private var exportFailed = false
    @State private var showsRestoreImporter = false
    @State private var headerWidth: CGFloat = 0
    @State private var accessibleSelectionSlot: StudioStudyReaderSlot?
    @State private var activeReaderSlot: StudioStudyReaderSlot = .first
    @State private var navigationProtectionOwner = UUID()

    init(
        home: StudioHomeModel, onImportSources: @escaping () -> Void,
        onOpenProject: @escaping () -> Void,
        onCommandActionsChanged: ((StudioStudyActions?) -> Void)? = nil,
        @ViewBuilder workspaceContext: () -> WorkspaceContext
    ) {
        self.home = home
        self.onImportSources = onImportSources
        self.onOpenProject = onOpenProject
        self.workspaceContext = workspaceContext()
        self.onCommandActionsChanged = onCommandActionsChanged
        study = home.study
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                workspaceContext
                studyContent(width: geometry.size.width)
            }
        }
        .navigationTitle("study.title")
        .inspector(isPresented: $study.showsNotebook) {
            notebook.inspectorColumnWidth(min: 280, ideal: 340, max: 460)
        }
        .focusedSceneValue(\.studioStudyActions, studySceneActions)
        .onChange(of: commandAvailability, initial: true) { _, _ in
            onCommandActionsChanged?(studySceneActions)
        }
        .onChange(of: protectsWorkspaceNavigation, initial: true) { _, isPresented in
            home.setStudyNavigationProtection(isPresented, owner: navigationProtectionOwner)
        }
        .onDisappear {
            home.setStudyNavigationProtection(false, owner: navigationProtectionOwner)
            onCommandActionsChanged?(nil)
        }
        .sheet(item: $editor) { editing in
            StudioStudyObjectEditor(
                study: study, editing: editing, isBusy: home.isBusy,
                failureMessage: home.failureMessage, onReload: reloadNotebook
            ) {
                title, text, group, support in
                Task {
                    await home.runAdvancedAnalysis { session in
                        try await study.commitEditorChange(session: session) {
                            switch editing {
                            case let .excerpt(id):
                                try study.updateExcerpt(id: id, title: title, groupID: group)
                            case let .note(id):
                                study.saveNote(
                                    id: id, title: title, text: text, groupID: group,
                                    excerptIDs: support)
                            }
                        }
                        try await home.refreshAfterResearchChange()
                    }
                    if home.lastFailure == nil { editor = nil }
                }
            }
        }
        .sheet(isPresented: $showsOrganization) {
            StudioStudyOrganizationEditor(home: home, study: study)
        }
        .fileImporter(isPresented: $showsRestoreImporter, allowedContentTypes: [.json]) { result in
            guard case let .success(url) = result else { return }
            Task {
                await home.runAdvancedAnalysis { _ in
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try await study.prepareRestore(at: url)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { study.proposedRestore != nil },
                set: { if !$0 { study.proposedRestore = nil } })
        ) {
            restorePreview
        }
        .sheet(
            isPresented: Binding(
                get: { study.pendingPassage != nil },
                set: { if !$0 { study.clearPendingPassage() } })
        ) {
            collectionPreview
        }
        .fileExporter(
            isPresented: Binding(get: { exportData != nil }, set: { if !$0 { exportData = nil } }),
            document: exportData.map(StudioStudyExportDocument.init), contentType: exportType,
            defaultFilename: "GlifiStudio-Studio"
        ) { outcome in
            if case let .failure(error) = outcome,
                (error as? CocoaError)?.code != .userCancelled
            {
                exportFailed = true
            }
            exportData = nil
        }
        .alert("visual.export.failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
        .task(id: home.snapshot?.projectID) {
            await initializeNotebookIfNeeded()
        }
        .onChange(of: home.snapshot?.sources.map(\.sourceRevisionID)) { _, _ in
            openFirstAvailableSource()
        }
        .onChange(of: compactSlot) { _, slot in activeReaderSlot = slot }
        .onChange(of: home.isBusy) { _, busy in
            guard !busy else { return }
            if !study.hasLoaded, home.lastFailure == nil {
                Task { await initializeNotebookIfNeeded() }
            } else {
                openFirstAvailableSource()
            }
        }
    }

    @ViewBuilder private func studyContent(width: CGFloat) -> some View {
        if home.snapshot == nil {
            ContentUnavailableView {
                Label("study.empty.project", systemImage: "book.closed")
            } description: {
                Text("study.empty.project-help")
            } actions: {
                Button("action.open-project", systemImage: "folder") { onOpenProject() }
            }
        } else if home.snapshot?.sources.isEmpty != false {
            ContentUnavailableView {
                Label("study.empty.sources", systemImage: "doc.badge.plus")
            } description: {
                Text("study.empty.sources-help")
            } actions: {
                Button("action.import", systemImage: "doc.badge.plus") { onImportSources() }
                    .disabled(home.isBusy)
            }
        } else {
            VStack(spacing: 0) {
                header
                Divider()
                readingWorkspace(width: width)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                status
            }
        }
    }

    @ViewBuilder private func readingWorkspace(width: CGFloat) -> some View {
        if study.showsComparison {
            if width >= 880 && !dynamicTypeSize.isAccessibilitySize {
                HSplitView {
                    reader(.first, compactControls: true).frame(minWidth: 320)
                    reader(.second, compactControls: true).frame(minWidth: 320)
                }
            } else {
                compactReadings
            }
        } else {
            reader(
                .first,
                compactControls: width < 640 || dynamicTypeSize.isAccessibilitySize)
        }
    }

    private var compactReadings: some View {
        TabView(selection: $compactSlot) {
            Tab(value: StudioStudyReaderSlot.first) {
                reader(.first, compactControls: true)
            } label: {
                Text("study.reading.first")
            }
            Tab(value: StudioStudyReaderSlot.second) {
                reader(.second, compactControls: true)
            } label: {
                Text("study.reading.second")
            }
        }
        .tabViewStyle(.grouped)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("study.reading.help")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if headerWidth < 520 || dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { workspaceControls }
            } else {
                HStack(spacing: 12) {
                    workspaceControls
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            headerWidth = $0
        }
    }

    @ViewBuilder private var workspaceControls: some View {
        Button(
            LocalizedStringKey(
                study.showsComparison ? "study.compare.close" : "study.compare.open"),
            systemImage: "rectangle.split.2x1"
        ) { toggleComparison() }
        .disabled(home.isBusy)
        Button("study.notebook", systemImage: "note.text") { study.showsNotebook.toggle() }
        Button("study.conclusion.new", systemImage: "square.and.pencil") {
            editor = .newConclusion()
        }
        .accessibilityIdentifier("study.conclusion.new")
        .disabled(home.isBusy || !study.hasLoaded)
    }

    private var allowsStudyCommands: Bool {
        study.hasLoaded && home.snapshot != nil && !protectsWorkspaceNavigation
    }

    private var commandAvailability: [Bool] {
        [
            allowsStudyCommands, canCollectFromCommand, canCompareFromCommand,
            study.showsNotebook, study.showsComparison,
        ]
    }

    private var protectsWorkspaceNavigation: Bool {
        home.snapshot != nil
            && (home.isBusy || editor != nil || showsOrganization || exportData != nil
                || exportFailed || showsRestoreImporter || study.proposedRestore != nil
                || study.pendingPassage != nil || accessibleSelectionSlot != nil)
    }

    private var commandReaderSlot: StudioStudyReaderSlot {
        StudioStudyReaderSlot.commandTarget(
            isComparing: study.showsComparison,
            isCompact: headerWidth < 880 || dynamicTypeSize.isAccessibilitySize,
            activeSlot: activeReaderSlot, compactSlot: compactSlot)
    }

    private var canCollectFromCommand: Bool {
        let slot = commandReaderSlot
        guard allowsStudyCommands, let reading = study.reading(slot) else { return false }
        return study.hasNativeSelection(slot) && (reading.pdf == nil || !pdfSlots.contains(slot))
    }

    private var canCompareFromCommand: Bool {
        allowsStudyCommands && home.snapshot?.sources.isEmpty == false
    }

    private var studySceneActions: StudioStudyActions? {
        guard allowsStudyCommands else { return nil }
        return StudioStudyActions(
            collectPassage: {
                guard canCollectFromCommand else { return }
                previewSelection(commandReaderSlot)
            },
            newConclusion: {
                guard allowsStudyCommands else { return }
                editor = .newConclusion()
            },
            toggleNotebook: {
                guard allowsStudyCommands else { return }
                study.showsNotebook.toggle()
            },
            toggleComparison: {
                guard canCompareFromCommand else { return }
                toggleComparison()
            },
            canCollectPassage: canCollectFromCommand, canCreateConclusion: true,
            canToggleNotebook: true, canToggleComparison: canCompareFromCommand,
            showsNotebook: study.showsNotebook, showsComparison: study.showsComparison)
    }

    private func reader(_ slot: StudioStudyReaderSlot, compactControls: Bool) -> some View {
        let controlsLayout =
            compactControls
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if study.showsComparison {
                    Text(
                        LocalizedStringKey(
                            slot == .first ? "study.reading.first" : "study.reading.second")
                    )
                    .font(.headline)
                }
                controlsLayout {
                    sourcePicker(slot).frame(maxWidth: .infinity, alignment: .leading)
                    readingActions(slot).fixedSize(horizontal: false, vertical: true)
                }
                if study.reading(slot)?.pdf != nil {
                    Picker("study.reading.format", selection: pdfBinding(slot)) {
                        Text("study.reading.pdf").tag(true)
                        Text("study.reading.text").tag(false)
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 180)
                }
            }
            .padding()
            .fixedSize(horizontal: false, vertical: true)
            if let reading = study.reading(slot) {
                if let document = reading.pdf, pdfSlots.contains(slot) {
                    StudioStudyPDFReader(
                        document: document, pageNumber: reading.pageNumber,
                        navigationID: reading.navigationID,
                        accessibilityTitle: localized("study.reading.pdf"))
                } else {
                    StudioStudyTextReader(
                        reading: reading, accessibilityTitle: localized("study.reading.text"),
                        initialSelection: study.nativeSelection(slot)
                    ) { range in
                        study.setNativeSelection(
                            range, sourceID: reading.sourceRevisionID, slot: slot)
                        activeReaderSlot = slot
                    }
                }
            } else {
                ContentUnavailableView(
                    "study.source.choose", systemImage: "doc.text",
                    description: Text("study.source.choose-help"))
            }
        }
    }

    private func sourcePicker(_ slot: StudioStudyReaderSlot) -> some View {
        Picker(
            "study.source",
            selection: Binding(
                get: { study.reading(slot)?.sourceRevisionID ?? "" },
                set: { id in readSource(id, slot: slot) })
        ) {
            Text("study.source.choose").tag("")
            ForEach(Array((home.snapshot?.sources ?? []).enumerated()), id: \.element.id) {
                index, source in
                Group {
                    if let title = study.sourceTitles[source.sourceRevisionID], !title.isEmpty {
                        Text(title)
                    } else {
                        Text("workspace.source.ordinal \(index + 1)")
                    }
                }.tag(source.sourceRevisionID)
            }
        }
        .disabled(home.isBusy)
    }

    @ViewBuilder private func readingActions(_ slot: StudioStudyReaderSlot) -> some View {
        if let reading = study.reading(slot) {
            if reading.pdf != nil, pdfSlots.contains(slot) {
                Button("study.reading.show-text", systemImage: "text.badge.plus") {
                    pdfSlots.remove(slot)
                }
                .help("study.pdf.collection-help")
                .disabled(home.isBusy)
            } else {
                HStack {
                    Button("study.collect", systemImage: "text.badge.plus") {
                        previewSelection(slot)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("study.collect")
                    .disabled(home.isBusy || !study.hasNativeSelection(slot))
                    Button("study.selection.accessible", systemImage: "text.cursor") {
                        accessibleSelectionSlot = slot
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("study.selection.accessible")
                    .help("study.selection.accessible")
                    .disabled(home.isBusy)
                    .popover(
                        isPresented: Binding(
                            get: { accessibleSelectionSlot == slot },
                            set: { if !$0 { accessibleSelectionSlot = nil } })
                    ) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                StudioStudyAccessibleSelection(
                                    reading: reading, disabled: home.isBusy
                                ) { selection in
                                    Task {
                                        await home.runAdvancedAnalysis { session in
                                            try await study.previewPassage(
                                                session: session, slot: slot, selection: selection)
                                        }
                                        if home.lastFailure == nil {
                                            accessibleSelectionSlot = nil
                                        }
                                    }
                                }
                                .id(reading.navigationID)
                                if let message = home.failureMessage {
                                    Text(message).foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                        }
                        .frame(idealWidth: 360, idealHeight: 300, maxHeight: 420)
                    }
                }
            }
        }
    }

    private var notebook: some View {
        VStack(spacing: 0) {
            HStack {
                Text("study.notebook").font(.headline)
                Spacer()
                Menu("study.notebook.actions", systemImage: "ellipsis.circle") {
                    Button("study.organize", systemImage: "folder") { showsOrganization = true }
                    Button("study.undo", systemImage: "arrow.uturn.backward") {
                        commit { study.undo() }
                    }.disabled(!study.canUndo)
                    Button("study.redo", systemImage: "arrow.uturn.forward") {
                        commit { study.redo() }
                    }.disabled(!study.canRedo)
                    Divider()
                    Button("study.export.markdown") { export(.markdown) }
                    Button("study.export.json") { export(.json) }
                    Button("study.restore.choose") { showsRestoreImporter = true }
                }
                .disabled(home.isBusy)
            }
            .padding()
            List {
                if let draft = study.recoveryDraft {
                    Section("study.recovery.title") {
                        Text("study.recovery.help").font(.caption).foregroundStyle(.secondary)
                        ForEach(draft.notes) { note in
                            DisclosureGroup(note.title) { Text(note.text).textSelection(.enabled) }
                        }
                        Button("study.recovery.restore") { study.restoreRecoveryDraft() }
                    }
                }
                Section("study.passages") {
                    if study.orderedExcerpts.isEmpty {
                        Text("study.passages.empty").foregroundStyle(.secondary)
                    }
                    ForEach(study.orderedExcerpts) { excerpt in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(excerpt.title).font(.headline)
                            Text(excerpt.anchor.quote).lineLimit(5).textSelection(.enabled)
                            groupLabel(excerpt.groupID)
                            HStack {
                                Button("study.source.return", systemImage: "arrow.up.left") {
                                    openExcerpt(excerpt.id, slot: .first)
                                }
                                Spacer()
                                objectMenu(id: excerpt.id) {
                                    Button("study.edit") { editor = .excerpt(excerpt.id) }
                                    Button("study.compare.second") {
                                        openExcerpt(excerpt.id, slot: .second)
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("study.conclusions") {
                    if study.orderedNotes.isEmpty {
                        Text("study.conclusions.empty").foregroundStyle(.secondary)
                    }
                    ForEach(study.orderedNotes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                editor = .note(note.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title).font(.headline)
                                    Text(note.text).lineLimit(6)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            groupLabel(note.groupID)
                            ForEach(note.excerptIDs, id: \.self) { id in
                                if let excerpt = study.state.excerpts.first(where: { $0.id == id })
                                {
                                    Button {
                                        openExcerpt(id, slot: .first)
                                    } label: {
                                        Label(excerpt.title, systemImage: "text.quote").lineLimit(1)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            objectMenu(id: note.id) {
                                Button("study.edit") { editor = .note(note.id) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Button("study.conclusion.new", systemImage: "square.and.pencil") {
                        editor = .newConclusion()
                    }
                }
            }
            .listStyle(.inset)
            .disabled(home.isBusy)
        }
    }

    private func objectMenu<Content: View>(id: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        Menu("study.object.actions", systemImage: "ellipsis") {
            content()
            Button("study.organize", systemImage: "folder") { showsOrganization = true }
            Button("action.remove", systemImage: "trash", role: .destructive) {
                commit { study.removeObject(id: id) }
            }
        }
    }

    @ViewBuilder private func groupLabel(_ id: String?) -> some View {
        if let id, let group = study.state.groups.first(where: { $0.id == id }) {
            Label(group.title, systemImage: "folder").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var status: some View {
        HStack {
            if home.isBusy {
                ProgressView().controlSize(.small)
                Text("study.status.saving")
            } else if !study.hasLoaded {
                Text("study.status.unavailable")
                Button("study.reload") {
                    reloadNotebook()
                }
            } else {
                Text(
                    LocalizedStringKey(
                        study.hasChanges ? "study.status.unsaved" : "study.status.saved"))
                if study.hasChanges {
                    Button("study.save-retry") { commit {} }
                    Button("study.discard-draft", role: .destructive) { study.discardDraft() }
                    Button("study.reload") {
                        reloadNotebook()
                    }
                }
            }
            Spacer()
            Text("study.conclusions.personal").foregroundStyle(.secondary)
        }
        .font(.caption).padding(.horizontal).padding(.vertical, 8)
    }

    private var collectionPreview: some View {
        NavigationStack {
            Form {
                Section("study.collect.preview") {
                    Text(study.pendingPassage?.text ?? "").textSelection(.enabled)
                    TextField("study.object.title", text: $study.pendingTitle)
                }
                DisclosureGroup("study.organize") {
                    groupPicker($study.pendingGroupID)
                }
                if let message = home.failureMessage {
                    Text(message).foregroundStyle(.secondary)
                    Button("study.reload") { reloadNotebook() }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("study.collect")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("study.cancel", role: .cancel) { study.clearPendingPassage() }
                        .disabled(home.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("study.collect") {
                        Task {
                            await home.runAdvancedAnalysis { session in
                                try await study.collect(session: session)
                                try await home.refreshAfterResearchChange()
                            }
                        }
                    }
                    .disabled(
                        home.isBusy
                            || study.pendingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                    )
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 560, minHeight: 300)
        .interactiveDismissDisabled(true)
    }

    private var restorePreview: some View {
        NavigationStack {
            Form {
                Text("study.restore.help")
                LabeledContent("study.passages") {
                    Text(study.proposedRestore?.excerpts.count ?? 0, format: .number)
                }
                LabeledContent("study.conclusions") {
                    Text(study.proposedRestore?.notes.count ?? 0, format: .number)
                }
                ForEach(study.proposedRestore?.notes ?? []) { note in
                    VStack(alignment: .leading) {
                        Text(note.title).font(.headline)
                        Text(note.text).lineLimit(3)
                    }
                }
                if let message = home.failureMessage {
                    Text(message).foregroundStyle(.secondary)
                    Button("study.reload") { reloadNotebook() }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("study.restore.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("study.cancel", role: .cancel) { study.proposedRestore = nil }.disabled(
                        home.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("study.restore.confirm") {
                        Task {
                            await home.runAdvancedAnalysis { session in
                                try await study.restoreProposedNotebook(session: session)
                                try await home.refreshAfterResearchChange()
                            }
                        }
                    }.disabled(home.isBusy)
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 560, minHeight: 320)
        .interactiveDismissDisabled(home.isBusy)
    }

    private func groupPicker(_ selection: Binding<String>) -> some View {
        Picker("study.group", selection: selection) {
            Text("study.group.none").tag("")
            ForEach(study.state.groups) { group in Text(group.title).tag(group.id) }
        }
    }

    private func pdfBinding(_ slot: StudioStudyReaderSlot) -> Binding<Bool> {
        Binding(
            get: { pdfSlots.contains(slot) },
            set: { if $0 { pdfSlots.insert(slot) } else { pdfSlots.remove(slot) } })
    }

    private func readSource(_ id: String, slot: StudioStudyReaderSlot) {
        guard !id.isEmpty else { return }
        accessibleSelectionSlot = nil
        Task {
            await home.runAdvancedAnalysis { session in
                try await study.readSource(session: session, sourceID: id, slot: slot)
                study.setComparison([])
                try await study.save(session: session)
            }
        }
    }

    private func initializeNotebookIfNeeded() async {
        guard home.snapshot != nil, !home.isBusy, !study.hasLoaded else { return }
        await home.runAdvancedAnalysis { session in
            try await study.load(session: session)
            if let first = study.state.comparisonExcerptIDs.first {
                try await study.openExcerpt(session: session, excerptID: first, slot: .first)
                if let second = study.state.comparisonExcerptIDs.dropFirst().first {
                    try await study.openExcerpt(session: session, excerptID: second, slot: .second)
                }
            } else if let source = home.snapshot?.sources.first {
                try await study.readSource(
                    session: session, sourceID: source.sourceRevisionID, slot: .first)
            }
        }
    }

    private func openFirstAvailableSource() {
        guard !home.isBusy, home.lastFailure == nil, study.hasLoaded, study.firstReading == nil,
            let source = home.snapshot?.sources.first
        else { return }
        readSource(source.sourceRevisionID, slot: .first)
    }

    private func toggleComparison() {
        if study.showsComparison {
            study.showsComparison = false
            commit { study.setComparison([]) }
            return
        }
        Task {
            await home.runAdvancedAnalysis { session in
                if study.secondReading == nil,
                    let source = home.snapshot?.sources.first(where: {
                        $0.sourceRevisionID != study.firstReading?.sourceRevisionID
                    }) ?? home.snapshot?.sources.first
                {
                    try await study.readSource(
                        session: session, sourceID: source.sourceRevisionID, slot: .second)
                }
                study.showsComparison = true
            }
        }
    }

    private func openExcerpt(_ id: String, slot: StudioStudyReaderSlot) {
        Task {
            await home.runAdvancedAnalysis { session in
                try await study.openExcerpt(session: session, excerptID: id, slot: slot)
                pdfSlots.remove(slot)
                if study.showsComparison,
                    let first = study.excerptID(in: .first),
                    let second = study.excerptID(in: .second), first != second
                {
                    study.setComparison([first, second])
                    try await study.save(session: session)
                    try await home.refreshAfterResearchChange()
                }
            }
        }
    }

    private func previewSelection(_ slot: StudioStudyReaderSlot) {
        Task {
            await home.runAdvancedAnalysis { session in
                try await study.previewNativeSelection(session: session, slot: slot)
            }
        }
    }

    private func commit(_ mutation: @escaping @MainActor () -> Void) {
        Task {
            await home.runAdvancedAnalysis { session in
                mutation()
                try await study.save(session: session)
                try await home.refreshAfterResearchChange()
            }
        }
    }

    private func reloadNotebook() {
        Task {
            await home.runAdvancedAnalysis { _ in
                try await home.reloadStudyFromDisk()
                study.showsNotebook = true
            }
        }
    }

    private func export(_ format: GlifiStudioStudyExportFormat) {
        Task {
            await home.runAdvancedAnalysis { session in
                let bytes = try await study.export(session: session, format: format)
                exportType = format == .json ? .json : .markdown
                exportData = bytes
                try await home.refreshAfterResearchChange()
            }
        }
    }

    private func localized(_ key: String) -> String {
        String(localized: StudioLocalization.value(key), locale: locale)
    }
}

extension StudioStudyView where WorkspaceContext == EmptyView {
    init(
        home: StudioHomeModel, onImportSources: @escaping () -> Void,
        onOpenProject: @escaping () -> Void
    ) {
        self.init(
            home: home, onImportSources: onImportSources, onOpenProject: onOpenProject,
            workspaceContext: { EmptyView() })
    }
}

private struct StudioStudyAccessibleSelection: View {
    let reading: StudioStudyReading
    let disabled: Bool
    let onPreview: (GlifiStudioPassageSelection) -> Void
    @State private var usesCharacters = false
    @State private var first = 0
    @State private var last = 0
    @State private var start = 0
    @State private var end = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("study.selection.accessible").font(.headline).accessibilityAddTraits(.isHeader)
            Toggle("study.selection.characters", isOn: $usesCharacters)
            if usesCharacters {
                Text("study.selection.characters-help").font(.caption).foregroundStyle(
                    .secondary)
                HStack {
                    TextField("study.selection.start", value: $start, format: .number)
                    TextField("study.selection.end", value: $end, format: .number)
                }
                LabeledContent("study.selection.character-count") {
                    Text(reading.characterCount, format: .number)
                }
            } else {
                Picker("study.selection.first-sentence", selection: $first) {
                    ForEach(Array(reading.segments.enumerated()), id: \.offset) {
                        index, segment in
                        Text(segment.text).lineLimit(1).tag(index)
                    }
                }
                Picker("study.selection.last-sentence", selection: $last) {
                    ForEach(Array(reading.segments.enumerated()), id: \.offset) {
                        index, segment in
                        Text(segment.text).lineLimit(1).tag(index)
                    }
                }
            }
            Button("study.collect.preview") {
                onPreview(
                    usesCharacters
                        ? .characters(start: start, end: end)
                        : .sentences(first: first, last: last))
            }
            .disabled(disabled || (!usesCharacters && reading.segments.isEmpty))
        }
        .onChange(of: reading.navigationID) { _, _ in
            first = 0
            last = 0
            start = 0
            end = min(1, reading.characterCount)
        }
    }
}

private struct StudioStudyObjectEditor: View {
    @Bindable var study: StudioStudyModel
    let editing: StudioStudyEditor
    let isBusy: Bool
    let failureMessage: LocalizedStringKey?
    let onReload: () -> Void
    let onSave: (String, String, String?, [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = StudioStudyEditorDraft()
    @State private var initial = ""

    private var isNote: Bool { if case .note = editing { true } else { false } }
    private var fingerprint: String {
        "\(draft.title)\u{0}\(draft.text)\u{0}\(draft.groupID)\u{0}\(draft.support.sorted())"
    }

    private var reconciledDraft: StudioStudyEditorDraft {
        var current = draft
        current.reconcile(with: study.state)
        return current
    }

    private var excerptIsUnavailable: Bool {
        guard case let .excerpt(id) = editing else { return false }
        return !study.state.excerpts.contains { $0.id == id }
    }

    var body: some View {
        let reconciled = reconciledDraft
        NavigationStack {
            Form {
                if reconciled != draft {
                    Label("study.editor.references-updated", systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if excerptIsUnavailable {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("study.editor.excerpt-unavailable", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                        Button("study.reload") { onReload() }
                    }
                }
                Section {
                    TextField("study.object.title", text: $draft.title)
                        .accessibilityIdentifier("study.object.title")
                    if isNote {
                        Text("study.conclusion.prompt").foregroundStyle(.secondary)
                        TextEditor(text: $draft.text).frame(minHeight: 180)
                            .accessibilityLabel("study.conclusion.text")
                        Text("study.conclusions.personal").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }
                if isNote {
                    Section("study.conclusion.support") {
                        ForEach(study.orderedExcerpts) { excerpt in
                            Toggle(
                                isOn: Binding(
                                    get: { reconciled.support.contains(excerpt.id) },
                                    set: {
                                        if $0 {
                                            draft.support.insert(excerpt.id)
                                        } else {
                                            draft.support.remove(excerpt.id)
                                        }
                                    })
                            ) {
                                VStack(alignment: .leading) {
                                    Text(excerpt.title)
                                    Text(excerpt.anchor.quote).font(.caption).lineLimit(3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                DisclosureGroup("study.organize") {
                    Picker(
                        "study.group",
                        selection: Binding(get: { reconciled.groupID }, set: { draft.groupID = $0 })
                    ) {
                        Text("study.group.none").tag("")
                        ForEach(study.state.groups) { group in Text(group.title).tag(group.id) }
                    }
                    if case let .excerpt(id) = editing,
                        let anchor = study.state.excerpts.first(where: { $0.id == id })?.anchor
                    {
                        LabeledContent("study.provenance.revision", value: anchor.sourceRevisionID)
                        LabeledContent("study.provenance.digest", value: anchor.sourceContentDigest)
                        LabeledContent(
                            "study.provenance.representation",
                            value: anchor.representationIdentifier)
                    }
                }
                if let failureMessage {
                    Text(failureMessage).foregroundStyle(.secondary)
                    if !excerptIsUnavailable { Button("study.reload") { onReload() } }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(
                LocalizedStringKey(isNote ? "study.conclusion.edit" : "study.passage.edit")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("study.cancel", role: .cancel) { dismiss() }.keyboardShortcut(
                        .cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("study.save") {
                        let saving = reconciledDraft
                        onSave(
                            saving.title, saving.text,
                            saving.groupID.isEmpty ? nil : saving.groupID, saving.support.sorted())
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || (isNote
                                && draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty)
                    )
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 620, minHeight: 420)
        .disabled(isBusy)
        .interactiveDismissDisabled(isBusy || fingerprint != initial)
        .task {
            switch editing {
            case let .excerpt(id):
                if let value = study.state.excerpts.first(where: { $0.id == id }) {
                    draft.title = value.title
                    draft.groupID = value.groupID ?? ""
                }
            case let .note(id):
                if let value = study.state.notes.first(where: { $0.id == id }) {
                    draft.title = value.title
                    draft.text = value.text
                    draft.groupID = value.groupID ?? ""
                    draft.support = Set(value.excerptIDs)
                } else if let selected = study.selectedExcerptID {
                    draft.support = [selected]
                }
            }
            initial = fingerprint
        }
    }
}

private struct StudioStudyOrganizationEditor: View {
    @Bindable var home: StudioHomeModel
    @Bindable var study: StudioStudyModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var newGroup = ""
    @State private var titles: [String: String] = [:]

    private var hasTextDraft: Bool {
        !newGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || titles.contains { id, title in
                study.state.groups.first { $0.id == id }?.title != title
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("study.order") {
                    ForEach(study.state.order, id: \.self) { id in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(objectTitle(id))
                                Text(
                                    study.state.excerpts.contains { $0.id == id }
                                        ? "study.passage.kind" : "study.conclusion.kind"
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("study.move-up", systemImage: "arrow.up") {
                                commit { study.moveObject(id: id, by: -1) }
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel(Text(moveLabel("study.move-up", id: id)))
                            .disabled(!study.canMoveObject(id: id, by: -1))
                            Button("study.move-down", systemImage: "arrow.down") {
                                commit { study.moveObject(id: id, by: 1) }
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel(Text(moveLabel("study.move-down", id: id)))
                            .disabled(!study.canMoveObject(id: id, by: 1))
                        }
                    }
                }
                Section("study.groups") {
                    ForEach(study.state.groups) { group in
                        HStack {
                            TextField(
                                "study.group.title",
                                text: Binding(
                                    get: { titles[group.id] ?? group.title },
                                    set: { titles[group.id] = $0 }))
                            Button("study.save") {
                                commit {
                                    study.renameGroup(
                                        id: group.id, title: titles[group.id] ?? group.title)
                                }
                            }
                            Button("action.remove", systemImage: "minus.circle", role: .destructive)
                            {
                                commit { study.removeGroup(id: group.id) }
                            }
                        }
                    }
                    TextField("study.group.title", text: $newGroup)
                    Button("study.group.add", systemImage: "plus") {
                        let title = newGroup
                        commit { study.addGroup(title: title) }
                        newGroup = ""
                    }
                    .disabled(newGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("sidebar.investigation") {
                    Picker(
                        "study.investigation",
                        selection: Binding(
                            get: { study.state.investigationID ?? "" },
                            set: { id in commit { study.setInvestigation(id.isEmpty ? nil : id) } })
                    ) {
                        Text("study.investigation.none").tag("")
                        ForEach(home.investigationHeads, id: \.id) { head in
                            Text(head.question).tag(head.id)
                        }
                    }
                    Text("study.investigation.help").font(.caption).foregroundStyle(.secondary)
                }
                if let message = home.failureMessage {
                    Text(message).foregroundStyle(.secondary)
                    Button("study.reload") {
                        Task {
                            await home.runAdvancedAnalysis { _ in
                                try await home.reloadStudyFromDisk()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(home.isBusy)
            .navigationTitle("study.organize")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey(hasTextDraft ? "study.cancel" : "workspace.close")) {
                        dismiss()
                    }
                    .disabled(home.isBusy)
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 620, minHeight: 360)
        .interactiveDismissDisabled(home.isBusy || hasTextDraft)
    }

    private func commit(_ mutation: @escaping @MainActor () -> Void) {
        Task {
            await home.runAdvancedAnalysis { session in
                mutation()
                try await study.save(session: session)
                try await home.refreshAfterResearchChange()
            }
        }
    }

    private func moveLabel(_ key: String, id: String) -> String {
        String(localized: StudioLocalization.value(key), locale: locale) + " " + objectTitle(id)
    }

    private func objectTitle(_ id: String) -> String {
        study.state.excerpts.first { $0.id == id }?.title
            ?? study.state.notes.first { $0.id == id }?.title ?? ""
    }
}

private struct StudioStudyExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText, .markdown] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
