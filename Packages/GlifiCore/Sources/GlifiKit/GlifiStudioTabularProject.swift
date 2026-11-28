// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Original dataset bytes and mapping, retained independently from the derived text sources.
public struct GlifiStudioTabularSource: Codable, Sendable {
    /// Content identity of the immutable original-dataset artifact.
    public let artifactID: String
    /// Exact original CSV or XLSX bytes, never regenerated from extracted text.
    public let data: Data
    /// Resolved options, mapping, row data and original cell addresses.
    public let dataset: GlifiStudioTabularMappedDataset
}

/// A committed import; every row and its typed variables become reachable together.
public struct GlifiStudioTabularImportResult: Codable, Sendable {
    /// Derived text revisions, in the original mapped row order.
    public let sourceRevisionIDs: [String]
    /// Number of rows incorporated in the committed generation.
    public let importedCount: Int
    /// Content identity of the original container and complete mapping.
    public let originalArtifactID: String
    /// Every explicitly skipped row, identified without diagnostic source content.
    public let issues: [GlifiStudioTabularIssue]
}

private struct TabularSourcePayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.artifact.tabular-source.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let data: Data
    let dataset: GlifiStudioTabularMappedDataset
}

extension GlifiStudioProjectSession {
    /// Rechecks parsing and mapping before one atomic source/metadata commit.
    public func importTabular(
        data: Data, options: GlifiStudioTabularOptions, mapping: GlifiStudioTabularMapping
    ) async throws -> GlifiStudioTabularImportResult {
        try await performOperation(.importText) {
            let table = try await GlifiStudioTabularImporter.preview(data: data, options: options)
            let dataset = try await GlifiStudioTabularImporter.map(table: table, mapping: mapping)
            var state = try await researchState()
            let expectedRevision = state.revision
            guard !dataset.records.isEmpty else {
                throw savedResearchFailure("research.empty-dataset")
            }
            var fieldIDs: [String: String] = [:]
            for variable in mapping.variables {
                let fieldType: GlifiStudioResearchFieldType
                switch variable.type {
                case .text: fieldType = .text
                case .integer, .decimal: fieldType = .number
                case .boolean: fieldType = .boolean
                case .date: fieldType = .date
                }
                if let field = state.fields.first(where: { $0.label == variable.name }) {
                    guard field.type == fieldType else {
                        throw savedResearchFailure("research.incompatible-variable")
                    }
                    fieldIDs[variable.name] = field.id
                } else {
                    let id = tabularFieldID(variable.name)
                    guard !state.fields.contains(where: { $0.id == id }) else {
                        throw savedResearchFailure("research.incompatible-variable")
                    }
                    state.fields.append(.init(id: id, label: variable.name, type: fieldType))
                    fieldIDs[variable.name] = id
                }
            }
            let projectIdentity = try await snapshot().projectID
            let importIdentity =
                researchContentDigest(try CommandJSON.encode(mapping))
                + researchContentDigest(try CommandJSON.encode(options))
            var knownIDs = Set(state.records.compactMap(\.externalID))
            var imported: [GlifiImportedText] = []
            var issues = dataset.issues
            for row in dataset.records {
                try Task.checkCancellation()
                var externalID =
                    mapping.identifierColumn == nil
                    ? "dataset:\(dataset.sourceDigest)|\(table.selectedSheet ?? "csv")|\(row.identifier)"
                    : row.identifier
                if knownIDs.contains(externalID) {
                    switch mapping.duplicatePolicy {
                    case .reject: throw savedResearchFailure("research.duplicate-identifier")
                    case .skip:
                        issues.append(
                            GlifiStudioTabularIssue(
                                rowNumber: row.rowNumber, code: "duplicate-existing-identifier"))
                        continue
                    case .appendRowNumber:
                        let stem = "\(externalID)-\(row.rowNumber)"
                        externalID = stem
                        var suffix = 1
                        while knownIDs.contains(externalID) {
                            suffix += 1
                            externalID = "\(stem)-\(suffix)"
                        }
                    }
                }
                knownIDs.insert(externalID)
                let text = try GlifiTextImporter().importText(
                    from: Data(row.text.utf8), format: .plainText,
                    sourceRevisionID: try deterministicTabularRevision(
                        "\(projectIdentity)|\(dataset.sourceDigest)|\(importIdentity)|\(row.rowNumber)|\(externalID)"
                    ))
                var values: [String: GlifiStudioResearchValue] = [:]
                for (name, id) in fieldIDs {
                    guard let value = row.variables[name] else {
                        values[id] = .missing
                        continue
                    }
                    switch value {
                    case let .text(value): values[id] = .text(value)
                    case let .integer(value):
                        guard let exact = Double(exactly: value) else {
                            throw savedResearchFailure("research.integer-precision")
                        }
                        values[id] = .number(exact)
                    case let .decimal(value): values[id] = .number(value)
                    case let .boolean(value): values[id] = .boolean(value)
                    case let .date(value): values[id] = .date(value)
                    }
                }
                var origins: [String: GlifiStudioResearchCellOrigin] = [:]
                for (name, origin) in row.origins {
                    let field: String?
                    if name == "identifier" {
                        field = "$id"
                    } else if name.hasPrefix("text:") {
                        field = name == "text:\(mapping.textColumns.first ?? 0)" ? "$text" : nil
                    } else if name.hasPrefix("variable:") {
                        field = fieldIDs[String(name.dropFirst(9))]
                    } else {
                        field = nil
                    }
                    if let field {
                        origins[field] = GlifiStudioResearchCellOrigin(
                            inputDigest: origin.sourceDigest, sheet: origin.sheet,
                            row: origin.row, column: origin.column)
                    }
                }
                state.records.append(
                    GlifiStudioResearchRecord(
                        sourceRevisionID: text.sourceRevisionID.canonicalValue, values: values,
                        externalID: externalID, origins: origins))
                imported.append(text)
            }
            guard !imported.isEmpty else {
                throw savedResearchFailure("research.empty-dataset")
            }
            // Validate all rows and definitions before retaining even the original container.
            let before = await project.snapshot()
            try state.validate(
                sourceRevisionIDs: Set(
                    before.sources.map { $0.sourceRevisionID.canonicalValue }
                        + imported.map { $0.sourceRevisionID.canonicalValue }))
            let attachment = try await tabularOriginalAttachment(data: data, dataset: dataset)
            let originalID = try ArtifactID(digest: researchContentDigest(attachment.data))
                .canonicalValue
            _ = try await project.saveImportedResearchState(
                state.core(), expectedRevision: expectedRevision, importedTexts: imported,
                attachments: [attachment])
            return GlifiStudioTabularImportResult(
                sourceRevisionIDs: imported.map { $0.sourceRevisionID.canonicalValue },
                importedCount: imported.count, originalArtifactID: originalID, issues: issues)
        }
    }

