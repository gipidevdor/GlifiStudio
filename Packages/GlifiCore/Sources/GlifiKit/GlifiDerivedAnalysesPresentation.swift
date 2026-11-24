// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Project and generation lineage shared by every derived analysis result.
public struct GlifiStudioDerivedLineage: Codable, Equatable, Sendable {
    /// Stable project identity.
    public let projectID: String
    /// Exact source generation captured before the analysis.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the Artifact.
    public let generation: Int
    /// Immutable persisted Artifact identity.
    public let artifactID: String
    /// Semantic producer identity.
    public let analysisNodeID: String

    init<Value: GlifiDerivedAnalysisResult>(_ result: GlifiProjectDerivedResult<Value>) {
        projectID = result.projectID.canonicalValue
        sourceGeneration = result.sourceGeneration
        generation = result.generation
        artifactID = result.artifactID.canonicalValue
        analysisNodeID = result.analysisNodeID.canonicalValue
    }
}

// MARK: - Association

/// One cell with a large standardized residual.
public struct GlifiStudioAssociationResidual: Codable, Equatable, Sendable {
    /// Normalized lexical form.
    public let term: String
    /// Document that owns the cell.
    public let sourceRevisionID: String
    /// Observed count.
    public let observed: Int
    /// Count expected under independence.
    public let expected: Double
    /// Standardized residual.
    public let standardizedResidual: Double

    init(_ value: GlifiCorpusAssociationResidual) {
        term = value.term
        sourceRevisionID = value.sourceRevisionID
        observed = value.observed
        expected = value.expected
        standardizedResidual = value.standardizedResidual
    }
}

/// Presentation-independent document × term association.
public struct GlifiStudioAssociationResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Independence-test method identity.
    public let chiSquareIdentifier: String
    /// Effect-size method identity.
    public let cramersVIdentifier: String
    /// Total lexical tokens in the table.
    public let totalObservations: Int
    /// Documents with at least one token.
    public let includedDocumentCount: Int
    /// Distinct terms in the table.
    public let includedTermCount: Int
    /// Documents excluded for a zero margin.
    public let excludedSourceRevisionIDs: [String]
    /// Pearson `χ²`.
    public let chiSquareStatistic: Double
    /// Degrees of freedom.
    public let degreesOfFreedom: Int
    /// Asymptotic p-value.
    public let pValue: Double
    /// Cramér's V.
    public let cramersV: Double
    /// Share of cells whose expected count is below five.
    public let lowExpectedCellFraction: Double
    /// Largest number of residual rows stored.
    public let residualLimit: Int
    /// Cells with the largest absolute standardized residual.
    public let topResiduals: [GlifiStudioAssociationResidual]

    /// Fixed-margin Monte Carlo p-value of χ².
    public let monteCarloPValue: Double?
    /// Simulated tables.
    public let monteCarloSimulationCount: Int
    /// Recorded seed.
    public let monteCarloSeed: UInt64
    /// Reason code when the Monte Carlo p-value is unavailable.
    public let monteCarloUnavailableReason: String?
    /// Fisher exact p-value when the included table is 2×2.
    public let fisherPValue: Double?

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusAssociationAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        corpusDigest = value.corpusDigest
        sourceRevisionIDs = value.sourceRevisionIDs
        chiSquareIdentifier = value.chiSquareIdentifier
        cramersVIdentifier = value.cramersVIdentifier
        totalObservations = value.totalObservations
        includedDocumentCount = value.includedDocumentCount
        includedTermCount = value.includedTermCount
        excludedSourceRevisionIDs = value.excludedSourceRevisionIDs
        chiSquareStatistic = value.chiSquareStatistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        cramersV = value.cramersV
        lowExpectedCellFraction = value.lowExpectedCellFraction
        residualLimit = value.residualLimit
        topResiduals = value.topResiduals.map(GlifiStudioAssociationResidual.init)
        monteCarloPValue = value.monteCarloPValue
        monteCarloSimulationCount = value.monteCarloSimulationCount
        monteCarloSeed = value.monteCarloSeed
        monteCarloUnavailableReason = value.monteCarloUnavailableReason
        fisherPValue = value.fisherPValue
    }
}

// MARK: - Dispersion

/// Dispersion measures of one term.
public struct GlifiStudioDispersionTerm: Codable, Equatable, Identifiable, Sendable {
    /// Stable row identity derived from the normalized term.
    public var id: String { term }
    /// Normalized lexical form.
    public let term: String
    /// Total occurrences.
    public let frequency: Int
    /// Documents that contain the term.
    public let documentFrequency: Int
    /// `GriesDP-v1`.
    public let griesDP: Double
    /// `GriesDPnorm-v1`.
    public let griesDPNorm: Double?
    /// `JuillandD-equal-v1`.
    public let juillandD: Double?

    init(_ value: GlifiCorpusDispersionRow) {
        term = value.term
        frequency = value.frequency
        documentFrequency = value.documentFrequency
        griesDP = value.griesDP
        griesDPNorm = value.griesDPNorm
        juillandD = value.juillandD
    }
}

/// Presentation-independent per-term dispersion.
public struct GlifiStudioDispersionResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered partition units.
    public let sourceRevisionIDs: [String]
    /// `GriesDP-v1` identity.
    public let griesDPIdentifier: String
    /// `GriesDPnorm-v1` identity.
    public let griesDPNormIdentifier: String
    /// `JuillandD-equal-v1` identity.
    public let juillandDIdentifier: String
    /// Lexical-token count of each unit.
    public let unitSizes: [Int]
    /// Whether all units have the same size.
    public let equalSizePartition: Bool
    /// Complete term rows.
    public let terms: [GlifiStudioDispersionTerm]

    /// Partition rule.
    public let partitionIdentifier: String
    /// Documents of each part.
    public let parts: [[String]]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusDispersionAnalysis>) {
        let value = result.value
        partitionIdentifier = value.partitionIdentifier
        parts = value.parts
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        corpusDigest = value.corpusDigest
        sourceRevisionIDs = value.sourceRevisionIDs
        griesDPIdentifier = value.griesDPIdentifier
        griesDPNormIdentifier = value.griesDPNormIdentifier
        juillandDIdentifier = value.juillandDIdentifier
        unitSizes = value.unitSizes
        equalSizePartition = value.equalSizePartition
        terms = value.terms.map(GlifiStudioDispersionTerm.init)
    }
}

// MARK: - Group metric comparison

/// Document metric compared across groups.
public enum GlifiStudioDocumentMetric: Equatable, Sendable {
    /// Lexical-token count of each document.
    case lexicalTokenCount
    /// Relative frequency of one normalized term in each document.
    case termRelativeFrequency(String)

    var coreValue: GlifiDocumentMetric {
        switch self {
        case .lexicalTokenCount: .lexicalTokenCount
        case let .termRelativeFrequency(term): .termRelativeFrequency(term)
        }
    }
}

/// Summary of one compared group.
public struct GlifiStudioGroupMetricSummary: Codable, Equatable, Sendable {
    /// Canonically ordered documents of the group.
    public let sourceRevisionIDs: [String]
    /// Documents contributing one value each.
    public let documentCount: Int
    /// Arithmetic mean.
    public let mean: Double
    /// Unbiased sample variance.
    public let variance: Double?
    /// Lower bootstrap bound of the mean.
    public let bootstrapLower: Double?
    /// Upper bootstrap bound of the mean.
    public let bootstrapUpper: Double?
    /// Lower BCa bound of the mean.
    public let bcaLower: Double?
    /// Upper BCa bound of the mean.
    public let bcaUpper: Double?

    init(_ value: GlifiGroupMetricSummary) {
        sourceRevisionIDs = value.sourceRevisionIDs
        documentCount = value.documentCount
        mean = value.mean
        variance = value.variance
        bootstrapLower = value.bootstrapLower
        bootstrapUpper = value.bootstrapUpper
        bcaLower = value.bcaLower
        bcaUpper = value.bcaUpper
    }
}

/// `PermutationMeanDifference-v1` values.
public struct GlifiStudioGroupPermutation: Codable, Equatable, Sendable {
    /// `exact` or `monte-carlo`.
    public let strategyIdentifier: String
    /// Observed difference of means.
    public let observedDifference: Double
    /// Relabelings evaluated.
    public let evaluatedCount: Int
    /// Relabelings at least as extreme as the observed one.
    public let extremeCount: Int
    /// Two-sided p-value.
    public let pValue: Double

