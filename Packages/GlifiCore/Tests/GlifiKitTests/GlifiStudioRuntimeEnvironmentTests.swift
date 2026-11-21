// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Synchronization
import Testing

@testable import GlifiKit

@Test("I segnali concorrenti conservano memoria critica ed energia senza aggiornamenti persi")
func runtimeEnvironmentUpdatesAreAtomic() async {
    let store = GlifiStudioSystemConditionsStore(kitRuntimeConditions())
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            for _ in 0..<1_000 { store.updateMemoryPressure(.critical) }
        }
        group.addTask {
            for _ in 0..<1_000 {
                store.updateEnergyAndActivity(
                    kitRuntimeConditions(lowPower: true, thermal: .serious, active: false))
            }
        }
        group.addTask {
            for _ in 0..<1_000 {
                let snapshot = store.snapshot()
                #expect(snapshot.isLowPowerModeEnabled == (snapshot.thermalCondition == .serious))
                #expect(snapshot.isApplicationActive == !snapshot.isLowPowerModeEnabled)
            }
        }
    }
    #expect(
        store.snapshot()
            == kitRuntimeConditions(
                lowPower: true, thermal: .serious, memory: .critical, active: false))
}

@Test("L'admission conserva la cancellazione tipizzata senza eseguire I/O")
func runtimeEnvironmentPreservesTypedCancellation() async throws {
    let service = GlifiStudioService(
        runtimeEnvironment: .init(snapshot: { kitRuntimeConditions() }))
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await service.profileText(
            at: URL(fileURLWithPath: "/missing-runtime-cancellation-canary"), format: .plainText)
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled admission succeeded")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "operation.cancelled")
        #expect(failure.category == "cancelled")
        #expect(failure.operation == "profileCollection")
        #expect(failure.retryDisposition == "newRequest")
        #expect(failure.retainedState == "unchanged")
        #expect(!String(describing: failure).contains("missing-runtime-cancellation-canary"))
    }
}

@Test(
    "La cancellazione dopo l'admission della fonte mantiene la failure tipizzata e la generazione")
func runtimeEnvironmentPreservesCancellationDuringSourceRead() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitRuntimeSourceCancellation-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceURL = root.appending(path: "fonte.txt")
    let text = "Una fonte sintetica per la cancellazione."
    try Data(text.utf8).write(to: sourceURL)
    let cancelNextSnapshot = Mutex(false)
    let environment = GlifiStudioRuntimeEnvironment {
        let shouldCancel = cancelNextSnapshot.withLock { armed in
            let result = armed
            armed = false
            return result
        }
        if shouldCancel { withUnsafeCurrentTask { $0?.cancel() } }
        return kitRuntimeConditions()
    }
    let service = GlifiStudioService(runtimeEnvironment: environment)
    let session = try await service.createProject(at: root.appending(path: "Runtime.glifi"))
    let imported = try await session.importText(at: sourceURL, format: .plainText)
    let revision = try #require(imported.project.sources.first?.sourceRevisionID)
    let initial = try await session.snapshot()

    cancelNextSnapshot.withLock { $0 = true }
    let read = Task { try await session.sourceText(sourceRevisionID: revision) }
    do {
        _ = try await read.value
        Issue.record("Source reading ignored cancellation after admission")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "operation.cancelled")
        #expect(failure.category == "cancelled")
        #expect(failure.operation == "query")
        #expect(failure.retryDisposition == "newRequest")
        #expect(failure.retainedState == "lastCommittedGeneration")
        #expect(failure.messageKey == "failure.operation.cancelled")
        #expect(failure.arguments.isEmpty)
    }
    #expect(!cancelNextSnapshot.withLock { $0 })
    #expect(try await session.snapshot() == initial)
    #expect(try await session.sourceText(sourceRevisionID: revision).text == text)
    await session.close()
}

