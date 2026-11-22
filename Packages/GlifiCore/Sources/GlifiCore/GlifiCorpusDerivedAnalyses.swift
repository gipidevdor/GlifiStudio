// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Per-document term counts reconstructed from the sparse matrix of one
/// corpus profile.
struct GlifiDocumentTermCounts {
    /// Canonically ordered document identities, including empty documents.
    let documentIDs: [SourceRevisionID]
    /// Lexicographically ordered vocabulary.
    let terms: [String]
    /// Non-zero counts per document, keyed by term index.
    let rows: [[Int: Int]]

    init(_ analysis: GlifiCorpusAnalysis) {
        documentIDs = analysis.matrix.rowSourceRevisionIDs
        terms = analysis.matrix.terms
        var rows = Array(repeating: [Int: Int](), count: documentIDs.count)
        for cell in analysis.matrix.cells where rows.indices.contains(cell.rowIndex) {
            rows[cell.rowIndex][cell.columnIndex] = cell.count
        }
        self.rows = rows
    }

    /// Lexical-token count of each document.
    var documentLengths: [Int] {
        rows.map { $0.values.reduce(0, +) }
    }
}

// MARK: - Document × term association

/// One cell whose standardized residual is among the largest in magnitude.
public struct GlifiCorpusAssociationResidual: Codable, Equatable, Sendable {
    /// Normalized lexical form.
    public let term: String
    /// Document that owns the cell.
    public let sourceRevisionID: String
    /// Observed count.
    public let observed: Int
    /// Count expected under independence.
    public let expected: Double
    /// Standardized residual of the cell.
    public let standardizedResidual: Double
}

/// `PearsonChiSquareRxC-v1` and `CramersV-v1` over the document × term table.
public struct GlifiCorpusAssociationAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-association.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-document-term-association-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Independence-test method identity.
    public let chiSquareIdentifier: String
    /// Effect-size method identity.
    public let cramersVIdentifier: String
    /// Total number of lexical tokens in the table.
    public let totalObservations: Int
    /// Documents that carry at least one token.
    public let includedDocumentCount: Int
    /// Distinct terms in the table.
    public let includedTermCount: Int
    /// Documents excluded for a zero margin.
    public let excludedSourceRevisionIDs: [String]
    /// Pearson `χ²` statistic.
    public let chiSquareStatistic: Double
    /// `(I-1)(J-1)` after exclusions.
    public let degreesOfFreedom: Int
    /// Upper-tail asymptotic p-value.
    public let pValue: Double
    /// Non-directional effect size in `[0,1]`.
    public let cramersV: Double
    /// Share of included cells whose expected count is below five.
    public let lowExpectedCellFraction: Double
    /// Largest number of residual rows stored.
    public let residualLimit: Int
    /// Cells with the largest absolute standardized residual.
    public let topResiduals: [GlifiCorpusAssociationResidual]
    /// `ChiSquareMonteCarlo-v1` identity.
    public let monteCarloIdentifier: String
    /// Fixed-margin Monte Carlo p-value of χ² on the included table.
    public let monteCarloPValue: Double?
    /// Simulated tables.
    public let monteCarloSimulationCount: Int
    /// Recorded seed of the simulation.
    public let monteCarloSeed: UInt64
    /// Stable reason code when the Monte Carlo p-value is unavailable.
    public let monteCarloUnavailableReason: String?
    /// `FisherExact2x2-v1` p-value, only when the included table is 2×2.
    public let fisherPValue: Double?
}

/// Computes document × term association from one corpus profile.
public struct GlifiCorpusAssociationAnalyzer: Sendable {
    /// Largest admitted dense table (documents × terms).
    public static let maximumCellCount = 2_000_000
    /// Simulated tables of the Monte Carlo p-value.
    public static let monteCarloSimulationCount = 2_000
    /// Recorded seed of the Monte Carlo p-value.
    public static let monteCarloSeed: UInt64 = 20_260_918

    /// Creates a stateless analyzer.
    public init() {}

