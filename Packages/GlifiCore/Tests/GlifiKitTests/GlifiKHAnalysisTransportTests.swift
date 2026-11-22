// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

private func khRequestData(_ fields: [String: Any]) throws -> Data {
    var fields = fields
    fields["schema"] = GlifiStudioTextAnalysisRequest.schema
    fields["schemaVersion"] = GlifiStudioTextAnalysisRequest.schemaVersion
    return try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
}

private func khEncoded(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

@Test("KH request defaults have the same canonical identity as explicit native parameters")
func khAnalysisDefaultsAndIdentity() throws {
    let minimal = try GlifiStudioTextAnalysisRequest.decode(
        khRequestData([
            "operation": "som-kh", "matrix": [[0.0], [2.0], [4.0]], "width": 2, "height": 1,
        ]))
    let typed = GlifiStudioTextAnalysisRequest.advanced(
        .kh(
            .somKH(
                matrix: [[0], [2], [4]], width: 2, height: 1)))
    let explicit = GlifiStudioTextAnalysisRequest.advanced(
        .kh(
            .somKH(
                matrix: [[0], [2], [4]], width: 2, height: 1,
                firstPhase: .init(steps: 6, initialLearningRate: 0.05, initialRadius: 1),
                secondPhase: .init(steps: 30, initialLearningRate: 0.02, initialRadius: 1))))
    #expect(try minimal.canonicalData() == typed.canonicalData())
    #expect(try explicit.canonicalData() == typed.canonicalData())
    #expect(try GlifiStudioTextAnalysisRequest.decode(minimal.canonicalData()) == minimal)
    let changed = GlifiStudioTextAnalysisRequest.advanced(
        .kh(
            .somKH(
                matrix: [[0], [2], [4]], width: 2, height: 1, topology: .rectangular)))
    #expect(try changed.canonicalData() != minimal.canonicalData())
}

@Test("KH nested fields reject unknown keys, explicit nulls and malformed states")
func khAnalysisStrictNestedFields() throws {
    let phase: [String: Any] = ["steps": 2, "initialLearningRate": 0.05, "initialRadius": 1]
    let invalid: [[String: Any]] = [
        [
            "operation": "som-kh", "matrix": [[0], [1]], "width": 1, "height": 1,
            "initialCodebooks": NSNull(),
        ],
        [
            "operation": "som-kh", "matrix": [[0], [1]], "width": 1, "height": 1,
            "firstPhase": NSNull(),
        ],
        [
            "operation": "som-kh", "matrix": [[0], [1]], "width": 1, "height": 1,
            "firstPhase": phase.merging(["secret-canary": 1]) { _, b in b },
        ],
        [
            "operation": "term-scores",
            "candidates": [["components": ["a"], "frequency": 1, "secret-canary": 1]],
            "preprocessingIdentifier": "synthetic-v1",
        ],
        [
            "operation": "term-scores",
            "candidates": [["components": ["a"], "frequency": NSNull()]],
            "preprocessingIdentifier": "synthetic-v1",
        ],
        [
            "operation": "kh-collocation",
            "counts": [
                "jointCount": 1, "nodeFrequency": 2,
                "collocateFrequency": 3, "corpusTokenCount": 10, "windowSpan": 2,
                "secret-canary": 1,
            ],
        ],
        [
            "operation": "matrix-zscore", "matrix": [[1, 2]], "axis": "rows",
            "constantPolicy": NSNull(),
        ],
        ["operation": "continue-classifier", "documents": [], "labels": [], "state": NSNull()],
        [
            "operation": "incremental-classifier", "documents": [["x"]], "labels": ["A"],
            "state": [:],
        ],
    ]
    for fields in invalid {
        do {
            _ = try GlifiStudioTextAnalysisRequest.decode(khRequestData(fields))
            Issue.record("Invalid KH nested request accepted")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "invalidInput")
            #expect(failure.arguments.isEmpty)
            #expect(!String(describing: failure).contains("secret-canary"))
        }
    }
    let duplicate = Data(
        #"{"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"kh-collocation","counts":{"jointCount":1,"nodeFrequency":2,"collocateFrequency":3,"corpusTokenCount":10,"windowSpan":2,"\u0077indowSpan":4}}"#
            .utf8)
    #expect(throws: GlifiStudioFailure.self) {
        try GlifiStudioTextAnalysisRequest.decode(duplicate)
    }
}

@Test("KH transport aggregate budgets include empty candidate and token collections")
func khAnalysisAggregateAdmission() throws {
    let candidates = Array(
        repeating: GlifiStudioTermCandidate(components: [], frequency: 1), count: 250_001)
    let request = GlifiStudioTextAnalysisRequest.advanced(
        .kh(
            .termScores(
                candidates: candidates, preprocessingIdentifier: "synthetic-v1")))
    do {
        _ = try request.canonicalData()
        Issue.record("Aggregate collection count escaped the budget")
    } catch let failure {
        #expect(failure.category == "insufficientResources")
    }
    let nonfinite = GlifiStudioTextAnalysisRequest.advanced(
        .kh(
            .wordContext(
                levels: [
                    .init(
                        level: .sentence, alpha: .infinity, targetCounts: [[1]],
                        contextCounts: [[1]])
                ],
                targetIDs: ["a"], contextIDs: ["b"])))
    #expect(throws: GlifiStudioFailure.self) { try nonfinite.canonicalData() }
}

