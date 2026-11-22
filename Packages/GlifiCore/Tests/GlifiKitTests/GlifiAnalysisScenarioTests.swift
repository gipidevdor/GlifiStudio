// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

private struct AnalysisScenarioProject {
    let root: URL
    let projectURL: URL
    let session: GlifiStudioProjectSession
    let markdownURL: URL
    let revisionIDs: [String]
}

private func withAnalysisScenarioProject(
    _ body: (AnalysisScenarioProject) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiAnalysisScenario-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Scenario.glifi", directoryHint: .isDirectory)
    let session = try await GlifiStudioService().createProject(at: projectURL)
    do {
        let markdownURL = root.appending(path: "markdown.data")
        let plainURL = root.appending(path: "plain.data")
        try Data("# Città\n**casa** mare.".utf8).write(to: markdownURL)
        try Data("casa casa sole.".utf8).write(to: plainURL)
        let first = try await session.importText(at: markdownURL, format: .markdown)
        let markdownID = try #require(first.project.sources.first?.sourceRevisionID)
        let second = try await session.importText(at: plainURL, format: .plainText)
        let plainID = try #require(
            second.project.sources.first { $0.sourceRevisionID != markdownID }?.sourceRevisionID)
        try await body(
            .init(
                root: root, projectURL: projectURL, session: session, markdownURL: markdownURL,
                revisionIDs: [markdownID, plainID]))
        await session.close()
    } catch {
        await session.close()
        throw error
    }
}

@Test("Scenario: importazione, matrici, distanze e codifica conservano dati e progetto")
func analysisScenarioImportedProjectFeedsPureFamiliesWithoutMutation() async throws {
    try await withAnalysisScenarioProject { fixture in
        let before = try await fixture.session.snapshot()
        let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: fixture.session, sourceRevisionIDs: Array(fixture.revisionIDs.reversed()))
        try #require(input.sourceRevisionIDs == fixture.revisionIDs.sorted())
        try #require(
            input.documents.count == 2 && input.matrix.count == 2 && input.codingUnits.count == 2
                && input.contentDigests.count == 2)
        #expect(input.projectID == before.projectID)
        #expect(input.generation == before.generation)
        #expect(input.terms == ["casa", "città", "mare", "sole"])
        #expect(input.vocabularySize == 4)
        #expect(input.lexicalTokenCount == 6)
        for (index, id) in input.sourceRevisionIDs.enumerated() {
            let markdown = id == fixture.revisionIDs[0]
            #expect(
                input.documents[index]
                    == (markdown ? ["città", "casa", "mare"] : ["casa", "casa", "sole"]))
            #expect(input.matrix[index] == (markdown ? [1, 1, 1, 0] : [2, 0, 0, 1]))
            #expect(input.codingUnits[index].id == id)
            #expect(!input.codingUnits[index].text.contains("**"))
            #expect(!input.codingUnits[index].text.contains("#"))
            #expect(
                input.contentDigests[index]
                    == before.sources.first { $0.sourceRevisionID == id }?.contentDigest)
        }

        let rate = try await GlifiStudioKHAnalysis.execute(
            .perThousand(matrix: input.matrix, exposures: input.documents.map { Double($0.count) }))
        guard case let .advanced(.kh(.matrix(rates))) = rate.payload else {
            Issue.record("Expected the complete per-thousand matrix")
            return
        }
        try #require(rates.count == input.matrix.count)
        try #require(rates.allSatisfy { $0.count == input.terms.count })
        for (row, values) in rates.enumerated() {
            #expect(abs(values.reduce(0, +) - 1_000) < 1e-12)
            for (column, value) in values.enumerated() {
                #expect(abs(value - input.matrix[row][column] * 1_000 / 3) < 1e-12)
            }
        }
        let standardized = try await GlifiStudioKHAnalysis.execute(
            .sampleZScores(matrix: input.matrix, axis: .columns))
        guard case let .advanced(.kh(.matrix(zScores))) = standardized.payload else {
            Issue.record("Expected the complete sample-standardized matrix")
            return
        }
        try #require(zScores.count == 2)
        try #require(zScores.allSatisfy { $0.count == input.terms.count })
        for column in input.terms.indices {
            let values = zScores.map { $0[column] }
            #expect(abs(values.reduce(0, +)) < 1e-12)
            #expect(abs(values.reduce(0) { $0 + $1 * $1 } - 1) < 1e-12)
        }
        let distances = try await GlifiStudioTextAnalytics.dissimilarities(
            input.matrix, metric: .jaccard)
        try #require(distances.count == 2)
        try #require(distances.allSatisfy { $0.count == 2 })
        #expect(distances[0][0] == 0)
        #expect(distances[1][1] == 0)
        #expect(distances[0][1] == 0.75)
        #expect(distances[1][0] == 0.75)

        let coding = try await GlifiStudioTextAnalytics.code(
            input.codingUnits, rules: "*Acqua\nmare\n*Luce\nsole\n*Luogo\ncittà")
        try #require(coding.documentIDs == input.sourceRevisionIDs)
        try #require(coding.values.count == 2 && coding.values.allSatisfy { $0.count == 3 })
        try #require(coding.evidence.count == 2 && coding.evidence.allSatisfy { $0.count == 3 })
        #expect(coding.codes == ["Acqua", "Luce", "Luogo"])
        #expect(coding.frequencies == [1, 1, 1])
        for (row, id) in coding.documentIDs.enumerated() {
            #expect(coding.values[row] == (id == fixture.revisionIDs[0] ? [1, 0, 1] : [0, 1, 0]))
            let bytes = Array(input.codingUnits[row].text.utf8)
            for (code, expected) in ["mare", "sole", "città"].enumerated() {
                #expect(coding.evidence[row][code].isEmpty == (coding.values[row][code] == 0))
                for range in coding.evidence[row][code] {
                    try #require(
                        range.start >= 0 && range.end <= bytes.count && range.start < range.end)
                    let slice = String(
                        decoding: bytes[range.start..<range.end], as: UTF8.self)
                    #expect(slice.lowercased() == expected)
                }
            }
        }
        let crosstab = try coding.crosstab(
            groups: input.sourceRevisionIDs.map { $0 == fixture.revisionIDs[0] ? "Markdown" : nil })
        #expect(crosstab.groups == ["Markdown"])
        #expect(crosstab.codes == coding.codes)
        #expect(crosstab.counts == [[1, 0, 1]])
        #expect(crosstab.sizes == [1])
        #expect(crosstab.missingCount == 1)
        #expect(try await fixture.session.snapshot() == before)
    }
}

