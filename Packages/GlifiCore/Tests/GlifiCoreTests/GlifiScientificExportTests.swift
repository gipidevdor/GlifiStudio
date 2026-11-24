// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import PDFKit
import Testing

@testable import GlifiCore

@Test("L'export scientifico inventaria JSON/Markdown/CSV/PDF e rileva manomissioni")
func scientificExportIsCanonicalAndTamperEvident() async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(
        path: "Relazione.glifiexport",
        directoryHint: .isDirectory
    )
    let exporter = GlifiScientificExporter()
    let receipt = try exporter.export(
        snapshot: fixture.snapshot,
        investigation: fixture.investigation,
        interpretationRecord: fixture.interpretationRecord,
        interpretation: fixture.interpretation,
        request: try GlifiScientificExportRequest(
            investigationHeadEventID: fixture.investigation.headEventID,
            formats: GlifiScientificExportFormat.allCases
        ),
        to: destination,
        environment: deterministicEnvironment,
        exportID: try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000001")),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let manifest = try GlifiScientificExporter.verifyExport(at: destination)
    let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    #expect(permissions.intValue & 0o777 == 0o700)
    #expect(manifest.exportID == "90000000-0000-0000-0000-000000000001")
    #expect(
        manifest.files.map(\.path)
            == ["evidence.csv", "findings.csv", "report.json", "report.md", "report.pdf"])
    #expect(
        manifest.selection.selectedFindingIDs
            == fixture.investigation.selectedFindingIDs.map(\.canonicalValue))
    #expect(manifest.corpus.sources.count == 1)
    #expect(manifest.corpus.sources[0].contentDigest == fixture.snapshot.sources[0].contentDigest)
    #expect(manifest.analysis.descriptorDigest == fixture.interpretationRecord.descriptorDigest)
    #expect(manifest.validation.status == "candidate")
    #expect(receipt.reportRevisionID.canonicalValue == manifest.selection.reportRevisionID)
    #expect(receipt.fileCount == 5)

    let reportData = try Data(contentsOf: destination.appending(path: "report.json"))
    let report = try JSONDecoder().decode(GlifiReportRevision.self, from: reportData)
    #expect(report.findings.map(\.id) == fixture.investigation.selectedFindingIDs)
    #expect(
        Set(report.evidence.map(\.id))
            == Set(report.findings.flatMap { $0.evidenceReferences.map(\.evidenceID) }))
    #expect(!String(decoding: reportData, as: UTF8.self).contains("uno due due"))

    let markdown = try String(contentsOf: destination.appending(path: "report.md"), encoding: .utf8)
    #expect(markdown.contains("# Relazione di indagine"))
    #expect(markdown.contains("\\# corpus"))

    let findingsCSV = try String(
        contentsOf: destination.appending(path: "findings.csv"),
        encoding: .utf8
    )
    let evidenceCSV = try String(
        contentsOf: destination.appending(path: "evidence.csv"),
        encoding: .utf8
    )
    #expect(findingsCSV.hasPrefix("\"ordinal\",\"finding_id\","))
    #expect(findingsCSV.contains("\r\n"))
    #expect(!findingsCSV.contains("uno due due"))
    #expect(!evidenceCSV.contains("uno due due"))

    let pdfData = try Data(contentsOf: destination.appending(path: "report.pdf"))
    if let directory = ProcessInfo.processInfo.environment["GLIFI_ORACLE_PDF_DIRECTORY"] {
        try pdfData.write(to: URL(fileURLWithPath: directory).appending(path: "report.pdf"))
    }
    let pdf = try #require(PDFDocument(data: pdfData))
    #expect(pdf.pageCount >= 1)
    #expect(pdf.string?.contains("Relazione di indagine") == true)
    #expect(pdf.string?.contains("Tracciabilità") == true)
    #expect(pdf.string?.contains("uno due due") != true)

    let manifestData = try Data(contentsOf: destination.appending(path: "export-manifest.json"))
    var alteredManifest = try #require(
        JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
    )
    var alteredCorpus = try #require(alteredManifest["corpus"] as? [String: Any])
    alteredCorpus["digest"] = "sha256:" + String(repeating: "0", count: 64)
    alteredManifest["corpus"] = alteredCorpus
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(
            GlifiExportManifest.self,
            from: JSONSerialization.data(withJSONObject: alteredManifest)
        )
    }

    try (manifestData + Data("\n".utf8)).write(
        to: destination.appending(path: "export-manifest.json")
    )
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiScientificExporter.verifyExport(at: destination)
    }
    try manifestData.write(to: destination.appending(path: "export-manifest.json"))

    try Data("manomissione".utf8).append(to: destination.appending(path: "report.json"))
    do {
        _ = try GlifiScientificExporter.verifyExport(at: destination)
        Issue.record("Era attesa la rilevazione della manomissione")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "export.invalid-file" || failure.code == "export.digest-mismatch")
    }
}

