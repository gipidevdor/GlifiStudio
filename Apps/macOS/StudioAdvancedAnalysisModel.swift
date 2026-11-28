// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioAdvancedTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case mds, som, clara, topics, classification, classifierValidation
    case coding, codeCrosstab, distances, correspondence, hierarchical, network
    case mdsSearch, somAdvanced, topicSelection
    case mdsOrdinal, mdsOrdinalSearch, somPCAInitialization, somKH

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
        case .mds, .mdsSearch, .mdsOrdinal, .mdsOrdinalSearch, .som, .somAdvanced,
            .somPCAInitialization, .somKH, .clara, .distances, .correspondence,
            .hierarchical, .network:
            true
        case .topics, .topicSelection, .classification, .classifierValidation, .coding,
            .codeCrosstab:
            false
        }
    }
}

nonisolated struct StudioAdvancedRow: Codable, Identifiable, Sendable {
    let id: Int
    let values: [String]
    let sourceRevisionID: String?
    var searchText: String { values.joined(separator: " ") }
}

nonisolated struct StudioAdvancedPoint: Codable, Identifiable, Sendable {
    let id: Int
    let x: Double
    let y: Double
    let sourceRevisionID: String
    let sourceNumber: Int
}

nonisolated struct StudioAdvancedFactorPoint: Codable, Identifiable, Sendable {
    let id: String
    let label: String
    let seriesKey: String
    let x: Double
    let y: Double
}

nonisolated struct StudioAdvancedTreeVertex: Codable, Identifiable, Sendable {
    let id: String
    let segment: String
    let x: Double
    let y: Double
}

