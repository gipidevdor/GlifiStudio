// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

private enum StudioSection: String, CaseIterable, Identifiable {
    case overview
    case project
    case sources
    case investigation
    case query
    case findings
    case coding
    case export

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .overview: "sidebar.overview"
        case .project: "sidebar.project"
        case .sources: "sidebar.sources"
        case .investigation: "sidebar.investigation"
        case .query: "sidebar.query"
        case .findings: "sidebar.findings"
        case .coding: "sidebar.coding"
        case .export: "sidebar.export"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .project: "folder"
        case .sources: "doc.text"
        case .investigation: "lightbulb"
        case .query: "magnifyingglass"
        case .findings: "list.bullet.rectangle"
        case .coding: "highlighter"
        case .export: "square.and.arrow.up"
        }
    }
}

struct StudioHomeView: View {
    var documentURL: URL?
    var needsPackageInitialization: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    @State private var model = StudioHomeModel()
    @State private var selection: StudioSection? = .overview
    @State private var isSourceImporterPresented = false
    @State private var isProjectImporterPresented = false
    @State private var isExportFolderPresented = false

    init(documentURL: URL? = nil, needsPackageInitialization: Bool = false) {
        self.documentURL = documentURL
        self.needsPackageInitialization = needsPackageInitialization
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach([StudioSection.overview, .sources, .investigation, .findings]) {
                        section in
                        sidebarRow(section)
                    }
                }
                Section("sidebar.tools") {
                    ForEach([StudioSection.query, .coding, .export]) { section in
                        sidebarRow(section)
                    }
                }
                Section {
                    sidebarRow(.project)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("app.name")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            switch selection ?? .overview {
            case .overview: overview
            case .project: project
            case .sources: sources
            case .investigation: investigation
            case .query: query
            case .findings: findings
            case .coding: StudioCodingView(model: model)
            case .export: export
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.snapshot != nil {
                    Button("action.import", systemImage: "plus") {
                        isSourceImporterPresented = true
                    }
                    .disabled(model.isBusy)
                    .help("action.import")
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                }
                Menu("sidebar.project", systemImage: "folder") {
                    Button("action.new-project", systemImage: "folder.badge.plus") {
                        selection = .project
                        Task { await model.createProject() }
                    }
                    Button("action.open-project", systemImage: "folder") {
                        isProjectImporterPresented = true
                    }
                    Button("action.reopen-project", systemImage: "arrow.uturn.backward") {
                        selection = .project
                        Task { await model.reopenLastProject() }
                    }
                    .disabled(model.lastProjectBookmark == nil)
                }
                .disabled(model.isBusy)
                .help("sidebar.project")
            }
        }
        .fileImporter(
            isPresented: $isSourceImporterPresented,
            allowedContentTypes: [.plainText, .markdown],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result, !urls.isEmpty else {
                return
            }
            selection = .sources
            Task { await model.importSources(at: urls) }
        }
        .fileImporter(
            isPresented: $isProjectImporterPresented,
            allowedContentTypes: [.folder, .package],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                return
            }
            guard url.pathExtension.lowercased() == "glifi" else {
                model.reportOpenFailure()
                return
            }
            selection = .project
            Task { await model.openProject(at: url) }
        }
        .fileImporter(
            isPresented: $isExportFolderPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                return
            }
            Task { await model.exportInvestigation(to: url) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.isBusy || model.lastFailure != nil {
                statusBar
            }
        }
        .task(id: documentURL?.path) {
            await model.prepare()
            await model.attachDocument(
                at: documentURL,
                needsPackageInitialization: needsPackageInitialization
            )
        }
    }

    private func sidebarRow(_ section: StudioSection) -> some View {
        Label(section.titleKey, systemImage: section.systemImage)
            .tag(section)
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("home.question")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("home.introduction")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 16) {
                    if let projectURL = model.projectURL {
                        Text(projectURL.deletingPathExtension().lastPathComponent)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Text(nextStepDescription)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { overviewActions }
                            .fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 12) { overviewActions }
                    }
                    .controlSize(.large)
                }

                Divider()

                DisclosureGroup("home.must-progress.title") {
                    VStack(alignment: .leading, spacing: 0) {
                        mustProgressRow(
                            "home.must-progress.project",
                            done: model.mustPathHasProject,
                            section: .project
                        )
                        mustProgressRow(
                            "home.must-progress.sources",
                            done: model.mustPathHasSources,
                            section: .sources
                        )
                        mustProgressRow(
                            "home.must-progress.analysis",
                            done: model.mustPathHasPlanOrCorpus,
                            section: .investigation
                        )
                        mustProgressRow(
                            "home.must-progress.query",
                            done: model.mustPathHasQuery,
                            section: .query
                        )
                        mustProgressRow(
                            "home.must-progress.findings",
                            done: model.mustPathHasFindings,
                            section: .findings
                        )
                        mustProgressRow(
                            "home.must-progress.investigation",
                            done: model.mustPathHasInvestigation,
                            section: .investigation
                        )
                        mustProgressRow(
                            "home.must-progress.export",
                            done: model.mustPathHasExport,
                            section: .export
                        )
                    }
                    .padding(.top, 8)
                }
                .accessibilityElement(children: .contain)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle("sidebar.overview")
    }

    private var nextStepDescription: LocalizedStringKey {
        if model.snapshot == nil { return "home.next.project" }
        if !model.mustPathHasSources { return "home.next.sources" }
        if model.mustPathHasFindings { return "home.next.findings" }
        return "home.next.investigation"
    }

    @ViewBuilder
    private var overviewActions: some View {
        if model.snapshot == nil {
            Button("action.new-project", systemImage: "folder.badge.plus") {
                selection = .project
                Task { await model.createProject() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isBusy)
            Button("action.open-project", systemImage: "folder") {
                isProjectImporterPresented = true
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)
            if model.lastProjectBookmark != nil {
                Button("action.reopen-project", systemImage: "arrow.uturn.backward") {
                    selection = .project
                    Task { await model.reopenLastProject() }
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy)
            }
        } else if !model.mustPathHasSources {
            Button("action.import", systemImage: "plus") {
                isSourceImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isBusy)
        } else if model.mustPathHasFindings {
            Button("home.action.findings", systemImage: "list.bullet.rectangle") {
                selection = .findings
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button("home.action.investigation", systemImage: "arrow.forward") {
                selection = .investigation
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var project: some View {
        Form {
            Section("project.identity") {
                TextField("project.name", text: $model.projectNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.isBusy)
                    .accessibilityLabel("project.name")
                if let projectURL = model.projectURL {
                    LabeledContent("project.path") {
                        Text(projectURL.lastPathComponent)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                if let snapshot = model.snapshot {
                    LabeledContent("project.id") {
                        Text(shortID(snapshot.projectID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("project.generation") {
                        Text(snapshot.generation, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("project.sources") {
                        Text(snapshot.sourceCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("project.artifacts") {
                        Text(snapshot.artifactCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("project.investigation-events") {
                        Text(snapshot.investigationEventCount, format: .number)
                            .monospacedDigit()
                    }
                } else {
                    ContentUnavailableView {
                        Label("project.empty.title", systemImage: "folder")
                    } description: {
                        Text("project.empty.description")
                    }
                }
            }
            Section {
                Button("action.new-project") {
                    Task { await model.createProject() }
                }
                .disabled(model.isBusy)
                Button("action.open-project") {
                    isProjectImporterPresented = true
                }
                .disabled(model.isBusy)
                Button("action.reopen-project") {
                    Task { await model.reopenLastProject() }
                }
                .disabled(model.isBusy || model.lastProjectBookmark == nil)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("sidebar.project")
    }

    @ViewBuilder
    private var sources: some View {
        if model.snapshot == nil {
            ContentUnavailableView {
                Label("sources.needs-project.title", systemImage: "folder.badge.questionmark")
            } description: {
                Text("sources.needs-project.description")
            } actions: {
                Button("action.new-project") {
                    selection = .project
                    Task { await model.createProject() }
                }
                .disabled(model.isBusy)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("sidebar.sources")
        } else {
            List {
                Section {
                    Button("action.import") {
                        isSourceImporterPresented = true
                    }
                    .disabled(model.isBusy)
                    Button("action.analyze-corpus") {
                        Task { await model.analyzeCorpusNow() }
                    }
                    .disabled(model.isBusy || (model.snapshot?.sources.isEmpty ?? true))
                    .accessibilityLabel("action.analyze-corpus")
                    Text("import.allowed-formats")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let lastProfile = model.lastProfile {
                    Section("profile.title") {
                        if let name = model.lastImportedFileName {
                            Text(name).foregroundStyle(.secondary)
                        }
                        LabeledContent("profile.content-digest") {
                            Text(shortID(lastProfile.contentDigest))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        metricRow("metric.bytes", value: lastProfile.utf8ByteCount)
                        metricRow("metric.characters", value: lastProfile.characterCount)
                        metricRow("metric.sentences", value: lastProfile.sentenceCount)
                        metricRow("metric.surface-tokens", value: lastProfile.surfaceTokenCount)
                        metricRow("metric.tokens", value: lastProfile.lexicalTokenCount)
                        metricRow("metric.types", value: lastProfile.typeCount)
                    }
                    Section("profile.top-terms") {
                        ForEach(lastProfile.topTerms.prefix(20)) { frequency in
                            LabeledContent(frequency.term) {
                                Text(frequency.count, format: .number)
                                    .monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let corpus = model.lastCorpusAnalysis {
                    Section("corpus.analysis.title") {
                        metricRow("metric.documents", value: corpus.documentCount)
                        metricRow("metric.characters", value: corpus.characterCount)
                        metricRow("metric.sentences", value: corpus.sentenceCount)
                        metricRow("metric.tokens", value: corpus.lexicalTokenCount)
                        metricRow("metric.types", value: corpus.typeCount)
                        DisclosureGroup("common.provenance") {
                            LabeledContent("corpus.analysis.project-id") {
                                Text(shortID(corpus.projectID))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("corpus.analysis.generation") {
                                Text(corpus.generation, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.analysis.source-generation") {
                                Text(corpus.sourceGeneration, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.analysis.artifact") {
                                Text(shortID(corpus.artifactID))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("corpus.analysis.analysis-node") {
                                Text(shortID(corpus.analysisNodeID))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("corpus.analysis.identifier") {
                                Text(corpus.analysisIdentifier)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("corpus.analysis.digest") {
                                Text(shortID(corpus.corpusDigest))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    StudioDetailsSection("corpus.analysis.contracts") {
                        LabeledContent("corpus.analysis.count-determinism") {
                            Text(corpus.countDeterminismClass)
                                .font(.caption2.monospaced())
                        }
                        LabeledContent("corpus.analysis.fp-determinism") {
                            Text(corpus.floatingPointDeterminismClass)
                                .font(.caption2.monospaced())
                        }
                        LabeledContent("corpus.analysis.numeric-policy") {
                            Text(corpus.numericPolicyIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.tolerance") {
                            Text(
                                corpus.referenceAbsoluteTolerance,
                                format: .number.precision(.fractionLength(6))
                            )
                            .monospacedDigit()
                        }
                        LabeledContent("corpus.analysis.tokenization") {
                            Text(corpus.tokenizationContractIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.normalization") {
                            Text(corpus.normalizationIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.ngram-id") {
                            Text(corpus.ngramIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.dispersion-id") {
                            Text(corpus.dispersionIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.character-unit") {
                            Text(corpus.characterUnitIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        revisionIDList(
                            titleKey: "corpus.analysis.source-revisions",
                            ids: corpus.sourceRevisionIDs
                        )
                    }
                    StudioDetailsSection("corpus.analysis.matrix") {
                        LabeledContent("corpus.analysis.matrix-unit") {
                            Text(corpus.matrix.unitKind)
                                .font(.caption2.monospaced())
                        }
                        LabeledContent("corpus.analysis.matrix-count-id") {
                            Text(corpus.matrix.countIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.matrix-tf-id") {
                            Text(corpus.matrix.tfIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.matrix-idf-id") {
                            Text(corpus.matrix.idfIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.matrix-tfidf-id") {
                            Text(corpus.matrix.tfidfIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.analysis.matrix-terms") {
                            Text(corpus.matrix.terms.count, format: .number)
                                .monospacedDigit()
                        }
                        ForEach(
                            Array(corpus.matrix.terms.prefix(16).enumerated()),
                            id: \.offset
                        ) { index, term in
                            LabeledContent("corpus.analysis.matrix-term") {
                                Text("\(index): \(term)")
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        LabeledContent("corpus.analysis.matrix-cells") {
                            Text(corpus.matrix.cells.count, format: .number)
                                .monospacedDigit()
                        }
                        revisionIDList(
                            titleKey: "corpus.analysis.matrix-rows",
                            ids: corpus.matrix.rowSourceRevisionIDs
                        )
                        ForEach(
                            Array(corpus.matrix.cells.prefix(8).enumerated()),
                            id: \.offset
                        ) { _, cell in
                            VStack(alignment: .leading, spacing: 2) {
                                LabeledContent("corpus.analysis.matrix-cell") {
                                    Text("\(cell.rowIndex),\(cell.columnIndex)")
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("corpus.analysis.matrix-cell-count") {
                                    Text(cell.count, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("corpus.analysis.matrix-cell-tf") {
                                    Text(
                                        cell.tfRaw,
                                        format: .number.precision(.fractionLength(4))
                                    )
                                    .monospacedDigit()
                                }
                                LabeledContent("corpus.analysis.matrix-cell-tfidf") {
                                    Text(
                                        cell.tfidfSmooth,
                                        format: .number.precision(.fractionLength(4))
                                    )
                                    .monospacedDigit()
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Section("corpus.diversity.title") {
                        optionalRatioRow("corpus.diversity.ttr", value: corpus.diversity.ttr)
                        optionalRatioRow("corpus.diversity.msttr", value: corpus.diversity.msttr)
                        optionalRatioRow("corpus.diversity.mattr", value: corpus.diversity.mattr)
                        LabeledContent("corpus.diversity.window") {
                            Text(corpus.diversity.windowSize, format: .number)
                                .monospacedDigit()
                        }
                        LabeledContent("corpus.diversity.sequence-policy") {
                            Text(corpus.diversity.sequencePolicy)
                                .font(.caption2.monospaced())
                        }
                        LabeledContent("corpus.diversity.ttr-id") {
                            Text(corpus.diversity.ttrIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.diversity.msttr-id") {
                            Text(corpus.diversity.msttrIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("corpus.diversity.mattr-id") {
                            Text(corpus.diversity.mattrIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    Section("corpus.analysis.top-terms") {
                        ForEach(corpus.terms.prefix(20)) { term in
                            VStack(alignment: .leading, spacing: 2) {
                                LabeledContent(term.term) {
                                    Text(term.frequency, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("corpus.term.relative") {
                                    Text(
                                        term.relativeFrequency,
                                        format: .number.precision(.fractionLength(6))
                                    )
                                    .monospacedDigit()
                                }
                                LabeledContent("corpus.term.document-frequency") {
                                    Text(term.documentFrequency, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("corpus.term.range") {
                                    Text(term.range, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("corpus.term.gries-dp") {
                                    Text(
                                        term.griesDP,
                                        format: .number.precision(.fractionLength(4))
                                    )
                                    .monospacedDigit()
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    if !corpus.ngrams.isEmpty {
                        Section("corpus.analysis.ngrams") {
                            ForEach(corpus.ngrams.prefix(20)) { ngram in
                                VStack(alignment: .leading, spacing: 2) {
                                    LabeledContent(ngram.values.joined(separator: " ")) {
                                        Text(ngram.count, format: .number)
                                            .monospacedDigit()
                                    }
                                    LabeledContent("corpus.ngram.order") {
                                        Text(ngram.values.count, format: .number)
                                            .monospacedDigit()
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    if let options = model.lastCorpusOptions {
                        StudioDetailsSection("corpus.options.title") {
                            LabeledContent("corpus.options.diversity-window") {
                                Text(options.diversityWindowSize, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.options.ngram-sizes") {
                                Text(
                                    options.ngramSizes.map(String.init).joined(separator: ", ")
                                )
                                .font(.caption.monospaced())
                            }
                            LabeledContent("corpus.options.max-documents") {
                                Text(options.maximumDocumentCount, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.options.max-source-bytes") {
                                Text(options.maximumSourceByteCount, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.options.max-vocabulary") {
                                Text(options.maximumVocabularySize, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.options.max-ngrams") {
                                Text(options.maximumDistinctNGramCount, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("corpus.options.max-nonzero-cells") {
                                Text(options.maximumNonZeroCellCount, format: .number)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                if let snapshot = model.snapshot, !snapshot.sources.isEmpty {
                    StudioDetailsSection("sources.revisions") {
                        ForEach(snapshot.sources) { source in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(shortID(source.sourceRevisionID))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                LabeledContent("sources.source-id") {
                                    Text(shortID(source.sourceID))
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                                Text(
                                    source.format == .markdown
                                        ? "format.markdown" : "format.plain-text"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                LabeledContent("sources.content-digest") {
                                    Text(shortID(source.contentDigest))
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                                LabeledContent("sources.bytes") {
                                    Text(source.byteCount, format: .number)
                                        .monospacedDigit()
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .navigationTitle("sidebar.sources")
        }
    }

    private var investigation: some View {
        Form {
            Section("investigation.question") {
                TextField(
                    "investigation.question-prompt", text: $model.questionDraft, axis: .vertical
                )
                .lineLimit(3...6)
                .disabled(model.isBusy || model.snapshot == nil)
                .accessibilityLabel("investigation.question-prompt")
                Picker("investigation.intent", selection: $model.selectedIntent) {
                    ForEach(StudioIntentOption.allCases) { intent in
                        Text(LocalizedStringKey(intent.titleKey)).tag(intent)
                    }
                }
                .disabled(model.isBusy || model.snapshot == nil)
                .accessibilityLabel("investigation.intent")
            }

            if let snapshot = model.snapshot, model.selectedIntent.usesComparisonGroups {
                Section("investigation.compare-groups") {
                    ForEach(snapshot.sources) { source in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(shortID(source.sourceRevisionID))
                                .font(.caption.monospaced())
                            ViewThatFits(in: .horizontal) {
                                HStack { comparisonActions(for: source.sourceRevisionID) }
                                    .fixedSize(horizontal: true, vertical: false)
                                VStack(alignment: .leading) {
                                    comparisonActions(for: source.sourceRevisionID)
                                }
                            }
                        }
                    }
                    Button("action.compare-keyness") {
                        Task { await model.compareKeynessNow() }
                    }
                    .disabled(
                        model.isBusy
                            || model.selectedTargetRevisionIDs.isEmpty
                            || model.selectedReferenceRevisionIDs.isEmpty
                    )
                    .accessibilityLabel("action.compare-keyness")
                }
            }

            if let keyness = model.lastKeyness {
                Section("keyness.title") {
                    LabeledContent("keyness.target-tokens") {
                        Text(keyness.targetTokenCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("keyness.reference-tokens") {
                        Text(keyness.referenceTokenCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("keyness.term-count") {
                        Text(keyness.terms.count, format: .number)
                            .monospacedDigit()
                    }
                    DisclosureGroup("common.provenance") {
                        LabeledContent("keyness.artifact") {
                            Text(shortID(keyness.artifactID))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("keyness.analysis-node") {
                            Text(shortID(keyness.analysisNodeID))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("keyness.generation") {
                            Text(keyness.generation, format: .number)
                                .monospacedDigit()
                        }
                        LabeledContent("keyness.comparison-id") {
                            Text(keyness.comparisonIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("keyness.comparison-digest") {
                            Text(shortID(keyness.comparisonDigest))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("keyness.target-digest") {
                            Text(shortID(keyness.targetCorpusDigest))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("keyness.reference-digest") {
                            Text(shortID(keyness.referenceCorpusDigest))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        revisionIDList(
                            titleKey: "keyness.target-revisions",
                            ids: keyness.targetSourceRevisionIDs
                        )
                        revisionIDList(
                            titleKey: "keyness.reference-revisions",
                            ids: keyness.referenceSourceRevisionIDs
                        )
                        LabeledContent("keyness.project-id") {
                            Text(shortID(keyness.projectID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("keyness.source-generation") {
                            Text(keyness.sourceGeneration, format: .number)
                                .monospacedDigit()
                        }
                    }
                }
                StudioDetailsSection("keyness.contracts") {
                    LabeledContent("keyness.test-id") {
                        Text(keyness.testIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.pvalue-id") {
                        Text(keyness.pValueIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.correction-id") {
                        Text(keyness.correctionIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.odds-ratio-id") {
                        Text(keyness.oddsRatioIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.log-ratio-id") {
                        Text(keyness.logRatioIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.diagnostic-id") {
                        Text(keyness.diagnosticIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.ordering-id") {
                        Text(keyness.orderingIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("keyness.low-expected-threshold") {
                        Text(
                            keyness.lowExpectedCountThreshold,
                            format: .number.precision(.fractionLength(2))
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("keyness.tolerance") {
                        Text(
                            keyness.referenceAbsoluteTolerance,
                            format: .number.precision(.fractionLength(6))
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("keyness.fp-determinism") {
                        Text(keyness.floatingPointDeterminismClass)
                            .font(.caption2.monospaced())
                    }
                    LabeledContent("keyness.numeric-policy") {
                        Text(keyness.numericPolicyIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                }
                Section("keyness.top-terms") {
                    ForEach(keyness.terms.prefix(20)) { term in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(term.term)
                                .font(.body.weight(.medium))
                            LabeledContent("keyness.direction") {
                                Text(term.direction)
                                    .font(.caption.monospaced())
                            }
                            LabeledContent("keyness.target-frequency") {
                                Text(term.targetFrequency, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("keyness.reference-frequency") {
                                Text(term.referenceFrequency, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("keyness.target-relative") {
                                Text(
                                    term.targetRelativeFrequency,
                                    format: .number.precision(.fractionLength(6))
                                )
                                .monospacedDigit()
                            }
                            LabeledContent("keyness.reference-relative") {
                                Text(
                                    term.referenceRelativeFrequency,
                                    format: .number.precision(.fractionLength(6))
                                )
                                .monospacedDigit()
                            }
                            LabeledContent("keyness.g-statistic") {
                                Text(term.gStatistic, format: .number.precision(.fractionLength(2)))
                                    .monospacedDigit()
                            }
                            LabeledContent("keyness.df") {
                                Text(term.degreesOfFreedom, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("keyness.p-value") {
                                Text(term.pValue, format: .number.precision(.fractionLength(4)))
                                    .monospacedDigit()
                            }
                            LabeledContent("keyness.q-value") {
                                Text(term.qValue, format: .number.precision(.fractionLength(4)))
                                    .monospacedDigit()
                            }
                            LabeledContent("keyness.odds-ratio") {
                                Text(
                                    term.oddsRatioHaldaneAnscombe,
                                    format: .number.precision(.fractionLength(3))
                                )
                                .monospacedDigit()
                            }
                            LabeledContent("keyness.log2-ratio") {
                                Text(
                                    term.log2RatioHaldaneAnscombe,
                                    format: .number.precision(.fractionLength(2))
                                )
                                .monospacedDigit()
                            }
                            LabeledContent("keyness.min-expected") {
                                Text(
                                    term.minimumExpectedCount,
                                    format: .number.precision(.fractionLength(2))
                                )
                                .monospacedDigit()
                            }
                            LabeledContent("keyness.low-expected") {
                                Text(term.hasLowExpectedCount ? "common.yes" : "common.no")
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let options = model.lastKeynessOptions {
                    StudioDetailsSection("keyness.options.title") {
                        LabeledContent("keyness.options.max-hypotheses") {
                            Text(options.maximumHypothesisCount, format: .number)
                                .monospacedDigit()
                        }
                        LabeledContent("keyness.options.low-expected-threshold") {
                            Text(
                                options.lowExpectedCountThreshold,
                                format: .number.precision(.fractionLength(2))
                            )
                            .monospacedDigit()
                        }
                    }
                }
            }

            Section {
                Button("action.plan") {
                    Task { await model.planInvestigation() }
                }
                .disabled(model.isBusy || model.snapshot == nil)
                Button("action.execute") {
                    Task { await model.executePlan() }
                }
                .disabled(model.isBusy || model.snapshot == nil)
                if model.canCancelExecution {
                    Button("action.cancel-execution", role: .cancel) {
                        model.cancelExecution()
                    }
                    if let operationID = model.activeExecutionOperationID {
                        LabeledContent("execution.active-operation-id") {
                            Text(shortID(operationID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
                Button("action.save-investigation") {
                    Task { await model.createInvestigationFromExecution() }
                }
                .disabled(model.isBusy || model.executionResult == nil)
            }

            if !model.investigationHeads.isEmpty {
                Section("investigation.heads") {
                    ForEach(model.investigationHeads, id: \.headEventID) { head in
                        Button {
                            model.selectInvestigationHead(head)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(head.question)
                                    .lineLimit(2)
                                LabeledContent("investigation.heads.id") {
                                    Text(shortID(head.id))
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("investigation.heads.head-event") {
                                    Text(shortID(head.headEventID))
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("investigation.heads.intent") {
                                    Text(head.intent)
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("investigation.heads.language") {
                                    Text(head.languageCode)
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("investigation.heads.selected-findings") {
                                    Text(head.selectedFindingIDs.count, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("investigation.heads.available-findings") {
                                    Text(head.availableFindingIDs.count, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("investigation.heads.events") {
                                    Text(head.eventIDs.count, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("investigation.heads.plan-artifact") {
                                    Text(shortID(head.planArtifactID))
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("investigation.heads.interpretation-artifact") {
                                    Text(shortID(head.interpretationArtifactID))
                                        .font(.caption2.monospaced())
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("investigation.heads")
                        .accessibilityAddTraits(
                            model.investigation?.headEventID == head.headEventID
                                ? AccessibilityTraits.isSelected
                                : AccessibilityTraits()
                        )
                    }
                    Button("action.refresh-heads") {
                        Task { await model.refreshInvestigationHeads() }
                    }
                    .disabled(model.isBusy)
                }
            }

            if let request = model.lastPlanRequest {
                StudioDetailsSection("plan.request") {
                    LabeledContent("plan.request.intent") {
                        Text(request.intent)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("plan.request.work-budget") {
                        Text(request.maximumEstimatedWorkUnits, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("plan.request.scope-count") {
                        Text(request.scopeSourceRevisionIDs.count, format: .number)
                            .monospacedDigit()
                    }
                    revisionIDList(
                        titleKey: "plan.request.scope",
                        ids: request.scopeSourceRevisionIDs
                    )
                    LabeledContent("plan.request.target-count") {
                        Text(request.targetSourceRevisionIDs.count, format: .number)
                            .monospacedDigit()
                    }
                    revisionIDList(
                        titleKey: "plan.request.target",
                        ids: request.targetSourceRevisionIDs
                    )
                    LabeledContent("plan.request.reference-count") {
                        Text(request.referenceSourceRevisionIDs.count, format: .number)
                            .monospacedDigit()
                    }
                    revisionIDList(
                        titleKey: "plan.request.reference",
                        ids: request.referenceSourceRevisionIDs
                    )
                }
            }

            if let plan = model.planResult {
                Section("plan.title") {
                    LabeledContent("plan.status") {
                        Text(LocalizedStringKey("plan.status.\(plan.plan.status)"))
                    }
                    LabeledContent("plan.project-id") {
                        Text(shortID(plan.projectID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.artifact") {
                        Text(shortID(plan.artifactID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.analysis-node") {
                        Text(shortID(plan.analysisNodeID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.planner") {
                        Text(plan.plan.plannerIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.capability-catalog") {
                        Text(plan.plan.capabilityCatalogIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.intent") {
                        Text(plan.plan.intent)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("plan.generation") {
                        Text(plan.generation, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("plan.source-generation") {
                        Text(plan.sourceGeneration, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("plan.work-units") {
                        Text(plan.plan.totalEstimatedWorkUnits, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("plan.work-budget") {
                        Text(plan.plan.maximumEstimatedWorkUnits, format: .number)
                            .monospacedDigit()
                    }
                }
                StudioDetailsSection("plan.scope") {
                    revisionIDList(
                        titleKey: "plan.scope.resolved",
                        ids: plan.plan.resolvedScopeSourceRevisionIDs
                    )
                    revisionIDList(
                        titleKey: "plan.scope.target",
                        ids: plan.plan.targetSourceRevisionIDs
                    )
                    revisionIDList(
                        titleKey: "plan.scope.reference",
                        ids: plan.plan.referenceSourceRevisionIDs
                    )
                }
                StudioDetailsSection("plan.collection-profile") {
                    let profile = plan.plan.collectionProfile
                    LabeledContent("plan.sources") {
                        Text(profile.sourceCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("plan.source-bytes") {
                        Text(profile.totalSourceByteCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("plan.language") {
                        Text(profile.configuredLanguageCode)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("plan.observation-class") {
                        Text(profile.observationClassIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.profile-id") {
                        Text(profile.profileIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("plan.source-root-digest") {
                        Text(shortID(profile.sourceRootDigest))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    revisionIDList(
                        titleKey: "plan.profile.revisions",
                        ids: profile.sourceRevisionIDs
                    )
                    ForEach(profile.formatCounts, id: \.formatIdentifier) { formatCount in
                        VStack(alignment: .leading, spacing: 2) {
                            LabeledContent(formatCount.formatIdentifier) {
                                Text(formatCount.sourceCount, format: .number)
                                    .monospacedDigit()
                            }
                            LabeledContent("plan.format.bytes") {
                                Text(formatCount.byteCount, format: .number)
                                    .monospacedDigit()
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section("plan.steps") {
                    ForEach(Array(plan.plan.steps.enumerated()), id: \.element.identifier) {
                        _, step in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("\(step.order + 1). \(step.capabilityIdentifier)") {
                                Text(step.operation)
                                    .font(.caption.monospaced())
                            }
                            LabeledContent("plan.step.id") {
                                Text(step.identifier)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("plan.step.role") {
                                Text(step.role)
                                    .font(.caption2.monospaced())
                            }
                            LabeledContent("plan.step.work-units") {
                                Text(step.estimatedWorkUnits, format: .number)
                                    .monospacedDigit()
                            }
                            Text(step.outputSchemaIdentifier)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            if !step.dependencyStepIdentifiers.isEmpty {
                                ForEach(
                                    step.dependencyStepIdentifiers.prefix(6),
                                    id: \.self
                                ) { dependency in
                                    LabeledContent("plan.step.dependency") {
                                        Text(dependency)
                                            .font(.caption2.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            revisionIDList(
                                titleKey: "plan.step.sources",
                                ids: step.sourceRevisionIDs
                            )
                            ForEach(step.caveatIdentifiers.prefix(4), id: \.self) { caveat in
                                LabeledContent("plan.step.caveat") {
                                    Text(caveat)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section("plan.decisions") {
                    ForEach(Array(plan.plan.decisions.enumerated()), id: \.offset) { _, decision in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(decision.capabilityIdentifier) {
                                Text(
                                    LocalizedStringKey(
                                        "plan.applicability.\(decision.applicability)")
                                )
                                .font(.caption)
                            }
                            LabeledContent("plan.decision.included") {
                                Text(decision.isIncluded ? "common.yes" : "common.no")
                            }
                            if let work = decision.estimatedWorkUnits {
                                LabeledContent("plan.step.work-units") {
                                    Text(work, format: .number)
                                        .monospacedDigit()
                                }
                            }
                            if let backend = decision.selectedBackendIdentifier {
                                LabeledContent("plan.decision.backend") {
                                    Text(backend)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            ForEach(decision.fallbackIdentifiers.prefix(4), id: \.self) {
                                fallback in
                                LabeledContent("plan.decision.fallback") {
                                    Text(fallback)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            ForEach(decision.reasonIdentifiers.prefix(4), id: \.self) { reason in
                                Text(reason)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(decision.caveatIdentifiers.prefix(4), id: \.self) { caveat in
                                LabeledContent("plan.decision.caveat") {
                                    Text(caveat)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if !plan.plan.unresolvedReasonIdentifiers.isEmpty {
                    Section("plan.unresolved") {
                        ForEach(plan.plan.unresolvedReasonIdentifiers, id: \.self) { reason in
                            Text(reason)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let progress = model.executionProgress {
                Section("execution.progress") {
                    ProgressView(
                        value: Double(progress.completed),
                        total: Double(progress.total ?? max(progress.completed, 1))
                    )
                    LabeledContent("execution.progress.phase") {
                        Text(progress.phase)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("execution.progress.completed") {
                        Text(progress.completed, format: .number)
                            .monospacedDigit()
                    }
                    if let total = progress.total {
                        LabeledContent("execution.progress.total") {
                            Text(total, format: .number)
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("execution.progress.unit") {
                        Text(progress.unit)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("execution.progress.estimate-quality") {
                        Text(progress.estimateQuality)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("execution.progress.revision") {
                        Text(progress.revision, format: .number)
                            .monospacedDigit()
                    }
                    if let step = progress.planStepIdentifier {
                        LabeledContent("execution.progress.plan-step") {
                            Text(step)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    if let node = progress.analysisNodeID {
                        LabeledContent("execution.progress.analysis-node") {
                            Text(shortID(node))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("execution.operation-id") {
                        Text(shortID(progress.operationID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("execution.progress")
            }

            if let execution = model.executionResult {
                Section("execution.terminal") {
                    LabeledContent("execution.terminal-state") {
                        Text(execution.terminalState)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("execution.project-id") {
                        Text(shortID(execution.projectID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.plan-status") {
                        Text(LocalizedStringKey("plan.status.\(execution.planStatus)"))
                    }
                    LabeledContent("execution.operating-profile") {
                        Text(execution.operatingProfile)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("execution.maximum-parallelism") {
                        Text(execution.maximumParallelism, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("execution.estimated-work-units") {
                        Text(execution.estimatedWorkUnits, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("execution.completed-work-units") {
                        Text(execution.completedWorkUnits, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("execution.generation") {
                        Text(execution.generation, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("execution.source-generation") {
                        Text(execution.sourceGeneration, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("execution.operation-id") {
                        Text(shortID(execution.operationID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                }
                StudioDetailsSection("execution.artifacts") {
                    LabeledContent("execution.plan-artifact") {
                        Text(shortID(execution.planArtifactID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.plan-analysis-node") {
                        Text(shortID(execution.planAnalysisNodeID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.interpretation-artifact") {
                        Text(shortID(execution.interpretationArtifactID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.interpretation-analysis-node") {
                        Text(shortID(execution.interpretationAnalysisNodeID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    ForEach(execution.artifacts, id: \.artifactID) { artifact in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artifact.operation)
                                .font(.caption.monospaced())
                            LabeledContent("execution.artifact.role") {
                                Text(artifact.role)
                                    .font(.caption2.monospaced())
                            }
                            LabeledContent("execution.artifact.plan-step") {
                                Text(artifact.planStepIdentifier)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("execution.artifact.schema") {
                                Text(artifact.outputSchemaIdentifier)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("execution.artifact.analysis-node") {
                                Text(shortID(artifact.analysisNodeID))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            Text(shortID(artifact.artifactID))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section("execution.interpretation") {
                    let interpretation = execution.interpretation
                    LabeledContent("execution.rule-catalog") {
                        Text(interpretation.ruleCatalogIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.ranking-policy") {
                        Text(interpretation.rankingIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.interpretation.intent") {
                        Text(interpretation.intent)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("execution.interpretation.plan-artifact") {
                        Text(shortID(interpretation.planArtifactID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.interpretation.plan-node") {
                        Text(shortID(interpretation.planAnalysisNodeID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("execution.findings-count") {
                        Text(interpretation.findings.count, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("execution.evidence-count") {
                        Text(interpretation.evidence.count, format: .number)
                            .monospacedDigit()
                    }
                    if !interpretation.sourceArtifactIDs.isEmpty {
                        ForEach(
                            interpretation.sourceArtifactIDs.prefix(6),
                            id: \.self
                        ) { artifactID in
                            LabeledContent("execution.interpretation.source-artifact") {
                                Text(shortID(artifactID))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    if !interpretation.suppressionSummaries.isEmpty {
                        ForEach(
                            Array(interpretation.suppressionSummaries.enumerated()),
                            id: \.offset
                        ) { _, suppression in
                            LabeledContent(suppression.reasonIdentifier) {
                                Text(suppression.count, format: .number)
                                    .monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }

            if let investigation = model.investigation {
                Section("investigation.saved") {
                    LabeledContent("investigation.id") {
                        Text(shortID(investigation.id))
                            .font(.caption.monospaced())
                    }
                    LabeledContent("investigation.head") {
                        Text(shortID(investigation.headEventID))
                            .font(.caption.monospaced())
                    }
                    if let projectID = model.lastInvestigationProjectID {
                        LabeledContent("investigation.project-id") {
                            Text(shortID(projectID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    if let generation = model.lastInvestigationGeneration {
                        LabeledContent("investigation.generation") {
                            Text(generation, format: .number)
                                .monospacedDigit()
                        }
                    }
                    LabeledContent("investigation.intent") {
                        Text(investigation.intent)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("investigation.language") {
                        Text(investigation.languageCode)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("investigation.plan-artifact") {
                        Text(shortID(investigation.planArtifactID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("investigation.interpretation-artifact") {
                        Text(shortID(investigation.interpretationArtifactID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    Text(investigation.question)
                }
                if let request = model.lastInvestigationCreationRequest {
                    StudioDetailsSection("investigation.creation-request") {
                        LabeledContent("investigation.creation-request.schema") {
                            Text(request.schemaIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("investigation.creation-request.schema-version") {
                            Text(request.schemaVersion, format: .number)
                                .monospacedDigit()
                        }
                        LabeledContent("investigation.creation-request.language") {
                            Text(request.languageCode)
                                .font(.caption.monospaced())
                        }
                        LabeledContent("investigation.creation-request.interpretation-artifact") {
                            Text(shortID(request.interpretationArtifactID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        if let selected = request.selectedFindingIDs {
                            LabeledContent("investigation.creation-request.selected-count") {
                                Text(selected.count, format: .number)
                                    .monospacedDigit()
                            }
                            ForEach(selected.prefix(8), id: \.self) { findingID in
                                LabeledContent(
                                    "investigation.creation-request.selected-finding"
                                ) {
                                    Text(shortID(findingID))
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        } else {
                            Text("investigation.creation-request.all-findings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(request.question)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let request = model.lastInvestigationSelectionRequest {
                    StudioDetailsSection("investigation.selection-request") {
                        LabeledContent("investigation.selection-request.schema") {
                            Text(request.schemaIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("investigation.selection-request.schema-version") {
                            Text(request.schemaVersion, format: .number)
                                .monospacedDigit()
                        }
                        LabeledContent("investigation.selection-request.investigation-id") {
                            Text(shortID(request.investigationID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("investigation.selection-request.predecessor") {
                            Text(shortID(request.predecessorEventID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("investigation.selection-request.reason") {
                            Text(request.reasonIdentifier)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("investigation.selection-request.selected-count") {
                            Text(request.selectedFindingIDs.count, format: .number)
                                .monospacedDigit()
                        }
                        ForEach(request.selectedFindingIDs.prefix(8), id: \.self) { findingID in
                            LabeledContent("investigation.selection-request.selected-finding") {
                                Text(shortID(findingID))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                Section("investigation.history") {
                    ForEach(Array(investigation.eventIDs.enumerated()), id: \.offset) {
                        index, eventID in
                        LabeledContent("\(index + 1)") {
                            Text(shortID(eventID))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    LabeledContent("investigation.selected-findings") {
                        Text(investigation.selectedFindingIDs.count, format: .number)
                            .monospacedDigit()
                    }
                    ForEach(
                        investigation.selectedFindingIDs.prefix(8),
                        id: \.self
                    ) { findingID in
                        LabeledContent("investigation.selected-finding") {
                            Text(shortID(findingID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("investigation.available-findings") {
                        Text(investigation.availableFindingIDs.count, format: .number)
                            .monospacedDigit()
                    }
                    ForEach(
                        investigation.availableFindingIDs.prefix(8),
                        id: \.self
                    ) { findingID in
                        LabeledContent("investigation.available-finding") {
                            Text(shortID(findingID))
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("sidebar.investigation")
        .disabled(model.snapshot == nil && !model.isBusy)
    }

    private func comparisonActions(for revisionID: String) -> some View {
        Group {
            Button {
                model.toggleTarget(revisionID)
            } label: {
                Label(
                    "group.target",
                    systemImage: model.selectedTargetRevisionIDs.contains(revisionID)
                        ? "checkmark.circle.fill" : "circle"
                )
            }
            .accessibilityValue(
                Text(
                    model.selectedTargetRevisionIDs.contains(revisionID)
                        ? "common.yes" : "common.no")
            )
            Button {
                model.toggleReference(revisionID)
            } label: {
                Label(
                    "group.reference",
                    systemImage: model.selectedReferenceRevisionIDs.contains(revisionID)
                        ? "checkmark.circle.fill" : "circle"
                )
            }
            .accessibilityValue(
                Text(
                    model.selectedReferenceRevisionIDs.contains(revisionID)
                        ? "common.yes" : "common.no")
            )
        }
        .buttonStyle(.bordered)
        .disabled(model.isBusy)
    }

    private var query: some View {
        Form {
            Section("query.editor") {
                TextField("query.placeholder", text: $model.queryDraft)
                    .disabled(model.isBusy || model.snapshot == nil)
                    .accessibilityLabel("query.placeholder")
                Button("action.search") {
                    Task { await model.runQuery() }
                }
                .disabled(model.isBusy || model.snapshot == nil)
            }
            if let queryResult = model.queryResult {
                Section("query.results") {
                    if let expression = model.lastQueryExpression {
                        LabeledContent("query.expression") {
                            Text(expression)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("query.matches") {
                        Text(queryResult.matches.count, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("query.matched-sources") {
                        Text(queryResult.matchedSourceCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("query.project-id") {
                        Text(shortID(queryResult.projectID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("query.generation") {
                        Text(queryResult.generation, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("query.digest") {
                        Text(shortID(queryResult.queryDigest))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    if queryResult.isTruncated {
                        Text("query.truncated")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(queryResult.matches) { match in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Task { await model.selectQueryMatch(match) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(
                                        kwicAttributedString(
                                            leftContext: match.leftContext,
                                            match: match.match,
                                            rightContext: match.rightContext
                                        )
                                    )
                                    .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("query.match.accessibility")
                            .accessibilityValue(
                                Text(
                                    kwicAttributedString(
                                        leftContext: match.leftContext,
                                        match: match.match,
                                        rightContext: match.rightContext
                                    )
                                )
                            )
                            .accessibilityAddTraits(
                                model.selectedQueryMatchID == match.id
                                    ? AccessibilityTraits.isSelected
                                    : AccessibilityTraits()
                            )
                            DisclosureGroup("common.provenance") {
                                LabeledContent("query.match.id") {
                                    Text(shortID(match.id))
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                                LabeledContent("query.match.source-revision") {
                                    Text(shortID(match.sourceRevisionID))
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                                LabeledContent("query.coordinate-space") {
                                    Text(match.coordinateSpace)
                                        .font(.caption2.monospaced())
                                }
                                LabeledContent("query.match.start-utf8") {
                                    Text(match.startUTF8, format: .number)
                                        .monospacedDigit()
                                }
                                LabeledContent("query.match.end-utf8") {
                                    Text(match.endUTF8, format: .number)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            if let sourceText = model.sourceText, let match = model.selectedQueryMatch {
                Section("query.source") {
                    Text(shortID(sourceText.sourceRevisionID))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    LabeledContent("query.source.bytes") {
                        Text(sourceText.byteCount, format: .number)
                            .monospacedDigit()
                    }
                    highlightedSource(sourceText.text, ranges: match.sourceRanges)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .accessibilityLabel("query.source")
                    ForEach(Array(match.sourceRanges.enumerated()), id: \.offset) { _, range in
                        LabeledContent("source.bytes") {
                            Text("\(range.start)–\(range.end)")
                                .font(.caption2.monospaced())
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("sidebar.query")
    }

    private var findings: some View {
        Group {
            if let insufficient = model.insufficientEvidence, model.findings.isEmpty {
                Form {
                    Section {
                        ContentUnavailableView {
                            Label(
                                "findings.insufficient.title",
                                systemImage: "exclamationmark.bubble"
                            )
                        } description: {
                            Text(LocalizedStringKey(insufficient.messageKey))
                        }
                    }
                    StudioDetailsSection("findings.insufficient.meta") {
                        LabeledContent("findings.insufficient.message-key") {
                            Text(insufficient.messageKey)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    Section("findings.insufficient.reasons") {
                        ForEach(insufficient.reasonIdentifiers, id: \.self) { reason in
                            Text(reason)
                                .font(.caption.monospaced())
                        }
                    }
                    if !insufficient.messageArguments.isEmpty {
                        StudioDetailsSection("findings.insufficient.arguments") {
                            ForEach(
                                insufficient.messageArguments.keys.sorted(),
                                id: \.self
                            ) { key in
                                LabeledContent(key) {
                                    Text(insufficient.messageArguments[key] ?? "")
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    if !insufficient.caveats.isEmpty {
                        Section("finding.caveats") {
                            ForEach(
                                Array(insufficient.caveats.enumerated()),
                                id: \.offset
                            ) { _, caveat in
                                caveatRow(caveat)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else if model.findings.isEmpty {
                ContentUnavailableView {
                    Label("findings.empty.title", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("findings.empty.description")
                }
            } else {
                GeometryReader { geometry in
                    if geometry.size.width >= 760 && !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: 0) {
                            findingList
                                .frame(width: 280)
                            Divider()
                            if let finding = model.selectedFinding {
                                findingDetail(finding)
                            }
                        }
                    } else {
                        NavigationStack {
                            List(model.findings, id: \.id) { finding in
                                NavigationLink {
                                    findingDetail(finding)
                                        .onAppear { model.selectFinding(id: finding.id) }
                                } label: {
                                    findingSummary(finding)
                                }
                            }
                            .navigationTitle("sidebar.findings")
                        }
                    }
                }
            }
        }
        .navigationTitle("sidebar.findings")
    }

    private var findingList: some View {
        List(
            model.findings, id: \.id,
            selection: Binding(
                get: { model.selectedFinding?.id },
                set: { if let value = $0 { model.selectFinding(id: value) } }
            )
        ) { finding in
            findingSummary(finding)
                .tag(finding.id)
        }
    }

    private func findingSummary(_ finding: GlifiStudioFinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(finding.localizedMessage(locale: locale))
                .fixedSize(horizontal: false, vertical: true)
            Text(finding.supportClassLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func findingDetail(_ finding: GlifiStudioFinding) -> some View {
        Form {
            Section("finding.proposition") {
                Text(finding.localizedMessage(locale: locale))
                DisclosureGroup("common.provenance") {
                    LabeledContent("finding.id") {
                        Text(shortID(finding.id))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("finding.family") {
                        Text(finding.familyIdentifier)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("finding.type") {
                        Text(finding.typeIdentifier)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("finding.subject") {
                        Text(finding.subjectIdentifier)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("finding.predicate") {
                        Text(finding.predicateIdentifier)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("finding.object") {
                        Text(finding.objectIdentifier)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("finding.scope") {
                        Text(finding.scopeIdentifier)
                            .font(.caption.monospaced())
                    }
                    if let direction = finding.directionIdentifier {
                        LabeledContent("finding.direction") {
                            Text(direction)
                                .font(.caption.monospaced())
                        }
                    }
                    LabeledContent("finding.state") {
                        Text(finding.state)
                    }
                    LabeledContent("finding.epistemic") {
                        Text(finding.epistemicCategory)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("finding.rule-set") {
                        Text(finding.ruleSetIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    ForEach(
                        finding.messageArguments.keys.sorted(),
                        id: \.self
                    ) { key in
                        LabeledContent(key) {
                            Text(finding.messageArguments[key] ?? "")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            Section("finding.assessment") {
                LabeledContent("finding.support-class") {
                    Text(finding.assessment.supportClass)
                        .font(.caption.monospaced())
                }
                LabeledContent("finding.support-policy") {
                    Text(finding.assessment.policyIdentifier)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
                ForEach(finding.assessment.rationaleIdentifiers, id: \.self) { rationale in
                    Text(rationale)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                ForEach(finding.assessment.dimensions, id: \.identifier) { dimension in
                    VStack(alignment: .leading, spacing: 2) {
                        LabeledContent(dimension.identifier) {
                            Text(evidenceValueText(dimension.value))
                                .font(.caption.monospacedDigit())
                        }
                        Text(dimension.outcomeIdentifier)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section("finding.caveats") {
                if finding.caveats.isEmpty {
                    Text("finding.caveats.none")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(finding.caveats.enumerated()), id: \.offset) { _, caveat in
                        caveatRow(caveat)
                    }
                }
            }
            StudioDetailsSection("finding.evidence-references") {
                if finding.evidenceReferences.isEmpty {
                    Text("finding.evidence.none")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("finding.evidence-references.count") {
                        Text(finding.evidenceReferences.count, format: .number)
                            .monospacedDigit()
                    }
                    ForEach(
                        Array(finding.evidenceReferences.enumerated()),
                        id: \.offset
                    ) { _, reference in
                        VStack(alignment: .leading, spacing: 2) {
                            LabeledContent("finding.evidence-references.id") {
                                Text(shortID(reference.evidenceID))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("finding.evidence.disposition") {
                                Text(
                                    LocalizedStringKey(
                                        "evidence.disposition.\(reference.disposition)")
                                )
                                .font(.caption)
                            }
                            if let reason = reference.reasonIdentifier {
                                LabeledContent("finding.evidence.disposition-reason") {
                                    Text(reason)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Section("finding.evidence") {
                if model.evidenceForSelectedFinding.isEmpty {
                    Text("finding.evidence.none")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.evidenceForSelectedFinding, id: \.id) { evidence in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(evidence.kindIdentifier)
                                .font(.caption.monospaced())
                            Text(shortID(evidence.id))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            if let disposition = model.evidenceDisposition(for: evidence.id) {
                                LabeledContent("finding.evidence.disposition") {
                                    Text(LocalizedStringKey("evidence.disposition.\(disposition)"))
                                        .font(.caption)
                                }
                            }
                            if let reason = model.evidenceDispositionReason(for: evidence.id) {
                                LabeledContent("finding.evidence.disposition-reason") {
                                    Text(reason)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            LabeledContent("finding.evidence.validity") {
                                Text(evidence.validity)
                                    .font(.caption.monospaced())
                            }
                            LabeledContent("finding.evidence.epistemic") {
                                Text(evidence.epistemicCategory)
                                    .font(.caption.monospaced())
                            }
                            LabeledContent("finding.evidence.analysis-node") {
                                Text(shortID(evidence.analysisNodeID))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            LabeledContent("finding.evidence.descriptor-digest") {
                                Text(shortID(evidence.descriptorDigest))
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                            }
                            ForEach(evidence.artifactIDs.prefix(4), id: \.self) { artifactID in
                                LabeledContent("finding.evidence.artifact") {
                                    Text(shortID(artifactID))
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            if !evidence.methodIdentifiers.isEmpty {
                                ForEach(evidence.methodIdentifiers.prefix(6), id: \.self) {
                                    method in
                                    LabeledContent("finding.evidence.method") {
                                        Text(method)
                                            .font(.caption2.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            ForEach(
                                evidence.uncertaintyIdentifiers.prefix(4),
                                id: \.self
                            ) { identifier in
                                LabeledContent("finding.evidence.uncertainty") {
                                    Text(identifier)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            ForEach(
                                evidence.effectSizeIdentifiers.prefix(4),
                                id: \.self
                            ) { identifier in
                                LabeledContent("finding.evidence.effect-size") {
                                    Text(identifier)
                                        .font(.caption2.monospaced())
                                        .textSelection(.enabled)
                                }
                            }
                            ForEach(evidence.measures.prefix(8), id: \.identifier) { measure in
                                VStack(alignment: .leading, spacing: 2) {
                                    LabeledContent(measure.identifier) {
                                        Text(evidenceMeasureText(measure))
                                            .font(.caption.monospacedDigit())
                                    }
                                    LabeledContent("finding.evidence.measure-type") {
                                        Text(measure.value.type)
                                            .font(.caption2.monospaced())
                                    }
                                    if let unit = measure.unitIdentifier, !unit.isEmpty {
                                        LabeledContent("finding.evidence.measure-unit") {
                                            Text(unit)
                                                .font(.caption2.monospaced())
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                            ForEach(
                                Array(evidence.sourceReferences.prefix(3).enumerated()),
                                id: \.offset
                            ) { _, reference in
                                VStack(alignment: .leading, spacing: 2) {
                                    LabeledContent("finding.evidence.source-revision") {
                                        Text(shortID(reference.sourceRevisionID))
                                            .font(.caption2.monospaced())
                                            .textSelection(.enabled)
                                    }
                                    LabeledContent("finding.evidence.source-role") {
                                        Text(reference.roleIdentifier)
                                            .font(.caption2.monospaced())
                                    }
                                    LabeledContent("finding.evidence.source-representation") {
                                        Text(reference.representationIdentifier)
                                            .font(.caption2.monospaced())
                                    }
                                    LabeledContent("finding.evidence.source-region") {
                                        Text(reference.regionIdentifier)
                                            .font(.caption2.monospaced())
                                    }
                                    if !reference.ranges.isEmpty {
                                        LabeledContent("source.bytes") {
                                            Text(
                                                reference.ranges
                                                    .prefix(2)
                                                    .map { "\($0.start)–\($0.end)" }
                                                    .joined(separator: ", ")
                                            )
                                            .font(.caption2.monospaced())
                                        }
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                            if !evidence.sourceReferences.isEmpty {
                                Button("action.open-evidence-source") {
                                    Task { await model.openEvidenceSource(evidence) }
                                }
                                .disabled(model.isBusy)
                                .accessibilityLabel("action.open-evidence-source")
                            }
                            ForEach(
                                Array(evidence.caveats.enumerated()),
                                id: \.offset
                            ) { _, caveat in
                                caveatRow(caveat)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(
                            model.focusedEvidenceID == evidence.id
                                ? AccessibilityTraits.isSelected
                                : AccessibilityTraits()
                        )
                    }
                }
            }
            if let sourceText = model.evidenceSourceText {
                Section("finding.evidence.source") {
                    LabeledContent("finding.evidence.source-revision") {
                        Text(shortID(sourceText.sourceRevisionID))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("finding.evidence.source-bytes") {
                        Text(sourceText.byteCount, format: .number)
                            .monospacedDigit()
                    }
                    highlightedSource(sourceText.text, ranges: model.evidenceSourceRanges)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .accessibilityLabel("finding.evidence.source")
                    ForEach(
                        Array(model.evidenceSourceRanges.prefix(6).enumerated()),
                        id: \.offset
                    ) { _, range in
                        LabeledContent("source.bytes") {
                            Text("\(range.start)–\(range.end)")
                                .font(.caption2.monospaced())
                        }
                    }
                    Button("action.clear-evidence-source", role: .cancel) {
                        model.clearEvidenceSource()
                    }
                    .accessibilityLabel("action.clear-evidence-source")
                }
            }
            ForEach(model.visualizations(for: finding)) { visualization in
                Section(LocalizedStringKey(visualization.titleKey)) {
                    StudioVisualizationView(
                        visualization: visualization,
                        selectedMarkID: model.selectedVisualMarkID,
                        projectID: model.snapshot?.projectID,
                        generation: model.snapshot?.generation
                    ) { mark in
                        Task { await model.selectVisualMark(mark) }
                    }
                }
            }
            StudioDetailsSection("finding.ranking") {
                LabeledContent("finding.ranking.policy") {
                    Text(finding.rankFactors.rankingIdentifier)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
                LabeledContent("finding.ranking.intent-relevance") {
                    Text(finding.rankFactors.intentRelevance, format: .number)
                        .monospacedDigit()
                }
                LabeledContent("finding.support-class") {
                    Text(finding.rankFactors.supportClass)
                        .font(.caption.monospaced())
                }
                optionalRatioRow(
                    "finding.ranking.effect", value: finding.rankFactors.effectMagnitude)
                optionalRatioRow(
                    "finding.ranking.coverage", value: finding.rankFactors.coverage)
                optionalRatioRow(
                    "finding.ranking.stability", value: finding.rankFactors.stability)
                optionalRatioRow("finding.ranking.novelty", value: finding.rankFactors.novelty)
                LabeledContent("finding.ranking.non-redundancy") {
                    Text(
                        finding.rankFactors.nonRedundancy,
                        format: .number.precision(.fractionLength(3))
                    )
                    .monospacedDigit()
                }
                LabeledContent("finding.has-lineage") {
                    Text(finding.rankFactors.hasCompleteLineage ? "common.yes" : "common.no")
                }
            }
            Section("finding.editorial") {
                Toggle(
                    "finding.editorial.include",
                    isOn: Binding(
                        get: { model.editorialSelectedFindingIDs.contains(finding.id) },
                        set: { _ in model.toggleEditorialSelection(id: finding.id) }
                    )
                )
                .accessibilityLabel("finding.editorial.include")
                Button("action.revise-selection") {
                    Task { await model.reviseEditorialSelection() }
                }
                .disabled(model.isBusy || model.investigation == nil)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("finding.detail")
    }

    private var export: some View {
        Form {
            Section("export.description") {
                Text("export.help")
                    .foregroundStyle(.secondary)
                Text("export.formats.help")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(["json", "markdown", "csv", "pdf"], id: \.self) { format in
                    Label(format, systemImage: "doc")
                        .font(.caption.monospaced())
                        .accessibilityLabel(Text("export.format.\(format)"))
                }
                Button("action.export") {
                    isExportFolderPresented = true
                }
                .disabled(model.isBusy || model.investigation == nil)
                .accessibilityLabel("action.export")
            }
            if let receipt = model.exportReceipt {
                Section("export.receipt") {
                    LabeledContent("export.id") {
                        Text(shortID(receipt.exportID))
                            .font(.caption.monospaced())
                    }
                    LabeledContent("export.files") {
                        Text(receipt.fileCount, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("export.manifest") {
                        Text(shortID(receipt.manifestDigest))
                            .font(.caption.monospaced())
                    }
                    LabeledContent("export.report-revision") {
                        Text(shortID(receipt.reportRevisionID))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            if let request = model.lastExportRequest {
                StudioDetailsSection("export.request") {
                    LabeledContent("export.request.schema") {
                        Text(request.schemaIdentifier)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("export.request.schema-version") {
                        Text(request.schemaVersion, format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("export.request.head-event") {
                        Text(shortID(request.investigationHeadEventID))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("export.request.locale") {
                        Text(request.presentationLocaleIdentifier)
                            .font(.caption.monospaced())
                    }
                    LabeledContent("export.request.time-zone") {
                        Text(request.presentationTimeZoneIdentifier)
                            .font(.caption.monospaced())
                    }
                    ForEach(request.formats, id: \.self) { format in
                        LabeledContent("export.request.format") {
                            Text(format)
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            if let preview = model.exportPreviewMarkdown {
                Section("export.preview") {
                    Text(preview)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("export.preview")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("sidebar.export")
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case let .working(messageKey) = model.busyState {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(LocalizedStringKey(messageKey))
                    Text(LocalizedStringKey(messageKey))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if model.canCancelExecution {
                        Button("action.cancel-execution", role: .cancel) {
                            model.cancelExecution()
                        }
                    }
                }
                if model.importProgressTotal > 0 {
                    ProgressView(
                        value: Double(model.importProgressCompleted),
                        total: Double(model.importProgressTotal)
                    )
                    .accessibilityLabel("import.progress.count")
                }
            }
            if let failure = model.lastFailure {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("failure.message-key", value: failure.messageKey)
                        LabeledContent("failure.code", value: failure.code)
                        LabeledContent("failure.category", value: failure.category)
                        LabeledContent("failure.operation", value: failure.operation)
                        LabeledContent("failure.retry", value: failure.retryDisposition)
                        LabeledContent("failure.retained-state", value: failure.retainedState)
                        ForEach(failure.arguments.keys.sorted().prefix(6), id: \.self) { key in
                            Text("\(key)=\(failure.arguments[key] ?? "")")
                                .accessibilityLabel("failure.arguments")
                        }
                        engineStatus
                    }
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(.top, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("failure.detail")
                } label: {
                    Label(
                        StudioHomeModel.localizedFailureMessage(
                            messageKey: failure.messageKey, category: failure.category
                        ),
                        systemImage: "exclamationmark.triangle"
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var engineStatus: some View {
        Group {
            switch model.engineState {
            case .checking:
                Label("engine.status.checking", systemImage: "hourglass")
            case .ready:
                Label("engine.status.ready", systemImage: "checkmark.circle")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityLabel("engine.status.accessibility-label")
    }

    private func metricRow(_ title: LocalizedStringKey, value: Int) -> some View {
        LabeledContent(title) {
            Text(value, format: .number)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func mustProgressRow(
        _ title: LocalizedStringKey,
        done: Bool,
        section: StudioSection
    ) -> some View {
        Button {
            selection = section
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(Text(done ? "common.yes" : "common.no"))
        .accessibilityHint(Text("home.must-progress.hint"))
    }

    @ViewBuilder
    private func optionalRatioRow(_ title: LocalizedStringKey, value: Double?) -> some View {
        LabeledContent(title) {
            if let value {
                Text(value, format: .number.precision(.fractionLength(3)))
                    .monospacedDigit()
            } else {
                Text("common.unavailable")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func highlightedSource(_ text: String, ranges: [GlifiStudioUTF8Range]) -> some View {
        let attributed = attributedSource(text, ranges: ranges)
        Text(attributed)
    }

    private func attributedSource(_ text: String, ranges: [GlifiStudioUTF8Range])
        -> AttributedString
    {
        var attributed = AttributedString(text)
        let utf8 = text.utf8
        for range in ranges {
            guard
                let utf8Start = utf8.index(
                    utf8.startIndex,
                    offsetBy: range.start,
                    limitedBy: utf8.endIndex
                ),
                let utf8End = utf8.index(
                    utf8.startIndex,
                    offsetBy: range.end,
                    limitedBy: utf8.endIndex
                ),
                let start = String.Index(utf8Start, within: text),
                let end = String.Index(utf8End, within: text),
                let lower = AttributedString.Index(start, within: attributed),
                let upper = AttributedString.Index(end, within: attributed)
            else {
                continue
            }
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.35)
            attributed[lower..<upper].font = .body.monospaced().bold()
        }
        return attributed
    }

    private func shortID(_ value: String) -> String {
        if value.count <= 24 {
            return value
        }
        return String(value.prefix(12)) + "…" + String(value.suffix(8))
    }

    private func kwicAttributedString(
        leftContext: String,
        match: String,
        rightContext: String
    ) -> AttributedString {
        var left = AttributedString(leftContext)
        left.foregroundColor = .secondary
        var highlighted = AttributedString(match)
        highlighted.inlinePresentationIntent = .stronglyEmphasized
        var right = AttributedString(rightContext)
        right.foregroundColor = .secondary
        return left + highlighted + right
    }

    @ViewBuilder
    private func revisionIDList(titleKey: LocalizedStringKey, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            if ids.isEmpty {
                Text("common.unavailable")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(ids.prefix(8).enumerated()), id: \.offset) { _, revisionID in
                    Text(shortID(revisionID))
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
                if ids.count > 8 {
                    Text("+\(ids.count - 8)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(titleKey)
    }

    private func caveatRow(_ caveat: GlifiStudioCaveat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(caveat.identifier))
            LabeledContent("finding.caveat.severity") {
                Text(LocalizedStringKey("caveat.severity.\(caveat.severity)"))
                    .font(.caption)
            }
            LabeledContent("finding.caveat.scope") {
                Text(caveat.scope)
                    .font(.caption.monospaced())
            }
            LabeledContent("finding.caveat.cause") {
                Text(caveat.causeIdentifier)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("finding.caveat.consequence") {
                Text(caveat.consequenceIdentifier)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }
            if let action = caveat.actionIdentifier {
                LabeledContent("finding.caveat.action") {
                    Text(action)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
            }
            LabeledContent("finding.caveat.origin") {
                Text(caveat.originIdentifier)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func evidenceMeasureText(_ measure: GlifiStudioEvidenceMeasure) -> String {
        let rendered = evidenceValueText(measure.value)
        if let unit = measure.unitIdentifier, !unit.isEmpty {
            return "\(rendered) \(unit)"
        }
        return rendered
    }

    private func evidenceValueText(_ value: GlifiStudioEvidenceValue) -> String {
        switch value.type {
        case "integer":
            return value.integerValue.map(String.init) ?? "—"
        case "decimal":
            return value.decimalValue.map { String(format: "%.4g", $0) } ?? "—"
        case "boolean":
            return value.booleanValue.map { $0 ? "true" : "false" } ?? "—"
        case "text":
            return value.textValue ?? "—"
        default:
            return "—"
        }
    }
}

/// Keeps implementation details reachable in context through a native disclosure.
private struct StudioDetailsSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section {
            DisclosureGroup(title) {
                content
            }
        }
    }
}

private extension GlifiStudioFinding {
    func localizedMessage(locale: Locale) -> String {
        let template = String(localized: String.LocalizationValue(messageKey), locale: locale)
        // Resolve ranges in the original template so argument text is never substituted again.
        var rendered = template
        for range in template.ranges(of: /\{[^{}]+\}/).reversed() {
            let key = String(template[range].dropFirst().dropLast())
            if let value = messageArguments[key],
                let currentRange = Range(NSRange(range, in: template), in: rendered)
            {
                rendered.replaceSubrange(currentRange, with: value)
            }
        }
        return rendered
    }

    var supportClassLabel: String {
        assessment.supportClass
    }
}

#Preview("Italiano") {
    StudioHomeView()
        .environment(\.locale, Locale(identifier: "it"))
}

#Preview("English · Dynamic Type") {
    StudioHomeView()
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Right to left") {
    StudioHomeView()
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Document") {
    StudioHomeView(
        documentURL: URL(filePath: "/tmp/Anteprima.glifi"),
        needsPackageInitialization: true
    )
}

#Preview("Dark") {
    StudioHomeView()
        .preferredColorScheme(.dark)
}
