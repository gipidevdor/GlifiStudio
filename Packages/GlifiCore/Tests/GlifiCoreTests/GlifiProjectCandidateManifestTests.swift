// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Testing

@testable import GlifiCore

private enum CandidateCommitKind: CaseIterable, Sendable {
    case importedSource, artifact, qualitative, investigation
}

private enum CandidateMutation: CaseIterable, Sendable {
    case truncated, extraByte, oversizedSparse, symbolicLink, hardLink, fifo, changedDigest
}

@Test(
    "I quattro commit verificano il candidato e pubblicano la nuova generazione",
    arguments: CandidateCommitKind.allCases
)
private func candidateManifestCommitsExpectedGeneration(kind: CandidateCommitKind) async throws {
    try await withCandidateManifestFixture(kind: kind) { fixture in
        let before = await fixture.project.snapshot()
        let committed = try await fixture.commit(nil, .throwFailure)
        #expect(committed.generation == before.generation + 1)
        #expect(await fixture.project.snapshot() == committed)
        #expect(try await GlifiProjectPackage.open(at: fixture.packageURL).snapshot() == committed)
        try await expectOriginalSourcesUnchanged(fixture: fixture, snapshot: before)
    }
}

@Test(
    "Un candidato alterato viene rifiutato prima del publish e il commit sano resta utilizzabile",
    .timeLimit(.minutes(1)),
    arguments: CandidateCommitKind.allCases, CandidateMutation.allCases
)
private func candidateManifestRejectsMutation(
    kind: CandidateCommitKind, mutation: CandidateMutation
) async throws {
    try await withCandidateManifestFixture(kind: kind) { fixture in
        let before = await fixture.project.snapshot()
        let manifestURL = fixture.packageURL.appending(path: "manifest.json")
        let originalManifest = try Data(contentsOf: manifestURL)
        let outsideURL = fixture.packageURL.deletingLastPathComponent().appending(path: "outside")
        let outsideReferenceURL = outsideURL.appendingPathExtension("expected")
        let sentinel = Data("unchanged external synthetic bytes".utf8)
        try sentinel.write(to: outsideURL)
        try sentinel.write(to: outsideReferenceURL)
        let observer = GlifiProjectCommitInterruptionBehavior.observe {
            let transactions = try FileManager.default.contentsOfDirectory(
                at: fixture.packageURL.appending(path: "transactions"),
                includingPropertiesForKeys: [.isDirectoryKey]
            ).filter { $0.lastPathComponent != ".writer.lock" }
            let transaction = try #require(transactions.count == 1 ? transactions.first : nil)
            let candidateURL = transaction.appending(path: "manifest.json")
            try mutateCandidateManifest(
                at: candidateURL, mutation: mutation, outsideURL: outsideURL,
                outsideReferenceURL: outsideReferenceURL)
        }
        do {
            _ = try await fixture.commit(.manifestPrepared, observer)
            Issue.record("An altered candidate was published")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.retryDisposition == .never)
            #expect(failure.retainedState == .readOnlyRecovery)
        }

        #expect(await fixture.project.snapshot() == before)
        #expect(try Data(contentsOf: manifestURL) == originalManifest)
        #expect(try await GlifiProjectPackage.open(at: fixture.packageURL).snapshot() == before)
        #expect(try Data(contentsOf: outsideURL) == Data(contentsOf: outsideReferenceURL))
        try await expectOriginalSourcesUnchanged(fixture: fixture, snapshot: before)

        let committed = try await fixture.commit(nil, .throwFailure)
        #expect(committed.generation == before.generation + 1)
        #expect(try await GlifiProjectPackage.open(at: fixture.packageURL).snapshot() == committed)
        try await expectOriginalSourcesUnchanged(fixture: fixture, snapshot: before)
    }
}

private struct CandidateManifestFixture: Sendable {
    let packageURL: URL
    let project: GlifiProjectPackage
    let sourceBytes: Data
    let commit:
        @Sendable (GlifiProjectCommitInterruption?, GlifiProjectCommitInterruptionBehavior)
            async throws -> GlifiProjectSnapshot
}

