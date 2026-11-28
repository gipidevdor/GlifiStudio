// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// A complete saved result, including the original request and immutable source lineage.
public struct GlifiStudioSavedAnalysis: Codable, Identifiable, Sendable {
    /// Stable list identity equal to the content-addressed artifact identifier.
    public var id: String { artifactID }
    /// Content-addressed identity of the complete captured analysis.
    public let artifactID: String
    /// User-provided title retained independently from the method identity.
    public let title: String
    /// Exact versioned scientific method reported by the original dispatcher.
    public let methodIdentifier: String
    /// Discriminant selecting the text or standalone-workbench request/result envelopes.
    public let transportIdentifier: String
    /// Declared input revisions in their effective analytical order.
    public let sourceRevisionIDs: [String]
    /// Input revisions aligned with the document assignments in the result.
    public let resultSourceRevisionIDs: [String]
    /// Canonical request bytes containing all effective inputs and parameters.
    public let requestJSON: Data
    /// Complete canonical result bytes; rendering does not recalculate these values.
    public let resultJSON: Data
    /// Optional derived native view and draft snapshot, never scientific authority.
    public let presentationJSON: Data?
    /// Semantic identity of the preparation captured with the result.
    public let preparationDigest: String
    /// Complete resolved lexical configuration, encoded independently of the view.
    public let preparationJSON: Data
    /// Original Apple runtime used by the preparation, absent for native-only settings.
    public let preparationOperatingSystemVersion: String?
    /// Nonnegative capture time expressed as Unix milliseconds.
    public let createdAtUnixMilliseconds: Int64

    init(_ payload: GlifiSavedResearchAnalysis, artifactID: String) {
        self.artifactID = artifactID
        title = payload.title
        methodIdentifier = payload.methodIdentifier
        transportIdentifier = payload.effectiveTransportIdentifier
        sourceRevisionIDs = payload.sourceRevisionIDs
        resultSourceRevisionIDs = payload.resultSourceRevisionIDs
        requestJSON = payload.requestJSON
        resultJSON = payload.resultJSON
        presentationJSON = payload.presentationJSON
        preparationDigest = payload.preparationDigest
        preparationJSON = payload.preparationJSON
        preparationOperatingSystemVersion = payload.preparationOperatingSystemVersion
        createdAtUnixMilliseconds = payload.createdAtUnixMilliseconds
    }
}

extension GlifiStudioProjectSession {
    /// Runs the existing typed dispatcher and saves the complete output in the project.
    public func runSavedAnalysis(
        requestJSON: Data, title: String, sourceRevisionIDs: [String]
    ) async throws -> GlifiStudioSavedAnalysis {
        try ensureOpen(operation: .analyze)
        let request = try GlifiStudioTextAnalysisRequest.decode(requestJSON)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        return try await saveCompletedAnalysis(
            request: request, result: result, title: title,
            sourceRevisionIDs: sourceRevisionIDs)
    }

    /// Saves a result issued by GlifiKit without calculating it a second time.
    ///
    /// Presentation bytes are a derived client view and are never scientific authority.
    public func saveCompletedAnalysis(
        request: GlifiStudioTextAnalysisRequest, result: GlifiStudioTextAnalysisResult,
        title: String, sourceRevisionIDs: [String], presentationJSON: Data? = nil,
        preparationDigest: String? = nil,
        preparation: GlifiStudioCorpusPreparation? = nil,
        resultSourceRevisionIDs: [String]? = nil
    ) async throws -> GlifiStudioSavedAnalysis {
        try await captureSavedAnalysis(
            requestJSON: request.canonicalData(), resultJSON: CommandJSON.encode(result),
            title: title, sourceRevisionIDs: sourceRevisionIDs,
            presentationJSON: presentationJSON, preparationDigest: preparationDigest,
            preparation: preparation, resultSourceRevisionIDs: resultSourceRevisionIDs)
    }

    /// Captures an existing output with explicit identity checks and no scientific re-execution.
    ///
    /// Captured output is not automatically promoted to a Finding or inferential conclusion.
    public func captureSavedAnalysis(
        requestJSON: Data, resultJSON: Data, title: String, sourceRevisionIDs: [String],
        presentationJSON: Data? = nil, preparationDigest: String? = nil,
        preparation: GlifiStudioCorpusPreparation? = nil,
        createdAtUnixMilliseconds: Int64? = nil,
        resultSourceRevisionIDs: [String]? = nil
    ) async throws -> GlifiStudioSavedAnalysis {
        try ensureOpen(operation: .persistProject)
        guard requestJSON.count <= 1_048_576, resultJSON.count <= 8 * 1_048_576,
            (presentationJSON?.count ?? 0) <= 8 * 1_048_576
        else { throw commandFailure("capture-byte-limit", category: "insufficientResources") }
        guard resultJSON.count <= 8 * 1_048_576,
            let resultHeader = try JSONSerialization.jsonObject(with: resultJSON) as? [String: Any],
            let method = resultHeader["methodIdentifier"] as? String,
            resultHeader["validationStatus"] as? String
                == GlifiStudioTextAnalytics.validationStatus(forMethod: method)
        else { throw GlifiStudioFailure(savedResearchFailure("research.invalid-saved-analysis")) }
        let request = try GlifiStudioTextAnalysisRequest.decode(requestJSON)
        return try await persistCapturedAnalysis(
            requestJSON: request.canonicalData(), resultJSON: resultJSON,
            methodIdentifier: method, title: title, sourceRevisionIDs: sourceRevisionIDs,
            presentationJSON: presentationJSON, preparationDigest: preparationDigest,
            preparation: preparation, createdAtUnixMilliseconds: createdAtUnixMilliseconds,
            resultSourceRevisionIDs: resultSourceRevisionIDs)
    }

