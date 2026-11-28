// SPDX-License-Identifier: BSD-3-Clause

import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

private let plannerContractCapabilities = [
    "profile": "studio.glifi.capability.corpus-profile.v1",
    "keyness": "studio.glifi.capability.keyness.v1",
    "association": "studio.glifi.capability.document-term-association.v1",
    "collocations": "studio.glifi.capability.window-collocation.v1",
    "network": "studio.glifi.capability.window-network.v1",
    "correspondence": "studio.glifi.capability.correspondence-analysis.v1",
    "clustering": "studio.glifi.capability.document-clustering.v1",
    "similarity": "studio.glifi.capability.group-similarity.v1",
    "groupMetric": "studio.glifi.capability.group-location-comparison.v1",
]
private let plannerContractCapabilityOrder = [
    "profile", "keyness", "association", "collocations", "network", "correspondence",
    "clustering", "similarity", "groupMetric",
]

@MainActor
private final class BDDPlannerContractWorld {
    var root: URL?
    var session: GlifiStudioProjectSession?
    var ids: [String] = []
    var sourceBytes: [String: Data] = [:]
    var before: GlifiStudioProjectSnapshot?
    var afterPlanning: GlifiStudioProjectSnapshot?
    var request: GlifiStudioAnalysisPlanRequest?
    var planned: GlifiStudioAnalysisPlanResult?
    var expectedOperations: [String] = []
    var expectedRoles: [String] = []
    var execution: GlifiStudioAnalysisExecutionResult?
    var progress: [GlifiStudioOperationProgress] = []
    var terminalCount = 0
    var failure: GlifiStudioFailure?

