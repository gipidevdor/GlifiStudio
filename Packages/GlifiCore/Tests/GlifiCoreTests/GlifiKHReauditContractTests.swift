// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Reaudit: decoded UTF-8 ranges preserve constructor invariants")
func khReauditRangeDecoding() throws {
    for (start, end) in [(-1, 1), (0, 0), (1, 0), (0, -1), (Int.min, Int.max)] {
        let data = try JSONSerialization.data(withJSONObject: ["start": start, "end": end])
        #expect(throws: GlifiFailure.self) {
            try JSONDecoder().decode(GlifiUTF8Range.self, from: data)
        }
    }
    let valid = try JSONDecoder().decode(
        GlifiUTF8Range.self, from: Data(#"{"start":0,"end":2}"#.utf8))
    #expect(valid.count == 2)
    #expect(valid.text(in: "é") == "é")
}

@Test("Reaudit: externally supplied coding surfaces match exact source bytes")
func khReauditCodingSourceBytes() throws {
    for (text, surface) in [("é", "e\u{301}"), ("e\u{301}", "é")] {
        #expect(text == surface)
        #expect(!text.utf8.elementsEqual(surface.utf8))
        let range = try GlifiUTF8Range(start: 0, end: text.utf8.count)
        let altered = GlifiCodingToken(
            surface: surface, base: "é", range: range, sentence: 0, paragraph: 0)
        #expect(throws: GlifiFailure.self) {
            try GlifiCodingDocument(
                id: "one", text: text, tokens: [altered], linguisticContract: "external-test")
        }
        let exact = GlifiCodingToken(
            surface: text, base: "é", range: range, sentence: 0, paragraph: 0)
        _ = try GlifiCodingDocument(
            id: "one", text: text, tokens: [exact], linguisticContract: "external-test")
    }
}

@Test("Reaudit: SOM diagnostics do not silently square tiny distances to zero")
func khReauditSOMUnderflow() throws {
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0.0], [1e-200]], width: 1, height: 1, seed: 0, epochs: 1,
        initialRadius: 1, finalRadius: 1, tolerance: 1e-300)
    #expect(abs(result.quantizationError / 1e-200 - 0.5) < 1e-14)
    #expect(!result.converged)
}

@Test("Reaudit: Kamada-Kawai admission counts all-pairs shortest-path preparation")
func khReauditKamadaKawaiWork() throws {
    let nodes = Array(0..<20)
    let edges = nodes.flatMap { first in
        (0..<first).map { second in GlifiGraphEdge(source: first, target: second, weight: 1) }
    }
    let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
    #expect(throws: GlifiFailure.self) {
        try GlifiNetworkAnalysis.layout(
            graph, method: .kamadaKawai, maximumIterations: 1,
            limits: .init(maximumWork: 1_040))
    }
    _ = try GlifiNetworkAnalysis.layout(
        graph, method: .fruchtermanReingold, maximumIterations: 1,
        limits: .init(maximumWork: 1_040))
}
