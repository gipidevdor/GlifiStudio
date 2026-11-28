// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiResearchStateTests {
    @Test("La derivazione di un campo conserva trasformazione, parametri e produttore verificato")
    func fieldDerivationParametersSurviveReopening() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        _ = try await project.importText(
            GlifiTextImporter().importText(
                from: Data("Un testo italiano originale.".utf8), format: .plainText))
        let producer = try await GlifiEngine().analyzeCorpus(in: project)
        let derivation = GlifiResearchFieldDerivation(
            artifactID: producer.artifactID.canonicalValue,
            operationIdentifier: "document-count-group-v1",
            parameters: ["threshold": "2", "clusterCount": "2"])
        let state = try await project.saveResearchState(
            .init(fields: [
                .init(id: "group", label: "Gruppo", type: .text, derivation: derivation)
            ]), expectedRevision: 0)
        let restored = try GlifiProjectPackage.open(at: url)
        #expect(try await restored.researchState().fields.first?.derivation == derivation)
        let before = await restored.snapshot()
        var unknown = state
        unknown.fields[0].derivation?.artifactID = try ArtifactID(
            digest: "sha256:" + String(repeating: "0", count: 64)
        ).canonicalValue
        let invalidProducer = unknown
        await #expect(throws: GlifiFailure.self) {
            _ = try await restored.saveResearchState(invalidProducer, expectedRevision: 1)
        }
        var invalid = state
        invalid.fields[0].derivation?.parameters = ["not a key": "2"]
        let invalidParameters = invalid
        await #expect(throws: GlifiFailure.self) {
            _ = try await restored.saveResearchState(invalidParameters, expectedRevision: 1)
        }
        #expect(await restored.snapshot() == before)
    }

    @Test(
        "Una preparazione nuova cambia corpus, dipendenze e ricerca senza riusare il profilo precedente"
    )
    func preparationChangesCorpusAndQueryIdentities() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try GlifiTextImporter().importText(
            from: Data("La città di Roma è una città. I ragazzi mangiano.".utf8), format: .plainText
        )
        _ = try await project.importText(imported)
        let engine = GlifiEngine()
        let original = try await engine.analyzeCorpus(in: project)
        #expect(original.analysis.terms.contains { $0.term == "la" })
        let configuration = GlifiResearchState(
            preparation: .init(
                stopwords: ["la", "di"], compounds: ["città di Roma"]))
        _ = try await project.saveResearchState(configuration, expectedRevision: 0)
        let prepared = try await engine.analyzeCorpus(in: project)
        #expect(!prepared.analysis.terms.contains { $0.term == "la" })
        #expect(prepared.analysis.terms.contains { $0.term == "città di roma" })
        #expect(prepared.analysisNodeID != original.analysisNodeID)
        let reused = try await engine.analyzeCorpus(in: project)
        #expect(reused.analysisNodeID == prepared.analysisNodeID)
        #expect(reused.generation == prepared.generation)
        let query = try await engine.query("normalized:\"città di roma\"", in: project)
        #expect(query.matches.count == 1)
        #expect(query.matches.first?.match == "città di Roma")
        let exactExcluded = try await engine.query("form:\"La città\"", in: project)
        #expect(exactExcluded.matches.isEmpty)
        var state = try await project.researchState()
        state.preparation = .init(base: .italianSnowballStem)
        _ = try await project.saveResearchState(state, expectedRevision: state.revision)
        let stemQuery = try await engine.query("normalized:ragazzi", in: project)
        #expect(stemQuery.matches.first?.match == "ragazzi")
        let profile = try await engine.analyzeCorpus(in: project)
        #expect(profile.analysis.terms.contains { $0.term == "ragazz" })
        #expect(!profile.analysis.terms.contains { $0.term == "ragazzi" })
    }

    @Test("Metadati, gruppi e preparazione sopravvivono a import e riapertura")
    func researchHistorySurvivesImportAndReopening() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = try GlifiProjectPackage.create(at: root.appendingPathExtension("glifi"))
        defer { try? FileManager.default.removeItem(at: root.appendingPathExtension("glifi")) }
        let first = try GlifiTextImporter().importText(
            from: Data("La ricerca riguarda Roma e Milano.".utf8), format: .plainText)
        _ = try await project.importText(first)
        let id = first.sourceRevisionID.canonicalValue
        let data = Data("id,text,area\nr-1,La ricerca riguarda Roma e Milano.,Nord\n".utf8)
        let table = try GlifiTabularImporter.preview(data: data, options: .init())
        let dataset = try GlifiTabularImporter.map(
            table: table,
            mapping: .init(
                textColumns: [2], identifierColumn: 1,
                variables: [.init(column: 3, name: "Area")]))
        let attachment = try await researchArchiveFixture(project, data: data, dataset: dataset)
        let origin = GlifiResearchCellOrigin(
            inputDigest: dataset.sourceDigest, row: 2, column: 3)
        var state = GlifiResearchState(
            fields: [.init(id: "area", label: "Area", type: .text)],
            records: [
                .init(
                    sourceRevisionID: id, values: ["area": .text("Nord")],
                    externalID: "r-1", origins: ["area": origin])
            ],
            subsets: [.init(id: "nord", label: "Risposte del Nord", sourceRevisionIDs: [id])],
            preparation: .init(stopwords: ["la", "e"]))
        let unverified = state
        await #expect(throws: GlifiFailure.self) {
            _ = try await project.saveResearchState(unverified, expectedRevision: 0)
        }
        state = try await project.saveImportedResearchState(
            state, expectedRevision: 0, importedTexts: [], attachments: [attachment])
        #expect(state.revision == 1)
        let second = try GlifiTextImporter().importText(
            from: Data("Un secondo testo indipendente.".utf8), format: .plainText)
        _ = try await project.importText(second)
        #expect(try await project.researchState() == state)
        let restored = try GlifiProjectPackage.open(at: root.appendingPathExtension("glifi"))
        #expect(try await restored.researchState() == state)
        state.records[0].values["area"] = .text("Centro")
        let next = try await restored.saveResearchState(state, expectedRevision: 1)
        #expect(next.revision == 2)
        #expect(try await restored.researchState() == next)
        let before = await restored.snapshot()
        await #expect(throws: GlifiFailure.self) {
            _ = try await restored.saveResearchState(state, expectedRevision: 1)
        }
        #expect(await restored.snapshot() == before)
        var invalidCell = next
        invalidCell.records[0].origins["area"] = .init(
            inputDigest: dataset.sourceDigest, row: 99, column: 3)
        let invalidObservation = invalidCell
        await #expect(throws: GlifiFailure.self) {
            _ = try await restored.saveResearchState(invalidObservation, expectedRevision: 2)
        }
        #expect(await restored.snapshot() == before)
    }

    @Test("I valori invalidi e i riferimenti sconosciuti non cambiano il progetto")
    func invalidValuesAndUnknownSourcesFailClosed() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try GlifiTextImporter().importText(
            from: Data("testo".utf8), format: .plainText)
        _ = try await project.importText(imported)
        let id = imported.sourceRevisionID.canonicalValue
        for value in [
            GlifiResearchValue.text("wrong type"), .date("2025-02-29"), .number(.infinity),
        ] {
            let state = GlifiResearchState(
                fields: [.init(id: "date", label: "Data", type: .date)],
                records: [.init(sourceRevisionID: id, values: ["date": value])])
            let before = await project.snapshot()
            await #expect(throws: GlifiFailure.self) {
                _ = try await project.saveResearchState(state, expectedRevision: 0)
            }
            #expect(await project.snapshot() == before)
        }
        let unknown = GlifiResearchState(
            records: [.init(sourceRevisionID: SourceRevisionID().canonicalValue, values: [:])])
        await #expect(throws: GlifiFailure.self) {
            _ = try await project.saveResearchState(unknown, expectedRevision: 0)
        }
        let validLeap = GlifiResearchState(
            fields: [.init(id: "date", label: "Data", type: .date)],
            records: [.init(sourceRevisionID: id, values: ["date": .date("2024-02-29")])])
        #expect(try await project.saveResearchState(validLeap, expectedRevision: 0).revision == 1)
    }

    @Test("Mancante, stringa vuota, zero e falso restano osservazioni distinte")
    func typedSelectionPreservesMissingValues() throws {
        let ids = (0..<3).map { _ in SourceRevisionID().canonicalValue }
        let state = GlifiResearchState(
            fields: [.init(id: "testo", label: "Testo", type: .text)],
            records: [
                .init(sourceRevisionID: ids[0], values: ["testo": .missing]),
                .init(sourceRevisionID: ids[1], values: ["testo": .text("")]),
            ],
            subsets: [.init(id: "primi", label: "Primi", sourceRevisionIDs: [ids[0], ids[1]])])
        let missing = try GlifiResearchFilter(fieldID: "testo", value: .missing)
            .select(from: state, sourceRevisionIDs: ids)
        #expect(missing == [ids[0], ids[2]])
        let empty = try GlifiResearchFilter(
            subsetID: "primi", fieldID: "testo", value: .text("")
        )
        .select(from: state, sourceRevisionIDs: ids)
        #expect(empty == [ids[1]])
        #expect(
            try GlifiResearchFilter(fieldID: "testo", value: .missing)
                .select(from: state, sourceRevisionIDs: ids).count == 2)
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiResearchFilter(fieldID: "testo", value: .boolean(false))
                .select(from: state, sourceRevisionIDs: ids)
        }
    }

    @Test("La decodifica riesegue i vincoli dello stato autorevole")
    func decodedStateRejectsInvalidDefinitions() throws {
        let state = GlifiResearchState(fields: [.init(id: "field", label: "Campo", type: .number)])
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
                as? [String: Any])
        object["revision"] = -1
        let encoded = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: GlifiFailure.self) {
            _ = try JSONDecoder().decode(GlifiResearchState.self, from: encoded)
        }
    }

    @Test("La modifica dei byte persistiti viene rilevata alla lettura")
    func corruptedStateCannotBeRestored() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        _ = try await project.saveResearchState(GlifiResearchState(), expectedRevision: 0)
        let snapshot = await project.snapshot()
        let record = try #require(snapshot.artifacts.first)
        let object = url.appending(path: record.objectPath)
        try Data("corrupted".utf8).write(to: object)
        await #expect(throws: GlifiFailure.self) { _ = try await project.researchState() }
    }
}

