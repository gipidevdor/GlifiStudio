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

    /// Verifies payload integrity and agreement of the manifest, view and equivalent table.
    ///
    /// This checks internal consistency, not the authenticity of the declared source project.
    public static func verify(_ files: [String: Data]) throws -> GlifiStudioVisualExportManifest {
        guard let data = files[manifestFileName],
            let manifest = try? JSONDecoder().decode(
                GlifiStudioVisualExportManifest.self, from: data),
            manifest.schema == GlifiStudioVisualExportManifest.schema,
            manifest.schemaVersion == GlifiStudioVisualExportManifest.schemaVersion,
            Set(files.keys) == Set([manifestFileName, "view-spec.json", "view.csv"]),
            manifest.files.map(\.path) == ["view-spec.json", "view.csv"],
            manifest.files[0].mediaType == "application/json",
            manifest.files[1].mediaType == "text/csv",
            validMetadata(manifest),
            manifest.files.allSatisfy({ record in
                files[record.path].map {
                    record.byteCount >= 0 && $0.count == record.byteCount
                        && digest($0) == record.sha256
                } ?? false
            }),
            let specificationData = files["view-spec.json"],
            let visualization = try? JSONDecoder().decode(
                GlifiStudioVisualization.self, from: specificationData),
            validStructure(visualization),
            manifest.artifactID == visualization.artifactID,
            manifest.analysisNodeID == visualization.analysisNodeID,
            manifest.analysisIdentifier == visualization.analysisIdentifier,
            manifest.methodIdentifier == visualization.methodIdentifier,
            manifest.specificationIdentifier == visualization.specificationIdentifier,
            manifest.totalObservationCount == visualization.totalObservationCount,
            manifest.visibleObservationCount == visualization.visibleObservationCount,
            manifest.reductionIdentifier == visualization.reductionIdentifier,
            manifest.layoutIdentifier == visualization.layoutIdentifier,
            manifest.caveatKeys == visualization.caveatKeys,
            files["view.csv"] == Data(GlifiStudioVisualizationBuilder.csv(visualization).utf8)
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

    private static func validMetadata(_ manifest: GlifiStudioVisualExportManifest) -> Bool {
        [
            manifest.softwareIdentifier, manifest.projectID, manifest.artifactID,
            manifest.analysisNodeID, manifest.analysisIdentifier, manifest.methodIdentifier,
            manifest.specificationIdentifier,
        ].allSatisfy(nonblank)
            && manifest.generation >= 0
            && manifest.totalObservationCount >= 0
            && manifest.visibleObservationCount >= 0
            && manifest.visibleObservationCount <= manifest.totalObservationCount
            && (manifest.reductionIdentifier.map(nonblank) ?? true)
            && (manifest.layoutIdentifier.map(nonblank) ?? true)
            && manifest.caveatKeys.allSatisfy(nonblank)
            && validCreationTime(manifest.createdAt)
    }

    private static func validStructure(_ view: GlifiStudioVisualization) -> Bool {
        guard nonblank(view.titleKey), nonblank(view.summaryKey),
            uniqueNonblank(view.table.columns.map(\.identifier)),
            uniqueNonblank(view.table.rows.map(\.id)),
            uniqueNonblank(view.marks.map(\.id)),
            uniqueNonblank(view.axes.map(\.fieldIdentifier)),
            view.table.rows.allSatisfy({
                $0.cells.count == view.table.columns.count && $0.cells.allSatisfy(finiteCell)
            }),
            view.axes.allSatisfy({
                $0.lowerBound.isFinite && $0.upperBound.isFinite && $0.lowerBound <= $0.upperBound
                    && ($0.share.map(\.isFinite) ?? true)
            }),
            view.marks.allSatisfy({
                $0.x.isFinite && $0.y.isFinite && ($0.x2.map(\.isFinite) ?? true)
                    && ($0.y2.map(\.isFinite) ?? true) && ($0.magnitude.map(\.isFinite) ?? true)
                    && $0.sourceRevisionIDs.allSatisfy(nonblank)
            }),
            view.summaryArguments.allSatisfy({ finiteCell($0.value) })
        else { return false }
        // Counts refer to family-specific observations, not necessarily rows or marks.
        return true
    }

    private static func finiteCell(_ cell: GlifiStudioVisualCell) -> Bool {
        switch cell {
        case let .decimal(value): value.isFinite
        case .text, .integer, .missing: true
        }
    }

    private static func nonblank(_ value: String) -> Bool {
        value.unicodeScalars.contains { !CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    private static func uniqueNonblank(_ values: [String]) -> Bool {
        values.allSatisfy(nonblank) && Set(values).count == values.count
    }

    /// Accepts the producer's UTC calendar profile, also with fractions or a zero offset.
    private static func validCreationTime(_ value: String) -> Bool {
        let utf8 = value.utf8
        let count = utf8.count
        let tail = Array(utf8.suffix(6))
        let end: Int
        let zoneLength: Int
        if tail.last == 90 || tail.last == 122 {
            zoneLength = 1
        } else if tail.elementsEqual("+00:00".utf8) {
            zoneLength = 6
        } else {
            return false
        }
        end = count - zoneLength
        let head = Array(utf8.prefix(20))
        guard end >= 19,
            head[4] == 45, head[7] == 45, head[10] == 84 || head[10] == 116,
            head[13] == 58, head[16] == 58
        else { return false }
        for index in 0..<19 where ![4, 7, 10, 13, 16].contains(index) {
            guard (48...57).contains(head[index]) else { return false }
        }
        if end > 19 {
            guard end > 20, head[19] == 46,
                utf8.dropFirst(20).dropLast(zoneLength).allSatisfy({ (48...57).contains($0) })
            else { return false }
        }
        // The calendar parser sees a fixed twenty bytes, independent of fractional precision.
        var calendarBytes = Array(head.prefix(19))
        calendarBytes[10] = 84
        calendarBytes.append(90)
        let calendarTime = String(decoding: calendarBytes, as: UTF8.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: calendarTime) else { return false }
        return formatter.string(from: date) == calendarTime
    }

    private static let hexadecimalDigits = Array("0123456789abcdef".utf8)

    static func digest(_ data: Data) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(71)
        bytes.append(contentsOf: "sha256:".utf8)
        for byte in SHA256.hash(data: data) {
            bytes.append(hexadecimalDigits[Int(byte >> 4)])
            bytes.append(hexadecimalDigits[Int(byte & 15)])
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func canonicalJSON(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return try encoder.encode(value) + Data("\n".utf8)
    }
}
