// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDWorkflowWorld {
    var root: URL?
    var projectURL: URL?
    var session: GlifiStudioProjectSession?
    var files: [String: URL] = [:]
    var formats: [String: GlifiStudioTextFormat] = [:]
    var revisions: [String: String] = [:]
    var profile: GlifiStudioTextProfile?
    var snapshot: GlifiStudioProjectSnapshot?
    var query: GlifiStudioProjectQueryResult?
    var failure: GlifiStudioFailure?
    var input: GlifiStudioProjectTextAnalysisInput?
    var corpus: GlifiStudioCorpusAnalysisResult?
    var previousCorpus: GlifiStudioCorpusAnalysisResult?
    var association: GlifiStudioAssociationResult?
    var distances: [[Double]]?
    var passage: GlifiStudioTextSegment?
    var qualitative: GlifiStudioQualitativeState?
    var view: GlifiStudioVisualization?
    var bundle: [String: Data] = [:]
    var manifest: GlifiStudioVisualExportManifest?
    var plan: GlifiStudioAnalysisPlanResult?
    var execution: GlifiStudioAnalysisExecutionResult?

    func openedSession() throws -> GlifiStudioProjectSession { try #require(session) }

    func createProject() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDD-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        root = directory
        let url = directory.appending(path: "Scenario.glifi", directoryHint: .isDirectory)
        projectURL = url
        session = try await GlifiStudioService().createProject(at: url)
    }

    func stage(_ name: String, text: String, format: GlifiStudioTextFormat) throws {
        let directory = try #require(root)
        let url = directory.appending(path: "\(name).data")
        try Data(text.utf8).write(to: url)
        files[name] = url
        formats[name] = format
    }

    func importSource(_ name: String) async throws {
        let current = try openedSession()
        let previous = try await current.snapshot().sources.map(\.sourceRevisionID)
        let result = try await current.importText(
            at: #require(files[name]), format: #require(formats[name]))
        let added = try #require(
            result.project.sources.first { !previous.contains($0.sourceRevisionID) })
        revisions[name] = added.sourceRevisionID
        profile = result.profile
    }

    func reopen() async throws {
        await session?.close()
        session = try await GlifiStudioService().openProject(at: #require(projectURL))
    }

    func captureFailure(_ body: () async throws -> Void) async throws {
        failure = nil
        do { try await body() } catch let error as GlifiStudioFailure { failure = error }
    }

    func cleanup() async throws {
        await session?.close()
        session = nil
        if let root { try FileManager.default.removeItem(at: root) }
        root = nil
    }
}

@MainActor
private var workflowWorld: BDDWorkflowWorld { Scenario.state(BDDWorkflowWorld.init) }

@MainActor
func registerWorkflowSteps() {
    AfterScenario { _ in try await workflowWorld.cleanup() }
    registerProjectWorkflowSteps()
    registerQueryWorkflowSteps()
    registerCorpusWorkflowSteps()
    registerQualitativeWorkflowSteps()
    registerExportWorkflowSteps()
}