    /// Returns the original bytes and every text-column interval after digest verification.
    public func tabularSource(artifactID: String) async throws -> GlifiStudioTabularSource {
        try await performOperation(.analyze) {
            let id = try ArtifactID(canonicalValue: artifactID)
            let snapshot = await project.snapshot()
            guard let record = snapshot.artifacts.first(where: { $0.artifactID == id }),
                record.node.descriptor.outputSchemaIdentifier
                    == TabularSourcePayload.outputSchemaIdentifier
            else { throw savedResearchFailure("research.invalid-tabular-source") }
            let bytes = try await project.artifactData(for: id)
            let payload = try JSONDecoder().decode(TabularSourcePayload.self, from: bytes)
            guard payload.schemaIdentifier == TabularSourcePayload.outputSchemaIdentifier,
                payload.schemaVersion == 1, payload.analysisNodeID == record.node.id,
                researchContentDigest(payload.data) == payload.dataset.sourceDigest
            else { throw savedResearchFailure("research.invalid-tabular-source") }
            return GlifiStudioTabularSource(
                artifactID: artifactID, data: payload.data, dataset: payload.dataset)
        }
    }

    private func tabularOriginalAttachment(
        data: Data, dataset: GlifiStudioTabularMappedDataset
    ) async throws -> GlifiProjectArtifactAttachment {
        let snapshot = await project.snapshot()
        let settings = try CommandJSON.encode(dataset.mapping)
        let options = try CommandJSON.encode(dataset.options)
        let descriptor = try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.tabular-source",
            algorithmIdentifier: "tabular-capture-v1", algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: snapshot.corpusVersionDigest(for: []),
            selectionIdentifier: "external-authorized-dataset",
            analyticalUnitIdentifier: "original-cells",
            preprocessingIdentifiers: [], linguisticProfileIdentifiers: [],
            representationIdentifier: "original-bytes-and-explicit-mapping-v1",
            resolvedParameters: [
                "inputDigest": .text(dataset.sourceDigest),
                "mappingDigest": .text(researchContentDigest(settings)),
                "optionsDigest": .text(researchContentDigest(options)),
            ],
            seedPolicyIdentifier: "no-randomness", backendIdentifier: "studio.glifi.native",
            numericPolicyIdentifier: "explicit-cell-types-v1", determinismClass: .d0,
            outputSchemaIdentifier: TabularSourcePayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0", dependencies: [], sourceRevisionIDs: [])
        let nodeID = try descriptor.nodeID()
        return try GlifiProjectArtifactAttachment(
            payload: TabularSourcePayload(
                schemaIdentifier: TabularSourcePayload.outputSchemaIdentifier, schemaVersion: 1,
                analysisNodeID: nodeID, data: data, dataset: dataset), descriptor: descriptor)
    }
}

private func tabularFieldID(_ name: String) -> String {
    let normalized = name.precomposedStringWithCanonicalMapping.lowercased()
    if (1...64).contains(normalized.utf8.count),
        normalized.utf8.allSatisfy({
            (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 || $0 == 95
        })
    {
        return normalized
    }
    return "column-" + researchContentDigest(Data(name.utf8)).dropFirst(7).prefix(24)
}

private func deterministicTabularRevision(_ identity: String) throws -> SourceRevisionID {
    let hex = String(researchContentDigest(Data(identity.utf8)).dropFirst(7).prefix(32))
    let chars = Array(hex)
    let uuidText =
        String(chars[0..<8]) + "-" + String(chars[8..<12]) + "-"
        + String(chars[12..<16]) + "-" + String(chars[16..<20]) + "-" + String(chars[20..<32])
    guard let uuid = UUID(uuidString: uuidText) else {
        throw savedResearchFailure("research.invalid-tabular-source")
    }
    return SourceRevisionID(uuid: uuid)
}
