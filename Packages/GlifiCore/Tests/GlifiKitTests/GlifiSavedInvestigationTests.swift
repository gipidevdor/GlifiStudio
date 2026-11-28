// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore
@testable import GlifiKit

struct GlifiSavedInvestigationTests {
    @Test("Un'analisi acquisita crea una sola indagine descrittiva e conserva il piano e i limiti")
    func captureInvestigationIsDescriptiveAndIdempotent() async throws {
        let fixture = try await SavedInvestigationFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let result = try await fixture.session.createSavedAnalysisInvestigation(
            artifactID: fixture.saved.artifactID, question: "Quale output è stato acquisito?")
        let snapshot = try await fixture.session.snapshot()
        let repeated = try await fixture.session.createSavedAnalysisInvestigation(
            artifactID: fixture.saved.artifactID, question: "Quale output è stato acquisito?")
        #expect(repeated == result)
        #expect(try await fixture.session.snapshot() == snapshot)
        for (artifactID, question) in [
            (fixture.saved.artifactID, "   "),
            (result.investigation.planArtifactID, "Quale output?"),
        ] {
            do {
                _ = try await fixture.session.createSavedAnalysisInvestigation(
                    artifactID: artifactID, question: question)
                Issue.record("Expected invalid saved-output investigation request")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.category == "invalidInput")
            }
            #expect(try await fixture.session.snapshot() == snapshot)
        }
        #expect(result.investigation.selectedFindingIDs.count == 1)
        let project = try GlifiProjectPackage.open(at: fixture.projectURL)
        let payload = try await Self.interpretation(
            project: project, investigation: result.investigation)
        #expect(payload.interpretation.findings.count == 1)
        let finding = try #require(payload.interpretation.findings.first)
        #expect(finding.familyIdentifier == "saved-analysis-capture")
        #expect(finding.assessment.supportClass == .descriptive)
        #expect(finding.assessment.policyIdentifier == "saved-analysis-capture-v1")
        #expect(finding.rankFactors.effectMagnitude == nil)
        #expect(finding.rankFactors.coverage == nil)
        #expect(finding.caveats.contains { $0.identifier == "saved-analysis.no-method-validation" })
        #expect(
            finding.caveats.contains { $0.identifier == "saved-analysis.separate-plan-execution" })
        #expect(payload.interpretation.evidence[0].validity == .limited)
        #expect(
            payload.interpretation.evidence[0].measures.allSatisfy {
                !$0.identifier.contains("p-value") && !$0.identifier.contains("confidence")
            })
        #expect(
            payload.interpretation.evidence[0].artifactIDs.map(\.canonicalValue) == [
                fixture.saved.artifactID
            ])
        #expect(
            payload.interpretation.planArtifactID.canonicalValue
                == result.investigation.planArtifactID)
        let coreSnapshot = await project.snapshot()
        let interpretationRecord = try #require(
            coreSnapshot.artifacts.first {
                $0.artifactID.canonicalValue == result.investigation.interpretationArtifactID
            })
        #expect(interpretationRecord.node.descriptor.dependencies.count == 2)
        #expect(
            interpretationRecord.node.descriptor.dependencies.contains {
                $0.outputSchemaIdentifier == GlifiSavedResearchAnalysis.outputSchemaIdentifier
            })
        await fixture.session.close()
        let reopened = try await GlifiStudioService().openProject(at: fixture.projectURL)
        let restored = try await reopened.createSavedAnalysisInvestigation(
            artifactID: fixture.saved.artifactID, question: "Quale output è stato acquisito?")
        #expect(restored == result)
        await reopened.close()
    }

    @Test("L'export conserva i byte scientifici nell'allegato verificato e mostra limiti leggibili")
    func captureExportRoundTripAndTampering() async throws {
        let fixture = try await SavedInvestigationFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let investigation = try await fixture.session.createSavedAnalysisInvestigation(
            artifactID: fixture.saved.artifactID, question: "Quale output è disponibile?")
        let destination = fixture.root.appending(path: "Export")
        let receipt = try await fixture.session.exportInvestigation(
            .init(
                investigationHeadEventID: investigation.investigation.headEventID,
                formats: ["json", "markdown", "csv"]), to: destination)
        #expect(receipt.fileCount == 5)
        let manifest = try GlifiScientificExporter.verifyExport(at: destination)
        let companion = try #require(
            manifest.files.first {
                $0.schema == GlifiSavedResearchAnalysis.outputSchemaIdentifier
            })
        let bytes = try Data(contentsOf: destination.appending(path: companion.path))
        let payload = try JSONDecoder().decode(GlifiSavedResearchAnalysis.self, from: bytes)
        #expect(payload.requestJSON == fixture.saved.requestJSON)
        #expect(payload.resultJSON == fixture.saved.resultJSON)
        #expect(payload.preparationJSON == fixture.saved.preparationJSON)
        #expect(
            try GlifiSavedResearchReport.verify(data: bytes, path: companion.path).canonicalValue
                == fixture.saved.artifactID)
        let markdown = try String(
            contentsOf: destination.appending(path: "report.md"), encoding: .utf8)
        #expect(markdown.contains("Output del metodo"))
        #expect(markdown.contains("non certifica il metodo"))
        #expect(!markdown.contains("finding.saved-analysis.captured"))
        try Data("{}".utf8).write(to: destination.appending(path: companion.path))
        #expect(throws: GlifiFailure.self) {
            try GlifiScientificExporter.verifyExport(at: destination)
        }
        await fixture.session.close()
    }

    @Test("L'export di una selezione vuota non allega richieste o risultati non selezionati")
    func emptyEditorialSelectionDoesNotExportTheCapturedOutput() async throws {
        let fixture = try await SavedInvestigationFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let result = try await fixture.session.createSavedAnalysisInvestigation(
            artifactID: fixture.saved.artifactID, question: "Quale output è disponibile?")
        let empty = try await fixture.session.reviseInvestigationSelection(
            .init(
                investigationID: result.investigation.id,
                predecessorEventID: result.investigation.headEventID,
                selectedFindingIDs: [], reasonIdentifier: "explicit-empty-selection"))
        let destination = fixture.root.appending(path: "Empty")
        let receipt = try await fixture.session.exportInvestigation(
            .init(investigationHeadEventID: empty.investigation.headEventID), to: destination)
        #expect(receipt.fileCount == 2)
        let manifest = try GlifiScientificExporter.verifyExport(at: destination)
        #expect(!manifest.files.contains { GlifiSavedResearchReport.isFileName($0.path) })
        await fixture.session.close()
    }

    private static func interpretation(
        project: GlifiProjectPackage, investigation: GlifiStudioInvestigation
    ) async throws -> GlifiAnalysisInterpretationArtifactPayload {
        let data = try await project.artifactData(
            for: ArtifactID(canonicalValue: investigation.interpretationArtifactID))
        return try JSONDecoder().decode(GlifiAnalysisInterpretationArtifactPayload.self, from: data)
    }
}

private struct SavedInvestigationFixture {
    let root: URL
    let projectURL: URL
    let session: GlifiStudioProjectSession
    let saved: GlifiStudioSavedAnalysis

    static func create() async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiSavedInvestigation-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        do {
            let projectURL = root.appending(path: "Project.glifi")
            let session = try await GlifiStudioService().createProject(at: projectURL)
            let imported = try await session.importTabular(
                data: Data("id,testo\na,Città e mare\nb,Montagna e neve\n".utf8), options: .init(),
                mapping: .init(textColumns: [2], identifierColumn: 1))
            let saved = try await session.runSavedAnalysis(
                requestJSON: GlifiStudioTextAnalysisRequest.dissimilarities(
                    matrix: [[1, 0], [0, 1]], metric: .euclidean
                ).canonicalData(),
                title: "Distanze acquisite", sourceRevisionIDs: imported.sourceRevisionIDs)
            return Self(root: root, projectURL: projectURL, session: session, saved: saved)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}
