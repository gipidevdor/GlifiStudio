// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// JSON-safe tagged scalar used by evidence and assessment values.
public struct GlifiStudioEvidenceValue: Codable, Equatable, Sendable {
    /// Stable scalar kind: `integer`, `decimal`, `text`, or `boolean`.
    public let type: String
    /// Exact integer value when `type` is `integer`.
    public let integerValue: Int64?
    /// Finite binary64 value when `type` is `decimal`.
    public let decimalValue: Double?
    /// Canonical text when `type` is `text`.
    public let textValue: String?
    /// Boolean value when `type` is `boolean`.
    public let booleanValue: Bool?

    private enum CodingKeys: String, CodingKey {
        case type, integerValue, decimalValue, textValue, booleanValue
    }

    init(_ value: GlifiEvidenceValue) {
        switch value {
        case let .integer(value):
            type = "integer"
            integerValue = value
            decimalValue = nil
            textValue = nil
            booleanValue = nil
        case let .decimal(value):
            type = "decimal"
            integerValue = nil
            decimalValue = value
            textValue = nil
            booleanValue = nil
        case let .text(value):
            type = "text"
            integerValue = nil
            decimalValue = nil
            textValue = value
            booleanValue = nil
        case let .boolean(value):
            type = "boolean"
            integerValue = nil
            decimalValue = nil
            textValue = nil
            booleanValue = value
        }
    }

    /// Decodes exactly one value matching the declared stable type.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let integerValue = try container.decodeIfPresent(Int64.self, forKey: .integerValue)
        let decimalValue = try container.decodeIfPresent(Double.self, forKey: .decimalValue)
        let textValue = try container.decodeIfPresent(String.self, forKey: .textValue)
        let booleanValue = try container.decodeIfPresent(Bool.self, forKey: .booleanValue)
        let isValid =
            switch type {
            case "integer":
                integerValue != nil && decimalValue == nil && textValue == nil
                    && booleanValue == nil
            case "decimal":
                integerValue == nil && decimalValue?.isFinite == true && textValue == nil
                    && booleanValue == nil
            case "text":
                integerValue == nil && decimalValue == nil && textValue != nil
                    && booleanValue == nil
            case "boolean":
                integerValue == nil && decimalValue == nil && textValue == nil
                    && booleanValue != nil
            default:
                false
            }
        guard isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Evidence value type and payload do not match"
            )
        }
        self.type = type
        self.integerValue = integerValue
        self.decimalValue = decimalValue
        self.textValue = textValue
        self.booleanValue = booleanValue
    }

    /// Encodes only the value admitted by the stable type tag.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch type {
        case "integer":
            try container.encode(
                try required(integerValue, encoder: encoder),
                forKey: .integerValue
            )
        case "decimal":
            let value = try required(decimalValue, encoder: encoder)
            guard value.isFinite else { throw invalidStudioEvidenceValue(encoder) }
            try container.encode(value, forKey: .decimalValue)
        case "text":
            try container.encode(
                try required(textValue, encoder: encoder),
                forKey: .textValue
            )
        case "boolean":
            try container.encode(
                try required(booleanValue, encoder: encoder),
                forKey: .booleanValue
            )
        default:
            throw invalidStudioEvidenceValue(encoder)
        }
    }
}

private func required<Value>(_ value: Value?, encoder: any Encoder) throws -> Value {
    guard let value else { throw invalidStudioEvidenceValue(encoder) }
    return value
}

private func invalidStudioEvidenceValue(_ encoder: any Encoder) -> EncodingError {
    EncodingError.invalidValue(
        "GlifiStudioEvidenceValue",
        EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Evidence value type and payload do not match"
        )
    )
}

/// One named quantitative or qualitative value supporting evidence.
public struct GlifiStudioEvidenceMeasure: Codable, Equatable, Sendable {
    /// Stable measure identity.
    public let identifier: String
    /// Typed measure value.
    public let value: GlifiStudioEvidenceValue
    /// Stable unit identity, absent for unitless values.
    public let unitIdentifier: String?

    init(_ value: GlifiEvidenceMeasure) {
        identifier = value.identifier
        self.value = GlifiStudioEvidenceValue(value.value)
        unitIdentifier = value.unitIdentifier
    }
}