    init(_ value: GlifiGroupPermutation) {
        strategyIdentifier = value.strategyIdentifier
        observedDifference = value.observedDifference
        evaluatedCount = value.evaluatedCount
        extremeCount = value.extremeCount
        pValue = value.pValue
    }
}

/// `OneWayANOVA-v1` values.
public struct GlifiStudioGroupANOVA: Codable, Equatable, Sendable {
    /// `F` statistic.
    public let fStatistic: Double
    /// `k-1`.
    public let numeratorDegreesOfFreedom: Int
    /// `N-k`.
    public let denominatorDegreesOfFreedom: Int
    /// Asymptotic p-value.
    public let pValue: Double

    init(_ value: GlifiGroupANOVA) {
        fStatistic = value.fStatistic
        numeratorDegreesOfFreedom = value.numeratorDegreesOfFreedom
        denominatorDegreesOfFreedom = value.denominatorDegreesOfFreedom
        pValue = value.pValue
    }
}

/// `WelchT-v1` values.
public struct GlifiStudioGroupWelch: Codable, Equatable, Sendable {
    /// `t` statistic.
    public let statistic: Double
    /// Welch–Satterthwaite degrees of freedom.
    public let degreesOfFreedom: Double
    /// Two-sided asymptotic p-value.
    public let pValue: Double

    init(_ value: GlifiGroupWelch) {
        statistic = value.statistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
    }
}

/// `MannWhitneyU-v1` values.
public struct GlifiStudioGroupMannWhitney: Codable, Equatable, Sendable {
    /// `exact` or `asymptotic-tie-corrected-continuity`.
    public let methodIdentifier: String
    /// `U₁` of the first group.
    public let u1: Double
    /// `U₂` of the second group.
    public let u2: Double
    /// Standard-normal statistic, `nil` for the exact method.
    public let zStatistic: Double?
    /// Two-sided p-value.
    public let pValue: Double

    init(_ value: GlifiGroupMannWhitney) {
        methodIdentifier = value.methodIdentifier
        u1 = value.u1
        u2 = value.u2
        zStatistic = value.zStatistic
        pValue = value.pValue
    }
}

/// `KruskalWallis-v1` values.
public struct GlifiStudioGroupKruskalWallis: Codable, Equatable, Sendable {
    /// `H` before tie correction.
    public let hStatistic: Double
    /// Tie-correction factor.
    public let tieCorrection: Double
    /// `H/C`.
    public let correctedHStatistic: Double
    /// `k-1`.
    public let degreesOfFreedom: Int
    /// Upper-tail asymptotic chi-square p-value.
    public let pValue: Double

    /// `ε² = (H/C)/(N-1)`.
    public let epsilonSquared: Double

    init(_ value: GlifiGroupKruskalWallis) {
        hStatistic = value.hStatistic
        tieCorrection = value.tieCorrection
        correctedHStatistic = value.correctedHStatistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        epsilonSquared = value.epsilonSquared
    }
}

/// Public request-level parameters of a group comparison.
public struct GlifiStudioGroupComparisonOptions: Codable, Equatable, Sendable {
    /// Defaults shared by native and headless clients.
    public static let standard = GlifiStudioGroupComparisonOptions(.standard)

    let coreValue: GlifiGroupComparisonOptions

    /// Confidence level of every interval.
    public let confidenceLevel: Double
    /// Bootstrap resamples per group.
    public let bootstrapResampleCount: Int
    /// Monte Carlo relabelings beyond the exact bound.
    public let permutationMonteCarloCount: Int
    /// Seed of every resampling step.
    public let resamplingSeed: UInt64
    /// Declared family of planned contrasts.
    public let contrasts: [[Double]]

    /// Creates validated options without silently correcting parameters.
    public init(
        confidenceLevel: Double,
        bootstrapResampleCount: Int,
        permutationMonteCarloCount: Int,
        resamplingSeed: UInt64,
        contrasts: [[Double]]
    ) throws {
        do {
            self.init(
                try GlifiGroupComparisonOptions(
                    confidenceLevel: confidenceLevel,
                    bootstrapResampleCount: bootstrapResampleCount,
                    permutationMonteCarloCount: permutationMonteCarloCount,
                    resamplingSeed: resamplingSeed,
                    contrasts: contrasts
                )
            )
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        }
    }

    /// Decodes only valid options.
    public init(from decoder: any Decoder) throws {
        self.init(try GlifiGroupComparisonOptions(from: decoder))
    }

    /// Encodes the options.
    public func encode(to encoder: any Encoder) throws {
        try coreValue.encode(to: encoder)
    }

    fileprivate init(_ value: GlifiGroupComparisonOptions) {
        coreValue = value
        confidenceLevel = value.confidenceLevel
        bootstrapResampleCount = value.bootstrapResampleCount
        permutationMonteCarloCount = value.permutationMonteCarloCount
        resamplingSeed = value.resamplingSeed
        contrasts = value.contrasts
    }
}

/// One planned contrast.
public struct GlifiStudioContrast: Codable, Equatable, Sendable {
    /// Coefficients in group order.
    public let coefficients: [Double]
    /// `Σcᵢx̄ᵢ`.
    public let estimate: Double
    /// Standard error.
    public let standardError: Double
    /// t statistic.
    public let tStatistic: Double
    /// `N-k`.
    public let degreesOfFreedom: Int
    /// Raw two-sided p-value.
    public let pValue: Double
    /// Bonferroni-adjusted p-value.
    public let bonferroniPValue: Double
    /// Benjamini–Hochberg q-value.
    public let benjaminiHochbergPValue: Double
    /// Lower interval bound.
    public let lower: Double
    /// Upper interval bound.
    public let upper: Double

    init(_ value: GlifiContrastResult) {
        coefficients = value.coefficients
        estimate = value.estimate
        standardError = value.standardError
        tStatistic = value.tStatistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        bonferroniPValue = value.bonferroniPValue
        benjaminiHochbergPValue = value.benjaminiHochbergPValue
        lower = value.lower
        upper = value.upper
    }
}

