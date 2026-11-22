// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private func graphDocuments() throws -> [GlifiSummaryDocument] {
    let documents = [
        [["casa", "bella", "casa"], [], ["bella", "giardino"]],
        [["giardino", "verde"], ["casa"]],
    ]
    return try documents.enumerated().map { document, sentences in
        GlifiSummaryDocument(
            sourceRevisionID: try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(document + 1)"
            ),
            sentences: try sentences.enumerated().map { index, terms in
                GlifiSummaryCandidateSentence(
                    range: try GlifiUTF8Range(start: index * 10, end: index * 10 + 5), terms: terms,
                    characterCount: 5)
            })
    }
}

@Test("Le varianti upstream restano fisse e i payload precedenti non richiedono diagnostica")
func summaryGraphPreservesUpstreamMethodsAndLegacyPayloads() throws {
    let documents = try graphDocuments()
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    for method in [GlifiSummaryScoringMethod.lexRank, .textRank] {
        #expect(!method.supportsGraphConfiguration)
        let legacy = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: documents, budget: .standard, scheme: scheme, method: method)
        #expect(legacy.graphDiagnostics == nil)
        let bytes = try JSONEncoder().encode(legacy)
        let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(object["graphDiagnostics"] == nil)
        let decoded = try JSONDecoder().decode(
            GlifiCorpusExtractiveSummaryAnalysis.self, from: bytes)
        #expect(decoded == legacy)
        #expect(throws: GlifiFailure.self) {
            try GlifiCorpusExtractiveSummaryAnalysis(
                documents: documents, budget: .standard, scheme: scheme, method: method,
                graphConfiguration: .standard)
        }
    }
    #expect(GlifiSummaryScoringMethod.lexRank.rawValue == "LexRankSentence-v1")
    #expect(GlifiSummaryScoringMethod.textRank.rawValue == "TextRankSentence-v1")
    #expect(
        GlifiSummaryScoringMethod.textRankConfigurable.rawValue
            == "TextRankSentence-configurable-v1")
}

@Test("Le tre varianti configurabili conservano budget Unicode scalari e confronto senza overflow")
func summaryGraphPreservesCharacterBudgets() throws {
    let documents = try graphDocuments()
    let scheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme
    for method in [
        GlifiSummaryScoringMethod.textRankConfigurable, .lexRankContinuous, .lexRankThreshold,
    ] {
        let result = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: documents, budget: .init(unit: .characters, limit: 5),
            scheme: scheme, method: method)
        #expect(result.consumedBudget == 5)
        #expect(result.selectedSentences.count == 1)
        #expect(result.graphDiagnostics != nil)
    }
    let largeCost = GlifiSummaryDocument(
        sourceRevisionID: documents[0].sourceRevisionID,
        sentences: [
            .init(range: try GlifiUTF8Range(start: 0, end: 1), terms: ["a"], characterCount: 1),
            .init(
                range: try GlifiUTF8Range(start: 1, end: 2), terms: ["a"], characterCount: Int.max),
        ])
    let result = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: [largeCost], budget: .init(unit: .characters, limit: 3),
        scheme: scheme, method: .textRankConfigurable,
        redundancy: .maximalMarginalRelevance(lambda: 1))
    #expect(result.consumedBudget == 1)
    #expect(result.selectedSentences.map(\.sentenceIndex) == [0])
}

