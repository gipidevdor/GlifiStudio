// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// A half-open UTF-8 interval in an explicitly identified representation.
public struct GlifiStudioStudyRange: Codable, Equatable, Sendable {
    /// Inclusive UTF-8 offset.
    public let startUTF8: Int
    /// Exclusive UTF-8 offset.
    public let endUTF8: Int
    /// Creates an interval for validation at the study boundary.
    public init(startUTF8: Int, endUTF8: Int) {
        self.startUTF8 = startUTF8
        self.endUTF8 = endUTF8
    }
}

/// Immutable captured passage identity, independent from titles and personal notes.
public struct GlifiStudioStudyAnchor: Codable, Equatable, Sendable {
    /// Immutable revision incorporated in the owning project.
    public let sourceRevisionID: String
    /// Digest of the exact original bytes.
    public let sourceContentDigest: String
    /// Explicit coordinate system of the captured quote.
    public let representationIdentifier: String
    /// Digest of the complete extracted representation.
    public let representationDigest: String
    /// Versioned extraction contract captured by the importer.
    public let extractionContractIdentifier: String
    /// Inclusive offset in extracted UTF-8 text.
    public let startUTF8: Int
    /// Exclusive offset in extracted UTF-8 text.
    public let endUTF8: Int
    /// Exact immutable quote, never a manually edited paraphrase.
    public let quote: String
    /// Real contributing intervals in the importer's source representation.
    public let sourceRanges: [GlifiStudioStudyRange]
    /// Creates an explicit anchor for verification against an incorporated revision.
    public init(
        sourceRevisionID: String, sourceContentDigest: String,
        representationIdentifier: String = "extracted-utf8-v1", representationDigest: String,
        extractionContractIdentifier: String, startUTF8: Int, endUTF8: Int, quote: String,
        sourceRanges: [GlifiStudioStudyRange]
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.sourceContentDigest = sourceContentDigest
        self.representationIdentifier = representationIdentifier
        self.representationDigest = representationDigest
        self.extractionContractIdentifier = extractionContractIdentifier
        self.startUTF8 = startUTF8
        self.endUTF8 = endUTF8
        self.quote = quote
        self.sourceRanges = sourceRanges
    }
}

/// An independently organized passage with an immutable content-derived identity.
public struct GlifiStudioStudyExcerpt: Codable, Equatable, Identifiable, Sendable {
    /// SHA-256 identity of the canonical anchor, without the digest prefix.
    public let id: String
    /// Editable personal title.
    public var title: String
    /// Optional organizational group.
    public var groupID: String?
    /// Captured source identity and quote.
    public let anchor: GlifiStudioStudyAnchor
    /// Creates a passage entry for project validation.
    public init(id: String, title: String, groupID: String? = nil, anchor: GlifiStudioStudyAnchor) {
        self.id = id
        self.title = title
        self.groupID = groupID
        self.anchor = anchor
    }
}

/// A personal conclusion linking zero or more passages, never scientific Evidence.
public struct GlifiStudioStudyNote: Codable, Equatable, Identifiable, Sendable {
    /// Stable user-owned identity.
    public let id: String
    /// Editable personal title.
    public var title: String
    /// Editable personal annotation.
    public var text: String
    /// Optional organizational group.
    public var groupID: String?
    /// Ordered supporting passage identities.
    public var excerptIDs: [String]
    /// Creates an annotation without promoting it to an analytical result.
    public init(
        id: String, title: String, text: String, groupID: String? = nil, excerptIDs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.groupID = groupID
        self.excerptIDs = excerptIDs
    }
}

/// An ordered user-owned organizational group.
public struct GlifiStudioStudyGroup: Codable, Equatable, Identifiable, Sendable {
    /// Stable user-owned identity.
    public let id: String
    /// Editable displayed title.
    public var title: String
    /// Creates an explicit group.
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Complete project-bound notebook state stored through an optimistic append-only history.
public struct GlifiStudioStudyState: Codable, Equatable, Sendable {
    /// Owning project; exports cannot silently cross this boundary.
    public let projectID: String
    /// Monotonic revision, also supplied by the writer for optimistic concurrency.
    public var revision: Int
    /// Optional existing investigation, used only for manual organization.
    public var investigationID: String?
    /// Independently collected immutable passages.
    public var excerpts: [GlifiStudioStudyExcerpt]
    /// Editable personal conclusions.
    public var notes: [GlifiStudioStudyNote]
    /// Explicitly ordered groups.
    public var groups: [GlifiStudioStudyGroup]
    /// Mixed ordering containing every passage and note identity exactly once.
    public var order: [String]
    /// Zero, one or two distinct passage identities in left-to-right comparison order.
    public var comparisonExcerptIDs: [String]
    /// Creates an explicit project-bound notebook for boundary validation.
    public init(
        projectID: String, revision: Int = 0, investigationID: String? = nil,
        excerpts: [GlifiStudioStudyExcerpt] = [], notes: [GlifiStudioStudyNote] = [],
        groups: [GlifiStudioStudyGroup] = [], order: [String] = [],
        comparisonExcerptIDs: [String] = []
    ) {
        self.projectID = projectID
        self.revision = revision
        self.investigationID = investigationID
        self.excerpts = excerpts
        self.notes = notes
        self.groups = groups
        self.order = order
        self.comparisonExcerptIDs = comparisonExcerptIDs
    }

