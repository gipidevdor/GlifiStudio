// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Epistemic category retained by evidence and deterministic interpretations.
public enum GlifiEpistemicCategory: String, Codable, Equatable, Sendable {
    /// Value read directly from an authoritative input.
    case observed
    /// Value produced by a declared reversible or derivational transformation.
    case transformed
    /// Quantity estimated from observed data.
    case estimated
    /// Quantity or relation inferred by a declared analytical method.
    case inferred
    /// Human or automated annotation with explicit authorship.
    case annotated
    /// Non-authoritative generated material.
    case generative
    /// Proposition emitted by a deterministic interpretation rule.
    case deterministicallyInterpreted
}

/// Family-specific support category that is never a universal confidence score.
public enum GlifiSupportClass: String, Codable, Equatable, Sendable {
    /// Complete descriptive lineage without an inferential strength claim.
    case descriptive
    /// Strong support according to the named family policy.
    case strong
    /// Moderate support according to the named family policy.
    case moderate
    /// Weak but still eligible support according to the named family policy.
    case weak
    /// Eligible conclusion requiring a visible methodological caution.
    case caution
    /// Evidence does not authorize a positive conclusion.
    case insufficient
}

/// Lifecycle state of one immutable finding revision.
public enum GlifiFindingState: String, Codable, Equatable, Sendable {
    /// Deterministic candidate not yet selected editorially.
    case candidate
    /// Candidate satisfying its family-specific support policy.
    case supported
    /// Candidate deliberately excluded with a structured reason.
    case suppressed
    /// Outcome for which no positive proposition is defensible.
    case insufficient
    /// Finding selected for a report revision.
    case included
    /// Older immutable revision replaced by a newer finding revision.
    case superseded
}

/// Severity of a structured caveat.
public enum GlifiCaveatSeverity: String, Codable, Equatable, Sendable {
    /// Context that does not weaken the represented proposition.
    case information
    /// Limitation that must accompany interpretation.
    case warning
    /// Limitation that prevents publication of a positive proposition.
    case blocking
}

/// Smallest semantic scope affected by a caveat.
public enum GlifiCaveatScope: String, Codable, Equatable, Sendable {
    /// Caveat attached to an analytical artifact.
    case artifact
    /// Caveat attached to one evidence record.
    case evidence
    /// Caveat attached to one finding revision.
    case finding
    /// Caveat attached to the complete interpretation result.
    case interpretation
}

/// Validity state of one evidence record.
public enum GlifiEvidenceValidity: String, Codable, Equatable, Sendable {
    /// Evidence satisfies every declared rule precondition.
    case valid
    /// Evidence remains inspectable but carries a methodological limitation.
    case limited
}

/// Relationship between a finding and one considered evidence record.
public enum GlifiFindingEvidenceDisposition: String, Codable, Equatable, Sendable {
    /// Evidence supports the emitted proposition.
    case supporting
    /// Evidence contradicts the emitted proposition.
    case contrary
    /// Evidence was considered but excluded for the recorded reason.
    case excluded
}

/// Canonical scalar used by evidence measures without unit ambiguity.
public enum GlifiEvidenceValue: Codable, Equatable, Sendable {
    /// Exact signed integer.
    case integer(Int64)
    /// Finite IEEE-754 binary64 value.
    case decimal(Double)
    /// NFC text value.
    case text(String)
    /// Boolean value.
    case boolean(Bool)

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum Kind: String, Codable { case integer, decimal, text, boolean }

