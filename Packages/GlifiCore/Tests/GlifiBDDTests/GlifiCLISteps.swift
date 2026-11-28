// SPDX-License-Identifier: BSD-3-Clause

import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDCLIWorld {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiBDDCLI-\(UUID().uuidString)", directoryHint: .isDirectory)
    var output: BDDSubprocessOutput?
    var baseline: GlifiStudioProjectSnapshot?
    var query: String?
    var sourceFormat: GlifiStudioTextFormat = .plainText
    var request = Data()

    var project: URL { root.appending(path: "Studio.glifi", directoryHint: .isDirectory) }
    var source: URL { root.appending(path: "fonte.txt") }
    var requestURL: URL { root.appending(path: "richiesta.json") }

    func prepare() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }

    func cleanup() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func run(_ arguments: [String]) async throws {
        output = nil
        output = try await BDDSubprocess.run(
            executable: locateBDDCLI(), arguments: arguments, directory: root)
    }

    func json(fromError: Bool = false) throws -> [String: Any] {
        let captured = try #require(output)
        return try #require(
            JSONSerialization.jsonObject(with: fromError ? captured.stderr : captured.stdout)
                as? [String: Any])
    }

    func snapshot() async throws -> GlifiStudioProjectSnapshot {
        let session = try await GlifiStudioService().openProject(at: project)
        do {
            let value = try await session.snapshot()
            await session.close()
            return value
        } catch {
            await session.close()
            throw error
        }
    }
}

@MainActor
private var cliWorld: BDDCLIWorld { Scenario.state(BDDCLIWorld.init) }

