// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Isolated, bounded graph workloads; the harness chooses when to run them.
func graphOptimizationMeasurements() throws -> [Measurement] {
    var generator = GlifiSplitMix64(seed: 169)
    var documents: [GlifiSummaryDocument] = []
    for documentIndex in 0..<8 {
        var sentences: [GlifiSummaryCandidateSentence] = []
        for sentenceIndex in 0..<60 {
            let topic = (documentIndex * 60 + sentenceIndex) % 16
            let terms = (0..<32).map { position in
                position.isMultiple(of: 16)
                    ? "shared\(generator.index(below: 512))"
                    : "topic\(topic)-term\(generator.index(below: 96))"
            }
            sentences.append(
                GlifiSummaryCandidateSentence(
                    range: try GlifiUTF8Range(
                        start: sentenceIndex * 128, end: sentenceIndex * 128 + 96),
                    terms: terms, characterCount: 96))
        }
        documents.append(
            GlifiSummaryDocument(
                sourceRevisionID: try SourceRevisionID(
                    canonicalValue: String(
                        format: "source-revision:00000000-0000-0000-0000-%012d", documentIndex + 1)),
                sentences: sentences))
    }
    let configuration = GlifiSummaryGraphConfiguration(
        damping: 0.85, tolerance: 1e-12, maximumIterations: 400, similarityThreshold: 0.1)
    let summaryInputChecksum = try graphBenchmarkChecksum(
        documents.map {
            GraphBenchmarkSummaryInput(
                sourceRevisionID: $0.sourceRevisionID.canonicalValue,
                ranges: $0.sentences.map(\.range), terms: $0.sentences.map(\.terms),
                characterCounts: $0.sentences.map(\.characterCount))
        })
    var measurements: [Measurement] = []
    for (identifier, method) in [
        ("optimization-textrank-480x32", GlifiSummaryScoringMethod.textRankConfigurable),
        ("optimization-lexrank-continuous-480x32", GlifiSummaryScoringMethod.lexRankContinuous),
    ] {
        var result: GlifiCorpusExtractiveSummaryAnalysis?
        let times = try measure {
            result = try GlifiCorpusExtractiveSummaryAnalysis(
                documents: documents, budget: GlifiSummaryBudget(unit: .sentences, limit: 8),
                scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: method,
                graphConfiguration: configuration)
        }
        guard let result, let diagnostics = result.graphDiagnostics else {
            throw GraphBenchmarkFailure.missingResult
        }
        let check =
            try graphBenchmarkChecksum(result)
            + "; nodes=\(diagnostics.nodeCount); edges=\(diagnostics.edgeCount)"
            + "; iterations=\(diagnostics.iterations); converged=\(diagnostics.converged)"
        measurements.append(
            summary(
                identifier, "GS-MET-001-19",
                "SplitMix64 seed 169; 8 documents, 480 sentences, 32 tokens, 16 topics, shared keys; "
                    + "damping 0.85, L1 1e-12, maximum 400 iterations; input=\(summaryInputChecksum)",
                times, check: check))
    }

    let nodes = (0..<8_000).map { "term-\($0)" }
    var graphGenerator = GlifiSplitMix64(seed: 170)
    var edges: [GlifiGraphEdge<String>] = []
    edges.reserveCapacity(72_000)
    for source in 0..<7_200 {
        for _ in 0..<10 {
            let target =
                graphGenerator.index(below: 10) < 8
                ? source / 200 * 200 + graphGenerator.index(below: 200)
                : graphGenerator.index(below: nodes.count)
            edges.append(
                GlifiGraphEdge(
                    source: nodes[source], target: nodes[target],
                    weight: 0.25 + 3.75 * uniform(&graphGenerator)))
        }
    }
    let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
    let graphInputChecksum = try graphBenchmarkChecksum(
        GraphBenchmarkGraphInput(
            nodes: nodes, sources: edges.map(\.source), targets: edges.map(\.target),
            weights: edges.map(\.weight)))
    var centrality: GlifiPageRankResult<String>?
    let rankTimes = try measure {
        centrality = try GlifiNetworkAnalysis.pageRank(
            graph, damping: 0.85, tolerance: 1e-12, maximumIterations: 400)
    }
    guard let centrality else { throw GraphBenchmarkFailure.missingResult }
    let orderedScores = nodes.map { centrality.scores[$0] ?? 0 }
    let check =
        try graphBenchmarkChecksum(orderedScores)
        + "; mass=\(orderedScores.reduce(0, +)); iterations=\(centrality.iterations)"
        + "; converged=\(centrality.converged)"
    measurements.append(
        summary(
            "optimization-pagerank-8000-nodes-72000-edges", "GS-MET-001-16",
            "SplitMix64 seed 170; string identities, 80% local edges, weights [0.25,4], "
                + "800 dangling nodes; damping 0.85, L1 1e-12, maximum 400 iterations; "
                + "input=\(graphInputChecksum)",
            rankTimes, check: check))
    return measurements
}

private enum GraphBenchmarkFailure: Error {
    case missingResult
}

private struct GraphBenchmarkSummaryInput: Encodable {
    let sourceRevisionID: String
    let ranges: [GlifiUTF8Range]
    let terms: [[String]]
    let characterCounts: [Int]
}

private struct GraphBenchmarkGraphInput: Encodable {
    let nodes: [String]
    let sources: [String]
    let targets: [String]
    let weights: [Double]
}

private func graphBenchmarkChecksum(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(value)
    return "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}
