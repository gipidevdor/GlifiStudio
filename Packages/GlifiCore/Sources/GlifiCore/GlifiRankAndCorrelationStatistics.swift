// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Result of a correlation test over paired quantitative observations.
public struct GlifiCorrelationResult: Equatable, Sendable {
    /// `PearsonR-v1`.
    public static let pearsonIdentifier = "PearsonR-v1"
    /// `SpearmanRho-v1`.
    public static let spearmanIdentifier = "SpearmanRho-v1"

    /// Versioned method identity.
    public let methodIdentifier: String
    /// Correlation coefficient in `[-1, 1]`.
    public let coefficient: Double
    /// Number of complete pairs.
    public let sampleCount: Int
    /// `t = r·sqrt((n-2)/(1-r²))`, infinite for a perfect correlation.
    public let tStatistic: Double
    /// `n-2`.
    public let degreesOfFreedom: Int
    /// Asymptotic Student-t p-value for the declared alternative.
    public let pValue: Double
    /// Alternative hypothesis the p-value was computed against.
    public let alternative: GlifiAlternativeHypothesis
}

/// Declared computation of the `MannWhitneyU-v1` p-value.
public enum GlifiMannWhitneyMethod: Sendable, Equatable {
    /// Exact null distribution of `U`; requires no ties and `n₁+n₂ ≤ 50`.
    case exact
    /// Normal approximation with tie correction and an explicit continuity correction.
    case asymptotic(continuityCorrection: Bool)
}

/// `MannWhitneyU-v1` result for two independent samples.
public struct GlifiMannWhitneyUResult: Equatable, Sendable {
    /// Versioned test identifier.
    public static let identifier = "MannWhitneyU-v1"

    /// `U₁ = R₁ - n₁(n₁+1)/2` with midranks over the pooled sample.
    public let u1: Double
    /// `U₂ = n₁n₂ - U₁`.
    public let u2: Double
    /// Size of the first sample.
    public let firstSampleCount: Int
    /// Size of the second sample.
    public let secondSampleCount: Int
    /// Declared p-value computation.
    public let method: GlifiMannWhitneyMethod
    /// Standard-normal statistic, present only for the asymptotic method.
    public let zStatistic: Double?
    /// P-value for the declared alternative.
    public let pValue: Double
    /// Alternative hypothesis: `greater` means the first sample tends to be larger.
    public let alternative: GlifiAlternativeHypothesis
}

/// `KruskalWallis-v1` result over `k≥2` independent groups.
public struct GlifiKruskalWallisResult: Equatable, Sendable {
    /// Versioned test identifier.
    public static let identifier = "KruskalWallis-v1"

    /// `H = 12/[N(N+1)]·ΣR_g²/n_g - 3(N+1)` before tie correction.
    public let hStatistic: Double
    /// Tie-correction factor `C = 1 - Σ(t³-t)/(N³-N)`.
    public let tieCorrection: Double
    /// `H/C`, the statistic used for the p-value.
    public let correctedHStatistic: Double
    /// `k-1`.
    public let degreesOfFreedom: Int
    /// Upper-tail asymptotic chi-square p-value.
    public let pValue: Double
}

extension GlifiStatisticalFoundation {
    /// Largest pooled size for which the exact `MannWhitneyU-v1` distribution is enumerated.
    public static let maximumExactMannWhitneySampleCount = 50

