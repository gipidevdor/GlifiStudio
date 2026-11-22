// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Scientific operations exposed by the explicit-data statistical laboratory.
public enum GlifiStudioStatisticsOperation: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Exact descriptive statistics with missing observations and requested quantiles.
    case descriptive
    /// Welch's independent-sample t test.
    case welchT
    /// One-sample Student t test.
    case oneSampleT
    /// Paired Student t test.
    case pairedT
    /// Equal-variance one-way ANOVA.
    case anova
    /// Unequal-variance one-way ANOVA.
    case welchANOVA
    /// Mann–Whitney U, exact or asymptotic.
    case mannWhitney
    /// Wilcoxon signed-rank, exact or asymptotic.
    case wilcoxon
    /// Kruskal–Wallis rank test.
    case kruskalWallis
    /// Pearson correlation and asymptotic test.
    case pearson
    /// Spearman correlation and asymptotic test.
    case spearman
    /// Exact Spearman permutation p-value.
    case spearmanExact
    /// Pooled-variance Cohen d.
    case cohenD
    /// Hedges g and the normal-approximation interval of d.
    case hedgesG
    /// Rank-biserial effect size from declared U and sample sizes.
    case rankBiserial
    /// Kruskal epsilon squared from declared H and sample size.
    case epsilonSquared
    /// Fisher-z interval of a declared Pearson coefficient.
    case pearsonInterval
    /// Tukey–Kramer simultaneous comparisons.
    case tukey
    /// Games–Howell comparisons.
    case gamesHowell
    /// Dunn comparisons with raw p-values.
    case dunn
    /// Bonferroni adjustment of a declared family.
    case bonferroni
    /// Benjamini–Hochberg adjustment of a declared family.
    case benjaminiHochberg
    /// Independent-unit percentile bootstrap interval.
    case bootstrapMean
    /// Moving-block bootstrap interval for an ordered sequence.
    case blockBootstrap
    /// Exact or Monte Carlo permutation comparison of means.
    case permutation
    /// Pearson chi-square, Cramer V and standardized residuals.
    case contingency
    /// Fisher exact test of a two-by-two count table.
    case fisherExact
    /// Fixed-margin Monte Carlo chi-square test.
    case monteCarloChiSquare
    /// Nominal Cohen kappa for two complete raters.
    case cohenKappa
    /// Nominal Krippendorff alpha with missing ratings.
    case alphaNominal
    /// Numeric Krippendorff alpha at a declared measurement level.
    case alphaNumeric
    /// Fleiss kappa for complete categorical ratings.
    case fleissKappa
    /// Unit-bootstrap interval of numeric Krippendorff alpha.
    case alphaInterval
    /// Standard-normal cumulative distribution.
    case normalCDF
    /// Standard-normal density.
    case normalDensity
    /// Standard-normal quantile.
    case normalQuantile
    /// Student t p-value at declared degrees of freedom.
    case tPValue
    /// F upper-tail p-value at declared degrees of freedom.
    case fPValue
    /// Studentized-range cumulative distribution.
    case rangeCDF
    /// Studentized-range upper tail.
    case rangeTail
    /// Studentized-range quantile.
    case rangeQuantile
    /// Quantile of Student t at declared degrees of freedom.
    case tQuantile
    /// Bias-corrected accelerated bootstrap interval of the mean.
    case bootstrapBCa
    /// Explicit family of planned contrasts under the pooled-variance model.
    case plannedContrasts

    /// Stable operation identity.
    public var id: String { rawValue }

    /// Required shape of the explicit data editor.
    public var inputKind: GlifiStudioStatisticsInputKind {
        switch self {
        case .descriptive, .oneSampleT, .bonferroni, .benjaminiHochberg, .bootstrapMean,
            .bootstrapBCa,
            .blockBootstrap:
            .series
        case .welchT, .pairedT, .mannWhitney, .wilcoxon, .pearson, .spearman, .spearmanExact,
            .cohenD, .hedgesG, .permutation:
            .pairedSeries
        case .anova, .welchANOVA, .kruskalWallis, .tukey, .gamesHowell, .dunn, .plannedContrasts:
            .groups
        case .contingency, .fisherExact, .monteCarloChiSquare: .counts
        case .cohenKappa, .alphaNominal, .fleissKappa: .categories
        case .alphaNumeric, .alphaInterval: .ratings
        case .rankBiserial, .epsilonSquared, .pearsonInterval, .normalCDF, .normalDensity,
            .normalQuantile, .tQuantile, .tPValue, .fPValue, .rangeCDF, .rangeTail, .rangeQuantile:
            .scalar
        }
    }
}

/// Shape of explicit data, independent from the presentation language.
public enum GlifiStudioStatisticsInputKind: String, Codable, Sendable {
    /// One numeric series.
    case series
    /// Two numeric series; paired methods reject different lengths.
    case pairedSeries
    /// Two or more numeric groups.
    case groups
    /// Rectangular non-negative integer count table.
    case counts
    /// One unit per row and categorical rater values separated by TAB.
    case categories
    /// One unit per row and numeric rater values; question marks represent missing values.
    case ratings
    /// Only declared scalar parameters are needed.
    case scalar
}

/// Alternative hypothesis fixed before execution.
public enum GlifiStudioStatisticsAlternative: String, Codable, CaseIterable, Sendable {
    /// Difference from zero.
    case twoSided
    /// First sample location is smaller.
    case less
    /// First sample location is greater.
    case greater

    var coreValue: GlifiAlternativeHypothesis {
        switch self {
        case .twoSided: .twoSided
        case .less: .less
        case .greater: .greater
        }
    }
}

