// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Agreement computed from the persisted codings of one codebook revision.
public struct GlifiStoredCodingAgreement: Equatable, Sendable {
    /// Persisted agreement Artifact over the derived table.
    public let agreement: GlifiProjectDerivedResult<GlifiCodingAgreementAnalysis>
    /// Units excluded because one coder coded them more than once.
    public let ambiguousUnitCount: Int
}

/// Structured selection of a passage of the extracted text, usable without dragging.
///
/// The two forms are the accessible alternatives required by GS-UX-001-16: whole sentences, or an
/// interval of characters of the extracted text.
public enum GlifiPassageSelection: Equatable, Sendable {
    /// Every sentence from the first index through the last, both inclusive, as returned by
    /// ``GlifiEngine/textSegments(sourceRevisionID:in:)``.
    case sentences(first: Int, last: Int)
    /// The half-open interval `start..<end` of characters of the extracted text.
    case characters(start: Int, end: Int)
    /// The half-open UTF-8 interval `start..<end` of the extracted text, as a coding stores it.
    case bytes(start: Int, end: Int)
}

extension GlifiEngine {
    /// Appends one change to the qualitative history on top of the current head.
    ///
    /// A coding must address a source revision of the current generation with an interval of its
    /// extracted text that starts and ends on character boundaries.
    public func appendQualitativeEvent(
        _ payload: GlifiQualitativeEventPayload,
        recordedAtUnixMilliseconds: Int64,
        in project: GlifiProjectPackage
    ) async throws -> GlifiProjectSnapshot {
        let snapshot = await project.snapshot()
        if case let .segmentCoded(sourceRevisionID, range, _, _, _, _, _) = payload {
            guard
                let record = snapshot.sources.first(where: {
                    $0.sourceRevisionID == sourceRevisionID
                })
            else {
                throw qualitativeFailure("qualitative.source-not-found")
            }
            let text =
                try await importedSources(
                    [record], from: project, maximumSourceByteCount: Int.max
                ).first?.text ?? ""
            let utf8 = text.utf8
            guard range.end <= utf8.count,
                let start = utf8.index(
                    utf8.startIndex, offsetBy: range.start, limitedBy: utf8.endIndex),
                let end = utf8.index(
                    utf8.startIndex, offsetBy: range.end, limitedBy: utf8.endIndex),
                start.samePosition(in: text) != nil, end.samePosition(in: text) != nil
            else {
                throw qualitativeFailure("qualitative.invalid-range")
            }
        }
        if case let .memoAttached(.source(sourceRevisionID), _, _) = payload {
            guard snapshot.sources.contains(where: { $0.sourceRevisionID == sourceRevisionID })
            else {
                throw qualitativeFailure("qualitative.source-not-found")
            }
        }
        let event = try GlifiQualitativeEvent(
            predecessorEventID: snapshot.qualitativeEvents.last?.eventID,
            recordedAtUnixMilliseconds: recordedAtUnixMilliseconds,
            payload: payload
        )
        return try await project.appendQualitativeEvent(event)
    }

    /// Sentences of the extracted text of one source revision, as codable intervals.
    public func textSegments(
        sourceRevisionID: SourceRevisionID,
        in project: GlifiProjectPackage
    ) async throws -> [(range: GlifiUTF8Range, text: String)] {
        let text = try await extractedText(sourceRevisionID: sourceRevisionID, in: project)
        return try sentenceSegments(of: text)
    }

    /// Resolves a structured passage selection into one codable interval of the extracted text.
    ///
    /// Both forms address the same text: whole sentences, identified by their position in
    /// ``textSegments(sourceRevisionID:in:)``, or an interval of characters. A character interval
    /// is expressed in extended grapheme clusters, so the resolved interval always begins and
    /// ends on a character boundary. A selection outside the text, an empty one, or one whose
    /// passage contains no visible character is rejected with `qualitative.invalid-selection`.
    public func passage(
        sourceRevisionID: SourceRevisionID,
        selection: GlifiPassageSelection,
        in project: GlifiProjectPackage
    ) async throws -> (range: GlifiUTF8Range, text: String) {
        guard
            let resolved = try await passages(
                sourceRevisionID: sourceRevisionID, selections: [selection], in: project
            ).first
        else {
            throw qualitativeFailure("qualitative.invalid-selection")
        }
        return resolved
    }

