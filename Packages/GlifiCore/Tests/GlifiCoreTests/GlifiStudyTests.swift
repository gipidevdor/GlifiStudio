// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiStudyTests {
    @Test("Lo studio è lazy, conserva Markdown e provenienza e riapre senza scritture")
    func studyReaderAndImmutablePassagesSurviveReopening() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Study-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try GlifiTextImporter().importText(
            from: Data("# Titolo\n👩🏽‍🔬 Studiare **insieme**.\n".utf8), format: .markdown)
        _ = try await project.importText(imported)
        let before = try Data(contentsOf: url.appending(path: "manifest.json"))
        let empty = try await project.studyState()
        #expect(empty.revision == 0)
        #expect(try Data(contentsOf: url.appending(path: "manifest.json")) == before)
        let state = try await project.collectStudyExcerpt(
            sourceRevisionID: imported.sourceRevisionID.canonicalValue,
            selection: .characters(start: 0, end: 6), title: "Titolo letto", expectedRevision: 0)
        #expect(state.revision == 1)
        #expect(try requirement(url) == 4)
        let excerpt = try #require(state.excerpts.first)
        let resolved = try await project.resolveStudyExcerpt(excerptID: excerpt.id)
        #expect(resolved.extractedText == imported.text)
        #expect(resolved.sourceText == String(decoding: imported.bytes, as: UTF8.self))
        #expect(resolved.extractedText != resolved.sourceText)
        #expect(excerpt.anchor.representationDigest == studyBytesDigest(Data(imported.text.utf8)))
        #expect(excerpt.anchor.quote == "Titolo")
        var edited = state
        edited.groups = [.init(id: "reading", title: "Lettura")]
        edited.notes = [
            .init(
                id: "conclusion", title: "Conclusione", text: "Una nota personale",
                groupID: "reading", excerptIDs: [excerpt.id])
        ]
        edited.order = ["conclusion", excerpt.id]
        edited.comparisonExcerptIDs = [excerpt.id]
        let saved = try await project.saveStudyState(edited, expectedRevision: 1)
        _ = try await project.importText(
            GlifiTextImporter().importText(from: Data("Altra fonte".utf8), format: .plainText))
        #expect(try requirement(url) == 4)
        let reopened = try GlifiProjectPackage.open(at: url)
        let snapshot = await reopened.snapshot()
        #expect(try await reopened.studyState() == saved)
        let exported = try await project.exportStudy()
        #expect(try await reopened.exportStudy() == exported)
        #expect(
            try await reopened.studyOriginal(
                sourceRevisionID: imported.sourceRevisionID.canonicalValue
            ).data == imported.bytes)
        #expect(await reopened.snapshot() == snapshot)
        for minimum in [1, 2, 3, 5] {
            let manifest = url.appending(path: "manifest.json")
            let bytes = try Data(contentsOf: manifest)
            var fields = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            fields["minimumReaderVersion"] = minimum
            try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]).write(
                to: manifest)
            #expect(throws: GlifiFailure.self) { try GlifiProjectPackage.open(at: url) }
            try bytes.write(to: manifest)
        }
    }

    @Test("Conflitti riferimenti pendenti progetto estraneo e limiti non pubblicano revisioni")
    func invalidWritesAreAtomic() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Study-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        let initial = try await project.studyState()
        let state = try await project.saveStudyState(initial, expectedRevision: 0)
        let baseline = await project.snapshot()
        for variant in 0..<4 {
            var invalid = state
            if variant == 0 { invalid.revision = 0 }
            if variant == 1 {
                invalid.notes = [
                    .init(id: "note", title: "Nota", text: "Testo", excerptIDs: ["missing"])
                ]
                invalid.order = ["note"]
            }
            if variant == 2 {
                invalid.groups = (0..<201).map { .init(id: "g\($0)", title: "Gruppo") }
            }
            if variant == 3 { invalid.investigationID = "unknown" }
            let request = invalid
            await #expect(throws: GlifiFailure.self) {
                try await project.saveStudyState(request, expectedRevision: 1)
            }
            #expect(await project.snapshot() == baseline)
        }
        let foreign = GlifiStudyState(projectID: ProjectID().canonicalValue, revision: 1)
        await #expect(throws: GlifiFailure.self) {
            try await project.saveStudyState(foreign, expectedRevision: 1)
        }
        #expect(await project.snapshot() == baseline)
    }

    @Test("Il PDF digitale usa originale e locatori catturati anche dopo riapertura")
    func capturedPDFResolvesWithoutNewExtraction() async throws {
        var repository = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { repository.deleteLastPathComponent() }
        let bytes = try Data(
            contentsOf: repository.appending(path: "Fixtures/DocumentImport/v1/digital.pdf"))
        let imported = try GlifiTextImporter().importText(from: bytes, format: .pdf)
        let url = FileManager.default.temporaryDirectory.appending(path: "StudyPDF-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        _ = try await project.importText(imported)
        #expect(try requirement(url) == 2)
        #expect(
            try await project.studyOriginal(
                sourceRevisionID: imported.sourceRevisionID.canonicalValue
            ).data == bytes)
        #expect(try requirement(url) == 2)
        let state = try await project.collectStudyExcerpt(
            sourceRevisionID: imported.sourceRevisionID.canonicalValue,
            selection: .characters(start: 0, end: min(12, imported.text.count)),
            title: "PDF originale", expectedRevision: 0)
        let id = try #require(state.excerpts.first).id
        let reopened = try GlifiProjectPackage.open(at: url)
        let before = await reopened.snapshot()
        let resolved = try await reopened.resolveStudyExcerpt(excerptID: id)
        #expect(resolved.imported.documentExtraction == imported.documentExtraction)
        #expect(resolved.imported.documentExtraction?.locations.first?.pageNumber == 1)
        #expect(resolved.imported.documentExtraction?.locations.first?.method == "pdf-text")
        #expect(resolved.imported.documentExtraction?.locations.first?.region == nil)
        #expect(resolved.extractedText.utf8.elementsEqual(imported.text.utf8))
        #expect(
            try await reopened.studyOriginal(
                sourceRevisionID: imported.sourceRevisionID.canonicalValue
            ).data == bytes)
        #expect(await reopened.snapshot() == before)
    }

    @Test(
        "Schema versione e citazioni persistenti incoerenti sono corruzione senza riparazioni silenziose"
    )
    func persistedStudyPayloadsFailClosed() async throws {
        for variant in 0..<3 {
            let url = FileManager.default.temporaryDirectory.appending(
                path: "StudyCorruption-\(UUID()).glifi")
            defer { try? FileManager.default.removeItem(at: url) }
            let project = try GlifiProjectPackage.create(at: url)
            let imported = try GlifiTextImporter().importText(
                from: Data("Un testo originale.".utf8), format: .plainText)
            _ = try await project.importText(imported)
            var state = try await project.collectStudyExcerpt(
                sourceRevisionID: imported.sourceRevisionID.canonicalValue,
                selection: .characters(start: 0, end: 8), title: "Passaggio", expectedRevision: 0)
            let previous = try #require(await project.snapshot().artifacts.first)
            state.revision = 2
            if variant == 2 {
                let original = try #require(state.excerpts.first)
                let a = original.anchor
                let falseAnchor = GlifiStudyAnchor(
                    sourceRevisionID: a.sourceRevisionID,
                    sourceContentDigest: a.sourceContentDigest,
                    representationDigest: a.representationDigest,
                    extractionContractIdentifier: a.extractionContractIdentifier,
                    startUTF8: a.startUTF8, endUTF8: a.endUTF8, quote: "Falso!!!",
                    sourceRanges: a.sourceRanges)
                state.excerpts[0] = .init(
                    id: original.id, title: original.title, anchor: falseAnchor)
            }
            let descriptor = try payloadDescriptor(state, previous: previous)
            _ = try await project.storeArtifact(
                StudyTestPayload(
                    schemaIdentifier: variant == 1
                        ? "studio.glifi.artifact.study-state.v9"
                        : "studio.glifi.artifact.study-state.v1",
                    schemaVersion: variant == 0 ? 2 : 1, analysisNodeID: descriptor.nodeID(),
                    previousArtifactID: previous.artifactID.canonicalValue, state: state),
                descriptor: descriptor)
            let before = await project.snapshot()
            do {
                _ = try await project.studyState()
                Issue.record("Expected persisted study corruption rejection")
            } catch let failure as GlifiFailure {
                #expect(failure.code == "study.invalid-history")
                #expect(failure.category == .corruption)
                #expect(failure.retainedState == .readOnlyRecovery)
            }
            #expect(await project.snapshot() == before)
        }
    }

    @Test("Il Markdown collega conclusioni e passaggi con numeri leggibili e rimane riproducibile")
    func markdownReferencesFollowNotebookOrder() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "StudyMarkdown-\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let project = try GlifiProjectPackage.create(at: url)
        let imported = try GlifiTextImporter().importText(
            from: Data("Uno. Due.".utf8), format: .plainText)
        _ = try await project.importText(imported)
        let first = try await project.collectStudyExcerpt(
            sourceRevisionID: imported.sourceRevisionID.canonicalValue,
            selection: .characters(start: 0, end: 4), title: "Primo", expectedRevision: 0)
        var state = try await project.collectStudyExcerpt(
            sourceRevisionID: imported.sourceRevisionID.canonicalValue,
            selection: .characters(start: 5, end: 9), title: "Secondo", expectedRevision: 1)
        let firstID = try #require(first.excerpts.first).id
        let secondID = try #require(state.excerpts.first { $0.id != firstID }).id
        state.notes = [
            .init(
                id: "note", title: "Conclusione", text: "Due passaggi collegati",
                excerptIDs: [firstID, secondID])
        ]
        state.order = ["note", secondID, firstID]
        _ = try await project.saveStudyState(state, expectedRevision: 2)
        let bytes = try await project.exportStudy(format: .markdown)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("## Passaggio 1 · Secondo"))
        #expect(text.contains("## Passaggio 2 · Primo"))
        #expect(text.contains("Passaggi collegati: [2] Primo, [1] Secondo"))
        #expect(!text.contains("Passaggi collegati: " + firstID))
        let reopened = try GlifiProjectPackage.open(at: url)
        #expect(try await reopened.exportStudy(format: .markdown) == bytes)
    }

    private func payloadDescriptor(_ state: GlifiStudyState, previous: GlifiProjectArtifactRecord)
        throws -> GlifiAnalysisDescriptor
    {
        let d = previous.node.descriptor
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: d.artifactTypeIdentifier,
            algorithmIdentifier: d.algorithmIdentifier, algorithmVersion: d.algorithmVersion,
            corpusIdentifier: d.corpusIdentifier, corpusVersionDigest: d.corpusVersionDigest,
            selectionIdentifier: d.selectionIdentifier,
            analyticalUnitIdentifier: d.analyticalUnitIdentifier,
            preprocessingIdentifiers: d.preprocessingIdentifiers,
            linguisticProfileIdentifiers: d.linguisticProfileIdentifiers,
            representationIdentifier: d.representationIdentifier,
            resolvedParameters: [
                "revision": .integer(Int64(state.revision)),
                "contentDigest": .text(try studyDigest(state)),
            ],
            seedPolicyIdentifier: d.seedPolicyIdentifier, backendIdentifier: d.backendIdentifier,
            numericPolicyIdentifier: d.numericPolicyIdentifier,
            determinismClass: d.determinismClass,
            outputSchemaIdentifier: d.outputSchemaIdentifier,
            softwareIdentifier: d.softwareIdentifier,
            dependencies: [
                try .init(
                    nodeID: previous.node.id, artifactDigest: previous.contentDigest,
                    outputSchemaIdentifier: d.outputSchemaIdentifier)
            ], sourceRevisionIDs: [])
    }

    private func requirement(_ url: URL) throws -> Int {
        try JSONDecoder().decode(
            GlifiProjectManifest.self, from: Data(contentsOf: url.appending(path: "manifest.json"))
        ).minimumReaderVersion
    }
}

private struct StudyTestPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.artifact.study-state.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let previousArtifactID: String?
    let state: GlifiStudyState
}
