// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Supplies the stable namespace for a strongly typed Glifi identifier.
public protocol GlifiIdentifierKind: Sendable {
    /// Stable namespace serialized before the opaque value.
    static var namespace: String { get }
}

/// Supplies the stable namespace for a content-addressed Glifi identifier.
public protocol GlifiDigestIdentifierKind: Sendable {
    /// Stable namespace serialized before the SHA-256 digest.
    static var namespace: String { get }
}

/// A SHA-256-backed identifier for immutable semantic objects.
public struct GlifiDigestIdentifier<Kind: GlifiDigestIdentifierKind>:
    Codable, CustomStringConvertible, Hashable, Sendable
{
    private let digestValue: String

    /// Creates an identifier from a lowercase `sha256:` digest.
    public init(digest: String) throws {
        guard Self.isValidDigest(digest) else {
            throw GlifiFailure(
                code: "identifier.invalid-digest",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.identifier.invalid-digest"
            )
        }
        digestValue = digest
    }

    /// Restores a namespaced content identifier.
    public init(canonicalValue: String) throws {
        let prefix = "\(Kind.namespace):"
        guard canonicalValue.hasPrefix(prefix) else {
            throw GlifiFailure(
                code: "identifier.invalid-digest",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.identifier.invalid-digest"
            )
        }
        try self.init(digest: String(canonicalValue.dropFirst(prefix.count)))
    }

    /// The underlying content digest.
    public var digest: String { digestValue }

    /// Stable namespaced representation.
    public var canonicalValue: String { "\(Kind.namespace):\(digestValue)" }

    /// Canonical textual description.
    public var description: String { canonicalValue }

    /// Decodes and validates the canonical representation.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(canonicalValue: container.decode(String.self))
    }

    /// Encodes the canonical representation.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(canonicalValue)
    }

    private static func isValidDigest(_ value: String) -> Bool {
        isCanonicalSHA256Digest(value)
    }
}

/// A UUID-backed identifier whose phantom kind prevents cross-entity comparison.
public struct GlifiIdentifier<Kind: GlifiIdentifierKind>:
    Codable, CustomStringConvertible, Hashable, Sendable
{
    private let value: UUID

    /// Creates a new opaque identifier.
    public init() {
        value = UUID()
    }

    /// Creates an identifier from a UUID for deterministic import and testing.
    public init(uuid: UUID) {
        value = uuid
    }

    /// Restores an identifier from its canonical, namespaced representation.
    public init(canonicalValue: String) throws {
        let prefix = "\(Kind.namespace):"
        guard canonicalValue.hasPrefix(prefix),
            let uuid = UUID(uuidString: String(canonicalValue.dropFirst(prefix.count)))
        else {
            throw GlifiFailure(
                code: "identifier.invalid",
                category: .invalidInput,
                operation: .importText,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.identifier.invalid"
            )
        }

        value = uuid
    }

    /// The stable representation used by persistence and machine interfaces.
    public var canonicalValue: String {
        "\(Kind.namespace):\(value.uuidString.lowercased())"
    }

    /// The canonical representation used for textual descriptions.
    public var description: String {
        canonicalValue
    }

    /// Decodes and validates a canonical identifier.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let canonicalValue = try container.decode(String.self)
        do {
            try self.init(canonicalValue: canonicalValue)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid \(Kind.namespace) identifier"
            )
        }
    }

    /// Encodes the canonical namespaced representation.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(canonicalValue)
    }
}

/// Phantom kind for projects.
public enum ProjectIdentifierKind: GlifiIdentifierKind {
    /// Stable project namespace.
    public static let namespace = "project"
}

/// Phantom kind for sources.
public enum SourceIdentifierKind: GlifiIdentifierKind {
    /// Stable source namespace.
    public static let namespace = "source"
}

/// Phantom kind for source revisions.
public enum SourceRevisionIdentifierKind: GlifiIdentifierKind {
    /// Stable source-revision namespace.
    public static let namespace = "source-revision"
}

/// Phantom kind for documents.
public enum DocumentIdentifierKind: GlifiIdentifierKind {
    /// Stable document namespace.
    public static let namespace = "document"
}

/// Phantom kind for document revisions.
public enum DocumentRevisionIdentifierKind: GlifiIdentifierKind {
    /// Stable document-revision namespace.
    public static let namespace = "document-revision"
}