    func prepare() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDDPlanner-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        root = directory
        let service = GlifiStudioService(
            runtimeEnvironment: .init {
                .init(
                    isLowPowerModeEnabled: false, thermalCondition: .nominal,
                    memoryPressure: .nominal, isApplicationActive: true)
            })
        let current = try await service.createProject(
            at: directory.appending(path: "Planner.glifi"))
        session = current
        // Original repository fixture, explicitly reviewed for this planner contract.
        let texts = [
            "casa casa giardino mare luce città", "casa giardino albero albero sole",
            "casa sole luce luce parco parco parco", "mare mare barca costa luce",
            "mare barca onda onda acqua acqua", "mare onda acqua acqua acqua luce città città",
        ]
        for (index, text) in texts.enumerated() {
            let markdown = !index.isMultiple(of: 2)
            let bytes = Data((markdown ? "# Scenario\n\(text)" : text).utf8)
            let url = directory.appending(path: "source-\(index).data")
            try bytes.write(to: url)
            let imported = try await current.importText(
                at: url, format: markdown ? .markdown : .plainText)
            let known = Set(ids)
            let id = try #require(
                imported.project.sources.first { !known.contains($0.sourceRevisionID) }?
                    .sourceRevisionID)
            ids.append(id)
            sourceBytes[id] = bytes
        }
        before = try await current.snapshot()
        #expect(ids.count == 6)
    }

    func makeRequest(intent: String) {
        request = .init(
            intent: intent, scopeSourceRevisionIDs: Array(ids.reversed()),
            targetSourceRevisionIDs: Array(ids.prefix(3).reversed()),
            referenceSourceRevisionIDs: Array(ids.suffix(3).reversed()))
    }

    func plan(cancelled: Bool = false) async throws {
        let current = try #require(session)
        let request = try #require(request)
        do {
            if cancelled {
                planned = try await Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await current.planAnalysis(request)
                }.value
            } else {
                planned = try await current.planAnalysis(request)
            }
            afterPlanning = try await current.snapshot()
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    func run() async throws {
        let current = try #require(session)
        do {
            let stream = try await current.executeAnalysisPlan(#require(request))
            for try await event in stream.events {
                switch event {
                case let .progress(value):
                    #expect(terminalCount == 0)
                    #expect(value.operationID == stream.operationID)
                    progress.append(value)
                case let .completed(value):
                    terminalCount += 1
                    #expect(value.operationID == stream.operationID)
                    execution = value
                }
            }
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    func cleanup() async throws {
        await session?.close()
        session = nil
        if let root { try FileManager.default.removeItem(at: root) }
        root = nil
    }
}

@MainActor
private var plannerContractWorld: BDDPlannerContractWorld {
    Scenario.state(BDDPlannerContractWorld.init)
}

@MainActor
func registerPlannerContractSteps() {
    AfterScenario { _ in try await plannerContractWorld.cleanup() }
    Given("la raccolta originale del planner contiene sei fonti e gruppi tre più tre") { _, _ in
        try await plannerContractWorld.prepare()
    }
    Given("il planner riceve l'intento {string}") { match, _ in
        plannerContractWorld.makeRequest(intent: try match.first(\.string))
    }
    When("pianifico la raccolta attraverso GlifiKit") { _, _ in
        try await plannerContractWorld.plan()
    }
    When("pianifico la raccolta con task già cancellato") { _, _ in
        try await plannerContractWorld.plan(cancelled: true)
    }
    Then(#/^il piano dichiara stato "([^"]+)" operazioni JSON (.+) e ruoli JSON (.+)$/#) {
        match, _ in
        let world = plannerContractWorld
        let result = try #require(world.planned)
        let plan = result.plan
        let operations = try plannerContractStrings(String(match.2))
        let roles = try plannerContractStrings(String(match.3))
        world.expectedOperations = operations
        world.expectedRoles = roles
        #expect(world.failure == nil)
        #expect(plan.intent == world.request?.intent)
        #expect(plan.status == String(match.1))
        #expect(plan.steps.map(\.operation) == operations)
        #expect(plan.steps.map(\.role) == roles)
        #expect(plan.steps.map(\.order) == Array(plan.steps.indices))
        #expect(plan.totalEstimatedWorkUnits == plan.steps.reduce(0) { $0 + $1.estimatedWorkUnits })
        #expect(
            plan.unresolvedReasonIdentifiers
                == (operations.isEmpty ? ["planner.no-capability-for-intent"] : []))
    }
    Then(#/^le nove capability includono JSON (.+) con profilo dipendente "([^"]+)"$/#) {
        match, _ in
        let plan = try #require(plannerContractWorld.planned).plan
        let includedNames = try plannerContractStrings(String(match.1))
        let included = try Set(includedNames.map { try #require(plannerContractCapabilities[$0]) })
        #expect(
            plan.decisions.map(\.capabilityIdentifier)
                == plannerContractCapabilityOrder.compactMap { plannerContractCapabilities[$0] })
        #expect(plan.decisions.count == 9)
        #expect(Set(plan.decisions.filter(\.isIncluded).map(\.capabilityIdentifier)) == included)
        for decision in plan.decisions {
            if included.contains(decision.capabilityIdentifier) {
                #expect(decision.selectedBackendIdentifier == "swift-reference-v1")
                #expect(decision.fallbackIdentifiers.isEmpty)
                if decision.capabilityIdentifier == plannerContractCapabilities["profile"] {
                    #expect(decision.applicability == "applicable")
                    #expect(
                        decision.reasonIdentifiers == [
                            String(match.2) == "sì"
                                ? "planner.dependency-required" : "planner.intent-supported"
                        ])
                } else {
                    #expect(decision.applicability == "conditional")
                    #expect(!decision.caveatIdentifiers.isEmpty)
                    #expect(
                        decision.reasonIdentifiers == [
                            decision.capabilityIdentifier == plannerContractCapabilities["keyness"]
                                ? "planner.comparison-groups-valid" : "planner.intent-supported"
                        ])
                }
            } else {
                #expect(!decision.isIncluded)
                #expect(decision.applicability == "notApplicable")
                #expect(decision.reasonIdentifiers == ["planner.intent-not-supported"])
                #expect(decision.selectedBackendIdentifier == nil)
            }
        }
    }
    Then("il piano conserva le sei fonti i gruppi e una sola nuova revisione persistita") { _, _ in
        let world = plannerContractWorld
        let before = try #require(world.before)
        let after = try #require(world.afterPlanning)
        let result = try #require(world.planned)
        let plan = result.plan
        #expect(result.projectID == before.projectID)
        #expect(result.sourceGeneration == before.generation)
        #expect(plan.resolvedScopeSourceRevisionIDs == world.ids.sorted())
        #expect(plan.targetSourceRevisionIDs == world.ids.prefix(3).sorted())
        #expect(plan.referenceSourceRevisionIDs == world.ids.suffix(3).sorted())
        #expect(plan.collectionProfile.sourceRevisionIDs == world.ids.sorted())
        #expect(plan.collectionProfile.sourceCount == 6)
        #expect(
            plan.collectionProfile.totalSourceByteCount
                == Int64(world.sourceBytes.values.reduce(0) { $0 + $1.count }))
        #expect(plan.collectionProfile.formatCounts.map(\.sourceCount).sorted() == [3, 3])
        #expect(after.projectID == before.projectID && after.sources == before.sources)
        #expect(after.generation == before.generation + 1)
        #expect(after.artifactCount == before.artifactCount + 1)
    }
    Then("ripianificare riusa identità contenuto e snapshot del piano") { _, _ in
        let world = plannerContractWorld
        let current = try #require(world.session)
        let repeated = try await current.planAnalysis(#require(world.request))
        let original = try #require(world.planned)
        #expect(repeated.artifactID == original.artifactID)
        #expect(repeated.analysisNodeID == original.analysisNodeID)
        #expect(repeated.plan == original.plan)
        #expect(try await current.snapshot() == world.afterPlanning)
    }
    When("eseguo il piano attraverso il flusso GlifiKit") { _, _ in
        try await plannerContractWorld.run()
    }
    Then("il flusso pubblica progresso monotono e un solo completamento coerente") { _, _ in
        let world = plannerContractWorld
        let result = try #require(world.execution)
        let planned = try #require(world.planned)
        #expect(world.failure == nil)
        #expect(world.terminalCount == 1)
        #expect(!world.progress.isEmpty)
        #expect(world.progress.map(\.revision) == Array(world.progress.indices))
        #expect(world.progress.first?.phase == "planning")
        #expect(world.progress.last?.phase == "finalizing")
        #expect(world.progress.last?.completed == 1 && world.progress.last?.total == 1)
        let executing = world.progress.filter { $0.phase == "executing" }
        #expect(executing.map(\.completed) == executing.map(\.completed).sorted())
        #expect(executing.last?.completed == result.completedWorkUnits)
        #expect(result.completedWorkUnits == result.estimatedWorkUnits)
        #expect(result.estimatedWorkUnits == planned.plan.totalEstimatedWorkUnits)
        #expect(result.planArtifactID == planned.artifactID)
        #expect(result.planAnalysisNodeID == planned.analysisNodeID)
        #expect(result.planStatus == planned.plan.status)
        #expect(result.terminalState == "completedWithCaveats")
        #expect(result.projectID == planned.projectID)
        #expect(result.sourceGeneration == world.afterPlanning?.generation)
        #expect(result.artifacts.map(\.operation) == world.expectedOperations)
        #expect(result.artifacts.map(\.role) == world.expectedRoles)
        #expect(result.artifacts.map(\.planStepIdentifier) == planned.plan.steps.map(\.identifier))
        #expect(
            result.artifacts.map(\.outputSchemaIdentifier)
                == planned.plan.steps.map(\.outputSchemaIdentifier))
        let snapshot = try await #require(world.session).snapshot()
        #expect(snapshot.sources == world.before?.sources)
        #expect(snapshot.generation == result.generation)
        #expect(snapshot.investigationEventCount == world.before?.investigationEventCount)
        let artifactIDs = Set(result.artifacts.map(\.artifactID))
        #expect(result.interpretation.sourceArtifactIDs == artifactIDs.sorted())
        for evidence in result.interpretation.evidence {
            #expect(Set(evidence.artifactIDs).isSubset(of: artifactIDs))
            for reference in evidence.sourceReferences {
                let bytes = try #require(world.sourceBytes[reference.sourceRevisionID])
                for range in reference.ranges {
                    try #require(
                        range.start >= 0 && range.end >= range.start && range.end <= bytes.count)
                    #expect(
                        String(data: bytes.subdata(in: range.start..<range.end), encoding: .utf8)
                            != nil)
                }
            }
        }
    }
    Then("una seconda esecuzione riusa i risultati del planner") { _, _ in
        let world = plannerContractWorld
        let current = try #require(world.session)
        let before = try await current.snapshot()
        let original = try #require(world.execution)
        world.execution = nil
        world.progress = []
        world.terminalCount = 0
        try await world.run()
        let repeated = try #require(world.execution)
        #expect(world.failure == nil && world.terminalCount == 1)
        #expect(repeated.operationID != original.operationID)
        #expect(repeated.artifacts == original.artifacts)
        #expect(repeated.planArtifactID == original.planArtifactID)
        #expect(repeated.interpretationArtifactID == original.interpretationArtifactID)
        #expect(repeated.interpretation == original.interpretation)
        #expect(try await current.snapshot() == before)
    }
    Then("il piano indisponibile fallisce senza completamenti e senza nuovi artifact") { _, _ in
        let world = plannerContractWorld
        try plannerContractFailure(
            try #require(world.failure), code: "runtime.plan-not-executable",
            category: "insufficientData",
            operation: "executePlan", retry: "afterCorrection")
        #expect(world.execution == nil && world.terminalCount == 0)
        #expect(try await #require(world.session).snapshot() == world.afterPlanning)
    }
    Then("la richiesta planner fallisce con codice {string} categoria {string} e retry {string}") {
        match, _ in
        let world = plannerContractWorld
        try plannerContractFailure(
            try #require(world.failure), code: match[\.string, index: 0],
            category: match[\.string, index: 1],
            operation: "plan", retry: match[\.string, index: 2])
        #expect(world.planned == nil && world.execution == nil)
        #expect(try await #require(world.session).snapshot() == world.before)
    }
}

private func plannerContractStrings(_ text: String) throws -> [String] {
    try JSONDecoder().decode([String].self, from: Data(text.utf8))
}

private func plannerContractFailure(
    _ failure: GlifiStudioFailure, code: String, category: String, operation: String, retry: String
) throws {
    #expect(failure.code == code)
    #expect(failure.category == category)
    #expect(failure.operation == operation)
    #expect(failure.retryDisposition == retry)
    #expect(failure.retainedState == "lastCommittedGeneration")
    #expect(failure.arguments.isEmpty)
}
