// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Test-only process-termination hooks for proving the `.glifi` commit protocol.
///
/// This surface is SPI: production clients must not import it. The dedicated
/// SwiftPM recovery harness is the only repository target allowed to call it.
@_spi(RecoveryTesting)
public enum GlifiProjectRecoveryTesting {
    /// Stable checkpoint names accepted by the recovery harness.
    public static var checkpoints: [String] {
        GlifiProjectCommitInterruption.allCases.map(\.rawValue)
    }

    /// Stable checkpoint names accepted by the recovery harness for export.
    public static var exportCheckpoints: [String] {
        GlifiExportInterruption.allCases.map(\.rawValue)
    }

    /// Commits the deterministic recovery-test source without terminating.
    public static func commitImport(at packageURL: URL) async throws -> GlifiProjectSnapshot {
        let project = try GlifiProjectPackage.open(at: packageURL)
        return try await project.importText(
            importedText(),
            sourceID: recoverySourceID
        )
    }

    /// Invokes a non-returning harness action at one import commit checkpoint.
    public static func runInterruptedImport(
        at packageURL: URL,
        checkpoint: String,
        action: @escaping @Sendable () -> Never
    ) async throws -> Never {
        let interruption = try validatedCheckpoint(checkpoint)
        let project = try GlifiProjectPackage.open(at: packageURL)
        _ = try await project.importText(
            importedText(),
            sourceID: recoverySourceID,
            interruption: interruption,
            interruptionBehavior: .invoke(action)
        )
        preconditionFailure("Il checkpoint di recovery non ha terminato il processo")
    }

    /// Commits the deterministic recovery-test artifact without terminating.
    public static func commitArtifact(at packageURL: URL) async throws -> GlifiProjectSnapshot {
        let project = try GlifiProjectPackage.open(at: packageURL)
        let descriptor = try await recoveryArtifactDescriptor(for: project)
        return try await project.storeArtifact(
            GlifiRecoveryArtifactPayload(value: "recovery-probe-v1"),
            descriptor: descriptor
        )
    }

    /// Invokes a non-returning harness action at one Artifact commit checkpoint.
    public static func runInterruptedArtifactCommit(
        at packageURL: URL,
        checkpoint: String,
        action: @escaping @Sendable () -> Never
    ) async throws -> Never {
        let interruption = try validatedCheckpoint(checkpoint)
        let project = try GlifiProjectPackage.open(at: packageURL)
        let descriptor = try await recoveryArtifactDescriptor(for: project)
        _ = try await project.storeArtifact(
            GlifiRecoveryArtifactPayload(value: "recovery-probe-v1"),
            descriptor: descriptor,
            interruption: interruption,
            interruptionBehavior: .invoke(action)
        )
        preconditionFailure("Il checkpoint di recovery non ha terminato il processo")
    }

    /// Commits the deterministic recovery-test qualitative event without terminating.
    public static func commitQualitative(at packageURL: URL) async throws -> GlifiProjectSnapshot {
        let project = try GlifiProjectPackage.open(at: packageURL)
        return try await project.appendQualitativeEvent(try recoveryQualitativeEvent())
    }

    /// Invokes a non-returning harness action at one qualitative commit checkpoint.
    public static func runInterruptedQualitativeCommit(
        at packageURL: URL,
        checkpoint: String,
        action: @escaping @Sendable () -> Never
    ) async throws -> Never {
        let interruption = try validatedCheckpoint(checkpoint)
        let project = try GlifiProjectPackage.open(at: packageURL)
        _ = try await project.appendQualitativeEvent(
            try recoveryQualitativeEvent(),
            interruption: interruption,
            interruptionBehavior: .invoke(action)
        )
        preconditionFailure("Il checkpoint di recovery non ha terminato il processo")
    }

    private static func recoveryQualitativeEvent() throws -> GlifiQualitativeEvent {
        try GlifiQualitativeEvent(
            predecessorEventID: nil,
            recordedAtUnixMilliseconds: 0,
            payload: .codebookRevised(
                codebookID: "recovery",
                revision: 1,
                categories: [
                    GlifiCodebookCategory(
                        categoryID: "probe", label: "Probe", definition: "Recovery probe.")
                ]
            )
        )
    }

    /// Commits the deterministic recovery-test export without terminating.
    public static func commitExport(
        at packageURL: URL,
        to destinationURL: URL
    ) async throws -> GlifiExportReceipt {
        let project = try GlifiProjectPackage.open(at: packageURL)
        let fixture = try await exportRecoveryFixture(for: project)
        return try GlifiScientificExporter().export(
            snapshot: fixture.snapshot,
            investigation: fixture.investigation,
            interpretationRecord: fixture.interpretationRecord,
            interpretation: fixture.interpretation,
            request: try GlifiScientificExportRequest(
                investigationHeadEventID: fixture.investigation.headEventID,
                formats: [.json]
            ),
            to: destinationURL
        )
    }

