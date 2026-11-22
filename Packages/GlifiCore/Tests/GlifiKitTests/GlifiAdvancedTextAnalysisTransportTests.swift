// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

private func advancedData(_ body: [String: Any]) throws -> Data {
    var body = body
    body["schema"] = GlifiStudioTextAnalysisRequest.schema
    body["schemaVersion"] = 1
    return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
}

@Test("Operatori nuovi: omissione default, ordine chiavi e UInt64 hanno identità canonica")
func advancedTextAnalysisDefaults() throws {
    let graph = GlifiStudioGraphInput(nodes: ["a", "b"], edges: [.init(source: "a", target: "b")])
    let typed = GlifiStudioTextAnalysisRequest.advanced(
        .graphLayout(
            graph: graph, method: .fruchtermanReingold, seed: .max))
    let decoded = try GlifiStudioTextAnalysisRequest.decode(
        advancedData([
            "operation": "graph-layout",
            "graph": ["nodes": ["a", "b"], "edges": [["source": "a", "target": "b"]]],
            "method": "fruchtermanReingold", "seed": UInt64.max,
        ]))
    #expect(try typed.canonicalData() == decoded.canonicalData())
    #expect(try GlifiStudioTextAnalysisRequest.decode(typed.canonicalData()) == typed)
    let stem = GlifiStudioTextAnalysisRequest.advanced(.linguistic(text: "ragazze"))
    let minimal = try GlifiStudioTextAnalysisRequest.decode(
        advancedData([
            "operation": "linguistic", "text": "ragazze", "options": [:],
        ]))
    #expect(try stem.canonicalData() == minimal.canonicalData())
}

@Test("Le nuove opzioni rifiutano chiavi ignote, null e ambiguità annidate")
func advancedTextAnalysisStrictNestedRequests() throws {
    let graph: [String: Any] = ["nodes": ["a", "b"], "edges": [["source": "a", "target": "b"]]]
    let invalid: [[String: Any]] = [
        [
            "operation": "communities",
            "graph": graph.merging(["secret-canary": true]) { _, b in b }, "method": "walktrap",
        ],
        [
            "operation": "communities",
            "graph": [
                "nodes": ["a", "b"], "edges": [["source": "a", "target": "b", "weight": NSNull()]],
            ], "method": "walktrap",
        ],
        [
            "operation": "graph-layout", "graph": graph, "method": "kamadaKawai",
            "initialPositions": [["x": 0, "y": 0, "secret-canary": 1], ["x": 1, "y": 1]],
        ],
        ["operation": "linguistic", "text": "secret-canary", "options": ["base": NSNull()]],
        ["operation": "linguistic", "text": "secret-canary", "options": ["secret-canary": true]],
        [
            "operation": "lda-selection", "documents": [["a"], ["a"]], "candidateTopicCounts": [1],
            "seed": 0, "options": ["folds": NSNull()],
        ],
        [
            "operation": "lda-selection", "documents": [["a"], ["a"]], "candidateTopicCounts": [1],
            "seed": 0, "options": ["secret-canary": 1],
        ],
        [
            "operation": "linguistic-coding",
            "units": [["id": "1", "text": "secret-canary", "extra": true]], "rules": "*A\na",
        ],
    ]
    for value in invalid {
        do {
            _ = try GlifiStudioTextAnalysisRequest.decode(advancedData(value))
            Issue.record("Ambiguous advanced request accepted")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "invalidInput")
            #expect(failure.arguments.isEmpty)
            #expect(!String(describing: failure).contains("secret-canary"))
        }
    }
    let duplicate = Data(
        #"{"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"linguistic","text":"secret-canary","options":{"base":"normalized-surface","\u0062ase":"apple-lemma"}}"#
            .utf8)
    #expect(throws: GlifiStudioFailure.self) {
        try GlifiStudioTextAnalysisRequest.decode(duplicate)
    }
}

@Test("Il budget aggregato include candidati LDA e impedisce valori non finiti")
func advancedTextAnalysisAggregateBudgets() throws {
    let documents = Array(repeating: Array(repeating: "t", count: 49), count: 5_000)
    let over = GlifiStudioTextAnalysisRequest.advanced(
        .ldaSelection(
            documents: documents, candidateTopicCounts: [2], seed: 0))
    do {
        _ = try over.canonicalData()
        Issue.record("Candidate vector escaped aggregate element limit")
    } catch let failure {
        #expect(failure.category == "insufficientResources")
    }
    let graph = GlifiStudioGraphInput(nodes: ["a"], edges: [])
    let invalid = GlifiStudioTextAnalysisRequest.advanced(
        .graphLayout(
            graph: graph, method: .fruchtermanReingold,
            initialPositions: [.init(x: .infinity, y: 0)]))
    #expect(throws: GlifiStudioFailure.self) { try invalid.canonicalData() }
}

@Test("Trasporto LDA mantiene diagnostiche, copertura held-out e stato scientifico conservativo")
func advancedTextAnalysisLDADirectParity() async throws {
    let documents = [["a", "a", "b"], ["b", "a", "b"], ["a", "b", "a"], ["b", "b", "a"]]
    let options = GlifiStudioLDASelectionOptions(folds: 2, burnIn: 2, sampleCount: 3, thinning: 1)
    let direct = try await GlifiStudioLDAModelSelection.select(
        documents: documents, candidateTopicCounts: [1, 2], seed: 17, options: options)
    let request = GlifiStudioTextAnalysisRequest.advanced(
        .ldaSelection(
            documents: documents, candidateTopicCounts: [1, 2], seed: 17, options: options))
    let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(
        json: request.canonicalData())
    let data = try JSONEncoder().encode(result)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let payload = try #require(object["result"] as? [String: Any])
    #expect(payload["selectedTopicCount"] as? Int == direct.selectedTopicCount)
    #expect(payload["foldAssignments"] as? [Int] == direct.foldAssignments)
    #expect(result.validationStatus == "candidate")
    #expect(result.methodIdentifier == direct.methodIdentifier)
}

@Test("I nuovi operatori propagano cancellazione prima della pubblicazione")
func advancedTextAnalysisCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioTextAnalytics.executeTextAnalysis(
            .advanced(.linguistic(text: "ragazze", options: .init(base: .italianSnowballStem))))
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled request returned a result")
    } catch {
        let failure = error as? GlifiStudioFailure
        #expect(failure?.category == "cancelled")
        #expect(failure?.retainedState == "unchanged")
    }
}
