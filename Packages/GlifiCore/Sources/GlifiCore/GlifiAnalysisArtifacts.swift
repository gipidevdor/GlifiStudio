// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// A versioned analytical payload whose schema must match its descriptor.
public protocol GlifiAnalysisArtifactPayload: Codable, Sendable {
    /// Stable output schema recorded by the producer descriptor.
    static var outputSchemaIdentifier: String { get }
}

/// Canonical persisted payload for `corpus-profile-it-v1`.
public struct GlifiCorpusAnalysisArtifactPayload:
    GlifiAnalysisArtifactPayload, Equatable, Sendable
{
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-profile.v1"
    /// Current payload schema version.
    public static let schemaVersion = 1

    /// Stable schema serialized with the payload.
    public let schemaIdentifier: String
    /// Version serialized with the payload.
    public let schemaVersion: Int
    /// Semantic producer identity bound into the immutable payload.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic analytical result.
    public let analysis: GlifiCorpusAnalysis

    /// Creates the canonical payload for a verified corpus analysis.
    public init(analysisNodeID: AnalysisNodeID, analysis: GlifiCorpusAnalysis) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = Self.schemaVersion
        self.analysisNodeID = analysisNodeID
        self.analysis = analysis
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, analysisNodeID, analysis
    }

    /// Decodes only the supported schema and analytical family.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let analysisNodeID = try container.decode(AnalysisNodeID.self, forKey: .analysisNodeID)
        let analysis = try container.decode(GlifiCorpusAnalysis.self, forKey: .analysis)
        guard schemaIdentifier == Self.outputSchemaIdentifier,
            schemaVersion == Self.schemaVersion,
            analysis.analysisIdentifier == GlifiCorpusAnalyzer.analysisIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported corpus-analysis artifact payload"
            )
        }
        self.schemaIdentifier = schemaIdentifier
        self.schemaVersion = schemaVersion
        self.analysisNodeID = analysisNodeID
        self.analysis = analysis
    }
}

/// Canonical persisted payload for `keyness-gtest-fisher-ha-ci-bh-v2`.
public struct GlifiKeynessArtifactPayload: GlifiAnalysisArtifactPayload, Equatable, Sendable {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.keyness.v2"
    /// Current payload schema version.
    public static let schemaVersion = 1

    /// Stable schema serialized with the payload.
    public let schemaIdentifier: String
    /// Version serialized with the payload.
    public let schemaVersion: Int
    /// Semantic producer identity bound into the immutable payload.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic multiple-comparison result.
    public let comparison: GlifiKeynessComparison

    /// Creates the canonical payload for a verified keyness comparison.
    public init(analysisNodeID: AnalysisNodeID, comparison: GlifiKeynessComparison) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = Self.schemaVersion
        self.analysisNodeID = analysisNodeID
        self.comparison = comparison
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, analysisNodeID, comparison
    }

    /// Decodes only the supported schema and analytical family.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let analysisNodeID = try container.decode(AnalysisNodeID.self, forKey: .analysisNodeID)
        let comparison = try container.decode(GlifiKeynessComparison.self, forKey: .comparison)
        guard schemaIdentifier == Self.outputSchemaIdentifier,
            schemaVersion == Self.schemaVersion,
            comparison.comparisonIdentifier == GlifiKeynessAnalyzer.comparisonIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported keyness artifact payload"
            )
        }
        self.schemaIdentifier = schemaIdentifier
        self.schemaVersion = schemaVersion
        self.analysisNodeID = analysisNodeID
        self.comparison = comparison
    }
}