@MainActor
func registerCLISteps() {
    AfterScenario { _ in try cliWorld.cleanup() }

    Given("un ambiente CLI isolato") { _, _ in try cliWorld.prepare() }

    Given("una fonte CLI in formato {word} con testo {string}") { match, _ in
        let world = cliWorld
        world.sourceFormat = try #require(
            GlifiStudioTextFormat(rawValue: match.first(\.word)))
        let content = try match.first(\.string)
        try Data(content.utf8).write(to: world.source)
    }

    Given("un progetto CLI con la fonte sintetica") { _, _ in
        let world = cliWorld
        let content = "Casa, casa sul mare. La casa guarda il mare."
        try Data(content.utf8).write(to: world.source)
        try await world.run(["--format", "json", "project", "create", world.project.path])
        #expect(try #require(world.output).status == 0)
        try await world.run(["--format", "json", "import", world.project.path, world.source.path])
        #expect(try #require(world.output).status == 0)
        world.baseline = try await world.snapshot()
        #expect(world.baseline?.generation == 1)
        #expect(world.baseline?.sourceCount == 1)
    }

    When("richiedo lo stato CLI in formato {string}") { match, _ in
        try await cliWorld.run(["--format", try match.first(\.string), "status"])
    }

    When("profila la fonte con la CLI") { _, _ in
        let world = cliWorld
        try await world.run([
            "--format", "json", "profile", world.source.path, "--input-format",
            world.sourceFormat.rawValue,
        ])
    }

    When("valido il progetto con la CLI") { _, _ in
        try await cliWorld.run(["--format", "json", "project", "validate", cliWorld.project.path])
    }

    When("interrogo la CLI con {string}") { match, _ in
        let world = cliWorld
        let query = try match.first(\.string)
        world.query = query
        try await world.run(["--format", "json", "query", world.project.path, "--text", query])
    }

    Then("la CLI termina con codice {int}") { match, _ in
        let expected = try match.first(\.int)
        let output = try #require(cliWorld.output)
        #expect(output.status == Int32(expected))
    }

    Then("lo stato testuale CLI è pronto") { _, _ in
        let output = try #require(cliWorld.output)
        #expect(output.stdout == Data("GlifiCore pronto\n".utf8))
        #expect(output.stderr.isEmpty)
    }

    Then("lo stato JSON CLI è pronto") { _, _ in
        let json = try cliWorld.json()
        #expect(json["cliProtocolVersion"] as? Int == 1)
        #expect(json["command"] as? String == "status")
        #expect(json["outcome"] as? String == "succeeded")
        #expect((json["result"] as? [String: String]) == ["status": "ready"])
        #expect(try #require(cliWorld.output).stderr.isEmpty)
    }

    Then("il profilo CLI coincide integralmente con GlifiKit") { _, _ in
        let world = cliWorld
        let profile = try await GlifiStudioService().profileText(
            at: world.source, format: world.sourceFormat)
        let native = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? NSDictionary)
        let json = try world.json()
        #expect(json["cliProtocolVersion"] as? Int == 1)
        #expect(json["command"] as? String == "profile")
        #expect(json["outcome"] as? String == "succeeded")
        #expect(try #require(json["result"] as? NSDictionary) == native)
        #expect(try #require(world.output).stderr.isEmpty)
    }

    Then("il profilo CLI contiene {int} token lessicali") { match, _ in
        let result = try #require(cliWorld.json()["result"] as? [String: Any])
        #expect(result["lexicalTokenCount"] as? Int == (try match.first(\.int)))
    }

    Then("la validazione CLI dichiara il progetto valido") { _, _ in
        let json = try cliWorld.json()
        #expect(json["command"] as? String == "project.validate")
        #expect(json["outcome"] as? String == "succeeded")
        let result = try #require(json["result"] as? [String: Any])
        #expect(result["status"] as? String == "valid")
        let project = try #require(result["project"] as? [String: Any])
        #expect(project["generation"] as? Int == 1)
        #expect(project["sourceCount"] as? Int == 1)
    }

    Then("la query CLI coincide con GlifiKit") { _, _ in
        let world = cliWorld
        let query = try #require(world.query)
        let session = try await GlifiStudioService().openProject(at: world.project)
        let native: GlifiStudioProjectQueryResult
        do {
            native = try await session.query(query)
            await session.close()
        } catch {
            await session.close()
            throw error
        }
        let json = try world.json()
        #expect(json["cliProtocolVersion"] as? Int == 1)
        #expect(json["command"] as? String == "query")
        #expect(json["outcome"] as? String == "succeeded")
        let result = try #require(json["result"] as? [String: Any])
        #expect(result["projectID"] as? String == native.projectID)
        #expect(result["generation"] as? Int == native.generation)
        #expect(result["queryDigest"] as? String == native.queryDigest)
        #expect(result["matchedSourceCount"] as? Int == native.matchedSourceCount)
        #expect(result["isTruncated"] as? Bool == native.isTruncated)
        let matches = try #require(result["matches"] as? [[String: Any]])
        #expect(matches.count == native.matches.count)
        for (actual, expected) in zip(matches, native.matches) {
            #expect(actual["startUTF8"] as? Int == expected.startUTF8)
            #expect(actual["endUTF8"] as? Int == expected.endUTF8)
            #expect(actual["sourceRevisionID"] as? String == expected.sourceRevisionID)
            #expect(actual["coordinateSpace"] as? String == expected.coordinateSpace)
            #expect(actual["match"] as? String == expected.match)
            #expect(actual["leftContext"] as? String == expected.leftContext)
            #expect(actual["rightContext"] as? String == expected.rightContext)
            let ranges = try #require(actual["sourceRanges"] as? [[String: Int]])
            #expect(ranges == expected.sourceRanges.map { ["start": $0.start, "end": $0.end] })
        }
        #expect(try #require(world.output).stderr.isEmpty)
    }

    Then("la query CLI produce gli intervalli {string}") { match, _ in
        let expected = try match.first(\.string)
        let result = try #require(cliWorld.json()["result"] as? [String: Any])
        let matches = try #require(result["matches"] as? [[String: Any]])
        let ranges = try matches.map { row in
            "\(try #require(row["startUTF8"] as? Int)):\(try #require(row["endUTF8"] as? Int))"
        }.joined(separator: ",")
        #expect(ranges == expected)
    }

    Then("il progetto CLI conserva lo snapshot precedente") { _, _ in
        let world = cliWorld
        let baseline = try #require(world.baseline)
        #expect(try await world.snapshot() == baseline)
    }

    Then("la failure CLI ha codice {string}") { match, _ in
        let world = cliWorld
        let output = try #require(world.output)
        #expect(output.stdout.isEmpty)
        let json = try world.json(fromError: true)
        #expect(json["cliProtocolVersion"] as? Int == 1)
        #expect(json["outcome"] as? String == "failed")
        let failure = try #require(json["failure"] as? [String: Any])
        #expect(failure["code"] as? String == (try match.first(\.string)))
        #expect(!String(decoding: output.stderr, as: UTF8.self).contains("BDD_PRIVATE_CANARY"))
        #expect(!String(decoding: output.stderr, as: UTF8.self).contains(world.root.path))
    }

    Then("la failure query CLI coincide con GlifiKit") { _, _ in
        let world = cliWorld
        let query = try #require(world.query)
        let session = try await GlifiStudioService().openProject(at: world.project)
        do {
            _ = try await session.query(query)
            Issue.record("GlifiKit accepted a query rejected by the CLI")
            await session.close()
        } catch let failure as GlifiStudioFailure {
            await session.close()
            try expectCLIFailure(failure, world: world)
        } catch {
            await session.close()
            throw error
        }
    }

    Given(#/^una richiesta CLI JSON ([\s\S]+)$/#) { match, _ in
        cliWorld.request = Data(match.output.1.utf8)
    }

    Given("una richiesta CLI di {int} byte") { match, _ in
        cliWorld.request = Data(repeating: 0x20, count: try match.first(\.int))
    }

    Given("una richiesta CLI annidata a profondità {int}") { match, _ in
        let depth = try match.first(\.int)
        cliWorld.request = Data(
            (String(repeating: "[", count: depth) + "0" + String(repeating: "]", count: depth)).utf8
        )
    }

    Given("una richiesta CLI con UTF-8 invalido") { _, _ in
        cliWorld.request = Data([0xFF, 0xFE, 0xC0, 0xAF])
    }

    When("eseguo la richiesta analitica con la CLI") { _, _ in
        let world = cliWorld
        try world.request.write(to: world.requestURL)
        try await world.run([
            "--format", "json", "text-analysis", "--request", world.requestURL.path,
        ])
    }

    Then("la failure della richiesta CLI coincide con GlifiKit") { _, _ in
        let world = cliWorld
        do {
            _ = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: world.request)
            Issue.record("GlifiKit accepted a request rejected by the CLI")
        } catch let failure as GlifiStudioFailure {
            try expectCLIFailure(failure, world: world)
        }
    }

    When(#/^invoco la CLI con argomenti JSON (.+)$/#) { match, _ in
        let arguments = try JSONDecoder().decode(
            [String].self, from: Data(match.output.1.utf8))
        try await cliWorld.run(arguments)
    }

    Then("la CLI mostra la guida senza risultato") { _, _ in
        let output = try #require(cliWorld.output)
        #expect(output.stdout.isEmpty)
        #expect(String(decoding: output.stderr, as: UTF8.self).hasPrefix("Uso:"))
    }
}

@MainActor
private func expectCLIFailure(_ expected: GlifiStudioFailure, world: BDDCLIWorld) throws {
    let failure = try #require(world.json(fromError: true)["failure"] as? [String: Any])
    #expect(failure["code"] as? String == expected.code)
    #expect(failure["category"] as? String == expected.category)
    #expect(failure["operation"] as? String == expected.operation)
    #expect(failure["retryDisposition"] as? String == expected.retryDisposition)
    #expect(failure["retainedState"] as? String == expected.retainedState)
    #expect(failure["messageKey"] as? String == expected.messageKey)
    let arguments = expected.arguments.sorted { $0.key < $1.key }.map {
        ["key": $0.key, "value": $0.value]
    }
    #expect(failure["arguments"] as? [[String: String]] == arguments)
}