@MainActor
private func registerProjectWorkflowSteps() {
    Given("un progetto temporaneo vuoto") { _, _ in try await workflowWorld.createProject() }
    Given("una fonte {string} con testo {string} in formato {word}") { match, _ in
        let name: String = match[\.string, index: 0]
        let text: String = match[\.string, index: 1]
        let format = try #require(GlifiStudioTextFormat(rawValue: match.first(\.word)))
        try workflowWorld.stage(name, text: text, format: format)
    }
    Given("nel progetto è importato il testo {string}") { match, _ in
        try workflowWorld.stage("source", text: match.first(\.string), format: .plainText)
        try await workflowWorld.importSource("source")
    }
    Given("lo stato del progetto è memorizzato") { _, _ in
        workflowWorld.snapshot = try await workflowWorld.openedSession().snapshot()
    }
    When("importo la fonte {string}") { match, _ in
        try await workflowWorld.importSource(match.first(\.string))
    }
    When("aggiorno la fonte {string} con il testo {string}") { match, _ in
        let name: String = match[\.string, index: 0]
        try workflowWorld.stage(name, text: match[\.string, index: 1], format: .plainText)
        try await workflowWorld.importSource(name)
    }
    When("elimino tutte le fonti esterne e riapro il progetto") { _, _ in
        for url in workflowWorld.files.values { try FileManager.default.removeItem(at: url) }
        try await workflowWorld.reopen()
    }
    When("riapro il progetto") { _, _ in try await workflowWorld.reopen() }
    When("chiudo la sessione e richiedo {word}") { match, _ in
        let world = workflowWorld
        let session = try world.openedSession()
        await session.close()
        let operation = try match.first(\.word)
        try await world.captureFailure {
            switch operation {
            case "snapshot": _ = try await session.snapshot()
            case "query": _ = try await session.query("casa")
            case "corpus": _ = try await session.analyzeCorpus()
            default: Issue.record("Unknown session operation: \(operation)")
            }
        }
    }
    When("tento di importare una fonte {word}") { match, _ in
        let world = workflowWorld
        let url = try #require(world.root).appending(path: "private-canary.data")
        let kind = try match.first(\.word)
        if kind == "UTF8-invalida" { try Data([0x41, 0xC3, 0x28]).write(to: url) }
        try await world.captureFailure {
            _ = try await world.openedSession().importText(at: url, format: .plainText)
        }
    }
    Then("il progetto contiene {int} fonti e {int} artifact alla generazione {int}") { match, _ in
        let snapshot = try await workflowWorld.openedSession().snapshot()
        #expect(snapshot.sourceCount == match[\.int, index: 0])
        #expect(snapshot.artifactCount == match[\.int, index: 1])
        #expect(snapshot.generation == match[\.int, index: 2])
    }
    Then("il profilo contiene {int} token lessicali e {int} tipi") { match, _ in
        let profile = try #require(workflowWorld.profile)
        #expect(profile.lexicalTokenCount == match[\.int, index: 0])
        #expect(profile.typeCount == match[\.int, index: 1])
        #expect(profile.contentDigest.hasPrefix("sha256:"))
    }
    Then("le due revisioni incorporate conservano i testi {string} e {string}") { match, _ in
        let session = try workflowWorld.openedSession()
        let snapshot = try await session.snapshot()
        #expect(snapshot.sourceCount == 2)
        #expect(Set(snapshot.sources.map(\.contentDigest)).count == 2)
        var texts: [String] = []
        for source in snapshot.sources {
            texts.append(
                try await session.sourceText(sourceRevisionID: source.sourceRevisionID).text)
        }
        #expect(Set(texts) == Set([match[\.string, index: 0], match[\.string, index: 1]]))
    }
    Then("lo stato completo del progetto è invariato") { _, _ in
        let expected = try #require(workflowWorld.snapshot)
        let actual = try await workflowWorld.openedSession().snapshot()
        #expect(actual == expected)
    }
    Then("la failure ha codice {string} e categoria {string}") { match, _ in
        let failure = try #require(workflowWorld.failure)
        #expect(failure.code == match[\.string, index: 0])
        #expect(failure.category == match[\.string, index: 1])
        #expect(failure.messageKey.hasPrefix("failure."))
    }
    Then("la failure ha categoria {string}") { match, _ in
        let failure = try #require(workflowWorld.failure)
        let category = try match.first(\.string)
        #expect(failure.category == category)
    }
    Then("la failure non rivela il contenuto {string} né percorsi locali") { match, _ in
        let rendered = String(describing: try #require(workflowWorld.failure))
        #expect(!rendered.contains(try match.first(\.string)))
        if let root = workflowWorld.root { #expect(!rendered.contains(root.path)) }
    }
}

@MainActor
private func registerQueryWorkflowSteps() {
    When("cerco {string}") { match, _ in
        let world = workflowWorld
        let text = try match.first(\.string)
        world.query = nil
        try await world.captureFailure { world.query = try await world.openedSession().query(text) }
    }
    Then("i risultati hanno intervalli UTF8 {string}") { match, _ in
        let expected = try match.first(\.string).split(separator: ",").map { part in
            try part.split(separator: ":").map { try #require(Int($0)) }
        }
        let result = try #require(workflowWorld.query)
        #expect(result.matches.map { [$0.startUTF8, $0.endUTF8] } == expected)
        #expect(result.matchedSourceCount == (expected.isEmpty ? 0 : 1))
        #expect(!result.isTruncated)
        #expect(workflowWorld.failure == nil)
        for item in result.matches {
            let source = try await workflowWorld.openedSession().sourceText(
                sourceRevisionID: item.sourceRevisionID)
            let bytes = Array(source.text.utf8)
            try #require(item.startUTF8 >= 0 && item.endUTF8 <= bytes.count)
            #expect(
                String(decoding: bytes[item.startUTF8..<item.endUTF8], as: UTF8.self) == item.match)
        }
    }
    Then("la ricerca non contiene risultati") { _, _ in
        let result = try #require(workflowWorld.query)
        #expect(result.matches.isEmpty)
        #expect(result.matchedSourceCount == 0)
        #expect(workflowWorld.failure == nil)
    }
}

@MainActor
private func registerCorpusWorkflowSteps() {
    Given("un corpus sintetico di due documenti") { _, _ in
        try await workflowWorld.createProject()
        try workflowWorld.stage("markdown", text: "# Città\n**casa** mare.", format: .markdown)
        try await workflowWorld.importSource("markdown")
        try workflowWorld.stage("plain", text: "casa casa sole.", format: .plainText)
        try await workflowWorld.importSource("plain")
    }
    When("preparo il laboratorio con al massimo {int} termini") { match, _ in
        let world = workflowWorld
        let count = try match.first(\.int)
        try await world.captureFailure {
            world.input = try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: world.openedSession(), sourceRevisionIDs: Array(world.revisions.values),
                maximumTermCount: count)
        }
    }
    When("preparo il laboratorio con ambito {word}") { match, _ in
        let world = workflowWorld
        let first = try #require(world.revisions.values.first)
        let kind = try match.first(\.word)
        let ids: [String]
        switch kind {
        case "vuoto": ids = []
        case "duplicato": ids = [first, first]
        case "inesistente": ids = ["not-a-project-revision"]
        default:
            ids = []
            Issue.record("Unknown scope fixture")
        }
        try await world.captureFailure {
            world.input = try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: world.openedSession(), sourceRevisionIDs: ids)
        }
    }
    Then("il laboratorio conserva sei token e vocabolario {string}") { match, _ in
        let input = try #require(workflowWorld.input)
        let expected = try match.first(\.string).split(separator: ",").map(String.init)
        #expect(input.lexicalTokenCount == 6)
        #expect(input.vocabularySize == 4)
        #expect(input.terms == expected)
        #expect(input.sourceRevisionIDs == input.sourceRevisionIDs.sorted())
        for (index, id) in input.sourceRevisionIDs.enumerated() {
            let markdown = id == workflowWorld.revisions["markdown"]
            #expect(
                input.documents[index]
                    == (markdown ? ["città", "casa", "mare"] : ["casa", "casa", "sole"]))
            let counts: [String: Double] =
                markdown ? ["città": 1, "casa": 1, "mare": 1] : ["casa": 2, "sole": 1]
            #expect(input.matrix[index] == expected.map { counts[$0] ?? 0 })
            #expect(!input.codingUnits[index].text.contains("**"))
            #expect(!input.codingUnits[index].text.contains("#"))
        }
    }
    When("preparo il laboratorio con cancellazione preventiva") { _, _ in
        let world = workflowWorld
        let session = try world.openedSession()
        let ids = Array(world.revisions.values)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: session, sourceRevisionIDs: ids)
        }
        try await world.captureFailure { _ = try await task.value }
    }
    When("pianifico la comprensione della raccolta") { _, _ in
        workflowWorld.plan = try await workflowWorld.openedSession().planAnalysis(
            .init(intent: "understand.collection"))
    }
    Then("il piano spiega che l'ambito è vuoto senza passi eseguibili") { _, _ in
        let plan = try #require(workflowWorld.plan).plan
        #expect(plan.status == "notExecutable")
        #expect(plan.steps.isEmpty)
        #expect(plan.unresolvedReasonIdentifiers == ["planner.empty-scope"])
        #expect(plan.totalEstimatedWorkUnits == 0)
    }
    When("eseguo la comprensione della raccolta") { _, _ in
        let world = workflowWorld
        let execution = try await world.openedSession().executeAnalysisPlan(
            .init(intent: "understand.collection"))
        var completions = 0
        for try await event in execution.events {
            switch event {
            case .progress: break
            case let .completed(result):
                completions += 1
                world.execution = result
            }
        }
        #expect(completions == 1)
    }
    Then("l'interpretazione dichiara evidenza insufficiente e nessun finding") { _, _ in
        let result = try #require(workflowWorld.execution)
        #expect(result.interpretation.findings.isEmpty)
        #expect(result.interpretation.evidence.isEmpty)
        let insufficient = try #require(result.interpretation.insufficientEvidence)
        #expect(insufficient.reasonIdentifiers == ["interpretation.empty-token-population"])
        #expect(insufficient.caveats.contains { $0.severity == "blocking" })
    }
    When("calcolo il profilo del corpus") { _, _ in
        workflowWorld.corpus = try await workflowWorld.openedSession().analyzeCorpus()
    }
    Given("il profilo del corpus è già in cache") { _, _ in
        workflowWorld.corpus = try await workflowWorld.openedSession().analyzeCorpus()
    }
    When("ricalcolo il profilo del corpus") { _, _ in
        workflowWorld.previousCorpus = workflowWorld.corpus
        workflowWorld.corpus = try await workflowWorld.openedSession().analyzeCorpus()
    }
    Then("il corpus ha sei token, quattro tipi e frequenza tre per casa") { _, _ in
        let result = try #require(workflowWorld.corpus)
        #expect(result.documentCount == 2)
        #expect(result.lexicalTokenCount == 6)
        #expect(result.typeCount == 4)
        #expect(result.terms.first?.term == "casa")
        #expect(result.terms.first?.frequency == 3)
        #expect(result.terms.first?.relativeFrequency == 0.5)
        #expect(result.matrix.terms == ["casa", "città", "mare", "sole"])
        #expect(result.matrix.cells.reduce(0) { $0 + $1.count } == 6)
        #expect(result.diversity.ttr == 4.0 / 6)
    }
    Then("il riuso conserva artifact, nodo e valori scientifici") { _, _ in
        let original = try #require(workflowWorld.previousCorpus)
        let current = try #require(workflowWorld.corpus)
        #expect(current.artifactID == original.artifactID)
        #expect(current.analysisNodeID == original.analysisNodeID)
        #expect(current.corpusDigest == original.corpusDigest)
        #expect(current.terms == original.terms)
        #expect(current.matrix == original.matrix)
        #expect(current.diversity == original.diversity)
    }
    When("richiedo il corpus con budget di vocabolario {int}") { match, _ in
        let world = workflowWorld
        let count = try match.first(\.int)
        let options = try GlifiStudioCorpusAnalysisOptions(
            diversityWindowSize: 50, ngramSizes: [1, 2, 3], maximumDocumentCount: 100,
            maximumSourceByteCount: 1_048_576, maximumVocabularySize: count,
            maximumDistinctNGramCount: 10_000, maximumNonZeroCellCount: 10_000)
        try await world.captureFailure {
            _ = try await world.openedSession().analyzeCorpus(options: options)
        }
    }
    When("calcolo l'associazione fra i documenti") { _, _ in
        workflowWorld.association = try await workflowWorld.openedSession().analyzeAssociation(
            sourceRevisionIDs: Array(workflowWorld.revisions.values))
    }
    Then("il chi quadro è dieci terzi con tre gradi di libertà") { _, _ in
        let result = try #require(workflowWorld.association)
        #expect(abs(result.chiSquareStatistic - 10.0 / 3) < 1e-12)
        #expect(result.degreesOfFreedom == 3)
        #expect(result.totalObservations == 6)
        #expect(result.includedTermCount == 4)
    }
    When("calcolo la distanza Jaccard del laboratorio") { _, _ in
        let input = try #require(workflowWorld.input)
        workflowWorld.distances = try await GlifiStudioTextAnalytics.dissimilarities(
            input.matrix, metric: .jaccard)
    }
    Then("le distanze sono zero sulla diagonale e tre quarti fuori diagonale") { _, _ in
        let distances = try #require(workflowWorld.distances)
        #expect(distances == [[0, 0.75], [0.75, 0]])
    }
    When("normalizzo le righe del laboratorio per mille") { _, _ in
        let input = try #require(workflowWorld.input)
        let result = try await GlifiStudioKHAnalysis.execute(
            .perThousand(matrix: input.matrix, exposures: [3, 3]))
        guard case let .advanced(.kh(.matrix(values))) = result.payload else {
            Issue.record("Expected the per-thousand matrix")
            return
        }
        workflowWorld.distances = values
    }
    Then("ogni riga somma mille e preserva le proporzioni osservate") { _, _ in
        let input = try #require(workflowWorld.input)
        let values = try #require(workflowWorld.distances)
        try #require(values.count == 2)
        for (row, cells) in values.enumerated() {
            #expect(abs(cells.reduce(0, +) - 1_000) < 1e-12)
            #expect(cells.count == input.matrix[row].count)
            for (column, value) in cells.enumerated() {
                #expect(abs(value - input.matrix[row][column] * 1_000 / 3) < 1e-12)
            }
        }
    }
}

