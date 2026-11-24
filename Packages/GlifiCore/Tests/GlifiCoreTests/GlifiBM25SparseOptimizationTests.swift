// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("BM25 adattivo conserva ogni bit del riferimento diretto per query piccole e grandi")
func bm25SparsePathsMatchDirectReference() throws {
    let rows = bm25SparseTestRows()
    let lengths = rows.map { $0.values.reduce(0, +) }
    for queryCount in [4, 128, 1_024] {
        let query = Set((0..<queryCount).map { ($0 * 31) % 2_048 })
        for parameters in [GlifiBM25Parameters.standard, .init(k1: 2, b: 0), .init(k1: 0.1, b: 1)] {
            let expected = bm25SparseDirectReference(
                rows, lengths: lengths, query: query, parameters: parameters)
            let actual = try GlifiTermWeighting.bm25(
                rows: rows, columnCount: 2_048, documentLengths: lengths,
                queryColumns: query, parameters: parameters)
            #expect(actual.map(\.bitPattern) == expected.map(\.bitPattern))
        }
    }
}

@Test("Le posting BM25 conservano DF, conteggi e ordine crescente delle righe")
func bm25SparsePostingsPreserveCountsAndOrder() throws {
    let rows = bm25SparseTestRows()
    let columns = Set((0..<1_024).map { ($0 * 31) % 2_048 }).sorted()
    let builtPostings = try GlifiBM25QueryPostings.build(
        rows: rows, columns: columns, policy: .standard)
    let postings = try #require(builtPostings)
    #expect(postings.offsets.count == columns.count + 1)
    #expect(postings.rowIndices.count == postings.frequencies.count)
    for (position, column) in columns.enumerated() {
        let expectedRows = rows.indices.filter { (rows[$0][column] ?? 0) > 0 }
        let range = postings.offsets[position]..<postings.offsets[position + 1]
        #expect(Array(postings.rowIndices[range]) == expectedRows)
        #expect(Array(postings.frequencies[range]) == expectedRows.map { rows[$0][column] ?? 0 })
    }
    let reserved = 256 * columns.count + 2 * MemoryLayout<Int>.stride * postings.rowIndices.count
    #expect(reserved <= GlifiBM25PostingsPolicy.maximumTemporaryByteCount)
    #expect(postings.rowIndices.count <= GlifiBM25PostingsPolicy.maximumPostingCount)
    #expect(
        try GlifiBM25QueryPostings.build(rows: rows, columns: [0, 1, 2, 3], policy: .standard)
            == nil)
    let dense: [[Int: Int]] = (0..<8).map { _ in
        Dictionary(uniqueKeysWithValues: (0..<128).map { ($0, 1) })
    }
    #expect(
        try GlifiBM25QueryPostings.build(rows: dense, columns: Array(0..<128), policy: .standard)
            == nil)
}

@Test("Il fallback BM25 per memoria o hit insufficienti non cambia i risultati ammessi")
func bm25SparseBudgetFallsBackWithoutChangingResults() throws {
    let rows = bm25SparseTestRows()
    let lengths = rows.map { $0.values.reduce(0, +) }
    let query = Set((0..<1_024).map { ($0 * 31) % 2_048 })
    let columns = query.sorted()
    let expected = bm25SparseDirectReference(
        rows, lengths: lengths, query: query, parameters: .standard)
    for policy in [
        GlifiBM25PostingsPolicy(temporaryByteLimit: 1),
        .init(postingCountLimit: 0),
        .init(
            temporaryByteLimit: 256 * columns.count + 6 * MemoryLayout<Int>.stride,
            postingCountLimit: 3),
        .init(temporaryByteLimit: -1),
        .init(temporaryByteLimit: GlifiBM25PostingsPolicy.maximumTemporaryByteCount + 1),
        .init(postingCountLimit: GlifiBM25PostingsPolicy.maximumPostingCount + 1),
    ] {
        #expect(
            try GlifiBM25QueryPostings.build(rows: rows, columns: columns, policy: policy) == nil)
        let actual = try GlifiTermWeighting.bm25(
            rows: rows, columnCount: 2_048, documentLengths: lengths,
            queryColumns: query, parameters: .standard, postingsPolicy: policy)
        #expect(actual.map(\.bitPattern) == expected.map(\.bitPattern))
    }
    #expect(
        try GlifiBM25QueryPostings.build(rows: rows, columns: Array(0..<32_769), policy: .standard)
            == nil)
}

@Test("La scelta BM25 confronta DQ e 4C senza overflow e con soglia stretta")
func bm25SparseCostComparisonUsesFullWidth() {
    #expect(
        !GlifiBM25QueryPostings.favorsPostings(
            documentCount: 4, queryCount: 128, storedCellCount: 128))
    #expect(
        GlifiBM25QueryPostings.favorsPostings(
            documentCount: 5, queryCount: 128, storedCellCount: 128))
    #expect(
        !GlifiBM25QueryPostings.favorsPostings(
            documentCount: Int.max, queryCount: 1, storedCellCount: Int.max))
    #expect(
        GlifiBM25QueryPostings.favorsPostings(
            documentCount: Int.max, queryCount: 8, storedCellCount: Int.max))
    #expect(
        GlifiBM25QueryPostings.favorsPostings(
            documentCount: Int.max, queryCount: Int.max, storedCellCount: Int.max))
    #expect(
        !GlifiBM25QueryPostings.favorsPostings(
            documentCount: 0, queryCount: 128, storedCellCount: 0))
    #expect(
        !GlifiBM25QueryPostings.favorsPostings(
            documentCount: 1, queryCount: 128, storedCellCount: -1))
}

