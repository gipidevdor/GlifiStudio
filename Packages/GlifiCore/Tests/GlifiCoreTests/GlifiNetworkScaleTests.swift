// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

/// Values of one `INFO_BULK_*` line of the igraph oracle (Tests/Oracles/expected.txt).
private func bulkOracle(_ key: String) throws -> [Double] {
    let file = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Oracles/expected.txt")
    let line = try #require(
        try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
            .first { $0.hasPrefix("networks:\(key) ") }
    )
    return line.split(separator: " ").dropFirst().compactMap { Double($0) }
}

@Test("Cammini pesati e Louvain su 150 nodi e 600 archi coincidono con igraph")
func largeWeightedGraphMatchesIgraph() throws {
    // Oracolo: networks.R, sample_gnm(150, 600) con seed 42 e pesi uniformi in [0,1; 5].
    let raw = try bulkOracle("INFO_BULK_EDGES")
    #expect(raw.count == 1_800)
    var edges: [GlifiGraphEdge<Int>] = []
    for index in stride(from: 0, to: raw.count, by: 3) {
        let source = Int(raw[index])
        let target = Int(raw[index + 1])
        edges.append(GlifiGraphEdge(source: source, target: target, weight: raw[index + 2]))
        edges.append(GlifiGraphEdge(source: target, target: source, weight: raw[index + 2]))
    }
    let graph = try GlifiDirectedGraph(nodes: Array(0..<150), edges: edges)

    let betweenness = GlifiNetworkAnalysis.weightedBetweenness(graph)
    let expectedBetweenness = try bulkOracle("INFO_BULK_BETWEENNESS")
    for node in 0..<150 {
        // igraph conta una volta ogni coppia non ordinata.
        let value = betweenness.scores[node] ?? .nan
        #expect(abs(value - 2 * expectedBetweenness[node]) <= 1e-7 * max(1, value))
    }
    let harmonic = GlifiNetworkAnalysis.weightedHarmonicCloseness(graph)
    let expectedHarmonic = try bulkOracle("INFO_BULK_HARMONIC")
    for node in 0..<150 {
        #expect(abs((harmonic.scores[node] ?? .nan) - expectedHarmonic[node]) < 1e-9)
    }
    #expect(GlifiNetworkAnalysis.weakComponents(graph).componentCount == 1)
    let communities = try GlifiNetworkAnalysis.louvain(graph)
    let igraphQuality = try #require(try bulkOracle("INFO_BULK_LOUVAIN_Q").first)
    #expect(communities.modularity >= igraphQuality - 0.02)
    let recomputed = GlifiNetworkAnalysis.modularity(
        graph,
        communityByNode: communities.communityByNode
    )
    #expect(abs(recomputed - communities.modularity) < 1e-12)
}
