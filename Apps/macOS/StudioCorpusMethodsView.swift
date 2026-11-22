// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Direct access to the persisted corpus analyses, with scope and effective parameters.
struct StudioCorpusMethodsView: View {
    @Bindable var model: StudioHomeModel
    let onImportSources: (() -> Void)?
    let onOpenProject: (() -> Void)?
    @Bindable private var analysis: StudioCorpusMethodsModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsResults = false
    @State private var selectedRow: StudioCorpusMethodRow?
    @State private var source: GlifiStudioSourceText?
    @State private var showsSource = false
    @State private var showsExporter = false
    @State private var exportError = false

    init(
        model: StudioHomeModel, onImportSources: (() -> Void)? = nil,
        onOpenProject: (() -> Void)? = nil
    ) {
        self.onImportSources = onImportSources
        self.onOpenProject = onOpenProject
        self.model = model
        analysis = model.corpusMethods
    }

    var body: some View {
        Group {
            if let snapshot = model.snapshot, !snapshot.sources.isEmpty {
                VStack(spacing: 0) {
                    header
                    Divider()
                    GeometryReader { geometry in
                        if geometry.size.width >= 930 && !dynamicTypeSize.isAccessibilitySize {
                            HSplitView {
                                configuration(snapshot)
                                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 460)
                                results.frame(minWidth: 380)
                            }
                        } else {
                            VStack(spacing: 0) {
                                Picker("cm.pane", selection: $showsResults) {
                                    Text("cm.settings").tag(false)
                                    Text("cm.results").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .padding()
                                if showsResults { results } else { configuration(snapshot) }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("cm.empty.title", systemImage: "chart.bar.doc.horizontal")
                } description: {
                    Text("cm.empty.description")
                } actions: {
                    if model.snapshot != nil, let onImportSources {
                        Button("action.import", action: onImportSources).disabled(model.isBusy)
                    } else if let onOpenProject {
                        Button("action.open-project", action: onOpenProject).disabled(model.isBusy)
                    }
                }
            }
        }
        .navigationTitle("cm.title")
        .onChange(of: analysis.output?.completedAt) { _, value in
            if value != nil { showsResults = true }
        }
        .onChange(of: analysis.tool) { _, _ in showsResults = false }
        .onChange(of: model.snapshot?.projectID) { _, _ in
            selectedRow = nil
            source = nil
            showsSource = false
            showsResults = false
        }
        .sheet(item: $selectedRow) { row in
            NavigationStack {
                List(row.details) { field in
                    LabeledContent(fieldLabel(field.key), value: field.value)
                        .textSelection(.enabled)
                }
                .navigationTitle("cm.row-details")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("action.close") { selectedRow = nil }.keyboardShortcut(.cancelAction)
                    }
                }
            }
            .frame(minWidth: 420, idealWidth: 680, minHeight: 400, idealHeight: 620)
        }
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                if let source {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("cm.source-whole").font(.caption).foregroundStyle(.secondary)
                            Text(source.text).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(source.sourceRevisionID).font(.caption.monospaced()).textSelection(
                                .enabled)
                        }
                        .padding(24)
                    }
                    .navigationTitle("cm.source")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("action.close") { showsSource = false }.keyboardShortcut(
                                .cancelAction)
                        }
                    }
                }
            }
            .frame(minWidth: 420, idealWidth: 760, minHeight: 400, idealHeight: 620)
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: CorpusMethodsJSONDocument(data: analysis.output?.encodedResult ?? Data()),
            contentType: .json, defaultFilename: "GlifiStudio-CorpusAnalysis"
        ) { outcome in
            if case let .failure(error) = outcome, (error as? CocoaError)?.code != .userCancelled {
                exportError = true
            }
        }
        .alert("cm.export-error", isPresented: $exportError) {
            Button("action.close", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("cm.method", selection: $analysis.draft.tool) {
                ForEach(StudioCorpusMethod.allCases) { method in
                    Text(LocalizedStringKey(method.titleKey)).tag(method)
                }
            }
            .pickerStyle(.menu)
            .disabled(model.isBusy)
            Text(LocalizedStringKey(analysis.tool.descriptionKey))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func configuration(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        Form {
            Section("cm.scope") {
                Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                    ForEach(StudioTextAnalysisScope.allCases) { scope in
                        Text(LocalizedStringKey(scope.titleKey)).tag(scope)
                    }
                }
                LabeledContent("cm.selected-sources") {
                    Text(selectedIDs(snapshot).count, format: .number)
                }
                if model.textAnalysisScope == .selectedSources {
                    DisclosureGroup("cm.choose-sources") {
                        ForEach(
                            Array(snapshot.sources.enumerated()), id: \.element.sourceRevisionID
                        ) { index, source in
                            Toggle(
                                isOn: Binding(
                                    get: {
                                        model.selectedTextAnalysisSourceRevisionIDs.contains(
                                            source.sourceRevisionID)
                                    },
                                    set: { value in
                                        if value {
                                            model.selectedTextAnalysisSourceRevisionIDs.insert(
                                                source.sourceRevisionID)
                                        } else {
                                            model.selectedTextAnalysisSourceRevisionIDs.remove(
                                                source.sourceRevisionID)
                                        }
                                    }
                                )
                            ) {
                                sourceLabel(index: index, id: source.sourceRevisionID)
                            }
                        }
                    }
                }
            }
            if analysis.tool == .dispersion {
                Section("cm.partition") {
                    Toggle("cm.use-partition", isOn: $analysis.draft.usesPartition)
                    Text("cm.partition-help").font(.caption).foregroundStyle(.secondary)
                }
            }
            if analysis.tool.usesGroups
                || (analysis.tool == .dispersion && analysis.draft.usesPartition)
            {
                groups(snapshot)
            }
            parameters
            Section {
                Button("cm.run", systemImage: "play.fill") {
                    let ids = selectedIDs(snapshot)
                    let numbers = Dictionary(
                        uniqueKeysWithValues: snapshot.sources.enumerated().map {
                            ($0.element.sourceRevisionID, $0.offset + 1)
                        })
                    Task {
                        await model.runCorpusAnalysis { active in
                            try await analysis.execute(
                                session: active, sourceRevisionIDs: ids, sourceNumbers: numbers,
                                locale: locale)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isBusy || selectedIDs(snapshot).isEmpty)
                Text("cm.persisted-help").font(.caption).foregroundStyle(.secondary)
            }
            limits
        }
        .formStyle(.grouped)
        .disabled(model.isBusy)
    }

    private func groups(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        let ids = Set(selectedIDs(snapshot))
        return Section("cm.groups") {
            Text("cm.groups-help").font(.caption).foregroundStyle(.secondary)
            if analysis.tool == .similarity {
                TextField("cm.target-group", text: $analysis.draft.targetGroup)
                TextField("cm.reference-group", text: $analysis.draft.referenceGroup)
                Text("cm.similarity-groups-help").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("cm.group-assignments") {
                ForEach(
                    Array(snapshot.sources.enumerated()).filter {
                        ids.contains($0.element.sourceRevisionID)
                    }, id: \.element.sourceRevisionID
                ) { index, source in
                    VStack(alignment: .leading, spacing: 6) {
                        sourceLabel(index: index, id: source.sourceRevisionID)
                        TextField(
                            "cm.group-label",
                            text: Binding(
                                get: {
                                    analysis.draft.groupLabels[source.sourceRevisionID, default: ""]
                                },
                                set: { analysis.draft.groupLabels[source.sourceRevisionID] = $0 }))
                    }
                }
            }
            LabeledContent(
                "cm.group-order",
                value: analysis.groupNames(for: Array(ids)).joined(separator: " · "))
            if analysis.tool != .similarity {
                Text("cm.complete-groups-help").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var parameters: some View {
        if analysis.tool.usesCooccurrence {
            Section("cm.cooccurrence") {
                integer("cm.maximum-terms", value: $analysis.draft.maximumTerms)
                integer("cm.minimum-joint", value: $analysis.draft.minimumJointCount)
                integer("cm.maximum-pairs", value: $analysis.draft.maximumPairs)
                Text("cm.document-context").font(.caption).foregroundStyle(.secondary)
            }
        }
        if analysis.tool.usesWindow {
            Section("cm.window") {
                integer("cm.left-span", value: $analysis.draft.leftSpan)
                integer("cm.right-span", value: $analysis.draft.rightSpan)
                Toggle("cm.cross-sentences", isOn: $analysis.draft.crossesSentences)
                Toggle("cm.self-pairs", isOn: $analysis.draft.includesSelfPairs)
                Toggle("cm.inverse-distance", isOn: $analysis.draft.weightsByInverseDistance)
                integer("cm.minimum-joint", value: $analysis.draft.minimumJointCount)
                integer("cm.maximum-pairs", value: $analysis.draft.maximumPairs)
                integer("cm.maximum-positions", value: $analysis.draft.maximumPositions)
                if analysis.tool == .windowNetwork {
                    Toggle("cm.logdice-threshold", isOn: $analysis.draft.usesLogDiceThreshold)
                    if analysis.draft.usesLogDiceThreshold {
                        decimal("cm.minimum-logdice", value: $analysis.draft.minimumLogDice)
                    }
                    Toggle("cm.weighted-joint", isOn: $analysis.draft.usesWeightedJointCount)
                }
            }
        }
        if analysis.tool.isMultivariate {
            Section("cm.multivariate") {
                integer("cm.maximum-terms", value: $analysis.draft.maximumTerms)
                if analysis.tool == .pca {
                    Toggle("cm.scaled-pca", isOn: $analysis.draft.scaledPCA)
                }
                if analysis.tool == .lsa || analysis.tool == .nmf {
                    integer("cm.rank", value: $analysis.draft.rank)
                }
                if analysis.tool == .hierarchical || analysis.tool == .kmeans {
                    integer("cm.cluster-count", value: $analysis.draft.clusterCount)
                }
                if analysis.tool == .hierarchical {
                    Picker("cm.linkage", selection: $analysis.draft.linkage) {
                        ForEach(["single", "complete", "average", "ward"], id: \.self) { value in
                            Text(LocalizedStringKey("cm.linkage.\(value)")).tag(value)
                        }
                    }
                }
                if analysis.tool == .nmf || analysis.tool == .kmeans {
                    seedField
                    integer("cm.restarts", value: $analysis.draft.restarts)
                }
                Text("cm.multivariate-representation").font(.caption).foregroundStyle(.secondary)
            }
        }
        if analysis.tool.usesMetrics {
            Section("cm.metrics") {
                Picker("cm.first-metric", selection: $analysis.draft.firstMetric) {
                    ForEach(StudioCorpusMetricKind.allCases) { kind in
                        Text(LocalizedStringKey(kind.titleKey)).tag(kind)
                    }
                }
                if analysis.draft.firstMetric == .termFrequency {
                    TextField("cm.term", text: $analysis.draft.firstTerm)
                }
                if analysis.tool == .correlation || analysis.tool == .pairedMetrics {
                    Picker("cm.second-metric", selection: $analysis.draft.secondMetric) {
                        ForEach(StudioCorpusMetricKind.allCases) { kind in
                            Text(LocalizedStringKey(kind.titleKey)).tag(kind)
                        }
                    }
                    if analysis.draft.secondMetric == .termFrequency {
                        TextField("cm.term", text: $analysis.draft.secondTerm)
                    }
                }
                Text("cm.metric-help").font(.caption).foregroundStyle(.secondary)
            }
        }
        if analysis.tool == .groupMetrics {
            Section("cm.inference") {
                decimal("cm.confidence", value: $analysis.draft.confidenceLevel)
                integer("cm.bootstrap", value: $analysis.draft.bootstrapResamples)
                integer("cm.permutations", value: $analysis.draft.permutationCount)
                seedField
                DisclosureGroup("cm.contrasts") {
                    Text("cm.contrasts-help").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $analysis.draft.contrasts)
                        .font(.body.monospaced()).frame(minHeight: 90)
                        .accessibilityLabel("cm.contrasts")
                }
            }
        }
    }

    private var seedField: some View {
        LabeledContent("cm.seed") {
            TextField("cm.seed", value: $analysis.draft.seed, format: .number.grouping(.never))
                .multilineTextAlignment(.trailing)
        }
    }

    private var limits: some View {
        Section {
            DisclosureGroup("cm.profile-options") {
                integer("cm.diversity-window", value: $analysis.draft.diversityWindowSize)
                Text("cm.ngram-orders")
                ForEach(1...5, id: \.self) { n in
                    Toggle(
                        isOn: Binding(
                            get: { analysis.draft.ngramOrders.contains(n) },
                            set: {
                                if $0 {
                                    analysis.draft.ngramOrders.insert(n)
                                } else {
                                    analysis.draft.ngramOrders.remove(n)
                                }
                            }
                        )
                    ) { Text(n, format: .number) }
                }
                integer("cm.maximum-documents", value: $analysis.draft.maximumDocumentCount)
                integer("cm.maximum-bytes", value: $analysis.draft.maximumSourceBytes)
                integer("cm.maximum-vocabulary", value: $analysis.draft.maximumVocabularySize)
                integer("cm.maximum-ngrams", value: $analysis.draft.maximumDistinctNGrams)
                integer("cm.maximum-cells", value: $analysis.draft.maximumNonZeroCells)
                Text("cm.bounds-help").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var results: some View {
        if let output = analysis.output {
            Form {
                Section {
                    Text(LocalizedStringKey(output.tool.titleKey)).font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Label("cm.persisted", systemImage: "externaldrive.badge.checkmark")
                    Text("cm.caveat").foregroundStyle(.secondary).fixedSize(
                        horizontal: false, vertical: true)
                    LabeledContent("cm.effective-sources") {
                        Text(output.sourceRevisionIDs.count, format: .number)
                    }
                    if analysis.draft != output.draft {
                        Label("cm.changed-settings", systemImage: "info.circle")
                    }
                    if hasConvergenceWarning(output) {
                        Label("cm.not-converged", systemImage: "exclamationmark.triangle")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let snapshot = model.snapshot,
                        Set(selectedIDs(snapshot)) != Set(output.eligibleSourceRevisionIDs)
                    {
                        Label("cm.changed-scope", systemImage: "info.circle")
                    }
                    Button("cm.export", systemImage: "square.and.arrow.up") { showsExporter = true }
                }
                if !analysis.summary.isEmpty {
                    Section("cm.indicators") {
                        ForEach(analysis.summary) { field in
                            LabeledContent(fieldLabel(field.key), value: field.value).textSelection(
                                .enabled)
                        }
                    }
                }
                if !analysis.tables.isEmpty {
                    Section("cm.tables") {
                        Picker("cm.table", selection: $analysis.tableID) {
                            ForEach(analysis.tables) { table in
                                Text(fieldLabel(table.id)).tag(table.id)
                            }
                        }
                        if analysis.axisCount > 1 {
                            Stepper(value: $analysis.axis, in: 1...analysis.axisCount) {
                                Text("cm.axis \(analysis.axis)")
                            }
                            Text("cm.axis-help").font(.caption).foregroundStyle(.secondary)
                        }
                        TextField("cm.search", text: $analysis.search).textFieldStyle(
                            .roundedBorder)
                        LabeledContent("cm.matching-rows") {
                            Text(analysis.matchingCount, format: .number)
                        }
                        if let table = analysis.selectedTable {
                            resultTable(table)
                            if analysis.visibleRows.isEmpty {
                                ContentUnavailableView.search(text: analysis.search)
                            }
                            pagination
                        }
                    }
                }
                Section {
                    DisclosureGroup("cm.effective-request") {
                        ForEach(output.sourceRevisionIDs, id: \.self) { id in
                            HStack {
                                LabeledContent("cm.source", value: id).font(.caption.monospaced())
                                    .textSelection(.enabled)
                                Button("cm.open-source") { openSource(id) }.disabled(model.isBusy)
                            }
                        }
                        ForEach(output.parameters) { field in
                            LabeledContent(fieldLabel(field.key), value: field.value)
                                .textSelection(.enabled)
                        }
                        ForEach(Array(output.groupNames.enumerated()), id: \.offset) {
                            index, name in
                            LabeledContent(
                                name, value: output.groups[index].joined(separator: "\n")
                            )
                            .font(.caption.monospaced()).textSelection(.enabled)
                        }
                        if output.tool.usesMetrics {
                            LabeledContent(
                                "cm.first-metric",
                                value: String(
                                    localized: String.LocalizationValue(
                                        output.draft.firstMetric.titleKey), locale: locale))
                            if output.draft.firstMetric == .termFrequency {
                                LabeledContent("cm.term", value: output.draft.firstTerm)
                            }
                        }
                        if output.tool == .correlation || output.tool == .pairedMetrics {
                            LabeledContent(
                                "cm.second-metric",
                                value: String(
                                    localized: String.LocalizationValue(
                                        output.draft.secondMetric.titleKey), locale: locale))
                            if output.draft.secondMetric == .termFrequency {
                                LabeledContent("cm.term", value: output.draft.secondTerm)
                            }
                        }
                        if output.tool == .groupMetrics && !output.draft.contrasts.isEmpty {
                            LabeledContent("cm.contrasts", value: output.draft.contrasts)
                                .textSelection(.enabled)
                        }
                        Text("cm.effective-request-help").font(.caption).foregroundStyle(.secondary)
                    }
                    DisclosureGroup("cm.method-details") {
                        ForEach(analysis.methodDetails) { field in
                            LabeledContent(fieldLabel(field.key), value: field.value).font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView(
                "cm.result-empty.title", systemImage: "chart.bar.xaxis",
                description: Text("cm.result-empty.description"))
        }
    }

    private func resultTable(_ table: StudioCorpusMethodTable) -> some View {
        Table(analysis.visibleRows) {
            TableColumnForEach(Array(table.columns.enumerated()), id: \.offset) { index, key in
                TableColumn(fieldLabel(key)) { row in
                    if row.values.indices.contains(index) {
                        Text(row.values[index]).textSelection(.enabled)
                    }
                }
            }
            TableColumn("cm.actions") { row in
                HStack {
                    Button("cm.details") { selectedRow = row }
                    if let id = row.sourceRevisionID {
                        Button("cm.source") { openSource(id) }.disabled(model.isBusy)
                    }
                }
            }
        }
        .frame(minHeight: 240, idealHeight: 360)
    }

    private func hasConvergenceWarning(_ output: StudioCorpusMethodsOutput) -> Bool {
        switch output.payload {
        case let .multivariate(value): value.converged == false
        case let .lexicalNetwork(value):
            !value.pageRankConverged || !value.summary.eigenvectorConverged
        case let .windowNetwork(value): !value.summary.eigenvectorConverged
        case .association, .dispersion, .similarity, .collocations, .windowCollocations,
            .groupMetrics, .postHoc, .correlation, .paired:
            false
        }
    }

    private var pagination: some View {
        ViewThatFits(in: .horizontal) {
            HStack { pageControls }
            VStack(alignment: .leading, spacing: 10) { pageControls }
        }
    }

    @ViewBuilder private var pageControls: some View {
        Button("cm.first-page", systemImage: "backward.end") { analysis.showPage(0) }.disabled(
            analysis.page == 0)
        Button("cm.previous-page", systemImage: "chevron.backward") {
            analysis.showPage(analysis.page - 1)
        }.disabled(analysis.page == 0)
        LabeledContent("cm.page") {
            TextField(
                "cm.page",
                value: Binding(get: { analysis.page + 1 }, set: { analysis.showPage($0 - 1) }),
                format: .number
            )
            .frame(width: 70).textFieldStyle(.roundedBorder)
        }
        Text("/ \(analysis.pageCount, format: .number)")
        Button("cm.next-page", systemImage: "chevron.forward") {
            analysis.showPage(analysis.page + 1)
        }.disabled(analysis.page + 1 >= analysis.pageCount)
        Button("cm.last-page", systemImage: "forward.end") {
            analysis.showPage(analysis.pageCount - 1)
        }.disabled(analysis.page + 1 >= analysis.pageCount)
    }

    private func selectedIDs(_ snapshot: GlifiStudioProjectSnapshot) -> [String] {
        switch model.textAnalysisScope {
        case .allSources: snapshot.sources.map(\.sourceRevisionID).sorted()
        case .selectedSources: model.selectedTextAnalysisSourceRevisionIDs.sorted()
        }
    }

    private func sourceLabel(index: Int, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("workspace.source.ordinal \(index + 1)")
            Text(id).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }

    private func openSource(_ id: String) {
        Task {
            await model.runCorpusAnalysis { active in
                let text = try await active.sourceText(sourceRevisionID: id)
                let snapshot = try await active.snapshot()
                source = text
                showsSource = true
                return snapshot
            }
        }
    }

    private func fieldLabel(_ path: String) -> String {
        path.split(separator: ".").map { component in
            if Int(component) != nil { return String(component) }
            let key = "cm.field.\(component)"
            let value = String(localized: String.LocalizationValue(key), locale: locale)
            return value == key
                ? String(localized: "cm.field.unknown", locale: locale) : value
        }.joined(separator: " · ")
    }

    private func integer(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).multilineTextAlignment(.trailing)
        }
    }
    private func decimal(_ key: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).multilineTextAlignment(.trailing)
        }
    }
}

private struct CorpusMethodsJSONDocument: FileDocument {
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

#Preview("Raccolta · italiano") {
    StudioCorpusMethodsView(model: StudioHomeModel())
        .environment(\.locale, Locale(identifier: "it"))
        .frame(width: 1100, height: 760)
}

#Preview("Raccolta · scuro") {
    StudioCorpusMethodsView(model: StudioHomeModel())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "en"))
        .frame(width: 1100, height: 760)
}

#Preview("Raccolta · testo grande") {
    StudioCorpusMethodsView(model: StudioHomeModel())
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 420, height: 760)
}

#Preview("Raccolta · destra-sinistra") {
    StudioCorpusMethodsView(model: StudioHomeModel())
        .environment(\.layoutDirection, .rightToLeft)
        .frame(width: 420, height: 760)
}
