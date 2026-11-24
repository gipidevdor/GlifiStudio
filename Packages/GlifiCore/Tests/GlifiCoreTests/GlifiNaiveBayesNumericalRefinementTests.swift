// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Dominant-term likelihoods retain exact-count complements and avoid false classifier ties")
func khRefinementIncrementalNaiveBayesNearUnitLikelihoods() throws {
    let total = 1_000_000_000_000_000
    let state = try GlifiNaiveBayesTrainingState(
        classes: ["A", "B"], vocabulary: ["x", "y"], documentCounts: [1, 1],
        tokenCounts: [[total - 2, 2], [total - 1, 1]])
    let model = try state.model()
    // Independent Decimal(80): log((N-1)/(N+2)) and log(N/(N+2)).
    let expected = [-2.9999999999999987e-15, -1.999999999999998e-15]
    for category in expected.indices {
        #expect(model.logLikelihoods[category][0] < 0)
        #expect(abs(model.logLikelihoods[category][0] - expected[category]) < 1e-28)
    }
    let predictions = try GlifiNaiveBayes.predict(
        [Array(repeating: "x", count: 100_000)], using: model)
    let prediction = try #require(predictions.first)
    #expect(prediction.label == "B")
    // The log ratio is 100000*log(N/(N-1)); priors are exactly equal.
    let posterior = [0.499999999975, 0.500000000025]
    for category in posterior.indices {
        #expect(abs(prediction.probabilities[category] - posterior[category]) < 5e-15)
    }
    #expect(prediction.ignoredTokenCount == 0)
}

@Test("Batch training admits label and token UTF-8 work before constructing identity tables")
func khRefinementNaiveBayesTrainingUTF8Budget() throws {
    let longA = String(repeating: "a", count: 10_000)
    let longB = String(repeating: "b", count: 10_000)
    for (documents, labels) in [
        ([["x"], ["x"]], [longA, longB]),
        ([[longA], [longA]], ["A", "B"]),
    ] {
        do {
            _ = try GlifiNaiveBayes.train(
                documents: documents, labels: labels, limits: .init(maximumWork: 8))
            Issue.record("An eight-unit budget admitted more than 20000 UTF-8 bytes")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .insufficientResources)
            #expect(failure.code == "exploratory.resource-limit")
        }
        let ordinary = try GlifiNaiveBayes.train(documents: documents, labels: labels)
        let admitted = try GlifiNaiveBayes.train(
            documents: documents, labels: labels, limits: .init(maximumWork: 1_000_000))
        #expect(admitted == ordinary)
    }
}

@Test("The shared stable likelihood preserves pooled training and exact positive zero for one word")
func khRefinementNaiveBayesStableLikelihoodSharedEdges() throws {
    for smoothing in [1, 0.25, Double.leastNonzeroMagnitude] {
        let documents = [["x"], []]
        let labels = ["A", "B"]
        let state = try GlifiIncrementalNaiveBayes.train(
            documents: documents, labels: labels, smoothing: smoothing)
        let batch = try GlifiNaiveBayes.train(
            documents: documents, labels: labels, smoothing: smoothing)
        let continued = try state.model()
        #expect(continued == batch)
        #expect(batch.logLikelihoods.allSatisfy { $0.allSatisfy { $0.bitPattern == 0 } })
    }
}

@Test("A dominant class prior preserves its exact integer complement instead of rounding to one")
func khRefinementDominantPriorExactComplement() throws {
    let state = try GlifiNaiveBayesTrainingState(
        classes: ["A", "B"], vocabulary: ["x", "y"],
        documentCounts: [Int.max - 1, 1], tokenCounts: [[1, 0], [0, 1]])
    let model = try state.model()
    // Independent Decimal(100): log((9223372036854775807-1)/9223372036854775807).
    let expected = -1.0842021724855044e-19
    #expect(model.logPriors[0] < 0)
    #expect(abs(model.logPriors[0] / expected - 1) < 1e-14)
    #expect(model.logPriors[1].isFinite)

    let documents = [["x"], ["x"], ["x"], ["y"]]
    let labels = ["A", "A", "A", "B"]
    let incremental = try GlifiIncrementalNaiveBayes.train(
        documents: documents, labels: labels
    ).model()
    let batch = try GlifiNaiveBayes.train(documents: documents, labels: labels)
    #expect(batch.logPriors == incremental.logPriors)
    for (actual, expected) in zip(batch.logPriors, [-0.2876820724517809, -1.3862943611198906]) {
        #expect(abs(actual - expected) < 1e-15)
    }
}
