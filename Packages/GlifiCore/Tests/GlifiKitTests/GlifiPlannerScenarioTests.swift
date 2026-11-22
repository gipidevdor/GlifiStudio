// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import GlifiKit
import Testing

struct GlifiPlannerScenarioTests {
    @Test func publicIntentInventoryMatchesTheDeclaredScenarios() {
        #expect(
            Set(GlifiAnalyticalIntent.allCases.map(\.rawValue)) == [
                "understand.collection", "discover.contents", "identify.themes",
                "characterize.group", "compare.objects", "trace.change",
                "explore.relationships", "find.similar", "explore.object",
                "search.sources", "review.completely",
            ])
    }

    @Test(.timeLimit(.minutes(1)), arguments: GlifiAnalyticalIntent.allCases)
    func everyPublicIntentHasAnExplainableDurableOutcome(intent: GlifiAnalyticalIntent)
        async throws
    {
        try await withPlannerFixture { fixture in
            let expected = Self.contract(for: intent)
            let before = try await fixture.session.snapshot()
            let request = GlifiStudioAnalysisPlanRequest(
                intent: intent.rawValue,
                scopeSourceRevisionIDs: Array(fixture.ids.reversed()),
                targetSourceRevisionIDs: Array(fixture.ids.prefix(3).reversed()),
                referenceSourceRevisionIDs: Array(fixture.ids.suffix(3).reversed()))
            let planned = try await fixture.session.planAnalysis(request)
            let plan = planned.plan
            let afterPlanning = try await fixture.session.snapshot()

            #expect(planned.projectID == before.projectID)
            #expect(planned.sourceGeneration == before.generation)
            #expect(plan.intent == intent.rawValue)
            #expect(plan.status == expected.status)
            #expect(plan.unresolvedReasonIdentifiers == expected.unresolvedReasons)
            #expect(plan.resolvedScopeSourceRevisionIDs == fixture.ids.sorted())
            #expect(plan.collectionProfile.sourceRevisionIDs == fixture.ids.sorted())
            #expect(plan.collectionProfile.sourceCount == fixture.ids.count)
            #expect(plan.targetSourceRevisionIDs == fixture.ids.prefix(3).sorted())
            #expect(plan.referenceSourceRevisionIDs == fixture.ids.suffix(3).sorted())
            #expect(plan.steps.map(\.operation) == expected.operations)
            #expect(plan.steps.map(\.role) == expected.roles)
            #expect(plan.steps.map(\.order) == Array(plan.steps.indices))
            #expect(
                plan.totalEstimatedWorkUnits
                    == plan.steps.reduce(0) {
                        $0 + $1.estimatedWorkUnits
                    })
            #expect(afterPlanning.sourceCount == before.sourceCount)
            #expect(afterPlanning.artifactCount == before.artifactCount + 1)
            #expect(afterPlanning.generation == before.generation + 1)
            Self.checkDecisions(plan, contract: expected)

            let repeatedPlan = try await fixture.session.planAnalysis(request)
            #expect(repeatedPlan.artifactID == planned.artifactID)
            #expect(repeatedPlan.analysisNodeID == planned.analysisNodeID)
            #expect(repeatedPlan.plan == plan)
            #expect(try await fixture.session.snapshot() == afterPlanning)

            if expected.operations.isEmpty {
                try await Self.rejectExecution(
                    request, in: fixture.session, preserving: afterPlanning)
            } else {
                let result = try await Self.completeExecution(request, in: fixture.session)
                #expect(result.sourceGeneration == afterPlanning.generation)
                #expect(result.planStatus == expected.status)
                // This short collection retains interpretation caveats even for a ready plan.
                #expect(result.terminalState == "completedWithCaveats")
                #expect(result.planArtifactID == planned.artifactID)
                #expect(result.planAnalysisNodeID == planned.analysisNodeID)
                #expect(result.projectID == before.projectID)
                #expect(result.artifacts.map(\.operation) == expected.operations)
                #expect(result.artifacts.map(\.role) == expected.roles)
                #expect(result.artifacts.map(\.planStepIdentifier) == plan.steps.map(\.identifier))
                #expect(
                    result.artifacts.map(\.outputSchemaIdentifier)
                        == plan.steps.map(\.outputSchemaIdentifier))
                #expect(result.estimatedWorkUnits == plan.totalEstimatedWorkUnits)
                #expect(result.completedWorkUnits == result.estimatedWorkUnits)
                try Self.checkGrounding(result, plan: plan, sourceBytes: fixture.sourceBytes)

                let settled = try await fixture.session.snapshot()
                #expect(settled.generation == result.generation)
                #expect(settled.sourceCount == before.sourceCount)
                #expect(settled.investigationEventCount == before.investigationEventCount)
                #expect(settled.artifactCount > afterPlanning.artifactCount)

                let second = try await Self.completeExecution(request, in: fixture.session)
                #expect(second.operationID != result.operationID)
                #expect(second.sourceGeneration == settled.generation)
                #expect(second.generation == settled.generation)
                #expect(second.artifacts == result.artifacts)
                #expect(second.planArtifactID == result.planArtifactID)
                #expect(second.interpretationArtifactID == result.interpretationArtifactID)
                #expect(
                    second.interpretationAnalysisNodeID
                        == result.interpretationAnalysisNodeID)
                #expect(second.interpretation == result.interpretation)
                #expect(try await fixture.session.snapshot() == settled)
            }
        }
    }

    @Test(.timeLimit(.minutes(1)), arguments: PlannerPrecondition.allCases)
    func nonExecutablePlansExplainTheirPreconditionsWithoutAnalyticalCommits(
        scenario: PlannerPrecondition
    ) async throws {
        try await withPlannerFixture(sourceTexts: scenario == .emptyScope ? [] : plannerTexts) {
            fixture in
            let before = try await fixture.session.snapshot()
            let request = try scenario.request(ids: fixture.ids)
            let planned = try await fixture.session.planAnalysis(request)
            let afterPlanning = try await fixture.session.snapshot()

            #expect(planned.plan.status == "notExecutable")
            #expect(planned.plan.steps.isEmpty)
            #expect(planned.plan.decisions.allSatisfy { !$0.isIncluded })
            #expect(planned.plan.unresolvedReasonIdentifiers == scenario.expectedReasons)
            #expect(planned.plan.totalEstimatedWorkUnits == 0)
            #expect(afterPlanning.sourceCount == before.sourceCount)
            #expect(afterPlanning.artifactCount == before.artifactCount + 1)
            #expect(afterPlanning.generation == before.generation + 1)

            // Persisting the explanation is intentional; rejected execution adds no artifacts.
            try await Self.rejectExecution(
                request, in: fixture.session, preserving: afterPlanning,
                resourceLimited: scenario == .zeroBudget)
            let repeated = try await fixture.session.planAnalysis(request)
            #expect(repeated.artifactID == planned.artifactID)
            #expect(repeated.plan == planned.plan)
            #expect(try await fixture.session.snapshot() == afterPlanning)
        }
    }

    @Test(.timeLimit(.minutes(1)), arguments: InvalidPlannerRequest.allCases)
    func invalidRequestsPreserveTheWholeProject(scenario: InvalidPlannerRequest) async throws {
        try await withPlannerFixture { fixture in
            let before = try await fixture.session.snapshot()
            let request = try scenario.request(ids: fixture.ids)
            do {
                _ = try await fixture.session.planAnalysis(request)
                Issue.record("An invalid planner request must fail before persisting a plan")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == scenario.expectedCode)
                #expect(failure.category == "invalidInput")
                #expect(failure.operation == "plan")
                #expect(failure.retryDisposition == "afterCorrection")
                #expect(failure.retainedState == "lastCommittedGeneration")
                #expect(failure.arguments.isEmpty)
            }
            #expect(try await fixture.session.snapshot() == before)
            #expect(try await fixture.session.investigationHeads().isEmpty)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func anEmptyTokenPopulationProducesAnExplicitInsufficientEvidenceOutcome() async throws {
        try await withPlannerFixture(sourceTexts: ["… ! ?\n"]) { fixture in
            let request = GlifiStudioAnalysisPlanRequest(intent: "understand.collection")
            let result = try await Self.completeExecution(request, in: fixture.session)
            #expect(result.artifacts.map(\.operation) == ["analyzeCorpus"])
            #expect(result.interpretation.findings.isEmpty)
            #expect(result.interpretation.evidence.isEmpty)
            let insufficient = try #require(result.interpretation.insufficientEvidence)
            #expect(insufficient.reasonIdentifiers == ["interpretation.empty-token-population"])
            #expect(insufficient.caveats.contains { $0.severity == "blocking" })
            let settled = try await fixture.session.snapshot()
            let repeated = try await Self.completeExecution(request, in: fixture.session)
            #expect(repeated.interpretation == result.interpretation)
            #expect(repeated.interpretationArtifactID == result.interpretationArtifactID)
            #expect(try await fixture.session.snapshot() == settled)
        }
    }

    private static func checkDecisions(
        _ plan: GlifiStudioAnalysisPlan, contract: PlannerIntentContract
    ) {
        #expect(
            plan.decisions.map(\.capabilityIdentifier) == PlannerCapability.allCases.map(\.rawValue)
        )
        #expect(
            Set(plan.decisions.filter(\.isIncluded).map(\.capabilityIdentifier))
                == Set(contract.includedCapabilities.map(\.rawValue)))
        for decision in plan.decisions {
            if contract.includedCapabilities.contains(where: {
                $0.rawValue == decision.capabilityIdentifier
            }) {
                #expect(decision.isIncluded)
                #expect(decision.selectedBackendIdentifier == "swift-reference-v1")
                #expect(decision.fallbackIdentifiers.isEmpty)
                if decision.capabilityIdentifier == PlannerCapability.profile.rawValue {
                    #expect(decision.applicability == "applicable")
                    #expect(
                        decision.reasonIdentifiers
                            == [
                                contract.dependencyProfile
                                    ? "planner.dependency-required" : "planner.intent-supported"
                            ])
                } else {
                    #expect(decision.applicability == "conditional")
                    #expect(!decision.caveatIdentifiers.isEmpty)
                    #expect(
                        decision.reasonIdentifiers
                            == [
                                decision.capabilityIdentifier == PlannerCapability.keyness.rawValue
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

    private static func completeExecution(
        _ request: GlifiStudioAnalysisPlanRequest, in session: GlifiStudioProjectSession
    ) async throws -> GlifiStudioAnalysisExecutionResult {
        let execution = try await session.executeAnalysisPlan(request)
        var progress: [GlifiStudioOperationProgress] = []
        var results: [GlifiStudioAnalysisExecutionResult] = []
        for try await event in execution.events {
            switch event {
            case let .progress(value):
                #expect(results.isEmpty)
                progress.append(value)
            case let .completed(value): results.append(value)
            }
        }
        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.operationID == execution.operationID)
        #expect(!progress.isEmpty)
        #expect(progress.map(\.revision) == Array(progress.indices))
        #expect(progress.allSatisfy { $0.operationID == execution.operationID })
        #expect(progress.first?.phase == "planning")
        #expect(progress.last?.phase == "finalizing")
        #expect(progress.last?.completed == 1)
        #expect(progress.last?.total == 1)
        let executing = progress.filter { $0.phase == "executing" }
        #expect(executing.map(\.completed) == executing.map(\.completed).sorted())
        #expect(executing.last?.completed == result.completedWorkUnits)
        #expect(result.completedWorkUnits == result.estimatedWorkUnits)
        return result
    }

    private static func rejectExecution(
        _ request: GlifiStudioAnalysisPlanRequest, in session: GlifiStudioProjectSession,
        preserving snapshot: GlifiStudioProjectSnapshot, resourceLimited: Bool = false
    ) async throws {
        var completed = false
        do {
            let execution = try await session.executeAnalysisPlan(request)
            for try await event in execution.events {
                switch event {
                case .progress: break
                case .completed: completed = true
                }
            }
            Issue.record("A non-executable plan must terminate with its typed failure")
        } catch let failure as GlifiStudioFailure {
            #expect(
                failure.code
                    == (resourceLimited
                        ? "runtime.plan-resource-limited" : "runtime.plan-not-executable"))
            #expect(
                failure.category == (resourceLimited ? "insufficientResources" : "insufficientData")
            )
            #expect(failure.operation == "executePlan")
            #expect(
                failure.retryDisposition
                    == (resourceLimited ? "afterConditionsChange" : "afterCorrection"))
            #expect(failure.retainedState == "lastCommittedGeneration")
        }
        #expect(!completed)
        #expect(try await session.snapshot() == snapshot)
    }

    private static func checkGrounding(
        _ result: GlifiStudioAnalysisExecutionResult, plan: GlifiStudioAnalysisPlan,
        sourceBytes: [String: Data]
    ) throws {
        let interpretation = result.interpretation
        let artifactIDs = Set(result.artifacts.map(\.artifactID))
        let nodeIDs = Set(result.artifacts.map(\.analysisNodeID))
        #expect(interpretation.intent == plan.intent)
        #expect(interpretation.planArtifactID == result.planArtifactID)
        #expect(interpretation.planAnalysisNodeID == result.planAnalysisNodeID)
        #expect(interpretation.sourceArtifactIDs == artifactIDs.sorted())
        #expect(interpretation.findings.count == interpretation.evidence.count)
        #expect(interpretation.findings.isEmpty == (interpretation.insufficientEvidence != nil))
        let evidenceIDs = Set(interpretation.evidence.map(\.id))
        #expect(evidenceIDs.count == interpretation.evidence.count)
        let permittedFamilies = Set(
            plan.steps.compactMap {
                findingFamiliesByOperation[$0.operation]
            })
        for evidence in interpretation.evidence {
            #expect(!evidence.artifactIDs.isEmpty)
            #expect(Set(evidence.artifactIDs).isSubset(of: artifactIDs))
            #expect(nodeIDs.contains(evidence.analysisNodeID))
            #expect(!evidence.methodIdentifiers.isEmpty)
            #expect(!evidence.sourceReferences.isEmpty)
            for reference in evidence.sourceReferences {
                #expect(plan.resolvedScopeSourceRevisionIDs.contains(reference.sourceRevisionID))
                let bytes = try #require(sourceBytes[reference.sourceRevisionID])
                for range in reference.ranges {
                    #expect(
                        range.start >= 0 && range.end >= range.start && range.end <= bytes.count)
                    if range.start >= 0 && range.end >= range.start && range.end <= bytes.count {
                        #expect(
                            String(
                                data: bytes.subdata(in: range.start..<range.end), encoding: .utf8)
                                != nil)
                    }
                }
            }
        }
        for finding in interpretation.findings {
            #expect(permittedFamilies.contains(finding.familyIdentifier))
            #expect(finding.rankFactors.hasCompleteLineage)
            #expect(finding.evidenceReferences.contains { $0.disposition == "supporting" })
            #expect(finding.evidenceReferences.allSatisfy { evidenceIDs.contains($0.evidenceID) })
        }
        #expect(
            try JSONDecoder().decode(
                GlifiStudioAnalysisInterpretation.self,
                from: JSONEncoder().encode(interpretation)) == interpretation)
    }

    private static func contract(for intent: GlifiAnalyticalIntent) -> PlannerIntentContract {
        switch intent {
        case .understandCollection:
            .init(
                operations: ["analyzeCorpus"], roles: ["scope"], includedCapabilities: [.profile],
                status: "ready")
        case .discoverContents:
            .init(
                operations: ["analyzeCorpus", "analyzeWindowCollocations"],
                roles: ["scope", "scope"], includedCapabilities: [.profile, .collocations],
                status: "readyWithCaveats")
        case .identifyThemes:
            .init(
                operations: ["analyzeWindowNetwork", "analyzeCorrespondence", "clusterDocuments"],
                roles: ["scope", "scope", "scope"],
                includedCapabilities: [.network, .correspondence, .clustering],
                status: "readyWithCaveats")
        case .characterizeGroup:
            .init(
                operations: ["analyzeCorpus", "analyzeCorpus", "analyzeCorpus", "compareKeyness"],
                roles: ["scope", "target", "reference", "comparison"],
                includedCapabilities: [.profile, .keyness], status: "readyWithCaveats")
        case .compareObjects:
            .init(
                operations: [
                    "analyzeCorpus", "analyzeCorpus", "compareKeyness", "compareSimilarity",
                    "compareGroupMetric",
                ], roles: ["target", "reference", "comparison", "comparison", "comparison"],
                includedCapabilities: [.profile, .keyness, .similarity, .groupMetric],
                status: "readyWithCaveats", dependencyProfile: true)
        case .exploreRelationships:
            .init(
                operations: [
                    "analyzeAssociation", "analyzeWindowCollocations", "analyzeWindowNetwork",
                    "analyzeCorrespondence",
                ], roles: ["scope", "scope", "scope", "scope"],
                includedCapabilities: [.association, .collocations, .network, .correspondence],
                status: "readyWithCaveats")
        case .findSimilar:
            .init(
                operations: ["clusterDocuments", "compareSimilarity"],
                roles: ["scope", "comparison"], includedCapabilities: [.clustering, .similarity],
                status: "readyWithCaveats")
        case .reviewCompletely:
            .init(
                operations: [
                    "analyzeCorpus", "analyzeCorpus", "analyzeCorpus", "compareKeyness",
                    "analyzeAssociation", "analyzeWindowCollocations", "analyzeWindowNetwork",
                    "analyzeCorrespondence", "clusterDocuments", "compareSimilarity",
                    "compareGroupMetric",
                ],
                roles: [
                    "scope", "target", "reference", "comparison", "scope", "scope", "scope",
                    "scope", "scope", "comparison", "comparison",
                ], includedCapabilities: PlannerCapability.allCases, status: "readyWithCaveats")
        case .traceChange, .exploreObject, .searchSources:
            .init(
                operations: [], roles: [], includedCapabilities: [], status: "notExecutable",
                unresolvedReasons: ["planner.no-capability-for-intent"])
        }
    }
}

