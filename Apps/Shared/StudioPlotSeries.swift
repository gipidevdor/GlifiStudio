// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit

/// Shares the plot's first-seen style assignment with its legend and point selection.
nonisolated struct StudioPlotSeries {
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
