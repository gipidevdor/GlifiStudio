// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Complete standalone evaluation and lexical operations admitted by the shared transport.
public enum GlifiStudioEvaluationOperation: String, Codable, CaseIterable, Sendable {
    case classification
    case lemmas
    case boundaries
    case namedEntities = "named-entities"
    case morphology
    case boundariesWithText = "boundaries-with-text"
    case namedEntitiesWithText = "named-entities-with-text"
    case temporal
    case lexicalObserve = "lexical-observe"
    case lexicalZipf = "lexical-zipf"
    case lexicalHeaps = "lexical-heaps"
    case lexicalSummary = "lexical-summary"
    case welchANOVA = "welch-anova"
}

/// Versioned transport over native evaluation APIs; the command line only adapts file I/O.
public enum GlifiStudioEvaluationCommand {
    /// Request identity, independent from the project persistence format.
    public static let schema = "studio.glifi.evaluation-command-request"
    /// Current additive command transport version.
    public static let schemaVersion = 1

    /// Evaluates the exact native parameters, preserving typed failures and cancellation.
    @concurrent public static func execute(json: Data) async throws(GlifiStudioFailure)
        -> GlifiStudioCommandResult
    {
        guard !Task.isCancelled else { throw evaluationCommandCancellation() }
        let header = try CommandJSON.decode(EvaluationCommandHeader.self, from: json)
        guard header.schema == schema else {
            throw evaluationCommandFailure("invalid-schema")
        }
        guard header.schemaVersion == schemaVersion else {
            throw evaluationCommandFailure("incompatible-version", category: "incompatibleVersion")
        }
        let result: GlifiStudioCommandResult
        switch header.operation {
        case .classification:
            let value: EvaluationLabels = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioLinguisticEvaluation.classification(
                    gold: value.gold, predicted: value.predicted,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .lemmas:
            let value: EvaluationLemmas = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioLinguisticEvaluation.lemmas(
                    gold: value.gold, predicted: value.predicted,
                    forms: value.forms, partsOfSpeech: value.partsOfSpeech,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .boundaries:
            let value: EvaluationBoundaries = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioLinguisticEvaluation.boundaries(
                    gold: value.gold, predicted: value.predicted, utf8Lengths: value.utf8Lengths,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .namedEntities:
            let value: EvaluationEntities = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioLinguisticEvaluation.namedEntities(
                    gold: value.gold, predicted: value.predicted, utf8Lengths: value.utf8Lengths,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .morphology:
            let value: EvaluationMorphology = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioLinguisticEvaluation.morphology(
                    gold: value.gold, predicted: value.predicted,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .boundariesWithText:
            let value: EvaluationTextBoundaries = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioEvaluationWorkbench.boundaries(
                    gold: value.gold, predicted: value.predicted, texts: value.texts,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .namedEntitiesWithText:
            let value: EvaluationTextEntities = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioEvaluationWorkbench.namedEntities(
                    gold: value.gold, predicted: value.predicted, texts: value.texts,
                    zeroPolicy: value.zeroPolicy ?? .undefined))
        case .temporal:
            let value: EvaluationTemporal = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioTextAnalytics.temporalFrequencies(
                    value.documents, configuration: value.configuration))
        case .lexicalObserve:
            let value: EvaluationLexical = try parameters(from: json)
            result = try await GlifiStudioCommandResult(value.observe())
        case .lexicalZipf:
            let value: EvaluationZipf = try parameters(from: json)
            guard value.firstRank <= value.lastRank else {
                throw evaluationCommandFailure("invalid-ranks")
            }
            let observed = try await value.observations.observe()
            result = try await GlifiStudioCommandResult(
                GlifiStudioLexicalStatistics.fitZipf(
                    observed, ranks: value.firstRank...value.lastRank))
        case .lexicalHeaps:
            let value: EvaluationLexical = try parameters(from: json)
            let observed = try await value.observe()
            result = try await GlifiStudioCommandResult(
                GlifiStudioLexicalStatistics.fitHeaps(observed))
        case .lexicalSummary:
            let value: EvaluationSummary = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioLexicalStatistics.summarize(
                    value.observations, unitIdentifier: value.unitIdentifier,
                    variance: value.variance, probabilities: value.probabilities))
        case .welchANOVA:
            let value: EvaluationWelch = try parameters(from: json)
            result = try await GlifiStudioCommandResult(
                GlifiStudioTextAnalytics.welchOneWayANOVA(value.groups))
        }
        guard !Task.isCancelled else { throw evaluationCommandCancellation() }
        return result
    }

    private static func parameters<Value: Codable>(from json: Data) throws(GlifiStudioFailure)
        -> Value
    {
        let request = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<Value>.self, from: json)
        return request.parameters
    }
}

struct EvaluationCommandHeader: Decodable {
    let schema: String
    let schemaVersion: Int
    let operation: GlifiStudioEvaluationOperation
}

struct EvaluationCommandEnvelope<Parameters: Codable>: Codable {
    let schema: String
    let schemaVersion: Int
    let operation: GlifiStudioEvaluationOperation
    let parameters: Parameters
}

struct EvaluationLabels: Codable {
    let gold: [String]
    let predicted: [String]
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationLemmas: Codable {
    let gold: [String]
    let predicted: [String]
    let forms: [String]?
    let partsOfSpeech: [String]?
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationBoundaries: Codable {
    let gold: [[Int]]
    let predicted: [[Int]]
    let utf8Lengths: [Int]
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationEntities: Codable {
    let gold: [[GlifiStudioEvaluationEntity]]
    let predicted: [[GlifiStudioEvaluationEntity]]
    let utf8Lengths: [Int]
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationMorphology: Codable {
    let gold: [[String: String]]
    let predicted: [[String: String]]
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationTextBoundaries: Codable {
    let gold: [[Int]]
    let predicted: [[Int]]
    let texts: [String]
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationTextEntities: Codable {
    let gold: [[GlifiStudioEvaluationEntity]]
    let predicted: [[GlifiStudioEvaluationEntity]]
    let texts: [String]
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy?
}

struct EvaluationTemporal: Codable {
    let documents: [GlifiStudioTemporalDocument]
    let configuration: GlifiStudioTemporalConfiguration
}

struct EvaluationLexical: Codable {
    let documents: [GlifiStudioLexicalSequence]
    let checkpoints: [Int]
    let preprocessingIdentifier: String

    func observe() async throws(GlifiStudioFailure) -> GlifiStudioLexicalDistribution {
        try await GlifiStudioLexicalStatistics.observe(
            documents, checkpoints: checkpoints, preprocessingIdentifier: preprocessingIdentifier)
    }
}

struct EvaluationZipf: Codable {
    let observations: EvaluationLexical
    let firstRank: Int
    let lastRank: Int
}

struct EvaluationSummary: Codable {
    let observations: [Double?]
    let unitIdentifier: String
    let variance: GlifiStudioVarianceConvention
    let probabilities: [Double]
}

struct EvaluationWelch: Codable {
    let groups: [[Double]]
}

private func evaluationCommandFailure(
    _ reason: String, category: String = "invalidInput"
) -> GlifiStudioFailure {
    GlifiStudioFailure(
        code: "evaluation-command.\(reason)", category: category, operation: "analyze",
        retryDisposition: category == "incompatibleVersion" ? "never" : "afterCorrection",
        retainedState: "unchanged", messageKey: "failure.category.\(category)")
}

private func evaluationCommandCancellation() -> GlifiStudioFailure {
    GlifiStudioFailure(
        code: "operation.cancelled", category: "cancelled", operation: "analyze",
        retryDisposition: "newRequest", retainedState: "unchanged",
        messageKey: "failure.category.cancelled")
}
