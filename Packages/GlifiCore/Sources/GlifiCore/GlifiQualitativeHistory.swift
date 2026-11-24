// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

// Storia qualitativa append-only (ADR-0027, GS-MET-001-20): codebook, mapping di categorie,
// codifiche di segmenti, ritrattazioni e memo come eventi immutabili content-addressed. Lo stato
// corrente è una proiezione deterministica; nessuna codifica storica viene riscritta.

/// One category of a codebook revision.
public struct GlifiCodebookCategory: Codable, Equatable, Sendable {
    /// Stable identity, `[a-z0-9._-]{1,64}`, whose meaning never changes across revisions.
    public let categoryID: String
    /// Parent category in the same revision, for hierarchical codebooks.
    public let parentCategoryID: String?
    /// Human label.
    public let label: String
    /// Operational definition.
    public let definition: String
    /// Coding instructions, inclusion and exclusion criteria.
    public let instructions: String?

    /// Creates a category; the event validates it.
    public init(
        categoryID: String, parentCategoryID: String? = nil, label: String, definition: String,
        instructions: String? = nil
    ) {
        self.categoryID = categoryID
        self.parentCategoryID = parentCategoryID
        self.label = label
        self.definition = definition
        self.instructions = instructions
    }
}

/// Kind of an explicit category mapping between two revisions.
public enum GlifiCategoryMappingKind: String, Codable, Sendable {
    /// Several categories become one.
    case merge
    /// One category becomes several.
    case split
    /// One category is replaced by another with the same scope.
    case rename
}

/// One mapping from categories of a revision to categories of a later revision.
public struct GlifiCategoryMapping: Codable, Equatable, Sendable {
    /// Mapping kind.
    public let kind: GlifiCategoryMappingKind
    /// Categories of the source revision.
    public let fromCategoryIDs: [String]
    /// Categories of the target revision.
    public let toCategoryIDs: [String]

    /// Creates a mapping; the event validates it.
    public init(kind: GlifiCategoryMappingKind, fromCategoryIDs: [String], toCategoryIDs: [String])
    {
        self.kind = kind
        self.fromCategoryIDs = fromCategoryIDs
        self.toCategoryIDs = toCategoryIDs
    }
}

/// Origin of a coding.
public enum GlifiCodingOrigin: String, Codable, Sendable {
    /// Assigned by a person.
    case manual
    /// Proposed by an automatic procedure and recorded as such.
    case automatic
}

/// Target of a memo.
public enum GlifiMemoTarget: Codable, Equatable, Sendable {
    /// A coding event.
    case coding(eventID: String)
    /// A category of a codebook.
    case category(codebookID: String, categoryID: String)
    /// A source revision.
    case source(sourceRevisionID: SourceRevisionID)
}

/// Typed payload of one qualitative-history event.
public enum GlifiQualitativeEventPayload: Codable, Equatable, Sendable {
    /// Complete content of revision `revision` of a codebook; revisions start at 1.
    case codebookRevised(codebookID: String, revision: Int, categories: [GlifiCodebookCategory])
    /// Explicit merge, split and rename mappings between two revisions of a codebook.
    case categoryMapped(
        codebookID: String, fromRevision: Int, toRevision: Int, mappings: [GlifiCategoryMapping])
    /// One category assigned to one extracted UTF-8 interval of a source revision.
    case segmentCoded(
        sourceRevisionID: SourceRevisionID,
        range: GlifiUTF8Range,
        codebookID: String,
        codebookRevision: Int,
        categoryID: String,
        coderID: String,
        origin: GlifiCodingOrigin
    )
    /// Withdraws an active coding without erasing it.
    case codingRetracted(codingEventID: String, reasonIdentifier: String)
    /// Free-text memo attached to a coding, a category or a source.
    case memoAttached(target: GlifiMemoTarget, coderID: String, text: String)
}

/// One immutable event of the linear qualitative history.
public struct GlifiQualitativeEvent: Codable, Equatable, Sendable {
    /// Stable event schema.
    public static let schemaIdentifier = "studio.glifi.qualitative-event"
    /// Current event schema version.
    public static let schemaVersion = 1

    /// Stable schema encoded with the event.
    public let schemaIdentifier: String
    /// Schema version encoded with the event.
    public let schemaVersion: Int
    /// Head of the history this event extends, absent only for the first event.
    public let predecessorEventID: String?
    /// Non-negative wall-clock time for presentation and audit.
    public let recordedAtUnixMilliseconds: Int64
    /// Typed change.
    public let payload: GlifiQualitativeEventPayload