    /// Computes `PearsonR-v1`: `r = Σ(x-x̄)(y-ȳ)/sqrt[Σ(x-x̄)²Σ(y-ȳ)²]`.
    ///
    /// Requires `n≥3` finite pairs and positive variance in both variables.
    public static func pearsonCorrelation(
        _ x: [Double],
        _ y: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> GlifiCorrelationResult {
        try validatePairs(x, y)
        return try correlation(
            x,
            y,
            identifier: GlifiCorrelationResult.pearsonIdentifier,
            alternative: alternative
        )
    }

    /// Computes `SpearmanRho-v1`: Pearson correlation of the midranks.
    ///
    /// The p-value is the asymptotic Student-t approximation with `n-2` degrees of freedom.
    public static func spearmanCorrelation(
        _ x: [Double],
        _ y: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> GlifiCorrelationResult {
        try validatePairs(x, y)
        return try correlation(
            midranks(x).ranks,
            midranks(y).ranks,
            identifier: GlifiCorrelationResult.spearmanIdentifier,
            alternative: alternative
        )
    }

    /// Computes `MannWhitneyU-v1` with the declared alternative and p-value method.
    public static func mannWhitneyU(
        _ sample1: [Double],
        _ sample2: [Double],
        alternative: GlifiAlternativeHypothesis = .twoSided,
        method: GlifiMannWhitneyMethod = .asymptotic(continuityCorrection: true)
    ) throws -> GlifiMannWhitneyUResult {
        guard !sample1.isEmpty, !sample2.isEmpty else {
            throw rankStatisticsFailure("statistics.empty-group")
        }
        guard sample1.allSatisfy(\.isFinite), sample2.allSatisfy(\.isFinite) else {
            throw rankStatisticsFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let first = Double(sample1.count)
        let second = Double(sample2.count)
        let pooled = midranks(sample1 + sample2)
        let firstRankSum = pooled.ranks.prefix(sample1.count).reduce(0, +)
        let u1 = firstRankSum - first * (first + 1) / 2
        let u2 = first * second - u1

        switch method {
        case .exact:
            guard pooled.tieGroupSizes.isEmpty else {
                throw rankStatisticsFailure("statistics.exact-requires-no-ties")
            }
            guard sample1.count + sample2.count <= maximumExactMannWhitneySampleCount else {
                throw rankStatisticsFailure(
                    "statistics.exact-sample-too-large",
                    category: .invalidInput
                )
            }
            let distribution = mannWhitneyDistribution(sample1.count, sample2.count)
            let total = distribution.reduce(0, +)
            let index = Int(u1.rounded())
            let lower = distribution.prefix(index + 1).reduce(0, +) / total
            let upper = distribution.suffix(from: index).reduce(0, +) / total
            let pValue: Double
            switch alternative {
            case .less: pValue = lower
            case .greater: pValue = upper
            case .twoSided: pValue = min(1, 2 * min(lower, upper))
            }
            return GlifiMannWhitneyUResult(
                u1: u1,
                u2: u2,
                firstSampleCount: sample1.count,
                secondSampleCount: sample2.count,
                method: method,
                zStatistic: nil,
                pValue: min(max(pValue, 0), 1),
                alternative: alternative
            )
        case .asymptotic(let continuityCorrection):
            let count = first + second
            let tieTerm = pooled.tieGroupSizes.reduce(0.0) {
                $0 + Double($1) * Double($1) * Double($1) - Double($1)
            }
            let variance = first * second / 12 * ((count + 1) - tieTerm / (count * (count - 1)))
            guard variance > 0 else {
                throw rankStatisticsFailure("statistics.degenerate-rank-variance")
            }
            let deviation = u1 - first * second / 2
            let correction = continuityShift(
                deviation,
                enabled: continuityCorrection,
                alternative: alternative
            )
            let z = (deviation + correction) / variance.squareRoot()
            return GlifiMannWhitneyUResult(
                u1: u1,
                u2: u2,
                firstSampleCount: sample1.count,
                secondSampleCount: sample2.count,
                method: method,
                zStatistic: z,
                pValue: normalPValue(z, alternative: alternative),
                alternative: alternative
            )
        }
    }

    /// Computes `KruskalWallis-v1` with tie correction and an asymptotic chi-square p-value.
    public static func kruskalWallis(_ groups: [[Double]]) throws -> GlifiKruskalWallisResult {
        guard groups.count >= 2 else {
            throw rankStatisticsFailure("statistics.insufficient-group-count")
        }
        guard groups.allSatisfy({ !$0.isEmpty }) else {
            throw rankStatisticsFailure("statistics.empty-group")
        }
        guard groups.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw rankStatisticsFailure("statistics.non-finite-value", category: .invalidInput)
        }
        let pooled = midranks(groups.flatMap { $0 })
        let count = Double(pooled.ranks.count)
        var offset = 0
        var rankTerm = 0.0
        for group in groups {
            let sum = pooled.ranks[offset..<(offset + group.count)].reduce(0, +)
            rankTerm += sum * sum / Double(group.count)
            offset += group.count
        }
        let h = 12 / (count * (count + 1)) * rankTerm - 3 * (count + 1)
        let tieTerm = pooled.tieGroupSizes.reduce(0.0) {
            $0 + Double($1) * Double($1) * Double($1) - Double($1)
        }
        let correction = 1 - tieTerm / (count * count * count - count)
        guard correction > 0 else {
            throw rankStatisticsFailure("statistics.degenerate-rank-variance")
        }
        let corrected = h / correction
        let degrees = groups.count - 1
        let pValue = try chiSquareUpperTailProbability(corrected, degreesOfFreedom: degrees)
        return GlifiKruskalWallisResult(
            hStatistic: h,
            tieCorrection: correction,
            correctedHStatistic: corrected,
            degreesOfFreedom: degrees,
            pValue: min(max(pValue, 0), 1)
        )
    }

    /// `Bonferroni-v1`: `p_adj = min(1, m·p)`, preserving the input order.
    public static func bonferroniAdjustedPValues(_ pValues: [Double]) throws -> [Double] {
        try validateProbabilities(pValues)
        let familySize = Double(pValues.count)
        return pValues.map { min(1, familySize * $0) }
    }

    /// `BenjaminiHochberg-v1`: step-up adjusted q-values, preserving the input order.
    public static func benjaminiHochbergAdjustedPValues(
        _ pValues: [Double]
    ) throws -> [Double] {
        try validateProbabilities(pValues)
        let familySize = pValues.count
        let order = pValues.indices.sorted {
            pValues[$0] == pValues[$1] ? $0 < $1 : pValues[$0] < pValues[$1]
        }
        var adjusted = [Double](repeating: 1, count: familySize)
        var running = 1.0
        for position in stride(from: familySize - 1, through: 0, by: -1) {
            let index = order[position]
            running = min(running, Double(familySize) * pValues[index] / Double(position + 1))
            adjusted[index] = min(1, running)
        }
        return adjusted
    }

    /// Midranks of `values` and the sizes of the tie groups larger than one.
    static func midranks(_ values: [Double]) -> (ranks: [Double], tieGroupSizes: [Int]) {
        let order = values.indices.sorted {
            values[$0] == values[$1] ? $0 < $1 : values[$0] < values[$1]
        }
        var ranks = [Double](repeating: 0, count: values.count)
        var tieGroupSizes: [Int] = []
        var start = 0
        while start < order.count {
            var end = start
            while end + 1 < order.count, values[order[end + 1]] == values[order[start]] {
                end += 1
            }
            let rank = Double(start + end) / 2 + 1
            for position in start...end { ranks[order[position]] = rank }
            if end > start { tieGroupSizes.append(end - start + 1) }
            start = end + 1
        }
        return (ranks, tieGroupSizes)
    }

    /// Number of arrangements of each `U` value for sample sizes `m` and `n`.
    ///
    /// Uses `f(m,n,u) = f(m-1,n,u-n) + f(m,n-1,u)`, which counts the placements of the
    /// largest observation in the first or second sample.
    static func mannWhitneyDistribution(_ m: Int, _ n: Int) -> [Double] {
        var table = [[[Double]]](
            repeating: [[Double]](repeating: [], count: n + 1),
            count: m + 1
        )
        for i in 0...m {
            for j in 0...n {
                if i == 0 || j == 0 {
                    table[i][j] = [1]
                    continue
                }
                var counts = [Double](repeating: 0, count: i * j + 1)
                for (u, value) in table[i - 1][j].enumerated() { counts[u + j] += value }
                for (u, value) in table[i][j - 1].enumerated() { counts[u] += value }
                table[i][j] = counts
            }
        }
        return table[m][n]
    }

    private static func validatePairs(_ x: [Double], _ y: [Double]) throws {
        guard x.count == y.count else {
            throw rankStatisticsFailure(
                "statistics.paired-length-mismatch",
                category: .invalidInput
            )
        }
        guard x.count >= 3 else {
            throw rankStatisticsFailure("statistics.insufficient-sample-size")
        }
        guard x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite) else {
            throw rankStatisticsFailure("statistics.non-finite-value", category: .invalidInput)
        }
    }

    private static func correlation(
        _ x: [Double],
        _ y: [Double],
        identifier: String,
        alternative: GlifiAlternativeHypothesis
    ) throws -> GlifiCorrelationResult {
        let count = Double(x.count)
        // Translate by an observed anchor before taking means: scaling raw values alone
        // cannot preserve a small variance in the presence of a large common offset.
        let scaleX = try correlationScale(x)
        let scaleY = try correlationScale(y)
        let meanX = x.reduce(0.0) { $0 + correlationCoordinate($1, scale: scaleX) } / count
        let meanY = y.reduce(0.0) { $0 + correlationCoordinate($1, scale: scaleY) } / count
        var sumXY = 0.0
        var sumXX = 0.0
        var sumYY = 0.0
        for (valueX, valueY) in zip(x, y) {
            let deviationX = correlationCoordinate(valueX, scale: scaleX) - meanX
            let deviationY = correlationCoordinate(valueY, scale: scaleY) - meanY
            sumXY += deviationX * deviationY
            sumXX += deviationX * deviationX
            sumYY += deviationY * deviationY
        }
        guard sumXX > 0, sumYY > 0 else {
            throw rankStatisticsFailure("statistics.non-positive-variance")
        }
        let coefficient = min(max(sumXY / (sumXX * sumYY).squareRoot(), -1), 1)
        let degrees = x.count - 2
        let denominator = 1 - coefficient * coefficient
        let statistic: Double
        let pValue: Double
        if denominator <= 0 {
            statistic = coefficient > 0 ? .infinity : -.infinity
            switch alternative {
            case .twoSided: pValue = 0
            case .greater: pValue = coefficient > 0 ? 0 : 1
            case .less: pValue = coefficient > 0 ? 1 : 0
            }
        } else {
            statistic = coefficient * (Double(degrees) / denominator).squareRoot()
            pValue = try tDistributionPValue(
                statistic: statistic,
                degreesOfFreedom: Double(degrees),
                alternative: alternative
            )
        }
        return GlifiCorrelationResult(
            methodIdentifier: identifier,
            coefficient: coefficient,
            sampleCount: x.count,
            tStatistic: statistic,
            degreesOfFreedom: degrees,
            pValue: pValue,
            alternative: alternative
        )
    }

    private static func correlationScale(
        _ values: [Double]
    ) throws -> (input: Double, offset: Double, anchor: Double) {
        let anchor = values.first ?? 0
        let largest = values.reduce(0.0) { max($0, abs($1)) }
        // Opposite signs close to binary64's maximum may overflow subtraction. Only
        // that case needs a preliminary common power-of-two scale before translation.
        let needsPrescaling = values.contains { !($0 - anchor).isFinite }
        let input =
            needsPrescaling
            ? Double(sign: .plus, exponent: largest.exponent, significand: 1) : 1
        let scaledAnchor = anchor / input
        let largestOffset = values.reduce(0.0) { max($0, abs($1 / input - scaledAnchor)) }
        guard largestOffset > 0 else {
            throw rankStatisticsFailure("statistics.non-positive-variance")
        }
        return (
            input, Double(sign: .plus, exponent: largestOffset.exponent, significand: 1),
            scaledAnchor
        )
    }

    private static func correlationCoordinate(
        _ value: Double, scale: (input: Double, offset: Double, anchor: Double)
    ) -> Double {
        (value / scale.input - scale.anchor) / scale.offset
    }

    private static func continuityShift(
        _ deviation: Double,
        enabled: Bool,
        alternative: GlifiAlternativeHypothesis
    ) -> Double {
        guard enabled else { return 0 }
        switch alternative {
        case .twoSided:
            if deviation == 0 { return 0 }
            return deviation > 0 ? -0.5 : 0.5
        case .greater:
            return -0.5
        case .less:
            return 0.5
        }
    }

    private static func normalPValue(
        _ z: Double,
        alternative: GlifiAlternativeHypothesis
    ) -> Double {
        let root = 2.0.squareRoot()
        let value: Double
        switch alternative {
        case .twoSided: value = erfc(abs(z) / root)
        case .greater: value = 0.5 * erfc(z / root)
        case .less: value = 0.5 * erfc(-z / root)
        }
        return min(max(value, 0), 1)
    }

    private static func validateProbabilities(_ pValues: [Double]) throws {
        guard !pValues.isEmpty else {
            throw rankStatisticsFailure("statistics.empty-family")
        }
        guard pValues.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw rankStatisticsFailure("statistics.invalid-p-value", category: .invalidInput)
        }
    }
}

private func rankStatisticsFailure(
    _ code: String,
    category: GlifiFailureCategory = .insufficientData
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}
