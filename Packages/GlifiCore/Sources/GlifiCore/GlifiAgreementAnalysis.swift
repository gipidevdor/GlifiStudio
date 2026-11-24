// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// `CohenKappaNominal-v1` result for two coders on the same units.
public struct GlifiCohenKappaResult: Equatable, Sendable {
    /// Versioned agreement-coefficient identifier.
    public static let identifier = "CohenKappaNominal-v1"

    /// `p_o`: the observed proportion of agreement.
    public let observedAgreement: Double
    /// `p_e = Σ_c p_1(c)p_2(c)`: the chance-expected proportion of agreement.
    public let expectedAgreement: Double
    /// `κ = (p_o-p_e)/(1-p_e)`.
    public let kappa: Double
    /// Number of coded units.
    public let unitCount: Int
}

/// `KrippendorffAlpha-v1` result (nominal disagreement function) over units
/// with two or more non-missing judgments.
public struct GlifiKrippendorffAlphaResult: Equatable, Sendable {
    /// Versioned agreement-coefficient identifier.
    public static let identifier = "KrippendorffAlpha-v1"

    /// `D_o`: observed disagreement over the coincidence matrix.
    public let observedDisagreement: Double
    /// `D_e`: expected disagreement over the coincidence matrix.
    public let expectedDisagreement: Double
    /// `α = 1 - D_o/D_e`.
    public let alpha: Double
    /// Units with at least two non-missing judgments, included in the computation.
    public let includedUnitCount: Int
}

/// Bounded, deterministic inter-coder agreement over nominal categories
/// (GS-MET-001-20).
public enum GlifiAgreementAnalysis {
    /// Computes `CohenKappaNominal-v1` for two coders over the same, aligned units.
    ///
    /// Throws when `p_e=1` (agreement is not defined relative to a chance
    /// baseline with no variability).
    public static func cohenKappa<Category: Hashable>(
        rater1: [Category],
        rater2: [Category]
    ) throws -> GlifiCohenKappaResult {
        guard !rater1.isEmpty, rater1.count == rater2.count else {
            throw agreementFailure("agreement.shape-mismatch", category: .invalidInput)
        }
        let unitCount = rater1.count
        let observedAgreement =
            Double(zip(rater1, rater2).filter { $0.0 == $0.1 }.count) / Double(unitCount)

        var counts1: [Category: Int] = [:]
        var counts2: [Category: Int] = [:]
        for category in rater1 { counts1[category, default: 0] += 1 }
        for category in rater2 { counts2[category, default: 0] += 1 }
        // L'ordine della somma è quello di prima apparizione nei giudizi: l'ordine di un insieme
        // hash non è riproducibile e cambierebbe l'ultima cifra del risultato.
        let categories = Self.firstAppearanceOrder(rater1 + rater2)
        let expectedAgreement = categories.reduce(0.0) { result, category in
            let proportion1 = Double(counts1[category] ?? 0) / Double(unitCount)
            let proportion2 = Double(counts2[category] ?? 0) / Double(unitCount)
            return result + proportion1 * proportion2
        }
        guard expectedAgreement < 1 else {
            throw agreementFailure("agreement.kappa-undefined", category: .insufficientData)
        }
        let kappa = (observedAgreement - expectedAgreement) / (1 - expectedAgreement)
        return GlifiCohenKappaResult(
            observedAgreement: observedAgreement,
            expectedAgreement: expectedAgreement,
            kappa: kappa,
            unitCount: unitCount
        )
    }