@MainActor
private func registerQualitativeWorkflowSteps() {
    Given("un codebook con la categoria luogo") { _, _ in
        _ = try await workflowWorld.openedSession().appendQualitativeChange(
            .codebookRevised(
                codebookID: "temi", revision: 1,
                categories: [
                    GlifiStudioCodebookCategory(
                        categoryID: "luogo", label: "Luogo", definition: "Luoghi del testo.")
                ]))
    }
    When("seleziono i caratteri da {int} a {int}") { match, _ in
        let world = workflowWorld
        let start: Int = match[\.int, index: 0]
        let end: Int = match[\.int, index: 1]
        try await world.captureFailure {
            world.passage = try await world.openedSession().passage(
                sourceRevisionID: #require(world.revisions["source"]),
                selection: .characters(start: start, end: end))
        }
    }
    Then("il passaggio contiene {string} e occupa {int} byte UTF8") { match, _ in
        let passage = try #require(workflowWorld.passage)
        #expect(passage.text == (try match.first(\.string)))
        #expect(passage.endUTF8 - passage.startUTF8 == (try match.first(\.int)))
    }
    When("codifico il passaggio selezionato e aggiungo un memo") { _, _ in
        let world = workflowWorld
        let passage = try #require(world.passage)
        let state = try await world.openedSession().appendQualitativeChange(
            .segmentCoded(
                sourceRevisionID: #require(world.revisions["source"]),
                startUTF8: passage.startUTF8, endUTF8: passage.endUTF8,
                codebookID: "temi", codebookRevision: 1, categoryID: "luogo",
                coderID: "coder-1", origin: "manual"))
        let event = try #require(state.codings.last?.eventID)
        world.qualitative = try await world.openedSession().appendQualitativeChange(
            .memoAttached(
                target: .coding(eventID: event), coderID: "coder-1", text: "Caso sintetico."))
    }
    Then("codifica e memo sopravvivono identici alla riapertura") { _, _ in
        let original = try #require(workflowWorld.qualitative)
        try await workflowWorld.reopen()
        let actual = try await workflowWorld.openedSession().qualitativeState()
        #expect(actual == original)
        #expect(actual.codings.count == 1)
        #expect(actual.memos.count == 1)
        #expect(actual.codebooks.count == 1)
        let coding = try #require(actual.codings.first)
        let sourceRevisionID = try #require(workflowWorld.revisions["source"])
        #expect(coding.sourceRevisionID == sourceRevisionID)
        #expect(coding.startUTF8 == 3)
        #expect(coding.endUTF8 == 7)
        #expect(coding.codebookID == "temi")
        #expect(coding.codebookRevision == 1)
        #expect(coding.categoryID == "luogo")
        #expect(coding.coderID == "coder-1")
        #expect(coding.origin == "manual")
        #expect(coding.retractionEventID == nil)
        let memo = try #require(actual.memos.first)
        #expect(memo.target == .coding(eventID: coding.eventID))
        #expect(memo.coderID == "coder-1")
        #expect(memo.text == "Caso sintetico.")
    }
    When("tento una codifica con intervallo UTF8 da {int} a {int}") { match, _ in
        let world = workflowWorld
        let start: Int = match[\.int, index: 0]
        let end: Int = match[\.int, index: 1]
        world.qualitative = try await world.openedSession().qualitativeState()
        try await world.captureFailure {
            _ = try await world.openedSession().appendQualitativeChange(
                .segmentCoded(
                    sourceRevisionID: #require(world.revisions["source"]),
                    startUTF8: start, endUTF8: end, codebookID: "temi",
                    codebookRevision: 1, categoryID: "luogo", coderID: "coder-1", origin: "manual"))
        }
    }
    Then("la storia qualitativa è invariata") { _, _ in
        let expected = try #require(workflowWorld.qualitative)
        let actual = try await workflowWorld.openedSession().qualitativeState()
        #expect(actual == expected)
    }
}

