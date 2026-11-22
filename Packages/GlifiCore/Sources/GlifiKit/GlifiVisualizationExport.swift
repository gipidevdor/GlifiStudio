// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// One payload file of a view export.
public struct GlifiStudioVisualExportFile: Codable, Equatable, Sendable {
    /// Path inside the export folder.
    public let path: String
    /// Media type.
    public let mediaType: String
    /// Exact size in bytes.
    public let byteCount: Int
    /// `sha256:` digest of the bytes.
    public let sha256: String
}

/// Provenance manifest of a view export (GS-VIZ-001 § Export).
public struct GlifiStudioVisualExportManifest: Codable, Equatable, Sendable {
    /// Stable schema.
    public static let schema = "studio.glifi.visual-export-manifest"
    /// Current schema version.
    public static let schemaVersion = 1
    /// Engine build recorded by every analytical descriptor.
    public static let softwareIdentifier = "GlifiCore-0.1.0"

    /// Schema encoded in the manifest.
    public let schema: String
    /// Schema version encoded in the manifest.
    public let schemaVersion: Int
    /// RFC 3339 UTC creation time, excluded from the scientific identity.
    public let createdAt: String
    /// Engine build.
    public let softwareIdentifier: String
    /// Project owning the Artifact.
    public let projectID: String
    /// Generation that contains the Artifact.
    public let generation: Int
    /// Source Artifact.
    public let artifactID: String
    /// Producer node.
    public let analysisNodeID: String
    /// Analysis bundle.
    public let analysisIdentifier: String
    /// Method identity.
    public let methodIdentifier: String
    /// Versioned view specification.
    public let specificationIdentifier: String
    /// Observations in the Artifact.
    public let totalObservationCount: Int
    /// Observations represented by the view.
    public let visibleObservationCount: Int
    /// Declared reduction, when the view shows a subset.
    public let reductionIdentifier: String?
    /// Declared layout, when positions are not data.
    public let layoutIdentifier: String?
    /// Caveats that change the reading of the view.
    public let caveatKeys: [String]
    /// Payload files in path order, excluding this manifest.
    public let files: [GlifiStudioVisualExportFile]
}

/// Result of a completed view export.
public struct GlifiStudioVisualExportReceipt: Codable, Equatable, Sendable {
    /// `sha256:` digest of the manifest bytes.
    public let manifestDigest: String
    /// Files written, manifest included.
    public let fileCount: Int
}

/// Deterministic construction and verified writing of view exports.
public enum GlifiStudioVisualExport {
    /// Manifest file name.
    public static let manifestFileName = "visual-export-manifest.json"

    /// Files of the export: equivalent table, specification and manifest.
    ///
    /// Every byte except `createdAt` depends only on the view and its lineage.
    public static func bundle(
        _ visualization: GlifiStudioVisualization,
        projectID: String,
        generation: Int,
        createdAt: Date
    ) throws -> [String: Data] {
        let payloads: [(String, String, Data)] = [
            ("view.csv", "text/csv", Data(GlifiStudioVisualizationBuilder.csv(visualization).utf8)),
            ("view-spec.json", "application/json", try canonicalJSON(visualization)),
        ]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        let manifest = GlifiStudioVisualExportManifest(
            schema: GlifiStudioVisualExportManifest.schema,
            schemaVersion: GlifiStudioVisualExportManifest.schemaVersion,
            createdAt: formatter.string(from: createdAt),
            softwareIdentifier: GlifiStudioVisualExportManifest.softwareIdentifier,
            projectID: projectID,
            generation: generation,
            artifactID: visualization.artifactID,
            analysisNodeID: visualization.analysisNodeID,
            analysisIdentifier: visualization.analysisIdentifier,
            methodIdentifier: visualization.methodIdentifier,
            specificationIdentifier: visualization.specificationIdentifier,
            totalObservationCount: visualization.totalObservationCount,
            visibleObservationCount: visualization.visibleObservationCount,
            reductionIdentifier: visualization.reductionIdentifier,
            layoutIdentifier: visualization.layoutIdentifier,
            caveatKeys: visualization.caveatKeys,
            files: payloads.map { path, mediaType, data in
                GlifiStudioVisualExportFile(
                    path: path, mediaType: mediaType, byteCount: data.count,
                    sha256: digest(data))
            }.sorted { $0.path < $1.path }
        )
        var files = Dictionary(uniqueKeysWithValues: payloads.map { ($0.0, $0.2) })
        files[manifestFileName] = try canonicalJSON(manifest)
        return files
    }

    /// Verifies every file of a bundle against its manifest.
    public static func verify(_ files: [String: Data]) throws -> GlifiStudioVisualExportManifest {
        guard let data = files[manifestFileName],
            let manifest = try? JSONDecoder().decode(
                GlifiStudioVisualExportManifest.self, from: data),
            manifest.schema == GlifiStudioVisualExportManifest.schema,
            manifest.schemaVersion == GlifiStudioVisualExportManifest.schemaVersion,
            Set(files.keys) == Set(manifest.files.map(\.path) + [manifestFileName]),
            manifest.files.allSatisfy({ record in
                files[record.path].map {
                    $0.count == record.byteCount && digest($0) == record.sha256
                } ?? false
            })
        else {
            throw GlifiStudioFailure(
                code: "visual-export.integrity-failed",
                category: GlifiFailureCategory.corruption.rawValue,
                operation: GlifiOperationKind.export.rawValue,
                retryDisposition: GlifiRetryDisposition.never.rawValue,
                retainedState: GlifiRetainedState.readOnlyRecovery.rawValue,
                messageKey: "failure.visual-export.integrity-failed"
            )
        }
        return manifest
    }

    static func digest(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func canonicalJSON(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return try encoder.encode(value) + Data("\n".utf8)
    }
}
