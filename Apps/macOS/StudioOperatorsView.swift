// SPDX-License-Identifier: BSD-3-Clause

import Charts
import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Explicit expert inputs, separate from the document-driven research workflows.
struct StudioOperatorsView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var operators: StudioOperatorsModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var showsResults = false
    @State private var exportDocument: StudioTextExportDocument?
    @State private var exportFailed = false
    @State private var preparingExport = false
    @State private var exportTask: Task<Void, Never>?
    @State private var exportID = UUID()

    init(model: StudioHomeModel) {
        self.model = model
        operators = model.operators
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                HSplitView {
                    configuration.frame(minWidth: 300, idealWidth: 360, maxWidth: 440)
                    results.frame(minWidth: 360)
                }
            } else {
                TabView(selection: $showsResults) {
                    Tab(value: false) {
                        configuration
                    } label: {
                        Text("text-analysis.workspace.configuration")
                    }
                    Tab(value: true) {
                        results
                    } label: {
                        Text("text-analysis.workspace.results")
                    }
                }
                .tabViewStyle(.grouped)
                .padding()
            }
        }
        .navigationTitle("operators.title")
        .onChange(of: operators.request.operation) { _, _ in showsResults = false }
        .onChange(of: operators.request.communityMethod) { _, _ in showsResults = false }
        .onChange(of: operators.request.layoutMethod) { _, _ in showsResults = false }
        .onChange(of: operators.selectedTable) { _, _ in operators.page = 0 }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument, contentType: .json,
            defaultFilename: "GlifiStudio-CoreOperator"
        ) { result in
            if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
                exportFailed = true
            }
            exportDocument = nil
        }
        .alert("operators.export-failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
        .onDisappear {
            exportID = UUID()
            exportTask?.cancel()
            exportTask = nil
            preparingExport = false
        }
    }

    private var configuration: some View {
        Form {
            Section {
                Text("operators.introduction").foregroundStyle(.secondary)
                Picker("operators.method", selection: $operators.request.operation) {
                    ForEach(["matrix", "similarity", "graph", "lexical"], id: \.self) { family in
                        Section(StudioLocalization.key("operators.family.\(family)")) {
                            ForEach(
                                GlifiStudioCoreOperator.allCases.filter { $0.family == family },
                                id: \.self
                            ) { method in
                                Text(StudioLocalization.key("operators.method.\(method.rawValue)"))
                                    .tag(
                                        method)
                            }
                        }
                    }
                }
                Text(
                    StudioLocalization.key(
                        "operators.family.\(operators.request.operation.family).help")
                )
                .font(.callout).foregroundStyle(.secondary)
            }
            inputSection
            parameterSection
            Section {
                Button("operators.run", systemImage: "play.fill") {
                    Task {
                        await model.runCoreAnalysis { try await operators.execute() }
                        if model.lastFailure == nil { showsResults = true }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                Button("operators.example", systemImage: "doc.badge.plus") {
                    operators.loadSyntheticExample()
                }
                Text("operators.limits").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.isBusy)
    }

    @ViewBuilder private var inputSection: some View {
        switch operators.request.operation.family {
        case "graph":
            Section("operators.nodes") {
                editor("operators.nodes", text: $operators.request.nodes, height: 100)
            }
            Section("operators.edges") {
                editor("operators.edges", text: $operators.request.edges, height: 140)
                Text("operators.edges.help").font(.caption).foregroundStyle(.secondary)
                if operators.request.operation == .minimumSpanningForest {
                    Text("operators.forest-semantics").font(.caption).foregroundStyle(.secondary)
                }
                if operators.request.operation == .graphLayout
                    && operators.request.usesInitialPositions
                {
                    editor(
                        "operators.initial-positions", text: $operators.request.numbers, height: 140
                    )
                    Text("operators.initial-positions.help").font(.caption).foregroundStyle(
                        .secondary)
                }
            }
        case "lexical":
            Section("operators.documents") {
                editor("operators.documents", text: $operators.request.documents, height: 180)
                TextField("operators.checkpoints", text: $operators.request.checkpoints)
                Text("operators.documents.help").font(.caption).foregroundStyle(.secondary)
            }
        default:
            if [.jaccard, .dice, .simpson].contains(operators.request.operation) {
                Section("operators.set-input") {
                    editor("operators.first-set", text: $operators.request.firstSet, height: 90)
                    editor("operators.second-set", text: $operators.request.secondSet, height: 90)
                    Text("operators.set-input.help").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Section("operators.numeric-input") {
                    editor("operators.numeric-input", text: $operators.request.numbers, height: 200)
                    Text("operators.numeric-help").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var parameterSection: some View {
        Section {
            DisclosureGroup("operators.parameters") {
                switch operators.request.operation {
                case .truncatedSVD:
                    integer("operators.rank", value: $operators.request.rank)
                    integer("operators.oversampling", value: $operators.request.oversampling)
                    iterativeParameters
                case .pca:
                    Toggle("operators.scaled", isOn: $operators.request.scaled)
                case .lsa:
                    integer("operators.rank", value: $operators.request.rank)
                case .nmf:
                    integer("operators.rank", value: $operators.request.rank)
                    integer("operators.restarts", value: $operators.request.restarts)
                    iterativeParameters
                case .kMeans:
                    integer("operators.cluster-count", value: $operators.request.clusterCount)
                    integer("operators.restarts", value: $operators.request.restarts)
                    seedField
                    integer("operators.iterations", value: $operators.request.maximumIterations)
                case .hacCutCount, .hacCutHeight:
                    Picker("operators.linkage", selection: $operators.request.linkage) {
                        ForEach(["single", "complete", "average", "ward"], id: \.self) {
                            Text(StudioLocalization.key("operators.linkage.\($0)")).tag($0)
                        }
                    }
                    if operators.request.operation == .hacCutCount {
                        integer("operators.cluster-count", value: $operators.request.clusterCount)
                    } else {
                        decimal("operators.maximum-height", value: $operators.request.maximumHeight)
                    }
                case .silhouette, .modularity:
                    TextField("operators.assignments", text: $operators.request.assignments)
                    Text("operators.assignments.help").font(.caption).foregroundStyle(.secondary)
                case .distances:
                    Picker("operators.distance", selection: $operators.request.distance) {
                        ForEach(
                            ["jaccard", "dice", "cosine", "euclidean", "manhattan", "simpson"],
                            id: \.self
                        ) { Text(StudioLocalization.key("operators.distance.\($0)")).tag($0) }
                    }
                case .pageRank:
                    decimal("operators.damping", value: $operators.request.damping)
                    decimal("operators.tolerance", value: $operators.request.tolerance)
                    integer("operators.iterations", value: $operators.request.maximumIterations)
                case .eigenvector:
                    decimal("operators.tolerance", value: $operators.request.tolerance)
                    integer("operators.iterations", value: $operators.request.maximumIterations)
                case .lidstone:
                    decimal("operators.alpha", value: $operators.request.alpha)
                case .zipfFit:
                    integer("operators.first-rank", value: $operators.request.firstRank)
                    Toggle(
                        "operators.last-observed-rank",
                        isOn: Binding(
                            get: { operators.request.lastRank == nil },
                            set: {
                                operators.request.lastRank =
                                    $0 ? nil : max(operators.request.firstRank, 2)
                            }))
                    if operators.request.lastRank != nil {
                        integer(
                            "operators.last-rank",
                            value: Binding(
                                get: { operators.request.lastRank ?? 2 },
                                set: { operators.request.lastRank = $0 }))
                    }
                case .communities:
                    Picker(
                        "operators.community-method", selection: $operators.request.communityMethod
                    ) {
                        ForEach(GlifiStudioGraphCommunityMethod.allCases, id: \.self) { method in
                            Text(
                                StudioLocalization.key(
                                    "operators.community-method.\(method.rawValue)")
                            ).tag(method.rawValue)
                        }
                    }
                    decimal("operators.resolution", value: $operators.request.resolution)
                    if operators.request.communityMethod == "walktrap" {
                        integer("operators.walk-length", value: $operators.request.walkLength)
                    }
                    Text("operators.community-semantics").font(.caption).foregroundStyle(.secondary)
                case .graphLayout:
                    Picker("operators.layout-method", selection: $operators.request.layoutMethod) {
                        ForEach(GlifiStudioGraphLayoutMethod.allCases, id: \.self) { method in
                            Text(
                                StudioLocalization.key("operators.layout-method.\(method.rawValue)")
                            )
                            .tag(method.rawValue)
                        }
                    }
                    seedField
                    integer("operators.iterations", value: $operators.request.maximumIterations)
                    decimal("operators.tolerance", value: $operators.request.tolerance)
                    Toggle(
                        "operators.use-initial-positions",
                        isOn: $operators.request.usesInitialPositions)
                    Text("operators.layout-semantics").font(.caption).foregroundStyle(.secondary)
                case .minimumSpanningForest:
                    Text("operators.forest-semantics").font(.caption).foregroundStyle(.secondary)
                case .svd, .transformCounts, .transformBinary, .transformPerThousand,
                    .transformTFIDF, .transpose, .cosine, .euclidean, .manhattan, .jaccard,
                    .dice, .simpson, .weightedJaccard, .multisetDice, .kl, .jensenShannon,
                    .jensenShannonDistance, .hellinger, .degree, .betweenness, .harmonicCloseness,
                    .weightedBetweenness, .weightedCloseness, .weakComponents, .strongComponents,
                    .louvain, .lexicalObservation, .heapsFit:
                    Text("operators.no-additional-parameters").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var iterativeParameters: some View {
        Group {
            seedField
            decimal("operators.tolerance", value: $operators.request.tolerance)
            integer("operators.iterations", value: $operators.request.maximumIterations)
        }
    }

    private var seedField: some View {
        TextField("operators.seed", value: $operators.request.seed, format: .number)
    }

    private var results: some View {
        Form {
            if let result = operators.result {
                Section {
                    Text(
                        StudioLocalization.key(
                            "operators.method.\(result.request.operation.rawValue)")
                    )
                    .font(.headline).accessibilityAddTraits(.isHeader)
                    Label("operators.session-only", systemImage: "clock")
                    if operators.request.effective != result.request {
                        Label("operators.draft-changed", systemImage: "info.circle")
                    }
                    if result.tables.contains(where: {
                        $0.rows.contains([
                            .localized("operators.converged"),
                            .localized("operators.boolean.false"),
                        ])
                    }) {
                        Label("operators.not-converged", systemImage: "exclamationmark.triangle")
                    }
                    Picker("operators.result-table", selection: $operators.selectedTable) {
                        ForEach(Array(result.tables.enumerated()), id: \.offset) { index, table in
                            Text(LocalizedStringKey(table.titleKey)).tag(index)
                        }
                    }
                    if let preview = operators.graphPreview {
                        graphPreview(preview)
                        Text("operators.layout-semantics").font(.caption).foregroundStyle(
                            .secondary)
                    } else if result.request.operation == .graphLayout {
                        Text("operators.preview-unavailable").font(.caption).foregroundStyle(
                            .secondary)
                    }
                    if let table = operators.table {
                        Text("operators.row-count \(table.rows.count)")
                        operatorTable(table)
                        Text("operators.indices-help").font(.caption).foregroundStyle(.secondary)
                        pageControls
                    }
                }
                Section("operators.method-details") {
                    Text("operators.caveat").foregroundStyle(.secondary)
                    ForEach(result.methodIdentifiers, id: \.self) {
                        Text($0).font(.caption.monospaced()).textSelection(.enabled)
                    }
                    Text(StudioLocalization.key("advanced.validation.\(result.validationStatus)"))
                    if result.request.operation.family == "graph" {
                        Text("operators.graph-semantics").font(.caption)
                        if result.request.operation == .communities {
                            Text("operators.community-semantics").font(.caption)
                        }
                        if result.request.operation == .minimumSpanningForest {
                            Text("operators.forest-semantics").font(.caption)
                        }
                    }
                    Button("operators.export", systemImage: "square.and.arrow.up") {
                        let identifier = UUID()
                        exportID = identifier
                        exportTask = Task { await prepareExport(result, identifier: identifier) }
                    }
                    .disabled(preparingExport)
                    if preparingExport { ProgressView("lexical-laws.export.preparing") }
                }
                DisclosureGroup("operators.effective-input") {
                    effectiveInput(result.request)
                    effectiveParameters(result.request)
                }
            } else {
                ContentUnavailableView(
                    "operators.empty", systemImage: "function",
                    description: Text("operators.empty.description"))
            }
        }
        .formStyle(.grouped)
    }

    private func operatorTable(_ table: GlifiStudioOperatorTable) -> some View {
        Table(operators.visibleRows) {
            TableColumnForEach(Array(table.columns.enumerated()), id: \.offset) { index, key in
                TableColumn(LocalizedStringKey(key)) { row in
                    if row.values.indices.contains(index) {
                        cell(row.values[index]).textSelection(.enabled)
                    }
                }
            }
        }
        .frame(minHeight: 180, idealHeight: 320)
    }

    @ViewBuilder private func effectiveText(_ key: LocalizedStringKey, _ value: String) -> some View
    {
        if !value.isEmpty {
            LabeledContent(key) {
                VStack(alignment: .leading) {
                    Text(String(value.prefix(8_192))).font(.body.monospaced()).textSelection(
                        .enabled)
                    if value.count > 8_192 {
                        Text("operators.input-preview-limit").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder private func effectiveInput(_ request: GlifiStudioCoreOperatorRequest) -> some View
    {
        switch request.operation.family {
        case "graph":
            effectiveText("operators.nodes", request.nodes)
            effectiveText("operators.edges", request.edges)
            if request.operation == .graphLayout && request.usesInitialPositions {
                effectiveText("operators.initial-positions", request.numbers)
            }
        case "lexical":
            effectiveText("operators.documents", request.documents)
            effectiveText("operators.checkpoints", request.checkpoints)
        default:
            if [.jaccard, .dice, .simpson].contains(request.operation) {
                effectiveText("operators.first-set", request.firstSet)
                effectiveText("operators.second-set", request.secondSet)
            } else {
                effectiveText("operators.numeric-input", request.numbers)
            }
        }
    }

    @ViewBuilder private func effectiveParameters(_ request: GlifiStudioCoreOperatorRequest)
        -> some View
    {
        switch request.operation {
        case .truncatedSVD, .nmf:
            LabeledContent("operators.rank") { Text(request.rank, format: .number) }
            if request.operation == .truncatedSVD {
                LabeledContent("operators.oversampling") {
                    Text(request.oversampling, format: .number)
                }
            } else {
                LabeledContent("operators.restarts") { Text(request.restarts, format: .number) }
            }
            LabeledContent("operators.seed") { Text(request.seed, format: .number) }
            LabeledContent("operators.tolerance") { Text(request.tolerance, format: .number) }
            LabeledContent("operators.iterations") {
                Text(request.maximumIterations, format: .number)
            }
        case .pca:
            LabeledContent("operators.scaled") {
                Text(StudioLocalization.key("operators.boolean.\(String(request.scaled))"))
            }
        case .lsa:
            LabeledContent("operators.rank") { Text(request.rank, format: .number) }
        case .kMeans:
            LabeledContent("operators.cluster-count") {
                Text(request.clusterCount, format: .number)
            }
            LabeledContent("operators.restarts") { Text(request.restarts, format: .number) }
            LabeledContent("operators.seed") { Text(request.seed, format: .number) }
            LabeledContent("operators.iterations") {
                Text(request.maximumIterations, format: .number)
            }
        case .hacCutCount, .hacCutHeight:
            LabeledContent("operators.linkage") {
                Text(StudioLocalization.key("operators.linkage.\(request.linkage)"))
            }
            if request.operation == .hacCutCount {
                LabeledContent("operators.cluster-count") {
                    Text(request.clusterCount, format: .number)
                }
            } else {
                LabeledContent("operators.maximum-height") {
                    Text(request.maximumHeight, format: .number)
                }
            }
        case .silhouette, .modularity:
            effectiveText("operators.assignments", request.assignments)
        case .distances:
            LabeledContent("operators.distance") {
                Text(StudioLocalization.key("operators.distance.\(request.distance)"))
            }
        case .pageRank, .eigenvector:
            if request.operation == .pageRank {
                LabeledContent("operators.damping") { Text(request.damping, format: .number) }
            }
            LabeledContent("operators.tolerance") { Text(request.tolerance, format: .number) }
            LabeledContent("operators.iterations") {
                Text(request.maximumIterations, format: .number)
            }
        case .communities:
            LabeledContent("operators.community-method") {
                Text(
                    StudioLocalization.key("operators.community-method.\(request.communityMethod)"))
            }
            LabeledContent("operators.resolution") { Text(request.resolution, format: .number) }
            if request.communityMethod == "walktrap" {
                LabeledContent("operators.walk-length") {
                    Text(request.walkLength, format: .number)
                }
            }
        case .graphLayout:
            LabeledContent("operators.layout-method") {
                Text(StudioLocalization.key("operators.layout-method.\(request.layoutMethod)"))
            }
            LabeledContent("operators.seed") { Text(request.seed, format: .number) }
            LabeledContent("operators.iterations") {
                Text(request.maximumIterations, format: .number)
            }
            LabeledContent("operators.tolerance") { Text(request.tolerance, format: .number) }
        case .minimumSpanningForest: EmptyView()
        case .lidstone:
            LabeledContent("operators.alpha") { Text(request.alpha, format: .number) }
        case .zipfFit:
            LabeledContent("operators.first-rank") { Text(request.firstRank, format: .number) }
            LabeledContent("operators.last-rank") {
                if let last = request.lastRank {
                    Text(last, format: .number)
                } else {
                    Text("operators.last-observed-rank")
                }
            }
        case .svd, .transformCounts, .transformBinary, .transformPerThousand, .transformTFIDF,
            .transpose, .cosine, .euclidean, .manhattan, .jaccard, .dice, .simpson,
            .weightedJaccard,
            .multisetDice, .kl, .jensenShannon, .jensenShannonDistance, .hellinger, .degree,
            .betweenness, .harmonicCloseness, .weightedBetweenness, .weightedCloseness,
            .weakComponents, .strongComponents, .louvain, .lexicalObservation, .heapsFit:
            EmptyView()
        }
    }

    private func graphPreview(_ preview: StudioOperatorGraphPreview) -> some View {
        Chart {
            ForEach(preview.edges) { edge in
                LineMark(
                    x: .value("X", edge.source.x), y: .value("Y", edge.source.y),
                    series: .value(String(localized: "operators.edge", locale: locale), edge.id)
                )
                .foregroundStyle(.secondary.opacity(0.5))
                LineMark(
                    x: .value("X", edge.target.x), y: .value("Y", edge.target.y),
                    series: .value(String(localized: "operators.edge", locale: locale), edge.id)
                )
                .foregroundStyle(.secondary.opacity(0.5))
            }
            ForEach(preview.points) { point in
                PointMark(x: .value("X", point.x), y: .value("Y", point.y))
                    .symbolSize(28).foregroundStyle(.tint)
                    .accessibilityLabel(Text(point.id))
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: preview.domain).chartYScale(domain: preview.domain)
        .chartPlotStyle { plot in plot.aspectRatio(1, contentMode: .fit) }
        .frame(minHeight: 240, idealHeight: 340, maxHeight: 420)
        .accessibilityLabel("operators.positions")
    }

    private var pageControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack { pagingButtons }
            VStack(alignment: .leading) { pagingButtons }
        }
    }

    @ViewBuilder private var pagingButtons: some View {
        Button("advanced.first-page", systemImage: "backward.end") { operators.showPage(0) }
            .disabled(operators.page == 0)
        Button("advanced.previous-page", systemImage: "chevron.backward") {
            operators.showPage(operators.page - 1)
        }.disabled(operators.page == 0)
        Text("operators.page \(operators.page + 1) \(operators.pageCount)")
        Button("advanced.next-page", systemImage: "chevron.forward") {
            operators.showPage(operators.page + 1)
        }.disabled(operators.page + 1 >= operators.pageCount)
        Button("advanced.last-page", systemImage: "forward.end") {
            operators.showPage(operators.pageCount - 1)
        }.disabled(operators.page + 1 >= operators.pageCount)
    }

    @ViewBuilder private func cell(_ value: GlifiStudioOperatorCell) -> some View {
        switch value {
        case let .number(number): Text(number, format: .number.precision(.significantDigits(10)))
        case let .integer(number): Text(number, format: .number)
        case let .text(text): Text(text)
        case let .localized(key): Text(LocalizedStringKey(key))
        case let .nonFinite(kind): Text(StudioLocalization.key("operators.nonfinite.\(kind)"))
        }
    }

    private func editor(_ key: LocalizedStringKey, text: Binding<String>, height: CGFloat)
        -> some View
    {
        TextEditor(text: text).font(.body.monospaced()).frame(minHeight: height).accessibilityLabel(
            key)
    }

    private func integer(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        TextField(key, value: value, format: .number)
    }

    private func decimal(_ key: LocalizedStringKey, value: Binding<Double>) -> some View {
        TextField(key, value: value, format: .number)
    }

    private func prepareExport(_ result: GlifiStudioCoreOperatorResult, identifier: UUID) async {
        preparingExport = true
        defer {
            if exportID == identifier {
                preparingExport = false
                exportTask = nil
            }
        }
        do {
            let data = try await Self.encoded(result)
            guard exportID == identifier, !Task.isCancelled else { return }
            exportDocument = StudioTextExportDocument(
                text: String(decoding: data, as: UTF8.self), contentType: .json)
        } catch is CancellationError { return } catch {
            if exportID == identifier { exportFailed = true }
        }
    }

    @concurrent private static func encoded(_ result: GlifiStudioCoreOperatorResult) async throws
        -> Data
    {
        try Task.checkCancellation()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        try Task.checkCancellation()
        return data
    }
}

#Preview("Operatori · italiano") {
    StudioOperatorsView(model: StudioHomeModel())
        .environment(\.locale, Locale(identifier: "it"))
        .frame(width: 1100, height: 760)
}

#Preview("Operatori · testo grande e scuro") {
    StudioOperatorsView(model: StudioHomeModel())
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .frame(width: 480, height: 780)
}

#Preview("Operatori · destra-sinistra") {
    StudioOperatorsView(model: StudioHomeModel())
        .environment(\.layoutDirection, .rightToLeft)
        .frame(width: 480, height: 780)
}
