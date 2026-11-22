// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Il planner produce un piano canonico con dipendenze e rationale completi")
func plannerProducesCanonicalExplainablePlan() throws {
    let first = try planningSource("00000000-0000-0000-0000-000000000001", .plainText, 100)
    let second = try planningSource("00000000-0000-0000-0000-000000000002", .markdown, 200)
    let request = try GlifiAnalysisPlanRequest(
        intent: .reviewCompletely,
        targetSourceRevisionIDs: [first.sourceRevisionID],
        referenceSourceRevisionIDs: [second.sourceRevisionID]
    )
    let planner = GlifiAnalysisPlanner()
    #expect(GlifiAnalysisPlanner.capabilities.count == 9)
    #expect(GlifiAnalysisPlanner.capabilities[0].minimumSourceCount == 1)
    #expect(GlifiAnalysisPlanner.capabilities[1].minimumSourceCount == 2)
    #expect(
        GlifiAnalysisPlanner.capabilities[1].dependencyCapabilityIdentifiers == [
            GlifiAnalysisPlanner.corpusProfileCapabilityIdentifier
        ])
    #expect(
        GlifiAnalysisPlanner.capabilities.allSatisfy {
            $0.fallbackBackendIdentifiers.isEmpty
        })
    let firstPlan = try planner.plan(
        request: request,
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [second, first]
    )
    let repeatedPlan = try planner.plan(
        request: request,
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [first, second]
    )

    #expect(firstPlan == repeatedPlan)
    #expect(firstPlan.plannerIdentifier == "planner-v2")
    #expect(firstPlan.capabilityCatalogIdentifier == "capability-catalog-v2")
    #expect(firstPlan.status == .readyWithCaveats)
    #expect(firstPlan.collectionProfile.sourceCount == 2)
    #expect(firstPlan.collectionProfile.totalSourceByteCount == 300)
    #expect(
        firstPlan.collectionProfile.formatCounts.map(\.formatIdentifier) == [
            "markdown", "plainText",
        ])
    // I passi MVP restano i primi quattro, identici a planner-mvp-v1 (ADR-0025).
    #expect(firstPlan.steps.prefix(4).map(\.order) == [0, 1, 2, 3])
    #expect(firstPlan.steps.prefix(4).map(\.role) == [.scope, .target, .reference, .comparison])
    #expect(
        firstPlan.steps[3].dependencyStepIdentifiers == [
            "plan-step.corpus-profile.target.v1",
            "plan-step.corpus-profile.reference.v1",
        ])
    // MVP: 1 412 unità. Capability estese, profilo delle due fonti (428) più il costo per
    // fonte dichiarato: associazione 940, collocazioni 1 452, rete 2 476, CA 1 452,
    // similarità 684, confronto di gruppo 4 524; il clustering richiede tre fonti.
    #expect(firstPlan.steps.prefix(4).reduce(0) { $0 + $1.estimatedWorkUnits } == 1_412)
    #expect(firstPlan.totalEstimatedWorkUnits == 12_940)
    #expect(firstPlan.decisions.prefix(2).map(\.isIncluded) == [true, true])
    #expect(firstPlan.decisions[1].applicability == .conditional)
    #expect(
        firstPlan.decisions[1].caveatIdentifiers == [
            "planner.nonempty-token-populations-required"
        ])
    #expect(
        firstPlan.decisions.dropFirst(2).map(\.isIncluded) == [
            true, true, true, true, false, true, true,
        ])
    #expect(firstPlan.decisions[6].reasonIdentifiers == ["planner.insufficient-sources"])
    #expect(
        firstPlan.steps.dropFirst(4).map(\.operation) == [
            .analyzeAssociation, .analyzeWindowCollocations, .analyzeWindowNetwork,
            .analyzeCorrespondence, .compareSimilarity, .compareGroupMetric,
        ])
    #expect(firstPlan.steps.dropFirst(4).allSatisfy { $0.dependencyStepIdentifiers.isEmpty })
    #expect(
        try JSONDecoder().decode(
            GlifiAnalysisPlan.self,
            from: JSONEncoder().encode(firstPlan)
        ) == firstPlan
    )
}

