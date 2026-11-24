// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// JSON-friendly planner request shared by native and headless clients.
public struct GlifiStudioAnalysisPlanRequest: Codable, Equatable, Sendable {
    /// Stable analytical-intent identifier.
    public let intent: String
    /// Optional scope; an empty array resolves to all current sources.
    public let scopeSourceRevisionIDs: [String]
    /// Explicit target population for comparative capabilities.
    public let targetSourceRevisionIDs: [String]
    /// Explicit reference population for comparative capabilities.
    public let referenceSourceRevisionIDs: [String]
    /// Maximum aggregate cost admitted by the planner.
    public let maximumEstimatedWorkUnits: Int64

    /// Creates a client request without interpreting localized text.
    public init(
        intent: String,
        scopeSourceRevisionIDs: [String] = [],
        targetSourceRevisionIDs: [String] = [],
        referenceSourceRevisionIDs: [String] = [],
        maximumEstimatedWorkUnits: Int64 =
            GlifiAnalysisPlanRequest.standardMaximumEstimatedWorkUnits
    ) {
        self.intent = intent
        self.scopeSourceRevisionIDs = scopeSourceRevisionIDs
        self.targetSourceRevisionIDs = targetSourceRevisionIDs
        self.referenceSourceRevisionIDs = referenceSourceRevisionIDs
        self.maximumEstimatedWorkUnits = maximumEstimatedWorkUnits
    }

    private enum CodingKeys: String, CodingKey {
        case intent
        case scopeSourceRevisionIDs
        case targetSourceRevisionIDs
        case referenceSourceRevisionIDs
        case maximumEstimatedWorkUnits
    }

    /// Decodes a minimal request while resolving omitted optional fields explicitly.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = try container.decode(String.self, forKey: .intent)
        scopeSourceRevisionIDs =
            try container.decodeIfPresent([String].self, forKey: .scopeSourceRevisionIDs) ?? []
        targetSourceRevisionIDs =
            try container.decodeIfPresent([String].self, forKey: .targetSourceRevisionIDs) ?? []
        referenceSourceRevisionIDs =
            try container.decodeIfPresent([String].self, forKey: .referenceSourceRevisionIDs) ?? []
        maximumEstimatedWorkUnits =
            try container.decodeIfPresent(Int64.self, forKey: .maximumEstimatedWorkUnits)
            ?? GlifiAnalysisPlanRequest.standardMaximumEstimatedWorkUnits
    }
}

/// Observed source-format distribution used by the planner.
public struct GlifiStudioPlanningFormatCount: Codable, Equatable, Sendable {
    /// Stable source-format identifier.
    public let formatIdentifier: String
    /// Number of source revisions in this format.
    public let sourceCount: Int
    /// Exact number of source bytes in this format.
    public let byteCount: Int64

    init(_ value: GlifiPlanningFormatCount) {
        formatIdentifier = value.formatIdentifier
        sourceCount = value.sourceCount
        byteCount = value.byteCount
    }
}

/// Presentation-independent collection facts used by one plan revision.
public struct GlifiStudioCollectionPlanningProfile: Codable, Equatable, Sendable {
    /// Versioned collection-profile contract.
    public let profileIdentifier: String
    /// Authoritative source root evaluated by the planner.
    public let sourceRootDigest: String
    /// Canonically ordered resolved source scope.
    public let sourceRevisionIDs: [String]
    /// Number of source revisions in the scope.
    public let sourceCount: Int
    /// Exact source bytes in the scope.
    public let totalSourceByteCount: Int64
    /// Canonically ordered source-format distribution.
    public let formatCounts: [GlifiStudioPlanningFormatCount]
    /// Explicit language configuration used for matching.
    public let configuredLanguageCode: String
    /// Epistemic class of the profile facts.
    public let observationClassIdentifier: String