nonisolated struct StudioAdvancedTable: Codable, Identifiable, Sendable {
    let id: String
    let titleKey: String
    let columns: [String]
    let rows: [StudioAdvancedRow]
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
    let typedResult: GlifiStudioTextAnalysisResult?
    let parameters: [(key: String, value: String)]
    let columns: [String]
    let rows: [StudioAdvancedRow]
    let points: [StudioAdvancedPoint]
    let factorPoints: [StudioAdvancedFactorPoint]
    let treeVertices: [StudioAdvancedTreeVertex]
    let treeLeafLabels: [String]
    let diagnostics: [(key: String, value: String)]
    let tables: [StudioAdvancedTable]
    let completedAt: Date
    let sourceLabels: [String]
    let sourceNumbers: [Int]

    var factorDomain: ClosedRange<Double> {
        let radius = max(1e-12, factorPoints.reduce(0) { max($0, max(abs($1.x), abs($1.y))) })
        return -radius...radius
    }

    var isOneDimensional: Bool {
        if case let .mds(_, dimensions, _, _, _) = request { return dimensions == 1 }
        if case let .advanced(.mdsSearch(_, dimensions, _, _, _, _, _)) = request {
            return dimensions == 1
        }
        if case let .advanced(.kh(.ordinalMDS(_, dimensions, _, _, _, _))) = request {
            return dimensions == 1
        }
        if case let .advanced(.kh(.ordinalMDSSearch(_, dimensions, _, _, _, _, _))) = request {
            return dimensions == 1
        }
        return false
    }

    var isOrdinalMDS: Bool {
        if tool == .mdsOrdinal || tool == .mdsOrdinalSearch { return true }
        if case let .mds(_, _, method, _, _) = request { return method == .ordinal }
        if case let .advanced(.mdsSearch(_, _, method, _, _, _, _)) = request {
            return method == .ordinal
        }
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
    var mdsSearchMethod: GlifiStudioMDSMethod = .ordinal
    var mdsStarts = 10
    var mdsTolerance = 1e-8
    var ordinalTies: GlifiStudioMDSOrdinalTies = .primary
    var dimensions = 2
    var maximumIterations = 300
    var gridWidth = 3
    var gridHeight = 3
    var epochs = 100
    var somTopology: GlifiStudioSOMTopology = .rectangular
    var somInitialRadius = 2.0
    var somFinalRadius = 0.5
    var somTolerance = 1e-8
    var clustersSOMCodebooks = false
    var somCodebookClusterCount = 2
    var somKHUsesCustomPhases = false
    var somKHFirstSteps = 1_000
    var somKHSecondSteps = 4_500
    var somKHFirstLearningRate = 0.05
    var somKHSecondLearningRate = 0.02
    var somKHFirstRadius = 3.0
    var somKHSecondRadius = 1.0
    var somKHUsesExplicitCodebooks = false
    var somKHInitialCodebooks = ""

    var clusterCount = 2
    var sampleSize = 100
    var topicCount = 2
    var topicCandidatesDraft = "2 3 4"
    var topicCriterion: GlifiStudioTopicSelectionCriterion = .heldOutPerplexity
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
    private(set) var isFiltering = false
    private var filteredIndices: [Int] = []
    private var filterTask: Task<Void, Never>?
    private var filterRevision = UUID()
    private var isReplacingOutput = false
    private var executionRevision = UUID()
    private var capturedSpecification: Specification?
    var tableIndex = 0 {
        didSet { if !isReplacingOutput, tableIndex != oldValue { scheduleFilter() } }
    }
    static let pageSize = 50

    var selectedTable: StudioAdvancedTable? {
        guard let output, output.tables.indices.contains(tableIndex) else { return nil }
        return output.tables[tableIndex]
    }

    var isDraftChanged: Bool {
        guard output != nil, let capturedSpecification else { return false }
        return Specification(model: self) != capturedSpecification
    }

    var pageCount: Int { max(1, (matchingRowCount + Self.pageSize - 1) / Self.pageSize) }

    func reset() {
        executionRevision = UUID()
        filterTask?.cancel()
        filterRevision = UUID()
        output = nil
        capturedSpecification = nil
        tableIndex = 0
        labels = [:]
        rules = ""
        somKHInitialCodebooks = ""
        search = ""
        page = 0
        matchingRowCount = 0
        filteredIndices = []
        visibleRows = []
        isFiltering = false
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
        let execution = UUID()
        executionRevision = execution
        let specification = Specification(model: self)
        let next = try await Self.calculate(
            specification, session: session, ids: sourceRevisionIDs,
            sourceNumbers: sourceNumbers, locale: locale)
        guard !Task.isCancelled, executionRevision == execution else {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        }
        filterTask?.cancel()
        filterRevision = UUID()
        isReplacingOutput = true
        search = ""
        tableIndex = 0
        output = next
        capturedSpecification = specification
        isFiltering = false
        isReplacingOutput = false
        filteredIndices = Array(next.rows.indices)
        matchingRowCount = next.rows.count
        page = 0
        refreshVisibleRows()
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        let revision = UUID()
        filterRevision = revision
        guard let table = selectedTable else {
            filteredIndices = []
            matchingRowCount = 0
            visibleRows = []
            isFiltering = false
            return
        }
        let query = search
        if query.isEmpty {
            isFiltering = false
            filteredIndices = Array(table.rows.indices)
            matchingRowCount = table.rows.count
            page = 0
            refreshVisibleRows()
            return
        }
        isFiltering = true
        page = 0
        filteredIndices = []
        matchingRowCount = 0
        visibleRows = []
        filterTask = Task {
            guard !Task.isCancelled else { return }
            let indices = await Self.matchingIndices(table.rows, query: query)
            guard !Task.isCancelled, filterRevision == revision else { return }
            isFiltering = false
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
        guard let table = selectedTable else {
            visibleRows = []
            return
        }
        let start = page * Self.pageSize
        visibleRows = filteredIndices.dropFirst(start).prefix(Self.pageSize).compactMap {
            table.rows.indices.contains($0) ? table.rows[$0] : nil
        }
    }

    nonisolated private struct Specification: Codable, Equatable, Sendable {
        let tool: StudioAdvancedTool
        let maximumTerms: Int
        let seed: UInt64
        let distance: GlifiStudioTextDistance
        let mdsMethod: GlifiStudioMDSMethod
        let mdsSearchMethod: GlifiStudioMDSMethod
        let mdsStarts: Int
        let mdsTolerance: Double
        let ordinalTies: GlifiStudioMDSOrdinalTies
        let dimensions: Int
        let maximumIterations: Int
        let gridWidth: Int
        let gridHeight: Int
        let epochs: Int
        let somTopology: GlifiStudioSOMTopology
        let somInitialRadius: Double
        let somFinalRadius: Double
        let somTolerance: Double
        let clustersSOMCodebooks: Bool
        let somCodebookClusterCount: Int
        let somKHUsesCustomPhases: Bool
        let somKHFirstSteps: Int
        let somKHSecondSteps: Int
        let somKHFirstLearningRate: Double
        let somKHSecondLearningRate: Double
        let somKHFirstRadius: Double
        let somKHSecondRadius: Double
        let somKHUsesExplicitCodebooks: Bool
        let somKHInitialCodebooks: String
        let clusterCount: Int
        let sampleSize: Int
        let topicCount: Int
        let topicCandidatesDraft: String
        let topicCriterion: GlifiStudioTopicSelectionCriterion
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
            mdsSearchMethod = model.mdsSearchMethod
            mdsStarts = model.mdsStarts
            mdsTolerance = model.mdsTolerance
            ordinalTies = model.ordinalTies
            dimensions = model.dimensions
            maximumIterations = model.maximumIterations
            gridWidth = model.gridWidth
            gridHeight = model.gridHeight
            epochs = model.epochs
            somTopology = model.somTopology
            somInitialRadius = model.somInitialRadius
            somFinalRadius = model.somFinalRadius
            somTolerance = model.somTolerance
            clustersSOMCodebooks = model.clustersSOMCodebooks
            somCodebookClusterCount = model.somCodebookClusterCount
            somKHUsesCustomPhases = model.somKHUsesCustomPhases
            somKHFirstSteps = model.somKHFirstSteps
            somKHSecondSteps = model.somKHSecondSteps
            somKHFirstLearningRate = model.somKHFirstLearningRate
            somKHSecondLearningRate = model.somKHSecondLearningRate
            somKHFirstRadius = model.somKHFirstRadius
            somKHSecondRadius = model.somKHSecondRadius
            somKHUsesExplicitCodebooks = model.somKHUsesExplicitCodebooks
            somKHInitialCodebooks = model.somKHInitialCodebooks
            clusterCount = model.clusterCount
            sampleSize = model.sampleSize
            topicCount = model.topicCount
            topicCandidatesDraft = model.topicCandidatesDraft
            topicCriterion = model.topicCriterion
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

    nonisolated private struct ArchivePair: Codable, Sendable {
        let key: String
        let value: String
    }
    nonisolated private struct Archive: Codable, Sendable {
        let client: String
        let version: Int
        let specification: Specification
        let parameters: [ArchivePair]
        let diagnostics: [ArchivePair]
        let tool: StudioAdvancedTool
        let input: GlifiStudioProjectTextAnalysisInput
        let methodIdentifier: String
        let validationStatus: String
        let requestDigest: String
        let canonicalRequest: Data
        let encodedResult: Data
        let columns: [String]
        let rows: [StudioAdvancedRow]
        let points: [StudioAdvancedPoint]
        let factorPoints: [StudioAdvancedFactorPoint]
        let treeVertices: [StudioAdvancedTreeVertex]
        let treeLeafLabels: [String]
        let tables: [StudioAdvancedTable]
        let completedAt: Date
        let sourceLabels: [String]
        let sourceNumbers: [Int]
    }

    /// Captures native presentation and draft settings without recomputing statistics.
    func archiveData() async throws -> Data {
        let expected = executionRevision
        guard let output, let specification = capturedSpecification else {
            throw Self.invalidInput()
        }
        let archive = Archive(
            client: "advanced", version: 1, specification: specification,
            parameters: output.parameters.map { ArchivePair(key: $0.key, value: $0.value) },
            diagnostics: output.diagnostics.map { ArchivePair(key: $0.key, value: $0.value) },
            tool: output.tool,
            input: output.input,
            methodIdentifier: output.methodIdentifier,
            validationStatus: output.validationStatus,
            requestDigest: output.requestDigest,
            canonicalRequest: output.canonicalRequest,
            encodedResult: output.encodedResult,
            columns: output.columns,
            rows: output.rows,
            points: output.points,
            factorPoints: output.factorPoints,
            treeVertices: output.treeVertices,
            treeLeafLabels: output.treeLeafLabels,
            tables: output.tables,
            completedAt: output.completedAt,
            sourceLabels: output.sourceLabels,
            sourceNumbers: output.sourceNumbers)

        let bytes = try await Self.encodeArchive(archive)
        try Task.checkCancellation()
        guard executionRevision == expected else { throw CancellationError() }
        return bytes
    }

    @concurrent private static func encodeArchive(_ archive: Archive) async throws -> Data {
        try Task.checkCancellation()
        let bytes = try JSONEncoder().encode(archive)
        guard bytes.count <= 8 * 1_048_576 else { throw Self.resourceLimit() }
        try Task.checkCancellation()
        return bytes
    }

    /// Restores the captured view and its settings.
    ///
    /// The scientific dispatcher is never invoked.
    @concurrent private static func decodeArchive(
        _ data: Data, saved: GlifiStudioSavedAnalysis
    ) async throws -> (archive: Archive, request: GlifiStudioTextAnalysisRequest) {
        try Task.checkCancellation()
        guard data.count <= 8 * 1_048_576 else { throw Self.resourceLimit() }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.client == "advanced", archive.version == 1,
            archive.canonicalRequest == saved.requestJSON,
            archive.input.sourceRevisionIDs == saved.sourceRevisionIDs,
            archive.input.preparationDigest == saved.preparationDigest,
            archive.rows.count <= 100_000,
            archive.tables.reduce(0, { $0 + $1.rows.count }) <= 100_000,
            archive.sourceNumbers.count == archive.input.sourceRevisionIDs.count,
            archive.input.matrix.count == archive.input.documents.count,
            archive.input.matrix.allSatisfy({ $0.count == archive.input.terms.count })
        else { throw Self.invalidInput() }
        let storedJSON =
            try JSONSerialization.jsonObject(with: archive.encodedResult) as? NSDictionary
        let scientificJSON =
            try JSONSerialization.jsonObject(with: saved.resultJSON) as? NSDictionary
        guard storedJSON == scientificJSON else { throw Self.invalidInput() }
        let request = try GlifiStudioTextAnalysisRequest.decode(archive.canonicalRequest)
        try Task.checkCancellation()
        return (archive, request)
    }

    func restoreArchive(_ data: Data, saved: GlifiStudioSavedAnalysis) async throws {
        let expected = UUID()
        executionRevision = expected
        let decoded = try await Self.decodeArchive(data, saved: saved)
        let archive = decoded.archive
        try Task.checkCancellation()
        guard executionRevision == expected else { throw CancellationError() }
        reset()
        let spec = archive.specification
        tool = spec.tool
        maximumTerms = spec.maximumTerms
        seed = spec.seed
        distance = spec.distance
        mdsMethod = spec.mdsMethod
        mdsSearchMethod = spec.mdsSearchMethod
        mdsStarts = spec.mdsStarts
        mdsTolerance = spec.mdsTolerance
        ordinalTies = spec.ordinalTies
        dimensions = spec.dimensions
        maximumIterations = spec.maximumIterations
        gridWidth = spec.gridWidth
        gridHeight = spec.gridHeight
        epochs = spec.epochs
        somTopology = spec.somTopology
        somInitialRadius = spec.somInitialRadius
        somFinalRadius = spec.somFinalRadius
        somTolerance = spec.somTolerance
        clustersSOMCodebooks = spec.clustersSOMCodebooks
        somCodebookClusterCount = spec.somCodebookClusterCount
        somKHUsesCustomPhases = spec.somKHUsesCustomPhases
        somKHFirstSteps = spec.somKHFirstSteps
        somKHSecondSteps = spec.somKHSecondSteps
        somKHFirstLearningRate = spec.somKHFirstLearningRate
        somKHSecondLearningRate = spec.somKHSecondLearningRate
        somKHFirstRadius = spec.somKHFirstRadius
        somKHSecondRadius = spec.somKHSecondRadius
        somKHUsesExplicitCodebooks = spec.somKHUsesExplicitCodebooks
        somKHInitialCodebooks = spec.somKHInitialCodebooks
        clusterCount = spec.clusterCount
        sampleSize = spec.sampleSize
        topicCount = spec.topicCount
        topicCandidatesDraft = spec.topicCandidatesDraft
        topicCriterion = spec.topicCriterion
        alpha = spec.alpha
        beta = spec.beta
        burnIn = spec.burnIn
        posteriorSamples = spec.posteriorSamples
        thinning = spec.thinning
        topicTermsShown = spec.topicTermsShown
        smoothing = spec.smoothing
        folds = spec.folds
        rules = spec.rules
        labels = spec.labels
        linkage = spec.linkage
        minimumJaccard = spec.minimumJaccard
        maximumEdges = spec.maximumEdges
        output = StudioAdvancedOutput(
            tool: archive.tool, input: archive.input, methodIdentifier: archive.methodIdentifier,
            validationStatus: archive.validationStatus, requestDigest: archive.requestDigest,
            request: decoded.request,
            canonicalRequest: archive.canonicalRequest, encodedResult: archive.encodedResult,
            typedResult: nil, parameters: archive.parameters.map { ($0.key, $0.value) },
            columns: archive.columns, rows: archive.rows, points: archive.points,
            factorPoints: archive.factorPoints, treeVertices: archive.treeVertices,
            treeLeafLabels: archive.treeLeafLabels,
            diagnostics: archive.diagnostics.map { ($0.key, $0.value) }, tables: archive.tables,
            completedAt: archive.completedAt, sourceLabels: archive.sourceLabels,
            sourceNumbers: archive.sourceNumbers)
        capturedSpecification = spec
        scheduleFilter()
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
        if [.mds, .mdsSearch, .mdsOrdinal, .mdsOrdinalSearch].contains(spec.tool),
            !(1...2).contains(spec.dimensions)
        {
            throw invalidInput()
        }
        let request: GlifiStudioTextAnalysisRequest
        var parameters: [(key: String, value: String)] = []
        func localized(_ key: String) -> String {
            String(localized: String.LocalizationValue(key), locale: locale)
        }
        if spec.tool.usesDenseMatrix {
            parameters.append(("advanced.maximum-terms", String(spec.maximumTerms)))
        }
        if [
            .mds, .mdsSearch, .mdsOrdinal, .mdsOrdinalSearch, .som, .somAdvanced, .clara,
            .topics, .topicSelection,
            .classifierValidation,
        ].contains(spec.tool) {
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
                ("advanced.distance", localized("advanced.distance.\(spec.distance.rawValue)")),
                ("advanced.mds-method", localized("advanced.mds.\(spec.mdsMethod.rawValue)")),
                ("advanced.dimensions", String(spec.dimensions)),
                ("advanced.iterations", String(spec.maximumIterations)),
            ]
        case .mdsSearch:
            guard (1...32).contains(spec.mdsStarts) else { throw invalidInput() }
            let distances = try await GlifiStudioTextAnalytics.dissimilarities(
                input.matrix, metric: spec.distance)
            request = .advanced(
                .mdsSearch(
                    matrix: distances, dimensions: spec.dimensions, method: spec.mdsSearchMethod,
                    starts: spec.mdsStarts, seed: spec.seed,
                    maximumIterations: spec.maximumIterations, tolerance: spec.mdsTolerance))
            parameters += [
                ("advanced.distance", localized("advanced.distance.\(spec.distance.rawValue)")),
                ("advanced.mds-method", localized("advanced.mds.\(spec.mdsSearchMethod.rawValue)")),
                ("advanced.dimensions", String(spec.dimensions)),
                ("advanced.iterations", String(spec.maximumIterations)),
                ("advanced.starts", String(spec.mdsStarts)),
                ("advanced.tolerance", String(spec.mdsTolerance)),
            ]
        case .mdsOrdinal, .mdsOrdinalSearch:
            guard spec.tool != .mdsOrdinalSearch || (1...32).contains(spec.mdsStarts) else {
                throw invalidInput()
            }
            let distances = try await GlifiStudioTextAnalytics.dissimilarities(
                input.matrix, metric: spec.distance)
            let operation: GlifiStudioKHAnalysisRequest
            if spec.tool == .mdsOrdinalSearch {
                operation = .ordinalMDSSearch(
                    matrix: distances, dimensions: spec.dimensions, ties: spec.ordinalTies,
                    starts: spec.mdsStarts, seed: spec.seed,
                    maximumIterations: spec.maximumIterations, tolerance: spec.mdsTolerance)
                parameters.append(("advanced.starts", String(spec.mdsStarts)))
            } else {
                operation = .ordinalMDS(
                    matrix: distances, dimensions: spec.dimensions, ties: spec.ordinalTies,
                    seed: spec.seed, maximumIterations: spec.maximumIterations,
                    tolerance: spec.mdsTolerance)
            }
            request = .advanced(.kh(operation))
            parameters += [
                ("advanced.distance", localized("advanced.distance.\(spec.distance.rawValue)")),
                (
                    "advanced.ordinal-ties",
                    localized("advanced.ordinal-ties.\(spec.ordinalTies.rawValue)")
                ),
                ("advanced.dimensions", String(spec.dimensions)),
                ("advanced.iterations", String(spec.maximumIterations)),
                ("advanced.tolerance", String(spec.mdsTolerance)),
            ]
        case .somPCAInitialization, .somKH:
            guard spec.gridWidth > 0, spec.gridHeight > 0 else { throw invalidInput() }
            let units = spec.gridWidth.multipliedReportingOverflow(by: spec.gridHeight)
            guard !units.overflow, units.partialValue <= 256,
                units.partialValue <= 30_000 / max(1, input.terms.count)
            else { throw resourceLimit() }
            if spec.tool == .somPCAInitialization {
                request = .advanced(
                    .kh(
                        .somPCAInitialization(
                            matrix: input.matrix, width: spec.gridWidth, height: spec.gridHeight)))
            } else {
                let initial: [[Double]]?
                if spec.somKHUsesExplicitCodebooks {
                    guard spec.somKHInitialCodebooks.utf8.count <= 1_048_576 else {
                        throw resourceLimit()
                    }
                    let lines = spec.somKHInitialCodebooks.split(whereSeparator: \.isNewline)
                    guard lines.count == units.partialValue else { throw invalidInput() }
                    initial = try lines.map { line in
                        let tokens = line.split(whereSeparator: \.isWhitespace)
                        guard tokens.count == input.terms.count else { throw invalidInput() }
                        return try tokens.map { token in
                            guard
                                token.range(
                                    of:
                                        #"^[+-]?(?:[0-9]+(?:[.,][0-9]*)?|[.,][0-9]+)(?:[eE][+-]?[0-9]+)?$"#,
                                    options: .regularExpression) != nil,
                                !(token.contains(".") && token.contains(",")),
                                let value = Double(token.replacingOccurrences(of: ",", with: ".")),
                                value.isFinite
                            else { throw invalidInput() }
                            return value
                        }
                    }
                    guard initial?.allSatisfy({ $0.count == input.terms.count }) == true else {
                        throw invalidInput()
                    }
                } else {
                    initial = nil
                }
                request = .advanced(
                    .kh(
                        .somKH(
                            matrix: input.matrix, width: spec.gridWidth, height: spec.gridHeight,
                            firstPhase: spec.somKHUsesCustomPhases
                                ? .init(
                                    steps: spec.somKHFirstSteps,
                                    initialLearningRate: spec.somKHFirstLearningRate,
                                    initialRadius: spec.somKHFirstRadius) : nil,
                            secondPhase: spec.somKHUsesCustomPhases
                                ? .init(
                                    steps: spec.somKHSecondSteps,
                                    initialLearningRate: spec.somKHSecondLearningRate,
                                    initialRadius: spec.somKHSecondRadius) : nil,
                            topology: spec.somTopology, initialCodebooks: initial,
                            codebookClusterCount: spec.clustersSOMCodebooks
                                ? spec.somCodebookClusterCount : nil)))
                parameters += [
                    (
                        "advanced.som-topology",
                        localized("advanced.som-topology.\(spec.somTopology.rawValue)")
                    ),
                    (
                        "advanced.som-initialization",
                        localized(
                            spec.somKHUsesExplicitCodebooks
                                ? "advanced.som-initialization.explicit"
                                : "advanced.som-initialization.pca")
                    ),
                    (
                        "advanced.som-codebooks",
                        localized(spec.clustersSOMCodebooks ? "common.yes" : "common.no")
                    ),
                ]
                if spec.clustersSOMCodebooks {
                    parameters.append(
                        ("advanced.codebook-clusters", String(spec.somCodebookClusterCount)))
                }
            }
            parameters += [
                ("advanced.width", String(spec.gridWidth)),
                ("advanced.height", String(spec.gridHeight)),
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
        case .somAdvanced:
            guard spec.gridWidth > 0, spec.gridHeight > 0 else { throw invalidInput() }
            let units = spec.gridWidth.multipliedReportingOverflow(by: spec.gridHeight)
            guard !units.overflow,
                units.partialValue <= 256,
                units.partialValue <= 100_000 / max(1, input.terms.count)
            else { throw resourceLimit() }
            request = .advanced(
                .somAdvanced(
                    matrix: input.matrix, width: spec.gridWidth, height: spec.gridHeight,
                    seed: spec.seed, epochs: spec.epochs, topology: spec.somTopology,
                    initialRadius: spec.somInitialRadius, finalRadius: spec.somFinalRadius,
                    tolerance: spec.somTolerance,
                    codebookClusterCount: spec.clustersSOMCodebooks
                        ? spec.somCodebookClusterCount : nil))
            parameters += [
                ("advanced.width", String(spec.gridWidth)),
                ("advanced.height", String(spec.gridHeight)),
                ("advanced.epochs", String(spec.epochs)),
                (
                    "advanced.som-topology",
                    localized("advanced.som-topology.\(spec.somTopology.rawValue)")
                ),
                ("advanced.initial-radius", String(spec.somInitialRadius)),
                ("advanced.final-radius", String(spec.somFinalRadius)),
                ("advanced.tolerance", String(spec.somTolerance)),
                (
                    "advanced.som-codebooks",
                    localized(spec.clustersSOMCodebooks ? "common.yes" : "common.no")
                ),
            ]
            if spec.clustersSOMCodebooks {
                parameters.append(
                    ("advanced.codebook-clusters", String(spec.somCodebookClusterCount)))
            }
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
        case .topicSelection:
            guard spec.topicCandidatesDraft.utf8.count <= 256,
                (1...1_000).contains(spec.topicTermsShown)
            else { throw invalidInput() }
            let candidates = try spec.topicCandidatesDraft.split(whereSeparator: \.isWhitespace).map
            {
                guard let count = Int($0) else { throw invalidInput() }
                return count
            }
            guard !candidates.isEmpty, candidates.count <= 32 else { throw invalidInput() }
            request = .advanced(
                .ldaSelection(
                    documents: input.documents, candidateTopicCounts: candidates, seed: spec.seed,
                    options: .init(
                        criterion: spec.topicCriterion, folds: spec.folds,
                        alpha: spec.alpha, beta: spec.beta, burnIn: spec.burnIn,
                        sampleCount: spec.posteriorSamples, thinning: spec.thinning)))
            parameters += [
                ("advanced.topic-candidates", candidates.map(String.init).joined(separator: ", ")),
                (
                    "advanced.selection-criterion",
                    localized("advanced.selection-criterion.\(spec.topicCriterion.rawValue)")
                ),
                ("advanced.folds", String(spec.folds)),
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
            parameters += [
                ("advanced.distance", localized("advanced.distance.\(spec.distance.rawValue)"))
            ]
        case .correspondence:
            request = .correspondence(matrix: input.matrix)
        case .hierarchical:
            let distances = try await GlifiStudioTextAnalytics.dissimilarities(
                input.matrix, metric: spec.distance)
            request = .hierarchical(matrix: distances, linkage: spec.linkage)
            parameters += [
                ("advanced.distance", localized("advanced.distance.\(spec.distance.rawValue)")),
                ("advanced.linkage", localized("advanced.linkage.\(spec.linkage)")),
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
        let canonicalRequest = try request.canonicalData()
        let effectiveRequest = try GlifiStudioTextAnalysisRequest.decode(canonicalRequest)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(effectiveRequest)
        var rows: [StudioAdvancedRow] = []
        var columns: [String] = []
        var points: [StudioAdvancedPoint] = []
        var factorPoints: [StudioAdvancedFactorPoint] = []
        var treeVertices: [StudioAdvancedTreeVertex] = []
        var treeLeafLabels: [String] = []
        var diagnostics: [(key: String, value: String)] = []
        var extraTables: [StudioAdvancedTable] = []
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
        func table(_ key: String, columns: [String], values: [[String]], sourceIndices: [Int?] = [])
            -> StudioAdvancedTable
        {
            StudioAdvancedTable(
                id: key, titleKey: key, columns: columns,
                rows: values.enumerated().map {
                    let index =
                        sourceIndices.indices.contains($0.offset) ? sourceIndices[$0.offset] : nil
                    let source = index.flatMap {
                        input.sourceRevisionIDs.indices.contains($0)
                            ? input.sourceRevisionIDs[$0] : nil
                    }
                    return StudioAdvancedRow(
                        id: $0.offset, values: $0.element, sourceRevisionID: source)
                })
        }
        func mdsCoordinates(_ value: GlifiStudioMDSResult) throws {
            guard (1...2).contains(spec.dimensions),
                value.coordinates.count == input.sourceRevisionIDs.count,
                value.coordinates.allSatisfy({ $0.count == spec.dimensions })
            else { throw unexpectedPayload() }
            columns = ["summary.source.label", "advanced.axis-one", "advanced.axis-two"]
            for (index, coordinates) in value.coordinates.enumerated() {
                let x = coordinates[0]
                let y = coordinates.count > 1 ? coordinates[1] : 0
                add(
                    [sourceNumber(index), number(x), spec.dimensions > 1 ? number(y) : "—"],
                    source: index)
                points.append(
                    StudioAdvancedPoint(
                        id: index, x: x, y: y,
                        sourceRevisionID: input.sourceRevisionIDs[index],
                        sourceNumber: sourceNumbers[input.sourceRevisionIDs[index]] ?? index + 1))
            }
            diagnostics += [
                ("advanced.stress", number(value.stress)),
                ("advanced.completed-iterations", String(value.iterations)),
                (
                    "advanced.convergence",
                    value.converged ? "advanced.converged" : "advanced.limit-reached"
                ),
            ]
        }
        func mdsDetails(_ runs: [GlifiStudioMDSResult]) {
            extraTables.append(
                table(
                    "advanced.table.mds-objectives",
                    columns: ["advanced.run-index", "advanced.step", "advanced.objective-value"],
                    values: runs.enumerated().flatMap { run, value in
                        value.objectiveHistory.enumerated().map {
                            [String(run + 1), String($0.offset), number($0.element)]
                        }
                    }))
            if runs.contains(where: { !$0.eigenvalues.isEmpty }) {
                extraTables.append(
                    table(
                        "advanced.table.mds-eigenvalues",
                        columns: ["advanced.run-index", "advanced.axis", "advanced.eigenvalue"],
                        values: runs.enumerated().flatMap { run, value in
                            value.eigenvalues.enumerated().map {
                                [String(run + 1), String($0.offset + 1), number($0.element)]
                            }
                        }))
            }
        }
        func somAssignments(_ value: GlifiStudioSOMResult) throws {
            guard value.assignments.count == input.sourceRevisionIDs.count, value.width > 0,
                value.assignments.allSatisfy({ value.prototypes.indices.contains($0) })
            else { throw unexpectedPayload() }
            columns = ["summary.source.label", "advanced.grid-column", "advanced.grid-row"]
            for (index, unit) in value.assignments.enumerated() {
                add(
                    [
                        sourceNumber(index), String(unit % value.width + 1),
                        String(unit / value.width + 1),
                    ], source: index)
            }
            diagnostics += [
                ("advanced.quantization-error", number(value.quantizationError)),
                ("advanced.topographic-error", number(value.topographicError)),
                ("advanced.epochs", String(value.epochs)),
                (
                    "advanced.convergence",
                    value.converged ? "advanced.converged" : "advanced.limit-reached"
                ),
            ]
        }
        func mdsSearchResults(_ value: GlifiStudioMDSSearchResult) throws {
            guard value.runs.indices.contains(value.chosenRun) else {
                throw unexpectedPayload()
            }
            try mdsCoordinates(value.best)
            diagnostics += [
                ("advanced.chosen-run", String(value.chosenRun + 1)),
                ("advanced.completed-runs", String(value.runs.count)),
            ]
            extraTables.append(
                table(
                    "advanced.table.mds-runs",
                    columns: [
                        "advanced.run-index", "advanced.seed", "advanced.stress",
                        "advanced.completed-iterations", "advanced.convergence",
                    ],
                    values: value.runs.enumerated().map { index, run in
                        [
                            String(index + 1), String(run.seed), number(run.stress),
                            String(run.iterations),
                            localized(
                                run.converged ? "advanced.converged" : "advanced.limit-reached"),
                        ]
                    }))
            var coordinates: [[String]] = []
            var sourceIndices: [Int?] = []
            for (run, result) in value.runs.enumerated() {
                guard result.coordinates.count == input.sourceRevisionIDs.count,
                    result.coordinates.allSatisfy({ $0.count == spec.dimensions })
                else { throw unexpectedPayload() }
                for (source, point) in result.coordinates.enumerated() {
                    coordinates.append([
                        String(run + 1), sourceNumber(source), number(point[0]),
                        point.count > 1 ? number(point[1]) : "—",
                    ])
                    sourceIndices.append(source)
                }
            }
            extraTables.append(
                table(
                    "advanced.table.mds-all-coordinates",
                    columns: [
                        "advanced.run-index", "summary.source.label", "advanced.axis-one",
                        "advanced.axis-two",
                    ],
                    values: coordinates, sourceIndices: sourceIndices))
            mdsDetails(value.runs)
        }
        func somDetails(
            width: Int, prototypes: [[Double]], uMatrix: [Double],
            clustering: GlifiStudioSOMCodebookClustering?, topology: GlifiStudioSOMTopology
        ) throws {
            let units = prototypes.count
            guard uMatrix.count == units,
                prototypes.allSatisfy({ $0.count == input.terms.count }),
                clustering.map({ $0.assignments.count == units }) ?? true
            else { throw unexpectedPayload() }
            diagnostics.append(
                (
                    "advanced.som-topology",
                    localized("advanced.som-topology.\(topology.rawValue)")
                ))
            extraTables.append(
                table(
                    "advanced.table.som-prototypes",
                    columns: [
                        "advanced.unit", "advanced.grid-column", "advanced.grid-row",
                        "advanced.term", "advanced.value",
                    ],
                    values: prototypes.enumerated().flatMap { unit, prototype in
                        prototype.enumerated().map { term, weight in
                            [
                                String(unit + 1), String(unit % width + 1),
                                String(unit / width + 1), input.terms[term],
                                number(weight),
                            ]
                        }
                    }))
            extraTables.append(
                table(
                    "advanced.table.som-u-matrix",
                    columns: [
                        "advanced.unit", "advanced.grid-column", "advanced.grid-row",
                        "advanced.u-value", "advanced.cluster",
                    ],
                    values: uMatrix.enumerated().map { unit, distance in
                        [
                            String(unit + 1), String(unit % width + 1),
                            String(unit / width + 1),
                            number(distance),
                            clustering.map { String($0.assignments[unit] + 1) }
                                ?? "—",
                        ]
                    }))
            if let clustering = clustering {
                guard clustering.children.count == clustering.heights.count,
                    clustering.children.count == clustering.wardIncrements.count,
                    clustering.children.count == clustering.sizes.count,
                    clustering.children.allSatisfy({ $0.count == 2 })
                else { throw unexpectedPayload() }
                func nodeName(_ node: Int) -> String {
                    let key = node < units ? "advanced.node.unit" : "advanced.node.cluster"
                    return localized(key).replacingOccurrences(
                        of: "{number}",
                        with: String(node < units ? node + 1 : node - units + 1))
                }
                extraTables.append(
                    table(
                        "advanced.table.som-ward",
                        columns: [
                            "advanced.merge", "advanced.first-node", "advanced.second-node",
                            "advanced.merge-height", "advanced.ward-increment",
                            "advanced.cluster-size",
                        ],
                        values: clustering.children.enumerated().map { index, children in
                            [
                                String(index + 1), nodeName(children[0]), nodeName(children[1]),
                                number(clustering.heights[index]),
                                clustering.wardIncrements[index].map(number)
                                    ?? localized("advanced.undefined"),
                                String(clustering.sizes[index]),
                            ]
                        }))
                diagnostics.append(("advanced.codebook-method", clustering.methodIdentifier))
            }
        }
        func topicRows(_ value: GlifiStudioLDAResult) throws {
            guard !value.topicTerms.isEmpty,
                value.documentTopics.count == input.sourceRevisionIDs.count,
                value.documentTopics.allSatisfy({ $0.count == value.topicTerms.count })
            else { throw unexpectedPayload() }
            columns = [
                "advanced.topic", "advanced.term", "summary.source.label", "advanced.probability",
            ]
            for (topic, probabilities) in value.topicTerms.enumerated() {
                guard probabilities.count == value.vocabulary.count else {
                    throw unexpectedPayload()
                }
                let indices = probabilities.indices.sorted {
                    probabilities[$0] == probabilities[$1]
                        ? $0 < $1 : probabilities[$0] > probabilities[$1]
                }.prefix(spec.topicTermsShown)
                for index in indices {
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
            diagnostics += [
                ("advanced.training-perplexity", number(value.trainingPerplexity)),
                ("advanced.topic-terms", String(spec.topicTermsShown)),
            ]
        }
        switch result.payload {
        case let .mds(value):
            try mdsCoordinates(value)
            mdsDetails([value])
        case let .som(value):
            try somAssignments(value)
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
            try topicRows(value)
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
                factorPoints.append(
                    StudioAdvancedFactorPoint(
                        id: "source:\(source)", label: sourceNumber(source),
                        seriesKey: "visual.series.documents", x: coordinates.first ?? 0,
                        y: coordinates.count > 1 ? coordinates[1] : 0))
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
                factorPoints.append(
                    StudioAdvancedFactorPoint(
                        id: "term:\(column)", label: input.terms[column],
                        seriesKey: "visual.series.terms", x: coordinates.first ?? 0,
                        y: coordinates.count > 1 ? coordinates[1] : 0))
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
            let tree = try Self.treeVertices(value, leafCount: input.sourceRevisionIDs.count)
            treeVertices = tree.vertices
            treeLeafLabels = tree.order.map(sourceNumber)
            columns = [
                "advanced.merge", "advanced.first-node", "advanced.second-node",
                "advanced.merge-height",
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
        case let .advanced(payload):
            switch payload {
            case let .mdsSearch(value):
                try mdsSearchResults(value)
            case let .somAdvanced(value):
                try somAssignments(value.map)
                try somDetails(
                    width: value.map.width, prototypes: value.map.prototypes,
                    uMatrix: value.uMatrix,
                    clustering: value.codebookClustering, topology: value.topology)
            case let .ldaSelection(value):
                try topicRows(value.selectedModel)
                diagnostics += [
                    ("advanced.selected-topics", String(value.selectedTopicCount)),
                    (
                        "advanced.selection-criterion",
                        localized("advanced.selection-criterion.\(value.criterion)")
                    ),
                ]
                var candidates: [[String]] = []
                var folds: [[String]] = []
                for candidate in value.candidates {
                    let metrics: [(String, Double?)] = [
                        ("caoJuan2009", candidate.metrics.caoJuan2009),
                        ("arun2010", candidate.metrics.arun2010),
                        ("deveaud2014", candidate.metrics.deveaud2014),
                        ("griffiths2004", candidate.metrics.griffiths2004),
                        ("heldOutPerplexity", candidate.heldOutPerplexity),
                        ("trainingPerplexity", candidate.trainingPerplexity),
                    ]
                    for (key, metric) in metrics {
                        let reason = candidate.metrics.unavailableReasons[key]
                        let reasonKey = reason.map { "advanced.unavailable.\($0)" }
                        let explanation =
                            reasonKey.map { key in
                                let text = localized(key)
                                return text == key ? reason ?? "—" : text
                            } ?? (metric == nil ? localized("advanced.no-held-out-folds") : "—")
                        candidates.append([
                            String(candidate.topicCount), localized("advanced.metric.\(key)"),
                            metric.map(number) ?? localized("advanced.undefined"), explanation,
                        ])
                    }
                    for (fold, score) in candidate.foldScores.enumerated() {
                        folds.append([
                            String(candidate.topicCount), String(fold + 1),
                            String(score.evaluatedTokenCount), String(score.observedTokenCount),
                            String(score.ignoredTokenCount), number(score.logLikelihood),
                            number(score.perplexity),
                        ])
                    }
                }
                extraTables.append(
                    table(
                        "advanced.table.lda-candidates",
                        columns: [
                            "advanced.topics", "advanced.metric", "advanced.value",
                            "advanced.unavailable-reason",
                        ], values: candidates))
                if !folds.isEmpty {
                    extraTables.append(
                        table(
                            "advanced.table.lda-held-out",
                            columns: [
                                "advanced.topics", "advanced.fold", "advanced.evaluated-tokens",
                                "advanced.observed-tokens",
                                "advanced.ignored-tokens", "advanced.log-likelihood",
                                "advanced.perplexity",
                            ], values: folds))
                }
                if !value.foldAssignments.isEmpty {
                    guard value.foldAssignments.count == input.sourceRevisionIDs.count else {
                        throw unexpectedPayload()
                    }
                    extraTables.append(
                        table(
                            "advanced.table.lda-fold-assignments",
                            columns: ["summary.source.label", "advanced.fold"],
                            values: value.foldAssignments.enumerated().map {
                                [sourceNumber($0.offset), String($0.element + 1)]
                            },
                            sourceIndices: value.foldAssignments.indices.map { Optional($0) }))
                }
            case let .kh(value):
                switch value {
                case let .mds(value):
                    try mdsCoordinates(value)
                    mdsDetails([value])
                case let .mdsSearch(value):
                    try mdsSearchResults(value)
                case let .matrix(value):
                    guard spec.tool == .somPCAInitialization,
                        value.count == spec.gridWidth * spec.gridHeight,
                        value.allSatisfy({ $0.count == input.terms.count })
                    else { throw unexpectedPayload() }
                    columns = [
                        "advanced.unit", "advanced.grid-column", "advanced.grid-row",
                        "advanced.term", "advanced.value",
                    ]
                    for (unit, codebook) in value.enumerated() {
                        for (term, weight) in codebook.enumerated() {
                            add([
                                String(unit + 1), String(unit % spec.gridWidth + 1),
                                String(unit / spec.gridWidth + 1), input.terms[term],
                                number(weight),
                            ])
                        }
                    }
                case let .som(value):
                    guard value.assignments.count == input.sourceRevisionIDs.count, value.width > 0,
                        value.assignments.allSatisfy({ value.prototypes.indices.contains($0) })
                    else { throw unexpectedPayload() }
                    columns = ["summary.source.label", "advanced.grid-column", "advanced.grid-row"]
                    for (index, unit) in value.assignments.enumerated() {
                        add(
                            [
                                sourceNumber(index), String(unit % value.width + 1),
                                String(unit / value.width + 1),
                            ], source: index)
                    }
                    diagnostics += [
                        ("advanced.quantization-error", number(value.quantizationError)),
                        ("advanced.topographic-error", number(value.topographicError)),
                        ("advanced.neighborhood-distortion", number(value.neighborhoodDistortion)),
                        ("advanced.completed-steps", String(value.completedSteps)),
                    ]
                    let phases = [value.firstPhase, value.secondPhase]
                    for (index, phase) in phases.enumerated() {
                        parameters += [
                            (index == 0 ? "advanced.som-phase-one" : "advanced.som-phase-two", ""),
                            ("advanced.som-phase-steps", String(phase.steps)),
                            ("advanced.som-learning-rate", number(phase.initialLearningRate)),
                            ("advanced.som-phase-radius", number(phase.initialRadius)),
                        ]
                    }
                    for (key, codebooks) in [
                        ("advanced.table.som-initial-codebooks", value.initialCodebooks),
                        ("advanced.table.som-phase-one-codebooks", value.firstPhaseCodebooks),
                    ] {
                        guard codebooks.count == value.prototypes.count,
                            codebooks.allSatisfy({ $0.count == input.terms.count })
                        else { throw unexpectedPayload() }
                        extraTables.append(
                            table(
                                key,
                                columns: [
                                    "advanced.unit", "advanced.grid-column", "advanced.grid-row",
                                    "advanced.term", "advanced.value",
                                ],
                                values: codebooks.enumerated().flatMap { unit, codebook in
                                    codebook.enumerated().map { term, weight in
                                        [
                                            String(unit + 1), String(unit % value.width + 1),
                                            String(unit / value.width + 1), input.terms[term],
                                            number(weight),
                                        ]
                                    }
                                }))
                    }
                    try somDetails(
                        width: value.width, prototypes: value.prototypes, uMatrix: value.uMatrix,
                        clustering: value.codebookClustering, topology: value.topology)
                case .wordContext, .correspondence, .collocation, .wordAssociation, .documentScores,
                    .legacyClustering, .chiSquare, .codeCrosstabSignificance, .termScores,
                    .termExtraction,
                    .incrementalClassifier, .classifierAgreement:
                    throw unexpectedPayload()
                }
            case .communities, .graphLayout, .minimumSpanningForest, .linguistic,
                .linguisticAvailability, .linguisticCoding:
                throw unexpectedPayload()
            }
        }
        guard rows.count <= 100_000,
            extraTables.reduce(rows.count, { $0 + $1.rows.count }) <= 100_000
        else { throw resourceLimit() }
        let tables =
            [
                StudioAdvancedTable(
                    id: "primary", titleKey: "advanced.table.primary",
                    columns: columns, rows: rows)
            ] + extraTables
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return StudioAdvancedOutput(
            tool: spec.tool, input: input, methodIdentifier: result.methodIdentifier,
            validationStatus: result.validationStatus, requestDigest: result.requestDigest,
            request: effectiveRequest, canonicalRequest: canonicalRequest,
            encodedResult: try encoder.encode(result), typedResult: result,
            parameters: parameters, columns: columns, rows: rows, points: points,
            factorPoints: factorPoints, treeVertices: treeVertices, treeLeafLabels: treeLeafLabels,
            diagnostics: diagnostics, tables: tables, completedAt: Date(),
            sourceLabels: sourceLabels,
            sourceNumbers: input.sourceRevisionIDs.enumerated().map {
                sourceNumbers[$0.element] ?? $0.offset + 1
            })
    }

    nonisolated private static func treeVertices(
        _ value: GlifiStudioMatrixClustering, leafCount: Int
    ) throws -> (vertices: [StudioAdvancedTreeVertex], order: [Int]) {
        guard leafCount >= 2, value.children.count == leafCount - 1,
            value.heights.count == value.children.count
        else { throw unexpectedPayload() }
        var stack = [2 * leafCount - 2]
        var order: [Int] = []
        while let node = stack.popLast() {
            if node < leafCount {
                guard node >= 0 else { throw unexpectedPayload() }
                order.append(node)
            } else {
                let step = node - leafCount
                guard value.children.indices.contains(step), value.children[step].count == 2,
                    value.children[step].allSatisfy({ $0 >= 0 && $0 < node })
                else { throw unexpectedPayload() }
                stack.append(value.children[step][1])
                stack.append(value.children[step][0])
            }
            guard stack.count + order.count <= leafCount else { throw unexpectedPayload() }
        }
        guard Set(order).count == leafCount else { throw unexpectedPayload() }
        var x = [Double](repeating: 0, count: 2 * leafCount - 1)
        var y = x
        for (position, leaf) in order.enumerated() { x[leaf] = Double(position + 1) }
        var vertices: [StudioAdvancedTreeVertex] = []
        for (step, children) in value.children.enumerated() {
            let node = leafCount + step
            let height = value.heights[step]
            guard children.count == 2, children.allSatisfy({ $0 >= 0 && $0 < node }),
                height.isFinite, height >= 0
            else { throw unexpectedPayload() }
            let a = children[0]
            let b = children[1]
            for (part, startX, startY, endX, endY) in [
                ("first", x[a], y[a], x[a], height),
                ("second", x[b], y[b], x[b], height),
                ("bridge", x[a], height, x[b], height),
            ] {
                let segment = "merge:\(step + 1):\(part)"
                vertices.append(
                    .init(id: segment + ":start", segment: segment, x: startX, y: startY))
                vertices.append(.init(id: segment + ":end", segment: segment, x: endX, y: endY))
            }
            x[node] = (x[a] + x[b]) / 2
            y[node] = height
        }
        return (vertices, order)
    }

    nonisolated private static func invalidInput() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "text-analysis.invalid-request", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }

    nonisolated private static func resourceLimit() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "ui.advanced.result-limit", category: "insufficientResources",
            operation: "analyze",
            retryDisposition: "afterConditionsChange", retainedState: "unchanged",
            messageKey: "failure.category.insufficientResources")
    }

    nonisolated private static func unexpectedPayload() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "ui.advanced.unexpected-payload", category: "invariantViolation",
            operation: "analyze",
            retryDisposition: "never", retainedState: "unchanged",
            messageKey: "failure.category.invariantViolation")
    }
}