    /// Commits admitted envelopes through one shared descriptor and integrity path.
    package func persistCapturedAnalysis(
        requestJSON: Data, resultJSON: Data, methodIdentifier: String, title: String,
        sourceRevisionIDs: [String], presentationJSON: Data? = nil,
        preparationDigest: String? = nil, preparation: GlifiStudioCorpusPreparation? = nil,
        createdAtUnixMilliseconds: Int64? = nil, resultSourceRevisionIDs: [String]? = nil,
        transportIdentifier: String? = nil
    ) async throws -> GlifiStudioSavedAnalysis {
        try await performOperation(.persistProject) {
            guard requestJSON.count <= (transportIdentifier == nil ? 1_048_576 : 2 * 1_048_576),
                resultJSON.count <= (transportIdentifier == nil ? 8 * 1_048_576 : 12 * 1_048_576),
                (presentationJSON?.count ?? 0) <= 8 * 1_048_576
            else { throw commandFailure("capture-byte-limit", category: "insufficientResources") }
            let snapshot = await project.snapshot()
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            guard Set(ids).count == ids.count,
                ids.allSatisfy({ id in snapshot.sources.contains { $0.sourceRevisionID == id } })
            else { throw savedResearchFailure("research.invalid-saved-analysis") }
            let canonical = requestJSON
            let method = methodIdentifier
            let capturedPreparation = preparation ?? GlifiStudioCorpusPreparation()
            let resolvedPreparation = try capturedPreparation.core()
            let preparationRuntime =
                resolvedPreparation.requiresAppleRuntime
                ? ProcessInfo.processInfo.operatingSystemVersionString : nil
            let preparation = try resolvedPreparation.digest(
                operatingSystemVersion: preparationRuntime)
            guard preparationDigest == nil || preparationDigest == preparation else {
                throw savedResearchFailure("research.invalid-saved-analysis")
            }
            let preparationJSON = try CommandJSON.encode(capturedPreparation)
            let response = try CommandJSON.canonicalize(
                resultJSON,
                maximumByteCount: transportIdentifier == nil ? 8 * 1_048_576 : 12 * 1_048_576)
            let contentDigest = try GlifiSavedResearchAnalysis.contentDigest(
                requestJSON: canonical, resultJSON: response, title: title,
                presentationJSON: presentationJSON, preparationDigest: preparation,
                preparationJSON: preparationJSON,
                preparationOperatingSystemVersion: preparationRuntime,
                resultSourceRevisionIDs: resultSourceRevisionIDs ?? sourceRevisionIDs,
                transportIdentifier: transportIdentifier)
            let descriptor = try GlifiAnalysisDescriptor(
                artifactTypeIdentifier: "studio.glifi.artifact.saved-research-analysis",
                algorithmIdentifier: method, algorithmVersion: "1",
                corpusIdentifier: snapshot.projectID.canonicalValue,
                corpusVersionDigest: snapshot.corpusVersionDigest(for: ids),
                selectionIdentifier: "explicit-source-revisions-v1",
                analyticalUnitIdentifier: "declared-request-units-v1",
                preprocessingIdentifiers: transportIdentifier != nil
                    && capturedPreparation.isIdentity
                    ? [] : [preparation],
                linguisticProfileIdentifiers: transportIdentifier != nil
                    && capturedPreparation.isIdentity
                    ? [] : ["it"],
                representationIdentifier: transportIdentifier == nil
                    ? "canonical-request-and-complete-result-v1"
                    : "workbench-capture-request-and-result-v1",
                resolvedParameters: ["contentDigest": .text(contentDigest)],
                seedPolicyIdentifier: "resolved-in-canonical-request",
                backendIdentifier: "studio.glifi.native",
                numericPolicyIdentifier: "declared-by-method",
                determinismClass: .d0,
                outputSchemaIdentifier: GlifiSavedResearchAnalysis.outputSchemaIdentifier,
                softwareIdentifier: "GlifiCore-0.1.0", dependencies: [], sourceRevisionIDs: ids)
            let node = try descriptor.nodeID()
            if let existing = snapshot.artifacts.first(where: { $0.node.id == node }) {
                return try await savedAnalysis(artifactID: existing.artifactID.canonicalValue)
            }
            let digestByID = Dictionary(
                uniqueKeysWithValues: snapshot.sources.map {
                    ($0.sourceRevisionID.canonicalValue, $0.contentDigest)
                })
            let payload = try GlifiSavedResearchAnalysis(
                analysisNodeID: node, title: title, methodIdentifier: method,
                preparationDigest: preparation, preparationJSON: preparationJSON,
                sourceRevisionIDs: sourceRevisionIDs,
                sourceContentDigests: sourceRevisionIDs.compactMap { digestByID[$0] },
                requestJSON: canonical, resultJSON: response, presentationJSON: presentationJSON,
                createdAtUnixMilliseconds: createdAtUnixMilliseconds
                    ?? Int64(Date().timeIntervalSince1970 * 1_000),
                resultSourceRevisionIDs: resultSourceRevisionIDs,
                preparationOperatingSystemVersion: preparationRuntime,
                transportIdentifier: transportIdentifier)
            try Task.checkCancellation()
            let committed = try await project.storeArtifact(payload, descriptor: descriptor)
            guard let record = committed.artifacts.first(where: { $0.node.id == node }) else {
                throw savedResearchFailure("research.invalid-saved-analysis")
            }
            return GlifiStudioSavedAnalysis(payload, artifactID: record.artifactID.canonicalValue)
        }
    }