@Test("Il planner distingue precondizioni, capability assenti e rinvio per budget")
func plannerExplainsNonExecutableRequests() throws {
    let first = try planningSource("00000000-0000-0000-0000-000000000001", .plainText, 100)
    let planner = GlifiAnalysisPlanner()

    let empty = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .understandCollection),
        sourceRootDigest: digest("0"),
        configuredLanguageCode: "it",
        sources: []
    )
    #expect(empty.status == .notExecutable)
    #expect(empty.decisions.first?.reasonIdentifiers == ["planner.empty-scope"])

    let missingGroups = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .compareObjects),
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [first]
    )
    #expect(missingGroups.status == .notExecutable)
    #expect(missingGroups.decisions.last?.applicability == .notApplicable)
    #expect(
        missingGroups.decisions.last?.reasonIdentifiers == [
            "planner.comparison-groups-required"
        ])

    // trace.change richiede metadati temporali: nessuna capability del catalogo v2.
    let unsupported = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .traceChange),
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [first]
    )
    #expect(unsupported.status == .notExecutable)
    #expect(
        unsupported.unresolvedReasonIdentifiers == [
            "planner.no-capability-for-intent"
        ])
    // identify.themes con una fonte: la rete a finestra è pianificabile (ADR-0025), mentre CA
    // e clustering sono esclusi con motivo esplicito.
    let themes = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .identifyThemes),
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [first]
    )
    #expect(themes.status == .readyWithCaveats)
    #expect(themes.steps.map(\.operation) == [.analyzeWindowNetwork])
    #expect(
        themes.decisions.filter { $0.reasonIdentifiers == ["planner.insufficient-sources"] }
            .count == 2)

    let deferred = try planner.plan(
        request: GlifiAnalysisPlanRequest(
            intent: .understandCollection,
            maximumEstimatedWorkUnits: 0
        ),
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [first]
    )
    #expect(deferred.status == .notExecutable)
    #expect(deferred.decisions.first?.applicability == .deferred)
    #expect(deferred.decisions.first?.estimatedWorkUnits == 164)

    let ready = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .understandCollection),
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "it",
        sources: [first]
    )
    #expect(ready.status == .ready)
    #expect(ready.unresolvedReasonIdentifiers.isEmpty)

    let unsupportedLanguage = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .understandCollection),
        sourceRootDigest: digest("a"),
        configuredLanguageCode: "en",
        sources: [first]
    )
    #expect(unsupportedLanguage.status == .notExecutable)
    #expect(unsupportedLanguage.decisions.first?.applicability == .unavailable)
    #expect(
        unsupportedLanguage.unresolvedReasonIdentifiers == [
            "planner.linguistic-profile-unavailable"
        ])

    let oversized = try planningSource(
        "00000000-0000-0000-0000-000000000002",
        .plainText,
        GlifiCorpusAnalysisOptions.standard.maximumSourceByteCount + 1
    )
    let executionLimited = try planner.plan(
        request: GlifiAnalysisPlanRequest(intent: .understandCollection),
        sourceRootDigest: digest("b"),
        configuredLanguageCode: "it",
        sources: [oversized]
    )
    #expect(executionLimited.status == .notExecutable)
    #expect(executionLimited.decisions.first?.applicability == .deferred)
    #expect(
        executionLimited.unresolvedReasonIdentifiers == [
            "planner.execution-limit-exceeded"
        ])
}

@Test("Il piano viene persistito e riusato dopo la riapertura")
func projectPersistsAndReusesAnalysisPlan() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiAnalysisPlannerTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let packageURL = root.appending(path: "Piano.glifi", directoryHint: .isDirectory)
    let project = try GlifiProjectPackage.create(at: packageURL)
    let first = try GlifiTextImporter().importText(
        from: Data("casa mare".utf8),
        format: .plainText,
        sourceRevisionID: try revision("00000000-0000-0000-0000-000000000001")
    )
    let second = try GlifiTextImporter().importText(
        from: Data("casa città".utf8),
        format: .plainText,
        sourceRevisionID: try revision("00000000-0000-0000-0000-000000000002")
    )
    _ = try await project.importText(first)
    _ = try await project.importText(second)
    let request = try GlifiAnalysisPlanRequest(
        intent: .compareObjects,
        targetSourceRevisionIDs: [first.sourceRevisionID],
        referenceSourceRevisionIDs: [second.sourceRevisionID]
    )
    let engine = GlifiEngine()
    let planned = try await engine.planAnalysis(in: project, request: request)

    #expect(planned.sourceGeneration == 2)
    #expect(planned.generation == 3)
    // compare.objects: tre passi MVP più similarità e confronto di gruppo (ADR-0025).
    #expect(planned.plan.steps.count == 5)
    #expect(await project.snapshot().artifacts.count == 1)
    let data = try await project.artifactData(for: planned.artifactID)
    let payload = try JSONDecoder().decode(GlifiAnalysisPlanArtifactPayload.self, from: data)
    #expect(payload.analysisNodeID == planned.analysisNodeID)
    #expect(payload.plan == planned.plan)

    let repeated = try await engine.planAnalysis(in: project, request: request)
    #expect(repeated.sourceGeneration == 3)
    #expect(repeated.generation == 3)
    #expect(repeated.artifactID == planned.artifactID)

    let reopened = try GlifiProjectPackage.open(at: packageURL)
    let reopenedResult = try await GlifiEngine().planAnalysis(in: reopened, request: request)
    #expect(reopenedResult.generation == 3)
    #expect(reopenedResult.artifactID == planned.artifactID)
    #expect(await reopened.snapshot().artifacts.count == 1)
}

@Test("Il planner rifiuta riferimenti ignoti o fuori scope senza modificare il piano")
func plannerRejectsInvalidReferences() throws {
    let first = try planningSource("00000000-0000-0000-0000-000000000001", .plainText, 100)
    let secondID = try revision("00000000-0000-0000-0000-000000000002")
    let request = try GlifiAnalysisPlanRequest(
        intent: .compareObjects,
        scopeSourceRevisionIDs: [first.sourceRevisionID],
        targetSourceRevisionIDs: [first.sourceRevisionID],
        referenceSourceRevisionIDs: [secondID]
    )
    do {
        _ = try GlifiAnalysisPlanner().plan(
            request: request,
            sourceRootDigest: digest("a"),
            configuredLanguageCode: "it",
            sources: [first, try planningSource(secondID, .plainText, 100)]
        )
        Issue.record("Era atteso un gruppo fuori scope")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "planner.group-outside-scope")
        #expect(failure.operation == .plan)
    }
}

private func planningSource(
    _ uuid: String,
    _ format: GlifiTextFormat,
    _ byteCount: Int
) throws -> GlifiPlanningSource {
    try planningSource(revision(uuid), format, byteCount)
}

private func planningSource(
    _ id: SourceRevisionID,
    _ format: GlifiTextFormat,
    _ byteCount: Int
) throws -> GlifiPlanningSource {
    try GlifiPlanningSource(sourceRevisionID: id, format: format, byteCount: byteCount)
}

private func revision(_ value: String) throws -> SourceRevisionID {
    SourceRevisionID(uuid: try #require(UUID(uuidString: value)))
}

private func digest(_ character: Character) -> String {
    "sha256:" + String(repeating: character, count: 64)
}
