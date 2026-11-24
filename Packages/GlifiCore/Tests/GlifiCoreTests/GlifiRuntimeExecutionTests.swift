// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Synchronization
import Testing

@testable import GlifiCore

@Test("La pressione arrivata prima della pianificazione non produce una generazione")
func runtimePressureBeforePlanningPreservesGeneration() async throws {
    let fixture = try await runtimeExecutionFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let initial = await fixture.project.snapshot()
    let conditions = Mutex(runtimeExecutionConditions())
    do {
        _ = try await GlifiEngine().executeAnalysisPlan(
            in: fixture.project, request: fixture.request,
            systemConditionsProvider: GlifiSystemConditionsProvider { conditions.withLock { $0 } }
        ) { progress in
            if progress.phase == .planning, progress.completed == 0 {
                conditions.withLock { $0 = runtimeExecutionConditions(memoryPressure: .critical) }
            }
        }
        Issue.record("Critical pressure did not stop planning")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "runtime.admission-denied")
        #expect(failure.category == .insufficientResources)
        #expect(failure.retryDisposition == .afterConditionsChange)
        #expect(failure.retainedState == .lastCommittedGeneration)
    }
    #expect(await fixture.project.snapshot() == initial)
    let reopened = try GlifiProjectPackage.open(at: fixture.projectURL)
    #expect(await reopened.snapshot() == initial)
}

@Test("La pressione fra nodi conserva soltanto generazioni complete e permette la ripresa")
func runtimePressureBetweenNodesPreservesCommittedWork() async throws {
    let fixture = try await runtimeExecutionFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let initial = await fixture.project.snapshot()
    let conditions = Mutex(runtimeExecutionConditions())
    do {
        _ = try await GlifiEngine().executeAnalysisPlan(
            in: fixture.project, request: fixture.request,
            systemConditionsProvider: GlifiSystemConditionsProvider { conditions.withLock { $0 } }
        ) { progress in
            if progress.phase == .executing, progress.completed > 0 {
                conditions.withLock { $0 = runtimeExecutionConditions(memoryPressure: .critical) }
            }
        }
        Issue.record("Critical pressure did not stop the following node")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "runtime.admission-denied")
        #expect(failure.category == .insufficientResources)
        #expect(failure.retainedState == .lastCommittedGeneration)
    }
    let stopped = await fixture.project.snapshot()
    // The plan and first node were committed; no later node or interpretation was published.
    #expect(stopped.generation == initial.generation + 2)
    #expect(stopped.artifacts.count == initial.artifacts.count + 2)
    let reopened = try GlifiProjectPackage.open(at: fixture.projectURL)
    #expect(await reopened.snapshot() == stopped)
    conditions.withLock { $0 = runtimeExecutionConditions() }
    let completed = try await GlifiEngine().executeAnalysisPlan(
        in: reopened, request: fixture.request,
        systemConditionsProvider: GlifiSystemConditionsProvider { conditions.withLock { $0 } }
    )
    #expect(completed.completedWorkUnits == completed.estimatedWorkUnits)
    #expect(completed.artifacts.count == 5)
    #expect(completed.generation > stopped.generation)
}

private func runtimeExecutionConditions(
    memoryPressure: GlifiMemoryPressure = .nominal
) -> GlifiSystemConditions {
    GlifiSystemConditions(
        isLowPowerModeEnabled: false, thermalCondition: .nominal,
        memoryPressure: memoryPressure, isApplicationActive: true)
}

private func runtimeExecutionFixture() async throws -> (
    root: URL, projectURL: URL, project: GlifiProjectPackage, request: GlifiAnalysisPlanRequest
) {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiRuntimeExecution-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    let projectURL = root.appending(path: "Runtime.glifi", directoryHint: .isDirectory)
    let project = try GlifiProjectPackage.create(at: projectURL)
    let importer = GlifiTextImporter()
    let first = try importer.importText(from: Data("casa casa mare".utf8), format: .plainText)
    let second = try importer.importText(from: Data("casa città città".utf8), format: .plainText)
    _ = try await project.importText(first)
    _ = try await project.importText(second)
    let request = try GlifiAnalysisPlanRequest(
        intent: .compareObjects,
        targetSourceRevisionIDs: [first.sourceRevisionID],
        referenceSourceRevisionIDs: [second.sourceRevisionID])
    return (root, projectURL, project, request)
}
