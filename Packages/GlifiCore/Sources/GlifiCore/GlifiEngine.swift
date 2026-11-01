// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Describes the operational state of the GlifiCore engine.
public enum GlifiEngineStatus: String, Sendable, Equatable {
    /// The engine is available to accept work.
    case ready
}

/// Durable project snapshot and descriptive profile produced by one import.
public struct GlifiProjectTextImportResult: Equatable, Sendable {
    /// Verified generation committed by the import.
    public let project: GlifiProjectSnapshot
    /// Deterministic profile derived from the same immutable source bytes.
    public let profile: GlifiTextProfile

    /// Creates an import outcome whose project and profile share the same source revision.
    public init(project: GlifiProjectSnapshot, profile: GlifiTextProfile) {
        self.project = project
        self.profile = profile
    }
}

/// One bounded concordance row resolved against immutable source bytes.
public struct GlifiProjectQueryMatch: Equatable, Sendable {
    /// Source revision that owns every returned interval and excerpt.
    public let sourceRevisionID: SourceRevisionID
    /// Exact UTF-8 match interval in the extracted text representation.
    public let range: GlifiUTF8Range
    /// Ordered source-byte intervals contributing to the extracted match.
    public let sourceRanges: [GlifiUTF8Range]
    /// Bounded text preceding the match.
    public let leftContext: String
    /// Exact surface covered by `range`.
    public let match: String
    /// Bounded text following the match.
    public let rightContext: String

    /// Creates a concordance row from already verified source coordinates.
    public init(
        sourceRevisionID: SourceRevisionID,
        range: GlifiUTF8Range,
        sourceRanges: [GlifiUTF8Range],
        leftContext: String,
        match: String,
        rightContext: String
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.range = range
        self.sourceRanges = sourceRanges
        self.leftContext = leftContext
        self.match = match
        self.rightContext = rightContext
    }
}

/// Deterministic bounded project query result ordered by source identity and position.
public struct GlifiProjectQueryResult: Equatable, Sendable {
    /// Project queried by this result.
    public let projectID: ProjectID
    /// Exact authoritative generation queried.
    public let generation: Int
    /// Digest of the canonical query AST.
    public let queryDigest: String
    /// Number of source scopes selected by the predicate.
    public let matchedSourceCount: Int
    /// Bounded concordance rows in canonical order.
    public let matches: [GlifiProjectQueryMatch]
    /// Whether rows or source scans were curtailed by a declared limit.
    public let isTruncated: Bool

    /// Creates one immutable project query result.
    public init(
        projectID: ProjectID,
        generation: Int,
        queryDigest: String,
        matchedSourceCount: Int,
        matches: [GlifiProjectQueryMatch],
        isTruncated: Bool
    ) {
        self.projectID = projectID
        self.generation = generation
        self.queryDigest = queryDigest
        self.matchedSourceCount = matchedSourceCount
        self.matches = matches
        self.isTruncated = isTruncated
    }
}

/// Persisted deterministic plan for one verified project generation.
public struct GlifiProjectAnalysisPlanResult: Equatable, Sendable {
    /// Project that owns the plan revision.
    public let projectID: ProjectID
    /// Exact project generation evaluated by the planner.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the persisted plan.
    public let generation: Int
    /// Immutable persisted plan identity.
    public let artifactID: ArtifactID
    /// Semantic planner-node identity.
    public let analysisNodeID: AnalysisNodeID
    /// Complete plan, rationale, exclusions, and collection facts.
    public let plan: GlifiAnalysisPlan

    /// Creates a result with explicit source and commit lineage.
    public init(
        projectID: ProjectID,
        sourceGeneration: Int,
        generation: Int,
        artifactID: ArtifactID,
        analysisNodeID: AnalysisNodeID,
        plan: GlifiAnalysisPlan
    ) {
        self.projectID = projectID
        self.sourceGeneration = sourceGeneration
        self.generation = generation
        self.artifactID = artifactID
        self.analysisNodeID = analysisNodeID
        self.plan = plan
    }
}

/// Deterministic corpus profile bound to one verified project generation.
public struct GlifiProjectCorpusAnalysisResult: Equatable, Sendable {
    /// Project analyzed by this result.
    public let projectID: ProjectID
    /// Exact source generation captured before analysis.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the persisted Artifact.
    public let generation: Int
    /// Immutable persisted result identity.
    public let artifactID: ArtifactID
    /// Semantic producer identity.
    public let analysisNodeID: AnalysisNodeID
    /// Analytical values derived from every source in the captured generation.
    public let analysis: GlifiCorpusAnalysis

    /// Creates a result with explicit project and generation lineage.
    public init(
        projectID: ProjectID,
        sourceGeneration: Int,
        generation: Int,
        artifactID: ArtifactID,
        analysisNodeID: AnalysisNodeID,
        analysis: GlifiCorpusAnalysis
    ) {
        self.projectID = projectID
        self.sourceGeneration = sourceGeneration
        self.generation = generation
        self.artifactID = artifactID
        self.analysisNodeID = analysisNodeID
        self.analysis = analysis
    }
}

/// Deterministic two-group comparison bound to one verified project generation.
public struct GlifiProjectKeynessResult: Equatable, Sendable {
    /// Project that owns both compared populations.
    public let projectID: ProjectID
    /// Exact source generation captured before comparison.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the persisted Artifact.
    public let generation: Int
    /// Immutable persisted result identity.
    public let artifactID: ArtifactID
    /// Semantic producer identity.
    public let analysisNodeID: AnalysisNodeID
    /// Statistical comparison and complete population lineage.
    public let comparison: GlifiKeynessComparison

    /// Creates a result with explicit project and generation lineage.
    public init(
        projectID: ProjectID,
        sourceGeneration: Int,
        generation: Int,
        artifactID: ArtifactID,
        analysisNodeID: AnalysisNodeID,
        comparison: GlifiKeynessComparison
    ) {
        self.projectID = projectID
        self.sourceGeneration = sourceGeneration
        self.generation = generation
        self.artifactID = artifactID
        self.analysisNodeID = analysisNodeID
        self.comparison = comparison
    }
}

/// Deterministic two-group corpus-similarity comparison bound to one verified
/// project generation.
public struct GlifiProjectSimilarityResult: Equatable, Sendable {
    /// Project that owns both compared populations.
    public let projectID: ProjectID
    /// Exact source generation captured before comparison.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the persisted Artifact.
    public let generation: Int
    /// Immutable persisted result identity.
    public let artifactID: ArtifactID
    /// Semantic producer identity.
    public let analysisNodeID: AnalysisNodeID
    /// Similarity comparison and complete population lineage.
    public let comparison: GlifiCorpusSimilarityComparison

    /// Creates a result with explicit project and generation lineage.
    public init(
        projectID: ProjectID,
        sourceGeneration: Int,
        generation: Int,
        artifactID: ArtifactID,
        analysisNodeID: AnalysisNodeID,
        comparison: GlifiCorpusSimilarityComparison
    ) {
        self.projectID = projectID
        self.sourceGeneration = sourceGeneration
        self.generation = generation
        self.artifactID = artifactID
        self.analysisNodeID = analysisNodeID
        self.comparison = comparison
    }
}