    /// Decodes one explicitly tagged scalar and rejects non-finite numbers.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .integer:
            self = .integer(try container.decode(Int64.self, forKey: .value))
        case .decimal:
            let value = try container.decode(Double.self, forKey: .value)
            guard value.isFinite else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value,
                    in: container,
                    debugDescription: "Evidence decimals must be finite"
                )
            }
            self = .decimal(value == 0 ? 0 : value)
        case .text:
            self = .text(
                try container.decode(String.self, forKey: .value)
                    .precomposedStringWithCanonicalMapping
            )
        case .boolean:
            self = .boolean(try container.decode(Bool.self, forKey: .value))
        }
    }

    /// Encodes one scalar with an explicit stable type tag.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .integer(value):
            try container.encode(Kind.integer, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .decimal(value):
            guard value.isFinite else {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "Evidence decimals must be finite"
                    )
                )
            }
            try container.encode(Kind.decimal, forKey: .type)
            try container.encode(value == 0 ? 0 : value, forKey: .value)
        case let .text(value):
            try container.encode(Kind.text, forKey: .type)
            try container.encode(value.precomposedStringWithCanonicalMapping, forKey: .value)
        case let .boolean(value):
            try container.encode(Kind.boolean, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

/// One typed quantity retained by evidence, assessment, or ranking.
public struct GlifiEvidenceMeasure: Codable, Equatable, Sendable {
    /// Stable semantic quantity identifier.
    public let identifier: String
    /// Exact canonical scalar.
    public let value: GlifiEvidenceValue
    /// Stable unit identifier, absent for dimensionless quantities.
    public let unitIdentifier: String?
}

/// Exact source revision and region supporting one evidence record.
public struct GlifiSourceReference: Codable, Equatable, Sendable {
    /// Immutable source revision identity.
    public let sourceRevisionID: SourceRevisionID
    /// Semantic role of this source in the analysis.
    public let roleIdentifier: String
    /// Versioned representation coordinate space.
    public let representationIdentifier: String
    /// Versioned whole-region or selection contract.
    public let regionIdentifier: String
    /// Optional exact source-byte intervals; empty denotes the declared whole region.
    public let ranges: [GlifiUTF8Range]
}

/// Structured limitation that can be propagated without weakening its severity.
public struct GlifiCaveat: Codable, Equatable, Sendable {
    /// Stable caveat type.
    public let identifier: String
    /// Non-decreasing severity.
    public let severity: GlifiCaveatSeverity
    /// Smallest affected semantic scope.
    public let scope: GlifiCaveatScope
    /// Stable cause identifier.
    public let causeIdentifier: String
    /// Stable consequence identifier.
    public let consequenceIdentifier: String
    /// Optional stable remediation or next-action identifier.
    public let actionIdentifier: String?
    /// Rule, artifact, or policy that originated this caveat.
    public let originIdentifier: String
}

/// Immutable, content-addressed observation derived from analytical artifacts.
public struct GlifiEvidence: Codable, Equatable, Sendable {
    /// Content identity of the complete evidence record.
    public let id: EvidenceID
    /// Stable evidence family.
    public let kindIdentifier: String
    /// Immutable artifacts actually used by this observation.
    public let artifactIDs: [ArtifactID]
    /// Semantic producer whose descriptor defines the method.
    public let analysisNodeID: AnalysisNodeID
    /// Digest of the complete producer descriptor.
    public let descriptorDigest: String
    /// Ordered method identities required to reproduce the observation.
    public let methodIdentifiers: [String]
    /// Structured quantities in stable identifier order.
    public let measures: [GlifiEvidenceMeasure]
    /// Explicit uncertainty contracts, empty only when not applicable.
    public let uncertaintyIdentifiers: [String]
    /// Explicit effect-size contracts, empty only when not applicable.
    public let effectSizeIdentifiers: [String]
    /// Exact immutable source revisions or regions supporting the observation.
    public let sourceReferences: [GlifiSourceReference]
    /// Epistemic class retained from the analytical procedure.
    public let epistemicCategory: GlifiEpistemicCategory
    /// Whether the evidence is fully valid or methodologically limited.
    public let validity: GlifiEvidenceValidity
    /// Structured limitations in stable identifier order.
    public let caveats: [GlifiCaveat]
}

/// One policy dimension retained instead of collapsing support into a percentage.
public struct GlifiEvidenceAssessmentDimension: Codable, Equatable, Sendable {
    /// Stable dimension identifier.
    public let identifier: String
    /// Observed or derived value used by the policy.
    public let value: GlifiEvidenceValue
    /// Stable outcome of evaluating this dimension.
    public let outcomeIdentifier: String
}

/// Family-specific support decision with all determining dimensions preserved.
public struct GlifiEvidenceAssessment: Codable, Equatable, Sendable {
    /// Exact support-policy identity and version.
    public let policyIdentifier: String
    /// Category meaningful only within the named policy.
    public let supportClass: GlifiSupportClass
    /// Ordered evaluated dimensions.
    public let dimensions: [GlifiEvidenceAssessmentDimension]
    /// Stable rationale codes.
    public let rationaleIdentifiers: [String]
}

/// One evidence item considered by a deterministic finding rule.
public struct GlifiFindingEvidenceReference: Codable, Equatable, Sendable {
    /// Content identity of the considered evidence.
    public let evidenceID: EvidenceID
    /// Supporting, contrary, or excluded relationship.
    public let disposition: GlifiFindingEvidenceDisposition
    /// Stable reason, required for non-supporting dispositions.
    public let reasonIdentifier: String?
}

/// Comparable dimensions used by `editorial-rank-v1` within one family.
public struct GlifiEditorialRankFactors: Codable, Equatable, Sendable {
    /// Stable ranking policy.
    public let rankingIdentifier: String
    /// Relevance declared for the requested intent.
    public let intentRelevance: Int
    /// Family-specific support class.
    public let supportClass: GlifiSupportClass
    /// Appropriate absolute effect magnitude, absent when not applicable.
    public let effectMagnitude: Double?
    /// Coverage or data-quality dimension, absent when unavailable.
    public let coverage: Double?
    /// Stability dimension, absent when not measured.
    public let stability: Double?
    /// Novelty dimension, absent before editorial history exists.
    public let novelty: Double?
    /// Non-redundancy dimension within the emitted family.
    public let nonRedundancy: Double
    /// Whether every required lineage edge resolves.
    public let hasCompleteLineage: Bool
}

/// Immutable deterministic proposition supported by one or more evidence records.
public struct GlifiFinding: Codable, Equatable, Sendable {
    /// Content identity of this exact finding revision.
    public let id: FindingID
    /// Family within which editorial ranking is meaningful.
    public let familyIdentifier: String
    /// Stable proposition type.
    public let typeIdentifier: String
    /// Stable structured subject.
    public let subjectIdentifier: String
    /// Stable predicate that never implies unsupported causality.
    public let predicateIdentifier: String
    /// Stable structured object or value identifier.
    public let objectIdentifier: String
    /// Exact analytical scope.
    public let scopeIdentifier: String
    /// Direction when applicable.
    public let directionIdentifier: String?
    /// Current immutable lifecycle state.
    public let state: GlifiFindingState
    /// Evidence considered by the rule.
    public let evidenceReferences: [GlifiFindingEvidenceReference]
    /// Family-specific support assessment.
    public let assessment: GlifiEvidenceAssessment
    /// Structured limitations retained by the proposition.
    public let caveats: [GlifiCaveat]
    /// Exact interpretation rule-set identity and version.
    public let ruleSetIdentifier: String
    /// Semantic localization key; localized text is not identity.
    public let messageKey: String
    /// Non-sensitive semantic localization arguments.
    public let messageArguments: [String: String]
    /// Deterministic editorial dimensions; array position is the resolved rank.
    public let rankFactors: GlifiEditorialRankFactors
    /// Finding propositions are deterministic interpretations, not observations.
    public let epistemicCategory: GlifiEpistemicCategory
}

/// Counted reason for alternatives not emitted by the bounded interpreter.
public struct GlifiSuppressionSummary: Codable, Equatable, Sendable {
    /// Stable suppression reason.
    public let reasonIdentifier: String
    /// Exact number of alternatives suppressed for this reason.
    public let count: Int
}

/// Valid result explaining why no positive finding can be emitted.
public struct GlifiInsufficientEvidenceOutcome: Codable, Equatable, Sendable {
    /// Stable non-empty reasons.
    public let reasonIdentifiers: [String]
    /// Structured blocking or warning limitations.
    public let caveats: [GlifiCaveat]
    /// Semantic localization key.
    public let messageKey: String
    /// Non-sensitive semantic localization arguments.
    public let messageArguments: [String: String]
}

/// Complete bounded Evidence/Finding/Caveat result for one immutable plan execution.
public struct GlifiAnalysisInterpretation: Codable, Equatable, Sendable {
    /// Exact deterministic rule catalog.
    public let ruleCatalogIdentifier: String
    /// Exact editorial-ranking contract.
    public let rankingIdentifier: String
    /// Analytical intent interpreted by this result.
    public let intent: GlifiAnalyticalIntent
    /// Persisted plan that governed every source artifact.
    public let planArtifactID: ArtifactID
    /// Semantic plan node identity.
    public let planAnalysisNodeID: AnalysisNodeID
    /// Canonically ordered plan-output artifacts considered by the rules.
    public let sourceArtifactIDs: [ArtifactID]
    /// Evidence in the same order as ranked findings.
    public let evidence: [GlifiEvidence]
    /// Eligible positive findings ordered by `editorial-rank-v1`.
    public let findings: [GlifiFinding]
    /// Bounded aggregate reasons for alternatives not emitted.
    public let suppressionSummaries: [GlifiSuppressionSummary]
    /// Present exactly when no positive finding is defensible.
    public let insufficientEvidence: GlifiInsufficientEvidenceOutcome?
}

/// Bounded policy parameters for the first deterministic interpretation slice.
public struct GlifiInterpretationOptions: Equatable, Sendable {
    /// Conservative fixed policy used by the 0.1 implementation.
    public static let standard = GlifiInterpretationOptions(
        validatedMaximumFindingCount: 100,
        moderateMaximumQValue: 0.05,
        strongMaximumQValue: 0.01,
        moderateMinimumAbsoluteLog2Ratio: 1,
        strongMinimumAbsoluteLog2Ratio: 2
    )

    /// Largest materialized finding/evidence set.
    public let maximumFindingCount: Int
    /// Largest adjusted q-value admitted as moderate support.
    public let moderateMaximumQValue: Double
    /// Largest adjusted q-value admitted as strong support.
    public let strongMaximumQValue: Double
    /// Smallest absolute log2 ratio admitted as moderate support.
    public let moderateMinimumAbsoluteLog2Ratio: Double
    /// Smallest absolute log2 ratio admitted as strong support.
    public let strongMinimumAbsoluteLog2Ratio: Double

    /// Creates a valid monotonic family policy without silently correcting values.
    public init(
        maximumFindingCount: Int,
        moderateMaximumQValue: Double,
        strongMaximumQValue: Double,
        moderateMinimumAbsoluteLog2Ratio: Double,
        strongMinimumAbsoluteLog2Ratio: Double
    ) throws {
        guard maximumFindingCount > 0,
            moderateMaximumQValue.isFinite,
            strongMaximumQValue.isFinite,
            (0...1).contains(moderateMaximumQValue),
            (0...moderateMaximumQValue).contains(strongMaximumQValue),
            moderateMinimumAbsoluteLog2Ratio.isFinite,
            strongMinimumAbsoluteLog2Ratio.isFinite,
            moderateMinimumAbsoluteLog2Ratio >= 0,
            strongMinimumAbsoluteLog2Ratio >= moderateMinimumAbsoluteLog2Ratio
        else {
            throw interpretationFailure(
                "interpretation.invalid-options",
                category: .invalidInput
            )
        }
        self.init(
            validatedMaximumFindingCount: maximumFindingCount,
            moderateMaximumQValue: moderateMaximumQValue,
            strongMaximumQValue: strongMaximumQValue,
            moderateMinimumAbsoluteLog2Ratio: moderateMinimumAbsoluteLog2Ratio,
            strongMinimumAbsoluteLog2Ratio: strongMinimumAbsoluteLog2Ratio
        )
    }

    private init(
        validatedMaximumFindingCount: Int,
        moderateMaximumQValue: Double,
        strongMaximumQValue: Double,
        moderateMinimumAbsoluteLog2Ratio: Double,
        strongMinimumAbsoluteLog2Ratio: Double
    ) {
        maximumFindingCount = validatedMaximumFindingCount
        self.moderateMaximumQValue = moderateMaximumQValue
        self.strongMaximumQValue = strongMaximumQValue
        self.moderateMinimumAbsoluteLog2Ratio = moderateMinimumAbsoluteLog2Ratio
        self.strongMinimumAbsoluteLog2Ratio = strongMinimumAbsoluteLog2Ratio
    }
}

/// Typed analytical content consumed by deterministic interpretation rules.
public enum GlifiInterpretationArtifactContent: Sendable {
    /// Descriptive corpus profile.
    case corpusProfile(GlifiCorpusAnalysis)
    /// Two-group keyness comparison.
    case keyness(GlifiKeynessComparison)
    /// Verified output of an ADR-0025 capability with the facts its ADR-0026 policy needs.
    case supplementary(
        outputSchemaIdentifier: String,
        sourceRevisionIDs: [SourceRevisionID],
        facts: GlifiSupplementaryFacts
    )
}

/// One collocation pair considered by `support-policy.collocation-tscore-npmi-v1`.
public struct GlifiCollocationFact: Equatable, Sendable {
    /// Node term.
    public let node: String
    /// Collocate term.
    public let collocate: String
    /// Joint count `a`.
    public let jointCount: Int
    /// `t-score-v1`.
    public let tScore: Double?
    /// `NPMI-v1`.
    public let npmi: Double?
    /// `logDice-v1`.
    public let logDice: Double?

    /// Creates one pair fact.
    public init(
        node: String,
        collocate: String,
        jointCount: Int,
        tScore: Double?,
        npmi: Double?,
        logDice: Double?
    ) {
        self.node = node
        self.collocate = collocate
        self.jointCount = jointCount
        self.tScore = tScore
        self.npmi = npmi
        self.logDice = logDice
    }
}

/// Family-specific facts extracted from an ADR-0025 payload for its ADR-0026 policy.
public enum GlifiSupplementaryFacts: Equatable, Sendable {
    /// Document × term association.
    case association(
        cramersV: Double,
        minimumDimension: Int,
        monteCarloPValue: Double?,
        lowExpectedCellFraction: Double
    )
    /// Location comparison of a document metric between two groups.
    case groupLocation(
        metricIdentifier: String,
        hedgesG: Double?,
        pValue: Double?,
        smallestGroupSize: Int
    )
    /// Window collocations in declared order.
    case collocations([GlifiCollocationFact])
    /// Community structure of a lexical network.
    case network(modularity: Double?, communityCount: Int?, nodeCount: Int)
    /// Principal inertias of a Correspondence Analysis.
    case correspondence(inertias: [Double], totalInertia: Double)
    /// Cluster structure of the documents.
    case clustering(clusterCount: Int, averageSilhouette: Double?, smallestClusterSize: Int)
    /// Similarity between two groups (descriptive only).
    case similarity(sharedTypeCount: Int, cosine: Double, jsDistance: Double)
}

/// Verified plan-step artifact supplied to the pure interpretation engine.
public struct GlifiInterpretationArtifactInput: Sendable {
    /// Stable plan-step identity.
    public let planStepIdentifier: String
    /// Semantic role selected by the planner.
    public let role: GlifiAnalysisPlanStepRole
    /// Immutable artifact identity.
    public let artifactID: ArtifactID
    /// Semantic producer identity.
    public let analysisNodeID: AnalysisNodeID
    /// Complete descriptor digest.
    public let descriptorDigest: String
    /// Decoded payload validated against the descriptor schema.
    public let content: GlifiInterpretationArtifactContent

    /// Creates one already verified interpretation input.
    public init(
        planStepIdentifier: String,
        role: GlifiAnalysisPlanStepRole,
        artifactID: ArtifactID,
        analysisNodeID: AnalysisNodeID,
        descriptorDigest: String,
        content: GlifiInterpretationArtifactContent
    ) {
        self.planStepIdentifier = planStepIdentifier
        self.role = role
        self.artifactID = artifactID
        self.analysisNodeID = analysisNodeID
        self.descriptorDigest = descriptorDigest
        self.content = content
    }
}

/// Pure bounded interpreter for the descriptive and keyness MVP families.
public struct GlifiInterpretationEngine: Sendable {
    /// Exact deterministic rule catalog.
    public static let ruleCatalogIdentifier = "interpretation-rules-mvp-v1"
    /// Exact within-family ranking policy.
    public static let rankingIdentifier = "editorial-rank-v1"
    /// Descriptive completeness policy without inferential strength.
    public static let descriptiveSupportPolicyIdentifier =
        "support-policy.descriptive-completeness-v1"
    /// Fixed product policy for G-test/BH keyness findings.
    public static let keynessSupportPolicyIdentifier = "support-policy.keyness-gtest-bh-v1"

    /// Creates one stateless interpreter.
    public init() {}

    /// Produces deterministic Evidence/Finding/Caveat structures from verified artifacts.
    public func interpret(
        planArtifactID: ArtifactID,
        planAnalysisNodeID: AnalysisNodeID,
        plan: GlifiAnalysisPlan,
        artifacts: [GlifiInterpretationArtifactInput],
        sources: [GlifiProjectSourceRecord],
        options: GlifiInterpretationOptions = .standard
    ) throws -> GlifiAnalysisInterpretation {
        try Task.checkCancellation()
        guard artifacts.count == plan.steps.count,
            Set(artifacts.map(\.planStepIdentifier)).count == artifacts.count,
            Set(artifacts.map(\.artifactID)).count == artifacts.count
        else {
            throw interpretationFailure("interpretation.input-mismatch")
        }
        let stepIDs = Set(plan.steps.map(\.identifier))
        guard Set(artifacts.map(\.planStepIdentifier)) == stepIDs else {
            throw interpretationFailure("interpretation.input-mismatch")
        }
        let stepsByID = Dictionary(
            uniqueKeysWithValues: plan.steps.map { ($0.identifier, $0) }
        )
        for artifact in artifacts {
            guard let step = stepsByID[artifact.planStepIdentifier],
                step.role == artifact.role
            else {
                throw interpretationFailure("interpretation.input-mismatch")
            }
            switch (step.operation, artifact.content) {
            case let (.analyzeCorpus, .corpusProfile(analysis)):
                guard analysis.sourceRevisionIDs == step.sourceRevisionIDs else {
                    throw interpretationFailure("interpretation.input-lineage-mismatch")
                }
            case let (.compareKeyness, .keyness(comparison)):
                guard step.role == .comparison,
                    comparison.targetSourceRevisionIDs
                        == plan.targetSourceRevisionIDs,
                    comparison.referenceSourceRevisionIDs
                        == plan.referenceSourceRevisionIDs
                else {
                    throw interpretationFailure("interpretation.input-lineage-mismatch")
                }
            case let (operation, .supplementary(schema, _, _))
            where operation != .analyzeCorpus && operation != .compareKeyness:
                guard schema == step.outputSchemaIdentifier else {
                    throw interpretationFailure("interpretation.input-lineage-mismatch")
                }
            default:
                throw interpretationFailure("interpretation.input-family-mismatch")
            }
        }
        guard Set(sources.map(\.sourceRevisionID)).count == sources.count,
            sources.allSatisfy({ $0.byteCount >= 0 })
        else {
            throw interpretationFailure("interpretation.invalid-source-catalog")
        }
        let sourcesByID = Dictionary(
            uniqueKeysWithValues: sources.map { ($0.sourceRevisionID, $0) }
        )
        let sourceArtifactIDs = artifacts.map(\.artifactID).sorted {
            $0.canonicalValue < $1.canonicalValue
        }

        let result: GlifiAnalysisInterpretation
        let keynessInputs = artifacts.filter {
            if case .keyness = $0.content { return true }
            return false
        }
        if let keynessInput = keynessInputs.first {
            guard keynessInputs.count == 1,
                case let .keyness(comparison) = keynessInput.content
            else {
                throw interpretationFailure("interpretation.ambiguous-family")
            }
            result = try interpretKeyness(
                planArtifactID: planArtifactID,
                planAnalysisNodeID: planAnalysisNodeID,
                plan: plan,
                input: keynessInput,
                comparison: comparison,
                sourceArtifactIDs: sourceArtifactIDs,
                sourcesByID: sourcesByID,
                options: options
            )
        } else if !artifacts.contains(where: {
            if case .supplementary = $0.content { return false }
            return true
        }) {
            // Solo capability ADR-0025: i findings eleggibili secondo ADR-0026 vengono aggiunti
            // da mergingExtendedFindings; se nessuno lo è, l'esito resta insufficiente.
            result = GlifiAnalysisInterpretation(
                ruleCatalogIdentifier: Self.ruleCatalogIdentifier,
                rankingIdentifier: Self.rankingIdentifier,
                intent: plan.intent,
                planArtifactID: planArtifactID,
                planAnalysisNodeID: planAnalysisNodeID,
                sourceArtifactIDs: sourceArtifactIDs,
                evidence: [],
                findings: [],
                suppressionSummaries: [],
                insufficientEvidence: GlifiInsufficientEvidenceOutcome(
                    reasonIdentifiers: ["interpretation.no-eligible-finding"],
                    caveats: [
                        caveat(
                            "caveat.insufficient-evidence",
                            severity: .warning,
                            scope: .interpretation,
                            cause: "interpretation.no-eligible-finding",
                            consequence: "caveat.consequence.no-positive-finding",
                            action: nil,
                            origin: Self.ruleCatalogIdentifier
                        )
                    ],
                    messageKey: "finding.insufficient-evidence",
                    messageArguments: [:]
                )
            )
        } else {
            let profileInputs = artifacts.filter {
                if case .corpusProfile = $0.content { return true }
                return false
            }
            guard
                let profileInput = profileInputs.first(where: { $0.role == .scope })
                    ?? profileInputs.first,
                case let .corpusProfile(analysis) = profileInput.content
            else {
                throw interpretationFailure("interpretation.unsupported-family")
            }
            result = try interpretCorpusProfile(
                planArtifactID: planArtifactID,
                planAnalysisNodeID: planAnalysisNodeID,
                plan: plan,
                input: profileInput,
                analysis: analysis,
                sourceArtifactIDs: sourceArtifactIDs,
                sourcesByID: sourcesByID
            )
        }
        let merged = try mergingExtendedFindings(
            into: result,
            artifacts: artifacts,
            sourcesByID: sourcesByID,
            options: options
        )
        try validateInterpretation(merged)
        return merged
    }
}

private extension GlifiInterpretationEngine {
    struct Candidate {
        let evidence: GlifiEvidence
        let finding: GlifiFinding
    }

    func interpretKeyness(
        planArtifactID: ArtifactID,
        planAnalysisNodeID: AnalysisNodeID,
        plan: GlifiAnalysisPlan,
        input: GlifiInterpretationArtifactInput,
        comparison: GlifiKeynessComparison,
        sourceArtifactIDs: [ArtifactID],
        sourcesByID: [SourceRevisionID: GlifiProjectSourceRecord],
        options: GlifiInterpretationOptions
    ) throws -> GlifiAnalysisInterpretation {
        let sourceReferences = try keynessSourceReferences(
            comparison,
            sourcesByID: sourcesByID
        )
        var candidates: [Candidate] = []
        candidates.reserveCapacity(min(comparison.terms.count, options.maximumFindingCount))
        var insufficientCount = 0
        for (index, term) in comparison.terms.enumerated() {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
            guard let supportClass = keynessSupportClass(term, options: options) else {
                insufficientCount += 1
                continue
            }
            let evidenceCaveats =
                term.hasLowExpectedCount
                ? [
                    caveat(
                        "caveat.keyness.low-expected-count",
                        severity: .warning,
                        scope: .evidence,
                        cause: comparison.diagnosticIdentifier,
                        consequence: "caveat.consequence.asymptotic-approximation-limited",
                        action: "caveat.action.inspect-counts",
                        origin: input.artifactID.canonicalValue
                    )
                ] : []
            let evidence = try makeEvidence(
                kindIdentifier: "evidence.keyness-term.v1",
                artifactIDs: [input.artifactID],
                analysisNodeID: input.analysisNodeID,
                descriptorDigest: input.descriptorDigest,
                methodIdentifiers: [
                    comparison.comparisonIdentifier,
                    comparison.testIdentifier,
                    comparison.correctionIdentifier,
                    comparison.oddsRatioIdentifier,
                    comparison.logRatioIdentifier,
                ],
                measures: keynessMeasures(term),
                uncertaintyIdentifiers: [
                    comparison.pValueIdentifier,
                    comparison.correctionIdentifier,
                ],
                effectSizeIdentifiers: [
                    comparison.oddsRatioIdentifier,
                    comparison.logRatioIdentifier,
                ],
                sourceReferences: sourceReferences,
                epistemicCategory: .inferred,
                validity: term.hasLowExpectedCount ? .limited : .valid,
                caveats: evidenceCaveats
            )
            let findingCaveats =
                evidenceCaveats.map {
                    caveat(
                        $0.identifier,
                        severity: $0.severity,
                        scope: .finding,
                        cause: $0.causeIdentifier,
                        consequence: $0.consequenceIdentifier,
                        action: $0.actionIdentifier,
                        origin: $0.originIdentifier
                    )
                } + rankingLimitCaveats()
            let assessment = GlifiEvidenceAssessment(
                policyIdentifier: Self.keynessSupportPolicyIdentifier,
                supportClass: supportClass,
                dimensions: keynessAssessmentDimensions(term, options: options),
                rationaleIdentifiers: [
                    "interpretation.keyness.q-value-and-effect-size",
                    term.hasLowExpectedCount
                        ? "interpretation.keyness.low-expected-count"
                        : "interpretation.keyness.expected-count-adequate",
                ]
            )
            let rank = GlifiEditorialRankFactors(
                rankingIdentifier: Self.rankingIdentifier,
                intentRelevance: 1,
                supportClass: supportClass,
                effectMagnitude: abs(term.log2RatioHaldaneAnscombe),
                coverage: nil,
                stability: nil,
                novelty: nil,
                nonRedundancy: 1,
                hasCompleteLineage: true
            )
            let finding = try makeFinding(
                familyIdentifier: "finding-family.keyness.v1",
                typeIdentifier: "finding.keyness.distinctive-term.v1",
                subjectIdentifier: "term:\(term.term)",
                predicateIdentifier: "predicate.characterizes-group-more",
                objectIdentifier: "group:\(term.direction.rawValue)",
                scopeIdentifier: "scope.target-reference-comparison.v1",
                directionIdentifier: term.direction.rawValue,
                state: .supported,
                evidenceReferences: [
                    GlifiFindingEvidenceReference(
                        evidenceID: evidence.id,
                        disposition: .supporting,
                        reasonIdentifier: nil
                    )
                ],
                assessment: assessment,
                caveats: findingCaveats,
                ruleSetIdentifier: "interpretation-rule.keyness-distinctive-term-v1",
                messageKey: "finding.keyness.\(term.direction.rawValue)",
                messageArguments: ["term": term.term],
                rankFactors: rank
            )
            candidates.append(Candidate(evidence: evidence, finding: finding))
        }
        candidates.sort { findingPrecedes($0.finding, $1.finding) }
        let emitted = Array(candidates.prefix(options.maximumFindingCount))
        let limitCount = candidates.count - emitted.count
        var suppressions: [GlifiSuppressionSummary] = []
        if insufficientCount > 0 {
            suppressions.append(
                GlifiSuppressionSummary(
                    reasonIdentifier: "interpretation.support-insufficient",
                    count: insufficientCount
                )
            )
        }
        if limitCount > 0 {
            suppressions.append(
                GlifiSuppressionSummary(
                    reasonIdentifier: "interpretation.finding-limit-exceeded",
                    count: limitCount
                )
            )
        }
        suppressions.sort { $0.reasonIdentifier < $1.reasonIdentifier }
        let insufficientOutcome =
            emitted.isEmpty
            ? GlifiInsufficientEvidenceOutcome(
                reasonIdentifiers: ["interpretation.no-keyness-term-meets-policy"],
                caveats: [
                    caveat(
                        "caveat.insufficient-evidence",
                        severity: .blocking,
                        scope: .interpretation,
                        cause: Self.keynessSupportPolicyIdentifier,
                        consequence: "caveat.consequence.no-positive-finding",
                        action: "caveat.action.review-data-or-thresholds",
                        origin: Self.ruleCatalogIdentifier
                    )
                ],
                messageKey: "finding.insufficient-evidence",
                messageArguments: [:]
            ) : nil
        return GlifiAnalysisInterpretation(
            ruleCatalogIdentifier: Self.ruleCatalogIdentifier,
            rankingIdentifier: Self.rankingIdentifier,
            intent: plan.intent,
            planArtifactID: planArtifactID,
            planAnalysisNodeID: planAnalysisNodeID,
            sourceArtifactIDs: sourceArtifactIDs,
            evidence: emitted.map(\.evidence),
            findings: emitted.map(\.finding),
            suppressionSummaries: suppressions,
            insufficientEvidence: insufficientOutcome
        )
    }

    func interpretCorpusProfile(
        planArtifactID: ArtifactID,
        planAnalysisNodeID: AnalysisNodeID,
        plan: GlifiAnalysisPlan,
        input: GlifiInterpretationArtifactInput,
        analysis: GlifiCorpusAnalysis,
        sourceArtifactIDs: [ArtifactID],
        sourcesByID: [SourceRevisionID: GlifiProjectSourceRecord]
    ) throws -> GlifiAnalysisInterpretation {
        guard analysis.lexicalTokenCount > 0 else {
            return GlifiAnalysisInterpretation(
                ruleCatalogIdentifier: Self.ruleCatalogIdentifier,
                rankingIdentifier: Self.rankingIdentifier,
                intent: plan.intent,
                planArtifactID: planArtifactID,
                planAnalysisNodeID: planAnalysisNodeID,
                sourceArtifactIDs: sourceArtifactIDs,
                evidence: [],
                findings: [],
                suppressionSummaries: [
                    GlifiSuppressionSummary(
                        reasonIdentifier: "interpretation.empty-token-population",
                        count: 1
                    )
                ],
                insufficientEvidence: GlifiInsufficientEvidenceOutcome(
                    reasonIdentifiers: ["interpretation.empty-token-population"],
                    caveats: [
                        caveat(
                            "caveat.insufficient-evidence",
                            severity: .blocking,
                            scope: .interpretation,
                            cause: "analysis.empty-token-population",
                            consequence: "caveat.consequence.no-positive-finding",
                            action: "caveat.action.review-source-content",
                            origin: Self.ruleCatalogIdentifier
                        )
                    ],
                    messageKey: "finding.insufficient-evidence",
                    messageArguments: [:]
                )
            )
        }
        let sourceReferences = try sourceReferences(
            ids: analysis.sourceRevisionIDs,
            roleIdentifier: input.role.rawValue,
            sourcesByID: sourcesByID
        )
        var measures = [
            measure(
                "collection.document-count", .integer(Int64(analysis.documentCount)), "documents"),
            measure(
                "collection.character-count", .integer(Int64(analysis.characterCount)), "characters"
            ),
            measure(
                "collection.sentence-count", .integer(Int64(analysis.sentenceCount)), "sentences"),
            measure(
                "collection.lexical-token-count", .integer(Int64(analysis.lexicalTokenCount)),
                "tokens"),
            measure("collection.type-count", .integer(Int64(analysis.typeCount)), "types"),
        ]
        if let ttr = analysis.diversity.ttr {
            measures.append(measure("collection.ttr", .decimal(ttr), nil))
        }
        if let msttr = analysis.diversity.msttr {
            measures.append(measure("collection.msttr", .decimal(msttr), nil))
        }
        if let mattr = analysis.diversity.mattr {
            measures.append(measure("collection.mattr", .decimal(mattr), nil))
        }
        let diversityUnavailable =
            analysis.diversity.msttr == nil || analysis.diversity.mattr == nil
        let evidenceCaveats =
            diversityUnavailable
            ? [
                caveat(
                    "caveat.collection.diversity-window-unavailable",
                    severity: .information,
                    scope: .evidence,
                    cause: "analysis.insufficient-complete-diversity-window",
                    consequence: "caveat.consequence.partial-diversity-profile",
                    action: "caveat.action.add-lexical-data",
                    origin: input.artifactID.canonicalValue
                )
            ] : []
        let evidence = try makeEvidence(
            kindIdentifier: "evidence.corpus-profile-summary.v1",
            artifactIDs: [input.artifactID],
            analysisNodeID: input.analysisNodeID,
            descriptorDigest: input.descriptorDigest,
            methodIdentifiers: [
                analysis.analysisIdentifier,
                analysis.diversity.ttrIdentifier,
                analysis.diversity.msttrIdentifier,
                analysis.diversity.mattrIdentifier,
                analysis.dispersionIdentifier,
            ],
            measures: measures,
            uncertaintyIdentifiers: [],
            effectSizeIdentifiers: [],
            sourceReferences: sourceReferences,
            epistemicCategory: .transformed,
            validity: .valid,
            caveats: evidenceCaveats
        )
        let assessment = GlifiEvidenceAssessment(
            policyIdentifier: Self.descriptiveSupportPolicyIdentifier,
            supportClass: .descriptive,
            dimensions: [
                GlifiEvidenceAssessmentDimension(
                    identifier: "assessment.lineage-complete",
                    value: .boolean(true),
                    outcomeIdentifier: "assessment.satisfied"
                ),
                GlifiEvidenceAssessmentDimension(
                    identifier: "assessment.nonempty-token-population",
                    value: .integer(Int64(analysis.lexicalTokenCount)),
                    outcomeIdentifier: "assessment.satisfied"
                ),
            ],
            rationaleIdentifiers: ["interpretation.descriptive-complete-lineage"]
        )
        let finding = try makeFinding(
            familyIdentifier: "finding-family.corpus-profile.v1",
            typeIdentifier: "finding.collection-profile-summary.v1",
            subjectIdentifier: "collection:\(analysis.corpusDigest)",
            predicateIdentifier: "predicate.has-descriptive-profile",
            objectIdentifier: "profile:\(analysis.analysisIdentifier)",
            scopeIdentifier: input.role.rawValue,
            directionIdentifier: nil,
            state: .supported,
            evidenceReferences: [
                GlifiFindingEvidenceReference(
                    evidenceID: evidence.id,
                    disposition: .supporting,
                    reasonIdentifier: nil
                )
            ],
            assessment: assessment,
            caveats: evidenceCaveats.map {
                caveat(
                    $0.identifier,
                    severity: $0.severity,
                    scope: .finding,
                    cause: $0.causeIdentifier,
                    consequence: $0.consequenceIdentifier,
                    action: $0.actionIdentifier,
                    origin: $0.originIdentifier
                )
            } + rankingLimitCaveats(),
            ruleSetIdentifier: "interpretation-rule.corpus-profile-summary-v1",
            messageKey: "finding.collection-profile.summary",
            messageArguments: [
                "documents": String(analysis.documentCount),
                "tokens": String(analysis.lexicalTokenCount),
                "types": String(analysis.typeCount),
            ],
            rankFactors: GlifiEditorialRankFactors(
                rankingIdentifier: Self.rankingIdentifier,
                intentRelevance: 1,
                supportClass: .descriptive,
                effectMagnitude: nil,
                coverage: 1,
                stability: nil,
                novelty: nil,
                nonRedundancy: 1,
                hasCompleteLineage: true
            )
        )
        return GlifiAnalysisInterpretation(
            ruleCatalogIdentifier: Self.ruleCatalogIdentifier,
            rankingIdentifier: Self.rankingIdentifier,
            intent: plan.intent,
            planArtifactID: planArtifactID,
            planAnalysisNodeID: planAnalysisNodeID,
            sourceArtifactIDs: sourceArtifactIDs,
            evidence: [evidence],
            findings: [finding],
            suppressionSummaries: [],
            insufficientEvidence: nil
        )
    }

    func keynessSupportClass(
        _ term: GlifiKeynessTermResult,
        options: GlifiInterpretationOptions
    ) -> GlifiSupportClass? {
        let magnitude = abs(term.log2RatioHaldaneAnscombe)
        guard term.qValue <= options.moderateMaximumQValue,
            magnitude >= options.moderateMinimumAbsoluteLog2Ratio,
            term.direction != .equal
        else {
            return nil
        }
        if term.hasLowExpectedCount { return .caution }
        if term.qValue <= options.strongMaximumQValue,
            magnitude >= options.strongMinimumAbsoluteLog2Ratio
        {
            return .strong
        }
        return .moderate
    }

    func keynessMeasures(_ term: GlifiKeynessTermResult) -> [GlifiEvidenceMeasure] {
        [
            measure("keyness.g-statistic", .decimal(term.gStatistic), nil),
            measure("keyness.log2-ratio-ha", .decimal(term.log2RatioHaldaneAnscombe), nil),
            measure("keyness.minimum-expected-count", .decimal(term.minimumExpectedCount), "cells"),
            measure("keyness.odds-ratio-ha", .decimal(term.oddsRatioHaldaneAnscombe), nil),
            measure("keyness.p-value", .decimal(term.pValue), nil),
            measure("keyness.q-value", .decimal(term.qValue), nil),
            measure(
                "keyness.reference-frequency", .integer(Int64(term.referenceFrequency)), "tokens"),
            measure(
                "keyness.reference-relative-frequency", .decimal(term.referenceRelativeFrequency),
                nil),
            measure("keyness.target-frequency", .integer(Int64(term.targetFrequency)), "tokens"),
            measure(
                "keyness.target-relative-frequency", .decimal(term.targetRelativeFrequency), nil),
            measure("keyness.term", .text(term.term), nil),
        ].sorted { $0.identifier < $1.identifier }
    }

    func keynessAssessmentDimensions(
        _ term: GlifiKeynessTermResult,
        options: GlifiInterpretationOptions
    ) -> [GlifiEvidenceAssessmentDimension] {
        [
            GlifiEvidenceAssessmentDimension(
                identifier: "assessment.adjusted-q-value",
                value: .decimal(term.qValue),
                outcomeIdentifier: term.qValue <= options.moderateMaximumQValue
                    ? "assessment.satisfied" : "assessment.not-satisfied"
            ),
            GlifiEvidenceAssessmentDimension(
                identifier: "assessment.absolute-log2-ratio",
                value: .decimal(abs(term.log2RatioHaldaneAnscombe)),
                outcomeIdentifier:
                    abs(term.log2RatioHaldaneAnscombe)
                    >= options.moderateMinimumAbsoluteLog2Ratio
                    ? "assessment.satisfied" : "assessment.not-satisfied"
            ),
            GlifiEvidenceAssessmentDimension(
                identifier: "assessment.minimum-expected-count",
                value: .decimal(term.minimumExpectedCount),
                outcomeIdentifier: term.hasLowExpectedCount
                    ? "assessment.caution" : "assessment.satisfied"
            ),
        ]
    }

    func keynessSourceReferences(
        _ comparison: GlifiKeynessComparison,
        sourcesByID: [SourceRevisionID: GlifiProjectSourceRecord]
    ) throws -> [GlifiSourceReference] {
        try sourceReferences(
            ids: comparison.targetSourceRevisionIDs,
            roleIdentifier: "target",
            sourcesByID: sourcesByID
        )
            + sourceReferences(
                ids: comparison.referenceSourceRevisionIDs,
                roleIdentifier: "reference",
                sourcesByID: sourcesByID
            )
    }

    func sourceReferences(
        ids: [SourceRevisionID],
        roleIdentifier: String,
        sourcesByID: [SourceRevisionID: GlifiProjectSourceRecord]
    ) throws -> [GlifiSourceReference] {
        try ids.sorted { $0.canonicalValue < $1.canonicalValue }.map { identifier in
            guard let source = sourcesByID[identifier], source.byteCount > 0 else {
                throw interpretationFailure("interpretation.source-reference-unresolved")
            }
            return GlifiSourceReference(
                sourceRevisionID: identifier,
                roleIdentifier: roleIdentifier,
                representationIdentifier: "source-bytes.v1",
                regionIdentifier: "whole-source-revision.v1",
                ranges: [try GlifiUTF8Range(start: 0, end: source.byteCount)]
            )
        }
    }

    func rankingLimitCaveats() -> [GlifiCaveat] {
        [
            caveat(
                "caveat.ranking.stability-not-measured",
                severity: .information,
                scope: .finding,
                cause: "ranking.dimension-unavailable",
                consequence: "caveat.consequence.rank-omits-stability",
                action: nil,
                origin: Self.rankingIdentifier
            ),
            caveat(
                "caveat.ranking.novelty-not-assessed",
                severity: .information,
                scope: .finding,
                cause: "ranking.history-unavailable",
                consequence: "caveat.consequence.rank-omits-novelty",
                action: nil,
                origin: Self.rankingIdentifier
            ),
        ]
    }
}

/// Canonical persisted payload for deterministic Evidence/Finding/Caveat output.
public struct GlifiAnalysisInterpretationArtifactPayload:
    GlifiAnalysisArtifactPayload, Equatable, Sendable
{
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.interpretation.v1"
    /// Current payload schema version.
    public static let schemaVersion = 1

    /// Stable schema serialized with the payload.
    public let schemaIdentifier: String
    /// Version serialized with the payload.
    public let schemaVersion: Int
    /// Semantic producer identity bound into the immutable payload.
    public let analysisNodeID: AnalysisNodeID
    /// Complete deterministic Evidence/Finding/Caveat result.
    public let interpretation: GlifiAnalysisInterpretation

    /// Creates a payload after validating every identity and lineage edge.
    public init(
        analysisNodeID: AnalysisNodeID,
        interpretation: GlifiAnalysisInterpretation
    ) throws {
        try validateInterpretation(interpretation)
        schemaIdentifier = Self.outputSchemaIdentifier
        schemaVersion = Self.schemaVersion
        self.analysisNodeID = analysisNodeID
        self.interpretation = interpretation
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, analysisNodeID, interpretation
    }

    /// Decodes only the supported schema and revalidates content identities.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let analysisNodeID = try container.decode(AnalysisNodeID.self, forKey: .analysisNodeID)
        let interpretation = try container.decode(
            GlifiAnalysisInterpretation.self,
            forKey: .interpretation
        )
        guard schemaIdentifier == Self.outputSchemaIdentifier,
            schemaVersion == Self.schemaVersion,
            interpretation.ruleCatalogIdentifier
                == GlifiInterpretationEngine.ruleCatalogIdentifier,
            interpretation.rankingIdentifier == GlifiInterpretationEngine.rankingIdentifier
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaIdentifier,
                in: container,
                debugDescription: "Unsupported interpretation artifact payload"
            )
        }
        try validateInterpretation(interpretation)
        self.schemaIdentifier = schemaIdentifier
        self.schemaVersion = schemaVersion
        self.analysisNodeID = analysisNodeID
        self.interpretation = interpretation
    }
}

