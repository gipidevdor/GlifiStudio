// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

struct ValidatedReadBenchmarkReport: Encodable {
    let device: String
    let operatingSystem: String
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

/// Measures verified Core reads and an absent normalized query independently of setup.
func validatedReadBenchmarkReport() async throws -> ValidatedReadBenchmarkReport {
    let initialHashes = try validatedBenchmarkSourceHashes()
    let initialThermal = validatedBenchmarkThermalState()
    let initialLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var measured: [ValidatedBenchmarkSamples] = []
    for mebibytes in [1, 8, 32] {
        measured += try await validatedPayloadMeasurements(mebibytes: mebibytes)
    }
    measured.append(try await absentNormalizedQueryMeasurement())
    guard try validatedBenchmarkSourceHashes() == initialHashes else {
        throw ValidatedBenchmarkFailure.sourcesChanged
    }
    #if DEBUG
        let configuration = "Debug, GlifiBenchmark --validated-reads-query"
    #else
        let configuration = "Release, GlifiBenchmark --validated-reads-query"
    #endif
    return ValidatedReadBenchmarkReport(
        device: hardwareModel(),
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        thermalStateAtStart: initialThermal,
        thermalStateAtEnd: validatedBenchmarkThermalState(),
        lowPowerModeAtStart: initialLowPower,
        lowPowerModeAtEnd: ProcessInfo.processInfo.isLowPowerModeEnabled,
        configuration: configuration,
        cachePolicy: "warm OS page cache; setup and one untimed warm-up; no cache flush",
        warmUpRuns: 1, samples: 7, statistic: "median, min, max wall-clock seconds",
        threshold: "observational before/after comparison; no release gate",
        sourceHashes: initialHashes, measurements: measured.map(\.measurement),
        rawSamplesSeconds: Dictionary(
            uniqueKeysWithValues: measured.map { ($0.measurement.identifier, $0.seconds) }))
}

private func validatedPayloadMeasurements(mebibytes: Int) async throws
    -> [ValidatedBenchmarkSamples]
{
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiValidatedReadBenchmark-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let packageURL = root.appending(path: "Synthetic.glifi")
    let project = try GlifiProjectPackage.create(
        at: packageURL,
        projectID: ProjectID(
            canonicalValue: String(format: "project:00000000-0000-0000-0000-%012d", mebibytes)))
    let sourceBytes = validatedBenchmarkUTF8(byteCount: mebibytes * 1_048_576)
    let revision = try SourceRevisionID(
        canonicalValue: String(
            format: "source-revision:00000000-0000-0000-0000-%012d", mebibytes))
    let imported = try GlifiTextImporter().importText(
        from: sourceBytes, format: .plainText, sourceRevisionID: revision)
    let sourceID = try SourceID(
        canonicalValue: String(format: "source:00000000-0000-0000-0000-%012d", mebibytes))
    let sourceSnapshot = try await project.importText(imported, sourceID: sourceID)
    let descriptor = try validatedBenchmarkDescriptor(snapshot: sourceSnapshot, revision: revision)
    let payload = ValidatedBenchmarkPayload(value: String(repeating: "a", count: sourceBytes.count))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let artifactBytes = try encoder.encode(payload)
    let withArtifact = try await project.storeArtifact(payload, descriptor: descriptor)
    guard let artifact = withArtifact.artifacts.first else {
        throw ValidatedBenchmarkFailure.invalidFixture
    }
    // Advance the manifest so read-only recovery selects the generation containing both payloads.
    let currentSnapshot = try await project.importText(
        GlifiTextImporter().importText(
            from: Data("Unrelated synthetic source.".utf8), format: .plainText,
            sourceRevisionID: SourceRevisionID(
                canonicalValue: String(
                    format: "source-revision:00000000-0000-0000-0000-%012d", mebibytes + 1_000))),
        sourceID: SourceID(
            canonicalValue: String(
                format: "source:00000000-0000-0000-0000-%012d", mebibytes + 1_000)))
    let recovery = try GlifiProjectPackage.openReadOnlyRecovery(at: packageURL)
    guard recovery.snapshot.generation == withArtifact.generation,
        recovery.snapshot.artifacts.contains(where: { $0.artifactID == artifact.artifactID })
    else {
        throw ValidatedBenchmarkFailure.invalidFixture
    }

    let sourceTimes = try await validatedBenchmarkTimes(expected: sourceBytes) {
        try await project.sourceData(for: revision)
    }
    let recoveryTimes = try await validatedBenchmarkTimes(expected: sourceBytes) {
        try recovery.sourceData(for: revision)
    }
    let artifactTimes = try await validatedBenchmarkTimes(expected: artifactBytes) {
        try await project.artifactData(for: artifact.artifactID)
    }
    let generator =
        "deterministic repeated Italian UTF-8; source \(sourceBytes.count) bytes; "
        + "ASCII JSON artifact \(artifactBytes.count) bytes; setup/import/recovery outside timer"
    let sourceCheck =
        "bytes=\(sourceBytes.count); \(validatedBenchmarkDigest(sourceBytes)); "
        + "sourceID=\(sourceID.canonicalValue); root=\(currentSnapshot.sourceRootDigest); "
        + "exact equality 8/8 reads"
    let artifactCheck =
        "bytes=\(artifactBytes.count); \(validatedBenchmarkDigest(artifactBytes)); "
        + "artifactID=\(artifact.artifactID.canonicalValue); descriptor=\(artifact.descriptorDigest); "
        + "nodeID=\(artifact.node.id.canonicalValue); exact equality 8/8 reads"
    return [
        validatedReadSummary(
            "validated-source-read-\(mebibytes)mib", "RQ-009, RQ-043, RQ-044", generator,
            sourceTimes, check: sourceCheck),
        validatedReadSummary(
            "validated-recovery-source-read-\(mebibytes)mib", "RQ-009, RQ-043, RQ-044", generator,
            recoveryTimes, check: sourceCheck),
        validatedReadSummary(
            "validated-artifact-read-\(mebibytes)mib", "RQ-009, RQ-043, RQ-044", generator,
            artifactTimes, check: artifactCheck),
    ]
}

private func absentNormalizedQueryMeasurement() async throws -> ValidatedBenchmarkSamples {
    let text = String(repeating: "Città PERCHÉ caffè già élite naïve über résumé ", count: 12_500)
    let revision = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000201")
    let imported = try GlifiTextImporter().importText(
        from: Data(text.utf8), format: .plainText, sourceRevisionID: revision)
    let tokenization = try GlifiItalianTokenizer().tokenize(imported.text)
    guard tokenization.tokens.count == 100_000 else {
        throw ValidatedBenchmarkFailure.invalidFixture
    }
    let query = try GlifiQueryParser().parse("normalized:ZZZZASSENTEÉ")
    let expected = GlifiQueryResult(
        queryDigest: try query.canonicalDigest(), sourceRevisionID: revision,
        matchedScope: false, matches: [], isTruncated: false)
    let times = try await validatedBenchmarkTimes(expected: expected) {
        try GlifiQueryEvaluator().evaluate(query, in: imported, tokenization: tokenization)
    }
    return validatedReadSummary(
        "normalized-absent-term-100000-unicode-tokens", "RF-080, RQ-009, RQ-042",
        "100,000 tokens; eight repeated Unicode forms; import/tokenization/parser outside timer",
        times,
        check: "source=\(imported.contentDigest); query=\(expected.queryDigest); "
            + "matchedScope=false; matches=0; truncated=false; exact equality 8/8 evaluations")
}

private struct ValidatedBenchmarkSamples {
    let measurement: Measurement
    let seconds: [Double]
}

private func validatedReadSummary(
    _ identifier: String, _ requirement: String, _ generator: String,
    _ times: [Double], check: String
) -> ValidatedBenchmarkSamples {
    ValidatedBenchmarkSamples(
        measurement: summary(identifier, requirement, generator, times, check: check),
        seconds: times)
}

/// Every timed result is consumed and compared after stopping the clock.
private func validatedBenchmarkTimes<Value: Equatable>(
    expected: Value, body: () async throws -> Value
) async throws -> [Double] {
    guard try await body() == expected else { throw ValidatedBenchmarkFailure.inconsistentResult }
    var times: [Double] = []
    times.reserveCapacity(7)
    for _ in 0..<7 {
        let start = ContinuousClock.now
        let observed = try await body()
        let elapsed = ContinuousClock.now - start
        guard observed == expected else { throw ValidatedBenchmarkFailure.inconsistentResult }
        times.append(
            Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
    }
    return times
}

private func validatedBenchmarkUTF8(byteCount: Int) -> Data {
    let pattern = Data("Glifi benchmark: città, perché, già.\n".utf8)
    var bytes = Data()
    bytes.reserveCapacity(byteCount)
    for _ in 0..<(byteCount / pattern.count) { bytes.append(pattern) }
    bytes.append(Data(repeating: 0x20, count: byteCount - bytes.count))
    return bytes
}

private func validatedBenchmarkDescriptor(
    snapshot: GlifiProjectSnapshot, revision: SourceRevisionID
) throws -> GlifiAnalysisDescriptor {
    try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.validated-read-benchmark",
        algorithmIdentifier: "algorithm.validated-read-benchmark", algorithmVersion: "1",
        corpusIdentifier: "project-source-root-v1",
        corpusVersionDigest: snapshot.corpusVersionDigest(for: [revision]),
        selectionIdentifier: "selection.synthetic.v1",
        analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: [], linguisticProfileIdentifiers: [],
        representationIdentifier: "representation.synthetic.v1", resolvedParameters: [:],
        seedPolicyIdentifier: "none-v1", backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1", determinismClass: .d0,
        outputSchemaIdentifier: ValidatedBenchmarkPayload.outputSchemaIdentifier,
        softwareIdentifier: "GlifiCore-0.1", dependencies: [], sourceRevisionIDs: [revision])
}

private func validatedBenchmarkDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func validatedBenchmarkThermalState() -> String {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "nominal"
    case .fair: "fair"
    case .serious: "serious"
    case .critical: "critical"
    @unknown default: "unknown"
    }
}

private func validatedBenchmarkSourceHashes() throws -> [String: String] {
    let sources = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let paths = [
        "GlifiCore/GlifiProjectPackage.swift", "GlifiCore/GlifiQueryEvaluator.swift",
        "GlifiBenchmark/GlifiValidatedReadBenchmarks.swift", "GlifiBenchmark/main.swift",
    ]
    return try Dictionary(
        uniqueKeysWithValues: paths.map {
            ($0, try validatedBenchmarkDigest(Data(contentsOf: sources.appending(path: $0))))
        })
}

private struct ValidatedBenchmarkPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.validated-read-benchmark.v1"
    let value: String
}

private enum ValidatedBenchmarkFailure: Error {
    case invalidFixture, inconsistentResult, sourcesChanged
}
