// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiResearchSessionTests {
    @Test("Filtri testuali e metadati selezionano gli stessi documenti anche con NOT")
    func combinedSelectionUsesCompleteSourcePredicates() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Test.glifi"))
        for (index, text) in ["casa mare", "casa montagna", "casa cielo"].enumerated() {
            let url = root.appending(path: "\(index).txt")
            try Data(text.utf8).write(to: url)
            _ = try await session.importText(at: url, format: .plainText)
        }
        let snapshot = try await session.snapshot()
        let ids = snapshot.sources.map(\.sourceRevisionID)
        var state = GlifiStudioResearchState(
            fields: [.init(id: "area", label: "Area", type: .text)],
            records: ids.map { .init(sourceRevisionID: $0, values: ["area": .text("Nord")]) },
            subsets: [.init(id: "tutte", label: "Tutte", sourceRevisionIDs: ids)])
        state = try await session.saveResearchState(state, expectedRevision: 0)
        #expect(state.revision == 1)
        let negative = try await session.selectResearchSources(
            .init(
                subsetID: "tutte", fieldID: "area", value: .text("Nord"),
                query: "NOT normalized:mare"))
        #expect(negative.count == 2)
        let positive = try await session.selectResearchSources(
            .init(
                fieldID: "area", value: .text("Nord"), query: "normalized:mare"))
        #expect(positive.count == 1)
        #expect(Set(negative).isDisjoint(with: positive))
        #expect(Set(negative + positive) == Set(ids))
        await session.close()
        let restored = try await GlifiStudioService().openProject(
            at: root.appending(path: "Test.glifi"))
        #expect(try await restored.researchState() == state)
        await restored.close()
    }

    @Test("La configurazione applicativa preserva il contratto italiano e i parametri")
    func applicationStateRoundTripsWithoutCoreTypes() throws {
        let original = GlifiStudioResearchState(
            preparation: .init(
                base: .italianSnowballStem, stopwords: ["di"], includedTerms: ["città"],
                excludedTerms: ["rumore"], compounds: ["città metropolitana"]))
        let decoded = try JSONDecoder().decode(
            GlifiStudioResearchState.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(try decoded.preparation.digest() == original.preparation.digest())
        #expect(try decoded.preparation.digest() != GlifiStudioCorpusPreparation().digest())
    }
}
