// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

// Provenance: GS-LIC-003 / BDD-SRC-03,04,05. All fixture data and assertions are original.
@MainActor
private final class BDDInterchangeWorld {
    var root: URL?
    var projectURL: URL?
    var session: GlifiStudioProjectSession?
    var sourceID: String?
    var baselineSnapshot: GlifiStudioProjectSnapshot?
    var baselineHistory: GlifiStudioQualitativeState?
    var passage: GlifiStudioTextSegment?
    var failure: GlifiStudioFailure?
    var view: GlifiStudioVisualization?
    var bundle: [String: Data] = [:]

    func openedSession() throws -> GlifiStudioProjectSession { try #require(session) }

    func prepareUnicode(scalars: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDDInterchange-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        root = directory
        let project = directory.appending(path: "Unicode.glifi", directoryHint: .isDirectory)
        projectURL = project
        let session = try await GlifiStudioService().createProject(at: project)
        self.session = session
        let sourceURL = directory.appending(path: "original.txt")
        let text = try interchangeText(scalars: scalars)
        try Data(text.utf8).write(to: sourceURL)
        let imported = try await session.importText(at: sourceURL, format: .plainText)
        sourceID = try #require(imported.project.sources.first).sourceRevisionID
        let loaded = try await session.sourceText(sourceRevisionID: #require(sourceID))
        #expect(Data(loaded.text.utf8) == Data(text.utf8))
        _ = try await session.appendQualitativeChange(
            .codebookRevised(
                codebookID: "interchange", revision: 1,
                categories: [
                    GlifiStudioCodebookCategory(
                        categoryID: "passage", label: "Passaggio", definition: "Test originale.")
                ]))
        baselineSnapshot = try await session.snapshot()
        baselineHistory = try await session.qualitativeState()
    }

    func captureFailure(_ body: () async throws -> Void) async throws {
        failure = nil
        do { try await body() } catch let error as GlifiStudioFailure { failure = error }
    }

    func reopen() async throws {
        await session?.close()
        session = nil
        session = try await GlifiStudioService().openProject(at: #require(projectURL))
    }

    func cleanup() async throws {
        await session?.close()
        session = nil
        if let root { try FileManager.default.removeItem(at: root) }
        root = nil
    }
}

@MainActor
private var interchangeWorld: BDDInterchangeWorld { Scenario.state(BDDInterchangeWorld.init) }

@MainActor
func registerInterchangeSteps() {
    AfterScenario { _ in try await interchangeWorld.cleanup() }
    registerUnicodeInterchangeSteps()
    registerCSVInterchangeSteps()
}

@MainActor
private func registerUnicodeInterchangeSteps() {
    Given("una fonte Unicode originale con scalari {string}") { match, _ in
        try await interchangeWorld.prepareUnicode(scalars: match.first(\.string))
    }
    Then("la fonte Unicode contiene {int} caratteri e {int} byte UTF8") { match, _ in
        let world = interchangeWorld
        let session = try world.openedSession()
        let sourceID = try #require(world.sourceID)
        let loaded = try await session.sourceText(sourceRevisionID: sourceID)
        #expect(
            try await session.extractedCharacterCount(sourceRevisionID: sourceID)
                == match[\.int, index: 0])
        #expect(loaded.byteCount == match[\.int, index: 1])
        #expect(loaded.text.utf8.count == match[\.int, index: 1])
    }
    When("seleziono il passaggio Unicode dai caratteri {int} a {int}") { match, _ in
        let world = interchangeWorld
        let start: Int = match[\.int, index: 0]
        let end: Int = match[\.int, index: 1]
        world.passage = nil
        try await world.captureFailure {
            world.passage = try await world.openedSession().passage(
                sourceRevisionID: #require(world.sourceID),
                selection: .characters(start: start, end: end))
        }
    }
    Then("il passaggio Unicode ha scalari {string} e intervallo UTF8 da {int} a {int}") {
        match, _ in
        let world = interchangeWorld
        let passage = try #require(world.passage)
        let expected = try interchangeText(scalars: match.first(\.string))
        #expect(world.failure == nil)
        #expect(Data(passage.text.utf8) == Data(expected.utf8))
        #expect(passage.startUTF8 == match[\.int, index: 0])
        #expect(passage.endUTF8 == match[\.int, index: 1])
    }
    Then("la codifica Unicode conserva il passaggio identico dopo la riapertura") { _, _ in
        let world = interchangeWorld
        let session = try world.openedSession()
        let passage = try #require(world.passage)
        let baseline = try #require(world.baselineHistory)
        let state = try await session.appendQualitativeChange(
            .segmentCoded(
                sourceRevisionID: #require(world.sourceID), startUTF8: passage.startUTF8,
                endUTF8: passage.endUTF8, codebookID: "interchange", codebookRevision: 1,
                categoryID: "passage", coderID: "reader", origin: "manual"))
        #expect(state.codings.count == baseline.codings.count + 1)
        #expect(state.headEventID != baseline.headEventID)
        let coding = try #require(state.codings.last)
        #expect(coding.sourceRevisionID == world.sourceID)
        #expect(coding.startUTF8 == passage.startUTF8 && coding.endUTF8 == passage.endUTF8)
        #expect(coding.categoryID == "passage" && coding.coderID == "reader")
        let snapshot = try await session.snapshot()
        try await world.reopen()
        #expect(try await world.openedSession().qualitativeState() == state)
        #expect(try await world.openedSession().snapshot() == snapshot)
        let reloaded = try await world.openedSession().passage(
            sourceRevisionID: #require(world.sourceID),
            selection: .bytes(start: passage.startUTF8, end: passage.endUTF8))
        #expect(Data(reloaded.text.utf8) == Data(passage.text.utf8))
        #expect(reloaded.startUTF8 == passage.startUTF8 && reloaded.endUTF8 == passage.endUTF8)
    }
    When("tento un passaggio Unicode con intervallo UTF8 da {int} a {int}") { match, _ in
        let world = interchangeWorld
        let start: Int = match[\.int, index: 0]
        let end: Int = match[\.int, index: 1]
        world.passage = nil
        try await world.captureFailure {
            world.passage = try await world.openedSession().passage(
                sourceRevisionID: #require(world.sourceID),
                selection: .bytes(start: start, end: end))
        }
    }
    When("tento una codifica Unicode con intervallo UTF8 da {int} a {int}") { match, _ in
        let world = interchangeWorld
        let start: Int = match[\.int, index: 0]
        let end: Int = match[\.int, index: 1]
        try await world.captureFailure {
            _ = try await world.openedSession().appendQualitativeChange(
                .segmentCoded(
                    sourceRevisionID: #require(world.sourceID), startUTF8: start, endUTF8: end,
                    codebookID: "interchange", codebookRevision: 1, categoryID: "passage",
                    coderID: "reader", origin: "manual"))
        }
    }
    Then("la failure Unicode ha codice {string} senza pubblicare un passaggio") { match, _ in
        let world = interchangeWorld
        let failure = try #require(world.failure)
        let code = try match.first(\.string)
        #expect(failure.code == code)
        #expect(failure.category == "invalidInput")
        #expect(failure.operation == "investigate")
        #expect(failure.retryDisposition == "afterCorrection")
        #expect(failure.retainedState == "unchanged")
        #expect(failure.messageKey == "failure.\(code)")
        #expect(failure.arguments.isEmpty)
        #expect(world.passage == nil)
    }
    Then("snapshot e storia Unicode restano identici anche dopo la riapertura") { _, _ in
        let world = interchangeWorld
        let snapshot = try #require(world.baselineSnapshot)
        let history = try #require(world.baselineHistory)
        #expect(try await world.openedSession().snapshot() == snapshot)
        #expect(try await world.openedSession().qualitativeState() == history)
        try await world.reopen()
        #expect(try await world.openedSession().snapshot() == snapshot)
        #expect(try await world.openedSession().qualitativeState() == history)
    }
}

@MainActor
private func registerCSVInterchangeSteps() {
    Given("una tabella CSV originale con etichetta {word}") { match, _ in
        let label: String
        switch try match.first(\.word) {
        case "semplice": label = "sponda"
        case "virgola": label = "sponda, chiara"
        case "virgolette": label = "sponda \"alta\""
        case "CRLF": label = "sponda\r\nchiara"
        case "vuota": label = ""
        default:
            Issue.record("Unknown original CSV fixture")
            return
        }
        interchangeWorld.view = try interchangeCSVView(label: label)
    }
    When("genero il bundle CSV di interscambio") { _, _ in
        let world = interchangeWorld
        world.bundle = try GlifiStudioVisualExport.bundle(
            #require(world.view), projectID: "project:interchange", generation: 3,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000))
    }
    Then("i byte CSV coincidono con il testo JSON originale") { _, step in
        let world = interchangeWorld
        // Let JSONDecoder handle the escapes; the processed DocString has unescaped quotes.
        let raw = try #require(step.docString?.rawLiteral)
        let expected = try JSONDecoder().decode(
            String.self, from: Data(raw.utf8))
        let actualBytes = try #require(world.bundle["view.csv"])
        let expectedBytes = Data(expected.utf8)
        #expect(
            actualBytes == expectedBytes,
            Comment(
                rawValue: "Synthetic CSV expected UTF8=\(interchangeHex(expectedBytes)); "
                    + "actual UTF8=\(interchangeHex(actualBytes)); "
                    + "datum=\(String(reflecting: world.view?.table.rows.first?.id))"))
    }
    Then("il bundle CSV è verificato con provenienza e digest dei byte esatti") { _, _ in
        let world = interchangeWorld
        let view = try #require(world.view)
        let manifest = try GlifiStudioVisualExport.verify(world.bundle)
        #expect(
            Set(world.bundle.keys) == [
                "view.csv", "view-spec.json", GlifiStudioVisualExport.manifestFileName,
            ])
        #expect(manifest.projectID == "project:interchange" && manifest.generation == 3)
        #expect(manifest.artifactID == view.artifactID)
        #expect(manifest.analysisNodeID == view.analysisNodeID)
        #expect(manifest.methodIdentifier == view.methodIdentifier)
        #expect(manifest.totalObservationCount == 1 && manifest.visibleObservationCount == 1)
        let csv = try #require(manifest.files.first { $0.path == "view.csv" })
        let bytes = try #require(world.bundle["view.csv"])
        #expect(csv.mediaType == "text/csv")
        #expect(csv.byteCount == bytes.count)
        #expect(
            csv.sha256 == "sha256:"
                + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined())
        let decoded = try JSONDecoder().decode(
            GlifiStudioVisualization.self, from: #require(world.bundle["view-spec.json"]))
        #expect(decoded == view)
    }
}

private func interchangeText(scalars: String) throws -> String {
    let values = try scalars.split(separator: " ").map { part in
        let value = try #require(UInt32(part, radix: 16))
        return try #require(Unicode.Scalar(value))
    }
    return String(String.UnicodeScalarView(values))
}

private func interchangeHex(_ bytes: Data) -> String {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

private func interchangeCSVView(label: String) throws -> GlifiStudioVisualization {
    let options = try GlifiStudioWindowCooccurrenceOptions(
        leftSpan: 1, rightSpan: 1, crossesSentences: false, includesSelfPairs: false,
        minimumJointCount: 1, maximumPairCount: 1)
    let object: [String: Any] = [
        "lineage": [
            "projectID": "project:interchange", "sourceGeneration": 2, "generation": 3,
            "artifactID": "artifact:interchange", "analysisNodeID": "node:interchange",
        ],
        "analysisIdentifier": "analysis:interchange",
        "tokenizationContractIdentifier": "tokenization:interchange",
        "sourceRevisionIDs": ["source:interchange"], "contextIdentifier": "window:interchange",
        "universeIdentifier": "method:interchange",
        "options": try JSONSerialization.jsonObject(with: JSONEncoder().encode(options)),
        "tokenCount": 17, "universeSize": 17, "distinctPairCount": 1, "isTruncated": false,
        "pairs": [
            [
                "nodeTerm": label, "collocateTerm": "riva", "jointCount": 2,
                "nodeOnlyCount": 3, "collocateOnlyCount": 5, "neitherCount": 7,
                "meanDistance": 2.5, "weightedJointCount": 2, "occurrences": [],
                "occurrencesTruncated": false,
            ]
        ],
    ]
    let result = try JSONDecoder().decode(
        GlifiStudioWindowCollocationResult.self,
        from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    return GlifiStudioVisualizationBuilder.collocationTable(result)
}
