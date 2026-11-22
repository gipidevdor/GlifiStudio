// SPDX-License-Identifier: BSD-3-Clause

import CoreFoundation
import Foundation
import GlifiKit
import Observation

nonisolated enum StudioCorpusMethod: String, CaseIterable, Identifiable, Sendable {
    case association, dispersion, similarity, collocations, windowCollocations
    case lexicalNetwork, windowNetwork, correspondence, pca, lsa, nmf, hierarchical, kmeans
    case groupMetrics, postHoc, correlation, pairedMetrics

    var id: Self { self }
    var titleKey: String { "cm.tool.\(rawValue)" }
    var descriptionKey: String { "cm.description.\(rawValue)" }
    var usesGroups: Bool {
        switch self {
        case .similarity, .groupMetrics, .postHoc: true
        case .association, .dispersion, .collocations, .windowCollocations, .lexicalNetwork,
            .windowNetwork, .correspondence, .pca, .lsa, .nmf, .hierarchical, .kmeans,
            .correlation, .pairedMetrics:
            false
        }
    }
    var isMultivariate: Bool {
        switch self {
        case .correspondence, .pca, .lsa, .nmf, .hierarchical, .kmeans: true
        case .association, .dispersion, .similarity, .collocations, .windowCollocations,
            .lexicalNetwork, .windowNetwork, .groupMetrics, .postHoc, .correlation,
            .pairedMetrics:
            false
        }
    }
    var usesWindow: Bool { self == .windowCollocations || self == .windowNetwork }
    var usesCooccurrence: Bool { self == .collocations || self == .lexicalNetwork }
    var usesMetrics: Bool {
        self == .groupMetrics || self == .postHoc || self == .correlation || self == .pairedMetrics
    }
}

nonisolated enum StudioCorpusMetricKind: String, CaseIterable, Identifiable, Sendable {
    case lexicalTokens, termFrequency
    var id: Self { self }
    var titleKey: String { "cm.metric.\(rawValue)" }
    func metric(term: String) -> GlifiStudioDocumentMetric {
        switch self {
        case .lexicalTokens: .lexicalTokenCount
        case .termFrequency: .termRelativeFrequency(term)
        }
    }
}