/// Presentation-independent group metric comparison.
public struct GlifiStudioGroupMetricResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Metric definition identity.
    public let metricIdentifier: String
    /// Normalized term of a term-frequency metric.
    public let term: String?
    /// ANOVA method identity.
    public let anovaIdentifier: String
    /// Welch method identity.
    public let welchIdentifier: String
    /// Mann–Whitney method identity.
    public let mannWhitneyIdentifier: String
    /// Kruskal–Wallis method identity.
    public let kruskalWallisIdentifier: String
    /// Cohen's d method identity.
    public let cohenDIdentifier: String
    /// Permutation method identity.
    public let permutationIdentifier: String
    /// Bootstrap method identity.
    public let bootstrapIdentifier: String
    /// Generator identity.
    public let generatorIdentifier: String
    /// Recorded resampling seed.
    public let resamplingSeed: UInt64
    /// Bootstrap resamples per group.
    public let bootstrapResampleCount: Int
    /// Confidence level of the bootstrap intervals.
    public let bootstrapConfidenceLevel: Double
    /// Monte Carlo relabelings beyond the exact bound.
    public let permutationMonteCarloCount: Int
    /// Corpus-profile digest of each group.
    public let groupCorpusDigests: [String]
    /// Per-group summaries in request order.
    public let groups: [GlifiStudioGroupMetricSummary]
    /// ANOVA, `nil` when unavailable.
    public let anova: GlifiStudioGroupANOVA?
    /// Reason code when ANOVA is unavailable.
    public let anovaUnavailableReason: String?
    /// Welch t, `nil` when unavailable.
    public let welch: GlifiStudioGroupWelch?
    /// Reason code when Welch t is unavailable.
    public let welchUnavailableReason: String?
    /// Mann–Whitney U, `nil` when unavailable.
    public let mannWhitney: GlifiStudioGroupMannWhitney?
    /// Reason code when Mann–Whitney U is unavailable.
    public let mannWhitneyUnavailableReason: String?
    /// Kruskal–Wallis H, `nil` when unavailable.
    public let kruskalWallis: GlifiStudioGroupKruskalWallis?
    /// Reason code when Kruskal–Wallis H is unavailable.
    public let kruskalWallisUnavailableReason: String?
    /// `CohenD-pooled-v1`, `nil` when unavailable.
    public let cohenD: Double?
    /// Reason code when Cohen's d is unavailable.
    public let cohenDUnavailableReason: String?
    /// Permutation test, `nil` when unavailable.
    public let permutation: GlifiStudioGroupPermutation?
    /// Reason code when the permutation test is unavailable.
    public let permutationUnavailableReason: String?
    /// BCa method identity.
    public let bcaIdentifier: String
    /// Hedges method identity.
    public let hedgesIdentifier: String
    /// Rank-biserial method identity.
    public let rankBiserialIdentifier: String
    /// Planned-contrast method identity.
    public let contrastIdentifier: String
    /// Hedges' g and the interval of d.
    public let standardizedDifference: GlifiStudioStandardizedDifference?
    /// Rank-biserial correlation.
    public let rankBiserial: Double?
    /// Planned contrasts.
    public let contrasts: [GlifiStudioContrast]
    /// Reason code when the contrasts cannot be computed.
    public let contrastsUnavailableReason: String?

    init(_ result: GlifiProjectDerivedResult<GlifiGroupMetricComparison>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        metricIdentifier = value.metricIdentifier
        term = value.term
        anovaIdentifier = value.anovaIdentifier
        welchIdentifier = value.welchIdentifier
        mannWhitneyIdentifier = value.mannWhitneyIdentifier
        kruskalWallisIdentifier = value.kruskalWallisIdentifier
        cohenDIdentifier = value.cohenDIdentifier
        permutationIdentifier = value.permutationIdentifier
        bootstrapIdentifier = value.bootstrapIdentifier
        generatorIdentifier = value.generatorIdentifier
        resamplingSeed = value.resamplingSeed
        bootstrapResampleCount = value.bootstrapResampleCount
        bootstrapConfidenceLevel = value.bootstrapConfidenceLevel
        permutationMonteCarloCount = value.permutationMonteCarloCount
        groupCorpusDigests = value.groupCorpusDigests
        groups = value.groups.map(GlifiStudioGroupMetricSummary.init)
        anova = value.anova.map(GlifiStudioGroupANOVA.init)
        anovaUnavailableReason = value.anovaUnavailableReason
        welch = value.welch.map(GlifiStudioGroupWelch.init)
        welchUnavailableReason = value.welchUnavailableReason
        mannWhitney = value.mannWhitney.map(GlifiStudioGroupMannWhitney.init)
        mannWhitneyUnavailableReason = value.mannWhitneyUnavailableReason
        kruskalWallis = value.kruskalWallis.map(GlifiStudioGroupKruskalWallis.init)
        kruskalWallisUnavailableReason = value.kruskalWallisUnavailableReason
        cohenD = value.cohenD
        cohenDUnavailableReason = value.cohenDUnavailableReason
        permutation = value.permutation.map(GlifiStudioGroupPermutation.init)
        permutationUnavailableReason = value.permutationUnavailableReason
        bcaIdentifier = value.bcaIdentifier
        hedgesIdentifier = value.hedgesIdentifier
        rankBiserialIdentifier = value.rankBiserialIdentifier
        contrastIdentifier = value.contrastIdentifier
        standardizedDifference = value.standardizedDifference.map(
            GlifiStudioStandardizedDifference.init
        )
        rankBiserial = value.rankBiserial
        contrasts = value.contrasts.map(GlifiStudioContrast.init)
        contrastsUnavailableReason = value.contrastsUnavailableReason
    }
}

// MARK: - Co-occurrence options

/// Public bounded parameters of a document-level co-occurrence analysis.
public struct GlifiStudioCooccurrenceOptions: Codable, Equatable, Sendable {
    /// Conservative defaults shared by native and headless clients.
    public static let standard = GlifiStudioCooccurrenceOptions(.standard)

    let coreValue: GlifiCooccurrenceOptions

    /// Largest number of terms, chosen by document frequency.
    public let maximumTermCount: Int
    /// Smallest joint document count of a retained pair.
    public let minimumJointCount: Int
    /// Largest number of stored pairs.
    public let maximumPairCount: Int

    /// Creates valid bounds without silently correcting parameters.
    public init(
        maximumTermCount: Int,
        minimumJointCount: Int,
        maximumPairCount: Int
    ) throws {
        do {
            self.init(
                try GlifiCooccurrenceOptions(
                    maximumTermCount: maximumTermCount,
                    minimumJointCount: minimumJointCount,
                    maximumPairCount: maximumPairCount
                )
            )
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        }
    }

    /// Decodes only valid bounds.
    public init(from decoder: any Decoder) throws {
        let value = try GlifiCooccurrenceOptions(from: decoder)
        self.init(value)
    }

    /// Encodes the bounds.
    public func encode(to encoder: any Encoder) throws {
        try coreValue.encode(to: encoder)
    }

    fileprivate init(_ value: GlifiCooccurrenceOptions) {
        coreValue = value
        maximumTermCount = value.maximumTermCount
        minimumJointCount = value.minimumJointCount
        maximumPairCount = value.maximumPairCount
    }
}

// MARK: - Collocations

/// One term pair with its document-presence table and measures.
public struct GlifiStudioCollocationPair: Codable, Equatable, Sendable {
    /// Lexicographically first term.
    public let firstTerm: String
    /// Lexicographically second term.
    public let secondTerm: String
    /// Documents with both terms.
    public let jointCount: Int
    /// Documents with the first term only.
    public let firstOnlyCount: Int
    /// Documents with the second term only.
    public let secondOnlyCount: Int
    /// Documents with neither term.
    public let neitherCount: Int
    /// `PMI-v1`.
    public let pmi: Double?
    /// `NPMI-v1`.
    public let npmi: Double?
    /// `Dice-v1`.
    public let dice: Double?
    /// `Jaccard-v1`.
    public let jaccard: Double?
    /// `t-score-v1`.
    public let tScore: Double?
    /// `logDice-v1`.
    public let logDice: Double?

    init(_ value: GlifiCorpusCollocationPair) {
        firstTerm = value.firstTerm
        secondTerm = value.secondTerm
        jointCount = value.jointCount
        firstOnlyCount = value.firstOnlyCount
        secondOnlyCount = value.secondOnlyCount
        neitherCount = value.neitherCount
        pmi = value.pmi
        npmi = value.npmi
        dice = value.dice
        jaccard = value.jaccard
        tScore = value.tScore
        logDice = value.logDice
    }
}

/// Presentation-independent collocation measures.
public struct GlifiStudioCollocationResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Context definition.
    public let contextIdentifier: String
    /// Universe of opportunities: the number of documents.
    public let universeSize: Int
    /// Bounds applied to term and pair selection.
    public let options: GlifiStudioCooccurrenceOptions
    /// Selected terms in lexicographic order.
    public let selectedTerms: [String]
    /// Pairs evaluated before the joint-count threshold.
    public let evaluatedPairCount: Int
    /// Whether retained pairs exceeded the stored maximum.
    public let isTruncated: Bool
    /// Retained pairs in declared order.
    public let pairs: [GlifiStudioCollocationPair]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusCollocationAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        corpusDigest = value.corpusDigest
        sourceRevisionIDs = value.sourceRevisionIDs
        contextIdentifier = value.contextIdentifier
        universeSize = value.universeSize
        options = GlifiStudioCooccurrenceOptions(value.options)
        selectedTerms = value.selectedTerms
        evaluatedPairCount = value.evaluatedPairCount
        isTruncated = value.isTruncated
        pairs = value.pairs.map(GlifiStudioCollocationPair.init)
    }
}

// MARK: - Lexical network

