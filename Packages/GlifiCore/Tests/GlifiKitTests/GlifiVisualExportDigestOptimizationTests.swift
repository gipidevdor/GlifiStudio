// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiKit

@Test("I digest degli export coincidono con i vettori SHA-256 e il formatter completo")
func visualExportDigestEncodingMatchesFormatter() {
    #expect(
        GlifiStudioVisualExport.digest(Data())
            == "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    #expect(
        GlifiStudioVisualExport.digest(Data("abc".utf8))
            == "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    for payload in exportDigestPayloads() {
        let actual = GlifiStudioVisualExport.digest(payload)
        #expect(actual == exportDigestFormatterReference(payload))
        #expect(actual.utf8.count == 71)
        #expect(
            actual.utf8.dropFirst(7).allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            })
    }
}

@Test("Gli export conservano bundle e manifest completi e misurano solo workload espliciti")
func visualExportDigestOptimizationBenchmarks() throws {
    let small = exportDigestView(rows: 16)
    let reference = try exportDigestReferenceBundle(small)
    #expect(try exportDigestBundle(small) == reference.files)
    #expect(try GlifiStudioVisualExport.verify(reference.files) == reference.manifest)
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }

    let payloads = exportDigestPayloads()
    let calls = 20_000
    let expectedPool = payloads.map(exportDigestFormatterReference)
    let expectedDigests = (0..<calls).map { expectedPool[$0 % expectedPool.count] }
    try measurePipelineOptimization(
        identifier: "visual-export-digest-20000",
        generator:
            "256 complete binary/Unicode payloads of 0...4096 bytes; payload i=(call%256); "
            + "20000 full CryptoKit SHA-256 plus canonical digest encodings; fixed arithmetic generator",
        fixtureDigest: try pipelineBenchmarkDigest(
            ExportDigestPayloadFixture(payloads: payloads, calls: calls)),
        expected: expectedDigests,
        body: {
            (0..<calls).map { GlifiStudioVisualExport.digest(payloads[$0 % payloads.count]) }
        },
        checksum: { try pipelineBenchmarkDigest($0) })

    let bundleCalls = 128
    try measurePipelineOptimization(
        identifier: "visual-export-small-bundle-128",
        generator:
            "16-row synthetic collocation view; Unicode, quotes, CRLF and missing cells; "
            + "128 complete bundle calls at fixed project/generation/date; no filesystem",
        fixtureDigest: try pipelineBenchmarkDigest(
            ExportDigestViewFixture(view: small, calls: bundleCalls)),
        expected: Array(repeating: reference.files, count: bundleCalls),
        body: { try (0..<bundleCalls).map { _ in try exportDigestBundle(small) } },
        checksum: { try pipelineBenchmarkDigest($0) })

    let large = exportDigestView(rows: 10_000)
    let largeReference = try exportDigestReferenceBundle(large)
    let verificationCalls = 4
    try measurePipelineOptimization(
        identifier: "visual-export-large-verification-4",
        generator:
            "10000-row synthetic collocation view; Unicode/quoted multiline CSV; "
            + "four complete verify calls over a prebuilt reference bundle; all integrity checks included",
        fixtureDigest: try pipelineBenchmarkDigest(
            ExportDigestVerificationFixture(files: largeReference.files, calls: verificationCalls)),
        expected: Array(repeating: largeReference.manifest, count: verificationCalls),
        body: {
            try (0..<verificationCalls).map { _ in
                try GlifiStudioVisualExport.verify(largeReference.files)
            }
        },
        checksum: { try pipelineBenchmarkDigest($0) })
}

private struct ExportDigestPayloadFixture: Encodable {
    let payloads: [Data]
    let calls: Int
}

private struct ExportDigestViewFixture: Encodable {
    let view: GlifiStudioVisualization
    let calls: Int
    let projectID = "synthetic:export-digest-project"
    let generation = 7
    let createdAtEpochSeconds: Double = 1_800_000_000
}

private struct ExportDigestVerificationFixture: Encodable {
    let files: [String: Data]
    let calls: Int
}

private func exportDigestPayloads() -> [Data] {
    var payloads = [
        Data(), Data("abc".utf8), Data((0...255).map { UInt8($0) }),
        Data("città e\u{301}/é 日本語 👩‍🔬, \"CSV\"\r\nsecond line\0".utf8),
    ]
    let lengths = [1, 3, 31, 64, 255, 1_024, 4_096]
    for index in 4..<256 {
        let length = lengths[index % lengths.count]
        payloads.append(
            Data(
                (0..<length).map { position in
                    UInt8(truncatingIfNeeded: (index * 37 + position * 53) ^ (position / 7))
                }))
    }
    return payloads
}

