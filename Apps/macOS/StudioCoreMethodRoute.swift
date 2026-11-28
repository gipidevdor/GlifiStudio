// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI

/// Research questions shared by every analytical entry point.
nonisolated enum StudioAnalysisTheme: String, CaseIterable, Identifiable, Sendable {
    case vocabulary, relationships, comparison, structure, classification, coding, validation,
        preparation
    var id: Self { self }
    var titleKey: String { "analysis.theme.\(rawValue).title" }
    var descriptionKey: String { "analysis.theme.\(rawValue).description" }
    var systemImage: String {
        switch self {
        case .vocabulary: "textformat.abc"
        case .relationships: "point.3.connected.trianglepath.dotted"
        case .comparison: "arrow.left.arrow.right"
        case .structure: "chart.dots.scatter"
        case .classification: "tag"
        case .coding: "highlighter"
        case .validation: "checkmark.seal"
        case .preparation: "tablecells"
        }
    }
}

nonisolated enum StudioCoreMethodFamily: String, CaseIterable, Identifiable, Sendable {
    case corpus, statistics, evaluation, operators, advanced, linguistics, khMatrix, khLanguage
    var id: Self { self }
    var titleKey: String { "core-features.\(rawValue)" }
    var systemImage: String {
        switch self {
        case .corpus: "chart.bar.doc.horizontal"
        case .statistics: "function"
        case .evaluation: "checkmark.seal"
        case .operators: "square.grid.3x3"
        case .advanced: "point.3.connected.trianglepath.dotted"
        case .linguistics: "textformat.abc"
        case .khMatrix: "tablecells"
        case .khLanguage: "text.badge.checkmark"
        }
    }
}

