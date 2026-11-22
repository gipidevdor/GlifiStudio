// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracolo: Tests/Oracles/R/weighting.R (righe TF_*, IDF_*, TFIDF_*, BM25_* di expected.txt).
private let weightingRows: [[Int: Int]] = [
    [0: 2, 1: 1],
    [0: 1, 1: 3, 2: 1],
    [0: 1, 3: 4],
    [:],
]

private func dense(_ rows: [[Int: Double]]) -> [Double] {
    rows.flatMap { row in (0..<4).map { row[$0] ?? 0 } }
}

private func expectClose(_ actual: [Double], _ expected: [Double]) {
    #expect(actual.count == expected.count)
    for (value, reference) in zip(actual, expected) {
        #expect(abs(value - reference) <= 1e-12 * max(1, abs(reference)))
    }
}

@Test("Le sei varianti TF coincidono con le formule indipendenti di R, riga vuota inclusa")
func termFrequencyVariantsMatchR() throws {
    let expected: [GlifiTermFrequencyVariant: [Double]] = [
        .raw: [2, 1, 0, 0, 1, 3, 1, 0, 1, 0, 0, 4, 0, 0, 0, 0],
        .binary: [1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0],
        .l1: [
            0.666666666666667, 0.333333333333333, 0, 0, 0.2, 0.6, 0.2, 0, 0.2, 0, 0, 0.8,
            0, 0, 0, 0,
        ],
        .max: [
            1, 0.5, 0, 0, 0.333333333333333, 1, 0.333333333333333, 0, 0.25, 0, 0, 1, 0, 0, 0, 0,
        ],
        .augmented: [
            1, 0.75, 0, 0, 0.666666666666667, 1, 0.666666666666667, 0, 0.625, 0, 0, 1, 0, 0, 0,
            0,
        ],
        .sublinear: [
            1.69314718055995, 1, 0, 0, 1, 2.09861228866811, 1, 0, 1, 0, 0, 2.38629436111989, 0,
            0, 0, 0,
        ],
    ]
    for variant in GlifiTermFrequencyVariant.allCases {
        let weighted = try GlifiTermWeighting.weigh(
            rows: weightingRows,
            columnCount: 4,
            scheme: GlifiTermWeightingScheme(
                termFrequency: variant, inverseDocumentFrequency: .none, normalization: .none)
        )
        expectClose(dense(weighted), try #require(expected[variant]))
    }
}

@Test("IDF, TF-IDF normalizzato L1/L2 e BM25-v1 coincidono con R")
func inverseDocumentFrequencyAndBM25MatchR() throws {
    expectClose(
        try (0..<4).map { column in
            try GlifiTermWeighting.inverseDocumentFrequency(
                documentFrequency: [3, 2, 1, 1][column], documentCount: 4, variant: .unsmoothed)
        },
        [0.287682072451781, 0.693147180559945, 1.38629436111989, 1.38629436111989]
    )
    expectClose(
        try (0..<4).map { column in
            try GlifiTermWeighting.inverseDocumentFrequency(
                documentFrequency: [3, 2, 1, 1][column], documentCount: 4, variant: .smooth)
        },
        [1.22314355131421, 1.51082562376599, 1.91629073187416, 1.91629073187416]
    )
    expectClose(
        dense(
            try GlifiTermWeighting.weigh(
                rows: weightingRows,
                columnCount: 4,
                scheme: GlifiTermWeightingScheme(
                    termFrequency: .sublinear, inverseDocumentFrequency: .unsmoothed,
                    normalization: .l2)
            )),
        [
            0.574954756247397, 0.818185204136873, 0, 0, 0.141720955756097, 0.716603535411419,
            0.682930848428619, 0, 0.0866357869415011, 0, 0, 0.996240051604545, 0, 0, 0, 0,
        ]
    )
    expectClose(
        dense(
            try GlifiTermWeighting.weigh(
                rows: weightingRows,
                columnCount: 4,
                scheme: GlifiTermWeightingScheme(
                    termFrequency: .augmented, inverseDocumentFrequency: .smooth,
                    normalization: .l1)
            )),
        [
            0.519103203316034, 0.480896796683966, 0, 0, 0.226270367248072, 0.419233378253134,
            0.354496254498794, 0, 0.28516764524685, 0, 0, 0.71483235475315, 0, 0, 0, 0,
        ]
    )
    expectClose(
        [3, 2, 1, 1].map {
            GlifiTermWeighting.bm25InverseDocumentFrequency(documentFrequency: $0, documentCount: 4)
        },
        [0.356674943938732, 0.693147180559945, 1.20397280432594, 1.20397280432594]
    )
    let lengths = weightingRows.map { $0.values.reduce(0, +) }
    // La colonna 99 è fuori vocabolario e contribuisce zero.
    expectClose(
        try GlifiTermWeighting.bm25(
            rows: weightingRows, columnCount: 4, documentLengths: lengths,
            queryColumns: [0, 2, 99], parameters: .standard),
        [0.501272894184165, 1.27892623496761, 0.292289495605953, 0]
    )
    expectClose(
        try GlifiTermWeighting.bm25(
            rows: weightingRows, columnCount: 4, documentLengths: lengths,
            queryColumns: [1, 3], parameters: GlifiBM25Parameters(k1: 2, b: 0)),
        [0.693147180559945, 1.2476649250079, 2.40794560865187, 0]
    )
}

@Test("Invarianti e precondizioni di GS-MET-001-07 falliscono con codici tipizzati")
func weightingInvariantsAndPreconditions() throws {
    for normalization in [GlifiRowNormalization.l1, .l2] {
        let weighted = try GlifiTermWeighting.weigh(
            rows: weightingRows,
            columnCount: 4,
            scheme: GlifiTermWeightingScheme(
                termFrequency: .raw, inverseDocumentFrequency: .smooth,
                normalization: normalization)
        )
        for row in weighted where !row.isEmpty {
            let norm =
                normalization == .l1
                ? row.values.reduce(0) { $0 + abs($1) }
                : row.values.reduce(0) { $0 + $1 * $1 }.squareRoot()
            #expect(abs(norm - 1) < 1e-12)
        }
        #expect(weighted[3].isEmpty)
    }
    // df = N: IDF non smussata nulla, smussata pari a uno, idf BM25 positiva e finita.
    #expect(
        try GlifiTermWeighting.inverseDocumentFrequency(
            documentFrequency: 4, documentCount: 4, variant: .unsmoothed) == 0)
    #expect(
        try GlifiTermWeighting.inverseDocumentFrequency(
            documentFrequency: 4, documentCount: 4, variant: .smooth) == 1)
    let saturated = GlifiTermWeighting.bm25InverseDocumentFrequency(
        documentFrequency: 4, documentCount: 4)
    #expect(saturated > 0 && saturated.isFinite)
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiTermWeighting.inverseDocumentFrequency(
            documentFrequency: 0, documentCount: 4, variant: .unsmoothed)
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiTermWeighting.bm25(
            rows: weightingRows, columnCount: 4, documentLengths: [3, 5, 5, 0],
            queryColumns: [0], parameters: GlifiBM25Parameters(k1: 0, b: 0.75))
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiTermWeighting.bm25(
            rows: [[:]], columnCount: 4, documentLengths: [0],
            queryColumns: [0], parameters: .standard)
    }
}

