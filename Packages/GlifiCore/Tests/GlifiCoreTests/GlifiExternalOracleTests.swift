// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracoli esterni rieseguibili: Packages/GlifiCore/Tests/Oracles/R/networks.R (igraph 2.3.3) e
// multivariate.R (NMF 0.28), verificati da Scripts/check-oracles.py.

/// Archi del karate club di Zachary (make_graph("Zachary") di igraph, nodi da 0).
private let karateEdges: [Int] = [
    0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 10, 0, 11, 0, 12, 0, 13, 0, 17, 0, 19, 0, 21,
    0, 31, 1, 2, 1, 3, 1, 7, 1, 13, 1, 17, 1, 19, 1, 21, 1, 30, 2, 3, 2, 7, 2, 27, 2, 28, 2, 32, 2,
    9, 2, 8, 2, 13, 3, 7, 3, 12, 3, 13, 4, 6, 4, 10, 5, 6, 5, 10, 5, 16, 6, 16, 8, 30, 8, 32, 8, 33,
    9, 33, 13, 33, 14, 32, 14, 33, 15, 32, 15, 33, 18, 32, 18, 33, 19, 33, 20, 32, 20, 33, 22, 32,
    22, 33, 23, 25, 23, 27, 23, 32, 23, 33, 23, 29, 24, 25, 24, 27, 24, 31, 25, 31, 26, 29, 26, 33,
    27, 33, 28, 31, 28, 33, 29, 32, 29, 33, 30, 32, 30, 33, 31, 32, 31, 33, 32, 33,
]

private func undirected(
    _ nodes: [Int],
    _ edges: [(Int, Int, Double)]
) throws -> GlifiDirectedGraph<Int> {
    try GlifiDirectedGraph(
        nodes: nodes,
        edges: edges.flatMap {
            [
                GlifiGraphEdge(source: $0.0, target: $0.1, weight: $0.2),
                GlifiGraphEdge(source: $0.1, target: $0.0, weight: $0.2),
            ]
        }
    )
}

@Test("Modularità e qualità di Louvain coincidono con igraph sul karate club")
func louvainMatchesIgraphOnKarate() throws {
    let edges = stride(from: 0, to: karateEdges.count, by: 2).map {
        (karateEdges[$0], karateEdges[$0 + 1], 1.0)
    }
    let graph = try undirected(Array(0..<34), edges)
    // Partizione delle due fazioni storiche: modularity(g, faction) = 0,37146614069691.
    let faction = [
        1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 2, 1, 2, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2,
        2, 2, 2,
    ]
    let partition = Dictionary(
        uniqueKeysWithValues: faction.enumerated().map { ($0.offset, $0.element) })
    #expect(
        abs(GlifiNetworkAnalysis.modularity(graph, communityByNode: partition) - 0.37146614069691)
            < 1e-12)
    // cluster_louvain di igraph (seed 1) raggiunge Q = 0,418803418803419; Louvain-v1 deve
    // ottenere una partizione di qualità non inferiore di oltre 0,01.
    let result = try GlifiNetworkAnalysis.louvain(graph)
    #expect(result.modularity >= 0.418803418803419 - 0.01)
    let recomputed = GlifiNetworkAnalysis.modularity(graph, communityByNode: result.communityByNode)
    #expect(abs(recomputed - result.modularity) < 1e-12)
}

@Test("Cammini pesati, eigenvector pesata e componenti coincidono con igraph")
func weightedMeasuresMatchIgraph() throws {
    let graph = try undirected(
        [1, 2, 3, 4, 5, 6],
        [(1, 2, 3), (1, 3, 1), (2, 3, 1), (2, 4, 2), (3, 5, 4), (4, 5, 1), (4, 6, 2), (5, 6, 1)]
    )
    // igraph conta ogni coppia non ordinata una volta: il grafo simmetrico la conta due volte.
    let betweenness = GlifiNetworkAnalysis.weightedBetweenness(graph)
    let expectedBetweenness: [Int: Double] = [1: 0, 2: 4, 3: 4, 4: 4, 5: 4, 6: 0]
    for (node, value) in expectedBetweenness {
        #expect(abs((betweenness.scores[node] ?? .nan) - value) < 1e-12)
    }
    let harmonic = GlifiNetworkAnalysis.weightedHarmonicCloseness(graph)
    let expectedHarmonic: [Int: Double] = [1: 6.75, 2: 7.8, 3: 7.6, 4: 7, 5: 7.6, 6: 5.55]
    for (node, value) in expectedHarmonic {
        #expect(abs((harmonic.scores[node] ?? .nan) - value) < 1e-12)
    }
    let eigen = try GlifiNetworkAnalysis.eigenvectorCentrality(graph)
    #expect(abs(eigen.eigenvalue - 5.28244821900622) < 1e-10)
    let expectedEigen: [Int: Double] = [
        1: 0.643032926833461, 2: 0.798929379704591, 3: 1, 4: 0.645602149215938,
        5: 0.960121478117042, 6: 0.426189842893047,
    ]
    for (node, value) in expectedEigen {
        #expect(abs((eigen.scores[node] ?? .nan) - value) < 1e-10)
    }
    let split = GlifiNetworkAnalysis.modularity(
        graph,
        communityByNode: [1: 0, 2: 0, 3: 0, 4: 1, 5: 1, 6: 1]
    )
    #expect(abs(split - 0.0977777777777778) < 1e-12)

    let directed = try GlifiDirectedGraph(
        nodes: [1, 2, 3, 4, 5, 6, 7],
        edges: [(1, 2), (2, 3), (3, 1), (3, 4), (5, 6), (6, 5)].map {
            GlifiGraphEdge(source: $0.0, target: $0.1)
        }
    )
    #expect(GlifiNetworkAnalysis.weakComponents(directed).componentCount == 3)
    #expect(GlifiNetworkAnalysis.strongComponents(directed).componentCount == 4)
}

@Test("Lee–Seung coincide con NMF::nmf (lee, senza riscalatura) dagli stessi fattori")
func leeSeungMatchesNMFPackage() throws {
    let matrix: [[Double]] = [[1, 2, 0], [0, 1, 3], [1, 3, 3], [2, 1, 1]]
    let run = try GlifiMultivariateMethods.leeSeung(
        matrix,
        initialW: [[0.5, 0.2], [0.3, 0.9], [0.7, 0.4], [0.1, 0.6]],
        initialH: [[0.2, 0.8, 0.5], [0.6, 0.1, 0.9]],
        maximumIterations: 100,
        tolerance: -1
    )
    let expectedW: [Double] = [
        0.531384279399432, 1.68015004736501e-08, 2.98296813687695e-05, 0.964327786146612,
        0.504780836210703, 0.974442579996557, 0.460703575259226, 0.203947191041543,
    ]
    let expectedH: [Double] = [
        2.61206855209236, 3.13621085690436, 0.246575619045563, 5.47985216299489e-07,
        1.17341780659589, 3.05858645302801,
    ]
    for (value, reference) in zip(run.w.flatMap { $0 }, expectedW) {
        #expect(abs(value - reference) <= 1e-9 * max(1, abs(reference)))
    }
    for (value, reference) in zip(run.h.flatMap { $0 }, expectedH) {
        #expect(abs(value - reference) <= 1e-9 * max(1, abs(reference)))
    }
    #expect(run.history.count == 100)
    #expect(abs((run.history.last ?? .nan) - 1.65770396661443) < 1e-10)
}
