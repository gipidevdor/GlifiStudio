// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Document typicality scores in KH Coder's public A.6.1 definition.
public enum GlifiKHDocumentScoreMode: String, Codable, CaseIterable, Sendable {
    /// Sum of selected term counts divided by the complete document exposure.
    case tf
    /// Relative term frequency multiplied by unsmoothed base-ten IDF.
    case tfIdf
    /// Relative term frequency divided by base-ten IDF, substituting one for zero IDF.
    case tfDividedByIdf

    /// Versioned formula, distinct from natural-log and smoothed TF-IDF.
    public var methodIdentifier: String {
        switch self {
        case .tf: "KH-document-tf-v1"
        case .tfIdf: "KH-document-tf-log10-idf-v1"
        case .tfDividedByIdf: "KH-document-tf-divided-by-log10-idf-zero-one-v1"
        }
    }
}

/// Document scores and their term contributions, preserving the caller's row/column order.
public struct GlifiKHDocumentScoreResult: Codable, Equatable, Sendable {
    /// Versioned formula used for the scores.
    public let methodIdentifier: String
    /// Resolved term-weighting mode.
    public let mode: GlifiKHDocumentScoreMode
    /// Full reference-corpus document count, independent of selected rows and terms.
    public let corpusDocumentCount: Int
    /// Complete document lengths supplied by the caller.
    public let exposures: [Double]
    /// Full-corpus document frequency for each selected term.
    public let documentFrequencies: [Int]
    /// Base-ten IDF per term; ubiquitous terms retain zero here even in division mode.
    public let inverseDocumentFrequencies: [Double]
    /// One weighted contribution per input document and selected term.
    public let termContributions: [[Double]]
    /// Compensated sums of the corresponding contribution rows.
    public let scores: [Double]
}

/// Bounded KH document scores with explicit corpus frequencies and complete exposures.
public enum GlifiKHDocumentScores {
    /// Scores nonnegative finite counts with positive exposures and observed corpus frequencies.
    ///
    /// The reference corpus may differ from the scored row subset. No selected-column sum
    /// substitutes for the complete exposure. IDF is log10(N/DF); only division mode uses
    /// one instead of a zero divisor, as in KH's public implementation. Empty vocabularies,
    /// nonrepresentable positive contributions and nonfinite sums fail closed.
    public static func score(
        counts: [[Double]], exposures: [Double], documentFrequencies: [Int],
        corpusDocumentCount: Int, mode: GlifiKHDocumentScoreMode,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiKHDocumentScoreResult {
        try Task.checkCancellation()
        guard let columns = counts.first?.count, columns > 0, corpusDocumentCount > 0,
            counts.count == exposures.count, documentFrequencies.count == columns
        else { throw exploratoryFailure("kh-document-score.invalid-input") }
        var cells = limits.maximumCells
        try khScoreConsume([counts.count, columns, 2], remaining: &cells)
        try khScoreConsume([counts.count, 2], remaining: &cells)
        try khScoreConsume([columns, 2], remaining: &cells)
        var work = limits.maximumWork
        try khScoreConsume([counts.count, columns, 4], remaining: &work)
        try khScoreConsume([counts.count], remaining: &work)
        try khScoreConsume([columns, 2], remaining: &work)
        for row in counts.indices {
            try Task.checkCancellation()
            guard counts[row].count == columns, exposures[row].isFinite, exposures[row] > 0
            else { throw exploratoryFailure("kh-document-score.invalid-input") }
            for column in 0..<columns {
                if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
                guard counts[row][column].isFinite, counts[row][column] >= 0 else {
                    throw exploratoryFailure("kh-document-score.invalid-input")
                }
            }
        }
        var idf: [Double] = []
        idf.reserveCapacity(columns)
        for (column, frequency) in documentFrequencies.enumerated() {
            if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
            guard frequency > 0, frequency <= corpusDocumentCount else {
                throw exploratoryFailure("kh-document-score.invalid-frequency")
            }
            // The exact integer difference preserves positive IDF when N and DF round
            // to the same Double. log1p also avoids cancellation near a ubiquitous term.
            let value = log1p(Double(corpusDocumentCount - frequency) / Double(frequency)) / log(10)
            guard value.isFinite, value >= 0,
                frequency == corpusDocumentCount || value > 0
            else { throw exploratoryFailure("kh-document-score.numeric-range") }
            idf.append(value)
        }
        var contributions: [[Double]] = []
        var scores: [Double] = []
        contributions.reserveCapacity(counts.count)
        scores.reserveCapacity(counts.count)
        for row in counts.indices {
            try Task.checkCancellation()
            var terms: [Double] = []
            terms.reserveCapacity(columns)
            var sum = 0.0
            var correction = 0.0
            for column in 0..<columns {
                if column.isMultiple(of: 1_024) { try Task.checkCancellation() }
                let numerator: Double
                let denominator: Double
                switch mode {
                case .tf:
                    numerator = 1
                    denominator = 1
                case .tfIdf:
                    numerator = idf[column]
                    denominator = 1
                case .tfDividedByIdf:
                    numerator = 1
                    denominator = idf[column] == 0 ? 1 : idf[column]
                }
                let contribution = try khScoreRatio(
                    counts[row][column], numerator: numerator,
                    exposure: exposures[row], denominator: denominator)
                terms.append(contribution)
                let adjusted = contribution - correction
                let updated = sum + adjusted
                correction = (updated - sum) - adjusted
                sum = updated
                guard sum.isFinite else {
                    throw exploratoryFailure("kh-document-score.numeric-range")
                }
            }
            contributions.append(terms)
            scores.append(sum)
        }
        try Task.checkCancellation()
        return GlifiKHDocumentScoreResult(
            methodIdentifier: mode.methodIdentifier, mode: mode,
            corpusDocumentCount: corpusDocumentCount, exposures: exposures,
            documentFrequencies: documentFrequencies, inverseDocumentFrequencies: idf,
            termContributions: contributions, scores: scores)
    }
}

private func khScoreConsume(_ factors: [Int], remaining: inout Int) throws {
    var product = 1
    for factor in factors {
        guard factor >= 0, product == 0 || factor <= remaining / product else {
            throw exploratoryFailure("kh-document-score.resource-limit", .insufficientResources)
        }
        product *= factor
    }
    remaining -= product
}

private func khScoreRatio(
    _ count: Double, numerator: Double, exposure: Double, denominator: Double
) throws -> Double {
    guard count > 0, numerator > 0 else { return 0 }
    let exponent = count.exponent + numerator.exponent - exposure.exponent - denominator.exponent
    let significand =
        count.significand * numerator.significand / exposure.significand / denominator.significand
    let result = Double(sign: .plus, exponent: exponent, significand: significand)
    guard result.isFinite, result > 0 else {
        throw exploratoryFailure("kh-document-score.numeric-range")
    }
    return result
}