private func measure(
    _ identifier: String,
    _ value: GlifiEvidenceValue,
    _ unitIdentifier: String?
) -> GlifiEvidenceMeasure {
    GlifiEvidenceMeasure(
        identifier: identifier,
        value: value,
        unitIdentifier: unitIdentifier
    )
}

private func caveat(
    _ identifier: String,
    severity: GlifiCaveatSeverity,
    scope: GlifiCaveatScope,
    cause: String,
    consequence: String,
    action: String?,
    origin: String
) -> GlifiCaveat {
    GlifiCaveat(
        identifier: identifier,
        severity: severity,
        scope: scope,
        causeIdentifier: cause,
        consequenceIdentifier: consequence,
        actionIdentifier: action,
        originIdentifier: origin
    )
}

private func makeEvidence(
    kindIdentifier: String,
    artifactIDs: [ArtifactID],
    analysisNodeID: AnalysisNodeID,
    descriptorDigest: String,
    methodIdentifiers: [String],
    measures: [GlifiEvidenceMeasure],
    uncertaintyIdentifiers: [String],
    effectSizeIdentifiers: [String],
    sourceReferences: [GlifiSourceReference],
    epistemicCategory: GlifiEpistemicCategory,
    validity: GlifiEvidenceValidity,
    caveats: [GlifiCaveat]
) throws -> GlifiEvidence {
    let canonicalArtifacts = Array(Set(artifactIDs)).sorted {
        $0.canonicalValue < $1.canonicalValue
    }
    let canonicalMethods = Array(Set(methodIdentifiers)).sorted()
    let canonicalMeasures = measures.sorted { $0.identifier < $1.identifier }
    let canonicalUncertainty = Array(Set(uncertaintyIdentifiers)).sorted()
    let canonicalEffects = Array(Set(effectSizeIdentifiers)).sorted()
    let canonicalReferences = sourceReferences.sorted {
        sourceReferenceSortKey($0) < sourceReferenceSortKey($1)
    }
    let canonicalCaveats = caveats.sorted { $0.identifier < $1.identifier }
    let identity = EvidenceIdentity(
        domain: "glifi.evidence.v1",
        kindIdentifier: kindIdentifier,
        artifactIDs: canonicalArtifacts,
        analysisNodeID: analysisNodeID,
        descriptorDigest: descriptorDigest,
        methodIdentifiers: canonicalMethods,
        measures: canonicalMeasures,
        uncertaintyIdentifiers: canonicalUncertainty,
        effectSizeIdentifiers: canonicalEffects,
        sourceReferences: canonicalReferences,
        epistemicCategory: epistemicCategory,
        validity: validity,
        caveats: canonicalCaveats
    )
    return GlifiEvidence(
        id: try EvidenceID(digest: interpretationDigest(identity)),
        kindIdentifier: kindIdentifier,
        artifactIDs: canonicalArtifacts,
        analysisNodeID: analysisNodeID,
        descriptorDigest: descriptorDigest,
        methodIdentifiers: canonicalMethods,
        measures: canonicalMeasures,
        uncertaintyIdentifiers: canonicalUncertainty,
        effectSizeIdentifiers: canonicalEffects,
        sourceReferences: canonicalReferences,
        epistemicCategory: epistemicCategory,
        validity: validity,
        caveats: canonicalCaveats
    )
}

