// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI

enum StudioSection: String, CaseIterable, Identifiable {
    case overview
    case project
    case sources
    case tools
    #if os(macOS)
        case textAnalysis
        case advancedAnalysis
        case corpusMethods
        case statistics
        case evaluation
        case operators
        case linguistics
    #endif
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
        case .tools: "workspace.tools.title"
        #if os(macOS)
            case .textAnalysis: "sidebar.text-analysis"
            case .advancedAnalysis: "workspace.advanced.title"
            case .corpusMethods: "core-features.corpus"
            case .statistics: "core-features.statistics"
            case .evaluation: "core-features.evaluation"
            case .operators: "core-features.operators"
            case .linguistics: "core-features.linguistics"
        #endif
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
        case .tools: "square.grid.2x2"
        #if os(macOS)
            case .textAnalysis: "text.magnifyingglass"
            case .advancedAnalysis: "point.3.connected.trianglepath.dotted"
            case .corpusMethods: "chart.bar.doc.horizontal"
            case .statistics: "function"
            case .evaluation: "checkmark.seal"
            case .operators: "square.grid.3x3"
            case .linguistics: "textformat.abc"
        #endif
        case .investigation: "lightbulb"
        case .query: "magnifyingglass"
        case .findings: "list.bullet.rectangle"
        case .coding: "highlighter"
        case .export: "square.and.arrow.up"
        }
    }
}

enum StudioToolGroup: String, CaseIterable, Identifiable {
    case read
    case compare
    case model
    case publish

    var id: Self { self }
    var titleKey: String { "workspace.tools.group.\(rawValue)" }
}

/// Discoverable routes to existing operations; scientific computation remains in GlifiKit.
enum StudioToolDestination: String, CaseIterable, Identifiable {
    case corpus, query, coding
    #if os(macOS)
        case summary, documents, lexicon, termWeights, lexicalLaws
        case mds, som, clara, topics, classification, classifierValidation
        case codingRules, codeCrosstab, distances, correspondence, hierarchical, network
        case corpusMethods, statistics, evaluation, operators, linguistics
    #endif
    case keyness, relationships, themes, similarity, review, export

    var id: Self { self }
    var titleKey: String { "workspace.tool.\(rawValue).title" }
    var descriptionKey: String { "workspace.tool.\(rawValue).description" }

    var group: StudioToolGroup {
        switch self {
        case .corpus, .query, .coding: .read
        #if os(macOS)
            case .summary, .documents, .lexicon, .lexicalLaws: .read
            case .termWeights, .codeCrosstab, .distances: .compare
            case .corpusMethods: .compare
            case .statistics, .evaluation, .operators, .linguistics: .model
            case .mds, .som, .clara, .topics, .classification, .classifierValidation,
                .codingRules, .correspondence, .hierarchical, .network:
                .model
        #endif
        case .keyness, .relationships, .similarity: .compare
        case .themes, .review: .model
        case .export: .publish
        }
    }

    var systemImage: String {
        switch self {
        case .corpus: "chart.bar.doc.horizontal"
        case .query: "magnifyingglass"
        case .coding: "highlighter"
        #if os(macOS)
            case .summary: "text.alignleft"
            case .documents: "doc.text.magnifyingglass"
            case .lexicon: "textformat.abc"
            case .termWeights: "tablecells"
            case .lexicalLaws: "chart.xyaxis.line"
            case .mds, .correspondence: "chart.dots.scatter"
            case .som: "square.grid.3x3"
            case .clara, .hierarchical: "point.3.filled.connected.trianglepath.dotted"
            case .topics: "text.bubble"
            case .classification, .classifierValidation: "tag"
            case .codingRules: "text.badge.checkmark"
            case .codeCrosstab: "tablecells"
            case .distances: "arrow.left.and.right"
            case .network: "point.3.connected.trianglepath.dotted"
            case .corpusMethods: "chart.bar.doc.horizontal"
            case .statistics: "function"
            case .evaluation: "checkmark.seal"
            case .operators: "square.grid.3x3"
            case .linguistics: "textformat.abc"
        #endif
        case .keyness: "arrow.left.arrow.right"
        case .relationships: "point.3.connected.trianglepath.dotted"
        case .themes: "text.bubble"
        case .similarity: "doc.on.doc"
        case .review: "checklist"
        case .export: "square.and.arrow.up"
        }
    }

