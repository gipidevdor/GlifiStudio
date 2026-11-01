// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import Synchronization

/// Stable fields admitted by `query-ast-v1`.
public struct GlifiQueryField: Codable, Hashable, RawRepresentable, Sendable {
    /// Surface text field using exact token forms.
    public static let form = GlifiQueryField(rawValue: "form")
    /// NFC/lowercase token field produced by the Italian profile.
    public static let normalized = GlifiQueryField(rawValue: "normalized")
    /// Visible document text field.
    public static let text = GlifiQueryField(rawValue: "text")
    /// Linguistic lemma field, available only with a capable backend.
    public static let lemma = GlifiQueryField(rawValue: "lemma")
    /// Stable document title field.
    public static let documentTitle = GlifiQueryField(rawValue: "document.title")
    /// Stable document identifier field.
    public static let documentID = GlifiQueryField(rawValue: "document.id")
    /// Stable source identifier field.
    public static let sourceID = GlifiQueryField(rawValue: "source.id")
    /// Stable corpus identifier field.
    public static let corpusID = GlifiQueryField(rawValue: "corpus.id")
    /// Part-of-speech field, available only with a capable backend.
    public static let partOfSpeech = GlifiQueryField(rawValue: "pos")
    /// Named-entity field, available only with a capable backend.
    public static let entity = GlifiQueryField(rawValue: "entity")

    /// Stable canonical field name.
    public let rawValue: String

    /// Creates a field reference without silently changing its canonical spelling.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Whether the field belongs to the public v1 algebra.
    public var isKnown: Bool {
        Self.knownFields.contains(self) || isMetadata
    }

    /// Whether the field addresses a typed project metadata field.
    public var isMetadata: Bool {
        guard rawValue.hasPrefix("metadata."), rawValue.utf8.count > 9 else { return false }
        return rawValue.dropFirst(9).allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-")
        }
    }

    private static let knownFields: Set<GlifiQueryField> = [
        .form,
        .normalized,
        .text,
        .lemma,
        .documentTitle,
        .documentID,
        .sourceID,
        .corpusID,
        .partOfSpeech,
        .entity,
    ]
}

/// Explicit term comparison behavior.
public enum GlifiTermMatchMode: String, Codable, Sendable {
    case exact
}

/// Explicit regex options in canonical order.
public struct GlifiRegexFlags: OptionSet, Codable, Hashable, Sendable {
    /// ASCII case-insensitive matching.
    public static let caseInsensitive = GlifiRegexFlags(rawValue: 1 << 0)
    /// Canonically equivalent Unicode comparison.
    public static let canonicalEquivalence = GlifiRegexFlags(rawValue: 1 << 1)

    /// Stable bit representation.
    public let rawValue: Int

    /// Creates flags from the persisted bit representation.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// Inclusive/exclusive bounds of one typed range query.
public struct GlifiQueryRange: Codable, Equatable, Sendable {
    /// Optional lower textual bound; `nil` means unbounded.
    public let lower: String?
    /// Optional upper textual bound; `nil` means unbounded.
    public let upper: String?
    /// Whether the lower bound is included.
    public let includesLower: Bool
    /// Whether the upper bound is included.
    public let includesUpper: Bool

    /// Creates one explicit range value.
    public init(
        lower: String?,
        upper: String?,
        includesLower: Bool,
        includesUpper: Bool
    ) {
        self.lower = lower
        self.upper = upper
        self.includesLower = includesLower
        self.includesUpper = includesUpper
    }
}

/// Unit used to measure proximity.
public enum GlifiProximityUnit: String, Codable, Sendable {
    case surfaceToken
}

/// Stable scope embedded by a programmatic `within` node.
public enum GlifiQueryScope: Equatable, Sendable {
    case project(ProjectID)
    case corpus(CorpusVersionID)
    case sourceRevision(SourceRevisionID)
}

extension GlifiQueryScope: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    private enum ScopeType: String, Codable {
        case project
        case corpus
        case sourceRevision
    }