@Test("L'admission critica blocca importazione, query e analisi senza impedire letture e recupero")
func runtimeEnvironmentRejectsLongWorkAndPreservesRecovery() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitRuntime-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceURL = root.appending(path: "fonte.txt")
    try Data("Una fonte. Una seconda frase.".utf8).write(to: sourceURL)
    let store = GlifiStudioSystemConditionsStore(kitRuntimeConditions())
    let service = GlifiStudioService(runtimeEnvironment: .init(store: store))
    let projectURL = root.appending(path: "Runtime.glifi", directoryHint: .isDirectory)
    let session = try await service.createProject(at: projectURL)
    let imported = try await session.importText(at: sourceURL, format: .plainText)
    let initial = try await session.snapshot()
    let revision = try #require(imported.project.sources.first?.sourceRevisionID)
    store.updateMemoryPressure(.critical)

    for (operation, expectedOperation) in [
        ("importText", "importText"), ("query", "query"), ("sourceText", "query"),
        ("analyze", "analyze"), ("plan", "plan"), ("executePlan", "executePlan"),
        ("profileCollection", "profileCollection"),
    ] {
        do {
            switch operation {
            case "importText":
                _ = try await session.importText(at: sourceURL, format: .plainText)
            case "query":
                _ = try await session.query("fonte")
            case "sourceText":
                _ = try await session.sourceText(sourceRevisionID: revision)
            case "analyze":
                _ = try await session.analyzeExtractiveSummary(sourceRevisionIDs: [revision])
            case "plan":
                _ = try await session.planAnalysis(.init(intent: "understand.collection"))
            case "executePlan":
                _ = try await session.executeAnalysisPlan(.init(intent: "understand.collection"))
            case "profileCollection":
                _ = try await service.profileText(at: sourceURL, format: .plainText)
            default:
                Issue.record("Unexpected test operation")
            }
            Issue.record("Critical pressure admitted \(operation)")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.code == "runtime.admission-denied")
            #expect(failure.operation == expectedOperation)
            #expect(failure.category == "insufficientResources")
            #expect(failure.retryDisposition == "afterConditionsChange")
            #expect(
                failure.retainedState
                    == (operation == "profileCollection" ? "unchanged" : "lastCommittedGeneration"))
        }
    }
    #expect(try await session.snapshot() == initial)
    #expect(try await session.investigationHeads().isEmpty)
    _ = try await session.qualitativeState()
    await session.close()
    let reopened = try await service.openProject(at: projectURL)
    #expect(try await reopened.snapshot() == initial)
    store.updateMemoryPressure(.nominal)
    #expect(
        try await reopened.sourceText(sourceRevisionID: revision).text
            == "Una fonte. Una seconda frase.")
    #expect(try await reopened.query("fonte").matches.count == 1)
    await reopened.close()
}

@Test("Il profilo Low Power Mode è propagato al piano e la fermata del monitor è conservativa")
func runtimeEnvironmentPropagatesConditionsIntoExecution() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitRuntimeProfile-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceURL = root.appending(path: "fonte.txt")
    try Data("Una fonte italiana. Una seconda frase.".utf8).write(to: sourceURL)
    let store = GlifiStudioSystemConditionsStore(kitRuntimeConditions(lowPower: true))
    let session = try await GlifiStudioService(runtimeEnvironment: .init(store: store))
        .createProject(at: root.appending(path: "Runtime.glifi"))
    _ = try await session.importText(at: sourceURL, format: .plainText)
    let execution = try await session.executeAnalysisPlan(.init(intent: "understand.collection"))
    var completion: GlifiStudioAnalysisExecutionResult?
    for try await event in execution.events {
        if case let .completed(result) = event {
            completion = result
            #expect(result.operatingProfile == "constrained")
            #expect(result.maximumParallelism <= 2)
        }
    }
    let result = try #require(completion)
    store.markUnavailable()
    #expect(store.snapshot().memoryPressure == .critical)
    #expect(!store.snapshot().isApplicationActive)
    do {
        _ = try await session.visualizations(for: result)
        Issue.record("Critical pressure admitted Artifact loading and visualization work")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "runtime.admission-denied")
        #expect(failure.operation == "analyze")
    }
    await session.close()
}

private func kitRuntimeConditions(
    lowPower: Bool = false,
    thermal: GlifiStudioThermalCondition = .nominal,
    memory: GlifiStudioMemoryPressure = .nominal,
    active: Bool = true
) -> GlifiStudioSystemConditions {
    GlifiStudioSystemConditions(
        isLowPowerModeEnabled: lowPower, thermalCondition: thermal,
        memoryPressure: memory, isApplicationActive: active)
}