    /// Computes `KrippendorffAlpha-v1` with the nominal disagreement function
    /// (`δ²=0` for equal categories, `1` otherwise) over `units`, one row of
    /// coder judgments per unit (`nil` for a missing judgment).
    ///
    /// Units with fewer than two non-missing judgments are excluded, as
    /// required by the specification. Throws when no unit qualifies or when
    /// `D_e=0` (alpha is not defined).
    public static func krippendorffAlphaNominal<Category: Hashable>(
        _ units: [[Category?]]
    ) throws -> GlifiKrippendorffAlphaResult {
        guard !units.isEmpty else {
            throw agreementFailure("agreement.empty-units", category: .invalidInput)
        }

        // Ogni somma segue l'ordine di prima apparizione delle categorie nelle unità incluse:
        // l'ordine di un insieme hash non è riproducibile fra istanze e cambierebbe l'ultima
        // cifra dei risultati, e con essa il digest dell'Artifact.
        var index: [Category: Int] = [:]
        var ordered: [Category] = []
        var includedUnits: [[Int]] = []
        for unit in units {
            let judgments = unit.compactMap { $0 }
            guard judgments.count >= 2 else { continue }
            includedUnits.append(
                judgments.map { category in
                    if let existing = index[category] { return existing }
                    index[category] = ordered.count
                    ordered.append(category)
                    return ordered.count - 1
                })
        }
        let includedUnitCount = includedUnits.count
        guard includedUnitCount > 0 else {
            throw agreementFailure("agreement.insufficient-units", category: .insufficientData)
        }

        let categoryCount = ordered.count
        var coincidences = [[Double]](
            repeating: [Double](repeating: 0, count: categoryCount), count: categoryCount)
        for judgments in includedUnits {
            let unitTotal = judgments.count
            var unitCounts = [Int](repeating: 0, count: categoryCount)
            for code in judgments { unitCounts[code] += 1 }
            for category in 0..<categoryCount where unitCounts[category] > 0 {
                for otherCategory in 0..<categoryCount where unitCounts[otherCategory] > 0 {
                    let indicator = category == otherCategory ? 1 : 0
                    coincidences[category][otherCategory] +=
                        Double(unitCounts[category]) * Double(unitCounts[otherCategory] - indicator)
                        / Double(unitTotal - 1)
                }
            }
        }

        var marginals = [Double](repeating: 0, count: categoryCount)
        var total = 0.0
        for category in 0..<categoryCount {
            let rowSum = coincidences[category].reduce(0.0, +)
            marginals[category] = rowSum
            total += rowSum
        }
        guard total > 1 else {
            throw agreementFailure("agreement.degenerate-total", category: .insufficientData)
        }

        var observedWeighted = 0.0
        var observedTotal = 0.0
        var expectedWeighted = 0.0
        var expectedTotal = 0.0
        for category in 0..<categoryCount {
            for otherCategory in 0..<categoryCount {
                let disagreement: Double = category == otherCategory ? 0 : 1
                let observedCell = coincidences[category][otherCategory]
                observedWeighted += observedCell * disagreement
                observedTotal += observedCell

                let categoryMargin = marginals[category]
                let otherMargin = marginals[otherCategory]
                let expectedCell =
                    category == otherCategory
                    ? categoryMargin * (categoryMargin - 1) / (total - 1)
                    : categoryMargin * otherMargin / (total - 1)
                expectedWeighted += expectedCell * disagreement
                expectedTotal += expectedCell
            }
        }
        guard observedTotal > 0, expectedTotal > 0 else {
            throw agreementFailure("agreement.degenerate-total", category: .insufficientData)
        }
        let observedDisagreement = observedWeighted / observedTotal
        let expectedDisagreement = expectedWeighted / expectedTotal
        guard expectedDisagreement > 0 else {
            throw agreementFailure("agreement.alpha-undefined", category: .insufficientData)
        }
        let alpha = 1 - observedDisagreement / expectedDisagreement
        return GlifiKrippendorffAlphaResult(
            observedDisagreement: observedDisagreement,
            expectedDisagreement: expectedDisagreement,
            alpha: alpha,
            includedUnitCount: includedUnitCount
        )
    }
}

extension GlifiAgreementAnalysis {
    /// Distinct values in order of first appearance, a reproducible alternative to a hashed set.
    static func firstAppearanceOrder<Category: Hashable>(_ values: [Category]) -> [Category] {
        var seen: Set<Category> = []
        var ordered: [Category] = []
        for value in values where seen.insert(value).inserted { ordered.append(value) }
        return ordered
    }
}

func agreementFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
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
