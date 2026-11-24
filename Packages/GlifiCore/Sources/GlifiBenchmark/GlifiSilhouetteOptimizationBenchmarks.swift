// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Exact silhouette workloads; preparation and complete bitwise checksums remain untimed.
func silhouetteOptimizationMeasurements() throws -> [Measurement] {
    var measurements: [Measurement] = []
    for (clusterCount, seed, batch) in [
        (2, UInt64(172), 1), (50, UInt64(173), 1), (1_000, UInt64(174), 128),
    ] {
        var generator = GlifiSplitMix64(seed: seed)
        let assignments = (0..<1_000).map { $0 % clusterCount }
        let points = assignments.map { cluster in
            (0..<12).map { dimension in
                Double(cluster * 8) + Double(generator.index(below: 10_000)) / 10_000
                    + Double(dimension % 3) / 64
            }
        }
        var input = SilhouetteBenchmarkChecksum()
        input.append("silhouette-euclidean-v1")
        input.append(seed)
        input.append(UInt64(points.count))
        for point in points {
            input.append(UInt64(point.count))
            for coordinate in point { input.append(coordinate.bitPattern) }
        }
        input.append(UInt64(assignments.count))
        for label in assignments { input.append(UInt64(bitPattern: Int64(label))) }
        var result: (widths: [Double], average: Double)?
        let times = try measure {
            for _ in 0..<batch {
                result = try GlifiMultivariateMethods.silhouette(points, assignments: assignments)
            }
        }.map { $0 / Double(batch) }
        guard let result else { throw SilhouetteBenchmarkFailure.missingResult }
        var output = SilhouetteBenchmarkChecksum()
        output.append(UInt64(result.widths.count))
        for width in result.widths { output.append(width.bitPattern) }
        output.append(result.average.bitPattern)
        measurements.append(
            summary(
                "silhouette-1000x12-clusters\(clusterCount)", "GS-MET-001-14",
                "SplitMix64 seed \(seed); 1000 points, 12 dimensions, round-robin labels; "
                    + "cluster offset 8, uniform noise in [0,1), axis offset modulo3/64; "
                    + "batch=\(batch); reported seconds per call; inputSHA256=\(input.digest)",
                times,
                check:
                    "outputSHA256=\(output.digest); widthCount=\(result.widths.count); "
                    + "average=\(result.average)"))
    }
    return measurements
}

private enum SilhouetteBenchmarkFailure: Error {
    case missingResult
}

private struct SilhouetteBenchmarkChecksum {
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