private func exportDigestFormatterReference(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func exportDigestView(rows: Int) -> GlifiStudioVisualization {
    let tableRows = (0..<rows).map { index in
        GlifiStudioVisualRow(
            id: "datum:\(index)",
            cells: [
                .text("città, \"β\"\r\nriga \(index) 👩‍🔬"), .integer(index + 1),
                .decimal(Double(index % 31) / 8 - 1),
                index.isMultiple(of: 3) ? .missing : .text("e\u{301}/é/日本語"),
            ])
    }
    return GlifiStudioVisualization(
        specificationIdentifier: "visual-spec.collocation-table.v1", family: .collocationTable,
        titleKey: "visual.title.collocation-table", artifactID: "artifact:synthetic-export-digest",
        analysisNodeID: "node:synthetic-export-digest", analysisIdentifier: "synthetic.export.v1",
        methodIdentifier: "synthetic.association.v1", axes: [], requiresEqualAspect: false,
        marks: [],
        table: GlifiStudioVisualTable(
            columns: ["term", "count", "score", "annotation"].map {
                GlifiStudioVisualColumn(identifier: $0, labelKey: "visual.column.\($0)")
            }, rows: tableRows),
        totalObservationCount: rows, visibleObservationCount: rows, reductionIdentifier: nil,
        layoutIdentifier: nil, emphasisIdentifier: nil, excludedLabels: [],
        caveatKeys: ["caveat.visual.synthetic-fixture"],
        summaryKey: "visual.summary.collocation-table",
        summaryArguments: [GlifiStudioVisualArgument(name: "rows", value: .integer(rows))])
}

private func exportDigestBundle(_ view: GlifiStudioVisualization) throws -> [String: Data] {
    try GlifiStudioVisualExport.bundle(
        view, projectID: "synthetic:export-digest-project", generation: 7,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000))
}

/// Full v1 construction using an independent CSV renderer and the previous digest formatter.
private func exportDigestReferenceBundle(
    _ view: GlifiStudioVisualization
) throws -> (files: [String: Data], manifest: GlifiStudioVisualExportManifest) {
    let csv = Data(exportDigestCSVReference(view).utf8)
    let specification = try exportDigestCanonicalJSON(view)
    let manifest = GlifiStudioVisualExportManifest(
        schema: "studio.glifi.visual-export-manifest", schemaVersion: 1,
        createdAt: "2027-01-15T08:00:00Z", softwareIdentifier: "GlifiCore-0.1.0",
        projectID: "synthetic:export-digest-project", generation: 7,
        artifactID: view.artifactID, analysisNodeID: view.analysisNodeID,
        analysisIdentifier: view.analysisIdentifier, methodIdentifier: view.methodIdentifier,
        specificationIdentifier: view.specificationIdentifier,
        totalObservationCount: view.totalObservationCount,
        visibleObservationCount: view.visibleObservationCount,
        reductionIdentifier: view.reductionIdentifier, layoutIdentifier: view.layoutIdentifier,
        caveatKeys: view.caveatKeys,
        files: [
            GlifiStudioVisualExportFile(
                path: "view-spec.json", mediaType: "application/json",
                byteCount: specification.count,
                sha256: exportDigestFormatterReference(specification)),
            GlifiStudioVisualExportFile(
                path: "view.csv", mediaType: "text/csv", byteCount: csv.count,
                sha256: exportDigestFormatterReference(csv)),
        ])
    return (
        [
            "view.csv": csv, "view-spec.json": specification,
            "visual-export-manifest.json": try exportDigestCanonicalJSON(manifest),
        ], manifest
    )
}

private func exportDigestCanonicalJSON(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
    return try encoder.encode(value) + Data("\n".utf8)
}

private func exportDigestCSVReference(_ view: GlifiStudioVisualization) -> String {
    let special = CharacterSet(charactersIn: ",\"\r\n")
    func field(_ text: String) -> String {
        if text.rangeOfCharacter(from: special) == nil { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    let header = (["datum"] + view.table.columns.map(\.identifier)).map(field).joined(
        separator: ",")
    let rows = view.table.rows.map { row in
        let values = row.cells.map { cell -> String in
            switch cell {
            case let .text(value): field(value)
            case let .integer(value): String(value)
            case let .decimal(value): String(value)
            case .missing: ""
            }
        }
        return ([field(row.id)] + values).joined(separator: ",")
    }
    return ([header] + rows).joined(separator: "\r\n") + "\r\n"
}
