// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore
@testable import GlifiKit

struct GlifiResearchSavedIntegrityTests {
    @Test("Una versione booleana del risultato non viene interpretata come versione uno")
    func booleanSchemaVersionIsRejected() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let request = GlifiStudioTextAnalysisRequest.dissimilarities(
            matrix: [[1, 0], [0, 1]], metric: .euclidean)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        object["schemaVersion"] = true
        let bytes = try JSONSerialization.data(withJSONObject: object)
        let before = try await session.snapshot()
        await #expect(throws: GlifiStudioFailure.self) {
            _ = try await session.captureSavedAnalysis(
                requestJSON: request.canonicalData(), resultJSON: bytes,
                title: "Versione non valida", sourceRevisionIDs: [])
        }
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    @Test("Lo stato scientifico acquisito deve concordare con il registro del metodo")
    func capturedValidationStatusCannotBePromoted() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let request = GlifiStudioTextAnalysisRequest.dissimilarities(
            matrix: [[1, 0], [0, 1]], metric: .euclidean)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        object["validationStatus"] =
            result.validationStatus == "supported" ? "candidate" : "supported"
        let bytes = try JSONSerialization.data(withJSONObject: object)
        let before = try await session.snapshot()
        await #expect(throws: GlifiStudioFailure.self) {
            _ = try await session.captureSavedAnalysis(
                requestJSON: request.canonicalData(), resultJSON: bytes,
                title: "Stato non coerente", sourceRevisionIDs: [])
        }
        #expect(try await session.snapshot() == before)
        await session.close()
    }

    @Test("Un digest di preparazione estraneo non viene acquisito né modifica il progetto")
    func mismatchedPreparationDigestCannotBeCaptured() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let request = GlifiStudioTextAnalysisRequest.dissimilarities(
            matrix: [[1, 0], [0, 1]], metric: .euclidean)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        let before = try await session.snapshot()
        await #expect(throws: GlifiStudioFailure.self) {
            _ = try await session.saveCompletedAnalysis(
                request: request, result: result, title: "Distanze", sourceRevisionIDs: [],
                preparationDigest: "sha256:" + String(repeating: "0", count: 64),
                preparation: .init(stopwords: ["la"]))
        }
        #expect(try await session.snapshot() == before)
        #expect(try await session.savedAnalyses().isEmpty)
        await session.close()
    }

    @Test("L'acquisizione vincola il JSON di preparazione e conserva il runtime storico")
    func preparationBytesAndHistoricalRuntimeAreValidated() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).glifi")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = try await GlifiStudioService().createProject(at: url)
        let request = GlifiStudioTextAnalysisRequest.dissimilarities(
            matrix: [[1, 0], [0, 1]], metric: .euclidean)
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
        let preparation = GlifiStudioCorpusPreparation(base: .appleLemma)
        let saved = try await session.saveCompletedAnalysis(
            request: request, result: result, title: "Distanze", sourceRevisionIDs: [],
            preparation: preparation)
        let manifest = try JSONDecoder().decode(
            GlifiProjectManifest.self,
            from: Data(contentsOf: url.appending(path: "manifest.json")))
        #expect(manifest.minimumReaderVersion == 3)
        #expect(
            saved.preparationOperatingSystemVersion
                == ProcessInfo.processInfo.operatingSystemVersionString)
        let data = try await session.exportSavedAnalysis(artifactID: saved.artifactID)
        let payload = try JSONDecoder().decode(GlifiSavedResearchAnalysis.self, from: data)
        try payload.validate()
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let historicalRuntime = "historical-macOS-build-verified-fixture"
        object["preparationOperatingSystemVersion"] = historicalRuntime
        object["preparationDigest"] = try preparation.core().digest(
            operatingSystemVersion: historicalRuntime)
        let historical = try JSONDecoder().decode(
            GlifiSavedResearchAnalysis.self, from: JSONSerialization.data(withJSONObject: object))
        try historical.validate()
        #expect(try historical.contentDigest() != payload.contentDigest())
        object["preparationJSON"] = try JSONEncoder().encode(
            GlifiStudioCorpusPreparation(stopwords: ["alterata"])
        ).base64EncodedString()
        let mismatched = try JSONDecoder().decode(
            GlifiSavedResearchAnalysis.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(throws: GlifiFailure.self) { try mismatched.validate() }
        await session.close()
    }
}