    /// Decodes an explicitly tagged scope and validates its typed identifier.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identifier = try container.decode(String.self, forKey: .id)
        switch try container.decode(ScopeType.self, forKey: .type) {
        case .project:
            self = try .project(ProjectID(canonicalValue: identifier))
        case .corpus:
            self = try .corpus(CorpusVersionID(canonicalValue: identifier))
        case .sourceRevision:
            self = try .sourceRevision(SourceRevisionID(canonicalValue: identifier))
        }
    }

    /// Encodes an explicitly tagged scope with one canonical typed identifier.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .project(identifier):
            try container.encode(ScopeType.project, forKey: .type)
            try container.encode(identifier.canonicalValue, forKey: .id)
        case let .corpus(identifier):
            try container.encode(ScopeType.corpus, forKey: .type)
            try container.encode(identifier.canonicalValue, forKey: .id)
        case let .sourceRevision(identifier):
            try container.encode(ScopeType.sourceRevision, forKey: .type)
            try container.encode(identifier.canonicalValue, forKey: .id)
        }
    }
}

/// Canonical typed algebra of `query-ast-v1`.
public indirect enum GlifiQueryNode: Equatable, Sendable {
    case matchAll
    case term(field: GlifiQueryField, value: String, matchMode: GlifiTermMatchMode)
    case phrase(field: GlifiQueryField, values: [String], slop: Int)
    case regex(field: GlifiQueryField, pattern: String, flags: GlifiRegexFlags)
    case range(field: GlifiQueryField, value: GlifiQueryRange)
    case exists(field: GlifiQueryField)
    case proximity(
        left: GlifiQueryNode,
        right: GlifiQueryNode,
        distance: Int,
        unit: GlifiProximityUnit,
        ordered: Bool
    )
    case not(GlifiQueryNode)
    case and([GlifiQueryNode])
    case or([GlifiQueryNode])
    case within(GlifiQueryNode, scope: GlifiQueryScope)
}

