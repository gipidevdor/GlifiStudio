// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Degree e WeightedDegree contano correttamente archi e self-loop")
func degreeCountsEdgesAndSelfLoops() throws {
    let graph = try GlifiDirectedGraph(
        nodes: ["a", "b", "c"],
        edges: [
            GlifiGraphEdge(source: "a", target: "b", weight: 2),
            GlifiGraphEdge(source: "a", target: "c", weight: 3),
            GlifiGraphEdge(source: "b", target: "a", weight: 1),
            GlifiGraphEdge(source: "c", target: "c", weight: 5),
        ]
    )

    let result = GlifiNetworkAnalysis.degree(graph)

    #expect(result.outDegree["a"] == 2)
    #expect(result.inDegree["a"] == 1)
    #expect(result.weightedOutDegree["a"] == 5)
    #expect(result.weightedInDegree["a"] == 1)
    // Il self-loop su "c" contribuisce sia a in- sia a out-degree.
    #expect(result.outDegree["c"] == 1)
    #expect(result.inDegree["c"] == 2)
    #expect(result.weightedOutDegree["c"] == 5)
    #expect(result.weightedInDegree["c"] == 8)
    // Nodo isolato dagli archi in ingresso resta a zero, non assente.
    #expect(result.inDegree["b"] == 1)
}

@Test("PageRank su un ciclo simmetrico converge a 1/3 esatto per ogni nodo")
func pageRankOnSymmetricCycleIsUniform() throws {
    // Un ciclo diretto a-b-c-a è invariante per rotazione: la distribuzione
    // uniforme è un punto fisso indipendentemente dal damping, quindi 1/3 è
    // il valore atteso indipendentemente dal codice in prova.
    let graph = try GlifiDirectedGraph(
        nodes: ["a", "b", "c"],
        edges: [
            GlifiGraphEdge(source: "a", target: "b"),
            GlifiGraphEdge(source: "b", target: "c"),
            GlifiGraphEdge(source: "c", target: "a"),
        ]
    )

    let result = try GlifiNetworkAnalysis.pageRank(graph)

    #expect(result.converged)
    for node in graph.nodes {
        #expect(abs((result.scores[node] ?? 0) - 1.0 / 3.0) < 1e-9)
    }
    let total = result.scores.values.reduce(0, +)
    #expect(abs(total - 1) < 1e-9)
}

@Test("PageRank senza archi resta al vettore di teleport e converge in una iterazione")
func pageRankWithNoEdgesStaysAtTeleport() throws {
    let graph = try GlifiDirectedGraph(nodes: ["a", "b", "c", "d"], edges: [])

    let result = try GlifiNetworkAnalysis.pageRank(graph)

    #expect(result.iterations == 1)
    #expect(result.converged)
    for node in graph.nodes {
        #expect(abs((result.scores[node] ?? 0) - 0.25) < 1e-12)
    }
}

@Test("PageRank su due nodi con un pendente coincide con la soluzione del sistema lineare esatto")
func pageRankTwoNodeDanglingCaseMatchesLinearSystem() throws {
    // a→b, b senza archi uscenti (pendente). Risolvendo a mano
    // π = (1-d)v + d Pᵀπ con d=0,85, v=[0,5;0,5]:
    //   π_a = (1-d)·0,5 + d·0,5·π_b = 0,075 + 0,425·π_b
    //   π_b = (1-d)·0,5 + d·π_a + d·0,5·π_b = 0,075 + 0,85·π_a + 0,425·π_b
    // Con π_a+π_b=1: π_b = 0,925/1,425 = 37/57; π_a = 20/57.
    let graph = try GlifiDirectedGraph(
        nodes: ["a", "b"],
        edges: [GlifiGraphEdge(source: "a", target: "b")]
    )

    let result = try GlifiNetworkAnalysis.pageRank(graph, damping: 0.85, tolerance: 1e-14)

    let expectedB = 37.0 / 57.0
    let expectedA = 20.0 / 57.0
    #expect(abs((result.scores["a"] ?? 0) - expectedA) < 1e-6)
    #expect(abs((result.scores["b"] ?? 0) - expectedB) < 1e-6)
}

@Test("PageRank conserva la massa totale a 1 su un grafo asimmetrico con nodo pendente")
func pageRankConservesTotalMass() throws {
    let graph = try GlifiDirectedGraph(
        nodes: ["a", "b", "c", "d"],
        edges: [
            GlifiGraphEdge(source: "a", target: "b", weight: 2),
            GlifiGraphEdge(source: "a", target: "c", weight: 1),
            GlifiGraphEdge(source: "b", target: "c"),
            // "d" non ha archi uscenti: nodo pendente.
        ]
    )

    let result = try GlifiNetworkAnalysis.pageRank(graph)

    let total = result.scores.values.reduce(0, +)
    #expect(abs(total - 1) < 1e-9)
    #expect(result.scores.values.allSatisfy { $0 >= 0 })
}

