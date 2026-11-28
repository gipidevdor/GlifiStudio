// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import Testing

@testable import GlifiKit

@Suite("Visual export source metadata")
struct GlifiVisualExportSourceTests {
    @Test(
        "The live source rejects contradictory producer metadata before writing",
        arguments: VisualExportSourceKind.allCases, [false, true])
    func contradictoryMetadataIsRejected(
        _ kind: VisualExportSourceKind, throughCommand: Bool
    ) async throws {
        try await withVisualExportSourceFixture { fixture in
            let view = try await fixture.visualization(kind)
            let before = try await fixture.session.snapshot()
            let originalDestination = fixture.root.appending(path: "original")
            try await exportSourceView(
                view, session: fixture.session, to: originalDestination,
                throughCommand: throughCommand)
            #expect(FileManager.default.fileExists(atPath: originalDestination.path))

            for field in ["analysisNodeID", "analysisIdentifier", "methodIdentifier"] {
                var object = try #require(
                    JSONSerialization.jsonObject(with: JSONEncoder().encode(view))
                        as? [String: Any])
                object[field] =
                    field == "analysisNodeID"
                    ? "analysis-node:sha256:" + String(repeating: "b", count: 64)
                    : "contradictory-source-\(field)-v1"
                let altered = try JSONDecoder().decode(
                    GlifiStudioVisualization.self,
                    from: JSONSerialization.data(withJSONObject: object))
                let destination = fixture.root.appending(path: field)

                do {
                    try await exportSourceView(
                        altered, session: fixture.session, to: destination,
                        throughCommand: throughCommand)
                    Issue.record("Live export accepted contradictory source metadata: \(field)")
                } catch let failure as GlifiStudioFailure {
                    #expect(failure.code == "visual-export.source-mismatch")
                    #expect(failure.category == "invalidInput")
                    #expect(failure.operation == "export")
                    #expect(failure.retryDisposition == "afterCorrection")
                    #expect(failure.retainedState == "unchanged")
                    #expect(failure.arguments.isEmpty)
                }

                #expect(!FileManager.default.fileExists(atPath: destination.path))
                #expect(try await fixture.session.snapshot() == before)
                #expect(
                    try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
                        .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
            }
        }
    }

    @Test("Alternate factor axes preserve valid presentation choices", arguments: [false, true])
    func alternateFactorAxesRemainExportable(throughCommand: Bool) async throws {
        try await withVisualExportSourceFixture { fixture in
            let result = try await fixture.session.analyzeMultivariate(
                sourceRevisionIDs: fixture.sourceIDs,
                method: .principalComponents(scaled: false), maximumTermCount: 8)
            let standard = try #require(try GlifiStudioVisualizationBuilder.factorPlot(result))
            let alternate = try #require(
                try GlifiStudioVisualizationBuilder.factorPlot(result, firstAxis: 1, secondAxis: 0))
            #expect(alternate != standard)
            #expect(alternate.methodIdentifier == standard.methodIdentifier)
            let before = try await fixture.session.snapshot()
            let destination = fixture.root.appending(path: "alternate-axes")

            try await exportSourceView(
                alternate, session: fixture.session, to: destination,
                throughCommand: throughCommand)

            let written = try JSONDecoder().decode(
                GlifiStudioVisualization.self,
                from: Data(contentsOf: destination.appending(path: "view-spec.json")))
            #expect(written == alternate)
            #expect(try await fixture.session.snapshot() == before)
        }
    }

    @Test(
        "Source read failures retain their typed contract at the export boundary",
        arguments: [false, true])
    func corruptedSourcePayloadRetainsExportFailure(throughCommand: Bool) async throws {
        try await withVisualExportSourceFixture { fixture in
            let view = try await fixture.visualization(.factorPlot)
            let packageURL = fixture.root.appending(path: "Project.glifi")
            let inspected = try GlifiProjectPackage.open(at: packageURL)
            let snapshot = await inspected.snapshot()
            let record = try #require(
                snapshot.artifacts.first { $0.artifactID.canonicalValue == view.artifactID })
            let artifactURL = packageURL.appending(path: record.objectPath)
            var bytes = try Data(contentsOf: artifactURL)
            let first = try #require(bytes.indices.first)
            bytes[first] ^= 1
            try bytes.write(to: artifactURL)
            let destination = fixture.root.appending(path: "corrupted-source-export")

            do {
                try await exportSourceView(
                    view, session: fixture.session, to: destination,
                    throughCommand: throughCommand)
                Issue.record("Live export failed to observe the corrupted source Artifact.")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "project.artifact-digest-mismatch")
                #expect(failure.category == "corruption")
                #expect(failure.operation == "export")
                #expect(failure.retryDisposition == "never")
                #expect(failure.retainedState == "readOnlyRecovery")
                #expect(failure.arguments.isEmpty)
            }

            #expect(!FileManager.default.fileExists(atPath: destination.path))
            #expect(
                try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
                    .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
        }
    }

    @Test("Closed-session admission retains the export operation")
    func closedSessionUsesExportFailureBoundary() async throws {
        try await withVisualExportSourceFixture { fixture in
            let view = try await fixture.visualization(.factorPlot)
            let before = try await fixture.session.snapshot()
            await fixture.session.close()
            let destination = fixture.root.appending(path: "closed-session-export")

            do {
                _ = try await fixture.session.exportVisualization(view, to: destination)
                Issue.record("Closed session exported a visualization.")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "project.session-closed")
                #expect(failure.category == "invalidInput")
                #expect(failure.operation == "export")
                #expect(failure.retryDisposition == "afterCorrection")
                #expect(failure.retainedState == "lastCommittedGeneration")
                #expect(failure.arguments.isEmpty)
            }

            let reopened = try GlifiProjectPackage.open(
                at: fixture.root.appending(path: "Project.glifi"))
            #expect(await reopened.snapshot().generation == before.generation)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @Test("Pre-cancelled admission retains unchanged export state")
    func preCancelledTaskUsesExportFailureBoundary() async throws {
        try await withVisualExportSourceFixture { fixture in
            let view = try await fixture.visualization(.factorPlot)
            let before = try await fixture.session.snapshot()
            let destination = fixture.root.appending(path: "pre-cancelled-export")
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await fixture.session.exportVisualization(view, to: destination)
            }

            do {
                _ = try await task.value
                Issue.record("Pre-cancelled task exported a visualization.")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == "operation.cancelled")
                #expect(failure.category == "cancelled")
                #expect(failure.operation == "export")
                #expect(failure.retryDisposition == "newRequest")
                #expect(failure.retainedState == "unchanged")
                #expect(failure.arguments.isEmpty)
            }

            #expect(try await fixture.session.snapshot() == before)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
            #expect(
                try FileManager.default.contentsOfDirectory(atPath: fixture.root.path)
                    .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
        }
    }
}

