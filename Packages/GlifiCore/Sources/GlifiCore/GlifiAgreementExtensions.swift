// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Measurement level of Krippendorff's alpha, which selects the difference function `δ²`.
public enum GlifiMeasurementLevel: String, Codable, Equatable, Sendable {
    /// `δ² = [c ≠ k]`.
    case nominal
    /// `δ² = (Σ_{g=c}^{k} n_g - (n_c+n_k)/2)²` over sorted values.
    case ordinal
    /// `δ² = (c - k)²`.
    case interval
    /// `δ² = ((c - k)/(c + k))²`, values non-negative.
    case ratio
}

/// `KrippendorffAlpha-v2` result for a declared level.
public struct GlifiLeveledAlphaResult: Codable, Equatable, Sendable {
    /// Versioned identity.
    public static let identifier = "KrippendorffAlpha-v2"

    /// Level used.
    public let level: GlifiMeasurementLevel
    /// `α = 1 - (n-1)·Σ o_ck δ²_ck / Σ n_c n_k δ²_ck`.
    public let alpha: Double
    /// Pairable values `n`.
    public let pairableValueCount: Int
    /// Units with at least two values.
    public let includedUnitCount: Int
}

/// `FleissKappa-v1` result for complete ratings by `m ≥ 2` coders.
public struct GlifiFleissKappaResult: Codable, Equatable, Sendable {
    /// Versioned identity.
    public static let identifier = "FleissKappa-v1"

    /// `P̄`: mean per-unit agreement.
    public let observedAgreement: Double
    /// `P̄_e = Σ p_j²`.
    public let expectedAgreement: Double
    /// `κ = (P̄ - P̄_e)/(1 - P̄_e)`.
    public let kappa: Double
}

/// Unit-resampling percentile interval of alpha.
public struct GlifiAlphaInterval: Codable, Equatable, Sendable {
    /// `AlphaUnitBootstrap-v1` identity.
    public static let identifier = "AlphaUnitBootstrap-v1"

    /// Confidence level.
    public let confidenceLevel: Double
    /// Lower type-7 quantile.
    public let lower: Double
    /// Upper type-7 quantile.
    public let upper: Double
    /// Resamples with a defined alpha.
    public let validResampleCount: Int
    /// Requested resamples.
    public let resampleCount: Int
    /// Recorded seed.
    public let seed: UInt64
}

extension GlifiAgreementAnalysis {
    /// Computes Krippendorff's alpha on numeric values at the declared level.
    ///
    /// `units[u][c]` is coder `c`'s value for unit `u`, `nil` when missing; units with fewer
    /// than two values are not pairable and are ignored.
    public static func krippendorffAlpha(
        _ units: [[Double?]],
        level: GlifiMeasurementLevel
    ) throws -> GlifiLeveledAlphaResult {
        guard units.allSatisfy({ $0.allSatisfy { $0.map(\.isFinite) ?? true } }) else {
            throw agreementFailure("agreement.non-finite-value", category: .invalidInput)
        }
        if level == .ratio, units.contains(where: { $0.contains { ($0 ?? 0) < 0 } }) {
            throw agreementFailure("agreement.negative-ratio-value", category: .invalidInput)
        }
        let values = Array(Set(units.flatMap { $0.compactMap { $0 } })).sorted()
        let index = Dictionary(uniqueKeysWithValues: values.enumerated().map { ($1, $0) })
        var coincidences = [[Double]](
            repeating: [Double](repeating: 0, count: values.count),
            count: values.count
        )
        var included = 0
        for unit in units {
            let present = unit.compactMap { $0 }
            guard present.count >= 2 else { continue }
            included += 1
            let weight = 1 / Double(present.count - 1)
            for (first, left) in present.enumerated() {
                for (second, right) in present.enumerated() where first != second {
                    guard let a = index[left], let b = index[right] else { continue }
                    coincidences[a][b] += weight
                }
            }
        }
        let marginals = coincidences.map { $0.reduce(0, +) }
        let total = marginals.reduce(0, +)
        guard included > 0, total > 1 else {
            throw agreementFailure("agreement.insufficient-units", category: .insufficientData)
        }
        func delta(_ a: Int, _ b: Int) -> Double {
            switch level {
            case .nominal:
                return a == b ? 0 : 1
            case .interval:
                return (values[a] - values[b]) * (values[a] - values[b])
            case .ratio:
                let sum = values[a] + values[b]
                return sum == 0 ? 0 : pow((values[a] - values[b]) / sum, 2)
            case .ordinal:
                let low = min(a, b)
                let high = max(a, b)
                let span = marginals[low...high].reduce(0, +) - (marginals[a] + marginals[b]) / 2
                return span * span
            }
        }
        var observed = 0.0
        var expected = 0.0
        for a in values.indices {
            for b in values.indices {
                let difference = delta(a, b)
                observed += coincidences[a][b] * difference
                expected += marginals[a] * marginals[b] * difference
            }
        }
        guard expected > 0 else {
            throw agreementFailure("agreement.alpha-undefined", category: .insufficientData)
        }
        return GlifiLeveledAlphaResult(
            level: level,
            alpha: 1 - (total - 1) * observed / expected,
            pairableValueCount: Int(total.rounded()),
            includedUnitCount: included
        )
    }

