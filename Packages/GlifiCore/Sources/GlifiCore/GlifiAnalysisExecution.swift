// SPDX-License-Identifier: BSD-3-Clause

/// Stable phase of a long-running analytical operation.
public enum GlifiOperationProgressPhase: String, Codable, Equatable, Sendable {
    case planning
    case executing
    case finalizing
}

/// Unit represented by a progress observation.
public enum GlifiOperationProgressUnit: String, Codable, Equatable, Sendable {
    case workUnits
    case nodes
    case indeterminate
}

/// Quality of the total used for one progress observation.
public enum GlifiProgressEstimateQuality: String, Codable, Equatable, Sendable {
    case exact
    case estimated
    case indeterminate
}

/// Monotonic, presentation-independent observation of one owned operation.
public struct GlifiOperationProgress: Codable, Equatable, Sendable {
    /// Runtime identity, excluded from analytical identity.
    public let operationID: OperationID
    /// Monotonic event revision for this operation.
    public let revision: Int
    /// Current bounded phase.
    public let phase: GlifiOperationProgressPhase
    /// Current semantic plan step, when execution is inside a node.
    public let planStepIdentifier: String?
    /// Semantic node being executed, when already known.
    public let analysisNodeID: AnalysisNodeID?
    /// Completed work in `unit` within the current phase.
    public let completed: Int64
    /// Stable or estimated phase total, absent only for indeterminate work.
    public let total: Int64?
    /// Measurement unit of `completed` and `total`.
    public let unit: GlifiOperationProgressUnit
    /// Whether the total is exact, estimated, or unavailable.
    public let estimateQuality: GlifiProgressEstimateQuality

    private enum CodingKeys: String, CodingKey {
        case operationID
        case revision
        case phase
        case planStepIdentifier
        case analysisNodeID
        case completed
        case total
        case unit
        case estimateQuality
    }

    /// Creates a validated progress observation.
    public init(
        operationID: OperationID,
        revision: Int,
        phase: GlifiOperationProgressPhase,
        planStepIdentifier: String? = nil,
        analysisNodeID: AnalysisNodeID? = nil,
        completed: Int64,
        total: Int64?,
        unit: GlifiOperationProgressUnit,
        estimateQuality: GlifiProgressEstimateQuality
    ) throws {
        guard revision >= 0, completed >= 0,
            total.map({ $0 >= completed }) ?? (unit == .indeterminate),
            (total == nil) == (estimateQuality == .indeterminate),
            (unit == .indeterminate) == (total == nil)
        else {
            throw GlifiFailure(
                code: "runtime.invalid-progress",
                category: .invariantViolation,
                operation: .executePlan,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.runtime.invalid-progress"
            )
        }
        self.operationID = operationID
        self.revision = revision
        self.phase = phase
        self.planStepIdentifier = planStepIdentifier
        self.analysisNodeID = analysisNodeID
        self.completed = completed
        self.total = total
        self.unit = unit
        self.estimateQuality = estimateQuality
    }

    /// Decodes through the same invariant checks used by runtime producers.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            operationID: container.decode(OperationID.self, forKey: .operationID),
            revision: container.decode(Int.self, forKey: .revision),
            phase: container.decode(GlifiOperationProgressPhase.self, forKey: .phase),
            planStepIdentifier: container.decodeIfPresent(
                String.self,
                forKey: .planStepIdentifier
            ),
            analysisNodeID: container.decodeIfPresent(
                AnalysisNodeID.self,
                forKey: .analysisNodeID
            ),
            completed: container.decode(Int64.self, forKey: .completed),
            total: container.decodeIfPresent(Int64.self, forKey: .total),
            unit: container.decode(GlifiOperationProgressUnit.self, forKey: .unit),
            estimateQuality: container.decode(
                GlifiProgressEstimateQuality.self,
                forKey: .estimateQuality
            )
        )
    }
}

/// Terminal state of one successfully returned plan execution.
public enum GlifiAnalysisExecutionTerminalState: String, Codable, Equatable, Sendable {
    case completed
    case completedWithCaveats
}

