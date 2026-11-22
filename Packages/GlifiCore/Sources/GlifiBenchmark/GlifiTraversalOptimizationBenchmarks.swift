// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Bounded harmonic-centrality workloads; fixture setup and complete hashes are untimed.
func graphTraversalOptimizationMeasurements() throws -> [Measurement] {
    var measurements: [Measurement] = []
    do {
        let identities = (0..<600).map { "node-\($0)" }
        let nodes = (0..<600).map { identities[($0 * 37) % 600] }
        var generator = GlifiSplitMix64(seed: 173)
        var edges: [GlifiGraphEdge<String>] = []
        edges.reserveCapacity(3_600)
        for source in 0..<600 {
            for offset in 0..<6 {
                let target = offset == 0 ? (source + 1) % 600 : generator.index(below: 600)
                edges.append(
                    GlifiGraphEdge(
                        source: identities[source], target: identities[target],
                        weight: offset.isMultiple(of: 3) ? 0 : Double(offset)))
            }
        }
        measurements.append(
            try traversalMeasurement(
                "harmonic-sparse-600x3600", nodes: nodes, edges: edges,
                recipe:
                    "SplitMix64 seed173; 600 nodes, 3600 ordered edges; ring plus 5 random targets/source; "
                    + "weights offset%3==0 ? 0 : offset; declared node i=(i*37)%600"))
    }
    do {
        let identities = (0..<1_000).map { "node-\($0)" }
        let nodes = (0..<1_000).map { identities[($0 * 37) % 1_000] }
        var edges: [GlifiGraphEdge<String>] = []
        for source in 0..<1_000 {
            if source + 1 < 1_000 {
                edges.append(
                    GlifiGraphEdge(source: identities[source], target: identities[source + 1]))
            }
            if source.isMultiple(of: 11), source + 7 < 1_000 {
                edges.append(
                    GlifiGraphEdge(
                        source: identities[source], target: identities[source + 7], weight: 0))
            }
            if source > 0, source.isMultiple(of: 17) {
                edges.append(
                    GlifiGraphEdge(source: identities[source], target: identities[source / 2]))
            }
        }
        measurements.append(
            try traversalMeasurement(
                "harmonic-irregular-chain-1000", nodes: nodes, edges: edges,
                recipe:
                    "1000-node forward chain; zero-weight shortcut +7 every11; back-edge to floor(i/2) every17; "
                    + "declared node i=(i*37)%1000"))
    }
    do {
        let identities = (0..<1_200).map { "node-\($0)" }
        let nodes = (0..<1_200).map { identities[($0 * 37) % 1_200] }
        var edges: [GlifiGraphEdge<String>] = []
        for component in 0..<30 {
            let base = component * 30
            for offset in 0..<30 {
                let source = identities[base + offset]
                edges.append(
                    GlifiGraphEdge(source: source, target: identities[base + (offset + 1) % 30]))
                edges.append(
                    GlifiGraphEdge(
                        source: source, target: identities[base + (offset + 7) % 30], weight: 0))
            }
            edges.append(
                GlifiGraphEdge(source: identities[base], target: identities[base], weight: 0))
            for weight in [2.0, 3.0] {
                edges.append(
                    GlifiGraphEdge(
                        source: identities[base], target: identities[base + 1], weight: weight))
            }
        }
        measurements.append(
            try traversalMeasurement(
                "harmonic-components-1200-isolates300", nodes: nodes, edges: edges,
                recipe:
                    "30 directed components of30 nodes (ring/+7 jump), 300 isolates, 1890 ordered edges; "
                    + "zero-weight jumps/self-loops and parallel ring edges; declared node i=(i*37)%1200"
            ))
    }
    return measurements
}

private func traversalMeasurement(
    _ identifier: String, nodes: [String], edges: [GlifiGraphEdge<String>], recipe: String
) throws -> Measurement {
    let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
    let batchCount = 1
    var input = TraversalBenchmarkChecksum()
    input.append("harmonic-traversal-input-v1")
    input.append(GlifiHarmonicClosenessResult<String>.identifier)
    input.append(identifier)
    input.append(recipe)
    input.append(UInt64(batchCount))
    input.append(UInt64(1))  // Warm-up batches.
    input.append(UInt64(5))  // Timed batches.
    input.append(UInt64(nodes.count))
    for node in nodes { input.append(node) }
    input.append(UInt64(edges.count))
    for edge in edges {
        input.append(edge.source)
        input.append(edge.target)
        input.append(edge.weight.bitPattern)
    }
    let inputDigest = input.digest
    var result: GlifiHarmonicClosenessResult<String>?
    let times = measure {
        for _ in 0..<batchCount {
            result = GlifiNetworkAnalysis.harmonicCloseness(graph)
        }
    }.map { $0 / Double(batchCount) }
    guard let result, result.scores.count == nodes.count else {
        throw TraversalBenchmarkFailure.missingResult
    }
    var output = TraversalBenchmarkChecksum()
    output.append("harmonic-traversal-output-v1")
    output.append(UInt64(nodes.count))
    for node in nodes {
        guard let score = result.scores[node] else { throw TraversalBenchmarkFailure.missingResult }
        output.append(node)
        output.append(score.bitPattern)
    }
    return summary(
        identifier, "GS-MET-001-16",
        recipe
            + "; HarmonicCloseness-v1; batch=\(batchCount); warm-up=1; samples=5; seconds per call; inputSHA256=\(inputDigest)",
        times, check: "outputSHA256=\(output.digest); scoreCount=\(result.scores.count)")
}

private enum TraversalBenchmarkFailure: Error {
    case missingResult
}

private struct TraversalBenchmarkChecksum {
    private var bytes = Data()

    var digest: String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    mutating func append(_ integer: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            bytes.append(UInt8((integer >> shift) & 255))
        }
    }

    mutating func append(_ text: String) {
        append(UInt64(text.utf8.count))
        bytes.append(contentsOf: text.utf8)
    }
}
