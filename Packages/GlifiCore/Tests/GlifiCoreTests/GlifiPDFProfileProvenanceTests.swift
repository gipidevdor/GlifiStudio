// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("A new PDF profile preserves the old acquisition and deduplicates only original bytes")
func pdfProfileProvenancePreservesLegacyAndNewAcquisitions() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let sourceID = try pdfProfileProvenanceSourceID()
        let legacy = try pdfProfileProvenanceCapture(
            .legacy, revision: pdfProfileProvenanceRevision(1))
        let first = try await project.importText(legacy, sourceID: sourceID)
        let oldSource = try #require(first.sources.first)
        let oldArtifact = try #require(first.artifacts.first)
        let oldPayloadBytes = try await project.artifactData(for: oldArtifact.artifactID)
        let oldDescriptorBytes = try Data(
            contentsOf: url.appending(path: oldArtifact.descriptorObjectPath))
        let oldPayload = try JSONDecoder().decode(
            GlifiDocumentExtractionArtifactPayload.self, from: oldPayloadBytes)
        #expect(oldPayload.schemaIdentifier == "studio.glifi.artifact.document-extraction.v1")
        #expect(oldPayload.schemaVersion == 1)
        #expect(oldPayload.extraction.contractIdentifier == "pdfkit-pages-vision-ocr-v1")
        #expect(oldPayload.extraction.metadata["ocrRequestedRecognitionLevel"] == nil)
        #expect(oldPayload.extraction.metadata["ocrFallbackPageCount"] == nil)
        #expect(oldPayload.extraction.metadata["ocrFastPageNumbers"] == nil)

        let current = try pdfProfileProvenanceCapture(
            .resourceFallback, revision: pdfProfileProvenanceRevision(2))
        #expect(current.sourceRevisionID != legacy.sourceRevisionID)
        #expect(current.bytes == legacy.bytes)
        #expect(current.contentDigest == legacy.contentDigest)
        #expect(current.text.utf8.elementsEqual(legacy.text.utf8))
        let committed = try await project.importText(current, sourceID: sourceID)
        #expect(committed.generation == first.generation + 1)
        #expect(committed.sources.count == 2 && committed.artifacts.count == 2)
        let newSource = try #require(
            committed.sources.first { $0.sourceRevisionID == current.sourceRevisionID })
        #expect(committed.sources.contains(oldSource))
        #expect(oldSource.sourceID == newSource.sourceID)
        #expect(oldSource.objectPath == newSource.objectPath)
        #expect(oldSource.contentDigest == newSource.contentDigest)
        #expect(committed.artifacts.contains(oldArtifact))
        let newArtifact = try #require(
            committed.artifacts.first {
                $0.node.descriptor.sourceRevisionIDs == [current.sourceRevisionID]
            })
        #expect(newArtifact.node.id != oldArtifact.node.id)
        #expect(newArtifact.artifactID != oldArtifact.artifactID)
        let bindings = try GlifiDocumentExtractionPersistence.bindings(
            sources: committed.sources, artifacts: committed.artifacts)
        #expect(bindings.count == 2)
        #expect(bindings[legacy.sourceRevisionID] == oldArtifact)
        #expect(bindings[current.sourceRevisionID] == newArtifact)

        let reopened = try GlifiProjectPackage.open(at: url)
        #expect(await reopened.snapshot() == committed)
        let restoredLegacy = try await reopened.importedText(for: legacy.sourceRevisionID)
        let restoredCurrent = try await reopened.importedText(for: current.sourceRevisionID)
        #expect(restoredLegacy == legacy)
        #expect(restoredCurrent == current)
        #expect(restoredLegacy.text.utf8.elementsEqual(legacy.text.utf8))
        #expect(restoredCurrent.text.utf8.elementsEqual(current.text.utf8))
        #expect(restoredLegacy.documentExtraction == oldPayload.extraction)
        #expect(restoredLegacy.documentExtraction?.metadata["ocrRequestCount"] == nil)
        #expect(restoredLegacy.documentExtraction?.metadata["ocrRequestedRecognitionLevel"] == nil)
        #expect(restoredCurrent.documentExtraction?.metadata["ocrRecognitionLevel"] == "fast")
        #expect(
            restoredCurrent.documentExtraction?.metadata["ocrRequestedRecognitionLevel"]
                == "accurate")
        #expect(restoredCurrent.documentExtraction?.metadata["ocrRequestCount"] == "2")
        #expect(restoredCurrent.documentExtraction?.metadata["ocrFallbackPageCount"] == "1")
        #expect(restoredCurrent.documentExtraction?.metadata["ocrFastPageNumbers"] == "1")
        #expect(
            try await reopened.artifactData(for: oldArtifact.artifactID) == oldPayloadBytes)
        #expect(
            try Data(contentsOf: url.appending(path: oldArtifact.descriptorObjectPath))
                == oldDescriptorBytes)
        #expect(try await reopened.sourceData(for: legacy.sourceRevisionID) == legacy.bytes)
        #expect(try await reopened.sourceData(for: current.sourceRevisionID) == legacy.bytes)
    }
}

