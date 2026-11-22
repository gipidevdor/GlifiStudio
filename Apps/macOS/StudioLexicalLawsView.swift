// SPDX-License-Identifier: BSD-3-Clause

import Charts
import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

struct StudioLexicalLawsConfiguration: View {
    @Bindable var model: StudioHomeModel
    @Binding var draft: StudioLexicalLawsDraft
    let onCompletion: () -> Void

    var body: some View {
        Section("lexical-laws.parameters") {
            integerField("lexical-laws.checkpoints", value: $draft.checkpointCount)
            Text("lexical-laws.checkpoints.help")
                .font(.caption)
                .foregroundStyle(.secondary)
            DisclosureGroup("lexical-laws.fit-range") {
                integerField("lexical-laws.first-rank", value: $draft.firstRank)
                Toggle("lexical-laws.last-observed-rank", isOn: $draft.usesLastObservedRank)
                if !draft.usesLastObservedRank {
                    integerField("lexical-laws.last-rank", value: $draft.lastRank)
                }
                integerField("lexical-laws.row-limit", value: $draft.rankRowLimit)
                Text("lexical-laws.row-limit.help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !draft.isValid {
                Label("lexical-laws.parameters.invalid", systemImage: "exclamationmark.triangle")
                    .font(.callout)
            }
            Button("lexical-laws.run", systemImage: "chart.xyaxis.line") {
                let parameters = draft.parameters
                Task {
                    await model.analyzeLexicalLaws(parameters: parameters)
                    onCompletion()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!draft.isValid || !hasScope)
        }
        .disabled(model.isBusy)
    }

    private var hasScope: Bool {
        switch model.textAnalysisScope {
        case .allSources: !(model.snapshot?.sources.isEmpty ?? true)
        case .selectedSources: !model.selectedTextAnalysisSourceRevisionIDs.isEmpty
        }
    }

    private func integerField(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }
}

/// Displays only the observations and fits returned by GlifiKit, with bounded pages.
struct StudioLexicalLawsResults: View {
    let result: GlifiStudioLexicalLawsResult
    @Environment(\.locale) private var locale
    @State private var observations: StudioLexicalObservationKind = .rankFrequency
    @State private var page = 0
    @State private var requestedPage = 1
    @State private var exportDocument: StudioTextExportDocument?
    @State private var isPreparingExport = false
    @State private var exportFailed = false
    private let pageSize = 50

    var body: some View {
        Group {
            overview
            observationSection
            StudioLexicalLawFitSection(titleKey: "lexical-laws.zipf", law: result.zipf)
            StudioLexicalLawFitSection(titleKey: "lexical-laws.heaps", law: result.heaps)
            methodSection
        }
        .onChange(of: observations) { _, _ in resetPage() }
        .onChange(of: result.lineage.artifactID) { _, _ in resetPage() }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }),
            document: exportDocument, contentType: .json,
            defaultFilename: "GlifiStudio-LexicalLaws"
        ) { outcome in
            if case let .failure(error) = outcome,
                (error as? CocoaError)?.code != .userCancelled
            {
                exportFailed = true
            }
            exportDocument = nil
        }
        .alert("lexical-laws.export.failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private var overview: some View {
        Section("lexical-laws.result") {
            Label("lexical-laws.caveat", systemImage: "info.circle")
                .fixedSize(horizontal: false, vertical: true)
            Text("lexical-laws.result.context")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("summary.result.sources") {
                Text(result.sourceRevisionIDs.count, format: .number)
            }
            LabeledContent("lexical-laws.tokens") { Text(result.tokenCount, format: .number) }
            LabeledContent("lexical-laws.types") { Text(result.typeCount, format: .number) }
            Button("lexical-laws.export", systemImage: "square.and.arrow.up") {
                Task { await prepareExport() }
            }
            .disabled(isPreparingExport)
            if isPreparingExport { ProgressView("lexical-laws.export.preparing") }
        }
    }

