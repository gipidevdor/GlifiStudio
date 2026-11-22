// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Prediction admits the frozen 100k vocabulary before its table and hash lookups")
func naiveBayesVocabularyBudgetLargeModel() throws {
    let vocabulary = (0..<100_000).map { String(format: "t%06d", $0) }
    let model = vocabularyBudgetUniformModel(vocabulary)
    do {
        _ = try GlifiNaiveBayes.predict(
            [[vocabulary[0]]], using: model, limits: .init(maximumWork: 5))
        Issue.record("A five-unit budget admitted a 100k-entry lookup")
    } catch let failure as GlifiFailure {
        #expect(failure.category == .insufficientResources)
        #expect(failure.code == "exploratory.resource-limit")
    }
    let result = try GlifiNaiveBayes.predict(
        [[vocabulary[0]]], using: model, limits: .init(maximumWork: 5_000_000))
    #expect(result.count == 1)
    #expect(result[0].label == "A")
    #expect(result[0].probabilities == [0.5, 0.5])
    #expect(result[0].ignoredTokenCount == 0)
    #expect(model.vocabulary == vocabulary)
}

@Test("Prediction charges vocabulary and token UTF-8 bytes in the same cumulative budget")
func naiveBayesVocabularyBudgetUnicodeBytes() throws {
    let longTerm = String(repeating: "é", count: 128)
    let model = vocabularyBudgetUniformModel(["a", longTerm])
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.predict([["a"]], using: model, limits: .init(maximumWork: 100))
    }
    let known = try GlifiNaiveBayes.predict(
        [[longTerm]], using: model, limits: .init(maximumWork: 2_000))
    #expect(known[0].probabilities == [0.5, 0.5])
    #expect(known[0].ignoredTokenCount == 0)
    let longUnknown = String(repeating: "e\u{301}", count: 1_024)
    let small = vocabularyBudgetUniformModel(["a"])
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.predict([[longUnknown]], using: small, limits: .init(maximumWork: 100))
    }
    let ignored = try GlifiNaiveBayes.predict(
        [[longUnknown]], using: small, limits: .init(maximumWork: 10_000))
    #expect(ignored[0].probabilities == [0.5, 0.5])
    #expect(ignored[0].ignoredTokenCount == 1)
}

@Test("Prediction admits lookup cells independently of the small posterior output")
func naiveBayesVocabularyBudgetLookupCells() throws {
    let model = vocabularyBudgetUniformModel(["a", "b", "c"])
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.predict([["a"]], using: model, limits: .init(maximumCells: 2))
    }
    let result = try GlifiNaiveBayes.predict([["a"]], using: model, limits: .init(maximumCells: 3))
    #expect(result[0].probabilities == [0.5, 0.5])
}

@Test("Vocabulary admission preserves scores, OOV counts, canonical order and model values")
func naiveBayesVocabularyBudgetPreservesPredictions() throws {
    let model = try GlifiNaiveBayes.train(
        documents: [["apple", "apple"], ["pear", "pear"]], labels: ["A", "B"])
    let original = model
    let documents = [["apple", "apple", "unknown"], ["pear"], []]
    let usual = try GlifiNaiveBayes.predict(documents, using: model)
    let bounded = try GlifiNaiveBayes.predict(
        documents, using: model, limits: .init(maximumWork: 1_000))
    #expect(bounded == usual)
    #expect(model == original)
    #expect(bounded.map(\.label) == ["A", "B", "A"])
    #expect(bounded.map(\.ignoredTokenCount) == [1, 0, 0])
    #expect(bounded.allSatisfy { $0.classes == ["A", "B"] })
    let expected = [[0.9, 0.1], [0.25, 0.75], [0.5, 0.5]]
    for (actual, reference) in zip(bounded.map(\.probabilities), expected) {
        for (left, right) in zip(actual, reference) { #expect(abs(left - right) < 1e-14) }
    }
}

@Test("Prediction reserves sparse feature ordering before constructing the table")
func naiveBayesVocabularyBudgetSparseOrdering() throws {
    let vocabulary = (0..<1_024).map { String(format: "t%04d", $0) }
    let model = vocabularyBudgetUniformModel(vocabulary)
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.predict([vocabulary], using: model, limits: .init(maximumWork: 25_000))
    }
    let output = try GlifiNaiveBayes.predict(
        [Array(vocabulary.reversed())], using: model, limits: .init(maximumWork: 100_000))
    #expect(output[0].probabilities == [0.5, 0.5])
    #expect(output[0].ignoredTokenCount == 0)
}

private func vocabularyBudgetUniformModel(_ vocabulary: [String]) -> GlifiNaiveBayesModel {
    GlifiNaiveBayesModel(
        classes: ["A", "B"], vocabulary: vocabulary,
        logPriors: [log(0.5), log(0.5)],
        logLikelihoods: Array(
            repeating: [Double](repeating: -log(Double(vocabulary.count)), count: vocabulary.count),
            count: 2), smoothing: 1)
}