    /// Analyzes the document × term table of `analysis`.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        residualLimit: Int = 20
    ) throws -> GlifiCorpusAssociationAnalysis {
        try Task.checkCancellation()
        guard residualLimit >= 0, residualLimit <= 1_000 else {
            throw derivedAnalysisFailure("association.invalid-residual-limit")
        }
        let counts = GlifiDocumentTermCounts(analysis)
        let documentCount = counts.documentIDs.count
        let termCount = counts.terms.count
        guard documentCount >= 2, termCount >= 2 else {
            throw derivedAnalysisFailure(
                "association.insufficient-table",
                category: .insufficientData
            )
        }
        guard documentCount <= Self.maximumCellCount / termCount else {
            throw derivedAnalysisFailure(
                "association.table-too-large",
                category: .insufficientResources
            )
        }
        var cells = Array(
            repeating: Array(repeating: 0, count: termCount),
            count: documentCount
        )
        for (row, entries) in counts.rows.enumerated() {
            for (column, count) in entries { cells[row][column] = count }
        }
        let table = try GlifiContingencyTable(
            rowLabels: counts.documentIDs.map(\.canonicalValue),
            columnLabels: counts.terms,
            cells: cells
        )
        let association = try GlifiContingencyAnalysis.associate(table)

        let rowMargins = table.rowMargins
        let columnMargins = table.columnMargins
        let total = Double(table.total)
        let excludedRows = Set(association.excludedRowIndices)
        var lowExpected = 0
        var includedCells = 0
        var candidates: [GlifiCorpusAssociationResidual] = []
        for row in cells.indices where !excludedRows.contains(row) {
            for column in 0..<termCount {
                let expected = Double(rowMargins[row]) * Double(columnMargins[column]) / total
                includedCells += 1
                if expected < 5 { lowExpected += 1 }
                guard let residual = association.standardizedResiduals[row][column] else {
                    continue
                }
                candidates.append(
                    GlifiCorpusAssociationResidual(
                        term: counts.terms[column],
                        sourceRevisionID: counts.documentIDs[row].canonicalValue,
                        observed: cells[row][column],
                        expected: expected,
                        standardizedResidual: residual
                    )
                )
            }
        }
        candidates.sort {
            let left = abs($0.standardizedResidual)
            let right = abs($1.standardizedResidual)
            if left != right { return left > right }
            if $0.term != $1.term { return $0.term < $1.term }
            return $0.sourceRevisionID < $1.sourceRevisionID
        }
        let excludedColumns = Set(association.excludedColumnIndices)
        let includedTable = cells.indices.filter { !excludedRows.contains($0) }.map { row in
            (0..<termCount).filter { !excludedColumns.contains($0) }.map { cells[row][$0] }
        }
        var monteCarlo: Double?
        var monteCarloReason: String?
        do {
            monteCarlo = try GlifiStatisticalFoundation.monteCarloChiSquare(
                includedTable,
                simulationCount: Self.monteCarloSimulationCount,
                seed: Self.monteCarloSeed
            ).pValue
        } catch let failure as GlifiFailure {
            monteCarloReason = failure.code
        }
        let fisher =
            includedTable.count == 2 && includedTable.first?.count == 2
            ? try? GlifiStatisticalFoundation.fisherExact(includedTable).pValue : nil
        return GlifiCorpusAssociationAnalysis(
            analysisIdentifier: GlifiCorpusAssociationAnalysis.analysisIdentifier,
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: counts.documentIDs.map(\.canonicalValue),
            chiSquareIdentifier: GlifiContingencyAssociation.chiSquareIdentifier,
            cramersVIdentifier: GlifiContingencyAssociation.cramersVIdentifier,
            totalObservations: table.total,
            includedDocumentCount: documentCount - excludedRows.count,
            includedTermCount: termCount - association.excludedColumnIndices.count,
            excludedSourceRevisionIDs: association.excludedRowIndices.map {
                counts.documentIDs[$0].canonicalValue
            },
            chiSquareStatistic: association.chiSquareStatistic,
            degreesOfFreedom: association.degreesOfFreedom,
            pValue: association.pValue,
            cramersV: association.cramersV,
            lowExpectedCellFraction: includedCells == 0
                ? 0 : Double(lowExpected) / Double(includedCells),
            residualLimit: residualLimit,
            topResiduals: Array(candidates.prefix(residualLimit)),
            monteCarloIdentifier: GlifiMonteCarloChiSquareResult.identifier,
            monteCarloPValue: monteCarlo,
            monteCarloSimulationCount: Self.monteCarloSimulationCount,
            monteCarloSeed: Self.monteCarloSeed,
            monteCarloUnavailableReason: monteCarloReason,
            fisherPValue: fisher
        )
    }
}

// MARK: - Per-term dispersion

/// Dispersion measures of one normalized term over the document partition.
public struct GlifiCorpusDispersionRow: Codable, Equatable, Sendable {
    /// Normalized lexical form.
    public let term: String
    /// Total occurrences.
    public let frequency: Int
    /// Documents that contain the term.
    public let documentFrequency: Int
    /// `GriesDP-v1`.
    public let griesDP: Double
    /// `GriesDPnorm-v1`, `nil` when its denominator is not positive.
    public let griesDPNorm: Double?
    /// `JuillandD-equal-v1`, `nil` unless every document has the same size.
    public let juillandD: Double?
}

/// `GriesDP-v1`, `GriesDPnorm-v1` and `JuillandD-equal-v1` per term.
public struct GlifiCorpusDispersionAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-dispersion.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-term-dispersion-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered documents.
    public let sourceRevisionIDs: [String]
    /// Partition rule: one part per document, or declared groups of documents.
    public let partitionIdentifier: String
    /// Documents of each part, in part order.
    public let parts: [[String]]
    /// `GriesDP-v1` identity.
    public let griesDPIdentifier: String
    /// `GriesDPnorm-v1` identity.
    public let griesDPNormIdentifier: String
    /// `JuillandD-equal-v1` identity.
    public let juillandDIdentifier: String
    /// Lexical-token count `n_i` of each unit, in unit order.
    public let unitSizes: [Int]
    /// Whether all units have the same size, making Juilland D defined.
    public let equalSizePartition: Bool
    /// Complete term rows in canonical order (frequency, then term).
    public let terms: [GlifiCorpusDispersionRow]
}