    private var observationSection: some View {
        Section("lexical-laws.observations") {
            Picker("lexical-laws.observation-kind", selection: $observations) {
                ForEach(StudioLexicalObservationKind.allCases) { kind in
                    Text(LocalizedStringKey(kind.titleKey)).tag(kind)
                }
            }
            if observations == .rankFrequency && result.isRankFrequencyTruncated {
                Label("lexical-laws.rank.truncated", systemImage: "exclamationmark.triangle")
                    .fixedSize(horizontal: false, vertical: true)
            }
            if rowCount == 0 {
                ContentUnavailableView("lexical-laws.empty", systemImage: "chart.xyaxis.line")
            } else {
                Chart(rows) { row in
                    PointMark(
                        x: .value(firstColumnTitle, row.first),
                        y: .value(secondColumnTitle, row.second))
                }
                .chartXAxisLabel { Text(LocalizedStringKey(observations.firstColumnKey)) }
                .chartYAxisLabel { Text(LocalizedStringKey(observations.secondColumnKey)) }
                .frame(height: 220)
                .accessibilityLabel(LocalizedStringKey(observations.titleKey))
                .accessibilityHint("lexical-laws.chart.help")
                Text("lexical-laws.chart.help")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Table(rows) {
                    TableColumn(LocalizedStringKey(observations.firstColumnKey)) { row in
                        Text(row.first, format: .number)
                    }
                    if observations == .rankFrequency {
                        TableColumn("weighting.term") { row in
                            Text(row.label).textSelection(.enabled)
                        }
                    }
                    TableColumn(LocalizedStringKey(observations.secondColumnKey)) { row in
                        Text(row.second, format: .number)
                    }
                }
                .frame(minHeight: 160, idealHeight: 280, maxHeight: 400)
                pagination
            }
        }
    }

    private var firstColumnTitle: String {
        String(localized: String.LocalizationValue(observations.firstColumnKey), locale: locale)
    }

    private var secondColumnTitle: String {
        String(localized: String.LocalizationValue(observations.secondColumnKey), locale: locale)
    }

    private var rowCount: Int {
        switch observations {
        case .rankFrequency: result.rankFrequency.count
        case .spectrum: result.spectrum.count
        case .growth: result.growth.count
        }
    }

    private var rows: [StudioLexicalObservationRow] {
        let offset = page * pageSize
        switch observations {
        case .rankFrequency:
            return result.rankFrequency.dropFirst(offset).prefix(pageSize).map {
                StudioLexicalObservationRow(
                    id: $0.rank, first: $0.rank, second: $0.count, label: $0.type)
            }
        case .spectrum:
            return result.spectrum.dropFirst(offset).prefix(pageSize).map {
                StudioLexicalObservationRow(
                    id: $0.frequency, first: $0.frequency, second: $0.typeCount)
            }
        case .growth:
            return result.growth.dropFirst(offset).prefix(pageSize).map {
                StudioLexicalObservationRow(
                    id: $0.tokenCount, first: $0.tokenCount, second: $0.typeCount)
            }
        }
    }

    private var pageCount: Int { (rowCount + pageSize - 1) / pageSize }