/// Shared scalar controls; only the applicable controls are interpreted by an operation.
public struct GlifiStudioStatisticsParameters: Codable, Equatable, Sendable {
    /// Declared test alternative.
    public var alternative: GlifiStudioStatisticsAlternative = .twoSided
    /// Exact enumeration instead of an asymptotic or Monte Carlo procedure.
    public var exact = false
    /// Continuity correction of an asymptotic rank test.
    public var continuityCorrection = true
    /// Confidence level of an interval.
    public var confidenceLevel = 0.95
    /// Hypothesized mean or mean difference.
    public var hypothesizedMean = 0.0
    /// Requested type-seven quantile probabilities.
    public var probabilities = [0.25, 0.5, 0.75]
    /// Shared physical or analytical unit of descriptive observations.
    public var unitIdentifier = "value"
    /// Sample variance rather than population variance.
    public var sampleVariance = true
    /// Number of bootstrap resamples or Monte Carlo simulations.
    public var resampleCount = 2_000
    /// Recorded pseudo-random seed.
    public var seed: UInt64 = 0
    /// Moving-block length.
    public var blockLength = 2
    /// Numeric alpha measurement level: nominal, ordinal, interval or ratio.
    public var measurementLevel = "nominal"
    /// Declared distribution statistic, effect-size U or corrected H.
    public var statistic = 1.0
    /// Distribution probability or quantile level.
    public var probability = 0.95
    /// First distribution degrees of freedom.
    public var degreesOfFreedom = 10.0
    /// Denominator F degrees of freedom.
    public var secondDegreesOfFreedom = 20.0
    /// Studentized-range group count.
    public var groupCount = 3
    /// First declared sample size.
    public var firstCount = 10
    /// Second declared sample size.
    public var secondCount = 10
    /// Declared Pearson coefficient for its Fisher-z interval.
    public var coefficient = 0.5

    /// One coefficient per group for each declared contrast; pooled variance is fixed by the core.
    public var contrasts: [[Double]] = []

    /// Creates the documented defaults without silently correcting later edits.
    public init() {}
}

/// Frozen explicit inputs of one session-only statistical calculation.
public struct GlifiStudioStatisticsRequest: Codable, Equatable, Sendable {
    /// Requested scientific operation.
    public let operation: GlifiStudioStatisticsOperation
    /// Numeric rows, preserving explicit missing values.
    public let values: [[Double?]]
    /// Categorical units and ratings, preserving explicit missing values.
    public let categories: [[String?]]
    /// Scalar controls captured when execution starts.
    public let parameters: GlifiStudioStatisticsParameters

    /// Creates a request; execution checks shape, finiteness and work limits.
    public init(
        operation: GlifiStudioStatisticsOperation, values: [[Double?]] = [],
        categories: [[String?]] = [], parameters: GlifiStudioStatisticsParameters = .init()
    ) {
        self.operation = operation
        self.values = values
        self.categories = categories
        self.parameters = parameters
    }
}

/// A finite number, an explicitly infinite statistic, text, or an undefined result.
public enum GlifiStudioStatisticsValue: Codable, Equatable, Sendable {
    /// A finite binary64 value.
    case number(Double)
    /// A count or index.
    case integer(Int)
    /// Literal identity or caller-supplied category.
    case text(String)
    /// A mathematically positive infinite statistic.
    case positiveInfinity
    /// A mathematically negative infinite statistic.
    case negativeInfinity
    /// Not defined or not provided by the numerical method.
    case undefined

    static func numberOrUndefined(_ value: Double?) throws -> Self {
        guard let value else { return .undefined }
        guard !value.isNaN else {
            throw statisticsWorkbenchFailure("invalid-result", category: "corruption")
        }
        if value == .infinity { return .positiveInfinity }
        if value == -.infinity { return .negativeInfinity }
        return .number(value)
    }
}

/// One presentation-independent scalar result with a semantic label.
public struct GlifiStudioStatisticsMetric: Codable, Equatable, Sendable {
    /// Semantic metric key, localized by the app.
    public let key: String
    /// Exact returned value, including undefined and infinite states.
    public let value: GlifiStudioStatisticsValue
}

/// Complete session result, with the frozen request, method and bounded table.
public struct GlifiStudioStatisticsResult: Codable, Equatable, Sendable {
    /// Exact request used by the calculation; editor changes do not rewrite it.
    public let request: GlifiStudioStatisticsRequest
    /// SHA-256 of sorted-key request JSON, independent from locale.
    public let requestDigest: String
    /// Versioned core method identity.
    public let methodIdentifier: String
    /// Scalar results and diagnostics supplied by the core.
    public let metrics: [GlifiStudioStatisticsMetric]
    /// Semantic table-column keys.
    public let columns: [String]
    /// Complete bounded table; the app paginates without recalculating it.
    public let rows: [[GlifiStudioStatisticsValue]]
}

/// Explicit-data access to every public statistical calculation of GlifiCore.
public enum GlifiStudioStatisticsWorkbench {
    /// Maximum UTF-8 editor input; this is an explicit laboratory limit.
    public static let maximumInputBytes = 1_048_576
    /// Maximum aggregate observations or ratings in one request.
    public static let maximumObservationCount = 100_000
    /// Maximum group count for the explicit-data editor.
    public static let maximumGroupCount = 64
    /// Maximum declared categorical or numeric alpha alphabet.
    public static let maximumCategoryCount = 256
    /// Maximum approximate observation-by-resample work before admission.
    public static let maximumResamplingWork = 20_000_000

