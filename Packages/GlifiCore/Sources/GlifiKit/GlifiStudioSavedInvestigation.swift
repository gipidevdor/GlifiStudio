// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

extension GlifiStudioProjectSession {
    /// Creates an Italian investigation that describes the saved output and preserves its caveats.
    public func createSavedAnalysisInvestigation(
        artifactID: String, question: String
    ) async throws -> GlifiStudioInvestigationResult {
        try await performOperation(.investigate) {
            _ = try await savedAnalysis(artifactID: artifactID)
            return try await GlifiStudioInvestigationResult(
                engine.createSavedAnalysisInvestigation(
                    in: project, artifactID: ArtifactID(canonicalValue: artifactID),
                    question: question))
        }
    }
}
