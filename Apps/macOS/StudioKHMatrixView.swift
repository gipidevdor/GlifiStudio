// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Themed KH profiles expose count universes, matrices and scientific choices as native controls.
struct StudioKHMatrixView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var analysis: StudioKHMatrixModel
    var initialTool: StudioKHMatrixTool?
    @Environment(\.locale) private var locale
    @State private var exportDocument: StudioKHMatrixExportDocument?
    @State private var exportFailed = false

    init(model: StudioHomeModel, initialTool: StudioKHMatrixTool? = nil) {
        self.model = model
        analysis = model.khMatrix
        self.initialTool = initialTool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedStringKey(analysis.tool.titleKey)).font(.title2)
                StudioAnalysisRoleView(route: .khMatrix(analysis.tool))
                Text(LocalizedStringKey(analysis.tool.descriptionKey)).foregroundStyle(.secondary)
                Text("kh.matrix.candidate").font(.callout).foregroundStyle(.secondary)
                GroupBox("kh.matrix.input") { inputControls.padding(8) }
                GroupBox("kh.matrix.parameters") { parameters.padding(8) }
                Button {
                    Task {
                        await model.runCoreAnalysis { try await analysis.execute(locale: locale) }
                    }
                } label: {
                    Label("advanced.run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isBusy)
                if let output = analysis.output { results(output) }
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey(analysis.tool.titleKey))
        .onAppear { if let initialTool { analysis.tool = initialTool } }
        .onChange(of: initialTool) { _, value in if let value { analysis.tool = value } }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument, contentType: .json,
            defaultFilename: "GlifiStudio-\(analysis.output?.tool.rawValue ?? "KH")"
        ) { result in
            if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
                exportFailed = true
            }
            exportDocument = nil
        }
        .alert("visual.export.failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
    }

    @ViewBuilder private var inputControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if analysis.tool == .wordContext {
                Text("kh.matrix.context-explicit").font(.callout)
            } else if let snapshot = model.snapshot, !snapshot.sources.isEmpty {
                Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                    ForEach(StudioTextAnalysisScope.allCases) { scope in
                        Text(LocalizedStringKey(scope.titleKey)).tag(scope)
                    }
                }
                if model.textAnalysisScope == .selectedSources {
                    DisclosureGroup("advanced.select-sources") {
                        ForEach(snapshot.sources, id: \.sourceRevisionID) { source in
                            Toggle(
                                sourceName(source.sourceRevisionID),
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
                                    }))
                        }
                    }
                }
                integer("kh.matrix.maximum-terms", $analysis.maximumTerms)
                Button("kh.matrix.prepare", systemImage: "tablecells") {
                    let ids =
                        model.textAnalysisScope == .allSources
                        ? snapshot.sources.map(\.sourceRevisionID)
                        : model.selectedTextAnalysisSourceRevisionIDs.sorted()
                    Task {
                        await model.runAdvancedAnalysis { session in
                            try await analysis.prepareInput(
                                session: session, sourceRevisionIDs: ids)
                        }
                    }
                }
                .disabled(model.isBusy)
                Text("kh.matrix.prepare-description").font(.caption).foregroundStyle(.secondary)
                if let input = analysis.input {
                    LabeledContent("kh.matrix.corpus-size") {
                        Text("\(input.documents.count) × \(input.terms.count)").monospacedDigit()
                    }
                    preparedScope(input)
                }
            } else {
                Text("kh.matrix.manual-input").font(.callout).foregroundStyle(.secondary)
            }
            switch analysis.tool {
            case .collocationScores, .wordAssociation:
                if analysis.input != nil {
                    Toggle("kh.matrix.corpus-auxiliary", isOn: $analysis.usesCorpusAuxiliary)
                }
                if analysis.usesCorpusAuxiliary, let input = analysis.input {
                    Picker("kh.matrix.node-term", selection: $analysis.nodeTerm) {
                        ForEach(input.terms, id: \.self) { Text($0).tag($0) }
                    }
                    if analysis.tool == .collocationScores {
                        Picker("kh.matrix.collocate-term", selection: $analysis.collocateTerm) {
                            ForEach(input.terms, id: \.self) { Text($0).tag($0) }
                        }
                        Stepper(
                            "kh.matrix.window-radius", value: $analysis.windowRadius, in: 1...100)
                        Text(analysis.windowRadius, format: .number).monospacedDigit()
                        Text("kh.matrix.window-universe").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("kh.matrix.condition-sources").font(.headline)
                        ForEach(input.sourceRevisionIDs, id: \.self) { id in
                            Toggle(
                                sourceName(id),
                                isOn: Binding(
                                    get: { analysis.conditionSourceIDs.contains(id) },
                                    set: { selected in
                                        if selected {
                                            analysis.conditionSourceIDs.insert(id)
                                        } else {
                                            analysis.conditionSourceIDs.remove(id)
                                        }
                                    }))
                        }
                    }
                } else {
                    integer("kh.matrix.joint", $analysis.jointCount)
                    if analysis.tool == .collocationScores {
                        integer("kh.matrix.node-frequency", $analysis.nodeFrequency)
                        integer("kh.matrix.collocate-frequency", $analysis.collocateFrequency)
                        integer("kh.matrix.corpus-tokens", $analysis.corpusTokenCount)
                        integer("kh.matrix.window-span", $analysis.windowSpan)
                    } else {
                        integer("kh.matrix.condition-count", $analysis.conditionDocumentCount)
                        integer("kh.matrix.term-document-count", $analysis.termDocumentCount)
                        integer("kh.matrix.total-documents", $analysis.totalDocumentCount)
                    }
                }
            case .wordContext:
                contextControls
            case .hierarchicalWardD2:
                if analysis.input != nil {
                    Toggle("kh.matrix.corpus-distances", isOn: $analysis.usesCorpusAuxiliary)
                }
                if analysis.usesCorpusAuxiliary {
                    Toggle("kh.matrix.cluster-terms", isOn: $analysis.clustersTerms)
                    Picker("advanced.distance", selection: $analysis.distance) {
                        ForEach(
                            [
                                GlifiStudioTextDistance.jaccard, .cosine, .dice, .simpson,
                                .euclidean, .manhattan,
                            ], id: \.self
                        ) { value in
                            Text(LocalizedStringKey("advanced.distance.\(value.rawValue)")).tag(
                                value)
                        }
                    }
                } else {
                    Text("kh.matrix.dissimilarities").font(.caption)
                    StudioKHMatrixGrid(matrix: $analysis.matrix)
                }
            case .sampleZScores, .perThousand, .correspondenceScaled, .documentScores, .chiSquare:
                StudioKHMatrixGrid(matrix: $analysis.matrix) { analysis.alignAuxiliaryDimensions() }
            }
        }
        .disabled(model.isBusy)
    }

    @ViewBuilder private var parameters: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch analysis.tool {
            case .sampleZScores:
                Picker("kh.matrix.axis", selection: $analysis.axis) {
                    Text("kh.matrix.axis.rows").tag(GlifiStudioKHMatrixAxis.rows)
                    Text("kh.matrix.axis.columns").tag(GlifiStudioKHMatrixAxis.columns)
                }
                Picker("kh.matrix.constant", selection: $analysis.constantPolicy) {
                    Text("kh.matrix.policy.reject").tag(GlifiStudioKHConstantPolicy.reject)
                    Text("kh.matrix.policy.zeros").tag(GlifiStudioKHConstantPolicy.zeros)
                }
            case .perThousand, .documentScores:
                exposureControls
                if analysis.tool == .perThousand {
                    Picker("kh.matrix.zero-exposure", selection: $analysis.zeroExposurePolicy) {
                        Text("kh.matrix.policy.reject").tag(GlifiStudioKHZeroExposurePolicy.reject)
                        Text("kh.matrix.policy.zeros").tag(GlifiStudioKHZeroExposurePolicy.zeros)
                    }
                } else {
                    integer("kh.matrix.corpus-documents", $analysis.corpusDocumentCount)
                    ForEach(analysis.documentFrequencies.indices, id: \.self) { column in
                        HStack {
                            Text(
                                analysis.matrix.columnLabels.indices.contains(column)
                                    ? analysis.matrix.columnLabels[column] : String(column + 1))
                            integer(
                                "kh.matrix.document-frequency",
                                $analysis.documentFrequencies[column])
                        }
                    }
                    Picker("kh.matrix.score-mode", selection: $analysis.scoreMode) {
                        Text("kh.matrix.score.tf").tag(GlifiStudioKHDocumentScoreMode.tf)
                        Text("kh.matrix.score.tfIdf").tag(GlifiStudioKHDocumentScoreMode.tfIdf)
                        Text("kh.matrix.score.tfDividedByIdf").tag(
                            GlifiStudioKHDocumentScoreMode.tfDividedByIdf)
                    }
                }
            case .correspondenceScaled:
                scalingPicker("kh.matrix.row-scaling", $analysis.rowScaling)
                scalingPicker("kh.matrix.column-scaling", $analysis.columnScaling)
                Text("kh.matrix.scaling-caveat").font(.caption).foregroundStyle(.secondary)
            case .chiSquare:
                Picker("kh.matrix.correction", selection: $analysis.correction) {
                    Text("kh.matrix.correction.automatic").tag(
                        GlifiStudioKHChiSquareCorrection.automatic)
                    Text("kh.matrix.correction.none").tag(GlifiStudioKHChiSquareCorrection.none)
                    Text("kh.matrix.correction.yates").tag(GlifiStudioKHChiSquareCorrection.yates)
                }
                Text("kh.matrix.chi-square-caveat").font(.caption).foregroundStyle(.secondary)
            case .hierarchicalWardD2:
                Text("kh.matrix.ward-caveat").font(.caption).foregroundStyle(.secondary)
            case .collocationScores, .wordAssociation:
                Text("kh.matrix.count-universes").font(.caption).foregroundStyle(.secondary)
            case .wordContext:
                Text("kh.matrix.context-weights").font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(model.isBusy)
    }

    private var exposureControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("kh.matrix.complete-exposures").font(.caption)
            ForEach(analysis.exposures.indices, id: \.self) { row in
                HStack {
                    Text(
                        analysis.matrix.rowLabels.indices.contains(row)
                            ? sourceName(analysis.matrix.rowLabels[row]) : String(row + 1))
                    TextField(
                        "kh.matrix.exposure", value: $analysis.exposures[row], format: .number
                    )
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                }
            }
        }
    }

    private var contextControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            identityControls("kh.matrix.targets", ids: $analysis.contextTargetIDs)
            identityControls("kh.matrix.context-words", ids: $analysis.contextIDs)
            ForEach($analysis.contextLevels) { $level in
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("kh.matrix.context-level", selection: $level.level) {
                            ForEach(
                                [
                                    GlifiStudioKHContextLevel.sentence, .paragraph, .h5, .h4, .h3,
                                    .h2, .h1,
                                ], id: \.self
                            ) { value in
                                Text(LocalizedStringKey("kh.matrix.level.\(value.rawValue)")).tag(
                                    value)
                            }
                        }
                        TextField("kh.matrix.alpha", value: $level.alpha, format: .number)
                            .textFieldStyle(.roundedBorder)
                        Text("kh.matrix.target-counts").font(.headline)
                        StudioKHMatrixGrid(matrix: $level.targets)
                        Text("kh.matrix.context-counts").font(.headline)
                        StudioKHMatrixGrid(matrix: $level.contexts)
                        Button("kh.matrix.remove-level", role: .destructive) {
                            analysis.contextLevels.removeAll { $0.id == level.id }
                        }
                        .disabled(analysis.contextLevels.count <= 1)
                    }
                    .padding(8)
                }
            }
            Button("kh.matrix.add-level", systemImage: "plus") {
                let used = Set(analysis.contextLevels.map { $0.level.rawValue })
                if let next = [
                    GlifiStudioKHContextLevel.sentence, .paragraph, .h5, .h4, .h3, .h2, .h1,
                ]
                .first(where: { !used.contains($0.rawValue) }) {
                    var draft = StudioKHContextDraft()
                    draft.level = next
                    analysis.contextLevels.append(draft)
                }
            }
            .disabled(analysis.contextLevels.count >= 7)
        }
    }

    private func identityControls(_ key: String, ids: Binding<[String]>) -> some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey(key)).font(.headline)
            Stepper(
                value: Binding(
                    get: { ids.wrappedValue.count },
                    set: { count in
                        ids.wrappedValue = (0..<count).map {
                            ids.wrappedValue.indices.contains($0)
                                ? ids.wrappedValue[$0] : String($0 + 1)
                        }
                    }), in: 1...200
            ) {
                Text(ids.wrappedValue.count, format: .number)
            }
            ForEach(ids.wrappedValue.indices, id: \.self) { index in
                TextField(LocalizedStringKey(key), text: ids[index]).textFieldStyle(.roundedBorder)
            }
        }
    }

    private func scalingPicker(_ key: String, _ value: Binding<GlifiStudioKHCorrespondenceScaling>)
        -> some View
    {
        Picker(LocalizedStringKey(key), selection: value) {
            Text("kh.matrix.scaling.principal").tag(GlifiStudioKHCorrespondenceScaling.principal)
            Text("kh.matrix.scaling.standard").tag(GlifiStudioKHCorrespondenceScaling.standard)
            Text("kh.matrix.scaling.symmetric").tag(GlifiStudioKHCorrespondenceScaling.symmetric)
        }
    }

    private func integer(_ key: String, _ value: Binding<Int>) -> some View {
        TextField(LocalizedStringKey(key), value: value, format: .number)
            .textFieldStyle(.roundedBorder)
    }

    private func sourceName(_ id: String) -> String {
        guard let index = model.snapshot?.sources.firstIndex(where: { $0.sourceRevisionID == id })
        else { return id }
        return String(localized: "summary.source.label", bundle: .main, locale: locale)
            + " " + (index + 1).formatted(.number.locale(locale))
    }

    private func results(_ output: StudioKHMatrixOutput) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey(output.tool.titleKey)).font(.headline)
            LabeledContent("visual.method", value: output.methodIdentifier)
            LabeledContent("advanced.validation") {
                Text(LocalizedStringKey("advanced.validation.\(output.validationStatus)"))
            }
            LabeledContent("advanced.request-digest", value: output.requestDigest)
                .textSelection(.enabled)
            if !analysis.outputMatchesDraft(output) {
                Label("kh.matrix.draft-changed", systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let provenance = output.provenance {
                DisclosureGroup("kh.matrix.used-provenance") {
                    LabeledContent("kh.matrix.project", value: provenance.projectID)
                    LabeledContent("kh.matrix.generation") {
                        Text(provenance.generation, format: .number)
                    }
                    ForEach(Array(provenance.sourceRevisionIDs.enumerated()), id: \.offset) {
                        index, id in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(id).textSelection(.enabled)
                            Text(provenance.contentDigests[index]).textSelection(.enabled)
                        }
                        .font(.caption.monospaced())
                    }
                    if provenance.hasManualEdits { Text("kh.matrix.manual-edits") }
                }
                if provenance.sourceRevisionIDs.sorted() != currentSourceIDs
                    || provenance.projectID != model.snapshot?.projectID
                {
                    Label("kh.matrix.scope-changed", systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            ForEach(output.tables) { table in
                StudioKHMatrixResultTable(table: table).id(output.completedAt)
            }
            Menu("action.export-view", systemImage: "square.and.arrow.up") {
                Button("kh.matrix.export-request") {
                    exportDocument = StudioKHMatrixExportDocument(data: output.request)
                }
                Button("kh.matrix.export-result") {
                    exportDocument = StudioKHMatrixExportDocument(data: output.result)
                }
            }
        }
    }

    private var currentSourceIDs: [String] {
        switch model.textAnalysisScope {
        case .allSources: model.snapshot?.sources.map(\.sourceRevisionID).sorted() ?? []
        case .selectedSources: model.selectedTextAnalysisSourceRevisionIDs.sorted()
        }
    }

    private func preparedScope(_ input: GlifiStudioProjectTextAnalysisInput) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup("kh.matrix.prepared-provenance") {
                LabeledContent("kh.matrix.project", value: input.projectID)
                LabeledContent("kh.matrix.generation") { Text(input.generation, format: .number) }
                ForEach(Array(input.sourceRevisionIDs.enumerated()), id: \.offset) { index, id in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(id).textSelection(.enabled)
                        Text(input.contentDigests[index]).textSelection(.enabled)
                    }
                    .font(.caption.monospaced())
                }
            }
            if input.sourceRevisionIDs.sorted() != currentSourceIDs {
                Label("kh.matrix.prepared-scope-changed", systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StudioKHMatrixResultTable: View {
    let table: StudioKHMatrixTable
    @State private var rowPage = 0
    @State private var columnPage = 0

    var body: some View {
        GroupBox(LocalizedStringKey(table.titleKey)) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            ForEach(columns, id: \.self) { column in
                                Text(table.columns[column]).font(
                                    .caption.bold()
                                )
                                .accessibilityAddTraits(.isHeader)
                            }
                        }
                        ForEach(
                            Array(table.rows.indices.dropFirst(rowPage * 20).prefix(20)), id: \.self
                        ) { row in
                            GridRow {
                                ForEach(columns, id: \.self) { column in
                                    Text(table.rows[row][column])
                                        .font(.caption.monospacedDigit()).textSelection(.enabled)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(8)
                }
                HStack {
                    Stepper(
                        "kh.matrix.row-page", value: $rowPage,
                        in: 0...max(0, (table.rows.count - 1) / 20))
                    Text(rowPage + 1, format: .number)
                    Stepper(
                        "kh.matrix.column-page", value: $columnPage,
                        in: 0...max(0, (table.columns.count - 1) / 8))
                    Text(columnPage + 1, format: .number)
                }
            }
        }
    }

    private var columns: [Int] {
        Array(table.columns.indices.dropFirst(columnPage * 8).prefix(8))
    }
}

/// A paged native cell grid avoids constructing the entire dense corpus matrix as controls.
private struct StudioKHMatrixGrid: View {
    @Binding var matrix: StudioKHNumericMatrix
    var onEdit: () -> Void = {}
    @State private var rowPage = 0
    @State private var columnPage = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(
                "kh.matrix.rows",
                value: Binding(
                    get: { matrix.values.count },
                    set: {
                        matrix.resize(rows: $0, columns: matrix.columnLabels.count)
                        rowPage = 0
                        onEdit()
                    }), in: 1...1_000)
            Text(matrix.values.count, format: .number).monospacedDigit()
            Stepper(
                "kh.matrix.columns",
                value: Binding(
                    get: { matrix.columnLabels.count },
                    set: {
                        matrix.resize(rows: matrix.values.count, columns: $0)
                        columnPage = 0
                        onEdit()
                    }), in: 1...1_000)
            Text(matrix.columnLabels.count, format: .number).monospacedDigit()
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Text("kh.matrix.row").font(.caption.bold())
                        ForEach(columns, id: \.self) { column in
                            TextField("kh.matrix.column-label", text: $matrix.columnLabels[column])
                                .textFieldStyle(.roundedBorder).frame(width: 100)
                        }
                    }
                    ForEach(rows, id: \.self) { row in
                        GridRow {
                            TextField("kh.matrix.row-label", text: $matrix.rowLabels[row])
                                .textFieldStyle(.roundedBorder).frame(width: 130)
                            ForEach(columns, id: \.self) { column in
                                TextField(
                                    "kh.matrix.value",
                                    value: Binding(
                                        get: { matrix.values[row][column] },
                                        set: {
                                            matrix.values[row][column] = $0
                                            onEdit()
                                        }), format: .number
                                )
                                .textFieldStyle(.roundedBorder).frame(width: 100)
                                .accessibilityLabel(Text("kh.matrix.cell \(row + 1) \(column + 1)"))
                            }
                        }
                    }
                }
            }
            HStack {
                Stepper(
                    "kh.matrix.row-page", value: $rowPage,
                    in: 0...max(0, (matrix.values.count - 1) / 20))
                Text(rowPage + 1, format: .number)
                Stepper(
                    "kh.matrix.column-page", value: $columnPage,
                    in: 0...max(0, (matrix.columnLabels.count - 1) / 8))
                Text(columnPage + 1, format: .number)
            }
        }
        .onChange(of: matrix.values.count) { _, _ in rowPage = 0 }
        .onChange(of: matrix.columnLabels.count) { _, _ in columnPage = 0 }
    }

    private var rows: [Int] {
        Array(matrix.values.indices.dropFirst(rowPage * 20).prefix(20))
    }
    private var columns: [Int] {
        Array(matrix.columnLabels.indices.dropFirst(columnPage * 8).prefix(8))
    }
}

private struct StudioKHMatrixExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
