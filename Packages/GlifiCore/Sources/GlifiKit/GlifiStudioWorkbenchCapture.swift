// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Original standalone command bytes restored from their explicit capture envelopes.
public struct GlifiStudioWorkbenchCapture: Sendable {
    /// Native dispatcher identity: statistics, operator or evaluation.
    public let command: String
    /// Canonical native request bytes, preserving UInt64 seeds and signed zero.
    public let requestJSON: Data
    /// Complete canonical native output, without recomputing its scientific values.
    public let resultJSON: Data
    /// Exact native method identity, or the ordered operator method identities joined by ` + `.
    public let methodIdentifier: String

    /// Unwraps and validates a saved standalone result without executing its dispatcher.
    public init(saved: GlifiStudioSavedAnalysis) throws {
        guard saved.transportIdentifier == "workbench-capture-v1" else {
            throw commandFailure("incompatible-capture-transport", category: "incompatibleVersion")
        }
        try GlifiWorkbenchCaptureEnvelope.validate(
            requestJSON: saved.requestJSON, resultJSON: saved.resultJSON,
            methodIdentifier: saved.methodIdentifier)
        let request = try JSONDecoder().decode(
            GlifiWorkbenchCaptureEnvelope.Request.self, from: saved.requestJSON)
        let result = try JSONDecoder().decode(
            GlifiWorkbenchCaptureEnvelope.Result.self, from: saved.resultJSON)
        try validateWorkbenchCapture(
            command: request.command, requestJSON: request.payloadJSON,
            resultJSON: result.payloadJSON,
            methodIdentifier: saved.methodIdentifier)
        command = request.command
        requestJSON = request.payloadJSON
        resultJSON = result.payloadJSON
        methodIdentifier = saved.methodIdentifier
    }
}

extension GlifiStudioProjectSession {
    /// Captures an existing standalone output using its own transport and no scientific re-execution.
    ///
    /// Explicit numerical inputs default to identity preparation; corpus-derived inputs declare their
    /// effective preparation instead of inheriting current editor settings.
    public func captureWorkbenchAnalysis(
        command: String, requestJSON: Data, resultJSON: Data, methodIdentifier: String,
        title: String,
        sourceRevisionIDs: [String] = [], presentationJSON: Data? = nil,
        preparationDigest: String? = nil, preparation: GlifiStudioCorpusPreparation? = nil,
        createdAtUnixMilliseconds: Int64? = nil, resultSourceRevisionIDs: [String]? = nil
    ) async throws -> GlifiStudioSavedAnalysis {
        try ensureOpen(operation: .persistProject)
        guard requestJSON.count <= 1_048_576, resultJSON.count <= 8 * 1_048_576,
            (presentationJSON?.count ?? 0) <= 8 * 1_048_576
        else { throw commandFailure("capture-byte-limit", category: "insufficientResources") }
        let rawRequest = try CommandJSON.canonicalize(requestJSON, maximumByteCount: 1_048_576)
        let rawResult = try CommandJSON.canonicalize(resultJSON, maximumByteCount: 8 * 1_048_576)
        let operation = try validateWorkbenchCapture(
            command: command, requestJSON: rawRequest, resultJSON: rawResult,
            methodIdentifier: methodIdentifier)
        let request = try CommandJSON.encode(
            GlifiWorkbenchCaptureEnvelope.Request(
                command: command, operation: operation, payloadJSON: rawRequest))
        let result = try CommandJSON.encode(
            GlifiWorkbenchCaptureEnvelope.Result(
                command: command, operation: operation, requestJSON: request,
                methodIdentifier: methodIdentifier, payloadJSON: rawResult))
        return try await persistCapturedAnalysis(
            requestJSON: request, resultJSON: result, methodIdentifier: methodIdentifier,
            title: title, sourceRevisionIDs: sourceRevisionIDs, presentationJSON: presentationJSON,
            preparationDigest: preparationDigest, preparation: preparation,
            createdAtUnixMilliseconds: createdAtUnixMilliseconds,
            resultSourceRevisionIDs: resultSourceRevisionIDs,
            transportIdentifier: "workbench-capture-v1")
    }
}

