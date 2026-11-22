// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Stable, localizable analytical intentions understood by the planner.
public enum GlifiAnalyticalIntent: String, Codable, CaseIterable, Sendable {
    case understandCollection = "understand.collection"
    case discoverContents = "discover.contents"
    case identifyThemes = "identify.themes"
    case characterizeGroup = "characterize.group"
    case compareObjects = "compare.objects"
    case traceChange = "trace.change"
    case exploreRelationships = "explore.relationships"
    case findSimilar = "find.similar"
    case exploreObject = "explore.object"
    case searchSources = "search.sources"
    case reviewCompletely = "review.completely"
}

/// Methodological outcome of evaluating one capability for one request.
public enum GlifiPlannerApplicability: String, Codable, Equatable, Sendable {
    case applicable
    case conditional
    case notApplicable
    case unavailable
    case deferred
}

/// Aggregate readiness of one immutable plan revision.
public enum GlifiAnalysisPlanStatus: String, Codable, Equatable, Sendable {
    case ready
    case readyWithCaveats
    case notExecutable
}

/// Executable operation represented by one plan step.
public enum GlifiPlannedOperation: String, Codable, Equatable, Sendable {
    case analyzeCorpus
    case compareKeyness
    case analyzeAssociation
    case analyzeWindowCollocations
    case analyzeWindowNetwork
    case analyzeCorrespondence
    case clusterDocuments
    case compareSimilarity
    case compareGroupMetric
}

/// Semantic role of a selected population in a plan step.
public enum GlifiAnalysisPlanStepRole: String, Codable, Equatable, Sendable {
    case scope
    case target
    case reference
    case comparison
}

/// Versioned declaration of one analytical capability admitted by the MVP planner.
public struct GlifiAnalysisCapabilityDescriptor: Codable, Equatable, Sendable {
    /// Stable catalog identity.
    public let identifier: String
    /// Capability contract version.
    public let version: Int
    /// Scientific family represented by the capability.
    public let familyIdentifier: String
    /// Exact implemented method variants.
    public let methodIdentifiers: [String]
    /// User intentions for which the capability can be informative.
    public let supportedIntents: [GlifiAnalyticalIntent]
    /// Semantic input types required by the capability.
    public let inputTypeIdentifiers: [String]
    /// Persisted output schema produced by execution.
    public let outputSchemaIdentifier: String
    /// Smallest valid number of source revisions.
    public let minimumSourceCount: Int
    /// Stable methodological and data preconditions.
    public let preconditionIdentifiers: [String]
    /// Stable minimum input-quality requirements.
    public let qualityRequirementIdentifiers: [String]
    /// Whether explicit target and reference populations are required.
    public let requiresComparisonGroups: Bool
    /// Capability families expanded into execution dependencies.
    public let dependencyCapabilityIdentifiers: [String]
    /// Versioned rule that decides methodological applicability.
    public let applicabilityRuleIdentifier: String
    /// Versioned deterministic work-estimation formula.
    public let costModelIdentifier: String
    /// Resource strategy implemented by the current backend.
    public let executionStrategyIdentifier: String
    /// Backend used by the capability.
    public let backendIdentifier: String
    /// Ordered equivalent backends available if the primary is unavailable.
    public let fallbackBackendIdentifiers: [String]
    /// Reproducibility class of the result.
    public let determinismClass: GlifiDeterminismClass
    /// Numeric precision and reduction contract.
    public let numericPolicyIdentifier: String
    /// Linguistic contracts required by execution.
    public let linguisticProfileIdentifiers: [String]
    /// Stable limitations that presentation clients can explain.
    public let limitationIdentifiers: [String]
}

/// One source fact used by the pure planner without filesystem access.
public struct GlifiPlanningSource: Equatable, Sendable {
    /// Immutable source revision used in the plan.
    public let sourceRevisionID: SourceRevisionID
    /// Validated source representation.
    public let format: GlifiTextFormat
    /// Observed exact source byte count.
    public let byteCount: Int

    /// Creates one validated planning fact.
    public init(
        sourceRevisionID: SourceRevisionID,
        format: GlifiTextFormat,
        byteCount: Int
    ) throws {
        guard byteCount >= 0 else {
            throw plannerFailure("planner.invalid-source-size")
        }
        self.sourceRevisionID = sourceRevisionID
        self.format = format
        self.byteCount = byteCount
    }
}

/// Canonical format distribution observed in the selected collection.
public struct GlifiPlanningFormatCount: Codable, Equatable, Sendable {
    /// Stable source-format identifier.
    public let formatIdentifier: String
    /// Number of source revisions in this format.
    public let sourceCount: Int
    /// Sum of exact source bytes in this format.
    public let byteCount: Int64
}

