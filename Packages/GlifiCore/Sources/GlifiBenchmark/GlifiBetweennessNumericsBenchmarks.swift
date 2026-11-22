// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Ordinary Brandes workloads; complete checksums and graph construction are untimed.
func betweennessNumericsMeasurements() throws -> [Measurement] {
    var measurements: [Measurement] = []
    do {
        let identities = (0..<600).map { "node-\($0)" }
        let nodes = (0..<600).map { identities[($0 * 37) % 600] }
        var generator = GlifiSplitMix64(seed: 174)
        var edges: [GlifiGraphEdge<String>] = []
        for source in 0..<600 {
            edges.append(.init(source: identities[source], target: identities[(source + 1) % 600]))
            for _ in 0..<3 {
                edges.append(
                    .init(
                        source: identities[source], target: identities[generator.index(below: 600)])
                )
            }
        }
        measurements.append(
            try betweennessNumericsMeasurement(
                "betweenness-directed-sparse-600", nodes: nodes, edges: edges,
                recipe: "SplitMix64 seed174; ring plus 3 random directed targets per node; "
                    + "2400 ordered unit-weight edges; declared node i=(i*37)%600"))
    }
    do {
        let nodes = (0..<600).map { "node-\($0)" }
        let edges = (0..<599).map {
            GlifiGraphEdge(source: nodes[$0], target: nodes[$0 + 1])
        }
        measurements.append(
            try betweennessNumericsMeasurement(
                "betweenness-directed-chain-600", nodes: nodes, edges: edges,
                recipe: "600 ordered nodes and 599 forward unit-weight edges; one path per pair"))
    }
    do {
        let diamonds = 160
        let identities = (0..<(diamonds * 3 + 1)).map { "node-\($0)" }
        let nodes = identities.reversed().map { $0 }
        var edges: [GlifiGraphEdge<String>] = []
        for diamond in 0..<diamonds {
            let source = diamond * 3
            for branch in [source + 1, source + 2] {
                edges.append(.init(source: identities[source], target: identities[branch]))
                edges.append(.init(source: identities[branch], target: identities[source + 3]))
            }
        }
        measurements.append(
            try betweennessNumericsMeasurement(
                "betweenness-diamond-dag-160", nodes: nodes, edges: edges,
                recipe: "160 chained directed diamonds; 481 reverse-declared nodes, "
                    + "640 ordered unit-weight edges; largest path count 2^160 is finite"))
    }
    do {
        let identities = (0..<800).map { "node-\($0)" }
        let nodes = (0..<800).map { identities[($0 * 37) % 800] }
        var edges: [GlifiGraphEdge<String>] = []
        for component in 0..<20 {
            let base = component * 30
            let cyclic = component.isMultiple(of: 2)
            for offset in 0..<(cyclic ? 30 : 29) {
                edges.append(
                    .init(
                        source: identities[base + offset],
                        target: identities[base + (offset + 1) % 30],
                        weight: offset.isMultiple(of: 3) ? 0 : 1))
            }
            for offset in stride(from: 0, to: 30, by: 5) {
                if cyclic || offset + 7 < 30 {
                    edges.append(
                        .init(
                            source: identities[base + offset],
                            target: identities[base + (offset + 7) % 30], weight: 0))
                }
            }
            edges.append(.init(source: identities[base], target: identities[base], weight: 0))
            edges.append(.init(source: identities[base], target: identities[base + 1], weight: 3))
        }
        measurements.append(
            try betweennessNumericsMeasurement(
                "betweenness-components-800-isolates200", nodes: nodes, edges: edges,
                recipe: "20 disjoint components of30 nodes plus200 isolates; "
                    + "10 directed rings with6 +7 shortcuts and10 chains with5 +7 shortcuts; "
                    + "one zero self-loop and one parallel first edge per component; "
                    + "backbone weights offset%3==0 ? 0 : 1, shortcuts/self0, parallel3; "
                    + "740 ordered edges; declared node i=(i*37)%800"))
    }
    return measurements
}

private func betweennessNumericsMeasurement(
    _ identifier: String, nodes: [String], edges: [GlifiGraphEdge<String>], recipe: String
) throws -> Measurement {
    let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
    let inputDigest = betweennessNumericsInputChecksum(nodes, edges, recipe)
    var result: GlifiBetweennessResult<String>?
    let times = measure { result = GlifiNetworkAnalysis.betweenness(graph) }
    guard let result, result.scores.count == nodes.count else {
        throw BetweennessNumericsBenchmarkFailure.missingResult
    }
    var output = BetweennessNumericsChecksum()
    output.append(GlifiBetweennessResult<String>.identifier)
    output.append(UInt64(result.scores.count))
    for node in nodes {
        guard let score = result.scores[node] else {
            throw BetweennessNumericsBenchmarkFailure.missingResult
        }
        output.append(node)
        output.append(score.bitPattern)
    }
    return summary(
        identifier, "GS-MET-001-16, Betweenness-v1",
        recipe + "; warmups=1; samples=5; batch=1; inputSHA256=\(inputDigest)",
        times,
        check: "outputSHA256=\(output.digest); scoreCount=\(result.scores.count); "
            + "samplesSeconds=\(times.map { String($0) }.joined(separator: ","))")
}

private func betweennessNumericsInputChecksum(
    _ nodes: [String], _ edges: [GlifiGraphEdge<String>], _ recipe: String
) -> String {
    var checksum = BetweennessNumericsChecksum()
    checksum.append(GlifiBetweennessResult<String>.identifier)
    checksum.append(recipe)
    checksum.append(UInt64(nodes.count))
    for node in nodes { checksum.append(node) }
    checksum.append(UInt64(edges.count))
    for edge in edges {
        checksum.append(edge.source)
        checksum.append(edge.target)
        checksum.append(edge.weight.bitPattern)
    }
    return checksum.digest
}

private enum BetweennessNumericsBenchmarkFailure: Error {
    case missingResult
}

/// Length-prefixed UTF-8 and little-endian UInt64, including every binary64 bit pattern.
private struct BetweennessNumericsChecksum {
    private var bytes = Data()

    var digest: String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    mutating func append(_ value: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            bytes.append(UInt8((value >> shift) & 255))
        }
    }

    mutating func append(_ value: String) {
        append(UInt64(value.utf8.count))
        bytes.append(contentsOf: value.utf8)
    }
}
