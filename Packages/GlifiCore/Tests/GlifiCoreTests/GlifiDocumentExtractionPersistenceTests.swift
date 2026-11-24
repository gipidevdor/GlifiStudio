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

@Test("Batch admission preserves mixed order, duplicates and exact known counts")
func documentExtractionAdmissionBatchOrder() throws {
    let fixture = try documentAdmissionFixture(sourceCount: 6, richCount: 3, artifactCount: 12)
    let records = [fixture.sources[4], fixture.sources[2], fixture.sources[0], fixture.sources[2]]
    let expected = [
        fixture.expected[4], fixture.expected[2], fixture.expected[0], fixture.expected[2],
    ]
    #expect(try documentAdmissionSingles(records, fixture.artifacts) == expected)
    #expect(
        try GlifiDocumentExtractionPersistence.admissionByteCounts(
            for: records, artifacts: fixture.artifacts) == expected)
    #expect(
        try GlifiDocumentExtractionPersistence.admissionByteCounts(
            for: [], artifacts: fixture.artifacts
        ).isEmpty)
    for source in fixture.sources {
        #expect(
            try GlifiDocumentExtractionPersistence.admissionByteCounts(
                for: [source], artifacts: fixture.artifacts)
                == [
                    GlifiDocumentExtractionPersistence.admissionByteCount(
                        for: source, artifacts: fixture.artifacts)
                ])
    }
}

@Test("Batch admission retains selective rejection and ignores the same unrelated descriptors")
func documentExtractionAdmissionBatchFailures() throws {
    let fixture = try documentAdmissionFixture(sourceCount: 4, richCount: 2, artifactCount: 4)
    let rich = fixture.sources[0]
    let matching = try #require(
        fixture.artifacts.first {
            $0.node.descriptor.sourceRevisionIDs == [rich.sourceRevisionID]
                && GlifiDocumentExtractionPersistence.isReserved($0.node.descriptor)
        })
    var cases: [(String, [GlifiProjectSourceRecord], [GlifiProjectArtifactRecord], Bool)] = [
        ("missing", fixture.sources, [], false),
        ("ambiguous", fixture.sources, fixture.artifacts + [matching], false),
    ]
    for field in [
        "algorithmVersion", "artifactTypeIdentifier", "algorithmIdentifier",
        "outputSchemaIdentifier",
    ] {
        let malformed = try documentAdmissionChanged(matching) {
            $0[field] = "unsupported-fixture-v2"
        }
        let artifacts = fixture.artifacts.map { $0 == matching ? malformed : $0 }
        cases.append((field, fixture.sources, artifacts, false))
        cases.append(
            ("\(field) after valid", fixture.sources, fixture.artifacts + [malformed], false))
        cases.append(
            ("\(field) before valid", fixture.sources, [malformed] + fixture.artifacts, false))
    }
    for count in [-1, 16_777_217] {
        let malformed = try documentAdmissionChanged(matching) { fields in
            var parameters = try #require(fields["resolvedParameters"] as? [String: Any])
            parameters["canonicalByteCount"] = ["type": "integer", "value": count]
            fields["resolvedParameters"] = parameters
        }
        cases.append(("canonical count", [rich, rich], [malformed], false))
    }
    let negative = try documentAdmissionSource(index: 50, format: .plainText, byteCount: -1)
    cases.append(("negative bytes", [negative, rich], fixture.artifacts, false))
    let plainAlias = GlifiProjectSourceRecord(
        sourceID: rich.sourceID, sourceRevisionID: rich.sourceRevisionID, format: .plainText,
        contentDigest: rich.contentDigest, byteCount: 3, objectPath: rich.objectPath)
    cases.append(("plain and rich alias", [plainAlias, rich, plainAlias], fixture.artifacts, true))
    let foreign = try documentAdmissionArtifact(
        source: documentAdmissionSource(index: 99, format: .pdf), ordinal: 99, reserved: true)
    let malformedForeign = try documentAdmissionChanged(foreign) { $0["algorithmVersion"] = "2" }
    let multiple = try documentAdmissionChanged(matching) {
        $0["sourceRevisionIDs"] = fixture.sources.prefix(2).map {
            $0.sourceRevisionID.canonicalValue
        }
    }
    let undeclared = try documentAdmissionChanged(matching) {
        $0["schemaIdentifier"] = GlifiAnalysisDescriptor.schemaIdentifier
        $0.removeValue(forKey: "sourceRevisionIDs")
    }
    let empty = try documentAdmissionChanged(matching) { $0["sourceRevisionIDs"] = [String]() }
    let plainMalformed = try documentAdmissionChanged(matching) {
        $0["sourceRevisionIDs"] = [fixture.sources[3].sourceRevisionID.canonicalValue]
        $0["algorithmVersion"] = "2"
    }
    cases.append(
        (
            "foreign and nonsingleton ignored", fixture.sources,
            fixture.artifacts + [malformedForeign, multiple, undeclared, empty, plainMalformed],
            true
        ))
    for (name, records, artifacts, accepted) in cases {
        let reference = try documentAdmissionOutcome {
            try documentAdmissionSingles(records, artifacts)
        }
        let batch = try documentAdmissionOutcome {
            try GlifiDocumentExtractionPersistence.admissionByteCounts(
                for: records, artifacts: artifacts)
        }
        #expect(batch == reference, "Differential case: \(name)")
        if accepted {
            if case .accepted = batch {} else { Issue.record("Expected acceptance: \(name)") }
        } else {
            #expect(batch == .rejected(GlifiDocumentExtractionPersistence.invalidSnapshot()))
        }
    }
}