private func makeFinding(
    familyIdentifier: String,
    typeIdentifier: String,
    subjectIdentifier: String,
    predicateIdentifier: String,
    objectIdentifier: String,
    scopeIdentifier: String,
    directionIdentifier: String?,
    state: GlifiFindingState,
    evidenceReferences: [GlifiFindingEvidenceReference],
    assessment: GlifiEvidenceAssessment,
    caveats: [GlifiCaveat],
    ruleSetIdentifier: String,
    messageKey: String,
    messageArguments: [String: String],
    rankFactors: GlifiEditorialRankFactors
) throws -> GlifiFinding {
    let canonicalReferences = evidenceReferences.sorted {
        $0.evidenceID.canonicalValue < $1.evidenceID.canonicalValue
    }
    let canonicalCaveats = caveats.sorted { $0.identifier < $1.identifier }
    let canonicalAssessment = GlifiEvidenceAssessment(
        policyIdentifier: assessment.policyIdentifier,
        supportClass: assessment.supportClass,
        dimensions: assessment.dimensions.sorted { $0.identifier < $1.identifier },
        rationaleIdentifiers: Array(Set(assessment.rationaleIdentifiers)).sorted()
    )
    let identity = FindingIdentity(
        domain: "glifi.finding-revision.v1",
        familyIdentifier: familyIdentifier,
        typeIdentifier: typeIdentifier,
        subjectIdentifier: subjectIdentifier,
        predicateIdentifier: predicateIdentifier,
        objectIdentifier: objectIdentifier,
        scopeIdentifier: scopeIdentifier,
        directionIdentifier: directionIdentifier,
        state: state,
        evidenceReferences: canonicalReferences,
        assessment: canonicalAssessment,
        caveats: canonicalCaveats,
        ruleSetIdentifier: ruleSetIdentifier,
        messageKey: messageKey,
        messageArguments: messageArguments,
        rankFactors: rankFactors,
        epistemicCategory: .deterministicallyInterpreted
    )
    return GlifiFinding(
        id: try FindingID(digest: interpretationDigest(identity)),
        familyIdentifier: familyIdentifier,
        typeIdentifier: typeIdentifier,
        subjectIdentifier: subjectIdentifier,
        predicateIdentifier: predicateIdentifier,
        objectIdentifier: objectIdentifier,
        scopeIdentifier: scopeIdentifier,
        directionIdentifier: directionIdentifier,
        state: state,
        evidenceReferences: canonicalReferences,
        assessment: canonicalAssessment,
        caveats: canonicalCaveats,
        ruleSetIdentifier: ruleSetIdentifier,
        messageKey: messageKey,
        messageArguments: messageArguments,
        rankFactors: rankFactors,
        epistemicCategory: .deterministicallyInterpreted
    )
}