    private var pagination: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("lexical-laws.observation-count") { Text(rowCount, format: .number) }
            LabeledContent("frequency.page") { Text("\(page + 1) / \(pageCount)") }
            LabeledContent("frequency.visible-rows") { Text(rows.count, format: .number) }
            ViewThatFits(in: .horizontal) {
                HStack { pageButtons }
                VStack(alignment: .leading) { pageButtons }
            }
            LabeledContent("weighting.page.direct") {
                TextField("weighting.page.direct", value: $requestedPage, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onSubmit { selectPage(requestedPage - 1) }
                Button("weighting.page.go") { selectPage(requestedPage - 1) }
                    .disabled(requestedPage < 1 || requestedPage > pageCount)
            }
        }
    }

    @ViewBuilder private var pageButtons: some View {
        Button("frequency.page.previous", systemImage: "chevron.backward") { selectPage(page - 1) }
            .disabled(page == 0)
        Button("frequency.page.next", systemImage: "chevron.forward") { selectPage(page + 1) }
            .disabled(page + 1 >= pageCount)
        Button("weighting.page.last", systemImage: "chevron.forward.to.line") {
            selectPage(pageCount - 1)
        }
        .disabled(page + 1 >= pageCount)
    }

    private func selectPage(_ value: Int) {
        guard value >= 0, value < pageCount else { return }
        page = value
        requestedPage = value + 1
    }

    private func resetPage() {
        page = 0
        requestedPage = 1
    }

    private var methodSection: some View {
        Section {
            DisclosureGroup("summary.result.method-lineage") {
                identifierRow("text-analysis.method", result.analysisIdentifier)
                identifierRow("mtld.type-mapping", result.typeMappingIdentifier)
                identifierRow("mtld.sequence-policy", result.sequencePolicy)
                identifierRow("lexical-laws.checkpoint-policy", result.checkpointPolicy)
                identifierRow("lexical-laws.caveat-identifier", result.fitCaveat)
                LabeledContent("lexical-laws.checkpoints") {
                    Text(result.parameters.checkpointCount, format: .number)
                }
                LabeledContent("lexical-laws.first-rank") {
                    Text(result.parameters.zipfFirstRank, format: .number)
                }
                LabeledContent("lexical-laws.last-rank") {
                    if let last = result.parameters.zipfLastRank {
                        Text(last, format: .number)
                    } else {
                        Text("lexical-laws.last-observed-rank")
                    }
                }
                LabeledContent("lexical-laws.row-limit") {
                    Text(result.parameters.rankRowLimit, format: .number)
                }
                identifierRow("summary.lineage.project", result.lineage.projectID)
                identifierRow("summary.lineage.artifact", result.lineage.artifactID)
                identifierRow("summary.lineage.node", result.lineage.analysisNodeID)
                LabeledContent("summary.lineage.source-generation") {
                    Text(result.lineage.sourceGeneration, format: .number)
                }
                LabeledContent("summary.lineage.generation") {
                    Text(result.lineage.generation, format: .number)
                }
                ForEach(result.sourceRevisionIDs, id: \.self) {
                    identifierRow("summary.source.revision", $0)
                }
            }
        }
    }

    private func identifierRow(_ key: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(key) {
            Text(value).font(.caption.monospaced()).textSelection(.enabled)
        }
    }

    private func prepareExport() async {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        defer { isPreparingExport = false }
        do {
            let text = try await Self.encodedResult(result)
            exportDocument = StudioTextExportDocument(text: text, contentType: .json)
        } catch {
            exportFailed = true
        }
    }

    @concurrent nonisolated private static func encodedResult(
        _ result: GlifiStudioLexicalLawsResult
    ) async throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(result)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

private struct StudioLexicalLawFitSection: View {
    let titleKey: LocalizedStringKey
    let law: GlifiStudioLexicalLawFit
    @State private var residualPage = 0
    private let pageSize = 50