@Test(
    "Un'interruzione export non pubblica una destinazione parziale",
    arguments: [
        GlifiExportInterruption.payloadsWritten,
        .manifestWritten,
        .stagingValidated,
    ]
)
func scientificExportInterruptionPreservesDestination(
    interruption: GlifiExportInterruption
) async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(
        path: "Interrotto-\(String(describing: interruption)).glifiexport",
        directoryHint: .isDirectory
    )

    #expect(throws: GlifiFailure.self) {
        _ = try GlifiScientificExporter().export(
            snapshot: fixture.snapshot,
            investigation: fixture.investigation,
            interpretationRecord: fixture.interpretationRecord,
            interpretation: fixture.interpretation,
            request: try GlifiScientificExportRequest(
                investigationHeadEventID: fixture.investigation.headEventID
            ),
            to: destination,
            environment: deterministicEnvironment,
            exportID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            interruption: interruption
        )
    }
    #expect(!FileManager.default.fileExists(atPath: destination.path))
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
    #expect(!leftovers.contains { $0.contains(".exporting-") })
}

@Test(
    "An already cancelled scientific export preserves user files and publishes nothing",
    arguments: [false, true])
func scientificExportPreCancelledPreservesDestination(existingDestination: Bool) async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(
        path: "Cancelled.glifiexport", directoryHint: .isDirectory)
    if existingDestination {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
    }
    let userFile = (existingDestination ? destination : fixture.root).appending(
        path: "user-note.txt")
    let userData = Data("Keep this existing user file".utf8)
    try userData.write(to: userFile)
    let projectManifest = fixture.root.appending(path: "Export.glifi/manifest.json")
    let originalManifest = try Data(contentsOf: projectManifest)
    let request = try GlifiScientificExportRequest(
        investigationHeadEventID: fixture.investigation.headEventID)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiScientificExporter().export(
            snapshot: fixture.snapshot,
            investigation: fixture.investigation,
            interpretationRecord: fixture.interpretationRecord,
            interpretation: fixture.interpretation,
            request: request,
            to: destination,
            environment: deterministicEnvironment,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }
    do {
        _ = try await task.value
        Issue.record("An already cancelled export succeeded")
    } catch is CancellationError {
        // The engine translates this cancellation to the existing export failure contract.
    }
    #expect(FileManager.default.fileExists(atPath: destination.path) == existingDestination)
    #expect(try Data(contentsOf: userFile) == userData)
    #expect(try Data(contentsOf: projectManifest) == originalManifest)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
    #expect(!leftovers.contains { $0.contains(".exporting-") })
}

@Test(
    "Scientific export cancellation respects the rename commit and preserves exact output",
    arguments: GlifiExportInterruption.allCases, [false, true])
func scientificExportCancellationAtCheckpoint(
    checkpoint: GlifiExportInterruption, cancels: Bool
) async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let reference = fixture.root.appending(
        path: "Reference.glifiexport", directoryHint: .isDirectory)
    let destination = fixture.root.appending(
        path: "Observed.glifiexport", directoryHint: .isDirectory)
    let projectManifest = fixture.root.appending(path: "Export.glifi/manifest.json")
    let originalManifest = try Data(contentsOf: projectManifest)
    let request = try GlifiScientificExportRequest(
        investigationHeadEventID: fixture.investigation.headEventID,
        formats: [.csv, .json, .markdown])
    let exportID = try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000317"))
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let expectedReceipt = try GlifiScientificExporter().export(
        snapshot: fixture.snapshot,
        investigation: fixture.investigation,
        interpretationRecord: fixture.interpretationRecord,
        interpretation: fixture.interpretation,
        request: request,
        to: reference,
        environment: deterministicEnvironment,
        exportID: exportID,
        createdAt: createdAt)
    let task = Task { () throws -> (GlifiExportReceipt?, Bool) in
        do {
            let receipt = try GlifiScientificExporter().export(
                snapshot: fixture.snapshot,
                investigation: fixture.investigation,
                interpretationRecord: fixture.interpretationRecord,
                interpretation: fixture.interpretation,
                request: request,
                to: destination,
                environment: deterministicEnvironment,
                exportID: exportID,
                createdAt: createdAt,
                interruption: checkpoint,
                interruptionBehavior: .observe {
                    if cancels { withUnsafeCurrentTask { $0?.cancel() } }
                })
            return (receipt, Task.isCancelled)
        } catch is CancellationError {
            return (nil, Task.isCancelled)
        }
    }
    let (receipt, wasCancelled) = try await task.value
    #expect(wasCancelled == cancels)
    if cancels, checkpoint != .destinationCommitted {
        #expect(receipt == nil)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    } else {
        #expect(receipt == expectedReceipt)
        let manifest = try GlifiScientificExporter.verifyExport(at: destination)
        #expect(manifest.exportID == expectedReceipt.exportID)
        let names = try FileManager.default.contentsOfDirectory(atPath: reference.path).sorted()
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted() == names)
        for name in names {
            #expect(
                try Data(contentsOf: destination.appending(path: name))
                    == Data(contentsOf: reference.appending(path: name)))
        }
    }
    #expect(try Data(contentsOf: projectManifest) == originalManifest)
    _ = try GlifiScientificExporter.verifyExport(at: reference)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
    #expect(!leftovers.contains { $0.contains(".exporting-") })
}

