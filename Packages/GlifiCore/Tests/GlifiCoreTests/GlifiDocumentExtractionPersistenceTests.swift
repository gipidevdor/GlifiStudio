// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test(
    "Rich sources and captured text reopen unchanged without a usable document backend",
    arguments: [GlifiTextFormat.pdf, .epub])
func documentExtractionPersistenceRoundTrip(format: GlifiTextFormat) async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try documentPersistenceCapturedDocument(format: format)
        let committed = try await project.importText(imported)
        #expect(
            committed.generation == 1 && committed.sources.count == 1
                && committed.artifacts.count == 1)
        #expect(try await project.sourceData(for: imported.sourceRevisionID) == imported.bytes)
        let reopened = try GlifiProjectPackage.open(at: url)
        let restored = try await reopened.importedText(for: imported.sourceRevisionID)
        #expect(restored == imported)
        #expect(try restored.sourceRepresentationText.utf8.elementsEqual(imported.text.utf8))
        #expect(restored.spanMap.inputByteCount == imported.text.utf8.count)
        #expect(restored.documentExtraction?.metadata["os"] == "captured-system-version")
        let plain = try GlifiTextImporter().importText(
            from: Data("Later source".utf8), format: .plainText)
        let next = try await reopened.importText(plain)
        #expect(next.generation == 2 && next.artifacts == committed.artifacts)
        #expect(try await reopened.importedText(for: imported.sourceRevisionID) == imported)
    }
}

@Test(
    "Every import checkpoint exposes either the old generation or the complete rich snapshot",
    arguments: GlifiProjectCommitInterruption.allCases, [GlifiTextFormat.pdf, .epub])
func documentExtractionPersistenceAtomicCheckpoints(
    checkpoint: GlifiProjectCommitInterruption, format: GlifiTextFormat
) async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let old = try GlifiTextImporter().importText(
            from: Data("Existing source".utf8), format: .plainText)
        let baseline = try await project.importText(old)
        let imported = try documentPersistenceCapturedDocument(format: format)
        do {
            _ = try await project.importText(
                imported, sourceID: SourceID(), interruption: checkpoint)
            Issue.record("Expected injected interruption")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "test.interrupted-commit")
        }
        let reopened = try GlifiProjectPackage.open(at: url)
        let snapshot = await reopened.snapshot()
        switch checkpoint {
        case .staged, .objectPromoted, .databasePrepared, .manifestPrepared:
            #expect(snapshot == baseline)
        case .manifestReplaced, .databaseCommitted:
            #expect(snapshot.generation == baseline.generation + 1)
            #expect(snapshot.sources.count == 2 && snapshot.artifacts.count == 1)
            #expect(try await reopened.importedText(for: imported.sourceRevisionID) == imported)
        }
        #expect(try await reopened.sourceData(for: old.sourceRevisionID) == old.bytes)
    }
}

@Test("The extraction schema cannot be rewritten through generic artifact storage")
func documentExtractionPersistenceReservedStore() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try documentPersistenceCapturedDocument(format: .pdf)
        let snapshot = try await project.importText(imported)
        let artifact = try #require(snapshot.artifacts.first)
        let payload = try JSONDecoder().decode(
            GlifiDocumentExtractionArtifactPayload.self,
            from: await project.artifactData(for: artifact.artifactID))
        do {
            _ = try await project.storeArtifact(payload, descriptor: artifact.node.descriptor)
            Issue.record("Generic artifact storage accepted an import-owned snapshot")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.document-extraction-import-only")
            #expect(failure.category == .invalidInput)
        }
        #expect(await project.snapshot() == snapshot)
    }
}

@Test("Missing or ambiguous extraction bindings fail closed before payload decoding")
func documentExtractionPersistenceBindingIntegrity() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let snapshot = try await project.importText(
            documentPersistenceCapturedDocument(format: .epub))
        let record = try #require(snapshot.artifacts.first)
        for artifacts in [[], [record, record]] {
            #expect(throws: GlifiFailure.self) {
                try GlifiDocumentExtractionPersistence.bindings(
                    sources: snapshot.sources, artifacts: artifacts)
            }
        }
        let bytes = try await project.artifactData(for: record.artifactID)
        var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        json["unrecognizedCanary"] = "must not be ignored"
        let changed = try JSONSerialization.data(
            withJSONObject: json, options: [.sortedKeys, .withoutEscapingSlashes])
        #expect(throws: GlifiFailure.self) {
            try GlifiDocumentExtractionPersistence.decode(
                changed, source: snapshot.sources[0], artifact: record)
        }
    }
}

