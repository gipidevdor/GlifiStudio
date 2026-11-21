// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One immutable, already preprocessed sequence of lexical keys.
public struct GlifiLexicalSequence: Codable, Equatable, Sendable {
    /// Stable caller-supplied document identity.
    public let id: String
    /// Ordered keys after the declared preprocessing.
    public let tokens: [String]

    /// Order and keys are preserved; no implicit normalization is applied.
    public init(id: String, tokens: [String]) {
        self.id = id
        self.tokens = tokens
    }
}

/// An observed term frequency with canonical tie-breaking by lexical key.
public struct GlifiRankFrequency: Codable, Equatable, Sendable {
    /// Observed lexical key.
    public let term: String
    /// One-based rank in canonical frequency order.
    public let rank: Int
    /// Absolute observed frequency.
    public let count: Int
    /// Frequency divided by the total included tokens.
    public let relativeFrequency: Double
}

/// Number of types observed exactly `frequency` times.
public struct GlifiFrequencySpectrumPoint: Codable, Equatable, Sendable {
    /// Observed absolute frequency.
    public let frequency: Int
    /// Number of distinct observed keys.
    public let typeCount: Int
}

/// Observed vocabulary after a declared prefix of the concatenated sequences.
public struct GlifiVocabularyGrowthPoint: Codable, Equatable, Sendable {
    /// Number of observed tokens.
    public let tokenCount: Int
    /// Number of distinct observed keys.
    public let typeCount: Int

    /// Creates one explicit observation.
    public init(tokenCount: Int, typeCount: Int) {
        self.tokenCount = tokenCount
        self.typeCount = typeCount
    }
}

/// Counts, spectrum and growth are observations, separate from fitted models.
public struct GlifiLexicalDistribution: Codable, Equatable, Sendable {
    /// Versioned analytical contract.
    public let methodIdentifier: String
    /// Caller-declared preprocessing contract.
    public let preprocessingIdentifier: String
    /// Document concatenation order, including empty documents.
    public let documentIDs: [String]
    /// Token counts in document order.
    public let documentTokenCounts: [Int]
    /// Number of observed tokens.
    public let tokenCount: Int
    /// Number of distinct observed keys.
    public let typeCount: Int
    /// Observed frequencies in canonical rank order.
    public let rankFrequency: [GlifiRankFrequency]
    /// Type counts by increasing absolute frequency.
    public let spectrum: [GlifiFrequencySpectrumPoint]
    /// Observed vocabulary at the requested prefixes.
    public let growth: [GlifiVocabularyGrowthPoint]
}

/// A fitted point retains observed, predicted and log-residual values.
public struct GlifiLogPowerFitPoint: Codable, Equatable, Sendable {
    /// Observed rank or token prefix.
    public let x: Int
    /// Observed count at this point.
    public let observed: Int
    /// Model prediction at the observed support.
    public let predicted: Double
    /// Observed minus fitted log count.
    public let logResidual: Double
}

/// Diagnostic log-space OLS; this does not establish a power law or causality.
public struct GlifiLogPowerFit: Codable, Equatable, Sendable {
    /// Versioned analytical contract.
    public let methodIdentifier: String
    /// Positive multiplicative coefficient C or K.
    public let coefficient: Double
    /// Alpha for Zipf; beta for Heaps.
    public let exponent: Double
    /// Explained log-space variance; nil for constant responses.
    public let logRSquared: Double?
    /// Root mean squared log residual, with denominator n.
    public let logRMSE: Double
    /// Observed support, predictions and log residuals.
    public let points: [GlifiLogPowerFitPoint]
    /// Extrapolation and uncertainty estimation are not part of these variants.
    public let diagnosticOnly: Bool
}

/// Incremental observed counts and the fully specified GS-MET-001-05 fits.
public enum GlifiLexicalDistributionAnalysis {
    /// Maximum included tokens and growth checkpoints.
    public static let maximumTokenCount = 1_000_000
    /// Maximum document identities.
    public static let maximumDocumentCount = 100_000
    /// Aggregate budget for identities, preprocessing and lexical keys.
    public static let maximumInputBytes = 64 * 1_024 * 1_024