@Test("A new OCR profile cannot replace an extraction bound to an existing PDF revision")
func pdfProfileProvenanceRejectsExistingRevisionRebinding() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let sourceID = try pdfProfileProvenanceSourceID()
        let revision = try pdfProfileProvenanceRevision(1)
        let legacy = try pdfProfileProvenanceCapture(.legacy, revision: revision)
        let baseline = try await project.importText(legacy, sourceID: sourceID)
        let oldArtifact = try #require(baseline.artifacts.first)
        let oldPayloadBytes = try await project.artifactData(for: oldArtifact.artifactID)
        let oldDescriptorBytes = try Data(
            contentsOf: url.appending(path: oldArtifact.descriptorObjectPath))
        let incompatible = try pdfProfileProvenanceCapture(.resourceFallback, revision: revision)
        do {
            _ = try await project.importText(incompatible, sourceID: sourceID)
            Issue.record("A committed PDF revision was rebound to a new OCR profile")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.document-extraction-invalid")
            #expect(failure.category == .corruption)
            #expect(failure.retainedState == .lastCommittedGeneration)
            #expect(failure.arguments.isEmpty)
        }
        #expect(await project.snapshot() == baseline)
        let reopened = try GlifiProjectPackage.open(at: url)
        #expect(await reopened.snapshot() == baseline)
        #expect(try await reopened.importedText(for: revision) == legacy)
        #expect(try await reopened.artifactData(for: oldArtifact.artifactID) == oldPayloadBytes)
        #expect(
            try Data(contentsOf: url.appending(path: oldArtifact.descriptorObjectPath))
                == oldDescriptorBytes)
    }
}

@Test("OCR producer identity changes even when original, revision, text and locations are equal")
func pdfProfileProvenanceDistinguishesPolicyWithoutTextChanges() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let revision = try pdfProfileProvenanceRevision(1)
        let legacy = try pdfProfileProvenanceCapture(.legacy, revision: revision)
        let snapshot = try await project.importText(
            legacy, sourceID: pdfProfileProvenanceSourceID())
        let source = try #require(snapshot.sources.first)
        let current = try pdfProfileProvenanceCapture(.resourceFallback, revision: revision)
        let legacyExtraction = try #require(legacy.documentExtraction)
        let currentExtraction = try #require(current.documentExtraction)
        #expect(legacyExtraction.text.utf8.elementsEqual(currentExtraction.text.utf8))
        #expect(legacyExtraction.locations == currentExtraction.locations)
        #expect(legacy.contentDigest == current.contentDigest)
        let oldPrepared = try #require(
            try GlifiDocumentExtractionPersistence.prepare(legacy, source: source))
        let newPrepared = try #require(
            try GlifiDocumentExtractionPersistence.prepare(current, source: source))
        #expect(
            oldPrepared.descriptor.sourceRevisionIDs == newPrepared.descriptor.sourceRevisionIDs)
        #expect(
            oldPrepared.descriptor.backendIdentifier != newPrepared.descriptor.backendIdentifier)
        #expect(
            oldPrepared.descriptor.resolvedParameters["extractionDigest"]
                != newPrepared.descriptor.resolvedParameters["extractionDigest"])
        #expect(
            oldPrepared.descriptor.resolvedParameters["backendMetadata"]
                != newPrepared.descriptor.resolvedParameters["backendMetadata"])
        #expect(try oldPrepared.descriptor.nodeID() != newPrepared.descriptor.nodeID())
        #expect(oldPrepared.descriptorData != newPrepared.descriptorData)
        #expect(oldPrepared.data != newPrepared.data)
        #expect(await project.snapshot() == snapshot)
    }
}

