// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDTextVariantWorld {
    var request = Data()
    var result: Data?
    var failure: GlifiStudioFailure?

    func prepare(variant: String, fixtureID: String) throws {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        let fixture = try #require(
            BDDVariantAssertions.object(
                Data(contentsOf: root.appending(path: "Fixtures/TextAnalysis/v1/cases.json")))
                as? [String: Any])
        let cases = try #require(fixture["cases"] as? [[String: Any]])
        let baseID: String
        switch fixtureID {
        case "bdd-som-constant": baseID = "som"
        case "bdd-som-advanced-constant": baseID = "som-hexagonal"
        case "bdd-mds-search-two-points": baseID = "mds-search"
        case "bdd-mds-ordinal-two-points": baseID = "kh-ordinal-primary"
        case "bdd-mds-ordinal-search-two-points": baseID = "kh-ordinal-search"
        default: baseID = fixtureID
        }
        let selected = try #require(cases.first { $0["id"] as? String == baseID })
        var fields = try #require(selected["request"] as? [String: Any])
        try #require(fields["operation"] as? String == variant)
        // Original degenerate fixtures make stochastic branches admit exact, independent facts.
        if fixtureID.hasPrefix("bdd-mds-") {
            fields["matrix"] = [[0, 1], [1, 0]]
        }
        if fixtureID == "bdd-som-constant" { fields["matrix"] = [[0, 0], [0, 0]] }
        if fixtureID == "bdd-som-advanced-constant" { fields["matrix"] = [[0], [0], [0], [0]] }
        request = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        result = nil
        failure = nil
    }

    func execute(phase: String) async throws {
        result = nil
        failure = nil
        var raw = request
        if phase == "JSON-invalido" {
            var fields = try #require(BDDVariantAssertions.object(raw) as? [String: Any])
            fields["unexpected_BDD"] = true
            raw = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        }
        do {
            let value: GlifiStudioTextAnalysisResult
            if phase == "precancellata" {
                let input = raw
                let task = Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await GlifiStudioTextAnalytics.executeTextAnalysis(json: input)
                }
                value = try await task.value
            } else {
                try #require(phase == "nominale" || phase == "JSON-invalido")
                value = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: raw)
            }
            result = try BDDVariantAssertions.encode(value)
            let resolved = try GlifiStudioTextAnalysisRequest.decode(raw)
            let digest = SHA256.hash(data: try resolved.canonicalData())
                .map { String(format: "%02x", $0) }.joined()
            #expect(value.requestDigest == digest)
            #expect(value.operation == resolved.operation)
            #expect(value.schema == "studio.glifi.text-analysis-result")
            #expect(value.schemaVersion == 1)
            #expect(!value.methodIdentifier.isEmpty)
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }
    func verifyQuantitativeInvariants() throws {
        let input = try #require(BDDVariantAssertions.object(request) as? [String: Any])
        let resultBytes = try #require(result)
        let resultObject = try BDDVariantAssertions.object(resultBytes)
        let output = try #require(resultObject as? [String: Any])
        let operation = try #require(input["operation"] as? String)
        if ["som", "som-advanced", "som-kh"].contains(operation) {
            var map = try #require(output["result"] as? [String: Any])
            if operation == "som-advanced" { map = try #require(map["map"] as? [String: Any]) }
            let rows = try #require(input["matrix"] as? [[Double]])
            let prototypes = try #require(map["prototypes"] as? [[Double]])
            let assignments = try #require(map["assignments"] as? [Int])
            try #require(!rows.isEmpty && !prototypes.isEmpty && assignments.count == rows.count)
            var error = 0.0
            for (index, row) in rows.enumerated() {
                let distances = try prototypes.map { prototype in
                    try #require(row.count == prototype.count)
                    return sqrt(zip(row, prototype).reduce(0) { $0 + pow($1.0 - $1.1, 2) })
                }
                let best = try #require(distances.min())
                try #require(distances.indices.contains(assignments[index]))
                try BDDVariantAssertions.expectEquivalent(distances[assignments[index]], best)
                error += best
            }
            try BDDVariantAssertions.expectEquivalent(
                #require(map["quantizationError"]), error / Double(rows.count))
        }
        if operation == "mds", input["method"] as? String != "ordinal" {
            let payload = try #require(output["result"] as? [String: Any])
            try verifyMDSInvariants(input: input, payload: payload)
        }
        if ["classify", "lda", "lda-selection"].contains(operation) {
            var payload = try #require(output["result"] as? [String: Any])
            if operation == "lda-selection" {
                payload = try #require(payload["selectedModel"] as? [String: Any])
            }
            for key in operation == "classify"
                ? ["probabilities"] : ["documentTopics", "topicTerms"]
            {
                let probabilities = try #require(payload[key] as? [[Double]])
                try #require(!probabilities.isEmpty)
                for row in probabilities {
                    try #require(
                        !row.isEmpty && row.allSatisfy { $0.isFinite && (0...1).contains($0) })
                    try BDDVariantAssertions.expectEquivalent(row.reduce(0, +), 1)
                }
            }
        }
        if ["mds-search", "mds-ordinal-search"].contains(operation) {
            let payload = try #require(output["result"] as? [String: Any])
            let runs = try #require(payload["runs"] as? [[String: Any]])
            let chosen = try #require(payload["chosenRun"] as? Int)
            let objectives = try runs.map { try #require($0["stress"] as? Double) }
            let best = try #require(objectives.min())
            #expect(chosen == objectives.firstIndex(of: best))
        }
    }

    private func verifyMDSInvariants(input: [String: Any], payload: [String: Any]) throws {
        let matrix = try #require(input["matrix"] as? [[Double]])
        let coordinates = try #require(payload["coordinates"] as? [[Double]])
        let method = try #require(input["method"] as? String)
        let dimensions = try #require(input["dimensions"] as? Int)
        try #require(matrix.count >= 2 && coordinates.count == matrix.count)
        try #require(matrix.allSatisfy { $0.count == matrix.count })
        try #require(
            coordinates.allSatisfy { $0.count == dimensions && $0.allSatisfy(\.isFinite) })
        var fitted = matrix.map { $0.map { _ in 0.0 } }
        for first in coordinates.indices {
            for second in 0..<first {
                let distance = sqrt(
                    zip(coordinates[first], coordinates[second]).reduce(0) {
                        $0 + pow($1.0 - $1.1, 2)
                    })
                fitted[first][second] = distance
                fitted[second][first] = distance
                if method == "classical" {
                    // This reviewed three-point line has an exact one-dimensional embedding.
                    try BDDVariantAssertions.expectEquivalent(distance, matrix[first][second])
                }
            }
        }
        let reconstructedStress: Double
        if method == "kruskal" {
            // For this original fixture the two dissimilarity-one pairs are tied. Their
            // least-squares disparity is their fitted mean; the dissimilarity-two pair is
            // already ordered above that mean. No isotonic algorithm is reused as an oracle.
            try #require(matrix == [[0, 1, 2], [1, 0, 1], [2, 1, 0]])
            let tiedMean = (fitted[0][1] + fitted[1][2]) / 2
            try #require(fitted[0][2] >= tiedMean)
            let residual = pow(fitted[0][1] - tiedMean, 2) + pow(fitted[1][2] - tiedMean, 2)
            let squaredDistances =
                pow(fitted[0][1], 2) + pow(fitted[1][2], 2)
                + pow(fitted[0][2], 2)
            try #require(squaredDistances > 0)
            reconstructedStress = sqrt(residual / squaredDistances)
        } else {
            try #require(["classical", "metric", "sammon"].contains(method))
            var numerator = 0.0
            var normalizer = 0.0
            for first in matrix.indices {
                for second in 0..<first {
                    let target = matrix[first][second]
                    let residual = pow(fitted[first][second] - target, 2)
                    if method == "sammon" {
                        try #require(target > 0)
                        numerator += residual / target
                        normalizer += target
                    } else {
                        numerator += residual
                    }
                }
            }
            reconstructedStress = method == "sammon" ? numerator / normalizer : numerator
        }
        try BDDVariantAssertions.expectEquivalent(
            #require(payload["stress"]), reconstructedStress, path: "MDS reconstructed objective")

        let iterations = try #require(payload["iterations"] as? Int)
        let limit = try #require(input["maximumIterations"] as? Int)
        let history = try #require(payload["objectiveHistory"] as? [Double])
        let converged = try #require(payload["converged"] as? Bool)
        try #require(iterations >= 0 && iterations <= limit && history.count == iterations + 1)
        try #require(history.allSatisfy { $0.isFinite && $0 >= 0 })
        let last = try #require(history.last)
        try BDDVariantAssertions.expectEquivalent(last, reconstructedStress)
        for index in 1..<history.count { #expect(history[index] <= history[index - 1]) }
        if method == "classical" {
            #expect(iterations == 0 && converged)
        } else if converged {
            try #require(history.count >= 2)
            let previous = history[history.count - 2]
            let scale = try #require(matrix.flatMap { $0 }.max())
            let multiplier = method == "metric" ? scale * scale : 1
            // The public MDS transport uses the documented default relative tolerance 1e-8.
            #expect(previous - last <= 1e-8 * max(previous, 1e-15 * multiplier))
        }
    }
}

@MainActor
private var textVariantWorld: BDDTextVariantWorld { Scenario.state(BDDTextVariantWorld.init) }

@MainActor
func registerTextVariantSteps() {
    Given("la variante testuale {string} usa la fixture originale {string}") { match, _ in
        try textVariantWorld.prepare(
            variant: match[\.string, index: 0], fixtureID: match[\.string, index: 1])
    }
    When("eseguo la variante testuale in fase {word}") { match, _ in
        try await textVariantWorld.execute(phase: match.first(\.word))
    }
    Then(#/^il risultato testuale rispetta i valori JSON (.+)$/#) { match, _ in
        let world = textVariantWorld
        #expect(world.failure == nil)
        try BDDVariantAssertions.expectFacts(
            BDDVariantAssertions.object(#require(world.result)),
            json: String(match.1))
    }
    Then("la variante testuale si ripete senza cambiare il risultato") { _, _ in
        let world = textVariantWorld
        let previous = try #require(world.result)
        let repeated = try await GlifiStudioTextAnalytics.executeTextAnalysis(json: world.request)
        #expect(try BDDVariantAssertions.encode(repeated) == previous)
    }
    Then("la variante testuale fallisce con codice {string} e categoria {string}") { match, _ in
        try BDDVariantAssertions.expectFailure(
            textVariantWorld.failure, result: textVariantWorld.result,
            code: match[\.string, index: 0], category: match[\.string, index: 1])
    }
    Then("gli invarianti quantitativi testuali coincidono con gli input") { _, _ in
        try textVariantWorld.verifyQuantitativeInvariants()
    }
}
