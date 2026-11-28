// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Explicit types of user-owned corpus variables.
public enum GlifiResearchFieldType: String, Codable, CaseIterable, Sendable {
    /// Exact text, including a deliberately empty string.
    case text
    /// Finite IEEE-754 binary64 numeric observation.
    case number
    /// Explicit true or false observation.
    case boolean
    /// Gregorian civil date in canonical yyyy-MM-dd form.
    case date
}

/// A missing observation is distinct from an empty string, zero and false.
public enum GlifiResearchValue: Codable, Equatable, Sendable {
    /// Explicit absence, distinct from empty text, zero and false.
    case missing
    /// Exact text, including a deliberately empty string.
    case text(String)
    /// Finite IEEE-754 binary64 numeric observation.
    case number(Double)
    /// Explicit true or false observation.
    case boolean(Bool)
    /// Gregorian civil date in the canonical `yyyy-MM-dd` representation.
    case date(String)

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Kind: String, Codable { case missing, text, number, boolean, date }

    /// Decodes the explicit tagged wire representation, independent of enum ABI.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        switch try fields.decode(Kind.self, forKey: .type) {
        case .missing:
            guard !fields.contains(.value) else { throw researchFailure("research.invalid-value") }
            self = .missing
        case .text: self = .text(try fields.decode(String.self, forKey: .value))
        case .number: self = .number(try fields.decode(Double.self, forKey: .value))
        case .boolean: self = .boolean(try fields.decode(Bool.self, forKey: .value))
        case .date: self = .date(try fields.decode(String.self, forKey: .value))
        }
    }

    /// Writes an explicit tag and primitive JSON value; missing has no value member.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .missing: try fields.encode(Kind.missing, forKey: .type)
        case let .text(value):
            try fields.encode(Kind.text, forKey: .type)
            try fields.encode(value, forKey: .value)
        case let .number(value):
            try fields.encode(Kind.number, forKey: .type)
            try fields.encode(value == 0 ? 0 : value, forKey: .value)
        case let .boolean(value):
            try fields.encode(Kind.boolean, forKey: .type)
            try fields.encode(value, forKey: .value)
        case let .date(value):
            try fields.encode(Kind.date, forKey: .type)
            try fields.encode(value, forKey: .value)
        }
    }

    /// Text representation used by explicitly string-valued coding variables.
    public var codingValue: String? {
        switch self {
        case .missing: nil
        case let .text(value), let .date(value): value
        case let .number(value): String(value)
        case let .boolean(value): value ? "true" : "false"
        }
    }
}

/// The recorded creation procedure of a derived variable; row overrides remain independently traced.
public struct GlifiResearchFieldDerivation: Codable, Equatable, Sendable {
    /// Existing immutable output used to derive the variable.
    public var artifactID: String
    /// Explicit transformation applied to that output, distinct from the numerical method.
    public var operationIdentifier: String
    /// Complete resolved transformation parameters, including a hierarchical cut when applicable.
    public var parameters: [String: String]

    /// Captures a variable's creation procedure without rewriting the producing result.
    public init(artifactID: String, operationIdentifier: String, parameters: [String: String] = [:])
    {
        self.artifactID = artifactID
        self.operationIdentifier = operationIdentifier
        self.parameters = parameters
    }
}

/// A stable variable identity and its human-facing label.
public struct GlifiResearchField: Codable, Equatable, Sendable {
    /// Stable ASCII identity, independent of the displayed label.
    public var id: String
    /// Human-readable label of the field or reusable source selection.
    public var label: String
    /// Declared value type; missing observations remain distinct.
    public var type: GlifiResearchFieldType
    /// Original creation procedure; per-record edits can supersede individual observations.
    public var derivation: GlifiResearchFieldDerivation?

    /// Creates explicit research data for validation by the project writer.
    public init(
        id: String, label: String, type: GlifiResearchFieldType,
        derivation: GlifiResearchFieldDerivation? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.derivation = derivation
    }
}