@Test("BM25 distingue zeri, query assenti, OOV e conteggi negativi non interrogati")
func bm25SparseZeroOOVAndNegativeSemantics() throws {
    let query = Set(0..<128)
    let lengths = [Int](repeating: 20, count: 16)
    let rows: [[Int: Int]] = (0..<16).map { index in
        index.isMultiple(of: 4) ? [:] : [index: index.isMultiple(of: 3) ? 0 : 2, 500: -7]
    }
    let mixed = query.union([-1, Int.max, 1_024])
    let expected = bm25SparseDirectReference(
        rows, lengths: lengths, query: query, parameters: .standard)
    let actual = try GlifiTermWeighting.bm25(
        rows: rows, columnCount: 1_024,
        documentLengths: lengths, queryColumns: mixed, parameters: .standard)
    #expect(actual.map(\.bitPattern) == expected.map(\.bitPattern))
    let builtAbsent = try GlifiBM25QueryPostings.build(
        rows: rows, columns: Array(256..<384), policy: .standard)
    let absent = try #require(builtAbsent)
    #expect(absent.rowIndices.isEmpty)
    #expect(absent.offsets.allSatisfy { $0 == 0 })
    for columns in [Set<Int>(), Set([Int.max, -1]), Set(256..<384)] {
        #expect(
            try GlifiTermWeighting.bm25(
                rows: rows, columnCount: 1_024,
                documentLengths: lengths, queryColumns: columns, parameters: .standard
            ).allSatisfy { $0.bitPattern == 0 })
    }
    var invalid = rows
    invalid[2][0] = -1
    for policy in [GlifiBM25PostingsPolicy.standard, .init(temporaryByteLimit: 0)] {
        do {
            _ = try GlifiTermWeighting.bm25(
                rows: invalid, columnCount: 1_024,
                documentLengths: lengths, queryColumns: query, parameters: .standard,
                postingsPolicy: policy)
            Issue.record("Expected queried negative-count failure")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "bm25.negative-count")
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTermWeighting.bm25(
            rows: rows, columnCount: 1_024,
            documentLengths: Array(repeating: 0, count: rows.count), queryColumns: query,
            parameters: .standard)
    }
}

@Test("BM25 sparso mantiene il recupero finito per k1 estremo")
func bm25SparsePreservesExtremeFiniteParameters() throws {
    let rows = bm25SparseTestRows()
    let lengths = rows.map { $0.values.reduce(0, +) }
    let query = Set((0..<1_024).map { ($0 * 31) % 2_048 })
    for b in [0.0, 1.0] {
        let parameters = GlifiBM25Parameters(k1: .greatestFiniteMagnitude, b: b)
        let actual = try GlifiTermWeighting.bm25(
            rows: rows, columnCount: 2_048,
            documentLengths: lengths, queryColumns: query, parameters: parameters)
        let expected = bm25SparseDirectReference(
            rows, lengths: lengths, query: query, parameters: parameters)
        #expect(actual.allSatisfy { $0.isFinite })
        #expect(actual.map(\.bitPattern) == expected.map(\.bitPattern))
    }
}

@Test("BM25 propaga cancellazione per query dirette, posting e fallback bounded")
func bm25SparseCancellationPropagates() async {
    let rows = bm25SparseTestRows()
    let lengths = rows.map { $0.values.reduce(0, +) }
    for queryCount in [4, 1_024] {
        for policy in [GlifiBM25PostingsPolicy.standard, .init(temporaryByteLimit: 0)] {
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try GlifiTermWeighting.bm25(
                    rows: rows, columnCount: 2_048,
                    documentLengths: lengths, queryColumns: Set(0..<queryCount),
                    parameters: .standard,
                    postingsPolicy: policy)
            }
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }
}

private func bm25SparseTestRows() -> [[Int: Int]] {
    var generator = GlifiSplitMix64(seed: 172)
    return (0..<64).map { row in
        guard !row.isMultiple(of: 11) else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: (0..<16).map { offset in
                ((row * 17 + offset * 61) % 2_048, generator.index(below: 7))
            })
    }
}

// Independent row-major definition: queried DF first, then ascending query sums per row.
private func bm25SparseDirectReference(
    _ rows: [[Int: Int]], lengths: [Int], query: Set<Int>, parameters: GlifiBM25Parameters
) -> [Double] {
    let columns = query.sorted()
    let average = Double(lengths.reduce(0, +)) / Double(lengths.count)
    let idf = columns.map { column in
        let df = rows.filter { ($0[column] ?? 0) > 0 }.count
        return log(1 + (Double(rows.count - df) + 0.5) / (Double(df) + 0.5))
    }
    return rows.enumerated().map { index, row in
        let lengthFactor = 1 - parameters.b + parameters.b * Double(lengths[index]) / average
        var score = 0.0
        for (position, column) in columns.enumerated() {
            let count = row[column] ?? 0
            guard count > 0 else { continue }
            let frequency = Double(count)
            let numerator = idf[position] * frequency * (parameters.k1 + 1)
            let denominator = frequency + parameters.k1 * lengthFactor
            if numerator.isFinite, denominator.isFinite {
                score += numerator / denominator
            } else {
                let scale = max(frequency, parameters.k1)
                let k1 = parameters.k1 / scale
                score +=
                    (idf[position] * frequency) * (k1 + 1 / scale)
                    / (frequency / scale + k1 * lengthFactor)
            }
        }
        return score
    }
}
