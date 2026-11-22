// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// One caller-ordered document of explicit lexical keys.
public struct GlifiStudioLexicalSequence: Equatable, Sendable {
    /// Stable document or source revision identity.
    public let id: String
    /// Keys after the caller's declared preprocessing.
    public let tokens: [String]

    /// Preserves identity, keys and their order.
    public init(id: String, tokens: [String]) {
        self.id = id
        self.tokens = tokens
    }
}

/// Application-facing observed lexical distributions.
public struct GlifiStudioLexicalDistribution: Encodable, Equatable, Sendable {
    private let value: GlifiLexicalDistribution
    /// Observation contract identifier.
    public var methodIdentifier: String { value.methodIdentifier }
    /// Explicit preprocessing contract.
    public var preprocessingIdentifier: String { value.preprocessingIdentifier }
    /// Document concatenation order.
    public var documentIDs: [String] { value.documentIDs }
    /// Number of included tokens.
    public var tokenCount: Int { value.tokenCount }
    /// Number of distinct lexical keys.
    public var typeCount: Int { value.typeCount }
    /// Canonical rank order, descending by count and ascending by key.
    public var terms: [String] { value.rankFrequency.map(\.term) }
    /// Absolute frequencies in rank order.
    public var counts: [Int] { value.rankFrequency.map(\.count) }
    /// Relative frequencies over all included tokens.
    public var relativeFrequencies: [Double] { value.rankFrequency.map(\.relativeFrequency) }
    /// Increasing observed frequencies in the spectrum.
    public var spectrumFrequencies: [Int] { value.spectrum.map(\.frequency) }
    /// Type counts for each spectrum frequency.
    public var spectrumTypeCounts: [Int] { value.spectrum.map(\.typeCount) }
    /// Caller-selected token prefixes.
    public var checkpoints: [Int] { value.growth.map(\.tokenCount) }
    /// Observed vocabulary sizes at the checkpoints.
    public var vocabularySizes: [Int] { value.growth.map(\.typeCount) }

    init(_ value: GlifiLexicalDistribution) { self.value = value }

    /// Serializes the complete observations and document lineage.
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }

    fileprivate var core: GlifiLexicalDistribution { value }
}

/// Application-facing log-space OLS diagnostics.
public struct GlifiStudioLogPowerFit: Encodable, Equatable, Sendable {
    private let value: GlifiLogPowerFit
    /// ZipfLogOLS-v1 or HeapsLogOLS-v1.
    public var methodIdentifier: String { value.methodIdentifier }
    /// Positive C or K.
    public var coefficient: Double { value.coefficient }
    /// Alpha for Zipf, beta for Heaps.
    public var exponent: Double { value.exponent }
    /// Explained log-space variance, undefined for constant responses.
    public var logRSquared: Double? { value.logRSquared }
    /// Root mean squared log residual.
    public var logRMSE: Double { value.logRMSE }
    /// Observed ranks or token prefixes, with no extrapolation.
    public var x: [Int] { value.points.map(\.x) }
    /// Observed counts at the fitted points.
    public var observed: [Int] { value.points.map(\.observed) }
    /// Fitted counts at the observed support.
    public var predicted: [Double] { value.points.map(\.predicted) }
    /// Observed minus predicted log counts.
    public var logResiduals: [Double] { value.points.map(\.logResidual) }

    init(_ value: GlifiLogPowerFit) { self.value = value }

    /// Serializes the complete diagnostic fit.
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Application-facing choice of variance denominator.
public enum GlifiStudioVarianceConvention: String, Sendable {
    /// Denominator n.
    case population
    /// Denominator n-1, undefined for n < 2.
    case sample