/// Exact original cell of an imported observation; both ordinals are one-based.
public struct GlifiResearchCellOrigin: Codable, Equatable, Sendable {
    /// SHA-256 digest of the exact original tabular container.
    public var inputDigest: String
    /// Original worksheet identity, absent for CSV input.
    public var sheet: String?
    /// One-based original physical row, including header rows.
    public var row: Int
    /// One-based original column in the captured container.
    public var column: Int

    /// Creates explicit research data for validation by the project writer.
    public init(inputDigest: String, sheet: String? = nil, row: Int, column: Int) {
        self.inputDigest = inputDigest
        self.sheet = sheet
        self.row = row
        self.column = column
    }
}

/// Variables belong to an immutable source revision, never a displayed filename.
public struct GlifiResearchRecord: Codable, Equatable, Sendable {
    /// Immutable source revision that owns these observations.
    public var sourceRevisionID: String
    /// Typed observations keyed by stable field identity.
    public var values: [String: GlifiResearchValue]
    /// Original external row identifier, when explicitly supplied.
    public var externalID: String?
    /// Legacy producer identity, retained for earlier research records.
    public var derivationArtifactID: String?
    /// Per-field producer identities preserve independent derived-variable provenance.
    public var derivationArtifactIDs: [String: String]?
    /// Field identities, or `$text`/`$id`, identify the original cells.
    public var origins: [String: GlifiResearchCellOrigin]

    /// Creates explicit research data for validation by the project writer.
    public init(
        sourceRevisionID: String, values: [String: GlifiResearchValue], externalID: String? = nil,
        derivationArtifactID: String? = nil, origins: [String: GlifiResearchCellOrigin] = [:],
        derivationArtifactIDs: [String: String]? = nil
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.values = values
        self.externalID = externalID
        self.derivationArtifactID = derivationArtifactID
        self.derivationArtifactIDs = derivationArtifactIDs
        self.origins = origins
    }
}

/// An explicit, reusable source selection; source order is not semantic.
public struct GlifiResearchSubset: Codable, Equatable, Sendable {
    /// Stable ASCII identity, independent of the displayed label.
    public var id: String
    /// Human-readable label of the field or reusable source selection.
    public var label: String
    /// Explicit immutable source revisions belonging to the selection.
    public var sourceRevisionIDs: [String]

    /// Creates explicit research data for validation by the project writer.
    public init(id: String, label: String, sourceRevisionIDs: [String]) {
        self.id = id
        self.label = label
        self.sourceRevisionIDs = sourceRevisionIDs
    }
}

/// Authoritative, versioned research configuration stored as immutable project artifacts.
public struct GlifiResearchState: Codable, Equatable, Sendable {
    /// Monotonic research revision used for optimistic concurrency.
    public var revision: Int
    /// Stable field definitions and their explicitly selected types.
    public var fields: [GlifiResearchField]
    /// Per-source observations, identifiers and original-cell provenance.
    public var records: [GlifiResearchRecord]
    /// Named reusable selections of immutable source revisions.
    public var subsets: [GlifiResearchSubset]
    /// Shared Italian lexical configuration for corpus analysis.
    public var preparation: GlifiCorpusPreparation

    /// Creates explicit research data for validation by the project writer.
    public init(
        revision: Int = 0, fields: [GlifiResearchField] = [], records: [GlifiResearchRecord] = [],
        subsets: [GlifiResearchSubset] = [], preparation: GlifiCorpusPreparation = .init()
    ) {
        self.revision = revision
        self.fields = fields
        self.records = records
        self.subsets = subsets
        self.preparation = preparation
    }

