// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// A verified passage and its explicitly distinct extracted and source representations.
public struct GlifiStudioStudyResolvedExcerpt: Encodable, Sendable {
    /// Frozen quote and personal title.
    public let excerpt: GlifiStudioStudyExcerpt
    /// Complete extracted text addressed by the anchor offsets.
    public let extractedText: String
    /// Source representation addressed by the source ranges.
    public let sourceText: String
    /// Real contributing intervals, never synthesized PDF rectangles.
    public let sourceRanges: [GlifiStudioStudyRange]
    /// Captured page or resource provenance, absent for historical text and Markdown.
    public let document: GlifiStudioDocumentProvenance?

    init(_ value: GlifiStudyResolvedExcerpt) throws {
        excerpt = try JSONDecoder().decode(
            GlifiStudioStudyExcerpt.self, from: studyKitData(value.excerpt))
        extractedText = value.extractedText
        sourceText = value.sourceText
        sourceRanges = try JSONDecoder().decode(
            [GlifiStudioStudyRange].self, from: studyKitData(value.sourceRanges))
        document = value.imported.documentExtraction.map {
            GlifiStudioDocumentProvenance(imported: value.imported, extraction: $0)
        }
    }
}

/// Exact verified original bytes for native PDF and document readers.
public struct GlifiStudioStudyOriginal: Encodable, Sendable {
    /// Immutable source revision.
    public let sourceRevisionID: String
    /// Digest of the exact original bytes.
    public let contentDigest: String
    /// Incorporated original format.
    public let format: GlifiStudioTextFormat
    /// Original file bytes, bounded at 64 MiB.
    public let data: Data

    init(_ value: GlifiStudyOriginal) {
        sourceRevisionID = value.sourceRevisionID
        contentDigest = value.contentDigest
        format = GlifiStudioTextFormat(value.format)
        data = value.data
    }
}

extension GlifiStudioProjectSession {
    /// Restores the notebook without creating a revision or re-extracting documents.
    public func studyState() async throws -> GlifiStudioStudyState {
        try await studyOperation(.query) { try await GlifiStudioStudyState(project.studyState()) }
    }

    /// Appends the complete project-bound notebook after an optimistic revision check.
    @discardableResult
    public func saveStudyState(_ state: GlifiStudioStudyState, expectedRevision: Int) async throws
        -> GlifiStudioStudyState
    {
        try await studyOperation(.persistProject) {
            try await GlifiStudioStudyState(
                project.saveStudyState(state.core(), expectedRevision: expectedRevision))
        }
    }

    /// Collects a native passage selection with its exact captured provenance.
    public func collectStudyExcerpt(
        sourceRevisionID: String, selection: GlifiStudioPassageSelection, title: String,
        groupID: String? = nil, expectedRevision: Int
    ) async throws -> GlifiStudioStudyState {
        try await studyOperation(.persistProject) {
            try await GlifiStudioStudyState(
                project.collectStudyExcerpt(
                    sourceRevisionID: sourceRevisionID, selection: selection.coreValue,
                    title: title, groupID: groupID, expectedRevision: expectedRevision))
        }
    }

    /// Restores the exact captured text and real source mapping of a collected passage.
    public func resolveStudyExcerpt(excerptID: String) async throws
        -> GlifiStudioStudyResolvedExcerpt
    {
        try await studyOperation(.query) {
            try await GlifiStudioStudyResolvedExcerpt(
                project.resolveStudyExcerpt(excerptID: excerptID))
        }
    }

    /// Exports the manual notebook as deterministic project-bound JSON or readable Markdown.
    public func exportStudy(format: GlifiStudioStudyExportFormat = .json) async throws -> Data {
        try await studyOperation(.export) {
            guard let core = GlifiStudyExportFormat(rawValue: format.rawValue) else {
                throw studyFailure("study.invalid-export")
            }
            return try await project.exportStudy(format: core)
        }
    }

    /// Restores verified original bytes for a native reader without changing the document.
    public func studyOriginal(sourceRevisionID: String) async throws -> GlifiStudioStudyOriginal {
        try await studyOperation(.query) {
            try await GlifiStudioStudyOriginal(
                project.studyOriginal(sourceRevisionID: sourceRevisionID))
        }
    }

    private func studyOperation<Value>(
        _ operation: GlifiOperationKind, _ body: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await performOperation(operation) {
                try studyCheckCancellation()
                return try await body()
            }
        } catch let failure as GlifiStudioFailure {
            if failure.category == "cancelled" {
                throw GlifiStudioFailure(studyFailure("study.cancelled", category: .cancelled))
            }
            throw failure
        }
    }
}