@Test(
    "Scientific export verification preserves cancellation instead of reporting corrupt data",
    arguments: [false, true])
func scientificExportVerificationPreservesCancellation(directRead: Bool) async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(
        path: "Verified.glifiexport", directoryHint: .isDirectory)
    _ = try GlifiScientificExporter().export(
        snapshot: fixture.snapshot,
        investigation: fixture.investigation,
        interpretationRecord: fixture.interpretationRecord,
        interpretation: fixture.interpretation,
        request: GlifiScientificExportRequest(
            investigationHeadEventID: fixture.investigation.headEventID, formats: [.json]),
        to: destination,
        environment: deterministicEnvironment)
    let original = try GlifiScientificExporter.verifyExport(at: destination)
    let task = Task {
        let directory = try GlifiPackageDirectory(at: destination)
        withUnsafeCurrentTask { $0?.cancel() }
        if directRead {
            _ = try GlifiScientificExporter.readFile(
                GlifiScientificExporter.manifestFileName, in: directory,
                maximumByteCount: GlifiProjectPackage.maximumManifestByteCount,
                failureCode: "export.invalid-manifest")
        } else {
            _ = try GlifiScientificExporter.verifyExport(at: destination)
        }
    }
    do {
        try await task.value
        Issue.record("Cancelled verification succeeded")
    } catch is CancellationError {
        // Cancellation must cross the nested verification boundary unchanged.
    }
    #expect(try GlifiScientificExporter.verifyExport(at: destination) == original)
}

@Test("A simulated postcommit export failure preserves the verified destination and taxonomy")
func scientificExportPostcommitInterruptionRetainsDestination() async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(
        path: "Committed.glifiexport", directoryHint: .isDirectory)
    do {
        _ = try GlifiScientificExporter().export(
            snapshot: fixture.snapshot,
            investigation: fixture.investigation,
            interpretationRecord: fixture.interpretationRecord,
            interpretation: fixture.interpretation,
            request: GlifiScientificExportRequest(
                investigationHeadEventID: fixture.investigation.headEventID),
            to: destination,
            environment: deterministicEnvironment,
            interruption: .destinationCommitted)
        Issue.record("The existing simulated postcommit failure was ignored")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "export.simulated-interruption")
        #expect(failure.category == .transientIO)
        #expect(failure.retainedState == .lastCommittedGeneration)
    }
    _ = try GlifiScientificExporter.verifyExport(at: destination)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
    #expect(!leftovers.contains { $0.contains(".exporting-") })
}

@Test("La traslazione dell'xref sposta solo gli offset a valle e riallinea startxref")
func crossReferenceShiftsOnlyOffsetsAfterBoundary() throws {
    // Due oggetti; il secondo segue il punto in cui uno stream viene accorciato di un byte.
    let head = "%PDF-1.3\n1 0 obj\n<<>>\nendobj\n"
    let second = "2 0 obj\n<<>>\nendobj\n"
    let firstOffset = 9
    let secondOffset = head.utf8.count
    func field(_ value: Int) -> String { String(format: "%010d", value) }
    let table =
        "xref\n0 3\n0000000000 65535 f \n\(field(firstOffset)) 00000 n \n"
        + "\(field(secondOffset)) 00000 n \n"
    let text =
        head + second + table + "trailer\n<< /Size 3 >>\nstartxref\n0000000000\n%%EOF\n"
    var data = Data(text.utf8)

    try GlifiScientificExportRenderer.updateCrossReferenceTable(
        in: &data,
        shiftedAfter: secondOffset,
        by: -1
    )

    let result = String(decoding: data, as: UTF8.self)
    let xrefStart = (head + second).utf8.count
    #expect(result.contains("\(field(firstOffset)) 00000 n \n"))
    #expect(result.contains("\(field(secondOffset - 1)) 00000 n \n"))
    #expect(!result.contains("\(field(secondOffset)) 00000 n \n"))
    #expect(result.contains("startxref\n\(field(xrefStart))\n"))
}