    /// Validates types, bounds, canonical identities and all source references before use.
    public func validate(sourceRevisionIDs: Set<String>? = nil) throws {
        guard (0...10_000).contains(revision), fields.count <= 256,
            records.count <= 100_000, subsets.count <= 1_000,
            Set(fields.map(\.id)).count == fields.count,
            Set(records.map(\.sourceRevisionID)).count == records.count,
            Set(subsets.map(\.id)).count == subsets.count
        else { throw researchFailure("research.invalid-state") }
        try preparation.validate()
        let definitions = Dictionary(uniqueKeysWithValues: fields.map { ($0.id, $0.type) })
        for field in fields {
            guard researchIdentifier(field.id), researchText(field.label, maximum: 512) else {
                throw researchFailure("research.invalid-field")
            }
            if let derivation = field.derivation {
                _ = try ArtifactID(canonicalValue: derivation.artifactID)
                guard researchIdentifier(derivation.operationIdentifier),
                    derivation.parameters.count <= 64,
                    derivation.parameters.allSatisfy({
                        researchParameterKey($0.key) && $0.value.utf8.count <= 4_096
                    }),
                    derivation.parameters.reduce(
                        0, { $0 + $1.key.utf8.count + $1.value.utf8.count }) <= 65_536
                else { throw researchFailure("research.invalid-derivation") }
            }
        }
        var retainedBytes = fields.reduce(0) { count, field in
            let derivationBytes =
                field.derivation.map { derivation in
                    derivation.artifactID.utf8.count + derivation.operationIdentifier.utf8.count
                        + derivation.parameters.reduce(0) {
                            $0 + $1.key.utf8.count + $1.value.utf8.count + 32
                        }
                } ?? 0
            return count + field.id.utf8.count + field.label.utf8.count + derivationBytes
        }
        guard retainedBytes <= 16 * 1_024 * 1_024 else {
            throw researchFailure("research.state-too-large", category: .insufficientResources)
        }
        var retainedCells = 0
        for record in records {
            try Task.checkCancellation()
            _ = try SourceRevisionID(canonicalValue: record.sourceRevisionID)
            guard sourceRevisionIDs?.contains(record.sourceRevisionID) != false,
                record.values.count <= fields.count, record.origins.count <= fields.count + 2,
                record.externalID.map({ researchText($0, maximum: 4_096) }) != false
            else { throw researchFailure("research.invalid-record") }
            retainedCells += record.values.count
            retainedBytes +=
                record.sourceRevisionID.utf8.count
                + (record.externalID?.utf8.count ?? 0)
                + record.values.reduce(0) {
                    $0 + $1.key.utf8.count + ($1.value.codingValue?.utf8.count ?? 0) + 32
                }
            guard retainedCells <= 500_000, retainedBytes <= 16 * 1_024 * 1_024 else {
                throw researchFailure("research.state-too-large", category: .insufficientResources)
            }
            if let artifactID = record.derivationArtifactID {
                _ = try ArtifactID(canonicalValue: artifactID)
            }
            guard (record.derivationArtifactIDs?.count ?? 0) <= fields.count else {
                throw researchFailure("research.invalid-derivation")
            }
            for (fieldID, artifactID) in record.derivationArtifactIDs ?? [:] {
                guard definitions[fieldID] != nil, record.values[fieldID] != nil else {
                    throw researchFailure("research.invalid-derivation")
                }
                _ = try ArtifactID(canonicalValue: artifactID)
            }
            for (key, value) in record.values {
                guard let type = definitions[key] else {
                    throw researchFailure("research.unknown-field")
                }
                try validateResearchValue(value, type: type)
            }
            for (key, origin) in record.origins {
                guard definitions[key] != nil || key == "$text" || key == "$id",
                    isCanonicalSHA256Digest(origin.inputDigest), origin.row > 0,
                    origin.column > 0, origin.row <= 1_048_576, origin.column <= 16_384,
                    origin.sheet.map({ researchText($0, maximum: 512) }) != false
                else { throw researchFailure("research.invalid-cell-origin") }
                retainedBytes +=
                    key.utf8.count + origin.inputDigest.utf8.count
                    + (origin.sheet?.utf8.count ?? 0) + 64
                guard retainedBytes <= 16 * 1_024 * 1_024 else {
                    throw researchFailure(
                        "research.state-too-large", category: .insufficientResources)
                }
            }
        }
        var retainedSelections = 0
        for subset in subsets {
            retainedSelections += subset.sourceRevisionIDs.count
            guard researchIdentifier(subset.id), researchText(subset.label, maximum: 512),
                subset.sourceRevisionIDs.count <= 100_000,
                retainedSelections <= 200_000,
                Set(subset.sourceRevisionIDs).count == subset.sourceRevisionIDs.count
            else { throw researchFailure("research.invalid-subset") }
            for sourceID in subset.sourceRevisionIDs {
                _ = try SourceRevisionID(canonicalValue: sourceID)
                guard sourceRevisionIDs?.contains(sourceID) != false else {
                    throw researchFailure("research.unknown-source")
                }
                retainedBytes += sourceID.utf8.count + 4
                guard retainedBytes <= 16 * 1_024 * 1_024 else {
                    throw researchFailure(
                        "research.state-too-large", category: .insufficientResources)
                }
            }
        }
        guard try researchCanonicalData(self).count <= 16 * 1_024 * 1_024 else {
            throw researchFailure("research.state-too-large", category: .insufficientResources)
        }
    }