nonisolated struct StudioCorpusMethodsDraft: Equatable, Sendable {
    var tool: StudioCorpusMethod = .association
    var groupLabels: [String: String] = [:]
    var targetGroup = "A"
    var referenceGroup = "B"
    var usesPartition = false
    var maximumTerms = 50
    var minimumJointCount = 1
    var maximumPairs = 1_000
    var leftSpan = 5
    var rightSpan = 5
    var crossesSentences = false
    var includesSelfPairs = false
    var weightsByInverseDistance = false
    var maximumPositions = 10
    var usesLogDiceThreshold = false
    var minimumLogDice = 0.0
    var usesWeightedJointCount = false
    var scaledPCA = false
    var rank = 2
    var clusterCount = 2
    var linkage = "average"
    var seed: UInt64 = 0
    var restarts = 5
    var firstMetric: StudioCorpusMetricKind = .lexicalTokens
    var firstTerm = ""
    var secondMetric: StudioCorpusMetricKind = .termFrequency
    var secondTerm = ""
    var confidenceLevel = 0.95
    var bootstrapResamples = GlifiStudioGroupComparisonOptions.standard.bootstrapResampleCount
    var permutationCount = GlifiStudioGroupComparisonOptions.standard.permutationMonteCarloCount
    var contrasts = ""
    var diversityWindowSize = GlifiStudioCorpusAnalysisOptions.standard.diversityWindowSize
    var ngramOrders: Set<Int> = [1, 2]
    var maximumDocumentCount = GlifiStudioCorpusAnalysisOptions.standard.maximumDocumentCount
    var maximumSourceBytes = GlifiStudioCorpusAnalysisOptions.standard.maximumSourceByteCount
    var maximumVocabularySize = GlifiStudioCorpusAnalysisOptions.standard.maximumVocabularySize
    var maximumDistinctNGrams = GlifiStudioCorpusAnalysisOptions.standard.maximumDistinctNGramCount
    var maximumNonZeroCells = GlifiStudioCorpusAnalysisOptions.standard.maximumNonZeroCellCount

    func corpusOptions() throws -> GlifiStudioCorpusAnalysisOptions {
        try GlifiStudioCorpusAnalysisOptions(
            diversityWindowSize: diversityWindowSize, ngramSizes: ngramOrders.sorted(),
            maximumDocumentCount: maximumDocumentCount, maximumSourceByteCount: maximumSourceBytes,
            maximumVocabularySize: maximumVocabularySize,
            maximumDistinctNGramCount: maximumDistinctNGrams,
            maximumNonZeroCellCount: maximumNonZeroCells)
    }
    func cooccurrenceOptions() throws -> GlifiStudioCooccurrenceOptions {
        try GlifiStudioCooccurrenceOptions(
            maximumTermCount: maximumTerms, minimumJointCount: minimumJointCount,
            maximumPairCount: maximumPairs)
    }
    func windowOptions() throws -> GlifiStudioWindowCooccurrenceOptions {
        try GlifiStudioWindowCooccurrenceOptions(
            leftSpan: leftSpan, rightSpan: rightSpan, crossesSentences: crossesSentences,
            includesSelfPairs: includesSelfPairs, minimumJointCount: minimumJointCount,
            maximumPairCount: maximumPairs, weightsByInverseDistance: weightsByInverseDistance,
            maximumPositionsPerPair: maximumPositions)
    }
    func comparisonOptions() throws -> GlifiStudioGroupComparisonOptions {
        let lines = contrasts.split(whereSeparator: \.isNewline).map {
            $0.split(whereSeparator: { $0.isWhitespace || $0 == ";" })
        }
        let tokens = lines.flatMap { $0 }
        guard
            !(tokens.contains(where: { $0.contains(",") })
                && tokens.contains(where: { $0.contains(".") }))
        else { throw Self.invalidInput() }
        let rows = try lines.map { line in
            try line.map { value in
                let canonical = value.replacingOccurrences(of: ",", with: ".")
                guard let number = Double(canonical), number.isFinite else {
                    throw Self.invalidInput()
                }
                return number
            }
        }
        return try GlifiStudioGroupComparisonOptions(
            confidenceLevel: confidenceLevel, bootstrapResampleCount: bootstrapResamples,
            permutationMonteCarloCount: permutationCount, resamplingSeed: seed, contrasts: rows)
    }
    static func invalidInput() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "ui.corpus-methods.invalid-input", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "cm.invalid-input")
    }
}

nonisolated enum StudioCorpusPayload: Sendable {
    case association(GlifiStudioAssociationResult)
    case dispersion(GlifiStudioDispersionResult)
    case similarity(GlifiStudioCorpusSimilarityResult)
    case collocations(GlifiStudioCollocationResult)
    case windowCollocations(GlifiStudioWindowCollocationResult)
    case lexicalNetwork(GlifiStudioLexicalNetworkResult)
    case windowNetwork(GlifiStudioWindowNetworkResult)
    case multivariate(GlifiStudioMultivariateResult)
    case groupMetrics(GlifiStudioGroupMetricResult)
    case postHoc(GlifiStudioPostHocResult)
    case correlation(GlifiStudioMetricCorrelationResult)
    case paired(GlifiStudioPairedMetricResult)

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        switch self {
        case let .association(value): return try encoder.encode(value)
        case let .dispersion(value): return try encoder.encode(value)
        case let .similarity(value): return try encoder.encode(value)
        case let .collocations(value): return try encoder.encode(value)
        case let .windowCollocations(value): return try encoder.encode(value)
        case let .lexicalNetwork(value): return try encoder.encode(value)
        case let .windowNetwork(value): return try encoder.encode(value)
        case let .multivariate(value): return try encoder.encode(value)
        case let .groupMetrics(value): return try encoder.encode(value)
        case let .postHoc(value): return try encoder.encode(value)
        case let .correlation(value): return try encoder.encode(value)
        case let .paired(value): return try encoder.encode(value)
        }
    }
}

