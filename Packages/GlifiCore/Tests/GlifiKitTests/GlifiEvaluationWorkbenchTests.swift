// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("La valutazione source-aware conserva i risultati e rifiuta offset dentro UTF-8")
func sourceAwareEvaluationChecksUnicodeBoundaries() async throws {
    let text = "città"
    let boundary = try await GlifiStudioEvaluationWorkbench.boundaries(
        gold: [[0, 6]], predicted: [[0, 4, 6]], texts: [text])
    let reference = try await GlifiStudioLinguisticEvaluation.boundaries(
        gold: [[0, 6]], predicted: [[0, 4, 6]], utf8Lengths: [6])
    #expect(boundary == reference)
    let gold: [[GlifiStudioEvaluationEntity]] = [[.init(lowerBound: 0, upperBound: 6, type: "LOC")]]
    let predicted: [[GlifiStudioEvaluationEntity]] = [
        [.init(lowerBound: 0, upperBound: 6, type: "ORG")]
    ]
    let entities = try await GlifiStudioEvaluationWorkbench.namedEntities(
        gold: gold, predicted: predicted, texts: [text])
    #expect(
        entities
            == (try await GlifiStudioLinguisticEvaluation.namedEntities(
                gold: gold, predicted: predicted, utf8Lengths: [6])))
    do {
        _ = try await GlifiStudioEvaluationWorkbench.boundaries(
            gold: [[5]], predicted: [[5]], texts: [text])
        Issue.record("A continuation byte must not become a Unicode boundary")
    } catch let failure {
        #expect(failure.category == "invalidInput")
    }
    do {
        _ = try await GlifiStudioEvaluationWorkbench.namedEntities(
            gold: [[.init(lowerBound: 0, upperBound: 5, type: "LOC")]],
            predicted: [[]], texts: [text])
        Issue.record("A continuation byte must not become an entity boundary")
    } catch let failure {
        #expect(failure.category == "invalidInput")
    }
}

@Test("La serie di progetto preserva metadati manuali, esposizione completa e zero token")
func projectTemporalEvaluationPreservesCompleteExposureAndZeroTokens() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiTemporalInput-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "Time.glifi"))
    let url = root.appending(path: "input.txt")
    try Data("!!!".utf8).write(to: url)
    let imported = try await session.importText(at: url, format: .plainText)
    let sourceID = try #require(imported.project.sources.first?.sourceRevisionID)
    let before = try await session.snapshot()
    let configuration = GlifiStudioTemporalConfiguration(
        basis: .civilDates, granularity: .month,
        origin: try .init(year: 2024, month: 1, day: 1), bucketWidth: 1, bucketCount: 2,
        missingPolicy: .separate, outsidePolicy: .exclude)
    let result = try await GlifiStudioEvaluationWorkbench.temporal(
        session: session,
        assignments: [
            .init(
                sourceRevisionID: sourceID, value: .civilMonth(year: 2024, month: 2),
                provenance: "manual.synthetic")
        ],
        terms: ["casa"], configuration: configuration)
    #expect(result.documents.first?.tokenCount == 0)
    #expect(result.documents.first?.metadataProvenance == "manual.synthetic")
    #expect(result.documents.first?.value == .civilMonth(year: 2024, month: 2))
    #expect(result.result.buckets[1].aggregate.documentCount == 1)
    #expect(result.result.buckets[1].aggregate.terms.first?.perThousandTokenRate == nil)
    #expect(result.contentDigests == imported.project.sources.map(\.contentDigest))
    #expect(try await session.snapshot() == before)
    do {
        _ = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: [sourceID])
        Issue.record("The exploratory default must still reject an empty lexical vocabulary")
    } catch let failure {
        #expect(failure.category == "invalidInput")
    }
    await session.close()
}

@Test("La cancellazione precede la valutazione degli input source-aware")
func sourceAwareEvaluationPreservesCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioEvaluationWorkbench.boundaries(
            gold: [], predicted: [], texts: [])
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
        #expect(failure.retainedState == "unchanged")
    } catch { Issue.record("Unexpected error: \(error)") }
}
