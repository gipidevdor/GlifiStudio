// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Confidence levels distinguish persisted keyness nodes and their reuse")
func keynessCacheIncludesConfidenceLevelInIdentity() async throws {
    let root = try keynessCacheRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (project, target, reference) = try await keynessCacheProject(in: root)
    let engine = GlifiEngine()
    let standard = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference])
    let options = try GlifiKeynessOptions(
        maximumHypothesisCount: 100_000, lowExpectedCountThreshold: 5, confidenceLevel: 0.8)

    let changed = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference],
        keynessOptions: options)

    #expect(changed.comparison.confidenceLevel == 0.8)
    #expect(changed.artifactID != standard.artifactID)
    #expect(changed.analysisNodeID != standard.analysisNodeID)
    #expect(changed.comparison.comparisonDigest != standard.comparison.comparisonDigest)
    #expect(changed.comparison.terms.map(\.pValue) == standard.comparison.terms.map(\.pValue))
    let snapshot = await project.snapshot()
    let record = try #require(snapshot.artifacts.first { $0.artifactID == changed.artifactID })
    #expect(record.node.descriptor.resolvedParameters["confidenceLevel"] == .decimal(0.8))

    let reused = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference])

    #expect(reused.artifactID == standard.artifactID)
    #expect(reused.comparison.confidenceLevel == 0.95)
    #expect(await project.snapshot().generation == snapshot.generation)
}

@Test("The hypothesis budget remains binding for a cached keyness comparison")
func keynessCacheEnforcesTheCurrentHypothesisBudget() async throws {
    let root = try keynessCacheRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (project, target, reference) = try await keynessCacheProject(in: root)
    let engine = GlifiEngine()
    let initial = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference])
    #expect(initial.comparison.terms.count == 3)
    let snapshot = await project.snapshot()
    let restrictive = try GlifiKeynessOptions(
        maximumHypothesisCount: 2, lowExpectedCountThreshold: 5)

    do {
        _ = try await engine.compareKeyness(
            in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference],
            keynessOptions: restrictive)
        Issue.record("A cached comparison must respect the current hypothesis budget.")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "keyness.hypothesis-limit-exceeded")
        #expect(failure.category == .insufficientResources)
        #expect(failure.retryDisposition == .afterConditionsChange)
        #expect(failure.retainedState == .lastCommittedGeneration)
    }
    #expect(await project.snapshot() == snapshot)
    let sufficient = try GlifiKeynessOptions(
        maximumHypothesisCount: 3, lowExpectedCountThreshold: 5)

    let reused = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference],
        keynessOptions: sufficient)

    #expect(reused.artifactID == initial.artifactID)
    #expect(reused.analysisNodeID == initial.analysisNodeID)
    #expect(await project.snapshot() == snapshot)
}

@Test("A cached keyness confidence mismatch fails without committing another generation")
func keynessCacheRejectsConfidenceMismatchUnderTheRequestedNode() async throws {
    let root = try keynessCacheRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (project, target, reference) = try await keynessCacheProject(in: root)
    let engine = GlifiEngine()
    let original = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference])
    let originalSnapshot = await project.snapshot()
    let originalRecord = try #require(
        originalSnapshot.artifacts.first { $0.artifactID == original.artifactID })
    let options = try GlifiKeynessOptions(
        maximumHypothesisCount: 100_000, lowExpectedCountThreshold: 5, confidenceLevel: 0.8)
    let descriptor = try GlifiAnalysisArtifactDescriptorFactory.keyness(
        snapshot: originalSnapshot,
        targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference],
        linguisticProfileIdentifiers: originalRecord.node.descriptor.linguisticProfileIdentifiers,
        options: options, dependencies: originalRecord.node.descriptor.dependencies)
    let requestedNodeID = try descriptor.nodeID()
    #expect(requestedNodeID != original.analysisNodeID)
    let stored = try await project.storeArtifact(
        GlifiKeynessArtifactPayload(
            analysisNodeID: requestedNodeID, comparison: original.comparison),
        descriptor: descriptor)
    #expect(stored.artifacts.contains { $0.node.id == requestedNodeID })
    let before = await project.snapshot()

    do {
        _ = try await engine.compareKeyness(
            in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference],
            keynessOptions: options)
        Issue.record("The cached payload must match the confidence encoded in its requested node.")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "keyness.descriptor-result-mismatch")
        #expect(failure.category == .invariantViolation)
        #expect(failure.operation == .analyze)
        #expect(failure.retryDisposition == .never)
        #expect(failure.retainedState == .validityUnknown)
    }

    #expect(await project.snapshot() == before)
}

