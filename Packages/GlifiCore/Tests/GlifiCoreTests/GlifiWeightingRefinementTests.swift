// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Le ponderazioni ottimizzate coincidono con la definizione densa per ogni variante")
func refinedWeightingMatchesDenseDefinition() throws {
    for seed in 1...4 {
        var generator = GlifiSplitMix64(seed: UInt64(seed))
        var dense = (0..<16).map { _ in (0..<12).map { _ in generator.index(below: 7) } }
        dense[0] = [Int](repeating: 1, count: 12)
        dense[15] = [Int](repeating: 0, count: 12)
        let rows = dense.map { values in
            Dictionary(
                uniqueKeysWithValues: values.enumerated().reversed().map { pair in
                    (pair.offset, pair.element)
                })
        }
        for tf in GlifiTermFrequencyVariant.allCases {
            for idf in GlifiInverseDocumentFrequencyVariant.allCases {
                for norm in GlifiRowNormalization.allCases {
                    let scheme = GlifiTermWeightingScheme(
                        termFrequency: tf, inverseDocumentFrequency: idf, normalization: norm)
                    let actual = try GlifiTermWeighting.weigh(
                        rows: rows, columnCount: 12, scheme: scheme)
                    let expected = denseWeightingReference(dense, scheme: scheme)
                    #expect(actual == expected)
                }
            }
        }
    }
}

@Test("Le ponderazioni rifiutano conteggi invalidi e overflow con failure tipizzate")
func refinedWeightingRejectsInvalidArithmetic() throws {
    let scheme = GlifiTermWeightingScheme(
        termFrequency: .raw, inverseDocumentFrequency: .none, normalization: .none)
    for (rows, columns) in [([[0: -1]], 1), ([[0: 1]], -1), ([[0: Int.max, 1: 1]], 2)] {
        #expect(throws: GlifiFailure.self) {
            try GlifiTermWeighting.weigh(rows: rows, columnCount: columns, scheme: scheme)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermWeighting.weigh(rows: [], columnCount: Int.max, scheme: scheme)
    }
    #expect(
        try GlifiTermWeighting.inverseDocumentFrequency(
            documentFrequency: Int.max, documentCount: Int.max, variant: .smooth) == 1)
    #expect(throws: GlifiFailure.self) {
        try GlifiTermWeighting.bm25(
            rows: [[0: 1], [0: 1]], columnCount: 1,
            documentLengths: [Int.max, 1], queryColumns: [0], parameters: .standard)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermWeighting.bm25(
            rows: [[0: 1], [0: 1]], columnCount: 1,
            documentLengths: [-1, 2], queryColumns: [0], parameters: .standard)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermWeighting.bm25(
            rows: [[0: -1]], columnCount: 1, documentLengths: [1], queryColumns: [0],
            parameters: .standard)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermWeighting.bm25(
            rows: [[0: 1]], columnCount: -1, documentLengths: [1], queryColumns: [0],
            parameters: .standard)
    }
}

@Test("BM25 conserva score finiti per k1 estremo senza azzerarli per overflow intermedio")
func refinedBM25PreservesExtremeFiniteParameters() throws {
    let scores = try GlifiTermWeighting.bm25(
        rows: [[0: 1], [0: 1]], columnCount: 1, documentLengths: [1, 3], queryColumns: [0],
        parameters: .init(k1: .greatestFiniteMagnitude, b: 1))
    #expect(abs(scores[0] - 0.36464311358790925) < 1e-12)
    #expect(abs(scores[1] - 0.12154770452930309) < 1e-12)
    let largerFrequency = try GlifiTermWeighting.bm25(
        rows: [[0: 10]], columnCount: 1, documentLengths: [10], queryColumns: [0],
        parameters: .init(k1: .greatestFiniteMagnitude, b: 0))
    #expect(abs(largerFrequency[0] - 2.8768207245178093) < 1e-12)
}

