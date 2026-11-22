// SPDX-License-Identifier: BSD-3-Clause

import Accelerate
import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("LDA completion: native prediction kernels and model-selection Release workloads")
func khCompletionLDABenchmark() throws {
    let theta = [0.25, 0.5, 0.25]
    let word = [0.6, 0.2, 0.8]
    #expect(abs(vDSP.dot(theta, word) - 0.45) < 1e-12)
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    var generator = GlifiSplitMix64(seed: 231)
    let vectors = (0..<2_000).map { _ in
        (0..<64).map { _ in Double(generator.next() % 1_000) / 1_000 }
    }
    let reference = vectors.map { row in zip(row, vectors[0]).reduce(0.0) { $0 + $1.0 * $1.1 } }
    let native = vectors.map { vDSP.dot($0, vectors[0]) }
    #expect(zip(reference, native).allSatisfy { abs($0 - $1) <= 1e-12 })
    let digest = try pipelineBenchmarkDigest(vectors)
    try measurePipelineOptimization(
        identifier: "kh-completion-lda-dot-scalar-2000x64",
        generator: "SplitMix64 seed231, 2000 vectors by64, full scalar dot products",
        fixtureDigest: digest, expected: reference,
        body: { vectors.map { row in zip(row, vectors[0]).reduce(0.0) { $0 + $1.0 * $1.1 } } },
        checksum: { try pipelineBenchmarkDigest($0) })
    try measurePipelineOptimization(
        identifier: "kh-completion-lda-dot-vDSP-2000x64",
        generator: "Same vectors and order; Apple vDSP dot products, full output",
        fixtureDigest: digest, expected: native,
        body: { vectors.map { vDSP.dot($0, vectors[0]) } },
        checksum: { try pipelineBenchmarkDigest($0) })
    let documents = (0..<32).map { document in
        (0..<32).map { token in "t\((document % 4 * 4 + token % 8) % 16)" }
    }
    let expected = try GlifiLDAModelSelection.select(
        documents: documents, candidateTopicCounts: [2, 3], seed: 231,
        folds: 2, burnIn: 4, sampleCount: 4, thinning: 2)
    try measurePipelineOptimization(
        identifier: "kh-completion-lda-selection-32x32-k2-3-folds2",
        generator: "32 synthetic documents,32 tokens,16 terms,K2/3,2folds,seed231,sweeps12",
        fixtureDigest: try pipelineBenchmarkDigest(documents), expected: expected,
        body: {
            try GlifiLDAModelSelection.select(
                documents: documents, candidateTopicCounts: [2, 3], seed: 231,
                folds: 2, burnIn: 4, sampleCount: 4, thinning: 2)
        }, checksum: { try pipelineBenchmarkDigest(LDASelectionBenchmarkSnapshot($0)) })
}

private struct LDASelectionBenchmarkSnapshot: Encodable {
    let selectedTopicCount: Int
    let foldAssignments: [Int]
    let vocabulary: [String]
    let documentTopics: [[Double]]
    let topicTerms: [[Double]]
    let assignments: [[Int]]
    let seed: UInt64
    let alpha: Double
    let beta: Double
    let burnIn: Int
    let sampleCount: Int
    let thinning: Int
    let trainingPerplexity: Double
    let sampleLogWordLikelihoods: [Double]
    let candidates: [LDACandidateBenchmarkSnapshot]

    init(_ value: GlifiLDAModelSelectionResult) {
        selectedTopicCount = value.selectedTopicCount
        foldAssignments = value.foldAssignments
        vocabulary = value.selectedModel.vocabulary
        documentTopics = value.selectedModel.documentTopics
        topicTerms = value.selectedModel.topicTerms
        assignments = value.selectedModel.assignments
        seed = value.selectedModel.seed
        alpha = value.selectedModel.alpha
        beta = value.selectedModel.beta
        burnIn = value.selectedModel.burnIn
        sampleCount = value.selectedModel.sampleCount
        thinning = value.selectedModel.thinning
        trainingPerplexity = value.selectedModel.trainingPerplexity
        sampleLogWordLikelihoods = value.selectedModel.sampleLogWordLikelihoods
        candidates = value.candidates.map(LDACandidateBenchmarkSnapshot.init)
    }
}

private struct LDACandidateBenchmarkSnapshot: Encodable {
    let topicCount: Int
    let metrics: [Double?]
    let unavailableReasons: [String: String]
    let trainingPerplexity: Double
    let heldOutPerplexity: Double?
    let foldValues: [[Double]]

    init(_ value: GlifiLDACandidateEvaluation) {
        topicCount = value.topicCount
        metrics = [
            value.metrics.caoJuan2009, value.metrics.arun2010,
            value.metrics.deveaud2014, value.metrics.griffiths2004,
        ]
        unavailableReasons = value.metrics.unavailableReasons
        trainingPerplexity = value.trainingPerplexity
        heldOutPerplexity = value.heldOutPerplexity
        foldValues = value.foldScores.map {
            [
                $0.logLikelihood, $0.perplexity, Double($0.evaluatedTokenCount),
                Double($0.observedTokenCount), Double($0.ignoredTokenCount),
            ]
        }
    }
}
