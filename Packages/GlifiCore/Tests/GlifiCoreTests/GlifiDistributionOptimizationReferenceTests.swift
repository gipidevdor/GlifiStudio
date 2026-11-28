// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private struct OptimizationDistributionGrid: Decodable {
    struct Normal: Decodable {
        let probability: Double
        let expected: Double
        let bits: [String: String]
        let hex: [String: String]
    }

    struct Student: Decodable {
        let statistic: Double
        let degrees: Double
        let twoSided: Double
        let less: Double
        let greater: Double
        let relativeTolerance: Double
        let bits: [String: String]
        let hex: [String: String]
    }

    struct Fisher: Decodable {
        let statistic: Double
        let firstDegrees: Double
        let secondDegrees: Double
        let expected: Double
        let relativeTolerance: Double
        let bits: [String: String]
        let hex: [String: String]
    }

    struct ChiSquare: Decodable {
        let statistic: Double
        let degrees: Int
        let expected: Double
        let relativeTolerance: Double
        let bits: [String: String]
        let hex: [String: String]
    }

    struct BCa: Decodable {
        let estimate: Double
        let confidenceLevel: Double
        let biasCorrection: Double
        let acceleration: Double
        let lowerProbability: Double
        let upperProbability: Double
        let lower: Double
        let upper: Double
        let probabilityTolerance: Double
        let lowerEnvelopeMin: Double
        let lowerEnvelopeMax: Double
        let upperEnvelopeMin: Double
        let upperEnvelopeMax: Double
        let sortedReplicates: [Double]
        let sortedReplicatesBits: [String]
        let sortedReplicatesHex: [String]
        let jackknife: [Double]
        let jackknifeBits: [String]
        let jackknifeHex: [String]
        let bits: [String: String]
        let hex: [String: String]
    }

    struct EffectSize: Decodable {
        let confidenceLevel: Double
        let cohenD: Double
        let correctionFactor: Double
        let hedgesG: Double
        let standardError: Double
        let lower: Double
        let upper: Double
        let firstSample: [Double]
        let firstSampleBits: [String]
        let firstSampleHex: [String]
        let secondSample: [Double]
        let secondSampleBits: [String]
        let secondSampleHex: [String]
        let bits: [String: String]
        let hex: [String: String]
    }

    let schema: String
    let schemaVersion: Int
    let normalMaximumULP: UInt64
    let normal: [Normal]
    let t: [Student]
    let f: [Fisher]
    let chiSquare: [ChiSquare]
    let bca: [BCa]
    let effectSize: [EffectSize]
}

private func optimizationDistributionGrid() throws -> OptimizationDistributionGrid {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    let path = root.appending(path: "docs/evidenze/allegati/GS-VER-324/griglia-kernel.json")
    let grid = try JSONDecoder().decode(
        OptimizationDistributionGrid.self, from: Data(contentsOf: path))
    #expect(grid.schema == "studio.glifi.statistical-optimization-oracle")
    #expect(grid.schemaVersion == 1)
    #expect(grid.normalMaximumULP == 8)
    #expect(grid.normal.count > 100)
    #expect(!grid.t.isEmpty && !grid.f.isEmpty && !grid.chiSquare.isEmpty)
    #expect(grid.bca.count == 36 && grid.effectSize.count == 18)
    return grid
}

private func optimizationULPDistance(_ first: Double, _ second: Double) -> UInt64 {
    guard first.isFinite, second.isFinite else { return .max }
    guard first != second else { return 0 }
    func ordered(_ value: Double) -> UInt64 {
        let bits = value.bitPattern
        return bits >> 63 == 0 ? bits | (1 << 63) : ~bits
    }
    let left = ordered(first)
    let right = ordered(second)
    return left >= right ? left - right : right - left
}

