// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One row of the rank-frequency observation.
public struct GlifiRankFrequencyRow: Codable, Equatable, Sendable {
    /// Ordinal rank, 1 for the most frequent type.
    public let rank: Int
    /// Normalized type.
    public let type: String
    /// Occurrences of the type.
    public let count: Int
}

/// One row of the frequency spectrum: `typeCount` types occur exactly `frequency` times.
public struct GlifiFrequencySpectrumRow: Codable, Equatable, Sendable {
    /// Occurrence count `k`.
    public let frequency: Int
    /// Number of types `V_k` observed exactly `k` times.
    public let typeCount: Int
}

/// Ordinary least squares `y = β₀ + β₁x` in log-log space.
public struct GlifiLogLinearFit: Codable, Equatable, Sendable {
    /// Points used by the fit.
    public let pointCount: Int
    /// Smallest predictor on the original scale (rank or token count).
    public let firstPredictor: Int
    /// Largest predictor on the original scale.
    public let lastPredictor: Int
    /// `β₀`.
    public let intercept: Double
    /// `β₁`.
    public let slope: Double
    /// Model coefficient `exp(β₀)` (`C` for Zipf, `K` for Heaps).
    public let coefficient: Double
    /// Model exponent (`α = -β₁` for Zipf, `β = β₁` for Heaps).
    public let exponent: Double
    /// `1 - SSE/SST`, `nil` when the response has no variance.
    public let rSquared: Double?
    /// `sqrt(SSE/n)` in log space.
    public let rootMeanSquaredLogError: Double
    /// `ln y - (β₀ + β₁ ln x)` per point, in predictor order.
    public let residuals: [Double]
    /// Whether the exponent lies in the domain of the model family.
    public let isExponentInModelDomain: Bool
}

/// A log-log fit or the reason it is not defined.
public struct GlifiLexicalLawFit: Codable, Equatable, Sendable {
    /// Versioned procedure identity.
    public let methodIdentifier: String
    /// The fit, `nil` with fewer than two points.
    public let fit: GlifiLogLinearFit?
    /// Stable reason when `fit` is `nil`.
    public let unavailableReason: String?
}

/// Pure GS-MET-001-05 observations and log-log fits.
public enum GlifiLexicalLaws {
    /// Zipf fitting procedure identity.
    public static let zipfIdentifier = "ZipfLogOLS-v1"
    /// Heaps fitting procedure identity.
    public static let heapsIdentifier = "HeapsLogOLS-v1"
    /// Checkpoint policy identity.
    public static let checkpointPolicyIdentifier = "GrowthCheckpoints-linear-v1"
    /// Admitted checkpoint counts.
    public static let checkpointCountRange = 2...10_000
    /// Admitted rank-frequency row limits.
    public static let rowLimitRange = 1...100_000

    /// Rank-frequency rows: descending count, ties by ascending UTF-8 type.
    public static func rankFrequency(_ tokens: [String]) -> [GlifiRankFrequencyRow] {
        var counts: [String: Int] = [:]
        for token in tokens {
            counts[token, default: 0] += 1
        }
        return counts.sorted {
            $0.value != $1.value
                ? $0.value > $1.value : $0.key.utf8.lexicographicallyPrecedes($1.key.utf8)
        }
        .enumerated()
        .map {
            GlifiRankFrequencyRow(
                rank: $0.offset + 1, type: $0.element.key, count: $0.element.value)
        }
    }

    /// Frequency spectrum in ascending `k`.
    public static func spectrum(_ rows: [GlifiRankFrequencyRow]) -> [GlifiFrequencySpectrumRow] {
        var types: [Int: Int] = [:]
        for row in rows {
            types[row.count, default: 0] += 1
        }
        return types.sorted { $0.key < $1.key }.map {
            GlifiFrequencySpectrumRow(frequency: $0.key, typeCount: $0.value)
        }
    }

    /// `GrowthCheckpoints-linear-v1`: `n_i = ⌈i·N/K⌉` for `i = 1…K`, duplicates removed.
    public static func checkpoints(tokenCount: Int, count: Int) throws -> [Int] {
        guard checkpointCountRange.contains(count) else {
            throw derivedAnalysisFailure("laws.invalid-checkpoints")
        }
        guard tokenCount > 0 else {
            return []
        }
        let (quotient, remainder) = tokenCount.quotientAndRemainder(dividingBy: count)
        var result: [Int] = []
        for index in 1...count {
            let checkpoint = index * quotient + (index * remainder + count - 1) / count
            if result.last != checkpoint {
                result.append(checkpoint)
            }
        }
        return result
    }

