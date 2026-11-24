// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Stable progress observation shared by native and headless clients.
public struct GlifiStudioOperationProgress: Codable, Equatable, Sendable {
    /// Opaque runtime operation identity.
    public let operationID: String
    /// Monotonic event revision.
    public let revision: Int
    /// Stable phase identifier.
    public let phase: String
    /// Current canonical plan step, when applicable.
    public let planStepIdentifier: String?
    /// Current semantic analysis node, when known.
    public let analysisNodeID: String?
    /// Completed work in the declared unit.
    public let completed: Int64
    /// Phase total, absent only for indeterminate work.
    public let total: Int64?
    /// Stable measurement unit.
    public let unit: String
    /// Quality of the total estimate.
    public let estimateQuality: String

    init(_ value: GlifiOperationProgress) {
        operationID = value.operationID.canonicalValue
        revision = value.revision
        phase = value.phase.rawValue
        planStepIdentifier = value.planStepIdentifier
        analysisNodeID = value.analysisNodeID?.canonicalValue
        completed = value.completed
        total = value.total
        unit = value.unit.rawValue
        estimateQuality = value.estimateQuality.rawValue
    }
}

/// Durable output associated with one canonical plan step.
public struct GlifiStudioAnalysisExecutionArtifact: Codable, Equatable, Sendable {
    /// Stable step identity within the plan.
    public let planStepIdentifier: String
    /// Stable operation selected by the planner.
    public let operation: String
    /// Semantic role of the analyzed population.
    public let role: String
    /// Immutable content-addressed output identity.
    public let artifactID: String
    /// Semantic producer identity.
    public let analysisNodeID: String
    /// Exact persisted payload contract.
    public let outputSchemaIdentifier: String

    init(_ value: GlifiAnalysisExecutionArtifact) {
        planStepIdentifier = value.planStepIdentifier
        operation = value.operation.rawValue
        role = value.role.rawValue
        artifactID = value.artifactID.canonicalValue
        analysisNodeID = value.analysisNodeID.canonicalValue
        outputSchemaIdentifier = value.outputSchemaIdentifier
    }
}

/// Successful terminal result emitted only after every output is durable.
public struct GlifiStudioAnalysisExecutionResult: Codable, Equatable, Sendable {
    /// Opaque operation identity shared with progress observations.
    public let operationID: String
    /// Stable project identity.
    public let projectID: String
    /// Generation observed by planning.
    public let sourceGeneration: Int
    /// Final authoritative generation.
    public let generation: Int
    /// Immutable plan Artifact identity.
    public let planArtifactID: String
    /// Semantic plan-node identity.
    public let planAnalysisNodeID: String
    /// Immutable Evidence/Finding/Caveat interpretation Artifact.
    public let interpretationArtifactID: String
    /// Semantic interpretation-node identity.
    public let interpretationAnalysisNodeID: String
    /// Structured interpretation ready for native or headless presentation.
    public let interpretation: GlifiStudioAnalysisInterpretation
    /// Readiness state preserved from the plan.
    public let planStatus: String
    /// Successful terminal state, including caveats when applicable.
    public let terminalState: String
    /// Runtime operating profile selected at admission.
    public let operatingProfile: String
    /// Parallelism admitted by the runtime policy.
    public let maximumParallelism: Int
    /// Planned deterministic work estimate.
    public let estimatedWorkUnits: Int64
    /// Work represented by all completed steps.
    public let completedWorkUnits: Int64
    /// Durable outputs in canonical plan-step order.
    public let artifacts: [GlifiStudioAnalysisExecutionArtifact]

    init(_ value: GlifiProjectAnalysisExecutionResult) {
        operationID = value.operationID.canonicalValue
        projectID = value.projectID.canonicalValue
        sourceGeneration = value.sourceGeneration
        generation = value.generation
        planArtifactID = value.planArtifactID.canonicalValue
        planAnalysisNodeID = value.planAnalysisNodeID.canonicalValue
        interpretationArtifactID = value.interpretationArtifactID.canonicalValue
        interpretationAnalysisNodeID = value.interpretationAnalysisNodeID.canonicalValue
        interpretation = GlifiStudioAnalysisInterpretation(value.interpretation)
        planStatus = value.planStatus.rawValue
        terminalState = value.terminalState.rawValue
        operatingProfile = value.operatingProfile.rawValue
        maximumParallelism = value.maximumParallelism
        estimatedWorkUnits = value.estimatedWorkUnits
        completedWorkUnits = value.completedWorkUnits
        artifacts = value.artifacts.map(GlifiStudioAnalysisExecutionArtifact.init)
    }
}

/// Ordered event emitted by one owned plan execution.
public enum GlifiStudioAnalysisExecutionEvent: Sendable {
    case progress(GlifiStudioOperationProgress)
    case completed(GlifiStudioAnalysisExecutionResult)
}

/// Owned, cancellable, bounded event stream for one plan execution.
public struct GlifiStudioAnalysisExecution: Sendable {
    /// Stable operation identity available before the first event.
    public let operationID: String
    /// Bounded stream ending in exactly one completion event or one typed failure.
    public let events: AsyncThrowingStream<GlifiStudioAnalysisExecutionEvent, any Error>

    private let task: Task<Void, Never>

    init(
        operationID: OperationID,
        events: AsyncThrowingStream<GlifiStudioAnalysisExecutionEvent, any Error>,
        task: Task<Void, Never>
    ) {
        self.operationID = operationID.canonicalValue
        self.events = events
        self.task = task
    }

    /// Requests cooperative cancellation; repeated calls are harmless.
    public func cancel() {
        task.cancel()
    }
}
