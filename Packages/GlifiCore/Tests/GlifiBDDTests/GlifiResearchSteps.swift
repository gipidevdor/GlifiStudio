// SPDX-License-Identifier: BSD-3-Clause

import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDResearchWorld {
    var root: URL?
    var session: GlifiStudioProjectSession?
    var operation = GlifiStudioResearchOperation.state
    var sourceIDs: [String] = []
    var originalArtifactID = ""
    var saved: GlifiStudioSavedAnalysis?
    var request = Data()
    var result: Data?
    var failure: GlifiStudioFailure?
    var baseline: GlifiStudioProjectSnapshot?
    var statisticsRequest: GlifiStudioStatisticsRequest?
    var statisticsResult: GlifiStudioStatisticsResult?
    var workflowSaved: GlifiStudioSavedAnalysis?
    var workflowState: GlifiStudioResearchState?
    var workflowFilter = GlifiStudioResearchFilter()
    var investigationHead = ""
    var largeTableResult: Data?
    var largeStateResult: Data?
    var largeDTOFailures: [String: GlifiStudioFailure] = [:]
    var largeState: GlifiStudioResearchState?

    // Three original synthetic rows, authored here rather than copied from an external corpus.
    let csv = Data(
        """
        id,testo,gruppo,data
        a,La città di Roma,Nord,2026-01-01
        b,La città di Milano,Sud,2026-01-02
        c,La casa di Roma,Nord,2026-01-03

        """.utf8)
    let nextCSV = Data("id,testo,gruppo,data\nd,Una casa nuova,Sud,2026-01-04\n".utf8)
    let title = "Gruppi sintetici"
    let clustering = GlifiStudioTextAnalysisRequest.clara(
        matrix: [[1, 0], [0, 1], [1, 1]], clusterCount: 2, seed: 9, sampleSize: 3)
    let mapping = GlifiStudioTabularMapping(
        textColumns: [2], identifierColumn: 1,
        variables: [
            .init(column: 3, name: "gruppo", type: .text),
            .init(column: 4, name: "data", type: .date),
        ])

    var projectURL: URL { get throws { try #require(root).appending(path: "Research.glifi") } }

    func prepare(_ variant: String) async throws {
        operation = try #require(
            GlifiStudioResearchOperation.allCases.first { String(describing: $0) == variant })
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDDResearch-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        root = directory
        let active = try await GlifiStudioService().createProject(at: projectURL)
        session = active
        let imported = try await active.importTabular(
            data: csv, options: .init(), mapping: mapping)
        sourceIDs = imported.sourceRevisionIDs
        originalArtifactID = imported.originalArtifactID
        #expect(imported.importedCount == 3)
        #expect(imported.issues.isEmpty)
        try await verifyImportedState(await active.researchState(), count: 3)
        let native = try await GlifiStudioTextAnalytics.executeTextAnalysis(clustering)
        try verifyClustering(BDDVariantAssertions.encode(native))
        saved = try await active.captureSavedAnalysis(
            requestJSON: clustering.canonicalData(),
            resultJSON: BDDVariantAssertions.encode(native), title: title,
            sourceRevisionIDs: sourceIDs, createdAtUnixMilliseconds: 1_700_000_000_000)
        request = try command(operation, parameters: await parameters())
        baseline = try await active.snapshot()
    }

    private func parameters() async throws -> [String: Any] {
        let captured = try #require(saved)
        switch operation {
        case .state, .savedList: return [:]
        case .select:
            return [
                "filter": try wire(
                    GlifiStudioResearchFilter(
                        fieldID: "gruppo", value: .text("Nord"), query: "normalized:roma"))
            ]
        case .saveState:
            let state = try await preparedState()
            return ["state": try wire(state), "expectedRevision": state.revision]
        case .tabularPreview:
            return [
                "data": csv.base64EncodedString(), "options": try wire(GlifiStudioTabularOptions()),
            ]
        case .tabularMap:
            return [
                "table": try await wire(
                    GlifiStudioTabularImporter.preview(data: csv, options: .init())),
                "mapping": try wire(mapping),
            ]
        case .tabularImport:
            return [
                "data": nextCSV.base64EncodedString(), "mapping": try wire(mapping),
                "options": try wire(GlifiStudioTabularOptions()),
            ]
        case .tabularSource: return ["artifactID": originalArtifactID]
        case .savedRead, .savedExport: return ["artifactID": captured.artifactID]
        case .savedInvestigation:
            return [
                "artifactID": captured.artifactID, "question": "Quali gruppi descrivono i testi?",
            ]
        case .deriveVariable:
            return [
                "artifactID": captured.artifactID, "fieldID": "cluster",
                "label": "Gruppo derivato", "expectedRevision": 1,
            ]
        case .savedRun:
            return [
                "requestJSON": captured.requestJSON.base64EncodedString(), "title": title,
                "sourceRevisionIDs": sourceIDs,
            ]
        case .capture:
            return [
                "requestJSON": captured.requestJSON.base64EncodedString(),
                "resultJSON": captured.resultJSON.base64EncodedString(), "title": title,
                "sourceRevisionIDs": sourceIDs, "createdAtUnixMilliseconds": 1_700_000_000_000,
            ]
        case .workbenchCapture:
            let request = GlifiStudioStatisticsRequest(
                operation: .descriptive, values: [[1, 2, 3]])
            let result = try await GlifiStudioStatisticsWorkbench.evaluate(request)
            statisticsRequest = request
            statisticsResult = result
            #expect(
                result.metrics.first { $0.key == "statistics.metric.valid-count" }?.value
                    == .integer(3))
            #expect(
                result.metrics.first { $0.key == "statistics.metric.mean" }?.value == .number(2))
            return [
                "command": "statistics",
                "requestJSON": try BDDVariantAssertions.encode(request).base64EncodedString(),
                "resultJSON": try BDDVariantAssertions.encode(result).base64EncodedString(),
                "methodIdentifier": result.methodIdentifier, "title": "Media sintetica",
                "sourceRevisionIDs": sourceIDs, "createdAtUnixMilliseconds": 1_700_000_000_000,
            ]
        }
    }

    func execute(_ phase: String) async throws {
        result = nil
        failure = nil
        let active = try #require(session)
        var fields = try #require(BDDVariantAssertions.object(request) as? [String: Any])
        if phase == "JSON-invalido" {
            var parameters = try #require(fields["parameters"] as? [String: Any])
            parameters["unexpected_BDD"] = true
            fields["parameters"] = parameters
        }
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        do {
            if phase == "precancellata" {
                let task = Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await GlifiStudioResearchCommand.execute(json: data, session: active)
                }
                result = try await task.value.json
            } else {
                try #require(phase == "nominale" || phase == "JSON-invalido")
                result = try await GlifiStudioResearchCommand.execute(json: data, session: active)
                    .json
            }
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    func verifyNominal(json: String) async throws {
        #expect(failure == nil)
        let bytes = try #require(result)
        let active = try #require(session)
        let captured = try #require(saved)
        var facts = try BDDVariantAssertions.object(bytes)
        switch operation {
        case .state:
            let state = try JSONDecoder().decode(GlifiStudioResearchState.self, from: bytes)
            try await verifyImportedState(state, count: 3)
        case .select:
            let selected = try JSONDecoder().decode([String].self, from: bytes)
            #expect(Set(selected) == Set(try await northernIDs()))
        case .saveState:
            let state = try JSONDecoder().decode(GlifiStudioResearchState.self, from: bytes)
            #expect(state.revision == 2)
            #expect(state.preparation.stopwords == ["la", "di"])
            #expect(state.preparation.compounds == ["città di Roma"])
            #expect(state.subsets.first?.id == "nord")
            #expect(
                Set(try #require(state.subsets.first).sourceRevisionIDs)
                    == Set(try await northernIDs()))
        case .tabularPreview:
            let table = try JSONDecoder().decode(GlifiStudioTabularTable.self, from: bytes)
            #expect(table.columns == ["id", "testo", "gruppo", "data"])
            #expect(table.rows.map(\.number) == [2, 3, 4])
            #expect(table.rows[0].cells[1] == "La città di Roma")
            #expect(table.sourceByteCount == csv.count)
        case .tabularMap:
            let dataset = try JSONDecoder().decode(
                GlifiStudioTabularMappedDataset.self, from: bytes)
            try verifyMapped(dataset)
        case .tabularImport:
            let imported = try JSONDecoder().decode(
                GlifiStudioTabularImportResult.self, from: bytes)
            #expect(imported.importedCount == 1)
            #expect(imported.sourceRevisionIDs.count == 1)
            #expect(!sourceIDs.contains(try #require(imported.sourceRevisionIDs.first)))
            let original = try await active.tabularSource(artifactID: imported.originalArtifactID)
            #expect(original.data == nextCSV)
            #expect(original.dataset.records.first?.identifier == "d")
            try await verifyImportedState(await active.researchState(), count: 4)
        case .tabularSource:
            let original = try JSONDecoder().decode(GlifiStudioTabularSource.self, from: bytes)
            #expect(original.artifactID == originalArtifactID)
            #expect(original.data == csv)
            try verifyMapped(original.dataset)
        case .deriveVariable:
            let state = try JSONDecoder().decode(GlifiStudioResearchState.self, from: bytes)
            try verifyDerived(state, producer: captured)
        case .savedList:
            let analyses = try JSONDecoder().decode([GlifiStudioSavedAnalysis].self, from: bytes)
            #expect(analyses.count == 1)
            try verifySaved(try #require(analyses.first), equals: captured)
        case .savedRead, .savedRun, .capture:
            let observed = try JSONDecoder().decode(GlifiStudioSavedAnalysis.self, from: bytes)
            try verifySaved(observed, equals: captured)
        case .workbenchCapture:
            let observed = try JSONDecoder().decode(GlifiStudioSavedAnalysis.self, from: bytes)
            #expect(observed.transportIdentifier == "workbench-capture-v1")
            #expect(observed.artifactID != captured.artifactID)
            #expect(observed.sourceRevisionIDs == sourceIDs)
            let restored = try GlifiStudioWorkbenchCapture(saved: observed)
            #expect(restored.command == "statistics")
            #expect(
                try JSONDecoder().decode(
                    GlifiStudioStatisticsRequest.self, from: restored.requestJSON) == #require(
                        statisticsRequest))
            #expect(
                try JSONDecoder().decode(
                    GlifiStudioStatisticsResult.self, from: restored.resultJSON) == #require(
                        statisticsResult))
        case .savedExport:
            let exported = try JSONDecoder().decode(Data.self, from: bytes)
            #expect(
                exported == (try await active.exportSavedAnalysis(artifactID: captured.artifactID)))
            let envelope = try #require(BDDVariantAssertions.object(exported) as? [String: Any])
            #expect(
                envelope["requestJSON"] as? String == captured.requestJSON.base64EncodedString())
            #expect(envelope["resultJSON"] as? String == captured.resultJSON.base64EncodedString())
            facts = envelope
        case .savedInvestigation:
            let envelope = try #require(facts as? [String: Any])
            let investigation = try #require(envelope["investigation"] as? [String: Any])
            #expect((investigation["selectedFindingIDs"] as? [String])?.count == 1)
            #expect(!(try #require(investigation["planArtifactID"] as? String)).isEmpty)
            #expect(!(try #require(investigation["interpretationArtifactID"] as? String)).isEmpty)
        }
        try BDDVariantAssertions.expectFacts(facts, json: json)
    }

    func verifyReopening() async throws {
        let active = try #require(session)
        let before = try #require(baseline)
        let warmed = try await active.snapshot()
        let state = try await active.researchState()
        let analyses = try await active.savedAnalyses()
        let mutates = [
            .saveState, .tabularImport, .deriveVariable, .workbenchCapture, .savedInvestigation,
        ].contains(operation)
        if mutates {
            #expect(warmed.artifactCount > before.artifactCount)
        } else {
            #expect(warmed == before)
        }
        #expect(warmed.sources.count == (operation == .tabularImport ? 4 : 3))
        await active.close()
        let reopened = try await GlifiStudioService().openProject(at: projectURL)
        session = reopened
        #expect(try await reopened.snapshot() == warmed)
        #expect(try await reopened.researchState() == state)
        let restored = try await reopened.savedAnalyses()
        #expect(restored.map(\.artifactID) == analyses.map(\.artifactID))
        for analysis in analyses {
            try verifySaved(
                try await reopened.savedAnalysis(artifactID: analysis.artifactID), equals: analysis)
        }
        #expect(try await reopened.tabularSource(artifactID: originalArtifactID).data == csv)
        // Verified reads must not execute a method or append another project generation.
        #expect(try await reopened.snapshot() == warmed)
    }

    func verifyUnchanged() async throws {
        let active = try #require(session)
        #expect(try await active.snapshot() == #require(baseline))
        #expect(try await active.researchState().revision == 1)
        #expect(try await active.savedAnalyses().count == 1)
        #expect(try await active.tabularSource(artifactID: originalArtifactID).data == csv)
        let names = try FileManager.default.contentsOfDirectory(atPath: #require(root).path)
        #expect(names == ["Research.glifi"])
    }

    private func preparedState() async throws -> GlifiStudioResearchState {
        var state = try await #require(session).researchState()
        state.preparation.stopwords = ["la", "di"]
        state.preparation.compounds = ["città di Roma"]
        state.subsets = [
            .init(id: "nord", label: "Testi del Nord", sourceRevisionIDs: try await northernIDs())
        ]
        return state
    }

    private func northernIDs() async throws -> [String] {
        try await #require(session).researchState().records.filter {
            $0.values["gruppo"] == .text("Nord")
        }.map(\.sourceRevisionID)
    }

    private func verifyImportedState(_ state: GlifiStudioResearchState, count: Int) async throws {
        #expect(state.revision == (count == 3 ? 1 : 2))
        #expect(state.fields.count == 2)
        #expect(state.fields.first { $0.id == "gruppo" }?.type == .text)
        #expect(state.fields.first { $0.id == "data" }?.type == .date)
        #expect(state.records.count == count)
        let original = try await #require(session).tabularSource(artifactID: originalArtifactID)
        for (index, externalID) in ["a", "b", "c"].enumerated() {
            let record = try #require(state.records.first { $0.externalID == externalID })
            #expect(record.sourceRevisionID == sourceIDs[index])
            #expect(record.values["data"] == .date("2026-01-0\(index + 1)"))
            #expect(record.values["gruppo"] == .text(index == 1 ? "Sud" : "Nord"))
            #expect(record.origins["$text"]?.row == index + 2)
            #expect(record.origins["$text"]?.column == 2)
            #expect(record.origins["$id"]?.column == 1)
            #expect(record.origins["gruppo"]?.column == 3)
            #expect(record.origins["data"]?.column == 4)
            #expect(
                record.origins.values.allSatisfy { $0.inputDigest == original.dataset.sourceDigest }
            )
        }
    }

    private func verifyMapped(_ dataset: GlifiStudioTabularMappedDataset) throws {
        #expect(dataset.records.count == 3)
        #expect(dataset.issues.isEmpty)
        #expect(dataset.records.map(\.identifier) == ["a", "b", "c"])
        #expect(dataset.records.map(\.rowNumber) == [2, 3, 4])
        let first = try #require(dataset.records.first)
        #expect(first.text == "La città di Roma")
        #expect(first.variables["gruppo"] == .text("Nord"))
        #expect(first.variables["data"] == .date("2026-01-01"))
        #expect(first.textSegments.count == 1)
        #expect(first.textSegments.first?.column == 2)
        #expect(first.textSegments.first?.startUTF8 == 0)
        #expect(first.textSegments.first?.endUTF8 == first.text.utf8.count)
        #expect(first.origins["variable:gruppo"]?.column == 3)
        #expect(first.origins["variable:gruppo"]?.row == 2)
        #expect(first.origins["variable:gruppo"]?.sourceDigest == dataset.sourceDigest)
    }

    private func verifyClustering(_ bytes: Data) throws {
        try BDDVariantAssertions.expectFacts(
            BDDVariantAssertions.object(bytes),
            json:
                #"{"operation":"clara","result.assignments.$count":3,"result.assignments.$distinctCount":2,"result.medoids.$count":2,"result.seed":9}"#
        )
    }

    private func verifySaved(
        _ observed: GlifiStudioSavedAnalysis, equals expected: GlifiStudioSavedAnalysis
    ) throws {
        #expect(observed.artifactID == expected.artifactID)
        #expect(observed.title == expected.title)
        #expect(observed.methodIdentifier == expected.methodIdentifier)
        #expect(observed.transportIdentifier == expected.transportIdentifier)
        #expect(observed.requestJSON == expected.requestJSON)
        #expect(observed.resultJSON == expected.resultJSON)
        #expect(observed.sourceRevisionIDs == expected.sourceRevisionIDs)
        #expect(observed.resultSourceRevisionIDs == expected.resultSourceRevisionIDs)
        #expect(observed.preparationJSON == expected.preparationJSON)
        #expect(observed.preparationDigest == expected.preparationDigest)
        #expect(observed.createdAtUnixMilliseconds == expected.createdAtUnixMilliseconds)
        #expect(observed.sourceRevisionIDs.count == 3)
    }

    private func verifyDerived(
        _ state: GlifiStudioResearchState, producer: GlifiStudioSavedAnalysis
    ) throws {
        #expect(state.fields.count == 3)
        #expect(state.records.count == 3)
        let field = try #require(state.fields.first { $0.id == "cluster" })
        #expect(field.type == .text)
        #expect(field.derivation?.artifactID == producer.artifactID)
        #expect(field.derivation?.operationIdentifier == "stored-document-assignments-v1")
        #expect(Set(state.records.compactMap { $0.values["cluster"]?.codingValue }).count == 2)
        #expect(
            state.records.allSatisfy { $0.derivationArtifactIDs?["cluster"] == producer.artifactID }
        )
        let output = try BDDVariantAssertions.object(producer.resultJSON)
        let assignments = try #require(
            try BDDVariantAssertions.value(output, at: "result.assignments") as? [Int])
        for (index, id) in producer.resultSourceRevisionIDs.enumerated() {
            let record = try #require(state.records.first { $0.sourceRevisionID == id })
            #expect(record.values["cluster"] == .text(String(assignments[index] + 1)))
            #expect(record.origins["gruppo"]?.column == 3)
            #expect(record.origins["cluster"] == nil)
        }
    }

    func prepareWorkflow() async throws {
        let active = try #require(session)
        let state = try await preparedState()
        let changed = try await GlifiStudioResearchCommand.execute(
            json: command(
                .saveState, parameters: ["state": try wire(state), "expectedRevision": 1]),
            session: active)
        let prepared = try JSONDecoder().decode(GlifiStudioResearchState.self, from: changed.json)
        #expect(prepared.revision == 2)
        #expect(prepared.subsets.first?.sourceRevisionIDs.count == 2)
        let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: active, sourceRevisionIDs: sourceIDs, maximumTermCount: 20)
        #expect(input.lexicalTokenCount == 5)
        #expect(input.vocabularySize == 5)
        #expect(input.terms == ["casa", "città", "città di roma", "milano", "roma"])
        #expect(input.matrix.count == 3)
        #expect(input.matrix.allSatisfy { $0.count == 5 })
        #expect(input.preparationDigest == (try prepared.preparation.digest()))
        #expect(
            input.codingUnits.allSatisfy {
                $0.variables["gruppo"] != nil && $0.variables["data"] != nil
            })
        workflowFilter = .init(
            subsetID: "nord", fieldID: "gruppo", value: .text("Nord"), query: "normalized:roma")
        let selected = try await GlifiStudioResearchCommand.execute(
            json: command(.select, parameters: ["filter": try wire(workflowFilter)]),
            session: active)
        let expectedID = try #require(prepared.records.first { $0.externalID == "c" })
            .sourceRevisionID
        #expect(try JSONDecoder().decode([String].self, from: selected.json) == [expectedID])
        #expect(try await active.selectResearchSources(workflowFilter) == [expectedID])
        workflowState = prepared
    }

    func captureWorkflow() async throws {
        let active = try #require(session)
        let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: active, sourceRevisionIDs: sourceIDs)
        let distances = try await GlifiStudioTextAnalytics.dissimilarities(
            input.matrix, metric: .euclidean)
        let request = GlifiStudioTextAnalysisRequest.hierarchical(
            matrix: distances, linkage: "average")
        let native = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        let nativeJSON = try BDDVariantAssertions.encode(native)
        try BDDVariantAssertions.expectFacts(
            BDDVariantAssertions.object(nativeJSON),
            json:
                #"{"operation":"hierarchical","result.linkage":"average","result.children.$count":2,"result.heights.$count":2,"result.sizes.1":3}"#
        )
        let transported = try await GlifiStudioTextAnalytics.executeTextAnalysis(
            json: request.canonicalData())
        #expect(try BDDVariantAssertions.encode(transported) == nativeJSON)
        let params: [String: Any] = [
            "requestJSON": try request.canonicalData().base64EncodedString(),
            "resultJSON": nativeJSON.base64EncodedString(), "title": "Gruppi del corpus preparato",
            "sourceRevisionIDs": input.sourceRevisionIDs,
            "resultSourceRevisionIDs": input.sourceRevisionIDs,
            "preparationDigest": input.preparationDigest,
            "preparation": try wire(input.preparation),
            "createdAtUnixMilliseconds": 1_700_000_000_001,
        ]
        let response = try await GlifiStudioResearchCommand.execute(
            json: command(.capture, parameters: params), session: active)
        let captured = try JSONDecoder().decode(GlifiStudioSavedAnalysis.self, from: response.json)
        #expect(captured.preparationDigest == input.preparationDigest)
        #expect(captured.resultSourceRevisionIDs == input.sourceRevisionIDs)
        #expect(captured.resultJSON == nativeJSON)
        #expect(
            try JSONDecoder().decode(
                GlifiStudioCorpusPreparation.self, from: captured.preparationJSON)
                == input.preparation)
        let snapshot = try await active.snapshot()
        let repeated = try await GlifiStudioResearchCommand.execute(
            json: command(.capture, parameters: params), session: active)
        #expect(repeated.json == response.json)
        #expect(try await active.snapshot() == snapshot)
        let derived = try await GlifiStudioResearchCommand.execute(
            json: command(
                .deriveVariable,
                parameters: [
                    "artifactID": captured.artifactID, "fieldID": "cluster",
                    "label": "Gruppo derivato",
                    "expectedRevision": 2, "clusterCount": 2,
                ]), session: active)
        let state = try JSONDecoder().decode(GlifiStudioResearchState.self, from: derived.json)
        #expect(state.revision == 3)
        #expect(state.fields.count == 3)
        #expect(state.records.count == 3)
        let field = try #require(state.fields.first { $0.id == "cluster" })
        #expect(field.derivation?.artifactID == captured.artifactID)
        #expect(field.derivation?.operationIdentifier == "hac-cut-v1")
        #expect(field.derivation?.parameters == ["clusterCount": "2"])
        #expect(Set(state.records.compactMap { $0.values["cluster"]?.codingValue }).count == 2)
        #expect(
            state.records.allSatisfy { $0.derivationArtifactIDs?["cluster"] == captured.artifactID }
        )
        let output = try #require(BDDVariantAssertions.object(nativeJSON) as? [String: Any])
        let firstMerge = try #require(
            try BDDVariantAssertions.value(output, at: "result.children.0") as? [Int])
        try #require(firstMerge.count == 2 && firstMerge.allSatisfy { (0..<3).contains($0) })
        let left = try #require(
            state.records.first { $0.sourceRevisionID == input.sourceRevisionIDs[firstMerge[0]] })
        let right = try #require(
            state.records.first { $0.sourceRevisionID == input.sourceRevisionIDs[firstMerge[1]] })
        #expect(left.values["cluster"] == right.values["cluster"])
        workflowSaved = captured
        workflowState = state
    }

    func verifyWorkflowFailures() async throws {
        let active = try #require(session)
        let snapshot = try await active.snapshot()
        let state = try #require(workflowState)
        do {
            _ = try await GlifiStudioResearchCommand.execute(
                json: command(
                    .saveState, parameters: ["state": try wire(state), "expectedRevision": 2]),
                session: active)
            Issue.record("Expected stale research revision rejection")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.code == "research.stale-revision")
            #expect(failure.category == "staleArtifact")
        }
        let captured = try #require(workflowSaved)
        do {
            _ = try await active.captureSavedAnalysis(
                requestJSON: captured.requestJSON, resultJSON: Data("{}".utf8),
                title: "Output incoerente", sourceRevisionIDs: sourceIDs)
            Issue.record("Expected incoherent output rejection")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "invalidInput")
        }
        #expect(try await active.snapshot() == snapshot)
        #expect(try await active.researchState() == state)
    }

    func exportWorkflow() async throws {
        let active = try #require(session)
        let captured = try #require(workflowSaved)
        let response = try await GlifiStudioResearchCommand.execute(
            json: command(
                .savedInvestigation,
                parameters: [
                    "artifactID": captured.artifactID,
                    "question": "Quali gruppi descrivono il corpus preparato?",
                ]), session: active)
        let fields = try #require(BDDVariantAssertions.object(response.json) as? [String: Any])
        let investigation = try #require(fields["investigation"] as? [String: Any])
        investigationHead = try #require(investigation["headEventID"] as? String)
        #expect((investigation["selectedFindingIDs"] as? [String])?.count == 1)
        let destination = try #require(root).appending(path: "Export")
        let receipt = try await active.exportInvestigation(
            .init(
                investigationHeadEventID: investigationHead, formats: ["json", "markdown", "csv"]),
            to: destination)
        #expect(receipt.fileCount == 5)
        let manifestBytes = try Data(
            contentsOf: destination.appending(path: "export-manifest.json"))
        let manifest = try #require(BDDVariantAssertions.object(manifestBytes) as? [String: Any])
        let files = try #require(manifest["files"] as? [[String: Any]])
        let companion = try #require(
            files.first {
                $0["schema"] as? String == "studio.glifi.artifact.saved-research-analysis.v1"
            })
        let path = try #require(companion["path"] as? String)
        let payload = try Data(contentsOf: destination.appending(path: path))
        #expect(payload == (try await active.exportSavedAnalysis(artifactID: captured.artifactID)))
        let envelope = try #require(BDDVariantAssertions.object(payload) as? [String: Any])
        #expect(envelope["requestJSON"] as? String == captured.requestJSON.base64EncodedString())
        #expect(envelope["resultJSON"] as? String == captured.resultJSON.base64EncodedString())
        #expect(
            envelope["preparationJSON"] as? String == captured.preparationJSON.base64EncodedString()
        )
        let markdown = try String(
            contentsOf: destination.appending(path: "report.md"), encoding: .utf8)
        #expect(markdown.contains("Output del metodo"))
        #expect(markdown.contains("non certifica il metodo"))
    }

    func reopenWorkflow() async throws {
        let active = try #require(session)
        let snapshot = try await active.snapshot()
        let captured = try #require(workflowSaved)
        let expectedState = try #require(workflowState)
        await active.close()
        let reopened = try await GlifiStudioService().openProject(at: projectURL)
        session = reopened
        #expect(try await reopened.snapshot() == snapshot)
        #expect(try await reopened.researchState() == expectedState)
        try verifySaved(
            try await reopened.savedAnalysis(artifactID: captured.artifactID), equals: captured)
        #expect(try await reopened.savedAnalyses().count == 2)
        #expect(try await reopened.tabularSource(artifactID: originalArtifactID).data == csv)
        let expectedID = try #require(expectedState.records.first { $0.externalID == "c" })
            .sourceRevisionID
        #expect(try await reopened.selectResearchSources(workflowFilter) == [expectedID])
        let repeated = try await reopened.createSavedAnalysisInvestigation(
            artifactID: captured.artifactID,
            question: "Quali gruppi descrivono il corpus preparato?")
        #expect(repeated.investigation.headEventID == investigationHead)
        #expect(try await reopened.snapshot() == snapshot)
    }

    func transferLargeDTOs() async throws {
        let active = try #require(session)
        let directory = try #require(root)
        let cell = String(repeating: "a", count: 220)
        let data = Data(
            ("id,testo,nota\n"
                + (0..<5_000).map {
                    "row\($0),Testo originale \($0),\(cell)\n"
                }.joined()).utf8)
        let table = try await GlifiStudioTabularImporter.preview(data: data, options: .init())
        let tableJSON = try BDDVariantAssertions.encode(table)
        try #require(tableJSON.count > 1_048_576 && tableJSON.count < 64 * 1_048_576)
        let tableURL = directory.appending(path: "table.json")
        try tableJSON.write(to: tableURL)
        let mapping = GlifiStudioTabularMapping(textColumns: [2], identifierColumn: 1)
        let reference = try await GlifiStudioTabularImporter.map(table: table, mapping: mapping)
        #expect(reference.records.count == 5_000)
        #expect(reference.records.first?.identifier == "row0")
        #expect(reference.records.last?.rowNumber == 5_001)

        var state = try await active.researchState()
        let largeText = String(repeating: "b", count: 65_536)
        for index in 0..<20 {
            let id = "large-\(index)"
            state.fields.append(.init(id: id, label: "Campo sintetico \(index)", type: .text))
            state.records[0].values[id] = .text(largeText)
        }
        let stateJSON = try BDDVariantAssertions.encode(state)
        try #require(stateJSON.count > 1_048_576 && stateJSON.count < 32 * 1_048_576)
        let stateURL = directory.appending(path: "state.json")
        try stateJSON.write(to: stateURL)
        largeState = state
        largeDTOFailures = [:]
        let calls: [(String, GlifiStudioResearchOperation, [String: Any])] = [
            ("tablePath", .tabularMap, ["tablePath": tableURL.path, "mapping": try wire(mapping)]),
            (
                "statePath", .saveState,
                ["statePath": stateURL.path, "expectedRevision": state.revision]
            ),
        ]
        let cliProject = directory.appending(path: "CLI.glifi")
        try FileManager.default.copyItem(at: projectURL, to: cliProject)
        for (name, operation, parameters) in calls {
            let envelope = try command(operation, parameters: parameters)
            try #require(envelope.count < 1_048_576)
            do {
                let output = try await GlifiStudioResearchCommand.execute(
                    json: envelope, session: active)
                if name == "tablePath" {
                    largeTableResult = output.json
                } else {
                    largeStateResult = output.json
                }
            } catch let observed {
                largeDTOFailures[name] = observed
            }
            let requestURL = directory.appending(path: "\(name)-request.json")
            let outputURL = directory.appending(path: "\(name)-output.json")
            try envelope.write(to: requestURL)
            let cli = try await BDDSubprocess.run(
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: [
                    "-c", #"output=$1; shift; exec "$@" > "$output""#, "glifi-research-output",
                    outputURL.path, try locateBDDCLI().path, "--format", "json", "--no-progress",
                    "research-call", cliProject.path, "--request", requestURL.path,
                ], directory: directory)
            #expect(cli.status == 0, "CLI \(name): \(String(decoding: cli.stderr, as: UTF8.self))")
            try #require(cli.status == 0)
            let byteCount = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
            try #require(try #require(byteCount) <= 16 * 1_048_576)
            let cliJSON = try Data(contentsOf: outputURL)
            let expected = try #require(name == "tablePath" ? largeTableResult : largeStateResult)
            let cliEnvelope = try #require(BDDVariantAssertions.object(cliJSON) as? [String: Any])
            #expect(cliEnvelope["cliProtocolVersion"] as? Int == 1)
            #expect(cliEnvelope["command"] as? String == "research-call")
            #expect(cliEnvelope["outcome"] as? String == "succeeded")
            let cliResult = try #require(cliEnvelope["result"])
            #expect(
                try JSONSerialization.data(
                    withJSONObject: cliResult, options: [.sortedKeys])
                    == JSONSerialization.data(
                        withJSONObject: BDDVariantAssertions.object(expected),
                        options: [.sortedKeys]))
        }
        if let largeTableResult {
            #expect(largeTableResult == (try BDDVariantAssertions.encode(reference)))
        }
    }

    func verifyLargeDTOs() async throws {
        #expect(
            largeDTOFailures.isEmpty, "File DTO failures: \(largeDTOFailures.mapValues(\.code))")
        let mapped = try #require(largeTableResult)
        try BDDVariantAssertions.expectFacts(
            BDDVariantAssertions.object(mapped),
            json:
                #"{"records.$count":5000,"records.0.identifier":"row0","records.4999.identifier":"row4999","records.4999.rowNumber":5001}"#
        )
        let saved = try JSONDecoder().decode(
            GlifiStudioResearchState.self, from: #require(largeStateResult))
        var expected = try #require(largeState)
        expected.revision += 1
        #expect(saved.fields.count == 22)
        #expect(saved.records.count == 3)
        #expect(Set(saved.fields.map(\.id)) == Set(expected.fields.map(\.id)))
        #expect(saved.records == expected.records)
        let active = try #require(session)
        #expect(try await active.researchState() == saved)
        let snapshot = try await active.snapshot()
        await active.close()
        let reopened = try await GlifiStudioService().openProject(at: projectURL)
        session = reopened
        #expect(try await reopened.researchState() == saved)
        #expect(try await reopened.tabularSource(artifactID: originalArtifactID).data == csv)
        #expect(try await reopened.snapshot() == snapshot)
    }

    func precancelNativePreparation() async throws {
        let active = try #require(session)
        let ids = sourceIDs
        baseline = try await active.snapshot()
        result = nil
        failure = nil
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: active, sourceRevisionIDs: ids)
        }
        do {
            result = try await BDDVariantAssertions.encode(task.value)
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    func verifyPreparationCancellation() async throws {
        try BDDVariantAssertions.expectFailure(
            failure, result: result, code: "operation.cancelled", category: "cancelled",
            operation: "analyze")
        try await verifyUnchanged()
    }

    private func command(_ operation: GlifiStudioResearchOperation, parameters: [String: Any])
        throws -> Data
    {
        try JSONSerialization.data(
            withJSONObject: [
                "schema": GlifiStudioResearchCommand.schema, "schemaVersion": 1,
                "operation": operation.rawValue, "parameters": parameters,
            ], options: [.sortedKeys])
    }

    private func wire<Value: Encodable>(_ value: Value) throws -> Any {
        try BDDVariantAssertions.object(BDDVariantAssertions.encode(value))
    }

    func cleanup() async throws {
        if let session { await session.close() }
        if let root { try FileManager.default.removeItem(at: root) }
    }
}

