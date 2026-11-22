// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Incremental counts reproduce pooled training across new words and classes")
func incrementalNaiveBayesMatchesPooledTraining() throws {
    let documents = [["red", "red"], ["blue"], ["green", "red"], [], ["new", "blue"]]
    let labels = ["b", "a", "c", "b", "a"]
    let first = try GlifiIncrementalNaiveBayes.train(
        documents: Array(documents.prefix(2)), labels: Array(labels.prefix(2)), smoothing: 0.5)
    let state = try GlifiIncrementalNaiveBayes.update(
        first, documents: Array(documents.dropFirst(2)), labels: Array(labels.dropFirst(2)))
    let batch = try GlifiNaiveBayes.train(documents: documents, labels: labels, smoothing: 0.5)
    #expect(try state.model() == batch)
    #expect(first.classes == ["a", "b"])
    #expect(first.vocabulary == ["blue", "red"])
    #expect(state.classes == ["a", "b", "c"])
    #expect(state.vocabulary == ["blue", "green", "new", "red"])
    let reordered = try GlifiIncrementalNaiveBayes.train(
        documents: Array(documents.reversed()), labels: Array(labels.reversed()), smoothing: 0.5)
    #expect(reordered == state)
    let heldOut = [["red"], ["new", "green"], ["oov"], []]
    #expect(
        try GlifiNaiveBayes.predict(heldOut, using: state.model())
            == GlifiNaiveBayes.predict(heldOut, using: batch))
    #expect(try GlifiIncrementalNaiveBayes.update(state, documents: [], labels: []) == state)
}

@Test("A one-class first batch can be continued without retaining documents")
func incrementalNaiveBayesContinuesOneClass() throws {
    let first = try GlifiIncrementalNaiveBayes.train(documents: [["a", "a"]], labels: ["A"])
    #expect(throws: GlifiFailure.self) { try first.model() }
    let state = try GlifiIncrementalNaiveBayes.update(first, documents: [["b"]], labels: ["B"])
    let model = try state.model()
    #expect(state.tokenCounts == [[2, 0], [0, 1]])
    #expect(abs(model.logLikelihoods[0][0] - log(3.0 / 4)) < 1e-14)
    #expect(abs(model.logLikelihoods[0][1] - log(1.0 / 4)) < 1e-14)
    #expect(abs(model.logLikelihoods[1][0] - log(1.0 / 3)) < 1e-14)
    #expect(abs(model.logPriors[0] - log(0.5)) < 1e-14)
}

@Test("Transient training statistics reject invalid shape, identities and count overflow")
func incrementalNaiveBayesValidatesRestoredStatistics() throws {
    for (classes, words, docs, tokens) in [
        (["B", "A"], ["x"], [1, 1], [[1], [1]]),
        (["A", "A"], ["x"], [1, 1], [[1], [1]]),
        (["A"], ["x", "x"], [1], [[1, 1]]),
        (["A"], ["x"], [0], [[1]]),
        (["A"], ["x"], [1], [[-1]]),
        (["A"], ["x"], [1], [[]]),
        (["A", "B"], ["x"], [Int.max, 1], [[1], [1]]),
        (["A"], ["x", "y"], [1], [[Int.max, 1]]),
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiNaiveBayesTrainingState(
                classes: classes, vocabulary: words, documentCounts: docs, tokenCounts: tokens)
        }
    }
    let huge = try GlifiNaiveBayesTrainingState(
        classes: ["A", "B"], vocabulary: ["x"], documentCounts: [1, 1],
        tokenCounts: [[Int.max], [1]])
    #expect(throws: GlifiFailure.self) {
        try GlifiIncrementalNaiveBayes.update(huge, documents: [["x"]], labels: ["A"])
    }
    #expect(huge.tokenCounts[0][0] == Int.max)
}

@Test("Incremental training and restoration enforce resource and smoothing limits")
func incrementalNaiveBayesEnforcesAdmission() throws {
    let state = try GlifiIncrementalNaiveBayes.train(
        documents: [["a"], ["b"]], labels: ["A", "B"])
    let limits = GlifiExploratoryLimits(maximumCells: 3)
    #expect(throws: GlifiFailure.self) { try state.model(limits: limits) }
    #expect(throws: GlifiFailure.self) {
        try GlifiIncrementalNaiveBayes.update(state, documents: [], labels: [], limits: limits)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiIncrementalNaiveBayes.train(
            documents: [["a"], ["b"]], labels: ["A", "B"],
            limits: GlifiExploratoryLimits(maximumWork: 3))
    }
    for smoothing in [0, -1, Double.infinity, Double.nan] {
        #expect(throws: GlifiFailure.self) {
            try GlifiIncrementalNaiveBayes.train(
                documents: [["a"]], labels: ["A"], smoothing: smoothing)
        }
    }
}

@Test("Classifier cross-validation returns kappa for its actual held-out predictions")
func incrementalNaiveBayesAgreementMatchesConfusionFormula() throws {
    let documents = [["a"], ["a", "a"], ["b"], ["b", "b"]]
    let labels = ["A", "A", "B", "B"]
    let result = try GlifiNaiveBayes.crossValidateWithAgreement(
        documents: documents, labels: labels, folds: 2, seed: 300)
    #expect(result.evaluation.accuracy == 1)
    #expect(result.agreement.kappa == 1)
    #expect(result.agreement.expectedAgreement == 0.5)
    let ambiguous = try GlifiNaiveBayes.crossValidateWithAgreement(
        documents: [["x"], ["y"], ["x"], ["y"]], labels: labels, folds: 2, seed: 300)
    let confusion = ambiguous.evaluation.confusion
    let n = Double(confusion.flatMap { $0 }.reduce(0, +))
    let observed = Double(confusion[0][0] + confusion[1][1]) / n
    let expected = (0..<2).reduce(0.0) { sum, k in
        let row = Double(confusion[k].reduce(0, +)) / n
        let column = Double(confusion[0][k] + confusion[1][k]) / n
        return sum + row * column
    }
    #expect(abs(ambiguous.agreement.kappa - (observed - expected) / (1 - expected)) < 1e-14)
}

@Test("Incremental classifier operations propagate pre-cancellation")
func incrementalNaiveBayesCancellation() async throws {
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        return try GlifiIncrementalNaiveBayes.train(documents: [["x"]], labels: ["A"])
    }
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch is CancellationError {}
}
