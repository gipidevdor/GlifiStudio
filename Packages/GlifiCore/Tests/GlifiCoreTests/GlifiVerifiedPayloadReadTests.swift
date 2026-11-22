// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Testing

@testable import GlifiCore

private enum VerifiedReadTarget: CaseIterable, Sendable {
    case source, recoverySource, artifact, recoveryArtifact
}

private enum VerifiedReadMutation: CaseIterable, Equatable, Sendable {
    case valid, sameLengthCorruption, truncated, grown, symbolicLink, hardLink, fifo, directory
}

@Test(
    "Le letture di fonti e Artifact, anche in recovery, conservano digest, limiti e no-follow",
    arguments: VerifiedReadTarget.allCases, VerifiedReadMutation.allCases
)
private func verifiedPayloadReadPreservesValidation(
    target: VerifiedReadTarget, mutation: VerifiedReadMutation
) async throws {
    let fixture = try await verifiedReadFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let objectURL = fixture.objectURL(for: target)
    let expected = try Data(contentsOf: objectURL)
    let initial = await fixture.project.snapshot()
    let manifestURL = fixture.packageURL.appending(path: "manifest.json")
    let manifest = try Data(contentsOf: manifestURL)
    let externalURL = fixture.root.appending(path: "external-canary")
    try expected.write(to: externalURL)
    switch mutation {
    case .valid:
        break
    case .sameLengthCorruption:
        try Data(repeating: 0x58, count: expected.count).write(to: objectURL)
    case .truncated:
        try Data(expected.dropLast()).write(to: objectURL)
    case .grown:
        try (expected + Data([0x58])).write(to: objectURL)
    case .symbolicLink, .hardLink, .fifo, .directory:
        try FileManager.default.removeItem(at: objectURL)
        switch mutation {
        case .symbolicLink:
            try FileManager.default.createSymbolicLink(
                at: objectURL, withDestinationURL: externalURL)
        case .hardLink:
            try FileManager.default.linkItem(at: externalURL, to: objectURL)
        case .fifo:
            try #require(mkfifo(objectURL.path, 0o600) == 0)
        case .directory:
            try FileManager.default.createDirectory(
                at: objectURL, withIntermediateDirectories: false)
        case .valid, .sameLengthCorruption, .truncated, .grown:
            Issue.record("A regular-file mutation reached the replacement branch")
        }
    }

    if mutation == .valid {
        #expect(try await fixture.read(target) == expected)
    } else {
        do {
            _ = try await fixture.read(target)
            Issue.record("An invalid payload was returned")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.retryDisposition == .never)
            #expect(failure.arguments.isEmpty)
            if mutation == .sameLengthCorruption || mutation == .truncated {
                let code: String
                switch target {
                case .source, .recoverySource: code = "project.object-digest-mismatch"
                case .artifact, .recoveryArtifact: code = "project.artifact-digest-mismatch"
                }
                #expect(failure.code == code)
            }
        }
    }
    #expect(await fixture.project.snapshot() == initial)
    #expect(try Data(contentsOf: manifestURL) == manifest)
    #expect(try Data(contentsOf: externalURL) == expected)
}

@Test(
    "La cancellazione delle letture verificate non muta il package e permette una nuova lettura",
    arguments: VerifiedReadTarget.allCases
)
private func verifiedPayloadReadPreservesCancellation(target: VerifiedReadTarget) async throws {
    let fixture = try await verifiedReadFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let initial = await fixture.project.snapshot()
    let expected = try Data(contentsOf: fixture.objectURL(for: target))
    let read = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await fixture.read(target)
    }
    do {
        _ = try await read.value
        Issue.record("A cancelled payload read succeeded")
    } catch is CancellationError {
        // The low-level package reader preserves cooperative cancellation for its caller.
    }
    #expect(await fixture.project.snapshot() == initial)
    #expect(try await fixture.read(target) == expected)
}

private struct VerifiedReadFixture: Sendable {
    let root: URL
    let packageURL: URL
    let project: GlifiProjectPackage
    let recovery: GlifiProjectPackage.ReadOnlyRecovery
    let sourceRevisionID: SourceRevisionID
    let artifactID: ArtifactID
    let sourceObjectPath: String
    let artifactObjectPath: String

    func objectURL(for target: VerifiedReadTarget) -> URL {
        switch target {
        case .source, .recoverySource: packageURL.appending(path: sourceObjectPath)
        case .artifact, .recoveryArtifact: packageURL.appending(path: artifactObjectPath)
        }
    }

    func read(_ target: VerifiedReadTarget) async throws -> Data {
        switch target {
        case .source: try await project.sourceData(for: sourceRevisionID)
        case .recoverySource: try recovery.sourceData(for: sourceRevisionID)
        case .artifact: try await project.artifactData(for: artifactID)
        case .recoveryArtifact: try recovery.artifactData(for: artifactID)
        }
    }
}

private struct VerifiedReadPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.test-artifact.v1"
    let value: String
}

private func verifiedReadFixture() async throws -> VerifiedReadFixture {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiVerifiedPayloadRead-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    var didComplete = false
    defer {
        if !didComplete { try? FileManager.default.removeItem(at: root) }
    }
    let packageURL = root.appending(path: "Letture.glifi", directoryHint: .isDirectory)
    let project = try GlifiProjectPackage.create(at: packageURL)
    let importer = GlifiTextImporter()
    let source = try importer.importText(
        from: Data("Fonte verificata con città e mare.".utf8), format: .plainText)
    let imported = try await project.importText(source)
    let descriptor = try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.verified-read-test",
        algorithmIdentifier: "algorithm.verified-read-test", algorithmVersion: "1",
        corpusIdentifier: "project-source-root-v1",
        corpusVersionDigest: try imported.corpusVersionDigest(for: [source.sourceRevisionID]),
        selectionIdentifier: "selection.all.v1", analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: ["extract-v1"], linguisticProfileIdentifiers: ["it-token-v1"],
        representationIdentifier: "representation.test.v1", resolvedParameters: [:],
        seedPolicyIdentifier: "none-v1", backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1", determinismClass: .d1,
        outputSchemaIdentifier: VerifiedReadPayload.outputSchemaIdentifier,
        softwareIdentifier: "GlifiCore-0.1", dependencies: [],
        sourceRevisionIDs: [source.sourceRevisionID])
    let stored = try await project.storeArtifact(
        VerifiedReadPayload(value: "Artifact sintetico verificato."), descriptor: descriptor)
    let artifact = try #require(stored.artifacts.first)
    let originalSource = try #require(stored.sources.first)

    // Open an actual previous verified generation, then restore the current source bytes.
    let subsequent = try importer.importText(
        from: Data("Una generazione successiva.".utf8), format: .plainText)
    let latest = try await project.importText(subsequent)
    let laterRecord = try #require(
        latest.sources.first { $0.sourceRevisionID == subsequent.sourceRevisionID })
    let laterURL = packageURL.appending(path: laterRecord.objectPath)
    try Data("corrupted".utf8).write(to: laterURL)
    let recovery = try GlifiProjectPackage.openReadOnlyRecovery(at: packageURL)
    try subsequent.bytes.write(to: laterURL)
    #expect(recovery.snapshot.generation == stored.generation)

    didComplete = true
    return VerifiedReadFixture(
        root: root, packageURL: packageURL, project: project, recovery: recovery,
        sourceRevisionID: source.sourceRevisionID, artifactID: artifact.artifactID,
        sourceObjectPath: originalSource.objectPath, artifactObjectPath: artifact.objectPath)
}
