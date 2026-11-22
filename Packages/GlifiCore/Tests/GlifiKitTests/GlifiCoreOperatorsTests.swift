// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

struct GlifiCoreOperatorsTests {
    @Test func ignoresHiddenParametersAndPreservesCallerIdentities() async throws {
        var request = Self.fixture(.cosine)
        request.maximumIterations = 0
        request.nodes = String(
            repeating: "x", count: GlifiStudioCoreOperators.maximumInputBytes + 1)
        #expect(try await GlifiStudioCoreOperators.execute(request).request == request.effective)
        request = Self.fixture(.degree)
        request.maximumIterations = 0
        request.nodes = "true\noperators.rank"
        request.edges = "true\toperators.rank\t1"
        let result = try await GlifiStudioCoreOperators.execute(request)
        #expect(
            result.tables.first?.rows.map { $0.first } == [.text("true"), .text("operators.rank")])
    }

    @Test(arguments: GlifiStudioCoreOperator.allCases)
    func executesEveryExplicitOperator(operation: GlifiStudioCoreOperator) async throws {
        var request = Self.fixture(operation)
        if operation == .lidstone { request.numbers = "1 2 3" }
        let result = try await GlifiStudioCoreOperators.execute(request)
        #expect(result.request == request.effective)
        #expect(!result.methodIdentifiers.isEmpty)
        #expect(!result.tables.isEmpty)
        #expect(
            result.tables.allSatisfy { table in
                table.rows.allSatisfy { $0.count == table.columns.count }
            })
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        #expect(object["schema"] as? String == "studio.glifi.core-operator-result")
        #expect(object["schemaVersion"] as? Int == 1)
        #expect(result.validationStatus == "candidate")
    }

    @Test func preservesExplicitLexicalKeysAndCheckpoints() async throws {
        var request = Self.fixture(.jaccard)
        request.firstSet = "casa mare mare"
        request.secondSet = "casa Sole"
        let sets = try await GlifiStudioCoreOperators.execute(request)
        #expect(sets.tables.first?.rows.first?.last == .number(1.0 / 3))
        request = Self.fixture(.lexicalObservation)
        request.documents = "a a a b"
        request.checkpoints = "1 4"
        let result = try await GlifiStudioCoreOperators.execute(request)
        let growth = try #require(result.tables.first { $0.titleKey == "operators.growth" })
        #expect(growth.rows == [[.integer(1), .integer(1)], [.integer(4), .integer(2)]])
    }

    @Test func preservesTheCoreFailureForUndefinedDivergence() async throws {
        var request = Self.fixture(.kl)
        request.numbers = "1 0\n0 1"
        do {
            _ = try await GlifiStudioCoreOperators.execute(request)
            Issue.record("Undefined divergence completed")
        } catch let failure {
            #expect(failure.code == "similarity.kl-undefined")
            #expect(failure.category == "insufficientData")
        }
    }

    @Test func rejectsMalformedUnboundedOrAmbiguousInputs() async {
        for text in ["1 2\n3", "1.000,5 2", "nan 2", "1e999 2"] {
            var request = Self.fixture(.svd)
            request.numbers = text
            await #expect(throws: GlifiStudioFailure.self) {
                try await GlifiStudioCoreOperators.execute(request)
            }
        }
        var graph = Self.fixture(.pageRank)
        graph.edges = "A\tunknown\t1"
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioCoreOperators.execute(graph)
        }
        var matrix = Self.fixture(.svd)
        matrix.numbers = String(
            repeating: "1 ", count: GlifiStudioCoreOperators.maximumMatrixCells + 1)
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioCoreOperators.execute(matrix)
        }
    }

    @Test func cancellationUsesTheSharedFailureTaxonomy() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioCoreOperators.execute(Self.fixture(.svd))
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled execution published a result")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        } catch { Issue.record("Unexpected failure: \(error)") }
    }

    private static func fixture(_ operation: GlifiStudioCoreOperator)
        -> GlifiStudioCoreOperatorRequest
    {
        var request = GlifiStudioCoreOperatorRequest()
        request.operation = operation
        request.numbers =
            operation.family == "similarity" ? "0,2 0,3 0,5\n0,3 0,3 0,4" : "1 2\n2 1\n4 5\n5 4"
        request.nodes = "A\nB\nC"
        request.edges = "A\tB\t2\nB\tC\t1\nC\tA\t1"
        request.firstSet = "a b"
        request.secondSet = "b c"
        request.assignments = operation.family == "graph" ? "0 0 1" : "0 0 1 1"
        request.documents = "a a b c\nb d a d c"
        request.checkpoints = "1 3 6 9"
        return request
    }
}
