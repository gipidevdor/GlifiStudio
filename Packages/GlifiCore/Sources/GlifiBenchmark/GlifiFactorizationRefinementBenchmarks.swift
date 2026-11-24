// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Bounded NMF workloads; generators and canonical checksums stay outside the timed region.
func factorizationRefinementMeasurements() throws -> [Measurement] {
    var lowRankGenerator = GlifiSplitMix64(seed: 171)
    let left = (0..<120).map { _ in
        (0..<3).map { _ in Double(lowRankGenerator.index(below: 9) + 1) / 10 }
    }
    let right = (0..<3).map { _ in
        (0..<240).map { _ in Double(lowRankGenerator.index(below: 9) + 1) / 10 }
    }
    let lowRank = left.map { row in
        (0..<240).map { column in
            (0..<3).reduce(0.0) { $0 + row[$1] * right[$1][column] }
        }
    }
    var sparseGenerator = GlifiSplitMix64(seed: 172)
    let sparse = (0..<240).map { _ in
        (0..<320).map { _ in
            sparseGenerator.index(below: 20) < 3
                ? Double(sparseGenerator.index(below: 9) + 1) : 0
        }
    }
    var rectangularGenerator = GlifiSplitMix64(seed: 173)
    let rectangular = (0..<400).map { row in
        (0..<96).map { column in
            row / 50 == column / 12 || rectangularGenerator.index(below: 20) == 0
                ? Double(rectangularGenerator.index(below: 8) + 1) : 0
        }
    }
    let cases: [(String, String, FactorizationRefinementInput)] = [
        (
            "refinement-nmf-lowrank-120x240-k3", "SplitMix64 seed 171; exact nonnegative rank 3",
            FactorizationRefinementInput(
                matrix: lowRank, rank: 3, seed: 181, restarts: 1,
                maximumIterations: 80, tolerance: 1e-12)
        ),
        (
            "refinement-nmf-sparse-240x320-k12",
            "SplitMix64 seed 172; 15% observed counts in 1...9",
            FactorizationRefinementInput(
                matrix: sparse, rank: 12, seed: 182, restarts: 1,
                maximumIterations: 40, tolerance: 1e-12)
        ),
        (
            "refinement-nmf-rectangular-400x96-k6",
            "SplitMix64 seed 173; eight topic blocks and 5% background",
            FactorizationRefinementInput(
                matrix: rectangular, rank: 6, seed: 183, restarts: 2,
                maximumIterations: 70, tolerance: 1e-12)
        ),
    ]
    var measurements: [Measurement] = []
    for (identifier, recipe, input) in cases {
        let inputChecksum = try factorizationRefinementChecksum(input)
        var result: GlifiNonNegativeFactorization?
        let times = try measure {
            result = try GlifiMultivariateMethods.nonNegativeFactorization(
                input.matrix, rank: input.rank, seed: input.seed, restarts: input.restarts,
                maximumIterations: input.maximumIterations, tolerance: input.tolerance)
        }
        guard let result else { throw FactorizationRefinementFailure.missingResult }
        let check =
            try factorizationRefinementChecksum(result)
            + "; objective=\(result.objective); iterations=\(result.iterations)"
            + "; converged=\(result.converged); chosenRestart=\(result.chosenRestart)"
        measurements.append(
            summary(
                identifier, "GS-MET-001-15, NMF-Frobenius-v1",
                recipe + "; seed=\(input.seed); restarts=\(input.restarts)"
                    + "; maximumIterations=\(input.maximumIterations); tolerance=\(input.tolerance)"
                    + "; input=\(inputChecksum)",
                times, check: check))
    }
    return measurements
}

private struct FactorizationRefinementInput: Encodable {
    let matrix: [[Double]]
    let rank: Int
    let seed: UInt64
    let restarts: Int
    let maximumIterations: Int
    let tolerance: Double
}

private enum FactorizationRefinementFailure: Error {
    case missingResult
}

private func factorizationRefinementChecksum(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return "sha256:"
        + SHA256.hash(data: try encoder.encode(value)).map {
            String(format: "%02x", $0)
        }.joined()
}