private enum PDFProfileProvenanceFixture {
    case legacy
    case resourceFallback
}

private func pdfProfileProvenanceCapture(
    _ profile: PDFProfileProvenanceFixture, revision: SourceRevisionID
) throws -> GlifiImportedText {
    let text = "Città e\u{301} 314159."
    let location = try GlifiDocumentTextLocation(
        range: GlifiUTF8Range(start: 0, end: text.utf8.count), pageNumber: 1, method: "pdf-ocr",
        region: GlifiDocumentRegion(x: 0.1, y: 0.2, width: 0.8, height: 0.1), confidence: 0.95)
    let contract: String
    let backend: String
    var metadata = [
        "documentUnitCount": "1", "pageCount": "1", "digitalTextPageCount": "0",
        "ocrPageCount": "1", "ocrRevision": "3", "ocrRequestedLanguages": "it-IT,en-US",
        "operatingSystemVersion": "synthetic", "operatingSystemBuild": "captured-synthetic-build",
    ]
    switch profile {
    case .legacy:
        contract = "pdfkit-pages-vision-ocr-v1"
        backend = "PDFKit-synthetic;Vision-text-r3;OS-synthetic"
        metadata["ocrProfileIdentifier"] = "pdf-import-readable-text-accurate-v1"
        metadata["ocrRecognitionLevel"] = "accurate"
    case .resourceFallback:
        contract = "pdfkit-pages-vision-ocr-v2"
        backend = "PDFKit-synthetic;Vision-text-r3;OS-synthetic;OCR-policy-v2;OCR-level-fast"
        metadata["ocrProfileIdentifier"] =
            "pdf-import-readable-text-accurate-preferred-fast-resource-v2"
        metadata["ocrRequestedRecognitionLevel"] = "accurate"
        metadata["ocrRecognitionLevel"] = "fast"
        metadata["ocrRequestCount"] = "2"
        metadata["ocrFallbackPageCount"] = "1"
        metadata["ocrFastPageNumbers"] = "1"
    }
    let extraction = try GlifiDocumentExtraction(
        text: text, locations: [location], contractIdentifier: contract,
        backendIdentifier: backend, metadata: metadata)
    // These bytes are neither a valid PDF nor valid UTF-8; reopen must use the captured snapshot.
    return try GlifiTextImporter().restoreDocument(
        from: Data([0xFF, 0x00, 0x50, 0x44, 0x46, 0x01]), format: .pdf,
        extraction: extraction, sourceRevisionID: revision)
}

private func pdfProfileProvenanceSourceID() throws -> SourceID {
    SourceID(uuid: try #require(UUID(uuidString: "7D56EB9E-F672-4101-BFAA-222222222222")))
}

private func pdfProfileProvenanceRevision(_ index: Int) throws -> SourceRevisionID {
    let identifier: String
    switch index {
    case 1: identifier = "7D56EB9E-F672-4101-BFAA-000000000001"
    case 2: identifier = "7D56EB9E-F672-4101-BFAA-000000000002"
    default:
        throw GlifiDocumentExtractionPersistence.invalidSnapshot()
    }
    return SourceRevisionID(uuid: try #require(UUID(uuidString: identifier)))
}
