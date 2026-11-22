// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// One category of a codebook revision.
public struct GlifiStudioCodebookCategory: Codable, Equatable, Sendable {
    /// Stable identity `[a-z0-9._-]{1,64}`.
    public let categoryID: String
    /// Parent in the same revision.
    public let parentCategoryID: String?
    /// Human label.
    public let label: String
    /// Operational definition.
    public let definition: String
    /// Coding instructions.
    public let instructions: String?

    /// Creates a category, validated when appended.
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

    init(_ value: GlifiCodebookCategory) {
        self.init(
            categoryID: value.categoryID, parentCategoryID: value.parentCategoryID,
            label: value.label, definition: value.definition, instructions: value.instructions)
    }

    /// Stable identity derived from a label: Italian-folded lowercase ASCII letters and digits,
    /// every other run of characters becomes one `-`, at most 64 characters.
    public static func identifier(forLabel label: String) -> String {
        let folded = label.folding(
            options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT")
        ).lowercased()
        var result = ""
        for scalar in folded.unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.isEmpty, !result.hasSuffix("-") {
                result.append("-")
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return String((result.isEmpty ? "categoria" : result).prefix(64))
    }

    var coreValue: GlifiCodebookCategory {
        GlifiCodebookCategory(
            categoryID: categoryID, parentCategoryID: parentCategoryID, label: label,
            definition: definition, instructions: instructions)
    }
}

/// Explicit mapping between two codebook revisions: `merge`, `split` or `rename`.
public struct GlifiStudioCategoryMapping: Codable, Equatable, Sendable {
    /// `merge`, `split` or `rename`.
    public let kind: String
    /// Categories of the source revision.
    public let fromCategoryIDs: [String]
    /// Categories of the target revision.
    public let toCategoryIDs: [String]

    /// Creates a mapping, validated when appended.
    public init(kind: String, fromCategoryIDs: [String], toCategoryIDs: [String]) {
        self.kind = kind
        self.fromCategoryIDs = fromCategoryIDs
        self.toCategoryIDs = toCategoryIDs
    }
}

/// Target of a memo.
public enum GlifiStudioMemoTarget: Codable, Equatable, Sendable {
    /// A coding event.
    case coding(eventID: String)
    /// A category of a codebook.
    case category(codebookID: String, categoryID: String)
    /// A source revision.
    case source(sourceRevisionID: String)
}

/// One change of the qualitative history, as a JSON-encodable request.
public enum GlifiStudioQualitativeChange: Codable, Equatable, Sendable {
    /// Complete revision of a codebook.
    case codebookRevised(
        codebookID: String, revision: Int, categories: [GlifiStudioCodebookCategory])
    /// Mappings between two revisions.
    case categoryMapped(
        codebookID: String, fromRevision: Int, toRevision: Int,
        mappings: [GlifiStudioCategoryMapping])
    /// One coded interval of the extracted text of a source revision.
    case segmentCoded(
        sourceRevisionID: String, startUTF8: Int, endUTF8: Int, codebookID: String,
        codebookRevision: Int, categoryID: String, coderID: String, origin: String)
    /// Withdraws a coding.
    case codingRetracted(codingEventID: String, reasonIdentifier: String)
    /// Attaches a memo.
    case memoAttached(target: GlifiStudioMemoTarget, coderID: String, text: String)

    func coreValue() throws -> GlifiQualitativeEventPayload {
        switch self {
        case let .codebookRevised(codebookID, revision, categories):
            return .codebookRevised(
                codebookID: codebookID, revision: revision, categories: categories.map(\.coreValue))
        case let .categoryMapped(codebookID, fromRevision, toRevision, mappings):
            return .categoryMapped(
                codebookID: codebookID, fromRevision: fromRevision, toRevision: toRevision,
                mappings: try mappings.map { mapping in
                    guard let kind = GlifiCategoryMappingKind(rawValue: mapping.kind) else {
                        throw Self.invalid()
                    }
                    return GlifiCategoryMapping(
                        kind: kind, fromCategoryIDs: mapping.fromCategoryIDs,
                        toCategoryIDs: mapping.toCategoryIDs)
                })
        case let .segmentCoded(
            sourceRevisionID, startUTF8, endUTF8, codebookID, codebookRevision, categoryID, coderID,
            origin):
            guard let codingOrigin = GlifiCodingOrigin(rawValue: origin) else {
                throw Self.invalid()
            }
            return .segmentCoded(
                sourceRevisionID: try SourceRevisionID(canonicalValue: sourceRevisionID),
                range: try GlifiUTF8Range(start: startUTF8, end: endUTF8),
                codebookID: codebookID, codebookRevision: codebookRevision,
                categoryID: categoryID, coderID: coderID, origin: codingOrigin)
        case let .codingRetracted(codingEventID, reasonIdentifier):
            return .codingRetracted(
                codingEventID: codingEventID, reasonIdentifier: reasonIdentifier)
        case let .memoAttached(target, coderID, text):
            let coreTarget: GlifiMemoTarget
            switch target {
            case let .coding(eventID): coreTarget = .coding(eventID: eventID)
            case let .category(codebookID, categoryID):
                coreTarget = .category(codebookID: codebookID, categoryID: categoryID)
            case let .source(sourceRevisionID):
                coreTarget = .source(
                    sourceRevisionID: try SourceRevisionID(canonicalValue: sourceRevisionID))
            }
            return .memoAttached(target: coreTarget, coderID: coderID, text: text)
        }
    }

