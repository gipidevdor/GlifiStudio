// SPDX-License-Identifier: BSD-3-Clause

import CoreFoundation
import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDCompleteMethodWorld {
    var command = ""
    var variant = ""
    var json = Data()
    var statistics: GlifiStudioStatisticsResult?
    var coreOperator: GlifiStudioCoreOperatorResult?
    var failure: GlifiStudioFailure?

    func prepare(command: String, variant: String, overrides: String = "{}") throws {
        self.command = command
        self.variant = variant
        statistics = nil
        coreOperator = nil
        failure = nil
        let encoded: Data
        if command == "statistics" {
            let operation = try #require(GlifiStudioStatisticsOperation(rawValue: variant))
            encoded = try JSONEncoder().encode(GlifiStudioStatisticsRequest(operation: operation))
        } else {
            let operation = try #require(GlifiStudioCoreOperator(rawValue: variant))
            var request = GlifiStudioCoreOperatorRequest()
            request.operation = operation
            encoded = try JSONEncoder().encode(request)
        }
        var body = try completeJSONObject(encoded)
        let declared = try completeJSONObject(Data(overrides.utf8))
        for (key, value) in declared {
            try #require(
                key != "operation"
                    && (body[key] != nil || (command == "operator" && key == "lastRank")))
            if key == "parameters" {
                var parameters = try #require(body[key] as? [String: Any])
                for (parameter, setting) in try #require(value as? [String: Any]) {
                    try #require(parameters[parameter] != nil)
                    parameters[parameter] = setting
                }
                body[key] = parameters
            } else {
                body[key] = value
            }
        }
        #expect(body["operation"] as? String == variant)
        json = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    func addUnknownField() throws {
        var body = try completeJSONObject(json)
        body["BDD_PRIVATE_CANARY"] = true
        json = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    func execute(cancelled: Bool) async throws {
        let input = json
        do {
            if command == "statistics" {
                if cancelled {
                    statistics = try await Task {
                        withUnsafeCurrentTask { $0?.cancel() }
                        return try await GlifiStudioStatisticsWorkbench.evaluate(json: input)
                    }.value
                } else {
                    statistics = try await GlifiStudioStatisticsWorkbench.evaluate(json: input)
                }
            } else {
                if cancelled {
                    coreOperator = try await Task {
                        withUnsafeCurrentTask { $0?.cancel() }
                        return try await GlifiStudioCoreOperators.execute(json: input)
                    }.value
                } else {
                    coreOperator = try await GlifiStudioCoreOperators.execute(json: input)
                }
            }
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }
}

@MainActor
private var completeMethodWorld: BDDCompleteMethodWorld {
    Scenario.state(BDDCompleteMethodWorld.init)
}

@MainActor
func registerCompleteMethodSteps() {
    Given(#/^il caso statistico "([^"]+)" usa JSON (.+)$/#) { match, _ in
        try completeMethodWorld.prepare(
            command: "statistics", variant: String(match.1), overrides: String(match.2))
    }
    Given(#/^il caso operatore "([^"]+)" usa JSON (.+)$/#) { match, _ in
        try completeMethodWorld.prepare(
            command: "operator", variant: String(match.1), overrides: String(match.2))
    }
    Given("la richiesta completa contiene un campo JSON non ammesso") { _, _ in
        try completeMethodWorld.addUnknownField()
    }
    When("eseguo il caso completo attraverso GlifiKit JSON") { _, _ in
        try await completeMethodWorld.execute(cancelled: false)
    }
    When("eseguo il caso completo con task già cancellato") { _, _ in
        try await completeMethodWorld.execute(cancelled: true)
    }
    Then("il risultato completo conserva la variante {string}") { match, _ in
        let world = completeMethodWorld
        let variant = try match.first(\.string)
        #expect(world.variant == variant)
        #expect(world.failure == nil)
        if world.command == "statistics" {
            let result = try #require(world.statistics)
            #expect(result.request.operation.rawValue == variant)
            #expect(
                result.request
                    == (try JSONDecoder().decode(
                        GlifiStudioStatisticsRequest.self, from: world.json)))
            #expect(world.coreOperator == nil)
        } else {
            let result = try #require(world.coreOperator)
            let request = try JSONDecoder().decode(
                GlifiStudioCoreOperatorRequest.self, from: world.json)
            #expect(result.request.operation.rawValue == variant)
            #expect(result.request == request.effective)
            #expect(world.statistics == nil)
        }
    }
    Then(#/^le attese statistiche indipendenti sono JSON (.+)$/#) { match, _ in
        let result = try #require(completeMethodWorld.statistics)
        let expected = try completeJSONObject(Data(String(match.1).utf8))
        let metrics = try #require(expected["metrics"] as? [String: Any])
        try #require(!metrics.isEmpty || !(expected["cells"] as? [String: Any] ?? [:]).isEmpty)
        for (key, reference) in metrics {
            let metric = try #require(result.metrics.first { $0.key == "statistics.metric.\(key)" })
            try completeExpectStatistic(metric.value, reference: reference)
        }
        if let count = expected["rowCount"] as? Int { #expect(result.rows.count == count) }
        for (position, reference) in expected["cells"] as? [String: Any] ?? [:] {
            let (row, column) = try completePosition(position)
            try #require(result.rows.indices.contains(row))
            try #require(result.rows[row].indices.contains(column))
            try completeExpectStatistic(result.rows[row][column], reference: reference)
        }
    }
    Then(#/^le attese degli operatori indipendenti sono JSON (.+)$/#) { match, _ in
        let result = try #require(completeMethodWorld.coreOperator)
        let expected = try completeJSONObject(Data(String(match.1).utf8))
        let tables = expected["tables"] as? [String: [String: Any]] ?? [:]
        let diagnostics = expected["diagnostics"] as? [String: Any] ?? [:]
        try #require(!tables.isEmpty || !diagnostics.isEmpty)
        for (key, reference) in tables {
            let table = try #require(result.tables.first { $0.titleKey == key })
            if let count = reference["rowCount"] as? Int { #expect(table.rows.count == count) }
            for (position, value) in reference["cells"] as? [String: Any] ?? [:] {
                let (row, column) = try completePosition(position)
                try #require(table.rows.indices.contains(row))
                try #require(table.rows[row].indices.contains(column))
                try completeExpectOperator(table.rows[row][column], reference: value)
            }
        }
        if !diagnostics.isEmpty {
            let table = try #require(result.tables.first { $0.titleKey == "operators.diagnostics" })
            for (key, reference) in diagnostics {
                let row = try #require(table.rows.first { $0.first == .localized(key) })
                try completeExpectOperator(try #require(row.last), reference: reference)
            }
        }
        if let partition = expected["partition"] as? [String: Any] {
            let key = try #require(partition["table"] as? String)
            let groups = try #require(partition["groups"] as? [[Int]])
            let table = try #require(result.tables.first { $0.titleKey == key })
            try #require(groups.flatMap { $0 }.sorted() == Array(table.rows.indices))
            var membership = [Int](repeating: -1, count: table.rows.count)
            for (group, indices) in groups.enumerated() {
                for index in indices { membership[index] = group }
            }
            for left in table.rows.indices {
                for right in table.rows.indices {
                    try #require(table.rows[left].count >= 2 && table.rows[right].count >= 2)
                    #expect(
                        (table.rows[left][1] == table.rows[right][1])
                            == (membership[left] == membership[right]))
                }
            }
        }
    }
    Then("il caso completo fallisce con codice {string} e categoria {string} e stato {string}") {
        match, _ in
        let world = completeMethodWorld
        let failure = try #require(world.failure)
        #expect(failure.code == match[\.string, index: 0])
        #expect(failure.category == match[\.string, index: 1])
        #expect(failure.operation == "analyze")
        #expect(failure.retainedState == match[\.string, index: 2])
        #expect(world.statistics == nil && world.coreOperator == nil)
        #expect(!String(describing: failure).contains("BDD_PRIVATE_CANARY"))
    }
}

private func completeJSONObject(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func completePosition(_ value: String) throws -> (Int, Int) {
    let parts = value.split(separator: ",")
    try #require(parts.count == 2)
    return (try #require(Int(parts[0])), try #require(Int(parts[1])))
}

private func completeExpectNumber(_ actual: Double, reference: Any) throws {
    let number = try #require(reference as? NSNumber)
    try #require(CFGetTypeID(number) != CFBooleanGetTypeID())
    let expected = number.doubleValue
    try #require(expected.isFinite)
    #expect(actual.isFinite)
    #expect(abs(actual - expected) <= 1e-10 * max(1, abs(expected)))
}

private func completeExpectStatistic(_ actual: GlifiStudioStatisticsValue, reference: Any) throws {
    switch actual {
    case let .number(value): try completeExpectNumber(value, reference: reference)
    case let .integer(value): try completeExpectNumber(Double(value), reference: reference)
    case let .text(value): #expect(value == (try #require(reference as? String)))
    case .positiveInfinity: #expect(reference as? String == "positiveInfinity")
    case .negativeInfinity: #expect(reference as? String == "negativeInfinity")
    case .undefined: #expect(reference as? String == "undefined")
    }
}

private func completeExpectOperator(_ actual: GlifiStudioOperatorCell, reference: Any) throws {
    switch actual {
    case let .number(value): try completeExpectNumber(value, reference: reference)
    case let .integer(value): try completeExpectNumber(Double(value), reference: reference)
    case let .text(value), let .localized(value):
        #expect(value == (try #require(reference as? String)))
    case let .nonFinite(value): #expect(value == (try #require(reference as? String)))
    }
}
