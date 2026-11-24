// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La classificazione ricostruisce confusion matrix, micro, macro e weighted")
func linguisticClassificationMatchesCounts() throws {
    let value = try GlifiLinguisticEvaluation.classification(
        gold: ["N", "N", "V", "V", "V"], predicted: ["N", "V", "V", "N", "A"], zeroPolicy: .zero)
    #expect(value.labels == ["A", "N", "V"])
    #expect(value.confusionMatrix == [[0, 0, 0], [0, 1, 1], [1, 1, 1]])
    #expect(value.accuracy.accuracy == 0.4)
    #expect(value.micro.truePositiveCount == 2)
    #expect(value.micro.falsePositiveCount == 3)
    #expect(value.micro.falseNegativeCount == 3)
    #expect(value.micro.f1 == 0.4)
    #expect(abs((value.macro.f1 ?? .nan) - 0.3) < 1e-12)
    #expect(abs((value.weighted.f1 ?? .nan) - 0.44) < 1e-12)
    #expect(abs((value.weighted.precision ?? .nan) - 0.5) < 1e-12)
    #expect(abs((value.weighted.recall ?? .nan) - 0.4) < 1e-12)
}

@Test("I denominatori nulli seguono la policy e non producono accordo perfetto")
func linguisticZeroDenominatorsAreExplicit() throws {
    let undefined = try GlifiLinguisticEvaluation.classification(gold: [], predicted: [])
    #expect(undefined.micro.precision == nil)
    #expect(undefined.micro.recall == nil)
    #expect(undefined.micro.f1 == nil)
    #expect(undefined.accuracy.accuracy == nil)
    #expect(undefined.macro.f1 == nil)
    let zero = try GlifiLinguisticEvaluation.classification(
        gold: [], predicted: [], zeroPolicy: .zero)
    #expect(zero.micro.f1 == 0)
    #expect(zero.weighted.f1 == 0)
    let absentPrediction = try GlifiLinguisticEvaluation.classification(
        gold: ["N"], predicted: ["V"])
    #expect(absentPrediction.perClass.first?.score.precision == nil)
    #expect(absentPrediction.macro.precision == nil)
    #expect(absentPrediction.macro.f1 == 0)
    #expect(absentPrediction.weighted.f1 == 0)
}

@Test("I confini mantengono separate posizione, unità e documento esatti")
func linguisticBoundariesMatchExactUnits() throws {
    let value = try GlifiLinguisticEvaluation.boundaries(
        gold: [[2, 5], [2]], predicted: [[2, 6], [1]], utf8Lengths: [8, 3])
    #expect(value.boundaries.truePositiveCount == 1)
    #expect(value.boundaries.falsePositiveCount == 2)
    #expect(value.boundaries.falseNegativeCount == 2)
    #expect(value.boundaries.f1 == 1.0 / 3)
    #expect(value.units.truePositiveCount == 1)
    #expect(value.units.falsePositiveCount == 4)
    #expect(value.units.falseNegativeCount == 4)
    #expect(value.units.f1 == 0.2)
    #expect(value.documents.correctCount == 0)
    let emptyDocument = try GlifiLinguisticEvaluation.boundaries(
        gold: [[]], predicted: [[]], utf8Lengths: [0])
    #expect(emptyDocument.units.f1 == nil)
    #expect(emptyDocument.documents.accuracy == 1)
}

@Test("NER separa span esatto e tipo e non abbina offset fra documenti")
func linguisticNERSeparatesTypesAndDocuments() throws {
    let person = GlifiEvaluationEntity(lowerBound: 0, upperBound: 3, type: "PER")
    let organization = GlifiEvaluationEntity(lowerBound: 0, upperBound: 3, type: "ORG")
    let partial = GlifiEvaluationEntity(lowerBound: 0, upperBound: 2, type: "PER")
    let value = try GlifiLinguisticEvaluation.namedEntities(
        gold: [[person], [person], []], predicted: [[organization], [partial], [person]],
        utf8Lengths: [5, 5, 5])
    #expect(value.spans.truePositiveCount == 1)
    #expect(value.spans.falsePositiveCount == 2)
    #expect(value.spans.falseNegativeCount == 1)
    #expect(value.spans.f1 == 0.4)
    #expect(value.typedSpans.truePositiveCount == 0)
    #expect(value.typedSpans.falsePositiveCount == 3)
    #expect(value.typedSpans.falseNegativeCount == 2)
    #expect(value.typedSpans.f1 == 0)
}