// Cache reads retain the complete analytical payload but report the requesting generation.
private func associationExpectedAtSnapshot(
    _ value: GlifiStudioAssociationResult, snapshot: GlifiStudioProjectSnapshot
) throws -> GlifiStudioAssociationResult {
    var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    var lineage = try #require(object["lineage"] as? [String: Any])
    lineage["sourceGeneration"] = snapshot.generation
    lineage["generation"] = snapshot.generation
    object["lineage"] = lineage
    return try JSONDecoder().decode(
        GlifiStudioAssociationResult.self,
        from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
}

@Test("Scenario: riapertura, riuso e aggiornamento mantengono le revisioni analizzate")
func analysisScenarioPersistedReuseDistinguishesHistoricalRevisions() async throws {
    try await withAnalysisScenarioProject { fixture in
        let original = try await fixture.session.analyzeAssociation(
            sourceRevisionIDs: fixture.revisionIDs)
        #expect(original.sourceRevisionIDs == fixture.revisionIDs.sorted())
        #expect(original.totalObservations == 6)
        #expect(original.includedTermCount == 4)
        #expect(original.degreesOfFreedom == 3)
        // Rows [1, 1, 1, 0] and [2, 0, 0, 1] have margins [3, 1, 1, 1], giving χ² = 10/3.
        #expect(abs(original.chiSquareStatistic - 10.0 / 3) < 1e-12)
        let persisted = try await fixture.session.snapshot()
        await fixture.session.close()
        let reopened = try await GlifiStudioService().openProject(at: fixture.projectURL)
        do {
            #expect(try await reopened.snapshot() == persisted)
            let reused = try await reopened.analyzeAssociation(
                sourceRevisionIDs: Array(fixture.revisionIDs.reversed()))
            #expect(reused == (try associationExpectedAtSnapshot(original, snapshot: persisted)))
            #expect(try await reopened.snapshot() == persisted)
            let frozen = try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: reopened, sourceRevisionIDs: fixture.revisionIDs)
            do {
                _ = try await reopened.analyzeAssociation(
                    sourceRevisionIDs: [fixture.revisionIDs[0], "not-a-project-revision"])
                Issue.record("An invalid persisted analysis must not reach a commit")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.category == "invalidInput")
            }
            #expect(try await reopened.snapshot() == persisted)

            try Data("# Città\n**sole** sole.".utf8).write(to: fixture.markdownURL)
            let imported = try await reopened.importText(at: fixture.markdownURL, format: .markdown)
            let updatedID = try #require(
                imported.project.sources.first {
                    !fixture.revisionIDs.contains($0.sourceRevisionID)
                }?.sourceRevisionID)
            #expect(imported.project.sourceCount == 3)
            let historical = try await reopened.analyzeAssociation(
                sourceRevisionIDs: fixture.revisionIDs)
            #expect(
                historical
                    == (try associationExpectedAtSnapshot(original, snapshot: imported.project)))
            #expect(try await reopened.snapshot() == imported.project)
            let stillFrozen = try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: reopened, sourceRevisionIDs: fixture.revisionIDs)
            #expect(stillFrozen.sourceRevisionIDs == frozen.sourceRevisionIDs)
            #expect(stillFrozen.contentDigests == frozen.contentDigests)
            #expect(stillFrozen.documents == frozen.documents)
            #expect(stillFrozen.matrix == frozen.matrix)
            let updated = try await reopened.analyzeAssociation(
                sourceRevisionIDs: [updatedID, fixture.revisionIDs[1]])
            #expect(updated.sourceRevisionIDs == [updatedID, fixture.revisionIDs[1]].sorted())
            #expect(updated.lineage.artifactID != original.lineage.artifactID)
            #expect(updated.lineage.analysisNodeID != original.lineage.analysisNodeID)
            #expect(updated.corpusDigest != original.corpusDigest)
            #expect(updated.includedTermCount == 3)
            #expect(updated.degreesOfFreedom == 2)
            let final = try await reopened.snapshot()
            await reopened.close()
            try FileManager.default.removeItem(at: fixture.markdownURL)
            let offline = try await GlifiStudioService().openProject(at: fixture.projectURL)
            do {
                #expect(try await offline.snapshot() == final)
                let oldCached = try await offline.analyzeAssociation(
                    sourceRevisionIDs: fixture.revisionIDs)
                let newCached = try await offline.analyzeAssociation(
                    sourceRevisionIDs: [updatedID, fixture.revisionIDs[1]])
                #expect(oldCached == (try associationExpectedAtSnapshot(original, snapshot: final)))
                #expect(newCached == (try associationExpectedAtSnapshot(updated, snapshot: final)))
                let oldSource = try await offline.sourceText(
                    sourceRevisionID: fixture.revisionIDs[0])
                let newSource = try await offline.sourceText(sourceRevisionID: updatedID)
                #expect(oldSource.text == "# Città\n**casa** mare.")
                #expect(newSource.text == "# Città\n**sole** sole.")
                #expect(try await offline.snapshot() == final)
                await offline.close()
            } catch {
                await offline.close()
                throw error
            }
        } catch {
            await reopened.close()
            throw error
        }
    }
}

