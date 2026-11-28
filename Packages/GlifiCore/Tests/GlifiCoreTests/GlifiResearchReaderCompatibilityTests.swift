// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiResearchReaderCompatibilityTests {
    @Test(
        "Il lettore tre è richiesto soltanto dal primo stato di ricerca e resta nei commit successivi"
    )
    func researchReaderRequirementIsLazyAndDurable() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        #expect(try requirement(url) == 1)
        _ = try await project.importText(
            GlifiTextImporter().importText(
                from: Data("Primo testo italiano.".utf8), format: .plainText))
        let engine = GlifiEngine()
        _ = try await engine.analyzeCorpus(in: project)
        #expect(try requirement(url) == 1)
        let before = try Data(contentsOf: url.appending(path: "manifest.json"))
        let databaseBefore = try Data(contentsOf: url.appending(path: "store/project.sqlite"))
        _ = try GlifiProjectPackage.open(at: url)
        #expect(try Data(contentsOf: url.appending(path: "manifest.json")) == before)
        #expect(try Data(contentsOf: url.appending(path: "store/project.sqlite")) == databaseBefore)
        let state = try await project.saveResearchState(.init(), expectedRevision: 0)
        #expect(try requirement(url) == 3)
        _ = try await project.importText(
            GlifiTextImporter().importText(
                from: Data("Secondo testo italiano.".utf8), format: .markdown))
        #expect(try requirement(url) == 3)
        _ = try await engine.analyzeCorpus(in: project)
        #expect(try requirement(url) == 3)
        let reopened = try GlifiProjectPackage.open(at: url)
        #expect(try await reopened.researchState() == state)
    }

    @Test("Anche l'archivio tabellare senza stato richiede il lettore tre")
    func standaloneArchiveRequiresResearchReader() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        let data = Data("id,testo\na,Un testo originale\n".utf8)
        let table = try GlifiTabularImporter.preview(data: data, options: .init())
        let dataset = try GlifiTabularImporter.map(
            table: table, mapping: .init(textColumns: [2], identifierColumn: 1))
        _ = try await researchArchiveFixture(project, data: data, dataset: dataset, commit: true)
        #expect(try requirement(url) == 3)
        _ = try GlifiProjectPackage.open(at: url)
    }

    @Test("Requisiti futuri o artificiosamente abbassati falliscono prima dell'apertura")
    func futureAndDowngradedRequirementsFailClosed() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        _ = try await project.saveResearchState(.init(), expectedRevision: 0)
        let manifest = url.appending(path: "manifest.json")
        let bytes = try Data(contentsOf: manifest)
        for minimum in [1, 2, 4] {
            var value = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            value["minimumReaderVersion"] = minimum
            try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(
                to: manifest)
            do {
                _ = try GlifiProjectPackage.open(at: url)
                Issue.record("An incompatible research reader requirement was accepted")
            } catch let failure as GlifiFailure {
                #expect(failure.category == (minimum == 4 ? .incompatibleVersion : .corruption))
            }
        }
        try bytes.write(to: manifest)
        _ = try GlifiProjectPackage.open(at: url)
    }

    private func requirement(_ projectURL: URL) throws -> Int {
        try JSONDecoder().decode(
            GlifiProjectManifest.self,
            from: Data(contentsOf: projectURL.appending(path: "manifest.json"))
        ).minimumReaderVersion
    }
}
