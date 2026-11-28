// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Immutable project inputs for the exploratory, in-memory laboratory.
///
/// The vocabulary is selected by decreasing corpus frequency, with lexical ties,
/// then stored lexicographically. Documents retain their complete lexical tokens;
/// the term cap applies only to the dense exploratory matrix.
public struct GlifiStudioProjectTextAnalysisInput: Codable, Equatable, Sendable {
    /// Project that owns the immutable revisions.
    public let projectID: String
    /// Project generation captured before reading the selected revisions.
    public let generation: Int
    /// Selected revision identities in canonical order.
    public let sourceRevisionIDs: [String]
    /// Original-content digests aligned with the revision identities.
    public let contentDigests: [String]
    /// Complete normalized lexical token sequences, aligned with the revisions.
    public let documents: [[String]]
    /// Extracted text units used by the automatic coding operators.
    public let codingUnits: [GlifiStudioAutomaticCodingUnit]
    /// Selected matrix vocabulary in lexical order.
    public let terms: [String]
    /// Complete vocabulary size before the explicit matrix term limit.
    public let vocabularySize: Int
    /// Document-by-term raw counts, aligned with revisions and selected terms.
    public let matrix: [[Double]]
    /// Complete lexical token count across the selected revisions.
    public let lexicalTokenCount: Int
    /// Canonical identity of the shared preparation captured before tokenization.
    public let preparationDigest: String
    /// Resolved dictionary and linguistic settings captured for later restoration.
    public let preparation: GlifiStudioCorpusPreparation
}

extension GlifiStudioTextAnalytics {
    /// Explicit client bounds, checked before decoding and before dense allocation.
    public static let projectLaboratoryMaximumSources = 200
    /// Maximum combined source bytes accepted by the session laboratory.
    public static let projectLaboratoryMaximumBytes = 8 * 1_024 * 1_024
    /// Maximum complete lexical token count accepted by the session laboratory.
    public static let projectLaboratoryMaximumTokens = 100_000
    /// Maximum selected vocabulary size of the dense exploratory matrix.
    public static let projectLaboratoryMaximumTerms = 1_000

    /// Reads immutable project revisions, using the product's importer and Italian tokenizer.
    ///
    /// No new Artifact or persistent representation is created.
    /// `allowsEmptyLexicon` preserves zero-token observations for descriptive temporal rates;
    /// exploratory numerical callers retain the default rejection of an empty vocabulary.
    @concurrent public static func prepareProjectInput(
        session: GlifiStudioProjectSession,
        sourceRevisionIDs: [String],
        maximumTermCount: Int = 200,
        allowsEmptyLexicon: Bool = false
    ) async throws(GlifiStudioFailure) -> GlifiStudioProjectTextAnalysisInput {
        do {
            try await session.ensureOpen(operation: .analyze)
            let snapshot = try await session.snapshot()
            let selected = Set(sourceRevisionIDs)
            guard !selected.isEmpty, selected.count == sourceRevisionIDs.count,
                selected.count <= projectLaboratoryMaximumSources,
                (1...projectLaboratoryMaximumTerms).contains(maximumTermCount)
            else { throw projectInputFailure() }
            let sources = snapshot.sources.filter { selected.contains($0.sourceRevisionID) }
                .sorted { $0.sourceRevisionID < $1.sourceRevisionID }
            guard sources.count == selected.count else { throw projectInputFailure() }
            var byteCount = 0
            for source in sources {
                guard source.byteCount <= projectLaboratoryMaximumBytes - byteCount else {
                    throw projectInputFailure(resource: true)
                }
                byteCount += source.byteCount
            }

            let research = try await GlifiStudioResearchState(session.project.researchState())
            let preparation = try research.preparation.core()
            let preparationDigest = try research.preparation.digest()
            var documents: [[String]] = []
            var units: [GlifiStudioAutomaticCodingUnit] = []
            var frequencies: [String: Int] = [:]
            var tokenCount = 0
            for source in sources {
                try Task.checkCancellation()
                let imported = try await session.importedTextForLaboratory(
                    sourceRevisionID: source.sourceRevisionID,
                    maximumByteCount: projectLaboratoryMaximumBytes - byteCount + source.byteCount)
                let extraBytes = imported.analysisByteCount - source.byteCount
                guard extraBytes <= projectLaboratoryMaximumBytes - byteCount else {
                    throw projectInputFailure(resource: true)
                }
                byteCount += extraBytes
                guard imported.contentDigest == source.contentDigest else {
                    throw projectInputFailure()
                }
                let variables = research.codingVariables(sourceRevisionID: source.sourceRevisionID)
                let document = try preparation.prepare(
                    text: imported.text, id: source.sourceRevisionID, variables: variables)
                guard document.tokens.count <= projectLaboratoryMaximumTokens - tokenCount else {
                    throw projectInputFailure(resource: true)
                }
                tokenCount += document.tokens.count
                let tokens = document.tokens.map(\.base)
                documents.append(tokens)
                units.append(
                    GlifiStudioAutomaticCodingUnit(
                        id: source.sourceRevisionID, text: imported.text, variables: variables)
                )
                for token in tokens { frequencies[token, default: 0] += 1 }
            }
            guard allowsEmptyLexicon || tokenCount > 0 else { throw projectInputFailure() }
            let terms = frequencies.keys.sorted {
                let first = frequencies[$0] ?? 0
                let second = frequencies[$1] ?? 0
                return first == second ? $0 < $1 : first > second
            }.prefix(maximumTermCount).sorted()
            let indices = Dictionary(uniqueKeysWithValues: terms.enumerated().map { ($1, $0) })
            var matrix = Array(
                repeating: Array(repeating: 0.0, count: terms.count), count: documents.count)
            for (row, tokens) in documents.enumerated() {
                try Task.checkCancellation()
                for token in tokens {
                    if let column = indices[token] { matrix[row][column] += 1 }
                }
            }
            return GlifiStudioProjectTextAnalysisInput(
                projectID: snapshot.projectID, generation: snapshot.generation,
                sourceRevisionIDs: sources.map(\.sourceRevisionID),
                contentDigests: sources.map(\.contentDigest), documents: documents,
                codingUnits: units, terms: terms, vocabularySize: frequencies.count,
                matrix: matrix, lexicalTokenCount: tokenCount,
                preparationDigest: preparationDigest, preparation: research.preparation)
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch is CancellationError {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        } catch {
            throw projectInputFailure()
        }
    }
}

private func projectInputFailure(resource: Bool = false) -> GlifiStudioFailure {
    GlifiStudioFailure(
        code: resource ? "exploratory.resource-limit" : "text-analysis.invalid-request",
        category: resource ? "insufficientResources" : "invalidInput", operation: "analyze",
        retryDisposition: "afterCorrection", retainedState: "unchanged",
        messageKey: resource
            ? "failure.category.insufficientResources" : "failure.category.invalidInput"
    )
}
