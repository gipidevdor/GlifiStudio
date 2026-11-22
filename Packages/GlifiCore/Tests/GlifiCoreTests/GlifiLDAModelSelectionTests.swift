// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import Testing

@Test("Le quattro diagnostiche LDA coincidono con formule indipendenti")
func ldaTuningIndependentFormulas() throws {
    let result = try GlifiLDAModelSelection.metrics(
        topicTerms: [[0.8, 0.2], [0.2, 0.8]],
        documentTopics: [[0.75, 0.25], [0.25, 0.75]], documentLengths: [2, 2],
        logWordLikelihoods: [-log(2), -log(8)])
    #expect(abs(try #require(result.caoJuan2009) - 8.0 / 17) < 1e-12)
    #expect(abs(try #require(result.deveaud2014) - 0.3 * log(4)) < 1e-12)
    #expect(abs(try #require(result.arun2010) + 0.4 * log(0.6)) < 1e-12)
    #expect(abs(try #require(result.griffiths2004) - log(0.2)) < 1e-12)
    #expect(result.unavailableReasons.isEmpty)
}

@Test("Le metriche non definite mantengono motivo e assenza del valore")
func ldaTuningUndefinedMetrics() throws {
    let single = try GlifiLDAModelSelection.metrics(
        topicTerms: [[0.5, 0.5]], documentTopics: [[1]], documentLengths: [4])
    #expect(single.caoJuan2009 == nil)
    #expect(single.deveaud2014 == nil)
    #expect(single.griffiths2004 == nil)
    #expect(single.unavailableReasons["caoJuan2009"] == "requires-multiple-topics")
    let deficient = try GlifiLDAModelSelection.metrics(
        topicTerms: [[0.5, 0.5], [0.5, 0.5]], documentTopics: [[0.5, 0.5]],
        documentLengths: [4])
    #expect(deficient.arun2010 == nil)
    #expect(deficient.unavailableReasons["arun2010"] == "rank-deficient-topic-matrix")
    let zeros = try GlifiLDAModelSelection.metrics(
        topicTerms: [[1, 0], [0, 1]], documentTopics: [[0.5, 0.5]], documentLengths: [4])
    #expect(zeros.deveaud2014 == nil)
    #expect(zeros.caoJuan2009 == 0)
}

@Test("Il log harmonic mean resta finito per likelihood molto piccole")
func ldaTuningLogDomainStability() throws {
    let value = try GlifiLDAModelSelection.metrics(
        topicTerms: [[1]], documentTopics: [[1]], documentLengths: [1],
        logWordLikelihoods: [-10_000, -10_001])
    let expected = -10_001 - log((1 + exp(-1.0)) / 2)
    #expect(abs(try #require(value.griffiths2004) - expected) < 1e-12)
}

@Test("Le likelihood collassate sono opt-in e non alterano il campionatore")
func ldaRetainedLikelihoodExactSingleTopic() throws {
    let documents = [["a", "a"], ["b", "b"]]
    let plain = try GlifiLatentDirichletAllocation.fit(
        documents: documents, topicCount: 1, seed: 5, beta: 1,
        burnIn: 0, sampleCount: 3, thinning: 1)
    let retained = try GlifiLatentDirichletAllocation.fit(
        documents: documents, topicCount: 1, seed: 5, beta: 1,
        burnIn: 0, sampleCount: 3, thinning: 1, retainLogLikelihoods: true)
    #expect(plain.sampleLogWordLikelihoods.isEmpty)
    #expect(retained.sampleLogWordLikelihoods.count == 3)
    #expect(retained.sampleLogWordLikelihoods.allSatisfy { abs($0 - log(1.0 / 30)) < 1e-12 })
    #expect(retained.assignments == plain.assignments)
    #expect(retained.documentTopics == plain.documentTopics)
    #expect(retained.topicTerms == plain.topicTerms)
    #expect(retained.trainingPerplexity == plain.trainingPerplexity)
}

@Test("La perplexity held-out a un topic ha oracolo esatto e conta gli OOV")
func ldaHeldOutExactAndCoverage() throws {
    let model = try GlifiLatentDirichletAllocation.fit(
        documents: [["a", "b"]], topicCount: 1, seed: 1, beta: 1,
        burnIn: 0, sampleCount: 1, thinning: 1)
    let original = model
    let score = try GlifiLDAModelSelection.heldOutScore(
        documents: [["a", "a", "b", "unknown"]], model: model, seed: 6,
        burnIn: 0, sampleCount: 2, thinning: 1)
    #expect(abs(score.perplexity - 2) < 1e-12)
    #expect(abs(score.logLikelihood + 2 * log(2.0)) < 1e-12)
    #expect(score.evaluatedTokenCount == 2)
    #expect(score.observedTokenCount == 1)
    #expect(score.ignoredTokenCount == 1)
    #expect(model == original)
    let priorOnly = try GlifiLDAModelSelection.heldOutScore(
        documents: [["a"]], model: model, seed: 6,
        burnIn: 0, sampleCount: 1, thinning: 1)
    #expect(priorOnly.observedTokenCount == 0)
    #expect(abs(priorOnly.perplexity - 2) < 1e-12)
}

