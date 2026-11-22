// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("L'esecutore materializza ogni passo, emette progresso monotono e riusa gli Artifact")
func analysisPlanExecutionIsDurableAndReusable() async throws {
    let fixture = try await executionFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let operationID = OperationID(
        uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000010"))
    )
    let recorder = ProgressRecorder()

    let result = try await GlifiEngine().executeAnalysisPlan(
        in: fixture.project,
        request: fixture.request,
        operationID: operationID,
        systemConditions: nominalConditions,
        availableProcessorCount: 6
    ) { progress in
        await recorder.append(progress)
    }

    #expect(result.operationID == operationID)
    // planner-v2 (ADR-0025): piano (3), due profili (4, 5), keyness (6), similarità (7),
    // confronto di gruppo (8) e interpretazione (9).
    #expect(result.sourceGeneration == 2)
    #expect(result.generation == 9)
    #expect(result.planStatus == .readyWithCaveats)
    #expect(result.terminalState == .completedWithCaveats)
    #expect(result.operatingProfile == .balanced)
    #expect(result.maximumParallelism == 6)
    #expect(result.completedWorkUnits == result.estimatedWorkUnits)
    #expect(
        result.artifacts.map(\.role) == [
            .target, .reference, .comparison, .comparison, .comparison,
        ])
    #expect(
        result.artifacts.map(\.operation) == [
            .analyzeCorpus, .analyzeCorpus, .compareKeyness, .compareSimilarity,
            .compareGroupMetric,
        ])
    #expect(Set(result.artifacts.map(\.artifactID)).count == 5)
    #expect(result.interpretationArtifactID != result.planArtifactID)
    #expect(result.interpretation.planArtifactID == result.planArtifactID)
    #expect(result.interpretation.planAnalysisNodeID == result.planAnalysisNodeID)
    #expect(
        Set(result.interpretation.sourceArtifactIDs)
            == Set(result.artifacts.map(\.artifactID))
    )
    // Keyness non ha termini eleggibili; la similarità (un solo tipo condiviso) produce un
    // finding `caution` secondo support-policy.similarity-descriptive-v1 (ADR-0026).
    #expect(result.interpretation.evidence.count == 1)
    #expect(
        result.interpretation.findings.map(\.familyIdentifier) == ["finding-family.similarity.v1"])
    #expect(result.interpretation.findings.first?.assessment.supportClass == .caution)
    #expect(result.interpretation.insufficientEvidence == nil)
    let snapshot = await fixture.project.snapshot()
    #expect(snapshot.generation == 9)
    #expect(snapshot.artifacts.count == 7)
    #expect(snapshot.artifacts.contains { $0.artifactID == result.interpretationArtifactID })

    let observations = await recorder.values
    #expect(observations.map(\.revision) == Array(0...9))
    #expect(
        observations.map(\.phase) == [
            .planning, .planning, .executing, .executing, .executing,
            .executing, .executing, .executing, .finalizing, .finalizing,
        ])
    #expect(observations.allSatisfy { $0.operationID == operationID })
    let executionProgress = observations.filter { $0.phase == .executing }
    #expect(executionProgress.map(\.completed) == executionProgress.map(\.completed).sorted())
    #expect(executionProgress.last?.completed == result.completedWorkUnits)

    let repeated = try await GlifiEngine().executeAnalysisPlan(
        in: fixture.project,
        request: fixture.request,
        systemConditions: nominalConditions,
        availableProcessorCount: 6
    )
    #expect(repeated.sourceGeneration == 9)
    #expect(repeated.generation == 9)
    #expect(repeated.artifacts.map(\.artifactID) == result.artifacts.map(\.artifactID))
    #expect(repeated.interpretationArtifactID == result.interpretationArtifactID)
    #expect(repeated.interpretation == result.interpretation)
    #expect(await fixture.project.snapshot() == snapshot)
}

@Test("Admission, piano non eseguibile e cancellazione terminano con failure tipizzate")
func analysisPlanExecutionFailsClosed() async throws {
    let fixture = try await executionFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let initial = await fixture.project.snapshot()

    do {
        _ = try await GlifiEngine().executeAnalysisPlan(
            in: fixture.project,
            request: fixture.request,
            systemConditions: GlifiSystemConditions(
                isLowPowerModeEnabled: false,
                thermalCondition: .critical,
                memoryPressure: .nominal,
                isApplicationActive: true
            )
        )
        Issue.record("Era atteso un rifiuto di admission")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "runtime.admission-denied")
        #expect(failure.category == .insufficientResources)
        #expect(failure.operation == .executePlan)
        #expect(failure.arguments["operatingProfile"] == "protective")
    }
    #expect(await fixture.project.snapshot() == initial)

    let cancelledTask = Task {
        try await GlifiEngine().executeAnalysisPlan(
            in: fixture.project,
            request: fixture.request,
            systemConditions: nominalConditions
        ) { _ in
            withUnsafeCurrentTask { $0?.cancel() }
        }
    }
    do {
        _ = try await cancelledTask.value
        Issue.record("Era attesa una cancellazione")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "operation.cancelled")
        #expect(failure.category == .cancelled)
        #expect(failure.operation == .executePlan)
    }
    #expect(await fixture.project.snapshot() == initial)

    let emptyURL = fixture.root.appending(path: "Vuoto.glifi", directoryHint: .isDirectory)
    let emptyProject = try GlifiProjectPackage.create(at: emptyURL)
    do {
        _ = try await GlifiEngine().executeAnalysisPlan(
            in: emptyProject,
            request: GlifiAnalysisPlanRequest(intent: .understandCollection),
            systemConditions: nominalConditions
        )
        Issue.record("Era atteso un piano non eseguibile")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "runtime.plan-not-executable")
        #expect(failure.category == .insufficientData)
        #expect(failure.operation == .executePlan)
    }
    let emptySnapshot = await emptyProject.snapshot()
    #expect(emptySnapshot.generation == 1)
    #expect(emptySnapshot.artifacts.count == 1)

    let lateFixture = try await executionFixture()
    defer { try? FileManager.default.removeItem(at: lateFixture.root) }
    let lateCancellationTask = Task {
        try await GlifiEngine().executeAnalysisPlan(
            in: lateFixture.project,
            request: lateFixture.request,
            systemConditions: nominalConditions
        ) { progress in
            if progress.phase == .finalizing,
                progress.completed == progress.total
            {
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
    }
    let committed = try await lateCancellationTask.value
    #expect(committed.terminalState == .completedWithCaveats)
    #expect(committed.artifacts.count == 5)
    #expect(await lateFixture.project.snapshot().generation == committed.generation)
}

@Test("Le osservazioni di progresso rifiutano invarianti impossibili")
func operationProgressValidatesItsContract() throws {
    let operationID = OperationID()
    #expect(throws: GlifiFailure.self) {
        try GlifiOperationProgress(
            operationID: operationID,
            revision: 1,
            phase: .executing,
            completed: 2,
            total: 1,
            unit: .workUnits,
            estimateQuality: .estimated
        )
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiOperationProgress(
            operationID: operationID,
            revision: 1,
            phase: .executing,
            completed: 0,
            total: nil,
            unit: .workUnits,
            estimateQuality: .indeterminate
        )
    }
}