/// Centrality values of one term node.
public struct GlifiStudioNetworkNode: Codable, Equatable, Identifiable, Sendable {
    /// Stable row identity derived from the normalized term.
    public var id: String { term }
    /// Normalized lexical form.
    public let term: String
    /// `Degree-v1`.
    public let degree: Int
    /// `WeightedDegree-v1`.
    public let weightedDegree: Double
    /// `PageRank-v1`.
    public let pageRank: Double
    /// Raw `Betweenness-v1`.
    public let betweenness: Double
    /// `HarmonicCloseness-v1`.
    public let harmonicCloseness: Double
    /// `WeightedBetweenness-v1`.
    public let weightedBetweenness: Double
    /// `WeightedHarmonicCloseness-v1`.
    public let weightedHarmonicCloseness: Double
    /// `EigenvectorCentrality-v1`.
    public let eigenvector: Double
    /// Weak component index.
    public let weakComponent: Int
    /// Strong component index.
    public let strongComponent: Int
    /// Louvain community index.
    public let community: Int

    init(_ value: GlifiCorpusNetworkNode) {
        term = value.term
        degree = value.degree
        weightedDegree = value.weightedDegree
        pageRank = value.pageRank
        betweenness = value.betweenness
        harmonicCloseness = value.harmonicCloseness
        weightedBetweenness = value.weightedBetweenness
        weightedHarmonicCloseness = value.weightedHarmonicCloseness
        eigenvector = value.eigenvector
        weakComponent = value.weakComponent
        strongComponent = value.strongComponent
        community = value.community
    }
}

/// One observation of a pair, resolvable to exact source positions.
public struct GlifiStudioWindowOccurrence: Codable, Equatable, Sendable {
    /// Source revision containing the observation.
    public let sourceRevisionID: String
    /// Inclusive UTF-8 start of the node token.
    public let nodeStart: Int
    /// Exclusive UTF-8 end of the node token.
    public let nodeEnd: Int
    /// Inclusive UTF-8 start of the collocate token.
    public let collocateStart: Int
    /// Exclusive UTF-8 end of the collocate token.
    public let collocateEnd: Int
    /// Signed token offset of the collocate.
    public let offset: Int

    init(_ value: GlifiWindowOccurrence) {
        sourceRevisionID = value.sourceRevisionID
        nodeStart = value.nodeRange.start
        nodeEnd = value.nodeRange.end
        collocateStart = value.collocateRange.start
        collocateEnd = value.collocateRange.end
        offset = value.offset
    }
}

/// One network edge with its weight and lineage.
public struct GlifiStudioNetworkEdge: Codable, Equatable, Sendable {
    /// Source term.
    public let source: String
    /// Target term.
    public let target: String
    /// Edge weight.
    public let weight: Double
    /// Supporting joint count.
    public let jointCount: Int
    /// `logDice-v1`.
    public let logDice: Double?
    /// Supporting documents.
    public let supportingSourceRevisionIDs: [String]
    /// Supporting source positions.
    public let occurrences: [GlifiStudioWindowOccurrence]

    init(_ value: GlifiCorpusNetworkEdge) {
        source = value.source
        target = value.target
        weight = value.weight
        jointCount = value.jointCount
        logDice = value.logDice
        supportingSourceRevisionIDs = value.supportingSourceRevisionIDs
        occurrences = value.occurrences.map(GlifiStudioWindowOccurrence.init)
    }
}

/// Graph-level summary of a lexical network.
public struct GlifiStudioNetworkSummary: Codable, Equatable, Sendable {
    /// Number of nodes.
    public let nodeCount: Int
    /// Number of edges.
    public let edgeCount: Int
    /// Number of weak components.
    public let weakComponentCount: Int
    /// Number of strong components.
    public let strongComponentCount: Int
    /// Number of communities.
    public let communityCount: Int?
    /// Modularity of the partition.
    public let modularity: Double?
    /// Principal eigenvalue.
    public let eigenvalue: Double?
    /// Whether the eigenvector iteration converged.
    public let eigenvectorConverged: Bool

    init(_ value: GlifiNetworkSummary) {
        nodeCount = value.nodeCount
        edgeCount = value.edgeCount
        weakComponentCount = value.weakComponentCount
        strongComponentCount = value.strongComponentCount
        communityCount = value.communityCount
        modularity = value.modularity
        eigenvalue = value.eigenvalue
        eigenvectorConverged = value.eigenvectorConverged
    }
}

/// Presentation-independent term co-occurrence network.
public struct GlifiStudioLexicalNetworkResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Context definition.
    public let contextIdentifier: String
    /// Graph construction rule.
    public let graphIdentifier: String
    /// Bounds applied to term and pair selection.
    public let options: GlifiStudioCooccurrenceOptions
    /// Number of undirected edges.
    public let edgeCount: Int
    /// `PageRank-v1` damping.
    public let pageRankDamping: Double
    /// Whether `PageRank-v1` converged.
    public let pageRankConverged: Bool
    /// Nodes ordered by PageRank.
    public let nodes: [GlifiStudioNetworkNode]
    /// Graph-level summary.
    public let summary: GlifiStudioNetworkSummary
    /// Edges with supporting documents.
    public let edges: [GlifiStudioNetworkEdge]

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusLexicalNetworkAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        corpusDigest = value.corpusDigest
        sourceRevisionIDs = value.sourceRevisionIDs
        contextIdentifier = value.contextIdentifier
        graphIdentifier = value.graphIdentifier
        options = GlifiStudioCooccurrenceOptions(value.options)
        edgeCount = value.edgeCount
        pageRankDamping = value.pageRankDamping
        pageRankConverged = value.pageRankConverged
        nodes = value.nodes.map(GlifiStudioNetworkNode.init)
        summary = GlifiStudioNetworkSummary(value.summary)
        edges = value.edges.map(GlifiStudioNetworkEdge.init)
    }
}

// MARK: - Coding agreement

/// One unit coded independently by every coder.
public struct GlifiStudioCodingUnit: Codable, Equatable, Sendable {
    /// Stable identity of the coded unit.
    public let unitIdentifier: String
    /// One nominal label per coder, `nil` for a missing judgment.
    public let labels: [String?]

    /// Creates one coded unit.
    public init(unitIdentifier: String, labels: [String?]) {
        self.unitIdentifier = unitIdentifier
        self.labels = labels
    }
}

/// Bounded, validated coding table supplied by the caller.
public struct GlifiStudioCodingAgreementRequest: Codable, Equatable, Sendable {
    let coreValue: GlifiCodingAgreementRequest

    /// Distinct coder identities, in label order.
    public let coderIdentifiers: [String]
    /// Distinct coded units.
    public let units: [GlifiStudioCodingUnit]

    /// Creates a request only after checking bounds and shape.
    public init(
        coderIdentifiers: [String],
        units: [GlifiStudioCodingUnit],
        level: String = "nominal"
    ) throws {
        do {
            guard let measurement = GlifiMeasurementLevel(rawValue: level) else {
                throw GlifiFailure(
                    code: "agreement.invalid-level",
                    category: .invalidInput,
                    operation: .analyze,
                    retryDisposition: .afterCorrection,
                    retainedState: .unchanged,
                    messageKey: "failure.agreement.invalid-level"
                )
            }
            self.init(
                try GlifiCodingAgreementRequest(
                    coderIdentifiers: coderIdentifiers,
                    units: units.map {
                        GlifiCodingUnit(unitIdentifier: $0.unitIdentifier, labels: $0.labels)
                    },
                    level: measurement
                )
            )
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        }
    }

    /// Decodes only a valid table.
    public init(from decoder: any Decoder) throws {
        self.init(try GlifiCodingAgreementRequest(from: decoder))
    }

    /// Encodes the table.
    public func encode(to encoder: any Encoder) throws {
        try coreValue.encode(to: encoder)
    }

    private init(_ value: GlifiCodingAgreementRequest) {
        coreValue = value
        coderIdentifiers = value.coderIdentifiers
        units = value.units.map {
            GlifiStudioCodingUnit(unitIdentifier: $0.unitIdentifier, labels: $0.labels)
        }
    }
}

/// `CohenKappaNominal-v1` values.
public struct GlifiStudioCodingCohenKappa: Codable, Equatable, Sendable {
    /// Observed proportion of agreement.
    public let observedAgreement: Double
    /// Chance-expected proportion of agreement.
    public let expectedAgreement: Double
    /// `κ`.
    public let kappa: Double

    init(_ value: GlifiCodingCohenKappa) {
        observedAgreement = value.observedAgreement
        expectedAgreement = value.expectedAgreement
        kappa = value.kappa
    }
}

