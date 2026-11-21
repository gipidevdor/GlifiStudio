// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

func weightingRefinementMeasurements() throws -> [Measurement] {
    let columns = 4_096
    let rows: [[Int: Int]] = (0..<4_000).map { row in
        Dictionary(
            uniqueKeysWithValues: (0..<64).map { offset in
                ((row * 17 + offset * 61) % columns, (row + offset) % 7 + 1)
            })
    }
    let lengths = rows.map { $0.values.reduce(0, +) }
    let inputDigest = try weightingDigest(rows)
    let lengthsDigest = try weightingDigest(lengths)
    let scheme = GlifiTermWeightingScheme(
        termFrequency: .sublinear, inverseDocumentFrequency: .smooth, normalization: .l2)
    var weighted: [[Int: Double]] = []
    let times = try measure {
        weighted = try GlifiTermWeighting.weigh(rows: rows, columnCount: columns, scheme: scheme)
    }
    var results = [
        summary(
            "tfidf-4000x4096-nnz256000", "GS-MET-001-07",
            "modular sparse counts; sublinear/smooth/L2; inputSHA256=\(inputDigest)", times,
            check: try weightingDigest(weighted))
    ]
    let rawScheme = GlifiTermWeightingScheme(
        termFrequency: .raw, inverseDocumentFrequency: .none, normalization: .none)
    let rawTimes = try measure {
        weighted = try GlifiTermWeighting.weigh(rows: rows, columnCount: columns, scheme: rawScheme)
    }
    results.append(
        summary(
            "tf-raw-4000x4096-nnz256000", "GS-MET-001-07",
            "same sparse counts; raw/noIDF/noNorm; inputSHA256=\(inputDigest)", rawTimes,
            check: try weightingDigest(weighted)))
    for queryCount in [4, 128] {
        let query = Set((0..<queryCount).map { $0 * 31 })
        let queryDigest = try weightingDigest(query.sorted())
        var scores: [Double] = []
        let times = try measure {
            scores = try GlifiTermWeighting.bm25(
                rows: rows, columnCount: columns, documentLengths: lengths, queryColumns: query,
                parameters: .standard)
        }
        results.append(
            summary(
                "bm25-4000x4096-query\(queryCount)", "GS-MET-001-07",
                "same sparse counts; k1=1.2/b=0.75; inputSHA256=\(inputDigest); lengthsSHA256=\(lengthsDigest); querySHA256=\(queryDigest)",
                times,
                check: try weightingDigest(scores)))
    }
    return results
}

private func weightingDigest<Value: Encodable>(_ value: Value) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
}