@Test("Cancellation and invalid input keep their original per-record precedence")
func documentExtractionAdmissionBatchCancellation() async throws {
    let fixture = try documentAdmissionFixture(sourceCount: 3, richCount: 1, artifactCount: 2)
    let rich = fixture.sources[0]
    let negative = try documentAdmissionSource(index: 20, format: .plainText, byteCount: -1)
    let missing = try documentAdmissionSource(index: 21, format: .epub)
    let cases: [([GlifiProjectSourceRecord], DocumentAdmissionOutcome)] = [
        ([rich, negative], .cancelled),
        ([negative, rich], .rejected(GlifiDocumentExtractionPersistence.invalidSnapshot())),
        ([missing, rich], .rejected(GlifiDocumentExtractionPersistence.invalidSnapshot())),
        ([fixture.sources[1], fixture.sources[2]], .accepted(Array(fixture.expected.suffix(2)))),
        ([], .accepted([])),
    ]
    for (records, expected) in cases {
        let actual = try await Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            let reference = try documentAdmissionOutcome {
                try documentAdmissionSingles(records, fixture.artifacts)
            }
            let batch = try documentAdmissionOutcome {
                try GlifiDocumentExtractionPersistence.admissionByteCounts(
                    for: records, artifacts: fixture.artifacts)
            }
            return (reference, batch)
        }.value
        #expect(actual.0 == expected)
        #expect(actual.1 == expected)
    }
}

@Test("Source loading keeps an earlier cumulative budget failure before a later missing snapshot")
func documentExtractionAdmissionLoaderBudgetPrecedence() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let missing = try documentAdmissionSource(index: 2, format: .pdf)
        for (bytes, code) in [
            (10, "analysis.byte-limit-exceeded"), (3, "project.document-extraction-invalid"),
        ] {
            let plain = try documentAdmissionSource(index: 1, format: .plainText, byteCount: bytes)
            do {
                _ = try await GlifiEngine().importedSources(
                    [plain, missing], from: project, maximumSourceByteCount: 5)
                Issue.record("Expected header admission failure")
            } catch let failure as GlifiFailure {
                #expect(failure.code == code)
            }
        }
    }
}