private actor ProgressRecorder {
    private(set) var values: [GlifiOperationProgress] = []

    func append(_ value: GlifiOperationProgress) {
        values.append(value)
    }
}

private struct ExecutionFixture {
    let root: URL
    let project: GlifiProjectPackage
    let request: GlifiAnalysisPlanRequest
}

private var nominalConditions: GlifiSystemConditions {
    GlifiSystemConditions(
        isLowPowerModeEnabled: false,
        thermalCondition: .nominal,
        memoryPressure: .nominal,
        isApplicationActive: true
    )
}

private func executionFixture() async throws -> ExecutionFixture {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiAnalysisExecutionTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "Esecuzione.glifi", directoryHint: .isDirectory)
    )
    let target = try GlifiTextImporter().importText(
        from: Data("casa casa mare".utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        )
    )
    let reference = try GlifiTextImporter().importText(
        from: Data("casa città città".utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        )
    )
    _ = try await project.importText(target)
    _ = try await project.importText(reference)
    return ExecutionFixture(
        root: root,
        project: project,
        request: try GlifiAnalysisPlanRequest(
            intent: .compareObjects,
            targetSourceRevisionIDs: [target.sourceRevisionID],
            referenceSourceRevisionIDs: [reference.sourceRevisionID]
        )
    )
}

@Test("Il planner-v2 esegue le capability estese e le conserva nel lineage dell'interpretazione")
func extendedCapabilitiesExecuteEndToEnd() async throws {
    let fixture = try await executionFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let third = try GlifiTextImporter().importText(
        from: Data("mare città casa mare".utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        )
    )
    _ = try await fixture.project.importText(third)

    // explore.relationships su tre fonti: associazione, collocazioni, rete e CA.
    let relationships = try await GlifiEngine().executeAnalysisPlan(
        in: fixture.project,
        request: try GlifiAnalysisPlanRequest(intent: .exploreRelationships),
        systemConditions: nominalConditions
    )
    #expect(
        relationships.artifacts.map(\.operation) == [
            .analyzeAssociation, .analyzeWindowCollocations, .analyzeWindowNetwork,
            .analyzeCorrespondence,
        ])
    #expect(relationships.terminalState == .completedWithCaveats)
    #expect(relationships.interpretation.sourceArtifactIDs.count == 4)
    // Ogni finding esteso applica una policy di ADR-0026 ed è accompagnato dal suo Evidence.
    let policies: Set<String> = [
        "support-policy.contingency-cramersv-v1", "support-policy.collocation-tscore-npmi-v1",
        "support-policy.community-modularity-v1", "support-policy.correspondence-axis-v1",
    ]
    #expect(
        relationships.interpretation.findings.allSatisfy {
            policies.contains($0.assessment.policyIdentifier)
        })
    #expect(
        relationships.interpretation.findings.count == relationships.interpretation.evidence.count)
    let snapshot = await fixture.project.snapshot()
    for artifact in relationships.artifacts {
        let record = try #require(snapshot.artifacts.first { $0.artifactID == artifact.artifactID })
        #expect(record.node.descriptor.outputSchemaIdentifier == artifact.outputSchemaIdentifier)
    }

    // identify.themes aggiunge il clustering gerarchico (tre fonti, k = 2).
    let themes = try await GlifiEngine().executeAnalysisPlan(
        in: fixture.project,
        request: try GlifiAnalysisPlanRequest(intent: .identifyThemes),
        systemConditions: nominalConditions
    )
    #expect(
        themes.artifacts.map(\.operation) == [
            .analyzeWindowNetwork, .analyzeCorrespondence, .clusterDocuments,
        ])
    // Rete e CA coincidono con quelle del piano precedente: stessi nodi, stessi Artifact.
    #expect(themes.artifacts[0].artifactID == relationships.artifacts[2].artifactID)
    #expect(themes.artifacts[1].artifactID == relationships.artifacts[3].artifactID)
}
