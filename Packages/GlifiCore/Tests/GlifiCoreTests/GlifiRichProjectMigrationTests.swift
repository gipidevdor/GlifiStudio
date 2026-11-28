// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import SQLite3
import Testing

@testable import GlifiCore

@Test("Opening TXT projects preserves schema 4 and the exact manifest and database bytes")
func documentExtractionPersistenceLegacyOpenDoesNotMigrate() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let text = try GlifiTextImporter().importText(
            from: Data("Legacy text".utf8), format: .plainText)
        let snapshot = try await project.importText(text)
        let database = url.appending(path: "store/project.sqlite")
        let databaseBytes = try Data(contentsOf: database)
        let manifestBytes = try Data(contentsOf: url.appending(path: "manifest.json"))
        #expect(
            try documentMigrationRows(database, "SELECT schema_version FROM project_metadata") == [
                ["4"]
            ])
        let reopened = try GlifiProjectPackage.open(at: url)
        #expect(await reopened.snapshot() == snapshot)
        #expect(try Data(contentsOf: database) == databaseBytes)
        #expect(try Data(contentsOf: url.appending(path: "manifest.json")) == manifestBytes)
    }
}

@Test(
    "The first rich import migrates all historical rows and preserves artifacts and both histories")
func documentExtractionPersistenceMigrationPreservesHistory() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let old = try GlifiTextImporter().importText(
            from: Data("Legacy source".utf8), format: .markdown)
        var snapshot = try await project.importText(old)
        let descriptor = try documentMigrationDescriptor(snapshot, name: "before")
        snapshot = try await project.storeArtifact(
            DocumentMigrationPayload(value: "old canary"), descriptor: descriptor)
        let oldArtifact = try #require(snapshot.artifacts.first)
        let oldPayload = try await project.artifactData(for: oldArtifact.artifactID)
        let event = try documentMigrationInvestigation(artifact: oldArtifact.artifactID)
        _ = try await project.appendInvestigationEvent(event)
        let qualitative = try GlifiQualitativeEvent(
            predecessorEventID: nil, recordedAtUnixMilliseconds: 1,
            payload: .codebookRevised(
                codebookID: "migration", revision: 1,
                categories: [
                    .init(categoryID: "theme", label: "Theme", definition: "Synthetic theme")
                ]))
        let baseline = try await project.appendQualitativeEvent(qualitative)
        let database = url.appending(path: "store/project.sqlite")
        let tables = [
            "generations", "source_entries", "artifact_entries", "investigation_event_entries",
        ]
        var rows: [String: [[String?]]] = [:]
        for table in tables {
            rows[table] = try documentMigrationRows(
                database, "SELECT * FROM \(table) ORDER BY 1, 2")
        }
        let qualitativeRows = try documentMigrationRows(
            database, "SELECT * FROM qualitative_event_entries ORDER BY sequence")
        let imported = try documentPersistenceCapturedDocument(format: .pdf)
        let committed = try await project.importText(imported)
        #expect(
            try documentMigrationRows(database, "SELECT schema_version FROM project_metadata") == [
                ["5"]
            ])
        for table in tables {
            #expect(
                try documentMigrationRows(
                    database,
                    "SELECT * FROM \(table) WHERE generation <= \(baseline.generation) ORDER BY 1, 2"
                ) == rows[table])
        }
        #expect(
            try documentMigrationRows(
                database, "SELECT * FROM qualitative_event_entries ORDER BY sequence")
                == qualitativeRows)
        #expect(committed.investigationRootDigest == baseline.investigationRootDigest)
        #expect(committed.qualitativeRootDigest == baseline.qualitativeRootDigest)
        #expect(committed.artifacts.contains(oldArtifact))
        #expect(try await project.artifactData(for: oldArtifact.artifactID) == oldPayload)
        #expect(try await project.sourceData(for: old.sourceRevisionID) == old.bytes)
        #expect(try await project.investigationEvent(for: event.eventID()) == event)
        #expect(try await project.qualitativeEvents() == [qualitative])
        #expect(try documentMigrationManifest(url).minimumReaderVersion == 2)

        let nextDescriptor = try documentMigrationDescriptor(committed, name: "after")
        let withArtifact = try await project.storeArtifact(
            DocumentMigrationPayload(value: "new canary"), descriptor: nextDescriptor)
        #expect(try documentMigrationManifest(url).minimumReaderVersion == 2)
        let nextNode = try nextDescriptor.nodeID()
        let nextArtifact = try #require(withArtifact.artifacts.first { $0.node.id == nextNode })
        _ = try await project.appendInvestigationEvent(
            documentMigrationInvestigation(artifact: nextArtifact.artifactID))
        #expect(try documentMigrationManifest(url).minimumReaderVersion == 2)
        let nextQualitative = try GlifiQualitativeEvent(
            predecessorEventID: qualitative.eventID(), recordedAtUnixMilliseconds: 2,
            payload: .codebookRevised(
                codebookID: "migration", revision: 2,
                categories: [
                    .init(
                        categoryID: "theme", label: "Theme", definition: "Revised synthetic theme")
                ]))
        _ = try await project.appendQualitativeEvent(nextQualitative)
        #expect(try documentMigrationManifest(url).minimumReaderVersion == 2)
        #expect(try documentMigrationManifest(url).formatVersion == 1)
        #expect(try documentMigrationManifest(url).schemaVersion == 4)
        let reopened = try GlifiProjectPackage.open(at: url)
        #expect(try await reopened.importedText(for: imported.sourceRevisionID) == imported)
    }
}

