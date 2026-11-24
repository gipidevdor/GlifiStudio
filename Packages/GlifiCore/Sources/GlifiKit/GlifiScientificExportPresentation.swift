// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Versioned machine request for exporting one investigation branch.
public struct GlifiStudioScientificExportRequest: Codable, Equatable, Sendable {
    /// Stable request schema.
    public static let schemaIdentifier = "studio.glifi.api.scientific-export-request"
    /// Current request schema version.
    public static let schemaVersion = 1

    /// Stable schema encoded in the request.
    public let schemaIdentifier: String
    /// Schema version encoded in the request.
    public let schemaVersion: Int
    /// Exact investigation branch to export.
    public let investigationHeadEventID: String
    /// Requested `csv`, `json`, `markdown`, and/or `pdf` payloads.
    public let formats: [String]
    /// Locale used only for the human-readable projection.
    public let presentationLocaleIdentifier: String
    /// Time-zone identifier used only for human presentation metadata.
    public let presentationTimeZoneIdentifier: String

    /// Creates a versioned export request without touching the destination.
    public init(
        investigationHeadEventID: String,
        formats: [String] = ["json", "markdown"],
        presentationLocaleIdentifier: String = "it-IT",
        presentationTimeZoneIdentifier: String = "Europe/Rome"
    ) {
        schemaIdentifier = Self.schemaIdentifier
        schemaVersion = Self.schemaVersion
        self.investigationHeadEventID = investigationHeadEventID
        self.formats = formats
        self.presentationLocaleIdentifier = presentationLocaleIdentifier
        self.presentationTimeZoneIdentifier = presentationTimeZoneIdentifier
    }

    func coreValue() throws -> GlifiScientificExportRequest {
        guard schemaIdentifier == Self.schemaIdentifier, schemaVersion == Self.schemaVersion else {
            throw presentationFailure("export.request-schema-unsupported")
        }
        let resolvedFormats = try formats.map { value in
            guard let format = GlifiScientificExportFormat(rawValue: value) else {
                throw presentationFailure("export.format-unsupported")
            }
            return format
        }
        return try GlifiScientificExportRequest(
            investigationHeadEventID: InvestigationEventID(
                canonicalValue: investigationHeadEventID
            ),
            formats: resolvedFormats,
            presentationLocaleIdentifier: presentationLocaleIdentifier,
            presentationTimeZoneIdentifier: presentationTimeZoneIdentifier
        )
    }
}

/// Presentation-safe receipt for a fully verified scientific export.
public struct GlifiStudioExportReceipt: Codable, Equatable, Sendable {
    /// Audit UUID shared with `export-manifest.json`.
    public let exportID: String
    /// Content identity of the exported report revision.
    public let reportRevisionID: String
    /// Digest of the exact canonical manifest bytes.
    public let manifestDigest: String
    /// Number of generated payload files.
    public let fileCount: Int

    init(_ value: GlifiExportReceipt) {
        exportID = value.exportID
        reportRevisionID = value.reportRevisionID.canonicalValue
        manifestDigest = value.manifestDigest
        fileCount = value.fileCount
    }
}