    /// Parses the documented editor grammar off the caller's actor.
    ///
    /// Numeric values use whitespace separators and either a decimal point or comma;
    /// mixed decimal/grouping separators are rejected. Categorical cells use TAB.
    @concurrent public static func request(
        operation: GlifiStudioStatisticsOperation, input: String,
        parameters: GlifiStudioStatisticsParameters
    ) async throws(GlifiStudioFailure) -> GlifiStudioStatisticsRequest {
        do {
            try Task.checkCancellation()
            guard input.utf8.count <= maximumInputBytes else {
                throw statisticsWorkbenchFailure("input-limit", category: "insufficientResources")
            }
            if operation.inputKind == .scalar {
                return GlifiStudioStatisticsRequest(operation: operation, parameters: parameters)
            }
            let normalized = input.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let trimmed = normalized.trimmingCharacters(in: .newlines)
            guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw statisticsWorkbenchFailure("empty-input")
            }
            let lines = trimmed.components(separatedBy: "\n")
            var values: [[Double?]] = []
            var categories: [[String?]] = []
            var count = 0
            for line in lines {
                try Task.checkCancellation()
                if operation.inputKind == .categories {
                    let cells = line.components(separatedBy: "\t")
                    let row: [String?] = cells.map {
                        let text = $0.trimmingCharacters(in: .whitespaces)
                        return text.isEmpty || text == "?" ? nil : text
                    }
                    guard !row.isEmpty else { throw statisticsWorkbenchFailure("empty-row") }
                    categories.append(row)
                    count += row.count
                } else {
                    let tokens = line.split(whereSeparator: \.isWhitespace)
                    guard !tokens.isEmpty else { throw statisticsWorkbenchFailure("empty-row") }
                    let row = try tokens.map { token -> Double? in
                        if token == "?" { return nil }
                        return try decimal(String(token))
                    }
                    values.append(row)
                    count += row.count
                }
                guard count <= maximumObservationCount else {
                    throw statisticsWorkbenchFailure(
                        "input-limit", category: "insufficientResources")
                }
            }
            return GlifiStudioStatisticsRequest(
                operation: operation, values: values, categories: categories, parameters: parameters
            )
        } catch let failure as GlifiStudioFailure { throw failure } catch {
            throw statisticsWorkbenchFailure("cancelled", category: "cancelled")
        }
    }

    /// Evaluates the requested core method off the caller's actor, preserving its numerical contract.
    @concurrent public static func evaluate(
        _ request: GlifiStudioStatisticsRequest
    ) async throws(GlifiStudioFailure) -> GlifiStudioStatisticsResult {
        do {
            try Task.checkCancellation()
            try validate(request)
            var builder = StatisticsResultBuilder(request: request)
            try builder.calculate()
            try Task.checkCancellation()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let encoded = try encoder.encode(request)
            return GlifiStudioStatisticsResult(
                request: request,
                requestDigest: SHA256.hash(data: encoded).map { String(format: "%02x", $0) }
                    .joined(),
                methodIdentifier: builder.method, metrics: builder.metrics,
                columns: builder.columns, rows: builder.rows)
        } catch let failure as GlifiStudioFailure { throw failure } catch let failure
            as GlifiFailure
        { throw GlifiStudioFailure(failure) } catch is CancellationError {
            throw statisticsWorkbenchFailure("cancelled", category: "cancelled")
        } catch { throw statisticsWorkbenchFailure("failed", category: "insufficientData") }
    }

    private static func decimal(_ token: String) throws -> Double {
        guard
            token.range(
                of: #"^[+-]?(?:[0-9]+(?:[.,][0-9]*)?|[.,][0-9]+)(?:[eE][+-]?[0-9]+)?$"#,
                options: .regularExpression) != nil,
            !(token.contains(".") && token.contains(",")),
            let value = Double(token.replacingOccurrences(of: ",", with: ".")), value.isFinite
        else { throw statisticsWorkbenchFailure("invalid-number") }
        return value
    }

    private static func validate(_ request: GlifiStudioStatisticsRequest) throws {
        let total = request.values.reduce(0) { $0 + $1.count }
        let nominalTotal = request.categories.reduce(0) { $0 + $1.count }
        guard total <= maximumObservationCount, nominalTotal <= maximumObservationCount,
            request.values.allSatisfy({ $0.allSatisfy { $0.map(\.isFinite) ?? true } })
        else { throw statisticsWorkbenchFailure("input-limit", category: "insufficientResources") }
        switch request.operation.inputKind {
        case .series:
            guard request.values.count == 1 else {
                throw statisticsWorkbenchFailure("one-series-required")
            }
        case .pairedSeries:
            guard request.values.count == 2 else {
                throw statisticsWorkbenchFailure("two-series-required")
            }
        case .groups, .counts:
            guard (2...maximumGroupCount).contains(request.values.count) else {
                throw statisticsWorkbenchFailure("group-limit")
            }
        case .categories:
            guard !request.categories.isEmpty,
                request.categories.allSatisfy({ !$0.isEmpty && $0.count <= maximumGroupCount }),
                Set(request.categories.flatMap { $0.compactMap { $0 } }).count
                    <= maximumCategoryCount
            else { throw statisticsWorkbenchFailure("category-limit") }
        case .ratings:
            guard !request.values.isEmpty,
                request.values.allSatisfy({ !$0.isEmpty && $0.count <= maximumGroupCount }),
                Set(request.values.flatMap { $0.compactMap { $0 } }).count <= maximumCategoryCount
            else { throw statisticsWorkbenchFailure("category-limit") }
        case .scalar: break
        }
        guard
            request.categories.flatMap({ $0 }).reduce(0, { $0 + ($1?.utf8.count ?? 0) })
                <= maximumInputBytes
        else {
            throw statisticsWorkbenchFailure("input-limit", category: "insufficientResources")
        }
        if [.alphaNominal, .alphaNumeric, .alphaInterval].contains(request.operation) {
            let counts =
                request.operation == .alphaNominal
                ? request.categories.map(\.count) : request.values.map(\.count)
            let pairWork = counts.reduce(0) { $0 + $1 * $1 }
            let repetitions =
                request.operation == .alphaInterval ? request.parameters.resampleCount : 1
            guard repetitions > 0, pairWork <= maximumResamplingWork / repetitions else {
                throw statisticsWorkbenchFailure("work-limit", category: "insufficientResources")
            }
        }
        if request.operation == .permutation && request.parameters.exact {
            // The core sums the first group for every assignment. Bound that work as well as
            // the assignment count, including strongly unbalanced groups.
            let firstCount = request.values.first?.count ?? 0
            let limit = min(
                GlifiStatisticalFoundation.maximumExactPermutationCount,
                maximumResamplingWork / max(1, firstCount))
            let selectedCount = min(firstCount, total - firstCount)
            var assignments = 1
            if selectedCount > 0 {
                for selected in 1...selectedCount {
                    let product = assignments.multipliedReportingOverflow(by: total - selected + 1)
                    guard !product.overflow else {
                        throw statisticsWorkbenchFailure(
                            "work-limit", category: "insufficientResources")
                    }
                    assignments = product.partialValue / selected
                    guard assignments <= limit else {
                        throw statisticsWorkbenchFailure(
                            "work-limit", category: "insufficientResources")
                    }
                }
            }
        }
        let resampling: Bool
        switch request.operation {
        case .bootstrapMean, .bootstrapBCa, .blockBootstrap, .monteCarloChiSquare, .alphaInterval:
            resampling = true
        case .permutation: resampling = !request.parameters.exact
        case .descriptive, .welchT, .oneSampleT, .pairedT, .anova, .welchANOVA, .mannWhitney,
            .wilcoxon, .kruskalWallis, .pearson, .spearman, .spearmanExact, .cohenD, .hedgesG,
            .rankBiserial, .epsilonSquared, .pearsonInterval, .tukey, .gamesHowell, .dunn,
            .bonferroni, .benjaminiHochberg, .contingency, .fisherExact, .cohenKappa,
            .alphaNominal, .alphaNumeric, .fleissKappa, .normalCDF, .normalDensity,
            .normalQuantile, .tQuantile, .plannedContrasts, .tPValue, .fPValue, .rangeCDF,
            .rangeTail, .rangeQuantile:
            resampling = false
        }
        if resampling {
            let iterations = request.parameters.resampleCount
            guard (1...GlifiStatisticalFoundation.maximumResampleCount).contains(iterations),
                total <= maximumResamplingWork / iterations
            else {
                throw statisticsWorkbenchFailure("work-limit", category: "insufficientResources")
            }
        }
        if request.operation == .alphaInterval {
            let categories = Set(request.values.flatMap { $0.compactMap { $0 } }).count
            guard
                categories * categories <= maximumResamplingWork / request.parameters.resampleCount
            else {
                throw statisticsWorkbenchFailure("work-limit", category: "insufficientResources")
            }
        }
    }
}