enum VisualExportSourceKind: CaseIterable, Sendable {
    case factorPlot, dendrogram, windowNetwork, documentNetwork, collocationTable
}

private struct VisualExportSourceFixture: Sendable {
    let root: URL
    let session: GlifiStudioProjectSession
    let sourceIDs: [String]

    func visualization(_ kind: VisualExportSourceKind) async throws -> GlifiStudioVisualization {
        switch kind {
        case .factorPlot:
            let result = try await session.analyzeMultivariate(
                sourceRevisionIDs: sourceIDs,
                method: .principalComponents(scaled: false), maximumTermCount: 8)
            return try #require(try GlifiStudioVisualizationBuilder.factorPlot(result))
        case .dendrogram:
            let result = try await session.analyzeMultivariate(
                sourceRevisionIDs: sourceIDs,
                method: .hierarchical(linkage: "average", clusterCount: 2), maximumTermCount: 8)
            return try #require(try GlifiStudioVisualizationBuilder.dendrogram(result))
        case .windowNetwork:
            return GlifiStudioVisualizationBuilder.network(
                try await session.analyzeWindowNetwork(sourceRevisionIDs: sourceIDs))
        case .documentNetwork:
            return GlifiStudioVisualizationBuilder.network(
                try await session.analyzeLexicalNetwork(sourceRevisionIDs: sourceIDs))
        case .collocationTable:
            return GlifiStudioVisualizationBuilder.collocationTable(
                try await session.analyzeWindowCollocations(sourceRevisionIDs: sourceIDs))
        }
    }
}

private func withVisualExportSourceFixture(
    _ body: (VisualExportSourceFixture) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiVisualExportSourceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "Project.glifi", directoryHint: .isDirectory))
    do {
        for (index, text) in [
            "Il mare bagna il porto e le barche tornano al porto dal mare.",
            "La valle e la montagna, sentieri di montagna nella valle.",
            "Il porto sul mare e la montagna sopra la valle.",
        ].enumerated() {
            let url = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            _ = try await session.importText(at: url, format: .plainText)
        }
        let sourceIDs = try await session.snapshot().sources.map(\.sourceRevisionID)
        try await body(.init(root: root, session: session, sourceIDs: sourceIDs))
    } catch {
        await session.close()
        throw error
    }
    await session.close()
}

private func exportSourceView(
    _ view: GlifiStudioVisualization, session: GlifiStudioProjectSession,
    to destination: URL, throughCommand: Bool
) async throws {
    if throughCommand {
        let request = VisualSourceCommandRequest(
            parameters: .init(visualization: view, destinationPath: destination.path))
        _ = try await GlifiStudioProjectCommand.execute(
            json: JSONEncoder().encode(request), session: session)
    } else {
        _ = try await session.exportVisualization(view, to: destination)
    }
}

private struct VisualSourceCommandRequest: Encodable {
    let schema = GlifiStudioProjectCommand.schema
    let schemaVersion = GlifiStudioProjectCommand.schemaVersion
    let operation = GlifiStudioProjectOperation.exportVisualization
    let parameters: Parameters

    struct Parameters: Encodable {
        let visualization: GlifiStudioVisualization
        let destinationPath: String
    }
}