@Test(
    "Le postings TextRank conservano bit per bit l'overlap diretto con ripetizioni, vuoti e disgiunzioni"
)
func summaryGraphPostingsMatchDirectOverlap() throws {
    var generator = GlifiSplitMix64(seed: 169)
    var terms: [[String]] = [[], ["solo"], ["solo"], ["solo", "solo"], ["disgiunto"]]
    for index in 0..<75 {
        terms.append(
            index.isMultiple(of: 11)
                ? [] : (0..<(index % 17 + 1)).map { _ in "t\(generator.index(below: 31))" })
    }
    let configuration = GlifiSummaryGraphConfiguration(
        damping: 0.85, tolerance: 1e-13, maximumIterations: 1_000)
    let actual = try summaryGraphScores(
        terms: terms, nonNullVectors: [], method: .textRankConfigurable,
        configuration: configuration,
        cosine: { _, _ in
            Issue.record("TextRank requested an unused cosine")
            return 0
        })
    let nodes = terms.indices.filter { !terms[$0].isEmpty }
    var edges: [GlifiGraphEdge<Int>] = []
    for (position, left) in nodes.enumerated() {
        for right in nodes.dropFirst(position + 1) {
            let denominator = log(Double(terms[left].count)) + log(Double(terms[right].count))
            let shared = Set(terms[left]).intersection(Set(terms[right])).count
            let weight = denominator > 0 ? Double(shared) / denominator : 0
            if weight > 0 {
                edges.append(.init(source: left, target: right, weight: weight))
                edges.append(.init(source: right, target: left, weight: weight))
            }
        }
    }
    let reference = try GlifiNetworkAnalysis.pageRank(
        GlifiDirectedGraph(nodes: nodes, edges: edges), damping: configuration.damping,
        tolerance: configuration.tolerance, maximumIterations: configuration.maximumIterations)
    for index in terms.indices {
        #expect(actual.scores[index].bitPattern == (reference.scores[index] ?? 0).bitPattern)
    }
    #expect(actual.diagnostics.edgeCount == edges.count / 2)
    #expect(actual.diagnostics.iterations == reference.iterations)
    #expect(actual.diagnostics.converged == reference.converged)
}

@Test("TextRank e LexRank coincidono con il sistema stazionario indipendente Python")
func summaryGraphMatchesIndependentOracle() throws {
    // summary_graph.py solves a linear system; production uses power iteration.
    let references: [(GlifiSummaryScoringMethod, [Double])] = [
        (
            .textRankConfigurable,
            [0.322225312424025, 0, 0.292712942260475, 0.177774687575975, 0.207287057739525]
        ),
        (
            .lexRankContinuous,
            [
                0.397350034627129, 0, 0.257537957648439, 0.102649965372871, 0.242462042351561,
            ]
        ),
        (
            .lexRankThreshold,
            [
                0.324561403508772, 0, 0.324561403508772, 0.175438596491228, 0.175438596491228,
            ]
        ),
    ]
    let documents = try graphDocuments()
    for (method, expected) in references {
        let summary = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: documents, budget: .standard,
            scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: method)
        for (sentence, reference) in zip(summary.sentences, expected) {
            #expect(abs(sentence.score - reference) < 1e-12)
        }
        #expect(abs(summary.sentences.reduce(0) { $0 + $1.score } - 1) < 1e-12)
        #expect(summary.graphDiagnostics?.configuration == .standard)
        #expect(summary.graphDiagnostics?.nodeCount == 4)
        #expect(summary.graphDiagnostics?.edgeCount == 3)
        #expect(summary.graphDiagnostics?.converged == true)
        #expect(summary.graphDiagnostics?.centralityIdentifier == "PageRank-v1")
        #expect(summary.sentences.map(\.isEligible) == [true, false, true, true, true])
        let reordered = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: documents.reversed(), budget: .standard,
            scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: method)
        #expect(reordered == summary)
        let encoded = try JSONEncoder().encode(summary)
        #expect(
            try JSONDecoder().decode(GlifiCorpusExtractiveSummaryAnalysis.self, from: encoded)
                == summary)
    }
}

@Test("Il grafo conserva isolate, non inventa vettori nulli e dichiara la mancata convergenza")
func summaryGraphDegenerateAndIterationCases() throws {
    let id = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000001")
    let disjoint = [
        GlifiSummaryDocument(
            sourceRevisionID: id,
            sentences: try ["a", "b", "c"].enumerated().map { index, term in
                GlifiSummaryCandidateSentence(
                    range: try GlifiUTF8Range(start: index, end: index + 1), terms: [term],
                    characterCount: 1)
            })
    ]
    let zeroScheme = GlifiTermWeightingScheme(
        termFrequency: .raw, inverseDocumentFrequency: .unsmoothed, normalization: .none)
    for method in [
        GlifiSummaryScoringMethod.textRankConfigurable, .lexRankContinuous, .lexRankThreshold,
    ] {
        let summary = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: disjoint, budget: .standard,
            scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: method)
        #expect(summary.graphDiagnostics?.edgeCount == 0)
        let uniform = [Double](repeating: 1.0 / 3.0, count: 3)
        #expect(summary.sentences.map(\.score) == uniform)
        #expect(summary.sentences.map(\.rank) == [1, 2, 3])
        let noWeights = try GlifiCorpusExtractiveSummaryAnalysis(
            documents: disjoint, budget: .standard, scheme: zeroScheme, method: method)
        #expect(noWeights.graphDiagnostics?.nodeCount == (method == .textRankConfigurable ? 3 : 0))
        #expect(noWeights.selectedSentences.count == (method == .textRankConfigurable ? 3 : 0))
        #expect(noWeights.graphDiagnostics?.converged == true)
    }
    let partial = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: graphDocuments(), budget: .standard,
        scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: .lexRankContinuous,
        graphConfiguration: GlifiSummaryGraphConfiguration(maximumIterations: 1))
    #expect(partial.graphDiagnostics?.iterations == 1)
    #expect(partial.graphDiagnostics?.converged == false)
    let noEdges = try GlifiCorpusExtractiveSummaryAnalysis(
        documents: graphDocuments(), budget: .standard,
        scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme, method: .lexRankThreshold,
        graphConfiguration: GlifiSummaryGraphConfiguration(similarityThreshold: 1))
    #expect(noEdges.graphDiagnostics?.edgeCount == 0)
}

