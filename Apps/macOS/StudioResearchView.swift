// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Native project data, reusable preparation and saved analytical work.
struct StudioResearchView: View {
    @Bindable var home: StudioHomeModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var research = StudioResearchModel()
    @State private var tab = 0
    @State private var showsImporter = false
    @State private var exportData: Data?
    @State private var exportFailed = false
    let onRestore: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if home.snapshot != nil {
                    TabView(selection: $tab) {
                        Tab(value: 0) {
                            importer
                        } label: {
                            Label("research.import", systemImage: "tablecells")
                        }
                        Tab(value: 1) {
                            metadata
                        } label: {
                            Label("research.data", systemImage: "tag")
                        }
                        Tab(value: 2) {
                            preparation
                        } label: {
                            Label("research.preparation", systemImage: "textformat.abc")
                        }
                        Tab(value: 3) {
                            savedAnalyses
                        } label: {
                            Label("research.saved", systemImage: "externaldrive")
                        }
                    }
                    .tabViewStyle(.grouped)
                    .padding()
                } else {
                    ContentUnavailableView(
                        "sources.needs-project.title", systemImage: "folder.badge.questionmark",
                        description: Text("sources.needs-project.description"))
                }
                if home.isBusy {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("research.progress")
                        Spacer()
                        Button("action.cancel-execution") { home.cancelAnalysis() }
                    }
                    .padding()
                }
                if let message = home.failureMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding()
                        .accessibilityAddTraits(.updatesFrequently)
                    if let row = home.lastFailure?.arguments["row"] {
                        LabeledContent("research.import.row", value: row)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
            }
            .navigationTitle("research.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("workspace.close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .disabled(home.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if tab == 1 || tab == 2 {
                        Button("research.save", systemImage: "externaldrive.badge.checkmark") {
                            save()
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(home.isBusy || !research.hasLoaded)
                    }
                }
            }
        }
        .frame(minWidth: 620, idealWidth: 940, minHeight: 480, idealHeight: 720)
        .task(id: home.snapshot?.projectID) {
            research.reset()
            guard home.snapshot != nil else { return }
            await home.runAdvancedAnalysis { session in
                try await research.load(session: session)
                research.selectedSourceID = home.snapshot?.sources.first?.sourceRevisionID ?? ""
            }
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: importContentTypes
        ) { result in
            switch result {
            case let .success(url):
                Task {
                    await home.runCoreAnalysis {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let bytes = try await StudioResearchModel.readInput(at: url)
                        research.setInput(data: bytes, filename: url.lastPathComponent)
                        try await research.preview()
                    }
                }
            case .failure:
                break
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportData != nil }, set: { if !$0 { exportData = nil } }),
            document: exportData.map(StudioResearchJSONDocument.init), contentType: .json,
            defaultFilename: "GlifiStudio-analysis"
        ) { result in
            if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
                exportFailed = true
            }
            exportData = nil
        }
        .alert("visual.export.failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
        .onChange(of: research.optionsSignature) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.textColumns) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.identifierColumn) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.variableColumns) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.variableNames) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.variableTypes) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.missingValues) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.duplicatePolicy) { _, _ in research.mappedDataset = nil }
        .onChange(of: research.invalidRowPolicy) { _, _ in research.mappedDataset = nil }
    }

    private var importer: some View {
        Form {
            Section("research.import.file") {
                Button("research.import.choose", systemImage: "doc.badge.plus") {
                    showsImporter = true
                }
                if !research.filename.isEmpty { Text(research.filename).textSelection(.enabled) }
                Text("research.import.formats").font(.caption).foregroundStyle(.secondary)
                if research.inputData != nil {
                    if research.format == .csv {
                        Picker("research.import.encoding", selection: $research.encoding) {
                            Text("UTF-8").tag(GlifiStudioTabularEncoding.utf8)
                            Text("UTF-16 LE").tag(GlifiStudioTabularEncoding.utf16LittleEndian)
                            Text("UTF-16 BE").tag(GlifiStudioTabularEncoding.utf16BigEndian)
                            Text("Windows-1252").tag(GlifiStudioTabularEncoding.windows1252)
                        }
                        Picker("research.import.delimiter", selection: $research.delimiter) {
                            Text("research.import.comma").tag(GlifiStudioTabularDelimiter.comma)
                            Text("research.import.semicolon").tag(
                                GlifiStudioTabularDelimiter.semicolon)
                            Text("research.import.tab").tag(GlifiStudioTabularDelimiter.tab)
                        }
                    }
                    Toggle("research.import.header", isOn: $research.hasHeaderRow)
                    if let table = research.table, !table.sheetNames.isEmpty {
                        Picker("research.import.sheet", selection: $research.sheetName) {
                            Text("research.import.first-sheet").tag("")
                            ForEach(table.sheetNames, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Button("research.import.preview", systemImage: "eye") {
                        Task { await home.runCoreAnalysis { try await research.preview() } }
                    }
                }
            }
            if let table = research.table {
                Section("research.import.preview") {
                    Text("research.import.preview-help").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("research.import.rows") {
                        Text(table.rows.count, format: .number)
                    }
                    ScrollView([.horizontal, .vertical]) {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("research.import.row").fontWeight(.semibold)
                                ForEach(Array(table.columns.enumerated()), id: \.offset) {
                                    _, title in
                                    Text(title).fontWeight(.semibold)
                                }
                            }
                            ForEach(Array(table.rows.prefix(20).enumerated()), id: \.offset) {
                                _, row in
                                GridRow {
                                    Text(row.number, format: .number).monospacedDigit()
                                    ForEach(Array(row.cells.enumerated()), id: \.offset) {
                                        _, cell in
                                        Text(cell ?? "—").lineLimit(3).frame(
                                            maxWidth: 260, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                    .frame(maxHeight: 240)
                    if !research.isPreviewCurrent {
                        Label("research.import.refresh-preview", systemImage: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("research.import.mapping") {
                    Text("research.import.mapping-help").font(.caption).foregroundStyle(.secondary)
                    Picker("research.import.identifier", selection: $research.identifierColumn) {
                        Text("research.import.generated-id").tag(0)
                        ForEach(Array(table.columns.enumerated()), id: \.offset) { index, title in
                            Text(title).tag(index + 1)
                        }
                    }
                    ForEach(Array(table.columns.enumerated()), id: \.offset) { index, title in
                        mappingColumn(index + 1, title: title)
                    }
                    TextField(
                        "research.import.missing", text: $research.missingValues, axis: .vertical)
                    Text("research.import.missing-help").font(.caption).foregroundStyle(.secondary)
                    Picker("research.import.duplicates", selection: $research.duplicatePolicy) {
                        Text("research.import.reject").tag(GlifiStudioTabularDuplicatePolicy.reject)
                        Text("research.import.skip").tag(GlifiStudioTabularDuplicatePolicy.skip)
                        Text("research.import.append-row").tag(
                            GlifiStudioTabularDuplicatePolicy.appendRowNumber)
                    }
                    Picker("research.import.invalid-rows", selection: $research.invalidRowPolicy) {
                        Text("research.import.reject").tag(
                            GlifiStudioTabularInvalidRowPolicy.reject)
                        Text("research.import.skip").tag(GlifiStudioTabularInvalidRowPolicy.skip)
                    }
                    Button("research.import.validate", systemImage: "checkmark.circle") {
                        Task { await home.runCoreAnalysis { try await research.map() } }
                    }
                    .disabled(!research.isPreviewCurrent || research.textColumns.isEmpty)
                }
            }
            if let mapped = research.mappedDataset {
                Section("research.import.ready") {
                    LabeledContent("research.import.documents") {
                        Text(mapped.records.count, format: .number)
                    }
                    LabeledContent("research.import.issues") {
                        Text(mapped.issues.count, format: .number)
                    }
                    ForEach(Array(mapped.issues.prefix(20).enumerated()), id: \.offset) {
                        _, issue in
                        HStack {
                            Text(issue.rowNumber, format: .number).monospacedDigit()
                            Text(
                                issue.code == "duplicate-identifier"
                                    ? "research.import.issue-duplicate"
                                    : "research.import.issue-invalid")
                        }
                    }
                    Button("research.import.commit", systemImage: "square.and.arrow.down") {
                        importMapped(mapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(mapped.records.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(home.isBusy)
    }

    private var importContentTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .tabSeparatedText]
        if let workbook = UTType(filenameExtension: "xlsx") { types.append(workbook) }
        return types
    }

    private func mappingColumn(_ column: Int, title: String) -> some View {
        DisclosureGroup(title) {
            Toggle("research.import.as-text", isOn: membership(column, in: $research.textColumns))
            Toggle(
                "research.import.as-variable",
                isOn: membership(column, in: $research.variableColumns))
            if research.variableColumns.contains(column) {
                TextField(
                    "research.field.name",
                    text: Binding(
                        get: { research.variableNames[column] ?? title },
                        set: { research.variableNames[column] = $0 }))
                Picker(
                    "research.field.type",
                    selection: Binding(
                        get: { research.variableTypes[column] ?? .text },
                        set: { research.variableTypes[column] = $0 })
                ) {
                    Text("research.type.text").tag(GlifiStudioTabularValueType.text)
                    Text("research.type.integer").tag(GlifiStudioTabularValueType.integer)
                    Text("research.type.number").tag(GlifiStudioTabularValueType.decimal)
                    Text("research.type.boolean").tag(GlifiStudioTabularValueType.boolean)
                    Text("research.type.date").tag(GlifiStudioTabularValueType.date)
                }
            }
        }
    }

    private var metadata: some View {
        Form {
            Section("research.fields") {
                Text("research.fields.help").font(.caption).foregroundStyle(.secondary)
                ForEach($research.state.fields, id: \.id) { $field in
                    VStack(alignment: .leading) {
                        HStack {
                            TextField("research.field.name", text: $field.label)
                            Button("action.remove", systemImage: "minus.circle") {
                                research.removeField(field.id)
                            }
                        }
                        Picker("research.field.type", selection: $field.type) {
                            Text("research.type.text").tag(GlifiStudioResearchFieldType.text)
                            Text("research.type.number").tag(GlifiStudioResearchFieldType.number)
                            Text("research.type.boolean").tag(GlifiStudioResearchFieldType.boolean)
                            Text("research.type.date").tag(GlifiStudioResearchFieldType.date)
                        }
                    }
                }
                Button("research.field.add", systemImage: "plus") { research.addField() }
            }
            if let snapshot = home.snapshot {
                Section("research.values") {
                    Picker("research.source", selection: $research.selectedSourceID) {
                        Text("kh.language.choose-source").tag("")
                        ForEach(
                            Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID
                        ) {
                            index, source in
                            Text("workspace.source.ordinal \(index + 1)").tag(
                                source.sourceRevisionID)
                        }
                    }
                    if !research.selectedSourceID.isEmpty {
                        ForEach(research.state.fields, id: \.id) { field in
                            TextField(field.label, text: valueBinding(field.id))
                                .accessibilityLabel(field.label)
                            if field.type == .boolean || field.type == .date
                                || field.type == .number
                            {
                                Text(LocalizedStringKey(valueHelp(field.type)))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let record = research.state.records.first(where: {
                            $0.sourceRevisionID == research.selectedSourceID
                        }) {
                            if let externalID = record.externalID {
                                LabeledContent("research.external-id") {
                                    Text(externalID).textSelection(.enabled)
                                }
                            }
                            if let artifact = record.derivationArtifactID {
                                LabeledContent("research.derivation") {
                                    Text(artifact).textSelection(.enabled)
                                }
                            }
                            if let producers = record.derivationArtifactIDs, !producers.isEmpty {
                                DisclosureGroup("research.derivation") {
                                    ForEach(producers.keys.sorted(), id: \.self) { fieldID in
                                        if let artifact = producers[fieldID] {
                                            LabeledContent(
                                                research.state.fields.first(where: {
                                                    $0.id == fieldID
                                                })?.label ?? fieldID
                                            ) { Text(artifact).textSelection(.enabled) }
                                        }
                                    }
                                }
                            }
                            if !record.origins.isEmpty {
                                DisclosureGroup("research.provenance") {
                                    ForEach(record.origins.keys.sorted(), id: \.self) { key in
                                        if let origin = record.origins[key] {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(originName(key))
                                                LabeledContent("research.import.row") {
                                                    Text(origin.row, format: .number)
                                                }
                                                LabeledContent("research.import.column") {
                                                    Text(origin.column, format: .number)
                                                }
                                                if let sheet = origin.sheet {
                                                    LabeledContent("research.import.sheet") {
                                                        Text(sheet)
                                                    }
                                                }
                                                Text(origin.inputDigest).font(.caption.monospaced())
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text("research.values.missing").font(.caption).foregroundStyle(.secondary)
                }
                Section("research.filter") {
                    Text("research.filter.help").font(.caption).foregroundStyle(.secondary)
                    Picker("research.subsets", selection: $research.selectedSubsetID) {
                        Text("research.filter.all-sources").tag("")
                        ForEach(research.state.subsets, id: \.id) { Text($0.label).tag($0.id) }
                    }
                    Picker("research.filter.variable", selection: $research.filterFieldID) {
                        Text("research.filter.no-variable").tag("")
                        ForEach(research.state.fields, id: \.id) { Text($0.label).tag($0.id) }
                    }
                    if !research.filterFieldID.isEmpty {
                        TextField("research.filter.equals", text: $research.filterValue)
                    }
                    TextField("research.filter.query", text: $research.filterQuery)
                    Button("research.filter.apply", systemImage: "line.3.horizontal.decrease") {
                        Task {
                            await home.runAdvancedAnalysis { session in
                                try await research.save(session: session)
                                let ids = try await research.filteredSources(session: session)
                                home.textAnalysisScope = .selectedSources
                                home.selectedTextAnalysisSourceRevisionIDs = Set(ids)
                                try await home.refreshAfterResearchChange()
                            }
                        }
                    }
                    LabeledContent("research.filter.selected") {
                        Text(research.selectedSourceIDs.count, format: .number)
                    }
                    if let field = research.state.fields.first(where: {
                        $0.id == research.filterFieldID
                    }) {
                        Button("research.variable.use-classes", systemImage: "tag") {
                            useVariableForClasses(field)
                        }
                        if field.type == .date {
                            Button("research.variable.use-time", systemImage: "calendar") {
                                useVariableForTime(field)
                            }
                        }
                    }
                }
                Section("research.subsets") {
                    TextField("research.subset.name", text: $research.subsetLabel)
                    DisclosureGroup("research.subset.sources") {
                        ForEach(
                            Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID
                        ) {
                            index, source in
                            Toggle(
                                isOn: sourceMembership(source.sourceRevisionID)
                            ) { Text("workspace.source.ordinal \(index + 1)") }
                        }
                    }
                    Button("research.subset.add", systemImage: "plus") { research.addSubset() }
                        .disabled(
                            research.selectedSourceIDs.isEmpty || research.subsetLabel.isEmpty)
                    ForEach(research.state.subsets, id: \.id) { subset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(subset.label)
                                Text(subset.sourceRevisionIDs.count, format: .number)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu("research.subset.actions") {
                                Button("research.subset.use") {
                                    home.textAnalysisScope = .selectedSources
                                    home.selectedTextAnalysisSourceRevisionIDs = Set(
                                        subset.sourceRevisionIDs)
                                    research.selectedSubsetID = subset.id
                                }

                                Button("research.subset.target") {
                                    home.selectedTargetRevisionIDs = Set(subset.sourceRevisionIDs)
                                    home.selectedReferenceRevisionIDs.subtract(
                                        subset.sourceRevisionIDs)
                                }
                                Button("research.subset.reference") {
                                    home.selectedReferenceRevisionIDs = Set(
                                        subset.sourceRevisionIDs)
                                    home.selectedTargetRevisionIDs.subtract(
                                        subset.sourceRevisionIDs)
                                }
                                Divider()
                                Button("action.remove", systemImage: "minus.circle") {
                                    research.state.subsets.removeAll { $0.id == subset.id }
                                }
                            }
                        }
                    }
                }
            }
            revision
        }
        .formStyle(.grouped)
        .disabled(home.isBusy || !research.hasLoaded)
    }

    private var preparation: some View {
        Form {
            Section("research.preparation") {
                Text("research.preparation.help").foregroundStyle(.secondary)
                LabeledContent("linguistic.language") { Text("linguistic.language.italian") }
                Picker("linguistic.base", selection: $research.state.preparation.base) {
                    Text("linguistic.base.normalized-surface").tag(
                        GlifiStudioLinguisticBase.normalizedSurface)
                    Text("linguistic.base.apple-lemma").tag(GlifiStudioLinguisticBase.appleLemma)
                    Text("linguistic.base.italian-snowball-3.1.0").tag(
                        GlifiStudioLinguisticBase.italianSnowballStem)
                }
                linesEditor("research.preparation.stopwords", text: $research.stopwords)
                linesEditor("research.preparation.include", text: $research.includedTerms)
                linesEditor("research.preparation.exclude", text: $research.excludedTerms)
                linesEditor("research.preparation.compounds", text: $research.compounds)
                linesEditor("research.preparation.pos", text: $research.includedPartsOfSpeech)
                Text("research.preparation.pos-help").font(.caption).foregroundStyle(.secondary)
                Text("research.preparation.recompute").font(.caption).foregroundStyle(.secondary)
            }
            revision
        }
        .formStyle(.grouped)
        .disabled(home.isBusy || !research.hasLoaded)
    }

    private var savedAnalyses: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("research.saved.help").foregroundStyle(.secondary)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading) {
                    TextField("research.saved.title", text: $research.savedTitle)
                    captureButton
                }
            } else {
                HStack {
                    TextField("research.saved.title", text: $research.savedTitle)
                    captureButton
                }
            }
            if research.savedAnalyses.isEmpty {
                ContentUnavailableView(
                    "research.saved.empty", systemImage: "externaldrive",
                    description: Text("research.saved.empty-help"))
            } else {
                List(selection: $research.selectedSavedID) {
                    ForEach(research.savedAnalyses, id: \.id) { entry in
                        Button {
                            Task {
                                await home.runCoreAnalysis { try await research.selectSaved(entry) }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title).font(.headline)
                                Text(entry.methodIdentifier).font(.caption).foregroundStyle(
                                    .secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .tag(entry.id)
                    }
                }
                .frame(minHeight: 140, maxHeight: 240)
                if let entry = research.savedAnalyses.first(where: {
                    $0.id == research.selectedSavedID
                }) {
                    if entry.sourceRevisionIDs.isEmpty {
                        Label("research.saved.explicit-input", systemImage: "keyboard")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        LabeledContent("research.saved.sources") {
                            Text(entry.sourceRevisionIDs.count, format: .number)
                        }
                    }
                    HStack {
                        if entry.presentationJSON != nil {
                            Button("research.saved.restore", systemImage: "arrow.uturn.backward") {
                                Task {
                                    await home.runAdvancedAnalysis { _ in
                                        try await home.restoreSavedResearchAnalysis(entry)
                                    }
                                    if home.lastFailure == nil {
                                        onRestore(research.savedClient)
                                        dismiss()
                                    }
                                }
                            }
                        }
                        Button("research.saved.export", systemImage: "square.and.arrow.up") {
                            Task {
                                await home.runAdvancedAnalysis { session in
                                    exportData = try await session.exportSavedAnalysis(
                                        artifactID: entry.artifactID)
                                }
                            }
                        }
                    }
                    DisclosureGroup("research.saved.derive") {
                        Text("research.saved.derive-help")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("research.field.identifier", text: $research.derivedFieldID)
                        TextField("research.field.name", text: $research.derivedFieldLabel)
                        if entry.methodIdentifier.hasPrefix("HAC") {
                            Stepper(
                                "research.saved.hac-count \(research.derivedClusterCount)",
                                value: $research.derivedClusterCount,
                                in: 1...max(1, entry.resultSourceRevisionIDs.count))
                        }
                        Button("research.saved.derive", systemImage: "tag.badge.plus") {
                            Task {
                                await home.runAdvancedAnalysis { session in
                                    _ = try await session.deriveResearchVariable(
                                        artifactID: entry.artifactID,
                                        fieldID: research.derivedFieldID,
                                        label: research.derivedFieldLabel,
                                        expectedRevision: research.state.revision,
                                        clusterCount: research.derivedClusterCount)
                                    try await research.load(session: session)
                                    try await home.refreshAfterResearchChange()
                                }
                            }
                        }
                        .disabled(
                            research.derivedFieldID.isEmpty || research.derivedFieldLabel.isEmpty)
                    }
                    DisclosureGroup("research.saved.report") {
                        Text("research.saved.report-help")
                            .font(.caption).foregroundStyle(.secondary)
                        if entry.sourceRevisionIDs.isEmpty {
                            Text("research.saved.report-sources-required")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        TextField(
                            "research.saved.question", text: $research.reportQuestion,
                            axis: .vertical)
                        Button("research.saved.create-report", systemImage: "doc.badge.plus") {
                            Task {
                                await home.runAdvancedAnalysis { _ in
                                    try await home.linkSavedResearchAnalysisToInvestigation(
                                        entry, question: research.reportQuestion)
                                }
                                if home.lastFailure == nil {
                                    onRestore("report")
                                    dismiss()
                                }
                            }
                        }
                        .disabled(
                            entry.sourceRevisionIDs.isEmpty
                                || research.reportQuestion.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty)
                    }
                    DisclosureGroup("research.saved.technical-details") {
                        LabeledContent("research.saved.artifact") {
                            Text(entry.artifactID).textSelection(.enabled)
                        }
                        if research.savedValuesAreTruncated {
                            Text("research.saved.table-limited").font(.caption).foregroundStyle(
                                .secondary)
                        }
                        Table(research.savedValues) {
                            TableColumn("research.saved.field", value: \.id)
                            TableColumn("research.saved.value", value: \.value)
                        }
                        .frame(height: 200)
                        .textSelection(.enabled)
                        Text("research.saved.preview-help").font(.caption).foregroundStyle(
                            .secondary)
                        ScrollView {
                            Text(research.savedPreview).font(.caption.monospaced())
                                .textSelection(.enabled).frame(
                                    maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                    }
                }
            }
        }
        .disabled(home.isBusy)
    }

    private var captureButton: some View {
        Button("research.saved.capture", systemImage: "externaldrive.badge.plus") {
            Task {
                await home.runAdvancedAnalysis { session in
                    try await home.saveCurrentResearchAnalysis(title: research.savedTitle)
                    try await research.load(session: session)
                    try await home.refreshAfterResearchChange()
                }
            }
        }
        .disabled(!home.canSaveCurrentResearchAnalysis || research.savedTitle.isEmpty)
    }

    private var revision: some View {
        Section {
            LabeledContent("research.revision") { Text(research.state.revision, format: .number) }
            Text("research.save.help").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func linesEditor(_ key: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(key, text: text, axis: .vertical).lineLimit(3...8)
    }

    private func originName(_ key: String) -> String {
        if key == "$id" { return String(localized: "research.external-id", locale: locale) }
        if key.hasPrefix("$text") {
            return String(localized: "research.source-text", locale: locale)
        }
        return research.state.fields.first(where: { $0.id == key })?.label ?? key
    }

    private func valueBinding(_ fieldID: String) -> Binding<String> {
        Binding(
            get: { research.values[research.selectedSourceID]?[fieldID] ?? "" },
            set: { research.values[research.selectedSourceID, default: [:]][fieldID] = $0 })
    }

    private func sourceMembership(_ id: String) -> Binding<Bool> {
        Binding(
            get: { research.selectedSourceIDs.contains(id) },
            set: { selected in
                if selected {
                    research.selectedSourceIDs.insert(id)
                } else {
                    research.selectedSourceIDs.remove(id)
                }
            })
    }

    private func membership(_ column: Int, in columns: Binding<Set<Int>>) -> Binding<Bool> {
        Binding(
            get: { columns.wrappedValue.contains(column) },
            set: { selected in
                if selected {
                    columns.wrappedValue.insert(column)
                } else {
                    columns.wrappedValue.remove(column)
                }
            })
    }

    private func valueHelp(_ type: GlifiStudioResearchFieldType) -> String {
        switch type {
        case .text: "research.type.text"
        case .number: "research.values.number-help"
        case .boolean: "research.values.boolean-help"
        case .date: "research.values.date-help"
        }
    }

    private func save() {
        Task {
            await home.runAdvancedAnalysis { session in
                try await research.save(session: session)
                try await home.refreshAfterResearchChange()
            }
        }
    }

    private func useVariableForClasses(_ field: GlifiStudioResearchField) {
        Task {
            await home.runAdvancedAnalysis { session in
                try await research.save(session: session)
                let labels = research.classLabels(fieldID: field.id)
                home.advancedAnalysis.labels = labels
                home.advancedAnalysis.tool = .classification
                home.khLanguage.draft.labels = labels
                try await home.refreshAfterResearchChange()
            }
            if home.lastFailure == nil {
                onRestore("advanced")
                dismiss()
            }
        }
    }

    private func useVariableForTime(_ field: GlifiStudioResearchField) {
        Task {
            await home.runAdvancedAnalysis { session in
                try await research.save(session: session)
                home.evaluation.tool = .temporal
                home.evaluation.instantBasis = false
                home.evaluation.temporalAnnotations = research.temporalAnnotations(
                    fieldID: field.id)
                try await home.refreshAfterResearchChange()
            }
            if home.lastFailure == nil {
                onRestore("evaluation")
                dismiss()
            }
        }
    }

    private func importMapped(_ dataset: GlifiStudioTabularMappedDataset) {
        Task {
            await home.runAdvancedAnalysis { session in
                guard let bytes = research.inputData, !dataset.records.isEmpty else { return }
                _ = try await session.importTabular(
                    data: bytes, options: research.importOptions,
                    mapping: research.importMapping())
                try await home.refreshAfterResearchChange()
                try await research.load(session: session)
                research.mappedDataset = nil
                research.table = nil
                research.inputData = nil
                tab = 1
            }
        }
    }
}

private struct StudioResearchJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(_ data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
