// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit

/// Shares the plot's first-seen style assignment with its legend and point selection.
nonisolated struct StudioPlotSeries: Sendable {
    let points: [GlifiStudioVisualMark]
    let pointSeries: [String]
    private let styleIndices: [String: Int]

    init(_ marks: [GlifiStudioVisualMark]) {
        var indices: [String: Int] = [:]
        var names: [String] = []
        var pointNames = Set<String>()
        var points: [GlifiStudioVisualMark] = []
        for mark in marks {
            if indices[mark.series] == nil {
                indices[mark.series] = names.count
                names.append(mark.series)
            }
            if mark.kind == .point {
                points.append(mark)
                pointNames.insert(mark.series)
            }
        }
        self.points = points
        pointSeries = names.filter(pointNames.contains)
        styleIndices = indices
    }

    func styleIndex(for series: String) -> Int? {
        styleIndices[series]
    }
}

/// A folded branch keeps the original merge as its selectable lineage datum.
nonisolated struct StudioDendrogramBranch: Sendable {
    let mark: GlifiStudioVisualMark
    let leafCount: Int
    let minimumX: Double
    let maximumX: Double
    let rootX: Double
    let rootHeight: Double
}

/// Chart-only folding leaves the complete table, tree and export available.
nonisolated struct StudioDendrogramPresentation: Sendable {
    let visualization: GlifiStudioVisualization
    let marks: [GlifiStudioVisualMark]
    let branch: StudioDendrogramBranch?

    static func isMergeID(_ identifier: String?) -> Bool {
        mergeStep(identifier) != nil
    }

    private static func mergeStep(_ identifier: String?) -> Int? {
        guard let identifier else { return nil }
        let parts = identifier.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "merge", parts[2] == "bridge",
            let step = Int(parts[1]), step > 0
        else { return nil }
        return step - 1
    }

    @concurrent static func prepare(
        _ visualization: GlifiStudioVisualization,
        clusterCount: Int? = nil, height: Double? = nil, collapsedMarkID: String? = nil
    ) async throws -> StudioDendrogramPresentation {
        try Task.checkCancellation()
        let view: GlifiStudioVisualization
        if clusterCount != nil || height != nil {
            view = try GlifiStudioVisualizationBuilder.recutDendrogram(
                visualization, clusterCount: clusterCount, height: height)
        } else {
            view = visualization
        }
        guard let collapsedMarkID else {
            return Self(visualization: view, marks: view.marks, branch: nil)
        }
        guard let tree = view.dendrogramTree, let step = mergeStep(collapsedMarkID),
            tree.merges.indices.contains(step),
            let bridge = view.marks.first(where: { $0.id == collapsedMarkID }),
            bridge.kind == .segment, let endX = bridge.x2
        else { throw StudioDendrogramPresentationFailure.invalidBranch }
        let leafCount = tree.leafIdentifiers.count
        var hidden = Set<String>()
        var leafIDs = Set<String>()
        var pending = [leafCount + step]
        while let node = pending.popLast() {
            try Task.checkCancellation()
            guard node >= 0 else { throw StudioDendrogramPresentationFailure.invalidBranch }
            if node < leafCount {
                let id = "leaf:\(tree.leafIdentifiers[node])"
                guard leafIDs.insert(id).inserted else {
                    throw StudioDendrogramPresentationFailure.invalidBranch
                }
                hidden.insert(id)
            } else {
                let mergeIndex = node - leafCount
                guard tree.merges.indices.contains(mergeIndex) else {
                    throw StudioDendrogramPresentationFailure.invalidBranch
                }
                let merge = tree.merges[mergeIndex]
                guard merge.first >= 0, merge.second >= 0,
                    merge.first < node, merge.second < node, merge.first != merge.second
                else { throw StudioDendrogramPresentationFailure.invalidBranch }
                for part in ["first", "second", "bridge"] {
                    hidden.insert("merge:\(mergeIndex + 1):\(part)")
                }
                pending.append(merge.first)
                pending.append(merge.second)
            }
        }
        let leaves = view.marks.filter { leafIDs.contains($0.id) && $0.kind == .point }
        guard leaves.count == leafIDs.count,
            let minimumX = leaves.map(\.x).min(), let maximumX = leaves.map(\.x).max()
        else { throw StudioDendrogramPresentationFailure.invalidBranch }
        let branch = StudioDendrogramBranch(
            mark: bridge, leafCount: leaves.count, minimumX: minimumX, maximumX: maximumX,
            rootX: bridge.x / 2 + endX / 2, rootHeight: bridge.y)
        let marks = view.marks.filter { !hidden.contains($0.id) }
        try Task.checkCancellation()
        return Self(visualization: view, marks: marks, branch: branch)
    }
}

nonisolated private enum StudioDendrogramPresentationFailure: Error {
    case invalidBranch
}