/// `KrippendorffAlpha-v1` values.
public struct GlifiStudioCodingKrippendorffAlpha: Codable, Equatable, Sendable {
    /// Observed disagreement.
    public let observedDisagreement: Double
    /// Expected disagreement.
    public let expectedDisagreement: Double
    /// `α`.
    public let alpha: Double
    /// Units with at least two non-missing judgments.
    public let includedUnitCount: Int

    init(_ value: GlifiCodingKrippendorffAlpha) {
        observedDisagreement = value.observedDisagreement
        expectedDisagreement = value.expectedDisagreement
        alpha = value.alpha
        includedUnitCount = value.includedUnitCount
    }
}

/// Presentation-independent inter-coder agreement.
public struct GlifiStudioCodingAgreementResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Digest of the canonical coding table.
    public let requestDigest: String
    /// Coder identities in label order.
    public let coderIdentifiers: [String]
    /// Number of coded units.
    public let unitCount: Int
    /// Number of distinct labels.
    public let categoryCount: Int
    /// Number of missing judgments.
    public let missingJudgmentCount: Int
    /// Cohen method identity.
    public let cohenIdentifier: String
    /// Cohen's kappa, `nil` when unavailable.
    public let cohen: GlifiStudioCodingCohenKappa?
    /// Reason code when kappa is unavailable.
    public let cohenUnavailableReason: String?
    /// Krippendorff method identity.
    public let krippendorffIdentifier: String
    /// Krippendorff's alpha, `nil` when unavailable.
    public let krippendorff: GlifiStudioCodingKrippendorffAlpha?
    /// Reason code when alpha is unavailable.
    public let krippendorffUnavailableReason: String?

    /// Declared measurement level.
    public let level: String
    /// Krippendorff's alpha at the declared level.
    public let leveledAlpha: Double?
    /// Reason code when the leveled alpha is unavailable.
    public let leveledAlphaUnavailableReason: String?
    /// Lower unit-bootstrap bound of alpha.
    public let alphaLower: Double?
    /// Upper unit-bootstrap bound of alpha.
    public let alphaUpper: Double?
    /// Fleiss kappa.
    public let fleissKappa: Double?
    /// Reason code when Fleiss kappa is unavailable.
    public let fleissUnavailableReason: String?

    init(_ result: GlifiProjectDerivedResult<GlifiCodingAgreementAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        requestDigest = value.requestDigest
        coderIdentifiers = value.coderIdentifiers
        unitCount = value.unitCount
        categoryCount = value.categoryCount
        missingJudgmentCount = value.missingJudgmentCount
        cohenIdentifier = value.cohenIdentifier
        cohen = value.cohen.map(GlifiStudioCodingCohenKappa.init)
        cohenUnavailableReason = value.cohenUnavailableReason
        krippendorffIdentifier = value.krippendorffIdentifier
        krippendorff = value.krippendorff.map(GlifiStudioCodingKrippendorffAlpha.init)
        krippendorffUnavailableReason = value.krippendorffUnavailableReason
        level = value.level.rawValue
        leveledAlpha = value.leveledAlpha
        leveledAlphaUnavailableReason = value.leveledAlphaUnavailableReason
        alphaLower = value.alphaInterval?.lower
        alphaUpper = value.alphaInterval?.upper
        fleissKappa = value.fleiss?.kappa
        fleissUnavailableReason = value.fleissUnavailableReason
    }
}

// MARK: - Window collocations

/// Public explicit window definition of a token co-occurrence analysis.
public struct GlifiStudioWindowCooccurrenceOptions: Codable, Equatable, Sendable {
    /// Conservative defaults shared by native and headless clients.
    public static let standard = GlifiStudioWindowCooccurrenceOptions(.standard)

    let coreValue: GlifiWindowCooccurrenceOptions

    /// Lexical tokens considered before the node token.
    public let leftSpan: Int
    /// Lexical tokens considered after the node token.
    public let rightSpan: Int
    /// Whether the window may extend across sentence boundaries.
    public let crossesSentences: Bool
    /// Whether a term co-occurring with itself is counted.
    public let includesSelfPairs: Bool
    /// Smallest joint count of a retained pair.
    public let minimumJointCount: Int
    /// Largest number of stored pairs.
    public let maximumPairCount: Int
    /// Whether observations weigh `1/d` instead of 1.
    public let weightsByInverseDistance: Bool
    /// Largest number of source positions kept per pair.
    public let maximumPositionsPerPair: Int

    /// Creates a valid window without silently correcting parameters.
    public init(
        leftSpan: Int,
        rightSpan: Int,
        crossesSentences: Bool,
        includesSelfPairs: Bool,
        minimumJointCount: Int,
        maximumPairCount: Int,
        weightsByInverseDistance: Bool = false,
        maximumPositionsPerPair: Int = 10
    ) throws {
        do {
            self.init(
                try GlifiWindowCooccurrenceOptions(
                    leftSpan: leftSpan,
                    rightSpan: rightSpan,
                    crossesSentences: crossesSentences,
                    includesSelfPairs: includesSelfPairs,
                    minimumJointCount: minimumJointCount,
                    maximumPairCount: maximumPairCount,
                    distanceWeighting: weightsByInverseDistance ? .inverseDistance : .none,
                    maximumPositionsPerPair: maximumPositionsPerPair
                )
            )
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        }
    }

    /// Decodes only valid windows.
    public init(from decoder: any Decoder) throws {
        let value = try GlifiWindowCooccurrenceOptions(from: decoder)
        self.init(value)
    }

    /// Encodes the window.
    public func encode(to encoder: any Encoder) throws {
        try coreValue.encode(to: encoder)
    }

    fileprivate init(_ value: GlifiWindowCooccurrenceOptions) {
        coreValue = value
        leftSpan = value.leftSpan
        rightSpan = value.rightSpan
        crossesSentences = value.crossesSentences
        includesSelfPairs = value.includesSelfPairs
        minimumJointCount = value.minimumJointCount
        maximumPairCount = value.maximumPairCount
        weightsByInverseDistance = value.distanceWeighting == .inverseDistance
        maximumPositionsPerPair = value.maximumPositionsPerPair
    }
}

/// One ordered node→collocate pair with its 2×2 table and measures.
public struct GlifiStudioWindowCollocationPair: Codable, Equatable, Sendable {
    /// Node term whose window is inspected.
    public let nodeTerm: String
    /// Term observed inside the window of the node.
    public let collocateTerm: String
    /// Ordered pairs node→collocate.
    public let jointCount: Int
    /// Ordered pairs with this node and another collocate.
    public let nodeOnlyCount: Int
    /// Ordered pairs with another node and this collocate.
    public let collocateOnlyCount: Int
    /// Ordered pairs with neither.
    public let neitherCount: Int
    /// `PMI-v1`.
    public let pmi: Double?
    /// `NPMI-v1`.
    public let npmi: Double?
    /// `Dice-v1`.
    public let dice: Double?
    /// `Jaccard-v1`.
    public let jaccard: Double?
    /// `t-score-v1`.
    public let tScore: Double?
    /// `logDice-v1`.
    public let logDice: Double?
    /// Mean absolute token distance.
    public let meanDistance: Double
    /// Distance-weighted joint count.
    public let weightedJointCount: Double
    /// First source positions.
    public let occurrences: [GlifiStudioWindowOccurrence]
    /// Whether more observations exist than those stored.
    public let occurrencesTruncated: Bool

    init(_ value: GlifiWindowCollocationPair) {
        nodeTerm = value.nodeTerm
        collocateTerm = value.collocateTerm
        jointCount = value.jointCount
        nodeOnlyCount = value.nodeOnlyCount
        collocateOnlyCount = value.collocateOnlyCount
        neitherCount = value.neitherCount
        pmi = value.pmi
        npmi = value.npmi
        dice = value.dice
        jaccard = value.jaccard
        tScore = value.tScore
        logDice = value.logDice
        meanDistance = value.meanDistance
        weightedJointCount = value.weightedJointCount
        occurrences = value.occurrences.map(GlifiStudioWindowOccurrence.init)
        occurrencesTruncated = value.occurrencesTruncated
    }
}