    /// Computes `FleissKappa-v1`; every unit must be rated by the same `m ≥ 2` coders.
    public static func fleissKappa(_ units: [[String]]) throws -> GlifiFleissKappaResult {
        guard let raters = units.first?.count, raters >= 2, !units.isEmpty,
            units.allSatisfy({ $0.count == raters })
        else {
            throw agreementFailure("agreement.incomplete-ratings", category: .invalidInput)
        }
        let categories = Array(Set(units.flatMap { $0 })).sorted()
        let m = Double(raters)
        var totals = [String: Double]()
        var observed = 0.0
        for unit in units {
            var counts = [String: Double]()
            for label in unit { counts[label, default: 0] += 1 }
            // Somma in ordine di etichetta: l'ordine dei valori di un dizionario non è riproducibile.
            let squares = counts.keys.sorted().reduce(0.0) {
                let count = counts[$1] ?? 0
                return $0 + count * count
            }
            observed += (squares - m) / (m * (m - 1))
            for (label, count) in counts { totals[label, default: 0] += count }
        }
        let meanObserved = observed / Double(units.count)
        let expected = categories.reduce(0.0) {
            let share = (totals[$1] ?? 0) / (Double(units.count) * m)
            return $0 + share * share
        }
        guard expected < 1 else {
            throw agreementFailure("agreement.kappa-undefined", category: .insufficientData)
        }
        return GlifiFleissKappaResult(
            observedAgreement: meanObserved,
            expectedAgreement: expected,
            kappa: (meanObserved - expected) / (1 - expected)
        )
    }

    /// Percentile interval of alpha from resampling units with replacement.
    public static func krippendorffAlphaInterval(
        _ units: [[Double?]],
        level: GlifiMeasurementLevel,
        confidenceLevel: Double = 0.95,
        resampleCount: Int = 1_000,
        seed: UInt64
    ) throws -> GlifiAlphaInterval {
        guard confidenceLevel > 0, confidenceLevel < 1,
            (1...GlifiStatisticalFoundation.maximumResampleCount).contains(resampleCount),
            !units.isEmpty
        else {
            throw agreementFailure("agreement.invalid-resampling", category: .invalidInput)
        }
        var generator = GlifiSplitMix64(seed: seed)
        var alphas: [Double] = []
        for iteration in 0..<resampleCount {
            if iteration.isMultiple(of: 256) { try Task.checkCancellation() }
            let sample = units.indices.map { _ in units[generator.index(below: units.count)] }
            if let value = try? krippendorffAlpha(sample, level: level).alpha, value.isFinite {
                alphas.append(value)
            }
        }
        guard alphas.count >= 2 else {
            throw agreementFailure("agreement.alpha-undefined", category: .insufficientData)
        }
        alphas.sort()
        let tail = (1 - confidenceLevel) / 2
        return GlifiAlphaInterval(
            confidenceLevel: confidenceLevel,
            lower: try GlifiStatisticalFoundation.quantileType7(alphas, probability: tail),
            upper: try GlifiStatisticalFoundation.quantileType7(alphas, probability: 1 - tail),
            validResampleCount: alphas.count,
            resampleCount: resampleCount,
            seed: seed
        )
    }
}

/// `FisherExact2x2-v1` result.
public struct GlifiFisherExactResult: Codable, Equatable, Sendable {
    /// Versioned identity.
    public static let identifier = "FisherExact2x2-v1"

    /// Hypergeometric probability of the observed table.
    public let tableProbability: Double
    /// P-value for the declared alternative (`greater`: association of the first cell).
    public let pValue: Double
    /// Conditional-free sample odds ratio `ad/(bc)`, `nil` when undefined.
    public let sampleOddsRatio: Double?
}

/// `ChiSquareMonteCarlo-v1` result: fixed-margin permutation p-value of Pearson's χ².
public struct GlifiMonteCarloChiSquareResult: Codable, Equatable, Sendable {
    /// Versioned identity.
    public static let identifier = "ChiSquareMonteCarlo-v1"

    /// Observed χ².
    public let statistic: Double
    /// `(1 + #{χ²* ≥ χ²})/(B + 1)`.
    public let pValue: Double
    /// Simulated tables `B`.
    public let simulationCount: Int
    /// Recorded seed.
    public let seed: UInt64
}

