// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("Facciata lessicale: osservazioni, fit e descrittive riproducibili")
func lexicalStatisticsFacade() async throws {
    let distribution = try await GlifiStudioLexicalStatistics.observe(
        [.init(id: "source", tokens: ["a", "a", "a", "b"])], checkpoints: [1, 4],
        preprocessingIdentifier: "keys-v1")
    #expect(distribution.documentIDs == ["source"])
    #expect(distribution.terms == ["a", "b"] && distribution.counts == [3, 1])
    #expect(distribution.vocabularySizes == [1, 2])
    let zipf = try await GlifiStudioLexicalStatistics.fitZipf(distribution, ranks: 1...2)
    #expect(abs(zipf.coefficient - 3) < 1e-12)
    #expect(abs(zipf.exponent - 1.58496250072116) < 1e-12)
    let heaps = try await GlifiStudioLexicalStatistics.fitHeaps(distribution)
    #expect(abs(heaps.exponent - 0.5) < 1e-12)
    let summary = try await GlifiStudioLexicalStatistics.summarize(
        [1, nil, 3], unitIdentifier: "tokens-v1", variance: .sample)
    #expect(summary.mean == 2 && summary.missingCount == 1)
    #expect(abs(try #require(summary.variance) - 2) < 1e-12)
    let object = try #require(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(distribution)) as? [String: Any])
    #expect(object["documentTokenCounts"] as? [Int] == [4])
    #expect(object["methodIdentifier"] as? String == "LexicalDistribution-ordered-v1")
    await #expect(throws: GlifiStudioFailure.self) {
        try await GlifiStudioLexicalStatistics.observe(
            [.init(id: "source", tokens: ["a"])], checkpoints: [2],
            preprocessingIdentifier: "keys-v1")
    }
}

@Test("Facciata lessicale: cancellazione tradotta nella tassonomia condivisa")
func lexicalFacadeCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioLexicalStatistics.summarize(
            [1, 2], unitIdentifier: "tokens-v1", variance: .population)
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled analysis completed")
    } catch let error as GlifiStudioFailure {
        #expect(error.category == "cancelled")
        #expect(error.retainedState == "unchanged")
    } catch {
        Issue.record("Unexpected cancellation error: \(error)")
    }
}