    /// Resolves available string coding variables while preserving missingness by omission.
    public func codingVariables(sourceRevisionID: String) -> [String: String] {
        guard let record = records.first(where: { $0.sourceRevisionID == sourceRevisionID }) else {
            return [:]
        }
        return record.values.compactMapValues(\.codingValue)
    }

    /// Decoding is an admission boundary; malformed states never reach a writer.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        revision = try fields.decode(Int.self, forKey: .revision)
        self.fields = try fields.decode([GlifiResearchField].self, forKey: .fields)
        records = try fields.decode([GlifiResearchRecord].self, forKey: .records)
        subsets = try fields.decode([GlifiResearchSubset].self, forKey: .subsets)
        preparation = try fields.decode(GlifiCorpusPreparation.self, forKey: .preparation)
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case revision, fields, records, subsets, preparation
    }
}

/// A conjunction of an optional reusable subset, typed field equality and a textual query.
public struct GlifiResearchFilter: Codable, Equatable, Sendable {
    /// Optional identity of a reusable source selection.
    public var subsetID: String?
    /// Optional stable identity of the field tested for equality.
    public var fieldID: String?
    /// Typed equality operand; supplied together with the field identity.
    public var value: GlifiResearchValue?
    /// Optional textual predicate combined with metadata and source selection.
    public var query: String?

    /// Creates explicit research data for validation by the project writer.
    public init(
        subsetID: String? = nil, fieldID: String? = nil, value: GlifiResearchValue? = nil,
        query: String? = nil
    ) {
        self.subsetID = subsetID
        self.fieldID = fieldID
        self.value = value
        self.query = query
    }

    /// Resolves metadata predicates only; the session intersects the query's exact source IDs.
    public func select(from state: GlifiResearchState, sourceRevisionIDs: [String]) throws
        -> [String]
    {
        try state.validate(sourceRevisionIDs: Set(sourceRevisionIDs))
        var selected = Set(sourceRevisionIDs)
        if let subsetID {
            guard let subset = state.subsets.first(where: { $0.id == subsetID }) else {
                throw researchFailure("research.unknown-subset")
            }
            selected.formIntersection(subset.sourceRevisionIDs)
        }
        guard (fieldID == nil) == (value == nil) else {
            throw researchFailure("research.incomplete-predicate")
        }
        if let fieldID, let value {
            guard let field = state.fields.first(where: { $0.id == fieldID }) else {
                throw researchFailure("research.unknown-field")
            }
            try validateResearchValue(value, type: field.type)
            let observations = Dictionary(
                uniqueKeysWithValues: state.records.map { ($0.sourceRevisionID, $0.values) })
            selected = selected.filter { (observations[$0]?[fieldID] ?? .missing) == value }
        }
        return sourceRevisionIDs.filter { selected.contains($0) }
    }
}

private struct GlifiResearchStateArtifact: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.artifact.research-state.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let previousArtifactID: String?
    let state: GlifiResearchState
}