private struct EvidenceIdentity: Encodable {
    let domain: String
    let kindIdentifier: String
    let artifactIDs: [ArtifactID]
    let analysisNodeID: AnalysisNodeID
    let descriptorDigest: String
    let methodIdentifiers: [String]
    let measures: [GlifiEvidenceMeasure]
    let uncertaintyIdentifiers: [String]
    let effectSizeIdentifiers: [String]
    let sourceReferences: [GlifiSourceReference]
    let epistemicCategory: GlifiEpistemicCategory
    let validity: GlifiEvidenceValidity
    let caveats: [GlifiCaveat]
}

private struct FindingIdentity: Encodable {
    let domain: String
    let familyIdentifier: String
    let typeIdentifier: String
    let subjectIdentifier: String
    let predicateIdentifier: String
    let objectIdentifier: String
    let scopeIdentifier: String
    let directionIdentifier: String?
    let state: GlifiFindingState
    let evidenceReferences: [GlifiFindingEvidenceReference]
    let assessment: GlifiEvidenceAssessment
    let caveats: [GlifiCaveat]
    let ruleSetIdentifier: String
    let messageKey: String
    let messageArguments: [String: String]
    let rankFactors: GlifiEditorialRankFactors
    let epistemicCategory: GlifiEpistemicCategory
}

