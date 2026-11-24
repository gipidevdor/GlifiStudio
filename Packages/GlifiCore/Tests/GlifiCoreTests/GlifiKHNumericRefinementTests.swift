// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test(
    "KH scores round subnormal contributions once in all three weighting modes",
    arguments: GlifiKHDocumentScoreMode.allCases)
func khRefinementDocumentScoreSubnormalRounding(_ mode: GlifiKHDocumentScoreMode) throws {
    // Let q=2^52+1 and p=(3q-1)/2. The exact ratio p/q is below 3/2;
    // after scaling by the subnormal quantum it rounds to one quantum, not two.
    // Multiplications by two below are exact. A single hardware division gives
    // an independent oracle without repeating the product/ratio implementation.
    let count = 0x1.8000000000001p-1022
    let exposure = 4_503_599_627_370_497.0
    let expected = count / exposure
    #expect(expected == Double.leastNonzeroMagnitude)
    let inputCount: Double
    let inputExposure: Double
    let corpus: Int
    switch mode {
    case .tf:
        inputCount = count
        inputExposure = exposure
        corpus = 1
    case .tfIdf:
        inputCount = count
        inputExposure = 2 * exposure
        corpus = 100
    case .tfDividedByIdf:
        inputCount = 2 * count
        inputExposure = exposure
        corpus = 100
    }
    let result = try GlifiKHDocumentScores.score(
        counts: [[inputCount]], exposures: [inputExposure], documentFrequencies: [1],
        corpusDocumentCount: corpus, mode: mode)
    #expect(result.termContributions == [[expected]])
    #expect(result.scores == [expected])
}

@Test("KH Ward refuses subnormal squared distances that would create a false input tie")
func khRefinementWardRejectsCollapsedSubnormalTie() throws {
    let closer = Double(sign: .plus, exponent: -537, significand: 1)
    let farther = closer.nextUp
    #expect(closer < farther)
    let matrix: [[Double]] = [
        [0, farther, closer, 1],
        [farther, 0, closer + farther, 1],
        [closer, closer + farther, 0, 1],
        [1, 1, 1, 0],
    ]
    // Normal initial squares may also become subnormal during an algebraic update.
    let normalSquareDistance = Double(sign: .plus, exponent: -511, significand: 1)
    let updateMatrix: [[Double]] = [
        [0, 0, 0, 1], [0, 0, normalSquareDistance, 1],
        [0, normalSquareDistance, 0, 1], [1, 1, 1, 0],
    ]
    for input in [matrix, updateMatrix] {
        do {
            _ = try GlifiKHLegacyClustering.wardD2(dissimilarities: input)
            Issue.record("Unsafe squared distances were accepted instead of failing closed")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "kh-ward.numeric-range")
            #expect(failure.category == .invalidInput)
            #expect(failure.retainedState == .unchanged)
        }
    }
}

@Test("KH Ward reports an exhausted object budget as a resource failure")
func khRefinementWardObjectLimitFailure() throws {
    do {
        _ = try GlifiKHLegacyClustering.wardD2(
            dissimilarities: [[0, 1], [1, 0]], limits: .init(maximumPairwiseObjects: 1))
        Issue.record("The object limit was ignored")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "kh-ward.resource-limit")
        #expect(failure.category == .insufficientResources)
        #expect(
            failure.retryDisposition
                == GlifiFailureTaxonomy.defaultRetry(.insufficientResources))
        #expect(failure.retainedState == .unchanged)
    }
}

@Test("KH subnormal scores match exhaustive nearest-quantum choices with even ties")
func khRefinementDocumentScoreSmallRationalOracle() throws {
    for numerator in 1...33 {
        for denominator in 1...17 {
            // Enumerate representable neighboring quantum counts and minimize exact
            // integer error. This does not use the production quotient/remainder recurrence.
            let nearest = try #require(
                (0...33).min { left, right in
                    let leftError = abs(numerator - left * denominator)
                    let rightError = abs(numerator - right * denominator)
                    if leftError != rightError { return leftError < rightError }
                    if left.isMultiple(of: 2) != right.isMultiple(of: 2) {
                        return left.isMultiple(of: 2)
                    }
                    return left < right
                })
            let count = Double(numerator) * Double.leastNonzeroMagnitude
            for mode in GlifiKHDocumentScoreMode.allCases {
                let inputCount = mode == .tfDividedByIdf ? 2 * count : count
                let exposure = Double(denominator) * (mode == .tfIdf ? 2 : 1)
                let corpus = mode == .tf ? 1 : 100
                if nearest == 0 {
                    #expect(throws: GlifiFailure.self) {
                        try GlifiKHDocumentScores.score(
                            counts: [[inputCount]], exposures: [exposure], documentFrequencies: [1],
                            corpusDocumentCount: corpus, mode: mode)
                    }
                } else {
                    let actual = try GlifiKHDocumentScores.score(
                        counts: [[inputCount]], exposures: [exposure], documentFrequencies: [1],
                        corpusDocumentCount: corpus, mode: mode)
                    #expect(actual.scores == [Double(nearest) * Double.leastNonzeroMagnitude])
                }
            }
        }
    }
}

@Test("KH scores preserve normal-boundary neighbors and ordinary arithmetic in every mode")
func khRefinementDocumentScoreNormalNeighbors() throws {
    for value in [
        Double.leastNormalMagnitude.nextDown, Double.leastNormalMagnitude,
        Double.leastNormalMagnitude.nextUp, 1, Double.greatestFiniteMagnitude,
    ] {
        for mode in GlifiKHDocumentScoreMode.allCases {
            let exposure: Double
            switch mode {
            case .tf: exposure = 1
            case .tfIdf: exposure = 2
            case .tfDividedByIdf: exposure = 0.5
            }
            let result = try GlifiKHDocumentScores.score(
                counts: [[value]], exposures: [exposure], documentFrequencies: [1],
                corpusDocumentCount: mode == .tf ? 1 : 100, mode: mode)
            #expect(result.scores == [value])
        }
    }
}

@Test("KH scores admit the entire bounded subnormal rounding work before building outputs")
func khRefinementDocumentScoreRoundingWorkAdmission() throws {
    let value = Double.leastNonzeroMagnitude
    do {
        _ = try GlifiKHDocumentScores.score(
            counts: [[value]], exposures: [1], documentFrequencies: [1],
            corpusDocumentCount: 1, mode: .tf, limits: .init(maximumWork: 60))
        Issue.record("Subnormal rounding exceeded its admitted work")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "kh-document-score.resource-limit")
        #expect(failure.category == .insufficientResources)
    }
    let result = try GlifiKHDocumentScores.score(
        counts: [[value]], exposures: [1], documentFrequencies: [1],
        corpusDocumentCount: 1, mode: .tf,
        limits: .init(maximumCells: 6, maximumWork: 61))
    #expect(result.scores == [value])
    // Ordinary data keep the original 4RC+R+2C estimate and do not pay for the fallback.
    #expect(
        try GlifiKHDocumentScores.score(
            counts: [[1]], exposures: [1], documentFrequencies: [1],
            corpusDocumentCount: 1, mode: .tf,
            limits: .init(maximumCells: 6, maximumWork: 7)
        ).scores == [1])
}