nonisolated struct StudioCorpusField: Identifiable, Sendable {
    let key: String
    let value: String
    var id: String { key }
}

nonisolated struct StudioCorpusMethodRow: Identifiable, Sendable {
    let id: Int
    let values: [String]
    let details: [StudioCorpusField]
    let sourceRevisionID: String?
    var searchText: String { values.joined(separator: " ") }
}

nonisolated struct StudioCorpusMethodTable: Identifiable, Sendable {
    let id: String
    let columns: [String]
    let rows: [StudioCorpusMethodRow]
}

nonisolated struct StudioCorpusMethodsOutput: Sendable {
    let tool: StudioCorpusMethod
    let sourceRevisionIDs: [String]
    let eligibleSourceRevisionIDs: [String]
    let sourceNumbers: [String: Int]
    let groupNames: [String]
    let groups: [[String]]
    let draft: StudioCorpusMethodsDraft
    let payload: StudioCorpusPayload
    let encodedResult: Data
    let parameters: [StudioCorpusField]
    let completedAt: Date
}

/// Coordinates existing persisted methods and keeps the last valid result independent of drafts.
@MainActor @Observable final class StudioCorpusMethodsModel {
    var draft = StudioCorpusMethodsDraft()
    var tool: StudioCorpusMethod {
        get { draft.tool }
        set { draft.tool = newValue }
    }
    private(set) var output: StudioCorpusMethodsOutput?
    private(set) var tables: [StudioCorpusMethodTable] = []
    private(set) var summary: [StudioCorpusField] = []
    private(set) var methodDetails: [StudioCorpusField] = []
    private(set) var axisCount = 1
    var axis = 1 {
        didSet { if axis != oldValue && !isPublishing { scheduleProjection() } }
    }
    var tableID = "" {
        didSet { if tableID != oldValue && !isPublishing { scheduleFilter() } }
    }
    var search = "" {
        didSet { if search != oldValue && !isPublishing { scheduleFilter() } }
    }
    private(set) var page = 0
    private(set) var matchingCount = 0
    private(set) var visibleRows: [StudioCorpusMethodRow] = []
    private var filtered: [Int] = []
    private var isPublishing = false
    private var lifecycleNonce = UUID()
    private var revision = UUID()
    private var filterTask: Task<Void, Never>?
    private var projectionTask: Task<Void, Never>?
    private var presentationLocale = Locale(identifier: "it_IT")
    static let pageSize = 50
    var selectedTable: StudioCorpusMethodTable? { tables.first { $0.id == tableID } }
    var pageCount: Int { max(1, (matchingCount + Self.pageSize - 1) / Self.pageSize) }

    func reset() {
        lifecycleNonce = UUID()
        filterTask?.cancel()
        projectionTask?.cancel()
        revision = UUID()
        draft = StudioCorpusMethodsDraft()
        output = nil
        tables = []
        summary = []
        methodDetails = []
        axisCount = 1
        axis = 1
        tableID = ""
        search = ""
        matchingCount = 0
        filtered = []
        visibleRows = []
        page = 0
    }

    func groupNames(for ids: [String]) -> [String] {
        Array(
            Set(
                ids.compactMap {
                    draft.groupLabels[$0]?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty })
        ).sorted()
    }

    func showPage(_ value: Int) {
        guard value >= 0, value < pageCount else { return }
        page = value
        updateVisibleRows()
    }