private func sourceReferenceSortKey(_ value: GlifiSourceReference) -> String {
    let ranges = value.ranges.map { "\($0.start):\($0.end)" }.joined(separator: ",")
    return [
        value.sourceRevisionID.canonicalValue,
        value.roleIdentifier,
        value.representationIdentifier,
        value.regionIdentifier,
        ranges,
    ].joined(separator: "\u{1f}")
}

private func interpretationDigest(_ value: some Encodable) throws -> String {
    let data = try GlifiArtifactCanonicalJSON.encode(value)
    return "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func findingPrecedes(_ lhs: GlifiFinding, _ rhs: GlifiFinding) -> Bool {
    let left = lhs.rankFactors
    let right = rhs.rankFactors
    if left.intentRelevance != right.intentRelevance {
        return left.intentRelevance > right.intentRelevance
    }
    let leftSupport = supportPriority(left.supportClass)
    let rightSupport = supportPriority(right.supportClass)
    if leftSupport != rightSupport { return leftSupport > rightSupport }
    if left.effectMagnitude != right.effectMagnitude {
        return (left.effectMagnitude ?? -.infinity) > (right.effectMagnitude ?? -.infinity)
    }
    if left.coverage != right.coverage {
        return (left.coverage ?? -.infinity) > (right.coverage ?? -.infinity)
    }
    if left.stability != right.stability {
        return (left.stability ?? -.infinity) > (right.stability ?? -.infinity)
    }
    if left.novelty != right.novelty {
        return (left.novelty ?? -.infinity) > (right.novelty ?? -.infinity)
    }
    if left.nonRedundancy != right.nonRedundancy {
        return left.nonRedundancy > right.nonRedundancy
    }
    if left.hasCompleteLineage != right.hasCompleteLineage {
        return left.hasCompleteLineage && !right.hasCompleteLineage
    }
    return lhs.id.canonicalValue < rhs.id.canonicalValue
}

private func supportPriority(_ value: GlifiSupportClass) -> Int {
    switch value {
    case .strong: 5
    case .moderate: 4
    case .descriptive: 3
    case .weak: 2
    case .caution: 1
    case .insufficient: 0
    }
}

