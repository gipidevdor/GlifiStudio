// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A deterministic analytical result derived from immutable inputs and
/// persisted as one Artifact.
public protocol GlifiDerivedAnalysisResult: Codable, Equatable, Sendable {
    /// Stable output schema recorded by the producer descriptor.
    static var outputSchemaIdentifier: String { get }
    /// Versioned identity of the analytical method bundle.
    static var analysisIdentifier: String { get }
    /// Method identity serialized with the result and revalidated on decode.
    var analysisIdentifier: String { get }
}

/// Canonical persisted payload wrapping one `GlifiDerivedAnalysisResult`.
public struct GlifiDerivedAnalysisArtifactPayload<Value: GlifiDerivedAnalysisResult>:
    GlifiAnalysisArtifactPayload, Equatable, Sendable
{
    /// Stable artifact payload schema of the wrapped result.
    public static var outputSchemaIdentifier: String { Value.outputSchemaIdentifier }
    /// Current payload schema version.
    public static var schemaVersion: Int { 1 }

    /// Stable schema serialized with the payload.
    public let schemaIdentifier: String
    /// Version serialized with the payload.
    public let schemaVersion: Int
    /// Semantic producer identity bound into the immutable payload.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic analytical result.
    public let result: Value

    /// Creates the canonical payload for a verified derived result.
    public init(analysisNodeID: AnalysisNodeID, result: Value) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = Self.schemaVersion
        self.analysisNodeID = analysisNodeID
        self.result = result
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, analysisNodeID, result
    }

    /// Decodes only the supported schema and analytical family.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let analysisNodeID = try container.decode(AnalysisNodeID.self, forKey: .analysisNodeID)
        let result = try container.decode(Value.self, forKey: .result)
        guard schemaIdentifier == Self.outputSchemaIdentifier,
            schemaVersion == Self.schemaVersion,
            result.analysisIdentifier == Value.analysisIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported derived-analysis artifact payload"
            )
        }
        self.schemaIdentifier = schemaIdentifier
        self.schemaVersion = schemaVersion
        self.analysisNodeID = analysisNodeID
        self.result = result
    }
}

/// A derived analysis bound to one verified project generation.
public struct GlifiProjectDerivedResult<Value: GlifiDerivedAnalysisResult>: Equatable, Sendable {
    /// Project that owns the analyzed sources.
    public let projectID: ProjectID
    /// Exact source generation captured before the analysis.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the persisted Artifact.
    public let generation: Int
    /// Immutable persisted result identity.
    public let artifactID: ArtifactID
    /// Semantic producer identity.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic analytical values.
    public let value: Value

    /// Creates a result with explicit project and generation lineage.
    public init(
        projectID: ProjectID,
        sourceGeneration: Int,
        generation: Int,
        artifactID: ArtifactID,
        analysisNodeID: AnalysisNodeID,
        value: Value
    ) {
        self.projectID = projectID
        self.sourceGeneration = sourceGeneration
        self.generation = generation
        self.artifactID = artifactID
        self.analysisNodeID = analysisNodeID
        self.value = value
    }
}

extension GlifiAnalysisArtifactDescriptorFactory {
    /// Descriptor for one derived analysis over role-tagged source groups or
    /// a canonical external input, with explicit dependencies.
    static func derived<Value: GlifiDerivedAnalysisResult>(
        _ type: Value.Type,
        artifactTypeIdentifier: String,
        snapshot: GlifiProjectSnapshot,
        sourceRevisionIDs: [SourceRevisionID],
        selectionDomain: String,
        selectionValues: [String],
        analyticalUnitIdentifier: String,
        representationIdentifier: String,
        resolvedParameters: [String: GlifiAnalysisValue],
        linguisticProfileIdentifiers: [String],
        dependencies: [GlifiAnalysisDependency]
    ) throws -> GlifiAnalysisDescriptor {
        try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: artifactTypeIdentifier,
            algorithmIdentifier: Value.analysisIdentifier,
            algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: try snapshot.corpusVersionDigest(for: sourceRevisionIDs),
            selectionIdentifier: try selectionIdentifier(
                domain: selectionDomain,
                values: selectionValues
            ),
            analyticalUnitIdentifier: analyticalUnitIdentifier,
            preprocessingIdentifiers: dependencies.isEmpty ? [] : ["corpus-profile-it-v1"],
            linguisticProfileIdentifiers: linguisticProfileIdentifiers,
            representationIdentifier: representationIdentifier,
            resolvedParameters: resolvedParameters,
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            determinismClass: .d1,
            outputSchemaIdentifier: Value.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0",
            dependencies: dependencies,
            sourceRevisionIDs: sourceRevisionIDs
        )
    }
}

func derivedAnalysisFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}

