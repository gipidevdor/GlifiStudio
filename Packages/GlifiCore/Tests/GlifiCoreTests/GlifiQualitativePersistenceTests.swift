// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import SQLite3
import Testing

@testable import GlifiCore

private let categories = [
    GlifiCodebookCategory(categoryID: "mare", label: "Mare", definition: "Riferimenti al mare."),
    GlifiCodebookCategory(categoryID: "monti", label: "Monti", definition: "Montagna e valli."),
]

@Test("La storia qualitativa non segue directory simboliche", arguments: [0, 1, 2, 3])
func qualitativeHistoryRejectsLinkedDirectories(depth: Int) async throws {
    let (root, url) = try temporaryProject("GlifiQualitativeDirectory")
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(at: url)
    let snapshot = try await project.appendQualitativeEvent(
        try await event(
            after: project,
            .codebookRevised(codebookID: "temi", revision: 1, categories: categories)))
    let record = try #require(snapshot.qualitativeEvents.first)
    let components = record.objectPath.split(separator: "/")
    let directoryURL = url.appending(path: components.prefix(depth + 1).joined(separator: "/"))
    let externalURL = root.appending(path: "external")
    let original = try Data(contentsOf: url.appending(path: record.objectPath))
    try FileManager.default.moveItem(at: directoryURL, to: externalURL)
    try FileManager.default.createSymbolicLink(at: directoryURL, withDestinationURL: externalURL)

    #expect(throws: GlifiFailure.self) { _ = try GlifiProjectPackage.open(at: url) }
    await #expect(throws: GlifiFailure.self) { _ = try await project.qualitativeEvents() }
    #expect(await project.snapshot() == snapshot)
    let externalObject = externalURL.appending(
        path: components.dropFirst(depth + 1).joined(separator: "/"))
    #expect(try Data(contentsOf: externalObject) == original)

    try FileManager.default.removeItem(at: directoryURL)
    try FileManager.default.moveItem(at: externalURL, to: directoryURL)
    #expect(try await GlifiProjectPackage.open(at: url).snapshot() == snapshot)
    #expect(try await project.qualitativeEvents().count == 1)
}

private func temporaryProject(_ name: String) throws -> (URL, URL) {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return (root, root.appending(path: "Q.glifi", directoryHint: .isDirectory))
}

private func event(
    after project: GlifiProjectPackage, _ payload: GlifiQualitativeEventPayload
) async throws -> GlifiQualitativeEvent {
    try GlifiQualitativeEvent(
        predecessorEventID: await project.snapshot().qualitativeEvents.last?.eventID,
        recordedAtUnixMilliseconds: 1_000, payload: payload)
}

@Test("La storia qualitativa si persiste, sopravvive a importazioni e riapertura")
func qualitativeHistoryIsPersistedAcrossGenerations() async throws {
    let (root, url) = try temporaryProject("GlifiQualitative")
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(at: url)
    // Senza eventi il manifest resta allo schema 3, identico ai package precedenti.
    let emptyManifest = try JSONDecoder().decode(
        GlifiProjectManifest.self, from: Data(contentsOf: url.appending(path: "manifest.json")))
    #expect(emptyManifest.schemaVersion == 3)
    #expect(emptyManifest.qualitativeEventCount == nil)

    let imported = try GlifiTextImporter().importText(
        from: Data("Il mare e i monti.".utf8), format: .plainText)
    _ = try await project.importText(imported)
    _ = try await project.appendQualitativeEvent(
        try await event(
            after: project,
            .codebookRevised(codebookID: "temi", revision: 1, categories: categories)))
    let coded = try await project.appendQualitativeEvent(
        try await event(
            after: project,
            .segmentCoded(
                sourceRevisionID: imported.sourceRevisionID,
                range: try GlifiUTF8Range(start: 3, end: 7), codebookID: "temi",
                codebookRevision: 1, categoryID: "mare", coderID: "c1", origin: .manual)))
    #expect(coded.qualitativeEvents.count == 2)
    let manifest = try JSONDecoder().decode(
        GlifiProjectManifest.self, from: Data(contentsOf: url.appending(path: "manifest.json")))
    #expect(manifest.schemaVersion == 4)
    #expect(manifest.qualitativeEventCount == 2)

    // Una nuova importazione conserva la storia qualitativa.
    let second = try GlifiTextImporter().importText(
        from: Data("Un'altra fonte.".utf8), format: .plainText)
    let afterImport = try await project.importText(second)
    #expect(afterImport.qualitativeRootDigest == coded.qualitativeRootDigest)
    #expect(afterImport.qualitativeEvents == coded.qualitativeEvents)

    let reopened = try GlifiProjectPackage.open(at: url)
    let state = try GlifiQualitativeState(events: try await reopened.qualitativeEvents())
    #expect(state.activeCodings.count == 1)
    #expect(state.codebooks["temi"]?.count == 1)

    // Predecessore non corrente e categoria assente sono rifiutati senza cambiare la generazione.
    let generation = await reopened.snapshot().generation
    let stale = try GlifiQualitativeEvent(
        predecessorEventID: nil, recordedAtUnixMilliseconds: 2,
        payload: .codebookRevised(codebookID: "altro", revision: 1, categories: categories))
    await #expect(throws: GlifiFailure.self) {
        _ = try await reopened.appendQualitativeEvent(stale)
    }
    let unknown = try await event(
        after: reopened,
        .segmentCoded(
            sourceRevisionID: imported.sourceRevisionID,
            range: try GlifiUTF8Range(start: 0, end: 2),
            codebookID: "temi", codebookRevision: 1, categoryID: "assente", coderID: "c1",
            origin: .manual))
    await #expect(throws: GlifiFailure.self) {
        _ = try await reopened.appendQualitativeEvent(unknown)
    }
    #expect(await reopened.snapshot().generation == generation)
}

