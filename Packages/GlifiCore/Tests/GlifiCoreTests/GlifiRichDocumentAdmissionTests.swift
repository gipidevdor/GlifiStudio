// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiRichDocumentAdmissionTests {
    @Test(arguments: [GlifiTextFormat.pdf, .epub])
    func planningChargesCapturedTextAndKeepsObservedBinarySize(format: GlifiTextFormat) throws {
        let revision = SourceRevisionID()
        #expect(throws: GlifiFailure.self) {
            try GlifiPlanningSource(sourceRevisionID: revision, format: format, byteCount: 1)
        }
        let source = try GlifiPlanningSource(
            sourceRevisionID: revision, format: format, byteCount: 1, capturedTextByteCount: 10_000)
        let plan = try GlifiAnalysisPlanner().plan(
            request: GlifiAnalysisPlanRequest(
                intent: .understandCollection, maximumEstimatedWorkUnits: 9_999),
            sourceRootDigest: "sha256:" + String(repeating: "a", count: 64),
            configuredLanguageCode: "it", sources: [source])
        #expect(plan.status == .notExecutable)
        #expect(plan.totalEstimatedWorkUnits == 0)
        #expect(plan.collectionProfile.totalSourceByteCount == 1)
        #expect(plan.decisions.first?.estimatedWorkUnits == 10_064)
    }

    @Test func restoringACompressedSourceAdmitsItsCapturedRepresentationFirst() throws {
        let revision = SourceRevisionID()
        let text = "e\u{0301}"
        let snapshot = try GlifiDocumentExtraction(
            text: text,
            locations: [
                GlifiDocumentTextLocation(
                    range: GlifiUTF8Range(start: 0, end: 3), resourcePath: "chapter.xhtml",
                    method: "epub-xhtml")
            ], contractIdentifier: "epub-spine-xhtml-v1", backendIdentifier: "synthetic-test-v1",
            metadata: ["documentUnitCount": "1"])
        #expect(throws: GlifiFailure.self) {
            try GlifiTextImporter().restoreDocument(
                from: Data([0xFF]), format: .epub, extraction: snapshot,
                limits: GlifiTextImportLimits(maximumByteCount: 1, maximumExtractedByteCount: 2),
                sourceRevisionID: revision)
        }
        let imported = try GlifiTextImporter().restoreDocument(
            from: Data([0xFF]), format: .epub, extraction: snapshot,
            limits: GlifiTextImportLimits(maximumByteCount: 1, maximumExtractedByteCount: 3),
            sourceRevisionID: revision)
        #expect(imported.bytes == Data([0xFF]))
        #expect(imported.analysisByteCount == 3)
        #expect(try imported.sourceRepresentationText.utf8.elementsEqual(text.utf8))
        #expect(imported.spanMap.inputByteCount == 3)
    }

    @Test func capturedLocationsRejectInteriorUTF8AndInconsistentPageCounts() throws {
        let interior = try GlifiDocumentTextLocation(
            range: GlifiUTF8Range(start: 1, end: 2), resourcePath: "chapter.xhtml",
            method: "epub-xhtml")
        #expect(throws: GlifiFailure.self) {
            try GlifiDocumentExtraction(
                text: "é", locations: [interior], contractIdentifier: "test-v1",
                backendIdentifier: "test-v1", metadata: ["documentUnitCount": "1"])
        }
        let page = try GlifiDocumentTextLocation(
            range: GlifiUTF8Range(start: 0, end: 1), pageNumber: 2, method: "pdf-text")
        #expect(throws: GlifiFailure.self) {
            try GlifiDocumentExtraction(
                text: "x", locations: [page], contractIdentifier: "test-v1",
                backendIdentifier: "test-v1", metadata: ["documentUnitCount": "1"])
        }
    }
}
