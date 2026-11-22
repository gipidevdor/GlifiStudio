// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Le similarità conservano identità e omogeneità anche agli estremi di Double")
func lexicalSimilarityHandlesExtremeFiniteVectors() throws {
    for scale in [Double.greatestFiniteMagnitude, 1e200, 1e-200, Double.leastNonzeroMagnitude] {
        let equal = [scale, scale]
        #expect(abs(try GlifiVectorSimilarity.cosine(equal, equal) - 1) < 1e-15)
        #expect(try GlifiVectorSimilarity.cosine([scale, 0], [0, scale]) == 0)
        #expect(try GlifiVectorSimilarity.cosine([scale, 0], [-scale, 0]) == -1)
        #expect(try GlifiVectorSimilarity.weightedJaccard(equal, equal) == 1)
        #expect(try GlifiVectorSimilarity.multisetDice(equal, equal) == 1)
        #expect(try GlifiVectorSimilarity.weightedJaccard([scale, 0], [0, scale]) == 0)
        #expect(try GlifiVectorSimilarity.multisetDice([scale, 0], [0, scale]) == 0)
    }
    let distance = try GlifiVectorSimilarity.euclidean([1e200, 1e200], [0, 0])
    #expect(abs(distance / 1e200 - 2.0.squareRoot()) < 1e-15)
    let subnormal = Double.leastNonzeroMagnitude
    #expect(try GlifiVectorSimilarity.euclidean([subnormal, 0], [0, 0]) == subnormal)
    for distanceMethod in [GlifiVectorSimilarity.euclidean, GlifiVectorSimilarity.manhattan] {
        #expect(throws: GlifiFailure.self) {
            try distanceMethod([Double.greatestFiniteMagnitude], [-Double.greatestFiniteMagnitude])
        }
    }
}

@Test("Lidstone normalizza conteggi e prior enormi o subnormali senza perdere massa")
func lexicalSimilaritySmoothingPreservesProbabilityMass() throws {
    for (counts, alpha) in [
        ([Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude], 1.0),
        (
            [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude],
            Double.greatestFiniteMagnitude
        ),
        ([0.0, 0.0], Double.leastNonzeroMagnitude),
        (
            [Double.leastNonzeroMagnitude, Double.leastNonzeroMagnitude],
            Double.leastNonzeroMagnitude
        ),
    ] {
        let probabilities = try GlifiProbabilityDivergence.lidstone(counts, alpha: alpha)
        #expect(probabilities == [0.5, 0.5])
    }
}

@Test("KL e JS valutano probabilità subnormali nel dominio logaritmico")
func lexicalSimilarityDivergencesAvoidRatioOverflow() throws {
    let smallest = Double.leastNonzeroMagnitude
    // log2(1 / 2^-1074) = 1074; the direct ratio overflows although the log is finite.
    let divergence = try GlifiProbabilityDivergence.klDivergence([1, 0], [smallest, 1])
    #expect(divergence == 1074)
    let left = [smallest, 1.0, 0.0]
    let right = [0.0, 1.0, smallest]
    let js = try GlifiProbabilityDivergence.jensenShannonDivergence(left, right)
    #expect(js.isFinite)
    #expect(js >= 0)
    #expect(js <= 1)
    #expect(try GlifiProbabilityDivergence.jensenShannonDivergence(left, left) == 0)
    #expect(try GlifiProbabilityDivergence.jensenShannonDivergence([1, 0], [0, 1]) == 1)
}
