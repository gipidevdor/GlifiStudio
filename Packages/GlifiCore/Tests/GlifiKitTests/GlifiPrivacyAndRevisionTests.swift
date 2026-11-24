// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

private let canary = "ZQXCANARY42"

/// Every field of a failure, arguments included, as one string.
private func rendered(_ failure: GlifiStudioFailure) -> String {
    String(describing: failure)
}

@Test("RQ-046: le failure non contengono contenuto, query, path o nomi file")
func failuresNeverCarryCorpusContentQueriesOrPaths() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "\(canary)-root-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let service = GlifiStudioService()
    let session = try await service.createProject(
        at: root.appending(path: "\(canary).glifi", directoryHint: .isDirectory))
    let valid = root.appending(path: "\(canary)-fonte.txt")
    try Data("Casa \(canary) mare.".utf8).write(to: valid)
    let imported = try await session.importText(at: valid, format: .plainText)
    let ids = imported.project.sources.map(\.sourceRevisionID)
    let invalid = root.appending(path: "\(canary)-rotto.txt")
    try Data([0x41, 0xC3, 0x28, 0x42]).write(to: invalid)

    var failures: [GlifiStudioFailure] = []
    func collect(_ body: () async throws -> Void) async {
        do {
            try await body()
            Issue.record("operazione attesa in errore riuscita")
        } catch let failure as GlifiStudioFailure {
            failures.append(failure)
        } catch {
            Issue.record("errore non tipizzato: \(type(of: error))")
        }
    }
    await collect { _ = try await session.query("\(canary):casa") }
    await collect { _ = try await session.query("form:/(\(canary)+)+/") }
    await collect { _ = try await session.query("\"\(canary)") }
    await collect {
        _ = try await session.importText(
            at: root.appending(path: "\(canary)-assente.txt"), format: .plainText)
    }
    await collect { _ = try await session.importText(at: invalid, format: .plainText) }
    await collect {
        _ = try await service.openProject(
            at: root.appending(path: "\(canary)-assente.glifi", directoryHint: .isDirectory))
    }
    await collect {
        _ = try await session.rankDocumentsBM25(
            sourceRevisionIDs: ids, query: String(repeating: "\(canary) ", count: 600))
    }
    await collect {
        _ = try await session.analyzeNGramFrequencies(
            sourceRevisionIDs: ids, unit: GlifiStudioNGramUnit(kind: canary, n: 1))
    }
    #expect(failures.count == 8)
    for failure in failures {
        #expect(!rendered(failure).contains(canary), "\(failure.code)")
        #expect(!rendered(failure).contains(root.path), "\(failure.code)")
        #expect(failure.messageKey.hasPrefix("failure."))
    }
    await session.close()
}

@Test("RF-077: ogni aggiornamento è una SourceRevision distinta e le fonti sono incorporate")
func sourceUpdatesBecomeDistinctEmbeddedRevisions() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiRevisions-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "R.glifi", directoryHint: .isDirectory)
    let session = try await GlifiStudioService().createProject(at: projectURL)
    let external = root.appending(path: "fonte.txt")
    let original = "Prima versione della fonte."
    try Data(original.utf8).write(to: external)
    let first = try await session.importText(at: external, format: .plainText)
    let firstRevision = try #require(first.project.sources.last?.sourceRevisionID)

    try Data("Seconda versione, modificata.".utf8).write(to: external)
    let second = try await session.importText(at: external, format: .plainText)
    // Le fonti sono in ordine canonico di identità, non di importazione.
    let secondRevision = try #require(
        second.project.sources.map(\.sourceRevisionID).first { $0 != firstRevision })
    #expect(second.project.sourceCount == 2)
    #expect(second.project.generation > first.project.generation)

    // Incorporazione: le revisioni restano leggibili senza il file esterno e senza il suo path.
    try FileManager.default.removeItem(at: external)
    await session.close()
    let reopened = try await GlifiStudioService().openProject(at: projectURL)
    #expect(try await reopened.sourceText(sourceRevisionID: firstRevision).text == original)
    #expect(
        try await reopened.sourceText(sourceRevisionID: secondRevision).text
            == "Seconda versione, modificata.")
    let sources = try await reopened.snapshot().sources
    #expect(Set(sources.map(\.sourceRevisionID)) == [firstRevision, secondRevision])
    #expect(Set(sources.map(\.contentDigest)).count == 2)
    #expect(sources.allSatisfy { !String(describing: $0).contains(root.path) })
    await reopened.close()
}
