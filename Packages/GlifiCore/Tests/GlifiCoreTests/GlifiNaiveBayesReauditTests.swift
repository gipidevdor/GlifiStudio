// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("Naive Bayes cross-validation bounds the class-squared confusion matrix")
func naiveBayesReauditConfusionBudget() throws {
    let documents = Array(repeating: ["x"], count: 6)
    let labels = ["A", "A", "B", "B", "C", "C"]
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.crossValidate(
            documents: documents, labels: labels, folds: 2, seed: 0,
            limits: .init(maximumCells: 4))
    }
    let result = try GlifiNaiveBayes.crossValidate(
        documents: documents, labels: labels, folds: 2, seed: 0,
        limits: .init(maximumCells: 9))
    #expect(result.confusion.count == 3)
    #expect(result.confusion.reduce(0) { $0 + $1.reduce(0, +) } == 6)
}

@Test("Naive Bayes prediction bounds the complete probability output before scoring")
func naiveBayesReauditPredictionBudget() throws {
    let model = try GlifiNaiveBayes.train(
        documents: [["x"], ["x"], ["x"]], labels: ["A", "B", "C"])
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.predict([["x"], ["x"]], using: model, limits: .init(maximumCells: 4))
    }
    let predictions = try GlifiNaiveBayes.predict(
        [["x"], []], using: model, limits: .init(maximumCells: 6))
    #expect(predictions.count == 2)
    for prediction in predictions {
        #expect(prediction.label == "A")
        #expect(prediction.probabilities.allSatisfy { abs($0 - 1.0 / 3) < 1e-15 })
    }
}

@Test("Naive Bayes cumulative work includes dense training and held-out class scores")
func naiveBayesReauditWorkBudget() throws {
    let documents = Array(repeating: ["x"], count: 4)
    let labels = ["A", "A", "B", "B"]
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.train(
            documents: documents, labels: labels, limits: .init(maximumWork: 8))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.crossValidate(
            documents: documents, labels: labels, folds: 2, seed: 0,
            limits: .init(maximumWork: 8))
    }
    let model = try GlifiNaiveBayes.train(documents: documents, labels: labels)
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.predict(documents, using: model, limits: .init(maximumWork: 8))
    }
}

@Test("Naive Bayes rejects cancelled training, inference and validation before allocations")
func naiveBayesReauditCancellation() async throws {
    let model = try GlifiNaiveBayes.train(documents: [["x"], ["y"]], labels: ["A", "B"])
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        do {
            _ = try GlifiNaiveBayes.train(documents: [["x"], ["y"]], labels: ["A", "B"])
            Issue.record("Cancelled training succeeded")
        } catch { #expect(error is CancellationError) }
        do {
            _ = try GlifiNaiveBayes.predict([["x"]], using: model)
            Issue.record("Cancelled prediction succeeded")
        } catch { #expect(error is CancellationError) }
        do {
            _ = try GlifiNaiveBayes.crossValidate(
                documents: [["x"], ["x"], ["y"], ["y"]],
                labels: ["A", "A", "B", "B"], folds: 2, seed: 0)
            Issue.record("Cancelled validation succeeded")
        } catch { #expect(error is CancellationError) }
    }
    await task.value
}
