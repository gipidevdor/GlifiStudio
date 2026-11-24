// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private func symmetricGraph(
    _ nodes: [String],
    _ edges: [(String, String, Double)]
) throws -> GlifiDirectedGraph<String> {
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

@Test("L'eigenvector centrality coincide con eigen() di R, anche su un grafo bipartito")
func eigenvectorCentralityMatchesR() throws {
    // Oracolo: R 4.6.0, eigen(A), vettore principale scalato al massimo 1.
    let weighted = try symmetricGraph(
        ["a", "b", "c", "d"],
        [("a", "b", 2), ("a", "c", 1), ("b", "c", 1), ("b", "d", 1), ("c", "d", 3)]
    )
    let result = try GlifiNetworkAnalysis.eigenvectorCentrality(weighted)
    #expect(result.converged)
    #expect(abs(result.eigenvalue - 4.11753166928908) < 1e-10)
    let expected = [
        "a": 0.613335309520413, "b": 0.762713780421759, "c": 1, "d": 0.913827526448972,
    ]
    for (node, value) in expected {
        #expect(abs((result.scores[node] ?? .nan) - value) < 1e-10)
    }

    // Cammino di 5 nodi (bipartito): autovalore √3, vettore ½, √3/2, 1, √3/2, ½.
    let path = try symmetricGraph(
        ["1", "2", "3", "4", "5"],
        [("1", "2", 1), ("2", "3", 1), ("3", "4", 1), ("4", "5", 1)]
    )
    let pathResult = try GlifiNetworkAnalysis.eigenvectorCentrality(path)
    #expect(abs(pathResult.eigenvalue - 3.0.squareRoot()) < 1e-10)
    #expect(abs((pathResult.scores["2"] ?? .nan) - 3.0.squareRoot() / 2) < 1e-10)
    #expect(abs((pathResult.scores["1"] ?? .nan) - 0.5) < 1e-10)
}

@Test("La betweenness pesata usa la distanza 1/peso e divide i cammini a pari lunghezza")
func weightedBetweennessUsesInverseWeights() throws {
    // a–b e b–c con peso 1 (distanza 1), a–c con peso 0,25 (distanza 4): il cammino
    // minimo a↔c passa per b, betweenness(b)=2 (due direzioni), mentre in hop è 0.
    let detour = try symmetricGraph(
        ["a", "b", "c"], [("a", "b", 1), ("b", "c", 1), ("a", "c", 0.25)])
    #expect(GlifiNetworkAnalysis.weightedBetweenness(detour).scores["b"] == 2)
    #expect(GlifiNetworkAnalysis.betweenness(detour).scores["b"] == 0)
    // Con a–c di peso 0,5 (distanza 2) i due cammini sono pari: b riceve ½ per direzione.
    let tie = try symmetricGraph(["a", "b", "c"], [("a", "b", 1), ("b", "c", 1), ("a", "c", 0.5)])
    #expect(abs((GlifiNetworkAnalysis.weightedBetweenness(tie).scores["b"] ?? .nan) - 1) < 1e-12)
    // Closeness armonica pesata di a nel primo grafo: 1/d(a,b)+1/d(a,c)=1+1/2.
    let closeness = GlifiNetworkAnalysis.weightedHarmonicCloseness(detour)
    #expect(abs((closeness.scores["a"] ?? .nan) - 1.5) < 1e-12)
}

@Test("Componenti deboli e forti distinguono la direzione degli archi")
func componentsDistinguishDirection() throws {
    // a→b→c→a è un ciclo (una componente forte); c→d senza ritorno; e isolato.
    let graph = try GlifiDirectedGraph(
        nodes: ["a", "b", "c", "d", "e"],
        edges: [
            GlifiGraphEdge(source: "a", target: "b"),
            GlifiGraphEdge(source: "b", target: "c"),
            GlifiGraphEdge(source: "c", target: "a"),
            GlifiGraphEdge(source: "c", target: "d"),
        ]
    )
    let weak = GlifiNetworkAnalysis.weakComponents(graph)
    #expect(weak.componentCount == 2)
    #expect(weak.componentByNode == ["a": 0, "b": 0, "c": 0, "d": 0, "e": 1])
    let strong = GlifiNetworkAnalysis.strongComponents(graph)
    #expect(strong.componentCount == 3)
    #expect(strong.componentByNode["a"] == strong.componentByNode["c"])
    #expect(strong.componentByNode["d"] != strong.componentByNode["a"])
    #expect(strong.componentByNode["e"] == 2)
}

@Test("Louvain ritrova due triangoli e la modularità coincide con 5/14")
func louvainFindsPlantedCommunities() throws {
    // Due triangoli uniti da un arco: m=7; ogni comunità ha 3 archi interni e grado 7,
    // Q = 2·(3/7 - (7/14)²) = 5/14.
    let graph = try symmetricGraph(
        ["a", "b", "c", "d", "e", "f"],
        [
            ("a", "b", 1), ("b", "c", 1), ("a", "c", 1),
            ("d", "e", 1), ("e", "f", 1), ("d", "f", 1), ("c", "d", 1),
        ]
    )
    let result = try GlifiNetworkAnalysis.louvain(graph)
    #expect(result.communityCount == 2)
    #expect(result.communityByNode["a"] == result.communityByNode["c"])
    #expect(result.communityByNode["d"] == result.communityByNode["f"])
    #expect(result.communityByNode["a"] != result.communityByNode["d"])
    #expect(abs(result.modularity - 5.0 / 14.0) < 1e-12)
    let single = GlifiNetworkAnalysis.modularity(
        graph,
        communityByNode: Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0) })
    )
    #expect(abs(single) < 1e-12)
}
