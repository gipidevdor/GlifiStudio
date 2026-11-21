// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Application-facing zero-denominator policy for linguistic metrics.
public enum GlifiStudioEvaluationZeroPolicy: String, Codable, Sendable {
    /// Preserve undefined metrics as nil, propagating them through affected averages.
    case undefined
    /// Resolve undefined metrics to zero.
    case zero

    var core: GlifiEvaluationZeroPolicy {
        switch self {
        case .undefined: .undefined
        case .zero: .zero
        }
    }
}

/// Exact-match counts and precision, recall, F1 in the application-facing contract.
public struct GlifiStudioEvaluationScore: Codable, Equatable, Sendable {
    /// Correct predictions.
    public let truePositiveCount: Int
    /// Unmatched predictions.
    public let falsePositiveCount: Int
    /// Unmatched gold annotations.
    public let falseNegativeCount: Int
    /// Precision; nil when undefined under the selected policy.
    public let precision: Double?
    /// Recall; nil when undefined under the selected policy.
    public let recall: Double?
    /// F1 from counts; nil when undefined under the selected policy.
    public let f1: Double?

    init(_ value: GlifiEvaluationScore) {
        truePositiveCount = value.truePositiveCount
        falsePositiveCount = value.falsePositiveCount
        falseNegativeCount = value.falseNegativeCount
        precision = value.precision
        recall = value.recall
        f1 = value.f1
    }
}

/// Aligned exact observation accuracy.
public struct GlifiStudioEvaluationAccuracy: Codable, Equatable, Sendable {
    /// Number of aligned observations.
    public let observationCount: Int
    /// Exactly matching observations.
    public let correctCount: Int
    /// Exact accuracy under the selected zero-denominator policy.
    public let accuracy: Double?

    init(_ value: GlifiEvaluationAccuracy) {
        observationCount = value.observationCount
        correctCount = value.correctCount
        accuracy = value.accuracy
    }
}

/// Exact lemma errors grouped by a supplied gold surface form or POS label.
public struct GlifiStudioEvaluationErrorGroup: Codable, Equatable, Sendable {
    /// Group label in canonical output order.
    public let label: String
    /// Gold token count.
    public let observationCount: Int
    /// Incorrect lemma count.
    public let errorCount: Int

    init(_ value: GlifiEvaluationErrorGroup) {
        label = value.label
        observationCount = value.observationCount
        errorCount = value.errorCount
    }
}

/// Canonically ordered one-vs-rest class or attribute result.
public struct GlifiStudioEvaluationClassScore: Codable, Equatable, Sendable {
    /// Class label or morphological attribute.
    public let label: String
    /// Number of gold observations for this label.
    public let support: Int
    /// Exact class or attribute-value score.
    public let score: GlifiStudioEvaluationScore

    init(_ value: GlifiEvaluationClassScore) {
        label = value.label
        support = value.support
        score = GlifiStudioEvaluationScore(value.score)
    }
}

/// Separately averaged class precision, recall and F1.
public struct GlifiStudioEvaluationAverage: Codable, Equatable, Sendable {
    /// Average precision.
    public let precision: Double?
    /// Average recall.
    public let recall: Double?
    /// Average class F1.
    public let f1: Double?

    init(_ value: GlifiEvaluationAverage) {
        precision = value.precision
        recall = value.recall
        f1 = value.f1
    }
}

/// A half-open entity annotation in UTF-8 bytes of its enclosing document.
public struct GlifiStudioEvaluationEntity: Codable, Equatable, Sendable {
    /// Inclusive byte start.
    public let lowerBound: Int
    /// Exclusive byte end.
    public let upperBound: Int
    /// Exact entity type.
    public let type: String

    /// Creates an entity annotation, validated when evaluated.
    public init(lowerBound: Int, upperBound: Int, type: String) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.type = type
    }

    var core: GlifiEvaluationEntity {
        GlifiEvaluationEntity(lowerBound: lowerBound, upperBound: upperBound, type: type)
    }
}