    var core: GlifiVarianceConvention {
        switch self {
        case .population: .population
        case .sample: .sample
        }
    }
}

/// Application-facing exact descriptive statistics and Q7 quantiles.
public struct GlifiStudioDescriptiveSummary: Encodable, Equatable, Sendable {
    private let value: GlifiDescriptiveSummary
    /// Explicit unit shared by the input observations.
    public var unitIdentifier: String { value.unitIdentifier }
    /// Number of finite observations.
    public var validCount: Int { value.validCount }
    /// Missing observations excluded from calculation.
    public var missingCount: Int { value.missingCount }
    /// Smallest valid observation.
    public var minimum: Double? { value.minimum }
    /// Largest valid observation.
    public var maximum: Double? { value.maximum }
    /// Arithmetic mean.
    public var mean: Double? { value.mean }
    /// Q7 median.
    public var median: Double? { value.median }
    /// Variance with the declared denominator.
    public var variance: Double? { value.variance }
    /// Square root of variance.
    public var standardDeviation: Double? { value.standardDeviation }
    /// Quantile probabilities in caller order.
    public var probabilities: [Double] { value.quantiles.map(\.probability) }
    /// Exact Q7 quantiles in caller order.
    public var quantiles: [Double?] { value.quantiles.map(\.value) }

    init(_ value: GlifiDescriptiveSummary) { self.value = value }

    /// Serializes units, missing policy, variance convention and all statistics.
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Bounded analytical primitives computed outside the caller's actor.
public enum GlifiStudioLexicalStatistics {
    /// Headless implementation awaiting a separate per-variant scientific promotion.
    public static let validationStatus = "candidate"

    /// Counts frequencies, spectrum and caller-selected vocabulary checkpoints.
    @concurrent public static func observe(
        _ documents: [GlifiStudioLexicalSequence], checkpoints: [Int],
        preprocessingIdentifier: String
    ) async throws(GlifiStudioFailure) -> GlifiStudioLexicalDistribution {
        try mapFailure {
            try GlifiStudioLexicalDistribution(
                GlifiLexicalDistributionAnalysis.observe(
                    documents.map { .init(id: $0.id, tokens: $0.tokens) },
                    checkpoints: checkpoints, preprocessingIdentifier: preprocessingIdentifier))
        }
    }

    /// Fits Zipf only over the explicit inclusive rank interval.
    @concurrent public static func fitZipf(
        _ distribution: GlifiStudioLexicalDistribution, ranks: ClosedRange<Int>
    ) async throws(GlifiStudioFailure) -> GlifiStudioLogPowerFit {
        try mapFailure {
            try GlifiStudioLogPowerFit(
                GlifiLexicalDistributionAnalysis.fitZipf(
                    distribution.core, ranks: ranks))
        }
    }

    /// Fits Heaps on exactly the observed growth checkpoints.
    @concurrent public static func fitHeaps(
        _ distribution: GlifiStudioLexicalDistribution
    ) async throws(GlifiStudioFailure) -> GlifiStudioLogPowerFit {
        try mapFailure {
            try GlifiStudioLogPowerFit(
                GlifiLexicalDistributionAnalysis.fitHeaps(
                    distribution.core.growth))
        }
    }

    /// Summarizes one explicit unit, counting and excluding missing values.
    @concurrent public static func summarize(
        _ observations: [Double?], unitIdentifier: String,
        variance: GlifiStudioVarianceConvention, probabilities: [Double] = [0.25, 0.5, 0.75]
    ) async throws(GlifiStudioFailure) -> GlifiStudioDescriptiveSummary {
        try mapFailure {
            try GlifiStudioDescriptiveSummary(
                GlifiDescriptiveStatistics.summarize(
                    observations, unitIdentifier: unitIdentifier, variance: variance.core,
                    probabilities: probabilities))
        }
    }

    private static func mapFailure<Value>(_ body: () throws -> Value) throws(GlifiStudioFailure)
        -> Value
    {
        do {
            return try body()
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch is CancellationError {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        } catch {
            throw GlifiStudioFailure(
                code: "analysis.invariant-violation", category: "invariantViolation",
                operation: "analyze",
                retryDisposition: "never", retainedState: "validityUnknown",
                messageKey: "failure.category.invariantViolation")
        }
    }
}
