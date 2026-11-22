// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioAdvancedTool: String, CaseIterable, Identifiable, Sendable {
    case mds, som, clara, topics, classification, classifierValidation
    case coding, codeCrosstab, distances, correspondence, hierarchical, network

    var id: Self { self }
    var titleKey: String { "advanced.tool.\(rawValue).title" }
    var descriptionKey: String { "advanced.tool.\(rawValue).description" }
    var caveatKey: String { "advanced.tool.\(rawValue).caveat" }
    var needsLabels: Bool {
        self == .classification || self == .classifierValidation || self == .codeCrosstab
    }
    var needsRules: Bool { self == .coding || self == .codeCrosstab }
    var usesDenseMatrix: Bool {
        switch self {
        case .mds, .som, .clara, .distances, .correspondence, .hierarchical, .network: true
        case .topics, .classification, .classifierValidation, .coding, .codeCrosstab: false
        }
    }
}

nonisolated struct StudioAdvancedRow: Identifiable, Sendable {
    let id: Int
    let values: [String]
    let sourceRevisionID: String?
    var searchText: String { values.joined(separator: " ") }
}

nonisolated struct StudioAdvancedPoint: Identifiable, Sendable {
    let id: Int
    let x: Double
    let y: Double
    let sourceRevisionID: String
    let sourceNumber: Int
}

nonisolated struct StudioAdvancedOutput: Sendable {
    let tool: StudioAdvancedTool
    let input: GlifiStudioProjectTextAnalysisInput
    let methodIdentifier: String
    let validationStatus: String
    let requestDigest: String
    let request: GlifiStudioTextAnalysisRequest
    let canonicalRequest: Data
    let encodedResult: Data
    let parameters: [(key: String, value: String)]
    let columns: [String]
    let rows: [StudioAdvancedRow]
    let points: [StudioAdvancedPoint]
    let diagnostics: [(key: String, value: String)]
    let completedAt: Date
    let sourceLabels: [String]
    let sourceNumbers: [Int]

    var isOneDimensional: Bool {
        if case let .mds(_, dimensions, _, _, _) = request { return dimensions == 1 }
        return false
    }

    var codingRules: String? {
        if case let .coding(_, rules) = request { return rules }
        if case let .codeCrosstab(_, rules, _) = request { return rules }
        return nil
    }
}

/// Owns session-only exploratory results independently of navigation and parameter drafts.
@MainActor @Observable final class StudioAdvancedAnalysisModel {
    var tool: StudioAdvancedTool = .mds
    var maximumTerms = 200
    var seed: UInt64 = 0
    var distance: GlifiStudioTextDistance = .cosine
    var mdsMethod: GlifiStudioMDSMethod = .classical
    var dimensions = 2
    var maximumIterations = 300
    var gridWidth = 3
    var gridHeight = 3
    var epochs = 100
    var clusterCount = 2
    var sampleSize = 100
    var topicCount = 2
    var alpha = 0.1
    var beta = 0.01
    var burnIn = 100
    var posteriorSamples = 20
    var thinning = 5
    var topicTermsShown = 20
    var smoothing = 1.0
    var folds = 2
    var rules = ""
    var labels: [String: String] = [:]
    var linkage = "average"
    var minimumJaccard = 0.1
    var maximumEdges = 10_000
    var search = "" {
        didSet {
            if !isReplacingOutput, search != oldValue { scheduleFilter() }
        }
    }
    private(set) var output: StudioAdvancedOutput?
    private(set) var page = 0
    private(set) var matchingRowCount = 0
    private(set) var visibleRows: [StudioAdvancedRow] = []
    private var filteredIndices: [Int] = []
    private var filterTask: Task<Void, Never>?
    private var filterRevision = UUID()
    private var lifecycleID = UUID()
    private var isReplacingOutput = false
    static let pageSize = 50

    var pageCount: Int { max(1, (matchingRowCount + Self.pageSize - 1) / Self.pageSize) }

    func reset() {
        lifecycleID = UUID()
        filterTask?.cancel()
        filterRevision = UUID()
        output = nil
        labels = [:]
        rules = ""
        search = ""
        page = 0
        matchingRowCount = 0
        filteredIndices = []
        visibleRows = []
    }

    func showPage(_ requested: Int) {
        guard requested >= 0, requested < pageCount else { return }
        page = requested
        refreshVisibleRows()
    }

