// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test(
    "La facciata community conserva etichette, modularità e round-trip senza tipi Core",
    arguments: GlifiStudioGraphCommunityMethod.allCases)
func graphCompletionKitCommunities(_ method: GlifiStudioGraphCommunityMethod) async throws {
    let input = try graphKitFixture()
    let result = try await GlifiStudioGraphAlgorithms.communities(input, method: method)
    #expect(result.nodes == input.nodes)
    #expect(result.membership == [0, 0, 0, 1, 1, 1])
    #expect(abs(result.modularity - 5.0 / 14) < 1e-12)
    #expect(
        try JSONDecoder().decode(
            GlifiStudioGraphCommunityResult.self, from: JSONEncoder().encode(result)) == result)
}

@Test("Layout e Prim restituiscono DTO completi e Codable attraverso la facciata")
func graphCompletionKitLayoutAndForest() async throws {
    let input = try graphKitFixture()
    for method in GlifiStudioGraphLayoutMethod.allCases {
        let result = try await GlifiStudioGraphAlgorithms.layout(
            input, method: method, seed: 7, maximumIterations: 20)
        #expect(result.nodes == input.nodes)
        #expect(result.positions.count == input.nodes.count)
        #expect(
            try JSONDecoder().decode(
                GlifiStudioGraphLayoutResult.self, from: JSONEncoder().encode(result)) == result)
    }
    let forest = try await GlifiStudioGraphAlgorithms.minimumSpanningForest(input)
    #expect(forest.componentCount == 1)
    #expect(forest.edges.count == 5)
    #expect(forest.totalWeight == 5)
    #expect(
        try JSONDecoder().decode(
            GlifiStudioMinimumSpanningForest.self, from: JSONEncoder().encode(forest)) == forest)
}

@Test("Gli input JSON assumono peso uno e i confini Kit preservano failure e cancellazione")
func graphCompletionKitFailures() async throws {
    let arc = try JSONDecoder().decode(
        GlifiStudioGraphArc.self, from: Data(#"{"source":"a","target":"b"}"#.utf8))
    #expect(arc.weight == 1)
    let invalid = GlifiStudioGraphInput(nodes: ["a", "a"], edges: [])
    do {
        _ = try await GlifiStudioGraphAlgorithms.communities(invalid, method: .fastGreedy)
        Issue.record("Duplicate labels were accepted")
    } catch let failure {
        #expect(failure.code == "network.duplicate-node")
        #expect(failure.category == "invalidInput")
    }
    let input = try graphKitFixture()
    do {
        _ = try await GlifiStudioGraphAlgorithms.minimumSpanningForest(
            input,
            limits: .init(maximumNodeCount: 1))
        Issue.record("The input bypassed the resource gate")
    } catch let failure {
        #expect(failure.category == "insufficientResources")
        #expect(failure.retryDisposition == "afterConditionsChange")
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioGraphAlgorithms.layout(input, method: .kamadaKawai)
    }
    do {
        _ = try await task.value
        Issue.record("Cancellation was lost")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
        #expect(failure.code == "operation.cancelled")
        #expect(failure.retryDisposition == "newRequest")
    }
}

private func graphKitFixture() throws -> GlifiStudioGraphInput {
    let input = GlifiStudioGraphInput(
        nodes: ["a", "b", "c", "d", "e", "f"],
        edges: [
            ("a", "b"), ("a", "c"), ("b", "c"), ("c", "d"),
            ("d", "e"), ("d", "f"), ("e", "f"),
        ].map {
            GlifiStudioGraphArc(source: $0.0, target: $0.1)
        })
    return try JSONDecoder().decode(GlifiStudioGraphInput.self, from: JSONEncoder().encode(input))
}

@Test("Il decoder del grafo rifiuta campi annidati ignoti e default esplicitamente nulli")
func graphCompletionKitRejectsAmbiguousNestedInputs() throws {
    for text in [
        #"{"nodes":["a","b"],"edges":[],"extra":1}"#,
        #"{"nodes":["a","b"],"edges":[{"source":"a","target":"b","extra":1}]}"#,
        #"{"nodes":["a","b"],"edges":[{"source":"a","target":"b","weight":null}]}"#,
        #"{"nodes":null,"edges":[]}"#,
        #"{"nodes":[],"edges":null}"#,
    ] {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GlifiStudioGraphInput.self, from: Data(text.utf8))
        }
    }
    let omitted = try JSONDecoder().decode(
        GlifiStudioGraphInput.self,
        from: Data(#"{"nodes":["a","b"],"edges":[{"source":"a","target":"b"}]}"#.utf8))
    #expect(omitted.edges.first?.weight == 1)
}
