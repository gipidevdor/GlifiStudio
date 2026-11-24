// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Canonically encoded value admitted in resolved analytical parameters.
public indirect enum GlifiAnalysisValue: Codable, Equatable, Sendable {
    /// Boolean value.
    case boolean(Bool)
    /// Signed integer value.
    case integer(Int64)
    /// Finite IEEE-754 binary64 value; signed zero is canonicalized to positive zero.
    case decimal(Double)
    /// NFC text value.
    case text(String)
    /// Ordered values.
    case list([GlifiAnalysisValue])
    /// Keyed values whose key order is not semantic.
    case object([String: GlifiAnalysisValue])

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Kind: String, Codable { case boolean, integer, decimal, text, list, object }

    /// Decodes the explicit tagged representation.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .integer: self = .integer(try container.decode(Int64.self, forKey: .value))
        case .decimal: self = .decimal(try container.decode(Double.self, forKey: .value))
        case .text: self = .text(try container.decode(String.self, forKey: .value))
        case .list:
            self = .list(try container.decode([GlifiAnalysisValue].self, forKey: .value))
        case .object:
            self = .object(
                try container.decode([String: GlifiAnalysisValue].self, forKey: .value)
            )
        }
    }

    /// Encodes an explicit tagged representation without type ambiguity.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .boolean(value):
            try container.encode(Kind.boolean, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .integer(value):
            try container.encode(Kind.integer, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .decimal(value):
            try container.encode(Kind.decimal, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .text(value):
            try container.encode(Kind.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .list(value):
            try container.encode(Kind.list, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .object(value):
            try container.encode(Kind.object, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    func canonicalized() throws -> Self {
        switch self {
        case .boolean, .integer:
            return self
        case let .decimal(value):
            guard value.isFinite else { throw analysisGraphFailure("analysis.invalid-number") }
            return .decimal(value == 0 ? 0 : value)
        case let .text(value):
            return .text(value.precomposedStringWithCanonicalMapping)
        case let .list(values):
            return .list(try values.map { try $0.canonicalized() })
        case let .object(values):
            var result: [String: Self] = [:]
            for (key, value) in values {
                let canonicalKey = key.precomposedStringWithCanonicalMapping
                guard !canonicalKey.isEmpty, result[canonicalKey] == nil else {
                    throw analysisGraphFailure("analysis.invalid-parameter-key")
                }
                result[canonicalKey] = try value.canonicalized()
            }
            return .object(result)
        }
    }
}

/// Stable determinism class declared by an analytical node.
public enum GlifiDeterminismClass: String, Codable, Equatable, Sendable {
    /// Bit-exact deterministic output.
    case d0 = "D0"
    /// Numerically deterministic output within a declared tolerance.
    case d1 = "D1"
    /// Seeded probabilistic output.
    case p1 = "P1"
    /// Non-reproducible output with explicit provenance.
    case n1 = "N1"
}

/// One typed parent edge recorded by an analysis descriptor.
public struct GlifiAnalysisDependency: Codable, Equatable, Sendable {
    /// Semantic identity of the parent node.
    public let nodeID: AnalysisNodeID
    /// Expected immutable output-artifact digest.
    public let artifactDigest: String
    /// Expected parent output schema.
    public let outputSchemaIdentifier: String

    /// Creates a validated dependency edge.
    public init(
        nodeID: AnalysisNodeID,
        artifactDigest: String,
        outputSchemaIdentifier: String
    ) throws {
        guard isSHA256Digest(artifactDigest), !outputSchemaIdentifier.isEmpty else {
            throw analysisGraphFailure("analysis.invalid-dependency")
        }
        self.nodeID = nodeID
        self.artifactDigest = artifactDigest
        self.outputSchemaIdentifier =
            outputSchemaIdentifier
            .precomposedStringWithCanonicalMapping
    }

    private enum CodingKeys: String, CodingKey {
        case nodeID, artifactDigest, outputSchemaIdentifier
    }

    /// Decodes and validates a dependency edge.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            nodeID: container.decode(AnalysisNodeID.self, forKey: .nodeID),
            artifactDigest: container.decode(String.self, forKey: .artifactDigest),
            outputSchemaIdentifier: container.decode(
                String.self,
                forKey: .outputSchemaIdentifier
            )
        )
    }
}

/// Complete canonical semantic descriptor for one analytical output.
public struct GlifiAnalysisDescriptor: Codable, Equatable, Sendable {
    /// Descriptor format identity of a descriptor that does not declare its source revisions.
    public static let schemaIdentifier = "studio.glifi.analysis-descriptor.v1"

    /// Descriptor format identity of a descriptor that declares the source revisions it uses.
    public static let selectiveSchemaIdentifier = "studio.glifi.analysis-descriptor.v2"

    /// Descriptor format identity serialized with this instance.
    ///
    /// A descriptor that declares `sourceRevisionIDs` is a v2 descriptor; one that leaves them
    /// undeclared keeps the v1 identity and, with it, the node identity it had before v2 existed.
    public var descriptorSchemaIdentifier: String {
        sourceRevisionIDs == nil ? Self.schemaIdentifier : Self.selectiveSchemaIdentifier
    }

    /// Output artifact family.
    public let artifactTypeIdentifier: String
    /// Algorithm identity.
    public let algorithmIdentifier: String
    /// Logical algorithm version.
    public let algorithmVersion: String
    /// Immutable corpus identity or digest.
    public let corpusIdentifier: String
    /// Immutable corpus-version digest.
    public let corpusVersionDigest: String
    /// Canonical selection contract.
    public let selectionIdentifier: String
    /// Analytical unit contract.
    public let analyticalUnitIdentifier: String
    /// Ordered preprocessing chain.
    public let preprocessingIdentifiers: [String]
    /// Ordered linguistic profile versions.
    public let linguisticProfileIdentifiers: [String]
    /// Representation, orientation and missing-value contract.
    public let representationIdentifier: String
    /// Fully resolved, canonically keyed parameters.
    public let resolvedParameters: [String: GlifiAnalysisValue]
    /// Explicit seed or no-seed policy.
    public let seedPolicyIdentifier: String
    /// Backend identity when semantic equivalence does not make it irrelevant.
    public let backendIdentifier: String
    /// Numeric precision and reduction policy.
    public let numericPolicyIdentifier: String
    /// Declared reproducibility class.
    public let determinismClass: GlifiDeterminismClass
    /// Output schema version.
    public let outputSchemaIdentifier: String
    /// Product/core implementation version.
    public let softwareIdentifier: String
    /// Canonically ordered parent edges.
    public let dependencies: [GlifiAnalysisDependency]
    /// Source revisions whose content this analysis reads, canonically ordered (ADR-0028).
    ///
    /// `nil` means the analysis is not declared against specific revisions and depends on the
    /// whole generation, the only reading available before v2. An empty array is different: it
    /// declares that the analysis reads no source revision at all, so no import can invalidate it.
    public let sourceRevisionIDs: [SourceRevisionID]?

    /// Creates a complete descriptor and rejects implicit or non-canonical values.
    public init(
        artifactTypeIdentifier: String,
        algorithmIdentifier: String,
        algorithmVersion: String,
        corpusIdentifier: String,
        corpusVersionDigest: String,
        selectionIdentifier: String,
        analyticalUnitIdentifier: String,
        preprocessingIdentifiers: [String],
        linguisticProfileIdentifiers: [String],
        representationIdentifier: String,
        resolvedParameters: [String: GlifiAnalysisValue],
        seedPolicyIdentifier: String,
        backendIdentifier: String,
        numericPolicyIdentifier: String,
        determinismClass: GlifiDeterminismClass,
        outputSchemaIdentifier: String,
        softwareIdentifier: String,
        dependencies: [GlifiAnalysisDependency],
        sourceRevisionIDs: [SourceRevisionID]? = nil
    ) throws {
        let required = [
            artifactTypeIdentifier, algorithmIdentifier, algorithmVersion, corpusIdentifier,
            selectionIdentifier, analyticalUnitIdentifier, representationIdentifier,
            seedPolicyIdentifier, backendIdentifier, numericPolicyIdentifier,
            outputSchemaIdentifier, softwareIdentifier,
        ]
        guard required.allSatisfy({ !$0.isEmpty }), isSHA256Digest(corpusVersionDigest) else {
            throw analysisGraphFailure("analysis.incomplete-descriptor")
        }
        guard preprocessingIdentifiers.allSatisfy({ !$0.isEmpty }),
            linguisticProfileIdentifiers.allSatisfy({ !$0.isEmpty })
        else {
            throw analysisGraphFailure("analysis.incomplete-descriptor")
        }
        let orderedDependencies = dependencies.sorted {
            $0.nodeID.canonicalValue < $1.nodeID.canonicalValue
        }
        guard Set(orderedDependencies.map(\.nodeID)).count == orderedDependencies.count else {
            throw analysisGraphFailure("analysis.duplicate-dependency")
        }
        var parameters: [String: GlifiAnalysisValue] = [:]
        for (key, value) in resolvedParameters {
            let canonicalKey = key.precomposedStringWithCanonicalMapping
            guard !canonicalKey.isEmpty, parameters[canonicalKey] == nil else {
                throw analysisGraphFailure("analysis.invalid-parameter-key")
            }
            parameters[canonicalKey] = try value.canonicalized()
        }
        self.artifactTypeIdentifier = canonical(artifactTypeIdentifier)
        self.algorithmIdentifier = canonical(algorithmIdentifier)
        self.algorithmVersion = canonical(algorithmVersion)
        self.corpusIdentifier = canonical(corpusIdentifier)
        self.corpusVersionDigest = corpusVersionDigest
        self.selectionIdentifier = canonical(selectionIdentifier)
        self.analyticalUnitIdentifier = canonical(analyticalUnitIdentifier)
        self.preprocessingIdentifiers = preprocessingIdentifiers.map(canonical)
        self.linguisticProfileIdentifiers = linguisticProfileIdentifiers.map(canonical)
        self.representationIdentifier = canonical(representationIdentifier)
        self.resolvedParameters = parameters
        self.seedPolicyIdentifier = canonical(seedPolicyIdentifier)
        self.backendIdentifier = canonical(backendIdentifier)
        self.numericPolicyIdentifier = canonical(numericPolicyIdentifier)
        self.determinismClass = determinismClass
        self.outputSchemaIdentifier = canonical(outputSchemaIdentifier)
        self.softwareIdentifier = canonical(softwareIdentifier)
        self.dependencies = orderedDependencies
        if let declared = sourceRevisionIDs {
            let ordered = declared.sorted { $0.canonicalValue < $1.canonicalValue }
            guard Set(ordered).count == ordered.count else {
                throw analysisGraphFailure("analysis.duplicate-source-revision")
            }
            self.sourceRevisionIDs = ordered
        } else {
            self.sourceRevisionIDs = nil
        }
    }

    /// Returns the SHA-256 digest of the complete canonical descriptor.
    public func canonicalDigest() throws -> String {
        try digest(of: self)
    }

    /// Returns the content identity used to deduplicate equivalent computation nodes.
    public func nodeID() throws -> AnalysisNodeID {
        struct InputReference: Encodable {
            let artifactDigest: String
            let outputSchemaIdentifier: String
        }
        struct Identity: Encodable {
            let domain: String
            let artifactTypeIdentifier: String
            let algorithmIdentifier: String
            let algorithmVersion: String
            let corpusIdentifier: String
            let corpusVersionDigest: String
            let selectionIdentifier: String
            let analyticalUnitIdentifier: String
            let preprocessingIdentifiers: [String]
            let linguisticProfileIdentifiers: [String]
            let representationIdentifier: String
            let resolvedParameters: [String: GlifiAnalysisValue]
            let seedPolicyIdentifier: String
            let backendIdentifier: String
            let numericPolicyIdentifier: String
            let determinismClass: GlifiDeterminismClass
            let outputSchemaIdentifier: String
            let softwareIdentifier: String
            let inputs: [InputReference]
            // Assente nei descrittori v1: la loro identità resta quella calcolata prima della v2.
            let sourceRevisionIDs: [String]?
        }
        let inputs = dependencies.map {
            InputReference(
                artifactDigest: $0.artifactDigest,
                outputSchemaIdentifier: $0.outputSchemaIdentifier
            )
        }.sorted {
            ($0.artifactDigest, $0.outputSchemaIdentifier)
                < ($1.artifactDigest, $1.outputSchemaIdentifier)
        }
        return try AnalysisNodeID(
            digest: digest(
                of: Identity(
                    domain: "glifi.analysis-node.v1",
                    artifactTypeIdentifier: artifactTypeIdentifier,
                    algorithmIdentifier: algorithmIdentifier,
                    algorithmVersion: algorithmVersion,
                    corpusIdentifier: corpusIdentifier,
                    corpusVersionDigest: corpusVersionDigest,
                    selectionIdentifier: selectionIdentifier,
                    analyticalUnitIdentifier: analyticalUnitIdentifier,
                    preprocessingIdentifiers: preprocessingIdentifiers,
                    linguisticProfileIdentifiers: linguisticProfileIdentifiers,
                    representationIdentifier: representationIdentifier,
                    resolvedParameters: resolvedParameters,
                    seedPolicyIdentifier: seedPolicyIdentifier,
                    backendIdentifier: backendIdentifier,
                    numericPolicyIdentifier: numericPolicyIdentifier,
                    determinismClass: determinismClass,
                    outputSchemaIdentifier: outputSchemaIdentifier,
                    softwareIdentifier: softwareIdentifier,
                    inputs: inputs,
                    sourceRevisionIDs: sourceRevisionIDs?.map(\.canonicalValue)
                )
            )
        )
    }

    /// Decodes and validates a complete descriptor.
    public init(from decoder: any Decoder) throws {
        let value = try DescriptorPayload(from: decoder)
        switch value.schemaIdentifier {
        case Self.schemaIdentifier:
            // Un descrittore v1 non dichiara revisioni: dipende dall'intera generazione.
            guard value.sourceRevisionIDs == nil else {
                throw analysisGraphFailure("analysis.unsupported-descriptor-version")
            }
        case Self.selectiveSchemaIdentifier:
            guard value.sourceRevisionIDs != nil else {
                throw analysisGraphFailure("analysis.unsupported-descriptor-version")
            }
        default:
            throw analysisGraphFailure("analysis.unsupported-descriptor-version")
        }
        try self.init(
            artifactTypeIdentifier: value.artifactTypeIdentifier,
            algorithmIdentifier: value.algorithmIdentifier,
            algorithmVersion: value.algorithmVersion,
            corpusIdentifier: value.corpusIdentifier,
            corpusVersionDigest: value.corpusVersionDigest,
            selectionIdentifier: value.selectionIdentifier,
            analyticalUnitIdentifier: value.analyticalUnitIdentifier,
            preprocessingIdentifiers: value.preprocessingIdentifiers,
            linguisticProfileIdentifiers: value.linguisticProfileIdentifiers,
            representationIdentifier: value.representationIdentifier,
            resolvedParameters: value.resolvedParameters,
            seedPolicyIdentifier: value.seedPolicyIdentifier,
            backendIdentifier: value.backendIdentifier,
            numericPolicyIdentifier: value.numericPolicyIdentifier,
            determinismClass: value.determinismClass,
            outputSchemaIdentifier: value.outputSchemaIdentifier,
            softwareIdentifier: value.softwareIdentifier,
            dependencies: value.dependencies,
            sourceRevisionIDs: try value.sourceRevisionIDs?.map {
                try SourceRevisionID(canonicalValue: $0)
            }
        )
    }

    /// Encodes the validated descriptor representation.
    public func encode(to encoder: any Encoder) throws {
        try DescriptorPayload(self).encode(to: encoder)
    }
}

/// Candidate node whose authority is established only by graph validation.
public struct GlifiAnalysisNode: Codable, Equatable, Sendable {
    /// Declared semantic content identity.
    public let id: AnalysisNodeID
    /// Complete descriptor.
    public let descriptor: GlifiAnalysisDescriptor

    /// Creates a node with an identity derived from its descriptor.
    public init(descriptor: GlifiAnalysisDescriptor) throws {
        id = try descriptor.nodeID()
        self.descriptor = descriptor
    }

    private enum CodingKeys: String, CodingKey { case id, descriptor }

    /// Decodes a node and verifies its content identity.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let declaredID = try container.decode(AnalysisNodeID.self, forKey: .id)
        let descriptor = try container.decode(
            GlifiAnalysisDescriptor.self,
            forKey: .descriptor
        )
        guard try descriptor.nodeID() == declaredID else {
            throw analysisGraphFailure("analysis.node-identity-mismatch")
        }
        id = declaredID
        self.descriptor = descriptor
    }

    init(uncheckedID: AnalysisNodeID, descriptor: GlifiAnalysisDescriptor) {
        id = uncheckedID
        self.descriptor = descriptor
    }
}

private struct DescriptorPayload: Codable {
    let schemaIdentifier: String
    let artifactTypeIdentifier: String
    let algorithmIdentifier: String
    let algorithmVersion: String
    let corpusIdentifier: String
    let corpusVersionDigest: String
    let selectionIdentifier: String
    let analyticalUnitIdentifier: String
    let preprocessingIdentifiers: [String]
    let linguisticProfileIdentifiers: [String]
    let representationIdentifier: String
    let resolvedParameters: [String: GlifiAnalysisValue]
    let seedPolicyIdentifier: String
    let backendIdentifier: String
    let numericPolicyIdentifier: String
    let determinismClass: GlifiDeterminismClass
    let outputSchemaIdentifier: String
    let softwareIdentifier: String
    let dependencies: [GlifiAnalysisDependency]
    /// Assente nei descrittori v1, presente in quelli v2.
    let sourceRevisionIDs: [String]?

    init(_ value: GlifiAnalysisDescriptor) {
        schemaIdentifier = value.descriptorSchemaIdentifier
        sourceRevisionIDs = value.sourceRevisionIDs?.map(\.canonicalValue)
        artifactTypeIdentifier = value.artifactTypeIdentifier
        algorithmIdentifier = value.algorithmIdentifier
        algorithmVersion = value.algorithmVersion
        corpusIdentifier = value.corpusIdentifier
        corpusVersionDigest = value.corpusVersionDigest
        selectionIdentifier = value.selectionIdentifier
        analyticalUnitIdentifier = value.analyticalUnitIdentifier
        preprocessingIdentifiers = value.preprocessingIdentifiers
        linguisticProfileIdentifiers = value.linguisticProfileIdentifiers
        representationIdentifier = value.representationIdentifier
        resolvedParameters = value.resolvedParameters
        seedPolicyIdentifier = value.seedPolicyIdentifier
        backendIdentifier = value.backendIdentifier
        numericPolicyIdentifier = value.numericPolicyIdentifier
        determinismClass = value.determinismClass
        outputSchemaIdentifier = value.outputSchemaIdentifier
        softwareIdentifier = value.softwareIdentifier
        dependencies = value.dependencies
    }
}

/// Bounded construction limits for an analysis graph.
public struct GlifiAnalysisGraphLimits: Equatable, Sendable {
    /// Conservative default planning bounds.
    public static let standard = GlifiAnalysisGraphLimits(
        validatedMaximumNodeCount: 10_000,
        maximumEdgeCount: 50_000
    )
    /// Largest admitted node set.
    public let maximumNodeCount: Int
    /// Largest admitted dependency set.
    public let maximumEdgeCount: Int

    /// Creates nonnegative graph bounds without silently correcting values.
    public init(maximumNodeCount: Int, maximumEdgeCount: Int) throws {
        guard maximumNodeCount >= 0, maximumEdgeCount >= 0 else {
            throw analysisGraphFailure("analysis.invalid-graph-limits")
        }
        self.init(
            validatedMaximumNodeCount: maximumNodeCount,
            maximumEdgeCount: maximumEdgeCount
        )
    }

    private init(validatedMaximumNodeCount: Int, maximumEdgeCount: Int) {
        maximumNodeCount = validatedMaximumNodeCount
        self.maximumEdgeCount = maximumEdgeCount
    }
}

/// Integrity state of one immutable analytical artifact reference.
public enum GlifiAnalysisArtifactState: String, Codable, Equatable, Sendable {
    case valid, stale, missing, running, failed, cancelled
}

/// Compact artifact record used to decide safe DAG reuse.
public struct GlifiAnalysisArtifactReference: Codable, Equatable, Sendable {
    /// Producer node.
    public let nodeID: AnalysisNodeID
    /// Digest of the exact descriptor used by the producer.
    public let descriptorDigest: String
    /// Digest of immutable output bytes.
    public let artifactDigest: String
    /// Output schema observed for the artifact.
    public let outputSchemaIdentifier: String
    /// Current verified state.
    public let state: GlifiAnalysisArtifactState

    /// Creates a validated artifact reference.
    public init(
        nodeID: AnalysisNodeID,
        descriptorDigest: String,
        artifactDigest: String,
        outputSchemaIdentifier: String,
        state: GlifiAnalysisArtifactState
    ) throws {
        guard isSHA256Digest(descriptorDigest), isSHA256Digest(artifactDigest),
            !outputSchemaIdentifier.isEmpty
        else { throw analysisGraphFailure("analysis.invalid-artifact-reference") }
        self.nodeID = nodeID
        self.descriptorDigest = descriptorDigest
        self.artifactDigest = artifactDigest
        self.outputSchemaIdentifier = outputSchemaIdentifier
        self.state = state
    }

    private enum CodingKeys: String, CodingKey {
        case nodeID, descriptorDigest, artifactDigest, outputSchemaIdentifier, state
    }

    /// Decodes and validates an artifact reference.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            nodeID: container.decode(AnalysisNodeID.self, forKey: .nodeID),
            descriptorDigest: container.decode(String.self, forKey: .descriptorDigest),
            artifactDigest: container.decode(String.self, forKey: .artifactDigest),
            outputSchemaIdentifier: container.decode(
                String.self,
                forKey: .outputSchemaIdentifier
            ),
            state: container.decode(GlifiAnalysisArtifactState.self, forKey: .state)
        )
    }
}