@Test("Il PDF pagina un rapporto lungo senza perdere testo o struttura")
func scientificPDFPaginatesLongReport() async throws {
    let question = String(
        repeating:
            "Quali caratteristiche emergono dalla raccolta e quali limiti vanno conservati? ",
        count: 180
    )
    let fixture = try await exportFixture(question: question)
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(
        path: "Relazione-lunga.glifiexport",
        directoryHint: .isDirectory
    )

    let receipt = try GlifiScientificExporter().export(
        snapshot: fixture.snapshot,
        investigation: fixture.investigation,
        interpretationRecord: fixture.interpretationRecord,
        interpretation: fixture.interpretation,
        request: try GlifiScientificExportRequest(
            investigationHeadEventID: fixture.investigation.headEventID,
            formats: [.pdf]
        ),
        to: destination,
        environment: deterministicEnvironment,
        exportID: try #require(UUID(uuidString: "90000000-0000-0000-0000-000000000002")),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(receipt.fileCount == 1)
    let pdfData = try Data(contentsOf: destination.appending(path: "report.pdf"))
    // Aggancio per l'oracolo veraPDF (Scripts/check-oracles.py): copia il PDF esportato.
    if let directory = ProcessInfo.processInfo.environment["GLIFI_ORACLE_PDF_DIRECTORY"] {
        try pdfData.write(to: URL(fileURLWithPath: directory).appending(path: "report-long.pdf"))
    }
    let pdf = try #require(PDFDocument(data: pdfData))
    #expect(pdf.pageCount > 1)
    #expect(pdf.string?.contains("Quali caratteristiche emergono") == true)
    _ = try GlifiScientificExporter.verifyExport(at: destination)
}

private enum ExportFileDamage: CaseIterable, Sendable {
    case symbolicLink
    case hardLink
    case directory
    case fifo
    case oversized
    case truncated
}

@Test(
    "La verifica export rifiuta manifest e payload non sicuri e riprende dopo il ripristino",
    arguments: ["export-manifest.json", "report.json"], ExportFileDamage.allCases
)
private func scientificExportRejectsUnsafeFiles(
    fileName: String, damage: ExportFileDamage
) async throws {
    let fixture = try await exportFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let destination = fixture.root.appending(path: "Verified.glifiexport")
    _ = try GlifiScientificExporter().export(
        snapshot: fixture.snapshot,
        investigation: fixture.investigation,
        interpretationRecord: fixture.interpretationRecord,
        interpretation: fixture.interpretation,
        request: try GlifiScientificExportRequest(
            investigationHeadEventID: fixture.investigation.headEventID
        ),
        to: destination,
        environment: deterministicEnvironment
    )
    let manifest = try GlifiScientificExporter.verifyExport(at: destination)
    let fileURL = destination.appending(path: fileName)
    let originalData = try Data(contentsOf: fileURL)
    let externalURL = fixture.root.appending(path: "external.json")
    try originalData.write(to: externalURL)
    try FileManager.default.removeItem(at: fileURL)
    switch damage {
    case .symbolicLink:
        try FileManager.default.createSymbolicLink(at: fileURL, withDestinationURL: externalURL)
    case .hardLink:
        try FileManager.default.linkItem(at: externalURL, to: fileURL)
    case .directory:
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: false)
    case .fifo:
        try #require(mkfifo(fileURL.path, mode_t(0o600)) == 0)
    case .oversized:
        try Data().write(to: fileURL)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        let limit =
            fileName == "export-manifest.json"
            ? GlifiProjectPackage.maximumManifestByteCount
            : GlifiScientificExporter.maximumFileByteCount
        try handle.truncate(atOffset: UInt64(limit + 1))
    case .truncated:
        try originalData.prefix(originalData.count / 2).write(to: fileURL)
    }
    do {
        _ = try GlifiScientificExporter.verifyExport(at: destination)
        Issue.record("La verifica doveva rifiutare il file non valido")
    } catch let failure as GlifiFailure {
        #expect(
            failure.code
                == (fileName == "export-manifest.json"
                    ? "export.invalid-manifest" : "export.invalid-file"))
        #expect(failure.operation == .export)
        #expect(failure.retryDisposition == .never)
    }
    #expect(try Data(contentsOf: externalURL) == originalData)
    try FileManager.default.removeItem(at: fileURL)
    try originalData.write(to: fileURL)
    #expect(try GlifiScientificExporter.verifyExport(at: destination) == manifest)
    let project = try GlifiProjectPackage.open(at: fixture.root.appending(path: "Export.glifi"))
    #expect(await project.snapshot() == fixture.snapshot)
}