/// Concrete, searchable entry points into the existing workbench selections.
nonisolated enum StudioCoreMethodRoute: Hashable, Identifiable, Sendable {
    case corpus(StudioCorpusMethod)
    case statistics(GlifiStudioStatisticsOperation)
    case evaluation(StudioEvaluationTool)
    case operators(GlifiStudioCoreOperator)
    case advanced(StudioAdvancedTool)
    case linguistics(StudioLinguisticTool)
    case community(GlifiStudioGraphCommunityMethod)
    case layout(GlifiStudioGraphLayoutMethod)
    case mdsMethod(GlifiStudioMDSMethod)
    case khMatrix(StudioKHMatrixTool)
    case khLanguage(StudioKHLanguageTool)

    var id: String { "\(family.rawValue).\(rawName)" }
    static var allCases: [Self] {
        StudioCorpusMethod.allCases.map(Self.corpus)
            + GlifiStudioStatisticsOperation.allCases.map(Self.statistics)
            + StudioEvaluationTool.allCases.map(Self.evaluation)
            + GlifiStudioCoreOperator.allCases.map(Self.operators)
            + StudioAdvancedTool.allCases.map(Self.advanced)
            + StudioLinguisticTool.allCases.map(Self.linguistics)
            + GlifiStudioGraphCommunityMethod.allCases.map(Self.community)
            + GlifiStudioGraphLayoutMethod.allCases.map(Self.layout)
            + [GlifiStudioMDSMethod.classical, .kruskal, .sammon, .metric, .ordinal].map(
                Self.mdsMethod)
            + StudioKHMatrixTool.allCases.map(Self.khMatrix)
            + StudioKHLanguageTool.allCases.map(Self.khLanguage)
    }

    var family: StudioCoreMethodFamily {
        switch self {
        case .corpus: .corpus
        case .statistics: .statistics
        case .evaluation: .evaluation
        case .operators: .operators
        case .advanced: .advanced
        case .linguistics: .linguistics
        case .community, .layout: .operators
        case .mdsMethod: .advanced
        case .khMatrix: .khMatrix
        case .khLanguage: .khLanguage
        }
    }

    var rawName: String {
        switch self {
        case let .corpus(method): method.rawValue
        case let .statistics(method): method.rawValue
        case let .evaluation(method): method.rawValue
        case let .operators(method): method.rawValue
        case let .advanced(method): method.rawValue
        case let .linguistics(method): method.rawValue
        case let .community(method): method.rawValue
        case let .layout(method): method.rawValue
        case let .mdsMethod(method): "mds.\(method.rawValue)"
        case let .khMatrix(method): method.rawValue
        case let .khLanguage(method): method.rawValue
        }
    }

    var titleKey: String {
        switch self {
        case let .corpus(method): method.titleKey
        case let .statistics(method): "statistics.operation.\(method.rawValue)"
        case let .evaluation(method): method.titleKey
        case let .operators(method): "operators.method.\(method.rawValue)"
        case let .advanced(method): method.titleKey
        case let .linguistics(method): method.titleKey
        case let .community(method): "operators.community-method.\(method.rawValue)"
        case let .layout(method): "operators.layout-method.\(method.rawValue)"
        case let .mdsMethod(method): "advanced.mds.\(method.rawValue)"
        case let .khMatrix(method): method.titleKey
        case let .khLanguage(method): method.titleKey
        }
    }

    var theme: StudioAnalysisTheme {
        switch self {
        case let .corpus(method):
            switch method {
            case .dispersion: .vocabulary
            case .association, .collocations, .windowCollocations, .lexicalNetwork, .windowNetwork:
                .relationships
            case .similarity, .groupMetrics, .postHoc, .correlation, .pairedMetrics: .comparison
            case .correspondence, .pca, .lsa, .nmf, .hierarchical, .kmeans: .structure
            }
        case let .statistics(method):
            switch method {
            case .cohenKappa, .alphaNominal, .alphaNumeric, .fleissKappa, .alphaInterval:
                .coding
            case .descriptive: .vocabulary
            case .normalCDF, .normalDensity, .normalQuantile, .tPValue, .fPValue, .rangeCDF,
                .rangeTail, .rangeQuantile, .tQuantile:
                .validation
            case .welchT, .oneSampleT, .pairedT, .anova, .welchANOVA, .mannWhitney, .wilcoxon,
                .kruskalWallis, .pearson, .spearman, .spearmanExact, .cohenD, .hedgesG,
                .rankBiserial, .epsilonSquared, .pearsonInterval, .tukey, .gamesHowell, .dunn,
                .bonferroni, .benjaminiHochberg, .bootstrapMean, .blockBootstrap, .permutation,
                .contingency, .fisherExact, .monteCarloChiSquare, .bootstrapBCa, .plannedContrasts:
                .comparison
            }
        case let .evaluation(method): method == .temporal ? .comparison : .validation
        case let .operators(method):
            switch method {
            case .svd, .truncatedSVD, .pca, .lsa, .nmf, .kMeans, .hacCutCount, .hacCutHeight,
                .silhouette:
                .structure
            case .transformCounts, .transformBinary, .transformPerThousand, .transformTFIDF,
                .transpose, .lidstone:
                .preparation
            case .distances, .cosine, .euclidean, .manhattan, .jaccard, .dice, .simpson,
                .weightedJaccard, .multisetDice, .kl, .jensenShannon, .jensenShannonDistance,
                .hellinger:
                .comparison
            case .degree, .pageRank, .betweenness, .harmonicCloseness, .weightedBetweenness,
                .weightedCloseness, .weakComponents, .strongComponents, .eigenvector, .louvain,
                .modularity, .communities, .graphLayout, .minimumSpanningForest:
                .relationships
            case .lexicalObservation, .zipfFit, .heapsFit: .vocabulary
            }
        case let .advanced(method):
            switch method {
            case .classification, .classifierValidation: .classification
            case .coding, .codeCrosstab: .coding
            case .network: .relationships
            case .distances: .comparison
            case .mds, .som, .clara, .topics, .correspondence, .hierarchical,
                .mdsSearch, .somAdvanced, .topicSelection, .mdsOrdinal, .mdsOrdinalSearch,
                .somPCAInitialization, .somKH:
                .structure
            }
        case .linguistics(.availability), .linguistics(.annotation): .preparation
        case .linguistics(.coding): .coding
        case .community, .layout: .relationships
        case .mdsMethod: .structure
        case let .khMatrix(method): method.theme
        case let .khLanguage(method): method.theme
        }
    }

    /// The task this particular method performs inside its research theme.
    var purposeKey: String {
        switch self {
        case let .corpus(method): method.descriptionKey
        case let .advanced(method): method.descriptionKey
        case let .evaluation(method): method.descriptionKey
        case let .linguistics(method): method.descriptionKey
        case let .statistics(method): "analysis.role.statistics.\(method.rawValue)"
        case let .operators(method): "analysis.role.operators.\(method.rawValue)"
        case let .community(method): "analysis.role.community.\(method.rawValue)"
        case let .layout(method): "analysis.role.layout.\(method.rawValue)"
        case let .mdsMethod(method): "analysis.role.mds.\(method.rawValue)"
        case let .khMatrix(method): method.descriptionKey
        case let .khLanguage(method): method.descriptionKey
        }
    }

    func matches(_ query: String, locale: Locale) -> Bool {
        let label = String(localized: String.LocalizationValue(titleKey), locale: locale)
        let aliases: String
        switch self {
        case .operators(.communities):
            aliases = "comunità community Girvan Newman CNM fast greedy walktrap"
        case .operators(.graphLayout):
            aliases = "grafo graph layout Fruchterman Reingold Kamada Kawai FR KK"
        case .operators(.minimumSpanningForest):
            aliases = "Prim MST minimum spanning tree forest foresta minima"
        case .operators(.distances):
            aliases = "matrice matrix Jaccard Dice cosine Euclidean Manhattan Simpson"
        case .community(.edgeBetweenness): aliases = "Girvan Newman GN community"
        case .community(.fastGreedy): aliases = "Clauset Newman Moore CNM community fast greedy"
        case .community(.walktrap): aliases = "walk trap community random walk"
        case .layout(.fruchtermanReingold): aliases = "FR graph layout"
        case .layout(.kamadaKawai): aliases = "KK graph layout"
        case .corpus, .statistics, .evaluation, .operators, .advanced, .linguistics, .mdsMethod,
            .khMatrix, .khLanguage:
            aliases = ""
        }
        let purpose = String(localized: String.LocalizationValue(purposeKey), locale: locale)
        let themeLabel = String(localized: String.LocalizationValue(theme.titleKey), locale: locale)
        let text = "\(label) \(rawName) \(aliases) \(purpose) \(themeLabel)"
        return query.split(whereSeparator: \.isWhitespace).allSatisfy {
            text.localizedStandardContains(String($0))
        }
    }

    @MainActor func activate(on model: StudioHomeModel) -> StudioSection {
        switch self {
        case let .corpus(method):
            model.corpusMethods.tool = method
            return .corpusMethods
        case let .statistics(method):
            model.statistics.select(method)
            return .statistics
        case let .evaluation(method):
            model.evaluation.tool = method
            return .evaluation
        case let .operators(method):
            model.operators.request.operation = method
            return .operators
        case let .advanced(method):
            model.advancedAnalysis.tool = method
            return .advancedAnalysis
        case let .linguistics(method):
            model.linguistics.tool = method
            return .linguistics
        case let .community(method):
            model.operators.request.operation = .communities
            model.operators.request.communityMethod = method.rawValue
            return .operators
        case let .layout(method):
            model.operators.request.operation = .graphLayout
            model.operators.request.layoutMethod = method.rawValue
            return .operators
        case let .mdsMethod(method):
            model.advancedAnalysis.tool = .mds
            model.advancedAnalysis.mdsMethod = method
            return .advancedAnalysis
        case let .khMatrix(method):
            model.khMatrix.tool = method
            return .khMatrix
        case let .khLanguage(method):
            model.khLanguage.tool = method
            return .khLanguage
        }
    }
}

/// Context follows the selected operation in every workbench.
struct StudioAnalysisRoleView: View {
    let route: StudioCoreMethodRoute
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(LocalizedStringKey(route.theme.titleKey), systemImage: route.theme.systemImage)
                .font(.caption).foregroundStyle(.secondary)
            Text(LocalizedStringKey(route.purposeKey))
                .font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