@Test("A rich loader rejects lower text budgets before accessing the payload")
func documentExtractionPersistenceHeaderAdmission() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try documentPersistenceCapturedDocument(format: .pdf)
        let snapshot = try await project.importText(imported)
        let source = try #require(snapshot.sources.first)
        let artifact = try #require(snapshot.artifacts.first)
        #expect(
            try GlifiDocumentExtractionPersistence.admissionByteCount(
                for: source, artifacts: snapshot.artifacts)
                == max(imported.bytes.count, imported.text.utf8.count))
        try FileManager.default.removeItem(at: url.appending(path: artifact.objectPath))
        for limits in [
            GlifiTextImportLimits(maximumByteCount: 1_024, maximumExtractedByteCount: 1),
            GlifiTextImportLimits(maximumByteCount: 1_024, maximumDocumentUnitCount: 0),
        ] {
            do {
                _ = try await project.importedText(for: source.sourceRevisionID, limits: limits)
                Issue.record("The caller's text or unit limit was ignored")
            } catch let failure as GlifiFailure {
                #expect(failure.category == .insufficientResources)
            }
        }
    }
}

@Test("Escaped extraction JSON cannot exceed the existing artifact envelope")
func documentExtractionPersistenceEncodedLimit() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        // Each NUL needs six JSON bytes. The source text remains below its 16 MiB
        // ceiling while the immutable payload exceeds the existing 64 MiB envelope.
        let imported = try documentPersistenceCapturedDocument(
            format: .pdf, text: String(repeating: "\0", count: 11_184_811))
        let baseline = await project.snapshot()
        do {
            _ = try await project.importText(imported)
            Issue.record("An extraction larger than the encoded artifact envelope was published")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .insufficientResources)
            #expect(failure.code == "project.artifact-too-large")
        }
        #expect(await project.snapshot() == baseline)
        #expect(try await GlifiProjectPackage.open(at: url).snapshot() == baseline)
    }
}

@Test(
    "Tampering with an extraction rejects current reads and permits an intact historical recovery",
    arguments: [false, true])
func documentExtractionPersistenceTamperAndRecovery(remove: Bool) async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let first = try documentPersistenceCapturedDocument(
            format: .pdf, text: "First captured text")
        let previous = try await project.importText(first)
        let second = try documentPersistenceCapturedDocument(
            format: .epub, text: "Second captured text")
        let current = try await project.importText(second)
        let artifact = try #require(
            current.artifacts.first {
                $0.node.descriptor.sourceRevisionIDs == [second.sourceRevisionID]
            })
        let payloadURL = url.appending(path: artifact.objectPath)
        if remove {
            try FileManager.default.removeItem(at: payloadURL)
        } else {
            try Data("modified extraction".utf8).write(to: payloadURL)
        }
        await #expect(throws: GlifiFailure.self) {
            try await project.importedText(for: second.sourceRevisionID)
        }
        #expect(throws: GlifiFailure.self) { try GlifiProjectPackage.open(at: url) }
        let recovery = try GlifiProjectPackage.openReadOnlyRecovery(at: url)
        #expect(recovery.snapshot == previous)
        #expect(try recovery.importedText(for: first.sourceRevisionID) == first)
        #expect(try recovery.sourceData(for: first.sourceRevisionID) == first.bytes)
    }
}

@Test(
    "TXT and Markdown keep their original bytes and acquire no extraction artifact",
    arguments: [GlifiTextFormat.plainText, .markdown])
func documentExtractionPersistenceHistoricalFormats(format: GlifiTextFormat) async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let bytes = Data([0xEF, 0xBB, 0xBF]) + Data("# Città\r\nUnicode e\u{301}".utf8)
        let imported = try GlifiTextImporter().importText(from: bytes, format: format)
        let snapshot = try await project.importText(imported)
        #expect(snapshot.generation == 1 && snapshot.artifacts.isEmpty)
        let restored = try await project.importedText(for: imported.sourceRevisionID)
        #expect(restored == imported && restored.documentExtraction == nil)
        #expect(
            try restored.sourceRepresentationText.utf8.elementsEqual(
                String(decoding: bytes, as: UTF8.self).utf8))
    }
}

func documentPersistenceCapturedDocument(
    format: GlifiTextFormat, text: String = "Città e mare.\n新しい章"
) throws -> GlifiImportedText {
    let range = try GlifiUTF8Range(start: 0, end: text.utf8.count)
    let location: GlifiDocumentTextLocation
    switch format {
    case .pdf: location = try .init(range: range, pageNumber: 1, method: "pdf-text")
    case .epub:
        location = try .init(range: range, resourcePath: "Text/chapter.xhtml", method: "epub-xhtml")
    case .plainText, .markdown:
        throw GlifiDocumentExtractionPersistence.invalidSnapshot()
    }
    let extraction = try GlifiDocumentExtraction(
        text: text, locations: [location], contractIdentifier: "captured-test-v1",
        backendIdentifier: "unavailable-test-backend-v1",
        metadata: [
            "documentUnitCount": "1", "os": "captured-system-version", "revision": "fixture-v1",
        ])
    // Neither a PDF parser nor a ZIP reader can interpret these bytes. A successful
    // reopen therefore proves that the saved snapshot, rather than a backend, is used.
    return try GlifiTextImporter().restoreDocument(
        from: Data([0xFF, 0x00, 0x50, 0x44, 0x46, 0x01]), format: format,
        extraction: extraction, sourceRevisionID: SourceRevisionID())
}

func withDocumentPersistenceProject(_ body: (URL) async throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "GlifiDocumentPersistence-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    try await body(directory.appending(path: "Test.glifi", directoryHint: .isDirectory))
}
