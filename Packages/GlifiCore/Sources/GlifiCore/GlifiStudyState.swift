// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// A half-open UTF-8 interval in an explicitly identified representation.
public struct GlifiStudyRange: Codable, Equatable, Sendable {
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
public struct GlifiStudyAnchor: Codable, Equatable, Sendable {
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
    public let sourceRanges: [GlifiStudyRange]
    /// Creates an explicit anchor for verification against an incorporated revision.
    public init(
        sourceRevisionID: String, sourceContentDigest: String,
        representationIdentifier: String = "extracted-utf8-v1", representationDigest: String,
        extractionContractIdentifier: String, startUTF8: Int, endUTF8: Int, quote: String,
        sourceRanges: [GlifiStudyRange]
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
public struct GlifiStudyExcerpt: Codable, Equatable, Identifiable, Sendable {
    /// SHA-256 identity of the canonical anchor, without the digest prefix.
    public let id: String
    /// Editable personal title.
    public var title: String
    /// Optional organizational group.
    public var groupID: String?
    /// Captured source identity and quote.
    public let anchor: GlifiStudyAnchor
    /// Creates a passage entry for project validation.
    public init(id: String, title: String, groupID: String? = nil, anchor: GlifiStudyAnchor) {
        self.id = id
        self.title = title
        self.groupID = groupID
        self.anchor = anchor
    }
}

/// A personal conclusion linking zero or more passages, never scientific Evidence.
public struct GlifiStudyNote: Codable, Equatable, Identifiable, Sendable {
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
public struct GlifiStudyGroup: Codable, Equatable, Identifiable, Sendable {
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
public struct GlifiStudyState: Codable, Equatable, Sendable {
    /// Owning project; exports cannot silently cross this boundary.
    public let projectID: String
    /// Monotonic revision, also supplied by the writer for optimistic concurrency.
    public var revision: Int
    /// Optional existing investigation, used only for manual organization.
    public var investigationID: String?
    /// Independently collected immutable passages.
    public var excerpts: [GlifiStudyExcerpt]
    /// Editable personal conclusions.
    public var notes: [GlifiStudyNote]
    /// Explicitly ordered groups.
    public var groups: [GlifiStudyGroup]
    /// Mixed ordering containing every passage and note identity exactly once.
    public var order: [String]
    /// Zero, one or two distinct passage identities in left-to-right comparison order.
    public var comparisonExcerptIDs: [String]
    /// Creates an explicit project-bound notebook for boundary validation.
    public init(
        projectID: String, revision: Int = 0, investigationID: String? = nil,
        excerpts: [GlifiStudyExcerpt] = [], notes: [GlifiStudyNote] = [],
        groups: [GlifiStudyGroup] = [], order: [String] = [], comparisonExcerptIDs: [String] = []
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

    /// Checks bounds, typed identities and all internal references before project I/O.
    package func validateResourceBounds() throws {
        guard order.count <= 2_000, comparisonExcerptIDs.count <= 2 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        guard excerpts.count <= 1_000, notes.count <= 1_000, groups.count <= 200
        else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        guard (try? ProjectID(canonicalValue: projectID)) != nil, (0...10_000).contains(revision)
        else {
            throw studyFailure("study.invalid-state")
        }
        var retained = 4_096
        func account(_ count: Int) throws {
            guard count >= 0, count <= 32 * 1_048_576 - retained else {
                throw studyFailure("study.resource-limit", category: .insufficientResources)
            }
            retained += count
        }
        for excerpt in excerpts {
            try studyCheckCancellation()
            guard excerpt.anchor.quote.utf8.count <= 1_048_576,
                excerpt.anchor.sourceRanges.count <= 10_000
            else { throw studyFailure("study.resource-limit", category: .insufficientResources) }
            try account(excerpt.anchor.quote.utf8.count)
            try account(excerpt.anchor.sourceRanges.count * 96)
            try account(excerpt.title.utf8.count)
            for text in [
                excerpt.id, excerpt.groupID ?? "", excerpt.anchor.sourceRevisionID,
                excerpt.anchor.sourceContentDigest, excerpt.anchor.representationIdentifier,
                excerpt.anchor.representationDigest, excerpt.anchor.extractionContractIdentifier,
            ] {
                try account(text.utf8.count + 32)
            }
        }
        for note in notes {
            try studyCheckCancellation()
            guard note.text.utf8.count <= 1_048_576, note.excerptIDs.count <= 1_000 else {
                throw studyFailure("study.resource-limit", category: .insufficientResources)
            }
            try account(note.text.utf8.count)
            try account(note.title.utf8.count)
            try account(note.id.utf8.count + 64)
            try account(note.groupID?.utf8.count ?? 0)
            for id in note.excerptIDs { try account(id.utf8.count + 16) }
        }
        for group in groups {
            try account(group.id.utf8.count)
            try account(group.title.utf8.count + 64)
        }
        try account(investigationID?.utf8.count ?? 0)
        for id in order + comparisonExcerptIDs { try account(id.utf8.count + 16) }
    }

    /// Checks bounds, typed identities and all internal references before project I/O.
    public func validate() throws {
        try validateResourceBounds()
        let excerptIDs = Set(excerpts.map(\.id))
        let noteIDs = Set(notes.map(\.id))
        let groupIDs = Set(groups.map(\.id))
        guard excerptIDs.count == excerpts.count, noteIDs.count == notes.count,
            groupIDs.count == groups.count, excerptIDs.isDisjoint(with: noteIDs),
            groupIDs.isDisjoint(with: excerptIDs.union(noteIDs)),
            order.count == excerpts.count + notes.count,
            Set(order) == excerptIDs.union(noteIDs), comparisonExcerptIDs.count <= 2,
            Set(comparisonExcerptIDs).count == comparisonExcerptIDs.count,
            Set(comparisonExcerptIDs).isSubset(of: excerptIDs)
        else { throw studyFailure("study.invalid-state") }
        for group in groups {
            guard studyIdentifier(group.id), studyTitle(group.title) else {
                throw studyFailure("study.invalid-group")
            }
        }
        for excerpt in excerpts {
            try studyCheckCancellation()
            let anchor = excerpt.anchor
            guard studyTitle(excerpt.title), excerpt.groupID.map(groupIDs.contains) ?? true,
                (try? SourceRevisionID(canonicalValue: anchor.sourceRevisionID)) != nil,
                studyIsDigest(anchor.sourceContentDigest),
                studyIsDigest(anchor.representationDigest),
                anchor.representationIdentifier == "extracted-utf8-v1",
                !anchor.extractionContractIdentifier.isEmpty,
                anchor.extractionContractIdentifier.utf8.count <= 256,
                anchor.startUTF8 >= 0, anchor.endUTF8 > anchor.startUTF8,
                anchor.endUTF8 - anchor.startUTF8 == anchor.quote.utf8.count,
                !anchor.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                anchor.sourceRanges.allSatisfy({ $0.startUTF8 >= 0 && $0.endUTF8 > $0.startUTF8 }),
                excerpt.id == (try studyDigest(anchor)).dropFirst(7)
            else { throw studyFailure("study.invalid-anchor") }
            guard anchor.quote.utf8.count <= 1_048_576 else {
                throw studyFailure("study.resource-limit", category: .insufficientResources)
            }
        }
        for note in notes {
            try studyCheckCancellation()
            guard studyIdentifier(note.id), studyTitle(note.title),
                note.groupID.map(groupIDs.contains) ?? true,
                note.excerptIDs.count <= 1_000, Set(note.excerptIDs).count == note.excerptIDs.count,
                Set(note.excerptIDs).isSubset(of: excerptIDs)
            else { throw studyFailure("study.invalid-note") }
            guard note.text.utf8.count <= 1_048_576 else {
                throw studyFailure("study.resource-limit", category: .insufficientResources)
            }
        }
        guard try studyData(self).count <= 32 * 1_048_576 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
    }
}

/// Deterministic notebook export formats.
public enum GlifiStudyExportFormat: String, Codable, CaseIterable, Sendable {
    /// Complete canonical project-bound restoration envelope.
    case json
    /// Readable personal notebook, distinct from a scientific report.
    case markdown
}

/// Complete project-bound restoration envelope.
public struct GlifiStudyExport: Codable, Equatable, Sendable {
    /// Stable export schema.
    public let schema: String
    /// Export contract version.
    public let schemaVersion: Int
    /// Exact owning project.
    public let projectID: String
    /// Complete authoritative notebook state.
    public let state: GlifiStudyState
    /// Creates a versioned export of the supplied project state.
    public init(state: GlifiStudyState) {
        schema = "studio.glifi.study-export"
        schemaVersion = 1
        projectID = state.projectID
        self.state = state
    }
}

package func studyData<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

package func studyDigest<Value: Encodable>(_ value: Value) throws -> String {
    studyBytesDigest(try studyData(value))
}

package func studyBytesDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func studyIdentifier(_ value: String) -> Bool {
    (1...64).contains(value.utf8.count)
        && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45
                || $0 == 46 || $0 == 95
        }
}

private func studyTitle(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 512
}

private func studyIsDigest(_ value: String) -> Bool {
    value.hasPrefix("sha256:") && value.utf8.count == 71
        && value.dropFirst(7).utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
}

package func studyFailure(_ code: String, category: GlifiFailureCategory = .invalidInput)
    -> GlifiFailure
{
    let actionable: Set<String> = [
        "study.stale-revision", "study.invalid-history", "study.resource-limit",
        "study.invalid-selection", "study.unknown-source", "study.invalid-anchor",
        "study.project-mismatch",
    ]
    return GlifiFailure(
        code: code, category: category, operation: .persistProject,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: actionable.contains(code)
            ? "failure.\(code)" : "failure.category.\(category.rawValue)")
}
