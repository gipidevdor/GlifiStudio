// SPDX-License-Identifier: BSD-3-Clause

import Foundation

extension GlifiEngine {
    /// Links an archived output to an ordinary investigation without inventing a scientific claim.
    public func createSavedAnalysisInvestigation(
        in project: GlifiProjectPackage, artifactID: ArtifactID, question: String
    ) async throws -> GlifiProjectInvestigationResult {
        try Task.checkCancellation()
        // Validate the question before creating even a review-plan artifact.
        _ = try GlifiInvestigationCreationRequest(
            question: question, languageCode: "it", interpretationArtifactID: artifactID)
        let snapshot = await project.snapshot()
        guard let record = snapshot.artifacts.first(where: { $0.artifactID == artifactID }),
            record.node.descriptor.outputSchemaIdentifier
                == GlifiSavedResearchAnalysis.outputSchemaIdentifier
        else { throw savedResearchFailure("research.invalid-saved-analysis") }
        let bytes = try await project.artifactData(for: artifactID)
        let saved = try JSONDecoder().decode(GlifiSavedResearchAnalysis.self, from: bytes)
        try saved.validate()
        let ids = try saved.sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
        guard !ids.isEmpty, saved.analysisNodeID == record.node.id,
            record.node.descriptor.sourceRevisionIDs
                == ids.sorted(by: { $0.canonicalValue < $1.canonicalValue }),
            zip(ids, saved.sourceContentDigests).allSatisfy({ id, digest in
                snapshot.sources.contains {
                    $0.sourceRevisionID == id && $0.contentDigest == digest
                }
            })
        else { throw savedResearchFailure("research.capture-sources-required") }
        let existingHeads = try await investigationHeads(in: project)
        if let existing = existingHeads.first(where: { head in
            head.question == question
                && snapshot.artifacts.contains(where: {
                    $0.artifactID == head.interpretationArtifactID
                        && $0.node.descriptor.algorithmIdentifier == "saved-analysis-capture-v1"
                        && $0.node.descriptor.resolvedParameters["savedArtifactID"]
                            == .text(artifactID.canonicalValue)
                })
        }) {
            return GlifiProjectInvestigationResult(
                projectID: snapshot.projectID, generation: snapshot.generation,
                investigation: existing)
        }
        var references: [GlifiSourceReference] = []
        for id in ids.sorted(by: { $0.canonicalValue < $1.canonicalValue }) {
            let imported = try await project.importedText(for: id)
            let text = imported.text
            references.append(
                GlifiSourceReference(
                    sourceRevisionID: id, roleIdentifier: "declared-captured-input",
                    representationIdentifier: "extracted-utf8-v1", regionIdentifier: "whole-source",
                    ranges: [try GlifiUTF8Range(start: 0, end: text.utf8.count)]))
        }
        let planned = try await planAnalysis(
            in: project,
            request: GlifiAnalysisPlanRequest(
                intent: .understandCollection, scopeSourceRevisionIDs: ids))
        let current = await project.snapshot()
        guard
            let planRecord = current.artifacts.first(where: { $0.artifactID == planned.artifactID })
        else {
            throw savedResearchFailure("research.capture-plan-missing")
        }
        let interpretation = try GlifiInterpretationEngine.describeSavedResearchCapture(
            planArtifactID: planned.artifactID, planAnalysisNodeID: planned.analysisNodeID,
            savedRecord: record, saved: saved, sourceReferences: references)
        let dependencies = try [planRecord, record].map {
            try GlifiAnalysisDependency(
                nodeID: $0.node.id, artifactDigest: $0.contentDigest,
                outputSchemaIdentifier: $0.node.descriptor.outputSchemaIdentifier)
        }
        let descriptor = try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.interpretation",
            algorithmIdentifier: "saved-analysis-capture-v1", algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: snapshot.corpusVersionDigest(for: ids),
            selectionIdentifier: "declared-captured-inputs-v1",
            analyticalUnitIdentifier: "archived-output",
            preprocessingIdentifiers: record.node.descriptor.preprocessingIdentifiers,
            linguisticProfileIdentifiers: ["it"],
            representationIdentifier: "captured-output-review-not-plan-execution-v1",
            resolvedParameters: ["savedArtifactID": .text(artifactID.canonicalValue)],
            seedPolicyIdentifier: "no-randomness", backendIdentifier: "studio.glifi.native",
            numericPolicyIdentifier: "descriptive-capture-only-v1", determinismClass: .d0,
            outputSchemaIdentifier: GlifiAnalysisInterpretationArtifactPayload
                .outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0", dependencies: dependencies,
            sourceRevisionIDs: ids)
        let node = try descriptor.nodeID()
        let committed: GlifiProjectSnapshot
        if current.artifacts.contains(where: { $0.node.id == node }) {
            committed = current
        } else {
            committed = try await project.storeArtifact(
                GlifiAnalysisInterpretationArtifactPayload(
                    analysisNodeID: node, interpretation: interpretation),
                descriptor: descriptor)
        }
        guard let output = committed.artifacts.first(where: { $0.node.id == node }) else {
            throw savedResearchFailure("research.capture-interpretation-missing")
        }
        let heads = try await investigationHeads(in: project)
        if let existing = heads.first(where: {
            $0.question == question.precomposedStringWithCanonicalMapping
                && $0.interpretationArtifactID == output.artifactID
        }) {
            return GlifiProjectInvestigationResult(
                projectID: committed.projectID, generation: committed.generation,
                investigation: existing)
        }
        return try await createInvestigation(
            in: project,
            request: GlifiInvestigationCreationRequest(
                question: question, languageCode: "it", interpretationArtifactID: output.artifactID)
        )
    }
}