/// Immutable validated analysis DAG with exact invalidation and reuse queries.
public struct GlifiAnalysisGraph: Codable, Equatable, Sendable {
    /// Nodes ordered by semantic ID.
    public let nodes: [GlifiAnalysisNode]
    /// Stable topological order with semantic-ID tie-breaks.
    public let topologicalNodeIDs: [AnalysisNodeID]

    private let nodeByID: [AnalysisNodeID: GlifiAnalysisNode]
    private let childrenByID: [AnalysisNodeID: [AnalysisNodeID]]

    private enum CodingKeys: String, CodingKey { case nodes }

    /// Deduplicates and validates a bounded candidate graph.
    public init(
        _ candidates: [GlifiAnalysisNode],
        limits: GlifiAnalysisGraphLimits = .standard
    ) throws {
        guard limits.maximumNodeCount >= 0, limits.maximumEdgeCount >= 0,
            candidates.count <= limits.maximumNodeCount
        else {
            throw analysisGraphFailure(
                "analysis.graph-limit-exceeded", category: .insufficientResources)
        }
        var byID: [AnalysisNodeID: GlifiAnalysisNode] = [:]
        for candidate in candidates {
            if let existing = byID[candidate.id] {
                guard existing == candidate else {
                    throw analysisGraphFailure(
                        "analysis.node-id-collision", category: .invariantViolation)
                }
            } else {
                byID[candidate.id] = candidate
            }
        }
        let edgeCount = byID.values.reduce(0) { $0 + $1.descriptor.dependencies.count }
        guard edgeCount <= limits.maximumEdgeCount else {
            throw analysisGraphFailure(
                "analysis.graph-limit-exceeded", category: .insufficientResources)
        }
        var children: [AnalysisNodeID: [AnalysisNodeID]] = [:]
        var indegree = Dictionary(uniqueKeysWithValues: byID.keys.map { ($0, 0) })
        for node in byID.values {
            for dependency in node.descriptor.dependencies {
                guard let parent = byID[dependency.nodeID] else {
                    throw analysisGraphFailure("analysis.missing-dependency")
                }
                guard parent.descriptor.outputSchemaIdentifier == dependency.outputSchemaIdentifier
                else { throw analysisGraphFailure("analysis.dependency-schema-mismatch") }
                children[dependency.nodeID, default: []].append(node.id)
                indegree[node.id, default: 0] += 1
            }
        }
        var ready = AnalysisNodeIDMinHeap(indegree.filter { $0.value == 0 }.map(\.key))
        var order: [AnalysisNodeID] = []
        while let next = ready.removeMinimum() {
            order.append(next)
            for child in children[next, default: []] {
                indegree[child, default: 0] -= 1
                if indegree[child] == 0 {
                    ready.insert(child)
                }
            }
        }
        guard order.count == byID.count else { throw analysisGraphFailure("analysis.cyclic-graph") }
        for node in byID.values {
            guard try node.descriptor.nodeID() == node.id else {
                throw analysisGraphFailure("analysis.node-identity-mismatch")
            }
        }
        nodes = byID.values.sorted { idOrder($0.id, $1.id) }
        topologicalNodeIDs = order
        nodeByID = byID
        childrenByID = children.mapValues { $0.sorted(by: idOrder) }
    }

