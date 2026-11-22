// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated struct StudioOperatorRow: Identifiable, Sendable {
    let id: Int
    let values: [GlifiStudioOperatorCell]
}

/// Session ownership of explicit operator inputs and immutable, paged results.
@MainActor @Observable final class StudioOperatorsModel {
    var request = GlifiStudioCoreOperatorRequest()
    private(set) var result: GlifiStudioCoreOperatorResult?
    var selectedTable = 0
    var page = 0
    let pageSize = 50
    private var revision = UUID()

    var table: GlifiStudioOperatorTable? {
        guard let result, result.tables.indices.contains(selectedTable) else { return nil }
        return result.tables[selectedTable]
    }

    var pageCount: Int { max(1, ((table?.rows.count ?? 0) + pageSize - 1) / pageSize) }

    var visibleRows: [StudioOperatorRow] {
        (table?.rows ?? []).dropFirst(page * pageSize).prefix(pageSize).enumerated().map {
            StudioOperatorRow(id: page * pageSize + $0.offset, values: $0.element)
        }
    }

    func execute() async throws {
        let token = revision
        let next = try await GlifiStudioCoreOperators.execute(request)
        guard revision == token, !Task.isCancelled else {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        }
        result = next
        selectedTable = 0
        page = 0
    }

    func reset() {
        revision = UUID()
        request = GlifiStudioCoreOperatorRequest()
        result = nil
        selectedTable = 0
        page = 0
    }

    func showPage(_ value: Int) {
        guard value >= 0, value < pageCount else { return }
        page = value
    }

    func loadSyntheticExample() {
        request.numbers = "1 2\n2 1\n4 5\n5 4"
        if request.operation.family == "similarity" {
            request.numbers = request.operation == .lidstone ? "1 2 3" : "0,2 0,3 0,5\n0,3 0,3 0,4"
        }
        request.nodes = "A\nB\nC"
        request.firstSet = "casa mare sole"
        request.secondSet = "casa libro sole"
        request.edges = "A\tB\t2\nB\tC\t1\nC\tA\t1"
        request.documents = "casa mare casa sole\nmare libro casa libro sole"
        request.assignments = request.operation.family == "graph" ? "0 0 1" : "0 0 1 1"
        request.checkpoints = "1 3 6 9"
        request.firstRank = 1
        request.lastRank = nil
    }
}