    var searchTerms: String {
        switch self {
        case .corpus: "corpus profile profilo descrittive descriptive"
        case .query: "KWIC query concordanze concordance boolean regex"
        case .coding: "codebook annotation annotazioni accordo agreement"
        #if os(macOS)
            case .summary: "riassunto summary estrattivo extractive MMR"
            case .documents: "BM25 ranking documenti documents"
            case .lexicon: "frequenze frequencies n-grammi ngrams MTLD diversità diversity"
            case .termWeights: "TF IDF TF-IDF ponderazione weighting matrice matrix"
            case .lexicalLaws: "Zipf Heaps spettro spectrum vocabolario vocabulary"
            case .mds: "MDS multidimensional scaling Kruskal Sammon SMACOF"
            case .som: "SOM self organizing map Kohonen"
            case .clara: "CLARA PAM medoids medoidi clustering"
            case .topics: "LDA Latent Dirichlet Allocation Gibbs topic"
            case .classification: "Naive Bayes multinomial classificazione supervised"
            case .classifierValidation: "Naive Bayes cross validation k-fold accuratezza accuracy"
            case .codingRules: "KH Coder coding rules regole automatiche boolean"
            case .codeCrosstab: "crosstab contingenza contingency codici codes"
            case .distances: "Jaccard Dice cosine coseno euclidean Manhattan distanze distances"
            case .correspondence: "CA correspondence corrispondenze SVD"
            case .hierarchical: "HAC hierarchical clustering dendrogramma dendrogram"
            case .network: "rete network co-occorrenze co-occurrence Jaccard"
            case .corpusMethods:
                "corpus documenti documents multivariate PCA CA LSA NMF kmeans dispersione collocazioni finestra"
            case .statistics:
                "statistica statistics Welch ANOVA Mann Whitney Wilcoxon Kruskal Pearson Spearman bootstrap kappa alpha distribuzioni distributions"
            case .linguistics:
                "linguistica linguistic lemma lemmi POS stemming Snowball annotazioni annotation disponibilità availability coding variabili"
            case .evaluation:
                "temporale temporal date calendario gold lemma POS NER morfologia morphology boundaries qualità quality"
            case .operators:
                "operatori operators SVD matrici matrices grafi graphs PageRank Louvain comunità community CNM Walktrap Girvan Newman layout Fruchterman Reingold Kamada Kawai Prim MST foresta spanning forest silhouette Jaccard Dice Simpson KL Hellinger Zipf Heaps"
        #endif
        case .keyness: "keyness Fisher G-test gruppi groups confronto comparison"
        case .relationships: "collocazioni collocations associazioni associations rete network"
        case .themes: "CA PCA LSA NMF temi themes fattoriale factorial"
        case .similarity: "similarità similarity coseno cosine confronto comparison"
        case .review: "statistica statistics piano planner analisi analysis"
        case .export: "PDF CSV JSON Markdown export rapporto report"
        }
    }

    func matches(_ query: String, locale: Locale) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let title = String(localized: String.LocalizationValue(titleKey), locale: locale)
        let description = String(
            localized: String.LocalizationValue(descriptionKey), locale: locale)
        let searchableText = "\(title) \(description) \(searchTerms)"
        return words.allSatisfy { searchableText.localizedStandardContains(String($0)) }
    }
}

/// A destination may be opened by Return only when search identifies it unambiguously.
enum StudioToolCatalogDestination: Equatable {
    case tool(StudioToolDestination)
    #if os(macOS)
        case core(StudioCoreMethodRoute)

        static func submission(
            tools: [StudioToolDestination], coreMethods: [StudioCoreMethodRoute]
        ) -> Self? {
            guard tools.count + coreMethods.count == 1 else { return nil }
            if let method = coreMethods.first {
                return .core(method)
            }
            if let tool = tools.first {
                return .tool(tool)
            }
            return nil
        }
    #endif
}

struct StudioToolCatalogView: View {
    let onSelect: (StudioToolDestination) -> Void
    #if os(macOS)
        var onSelectCore: ((StudioCoreMethodRoute) -> Void)?
    #endif
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    init(onSelect: @escaping (StudioToolDestination) -> Void) {
        self.onSelect = onSelect
    }

