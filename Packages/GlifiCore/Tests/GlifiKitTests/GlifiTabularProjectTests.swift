// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiTabularProjectTests {
    @Test(
        "Import tabellare salva testo, variabili, celle e originale e li ripristina alla riapertura"
    )
    func importReopenAndOriginal() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "GlifiTabular-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "Dataset.glifi")
        let session = try await GlifiStudioService().createProject(at: projectURL)
        let original = Data(
            "id;prima;seconda;gruppo;anno;attivo;data\nuno;Città;Mare;A;2024;true;2024-02-29\ndue;Montagna;Neve;B;NA;false;2025-01-01\n"
                .utf8)
        let options = GlifiStudioTabularOptions(delimiter: .semicolon)
        let mapping = GlifiStudioTabularMapping(
            textColumns: [2, 3], identifierColumn: 1,
            variables: [
                .init(column: 4, name: "gruppo"),
                .init(column: 5, name: "anno", type: .integer),
                .init(column: 6, name: "attivo", type: .boolean),
                .init(column: 7, name: "data", type: .date),
            ], missingValues: ["", "NA"])
        let imported = try await session.importTabular(
            data: original, options: options, mapping: mapping)
        #expect(imported.importedCount == 2)
        #expect(imported.sourceRevisionIDs.count == 2)
        #expect(imported.issues.isEmpty)
        let state = try await session.researchState()
        #expect(state.revision == 1)
        #expect(
            state.records.map(\.externalID).sorted { ($0 ?? "") < ($1 ?? "") } == ["due", "uno"])
        let first = try #require(state.records.first { $0.externalID == "uno" })
        let second = try #require(state.records.first { $0.externalID == "due" })
        #expect(first.values["gruppo"] == .text("A"))
        #expect(first.values["anno"] == .number(2024))
        #expect(first.values["attivo"] == .boolean(true))
        #expect(first.values["data"] == .date("2024-02-29"))
        #expect(second.values["anno"] == .missing)
        #expect(first.origins["gruppo"]?.row == 2)
        #expect(first.origins["gruppo"]?.column == 4)
        let text = try await session.sourceText(sourceRevisionID: first.sourceRevisionID)
        #expect(text.text == "Città\n\nMare")
        let before = try await session.snapshot()
        let stored = try await session.tabularSource(artifactID: imported.originalArtifactID)
        #expect(stored.data == original)
        #expect(stored.dataset.mapping == mapping)
        #expect(stored.dataset.options == options)
        #expect(stored.dataset.records[0].textSegments.map(\.column) == [2, 3])
        #expect(stored.dataset.records[0].origins["text:3"]?.column == 3)
        await session.close()
        let reopened = try await GlifiStudioService().openProject(at: projectURL)
        let restored = try await reopened.researchState()
        #expect(restored == state)
        #expect(try await reopened.snapshot().generation == before.generation)
        #expect(
            try await reopened.tabularSource(artifactID: imported.originalArtifactID).data
                == original)
        #expect(
            try await reopened.sourceText(sourceRevisionID: first.sourceRevisionID).text
                == text.text)
        await reopened.close()
    }

    @Test("Rifiutare righe o identificativi duplicati non cambia fonti, variabili o generazione")
    func rejectedImportPreservesCommittedGeneration() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiTabularReject-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Dataset.glifi"))
        let mapping = GlifiStudioTabularMapping(
            textColumns: [2], identifierColumn: 1,
            variables: [.init(column: 3, name: "n", type: .integer)])
        _ = try await session.importTabular(
            data: Data("id,testo,n\na,Prima,1\n".utf8), options: .init(), mapping: mapping)
        let before = try await session.snapshot()
        let state = try await session.researchState()
        for csv in [
            "id,testo,n\na,Collisione,2\n",
            "id,testo,n\nb,Valida,2\nc,Invalida,non-numero\n",
            "id,testo,n\nb,Prima,1\nb,Seconda,2\n",
        ] {
            do {
                _ = try await session.importTabular(
                    data: Data(csv.utf8), options: .init(), mapping: mapping)
                Issue.record("Expected rejected import")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.category == "invalidInput")
            }
            #expect(try await session.snapshot() == before)
            #expect(try await session.researchState() == state)
        }
        await session.close()
    }

    @Test("Duplicati già importati possono essere scartati mantenendo l'issue originale")
    func skipExistingDuplicates() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiTabularSkip-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Dataset.glifi"))
        let mapping = GlifiStudioTabularMapping(
            textColumns: [2], identifierColumn: 1, duplicatePolicy: .skip)
        _ = try await session.importTabular(
            data: Data("id,testo\na,Prima\n".utf8), options: .init(), mapping: mapping)
        let imported = try await session.importTabular(
            data: Data("id,testo\na,Collisione\nb,Nuova\n".utf8), options: .init(), mapping: mapping
        )
        #expect(imported.importedCount == 1)
        #expect(imported.issues.count == 1)
        #expect(imported.issues[0].rowNumber == 2)
        #expect(try await session.researchState().records.count == 2)
        await session.close()
    }

    @Test("Gli identificativi generati sono distinti fra dataset con gli stessi numeri di riga")
    func generatedIdentifiersAreScopedToTheDataset() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiTabularGenerated-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Dataset.glifi"))
        let mapping = GlifiStudioTabularMapping(textColumns: [1])
        _ = try await session.importTabular(
            data: Data("testo\nPrima raccolta\nSeconda risposta\n".utf8), options: .init(),
            mapping: mapping)
        let second = try await session.importTabular(
            data: Data("testo\nAltra raccolta\nAltra risposta\n".utf8), options: .init(),
            mapping: mapping)
        #expect(second.importedCount == 2)
        let records = try await session.researchState().records
        #expect(records.count == 4)
        #expect(Set(records.compactMap(\.externalID)).count == 4)
        await session.close()
    }
}