private func expectOptimizationInputBits(
    _ values: [String: Double], bits: [String: String], hex: [String: String]
) {
    #expect(values.count == bits.count && values.count == hex.count)
    for (key, value) in values {
        let sourceBits = bits[key].flatMap { UInt64($0, radix: 16) }
        #expect(sourceBits == value.bitPattern)
        let hexadecimalValue = hex[key].flatMap(Double.init)
        #expect(hexadecimalValue?.bitPattern == value.bitPattern)
    }
}

private func expectOptimizationArrayBits(
    _ values: [Double], bits: [String], hex: [String]
) {
    #expect(values.count == bits.count && values.count == hex.count)
    guard values.count == bits.count && values.count == hex.count else { return }
    for index in values.indices {
        #expect(UInt64(bits[index], radix: 16) == values[index].bitPattern)
        #expect(Double(hex[index])?.bitPattern == values[index].bitPattern)
    }
}

private func expectOptimizationScalar(_ actual: Double, _ expected: Double) {
    #expect(actual.isFinite)
    #expect(abs(actual - expected) <= 1e-12 * max(1, abs(expected)))
}

private func expectOptimizationEnvelope(_ actual: Double, lower: Double, upper: Double) {
    // R supplies the Type-7 image of the declared probability uncertainty.
    // This preserves the local condition number at integer rank boundaries.
    let roundoff = 64 * Double.ulpOfOne * max(1, abs(lower), abs(upper))
    #expect(actual.isFinite)
    #expect(actual >= lower - roundoff && actual <= upper + roundoff)
}

private func expectOptimizationProbability(
    _ actual: Double, _ expected: Double, relativeTolerance: Double,
    isMathematicalEndpoint: Bool = false
) {
    #expect(actual.isFinite && actual >= 0 && actual <= 1)
    if isMathematicalEndpoint || expected == 0 || !expected.isNormal {
        // A reference rounded to one at positive x is not a mathematical endpoint.
        // True endpoints and quantized small tails retain exact checks.
        #expect(actual == expected)
    } else {
        #expect(actual > 0)
        #expect(abs(actual - expected) / max(actual, expected) <= relativeTolerance)
    }
}

@Test("Optimized normal inversion retains R accuracy in ULP and monotone boundaries")
func distributionOptimizationNormalReferenceGrid() throws {
    let grid = try optimizationDistributionGrid()
    var previous = -Double.infinity
    for row in grid.normal {
        expectOptimizationInputBits(
            ["probability": row.probability, "expected": row.expected], bits: row.bits, hex: row.hex
        )
        let actual = try GlifiDistributionFunctions.normalQuantile(row.probability)
        #expect(actual.isFinite)
        #expect(optimizationULPDistance(actual, row.expected) <= grid.normalMaximumULP)
        #expect(actual >= previous)
        if row.probability < 0.5 { #expect(actual < 0) }
        if row.probability == 0.5 { #expect(actual == 0) }
        if row.probability > 0.5 { #expect(actual > 0) }
        previous = actual
    }
}

@Test("Optimized beta kernels retain t alternatives and their small tails")
func distributionOptimizationStudentReferenceGrid() throws {
    for row in try optimizationDistributionGrid().t {
        expectOptimizationInputBits(
            [
                "statistic": row.statistic, "degrees": row.degrees, "twoSided": row.twoSided,
                "less": row.less, "greater": row.greater,
                "relativeTolerance": row.relativeTolerance,
            ], bits: row.bits, hex: row.hex)
        let twoSided = try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: row.statistic, degreesOfFreedom: row.degrees, alternative: .twoSided)
        let less = try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: row.statistic, degreesOfFreedom: row.degrees, alternative: .less)
        let greater = try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: row.statistic, degreesOfFreedom: row.degrees, alternative: .greater)
        expectOptimizationProbability(
            twoSided, row.twoSided, relativeTolerance: row.relativeTolerance,
            isMathematicalEndpoint: row.statistic == 0)
        expectOptimizationProbability(less, row.less, relativeTolerance: row.relativeTolerance)
        expectOptimizationProbability(
            greater, row.greater, relativeTolerance: row.relativeTolerance)
        #expect(abs(less + greater - 1) <= 2 * Double.ulpOfOne)
        let reflected = try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: -row.statistic, degreesOfFreedom: row.degrees, alternative: .less)
        #expect(reflected == greater)
    }
}