    private static func invalid() -> GlifiFailure {
        GlifiFailure(
            code: "qualitative.invalid-event",
            category: .invalidInput,
            operation: .investigate,
            retryDisposition: .afterCorrection,
            retainedState: .unchanged,
            messageKey: "failure.qualitative.invalid-event"
        )
    }
}

/// One codebook with every revision.
public struct GlifiStudioCodebook: Codable, Equatable, Sendable {
    /// Codebook identity.
    public let codebookID: String
    /// Revisions in order; revision `n` is at index `n-1`.
    public let revisions: [[GlifiStudioCodebookCategory]]
}

/// One coding, retracted ones included.
public struct GlifiStudioCoding: Codable, Equatable, Sendable {
    /// Recording event.
    public let eventID: String
    /// Coded source revision.
    public let sourceRevisionID: String
    /// Inclusive UTF-8 start in the extracted text.
    public let startUTF8: Int
    /// Exclusive UTF-8 end in the extracted text.
    public let endUTF8: Int
    /// Codebook.
    public let codebookID: String
    /// Codebook revision.
    public let codebookRevision: Int
    /// Category.
    public let categoryID: String
    /// Pseudonymous coder.
    public let coderID: String
    /// `manual` or `automatic`.
    public let origin: String
    /// Retraction event, when withdrawn.
    public let retractionEventID: String?
}

/// One memo.
public struct GlifiStudioMemo: Codable, Equatable, Sendable {
    /// Recording event.
    public let eventID: String
    /// Annotated object.
    public let target: GlifiStudioMemoTarget
    /// Pseudonymous author.
    public let coderID: String
    /// Memo text.
    public let text: String
}

/// Presentation-independent projection of the qualitative history.
public struct GlifiStudioQualitativeState: Codable, Equatable, Sendable {
    /// Codebooks by identity.
    public let codebooks: [GlifiStudioCodebook]
    /// Codings in history order.
    public let codings: [GlifiStudioCoding]
    /// Memos in history order.
    public let memos: [GlifiStudioMemo]
    /// Head event, absent for an empty history.
    public let headEventID: String?

    init(_ state: GlifiQualitativeState) {
        codebooks = state.codebooks.keys.sorted().map { identity in
            GlifiStudioCodebook(
                codebookID: identity,
                revisions: (state.codebooks[identity] ?? []).map {
                    $0.map(GlifiStudioCodebookCategory.init)
                })
        }
        codings = state.codings.map {
            GlifiStudioCoding(
                eventID: $0.eventID, sourceRevisionID: $0.sourceRevisionID.canonicalValue,
                startUTF8: $0.range.start, endUTF8: $0.range.end, codebookID: $0.codebookID,
                codebookRevision: $0.codebookRevision, categoryID: $0.categoryID,
                coderID: $0.coderID, origin: $0.origin.rawValue,
                retractionEventID: $0.retractionEventID)
        }
        memos = state.memos.map { memo in
            let target: GlifiStudioMemoTarget
            switch memo.target {
            case let .coding(eventID): target = .coding(eventID: eventID)
            case let .category(codebookID, categoryID):
                target = .category(codebookID: codebookID, categoryID: categoryID)
            case let .source(sourceRevisionID):
                target = .source(sourceRevisionID: sourceRevisionID.canonicalValue)
            }
            return GlifiStudioMemo(
                eventID: memo.eventID, target: target, coderID: memo.coderID, text: memo.text)
        }
        headEventID = state.headEventID
    }
}

/// Agreement computed from persisted codings.
public struct GlifiStudioStoredCodingAgreement: Codable, Equatable, Sendable {
    /// Persisted agreement over the derived table.
    public let agreement: GlifiStudioCodingAgreementResult
    /// Units excluded because a coder coded them more than once.
    public let ambiguousUnitCount: Int
}

/// One selectable interval of the extracted text, used as a structured selection.
public struct GlifiStudioTextSegment: Codable, Equatable, Identifiable, Sendable {
    /// Stable identity within the source.
    public var id: String { "\(startUTF8)-\(endUTF8)" }
    /// Inclusive UTF-8 start in the extracted text.
    public let startUTF8: Int
    /// Exclusive UTF-8 end in the extracted text.
    public let endUTF8: Int
    /// Segment text.
    public let text: String
}

/// Structured selection of a passage of the extracted text, usable without dragging.
///
/// Mirrors ``GlifiPassageSelection``: whole sentences of the source, identified by their position
/// among the segments, or an interval of characters of the extracted text.
public enum GlifiStudioPassageSelection: Codable, Equatable, Sendable {
    /// Every segment from the first index through the last, both inclusive.
    case sentences(first: Int, last: Int)
    /// The half-open interval `start..<end` of characters of the extracted text.
    case characters(start: Int, end: Int)
    /// The half-open UTF-8 interval `start..<end` of the extracted text, as a coding stores it.
    case bytes(start: Int, end: Int)

    var coreValue: GlifiPassageSelection {
        switch self {
        case let .sentences(first, last): .sentences(first: first, last: last)
        case let .characters(start, end): .characters(start: start, end: end)
        case let .bytes(start, end): .bytes(start: start, end: end)
        }
    }
}
