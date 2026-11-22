// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// BM25 query-size workloads; fixture construction and complete checksums are untimed.
func bm25SparseOptimizationMeasurements() throws -> [Measurement] {
    let columnCount = 4_096
    var measurements: [Measurement] = []
    do {
        let rows = bm25SparseRows(includingZerosAndEmptyRows: false)
        let lengths = rows.map { $0.values.reduce(0, +) }
        for queryCount in [4, 128, 1_024] {
            let query = Set((0..<queryCount).map { ($0 * 31) % columnCount })
            measurements.append(
                try bm25SparseMeasurement(
                    identifier: "bm25-sparse-query\(queryCount)-4000x4096",
                    rows: rows, columnCount: columnCount, lengths: lengths, query: query,
                    batchCount: queryCount == 4 ? 64 : 1,
                    recipe: "4000 rows, 64 positive cells/row, 256000 cells; query=(i*31)%4096"))
        }
        let outside = Set((0..<1_024).map { columnCount + $0 })
        measurements.append(
            try bm25SparseMeasurement(
                identifier: "bm25-sparse-oov-query1024-4000x4096",
                rows: rows, columnCount: columnCount, lengths: lengths, query: outside,
                batchCount: 256,
                recipe:
                    "same 256000 cells; requested query1024, effective query0; columns4096..<5120"))
        let mixed = Set((0..<512).map { ($0 * 31) % columnCount })
            .union((0..<512).map { columnCount + $0 })
        measurements.append(
            try bm25SparseMeasurement(
                identifier: "bm25-sparse-mixed-query1024-effective512-4000x4096",
                rows: rows, columnCount: columnCount, lengths: lengths, query: mixed,
                batchCount: 1,
                recipe: "same 256000 cells; 512 valid query columns plus 512 OOV columns"))
        measurements.append(
            try bm25SparseMeasurement(
                identifier: "bm25-sparse-valid-absent-query1024-4000x8192",
                rows: rows, columnCount: 8_192, lengths: lengths, query: outside,
                batchCount: 1,
                recipe:
                    "same stored columns0..<4096; declared8192; query4096..<5120 valid but absent"))
    }
    do {
        let rows = bm25SparseRows(includingZerosAndEmptyRows: true)
        let lengths = rows.map { $0.values.reduce(0, +) }
        let query = Set((0..<1_024).map { ($0 * 31) % columnCount })
        measurements.append(
            try bm25SparseMeasurement(
                identifier: "bm25-sparse-zero-empty-query1024-4000x4096",
                rows: rows, columnCount: columnCount, lengths: lengths, query: query,
                batchCount: 1,
                recipe:
                    "400 empty rows; 230400 stored cells including 79200 explicit zeros; 151200 positive cells; query=(i*31)%4096"
            ))
    }
    return measurements
}

private func bm25SparseRows(includingZerosAndEmptyRows: Bool) -> [[Int: Int]] {
    (0..<4_000).map { row in
        if includingZerosAndEmptyRows, row.isMultiple(of: 10) { return [:] }
        return Dictionary(
            uniqueKeysWithValues: (0..<64).map { offset in
                let count =
                    includingZerosAndEmptyRows && offset.isMultiple(of: 3)
                    ? 0 : (row + offset) % 7 + 1
                return ((row * 17 + offset * 61) % 4_096, count)
            })
    }
}

private func bm25SparseMeasurement(
    identifier: String, rows: [[Int: Int]], columnCount: Int, lengths: [Int], query: Set<Int>,
    batchCount: Int, recipe: String
) throws -> Measurement {
    let parameters = GlifiBM25Parameters.standard
    let input = BM25SparseInputDescription(
        methodIdentifier: "BM25-v1", documentCount: rows.count, columnCount: columnCount,
        documentLengths: lengths, queryColumns: query.sorted(), parameters: parameters,
        batchCount: batchCount, rowEncodingIdentifier: "sorted-column-count-pairs-v1")
    let inputDigest = try bm25SparseInputDigest(input, rows: rows)
    var scores: [Double] = []
    let batchTimes = try measure {
        for _ in 0..<batchCount {
            scores = try GlifiTermWeighting.bm25(
                rows: rows, columnCount: columnCount, documentLengths: lengths,
                queryColumns: query, parameters: parameters)
        }
    }
    // Report per-call time; the recipe and hashed input retain the fixed batch size.
    let callTimes = batchTimes.map { $0 / Double(batchCount) }
    let outputDigest = try bm25SparseDigest(
        BM25SparseScoreBits(
            count: scores.count, bitPatterns: scores.map(\.bitPattern)))
    return summary(
        identifier, "GS-MET-001-07",
        "\(recipe); k1=1.2/b=0.75; batch=\(batchCount); seconds per call; inputSHA256=\(inputDigest)",
        callTimes, check: outputDigest)
}

private struct BM25SparseInputDescription: Encodable {
    let methodIdentifier: String
    let documentCount: Int
    let columnCount: Int
    let documentLengths: [Int]
    let queryColumns: [Int]
    let parameters: GlifiBM25Parameters
    let batchCount: Int
    let rowEncodingIdentifier: String
}

private struct BM25SparseInputRow: Encodable {
    let columns: [Int]
    let counts: [Int]
}

private struct BM25SparseScoreBits: Encodable {
    let count: Int
    let bitPatterns: [UInt64]
}

private func bm25SparseInputDigest(
    _ description: BM25SparseInputDescription, rows: [[Int: Int]]
) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var hasher = SHA256()
    hasher.update(data: try encoder.encode(description))
    // Hash one row at a time to avoid retaining a JSON copy of the complete sparse matrix.
    for row in rows {
        let columns = row.keys.sorted()
        let value = BM25SparseInputRow(columns: columns, counts: columns.map { row[$0] ?? 0 })
        hasher.update(data: try encoder.encode(value))
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

private func bm25SparseDigest(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
}
