// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Immutable scientific request and output; presentation bytes are an optional derived view.
public struct GlifiSavedResearchAnalysis: GlifiAnalysisArtifactPayload, Equatable, Sendable {
    /// Stable payload schema, independent of the package manifest version.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.saved-research-analysis.v1"
    /// Schema identity encoded with the immutable payload.
    public let schemaIdentifier: String
    /// Payload version admitted by the current reader.
    public let schemaVersion: Int
    /// Semantic producer identity bound to the stored descriptor.
    public let analysisNodeID: AnalysisNodeID
    /// User-provided title retained independently from the method identity.
    public let title: String
    /// Exact versioned scientific method reported by the original dispatcher.
    public let methodIdentifier: String
    /// Explicit non-text transport; nil retains the original text-analysis-v1 encoding.
    public let transportIdentifier: String?
    /// Resolved transport used to decode the captured request and result envelopes.
    public var effectiveTransportIdentifier: String { transportIdentifier ?? "text-analysis-v1" }
    /// Lowercase SHA-256 of the canonical resolved request bytes.
    public let requestDigest: String
    /// Semantic identity of the preparation captured with the result.
    public let preparationDigest: String
    /// Complete resolved lexical configuration, encoded independently of the view.
    public let preparationJSON: Data
    /// Original Apple runtime used by the preparation, absent for native-only settings.
    public let preparationOperatingSystemVersion: String?
    /// Declared input revisions in their effective analytical order.
    public let sourceRevisionIDs: [String]
    /// Input revisions aligned with the document assignments in the result.
    public let resultSourceRevisionIDs: [String]
    /// Original-content SHA-256 digests aligned with the declared input revisions.
    public let sourceContentDigests: [String]
    /// Canonical request bytes containing all effective inputs and parameters.
    public let requestJSON: Data
    /// Complete canonical result bytes; rendering does not recalculate these values.
    public let resultJSON: Data
    /// Optional derived native view and draft snapshot, never scientific authority.
    public let presentationJSON: Data?
    /// Nonnegative capture time expressed as Unix milliseconds.
    public let createdAtUnixMilliseconds: Int64

    /// Creates and validates an immutable capture before it can enter a project.
    public init(
        analysisNodeID: AnalysisNodeID, title: String, methodIdentifier: String,
        preparationDigest: String, preparationJSON: Data, sourceRevisionIDs: [String],
        sourceContentDigests: [String],
        requestJSON: Data, resultJSON: Data, presentationJSON: Data? = nil,
        createdAtUnixMilliseconds: Int64, resultSourceRevisionIDs: [String]? = nil,
        preparationOperatingSystemVersion: String? = nil, transportIdentifier: String? = nil
    ) throws {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = 1
        self.analysisNodeID = analysisNodeID
        self.title = title
        self.methodIdentifier = methodIdentifier
        self.transportIdentifier = transportIdentifier
        requestDigest = SHA256.hash(data: requestJSON).map { String(format: "%02x", $0) }.joined()
        self.preparationDigest = preparationDigest
        self.preparationJSON = preparationJSON
        self.preparationOperatingSystemVersion = preparationOperatingSystemVersion
        self.sourceRevisionIDs = sourceRevisionIDs
        self.resultSourceRevisionIDs = resultSourceRevisionIDs ?? sourceRevisionIDs
        self.sourceContentDigests = sourceContentDigests
        self.requestJSON = requestJSON
        self.resultJSON = resultJSON
        self.presentationJSON = presentationJSON
        self.createdAtUnixMilliseconds = createdAtUnixMilliseconds
        try validate()
    }