/// Performs only structural admission and request/method identity checks, never calculations.
@discardableResult private func validateWorkbenchCapture(
    command: String, requestJSON: Data, resultJSON: Data, methodIdentifier: String
) throws -> String {
    guard !methodIdentifier.isEmpty, methodIdentifier.utf8.count <= 4_096 else {
        throw commandFailure("invalid-workbench-method")
    }
    switch command {
    case "statistics":
        let request = try CommandJSON.decodeStrict(
            GlifiStudioStatisticsRequest.self, from: requestJSON)
        let result = try CommandJSON.decodeStrict(
            GlifiStudioStatisticsResult.self, from: resultJSON, maximumByteCount: 8 * 1_048_576)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let digest = SHA256.hash(data: try encoder.encode(request)).map {
            String(format: "%02x", $0)
        }.joined()
        guard result.methodIdentifier == methodIdentifier, result.requestDigest == digest,
            try CommandJSON.encode(request) == CommandJSON.encode(result.request)
        else { throw commandFailure("invalid-workbench-result") }
        return request.operation.rawValue
    case "operator":
        let request = try CommandJSON.decodeStrict(
            GlifiStudioCoreOperatorRequest.self, from: requestJSON)
        let result = try CommandJSON.decodeStrict(
            GlifiStudioCoreOperatorResult.self, from: resultJSON, maximumByteCount: 8 * 1_048_576)
        guard result.schema == "studio.glifi.core-operator-result", result.schemaVersion == 1,
            result.validationStatus == "candidate", !result.methodIdentifiers.isEmpty,
            result.methodIdentifiers.joined(separator: " + ") == methodIdentifier,
            try CommandJSON.encode(request) == CommandJSON.encode(result.request)
        else { throw commandFailure("invalid-workbench-result") }
        return request.operation.rawValue
    case "evaluation":
        let header = try CommandJSON.decode(EvaluationCommandHeader.self, from: requestJSON)
        guard header.schema == GlifiStudioEvaluationCommand.schema,
            header.schemaVersion == GlifiStudioEvaluationCommand.schemaVersion
        else { throw commandFailure("invalid-workbench-request") }
        try validateEvaluationCaptureRequest(header.operation, json: requestJSON)
        let result = try CommandJSON.decode(
            WorkbenchMethodHeader.self, from: resultJSON, maximumByteCount: 8 * 1_048_576)
        guard result.methodIdentifier == methodIdentifier else {
            throw commandFailure("invalid-workbench-result")
        }
        try validateEvaluationCaptureResult(header.operation, json: resultJSON)
        return header.operation.rawValue
    default: throw commandFailure("unsupported-workbench-command")
    }
}

private func validateEvaluationCaptureResult(
    _ operation: GlifiStudioEvaluationOperation, json: Data
) throws {
    switch operation {
    case .classification, .lemmas, .boundaries, .namedEntities, .morphology,
        .boundariesWithText, .namedEntitiesWithText:
        _ = try CommandJSON.decodeStrict(
            GlifiStudioLinguisticEvaluationResult.self, from: json, maximumByteCount: 8 * 1_048_576)
    case .temporal:
        _ = try CommandJSON.decodeStrict(
            GlifiStudioTemporalResult.self, from: json, maximumByteCount: 8 * 1_048_576)
    case .lexicalObserve:
        _ = try CommandJSON.decodeStrict(
            GlifiLexicalDistribution.self, from: json, maximumByteCount: 8 * 1_048_576)
    case .lexicalZipf, .lexicalHeaps:
        _ = try CommandJSON.decodeStrict(
            GlifiLogPowerFit.self, from: json, maximumByteCount: 8 * 1_048_576)
    case .lexicalSummary:
        _ = try CommandJSON.decodeStrict(
            GlifiDescriptiveSummary.self, from: json, maximumByteCount: 8 * 1_048_576)
    case .welchANOVA:
        _ = try CommandJSON.decodeStrict(
            GlifiStudioWelchANOVAResult.self, from: json, maximumByteCount: 8 * 1_048_576)
    }
}

private struct WorkbenchMethodHeader: Decodable { let methodIdentifier: String }

private func validateEvaluationCaptureRequest(
    _ operation: GlifiStudioEvaluationOperation, json: Data
) throws {
    switch operation {
    case .classification:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationLabels>.self, from: json)
    case .lemmas:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationLemmas>.self, from: json)
    case .boundaries:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationBoundaries>.self, from: json)
    case .namedEntities:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationEntities>.self, from: json)
    case .morphology:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationMorphology>.self, from: json)
    case .boundariesWithText:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationTextBoundaries>.self, from: json)
    case .namedEntitiesWithText:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationTextEntities>.self, from: json)
    case .temporal:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationTemporal>.self, from: json)
    case .lexicalObserve, .lexicalHeaps:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationLexical>.self, from: json)
    case .lexicalZipf:
        _ = try CommandJSON.decodeStrict(EvaluationCommandEnvelope<EvaluationZipf>.self, from: json)
    case .lexicalSummary:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationSummary>.self, from: json)
    case .welchANOVA:
        _ = try CommandJSON.decodeStrict(
            EvaluationCommandEnvelope<EvaluationWelch>.self, from: json)
    }
}