@Test("Un evento qualitativo manomesso rende il package non apribile")
func tamperedQualitativeEventIsDetected() async throws {
    let (root, url) = try temporaryProject("GlifiQualitativeTamper")
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(at: url)
    let snapshot = try await project.appendQualitativeEvent(
        try await event(
            after: project,
            .codebookRevised(codebookID: "temi", revision: 1, categories: categories)))
    let objectURL = url.appending(path: try #require(snapshot.qualitativeEvents.first).objectPath)
    var bytes = try Data(contentsOf: objectURL)
    bytes[bytes.count / 2] ^= 0x01
    try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: objectURL.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: objectURL.path)
    try bytes.write(to: objectURL)
    #expect(throws: GlifiFailure.self) { _ = try GlifiProjectPackage.open(at: url) }
}

@Test("Uno store di schema 3 migra in modo additivo allo schema 4")
func schemaThreeStoreMigratesToQualitativeHistory() async throws {
    let (root, url) = try temporaryProject("GlifiQualitativeMigration")
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try GlifiProjectPackage.create(at: url)
    // Riporta lo store alla forma dei package esistenti (schema 3, nessuna radice qualitativa).
    var database: OpaquePointer?
    let path = url.appending(path: "store/project.sqlite").path
    #expect(sqlite3_open(path, &database) == SQLITE_OK)
    for statement in [
        "ALTER TABLE generations DROP COLUMN qualitative_root_digest",
        "ALTER TABLE generations DROP COLUMN qualitative_event_count",
        "DROP TABLE qualitative_event_entries",
        "CREATE TABLE project_metadata_v3 (singleton INTEGER PRIMARY KEY CHECK (singleton = 1), project_id TEXT NOT NULL, schema_version INTEGER NOT NULL CHECK (schema_version = 3)) STRICT",
        "INSERT INTO project_metadata_v3 SELECT singleton, project_id, 3 FROM project_metadata",
        "DROP TABLE project_metadata",
        "ALTER TABLE project_metadata_v3 RENAME TO project_metadata",
    ] {
        #expect(sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK, "\(statement)")
    }
    sqlite3_close(database)

    let migrated = try GlifiProjectPackage.open(at: url)
    #expect(await migrated.snapshot().qualitativeEvents.isEmpty)
    _ = try await migrated.appendQualitativeEvent(
        try await event(
            after: migrated,
            .codebookRevised(codebookID: "temi", revision: 1, categories: categories)))
    let reopened = try GlifiProjectPackage.open(at: url)
    #expect(try await reopened.qualitativeEvents().count == 1)
}

@Test(
    "Gli oggetti qualitativi non accettano link, file speciali o dimensioni incoerenti",
    arguments: ["symbolicLink", "hardLink", "fifo", "directory", "oversized", "truncated"]
)
func qualitativeHistoryRejectsUnsafeObjectFiles(kind: String) async throws {
    let (root, url) = try temporaryProject("GlifiQualitativeUnsafeFile")
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(at: url)
    let snapshot = try await project.appendQualitativeEvent(
        try await event(
            after: project,
            .codebookRevised(codebookID: "temi", revision: 1, categories: categories)))
    let record = try #require(snapshot.qualitativeEvents.first)
    let objectURL = url.appending(path: record.objectPath)
    let original = try Data(contentsOf: objectURL)
    let externalURL = root.appending(path: "external.json")
    try original.write(to: externalURL)
    try FileManager.default.removeItem(at: objectURL)

    switch kind {
    case "symbolicLink":
        try FileManager.default.createSymbolicLink(at: objectURL, withDestinationURL: externalURL)
    case "hardLink":
        try FileManager.default.linkItem(at: externalURL, to: objectURL)
    case "fifo":
        try #require(mkfifo(objectURL.path, 0o600) == 0)
    case "directory":
        try FileManager.default.createDirectory(at: objectURL, withIntermediateDirectories: false)
    case "oversized":
        try (original + Data([0])).write(to: objectURL)
    case "truncated":
        try Data(original.dropLast()).write(to: objectURL)
    default:
        Issue.record("Caso di test sconosciuto")
    }

    do {
        _ = try GlifiProjectPackage.open(at: url)
        Issue.record("Era atteso il rifiuto dell'oggetto qualitativo non sicuro")
    } catch let failure as GlifiFailure {
        #expect(failure.category == .corruption)
    }
    await #expect(throws: GlifiFailure.self) {
        _ = try await project.qualitativeEvents()
    }
    #expect(await project.snapshot() == snapshot)
    #expect(try Data(contentsOf: externalURL) == original)

    try FileManager.default.removeItem(at: objectURL)
    try original.write(to: objectURL)
    let reopened = try GlifiProjectPackage.open(at: url)
    #expect(await reopened.snapshot() == snapshot)
    #expect(try await reopened.qualitativeEvents().count == 1)
}