/// Computes per-term dispersion from one corpus profile.
public struct GlifiCorpusDispersionAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Analyzes every term of `analysis` over the document partition or a declared one.
    ///
    /// A declared partition must cover every document exactly once with at least two parts;
    /// part sizes and frequencies are the sums over their documents.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        partition declared: [[String]]? = nil
    ) throws -> GlifiCorpusDispersionAnalysis {
        try Task.checkCancellation()
        let counts = GlifiDocumentTermCounts(analysis)
        let identifiers = counts.documentIDs.map(\.canonicalValue)
        let parts = declared ?? identifiers.map { [$0] }
        let rowByDocument = Dictionary(
            uniqueKeysWithValues: identifiers.enumerated().map { ($1, $0) })
        let flattened = parts.flatMap { $0 }
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty }),
            Set(flattened).count == flattened.count,
            Set(flattened) == Set(identifiers)
        else {
            throw derivedAnalysisFailure("dispersion.invalid-partition")
        }
        let partRows = parts.map { part in part.compactMap { rowByDocument[$0] } }
        let lengths = counts.documentLengths
        let unitSizes = partRows.map { rows in rows.reduce(0) { $0 + lengths[$1] } }
        guard counts.documentIDs.count >= 2, !counts.terms.isEmpty else {
            throw derivedAnalysisFailure(
                "dispersion.insufficient-partition",
                category: .insufficientData
            )
        }
        var frequencies = Array(
            repeating: Array(repeating: 0, count: parts.count),
            count: counts.terms.count
        )
        for (part, rows) in partRows.enumerated() {
            for row in rows {
                for (column, count) in counts.rows[row] { frequencies[column][part] += count }
            }
        }
        var rows: [GlifiCorpusDispersionRow] = []
        rows.reserveCapacity(counts.terms.count)
        for (column, term) in counts.terms.enumerated() {
            if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
            let partition = try GlifiDispersionPartition(
                unitSizes: unitSizes,
                unitFrequencies: frequencies[column]
            )
            let result = try GlifiDispersionAnalysis.dispersion(partition)
            rows.append(
                GlifiCorpusDispersionRow(
                    term: term,
                    frequency: partition.totalFrequency,
                    documentFrequency: counts.rows.filter { $0[column] != nil }.count,
                    griesDP: result.griesDP,
                    griesDPNorm: result.griesDPNorm,
                    juillandD: result.juillandD
                )
            )
        }
        rows.sort {
            $0.frequency == $1.frequency ? $0.term < $1.term : $0.frequency > $1.frequency
        }
        return GlifiCorpusDispersionAnalysis(
            analysisIdentifier: GlifiCorpusDispersionAnalysis.analysisIdentifier,
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: identifiers,
            partitionIdentifier: declared == nil
                ? "document-partition-v1" : "declared-partition-v1",
            parts: parts,
            griesDPIdentifier: GlifiDispersionResult.griesDPIdentifier,
            griesDPNormIdentifier: GlifiDispersionResult.griesDPNormIdentifier,
            juillandDIdentifier: GlifiDispersionResult.juillandDIdentifier,
            unitSizes: unitSizes,
            equalSizePartition: Set(unitSizes).count == 1,
            terms: rows
        )
    }
}

// MARK: - Group location comparison

/// Document-level metric compared across groups.
public enum GlifiDocumentMetric: Codable, Equatable, Sendable {
    /// Lexical-token count of each document.
    case lexicalTokenCount
    /// Relative frequency of one normalized term in each document.
    case termRelativeFrequency(String)

    /// Versioned identity of the metric definition.
    public var identifier: String {
        switch self {
        case .lexicalTokenCount: "document-lexical-token-count-v1"
        case .termRelativeFrequency: "document-term-relative-frequency-v1"
        }
    }
}

extension GlifiDocumentMetric {
    /// Normalized term of a term-frequency metric; `nil` for other metrics.
    func normalizedTerm() throws -> String? {
        guard case let .termRelativeFrequency(term) = self else { return nil }
        let value = term.precomposedStringWithCanonicalMapping.lowercased(
            with: Locale(identifier: "it_IT")
        )
        guard !value.isEmpty else {
            throw derivedAnalysisFailure("group-comparison.empty-term")
        }
        return value
    }

    /// One value per document of `analysis`, in canonical document order.
    func values(in analysis: GlifiCorpusAnalysis, normalizedTerm: String?) throws -> [Double] {
        let counts = GlifiDocumentTermCounts(analysis)
        let lengths = counts.documentLengths
        switch self {
        case .lexicalTokenCount:
            return lengths.map(Double.init)
        case .termRelativeFrequency:
            guard lengths.allSatisfy({ $0 > 0 }) else {
                throw derivedAnalysisFailure(
                    "group-comparison.empty-document",
                    category: .insufficientData
                )
            }
            let column = normalizedTerm.flatMap { counts.terms.firstIndex(of: $0) }
            return zip(counts.rows, lengths).map { row, length in
                Double(column.flatMap { row[$0] } ?? 0) / Double(length)
            }
        }
    }
}

/// Summary of one compared group.
public struct GlifiGroupMetricSummary: Codable, Equatable, Sendable {
    /// Canonically ordered documents of the group.
    public let sourceRevisionIDs: [String]
    /// Number of documents contributing one value each.
    public let documentCount: Int
    /// Arithmetic mean of the metric.
    public let mean: Double
    /// Unbiased sample variance, `nil` for a single document.
    public let variance: Double?
    /// Lower `BootstrapPercentile-v1` bound of the mean, `nil` for a single document.
    public let bootstrapLower: Double?
    /// Upper `BootstrapPercentile-v1` bound of the mean, `nil` for a single document.
    public let bootstrapUpper: Double?
    /// Lower `BootstrapBCa-v1` bound of the mean, `nil` when BCa is undefined.
    public let bcaLower: Double?
    /// Upper `BootstrapBCa-v1` bound of the mean, `nil` when BCa is undefined.
    public let bcaUpper: Double?
}

/// `PermutationMeanDifference-v1` values of a two-group comparison.
public struct GlifiGroupPermutation: Codable, Equatable, Sendable {
    /// `exact` or `monte-carlo`, chosen by the declared rule.
    public let strategyIdentifier: String
    /// Observed `x̄₁ - x̄₂`.
    public let observedDifference: Double
    /// Relabelings evaluated.
    public let evaluatedCount: Int
    /// Relabelings at least as extreme as the observed one.
    public let extremeCount: Int
    /// Two-sided p-value: exact `b/m`, Monte Carlo `(b+1)/(m+1)`.
    public let pValue: Double
}

/// `OneWayANOVA-v1` values of a group comparison.
public struct GlifiGroupANOVA: Codable, Equatable, Sendable {
    /// `F` statistic.
    public let fStatistic: Double
    /// `k-1`.
    public let numeratorDegreesOfFreedom: Int
    /// `N-k`.
    public let denominatorDegreesOfFreedom: Int
    /// Upper-tail asymptotic p-value.
    public let pValue: Double
}

/// `WelchT-v1` values of a two-group comparison.
public struct GlifiGroupWelch: Codable, Equatable, Sendable {
    /// `t` statistic.
    public let statistic: Double
    /// Welch–Satterthwaite degrees of freedom.
    public let degreesOfFreedom: Double
    /// Two-sided asymptotic p-value.
    public let pValue: Double
}

