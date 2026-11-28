// SPDX-License-Identifier: BSD-3-Clause

import Charts
import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Native, document-driven access to the bounded exploratory operators.
struct StudioAdvancedAnalysisView: View {
    @Bindable var model: StudioHomeModel
    @Bindable private var analysis: StudioAdvancedAnalysisModel
    var initialTool: StudioAdvancedTool?
    var onImportSources: (() -> Void)?
    var onOpenProject: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var source: GlifiStudioSourceText?
    @State private var showsSource = false
    @State private var showsExporter = false
    @State private var exportData = Data()
    @State private var exportFilename = "GlifiStudio-analysis"
    @State private var exportFailed = false
    @State private var compactResults = false

    init(
        model: StudioHomeModel, initialTool: StudioAdvancedTool? = nil,
        onImportSources: (() -> Void)? = nil, onOpenProject: (() -> Void)? = nil
    ) {
        self.model = model
        analysis = model.advancedAnalysis
        self.initialTool = initialTool
        self.onImportSources = onImportSources
        self.onOpenProject = onOpenProject
    }

    var body: some View {
        Group {
            if let snapshot = model.snapshot, !snapshot.sources.isEmpty {
                GeometryReader { geometry in
                    if geometry.size.width >= 920 && !dynamicTypeSize.isAccessibilitySize {
                        HSplitView {
                            ScrollView { configuration(snapshot).padding() }
                                .frame(minWidth: 290, idealWidth: 340, maxWidth: 440)
                            ScrollView { results.padding() }
                                .frame(minWidth: 400)
                        }
                    } else {
                        TabView(selection: $compactResults) {
                            Tab(value: false) {
                                ScrollView { configuration(snapshot).padding() }
                            } label: {
                                Text("advanced.settings-pane")
                            }
                            Tab(value: true) {
                                ScrollView { results.padding() }
                            } label: {
                                Text("advanced.results-pane")
                            }
                        }
                        .tabViewStyle(.grouped)
                        .padding()
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("advanced.empty.title", systemImage: "chart.xyaxis.line")
                } description: {
                    Text("advanced.empty.description")
                } actions: {
                    if model.snapshot != nil, let onImportSources {
                        Button("action.import", action: onImportSources).disabled(model.isBusy)
                    } else if let onOpenProject {
                        Button("action.open-project", action: onOpenProject).disabled(model.isBusy)
                    }
                }
            }
        }
        .navigationTitle("advanced.title")
        .onAppear {
            if let initialTool { analysis.tool = initialTool }
        }
        .onChange(of: initialTool) { _, tool in
            if let tool { analysis.tool = tool }
        }
        .onChange(of: analysis.tool) { _, _ in compactResults = false }
        .onChange(of: analysis.mdsMethod) { _, _ in compactResults = false }
        .onChange(of: analysis.mdsSearchMethod) { _, _ in compactResults = false }
        .onChange(of: analysis.somTopology) { _, _ in compactResults = false }
        .onChange(of: analysis.topicCriterion) { _, _ in compactResults = false }
        .onChange(of: analysis.output?.completedAt) { _, completion in
            if completion != nil { compactResults = true }
        }
        .onChange(of: model.snapshot?.projectID) { _, _ in
            source = nil
            showsSource = false
            compactResults = false
        }
        .sheet(isPresented: $showsSource) {
            if let source {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("advanced.original-source", systemImage: "doc.text")
                            .font(.headline)
                        Spacer()
                        Button("action.close") { showsSource = false }
                            .keyboardShortcut(.cancelAction)
                    }
                    Text("advanced.original-source.description").foregroundStyle(.secondary)
                    ScrollView {
                        Text(source.text).textSelection(.enabled).frame(
                            maxWidth: .infinity, alignment: .leading)
                    }
                    Text(source.sourceRevisionID).font(.caption.monospaced()).textSelection(
                        .enabled)
                }
                .padding(24)
                .frame(minWidth: 480, idealWidth: 720, minHeight: 400, idealHeight: 600)
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: StudioAdvancedResultDocument(data: exportData),
            contentType: .json, defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result,
                (error as? CocoaError)?.code != .userCancelled
            {
                exportFailed = true
            }
        }
        .alert("advanced.export-failed", isPresented: $exportFailed) {
            Button("action.close", role: .cancel) {}
        } message: {
            Text("advanced.export-failed.description")
        }
    }

