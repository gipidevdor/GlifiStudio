// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Raw and family-adjusted p-values of one pairwise test.
public struct GlifiPostHocTest: Codable, Equatable, Sendable {
    /// Raw two-sided p-value.
    public let pValue: Double
    /// `Bonferroni-v1` adjusted p-value within the test family.
    public let bonferroniPValue: Double
    /// `BenjaminiHochberg-v1` adjusted q-value within the test family.
    public let benjaminiHochbergPValue: Double
}

/// Result of a procedure-specific post-hoc statistic for one pair.
public struct GlifiPostHocProcedureValue: Codable, Equatable, Sendable {
    /// `q` (Tukey, Games–Howell) or `z` (Dunn).
    public let statistic: Double
    /// Reference degrees of freedom, `nil` for Dunn.
    public let degreesOfFreedom: Double?
    /// P-value adjusted by the procedure (Tukey, Games–Howell) or raw (Dunn).
    public let pValue: Double
    /// Dunn p-value adjusted by `Bonferroni-v1` over all pairs.
    public let bonferroniPValue: Double?
    /// Dunn q-value adjusted by `BenjaminiHochberg-v1` over all pairs.
    public let benjaminiHochbergPValue: Double?
    /// Lower simultaneous bound of the difference (Tukey only).
    public let lower: Double?
    /// Upper simultaneous bound of the difference (Tukey only).
    public let upper: Double?

    init(_ value: GlifiPostHocComparison, bonferroni: Double? = nil, hochberg: Double? = nil) {
        statistic = value.statistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        bonferroniPValue = bonferroni
        benjaminiHochbergPValue = hochberg
        lower = value.lower
        upper = value.upper
    }
}

/// One pair of groups with its pairwise tests.
public struct GlifiPostHocPair: Codable, Equatable, Sendable {
    /// Zero-based index of the first group in request order.
    public let firstGroupIndex: Int
    /// Zero-based index of the second group in request order.
    public let secondGroupIndex: Int
    /// `x̄_first - x̄_second`.
    public let meanDifference: Double
    /// `WelchT-v1` statistic, `nil` when its preconditions are not met.
    public let welchStatistic: Double?
    /// Welch test with adjustments, `nil` when unavailable.
    public let welch: GlifiPostHocTest?
    /// Stable reason code when Welch is unavailable.
    public let welchUnavailableReason: String?
    /// `MannWhitneyU-v1` `U₁`, `nil` when unavailable.
    public let mannWhitneyU1: Double?
    /// Declared Mann–Whitney method of this pair.
    public let mannWhitneyMethodIdentifier: String?
    /// Mann–Whitney test with adjustments, `nil` when unavailable.
    public let mannWhitney: GlifiPostHocTest?
    /// Stable reason code when Mann–Whitney is unavailable.
    public let mannWhitneyUnavailableReason: String?
    /// `TukeyHSD-v1`, `nil` when the procedure is unavailable.
    public let tukey: GlifiPostHocProcedureValue?
    /// `GamesHowell-v1`, `nil` when the procedure is unavailable.
    public let gamesHowell: GlifiPostHocProcedureValue?
    /// `Dunn-v1` with family adjustments, `nil` when the procedure is unavailable.
    public let dunn: GlifiPostHocProcedureValue?
    /// `HedgesG-v1` with Cohen's d interval, `nil` when unavailable.
    public let standardizedDifference: GlifiStandardizedDifference?
    /// `RankBiserial-v1` from the Mann–Whitney `U₁`, `nil` when unavailable.
    public let rankBiserial: Double?
}

