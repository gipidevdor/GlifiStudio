// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// One rank-frequency row: rank, type and occurrences.
public struct GlifiStudioRankFrequencyRow: Codable, Equatable, Sendable {
    /// Ordinal rank, 1 for the most frequent type.
    public let rank: Int
    /// Normalized type.
    public let type: String
    /// Occurrences.
    public let count: Int
}

/// `typeCount` types occur exactly `frequency` times.
public struct GlifiStudioFrequencySpectrumRow: Codable, Equatable, Sendable {
    /// Occurrence count `k`.
    public let frequency: Int
    /// Types `V_k`.
    public let typeCount: Int
}

/// Distinct types after the first `tokenCount` tokens.
public struct GlifiStudioVocabularyGrowthPoint: Codable, Equatable, Sendable {
    /// Tokens read `n`.
    public let tokenCount: Int
    /// Types `V(n)`.
    public let typeCount: Int
}

/// Ordinary least squares in log-log space.
public struct GlifiStudioLogLinearFit: Codable, Equatable, Sendable {
    /// Points used.
    public let pointCount: Int
    /// Smallest predictor on the original scale.
    public let firstPredictor: Int
    /// Largest predictor on the original scale.
    public let lastPredictor: Int
    /// `β₀`.
    public let intercept: Double
    /// `β₁`.
    public let slope: Double
    /// `C` (Zipf) or `K` (Heaps).
    public let coefficient: Double
    /// `α` (Zipf) or `β` (Heaps).
    public let exponent: Double
    /// `R²` in log space, absent without response variance.
    public let rSquared: Double?
    /// RMSE in log space.
    public let rootMeanSquaredLogError: Double
    /// Log-space residuals in predictor order.
    public let residuals: [Double]
    /// Whether the exponent lies in the model domain.
    public let isExponentInModelDomain: Bool

    init(_ fit: GlifiLogLinearFit) {
        pointCount = fit.pointCount
        firstPredictor = fit.firstPredictor
        lastPredictor = fit.lastPredictor
        intercept = fit.intercept
        slope = fit.slope
        coefficient = fit.coefficient
        exponent = fit.exponent
        rSquared = fit.rSquared
        rootMeanSquaredLogError = fit.rootMeanSquaredLogError
        residuals = fit.residuals
        isExponentInModelDomain = fit.isExponentInModelDomain
    }
}

/// A versioned fit or the reason it is not defined.
public struct GlifiStudioLexicalLawFit: Codable, Equatable, Sendable {
    /// Procedure identity.
    public let methodIdentifier: String
    /// The fit, absent with fewer than two points.
    public let fit: GlifiStudioLogLinearFit?
    /// Stable reason when `fit` is absent.
    public let unavailableReason: String?

    init(_ value: GlifiLexicalLawFit) {
        methodIdentifier = value.methodIdentifier
        fit = value.fit.map(GlifiStudioLogLinearFit.init)
        unavailableReason = value.unavailableReason
    }
}

/// Declared parameters of `corpus-lexical-laws-v1`.
public struct GlifiStudioLexicalLawsParameters: Codable, Equatable, Sendable {
    /// Growth checkpoints `K`.
    public let checkpointCount: Int
    /// First rank of the Zipf fit.
    public let zipfFirstRank: Int
    /// Last rank of the Zipf fit, absent for the last observed rank.
    public let zipfLastRank: Int?
    /// Maximum persisted rank-frequency rows.
    public let rankRowLimit: Int

    /// Defaults of GS-MET-001-05.
    public static let standard = GlifiStudioLexicalLawsParameters(
        checkpointCount: 20, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 1_000)

    /// Creates parameters; validation happens when the analysis runs.
    public init(checkpointCount: Int, zipfFirstRank: Int, zipfLastRank: Int?, rankRowLimit: Int) {
        self.checkpointCount = checkpointCount
        self.zipfFirstRank = zipfFirstRank
        self.zipfLastRank = zipfLastRank
        self.rankRowLimit = rankRowLimit
    }

    init(_ value: GlifiLexicalLawsParameters) {
        self.init(
            checkpointCount: value.checkpointCount, zipfFirstRank: value.zipfFirstRank,
            zipfLastRank: value.zipfLastRank, rankRowLimit: value.rankRowLimit)
    }

    var coreValue: GlifiLexicalLawsParameters {
        GlifiLexicalLawsParameters(
            checkpointCount: checkpointCount, zipfFirstRank: zipfFirstRank,
            zipfLastRank: zipfLastRank, rankRowLimit: rankRowLimit)
    }
}

/// Presentation-independent observations and fits of `corpus-lexical-laws-v1`.
public struct GlifiStudioLexicalLawsResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Token-to-type mapping.
    public let typeMappingIdentifier: String
    /// Order of the pooled sequence.
    public let sequencePolicy: String
    /// Checkpoint policy of the growth curve.
    public let checkpointPolicy: String
    /// Declared parameters.
    public let parameters: GlifiStudioLexicalLawsParameters
    /// Analyzed documents in canonical order.
    public let sourceRevisionIDs: [String]
    /// Tokens `N`.
    public let tokenCount: Int
    /// Types `V`.
    public let typeCount: Int
    /// Persisted rank-frequency rows.
    public let rankFrequency: [GlifiStudioRankFrequencyRow]
    /// Whether rows beyond the limit were not persisted.
    public let isRankFrequencyTruncated: Bool
    /// Frequency spectrum.
    public let spectrum: [GlifiStudioFrequencySpectrumRow]
    /// Vocabulary growth at the checkpoints.
    public let growth: [GlifiStudioVocabularyGrowthPoint]
    /// `ZipfLogOLS-v1`.
    public let zipf: GlifiStudioLexicalLawFit
    /// `HeapsLogOLS-v1`.
    public let heaps: GlifiStudioLexicalLawFit
    /// Caveat: fits describe the observed interval, not a law or a mechanism.
    public let fitCaveat: String

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusLexicalLawsAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        typeMappingIdentifier = value.typeMappingIdentifier
        sequencePolicy = value.sequencePolicy
        checkpointPolicy = value.checkpointPolicy
        parameters = GlifiStudioLexicalLawsParameters(value.parameters)
        sourceRevisionIDs = value.sourceRevisionIDs
        tokenCount = value.tokenCount
        typeCount = value.typeCount
        rankFrequency = value.rankFrequency.map {
            GlifiStudioRankFrequencyRow(rank: $0.rank, type: $0.type, count: $0.count)
        }
        isRankFrequencyTruncated = value.isRankFrequencyTruncated
        spectrum = value.spectrum.map {
            GlifiStudioFrequencySpectrumRow(frequency: $0.frequency, typeCount: $0.typeCount)
        }
        growth = value.growth.map {
            GlifiStudioVocabularyGrowthPoint(tokenCount: $0.tokenCount, typeCount: $0.typeCount)
        }
        zipf = GlifiStudioLexicalLawFit(value.zipf)
        heaps = GlifiStudioLexicalLawFit(value.heaps)
        fitCaveat = value.fitCaveat
    }
}