    private func configuration(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                StudioAnalysisRoleView(route: .advanced(analysis.tool))
                Label("advanced.title", systemImage: "chart.xyaxis.line").font(.title2.bold())
                Text("advanced.introduction").foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("advanced.choose-tool", selection: $analysis.tool) {
                        ForEach(StudioAdvancedTool.allCases) { tool in
                            Text(LocalizedStringKey(tool.titleKey)).tag(tool)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(LocalizedStringKey(analysis.tool.descriptionKey))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            scope(snapshot)
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    parameters
                    DisclosureGroup("advanced.reproducibility") {
                        VStack(alignment: .leading, spacing: 12) {
                            if analysis.tool.usesDenseMatrix {
                                integerField(
                                    "advanced.maximum-terms", value: $analysis.maximumTerms)
                                Text("advanced.matrix-policy").font(.caption).foregroundStyle(
                                    .secondary)
                            } else {
                                Text("advanced.full-token-policy").font(.caption).foregroundStyle(
                                    .secondary)
                            }
                            if analysis.tool != .somPCAInitialization && analysis.tool != .somKH {
                                TextField("advanced.seed", value: $analysis.seed, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Text("advanced.limits").font(.caption).foregroundStyle(.secondary)
                            Text("advanced.completion-limits").font(.caption).foregroundStyle(
                                .secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            } label: {
                Label("advanced.parameters", systemImage: "slider.horizontal.3")
            }
            if analysis.tool.needsLabels { labels(snapshot) }
            if analysis.tool.needsRules { rules }
            Label(LocalizedStringKey(analysis.tool.caveatKey), systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let reason = blockedReason(snapshot) {
                Label(LocalizedStringKey(reason), systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                let ids = selectedIDs(snapshot)
                let numbers = Dictionary(
                    uniqueKeysWithValues: snapshot.sources.enumerated().map {
                        ($1.sourceRevisionID, $0 + 1)
                    })
                Task {
                    await model.runAdvancedAnalysis { session in
                        try await analysis.execute(
                            session: session, sourceRevisionIDs: ids, sourceNumbers: numbers,
                            locale: locale)
                    }
                }
            } label: {
                Label("advanced.run", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(blockedReason(snapshot) != nil)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .disabled(model.isBusy)
    }

    private func scope(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("summary.scope.choice", selection: $model.textAnalysisScope) {
                    ForEach(StudioTextAnalysisScope.allCases) { scope in
                        Text(LocalizedStringKey(scope.titleKey)).tag(scope)
                    }
                }
                if model.textAnalysisScope == .selectedSources {
                    DisclosureGroup("advanced.select-sources") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("advanced.select-all") {
                                    model.selectedTextAnalysisSourceRevisionIDs = Set(
                                        snapshot.sources.map(\.sourceRevisionID))
                                }
                                Button("advanced.clear-selection") {
                                    model.selectedTextAnalysisSourceRevisionIDs = []
                                }
                            }
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
                                            if selected
                                                != model.selectedTextAnalysisSourceRevisionIDs
                                                .contains(source.sourceRevisionID)
                                            {
                                                model.toggleTextAnalysisSource(
                                                    source.sourceRevisionID)
                                            }
                                        }
                                    )
                                ) { sourceLabel(index: index, source: source) }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                LabeledContent("advanced.scope-source-count") {
                    Text(selectedIDs(snapshot).count, format: .number)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("summary.scope.title", systemImage: "doc.on.doc")
        }
    }

    @ViewBuilder private var parameters: some View {
        switch analysis.tool {
        case .mds:
            mdsParameters(search: false)
        case .mdsSearch:
            mdsParameters(search: true)
        case .mdsOrdinal, .mdsOrdinalSearch:
            distancePicker
            Stepper("advanced.dimensions", value: $analysis.dimensions, in: 1...2)
            Text(analysis.dimensions, format: .number).foregroundStyle(.secondary)
            Picker("advanced.ordinal-ties", selection: $analysis.ordinalTies) {
                ForEach([GlifiStudioMDSOrdinalTies.primary, .secondary], id: \.self) { ties in
                    Text(LocalizedStringKey("advanced.ordinal-ties.\(ties.rawValue)")).tag(ties)
                }
            }
            integerField("advanced.iterations", value: $analysis.maximumIterations)
            decimalField("advanced.tolerance", value: $analysis.mdsTolerance)
            if analysis.tool == .mdsOrdinalSearch {
                integerField("advanced.starts", value: $analysis.mdsStarts)
            }
        case .somPCAInitialization:
            integerField("advanced.width", value: $analysis.gridWidth)
            integerField("advanced.height", value: $analysis.gridHeight)
        case .somKH:
            integerField("advanced.width", value: $analysis.gridWidth)
            integerField("advanced.height", value: $analysis.gridHeight)
            Picker("advanced.som-topology", selection: $analysis.somTopology) {
                ForEach([GlifiStudioSOMTopology.rectangular, .hexagonal], id: \.self) { topology in
                    Text(LocalizedStringKey("advanced.som-topology.\(topology.rawValue)")).tag(
                        topology)
                }
            }
            Toggle("advanced.som-custom-phases", isOn: $analysis.somKHUsesCustomPhases)
            if analysis.somKHUsesCustomPhases {
                DisclosureGroup("advanced.som-phase-one") { somKHPhaseFields(first: true) }
                DisclosureGroup("advanced.som-phase-two") { somKHPhaseFields(first: false) }
            } else {
                Text("advanced.som-default-phases").font(.caption).foregroundStyle(.secondary)
            }
            Toggle("advanced.som-explicit-codebooks", isOn: $analysis.somKHUsesExplicitCodebooks)
            if analysis.somKHUsesExplicitCodebooks {
                Text("advanced.som-codebook-input-help").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $analysis.somKHInitialCodebooks)
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
                    .accessibilityLabel("advanced.som-initial-codebooks")
                if let output = analysis.output, output.tool.usesDenseMatrix {
                    DisclosureGroup("advanced.matrix-vocabulary") {
                        Text(output.input.terms.joined(separator: " · "))
                            .font(.caption).textSelection(.enabled)
                    }
                }
            }
            Toggle("advanced.som-codebooks", isOn: $analysis.clustersSOMCodebooks)
            if analysis.clustersSOMCodebooks {
                integerField("advanced.codebook-clusters", value: $analysis.somCodebookClusterCount)
            }
        case .som:
            integerField("advanced.width", value: $analysis.gridWidth)
            integerField("advanced.height", value: $analysis.gridHeight)
            integerField("advanced.epochs", value: $analysis.epochs)
        case .somAdvanced:
            integerField("advanced.width", value: $analysis.gridWidth)
            integerField("advanced.height", value: $analysis.gridHeight)
            integerField("advanced.epochs", value: $analysis.epochs)
            Picker("advanced.som-topology", selection: $analysis.somTopology) {
                ForEach([GlifiStudioSOMTopology.rectangular, .hexagonal], id: \.self) { topology in
                    Text(LocalizedStringKey("advanced.som-topology.\(topology.rawValue)")).tag(
                        topology)
                }
            }
            DisclosureGroup("advanced.som-neighborhood") {
                decimalField("advanced.initial-radius", value: $analysis.somInitialRadius)
                decimalField("advanced.final-radius", value: $analysis.somFinalRadius)
                decimalField("advanced.tolerance", value: $analysis.somTolerance)
            }
            Toggle("advanced.som-codebooks", isOn: $analysis.clustersSOMCodebooks)
            if analysis.clustersSOMCodebooks {
                integerField("advanced.codebook-clusters", value: $analysis.somCodebookClusterCount)
            }
            Text("advanced.completion-limits").font(.caption).foregroundStyle(.secondary)
        case .clara:
            integerField("advanced.clusters", value: $analysis.clusterCount)
            integerField("advanced.sample-size", value: $analysis.sampleSize)
        case .topics, .topicSelection:
            if analysis.tool == .topics {
                integerField("advanced.topics", value: $analysis.topicCount)
            } else {
                TextField("advanced.topic-candidates", text: $analysis.topicCandidatesDraft)
                    .textFieldStyle(.roundedBorder)
                Picker("advanced.selection-criterion", selection: $analysis.topicCriterion) {
                    ForEach(
                        [
                            GlifiStudioTopicSelectionCriterion.heldOutPerplexity, .caoJuan2009,
                            .arun2010, .deveaud2014, .griffiths2004,
                        ], id: \.self
                    ) { criterion in
                        Text(
                            LocalizedStringKey("advanced.selection-criterion.\(criterion.rawValue)")
                        ).tag(criterion)
                    }
                }
                integerField("advanced.folds", value: $analysis.folds)
                Text("advanced.topic-selection-help").font(.caption).foregroundStyle(.secondary)
            }
            integerField("advanced.topic-terms", value: $analysis.topicTermsShown)
            DisclosureGroup("advanced.sampling") {
                VStack(alignment: .leading, spacing: 10) {
                    decimalField("advanced.alpha", value: $analysis.alpha)
                    decimalField("advanced.beta", value: $analysis.beta)
                    integerField("advanced.burn-in", value: $analysis.burnIn)
                    integerField("advanced.posterior-samples", value: $analysis.posteriorSamples)
                    integerField("advanced.thinning", value: $analysis.thinning)
                }
                .padding(.top, 8)
            }
        case .classification:
            decimalField("advanced.smoothing", value: $analysis.smoothing)
        case .classifierValidation:
            integerField("advanced.folds", value: $analysis.folds)
        case .coding, .codeCrosstab:
            Text("advanced.rules-parameters").foregroundStyle(.secondary)
        case .distances:
            distancePicker
        case .correspondence:
            Text("advanced.correspondence-parameters").foregroundStyle(.secondary)
        case .hierarchical:
            distancePicker
            Picker("advanced.linkage", selection: $analysis.linkage) {
                ForEach(["single", "complete", "average"], id: \.self) { linkage in
                    Text(LocalizedStringKey("advanced.linkage.\(linkage)")).tag(linkage)
                }
            }
        case .network:
            decimalField("advanced.minimum-jaccard", value: $analysis.minimumJaccard)
            integerField("advanced.maximum-edges", value: $analysis.maximumEdges)
        }
    }

    @ViewBuilder private func somKHPhaseFields(first: Bool) -> some View {
        integerField(
            "advanced.som-phase-steps",
            value:
                first ? $analysis.somKHFirstSteps : $analysis.somKHSecondSteps)
        decimalField(
            "advanced.som-learning-rate",
            value:
                first ? $analysis.somKHFirstLearningRate : $analysis.somKHSecondLearningRate)
        decimalField(
            "advanced.som-phase-radius",
            value:
                first ? $analysis.somKHFirstRadius : $analysis.somKHSecondRadius)
    }

    @ViewBuilder private func mdsParameters(search: Bool) -> some View {
        distancePicker
        Picker(
            "advanced.mds-method",
            selection: search ? $analysis.mdsSearchMethod : $analysis.mdsMethod
        ) {
            ForEach(
                search
                    ? [GlifiStudioMDSMethod.metric, .kruskal, .sammon, .ordinal]
                    : [.classical, .metric, .kruskal, .sammon, .ordinal], id: \.self
            ) { method in
                Text(localizedTitle("advanced.mds.\(method.rawValue)")).tag(method)
            }
        }
        Stepper("advanced.dimensions", value: $analysis.dimensions, in: 1...2)
        Text(analysis.dimensions, format: .number).foregroundStyle(.secondary)
        integerField("advanced.iterations", value: $analysis.maximumIterations)
        if (search ? analysis.mdsSearchMethod : analysis.mdsMethod) == .ordinal {
            Text("advanced.ordinal-caveat").font(.callout).foregroundStyle(.secondary)
        }
        if search {
            integerField("advanced.starts", value: $analysis.mdsStarts)
            decimalField("advanced.tolerance", value: $analysis.mdsTolerance)
            Text("advanced.completion-limits").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var distancePicker: some View {
        Picker("advanced.distance", selection: $analysis.distance) {
            ForEach(
                [
                    GlifiStudioTextDistance.jaccard, .simpson, .dice, .cosine, .euclidean,
                    .manhattan,
                ],
                id: \.self
            ) { distance in
                Text(localizedTitle("advanced.distance.\(distance.rawValue)")).tag(distance)
            }
        }
    }

    private func labels(_ snapshot: GlifiStudioProjectSnapshot) -> some View {
        let selected = Set(selectedIDs(snapshot))
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    analysis.tool == .codeCrosstab
                        ? "advanced.group-help"
                        : analysis.tool == .classifierValidation
                            ? "advanced.validation-label-help"
                            : "advanced.classification-label-help"
                )
                .font(.callout).foregroundStyle(.secondary)
                if selected.count <= GlifiStudioTextAnalytics.projectLaboratoryMaximumSources {
                    ForEach(
                        Array(snapshot.sources.enumerated()).filter {
                            selected.contains($0.element.sourceRevisionID)
                        }, id: \.element.sourceRevisionID
                    ) { index, source in
                        VStack(alignment: .leading, spacing: 4) {
                            sourceLabel(index: index, source: source)
                            TextField(
                                "advanced.class-or-group",
                                text: Binding(
                                    get: { analysis.labels[source.sourceRevisionID, default: ""] },
                                    set: { analysis.labels[source.sourceRevisionID] = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                } else {
                    Text("advanced.scope-limit").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("advanced.labels", systemImage: "tag")
        }
    }

    private var rules: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("advanced.rules-help").font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $analysis.rules)
                    .font(.body.monospaced())
                    .frame(minHeight: 150)
                    .accessibilityLabel("advanced.rules")
                Text("advanced.rules-example").font(.caption.monospaced()).foregroundStyle(
                    .secondary)
            }
            .padding(6)
        } label: {
            Label("advanced.rules", systemImage: "text.badge.checkmark")
        }
    }

    @ViewBuilder private var results: some View {
        if let output = analysis.output {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey(output.tool.titleKey)).font(.title2.bold())
                        Text(output.completedAt, format: .dateTime.day().month().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu("advanced.export", systemImage: "square.and.arrow.up") {
                        Button("advanced.export-result") {
                            exportData = output.encodedResult
                            exportFilename = "GlifiStudio-analysis"
                            showsExporter = true
                        }
                        Button("advanced.export-request") {
                            exportData = output.canonicalRequest
                            exportFilename = "GlifiStudio-request"
                            showsExporter = true
                        }
                    }
                    .disabled(model.isBusy)
                }
                Label(
                    LocalizedStringKey(
                        output.typedResult == nil
                            ? "research.saved.restored" : "research.saved.session-copy"),
                    systemImage: output.typedResult == nil
                        ? "externaldrive.badge.checkmark" : "clock"
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if analysis.isDraftChanged {
                    Label("advanced.draft-changed", systemImage: "info.circle")
                        .fixedSize(horizontal: false, vertical: true)
                }
                if output.isOrdinalMDS {
                    Label("advanced.ordinal-caveat", systemImage: "info.circle")
                        .fixedSize(horizontal: false, vertical: true)
                }
                if output.diagnostics.contains(where: {
                    $0.key == "advanced.convergence" && $0.value == "advanced.limit-reached"
                }) {
                    Label("advanced.not-converged", systemImage: "exclamationmark.triangle")
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(
                    Array(
                        output.diagnostics.filter {
                            [
                                "advanced.selected-topics", "advanced.chosen-run",
                                "advanced.completed-runs",
                            ].contains($0.key)
                        }.enumerated()), id: \.offset
                ) { _, diagnostic in
                    LabeledContent(LocalizedStringKey(diagnostic.key), value: diagnostic.value)
                }
                if let snapshot = model.snapshot,
                    Set(selectedIDs(snapshot)) != Set(output.input.sourceRevisionIDs)
                {
                    Label("advanced.scope-changed", systemImage: "exclamationmark.circle")
                        .fixedSize(horizontal: false, vertical: true)
                }
                scopeSummary(output)
                if !output.factorPoints.isEmpty {
                    Chart(output.factorPoints) { point in
                        PointMark(
                            x: .value(String(localized: "advanced.axis-one"), point.x),
                            y: .value(String(localized: "advanced.axis-two"), point.y)
                        )
                        .foregroundStyle(
                            by: .value(
                                "series",
                                String(
                                    localized:
                                        String.LocalizationValue(point.seriesKey), locale: locale))
                        )
                        .symbol(
                            by: .value(
                                "series",
                                String(
                                    localized:
                                        String.LocalizationValue(point.seriesKey), locale: locale))
                        )
                        .accessibilityLabel(point.label)
                        .accessibilityValue(
                            Text("\(point.x, format: .number), \(point.y, format: .number)"))
                    }
                    .chartXScale(domain: output.factorDomain)
                    .chartYScale(domain: output.factorDomain)
                    .chartPlotStyle { plot in plot.aspectRatio(1, contentMode: .fit) }
                    .frame(height: 300)
                    Text("caveat.visual.symmetric-map").font(.caption).foregroundStyle(.secondary)
                }
                if !output.treeVertices.isEmpty {
                    Chart(output.treeVertices) { vertex in
                        LineMark(
                            x: .value(String(localized: "visual.axis.leaf-order"), vertex.x),
                            y: .value(String(localized: "advanced.merge-height"), vertex.y),
                            series: .value("merge", vertex.segment)
                        )
                        .foregroundStyle(.secondary)
                    }
                    .chartXAxis {
                        AxisMarks(values: Array(1...output.treeLeafLabels.count)) { axis in
                            AxisValueLabel {
                                if let value = axis.as(Int.self),
                                    output.treeLeafLabels.indices.contains(value - 1)
                                {
                                    Text(output.treeLeafLabels[value - 1])
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                    Text("advanced.tree-table-help").font(.caption).foregroundStyle(.secondary)
                }
                if !output.points.isEmpty {
                    Chart(output.points) { point in
                        PointMark(
                            x: .value(String(localized: "advanced.axis-one"), point.x),
                            y: .value(String(localized: "advanced.axis-two"), point.y)
                        )
                        .accessibilityLabel(
                            Text("workspace.source.ordinal \(point.sourceNumber)")
                        )
                        .accessibilityValue(
                            output.isOneDimensional
                                ? Text(point.x, format: .number)
                                : Text("\(point.x, format: .number), \(point.y, format: .number)"))
                    }
                    .chartYAxis(output.isOneDimensional ? .hidden : .automatic)
                    .frame(height: 260)
                    .padding(.vertical, 8)
                    Text("advanced.chart-help").font(.caption).foregroundStyle(.secondary)
                }
                resultTable(output)
                methodDetails(output)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ContentUnavailableView(
                "advanced.result-empty.title", systemImage: "chart.bar.doc.horizontal",
                description: Text("advanced.result-empty.description")
            )
            .frame(maxWidth: .infinity, minHeight: 320)
        }
    }

    private func scopeSummary(_ output: StudioAdvancedOutput) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("summary.result.sources") {
                    Text(output.input.sourceRevisionIDs.count, format: .number)
                }
                LabeledContent("advanced.tokens") {
                    Text(output.input.lexicalTokenCount, format: .number)
                }
                if output.tool.usesDenseMatrix {
                    LabeledContent("advanced.matrix-vocabulary") {
                        Text(
                            "\(output.input.terms.count, format: .number) / \(output.input.vocabularySize, format: .number)"
                        )
                    }
                } else {
                    LabeledContent("advanced.full-vocabulary") {
                        Text(output.input.vocabularySize, format: .number)
                    }
                }
                Text(LocalizedStringKey(output.tool.caveatKey)).font(.callout).foregroundStyle(
                    .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    private func resultTable(_ output: StudioAdvancedOutput) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("advanced.search-results", text: $analysis.search)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("advanced.search-results")
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                if output.tables.count > 1 {
                    Picker("advanced.result-table", selection: $analysis.tableIndex) {
                        ForEach(Array(output.tables.enumerated()), id: \.offset) { index, table in
                            Text(LocalizedStringKey(table.titleKey)).tag(index)
                        }
                    }
                }
                if analysis.isFiltering {
                    ProgressView("advanced.filtering")
                } else if analysis.visibleRows.isEmpty {
                    Text("advanced.no-rows").foregroundStyle(.secondary)
                } else if let table = analysis.selectedTable {
                    Table(analysis.visibleRows) {
                        TableColumnForEach(Array(table.columns.enumerated()), id: \.offset) {
                            index, key in
                            TableColumn(LocalizedStringKey(key)) { row in
                                if row.values.indices.contains(index) {
                                    Text(row.values[index]).monospacedDigit().textSelection(
                                        .enabled)
                                }
                            }
                        }
                        TableColumn("advanced.source-action") { row in
                            if let revision = row.sourceRevisionID {
                                Button(
                                    "advanced.open-source", systemImage: "doc.text.magnifyingglass"
                                ) {
                                    Task {
                                        await model.runAdvancedAnalysis { session in
                                            source = try await session.sourceText(
                                                sourceRevisionID: revision)
                                            showsSource = true
                                        }
                                    }
                                }
                                .labelStyle(.iconOnly)
                                .help("advanced.open-source")
                                .disabled(model.isBusy)
                            } else {
                                Text("—").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(minHeight: 220, idealHeight: 340)
                }
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack {
                        rowCount
                        Spacer()
                        pagination
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        rowCount
                        pagination
                    }
                }
            }
            .padding(6)
        }
    }

    private var rowCount: some View {
        LabeledContent("advanced.matching-rows") {
            Text(analysis.matchingRowCount, format: .number)
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private var pagination: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { paginationControls }
            VStack(alignment: .leading, spacing: 10) { paginationControls }
        }
    }

    @ViewBuilder private var paginationControls: some View {
        Button("advanced.first-page", systemImage: "backward.end") { analysis.showPage(0) }
            .disabled(analysis.page == 0)
        Button("advanced.previous-page", systemImage: "chevron.backward") {
            analysis.showPage(analysis.page - 1)
        }
        .disabled(analysis.page == 0)
        TextField(
            "advanced.page",
            value: Binding(get: { analysis.page + 1 }, set: { analysis.showPage($0 - 1) }),
            format: .number
        )
        .textFieldStyle(.roundedBorder)
        .frame(width: 60)
        Text("/ \(analysis.pageCount, format: .number)")
        Button("advanced.next-page", systemImage: "chevron.forward") {
            analysis.showPage(analysis.page + 1)
        }
        .disabled(analysis.page + 1 >= analysis.pageCount)
        Button("advanced.last-page", systemImage: "forward.end") {
            analysis.showPage(analysis.pageCount - 1)
        }
        .disabled(analysis.page + 1 >= analysis.pageCount)
    }

    private func methodDetails(_ output: StudioAdvancedOutput) -> some View {
        DisclosureGroup("advanced.method-and-provenance") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("advanced.method") {
                    Text(output.methodIdentifier).textSelection(.enabled)
                }
                LabeledContent("advanced.validation") {
                    Text(LocalizedStringKey("advanced.validation.\(output.validationStatus)"))
                }
                Text("advanced.validation-help").font(.caption).foregroundStyle(.secondary)
                ForEach(Array(output.parameters.enumerated()), id: \.offset) { _, parameter in
                    LabeledContent(LocalizedStringKey(parameter.key)) {
                        Text(parameter.value).textSelection(.enabled)
                    }
                }
                ForEach(Array(output.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                    LabeledContent(LocalizedStringKey(diagnostic.key)) {
                        if diagnostic.value.hasPrefix("advanced.") {
                            Text(LocalizedStringKey(diagnostic.value))
                        } else {
                            Text(diagnostic.value).textSelection(.enabled)
                        }
                    }
                }
                LabeledContent("advanced.request-digest") {
                    Text(output.requestDigest).font(.caption.monospaced()).textSelection(.enabled)
                }
                LabeledContent("summary.lineage.project") {
                    Text(output.input.projectID).font(.caption.monospaced()).textSelection(.enabled)
                }
                LabeledContent("summary.lineage.generation") {
                    Text(output.input.generation, format: .number)
                }
                ForEach(Array(output.input.sourceRevisionIDs.enumerated()), id: \.element) {
                    index, revision in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("summary.source.label")
                            Text(output.sourceNumbers[index], format: .number)
                        }
                        if output.tool.needsLabels {
                            Text(LocalizedStringKey(labelRole(output, index: index)))
                            Text(
                                output.sourceLabels[index].isEmpty
                                    ? "—" : output.sourceLabels[index])
                        }
                        Text(revision).textSelection(.enabled)
                        Text(output.input.contentDigests[index]).textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.monospaced())
                }
                if let rules = output.codingRules {
                    DisclosureGroup("advanced.used-rules") {
                        Text(rules).font(.body.monospaced()).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(
                    output.tool.usesDenseMatrix
                        ? "advanced.matrix-policy" : "advanced.full-token-policy"
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 10)
        }
    }

    private func integerField(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).textFieldStyle(.roundedBorder).frame(
                minWidth: 70, idealWidth: 95, maxWidth: 130)
        }
    }

    private func decimalField(_ key: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number).textFieldStyle(.roundedBorder).frame(
                minWidth: 70, idealWidth: 95, maxWidth: 130)
        }
    }

    private func selectedIDs(_ snapshot: GlifiStudioProjectSnapshot) -> [String] {
        switch model.textAnalysisScope {
        case .allSources: snapshot.sources.map(\.sourceRevisionID)
        case .selectedSources:
            snapshot.sources.map(\.sourceRevisionID).filter {
                model.selectedTextAnalysisSourceRevisionIDs.contains($0)
            }
        }
    }

    private func blockedReason(_ snapshot: GlifiStudioProjectSnapshot) -> String? {
        let ids = selectedIDs(snapshot)
        guard !ids.isEmpty else { return "advanced.needs-scope" }
        guard ids.count <= GlifiStudioTextAnalytics.projectLaboratoryMaximumSources else {
            return "advanced.scope-limit"
        }
        if [.mds, .mdsSearch, .mdsOrdinal, .mdsOrdinalSearch].contains(analysis.tool),
            ids.count <= analysis.dimensions
        {
            return "advanced.needs-mds-dimensions"
        }
        if [.mdsSearch, .mdsOrdinalSearch].contains(analysis.tool),
            !(1...32).contains(analysis.mdsStarts)
        {
            return "advanced.needs-starts"
        }
        if analysis.tool == .somKH && analysis.somKHUsesExplicitCodebooks,
            analysis.somKHInitialCodebooks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return "advanced.needs-codebooks"
        }
        if analysis.tool == .topicSelection {
            if analysis.folds != 0 && (analysis.folds < 2 || analysis.folds > ids.count) {
                return "advanced.needs-topic-folds"
            }
            if analysis.topicCriterion == .heldOutPerplexity && analysis.folds == 0 {
                return "advanced.needs-held-out-folds"
            }
        }
        if analysis.tool.needsRules
            && analysis.rules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return "advanced.needs-rules"
        }
        if analysis.tool == .classification {
            let labels = ids.map {
                analysis.labels[$0, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let classes = Set(labels.filter { !$0.isEmpty })
            if classes.count < 2 || !labels.contains(where: \.isEmpty) {
                return "advanced.needs-training-and-prediction"
            }
        }
        if analysis.tool == .classifierValidation {
            let labels = ids.map {
                analysis.labels[$0, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if labels.contains(where: \.isEmpty) || Set(labels).count < 2 {
                return "advanced.needs-validation-labels"
            }
            if analysis.folds < 2
                || Dictionary(grouping: labels, by: { $0 }).values.contains(where: {
                    $0.count < analysis.folds
                })
            {
                return "advanced.needs-fold-support"
            }
        }
        return nil
    }

    private func labelRole(_ output: StudioAdvancedOutput, index: Int) -> String {
        if output.tool == .codeCrosstab {
            return output.sourceLabels[index].isEmpty
                ? "advanced.role.missing-group" : "advanced.role.group"
        }
        if output.tool == .classifierValidation { return "advanced.role.validation" }
        return output.sourceLabels[index].isEmpty
            ? "advanced.role.prediction" : "advanced.role.training"
    }

    private func localizedTitle(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .main, locale: locale)
    }

    private func sourceLabel(index: Int, source: GlifiStudioProjectSource) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("summary.source.label")
                Text(index + 1, format: .number)
            }
            .accessibilityElement(children: .combine)
            Text(source.sourceRevisionID).font(.caption2.monospaced()).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        }
    }
}

private struct StudioAdvancedResultDocument: FileDocument {
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