/// Exact immutable source region grounding one evidence record.
public struct GlifiStudioSourceReference: Codable, Equatable, Sendable {
    /// Opaque immutable source revision identity.
    public let sourceRevisionID: String
    /// Population role assigned by the plan.
    public let roleIdentifier: String
    /// Coordinate representation used by the ranges.
    public let representationIdentifier: String
    /// Stable semantic region identity.
    public let regionIdentifier: String
    /// Ordered half-open source-byte ranges.
    public let ranges: [GlifiStudioUTF8Range]

    init(_ value: GlifiSourceReference) {
        sourceRevisionID = value.sourceRevisionID.canonicalValue
        roleIdentifier = value.roleIdentifier
        representationIdentifier = value.representationIdentifier
        regionIdentifier = value.regionIdentifier
        ranges = value.ranges.map(GlifiStudioUTF8Range.init)
    }
}

/// Structured, localizable limitation whose semantics are never hidden in prose.
public struct GlifiStudioCaveat: Codable, Equatable, Sendable {
    /// Stable localizable caveat identity.
    public let identifier: String
    /// `information`, `warning`, or `blocking`.
    public let severity: String
    /// Smallest semantic scope affected by the caveat.
    public let scope: String
    /// Stable cause identity.
    public let causeIdentifier: String
    /// Stable consequence identity.
    public let consequenceIdentifier: String
    /// Stable remediation identity, when actionable.
    public let actionIdentifier: String?
    /// Artifact, policy, or rule that originated the caveat.
    public let originIdentifier: String

    init(_ value: GlifiCaveat) {
        identifier = value.identifier
        severity = value.severity.rawValue
        scope = value.scope.rawValue
        causeIdentifier = value.causeIdentifier
        consequenceIdentifier = value.consequenceIdentifier
        actionIdentifier = value.actionIdentifier
        originIdentifier = value.originIdentifier
    }
}

/// Immutable, content-addressed analytical evidence with complete lineage.
public struct GlifiStudioEvidence: Codable, Equatable, Sendable {
    /// Content identity of the evidence record.
    public let id: String
    /// Stable evidence-family identity.
    public let kindIdentifier: String
    /// Immutable Artifact identities used by the evidence.
    public let artifactIDs: [String]
    /// Semantic producer node.
    public let analysisNodeID: String
    /// Digest of the complete producer descriptor.
    public let descriptorDigest: String
    /// Exact method variants used.
    public let methodIdentifiers: [String]
    /// Canonically ordered observed or derived measures.
    public let measures: [GlifiStudioEvidenceMeasure]
    /// Exact uncertainty contracts represented by the evidence.
    public let uncertaintyIdentifiers: [String]
    /// Exact effect-size contracts represented by the evidence.
    public let effectSizeIdentifiers: [String]
    /// Source-level provenance references.
    public let sourceReferences: [GlifiStudioSourceReference]
    /// Epistemic class of the evidence.
    public let epistemicCategory: String
    /// `valid` or `limited`.
    public let validity: String
    /// Structured limitations attached to this evidence.
    public let caveats: [GlifiStudioCaveat]

    init(_ value: GlifiEvidence) {
        id = value.id.canonicalValue
        kindIdentifier = value.kindIdentifier
        artifactIDs = value.artifactIDs.map(\.canonicalValue)
        analysisNodeID = value.analysisNodeID.canonicalValue
        descriptorDigest = value.descriptorDigest
        methodIdentifiers = value.methodIdentifiers
        measures = value.measures.map(GlifiStudioEvidenceMeasure.init)
        uncertaintyIdentifiers = value.uncertaintyIdentifiers
        effectSizeIdentifiers = value.effectSizeIdentifiers
        sourceReferences = value.sourceReferences.map(GlifiStudioSourceReference.init)
        epistemicCategory = value.epistemicCategory.rawValue
        validity = value.validity.rawValue
        caveats = value.caveats.map(GlifiStudioCaveat.init)
    }
}

/// One transparent dimension evaluated by a family-specific support policy.
public struct GlifiStudioEvidenceAssessmentDimension: Codable, Equatable, Sendable {
    /// Stable dimension identity.
    public let identifier: String
    /// Exact value evaluated by the policy.
    public let value: GlifiStudioEvidenceValue
    /// Stable policy outcome identity.
    public let outcomeIdentifier: String