@Test("Morfologia conserva exact-set e conta valori errati come FP e FN")
func linguisticMorphologyMatchesAttributeValues() throws {
    let value = try GlifiLinguisticEvaluation.morphology(
        gold: [["Number": "Sing", "Gender": "Masc"], ["Number": "Plur"], [:]],
        predicted: [["Number": "Plur", "Gender": "Masc"], [:], ["Case": "Nom"]])
    #expect(value.exactSets.correctCount == 0)
    #expect(value.perAttribute.map(\.label) == ["Case", "Gender", "Number"])
    let number = try #require(value.perAttribute.last)
    #expect(number.support == 2)
    #expect(number.score.truePositiveCount == 0)
    #expect(number.score.falsePositiveCount == 1)
    #expect(number.score.falseNegativeCount == 2)
    #expect(number.score.f1 == 0)
    #expect(value.perAttribute[1].score.f1 == 1)
    let lemmas = try GlifiLinguisticEvaluation.lemmas(
        gold: ["essere", "cane"], predicted: ["essere", "cani"])
    #expect(lemmas.accuracy == 0.5)
    let stratified = try GlifiLinguisticEvaluation.lemmaAnalysis(
        gold: ["essere", "cane", "cane"], predicted: ["essere", "cani", "cane"],
        forms: ["è", "cani", "cane"], partsOfSpeech: ["V", "N", "N"])
    #expect(stratified.errorsByForm.map(\.label) == ["cane", "cani", "è"])
    #expect(stratified.errorsByForm.map(\.errorCount) == [0, 1, 0])
    #expect(stratified.errorsByPartOfSpeech.map(\.observationCount) == [2, 1])
    #expect(stratified.errorsByPartOfSpeech.map(\.errorCount) == [1, 0])
}

@Test("La valutazione rifiuta disallineamenti, annotazioni duplicate, offset e label invalidi")
func linguisticEvaluationRejectsInvalidInputs() {
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.classification(
            gold: Array(repeating: String(repeating: "x", count: 1_024), count: 65_537),
            predicted: Array(repeating: "N", count: 65_537))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.lemmaAnalysis(gold: ["cane"], predicted: ["cane"], forms: [])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.classification(gold: ["N"], predicted: [])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.lemmas(gold: [""], predicted: ["x"])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.classification(
            gold: [String(repeating: "x", count: 1_025)], predicted: ["x"])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.classification(
            gold: (0...256).map(String.init), predicted: (0...256).map(String.init))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.boundaries(gold: [[2, 2]], predicted: [[]], utf8Lengths: [4])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.boundaries(gold: [[-1]], predicted: [[]], utf8Lengths: [4])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.boundaries(gold: [[5]], predicted: [[]], utf8Lengths: [4])
    }
    let entity = GlifiEvaluationEntity(lowerBound: 0, upperBound: 2, type: "N")
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.namedEntities(
            gold: [[entity, entity]], predicted: [[]], utf8Lengths: [4])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.namedEntities(
            gold: [[entity]], predicted: [[]], utf8Lengths: [1])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLinguisticEvaluation.morphology(gold: [["N": ""]], predicted: [[:]])
    }
}

@Test("La morfologia conserva tutti i casi di attributi assenti, errati e corretti")
func linguisticMorphologyExhaustiveTwoAttributeStates() throws {
    var gold: [[String: String]] = []
    var predicted: [[String: String]] = []
    for firstGold in 0..<3 {
        for secondGold in 0..<3 {
            for firstPrediction in 0..<3 {
                for secondPrediction in 0..<3 {
                    var expected: [String: String] = [:]
                    var actual: [String: String] = [:]
                    if firstGold > 0 { expected["A"] = String(firstGold) }
                    if secondGold > 0 { expected["B"] = String(secondGold) }
                    if firstPrediction > 0 { actual["A"] = String(firstPrediction) }
                    if secondPrediction > 0 { actual["B"] = String(secondPrediction) }
                    gold.append(expected)
                    predicted.append(actual)
                }
            }
        }
    }
    let result = try GlifiLinguisticEvaluation.morphology(gold: gold, predicted: predicted)
    // Each attribute has 9 absent/value state pairs, repeated over the other
    // attribute's 9 pairs: two exact positive matches, four FP and four FN pairs.
    #expect(result.exactSets.observationCount == 81)
    #expect(result.exactSets.correctCount == 9)
    #expect(result.perAttribute.map(\.label) == ["A", "B"])
    for attribute in result.perAttribute {
        #expect(attribute.support == 54)
        #expect(attribute.score.truePositiveCount == 18)
        #expect(attribute.score.falsePositiveCount == 36)
        #expect(attribute.score.falseNegativeCount == 36)
        #expect(attribute.score.f1 == 1.0 / 3)
    }
}

@Test("La valutazione osserva la cancellazione prima di produrre un risultato")
func linguisticEvaluationObservesCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiLinguisticEvaluation.classification(gold: ["N"], predicted: ["N"])
    }
    do {
        _ = try await task.value
        Issue.record("Expected cancellation")
    } catch is CancellationError {
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
