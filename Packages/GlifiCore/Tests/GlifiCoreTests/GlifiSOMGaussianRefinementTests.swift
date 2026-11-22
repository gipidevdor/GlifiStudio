// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Batch Gaussian SOM keeps relative influence when all absolute weights are small")
func khRefinementBatchGaussianRelativeWeights() throws {
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1]], width: 8, height: 1, seed: 0, epochs: 1,
        initialRadius: 0.5, finalRadius: 0.5)
    // SplitMix64 seed zero initializes [1,0,1,0,1,0,1,0]. The first BMUs are
    // unit 1 for zero and unit 0 for one. Their normalized Gaussian mean is
    // 1 / (1 + exp(4*u - 2)); this closed form does not reuse the batch algorithm.
    for unit in 0..<8 {
        let expected = 1 / (1 + exp(Double(4 * unit - 2)))
        #expect(abs(result.prototypes[unit][0] - expected) <= expected * 2e-13)
    }
    #expect(abs(result.prototypes[6][0] / 2.7894680920908113e-10 - 1) < 2e-13)
}

@Test("Batch SOM recovers relative weights after every absolute Gaussian has underflowed")
func khRefinementBatchGaussianAbsoluteUnderflowRecovery() throws {
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1]], width: 32, height: 1, seed: 0, epochs: 1,
        initialRadius: 0.5, finalRadius: 0.5)
    // Unit 31 has absolute exponents -1800 and -1922. Both exp values
    // underflow, but their ratio is ordinary binary64 exp(-122).
    // Unit 19 also checks a subnormal absolute coefficient divided by a normal
    // denominator. Checking the whole grid catches either source of range loss.
    for unit in 0..<32 {
        let expected = 1 / (1 + exp(Double(4 * unit - 2)))
        #expect(result.prototypes[unit][0] > 0)
        #expect(abs(result.prototypes[unit][0] / expected - 1) < 2e-13)
    }
}

@Test("Batch SOM combines a subnormal Gaussian coefficient before a normal scalar product")
func khRefinementBatchGaussianSubnormalCoefficientWithNormalProduct() throws {
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        [[0], [1e100]], width: 187, height: 1, seed: 0, epochs: 1,
        initialRadius: 0.5, finalRadius: 0.5)
    // Decimal(100): 1e100 * exp(-742) / (1 + exp(-742)). exp(-742)
    // is subnormal, but the final mean is normal in the original state units.
    let expected = 5.6688429807079775e-223
    #expect(result.prototypes[186][0] > 0)
    #expect(abs(result.prototypes[186][0] / expected - 1) < 2e-12)
}

@Test("Batch SOM never publishes zero after losing a representable Gaussian weighted product")
func khRefinementBatchGaussianRestoredUnderflow() throws {
    do {
        let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
            [[0], [1e308]], width: 200, height: 1, seed: 0, epochs: 1,
            initialRadius: 0.5, finalRadius: 0.5)
        // Decimal(100): 1e308 * exp(-794) / (1 + exp(-794)). Subtracting the
        // maximum log-weight alone still loses exp(-794) in binary64, although
        // its product in the original coordinate units is representable.
        let expected = 1.4797262181774719e-37
        #expect(result.prototypes[199][0] > 0)
        #expect(abs(result.prototypes[199][0] / expected - 1) < 2e-12)
    } catch let failure as GlifiFailure {
        // A declared numeric-range rejection is preferable to a plausible zero.
        #expect(failure.code == "exploratory.numeric-range")
        #expect(failure.category == .invalidInput)
    }
}

@Test("Online KH SOM never silently discards a representable restored Gaussian update")
func khRefinementOnlineGaussianRestoredUnderflow() throws {
    let phase = GlifiKHSOMPhase(steps: 1, initialLearningRate: 1, initialRadius: 1)
    do {
        let result = try GlifiExploratoryAnalysis.khSelfOrganizingMap(
            [[1e150]], width: 41, height: 1, firstPhase: phase, secondPhase: phase,
            topology: .rectangular, initialCodebooks: [[Double]](repeating: [0], count: 41))
        // Decimal(100): x*(2*w-w*w), x=1e150, w=exp(-800)/101. Both phases
        // use unit zero as BMU; the final unit is forty grid steps away.
        let expected = 7.263117988470668e-200
        #expect(result.prototypes[40][0] > 0)
        #expect(abs(result.prototypes[40][0] / expected - 1) < 2e-12)
    } catch let failure as GlifiFailure {
        #expect(failure.code == "exploratory.numeric-range")
        #expect(failure.category == .invalidInput)
    }
}
