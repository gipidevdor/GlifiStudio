// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

extension GlifiStudioProjectSession {
    /// Stores an existing document assignment with a permanent link to its producing artifact.
    ///
    /// No labels are inferred from coordinates, posterior scores or filenames.
    public func deriveResearchVariable(
        artifactID: String, fieldID: String, label: String, expectedRevision: Int,
        clusterCount: Int? = nil
    ) async throws -> GlifiStudioResearchState {
        try await performOperation(.persistProject) {
            let saved = try await savedAnalysis(artifactID: artifactID)
            var state = try await researchState()
            guard !state.fields.contains(where: { $0.id == fieldID }),
                let envelope = try JSONSerialization.jsonObject(with: saved.resultJSON)
                    as? [String: Any],
                let result = envelope["result"] as? [String: Any]
            else { throw savedResearchFailure("research.invalid-derived-variable") }
            let labels: [String]
            var derivationOperation = "stored-document-assignments-v1"
            var derivationParameters: [String: String] = [:]
            if let assignedLabels = result["labels"] as? [String] {
                labels = assignedLabels
            } else if let assignments = result["assignments"] as? [Int],
                assignments.allSatisfy({ $0 >= 0 && $0 < Int.max })
            {
                labels = assignments.map { String($0 + 1) }
            } else if let map = result["map"] as? [String: Any],
                let assignments = map["assignments"] as? [Int],
                assignments.allSatisfy({ $0 >= 0 && $0 < Int.max })
            {
                labels = assignments.map { String($0 + 1) }
            } else if let clusterCount,
                let request = try JSONSerialization.jsonObject(with: saved.requestJSON)
                    as? [String: Any],
                request["operation"] as? String == "hierarchical",
                let children = result["children"] as? [[Int]],
                let heights = result["heights"] as? [Double],
                let sizes = result["sizes"] as? [Int],
                let linkage = result["linkage"] as? String,
                children.count == heights.count, heights.count == sizes.count,
                children.allSatisfy({ $0.count == 2 })
            {
                let merges: [[String: Any]] = children.indices.map { index in
                    [
                        "first": children[index][0], "second": children[index][1],
                        "height": heights[index], "size": sizes[index],
                    ]
                }
                let data = try JSONSerialization.data(withJSONObject: [
                    "linkage": linkage, "merges": merges,
                ])
                let tree = try JSONDecoder().decode(GlifiHierarchicalClustering.self, from: data)
                derivationOperation = "hac-cut-v1"
                derivationParameters = ["clusterCount": String(clusterCount)]
                labels = try GlifiMultivariateMethods.cut(
                    tree, pointCount: saved.resultSourceRevisionIDs.count,
                    clusterCount: clusterCount
                ).map { String($0 + 1) }
            } else {
                throw savedResearchFailure("research.result-has-no-assignments")
            }
            guard !labels.isEmpty, labels.count == saved.resultSourceRevisionIDs.count,
                labels.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 4_096 })
            else { throw savedResearchFailure("research.assignment-scope-mismatch") }
            state.fields.append(
                .init(
                    id: fieldID, label: label, type: .text,
                    derivation: .init(
                        artifactID: artifactID,
                        operationIdentifier: derivationOperation, parameters: derivationParameters))
            )
            for (sourceID, value) in zip(saved.resultSourceRevisionIDs, labels) {
                if let index = state.records.firstIndex(where: { $0.sourceRevisionID == sourceID })
                {
                    state.records[index].values[fieldID] = .text(value)
                    state.records[index].derivationArtifactID = artifactID
                    var derivations = state.records[index].derivationArtifactIDs ?? [:]
                    derivations[fieldID] = artifactID
                    state.records[index].derivationArtifactIDs = derivations
                } else {
                    state.records.append(
                        .init(
                            sourceRevisionID: sourceID, values: [fieldID: .text(value)],
                            derivationArtifactID: artifactID,
                            derivationArtifactIDs: [fieldID: artifactID]))
                }
            }
            return try await saveResearchState(state, expectedRevision: expectedRevision)
        }
    }
}