    func execute(
        session: GlifiStudioProjectSession,
        sourceRevisionIDs: [String],
        sourceNumbers: [String: Int],
        locale: Locale
    ) async throws {
        let lifecycle = lifecycleID
        let specification = Specification(model: self)
        let next = try await Self.calculate(
            specification, session: session, ids: sourceRevisionIDs,
            sourceNumbers: sourceNumbers, locale: locale)
        guard !Task.isCancelled, lifecycleID == lifecycle else {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        }
        filterTask?.cancel()
        filterRevision = UUID()
        isReplacingOutput = true
        search = ""
        isReplacingOutput = false
        output = next
        filteredIndices = Array(next.rows.indices)
        matchingRowCount = next.rows.count
        page = 0
        refreshVisibleRows()
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        let revision = UUID()
        filterRevision = revision
        guard let output else { return }
        let query = search
        filterTask = Task {
            guard !Task.isCancelled else { return }
            let indices = await Self.matchingIndices(output.rows, query: query)
            guard !Task.isCancelled, filterRevision == revision else { return }
            filteredIndices = indices
            matchingRowCount = indices.count
            page = 0
            refreshVisibleRows()
        }
    }

    @concurrent private static func matchingIndices(
        _ rows: [StudioAdvancedRow], query: String
    ) async -> [Int] {
        guard !query.isEmpty else { return Array(rows.indices) }
        var indices: [Int] = []
        for index in rows.indices {
            if Task.isCancelled { return [] }
            if rows[index].searchText.localizedStandardContains(query) { indices.append(index) }
        }
        return indices
    }

    private func refreshVisibleRows() {
        guard let output else {
            visibleRows = []
            return
        }
        let start = page * Self.pageSize
        visibleRows = filteredIndices.dropFirst(start).prefix(Self.pageSize).map { output.rows[$0] }
    }

    private struct Specification: Sendable {
        let tool: StudioAdvancedTool
        let maximumTerms: Int
        let seed: UInt64
        let distance: GlifiStudioTextDistance
        let mdsMethod: GlifiStudioMDSMethod
        let dimensions: Int
        let maximumIterations: Int
        let gridWidth: Int
        let gridHeight: Int
        let epochs: Int
        let clusterCount: Int
        let sampleSize: Int
        let topicCount: Int
        let alpha: Double
        let beta: Double
        let burnIn: Int
        let posteriorSamples: Int
        let thinning: Int
        let topicTermsShown: Int
        let smoothing: Double
        let folds: Int
        let rules: String
        let labels: [String: String]
        let linkage: String
        let minimumJaccard: Double
        let maximumEdges: Int

        @MainActor init(model: StudioAdvancedAnalysisModel) {
            tool = model.tool
            maximumTerms = model.maximumTerms
            seed = model.seed
            distance = model.distance
            mdsMethod = model.mdsMethod
            dimensions = model.dimensions
            maximumIterations = model.maximumIterations
            gridWidth = model.gridWidth
            gridHeight = model.gridHeight
            epochs = model.epochs
            clusterCount = model.clusterCount
            sampleSize = model.sampleSize
            topicCount = model.topicCount
            alpha = model.alpha
            beta = model.beta
            burnIn = model.burnIn
            posteriorSamples = model.posteriorSamples
            thinning = model.thinning
            topicTermsShown = model.topicTermsShown
            smoothing = model.smoothing
            folds = model.folds
            rules = model.rules
            labels = model.labels
            linkage = model.linkage
            minimumJaccard = model.minimumJaccard
            maximumEdges = model.maximumEdges
        }
    }