/// `MannWhitneyU-v1` values of a two-group comparison.
public struct GlifiGroupMannWhitney: Codable, Equatable, Sendable {
    /// `exact` or `asymptotic-tie-corrected-continuity`, chosen by the declared rule.
    public let methodIdentifier: String
    /// `U₁` of the first group.
    public let u1: Double
    /// `U₂` of the second group.
    public let u2: Double
    /// Standard-normal statistic, `nil` for the exact method.
    public let zStatistic: Double?
    /// Two-sided p-value.
    public let pValue: Double
}

/// `KruskalWallis-v1` values of a group comparison.
public struct GlifiGroupKruskalWallis: Codable, Equatable, Sendable {
    /// `H` before tie correction.
    public let hStatistic: Double
    /// Tie-correction factor `C`.
    public let tieCorrection: Double
    /// `H/C`.
    public let correctedHStatistic: Double
    /// `k-1`.
    public let degreesOfFreedom: Int
    /// Upper-tail asymptotic chi-square p-value.
    public let pValue: Double
    /// `KruskalEpsilonSquared-v1`: `ε² = (H/C)/(N-1)`.
    public let epsilonSquared: Double
}

/// Request-level parameters of a group comparison, persisted in the descriptor.
public struct GlifiGroupComparisonOptions: Codable, Equatable, Sendable {
    /// Defaults recorded in GS-VER-097.
    public static let standard = GlifiGroupComparisonOptions(
        validatedConfidenceLevel: 0.95,
        bootstrapResampleCount: 2_000,
        permutationMonteCarloCount: 9_999,
        resamplingSeed: 20_260_918,
        contrasts: []
    )

    /// Confidence level of every interval.
    public let confidenceLevel: Double
    /// Bootstrap resamples per group.
    public let bootstrapResampleCount: Int
    /// Monte Carlo relabelings used when exact enumeration exceeds its bound.
    public let permutationMonteCarloCount: Int
    /// Seed of every resampling step.
    public let resamplingSeed: UInt64
    /// Declared family of planned contrasts, one coefficient per group, each summing to zero.
    public let contrasts: [[Double]]

    /// Creates validated options without silently correcting parameters.
    public init(
        confidenceLevel: Double,
        bootstrapResampleCount: Int,
        permutationMonteCarloCount: Int,
        resamplingSeed: UInt64,
        contrasts: [[Double]]
    ) throws {
        guard confidenceLevel > 0, confidenceLevel < 1,
            (1...GlifiStatisticalFoundation.maximumResampleCount).contains(bootstrapResampleCount),
            (1...GlifiStatisticalFoundation.maximumResampleCount).contains(
                permutationMonteCarloCount
            ),
            contrasts.count <= 100,
            contrasts.allSatisfy({ $0.allSatisfy(\.isFinite) })
        else {
            throw derivedAnalysisFailure("group-comparison.invalid-options")
        }
        self.init(
            validatedConfidenceLevel: confidenceLevel,
            bootstrapResampleCount: bootstrapResampleCount,
            permutationMonteCarloCount: permutationMonteCarloCount,
            resamplingSeed: resamplingSeed,
            contrasts: contrasts
        )
    }

    private init(
        validatedConfidenceLevel: Double,
        bootstrapResampleCount: Int,
        permutationMonteCarloCount: Int,
        resamplingSeed: UInt64,
        contrasts: [[Double]]
    ) {
        confidenceLevel = validatedConfidenceLevel
        self.bootstrapResampleCount = bootstrapResampleCount
        self.permutationMonteCarloCount = permutationMonteCarloCount
        self.resamplingSeed = resamplingSeed
        self.contrasts = contrasts
    }

    /// Decodes only valid options.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            confidenceLevel: container.decode(Double.self, forKey: .confidenceLevel),
            bootstrapResampleCount: container.decode(Int.self, forKey: .bootstrapResampleCount),
            permutationMonteCarloCount: container.decode(
                Int.self,
                forKey: .permutationMonteCarloCount
            ),
            resamplingSeed: container.decode(UInt64.self, forKey: .resamplingSeed),
            contrasts: container.decodeIfPresent([[Double]].self, forKey: .contrasts) ?? []
        )
    }

    private enum CodingKeys: String, CodingKey {
        case confidenceLevel, bootstrapResampleCount, permutationMonteCarloCount
        case resamplingSeed, contrasts
    }
}