/// Canonical persisted payload for `corpus-term-similarity-v3`.
public struct GlifiCorpusSimilarityArtifactPayload:
    GlifiAnalysisArtifactPayload, Equatable, Sendable
{
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-similarity.v2"
    /// Current payload schema version.
    public static let schemaVersion = 1

    /// Stable schema serialized with the payload.
    public let schemaIdentifier: String
    /// Version serialized with the payload.
    public let schemaVersion: Int
    /// Semantic producer identity bound into the immutable payload.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic corpus-similarity result.
    public let comparison: GlifiCorpusSimilarityComparison

    /// Creates the canonical payload for a verified similarity comparison.
    public init(analysisNodeID: AnalysisNodeID, comparison: GlifiCorpusSimilarityComparison) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = Self.schemaVersion
        self.analysisNodeID = analysisNodeID
        self.comparison = comparison
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, analysisNodeID, comparison
    }

    /// Decodes only the supported schema and analytical family.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let analysisNodeID = try container.decode(AnalysisNodeID.self, forKey: .analysisNodeID)
        let comparison = try container.decode(
            GlifiCorpusSimilarityComparison.self,
            forKey: .comparison
        )
        guard schemaIdentifier == Self.outputSchemaIdentifier,
            schemaVersion == Self.schemaVersion,
            comparison.comparisonIdentifier == GlifiCorpusSimilarityAnalyzer.comparisonIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported corpus-similarity artifact payload"
            )
        }
        self.schemaIdentifier = schemaIdentifier
        self.schemaVersion = schemaVersion
        self.analysisNodeID = analysisNodeID
        self.comparison = comparison
    }
}

/// Canonical persisted payload for `planner-mvp-v1`.
public struct GlifiAnalysisPlanArtifactPayload:
    GlifiAnalysisArtifactPayload, Equatable, Sendable
{
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.analysis-plan.v1"
    /// Current payload schema version.
    public static let schemaVersion = 1

    /// Stable schema serialized with the payload.
    public let schemaIdentifier: String
    /// Version serialized with the payload.
    public let schemaVersion: Int
    /// Semantic producer identity serialized with the plan.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic planner result.
    public let plan: GlifiAnalysisPlan

    /// Creates a payload bound to the semantic plan node.
    public init(analysisNodeID: AnalysisNodeID, plan: GlifiAnalysisPlan) {
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = Self.schemaVersion
        self.analysisNodeID = analysisNodeID
        self.plan = plan
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, analysisNodeID, plan
    }

    /// Decodes only the current planner and capability-catalog contract.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let analysisNodeID = try container.decode(AnalysisNodeID.self, forKey: .analysisNodeID)
        let plan = try container.decode(GlifiAnalysisPlan.self, forKey: .plan)
        guard schemaIdentifier == Self.outputSchemaIdentifier,
            schemaVersion == Self.schemaVersion,
            plan.plannerIdentifier == GlifiAnalysisPlanner.plannerIdentifier,
            plan.capabilityCatalogIdentifier
                == GlifiAnalysisPlanner.capabilityCatalogIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported analysis-plan artifact payload"
            )
        }
        self.schemaIdentifier = schemaIdentifier
        self.schemaVersion = schemaVersion
        self.analysisNodeID = analysisNodeID
        self.plan = plan
    }
}

enum GlifiArtifactCanonicalJSON {
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

enum GlifiAnalysisArtifactDescriptorFactory {
    static func analysisPlan(
        projectID: ProjectID,
        sourceRootDigest: String,
        tokenizationContractIdentifier: String,
        plan: GlifiAnalysisPlan
    ) throws -> GlifiAnalysisDescriptor {
        let roleAwareSelection =
            plan.resolvedScopeSourceRevisionIDs.map { "scope:\($0.canonicalValue)" }
            + plan.targetSourceRevisionIDs.map { "target:\($0.canonicalValue)" }
            + plan.referenceSourceRevisionIDs.map { "reference:\($0.canonicalValue)" }
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.analysis-plan",
            algorithmIdentifier: GlifiAnalysisPlanner.plannerIdentifier,
            algorithmVersion: "2",
            corpusIdentifier: projectID.canonicalValue,
            corpusVersionDigest: sourceRootDigest,
            selectionIdentifier: try selectionIdentifier(
                domain: "analysis-plan-request.v1",
                values: roleAwareSelection
            ),
            analyticalUnitIdentifier: "analysis-plan-revision.v1",
            preprocessingIdentifiers: [plan.collectionProfile.profileIdentifier],
            linguisticProfileIdentifiers: [
                plan.collectionProfile.configuredLanguageCode,
                tokenizationContractIdentifier,
            ],
            representationIdentifier: "analysis-plan-with-rationale.v1",
            resolvedParameters: [
                "capabilityCatalogIdentifier": .text(plan.capabilityCatalogIdentifier),
                "intent": .text(plan.intent.rawValue),
                "maximumEstimatedWorkUnits": .integer(plan.maximumEstimatedWorkUnits),
                "plannerIdentifier": .text(plan.plannerIdentifier),
                "referenceSourceRevisionIDs": .list(
                    plan.referenceSourceRevisionIDs.map { .text($0.canonicalValue) }
                ),
                "targetSourceRevisionIDs": .list(
                    plan.targetSourceRevisionIDs.map { .text($0.canonicalValue) }
                ),
            ],
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "integer-saturating-rejected-overflow-v1",
            determinismClass: .d0,
            outputSchemaIdentifier: GlifiAnalysisPlanArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0",
            dependencies: []
        )
    }