/// Bounded observed collection facts available before analytical execution.
public struct GlifiCollectionPlanningProfile: Codable, Equatable, Sendable {
    /// Versioned profile contract.
    public let profileIdentifier: String
    /// Authoritative root of all project sources.
    public let sourceRootDigest: String
    /// Canonically ordered revisions in the resolved scope.
    public let sourceRevisionIDs: [SourceRevisionID]
    /// Number of revisions in the scope.
    public let sourceCount: Int
    /// Exact sum of source bytes in the scope.
    public let totalSourceByteCount: Int64
    /// Canonically ordered observed format distribution.
    public let formatCounts: [GlifiPlanningFormatCount]
    /// Explicit language configuration used for capability matching.
    public let configuredLanguageCode: String
    /// Epistemic class of the profile values.
    public let observationClassIdentifier: String
}

/// User-owned, capability-neutral input to the deterministic planner.
public struct GlifiAnalysisPlanRequest: Equatable, Sendable {
    /// Default bounded work budget of the MVP planner.
    public static let standardMaximumEstimatedWorkUnits: Int64 = 1_073_741_824

    /// Stable user intention to satisfy.
    public let intent: GlifiAnalyticalIntent
    /// Empty means the planner must resolve the complete current source set explicitly.
    public let scopeSourceRevisionIDs: [SourceRevisionID]
    /// Explicit target population for comparative capabilities.
    public let targetSourceRevisionIDs: [SourceRevisionID]
    /// Explicit reference population for comparative capabilities.
    public let referenceSourceRevisionIDs: [SourceRevisionID]
    /// Maximum aggregate cost admitted by the request.
    public let maximumEstimatedWorkUnits: Int64

    /// Creates and canonicalizes a bounded planner request.
    public init(
        intent: GlifiAnalyticalIntent,
        scopeSourceRevisionIDs: [SourceRevisionID] = [],
        targetSourceRevisionIDs: [SourceRevisionID] = [],
        referenceSourceRevisionIDs: [SourceRevisionID] = [],
        maximumEstimatedWorkUnits: Int64 = Self.standardMaximumEstimatedWorkUnits
    ) throws {
        guard maximumEstimatedWorkUnits >= 0 else {
            throw plannerFailure("planner.invalid-work-budget")
        }
        guard scopeSourceRevisionIDs.count <= GlifiAnalysisPlanner.maximumSourceCount,
            targetSourceRevisionIDs.count <= GlifiAnalysisPlanner.maximumSourceCount,
            referenceSourceRevisionIDs.count <= GlifiAnalysisPlanner.maximumSourceCount
        else {
            throw plannerFailure("planner.source-limit-exceeded", category: .insufficientResources)
        }
        self.intent = intent
        self.scopeSourceRevisionIDs = try canonicalSourceIDs(scopeSourceRevisionIDs)
        self.targetSourceRevisionIDs = try canonicalSourceIDs(targetSourceRevisionIDs)
        self.referenceSourceRevisionIDs = try canonicalSourceIDs(referenceSourceRevisionIDs)
        self.maximumEstimatedWorkUnits = maximumEstimatedWorkUnits
    }
}

/// Explainable decision for one capability in the immutable catalog snapshot.
public struct GlifiAnalysisCapabilityDecision: Codable, Equatable, Sendable {
    /// Capability evaluated by this decision.
    public let capabilityIdentifier: String
    /// Methodological and operational outcome.
    public let applicability: GlifiPlannerApplicability
    /// Whether execution steps were admitted to the plan.
    public let isIncluded: Bool
    /// Stable explanation codes for the outcome.
    public let reasonIdentifiers: [String]
    /// Stable limitations that remain on an included capability.
    public let caveatIdentifiers: [String]
    /// Backend selected for admitted execution, if any.
    public let selectedBackendIdentifier: String?
    /// Explicit ordered fallback chain, empty when none is approved.
    public let fallbackIdentifiers: [String]
    /// Estimated atomic bundle cost when it is meaningful.
    public let estimatedWorkUnits: Int64?
}

/// Canonical executable unit selected by one plan revision.
public struct GlifiAnalysisPlanStep: Codable, Equatable, Sendable {
    /// Stable identity within this plan revision.
    public let identifier: String
    /// Zero-based canonical execution order.
    public let order: Int
    /// Capability whose implementation executes the step.
    public let capabilityIdentifier: String
    /// Headless operation selected for execution.
    public let operation: GlifiPlannedOperation
    /// Population role of this step.
    public let role: GlifiAnalysisPlanStepRole
    /// Canonically ordered immutable inputs.
    public let sourceRevisionIDs: [SourceRevisionID]
    /// Earlier plan steps required by this step.
    public let dependencyStepIdentifiers: [String]
    /// Deterministic integer work estimate.
    public let estimatedWorkUnits: Int64
    /// Expected persisted output schema.
    public let outputSchemaIdentifier: String
    /// Stable limitations that execution and presentation must preserve.
    public let caveatIdentifiers: [String]
}