/// Location comparison of a document metric across independent groups.
public struct GlifiGroupMetricComparison: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.group-metric-comparison.v5"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "document-metric-group-comparison-v5"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Metric definition identity.
    public let metricIdentifier: String
    /// Normalized term of a term-frequency metric.
    public let term: String?
    /// `OneWayANOVA-v1` identity.
    public let anovaIdentifier: String
    /// `WelchT-v1` identity.
    public let welchIdentifier: String
    /// `MannWhitneyU-v1` identity.
    public let mannWhitneyIdentifier: String
    /// `KruskalWallis-v1` identity.
    public let kruskalWallisIdentifier: String
    /// `CohenD-pooled-v1` identity.
    public let cohenDIdentifier: String
    /// `PermutationMeanDifference-v1` identity.
    public let permutationIdentifier: String
    /// `BootstrapPercentile-v1` identity of the per-group intervals.
    public let bootstrapIdentifier: String
    /// `BootstrapBCa-v1` identity of the per-group intervals.
    public let bcaIdentifier: String
    /// `HedgesG-v1` identity.
    public let hedgesIdentifier: String
    /// `RankBiserial-v1` identity.
    public let rankBiserialIdentifier: String
    /// `PlannedContrast-v1` identity.
    public let contrastIdentifier: String
    /// Generator of every resampling step.
    public let generatorIdentifier: String
    /// Recorded seed of every resampling step.
    public let resamplingSeed: UInt64
    /// Bootstrap resamples per group.
    public let bootstrapResampleCount: Int
    /// Confidence level of the per-group intervals.
    public let bootstrapConfidenceLevel: Double
    /// Monte Carlo relabelings used when exact enumeration exceeds its bound.
    public let permutationMonteCarloCount: Int
    /// Corpus-profile digest of each group, in group order.
    public let groupCorpusDigests: [String]
    /// Per-group summaries in request order.
    public let groups: [GlifiGroupMetricSummary]
    /// ANOVA, `nil` when its preconditions are not met.
    public let anova: GlifiGroupANOVA?
    /// Stable reason code when ANOVA is unavailable.
    public let anovaUnavailableReason: String?
    /// Welch t, only for exactly two groups meeting its preconditions.
    public let welch: GlifiGroupWelch?
    /// Stable reason code when Welch t is unavailable.
    public let welchUnavailableReason: String?
    /// Mann–Whitney U, only for exactly two groups meeting its preconditions.
    public let mannWhitney: GlifiGroupMannWhitney?
    /// Stable reason code when Mann–Whitney U is unavailable.
    public let mannWhitneyUnavailableReason: String?
    /// Kruskal–Wallis H, `nil` when its preconditions are not met.
    public let kruskalWallis: GlifiGroupKruskalWallis?
    /// Stable reason code when Kruskal–Wallis H is unavailable.
    public let kruskalWallisUnavailableReason: String?
    /// `d = (x̄₁-x̄₂)/s_p`, only for exactly two groups meeting its preconditions.
    public let cohenD: Double?
    /// Stable reason code when Cohen's d is unavailable.
    public let cohenDUnavailableReason: String?
    /// Permutation test, only for exactly two groups.
    public let permutation: GlifiGroupPermutation?
    /// Stable reason code when the permutation test is unavailable.
    public let permutationUnavailableReason: String?
    /// Hedges' g and the interval of d, only for exactly two groups.
    public let standardizedDifference: GlifiStandardizedDifference?
    /// Rank-biserial correlation from Mann–Whitney `U₁`, only for exactly two groups.
    public let rankBiserial: Double?
    /// Planned contrasts of the declared family, in request order.
    public let contrasts: [GlifiContrastResult]
    /// Stable reason code when the declared contrasts cannot be computed.
    public let contrastsUnavailableReason: String?
}

/// Compares one document metric across groups.
public struct GlifiGroupMetricAnalyzer: Sendable {
    /// Default seed of the resampling steps.
    public static let resamplingSeed: UInt64 = GlifiGroupComparisonOptions.standard.resamplingSeed

    /// Creates a stateless analyzer.
    public init() {}

    /// Compares `metric` across the corpus profiles of independent groups.
    public func compare(
        groups: [GlifiCorpusAnalysis],
        metric: GlifiDocumentMetric,
        options: GlifiGroupComparisonOptions = .standard
    ) throws -> GlifiGroupMetricComparison {
        try Task.checkCancellation()
        guard groups.count >= 2 else {
            throw derivedAnalysisFailure(
                "group-comparison.insufficient-groups",
                category: .insufficientData
            )
        }
        let normalizedTerm = try metric.normalizedTerm()
        var samples: [[Double]] = []
        for group in groups {
            samples.append(try metric.values(in: group, normalizedTerm: normalizedTerm))
        }
        let summaries = zip(groups, samples).map { group, sample -> GlifiGroupMetricSummary in
            let mean = sample.reduce(0, +) / Double(sample.count)
            let variance: Double? =
                sample.count >= 2
                ? sample.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
                    / Double(sample.count - 1)
                : nil
            let interval =
                sample.count >= 2
                ? try? GlifiStatisticalFoundation.bootstrapMeanInterval(
                    sample,
                    confidenceLevel: options.confidenceLevel,
                    resampleCount: options.bootstrapResampleCount,
                    seed: options.resamplingSeed
                ) : nil
            let bca =
                sample.count >= 2
                ? try? GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
                    sample,
                    confidenceLevel: options.confidenceLevel,
                    resampleCount: options.bootstrapResampleCount,
                    seed: options.resamplingSeed
                ) : nil
            return GlifiGroupMetricSummary(
                sourceRevisionIDs: group.matrix.rowSourceRevisionIDs.map(\.canonicalValue),
                documentCount: sample.count,
                mean: mean,
                variance: variance,
                bootstrapLower: interval?.lower,
                bootstrapUpper: interval?.upper,
                bcaLower: bca?.lower,
                bcaUpper: bca?.upper
            )
        }

