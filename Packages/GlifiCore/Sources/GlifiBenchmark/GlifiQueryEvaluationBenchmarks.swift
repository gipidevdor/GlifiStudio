// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

struct QueryEvaluationBenchmarkReport: Encodable {
    let device: String
    let operatingSystem: String
    let physicalMemoryBytes: UInt64
    let thermalStateAtStart: String
    let thermalStateAtEnd: String
    let lowPowerModeAtStart: Bool
    let lowPowerModeAtEnd: Bool
    let configuration: String
    let cachePolicy: String
    let warmUpRuns: Int
    let samples: Int
    let statistic: String
    let threshold: String
    let sourceHashes: [String: String]
    let measurements: [Measurement]
    let rawSamplesSeconds: [String: [Double]]
}

/// Compares unchanged query semantics with fixture construction outside the timer.
func queryEvaluationBenchmarkReport() throws -> QueryEvaluationBenchmarkReport {
    let sources = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let sourcePaths = [
        "GlifiCore/GlifiQueryEvaluator.swift", "GlifiCore/GlifiQueryModel.swift",
        "GlifiBenchmark/GlifiQueryEvaluationBenchmarks.swift", "GlifiBenchmark/main.swift",
    ]
    func sourceHashes() throws -> [String: String] {
        try Dictionary(
            uniqueKeysWithValues: sourcePaths.map {
                (
                    $0,
                    "sha256:"
                        + SHA256.hash(data: try Data(contentsOf: sources.appending(path: $0)))
                        .map { String(format: "%02x", $0) }.joined()
                )
            })
    }
    let initialHashes = try sourceHashes()
    let initialThermal = queryBenchmarkThermalState()
    let initialLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    let fixtures: [(id: String, text: String, query: String, intervals: [(Int, Int)])] = [
        (
            "ordered-proximity-100x100", String(repeating: "a x b y ", count: 100),
            "a BEFORE/1 b", (0..<100).map { ($0 * 8, $0 * 8 + 5) }
        ),
        (
            "symmetric-proximity-100x100", String(repeating: "b a x y ", count: 100),
            "a NEAR/0 b", (0..<100).map { ($0 * 8, $0 * 8 + 3) }
        ),
        (
            "boolean-union-1000-tokens", String(repeating: "a b ", count: 500),
            "a OR b", (0..<1_000).map { ($0 * 2, $0 * 2 + 1) }
        ),
    ]
    var measurements: [Measurement] = []
    var raw: [String: [Double]] = [:]
    for fixture in fixtures {
        let revision = try SourceRevisionID(
            canonicalValue: "source-revision:00000000-0000-0000-0000-000000000302")
        let imported = try GlifiTextImporter().importText(
            from: Data(fixture.text.utf8), format: .plainText, sourceRevisionID: revision)
        let tokenization = try GlifiItalianTokenizer().tokenize(imported.text)
        let query = try GlifiQueryParser().parse(fixture.query)
        let expected = try fixture.intervals.map {
            try GlifiUTF8Range(start: $0.0, end: $0.1)
        }
        let evaluator = GlifiQueryEvaluator()
        let reference = try evaluator.evaluate(query, in: imported, tokenization: tokenization)
        guard reference.matchedScope, !reference.isTruncated,
            reference.matches.map(\.range) == expected
        else { throw QueryBenchmarkFailure.inconsistentResult }
        var times: [Double] = []
        for _ in 0..<7 {
            let start = ContinuousClock.now
            let observed = try evaluator.evaluate(query, in: imported, tokenization: tokenization)
            let elapsed = ContinuousClock.now - start
            guard observed == reference else { throw QueryBenchmarkFailure.inconsistentResult }
            times.append(
                Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        }
        raw[fixture.id] = times
        measurements.append(
            summary(
                fixture.id, "GS-QRY-001; RQ-009, RQ-042",
                "deterministic repeated ASCII; import/tokenization/parser outside timer",
                times,
                check: "source=\(imported.contentDigest); query=\(reference.queryDigest); "
                    + "matches=\(expected.count); independent exact UTF-8 intervals; "
                    + "truncated=false; complete equality 8/8 evaluations"))
    }
    guard try sourceHashes() == initialHashes else { throw QueryBenchmarkFailure.sourcesChanged }
    return QueryEvaluationBenchmarkReport(
        device: hardwareModel(),
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        thermalStateAtStart: initialThermal, thermalStateAtEnd: queryBenchmarkThermalState(),
        lowPowerModeAtStart: initialLowPower,
        lowPowerModeAtEnd: ProcessInfo.processInfo.isLowPowerModeEnabled,
        configuration: "Release, GlifiBenchmark --query-evaluation",
        cachePolicy: "warm process; setup and one untimed warm-up; no cache flush",
        warmUpRuns: 1, samples: 7, statistic: "median, min, max wall-clock seconds per evaluation",
        threshold: "observational before/after comparison; no release gate",
        sourceHashes: initialHashes, measurements: measurements, rawSamplesSeconds: raw)
}

private func queryBenchmarkThermalState() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "nominal"
    case .fair: "fair"
    case .serious: "serious"
    case .critical: "critical"
    @unknown default: "unknown"
    }
}

private enum QueryBenchmarkFailure: Error {
    case inconsistentResult, sourcesChanged
}