/// Linguistic evaluation result independent of Core representations.
///
/// Only the fields applicable to `methodIdentifier` are populated. Classification includes
/// all averages and confusion counts; boundary matching includes boundary/unit scores;
/// NER includes untyped/typed spans; morphology includes accuracy and attribute scores.
public struct GlifiStudioLinguisticEvaluationResult: Codable, Equatable, Sendable {
    /// Fully resolved numerical variant.
    public let methodIdentifier: String
    /// Recorded undefined metric handling.
    public let zeroPolicy: GlifiStudioEvaluationZeroPolicy
    /// Exact token, document or morphology-set accuracy when applicable.
    public let accuracy: GlifiStudioEvaluationAccuracy?
    /// Label order for confusion counts.
    public let labels: [String]
    /// Gold rows by predicted columns; empty for non-classification methods.
    public let confusionMatrix: [[Int]]
    /// Class or morphological attribute results in canonical order.
    public let perClass: [GlifiStudioEvaluationClassScore]
    /// Classification micro score or untyped boundary/span score.
    public let score: GlifiStudioEvaluationScore?
    /// Boundary-derived exact unit score or typed NER span score.
    public let exactUnitScore: GlifiStudioEvaluationScore?
    /// Classification macro average.
    public let macro: GlifiStudioEvaluationAverage?
    /// Classification gold-support-weighted average.
    public let weighted: GlifiStudioEvaluationAverage?
    /// Lemma errors grouped by gold surface form when supplied.
    public let errorsByForm: [GlifiStudioEvaluationErrorGroup]
    /// Lemma errors grouped by gold POS when supplied.
    public let errorsByPartOfSpeech: [GlifiStudioEvaluationErrorGroup]

    init(
        method: String, policy: GlifiStudioEvaluationZeroPolicy,
        accuracy: GlifiEvaluationAccuracy? = nil, labels: [String] = [], confusion: [[Int]] = [],
        classes: [GlifiEvaluationClassScore] = [], score: GlifiEvaluationScore? = nil,
        exactUnits: GlifiEvaluationScore? = nil, macro: GlifiEvaluationAverage? = nil,
        weighted: GlifiEvaluationAverage? = nil,
        forms: [GlifiEvaluationErrorGroup] = [], partsOfSpeech: [GlifiEvaluationErrorGroup] = []
    ) {
        methodIdentifier = method
        zeroPolicy = policy
        self.accuracy = accuracy.map(GlifiStudioEvaluationAccuracy.init)
        self.labels = labels
        confusionMatrix = confusion
        perClass = classes.map(GlifiStudioEvaluationClassScore.init)
        self.score = score.map(GlifiStudioEvaluationScore.init)
        exactUnitScore = exactUnits.map(GlifiStudioEvaluationScore.init)
        self.macro = macro.map(GlifiStudioEvaluationAverage.init)
        self.weighted = weighted.map(GlifiStudioEvaluationAverage.init)
        errorsByForm = forms.map(GlifiStudioEvaluationErrorGroup.init)
        errorsByPartOfSpeech = partsOfSpeech.map(GlifiStudioEvaluationErrorGroup.init)
    }
}

/// Linguistic quality metrics on caller-supplied aligned gold observations (GS-MET-001-18).
public enum GlifiStudioLinguisticEvaluation {
    /// This library contract has not been promoted through the full scientific validation protocol.
    public static let validationStatus = "candidate"

    /// Evaluates exact POS or other single-label predictions off the caller's actor.
    @concurrent public static func classification(
        gold: [String], predicted: [String],
        zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try mapEvaluationFailure {
            let value = try GlifiLinguisticEvaluation.classification(
                gold: gold, predicted: predicted, zeroPolicy: zeroPolicy.core)
            return GlifiStudioLinguisticEvaluationResult(
                method: GlifiLinguisticClassificationEvaluation.identifier, policy: zeroPolicy,
                accuracy: value.accuracy, labels: value.labels, confusion: value.confusionMatrix,
                classes: value.perClass, score: value.micro, macro: value.macro,
                weighted: value.weighted)
        }
    }

    /// Evaluates exact lemma accuracy on aligned gold tokens off the caller's actor.
    @concurrent public static func lemmas(
        gold: [String], predicted: [String], forms: [String]? = nil, partsOfSpeech: [String]? = nil,
        zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try mapEvaluationFailure {
            let value = try GlifiLinguisticEvaluation.lemmaAnalysis(
                gold: gold, predicted: predicted, forms: forms, partsOfSpeech: partsOfSpeech,
                zeroPolicy: zeroPolicy.core)
            return GlifiStudioLinguisticEvaluationResult(
                method: GlifiLemmaEvaluation.identifier, policy: zeroPolicy,
                accuracy: value.accuracy,
                forms: value.errorsByForm, partsOfSpeech: value.errorsByPartOfSpeech)
        }
    }