/// Pairwise post-hoc comparison of a document metric across at least three groups.
///
/// It is a node distinct from the omnibus comparison: each test forms its own family of
/// `m` available pairwise p-values, adjusted by both Bonferroni and Benjamini–Hochberg.
public struct GlifiPostHocAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.group-metric-posthoc.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "document-metric-pairwise-posthoc-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Metric definition identity.
    public let metricIdentifier: String
    /// Normalized term of a term-frequency metric.
    public let term: String?
    /// Family definition: every unordered pair of groups, one family per test.
    public let familyIdentifier: String
    /// `WelchT-v1` identity.
    public let welchIdentifier: String
    /// `MannWhitneyU-v1` identity.
    public let mannWhitneyIdentifier: String
    /// `Bonferroni-v1` identity.
    public let bonferroniIdentifier: String
    /// `BenjaminiHochberg-v1` identity.
    public let benjaminiHochbergIdentifier: String
    /// `TukeyHSD-v1` identity.
    public let tukeyIdentifier: String
    /// `GamesHowell-v1` identity.
    public let gamesHowellIdentifier: String
    /// `Dunn-v1` identity.
    public let dunnIdentifier: String
    /// `HedgesG-v1` identity.
    public let hedgesIdentifier: String
    /// `RankBiserial-v1` identity.
    public let rankBiserialIdentifier: String
    /// Confidence level of Tukey and Cohen's d intervals.
    public let confidenceLevel: Double
    /// Stable reason code when Tukey is unavailable for the whole family.
    public let tukeyUnavailableReason: String?
    /// Stable reason code when Games–Howell is unavailable for the whole family.
    public let gamesHowellUnavailableReason: String?
    /// Stable reason code when Dunn is unavailable for the whole family.
    public let dunnUnavailableReason: String?
    /// Corpus-profile digest of each group, in group order.
    public let groupCorpusDigests: [String]
    /// Number of groups compared.
    public let groupCount: Int
    /// Available Welch p-values forming the Welch family.
    public let welchFamilySize: Int
    /// Available Mann–Whitney p-values forming the Mann–Whitney family.
    public let mannWhitneyFamilySize: Int
    /// Pairs in lexicographic order of group indexes.
    public let pairs: [GlifiPostHocPair]
}

/// Computes pairwise post-hoc comparisons of one document metric.
public struct GlifiPostHocAnalyzer: Sendable {
    /// Creates a stateless analyzer.
    public init() {}