    init(_ value: GlifiEvidenceAssessmentDimension) {
        identifier = value.identifier
        self.value = GlifiStudioEvidenceValue(value.value)
        outcomeIdentifier = value.outcomeIdentifier
    }
}

/// Explainable family-specific support decision, not a universal score.
public struct GlifiStudioEvidenceAssessment: Codable, Equatable, Sendable {
    /// Exact support-policy version.
    public let policyIdentifier: String
    /// Family-specific support class.
    public let supportClass: String
    /// Transparent evaluated dimensions.
    public let dimensions: [GlifiStudioEvidenceAssessmentDimension]
    /// Stable localizable rationale identities.
    public let rationaleIdentifiers: [String]

    init(_ value: GlifiEvidenceAssessment) {
        policyIdentifier = value.policyIdentifier
        supportClass = value.supportClass.rawValue
        dimensions = value.dimensions.map(GlifiStudioEvidenceAssessmentDimension.init)
        rationaleIdentifiers = value.rationaleIdentifiers
    }
}

/// Declared relationship between a finding and considered evidence.
public struct GlifiStudioFindingEvidenceReference: Codable, Equatable, Sendable {
    /// Content identity of the evidence record.
    public let evidenceID: String
    /// `supporting`, `contrary`, or `excluded`.
    public let disposition: String
    /// Stable exclusion or contradiction reason, when required.
    public let reasonIdentifier: String?

    init(_ value: GlifiFindingEvidenceReference) {
        evidenceID = value.evidenceID.canonicalValue
        disposition = value.disposition.rawValue
        reasonIdentifier = value.reasonIdentifier
    }
}

/// Transparent lexicographic factors used by the editorial ranking policy.
public struct GlifiStudioEditorialRankFactors: Codable, Equatable, Sendable {
    /// Exact ranking-policy version.
    public let rankingIdentifier: String
    /// Relevance to the user-selected intent.
    public let intentRelevance: Int
    /// Family-specific support class.
    public let supportClass: String
    /// Comparable within-family effect magnitude, when defined.
    public let effectMagnitude: Double?
    /// Population coverage, when measured.
    public let coverage: Double?
    /// Stability, when measured.
    public let stability: Double?
    /// Novelty, when history makes it measurable.
    public let novelty: Double?
    /// Non-redundancy factor.
    public let nonRedundancy: Double
    /// Whether every lineage edge is complete.
    public let hasCompleteLineage: Bool

    init(_ value: GlifiEditorialRankFactors) {
        rankingIdentifier = value.rankingIdentifier
        intentRelevance = value.intentRelevance
        supportClass = value.supportClass.rawValue
        effectMagnitude = value.effectMagnitude
        coverage = value.coverage
        stability = value.stability
        novelty = value.novelty
        nonRedundancy = value.nonRedundancy
        hasCompleteLineage = value.hasCompleteLineage
    }
}

/// Immutable deterministic proposition grounded in explicit evidence.
public struct GlifiStudioFinding: Codable, Equatable, Sendable {
    /// Content identity of this finding revision.
    public let id: String
    /// Analytical family used for policy and within-family comparison.
    public let familyIdentifier: String
    /// Stable proposition type.
    public let typeIdentifier: String
    /// Stable proposition subject.
    public let subjectIdentifier: String
    /// Stable proposition predicate.
    public let predicateIdentifier: String
    /// Stable proposition object.
    public let objectIdentifier: String
    /// Scope within which the proposition is valid.
    public let scopeIdentifier: String
    /// Direction, when defined by the family.
    public let directionIdentifier: String?
    /// Immutable finding lifecycle state.
    public let state: String
    /// Evidence relationships considered by the rule.
    public let evidenceReferences: [GlifiStudioFindingEvidenceReference]
    /// Explainable family-specific support decision.
    public let assessment: GlifiStudioEvidenceAssessment
    /// Structured limitations that must travel with the proposition.
    public let caveats: [GlifiStudioCaveat]
    /// Exact deterministic rule version.
    public let ruleSetIdentifier: String
    /// Localizable explanation key.
    public let messageKey: String
    /// Localizable explanation arguments.
    public let messageArguments: [String: String]
    /// Transparent ranking factors without an invented global score.
    public let rankFactors: GlifiStudioEditorialRankFactors
    /// Epistemic class of the proposition.
    public let epistemicCategory: String

