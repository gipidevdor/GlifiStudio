// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit

nonisolated enum StudioVisualExportKind: Sendable {
    case csv
    case json
    case provenance(projectID: String, generation: Int)
}

nonisolated enum StudioPreparedVisualExport: Sendable {
    case text(String, isJSON: Bool)
    case files([String: Data])
}

nonisolated enum StudioVisualExportPreparation {
    @concurrent static func prepare(
        _ visualization: GlifiStudioVisualization, kind: StudioVisualExportKind
    ) async throws -> StudioPreparedVisualExport {
        try Task.checkCancellation()
        let result: StudioPreparedVisualExport
        switch kind {
        case .csv:
            result = .text(GlifiStudioVisualizationBuilder.csv(visualization), isJSON: false)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(visualization)
            result = .text(String(decoding: data, as: UTF8.self) + "\n", isJSON: true)
        case let .provenance(projectID, generation):
            let files = try GlifiStudioVisualExport.bundle(
                visualization, projectID: projectID, generation: generation, createdAt: Date())
            _ = try GlifiStudioVisualExport.verify(files)
            result = .files(files)
        }
        try Task.checkCancellation()
        return result
    }
}