    /// Invokes a non-returning harness action at one export commit checkpoint.
    public static func runInterruptedExport(
        at packageURL: URL,
        to destinationURL: URL,
        checkpoint: String,
        action: @escaping @Sendable () -> Never
    ) async throws -> Never {
        let interruption = try validatedExportCheckpoint(checkpoint)
        let project = try GlifiProjectPackage.open(at: packageURL)
        let fixture = try await exportRecoveryFixture(for: project)
        _ = try GlifiScientificExporter().export(
            snapshot: fixture.snapshot,
            investigation: fixture.investigation,
            interpretationRecord: fixture.interpretationRecord,
            interpretation: fixture.interpretation,
            request: try GlifiScientificExportRequest(
                investigationHeadEventID: fixture.investigation.headEventID,
                formats: [.json]
            ),
            to: destinationURL,
            interruption: interruption,
            interruptionBehavior: .invoke(action)
        )
        preconditionFailure("Il checkpoint di recovery dell'export non ha terminato il processo")
    }

    /// Reports the observable state of an export destination without decoding
    /// its content: absent, invalid, or committed with its verified file count.
    ///
    /// Kept as a plain `String` because `GlifiScientificExporter` is not public
    /// and the harness lives in a separate module.
    public static func inspectExport(at destinationURL: URL) -> String {
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            return "absent"
        }
        guard let manifest = try? GlifiScientificExporter.verifyExport(at: destinationURL) else {
            return "invalid"
        }
        return "committed files=\(manifest.files.count)"
    }

    private static var recoverySourceID: SourceID {
        guard let uuid = UUID(uuidString: "20000000-0000-0000-0000-000000000072") else {
            preconditionFailure("UUID fixture non valido")
        }
        return SourceID(uuid: uuid)
    }

    private static func importedText() throws -> GlifiImportedText {
        guard let uuid = UUID(uuidString: "30000000-0000-0000-0000-000000000072") else {
            preconditionFailure("UUID fixture non valido")
        }
        let revisionID = SourceRevisionID(uuid: uuid)
        return try GlifiTextImporter().importText(
            from: Data("Commit recovery verificabile.".utf8),
            format: .plainText,
            sourceRevisionID: revisionID
        )
    }

    private static func recoveryArtifactDescriptor(
        for project: GlifiProjectPackage
    ) async throws -> GlifiAnalysisDescriptor {
        let snapshot = await project.snapshot()
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "artifact.recovery-probe",
            algorithmIdentifier: "algorithm.recovery-probe",
            algorithmVersion: "1",
            corpusIdentifier: "project-source-root-v1",
            corpusVersionDigest: snapshot.sourceRootDigest,
            selectionIdentifier: "selection.all.v1",
            analyticalUnitIdentifier: "source-revision.v1",
            preprocessingIdentifiers: [],
            linguisticProfileIdentifiers: [],
            representationIdentifier: "representation.recovery-probe.v1",
            resolvedParameters: ["resolved": .boolean(true)],
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            determinismClass: .d0,
            outputSchemaIdentifier: GlifiRecoveryArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1",
            dependencies: []
        )
    }

    private static func validatedCheckpoint(
        _ checkpoint: String
    ) throws -> GlifiProjectCommitInterruption {
        guard let interruption = GlifiProjectCommitInterruption(rawValue: checkpoint) else {
            throw GlifiFailure(
                code: "test.invalid-recovery-checkpoint",
                category: .invalidInput,
                operation: .persistProject,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.test.invalid-recovery-checkpoint"
            )
        }
        return interruption
    }

    private static func validatedExportCheckpoint(
        _ checkpoint: String
    ) throws -> GlifiExportInterruption {
        guard let interruption = GlifiExportInterruption(rawValue: checkpoint) else {
            throw GlifiFailure(
                code: "test.invalid-recovery-checkpoint",
                category: .invalidInput,
                operation: .export,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.test.invalid-recovery-checkpoint"
            )
        }
        return interruption
    }

    private static func exportRecoveryFixture(
        for project: GlifiProjectPackage
    ) async throws -> GlifiRecoveryExportFixture {
        let imported = try GlifiTextImporter().importText(
            from: Data("Commit recovery dell'export verificabile.".utf8),
            format: .plainText
        )
        _ = try await project.importText(imported)
        let engine = GlifiEngine()
        let execution = try await engine.executeAnalysisPlan(
            in: project,
            request: GlifiAnalysisPlanRequest(intent: .understandCollection)
        )
        let created = try await engine.createInvestigation(
            in: project,
            request: try GlifiInvestigationCreationRequest(
                question: "# corpus: quali caratteristiche emergono?",
                interpretationArtifactID: execution.interpretationArtifactID
            )
        )
        let snapshot = await project.snapshot()
        guard
            let record = snapshot.artifacts.first(where: {
                $0.artifactID == execution.interpretationArtifactID
            })
        else {
            throw GlifiFailure(
                code: "test.missing-recovery-artifact",
                category: .insufficientData,
                operation: .export,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.test.missing-recovery-artifact"
            )
        }
        let payload = try JSONDecoder().decode(
            GlifiAnalysisInterpretationArtifactPayload.self,
            from: try await project.artifactData(for: record.artifactID)
        )
        return GlifiRecoveryExportFixture(
            snapshot: snapshot,
            investigation: created.investigation,
            interpretationRecord: record,
            interpretation: payload.interpretation
        )
    }
}

private struct GlifiRecoveryExportFixture {
    let snapshot: GlifiProjectSnapshot
    let investigation: GlifiInvestigation
    let interpretationRecord: GlifiProjectArtifactRecord
    let interpretation: GlifiAnalysisInterpretation
}

private struct GlifiRecoveryArtifactPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.recovery-probe.v1"

    let value: String
}
