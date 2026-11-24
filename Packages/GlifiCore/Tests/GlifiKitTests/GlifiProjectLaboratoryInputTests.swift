// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

private func laboratoryProject() async throws -> (
    root: URL, session: GlifiStudioProjectSession, markdownID: String, textID: String
) {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiLaboratory-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    do {
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Laboratory.glifi", directoryHint: .isDirectory))
        let markdownURL = root.appending(path: "source.md")
        try Data("# Casa\nUna **casa**.".utf8).write(to: markdownURL)
        let first = try await session.importText(at: markdownURL, format: .markdown)
        let markdownID = try #require(first.project.sources.first?.sourceRevisionID)
        let textURL = root.appending(path: "source.txt")
        try Data("Mare mare luna.".utf8).write(to: textURL)
        let second = try await session.importText(at: textURL, format: .plainText)
        let textID = try #require(
            second.project.sources.first { $0.sourceRevisionID != markdownID }?.sourceRevisionID)
        return (root, session, markdownID, textID)
    } catch {
        try? FileManager.default.removeItem(at: root)
        throw error
    }
}

@Test("Il laboratorio usa testo estratto e token nativi, senza mutare il progetto")
func laboratoryInputUsesExtractedTextAndCompleteTokens() async throws {
    let fixture = try await laboratoryProject()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let before = try await fixture.session.snapshot()
    let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
        session: fixture.session,
        sourceRevisionIDs: [fixture.textID, fixture.markdownID], maximumTermCount: 2)
    #expect(input.sourceRevisionIDs == [fixture.textID, fixture.markdownID].sorted())
    #expect(input.projectID == before.projectID)
    #expect(input.generation == before.generation)
    #expect(input.terms == ["casa", "mare"])
    #expect(input.vocabularySize == 4)
    #expect(input.lexicalTokenCount == 6)
    let markdown = try #require(input.sourceRevisionIDs.firstIndex(of: fixture.markdownID))
    let text = try #require(input.sourceRevisionIDs.firstIndex(of: fixture.textID))
    #expect(input.documents[markdown] == ["casa", "una", "casa"])
    #expect(input.documents[text] == ["mare", "mare", "luna"])
    #expect(!input.codingUnits[markdown].text.contains("**"))
    #expect(!input.codingUnits[markdown].text.contains("#"))
    #expect(input.matrix[markdown] == [2, 0])
    #expect(input.matrix[text] == [0, 2])
    #expect(
        input.contentDigests
            == input.sourceRevisionIDs.map { id in
                before.sources.first { $0.sourceRevisionID == id }?.contentDigest ?? ""
            })
    #expect(try await fixture.session.snapshot() == before)
    await fixture.session.close()
}

@Test("Il laboratorio rifiuta ambiti e limiti invalidi senza risultato parziale")
func laboratoryInputRejectsInvalidScopeAndBounds() async throws {
    let fixture = try await laboratoryProject()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let cases: [(ids: [String], terms: Int)] = [
        ([], 200), ([fixture.textID, fixture.textID], 200),
        (["not-a-project-revision"], 200), ([fixture.textID], 0),
        ([fixture.textID], 1_001),
    ]
    for item in cases {
        do {
            _ = try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: fixture.session, sourceRevisionIDs: item.ids,
                maximumTermCount: item.terms)
            Issue.record("Era atteso il rifiuto di ambito o limite")
        } catch let failure {
            #expect(failure.category == "invalidInput")
            #expect(failure.retainedState == "unchanged")
        }
    }
    await fixture.session.close()
}

@Test("La cancellazione degli input del laboratorio resta tipizzata")
func laboratoryInputCancellationIsTyped() async throws {
    let fixture = try await laboratoryProject()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let operation = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: fixture.session, sourceRevisionIDs: [fixture.textID])
    }
    do {
        _ = try await operation.value
        Issue.record("Era attesa la cancellazione")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
        #expect(failure.retainedState == "unchanged")
    }
    await fixture.session.close()
}

@Test("I payload nativi e i nomi dei codici preservano il trasporto JSON esistente")
func nativeLaboratoryPayloadRetainsWireContract() async throws {
    let mds = try await GlifiStudioTextAnalytics.executeTextAnalysis(
        .mds(matrix: [[0, 1], [1, 0]], dimensions: 1))
    guard case let .mds(payload) = mds.payload else {
        Issue.record("Payload MDS assente")
        return
    }
    #expect(payload.coordinates.count == 2)
    let coding = try await GlifiStudioTextAnalytics.code(
        [GlifiStudioAutomaticCodingUnit(id: "a", text: "mare")], rules: "*Mare\nmare")
    let table = try coding.crosstab(groups: ["A"])
    #expect(table.codes == ["Mare"])
    let encoded = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(table)) as? [String: Any])
    #expect(Set(encoded.keys) == ["groups", "counts", "sizes", "missingCount"])
    #expect(table.counts == [[1]])
}