@Test("BM25 con buffer per colonna coincide bit per bit con la definizione diretta")
func refinedBM25MatchesDirectSparseDefinition() throws {
    for seed in 1...20 {
        var generator = GlifiSplitMix64(seed: UInt64(seed))
        let rows = (0..<24).map { _ in
            Dictionary(
                uniqueKeysWithValues: (0..<18).reversed().map { ($0, generator.index(below: 7)) })
        }
        let lengths = rows.map { $0.values.reduce(0, +) }
        let query = Set([-1, 2, 4, 5, 9, 17, 18])
        let columns = query.filter { $0 >= 0 && $0 < 18 }.sorted()
        let averageLength = Double(lengths.reduce(0, +)) / Double(lengths.count)
        for parameters in [GlifiBM25Parameters.standard, .init(k1: 0.01, b: 0), .init(k1: 8, b: 1)]
        {
            let actual = try GlifiTermWeighting.bm25(
                rows: rows, columnCount: 18, documentLengths: lengths,
                queryColumns: query, parameters: parameters)
            let expected = rows.enumerated().map { index, row in
                let lengthFactor =
                    1 - parameters.b + parameters.b * Double(lengths[index]) / averageLength
                return columns.reduce(0.0) { score, column in
                    let f = Double(row[column] ?? 0)
                    guard f > 0 else { return score }
                    let df = rows.filter { ($0[column] ?? 0) > 0 }.count
                    let idf = log(1 + (Double(rows.count - df) + 0.5) / (Double(df) + 0.5))
                    return score + idf * f * (parameters.k1 + 1)
                        / (f + parameters.k1 * lengthFactor)
                }
            }
            #expect(actual.map(\.bitPattern) == expected.map(\.bitPattern))
        }
    }
}

@Test("Le ponderazioni osservano cancellazione prima delle scansioni sparse")
func refinedWeightingCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiTermWeighting.weigh(
            rows: [[0: 1]], columnCount: 1,
            scheme: .init(
                termFrequency: .raw, inverseDocumentFrequency: .none, normalization: .none))
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    let bm25Task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiTermWeighting.bm25(
            rows: [[0: 1]], columnCount: 1, documentLengths: [1], queryColumns: [0],
            parameters: .standard)
    }
    await #expect(throws: CancellationError.self) { try await bm25Task.value }
}

// Direct dense formulas, independently ordered by integer column index.
private func denseWeightingReference(
    _ rows: [[Int]], scheme: GlifiTermWeightingScheme
) -> [[Int: Double]] {
    let columns = rows[0].count
    let frequencies = (0..<columns).map { column in rows.filter { $0[column] > 0 }.count }
    return rows.map { row in
        let sum = row.reduce(0, +)
        let maximum = row.max() ?? 0
        var values: [Int: Double] = [:]
        var norm = 0.0
        for column in 0..<columns where row[column] > 0 {
            let count = Double(row[column])
            let tf: Double
            switch scheme.termFrequency {
            case .raw: tf = count
            case .binary: tf = 1
            case .l1: tf = count / Double(sum)
            case .max: tf = count / Double(maximum)
            case .augmented: tf = 0.5 + 0.5 * count / Double(maximum)
            case .sublinear: tf = 1 + log(count)
            }
            let idf: Double
            switch scheme.inverseDocumentFrequency {
            case .none: idf = 1
            case .unsmoothed: idf = log(Double(rows.count) / Double(frequencies[column]))
            case .smooth:
                idf = log(Double(rows.count + 1) / Double(frequencies[column] + 1)) + 1
            }
            let weight = tf * idf
            values[column] = weight
            switch scheme.normalization {
            case .none: break
            case .l1: norm += abs(weight)
            case .l2: norm += weight * weight
            }
        }
        if scheme.normalization == .l2 { norm = norm.squareRoot() }
        if scheme.normalization != .none, norm > 0 { return values.mapValues { $0 / norm } }
        return values
    }
}