    /// Validates the same project-independent contract as the authoritative writer.
    public func validate() throws(GlifiStudioFailure) {
        try studyPresentation { try core().validate() }
    }

    package func core() throws -> GlifiStudyState {
        guard order.count <= 2_000, comparisonExcerptIDs.count <= 2 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        guard excerpts.count <= 1_000, notes.count <= 1_000, groups.count <= 200,
            excerpts.allSatisfy({ $0.anchor.sourceRanges.count <= 10_000 }),
            notes.allSatisfy({ $0.excerptIDs.count <= 1_000 })
        else { throw studyFailure("study.resource-limit", category: .insufficientResources) }
        var rangeBudget = 32 * 1_048_576
        for excerpt in excerpts {
            guard excerpt.anchor.sourceRanges.count <= rangeBudget / 96 else {
                throw studyFailure("study.resource-limit", category: .insufficientResources)
            }
            rangeBudget -= excerpt.anchor.sourceRanges.count * 96
        }
        let value = GlifiStudyState(
            projectID: projectID, revision: revision, investigationID: investigationID,
            excerpts: excerpts.map { excerpt in
                let a = excerpt.anchor
                return GlifiStudyExcerpt(
                    id: excerpt.id, title: excerpt.title, groupID: excerpt.groupID,
                    anchor: GlifiStudyAnchor(
                        sourceRevisionID: a.sourceRevisionID,
                        sourceContentDigest: a.sourceContentDigest,
                        representationIdentifier: a.representationIdentifier,
                        representationDigest: a.representationDigest,
                        extractionContractIdentifier: a.extractionContractIdentifier,
                        startUTF8: a.startUTF8,
                        endUTF8: a.endUTF8, quote: a.quote,
                        sourceRanges: a.sourceRanges.map {
                            .init(startUTF8: $0.startUTF8, endUTF8: $0.endUTF8)
                        }))
            },
            notes: notes.map {
                .init(
                    id: $0.id, title: $0.title, text: $0.text, groupID: $0.groupID,
                    excerptIDs: $0.excerptIDs)
            },
            groups: groups.map { .init(id: $0.id, title: $0.title) }, order: order,
            comparisonExcerptIDs: comparisonExcerptIDs)
        return value
    }

    package init(_ value: GlifiStudyState) throws {
        self = try JSONDecoder().decode(Self.self, from: studyKitData(value))
    }

}

/// Deterministic notebook export formats.
public enum GlifiStudioStudyExportFormat: String, Codable, CaseIterable, Sendable {
    /// Complete canonical project-bound restoration envelope.
    case json
    /// Readable personal notebook, distinct from a scientific report.
    case markdown
}

/// Complete project-bound restoration envelope.
public struct GlifiStudioStudyExport: Codable, Equatable, Sendable {
    /// Stable export schema.
    public let schema: String
    /// Export contract version.
    public let schemaVersion: Int
    /// Exact owning project.
    public let projectID: String
    /// Complete authoritative notebook state.
    public let state: GlifiStudioStudyState
    /// Creates a versioned export of the supplied project state.
    public init(state: GlifiStudioStudyState) {
        schema = "studio.glifi.study-export"
        schemaVersion = 1
        projectID = state.projectID
        self.state = state
    }

    /// Decodes a bounded, strict restoration envelope without modifying any project.
    public static func decode(json: Data) throws(GlifiStudioFailure) -> Self {
        let value = try CommandJSON.decodeStrict(
            Self.self, from: json, maximumByteCount: 32 * 1_048_576 + 65_536)
        guard value.schema == "studio.glifi.study-export", value.schemaVersion == 1,
            value.projectID == value.state.projectID
        else { throw GlifiStudioFailure(studyFailure("study.invalid-export")) }
        try value.state.validate()
        return value
    }
}

package func studyKitData<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

package func studyPresentation<Value>(_ body: () throws -> Value) throws(GlifiStudioFailure)
    -> Value
{
    do { return try body() } catch let failure as GlifiStudioFailure { throw failure } catch let
        failure as GlifiFailure
    { throw GlifiStudioFailure(failure) } catch is CancellationError {
        throw GlifiStudioFailure(studyFailure("study.cancelled", category: .cancelled))
    } catch { throw GlifiStudioFailure(studyFailure("study.invalid-state")) }
}