/// Presentation-independent window collocation measures.
public struct GlifiStudioWindowCollocationResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Tokenization contract that produced the token sequences.
    public let tokenizationContractIdentifier: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Context definition.
    public let contextIdentifier: String
    /// Definition of the opportunities counted by the 2×2 tables.
    public let universeIdentifier: String
    /// Window and thresholds applied.
    public let options: GlifiStudioWindowCooccurrenceOptions
    /// Lexical tokens across all analyzed documents.
    public let tokenCount: Int
    /// Ordered node→collocate observations.
    public let universeSize: Int
    /// Distinct ordered pairs observed before thresholds.
    public let distinctPairCount: Int
    /// Whether retained pairs exceeded the stored maximum.
    public let isTruncated: Bool
    /// Retained pairs in declared order.
    public let pairs: [GlifiStudioWindowCollocationPair]

    init(_ result: GlifiProjectDerivedResult<GlifiWindowCollocationAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        tokenizationContractIdentifier = value.tokenizationContractIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs
        contextIdentifier = value.contextIdentifier
        universeIdentifier = value.universeIdentifier
        options = GlifiStudioWindowCooccurrenceOptions(value.options)
        tokenCount = value.tokenCount
        universeSize = value.universeSize
        distinctPairCount = value.distinctPairCount
        isTruncated = value.isTruncated
        pairs = value.pairs.map(GlifiStudioWindowCollocationPair.init)
    }
}

// MARK: - Metric correlation

/// One correlation coefficient with its two-sided asymptotic test.
public struct GlifiStudioMetricCorrelation: Codable, Equatable, Sendable {
    /// Coefficient in `[-1, 1]`.
    public let coefficient: Double
    /// `n-2`.
    public let degreesOfFreedom: Int
    /// `t` statistic, `nil` for a perfect correlation.
    public let tStatistic: Double?
    /// Two-sided asymptotic p-value.
    public let pValue: Double

    init(_ value: GlifiMetricCorrelation) {
        coefficient = value.coefficient
        degreesOfFreedom = value.degreesOfFreedom
        tStatistic = value.tStatistic
        pValue = value.pValue
    }
}

/// Presentation-independent correlation of two document metrics.
public struct GlifiStudioMetricCorrelationResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Definition of the first variable.
    public let firstMetricIdentifier: String
    /// Normalized term of the first variable.
    public let firstTerm: String?
    /// Definition of the second variable.
    public let secondMetricIdentifier: String
    /// Normalized term of the second variable.
    public let secondTerm: String?
    /// Pearson method identity.
    public let pearsonIdentifier: String
    /// Spearman method identity.
    public let spearmanIdentifier: String
    /// Number of paired observations.
    public let pairCount: Int
    /// Pearson coefficient, `nil` when unavailable.
    public let pearson: GlifiStudioMetricCorrelation?
    /// Reason code when Pearson is unavailable.
    public let pearsonUnavailableReason: String?
    /// Spearman coefficient, `nil` when unavailable.
    public let spearman: GlifiStudioMetricCorrelation?
    /// Reason code when Spearman is unavailable.
    public let spearmanUnavailableReason: String?
    /// Lower Fisher-z bound of Pearson's r.
    public let pearsonLower: Double?
    /// Upper Fisher-z bound of Pearson's r.
    public let pearsonUpper: Double?
    /// Reason code when the Fisher-z interval is undefined.
    public let pearsonIntervalUnavailableReason: String?
    /// Exact permutation p-value of Spearman's ρ.
    public let spearmanExactPValue: Double?
    /// Reason code when the exact Spearman p-value is not applicable.
    public let spearmanExactUnavailableReason: String?

    init(_ result: GlifiProjectDerivedResult<GlifiMetricCorrelationAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        corpusDigest = value.corpusDigest
        sourceRevisionIDs = value.sourceRevisionIDs
        firstMetricIdentifier = value.firstMetricIdentifier
        firstTerm = value.firstTerm
        secondMetricIdentifier = value.secondMetricIdentifier
        secondTerm = value.secondTerm
        pearsonIdentifier = value.pearsonIdentifier
        spearmanIdentifier = value.spearmanIdentifier
        pairCount = value.pairCount
        pearson = value.pearson.map(GlifiStudioMetricCorrelation.init)
        pearsonUnavailableReason = value.pearsonUnavailableReason
        spearman = value.spearman.map(GlifiStudioMetricCorrelation.init)
        spearmanUnavailableReason = value.spearmanUnavailableReason
        pearsonLower = value.pearsonInterval?.lower
        pearsonUpper = value.pearsonInterval?.upper
        pearsonIntervalUnavailableReason = value.pearsonIntervalUnavailableReason
        spearmanExactPValue = value.spearmanExactPValue
        spearmanExactUnavailableReason = value.spearmanExactUnavailableReason
    }
}

// MARK: - Post-hoc

/// Raw and family-adjusted p-values of one pairwise test.
public struct GlifiStudioPostHocTest: Codable, Equatable, Sendable {
    /// Raw two-sided p-value.
    public let pValue: Double
    /// Bonferroni-adjusted p-value.
    public let bonferroniPValue: Double
    /// Benjamini–Hochberg q-value.
    public let benjaminiHochbergPValue: Double

    init(_ value: GlifiPostHocTest) {
        pValue = value.pValue
        bonferroniPValue = value.bonferroniPValue
        benjaminiHochbergPValue = value.benjaminiHochbergPValue
    }
}

/// Procedure-specific post-hoc value of one pair.
public struct GlifiStudioPostHocProcedureValue: Codable, Equatable, Sendable {
    /// `q` or `z`.
    public let statistic: Double
    /// Reference degrees of freedom.
    public let degreesOfFreedom: Double?
    /// Procedure-adjusted (Tukey, Games–Howell) or raw (Dunn) p-value.
    public let pValue: Double
    /// Dunn Bonferroni-adjusted p-value.
    public let bonferroniPValue: Double?
    /// Dunn Benjamini–Hochberg q-value.
    public let benjaminiHochbergPValue: Double?
    /// Tukey lower simultaneous bound.
    public let lower: Double?
    /// Tukey upper simultaneous bound.
    public let upper: Double?

    init(_ value: GlifiPostHocProcedureValue) {
        statistic = value.statistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        bonferroniPValue = value.bonferroniPValue
        benjaminiHochbergPValue = value.benjaminiHochbergPValue
        lower = value.lower
        upper = value.upper
    }
}

/// Cohen's d, Hedges' g and the interval of d.
public struct GlifiStudioStandardizedDifference: Codable, Equatable, Sendable {
    /// Cohen's d (pooled).
    public let cohenD: Double
    /// Exact small-sample factor J.
    public let correctionFactor: Double
    /// Hedges' g.
    public let hedgesG: Double
    /// Standard error of d.
    public let standardError: Double
    /// Confidence level.
    public let confidenceLevel: Double
    /// Lower bound of d.
    public let lower: Double
    /// Upper bound of d.
    public let upper: Double

    init(_ value: GlifiStandardizedDifference) {
        cohenD = value.cohenD
        correctionFactor = value.correctionFactor
        hedgesG = value.hedgesG
        standardError = value.standardError
        confidenceLevel = value.confidenceLevel
        lower = value.lower
        upper = value.upper
    }
}

/// One pair of groups with its pairwise tests.
public struct GlifiStudioPostHocPair: Codable, Equatable, Sendable {
    /// Zero-based index of the first group.
    public let firstGroupIndex: Int
    /// Zero-based index of the second group.
    public let secondGroupIndex: Int
    /// Difference of the group means.
    public let meanDifference: Double
    /// Welch statistic.
    public let welchStatistic: Double?
    /// Welch test, `nil` when unavailable.
    public let welch: GlifiStudioPostHocTest?
    /// Reason code when Welch is unavailable.
    public let welchUnavailableReason: String?
    /// Mann–Whitney `U₁`.
    public let mannWhitneyU1: Double?
    /// Declared Mann–Whitney method.
    public let mannWhitneyMethodIdentifier: String?
    /// Mann–Whitney test, `nil` when unavailable.
    public let mannWhitney: GlifiStudioPostHocTest?
    /// Reason code when Mann–Whitney is unavailable.
    public let mannWhitneyUnavailableReason: String?
    /// Tukey HSD value.
    public let tukey: GlifiStudioPostHocProcedureValue?
    /// Games–Howell value.
    public let gamesHowell: GlifiStudioPostHocProcedureValue?
    /// Dunn value with adjustments.
    public let dunn: GlifiStudioPostHocProcedureValue?
    /// Standardized difference.
    public let standardizedDifference: GlifiStudioStandardizedDifference?
    /// Rank-biserial correlation.
    public let rankBiserial: Double?