private func withCandidateManifestFixture(
    kind: CandidateCommitKind,
    _ body: (CandidateManifestFixture) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiCandidateManifestTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let packageURL = root.appending(path: "Project.glifi")
    let project = try GlifiProjectPackage.create(at: packageURL)
    let sourceBytes = Data("Fonte sintetica precedente da conservare.".utf8)
    let imported = try GlifiTextImporter().importText(from: sourceBytes, format: .plainText)
    _ = try await project.importText(imported)
    let snapshot = await project.snapshot()
    let descriptor = try candidateArtifactDescriptor(corpusDigest: snapshot.sourceRootDigest)
    let payload = CandidateManifestPayload(value: "synthetic")
    let commit:
        @Sendable (GlifiProjectCommitInterruption?, GlifiProjectCommitInterruptionBehavior)
            async throws -> GlifiProjectSnapshot
    switch kind {
    case .importedSource:
        let nextSource = try GlifiTextImporter().importText(
            from: Data("Nuova fonte sintetica.".utf8), format: .plainText)
        let sourceID = SourceID()
        commit = { interruption, behavior in
            try await project.importText(
                nextSource, sourceID: sourceID, interruption: interruption,
                interruptionBehavior: behavior)
        }
    case .artifact:
        commit = { interruption, behavior in
            try await project.storeArtifact(
                payload, descriptor: descriptor, interruption: interruption,
                interruptionBehavior: behavior)
        }
    case .qualitative:
        let event = try GlifiQualitativeEvent(
            predecessorEventID: nil, recordedAtUnixMilliseconds: 0,
            payload: .codebookRevised(
                codebookID: "synthetic", revision: 1,
                categories: [
                    GlifiCodebookCategory(
                        categoryID: "theme", label: "Tema", definition: "Tema sintetico")
                ]))
        commit = { interruption, behavior in
            try await project.appendQualitativeEvent(
                event, interruption: interruption, interruptionBehavior: behavior)
        }
    case .investigation:
        let prepared = try await project.storeArtifact(payload, descriptor: descriptor)
        let artifact = try #require(prepared.artifacts.first)
        let event = try GlifiInvestigationEvent(
            investigationID: InvestigationID(), predecessorEventID: nil,
            recordedAtUnixMilliseconds: 0, actor: .localPerson,
            payload: .created(
                question: "Domanda sintetica", languageCode: "it", intent: .understandCollection,
                planArtifactID: artifact.artifactID, interpretationArtifactID: artifact.artifactID,
                availableFindingIDs: [], selectedFindingIDs: []))
        commit = { interruption, behavior in
            try await project.appendInvestigationEvent(
                event, interruption: interruption, interruptionBehavior: behavior)
        }
    }
    try await body(
        CandidateManifestFixture(
            packageURL: packageURL, project: project, sourceBytes: sourceBytes, commit: commit))
}

private func mutateCandidateManifest(
    at url: URL, mutation: CandidateMutation, outsideURL: URL, outsideReferenceURL: URL
) throws {
    switch mutation {
    case .truncated:
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 1)
    case .extraByte:
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0]))
    case .oversizedSparse:
        let descriptor = open(url.path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        try #require(descriptor >= 0)
        defer { close(descriptor) }
        try #require(
            ftruncate(descriptor, off_t(GlifiProjectPackage.maximumManifestByteCount + 1)) == 0)
    case .symbolicLink:
        let original = try Data(contentsOf: url)
        try original.write(to: outsideURL)
        try original.write(to: outsideReferenceURL)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outsideURL)
    case .hardLink:
        let original = try Data(contentsOf: url)
        try original.write(to: outsideURL)
        try original.write(to: outsideReferenceURL)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.linkItem(at: outsideURL, to: url)
    case .fifo:
        try FileManager.default.removeItem(at: url)
        try #require(mkfifo(url.path, 0o600) == 0)
    case .changedDigest:
        let original = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(GlifiProjectManifest.self, from: original)
        let digest = manifest.generationRecordDigest
        let finalDigit = try #require(digest.last)
        let changedDigest = String(digest.dropLast()) + (finalDigit == "0" ? "1" : "0")
        let encoded = try #require(String(data: original, encoding: .utf8))
        let changed = Data(encoded.replacingOccurrences(of: digest, with: changedDigest).utf8)
        #expect(changed.count == original.count)
        let decoded = try JSONDecoder().decode(GlifiProjectManifest.self, from: changed)
        #expect(decoded.generationRecordDigest != manifest.generationRecordDigest)
        try changed.write(to: url)
    }
}

private func expectOriginalSourcesUnchanged(
    fixture: CandidateManifestFixture, snapshot: GlifiProjectSnapshot
) async throws {
    for source in snapshot.sources {
        #expect(
            try await fixture.project.sourceData(for: source.sourceRevisionID)
                == fixture.sourceBytes)
        #expect(
            try Data(contentsOf: fixture.packageURL.appending(path: source.objectPath))
                == fixture.sourceBytes)
    }
}

private func candidateArtifactDescriptor(corpusDigest: String) throws -> GlifiAnalysisDescriptor {
    try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.candidate-manifest-test",
        algorithmIdentifier: "algorithm.candidate-manifest-test", algorithmVersion: "1",
        corpusIdentifier: "project-source-root-v1", corpusVersionDigest: corpusDigest,
        selectionIdentifier: "selection.all.v1", analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: [], linguisticProfileIdentifiers: [],
        representationIdentifier: "representation.test.v1", resolvedParameters: [:],
        seedPolicyIdentifier: "none-v1", backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1", determinismClass: .d0,
        outputSchemaIdentifier: CandidateManifestPayload.outputSchemaIdentifier,
        softwareIdentifier: "GlifiCore-0.1", dependencies: [])
}

private struct CandidateManifestPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.candidate-manifest-test.v1"
    let value: String
}