@Test("Batch admission matches known corpus shapes using compiled product metadata helpers")
func documentExtractionAdmissionBatchCorpusShapes() throws {
    let measure = ProcessInfo.processInfo.environment["GLIFI_ADMISSION_BENCHMARK"] == "1"
    let shapes: [(String, Int, Int, Int)] = [
        ("plain-control", 1_000, 0, 1_000), ("small-rich", 25, 25, 50),
        ("mixed-100", 100, 25, 500), ("mixed-250", 250, 125, 2_000),
        ("mixed-1000", 1_000, 500, 5_000),
    ]
    for (label, count, rich, artifacts) in shapes {
        let fixture = try documentAdmissionFixture(
            sourceCount: count, richCount: rich, artifactCount: artifacts)
        #expect(
            try documentAdmissionSingles(fixture.sources, fixture.artifacts) == fixture.expected)
        #expect(
            try GlifiDocumentExtractionPersistence.admissionByteCounts(
                for: fixture.sources, artifacts: fixture.artifacts) == fixture.expected)
        guard measure else { continue }
        var baseline: [Double] = []
        var candidate: [Double] = []
        var checksum = 0
        for sample in 0..<7 {
            for batch in sample.isMultiple(of: 2) ? [false, true] : [true, false] {
                let start = DispatchTime.now().uptimeNanoseconds
                let values =
                    try batch
                    ? GlifiDocumentExtractionPersistence.admissionByteCounts(
                        for: fixture.sources, artifacts: fixture.artifacts)
                    : documentAdmissionSingles(fixture.sources, fixture.artifacts)
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                #expect(values == fixture.expected)
                checksum = checksum &+ values.reduce(0, &+)
                if batch { candidate.append(elapsed) } else { baseline.append(elapsed) }
            }
        }
        let report: [String: Any] = [
            "schema": "studio.glifi.document-admission-benchmark.v1", "label": label,
            "sources": count, "richSources": rich, "artifacts": artifacts, "samples": 7,
            "baselineMs": baseline, "candidateMs": candidate,
            "baselineMedianMs": baseline.sorted()[3], "candidateMedianMs": candidate.sorted()[3],
            "checksum": checksum,
            "sourceStride": MemoryLayout<GlifiProjectSourceRecord>.stride,
            "artifactStride": MemoryLayout<GlifiProjectArtifactRecord>.stride,
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}

private enum DocumentAdmissionOutcome: Equatable, Sendable {
    case accepted([Int])
    case rejected(GlifiFailure)
    case cancelled
}

private func documentAdmissionOutcome(_ body: () throws -> [Int]) throws -> DocumentAdmissionOutcome
{
    do { return .accepted(try body()) } catch is CancellationError { return .cancelled } catch let
        failure as GlifiFailure
    { return .rejected(failure) }
}

@inline(never)
private func documentAdmissionSingles(
    _ sources: [GlifiProjectSourceRecord], _ artifacts: [GlifiProjectArtifactRecord]
) throws -> [Int] {
    try sources.map {
        try GlifiDocumentExtractionPersistence.admissionByteCount(for: $0, artifacts: artifacts)
    }
}

private struct DocumentAdmissionFixture: Sendable {
    let sources: [GlifiProjectSourceRecord]
    let artifacts: [GlifiProjectArtifactRecord]
    let expected: [Int]
}

private func documentAdmissionFixture(
    sourceCount: Int, richCount: Int, artifactCount: Int
) throws -> DocumentAdmissionFixture {
    var sources: [GlifiProjectSourceRecord] = []
    var artifacts: [GlifiProjectArtifactRecord] = []
    var expected: [Int] = []
    for index in 0..<sourceCount {
        let format: GlifiTextFormat =
            index < richCount ? (index.isMultiple(of: 2) ? .pdf : .epub) : .plainText
        let source = try documentAdmissionSource(
            index: index, format: format, byteCount: 1_024 + index % 31)
        sources.append(source)
        expected.append(index < richCount ? 16_384 + index % 97 : source.byteCount)
        if index < richCount {
            artifacts.append(
                try documentAdmissionArtifact(source: source, ordinal: index, reserved: true))
        }
    }
    for index in richCount..<artifactCount {
        artifacts.append(
            try documentAdmissionArtifact(
                source: sources[index % sources.count], ordinal: index, reserved: false))
    }
    return DocumentAdmissionFixture(
        sources: sources, artifacts: Array(artifacts.reversed()), expected: expected)
}