    /// Checkpoints must be strictly increasing positive prefixes within the input.
    ///
    /// Document order, including empty documents, is retained in the result.
    public static func observe(
        _ documents: [GlifiLexicalSequence],
        checkpoints: [Int],
        preprocessingIdentifier: String
    ) throws -> GlifiLexicalDistribution {
        try Task.checkCancellation()
        guard documents.count <= maximumDocumentCount, checkpoints.count <= maximumTokenCount else {
            throw failure("lexical-distribution.input-limit", category: .insufficientResources)
        }
        guard preprocessingIdentifier.utf8.count <= maximumInputBytes else {
            throw failure("lexical-distribution.input-limit", category: .insufficientResources)
        }
        guard !preprocessingIdentifier.isEmpty,
            Set(documents.map(\.id)).count == documents.count,
            documents.allSatisfy({ !$0.id.isEmpty })
        else {
            throw failure("lexical-distribution.invalid-identity")
        }
        var tokenCount = 0
        var byteCount = preprocessingIdentifier.utf8.count
        var counts: [String: Int] = [:]
        var growth: [GlifiVocabularyGrowthPoint] = []
        growth.reserveCapacity(min(checkpoints.count, 4_096))
        var position = 0
        var checkpointIndex = 0
        for document in documents {
            try Task.checkCancellation()
            guard document.tokens.count <= maximumTokenCount - tokenCount,
                document.id.utf8.count <= maximumInputBytes - min(byteCount, maximumInputBytes)
            else {
                throw failure("lexical-distribution.input-limit", category: .insufficientResources)
            }
            tokenCount += document.tokens.count
            byteCount += document.id.utf8.count
            for (index, token) in document.tokens.enumerated() {
                if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
                guard !token.isEmpty else { throw failure("lexical-distribution.empty-key") }
                let tokenBytes = token.utf8.count
                guard tokenBytes <= maximumInputBytes - min(byteCount, maximumInputBytes)
                else {
                    throw failure(
                        "lexical-distribution.input-limit", category: .insufficientResources)
                }
                byteCount += tokenBytes
                counts[token, default: 0] += 1
                position += 1
                if checkpointIndex < checkpoints.count, position == checkpoints[checkpointIndex] {
                    growth.append(.init(tokenCount: position, typeCount: counts.count))
                    checkpointIndex += 1
                }
            }
        }
        var previous = 0
        for checkpoint in checkpoints {
            guard checkpoint > previous, checkpoint <= tokenCount else {
                throw failure("lexical-distribution.invalid-checkpoints")
            }
            previous = checkpoint
        }
        var spectrum: [Int: Int] = [:]
        for count in counts.values { spectrum[count, default: 0] += 1 }
        let ordered = counts.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }
        return GlifiLexicalDistribution(
            methodIdentifier: "LexicalDistribution-ordered-v1",
            preprocessingIdentifier: preprocessingIdentifier,
            documentIDs: documents.map(\.id),
            documentTokenCounts: documents.map { $0.tokens.count },
            tokenCount: tokenCount,
            typeCount: counts.count,
            rankFrequency: ordered.enumerated().map {
                GlifiRankFrequency(
                    term: $0.element.key, rank: $0.offset + 1, count: $0.element.value,
                    relativeFrequency: Double($0.element.value) / Double(tokenCount))
            },
            spectrum: spectrum.keys.sorted().map {
                GlifiFrequencySpectrumPoint(frequency: $0, typeCount: spectrum[$0] ?? 0)
            },
            growth: growth
        )
    }

    /// Fits positive rank frequencies over an explicit inclusive rank interval.
    ///
    /// Flat or increasing fits do not meet the Zipf family domain alpha > 0.
    public static func fitZipf(
        _ distribution: GlifiLexicalDistribution,
        ranks: ClosedRange<Int>
    ) throws -> GlifiLogPowerFit {
        guard distribution.rankFrequency.count <= maximumTokenCount else {
            throw failure("lexical-distribution.input-limit", category: .insufficientResources)
        }
        guard ranks.lowerBound > 0, ranks.upperBound <= distribution.rankFrequency.count else {
            throw failure("lexical-distribution.invalid-rank-interval")
        }
        let selected = distribution.rankFrequency[(ranks.lowerBound - 1)..<ranks.upperBound]
        guard
            selected.enumerated().allSatisfy({
                $0.element.rank == ranks.lowerBound + $0.offset && $0.element.count > 0
            })
        else {
            throw failure("lexical-distribution.invalid-observations")
        }
        return try fit(
            selected.map { ($0.rank, $0.count) }, identifier: "ZipfLogOLS-v1", isZipf: true)
    }

    /// Fits exactly the supplied checkpoints, without thinning or extrapolation.
    public static func fitHeaps(_ checkpoints: [GlifiVocabularyGrowthPoint]) throws
        -> GlifiLogPowerFit
    {
        guard checkpoints.count <= maximumTokenCount else {
            throw failure("lexical-distribution.input-limit", category: .insufficientResources)
        }
        var previousTokens = 0
        var previousTypes = 0
        for point in checkpoints {
            guard point.tokenCount > previousTokens, point.typeCount > 0,
                point.typeCount >= previousTypes, point.typeCount <= point.tokenCount,
                point.typeCount - previousTypes <= point.tokenCount - previousTokens
            else { throw failure("lexical-distribution.invalid-growth") }
            previousTokens = point.tokenCount
            previousTypes = point.typeCount
        }
        return try fit(
            checkpoints.map { ($0.tokenCount, $0.typeCount) },
            identifier: "HeapsLogOLS-v1", isZipf: false)
    }

    private static func fit(
        _ observations: [(Int, Int)], identifier: String, isZipf: Bool
    ) throws -> GlifiLogPowerFit {
        try Task.checkCancellation()
        guard observations.count >= 2 else {
            throw failure(
                "lexical-distribution.insufficient-fit-points", category: .insufficientData)
        }
        // Relative logs center proportional growth identically in both axes,
        // including the exact Heaps beta=1 boundary, without clipping a fit.
        let originX = Double(observations[0].0)
        let originY = Double(observations[0].1)
        let logOriginY = log(originY)
        let x = observations.map { log(Double($0.0) / originX) }
        let y = observations.map { log(Double($0.1) / originY) }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        var sxx = 0.0
        var sxy = 0.0
        var syy = 0.0
        for index in x.indices {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            sxx += (x[index] - meanX) * (x[index] - meanX)
            sxy += (x[index] - meanX) * (y[index] - meanY)
            syy += (y[index] - meanY) * (y[index] - meanY)
        }
        guard sxx > 0 else {
            throw failure("lexical-distribution.singular-fit", category: .insufficientData)
        }
        let slope = sxy / sxx
        let intercept = meanY - slope * meanX
        let coefficient = exp(logOriginY + intercept - slope * log(originX))
        let exponent = isZipf ? -slope : slope
        guard coefficient.isFinite, coefficient > 0, exponent.isFinite else {
            throw failure("lexical-distribution.non-finite-fit")
        }
        guard exponent > 0, isZipf || exponent <= 1 else {
            throw failure(
                "lexical-distribution.fit-outside-model-domain", category: .insufficientData)
        }
        var squaredError = 0.0
        var points: [GlifiLogPowerFitPoint] = []
        points.reserveCapacity(observations.count)
        for index in observations.indices {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let fittedLog = intercept + slope * x[index]
            let residual = y[index] - fittedLog
            let predicted = exp(logOriginY + fittedLog)
            guard predicted.isFinite, predicted > 0 else {
                throw failure("lexical-distribution.non-finite-fit")
            }
            squaredError += residual * residual
            points.append(
                .init(
                    x: observations[index].0, observed: observations[index].1,
                    predicted: predicted, logResidual: residual))
        }
        return GlifiLogPowerFit(
            methodIdentifier: identifier, coefficient: coefficient, exponent: exponent,
            logRSquared: syy > 0 ? 1 - squaredError / syy : nil,
            logRMSE: sqrt(squaredError / Double(x.count)), points: points, diagnosticOnly: true)
    }

    private static func failure(
        _ code: String, category: GlifiFailureCategory = .invalidInput
    ) -> GlifiFailure {
        GlifiFailure(
            code: code, category: category, operation: .analyze,
            retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
            retainedState: .unchanged,
            messageKey: "failure.\(code)")
    }
}