@Test("Parametri e limiti dei grafi falliscono prima del calcolo non limitato")
func summaryGraphRejectsInvalidConfigurationAndWork() throws {
    let documents = try graphDocuments()
    let invalid = [
        GlifiSummaryGraphConfiguration(damping: .nan),
        GlifiSummaryGraphConfiguration(damping: 1),
        GlifiSummaryGraphConfiguration(tolerance: 0),
        GlifiSummaryGraphConfiguration(tolerance: .infinity),
        GlifiSummaryGraphConfiguration(maximumIterations: 0),
        GlifiSummaryGraphConfiguration(maximumIterations: 10_001),
        GlifiSummaryGraphConfiguration(similarityThreshold: -0.1),
        GlifiSummaryGraphConfiguration(similarityThreshold: .nan),
    ]
    for configuration in invalid {
        #expect(throws: GlifiFailure.self) {
            try GlifiCorpusExtractiveSummaryAnalysis(
                documents: documents, budget: .standard,
                scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme,
                method: .textRankConfigurable,
                graphConfiguration: configuration)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiCorpusExtractiveSummaryAnalysis(
            documents: documents, budget: .standard,
            scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme,
            graphConfiguration: .standard)
    }
    for (count, code) in [
        (2_049, "summary.graph-sentence-limit"), (500, "summary.graph-work-limit"),
    ] {
        let document = GlifiSummaryDocument(
            sourceRevisionID: documents[0].sourceRevisionID,
            sentences: Array(repeating: documents[0].sentences[0], count: count))
        do {
            _ = try GlifiCorpusExtractiveSummaryAnalysis(
                documents: [document], budget: .standard,
                scheme: GlifiCorpusExtractiveSummaryAnalysis.standardScheme,
                method: .textRankConfigurable)
            Issue.record("Expected graph resource limit")
        } catch let failure as GlifiFailure {
            #expect(failure.code == code)
            #expect(failure.category == .insufficientResources)
        }
    }
}

@Test("Il descrittore distingue metodi e configurazioni del grafo e riusa lo stesso artefatto")
func summaryGraphPersistsParametersAndDiagnostics() async throws {
    let url = FileManager.default.temporaryDirectory.appending(
        path: "GlifiSummaryGraph-\(UUID().uuidString).glifi", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: url) }
    let engine = GlifiEngine()
    let project = try await engine.createProject(at: url)
    let source = try GlifiTextImporter().importText(
        from: Data("Casa bella. Bella verde. Casa.".utf8), format: .plainText,
        sourceRevisionID: graphDocuments()[0].sourceRevisionID)
    _ = try await project.importText(source)
    let ids = [source.sourceRevisionID]
    let first = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, method: .textRankConfigurable)
    let reused = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, method: .textRankConfigurable)
    #expect(first.artifactID == reused.artifactID)
    let changed = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, method: .textRankConfigurable,
        graphConfiguration: GlifiSummaryGraphConfiguration(damping: 0.5))
    #expect(changed.artifactID != first.artifactID)
    #expect(changed.value.graphDiagnostics?.configuration.damping == 0.5)
    let lexical = try await engine.analyzeExtractiveSummary(
        in: project, sourceRevisionIDs: ids, method: .lexRankContinuous)
    #expect(lexical.artifactID != first.artifactID)
    let stored = try await engine.storedDerivedResult(
        GlifiCorpusExtractiveSummaryAnalysis.self, artifactID: changed.artifactID, in: project)
    #expect(stored.value == changed.value)
}
