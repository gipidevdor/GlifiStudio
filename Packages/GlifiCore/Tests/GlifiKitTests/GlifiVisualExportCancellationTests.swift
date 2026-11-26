// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Synchronization
import Testing

@testable import GlifiKit

@Test(
    "L'export nativo e project-command osservano cancellazione dopo admission senza pubblicare",
    arguments: [false, true])
func visualExportCancellationAfterAdmission(throughCommand: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiVisualCancellation-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let armed = Mutex(false)
    let environment = GlifiStudioRuntimeEnvironment {
        let shouldCancel = armed.withLock { value in
            let result = value
            value = false
            return result
        }
        if shouldCancel { withUnsafeCurrentTask { $0?.cancel() } }
        return GlifiStudioSystemConditions(
            isLowPowerModeEnabled: false, thermalCondition: .nominal,
            memoryPressure: .nominal, isApplicationActive: true)
    }
    let session = try await GlifiStudioService(runtimeEnvironment: environment).createProject(
        at: root.appending(path: "Project.glifi", directoryHint: .isDirectory))
    for (index, text) in [
        "Il mare bagna il porto e le barche tornano al porto dal mare.",
        "La valle e la montagna, sentieri di montagna nella valle.",
        "Il porto sul mare e la montagna sopra la valle.",
    ].enumerated() {
        let url = root.appending(path: "source-\(index).txt")
        try Data(text.utf8).write(to: url)
        _ = try await session.importText(at: url, format: .plainText)
    }
    let execution = try await session.executeAnalysisPlan(.init(intent: "identify.themes"))
    var completed: GlifiStudioAnalysisExecutionResult?
    for try await event in execution.events {
        if case let .completed(result) = event { completed = result }
    }
    let views = try await session.visualizations(for: #require(completed))
    let view = try #require(views.first)
    let initial = try await session.snapshot()
    let destination = root.appending(path: "export", directoryHint: .isDirectory)
    let request = try JSONEncoder().encode(
        VisualCancellationCommandRequest(
            parameters: .init(visualization: view, destinationPath: destination.path)))
    armed.withLock { $0 = true }
    let task = Task {
        if throughCommand {
            _ = try await GlifiStudioProjectCommand.execute(json: request, session: session)
        } else {
            _ = try await session.exportVisualization(view, to: destination)
        }
    }
    do {
        try await task.value
        Issue.record("Export ignored cancellation after admission")
    } catch let failure as GlifiStudioFailure {
        expectVisualExportCancellation(failure)
    }
    #expect(!armed.withLock { $0 })
    #expect(!FileManager.default.fileExists(atPath: destination.path))
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path)
            .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
    #expect(try await session.snapshot() == initial)
    let receipt = try await session.exportVisualization(view, to: destination)
    #expect(receipt.fileCount == 3)
    await session.close()
}

@Test(
    "Il writer elimina lo staging se cancellato prima del commit e conserva il successo dopo",
    arguments: GlifiStudioVisualExport.WriteCheckpoint.allCases, [false, true])
func visualExportCancellationAtWriteCheckpoints(
    observed: GlifiStudioVisualExport.WriteCheckpoint, cancels: Bool
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiVisualWriterCancellation-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let userFile = root.appending(path: "user.txt")
    let userData = Data("User-owned sentinel".utf8)
    try userData.write(to: userFile)
    let destination = root.appending(path: "export", directoryHint: .isDirectory)
    let files = try visualCancellationBundle()
    let visited = Mutex<[GlifiStudioVisualExport.WriteCheckpoint]>([])
    let task = Task {
        try GlifiStudioVisualExport.write(files, to: destination) { checkpoint in
            visited.withLock { $0.append(checkpoint) }
            if cancels, checkpoint == observed { withUnsafeCurrentTask { $0?.cancel() } }
        }
    }
    let commits = !cancels || observed == .committed
    do {
        let receipt = try await task.value
        #expect(commits)
        #expect(receipt.fileCount == files.count)
        #expect(
            receipt.manifestDigest
                == GlifiStudioVisualExport.digest(
                    try #require(files[GlifiStudioVisualExport.manifestFileName])))
        var written: [String: Data] = [:]
        for path in try FileManager.default.contentsOfDirectory(atPath: destination.path) {
            written[path] = try Data(contentsOf: destination.appending(path: path))
        }
        #expect(written == files)
        _ = try GlifiStudioVisualExport.verify(written)
    } catch let failure as GlifiStudioFailure {
        #expect(!commits)
        expectVisualExportCancellation(failure)
    }
    #expect(visited.withLock { $0.contains(observed) })
    #expect(FileManager.default.fileExists(atPath: destination.path) == commits)
    #expect(try Data(contentsOf: userFile) == userData)
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path)
            .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
}

@Test(
    "Il writer già cancellato conserva destinazioni e file utente preesistenti",
    arguments: [false, true])
func visualExportCancellationBeforeWriting(destinationExists: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiVisualWriterAdmission-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let destination = root.appending(path: "export", directoryHint: .isDirectory)
    let sentinel = destination.appending(path: "user.txt")
    let data = Data("Existing export directory belongs to the user".utf8)
    if destinationExists {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        try data.write(to: sentinel)
    }
    let files = try visualCancellationBundle()
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiStudioVisualExport.write(files, to: destination)
    }
    do {
        _ = try await task.value
        Issue.record("Pre-cancelled writer succeeded")
    } catch let failure as GlifiStudioFailure {
        expectVisualExportCancellation(failure)
    }
    #expect(FileManager.default.fileExists(atPath: destination.path) == destinationExists)
    if destinationExists {
        #expect(try Data(contentsOf: sentinel) == data)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: destination.path) == ["user.txt"])
    }
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path)
            .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
}

private func visualCancellationBundle() throws -> [String: Data] {
    try GlifiStudioVisualExport.bundle(
        GlifiStudioVisualization(
            specificationIdentifier: "visual-spec.collocation-table.v1", family: .collocationTable,
            titleKey: "visual.title.collocation-table",
            artifactID: "artifact:synthetic-cancellation",
            analysisNodeID: "node:synthetic-cancellation", analysisIdentifier: "synthetic.v1",
            methodIdentifier: "synthetic.v1", axes: [], requiresEqualAspect: false, marks: [],
            table: .init(
                columns: [.init(identifier: "term", labelKey: "visual.column.term")],
                rows: [.init(id: "term:mare", cells: [.text("mare")])]),
            totalObservationCount: 1, visibleObservationCount: 1, reductionIdentifier: nil,
            layoutIdentifier: nil, emphasisIdentifier: nil, excludedLabels: [], caveatKeys: [],
            summaryKey: "visual.summary.collocation-table", summaryArguments: []),
        projectID: "project:synthetic-cancellation", generation: 1,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000))
}

private struct VisualCancellationCommandRequest: Encodable {
    let schema = GlifiStudioProjectCommand.schema
    let schemaVersion = GlifiStudioProjectCommand.schemaVersion
    let operation = GlifiStudioProjectOperation.exportVisualization
    let parameters: Parameters

    struct Parameters: Encodable {
        let visualization: GlifiStudioVisualization
        let destinationPath: String
    }
}

private func expectVisualExportCancellation(_ failure: GlifiStudioFailure) {
    #expect(failure.code == "operation.cancelled")
    #expect(failure.category == "cancelled")
    #expect(failure.operation == "export")
    #expect(failure.retryDisposition == "newRequest")
    #expect(failure.retainedState == "unchanged")
    #expect(failure.messageKey == "failure.operation.cancelled")
    #expect(failure.arguments.isEmpty)
}
