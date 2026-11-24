// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Darwin
import Foundation

private enum PipelineBenchmarkFailure: Error {
    case resultMismatch
    case releaseConfigurationRequired
}

private struct PipelineBenchmarkReport: Encodable {
    let identifier: String
    let generator: String
    let fixtureDigest: String
    let resultDigest: String
    let device: String
    let physicalMemoryBytes: UInt64
    let logicalProcessorCount: Int
    let operatingSystem: String
    let configuration: String
    let thermalStateAtStart: String
    let thermalStateAtEnd: String
    let lowPowerModeAtStart: Bool
    let lowPowerModeAtEnd: Bool
    let warmupRuns: Int
    let samplesSeconds: [Double]
    let medianSeconds: Double
    let minimumSeconds: Double
    let maximumSeconds: Double
    let resultChecks: Int
    let measurementScope: String
}

/// Measures only the supplied operation when an explicit report destination is set.
///
/// Callers also perform a meaningful reference regression without that environment variable.
public func measurePipelineOptimization<Result: Equatable>(
    identifier: String,
    generator: String,
    fixtureDigest: String,
    expected: Result,
    body: () throws -> Result,
    checksum: (Result) throws -> String
) throws {
    guard
        let directory = ProcessInfo.processInfo.environment[
            "GLIFI_PIPELINE_BENCHMARK_DIRECTORY"]
    else { return }
    #if DEBUG
        throw PipelineBenchmarkFailure.releaseConfigurationRequired
    #else
        let process = ProcessInfo.processInfo
        let thermalAtStart = String(describing: process.thermalState)
        let lowPowerAtStart = process.isLowPowerModeEnabled
        let expectedDigest = try checksum(expected)
        let warmup = try body()
        guard warmup == expected, try checksum(warmup) == expectedDigest else {
            throw PipelineBenchmarkFailure.resultMismatch
        }
        var times: [Double] = []
        times.reserveCapacity(7)
        for _ in 0..<7 {
            let start = DispatchTime.now().uptimeNanoseconds
            let observed = try body()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            guard observed == expected, try checksum(observed) == expectedDigest else {
                throw PipelineBenchmarkFailure.resultMismatch
            }
            times.append(Double(elapsed) / 1e9)
        }
        let sorted = times.sorted()
        var modelSize = 0
        sysctlbyname("hw.model", nil, &modelSize, nil, 0)
        var model = [CChar](repeating: 0, count: max(modelSize, 1))
        sysctlbyname("hw.model", &model, &modelSize, nil, 0)
        let report = PipelineBenchmarkReport(
            identifier: identifier,
            generator: generator,
            fixtureDigest: fixtureDigest,
            resultDigest: expectedDigest,
            device: String(
                decoding: model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self),
            physicalMemoryBytes: process.physicalMemory,
            logicalProcessorCount: process.processorCount,
            operatingSystem: process.operatingSystemVersionString,
            configuration: "SwiftPM Release test executable; one workload per measurement",
            thermalStateAtStart: thermalAtStart,
            thermalStateAtEnd: String(describing: process.thermalState),
            lowPowerModeAtStart: lowPowerAtStart,
            lowPowerModeAtEnd: process.isLowPowerModeEnabled,
            warmupRuns: 1,
            samplesSeconds: times,
            medianSeconds: sorted[3],
            minimumSeconds: sorted[0],
            maximumSeconds: sorted[6],
            resultChecks: 8,
            measurementScope:
                "Fixture and reference preparation, full equality, verification SHA-256 and report encoding excluded; warm process, no cache flush; no UI, energy or release threshold claim"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try (encoder.encode(report) + Data("\n".utf8)).write(
            to: output.appendingPathComponent(identifier + ".json"), options: .atomic)
    #endif
}

/// Returns a stable checksum for synthetic benchmark data outside the timed interval.
public func pipelineBenchmarkDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// Encodes synthetic regression values with stable key order before checksumming them.
public func pipelineBenchmarkDigest(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return pipelineBenchmarkDigest(try encoder.encode(value))
}