private struct PlannerIntentContract: Sendable {
    let operations: [String]
    let roles: [String]
    let includedCapabilities: [PlannerCapability]
    let status: String
    var dependencyProfile = false
    var unresolvedReasons: [String] = []
}

private enum PlannerCapability: String, CaseIterable, Sendable {
    case profile = "studio.glifi.capability.corpus-profile.v1"
    case keyness = "studio.glifi.capability.keyness.v1"
    case association = "studio.glifi.capability.document-term-association.v1"
    case collocations = "studio.glifi.capability.window-collocation.v1"
    case network = "studio.glifi.capability.window-network.v1"
    case correspondence = "studio.glifi.capability.correspondence-analysis.v1"
    case clustering = "studio.glifi.capability.document-clustering.v1"
    case similarity = "studio.glifi.capability.group-similarity.v1"
    case groupMetric = "studio.glifi.capability.group-location-comparison.v1"
}

private let findingFamiliesByOperation = [
    "analyzeCorpus": "finding-family.corpus-profile.v1",
    "compareKeyness": "finding-family.keyness.v1",
    "analyzeAssociation": "finding-family.contingency.v1",
    "analyzeWindowCollocations": "finding-family.collocation.v1",
    "analyzeWindowNetwork": "finding-family.lexical-network.v1",
    "analyzeCorrespondence": "finding-family.correspondence.v1",
    "clusterDocuments": "finding-family.clustering.v1",
    "compareSimilarity": "finding-family.similarity.v1",
    "compareGroupMetric": "finding-family.group-location.v1",
]