/// Reproducible planner output, including exclusions and unresolved conditions.
public struct GlifiAnalysisPlan: Codable, Equatable, Sendable {
    /// Exact planner algorithm identity.
    public let plannerIdentifier: String
    /// Immutable capability catalog used for the decision.
    public let capabilityCatalogIdentifier: String
    /// Stable user intention evaluated by the plan.
    public let intent: GlifiAnalyticalIntent
    /// Aggregate readiness derived from all decisions.
    public let status: GlifiAnalysisPlanStatus
    /// Observed collection facts used by applicability rules.
    public let collectionProfile: GlifiCollectionPlanningProfile
    /// Explicit scope resolved before persistence.
    public let resolvedScopeSourceRevisionIDs: [SourceRevisionID]
    /// Explicit target group resolved before persistence.
    public let targetSourceRevisionIDs: [SourceRevisionID]
    /// Explicit reference group resolved before persistence.
    public let referenceSourceRevisionIDs: [SourceRevisionID]
    /// Work budget applied by the planner.
    public let maximumEstimatedWorkUnits: Int64
    /// Sum of admitted step estimates.
    public let totalEstimatedWorkUnits: Int64
    /// Canonically ordered executable steps.
    public let steps: [GlifiAnalysisPlanStep]
    /// Decision for every capability in the catalog.
    public let decisions: [GlifiAnalysisCapabilityDecision]
    /// Stable questions or absences that prevented a complete plan.
    public let unresolvedReasonIdentifiers: [String]
}

/// Pure deterministic `planner-mvp-v1` implementation.
public struct GlifiAnalysisPlanner: Sendable {
    /// Largest source set admitted before sorting or set construction.
    public static let maximumSourceCount = 10_000
    /// Exact deterministic planner contract.
    public static let plannerIdentifier = "planner-v2"
    /// Exact immutable capability-catalog contract.
    public static let capabilityCatalogIdentifier = "capability-catalog-v2"
    /// Catalog identity of the descriptive corpus profile.
    public static let corpusProfileCapabilityIdentifier =
        "studio.glifi.capability.corpus-profile.v1"
    /// Catalog identity of two-group keyness.
    public static let keynessCapabilityIdentifier = "studio.glifi.capability.keyness.v1"

    /// Immutable catalog admitted by the product baseline.
    public static let capabilities: [GlifiAnalysisCapabilityDescriptor] =
        [
            GlifiAnalysisCapabilityDescriptor(
                identifier: corpusProfileCapabilityIdentifier,
                version: 1,
                familyIdentifier: "descriptive-corpus-profile",
                methodIdentifiers: [GlifiCorpusAnalyzer.analysisIdentifier],
                supportedIntents: [
                    .characterizeGroup,
                    .discoverContents,
                    .reviewCompletely,
                    .understandCollection,
                ],
                inputTypeIdentifiers: ["source-revision.v1"],
                outputSchemaIdentifier: GlifiCorpusAnalysisArtifactPayload.outputSchemaIdentifier,
                minimumSourceCount: 1,
                preconditionIdentifiers: ["planner.precondition.nonempty-scope"],
                qualityRequirementIdentifiers: ["planner.quality.strict-utf8-source"],
                requiresComparisonGroups: false,
                dependencyCapabilityIdentifiers: [],
                applicabilityRuleIdentifier: "corpus-profile-applicability-v1",
                costModelIdentifier: "source-bytes-plus-64-per-source-v1",
                executionStrategyIdentifier: "bounded-in-memory-v1",
                backendIdentifier: "swift-reference-v1",
                fallbackBackendIdentifiers: [],
                determinismClass: .d1,
                numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
                linguisticProfileIdentifiers: [GlifiItalianTokenizer.contractIdentifier],
                limitationIdentifiers: ["planner.limit.bounded-memory"]
            ),
            GlifiAnalysisCapabilityDescriptor(
                identifier: keynessCapabilityIdentifier,
                version: 1,
                familyIdentifier: "two-group-keyness",
                methodIdentifiers: [GlifiKeynessAnalyzer.comparisonIdentifier],
                supportedIntents: [
                    .characterizeGroup,
                    .compareObjects,
                    .reviewCompletely,
                ],
                inputTypeIdentifiers: [
                    "source-revision-group.target.v1", "source-revision-group.reference.v1",
                ],
                outputSchemaIdentifier: GlifiKeynessArtifactPayload.outputSchemaIdentifier,
                minimumSourceCount: 2,
                preconditionIdentifiers: [
                    "planner.precondition.disjoint-groups",
                    "planner.precondition.nonempty-token-populations",
                ],
                qualityRequirementIdentifiers: [
                    "planner.quality.strict-utf8-source",
                    "planner.quality.low-expected-count-disclosed",
                ],
                requiresComparisonGroups: true,
                dependencyCapabilityIdentifiers: [corpusProfileCapabilityIdentifier],
                applicabilityRuleIdentifier: "keyness-two-disjoint-groups-applicability-v1",
                costModelIdentifier: "two-profiles-plus-comparison-v1",
                executionStrategyIdentifier: "bounded-in-memory-v1",
                backendIdentifier: "swift-reference-v1",
                fallbackBackendIdentifiers: [],
                determinismClass: .d1,
                numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
                linguisticProfileIdentifiers: [GlifiItalianTokenizer.contractIdentifier],
                limitationIdentifiers: [
                    "planner.limit.asymptotic-low-count-caveat",
                    "planner.limit.bounded-memory",
                ]
            ),
        ] + extendedCapabilities.map(\.descriptor)