    /// Resolves several selections of the same source, reading the extracted text once.
    ///
    /// The whole call fails when any selection is invalid, so a caller never receives a partial
    /// list it could mistake for a complete one.
    public func passages(
        sourceRevisionID: SourceRevisionID,
        selections: [GlifiPassageSelection],
        in project: GlifiProjectPackage
    ) async throws -> [(range: GlifiUTF8Range, text: String)] {
        let text = try await extractedText(sourceRevisionID: sourceRevisionID, in: project)
        var segments: [(range: GlifiUTF8Range, text: String)]?
        return try selections.map { selection in
            let bounds: (start: Int, end: Int)
            switch selection {
            case let .sentences(first, last):
                let resolved = try segments ?? sentenceSegments(of: text)
                segments = resolved
                guard first >= 0, last >= first, last < resolved.count else {
                    throw qualitativeFailure("qualitative.invalid-selection")
                }
                bounds = (resolved[first].range.start, resolved[last].range.end)
            case let .characters(start, end):
                guard start >= 0, end > start,
                    let lowerBound = text.index(
                        text.startIndex, offsetBy: start, limitedBy: text.endIndex),
                    let upperBound = text.index(
                        text.startIndex, offsetBy: end, limitedBy: text.endIndex)
                else {
                    throw qualitativeFailure("qualitative.invalid-selection")
                }
                bounds = (
                    text.utf8.distance(from: text.startIndex, to: lowerBound),
                    text.utf8.distance(from: text.startIndex, to: upperBound)
                )
            case let .bytes(start, end):
                bounds = (start, end)
            }
            guard let range = try? GlifiUTF8Range(start: bounds.start, end: bounds.end),
                let value = Self.characterAlignedText(range, in: text),
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw qualitativeFailure("qualitative.invalid-selection")
            }
            return (range, value)
        }
    }

    /// Number of characters of the extracted text, the upper bound of a character selection.
    public func extractedCharacterCount(
        sourceRevisionID: SourceRevisionID,
        in project: GlifiProjectPackage
    ) async throws -> Int {
        try await extractedText(sourceRevisionID: sourceRevisionID, in: project).count
    }

    /// Text of an interval, only when both bounds fall on character boundaries, as a coding needs.
    private static func characterAlignedText(_ range: GlifiUTF8Range, in text: String) -> String? {
        let utf8 = text.utf8
        guard range.end <= utf8.count,
            let lowerBound = utf8.index(
                utf8.startIndex, offsetBy: range.start, limitedBy: utf8.endIndex),
            let upperBound = utf8.index(
                utf8.startIndex, offsetBy: range.end, limitedBy: utf8.endIndex),
            let start = lowerBound.samePosition(in: text),
            let end = upperBound.samePosition(in: text)
        else {
            return nil
        }
        return String(text[start..<end])
    }

    private func extractedText(
        sourceRevisionID: SourceRevisionID,
        in project: GlifiProjectPackage
    ) async throws -> String {
        let snapshot = await project.snapshot()
        guard
            let record = snapshot.sources.first(where: { $0.sourceRevisionID == sourceRevisionID }),
            let text = try await importedSources(
                [record], from: project, maximumSourceByteCount: Int.max
            ).first?.text
        else {
            throw qualitativeFailure("qualitative.source-not-found")
        }
        return text
    }

    private func sentenceSegments(of text: String) throws -> [(
        range: GlifiUTF8Range, text: String
    )] {
        try textTokenizer.tokenize(text).sentences.compactMap { sentence in
            guard let value = sentence.range.text(in: text),
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            return (sentence.range, value)
        }
    }

    /// Deterministic projection of the persisted qualitative history.
    public func qualitativeState(in project: GlifiProjectPackage) async throws
        -> GlifiQualitativeState
    {
        try GlifiQualitativeState(events: try await project.qualitativeEvents())
    }

    /// Computes and persists agreement from the codings of one codebook revision.
    public func assessStoredCodingAgreement(
        codebookID: String,
        codebookRevision: Int,
        coderIDs: [String],
        in project: GlifiProjectPackage
    ) async throws -> GlifiStoredCodingAgreement {
        let state = try await qualitativeState(in: project)
        guard (state.codebooks[codebookID]?.count ?? 0) >= codebookRevision, codebookRevision >= 1
        else {
            throw qualitativeFailure("qualitative.unknown-revision")
        }
        let (request, ambiguous) = try state.agreementTable(
            codebookID: codebookID, codebookRevision: codebookRevision, coderIDs: coderIDs)
        return GlifiStoredCodingAgreement(
            agreement: try await assessCodingAgreement(in: project, request: request),
            ambiguousUnitCount: ambiguous
        )
    }
}
