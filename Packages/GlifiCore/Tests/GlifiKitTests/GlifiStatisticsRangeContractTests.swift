// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

private enum StatisticsFiniteFrontier: CaseIterable, Sendable {
    case cohenD
    case locationT
    case standardizedDifference

    var request: GlifiStudioStatisticsRequest {
        switch self {
        case .cohenD:
            .init(operation: .cohenD, values: [[1e308, 1e308], [0, 0.9, -0.9]])
        case .locationT:
            locationRequest()
        case .standardizedDifference:
            .init(operation: .hedgesG, values: [[1e200, 1e200], [0, 0.9, -0.9]])
        }
    }

    var reference: (metric: String, value: Double) {
        // Independent direct formulas and R base references on the synthetic inputs.
        switch self {
        case .cohenD: ("cohen-d", 1.3608276348795434e308)
        case .locationT: ("statistic", -1.7495462702715934e308)
        case .standardizedDifference: ("hedges-g", 1e200 * Double.pi.squareRoot() / 1.8)
        }
    }

    private func locationRequest() -> GlifiStudioStatisticsRequest {
        var parameters = GlifiStudioStatisticsParameters()
        parameters.hypothesizedMean = 1e308
        return .init(operation: .oneSampleT, values: [[0, 0.99, -0.99]], parameters: parameters)
    }
}

@Test(arguments: StatisticsFiniteFrontier.allCases)
private func statisticsRangeFrontiersSurviveTransport(frontier: StatisticsFiniteFrontier)
    async throws
{
    let request = frontier.request
    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(GlifiStudioStatisticsRequest.self, from: encoded)
    #expect(decoded == request)
    let result = try await GlifiStudioStatisticsWorkbench.evaluate(decoded)
    let metric = try #require(
        result.metrics.first { $0.key == "statistics.metric.\(frontier.reference.metric)" })
    guard case let .number(value) = metric.value else {
        Issue.record("A representable statistic must retain its finite numerical transport")
        return
    }
    #expect(value.isFinite)
    #expect(abs(value / frontier.reference.value - 1) <= 1e-12)
    #expect(
        try JSONDecoder().decode(
            GlifiStudioStatisticsResult.self, from: JSONEncoder().encode(result)) == result)
    try exportKitCLIParityFixture(
        command: "statistics", operation: request.operation.rawValue,
        request: request, result: result, variant: "finite-range-334")
}

@Test(arguments: [GlifiStudioStatisticsOperation.hedgesG, .pearsonInterval])
private func statisticsAdjacentUnitConfidenceSurvivesTransport(
    operation: GlifiStudioStatisticsOperation
) async throws {
    var parameters = GlifiStudioStatisticsParameters()
    parameters.confidenceLevel = 1.0.nextDown
    parameters.coefficient = 0.5
    parameters.firstCount = 10
    let request = GlifiStudioStatisticsRequest(
        operation: operation,
        values: operation == .hedgesG ? [[1, 2, 3], [2, 3, 4]] : [], parameters: parameters)
    let result = try await GlifiStudioStatisticsWorkbench.evaluate(request)
    let expected: [String: Double] =
        operation == .hedgesG
        ? ["lower": -8.181395349007829, "upper": 6.18139534900783]
        : ["lower": -0.9886931412605833, "upper": 0.9987373371398001]
    for (name, reference) in expected {
        let metric = try #require(result.metrics.first { $0.key == "statistics.metric.\(name)" })
        guard case let .number(value) = metric.value else {
            Issue.record("A finite confidence endpoint must retain its numerical transport")
            continue
        }
        #expect(abs(value / reference - 1) <= 1e-12)
    }
    try exportKitCLIParityFixture(
        command: "statistics", operation: request.operation.rawValue,
        request: request, result: result, variant: "confidence-boundary-334")
}
