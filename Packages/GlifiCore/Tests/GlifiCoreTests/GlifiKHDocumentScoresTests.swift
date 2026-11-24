// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("KH document scores match independent base-ten R formulas and retain every contribution")
func khDocumentScoreBaseROracle() throws {
    let counts: [[Double]] = [[1, 2, 3], [0, 4, 1]]
    let expected: [(GlifiKHDocumentScoreMode, [[Double]], [Double])] = [
        (.tf, [[0.1, 0.2, 0.3], [0, 0.2, 0.05]], [0.6, 0.25]),
        (
            .tfIdf,
            [[0.1, 0.060205999132796242, 0], [0, 0.060205999132796242, 0]],
            [0.160205999132796262, 0.060205999132796242]
        ),
        (
            .tfDividedByIdf,
            [[0.1, 0.6643856189774725, 0.3], [0, 0.6643856189774725, 0.05]],
            [1.06438561897747253, 0.71438561897747255]
        ),
    ]
    for (mode, terms, scores) in expected {
        let result = try GlifiKHDocumentScores.score(
            counts: counts, exposures: [10, 20], documentFrequencies: [1, 5, 10],
            corpusDocumentCount: 10, mode: mode)
        khDocumentScoreClose(result.termContributions.flatMap { $0 }, terms.flatMap { $0 })
        khDocumentScoreClose(result.scores, scores)
        khDocumentScoreClose(result.inverseDocumentFrequencies, [1, 0.3010299956639812, 0])
        #expect(result.methodIdentifier == mode.methodIdentifier)
        #expect(result.exposures == [10, 20])
        #expect(result.documentFrequencies == [1, 5, 10])
        #expect(result.corpusDocumentCount == 10)
        #expect(
            try JSONDecoder().decode(
                GlifiKHDocumentScoreResult.self, from: JSONEncoder().encode(result)) == result)
    }
}

@Test("KH document scores use full exposures and corpus DF rather than selected-row statistics")
func khDocumentScoreExternalExposureAndSubset() throws {
    let single = try GlifiKHDocumentScores.score(
        counts: [[1]], exposures: [100], documentFrequencies: [5], corpusDocumentCount: 10,
        mode: .tfDividedByIdf)
    khDocumentScoreClose(single.scores, [0.03321928094887362])
    let changed = try GlifiKHDocumentScores.score(
        counts: [[1], [1]], exposures: [100, 200], documentFrequencies: [5],
        corpusDocumentCount: 10,
        mode: .tfDividedByIdf)
    #expect(changed.scores[0] == single.scores[0])
    #expect(changed.scores[1] == single.scores[0] / 2)
    let ubiquitous = try GlifiKHDocumentScores.score(
        counts: [[1]], exposures: [10], documentFrequencies: [10], corpusDocumentCount: 10,
        mode: .tfDividedByIdf)
    #expect(ubiquitous.inverseDocumentFrequencies == [0])
    #expect(ubiquitous.scores == [0.1])
    #expect(
        try GlifiKHDocumentScores.score(
            counts: [[1]], exposures: [10], documentFrequencies: [10], corpusDocumentCount: 10,
            mode: .tfIdf
        ).scores == [0])
}

@Test("KH document scores retain tiny positive IDF and recover representable scaled contributions")
func khDocumentScoreExtremeScales() throws {
    let result = try GlifiKHDocumentScores.score(
        counts: [[1]], exposures: [1], documentFrequencies: [Int.max - 1],
        corpusDocumentCount: Int.max, mode: .tfDividedByIdf)
    #expect(result.inverseDocumentFrequencies[0] > 0)
    #expect(result.scores[0] > 1e19)
    #expect(result.scores[0].isFinite)
    #expect(
        try GlifiKHDocumentScores.score(
            counts: [[.leastNonzeroMagnitude]], exposures: [1], documentFrequencies: [1],
            corpusDocumentCount: 1, mode: .tf
        ).scores == [.leastNonzeroMagnitude])
    let recovered = try GlifiKHDocumentScores.score(
        counts: [[1e-320]], exposures: [1e20], documentFrequencies: [Int.max - 1],
        corpusDocumentCount: Int.max, mode: .tfDividedByIdf)
    #expect(recovered.scores[0] > 0)
    #expect(recovered.scores[0] < 1e-320)
    for (count, exposure) in [
        (Double.greatestFiniteMagnitude, Double.leastNonzeroMagnitude),
        (Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiKHDocumentScores.score(
                counts: [[count]], exposures: [exposure], documentFrequencies: [1],
                corpusDocumentCount: 1, mode: .tf)
        }
    }
}

@Test("KH document scores reject invalid shape, frequencies, exposures and exhausted budgets")
func khDocumentScoreAdmission() throws {
    for (counts, exposures, frequencies, total) in [
        ([[Double]](), [Double](), [Int](), 10),
        ([[]], [1], [], 10),
        ([[1], [1, 2]], [1, 1], [1], 10),
        ([[1]], [], [1], 10),
        ([[1]], [0], [1], 10),
        ([[1]], [.infinity], [1], 10),
        ([[.nan]], [1], [1], 10),
        ([[-1]], [1], [1], 10),
        ([[1]], [1], [0], 10),
        ([[1]], [1], [11], 10),
        ([[1]], [1], [1], 0),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiKHDocumentScores.score(
                counts: counts, exposures: exposures, documentFrequencies: frequencies,
                corpusDocumentCount: total, mode: .tf)
        }
    }
    for limits in [GlifiExploratoryLimits(maximumCells: 5), .init(maximumWork: 6)] {
        #expect(throws: GlifiFailure.self) {
            try GlifiKHDocumentScores.score(
                counts: [[1]], exposures: [1], documentFrequencies: [1],
                corpusDocumentCount: 1, mode: .tf, limits: limits)
        }
    }
    #expect(
        try GlifiKHDocumentScores.score(
            counts: [[1]], exposures: [1], documentFrequencies: [1],
            corpusDocumentCount: 1, mode: .tf,
            limits: .init(maximumCells: 6, maximumWork: 7)
        ).scores == [1])
}

@Test("KH document scores check cancellation before validating or allocating")
func khDocumentScoreCancellation() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiKHDocumentScores.score(
            counts: [[1]], exposures: [1], documentFrequencies: [1],
            corpusDocumentCount: 1, mode: .tf)
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled document scoring unexpectedly completed")
    } catch is CancellationError {
    }
}

private func khDocumentScoreClose(_ actual: [Double], _ expected: [Double]) {
    #expect(actual.count == expected.count)
    for (value, reference) in zip(actual, expected) {
        #expect(abs(value - reference) <= 1e-13 * max(1, abs(reference)))
    }
}