    /// Capabilities of the post-0.1 analytical increment (ADR-0025), in catalog order.
    static let extendedCapabilities: [ExtendedCapability] = [
        ExtendedCapability(
            identifier: "studio.glifi.capability.document-term-association.v1",
            family: "contingency-association",
            method: GlifiCorpusAssociationAnalysis.analysisIdentifier,
            intents: [.exploreRelationships, .reviewCompletely],
            minimumSourceCount: 2,
            requiresGroups: false,
            operation: .analyzeAssociation,
            outputSchema: GlifiCorpusAssociationAnalysis.outputSchemaIdentifier,
            costPerSource: 256,
            caveats: ["planner.caveat.low-expected-counts-disclosed"]
        ),
        ExtendedCapability(
            identifier: "studio.glifi.capability.window-collocation.v1",
            family: "cooccurrence-collocation",
            method: GlifiWindowCollocationAnalysis.analysisIdentifier,
            intents: [.discoverContents, .exploreRelationships, .reviewCompletely],
            minimumSourceCount: 1,
            requiresGroups: false,
            operation: .analyzeWindowCollocations,
            outputSchema: GlifiWindowCollocationAnalysis.outputSchemaIdentifier,
            costPerSource: 512,
            caveats: ["planner.caveat.cooccurring-pairs-required"]
        ),
        ExtendedCapability(
            identifier: "studio.glifi.capability.window-network.v1",
            family: "lexical-network",
            method: GlifiWindowNetworkAnalysis.analysisIdentifier,
            intents: [.exploreRelationships, .identifyThemes, .reviewCompletely],
            minimumSourceCount: 1,
            requiresGroups: false,
            operation: .analyzeWindowNetwork,
            outputSchema: GlifiWindowNetworkAnalysis.outputSchemaIdentifier,
            costPerSource: 1_024,
            caveats: ["planner.caveat.cooccurring-pairs-required"]
        ),
        ExtendedCapability(
            identifier: "studio.glifi.capability.correspondence-analysis.v1",
            family: "correspondence-analysis",
            method: GlifiCorrespondenceResult.identifier,
            intents: [.exploreRelationships, .identifyThemes, .reviewCompletely],
            minimumSourceCount: 2,
            requiresGroups: false,
            operation: .analyzeCorrespondence,
            outputSchema: GlifiCorpusMultivariateAnalysis.outputSchemaIdentifier,
            costPerSource: 512,
            caveats: ["planner.caveat.nonzero-inertia-required"]
        ),
        ExtendedCapability(
            identifier: "studio.glifi.capability.document-clustering.v1",
            family: "hierarchical-clustering",
            method: GlifiHierarchicalClustering.identifier,
            intents: [.findSimilar, .identifyThemes, .reviewCompletely],
            minimumSourceCount: 3,
            requiresGroups: false,
            operation: .clusterDocuments,
            outputSchema: GlifiCorpusMultivariateAnalysis.outputSchemaIdentifier,
            costPerSource: 512,
            caveats: ["planner.caveat.nonempty-documents-required"]
        ),
        ExtendedCapability(
            identifier: "studio.glifi.capability.group-similarity.v1",
            family: "similarity-distance",
            method: GlifiCorpusSimilarityAnalyzer.comparisonIdentifier,
            intents: [.compareObjects, .findSimilar, .reviewCompletely],
            minimumSourceCount: 2,
            requiresGroups: true,
            operation: .compareSimilarity,
            outputSchema: GlifiCorpusSimilarityArtifactPayload.outputSchemaIdentifier,
            costPerSource: 128,
            caveats: ["planner.caveat.nonempty-token-populations-required"]
        ),
        ExtendedCapability(
            identifier: "studio.glifi.capability.group-location-comparison.v1",
            family: "statistical-foundation",
            method: GlifiGroupMetricComparison.analysisIdentifier,
            intents: [.compareObjects, .reviewCompletely],
            minimumSourceCount: 2,
            requiresGroups: true,
            operation: .compareGroupMetric,
            outputSchema: GlifiGroupMetricComparison.outputSchemaIdentifier,
            costPerSource: 2_048,
            caveats: ["planner.caveat.small-groups-limit-inference"]
        ),
    ]

    /// Creates a stateless planner over the immutable MVP catalog.
    public init() {}

