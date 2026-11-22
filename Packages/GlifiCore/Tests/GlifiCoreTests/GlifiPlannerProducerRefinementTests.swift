// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("The budget-correct planner cannot collide with a producer-one cached plan")
func khRefinementPlannerProducerSeparatesLegacyCacheIdentity() throws {
    let first = SourceRevisionID()
    let second = SourceRevisionID()
    let sources = [
        try GlifiPlanningSource(sourceRevisionID: first, format: .plainText, byteCount: 100),
        try GlifiPlanningSource(sourceRevisionID: second, format: .markdown, byteCount: 200),
    ]
    let digest = "sha256:" + String(repeating: "a", count: 64)
    let generous = try GlifiAnalysisPlanner().plan(
        request: GlifiAnalysisPlanRequest(
            intent: .compareObjects, targetSourceRevisionIDs: [first],
            referenceSourceRevisionIDs: [second], maximumEstimatedWorkUnits: 1_668),
        sourceRootDigest: digest, configuredLanguageCode: "it", sources: sources)
    #expect(generous.totalEstimatedWorkUnits == 1_668)
    // Producer one emitted these same steps with a smaller request budget.
    // Recreate that immutable historical payload without invoking the old bug.
    var legacyFields = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(generous)) as? [String: Any])
    legacyFields["maximumEstimatedWorkUnits"] = 1_000
    let legacyPlan = try JSONDecoder().decode(
        GlifiAnalysisPlan.self, from: JSONSerialization.data(withJSONObject: legacyFields))
    let current = try GlifiAnalysisPlanner().plan(
        request: GlifiAnalysisPlanRequest(
            intent: .compareObjects, targetSourceRevisionIDs: [first],
            referenceSourceRevisionIDs: [second], maximumEstimatedWorkUnits: 1_000),
        sourceRootDigest: digest, configuredLanguageCode: "it", sources: sources)
    #expect(current.totalEstimatedWorkUnits == 984)
    let project = ProjectID()
    func descriptor(_ plan: GlifiAnalysisPlan) throws -> GlifiAnalysisDescriptor {
        try GlifiAnalysisArtifactDescriptorFactory.analysisPlan(
            projectID: project, sourceRootDigest: digest,
            tokenizationContractIdentifier: GlifiItalianTokenizer.contractIdentifier, plan: plan)
    }
    var oldFields = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(descriptor(legacyPlan)))
            as? [String: Any])
    oldFields["algorithmVersion"] = "1"
    let oldDescriptor = try JSONDecoder().decode(
        GlifiAnalysisDescriptor.self, from: JSONSerialization.data(withJSONObject: oldFields))
    let oldNode = try oldDescriptor.nodeID()
    let newDescriptor = try descriptor(current)
    #expect(try newDescriptor.nodeID() != oldNode)
    #expect(newDescriptor.outputSchemaIdentifier == oldDescriptor.outputSchemaIdentifier)
    #expect(newDescriptor.descriptorSchemaIdentifier == oldDescriptor.descriptorSchemaIdentifier)
    let payload = GlifiAnalysisPlanArtifactPayload(analysisNodeID: oldNode, plan: legacyPlan)
    let oldBytes = try GlifiArtifactCanonicalJSON.encode(payload)
    #expect(
        try JSONDecoder().decode(GlifiAnalysisPlanArtifactPayload.self, from: oldBytes) == payload)
    #expect(try GlifiArtifactCanonicalJSON.encode(payload) == oldBytes)
}