    /// Creates and validates an event.
    public init(
        predecessorEventID: String?,
        recordedAtUnixMilliseconds: Int64,
        payload: GlifiQualitativeEventPayload
    ) throws {
        schemaIdentifier = Self.schemaIdentifier
        schemaVersion = Self.schemaVersion
        self.predecessorEventID = predecessorEventID
        self.recordedAtUnixMilliseconds = recordedAtUnixMilliseconds
        self.payload = payload
        try validate()
    }

    /// Content identity of the canonical event.
    public func eventID() throws -> String {
        // Stessa codifica canonica del package: chiavi ordinate, slash non escapati.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(self))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, predecessorEventID, recordedAtUnixMilliseconds
        case payload
    }

    /// Decodes only the supported schema and revalidates every invariant.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        predecessorEventID = try container.decodeIfPresent(
            String.self, forKey: .predecessorEventID)
        recordedAtUnixMilliseconds = try container.decode(
            Int64.self, forKey: .recordedAtUnixMilliseconds)
        payload = try container.decode(GlifiQualitativeEventPayload.self, forKey: .payload)
        try validate()
    }

    static func isIdentifier(_ value: String) -> Bool {
        (1...64).contains(value.utf8.count)
            && value.utf8.allSatisfy {
                ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x2E
                    || $0 == 0x5F || $0 == 0x2D
            }
    }

    static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 71 && value.hasPrefix("sha256:")
            && value.dropFirst(7).allSatisfy { "0123456789abcdef".contains($0) }
    }

    private static func isText(_ value: String, maximum: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.utf8.count <= maximum
    }

    private func validate() throws {
        guard schemaIdentifier == Self.schemaIdentifier, schemaVersion == Self.schemaVersion,
            recordedAtUnixMilliseconds >= 0,
            predecessorEventID.map(Self.isDigest) ?? true
        else {
            throw qualitativeFailure("qualitative.invalid-event")
        }
        let valid: Bool
        switch payload {
        case let .codebookRevised(codebookID, revision, categories):
            let identities = categories.map(\.categoryID)
            valid =
                Self.isIdentifier(codebookID) && revision >= 1 && !categories.isEmpty
                && categories.count <= 2_000 && Set(identities).count == identities.count
                && categories.allSatisfy {
                    Self.isIdentifier($0.categoryID) && Self.isText($0.label, maximum: 256)
                        && Self.isText($0.definition, maximum: 8_192)
                        && ($0.instructions.map { Self.isText($0, maximum: 16_384) } ?? true)
                        && ($0.parentCategoryID.map { identities.contains($0) } ?? true)
                        && $0.parentCategoryID != $0.categoryID
                } && Self.isAcyclic(categories)
        case let .categoryMapped(codebookID, fromRevision, toRevision, mappings):
            valid =
                Self.isIdentifier(codebookID) && fromRevision >= 1 && toRevision > fromRevision
                && !mappings.isEmpty && mappings.count <= 2_000
                && mappings.allSatisfy { mapping in
                    let arity: Bool
                    switch mapping.kind {
                    case .merge:
                        arity =
                            mapping.fromCategoryIDs.count >= 2 && mapping.toCategoryIDs.count == 1
                    case .split:
                        arity =
                            mapping.fromCategoryIDs.count == 1 && mapping.toCategoryIDs.count >= 2
                    case .rename:
                        arity =
                            mapping.fromCategoryIDs.count == 1 && mapping.toCategoryIDs.count == 1
                    }
                    return arity
                        && (mapping.fromCategoryIDs + mapping.toCategoryIDs).allSatisfy(
                            Self.isIdentifier)
                }
        case let .segmentCoded(_, range, codebookID, codebookRevision, categoryID, coderID, _):
            valid =
                range.end > range.start && Self.isIdentifier(codebookID) && codebookRevision >= 1
                && Self.isIdentifier(categoryID) && Self.isIdentifier(coderID)
        case let .codingRetracted(codingEventID, reasonIdentifier):
            valid = Self.isDigest(codingEventID) && Self.isIdentifier(reasonIdentifier)
        case let .memoAttached(target, coderID, text):
            let targetValid: Bool
            switch target {
            case let .coding(eventID): targetValid = Self.isDigest(eventID)
            case let .category(codebookID, categoryID):
                targetValid = Self.isIdentifier(codebookID) && Self.isIdentifier(categoryID)
            case .source: targetValid = true
            }
            valid = targetValid && Self.isIdentifier(coderID) && Self.isText(text, maximum: 32_768)
        }
        guard valid else {
            throw qualitativeFailure("qualitative.invalid-event")
        }
    }

    private static func isAcyclic(_ categories: [GlifiCodebookCategory]) -> Bool {
        let parents = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.categoryID, $0.parentCategoryID) })
        for category in categories {
            var seen: Set<String> = [category.categoryID]
            var current = category.parentCategoryID
            while let parent = current {
                guard seen.insert(parent).inserted else { return false }
                current = parents[parent] ?? nil
            }
        }
        return true
    }
}

