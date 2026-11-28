// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One explicit temporal annotation supplied by the researcher for an immutable revision.
public struct GlifiStudioTemporalAssignment: Codable, Equatable, Sendable {
    /// Immutable project source revision.
    public let sourceRevisionID: String
    /// Observed date type and precision, including an explicit missing value.
    public let value: GlifiStudioTemporalValue
    /// Researcher-supplied metadata provenance; no filename-derived date is created.
    public let provenance: String

    /// Creates an annotation without persisting it in the project.
    public init(sourceRevisionID: String, value: GlifiStudioTemporalValue, provenance: String) {
        self.sourceRevisionID = sourceRevisionID
        self.value = value
        self.provenance = provenance
    }
}

/// Temporal observations retain the exact project inputs and manual metadata used.
public struct GlifiStudioProjectTemporalEvaluation: Decodable, Sendable {
    /// Project owning the selected immutable revisions.
    public let projectID: String
    /// Project generation captured while preparing inputs.
    public let generation: Int
    /// Exact manual observations with complete lexical token exposure.
    public let documents: [GlifiStudioTemporalDocument]
    /// Original content digests aligned with `documents`.
    public let contentDigests: [String]
    /// Requested lexical keys in canonical order, without implicit normalization.
    public let selectedTerms: [String]
    /// Descriptive calendar aggregation returned by the core.
    public let result: GlifiStudioTemporalResult
    /// Exact shared lexical preparation used for the captured token exposures.
    public let preparation: GlifiStudioCorpusPreparation
    /// Versioned preparation identity captured before reading sources.
    public let preparationDigest: String
}

extension GlifiStudioProjectTemporalEvaluation {
    private enum RestoreKeys: String, CodingKey {
        case projectID, generation, documents, contentDigests, selectedTerms, result
        case preparation, preparationDigest
    }

    /// Restores captured observations and accepts the historical surface-only transport.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: RestoreKeys.self)
        let preparation =
            try fields.decodeIfPresent(
                GlifiStudioCorpusPreparation.self, forKey: .preparation) ?? .init()
        self.init(
            projectID: try fields.decode(String.self, forKey: .projectID),
            generation: try fields.decode(Int.self, forKey: .generation),
            documents: try fields.decode([GlifiStudioTemporalDocument].self, forKey: .documents),
            contentDigests: try fields.decode([String].self, forKey: .contentDigests),
            selectedTerms: try fields.decode([String].self, forKey: .selectedTerms),
            result: try fields.decode(GlifiStudioTemporalResult.self, forKey: .result),
            preparation: preparation,
            preparationDigest: try fields.decodeIfPresent(String.self, forKey: .preparationDigest)
                ?? preparation.digest())
    }
}

/// Source-aware preparation for the existing temporal and linguistic evaluation operators.
public enum GlifiStudioEvaluationWorkbench {
    /// Reads project revisions and aggregates supplied metadata without project mutations.
    @concurrent public static func temporal(
        session: GlifiStudioProjectSession,
        assignments: [GlifiStudioTemporalAssignment], terms: [String],
        configuration: GlifiStudioTemporalConfiguration
    ) async throws(GlifiStudioFailure) -> GlifiStudioProjectTemporalEvaluation {
        try checkCancellation()
        guard !assignments.isEmpty, assignments.count <= 200,
            Set(assignments.map(\.sourceRevisionID)).count == assignments.count,
            terms.count <= 1_000, Set(terms).count == terms.count,
            terms.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 4_096 }),
            assignments.allSatisfy({ !$0.provenance.isEmpty && $0.provenance.utf8.count <= 4_096 })
        else { throw inputFailure() }
        let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: assignments.map(\.sourceRevisionID),
            maximumTermCount: 1, allowsEmptyLexicon: true)
        let metadata = Dictionary(
            uniqueKeysWithValues: assignments.map { ($0.sourceRevisionID, $0) })
        let selectedTerms = terms.sorted()
        let selectedSet = Set(selectedTerms)
        var documents: [GlifiStudioTemporalDocument] = []
        for (index, id) in input.sourceRevisionIDs.enumerated() {
            try checkCancellation()
            guard let annotation = metadata[id] else { throw inputFailure() }
            var counts = Dictionary(uniqueKeysWithValues: selectedTerms.map { ($0, 0) })
            for token in input.documents[index] where selectedSet.contains(token) {
                counts[token, default: 0] += 1
            }
            documents.append(
                .init(
                    sourceRevisionID: id, metadataProvenance: annotation.provenance,
                    value: annotation.value, tokenCount: input.documents[index].count,
                    termCounts: counts))
        }
        let result = try await GlifiStudioTextAnalytics.temporalFrequencies(
            documents, configuration: configuration)
        return .init(
            projectID: input.projectID, generation: input.generation,
            documents: documents, contentDigests: input.contentDigests,
            selectedTerms: selectedTerms, result: result,
            preparation: input.preparation, preparationDigest: input.preparationDigest)
    }

    /// Evaluates supplied boundary annotations after checking scalar-aligned UTF-8 offsets.
    @concurrent public static func boundaries(
        gold: [[Int]], predicted: [[Int]], texts: [String],
        zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try checkCancellation()
        guard gold.count == texts.count, predicted.count == texts.count,
            texts.count <= 200
        else { throw inputFailure() }
        try validateTextBudget(texts)
        for index in texts.indices {
            try checkCancellation()
            let bytes = Array(texts[index].utf8)
            guard gold[index].allSatisfy({ validOffset($0, bytes: bytes) }),
                predicted[index].allSatisfy({ validOffset($0, bytes: bytes) })
            else { throw inputFailure() }
        }
        return try await GlifiStudioLinguisticEvaluation.boundaries(
            gold: gold, predicted: predicted, utf8Lengths: texts.map { $0.utf8.count },
            zeroPolicy: zeroPolicy)
    }

    /// Evaluates supplied entity spans only when each boundary is a valid UTF-8 scalar boundary.
    @concurrent public static func namedEntities(
        gold: [[GlifiStudioEvaluationEntity]], predicted: [[GlifiStudioEvaluationEntity]],
        texts: [String], zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try checkCancellation()
        guard gold.count == texts.count, predicted.count == texts.count,
            texts.count <= 200
        else { throw inputFailure() }
        try validateTextBudget(texts)
        for index in texts.indices {
            try checkCancellation()
            let bytes = Array(texts[index].utf8)
            for entities in [gold[index], predicted[index]] {
                guard entities.count <= 2_000 else { throw inputFailure() }
                for entity in entities {
                    guard validOffset(entity.lowerBound, bytes: bytes),
                        validOffset(entity.upperBound, bytes: bytes)
                    else { throw inputFailure() }
                }
            }
        }
        return try await GlifiStudioLinguisticEvaluation.namedEntities(
            gold: gold, predicted: predicted,
            utf8Lengths: texts.map { $0.utf8.count }, zeroPolicy: zeroPolicy)
    }

    private static func validOffset(_ offset: Int, bytes: [UInt8]) -> Bool {
        guard offset >= 0, offset <= bytes.count else { return false }
        return offset == bytes.count || bytes[offset] & 0xC0 != 0x80
    }

    private static func validateTextBudget(_ texts: [String]) throws(GlifiStudioFailure) {
        var remaining = 8 * 1_024 * 1_024
        for text in texts {
            try checkCancellation()
            guard text.utf8.count <= remaining else { throw inputFailure() }
            remaining -= text.utf8.count
        }
    }

    private static func checkCancellation() throws(GlifiStudioFailure) {
        guard !Task.isCancelled else {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        }
    }

    private static func inputFailure() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "evaluation.invalid-source-input", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }
}