extension GlifiProjectPackage {
    /// Reads the latest research revision after validating its complete descriptor chain.
    public func researchState() throws -> GlifiResearchState {
        let history = try researchHistory()
        guard let latest = history.last else { return GlifiResearchState() }
        let payload = try JSONDecoder().decode(
            GlifiResearchStateArtifact.self, from: artifactData(for: latest.artifactID))
        guard payload.schemaIdentifier == GlifiResearchStateArtifact.outputSchemaIdentifier,
            payload.schemaVersion == 1, payload.analysisNodeID == latest.node.id,
            payload.state.revision == history.count,
            payload.previousArtifactID == history.dropLast().last?.artifactID.canonicalValue,
            latest.node.descriptor.resolvedParameters["contentDigest"]
                == .text(try researchDigest(payload.state))
        else { throw researchFailure("research.invalid-history", category: .corruption) }
        try payload.state.validate(
            sourceRevisionIDs: Set(snapshot().sources.map { $0.sourceRevisionID.canonicalValue }))
        try validateResearchProducers(payload.state)
        try validateResearchOrigins(payload.state, importedTexts: [], attachments: [])
        return payload.state
    }

    /// Optimistic writes append immutable history; an import cannot invalidate configuration.
    @discardableResult
    public func saveResearchState(
        _ proposed: GlifiResearchState, expectedRevision: Int
    ) throws -> GlifiResearchState {
        try saveImportedResearchState(
            proposed, expectedRevision: expectedRevision, importedTexts: [])
    }