@Test("A failed prepared generation rolls back the rich-format DDL and metadata together")
func documentExtractionPersistenceMigrationRollback() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let plain = try GlifiTextImporter().importText(
            from: Data("Old text".utf8), format: .plainText)
        let baseline = try await project.importText(plain)
        let database = url.appending(path: "store/project.sqlite")
        try documentMigrationExecute(
            database,
            "CREATE TRIGGER reject_fixture_generation BEFORE INSERT ON generations WHEN NEW.generation = 2 BEGIN SELECT RAISE(ABORT, 'synthetic rollback'); END"
        )
        let imported = try documentPersistenceCapturedDocument(format: .epub)
        do {
            _ = try await project.importText(imported)
            Issue.record("The synthetic generation failure did not fire")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.store-statement-failed")
        }
        #expect(await project.snapshot() == baseline)
        #expect(
            try documentMigrationRows(database, "SELECT schema_version FROM project_metadata") == [
                ["4"]
            ])
        #expect(
            try documentMigrationRows(
                database,
                "SELECT name FROM sqlite_master WHERE name IN ('source_entries_v5', 'project_metadata_v5')"
            ).isEmpty)
        #expect(try await GlifiProjectPackage.open(at: url).snapshot() == baseline)
        try documentMigrationExecute(database, "DROP TRIGGER reject_fixture_generation")
        _ = try await project.importText(imported)
        #expect(
            try documentMigrationRows(database, "SELECT schema_version FROM project_metadata") == [
                ["5"]
            ])
        #expect(try await project.importedText(for: imported.sourceRevisionID) == imported)
    }
}

@Test("Cancellation immediately before migration leaves schema four and the last generation intact")
func documentExtractionPersistenceMigrationCancellation() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        let plain = try GlifiTextImporter().importText(
            from: Data("Old text".utf8), format: .plainText)
        let baseline = try await project.importText(plain)
        let imported = try documentPersistenceCapturedDocument(format: .pdf)
        let task = Task {
            try await project.importText(
                imported, sourceID: SourceID(), interruption: .objectPromoted,
                interruptionBehavior: .observe {
                    withUnsafeCurrentTask { $0?.cancel() }
                })
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled migration succeeded")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .cancelled)
            #expect(failure.retryDisposition == .newRequest)
            #expect(failure.retainedState == .lastCommittedGeneration)
            #expect(failure.arguments.isEmpty)
        }
        #expect(await project.snapshot() == baseline)
        #expect(
            try documentMigrationRows(
                url.appending(path: "store/project.sqlite"),
                "SELECT schema_version FROM project_metadata") == [["4"]])
        #expect(try await GlifiProjectPackage.open(at: url).snapshot() == baseline)
    }
}

