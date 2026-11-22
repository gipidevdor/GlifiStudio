// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiKit

#if DEBUG
    #error("Source lookup measurements require a Release build without DEBUG.")
#endif

private struct Workload: Sendable {
    let name: String
    let sources: [GlifiStudioProjectSource]
    let queries: [String]
}

private struct Measurements: Codable {
    let samplesMilliseconds: [Double]
    let medianMilliseconds: Double
    let minimumMilliseconds: Double
    let maximumMilliseconds: Double
}

private struct ScenarioReport: Codable {
    let name: String
    let sourceCount: Int
    let queryCount: Int
    let inputSHA256: String
    let outputSHA256: String
    let output: [Int?]
    let endToEnd: Measurements
    let constructionOnly: Measurements
    let lookupOnly: Measurements
}

private struct Report: Encodable {
    let schema = "studio.glifi.benchmark.source-lookup.v1"
    let warmupCount = 2
    let sampleCount = 7
    let configuration = "Release; DEBUG absent"
    let architecture: String
    let operatingSystem: String
    let processorCount: Int
    let physicalMemoryBytes: UInt64
    let thermalState: String
    let lowPowerModeEnabled: Bool
    let implementationSHA256: String
    let scenarios: [ScenarioReport]
}

private enum BenchmarkFailure: Error {
    case invalidArguments
    case inconsistentOutput
    case incorrectLookup
    case invalidFixture
}