@Test("Griffiths a due topic coincide con l'enumerazione esatta degli stati latenti")
func ldaGriffithsExactLatentEnumeration() throws {
    // Two one-token documents. Equal topics have word likelihood 1/6; different
    // topics have 1/4. Their prior masses are both 1/2, so evidence is 5/24.
    let model = try GlifiLatentDirichletAllocation.fit(
        documents: [["a"], ["b"]], topicCount: 2, seed: 190,
        alpha: 0.5, beta: 1, burnIn: 500, sampleCount: 2_000, thinning: 2,
        retainLogLikelihoods: true)
    #expect(
        model.sampleLogWordLikelihoods.allSatisfy {
            min(abs($0 - log(1.0 / 6)), abs($0 - log(1.0 / 4))) < 1e-12
        })
    let metrics = try GlifiLDAModelSelection.metrics(
        topicTerms: model.topicTerms, documentTopics: model.documentTopics,
        documentLengths: [1, 1], logWordLikelihoods: model.sampleLogWordLikelihoods)
    #expect(abs(exp(try #require(metrics.griffiths2004)) - 5.0 / 24) < 0.01)
}

@Test("I fold ricostruiscono il vocabolario senza usare le parole del test")
func ldaSelectionTrainingVocabularyIsolation() throws {
    let documents = (0..<4).map { ["common", "common", "common", "unique-\($0)"] }
    let result = try GlifiLDAModelSelection.select(
        documents: documents, candidateTopicCounts: [1], seed: 9, folds: 2,
        beta: 1, burnIn: 0, sampleCount: 2, thinning: 1)
    #expect(result.selectedTopicCount == 1)
    #expect(Set(result.foldAssignments) == [0, 1])
    let candidate = try #require(result.candidates.first)
    #expect(candidate.foldScores.reduce(0) { $0 + $1.ignoredTokenCount } == 4)
    #expect(candidate.foldScores.reduce(0) { $0 + $1.evaluatedTokenCount } == 8)
    #expect(abs(try #require(candidate.heldOutPerplexity) - 11.0 / 7) < 1e-12)
}

@Test("L'ordine dei candidati non cambia split, seed o modello selezionato")
func ldaSelectionCandidateOrderAndDeterminism() throws {
    let documents = [["a", "a", "b"], ["a", "b", "b"], ["a", "b", "a"], ["b", "b", "a"]]
    let first = try GlifiLDAModelSelection.select(
        documents: documents, candidateTopicCounts: [2, 1], seed: 12, folds: 2,
        burnIn: 2, sampleCount: 3, thinning: 1)
    let second = try GlifiLDAModelSelection.select(
        documents: documents, candidateTopicCounts: [1, 2], seed: 12, folds: 2,
        burnIn: 2, sampleCount: 3, thinning: 1)
    #expect(first == second)
    #expect(first.candidates.map(\.topicCount) == [1, 2])
    let metricsOnly = try GlifiLDAModelSelection.select(
        documents: documents, candidateTopicCounts: [2], seed: 12,
        criterion: .caoJuan2009, folds: 0, burnIn: 1, sampleCount: 2, thinning: 1)
    #expect(metricsOnly.foldAssignments.isEmpty)
    #expect(metricsOnly.candidates[0].heldOutPerplexity == nil)
}

@Test("Richieste LDA non valide, budget e test solo OOV falliscono chiusi")
func ldaSelectionValidationAndLimits() throws {
    let documents = [["a", "b"], ["b", "a"]]
    #expect(throws: GlifiFailure.self) {
        try GlifiLDAModelSelection.select(
            documents: documents, candidateTopicCounts: [2, 2], seed: 0)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLDAModelSelection.select(
            documents: documents, candidateTopicCounts: [1], seed: 0, folds: 0)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLDAModelSelection.select(
            documents: documents, candidateTopicCounts: [1], seed: 0, folds: 2,
            limits: GlifiExploratoryLimits(maximumWork: 1))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLDAModelSelection.metrics(
            topicTerms: [[0.1, 0.2]], documentTopics: [[1]], documentLengths: [1])
    }
    let model = try GlifiLatentDirichletAllocation.fit(
        documents: documents, topicCount: 1, seed: 0, burnIn: 0, sampleCount: 1, thinning: 1)
    #expect(throws: GlifiFailure.self) {
        try GlifiLDAModelSelection.heldOutScore(
            documents: [["unknown"]], model: model, seed: 0,
            burnIn: 0, sampleCount: 1, thinning: 1)
    }
}