@Test("Pesi e ranking BM25 si persistono come Artifact riusabili con query normalizzata")
func termWeightingAndBM25ArePersistedAndReused() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiTermWeighting-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    var ids: [SourceRevisionID] = []
    for (index, text) in ["Il mare e il porto.", "Porto, porto e mare aperto.", "La valle."]
        .enumerated()
    {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index + 1)")
        )
        _ = try await project.importText(imported)
        ids.append(imported.sourceRevisionID)
    }
    let scheme = GlifiTermWeightingScheme(
        termFrequency: .sublinear, inverseDocumentFrequency: .smooth, normalization: .l2)
    let weighting = try await engine.analyzeTermWeighting(
        in: project, sourceRevisionIDs: ids, scheme: scheme)
    let reused = try await engine.analyzeTermWeighting(
        in: project, sourceRevisionIDs: ids, scheme: scheme)
    #expect(reused.artifactID == weighting.artifactID)
    #expect(weighting.value.combinedIdentifier == "TFIDF-v1")

    let ranking = try await engine.rankDocumentsBM25(
        in: project, sourceRevisionIDs: ids, query: "PORTO Mare nebbia")
    let sameQuery = try await engine.rankDocumentsBM25(
        in: project, sourceRevisionIDs: ids, query: "mare porto porto nebbia")
    #expect(sameQuery.artifactID == ranking.artifactID)
    #expect(ranking.value.queryTerms.map(\.term) == ["mare", "nebbia", "porto"])
    #expect(ranking.value.queryTerms.map(\.isInVocabulary) == [true, false, true])
    let scores = ranking.value.ranking.map(\.score)
    #expect(scores == scores.sorted(by: >))
    #expect(ranking.value.ranking.last?.score == 0)
    await #expect(throws: GlifiFailure.self) {
        _ = try await engine.rankDocumentsBM25(
            in: project, sourceRevisionIDs: ids, query: " , . ")
    }
}