/// Durable Artifact produced or reused for one canonical plan step.
public struct GlifiAnalysisExecutionArtifact: Codable, Equatable, Sendable {
    /// Stable step identity within the plan.
    public let planStepIdentifier: String
    /// Operation selected by the planner.
    public let operation: GlifiPlannedOperation
    /// Population role represented by the output.
    public let role: GlifiAnalysisPlanStepRole
    /// Immutable content-addressed output.
    public let artifactID: ArtifactID
    /// Semantic producer identity.
    public let analysisNodeID: AnalysisNodeID
    /// Exact persisted payload contract.
    public let outputSchemaIdentifier: String
}

/// Complete durable result of executing one immutable analysis plan.
public struct GlifiProjectAnalysisExecutionResult: Equatable, Sendable {
    /// Runtime operation identity used by progress and cancellation.
    public let operationID: OperationID
    /// Project that owns the plan and all outputs.
    public let projectID: ProjectID
    /// Generation observed before the plan was persisted or reused.
    public let sourceGeneration: Int
    /// Final authoritative generation containing every returned Artifact.
    public let generation: Int
    /// Persisted plan revision that governed execution.
    public let planArtifactID: ArtifactID
    /// Semantic identity of the persisted plan revision.
    public let planAnalysisNodeID: AnalysisNodeID
    /// Immutable Evidence/Finding/Caveat interpretation Artifact.
    public let interpretationArtifactID: ArtifactID
    /// Semantic identity of the deterministic interpretation node.
    public let interpretationAnalysisNodeID: AnalysisNodeID
    /// Structured interpretation grounded in the returned plan outputs.
    public let interpretation: GlifiAnalysisInterpretation
    /// Planner readiness preserved by the execution result.
    public let planStatus: GlifiAnalysisPlanStatus
    /// Successful terminal state, including methodological caveats.
    public let terminalState: GlifiAnalysisExecutionTerminalState
    /// Runtime profile selected from one immutable system snapshot.
    public let operatingProfile: GlifiOperatingProfile
    /// Parallelism admitted by the runtime policy.
    public let maximumParallelism: Int
    /// Planned aggregate work estimate.
    public let estimatedWorkUnits: Int64
    /// Work represented by all completed plan steps.
    public let completedWorkUnits: Int64
    /// Outputs in canonical plan-step order.
    public let artifacts: [GlifiAnalysisExecutionArtifact]

    /// Creates a successful result after every output has become durable.
    public init(
        operationID: OperationID,
        projectID: ProjectID,
        sourceGeneration: Int,
        generation: Int,
        planArtifactID: ArtifactID,
        planAnalysisNodeID: AnalysisNodeID,
        interpretationArtifactID: ArtifactID,
        interpretationAnalysisNodeID: AnalysisNodeID,
        interpretation: GlifiAnalysisInterpretation,
        planStatus: GlifiAnalysisPlanStatus,
        terminalState: GlifiAnalysisExecutionTerminalState,
        operatingProfile: GlifiOperatingProfile,
        maximumParallelism: Int,
        estimatedWorkUnits: Int64,
        completedWorkUnits: Int64,
        artifacts: [GlifiAnalysisExecutionArtifact]
    ) {
        self.operationID = operationID
        self.projectID = projectID
        self.sourceGeneration = sourceGeneration
        self.generation = generation
        self.planArtifactID = planArtifactID
        self.planAnalysisNodeID = planAnalysisNodeID
        self.interpretationArtifactID = interpretationArtifactID
        self.interpretationAnalysisNodeID = interpretationAnalysisNodeID
        self.interpretation = interpretation
        self.planStatus = planStatus
        self.terminalState = terminalState
        self.operatingProfile = operatingProfile
        self.maximumParallelism = maximumParallelism
        self.estimatedWorkUnits = estimatedWorkUnits
        self.completedWorkUnits = completedWorkUnits
        self.artifacts = artifacts
    }
}