/// Phantom kind for corpora.
public enum CorpusIdentifierKind: GlifiIdentifierKind {
    /// Stable corpus namespace.
    public static let namespace = "corpus"
}

/// Phantom kind for corpus versions.
public enum CorpusVersionIdentifierKind: GlifiIdentifierKind {
    /// Stable corpus-version namespace.
    public static let namespace = "corpus-version"
}

/// Phantom kind for investigations.
public enum InvestigationIdentifierKind: GlifiIdentifierKind {
    /// Stable investigation namespace.
    public static let namespace = "investigation"
}

/// Phantom kind for operations.
public enum OperationIdentifierKind: GlifiIdentifierKind {
    /// Stable operation namespace.
    public static let namespace = "operation"
}

/// Phantom kind for semantic analysis nodes.
public enum AnalysisNodeIdentifierKind: GlifiDigestIdentifierKind {
    /// Stable analysis-node namespace.
    public static let namespace = "analysis-node"
}

/// Phantom kind for immutable analytical artifacts.
public enum ArtifactIdentifierKind: GlifiDigestIdentifierKind {
    /// Stable artifact namespace.
    public static let namespace = "artifact"
}

/// Phantom kind for immutable evidence records.
public enum EvidenceIdentifierKind: GlifiDigestIdentifierKind {
    /// Stable evidence namespace.
    public static let namespace = "evidence"
}

/// Phantom kind for immutable finding revisions.
public enum FindingIdentifierKind: GlifiDigestIdentifierKind {
    /// Stable finding-revision namespace.
    public static let namespace = "finding"
}

/// Phantom kind for immutable investigation-history events.
public enum InvestigationEventIdentifierKind: GlifiDigestIdentifierKind {
    /// Stable investigation-event namespace.
    public static let namespace = "investigation-event"
}

/// Phantom kind for immutable report revisions.
public enum ReportRevisionIdentifierKind: GlifiDigestIdentifierKind {
    /// Stable report-revision namespace.
    public static let namespace = "report-revision"
}

/// Strongly typed identifier for a project aggregate.
public typealias ProjectID = GlifiIdentifier<ProjectIdentifierKind>
/// Strongly typed identifier for a source entity.
public typealias SourceID = GlifiIdentifier<SourceIdentifierKind>
/// Strongly typed identifier for an immutable source revision.
public typealias SourceRevisionID = GlifiIdentifier<SourceRevisionIdentifierKind>
/// Strongly typed identifier for a document entity.
public typealias DocumentID = GlifiIdentifier<DocumentIdentifierKind>
/// Strongly typed identifier for an immutable document revision.
public typealias DocumentRevisionID = GlifiIdentifier<DocumentRevisionIdentifierKind>
/// Strongly typed identifier for a corpus aggregate.
public typealias CorpusID = GlifiIdentifier<CorpusIdentifierKind>
/// Strongly typed identifier for an immutable corpus version.
public typealias CorpusVersionID = GlifiIdentifier<CorpusVersionIdentifierKind>
/// Strongly typed identifier for an investigation aggregate.
public typealias InvestigationID = GlifiIdentifier<InvestigationIdentifierKind>
/// Strongly typed identifier for a runtime operation.
public typealias OperationID = GlifiIdentifier<OperationIdentifierKind>
/// Strongly typed content identity for an analysis node.
public typealias AnalysisNodeID = GlifiDigestIdentifier<AnalysisNodeIdentifierKind>
/// Strongly typed content identity for an immutable analytical artifact.
public typealias ArtifactID = GlifiDigestIdentifier<ArtifactIdentifierKind>
/// Strongly typed content identity for immutable evidence.
public typealias EvidenceID = GlifiDigestIdentifier<EvidenceIdentifierKind>
/// Strongly typed content identity for immutable finding revisions.
public typealias FindingID = GlifiDigestIdentifier<FindingIdentifierKind>
/// Strongly typed content identity for an immutable investigation-history event.
public typealias InvestigationEventID = GlifiDigestIdentifier<InvestigationEventIdentifierKind>
/// Strongly typed content identity for an immutable report revision.
public typealias ReportRevisionID = GlifiDigestIdentifier<ReportRevisionIdentifierKind>