@Test("Optimized beta kernels retain F tails at symmetry and numeric boundaries")
func distributionOptimizationFisherReferenceGrid() throws {
    for row in try optimizationDistributionGrid().f {
        expectOptimizationInputBits(
            [
                "statistic": row.statistic, "firstDegrees": row.firstDegrees,
                "secondDegrees": row.secondDegrees, "expected": row.expected,
                "relativeTolerance": row.relativeTolerance,
            ], bits: row.bits, hex: row.hex)
        let actual = try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
            statistic: row.statistic, numeratorDegreesOfFreedom: row.firstDegrees,
            denominatorDegreesOfFreedom: row.secondDegrees)
        expectOptimizationProbability(
            actual, row.expected, relativeTolerance: row.relativeTolerance,
            isMathematicalEndpoint: row.statistic == 0)
    }
}

@Test("Optimized gamma kernels retain the series/fraction boundary and subnormal tails")
func distributionOptimizationChiSquareReferenceGrid() throws {
    for row in try optimizationDistributionGrid().chiSquare {
        expectOptimizationInputBits(
            [
                "statistic": row.statistic, "degrees": Double(row.degrees),
                "expected": row.expected,
                "relativeTolerance": row.relativeTolerance,
            ], bits: row.bits, hex: row.hex)
        let actual = try chiSquareUpperTailProbability(row.statistic, degreesOfFreedom: row.degrees)
        expectOptimizationProbability(
            actual, row.expected, relativeTolerance: row.relativeTolerance,
            isMathematicalEndpoint: row.statistic == 0)
    }
}

@Test("Normal inversion retains BCa bias, acceleration and Type-7 boundary propagation")
func distributionOptimizationBCaReferenceGrid() throws {
    for row in try optimizationDistributionGrid().bca {
        expectOptimizationInputBits(
            [
                "estimate": row.estimate, "confidenceLevel": row.confidenceLevel,
                "biasCorrection": row.biasCorrection, "acceleration": row.acceleration,
                "lowerProbability": row.lowerProbability, "upperProbability": row.upperProbability,
                "lower": row.lower, "upper": row.upper,
                "probabilityTolerance": row.probabilityTolerance,
                "lowerEnvelopeMin": row.lowerEnvelopeMin, "lowerEnvelopeMax": row.lowerEnvelopeMax,
                "upperEnvelopeMin": row.upperEnvelopeMin, "upperEnvelopeMax": row.upperEnvelopeMax,
            ],
            bits: row.bits, hex: row.hex)
        expectOptimizationArrayBits(
            row.sortedReplicates, bits: row.sortedReplicatesBits, hex: row.sortedReplicatesHex)
        expectOptimizationArrayBits(row.jackknife, bits: row.jackknifeBits, hex: row.jackknifeHex)
        #expect(row.probabilityTolerance == 4e-15)
        let actual = try GlifiStatisticalFoundation.bcaInterval(
            estimate: row.estimate, sortedReplicates: row.sortedReplicates,
            jackknife: row.jackknife, confidenceLevel: row.confidenceLevel, seed: 0)
        #expect(optimizationULPDistance(actual.biasCorrection, row.biasCorrection) <= 8)
        #expect(abs(actual.acceleration - row.acceleration) <= 32 * Double.ulpOfOne)
        #expect(abs(actual.lowerProbability - row.lowerProbability) <= row.probabilityTolerance)
        #expect(abs(actual.upperProbability - row.upperProbability) <= row.probabilityTolerance)
        #expect(actual.lowerProbability <= actual.upperProbability)
        #expect(actual.lower <= actual.upper)
        #expect(actual.resampleCount == row.sortedReplicates.count)
        expectOptimizationEnvelope(
            actual.lower, lower: row.lowerEnvelopeMin, upper: row.lowerEnvelopeMax)
        expectOptimizationEnvelope(
            actual.upper, lower: row.upperEnvelopeMin, upper: row.upperEnvelopeMax)
    }
}