private struct ResearchArchiveFixture: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.artifact.tabular-source.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let data: Data
    let dataset: GlifiTabularMappedDataset

    init(analysisNodeID: AnalysisNodeID, data: Data, dataset: GlifiTabularMappedDataset) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = 1
        self.analysisNodeID = analysisNodeID
        self.data = data
        self.dataset = dataset
    }
}

func researchArchiveFixture(
    _ project: GlifiProjectPackage, data: Data, dataset: GlifiTabularMappedDataset,
    commit: Bool = false
) async throws -> GlifiProjectArtifactAttachment {
    let snapshot = await project.snapshot()
    let descriptor = try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "studio.glifi.artifact.tabular-source",
        algorithmIdentifier: "tabular-capture-v1", algorithmVersion: "1",
        corpusIdentifier: snapshot.projectID.canonicalValue,
        corpusVersionDigest: snapshot.corpusVersionDigest(for: []),
        selectionIdentifier: "external-authorized-dataset",
        analyticalUnitIdentifier: "original-cells",
        preprocessingIdentifiers: [], linguisticProfileIdentifiers: [],
        representationIdentifier: "original-bytes-and-explicit-mapping-v1",
        resolvedParameters: ["inputDigest": .text(dataset.sourceDigest)],
        seedPolicyIdentifier: "no-randomness", backendIdentifier: "studio.glifi.native",
        numericPolicyIdentifier: "explicit-cell-types-v1", determinismClass: .d0,
        outputSchemaIdentifier: ResearchArchiveFixture.outputSchemaIdentifier,
        softwareIdentifier: "GlifiCore-0.1.0", dependencies: [], sourceRevisionIDs: [])
    let payload = try ResearchArchiveFixture(
        analysisNodeID: descriptor.nodeID(), data: data, dataset: dataset)
    if commit { _ = try await project.storeArtifact(payload, descriptor: descriptor) }
    return try GlifiProjectArtifactAttachment(payload: payload, descriptor: descriptor)
}