extension GlifiEngine {
    /// Get-or-store of one derived analysis: a semantic node already present
    /// in the current generation is reused without recomputation.
    func derivedArtifact<Value: GlifiDerivedAnalysisResult>(
        descriptor: GlifiAnalysisDescriptor,
        sourceSnapshot: GlifiProjectSnapshot,
        in project: GlifiProjectPackage,
        compute: () throws -> Value
    ) async throws -> GlifiProjectDerivedResult<Value> {
        let nodeID = try descriptor.nodeID()
        let preparedSnapshot = await project.snapshot()
        if let artifact = preparedSnapshot.artifacts.first(where: { $0.node.id == nodeID }) {
            let data = try await project.artifactData(for: artifact.artifactID)
            let payload: GlifiDerivedAnalysisArtifactPayload<Value> = try decodeArtifact(data)
            guard payload.analysisNodeID == nodeID else {
                throw analysisArtifactFailure("derived-analysis.payload-node-mismatch")
            }
            return GlifiProjectDerivedResult(
                projectID: sourceSnapshot.projectID,
                sourceGeneration: sourceSnapshot.generation,
                generation: preparedSnapshot.generation,
                artifactID: artifact.artifactID,
                analysisNodeID: nodeID,
                value: payload.result
            )
        }
        let value = try GlifiDiagnostics.measure(.deriveAnalysis, compute)
        try Task.checkCancellation()
        let committed = try await project.storeArtifact(
            GlifiDerivedAnalysisArtifactPayload(analysisNodeID: nodeID, result: value),
            descriptor: descriptor
        )
        guard let artifact = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
            throw analysisArtifactFailure("derived-analysis.persisted-artifact-missing")
        }
        return GlifiProjectDerivedResult(
            projectID: sourceSnapshot.projectID,
            sourceGeneration: sourceSnapshot.generation,
            generation: committed.generation,
            artifactID: artifact.artifactID,
            analysisNodeID: nodeID,
            value: value
        )
    }

    /// Reads back one persisted derived Artifact without recomputation.
    ///
    /// The Artifact must belong to the current generation, carry the output
    /// schema of `Value` and wrap a payload bound to its own producer node.
    public func storedDerivedResult<Value: GlifiDerivedAnalysisResult>(
        _ type: Value.Type,
        artifactID: ArtifactID,
        in project: GlifiProjectPackage
    ) async throws -> GlifiProjectDerivedResult<Value> {
        try await guardedDerived {
            let snapshot = await project.snapshot()
            guard let artifact = snapshot.artifacts.first(where: { $0.artifactID == artifactID })
            else {
                throw derivedAnalysisFailure("derived-analysis.artifact-not-found")
            }
            guard artifact.node.descriptor.outputSchemaIdentifier == Value.outputSchemaIdentifier
            else {
                throw derivedAnalysisFailure("derived-analysis.artifact-schema-mismatch")
            }
            let data = try await project.artifactData(for: artifactID)
            let payload: GlifiDerivedAnalysisArtifactPayload<Value> = try decodeArtifact(data)
            guard payload.analysisNodeID == artifact.node.id else {
                throw analysisArtifactFailure("derived-analysis.payload-node-mismatch")
            }
            return GlifiProjectDerivedResult(
                projectID: snapshot.projectID,
                sourceGeneration: snapshot.generation,
                generation: snapshot.generation,
                artifactID: artifactID,
                analysisNodeID: artifact.node.id,
                value: payload.result
            )
        }
    }

    /// Maps unexpected errors of a derived operation to the shared taxonomy.
    func guardedDerived<Result>(
        _ operation: () async throws -> Result
    ) async throws -> Result {
        do {
            return try await operation()
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .analyze,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "derived-analysis.internal-failure",
                category: .invariantViolation,
                operation: .analyze,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.derived-analysis.internal-failure"
            )
        }
    }

    /// One validated, corpus-profile-backed group of source revisions.
    struct DerivedCorpusGroup {
        let sourceRevisionIDs: [SourceRevisionID]
        let analysis: GlifiCorpusAnalysis
        let dependency: GlifiAnalysisDependency
    }

    /// Validates a group, builds or reuses its corpus profile, and returns
    /// the profile with its DAG dependency.
    func derivedCorpusGroup(
        _ sourceRevisionIDs: [SourceRevisionID],
        minimumCount: Int,
        code: String,
        snapshot: GlifiProjectSnapshot,
        options: GlifiCorpusAnalysisOptions,
        in project: GlifiProjectPackage
    ) async throws -> DerivedCorpusGroup {
        guard sourceRevisionIDs.count >= minimumCount else {
            throw derivedAnalysisFailure(
                "\(code).insufficient-sources",
                category: .insufficientData
            )
        }
        guard Set(sourceRevisionIDs).count == sourceRevisionIDs.count else {
            throw derivedAnalysisFailure("\(code).duplicate-source")
        }
        let recordsByID = Dictionary(
            uniqueKeysWithValues: snapshot.sources.map { ($0.sourceRevisionID, $0) }
        )
        let records = try selectedRecords(sourceRevisionIDs, recordsByID: recordsByID)
        try validateCorpusSelection(
            documentByteCounts: records.map(\.byteCount),
            options: options
        )
        let artifact = try await corpusAnalysisArtifact(
            records,
            options: options,
            in: project
        )
        return DerivedCorpusGroup(
            sourceRevisionIDs: sourceRevisionIDs,
            analysis: artifact.analysis,
            dependency: try GlifiAnalysisDependency(
                nodeID: artifact.record.node.id,
                artifactDigest: artifact.record.contentDigest,
                outputSchemaIdentifier: artifact.record.node.descriptor.outputSchemaIdentifier
            )
        )
    }
}