    /// Decodes and completely revalidates a graph.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(container.decode([GlifiAnalysisNode].self, forKey: .nodes))
    }

    /// Encodes the canonical node set; derived indexes are rebuilt on decode.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
    }

    /// Returns the requested nodes and ancestors in stable topological order.
    public func requiredNodeIDs(for requested: [AnalysisNodeID]) throws -> [AnalysisNodeID] {
        var required = Set<AnalysisNodeID>()
        var pending = requested
        while let next = pending.popLast() {
            guard let node = nodeByID[next] else {
                throw analysisGraphFailure("analysis.node-not-found")
            }
            if required.insert(next).inserted {
                pending.append(contentsOf: node.descriptor.dependencies.map(\.nodeID))
            }
        }
        return topologicalNodeIDs.filter(required.contains)
    }

    /// Returns changed nodes and exactly their transitive descendants.
    public func invalidatedNodeIDs(changing changed: [AnalysisNodeID]) throws -> [AnalysisNodeID] {
        var invalidated = Set<AnalysisNodeID>()
        var pending = changed
        while let next = pending.popLast() {
            guard nodeByID[next] != nil else {
                throw analysisGraphFailure("analysis.node-not-found")
            }
            if invalidated.insert(next).inserted {
                pending.append(contentsOf: childrenByID[next, default: []])
            }
        }
        return topologicalNodeIDs.filter(invalidated.contains)
    }

    /// Returns nodes whose artifact and complete dependency chain remain reusable.
    public func reusableNodeIDs(from artifacts: [GlifiAnalysisArtifactReference]) throws
        -> [AnalysisNodeID]
    {
        var artifactsByNode: [AnalysisNodeID: GlifiAnalysisArtifactReference] = [:]
        for artifact in artifacts {
            guard artifactsByNode.updateValue(artifact, forKey: artifact.nodeID) == nil else {
                throw analysisGraphFailure("analysis.duplicate-artifact")
            }
        }
        var reusable = Set<AnalysisNodeID>()
        for nodeID in topologicalNodeIDs {
            guard let node = nodeByID[nodeID], let artifact = artifactsByNode[nodeID],
                artifact.state == .valid,
                artifact.descriptorDigest == (try node.descriptor.canonicalDigest()),
                artifact.outputSchemaIdentifier == node.descriptor.outputSchemaIdentifier,
                node.descriptor.dependencies.allSatisfy({ dependency in
                    reusable.contains(dependency.nodeID)
                        && artifactsByNode[dependency.nodeID]?.artifactDigest
                            == dependency.artifactDigest
                })
            else { continue }
            reusable.insert(nodeID)
        }
        return topologicalNodeIDs.filter(reusable.contains)
    }

    /// Compares the canonical node set and topological order.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.nodes == rhs.nodes && lhs.topologicalNodeIDs == rhs.topologicalNodeIDs
    }
}