    /// Produces the same canonical plan for the same request, source facts, and policy.
    public func plan(
        request: GlifiAnalysisPlanRequest,
        sourceRootDigest: String,
        configuredLanguageCode: String,
        sources: [GlifiPlanningSource]
    ) throws -> GlifiAnalysisPlan {
        try Task.checkCancellation()
        guard isSHA256Digest(sourceRootDigest), !configuredLanguageCode.isEmpty else {
            throw plannerFailure("planner.invalid-collection-profile")
        }
        guard sources.count <= Self.maximumSourceCount else {
            throw plannerFailure("planner.source-limit-exceeded", category: .insufficientResources)
        }
        let orderedSources = sources.sorted {
            $0.sourceRevisionID.canonicalValue < $1.sourceRevisionID.canonicalValue
        }
        guard Set(orderedSources.map(\.sourceRevisionID)).count == orderedSources.count else {
            throw plannerFailure("planner.duplicate-project-source", category: .invariantViolation)
        }
        let sourceByID = Dictionary(
            uniqueKeysWithValues: orderedSources.map { ($0.sourceRevisionID, $0) }
        )
        let scopeIDs =
            request.scopeSourceRevisionIDs.isEmpty
            ? orderedSources.map(\.sourceRevisionID) : request.scopeSourceRevisionIDs
        try validateKnown(scopeIDs, sourceByID: sourceByID)
        try validateKnown(request.targetSourceRevisionIDs, sourceByID: sourceByID)
        try validateKnown(request.referenceSourceRevisionIDs, sourceByID: sourceByID)
        let scopeSet = Set(scopeIDs)
        guard Set(request.targetSourceRevisionIDs).isSubset(of: scopeSet),
            Set(request.referenceSourceRevisionIDs).isSubset(of: scopeSet)
        else {
            throw plannerFailure("planner.group-outside-scope")
        }

        let scopedSources = scopeIDs.compactMap { sourceByID[$0] }
        let targetSources = request.targetSourceRevisionIDs.compactMap { sourceByID[$0] }
        let referenceSources = request.referenceSourceRevisionIDs.compactMap { sourceByID[$0] }
        let collectionProfile = try collectionProfile(
            sourceRootDigest: sourceRootDigest,
            languageCode: configuredLanguageCode,
            sources: scopedSources
        )
        let profileRelevant = Self.profileIntents.contains(request.intent)
        let keynessRelevant = Self.keynessIntents.contains(request.intent)
        let groupsComplete = !targetSources.isEmpty && !referenceSources.isEmpty
        let groupsDisjoint = Set(request.targetSourceRevisionIDs).isDisjoint(
            with: request.referenceSourceRevisionIDs
        )
        let supportsConfiguredLanguage = configuredLanguageCode == "it"
        let scopeFitsExecutionLimits = selectionFitsExecutionLimits(scopedSources)
        let comparisonFitsExecutionLimits =
            selectionFitsExecutionLimits(targetSources)
            && selectionFitsExecutionLimits(referenceSources)

        let profileCost = try estimatedProfileCost(scopedSources)
        let targetProfileCost = try estimatedProfileCost(targetSources)
        let referenceProfileCost = try estimatedProfileCost(referenceSources)
        let keynessOwnCost = try estimatedKeynessCost(targetSources + referenceSources)
        let keynessBundleCost = try checkedSum([
            targetProfileCost,
            referenceProfileCost,
            keynessOwnCost,
        ])

        var remainingBudget = request.maximumEstimatedWorkUnits
        var steps: [GlifiAnalysisPlanStep] = []
        var profileDecision: GlifiAnalysisCapabilityDecision
        if !profileRelevant {
            profileDecision = decision(
                capability: Self.corpusProfileCapabilityIdentifier,
                applicability: .notApplicable,
                reason: "planner.intent-not-supported"
            )
        } else if scopedSources.isEmpty {
            profileDecision = decision(
                capability: Self.corpusProfileCapabilityIdentifier,
                applicability: .notApplicable,
                reason: "planner.empty-scope"
            )
        } else if !supportsConfiguredLanguage {
            profileDecision = decision(
                capability: Self.corpusProfileCapabilityIdentifier,
                applicability: .unavailable,
                reason: "planner.linguistic-profile-unavailable"
            )
        } else if !scopeFitsExecutionLimits {
            profileDecision = decision(
                capability: Self.corpusProfileCapabilityIdentifier,
                applicability: .deferred,
                reason: "planner.execution-limit-exceeded",
                estimatedWorkUnits: profileCost
            )
        } else if profileCost > remainingBudget {
            profileDecision = decision(
                capability: Self.corpusProfileCapabilityIdentifier,
                applicability: .deferred,
                reason: "planner.work-budget-exceeded",
                estimatedWorkUnits: profileCost
            )
        } else {
            profileDecision = decision(
                capability: Self.corpusProfileCapabilityIdentifier,
                applicability: .applicable,
                reason: "planner.intent-supported",
                isIncluded: true,
                estimatedWorkUnits: profileCost
            )
            remainingBudget -= profileCost
            steps.append(
                step(
                    identifier: "plan-step.corpus-profile.scope.v1",
                    capability: Self.corpusProfileCapabilityIdentifier,
                    operation: .analyzeCorpus,
                    role: .scope,
                    sources: scopeIDs,
                    dependencies: [],
                    cost: profileCost,
                    outputSchema: GlifiCorpusAnalysisArtifactPayload.outputSchemaIdentifier
                )
            )
        }

        let keynessDecision: GlifiAnalysisCapabilityDecision
        if !keynessRelevant {
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .notApplicable,
                reason: "planner.intent-not-supported"
            )
        } else if !groupsComplete {
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .notApplicable,
                reason: "planner.comparison-groups-required"
            )
        } else if !groupsDisjoint {
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .notApplicable,
                reason: "planner.comparison-groups-must-be-disjoint"
            )
        } else if !supportsConfiguredLanguage {
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .unavailable,
                reason: "planner.linguistic-profile-unavailable"
            )
        } else if !comparisonFitsExecutionLimits {
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .deferred,
                reason: "planner.execution-limit-exceeded",
                estimatedWorkUnits: keynessBundleCost
            )
        } else if keynessBundleCost > remainingBudget {
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .deferred,
                reason: "planner.work-budget-exceeded",
                estimatedWorkUnits: keynessBundleCost
            )
        } else {
            let targetStepID = "plan-step.corpus-profile.target.v1"
            let referenceStepID = "plan-step.corpus-profile.reference.v1"
            if !profileRelevant {
                profileDecision = decision(
                    capability: Self.corpusProfileCapabilityIdentifier,
                    applicability: .applicable,
                    reason: "planner.dependency-required",
                    isIncluded: true,
                    estimatedWorkUnits: try checkedSum([
                        targetProfileCost,
                        referenceProfileCost,
                    ])
                )
            }
            keynessDecision = decision(
                capability: Self.keynessCapabilityIdentifier,
                applicability: .conditional,
                reason: "planner.comparison-groups-valid",
                caveats: ["planner.nonempty-token-populations-required"],
                isIncluded: true,
                estimatedWorkUnits: keynessBundleCost
            )
            steps.append(
                step(
                    identifier: targetStepID,
                    capability: Self.corpusProfileCapabilityIdentifier,
                    operation: .analyzeCorpus,
                    role: .target,
                    sources: request.targetSourceRevisionIDs,
                    dependencies: [],
                    cost: targetProfileCost,
                    outputSchema: GlifiCorpusAnalysisArtifactPayload.outputSchemaIdentifier
                )
            )
            steps.append(
                step(
                    identifier: referenceStepID,
                    capability: Self.corpusProfileCapabilityIdentifier,
                    operation: .analyzeCorpus,
                    role: .reference,
                    sources: request.referenceSourceRevisionIDs,
                    dependencies: [],
                    cost: referenceProfileCost,
                    outputSchema: GlifiCorpusAnalysisArtifactPayload.outputSchemaIdentifier
                )
            )
            steps.append(
                step(
                    identifier: "plan-step.keyness.comparison.v1",
                    capability: Self.keynessCapabilityIdentifier,
                    operation: .compareKeyness,
                    role: .comparison,
                    sources: request.targetSourceRevisionIDs + request.referenceSourceRevisionIDs,
                    dependencies: [targetStepID, referenceStepID],
                    cost: keynessOwnCost,
                    outputSchema: GlifiKeynessArtifactPayload.outputSchemaIdentifier,
                    caveats: ["planner.nonempty-token-populations-required"]
                )
            )
        }

        var decisions = [profileDecision, keynessDecision]
        for capability in Self.extendedCapabilities {
            let groups = capability.requiresGroups
            let sources = groups ? targetSources + referenceSources : scopedSources
            let cost = try checkedSum([
                try estimatedProfileCost(sources),
                try checkedProduct(Int64(sources.count), capability.costPerSource),
            ])
            let result: GlifiAnalysisCapabilityDecision
            if !capability.intents.contains(request.intent) {
                result = decision(
                    capability: capability.identifier,
                    applicability: .notApplicable,
                    reason: "planner.intent-not-supported"
                )
            } else if groups && !groupsComplete {
                result = decision(
                    capability: capability.identifier,
                    applicability: .notApplicable,
                    reason: "planner.comparison-groups-required"
                )
            } else if groups && !groupsDisjoint {
                result = decision(
                    capability: capability.identifier,
                    applicability: .notApplicable,
                    reason: "planner.comparison-groups-must-be-disjoint"
                )
            } else if sources.count < capability.minimumSourceCount {
                result = decision(
                    capability: capability.identifier,
                    applicability: .notApplicable,
                    reason: "planner.insufficient-sources"
                )
            } else if !supportsConfiguredLanguage {
                result = decision(
                    capability: capability.identifier,
                    applicability: .unavailable,
                    reason: "planner.linguistic-profile-unavailable"
                )
            } else if groups
                ? !comparisonFitsExecutionLimits : !scopeFitsExecutionLimits
            {
                result = decision(
                    capability: capability.identifier,
                    applicability: .deferred,
                    reason: "planner.execution-limit-exceeded",
                    estimatedWorkUnits: cost
                )
            } else if cost > remainingBudget {
                result = decision(
                    capability: capability.identifier,
                    applicability: .deferred,
                    reason: "planner.work-budget-exceeded",
                    estimatedWorkUnits: cost
                )
            } else {
                remainingBudget -= cost
                result = decision(
                    capability: capability.identifier,
                    applicability: .conditional,
                    reason: "planner.intent-supported",
                    caveats: capability.caveats,
                    isIncluded: true,
                    estimatedWorkUnits: cost
                )
                steps.append(
                    step(
                        identifier: capability.stepIdentifier,
                        capability: capability.identifier,
                        operation: capability.operation,
                        role: groups ? .comparison : .scope,
                        sources: groups
                            ? request.targetSourceRevisionIDs + request.referenceSourceRevisionIDs
                            : scopeIDs,
                        dependencies: [],
                        cost: cost,
                        outputSchema: capability.outputSchema,
                        caveats: capability.caveats
                    )
                )
            }
            decisions.append(result)
        }
        let totalCost = try checkedSum(steps.map(\.estimatedWorkUnits))
        let unresolved = unresolvedReasons(
            intent: request.intent,
            decisions: decisions
        )
        let status: GlifiAnalysisPlanStatus
        if steps.isEmpty {
            status = .notExecutable
        } else if decisions.contains(where: { $0.applicability == .conditional })
            || !unresolved.isEmpty
        {
            status = .readyWithCaveats
        } else {
            status = .ready
        }
        return GlifiAnalysisPlan(
            plannerIdentifier: Self.plannerIdentifier,
            capabilityCatalogIdentifier: Self.capabilityCatalogIdentifier,
            intent: request.intent,
            status: status,
            collectionProfile: collectionProfile,
            resolvedScopeSourceRevisionIDs: scopeIDs,
            targetSourceRevisionIDs: request.targetSourceRevisionIDs,
            referenceSourceRevisionIDs: request.referenceSourceRevisionIDs,
            maximumEstimatedWorkUnits: request.maximumEstimatedWorkUnits,
            totalEstimatedWorkUnits: totalCost,
            steps: steps.enumerated().map { offset, value in
                GlifiAnalysisPlanStep(
                    identifier: value.identifier,
                    order: offset,
                    capabilityIdentifier: value.capabilityIdentifier,
                    operation: value.operation,
                    role: value.role,
                    sourceRevisionIDs: value.sourceRevisionIDs,
                    dependencyStepIdentifiers: value.dependencyStepIdentifiers,
                    estimatedWorkUnits: value.estimatedWorkUnits,
                    outputSchemaIdentifier: value.outputSchemaIdentifier,
                    caveatIdentifiers: value.caveatIdentifiers
                )
            },
            decisions: decisions,
            unresolvedReasonIdentifiers: unresolved
        )
    }

    private static let profileIntents: Set<GlifiAnalyticalIntent> = [
        .understandCollection, .discoverContents, .characterizeGroup, .reviewCompletely,
    ]
    private static let keynessIntents: Set<GlifiAnalyticalIntent> = [
        .characterizeGroup, .compareObjects, .reviewCompletely,
    ]

    private func collectionProfile(
        sourceRootDigest: String,
        languageCode: String,
        sources: [GlifiPlanningSource]
    ) throws -> GlifiCollectionPlanningProfile {
        var counts: [GlifiTextFormat: (count: Int, bytes: Int64)] = [:]
        for source in sources {
            let byteCount = Int64(source.byteCount)
            let previous = counts[source.format, default: (0, 0)]
            counts[source.format] = (
                previous.count + 1,
                try checkedSum([previous.bytes, byteCount])
            )
        }
        let formats = counts.map { format, value in
            GlifiPlanningFormatCount(
                formatIdentifier: format.rawValue,
                sourceCount: value.count,
                byteCount: value.bytes
            )
        }.sorted { $0.formatIdentifier < $1.formatIdentifier }
        return GlifiCollectionPlanningProfile(
            profileIdentifier: "collection-planning-profile-v1",
            sourceRootDigest: sourceRootDigest,
            sourceRevisionIDs: sources.map(\.sourceRevisionID),
            sourceCount: sources.count,
            totalSourceByteCount: try checkedSum(sources.map { Int64($0.byteCount) }),
            formatCounts: formats,
            configuredLanguageCode: languageCode,
            observationClassIdentifier: "observed-project-metadata-v1"
        )
    }

    private func estimatedProfileCost(_ sources: [GlifiPlanningSource]) throws -> Int64 {
        try checkedSum([
            try checkedSum(sources.map { Int64($0.byteCount) }),
            try checkedProduct(Int64(sources.count), 64),
        ])
    }

    private func estimatedKeynessCost(_ sources: [GlifiPlanningSource]) throws -> Int64 {
        try checkedSum([
            try checkedSum(sources.map { Int64($0.byteCount) }),
            try checkedProduct(Int64(sources.count), 128),
        ])
    }

    private func selectionFitsExecutionLimits(_ sources: [GlifiPlanningSource]) -> Bool {
        let options = GlifiCorpusAnalysisOptions.standard
        guard sources.count <= options.maximumDocumentCount else { return false }
        var bytes = 0
        for source in sources {
            let sum = bytes.addingReportingOverflow(source.byteCount)
            guard !sum.overflow, sum.partialValue <= options.maximumSourceByteCount else {
                return false
            }
            bytes = sum.partialValue
        }
        return true
    }

    private func validateKnown(
        _ identifiers: [SourceRevisionID],
        sourceByID: [SourceRevisionID: GlifiPlanningSource]
    ) throws {
        guard identifiers.allSatisfy({ sourceByID[$0] != nil }) else {
            throw plannerFailure("planner.source-not-found")
        }
    }

    private func decision(
        capability: String,
        applicability: GlifiPlannerApplicability,
        reason: String,
        caveats: [String] = [],
        isIncluded: Bool = false,
        estimatedWorkUnits: Int64? = nil
    ) -> GlifiAnalysisCapabilityDecision {
        GlifiAnalysisCapabilityDecision(
            capabilityIdentifier: capability,
            applicability: applicability,
            isIncluded: isIncluded,
            reasonIdentifiers: [reason],
            caveatIdentifiers: caveats,
            selectedBackendIdentifier: isIncluded ? "swift-reference-v1" : nil,
            fallbackIdentifiers: [],
            estimatedWorkUnits: estimatedWorkUnits
        )
    }

    private func step(
        identifier: String,
        capability: String,
        operation: GlifiPlannedOperation,
        role: GlifiAnalysisPlanStepRole,
        sources: [SourceRevisionID],
        dependencies: [String],
        cost: Int64,
        outputSchema: String,
        caveats: [String] = []
    ) -> GlifiAnalysisPlanStep {
        GlifiAnalysisPlanStep(
            identifier: identifier,
            order: 0,
            capabilityIdentifier: capability,
            operation: operation,
            role: role,
            sourceRevisionIDs: sources,
            dependencyStepIdentifiers: dependencies,
            estimatedWorkUnits: cost,
            outputSchemaIdentifier: outputSchema,
            caveatIdentifiers: caveats
        )
    }

    private func unresolvedReasons(
        intent: GlifiAnalyticalIntent,
        decisions: [GlifiAnalysisCapabilityDecision]
    ) -> [String] {
        if !Self.profileIntents.contains(intent), !Self.keynessIntents.contains(intent),
            !Self.extendedCapabilities.contains(where: { $0.intents.contains(intent) })
        {
            return ["planner.no-capability-for-intent"]
        }
        return decisions.flatMap { decision -> [String] in
            switch decision.applicability {
            case .notApplicable, .unavailable, .deferred:
                return decision.reasonIdentifiers.filter {
                    $0 != "planner.intent-not-supported"
                }
            case .applicable, .conditional:
                return []
            }
        }.sorted()
    }
}