@Test("La selezione LDA osserva una cancellazione già richiesta")
func ldaSelectionCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiLDAModelSelection.select(
            documents: [["a"], ["a"]], candidateTopicCounts: [1], seed: 0, folds: 2)
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled selection succeeded")
    } catch is CancellationError {} catch {
        Issue.record("Unexpected cancellation result: \(error)")
    }
}

@Test(
    "Held-out empty and OOV documents skip sweeps and prior-only prediction is analytic",
    .timeLimit(.minutes(1)))
func ldaHeldOutEmptyContextWorkBound() throws {
    let model = try GlifiLatentDirichletAllocation.fit(
        documents: [["a", "b"]], topicCount: 1, seed: 1, beta: 1,
        burnIn: 0, sampleCount: 1, thinning: 1)
    var documents = [[String]](repeating: [], count: 20_000)
    for index in 0..<5_000 { documents[index] = ["unknown"] }
    documents[19_999] = ["a"]
    let score = try GlifiLDAModelSelection.heldOutScore(
        documents: documents, model: model, seed: 6,
        burnIn: 10_000, sampleCount: 10_000, thinning: 1_000,
        limits: GlifiExploratoryLimits(maximumWork: 4))
    #expect(score.perplexity == 2)
    #expect(score.observedTokenCount == 0)
    #expect(score.evaluatedTokenCount == 1)
    #expect(score.ignoredTokenCount == 5_000)
}

@Test("LDA preflight bounds document storage and theta work before allocation or fitting")
func ldaFitEmptyDocumentAdmission() throws {
    let emptyHeavy = [[String]](repeating: [], count: 1_000) + [["a"]]
    #expect(throws: GlifiFailure.self) {
        try GlifiLatentDirichletAllocation.fit(
            documents: emptyHeavy, topicCount: 1, seed: 0,
            burnIn: 0, sampleCount: 1_000, thinning: 1,
            limits: GlifiExploratoryLimits(maximumWork: 10_000))
    }
    // An invalid vocabulary would fail in table construction; these codes prove that
    // parameters and dense document-topic admission are checked before that allocation.
    do {
        _ = try GlifiLatentDirichletAllocation.fit(documents: [[""]], topicCount: 0, seed: 0)
        Issue.record("Invalid topic count was accepted")
    } catch let failure as GlifiFailure { #expect(failure.code == "lda.invalid-parameters") }
    do {
        _ = try GlifiLatentDirichletAllocation.fit(
            documents: [[String]](repeating: [""], count: 100), topicCount: 2, seed: 0,
            limits: GlifiExploratoryLimits(maximumCells: 1))
        Issue.record("Over-budget document-topic storage was accepted")
    } catch let failure as GlifiFailure { #expect(failure.code == "exploratory.resource-limit") }
}

@Test("LDA selection admits the aggregate candidate work and bounds held-out document count")
func ldaSelectionAggregateAdmission() throws {
    #expect(throws: GlifiFailure.self) {
        try GlifiLDAModelSelection.select(
            documents: [["a", "b"], ["a", "b"]], candidateTopicCounts: [1, 2], seed: 0,
            criterion: .griffiths2004, folds: 0, burnIn: 0, sampleCount: 2, thinning: 1,
            limits: GlifiExploratoryLimits(maximumWork: 100))
    }
    let model = try GlifiLatentDirichletAllocation.fit(
        documents: [["a"]], topicCount: 1, seed: 0,
        burnIn: 0, sampleCount: 1, thinning: 1)
    do {
        _ = try GlifiLDAModelSelection.heldOutScore(
            documents: [[String]](repeating: [], count: 20_001), model: model, seed: 0)
        Issue.record("Too many held-out documents were accepted")
    } catch let failure as GlifiFailure { #expect(failure.code == "lda-selection.invalid-fold-in") }
}

@Test("LDA fitter and held-out inference observe cancellation before preparation")
func ldaPreparationCancellation() async throws {
    let model = try GlifiLatentDirichletAllocation.fit(
        documents: [["a"]], topicCount: 1, seed: 0,
        burnIn: 0, sampleCount: 1, thinning: 1)
    for operation in 0..<2 {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            if operation == 0 {
                _ = try GlifiLatentDirichletAllocation.fit(
                    documents: [[String]](repeating: ["a"], count: 1_000), topicCount: 2, seed: 0)
            } else {
                _ = try GlifiLDAModelSelection.heldOutScore(
                    documents: [[String]](repeating: [], count: 20_000), model: model, seed: 0)
            }
        }
        do {
            try await task.value
            Issue.record("Preparation ignored cancellation")
        } catch is CancellationError {}
    }
}