@Test("A keyness descriptor without confidence remains readable after reopening")
func keynessLegacyDescriptorRemainsReadableWithoutReplacingTheCurrentNode() async throws {
    let root = try keynessCacheRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (project, target, reference) = try await keynessCacheProject(in: root)
    let engine = GlifiEngine()
    let original = try await engine.compareKeyness(
        in: project, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference])
    let originalSnapshot = await project.snapshot()
    let originalRecord = try #require(
        originalSnapshot.artifacts.first { $0.artifactID == original.artifactID })
    var object = try #require(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(originalRecord.node.descriptor)) as? [String: Any])
    var parameters = try #require(object["resolvedParameters"] as? [String: Any])
    let removedConfidence = parameters.removeValue(forKey: "confidenceLevel")
    _ = try #require(removedConfidence)
    object["resolvedParameters"] = parameters
    let legacyDescriptor = try JSONDecoder().decode(
        GlifiAnalysisDescriptor.self,
        from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    let legacyNodeID = try legacyDescriptor.nodeID()
    #expect(legacyNodeID != original.analysisNodeID)
    #expect(legacyDescriptor.resolvedParameters["confidenceLevel"] == nil)
    let committed = try await project.storeArtifact(
        GlifiKeynessArtifactPayload(
            analysisNodeID: legacyNodeID, comparison: original.comparison),
        descriptor: legacyDescriptor)
    let legacyRecord = try #require(committed.artifacts.first { $0.node.id == legacyNodeID })
    let originalBytes = try await project.artifactData(for: legacyRecord.artifactID)

    let reopened = try GlifiProjectPackage.open(at: root.appending(path: "Keyness.glifi"))
    let reopenedSnapshot = await reopened.snapshot()
    let reopenedBytes = try await reopened.artifactData(for: legacyRecord.artifactID)
    let payload = try JSONDecoder().decode(GlifiKeynessArtifactPayload.self, from: reopenedBytes)

    #expect(reopenedSnapshot == committed)
    #expect(reopenedBytes == originalBytes)
    #expect(payload.analysisNodeID == legacyNodeID)
    #expect(payload.comparison == original.comparison)
    let current = try await engine.compareKeyness(
        in: reopened, targetSourceRevisionIDs: [target], referenceSourceRevisionIDs: [reference])
    #expect(current.artifactID == original.artifactID)
    #expect(current.analysisNodeID == original.analysisNodeID)
    #expect(current.analysisNodeID != legacyNodeID)
    #expect(current.comparison.confidenceLevel == 0.95)
    #expect(await reopened.snapshot() == reopenedSnapshot)
    #expect(try await reopened.artifactData(for: legacyRecord.artifactID) == originalBytes)
}

private func keynessCacheRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKeynessCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    return root
}

private func keynessCacheProject(in root: URL) async throws -> (
    GlifiProjectPackage, SourceRevisionID, SourceRevisionID
) {
    let project = try GlifiProjectPackage.create(at: root.appending(path: "Keyness.glifi"))
    let target = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000001")
    let reference = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000002")
    for (revision, text) in [(target, "casa casa mare"), (reference, "casa città città")] {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8), format: .plainText, sourceRevisionID: revision)
        _ = try await project.importText(imported)
    }
    return (project, target, reference)
}