enum PlannerPrecondition: String, CaseIterable, Sendable {
    case emptyScope, missingGroups, overlappingGroups, insufficientSources, zeroBudget

    var expectedReasons: [String] {
        switch self {
        case .emptyScope: ["planner.empty-scope"]
        case .missingGroups: Array(repeating: "planner.comparison-groups-required", count: 3)
        case .overlappingGroups:
            Array(repeating: "planner.comparison-groups-must-be-disjoint", count: 3)
        case .insufficientSources:
            ["planner.comparison-groups-required", "planner.insufficient-sources"]
        case .zeroBudget: ["planner.work-budget-exceeded"]
        }
    }

    func request(ids: [String]) throws -> GlifiStudioAnalysisPlanRequest {
        switch self {
        case .emptyScope: .init(intent: "understand.collection")
        case .missingGroups: .init(intent: "compare.objects")
        case .overlappingGroups:
            .init(
                intent: "compare.objects", targetSourceRevisionIDs: [try #require(ids.first)],
                referenceSourceRevisionIDs: [try #require(ids.first)])
        case .insufficientSources:
            .init(intent: "find.similar", scopeSourceRevisionIDs: [try #require(ids.first)])
        case .zeroBudget:
            .init(intent: "understand.collection", maximumEstimatedWorkUnits: 0)
        }
    }
}

enum InvalidPlannerRequest: String, CaseIterable, Sendable {
    case invalidIntent, malformedSourceID, unknownSource, duplicateScope, outsideScope,
        negativeBudget

    var expectedCode: String {
        switch self {
        case .invalidIntent: "planner.invalid-intent"
        case .malformedSourceID: "planner.invalid-source-identifier"
        case .unknownSource: "planner.source-not-found"
        case .duplicateScope: "planner.duplicate-source"
        case .outsideScope: "planner.group-outside-scope"
        case .negativeBudget: "planner.invalid-work-budget"
        }
    }

    func request(ids: [String]) throws -> GlifiStudioAnalysisPlanRequest {
        switch self {
        case .invalidIntent: .init(intent: "intent.unsupported-test-canary")
        case .malformedSourceID:
            .init(intent: "understand.collection", scopeSourceRevisionIDs: ["not-a-source-id"])
        case .unknownSource:
            .init(
                intent: "understand.collection",
                scopeSourceRevisionIDs: [SourceRevisionID().canonicalValue])
        case .duplicateScope:
            .init(
                intent: "understand.collection",
                scopeSourceRevisionIDs: Array(repeating: try #require(ids.first), count: 2))
        case .outsideScope:
            .init(
                intent: "compare.objects", scopeSourceRevisionIDs: [try #require(ids.first)],
                targetSourceRevisionIDs: [try #require(ids.first)],
                referenceSourceRevisionIDs: [try #require(ids.last)])
        case .negativeBudget:
            .init(intent: "understand.collection", maximumEstimatedWorkUnits: -1)
        }
    }
}

private struct PlannerScenarioFixture: Sendable {
    let session: GlifiStudioProjectSession
    let ids: [String]
    let sourceBytes: [String: Data]
}

private let plannerTexts = [
    "casa casa giardino mare luce città",
    "casa giardino albero albero sole",
    "casa sole luce luce parco parco parco",
    "mare mare barca costa luce",
    "mare barca onda onda acqua acqua",
    "mare onda acqua acqua acqua luce città città",
]

private func withPlannerFixture(
    sourceTexts: [String] = plannerTexts,
    body: @Sendable (PlannerScenarioFixture) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiPlannerScenarios-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let service = GlifiStudioService(
        runtimeEnvironment: .init {
            .init(
                isLowPowerModeEnabled: false, thermalCondition: .nominal, memoryPressure: .nominal,
                isApplicationActive: true)
        })
    let session = try await service.createProject(at: root.appending(path: "Scenarios.glifi"))
    do {
        var ids: [String] = []
        var sourceBytes: [String: Data] = [:]
        for (index, text) in sourceTexts.enumerated() {
            let format: GlifiStudioTextFormat = index.isMultiple(of: 2) ? .plainText : .markdown
            let bytes = Data((format == .markdown ? "# Scenario\n\(text)" : text).utf8)
            let url = root.appending(path: "source-\(index).data")
            try bytes.write(to: url)
            let imported = try await session.importText(at: url, format: format)
            let known = Set(ids)
            let id = try #require(
                imported.project.sources.first { !known.contains($0.sourceRevisionID) }?
                    .sourceRevisionID)
            ids.append(id)
            sourceBytes[id] = bytes
        }
        try await body(.init(session: session, ids: ids, sourceBytes: sourceBytes))
        await session.close()
    } catch {
        await session.close()
        throw error
    }
}