        var anova: GlifiGroupANOVA?
        var anovaReason: String?
        do {
            let result = try GlifiStatisticalFoundation.oneWayANOVA(samples)
            anova = GlifiGroupANOVA(
                fStatistic: result.fStatistic,
                numeratorDegreesOfFreedom: result.numeratorDegreesOfFreedom,
                denominatorDegreesOfFreedom: result.denominatorDegreesOfFreedom,
                pValue: result.pValue
            )
        } catch let failure as GlifiFailure {
            anovaReason = failure.code
        }
        var welch: GlifiGroupWelch?
        var welchReason: String?
        if samples.count == 2 {
            do {
                let result = try GlifiStatisticalFoundation.welchTTest(samples[0], samples[1])
                welch = GlifiGroupWelch(
                    statistic: result.statistic,
                    degreesOfFreedom: result.degreesOfFreedom,
                    pValue: result.pValue
                )
            } catch let failure as GlifiFailure {
                welchReason = failure.code
            }
        } else {
            welchReason = "statistics.requires-two-groups"
        }
        var mannWhitney: GlifiGroupMannWhitney?
        var mannWhitneyReason: String?
        if samples.count == 2 {
            // Regola dichiarata: esatto senza tie e fino al limite di enumerazione,
            // altrimenti asintotico con correzione dei tie e di continuità.
            let pooled = GlifiStatisticalFoundation.midranks(samples[0] + samples[1])
            let isExact =
                pooled.tieGroupSizes.isEmpty
                && pooled.ranks.count
                    <= GlifiStatisticalFoundation.maximumExactMannWhitneySampleCount
            do {
                let result = try GlifiStatisticalFoundation.mannWhitneyU(
                    samples[0],
                    samples[1],
                    method: isExact ? .exact : .asymptotic(continuityCorrection: true)
                )
                mannWhitney = GlifiGroupMannWhitney(
                    methodIdentifier: isExact ? "exact" : "asymptotic-tie-corrected-continuity",
                    u1: result.u1,
                    u2: result.u2,
                    zStatistic: result.zStatistic,
                    pValue: result.pValue
                )
            } catch let failure as GlifiFailure {
                mannWhitneyReason = failure.code
            }
        } else {
            mannWhitneyReason = "statistics.requires-two-groups"
        }
        var kruskalWallis: GlifiGroupKruskalWallis?
        var kruskalWallisReason: String?
        do {
            let result = try GlifiStatisticalFoundation.kruskalWallis(samples)
            kruskalWallis = GlifiGroupKruskalWallis(
                hStatistic: result.hStatistic,
                tieCorrection: result.tieCorrection,
                correctedHStatistic: result.correctedHStatistic,
                degreesOfFreedom: result.degreesOfFreedom,
                pValue: result.pValue,
                epsilonSquared: GlifiStatisticalFoundation.kruskalEpsilonSquared(
                    correctedH: result.correctedHStatistic,
                    totalCount: samples.reduce(0) { $0 + $1.count }
                ))
        } catch let failure as GlifiFailure {
            kruskalWallisReason = failure.code
        }
        var permutation: GlifiGroupPermutation?
        var permutationReason: String?
        if samples.count == 2 {
            // Regola dichiarata: enumerazione esatta entro il limite, altrimenti Monte Carlo.
            let assignments = GlifiStatisticalFoundation.binomialCoefficient(
                samples[0].count + samples[1].count,
                samples[0].count
            )
            let isExact =
                assignments.map { $0 <= GlifiStatisticalFoundation.maximumExactPermutationCount }
                ?? false
            do {
                let result = try GlifiStatisticalFoundation.permutationMeanDifference(
                    samples[0],
                    samples[1],
                    strategy: isExact
                        ? .exact
                        : .monteCarlo(
                            sampleCount: options.permutationMonteCarloCount,
                            seed: options.resamplingSeed
                        )
                )
                permutation = GlifiGroupPermutation(
                    strategyIdentifier: isExact ? "exact" : "monte-carlo",
                    observedDifference: result.observedDifference,
                    evaluatedCount: result.evaluatedCount,
                    extremeCount: result.extremeCount,
                    pValue: result.pValue
                )
            } catch let failure as GlifiFailure {
                permutationReason = failure.code
            }
        } else {
            permutationReason = "statistics.requires-two-groups"
        }
        var cohenD: Double?
        var cohenDReason: String?
        if samples.count == 2 {
            do {
                cohenD = try GlifiStatisticalFoundation.cohenDPooled(samples[0], samples[1]).d
            } catch let failure as GlifiFailure {
                cohenDReason = failure.code
            }
        } else {
            cohenDReason = "statistics.requires-two-groups"
        }
        var standardized: GlifiStandardizedDifference?
        var rankBiserial: Double?
        if samples.count == 2 {
            standardized = try? GlifiStatisticalFoundation.standardizedDifference(
                samples[0],
                samples[1],
                confidenceLevel: options.confidenceLevel
            )
            rankBiserial = mannWhitney.map {
                GlifiStatisticalFoundation.rankBiserial(
                    u1: $0.u1,
                    firstCount: samples[0].count,
                    secondCount: samples[1].count
                )
            }
        }
        var contrasts: [GlifiContrastResult] = []
        var contrastsReason: String?
        if !options.contrasts.isEmpty {
            do {
                contrasts = try GlifiStatisticalFoundation.plannedContrasts(
                    samples,
                    contrasts: options.contrasts,
                    confidenceLevel: options.confidenceLevel
                )
            } catch let failure as GlifiFailure {
                contrastsReason = failure.code
            }
        }
        return GlifiGroupMetricComparison(
            analysisIdentifier: GlifiGroupMetricComparison.analysisIdentifier,
            metricIdentifier: metric.identifier,
            term: normalizedTerm,
            anovaIdentifier: GlifiOneWayANOVAResult.identifier,
            welchIdentifier: GlifiWelchTTestResult.identifier,
            mannWhitneyIdentifier: GlifiMannWhitneyUResult.identifier,
            kruskalWallisIdentifier: GlifiKruskalWallisResult.identifier,
            cohenDIdentifier: GlifiCohenDResult.identifier,
            permutationIdentifier: GlifiPermutationTestResult.identifier,
            bootstrapIdentifier: GlifiBootstrapInterval.identifier,
            bcaIdentifier: GlifiBCaInterval.identifier,
            hedgesIdentifier: GlifiStatisticalFoundation.hedgesIdentifier,
            rankBiserialIdentifier: GlifiStatisticalFoundation.rankBiserialIdentifier,
            contrastIdentifier: GlifiStatisticalFoundation.plannedContrastIdentifier,
            generatorIdentifier: GlifiSplitMix64.identifier,
            resamplingSeed: options.resamplingSeed,
            bootstrapResampleCount: options.bootstrapResampleCount,
            bootstrapConfidenceLevel: options.confidenceLevel,
            permutationMonteCarloCount: options.permutationMonteCarloCount,
            groupCorpusDigests: groups.map(\.corpusDigest),
            groups: summaries,
            anova: anova,
            anovaUnavailableReason: anovaReason,
            welch: welch,
            welchUnavailableReason: welchReason,
            mannWhitney: mannWhitney,
            mannWhitneyUnavailableReason: mannWhitneyReason,
            kruskalWallis: kruskalWallis,
            kruskalWallisUnavailableReason: kruskalWallisReason,
            cohenD: cohenD,
            cohenDUnavailableReason: cohenDReason,
            permutation: permutation,
            permutationUnavailableReason: permutationReason,
            standardizedDifference: standardized,
            rankBiserial: rankBiserial,
            contrasts: contrasts,
            contrastsUnavailableReason: contrastsReason
        )
    }
}

