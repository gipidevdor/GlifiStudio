// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// NMF layout workloads with full input/output checksums outside the measured calls.
func factorizationStorageMeasurements() throws -> [Measurement] {
    var measurements: [Measurement] = []
    for (rows, columns, rank, iterations, generatorSeed, seed) in [
        (120, 240, 3, 80, UInt64(173), UInt64(273)),
        (16, 20_000, 4, 40, UInt64(174), UInt64(274)),
        (20_000, 16, 4, 40, UInt64(175), UInt64(275)),
    ] {
        var generator = GlifiSplitMix64(seed: generatorSeed)
        let matrix = (0..<rows).map { _ in
            (0..<columns).map { _ in
                generator.index(below: 5) == 0 ? 0 : Double(generator.index(below: 9) + 1)
            }
        }
        let restarts = 1
        let tolerance = 1e-12
        let inputChecksum = factorizationStorageInputChecksum(
            matrix, rank: rank, generatorSeed: generatorSeed, seed: seed,
            restarts: restarts, maximumIterations: iterations, tolerance: tolerance)
        var result: GlifiNonNegativeFactorization?
        // The common helper performs one warm-up followed by five samples; batch is one.
        let times = try measure {
            result = try GlifiMultivariateMethods.nonNegativeFactorization(
                matrix, rank: rank, seed: seed, restarts: restarts,
                maximumIterations: iterations, tolerance: tolerance)
        }
        guard let result else { throw FactorizationStorageBenchmarkFailure.missingResult }
        let outputChecksum = factorizationStorageOutputChecksum(result)
        measurements.append(
            summary(
                "storage-nmf-\(rows)x\(columns)-rank\(rank)", "GS-MET-001-15, NMF-Frobenius-v1",
                "SplitMix64 generatorSeed=\(generatorSeed); row-major counts in 1...9 with 20% zeros; "
                    + "rows=\(rows); columns=\(columns); rank=\(rank); seed=\(seed); "
                    + "restarts=\(restarts); maximumIterations=\(iterations); tolerance=\(tolerance); "
                    + "warmups=1; samples=5; batch=1; inputSHA256=\(inputChecksum)",
                times,
                check:
                    "outputSHA256=\(outputChecksum); objective=\(result.objective); "
                    + "iterations=\(result.iterations); converged=\(result.converged); "
                    + "chosenRestart=\(result.chosenRestart)"))
    }
    return measurements
}

private enum FactorizationStorageBenchmarkFailure: Error {
    case missingResult
}

private func factorizationStorageInputChecksum(
    _ matrix: [[Double]], rank: Int, generatorSeed: UInt64, seed: UInt64,
    restarts: Int, maximumIterations: Int, tolerance: Double
) -> String {
    var checksum = FactorizationStorageChecksum()
    checksum.append(GlifiNonNegativeFactorization.identifier)
    checksum.append(GlifiNonNegativeFactorization.updateIdentifier)
    checksum.append(matrix)
    checksum.append(UInt64(rank))
    checksum.append(generatorSeed)
    checksum.append(seed)
    checksum.append(UInt64(restarts))
    checksum.append(UInt64(maximumIterations))
    checksum.append(tolerance.bitPattern)
    return checksum.digest
}

private func factorizationStorageOutputChecksum(_ result: GlifiNonNegativeFactorization) -> String {
    var checksum = FactorizationStorageChecksum()
    checksum.append(GlifiNonNegativeFactorization.identifier)
    checksum.append(GlifiNonNegativeFactorization.updateIdentifier)
    checksum.append(UInt64(result.rank))
    checksum.append(result.w)
    checksum.append(result.h)
    checksum.append(result.objective.bitPattern)
    checksum.append(UInt64(result.objectiveHistory.count))
    for value in result.objectiveHistory { checksum.append(value.bitPattern) }
    checksum.append(UInt64(result.iterations))
    checksum.append(result.converged ? 1 : 0)
    checksum.append(result.seed)
    checksum.append(UInt64(result.restarts))
    checksum.append(UInt64(result.chosenRestart))
    return checksum.digest
}

/// Length-prefixed UTF-8, dimensions and binary64 bit patterns as little-endian UInt64.
private struct FactorizationStorageChecksum {
    private var bytes = Data()

    var digest: String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    mutating func append(_ value: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            bytes.append(UInt8((value >> shift) & 255))
        }
    }

    mutating func append(_ value: String) {
        append(UInt64(value.utf8.count))
        bytes.append(contentsOf: value.utf8)
    }

    mutating func append(_ matrix: [[Double]]) {
        append(UInt64(matrix.count))
        for row in matrix {
            append(UInt64(row.count))
            for value in row { append(value.bitPattern) }
        }
    }
}