@Test("New KH methods return typed payloads and retain candidate scientific status")
func khAnalysisNativePayloads() async throws {
    let result = try await GlifiStudioKHAnalysis.execute(
        .sampleZScores(
            matrix: [[1, 2, 3]], axis: .rows))
    guard case let .advanced(.kh(.matrix(values))) = result.payload else {
        Issue.record("Wrong KH payload")
        return
    }
    #expect(values == [[-1, 0, 1]])
    #expect(result.methodIdentifier == "KH-sample-z-score-v1")
    #expect(result.validationStatus == "candidate")
    let raw = try khRequestData([
        "operation": "matrix-zscore", "matrix": [[1, 2, 3]], "axis": "rows",
    ])
    let transported = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: raw)
    #expect(try khEncoded(transported) == khEncoded(result))
    let primary = try await GlifiStudioKHAnalysis.execute(
        .ordinalMDS(
            matrix: [[0, 1, 1], [1, 0, 1], [1, 1, 0]], dimensions: 1))
    #expect(primary.methodIdentifier == "MDS-ordinal-SMACOF-primary-ties-normalized-raw-stress-v1")
    let legacy = try await GlifiStudioTextAnalytics.executeTextAnalysis(
        .mds(
            matrix: [[0, 1, 1], [1, 0, 1], [1, 1, 0]], dimensions: 1, method: .ordinal))
    #expect(legacy.methodIdentifier == "MDS-ordinal-SMACOF-secondary-ties-normalized-raw-stress-v1")
}

@Test("An incremental state can cross JSON, expand vocabulary and reproduce direct posterior math")
func khAnalysisIncrementalContinuation() async throws {
    let first = try await GlifiStudioKHAnalysis.execute(
        .incrementalClassifier(
            documents: [["a", "a"]], labels: ["A"], smoothing: 0.5))
    guard case let .advanced(.kh(.incrementalClassifier(initial))) = first.payload else {
        Issue.record("Wrong initial classifier payload")
        return
    }
    #expect(initial.model == nil)
    let stateObject = try #require(
        JSONSerialization.jsonObject(with: khEncoded(initial.state)) as? [String: Any])
    let data = try khRequestData([
        "operation": "continue-classifier", "state": stateObject,
        "documents": [["b"]], "labels": ["B"], "predictionDocuments": [["a"], ["b"], ["unknown"]],
    ])
    let final = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: data)
    guard case let .advanced(.kh(.incrementalClassifier(value))) = final.payload else {
        Issue.record("Wrong continued classifier payload")
        return
    }
    #expect(value.state.vocabulary == ["a", "b"])
    #expect(value.state.tokenCounts == [[2, 0], [0, 1]])
    #expect(initial.state.vocabulary == ["a"])
    let prediction = try #require(value.predictions)
    #expect(prediction.labels == ["A", "B", "A"])
    #expect(prediction.ignoredTokenCounts == [0, 0, 1])
    #expect(abs(prediction.probabilities[0][0] - 10.0 / 13) < 1e-14)
    #expect(abs(prediction.probabilities[1][1] - 9.0 / 11) < 1e-14)
    #expect(prediction.probabilities[2] == [0.5, 0.5])
}

@Test("KH failures retain their domain category instead of becoming invariant failures")
func khAnalysisFailureMapping() async throws {
    do {
        _ = try await GlifiStudioKHAnalysis.execute(
            .incrementalClassifier(
                documents: [["a"]], labels: ["A"], predictionDocuments: [["a"]]))
        Issue.record("A one-class state was used for prediction")
    } catch let failure {
        #expect(failure.category == "insufficientData")
        #expect(failure.retainedState == "unchanged")
    }
    let invalid = GlifiStudioNaiveBayesTrainingState(
        classes: ["A", "B"], vocabulary: ["a"], documentCounts: [1, 1], tokenCounts: [[-1], [1]])
    do {
        _ = try await GlifiStudioKHAnalysis.execute(
            .continueClassifier(state: invalid, documents: [], labels: []))
        Issue.record("Negative training counts were restored")
    } catch let failure {
        #expect(failure.category == "invalidInput")
        #expect(failure.arguments.isEmpty)
    }
}

@Test("KH operations propagate typed pre-cancellation without partial results")
func khAnalysisCancellation() async throws {
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        return try await GlifiStudioKHAnalysis.execute(
            .sampleZScores(matrix: [[1, 2]], axis: .rows))
    }
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch let failure as GlifiStudioFailure { #expect(failure.category == "cancelled") }
}

@Test("Document-condition association admits overlapping marginals and preserves near-Int.max counts")
func khAnalysisWordAssociationCounts() async throws {
    let result = try await GlifiStudioKHAnalysis.execute(.wordAssociation(.init(
        jointCount: 70, conditionDocumentCount: 80, termDocumentCount: 90, totalDocumentCount: 100)))
    guard case let .advanced(.kh(.wordAssociation(value))) = result.payload else {
        Issue.record("Wrong document association payload"); return
    }
    #expect(abs(try #require(value.differential) + 0.025) < 1e-15)
    #expect(!value.isPositiveAssociation)
    let identical = try await GlifiStudioKHAnalysis.execute(.wordAssociation(.init(
        jointCount: Int.max, conditionDocumentCount: Int.max,
        termDocumentCount: Int.max, totalDocumentCount: Int.max)))
    guard case let .advanced(.kh(.wordAssociation(equal))) = identical.payload else {
        Issue.record("Wrong large-count association payload"); return
    }
    #expect(equal.jaccard == 1)
    #expect(equal.ochiai == 1)
    #expect(equal.differential == 0)
    #expect(!equal.isPositiveAssociation)
    do {
        _ = try await GlifiStudioKHAnalysis.execute(.wordAssociation(.init(
            jointCount: 0, conditionDocumentCount: 8, termDocumentCount: 8, totalDocumentCount: 10)))
        Issue.record("An impossible document universe was accepted")
    } catch let failure { #expect(failure.category == "invalidInput") }
}
