// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

struct GlifiDocumentImportWorkflowTests {
    @Test(arguments: [GlifiStudioTextFormat.pdf, .epub])
    func binaryDocumentsRemainQueryableAfterReopen(format: GlifiStudioTextFormat) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../Fixtures/DocumentImport/v1").standardizedFileURL
        let source = fixtures.appendingPathComponent(format == .pdf ? "digital.pdf" : "book.epub")
        let projectURL = root.appendingPathComponent("Rich.glifi")
        let service = GlifiStudioService()
        let session = try await service.createProject(at: projectURL)
        let result = try await session.importText(at: source, format: format)
        let record = try #require(result.project.sources.first)
        #expect(record.format == format)
        #expect(record.byteCount == (try Data(contentsOf: source)).count)
        #expect(result.project.generation == 1)
        #expect(result.project.artifactCount == 1)
        let captured = try await session.sourceText(sourceRevisionID: record.sourceRevisionID)
        let provenance = try #require(captured.document)
        #expect(provenance.format == format)
        #expect(provenance.originalContentDigest == record.contentDigest)
        #expect(captured.byteCount == captured.text.utf8.count)
        let matches = try await session.query("normalized:casa")
        #expect(!matches.matches.isEmpty)
        for match in matches.matches {
            for range in match.sourceRanges {
                let bytes = Array(captured.text.utf8)
                #expect(range.start >= 0 && range.end <= bytes.count)
                #expect(String(bytes: bytes[range.start..<range.end], encoding: .utf8) != nil)
            }
        }
        let corpus = try await session.analyzeCorpus()
        #expect(corpus.lexicalTokenCount > 0)
        let laboratory = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: [record.sourceRevisionID])
        #expect(laboratory.lexicalTokenCount == corpus.lexicalTokenCount)
        if format == .epub {
            #expect(provenance.locations.first?.resourcePath == "Book/b.xhtml")
            #expect(captured.text.hasPrefix("La casa"))
        } else {
            #expect(provenance.locations.first?.pageNumber == 1)
            #expect(provenance.locations.last?.pageNumber == 2)
        }
        let execution = try await session.executeAnalysisPlan(
            GlifiStudioAnalysisPlanRequest(intent: "understand.collection"))
        var completed: GlifiStudioAnalysisExecutionResult?
        for try await event in execution.events {
            if case let .completed(value) = event { completed = value }
        }
        let interpreted = try #require(completed)
        let evidence = try #require(interpreted.interpretation.evidence.first)
        let reference = try #require(evidence.sourceReferences.first)
        #expect(reference.representationIdentifier == "document-extracted-utf8.v1")
        #expect(reference.ranges.first?.start == 0)
        #expect(reference.ranges.first?.end == captured.text.utf8.count)
        await session.close()
        let reopened = try await service.openProject(at: projectURL)
        #expect(
            try await reopened.sourceText(sourceRevisionID: record.sourceRevisionID) == captured)
        let repeated = try await reopened.query("normalized:casa")
        #expect(repeated.matches == matches.matches)
        #expect(repeated.matchedSourceCount == matches.matchedSourceCount)
        await reopened.close()
    }
}