    /// `V(n)` at each checkpoint of the sequence.
    public static func growth(_ tokens: [String], checkpoints: [Int])
        -> [GlifiVocabularyGrowthPoint]
    {
        var seen: Set<String> = []
        var points: [GlifiVocabularyGrowthPoint] = []
        var next = checkpoints.makeIterator()
        var target = next.next()
        for (index, token) in tokens.enumerated() {
            guard let current = target else { break }
            seen.insert(token)
            if index + 1 == current {
                points.append(
                    GlifiVocabularyGrowthPoint(tokenCount: current, typeCount: seen.count))
                target = next.next()
            }
        }
        return points
    }

    /// `ZipfLogOLS-v1` on the ranks `firstRank…lastRank` of the rows that exist.
    public static func zipf(
        _ rows: [GlifiRankFrequencyRow], firstRank: Int, lastRank: Int?
    ) throws -> GlifiLexicalLawFit {
        guard firstRank >= 1, lastRank.map({ $0 > firstRank }) ?? true else {
            throw derivedAnalysisFailure("laws.invalid-rank-range")
        }
        let selected = rows.filter { $0.rank >= firstRank && $0.rank <= (lastRank ?? Int.max) }
        let fit = logLinearFit(selected.map { ($0.rank, $0.count) }) { -$0 }
        return GlifiLexicalLawFit(
            methodIdentifier: zipfIdentifier,
            fit: fit.map { $0.withDomain($0.exponent > 0) },
            unavailableReason: fit == nil ? "fit.insufficient-points" : nil
        )
    }

    /// `HeapsLogOLS-v1` on the recorded growth points.
    public static func heaps(_ points: [GlifiVocabularyGrowthPoint]) -> GlifiLexicalLawFit {
        let fit = logLinearFit(points.map { ($0.tokenCount, $0.typeCount) }) { $0 }
        return GlifiLexicalLawFit(
            methodIdentifier: heapsIdentifier,
            fit: fit.map { $0.withDomain($0.exponent > 0 && $0.exponent <= 1) },
            unavailableReason: fit == nil ? "fit.insufficient-points" : nil
        )
    }

    /// Centered OLS of `ln y` on `ln x`; `nil` with fewer than two distinct predictors.
    static func logLinearFit(
        _ points: [(x: Int, y: Int)], exponent: (Double) -> Double
    ) -> GlifiLogLinearFit? {
        let positive = points.filter { $0.x > 0 && $0.y > 0 }
        guard let first = positive.first, let last = positive.last, first.x != last.x else {
            return nil
        }
        let x = positive.map { log(Double($0.x)) }
        let y = positive.map { log(Double($0.y)) }
        let count = Double(positive.count)
        let meanX = x.reduce(0, +) / count
        let meanY = y.reduce(0, +) / count
        var sxx = 0.0
        var sxy = 0.0
        var syy = 0.0
        for (xi, yi) in zip(x, y) {
            sxx += (xi - meanX) * (xi - meanX)
            sxy += (xi - meanX) * (yi - meanY)
            syy += (yi - meanY) * (yi - meanY)
        }
        let slope = sxy / sxx
        let intercept = meanY - slope * meanX
        let residuals = zip(x, y).map { $1 - (intercept + slope * $0) }
        let sse = residuals.reduce(0) { $0 + $1 * $1 }
        return GlifiLogLinearFit(
            pointCount: positive.count,
            firstPredictor: first.x,
            lastPredictor: last.x,
            intercept: intercept,
            slope: slope,
            coefficient: exp(intercept),
            exponent: exponent(slope),
            rSquared: syy > 0 ? 1 - sse / syy : nil,
            rootMeanSquaredLogError: (sse / count).squareRoot(),
            residuals: residuals,
            isExponentInModelDomain: false
        )
    }
}

extension GlifiLogLinearFit {
    fileprivate func withDomain(_ inDomain: Bool) -> GlifiLogLinearFit {
        GlifiLogLinearFit(
            pointCount: pointCount, firstPredictor: firstPredictor, lastPredictor: lastPredictor,
            intercept: intercept, slope: slope, coefficient: coefficient, exponent: exponent,
            rSquared: rSquared, rootMeanSquaredLogError: rootMeanSquaredLogError,
            residuals: residuals, isExponentInModelDomain: inDomain)
    }
}

/// Declared parameters of `corpus-lexical-laws-v1`.
public struct GlifiLexicalLawsParameters: Codable, Equatable, Sendable {
    /// Number `K` of growth checkpoints.
    public let checkpointCount: Int
    /// First rank of the Zipf fit.
    public let zipfFirstRank: Int
    /// Last rank of the Zipf fit, `nil` for the last observed rank.
    public let zipfLastRank: Int?
    /// Maximum persisted rank-frequency rows.
    public let rankRowLimit: Int