    /// Reads the final snapshot before publishing, so a failed refresh keeps the previous output.
    @discardableResult
    func execute(
        session: GlifiStudioProjectSession, sourceRevisionIDs: [String],
        sourceNumbers: [String: Int], locale: Locale
    ) async throws -> GlifiStudioProjectSnapshot {
        try Self.checkCancellation()
        let executionNonce = UUID()
        lifecycleNonce = executionNonce
        let specification = draft
        let ids = sourceRevisionIDs.sorted()
        guard !ids.isEmpty, Set(ids).count == ids.count else {
            throw StudioCorpusMethodsDraft.invalidInput()
        }
        let namedGroups = Self.groups(specification, ids: ids)
        let payload = try await Self.calculate(
            specification, session: session, ids: ids, namedGroups: namedGroups)
        try validateExecution(executionNonce)
        let encoded = try await Self.encode(payload)
        try validateExecution(executionNonce)
        let usedGroups: [(name: String, ids: [String])]
        let effectiveIDs: [String]
        if case let .similarity(value) = payload {
            effectiveIDs = (value.targetSourceRevisionIDs + value.referenceSourceRevisionIDs)
                .sorted()
            usedGroups = [
                (specification.targetGroup, value.targetSourceRevisionIDs),
                (specification.referenceGroup, value.referenceSourceRevisionIDs),
            ]
        } else {
            effectiveIDs = ids
            usedGroups =
                specification.tool.usesGroups
                    || (specification.tool == .dispersion && specification.usesPartition)
                ? namedGroups : []
        }
        let next = StudioCorpusMethodsOutput(
            tool: specification.tool, sourceRevisionIDs: effectiveIDs,
            eligibleSourceRevisionIDs: ids, sourceNumbers: sourceNumbers,
            groupNames: usedGroups.map(\.name), groups: usedGroups.map(\.ids),
            draft: specification, payload: payload, encodedResult: encoded,
            parameters: Self.requestedParameters(specification, locale: locale), completedAt: Date()
        )
        let projection = try await Self.project(next, axis: 1, locale: locale)
        try validateExecution(executionNonce)
        let snapshot = try await session.snapshot()
        try validateExecution(executionNonce)
        filterTask?.cancel()
        projectionTask?.cancel()
        revision = UUID()
        output = next
        presentationLocale = locale
        applyProjection(projection, selectedAxis: 1)
        return snapshot
    }

    private func validateExecution(_ nonce: UUID) throws {
        try Self.checkCancellation()
        guard lifecycleNonce == nonce else { throw Self.cancelled() }
    }

    nonisolated private static func checkCancellation() throws {
        if Task.isCancelled { throw cancelled() }
    }