/// Provides the headless entry point to GlifiCore capabilities.
public actor GlifiEngine {
    private let defaultLanguageConfiguration: GlifiLanguageConfiguration
    private let textImporter: GlifiTextImporter
    let textTokenizer: any GlifiTokenizing
    private let textAnalyzer: GlifiTextAnalyzer
    private let corpusAnalyzer: GlifiCorpusAnalyzer
    private var hasReportedReady = false

    /// Creates an engine with no persistent project attached.
    ///
    /// - Parameters:
    ///   - defaultLanguageConfiguration: Language used when a project has no explicit setting.
    ///   - textImporter: Strict, bounded ingestion implementation.
    ///   - tokenizer: Replaceable linguistic tokenizer.
    public init(
        defaultLanguageConfiguration: GlifiLanguageConfiguration = .italian,
        textImporter: GlifiTextImporter = GlifiTextImporter(),
        tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()
    ) {
        self.defaultLanguageConfiguration = defaultLanguageConfiguration
        self.textImporter = textImporter
        textTokenizer = tokenizer
        textAnalyzer = GlifiTextAnalyzer(tokenizer: tokenizer)
        corpusAnalyzer = GlifiCorpusAnalyzer(tokenizer: tokenizer)
    }

    /// Returns the language used when a project has no explicit configuration.
    public func languageConfiguration() -> GlifiLanguageConfiguration {
        defaultLanguageConfiguration
    }

    /// Returns the current operational state of the engine.
    public func status() -> GlifiEngineStatus {
        if !hasReportedReady {
            let conditions = GlifiSystemConditions.current()
            let recommendation = GlifiRuntimePolicy.recommendation(
                for: .interactive,
                conditions: conditions
            )
            GlifiDiagnostics.record(.engineReady(profile: recommendation.profile))
            hasReportedReady = true
        }

        return .ready
    }

    /// Imports and profiles one bounded UTF-8 text snapshot off the presentation actor.
    public func profileText(
        data: Data,
        format: GlifiTextFormat,
        limits: GlifiTextImportLimits = .standard
    ) throws -> GlifiTextProfile {
        do {
            try Task.checkCancellation()
            let importedText = try GlifiDiagnostics.measure(.importSources) {
                try textImporter.importText(from: data, format: format, limits: limits)
            }
            let profile = try profile(importedText)
            try Task.checkCancellation()
            return profile
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .profileCollection,
                retryDisposition: .newRequest,
                retainedState: .unchanged,
                messageKey: "failure.operation.cancelled"
            )
        }
    }

    /// Reads and profiles one user-authorized file while keeping file I/O off the Main Actor.
    public func profileText(
        at url: URL,
        format: GlifiTextFormat,
        limits: GlifiTextImportLimits = .standard
    ) throws -> GlifiTextProfile {
        do {
            try Task.checkCancellation()
            let importedText = try GlifiDiagnostics.measure(.importSources) {
                try importText(at: url, format: format, limits: limits)
            }
            return try profile(importedText)
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .profileCollection,
                retryDisposition: .newRequest,
                retainedState: .unchanged,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "file.unreadable",
                category: .transientIO,
                operation: .importText,
                retryDisposition: .transientBackoff,
                retainedState: .unchanged,
                messageKey: "failure.file.unreadable"
            )
        }
    }

    /// Creates an empty verified `.glifi` package.
    public func createProject(at url: URL) throws -> GlifiProjectPackage {
        try GlifiProjectPackage.create(at: url)
    }

    /// Opens an existing `.glifi` package after complete root verification.
    public func openProject(at url: URL) throws -> GlifiProjectPackage {
        try GlifiProjectPackage.open(at: url)
    }

    /// Validates, profiles, and transactionally incorporates one text source.
    public func importText(
        at url: URL,
        format: GlifiTextFormat,
        into project: GlifiProjectPackage,
        limits: GlifiTextImportLimits = .standard
    ) async throws -> GlifiProjectTextImportResult {
        do {
            try Task.checkCancellation()
            let importedText = try GlifiDiagnostics.measure(.importSources) {
                try importText(at: url, format: format, limits: limits)
            }
            let textProfile = try profile(importedText)
            try Task.checkCancellation()
            let snapshot = try await project.importText(importedText)
            return GlifiProjectTextImportResult(project: snapshot, profile: textProfile)
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw cancellationFailure()
        } catch {
            throw unreadableFileFailure()
        }
    }

    /// Creates one durable investigation from a verified interpretation artifact.
    public func createInvestigation(
        in project: GlifiProjectPackage,
        request: GlifiInvestigationCreationRequest
    ) async throws -> GlifiProjectInvestigationResult {
        do {
            try Task.checkCancellation()
            let sourceSnapshot = await project.snapshot()
            guard
                let record = sourceSnapshot.artifacts.first(where: {
                    $0.artifactID == request.interpretationArtifactID
                        && $0.node.descriptor.outputSchemaIdentifier
                            == GlifiAnalysisInterpretationArtifactPayload.outputSchemaIdentifier
                })
            else {
                throw investigationEngineFailure(
                    "investigation.interpretation-not-found",
                    category: .insufficientData
                )
            }
            let data = try await project.artifactData(for: record.artifactID)
            let payload: GlifiAnalysisInterpretationArtifactPayload = try decodeArtifact(data)
            let available = payload.interpretation.findings.map(\.id)
            let selected = request.selectedFindingIDs ?? available
            guard Set(selected).isSubset(of: Set(available)) else {
                throw investigationEngineFailure(
                    "investigation.finding-not-found",
                    category: .invalidInput
                )
            }
            let investigationID = InvestigationID()
            let event = try GlifiInvestigationEvent(
                investigationID: investigationID,
                predecessorEventID: nil,
                recordedAtUnixMilliseconds: Self.currentUnixMilliseconds(),
                actor: .localPerson,
                payload: .created(
                    question: request.question,
                    languageCode: request.languageCode,
                    intent: payload.interpretation.intent,
                    planArtifactID: payload.interpretation.planArtifactID,
                    interpretationArtifactID: request.interpretationArtifactID,
                    availableFindingIDs: available,
                    selectedFindingIDs: selected
                )
            )
            let headEventID = try event.eventID()
            let committed = try await project.appendInvestigationEvent(event)
            let eventsByID = try await loadInvestigationEvents(
                from: project,
                records: committed.investigationEvents
            )
            let investigation = try GlifiInvestigation(
                headEventID: headEventID,
                eventsByID: eventsByID
            )
            return GlifiProjectInvestigationResult(
                projectID: committed.projectID,
                generation: committed.generation,
                investigation: investigation
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw cancellationFailure(operation: .investigate)
        } catch {
            throw investigationEngineFailure("investigation.creation-failed")
        }
    }

    /// Appends one editorial selection without mutating or deleting its predecessor branch.
    public func reviseInvestigationSelection(
        in project: GlifiProjectPackage,
        request: GlifiInvestigationSelectionRequest
    ) async throws -> GlifiProjectInvestigationResult {
        do {
            try Task.checkCancellation()
            let sourceSnapshot = await project.snapshot()
            let sourceEvents = try await loadInvestigationEvents(
                from: project,
                records: sourceSnapshot.investigationEvents
            )
            let previous = try GlifiInvestigation(
                headEventID: request.predecessorEventID,
                eventsByID: sourceEvents
            )
            guard previous.id == request.investigationID,
                Set(request.selectedFindingIDs).isSubset(of: Set(previous.availableFindingIDs))
            else {
                throw investigationEngineFailure(
                    "investigation.finding-not-found",
                    category: .invalidInput
                )
            }
            let event = try GlifiInvestigationEvent(
                investigationID: request.investigationID,
                predecessorEventID: request.predecessorEventID,
                recordedAtUnixMilliseconds: Self.currentUnixMilliseconds(),
                actor: .localPerson,
                payload: .editorialSelectionChanged(
                    selectedFindingIDs: request.selectedFindingIDs,
                    reasonIdentifier: request.reasonIdentifier
                )
            )
            let headEventID = try event.eventID()
            let committed = try await project.appendInvestigationEvent(event)
            let committedEvents = try await loadInvestigationEvents(
                from: project,
                records: committed.investigationEvents
            )
            let investigation = try GlifiInvestigation(
                headEventID: headEventID,
                eventsByID: committedEvents
            )
            return GlifiProjectInvestigationResult(
                projectID: committed.projectID,
                generation: committed.generation,
                investigation: investigation
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw cancellationFailure(operation: .investigate)
        } catch {
            throw investigationEngineFailure("investigation.revision-failed")
        }
    }

    /// Returns every current investigation branch head in stable identity order.
    public func investigationHeads(
        in project: GlifiProjectPackage
    ) async throws -> [GlifiInvestigation] {
        let snapshot = await project.snapshot()
        let predecessorIDs = Set(snapshot.investigationEvents.compactMap(\.predecessorEventID))
        let heads = snapshot.investigationEvents.map(\.eventID).filter {
            !predecessorIDs.contains($0)
        }.sorted { $0.canonicalValue < $1.canonicalValue }
        let eventsByID = try await loadInvestigationEvents(
            from: project,
            records: snapshot.investigationEvents
        )
        var result: [GlifiInvestigation] = []
        result.reserveCapacity(heads.count)
        for head in heads {
            result.append(
                try GlifiInvestigation(
                    headEventID: head,
                    eventsByID: eventsByID
                ))
        }
        return result
    }

    /// Exports one exact investigation branch through a verified atomic staging directory.
    public func exportInvestigation(
        in project: GlifiProjectPackage,
        request: GlifiScientificExportRequest,
        to destinationURL: URL
    ) async throws -> GlifiExportReceipt {
        do {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let events = try await loadInvestigationEvents(
                from: project,
                records: snapshot.investigationEvents
            )
            let investigation = try GlifiInvestigation(
                headEventID: request.investigationHeadEventID,
                eventsByID: events
            )
            guard
                let interpretationRecord = snapshot.artifacts.first(where: {
                    $0.artifactID == investigation.interpretationArtifactID
                        && $0.node.descriptor.outputSchemaIdentifier
                            == GlifiAnalysisInterpretationArtifactPayload.outputSchemaIdentifier
                })
            else {
                throw GlifiFailure(
                    code: "export.interpretation-not-found",
                    category: .staleArtifact,
                    operation: .export,
                    retryDisposition: .newRequest,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.export.interpretation-not-found"
                )
            }
            let data = try await project.artifactData(for: interpretationRecord.artifactID)
            let payload: GlifiAnalysisInterpretationArtifactPayload = try decodeArtifact(data)
            guard payload.analysisNodeID == interpretationRecord.node.id else {
                throw GlifiFailure(
                    code: "export.interpretation-mismatch",
                    category: .corruption,
                    operation: .export,
                    retryDisposition: .never,
                    retainedState: .readOnlyRecovery,
                    messageKey: "failure.export.interpretation-mismatch"
                )
            }
            try Task.checkCancellation()
            return try GlifiScientificExporter().export(
                snapshot: snapshot,
                investigation: investigation,
                interpretationRecord: interpretationRecord,
                interpretation: payload.interpretation,
                request: request,
                to: destinationURL
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw cancellationFailure(operation: .export)
        } catch {
            throw GlifiFailure(
                code: "export.failed",
                category: .invariantViolation,
                operation: .export,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.export.failed"
            )
        }
    }

    /// Produces and persists an explainable deterministic plan for the current generation.
    public func planAnalysis(
        in project: GlifiProjectPackage,
        request: GlifiAnalysisPlanRequest
    ) async throws -> GlifiProjectAnalysisPlanResult {
        do {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let planningSources = try snapshot.sources.map {
                try GlifiPlanningSource(
                    sourceRevisionID: $0.sourceRevisionID,
                    format: $0.format,
                    byteCount: $0.byteCount
                )
            }
            let plan = try GlifiAnalysisPlanner().plan(
                request: request,
                sourceRootDigest: snapshot.sourceRootDigest,
                configuredLanguageCode: defaultLanguageConfiguration.languageCode,
                sources: planningSources
            )
            let descriptor = try GlifiAnalysisArtifactDescriptorFactory.analysisPlan(
                projectID: snapshot.projectID,
                sourceRootDigest: snapshot.sourceRootDigest,
                tokenizationContractIdentifier: textTokenizer.tokenizationContractIdentifier,
                plan: plan
            )
            let nodeID = try descriptor.nodeID()
            if let artifact = snapshot.artifacts.first(where: { $0.node.id == nodeID }) {
                let data = try await project.artifactData(for: artifact.artifactID)
                let payload: GlifiAnalysisPlanArtifactPayload = try decodeArtifact(data)
                guard payload.analysisNodeID == nodeID, payload.plan == plan else {
                    throw analysisArtifactFailure(
                        "planner.payload-plan-mismatch",
                        operation: .plan
                    )
                }
                return GlifiProjectAnalysisPlanResult(
                    projectID: snapshot.projectID,
                    sourceGeneration: snapshot.generation,
                    generation: snapshot.generation,
                    artifactID: artifact.artifactID,
                    analysisNodeID: nodeID,
                    plan: payload.plan
                )
            }
            try Task.checkCancellation()
            let committed = try await project.storeArtifact(
                GlifiAnalysisPlanArtifactPayload(
                    analysisNodeID: nodeID,
                    plan: plan
                ),
                descriptor: descriptor
            )
            guard let artifact = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
                throw analysisArtifactFailure(
                    "planner.persisted-artifact-missing",
                    operation: .plan
                )
            }
            return GlifiProjectAnalysisPlanResult(
                projectID: snapshot.projectID,
                sourceGeneration: snapshot.generation,
                generation: committed.generation,
                artifactID: artifact.artifactID,
                analysisNodeID: nodeID,
                plan: plan
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .plan,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "planner.internal-failure",
                category: .invariantViolation,
                operation: .plan,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.planner.internal-failure"
            )
        }
    }

    /// Executes every admitted step of one deterministic plan and reports bounded progress.
    public func executeAnalysisPlan(
        in project: GlifiProjectPackage,
        request: GlifiAnalysisPlanRequest,
        operationID: OperationID = OperationID(),
        workIntent: GlifiWorkIntent = .userInitiated,
        systemConditions: GlifiSystemConditions = .current(),
        availableProcessorCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        progress: @escaping @Sendable (GlifiOperationProgress) async -> Void = { _ in }
    ) async throws -> GlifiProjectAnalysisExecutionResult {
        do {
            try Task.checkCancellation()
            let recommendation = GlifiRuntimePolicy.recommendation(
                for: workIntent,
                conditions: systemConditions,
                availableProcessorCount: availableProcessorCount
            )
            guard recommendation.allowsNewWork else {
                throw GlifiFailure(
                    code: "runtime.admission-denied",
                    category: .insufficientResources,
                    operation: .executePlan,
                    retryDisposition: .afterConditionsChange,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.runtime.admission-denied",
                    arguments: ["operatingProfile": recommendation.profile.rawValue]
                )
            }

            var progressRevision = 0
            await progress(
                try GlifiOperationProgress(
                    operationID: operationID,
                    revision: progressRevision,
                    phase: .planning,
                    completed: 0,
                    total: 1,
                    unit: .nodes,
                    estimateQuality: .exact
                )
            )
            progressRevision += 1
            let planned = try await planAnalysis(in: project, request: request)
            await progress(
                try GlifiOperationProgress(
                    operationID: operationID,
                    revision: progressRevision,
                    phase: .planning,
                    analysisNodeID: planned.analysisNodeID,
                    completed: 1,
                    total: 1,
                    unit: .nodes,
                    estimateQuality: .exact
                )
            )
            progressRevision += 1

            guard !planned.plan.steps.isEmpty else {
                let wasResourceLimited = planned.plan.decisions.contains {
                    $0.applicability == .deferred
                }
                throw GlifiFailure(
                    code: wasResourceLimited
                        ? "runtime.plan-resource-limited" : "runtime.plan-not-executable",
                    category: wasResourceLimited ? .insufficientResources : .insufficientData,
                    operation: .executePlan,
                    retryDisposition: wasResourceLimited
                        ? .afterConditionsChange : .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: wasResourceLimited
                        ? "failure.runtime.plan-resource-limited"
                        : "failure.runtime.plan-not-executable"
                )
            }

            let executionSnapshot = await project.snapshot()
            guard executionSnapshot.projectID == planned.projectID,
                executionSnapshot.sourceRootDigest
                    == planned.plan.collectionProfile.sourceRootDigest
            else {
                throw GlifiFailure(
                    code: "runtime.plan-became-stale",
                    category: .staleArtifact,
                    operation: .executePlan,
                    retryDisposition: .newRequest,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.runtime.plan-became-stale"
                )
            }
            let recordsByID = Dictionary(
                uniqueKeysWithValues: executionSnapshot.sources.map {
                    ($0.sourceRevisionID, $0)
                }
            )
            var completedStepIdentifiers: Set<String> = []
            var completedWorkUnits: Int64 = 0
            var artifacts: [GlifiAnalysisExecutionArtifact] = []
            artifacts.reserveCapacity(planned.plan.steps.count)
            await progress(
                try GlifiOperationProgress(
                    operationID: operationID,
                    revision: progressRevision,
                    phase: .executing,
                    completed: completedWorkUnits,
                    total: planned.plan.totalEstimatedWorkUnits,
                    unit: .workUnits,
                    estimateQuality: .estimated
                )
            )
            progressRevision += 1

            for step in planned.plan.steps {
                try Task.checkCancellation()
                guard
                    Set(step.dependencyStepIdentifiers).isSubset(
                        of: completedStepIdentifiers
                    )
                else {
                    throw analysisArtifactFailure(
                        "runtime.plan-dependency-order-invalid",
                        operation: .executePlan
                    )
                }
                let artifact: GlifiAnalysisExecutionArtifact
                switch step.operation {
                case .analyzeCorpus:
                    let records = try selectedRecords(
                        step.sourceRevisionIDs,
                        recordsByID: recordsByID
                    )
                    try validateCorpusSelection(
                        documentByteCounts: records.map(\.byteCount),
                        options: .standard
                    )
                    let output = try await corpusAnalysisArtifact(
                        records,
                        options: .standard,
                        in: project
                    )
                    artifact = GlifiAnalysisExecutionArtifact(
                        planStepIdentifier: step.identifier,
                        operation: step.operation,
                        role: step.role,
                        artifactID: output.record.artifactID,
                        analysisNodeID: output.record.node.id,
                        outputSchemaIdentifier: output.record.node.descriptor.outputSchemaIdentifier
                    )
                case .compareKeyness:
                    let output = try await compareKeyness(
                        in: project,
                        targetSourceRevisionIDs: planned.plan.targetSourceRevisionIDs,
                        referenceSourceRevisionIDs: planned.plan.referenceSourceRevisionIDs
                    )
                    let currentSnapshot = await project.snapshot()
                    guard
                        let record = currentSnapshot.artifacts.first(where: {
                            $0.artifactID == output.artifactID
                                && $0.node.id == output.analysisNodeID
                        })
                    else {
                        throw analysisArtifactFailure(
                            "runtime.plan-output-missing",
                            operation: .executePlan
                        )
                    }
                    artifact = GlifiAnalysisExecutionArtifact(
                        planStepIdentifier: step.identifier,
                        operation: step.operation,
                        role: step.role,
                        artifactID: output.artifactID,
                        analysisNodeID: output.analysisNodeID,
                        outputSchemaIdentifier: record.node.descriptor.outputSchemaIdentifier
                    )
                default:
                    let output = try await executeExtendedStep(
                        step,
                        plan: planned.plan,
                        in: project
                    )
                    let currentSnapshot = await project.snapshot()
                    guard
                        let record = currentSnapshot.artifacts.first(where: {
                            $0.artifactID == output.artifactID && $0.node.id == output.nodeID
                        })
                    else {
                        throw analysisArtifactFailure(
                            "runtime.plan-output-missing",
                            operation: .executePlan
                        )
                    }
                    artifact = GlifiAnalysisExecutionArtifact(
                        planStepIdentifier: step.identifier,
                        operation: step.operation,
                        role: step.role,
                        artifactID: output.artifactID,
                        analysisNodeID: output.nodeID,
                        outputSchemaIdentifier: record.node.descriptor.outputSchemaIdentifier
                    )
                }
                guard artifact.outputSchemaIdentifier == step.outputSchemaIdentifier else {
                    throw analysisArtifactFailure(
                        "runtime.plan-output-schema-mismatch",
                        operation: .executePlan
                    )
                }
                artifacts.append(artifact)
                completedStepIdentifiers.insert(step.identifier)
                completedWorkUnits = try checkedExecutionWork(
                    completedWorkUnits,
                    adding: step.estimatedWorkUnits
                )
                await progress(
                    try GlifiOperationProgress(
                        operationID: operationID,
                        revision: progressRevision,
                        phase: .executing,
                        planStepIdentifier: step.identifier,
                        analysisNodeID: artifact.analysisNodeID,
                        completed: completedWorkUnits,
                        total: planned.plan.totalEstimatedWorkUnits,
                        unit: .workUnits,
                        estimateQuality: .estimated
                    )
                )
                progressRevision += 1
            }

            guard completedWorkUnits == planned.plan.totalEstimatedWorkUnits,
                artifacts.count == planned.plan.steps.count
            else {
                throw analysisArtifactFailure(
                    "runtime.plan-completion-mismatch",
                    operation: .executePlan
                )
            }
            await progress(
                try GlifiOperationProgress(
                    operationID: operationID,
                    revision: progressRevision,
                    phase: .finalizing,
                    completed: 0,
                    total: 1,
                    unit: .nodes,
                    estimateQuality: .exact
                )
            )
            progressRevision += 1
            let interpretationOutput = try await interpretationArtifact(
                planned: planned,
                executionArtifacts: artifacts,
                sourceSnapshot: executionSnapshot,
                in: project
            )
            let finalSnapshot = await project.snapshot()
            let reachableArtifactIDs = Set(finalSnapshot.artifacts.map(\.artifactID))
            guard finalSnapshot.sourceRootDigest == executionSnapshot.sourceRootDigest,
                reachableArtifactIDs.contains(planned.artifactID),
                reachableArtifactIDs.contains(interpretationOutput.record.artifactID),
                artifacts.allSatisfy({ reachableArtifactIDs.contains($0.artifactID) })
            else {
                throw GlifiFailure(
                    code: "runtime.execution-result-stale",
                    category: .staleArtifact,
                    operation: .executePlan,
                    retryDisposition: .newRequest,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.runtime.execution-result-stale"
                )
            }
            await progress(
                try GlifiOperationProgress(
                    operationID: operationID,
                    revision: progressRevision,
                    phase: .finalizing,
                    completed: 1,
                    total: 1,
                    unit: .nodes,
                    estimateQuality: .exact
                )
            )
            return GlifiProjectAnalysisExecutionResult(
                operationID: operationID,
                projectID: planned.projectID,
                sourceGeneration: planned.sourceGeneration,
                generation: finalSnapshot.generation,
                planArtifactID: planned.artifactID,
                planAnalysisNodeID: planned.analysisNodeID,
                interpretationArtifactID: interpretationOutput.record.artifactID,
                interpretationAnalysisNodeID: interpretationOutput.record.node.id,
                interpretation: interpretationOutput.interpretation,
                planStatus: planned.plan.status,
                terminalState: planned.plan.status == .readyWithCaveats
                    || interpretationHasCaveats(interpretationOutput.interpretation)
                    ? .completedWithCaveats : .completed,
                operatingProfile: recommendation.profile,
                maximumParallelism: recommendation.maximumParallelism,
                estimatedWorkUnits: planned.plan.totalEstimatedWorkUnits,
                completedWorkUnits: completedWorkUnits,
                artifacts: artifacts
            )
        } catch let failure as GlifiFailure where failure.category == .cancelled {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .executePlan,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .executePlan,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "runtime.execution-internal-failure",
                category: .invariantViolation,
                operation: .executePlan,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.runtime.execution-internal-failure"
            )
        }
    }

    /// Profiles every source in one verified generation using bounded deterministic methods.
    public func analyzeCorpus(
        in project: GlifiProjectPackage,
        options: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectCorpusAnalysisResult {
        do {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            try validateCorpusSelection(
                documentByteCounts: snapshot.sources.map(\.byteCount),
                options: options
            )
            let descriptor = try GlifiAnalysisArtifactDescriptorFactory.corpusProfile(
                snapshot: snapshot,
                sourceRevisionIDs: snapshot.sources.map(\.sourceRevisionID),
                tokenizationContractIdentifier: textTokenizer.tokenizationContractIdentifier,
                options: options
            )
            let nodeID = try descriptor.nodeID()
            if let artifact = snapshot.artifacts.first(where: { $0.node.id == nodeID }) {
                let data = try await project.artifactData(for: artifact.artifactID)
                let payload: GlifiCorpusAnalysisArtifactPayload = try decodeArtifact(data)
                guard payload.analysisNodeID == nodeID else {
                    throw analysisArtifactFailure("analysis.payload-node-mismatch")
                }
                try validatePlannedAnalysis(
                    payload.analysis,
                    sourceRevisionIDs: snapshot.sources.map(\.sourceRevisionID)
                )
                return GlifiProjectCorpusAnalysisResult(
                    projectID: snapshot.projectID,
                    sourceGeneration: snapshot.generation,
                    generation: snapshot.generation,
                    artifactID: artifact.artifactID,
                    analysisNodeID: nodeID,
                    analysis: payload.analysis
                )
            }

            var sources: [GlifiImportedText] = []
            sources.reserveCapacity(snapshot.sources.count)
            for source in snapshot.sources {
                try Task.checkCancellation()
                let data = try await project.sourceData(for: source.sourceRevisionID)
                sources.append(
                    try textImporter.importText(
                        from: data,
                        format: source.format,
                        limits: GlifiTextImportLimits(
                            maximumByteCount: options.maximumSourceByteCount
                        ),
                        sourceRevisionID: source.sourceRevisionID
                    )
                )
            }
            let analysis = try GlifiDiagnostics.measure(.analyzeCorpus) {
                try corpusAnalyzer.analyze(sources, options: options)
            }
            try validatePlannedAnalysis(
                analysis,
                sourceRevisionIDs: snapshot.sources.map(\.sourceRevisionID)
            )
            try Task.checkCancellation()
            let committed = try await project.storeArtifact(
                GlifiCorpusAnalysisArtifactPayload(
                    analysisNodeID: nodeID,
                    analysis: analysis
                ),
                descriptor: descriptor
            )
            guard let artifact = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
                throw analysisArtifactFailure("analysis.persisted-artifact-missing")
            }
            return GlifiProjectCorpusAnalysisResult(
                projectID: snapshot.projectID,
                sourceGeneration: snapshot.generation,
                generation: committed.generation,
                artifactID: artifact.artifactID,
                analysisNodeID: nodeID,
                analysis: analysis
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .analyze,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "analysis.internal-failure",
                category: .invariantViolation,
                operation: .analyze,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.analysis.internal-failure"
            )
        }
    }

    /// Compares two disjoint source-revision groups from one verified generation.
    public func compareKeyness(
        in project: GlifiProjectPackage,
        targetSourceRevisionIDs: [SourceRevisionID],
        referenceSourceRevisionIDs: [SourceRevisionID],
        corpusOptions: GlifiCorpusAnalysisOptions = .standard,
        keynessOptions: GlifiKeynessOptions = .standard
    ) async throws -> GlifiProjectKeynessResult {
        do {
            try Task.checkCancellation()
            guard !targetSourceRevisionIDs.isEmpty, !referenceSourceRevisionIDs.isEmpty else {
                throw keynessFailure("keyness.empty-group", category: .insufficientData)
            }
            guard Set(targetSourceRevisionIDs).count == targetSourceRevisionIDs.count,
                Set(referenceSourceRevisionIDs).count == referenceSourceRevisionIDs.count
            else {
                throw keynessFailure("keyness.duplicate-source", category: .invalidInput)
            }
            guard Set(targetSourceRevisionIDs).isDisjoint(with: referenceSourceRevisionIDs) else {
                throw keynessFailure("keyness.overlapping-groups", category: .invalidInput)
            }

            let snapshot = await project.snapshot()
            let recordsByID = Dictionary(
                uniqueKeysWithValues: snapshot.sources.map {
                    ($0.sourceRevisionID, $0)
                })
            let targetRecords = try selectedRecords(
                targetSourceRevisionIDs,
                recordsByID: recordsByID
            )
            let referenceRecords = try selectedRecords(
                referenceSourceRevisionIDs,
                recordsByID: recordsByID
            )
            try validateCorpusSelection(
                documentByteCounts: targetRecords.map(\.byteCount),
                options: corpusOptions
            )
            try validateCorpusSelection(
                documentByteCounts: referenceRecords.map(\.byteCount),
                options: corpusOptions
            )

            let targetArtifact = try await corpusAnalysisArtifact(
                targetRecords,
                options: corpusOptions,
                in: project
            )
            let referenceArtifact = try await corpusAnalysisArtifact(
                referenceRecords,
                options: corpusOptions,
                in: project
            )
            let dependencies = try [targetArtifact.record, referenceArtifact.record].map {
                artifact in
                try GlifiAnalysisDependency(
                    nodeID: artifact.node.id,
                    artifactDigest: artifact.contentDigest,
                    outputSchemaIdentifier: artifact.node.descriptor.outputSchemaIdentifier
                )
            }
            let descriptor = try GlifiAnalysisArtifactDescriptorFactory.keyness(
                snapshot: snapshot,
                targetSourceRevisionIDs: targetSourceRevisionIDs,
                referenceSourceRevisionIDs: referenceSourceRevisionIDs,
                linguisticProfileIdentifiers: [
                    targetArtifact.analysis.tokenizationContractIdentifier,
                    targetArtifact.analysis.normalizationIdentifier,
                ],
                options: keynessOptions,
                dependencies: dependencies
            )
            let nodeID = try descriptor.nodeID()
            let preparedSnapshot = await project.snapshot()
            if let artifact = preparedSnapshot.artifacts.first(where: { $0.node.id == nodeID }) {
                let data = try await project.artifactData(for: artifact.artifactID)
                let payload: GlifiKeynessArtifactPayload = try decodeArtifact(data)
                guard payload.analysisNodeID == nodeID else {
                    throw analysisArtifactFailure("keyness.payload-node-mismatch")
                }
                try validatePlannedKeyness(
                    payload.comparison,
                    target: targetArtifact.analysis,
                    reference: referenceArtifact.analysis,
                    options: keynessOptions
                )
                return GlifiProjectKeynessResult(
                    projectID: snapshot.projectID,
                    sourceGeneration: snapshot.generation,
                    generation: preparedSnapshot.generation,
                    artifactID: artifact.artifactID,
                    analysisNodeID: nodeID,
                    comparison: payload.comparison
                )
            }
            let comparison = try GlifiDiagnostics.measure(.compareKeyness) {
                try GlifiKeynessAnalyzer().compare(
                    target: targetArtifact.analysis,
                    reference: referenceArtifact.analysis,
                    options: keynessOptions
                )
            }
            try validatePlannedKeyness(
                comparison,
                target: targetArtifact.analysis,
                reference: referenceArtifact.analysis,
                options: keynessOptions
            )
            try Task.checkCancellation()
            let committed = try await project.storeArtifact(
                GlifiKeynessArtifactPayload(
                    analysisNodeID: nodeID,
                    comparison: comparison
                ),
                descriptor: descriptor
            )
            guard let artifact = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
                throw analysisArtifactFailure("keyness.persisted-artifact-missing")
            }
            return GlifiProjectKeynessResult(
                projectID: snapshot.projectID,
                sourceGeneration: snapshot.generation,
                generation: committed.generation,
                artifactID: artifact.artifactID,
                analysisNodeID: nodeID,
                comparison: comparison
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .analyze,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "keyness.internal-failure",
                category: .invariantViolation,
                operation: .analyze,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.keyness.internal-failure"
            )
        }
    }

    /// Compares two explicit, disjoint source groups with `corpus-term-similarity-v1`.
    public func compareSimilarity(
        in project: GlifiProjectPackage,
        targetSourceRevisionIDs: [SourceRevisionID],
        referenceSourceRevisionIDs: [SourceRevisionID],
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectSimilarityResult {
        do {
            try Task.checkCancellation()
            guard !targetSourceRevisionIDs.isEmpty, !referenceSourceRevisionIDs.isEmpty else {
                throw corpusSimilarityFailure(
                    "corpus-similarity.empty-group",
                    category: .insufficientData
                )
            }
            guard Set(targetSourceRevisionIDs).count == targetSourceRevisionIDs.count,
                Set(referenceSourceRevisionIDs).count == referenceSourceRevisionIDs.count
            else {
                throw corpusSimilarityFailure(
                    "corpus-similarity.duplicate-source",
                    category: .invalidInput
                )
            }
            guard Set(targetSourceRevisionIDs).isDisjoint(with: referenceSourceRevisionIDs) else {
                throw corpusSimilarityFailure(
                    "corpus-similarity.overlapping-groups",
                    category: .invalidInput
                )
            }

            let snapshot = await project.snapshot()
            let recordsByID = Dictionary(
                uniqueKeysWithValues: snapshot.sources.map {
                    ($0.sourceRevisionID, $0)
                })
            let targetRecords = try selectedRecords(
                targetSourceRevisionIDs,
                recordsByID: recordsByID
            )
            let referenceRecords = try selectedRecords(
                referenceSourceRevisionIDs,
                recordsByID: recordsByID
            )
            try validateCorpusSelection(
                documentByteCounts: targetRecords.map(\.byteCount),
                options: corpusOptions
            )
            try validateCorpusSelection(
                documentByteCounts: referenceRecords.map(\.byteCount),
                options: corpusOptions
            )

            let targetArtifact = try await corpusAnalysisArtifact(
                targetRecords,
                options: corpusOptions,
                in: project
            )
            let referenceArtifact = try await corpusAnalysisArtifact(
                referenceRecords,
                options: corpusOptions,
                in: project
            )
            let dependencies = try [targetArtifact.record, referenceArtifact.record].map {
                artifact in
                try GlifiAnalysisDependency(
                    nodeID: artifact.node.id,
                    artifactDigest: artifact.contentDigest,
                    outputSchemaIdentifier: artifact.node.descriptor.outputSchemaIdentifier
                )
            }
            let descriptor = try GlifiAnalysisArtifactDescriptorFactory.corpusSimilarity(
                snapshot: snapshot,
                targetSourceRevisionIDs: targetSourceRevisionIDs,
                referenceSourceRevisionIDs: referenceSourceRevisionIDs,
                linguisticProfileIdentifiers: [
                    targetArtifact.analysis.tokenizationContractIdentifier,
                    targetArtifact.analysis.normalizationIdentifier,
                ],
                dependencies: dependencies
            )
            let nodeID = try descriptor.nodeID()
            let preparedSnapshot = await project.snapshot()
            if let artifact = preparedSnapshot.artifacts.first(where: { $0.node.id == nodeID }) {
                let data = try await project.artifactData(for: artifact.artifactID)
                let payload: GlifiCorpusSimilarityArtifactPayload = try decodeArtifact(data)
                guard payload.analysisNodeID == nodeID else {
                    throw analysisArtifactFailure("corpus-similarity.payload-node-mismatch")
                }
                return GlifiProjectSimilarityResult(
                    projectID: snapshot.projectID,
                    sourceGeneration: snapshot.generation,
                    generation: preparedSnapshot.generation,
                    artifactID: artifact.artifactID,
                    analysisNodeID: nodeID,
                    comparison: payload.comparison
                )
            }
            let comparison = try GlifiDiagnostics.measure(.compareSimilarity) {
                try GlifiCorpusSimilarityAnalyzer().compare(
                    target: targetArtifact.analysis,
                    reference: referenceArtifact.analysis
                )
            }
            try Task.checkCancellation()
            let committed = try await project.storeArtifact(
                GlifiCorpusSimilarityArtifactPayload(
                    analysisNodeID: nodeID,
                    comparison: comparison
                ),
                descriptor: descriptor
            )
            guard let artifact = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
                throw analysisArtifactFailure("corpus-similarity.persisted-artifact-missing")
            }
            return GlifiProjectSimilarityResult(
                projectID: snapshot.projectID,
                sourceGeneration: snapshot.generation,
                generation: committed.generation,
                artifactID: artifact.artifactID,
                analysisNodeID: nodeID,
                comparison: comparison
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .analyze,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "corpus-similarity.internal-failure",
                category: .invariantViolation,
                operation: .analyze,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.corpus-similarity.internal-failure"
            )
        }
    }

    /// Parses and executes a bounded query against one verified project generation.
    public func query(
        _ queryText: String,
        in project: GlifiProjectPackage,
        limits: GlifiQueryLimits = .standard
    ) async throws -> GlifiProjectQueryResult {
        try await executeQuery(in: project, limits: limits) {
            try GlifiQueryParser(tokenizer: textTokenizer).parse(queryText, limits: limits)
        }
    }

    /// Decodes and executes bounded QueryAST v1 JSON through the textual query's execution path.
    public func query(
        canonicalAST data: Data,
        in project: GlifiProjectPackage,
        limits: GlifiQueryLimits = .standard
    ) async throws -> GlifiProjectQueryResult {
        try await executeQuery(in: project, limits: limits) {
            try GlifiQueryAST.decode(data, limits: limits)
        }
    }

    private func executeQuery(
        in project: GlifiProjectPackage,
        limits: GlifiQueryLimits,
        makeQuery: () throws -> GlifiQueryAST
    ) async throws -> GlifiProjectQueryResult {
        do {
            let query = try makeQuery()
            try GlifiQueryEvaluator().validate(query, limits: limits)
            let queryDigest = try query.canonicalDigest()
            let snapshot = await project.snapshot()
            guard !snapshot.sources.isEmpty else {
                throw GlifiFailure(
                    code: "query.empty-project",
                    category: .insufficientData,
                    operation: .query,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.query.empty-project"
                )
            }
            guard snapshot.sources.count <= limits.maximumSourceCount else {
                throw GlifiFailure(
                    code: "query.source-limit-exceeded",
                    category: .insufficientResources,
                    operation: .query,
                    retryDisposition: .afterConditionsChange,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.query.source-limit-exceeded",
                    arguments: ["maximumSourceCount": String(limits.maximumSourceCount)]
                )
            }

            var scannedByteCount = 0
            var matchedSourceCount = 0
            var matches: [GlifiProjectQueryMatch] = []
            var isTruncated = false
            for source in snapshot.sources {
                try Task.checkCancellation()
                guard source.byteCount <= limits.maximumScannedByteCount - scannedByteCount else {
                    throw GlifiFailure(
                        code: "query.scan-byte-limit-exceeded",
                        category: .insufficientResources,
                        operation: .query,
                        retryDisposition: .afterConditionsChange,
                        retainedState: .lastCommittedGeneration,
                        messageKey: "failure.query.scan-byte-limit-exceeded",
                        arguments: [
                            "maximumScannedByteCount": String(limits.maximumScannedByteCount)
                        ]
                    )
                }
                scannedByteCount += source.byteCount
                let data = try await project.sourceData(for: source.sourceRevisionID)
                let importedText = try textImporter.importText(
                    from: data,
                    format: source.format,
                    sourceRevisionID: source.sourceRevisionID
                )
                let tokenization = try textTokenizer.tokenize(importedText.text)
                let result = try GlifiQueryEvaluator().evaluate(
                    query,
                    in: importedText,
                    tokenization: tokenization,
                    limits: limits
                )
                if result.matchedScope { matchedSourceCount += 1 }
                for match in result.matches {
                    guard matches.count < limits.maximumResultCount else {
                        isTruncated = true
                        break
                    }
                    guard let surface = match.range.text(in: importedText.text) else {
                        throw GlifiFailure(
                            code: "query.invalid-match",
                            category: .invariantViolation,
                            operation: .query,
                            retryDisposition: .never,
                            retainedState: .validityUnknown,
                            messageKey: "failure.query.invalid-match"
                        )
                    }
                    matches.append(
                        GlifiProjectQueryMatch(
                            sourceRevisionID: match.sourceRevisionID,
                            range: match.range,
                            sourceRanges: try importedText.spanMap.sourceRanges(
                                for: match.range
                            ),
                            leftContext: match.leftContextRange?.text(in: importedText.text) ?? "",
                            match: surface,
                            rightContext: match.rightContextRange?.text(in: importedText.text) ?? ""
                        )
                    )
                }
                isTruncated = isTruncated || result.isTruncated
                if isTruncated { break }
            }
            return GlifiProjectQueryResult(
                projectID: snapshot.projectID,
                generation: snapshot.generation,
                queryDigest: queryDigest,
                matchedSourceCount: matchedSourceCount,
                matches: matches,
                isTruncated: isTruncated
            )
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw GlifiFailure(
                code: "operation.cancelled",
                category: .cancelled,
                operation: .query,
                retryDisposition: .newRequest,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.operation.cancelled"
            )
        } catch {
            throw GlifiFailure(
                code: "query.internal-failure",
                category: .invariantViolation,
                operation: .query,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.query.internal-failure"
            )
        }
    }

    private func importText(
        at url: URL,
        format: GlifiTextFormat,
        limits: GlifiTextImportLimits
    ) throws -> GlifiImportedText {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw GlifiFailure(
                code: "file.not-regular",
                category: .invalidInput,
                operation: .importText,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.file.not-regular"
            )
        }
        if let fileSize = values.fileSize, fileSize > limits.maximumByteCount {
            throw GlifiFailure(
                code: "text.byte-limit-exceeded",
                category: .insufficientResources,
                operation: .importText,
                retryDisposition: .afterConditionsChange,
                retainedState: .unchanged,
                messageKey: "failure.text.byte-limit-exceeded",
                arguments: ["maximumByteCount": String(limits.maximumByteCount)]
            )
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
        return try textImporter.importText(from: data, format: format, limits: limits)
    }

    func selectedRecords(
        _ sourceRevisionIDs: [SourceRevisionID],
        recordsByID: [SourceRevisionID: GlifiProjectSourceRecord]
    ) throws -> [GlifiProjectSourceRecord] {
        try sourceRevisionIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }.map { sourceRevisionID in
            guard let record = recordsByID[sourceRevisionID] else {
                throw keynessFailure("keyness.source-not-found", category: .invalidInput)
            }
            return record
        }
    }

    func corpusAnalysisArtifact(
        _ records: [GlifiProjectSourceRecord],
        options: GlifiCorpusAnalysisOptions,
        in project: GlifiProjectPackage
    ) async throws -> (analysis: GlifiCorpusAnalysis, record: GlifiProjectArtifactRecord) {
        // Il profilo dichiara le revisioni che legge: una revisione scomparsa dalla generazione
        // corrente è rifiutata dal calcolo del digest, mentre l'arrivo di altre fonti non lo
        // invalida più (ADR-0028).
        let currentSnapshot = await project.snapshot()
        let descriptor = try GlifiAnalysisArtifactDescriptorFactory.corpusProfile(
            snapshot: currentSnapshot,
            sourceRevisionIDs: records.map(\.sourceRevisionID),
            tokenizationContractIdentifier: textTokenizer.tokenizationContractIdentifier,
            options: options
        )
        let nodeID = try descriptor.nodeID()
        if let artifact = currentSnapshot.artifacts.first(where: { $0.node.id == nodeID }) {
            let data = try await project.artifactData(for: artifact.artifactID)
            let payload: GlifiCorpusAnalysisArtifactPayload = try decodeArtifact(data)
            guard payload.analysisNodeID == nodeID else {
                throw analysisArtifactFailure("analysis.payload-node-mismatch")
            }
            try validatePlannedAnalysis(
                payload.analysis,
                sourceRevisionIDs: records.map(\.sourceRevisionID)
            )
            return (payload.analysis, artifact)
        }
        let sources = try await importedSources(
            records,
            from: project,
            maximumSourceByteCount: options.maximumSourceByteCount
        )
        let analysis = try GlifiDiagnostics.measure(.analyzeCorpus) {
            try corpusAnalyzer.analyze(sources, options: options)
        }
        try validatePlannedAnalysis(
            analysis,
            sourceRevisionIDs: records.map(\.sourceRevisionID)
        )
        let committed = try await project.storeArtifact(
            GlifiCorpusAnalysisArtifactPayload(
                analysisNodeID: nodeID,
                analysis: analysis
            ),
            descriptor: descriptor
        )
        guard let artifact = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
            throw analysisArtifactFailure("analysis.persisted-artifact-missing")
        }
        return (analysis, artifact)
    }

    private func interpretationArtifact(
        planned: GlifiProjectAnalysisPlanResult,
        executionArtifacts: [GlifiAnalysisExecutionArtifact],
        sourceSnapshot: GlifiProjectSnapshot,
        options: GlifiInterpretationOptions = .standard,
        in project: GlifiProjectPackage
    ) async throws -> (
        interpretation: GlifiAnalysisInterpretation,
        record: GlifiProjectArtifactRecord
    ) {
        let currentSnapshot = await project.snapshot()
        guard currentSnapshot.sourceRootDigest == sourceSnapshot.sourceRootDigest,
            let planRecord = currentSnapshot.artifacts.first(where: {
                $0.artifactID == planned.artifactID
                    && $0.node.id == planned.analysisNodeID
            })
        else {
            throw analysisArtifactFailure(
                "interpretation.plan-artifact-missing",
                operation: .executePlan
            )
        }
        let recordsByArtifactID = Dictionary(
            uniqueKeysWithValues: currentSnapshot.artifacts.map { ($0.artifactID, $0) }
        )
        let stepsByIdentifier = Dictionary(
            uniqueKeysWithValues: planned.plan.steps.map { ($0.identifier, $0) }
        )
        var inputs: [GlifiInterpretationArtifactInput] = []
        var outputRecords: [GlifiProjectArtifactRecord] = []
        inputs.reserveCapacity(executionArtifacts.count)
        outputRecords.reserveCapacity(executionArtifacts.count)
        for output in executionArtifacts {
            guard let step = stepsByIdentifier[output.planStepIdentifier],
                step.operation == output.operation,
                step.role == output.role,
                let record = recordsByArtifactID[output.artifactID],
                record.node.id == output.analysisNodeID,
                record.node.descriptor.outputSchemaIdentifier
                    == output.outputSchemaIdentifier
            else {
                throw analysisArtifactFailure(
                    "interpretation.input-artifact-missing",
                    operation: .executePlan
                )
            }
            let data = try await project.artifactData(for: output.artifactID)
            let content: GlifiInterpretationArtifactContent
            switch output.operation {
            case .analyzeCorpus:
                let payload: GlifiCorpusAnalysisArtifactPayload = try decodeArtifact(data)
                guard payload.analysisNodeID == output.analysisNodeID else {
                    throw analysisArtifactFailure(
                        "interpretation.input-node-mismatch",
                        operation: .executePlan
                    )
                }
                content = .corpusProfile(payload.analysis)
            case .compareKeyness:
                let payload: GlifiKeynessArtifactPayload = try decodeArtifact(data)
                guard payload.analysisNodeID == output.analysisNodeID else {
                    throw analysisArtifactFailure(
                        "interpretation.input-node-mismatch",
                        operation: .executePlan
                    )
                }
                content = .keyness(payload.comparison)
            case .analyzeAssociation, .analyzeWindowCollocations, .analyzeWindowNetwork,
                .analyzeCorrespondence, .clusterDocuments, .compareSimilarity, .compareGroupMetric:
                content = try supplementaryContent(
                    operation: output.operation,
                    outputSchemaIdentifier: output.outputSchemaIdentifier,
                    data: data,
                    expectedNodeID: output.analysisNodeID
                )
            }
            inputs.append(
                GlifiInterpretationArtifactInput(
                    planStepIdentifier: output.planStepIdentifier,
                    role: output.role,
                    artifactID: output.artifactID,
                    analysisNodeID: output.analysisNodeID,
                    descriptorDigest: record.descriptorDigest,
                    content: content
                )
            )
            outputRecords.append(record)
        }
        let interpretation = try GlifiInterpretationEngine().interpret(
            planArtifactID: planned.artifactID,
            planAnalysisNodeID: planned.analysisNodeID,
            plan: planned.plan,
            artifacts: inputs,
            sources: sourceSnapshot.sources,
            options: options
        )
        let dependencies = try ([planRecord] + outputRecords).map { record in
            try GlifiAnalysisDependency(
                nodeID: record.node.id,
                artifactDigest: record.contentDigest,
                outputSchemaIdentifier: record.node.descriptor.outputSchemaIdentifier
            )
        }
        let descriptor = try GlifiAnalysisArtifactDescriptorFactory.interpretation(
            projectID: sourceSnapshot.projectID,
            sourceRootDigest: sourceSnapshot.sourceRootDigest,
            plan: planned.plan,
            options: options,
            dependencies: dependencies
        )
        let nodeID = try descriptor.nodeID()
        if let existing = currentSnapshot.artifacts.first(where: { $0.node.id == nodeID }) {
            let data = try await project.artifactData(for: existing.artifactID)
            let payload: GlifiAnalysisInterpretationArtifactPayload = try decodeArtifact(data)
            guard payload.analysisNodeID == nodeID,
                payload.interpretation == interpretation
            else {
                throw analysisArtifactFailure(
                    "interpretation.payload-mismatch",
                    operation: .executePlan
                )
            }
            return (payload.interpretation, existing)
        }
        try Task.checkCancellation()
        let committed = try await project.storeArtifact(
            GlifiAnalysisInterpretationArtifactPayload(
                analysisNodeID: nodeID,
                interpretation: interpretation
            ),
            descriptor: descriptor
        )
        guard let record = committed.artifacts.first(where: { $0.node.id == nodeID }) else {
            throw analysisArtifactFailure(
                "interpretation.persisted-artifact-missing",
                operation: .executePlan
            )
        }
        return (interpretation, record)
    }

    func decodeArtifact<Payload: Decodable>(_ data: Data) throws -> Payload {
        do {
            return try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw GlifiFailure(
                code: "analysis.artifact-payload-invalid",
                category: .corruption,
                operation: .analyze,
                retryDisposition: .never,
                retainedState: .readOnlyRecovery,
                messageKey: "failure.analysis.artifact-payload-invalid"
            )
        }
    }

    private func validatePlannedAnalysis(
        _ analysis: GlifiCorpusAnalysis,
        sourceRevisionIDs: [SourceRevisionID]
    ) throws {
        let expectedIDs = sourceRevisionIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }
        guard analysis.sourceRevisionIDs == expectedIDs,
            analysis.tokenizationContractIdentifier
                == textTokenizer.tokenizationContractIdentifier,
            analysis.normalizationIdentifier == "nfc-lowercase-it-v1",
            analysis.numericPolicyIdentifier == "IEEE-754-binary64-ordered-reduction-v1"
        else {
            throw analysisArtifactFailure("analysis.descriptor-result-mismatch")
        }
    }

    private func validatePlannedKeyness(
        _ comparison: GlifiKeynessComparison,
        target: GlifiCorpusAnalysis,
        reference: GlifiCorpusAnalysis,
        options: GlifiKeynessOptions
    ) throws {
        guard comparison.targetSourceRevisionIDs == target.sourceRevisionIDs,
            comparison.referenceSourceRevisionIDs == reference.sourceRevisionIDs,
            comparison.targetCorpusDigest == target.corpusDigest,
            comparison.referenceCorpusDigest == reference.corpusDigest,
            comparison.lowExpectedCountThreshold == options.lowExpectedCountThreshold,
            comparison.numericPolicyIdentifier == "IEEE-754-binary64-ordered-reduction-v1"
        else {
            throw analysisArtifactFailure("keyness.descriptor-result-mismatch")
        }
    }

    func importedSources(
        _ records: [GlifiProjectSourceRecord],
        from project: GlifiProjectPackage,
        maximumSourceByteCount: Int
    ) async throws -> [GlifiImportedText] {
        var sources: [GlifiImportedText] = []
        sources.reserveCapacity(records.count)
        for record in records {
            try Task.checkCancellation()
            let data = try await project.sourceData(for: record.sourceRevisionID)
            sources.append(
                try textImporter.importText(
                    from: data,
                    format: record.format,
                    limits: GlifiTextImportLimits(maximumByteCount: maximumSourceByteCount),
                    sourceRevisionID: record.sourceRevisionID
                )
            )
        }
        return sources
    }

    private func profile(_ importedText: GlifiImportedText) throws -> GlifiTextProfile {
        try GlifiDiagnostics.measure(.tokenize) {
            try textAnalyzer.profile(importedText)
        }
    }

    private func loadInvestigationEvents(
        from project: GlifiProjectPackage,
        records: [GlifiProjectInvestigationEventRecord]
    ) async throws -> [InvestigationEventID: GlifiInvestigationEvent] {
        var eventsByID: [InvestigationEventID: GlifiInvestigationEvent] = [:]
        eventsByID.reserveCapacity(records.count)
        for record in records {
            try Task.checkCancellation()
            eventsByID[record.eventID] = try await project.investigationEvent(
                for: record.eventID
            )
        }
        return eventsByID
    }

    private static func currentUnixMilliseconds() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1_000).rounded(.down))
    }

    private func cancellationFailure(
        operation: GlifiOperationKind = .profileCollection
    ) -> GlifiFailure {
        GlifiFailure(
            code: "operation.cancelled",
            category: .cancelled,
            operation: operation,
            retryDisposition: .newRequest,
            retainedState: .unchanged,
            messageKey: "failure.operation.cancelled"
        )
    }

    private func unreadableFileFailure() -> GlifiFailure {
        GlifiFailure(
            code: "file.unreadable",
            category: .transientIO,
            operation: .importText,
            retryDisposition: .transientBackoff,
            retainedState: .unchanged,
            messageKey: "failure.file.unreadable"
        )
    }
}

func analysisArtifactFailure(
    _ code: String,
    operation: GlifiOperationKind = .analyze
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: .invariantViolation,
        operation: operation,
        retryDisposition: .never,
        retainedState: .validityUnknown,
        messageKey: "failure.\(code)"
    )
}

private func investigationEngineFailure(
    _ code: String,
    category: GlifiFailureCategory = .invariantViolation
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .investigate,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}

private func interpretationHasCaveats(_ value: GlifiAnalysisInterpretation) -> Bool {
    value.insufficientEvidence != nil
        || value.evidence.contains { !$0.caveats.isEmpty }
        || value.findings.contains { !$0.caveats.isEmpty }
}

private func checkedExecutionWork(_ current: Int64, adding value: Int64) throws -> Int64 {
    let result = current.addingReportingOverflow(value)
    guard !result.overflow, value >= 0 else {
        throw GlifiFailure(
            code: "runtime.work-overflow",
            category: .invariantViolation,
            operation: .executePlan,
            retryDisposition: .never,
            retainedState: .validityUnknown,
            messageKey: "failure.runtime.work-overflow"
        )
    }
    return result.partialValue
}
