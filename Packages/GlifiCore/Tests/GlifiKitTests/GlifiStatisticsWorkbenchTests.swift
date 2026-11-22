// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import GlifiKit
import Testing

struct GlifiStatisticsWorkbenchTests {
    @Test(arguments: GlifiStudioStatisticsOperation.allCases)
    func everyOperatorMatchesItsCoreEntryPoint(operation: GlifiStudioStatisticsOperation)
        async throws
    {
        let request = fixture(operation)
        let result = try await GlifiStudioStatisticsWorkbench.evaluate(request)
        let expected = try reference(request)
        let observed: GlifiStudioStatisticsValue
        if let key = expected.metric {
            observed = try #require(
                result.metrics.first { $0.key == "statistics.metric.\(key)" }?.value)
        } else {
            let row = try #require(result.rows.first)
            observed = row[expected.column]
        }
        switch observed {
        case let .number(value):
            #expect(abs(value - expected.value) <= max(1e-12, abs(expected.value) * 1e-12))
        case .positiveInfinity: #expect(expected.value == .infinity)
        case .negativeInfinity: #expect(expected.value == -.infinity)
        case .integer, .text, .undefined: Issue.record("Expected a numerical core value")
        }
        #expect(result.request == request)
        #expect(!result.methodIdentifier.isEmpty)
        #expect(result.requestDigest.count == 64)
        #expect(result.rows.allSatisfy { $0.count == result.columns.count })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(result)
        #expect(try JSONDecoder().decode(GlifiStudioStatisticsResult.self, from: encoded) == result)
        let again = try await GlifiStudioStatisticsWorkbench.evaluate(request)
        #expect(again == result)
    }

    @Test func parsesDecimalCommaWithoutTreatingItAsAListDelimiter() async throws {
        let request = try await GlifiStudioStatisticsWorkbench.request(
            operation: .descriptive, input: "1,5 2.25 ?", parameters: .init())
        #expect(request.values == [[1.5, 2.25, nil]])
        let categories = try await GlifiStudioStatisticsWorkbench.request(
            operation: .alphaNominal, input: "tema A\ttema B\t?\ntema B\ttema B\ttema A",
            parameters: .init())
        #expect(categories.categories[0] == ["tema A", "tema B", nil])
        let emptyCells = try await GlifiStudioStatisticsWorkbench.request(
            operation: .alphaNominal, input: "\tA\r\nB\t", parameters: .init())
        #expect(emptyCells.categories == [[nil, "A"], ["B", nil]])
        let windowsRows = try await GlifiStudioStatisticsWorkbench.request(
            operation: .pairedT, input: "1 2\r\n3 4", parameters: .init())
        #expect(windowsRows.values == [[1, 2], [3, 4]])
        for invalid in ["1.000,5", "NaN", "Infinity", "1;2", "1 2\n\n3 4"] {
            await #expect(throws: GlifiStudioFailure.self) {
                try await GlifiStudioStatisticsWorkbench.request(
                    operation: .descriptive, input: invalid, parameters: .init())
            }
        }
    }

    @Test func rejectsMissingPairsNonFiniteDataAndExcessiveWorkWithoutTruncation() async throws {
        for request in [
            GlifiStudioStatisticsRequest(operation: .pairedT, values: [[1, 2, 3], [1, 2]]),
            GlifiStudioStatisticsRequest(operation: .pairedT, values: [[1, nil, 3], [1, 2, 3]]),
            GlifiStudioStatisticsRequest(operation: .descriptive, values: [[.nan]]),
            GlifiStudioStatisticsRequest(operation: .fisherExact, values: [[1.5, 2], [3, 4]]),
        ] {
            await #expect(throws: GlifiStudioFailure.self) {
                try await GlifiStudioStatisticsWorkbench.evaluate(request)
            }
        }
        var parameters = GlifiStudioStatisticsParameters()
        parameters.resampleCount = 200_000
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioStatisticsWorkbench.evaluate(
                GlifiStudioStatisticsRequest(
                    operation: .bootstrapMean, values: [Array(repeating: 1, count: 101)],
                    parameters: parameters))
        }
        parameters.exact = true
        let largeGroup = [Double?](repeating: 1, count: 5_000)
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioStatisticsWorkbench.evaluate(
                .init(operation: .permutation, values: [largeGroup, [2]], parameters: parameters))
        }
        let bounded = try await GlifiStudioStatisticsWorkbench.evaluate(
            .init(operation: .permutation, values: [[2], largeGroup], parameters: parameters))
        #expect(bounded.methodIdentifier == "PermutationMeanDifference-v1")
    }

    @Test func observesCancellationBeforeParsingAndExecution() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioStatisticsWorkbench.evaluate(fixture(.descriptive))
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let failure as GlifiStudioFailure { #expect(failure.category == "cancelled") }
    }

    private func fixture(_ operation: GlifiStudioStatisticsOperation)
        -> GlifiStudioStatisticsRequest
    {
        var parameters = GlifiStudioStatisticsParameters()
        parameters.resampleCount = 100
        parameters.contrasts = [[1, -1, 0], [0.5, 0.5, -1]]
        let values: [[Double?]]
        let categories: [[String?]]
        switch operation.inputKind {
        case .series:
            values = [[1, 2, 4, 7, 8, 12]]
            categories = []
        case .pairedSeries:
            values = [[1, 4, 9, 16], [0, 2, 6, 12]]
            categories = []
        case .groups:
            values = [[1, 2, 4, 7], [3, 5, 8, 9], [6, 10, 11, 15]]
            categories = []
        case .counts:
            values = [[12, 8], [5, 15]]
            categories = []
        case .categories:
            values = []
            categories =
                operation == .cohenKappa
                ? [["A", "A"], ["A", "B"], ["B", "B"], ["A", "A"]]
                : [["A", "A", "B"], ["A", "B", "B"], ["B", "B", "B"], ["A", "A", "A"]]
        case .ratings:
            values = [[1, 1, 2], [1, 2, 2], [3, 3, nil], [2, 2, 3]]
            categories = []
        case .scalar:
            values = []
            categories = []
        }
        if operation == .bonferroni || operation == .benjaminiHochberg {
            return .init(
                operation: operation, values: [[0.01, 0.04, 0.2, 0.6]], parameters: parameters)
        }
        return .init(
            operation: operation, values: values, categories: categories, parameters: parameters)
    }

    private func reference(_ request: GlifiStudioStatisticsRequest) throws -> (
        metric: String?, column: Int, value: Double
    ) {
        let p = request.parameters
        let groups = request.values.map { $0.compactMap { $0 } }
        let a = groups.first ?? []
        let b = groups.dropFirst().first ?? []
        switch request.operation {
        case .descriptive:
            let result = try GlifiDescriptiveStatistics.summarize(
                request.values[0], unitIdentifier: p.unitIdentifier, variance: .sample,
                probabilities: p.probabilities)
            return ("mean", 0, try #require(result.mean))
        case .welchT: return ("p-value", 0, try GlifiStatisticalFoundation.welchTTest(a, b).pValue)
        case .oneSampleT:
            return ("p-value", 0, try GlifiStatisticalFoundation.oneSampleTTest(a).pValue)
        case .pairedT:
            return ("p-value", 0, try GlifiStatisticalFoundation.pairedTTest(a, b).pValue)
        case .anova:
            return ("p-value", 0, try GlifiStatisticalFoundation.oneWayANOVA(groups).pValue)
        case .welchANOVA:
            return ("p-value", 0, try GlifiStatisticalFoundation.welchOneWayANOVA(groups).pValue)
        case .mannWhitney:
            return ("p-value", 0, try GlifiStatisticalFoundation.mannWhitneyU(a, b).pValue)
        case .wilcoxon:
            return ("p-value", 0, try GlifiStatisticalFoundation.wilcoxonSignedRank(a, b).pValue)
        case .kruskalWallis:
            return ("p-value", 0, try GlifiStatisticalFoundation.kruskalWallis(groups).pValue)
        case .pearson:
            return (
                "t-statistic", 0, try GlifiStatisticalFoundation.pearsonCorrelation(a, b).tStatistic
            )
        case .spearman:
            return (
                "t-statistic", 0,
                try GlifiStatisticalFoundation.spearmanCorrelation(a, b).tStatistic
            )
        case .spearmanExact:
            return ("p-value", 0, try GlifiStatisticalFoundation.spearmanExactPValue(a, b))
        case .cohenD: return ("cohen-d", 0, try GlifiStatisticalFoundation.cohenDPooled(a, b).d)
        case .hedgesG:
            return (
                "hedges-g", 0, try GlifiStatisticalFoundation.standardizedDifference(a, b).hedgesG
            )
        case .rankBiserial:
            return (
                "rank-biserial", 0,
                GlifiStatisticalFoundation.rankBiserial(
                    u1: p.statistic, firstCount: p.firstCount, secondCount: p.secondCount)
            )
        case .epsilonSquared:
            return (
                "epsilon-squared", 0,
                GlifiStatisticalFoundation.kruskalEpsilonSquared(
                    correctedH: p.statistic, totalCount: p.firstCount)
            )
        case .pearsonInterval:
            return (
                "lower", 0,
                try GlifiStatisticalFoundation.pearsonFisherInterval(
                    coefficient: p.coefficient, sampleCount: p.firstCount
                ).lower
            )
        case .tukey:
            return (nil, 5, try #require(GlifiStatisticalFoundation.tukeyHSD(groups).first).pValue)
        case .gamesHowell:
            return (
                nil, 5, try #require(GlifiStatisticalFoundation.gamesHowell(groups).first).pValue
            )
        case .dunn:
            return (nil, 5, try #require(GlifiStatisticalFoundation.dunn(groups).first).pValue)
        case .bonferroni:
            return (
                nil, 2, try #require(GlifiStatisticalFoundation.bonferroniAdjustedPValues(a).first)
            )
        case .benjaminiHochberg:
            return (
                nil, 2,
                try #require(GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues(a).first)
            )
        case .bootstrapMean:
            return (
                "lower", 0,
                try GlifiStatisticalFoundation.bootstrapMeanInterval(
                    a, resampleCount: p.resampleCount, seed: p.seed
                ).lower
            )
        case .bootstrapBCa:
            return (
                "lower", 0,
                try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
                    a, resampleCount: p.resampleCount, seed: p.seed
                ).lower
            )
        case .blockBootstrap:
            return (
                "lower", 0,
                try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                    a, blockLength: p.blockLength, resampleCount: p.resampleCount, seed: p.seed
                ).lower
            )
        case .permutation:
            return (
                "p-value", 0,
                try GlifiStatisticalFoundation.permutationMeanDifference(
                    a, b, strategy: .monteCarlo(sampleCount: p.resampleCount, seed: p.seed)
                ).pValue
            )
        case .contingency:
            let table = try GlifiContingencyTable(
                rowLabels: ["0", "1"], columnLabels: ["0", "1"], cells: [[12, 8], [5, 15]])
            return (
                "chi-square", 0, try GlifiContingencyAnalysis.associate(table).chiSquareStatistic
            )
        case .fisherExact:
            return (
                "p-value", 0,
                try GlifiStatisticalFoundation.fisherExact([[12, 8], [5, 15]]).pValue
            )
        case .monteCarloChiSquare:
            return (
                "p-value", 0,
                try GlifiStatisticalFoundation.monteCarloChiSquare(
                    [[12, 8], [5, 15]], simulationCount: p.resampleCount, seed: p.seed
                ).pValue
            )
        case .cohenKappa:
            return (
                "kappa", 0,
                try GlifiAgreementAnalysis.cohenKappa(
                    rater1: request.categories.compactMap { $0[0] },
                    rater2: request.categories.compactMap { $0[1] }
                ).kappa
            )
        case .alphaNominal:
            return (
                "alpha", 0,
                try GlifiAgreementAnalysis.krippendorffAlphaNominal(request.categories).alpha
            )
        case .alphaNumeric:
            return (
                "alpha", 0,
                try GlifiAgreementAnalysis.krippendorffAlpha(request.values, level: .nominal).alpha
            )
        case .fleissKappa:
            return (
                "kappa", 0,
                try GlifiAgreementAnalysis.fleissKappa(
                    request.categories.map { $0.compactMap { $0 } }
                ).kappa
            )
        case .alphaInterval:
            return (
                "lower", 0,
                try GlifiAgreementAnalysis.krippendorffAlphaInterval(
                    request.values, level: .nominal, resampleCount: p.resampleCount, seed: p.seed
                ).lower
            )
        case .normalCDF: return ("value", 0, GlifiDistributionFunctions.normalCDF(p.statistic))
        case .normalDensity:
            return ("value", 0, GlifiDistributionFunctions.normalDensity(p.statistic))
        case .normalQuantile:
            return ("value", 0, try GlifiDistributionFunctions.normalQuantile(p.probability))
        case .tQuantile:
            return (
                "value", 0,
                try GlifiStatisticalFoundation.tQuantile(
                    p.probability, degreesOfFreedom: p.degreesOfFreedom)
            )
        case .tPValue:
            return (
                "p-value", 0,
                try GlifiStatisticalFoundation.tDistributionPValue(
                    statistic: p.statistic, degreesOfFreedom: p.degreesOfFreedom,
                    alternative: .twoSided)
            )
        case .fPValue:
            return (
                "p-value", 0,
                try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
                    statistic: p.statistic, numeratorDegreesOfFreedom: p.degreesOfFreedom,
                    denominatorDegreesOfFreedom: p.secondDegreesOfFreedom)
            )
        case .rangeCDF:
            return (
                "value", 0,
                GlifiDistributionFunctions.studentizedRangeCDF(
                    p.statistic, groupCount: p.groupCount, degreesOfFreedom: p.degreesOfFreedom)
            )
        case .rangeTail:
            return (
                "value", 0,
                GlifiDistributionFunctions.studentizedRangeUpperTail(
                    p.statistic, groupCount: p.groupCount, degreesOfFreedom: p.degreesOfFreedom)
            )
        case .rangeQuantile:
            return (
                "value", 0,
                try GlifiStatisticalFoundation.studentizedRangeQuantile(
                    p.probability, groupCount: p.groupCount, degreesOfFreedom: p.degreesOfFreedom)
            )
        case .plannedContrasts:
            return (
                nil, 5,
                try #require(
                    GlifiStatisticalFoundation.plannedContrasts(groups, contrasts: p.contrasts)
                        .first
                ).pValue
            )
        }
    }
}