@MainActor
private func registerExportWorkflowSteps() {
    Given("una tabella scientifica con etichetta {string}") { match, _ in
        workflowWorld.view = try workflowExportView(label: match.first(\.string))
    }
    Given("il bundle scientifico è stato generato") { _, _ in
        workflowWorld.bundle = try GlifiStudioVisualExport.bundle(
            #require(workflowWorld.view), projectID: "project:bdd", generation: 7,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000))
    }
    When("verifico il bundle scientifico") { _, _ in
        let world = workflowWorld
        world.manifest = nil
        try await world.captureFailure {
            world.manifest = try GlifiStudioVisualExport.verify(world.bundle)
        }
    }
    Then("manifest e payload conservano provenienza e valori") { _, _ in
        let world = workflowWorld
        let manifest = try #require(world.manifest)
        let view = try #require(world.view)
        #expect(world.failure == nil)
        #expect(
            Set(world.bundle.keys) == [
                "view.csv", "view-spec.json", GlifiStudioVisualExport.manifestFileName,
            ])
        #expect(manifest.projectID == "project:bdd")
        #expect(manifest.generation == 7)
        #expect(manifest.artifactID == view.artifactID)
        #expect(manifest.analysisNodeID == view.analysisNodeID)
        #expect(manifest.methodIdentifier == view.methodIdentifier)
        #expect(manifest.caveatKeys == view.caveatKeys)
        #expect(manifest.totalObservationCount == 1 && manifest.visibleObservationCount == 1)
        for file in manifest.files {
            let bytes = try #require(world.bundle[file.path])
            #expect(file.byteCount == bytes.count)
            #expect(file.sha256 == workflowDigest(bytes))
        }
        let decoded = try JSONDecoder().decode(
            GlifiStudioVisualization.self, from: #require(world.bundle["view-spec.json"]))
        #expect(decoded == view)
    }
    Then("il CSV contiene l'etichetta quotata secondo RFC4180") { _, _ in
        let csv = String(decoding: try #require(workflowWorld.bundle["view.csv"]), as: UTF8.self)
        #expect(csv.contains("\"mare, \"\"calmo\"\"\""))
        #expect(csv.contains("\r\n"))
    }
    When("altero i byte del file {string}") { match, _ in
        let path = try match.first(\.string)
        var bytes = try #require(workflowWorld.bundle[path])
        bytes.append(0x20)
        workflowWorld.bundle[path] = bytes
    }
    When("rimuovo il file {string}") { match, _ in
        let removed = workflowWorld.bundle.removeValue(forKey: try match.first(\.string))
        #expect(removed != nil)
    }
    When("aggiungo un file non dichiarato al bundle") { _, _ in
        workflowWorld.bundle["unexpected.txt"] = Data("synthetic".utf8)
    }
    When("sostituisco il campo di provenienza {string} del manifest") { match, _ in
        let path = GlifiStudioVisualExport.manifestFileName
        var object = try workflowJSONObject(#require(workflowWorld.bundle[path]))
        object[try match.first(\.string)] = "unrelated"
        workflowWorld.bundle[path] = try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys])
    }
    When("altero il CSV e aggiorno il suo digest nel manifest") { _, _ in
        let csv = String(decoding: try #require(workflowWorld.bundle["view.csv"]), as: UTF8.self)
        try #require(csv.contains("1.25"))
        let changed = Data(csv.replacingOccurrences(of: "1.25", with: "9.5").utf8)
        workflowWorld.bundle["view.csv"] = changed
        let path = GlifiStudioVisualExport.manifestFileName
        var manifest = try workflowJSONObject(#require(workflowWorld.bundle[path]))
        var files = try #require(manifest["files"] as? [[String: Any]])
        let index = try #require(files.firstIndex { $0["path"] as? String == "view.csv" })
        files[index]["byteCount"] = changed.count
        files[index]["sha256"] = workflowDigest(changed)
        manifest["files"] = files
        workflowWorld.bundle[path] = try JSONSerialization.data(
            withJSONObject: manifest, options: [.sortedKeys])
    }
}

private func workflowDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func workflowJSONObject(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func workflowExportView(label: String) throws -> GlifiStudioVisualization {
    let options = try GlifiStudioWindowCooccurrenceOptions(
        leftSpan: 2, rightSpan: 2, crossesSentences: false, includesSelfPairs: false,
        minimumJointCount: 1, maximumPairCount: 2)
    let object: [String: Any] = [
        "lineage": [
            "projectID": "project:bdd", "sourceGeneration": 6, "generation": 7,
            "artifactID": "artifact:bdd", "analysisNodeID": "node:bdd",
        ],
        "analysisIdentifier": "analysis:bdd", "tokenizationContractIdentifier": "tokenization:bdd",
        "sourceRevisionIDs": ["source:bdd"], "contextIdentifier": "window:bdd",
        "universeIdentifier": "method:bdd",
        "options": try JSONSerialization.jsonObject(with: JSONEncoder().encode(options)),
        "tokenCount": 20, "universeSize": 20, "distinctPairCount": 1, "isTruncated": false,
        "pairs": [
            [
                "nodeTerm": label, "collocateTerm": "porto", "jointCount": 3,
                "nodeOnlyCount": 4, "collocateOnlyCount": 5, "neitherCount": 8,
                "meanDistance": 1.25, "weightedJointCount": 3, "occurrences": [],
                "occurrencesTruncated": false,
            ]
        ],
    ]
    let result = try JSONDecoder().decode(
        GlifiStudioWindowCollocationResult.self,
        from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    return GlifiStudioVisualizationBuilder.collocationTable(result)
}
