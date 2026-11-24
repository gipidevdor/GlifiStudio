// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// A normalized OCR region in the captured page image, with a bottom-left origin.
public struct GlifiStudioDocumentRegion: Encodable, Equatable, Sendable {
    /// Horizontal origin in the unit interval.
    public let x: Double
    /// Vertical origin in the unit interval.
    public let y: Double
    /// Width as a fraction of the page image.
    public let width: Double
    /// Height as a fraction of the page image.
    public let height: Double

    init(_ value: GlifiDocumentRegion) {
        x = value.x
        y = value.y
        width = value.width
        height = value.height
    }
}

/// Links a UTF-8 interval of captured text to a PDF page or EPUB resource.
public struct GlifiStudioDocumentTextLocation: Encodable, Equatable, Sendable {
    /// Inclusive UTF-8 offset in the captured source text.
    public let start: Int
    /// Exclusive UTF-8 offset in the captured source text.
    public let end: Int
    /// One-based PDF page, when applicable.
    public let pageNumber: Int?
    /// Relative EPUB chapter resource, when applicable.
    public let resourcePath: String?
    /// Distinguishes embedded PDF text, OCR and XHTML extraction.
    public let method: String
    /// Normalized OCR region, when applicable.
    public let region: GlifiStudioDocumentRegion?
    /// Confidence of the captured OCR observation, when applicable.
    public let confidence: Double?

    init(_ value: GlifiDocumentTextLocation) {
        start = value.range.start
        end = value.range.end
        pageNumber = value.pageNumber
        resourcePath = value.resourcePath
        method = value.method
        region = value.region.map(GlifiStudioDocumentRegion.init)
        confidence = value.confidence
    }
}

/// Immutable import provenance shared by native clients and the CLI source-text command.
public struct GlifiStudioDocumentProvenance: Encodable, Equatable, Sendable {
    /// Format of the incorporated original file.
    public let format: GlifiStudioTextFormat
    /// Exact byte count of the incorporated original file.
    public let originalByteCount: Int
    /// Digest of the incorporated original bytes.
    public let originalContentDigest: String
    /// Versioned extraction contract captured at import.
    public let extractionContractIdentifier: String
    /// System backend identity captured at import, retained after an OS upgrade.
    public let backendIdentifier: String
    /// Bounded original document and extraction metadata.
    public let metadata: [String: String]
    /// Locations in the captured source-text coordinate system.
    public let locations: [GlifiStudioDocumentTextLocation]

    init(imported: GlifiImportedText, extraction: GlifiDocumentExtraction) {
        format = GlifiStudioTextFormat(imported.format)
        originalByteCount = imported.bytes.count
        originalContentDigest = imported.contentDigest
        extractionContractIdentifier = extraction.contractIdentifier
        backendIdentifier = extraction.backendIdentifier
        metadata = extraction.metadata
        locations = extraction.locations.map(GlifiStudioDocumentTextLocation.init)
    }
}