    /// Incorporates mapped table rows and their variables in the same manifest commit.
    package func saveImportedResearchState(
        _ proposed: GlifiResearchState, expectedRevision: Int, importedTexts: [GlifiImportedText],
        attachments: [GlifiProjectArtifactAttachment] = []
    ) throws -> GlifiResearchState {
        let current = try researchState()
        guard current.revision == expectedRevision, proposed.revision == expectedRevision else {
            throw researchFailure("research.stale-revision", category: .staleArtifact)
        }
        guard current.revision < 10_000 else {
            throw researchFailure("research.history-limit", category: .insufficientResources)
        }
        let snapshot = snapshot()
        var next = proposed
        next.revision += 1
        next.fields.sort { $0.id < $1.id }
        next.records.sort { $0.sourceRevisionID < $1.sourceRevisionID }
        next.subsets.sort { $0.id < $1.id }
        for index in next.subsets.indices { next.subsets[index].sourceRevisionIDs.sort() }
        try next.validate(
            sourceRevisionIDs: Set(
                snapshot.sources.map { $0.sourceRevisionID.canonicalValue }
                    + importedTexts.map { $0.sourceRevisionID.canonicalValue }))
        try validateResearchOrigins(next, importedTexts: importedTexts, attachments: attachments)
        try validateResearchProducers(next)
        let previous = try researchHistory().last
        let dependencies =
            try previous.map {
                [
                    try GlifiAnalysisDependency(
                        nodeID: $0.node.id, artifactDigest: $0.contentDigest,
                        outputSchemaIdentifier: GlifiResearchStateArtifact.outputSchemaIdentifier)
                ]
            } ?? []
        let contentDigest = try researchDigest(next)
        let descriptor = try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.research-state",
            algorithmIdentifier: "research-state-append-v1", algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: snapshot.corpusVersionDigest(for: []),
            selectionIdentifier: "project-configuration",
            analyticalUnitIdentifier: "research-state",
            preprocessingIdentifiers: [], linguisticProfileIdentifiers: ["it"],
            representationIdentifier: "typed-metadata-and-preparation-v1",
            resolvedParameters: [
                "revision": .integer(Int64(next.revision)), "contentDigest": .text(contentDigest),
            ], seedPolicyIdentifier: "no-randomness", backendIdentifier: "studio.glifi.native",
            numericPolicyIdentifier: "typed-json-v1", determinismClass: .d0,
            outputSchemaIdentifier: GlifiResearchStateArtifact.outputSchemaIdentifier,
            softwareIdentifier: "GlifiStudio-research-v1", dependencies: dependencies,
            sourceRevisionIDs: [])
        let payload = GlifiResearchStateArtifact(
            schemaIdentifier: GlifiResearchStateArtifact.outputSchemaIdentifier,
            schemaVersion: 1, analysisNodeID: try descriptor.nodeID(),
            previousArtifactID: previous?.artifactID.canonicalValue, state: next)
        if importedTexts.isEmpty && attachments.isEmpty {
            _ = try storeArtifact(payload, descriptor: descriptor)
        } else {
            _ = try storeArtifact(
                payload, descriptor: descriptor, importedTexts: importedTexts,
                attachments: attachments)
        }
        return next
    }

    private func researchHistory() throws -> [GlifiProjectArtifactRecord] {
        let history = snapshot().artifacts.filter {
            $0.node.descriptor.artifactTypeIdentifier == "studio.glifi.artifact.research-state"
        }.sorted { researchRevision($0) < researchRevision($1) }
        guard history.count <= 10_000 else {
            throw researchFailure("research.history-limit", category: .insufficientResources)
        }
        for (index, record) in history.enumerated() {
            let descriptor = record.node.descriptor
            guard researchRevision(record) == index + 1,
                descriptor.outputSchemaIdentifier
                    == GlifiResearchStateArtifact.outputSchemaIdentifier,
                descriptor.algorithmIdentifier == "research-state-append-v1",
                descriptor.sourceRevisionIDs == [],
                descriptor.corpusIdentifier == snapshot().projectID.canonicalValue,
                descriptor.corpusVersionDigest == (try snapshot().corpusVersionDigest(for: [])),
                descriptor.dependencies.count == (index == 0 ? 0 : 1)
            else { throw researchFailure("research.invalid-history", category: .corruption) }
            if index > 0 {
                let previous = history[index - 1]
                guard descriptor.dependencies.first?.nodeID == previous.node.id,
                    descriptor.dependencies.first?.artifactDigest == previous.contentDigest
                else { throw researchFailure("research.invalid-history", category: .corruption) }
            }
        }
        return history
    }

    private func validateResearchProducers(_ state: GlifiResearchState) throws {
        let artifacts = Set(snapshot().artifacts.map { $0.artifactID.canonicalValue })
        guard
            state.fields.allSatisfy({
                $0.derivation.map { artifacts.contains($0.artifactID) } != false
            }),
            state.records.allSatisfy({
                $0.derivationArtifactID.map(artifacts.contains) != false
                    && ($0.derivationArtifactIDs?.values.allSatisfy(artifacts.contains) ?? true)
            })
        else { throw researchFailure("research.unknown-derivation") }
    }

    private func validateResearchOrigins(
        _ state: GlifiResearchState, importedTexts: [GlifiImportedText],
        attachments: [GlifiProjectArtifactAttachment]
    ) throws {
        let requested = Set(state.records.flatMap { $0.origins.values.map(\.inputDigest) })
        guard !requested.isEmpty else { return }
        guard requested.count <= 1_000 else {
            throw researchFailure("research.origin-limit", category: .insufficientResources)
        }
        let snapshot = snapshot()
        var sourceDigests = Dictionary(
            uniqueKeysWithValues: snapshot.sources.map {
                ($0.sourceRevisionID.canonicalValue, $0.contentDigest)
            })
        for imported in importedTexts {
            sourceDigests[imported.sourceRevisionID.canonicalValue] = imported.contentDigest
        }
        var evidence: [String: [Int: [ResearchOriginEvidence]]] = [:]
        var readBytes = 0
        func incorporate(_ data: Data, descriptor: GlifiAnalysisDescriptor) throws {
            guard data.count <= 256 * 1_024 * 1_024 - readBytes else {
                throw researchFailure("research.origin-limit", category: .insufficientResources)
            }
            readBytes += data.count
            let archived = try JSONDecoder().decode(ResearchTabularArchive.self, from: data)
            guard archived.schemaIdentifier == ResearchTabularArchive.schema,
                archived.schemaVersion == 1, archived.analysisNodeID == (try descriptor.nodeID()),
                archived.dataset.sourceByteCount == archived.data.count,
                archived.dataset.sourceDigest == researchRawDigest(archived.data),
                descriptor.resolvedParameters["inputDigest"]
                    == .text(archived.dataset.sourceDigest),
                archived.dataset.records.count <= 100_000
            else { throw researchFailure("research.invalid-origin-archive", category: .corruption) }
            for row in archived.dataset.records {
                let cells = Set(
                    row.origins.values.map {
                        ResearchCellAddress(sheet: $0.sheet, row: $0.row, column: $0.column)
                    })
                evidence[archived.dataset.sourceDigest, default: [:]][row.rowNumber, default: []]
                    .append(
                        ResearchOriginEvidence(
                            textDigest: researchRawDigest(Data(row.text.utf8)), cells: cells))
            }
        }
        for artifact in snapshot.artifacts {
            let descriptor = artifact.node.descriptor
            guard descriptor.outputSchemaIdentifier == ResearchTabularArchive.schema,
                case let .text(inputDigest) = descriptor.resolvedParameters["inputDigest"],
                requested.contains(inputDigest)
            else { continue }
            try incorporate(artifactData(for: artifact.artifactID), descriptor: descriptor)
        }
        for attachment in attachments {
            let descriptor = attachment.descriptor
            guard descriptor.outputSchemaIdentifier == ResearchTabularArchive.schema,
                case let .text(inputDigest) = descriptor.resolvedParameters["inputDigest"],
                requested.contains(inputDigest)
            else { continue }
            try incorporate(attachment.data, descriptor: descriptor)
        }
        for record in state.records {
            try Task.checkCancellation()
            for origin in record.origins.values {
                let cell = ResearchCellAddress(
                    sheet: origin.sheet, row: origin.row, column: origin.column)
                guard let rows = evidence[origin.inputDigest]?[origin.row],
                    rows.contains(where: {
                        $0.textDigest == sourceDigests[record.sourceRevisionID]
                            && $0.cells.contains(cell)
                    })
                else { throw researchFailure("research.unverified-origin") }
            }
        }
    }
}

