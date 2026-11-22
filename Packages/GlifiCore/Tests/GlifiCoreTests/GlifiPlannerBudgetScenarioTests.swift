// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiPlannerBudgetScenarioTests {
    @Test(.timeLimit(.minutes(1)), arguments: LegacyPlannerBudgetScenario.allCases)
    func legacyPlansStayReadableWhileCurrentRequestsUseTheBudgetCorrectProducer(
        scenario: LegacyPlannerBudgetScenario
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiLegacyPlannerBudget-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let packageURL = root.appending(path: "Budget.glifi", directoryHint: .isDirectory)
        let project = try GlifiProjectPackage.create(at: packageURL)
        let importer = GlifiTextImporter()
        let first = try importer.importText(
            from: Data(String(repeating: "a", count: 100).utf8), format: .plainText,
            sourceRevisionID: SourceRevisionID(
                uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))))
        let second = try importer.importText(
            from: Data(String(repeating: "b", count: 200).utf8), format: .markdown,
            sourceRevisionID: SourceRevisionID(
                uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))))
        _ = try await project.importText(first)
        _ = try await project.importText(second)
        let initial = await project.snapshot()
        let generousRequest = try GlifiAnalysisPlanRequest(
            intent: .compareObjects,
            targetSourceRevisionIDs: [first.sourceRevisionID],
            referenceSourceRevisionIDs: [second.sourceRevisionID],
            maximumEstimatedWorkUnits: 1_668)
        let generous = try GlifiAnalysisPlanner().plan(
            request: generousRequest, sourceRootDigest: initial.sourceRootDigest,
            configuredLanguageCode: "it",
            sources: initial.sources.map {
                try GlifiPlanningSource(
                    sourceRevisionID: $0.sourceRevisionID, format: $0.format,
                    byteCount: $0.byteCount)
            })
        #expect(generous.totalEstimatedWorkUnits == 1_668)

        // Producer 1 admitted the same four steps at 1000 because it did not debit keyness.
        // Replacing only this request field reproduces that historical output, independently
        // of whether the current builder has already corrected its cumulative admission.
        let legacyPlan: GlifiAnalysisPlan = try replacingPlannerJSONField(
            generous, key: "maximumEstimatedWorkUnits", with: scenario.maximumWork)
        #expect(legacyPlan.plannerIdentifier == "planner-v2")
        #expect(legacyPlan.capabilityCatalogIdentifier == "capability-catalog-v2")
        #expect(legacyPlan.totalEstimatedWorkUnits == 1_668)
        #expect(
            (legacyPlan.totalEstimatedWorkUnits > legacyPlan.maximumEstimatedWorkUnits)
                == (scenario == .oversubscribed))
        let currentDescriptor = try GlifiAnalysisArtifactDescriptorFactory.analysisPlan(
            projectID: initial.projectID, sourceRootDigest: initial.sourceRootDigest,
            tokenizationContractIdentifier: GlifiItalianTokenizer.contractIdentifier,
            plan: legacyPlan)
        let legacyDescriptor: GlifiAnalysisDescriptor = try replacingPlannerJSONField(
            currentDescriptor, key: "algorithmVersion", with: "1")
        let legacyNodeID = try legacyDescriptor.nodeID()
        let legacyPayload = GlifiAnalysisPlanArtifactPayload(
            analysisNodeID: legacyNodeID, plan: legacyPlan)
        let stored = try await project.storeArtifact(legacyPayload, descriptor: legacyDescriptor)
        let legacyRecord = try #require(stored.artifacts.first { $0.node.id == legacyNodeID })
        let legacyBytes = try await project.artifactData(for: legacyRecord.artifactID)
        #expect(legacyRecord.node.descriptor.algorithmVersion == "1")
        #expect(
            legacyRecord.node.descriptor.outputSchemaIdentifier
                == "studio.glifi.artifact.analysis-plan.v1")

        let reopened = try GlifiProjectPackage.open(at: packageURL)
        #expect(await reopened.snapshot() == stored)
        #expect(try await reopened.artifactData(for: legacyRecord.artifactID) == legacyBytes)
        #expect(
            try JSONDecoder().decode(GlifiAnalysisPlanArtifactPayload.self, from: legacyBytes)
                == legacyPayload)

        let request = try GlifiAnalysisPlanRequest(
            intent: .compareObjects,
            targetSourceRevisionIDs: [first.sourceRevisionID],
            referenceSourceRevisionIDs: [second.sourceRevisionID],
            maximumEstimatedWorkUnits: scenario.maximumWork)
        let engine = GlifiEngine()
        let rebuilt = try await engine.planAnalysis(in: reopened, request: request)
        #expect(rebuilt.plan.totalEstimatedWorkUnits == scenario.expectedCurrentCost)
        #expect(rebuilt.plan.totalEstimatedWorkUnits <= scenario.maximumWork)
        #expect(rebuilt.analysisNodeID != legacyNodeID)
        #expect(rebuilt.artifactID != legacyRecord.artifactID)
        let current = await reopened.snapshot()
        #expect(current.generation == stored.generation + 1)
        #expect(current.artifacts.count == stored.artifacts.count + 1)
        let currentRecord = try #require(
            current.artifacts.first { $0.artifactID == rebuilt.artifactID })
        #expect(currentRecord.node.descriptor.algorithmVersion == "2")
        #expect(
            currentRecord.node.descriptor.algorithmIdentifier
                == legacyDescriptor.algorithmIdentifier)
        #expect(
            currentRecord.node.descriptor.outputSchemaIdentifier
                == legacyDescriptor.outputSchemaIdentifier)
        #expect(
            currentRecord.node.descriptor.descriptorSchemaIdentifier
                == legacyDescriptor.descriptorSchemaIdentifier)
        #expect(current.artifacts.contains(legacyRecord))
        #expect(try await reopened.artifactData(for: legacyRecord.artifactID) == legacyBytes)

        let repeated = try await engine.planAnalysis(in: reopened, request: request)
        #expect(repeated.artifactID == rebuilt.artifactID)
        #expect(repeated.analysisNodeID == rebuilt.analysisNodeID)
        #expect(repeated.plan == rebuilt.plan)
        #expect(await reopened.snapshot() == current)
        let reopenedAgain = try GlifiProjectPackage.open(at: packageURL)
        #expect(await reopenedAgain.snapshot() == current)
        #expect(try await reopenedAgain.artifactData(for: legacyRecord.artifactID) == legacyBytes)
        let reusedAfterReopen = try await engine.planAnalysis(in: reopenedAgain, request: request)
        #expect(reusedAfterReopen.artifactID == rebuilt.artifactID)
        #expect(reusedAfterReopen.plan == rebuilt.plan)
        #expect(await reopenedAgain.snapshot() == current)
    }

    @Test(.timeLimit(.minutes(1)), arguments: PlannerBudgetScenario.boundaries)
    func comparisonBundlesAndExtendedFamiliesShareOneGlobalBudget(
        scenario: PlannerBudgetScenario
    ) async throws {
        let firstID = SourceRevisionID(
            uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")))
        let secondID = SourceRevisionID(
            uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")))
        let first = try GlifiPlanningSource(
            sourceRevisionID: firstID, format: .plainText, byteCount: 100)
        let second = try GlifiPlanningSource(
            sourceRevisionID: secondID, format: .markdown, byteCount: 200)
        let request = try GlifiAnalysisPlanRequest(
            intent: scenario.intent,
            targetSourceRevisionIDs: [firstID], referenceSourceRevisionIDs: [secondID],
            maximumEstimatedWorkUnits: scenario.maximumWork)
        let planner = GlifiAnalysisPlanner()
        let plan = try planner.plan(
            request: request, sourceRootDigest: "sha256:" + String(repeating: "a", count: 64),
            configuredLanguageCode: "it", sources: [second, first])

        // Oracle from the versioned cost contracts, not from planner decisions or totals:
        // profiles = 100 + 64 = 164 and 200 + 64 = 264;
        // comparison = 300 + 2 * 128 = 556, so its atomic bundle costs 984;
        // scope profile = 428; similarity = 428 + 2 * 128 = 684;
        // association = 428 + 2 * 256 = 940; group metric = 428 + 2 * 2048 = 4524.
        let expectedTotal = scenario.steps.reduce(Int64(0)) { $0 + $1.cost }
        #expect(plan.maximumEstimatedWorkUnits == scenario.maximumWork)
        #expect(plan.totalEstimatedWorkUnits <= request.maximumEstimatedWorkUnits)
        #expect(plan.totalEstimatedWorkUnits == expectedTotal)
        #expect(plan.steps.map(\.operation) == scenario.steps.map(\.operation))
        #expect(plan.steps.map(\.role) == scenario.steps.map(\.role))
        #expect(plan.steps.map(\.estimatedWorkUnits) == scenario.steps.map(\.cost))
        #expect(plan.steps.reduce(Int64(0)) { $0 + $1.estimatedWorkUnits } == expectedTotal)

        let includedCapabilities = Set(scenario.steps.map(\.capability))
        #expect(
            Set(plan.decisions.filter(\.isIncluded).map(\.capabilityIdentifier))
                == includedCapabilities)
        for decision in plan.decisions where decision.applicability == .deferred {
            #expect(!decision.isIncluded)
            #expect(decision.reasonIdentifiers == ["planner.work-budget-exceeded"])
        }
        let keyness = try #require(
            plan.decisions.first {
                $0.capabilityIdentifier == "studio.glifi.capability.keyness.v1"
            })
        #expect(keyness.estimatedWorkUnits == 984)
        #expect(keyness.isIncluded == scenario.steps.contains(.keyness))
        if keyness.isIncluded {
            #expect(keyness.applicability == .conditional)
            #expect(keyness.reasonIdentifiers == ["planner.comparison-groups-valid"])
            let comparison = try #require(plan.steps.first { $0.operation == .compareKeyness })
            #expect(
                comparison.dependencyStepIdentifiers
                    == [
                        "plan-step.corpus-profile.target.v1",
                        "plan-step.corpus-profile.reference.v1",
                    ])
        } else {
            #expect(keyness.applicability == .deferred)
            #expect(keyness.reasonIdentifiers == ["planner.work-budget-exceeded"])
        }

        let reordered = try planner.plan(
            request: request, sourceRootDigest: "sha256:" + String(repeating: "a", count: 64),
            configuredLanguageCode: "it", sources: [first, second])
        #expect(reordered == plan)
    }
}