/// One coding with its identity and state in the projection.
public struct GlifiCoding: Codable, Equatable, Sendable {
    /// Event that recorded the coding.
    public let eventID: String
    /// Coded source revision.
    public let sourceRevisionID: SourceRevisionID
    /// Extracted UTF-8 interval.
    public let range: GlifiUTF8Range
    /// Codebook.
    public let codebookID: String
    /// Codebook revision in force when coding.
    public let codebookRevision: Int
    /// Assigned category.
    public let categoryID: String
    /// Pseudonymous coder.
    public let coderID: String
    /// Manual or automatic.
    public let origin: GlifiCodingOrigin
    /// Recording time.
    public let recordedAtUnixMilliseconds: Int64
    /// Retraction event, when withdrawn.
    public let retractionEventID: String?
}

/// One memo in the projection.
public struct GlifiMemo: Codable, Equatable, Sendable {
    /// Event that recorded the memo.
    public let eventID: String
    /// Annotated object.
    public let target: GlifiMemoTarget
    /// Pseudonymous author.
    public let coderID: String
    /// Memo text.
    public let text: String
}

/// Deterministic projection of the whole qualitative history.
public struct GlifiQualitativeState: Equatable, Sendable {
    /// Revisions per codebook, in revision order.
    public let codebooks: [String: [[GlifiCodebookCategory]]]
    /// Mappings recorded between revisions, per codebook.
    public let mappings: [String: [(from: Int, to: Int, mappings: [GlifiCategoryMapping])]]
    /// Every coding in history order, retracted ones included.
    public let codings: [GlifiCoding]
    /// Memos in history order.
    public let memos: [GlifiMemo]
    /// Head event, `nil` for an empty history.
    public let headEventID: String?