private func canonicalSourceIDs(_ values: [SourceRevisionID]) throws -> [SourceRevisionID] {
    let sorted = values.sorted { $0.canonicalValue < $1.canonicalValue }
    guard Set(sorted).count == sorted.count else {
        throw plannerFailure("planner.duplicate-source")
    }
    return sorted
}

private func checkedSum(_ values: [Int64]) throws -> Int64 {
    try values.reduce(0) { partial, value in
        let result = partial.addingReportingOverflow(value)
        guard !result.overflow else {
            throw plannerFailure("planner.cost-overflow", category: .insufficientResources)
        }
        return result.partialValue
    }
}

private func checkedProduct(_ left: Int64, _ right: Int64) throws -> Int64 {
    let result = left.multipliedReportingOverflow(by: right)
    guard !result.overflow else {
        throw plannerFailure("planner.cost-overflow", category: .insufficientResources)
    }
    return result.partialValue
}

private func plannerFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .plan,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}

/// Declarative description of one capability of the post-0.1 increment (ADR-0025).
struct ExtendedCapability: Sendable {
    let identifier: String
    let family: String
    let method: String
    let intents: Set<GlifiAnalyticalIntent>
    let minimumSourceCount: Int
    let requiresGroups: Bool
    let operation: GlifiPlannedOperation
    let outputSchema: String
    let costPerSource: Int64
    let caveats: [String]

