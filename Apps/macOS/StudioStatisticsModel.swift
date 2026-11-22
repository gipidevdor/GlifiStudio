// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioStatisticsPane: String, CaseIterable, Identifiable, Sendable {
    case configuration, results
    var id: Self { self }
}

nonisolated struct StudioStatisticsRow: Identifiable, Sendable {
    let id: Int
    let values: [GlifiStudioStatisticsValue]
}

nonisolated private struct StudioStatisticsDraft: Equatable, Sendable {
    let operation: GlifiStudioStatisticsOperation
    let input: String
    let contrasts: String
    let probabilities: String
    let parameters: GlifiStudioStatisticsParameters
}

/// Owns explicit statistical drafts and session-only output; execution is owned by StudioHomeModel.
@MainActor @Observable final class StudioStatisticsModel {
    var operation: GlifiStudioStatisticsOperation = .descriptive {
        didSet { if operation != oldValue { pane = .configuration } }
    }
    var input = ""
    var contrastsDraft = "1 -1 0\n0,5 0,5 -1"
    var probabilitiesDraft = "0,25 0,5 0,75"
    var parameters = GlifiStudioStatisticsParameters()
    var pane: StudioStatisticsPane = .configuration
    var search = "" { didSet { scheduleFilter() } }
    private(set) var result: GlifiStudioStatisticsResult?
    private(set) var page = 0
    private(set) var matchingRowCount = 0
    private(set) var visibleRows: [StudioStatisticsRow] = []
    private(set) var capturedInputRows: [StudioStatisticsRow] = []
    private(set) var inputPage = 0
    private var filteredIndices: [Int] = []
    private var revision = UUID()
    private var filterTask: Task<Void, Never>?
    private var filterRevision = UUID()
    private var capturedDraft: StudioStatisticsDraft?
    static let pageSize = 50

    var pageCount: Int { max(1, (matchingRowCount + Self.pageSize - 1) / Self.pageSize) }
    var inputPageCount: Int {
        max(1, (capturedInputRows.count + Self.pageSize - 1) / Self.pageSize)
    }
    var visibleInputRows: [StudioStatisticsRow] {
        Array(capturedInputRows.dropFirst(inputPage * Self.pageSize).prefix(Self.pageSize))
    }
    var titleKey: String { "statistics.operation.\(operation.rawValue)" }
    var isDraftChanged: Bool { capturedDraft.map { $0 != draft } ?? false }

    private var draft: StudioStatisticsDraft {
        StudioStatisticsDraft(
            operation: operation, input: input, contrasts: contrastsDraft,
            probabilities: probabilitiesDraft, parameters: parameters)
    }

    func select(_ operation: GlifiStudioStatisticsOperation) {
        self.operation = operation
        pane = .configuration
    }

    func reset() {
        revision = UUID()
        filterTask?.cancel()
        filterRevision = UUID()
        operation = .descriptive
        input = ""
        contrastsDraft = "1 -1 0\n0,5 0,5 -1"
        probabilitiesDraft = "0,25 0,5 0,75"
        parameters = .init()
        pane = .configuration
        result = nil
        capturedDraft = nil
        search = ""
        page = 0
        matchingRowCount = 0
        filteredIndices = []
        visibleRows = []
        capturedInputRows = []
        inputPage = 0
    }

    func execute() async throws(GlifiStudioFailure) {
        let token = revision
        let submittedDraft = draft
        let selectedOperation = submittedDraft.operation
        let capturedInput = submittedDraft.input
        var capturedParameters = submittedDraft.parameters
        if selectedOperation == .descriptive {
            let probabilityRequest = try await GlifiStudioStatisticsWorkbench.request(
                operation: .descriptive, input: submittedDraft.probabilities,
                parameters: GlifiStudioStatisticsParameters())
            guard probabilityRequest.values.count == 1,
                let probabilities = probabilityRequest.values.first,
                probabilities.count <= 1_024,
                probabilities.allSatisfy({ $0 != nil })
            else { throw Self.invalidInput() }
            capturedParameters.probabilities = probabilities.compactMap { $0 }
        }
        if selectedOperation == .plannedContrasts {
            let parsed = try await GlifiStudioStatisticsWorkbench.request(
                operation: .anova, input: submittedDraft.contrasts, parameters: .init())
            guard parsed.values.allSatisfy({ $0.allSatisfy { $0 != nil } }) else {
                throw Self.invalidInput()
            }
            capturedParameters.contrasts = parsed.values.map { $0.compactMap { $0 } }
        }
        let request = try await GlifiStudioStatisticsWorkbench.request(
            operation: selectedOperation, input: capturedInput, parameters: capturedParameters)
        let next = try await GlifiStudioStatisticsWorkbench.evaluate(request)
        let capturedRows: [StudioStatisticsRow]
        do { capturedRows = try await Self.captureInput(request) } catch { throw Self.cancelled() }
        guard !Task.isCancelled, token == revision else { throw Self.cancelled() }
        filterTask?.cancel()
        filterRevision = UUID()
        result = next
        capturedDraft = submittedDraft
        capturedInputRows = capturedRows
        inputPage = 0
        if !search.isEmpty { search = "" }
        filteredIndices = Array(next.rows.indices)
        matchingRowCount = next.rows.count
        page = 0
        refreshVisibleRows()
        pane = .results
    }

