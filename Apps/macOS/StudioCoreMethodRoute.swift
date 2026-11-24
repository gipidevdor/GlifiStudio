// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit

nonisolated enum StudioCoreMethodFamily: String, CaseIterable, Identifiable, Sendable {
    case corpus, statistics, evaluation, operators, advanced, linguistics
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

    var id: String { "\(family.rawValue).\(rawName)" }
    static var allCases: [Self] {
        StudioCorpusMethod.allCases.map(Self.corpus)
            + GlifiStudioStatisticsOperation.allCases.map(Self.statistics)
            + StudioEvaluationTool.allCases.map(Self.evaluation)
            + GlifiStudioCoreOperator.allCases.map(Self.operators)
            + [StudioAdvancedTool.mdsSearch, .somAdvanced, .topicSelection].map(Self.advanced)
            + StudioLinguisticTool.allCases.map(Self.linguistics)
            + GlifiStudioGraphCommunityMethod.allCases.map(Self.community)
            + GlifiStudioGraphLayoutMethod.allCases.map(Self.layout)
            + [GlifiStudioMDSMethod.classical, .kruskal, .sammon, .metric, .ordinal].map(
                Self.mdsMethod)
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
        case .corpus, .statistics, .evaluation, .operators, .advanced, .linguistics, .mdsMethod:
            aliases = ""
        }
        let text = "\(label) \(rawName) \(aliases)"
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
        }
    }
}