private func validateInterpretation(_ value: GlifiAnalysisInterpretation) throws {
    guard value.ruleCatalogIdentifier == GlifiInterpretationEngine.ruleCatalogIdentifier,
        value.rankingIdentifier == GlifiInterpretationEngine.rankingIdentifier,
        !value.sourceArtifactIDs.isEmpty,
        value.sourceArtifactIDs
            == value.sourceArtifactIDs.sorted(by: {
                $0.canonicalValue < $1.canonicalValue
            }),
        Set(value.sourceArtifactIDs).count == value.sourceArtifactIDs.count,
        Set(value.evidence.map(\.id)).count == value.evidence.count,
        Set(value.findings.map(\.id)).count == value.findings.count,
        value.findings.count == value.evidence.count,
        value.findings.isEmpty == (value.insufficientEvidence != nil),
        value.findings == value.findings.sorted(by: findingPrecedes),
        value.suppressionSummaries.allSatisfy({
            !$0.reasonIdentifier.isEmpty && $0.count > 0
        }),
        Set(value.suppressionSummaries.map(\.reasonIdentifier)).count
            == value.suppressionSummaries.count,
        value.suppressionSummaries
            == value.suppressionSummaries.sorted(by: {
                $0.reasonIdentifier < $1.reasonIdentifier
            })
    else {
        throw interpretationFailure("interpretation.invalid-result")
    }
    let sourceArtifacts = Set(value.sourceArtifactIDs)
    let evidenceIDs = Set(value.evidence.map(\.id))
    for evidence in value.evidence {
        guard !evidence.kindIdentifier.isEmpty,
            !evidence.artifactIDs.isEmpty,
            Set(evidence.artifactIDs).count == evidence.artifactIDs.count,
            Set(evidence.artifactIDs).isSubset(of: sourceArtifacts),
            isSHA256Digest(evidence.descriptorDigest),
            !evidence.methodIdentifiers.isEmpty,
            evidence.methodIdentifiers == evidence.methodIdentifiers.sorted(),
            Set(evidence.methodIdentifiers).count == evidence.methodIdentifiers.count,
            evidence.methodIdentifiers.allSatisfy({ !$0.isEmpty }),
            !evidence.measures.isEmpty,
            evidence.measures
                == evidence.measures.sorted(by: {
                    $0.identifier < $1.identifier
                }),
            Set(evidence.measures.map(\.identifier)).count == evidence.measures.count,
            evidence.measures.allSatisfy({
                !$0.identifier.isEmpty && $0.unitIdentifier?.isEmpty != true
            }),
            evidence.uncertaintyIdentifiers == evidence.uncertaintyIdentifiers.sorted(),
            Set(evidence.uncertaintyIdentifiers).count
                == evidence.uncertaintyIdentifiers.count,
            evidence.uncertaintyIdentifiers.allSatisfy({ !$0.isEmpty }),
            evidence.effectSizeIdentifiers == evidence.effectSizeIdentifiers.sorted(),
            Set(evidence.effectSizeIdentifiers).count
                == evidence.effectSizeIdentifiers.count,
            evidence.effectSizeIdentifiers.allSatisfy({ !$0.isEmpty }),
            !evidence.sourceReferences.isEmpty,
            evidence.sourceReferences
                == evidence.sourceReferences.sorted(by: {
                    sourceReferenceSortKey($0) < sourceReferenceSortKey($1)
                }),
            Set(evidence.sourceReferences.map(sourceReferenceSortKey)).count
                == evidence.sourceReferences.count,
            evidence.sourceReferences.allSatisfy(validSourceReference),
            Set(evidence.caveats.map(\.identifier)).count == evidence.caveats.count,
            evidence.caveats.allSatisfy(validCaveat)
        else {
            throw interpretationFailure("interpretation.invalid-evidence")
        }
        let expected = try makeEvidence(
            kindIdentifier: evidence.kindIdentifier,
            artifactIDs: evidence.artifactIDs,
            analysisNodeID: evidence.analysisNodeID,
            descriptorDigest: evidence.descriptorDigest,
            methodIdentifiers: evidence.methodIdentifiers,
            measures: evidence.measures,
            uncertaintyIdentifiers: evidence.uncertaintyIdentifiers,
            effectSizeIdentifiers: evidence.effectSizeIdentifiers,
            sourceReferences: evidence.sourceReferences,
            epistemicCategory: evidence.epistemicCategory,
            validity: evidence.validity,
            caveats: evidence.caveats
        )
        guard expected == evidence else {
            throw interpretationFailure("interpretation.evidence-identity-mismatch")
        }
    }
    for finding in value.findings {
        guard !finding.familyIdentifier.isEmpty,
            !finding.typeIdentifier.isEmpty,
            !finding.subjectIdentifier.isEmpty,
            !finding.predicateIdentifier.isEmpty,
            !finding.objectIdentifier.isEmpty,
            !finding.scopeIdentifier.isEmpty,
            finding.state == .supported,
            !finding.evidenceReferences.isEmpty,
            Set(finding.evidenceReferences.map(\.evidenceID)).count
                == finding.evidenceReferences.count,
            finding.evidenceReferences.allSatisfy({
                evidenceIDs.contains($0.evidenceID)
                    && ($0.disposition == .supporting
                        ? $0.reasonIdentifier == nil
                        : $0.reasonIdentifier?.isEmpty == false)
            }),
            finding.assessment.supportClass != .insufficient,
            !finding.assessment.policyIdentifier.isEmpty,
            finding.assessment.supportClass == finding.rankFactors.supportClass,
            !finding.assessment.dimensions.isEmpty,
            finding.assessment.dimensions
                == finding.assessment.dimensions.sorted(by: {
                    $0.identifier < $1.identifier
                }),
            Set(finding.assessment.dimensions.map(\.identifier)).count
                == finding.assessment.dimensions.count,
            finding.assessment.dimensions.allSatisfy({
                !$0.identifier.isEmpty && !$0.outcomeIdentifier.isEmpty
            }),
            !finding.assessment.rationaleIdentifiers.isEmpty,
            finding.assessment.rationaleIdentifiers
                == finding.assessment.rationaleIdentifiers.sorted(),
            Set(finding.assessment.rationaleIdentifiers).count
                == finding.assessment.rationaleIdentifiers.count,
            finding.assessment.rationaleIdentifiers.allSatisfy({ !$0.isEmpty }),
            !finding.ruleSetIdentifier.isEmpty,
            !finding.messageKey.isEmpty,
            finding.messageArguments.allSatisfy({ !$0.key.isEmpty }),
            finding.rankFactors.rankingIdentifier
                == GlifiInterpretationEngine.rankingIdentifier,
            validRank(finding.rankFactors),
            finding.epistemicCategory == .deterministicallyInterpreted,
            Set(finding.caveats.map(\.identifier)).count == finding.caveats.count,
            finding.caveats.allSatisfy(validCaveat)
        else {
            throw interpretationFailure("interpretation.invalid-finding")
        }
        let expected = try makeFinding(
            familyIdentifier: finding.familyIdentifier,
            typeIdentifier: finding.typeIdentifier,
            subjectIdentifier: finding.subjectIdentifier,
            predicateIdentifier: finding.predicateIdentifier,
            objectIdentifier: finding.objectIdentifier,
            scopeIdentifier: finding.scopeIdentifier,
            directionIdentifier: finding.directionIdentifier,
            state: finding.state,
            evidenceReferences: finding.evidenceReferences,
            assessment: finding.assessment,
            caveats: finding.caveats,
            ruleSetIdentifier: finding.ruleSetIdentifier,
            messageKey: finding.messageKey,
            messageArguments: finding.messageArguments,
            rankFactors: finding.rankFactors
        )
        guard expected == finding else {
            throw interpretationFailure("interpretation.finding-identity-mismatch")
        }
    }
    if let insufficient = value.insufficientEvidence {
        guard !insufficient.reasonIdentifiers.isEmpty,
            Set(insufficient.reasonIdentifiers).count == insufficient.reasonIdentifiers.count,
            insufficient.reasonIdentifiers.allSatisfy({ !$0.isEmpty }),
            !insufficient.messageKey.isEmpty,
            insufficient.messageArguments.allSatisfy({ !$0.key.isEmpty }),
            Set(insufficient.caveats.map(\.identifier)).count
                == insufficient.caveats.count,
            insufficient.caveats.allSatisfy(validCaveat)
        else {
            throw interpretationFailure("interpretation.invalid-insufficient-outcome")
        }
    }
}

private func validCaveat(_ value: GlifiCaveat) -> Bool {
    !value.identifier.isEmpty && !value.causeIdentifier.isEmpty
        && !value.consequenceIdentifier.isEmpty && !value.originIdentifier.isEmpty
        && value.actionIdentifier?.isEmpty != true
}

private func validSourceReference(_ value: GlifiSourceReference) -> Bool {
    guard !value.roleIdentifier.isEmpty,
        !value.representationIdentifier.isEmpty,
        !value.regionIdentifier.isEmpty,
        !value.ranges.isEmpty,
        value.ranges == value.ranges.sorted(by: { ($0.start, $0.end) < ($1.start, $1.end) })
    else {
        return false
    }
    return zip(value.ranges, value.ranges.dropFirst()).allSatisfy { left, right in
        left.end <= right.start
    }
}

private func validRank(_ value: GlifiEditorialRankFactors) -> Bool {
    value.intentRelevance >= 0
        && value.effectMagnitude.map({ $0.isFinite && $0 >= 0 }) ?? true
        && value.coverage.map({ $0.isFinite && $0 >= 0 }) ?? true
        && value.stability.map({ $0.isFinite && $0 >= 0 }) ?? true
        && value.novelty.map({ $0.isFinite && $0 >= 0 }) ?? true
        && value.nonRedundancy.isFinite && value.nonRedundancy >= 0
}

private func interpretationFailure(
    _ code: String,
    category: GlifiFailureCategory = .invariantViolation
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .executePlan,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.\(code)"
    )
}

// MARK: - ADR-0025 families interpreted with ADR-0026 policies

extension GlifiInterpretationEngine {
    /// Rule set applied to the ADR-0025 families.
    static let extendedRuleSetIdentifier = "interpretation-rule.extended-families-adr-0026-v1"

    /// Adds the findings of the ADR-0025 capabilities to a base interpretation.
    ///
    /// Each eligible result becomes one Evidence and one Finding with its ADR-0026 class;
    /// ineligible results are counted as suppressions with a stable reason.
    func mergingExtendedFindings(
        into base: GlifiAnalysisInterpretation,
        artifacts: [GlifiInterpretationArtifactInput],
        sourcesByID: [SourceRevisionID: GlifiProjectSourceRecord],
        options: GlifiInterpretationOptions
    ) throws -> GlifiAnalysisInterpretation {
        var pairs: [(GlifiEvidence, GlifiFinding)] = []
        var suppressed: [String: Int] = [:]
        for input in artifacts {
            guard case let .supplementary(_, sources, facts) = input.content else { continue }
            let candidates = try extendedCandidates(
                facts: facts,
                input: input,
                sources: sources,
                sourcesByID: sourcesByID
            )
            if candidates.isEmpty {
                suppressed["interpretation.extended-not-eligible", default: 0] += 1
            }
            pairs += candidates
        }
        guard !pairs.isEmpty || base.insufficientEvidence == nil || !suppressed.isEmpty else {
            return base
        }
        var combined = Array(zip(base.evidence, base.findings)) + pairs
        combined.sort { findingPrecedes($0.1, $1.1) }
        let limit = max(options.maximumFindingCount, base.findings.count)
        if combined.count > limit {
            suppressed["interpretation.finding-limit-exceeded", default: 0] +=
                combined.count - limit
            combined = Array(combined.prefix(limit))
        }
        var summaries = Dictionary(
            uniqueKeysWithValues: base.suppressionSummaries.map { ($0.reasonIdentifier, $0.count) }
        )
        for (reason, count) in suppressed { summaries[reason, default: 0] += count }
        let hasFindings = !combined.isEmpty
        return GlifiAnalysisInterpretation(
            ruleCatalogIdentifier: base.ruleCatalogIdentifier,
            rankingIdentifier: base.rankingIdentifier,
            intent: base.intent,
            planArtifactID: base.planArtifactID,
            planAnalysisNodeID: base.planAnalysisNodeID,
            sourceArtifactIDs: base.sourceArtifactIDs,
            evidence: combined.map(\.0),
            findings: combined.map(\.1),
            suppressionSummaries: summaries.map {
                GlifiSuppressionSummary(reasonIdentifier: $0.key, count: $0.value)
            }.sorted { $0.reasonIdentifier < $1.reasonIdentifier },
            insufficientEvidence: hasFindings ? nil : base.insufficientEvidence
        )
    }