// MARK: - Metric correlation

/// Correlation of two document metrics over the documents of one group.
public struct GlifiMetricCorrelationAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.metric-correlation.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "document-metric-correlation-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Definition of the first variable.
    public let firstMetricIdentifier: String
    /// Normalized term of the first variable, when it is a term frequency.
    public let firstTerm: String?
    /// Definition of the second variable.
    public let secondMetricIdentifier: String
    /// Normalized term of the second variable, when it is a term frequency.
    public let secondTerm: String?
    /// `PearsonR-v1` identity.
    public let pearsonIdentifier: String
    /// `SpearmanRho-v1` identity.
    public let spearmanIdentifier: String
    /// Number of paired observations (documents).
    public let pairCount: Int
    /// Pearson coefficient, `nil` when its preconditions are not met.
    public let pearson: GlifiMetricCorrelation?
    /// Stable reason code when Pearson is unavailable.
    public let pearsonUnavailableReason: String?
    /// Spearman coefficient, `nil` when its preconditions are not met.
    public let spearman: GlifiMetricCorrelation?
    /// Stable reason code when Spearman is unavailable.
    public let spearmanUnavailableReason: String?
    /// `PearsonFisherZ-v1` interval of Pearson's r at 95 %, `nil` when undefined.
    public let pearsonInterval: GlifiCorrelationInterval?
    /// Stable reason code when the Fisher-z interval is undefined.
    public let pearsonIntervalUnavailableReason: String?
    /// `SpearmanExactPermutation-v1` two-sided p-value, `nil` when not applicable.
    public let spearmanExactPValue: Double?
    /// Stable reason code when the exact Spearman p-value is not applicable.
    public let spearmanExactUnavailableReason: String?
}

/// One correlation coefficient with its two-sided asymptotic test.
public struct GlifiMetricCorrelation: Codable, Equatable, Sendable {
    /// Coefficient in `[-1, 1]`.
    public let coefficient: Double
    /// `n-2`.
    public let degreesOfFreedom: Int
    /// `t = r·sqrt((n-2)/(1-r²))`, `nil` for a perfect correlation.
    public let tStatistic: Double?
    /// Two-sided asymptotic Student-t p-value.
    public let pValue: Double
}

/// Correlates two document metrics of one corpus profile.
public struct GlifiMetricCorrelationAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Correlates `first` and `second` over the documents of `analysis`.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        first: GlifiDocumentMetric,
        second: GlifiDocumentMetric
    ) throws -> GlifiMetricCorrelationAnalysis {
        try Task.checkCancellation()
        let firstTerm = try first.normalizedTerm()
        let secondTerm = try second.normalizedTerm()
        let x = try first.values(in: analysis, normalizedTerm: firstTerm)
        let y = try second.values(in: analysis, normalizedTerm: secondTerm)
        guard x.count >= 3 else {
            throw derivedAnalysisFailure(
                "metric-correlation.insufficient-documents",
                category: .insufficientData
            )
        }
        var pearson: GlifiMetricCorrelation?
        var pearsonReason: String?
        do {
            pearson = GlifiMetricCorrelation(
                try GlifiStatisticalFoundation.pearsonCorrelation(x, y)
            )
        } catch let failure as GlifiFailure {
            pearsonReason = failure.code
        }
        var spearman: GlifiMetricCorrelation?
        var spearmanReason: String?
        do {
            spearman = GlifiMetricCorrelation(
                try GlifiStatisticalFoundation.spearmanCorrelation(x, y)
            )
        } catch let failure as GlifiFailure {
            spearmanReason = failure.code
        }
        var interval: GlifiCorrelationInterval?
        var intervalReason: String?
        if let pearson {
            do {
                interval = try GlifiStatisticalFoundation.pearsonFisherInterval(
                    coefficient: pearson.coefficient,
                    sampleCount: x.count
                )
            } catch let failure as GlifiFailure {
                intervalReason = failure.code
            }
        } else {
            intervalReason = pearsonReason
        }
        var exact: Double?
        var exactReason: String?
        do {
            exact = try GlifiStatisticalFoundation.spearmanExactPValue(x, y)
        } catch let failure as GlifiFailure {
            exactReason = failure.code
        }
        return GlifiMetricCorrelationAnalysis(
            analysisIdentifier: GlifiMetricCorrelationAnalysis.analysisIdentifier,
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: analysis.matrix.rowSourceRevisionIDs.map(\.canonicalValue),
            firstMetricIdentifier: first.identifier,
            firstTerm: firstTerm,
            secondMetricIdentifier: second.identifier,
            secondTerm: secondTerm,
            pearsonIdentifier: GlifiCorrelationResult.pearsonIdentifier,
            spearmanIdentifier: GlifiCorrelationResult.spearmanIdentifier,
            pairCount: x.count,
            pearson: pearson,
            pearsonUnavailableReason: pearsonReason,
            spearman: spearman,
            spearmanUnavailableReason: spearmanReason,
            pearsonInterval: interval,
            pearsonIntervalUnavailableReason: intervalReason,
            spearmanExactPValue: exact,
            spearmanExactUnavailableReason: exactReason
        )
    }
}

extension GlifiMetricCorrelation {
    fileprivate init(_ result: GlifiCorrelationResult) {
        coefficient = result.coefficient
        degreesOfFreedom = result.degreesOfFreedom
        tStatistic = result.tStatistic.isFinite ? result.tStatistic : nil
        pValue = result.pValue
    }
}

// MARK: - Paired metric comparison

