// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Explicit native annotation and coding, separate from the gold-reference evaluation tools.
struct StudioLinguisticView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var analysis: StudioLinguisticModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsResults = false
    @State private var selectedUnitID: UUID?
    @State private var sourceRevisionID: String?
    @State private var provenanceIndex = 0
    @State private var capturedUnitIndex = 0
    @State private var exportData: Data?
    @State private var exportFilename = "GlifiStudio-LinguisticResult"
    @State private var exportFailed = false
    @FocusState private var focusedUnitID: UUID?
    @FocusState private var focusedVariableID: UUID?

    init(model: StudioHomeModel) {
        self.model = model
        analysis = model.linguistics
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { geometry in
                if geometry.size.width >= 920 && !dynamicTypeSize.isAccessibilitySize {
                    HSplitView {
                        configuration.frame(minWidth: 310, idealWidth: 380, maxWidth: 480)
                        results.frame(minWidth: 380)
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("linguistic.pane", selection: $showsResults) {
                            Text("linguistic.settings").tag(false)
                            Text("linguistic.results").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        if showsResults { results } else { configuration }
                    }
                }
            }
        }
        .navigationTitle("linguistic.title")
        .onChange(of: analysis.tool) { _, _ in showsResults = false }
        .onChange(of: analysis.output?.id) { _, id in
            if id != nil { showsResults = true }
            provenanceIndex = 0
            capturedUnitIndex = 0
        }
        .onChange(of: analysis.units.map(\.id)) { _, identities in
            if !identities.contains(where: { $0 == selectedUnitID }) {
                selectedUnitID = identities.first
            }
        }
        .onChange(of: selectedUnitID) { _, _ in focusedVariableID = nil }
        .onChange(of: model.snapshot?.projectID) { _, _ in
            selectedUnitID = nil
            sourceRevisionID = nil
            exportData = nil
        }
        .onChange(of: model.snapshot?.sources.map(\.sourceRevisionID) ?? []) { _, identities in
            if let sourceRevisionID, !identities.contains(sourceRevisionID) {
                self.sourceRevisionID = nil
            }
        }
        .onDisappear { exportData = nil }
        .fileExporter(
            isPresented: Binding(get: { exportData != nil }, set: { if !$0 { exportData = nil } }),
            document: exportData.map(StudioLinguisticJSONDocument.init), contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
                exportFailed = true
            }
            exportData = nil
        }
        .alert("linguistic.export-failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("linguistic.tool", selection: $analysis.tool) {
                ForEach(StudioLinguisticTool.allCases) { tool in
                    Text(LocalizedStringKey(tool.titleKey)).tag(tool)
                }
            }
            .disabled(model.isBusy)
            Text(LocalizedStringKey(analysis.tool.descriptionKey))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Label("linguistic.session-only", systemImage: "clock")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
    }

    private var configuration: some View {
        Form {
            Section("linguistic.configuration") {
                LabeledContent("linguistic.language") { Text("linguistic.language.italian") }
                if analysis.tool == .availability {
                    Text("linguistic.availability-help").foregroundStyle(.secondary)
                } else {
                    Picker("linguistic.base", selection: $analysis.base) {
                        ForEach(Self.bases, id: \.rawValue) { base in
                            Text(LocalizedStringKey(Self.baseKey(base))).tag(base)
                        }
                    }
                    Toggle("linguistic.include-pos", isOn: $analysis.includesPartOfSpeech)
                    Text("linguistic.prediction-help").font(.callout).foregroundStyle(.secondary)
                }
            }
            if analysis.tool == .annotation {
                Section("linguistic.text") {
                    TextEditor(text: $analysis.text)
                        .font(.body.monospaced()).frame(minHeight: 200)
                        .accessibilityLabel("linguistic.text")
                }
                projectInput
            } else if analysis.tool == .coding {
                unitEditor
                Section("linguistic.rules") {
                    TextEditor(text: $analysis.rules)
                        .font(.body.monospaced()).frame(minHeight: 150)
                        .accessibilityLabel("linguistic.rules")
                    Text("linguistic.rules-help").font(.caption).foregroundStyle(.secondary)
                }
                projectInput
            }
            if analysis.origin != nil && analysis.tool != .availability {
                Section {
                    Label(
                        LocalizedStringKey(
                            analysis.isModifiedProjectCopy
                                ? "linguistic.copy.modified" : "linguistic.copy.exact"),
                        systemImage: "doc.on.doc"
                    )
                    .font(.caption)
                }
            }
            Section {
                Button("linguistic.run", systemImage: "play.fill") { execute() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(analysis.tool == .coding && analysis.units.isEmpty)
                if analysis.tool != .availability {
                    Button("linguistic.example", systemImage: "doc.badge.plus") {
                        analysis.loadSyntheticExample()
                    }
                }
                DisclosureGroup("linguistic.limits") {
                    Text("linguistic.limits-help").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(model.isBusy)
    }

    private var unitEditor: some View {
        Section("linguistic.units") {
            LabeledContent("linguistic.unit-count") { Text(analysis.units.count, format: .number) }
            Picker("linguistic.selected-unit", selection: $selectedUnitID) {
                Text("linguistic.unit.none").tag(UUID?.none)
                ForEach(analysis.units) { unit in
                    Text(
                        unit.identifier.isEmpty
                            ? String(localized: "linguistic.unit.new", locale: locale)
                            : unit.identifier
                    )
                    .tag(Optional(unit.id))
                }
            }
            if let index = selectedUnitIndex {
                TextField("linguistic.unit.id", text: $analysis.units[index].identifier)
                    .autocorrectionDisabled().focused(
                        $focusedUnitID, equals: analysis.units[index].id)
                TextEditor(text: $analysis.units[index].text)
                    .font(.body.monospaced()).frame(minHeight: 180)
                    .accessibilityLabel("linguistic.unit.text")
                DisclosureGroup("linguistic.variables") {
                    Text("linguistic.variables-help").font(.caption).foregroundStyle(.secondary)
                    ForEach($analysis.units[index].variables) { $variable in
                        let ordinal =
                            (analysis.units[index].variables.firstIndex { $0.id == variable.id }
                                ?? 0) + 1
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("linguistic.variable.key", text: $variable.key)
                                .autocorrectionDisabled()
                                .focused($focusedVariableID, equals: variable.id)
                                .accessibilityLabel(
                                    Text("linguistic.variable.key-index \(ordinal)"))
                            TextField(
                                "linguistic.variable.value", text: $variable.value, axis: .vertical
                            )
                            .accessibilityLabel(Text("linguistic.variable.value-index \(ordinal)"))
                            Button("linguistic.variable.remove", role: .destructive) {
                                let identity = variable.id
                                analysis.units[index].variables.removeAll { $0.id == identity }
                                if focusedVariableID == identity { focusedVariableID = nil }
                            }
                            .accessibilityLabel(Text("linguistic.variable.remove-index \(ordinal)"))
                        }
                        .accessibilityElement(children: .contain)
                    }
                    Button("linguistic.variable.add", systemImage: "plus") {
                        let variable = StudioLinguisticVariable()
                        analysis.units[index].variables.append(variable)
                        focusedVariableID = variable.id
                    }
                    .disabled(
                        analysis.units[index].variables.count
                            >= StudioLinguisticModel.maximumVariables)
                }
                Button("linguistic.unit.remove", role: .destructive) {
                    let identity = analysis.units[index].id
                    analysis.units.removeAll { $0.id == identity }
                    selectedUnitID = analysis.units.first?.id
                }
            }
            Button("linguistic.unit.add", systemImage: "plus") {
                selectedUnitID = analysis.addUnit()
                focusedUnitID = selectedUnitID
            }
            .disabled(analysis.units.count >= StudioLinguisticModel.maximumUnits)
        }
    }

    @ViewBuilder private var projectInput: some View {
        if let snapshot = model.snapshot, !snapshot.sources.isEmpty {
            Section {
                DisclosureGroup("linguistic.from-project") {
                    Text("linguistic.from-project-help").font(.caption).foregroundStyle(.secondary)
                    if analysis.tool == .annotation {
                        Picker("linguistic.project-source", selection: $sourceRevisionID) {
                            Text("coding.source.none").tag(String?.none)
                            ForEach(
                                Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID
                            ) { index, source in
                                Text("workspace.source.ordinal \(index + 1)").tag(
                                    Optional(source.sourceRevisionID))
                            }
                        }
                    } else {
                        Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                            Text("summary.scope.all").tag(StudioTextAnalysisScope.allSources)
                            Text("summary.scope.selected").tag(
                                StudioTextAnalysisScope.selectedSources)
                        }
                        if model.textAnalysisScope == .selectedSources {
                            ForEach(
                                Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID
                            ) { index, source in
                                Toggle(
                                    isOn: Binding(
                                        get: {
                                            model.selectedTextAnalysisSourceRevisionIDs.contains(
                                                source.sourceRevisionID)
                                        },
                                        set: { selected in
                                            if selected {
                                                model.selectedTextAnalysisSourceRevisionIDs.insert(
                                                    source.sourceRevisionID)
                                            } else {
                                                model.selectedTextAnalysisSourceRevisionIDs.remove(
                                                    source.sourceRevisionID)
                                            }
                                        })
                                ) { Text("workspace.source.ordinal \(index + 1)") }
                            }
                        }
                    }
                    Button("linguistic.load-project", systemImage: "doc.on.doc") {
                        let ids = selectedSourceIDs
                        Task {
                            await model.runAdvancedAnalysis { session in
                                try await analysis.loadProjectInput(session: session, ids: ids)
                            }
                        }
                    }
                    .disabled(selectedSourceIDs.isEmpty)
                }
            }
        }
    }

    private var results: some View {
        Form {
            if let output = analysis.output {
                Section {
                    Text(LocalizedStringKey(output.input.tool.titleKey)).font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    if analysis.isDraftChanged {
                        Label("linguistic.draft-changed", systemImage: "info.circle")
                    }
                    if output.input.origin != nil && output.input.tool != .availability {
                        Label(
                            LocalizedStringKey(
                                output.input.isModifiedProjectCopy
                                    ? "linguistic.copy.modified" : "linguistic.copy.exact"),
                            systemImage: "doc.on.doc")
                    }
                    if case let .availability(value) = output.payload {
                        LabeledContent("linguistic.language", value: value.languageTag)
                        LabeledContent("linguistic.os", value: value.operatingSystemVersion)
                        Text("linguistic.availability-help").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }
                resultTable(output)
                Section("linguistic.method") {
                    LabeledContent("linguistic.method-id", value: output.methodIdentifier)
                        .font(.caption.monospaced()).textSelection(.enabled)
                    LabeledContent("linguistic.request-digest", value: output.requestDigest)
                        .font(.caption.monospaced()).textSelection(.enabled)
                    Text(LocalizedStringKey("advanced.validation.\(output.validationStatus)"))
                    Text("linguistic.interpretation-help").font(.caption).foregroundStyle(
                        .secondary)
                    provenance(output)
                    DisclosureGroup("linguistic.captured-input") { capturedInput(output.input) }
                    Button("linguistic.export-request", systemImage: "curlybraces") {
                        exportFilename = "GlifiStudio-LinguisticRequest"
                        exportData = output.canonicalRequest
                    }
                    Button("linguistic.export-result", systemImage: "square.and.arrow.up") {
                        exportFilename = "GlifiStudio-LinguisticResult"
                        exportData = output.encodedResult
                    }
                    Text("linguistic.export-help").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "linguistic.empty", systemImage: "textformat.abc",
                    description: Text("linguistic.empty-help"))
            }
        }
        .formStyle(.grouped)
    }

    private func resultTable(_ output: StudioLinguisticOutput) -> some View {
        Section("linguistic.tables") {
            Picker("linguistic.table", selection: $analysis.selectedTable) {
                ForEach(Array(output.tables.enumerated()), id: \.offset) { index, table in
                    Text(LocalizedStringKey("linguistic.table.\(table.id)")).tag(index)
                }
            }
            if let table = analysis.selectedResultTable {
                LabeledContent("linguistic.row-count") { Text(table.rows.count, format: .number) }
                Table(analysis.visibleRows) {
                    TableColumnForEach(Array(table.columns.enumerated()), id: \.offset) {
                        index, column in
                        TableColumn(LocalizedStringKey("linguistic.column.\(column)")) { row in
                            if row.values.indices.contains(index) {
                                cell(row.values[index]).textSelection(.enabled)
                            }
                        }
                    }
                }
                .frame(minHeight: 220, idealHeight: 360)
                if table.rows.isEmpty { Text("linguistic.no-rows").foregroundStyle(.secondary) }
                ViewThatFits(in: .horizontal) {
                    HStack { pagination }
                    VStack(alignment: .leading, spacing: 12) { pagination }
                }
            }
            Text("linguistic.offset-help").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var pagination: some View {
        Button("advanced.first-page", systemImage: "backward.end") { analysis.showPage(0) }
            .disabled(analysis.page == 0)
        Button("advanced.previous-page", systemImage: "chevron.backward") {
            analysis.showPage(analysis.page - 1)
        }.disabled(analysis.page == 0)
        Text("linguistic.page \(analysis.page + 1) \(analysis.pageCount)").monospacedDigit()
        Button("advanced.next-page", systemImage: "chevron.forward") {
            analysis.showPage(analysis.page + 1)
        }.disabled(analysis.page + 1 >= analysis.pageCount)
        Button("advanced.last-page", systemImage: "forward.end") {
            analysis.showPage(analysis.pageCount - 1)
        }.disabled(analysis.page + 1 >= analysis.pageCount)
    }

    @ViewBuilder private func cell(_ value: StudioLinguisticCell) -> some View {
        switch value {
        case let .text(value): Text(value).help(value)
        case let .integer(value): Text(value, format: .number).monospacedDigit()
        case let .semantic(key): Text(LocalizedStringKey(key))
        }
    }

    @ViewBuilder private func provenance(_ output: StudioLinguisticOutput) -> some View {
        let records = output.payload.provenances
        if !records.isEmpty {
            DisclosureGroup("linguistic.provenance") {
                if records.count > 1 {
                    Picker("linguistic.provenance-unit", selection: $provenanceIndex) {
                        ForEach(Array(records.indices), id: \.self) { index in
                            if output.input.units.indices.contains(index) {
                                Text(output.input.units[index].identifier).tag(index)
                            }
                        }
                    }
                }
                if records.indices.contains(provenanceIndex) {
                    provenanceRecord(records[provenanceIndex])
                }
            }
        }
    }

    private func provenanceRecord(_ record: GlifiStudioLinguisticProvenance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("linguistic.language", value: record.languageTag)
            LabeledContent("linguistic.base") {
                Text(LocalizedStringKey(Self.baseKey(record.base)))
            }
            LabeledContent("linguistic.include-pos") {
                Text(LocalizedStringKey(record.includesPartOfSpeech ? "common.yes" : "common.no"))
            }
            LabeledContent("linguistic.os", value: record.operatingSystemVersion)
            LabeledContent("linguistic.model-version") {
                if let version = record.modelVersion {
                    Text(version)
                } else if record.modelVersionPolicy == "no-model" {
                    Text("linguistic.model-none")
                } else {
                    Text("linguistic.model-unknown")
                }
            }
            if record.modelVersion == nil && record.modelVersionPolicy != "no-model" {
                Text("linguistic.model-policy-help").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("linguistic.contracts") {
                LabeledContent("linguistic.locale", value: record.localeIdentifier)
                LabeledContent("linguistic.tokenization", value: record.tokenizationIdentifier)
                LabeledContent("linguistic.backend", value: record.backendIdentifier)
                LabeledContent("linguistic.adapter-version", value: record.backendVersion)
                LabeledContent("linguistic.model-policy", value: record.modelVersionPolicy)
                if let tagset = record.partOfSpeechTagset {
                    LabeledContent("linguistic.tagset", value: tagset)
                }
                LabeledContent("linguistic.prediction-policy", value: record.predictionPolicy)
                if let stem = record.stemmingIdentifier {
                    LabeledContent("linguistic.stemming", value: stem)
                }
                LabeledContent("linguistic.coding-contract", value: record.codingContractIdentifier)
            }
            .font(.caption.monospaced()).textSelection(.enabled)
        }
    }

    private func capturedInput(_ input: StudioLinguisticInput) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("linguistic.tool") { Text(LocalizedStringKey(input.tool.titleKey)) }
            LabeledContent("linguistic.language", value: input.languageTag)
            if input.tool != .availability {
                LabeledContent("linguistic.base") {
                    Text(LocalizedStringKey(Self.baseKey(input.base)))
                }
                LabeledContent("linguistic.include-pos") {
                    Text(
                        LocalizedStringKey(input.includesPartOfSpeech ? "common.yes" : "common.no"))
                }
            }
            if input.tool == .annotation { textPreview(input.text) }
            if input.tool == .coding {
                Picker("linguistic.selected-unit", selection: $capturedUnitIndex) {
                    ForEach(Array(input.units.enumerated()), id: \.offset) { index, unit in
                        Text(unit.identifier).tag(index)
                    }
                }
                if input.units.indices.contains(capturedUnitIndex) {
                    let unit = input.units[capturedUnitIndex]
                    LabeledContent("linguistic.unit.id", value: unit.identifier)
                    textPreview(unit.text)
                    ForEach(unit.variables) { variable in
                        LabeledContent(variable.key, value: variable.value)
                    }
                }
                Text("linguistic.rules").font(.headline)
                textPreview(input.rules)
            }
            if let origin = input.origin, input.tool != .availability {
                DisclosureGroup("linguistic.source-origin") {
                    LabeledContent("linguistic.project-id", value: origin.projectID)
                    LabeledContent("linguistic.generation") {
                        Text(origin.generation, format: .number)
                    }
                    ForEach(Array(origin.sourceRevisionIDs.enumerated()), id: \.offset) {
                        index, id in
                        Text(id).textSelection(.enabled)
                        if origin.contentDigests.indices.contains(index) {
                            Text(origin.contentDigests[index]).textSelection(.enabled)
                        }
                    }
                }
                .font(.caption.monospaced())
            }
        }
    }

    private func textPreview(_ text: String) -> some View {
        let prefix = text.prefix(8_193)
        return VStack(alignment: .leading, spacing: 4) {
            Text(String(prefix.prefix(8_192))).font(.caption.monospaced()).textSelection(.enabled)
            if prefix.count > 8_192 {
                Text("linguistic.preview-limit").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var selectedUnitIndex: Int? { analysis.units.firstIndex { $0.id == selectedUnitID } }
    private var selectedSourceIDs: [String] {
        if analysis.tool == .annotation { return sourceRevisionID.map { [$0] } ?? [] }
        switch model.textAnalysisScope {
        case .allSources: return model.snapshot?.sources.map(\.sourceRevisionID) ?? []
        case .selectedSources: return model.selectedTextAnalysisSourceRevisionIDs.sorted()
        }
    }
    nonisolated private static let bases: [GlifiStudioLinguisticBase] = [
        .normalizedSurface, .appleLemma, .italianSnowballStem,
    ]
    nonisolated private static func baseKey(_ base: GlifiStudioLinguisticBase) -> String {
        "linguistic.base.\(base.rawValue)"
    }
    private func execute() {
        Task { await model.runCoreAnalysis { try await analysis.execute(locale: locale) } }
    }
}

private struct StudioLinguisticJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct StudioLinguisticPreview: View {
    @State private var model = StudioHomeModel()
    var showsResult = false
    var body: some View {
        StudioLinguisticView(model: model)
            .task {
                model.linguistics.loadSyntheticExample()
                if showsResult {
                    await model.runCoreAnalysis {
                        try await model.linguistics.execute(locale: .init(identifier: "it"))
                    }
                }
            }
    }
}

#Preview("Linguistica · chiaro") {
    StudioLinguisticPreview().environment(\.locale, Locale(identifier: "it")).frame(
        width: 1100, height: 760)
}
#Preview("Linguistica · risultato scuro") {
    StudioLinguisticPreview(showsResult: true).preferredColorScheme(.dark).frame(
        width: 1100, height: 760)
}
#Preview("Linguistica · testo grande") {
    StudioLinguisticPreview().environment(\.locale, Locale(identifier: "en")).environment(
        \.dynamicTypeSize, .accessibility3
    ).frame(width: 440, height: 780)
}
#Preview("Linguistica · destra-sinistra") {
    StudioLinguisticPreview().environment(\.layoutDirection, .rightToLeft).frame(
        width: 440, height: 780)
}
