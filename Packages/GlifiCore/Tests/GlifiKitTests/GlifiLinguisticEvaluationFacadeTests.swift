// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("La facciata Welch conserva F, gradi di libertà e p dell'oracolo R")
func welchANOVAFacadeMatchesR() async throws {
    let value = try await GlifiStudioTextAnalytics.welchOneWayANOVA([
        [3, 4, 5], [6, 7, 9], [1, 2, 2, 4],
    ])
    #expect(value.methodIdentifier == "WelchOneWayANOVA-v1")
    #expect(abs(value.fStatistic - 9.53739313787025) < 1e-12)
    #expect(abs(value.denominatorDegreesOfFreedom - 4.31788565443043) < 1e-12)
    #expect(abs(value.pValue - 0.0260464767746818) < 1e-12)
}

@Test("La facciata linguistica conserva metriche e contratti headless")
func linguisticEvaluationFacadePreservesMetrics() async throws {
    let classes = try await GlifiStudioLinguisticEvaluation.classification(
        gold: ["N", "N", "V", "V", "V"], predicted: ["N", "V", "V", "N", "A"], zeroPolicy: .zero)
    #expect(classes.methodIdentifier == "LinguisticClassification-exact-v1")
    #expect(classes.confusionMatrix == [[0, 0, 0], [0, 1, 1], [1, 1, 1]])
    #expect(classes.accuracy?.accuracy == 0.4)
    #expect(abs((classes.weighted?.f1 ?? .nan) - 0.44) < 1e-12)
    let boundaries = try await GlifiStudioLinguisticEvaluation.boundaries(
        gold: [[2, 5]], predicted: [[2, 6]], utf8Lengths: [8])
    #expect(boundaries.score?.truePositiveCount == 1)
    #expect(boundaries.exactUnitScore?.truePositiveCount == 1)
    let morphology = try await GlifiStudioLinguisticEvaluation.morphology(
        gold: [["N": "S"]], predicted: [["N": "S"]])
    #expect(morphology.accuracy?.accuracy == 1)
    let lemmas = try await GlifiStudioLinguisticEvaluation.lemmas(
        gold: ["cane"], predicted: ["cane"], forms: ["cani"], partsOfSpeech: ["N"])
    #expect(lemmas.accuracy?.accuracy == 1)
    #expect(lemmas.errorsByForm.first?.label == "cani")
    #expect(lemmas.errorsByPartOfSpeech.first?.errorCount == 0)
    let ner = try await GlifiStudioLinguisticEvaluation.namedEntities(
        gold: [[.init(lowerBound: 0, upperBound: 3, type: "PER")]],
        predicted: [[.init(lowerBound: 0, upperBound: 3, type: "ORG")]], utf8Lengths: [3])
    #expect(ner.score?.f1 == 1)
    #expect(ner.exactUnitScore?.f1 == 0)
    let encoded = try JSONEncoder().encode(classes)
    #expect(
        try JSONDecoder().decode(GlifiStudioLinguisticEvaluationResult.self, from: encoded)
            == classes)
}

@Test("La facciata linguistica conserva le failure tipizzate e la cancellazione")
func linguisticEvaluationFacadePreservesFailures() async {
    do {
        _ = try await GlifiStudioLinguisticEvaluation.classification(gold: ["N"], predicted: [])
        Issue.record("Expected alignment failure")
    } catch {
        #expect(error.code == "evaluation.alignment-mismatch")
        #expect(error.category == "invalidInput")
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioLinguisticEvaluation.lemmas(gold: ["cane"], predicted: ["cane"])
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