    init(_ value: GlifiCollectionPlanningProfile) {
        profileIdentifier = value.profileIdentifier
        sourceRootDigest = value.sourceRootDigest
        sourceRevisionIDs = value.sourceRevisionIDs.map(\.canonicalValue)
        sourceCount = value.sourceCount
        totalSourceByteCount = value.totalSourceByteCount
        formatCounts = value.formatCounts.map(GlifiStudioPlanningFormatCount.init)
        configuredLanguageCode = value.configuredLanguageCode
        observationClassIdentifier = value.observationClassIdentifier
    }
}

/// Explainable planner decision for one capability.
public struct GlifiStudioAnalysisCapabilityDecision: Codable, Equatable, Sendable {
    /// Stable capability identifier.
    public let capabilityIdentifier: String
    /// Applicability state independent from localized presentation.
    public let applicability: String
    /// Whether steps were admitted to the executable plan.
    public let isIncluded: Bool
    /// Stable explanation identifiers.
    public let reasonIdentifiers: [String]
    /// Stable caveat identifiers.
    public let caveatIdentifiers: [String]
    /// Backend selected for admitted execution, if any.
    public let selectedBackendIdentifier: String?
    /// Ordered approved fallback chain, empty when none exists.
    public let fallbackIdentifiers: [String]
    /// Atomic estimated cost when available.
    public let estimatedWorkUnits: Int64?

    init(_ value: GlifiAnalysisCapabilityDecision) {
        capabilityIdentifier = value.capabilityIdentifier
        applicability = value.applicability.rawValue
        isIncluded = value.isIncluded
        reasonIdentifiers = value.reasonIdentifiers
        caveatIdentifiers = value.caveatIdentifiers
        selectedBackendIdentifier = value.selectedBackendIdentifier
        fallbackIdentifiers = value.fallbackIdentifiers
        estimatedWorkUnits = value.estimatedWorkUnits
    }
}

/// Canonically ordered executable step selected by the planner.
public struct GlifiStudioAnalysisPlanStep: Codable, Equatable, Sendable {
    /// Stable identity within the plan revision.
    public let identifier: String
    /// Zero-based execution order.
    public let order: Int
    /// Stable capability identity.
    public let capabilityIdentifier: String
    /// Headless operation selected for execution.
    public let operation: String
    /// Semantic population role.
    public let role: String
    /// Canonically ordered immutable inputs.
    public let sourceRevisionIDs: [String]
    /// Earlier plan steps required by this step.
    public let dependencyStepIdentifiers: [String]
    /// Deterministic integer work estimate.
    public let estimatedWorkUnits: Int64
    /// Persisted output schema expected from execution.
    public let outputSchemaIdentifier: String
    /// Stable caveats that execution must preserve.
    public let caveatIdentifiers: [String]

    init(_ value: GlifiAnalysisPlanStep) {
        identifier = value.identifier
        order = value.order
        capabilityIdentifier = value.capabilityIdentifier
        operation = value.operation.rawValue
        role = value.role.rawValue
        sourceRevisionIDs = value.sourceRevisionIDs.map(\.canonicalValue)
        dependencyStepIdentifiers = value.dependencyStepIdentifiers
        estimatedWorkUnits = value.estimatedWorkUnits
        outputSchemaIdentifier = value.outputSchemaIdentifier
        caveatIdentifiers = value.caveatIdentifiers
    }
}

/// Reproducible analysis plan with rationale, exclusions, and explicit inputs.
public struct GlifiStudioAnalysisPlan: Codable, Equatable, Sendable {
    /// Exact planner contract.
    public let plannerIdentifier: String
    /// Exact capability-catalog snapshot.
    public let capabilityCatalogIdentifier: String
    /// Stable analytical intent.
    public let intent: String
    /// Aggregate readiness state.
    public let status: String
    /// Collection facts used by the decision.
    public let collectionProfile: GlifiStudioCollectionPlanningProfile
    /// Explicit resolved source scope.
    public let resolvedScopeSourceRevisionIDs: [String]
    /// Explicit target population.
    public let targetSourceRevisionIDs: [String]
    /// Explicit reference population.
    public let referenceSourceRevisionIDs: [String]
    /// Work budget applied to the request.
    public let maximumEstimatedWorkUnits: Int64
    /// Sum of admitted step estimates.
    public let totalEstimatedWorkUnits: Int64
    /// Canonically ordered execution steps.
    public let steps: [GlifiStudioAnalysisPlanStep]
    /// Decision for every capability in the catalog.
    public let decisions: [GlifiStudioAnalysisCapabilityDecision]
    /// Stable unresolved-condition identifiers.
    public let unresolvedReasonIdentifiers: [String]