    var body: some View {
        Section(titleKey) {
            if let fit = law.fit {
                if !fit.isExponentInModelDomain {
                    Label(
                        "lexical-laws.fit.outside-domain", systemImage: "exclamationmark.triangle"
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                numberRow("lexical-laws.fit.coefficient", fit.coefficient)
                numberRow("lexical-laws.fit.exponent", fit.exponent)
                if let rSquared = fit.rSquared {
                    numberRow("lexical-laws.fit.r-squared", rSquared)
                } else {
                    LabeledContent("lexical-laws.fit.r-squared") {
                        Text("lexical-laws.fit.no-variance")
                    }
                }
                numberRow("lexical-laws.fit.rmse", fit.rootMeanSquaredLogError)
                DisclosureGroup("lexical-laws.fit.details") {
                    Text(law.methodIdentifier).font(.caption.monospaced()).textSelection(.enabled)
                    LabeledContent("lexical-laws.fit.points") {
                        Text(fit.pointCount, format: .number)
                    }
                    LabeledContent("lexical-laws.fit.first-predictor") {
                        Text(fit.firstPredictor, format: .number)
                    }
                    LabeledContent("lexical-laws.fit.last-predictor") {
                        Text(fit.lastPredictor, format: .number)
                    }
                    numberRow("lexical-laws.fit.intercept", fit.intercept)
                    numberRow("lexical-laws.fit.slope", fit.slope)
                    Text("lexical-laws.fit.residuals").font(.headline)
                    Text("lexical-laws.fit.residuals.help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(residualIndices(fit), id: \.self) { index in
                        LabeledContent {
                            Text(
                                fit.residuals[index],
                                format: .number.precision(.significantDigits(1...17))
                            )
                            .textSelection(.enabled)
                        } label: {
                            Text(index + 1, format: .number)
                        }
                    }
                    residualPagination(fit)
                }
            } else {
                Label("lexical-laws.fit.unavailable", systemImage: "info.circle")
                DisclosureGroup("lexical-laws.fit.details") {
                    Text(law.methodIdentifier).font(.caption.monospaced()).textSelection(.enabled)
                    if let reason = law.unavailableReason {
                        Text(reason).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
        }
        .onChange(of: law) { _, _ in residualPage = 0 }
    }

    private func numberRow(_ key: LocalizedStringKey, _ value: Double) -> some View {
        LabeledContent(key) {
            Text(value, format: .number.precision(.significantDigits(1...17)))
                .textSelection(.enabled)
        }
    }

    private func residualIndices(_ fit: GlifiStudioLogLinearFit) -> Range<Int> {
        let lower = min(residualPage * pageSize, fit.residuals.count)
        return lower..<min(lower + pageSize, fit.residuals.count)
    }

    private func residualPagination(_ fit: GlifiStudioLogLinearFit) -> some View {
        let pageCount = (fit.residuals.count + pageSize - 1) / pageSize
        return VStack(alignment: .leading, spacing: 8) {
            LabeledContent("frequency.page") { Text("\(residualPage + 1) / \(pageCount)") }
            ViewThatFits(in: .horizontal) {
                HStack { residualPageButtons(pageCount) }
                VStack(alignment: .leading) { residualPageButtons(pageCount) }
            }
        }
    }

    @ViewBuilder private func residualPageButtons(_ pageCount: Int) -> some View {
        Button("frequency.page.previous", systemImage: "chevron.backward") { residualPage -= 1 }
            .disabled(residualPage == 0)
        Button("frequency.page.next", systemImage: "chevron.forward") { residualPage += 1 }
            .disabled(residualPage + 1 >= pageCount)
        Button("weighting.page.last", systemImage: "chevron.forward.to.line") {
            residualPage = max(0, pageCount - 1)
        }
        .disabled(residualPage + 1 >= pageCount)
    }
}

private struct StudioLexicalObservationRow: Identifiable {
    let id: Int
    let first: Int
    let second: Int
    var label = ""
}

private enum StudioLexicalObservationKind: CaseIterable, Identifiable {
    case rankFrequency
    case spectrum
    case growth

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .rankFrequency: "lexical-laws.rank-frequency"
        case .spectrum: "lexical-laws.spectrum"
        case .growth: "lexical-laws.growth"
        }
    }

    var firstColumnKey: String {
        switch self {
        case .rankFrequency: "lexical-laws.rank"
        case .spectrum: "frequency.count"
        case .growth: "lexical-laws.tokens"
        }
    }

    var secondColumnKey: String {
        switch self {
        case .rankFrequency: "frequency.count"
        case .spectrum, .growth: "lexical-laws.types"
        }
    }
}