@Test("Normal inversion retains standardized differences and confidence interval endpoints")
func distributionOptimizationEffectSizeReferenceGrid() throws {
    for row in try optimizationDistributionGrid().effectSize {
        expectOptimizationInputBits(
            [
                "confidenceLevel": row.confidenceLevel, "cohenD": row.cohenD,
                "correctionFactor": row.correctionFactor, "hedgesG": row.hedgesG,
                "standardError": row.standardError, "lower": row.lower, "upper": row.upper,
            ],
            bits: row.bits, hex: row.hex)
        expectOptimizationArrayBits(
            row.firstSample, bits: row.firstSampleBits, hex: row.firstSampleHex)
        expectOptimizationArrayBits(
            row.secondSample, bits: row.secondSampleBits, hex: row.secondSampleHex)
        let actual = try GlifiStatisticalFoundation.standardizedDifference(
            row.firstSample, row.secondSample, confidenceLevel: row.confidenceLevel)
        expectOptimizationScalar(actual.cohenD, row.cohenD)
        expectOptimizationScalar(actual.correctionFactor, row.correctionFactor)
        expectOptimizationScalar(actual.hedgesG, row.hedgesG)
        expectOptimizationScalar(actual.standardError, row.standardError)
        expectOptimizationScalar(actual.lower, row.lower)
        expectOptimizationScalar(actual.upper, row.upper)
        #expect(actual.lower <= actual.cohenD && actual.cohenD <= actual.upper)
    }
}

@Test("Distribution optimization preserves parameter admission and fail-closed numeric limits")
func distributionOptimizationFailureContracts() {
    for probability in [0, 1, -1, Double.nan, .infinity, -.infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiDistributionFunctions.normalQuantile(probability)
        }
    }
    for degrees in [0, -1, Double.nan, .infinity, -.infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.tDistributionPValue(
                statistic: 1, degreesOfFreedom: degrees, alternative: .twoSided)
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
                statistic: 1, numeratorDegreesOfFreedom: degrees, denominatorDegreesOfFreedom: 2)
        }
    }
    for statistic in [-1, Double.nan, .infinity, -.infinity] {
        #expect(throws: GlifiFailure.self) {
            try chiSquareUpperTailProbability(statistic, degreesOfFreedom: 2)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
            statistic: 1, numeratorDegreesOfFreedom: .greatestFiniteMagnitude,
            denominatorDegreesOfFreedom: .greatestFiniteMagnitude)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.bcaInterval(
            estimate: 0, sortedReplicates: [-2, -1, 1, 2], jackknife: [-1, 0, 1],
            confidenceLevel: (1.0).nextDown, seed: 0)
    }
    for confidenceLevel in [0, 1, -1, Double.nan, .infinity, -.infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.standardizedDifference(
                [1, 2, 3, 4], [2, 3, 4, 6], confidenceLevel: confidenceLevel)
        }
    }
}

@Test("Distribution optimization preserves cancellation at continued-fraction entry")
func distributionOptimizationCancellationContracts() async {
    let beta = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        do {
            _ = try GlifiStatisticalFoundation.tDistributionPValue(
                statistic: 3, degreesOfFreedom: 7, alternative: .twoSided)
            return false
        } catch is CancellationError {
            return true
        } catch {
            return false
        }
    }
    let gamma = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        do {
            _ = try chiSquareUpperTailProbability(100, degreesOfFreedom: 2)
            return false
        } catch is CancellationError {
            return true
        } catch {
            return false
        }
    }
    #expect(await beta.value)
    #expect(await gamma.value)
}