@Test(
    "La lettura export rispetta il budget a ogni confine di chunk",
    arguments: [0, 1, 65_535, 65_536, 65_537, 131_073]
)
func scientificExportReadsBoundedFiles(byteCount: Int) throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "ExportRead-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let data = Data(repeating: 65, count: byteCount)
    try data.write(to: root.appending(path: "payload"))
    let directory = try GlifiPackageDirectory(at: root)
    #expect(
        try GlifiScientificExporter.readFile(
            "payload", in: directory, maximumByteCount: byteCount,
            expectedByteCount: byteCount, failureCode: "export.invalid-file"
        ) == data)
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiScientificExporter.readFile(
            "payload", in: directory, maximumByteCount: byteCount - 1,
            failureCode: "export.invalid-file"
        )
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiScientificExporter.readFile(
            "payload", in: directory, maximumByteCount: byteCount + 1,
            expectedByteCount: byteCount + 1, failureCode: "export.invalid-file"
        )
    }
}

@Test("Le letture export restano ancorate alla radice aperta e rifiutano nuove radici simboliche")
func scientificExportPinsOpenedRoot() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: "ExportRoot-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appending(path: "original")
    let moved = root.appending(path: "moved")
    let external = root.appending(path: "external")
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
    try FileManager.default.createDirectory(at: external, withIntermediateDirectories: false)
    let originalData = Data("original".utf8)
    let externalData = Data("external".utf8)
    try originalData.write(to: original.appending(path: "payload"))
    try externalData.write(to: external.appending(path: "payload"))
    let directory = try GlifiPackageDirectory(at: original)
    try FileManager.default.moveItem(at: original, to: moved)
    try FileManager.default.createSymbolicLink(at: original, withDestinationURL: external)
    #expect(
        try GlifiScientificExporter.readFile(
            "payload", in: directory, maximumByteCount: originalData.count,
            failureCode: "export.invalid-file"
        ) == originalData)
    do {
        _ = try GlifiScientificExporter.verifyExport(at: original)
        Issue.record("La radice simbolica doveva essere rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "export.invalid-directory")
        #expect(failure.category == .invalidInput)
        #expect(failure.operation == .export)
    }
    #expect(try Data(contentsOf: external.appending(path: "payload")) == externalData)
}

private struct ExportFixture {
    let root: URL
    let snapshot: GlifiProjectSnapshot
    let investigation: GlifiInvestigation
    let interpretationRecord: GlifiProjectArtifactRecord
    let interpretation: GlifiAnalysisInterpretation
}

private func exportFixture(
    question: String = "# corpus: quali caratteristiche emergono?"
) async throws -> ExportFixture {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiExportTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    do {
        let projectURL = root.appending(path: "Export.glifi", directoryHint: .isDirectory)
        let project = try GlifiProjectPackage.create(at: projectURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("uno due due".utf8),
            format: .plainText
        )
        _ = try await project.importText(imported)
        let engine = GlifiEngine()
        let execution = try await engine.executeAnalysisPlan(
            in: project,
            request: GlifiAnalysisPlanRequest(intent: .understandCollection)
        )
        let created = try await engine.createInvestigation(
            in: project,
            request: try GlifiInvestigationCreationRequest(
                question: question,
                interpretationArtifactID: execution.interpretationArtifactID
            )
        )
        let snapshot = await project.snapshot()
        let record = try #require(
            snapshot.artifacts.first { $0.artifactID == execution.interpretationArtifactID }
        )
        let payload = try JSONDecoder().decode(
            GlifiAnalysisInterpretationArtifactPayload.self,
            from: await project.artifactData(for: record.artifactID)
        )
        return ExportFixture(
            root: root,
            snapshot: snapshot,
            investigation: created.investigation,
            interpretationRecord: record,
            interpretation: payload.interpretation
        )
    } catch {
        try? FileManager.default.removeItem(at: root)
        throw error
    }
}

private let deterministicEnvironment = GlifiExportEnvironment(
    software: .init(
        name: "Glifi Studio",
        version: "0.1.0",
        build: "1",
        sourceRevision: "test"
    ),
    platform: .init(
        system: "macOS",
        version: "27.0",
        architecture: "arm64",
        toolchain: "Apple Swift 6.4 / Xcode 27"
    )
)

private extension Data {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}