    /// Replays events that must form one chain from the first event.
    public init(events: [GlifiQualitativeEvent]) throws {
        var codebooks: [String: [[GlifiCodebookCategory]]] = [:]
        var mappings: [String: [(from: Int, to: Int, mappings: [GlifiCategoryMapping])]] = [:]
        var codings: [GlifiCoding] = []
        var codingIndex: [String: Int] = [:]
        var memos: [GlifiMemo] = []
        var head: String?
        for event in events {
            guard event.predecessorEventID == head else {
                throw qualitativeFailure("qualitative.broken-chain", category: .staleArtifact)
            }
            let eventID = try event.eventID()
            switch event.payload {
            case let .codebookRevised(codebookID, revision, categories):
                guard revision == (codebooks[codebookID]?.count ?? 0) + 1 else {
                    throw qualitativeFailure("qualitative.revision-not-consecutive")
                }
                codebooks[codebookID, default: []].append(categories)
            case let .categoryMapped(codebookID, fromRevision, toRevision, recorded):
                guard let revisions = codebooks[codebookID], toRevision <= revisions.count else {
                    throw qualitativeFailure("qualitative.unknown-revision")
                }
                let from = Set(revisions[fromRevision - 1].map(\.categoryID))
                let to = Set(revisions[toRevision - 1].map(\.categoryID))
                guard
                    recorded.allSatisfy({
                        Set($0.fromCategoryIDs).isSubset(of: from)
                            && Set($0.toCategoryIDs).isSubset(of: to)
                    })
                else {
                    throw qualitativeFailure("qualitative.unknown-category")
                }
                mappings[codebookID, default: []].append((fromRevision, toRevision, recorded))
            case let .segmentCoded(
                sourceRevisionID, range, codebookID, codebookRevision, categoryID, coderID, origin):
                guard let revisions = codebooks[codebookID],
                    codebookRevision <= revisions.count
                else {
                    throw qualitativeFailure("qualitative.unknown-revision")
                }
                guard
                    revisions[codebookRevision - 1].contains(where: { $0.categoryID == categoryID })
                else {
                    throw qualitativeFailure("qualitative.unknown-category")
                }
                codingIndex[eventID] = codings.count
                codings.append(
                    GlifiCoding(
                        eventID: eventID, sourceRevisionID: sourceRevisionID, range: range,
                        codebookID: codebookID, codebookRevision: codebookRevision,
                        categoryID: categoryID, coderID: coderID, origin: origin,
                        recordedAtUnixMilliseconds: event.recordedAtUnixMilliseconds,
                        retractionEventID: nil))
            case let .codingRetracted(codingEventID, _):
                guard let index = codingIndex[codingEventID],
                    codings[index].retractionEventID == nil
                else {
                    throw qualitativeFailure("qualitative.unknown-coding")
                }
                let coding = codings[index]
                codings[index] = GlifiCoding(
                    eventID: coding.eventID, sourceRevisionID: coding.sourceRevisionID,
                    range: coding.range, codebookID: coding.codebookID,
                    codebookRevision: coding.codebookRevision, categoryID: coding.categoryID,
                    coderID: coding.coderID, origin: coding.origin,
                    recordedAtUnixMilliseconds: coding.recordedAtUnixMilliseconds,
                    retractionEventID: eventID)
            case let .memoAttached(target, coderID, text):
                switch target {
                case let .coding(codingEventID):
                    guard codingIndex[codingEventID] != nil else {
                        throw qualitativeFailure("qualitative.unknown-coding")
                    }
                case let .category(codebookID, categoryID):
                    guard
                        codebooks[codebookID]?.contains(where: {
                            $0.contains { $0.categoryID == categoryID }
                        }) == true
                    else {
                        throw qualitativeFailure("qualitative.unknown-category")
                    }
                case .source:
                    break
                }
                memos.append(
                    GlifiMemo(eventID: eventID, target: target, coderID: coderID, text: text))
            }
            head = eventID
        }
        self.codebooks = codebooks
        self.mappings = mappings
        self.codings = codings
        self.memos = memos
        headEventID = head
    }

    /// Active codings (not retracted).
    public var activeCodings: [GlifiCoding] {
        codings.filter { $0.retractionEventID == nil }
    }

    /// Coding table of one codebook revision for `coding-agreement-v2`.
    ///
    /// A unit is one (source revision, interval) coded by at least one of `coderIDs`. A coder with
    /// several active codings of the same unit makes the unit ambiguous: it is excluded and counted.
    public func agreementTable(
        codebookID: String, codebookRevision: Int, coderIDs: [String]
    ) throws -> (request: GlifiCodingAgreementRequest, ambiguousUnitCount: Int) {
        let relevant = activeCodings.filter {
            $0.codebookID == codebookID && $0.codebookRevision == codebookRevision
                && coderIDs.contains($0.coderID)
        }
        var labels: [String: [String: [String]]] = [:]
        for coding in relevant {
            let unit =
                "\(coding.sourceRevisionID.canonicalValue)#\(coding.range.start)-\(coding.range.end)"
            labels[unit, default: [:]][coding.coderID, default: []].append(coding.categoryID)
        }
        var units: [GlifiCodingUnit] = []
        var ambiguous = 0
        for unit in labels.keys.sorted() {
            let byCoder = labels[unit] ?? [:]
            guard byCoder.values.allSatisfy({ $0.count == 1 }) else {
                ambiguous += 1
                continue
            }
            units.append(
                GlifiCodingUnit(unitIdentifier: unit, labels: coderIDs.map { byCoder[$0]?.first }))
        }
        return (
            try GlifiCodingAgreementRequest(coderIdentifiers: coderIDs, units: units), ambiguous
        )
    }

    /// Equality ignores the tuple-based mapping storage order only through its content.
    public static func == (lhs: GlifiQualitativeState, rhs: GlifiQualitativeState) -> Bool {
        lhs.codebooks == rhs.codebooks && lhs.codings == rhs.codings && lhs.memos == rhs.memos
            && lhs.headEventID == rhs.headEventID
            && lhs.mappings.mapValues { $0.map { "\($0.from)-\($0.to)-\($0.mappings)" } }
                == rhs.mappings.mapValues { $0.map { "\($0.from)-\($0.to)-\($0.mappings)" } }
    }
}

func qualitativeFailure(
    _ code: String, category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .investigate,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.\(code)"
    )
}
