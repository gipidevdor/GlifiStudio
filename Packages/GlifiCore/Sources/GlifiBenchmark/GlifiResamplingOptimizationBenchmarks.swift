// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Moving-block workloads; fixture generation and complete bitwise checksums are untimed.
func resamplingOptimizationMeasurements() throws -> [Measurement] {
    let count = 4_096
    let resampleCount = 4_000
    let confidenceLevel = 0.95
    let seed: UInt64 = 0x172173
    let sequence = (0..<count).map { index in
        Double((index * 37) % 8_192 - 4_096) / 64 + Double(index % 11) / 256
    }
    var measurements: [Measurement] = []
    for blockLength in [4_095, 257, 1] {
        var input = ResamplingBenchmarkChecksum()
        input.append("MovingBlockBootstrap-v1")
        input.append(GlifiBootstrapInterval.quantileIdentifier)
        input.append(GlifiSplitMix64.identifier)
        input.append(UInt64(sequence.count))
        for value in sequence { input.append(value.bitPattern) }
        input.append(UInt64(blockLength))
        input.append(confidenceLevel.bitPattern)
        input.append(UInt64(resampleCount))
        input.append(seed)
        input.append(UInt64(1))  // Calls per timed batch.
        input.append(UInt64(1))  // Warm-up batches.
        input.append(UInt64(5))  // Timed batches.
        let inputDigest = input.digest

        var result: GlifiBootstrapInterval?
        let times = try measure {
            result = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                sequence, blockLength: blockLength, confidenceLevel: confidenceLevel,
                resampleCount: resampleCount, seed: seed)
        }
        guard let result else { throw ResamplingBenchmarkFailure.missingResult }
        var output = ResamplingBenchmarkChecksum()
        output.append(GlifiBootstrapInterval.identifier)
        output.append(GlifiBootstrapInterval.quantileIdentifier)
        output.append(result.estimate.bitPattern)
        output.append(result.confidenceLevel.bitPattern)
        output.append(result.lower.bitPattern)
        output.append(result.upper.bitPattern)
        output.append(UInt64(result.resampleCount))
        output.append(result.generatorIdentifier)
        output.append(result.seed)
        measurements.append(
            summary(
                "moving-block-bootstrap-n4096-b4000-l\(blockLength)", "GS-MET-001-21",
                "n=4096; x[i]=((i*37)%8192-4096)/64+(i%11)/256; "
                    + "B=4000; L=\(blockLength); confidence=0.95; SplitMix64 seed=0x172173; "
                    + "batch=1; warm-up=1; samples=5; seconds per call; inputSHA256=\(inputDigest)",
                times, check: "outputSHA256=\(output.digest)"))
    }
    return measurements
}

private enum ResamplingBenchmarkFailure: Error {
    case missingResult
}

private struct ResamplingBenchmarkChecksum {
    private var bytes = Data()

    var digest: String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    mutating func append(_ integer: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            bytes.append(UInt8((integer >> shift) & 255))
        }
    }

    mutating func append(_ text: String) {
        append(UInt64(text.utf8.count))
        bytes.append(contentsOf: text.utf8)
    }
}
