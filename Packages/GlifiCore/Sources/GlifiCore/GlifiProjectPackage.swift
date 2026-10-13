// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Darwin
import Foundation

/// One immutable source revision reachable from a project generation.
public struct GlifiProjectSourceRecord: Codable, Equatable, Sendable {
    /// Logical identity of the source.
    public let sourceID: SourceID
    /// Identity of the immutable source snapshot.
    public let sourceRevisionID: SourceRevisionID
    /// Validated source format.
    public let format: GlifiTextFormat
    /// Digest of the exact source bytes.
    public let contentDigest: String
    /// Exact number of source bytes.
    public let byteCount: Int
    /// Generated relative path of the content-addressed object.
    public let objectPath: String

    /// Creates a fully identified immutable source record.
    public init(
        sourceID: SourceID,
        sourceRevisionID: SourceRevisionID,
        format: GlifiTextFormat,
        contentDigest: String,
        byteCount: Int,
        objectPath: String
    ) {
        self.sourceID = sourceID
        self.sourceRevisionID = sourceRevisionID
        self.format = format
        self.contentDigest = contentDigest
        self.byteCount = byteCount
        self.objectPath = objectPath
    }
}

/// One immutable analytical result reachable from a project generation.
public struct GlifiProjectArtifactRecord: Codable, Equatable, Sendable {
    /// Content identity of the exact output bytes.
    public let artifactID: ArtifactID
    /// Semantic producer node and complete descriptor.
    public let node: GlifiAnalysisNode
    /// Digest of the canonical descriptor.
    public let descriptorDigest: String
    /// Exact descriptor byte count.
    public let descriptorByteCount: Int
    /// Generated relative path of the content-addressed descriptor.
    public let descriptorObjectPath: String
    /// Digest of the exact output bytes.
    public let contentDigest: String
    /// Exact output byte count.
    public let byteCount: Int
    /// Generated relative path of the content-addressed output.
    public let objectPath: String

    init(
        artifactID: ArtifactID,
        node: GlifiAnalysisNode,
        descriptorDigest: String,
        descriptorByteCount: Int,
        descriptorObjectPath: String,
        contentDigest: String,
        byteCount: Int,
        objectPath: String
    ) {
        self.artifactID = artifactID
        self.node = node
        self.descriptorDigest = descriptorDigest
        self.descriptorByteCount = descriptorByteCount
        self.descriptorObjectPath = descriptorObjectPath
        self.contentDigest = contentDigest
        self.byteCount = byteCount
        self.objectPath = objectPath
    }

    var reference: GlifiAnalysisArtifactReference {
        get throws {
            try GlifiAnalysisArtifactReference(
                nodeID: node.id,
                descriptorDigest: descriptorDigest,
                artifactDigest: contentDigest,
                outputSchemaIdentifier: node.descriptor.outputSchemaIdentifier,
                state: .valid
            )
        }
    }
}

/// One immutable investigation-history event reachable from a project generation.
public struct GlifiProjectInvestigationEventRecord: Codable, Equatable, Sendable {
    /// Content identity of the canonical event.
    public let eventID: InvestigationEventID
    /// Aggregate that owns the event.
    public let investigationID: InvestigationID
    /// Previous event on the same branch.
    public let predecessorEventID: InvestigationEventID?
    /// SHA-256 digest of the exact canonical bytes.
    public let contentDigest: String
    /// Exact canonical byte count.
    public let byteCount: Int
    /// Generated relative content-addressed path.
    public let objectPath: String

    init(
        eventID: InvestigationEventID,
        investigationID: InvestigationID,
        predecessorEventID: InvestigationEventID?,
        contentDigest: String,
        byteCount: Int,
        objectPath: String
    ) {
        self.eventID = eventID
        self.investigationID = investigationID
        self.predecessorEventID = predecessorEventID
        self.contentDigest = contentDigest
        self.byteCount = byteCount
        self.objectPath = objectPath
    }
}

/// One immutable qualitative-history event at a fixed position of the linear history.
public struct GlifiProjectQualitativeEventRecord: Codable, Equatable, Sendable {
    /// Content identity of the canonical event.
    public let eventID: String
    /// Previous event, absent only for the first.
    public let predecessorEventID: String?
    /// SHA-256 digest of the exact canonical bytes.
    public let contentDigest: String
    /// Exact canonical byte count.
    public let byteCount: Int
    /// Generated relative content-addressed path.
    public let objectPath: String
}

/// Verified authoritative view of one committed project generation.
public struct GlifiProjectSnapshot: Equatable, Sendable {
    /// Stable identity of the project aggregate.
    public let projectID: ProjectID
    /// Monotonic authoritative generation selected by the root manifest.
    public let generation: Int
    /// Digest of the authoritative generation record selected by the manifest.
    public let generationRecordDigest: String
    /// Ordered source revisions reachable from this generation.
    public let sources: [GlifiProjectSourceRecord]
    /// Digest of the canonical ordered source root.
    public let sourceRootDigest: String
    /// Ordered analytical artifacts reachable from this generation.
    public let artifacts: [GlifiProjectArtifactRecord]
    /// Digest of the canonical ordered analytical-artifact root.
    public let artifactRootDigest: String
    /// Ordered append-only cognitive events reachable from this generation.
    public let investigationEvents: [GlifiProjectInvestigationEventRecord]
    /// Digest of the canonical ordered investigation-history root.
    public let investigationRootDigest: String
    /// Linear qualitative history reachable from this generation (ADR-0027).
    public let qualitativeEvents: [GlifiProjectQualitativeEventRecord]
    /// Digest of the qualitative-history root.
    public let qualitativeRootDigest: String

    /// Creates an immutable verified snapshot.
    public init(
        projectID: ProjectID,
        generation: Int,
        generationRecordDigest: String,
        sources: [GlifiProjectSourceRecord],
        sourceRootDigest: String,
        artifacts: [GlifiProjectArtifactRecord],
        artifactRootDigest: String,
        investigationEvents: [GlifiProjectInvestigationEventRecord],
        investigationRootDigest: String,
        qualitativeEvents: [GlifiProjectQualitativeEventRecord] = [],
        qualitativeRootDigest: String = GlifiProjectManifest.emptyQualitativeRootDigest
    ) {
        self.projectID = projectID
        self.generation = generation
        self.generationRecordDigest = generationRecordDigest
        self.sources = sources
        self.sourceRootDigest = sourceRootDigest
        self.artifacts = artifacts
        self.artifactRootDigest = artifactRootDigest
        self.investigationEvents = investigationEvents
        self.investigationRootDigest = investigationRootDigest
        self.qualitativeEvents = qualitativeEvents
        self.qualitativeRootDigest = qualitativeRootDigest
    }
}

/// Bounded root manifest whose replacement is the project commit point.
public struct GlifiProjectManifest: Codable, Equatable, Sendable {
    /// Stable schema identifier.
    public static let schema = "studio.glifi.project-manifest"
    /// Current manifest schema version.
    public static let schemaVersion = 4
    /// Schema written while the qualitative history is empty, byte-identical to earlier packages.
    static let schemaVersionWithoutQualitativeHistory = 3
    static let previousSchemaVersion = 2
    /// Root digest of an empty qualitative history (canonical empty list).
    public static let emptyQualitativeRootDigest =
        "sha256:4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"
    static let emptyInvestigationRootDigest =
        "sha256:4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"
    /// Current package format major.
    public static let formatVersion = 1

    /// Stable schema identifier encoded in the document.
    public let schema: String
    /// Version of the root-manifest schema.
    public let schemaVersion: Int
    /// Major version of the package format.
    public let formatVersion: Int
    /// Oldest reader capable of opening this package.
    public let minimumReaderVersion: Int
    /// Stable identity of the project.
    public let projectID: ProjectID
    /// Authoritative generation selected by this manifest.
    public let generation: Int
    /// Previously authoritative generation, absent for generation zero.
    public let baseGeneration: Int?
    /// Digest of the prepared generation record in SQLite.
    public let generationRecordDigest: String
    /// Digest of the canonical ordered source root.
    public let sourceRootDigest: String
    /// Exact number of source records reachable from the generation.
    public let sourceCount: Int
    /// Digest of the canonical ordered analytical-artifact root.
    public let artifactRootDigest: String
    /// Exact number of analytical artifacts reachable from the generation.
    public let artifactCount: Int
    /// Digest of the append-only investigation-history root.
    public let investigationRootDigest: String
    /// Exact number of immutable investigation events reachable from the generation.
    public let investigationEventCount: Int
    /// Qualitative-history root, present only when the history is not empty (schema 4).
    public let qualitativeRootDigest: String?
    /// Qualitative events, present only when the history is not empty (schema 4).
    public let qualitativeEventCount: Int?

    init(
        projectID: ProjectID,
        generation: Int,
        baseGeneration: Int?,
        generationRecordDigest: String,
        sourceRootDigest: String,
        sourceCount: Int,
        artifactRootDigest: String,
        artifactCount: Int,
        investigationRootDigest: String,
        investigationEventCount: Int,
        qualitativeRootDigest: String = GlifiProjectManifest.emptyQualitativeRootDigest,
        qualitativeEventCount: Int = 0
    ) {
        schema = Self.schema
        schemaVersion =
            qualitativeEventCount > 0
            ? Self.schemaVersion : Self.schemaVersionWithoutQualitativeHistory
        self.qualitativeRootDigest = qualitativeEventCount > 0 ? qualitativeRootDigest : nil
        self.qualitativeEventCount = qualitativeEventCount > 0 ? qualitativeEventCount : nil
        formatVersion = Self.formatVersion
        minimumReaderVersion = Self.formatVersion
        self.projectID = projectID
        self.generation = generation
        self.baseGeneration = baseGeneration
        self.generationRecordDigest = generationRecordDigest
        self.sourceRootDigest = sourceRootDigest
        self.sourceCount = sourceCount
        self.artifactRootDigest = artifactRootDigest
        self.artifactCount = artifactCount
        self.investigationRootDigest = investigationRootDigest
        self.investigationEventCount = investigationEventCount
    }

    private enum CodingKeys: String, CodingKey {
        case schema, schemaVersion, formatVersion, minimumReaderVersion, projectID
        case generation, baseGeneration, generationRecordDigest, sourceRootDigest
        case sourceCount, artifactRootDigest, artifactCount
        case investigationRootDigest, investigationEventCount
        case qualitativeRootDigest, qualitativeEventCount
    }

    /// Decodes schema 3 and the additive schema 2 compatibility projection.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(String.self, forKey: .schema)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        minimumReaderVersion = try container.decode(Int.self, forKey: .minimumReaderVersion)
        projectID = try container.decode(ProjectID.self, forKey: .projectID)
        generation = try container.decode(Int.self, forKey: .generation)
        baseGeneration = try container.decodeIfPresent(Int.self, forKey: .baseGeneration)
        generationRecordDigest = try container.decode(
            String.self,
            forKey: .generationRecordDigest
        )
        sourceRootDigest = try container.decode(String.self, forKey: .sourceRootDigest)
        sourceCount = try container.decode(Int.self, forKey: .sourceCount)
        artifactRootDigest = try container.decode(String.self, forKey: .artifactRootDigest)
        artifactCount = try container.decode(Int.self, forKey: .artifactCount)
        if schemaVersion == Self.previousSchemaVersion {
            investigationRootDigest =
                try container.decodeIfPresent(
                    String.self,
                    forKey: .investigationRootDigest
                ) ?? Self.emptyInvestigationRootDigest
            investigationEventCount =
                try container.decodeIfPresent(
                    Int.self,
                    forKey: .investigationEventCount
                ) ?? 0
        } else {
            investigationRootDigest = try container.decode(
                String.self,
                forKey: .investigationRootDigest
            )
            investigationEventCount = try container.decode(
                Int.self,
                forKey: .investigationEventCount
            )
        }
        qualitativeRootDigest = try container.decodeIfPresent(
            String.self, forKey: .qualitativeRootDigest)
        qualitativeEventCount = try container.decodeIfPresent(
            Int.self, forKey: .qualitativeEventCount)
    }

    /// Qualitative-history root, the empty root when absent.
    var resolvedQualitativeRootDigest: String {
        qualitativeRootDigest ?? Self.emptyQualitativeRootDigest
    }

    /// Qualitative event count, zero when absent.
    var resolvedQualitativeEventCount: Int {
        qualitativeEventCount ?? 0
    }
}

