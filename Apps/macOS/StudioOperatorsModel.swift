// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated struct StudioOperatorRow: Identifiable, Sendable {
    let id: Int
    let values: [GlifiStudioOperatorCell]
}

nonisolated struct StudioOperatorGraphPoint: Identifiable, Sendable {
    let id: String
    let x: Double
    let y: Double
}

nonisolated struct StudioOperatorGraphEdge: Identifiable, Sendable {
    let id: Int
    let source: StudioOperatorGraphPoint
    let target: StudioOperatorGraphPoint
}

nonisolated struct StudioOperatorGraphPreview: Sendable {
    let points: [StudioOperatorGraphPoint]
    let edges: [StudioOperatorGraphEdge]
    let domain: ClosedRange<Double>
}

/// Session ownership of explicit operator inputs and immutable, paged results.
@MainActor @Observable final class StudioOperatorsModel {
    var request = GlifiStudioCoreOperatorRequest()
    private(set) var result: GlifiStudioCoreOperatorResult?
    private(set) var completedAt: Date?
    private(set) var graphPreview: StudioOperatorGraphPreview?
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
        let preview = await Self.projectGraph(next)
        guard revision == token, !Task.isCancelled else {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        }
        result = next
        completedAt = .now
        graphPreview = preview
        selectedTable = 0
        page = 0
    }

    func reset() {
        revision = UUID()
        request = GlifiStudioCoreOperatorRequest()
        result = nil
        completedAt = nil
        graphPreview = nil
        selectedTable = 0
        page = 0
    }

    nonisolated private struct Archive: Codable, Sendable {
        let client: String
        let version: Int
        let result: GlifiStudioCoreOperatorResult
        let completedAt: Date
    }

    func archiveData() async throws -> Data {
        let expected = revision
        guard let result, let completedAt else { throw StudioWorkbenchArchiveCodec.failure() }
        let bytes = try await StudioWorkbenchArchiveCodec.encode(
            Archive(
                client: "operators", version: 1, result: result, completedAt: completedAt))
        try Task.checkCancellation()
        guard revision == expected else { throw CancellationError() }
        return bytes
    }

    func saveArchive(session: GlifiStudioProjectSession, title: String) async throws
        -> GlifiStudioSavedAnalysis
    {
        guard let result, let completedAt else { throw StudioWorkbenchArchiveCodec.failure() }
        let presentation = try await archiveData()
        return try await session.captureWorkbenchAnalysis(
            command: "operator", requestJSON: StudioWorkbenchArchiveCodec.encode(result.request),
            resultJSON: StudioWorkbenchArchiveCodec.encode(result),
            methodIdentifier: result.methodIdentifiers.joined(separator: " + "), title: title,
            presentationJSON: presentation,
            createdAtUnixMilliseconds: Int64(completedAt.timeIntervalSince1970 * 1_000))
    }

    @concurrent private static func decodeArchive(_ data: Data, saved: GlifiStudioSavedAnalysis)
        async throws -> (Archive, StudioOperatorGraphPreview?)
    {
        try Task.checkCancellation()
        guard data.count <= 8 * 1_048_576 else { throw StudioWorkbenchArchiveCodec.failure() }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.client == "operators", archive.version == 1 else {
            throw StudioWorkbenchArchiveCodec.failure()
        }
        try StudioWorkbenchArchiveCodec.validate(
            saved: saved, command: "operator", request: archive.result.request,
            result: archive.result,
            method: archive.result.methodIdentifiers.joined(separator: " + "))
        return (archive, await projectGraph(archive.result))
    }

    func restoreArchive(_ data: Data, saved: GlifiStudioSavedAnalysis) async throws {
        let expected = UUID()
        revision = expected
        let (archive, preview) = try await Self.decodeArchive(data, saved: saved)
        try Task.checkCancellation()
        guard revision == expected else { throw CancellationError() }
        reset()
        request = archive.result.request
        result = archive.result
        completedAt = archive.completedAt
        graphPreview = preview
    }

    func showPage(_ value: Int) {
        guard value >= 0, value < pageCount else { return }
        page = value
    }

    @concurrent private static func projectGraph(_ result: GlifiStudioCoreOperatorResult) async
        -> StudioOperatorGraphPreview?
    {
        guard result.request.operation == .graphLayout,
            let positions = result.tables.first(where: { $0.titleKey == "operators.positions" })
        else { return nil }
        let points = positions.rows.compactMap { row -> StudioOperatorGraphPoint? in
            guard row.count == 3, case let .text(id) = row[0], case let .number(x) = row[1],
                case let .number(y) = row[2], x.isFinite, y.isFinite
            else { return nil }
            return .init(id: id, x: x, y: y)
        }
        guard points.count == positions.rows.count, Set(points.map(\.id)).count == points.count
        else { return nil }
        let indices = Dictionary(
            uniqueKeysWithValues: points.enumerated().map { ($0.element.id, $0.offset) })
        var seen = Set<String>()
        var edges: [StudioOperatorGraphEdge] = []
        for row in result.tables.first(where: { $0.titleKey == "operators.layout-edges" })?.rows
            ?? []
        {
            if Task.isCancelled { return nil }
            guard row.count == 3, case let .text(source) = row[0], case let .text(target) = row[1],
                let first = indices[source], let second = indices[target], first != second
            else { continue }
            let key = "\(min(first, second)):\(max(first, second))"
            if seen.insert(key).inserted {
                edges.append(.init(id: edges.count, source: points[first], target: points[second]))
            }
        }
        guard edges.count <= 512 else { return nil }
        let extent = max(1, points.reduce(0) { max($0, max(abs($1.x), abs($1.y))) })
        let radius = extent <= Double.greatestFiniteMagnitude / 1.1 ? extent * 1.1 : extent
        return .init(points: points, edges: edges, domain: -radius...radius)
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
        if request.operation == .graphLayout {
            request.numbers = "-1 0\n1 0\n0 1"
            request.maximumIterations = 300
            request.tolerance = 1e-6
        }
        request.firstRank = 1
        request.lastRank = nil
    }
}