    /// Stable plan-step identity.
    var stepIdentifier: String {
        "plan-step.\(operation.rawValue).\(requiresGroups ? "comparison" : "scope").v1"
    }

    /// Catalog descriptor with the declared planner-chosen parameters.
    var descriptor: GlifiAnalysisCapabilityDescriptor {
        GlifiAnalysisCapabilityDescriptor(
            identifier: identifier,
            version: 1,
            familyIdentifier: family,
            methodIdentifiers: [method],
            supportedIntents: intents.sorted { $0.rawValue < $1.rawValue },
            inputTypeIdentifiers: requiresGroups
                ? ["source-revision-group.target.v1", "source-revision-group.reference.v1"]
                : ["source-revision.v1"],
            outputSchemaIdentifier: outputSchema,
            minimumSourceCount: minimumSourceCount,
            preconditionIdentifiers: requiresGroups
                ? ["planner.precondition.disjoint-groups"]
                : ["planner.precondition.minimum-sources"],
            qualityRequirementIdentifiers: ["planner.quality.strict-utf8-source"],
            requiresComparisonGroups: requiresGroups,
            dependencyCapabilityIdentifiers: [
                GlifiAnalysisPlanner.corpusProfileCapabilityIdentifier
            ],
            applicabilityRuleIdentifier: "\(family)-applicability-v1",
            costModelIdentifier: "profile-plus-\(costPerSource)-per-source-v1",
            executionStrategyIdentifier: "bounded-in-memory-v1",
            backendIdentifier: "swift-reference-v1",
            fallbackBackendIdentifiers: [],
            determinismClass: .d1,
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            linguisticProfileIdentifiers: [GlifiItalianTokenizer.contractIdentifier],
            limitationIdentifiers: ["planner.limit.bounded-memory"] + caveats
        )
    }
}