    /// Evaluates boundary positions and derived units in aligned UTF-8 documents.
    @concurrent public static func boundaries(
        gold: [[Int]], predicted: [[Int]], utf8Lengths: [Int],
        zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try mapEvaluationFailure {
            let value = try GlifiLinguisticEvaluation.boundaries(
                gold: gold, predicted: predicted, utf8Lengths: utf8Lengths,
                zeroPolicy: zeroPolicy.core)
            return GlifiStudioLinguisticEvaluationResult(
                method: GlifiBoundaryEvaluation.identifier, policy: zeroPolicy,
                accuracy: value.documents, score: value.boundaries, exactUnits: value.units)
        }
    }

    /// Evaluates exact untyped and typed entity spans off the caller's actor.
    @concurrent public static func namedEntities(
        gold: [[GlifiStudioEvaluationEntity]], predicted: [[GlifiStudioEvaluationEntity]],
        utf8Lengths: [Int],
        zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try mapEvaluationFailure {
            try validateEntityConversion(gold, predicted)
            let value = try GlifiLinguisticEvaluation.namedEntities(
                gold: gold.map { $0.map(\.core) },
                predicted: predicted.map { $0.map(\.core) }, utf8Lengths: utf8Lengths,
                zeroPolicy: zeroPolicy.core)
            return GlifiStudioLinguisticEvaluationResult(
                method: GlifiNamedEntityEvaluation.identifier, policy: zeroPolicy,
                score: value.spans, exactUnits: value.typedSpans)
        }
    }

    /// Evaluates exact morphology feature sets and attribute values off the caller's actor.
    @concurrent public static func morphology(
        gold: [[String: String]], predicted: [[String: String]],
        zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticEvaluationResult {
        try mapEvaluationFailure {
            let value = try GlifiLinguisticEvaluation.morphology(
                gold: gold, predicted: predicted, zeroPolicy: zeroPolicy.core)
            return GlifiStudioLinguisticEvaluationResult(
                method: GlifiMorphologyEvaluation.identifier, policy: zeroPolicy,
                accuracy: value.exactSets, classes: value.perAttribute)
        }
    }
}

private func validateEntityConversion(
    _ gold: [[GlifiStudioEvaluationEntity]], _ predicted: [[GlifiStudioEvaluationEntity]]
) throws {
    let limit = GlifiLinguisticEvaluation.maximumObservationCount
    var remainingBytes = GlifiLinguisticEvaluation.maximumTextByteCount
    guard gold.count == predicted.count else {
        throw GlifiFailure(
            code: "evaluation.alignment-mismatch", category: .invalidInput, operation: .analyze,
            retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
            messageKey: "failure.category.invalidInput")
    }
    for documents in [gold, predicted] {
        guard documents.count <= limit else {
            throw GlifiFailure(
                code: "evaluation.limit-exceeded", category: .invalidInput, operation: .analyze,
                retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
                messageKey: "failure.category.invalidInput")
        }
        var total = 0
        for (index, annotations) in documents.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            guard annotations.count <= limit - total else {
                throw GlifiFailure(
                    code: "evaluation.limit-exceeded", category: .invalidInput, operation: .analyze,
                    retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
                    messageKey: "failure.category.invalidInput")
            }
            total += annotations.count
            for (entityIndex, entity) in annotations.enumerated() {
                if entityIndex.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let count = entity.type.utf8.count
                guard count <= remainingBytes else {
                    throw GlifiFailure(
                        code: "evaluation.limit-exceeded", category: .invalidInput,
                        operation: .analyze,
                        retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
                        messageKey: "failure.category.invalidInput")
                }
                remainingBytes -= count
            }
        }
    }
}

private func mapEvaluationFailure<Value>(_ body: () throws -> Value) throws(GlifiStudioFailure)
    -> Value
{
    do {
        try Task.checkCancellation()
        return try body()
    } catch let failure as GlifiFailure {
        throw GlifiStudioFailure(failure)
    } catch is CancellationError {
        throw GlifiStudioFailure(
            code: "analysis.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled")
    } catch {
        throw GlifiStudioFailure(
            code: "analysis.failed", category: "insufficientData", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.insufficientData")
    }
}