enum LegacyPlannerBudgetScenario: String, CaseIterable, Sendable {
    case oversubscribed, withinBudget

    var maximumWork: Int64 {
        switch self {
        case .oversubscribed: 1_000
        case .withinBudget: 1_668
        }
    }

    var expectedCurrentCost: Int64 {
        switch self {
        case .oversubscribed: 984
        case .withinBudget: 1_668
        }
    }
}

private func replacingPlannerJSONField<Value: Codable>(
    _ value: Value, key: String, with replacement: Any
) throws -> Value {
    let encoded = try JSONEncoder().encode(value)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object[key] = replacement
    return try JSONDecoder().decode(
        Value.self, from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
}

struct PlannerBudgetScenario: Sendable {
    let maximumWork: Int64
    let steps: [PlannerBudgetStep]
    var intent: GlifiAnalyticalIntent = .compareObjects

    static let boundaries: [Self] = {
        let keyness: [PlannerBudgetStep] = [.targetProfile, .referenceProfile, .keyness]
        return [
            .init(maximumWork: 983, steps: [.similarity]),
            .init(maximumWork: 984, steps: keyness),
            .init(maximumWork: 1_000, steps: keyness),
            .init(maximumWork: 1_667, steps: keyness),
            .init(maximumWork: 1_668, steps: keyness + [.similarity]),
            .init(maximumWork: 6_191, steps: keyness + [.similarity]),
            .init(maximumWork: 6_192, steps: keyness + [.similarity, .groupMetric]),
            .init(maximumWork: 1_412, steps: [.scopeProfile] + keyness, intent: .reviewCompletely),
            .init(
                maximumWork: 2_352, steps: [.scopeProfile] + keyness + [.association],
                intent: .reviewCompletely),
        ]
    }()
}

enum PlannerBudgetStep: Equatable, Sendable {
    case scopeProfile, targetProfile, referenceProfile, keyness, association, similarity,
        groupMetric

    var cost: Int64 {
        switch self {
        case .scopeProfile: 428
        case .targetProfile: 164
        case .referenceProfile: 264
        case .keyness: 556
        case .association: 940
        case .similarity: 684
        case .groupMetric: 4_524
        }
    }

    var operation: GlifiPlannedOperation {
        switch self {
        case .scopeProfile, .targetProfile, .referenceProfile: .analyzeCorpus
        case .keyness: .compareKeyness
        case .association: .analyzeAssociation
        case .similarity: .compareSimilarity
        case .groupMetric: .compareGroupMetric
        }
    }

    var role: GlifiAnalysisPlanStepRole {
        switch self {
        case .scopeProfile, .association: .scope
        case .targetProfile: .target
        case .referenceProfile: .reference
        case .keyness, .similarity, .groupMetric: .comparison
        }
    }

    var capability: String {
        switch self {
        case .scopeProfile, .targetProfile, .referenceProfile:
            "studio.glifi.capability.corpus-profile.v1"
        case .keyness: "studio.glifi.capability.keyness.v1"
        case .association: "studio.glifi.capability.document-term-association.v1"
        case .similarity: "studio.glifi.capability.group-similarity.v1"
        case .groupMetric: "studio.glifi.capability.group-location-comparison.v1"
        }
    }
}