/// Owns transactional reads and writes for one local `.glifi` package.
public actor GlifiProjectPackage {
    /// Maximum accepted root-manifest size before decoding.
    public static let maximumManifestByteCount = 1_048_576
    /// Maximum accepted canonical descriptor size.
    public static let maximumDescriptorByteCount = 1_048_576
    /// Maximum accepted output-artifact size for the current local slice.
    public static let maximumArtifactByteCount = 67_108_864
    /// Maximum accepted bytes for one immutable cognitive-history event.
    public static let maximumInvestigationEventByteCount = 1_048_576

    private let packageURL: URL
    private var currentSnapshot: GlifiProjectSnapshot

    private init(packageURL: URL, snapshot: GlifiProjectSnapshot) {
        self.packageURL = packageURL
        currentSnapshot = snapshot
    }

    /// Creates and verifies a new empty package without overwriting an existing item.
    public static func create(
        at packageURL: URL,
        projectID: ProjectID = ProjectID()
    ) throws -> GlifiProjectPackage {
        try GlifiProjectPackageIO.validateDestination(packageURL)
        let fileManager = FileManager.default
        let parentURL = packageURL.deletingLastPathComponent()
        let stagingURL = parentURL.appending(
            path: ".\(packageURL.lastPathComponent).creating-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )

        do {
            try fileManager.createDirectory(
                at: stagingURL,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
            try GlifiProjectPackageIO.createDirectories(in: stagingURL)
            let databaseURL = GlifiProjectPackageIO.databaseURL(in: stagingURL)
            let database = try GlifiSQLiteProjectStore.create(
                at: databaseURL,
                projectID: projectID
            )
            let sources: [GlifiProjectSourceRecord] = []
            let sourceRootDigest = try GlifiProjectPackageIO.sourceRootDigest(sources)
            let artifacts: [GlifiProjectArtifactRecord] = []
            let artifactRootDigest = try GlifiProjectPackageIO.artifactRootDigest(artifacts)
            let investigationEvents: [GlifiProjectInvestigationEventRecord] = []
            let investigationRootDigest = try GlifiProjectPackageIO.investigationRootDigest(
                investigationEvents
            )
            let recordDigest = try GlifiProjectPackageIO.generationRecordDigest(
                projectID: projectID,
                generation: 0,
                baseGeneration: nil,
                sourceRootDigest: sourceRootDigest,
                sourceCount: 0,
                artifactRootDigest: artifactRootDigest,
                artifactCount: 0,
                investigationRootDigest: investigationRootDigest,
                investigationEventCount: 0
            )
            try database.insertInitialGeneration(
                recordDigest: recordDigest,
                sourceRootDigest: sourceRootDigest,
                artifactRootDigest: artifactRootDigest,
                investigationRootDigest: investigationRootDigest
            )
            let manifest = GlifiProjectManifest(
                projectID: projectID,
                generation: 0,
                baseGeneration: nil,
                generationRecordDigest: recordDigest,
                sourceRootDigest: sourceRootDigest,
                sourceCount: 0,
                artifactRootDigest: artifactRootDigest,
                artifactCount: 0,
                investigationRootDigest: investigationRootDigest,
                investigationEventCount: 0
            )
            try GlifiProjectPackageIO.writeManifest(manifest, in: stagingURL)
            _ = try GlifiProjectPackageIO.openVerified(at: stagingURL)
            try fileManager.moveItem(at: stagingURL, to: packageURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw GlifiProjectPackageIO.classify(error, operation: .persistProject)
        }

        let snapshot = try GlifiProjectPackageIO.openVerified(at: packageURL)
        return GlifiProjectPackage(packageURL: packageURL, snapshot: snapshot)
    }

    /// Opens a package only after validating its manifest, store, roots, and objects.
    public static func open(at packageURL: URL) throws -> GlifiProjectPackage {
        let snapshot = try GlifiProjectPackageIO.openVerified(at: packageURL)
        return GlifiProjectPackage(packageURL: packageURL, snapshot: snapshot)
    }

    /// Attempts to open the newest previous generation that verifies completely
    /// after the manifest-referenced generation fails validation.
    ///
    /// The original package is never rewritten: a future writer can still retry
    /// a normal `open(at:)` once the cause of corruption is addressed. Throws
    /// the underlying corruption failure when the manifest itself cannot be
    /// read or no previous generation verifies.
    public static func openReadOnlyRecovery(at packageURL: URL) throws -> ReadOnlyRecovery {
        try GlifiProjectPackageIO.openReadOnlyRecovery(at: packageURL)
    }

    /// Returns the last generation verified by this package session.
    public func snapshot() -> GlifiProjectSnapshot {
        currentSnapshot
    }

    /// Incorporates one already validated immutable text snapshot transactionally.
    @discardableResult
    public func importText(
        _ importedText: GlifiImportedText,
        sourceID: SourceID = SourceID()
    ) throws -> GlifiProjectSnapshot {
        try importText(importedText, sourceID: sourceID, interruption: nil)
    }

    /// Reads a source only after checking its identity, size, and digest again.
    public func sourceData(for sourceRevisionID: SourceRevisionID) throws -> Data {
        guard
            let source = currentSnapshot.sources.first(where: {
                $0.sourceRevisionID == sourceRevisionID
            })
        else {
            throw GlifiFailure(
                code: "project.source-not-found",
                category: .insufficientData,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.source-not-found"
            )
        }
        _ = try GlifiProjectPackageIO.validatedObjectURL(
            for: source,
            in: packageURL
        )
        return try GlifiProjectPackageIO.readValidatedObject(source, in: packageURL)
    }

    /// Returns the fully verified analysis DAG selected by the current generation.
    public func analysisGraph() throws -> GlifiAnalysisGraph {
        try GlifiAnalysisGraph(currentSnapshot.artifacts.map(\.node))
    }

    /// Reads immutable artifact bytes after checking path, size, digest, and identity again.
    public func artifactData(for artifactID: ArtifactID) throws -> Data {
        guard let artifact = currentSnapshot.artifacts.first(where: { $0.artifactID == artifactID })
        else {
            throw GlifiFailure(
                code: "project.artifact-not-found",
                category: .insufficientData,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.artifact-not-found"
            )
        }
        return try GlifiProjectPackageIO.readValidatedArtifact(artifact, in: packageURL)
    }

    /// Reads and validates one immutable investigation-history event.
    public func investigationEvent(
        for eventID: InvestigationEventID
    ) throws -> GlifiInvestigationEvent {
        guard
            let record = currentSnapshot.investigationEvents.first(where: {
                $0.eventID == eventID
            })
        else {
            throw GlifiFailure(
                code: "project.investigation-event-not-found",
                category: .insufficientData,
                operation: .investigate,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.investigation-event-not-found"
            )
        }
        return try GlifiProjectPackageIO.readValidatedInvestigationEvent(
            record,
            in: packageURL
        )
    }

    /// Appends one immutable cognitive event in a recoverable project transaction.
    @discardableResult
    /// Events of the linear qualitative history, verified again on read.
    public func qualitativeEvents() throws -> [GlifiQualitativeEvent] {
        try currentSnapshot.qualitativeEvents.map {
            try GlifiProjectPackageIO.readValidatedQualitativeEvent($0, in: packageURL)
        }
    }

    /// Appends one qualitative event whose predecessor is the current head.
    public func appendQualitativeEvent(_ event: GlifiQualitativeEvent) throws
        -> GlifiProjectSnapshot
    {
        try appendQualitativeEvent(event, interruption: nil, interruptionBehavior: .throwFailure)
    }

    func appendQualitativeEvent(
        _ event: GlifiQualitativeEvent,
        interruption: GlifiProjectCommitInterruption?,
        interruptionBehavior: GlifiProjectCommitInterruptionBehavior
    ) throws -> GlifiProjectSnapshot {
        do {
            let committed = try GlifiProjectPackageIO.commitQualitativeEvent(
                event, at: packageURL, expectedSnapshot: currentSnapshot,
                interruption: interruption, interruptionBehavior: interruptionBehavior)
            currentSnapshot = committed
            return committed
        } catch {
            throw GlifiProjectPackageIO.classify(error, operation: .investigate)
        }
    }

    func appendInvestigationEvent(
        _ event: GlifiInvestigationEvent
    ) throws -> GlifiProjectSnapshot {
        let expectedSnapshot = currentSnapshot
        var coordinatedError: Error?
        var result: GlifiProjectSnapshot?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            writingItemAt: packageURL,
            options: .forMerging,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                result = try GlifiProjectPackageIO.commitInvestigationEvent(
                    event,
                    at: coordinatedURL,
                    expectedSnapshot: expectedSnapshot
                )
            } catch {
                coordinatedError = error
            }
        }
        if let coordinatedError { throw coordinatedError }
        if let coordinationError { throw coordinationError }
        guard let result else {
            throw GlifiFailure(
                code: "project.coordination-failed",
                category: .transientIO,
                operation: .persistProject,
                retryDisposition: .transientBackoff,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.coordination-failed"
            )
        }
        currentSnapshot = result
        return result
    }

    /// Commits one typed immutable analytical result and its canonical descriptor.
    @discardableResult
    public func storeArtifact<Payload: GlifiAnalysisArtifactPayload>(
        _ payload: Payload,
        descriptor: GlifiAnalysisDescriptor
    ) throws -> GlifiProjectSnapshot {
        try storeArtifact(payload, descriptor: descriptor, interruption: nil)
    }

    @discardableResult
    func importText(
        _ importedText: GlifiImportedText,
        sourceID: SourceID,
        interruption: GlifiProjectCommitInterruption?,
        interruptionBehavior: GlifiProjectCommitInterruptionBehavior = .throwFailure
    ) throws -> GlifiProjectSnapshot {
        let expectedSnapshot = currentSnapshot
        var coordinatedError: Error?
        var result: GlifiProjectSnapshot?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            writingItemAt: packageURL,
            options: .forMerging,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                result = try GlifiProjectPackageIO.commitImport(
                    importedText,
                    sourceID: sourceID,
                    at: coordinatedURL,
                    expectedSnapshot: expectedSnapshot,
                    interruption: interruption,
                    interruptionBehavior: interruptionBehavior
                )
            } catch {
                coordinatedError = error
            }
        }

        if let coordinationError {
            throw GlifiFailure(
                code: "project.coordination-failed",
                category: .transientIO,
                operation: .persistProject,
                retryDisposition: .transientBackoff,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.coordination-failed",
                arguments: ["code": String(coordinationError.code)]
            )
        }
        if let coordinatedError {
            throw GlifiProjectPackageIO.classify(coordinatedError, operation: .persistProject)
        }
        guard let result else {
            throw GlifiFailure(
                code: "project.commit-produced-no-result",
                category: .invariantViolation,
                operation: .persistProject,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.project.commit-produced-no-result"
            )
        }

        currentSnapshot = result
        return result
    }

    @discardableResult
    func storeArtifact<Payload: GlifiAnalysisArtifactPayload>(
        _ payload: Payload,
        descriptor: GlifiAnalysisDescriptor,
        interruption: GlifiProjectCommitInterruption?,
        interruptionBehavior: GlifiProjectCommitInterruptionBehavior = .throwFailure
    ) throws -> GlifiProjectSnapshot {
        guard descriptor.outputSchemaIdentifier == Payload.outputSchemaIdentifier else {
            throw GlifiFailure(
                code: "project.artifact-schema-mismatch",
                category: .invalidInput,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.project.artifact-schema-mismatch"
            )
        }
        let data = try GlifiArtifactCanonicalJSON.encode(payload)
        guard data.count <= Self.maximumArtifactByteCount else {
            throw GlifiFailure(
                code: "project.artifact-too-large",
                category: .insufficientResources,
                operation: .persistProject,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.project.artifact-too-large"
            )
        }
        let expectedSnapshot = currentSnapshot
        var coordinatedError: Error?
        var result: GlifiProjectSnapshot?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(
            writingItemAt: packageURL,
            options: .forMerging,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                result = try GlifiProjectPackageIO.commitArtifact(
                    data,
                    descriptor: descriptor,
                    at: coordinatedURL,
                    expectedSnapshot: expectedSnapshot,
                    interruption: interruption,
                    interruptionBehavior: interruptionBehavior
                )
            } catch {
                coordinatedError = error
            }
        }

        if let coordinationError {
            throw GlifiFailure(
                code: "project.coordination-failed",
                category: .transientIO,
                operation: .persistProject,
                retryDisposition: .transientBackoff,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.coordination-failed",
                arguments: ["code": String(coordinationError.code)]
            )
        }
        if let coordinatedError {
            throw GlifiProjectPackageIO.classify(coordinatedError, operation: .persistProject)
        }
        guard let result else {
            throw GlifiFailure(
                code: "project.commit-produced-no-result",
                category: .invariantViolation,
                operation: .persistProject,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.project.commit-produced-no-result"
            )
        }
        currentSnapshot = result
        return result
    }
}