@MainActor
private var researchWorld: BDDResearchWorld {
    Scenario.state(BDDResearchWorld.init)
}

@MainActor
func registerResearchSteps() {
    AfterScenario { _ in try await researchWorld.cleanup() }
    Given("la variante di ricerca {string} su tre righe italiane originali") { match, _ in
        try await researchWorld.prepare(match.first(\.string))
    }
    When("eseguo la variante di ricerca in fase {word}") { match, _ in
        try await researchWorld.execute(match.first(\.word))
    }
    Then(#/^la ricerca verifica dati e provenienza con i fatti JSON (.+)$/#) { match, _ in
        try await researchWorld.verifyNominal(json: String(match.1))
    }
    Then("la ricerca riaperta conserva fonti configurazione e output senza nuovi calcoli") { _, _ in
        try await researchWorld.verifyReopening()
    }
    Then("la ricerca fallisce con codice {string} e categoria {string} senza modifiche") {
        match, _ in
        try BDDVariantAssertions.expectFailure(
            researchWorld.failure, result: researchWorld.result,
            code: match[\.string, index: 0], category: match[\.string, index: 1])
        try await researchWorld.verifyUnchanged()
    }
    When("salvo preparazione italiana e sottoinsieme con filtro testuale e variabili") { _, _ in
        try await researchWorld.prepareWorkflow()
    }
    When("acquisisco il risultato nativo e JSON e ne derivo una variabile tracciata") { _, _ in
        try await researchWorld.captureWorkflow()
    }
    Then("revisioni obsolete e risultati incoerenti sono rifiutati senza perdita di lavoro") {
        _, _ in
        try await researchWorld.verifyWorkflowFailures()
    }
    When("collego l'output al planner e al rapporto esportando gli stessi byte") { _, _ in
        try await researchWorld.exportWorkflow()
    }
    Then("la riapertura ripristina corpus preparazione selezione variabile e rapporto acquisito") {
        _, _ in
        try await researchWorld.reopenWorkflow()
    }
    When("trasporto anteprima e stato oltre un MiB tramite file JSON espliciti") { _, _ in
        try await researchWorld.transferLargeDTOs()
    }
    Then("mapping e stato grandi conservano parità nativa provenienza e riapertura") { _, _ in
        try await researchWorld.verifyLargeDTOs()
    }
    When("precancello direttamente la preparazione nativa del corpus") { _, _ in
        try await researchWorld.precancelNativePreparation()
    }
    Then("la preparazione cancellata conserva il contratto di lettura e lo snapshot") { _, _ in
        try await researchWorld.verifyPreparationCancellation()
    }
}