private struct StatisticsResultBuilder {
    let request: GlifiStudioStatisticsRequest
    var method = ""
    var metrics: [GlifiStudioStatisticsMetric] = []
    var columns: [String] = []
    var rows: [[GlifiStudioStatisticsValue]] = []
    var p: GlifiStudioStatisticsParameters { request.parameters }
    var groups: [[Double]] {
        get throws {
            try request.values.map { row in
                try row.map { value in
                    guard let value else {
                        throw statisticsWorkbenchFailure("missing-not-supported")
                    }
                    return value
                }
            }
        }
    }
    mutating func number(_ key: String, _ value: Double?) throws {
        metrics.append(.init(key: "statistics.metric.\(key)", value: try .numberOrUndefined(value)))
    }
    mutating func integer(_ key: String, _ value: Int) {
        metrics.append(.init(key: "statistics.metric.\(key)", value: .integer(value)))
    }
    mutating func text(_ key: String, _ value: String) {
        metrics.append(.init(key: "statistics.metric.\(key)", value: .text(value)))
    }

    mutating func calculate() throws {
        switch request.operation {
        case .descriptive:
            let result = try GlifiDescriptiveStatistics.summarize(
                request.values[0], unitIdentifier: p.unitIdentifier,
                variance: p.sampleVariance ? .sample : .population, probabilities: p.probabilities)
            method = result.methodIdentifier
            integer("valid-count", result.validCount)
            integer("missing-count", result.missingCount)
            try number("minimum", result.minimum)
            try number("maximum", result.maximum)
            try number("mean", result.mean)
            try number("median", result.median)
            try number("variance", result.variance)
            try number("standard-deviation", result.standardDeviation)
            text("unit", result.unitIdentifier)
            text("missing-policy", result.missingPolicyIdentifier)
            text("variance-convention", result.varianceConvention.rawValue)
            columns = ["statistics.column.probability", "statistics.column.quantile"]
            rows = try result.quantiles.map {
                [.number($0.probability), try .numberOrUndefined($0.value)]
            }
        case .welchT:
            let data = try groups
            let result = try GlifiStatisticalFoundation.welchTTest(
                data[0], data[1], alternative: p.alternative.coreValue)
            method = GlifiWelchTTestResult.identifier
            try number("statistic", result.statistic)
            try number("degrees-of-freedom", result.degreesOfFreedom)
            try number("p-value", result.pValue)
        case .oneSampleT, .pairedT:
            let data = try groups
            let result =
                try request.operation == .oneSampleT
                ? GlifiStatisticalFoundation.oneSampleTTest(
                    data[0], hypothesizedMean: p.hypothesizedMean,
                    alternative: p.alternative.coreValue)
                : GlifiStatisticalFoundation.pairedTTest(
                    data[0], data[1], hypothesizedDifference: p.hypothesizedMean,
                    alternative: p.alternative.coreValue)
            method = result.methodIdentifier
            try number("hypothesized-mean", result.hypothesizedMean)
            try number("mean", result.mean)
            try number("standard-deviation", result.standardDeviation)
            integer("sample-count", result.sampleCount)
            try number("statistic", result.statistic)
            integer("degrees-of-freedom", result.degreesOfFreedom)
            try number("p-value", result.pValue)
        case .anova:
            let result = try GlifiStatisticalFoundation.oneWayANOVA(groups)
            method = GlifiOneWayANOVAResult.identifier
            try number("f-statistic", result.fStatistic)
            integer("numerator-df", result.numeratorDegreesOfFreedom)
            integer("denominator-df", result.denominatorDegreesOfFreedom)
            try number("p-value", result.pValue)
        case .welchANOVA:
            let result = try GlifiStatisticalFoundation.welchOneWayANOVA(groups)
            method = GlifiWelchANOVAResult.identifier
            try number("f-statistic", result.fStatistic)
            integer("numerator-df", result.numeratorDegreesOfFreedom)
            try number("denominator-df", result.denominatorDegreesOfFreedom)
            try number("p-value", result.pValue)
        case .mannWhitney:
            let data = try groups
            let result = try GlifiStatisticalFoundation.mannWhitneyU(
                data[0], data[1], alternative: p.alternative.coreValue,
                method: p.exact ? .exact : .asymptotic(continuityCorrection: p.continuityCorrection)
            )
            method = GlifiMannWhitneyUResult.identifier
            try number("u-first", result.u1)
            try number("u-second", result.u2)
            integer("first-count", result.firstSampleCount)
            integer("second-count", result.secondSampleCount)
            try number("z-statistic", result.zStatistic)
            try number("p-value", result.pValue)
            try number(
                "rank-biserial",
                GlifiStatisticalFoundation.rankBiserial(
                    u1: result.u1, firstCount: result.firstSampleCount,
                    secondCount: result.secondSampleCount))
        case .wilcoxon:
            let data = try groups
            let result = try GlifiStatisticalFoundation.wilcoxonSignedRank(
                data[0], data[1], alternative: p.alternative.coreValue,
                method: p.exact ? .exact : .asymptotic(continuityCorrection: p.continuityCorrection)
            )
            method = GlifiWilcoxonSignedRankResult.identifier
            try number("positive-rank-sum", result.positiveRankSum)
            try number("negative-rank-sum", result.negativeRankSum)
            integer("ranked-count", result.rankedCount)
            integer("dropped-zero-count", result.droppedZeroCount)
            try number("z-statistic", result.zStatistic)
            try number("p-value", result.pValue)
            text("zero-policy", GlifiWilcoxonSignedRankResult.zeroPolicyIdentifier)
        case .kruskalWallis:
            let result = try GlifiStatisticalFoundation.kruskalWallis(groups)
            method = GlifiKruskalWallisResult.identifier
            try number("h-statistic", result.hStatistic)
            try number("tie-correction", result.tieCorrection)
            try number("corrected-h", result.correctedHStatistic)
            integer("degrees-of-freedom", result.degreesOfFreedom)
            try number("p-value", result.pValue)
        case .pearson, .spearman:
            let data = try groups
            let result =
                try request.operation == .pearson
                ? GlifiStatisticalFoundation.pearsonCorrelation(
                    data[0], data[1], alternative: p.alternative.coreValue)
                : GlifiStatisticalFoundation.spearmanCorrelation(
                    data[0], data[1], alternative: p.alternative.coreValue)
            method = result.methodIdentifier
            try number("coefficient", result.coefficient)
            integer("sample-count", result.sampleCount)
            try number("t-statistic", result.tStatistic)
            integer("degrees-of-freedom", result.degreesOfFreedom)
            try number("p-value", result.pValue)
        case .spearmanExact:
            let data = try groups
            method = GlifiStatisticalFoundation.spearmanExactIdentifier
            try number(
                "p-value",
                GlifiStatisticalFoundation.spearmanExactPValue(
                    data[0], data[1], alternative: p.alternative.coreValue))
        case .cohenD:
            let data = try groups
            let result = try GlifiStatisticalFoundation.cohenDPooled(data[0], data[1])
            method = GlifiCohenDResult.identifier
            try number("cohen-d", result.d)
            try number("pooled-standard-deviation", result.pooledStandardDeviation)
        case .hedgesG:
            let data = try groups
            let result = try GlifiStatisticalFoundation.standardizedDifference(
                data[0], data[1], confidenceLevel: p.confidenceLevel)
            method = GlifiStatisticalFoundation.hedgesIdentifier
            try number("cohen-d", result.cohenD)
            try number("hedges-g", result.hedgesG)
            try number("correction-factor", result.correctionFactor)
            try number("standard-error", result.standardError)
            try number("confidence-level", result.confidenceLevel)
            try number("lower", result.lower)
            try number("upper", result.upper)
        case .rankBiserial:
            guard p.statistic.isFinite, p.firstCount > 0, p.secondCount > 0,
                p.firstCount <= 1_000_000, p.secondCount <= 1_000_000,
                p.statistic >= 0, p.statistic <= Double(p.firstCount) * Double(p.secondCount)
            else { throw statisticsWorkbenchFailure("invalid-effect-parameters") }
            method = GlifiStatisticalFoundation.rankBiserialIdentifier
            try number(
                "rank-biserial",
                GlifiStatisticalFoundation.rankBiserial(
                    u1: p.statistic, firstCount: p.firstCount, secondCount: p.secondCount))
        case .epsilonSquared:
            guard p.statistic.isFinite, p.statistic >= 0, p.firstCount >= 2 else {
                throw statisticsWorkbenchFailure("invalid-effect-parameters")
            }
            method = GlifiStatisticalFoundation.epsilonSquaredIdentifier
            try number(
                "epsilon-squared",
                GlifiStatisticalFoundation.kruskalEpsilonSquared(
                    correctedH: p.statistic, totalCount: p.firstCount))
        case .pearsonInterval:
            let result = try GlifiStatisticalFoundation.pearsonFisherInterval(
                coefficient: p.coefficient, sampleCount: p.firstCount,
                confidenceLevel: p.confidenceLevel)
            method = GlifiCorrelationInterval.identifier
            try number("confidence-level", result.confidenceLevel)
            try number("lower", result.lower)
            try number("upper", result.upper)
        case .tukey, .gamesHowell, .dunn:
            let data = try groups
            guard data.count <= 20 else {
                throw statisticsWorkbenchFailure(
                    "post-hoc-group-limit", category: "insufficientResources")
            }
            let comparisons: [GlifiPostHocComparison]
            switch request.operation {
            case .tukey:
                comparisons = try GlifiStatisticalFoundation.tukeyHSD(
                    data, confidenceLevel: p.confidenceLevel)
                method = GlifiStatisticalFoundation.tukeyIdentifier
            case .gamesHowell:
                comparisons = try GlifiStatisticalFoundation.gamesHowell(data)
                method = GlifiStatisticalFoundation.gamesHowellIdentifier
            case .dunn:
                comparisons = try GlifiStatisticalFoundation.dunn(data)
                method = GlifiStatisticalFoundation.dunnIdentifier
            case .descriptive, .welchT, .oneSampleT, .pairedT, .anova, .welchANOVA, .mannWhitney,
                .wilcoxon, .kruskalWallis, .pearson, .spearman, .spearmanExact, .cohenD, .hedgesG,
                .rankBiserial, .epsilonSquared, .pearsonInterval, .bonferroni, .benjaminiHochberg,
                .bootstrapMean, .blockBootstrap, .permutation, .contingency, .fisherExact,
                .monteCarloChiSquare, .cohenKappa, .alphaNominal, .alphaNumeric, .fleissKappa,
                .alphaInterval, .normalCDF, .normalDensity, .normalQuantile, .tPValue, .fPValue,
                .rangeCDF, .rangeTail, .rangeQuantile, .tQuantile, .bootstrapBCa, .plannedContrasts:
                throw statisticsWorkbenchFailure("invalid-operation")
            }
            columns = [
                "statistics.column.first-group", "statistics.column.second-group",
                "statistics.column.difference", "statistics.column.statistic",
                "statistics.column.df", "statistics.column.p-value", "statistics.column.lower",
                "statistics.column.upper",
            ]
            rows = try comparisons.map {
                [
                    .integer($0.firstGroupIndex + 1), .integer($0.secondGroupIndex + 1),
                    try .numberOrUndefined($0.difference), try .numberOrUndefined($0.statistic),
                    try .numberOrUndefined($0.degreesOfFreedom), try .numberOrUndefined($0.pValue),
                    try .numberOrUndefined($0.lower), try .numberOrUndefined($0.upper),
                ]
            }
        case .bonferroni, .benjaminiHochberg:
            let values = try groups[0]
            let adjusted =
                try request.operation == .bonferroni
                ? GlifiStatisticalFoundation.bonferroniAdjustedPValues(values)
                : GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues(values)
            method = request.operation == .bonferroni ? "Bonferroni-v1" : "BenjaminiHochberg-v1"
            columns = [
                "statistics.column.index", "statistics.column.p-value",
                "statistics.column.adjusted-p",
            ]
            rows = zip(values, adjusted).enumerated().map {
                [.integer($0.offset + 1), .number($0.element.0), .number($0.element.1)]
            }
        case .bootstrapMean, .blockBootstrap:
            let data = try groups[0]
            let result =
                try request.operation == .bootstrapMean
                ? GlifiStatisticalFoundation.bootstrapMeanInterval(
                    data, confidenceLevel: p.confidenceLevel, resampleCount: p.resampleCount,
                    seed: p.seed)
                : GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                    data, blockLength: p.blockLength, confidenceLevel: p.confidenceLevel,
                    resampleCount: p.resampleCount, seed: p.seed)
            method =
                request.operation == .bootstrapMean
                ? GlifiBootstrapInterval.identifier : "MovingBlockBootstrap-v1"
            try number("estimate", result.estimate)
            try number("confidence-level", result.confidenceLevel)
            try number("lower", result.lower)
            try number("upper", result.upper)
            integer("resample-count", result.resampleCount)
            text("generator", result.generatorIdentifier)
            text("seed", String(result.seed))
            text("quantile-method", GlifiBootstrapInterval.quantileIdentifier)
        case .permutation:
            let data = try groups
            let result = try GlifiStatisticalFoundation.permutationMeanDifference(
                data[0], data[1], alternative: p.alternative.coreValue,
                strategy: p.exact ? .exact : .monteCarlo(sampleCount: p.resampleCount, seed: p.seed)
            )
            method = GlifiPermutationTestResult.identifier
            try number("observed-difference", result.observedDifference)
            integer("evaluated-count", result.evaluatedCount)
            integer("extreme-count", result.extremeCount)
            try number("p-value", result.pValue)
        case .contingency, .fisherExact, .monteCarloChiSquare:
            let table = try countTable()
            if request.operation == .contingency {
                let result = try GlifiContingencyAnalysis.associate(
                    GlifiContingencyTable(
                        rowLabels: table.indices.map(String.init),
                        columnLabels: (table.first?.indices ?? 0..<0).map(String.init), cells: table
                    ))
                method = GlifiContingencyAssociation.chiSquareIdentifier
                try number("chi-square", result.chiSquareStatistic)
                integer("degrees-of-freedom", result.degreesOfFreedom)
                try number("p-value", result.pValue)
                try number("cramers-v", result.cramersV)
                text(
                    "excluded-rows",
                    result.excludedRowIndices.map { String($0 + 1) }.joined(separator: ", "))
                text(
                    "excluded-columns",
                    result.excludedColumnIndices.map { String($0 + 1) }.joined(separator: ", "))
                columns = [
                    "statistics.column.row", "statistics.column.column",
                    "statistics.column.residual",
                ]
                for (row, values) in result.standardizedResiduals.enumerated() {
                    for (column, value) in values.enumerated() {
                        rows.append([
                            .integer(row + 1), .integer(column + 1), try .numberOrUndefined(value),
                        ])
                    }
                }
            } else if request.operation == .fisherExact {
                let result = try GlifiStatisticalFoundation.fisherExact(
                    table, alternative: p.alternative.coreValue)
                method = GlifiFisherExactResult.identifier
                try number("p-value", result.pValue)
                try number("table-probability", result.tableProbability)
                try number("odds-ratio", result.sampleOddsRatio)
            } else {
                let total = table.reduce(0) { $0 + $1.reduce(0, +) }
                guard
                    total <= GlifiStudioStatisticsWorkbench.maximumResamplingWork / p.resampleCount
                else {
                    throw statisticsWorkbenchFailure(
                        "work-limit", category: "insufficientResources")
                }
                let result = try GlifiStatisticalFoundation.monteCarloChiSquare(
                    table, simulationCount: p.resampleCount, seed: p.seed)
                method = GlifiMonteCarloChiSquareResult.identifier
                try number("chi-square", result.statistic)
                try number("p-value", result.pValue)
                integer("simulation-count", result.simulationCount)
                text("seed", String(result.seed))
            }
        case .cohenKappa:
            guard request.categories.allSatisfy({ $0.count == 2 && $0.allSatisfy { $0 != nil } })
            else { throw statisticsWorkbenchFailure("complete-two-raters-required") }
            let first = request.categories.compactMap { $0[0] }
            let second = request.categories.compactMap { $0[1] }
            let result = try GlifiAgreementAnalysis.cohenKappa(rater1: first, rater2: second)
            method = GlifiCohenKappaResult.identifier
            try number("observed-agreement", result.observedAgreement)
            try number("expected-agreement", result.expectedAgreement)
            try number("kappa", result.kappa)
            integer("unit-count", result.unitCount)
        case .alphaNominal:
            let result = try GlifiAgreementAnalysis.krippendorffAlphaNominal(request.categories)
            method = GlifiKrippendorffAlphaResult.identifier
            try number("observed-disagreement", result.observedDisagreement)
            try number("expected-disagreement", result.expectedDisagreement)
            try number("alpha", result.alpha)
            integer("included-units", result.includedUnitCount)
        case .fleissKappa:
            guard request.categories.allSatisfy({ $0.allSatisfy { $0 != nil } }) else {
                throw statisticsWorkbenchFailure("complete-raters-required")
            }
            let result = try GlifiAgreementAnalysis.fleissKappa(
                request.categories.map { $0.compactMap { $0 } })
            method = GlifiFleissKappaResult.identifier
            try number("observed-agreement", result.observedAgreement)
            try number("expected-agreement", result.expectedAgreement)
            try number("kappa", result.kappa)
        case .alphaNumeric, .alphaInterval:
            guard let level = GlifiMeasurementLevel(rawValue: p.measurementLevel) else {
                throw statisticsWorkbenchFailure("invalid-measurement-level")
            }
            if request.operation == .alphaNumeric {
                let result = try GlifiAgreementAnalysis.krippendorffAlpha(
                    request.values, level: level)
                method = GlifiLeveledAlphaResult.identifier
                try number("alpha", result.alpha)
                integer("pairable-values", result.pairableValueCount)
                integer("included-units", result.includedUnitCount)
            } else {
                let result = try GlifiAgreementAnalysis.krippendorffAlphaInterval(
                    request.values, level: level, confidenceLevel: p.confidenceLevel,
                    resampleCount: p.resampleCount, seed: p.seed)
                method = GlifiAlphaInterval.identifier
                try number("confidence-level", result.confidenceLevel)
                try number("lower", result.lower)
                try number("upper", result.upper)
                integer("valid-resamples", result.validResampleCount)
                integer("resample-count", result.resampleCount)
                text("seed", String(result.seed))
            }
        case .bootstrapBCa:
            let result = try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
                groups[0], confidenceLevel: p.confidenceLevel, resampleCount: p.resampleCount,
                seed: p.seed)
            method = GlifiBCaInterval.identifier
            try number("estimate", result.estimate)
            try number("confidence-level", result.confidenceLevel)
            try number("bias-correction", result.biasCorrection)
            try number("acceleration", result.acceleration)
            try number("lower-probability", result.lowerProbability)
            try number("upper-probability", result.upperProbability)
            try number("lower", result.lower)
            try number("upper", result.upper)
            integer("resample-count", result.resampleCount)
            text("seed", String(result.seed))
        case .plannedContrasts:
            guard p.contrasts.count <= 1_000, p.contrasts.reduce(0, { $0 + $1.count }) <= 100_000
            else {
                throw statisticsWorkbenchFailure(
                    "contrast-limit", category: "insufficientResources")
            }
            let comparisons = try GlifiStatisticalFoundation.plannedContrasts(
                groups, contrasts: p.contrasts, confidenceLevel: p.confidenceLevel)
            method = GlifiStatisticalFoundation.plannedContrastIdentifier
            columns = [
                "statistics.column.coefficients", "statistics.column.estimate",
                "statistics.column.standard-error", "statistics.column.statistic",
                "statistics.column.df", "statistics.column.p-value",
                "statistics.column.bonferroni-p", "statistics.column.bh-p",
                "statistics.column.lower", "statistics.column.upper",
            ]
            rows = try comparisons.map {
                [
                    .text($0.coefficients.map { String($0) }.joined(separator: " ")),
                    try .numberOrUndefined($0.estimate), try .numberOrUndefined($0.standardError),
                    try .numberOrUndefined($0.tStatistic), .integer($0.degreesOfFreedom),
                    try .numberOrUndefined($0.pValue), try .numberOrUndefined($0.bonferroniPValue),
                    try .numberOrUndefined($0.benjaminiHochbergPValue),
                    try .numberOrUndefined($0.lower), try .numberOrUndefined($0.upper),
                ]
            }
        case .normalCDF, .normalDensity, .normalQuantile, .tQuantile, .tPValue, .fPValue, .rangeCDF,
            .rangeTail,
            .rangeQuantile:
            try distribution()
        }
    }

    mutating func distribution() throws {
        switch request.operation {
        case .normalCDF, .normalDensity:
            guard p.statistic.isFinite else {
                throw statisticsWorkbenchFailure("invalid-distribution-parameters")
            }
            method = request.operation == .normalCDF ? "NormalCDF-v1" : "NormalDensity-v1"
            try number(
                "value",
                request.operation == .normalCDF
                    ? GlifiDistributionFunctions.normalCDF(p.statistic)
                    : GlifiDistributionFunctions.normalDensity(p.statistic))
        case .normalQuantile:
            method = "NormalQuantile-v1"
            try number("value", GlifiDistributionFunctions.normalQuantile(p.probability))
        case .tQuantile:
            guard p.degreesOfFreedom.isFinite else {
                throw statisticsWorkbenchFailure("invalid-distribution-parameters")
            }
            method = "StudentTQuantile-v1"
            try number(
                "value",
                GlifiStatisticalFoundation.tQuantile(
                    p.probability, degreesOfFreedom: p.degreesOfFreedom))
        case .tPValue:
            method = "StudentTPValue-v1"
            try number(
                "p-value",
                GlifiStatisticalFoundation.tDistributionPValue(
                    statistic: p.statistic, degreesOfFreedom: p.degreesOfFreedom,
                    alternative: p.alternative.coreValue))
        case .fPValue:
            method = "FUpperTailPValue-v1"
            try number(
                "p-value",
                GlifiStatisticalFoundation.fDistributionUpperTailPValue(
                    statistic: p.statistic, numeratorDegreesOfFreedom: p.degreesOfFreedom,
                    denominatorDegreesOfFreedom: p.secondDegreesOfFreedom))
        case .rangeCDF, .rangeTail, .rangeQuantile:
            guard p.groupCount >= 2, p.groupCount <= 100_000, p.degreesOfFreedom.isFinite,
                p.degreesOfFreedom > 0
            else { throw statisticsWorkbenchFailure("invalid-distribution-parameters") }
            if request.operation == .rangeQuantile {
                method = "StudentizedRangeQuantile-v1"
                try number(
                    "value",
                    GlifiStatisticalFoundation.studentizedRangeQuantile(
                        p.probability, groupCount: p.groupCount,
                        degreesOfFreedom: p.degreesOfFreedom))
            } else {
                guard p.statistic.isFinite, p.statistic >= 0 else {
                    throw statisticsWorkbenchFailure("invalid-distribution-parameters")
                }
                method =
                    request.operation == .rangeCDF
                    ? "StudentizedRangeCDF-v1" : "StudentizedRangeUpperTail-v1"
                try number(
                    "value",
                    request.operation == .rangeCDF
                        ? GlifiDistributionFunctions.studentizedRangeCDF(
                            p.statistic, groupCount: p.groupCount,
                            degreesOfFreedom: p.degreesOfFreedom)
                        : GlifiDistributionFunctions.studentizedRangeUpperTail(
                            p.statistic, groupCount: p.groupCount,
                            degreesOfFreedom: p.degreesOfFreedom))
            }
        case .descriptive, .welchT, .oneSampleT, .pairedT, .anova, .welchANOVA, .mannWhitney,
            .wilcoxon, .kruskalWallis, .pearson, .spearman, .spearmanExact, .cohenD, .hedgesG,
            .rankBiserial, .epsilonSquared, .pearsonInterval, .tukey, .gamesHowell, .dunn,
            .bonferroni, .benjaminiHochberg, .bootstrapMean, .blockBootstrap, .permutation,
            .contingency, .fisherExact, .monteCarloChiSquare, .cohenKappa, .alphaNominal,
            .alphaNumeric, .fleissKappa, .alphaInterval, .bootstrapBCa, .plannedContrasts:
            throw statisticsWorkbenchFailure("invalid-operation")
        }
    }

    func countTable() throws -> [[Int]] {
        let numeric = try groups
        guard let width = numeric.first?.count, (2...64).contains(width),
            numeric.allSatisfy({ $0.count == width })
        else { throw statisticsWorkbenchFailure("invalid-count-table") }
        var total = 0
        return try numeric.map { row in
            try row.map { value in
                guard value >= 0, value <= 1_000_000, value.rounded(.towardZero) == value else {
                    throw statisticsWorkbenchFailure("invalid-count")
                }
                let count = Int(value)
                guard count <= 1_000_000 - total else {
                    throw statisticsWorkbenchFailure(
                        "count-limit", category: "insufficientResources")
                }
                total += count
                return count
            }
        }
    }
}

private func statisticsWorkbenchFailure(_ code: String, category: String = "invalidInput")
    -> GlifiStudioFailure
{
    GlifiStudioFailure(
        code: "statistics.workbench.\(code)", category: category, operation: "analyze",
        retryDisposition: category == "cancelled" ? "newRequest" : "afterCorrection",
        retainedState: "unchanged", messageKey: "failure.category.\(category)")
}