    init(_ value: GlifiPostHocPair) {
        firstGroupIndex = value.firstGroupIndex
        secondGroupIndex = value.secondGroupIndex
        meanDifference = value.meanDifference
        welchStatistic = value.welchStatistic
        welch = value.welch.map(GlifiStudioPostHocTest.init)
        welchUnavailableReason = value.welchUnavailableReason
        mannWhitneyU1 = value.mannWhitneyU1
        mannWhitneyMethodIdentifier = value.mannWhitneyMethodIdentifier
        mannWhitney = value.mannWhitney.map(GlifiStudioPostHocTest.init)
        mannWhitneyUnavailableReason = value.mannWhitneyUnavailableReason
        tukey = value.tukey.map(GlifiStudioPostHocProcedureValue.init)
        gamesHowell = value.gamesHowell.map(GlifiStudioPostHocProcedureValue.init)
        dunn = value.dunn.map(GlifiStudioPostHocProcedureValue.init)
        standardizedDifference = value.standardizedDifference.map(
            GlifiStudioStandardizedDifference.init
        )
        rankBiserial = value.rankBiserial
    }
}

/// Presentation-independent pairwise post-hoc comparison.
public struct GlifiStudioPostHocResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Metric definition identity.
    public let metricIdentifier: String
    /// Normalized term of a term-frequency metric.
    public let term: String?
    /// Family definition.
    public let familyIdentifier: String
    /// Welch method identity.
    public let welchIdentifier: String
    /// Mann–Whitney method identity.
    public let mannWhitneyIdentifier: String
    /// Bonferroni method identity.
    public let bonferroniIdentifier: String
    /// Benjamini–Hochberg method identity.
    public let benjaminiHochbergIdentifier: String
    /// Tukey method identity.
    public let tukeyIdentifier: String
    /// Games–Howell method identity.
    public let gamesHowellIdentifier: String
    /// Dunn method identity.
    public let dunnIdentifier: String
    /// Hedges method identity.
    public let hedgesIdentifier: String
    /// Rank-biserial method identity.
    public let rankBiserialIdentifier: String
    /// Confidence level of the intervals.
    public let confidenceLevel: Double
    /// Reason code when Tukey is unavailable.
    public let tukeyUnavailableReason: String?
    /// Reason code when Games–Howell is unavailable.
    public let gamesHowellUnavailableReason: String?
    /// Reason code when Dunn is unavailable.
    public let dunnUnavailableReason: String?
    /// Corpus-profile digest of each group.
    public let groupCorpusDigests: [String]
    /// Number of groups compared.
    public let groupCount: Int
    /// Size of the Welch family.
    public let welchFamilySize: Int
    /// Size of the Mann–Whitney family.
    public let mannWhitneyFamilySize: Int
    /// Pairs in lexicographic order of group indexes.
    public let pairs: [GlifiStudioPostHocPair]

    init(_ result: GlifiProjectDerivedResult<GlifiPostHocAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        metricIdentifier = value.metricIdentifier
        term = value.term
        familyIdentifier = value.familyIdentifier
        welchIdentifier = value.welchIdentifier
        mannWhitneyIdentifier = value.mannWhitneyIdentifier
        bonferroniIdentifier = value.bonferroniIdentifier
        benjaminiHochbergIdentifier = value.benjaminiHochbergIdentifier
        tukeyIdentifier = value.tukeyIdentifier
        gamesHowellIdentifier = value.gamesHowellIdentifier
        dunnIdentifier = value.dunnIdentifier
        hedgesIdentifier = value.hedgesIdentifier
        rankBiserialIdentifier = value.rankBiserialIdentifier
        confidenceLevel = value.confidenceLevel
        tukeyUnavailableReason = value.tukeyUnavailableReason
        gamesHowellUnavailableReason = value.gamesHowellUnavailableReason
        dunnUnavailableReason = value.dunnUnavailableReason
        groupCorpusDigests = value.groupCorpusDigests
        groupCount = value.groupCount
        welchFamilySize = value.welchFamilySize
        mannWhitneyFamilySize = value.mannWhitneyFamilySize
        pairs = value.pairs.map(GlifiStudioPostHocPair.init)
    }
}

// MARK: - Paired metrics

/// Presentation-independent paired comparison of two document metrics.
public struct GlifiStudioPairedMetricResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Canonically ordered paired documents.
    public let sourceRevisionIDs: [String]
    /// Definition of the first variable.
    public let firstMetricIdentifier: String
    /// Definition of the second variable.
    public let secondMetricIdentifier: String
    /// Zero policy of the signed-rank test.
    public let zeroPolicyIdentifier: String
    /// Number of paired documents.
    public let pairCount: Int
    /// Mean difference `first - second`.
    public let meanDifference: Double
    /// Confidence level.
    public let confidenceLevel: Double
    /// Paired t statistic.
    public let tStatistic: Double?
    /// `n-1`.
    public let degreesOfFreedom: Int?
    /// Two-sided paired t p-value.
    public let tPValue: Double?
    /// Lower bound of the mean difference.
    public let lower: Double?
    /// Upper bound of the mean difference.
    public let upper: Double?
    /// `d_z`.
    public let standardizedMeanDifference: Double?
    /// Reason code when the paired t-test is unavailable.
    public let pairedTUnavailableReason: String?
    /// Declared signed-rank method.
    public let wilcoxonMethodIdentifier: String?
    /// Sum of positive ranks.
    public let positiveRankSum: Double?
    /// Zero differences removed.
    public let droppedZeroCount: Int?
    /// Two-sided signed-rank p-value.
    public let wilcoxonPValue: Double?
    /// Reason code when the signed-rank test is unavailable.
    public let wilcoxonUnavailableReason: String?

    init(_ result: GlifiProjectDerivedResult<GlifiPairedMetricAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs
        firstMetricIdentifier = value.firstMetricIdentifier
        secondMetricIdentifier = value.secondMetricIdentifier
        zeroPolicyIdentifier = value.zeroPolicyIdentifier
        pairCount = value.pairCount
        meanDifference = value.meanDifference
        confidenceLevel = value.confidenceLevel
        tStatistic = value.tStatistic
        degreesOfFreedom = value.degreesOfFreedom
        tPValue = value.tPValue
        lower = value.lower
        upper = value.upper
        standardizedMeanDifference = value.standardizedMeanDifference
        pairedTUnavailableReason = value.pairedTUnavailableReason
        wilcoxonMethodIdentifier = value.wilcoxonMethodIdentifier
        positiveRankSum = value.positiveRankSum
        droppedZeroCount = value.droppedZeroCount
        wilcoxonPValue = value.wilcoxonPValue
        wilcoxonUnavailableReason = value.wilcoxonUnavailableReason
    }
}

// MARK: - Window network

/// Presentation-independent token-window network.
public struct GlifiStudioWindowNetworkResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Graph construction rule.
    public let graphIdentifier: String
    /// Distance used by path-based centralities.
    public let distanceIdentifier: String
    /// Window used to build the network.
    public let window: GlifiStudioWindowCooccurrenceOptions
    /// `logDice-v1` threshold applied after measurement.
    public let minimumLogDice: Double?
    /// Whether edges weigh the distance-weighted joint count.
    public let usesWeightedJointCount: Bool
    /// Retained pairs before the logDice threshold.
    public let candidateEdgeCount: Int
    /// Graph-level summary.
    public let summary: GlifiStudioNetworkSummary
    /// Nodes ordered by PageRank.
    public let nodes: [GlifiStudioNetworkNode]
    /// Edges with source positions.
    public let edges: [GlifiStudioNetworkEdge]

    init(_ result: GlifiProjectDerivedResult<GlifiWindowNetworkAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs
        graphIdentifier = value.graphIdentifier
        distanceIdentifier = value.distanceIdentifier
        window = GlifiStudioWindowCooccurrenceOptions(value.options.window)
        minimumLogDice = value.options.minimumLogDice
        usesWeightedJointCount = value.options.usesWeightedJointCount
        candidateEdgeCount = value.candidateEdgeCount
        summary = GlifiStudioNetworkSummary(value.summary)
        nodes = value.nodes.map(GlifiStudioNetworkNode.init)
        edges = value.edges.map(GlifiStudioNetworkEdge.init)
    }
}