extension GlifiQueryNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case field
        case value
        case matchMode
        case values
        case slop
        case pattern
        case flags
        case range
        case left
        case right
        case distance
        case unit
        case ordered
        case child
        case children
        case scope
    }

    private enum NodeType: String, Codable {
        case matchAll
        case term
        case phrase
        case regex
        case range
        case exists
        case proximity
        case not
        case and
        case or
        case within
    }

    /// Decodes the explicit, tagged v1 representation.
    public init(from decoder: any Decoder) throws {
        if let key = QueryDecodingBudget.userInfoKey,
            let budget = decoder.userInfo[key] as? QueryDecodingBudget
        {
            try budget.consume(at: decoder.codingPath)
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(NodeType.self, forKey: .type) {
        case .matchAll:
            self = .matchAll
        case .term:
            self = try .term(
                field: container.decode(GlifiQueryField.self, forKey: .field),
                value: container.decode(String.self, forKey: .value),
                matchMode: container.decode(GlifiTermMatchMode.self, forKey: .matchMode)
            )
        case .phrase:
            self = try .phrase(
                field: container.decode(GlifiQueryField.self, forKey: .field),
                values: container.decode([String].self, forKey: .values),
                slop: container.decode(Int.self, forKey: .slop)
            )
        case .regex:
            self = try .regex(
                field: container.decode(GlifiQueryField.self, forKey: .field),
                pattern: container.decode(String.self, forKey: .pattern),
                flags: container.decode(GlifiRegexFlags.self, forKey: .flags)
            )
        case .range:
            self = try .range(
                field: container.decode(GlifiQueryField.self, forKey: .field),
                value: container.decode(GlifiQueryRange.self, forKey: .range)
            )
        case .exists:
            self = try .exists(field: container.decode(GlifiQueryField.self, forKey: .field))
        case .proximity:
            self = try .proximity(
                left: container.decode(GlifiQueryNode.self, forKey: .left),
                right: container.decode(GlifiQueryNode.self, forKey: .right),
                distance: container.decode(Int.self, forKey: .distance),
                unit: container.decode(GlifiProximityUnit.self, forKey: .unit),
                ordered: container.decode(Bool.self, forKey: .ordered)
            )
        case .not:
            self = try .not(container.decode(GlifiQueryNode.self, forKey: .child))
        case .and:
            self = try .and(container.decode([GlifiQueryNode].self, forKey: .children))
        case .or:
            self = try .or(container.decode([GlifiQueryNode].self, forKey: .children))
        case .within:
            self = try .within(
                container.decode(GlifiQueryNode.self, forKey: .child),
                scope: container.decode(GlifiQueryScope.self, forKey: .scope)
            )
        }
    }

    /// Encodes the explicit, tagged v1 representation.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .matchAll:
            try container.encode(NodeType.matchAll, forKey: .type)
        case let .term(field, value, matchMode):
            try container.encode(NodeType.term, forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(value, forKey: .value)
            try container.encode(matchMode, forKey: .matchMode)
        case let .phrase(field, values, slop):
            try container.encode(NodeType.phrase, forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(values, forKey: .values)
            try container.encode(slop, forKey: .slop)
        case let .regex(field, pattern, flags):
            try container.encode(NodeType.regex, forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(pattern, forKey: .pattern)
            try container.encode(flags, forKey: .flags)
        case let .range(field, value):
            try container.encode(NodeType.range, forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(value, forKey: .range)
        case let .exists(field):
            try container.encode(NodeType.exists, forKey: .type)
            try container.encode(field, forKey: .field)
        case let .proximity(left, right, distance, unit, ordered):
            try container.encode(NodeType.proximity, forKey: .type)
            try container.encode(left, forKey: .left)
            try container.encode(right, forKey: .right)
            try container.encode(distance, forKey: .distance)
            try container.encode(unit, forKey: .unit)
            try container.encode(ordered, forKey: .ordered)
        case let .not(child):
            try container.encode(NodeType.not, forKey: .type)
            try container.encode(child, forKey: .child)
        case let .and(children):
            try container.encode(NodeType.and, forKey: .type)
            try container.encode(children, forKey: .children)
        case let .or(children):
            try container.encode(NodeType.or, forKey: .type)
            try container.encode(children, forKey: .children)
        case let .within(child, scope):
            try container.encode(NodeType.within, forKey: .type)
            try container.encode(child, forKey: .child)
            try container.encode(scope, forKey: .scope)
        }
    }
}

/// Versioned canonical query shared by every product surface.
public struct GlifiQueryAST: Codable, Equatable, Sendable {
    /// Stable schema identifier.
    public static let schema = "studio.glifi.query-ast"
    /// Stable schema version.
    public static let schemaVersion = 1
    /// Stable textual grammar version.
    public static let grammarVersion = "glifi-query-v1"

    /// Schema identifier persisted with the query.
    public let schema: String
    /// Schema version persisted with the query.
    public let schemaVersion: Int
    /// Textual grammar that produced this AST.
    public let grammarVersion: String
    /// Canonical root node.
    public let root: GlifiQueryNode

    /// Creates one v1 query AST.
    public init(root: GlifiQueryNode) {
        schema = Self.schema
        schemaVersion = Self.schemaVersion
        grammarVersion = Self.grammarVersion
        self.root = root
    }

    /// Decodes untrusted v1 JSON with byte, node, and depth limits before execution.
    ///
    /// Malformed input produces a typed failure without decoder details or content.
    public static func decode(
        _ data: Data,
        limits: GlifiQueryLimits = .standard
    ) throws -> GlifiQueryAST {
        guard data.count <= limits.maximumQueryByteCount else {
            throw queryExecutionFailure(
                "query.byte-limit-exceeded", category: .insufficientResources)
        }
        try Task.checkCancellation()
        guard let key = QueryDecodingBudget.userInfoKey else {
            throw queryExecutionFailure("query.internal-failure", category: .invariantViolation)
        }
        let decoder = JSONDecoder()
        decoder.userInfo[key] = QueryDecodingBudget(limits: limits)
        let query: Self
        do {
            query = try decoder.decode(Self.self, from: data)
        } catch let failure as GlifiFailure
            where ["query.node-limit-exceeded", "query.depth-limit-exceeded"].contains(failure.code)
        {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw queryExecutionFailure("query.invalid-ast")
        }
        try GlifiQueryEvaluator().validate(query, limits: limits)
        return query
    }

    /// Returns deterministic JSON with sorted keys and no locale-sensitive values.
    public func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Returns the SHA-256 identity of the canonical v1 representation.
    public func canonicalDigest() throws -> String {
        let hash = SHA256.hash(data: try canonicalData())
        return "sha256:" + hash.map { String(format: "%02x", $0) }.joined()
    }
}

private final class QueryDecodingBudget: Sendable {
    static let userInfoKey = CodingUserInfoKey(rawValue: "studio.glifi.query-decoding-budget")
    let limits: GlifiQueryLimits
    private let nodeCount = Mutex(0)

    init(limits: GlifiQueryLimits) {
        self.limits = limits
    }

    func consume(at path: [any CodingKey]) throws {
        try Task.checkCancellation()
        try nodeCount.withLock { count in
            guard count < limits.maximumNodeCount else {
                throw queryExecutionFailure(
                    "query.node-limit-exceeded", category: .insufficientResources)
            }
            count += 1
        }
        let depth = path.filter { ["child", "children", "left", "right"].contains($0.stringValue) }
            .count
        guard depth <= limits.maximumDepth else {
            throw queryExecutionFailure(
                "query.depth-limit-exceeded", category: .insufficientResources)
        }
    }
}

/// Resource limits applied before and during query parsing and execution.
public struct GlifiQueryLimits: Equatable, Sendable {
    /// Conservative normative baseline for v1.
    public static let standard = GlifiQueryLimits(
        maximumQueryByteCount: 65_536,
        maximumDepth: 32,
        maximumNodeCount: 1_024,
        maximumPhraseTokenCount: 256,
        maximumProximityDistance: 10_000,
        maximumRegexByteCount: 256,
        maximumRegexInputByteCount: 4_096,
        maximumSourceCount: 1_000,
        maximumScannedByteCount: 256 * 1_024 * 1_024,
        maximumResultCount: 1_000,
        contextTokenCount: 5
    )

    /// Maximum UTF-8 byte length of a textual query.
    public let maximumQueryByteCount: Int
    /// Maximum parenthesis/unary nesting and AST edge depth (root is zero).
    public let maximumDepth: Int
    /// Maximum number of AST nodes.
    public let maximumNodeCount: Int
    /// Maximum token count of a phrase.
    public let maximumPhraseTokenCount: Int
    /// Maximum distance of one proximity operator.
    public let maximumProximityDistance: Int
    /// Maximum UTF-8 byte length of a regex pattern.
    public let maximumRegexByteCount: Int
    /// Maximum UTF-8 byte length of one token admitted to regex evaluation.
    public let maximumRegexInputByteCount: Int
    /// Maximum source revisions scanned by one non-indexed query.
    public let maximumSourceCount: Int
    /// Maximum incorporated source bytes scanned by one non-indexed query.
    public let maximumScannedByteCount: Int
    /// Maximum result rows materialized by the bounded evaluator.
    public let maximumResultCount: Int
    /// Number of surface tokens retained on each KWIC side.
    public let contextTokenCount: Int

    /// Creates non-negative bounded query limits.
    public init(
        maximumQueryByteCount: Int,
        maximumDepth: Int,
        maximumNodeCount: Int,
        maximumPhraseTokenCount: Int,
        maximumProximityDistance: Int,
        maximumRegexByteCount: Int,
        maximumRegexInputByteCount: Int,
        maximumSourceCount: Int,
        maximumScannedByteCount: Int,
        maximumResultCount: Int,
        contextTokenCount: Int
    ) {
        self.maximumQueryByteCount = max(0, maximumQueryByteCount)
        self.maximumDepth = max(0, maximumDepth)
        self.maximumNodeCount = max(0, maximumNodeCount)
        self.maximumPhraseTokenCount = max(0, maximumPhraseTokenCount)
        self.maximumProximityDistance = max(0, maximumProximityDistance)
        self.maximumRegexByteCount = max(0, maximumRegexByteCount)
        self.maximumRegexInputByteCount = max(0, maximumRegexInputByteCount)
        self.maximumSourceCount = max(0, maximumSourceCount)
        self.maximumScannedByteCount = max(0, maximumScannedByteCount)
        self.maximumResultCount = max(0, maximumResultCount)
        self.contextTokenCount = max(0, contextTokenCount)
    }
}
