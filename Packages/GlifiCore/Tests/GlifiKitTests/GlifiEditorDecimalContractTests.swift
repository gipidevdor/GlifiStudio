// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit
import Testing

struct GlifiEditorDecimalContractTests {
    @Test(arguments: [
        DecimalExample(token: "1,5", value: 1.5),
        DecimalExample(token: "2.25", value: 2.25),
        DecimalExample(token: ".5", value: 0.5),
        DecimalExample(token: ",5", value: 0.5),
        DecimalExample(token: "+1.", value: 1),
        DecimalExample(token: "1E+3", value: 1_000),
        DecimalExample(token: "-2,5e-2", value: -0.025),
        DecimalExample(token: "+0", value: 0),
        DecimalExample(token: "-0", value: -0.0),
        DecimalExample(token: "-0,0", value: -0.0),
        DecimalExample(token: "-0e5", value: -0.0),
        DecimalExample(token: "5e-324", value: .leastNonzeroMagnitude),
    ])
    func bothEditorsPreserveDecimalValuesAndSignedZero(example: DecimalExample) async throws {
        let statistics = try await GlifiStudioStatisticsWorkbench.request(
            operation: .descriptive, input: example.token, parameters: .init())
        let row = try #require(statistics.values.first)
        let optionalValue = try #require(row.first)
        let statisticValue = try #require(optionalValue)
        #expect(statisticValue.bitPattern == example.value.bitPattern)

        var request = GlifiStudioCoreOperatorRequest()
        request.operation = .transpose
        request.numbers = example.token
        let result = try await GlifiStudioCoreOperators.execute(request)
        let cell = try #require(result.tables.first?.rows.first?.last)
        guard case let .number(operatorValue) = cell else {
            Issue.record("Expected a finite numerical matrix cell")
            return
        }
        #expect(operatorValue.bitPattern == example.value.bitPattern)
    }

    @Test(arguments: ["1.000,5", "1,000.5", "1e999", "-1e999", "NaN", "Infinity", "0x10", "1;2"])
    func invalidTokensRetainEachEditorsFailureContract(token: String) async {
        do {
            _ = try await GlifiStudioStatisticsWorkbench.request(
                operation: .descriptive, input: token, parameters: .init())
            Issue.record("Statistics editor accepted an invalid decimal token")
        } catch {
            #expect(
                error
                    == GlifiStudioFailure(
                        code: "statistics.workbench.invalid-number", category: "invalidInput",
                        operation: "analyze", retryDisposition: "afterCorrection",
                        retainedState: "unchanged", messageKey: "failure.category.invalidInput"))
        }

        var request = GlifiStudioCoreOperatorRequest()
        request.operation = .transpose
        request.numbers = token
        do {
            _ = try await GlifiStudioCoreOperators.execute(request)
            Issue.record("Operator editor accepted an invalid decimal token")
        } catch {
            #expect(
                error
                    == GlifiStudioFailure(
                        code: "operators.invalid-input", category: "invalidInput",
                        operation: "analyze",
                        retryDisposition: "afterCorrection", retainedState: "unchanged",
                        messageKey: "failure.core-operators.input"))
        }
    }
}

struct DecimalExample: Sendable {
    let token: String
    let value: Double
}