    init(_ value: GlifiFinding) {
        id = value.id.canonicalValue
        familyIdentifier = value.familyIdentifier
        typeIdentifier = value.typeIdentifier
        subjectIdentifier = value.subjectIdentifier
        predicateIdentifier = value.predicateIdentifier
        objectIdentifier = value.objectIdentifier
        scopeIdentifier = value.scopeIdentifier
        directionIdentifier = value.directionIdentifier
        state = value.state.rawValue
        evidenceReferences = value.evidenceReferences.map(
            GlifiStudioFindingEvidenceReference.init
        )
        assessment = GlifiStudioEvidenceAssessment(value.assessment)
        caveats = value.caveats.map(GlifiStudioCaveat.init)
        ruleSetIdentifier = value.ruleSetIdentifier
        messageKey = value.messageKey
        messageArguments = value.messageArguments
        rankFactors = GlifiStudioEditorialRankFactors(value.rankFactors)
        epistemicCategory = value.epistemicCategory.rawValue
    }
}

/// Bounded aggregate explaining why alternatives were not materialized.
public struct GlifiStudioSuppressionSummary: Codable, Equatable, Sendable {
    /// Stable suppression reason.
    public let reasonIdentifier: String
    /// Number of alternatives represented by the aggregate.
    public let count: Int

    init(_ value: GlifiSuppressionSummary) {
        reasonIdentifier = value.reasonIdentifier
        count = value.count
    }
}

/// Explicit no-positive-finding outcome that never fabricates evidence.
public struct GlifiStudioInsufficientEvidenceOutcome: Codable, Equatable, Sendable {
    /// Stable reasons why a positive proposition is not authorized.
    public let reasonIdentifiers: [String]
    /// Blocking or explanatory structured caveats.
    public let caveats: [GlifiStudioCaveat]
    /// Localizable user-facing message key.
    public let messageKey: String
    /// Localizable message arguments.
    public let messageArguments: [String: String]

    init(_ value: GlifiInsufficientEvidenceOutcome) {
        reasonIdentifiers = value.reasonIdentifiers
        caveats = value.caveats.map(GlifiStudioCaveat.init)
        messageKey = value.messageKey
        messageArguments = value.messageArguments
    }
}

/// Complete deterministic Evidence/Finding/Caveat result for native and headless clients.
public struct GlifiStudioAnalysisInterpretation: Codable, Equatable, Sendable {
    /// Exact interpretation rule catalog.
    public let ruleCatalogIdentifier: String
    /// Exact editorial-ranking contract.
    public let rankingIdentifier: String
    /// User intent that governed interpretation.
    public let intent: String
    /// Immutable plan Artifact identity.
    public let planArtifactID: String
    /// Semantic plan-node identity.
    public let planAnalysisNodeID: String
    /// Canonically ordered analytical Artifact identities considered by the rules.
    public let sourceArtifactIDs: [String]
    /// Evidence records aligned with the emitted findings.
    public let evidence: [GlifiStudioEvidence]
    /// Eligible positive findings in deterministic editorial order.
    public let findings: [GlifiStudioFinding]
    /// Bounded reasons for suppressed alternatives.
    public let suppressionSummaries: [GlifiStudioSuppressionSummary]
    /// Explicit outcome when no positive finding is defensible.
    public let insufficientEvidence: GlifiStudioInsufficientEvidenceOutcome?

    init(_ value: GlifiAnalysisInterpretation) {
        ruleCatalogIdentifier = value.ruleCatalogIdentifier
        rankingIdentifier = value.rankingIdentifier
        intent = value.intent.rawValue
        planArtifactID = value.planArtifactID.canonicalValue
        planAnalysisNodeID = value.planAnalysisNodeID.canonicalValue
        sourceArtifactIDs = value.sourceArtifactIDs.map(\.canonicalValue)
        evidence = value.evidence.map(GlifiStudioEvidence.init)
        findings = value.findings.map(GlifiStudioFinding.init)
        suppressionSummaries = value.suppressionSummaries.map(
            GlifiStudioSuppressionSummary.init
        )
        insufficientEvidence = value.insufficientEvidence.map(
            GlifiStudioInsufficientEvidenceOutcome.init
        )
    }
}
