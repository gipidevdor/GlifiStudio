// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Explicit types of user-owned corpus variables.
public enum GlifiStudioResearchFieldType: String, Codable, CaseIterable, Sendable {
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
public enum GlifiStudioResearchValue: Codable, Equatable, Sendable {
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

    /// Decodes the explicit tagged wire representation shared with the project format.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        switch try fields.decode(Kind.self, forKey: .type) {
        case .missing:
            guard !fields.contains(.value) else {
                throw GlifiStudioFailure(researchFailure("research.invalid-value"))
            }
            self = .missing
        case .text: self = .text(try fields.decode(String.self, forKey: .value))
        case .number: self = .number(try fields.decode(Double.self, forKey: .value))
        case .boolean: self = .boolean(try fields.decode(Bool.self, forKey: .value))
        case .date: self = .date(try fields.decode(String.self, forKey: .value))
        }
    }

    /// Encodes an explicit tag and a JSON primitive; missing has no value member.
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

/// Explicit creation procedure of a derived variable, separate from later per-record overrides.
public struct GlifiStudioResearchFieldDerivation: Codable, Equatable, Sendable {
    /// Existing immutable output that produced the derived values.
    public var artifactID: String
    /// Versioned transformation applied to the saved output.
    public var operationIdentifier: String
    /// Resolved transformation parameters, including the chosen hierarchical cut.
    public var parameters: [String: String]

    /// Captures the producer and transformation without recalculating its result.
    public init(artifactID: String, operationIdentifier: String, parameters: [String: String] = [:])
    {
        self.artifactID = artifactID
        self.operationIdentifier = operationIdentifier
        self.parameters = parameters
    }
}

/// A stable variable identity and its human-facing label.
public struct GlifiStudioResearchField: Codable, Equatable, Sendable {
    /// Stable ASCII identity, independent of the displayed label.
    public var id: String
    /// Human-readable label of the field or reusable source selection.
    public var label: String
    /// Declared value type; missing observations remain distinct.
    public var type: GlifiStudioResearchFieldType
    /// Original creation procedure; individual observations may later be edited explicitly.
    public var derivation: GlifiStudioResearchFieldDerivation?

    /// Creates explicit research data for validation by the project writer.
    public init(
        id: String, label: String, type: GlifiStudioResearchFieldType,
        derivation: GlifiStudioResearchFieldDerivation? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.derivation = derivation
    }
}

/// Exact original cell of an imported observation; both ordinals are one-based.
public struct GlifiStudioResearchCellOrigin: Codable, Equatable, Sendable {
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
public struct GlifiStudioResearchRecord: Codable, Equatable, Sendable {
    /// Immutable source revision that owns these observations.
    public var sourceRevisionID: String
    /// Typed observations keyed by stable field identity.
    public var values: [String: GlifiStudioResearchValue]
    /// Original external row identifier, when explicitly supplied.
    public var externalID: String?
    /// Legacy producer identity, retained for earlier research records.
    public var derivationArtifactID: String?
    /// Independent producer identity for each derived field.
    public var derivationArtifactIDs: [String: String]?
    /// Field identities, or `$text`/`$id`, identify the original cells.
    public var origins: [String: GlifiStudioResearchCellOrigin]

    /// Creates explicit research data for validation by the project writer.
    public init(
        sourceRevisionID: String, values: [String: GlifiStudioResearchValue],
        externalID: String? = nil,
        derivationArtifactID: String? = nil, origins: [String: GlifiStudioResearchCellOrigin] = [:],
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
public struct GlifiStudioResearchSubset: Codable, Equatable, Sendable {
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
public struct GlifiStudioResearchState: Codable, Equatable, Sendable {
    /// Monotonic research revision used for optimistic concurrency.
    public var revision: Int
    /// Stable field definitions and their explicitly selected types.
    public var fields: [GlifiStudioResearchField]
    /// Per-source observations, identifiers and original-cell provenance.
    public var records: [GlifiStudioResearchRecord]
    /// Named reusable selections of immutable source revisions.
    public var subsets: [GlifiStudioResearchSubset]
    /// Shared Italian lexical configuration for corpus analysis.
    public var preparation: GlifiStudioCorpusPreparation

    /// Creates explicit research data for validation by the project writer.
    public init(
        revision: Int = 0, fields: [GlifiStudioResearchField] = [],
        records: [GlifiStudioResearchRecord] = [],
        subsets: [GlifiStudioResearchSubset] = [],
        preparation: GlifiStudioCorpusPreparation = .init()
    ) {
        self.revision = revision
        self.fields = fields
        self.records = records
        self.subsets = subsets
        self.preparation = preparation
    }

    /// Validates the same typed wire contract as the project writer.
    public func validate(sourceRevisionIDs: Set<String>? = nil) throws(GlifiStudioFailure) {
        try researchPresentationOperation {
            try core().validate(sourceRevisionIDs: sourceRevisionIDs)
        }
    }

    package func core() throws -> GlifiResearchState {
        try JSONDecoder().decode(GlifiResearchState.self, from: researchCanonicalData(self))
    }

    package init(_ value: GlifiResearchState) throws {
        self = try JSONDecoder().decode(Self.self, from: researchCanonicalData(value))
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
        self.fields = try fields.decode([GlifiStudioResearchField].self, forKey: .fields)
        records = try fields.decode([GlifiStudioResearchRecord].self, forKey: .records)
        subsets = try fields.decode([GlifiStudioResearchSubset].self, forKey: .subsets)
        preparation = try fields.decode(GlifiStudioCorpusPreparation.self, forKey: .preparation)
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case revision, fields, records, subsets, preparation
    }
}

/// A conjunction of an optional reusable subset, typed field equality and a textual query.
public struct GlifiStudioResearchFilter: Codable, Equatable, Sendable {
    /// Optional identity of a reusable source selection.
    public var subsetID: String?
    /// Optional stable identity of the field tested for equality.
    public var fieldID: String?
    /// Typed equality operand; supplied together with the field identity.
    public var value: GlifiStudioResearchValue?
    /// Optional textual predicate combined with metadata and source selection.
    public var query: String?

    /// Creates explicit research data for validation by the project writer.
    public init(
        subsetID: String? = nil, fieldID: String? = nil, value: GlifiStudioResearchValue? = nil,
        query: String? = nil
    ) {
        self.subsetID = subsetID
        self.fieldID = fieldID
        self.value = value
        self.query = query
    }

    /// Resolves the typed predicate against an explicit project source order.
    public func select(
        from state: GlifiStudioResearchState, sourceRevisionIDs: [String]
    ) throws(GlifiStudioFailure) -> [String] {
        try researchPresentationOperation {
            try core().select(from: state.core(), sourceRevisionIDs: sourceRevisionIDs)
        }
    }

    package func core() throws -> GlifiResearchFilter {
        try JSONDecoder().decode(GlifiResearchFilter.self, from: researchCanonicalData(self))
    }
}

package func researchPresentationOperation<Value>(
    _ body: () throws -> Value
) throws(GlifiStudioFailure) -> Value {
    do { return try body() } catch let failure as GlifiStudioFailure { throw failure } catch let
        failure as GlifiFailure
    { throw GlifiStudioFailure(failure) } catch is CancellationError {
        throw GlifiStudioFailure(researchFailure("operation.cancelled", category: .cancelled))
    } catch {
        throw GlifiStudioFailure(researchFailure("research.invalid-state"))
    }
}
