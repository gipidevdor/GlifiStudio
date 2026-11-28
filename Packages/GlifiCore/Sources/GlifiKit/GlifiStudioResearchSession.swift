// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

extension GlifiStudioProjectSession {
    /// Restores authoritative variables, named source subsets and Italian lexical settings.
    public func researchState() async throws -> GlifiStudioResearchState {
        try await performOperation(.persistProject) {
            try await GlifiStudioResearchState(project.researchState())
        }
    }

    /// Appends an immutable revision without overwriting another editor's committed state.
    @discardableResult
    public func saveResearchState(
        _ state: GlifiStudioResearchState, expectedRevision: Int
    ) async throws -> GlifiStudioResearchState {
        try await performOperation(.persistProject) {
            try await GlifiStudioResearchState(
                project.saveResearchState(state.core(), expectedRevision: expectedRevision))
        }
    }

    /// Combines typed variables and reusable subsets with a bounded textual query.
    public func selectResearchSources(_ filter: GlifiStudioResearchFilter) async throws -> [String]
    {
        try await performOperation(.query) {
            let snapshot = await project.snapshot()
            let state = try await project.researchState()
            let metadataSelected = try filter.core().select(
                from: state,
                sourceRevisionIDs: snapshot.sources.map {
                    $0.sourceRevisionID.canonicalValue
                })
            guard let text = filter.query,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return metadataSelected }
            let tokenizer: any GlifiTokenizing =
                state.preparation.isIdentity
                ? GlifiItalianTokenizer()
                : try GlifiPreparedCorpusTokenizer(preparation: state.preparation)
            let ast = try GlifiQueryParser(tokenizer: tokenizer).parse(text)
            var selected: [String] = []
            var scannedBytes = 0
            for sourceID in metadataSelected {
                try Task.checkCancellation()
                let imported = try await project.importedText(
                    for: SourceRevisionID(canonicalValue: sourceID),
                    limits: GlifiTextImportLimits(
                        maximumByteCount: 64 * 1_024 * 1_024 - scannedBytes,
                        maximumExtractedByteCount: 64 * 1_024 * 1_024 - scannedBytes))
                guard imported.analysisByteCount <= 64 * 1_024 * 1_024 - scannedBytes else {
                    throw researchFailure(
                        "research.query-byte-limit", category: .insufficientResources)
                }
                scannedBytes += imported.analysisByteCount
                let result = try GlifiQueryEvaluator().evaluate(
                    ast, in: imported, tokenization: tokenizer.tokenize(imported.text))
                if result.matchedScope { selected.append(sourceID) }
            }
            return selected
        }
    }
}