    /// Compares every pair of `groups` on `metric`.
    public func compare(
        groups: [GlifiCorpusAnalysis],
        metric: GlifiDocumentMetric
    ) throws -> GlifiPostHocAnalysis {
        try Task.checkCancellation()
        guard groups.count >= 3 else {
            throw derivedAnalysisFailure(
                "group-posthoc.insufficient-groups",
                category: .insufficientData
            )
        }
        let normalizedTerm = try metric.normalizedTerm()
        let samples = try groups.map {
            try metric.values(in: $0, normalizedTerm: normalizedTerm)
        }

        struct Raw {
            let first: Int
            let second: Int
            let meanDifference: Double
            var welchStatistic: Double?
            var welchP: Double?
            var welchReason: String?
            var u1: Double?
            var mannWhitneyMethod: String?
            var mannWhitneyP: Double?
            var mannWhitneyReason: String?
        }
        var raws: [Raw] = []
        for first in samples.indices {
            for second in samples.indices where second > first {
                let x = samples[first]
                let y = samples[second]
                var raw = Raw(
                    first: first,
                    second: second,
                    meanDifference: x.reduce(0, +) / Double(x.count) - y.reduce(0, +)
                        / Double(y.count)
                )
                do {
                    let result = try GlifiStatisticalFoundation.welchTTest(x, y)
                    raw.welchStatistic = result.statistic
                    raw.welchP = result.pValue
                } catch let failure as GlifiFailure {
                    raw.welchReason = failure.code
                }
                let pooled = GlifiStatisticalFoundation.midranks(x + y)
                let isExact =
                    pooled.tieGroupSizes.isEmpty
                    && pooled.ranks.count
                        <= GlifiStatisticalFoundation.maximumExactMannWhitneySampleCount
                do {
                    let result = try GlifiStatisticalFoundation.mannWhitneyU(
                        x,
                        y,
                        method: isExact ? .exact : .asymptotic(continuityCorrection: true)
                    )
                    raw.u1 = result.u1
                    raw.mannWhitneyMethod =
                        isExact ? "exact" : "asymptotic-tie-corrected-continuity"
                    raw.mannWhitneyP = result.pValue
                } catch let failure as GlifiFailure {
                    raw.mannWhitneyReason = failure.code
                }
                raws.append(raw)
            }
        }

        var tukey: [GlifiPostHocComparison]?
        var tukeyReason: String?
        do {
            tukey = try GlifiStatisticalFoundation.tukeyHSD(samples)
        } catch let failure as GlifiFailure {
            tukeyReason = failure.code
        }
        var gamesHowell: [GlifiPostHocComparison]?
        var gamesHowellReason: String?
        do {
            gamesHowell = try GlifiStatisticalFoundation.gamesHowell(samples)
        } catch let failure as GlifiFailure {
            gamesHowellReason = failure.code
        }
        var dunn: [GlifiPostHocProcedureValue]?
        var dunnReason: String?
        do {
            let values = try GlifiStatisticalFoundation.dunn(samples)
            let raw = values.map(\.pValue)
            let bonferroni = try GlifiStatisticalFoundation.bonferroniAdjustedPValues(raw)
            let hochberg = try GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues(raw)
            dunn = values.indices.map {
                GlifiPostHocProcedureValue(
                    values[$0],
                    bonferroni: bonferroni[$0],
                    hochberg: hochberg[$0]
                )
            }
        } catch let failure as GlifiFailure {
            dunnReason = failure.code
        }
        let welch = try adjusted(raws.map(\.welchP))
        let mannWhitney = try adjusted(raws.map(\.mannWhitneyP))
        let pairs = raws.indices.map { index in
            let raw = raws[index]
            return GlifiPostHocPair(
                firstGroupIndex: raw.first,
                secondGroupIndex: raw.second,
                meanDifference: raw.meanDifference,
                welchStatistic: raw.welchStatistic,
                welch: welch[index],
                welchUnavailableReason: raw.welchReason,
                mannWhitneyU1: raw.u1,
                mannWhitneyMethodIdentifier: raw.mannWhitneyMethod,
                mannWhitney: mannWhitney[index],
                mannWhitneyUnavailableReason: raw.mannWhitneyReason,
                tukey: tukey.map { GlifiPostHocProcedureValue($0[index]) },
                gamesHowell: gamesHowell.map { GlifiPostHocProcedureValue($0[index]) },
                dunn: dunn?[index],
                standardizedDifference: try? GlifiStatisticalFoundation.standardizedDifference(
                    samples[raw.first],
                    samples[raw.second]
                ),
                rankBiserial: raw.u1.map {
                    GlifiStatisticalFoundation.rankBiserial(
                        u1: $0,
                        firstCount: samples[raw.first].count,
                        secondCount: samples[raw.second].count
                    )
                }
            )
        }
        return GlifiPostHocAnalysis(
            analysisIdentifier: GlifiPostHocAnalysis.analysisIdentifier,
            metricIdentifier: metric.identifier,
            term: normalizedTerm,
            familyIdentifier: "all-unordered-group-pairs-per-test-v1",
            welchIdentifier: GlifiWelchTTestResult.identifier,
            mannWhitneyIdentifier: GlifiMannWhitneyUResult.identifier,
            bonferroniIdentifier: "Bonferroni-v1",
            benjaminiHochbergIdentifier: "BenjaminiHochberg-v1",
            tukeyIdentifier: GlifiStatisticalFoundation.tukeyIdentifier,
            gamesHowellIdentifier: GlifiStatisticalFoundation.gamesHowellIdentifier,
            dunnIdentifier: GlifiStatisticalFoundation.dunnIdentifier,
            hedgesIdentifier: GlifiStatisticalFoundation.hedgesIdentifier,
            rankBiserialIdentifier: GlifiStatisticalFoundation.rankBiserialIdentifier,
            confidenceLevel: 0.95,
            tukeyUnavailableReason: tukeyReason,
            gamesHowellUnavailableReason: gamesHowellReason,
            dunnUnavailableReason: dunnReason,
            groupCorpusDigests: groups.map(\.corpusDigest),
            groupCount: groups.count,
            welchFamilySize: raws.compactMap(\.welchP).count,
            mannWhitneyFamilySize: raws.compactMap(\.mannWhitneyP).count,
            pairs: pairs
        )
    }

    /// Adjusts the available p-values as one family; unavailable entries stay `nil`.
    private func adjusted(_ values: [Double?]) throws -> [GlifiPostHocTest?] {
        let available = values.enumerated().compactMap { index, value in
            value.map { (index, $0) }
        }
        guard !available.isEmpty else { return values.map { _ in nil } }
        let raw = available.map(\.1)
        let bonferroni = try GlifiStatisticalFoundation.bonferroniAdjustedPValues(raw)
        let hochberg = try GlifiStatisticalFoundation.benjaminiHochbergAdjustedPValues(raw)
        var result = [GlifiPostHocTest?](repeating: nil, count: values.count)
        for (position, entry) in available.enumerated() {
            result[entry.0] = GlifiPostHocTest(
                pValue: entry.1,
                bonferroniPValue: bonferroni[position],
                benjaminiHochbergPValue: hochberg[position]
            )
        }
        return result
    }
}
