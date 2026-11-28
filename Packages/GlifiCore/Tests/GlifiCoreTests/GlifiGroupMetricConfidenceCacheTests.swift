// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La revisione 4 dei confronti conserva la storia e gli intervalli finiti alla frontiera")
func groupMetricConfidenceRevisionPreservesHistory() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiConfidenceCache-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer {
        do { try FileManager.default.removeItem(at: root) } catch { Issue.record(error) }
    }
    let url = root.appending(path: "Confidence.glifi", directoryHint: .isDirectory)
    let project = try GlifiProjectPackage.create(at: url)
    var revisions: [SourceRevisionID] = []
    for (index, length) in [1, 2, 3, 2, 3, 4].enumerated() {
        let revision = try SourceRevisionID(
            canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index)")
        let text = Array(repeating: "casa", count: length).joined(separator: " ")
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8), format: .plainText, sourceRevisionID: revision)
        _ = try await project.importText(imported)
        revisions.append(revision)
    }
    let groups = [Array(revisions.prefix(3)), Array(revisions.suffix(3))]
    let options = try GlifiGroupComparisonOptions(
        confidenceLevel: 1.0.nextDown, bootstrapResampleCount: 32,
        permutationMonteCarloCount: 32, resamplingSeed: 334, contrasts: [])
    let engine = GlifiEngine()
    let current = try await engine.compareGroupMetric(
        in: project, groups: groups, metric: .lexicalTokenCount, options: options)
    let interval = try #require(current.value.standardizedDifference)
    #expect(abs(interval.lower + 8.181395349007829) < 1e-12)
    #expect(abs(interval.upper - 6.18139534900783) < 1e-12)
    let snapshot = await project.snapshot()
    let record = try #require(snapshot.artifacts.first { $0.artifactID == current.artifactID })
    #expect(record.node.descriptor.algorithmVersion == "4")

    var descriptor = try #require(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(record.node.descriptor)) as? [String: Any])
    descriptor["algorithmVersion"] = "3"
    let previous = try JSONDecoder().decode(
        GlifiAnalysisDescriptor.self, from: JSONSerialization.data(withJSONObject: descriptor))
    let previousID = try previous.nodeID()
    #expect(previousID != current.analysisNodeID)
    var value = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(current.value)) as? [String: Any])
    value.removeValue(forKey: "standardizedDifference")
    let unavailable = try JSONDecoder().decode(
        GlifiGroupMetricComparison.self, from: JSONSerialization.data(withJSONObject: value))
    #expect(unavailable.standardizedDifference == nil)
    let committed = try await project.storeArtifact(
        GlifiDerivedAnalysisArtifactPayload(analysisNodeID: previousID, result: unavailable),
        descriptor: previous)
    let historical = try #require(committed.artifacts.first { $0.node.id == previousID })
    let bytes = try await project.artifactData(for: historical.artifactID)

    let reopened = try GlifiProjectPackage.open(at: url)
    let result = try await engine.compareGroupMetric(
        in: reopened, groups: groups, metric: .lexicalTokenCount, options: options)
    #expect(result.artifactID == current.artifactID)
    #expect(result.analysisNodeID == current.analysisNodeID)
    #expect(result.value == current.value)
    #expect(await reopened.snapshot() == committed)
    #expect(try await reopened.artifactData(for: historical.artifactID) == bytes)
    let decoded = try JSONDecoder().decode(
        GlifiDerivedAnalysisArtifactPayload<GlifiGroupMetricComparison>.self, from: bytes)
    #expect(decoded.analysisNodeID == previousID)
    #expect(decoded.result.standardizedDifference == nil)
}