    nonisolated private static func cancelled() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "operation.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled")
    }

    private func applyProjection(_ projection: Projection, selectedAxis: Int) {
        filterTask?.cancel()
        revision = UUID()
        isPublishing = true
        defer { isPublishing = false }
        axis = selectedAxis
        tables = projection.tables
        summary = projection.summary
        methodDetails = projection.details
        axisCount = projection.axisCount
        tableID = tables.first?.id ?? ""
        search = ""
        filtered = Array((selectedTable?.rows ?? []).indices)
        matchingCount = filtered.count
        page = 0
        updateVisibleRows()
    }

    private func scheduleProjection() {
        guard let output, axis >= 1, axis <= axisCount else { return }
        projectionTask?.cancel()
        filterTask?.cancel()
        let expected = UUID()
        revision = expected
        let selectedAxis = axis
        let locale = presentationLocale
        projectionTask = Task {
            guard
                let projected = try? await Self.project(output, axis: selectedAxis, locale: locale),
                !Task.isCancelled, revision == expected
            else { return }
            applyProjection(projected, selectedAxis: selectedAxis)
        }
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        guard let rows = selectedTable?.rows else { return }
        let expected = UUID()
        revision = expected
        let query = search
        filterTask = Task {
            let indices = await Self.matching(rows, query: query)
            guard !Task.isCancelled, revision == expected else { return }
            filtered = indices
            matchingCount = indices.count
            page = 0
            updateVisibleRows()
        }
    }

    private func updateVisibleRows() {
        let rows = selectedTable?.rows ?? []
        visibleRows = filtered.dropFirst(page * Self.pageSize).prefix(Self.pageSize).map {
            rows[$0]
        }
    }

    nonisolated private static func groups(
        _ draft: StudioCorpusMethodsDraft, ids: [String]
    ) -> [(name: String, ids: [String])] {
        let names = Array(
            Set(
                ids.compactMap {
                    draft.groupLabels[$0]?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty })
        ).sorted()
        return names.map { name in
            (
                name,
                ids.filter {
                    draft.groupLabels[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) == name
                }
            )
        }
    }

    @concurrent private static func encode(_ payload: StudioCorpusPayload) async throws -> Data {
        try checkCancellation()
        return try payload.encoded()
    }

    @concurrent private static func matching(_ rows: [StudioCorpusMethodRow], query: String) async
        -> [Int]
    {
        var indices: [Int] = []
        for index in rows.indices {
            if Task.isCancelled { return [] }
            if query.isEmpty || rows[index].searchText.localizedStandardContains(query) {
                indices.append(index)
            }
        }
        return indices
    }

    @concurrent private static func calculate(
        _ draft: StudioCorpusMethodsDraft, session: GlifiStudioProjectSession,
        ids: [String], namedGroups: [(name: String, ids: [String])]
    ) async throws -> StudioCorpusPayload {
        try checkCancellation()
        let corpus = try draft.corpusOptions()
        let groups = namedGroups.map(\.ids)
        switch draft.tool {
        case .association:
            return try await .association(
                session.analyzeAssociation(sourceRevisionIDs: ids, corpusOptions: corpus))
        case .dispersion:
            if draft.usesPartition {
                guard groups.count >= 2, groups.flatMap({ $0 }).sorted() == ids else {
                    throw StudioCorpusMethodsDraft.invalidInput()
                }
            }
            return try await .dispersion(
                session.analyzeDispersion(
                    sourceRevisionIDs: ids, partition: draft.usesPartition ? groups : nil,
                    corpusOptions: corpus))
        case .similarity:
            let target = namedGroups.first { $0.name == draft.targetGroup }?.ids ?? []
            let reference = namedGroups.first { $0.name == draft.referenceGroup }?.ids ?? []
            return try await .similarity(
                session.compareSimilarity(
                    targetSourceRevisionIDs: target, referenceSourceRevisionIDs: reference,
                    corpusOptions: corpus))
        case .collocations:
            return try await .collocations(
                session.analyzeCollocations(
                    sourceRevisionIDs: ids, options: draft.cooccurrenceOptions(),
                    corpusOptions: corpus))
        case .windowCollocations:
            return try await .windowCollocations(
                session.analyzeWindowCollocations(
                    sourceRevisionIDs: ids, options: draft.windowOptions(), corpusOptions: corpus))
        case .lexicalNetwork:
            return try await .lexicalNetwork(
                session.analyzeLexicalNetwork(
                    sourceRevisionIDs: ids, options: draft.cooccurrenceOptions(),
                    corpusOptions: corpus))
        case .windowNetwork:
            return try await .windowNetwork(
                session.analyzeWindowNetwork(
                    sourceRevisionIDs: ids, window: draft.windowOptions(),
                    minimumLogDice: draft.usesLogDiceThreshold ? draft.minimumLogDice : nil,
                    usesWeightedJointCount: draft.usesWeightedJointCount, corpusOptions: corpus))
        case .correspondence, .pca, .lsa, .nmf, .hierarchical, .kmeans:
            let method: GlifiStudioMultivariateMethod
            switch draft.tool {
            case .correspondence: method = .correspondence
            case .pca: method = .principalComponents(scaled: draft.scaledPCA)
            case .lsa: method = .latentSemantic(rank: draft.rank)
            case .nmf:
                method = .nonNegativeFactorization(
                    rank: draft.rank, seed: draft.seed, restarts: draft.restarts)
            case .hierarchical:
                method = .hierarchical(linkage: draft.linkage, clusterCount: draft.clusterCount)
            case .kmeans:
                method = .kMeans(
                    clusterCount: draft.clusterCount, seed: draft.seed, restarts: draft.restarts)
            case .association, .dispersion, .similarity, .collocations, .windowCollocations,
                .lexicalNetwork, .windowNetwork, .groupMetrics, .postHoc, .correlation,
                .pairedMetrics:
                throw StudioCorpusMethodsDraft.invalidInput()
            }
            return try await .multivariate(
                session.analyzeMultivariate(
                    sourceRevisionIDs: ids, method: method, maximumTermCount: draft.maximumTerms,
                    corpusOptions: corpus))
        case .groupMetrics:
            guard groups.count >= 2, groups.flatMap({ $0 }).sorted() == ids else {
                throw StudioCorpusMethodsDraft.invalidInput()
            }
            return try await .groupMetrics(
                session.compareGroupMetric(
                    groups: groups, metric: draft.firstMetric.metric(term: draft.firstTerm),
                    options: draft.comparisonOptions(), corpusOptions: corpus))
        case .postHoc:
            guard groups.count >= 3, groups.flatMap({ $0 }).sorted() == ids else {
                throw StudioCorpusMethodsDraft.invalidInput()
            }
            return try await .postHoc(
                session.postHocGroupMetric(
                    groups: groups, metric: draft.firstMetric.metric(term: draft.firstTerm),
                    corpusOptions: corpus))
        case .correlation:
            return try await .correlation(
                session.correlateMetrics(
                    sourceRevisionIDs: ids, first: draft.firstMetric.metric(term: draft.firstTerm),
                    second: draft.secondMetric.metric(term: draft.secondTerm), corpusOptions: corpus
                ))
        case .pairedMetrics:
            return try await .paired(
                session.comparePairedMetrics(
                    sourceRevisionIDs: ids, first: draft.firstMetric.metric(term: draft.firstTerm),
                    second: draft.secondMetric.metric(term: draft.secondTerm), corpusOptions: corpus
                ))
        }
    }

    nonisolated struct Projection: Sendable {
        let tables: [StudioCorpusMethodTable]
        let summary: [StudioCorpusField]
        let details: [StudioCorpusField]
        let axisCount: Int
    }

    /// Projects the existing Codable result into bounded, selectable tables; no statistic is recomputed.
    @concurrent private static func project(
        _ output: StudioCorpusMethodsOutput, axis: Int, locale: Locale
    ) async throws -> Projection {
        let object = try JSONSerialization.jsonObject(with: output.encodedResult)
        guard let dictionary = object as? [String: Any] else {
            throw StudioCorpusMethodsDraft.invalidInput()
        }
        let orderedKeys = dictionary.keys.sorted()
        var summary: [StudioCorpusField] = []
        var details: [StudioCorpusField] = []
        var tables: [StudioCorpusMethodTable] = []
        var axisCount = 1
        for key in orderedKeys {
            try checkCancellation()
            guard let value = dictionary[key] else { continue }
            if let matrix = value as? [[NSNumber]], !matrix.isEmpty {
                axisCount = max(axisCount, matrix.map(\.count).max() ?? 1)
                let column = axis - 1
                let rowLabels = matrixLabels(key: key, output: output)
                let sourceIDs = matrixSourceIDs(key: key, output: output)
                let rows = matrix.enumerated().map { index, values in
                    let label =
                        rowLabels.indices.contains(index) ? rowLabels[index] : String(index + 1)
                    let number =
                        values.indices.contains(column)
                        ? format(values[column], locale: locale) : missing(locale)
                    let fields = values.enumerated().map {
                        StudioCorpusField(
                            key: String($0.offset + 1), value: format($0.element, locale: locale))
                    }
                    return StudioCorpusMethodRow(
                        id: index, values: [label, number], details: fields,
                        sourceRevisionID: sourceIDs.indices.contains(index) ? sourceIDs[index] : nil
                    )
                }
                tables.append(
                    StudioCorpusMethodTable(id: key, columns: ["label", "axisValue"], rows: rows))
            } else if let records = value as? [[String: Any]], !records.isEmpty {
                let flattened = records.map { scalarFields($0, locale: locale) }
                let columns = Array(Set(flattened.flatMap(\.keys))).sorted()
                let rows = records.indices.map { index in
                    StudioCorpusMethodRow(
                        id: index,
                        values: columns.map { flattened[index][$0] ?? missing(locale) },
                        details: allFields(records[index], locale: locale),
                        sourceRevisionID: records[index]["sourceRevisionID"] as? String)
                }
                tables.append(StudioCorpusMethodTable(id: key, columns: columns, rows: rows))
            } else if let array = value as? [Any], !array.isEmpty {
                let sourceIDs = matrixSourceIDs(key: key, output: output)
                let rows = array.enumerated().map { index, item in
                    let sourceID = sourceIDs.indices.contains(index) ? sourceIDs[index] : nil
                    let label =
                        sourceID.flatMap { output.sourceNumbers[$0].map(String.init) }
                        ?? sourceID ?? String(index + 1)
                    return StudioCorpusMethodRow(
                        id: index, values: [label, display(item, locale: locale)],
                        details: allFields(item, prefix: key, locale: locale),
                        sourceRevisionID: sourceID
                            ?? (item as? String == nil
                                ? nil
                                : (output.sourceRevisionIDs.contains(item as? String ?? "")
                                    ? item as? String : nil)))
                }
                tables.append(
                    StudioCorpusMethodTable(
                        id: key,
                        columns: [sourceIDs.isEmpty ? "index" : "sourceRevisionID", "value"],
                        rows: rows))
            } else if !(value is [Any]) {
                let fields = allFields(value, prefix: key, locale: locale)
                if ["lineage", "options", "window"].contains(key) || key.contains("Identifier")
                    || key.contains("Digest")
                    || key.contains("Reason")
                {
                    details += fields
                } else {
                    summary += fields
                }
            }
        }
        return Projection(tables: tables, summary: summary, details: details, axisCount: axisCount)
    }

    nonisolated private static func matrixLabels(key: String, output: StudioCorpusMethodsOutput)
        -> [String]
    {
        guard case let .multivariate(value) = output.payload else { return [] }
        switch key {
        case "rowCoordinates", "rowContributions", "rowCosines":
            let excluded = Set(value.excludedSourceRevisionIDs)
            return value.sourceRevisionIDs.filter { !excluded.contains($0) }.map { id in
                output.sourceNumbers[id].map(String.init) ?? id
            }
        case "columnCoordinates", "columnContributions":
            let excluded = Set(value.excludedTerms)
            return value.terms.filter { !excluded.contains($0) }
        default:
            return []
        }
    }

    nonisolated private static func matrixSourceIDs(
        key: String, output: StudioCorpusMethodsOutput
    ) -> [String] {
        guard case let .multivariate(value) = output.payload,
            ["rowCoordinates", "rowContributions", "rowCosines", "clusterAssignments"].contains(key)
        else { return [] }
        let excluded = Set(value.excludedSourceRevisionIDs)
        return value.sourceRevisionIDs.filter { !excluded.contains($0) }
    }

    nonisolated private static func scalarFields(
        _ object: [String: Any], prefix: String = "", locale: Locale
    ) -> [String: String] {
        var fields: [String: String] = [:]
        for key in object.keys.sorted() {
            let name = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let child = object[key] as? [String: Any] {
                fields.merge(scalarFields(child, prefix: name, locale: locale)) { first, _ in first
                }
            } else if !(object[key] is [Any]) {
                fields[name] = display(object[key] ?? NSNull(), locale: locale)
            }
        }
        return fields
    }

    nonisolated private static func allFields(_ value: Any, prefix: String = "", locale: Locale)
        -> [StudioCorpusField]
    {
        if let object = value as? [String: Any] {
            return object.keys.sorted().flatMap { key in
                allFields(
                    object[key] ?? NSNull(), prefix: prefix.isEmpty ? key : "\(prefix).\(key)",
                    locale: locale)
            }
        }
        if let array = value as? [Any] {
            return array.enumerated().flatMap { index, child in
                allFields(child, prefix: "\(prefix).\(index + 1)", locale: locale)
            }
        }
        return [StudioCorpusField(key: prefix, value: display(value, locale: locale))]
    }

    nonisolated private static func display(_ value: Any, locale: Locale) -> String {
        if value is NSNull { return missing(locale) }
        if let number = value as? NSNumber { return format(number, locale: locale) }
        if let text = value as? String { return text }
        if let array = value as? [Any] {
            return array.map { display($0, locale: locale) }.joined(separator: "; ")
        }
        return String(describing: value)
    }

    nonisolated private static func format(_ number: NSNumber, locale: Locale) -> String {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return String(
                localized: String.LocalizationValue(number.boolValue ? "cm.yes" : "cm.no"),
                locale: locale)
        }
        if ["d", "f"].contains(String(cString: number.objCType)) {
            return number.doubleValue.formatted(
                .number.locale(locale).precision(.significantDigits(1...9)))
        }
        if ["Q", "I", "L", "S", "C"].contains(String(cString: number.objCType)) {
            return number.uint64Value.formatted(.number.locale(locale))
        }
        return number.int64Value.formatted(.number.locale(locale))
    }

    nonisolated private static func requestedParameters(
        _ draft: StudioCorpusMethodsDraft, locale: Locale
    ) -> [StudioCorpusField] {
        func field(_ key: String, _ value: String) -> StudioCorpusField {
            StudioCorpusField(key: key, value: value)
        }
        var values = [
            field("diversityWindowSize", String(draft.diversityWindowSize)),
            field(
                "ngramSizes", draft.ngramOrders.sorted().map(String.init).joined(separator: ", ")),
            field("maximumDocumentCount", String(draft.maximumDocumentCount)),
            field("maximumSourceByteCount", String(draft.maximumSourceBytes)),
            field("maximumVocabularySize", String(draft.maximumVocabularySize)),
            field("maximumDistinctNGramCount", String(draft.maximumDistinctNGrams)),
            field("maximumNonZeroCellCount", String(draft.maximumNonZeroCells)),
        ]
        if draft.tool.usesCooccurrence || draft.tool.isMultivariate {
            values.append(field("maximumTermCount", String(draft.maximumTerms)))
        }
        if draft.tool.usesCooccurrence || draft.tool.usesWindow {
            values += [
                field("minimumJointCount", String(draft.minimumJointCount)),
                field("maximumPairCount", String(draft.maximumPairs)),
            ]
        }
        if draft.tool.usesWindow {
            values += [
                field("leftSpan", String(draft.leftSpan)),
                field("rightSpan", String(draft.rightSpan)),
                field(
                    "crossesSentences",
                    format(NSNumber(value: draft.crossesSentences), locale: locale)),
                field(
                    "includesSelfPairs",
                    format(NSNumber(value: draft.includesSelfPairs), locale: locale)),
                field(
                    "weightsByInverseDistance",
                    format(NSNumber(value: draft.weightsByInverseDistance), locale: locale)),
                field("maximumPositionsPerPair", String(draft.maximumPositions)),
            ]
        }
        if draft.tool == .windowNetwork {
            values += [
                field(
                    "minimumLogDice",
                    draft.usesLogDiceThreshold
                        ? format(NSNumber(value: draft.minimumLogDice), locale: locale)
                        : missing(locale)),
                field(
                    "usesWeightedJointCount",
                    format(NSNumber(value: draft.usesWeightedJointCount), locale: locale)),
            ]
        }
        if draft.tool == .pca {
            values.append(field("scaled", format(NSNumber(value: draft.scaledPCA), locale: locale)))
        }
        if draft.tool == .lsa || draft.tool == .nmf {
            values.append(field("rank", String(draft.rank)))
        }
        if draft.tool == .hierarchical || draft.tool == .kmeans {
            values.append(field("clusterCount", String(draft.clusterCount)))
        }
        if draft.tool == .hierarchical { values.append(field("linkage", draft.linkage)) }
        if draft.tool == .nmf || draft.tool == .kmeans || draft.tool == .groupMetrics {
            values.append(field("seed", String(draft.seed)))
        }
        if draft.tool == .nmf || draft.tool == .kmeans {
            values.append(field("restarts", String(draft.restarts)))
        }
        if draft.tool == .groupMetrics {
            values += [
                field(
                    "confidenceLevel",
                    format(NSNumber(value: draft.confidenceLevel), locale: locale)),
                field("bootstrapResampleCount", String(draft.bootstrapResamples)),
                field("permutationMonteCarloCount", String(draft.permutationCount)),
            ]
        }
        return values
    }

    nonisolated private static func missing(_ locale: Locale) -> String {
        String(localized: "cm.undefined", locale: locale)
    }
}