@main
private struct SourceLookupBenchmark {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw BenchmarkFailure.invalidArguments }
        try checkLookupSemantics()
        let sizes = [(10, 3), (100, 1_000), (1_000, 0), (1_000, 1), (1_000, 50), (1_000, 10_000)]
        var scenarios: [ScenarioReport] = []
        for (sourceCount, queryCount) in sizes {
            let sources = try makeSources(count: sourceCount)
            let missing = "source-revision:00000000-0000-4000-8000-000000000000"
            let choices = [
                sources[0].sourceRevisionID,
                sources[sourceCount / 2].sourceRevisionID,
                sources[sourceCount - 1].sourceRevisionID, missing,
            ]
            let queries = try independentQueries(
                (0..<queryCount).map { choices[$0 % choices.count] })
            let workload = Workload(
                name: "sources-\(sourceCount)-lookups-\(queryCount)", sources: sources,
                queries: queries)
            scenarios.append(try measure(workload))
        }
        let earlySources = try makeSources(count: 1_000)
        scenarios.append(
            try measure(
                Workload(
                    name: "sources-1000-lookups-10000-first-only", sources: earlySources,
                    queries: independentQueries(
                        Array(repeating: earlySources[0].sourceRevisionID, count: 10_000)))))
        #if arch(arm64)
            let architecture = "arm64"
        #elseif arch(x86_64)
            let architecture = "x86_64"
        #else
            let architecture = "other"
        #endif
        let process = ProcessInfo.processInfo
        let report = Report(
            architecture: architecture, operatingSystem: process.operatingSystemVersionString,
            processorCount: process.processorCount, physicalMemoryBytes: process.physicalMemory,
            thermalState: thermalName(process.thermalState),
            lowPowerModeEnabled: process.isLowPowerModeEnabled,
            implementationSHA256: BenchmarkBuildStamp.implementationSHA256,
            scenarios: scenarios)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: URL(filePath: CommandLine.arguments[1]), options: .atomic)
    }

    @MainActor @inline(never)
    private static func construct(_ sources: [GlifiStudioProjectSource]) -> StudioSourceLookup {
        StudioSourceLookup(sources: sources)
    }

    @MainActor @inline(never)
    private static func resolve(_ lookup: StudioSourceLookup, queries: [String]) -> [Int?] {
        queries.map { lookup.index(of: $0) }
    }

    @MainActor @inline(never)
    private static func project(_ workload: Workload) -> (StudioSourceLookup, [Int?]) {
        let lookup = construct(workload.sources)
        return (lookup, resolve(lookup, queries: workload.queries))
    }

    @MainActor
    private static func measure(_ workload: Workload) throws -> ScenarioReport {
        let clock = ContinuousClock()
        let expected = resolve(construct(workload.sources), queries: workload.queries)
        for _ in 0..<2 {
            let frame = project(workload)
            guard frame.1 == expected else { throw BenchmarkFailure.inconsistentOutput }
            _ = frame.0.index(of: workload.sources[0].sourceRevisionID)
        }
        var batchSamples: [Double] = []
        var constructionSamples: [Double] = []
        var lookupSamples: [Double] = []
        for _ in 0..<7 {
            let start = clock.now
            let frame = project(workload)
            let end = clock.now
            guard frame.1 == expected, frame.0.index(of: workload.sources[0].sourceRevisionID) == 0
            else { throw BenchmarkFailure.inconsistentOutput }
            batchSamples.append(milliseconds(start.duration(to: end)))
        }
        for _ in 0..<7 {
            let start = clock.now
            let lookup = construct(workload.sources)
            let end = clock.now
            guard lookup.index(of: workload.sources[0].sourceRevisionID) == 0 else {
                throw BenchmarkFailure.incorrectLookup
            }
            constructionSamples.append(milliseconds(start.duration(to: end)))
        }
        for _ in 0..<7 {
            let lookup = construct(workload.sources)
            let start = clock.now
            let rows = resolve(lookup, queries: workload.queries)
            let end = clock.now
            guard rows == expected, lookup.index(of: workload.sources[0].sourceRevisionID) == 0
            else { throw BenchmarkFailure.inconsistentOutput }
            lookupSamples.append(milliseconds(start.duration(to: end)))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var inputBytes = try encoder.encode(workload.sources)
        inputBytes.append(try encoder.encode(workload.queries))
        return ScenarioReport(
            name: workload.name, sourceCount: workload.sources.count,
            queryCount: workload.queries.count,
            inputSHA256: digest(inputBytes), outputSHA256: digest(try encoder.encode(expected)),
            output: expected, endToEnd: statistics(batchSamples),
            constructionOnly: statistics(constructionSamples), lookupOnly: statistics(lookupSamples)
        )
    }

    private static func statistics(_ values: [Double]) -> Measurements {
        let sorted = values.sorted()
        return Measurements(
            samplesMilliseconds: values, medianMilliseconds: sorted[sorted.count / 2],
            minimumMilliseconds: sorted[0], maximumMilliseconds: sorted[sorted.count - 1])
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1e15
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func makeSources(count: Int) throws -> [GlifiStudioProjectSource] {
        let records: [[String: Any]] = try (0..<count).map { index in
            let suffix = digest(Data("synthetic-source-\(index)".utf8))
            return [
                "sourceID": "source:\(try fixtureUUID(seed: "source-\(index)"))",
                "sourceRevisionID": "source-revision:\(try fixtureUUID(seed: "revision-\(index)"))",
                "format": GlifiStudioTextFormat.plainText.rawValue,
                "contentDigest": "sha256:\(suffix)", "byteCount": index + 1,
            ]
        }
        return try JSONDecoder().decode(
            [GlifiStudioProjectSource].self, from: JSONSerialization.data(withJSONObject: records)
        ).sorted { $0.sourceRevisionID < $1.sourceRevisionID }
    }

    private static func fixtureUUID(seed: String) throws -> String {
        var digits = Array(digest(Data(seed.utf8)).prefix(32))
        digits[12] = "4"
        digits[16] = "8"
        let compact = String(digits)
        let uuid = [
            String(compact.prefix(8)), String(compact.dropFirst(8).prefix(4)),
            String(compact.dropFirst(12).prefix(4)), String(compact.dropFirst(16).prefix(4)),
            String(compact.dropFirst(20).prefix(12)),
        ].joined(separator: "-")
        guard UUID(uuidString: uuid)?.uuidString.lowercased() == uuid else {
            throw BenchmarkFailure.invalidFixture
        }
        return uuid
    }

    private static func independentQueries(_ values: [String]) throws -> [String] {
        try JSONDecoder().decode([String].self, from: JSONEncoder().encode(values))
    }

    @MainActor private static func checkLookupSemantics() throws {
        let sources = try makeSources(count: 3)
        let order = [sources[2], sources[0], sources[1], sources[0]]
        let lookup = construct(order)
        guard lookup.index(of: sources[2].sourceRevisionID) == 0,
            lookup.index(of: sources[0].sourceRevisionID) == 1,
            lookup.index(of: sources[1].sourceRevisionID) == 2,
            lookup.index(of: "unknown") == nil,
            construct([]).index(of: sources[0].sourceRevisionID) == nil
        else { throw BenchmarkFailure.incorrectLookup }
    }

    private static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
