// SPDX-License-Identifier: BSD-3-Clause

import CoreFoundation
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDAnalyticalWorld {
    var request: Data?
    var result: GlifiStudioTextAnalysisResult?
    var encodedResult: Data?
    var object: Any?
    var failure: GlifiStudioFailure?

    func execute() async throws {
        result = nil
        encodedResult = nil
        object = nil
        failure = nil
        do {
            let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(
                json: #require(request))
            self.result = result
            encodedResult = try encode(result)
            object = try JSONSerialization.jsonObject(with: #require(encodedResult))
        } catch let failure as GlifiStudioFailure {
            self.failure = failure
        }
    }

    func encode(_ result: GlifiStudioTextAnalysisResult) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(result)
    }

    func value(at path: String) throws -> Any {
        var current = try #require(object)
        for component in path.split(separator: ".") {
            if let dictionary = current as? [String: Any] {
                current = try #require(dictionary[String(component)])
            } else {
                let values = try #require(current as? [Any])
                let index = try #require(Int(component))
                try #require(values.indices.contains(index))
                current = values[index]
            }
        }
        return current
    }
}

@MainActor
private var analyticalWorld: BDDAnalyticalWorld { Scenario.state(BDDAnalyticalWorld.init) }

@MainActor
func registerAnalyticalSteps() {
    Given("la richiesta analitica JSON") { _, step in
        let json = try #require(step.docString?.literal)
        analyticalWorld.request = Data(json.utf8)
    }
    Given(#/^la richiesta analitica JSON (.+)$/#) { match, _ in
        analyticalWorld.request = Data(String(match.1).utf8)
    }
    When("eseguo la richiesta analitica") { _, _ in try await analyticalWorld.execute() }
    Then("l'operazione analitica è {string}") { match, _ in
        let result = try #require(analyticalWorld.result)
        let operation = try match.first(\.string)
        #expect(result.operation == operation)
        #expect(result.schema == "studio.glifi.text-analysis-result")
        #expect(result.schemaVersion == 1)
        #expect(!result.methodIdentifier.isEmpty)
        #expect(result.requestDigest.count == 64)
        #expect(analyticalWorld.failure == nil)
    }
    Then("il valore analitico {string} è {string}") { match, _ in
        let path: String = match[\.string, index: 0]
        let expected: String = match[\.string, index: 1]
        let numeric = try #require(analyticalWorld.value(at: path) as? NSNumber)
        try #require(CFGetTypeID(numeric) != CFBooleanGetTypeID())
        let number = numeric.doubleValue
        let parts = expected.split(separator: "/")
        try #require((1...2).contains(parts.count))
        let numerator = try #require(Double(parts[0]))
        let denominator = parts.count == 2 ? try #require(Double(parts[1])) : 1
        try #require(denominator != 0)
        let reference = numerator / denominator
        try #require(reference.isFinite)
        #expect(number.isFinite)
        #expect(abs(number - reference) <= 1e-10 * max(1, abs(reference)))
    }
    Then("la stringa analitica {string} è {string}") { match, _ in
        let path: String = match[\.string, index: 0]
        let expected: String = match[\.string, index: 1]
        let actual = try #require(analyticalWorld.value(at: path) as? String)
        #expect(actual == expected)
    }
    Then("la collezione analitica {string} contiene {int} elementi") { match, _ in
        let path = try match.first(\.string)
        let expected = try match.first(\.int)
        let actual = try #require(analyticalWorld.value(at: path) as? [Any])
        #expect(actual.count == expected)
    }
    Then("la riesecuzione analitica è identica") { _, _ in
        let world = analyticalWorld
        let original = try #require(world.encodedResult)
        let repeated = try await GlifiStudioTextAnalytics.executeTextAnalysis(
            json: #require(world.request))
        let repeatedBytes = try world.encode(repeated)
        #expect(repeatedBytes == original)
    }
    Then("la richiesta analitica fallisce con codice {string} e categoria {string}") { match, _ in
        let world = analyticalWorld
        let failure = try #require(world.failure)
        #expect(failure.code == match[\.string, index: 0])
        #expect(failure.category == match[\.string, index: 1])
        #expect(failure.operation == "analyze")
        #expect(failure.retainedState == "unchanged")
        #expect(world.result == nil)
        #expect(world.encodedResult == nil)
    }
}