extension GlifiProjectPackage {
    /// A read-only handle on one generation older than the manifest-referenced
    /// one, opened after the current generation failed validation.
    ///
    /// It never mutates the package: writer-only operations are only on
    /// `GlifiProjectPackage`.
    public struct ReadOnlyRecovery: Sendable {
        /// Location of the package this snapshot was recovered from.
        public let packageURL: URL
        /// The newest previous generation that verified completely on its own.
        public let snapshot: GlifiProjectSnapshot

        /// Reads a source only after checking its identity, size, and digest again.
        public func sourceData(for sourceRevisionID: SourceRevisionID) throws -> Data {
            guard
                let source = snapshot.sources.first(where: {
                    $0.sourceRevisionID == sourceRevisionID
                })
            else {
                throw GlifiFailure(
                    code: "project.source-not-found",
                    category: .insufficientData,
                    operation: .persistProject,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.project.source-not-found"
                )
            }
            _ = try GlifiProjectPackageIO.validatedObjectURL(
                for: source,
                in: packageURL
            )
            return try GlifiProjectPackageIO.readValidatedObject(source, in: packageURL)
        }

        /// Reads immutable artifact bytes after checking path, size, digest, and identity again.
        public func artifactData(for artifactID: ArtifactID) throws -> Data {
            guard
                let artifact = snapshot.artifacts.first(where: { $0.artifactID == artifactID })
            else {
                throw GlifiFailure(
                    code: "project.artifact-not-found",
                    category: .insufficientData,
                    operation: .persistProject,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.project.artifact-not-found"
                )
            }
            return try GlifiProjectPackageIO.readValidatedArtifact(artifact, in: packageURL)
        }

        /// Reads and validates one immutable investigation-history event.
        public func investigationEvent(
            for eventID: InvestigationEventID
        ) throws -> GlifiInvestigationEvent {
            guard
                let record = snapshot.investigationEvents.first(where: {
                    $0.eventID == eventID
                })
            else {
                throw GlifiFailure(
                    code: "project.investigation-event-not-found",
                    category: .insufficientData,
                    operation: .investigate,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.project.investigation-event-not-found"
                )
            }
            return try GlifiProjectPackageIO.readValidatedInvestigationEvent(
                record,
                in: packageURL
            )
        }
    }
}

enum GlifiProjectCommitInterruption: String, Sendable, CaseIterable {
    case staged
    case objectPromoted
    case databasePrepared
    case manifestPrepared
    case manifestReplaced
    case databaseCommitted
}

enum GlifiProjectCommitInterruptionBehavior: Sendable {
    case throwFailure
    case invoke(@Sendable () -> Never)
}

struct GlifiStoredProjectArtifactRecord: Equatable, Sendable {
    let artifactID: ArtifactID
    let nodeID: AnalysisNodeID
    let descriptorDigest: String
    let descriptorByteCount: Int
    let descriptorObjectPath: String
    let contentDigest: String
    let byteCount: Int
    let objectPath: String
    let outputSchemaIdentifier: String
}

private enum GlifiProjectPackageIO {
    private static var fileManager: FileManager { FileManager.default }

