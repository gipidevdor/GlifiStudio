// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

struct StudioEvaluationView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var analysis: StudioEvaluationModel
    var onImportSources: (() -> Void)?
    var onOpenProject: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsResults = false
    @State private var editorPage = 0
    @State private var sourcePage = 0
    @State private var exportData: Data?
    @State private var exportFailed = false
    private let editorPageSize = 20

    init(
        model: StudioHomeModel,
        onImportSources: (() -> Void)? = nil, onOpenProject: (() -> Void)? = nil
    ) {
        self.model = model
        analysis = model.evaluation
        self.onImportSources = onImportSources
        self.onOpenProject = onOpenProject
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { geometry in
                if geometry.size.width >= 920 && !dynamicTypeSize.isAccessibilitySize {
                    HSplitView {
                        configuration.frame(minWidth: 320, idealWidth: 390, maxWidth: 480)
                        results.frame(minWidth: 380)
                    }
                } else {
                    TabView(selection: $showsResults) {
                        Tab(value: false) {
                            configuration
                        } label: {
                            Text("evaluation.settings")
                        }
                        Tab(value: true) {
                            results
                        } label: {
                            Text("evaluation.results")
                        }
                    }
                    .tabViewStyle(.grouped)
                    .padding()
                }
            }
        }
        .navigationTitle("evaluation.title")
        .onChange(of: analysis.tool) { _, _ in
            showsResults = false
            editorPage = 0
        }
        .onChange(of: analysis.output?.id) { _, id in if id != nil { showsResults = true } }
        .onChange(of: model.snapshot?.projectID) { _, _ in
            editorPage = 0
            sourcePage = 0
        }
        .fileExporter(
            isPresented: Binding(get: { exportData != nil }, set: { if !$0 { exportData = nil } }),
            document: exportData.map(StudioEvaluationJSONDocument.init), contentType: .json,
            defaultFilename: "GlifiStudio-LinguisticEvaluation"
        ) { result in
            if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
                exportFailed = true
            }
            exportData = nil
        }
        .alert("evaluation.export.failed", isPresented: $exportFailed) {
            Button("action.close", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("evaluation.tool", selection: $analysis.tool) {
                ForEach(StudioEvaluationTool.allCases) { tool in
                    Text(LocalizedStringKey(tool.titleKey)).tag(tool)
                }
            }
            .pickerStyle(.menu)
            .disabled(model.isBusy)
            StudioAnalysisRoleView(route: .evaluation(analysis.tool))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("evaluation.session-only", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var configuration: some View {
        Form {
            Section {
                Label("evaluation.candidate", systemImage: "info.circle")
                    .fixedSize(horizontal: false, vertical: true)
                if analysis.tool != .temporal {
                    Text("evaluation.no-backend")
                        .font(.callout).foregroundStyle(.secondary)
                    Picker("evaluation.zero-policy", selection: $analysis.zeroPolicy) {
                        Text("evaluation.zero.undefined").tag(
                            GlifiStudioEvaluationZeroPolicy.undefined)
                        Text("evaluation.zero.zero").tag(GlifiStudioEvaluationZeroPolicy.zero)
                    }
                    Button("evaluation.example") { analysis.loadSyntheticExample() }
                        .disabled(!analysis.observations.isEmpty || !analysis.documents.isEmpty)
                        .help("evaluation.example.help")
                }
            }
            if analysis.tool == .temporal {
                temporalConfiguration
            } else {
                linguisticConfiguration
            }
            Section {
                Button("evaluation.run", systemImage: "play.fill") { execute() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.isBusy || (analysis.tool == .temporal && selectedIDs.isEmpty))
                Text("evaluation.limits").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.isBusy)
    }

    @ViewBuilder
    private var temporalConfiguration: some View {
        if let snapshot = model.snapshot, !snapshot.sources.isEmpty {
            Section("summary.scope.title") {
                Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                    Text("summary.scope.all").tag(StudioTextAnalysisScope.allSources)
                    Text("summary.scope.selected").tag(StudioTextAnalysisScope.selectedSources)
                }
                LabeledContent("summary.scope.source-count") {
                    Text(selectedIDs.count, format: .number)
                }
                if model.textAnalysisScope == .selectedSources {
                    DisclosureGroup("evaluation.select-sources") {
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
                            ) {
                                Text("workspace.source.ordinal \(index + 1)")
                            }
                        }
                    }
                }
                Text("evaluation.metadata.help").foregroundStyle(.secondary)
            }
            Section("evaluation.partition") {
                Toggle("evaluation.instant-basis", isOn: $analysis.instantBasis)
                if analysis.instantBasis {
                    TextField("evaluation.time-zone", text: $analysis.timeZoneIdentifier)
                }
                Picker("evaluation.granularity", selection: $analysis.granularity) {
                    Text("evaluation.granularity.day").tag(GlifiStudioTemporalGranularity.day)
                    Text("evaluation.granularity.month").tag(GlifiStudioTemporalGranularity.month)
                    Text("evaluation.granularity.year").tag(GlifiStudioTemporalGranularity.year)
                }
                integerField("evaluation.origin.year", value: $analysis.originYear)
                integerField("evaluation.origin.month", value: $analysis.originMonth)
                integerField("evaluation.origin.day", value: $analysis.originDay)
                integerField("evaluation.bucket-width", value: $analysis.bucketWidth)
                integerField("evaluation.bucket-count", value: $analysis.bucketCount)
                Picker("evaluation.missing-policy", selection: $analysis.missingPolicy) {
                    Text("evaluation.policy.exclude").tag(GlifiStudioTemporalMissingPolicy.exclude)
                    Text("evaluation.policy.separate").tag(
                        GlifiStudioTemporalMissingPolicy.separate)
                    Text("evaluation.policy.reject").tag(GlifiStudioTemporalMissingPolicy.reject)
                }
                Picker("evaluation.outside-policy", selection: $analysis.outsidePolicy) {
                    Text("evaluation.policy.exclude").tag(GlifiStudioTemporalOutsidePolicy.exclude)
                    Text("evaluation.policy.reject").tag(GlifiStudioTemporalOutsidePolicy.reject)
                }
                Text("evaluation.partition.help").font(.caption).foregroundStyle(.secondary)
            }
            Section("evaluation.terms") {
                TextEditor(text: $analysis.selectedTerms)
                    .frame(minHeight: 80)
                    .accessibilityLabel("evaluation.terms")
                Text("evaluation.terms.help").font(.caption).foregroundStyle(.secondary)
            }
            Section("evaluation.annotations") {
                let selected = Set(selectedIDs)
                let sources = Array(snapshot.sources.enumerated()).filter {
                    selected.contains($0.element.sourceRevisionID)
                }
                pager(
                    page: sourcePage,
                    count: max(1, (sources.count + editorPageSize - 1) / editorPageSize),
                    previous: { sourcePage = max(0, sourcePage - 1) },
                    next: { sourcePage += 1 })
                ForEach(
                    Array(sources.dropFirst(sourcePage * editorPageSize).prefix(editorPageSize)),
                    id: \.element.sourceRevisionID
                ) { index, source in
                    temporalEditor(sourceID: source.sourceRevisionID, number: index + 1)
                }
            }
        } else {
            Section {
                ContentUnavailableView {
                    Label("advanced.empty.title", systemImage: "calendar")
                } description: {
                    Text("evaluation.temporal.needs-sources")
                } actions: {
                    if model.snapshot != nil, let onImportSources {
                        Button("action.import", action: onImportSources)
                    } else if let onOpenProject {
                        Button("action.open-project", action: onOpenProject)
                    }
                }
            }
        }
    }

    private func temporalEditor(sourceID: String, number: Int) -> some View {
        let draft = Binding<StudioTemporalAnnotationDraft>(
            get: { analysis.temporalAnnotations[sourceID] ?? .init() },
            set: { analysis.temporalAnnotations[sourceID] = $0 })
        return DisclosureGroup {
            Text(sourceID).font(.caption.monospaced()).textSelection(.enabled)
            Picker("evaluation.precision", selection: draft.precision) {
                ForEach(StudioTemporalPrecision.allCases) { precision in
                    Text(LocalizedStringKey(precision.titleKey)).tag(precision)
                }
            }
            switch draft.wrappedValue.precision {
            case .missing: Text("evaluation.missing-date.help").foregroundStyle(.secondary)
            case .civilYear:
                integerField("evaluation.date.year", value: draft.year)
            case .civilMonth:
                integerField("evaluation.date.year", value: draft.year)
                integerField("evaluation.date.month", value: draft.month)
            case .civilDate:
                integerField("evaluation.date.year", value: draft.year)
                integerField("evaluation.date.month", value: draft.month)
                integerField("evaluation.date.day", value: draft.day)
            case .instant:
                TextField("evaluation.date.instant", text: draft.instant)
                Text("evaluation.date.instant.help").font(.caption).foregroundStyle(.secondary)
            }
            TextField("evaluation.metadata.provenance", text: draft.provenance)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("workspace.source.ordinal \(number)").font(.headline)
                Text(LocalizedStringKey(draft.wrappedValue.precision.titleKey))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var linguisticConfiguration: some View {
        if analysis.tool == .boundaries || analysis.tool == .namedEntities {
            Section("evaluation.annotated-documents") {
                Button("evaluation.add-document", systemImage: "plus") {
                    analysis.documents.append(.init())
                    editorPage = (analysis.documents.count - 1) / editorPageSize
                }
                .disabled(analysis.documents.count >= StudioEvaluationModel.maximumDocuments)
                Text("evaluation.offsets.help").font(.caption).foregroundStyle(.secondary)
                pager(
                    page: editorPage,
                    count: max(1, (analysis.documents.count + editorPageSize - 1) / editorPageSize),
                    previous: { editorPage = max(0, editorPage - 1) }, next: { editorPage += 1 })
                ForEach(
                    Array(analysis.documents.enumerated()).dropFirst(editorPage * editorPageSize)
                        .prefix(editorPageSize), id: \.element.id
                ) { index, document in
                    documentEditor(documentBinding(document.id), number: index + 1)
                }
            }
        } else {
            if analysis.tool == .lemmas {
                Section {
                    Toggle("evaluation.include-forms", isOn: $analysis.includesForms)
                    Toggle("evaluation.include-pos", isOn: $analysis.includesPartsOfSpeech)
                }
            }
            Section("evaluation.observations") {
                Button("evaluation.add-observation", systemImage: "plus") {
                    analysis.observations.append(.init())
                    editorPage = (analysis.observations.count - 1) / editorPageSize
                }
                .disabled(analysis.observations.count >= StudioEvaluationModel.maximumObservations)
                pager(
                    page: editorPage,
                    count: max(
                        1, (analysis.observations.count + editorPageSize - 1) / editorPageSize),
                    previous: { editorPage = max(0, editorPage - 1) }, next: { editorPage += 1 })
                ForEach(
                    Array(analysis.observations.enumerated()).dropFirst(editorPage * editorPageSize)
                        .prefix(editorPageSize), id: \.element.id
                ) { index, observation in
                    observationEditor(observationBinding(observation.id), number: index + 1)
                }
            }
        }
    }

    private func observationEditor(_ observation: Binding<StudioEvaluationObservation>, number: Int)
        -> some View
    {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if analysis.tool == .morphology {
                    featureEditor(
                        observation.goldFeatures, titleKey: "evaluation.gold",
                        observationNumber: number)
                    featureEditor(
                        observation.predictedFeatures, titleKey: "evaluation.predicted",
                        observationNumber: number)
                } else {
                    editorTextField(
                        "evaluation.gold",
                        context: observationFieldLabel("evaluation.gold", number: number),
                        text: observation.gold)
                    editorTextField(
                        "evaluation.predicted",
                        context: observationFieldLabel("evaluation.predicted", number: number),
                        text: observation.predicted)
                    if analysis.tool == .lemmas && analysis.includesForms {
                        editorTextField(
                            "evaluation.form",
                            context: observationFieldLabel("evaluation.form", number: number),
                            text: observation.form)
                    }
                    if analysis.tool == .lemmas && analysis.includesPartsOfSpeech {
                        editorTextField(
                            "evaluation.pos",
                            context: observationFieldLabel("evaluation.pos", number: number),
                            text: observation.partOfSpeech)
                    }
                }
                let removeLabel = Text("evaluation.observation.remove \(number)")
                Button("evaluation.remove", systemImage: "minus.circle", role: .destructive) {
                    let identity = observation.wrappedValue.id
                    analysis.observations.removeAll { $0.id == identity }
                    editorPage = min(
                        editorPage, max(0, (analysis.observations.count - 1) / editorPageSize))
                }
                .accessibilityLabel(removeLabel)
                .accessibilityInputLabels([removeLabel, Text("evaluation.remove")])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("evaluation.observation.number \(number)")
                .accessibilityAddTraits(.isHeader)
        }
        .accessibilityElement(children: .contain)
    }

    private func featureEditor(
        _ features: Binding<[StudioEvaluationFeature]>, titleKey: String,
        observationNumber: Int
    ) -> some View {
        let side = localized(titleKey)
        let ordinals = Dictionary(
            features.wrappedValue.enumerated().map { ($0.element.id, $0.offset + 1) },
            uniquingKeysWith: { first, _ in first })
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features) { feature in
                    let identity = feature.wrappedValue.id
                    let number = ordinals[identity] ?? 1
                    VStack(alignment: .leading, spacing: 6) {
                        Text("evaluation.feature.number \(number)").font(.subheadline.bold())
                            .accessibilityAddTraits(.isHeader)
                        editorTextField(
                            "evaluation.attribute",
                            context: nestedFieldLabel(
                                "evaluation.attribute", parent: observationNumber, side: side,
                                number: number, isEntity: false),
                            text: feature.attribute)
                        editorTextField(
                            "evaluation.attribute-value",
                            context: nestedFieldLabel(
                                "evaluation.attribute-value", parent: observationNumber,
                                side: side, number: number, isEntity: false),
                            text: feature.value)
                        let removeLabel = Text(
                            "evaluation.feature.remove \(observationNumber) \(side) \(number)")
                        Button("evaluation.remove", systemImage: "minus.circle", role: .destructive)
                        {
                            features.wrappedValue.removeAll { $0.id == identity }
                        }
                        .accessibilityLabel(removeLabel)
                        .accessibilityInputLabels([removeLabel, Text("evaluation.remove")])
                    }
                    .accessibilityElement(children: .contain)
                }
                let addLabel = Text("evaluation.feature.add \(observationNumber) \(side)")
                Button("evaluation.add-feature", systemImage: "plus") {
                    features.wrappedValue.append(.init())
                }
                .accessibilityLabel(addLabel)
                .accessibilityInputLabels([addLabel, Text("evaluation.add-feature")])
                .disabled(features.wrappedValue.count >= 256)
            }
        } label: {
            Text(LocalizedStringKey(titleKey)).accessibilityAddTraits(.isHeader)
        }
        .accessibilityElement(children: .contain)
    }

    private func documentEditor(_ document: Binding<StudioEvaluationDocument>, number: Int)
        -> some View
    {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                editorTextField(
                    "evaluation.document-name",
                    context: documentFieldLabel("evaluation.document-name", number: number),
                    text: document.name)
                VStack(alignment: .leading, spacing: 6) {
                    Text("evaluation.source-text").font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    let label = documentFieldLabel("evaluation.source-text", number: number)
                    TextEditor(text: document.text)
                        .frame(minHeight: 90)
                        .accessibilityLabel(label)
                        .accessibilityInputLabels([label, Text("evaluation.source-text")])
                }
                if analysis.tool == .boundaries {
                    editorTextField(
                        "evaluation.gold-boundaries",
                        context: documentFieldLabel("evaluation.gold-boundaries", number: number),
                        text: document.goldBoundaries)
                    editorTextField(
                        "evaluation.predicted-boundaries",
                        context: documentFieldLabel(
                            "evaluation.predicted-boundaries", number: number),
                        text: document.predictedBoundaries)
                    Text("evaluation.boundaries.help").font(.caption).foregroundStyle(.secondary)
                } else {
                    entityEditor(
                        document.goldEntities, titleKey: "evaluation.gold", documentNumber: number)
                    entityEditor(
                        document.predictedEntities, titleKey: "evaluation.predicted",
                        documentNumber: number)
                }
                let removeLabel = Text("evaluation.document.remove \(number)")
                Button("evaluation.remove", systemImage: "minus.circle", role: .destructive) {
                    let identity = document.wrappedValue.id
                    analysis.documents.removeAll { $0.id == identity }
                    editorPage = min(
                        editorPage, max(0, (analysis.documents.count - 1) / editorPageSize))
                }
                .accessibilityLabel(removeLabel)
                .accessibilityInputLabels([removeLabel, Text("evaluation.remove")])
            }
        } label: {
            Text("evaluation.document.number \(number)").accessibilityAddTraits(.isHeader)
        }
        .accessibilityElement(children: .contain)
    }

    private func entityEditor(
        _ entities: Binding<[StudioEvaluationEntityDraft]>, titleKey: String,
        documentNumber: Int
    ) -> some View {
        let side = localized(titleKey)
        let ordinals = Dictionary(
            entities.wrappedValue.enumerated().map { ($0.element.id, $0.offset + 1) },
            uniquingKeysWith: { first, _ in first })
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entities) { entity in
                    let identity = entity.wrappedValue.id
                    let number = ordinals[identity] ?? 1
                    VStack(alignment: .leading, spacing: 6) {
                        Text("evaluation.entity.number \(number)").font(.subheadline.bold())
                            .accessibilityAddTraits(.isHeader)
                        editorIntegerField(
                            "evaluation.span.start",
                            context: nestedFieldLabel(
                                "evaluation.span.start", parent: documentNumber, side: side,
                                number: number, isEntity: true),
                            value: entity.start)
                        editorIntegerField(
                            "evaluation.span.end",
                            context: nestedFieldLabel(
                                "evaluation.span.end", parent: documentNumber, side: side,
                                number: number, isEntity: true),
                            value: entity.end)
                        editorTextField(
                            "evaluation.entity-type",
                            context: nestedFieldLabel(
                                "evaluation.entity-type", parent: documentNumber, side: side,
                                number: number, isEntity: true),
                            text: entity.type)
                        let removeLabel = Text(
                            "evaluation.entity.remove \(documentNumber) \(side) \(number)")
                        Button("evaluation.remove", systemImage: "minus.circle", role: .destructive)
                        {
                            entities.wrappedValue.removeAll { $0.id == identity }
                        }
                        .accessibilityLabel(removeLabel)
                        .accessibilityInputLabels([removeLabel, Text("evaluation.remove")])
                    }
                    .accessibilityElement(children: .contain)
                }
                let addLabel = Text("evaluation.entity.add \(documentNumber) \(side)")
                Button("evaluation.add-entity", systemImage: "plus") {
                    entities.wrappedValue.append(.init())
                }
                .accessibilityLabel(addLabel)
                .accessibilityInputLabels([addLabel, Text("evaluation.add-entity")])
                .disabled(entities.wrappedValue.count >= StudioEvaluationModel.maximumObservations)
            }
        } label: {
            Text(LocalizedStringKey(titleKey)).accessibilityAddTraits(.isHeader)
        }
        .accessibilityElement(children: .contain)
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    private func observationFieldLabel(_ key: String, number: Int) -> Text {
        let field = localized(key)
        return Text("evaluation.observation.field \(field) \(number)")
    }

    private func documentFieldLabel(_ key: String, number: Int) -> Text {
        let field = localized(key)
        return Text("evaluation.document.field \(field) \(number)")
    }

    private func nestedFieldLabel(
        _ key: String, parent: Int, side: String, number: Int, isEntity: Bool
    ) -> Text {
        let field = localized(key)
        if isEntity {
            return Text("evaluation.entity.field \(field) \(parent) \(side) \(number)")
        }
        return Text("evaluation.feature.field \(field) \(parent) \(side) \(number)")
    }

    private func editorTextField(_ key: String, context: Text, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(key)).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(context)
                .accessibilityInputLabels([context, Text(LocalizedStringKey(key))])
        }
    }

    private func editorIntegerField(_ key: String, context: Text, value: Binding<Int>) -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(key)).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(context)
                .accessibilityInputLabels([context, Text(LocalizedStringKey(key))])
        }
    }

    @ViewBuilder
    private var results: some View {
        if let output = analysis.output {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStringKey(output.input.tool.titleKey)).font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Label("evaluation.candidate", systemImage: "info.circle")
                    .fixedSize(horizontal: false, vertical: true)
                if output.temporal != nil {
                    Text("evaluation.temporal.caveat").foregroundStyle(.secondary)
                }
                if let temporal = output.temporal, !temporal.result.excluded.isEmpty {
                    DisclosureGroup {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(temporal.result.excluded.enumerated()), id: \.offset)
                                { _, exclusion in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exclusion.lineage.sourceRevisionID).font(
                                            .caption.monospaced()
                                        ).textSelection(.enabled)
                                        Text(exclusionReason(exclusion.reasonIdentifier))
                                        Text(exclusion.lineage.metadataProvenance).font(.caption)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    } label: {
                        Label {
                            Text("evaluation.excluded.count \(temporal.result.excluded.count)")
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                        }
                    }
                }
                Text("evaluation.effective-result").font(.caption).foregroundStyle(.secondary)
                if output.input.tool == .classification {
                    Text("evaluation.confusion.help").font(.caption).foregroundStyle(.secondary)
                }
                if analysis.isDraftChanged {
                    Label("operators.draft-changed", systemImage: "exclamationmark.circle")
                }
                resultTable(output)
                pager(
                    page: analysis.page, count: analysis.pageCount,
                    previous: {
                        Task { await analysis.showPage(analysis.page - 1, locale: locale) }
                    },
                    next: { Task { await analysis.showPage(analysis.page + 1, locale: locale) } })
                methodDetails(output)
            }
            .padding()
        } else {
            ContentUnavailableView(
                "evaluation.result.empty", systemImage: "checkmark.seal",
                description: Text("evaluation.result.empty.description"))
        }
    }

    @ViewBuilder
    private func resultTable(_ output: StudioEvaluationOutput) -> some View {
        if output.temporal != nil {
            Table(analysis.rows) {
                TableColumn("evaluation.column.kind") { cell($0, 0) }
                TableColumn("evaluation.column.start") { cell($0, 1) }
                TableColumn("evaluation.column.end") { cell($0, 2) }
                TableColumn("evaluation.column.term") { cell($0, 3) }
                TableColumn("evaluation.column.documents") { cell($0, 4) }
                TableColumn("evaluation.column.tokens") { cell($0, 5) }
                TableColumn("evaluation.column.frequency") { cell($0, 6) }
                TableColumn("evaluation.column.df") { cell($0, 7) }
                TableColumn("evaluation.column.rate") { cell($0, 8) }
            }
            .frame(minHeight: 260)
        } else {
            Table(analysis.rows) {
                TableColumn("evaluation.column.group") { cell($0, 0) }
                TableColumn("evaluation.column.metric") { cell($0, 1) }
                TableColumn("evaluation.column.value") { cell($0, 2) }
            }
            .frame(minHeight: 260)
        }
        Text("evaluation.result.rows \(output.rowCount)")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func cell(_ row: StudioEvaluationRow, _ index: Int) -> some View {
        Text(row.values.indices.contains(index) ? row.values[index] : "")
            .monospacedDigit().textSelection(.enabled)
    }

    private func methodDetails(_ output: StudioEvaluationOutput) -> some View {
        DisclosureGroup("common.method") {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(output.methodIdentifier).font(.caption.monospaced()).textSelection(
                        .enabled)
                    if let temporal = output.temporal {
                        LabeledContent("project.id", value: temporal.projectID)
                        LabeledContent("project.generation") {
                            Text(temporal.generation, format: .number)
                        }
                        LabeledContent("evaluation.granularity") {
                            Text(LocalizedStringKey(granularityTitleKey(output.input.granularity)))
                        }
                        Text(
                            "evaluation.partition.effective \(output.input.originYear) \(output.input.originMonth) \(output.input.originDay) \(output.input.bucketWidth) \(output.input.bucketCount)"
                        )
                        LabeledContent("evaluation.missing-policy") {
                            Text(
                                LocalizedStringKey(
                                    missingPolicyTitleKey(output.input.missingPolicy)))
                        }
                        LabeledContent("evaluation.outside-policy") {
                            Text(
                                LocalizedStringKey(
                                    outsidePolicyTitleKey(output.input.outsidePolicy)))
                        }
                        if output.input.instantBasis {
                            LabeledContent(
                                "evaluation.time-zone", value: output.input.timeZoneIdentifier)
                        }
                        ForEach(
                            Array(temporal.documents.enumerated()), id: \.element.sourceRevisionID
                        ) { index, document in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.sourceRevisionID).textSelection(.enabled)
                                Text(document.metadataProvenance).textSelection(.enabled)
                                Text(temporal.contentDigests[index]).font(.caption.monospaced())
                                    .textSelection(.enabled)
                                LabeledContent("evaluation.column.tokens") {
                                    Text(document.tokenCount, format: .number)
                                }
                                Text(temporalValueText(document.value)).textSelection(.enabled)
                            }
                        }
                    } else {
                        LabeledContent("evaluation.zero-policy") {
                            Text(LocalizedStringKey(zeroPolicyTitleKey(output.input.zeroPolicy)))
                        }
                        Text("evaluation.no-backend").foregroundStyle(.secondary)
                        ForEach(Array(output.input.observations.enumerated()), id: \.element.id) {
                            index, observation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("evaluation.observation.number \(index + 1)").font(.headline)
                                if output.input.tool == .morphology {
                                    Text("evaluation.gold").font(.caption)
                                    ForEach(observation.goldFeatures) { feature in
                                        Text("\(feature.attribute) = \(feature.value)")
                                    }
                                    Text("evaluation.predicted").font(.caption)
                                    ForEach(observation.predictedFeatures) { feature in
                                        Text("\(feature.attribute) = \(feature.value)")
                                    }
                                } else {
                                    LabeledContent("evaluation.gold", value: observation.gold)
                                    LabeledContent(
                                        "evaluation.predicted", value: observation.predicted)
                                    if output.input.includesForms {
                                        LabeledContent("evaluation.form", value: observation.form)
                                    }
                                    if output.input.includesPartsOfSpeech {
                                        LabeledContent(
                                            "evaluation.pos", value: observation.partOfSpeech)
                                    }
                                }
                            }
                        }
                        ForEach(Array(output.input.documents.enumerated()), id: \.element.id) {
                            index, document in
                            DisclosureGroup {
                                Text(document.text).textSelection(.enabled)
                                if output.input.tool == .boundaries {
                                    LabeledContent(
                                        "evaluation.gold-boundaries", value: document.goldBoundaries
                                    )
                                    LabeledContent(
                                        "evaluation.predicted-boundaries",
                                        value: document.predictedBoundaries)
                                } else {
                                    Text("evaluation.gold").font(.caption)
                                    ForEach(document.goldEntities) { entity in
                                        Text("\(entity.start)–\(entity.end): \(entity.type)")
                                    }
                                    Text("evaluation.predicted").font(.caption)
                                    ForEach(document.predictedEntities) { entity in
                                        Text("\(entity.start)–\(entity.end): \(entity.type)")
                                    }
                                }
                            } label: {
                                Text("evaluation.document.number \(index + 1)")
                            }
                        }
                        if let data = output.encodedLinguisticResult {
                            Button("evaluation.export", systemImage: "square.and.arrow.up") {
                                exportData = data
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 280)
        }
    }

    private var selectedIDs: [String] {
        switch model.textAnalysisScope {
        case .allSources: (model.snapshot?.sources.map(\.sourceRevisionID) ?? []).sorted()
        case .selectedSources: model.selectedTextAnalysisSourceRevisionIDs.sorted()
        }
    }

    private func granularityTitleKey(_ value: GlifiStudioTemporalGranularity) -> String {
        switch value {
        case .day: "evaluation.granularity.day"
        case .month: "evaluation.granularity.month"
        case .year: "evaluation.granularity.year"
        }
    }

    private func missingPolicyTitleKey(_ value: GlifiStudioTemporalMissingPolicy) -> String {
        switch value {
        case .exclude: "evaluation.policy.exclude"
        case .separate: "evaluation.policy.separate"
        case .reject: "evaluation.policy.reject"
        }
    }

    private func outsidePolicyTitleKey(_ value: GlifiStudioTemporalOutsidePolicy) -> String {
        switch value {
        case .exclude: "evaluation.policy.exclude"
        case .reject: "evaluation.policy.reject"
        }
    }

    private func zeroPolicyTitleKey(_ value: GlifiStudioEvaluationZeroPolicy) -> String {
        switch value {
        case .undefined: "evaluation.zero.undefined"
        case .zero: "evaluation.zero.zero"
        }
    }

    private func temporalValueText(_ value: GlifiStudioTemporalValue) -> String {
        switch value {
        case .missing:
            String(localized: "evaluation.precision.missing", locale: locale)
        case .civilDate(let date):
            String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
        case .civilMonth(let year, let month):
            String(format: "%04d-%02d", year, month)
        case .civilYear(let year):
            String(format: "%04d", year)
        case .instant(let instant):
            instant.ISO8601Format()
        case .interval, .uncertainPeriod:
            String(localized: "evaluation.unsupported-period", locale: locale)
        }
    }

    private func exclusionReason(_ value: String) -> LocalizedStringKey {
        switch value {
        case "temporal.missing-date": "evaluation.exclusion.missing"
        case "temporal.before-domain": "evaluation.exclusion.before"
        case "temporal.after-domain": "evaluation.exclusion.after"
        default: "evaluation.exclusion.other"
        }
    }

    private func execute() {
        if analysis.tool == .temporal {
            let ids = selectedIDs
            let numbers = Dictionary(
                uniqueKeysWithValues: (model.snapshot?.sources ?? []).enumerated().map {
                    ($0.element.sourceRevisionID, $0.offset + 1)
                })
            Task {
                await model.runAdvancedAnalysis { session in
                    try await analysis.executeTemporal(
                        session: session, sourceRevisionIDs: ids, sourceNumbers: numbers,
                        locale: locale)
                }
            }
        } else {
            Task {
                await model.runCoreAnalysis { try await analysis.executeLinguistic(locale: locale) }
            }
        }
    }

    private func observationBinding(_ id: UUID) -> Binding<StudioEvaluationObservation> {
        Binding(
            get: { analysis.observations.first { $0.id == id } ?? .init(id: id) },
            set: { updated in
                if let index = analysis.observations.firstIndex(where: { $0.id == id }) {
                    analysis.observations[index] = updated
                }
            })
    }

    private func documentBinding(_ id: UUID) -> Binding<StudioEvaluationDocument> {
        Binding(
            get: { analysis.documents.first { $0.id == id } ?? .init(id: id) },
            set: { updated in
                if let index = analysis.documents.firstIndex(where: { $0.id == id }) {
                    analysis.documents[index] = updated
                }
            })
    }

    private func integerField(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
                .accessibilityLabel(key)
        }
    }

    private func pager(
        page: Int, count: Int, previous: @escaping () -> Void, next: @escaping () -> Void
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { pageControls(page: page, count: count, previous: previous, next: next) }
            VStack(alignment: .leading) {
                pageControls(page: page, count: count, previous: previous, next: next)
            }
        }
    }

    @ViewBuilder
    private func pageControls(
        page: Int, count: Int, previous: @escaping () -> Void, next: @escaping () -> Void
    ) -> some View {
        Button("advanced.previous-page", systemImage: "chevron.backward", action: previous)
            .disabled(page <= 0)
        Text("evaluation.page \(page + 1) \(count)").monospacedDigit()
        Button("advanced.next-page", systemImage: "chevron.forward", action: next).disabled(
            page + 1 >= count)
    }
}

private struct StudioEvaluationJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data
    init(_ data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
private func evaluationPreviewModel() -> StudioHomeModel {
    let model = StudioHomeModel()
    model.evaluation.tool = .classification
    model.evaluation.loadSyntheticExample()
    return model
}

#Preview("Valutazione · italiano") {
    StudioEvaluationView(model: evaluationPreviewModel())
        .environment(\.locale, Locale(identifier: "it"))
        .frame(width: 1_100, height: 780)
}

#Preview("Valutazione · testo grande e scuro") {
    StudioEvaluationView(model: evaluationPreviewModel())
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .frame(width: 430, height: 780)
}

#Preview("Valutazione · destra-sinistra") {
    StudioEvaluationView(model: evaluationPreviewModel())
        .environment(\.layoutDirection, .rightToLeft)
        .frame(width: 430, height: 780)
}
