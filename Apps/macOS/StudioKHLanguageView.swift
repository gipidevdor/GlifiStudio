// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Native editors for independent candidates, explicit annotations and incremental classifiers.
struct StudioKHLanguageView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var analysis: StudioKHLanguageModel
    var initialTool: StudioKHLanguageTool?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsStateImporter = false
    @State private var exportData: Data?
    @State private var pages: [String: Int] = [:]
    @State private var showsResults = false
    @State private var exportFailed = false

    init(model: StudioHomeModel, initialTool: StudioKHLanguageTool? = nil) {
        self.model = model
        self.initialTool = initialTool
        analysis = model.khLanguage
    }

    var body: some View {
        Group {
            if let snapshot = model.snapshot {
                GeometryReader { geometry in
                    if geometry.size.width >= 940 && !dynamicTypeSize.isAccessibilitySize {
                        HSplitView {
                            configuration(snapshot).frame(
                                minWidth: 320, idealWidth: 410, maxWidth: 560)
                            results.frame(minWidth: 380)
                        }
                    } else {
                        TabView(selection: $showsResults) {
                            Tab(value: false) {
                                configuration(snapshot)
                            } label: {
                                Text("cm.settings")
                            }
                            Tab(value: true) {
                                results
                            } label: {
                                Text("cm.results")
                            }
                        }
                        .tabViewStyle(.grouped)
                    }
                }
            } else {
                ContentUnavailableView(
                    "advanced.empty.title", systemImage: "text.magnifyingglass",
                    description: Text("advanced.empty.description"))
            }
        }
        .navigationTitle("kh.language.title")
        .onAppear { if let initialTool { analysis.tool = initialTool } }
        .onChange(of: initialTool) { _, tool in if let tool { analysis.tool = tool } }
        .onChange(of: analysis.tool) { _, _ in showsResults = false }
        .onChange(of: analysis.output?.completedAt) { _, date in
            pages = [:]
            showsResults = date != nil
        }
        .onChange(of: model.snapshot?.projectID) { _, _ in
            exportData = nil
            showsStateImporter = false
            pages = [:]
            showsResults = false
        }
        .fileImporter(isPresented: $showsStateImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url):
                Task {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    await model.runCoreAnalysis {
                        try await analysis.importClassifierState(from: url)
                    }
                }
            case .failure:
                exportFailed = true
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportData != nil }, set: { if !$0 { exportData = nil } }),
            document: KHLanguageJSONDocument(data: exportData ?? Data()), contentType: .json,
            defaultFilename: "GlifiStudio-language"
        ) { result in
            if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
                exportFailed = true
            }
            exportData = nil
        }
        .alert("advanced.export-failed", isPresented: $exportFailed) {
            Button("action.close", role: .cancel) {}
        }
    }

    private func configuration(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        Form {
            Section {
                Picker("cm.method", selection: $analysis.tool) {
                    ForEach(StudioKHLanguageTool.allCases) { tool in
                        Text(LocalizedStringKey(tool.titleKey)).tag(tool)
                    }
                }
                Text(LocalizedStringKey(analysis.tool.descriptionKey)).foregroundStyle(.secondary)
                StudioAnalysisRoleView(route: .khLanguage(analysis.tool))
            }
            if analysis.tool != .termScores {
                Section("cm.scope") {
                    Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                        ForEach(StudioTextAnalysisScope.allCases) { scope in
                            Text(LocalizedStringKey(scope.titleKey)).tag(scope)
                        }
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
            }
            switch analysis.tool {
            case .termScores: candidates
            case .termExtraction: annotations(snapshot)
            case .incrementalClassifier, .continueClassifier, .validateClassifierWithAgreement:
                classifier(snapshot)
            case .codeCrosstabSignificance:
                coding(snapshot)
            }
            Section {
                Button("advanced.run", systemImage: "play.fill") {
                    let ids = selectedIDs(snapshot)
                    let numbers = Dictionary(
                        uniqueKeysWithValues: snapshot.sources.enumerated().map {
                            ($0.element.sourceRevisionID, $0.offset + 1)
                        })
                    Task {
                        await model.runAdvancedAnalysis { session in
                            try await analysis.execute(
                                session: session, sourceRevisionIDs: ids,
                                sourceNumbers: numbers, locale: locale)
                        }
                    }
                }
                .disabled(model.isBusy)
            }
        }
        .formStyle(.grouped)
        .disabled(model.isBusy)
    }

    private var candidates: some View {
        Section("kh.language.candidates") {
            Text("kh.language.candidates-help").font(.caption).foregroundStyle(.secondary)
            TextField("kh.language.preprocessing", text: $analysis.draft.preprocessingIdentifier)
            ForEach($analysis.draft.candidates) { $candidate in
                VStack(alignment: .leading) {
                    TextField("kh.language.components", text: $candidate.components)
                    integer("kh.language.frequency", value: $candidate.frequency)
                    Button("action.remove", systemImage: "minus.circle") {
                        analysis.draft.candidates.removeAll { $0.id == candidate.id }
                    }
                }
            }
            Button("kh.language.add-candidate", systemImage: "plus") {
                analysis.draft.candidates.append(StudioKHTermCandidateDraft())
            }.disabled(analysis.draft.candidates.count >= 10_000)
            adjacency
            integer("kh.language.maximum-work", value: $analysis.draft.maximumWork)
        }
    }

    private func annotations(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        Group {
            Section("kh.language.annotations") {
                Text("kh.language.annotation-help").font(.caption).foregroundStyle(.secondary)
                Picker(
                    "kh.language.annotation-source", selection: $analysis.draft.annotationSourceID
                ) {
                    Text("kh.language.choose-source").tag("")
                    ForEach(Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID) {
                        index, source in
                        if selectedIDs(snapshot).contains(source.sourceRevisionID) {
                            Text("workspace.source.ordinal \(index + 1)").tag(
                                source.sourceRevisionID)
                        }
                    }
                }
                Button("kh.language.load-source", systemImage: "doc.text") {
                    Task {
                        await model.runAdvancedAnalysis {
                            try await analysis.loadAnnotationSource(session: $0)
                        }
                    }
                }.disabled(analysis.draft.annotationSourceID.isEmpty || model.isBusy)
                if let source = analysis.annotationSource,
                    source.sourceRevisionID == analysis.draft.annotationSourceID
                {
                    Text(source.text).font(.body).textSelection(.enabled)
                    TextField(
                        "kh.language.linguistic-contract", text: $analysis.draft.linguisticContract)
                    ForEach($analysis.draft.tokens) { $token in
                        DisclosureGroup(
                            token.surface.isEmpty
                                ? String(localized: "kh.language.token", locale: locale)
                                : token.surface
                        ) {
                            TextField("kh.language.surface", text: $token.surface)
                            TextField("kh.language.base", text: $token.base)
                            TextField("kh.language.pos", text: $token.partOfSpeech)
                            integer("kh.language.start", value: $token.startUTF8)
                            integer("kh.language.end", value: $token.endUTF8)
                            integer("kh.language.sentence", value: $token.sentence)
                            integer("kh.language.paragraph", value: $token.paragraph)
                            Button("action.remove", systemImage: "minus.circle") {
                                analysis.draft.tokens.removeAll { $0.id == token.id }
                            }
                        }
                    }
                    Button("kh.language.add-token", systemImage: "plus") {
                        analysis.draft.tokens.append(StudioKHTermTokenDraft())
                    }
                }
            }
            Section("kh.language.extraction-rule") {
                TextField("kh.language.rule-identifier", text: $analysis.draft.ruleIdentifier)
                Text("kh.language.allowed-pos")
                TextEditor(text: $analysis.draft.allowedPartsOfSpeech).frame(minHeight: 60)
                Text("kh.language.ignored-keys")
                TextEditor(text: $analysis.draft.ignoredKeys).frame(minHeight: 60)
                integer("kh.language.minimum-components", value: $analysis.draft.minimumComponents)
                integer("kh.language.maximum-components", value: $analysis.draft.maximumComponents)
                adjacency
                integer("kh.language.maximum-work", value: $analysis.draft.maximumWork)
            }
        }
    }

    private func classifier(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        Group {
            Section("kh.language.training") {
                Text(
                    analysis.tool == .validateClassifierWithAgreement
                        ? "kh.language.validation-help" : "kh.language.classifier-help"
                )
                .font(.caption).foregroundStyle(.secondary)
                labelFields(snapshot)
                if analysis.tool != .continueClassifier {
                    LabeledContent("advanced.smoothing") {
                        TextField(
                            "advanced.smoothing", value: $analysis.draft.smoothing, format: .number)
                    }
                }
                if analysis.tool == .validateClassifierWithAgreement {
                    integer("advanced.folds", value: $analysis.draft.folds)
                    LabeledContent("advanced.seed") {
                        TextField("advanced.seed", value: $analysis.draft.seed, format: .number)
                    }
                }
            }
            if analysis.tool == .continueClassifier || analysis.classifierState != nil {
                Section("kh.language.classifier-state") {
                    Text("kh.language.continuation-help").font(.caption).foregroundStyle(.secondary)
                    if let state = analysis.classifierState {
                        LabeledContent(
                            "kh.language.classes", value: state.classes.joined(separator: ", "))
                        LabeledContent(
                            "kh.language.vocabulary", value: state.vocabulary.count.formatted())
                        Button("kh.language.export-state", systemImage: "square.and.arrow.up") {
                            Task {
                                await model.runCoreAnalysis {
                                    exportData = try await analysis.encodedClassifierState()
                                }
                            }
                        }.disabled(model.isBusy)
                    }
                    Button("kh.language.import-state", systemImage: "square.and.arrow.down") {
                        showsStateImporter = true
                    }.disabled(model.isBusy)
                }
            }
        }
    }

    private func coding(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        Section("kh.language.coding") {
            Text("kh.language.coding-help").font(.caption).foregroundStyle(.secondary)
            labelFields(snapshot)
            Text("advanced.rules-parameters")
            TextEditor(text: $analysis.draft.rules).font(.body.monospaced()).frame(minHeight: 180)
            Picker("kh.language.correction", selection: $analysis.draft.correction) {
                Text("kh.language.correction.automatic").tag(
                    GlifiStudioKHChiSquareCorrection.automatic)
                Text("kh.language.correction.none").tag(GlifiStudioKHChiSquareCorrection.none)
                Text("kh.language.correction.yates").tag(GlifiStudioKHChiSquareCorrection.yates)
            }
        }
    }

    private func labelFields(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        ForEach(Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID) {
            index, source in
            if selectedIDs(snapshot).contains(source.sourceRevisionID) {
                TextField(
                    "workspace.source.ordinal \(index + 1)",
                    text: Binding(
                        get: { analysis.draft.labels[source.sourceRevisionID] ?? "" },
                        set: { analysis.draft.labels[source.sourceRevisionID] = $0 }))
            }
        }
    }

    private var adjacency: some View {
        Picker("kh.language.adjacency", selection: $analysis.draft.adjacencyMode) {
            Text("kh.language.adjacency.token").tag(GlifiStudioTermAdjacencyMode.token)
            Text("kh.language.adjacency.type").tag(GlifiStudioTermAdjacencyMode.type)
        }
    }

    private var results: some View {
        Form {
            if let output = analysis.output {
                Section {
                    Text(LocalizedStringKey(output.tool.titleKey)).font(.headline)
                    Text(
                        LocalizedStringKey(
                            output.result == nil
                                ? "research.saved.restored" : "research.saved.session-copy")
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if output.tool == .codeCrosstabSignificance {
                        Text("kh.language.coding-result-help").font(.caption).foregroundStyle(
                            .secondary)
                    }
                    if output.draft != analysis.draft || output.tool != analysis.tool {
                        Label("cm.changed-settings", systemImage: "info.circle")
                    }
                    if output.tool != .termScores, let snapshot = model.snapshot,
                        Set(selectedIDs(snapshot)) != Set(output.eligibleSourceRevisionIDs)
                    {
                        Label("cm.changed-scope", systemImage: "info.circle")
                    }
                    LabeledContent("visual.method", value: output.methodIdentifier)
                    ForEach(output.metrics) { metric in
                        LabeledContent(
                            StudioLocalization.key("kh.language.\(metric.key)"), value: metric.value
                        )
                    }
                    Menu("cm.export", systemImage: "square.and.arrow.up") {
                        Button("advanced.export-result") { exportData = output.encodedResult }
                        Button("advanced.export-request") { exportData = output.encodedRequest }
                    }
                }
                if let projectID = output.projectID, let generation = output.generation {
                    Section("kh.language.effective-provenance") {
                        LabeledContent("kh.language.project", value: projectID)
                        LabeledContent("kh.language.generation", value: generation.formatted())
                        ForEach(output.sourceRevisionIDs, id: \.self) { id in
                            DisclosureGroup {
                                LabeledContent("cm.source", value: id)
                                if let digest = output.contentDigests[id] {
                                    LabeledContent("kh.language.content-digest", value: digest)
                                }
                            } label: {
                                if let number = output.sourceNumbers[id] {
                                    Text("workspace.source.ordinal \(number)")
                                } else {
                                    Text(id)
                                }
                            }
                            .textSelection(.enabled)
                        }
                        if let source = output.annotatedSource {
                            LabeledContent(
                                "kh.language.source-bytes", value: source.byteCount.formatted())
                            LabeledContent(
                                "kh.language.linguistic-contract",
                                value: output.draft.linguisticContract)
                            DisclosureGroup("kh.language.annotated-original") {
                                Text(source.text).textSelection(.enabled)
                            }
                            if let document = source.document {
                                LabeledContent(
                                    "kh.language.original-format", value: document.format.rawValue)
                                LabeledContent(
                                    "kh.language.extraction-contract",
                                    value: document.extractionContractIdentifier)
                                LabeledContent(
                                    "kh.language.original-bytes",
                                    value: document.originalByteCount.formatted())
                            }
                        }
                    }
                }
                ForEach(output.tables) { table in
                    Section(StudioLocalization.key("kh.language.table.\(table.id)")) {
                        resultTable(table)
                    }
                }
            } else {
                ContentUnavailableView(
                    "cm.result-empty.title", systemImage: "text.magnifyingglass",
                    description: Text("cm.result-empty.description"))
            }
        }
        .formStyle(.grouped)
    }

    private func resultTable(_ table: StudioKHLanguageTable) -> some View {
        let page = pages[table.id] ?? 0
        let count = max(1, (table.rows.count + 49) / 50)
        return VStack(alignment: .leading) {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        ForEach(Array(table.columns.enumerated()), id: \.offset) { index, key in
                            Group {
                                if let first = table.literalColumnStart, index >= first {
                                    Text(key)
                                } else {
                                    Text(StudioLocalization.key("kh.language.\(key)"))
                                }
                            }.fontWeight(.semibold).accessibilityAddTraits(.isHeader)
                        }
                    }
                    ForEach(
                        Array(table.rows.dropFirst(page * 50).prefix(50).enumerated()), id: \.offset
                    ) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                                Text(value).textSelection(.enabled)
                            }
                        }.accessibilityElement(children: .combine)
                    }
                }.font(.caption)
            }
            if count > 1 {
                HStack {
                    Button("cm.previous-page", systemImage: "chevron.backward") {
                        pages[table.id] = page - 1
                    }
                    .disabled(page <= 0)
                    Text("\(page + 1) / \(count)").monospacedDigit()
                    Button("cm.next-page", systemImage: "chevron.forward") {
                        pages[table.id] = page + 1
                    }
                    .disabled(page + 1 >= count)
                }
            }
        }
    }

    private func selectedIDs(_ snapshot: GlifiStudioProjectSnapshot) -> [String] {
        switch model.textAnalysisScope {
        case .allSources: snapshot.sources.map(\.sourceRevisionID).sorted()
        case .selectedSources: model.selectedTextAnalysisSourceRevisionIDs.sorted()
        }
    }

    private func integer(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) { TextField(key, value: value, format: .number) }
    }
}

private struct KHLanguageJSONDocument: FileDocument {
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
