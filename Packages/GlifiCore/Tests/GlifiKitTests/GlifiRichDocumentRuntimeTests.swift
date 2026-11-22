// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

@Test("Project laboratory admission rejects critical pressure before reading source storage")
func richDocumentRuntimeLaboratoryAdmissionPrecedesReading() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appending(
        path: "GlifiRichDocumentRuntime-\(UUID().uuidString)", directoryHint: .isDirectory)
    try manager.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? manager.removeItem(at: root) }
    let sourceURL = root.appending(path: "source.txt")
    try Data("Una casa e un giardino.".utf8).write(to: sourceURL)
    let store = GlifiStudioSystemConditionsStore(
        GlifiStudioSystemConditions(
            isLowPowerModeEnabled: false, thermalCondition: .nominal,
            memoryPressure: .nominal, isApplicationActive: true))
    let service = GlifiStudioService(runtimeEnvironment: .init(store: store))
    let projectURL = root.appending(path: "Runtime.glifi", directoryHint: .isDirectory)
    let session = try await service.createProject(at: projectURL)
    let imported = try await session.importText(at: sourceURL, format: .plainText)
    let revision = try #require(imported.project.sources.first?.sourceRevisionID)
    let initial = try await session.snapshot()

    // Make storage unavailable so a later read failure cannot masquerade as admission.
    let heldProjectURL = root.appending(path: "held-project", directoryHint: .isDirectory)
    try manager.moveItem(at: projectURL, to: heldProjectURL)
    defer {
        if manager.fileExists(atPath: heldProjectURL.path) {
            try? manager.moveItem(at: heldProjectURL, to: projectURL)
        }
    }
    store.updateMemoryPressure(.critical)
    #expect(try await session.snapshot() == initial)
    do {
        _ = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: [revision])
        Issue.record("Critical pressure admitted project laboratory work")
    } catch let failure {
        #expect(failure.code == "runtime.admission-denied")
        #expect(failure.category == "insufficientResources")
        #expect(failure.operation == "analyze")
        #expect(failure.retryDisposition == "afterConditionsChange")
        #expect(failure.retainedState == "lastCommittedGeneration")
        #expect(failure.messageKey == "failure.runtime.admission-denied")
    }
    #expect(try await session.snapshot() == initial)

    try manager.moveItem(at: heldProjectURL, to: projectURL)
    store.updateMemoryPressure(.nominal)
    let prepared = try await GlifiStudioTextAnalytics.prepareProjectInput(
        session: session, sourceRevisionIDs: [revision])
    #expect(prepared.sourceRevisionIDs == [revision])
    #expect(prepared.documents.count == 1 && prepared.lexicalTokenCount > 0)
    #expect(try await session.snapshot() == initial)
    await session.close()
}