private struct ResearchCellAddress: Hashable {
    let sheet: String?
    let row: Int
    let column: Int
}

private struct ResearchOriginEvidence {
    let textDigest: String
    let cells: Set<ResearchCellAddress>
}

private struct ResearchTabularArchive: Decodable {
    static let schema = "studio.glifi.artifact.tabular-source.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let data: Data
    let dataset: GlifiTabularMappedDataset
}

private func researchRevision(_ record: GlifiProjectArtifactRecord) -> Int64 {
    if case let .integer(value) = record.node.descriptor.resolvedParameters["revision"] {
        return value
    }
    return -1
}

package func researchCanonicalData<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

package func researchDigest<Value: Encodable>(_ value: Value) throws -> String {
    researchRawDigest(try researchCanonicalData(value))
}

private func researchRawDigest(_ data: Data) -> String {
    "sha256:"
        + SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
}

package func researchFailure(
    _ code: String, category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .persistProject,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: .lastCommittedGeneration, messageKey: "failure.\(code)")
}

private func researchIdentifier(_ value: String) -> Bool {
    (1...64).contains(value.utf8.count)
        && value.utf8.allSatisfy {
            (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 || $0 == 95
        }
}

private func researchParameterKey(_ value: String) -> Bool {
    (1...64).contains(value.utf8.count)
        && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                || $0 == 45 || $0 == 46 || $0 == 95
        }
}

private func researchText(_ value: String, maximum: Int) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= maximum
}

private func validateResearchValue(_ value: GlifiResearchValue, type: GlifiResearchFieldType) throws
{
    let valid: Bool
    switch (value, type) {
    case (.missing, _): valid = true
    case let (.text(text), .text): valid = text.utf8.count <= 65_536
    case let (.number(number), .number): valid = number.isFinite
    case (.boolean, .boolean): valid = true
    case let (.date(date), .date):
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let pieces = date.split(separator: "-", omittingEmptySubsequences: false)
        if date.utf8.count == 10, pieces.count == 3, pieces[0].count == 4,
            pieces[1].count == 2, pieces[2].count == 2,
            let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]),
            (1...9999).contains(year),
            let instant = calendar.date(from: DateComponents(year: year, month: month, day: day))
        {
            let checked = calendar.dateComponents([.year, .month, .day], from: instant)
            valid = checked.year == year && checked.month == month && checked.day == day
        } else {
            valid = false
        }
    case (.text, .number), (.text, .boolean), (.text, .date),
        (.number, .text), (.number, .boolean), (.number, .date),
        (.boolean, .text), (.boolean, .number), (.boolean, .date),
        (.date, .text), (.date, .number), (.date, .boolean):
        valid = false
    }
    guard valid else { throw researchFailure("research.invalid-value") }
}