extension GlifiStatisticalFoundation {
    /// Computes `FisherExact2x2-v1` on `[[a, b], [c, d]]`.
    ///
    /// The two-sided p-value sums the probabilities of tables with the same margins whose
    /// probability does not exceed the observed one by more than a relative `1e-7`, as in R.
    public static func fisherExact(
        _ table: [[Int]],
        alternative: GlifiAlternativeHypothesis = .twoSided
    ) throws -> GlifiFisherExactResult {
        guard table.count == 2, table.allSatisfy({ $0.count == 2 && $0.allSatisfy { $0 >= 0 } })
        else {
            throw exactTestFailure("contingency.invalid-2x2", category: .invalidInput)
        }
        let a = table[0][0]
        let b = table[0][1]
        let c = table[1][0]
        let d = table[1][1]
        let row = a + b
        let column = a + c
        let total = a + b + c + d
        guard total > 0 else {
            throw exactTestFailure("contingency.empty-table", category: .insufficientData)
        }
        let lower = max(0, column - (total - row))
        let upper = min(row, column)
        func logChoose(_ n: Int, _ k: Int) -> Double {
            lgamma(Double(n + 1)) - lgamma(Double(k + 1)) - lgamma(Double(n - k + 1))
        }
        let denominator = logChoose(total, column)
        let probabilities = (lower...upper).map {
            exp(logChoose(row, $0) + logChoose(total - row, column - $0) - denominator)
        }
        let observed = probabilities[a - lower]
        let pValue: Double
        switch alternative {
        case .greater:
            pValue = probabilities[(a - lower)...].reduce(0, +)
        case .less:
            pValue = probabilities[...(a - lower)].reduce(0, +)
        case .twoSided:
            pValue = probabilities.filter { $0 <= observed * (1 + 1e-7) }.reduce(0, +)
        }
        return GlifiFisherExactResult(
            tableProbability: observed,
            pValue: min(max(pValue, 0), 1),
            sampleOddsRatio: b * c == 0 ? nil : Double(a * d) / Double(b * c)
        )
    }

    /// Computes `ChiSquareMonteCarlo-v1` by permuting column labels of individual
    /// observations, which samples tables uniformly under fixed margins.
    public static func monteCarloChiSquare(
        _ table: [[Int]],
        simulationCount: Int = 2_000,
        seed: UInt64
    ) throws -> GlifiMonteCarloChiSquareResult {
        guard let width = table.first?.count, table.count >= 2, width >= 2,
            table.allSatisfy({ $0.count == width && $0.allSatisfy { $0 >= 0 } })
        else {
            throw exactTestFailure("contingency.invalid-table", category: .invalidInput)
        }
        guard (1...maximumResampleCount).contains(simulationCount) else {
            throw exactTestFailure("contingency.invalid-simulation", category: .invalidInput)
        }
        let rowTotals = table.map { $0.reduce(0, +) }
        let columnTotals = (0..<width).map { column in table.reduce(0) { $0 + $1[column] } }
        let total = rowTotals.reduce(0, +)
        guard total > 0, total <= 1_000_000,
            rowTotals.allSatisfy({ $0 > 0 }), columnTotals.allSatisfy({ $0 > 0 })
        else {
            throw exactTestFailure("contingency.degenerate-margins", category: .insufficientData)
        }
        func statistic(_ cells: [[Int]]) -> Double {
            var value = 0.0
            for row in cells.indices {
                for column in 0..<width {
                    let expected =
                        Double(rowTotals[row]) * Double(columnTotals[column]) / Double(total)
                    let difference = Double(cells[row][column]) - expected
                    value += difference * difference / expected
                }
            }
            return value
        }
        let observed = statistic(table)
        let rowLabels = rowTotals.enumerated().flatMap {
            Array(repeating: $0.offset, count: $0.element)
        }
        var columnLabels = columnTotals.enumerated().flatMap {
            Array(repeating: $0.offset, count: $0.element)
        }
        var generator = GlifiSplitMix64(seed: seed)
        var extreme = 0
        for iteration in 0..<simulationCount {
            if iteration.isMultiple(of: 256) { try Task.checkCancellation() }
            for position in stride(from: columnLabels.count - 1, to: 0, by: -1) {
                columnLabels.swapAt(position, generator.index(below: position + 1))
            }
            var cells = [[Int]](repeating: [Int](repeating: 0, count: width), count: table.count)
            for (row, column) in zip(rowLabels, columnLabels) { cells[row][column] += 1 }
            if statistic(cells) >= observed * (1 - 1e-12) { extreme += 1 }
        }
        return GlifiMonteCarloChiSquareResult(
            statistic: observed,
            pValue: Double(extreme + 1) / Double(simulationCount + 1),
            simulationCount: simulationCount,
            seed: seed
        )
    }
}

private func exactTestFailure(
    _ code: String,
    category: GlifiFailureCategory
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