private func documentAdmissionSource(
    index: Int, format: GlifiTextFormat, byteCount: Int = 1_024
) throws -> GlifiProjectSourceRecord {
    let uuid = try #require(
        UUID(uuidString: "31400000-0000-4000-8000-" + String(format: "%012x", index + 1)))
    let digest = "sha256:" + String(repeating: "0", count: 64)
    return GlifiProjectSourceRecord(
        sourceID: SourceID(uuid: uuid), sourceRevisionID: SourceRevisionID(uuid: uuid),
        format: format,
        contentDigest: digest, byteCount: byteCount,
        objectPath: "objects/00/" + String(repeating: "0", count: 64))
}

private func documentAdmissionArtifact(
    source: GlifiProjectSourceRecord, ordinal: Int, reserved: Bool
) throws -> GlifiProjectArtifactRecord {
    let descriptor = try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: reserved
            ? GlifiDocumentExtractionPersistence.artifactTypeIdentifier
            : "studio.glifi.artifact.metadata-fixture",
        algorithmIdentifier: reserved
            ? GlifiDocumentExtractionPersistence.algorithmIdentifier : "metadata-fixture-v1",
        algorithmVersion: "1", corpusIdentifier: "fixture-\(ordinal)",
        corpusVersionDigest: source.contentDigest,
        selectionIdentifier: "source-revision-all-v1",
        analyticalUnitIdentifier: "document-text-location-v1",
        preprocessingIdentifiers: ["captured-test-v1"], linguisticProfileIdentifiers: [],
        representationIdentifier: "captured-document-utf8-v1",
        resolvedParameters: [
            "canonicalByteCount": .integer(Int64(16_384 + ordinal % 97)),
            "documentUnitCount": .integer(1),
        ],
        seedPolicyIdentifier: "none-v1", backendIdentifier: "unavailable-test-backend-v1",
        numericPolicyIdentifier: "utf8-exact-captured-v1", determinismClass: .d0,
        outputSchemaIdentifier: reserved
            ? GlifiDocumentExtractionArtifactPayload.outputSchemaIdentifier
            : "studio.glifi.artifact.metadata-fixture.v1",
        softwareIdentifier: "metadata-fixture-v1", dependencies: [],
        sourceRevisionIDs: [source.sourceRevisionID])
    return try documentAdmissionArtifactRecord(descriptor)
}

private func documentAdmissionChanged(
    _ artifact: GlifiProjectArtifactRecord, _ change: (inout [String: Any]) throws -> Void
) throws -> GlifiProjectArtifactRecord {
    var fields = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(artifact.node.descriptor))
            as? [String: Any])
    try change(&fields)
    let descriptor = try JSONDecoder().decode(
        GlifiAnalysisDescriptor.self,
        from: JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]))
    return try documentAdmissionArtifactRecord(descriptor)
}

private func documentAdmissionArtifactRecord(_ descriptor: GlifiAnalysisDescriptor) throws
    -> GlifiProjectArtifactRecord
{
    let digest = try descriptor.canonicalDigest()
    return try GlifiProjectArtifactRecord(
        artifactID: ArtifactID(digest: digest), node: GlifiAnalysisNode(descriptor: descriptor),
        descriptorDigest: digest,
        descriptorByteCount: GlifiArtifactCanonicalJSON.encode(descriptor).count,
        descriptorObjectPath: "objects/" + String(digest.dropFirst(7)), contentDigest: digest,
        byteCount: 0, objectPath: "objects/" + String(digest.dropFirst(7)))
}
