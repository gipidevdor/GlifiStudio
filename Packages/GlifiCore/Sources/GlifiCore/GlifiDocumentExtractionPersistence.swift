// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Import-owned payload; source bytes and this captured representation share one generation.
struct GlifiDocumentExtractionArtifactPayload: GlifiAnalysisArtifactPayload, Equatable {
    static let outputSchemaIdentifier = "studio.glifi.artifact.document-extraction.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let sourceRevisionID: SourceRevisionID
    let sourceContentDigest: String
    let format: GlifiTextFormat
    let extraction: GlifiDocumentExtraction

    init(
        nodeID: AnalysisNodeID, source: GlifiProjectSourceRecord,
        extraction: GlifiDocumentExtraction
    ) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = 1
        analysisNodeID = nodeID
        sourceRevisionID = source.sourceRevisionID
        sourceContentDigest = source.contentDigest
        format = source.format
        self.extraction = extraction
    }
}

/// Canonical encoding and semantic verification, independent of the installed extraction backend.
package enum GlifiDocumentExtractionPersistence {
    static let artifactTypeIdentifier = "studio.glifi.artifact.document-extraction"
    static let algorithmIdentifier = "document-extraction-snapshot-v1"

    struct Prepared {
        let descriptor: GlifiAnalysisDescriptor
        let descriptorData: Data
        let data: Data
    }

    static func isRich(_ format: GlifiTextFormat) -> Bool {
        switch format {
        case .pdf, .epub: true
        case .plainText, .markdown: false
        }
    }

    static func isReserved(_ descriptor: GlifiAnalysisDescriptor) -> Bool {
        descriptor.outputSchemaIdentifier
            == GlifiDocumentExtractionArtifactPayload.outputSchemaIdentifier
            || descriptor.artifactTypeIdentifier == artifactTypeIdentifier
            || descriptor.algorithmIdentifier == algorithmIdentifier
    }

    static func prepare(
        _ imported: GlifiImportedText, source: GlifiProjectSourceRecord
    ) throws -> Prepared? {
        guard isRich(source.format) else {
            guard imported.documentExtraction == nil else { throw invalidSnapshot() }
            return nil
        }
        guard let extraction = imported.documentExtraction else { throw invalidSnapshot() }
        let restored = try GlifiTextImporter().restoreDocument(
            from: imported.bytes, format: source.format, extraction: extraction,
            sourceRevisionID: source.sourceRevisionID)
        guard restored == imported, restored.text.utf8.elementsEqual(imported.text.utf8) else {
            throw invalidSnapshot()
        }
        let descriptor = try descriptor(source: source, extraction: extraction)
        let payload = GlifiDocumentExtractionArtifactPayload(
            nodeID: try descriptor.nodeID(), source: source, extraction: extraction)
        let data = try GlifiArtifactCanonicalJSON.encode(payload)
        let descriptorData = try GlifiArtifactCanonicalJSON.encode(descriptor)
        guard data.count <= GlifiProjectPackage.maximumArtifactByteCount,
            descriptorData.count <= GlifiProjectPackage.maximumDescriptorByteCount
        else { throw resourceLimit() }
        return Prepared(descriptor: descriptor, descriptorData: descriptorData, data: data)
    }

    static func descriptor(
        source: GlifiProjectSourceRecord, extraction: GlifiDocumentExtraction
    ) throws -> GlifiAnalysisDescriptor {
        let extractionData = try GlifiArtifactCanonicalJSON.encode(extraction)
        guard extractionData.count <= GlifiProjectPackage.maximumArtifactByteCount else {
            throw resourceLimit()
        }
        guard let unitValue = extraction.metadata["documentUnitCount"],
            let unitCount = Int(unitValue), (0...2_048).contains(unitCount),
            String(unitCount) == unitValue
        else { throw invalidSnapshot() }
        let determinism: GlifiDeterminismClass
        switch source.format {
        case .pdf: determinism = .n1
        case .epub: determinism = .d0
        case .plainText, .markdown: throw invalidSnapshot()
        }
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: artifactTypeIdentifier,
            algorithmIdentifier: algorithmIdentifier, algorithmVersion: "1",
            corpusIdentifier: source.sourceRevisionID.canonicalValue,
            corpusVersionDigest: digest(try GlifiArtifactCanonicalJSON.encode([source])),
            selectionIdentifier: "source-revision-all-v1",
            analyticalUnitIdentifier: "document-text-location-v1",
            preprocessingIdentifiers: [extraction.contractIdentifier],
            linguisticProfileIdentifiers: [],
            representationIdentifier: "captured-document-utf8-v1",
            resolvedParameters: [
                "format": .text(source.format.rawValue),
                "sourceContentDigest": .text(source.contentDigest),
                "extractionDigest": .text(digest(extractionData)),
                "canonicalByteCount": .integer(Int64(extraction.text.utf8.count)),
                "documentUnitCount": .integer(Int64(unitCount)),
                "backendMetadata": .object(extraction.metadata.mapValues { .text($0) }),
            ],
            seedPolicyIdentifier: "none-v1", backendIdentifier: extraction.backendIdentifier,
            numericPolicyIdentifier: "utf8-exact-captured-v1", determinismClass: determinism,
            outputSchemaIdentifier: GlifiDocumentExtractionArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-document-extraction-v1", dependencies: [],
            sourceRevisionIDs: [source.sourceRevisionID])
    }

    /// Validates one-to-one bindings before payload reads, including missing or ambiguous snapshots.
    static func bindings(
        sources: [GlifiProjectSourceRecord], artifacts: [GlifiProjectArtifactRecord]
    ) throws -> [SourceRevisionID: GlifiProjectArtifactRecord] {
        var sourceByID: [SourceRevisionID: GlifiProjectSourceRecord] = [:]
        for source in sources {
            guard sourceByID.updateValue(source, forKey: source.sourceRevisionID) == nil else {
                throw invalidSnapshot()
            }
        }
        var result: [SourceRevisionID: GlifiProjectArtifactRecord] = [:]
        for artifact in artifacts where isReserved(artifact.node.descriptor) {
            try Task.checkCancellation()
            let descriptor = artifact.node.descriptor
            guard
                descriptor.outputSchemaIdentifier
                    == GlifiDocumentExtractionArtifactPayload.outputSchemaIdentifier,
                descriptor.artifactTypeIdentifier == artifactTypeIdentifier,
                descriptor.algorithmIdentifier == algorithmIdentifier,
                descriptor.algorithmVersion == "1", descriptor.dependencies.isEmpty,
                let revisions = descriptor.sourceRevisionIDs, revisions.count == 1,
                let revision = revisions.first, let source = sourceByID[revision],
                isRich(source.format),
                result.updateValue(artifact, forKey: revision) == nil
            else { throw invalidSnapshot() }
        }
        for source in sources where isRich(source.format) {
            guard result[source.sourceRevisionID] != nil else { throw invalidSnapshot() }
        }
        return result
    }

    /// Admits a persisted representation without decoding its potentially large text payload.
    package static func admissionByteCount(
        for source: GlifiProjectSourceRecord, artifacts: [GlifiProjectArtifactRecord]
    ) throws -> Int {
        guard source.byteCount >= 0 else { throw invalidSnapshot() }
        guard isRich(source.format) else { return source.byteCount }
        let record = try artifact(for: source, artifacts: artifacts)
        return max(source.byteCount, try canonicalByteCount(record))
    }

    /// Indexes only exact candidates, then preserves the single-record validation order.
    static func admissionByteCounts(
        for sources: [GlifiProjectSourceRecord], artifacts: [GlifiProjectArtifactRecord]
    ) throws -> [Int] {
        guard sources.count > 1 else {
            return try sources.map { try admissionByteCount(for: $0, artifacts: artifacts) }
        }
        let revisions = Set(
            sources.lazy.filter { isRich($0.format) }.map(\.sourceRevisionID))
        guard !revisions.isEmpty else {
            return try sources.map { try admissionByteCount(for: $0, artifacts: []) }
        }
        var candidates: [SourceRevisionID: [GlifiProjectArtifactRecord]] = [:]
        for artifact in artifacts where isReserved(artifact.node.descriptor) {
            guard let declared = artifact.node.descriptor.sourceRevisionIDs,
                declared.count == 1, let revision = declared.first,
                revisions.contains(revision)
            else { continue }
            candidates[revision, default: []].append(artifact)
        }
        return try sources.map {
            try admissionByteCount(for: $0, artifacts: candidates[$0.sourceRevisionID] ?? [])
        }
    }

    static func artifact(
        for source: GlifiProjectSourceRecord, artifacts: [GlifiProjectArtifactRecord]
    ) throws -> GlifiProjectArtifactRecord {
        let candidates = artifacts.filter {
            isReserved($0.node.descriptor)
                && $0.node.descriptor.sourceRevisionIDs == [source.sourceRevisionID]
        }
        let matched = try bindings(sources: [source], artifacts: candidates)
        guard let result = matched[source.sourceRevisionID] else { throw invalidSnapshot() }
        return result
    }

    static func canonicalByteCount(_ artifact: GlifiProjectArtifactRecord) throws -> Int {
        guard let value = artifact.node.descriptor.resolvedParameters["canonicalByteCount"],
            case let .integer(count) = value,
            (0...16_777_216).contains(count)
        else { throw invalidSnapshot() }
        return Int(count)
    }

    static func admit(
        _ artifact: GlifiProjectArtifactRecord, limits: GlifiTextImportLimits
    ) throws {
        guard let value = artifact.node.descriptor.resolvedParameters["documentUnitCount"],
            case let .integer(units) = value,
            (0...2_048).contains(units)
        else { throw invalidSnapshot() }
        guard try canonicalByteCount(artifact) <= limits.maximumExtractedByteCount,
            units <= limits.maximumDocumentUnitCount
        else {
            throw documentImportFailure("document.resource-limit", category: .insufficientResources)
        }
    }

    static func decode(
        _ data: Data, source: GlifiProjectSourceRecord, artifact: GlifiProjectArtifactRecord
    ) throws -> GlifiDocumentExtraction {
        try Task.checkCancellation()
        guard data.count <= GlifiProjectPackage.maximumArtifactByteCount else {
            throw invalidSnapshot()
        }
        do {
            let payload = try JSONDecoder().decode(
                GlifiDocumentExtractionArtifactPayload.self, from: data)
            let validLocations: Bool
            switch source.format {
            case .pdf:
                validLocations = payload.extraction.locations.allSatisfy {
                    $0.pageNumber != nil && ($0.method == "pdf-text" || $0.method == "pdf-ocr")
                }
            case .epub:
                validLocations = payload.extraction.locations.allSatisfy {
                    $0.resourcePath != nil && $0.method == "epub-xhtml"
                }
            case .plainText, .markdown: validLocations = false
            }
            guard
                payload.schemaIdentifier
                    == GlifiDocumentExtractionArtifactPayload.outputSchemaIdentifier,
                payload.schemaVersion == 1, payload.analysisNodeID == artifact.node.id,
                payload.sourceRevisionID == source.sourceRevisionID,
                payload.sourceContentDigest == source.contentDigest,
                payload.format == source.format,
                validLocations,
                try descriptor(source: source, extraction: payload.extraction)
                    == artifact.node.descriptor,
                try GlifiArtifactCanonicalJSON.encode(payload) == data
            else { throw invalidSnapshot() }
            return payload.extraction
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw invalidSnapshot()
        }
    }

    static func invalidSnapshot() -> GlifiFailure {
        GlifiFailure(
            code: "project.document-extraction-invalid", category: .corruption,
            operation: .persistProject, retryDisposition: .never,
            retainedState: .lastCommittedGeneration,
            messageKey: "failure.project.document-extraction-invalid")
    }

    private static func resourceLimit() -> GlifiFailure {
        GlifiFailure(
            code: "project.artifact-too-large", category: .insufficientResources,
            operation: .persistProject, retryDisposition: .afterConditionsChange,
            retainedState: .unchanged, messageKey: "failure.project.artifact-too-large")
    }

    private static func digest(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
