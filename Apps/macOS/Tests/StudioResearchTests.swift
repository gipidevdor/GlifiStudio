// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioResearchTests {
    @Test("Il mapping conserva colonne, tipi e provenienza delle righe originali")
    func tabularDraftPreservesExplicitColumnSemantics() async throws {
        let model = StudioResearchModel()
        model.setInput(
            data: Data("id;testo;gruppo\nA;Casa e mare;Nord\nB;Scuola e sole;Sud\n".utf8),
            filename: "questionario.csv")
        model.delimiter = .semicolon
        try await model.preview()
        #expect(model.isPreviewCurrent)
        #expect(model.table?.columns == ["id", "testo", "gruppo"])
        model.textColumns = [2]
        model.identifierColumn = 1
        model.variableColumns = [3]
        model.variableNames[3] = "gruppo"
        model.variableTypes[3] = .text
        try await model.map()
        let mapped = try #require(model.mappedDataset)
        #expect(mapped.records.map(\.identifier) == ["A", "B"])
        #expect(mapped.records.map(\.text) == ["Casa e mare", "Scuola e sole"])
        #expect(mapped.records[0].origins["text:2"]?.column == 2)
        #expect(mapped.records[0].origins["text:2"]?.row == 2)
        #expect(mapped.mapping.variables.first?.name == "gruppo")
    }

    @Test("Cambiare la lettura richiede una nuova anteprima prima di importare")
    func changedParsingOptionsCannotReuseAnOldPreview() async throws {
        let model = StudioResearchModel()
        model.setInput(data: Data("testo,gruppo\nCasa,A\n".utf8), filename: "test.csv")
        try await model.preview()
        model.textColumns = [1]
        try await model.map()
        let previous = try #require(model.mappedDataset)
        model.hasHeaderRow = false
        #expect(!model.isPreviewCurrent)
        await #expect(throws: GlifiStudioFailure.self) { try await model.map() }
        #expect(model.mappedDataset == previous)
    }

    @Test("Valori numerici e booleani non validi non sono corretti silenziosamente")
    func typedValuesRejectInvalidAndNonfiniteInputs() throws {
        #expect(try StudioResearchModel.value("", type: .number) == .missing)
        #expect(try StudioResearchModel.value("1.5", type: .number) == .number(1.5))
        #expect(try StudioResearchModel.value("false", type: .boolean) == .boolean(false))
        for text in ["NaN", "inf", "1,5", "testo"] {
            #expect(throws: GlifiStudioFailure.self) {
                try StudioResearchModel.value(text, type: .number)
            }
        }
        #expect(throws: GlifiStudioFailure.self) {
            try StudioResearchModel.value("yes", type: .boolean)
        }
    }

    @Test("Rimuovere un campo elimina i suoi valori dalle sole bozze pertinenti")
    func removingAFieldKeepsOtherMetadata() {
        let model = StudioResearchModel()
        model.state.fields = [
            GlifiStudioResearchField(id: "group", label: "Gruppo", type: .text),
            GlifiStudioResearchField(id: "year", label: "Anno", type: .number),
        ]
        model.state.records = [
            GlifiStudioResearchRecord(
                sourceRevisionID: "source", values: ["group": .text("A"), "year": .number(2026)])
        ]
        model.values = ["source": ["group": "A", "year": "2026"]]
        model.removeField("group")
        #expect(model.state.fields.map(\.id) == ["year"])
        #expect(model.state.records[0].values == ["year": .number(2026)])
        #expect(model.values["source"] == ["year": "2026"])
    }

    @Test("Una modifica manuale rimuove soltanto la provenienza del valore modificato")
    func manualValuesDoNotKeepAnObsoleteProducer() throws {
        let model = StudioResearchModel()
        model.state.fields = [
            GlifiStudioResearchField(id: "group", label: "Gruppo", type: .text),
            GlifiStudioResearchField(id: "year", label: "Anno", type: .number),
        ]
        model.state.records = [
            GlifiStudioResearchRecord(
                sourceRevisionID: "source", values: ["group": .text("A"), "year": .number(2026)],
                origins: [
                    "group": .init(inputDigest: "digest", row: 2, column: 1),
                    "year": .init(inputDigest: "digest", row: 2, column: 2),
                ], derivationArtifactIDs: ["group": "producerA", "year": "producerB"])
        ]
        model.values = ["source": ["group": "B", "year": "2026"]]
        let next = try model.stateForSaving()
        let record = try #require(next.records.first)
        #expect(record.values["group"] == .text("B"))
        #expect(record.origins["group"] == nil)
        #expect(record.derivationArtifactIDs?["group"] == nil)
        #expect(record.origins["year"]?.column == 2)
        #expect(record.derivationArtifactIDs?["year"] == "producerB")
        #expect(model.state.records.first?.values["group"] == .text("A"))
    }

    @Test("Le variabili alimentano classi e date conservando mancanti e provenienza")
    func metadataFeedsTheExistingClassAndTemporalEditors() {
        let model = StudioResearchModel()
        model.state.revision = 3
        model.state.records = [
            GlifiStudioResearchRecord(
                sourceRevisionID: "a",
                values: ["group": .text("Nord"), "date": .date("2026-11-28")]),
            GlifiStudioResearchRecord(
                sourceRevisionID: "b", values: ["group": .missing, "date": .missing]),
        ]
        #expect(model.classLabels(fieldID: "group") == ["a": "Nord"])
        let dates = model.temporalAnnotations(fieldID: "date")
        #expect(dates.count == 1)
        #expect(dates["a"]?.precision == .civilDate)
        #expect(dates["a"]?.year == 2026)
        #expect(dates["a"]?.month == 11)
        #expect(dates["a"]?.day == 28)
        #expect(dates["a"]?.provenance == "research-metadata-v1;field=date;revision=3")
        #expect(dates["b"] == nil)
    }

    @Test("Cambiare progetto elimina bozze, file e risultati del contesto precedente")
    func resetDropsProjectBoundDraftsAndCapturedInput() async throws {
        let model = StudioResearchModel()
        model.setInput(data: Data("testo\nCasa\n".utf8), filename: "test.csv")
        try await model.preview()
        model.textColumns = [1]
        try await model.map()
        model.selectedSourceID = "source"
        model.selectedSourceIDs = ["source"]
        model.subsetLabel = "Gruppo"
        model.addSubset()
        model.stopwords = "casa"
        model.savedTitle = "Risultato"
        model.missingValues = "NA"
        model.reset()
        #expect(model.table == nil)
        #expect(model.mappedDataset == nil)
        #expect(model.inputData == nil)
        #expect(model.selectedSourceID.isEmpty)
        #expect(model.selectedSourceIDs.isEmpty)
        #expect(model.state.subsets.isEmpty)
        #expect(model.stopwords.isEmpty)
        #expect(model.missingValues.isEmpty)
        #expect(model.savedTitle.isEmpty)
        #expect(!model.hasLoaded)
    }

    @Test("Una variabile riaperta alimenta confronti e tabelle incrociate effettivi")
    func persistedMetadataFeedsGroupComparisonsAndCrosstabRequests() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiResearchGroups-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "Groups.glifi")
        let initial = try await GlifiStudioService().createProject(at: project)
        let texts = [
            "casa mare", "casa sole mare", "scuola libro classe banco penna",
            "scuola libro classe banco penna quaderno alunno",
        ]
        var labels: [String: String] = [:]
        for (index, text) in texts.enumerated() {
            let url = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            let imported = try await initial.importText(at: url, format: .plainText)
            let source = try #require(
                imported.project.sources.first { labels[$0.sourceRevisionID] == nil })
            labels[source.sourceRevisionID] = index < 2 ? "Nord" : "Sud"
        }
        var state = try await initial.researchState()
        state.fields = [.init(id: "area", label: "Area", type: .text)]
        state.records = labels.map {
            .init(sourceRevisionID: $0.key, values: ["area": .text($0.value)])
        }
        _ = try await initial.saveResearchState(state, expectedRevision: state.revision)
        await initial.close()

        let session = try await GlifiStudioService().openProject(at: project)
        let research = StudioResearchModel()
        try await research.load(session: session)
        let home = StudioHomeModel()
        let ids = labels.keys.sorted()
        let numbers = Dictionary(
            uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset + 1) })
        research.useVariable(fieldID: "area", for: .groupComparison, in: home)
        home.corpusMethods.draft.bootstrapResamples = 99
        home.corpusMethods.draft.permutationCount = 99
        _ = try await home.corpusMethods.execute(
            session: session, sourceRevisionIDs: ids, sourceNumbers: numbers,
            locale: Locale(identifier: "it_IT"))
        let comparison = try #require(home.corpusMethods.output)
        let expectedGroups = ["Nord", "Sud"].map { label in
            ids.filter { labels[$0] == label }
        }
        #expect(comparison.groupNames == ["Nord", "Sud"])
        guard case let .groupMetrics(result) = comparison.payload else {
            Issue.record("Expected the metadata-driven group comparison")
            await session.close()
            return
        }
        #expect(result.groups.map(\.sourceRevisionIDs) == expectedGroups)
        #expect(result.groups.map(\.mean) == [2.5, 6])

        home.advancedAnalysis.rules = "*Casa\ncasa"
        research.useVariable(fieldID: "area", for: .codeCrosstab, in: home)
        try await home.advancedAnalysis.execute(
            session: session, sourceRevisionIDs: ids, sourceNumbers: numbers,
            locale: Locale(identifier: "it_IT"))
        let output = try #require(home.advancedAnalysis.output)
        let request = try GlifiStudioTextAnalysisRequest.decode(output.canonicalRequest)
        guard case let .codeCrosstab(_, rules, groups) = request,
            case let .codeCrosstab(table) = try #require(output.typedResult).payload
        else {
            Issue.record("Expected the metadata-driven crosstab request and result")
            await session.close()
            return
        }
        #expect(rules == "*Casa\ncasa")
        #expect(groups == output.input.sourceRevisionIDs.map { labels[$0] })
        #expect(table.groups == ["Nord", "Sud"])
        #expect(table.sizes == [2, 2])
        #expect(table.counts == [[2], [0]])
        await session.close()
    }
}