@Test("PageRank mantiene la massa anche con pesi finiti estremi e tolleranze validate")
func pageRankHandlesExtremeWeightsAndInvalidTolerance() throws {
    let ordinary = try GlifiDirectedGraph(
        nodes: [0, 1, 2],
        edges: [GlifiGraphEdge(source: 0, target: 1), GlifiGraphEdge(source: 0, target: 2)])
    let expected = try GlifiNetworkAnalysis.pageRank(ordinary)
    for scale in [Double.greatestFiniteMagnitude, Double.leastNonzeroMagnitude] {
        let graph = try GlifiDirectedGraph(
            nodes: [0, 1, 2],
            edges: [
                GlifiGraphEdge(source: 0, target: 1, weight: scale),
                GlifiGraphEdge(source: 0, target: 2, weight: scale),
            ])
        let result = try GlifiNetworkAnalysis.pageRank(graph)
        #expect(result.scores == expected.scores)
        #expect(abs(result.scores.values.reduce(0, +) - 1) < 1e-12)
    }
    for tolerance in [0, -1, Double.nan, Double.infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiNetworkAnalysis.pageRank(ordinary, tolerance: tolerance)
        }
    }
}

@Test(
    "PageRank conserva ordine dei nodi, multiarchi, self-loop e dangling nella rappresentazione sparsa"
)
func pageRankSparseRowsPreserveGraphSemantics() throws {
    let graph = try GlifiDirectedGraph(
        nodes: ["z", "m", "a", "d"],
        edges: [
            GlifiGraphEdge(source: "z", target: "a", weight: 2),
            GlifiGraphEdge(source: "m", target: "z", weight: 1),
            GlifiGraphEdge(source: "z", target: "a", weight: 3),
            GlifiGraphEdge(source: "a", target: "a", weight: 4),
            GlifiGraphEdge(source: "d", target: "m", weight: 0),
            GlifiGraphEdge(source: "m", target: "a", weight: 2),
            GlifiGraphEdge(source: "z", target: "z", weight: 1),
        ])
    let result = try GlifiNetworkAnalysis.pageRank(graph, tolerance: 1e-14)
    // With d=17/20 the dangling node obeys π_d=(1-d)/4+d*π_d/4=1/21.
    // π_m=π_d; π_z=π_d+d*(π_m/3+π_z/6)=154/2163; the remainder is π_a.
    #expect(abs((result.scores["d"] ?? 0) - 1.0 / 21) < 1e-13)
    #expect(abs((result.scores["m"] ?? 0) - 1.0 / 21) < 1e-13)
    #expect(abs((result.scores["z"] ?? 0) - 154.0 / 2163) < 1e-13)
    #expect(abs((result.scores["a"] ?? 0) - 601.0 / 721) < 1e-13)
    #expect(result.converged)
    let teleportOnly = try GlifiNetworkAnalysis.pageRank(graph, damping: 0)
    #expect(teleportOnly.iterations == 1)
    #expect(graph.nodes.allSatisfy { teleportOnly.scores[$0] == 0.25 })
}

private struct CollidingGraphNode: Hashable, Sendable {
    let value: Int

    func hash(into hasher: inout Hasher) { hasher.combine(0) }
}

@Test("PageRank risolve identità con hash in collisione e rispetta cancellazione")
func pageRankSparseRowsHandleHashCollisionsAndCancellation() async throws {
    let nodes = [2, 0, 1].map(CollidingGraphNode.init(value:))
    let graph = try GlifiDirectedGraph(
        nodes: nodes,
        edges: [
            GlifiGraphEdge(source: nodes[0], target: nodes[1]),
            GlifiGraphEdge(source: nodes[1], target: nodes[2]),
            GlifiGraphEdge(source: nodes[2], target: nodes[0]),
        ])
    let result = try GlifiNetworkAnalysis.pageRank(graph)
    let expected = 1.0 / 3.0
    #expect(nodes.allSatisfy { abs((result.scores[$0] ?? 0) - expected) < 1e-15 })
    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiNetworkAnalysis.pageRank(graph)
    }
    await #expect(throws: CancellationError.self) { try await cancelled.value }
}