@Test("Rich manifests require reader two and reject unsupported or falsely lowered reader fences")
func documentExtractionPersistenceReaderFence() async throws {
    try await withDocumentPersistenceProject { url in
        let project = try GlifiProjectPackage.create(at: url)
        _ = try await project.importText(documentPersistenceCapturedDocument(format: .pdf))
        let manifestURL = url.appending(path: "manifest.json")
        let bytes = try Data(contentsOf: manifestURL)
        #expect(try documentMigrationManifest(url).minimumReaderVersion == 2)
        for minimum in [0, 1, GlifiProjectManifest.readerVersion + 1] {
            var value = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            value["minimumReaderVersion"] = minimum
            try JSONSerialization.data(
                withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes]
            ).write(to: manifestURL)
            do {
                _ = try GlifiProjectPackage.open(at: url)
                Issue.record("An invalid reader fence was accepted")
            } catch let failure as GlifiFailure {
                #expect(failure.category == (minimum == 1 ? .corruption : .incompatibleVersion))
            }
        }
        try bytes.write(to: manifestURL)
        _ = try GlifiProjectPackage.open(at: url)
    }
}

private struct DocumentMigrationPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.test.document-migration.v1"
    let value: String
}

private func documentMigrationDescriptor(_ snapshot: GlifiProjectSnapshot, name: String) throws
    -> GlifiAnalysisDescriptor
{
    try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "test.migration", algorithmIdentifier: "test.migration.\(name)",
        algorithmVersion: "1", corpusIdentifier: snapshot.projectID.canonicalValue,
        corpusVersionDigest: snapshot.sourceRootDigest, selectionIdentifier: "all-v1",
        analyticalUnitIdentifier: "source-v1", preprocessingIdentifiers: [],
        linguisticProfileIdentifiers: [],
        representationIdentifier: "test-v1", resolvedParameters: [:],
        seedPolicyIdentifier: "none-v1",
        backendIdentifier: "swift-v1", numericPolicyIdentifier: "exact-v1", determinismClass: .d0,
        outputSchemaIdentifier: DocumentMigrationPayload.outputSchemaIdentifier,
        softwareIdentifier: "test-v1", dependencies: [],
        sourceRevisionIDs: snapshot.sources.map(\.sourceRevisionID))
}

private func documentMigrationInvestigation(artifact: ArtifactID) throws -> GlifiInvestigationEvent
{
    try GlifiInvestigationEvent(
        investigationID: InvestigationID(), predecessorEventID: nil, recordedAtUnixMilliseconds: 1,
        actor: .localPerson,
        payload: .created(
            question: "Synthetic migration", languageCode: "it", intent: .understandCollection,
            planArtifactID: artifact, interpretationArtifactID: artifact,
            availableFindingIDs: [], selectedFindingIDs: []))
}

private func documentMigrationManifest(_ url: URL) throws -> GlifiProjectManifest {
    try JSONDecoder().decode(
        GlifiProjectManifest.self, from: Data(contentsOf: url.appending(path: "manifest.json")))
}

private func documentMigrationRows(_ url: URL, _ sql: String) throws -> [[String?]] {
    var database: OpaquePointer?
    let opened = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil)
    defer { sqlite3_close(database) }
    try #require(opened == SQLITE_OK)
    var statement: OpaquePointer?
    try #require(sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK)
    defer { sqlite3_finalize(statement) }
    var rows: [[String?]] = []
    while true {
        let step = sqlite3_step(statement)
        if step == SQLITE_DONE { return rows }
        try #require(step == SQLITE_ROW)
        rows.append(
            (0..<sqlite3_column_count(statement)).map { column in
                sqlite3_column_text(statement, column).map { String(cString: $0) }
            })
    }
}

private func documentMigrationExecute(_ url: URL, _ sql: String) throws {
    var database: OpaquePointer?
    let opened = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil)
    defer { sqlite3_close(database) }
    try #require(opened == SQLITE_OK)
    try #require(sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK)
}