private enum AnalysisScenarioBoundary: String, CaseIterable, Sendable {
    case typed, json
}

private struct AnalysisScenarioFixture: Sendable, CustomStringConvertible {
    let id: String
    let request: GlifiStudioTextAnalysisRequest
    let canonical: Data
    var description: String { id }
}

private func analysisScenarioFixtures() throws -> [AnalysisScenarioFixture] {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    let url = root.appending(path: "Fixtures/TextAnalysis/v1/cases.json")
    let fixture = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    let cases = try #require(fixture["cases"] as? [[String: Any]])
    #expect(!cases.isEmpty)
    return try cases.map { item in
        let id = try #require(item["id"] as? String)
        let fields = try #require(item["request"] as? [String: Any])
        let raw = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        let request = try GlifiStudioTextAnalysisRequest.decode(raw)
        return .init(id: id, request: request, canonical: try request.canonicalData())
    }
}

@Test(
    "Scenario: ogni fixture analitica annullata termina prima di calcolo e pubblicazione",
    arguments: try analysisScenarioFixtures(), AnalysisScenarioBoundary.allCases)
private func analysisScenarioEveryFixturePreservesPreCancellation(
    fixture: AnalysisScenarioFixture, boundary: AnalysisScenarioBoundary
) async throws {
    let operation = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        switch boundary {
        case .typed: return try await GlifiStudioTextAnalytics.executeTextAnalysis(fixture.request)
        case .json:
            return try await GlifiStudioTextAnalytics.executeTextAnalysis(json: fixture.canonical)
        }
    }
    do {
        _ = try await operation.value
        Issue.record("Cancelled scenario published a result: \(fixture.id), \(boundary.rawValue)")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "operation.cancelled")
        #expect(failure.category == "cancelled")
        #expect(failure.operation == "analyze")
        #expect(failure.retryDisposition == "newRequest")
        #expect(failure.retainedState == "unchanged")
        #expect(failure.arguments.isEmpty)
    }
}
