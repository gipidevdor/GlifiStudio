// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Captured-output companions belong only to explicitly selected archival findings.
enum GlifiSavedResearchReport {
    static func fileName(artifactID: ArtifactID) -> String {
        "saved-analysis-\(artifactID.digest.dropFirst(7)).json"
    }

    static func isFileName(_ path: String) -> Bool {
        guard path.hasPrefix("saved-analysis-"), path.hasSuffix(".json") else { return false }
        let digest = path.dropFirst(15).dropLast(5)
        return digest.count == 64 && digest.allSatisfy { "0123456789abcdef".contains($0) }
    }

    static func selectedArtifactIDs(in report: GlifiReportRevision) -> Set<ArtifactID> {
        Set(
            report.evidence.filter { $0.kindIdentifier == "saved-analysis-capture" }.flatMap(
                \.artifactIDs))
    }

    static func payloads(
        report: GlifiReportRevision, captured: [ArtifactID: Data]
    ) throws -> [GlifiScientificExportPayload] {
        let selected = selectedArtifactIDs(in: report)
        guard Set(captured.keys) == selected else {
            throw savedResearchFailure("research.capture-export-input-mismatch")
        }
        var byteCount = 0
        for data in captured.values {
            guard data.count <= GlifiScientificExporter.maximumFileByteCount - byteCount else {
                throw GlifiFailure(
                    code: "export.captured-output-limit", category: .insufficientResources,
                    operation: .export, retryDisposition: .afterConditionsChange,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.export.captured-output-limit")
            }
            byteCount += data.count
        }
        return try selected.sorted { $0.canonicalValue < $1.canonicalValue }.map { artifactID in
            guard let data = captured[artifactID] else {
                throw savedResearchFailure("research.capture-export-input-mismatch")
            }
            _ = try verify(data: data, path: fileName(artifactID: artifactID))
            return GlifiScientificExportPayload(
                path: fileName(artifactID: artifactID), mediaType: "application/json",
                schema: GlifiSavedResearchAnalysis.outputSchemaIdentifier, data: data)
        }
    }

    static func verify(data: Data, path: String) throws -> ArtifactID {
        do {
            try Task.checkCancellation()
            guard isFileName(path), data.count <= GlifiScientificExporter.maximumFileByteCount
            else {
                throw captureExportFailure()
            }
            let payload = try JSONDecoder().decode(GlifiSavedResearchAnalysis.self, from: data)
            try payload.validate()
            let canonical = try GlifiArtifactCanonicalJSON.encode(payload)
            let digest =
                "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let artifactID = try ArtifactID(digest: digest)
            guard canonical == data, path == fileName(artifactID: artifactID) else {
                throw captureExportFailure()
            }
            return artifactID
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw captureExportFailure()
        }
    }

    static func findingText(_ finding: GlifiFinding, italian: Bool) -> String {
        guard finding.messageKey == "finding.saved-analysis.captured" else {
            return finding.messageKey
        }
        let method = finding.messageArguments["methodIdentifier"] ?? finding.objectIdentifier
        let count = finding.messageArguments["sourceCount"] ?? "—"
        return italian
            ? "Output del metodo \(method) acquisito con \(count) fonti dichiarate. Il risultato conservato è disponibile nell’allegato JSON."
            : "Output of \(method) captured with \(count) declared sources. The preserved result is available in the JSON attachment."
    }

    static func caveatText(_ caveat: GlifiCaveat, italian: Bool) -> String {
        switch caveat.identifier {
        case "saved-analysis.declared-source-association":
            return italian
                ? "Il collegamento alle fonti è dichiarato: verificare gli input nella richiesta acquisita."
                : "The source association is declared: review the inputs in the captured request."
        case "saved-analysis.no-method-validation":
            return italian
                ? "L’acquisizione conserva l’output e non certifica il metodo o una conclusione statistica."
                : "Capturing preserves the output and does not certify the method or a statistical conclusion."
        case "saved-analysis.separate-plan-execution":
            return italian
                ? "Il piano collega l’ambito dell’indagine; questa acquisizione non attesta l’esecuzione degli step del piano."
                : "The plan links the investigation scope; this capture does not attest execution of the plan steps."
        default: return caveat.identifier
        }
    }
}

private func captureExportFailure() -> GlifiFailure {
    GlifiFailure(
        code: "export.captured-output-mismatch", category: .corruption, operation: .export,
        retryDisposition: .never, retainedState: .lastCommittedGeneration,
        messageKey: "failure.export.captured-output-mismatch")
}