    private func extendedCandidates(
        facts: GlifiSupplementaryFacts,
        input: GlifiInterpretationArtifactInput,
        sources: [SourceRevisionID],
        sourcesByID: [SourceRevisionID: GlifiProjectSourceRecord]
    ) throws -> [(GlifiEvidence, GlifiFinding)] {
        let references = try sourceReferences(
            ids: Array(Set(sources)),
            roleIdentifier: input.role.rawValue,
            sourcesByID: sourcesByID
        )
        func candidate(
            family: String,
            type: String,
            subject: String,
            predicate: String,
            object: String,
            method: String,
            measures: [GlifiEvidenceMeasure],
            effectSizes: [String],
            outcome: GlifiSupportOutcome,
            effect: Double?,
            messageKey: String,
            arguments: [String: String]
        ) throws -> (GlifiEvidence, GlifiFinding)? {
            guard outcome.supportClass != .insufficient else { return nil }
            let cautionCaveats = outcome.rationaleIdentifiers
                .filter { $0.hasPrefix("support.caution.") }
                .map {
                    caveat(
                        "caveat.\($0.dropFirst("support.".count))",
                        severity: .warning,
                        scope: .finding,
                        cause: $0,
                        consequence: "caveat.consequence.interpret-with-caution",
                        action: nil,
                        origin: outcome.policyIdentifier
                    )
                }
            let evidence = try makeEvidence(
                kindIdentifier: "evidence.\(type)",
                artifactIDs: [input.artifactID],
                analysisNodeID: input.analysisNodeID,
                descriptorDigest: input.descriptorDigest,
                methodIdentifiers: [method],
                measures: measures.sorted { $0.identifier < $1.identifier },
                uncertaintyIdentifiers: [],
                effectSizeIdentifiers: effectSizes.sorted(),
                sourceReferences: references,
                epistemicCategory: outcome.supportClass == .descriptive ? .transformed : .inferred,
                validity: cautionCaveats.isEmpty ? .valid : .limited,
                caveats: []
            )
            let finding = try makeFinding(
                familyIdentifier: family,
                typeIdentifier: type,
                subjectIdentifier: subject,
                predicateIdentifier: predicate,
                objectIdentifier: object,
                scopeIdentifier: input.role.rawValue,
                directionIdentifier: nil,
                state: .supported,
                evidenceReferences: [
                    GlifiFindingEvidenceReference(
                        evidenceID: evidence.id,
                        disposition: .supporting,
                        reasonIdentifier: nil
                    )
                ],
                assessment: GlifiEvidenceAssessment(
                    policyIdentifier: outcome.policyIdentifier,
                    supportClass: outcome.supportClass,
                    dimensions: outcome.dimensions,
                    rationaleIdentifiers: outcome.rationaleIdentifiers
                ),
                caveats: cautionCaveats + rankingLimitCaveats(),
                ruleSetIdentifier: Self.extendedRuleSetIdentifier,
                messageKey: messageKey,
                messageArguments: arguments,
                rankFactors: GlifiEditorialRankFactors(
                    rankingIdentifier: Self.rankingIdentifier,
                    intentRelevance: 1,
                    supportClass: outcome.supportClass,
                    effectMagnitude: effect.map(abs),
                    coverage: nil,
                    stability: nil,
                    novelty: nil,
                    nonRedundancy: 1,
                    hasCompleteLineage: true
                )
            )
            return (evidence, finding)
        }
        func text(_ value: Double) -> String { String(format: "%.3f", value) }

        switch facts {
        case let .association(v, dimension, p, lowFraction):
            guard let p else { return [] }
            let outcome = GlifiSupportPolicies.contingency(
                cramersV: v,
                minimumDimension: dimension,
                monteCarloPValue: p,
                lowExpectedCellFraction: lowFraction
            )
            return try [
                candidate(
                    family: "finding-family.contingency.v1",
                    type: "finding.document-term-association.v1",
                    subject: "documents",
                    predicate: "predicate.associated-with",
                    object: "terms",
                    method: GlifiCorpusAssociationAnalysis.analysisIdentifier,
                    measures: [
                        measure("association.cramers-v", .decimal(v), nil),
                        measure("association.monte-carlo-p", .decimal(p), nil),
                    ],
                    effectSizes: [GlifiContingencyAssociation.cramersVIdentifier],
                    outcome: outcome,
                    effect: v,
                    messageKey: "finding.association.documents-terms",
                    arguments: ["v": text(v)]
                )
            ].compactMap { $0 }
        case let .groupLocation(metric, g, p, smallest):
            guard let g, let p else { return [] }
            let outcome = GlifiSupportPolicies.groupLocation(
                hedgesG: g,
                pValue: p,
                smallestGroupSize: smallest
            )
            return try [
                candidate(
                    family: "finding-family.group-location.v1",
                    type: "finding.group-location-difference.v1",
                    subject: "group:target",
                    predicate: g > 0 ? "predicate.higher-than" : "predicate.lower-than",
                    object: "group:reference",
                    method: GlifiGroupMetricComparison.analysisIdentifier,
                    measures: [
                        measure("group.hedges-g", .decimal(g), nil),
                        measure("group.p-value", .decimal(p), nil),
                    ],
                    effectSizes: [GlifiStatisticalFoundation.hedgesIdentifier],
                    outcome: outcome,
                    effect: g,
                    messageKey: "finding.group-location.difference",
                    arguments: ["metric": metric, "g": text(g)]
                )
            ].compactMap { $0 }
        case let .collocations(pairs):
            return try pairs.prefix(50).compactMap { pair in
                try candidate(
                    family: "finding-family.collocation.v1",
                    type: "finding.window-collocation.v1",
                    subject: "term:\(pair.node)",
                    predicate: "predicate.collocates-with",
                    object: "term:\(pair.collocate)",
                    method: GlifiWindowCollocationAnalysis.analysisIdentifier,
                    measures: [
                        measure(
                            "collocation.joint-count", .integer(Int64(pair.jointCount)), "pairs"),
                        measure("collocation.npmi", .decimal(pair.npmi ?? 0), nil),
                        measure("collocation.t-score", .decimal(pair.tScore ?? 0), nil),
                    ],
                    effectSizes: [GlifiCollocationMeasures.npmiIdentifier],
                    outcome: GlifiSupportPolicies.collocation(
                        jointCount: pair.jointCount,
                        tScore: pair.tScore,
                        npmi: pair.npmi
                    ),
                    effect: pair.npmi,
                    messageKey: "finding.collocation.pair",
                    arguments: [
                        "node": pair.node, "collocate": pair.collocate,
                        "npmi": text(pair.npmi ?? 0),
                    ]
                )
            }
        case let .network(modularity, communities, nodes):
            guard let modularity, let communities else { return [] }
            return try [
                candidate(
                    family: "finding-family.lexical-network.v1",
                    type: "finding.network-communities.v1",
                    subject: "network",
                    predicate: "predicate.has-community-structure",
                    object: "communities:\(communities)",
                    method: GlifiWindowNetworkAnalysis.analysisIdentifier,
                    measures: [
                        measure(
                            "network.community-count", .integer(Int64(communities)), "communities"),
                        measure("network.modularity", .decimal(modularity), nil),
                        measure("network.node-count", .integer(Int64(nodes)), "nodes"),
                    ],
                    effectSizes: ["Louvain-v1"],
                    outcome: GlifiSupportPolicies.community(
                        modularity: modularity, nodeCount: nodes),
                    effect: modularity,
                    messageKey: "finding.network.communities",
                    arguments: ["communities": String(communities), "q": text(modularity)]
                )
            ].compactMap { $0 }
        case let .correspondence(inertias, total):
            guard total > 0 else { return [] }
            return try inertias.prefix(3).enumerated().compactMap { axis, inertia in
                let share = inertia / total
                return try candidate(
                    family: "finding-family.correspondence.v1",
                    type: "finding.correspondence-axis.v1",
                    subject: "axis:\(axis + 1)",
                    predicate: "predicate.explains-inertia",
                    object: "inertia-share",
                    method: GlifiCorrespondenceResult.identifier,
                    measures: [
                        measure("correspondence.inertia", .decimal(inertia), nil),
                        measure("correspondence.inertia-share", .decimal(share), nil),
                        measure("correspondence.total-inertia", .decimal(total), nil),
                    ],
                    effectSizes: ["inertia-share"],
                    outcome: GlifiSupportPolicies.correspondenceAxis(
                        inertiaShare: share,
                        axisCount: inertias.count,
                        totalInertia: total
                    ),
                    effect: share,
                    messageKey: "finding.correspondence.axis",
                    arguments: ["axis": String(axis + 1), "share": text(share)]
                )
            }
        case let .clustering(clusters, silhouette, smallest):
            guard let silhouette else { return [] }
            return try [
                candidate(
                    family: "finding-family.clustering.v1",
                    type: "finding.cluster-structure.v1",
                    subject: "documents",
                    predicate: "predicate.form-clusters",
                    object: "clusters:\(clusters)",
                    method: GlifiHierarchicalClustering.identifier,
                    measures: [
                        measure("clustering.average-silhouette", .decimal(silhouette), nil),
                        measure("clustering.cluster-count", .integer(Int64(clusters)), "clusters"),
                    ],
                    effectSizes: ["Silhouette-v1"],
                    outcome: GlifiSupportPolicies.clustering(
                        averageSilhouette: silhouette,
                        smallestClusterSize: smallest
                    ),
                    effect: silhouette,
                    messageKey: "finding.clustering.structure",
                    arguments: ["clusters": String(clusters), "silhouette": text(silhouette)]
                )
            ].compactMap { $0 }
        case let .similarity(shared, cosine, jsDistance):
            return try [
                candidate(
                    family: "finding-family.similarity.v1",
                    type: "finding.group-similarity.v1",
                    subject: "group:target",
                    predicate: "predicate.similar-to",
                    object: "group:reference",
                    method: GlifiCorpusSimilarityAnalyzer.comparisonIdentifier,
                    measures: [
                        measure("similarity.cosine", .decimal(cosine), nil),
                        measure("similarity.js-distance", .decimal(jsDistance), nil),
                        measure("similarity.shared-types", .integer(Int64(shared)), "types"),
                    ],
                    effectSizes: [GlifiVectorSimilarity.cosineIdentifier],
                    outcome: GlifiSupportPolicies.similarity(sharedTypeCount: shared),
                    effect: nil,
                    messageKey: "finding.similarity.groups",
                    arguments: ["shared": String(shared), "cosine": text(cosine)]
                )
            ].compactMap { $0 }
        }
    }
}
