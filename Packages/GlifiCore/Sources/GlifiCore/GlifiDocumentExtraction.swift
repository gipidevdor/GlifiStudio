// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A normalized image region with a bottom-left origin, captured with an OCR observation.
package struct GlifiDocumentRegion: Codable, Equatable, Sendable {
    package let x: Double
    package let y: Double
    package let width: Double
    package let height: Double

    package init(x: Double, y: Double, width: Double, height: Double) throws {
        guard [x, y, width, height].allSatisfy(\.isFinite),
            x >= 0, y >= 0, width > 0, height > 0,
            x + width <= 1.000_000_001, y + height <= 1.000_000_001
        else { throw documentImportFailure("document.invalid-region") }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    private enum CodingKeys: String, CodingKey { case x, y, width, height }

    package init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            x: c.decode(Double.self, forKey: .x), y: c.decode(Double.self, forKey: .y),
            width: c.decode(Double.self, forKey: .width),
            height: c.decode(Double.self, forKey: .height))
    }
}

/// A location in the captured UTF-8 representation, never in compressed or PDF bytes.
package struct GlifiDocumentTextLocation: Codable, Equatable, Sendable {
    package let range: GlifiUTF8Range
    package let pageNumber: Int?
    package let resourcePath: String?
    package let method: String
    package let region: GlifiDocumentRegion?
    package let confidence: Double?

    package init(
        range: GlifiUTF8Range, pageNumber: Int? = nil, resourcePath: String? = nil,
        method: String, region: GlifiDocumentRegion? = nil, confidence: Double? = nil
    ) throws {
        let isPage = pageNumber != nil && resourcePath == nil
        let isResource = pageNumber == nil && resourcePath != nil
        guard isPage || isResource,
            pageNumber.map({ (1...2_048).contains($0) }) ?? true,
            resourcePath.map({
                !$0.isEmpty && $0.utf8.count <= 4_096 && !$0.hasPrefix("/")
                    && !$0.contains("\\") && !$0.contains("\0")
                    && !$0.split(separator: "/", omittingEmptySubsequences: false)
                        .contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
            }) ?? true,
            (isPage && (method == "pdf-text" || method == "pdf-ocr"))
                || (isResource && method == "epub-xhtml")
        else { throw documentImportFailure("document.invalid-location") }
        guard confidence.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
            method != "pdf-ocr" || (region != nil && confidence != nil)
        else { throw documentImportFailure("document.invalid-location") }
        self.range = range
        self.pageNumber = pageNumber
        self.resourcePath = resourcePath
        self.method = method
        self.region = region
        self.confidence = confidence
    }

    private enum CodingKeys: String, CodingKey {
        case range, pageNumber, resourcePath, method, region, confidence
    }

    package init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            range: c.decode(GlifiUTF8Range.self, forKey: .range),
            pageNumber: c.decodeIfPresent(Int.self, forKey: .pageNumber),
            resourcePath: c.decodeIfPresent(String.self, forKey: .resourcePath),
            method: c.decode(String.self, forKey: .method),
            region: c.decodeIfPresent(GlifiDocumentRegion.self, forKey: .region),
            confidence: c.decodeIfPresent(Double.self, forKey: .confidence))
    }
}

/// An immutable extraction snapshot whose backend is recorded rather than rerun on reopen.
package struct GlifiDocumentExtraction: Codable, Equatable, Sendable {
    package let text: String
    package let locations: [GlifiDocumentTextLocation]
    package let contractIdentifier: String
    package let backendIdentifier: String
    package let metadata: [String: String]

    package init(
        text: String, locations: [GlifiDocumentTextLocation], contractIdentifier: String,
        backendIdentifier: String, metadata: [String: String] = [:]
    ) throws {
        guard text.utf8.count <= 16 * 1_024 * 1_024, locations.count <= 100_000,
            !contractIdentifier.isEmpty, contractIdentifier.utf8.count <= 256,
            !backendIdentifier.isEmpty, backendIdentifier.utf8.count <= 1_024,
            metadata.count <= 32,
            metadata.allSatisfy({
                !$0.key.isEmpty && $0.key.utf8.count <= 256 && $0.value.utf8.count <= 4_096
            })
        else { throw documentImportFailure("document.invalid-extraction") }
        let utf8 = Array(text.utf8)
        guard let unitText = metadata["documentUnitCount"], let unitCount = Int(unitText),
            String(unitCount) == unitText, (0...2_048).contains(unitCount),
            locations.allSatisfy({ ($0.pageNumber ?? 0) <= unitCount }),
            Set(locations.compactMap(\.resourcePath)).count <= unitCount
        else { throw documentImportFailure("document.invalid-unit-count") }
        var previousEnd = 0
        for location in locations {
            guard location.range.start >= previousEnd, location.range.start >= 0,
                location.range.end > location.range.start,
                location.range.end <= utf8.count,
                utf8[location.range.start] & 0xC0 != 0x80,
                location.range.end == utf8.count || utf8[location.range.end] & 0xC0 != 0x80
            else { throw documentImportFailure("document.invalid-location") }
            previousEnd = location.range.end
        }
        guard text.isEmpty == locations.isEmpty else {
            throw documentImportFailure("document.invalid-extraction")
        }
        self.text = text
        self.locations = locations
        self.contractIdentifier = contractIdentifier
        self.backendIdentifier = backendIdentifier
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey {
        case text, locations, contractIdentifier, backendIdentifier, metadata
    }

    package init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            text: c.decode(String.self, forKey: .text),
            locations: c.decode([GlifiDocumentTextLocation].self, forKey: .locations),
            contractIdentifier: c.decode(String.self, forKey: .contractIdentifier),
            backendIdentifier: c.decode(String.self, forKey: .backendIdentifier),
            metadata: c.decode([String: String].self, forKey: .metadata))
    }
}

func documentImportFailure(
    _ code: String, category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .importText,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.category.\(category.rawValue)")
}
