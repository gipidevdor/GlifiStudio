// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit

nonisolated enum StudioCoreMethodFamily: String, CaseIterable, Identifiable, Sendable {
    case corpus, statistics, evaluation, operators
    var id: Self { self }
    var titleKey: String { "core-features.\(rawValue)" }
    var systemImage: String {
        switch self {
        case .corpus: "chart.bar.doc.horizontal"
        case .statistics: "function"
        case .evaluation: "checkmark.seal"
        case .operators: "square.grid.3x3"
        }
    }
}

/// Concrete, searchable entry points into the existing workbench selections.
nonisolated enum StudioCoreMethodRoute: Hashable, Identifiable, Sendable {
    case corpus(StudioCorpusMethod)
    case statistics(GlifiStudioStatisticsOperation)
    case evaluation(StudioEvaluationTool)
    case operators(GlifiStudioCoreOperator)

    var id: String { "\(family.rawValue).\(rawName)" }
    static var allCases: [Self] {
        StudioCorpusMethod.allCases.map(Self.corpus)
            + GlifiStudioStatisticsOperation.allCases.map(Self.statistics)
            + StudioEvaluationTool.allCases.map(Self.evaluation)
            + GlifiStudioCoreOperator.allCases.map(Self.operators)
    }

    var family: StudioCoreMethodFamily {
        switch self {
        case .corpus: .corpus
        case .statistics: .statistics
        case .evaluation: .evaluation
        case .operators: .operators
        }
    }

    var rawName: String {
        switch self {
        case let .corpus(method): method.rawValue
        case let .statistics(method): method.rawValue
        case let .evaluation(method): method.rawValue
        case let .operators(method): method.rawValue
        }
    }

    var titleKey: String {
        switch self {
        case let .corpus(method): method.titleKey
        case let .statistics(method): "statistics.operation.\(method.rawValue)"
        case let .evaluation(method): method.titleKey
        case let .operators(method): "operators.method.\(method.rawValue)"
        }
    }

    func matches(_ query: String, locale: Locale) -> Bool {
        let label = String(localized: String.LocalizationValue(titleKey), locale: locale)
        let text = "\(label) \(rawName)"
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
        }
    }
}