    /// Restores verified results without executing their algorithms.
    public func savedAnalyses() async throws -> [GlifiStudioSavedAnalysis] {
        try ensureOpen()
        let snapshot = await project.snapshot()
        var results: [GlifiStudioSavedAnalysis] = []
        for record in snapshot.artifacts
        where record.node.descriptor.outputSchemaIdentifier
            == GlifiSavedResearchAnalysis.outputSchemaIdentifier
        {
            try Task.checkCancellation()
            results.append(try await savedAnalysis(artifactID: record.artifactID.canonicalValue))
        }
        return results.sorted {
            $0.createdAtUnixMilliseconds == $1.createdAtUnixMilliseconds
                ? $0.artifactID < $1.artifactID
                : $0.createdAtUnixMilliseconds > $1.createdAtUnixMilliseconds
        }
    }

    /// Reads one saved result and checks its node, source revisions and output identity.
    public func savedAnalysis(artifactID: String) async throws -> GlifiStudioSavedAnalysis {
        try await performOperation(.analyze) {
            let id = try ArtifactID(canonicalValue: artifactID)
            let snapshot = await project.snapshot()
            guard let record = snapshot.artifacts.first(where: { $0.artifactID == id }),
                record.node.descriptor.outputSchemaIdentifier
                    == GlifiSavedResearchAnalysis.outputSchemaIdentifier
            else { throw savedResearchFailure("research.invalid-saved-analysis") }
            let bytes = try await project.artifactData(for: id)
            let payload = try JSONDecoder().decode(GlifiSavedResearchAnalysis.self, from: bytes)
            try payload.validate()
            guard payload.analysisNodeID == record.node.id,
                record.node.descriptor.resolvedParameters["contentDigest"]
                    == .text(try payload.contentDigest()),
                payload.methodIdentifier == record.node.descriptor.algorithmIdentifier,
                payload.sourceRevisionIDs.sorted()
                    == record.node.descriptor.sourceRevisionIDs?.map(\.canonicalValue).sorted(),
                zip(payload.sourceRevisionIDs, payload.sourceContentDigests).allSatisfy({
                    id, digest in
                    snapshot.sources.contains {
                        $0.sourceRevisionID.canonicalValue == id && $0.contentDigest == digest
                    }
                })
            else { throw savedResearchFailure("research.invalid-saved-analysis") }
            let view = GlifiStudioSavedAnalysis(payload, artifactID: artifactID)
            if payload.transportIdentifier == nil {
                let request = try GlifiStudioTextAnalysisRequest.decode(payload.requestJSON)
                guard try request.canonicalData() == payload.requestJSON else {
                    throw savedResearchFailure("research.invalid-saved-analysis")
                }
            } else {
                _ = try GlifiStudioWorkbenchCapture(saved: view)
            }
            return view
        }
    }

    /// Exports the complete immutable request, result and lineage envelope as canonical JSON.
    public func exportSavedAnalysis(artifactID: String) async throws -> Data {
        try ensureOpen(operation: .export)
        let id = try ArtifactID(canonicalValue: artifactID)
        _ = try await savedAnalysis(artifactID: artifactID)
        return try await project.artifactData(for: id)
    }
}

package func researchContentDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