    @concurrent private static func calculate(
        _ spec: Specification, session: GlifiStudioProjectSession, ids: [String],
        sourceNumbers: [String: Int], locale: Locale
    ) async throws -> StudioAdvancedOutput {
        let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: ids,
            maximumTermCount: spec.tool.usesDenseMatrix ? spec.maximumTerms : 200)
        let sourceLabels = input.sourceRevisionIDs.map {
            spec.labels[$0, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let request: GlifiStudioTextAnalysisRequest
        var parameters: [(key: String, value: String)] = []
        if spec.tool.usesDenseMatrix {
            parameters.append(("advanced.maximum-terms", String(spec.maximumTerms)))
        }
        if [.mds, .som, .clara, .topics, .classifierValidation].contains(spec.tool) {
            parameters.append(("advanced.seed", String(spec.seed)))
        }
        switch spec.tool {
        case .mds:
            let distances = try await GlifiStudioTextAnalytics.dissimilarities(
                input.matrix, metric: spec.distance)
            request = .mds(
                matrix: distances, dimensions: spec.dimensions, method: spec.mdsMethod,
                seed: spec.seed, maximumIterations: spec.maximumIterations)
            parameters += [
                ("advanced.distance", spec.distance.rawValue),
                ("advanced.mds-method", spec.mdsMethod.rawValue),
                ("advanced.dimensions", String(spec.dimensions)),
                ("advanced.iterations", String(spec.maximumIterations)),
            ]
        case .som:
            request = .som(
                matrix: input.matrix, width: spec.gridWidth, height: spec.gridHeight,
                seed: spec.seed, epochs: spec.epochs)
            parameters += [
                ("advanced.width", String(spec.gridWidth)),
                ("advanced.height", String(spec.gridHeight)),
                ("advanced.epochs", String(spec.epochs)),
            ]
        case .clara:
            request = .clara(
                matrix: input.matrix, clusterCount: spec.clusterCount, seed: spec.seed,
                sampleSize: spec.sampleSize)
            parameters += [
                ("advanced.clusters", String(spec.clusterCount)),
                ("advanced.sample-size", String(spec.sampleSize)),
            ]
        case .topics:
            guard (1...1_000).contains(spec.topicTermsShown) else { throw invalidInput() }
            request = .lda(
                documents: input.documents, topicCount: spec.topicCount, seed: spec.seed,
                alpha: spec.alpha, beta: spec.beta, burnIn: spec.burnIn,
                sampleCount: spec.posteriorSamples, thinning: spec.thinning)
            parameters += [
                ("advanced.topics", String(spec.topicCount)),
                ("advanced.alpha", String(spec.alpha)), ("advanced.beta", String(spec.beta)),
                ("advanced.burn-in", String(spec.burnIn)),
                ("advanced.posterior-samples", String(spec.posteriorSamples)),
                ("advanced.thinning", String(spec.thinning)),
                ("advanced.topic-terms", String(spec.topicTermsShown)),
            ]
        case .classification:
            let training = sourceLabels.indices.filter { !sourceLabels[$0].isEmpty }
            let prediction = sourceLabels.indices.filter { sourceLabels[$0].isEmpty }
            guard !training.isEmpty, !prediction.isEmpty else { throw invalidInput() }
            request = .classify(
                documents: training.map { input.documents[$0] },
                labels: training.map { sourceLabels[$0] },
                predictionDocuments: prediction.map { input.documents[$0] },
                smoothing: spec.smoothing)
            parameters += [("advanced.smoothing", String(spec.smoothing))]
        case .classifierValidation:
            guard !sourceLabels.contains(where: \.isEmpty) else { throw invalidInput() }
            request = .validateClassifier(
                documents: input.documents, labels: sourceLabels, folds: spec.folds, seed: spec.seed
            )
            parameters += [("advanced.folds", String(spec.folds))]
        case .coding:
            request = .coding(units: input.codingUnits, rules: spec.rules)
        case .codeCrosstab:
            request = .codeCrosstab(
                units: input.codingUnits, rules: spec.rules,
                groups: sourceLabels.map { $0.isEmpty ? nil : $0 })
        case .distances:
            request = .dissimilarities(matrix: input.matrix, metric: spec.distance)
            parameters += [("advanced.distance", spec.distance.rawValue)]
        case .correspondence:
            request = .correspondence(matrix: input.matrix)
        case .hierarchical:
            let distances = try await GlifiStudioTextAnalytics.dissimilarities(
                input.matrix, metric: spec.distance)
            request = .hierarchical(matrix: distances, linkage: spec.linkage)
            parameters += [
                ("advanced.distance", spec.distance.rawValue), ("advanced.linkage", spec.linkage),
            ]
        case .network:
            request = .network(
                matrix: input.matrix, labels: input.terms, minimumJaccard: spec.minimumJaccard,
                maximumEdges: spec.maximumEdges)
            parameters += [
                ("advanced.minimum-jaccard", String(spec.minimumJaccard)),
                ("advanced.maximum-edges", String(spec.maximumEdges)),
            ]
        }
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        var rows: [StudioAdvancedRow] = []
        var columns: [String] = []
        var points: [StudioAdvancedPoint] = []
        var diagnostics: [(key: String, value: String)] = []
        func number(_ value: Double) -> String {
            value.formatted(.number.locale(locale).precision(.significantDigits(1...8)))
        }
        func sourceNumber(_ index: Int) -> String {
            guard input.sourceRevisionIDs.indices.contains(index) else { return "—" }
            return String(sourceNumbers[input.sourceRevisionIDs[index]] ?? index + 1)
        }
        func add(_ values: [String], source index: Int? = nil) {
            let revision = index.flatMap {
                input.sourceRevisionIDs.indices.contains($0) ? input.sourceRevisionIDs[$0] : nil
            }
            rows.append(
                StudioAdvancedRow(id: rows.count, values: values, sourceRevisionID: revision))
        }
        switch result.payload {
        case .advanced:
            // This workbench builds only the explicit standard requests above.
            throw GlifiStudioFailure(
                code: "ui.advanced.unexpected-payload", category: "corruption",
                operation: "analyze",
                retryDisposition: "never", retainedState: "unchanged",
                messageKey: "failure.category.corruption")
        case let .mds(value):
            columns = ["summary.source.label", "advanced.axis-one", "advanced.axis-two"]
            for (index, coordinates) in value.coordinates.enumerated() {
                let x = coordinates.first ?? 0
                let y = coordinates.count > 1 ? coordinates[1] : 0
                add(
                    [sourceNumber(index), number(x), spec.dimensions > 1 ? number(y) : "—"],
                    source: index)
                if input.sourceRevisionIDs.indices.contains(index) {
                    points.append(
                        StudioAdvancedPoint(
                            id: index, x: x, y: y, sourceRevisionID: input.sourceRevisionIDs[index],
                            sourceNumber: sourceNumbers[input.sourceRevisionIDs[index]] ?? index + 1
                        ))
                }
            }
            diagnostics = [
                ("advanced.stress", number(value.stress)),
                ("advanced.completed-iterations", String(value.iterations)),
                (
                    "advanced.convergence",
                    value.converged ? "advanced.converged" : "advanced.limit-reached"
                ),
            ]
        case let .som(value):
            columns = ["summary.source.label", "advanced.grid-column", "advanced.grid-row"]
            for (index, unit) in value.assignments.enumerated() {
                add(
                    [
                        sourceNumber(index), String(unit % value.width + 1),
                        String(unit / value.width + 1),
                    ], source: index)
            }
            diagnostics = [
                ("advanced.quantization-error", number(value.quantizationError)),
                ("advanced.topographic-error", number(value.topographicError)),
                ("advanced.epochs", String(value.epochs)),
                (
                    "advanced.convergence",
                    value.converged ? "advanced.converged" : "advanced.limit-reached"
                ),
            ]
        case let .clara(value):
            columns = ["summary.source.label", "advanced.cluster", "advanced.medoid-source"]
            for (index, cluster) in value.assignments.enumerated() {
                let medoid =
                    value.medoids.indices.contains(cluster)
                    ? sourceNumber(value.medoids[cluster]) : "—"
                add([sourceNumber(index), String(cluster + 1), medoid], source: index)
            }
            diagnostics = [("advanced.objective", number(value.objective))]
        case let .lda(value):
            columns = [
                "advanced.topic", "advanced.term", "summary.source.label", "advanced.probability",
            ]
            for (topic, probabilities) in value.topicTerms.enumerated() {
                let indices = probabilities.indices.sorted {
                    probabilities[$0] == probabilities[$1]
                        ? $0 < $1 : probabilities[$0] > probabilities[$1]
                }.prefix(spec.topicTermsShown)
                for index in indices where value.vocabulary.indices.contains(index) {
                    add([
                        String(topic + 1), value.vocabulary[index], "—",
                        number(probabilities[index]),
                    ])
                }
            }
            for (index, topics) in value.documentTopics.enumerated() {
                for (topic, probability) in topics.enumerated() {
                    add(
                        [String(topic + 1), "—", sourceNumber(index), number(probability)],
                        source: index)
                }
            }
            diagnostics = [
                ("advanced.training-perplexity", number(value.trainingPerplexity)),
                ("advanced.topic-terms", String(spec.topicTermsShown)),
            ]
        case let .classify(value):
            columns = [
                "summary.source.label", "advanced.predicted-class", "advanced.class",
                "advanced.probability", "advanced.ignored-tokens",
            ]
            let prediction = sourceLabels.indices.filter { sourceLabels[$0].isEmpty }
            for (row, probabilities) in value.probabilities.enumerated()
            where prediction.indices.contains(row) && value.labels.indices.contains(row) {
                for (column, probability) in probabilities.enumerated()
                where value.classes.indices.contains(column) {
                    add(
                        [
                            sourceNumber(prediction[row]), value.labels[row], value.classes[column],
                            number(probability), String(value.ignoredTokenCounts[row]),
                        ], source: prediction[row])
                }
            }
        case let .validateClassifier(value):
            columns = ["advanced.actual-class", "advanced.predicted-class", "advanced.count"]
            for (actual, counts) in value.confusion.enumerated()
            where value.classes.indices.contains(actual) {
                for (predicted, count) in counts.enumerated()
                where value.classes.indices.contains(predicted) {
                    add([value.classes[actual], value.classes[predicted], String(count)])
                }
            }
            diagnostics = [("advanced.accuracy", number(value.accuracy))]
        case let .coding(value):
            columns = [
                "summary.source.label", "advanced.code", "advanced.applied",
                "advanced.positive-spans",
            ]
            for (row, values) in value.values.enumerated() {
                for (column, count) in values.enumerated()
                where value.codes.indices.contains(column) {
                    add(
                        [
                            sourceNumber(row), value.codes[column], String(count),
                            String(value.evidence[row][column].count),
                        ], source: row)
                }
            }
        case let .codeCrosstab(value):
            columns = ["advanced.group", "advanced.code", "advanced.count", "advanced.denominator"]
            for (row, counts) in value.counts.enumerated()
            where value.groups.indices.contains(row) && value.sizes.indices.contains(row) {
                for (column, count) in counts.enumerated()
                where value.codes.indices.contains(column) {
                    add([
                        value.groups[row], value.codes[column], String(count),
                        String(value.sizes[row]),
                    ])
                }
            }
            diagnostics = [("advanced.missing-groups", String(value.missingCount))]
        case let .dissimilarities(value):
            columns = ["advanced.first-source", "advanced.second-source", "advanced.distance"]
            for row in value.indices {
                for column in value[row].indices where column > row {
                    add(
                        [sourceNumber(row), sourceNumber(column), number(value[row][column])],
                        source: row)
                }
            }
        case let .correspondence(value):
            columns = [
                "summary.source.label", "advanced.term", "advanced.axis-one", "advanced.axis-two",
            ]
            for (row, coordinates) in value.rowCoordinates.enumerated()
            where value.includedRows.indices.contains(row) {
                let source = value.includedRows[row]
                add(
                    [
                        sourceNumber(source), "—", coordinates.first.map(number) ?? "—",
                        coordinates.count > 1 ? number(coordinates[1]) : "—",
                    ], source: source)
            }
            for (row, coordinates) in value.columnCoordinates.enumerated()
            where value.includedColumns.indices.contains(row) {
                let column = value.includedColumns[row]
                guard input.terms.indices.contains(column) else { continue }
                add([
                    "—", input.terms[column], coordinates.first.map(number) ?? "—",
                    coordinates.count > 1 ? number(coordinates[1]) : "—",
                ])
            }
            diagnostics = [("advanced.total-inertia", number(value.totalInertia))]
            diagnostics += [
                ("advanced.included-sources", String(value.includedRows.count)),
                (
                    "advanced.excluded-sources",
                    String(input.sourceRevisionIDs.count - value.includedRows.count)
                ),
            ]
        case let .hierarchical(value):
            columns = [
                "advanced.merge", "advanced.first-node", "advanced.second-node", "advanced.height",
                "advanced.cluster-size",
            ]
            for (index, children) in value.children.enumerated()
            where children.count == 2 && value.heights.indices.contains(index)
                && value.sizes.indices.contains(index)
            {
                func nodeName(_ node: Int) -> String {
                    let key =
                        node < input.sourceRevisionIDs.count
                        ? "advanced.node.source" : "advanced.node.cluster"
                    let number =
                        node < input.sourceRevisionIDs.count
                        ? sourceNumber(node) : String(node - input.sourceRevisionIDs.count + 1)
                    return String(
                        localized: String.LocalizationValue(key), bundle: .main, locale: locale
                    ).replacingOccurrences(of: "{number}", with: number)
                }
                add([
                    String(index + 1), nodeName(children[0]), nodeName(children[1]),
                    number(value.heights[index]), String(value.sizes[index]),
                ])
            }
        case let .network(value):
            columns = ["advanced.first-term", "advanced.second-term", "advanced.jaccard"]
            for (index, endpoints) in value.endpoints.enumerated()
            where endpoints.count == 2 && value.weights.indices.contains(index)
                && value.nodes.indices.contains(endpoints[0])
                && value.nodes.indices.contains(endpoints[1])
            {
                add([
                    value.nodes[endpoints[0]], value.nodes[endpoints[1]],
                    number(value.weights[index]),
                ])
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return StudioAdvancedOutput(
            tool: spec.tool, input: input, methodIdentifier: result.methodIdentifier,
            validationStatus: result.validationStatus, requestDigest: result.requestDigest,
            request: request, canonicalRequest: try request.canonicalData(),
            encodedResult: try encoder.encode(result),
            parameters: parameters, columns: columns, rows: rows, points: points,
            diagnostics: diagnostics, completedAt: Date(), sourceLabels: sourceLabels,
            sourceNumbers: input.sourceRevisionIDs.enumerated().map {
                sourceNumbers[$0.element] ?? $0.offset + 1
            })
    }

    nonisolated private static func invalidInput() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "text-analysis.invalid-request", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }
}