    func showPage(_ proposed: Int) {
        guard proposed >= 0, proposed < pageCount else { return }
        page = proposed
        refreshVisibleRows()
    }

    func showInputPage(_ proposed: Int) {
        guard proposed >= 0, proposed < inputPageCount else { return }
        inputPage = proposed
    }

    @concurrent private static func captureInput(
        _ request: GlifiStudioStatisticsRequest
    ) async throws -> [StudioStatisticsRow] {
        var rows: [StudioStatisticsRow] = []
        for (rowIndex, values) in request.values.enumerated() {
            for (columnIndex, value) in values.enumerated() {
                if rows.count.isMultiple(of: 1_024) { try Task.checkCancellation() }
                rows.append(
                    .init(
                        id: rows.count,
                        values: [
                            .integer(rowIndex + 1), .integer(columnIndex + 1),
                            value.map { .number($0) } ?? .undefined,
                        ]))
            }
        }
        for (rowIndex, values) in request.categories.enumerated() {
            for (columnIndex, value) in values.enumerated() {
                if rows.count.isMultiple(of: 1_024) { try Task.checkCancellation() }
                rows.append(
                    .init(
                        id: rows.count,
                        values: [
                            .integer(rowIndex + 1), .integer(columnIndex + 1),
                            value.map { .text($0) } ?? .undefined,
                        ]))
            }
        }
        return rows
    }

    func loadSyntheticExample() {
        switch operation.inputKind {
        case .series: input = "1 2 4 7 8 12"
        case .pairedSeries: input = "1 4 9 16\n0 2 6 12"
        case .groups: input = "1 2 4 7\n3 5 8 9\n6 10 11 15"
        case .counts: input = "12 8\n5 15"
        case .categories: input = "A\tA\tB\nA\tB\tB\nB\tB\tB\nA\tA\tA"
        case .ratings: input = "1 1 2\n1 2 2\n3 3 ?\n2 2 3"
        case .scalar: input = ""
        }
        if operation == .cohenKappa { input = "A\tA\nA\tB\nB\tB\nA\tA" }
        if operation == .bonferroni || operation == .benjaminiHochberg {
            input = "0,01 0,04 0,2 0,6"
        }
        parameters = .init()
        parameters.resampleCount = 200
        contrastsDraft = "1 -1 0\n0,5 0,5 -1"
        probabilitiesDraft = "0,25 0,5 0,75"
        pane = .configuration
    }

    @concurrent nonisolated static func exportData(
        for result: GlifiStudioStatisticsResult
    ) async throws -> Data {
        try Task.checkCancellation()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(result)
        try Task.checkCancellation()
        return data
    }

    private func refreshVisibleRows() {
        guard let result else {
            visibleRows = []
            return
        }
        visibleRows = filteredIndices.dropFirst(page * Self.pageSize).prefix(Self.pageSize)
            .map { StudioStatisticsRow(id: $0, values: result.rows[$0]) }
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        let token = UUID()
        filterRevision = token
        guard let result else { return }
        let query = search
        if query.isEmpty {
            filteredIndices = Array(result.rows.indices)
            matchingRowCount = result.rows.count
            page = 0
            refreshVisibleRows()
            return
        }
        filterTask = Task {
            let indices = await Self.filteredRows(result.rows, query: query)
            guard !Task.isCancelled, token == filterRevision else { return }
            filteredIndices = indices
            matchingRowCount = indices.count
            page = 0
            refreshVisibleRows()
        }
    }

    @concurrent private static func filteredRows(
        _ rows: [[GlifiStudioStatisticsValue]], query: String
    ) async -> [Int] {
        guard !query.isEmpty else { return Array(rows.indices) }
        var indices: [Int] = []
        for index in rows.indices {
            if Task.isCancelled { return [] }
            let text = rows[index].map { value in
                switch value {
                case let .number(value): String(value)
                case let .integer(value): String(value)
                case let .text(value): value
                case .positiveInfinity: "+Infinity"
                case .negativeInfinity: "-Infinity"
                case .undefined: "?"
                }
            }.joined(separator: " ")
            if text.localizedStandardContains(query) { indices.append(index) }
        }
        return indices
    }

    private static func invalidInput() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "statistics.invalid-probabilities", category: "invalidInput",
            operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }

    private static func cancelled() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "statistics.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled")
    }
}