/// Paired comparison of two document metrics measured on the same documents.
public struct GlifiPairedMetricAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.paired-metric-comparison.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "document-metric-paired-comparison-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Canonically ordered analyzed documents (the paired unit).
    public let sourceRevisionIDs: [String]
    /// Definition of the first variable.
    public let firstMetricIdentifier: String
    /// Normalized term of the first variable.
    public let firstTerm: String?
    /// Definition of the second variable.
    public let secondMetricIdentifier: String
    /// Normalized term of the second variable.
    public let secondTerm: String?
    /// `PairedT-v1` identity.
    public let pairedTIdentifier: String
    /// `WilcoxonSignedRank-v1` identity.
    public let wilcoxonIdentifier: String
    /// Zero policy of the signed-rank test.
    public let zeroPolicyIdentifier: String
    /// Number of paired documents.
    public let pairCount: Int
    /// Mean of the differences `first - second`.
    public let meanDifference: Double
    /// Confidence level of the interval.
    public let confidenceLevel: Double
    /// Paired t statistic, `nil` when unavailable.
    public let tStatistic: Double?
    /// `n-1`.
    public let degreesOfFreedom: Int?
    /// Two-sided paired t p-value.
    public let tPValue: Double?
    /// Lower bound of the mean difference.
    public let lower: Double?
    /// Upper bound of the mean difference.
    public let upper: Double?
    /// Standardized mean difference `d_z = d̄/s_d`.
    public let standardizedMeanDifference: Double?
    /// Stable reason code when the paired t-test is unavailable.
    public let pairedTUnavailableReason: String?
    /// Declared signed-rank method: `exact` without ties and zeros, else asymptotic.
    public let wilcoxonMethodIdentifier: String?
    /// Sum of positive ranks.
    public let positiveRankSum: Double?
    /// Zero differences removed by the declared policy.
    public let droppedZeroCount: Int?
    /// Two-sided signed-rank p-value.
    public let wilcoxonPValue: Double?
    /// Stable reason code when the signed-rank test is unavailable.
    public let wilcoxonUnavailableReason: String?
}

/// Compares two metrics on the same documents with paired tests.
public struct GlifiPairedMetricAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Compares `first` and `second` over the documents of `analysis`.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        first: GlifiDocumentMetric,
        second: GlifiDocumentMetric,
        confidenceLevel: Double = 0.95
    ) throws -> GlifiPairedMetricAnalysis {
        try Task.checkCancellation()
        let firstTerm = try first.normalizedTerm()
        let secondTerm = try second.normalizedTerm()
        let x = try first.values(in: analysis, normalizedTerm: firstTerm)
        let y = try second.values(in: analysis, normalizedTerm: secondTerm)
        guard x.count >= 2 else {
            throw derivedAnalysisFailure(
                "paired-comparison.insufficient-documents",
                category: .insufficientData
            )
        }
        let differences = zip(x, y).map { $0 - $1 }
        let meanDifference = differences.reduce(0, +) / Double(differences.count)
        var pairedT: GlifiLocationTTestResult?
        var pairedReason: String?
        var lower: Double?
        var upper: Double?
        do {
            let result = try GlifiStatisticalFoundation.pairedTTest(x, y)
            let critical = try GlifiStatisticalFoundation.tQuantile(
                (1 + confidenceLevel) / 2,
                degreesOfFreedom: Double(result.degreesOfFreedom)
            )
            let halfWidth =
                critical * result.standardDeviation / Double(result.sampleCount).squareRoot()
            pairedT = result
            lower = result.mean - halfWidth
            upper = result.mean + halfWidth
        } catch let failure as GlifiFailure {
            pairedReason = failure.code
        }
        var wilcoxon: GlifiWilcoxonSignedRankResult?
        var wilcoxonMethod: String?
        var wilcoxonReason: String?
        let nonZero = differences.filter { $0 != 0 }
        let isExact =
            nonZero.count == differences.count
            && GlifiStatisticalFoundation.midranks(nonZero.map(abs)).tieGroupSizes.isEmpty
            && nonZero.count <= GlifiStatisticalFoundation.maximumExactWilcoxonSampleCount
        do {
            wilcoxon = try GlifiStatisticalFoundation.wilcoxonSignedRank(
                x,
                y,
                method: isExact ? .exact : .asymptotic(continuityCorrection: true)
            )
            wilcoxonMethod = isExact ? "exact" : "asymptotic-tie-corrected-continuity"
        } catch let failure as GlifiFailure {
            wilcoxonReason = failure.code
        }
        return GlifiPairedMetricAnalysis(
            analysisIdentifier: GlifiPairedMetricAnalysis.analysisIdentifier,
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: analysis.matrix.rowSourceRevisionIDs.map(\.canonicalValue),
            firstMetricIdentifier: first.identifier,
            firstTerm: firstTerm,
            secondMetricIdentifier: second.identifier,
            secondTerm: secondTerm,
            pairedTIdentifier: GlifiLocationTTestResult.pairedIdentifier,
            wilcoxonIdentifier: GlifiWilcoxonSignedRankResult.identifier,
            zeroPolicyIdentifier: GlifiWilcoxonSignedRankResult.zeroPolicyIdentifier,
            pairCount: x.count,
            meanDifference: meanDifference,
            confidenceLevel: confidenceLevel,
            tStatistic: pairedT?.statistic,
            degreesOfFreedom: pairedT?.degreesOfFreedom,
            tPValue: pairedT?.pValue,
            lower: lower,
            upper: upper,
            standardizedMeanDifference: pairedT.map { $0.mean / $0.standardDeviation },
            pairedTUnavailableReason: pairedReason,
            wilcoxonMethodIdentifier: wilcoxonMethod,
            positiveRankSum: wilcoxon?.positiveRankSum,
            droppedZeroCount: wilcoxon?.droppedZeroCount,
            wilcoxonPValue: wilcoxon?.pValue,
            wilcoxonUnavailableReason: wilcoxonReason
        )
    }
}
