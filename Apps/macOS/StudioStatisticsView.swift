// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Provides native explicit-data statistical tools.
///
/// Scientific calculations and input parsing stay behind GlifiKit.
struct StudioStatisticsView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var statistics: StudioStatisticsModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var exportData: Data?
    @State private var exportFailed = false
    @State private var isPreparingExport = false
    @State private var exportTask: Task<Void, Never>?
    @State private var exportID = UUID()

    init(model: StudioHomeModel) {
        self.model = model
        statistics = model.statistics
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { geometry in
                if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                    HSplitView {
                        configuration.frame(minWidth: 300, idealWidth: 360, maxWidth: 460)
                        results.frame(minWidth: 380)
                    }
                } else {
                    TabView(selection: $statistics.pane) {
                        Tab(value: StudioStatisticsPane.configuration) {
                            configuration
                        } label: {
                            Text("statistics.configuration")
                        }
                        Tab(value: StudioStatisticsPane.results) {
                            results
                        } label: {
                            Text("statistics.results")
                        }
                    }
                    .tabViewStyle(.grouped)
                    .padding()
                }
            }
        }
        .navigationTitle("statistics.title")
        .task(id: locale) { await statistics.updatePresentationLocale(locale) }
        .onDisappear {
            exportTask?.cancel()
            exportID = UUID()
            exportTask = nil
            isPreparingExport = false
            exportData = nil
        }
        .fileExporter(
            isPresented: Binding(get: { exportData != nil }, set: { if !$0 { exportData = nil } }),
            document: exportData.map(StudioStatisticsExportDocument.init),
            contentType: .json, defaultFilename: "GlifiStudio-Statistics"
        ) { outcome in
            if case let .failure(error) = outcome,
                (error as? CocoaError)?.code != .userCancelled
            {
                exportFailed = true
            }
            exportData = nil
        }
        .alert("statistics.export-failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(statistics.titleKey))
                .font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text("statistics.introduction")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
    }

    private var configuration: some View {
        Form {
            Section("statistics.method") {
                StudioAnalysisRoleView(route: .statistics(statistics.operation))
                Picker("statistics.operation", selection: $statistics.operation) {
                    ForEach(GlifiStudioStatisticsOperation.allCases) { operation in
                        Text(LocalizedStringKey("statistics.operation.\(operation.rawValue)"))
                            .tag(operation)
                    }
                }
                .disabled(model.isBusy)
                Text("statistics.design-caveat").font(.callout).foregroundStyle(.secondary)
            }
            if statistics.operation.inputKind != .scalar {
                Section("statistics.input") {
                    Text(
                        LocalizedStringKey(
                            "statistics.input.\(statistics.operation.inputKind.rawValue)")
                    )
                    .font(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $statistics.input)
                        .font(.body.monospaced())
                        .frame(minHeight: 170)
                        .accessibilityLabel("statistics.input")
                    Text("statistics.input.format").font(.caption).foregroundStyle(.secondary)
                    Button("statistics.example", systemImage: "text.badge.plus") {
                        statistics.loadSyntheticExample()
                    }
                }
                .disabled(model.isBusy)
            }
            parameterSections
            Section {
                Button("statistics.run", systemImage: "play.fill") {
                    Task { await model.runCoreAnalysis { try await statistics.execute() } }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(
                    model.isBusy
                        || (statistics.operation.inputKind != .scalar
                            && statistics.input.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty)
                )
                if model.canCancelAnalysis {
                    Button("action.cancel-execution", role: .cancel) { model.cancelAnalysis() }
                }
                DisclosureGroup("statistics.limits") {
                    Text("statistics.limits.description").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder private var parameterSections: some View {
        if usesAlternative {
            Section("statistics.hypothesis") {
                Picker("statistics.alternative", selection: $statistics.parameters.alternative) {
                    ForEach(GlifiStudioStatisticsAlternative.allCases, id: \.rawValue) {
                        alternative in
                        Text(LocalizedStringKey("statistics.alternative.\(alternative.rawValue)"))
                            .tag(alternative)
                    }
                }
                if statistics.operation == .oneSampleT || statistics.operation == .pairedT {
                    numberField(
                        "statistics.hypothesized-mean",
                        value: $statistics.parameters.hypothesizedMean)
                }
            }
            .disabled(model.isBusy)
        }
        if usesConfidence {
            Section("statistics.interval") {
                numberField(
                    "statistics.confidence-level", value: $statistics.parameters.confidenceLevel)
                Text("statistics.confidence-help").font(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.isBusy)
        }
        if statistics.operation == .descriptive {
            Section("statistics.descriptive.parameters") {
                TextField("statistics.unit", text: $statistics.parameters.unitIdentifier)
                Toggle("statistics.sample-variance", isOn: $statistics.parameters.sampleVariance)
                TextField("statistics.quantiles", text: $statistics.probabilitiesDraft)
                Text("statistics.quantiles.help").font(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.isBusy)
        }
        if statistics.operation == .mannWhitney || statistics.operation == .wilcoxon
            || statistics.operation == .permutation
        {
            Section("statistics.computation") {
                Toggle("statistics.exact", isOn: $statistics.parameters.exact)
                if !statistics.parameters.exact && statistics.operation != .permutation {
                    Toggle(
                        "statistics.continuity", isOn: $statistics.parameters.continuityCorrection)
                }
                Text("statistics.exact-help").font(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.isBusy)
        }
        if usesResampling {
            Section("statistics.resampling") {
                integerField("statistics.resamples", value: $statistics.parameters.resampleCount)
                LabeledContent("statistics.seed") {
                    TextField(
                        "statistics.seed", value: $statistics.parameters.seed, format: .number
                    )
                    .multilineTextAlignment(.trailing)
                }
                if statistics.operation == .blockBootstrap {
                    integerField(
                        "statistics.block-length", value: $statistics.parameters.blockLength)
                    Text("statistics.block-help").font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(model.isBusy)
        }
        if statistics.operation == .alphaNumeric || statistics.operation == .alphaInterval {
            Section("statistics.agreement.parameters") {
                Picker(
                    "statistics.measurement-level",
                    selection: $statistics.parameters.measurementLevel
                ) {
                    ForEach(["nominal", "ordinal", "interval", "ratio"], id: \.self) { level in
                        Text(LocalizedStringKey("statistics.level.\(level)")).tag(level)
                    }
                }
                Text("statistics.agreement-help").font(.caption).foregroundStyle(.secondary)
            }
            .disabled(model.isBusy)
        }
        if statistics.operation == .plannedContrasts {
            Section("statistics.contrasts") {
                Text("statistics.contrasts.help").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $statistics.contrastsDraft).font(.body.monospaced()).frame(
                    minHeight: 100
                )
                .accessibilityLabel("statistics.contrasts")
            }.disabled(model.isBusy)
        }
        if statistics.operation.inputKind == .scalar {
            Section("statistics.scalar.parameters") {
                scalarParameters
            }
            .disabled(model.isBusy)
        }
    }

    @ViewBuilder private var scalarParameters: some View {
        switch statistics.operation {
        case .normalQuantile, .rangeQuantile, .tQuantile:
            numberField("statistics.probability", value: $statistics.parameters.probability)
        case .pearsonInterval:
            numberField("statistics.coefficient", value: $statistics.parameters.coefficient)
        case .epsilonSquared:
            numberField("statistics.corrected-h", value: $statistics.parameters.statistic)
        case .rankBiserial:
            numberField("statistics.u-first", value: $statistics.parameters.statistic)
        case .normalCDF, .normalDensity, .tPValue, .fPValue, .rangeCDF, .rangeTail:
            numberField("statistics.statistic", value: $statistics.parameters.statistic)
        case .descriptive, .welchT, .oneSampleT, .pairedT, .anova, .welchANOVA, .mannWhitney,
            .wilcoxon, .kruskalWallis, .pearson, .spearman, .spearmanExact, .cohenD, .hedgesG,
            .tukey, .gamesHowell, .dunn, .bonferroni, .benjaminiHochberg, .bootstrapMean,
            .blockBootstrap, .permutation, .contingency, .fisherExact, .monteCarloChiSquare,
            .cohenKappa, .alphaNominal, .alphaNumeric, .fleissKappa, .alphaInterval, .bootstrapBCa,
            .plannedContrasts:
            EmptyView()
        }
        if [.rankBiserial, .epsilonSquared, .pearsonInterval].contains(statistics.operation) {
            integerField("statistics.first-count", value: $statistics.parameters.firstCount)
        }
        if statistics.operation == .rankBiserial {
            integerField("statistics.second-count", value: $statistics.parameters.secondCount)
        }
        if [.tPValue, .fPValue, .rangeCDF, .rangeTail, .rangeQuantile, .tQuantile].contains(
            statistics.operation)
        {
            numberField(
                "statistics.degrees-of-freedom", value: $statistics.parameters.degreesOfFreedom)
        }
        if statistics.operation == .fPValue {
            numberField(
                "statistics.second-df", value: $statistics.parameters.secondDegreesOfFreedom)
        }
        if [.rangeCDF, .rangeTail, .rangeQuantile].contains(statistics.operation) {
            integerField("statistics.group-count", value: $statistics.parameters.groupCount)
        }
    }

    private var results: some View {
        Form {
            if let result = statistics.result {
                Section("statistics.results") {
                    Text(
                        LocalizedStringKey(
                            "statistics.operation.\(result.request.operation.rawValue)")
                    )
                    .font(.headline)
                    Label("statistics.session-only", systemImage: "clock")
                        .foregroundStyle(.secondary)
                    if statistics.isDraftChanged {
                        Label("statistics.draft-changed", systemImage: "info.circle")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if [.tukey, .gamesHowell, .dunn, .plannedContrasts].contains(
                        result.request.operation)
                    {
                        Text("statistics.posthoc-caveat").font(.callout).foregroundStyle(.secondary)
                    }
                    Text("statistics.result-caveat").font(.callout).foregroundStyle(.secondary)
                    ForEach(Array(result.metrics.enumerated()), id: \.offset) { _, metric in
                        LabeledContent(LocalizedStringKey(metric.key)) {
                            Text(formatted(metric.value)).monospacedDigit().textSelection(.enabled)
                        }
                    }
                }
                if !result.rows.isEmpty { resultTable(result) }
                Section("statistics.provenance") {
                    LabeledContent("statistics.method-identifier", value: result.methodIdentifier)
                    LabeledContent("statistics.request-digest", value: result.requestDigest)
                        .font(.caption.monospaced()).textSelection(.enabled)
                    Text("statistics.validation-status").font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("statistics.captured-input") {
                        capturedRequest(result.request)
                    }
                    Button("statistics.export", systemImage: "square.and.arrow.up") {
                        prepareExport(result)
                    }
                    .disabled(isPreparingExport)
                }
            } else {
                ContentUnavailableView(
                    "statistics.empty.title", systemImage: "chart.bar.xaxis",
                    description: Text("statistics.empty.description"))
            }
        }
        .formStyle(.grouped)
    }

    private func resultTable(_ result: GlifiStudioStatisticsResult) -> some View {
        Section("statistics.table") {
            TextField("statistics.filter", text: $statistics.search)
                .textFieldStyle(.roundedBorder)
            Table(statistics.visibleRows) {
                TableColumnForEach(Array(result.columns.enumerated()), id: \.offset) { column in
                    TableColumn(LocalizedStringKey(column.element)) { row in
                        if row.values.indices.contains(column.offset) {
                            Text(formatted(row.values[column.offset]))
                                .monospacedDigit().textSelection(.enabled)
                        }
                    }
                }
            }
            .frame(minHeight: 220, idealHeight: 380)
            ViewThatFits(in: .horizontal) {
                HStack { pagination }
                VStack(alignment: .leading, spacing: 12) { pagination }
            }
            Text("statistics.table.count \(statistics.matchingRowCount)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var pagination: some View {
        Button("statistics.first-page", systemImage: "backward.end") { statistics.showPage(0) }
            .disabled(statistics.page == 0)
        Button("statistics.previous-page", systemImage: "chevron.backward") {
            statistics.showPage(statistics.page - 1)
        }.disabled(statistics.page == 0)
        Text("statistics.page \(statistics.page + 1) / \(statistics.pageCount)").monospacedDigit()
        Button("statistics.next-page", systemImage: "chevron.forward") {
            statistics.showPage(statistics.page + 1)
        }.disabled(statistics.page + 1 >= statistics.pageCount)
        Button("statistics.last-page", systemImage: "forward.end") {
            statistics.showPage(statistics.pageCount - 1)
        }.disabled(statistics.page + 1 >= statistics.pageCount)
    }

    private func capturedRequest(_ request: GlifiStudioStatisticsRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("statistics.request-captured").font(.caption).foregroundStyle(.secondary)
            if !statistics.capturedInputRows.isEmpty {
                Table(statistics.visibleInputRows) {
                    TableColumn("statistics.column.row") { row in Text(formatted(row.values[0])) }
                    TableColumn("statistics.column.column") { row in Text(formatted(row.values[1]))
                    }
                    TableColumn("statistics.column.value") { row in
                        Text(formatted(row.values[2])).textSelection(.enabled)
                    }
                }.frame(minHeight: 180, idealHeight: 300)
                ViewThatFits(in: .horizontal) {
                    HStack { inputPagination }
                    VStack(alignment: .leading, spacing: 12) { inputPagination }
                }
            }
            ForEach(Array(parameterSnapshot(request.parameters).enumerated()), id: \.offset) {
                _, parameter in
                LabeledContent(LocalizedStringKey(parameter.0)) {
                    Text(formatted(parameter.1)).textSelection(.enabled)
                }
            }
            Text("statistics.request-fields-help").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var inputPagination: some View {
        Button("statistics.first-page") { statistics.showInputPage(0) }.disabled(
            statistics.inputPage == 0)
        Button("statistics.previous-page") { statistics.showInputPage(statistics.inputPage - 1) }
            .disabled(statistics.inputPage == 0)
        TextField(
            "statistics.input-page",
            value: Binding(
                get: { statistics.inputPage + 1 }, set: { statistics.showInputPage($0 - 1) }),
            format: .number
        )
        .frame(maxWidth: 90)
        Text("/ \(statistics.inputPageCount, format: .number)")
        Button("statistics.next-page") { statistics.showInputPage(statistics.inputPage + 1) }
            .disabled(statistics.inputPage + 1 >= statistics.inputPageCount)
        Button("statistics.last-page") { statistics.showInputPage(statistics.inputPageCount - 1) }
            .disabled(statistics.inputPage + 1 >= statistics.inputPageCount)
    }

    private func parameterSnapshot(_ parameters: GlifiStudioStatisticsParameters) -> [(
        String, GlifiStudioStatisticsValue
    )] {
        [
            (
                "statistics.alternative",
                .text(
                    String(
                        localized: String.LocalizationValue(
                            "statistics.alternative.\(parameters.alternative.rawValue)"),
                        locale: locale))
            ),
            (
                "statistics.exact",
                .text(
                    String(
                        localized: String.LocalizationValue(
                            parameters.exact ? "common.yes" : "common.no"), locale: locale))
            ),
            (
                "statistics.continuity",
                .text(
                    String(
                        localized: String.LocalizationValue(
                            parameters.continuityCorrection ? "common.yes" : "common.no"),
                        locale: locale))
            ),
            ("statistics.confidence-level", .number(parameters.confidenceLevel)),
            ("statistics.hypothesized-mean", .number(parameters.hypothesizedMean)),
            (
                "statistics.quantiles",
                .text(
                    parameters.probabilities.map { formatted(.number($0)) }.joined(separator: "; "))
            ),
            ("statistics.unit", .text(parameters.unitIdentifier)),
            (
                "statistics.sample-variance",
                .text(
                    String(
                        localized: String.LocalizationValue(
                            parameters.sampleVariance ? "common.yes" : "common.no"), locale: locale)
                )
            ),
            ("statistics.resamples", .integer(parameters.resampleCount)),
            ("statistics.seed", .text(String(parameters.seed))),
            ("statistics.block-length", .integer(parameters.blockLength)),
            (
                "statistics.measurement-level",
                .text(
                    String(
                        localized: String.LocalizationValue(
                            "statistics.level.\(parameters.measurementLevel)"), locale: locale))
            ),
            ("statistics.statistic", .number(parameters.statistic)),
            ("statistics.probability", .number(parameters.probability)),
            ("statistics.degrees-of-freedom", .number(parameters.degreesOfFreedom)),
            ("statistics.second-df", .number(parameters.secondDegreesOfFreedom)),
            ("statistics.group-count", .integer(parameters.groupCount)),
            ("statistics.first-count", .integer(parameters.firstCount)),
            ("statistics.second-count", .integer(parameters.secondCount)),
            ("statistics.coefficient", .number(parameters.coefficient)),
            (
                "statistics.contrasts",
                .text(
                    parameters.contrasts.map {
                        $0.map { formatted(.number($0)) }.joined(separator: " ")
                    }.joined(separator: "\n"))
            ),
        ]
    }

    private func prepareExport(_ result: GlifiStudioStatisticsResult) {
        exportTask?.cancel()
        let token = UUID()
        exportID = token
        isPreparingExport = true
        exportTask = Task {
            defer { if token == exportID { isPreparingExport = false } }
            do {
                let data = try await StudioStatisticsModel.exportData(for: result)
                guard !Task.isCancelled, token == exportID else { return }
                exportData = data
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled, token == exportID { exportFailed = true }
            }
        }
    }

    private func numberField(_ key: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).multilineTextAlignment(.trailing)
        }
    }
    private func integerField(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).multilineTextAlignment(.trailing)
        }
    }

    private func formatted(_ value: GlifiStudioStatisticsValue) -> String {
        StudioStatisticsPresentation.formatted(value, locale: locale)
    }

    private var usesAlternative: Bool {
        [
            .welchT, .oneSampleT, .pairedT, .mannWhitney, .wilcoxon, .pearson, .spearman,
            .spearmanExact, .permutation, .fisherExact, .tPValue,
        ].contains(statistics.operation)
    }
    private var usesConfidence: Bool {
        [
            .hedgesG, .pearsonInterval, .tukey, .plannedContrasts, .bootstrapMean, .bootstrapBCa,
            .blockBootstrap, .alphaInterval,
        ]
        .contains(statistics.operation)
    }
    private var usesResampling: Bool {
        [.bootstrapMean, .bootstrapBCa, .blockBootstrap, .monteCarloChiSquare, .alphaInterval]
            .contains(
                statistics.operation)
            || (statistics.operation == .permutation && !statistics.parameters.exact)
    }
}

private struct StudioStatisticsExportDocument: FileDocument {
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

private struct StudioStatisticsPreview: View {
    @State private var model = StudioHomeModel()
    var body: some View {
        StudioStatisticsView(model: model)
            .task { model.statistics.loadSyntheticExample() }
    }
}

#Preview("Statistiche · chiaro") {
    StudioStatisticsPreview().environment(\.locale, Locale(identifier: "it"))
        .frame(width: 1080, height: 760)
}

#Preview("Statistiche · scuro") {
    StudioStatisticsPreview().preferredColorScheme(.dark)
        .frame(width: 1080, height: 760)
}

#Preview("Statistiche · testo grande") {
    StudioStatisticsPreview().environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.locale, Locale(identifier: "en"))
        .frame(width: 420, height: 760)
}

#Preview("Statistiche · destra-sinistra") {
    StudioStatisticsPreview().environment(\.layoutDirection, .rightToLeft)
        .frame(width: 420, height: 760)
}