    static func corpusProfile(
        snapshot: GlifiProjectSnapshot,
        sourceRevisionIDs: [SourceRevisionID],
        tokenizationContractIdentifier: String,
        options: GlifiCorpusAnalysisOptions
    ) throws -> GlifiAnalysisDescriptor {
        try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.corpus-profile",
            algorithmIdentifier: GlifiCorpusAnalyzer.analysisIdentifier,
            algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: try snapshot.corpusVersionDigest(for: sourceRevisionIDs),
            selectionIdentifier: try selectionIdentifier(
                domain: "source-revisions.v1",
                values: sourceRevisionIDs.sorted {
                    $0.canonicalValue < $1.canonicalValue
                }.map(\.canonicalValue)
            ),
            analyticalUnitIdentifier: "source-revision.v1",
            preprocessingIdentifiers: ["source-extraction-contract-from-input-v1"],
            linguisticProfileIdentifiers: [
                tokenizationContractIdentifier,
                "nfc-lowercase-it-v1",
            ],
            representationIdentifier: "corpus-profile-table-and-sparse-matrix-v1",
            resolvedParameters: [
                "diversityWindowSize": .integer(Int64(options.diversityWindowSize)),
                "ngramSizes": .list(options.ngramSizes.map { .integer(Int64($0)) }),
            ],
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            determinismClass: .d1,
            outputSchemaIdentifier: GlifiCorpusAnalysisArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0",
            dependencies: [],
            sourceRevisionIDs: sourceRevisionIDs
        )
    }

    static func keyness(
        snapshot: GlifiProjectSnapshot,
        targetSourceRevisionIDs: [SourceRevisionID],
        referenceSourceRevisionIDs: [SourceRevisionID],
        linguisticProfileIdentifiers: [String],
        options: GlifiKeynessOptions,
        dependencies: [GlifiAnalysisDependency]
    ) throws -> GlifiAnalysisDescriptor {
        let targetSelection = targetSourceRevisionIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }.map { "target:\($0.canonicalValue)" }
        let referenceSelection = referenceSourceRevisionIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }.map { "reference:\($0.canonicalValue)" }
        let roleAwareSelection = targetSelection + referenceSelection
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.keyness",
            algorithmIdentifier: GlifiKeynessAnalyzer.comparisonIdentifier,
            algorithmVersion: "2",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: try snapshot.corpusVersionDigest(
                for: targetSourceRevisionIDs + referenceSourceRevisionIDs),
            selectionIdentifier: try selectionIdentifier(
                domain: "keyness-groups.v1",
                values: roleAwareSelection
            ),
            analyticalUnitIdentifier: "normalized-term.v1",
            preprocessingIdentifiers: ["corpus-profile-it-v1"],
            linguisticProfileIdentifiers: linguisticProfileIdentifiers,
            representationIdentifier: "keyness-multiple-comparison-table-v1",
            resolvedParameters: [
                "confidenceLevel": .decimal(options.confidenceLevel),
                "lowExpectedCountThreshold": .decimal(options.lowExpectedCountThreshold),
            ],
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            determinismClass: .d1,
            outputSchemaIdentifier: GlifiKeynessArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0",
            dependencies: dependencies,
            sourceRevisionIDs: targetSourceRevisionIDs + referenceSourceRevisionIDs
        )
    }

    static func corpusSimilarity(
        snapshot: GlifiProjectSnapshot,
        targetSourceRevisionIDs: [SourceRevisionID],
        referenceSourceRevisionIDs: [SourceRevisionID],
        linguisticProfileIdentifiers: [String],
        dependencies: [GlifiAnalysisDependency]
    ) throws -> GlifiAnalysisDescriptor {
        let targetSelection = targetSourceRevisionIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }.map { "target:\($0.canonicalValue)" }
        let referenceSelection = referenceSourceRevisionIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }.map { "reference:\($0.canonicalValue)" }
        let roleAwareSelection = targetSelection + referenceSelection
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.corpus-similarity",
            algorithmIdentifier: GlifiCorpusSimilarityAnalyzer.comparisonIdentifier,
            algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: try snapshot.corpusVersionDigest(
                for: targetSourceRevisionIDs + referenceSourceRevisionIDs),
            selectionIdentifier: try selectionIdentifier(
                domain: "similarity-groups.v1",
                values: roleAwareSelection
            ),
            analyticalUnitIdentifier: "normalized-term.v1",
            preprocessingIdentifiers: ["corpus-profile-it-v1"],
            linguisticProfileIdentifiers: linguisticProfileIdentifiers,
            representationIdentifier: GlifiCorpusSimilarityAnalyzer.vocabularyIdentifier,
            resolvedParameters: [:],
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            determinismClass: .d1,
            outputSchemaIdentifier: GlifiCorpusSimilarityArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0",
            dependencies: dependencies,
            sourceRevisionIDs: targetSourceRevisionIDs + referenceSourceRevisionIDs
        )
    }

    static func interpretation(
        projectID: ProjectID,
        sourceRootDigest: String,
        plan: GlifiAnalysisPlan,
        options: GlifiInterpretationOptions,
        dependencies: [GlifiAnalysisDependency]
    ) throws -> GlifiAnalysisDescriptor {
        try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.interpretation",
            algorithmIdentifier: GlifiInterpretationEngine.ruleCatalogIdentifier,
            algorithmVersion: "1",
            corpusIdentifier: projectID.canonicalValue,
            corpusVersionDigest: sourceRootDigest,
            selectionIdentifier: try selectionIdentifier(
                domain: "analysis-plan-artifacts.v1",
                values: dependencies.map {
                    "\($0.nodeID.canonicalValue):\($0.artifactDigest)"
                }.sorted()
            ),
            analyticalUnitIdentifier: "evidence-finding-caveat.v1",
            preprocessingIdentifiers: [plan.plannerIdentifier],
            linguisticProfileIdentifiers: [
                plan.collectionProfile.configuredLanguageCode
            ],
            representationIdentifier: "structured-localizable-explanation.v1",
            resolvedParameters: [
                "intent": .text(plan.intent.rawValue),
                "maximumFindingCount": .integer(Int64(options.maximumFindingCount)),
                "moderateMaximumQValue": .decimal(options.moderateMaximumQValue),
                "moderateMinimumAbsoluteLog2Ratio": .decimal(
                    options.moderateMinimumAbsoluteLog2Ratio
                ),
                "rankingIdentifier": .text(GlifiInterpretationEngine.rankingIdentifier),
                "strongMaximumQValue": .decimal(options.strongMaximumQValue),
                "strongMinimumAbsoluteLog2Ratio": .decimal(
                    options.strongMinimumAbsoluteLog2Ratio
                ),
            ],
            seedPolicyIdentifier: "none-v1",
            backendIdentifier: "swift-reference-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-comparison-v1",
            determinismClass: .d0,
            outputSchemaIdentifier:
                GlifiAnalysisInterpretationArtifactPayload.outputSchemaIdentifier,
            softwareIdentifier: "GlifiCore-0.1.0",
            dependencies: dependencies
        )
    }

    static func selectionIdentifier(domain: String, values: [String]) throws -> String {
        struct Selection: Encodable {
            let domain: String
            let values: [String]
        }
        let data = try GlifiArtifactCanonicalJSON.encode(
            Selection(domain: domain, values: values)
        )
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return "\(domain):sha256:\(digest)"
    }
}