    #if os(macOS)
        init(
            onSelect: @escaping (StudioToolDestination) -> Void,
            onSelectCore: @escaping (StudioCoreMethodRoute) -> Void
        ) {
            self.onSelect = onSelect
            self.onSelectCore = onSelectCore
        }
    #endif

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("workspace.tools.description")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("workspace.tools.search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .accessibilityLabel("workspace.tools.search")
                    .onSubmit {
                        #if os(macOS)
                            switch StudioToolCatalogDestination.submission(
                                tools: filteredTools, coreMethods: filteredCoreMethods)
                            {
                            case let .tool(tool): onSelect(tool)
                            case let .core(method): onSelectCore?(method)
                            case nil: break
                            }
                        #else
                            if filteredTools.count == 1, let tool = filteredTools.first {
                                onSelect(tool)
                            }
                        #endif
                    }
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("workspace.tools.results-count") {
                            Text(resultCount, format: .number).monospacedDigit()
                        }
                        if resultCount > 0 {
                            Text(
                                resultCount == 1
                                    ? "workspace.tools.return.unique"
                                    : "workspace.tools.return.choose")
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
            Divider()
            if hasNoMatches {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    #if os(macOS)
                        if let onSelectCore {
                            ForEach(StudioCoreMethodFamily.allCases) { family in
                                let routes = filteredCoreMethods.filter { $0.family == family }
                                if !routes.isEmpty {
                                    Section(LocalizedStringKey(family.titleKey)) {
                                        ForEach(routes) { route in
                                            Button {
                                                onSelectCore(route)
                                            } label: {
                                                Label(
                                                    LocalizedStringKey(route.titleKey),
                                                    systemImage: family.systemImage
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                                .padding(.vertical, 4)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    #endif
                    ForEach(StudioToolGroup.allCases) { group in
                        let tools = filteredTools.filter { $0.group == group }
                        if !tools.isEmpty {
                            Section(LocalizedStringKey(group.titleKey)) {
                                ForEach(tools) { tool in
                                    Button {
                                        onSelect(tool)
                                    } label: {
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: tool.systemImage)
                                                .font(.title3)
                                                .foregroundStyle(.tint)
                                                .frame(width: 28)
                                                .accessibilityHidden(true)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(LocalizedStringKey(tool.titleKey))
                                                    .font(.headline)
                                                Text(LocalizedStringKey(tool.descriptionKey))
                                                    .foregroundStyle(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer(minLength: 0)
                                            Image(systemName: "chevron.forward")
                                                .foregroundStyle(.secondary)
                                                .accessibilityHidden(true)
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("workspace.tools.title")
        .task { isSearchFocused = true }
    }

    private var filteredTools: [StudioToolDestination] {
        StudioToolDestination.allCases.filter { $0.matches(searchText, locale: locale) }
    }

    private var resultCount: Int {
        #if os(macOS)
            filteredTools.count + filteredCoreMethods.count
        #else
            filteredTools.count
        #endif
    }

    private var hasNoMatches: Bool {
        #if os(macOS)
            filteredTools.isEmpty && filteredCoreMethods.isEmpty
        #else
            filteredTools.isEmpty
        #endif
    }

    #if os(macOS)
        private var filteredCoreMethods: [StudioCoreMethodRoute] {
            guard onSelectCore != nil, !searchText.trimmingCharacters(in: .whitespaces).isEmpty
            else { return [] }
            return StudioCoreMethodRoute.allCases.filter { $0.matches(searchText, locale: locale) }
        }
    #endif
}

#Preview("Strumenti · italiano") {
    NavigationStack {
        StudioToolCatalogView { _ in }
    }
    .environment(\.locale, Locale(identifier: "it"))
    .frame(width: 760, height: 640)
}

#Preview("Strumenti · testo grande e scuro") {
    NavigationStack {
        StudioToolCatalogView { _ in }
    }
    .environment(\.locale, Locale(identifier: "en"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
    .frame(width: 420, height: 760)
}

#Preview("Strumenti · destra-sinistra") {
    NavigationStack {
        StudioToolCatalogView { _ in }
    }
    .environment(\.layoutDirection, .rightToLeft)
    .frame(width: 420, height: 640)
}
