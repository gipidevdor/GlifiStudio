// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI

/// Contextual text tools that present the results and provenance supplied by GlifiKit.
struct StudioTextAnalysisView: View {
    @Bindable var model: StudioHomeModel
    let onImportSources: () -> Void
    let onOpenProject: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding private var tool: StudioTextTool
    @State private var workspace: StudioTextWorkspace = .configuration
    @State private var weightingDetail: StudioWeightingDetail = .vocabulary

    init(
        model: StudioHomeModel,
        onImportSources: @escaping () -> Void,
        onOpenProject: @escaping () -> Void,
        tool: Binding<StudioTextTool>
    ) {
        self.model = model
        self.onImportSources = onImportSources
        self.onOpenProject = onOpenProject
        _tool = tool
    }

    var body: some View {
        let sourceLookup = StudioSourceLookup(sources: model.snapshot?.sources ?? [])
        return VStack(spacing: 0) {
            toolHeader
            Divider()
            if let snapshot = model.snapshot {
                if snapshot.sources.isEmpty {
                    ContentUnavailableView {
                        Label("text-analysis.empty-sources.title", systemImage: "doc.text")
                    } description: {
                        Text("text-analysis.empty-sources.description")
                    } actions: {
                        Button("action.import", action: onImportSources)
                            .disabled(model.isBusy)
                    }
                } else {
                    GeometryReader { geometry in
                        if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                            HSplitView {
                                configurationPane(snapshot.sources)
                                    .frame(minWidth: 290, idealWidth: 340, maxWidth: 420)
                                resultsPane(sourceLookup: sourceLookup)
                                    .frame(minWidth: 380)
                            }
                        } else {
                            compactWorkspace(snapshot.sources, sourceLookup: sourceLookup)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("sources.needs-project.title", systemImage: "folder.badge.questionmark")
                } description: {
                    Text("summary.needs-project")
                } actions: {
                    Button("action.open-project", action: onOpenProject)
                        .disabled(model.isBusy)
                }
            }
        }
        .navigationTitle(LocalizedStringKey(tool.titleKey))
        .onChange(of: tool) { _, _ in
            workspace = hasResult ? .results : .configuration
        }
        .onChange(of: resultIdentity) { _, identity in
            if identity != nil { workspace = .results }
        }
    }

    private var toolHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Label(LocalizedStringKey(tool.titleKey), systemImage: tool.systemImage)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    toolPicker
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(LocalizedStringKey(tool.titleKey), systemImage: tool.systemImage)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    toolPicker
                }
            }
            Text(LocalizedStringKey(tool.introductionKey))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toolPicker: some View {
        Picker("text-analysis.tool", selection: $tool) {
            ForEach(StudioTextTool.allCases) { option in
                Label(LocalizedStringKey(option.titleKey), systemImage: option.systemImage)
                    .tag(option)
            }
        }
        .pickerStyle(.menu)
        .fixedSize(horizontal: true, vertical: false)
        .disabled(model.isBusy)
    }

    private func compactWorkspace(
        _ sources: [GlifiStudioProjectSource], sourceLookup: StudioSourceLookup
    ) -> some View {
        TabView(selection: $workspace) {
            Tab(value: StudioTextWorkspace.configuration) {
                configurationPane(sources)
            } label: {
                Text("text-analysis.workspace.configuration")
            }
            Tab(value: StudioTextWorkspace.results) {
                resultsPane(sourceLookup: sourceLookup)
            } label: {
                Text("text-analysis.workspace.results")
            }
        }
        .tabViewStyle(.grouped)
        .padding()
    }

    private func configurationPane(_ sources: [GlifiStudioProjectSource]) -> some View {
        Form {
            scopeSection(sources)
            switch tool {
            case .summary: parametersSection
            case .documents: bm25ParametersSection
            case .lexicon:
                frequencyParametersSection
                mtldParametersSection
            case .termWeights: termWeightingParametersSection
            case .lexicalLaws:
                StudioLexicalLawsConfiguration(model: model, draft: $model.lexicalLawsDraft) {
                    if model.lastLexicalLaws != nil { workspace = .results }
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("text-analysis.configuration")
    }

    private func resultsPane(sourceLookup: StudioSourceLookup) -> some View {
        Form {
            if hasResult {
                switch tool {
                case .summary:
                    if let summary = model.lastExtractiveSummary {
                        resultSection(summary, sourceLookup: sourceLookup)
                        methodSection(summary)
                    }
                    if let source = model.summarySourceText {
                        sourceSection(source, sourceLookup: sourceLookup)
                    }
                case .documents:
                    if let ranking = model.lastBM25Ranking {
                        bm25ResultSection(ranking, sourceLookup: sourceLookup)
                    }
                    if let source = model.bm25SourceText {
                        bm25SourceSection(source, sourceLookup: sourceLookup)
                    }
                case .lexicon:
                    if let frequencies = model.lastNGramFrequencies {
                        frequencyResultSection(frequencies)
                    }
                    if let diversity = model.lastLexicalDiversity {
                        mtldResultSection(diversity, sourceLookup: sourceLookup)
                    }
                case .termWeights:
                    if let weighting = model.lastTermWeighting {
                        termWeightingResultSection(weighting)
                        Section {
                            Picker("text-analysis.weighting.detail", selection: $weightingDetail) {
                                ForEach(StudioWeightingDetail.allCases) { detail in
                                    Text(LocalizedStringKey(detail.titleKey)).tag(detail)
                                }
                            }
                        }
                        switch weightingDetail {
                        case .sources:
                            termWeightingSourcesSection(weighting, sourceLookup: sourceLookup)
                        case .vocabulary: termWeightingVocabularySection(weighting)
                        case .cells:
                            termWeightingCellsSection(weighting, sourceLookup: sourceLookup)
                        }
                        termWeightingMethodSection(weighting)
                    }
                case .lexicalLaws:
                    if let result = model.lastLexicalLaws {
                        StudioLexicalLawsResults(result: result)
                    }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("text-analysis.results.empty.title", systemImage: tool.systemImage)
                    } description: {
                        Text("text-analysis.results.empty.description")
                    } actions: {
                        Button("text-analysis.workspace.configuration") {
                            workspace = .configuration
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("text-analysis.results")
    }

    private var resultIdentity: String? {
        switch tool {
        case .summary: model.lastExtractiveSummary?.lineage.artifactID
        case .documents: model.lastBM25Ranking?.lineage.artifactID
        case .lexicon:
            model.lastNGramFrequencies?.lineage.artifactID
                ?? model.lastLexicalDiversity?.lineage.artifactID
        case .termWeights: model.lastTermWeighting?.lineage.artifactID
        case .lexicalLaws: model.lastLexicalLaws?.lineage.artifactID
        }
    }

    private var hasResult: Bool { resultIdentity != nil }

    private var hasScope: Bool {
        switch model.textAnalysisScope {
        case .allSources: !(model.snapshot?.sources.isEmpty ?? true)
        case .selectedSources: !model.selectedTextAnalysisSourceRevisionIDs.isEmpty
        }
    }

    private func scopeSection(_ sources: [GlifiStudioProjectSource]) -> some View {
        Section("summary.scope.title") {
            Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                ForEach(StudioTextAnalysisScope.allCases) { scope in
                    Text(LocalizedStringKey(scope.titleKey)).tag(scope)
                }
            }
            if model.textAnalysisScope == .selectedSources {
                LabeledContent("text-analysis.scope.selected-count") {
                    Text(model.selectedTextAnalysisSourceRevisionIDs.count, format: .number)
                }
                DisclosureGroup("text-analysis.scope.choose-sources") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(sources.enumerated()), id: \.element.sourceRevisionID) {
                                index, source in
                                sourceToggle(source, index: index)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 260)
                }
                if model.selectedTextAnalysisSourceRevisionIDs.isEmpty {
                    Label("summary.scope.empty", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("summary.scope.source-count") {
                    Text(sources.count, format: .number)
                }
            }
        }
        .disabled(model.isBusy)
    }

    private func sourceToggle(_ source: GlifiStudioProjectSource, index: Int) -> some View {
        Toggle(
            isOn: Binding(
                get: {
                    model.selectedTextAnalysisSourceRevisionIDs.contains(source.sourceRevisionID)
                },
                set: { isSelected in
                    if isSelected
                        != model.selectedTextAnalysisSourceRevisionIDs.contains(
                            source.sourceRevisionID)
                    {
                        model.toggleTextAnalysisSource(source.sourceRevisionID)
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 4) {
                sourceName(index: index)
                HStack {
                    Text(source.format == .markdown ? "format.markdown" : "format.plain-text")
                    Text(Int64(source.byteCount), format: .byteCount(style: .file))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(shortID(source.sourceRevisionID))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }

    private var parametersSection: some View {
        Section("summary.parameters") {
            Picker("summary.budget.unit", selection: $model.summaryBudgetUnit) {
                ForEach(StudioSummaryBudgetUnit.allCases) { unit in
                    Text(LocalizedStringKey(unit.titleKey)).tag(unit)
                }
            }
            LabeledContent("summary.budget.limit") {
                TextField("summary.budget.limit", value: $model.summaryBudgetLimit, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
            Text(
                model.summaryBudgetUnit == .characters
                    ? "summary.budget.characters.help" : "summary.budget.help"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            DisclosureGroup("summary.parameters.details") {
                Picker("summary.method", selection: $model.summaryMethod) {
                    ForEach(StudioSummaryMethod.allCases) { method in
                        Text(LocalizedStringKey(method.titleKey)).tag(method)
                    }
                }
                if model.summaryMethod.supportsGraphConfiguration {
                    DisclosureGroup("summary.graph.configuration") {
                        decimalField("summary.graph.damping", value: $model.summaryGraphDamping)
                        decimalField("summary.graph.tolerance", value: $model.summaryGraphTolerance)
                        integerField(
                            "summary.graph.maximum-iterations",
                            value: $model.summaryGraphMaximumIterations)
                        if model.summaryMethod == .lexRankThreshold {
                            decimalField(
                                "summary.graph.threshold",
                                value: $model.summaryGraphSimilarityThreshold)
                        }
                        Text("summary.graph.configuration.help")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("summary.redundancy", selection: $model.summaryRedundancy) {
                    ForEach(StudioSummaryRedundancy.allCases) { redundancy in
                        Text(LocalizedStringKey(redundancy.titleKey)).tag(redundancy)
                    }
                }
                if model.summaryRedundancy == .maximalMarginalRelevance {
                    LabeledContent("summary.mmr.lambda") {
                        TextField(
                            "summary.mmr.lambda", value: $model.summaryMMRLambda,
                            format: .number.precision(.significantDigits(1...17))
                        )
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                    }
                    Text("summary.mmr.help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("summary.action.run", systemImage: "text.quote") {
                Task {
                    await model.summarizeSources()
                    if model.lastExtractiveSummary != nil { workspace = .results }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasScope)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .disabled(model.isBusy)
    }

    private func resultSection(
        _ summary: GlifiStudioExtractiveSummaryResult, sourceLookup: StudioSourceLookup
    ) -> some View {
        Section("summary.result.title") {
            Text("summary.result.context")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let diagnostics = summary.graphDiagnostics, !diagnostics.converged {
                Label("summary.graph.not-converged", systemImage: "exclamationmark.triangle")
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent("summary.result.sources") {
                Text(summary.sourceRevisionIDs.count, format: .number)
            }
            LabeledContent("summary.result.sentences") {
                Text(summary.selected.count, format: .number)
            }
            if summary.selected.isEmpty {
                ContentUnavailableView {
                    Label("summary.result.empty.title", systemImage: "text.magnifyingglass")
                } description: {
                    Text("summary.result.empty.description")
                }
            } else {
                Text("summary.result.order")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(summary.selected.map(SelectedSummarySentence.init)) { item in
                    sentenceRow(item, sourceLookup: sourceLookup)
                }
            }
        }
    }

    private func sentenceRow(_ item: SelectedSummarySentence, sourceLookup: StudioSourceLookup)
        -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            sourceName(
                revisionID: item.selected.sentence.sourceRevisionID, sourceLookup: sourceLookup
            )
            .font(.headline)
            Text(item.selected.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Button("summary.action.open-source", systemImage: "doc.text.magnifyingglass") {
                Task { await model.openSummarySource(item.selected) }
            }
            .disabled(model.isBusy)
            DisclosureGroup("summary.sentence.details") {
                LabeledContent("summary.sentence.rank") {
                    Text(item.selected.sentence.rank, format: .number)
                }
                LabeledContent("summary.sentence.score") {
                    Text(
                        item.selected.sentence.score,
                        format: .number.precision(.significantDigits(17))
                    )
                    .textSelection(.enabled)
                }
                if let order = item.selected.sentence.selectionOrder {
                    LabeledContent("summary.sentence.selection-order") {
                        Text(order, format: .number)
                    }
                }
                LabeledContent("summary.sentence.tokens") {
                    Text(item.selected.sentence.tokenCount, format: .number)
                }
                LabeledContent("summary.sentence.eligible") {
                    Text(item.selected.sentence.isEligible ? "common.yes" : "common.no")
                }
                LabeledContent("summary.sentence.extracted-range") {
                    Text("\(item.selected.sentence.startUTF8)–\(item.selected.sentence.endUTF8)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                identifierRow("summary.source.revision", item.selected.sentence.sourceRevisionID)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(
            model.focusedSummarySentenceID == item.id ? .isSelected : AccessibilityTraits())
    }

    private func methodSection(_ summary: GlifiStudioExtractiveSummaryResult) -> some View {
        Section {
            DisclosureGroup("summary.result.method-lineage") {
                Text("summary.result.limits")
                    .font(.callout)
                identifierRow("summary.method", summary.methodIdentifier)
                identifierRow("summary.redundancy", summary.redundancyPolicy)
                if let lambda = summary.redundancyLambda {
                    LabeledContent("summary.mmr.lambda") {
                        Text(lambda, format: .number.precision(.significantDigits(1...17)))
                    }
                }
                identifierRow("summary.budget.unit", summary.budget.unit)
                LabeledContent("summary.budget.limit") {
                    Text(summary.budget.limit, format: .number)
                }
                LabeledContent("summary.budget.consumed") {
                    Text(summary.consumedBudget, format: .number)
                }
                identifierRow("summary.method.tf", summary.scheme.termFrequency)
                identifierRow("summary.method.idf", summary.scheme.inverseDocumentFrequency)
                identifierRow("summary.method.normalization", summary.scheme.normalization)
                identifierRow("summary.method.eligibility", summary.eligibilityPolicy)
                identifierRow("summary.method.tie-break", summary.tieBreakIdentifier)
                identifierRow("summary.method.output-order", summary.outputOrderIdentifier)
                if let graph = summary.graphDiagnostics {
                    LabeledContent("summary.graph.converged") {
                        Text(graph.converged ? "common.yes" : "common.no")
                    }
                    LabeledContent("summary.graph.nodes") { Text(graph.nodeCount, format: .number) }
                    LabeledContent("summary.graph.edges") { Text(graph.edgeCount, format: .number) }
                    LabeledContent("summary.graph.iterations") {
                        Text(graph.iterations, format: .number)
                    }
                    LabeledContent("summary.graph.damping") {
                        Text(
                            graph.configuration.damping,
                            format: .number.precision(.significantDigits(1...17)))
                    }
                    LabeledContent("summary.graph.tolerance") {
                        Text(
                            graph.configuration.tolerance,
                            format: .number.precision(.significantDigits(1...17)))
                    }
                    LabeledContent("summary.graph.maximum-iterations") {
                        Text(graph.configuration.maximumIterations, format: .number)
                    }
                    LabeledContent("summary.graph.threshold") {
                        Text(
                            graph.configuration.similarityThreshold,
                            format: .number.precision(.significantDigits(1...17)))
                    }
                    identifierRow("summary.graph.similarity", graph.similarityIdentifier)
                    identifierRow("summary.graph.centrality", graph.centralityIdentifier)
                    identifierRow("summary.graph.dangling-policy", graph.danglingPolicyIdentifier)
                }
                identifierRow("summary.lineage.project", summary.lineage.projectID)
                LabeledContent("summary.lineage.source-generation") {
                    Text(summary.lineage.sourceGeneration, format: .number)
                }
                LabeledContent("summary.lineage.generation") {
                    Text(summary.lineage.generation, format: .number)
                }
                identifierRow("summary.lineage.artifact", summary.lineage.artifactID)
                identifierRow("summary.lineage.node", summary.lineage.analysisNodeID)
                ForEach(summary.sourceRevisionIDs, id: \.self) { revisionID in
                    identifierRow("summary.source.revision", revisionID)
                }
            }
        }
    }

    private func sourceSection(_ source: GlifiStudioSourceText, sourceLookup: StudioSourceLookup)
        -> some View
    {
        Section("summary.source.title") {
            sourceName(revisionID: source.sourceRevisionID, sourceLookup: sourceLookup)
                .font(.headline)
            if model.summarySourceRanges.isEmpty {
                Label("summary.source.unmapped", systemImage: "info.circle")
                    .font(.callout)
            } else {
                Text("summary.source.mapped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(attributedSource(source.text, ranges: model.summarySourceRanges))
                .font(.body.monospaced())
                .textSelection(.enabled)
            Button("summary.action.close-source", role: .cancel) {
                model.clearSummarySource()
            }
            .disabled(model.isBusy)
        }
    }

    private func sourceName(revisionID: String, sourceLookup: StudioSourceLookup) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let index = sourceLookup.index(of: revisionID) {
                    sourceName(index: index)
                } else {
                    Text("summary.source.label")
                }
            }
            Text(shortID(revisionID)).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
    }

    private var bm25ParametersSection: some View {
        Section("bm25.parameters") {
            TextField("bm25.query", text: $model.bm25QueryDraft, axis: .vertical)
                .lineLimit(2...4)
            Text("bm25.query.help")
                .font(.caption)
                .foregroundStyle(.secondary)
            DisclosureGroup("bm25.parameters.details") {
                decimalField("bm25.k1", value: $model.bm25K1)
                decimalField("bm25.b", value: $model.bm25B)
            }
            Text("bm25.parameters.help")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("bm25.action.run", systemImage: "doc.text.magnifyingglass") {
                Task {
                    await model.rankSourcesBM25()
                    if model.lastBM25Ranking != nil { workspace = .results }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                !hasScope
                    || model.bm25QueryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .disabled(model.isBusy)
    }

    private func bm25ResultSection(
        _ ranking: GlifiStudioBM25Result, sourceLookup: StudioSourceLookup
    ) -> some View {
        Section("bm25.result.title") {
            Text("bm25.result.help")
                .font(.callout)
            LabeledContent("bm25.document-count") {
                Text(ranking.documentCount, format: .number)
            }
            if let options = model.lastBM25Options {
                LabeledContent("bm25.query.effective") {
                    Text(options.query).textSelection(.enabled)
                }
            }
            ForEach(ranking.ranking, id: \.sourceRevisionID) { document in
                VStack(alignment: .leading, spacing: 8) {
                    sourceName(revisionID: document.sourceRevisionID, sourceLookup: sourceLookup)
                        .font(.headline)
                    LabeledContent("bm25.score") {
                        Text(document.score, format: .number.precision(.significantDigits(1...17)))
                            .textSelection(.enabled)
                    }
                    LabeledContent("bm25.document-length") {
                        Text(document.length, format: .number)
                    }
                    Button("bm25.action.open-source", systemImage: "doc.text") {
                        Task { await model.openBM25Source(document) }
                    }
                    .disabled(model.isBusy)
                }
                .accessibilityElement(children: .contain)
                .padding(.vertical, 6)
            }
            DisclosureGroup("summary.result.method-lineage") {
                identifierRow("text-analysis.method", ranking.methodIdentifier)
                LabeledContent("bm25.k1") {
                    Text(ranking.k1, format: .number.precision(.significantDigits(1...17)))
                }
                LabeledContent("bm25.b") {
                    Text(ranking.b, format: .number.precision(.significantDigits(1...17)))
                }
                LabeledContent("bm25.document-count") {
                    Text(ranking.documentCount, format: .number)
                }
                LabeledContent("bm25.average-length") {
                    Text(
                        ranking.averageLength, format: .number.precision(.significantDigits(1...17))
                    )
                }
                ForEach(ranking.queryTerms, id: \.term) { term in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.term).font(.headline).textSelection(.enabled)
                        Text(term.isInVocabulary ? "bm25.term.known" : "bm25.term.outside")
                        LabeledContent("frequency.document-frequency") {
                            Text(term.documentFrequency, format: .number)
                        }
                        LabeledContent("summary.method.idf") {
                            Text(
                                term.inverseDocumentFrequency,
                                format: .number.precision(.significantDigits(1...17)))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                lineageRows(ranking.lineage)
            }
        }
    }

    private func bm25SourceSection(
        _ source: GlifiStudioSourceText, sourceLookup: StudioSourceLookup
    ) -> some View {
        Section("bm25.source.title") {
            sourceName(revisionID: source.sourceRevisionID, sourceLookup: sourceLookup).font(
                .headline)
            Text("bm25.source.help").font(.caption).foregroundStyle(.secondary)
            Text(source.text).font(.body.monospaced()).textSelection(.enabled)
            Button("summary.action.close-source", role: .cancel) {
                model.clearBM25Source()
            }
            .disabled(model.isBusy)
        }
    }

    private var frequencyParametersSection: some View {
        Section("frequency.parameters") {
            Picker("frequency.unit", selection: $model.frequencyUnit) {
                ForEach(StudioFrequencyUnit.allCases) { unit in
                    Text(LocalizedStringKey(unit.titleKey)).tag(unit)
                }
            }
            Text(LocalizedStringKey(frequencyUnitHelpKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.frequencyUnit != .forms {
                integerField("frequency.n", value: $model.frequencyN)
                Text("frequency.n.help").font(.caption).foregroundStyle(.secondary)
            }
            integerField("frequency.maximum-rows", value: $model.frequencyMaximumRowCount)
            Text("frequency.maximum-rows.help").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("frequency.filters") {
                TextField(
                    "frequency.stopwords", text: $model.frequencyStopwordsDraft, axis: .vertical
                )
                .lineLimit(3...6)
                Text("frequency.stopwords.help").font(.caption).foregroundStyle(.secondary)
                if model.frequencyUnit == .forms {
                    integerField("frequency.minimum-length", value: $model.frequencyMinimumLength)
                }
                integerField("frequency.minimum-count", value: $model.frequencyMinimumCount)
                integerField(
                    "frequency.minimum-document-frequency",
                    value: $model.frequencyMinimumDocumentFrequency)
                decimalField(
                    "frequency.maximum-document-proportion",
                    value: $model.frequencyMaximumDocumentProportion)
                Text("frequency.filters.help").font(.caption).foregroundStyle(.secondary)
            }
            Button("frequency.action.run", systemImage: "list.number") {
                Task {
                    await model.analyzeFrequencies()
                    if model.lastNGramFrequencies != nil { workspace = .results }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasScope)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .disabled(model.isBusy)
    }

    private var frequencyUnitHelpKey: String {
        switch model.frequencyUnit {
        case .forms: "frequency.forms.help"
        case .words: "frequency.words.help"
        case .characters: "frequency.characters.help"
        case .paddedCharacters: "frequency.padded-characters.help"
        }
    }

    private func frequencyResultSection(_ frequencies: GlifiStudioNGramFrequencyResult) -> some View
    {
        Section("frequency.result.title") {
            LabeledContent("summary.result.sources") {
                Text(frequencies.sourceRevisionIDs.count, format: .number)
            }
            LabeledContent("frequency.denominator") {
                Text(frequencies.denominator, format: .number)
            }
            LabeledContent("frequency.distinct-units") {
                Text(frequencies.distinctUnitCount, format: .number)
            }
            LabeledContent("frequency.returned-rows") {
                Text(frequencies.rows.count, format: .number)
            }
            if frequencies.isTruncated {
                Label("frequency.truncated", systemImage: "exclamationmark.triangle")
            } else {
                Text("frequency.not-truncated").font(.caption).foregroundStyle(.secondary)
            }
            if frequencies.rows.isEmpty {
                ContentUnavailableView("frequency.empty", systemImage: "list.number")
            } else {
                Table(model.frequencyRowsOnPage.map(FrequencyPresentationRow.init)) {
                    TableColumn("frequency.unit-value") { row in
                        Text(row.value.components.joined(separator: " ")).textSelection(.enabled)
                    }
                    TableColumn("frequency.count") { row in
                        Text(row.value.count, format: .number)
                    }
                    TableColumn("frequency.document-frequency") { row in
                        Text(row.value.documentFrequency, format: .number)
                    }
                    TableColumn("frequency.relative-frequency") { row in
                        Text(
                            row.value.relativeFrequency,
                            format: .number.precision(.significantDigits(1...17)))
                    }
                }
                .frame(minHeight: 160, idealHeight: 300, maxHeight: 400)
                frequencyPagination
            }
            DisclosureGroup("summary.result.method-lineage") {
                identifierRow("frequency.unit", frequencies.unitIdentifier)
                LabeledContent("frequency.n") { Text(frequencies.n, format: .number) }
                identifierRow("frequency.filter.identifier", frequencies.filterIdentifier)
                identifierRow("frequency.stopwords.policy", frequencies.stopwordPolicyIdentifier)
                LabeledContent("frequency.stopwords") {
                    Text(frequencies.filter.stopwords.joined(separator: ", ")).textSelection(
                        .enabled)
                }
                LabeledContent("frequency.minimum-length") {
                    Text(frequencies.filter.minimumLength, format: .number)
                }
                LabeledContent("frequency.minimum-count") {
                    Text(frequencies.filter.minimumCount, format: .number)
                }
                LabeledContent("frequency.minimum-document-frequency") {
                    Text(frequencies.filter.minimumDocumentFrequency, format: .number)
                }
                LabeledContent("frequency.maximum-document-proportion") {
                    Text(
                        frequencies.filter.maximumDocumentProportion,
                        format: .number.precision(.significantDigits(1...17)))
                }
                if let options = model.lastFrequencyOptions {
                    LabeledContent("frequency.maximum-rows") {
                        Text(options.maximumRowCount, format: .number)
                    }
                }
                frequencyExclusions(frequencies.exclusions)
                lineageRows(frequencies.lineage)
                ForEach(frequencies.sourceRevisionIDs, id: \.self) {
                    identifierRow("summary.source.revision", $0)
                }
            }
        }
    }

    private var frequencyPagination: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("frequency.page") {
                Text("\(model.frequencyPage + 1) / \(model.frequencyPageCount)")
            }
            LabeledContent("frequency.visible-rows") {
                Text(model.frequencyRowsOnPage.count, format: .number)
            }
            Text("frequency.page.help").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("frequency.page.previous", systemImage: "chevron.backward") {
                    model.showFrequencyPage(model.frequencyPage - 1)
                }
                .disabled(model.isBusy || model.frequencyPage == 0)
                Button("frequency.page.next", systemImage: "chevron.forward") {
                    model.showFrequencyPage(model.frequencyPage + 1)
                }
                .disabled(model.isBusy || model.frequencyPage + 1 >= model.frequencyPageCount)
            }
        }
    }

    private func frequencyExclusions(_ exclusions: GlifiStudioTermFilterExclusions) -> some View {
        Group {
            Text("frequency.exclusions.help").font(.caption).foregroundStyle(.secondary)
            LabeledContent("frequency.exclusions.stopwords") {
                Text(exclusions.stopwords, format: .number)
            }
            LabeledContent("frequency.exclusions.length") {
                Text(exclusions.minimumLength, format: .number)
            }
            LabeledContent("frequency.exclusions.count") {
                Text(exclusions.minimumCount, format: .number)
            }
            LabeledContent("frequency.exclusions.document-frequency") {
                Text(exclusions.minimumDocumentFrequency, format: .number)
            }
            LabeledContent("frequency.exclusions.document-proportion") {
                Text(exclusions.maximumDocumentProportion, format: .number)
            }
        }
    }

    private var mtldParametersSection: some View {
        Section("mtld.parameters") {
            decimalField("mtld.threshold", value: $model.mtldThreshold)
            Text("mtld.threshold.help").font(.caption).foregroundStyle(.secondary)
            Button("mtld.action.run", systemImage: "textformat.abc") {
                Task {
                    await model.analyzeMTLD()
                    if model.lastLexicalDiversity != nil { workspace = .results }
                }
            }
            .disabled(!hasScope)
        }
        .disabled(model.isBusy)
    }

    private func mtldResultSection(
        _ diversity: GlifiStudioLexicalDiversityResult, sourceLookup: StudioSourceLookup
    ) -> some View {
        Section("mtld.result.title") {
            Text("mtld.result.help").font(.callout)
            LabeledContent("summary.result.sources") {
                Text(diversity.documents.count, format: .number)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("mtld.pooled").font(.headline)
                mtldValue(diversity.pooled)
            }
            ForEach(diversity.documents, id: \.sourceRevisionID) { document in
                VStack(alignment: .leading, spacing: 8) {
                    sourceName(revisionID: document.sourceRevisionID, sourceLookup: sourceLookup)
                        .font(.headline)
                    mtldValue(document.mtld)
                }
                .accessibilityElement(children: .contain)
                .padding(.vertical, 6)
            }
            DisclosureGroup("summary.result.method-lineage") {
                identifierRow("text-analysis.method", diversity.methodIdentifier)
                LabeledContent("mtld.threshold") {
                    Text(diversity.threshold, format: .number.precision(.significantDigits(1...17)))
                }
                identifierRow("mtld.type-mapping", diversity.typeMappingIdentifier)
                identifierRow("mtld.sequence-policy", diversity.sequencePolicy)
                lineageRows(diversity.lineage)
            }
        }
    }

    @ViewBuilder private func mtldValue(_ value: GlifiStudioMTLDValue?) -> some View {
        if let value {
            LabeledContent("mtld.tokens") { Text(value.tokenCount, format: .number) }
            LabeledContent("mtld.value") { extendedValue(value.value) }
            DisclosureGroup("mtld.directions") {
                LabeledContent("mtld.forward") { extendedValue(value.forward) }
                LabeledContent("mtld.backward") { extendedValue(value.backward) }
            }
        } else {
            Text("mtld.unavailable")
        }
    }

    @ViewBuilder private func extendedValue(_ value: GlifiStudioExtendedValue) -> some View {
        switch value {
        case let .finite(number):
            Text(number, format: .number.precision(.significantDigits(1...17)))
        case .positiveInfinity:
            Text("mtld.positive-infinity")
        }
    }

    private var termWeightingParametersSection: some View {
        Section("weighting.parameters") {
            Picker("summary.method.tf", selection: $model.termFrequencyVariant) {
                ForEach(StudioTermFrequencyVariant.allCases) { variant in
                    Text(LocalizedStringKey(variant.titleKey)).tag(variant)
                }
            }
            Picker("summary.method.idf", selection: $model.inverseDocumentFrequencyVariant) {
                ForEach(StudioInverseDocumentFrequencyVariant.allCases) { variant in
                    Text(LocalizedStringKey(variant.titleKey)).tag(variant)
                }
            }
            Picker("summary.method.normalization", selection: $model.termWeightingNormalization) {
                ForEach(StudioTermWeightingNormalization.allCases) { normalization in
                    Text(LocalizedStringKey(normalization.titleKey)).tag(normalization)
                }
            }
            Text("weighting.parameters.help").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("weighting.parameters.details") {
                Text("weighting.tf.help")
                Text("weighting.idf.help")
                Text("weighting.normalization.help")
                Text("weighting.limits.help")
            }
            Button("weighting.action.run", systemImage: "tablecells") {
                Task {
                    await model.analyzeTermWeights()
                    if model.lastTermWeighting != nil { workspace = .results }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasScope)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .disabled(model.isBusy)
    }

    private func termWeightingResultSection(_ weighting: GlifiStudioTermWeightingResult)
        -> some View
    {
        Section("weighting.result.title") {
            Text("weighting.result.context").font(.caption).foregroundStyle(.secondary)
            LabeledContent("summary.result.sources") {
                Text(weighting.sourceRevisionIDs.count, format: .number)
            }
            LabeledContent("weighting.term-count") { Text(weighting.terms.count, format: .number) }
            LabeledContent("weighting.observed-cells") {
                Text(weighting.cells.count, format: .number)
            }
            Text("weighting.zeros.help").font(.callout)
            if weighting.cells.isEmpty {
                ContentUnavailableView {
                    Label("weighting.empty.title", systemImage: "tablecells")
                } description: {
                    Text("weighting.empty.description")
                }
            }
        }
    }

    private func termWeightingSourcesSection(
        _ weighting: GlifiStudioTermWeightingResult, sourceLookup: StudioSourceLookup
    )
        -> some View
    {
        Section("weighting.sources.title") {
            Text("weighting.sources.help").font(.caption).foregroundStyle(.secondary)
            Table(
                weighting.sourceRevisionIDs.enumerated().map { index, revisionID in
                    WeightedSourcePresentationRow(
                        sourceRevisionID: revisionID,
                        observedCellCount: model.termWeightingObservedCellCounts[index])
                }
            ) {
                TableColumn("summary.source.label") { row in
                    sourceName(revisionID: row.sourceRevisionID, sourceLookup: sourceLookup)
                }
                TableColumn("weighting.observed-cells") { row in
                    Text(row.observedCellCount, format: .number)
                }
            }
            .frame(minHeight: 120, idealHeight: 240, maxHeight: 400)
        }
    }

    @ViewBuilder
    private func termWeightingVocabularySection(_ weighting: GlifiStudioTermWeightingResult)
        -> some View
    {
        if !weighting.terms.isEmpty {
            Section("weighting.vocabulary.title") {
                Text("weighting.vocabulary.help").font(.caption).foregroundStyle(.secondary)
                Table(
                    model.termIndicesOnWeightingPage.map { index in
                        WeightedTermPresentationRow(
                            term: weighting.terms[index],
                            documentFrequency: weighting.documentFrequencies[index])
                    }
                ) {
                    TableColumn("weighting.term") { row in
                        Text(row.term).textSelection(.enabled)
                    }
                    TableColumn("frequency.document-frequency") { row in
                        Text(row.documentFrequency, format: .number)
                    }
                }
                .frame(minHeight: 160, idealHeight: 300, maxHeight: 400)
                TermWeightingPagination(
                    page: model.termWeightingTermPage,
                    pageCount: model.termWeightingTermPageCount,
                    visibleRowCount: model.termIndicesOnWeightingPage.count,
                    isBusy: model.isBusy,
                    onSelect: model.showTermWeightingTermPage)
            }
        }
    }

    @ViewBuilder
    private func termWeightingCellsSection(
        _ weighting: GlifiStudioTermWeightingResult, sourceLookup: StudioSourceLookup
    ) -> some View {
        if !weighting.cells.isEmpty {
            Section("weighting.cells.title") {
                Text("weighting.cells.help").font(.caption).foregroundStyle(.secondary)
                Table(
                    model.cellsOnTermWeightingPage.map { cell in
                        WeightedCellPresentationRow(
                            sourceRevisionID: weighting.sourceRevisionIDs[cell.rowIndex],
                            term: weighting.terms[cell.columnIndex], value: cell)
                    }
                ) {
                    TableColumn("summary.source.label") { row in
                        sourceName(revisionID: row.sourceRevisionID, sourceLookup: sourceLookup)
                    }
                    TableColumn("weighting.term") { row in
                        Text(row.term).textSelection(.enabled)
                    }
                    TableColumn("frequency.count") { row in
                        Text(row.value.count, format: .number)
                    }
                    TableColumn("weighting.weight") { row in
                        Text(
                            row.value.weight,
                            format: .number.notation(.scientific).precision(
                                .significantDigits(1...17))
                        )
                        .textSelection(.enabled)
                    }
                }
                .frame(minHeight: 160, idealHeight: 300, maxHeight: 400)
                TermWeightingPagination(
                    page: model.termWeightingCellPage,
                    pageCount: model.termWeightingCellPageCount,
                    visibleRowCount: model.cellsOnTermWeightingPage.count,
                    isBusy: model.isBusy,
                    onSelect: model.showTermWeightingCellPage)
            }
        }
    }

    private func termWeightingMethodSection(_ weighting: GlifiStudioTermWeightingResult)
        -> some View
    {
        Section {
            DisclosureGroup("summary.result.method-lineage") {
                identifierRow("text-analysis.method", weighting.combinedIdentifier)
                identifierRow("weighting.analysis", weighting.analysisIdentifier)
                identifierRow("summary.method.tf", weighting.scheme.termFrequency)
                identifierRow("summary.method.idf", weighting.scheme.inverseDocumentFrequency)
                identifierRow("summary.method.normalization", weighting.scheme.normalization)
                if let options = model.lastTermWeightingOptions {
                    LabeledContent("weighting.scope.effective") {
                        Text(LocalizedStringKey(options.scope.titleKey))
                    }
                    LabeledContent("weighting.limits.sources") {
                        Text(options.corpusOptions.maximumDocumentCount, format: .number)
                    }
                    LabeledContent("weighting.limits.bytes") {
                        Text(
                            options.corpusOptions.maximumSourceByteCount, format: .number)
                    }
                    LabeledContent("weighting.limits.terms") {
                        Text(options.corpusOptions.maximumVocabularySize, format: .number)
                    }
                    LabeledContent("weighting.limits.cells") {
                        Text(options.corpusOptions.maximumNonZeroCellCount, format: .number)
                    }
                }
                lineageRows(weighting.lineage)
                ForEach(weighting.sourceRevisionIDs, id: \.self) {
                    identifierRow("summary.source.revision", $0)
                }
            }
        }
    }

    private func integerField(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).multilineTextAlignment(.trailing).frame(
                maxWidth: 160)
        }
    }

    private func decimalField(_ key: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number.precision(.significantDigits(1...17)))
                .multilineTextAlignment(.trailing).frame(maxWidth: 160)
        }
    }

    private func lineageRows(_ lineage: GlifiStudioDerivedLineage) -> some View {
        Group {
            identifierRow("summary.lineage.project", lineage.projectID)
            LabeledContent("summary.lineage.source-generation") {
                Text(lineage.sourceGeneration, format: .number)
            }
            LabeledContent("summary.lineage.generation") {
                Text(lineage.generation, format: .number)
            }
            identifierRow("summary.lineage.artifact", lineage.artifactID)
            identifierRow("summary.lineage.node", lineage.analysisNodeID)
        }
    }

    private func sourceName(index: Int) -> some View {
        HStack(spacing: 4) {
            Text("summary.source.label")
            Text(index + 1, format: .number)
        }
        .accessibilityElement(children: .combine)
    }

    private func identifierRow(_ key: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(key) {
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func shortID(_ value: String) -> String {
        value.count <= 24 ? value : String(value.prefix(12)) + "…" + String(value.suffix(8))
    }

    private func attributedSource(_ text: String, ranges: [GlifiStudioUTF8Range])
        -> AttributedString
    {
        var attributed = AttributedString(text)
        let utf8 = text.utf8
        for range in ranges {
            guard range.start >= 0, range.end >= range.start,
                let byteStart = utf8.index(
                    utf8.startIndex, offsetBy: range.start, limitedBy: utf8.endIndex),
                let byteEnd = utf8.index(
                    utf8.startIndex, offsetBy: range.end, limitedBy: utf8.endIndex),
                let start = String.Index(byteStart, within: text),
                let end = String.Index(byteEnd, within: text),
                let lower = AttributedString.Index(start, within: attributed),
                let upper = AttributedString.Index(end, within: attributed)
            else { continue }
            attributed[lower..<upper].backgroundColor = Color.accentColor.opacity(0.2)
            attributed[lower..<upper].font = .body.monospaced().bold()
        }
        return attributed
    }
}

private struct SelectedSummarySentence: Identifiable {
    let selected: GlifiStudioSelectedSentence

    var id: String {
        "\(selected.sentence.sourceRevisionID):\(selected.sentence.sentenceIndex)"
    }
}

private struct FrequencyPresentationRow: Identifiable {
    let value: GlifiStudioNGramFrequencyRow
    var id: [String] { value.components }
}

private struct WeightedSourcePresentationRow: Identifiable {
    let sourceRevisionID: String
    let observedCellCount: Int
    var id: String { sourceRevisionID }
}

private struct WeightedTermPresentationRow: Identifiable {
    let term: String
    let documentFrequency: Int
    var id: String { term }
}

private struct WeightedCellPresentationRow: Identifiable {
    let sourceRevisionID: String
    let term: String
    let value: GlifiStudioWeightedTermCell
    var id: [String] { [sourceRevisionID, term] }
}

private struct TermWeightingPagination: View {
    let page: Int
    let pageCount: Int
    let visibleRowCount: Int
    let isBusy: Bool
    let onSelect: (Int) -> Void
    @State private var requestedPage = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("frequency.page") { Text("\(page + 1) / \(pageCount)") }
            LabeledContent("frequency.visible-rows") { Text(visibleRowCount, format: .number) }
            Text("weighting.page.help").font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { sequentialButtons }
                VStack(alignment: .leading) { sequentialButtons }
            }
            LabeledContent("weighting.page.direct") {
                TextField("weighting.page.direct", value: $requestedPage, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onSubmit { selectRequestedPage() }
                Button("weighting.page.go") { selectRequestedPage() }
                    .disabled(requestedPage < 1 || requestedPage > pageCount)
            }
        }
        .disabled(isBusy)
        .onAppear { requestedPage = page + 1 }
        .onChange(of: page) { _, value in requestedPage = value + 1 }
        .onChange(of: pageCount) { _, _ in requestedPage = page + 1 }
    }

    @ViewBuilder private var sequentialButtons: some View {
        Button("frequency.page.previous", systemImage: "chevron.backward") { onSelect(page - 1) }
            .disabled(page == 0)
        Button("frequency.page.next", systemImage: "chevron.forward") { onSelect(page + 1) }
            .disabled(page + 1 >= pageCount)
        Button("weighting.page.last", systemImage: "chevron.forward.to.line") {
            onSelect(pageCount - 1)
        }
        .disabled(page + 1 >= pageCount)
    }

    private func selectRequestedPage() {
        guard requestedPage >= 1, requestedPage <= pageCount else { return }
        onSelect(requestedPage - 1)
    }
}

enum StudioTextTool: CaseIterable, Identifiable, Sendable {
    case summary
    case documents
    case lexicon
    case termWeights
    case lexicalLaws

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .summary: "text-analysis.tool.summary"
        case .documents: "text-analysis.tool.documents"
        case .lexicon: "text-analysis.tool.lexicon"
        case .termWeights: "text-analysis.tool.term-weights"
        case .lexicalLaws: "text-analysis.tool.lexical-laws"
        }
    }

    var introductionKey: String {
        switch self {
        case .summary: "summary.introduction"
        case .documents: "bm25.introduction"
        case .lexicon: "frequency.introduction"
        case .termWeights: "weighting.introduction"
        case .lexicalLaws: "text-analysis.tool.lexical-laws.description"
        }
    }

    var systemImage: String {
        switch self {
        case .summary: "text.quote"
        case .documents: "doc.text.magnifyingglass"
        case .lexicon: "list.number"
        case .termWeights: "tablecells"
        case .lexicalLaws: "chart.xyaxis.line"
        }
    }
}

private enum StudioTextWorkspace {
    case configuration
    case results
}

private enum StudioWeightingDetail: CaseIterable, Identifiable {
    case sources
    case vocabulary
    case cells

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .sources: "weighting.sources.title"
        case .vocabulary: "weighting.vocabulary.title"
        case .cells: "weighting.cells.title"
        }
    }
}

#Preview {
    StudioTextAnalysisView(
        model: StudioHomeModel(), onImportSources: {}, onOpenProject: {}, tool: .constant(.summary))
}