    static func validateDestination(_ url: URL) throws {
        guard url.isFileURL,
            url.pathExtension.lowercased() == "glifi",
            !fileManager.fileExists(atPath: url.path)
        else {
            throw GlifiFailure(
                code: "project.invalid-destination",
                category: .invalidInput,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.project.invalid-destination"
            )
        }
        let parent = url.deletingLastPathComponent()
        let values = try parent.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw GlifiFailure(
                code: "project.invalid-parent",
                category: .invalidInput,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.project.invalid-parent"
            )
        }
    }

    static func createDirectories(in packageURL: URL) throws {
        for path in [
            "store",
            "sources/objects/sha256",
            "representations/objects/sha256",
            "artifacts/objects/sha256",
            "artifacts/descriptors/sha256",
            "investigations/events/sha256",
            "history",
            "transactions",
        ] {
            try fileManager.createDirectory(
                at: packageURL.appending(path: path, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }
    }

    static func databaseURL(in packageURL: URL) -> URL {
        packageURL.appending(path: "store/project.sqlite", directoryHint: .notDirectory)
    }

    static func manifestURL(in packageURL: URL) -> URL {
        packageURL.appending(path: "manifest.json", directoryHint: .notDirectory)
    }

    static func writeManifest(_ manifest: GlifiProjectManifest, in packageURL: URL) throws {
        let data = try GlifiCanonicalJSON.encode(manifest)
        guard data.count <= GlifiProjectPackage.maximumManifestByteCount else {
            throw GlifiFailure(
                code: "project.manifest-too-large",
                category: .insufficientResources,
                operation: .persistProject,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.project.manifest-too-large"
            )
        }
        try durableWrite(data, to: manifestURL(in: packageURL))
    }

    static func openVerified(at packageURL: URL) throws -> GlifiProjectSnapshot {
        do {
            let packageValues = try packageURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
            guard packageValues.isDirectory == true, packageValues.isSymbolicLink != true else {
                throw corruption("project.invalid-package")
            }

            let manifestURL = manifestURL(in: packageURL)
            let manifestValues = try manifestURL.resourceValues(forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ])
            guard manifestValues.isRegularFile == true,
                manifestValues.isSymbolicLink != true,
                let manifestSize = manifestValues.fileSize,
                manifestSize <= GlifiProjectPackage.maximumManifestByteCount
            else {
                throw corruption("project.invalid-manifest-file")
            }
            let observation = try readFile(
                "manifest.json", in: packageURL,
                maximumByteCount: GlifiProjectPackage.maximumManifestByteCount,
                retainBytes: true
            )
            guard let data = observation.data else {
                throw corruption("project.invalid-manifest-file")
            }
            let manifest = try JSONDecoder().decode(GlifiProjectManifest.self, from: data)
            try validate(manifest)

            let database = try GlifiSQLiteProjectStore.open(at: databaseURL(in: packageURL))
            try database.migrateIfNeeded(
                projectID: manifest.projectID,
                emptyInvestigationRootDigest: GlifiProjectManifest.emptyInvestigationRootDigest
            )
            try database.validateIntegrity(projectID: manifest.projectID)
            let generation = try database.generation(manifest.generation)
            guard generation.state == "prepared" || generation.state == "committed",
                generation.baseGeneration == manifest.baseGeneration,
                generation.recordDigest == manifest.generationRecordDigest,
                generation.sourceRootDigest == manifest.sourceRootDigest,
                generation.sourceCount == manifest.sourceCount,
                generation.artifactRootDigest == manifest.artifactRootDigest,
                generation.artifactCount == manifest.artifactCount,
                generation.investigationRootDigest == manifest.investigationRootDigest,
                generation.investigationEventCount == manifest.investigationEventCount,
                generation.qualitativeRootDigest == manifest.resolvedQualitativeRootDigest,
                generation.qualitativeEventCount == manifest.resolvedQualitativeEventCount
            else {
                throw corruption("project.generation-mismatch")
            }

            let sources = try database.sources(generation: manifest.generation)
            guard sources.count == manifest.sourceCount,
                try sourceRootDigest(sources) == manifest.sourceRootDigest
            else {
                throw corruption("project.source-root-mismatch")
            }
            for source in sources {
                _ = try validatedObjectURL(for: source, in: packageURL)
            }
            let storedArtifacts = try database.artifacts(generation: manifest.generation)
            let artifacts = try storedArtifacts.map {
                try validatedArtifactRecord(for: $0, in: packageURL)
            }
            guard artifacts.count == manifest.artifactCount,
                try artifactRootDigest(artifacts) == manifest.artifactRootDigest
            else {
                throw corruption("project.artifact-root-mismatch")
            }
            let artifactsMatchCorpus = try artifacts.allSatisfy {
                try artifactMatchesCorpus(
                    $0.node.descriptor, sources: sources, rootDigest: manifest.sourceRootDigest)
            }
            guard artifactsMatchCorpus else {
                throw corruption("project.artifact-corpus-mismatch")
            }
            do {
                let graph = try GlifiAnalysisGraph(artifacts.map(\.node))
                let reusable = try graph.reusableNodeIDs(
                    from: artifacts.map { try $0.reference }
                )
                guard reusable.count == artifacts.count else {
                    throw corruption("project.artifact-graph-mismatch")
                }
            } catch {
                throw corruption("project.artifact-graph-mismatch")
            }
            let investigationEvents = try database.investigationEvents(
                generation: manifest.generation
            )
            guard investigationEvents.count == manifest.investigationEventCount,
                try investigationRootDigest(investigationEvents)
                    == manifest.investigationRootDigest
            else {
                throw corruption("project.investigation-root-mismatch")
            }
            var decodedEvents: [InvestigationEventID: GlifiInvestigationEvent] = [:]
            decodedEvents.reserveCapacity(investigationEvents.count)
            for record in investigationEvents {
                let event = try readValidatedInvestigationEvent(record, in: packageURL)
                guard decodedEvents.updateValue(event, forKey: record.eventID) == nil else {
                    throw corruption("project.investigation-history-mismatch")
                }
            }
            let predecessorIDs = Set(decodedEvents.values.compactMap(\.predecessorEventID))
            for event in decodedEvents.values {
                if let predecessor = event.predecessorEventID {
                    guard decodedEvents[predecessor]?.investigationID == event.investigationID
                    else {
                        throw corruption("project.investigation-history-mismatch")
                    }
                }
            }
            let headIDs = decodedEvents.keys.filter { !predecessorIDs.contains($0) }
            do {
                var reachable = Set<InvestigationEventID>()
                for headID in headIDs {
                    let investigation = try GlifiInvestigation(
                        headEventID: headID,
                        eventsByID: decodedEvents
                    )
                    reachable.formUnion(investigation.eventIDs)
                }
                guard reachable.count == decodedEvents.count else {
                    throw corruption("project.investigation-history-mismatch")
                }
            } catch {
                throw corruption("project.investigation-history-mismatch")
            }
            return GlifiProjectSnapshot(
                projectID: manifest.projectID,
                generation: manifest.generation,
                generationRecordDigest: manifest.generationRecordDigest,
                sources: sources,
                sourceRootDigest: manifest.sourceRootDigest,
                artifacts: artifacts,
                artifactRootDigest: manifest.artifactRootDigest,
                investigationEvents: investigationEvents,
                investigationRootDigest: manifest.investigationRootDigest,
                qualitativeEvents: try verifiedQualitativeHistory(
                    database: database, count: manifest.resolvedQualitativeEventCount,
                    rootDigest: manifest.resolvedQualitativeRootDigest, in: packageURL),
                qualitativeRootDigest: manifest.resolvedQualitativeRootDigest
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch let decodingError as DecodingError {
            _ = decodingError
            throw corruption("project.manifest-invalid")
        } catch {
            throw classify(error, operation: .persistProject)
        }
    }

    /// Opens the newest generation older than the manifest-referenced one that
    /// verifies completely on its own, independent of the manifest that failed.
    ///
    /// Never rewrites the manifest, database, or any object.
    static func openReadOnlyRecovery(
        at packageURL: URL
    ) throws -> GlifiProjectPackage.ReadOnlyRecovery {
        do {
            let packageValues = try packageURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ])
            guard packageValues.isDirectory == true, packageValues.isSymbolicLink != true else {
                throw corruption("project.invalid-package")
            }

            let manifestURL = manifestURL(in: packageURL)
            let manifestValues = try manifestURL.resourceValues(forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ])
            guard manifestValues.isRegularFile == true,
                manifestValues.isSymbolicLink != true,
                let manifestSize = manifestValues.fileSize,
                manifestSize <= GlifiProjectPackage.maximumManifestByteCount
            else {
                throw corruption("project.invalid-manifest-file")
            }
            let observation = try readFile(
                "manifest.json", in: packageURL,
                maximumByteCount: GlifiProjectPackage.maximumManifestByteCount,
                retainBytes: true
            )
            guard let data = observation.data else {
                throw corruption("project.invalid-manifest-file")
            }
            let manifest = try JSONDecoder().decode(GlifiProjectManifest.self, from: data)
            try validate(manifest)

            let database = try GlifiSQLiteProjectStore.open(at: databaseURL(in: packageURL))
            try database.migrateIfNeeded(
                projectID: manifest.projectID,
                emptyInvestigationRootDigest: GlifiProjectManifest.emptyInvestigationRootDigest
            )
            try database.validateIntegrity(projectID: manifest.projectID)

            var candidateGeneration = manifest.generation - 1
            while candidateGeneration >= 0 {
                if let snapshot = try? verifiedHistoricalSnapshot(
                    generation: candidateGeneration,
                    projectID: manifest.projectID,
                    database: database,
                    packageURL: packageURL
                ) {
                    return GlifiProjectPackage.ReadOnlyRecovery(
                        packageURL: packageURL,
                        snapshot: snapshot
                    )
                }
                candidateGeneration -= 1
            }
            throw corruption("project.no-recoverable-generation")
        } catch let failure as GlifiFailure {
            throw failure
        } catch let decodingError as DecodingError {
            _ = decodingError
            throw corruption("project.manifest-invalid")
        } catch {
            throw classify(error, operation: .persistProject)
        }
    }

    /// Fully re-verifies one specific generation against its own stored digests,
    /// independent of the current manifest.
    ///
    /// Used only by read-only recovery.
    private static func verifiedHistoricalSnapshot(
        generation generationNumber: Int,
        projectID: ProjectID,
        database: GlifiSQLiteProjectStore,
        packageURL: URL
    ) throws -> GlifiProjectSnapshot {
        let generation = try database.generation(generationNumber)
        guard generation.state == "committed" else {
            throw corruption("project.generation-not-committed")
        }
        let sources = try database.sources(generation: generationNumber)
        guard sources.count == generation.sourceCount,
            try sourceRootDigest(sources) == generation.sourceRootDigest
        else {
            throw corruption("project.source-root-mismatch")
        }
        for source in sources {
            _ = try validatedObjectURL(for: source, in: packageURL)
        }
        let storedArtifacts = try database.artifacts(generation: generationNumber)
        let artifacts = try storedArtifacts.map {
            try validatedArtifactRecord(for: $0, in: packageURL)
        }
        guard artifacts.count == generation.artifactCount,
            try artifactRootDigest(artifacts) == generation.artifactRootDigest
        else {
            throw corruption("project.artifact-root-mismatch")
        }
        let artifactsMatchCorpus = try artifacts.allSatisfy {
            try artifactMatchesCorpus(
                $0.node.descriptor, sources: sources, rootDigest: generation.sourceRootDigest)
        }
        guard artifactsMatchCorpus else {
            throw corruption("project.artifact-corpus-mismatch")
        }
        do {
            let graph = try GlifiAnalysisGraph(artifacts.map(\.node))
            let reusable = try graph.reusableNodeIDs(
                from: artifacts.map { try $0.reference }
            )
            guard reusable.count == artifacts.count else {
                throw corruption("project.artifact-graph-mismatch")
            }
        } catch {
            throw corruption("project.artifact-graph-mismatch")
        }
        let investigationEvents = try database.investigationEvents(
            generation: generationNumber
        )
        guard investigationEvents.count == generation.investigationEventCount,
            try investigationRootDigest(investigationEvents)
                == generation.investigationRootDigest
        else {
            throw corruption("project.investigation-root-mismatch")
        }
        var decodedEvents: [InvestigationEventID: GlifiInvestigationEvent] = [:]
        decodedEvents.reserveCapacity(investigationEvents.count)
        for record in investigationEvents {
            let event = try readValidatedInvestigationEvent(record, in: packageURL)
            guard decodedEvents.updateValue(event, forKey: record.eventID) == nil else {
                throw corruption("project.investigation-history-mismatch")
            }
        }
        let predecessorIDs = Set(decodedEvents.values.compactMap(\.predecessorEventID))
        for event in decodedEvents.values {
            if let predecessor = event.predecessorEventID {
                guard decodedEvents[predecessor]?.investigationID == event.investigationID
                else {
                    throw corruption("project.investigation-history-mismatch")
                }
            }
        }
        let headIDs = decodedEvents.keys.filter { !predecessorIDs.contains($0) }
        do {
            var reachable = Set<InvestigationEventID>()
            for headID in headIDs {
                let investigation = try GlifiInvestigation(
                    headEventID: headID,
                    eventsByID: decodedEvents
                )
                reachable.formUnion(investigation.eventIDs)
            }
            guard reachable.count == decodedEvents.count else {
                throw corruption("project.investigation-history-mismatch")
            }
        } catch {
            throw corruption("project.investigation-history-mismatch")
        }
        return GlifiProjectSnapshot(
            projectID: projectID,
            generation: generationNumber,
            generationRecordDigest: generation.recordDigest,
            sources: sources,
            sourceRootDigest: generation.sourceRootDigest,
            artifacts: artifacts,
            artifactRootDigest: generation.artifactRootDigest,
            investigationEvents: investigationEvents,
            investigationRootDigest: generation.investigationRootDigest,
            qualitativeEvents: try verifiedQualitativeHistory(
                database: database, count: generation.qualitativeEventCount,
                rootDigest: generation.qualitativeRootDigest, in: packageURL),
            qualitativeRootDigest: generation.qualitativeRootDigest
        )
    }

    /// Reads the first `count` qualitative events and verifies root, objects and chain.
    static func verifiedQualitativeHistory(
        database: GlifiSQLiteProjectStore,
        count: Int,
        rootDigest: String,
        in packageURL: URL
    ) throws -> [GlifiProjectQualitativeEventRecord] {
        let records = try database.qualitativeEvents(count: count)
        guard try qualitativeRootDigest(records) == rootDigest else {
            throw corruption("project.qualitative-root-mismatch")
        }
        do {
            _ = try GlifiQualitativeState(
                events: try records.map { try readValidatedQualitativeEvent($0, in: packageURL) })
        } catch {
            throw corruption("project.qualitative-history-mismatch")
        }
        return records
    }

    /// Root digest of the ordered qualitative history.
    static func qualitativeRootDigest(_ records: [GlifiProjectQualitativeEventRecord]) throws
        -> String
    {
        digest(try GlifiCanonicalJSON.encode(records))
    }

    static func qualitativeEventObjectPath(for contentDigest: String) throws -> String {
        guard isSHA256Digest(contentDigest) else {
            throw corruption("project.invalid-qualitative-event-digest")
        }
        let hex = String(contentDigest.dropFirst("sha256:".count))
        return "qualitative/events/sha256/\(hex.prefix(2))/\(hex).json"
    }

    /// Reads one qualitative event after checking path, size, digest and identity.
    static func readValidatedQualitativeEvent(
        _ record: GlifiProjectQualitativeEventRecord,
        in packageURL: URL
    ) throws -> GlifiQualitativeEvent {
        guard record.objectPath == (try qualitativeEventObjectPath(for: record.contentDigest)),
            record.byteCount > 0,
            record.byteCount <= GlifiProjectPackage.maximumInvestigationEventByteCount
        else {
            throw corruption("project.illegal-qualitative-event-reference")
        }
        let observation = try readFile(
            record.objectPath, in: packageURL,
            maximumByteCount: record.byteCount,
            retainBytes: true
        )
        guard observation.byteCount == record.byteCount,
            observation.digest == record.contentDigest,
            let data = observation.data,
            let event = try? JSONDecoder().decode(GlifiQualitativeEvent.self, from: data),
            (try? event.eventID()) == record.eventID,
            event.predecessorEventID == record.predecessorEventID
        else {
            throw corruption("project.qualitative-event-mismatch")
        }
        return event
    }

    static func commitImport(
        _ importedText: GlifiImportedText,
        sourceID: SourceID,
        at packageURL: URL,
        expectedSnapshot: GlifiProjectSnapshot,
        interruption: GlifiProjectCommitInterruption?,
        interruptionBehavior: GlifiProjectCommitInterruptionBehavior
    ) throws -> GlifiProjectSnapshot {
        let writerLease = try GlifiProjectWriterLease.acquire(in: packageURL)
        defer { writerLease.release() }
        let observedSnapshot = try openVerified(at: packageURL)
        guard observedSnapshot.projectID == expectedSnapshot.projectID,
            observedSnapshot.generation == expectedSnapshot.generation,
            observedSnapshot.sourceRootDigest == expectedSnapshot.sourceRootDigest,
            observedSnapshot.artifactRootDigest == expectedSnapshot.artifactRootDigest,
            observedSnapshot.investigationRootDigest == expectedSnapshot.investigationRootDigest,
            observedSnapshot.qualitativeRootDigest == expectedSnapshot.qualitativeRootDigest
        else {
            throw GlifiFailure(
                code: "project.stale-generation",
                category: .staleArtifact,
                operation: .persistProject,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.stale-generation"
            )
        }

        let transactionID = UUID().uuidString.lowercased()
        let transactionURL = packageURL.appending(
            path: "transactions/\(transactionID)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: transactionURL, withIntermediateDirectories: false)
        let transactionState = TransactionState(
            transactionID: transactionID,
            baseGeneration: observedSnapshot.generation,
            targetGeneration: observedSnapshot.generation + 1,
            state: "staging"
        )
        try durableWrite(
            try GlifiCanonicalJSON.encode(transactionState),
            to: transactionURL.appending(path: "transaction.json")
        )
        try interruptIfRequested(.staged, interruption, behavior: interruptionBehavior)

        let objectPath = try objectPath(for: importedText.contentDigest)
        let source = GlifiProjectSourceRecord(
            sourceID: sourceID,
            sourceRevisionID: importedText.sourceRevisionID,
            format: importedText.format,
            contentDigest: importedText.contentDigest,
            byteCount: importedText.bytes.count,
            objectPath: objectPath
        )
        let stagedObjectURL = transactionURL.appending(path: "source-object")
        try durableWrite(importedText.bytes, to: stagedObjectURL)
        try promoteObject(stagedObjectURL, source: source, in: packageURL)
        try interruptIfRequested(.objectPromoted, interruption, behavior: interruptionBehavior)

        var sources = observedSnapshot.sources
        sources.append(source)
        sources.sort { $0.sourceRevisionID.canonicalValue < $1.sourceRevisionID.canonicalValue }
        let sourceRootDigest = try sourceRootDigest(sources)
        // Un'importazione invalida soltanto gli Artifact il cui corpus è cambiato (ADR-0028):
        // quelli legati a revisioni ancora presenti sopravvivono, con la loro catena.
        let artifacts = try retainedArtifacts(
            observedSnapshot.artifacts, sources: sources, rootDigest: sourceRootDigest)
        let artifactRootDigest = try artifactRootDigest(artifacts)
        let investigationRootDigest = observedSnapshot.investigationRootDigest
        let targetGeneration = observedSnapshot.generation + 1
        let recordDigest = try generationRecordDigest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            sourceRootDigest: sourceRootDigest,
            sourceCount: sources.count,
            artifactRootDigest: artifactRootDigest,
            artifactCount: artifacts.count,
            investigationRootDigest: investigationRootDigest,
            investigationEventCount: observedSnapshot.investigationEvents.count,
            qualitativeRootDigest: observedSnapshot.qualitativeRootDigest,
            qualitativeEventCount: observedSnapshot.qualitativeEvents.count
        )
        let database = try GlifiSQLiteProjectStore.open(at: databaseURL(in: packageURL))
        try database.discardGenerations(after: observedSnapshot.generation)
        try database.prepareSourceGeneration(
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            recordDigest: recordDigest,
            sourceRootDigest: sourceRootDigest,
            artifactRootDigest: artifactRootDigest,
            artifacts: artifacts.map(storedRecord),
            investigationRootDigest: investigationRootDigest,
            source: source
        )
        try interruptIfRequested(.databasePrepared, interruption, behavior: interruptionBehavior)

        let manifest = GlifiProjectManifest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            generationRecordDigest: recordDigest,
            sourceRootDigest: sourceRootDigest,
            sourceCount: sources.count,
            artifactRootDigest: artifactRootDigest,
            artifactCount: artifacts.count,
            investigationRootDigest: investigationRootDigest,
            investigationEventCount: observedSnapshot.investigationEvents.count,
            qualitativeRootDigest: observedSnapshot.qualitativeRootDigest,
            qualitativeEventCount: observedSnapshot.qualitativeEvents.count
        )
        let candidateURL = transactionURL.appending(path: "manifest.json")
        try durableWrite(try GlifiCanonicalJSON.encode(manifest), to: candidateURL)
        let decodedCandidate = try JSONDecoder().decode(
            GlifiProjectManifest.self,
            from: Data(contentsOf: candidateURL)
        )
        try validate(decodedCandidate)
        try interruptIfRequested(.manifestPrepared, interruption, behavior: interruptionBehavior)

        let rootManifestURL = manifestURL(in: packageURL)
        _ = try fileManager.replaceItemAt(rootManifestURL, withItemAt: candidateURL)
        try interruptIfRequested(.manifestReplaced, interruption, behavior: interruptionBehavior)

        try database.markCommitted(generation: targetGeneration)
        try interruptIfRequested(.databaseCommitted, interruption, behavior: interruptionBehavior)

        try? fileManager.removeItem(at: transactionURL)
        return try openVerified(at: packageURL)
    }

    static func commitArtifact(
        _ data: Data,
        descriptor: GlifiAnalysisDescriptor,
        at packageURL: URL,
        expectedSnapshot: GlifiProjectSnapshot,
        interruption: GlifiProjectCommitInterruption?,
        interruptionBehavior: GlifiProjectCommitInterruptionBehavior
    ) throws -> GlifiProjectSnapshot {
        let writerLease = try GlifiProjectWriterLease.acquire(in: packageURL)
        defer { writerLease.release() }
        let observedSnapshot = try openVerified(at: packageURL)
        guard observedSnapshot.projectID == expectedSnapshot.projectID,
            observedSnapshot.generation == expectedSnapshot.generation,
            observedSnapshot.sourceRootDigest == expectedSnapshot.sourceRootDigest,
            observedSnapshot.artifactRootDigest == expectedSnapshot.artifactRootDigest,
            observedSnapshot.investigationRootDigest == expectedSnapshot.investigationRootDigest,
            observedSnapshot.qualitativeRootDigest == expectedSnapshot.qualitativeRootDigest
        else {
            throw GlifiFailure(
                code: "project.stale-generation",
                category: .staleArtifact,
                operation: .persistProject,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.stale-generation"
            )
        }
        guard
            try artifactMatchesCorpus(
                descriptor,
                sources: observedSnapshot.sources,
                rootDigest: observedSnapshot.sourceRootDigest)
        else {
            throw GlifiFailure(
                code: "project.artifact-corpus-mismatch",
                category: .staleArtifact,
                operation: .persistProject,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.artifact-corpus-mismatch"
            )
        }

        let node = try GlifiAnalysisNode(descriptor: descriptor)
        let descriptorData = try GlifiCanonicalJSON.encode(descriptor)
        guard descriptorData.count <= GlifiProjectPackage.maximumDescriptorByteCount else {
            throw GlifiFailure(
                code: "project.descriptor-too-large",
                category: .insufficientResources,
                operation: .persistProject,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.project.descriptor-too-large"
            )
        }
        let descriptorDigest = digest(descriptorData)
        guard descriptorDigest == (try descriptor.canonicalDigest()) else {
            throw GlifiFailure(
                code: "project.descriptor-canonicalization-mismatch",
                category: .invariantViolation,
                operation: .persistProject,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.project.descriptor-canonicalization-mismatch"
            )
        }
        let contentDigest = digest(data)
        let artifact = GlifiProjectArtifactRecord(
            artifactID: try ArtifactID(digest: contentDigest),
            node: node,
            descriptorDigest: descriptorDigest,
            descriptorByteCount: descriptorData.count,
            descriptorObjectPath: try descriptorObjectPath(for: descriptorDigest),
            contentDigest: contentDigest,
            byteCount: data.count,
            objectPath: try artifactObjectPath(for: contentDigest)
        )
        if observedSnapshot.artifacts.contains(artifact) {
            return observedSnapshot
        }

        var artifacts = observedSnapshot.artifacts
        if artifacts.contains(where: { $0.node.id == node.id }) {
            let graph = try GlifiAnalysisGraph(artifacts.map(\.node))
            let invalidated = Set(try graph.invalidatedNodeIDs(changing: [node.id]))
            artifacts.removeAll { invalidated.contains($0.node.id) }
        }
        artifacts.append(artifact)
        artifacts.sort { $0.node.id.canonicalValue < $1.node.id.canonicalValue }
        guard artifacts.count <= GlifiAnalysisGraphLimits.standard.maximumNodeCount else {
            throw GlifiFailure(
                code: "project.artifact-limit-exceeded",
                category: .insufficientResources,
                operation: .persistProject,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.project.artifact-limit-exceeded"
            )
        }
        let candidateGraph = try GlifiAnalysisGraph(artifacts.map(\.node))
        let reusable = try candidateGraph.reusableNodeIDs(
            from: artifacts.map { try $0.reference }
        )
        guard reusable.count == artifacts.count else {
            throw GlifiFailure(
                code: "project.artifact-dependency-mismatch",
                category: .staleArtifact,
                operation: .persistProject,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.artifact-dependency-mismatch"
            )
        }

        let transactionID = UUID().uuidString.lowercased()
        let transactionURL = packageURL.appending(
            path: "transactions/\(transactionID)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: transactionURL, withIntermediateDirectories: false)
        let targetGeneration = observedSnapshot.generation + 1
        let transactionState = TransactionState(
            transactionID: transactionID,
            baseGeneration: observedSnapshot.generation,
            targetGeneration: targetGeneration,
            state: "staging"
        )
        try durableWrite(
            try GlifiCanonicalJSON.encode(transactionState),
            to: transactionURL.appending(path: "transaction.json")
        )
        try interruptIfRequested(.staged, interruption, behavior: interruptionBehavior)

        let stagedDescriptorURL = transactionURL.appending(path: "descriptor-object")
        try durableWrite(descriptorData, to: stagedDescriptorURL)
        try promoteArtifactObject(
            stagedDescriptorURL,
            relativePath: artifact.descriptorObjectPath,
            expectedDigest: artifact.descriptorDigest,
            expectedByteCount: artifact.descriptorByteCount,
            maximumByteCount: GlifiProjectPackage.maximumDescriptorByteCount,
            in: packageURL
        )
        let stagedArtifactURL = transactionURL.appending(path: "artifact-object")
        try durableWrite(data, to: stagedArtifactURL)
        try promoteArtifactObject(
            stagedArtifactURL,
            relativePath: artifact.objectPath,
            expectedDigest: artifact.contentDigest,
            expectedByteCount: artifact.byteCount,
            maximumByteCount: GlifiProjectPackage.maximumArtifactByteCount,
            in: packageURL
        )
        try interruptIfRequested(.objectPromoted, interruption, behavior: interruptionBehavior)

        let artifactRootDigest = try artifactRootDigest(artifacts)
        let investigationRootDigest = observedSnapshot.investigationRootDigest
        let recordDigest = try generationRecordDigest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            sourceCount: observedSnapshot.sources.count,
            artifactRootDigest: artifactRootDigest,
            artifactCount: artifacts.count,
            investigationRootDigest: investigationRootDigest,
            investigationEventCount: observedSnapshot.investigationEvents.count,
            qualitativeRootDigest: observedSnapshot.qualitativeRootDigest,
            qualitativeEventCount: observedSnapshot.qualitativeEvents.count
        )
        let database = try GlifiSQLiteProjectStore.open(at: databaseURL(in: packageURL))
        try database.discardGenerations(after: observedSnapshot.generation)
        try database.prepareArtifactGeneration(
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            recordDigest: recordDigest,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            artifactRootDigest: artifactRootDigest,
            artifacts: artifacts.map(storedRecord),
            investigationRootDigest: investigationRootDigest
        )
        try interruptIfRequested(.databasePrepared, interruption, behavior: interruptionBehavior)

        let manifest = GlifiProjectManifest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            generationRecordDigest: recordDigest,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            sourceCount: observedSnapshot.sources.count,
            artifactRootDigest: artifactRootDigest,
            artifactCount: artifacts.count,
            investigationRootDigest: investigationRootDigest,
            investigationEventCount: observedSnapshot.investigationEvents.count,
            qualitativeRootDigest: observedSnapshot.qualitativeRootDigest,
            qualitativeEventCount: observedSnapshot.qualitativeEvents.count
        )
        let candidateURL = transactionURL.appending(path: "manifest.json")
        try durableWrite(try GlifiCanonicalJSON.encode(manifest), to: candidateURL)
        let decodedCandidate = try JSONDecoder().decode(
            GlifiProjectManifest.self,
            from: Data(contentsOf: candidateURL)
        )
        try validate(decodedCandidate)
        try interruptIfRequested(.manifestPrepared, interruption, behavior: interruptionBehavior)

        _ = try fileManager.replaceItemAt(manifestURL(in: packageURL), withItemAt: candidateURL)
        try interruptIfRequested(.manifestReplaced, interruption, behavior: interruptionBehavior)
        try database.markCommitted(generation: targetGeneration)
        try interruptIfRequested(.databaseCommitted, interruption, behavior: interruptionBehavior)

        try? fileManager.removeItem(at: transactionURL)
        return try openVerified(at: packageURL)
    }

    /// Appends one event to the linear qualitative history in a new generation.
    static func commitQualitativeEvent(
        _ event: GlifiQualitativeEvent,
        at packageURL: URL,
        expectedSnapshot: GlifiProjectSnapshot,
        interruption: GlifiProjectCommitInterruption? = nil,
        interruptionBehavior: GlifiProjectCommitInterruptionBehavior = .throwFailure
    ) throws -> GlifiProjectSnapshot {
        let writerLease = try GlifiProjectWriterLease.acquire(in: packageURL)
        defer { writerLease.release() }
        let observedSnapshot = try openVerified(at: packageURL)
        guard observedSnapshot.projectID == expectedSnapshot.projectID,
            observedSnapshot.generation == expectedSnapshot.generation,
            observedSnapshot.qualitativeRootDigest == expectedSnapshot.qualitativeRootDigest,
            event.predecessorEventID == observedSnapshot.qualitativeEvents.last?.eventID
        else {
            throw GlifiFailure(
                code: "qualitative.stale-history",
                category: .staleArtifact,
                operation: .investigate,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.qualitative.stale-history"
            )
        }
        let data = try GlifiCanonicalJSON.encode(event)
        guard !data.isEmpty, data.count <= GlifiProjectPackage.maximumInvestigationEventByteCount
        else {
            throw GlifiFailure(
                code: "qualitative.event-too-large",
                category: .insufficientResources,
                operation: .investigate,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.qualitative.event-too-large"
            )
        }
        let contentDigest = digest(data)
        guard try event.eventID() == contentDigest else {
            throw corruption("project.qualitative-event-canonicalization-mismatch")
        }
        guard observedSnapshot.qualitativeEvents.count < 100_000 else {
            throw GlifiFailure(
                code: "qualitative.event-limit-exceeded",
                category: .insufficientResources,
                operation: .investigate,
                retryDisposition: .afterConditionsChange,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.qualitative.event-limit-exceeded"
            )
        }
        let record = GlifiProjectQualitativeEventRecord(
            eventID: contentDigest,
            predecessorEventID: event.predecessorEventID,
            contentDigest: contentDigest,
            byteCount: data.count,
            objectPath: try qualitativeEventObjectPath(for: contentDigest)
        )
        // La proiezione dell'intera storia valida integrità referenziale e catena prima del commit.
        var events = try observedSnapshot.qualitativeEvents.map {
            try readValidatedQualitativeEvent($0, in: packageURL)
        }
        events.append(event)
        _ = try GlifiQualitativeState(events: events)
        let records = observedSnapshot.qualitativeEvents + [record]

        let transactionID = UUID().uuidString.lowercased()
        let transactionURL = packageURL.appending(
            path: "transactions/\(transactionID)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: transactionURL, withIntermediateDirectories: false)
        let targetGeneration = observedSnapshot.generation + 1
        try durableWrite(
            try GlifiCanonicalJSON.encode(
                TransactionState(
                    transactionID: transactionID,
                    baseGeneration: observedSnapshot.generation,
                    targetGeneration: targetGeneration,
                    state: "staging"
                )
            ),
            to: transactionURL.appending(path: "transaction.json")
        )
        let stagedEventURL = transactionURL.appending(path: "qualitative-event")
        try durableWrite(data, to: stagedEventURL)
        try interruptIfRequested(.staged, interruption, behavior: interruptionBehavior)
        try promoteArtifactObject(
            stagedEventURL,
            relativePath: record.objectPath,
            expectedDigest: record.contentDigest,
            expectedByteCount: record.byteCount,
            maximumByteCount: GlifiProjectPackage.maximumInvestigationEventByteCount,
            in: packageURL
        )
        try interruptIfRequested(.objectPromoted, interruption, behavior: interruptionBehavior)
        let rootDigest = try qualitativeRootDigest(records)
        let recordDigest = try generationRecordDigest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            sourceCount: observedSnapshot.sources.count,
            artifactRootDigest: observedSnapshot.artifactRootDigest,
            artifactCount: observedSnapshot.artifacts.count,
            investigationRootDigest: observedSnapshot.investigationRootDigest,
            investigationEventCount: observedSnapshot.investigationEvents.count,
            qualitativeRootDigest: rootDigest,
            qualitativeEventCount: records.count
        )
        let database = try GlifiSQLiteProjectStore.open(at: databaseURL(in: packageURL))
        try database.discardGenerations(after: observedSnapshot.generation)
        try database.prepareQualitativeGeneration(
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            recordDigest: recordDigest,
            qualitativeRootDigest: rootDigest,
            event: record,
            sequence: observedSnapshot.qualitativeEvents.count
        )
        try interruptIfRequested(.databasePrepared, interruption, behavior: interruptionBehavior)
        let manifest = GlifiProjectManifest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            generationRecordDigest: recordDigest,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            sourceCount: observedSnapshot.sources.count,
            artifactRootDigest: observedSnapshot.artifactRootDigest,
            artifactCount: observedSnapshot.artifacts.count,
            investigationRootDigest: observedSnapshot.investigationRootDigest,
            investigationEventCount: observedSnapshot.investigationEvents.count,
            qualitativeRootDigest: rootDigest,
            qualitativeEventCount: records.count
        )
        let candidateURL = transactionURL.appending(path: "manifest.json")
        try durableWrite(try GlifiCanonicalJSON.encode(manifest), to: candidateURL)
        try validate(
            JSONDecoder().decode(
                GlifiProjectManifest.self,
                from: Data(contentsOf: candidateURL)
            )
        )
        try interruptIfRequested(.manifestPrepared, interruption, behavior: interruptionBehavior)
        _ = try fileManager.replaceItemAt(manifestURL(in: packageURL), withItemAt: candidateURL)
        try interruptIfRequested(.manifestReplaced, interruption, behavior: interruptionBehavior)
        try database.markCommitted(generation: targetGeneration)
        try interruptIfRequested(.databaseCommitted, interruption, behavior: interruptionBehavior)
        try? fileManager.removeItem(at: transactionURL)
        return try openVerified(at: packageURL)
    }

    static func commitInvestigationEvent(
        _ event: GlifiInvestigationEvent,
        at packageURL: URL,
        expectedSnapshot: GlifiProjectSnapshot
    ) throws -> GlifiProjectSnapshot {
        let writerLease = try GlifiProjectWriterLease.acquire(in: packageURL)
        defer { writerLease.release() }
        let observedSnapshot = try openVerified(at: packageURL)
        guard observedSnapshot.projectID == expectedSnapshot.projectID,
            observedSnapshot.generation == expectedSnapshot.generation,
            observedSnapshot.sourceRootDigest == expectedSnapshot.sourceRootDigest,
            observedSnapshot.artifactRootDigest == expectedSnapshot.artifactRootDigest,
            observedSnapshot.investigationRootDigest == expectedSnapshot.investigationRootDigest,
            observedSnapshot.qualitativeRootDigest == expectedSnapshot.qualitativeRootDigest
        else {
            throw GlifiFailure(
                code: "project.stale-generation",
                category: .staleArtifact,
                operation: .investigate,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.stale-generation"
            )
        }

        let data = try GlifiCanonicalJSON.encode(event)
        guard !data.isEmpty, data.count <= GlifiProjectPackage.maximumInvestigationEventByteCount
        else {
            throw GlifiFailure(
                code: "project.investigation-event-too-large",
                category: .insufficientResources,
                operation: .investigate,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.project.investigation-event-too-large"
            )
        }
        let contentDigest = digest(data)
        let eventID = try event.eventID()
        guard eventID.digest == contentDigest else {
            throw corruption("project.investigation-event-canonicalization-mismatch")
        }
        let record = GlifiProjectInvestigationEventRecord(
            eventID: eventID,
            investigationID: event.investigationID,
            predecessorEventID: event.predecessorEventID,
            contentDigest: contentDigest,
            byteCount: data.count,
            objectPath: try investigationEventObjectPath(for: contentDigest)
        )
        if observedSnapshot.investigationEvents.contains(record) { return observedSnapshot }

        let sameInvestigation = observedSnapshot.investigationEvents.filter {
            $0.investigationID == event.investigationID
        }
        if let predecessor = event.predecessorEventID {
            guard sameInvestigation.contains(where: { $0.eventID == predecessor }) else {
                throw GlifiFailure(
                    code: "investigation.predecessor-not-found",
                    category: .invalidInput,
                    operation: .investigate,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.investigation.predecessor-not-found"
                )
            }
        } else if !sameInvestigation.isEmpty {
            throw GlifiFailure(
                code: "investigation.duplicate-root",
                category: .invalidInput,
                operation: .investigate,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.investigation.duplicate-root"
            )
        }

        var events = observedSnapshot.investigationEvents
        events.append(record)
        events.sort { $0.eventID.canonicalValue < $1.eventID.canonicalValue }
        guard events.count <= 100_000 else {
            throw GlifiFailure(
                code: "project.investigation-event-limit-exceeded",
                category: .insufficientResources,
                operation: .investigate,
                retryDisposition: .afterConditionsChange,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.investigation-event-limit-exceeded"
            )
        }

        let transactionID = UUID().uuidString.lowercased()
        let transactionURL = packageURL.appending(
            path: "transactions/\(transactionID)",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: transactionURL, withIntermediateDirectories: false)
        let targetGeneration = observedSnapshot.generation + 1
        try durableWrite(
            try GlifiCanonicalJSON.encode(
                TransactionState(
                    transactionID: transactionID,
                    baseGeneration: observedSnapshot.generation,
                    targetGeneration: targetGeneration,
                    state: "staging"
                )
            ),
            to: transactionURL.appending(path: "transaction.json")
        )
        let stagedEventURL = transactionURL.appending(path: "investigation-event")
        try durableWrite(data, to: stagedEventURL)
        try promoteArtifactObject(
            stagedEventURL,
            relativePath: record.objectPath,
            expectedDigest: record.contentDigest,
            expectedByteCount: record.byteCount,
            maximumByteCount: GlifiProjectPackage.maximumInvestigationEventByteCount,
            in: packageURL
        )

        let investigationRootDigest = try investigationRootDigest(events)
        let recordDigest = try generationRecordDigest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            sourceCount: observedSnapshot.sources.count,
            artifactRootDigest: observedSnapshot.artifactRootDigest,
            artifactCount: observedSnapshot.artifacts.count,
            investigationRootDigest: investigationRootDigest,
            investigationEventCount: events.count,
            qualitativeRootDigest: observedSnapshot.qualitativeRootDigest,
            qualitativeEventCount: observedSnapshot.qualitativeEvents.count
        )
        let database = try GlifiSQLiteProjectStore.open(at: databaseURL(in: packageURL))
        try database.discardGenerations(after: observedSnapshot.generation)
        try database.prepareInvestigationGeneration(
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            recordDigest: recordDigest,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            artifactRootDigest: observedSnapshot.artifactRootDigest,
            investigationRootDigest: investigationRootDigest,
            events: events
        )

        let manifest = GlifiProjectManifest(
            projectID: observedSnapshot.projectID,
            generation: targetGeneration,
            baseGeneration: observedSnapshot.generation,
            generationRecordDigest: recordDigest,
            sourceRootDigest: observedSnapshot.sourceRootDigest,
            sourceCount: observedSnapshot.sources.count,
            artifactRootDigest: observedSnapshot.artifactRootDigest,
            artifactCount: observedSnapshot.artifacts.count,
            investigationRootDigest: investigationRootDigest,
            investigationEventCount: events.count,
            qualitativeRootDigest: observedSnapshot.qualitativeRootDigest,
            qualitativeEventCount: observedSnapshot.qualitativeEvents.count
        )
        let candidateURL = transactionURL.appending(path: "manifest.json")
        try durableWrite(try GlifiCanonicalJSON.encode(manifest), to: candidateURL)
        try validate(
            JSONDecoder().decode(
                GlifiProjectManifest.self,
                from: Data(contentsOf: candidateURL)
            )
        )
        _ = try fileManager.replaceItemAt(manifestURL(in: packageURL), withItemAt: candidateURL)
        try database.markCommitted(generation: targetGeneration)
        try? fileManager.removeItem(at: transactionURL)
        return try openVerified(at: packageURL)
    }

    static func validatedObjectURL(
        for source: GlifiProjectSourceRecord,
        in packageURL: URL
    ) throws -> URL {
        guard source.objectPath == (try objectPath(for: source.contentDigest)),
            source.byteCount >= 0,
            source.objectPath.utf8.count <= 256,
            !source.objectPath.hasPrefix("/"),
            !source.objectPath.split(separator: "/").contains("..")
        else {
            throw corruption("project.illegal-object-reference")
        }
        let objectURL = packageURL.appending(path: source.objectPath)
        let standardizedRoot = packageURL.standardizedFileURL.path + "/"
        guard objectURL.standardizedFileURL.path.hasPrefix(standardizedRoot) else {
            throw corruption("project.object-path-escape")
        }
        let observation = try digestFile(
            source.objectPath, in: packageURL, maximumByteCount: source.byteCount)
        guard observation.byteCount == source.byteCount,
            observation.digest == source.contentDigest
        else {
            throw corruption("project.object-digest-mismatch")
        }
        return objectURL
    }

    static func validatedArtifactRecord(
        for stored: GlifiStoredProjectArtifactRecord,
        in packageURL: URL
    ) throws -> GlifiProjectArtifactRecord {
        let expectedDescriptorPath = try descriptorObjectPath(for: stored.descriptorDigest)
        guard stored.descriptorObjectPath == expectedDescriptorPath,
            stored.descriptorByteCount >= 0,
            stored.descriptorByteCount <= GlifiProjectPackage.maximumDescriptorByteCount,
            stored.outputSchemaIdentifier.utf8.count <= 1_024
        else {
            throw corruption("project.illegal-descriptor-reference")
        }
        let observation = try readFile(
            stored.descriptorObjectPath, in: packageURL,
            maximumByteCount: stored.descriptorByteCount,
            retainBytes: true
        )
        guard observation.digest == stored.descriptorDigest,
            observation.byteCount == stored.descriptorByteCount,
            let descriptorData = observation.data
        else {
            throw corruption("project.descriptor-digest-mismatch")
        }
        let descriptor: GlifiAnalysisDescriptor
        do {
            descriptor = try JSONDecoder().decode(
                GlifiAnalysisDescriptor.self,
                from: descriptorData
            )
        } catch {
            throw corruption("project.descriptor-invalid")
        }
        guard try descriptor.nodeID() == stored.nodeID,
            try descriptor.canonicalDigest() == stored.descriptorDigest,
            descriptor.outputSchemaIdentifier == stored.outputSchemaIdentifier,
            stored.artifactID.digest == stored.contentDigest
        else {
            throw corruption("project.artifact-metadata-mismatch")
        }
        let record = GlifiProjectArtifactRecord(
            artifactID: stored.artifactID,
            node: try GlifiAnalysisNode(descriptor: descriptor),
            descriptorDigest: stored.descriptorDigest,
            descriptorByteCount: stored.descriptorByteCount,
            descriptorObjectPath: stored.descriptorObjectPath,
            contentDigest: stored.contentDigest,
            byteCount: stored.byteCount,
            objectPath: stored.objectPath
        )
        _ = try validatedArtifactObjectURL(for: record, in: packageURL)
        return record
    }

    private static func validatedArtifactObjectURL(
        for artifact: GlifiProjectArtifactRecord,
        in packageURL: URL
    ) throws -> URL {
        guard artifact.objectPath == (try artifactObjectPath(for: artifact.contentDigest)),
            artifact.artifactID.digest == artifact.contentDigest,
            artifact.byteCount >= 0,
            artifact.byteCount <= GlifiProjectPackage.maximumArtifactByteCount
        else {
            throw corruption("project.illegal-artifact-reference")
        }
        let objectURL = try containedObjectURL(relativePath: artifact.objectPath, in: packageURL)
        let observation = try digestFile(
            artifact.objectPath, in: packageURL, maximumByteCount: artifact.byteCount)
        guard observation.byteCount == artifact.byteCount,
            observation.digest == artifact.contentDigest
        else {
            throw corruption("project.artifact-digest-mismatch")
        }
        return objectURL
    }

    private static func containedObjectURL(relativePath: String, in packageURL: URL) throws -> URL {
        guard relativePath.utf8.count <= 256,
            !relativePath.hasPrefix("/"),
            !relativePath.split(separator: "/").contains("..")
        else {
            throw corruption("project.illegal-object-reference")
        }
        let objectURL = packageURL.appending(path: relativePath)
        let standardizedRoot = packageURL.standardizedFileURL.path + "/"
        guard objectURL.standardizedFileURL.path.hasPrefix(standardizedRoot) else {
            throw corruption("project.object-path-escape")
        }
        return objectURL
    }

    static func readValidatedObject(
        _ source: GlifiProjectSourceRecord,
        in packageURL: URL
    ) throws -> Data {
        let observation = try readFile(
            source.objectPath, in: packageURL,
            maximumByteCount: source.byteCount,
            retainBytes: true
        )
        guard observation.byteCount == source.byteCount,
            observation.digest == source.contentDigest,
            let data = observation.data
        else {
            throw corruption("project.object-digest-mismatch")
        }
        return data
    }

    static func readValidatedArtifact(
        _ artifact: GlifiProjectArtifactRecord,
        in packageURL: URL
    ) throws -> Data {
        _ = try validatedArtifactObjectURL(for: artifact, in: packageURL)
        let observation = try readFile(
            artifact.objectPath, in: packageURL,
            maximumByteCount: artifact.byteCount,
            retainBytes: true
        )
        guard observation.byteCount == artifact.byteCount,
            observation.digest == artifact.contentDigest,
            let data = observation.data
        else {
            throw corruption("project.artifact-digest-mismatch")
        }
        return data
    }

    static func readValidatedInvestigationEvent(
        _ record: GlifiProjectInvestigationEventRecord,
        in packageURL: URL
    ) throws -> GlifiInvestigationEvent {
        guard record.objectPath == (try investigationEventObjectPath(for: record.contentDigest)),
            record.byteCount > 0,
            record.byteCount <= GlifiProjectPackage.maximumInvestigationEventByteCount,
            record.eventID.digest == record.contentDigest
        else {
            throw corruption("project.illegal-investigation-event-reference")
        }
        let observation = try readFile(
            record.objectPath, in: packageURL,
            maximumByteCount: record.byteCount,
            retainBytes: true
        )
        guard observation.byteCount == record.byteCount,
            observation.digest == record.contentDigest,
            let data = observation.data,
            let event = try? JSONDecoder().decode(GlifiInvestigationEvent.self, from: data),
            try event.eventID() == record.eventID,
            event.investigationID == record.investigationID,
            event.predecessorEventID == record.predecessorEventID
        else {
            throw corruption("project.investigation-event-mismatch")
        }
        return event
    }

    /// Artifacts of the previous generation that survive an import, with their dependency chains.
    ///
    /// An artifact survives when it still matches the corpus it declares and every ancestor
    /// survives with the exact artifact digest it recorded: a node whose parent is invalidated is
    /// invalidated too, as transitive invalidation requires.
    static func retainedArtifacts(
        _ artifacts: [GlifiProjectArtifactRecord],
        sources: [GlifiProjectSourceRecord],
        rootDigest: String
    ) throws -> [GlifiProjectArtifactRecord] {
        var candidates: [AnalysisNodeID: GlifiProjectArtifactRecord] = [:]
        for artifact in artifacts
        where try artifactMatchesCorpus(
            artifact.node.descriptor, sources: sources, rootDigest: rootDigest)
        {
            candidates[artifact.node.id] = artifact
        }
        var removedOne = true
        while removedOne {
            removedOne = false
            for (nodeID, artifact) in candidates
            where artifact.node.descriptor.dependencies.contains(where: { dependency in
                guard let parent = candidates[dependency.nodeID] else { return true }
                return parent.contentDigest != dependency.artifactDigest
            }) {
                candidates.removeValue(forKey: nodeID)
                removedOne = true
            }
        }
        return candidates.values.sorted { $0.node.id.canonicalValue < $1.node.id.canonicalValue }
    }

    /// Whether an artifact still matches the corpus it declares (ADR-0028).
    ///
    /// A descriptor that declares no revisions depends on the whole generation and stays bound to
    /// its source root, the only rule available before the v2 descriptor. One that declares them
    /// is valid when every declared revision belongs to the generation and its corpus-version
    /// digest is the source root restricted to exactly those revisions.
    static func artifactMatchesCorpus(
        _ descriptor: GlifiAnalysisDescriptor,
        sources: [GlifiProjectSourceRecord],
        rootDigest: String
    ) throws -> Bool {
        guard let declared = descriptor.sourceRevisionIDs else {
            return descriptor.corpusVersionDigest == rootDigest
        }
        let requested = Set(declared)
        let selected = sources.filter { requested.contains($0.sourceRevisionID) }
        guard selected.count == requested.count else { return false }
        return descriptor.corpusVersionDigest == (try sourceRootDigest(selected))
    }

    static func sourceRootDigest(_ sources: [GlifiProjectSourceRecord]) throws -> String {
        let ordered = sources.sorted {
            $0.sourceRevisionID.canonicalValue < $1.sourceRevisionID.canonicalValue
        }
        return digest(try GlifiCanonicalJSON.encode(ordered))
    }

    static func artifactRootDigest(_ artifacts: [GlifiProjectArtifactRecord]) throws -> String {
        let ordered = artifacts.sorted {
            $0.node.id.canonicalValue < $1.node.id.canonicalValue
        }
        return digest(try GlifiCanonicalJSON.encode(ordered))
    }

    static func investigationRootDigest(
        _ events: [GlifiProjectInvestigationEventRecord]
    ) throws -> String {
        let ordered = events.sorted {
            $0.eventID.canonicalValue < $1.eventID.canonicalValue
        }
        return digest(try GlifiCanonicalJSON.encode(ordered))
    }

    static func generationRecordDigest(
        projectID: ProjectID,
        generation: Int,
        baseGeneration: Int?,
        sourceRootDigest: String,
        sourceCount: Int,
        artifactRootDigest: String,
        artifactCount: Int,
        investigationRootDigest: String,
        investigationEventCount: Int,
        qualitativeRootDigest: String = GlifiProjectManifest.emptyQualitativeRootDigest,
        qualitativeEventCount: Int = 0
    ) throws -> String {
        try digest(
            GlifiCanonicalJSON.encode(
                GenerationRecordDigestInput(
                    projectID: projectID,
                    generation: generation,
                    baseGeneration: baseGeneration,
                    sourceRootDigest: sourceRootDigest,
                    sourceCount: sourceCount,
                    artifactRootDigest: artifactRootDigest,
                    artifactCount: artifactCount,
                    investigationRootDigest: investigationRootDigest,
                    investigationEventCount: investigationEventCount,
                    qualitativeRootDigest: qualitativeEventCount > 0 ? qualitativeRootDigest : nil,
                    qualitativeEventCount: qualitativeEventCount > 0 ? qualitativeEventCount : nil
                )
            )
        )
    }

    static func classify(_ error: Error, operation: GlifiOperationKind) -> GlifiFailure {
        if let failure = error as? GlifiFailure {
            return failure
        }
        let cocoaError = error as NSError
        let authorizationCodes: Set<Int> = [
            CocoaError.fileReadNoPermission.rawValue,
            CocoaError.fileWriteNoPermission.rawValue,
        ]
        if authorizationCodes.contains(cocoaError.code) {
            return GlifiFailure(
                code: "project.authorization-denied",
                category: .authorizationDenied,
                operation: operation,
                retryDisposition: .afterUserAction,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.authorization-denied"
            )
        }
        return GlifiFailure(
            code: "project.io-failed",
            category: .transientIO,
            operation: operation,
            retryDisposition: .transientBackoff,
            retainedState: .lastCommittedGeneration,
            messageKey: "failure.project.io-failed",
            arguments: ["code": String(cocoaError.code)]
        )
    }

    private static func validate(_ manifest: GlifiProjectManifest) throws {
        guard manifest.schema == GlifiProjectManifest.schema else {
            throw corruption("project.manifest-schema-mismatch")
        }
        guard
            (GlifiProjectManifest.previousSchemaVersion...GlifiProjectManifest.schemaVersion)
                .contains(manifest.schemaVersion),
            manifest.formatVersion == GlifiProjectManifest.formatVersion,
            manifest.minimumReaderVersion <= GlifiProjectManifest.formatVersion
        else {
            throw GlifiFailure(
                code: "project.incompatible-version",
                category: .incompatibleVersion,
                operation: .persistProject,
                retryDisposition: .never,
                retainedState: .readOnlyRecovery,
                messageKey: "failure.project.incompatible-version"
            )
        }
        guard manifest.generation >= 0,
            manifest.sourceCount >= 0,
            manifest.artifactCount >= 0,
            manifest.investigationEventCount >= 0,
            (manifest.generation == 0) == (manifest.baseGeneration == nil),
            manifest.baseGeneration.map({ $0 >= 0 && $0 < manifest.generation }) ?? true,
            isSHA256Digest(manifest.generationRecordDigest),
            isSHA256Digest(manifest.sourceRootDigest),
            isSHA256Digest(manifest.artifactRootDigest),
            isSHA256Digest(manifest.investigationRootDigest)
        else {
            throw corruption("project.manifest-invariant-violation")
        }
        guard
            manifest.schemaVersion != GlifiProjectManifest.previousSchemaVersion
                || (manifest.investigationRootDigest
                    == GlifiProjectManifest.emptyInvestigationRootDigest
                    && manifest.investigationEventCount == 0)
        else {
            throw corruption("project.manifest-invariant-violation")
        }
        // Schema 4 porta sempre una storia qualitativa non vuota; gli schemi precedenti nessuna.
        let hasQualitativeHistory =
            manifest.qualitativeRootDigest != nil || manifest.qualitativeEventCount != nil
        guard
            hasQualitativeHistory
                ? manifest.schemaVersion == GlifiProjectManifest.schemaVersion
                    && (manifest.qualitativeEventCount ?? 0) > 0
                    && manifest.qualitativeRootDigest.map(isSHA256Digest) == true
                : manifest.schemaVersion < GlifiProjectManifest.schemaVersion
        else {
            throw corruption("project.manifest-invariant-violation")
        }
    }

    private static func objectPath(for contentDigest: String) throws -> String {
        guard isSHA256Digest(contentDigest) else {
            throw corruption("project.invalid-content-digest")
        }
        let hex = String(contentDigest.dropFirst("sha256:".count))
        return "sources/objects/sha256/\(hex.prefix(2))/\(hex)"
    }

    private static func artifactObjectPath(for contentDigest: String) throws -> String {
        guard isSHA256Digest(contentDigest) else {
            throw corruption("project.invalid-artifact-digest")
        }
        let hex = String(contentDigest.dropFirst("sha256:".count))
        return "artifacts/objects/sha256/\(hex.prefix(2))/\(hex)"
    }

    private static func descriptorObjectPath(for descriptorDigest: String) throws -> String {
        guard isSHA256Digest(descriptorDigest) else {
            throw corruption("project.invalid-descriptor-digest")
        }
        let hex = String(descriptorDigest.dropFirst("sha256:".count))
        return "artifacts/descriptors/sha256/\(hex.prefix(2))/\(hex).json"
    }

    private static func investigationEventObjectPath(for contentDigest: String) throws -> String {
        guard isSHA256Digest(contentDigest) else {
            throw corruption("project.invalid-investigation-event-digest")
        }
        let hex = String(contentDigest.dropFirst("sha256:".count))
        return "investigations/events/sha256/\(hex.prefix(2))/\(hex).json"
    }

    private static func promoteObject(
        _ stagedURL: URL,
        source: GlifiProjectSourceRecord,
        in packageURL: URL
    ) throws {
        let objectURL = packageURL.appending(path: source.objectPath)
        try fileManager.createDirectory(
            at: objectURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: objectURL.path) {
            _ = try validatedObjectURL(for: source, in: packageURL)
            try fileManager.removeItem(at: stagedURL)
            return
        }
        try fileManager.moveItem(at: stagedURL, to: objectURL)
        _ = try validatedObjectURL(for: source, in: packageURL)
    }

    private static func promoteArtifactObject(
        _ stagedURL: URL,
        relativePath: String,
        expectedDigest: String,
        expectedByteCount: Int,
        maximumByteCount: Int,
        in packageURL: URL
    ) throws {
        let objectURL = try containedObjectURL(relativePath: relativePath, in: packageURL)
        try fileManager.createDirectory(
            at: objectURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: objectURL.path) {
            let observation = try digestFile(
                relativePath, in: packageURL, maximumByteCount: maximumByteCount)
            guard observation.digest == expectedDigest,
                observation.byteCount == expectedByteCount
            else {
                throw corruption("project.artifact-object-collision")
            }
            try fileManager.removeItem(at: stagedURL)
            return
        }
        try fileManager.moveItem(at: stagedURL, to: objectURL)
        let observation = try digestFile(
            relativePath, in: packageURL, maximumByteCount: maximumByteCount)
        guard observation.digest == expectedDigest,
            observation.byteCount == expectedByteCount
        else {
            throw corruption("project.artifact-object-promotion-failed")
        }
    }

    private static func storedRecord(
        _ artifact: GlifiProjectArtifactRecord
    ) -> GlifiStoredProjectArtifactRecord {
        GlifiStoredProjectArtifactRecord(
            artifactID: artifact.artifactID,
            nodeID: artifact.node.id,
            descriptorDigest: artifact.descriptorDigest,
            descriptorByteCount: artifact.descriptorByteCount,
            descriptorObjectPath: artifact.descriptorObjectPath,
            contentDigest: artifact.contentDigest,
            byteCount: artifact.byteCount,
            objectPath: artifact.objectPath,
            outputSchemaIdentifier: artifact.node.descriptor.outputSchemaIdentifier
        )
    }

    private static func durableWrite(_ data: Data, to url: URL) throws {
        let descriptor = Darwin.open(
            url.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600
        )
        guard descriptor >= 0 else {
            if errno == EEXIST {
                throw GlifiFailure(
                    code: "project.unexpected-existing-file",
                    category: .corruption,
                    operation: .persistProject,
                    retryDisposition: .never,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.project.unexpected-existing-file"
                )
            }
            throw GlifiFailure(
                code: "project.file-create-failed",
                category: .transientIO,
                operation: .persistProject,
                retryDisposition: .transientBackoff,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.file-create-failed"
            )
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()
    }

    private static func digestFile(
        _ relativePath: String,
        in packageURL: URL,
        maximumByteCount: Int
    ) throws -> (digest: String, byteCount: Int) {
        let observation = try readFile(
            relativePath, in: packageURL,
            maximumByteCount: maximumByteCount,
            retainBytes: false
        )
        return (observation.digest, observation.byteCount)
    }

    private static func readFile(
        _ relativePath: String,
        in packageURL: URL,
        maximumByteCount: Int,
        retainBytes: Bool
    ) throws -> (digest: String, byteCount: Int, data: Data?) {
        let directory = try GlifiPackageDirectory(at: packageURL)
        let handle = try directory.openFile(relativePath: relativePath)
        defer { try? handle.close() }
        var status = stat()
        guard fstat(handle.fileDescriptor, &status) == 0,
            (status.st_mode & S_IFMT) == S_IFREG,
            status.st_nlink == 1,
            status.st_size >= 0,
            status.st_size <= maximumByteCount
        else {
            throw corruption("project.invalid-object-file")
        }
        var hasher = SHA256()
        var byteCount = 0
        var retainedData = retainBytes ? Data(capacity: Int(status.st_size)) : nil
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty else {
                break
            }
            byteCount += chunk.count
            guard byteCount <= maximumByteCount else {
                throw corruption("project.object-size-mismatch")
            }
            hasher.update(data: chunk)
            retainedData?.append(chunk)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return ("sha256:\(digest)", byteCount, retainedData)
    }

    private static func digest(_ data: Data) -> String {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return "sha256:\(digest)"
    }

    private static func isSHA256Digest(_ value: String) -> Bool {
        let bytes = value.utf8
        guard bytes.count == 71, value.hasPrefix("sha256:") else {
            return false
        }
        return bytes.dropFirst(7).allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private static func interruptIfRequested(
        _ step: GlifiProjectCommitInterruption,
        _ requested: GlifiProjectCommitInterruption?,
        behavior: GlifiProjectCommitInterruptionBehavior
    ) throws {
        guard step == requested else { return }
        switch behavior {
        case .throwFailure:
            break
        case .invoke(let action):
            action()
        }
        throw GlifiFailure(
            code: "test.interrupted-commit",
            category: .transientIO,
            operation: .persistProject,
            retryDisposition: .transientBackoff,
            retainedState: step == .manifestReplaced || step == .databaseCommitted
                ? .lastCommittedGeneration : .unchanged,
            messageKey: "failure.test.interrupted-commit"
        )
    }

    private static func corruption(_ code: String) -> GlifiFailure {
        GlifiFailure(
            code: code,
            category: .corruption,
            operation: .persistProject,
            retryDisposition: .never,
            retainedState: .readOnlyRecovery,
            messageKey: "failure.project.corruption"
        )
    }
}

private enum GlifiCanonicalJSON {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

private struct GenerationRecordDigestInput: Codable {
    let projectID: ProjectID
    let generation: Int
    let baseGeneration: Int?
    let sourceRootDigest: String
    let sourceCount: Int
    let artifactRootDigest: String
    let artifactCount: Int
    let investigationRootDigest: String
    let investigationEventCount: Int
    /// Absent while the qualitative history is empty, so earlier digests are unchanged.
    let qualitativeRootDigest: String?
    let qualitativeEventCount: Int?
}

private struct TransactionState: Codable {
    let transactionID: String
    let baseGeneration: Int
    let targetGeneration: Int
    let state: String
}

private final class GlifiProjectWriterLease {
    private let descriptor: Int32
    private var isReleased = false

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    static func acquire(in packageURL: URL) throws -> GlifiProjectWriterLease {
        let packageDescriptor = Darwin.open(
            packageURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard packageDescriptor >= 0 else { throw invalidLock() }
        defer { Darwin.close(packageDescriptor) }
        let directoryDescriptor = openat(
            packageDescriptor, "transactions", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard directoryDescriptor >= 0 else { throw invalidLock() }
        defer { Darwin.close(directoryDescriptor) }
        let descriptor = openat(
            directoryDescriptor, ".writer.lock",
            O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0o600
        )
        guard descriptor >= 0 else {
            if errno == ELOOP || errno == EISDIR { throw invalidLock() }
            throw failure()
        }
        var status = stat()
        guard fstat(descriptor, &status) == 0,
            (status.st_mode & S_IFMT) == S_IFREG,
            status.st_nlink == 1
        else {
            Darwin.close(descriptor)
            throw invalidLock()
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            throw failure()
        }
        return GlifiProjectWriterLease(descriptor: descriptor)
    }

    func release() {
        guard !isReleased else { return }
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
        isReleased = true
    }

    deinit {
        release()
    }

    private static func invalidLock() -> GlifiFailure {
        GlifiFailure(
            code: "project.invalid-writer-lock",
            category: .corruption,
            operation: .persistProject,
            retryDisposition: .never,
            retainedState: .readOnlyRecovery,
            messageKey: "failure.project.corruption"
        )
    }

    private static func failure() -> GlifiFailure {
        GlifiFailure(
            code: "project.writer-busy",
            category: .transientIO,
            operation: .persistProject,
            retryDisposition: .transientBackoff,
            retainedState: .lastCommittedGeneration,
            messageKey: "failure.project.writer-busy"
        )
    }
}

extension GlifiProjectSnapshot {
    /// Corpus-version digest of the source revisions an analysis declares (ADR-0028).
    ///
    /// The digest is the canonical source root restricted to the declared revisions, so declaring
    /// every revision of this generation returns ``sourceRootDigest`` unchanged. Declaring no
    /// revision returns the digest of the empty root: such an analysis reads no source and no
    /// import can invalidate it. A revision that does not belong to this generation is rejected.
    public func corpusVersionDigest(for sourceRevisionIDs: [SourceRevisionID]) throws -> String {
        let declared = Set(sourceRevisionIDs)
        let selected = sources.filter { declared.contains($0.sourceRevisionID) }
        guard selected.count == declared.count else {
            throw GlifiFailure(
                code: "project.source-revision-not-found",
                category: .invalidInput,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.project.source-revision-not-found"
            )
        }
        return try GlifiProjectPackageIO.sourceRootDigest(selected)
    }
}