    init(_ value: GlifiAnalysisPlan) {
        plannerIdentifier = value.plannerIdentifier
        capabilityCatalogIdentifier = value.capabilityCatalogIdentifier
        intent = value.intent.rawValue
        status = value.status.rawValue
        collectionProfile = GlifiStudioCollectionPlanningProfile(value.collectionProfile)
        resolvedScopeSourceRevisionIDs = value.resolvedScopeSourceRevisionIDs.map(
            \.canonicalValue
        )
        targetSourceRevisionIDs = value.targetSourceRevisionIDs.map(\.canonicalValue)
        referenceSourceRevisionIDs = value.referenceSourceRevisionIDs.map(\.canonicalValue)
        maximumEstimatedWorkUnits = value.maximumEstimatedWorkUnits
        totalEstimatedWorkUnits = value.totalEstimatedWorkUnits
        steps = value.steps.map(GlifiStudioAnalysisPlanStep.init)
        decisions = value.decisions.map(GlifiStudioAnalysisCapabilityDecision.init)
        unresolvedReasonIdentifiers = value.unresolvedReasonIdentifiers
    }
}

/// Persisted plan result shared by native presentation and machine clients.
public struct GlifiStudioAnalysisPlanResult: Codable, Equatable, Sendable {
    /// Stable project identity.
    public let projectID: String
    /// Exact project generation evaluated by the planner.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the plan Artifact.
    public let generation: Int
    /// Immutable plan Artifact identity.
    public let artifactID: String
    /// Semantic planner-node identity.
    public let analysisNodeID: String
    /// Complete presentation-independent plan.
    public let plan: GlifiStudioAnalysisPlan

    init(_ value: GlifiProjectAnalysisPlanResult) {
        projectID = value.projectID.canonicalValue
        sourceGeneration = value.sourceGeneration
        generation = value.generation
        artifactID = value.artifactID.canonicalValue
        analysisNodeID = value.analysisNodeID.canonicalValue
        plan = GlifiStudioAnalysisPlan(value.plan)
    }
}

extension GlifiStudioAnalysisPlanRequest {
    func coreValue() throws -> GlifiAnalysisPlanRequest {
        guard let intent = GlifiAnalyticalIntent(rawValue: intent) else {
            throw planRequestFailure("planner.invalid-intent")
        }
        do {
            return try GlifiAnalysisPlanRequest(
                intent: intent,
                scopeSourceRevisionIDs: scopeSourceRevisionIDs.map(
                    SourceRevisionID.init(canonicalValue:)
                ),
                targetSourceRevisionIDs: targetSourceRevisionIDs.map(
                    SourceRevisionID.init(canonicalValue:)
                ),
                referenceSourceRevisionIDs: referenceSourceRevisionIDs.map(
                    SourceRevisionID.init(canonicalValue:)
                ),
                maximumEstimatedWorkUnits: maximumEstimatedWorkUnits
            )
        } catch let failure as GlifiFailure where failure.code.hasPrefix("identifier.") {
            throw planRequestFailure("planner.invalid-source-identifier")
        }
    }
}

private func planRequestFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: .invalidInput,
        operation: .plan,
        retryDisposition: .afterCorrection,
        retainedState: .lastCommittedGeneration,
        messageKey: "failure.\(code)"
    )
}