@Test("Il grafo e PageRank rifiutano forme, riferimenti e parametri non validi")
func networkRejectsInvalidInputs() throws {
    do {
        _ = try GlifiDirectedGraph(nodes: ["a", "a"], edges: [])
        Issue.record("Il nodo duplicato non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "network.duplicate-node")
    }
    do {
        _ = try GlifiDirectedGraph(
            nodes: ["a"],
            edges: [GlifiGraphEdge(source: "a", target: "b")]
        )
        Issue.record("Il riferimento a nodo ignoto non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "network.unknown-edge-endpoint")
    }
    do {
        _ = try GlifiDirectedGraph(
            nodes: ["a", "b"],
            edges: [GlifiGraphEdge(source: "a", target: "b", weight: -1)]
        )
        Issue.record("Il peso negativo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "network.negative-or-non-finite-weight")
    }

    let graph = try GlifiDirectedGraph(nodes: ["a"], edges: [])
    do {
        _ = try GlifiNetworkAnalysis.pageRank(graph, damping: 1)
        Issue.record("Il damping fuori range non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "network.invalid-damping")
    }
    do {
        let emptyGraph: GlifiDirectedGraph<String> = try GlifiDirectedGraph(nodes: [], edges: [])
        _ = try GlifiNetworkAnalysis.pageRank(emptyGraph)
        Issue.record("Il grafo vuoto non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "network.empty-graph")
    }
}

@Test("Betweenness e HarmonicCloseness su un percorso diretto coincidono con i valori esatti")
func betweennessAndHarmonicClosenessMatchPathClosedForm() throws {
    // a→b→c→d, unidirezionale: unica fixture canonica "percorso" richiesta
    // dalla specifica. Betweenness(b)=2 da (a,c) e (a,d); Betweenness(c)=2 da
    // (a,d) e (b,d); estremi a zero. HarmonicCloseness calcolata per frazioni
    // esatte sulle distanze hop dirette.
    let graph = try GlifiDirectedGraph(
        nodes: ["a", "b", "c", "d"],
        edges: [
            GlifiGraphEdge(source: "a", target: "b"),
            GlifiGraphEdge(source: "b", target: "c"),
            GlifiGraphEdge(source: "c", target: "d"),
        ]
    )

    let betweenness = GlifiNetworkAnalysis.betweenness(graph)
    #expect(betweenness.scores["a"] == 0)
    #expect(betweenness.scores["b"] == 2)
    #expect(betweenness.scores["c"] == 2)
    #expect(betweenness.scores["d"] == 0)

    let closeness = GlifiNetworkAnalysis.harmonicCloseness(graph)
    #expect(abs((closeness.scores["a"] ?? 0) - 11.0 / 6.0) < 1e-12)
    #expect(abs((closeness.scores["b"] ?? 0) - 1.5) < 1e-12)
    #expect(abs((closeness.scores["c"] ?? 0) - 1) < 1e-12)
    #expect(abs((closeness.scores["d"] ?? 0)) < 1e-12)
}

@Test("Betweenness e HarmonicCloseness su una stella coincidono con i valori esatti noti")
func betweennessAndHarmonicClosenessMatchStarClosedForm() throws {
    // Stella bidirezionale a tre foglie: fixture canonica richiesta dalla
    // specifica. Ogni coppia di foglie passa esclusivamente dal centro su
    // un unico cammino minimo, quindi Betweenness(centro) = 3 foglie × 2
    // coppie ordinate = 6; le foglie non intermediano mai. HarmonicCloseness
    // del centro è 3 (distanza 1 da ciascuna foglia); di una foglia è 2
    // (1 dal centro, 1/2 da ciascuna delle altre due foglie via il centro).
    let graph = try GlifiDirectedGraph(
        nodes: ["center", "leaf1", "leaf2", "leaf3"],
        edges: [
            GlifiGraphEdge(source: "center", target: "leaf1"),
            GlifiGraphEdge(source: "leaf1", target: "center"),
            GlifiGraphEdge(source: "center", target: "leaf2"),
            GlifiGraphEdge(source: "leaf2", target: "center"),
            GlifiGraphEdge(source: "center", target: "leaf3"),
            GlifiGraphEdge(source: "leaf3", target: "center"),
        ]
    )

    let betweenness = GlifiNetworkAnalysis.betweenness(graph)
    #expect(betweenness.scores["center"] == 6)
    #expect(betweenness.scores["leaf1"] == 0)
    #expect(betweenness.scores["leaf2"] == 0)
    #expect(betweenness.scores["leaf3"] == 0)

    let closeness = GlifiNetworkAnalysis.harmonicCloseness(graph)
    #expect(abs((closeness.scores["center"] ?? 0) - 3) < 1e-12)
    #expect(abs((closeness.scores["leaf1"] ?? 0) - 2) < 1e-12)
    #expect(abs((closeness.scores["leaf2"] ?? 0) - 2) < 1e-12)
    #expect(abs((closeness.scores["leaf3"] ?? 0) - 2) < 1e-12)
}

@Test("Il grafo vuoto e i self-loop non alterano Betweenness/HarmonicCloseness")
func betweennessAndHarmonicClosenessHandleEmptyGraphAndSelfLoops() throws {
    let empty: GlifiDirectedGraph<String> = try GlifiDirectedGraph(nodes: [], edges: [])
    #expect(GlifiNetworkAnalysis.betweenness(empty).scores.isEmpty)
    #expect(GlifiNetworkAnalysis.harmonicCloseness(empty).scores.isEmpty)

    // Un self-loop non introduce un cammino minimo verso se stessi.
    let selfLoop = try GlifiDirectedGraph(
        nodes: ["a", "b"],
        edges: [
            GlifiGraphEdge(source: "a", target: "a"),
            GlifiGraphEdge(source: "a", target: "b"),
        ]
    )
    let closeness = GlifiNetworkAnalysis.harmonicCloseness(selfLoop)
    #expect(abs((closeness.scores["a"] ?? 0) - 1) < 1e-12)
}
