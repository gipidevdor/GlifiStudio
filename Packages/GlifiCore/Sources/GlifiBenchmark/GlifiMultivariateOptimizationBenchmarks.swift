// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

func multivariateOptimizationMeasurements() throws -> [Measurement] {
    var generator = GlifiSplitMix64(seed: 169)
    let points = (0..<400).map { _ in
        (0..<12).map { _ in Double(generator.index(below: 10_000)) / 10_000 }
    }
    let inputDigest = try multivariateBenchmarkDigest(points)
    var results: [Measurement] = []
    for linkage in [GlifiLinkage.single, .average, .ward] {
        var tree: GlifiHierarchicalClustering?
        let times = try measure {
            tree = try GlifiMultivariateMethods.hierarchicalClustering(points, linkage: linkage)
        }
        let checksum = try multivariateBenchmarkDigest(tree)
        results.append(
            summary(
                "hac-\(linkage.rawValue)-400x12", "GS-MET-001-14",
                "SplitMix64-v1 seed169; 400x12 counts mod10000/10000; inputSHA256=\(inputDigest)",
                times,
                check: checksum))
    }
    let clustered: [[Double]] = (0..<4_000).map { row in
        let location = Double((row % 8) * 10)
        return (0..<24).map { column -> Double in
            let residue = (row * 31 + column * 17) % 101
            return location + Double(residue) / 101.0
        }
    }
    var kMeans: GlifiKMeansResult?
    let times = try measure {
        kMeans = try GlifiMultivariateMethods.kMeans(
            clustered, clusterCount: 8, seed: 169, restarts: 2, maximumIterations: 60)
    }
    results.append(
        summary(
            "kmeans-4000x24-k8-r2", "GS-MET-001-14",
            "8 separated groups; modular grid; seed169; inputSHA256=\(try multivariateBenchmarkDigest(clustered))",
            times,
            check: try multivariateBenchmarkDigest(kMeans)))
    return results
}

private func multivariateBenchmarkDigest<Value: Encodable>(_ value: Value) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
}
