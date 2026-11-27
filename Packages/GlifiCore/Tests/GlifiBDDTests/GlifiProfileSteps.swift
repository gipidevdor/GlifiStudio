// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDProfileWorld {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiBDDProfiles-\(UUID().uuidString)", directoryHint: .isDirectory)
    var format: GlifiStudioTextFormat = .plainText
    var source: URL?
    var bytes = Data()
    var result: GlifiStudioTextProfile?
    var cliProfile: [String: Any]?
    var failure: GlifiStudioFailure?
    var session: GlifiStudioProjectSession?
    var originalQuery: GlifiStudioProjectQueryResult?
    var reopenedQuery: GlifiStudioProjectQueryResult?
    var captured: GlifiStudioSourceText?
    var originalSnapshot: GlifiStudioProjectSnapshot?

    var project: URL { root.appending(path: "Profile.glifi", directoryHint: .isDirectory) }
    var digest: String {
        "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    func prepare(_ format: GlifiStudioTextFormat) throws {
        self.format = format
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let suffix: String
        switch format {
        case .plainText: suffix = "txt"
        case .markdown: suffix = "md"
        case .pdf: suffix = "pdf"
        case .epub: suffix = "epub"
        }
        let url = root.appending(path: "source.\(suffix)")
        switch format {
        case .plainText, .markdown:
            bytes = Data("Alfa beta beta.".utf8)
        case .pdf, .epub:
            let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appending(path: "../../../../Fixtures/DocumentImport/v1").standardizedFileURL
            bytes = try Data(
                contentsOf: fixtures.appending(path: format == .pdf ? "digital.pdf" : "book.epub"))
        }
        try bytes.write(to: url)
        source = url
    }

    func profile(_ phase: String) async throws {
        result = nil
        failure = nil
        let request = GlifiStudioProfileRequest(
            sourcePath: try #require(source).path, format: format)
        var data = try JSONEncoder().encode(request)
        if phase == "invalid-input" {
            var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object["bddUnexpectedField"] = true
            data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }
        let service = GlifiStudioService()
        do {
            if phase == "pre-cancelled" {
                let input = data
                let task = Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await service.profileText(json: input)
                }
                result = try await task.value
            } else {
                try #require(phase == "nominal" || phase == "invalid-input")
                result = try await service.profileText(json: data)
            }
        } catch let error as GlifiStudioFailure {
            failure = error
        }
    }

    func automaticImport() async throws {
        let executable = try locateBDDCLI()
        let created = try await BDDSubprocess.run(
            executable: executable,
            arguments: ["--format", "json", "project", "create", project.path], directory: root)
        try #require(created.status == 0)
        try #require(created.stderr.isEmpty)
        let imported = try await BDDSubprocess.run(
            executable: executable,
            arguments: ["--format", "json", "import", project.path, try #require(source).path],
            directory: root)
        try #require(imported.status == 0)
        try #require(imported.stderr.isEmpty)
        let envelope = try #require(
            JSONSerialization.jsonObject(with: imported.stdout) as? [String: Any])
        #expect(envelope["command"] as? String == "import")
        #expect(envelope["outcome"] as? String == "succeeded")
        let payload = try #require(envelope["result"] as? [String: Any])
        #expect(payload["importedSourceCount"] as? Int == 1)
        cliProfile = try #require(payload["lastProfile"] as? [String: Any])
        session = try await GlifiStudioService().openProject(at: project)
        originalSnapshot = try await session?.snapshot()
    }

    func importAndReopen() async throws {
        let current = try await GlifiStudioService().createProject(at: project)
        session = current
        let imported = try await current.importText(at: #require(source), format: format)
        result = imported.profile
        originalSnapshot = imported.project
        let revision = try #require(imported.project.sources.first?.sourceRevisionID)
        captured = try await current.sourceText(sourceRevisionID: revision)
        let term = format == .plainText || format == .markdown ? "alfa" : "casa"
        originalQuery = try await current.query("normalized:\(term)")
        await current.close()
        try FileManager.default.removeItem(at: #require(source))
        let reopened = try await GlifiStudioService().openProject(at: project)
        session = reopened
        #expect(try await reopened.snapshot() == originalSnapshot)
        #expect(try await reopened.sourceText(sourceRevisionID: revision) == captured)
        reopenedQuery = try await reopened.query("normalized:\(term)")
    }

    func checkProfile(tokens: Int, types: Int) throws {
        #expect(failure == nil)
        if let result {
            #expect(result.lexicalTokenCount == tokens)
            #expect(result.typeCount == types)
            #expect(result.contentDigest == digest)
            #expect(result.topTerms.reduce(0) { $0 + $1.count } == tokens)
            if let captured {
                #expect(result.utf8ByteCount == captured.text.utf8.count)
                #expect(result.characterCount == captured.text.count)
            }
        } else {
            let object = try #require(cliProfile)
            #expect(object["lexicalTokenCount"] as? Int == tokens)
            #expect(object["typeCount"] as? Int == types)
            #expect(object["contentDigest"] as? String == digest)
        }
    }

    func cleanup() async throws {
        await session?.close()
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }
}

@MainActor
private var profileWorld: BDDProfileWorld { Scenario.state(BDDProfileWorld.init) }

@MainActor
func registerProfileSteps() {
    AfterScenario { _ in try await profileWorld.cleanup() }
    Given("la fonte originale di profilo nel formato {word}") { match, _ in
        try profileWorld.prepare(#require(GlifiStudioTextFormat(rawValue: match.first(\.word))))
    }
    When("eseguo il profilo pubblico nella fase {word}") { match, _ in
        try await profileWorld.profile(match.first(\.word))
    }
    Then("il profilo originale contiene {int} token e {int} tipi") { match, _ in
        try profileWorld.checkProfile(tokens: match[\.int, index: 0], types: match[\.int, index: 1])
    }
    Then("la fonte del profilo conserva esattamente i byte originali") { _, _ in
        let source = try #require(profileWorld.source)
        let actual = try Data(contentsOf: source)
        #expect(actual == profileWorld.bytes)
    }
    Then("il profilo fallisce con codice {string} e categoria {word}") { match, _ in
        let failure = try #require(profileWorld.failure)
        #expect(failure.code == (try match.first(\.string)))
        #expect(failure.category == (try match.first(\.word)))
        #expect(failure.operation == "analyze")
        #expect(failure.retainedState == "unchanged")
        #expect(failure.arguments.isEmpty)
        #expect(profileWorld.result == nil)
    }
    When("importo con la CLI rilevando il formato dalla fonte") { _, _ in
        try await profileWorld.automaticImport()
    }
    Then("la fonte importata conserva formato, digest e generazione") { _, _ in
        let world = profileWorld
        let snapshot = try #require(world.originalSnapshot)
        #expect(snapshot.generation == 1)
        #expect(snapshot.sourceCount == 1)
        #expect(snapshot.artifactCount == (world.format == .pdf || world.format == .epub ? 1 : 0))
        let source = try #require(snapshot.sources.first)
        #expect(source.format == world.format)
        #expect(source.contentDigest == world.digest)
        #expect(source.byteCount == world.bytes.count)
    }
    When("importo la fonte e riapro senza il file originale") { _, _ in
        try await profileWorld.importAndReopen()
    }
    Then("la fonte incorporata conserva {int} riscontri identici") { match, _ in
        let original = try #require(profileWorld.originalQuery)
        let reopened = try #require(profileWorld.reopenedQuery)
        let count = try match.first(\.int)
        #expect(original.matches.count == count)
        #expect(reopened.matches == original.matches)
        #expect(reopened.matchedSourceCount == 1)
        #expect(try await profileWorld.session?.snapshot() == profileWorld.originalSnapshot)
        let source = try #require(profileWorld.source)
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }
}