// MARK: - Multivariate

/// Declared multivariate method.
public enum GlifiStudioMultivariateMethod: Equatable, Sendable {
    /// Correspondence Analysis on raw counts.
    case correspondence
    /// PCA on relative frequencies.
    case principalComponents(scaled: Bool)
    /// LSA of rank `k` on TF-IDF weights.
    case latentSemantic(rank: Int)
    /// NMF of rank `k` on raw counts.
    case nonNegativeFactorization(rank: Int, seed: UInt64, restarts: Int)
    /// Agglomerative clustering with linkage `single`, `complete`, `average` or `ward`.
    case hierarchical(linkage: String, clusterCount: Int)
    /// K-means with k-means++ initialization.
    case kMeans(clusterCount: Int, seed: UInt64, restarts: Int)

    func coreValue() throws -> GlifiMultivariateMethod {
        switch self {
        case .correspondence: return .correspondence
        case let .principalComponents(scaled): return .principalComponents(scaled: scaled)
        case let .latentSemantic(rank): return .latentSemantic(rank: rank)
        case let .nonNegativeFactorization(rank, seed, restarts):
            return .nonNegativeFactorization(rank: rank, seed: seed, restarts: restarts)
        case let .hierarchical(linkage, clusterCount):
            guard let value = GlifiLinkage(rawValue: linkage) else {
                throw GlifiFailure(
                    code: "multivariate.invalid-linkage",
                    category: .invalidInput,
                    operation: .analyze,
                    retryDisposition: .afterCorrection,
                    retainedState: .unchanged,
                    messageKey: "failure.multivariate.invalid-linkage"
                )
            }
            return .hierarchical(linkage: value, clusterCount: clusterCount)
        case let .kMeans(clusterCount, seed, restarts):
            return .kMeans(clusterCount: clusterCount, seed: seed, restarts: restarts)
        }
    }
}

/// One merge of an agglomerative tree.
public struct GlifiStudioMerge: Codable, Equatable, Sendable {
    /// First child: `0..<n` documents, `n+s` the cluster of step `s`.
    public let first: Int
    /// Second child.
    public let second: Int
    /// Merge height.
    public let height: Double
    /// Size of the new cluster.
    public let size: Int
}

/// Presentation-independent multivariate result with method-agnostic fields.
public struct GlifiStudioMultivariateResult: Codable, Equatable, Sendable {
    /// Project and generation lineage.
    public let lineage: GlifiStudioDerivedLineage
    /// Versioned analysis identity.
    public let analysisIdentifier: String
    /// Method identity.
    public let methodIdentifier: String
    /// Row representation.
    public let representationIdentifier: String
    /// Corpus digest, absent only in older presentation JSON.
    public let corpusDigest: String?
    /// Term-selection rule, absent only in older presentation JSON.
    public let termSelectionIdentifier: String?
    /// Average silhouette of the computed partition, when defined.
    public let averageSilhouette: Double?
    /// Documents (rows).
    public let sourceRevisionIDs: [String]
    /// Terms (columns).
    public let terms: [String]
    /// Singular values, inertias or variances per axis, depending on the method.
    public let axisValues: [Double]
    /// Share of each axis (relative inertia or explained variance).
    public let axisShares: [Double]
    /// Row coordinates per axis (documents).
    public let rowCoordinates: [[Double]]
    /// Column coordinates or loadings per axis (terms).
    public let columnCoordinates: [[Double]]
    /// Row contributions (CA).
    public let rowContributions: [[Double]]?
    /// Column contributions (CA).
    public let columnContributions: [[Double]]?
    /// Row cos² (CA).
    public let rowCosines: [[Double]]?
    /// Documents excluded for zero mass (CA).
    public let excludedSourceRevisionIDs: [String]
    /// Terms excluded for zero mass or constant value.
    public let excludedTerms: [String]
    /// Cluster per document (HAC cut, k-means).
    public let clusterAssignments: [Int]?
    /// Merge tree (HAC).
    public let merges: [GlifiStudioMerge]?
    /// Final objective (NMF, k-means).
    public let objective: Double?
    /// Iterations (NMF, k-means).
    public let iterations: Int?
    /// Convergence flag (NMF, k-means).
    public let converged: Bool?
    /// Seed (NMF, k-means).
    public let seed: UInt64?
    /// Residual Frobenius norm (LSA).
    public let residualNorm: Double?
    /// SVD backend used by CA, PCA or LSA.
    public let backendIdentifier: String?

    init(_ result: GlifiProjectDerivedResult<GlifiCorpusMultivariateAnalysis>) {
        let value = result.value
        lineage = GlifiStudioDerivedLineage(result)
        analysisIdentifier = value.analysisIdentifier
        methodIdentifier = value.method.identifier
        representationIdentifier = value.representationIdentifier
        corpusDigest = value.corpusDigest
        termSelectionIdentifier = value.termSelectionIdentifier
        averageSilhouette = value.averageSilhouette
        sourceRevisionIDs = value.sourceRevisionIDs
        terms = value.terms
        clusterAssignments = value.clusterAssignments
        var axisValues: [Double] = []
        var axisShares: [Double] = []
        var rows: [[Double]] = []
        var columns: [[Double]] = []
        var excludedDocuments: [String] = []
        var excludedTerms: [String] = []
        if let ca = value.correspondence {
            axisValues = ca.inertias
            axisShares = ca.inertias.map { $0 / ca.totalInertia }
            rows = ca.rowCoordinates
            columns = ca.columnCoordinates
            let includedRows = Set(ca.includedRows)
            let includedColumns = Set(ca.includedColumns)
            excludedDocuments = value.sourceRevisionIDs.indices
                .filter { !includedRows.contains($0) }.map { value.sourceRevisionIDs[$0] }
            excludedTerms = value.terms.indices
                .filter { !includedColumns.contains($0) }.map { value.terms[$0] }
        } else if let pca = value.principalComponents {
            axisValues = pca.variances
            axisShares = pca.varianceShares
            rows = pca.scores
            columns = pca.loadings
            excludedTerms = pca.excludedConstantColumns.map { value.terms[$0] }
        } else if let lsa = value.latentSemantic {
            axisValues = lsa.singularValues
            let total = lsa.allSingularValues.reduce(0) { $0 + $1 * $1 }
            axisShares = lsa.singularValues.map { total > 0 ? $0 * $0 / total : 0 }
            rows = lsa.rowCoordinates
            columns = lsa.columnCoordinates
        } else if let nmf = value.nonNegativeFactorization {
            rows = nmf.w
            columns = GlifiLinearAlgebra.transpose(nmf.h)
        } else if let kMeans = value.kMeans {
            columns = GlifiLinearAlgebra.transpose(kMeans.centers)
        }
        self.axisValues = axisValues
        self.axisShares = axisShares
        rowCoordinates = rows
        columnCoordinates = columns
        rowContributions = value.correspondence?.rowContributions
        columnContributions = value.correspondence?.columnContributions
        rowCosines = value.correspondence?.rowCosines
        excludedSourceRevisionIDs = excludedDocuments
        self.excludedTerms = excludedTerms
        merges = value.hierarchical?.merges.map {
            GlifiStudioMerge(first: $0.first, second: $0.second, height: $0.height, size: $0.size)
        }
        objective = value.nonNegativeFactorization?.objective ?? value.kMeans?.objective
        iterations = value.nonNegativeFactorization?.iterations ?? value.kMeans?.iterations
        converged = value.nonNegativeFactorization?.converged ?? value.kMeans?.converged
        seed = value.nonNegativeFactorization?.seed ?? value.kMeans?.seed
        residualNorm = value.latentSemantic?.residualNorm
        backendIdentifier =
            value.correspondence?.backendIdentifier ?? value.principalComponents?.backendIdentifier
            ?? value.latentSemantic?.backendIdentifier
    }
}
