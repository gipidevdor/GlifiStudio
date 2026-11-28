// SPDX-License-Identifier: BSD-3-Clause

import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDEvaluationVariantWorld {
    var request = Data()
    var result: Data?
    var failure: GlifiStudioFailure?
    var variant = ""

    func prepare(_ variant: String) throws {
        self.variant = variant
        let parameters: [String: Any]
        let labels: [String: Any] = [
            "gold": ["N", "N", "V", "V", "V"],
            "predicted": ["N", "V", "V", "N", "A"], "zeroPolicy": "zero",
        ]
        let boundaries: [String: Any] = [
            "gold": [[2, 5]], "predicted": [[2, 6]], "utf8Lengths": [8], "zeroPolicy": "zero",
        ]
        let entities: [String: Any] = [
            "gold": [[["lowerBound": 0, "upperBound": 2, "type": "PER"]]],
            "predicted": [[["lowerBound": 0, "upperBound": 2, "type": "ORG"]]],
            "utf8Lengths": [8], "zeroPolicy": "zero",
        ]
        switch variant {
        case "classification": parameters = labels
        case "lemmas":
            parameters = [
                "gold": ["cane", "andare"], "predicted": ["cane", "andato"],
                "forms": ["cani", "andavano"], "partsOfSpeech": ["N", "V"], "zeroPolicy": "zero",
            ]
        case "boundaries": parameters = boundaries
        case "namedEntities": parameters = entities
        case "boundariesWithText", "namedEntitiesWithText":
            var value = variant == "boundariesWithText" ? boundaries : entities
            value.removeValue(forKey: "utf8Lengths")
            value["texts"] = ["è uno.."]
            parameters = value
        case "morphology":
            parameters = [
                "gold": [["Number": "Sing", "Gender": "Fem"]],
                "predicted": [["Number": "Plur", "Gender": "Fem"]], "zeroPolicy": "zero",
            ]
        case "temporal":
            let configuration = GlifiStudioTemporalConfiguration(
                basis: .civilDates, granularity: .month,
                origin: try .init(year: 2024, month: 1, day: 1), bucketWidth: 1, bucketCount: 3,
                missingPolicy: .separate, outsidePolicy: .exclude)
            let documents = [
                GlifiStudioTemporalDocument(
                    sourceRevisionID: "source-revision:00000000-0000-0000-0000-000000000001",
                    metadataProvenance: "bdd-original-month-v1",
                    value: .civilMonth(year: 2024, month: 2), tokenCount: 10,
                    termCounts: ["casa": 2]),
                GlifiStudioTemporalDocument(
                    sourceRevisionID: "source-revision:00000000-0000-0000-0000-000000000002",
                    metadataProvenance: "bdd-original-missing-v1", value: .missing,
                    tokenCount: 0, termCounts: [:]),
            ]
            parameters = [
                "documents": try wire(documents), "configuration": try wire(configuration),
            ]
        case "lexicalObserve":
            parameters = lexical(tokens: ["a", "a", "a", "b"], checkpoints: [1, 4])
        case "lexicalZipf":
            parameters = [
                "observations": lexical(
                    tokens: ["a", "a", "a", "a", "b", "b"], checkpoints: [1, 6]),
                "firstRank": 1, "lastRank": 2,
            ]
        case "lexicalHeaps":
            parameters = lexical(tokens: ["a", "b", "a", "c"], checkpoints: [1, 4])
        case "lexicalSummary":
            parameters = [
                "observations": [1, NSNull(), 3, 6], "unitIdentifier": "bdd-original-units-v1",
                "variance": "sample", "probabilities": [0.1, 0.9],
            ]
        case "welchANOVA": parameters = ["groups": [[1, 2, 3], [1, 2, 3], [1, 2, 3]]]
        default:
            Issue.record("Unregistered evaluation variant")
            throw BDDVariantSetupFailure.unknownVariant
        }
        let operation = try #require(
            GlifiStudioEvaluationOperation.allCases.first { String(describing: $0) == variant })
        request = try JSONSerialization.data(
            withJSONObject: [
                "schema": GlifiStudioEvaluationCommand.schema, "schemaVersion": 1,
                "operation": operation.rawValue, "parameters": parameters,
            ], options: [.sortedKeys])
        result = nil
        failure = nil
    }

    func execute(_ phase: String) async throws {
        result = nil
        failure = nil
        var fields = try #require(BDDVariantAssertions.object(request) as? [String: Any])
        if phase == "JSON-invalido" { fields["unexpected_BDD"] = true }
        if phase == "confine-UTF8-invalido" {
            var parameters = try #require(fields["parameters"] as? [String: Any])
            if variant == "boundariesWithText" {
                parameters["predicted"] = [[1]]
            } else {
                try #require(variant == "namedEntitiesWithText")
                parameters["predicted"] = [[["lowerBound": 0, "upperBound": 1, "type": "PER"]]]
            }
            fields["parameters"] = parameters
        }
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        do {
            if phase == "precancellata" {
                let task = Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await GlifiStudioEvaluationCommand.execute(json: data)
                }
                result = try await task.value.json
            } else {
                try #require(
                    ["nominale", "JSON-invalido", "confine-UTF8-invalido"].contains(phase))
                result = try await GlifiStudioEvaluationCommand.execute(json: data).json
            }
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    private func lexical(tokens: [String], checkpoints: [Int]) -> [String: Any] {
        [
            "documents": [["id": "empty", "tokens": []], ["id": "observed", "tokens": tokens]],
            "checkpoints": checkpoints, "preprocessingIdentifier": "bdd-original-lexical-v1",
        ]
    }

    private func wire<Value: Encodable>(_ value: Value) throws -> Any {
        try BDDVariantAssertions.object(BDDVariantAssertions.encode(value))
    }
}

enum BDDVariantSetupFailure: Error { case unknownVariant }

@MainActor
private var evaluationVariantWorld: BDDEvaluationVariantWorld {
    Scenario.state(BDDEvaluationVariantWorld.init)
}

@MainActor
func registerEvaluationVariantSteps() {
    Given("la valutazione completa {string} con annotazioni originali") { match, _ in
        try evaluationVariantWorld.prepare(match.first(\.string))
    }
    When("eseguo la valutazione completa in fase {word}") { match, _ in
        try await evaluationVariantWorld.execute(match.first(\.word))
    }
    Then(#/^la valutazione completa rispetta i valori JSON (.+)$/#) { match, _ in
        let world = evaluationVariantWorld
        #expect(world.failure == nil)
        let result = try BDDVariantAssertions.object(#require(world.result))
        #expect(
            try #require(BDDVariantAssertions.value(result, at: "methodIdentifier") as? String)
                .isEmpty == false)
        try BDDVariantAssertions.expectFacts(result, json: String(match.1))
    }
    Then("la valutazione completa si ripete identica") { _, _ in
        let world = evaluationVariantWorld
        let previous = try #require(world.result)
        let repeated = try await GlifiStudioEvaluationCommand.execute(json: world.request)
        #expect(repeated.json == previous)
    }
    Then("la valutazione completa fallisce con codice {string} e categoria {string}") { match, _ in
        try BDDVariantAssertions.expectFailure(
            evaluationVariantWorld.failure, result: evaluationVariantWorld.result,
            code: match[\.string, index: 0], category: match[\.string, index: 1])
    }
}