    /// Revalidates payloads read from disk before exposing a saved result.
    public func validate() throws {
        guard schemaIdentifier == Self.outputSchemaIdentifier, schemaVersion == 1,
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            title.utf8.count <= 512, !methodIdentifier.isEmpty,
            preparationJSON.count <= 4 * 1_048_576,
            requestJSON.count <= (transportIdentifier == nil ? 1_048_576 : 2 * 1_048_576),
            resultJSON.count <= (transportIdentifier == nil ? 8 * 1_048_576 : 12 * 1_048_576),
            (presentationJSON?.count ?? 0) <= 8 * 1_048_576,
            createdAtUnixMilliseconds >= 0, sourceRevisionIDs.count <= 1_000,
            sourceRevisionIDs.count == sourceContentDigests.count,
            Set(sourceRevisionIDs).count == sourceRevisionIDs.count,
            Set(resultSourceRevisionIDs).count == resultSourceRevisionIDs.count,
            Set(resultSourceRevisionIDs).isSubset(of: Set(sourceRevisionIDs)),
            requestDigest
                == SHA256.hash(data: requestJSON).map({ String(format: "%02x", $0) }).joined(),
            preparationDigest.hasPrefix("sha256:"), preparationDigest.utf8.count == 71
        else { throw savedResearchFailure("research.invalid-saved-analysis") }
        switch effectiveTransportIdentifier {
        case "text-analysis-v1":
            guard transportIdentifier == nil,
                let response = try? JSONDecoder().decode(SavedResultHeader.self, from: resultJSON),
                response.schema == "studio.glifi.text-analysis-result", response.schemaVersion == 1,
                response.requestDigest == requestDigest,
                response.methodIdentifier == methodIdentifier,
                let request = try? JSONDecoder().decode(SavedRequestHeader.self, from: requestJSON),
                request.schema == "studio.glifi.text-analysis-request", request.schemaVersion == 1,
                request.operation == response.operation
            else { throw savedResearchFailure("research.invalid-saved-analysis") }
        case "workbench-capture-v1":
            try GlifiWorkbenchCaptureEnvelope.validate(
                requestJSON: requestJSON, resultJSON: resultJSON, methodIdentifier: methodIdentifier
            )
        default: throw savedResearchFailure("research.incompatible-capture-transport")
        }
        let preparation = try JSONDecoder().decode(
            GlifiCorpusPreparation.self, from: preparationJSON)
        guard
            preparationDigest
                == (try preparation.digest(
                    operatingSystemVersion: preparationOperatingSystemVersion))
        else { throw savedResearchFailure("research.invalid-saved-analysis") }
        for id in sourceRevisionIDs { _ = try SourceRevisionID(canonicalValue: id) }
        guard
            sourceContentDigests.allSatisfy({ value in
                value.hasPrefix("sha256:") && value.count == 71
                    && value.dropFirst(7).allSatisfy { "0123456789abcdef".contains($0) }
            })
        else { throw savedResearchFailure("research.invalid-saved-analysis") }
    }

    /// Complete semantic identity, including captured preparation and the result row ordering.
    package func contentDigest() throws -> String {
        try Self.contentDigest(
            requestJSON: requestJSON, resultJSON: resultJSON, title: title,
            presentationJSON: presentationJSON, preparationDigest: preparationDigest,
            preparationJSON: preparationJSON,
            preparationOperatingSystemVersion: preparationOperatingSystemVersion,
            resultSourceRevisionIDs: resultSourceRevisionIDs,
            transportIdentifier: transportIdentifier)
    }

    package static func contentDigest(
        requestJSON: Data, resultJSON: Data, title: String, presentationJSON: Data?,
        preparationDigest: String, preparationJSON: Data,
        preparationOperatingSystemVersion: String?, resultSourceRevisionIDs: [String],
        transportIdentifier: String? = nil
    ) throws -> String {
        var content = [
            "request": requestJSON, "result": resultJSON, "title": Data(title.utf8),
            "presentation": presentationJSON ?? Data(), "preparation": Data(preparationDigest.utf8),
            "preparationJSON": preparationJSON,
            "preparationOperatingSystemVersion": Data(
                (preparationOperatingSystemVersion ?? "").utf8),
            "resultSources": try researchCanonicalData(resultSourceRevisionIDs),
        ]
        if let transportIdentifier {
            content["transportIdentifier"] = Data(transportIdentifier.utf8)
        }
        return try researchDigest(content)
    }
}

private struct SavedResultHeader: Decodable {
    let schema: String
    let schemaVersion: Int
    let operation: String
    let requestDigest: String
    let methodIdentifier: String
    let validationStatus: String
}

private struct SavedRequestHeader: Decodable {
    let schema: String
    let schemaVersion: Int
    let operation: String
}

package func savedResearchFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code, category: .invalidInput, operation: .persistProject,
        retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
        messageKey: "failure.category.invalidInput")
}