private struct AnalysisNodeIDMinHeap {
    private var elements: [AnalysisNodeID]

    init(_ values: [AnalysisNodeID]) {
        elements = values
        for index in (0..<(elements.count / 2)).reversed() {
            siftDown(from: index)
        }
    }

    mutating func insert(_ value: AnalysisNodeID) {
        elements.append(value)
        var index = elements.count - 1
        while index > 0 {
            let parent = (index - 1) / 2
            guard idOrder(value, elements[parent]) else { break }
            elements[index] = elements[parent]
            index = parent
        }
        elements[index] = value
    }

    mutating func removeMinimum() -> AnalysisNodeID? {
        guard let minimum = elements.first, let last = elements.popLast() else { return nil }
        if !elements.isEmpty {
            elements[0] = last
            siftDown(from: 0)
        }
        return minimum
    }

    private mutating func siftDown(from start: Int) {
        let value = elements[start]
        var index = start
        while index < elements.count / 2 {
            var child = index * 2 + 1
            let right = child + 1
            if right < elements.count, idOrder(elements[right], elements[child]) {
                child = right
            }
            guard idOrder(elements[child], value) else { break }
            elements[index] = elements[child]
            index = child
        }
        elements[index] = value
    }
}

private func canonical(_ value: String) -> String { value.precomposedStringWithCanonicalMapping }
private func idOrder(_ lhs: AnalysisNodeID, _ rhs: AnalysisNodeID) -> Bool {
    lhs.digest < rhs.digest
}
func isSHA256Digest(_ value: String) -> Bool {
    isCanonicalSHA256Digest(value)
}
private func digest(of value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let hash = SHA256.hash(data: try encoder.encode(value))
    return canonicalSHA256Digest(hash)
}
private func analysisGraphFailure(_ code: String, category: GlifiFailureCategory = .invalidInput)
    -> GlifiFailure
{
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category), messageKey: "failure.\(code)"
    )
}