    /// Defaults of GS-MET-001-05 § Variante implementata.
    public static let standard = GlifiLexicalLawsParameters(
        checkpointCount: 20, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 1_000)

    /// Creates parameters; validation happens when the analysis runs.
    public init(checkpointCount: Int, zipfFirstRank: Int, zipfLastRank: Int?, rankRowLimit: Int) {
        self.checkpointCount = checkpointCount
        self.zipfFirstRank = zipfFirstRank
        self.zipfLastRank = zipfLastRank
        self.rankRowLimit = rankRowLimit
    }

    /// Throws the typed failure of the first invalid parameter.
    public func validate() throws {
        guard GlifiLexicalLaws.checkpointCountRange.contains(checkpointCount) else {
            throw derivedAnalysisFailure("laws.invalid-checkpoints")
        }
        guard zipfFirstRank >= 1, zipfLastRank.map({ $0 > zipfFirstRank }) ?? true else {
            throw derivedAnalysisFailure("laws.invalid-rank-range")
        }
        guard GlifiLexicalLaws.rowLimitRange.contains(rankRowLimit) else {
            throw derivedAnalysisFailure("laws.invalid-row-limit")
        }
    }
}

/// Observations, Zipf and Heaps fits of the pooled lexical sequence of a group.
public struct GlifiCorpusLexicalLawsAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-lexical-laws.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-lexical-laws-v1"
    /// Caveat attached to every fit.
    public static let fitCaveatIdentifier = "caveat.lexical-law-fit-is-descriptive-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Token-to-type mapping.
    public let typeMappingIdentifier: String
    /// Order of the pooled sequence.
    public let sequencePolicy: String
    /// Checkpoint policy of the growth curve.
    public let checkpointPolicy: String
    /// Declared parameters.
    public let parameters: GlifiLexicalLawsParameters
    /// Analyzed documents in canonical order.
    public let sourceRevisionIDs: [String]
    /// Tokens `N` of the pooled sequence.
    public let tokenCount: Int
    /// Types `V` of the pooled sequence.
    public let typeCount: Int
    /// First `rankRowLimit` rank-frequency rows.
    public let rankFrequency: [GlifiRankFrequencyRow]
    /// Whether rows beyond `rankRowLimit` were not persisted.
    public let isRankFrequencyTruncated: Bool
    /// Complete frequency spectrum.
    public let spectrum: [GlifiFrequencySpectrumRow]
    /// Vocabulary growth at the checkpoints.
    public let growth: [GlifiVocabularyGrowthPoint]
    /// `ZipfLogOLS-v1` over all observed ranks in the declared range.
    public let zipf: GlifiLexicalLawFit
    /// `HeapsLogOLS-v1` over the growth checkpoints.
    public let heaps: GlifiLexicalLawFit
    /// Fits describe the observed interval; they do not establish a law or a mechanism.
    public let fitCaveat: String

    /// Analyzes documents given as normalized lexical sequences.
    public init(
        sequences: [(SourceRevisionID, [String])], parameters: GlifiLexicalLawsParameters
    ) throws {
        try parameters.validate()
        guard !sequences.isEmpty else {
            throw derivedAnalysisFailure("laws.insufficient-sources", category: .insufficientData)
        }
        let ordered = sequences.sorted { $0.0.canonicalValue < $1.0.canonicalValue }
        let pooled = ordered.flatMap(\.1)
        let rows = GlifiLexicalLaws.rankFrequency(pooled)
        let checkpoints = try GlifiLexicalLaws.checkpoints(
            tokenCount: pooled.count, count: parameters.checkpointCount)
        analysisIdentifier = Self.analysisIdentifier
        typeMappingIdentifier = "it-token-v1-nfc-lowercase-v1"
        sequencePolicy = "source-revision-order-concatenation-v1"
        checkpointPolicy = GlifiLexicalLaws.checkpointPolicyIdentifier
        self.parameters = parameters
        sourceRevisionIDs = ordered.map(\.0.canonicalValue)
        tokenCount = pooled.count
        typeCount = rows.count
        rankFrequency = Array(rows.prefix(parameters.rankRowLimit))
        isRankFrequencyTruncated = rows.count > parameters.rankRowLimit
        spectrum = GlifiLexicalLaws.spectrum(rows)
        growth = GlifiLexicalLaws.growth(pooled, checkpoints: checkpoints)
        zipf = try GlifiLexicalLaws.zipf(
            rows, firstRank: parameters.zipfFirstRank, lastRank: parameters.zipfLastRank)
        heaps = GlifiLexicalLaws.heaps(growth)
        fitCaveat = Self.fitCaveatIdentifier
    }
}
