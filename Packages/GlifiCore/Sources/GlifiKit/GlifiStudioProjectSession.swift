// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Actor-isolated lifecycle for one verified `.glifi` project.
public actor GlifiStudioProjectSession {
    private static let maximumActiveAnalysisExecutionCount = 1

    private let engine: GlifiEngine
    private let project: GlifiProjectPackage
    private let runtimeEnvironment: GlifiStudioRuntimeEnvironment
    private let activityProvider: GlifiStudioActivityProvider
    private var isClosed = false
    private var activeAnalysisExecutions: [OperationID: Task<Void, Never>] = [:]

    init(
        engine: GlifiEngine, project: GlifiProjectPackage,
        runtimeEnvironment: GlifiStudioRuntimeEnvironment = .headless,
        activityProvider: GlifiStudioActivityProvider = .system
    ) {
        self.engine = engine
        self.project = project
        self.runtimeEnvironment = runtimeEnvironment
        self.activityProvider = activityProvider
    }

    /// Returns the current verified generation while the session is open.
    public func snapshot() async throws -> GlifiStudioProjectSnapshot {
        try ensureOpen()
        return GlifiStudioProjectSnapshot(await project.snapshot())
    }

    /// Validates, profiles, and incorporates one user-authorized text source.
    public func importText(
        at url: URL,
        format: GlifiStudioTextFormat
    ) async throws -> GlifiStudioProjectImportResult {
        try await performOperation(.importText) {
            return try await GlifiStudioProjectImportResult(
                engine.importText(at: url, format: format.coreValue, into: project)
            )
        }
    }

    /// Parses and executes one bounded textual query against the current generation.
    public func query(_ text: String) async throws -> GlifiStudioProjectQueryResult {
        try await performOperation(.query) {
            return try await GlifiStudioProjectQueryResult(engine.query(text, in: project))
        }
    }

    /// Executes QueryAST v1 JSON (at most 64 KiB) with the same limits and results as textual queries.
    ///
    /// Rejects incompatible schemas and malformed input without exposing decoder details.
    public func query(canonicalAST data: Data) async throws -> GlifiStudioProjectQueryResult {
        try await performOperation(.query) {
            return try await GlifiStudioProjectQueryResult(
                engine.query(canonicalAST: data, in: project))
        }
    }

    /// Loads the exact UTF-8 text of one immutable source revision for source jump.
    public func sourceText(sourceRevisionID: String) async throws -> GlifiStudioSourceText {
        try await performOperation(.query) {
            let revision = try SourceRevisionID(canonicalValue: sourceRevisionID)
            let imported = try await project.importedText(for: revision)
            let text = try imported.sourceRepresentationText
            return GlifiStudioSourceText(
                sourceRevisionID: sourceRevisionID, text: text, byteCount: text.utf8.count,
                document: imported.documentExtraction.map {
                    GlifiStudioDocumentProvenance(imported: imported, extraction: $0)
                })
        }
    }

    /// Shares the validated captured representation with package-owned analytical clients.
    package func importedTextForLaboratory(
        sourceRevisionID: String, maximumByteCount: Int
    ) async throws -> GlifiImportedText {
        try ensureOpen(operation: .analyze)
        return try await project.importedText(
            for: SourceRevisionID(canonicalValue: sourceRevisionID),
            limits: GlifiTextImportLimits(
                maximumByteCount: maximumByteCount,
                maximumExtractedByteCount: maximumByteCount))
    }

    /// Produces and persists one deterministic, explainable plan revision.
    public func planAnalysis(
        _ request: GlifiStudioAnalysisPlanRequest
    ) async throws -> GlifiStudioAnalysisPlanResult {
        try await performOperation(.plan) {
            return try await GlifiStudioAnalysisPlanResult(
                engine.planAnalysis(in: project, request: request.coreValue())
            )
        }
    }

    /// Creates one durable Italian-first, locale-independent investigation branch.
    public func createInvestigation(
        _ request: GlifiStudioInvestigationCreationRequest
    ) async throws -> GlifiStudioInvestigationResult {
        try await performOperation(.investigate) {
            return try await GlifiStudioInvestigationResult(
                engine.createInvestigation(in: project, request: request.coreValue())
            )
        }
    }

    /// Appends a non-destructive editorial-selection branch.
    public func reviseInvestigationSelection(
        _ request: GlifiStudioInvestigationSelectionRequest
    ) async throws -> GlifiStudioInvestigationResult {
        try await performOperation(.investigate) {
            return try await GlifiStudioInvestigationResult(
                engine.reviseInvestigationSelection(in: project, request: request.coreValue())
            )
        }
    }

    /// Lists every current branch head with stable ordering.
    public func investigationHeads() async throws -> [GlifiStudioInvestigation] {
        try ensureOpen()
        do {
            return try await engine.investigationHeads(in: project).map(
                GlifiStudioInvestigation.init
            )
        } catch {
            throw Self.map(error, operation: .investigate)
        }
    }

    /// Exports one investigation branch to a new verified directory without overwriting it.
    public func exportInvestigation(
        _ request: GlifiStudioScientificExportRequest,
        to destinationURL: URL
    ) async throws -> GlifiStudioExportReceipt {
        try await performOperation(.export) {
            return try await GlifiStudioExportReceipt(
                engine.exportInvestigation(
                    in: project,
                    request: request.coreValue(),
                    to: destinationURL
                )
            )
        }
    }

    /// Starts one owned plan execution with bounded progress and cooperative cancellation.
    public func executeAnalysisPlan(
        _ request: GlifiStudioAnalysisPlanRequest
    ) throws -> GlifiStudioAnalysisExecution {
        try ensureOpen(operation: .executePlan)
        guard
            activeAnalysisExecutions.count < Self.maximumActiveAnalysisExecutionCount
        else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "runtime.operation-limit-exceeded",
                    category: .insufficientResources,
                    operation: .executePlan,
                    retryDisposition: .afterConditionsChange,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.runtime.operation-limit-exceeded",
                    arguments: [
                        "maximumActiveOperationCount": String(
                            Self.maximumActiveAnalysisExecutionCount
                        )
                    ]
                )
            )
        }
        let coreRequest: GlifiAnalysisPlanRequest
        do {
            coreRequest = try request.coreValue()
        } catch {
            throw Self.map(error, operation: .executePlan)
        }
        let operationID = OperationID()
        let (stream, continuation) = AsyncThrowingStream.makeStream(
            of: GlifiStudioAnalysisExecutionEvent.self,
            throwing: (any Error).self,
            bufferingPolicy: .bufferingNewest(32)
        )
        let task = Task(priority: .userInitiated) {
            [engine, project, runtimeEnvironment, activityProvider] in
            do {
                let result = try await activityProvider.perform {
                    try await engine.executeAnalysisPlan(
                        in: project,
                        request: coreRequest,
                        operationID: operationID,
                        systemConditionsProvider: GlifiSystemConditionsProvider {
                            runtimeEnvironment.snapshot().coreValue
                        }
                    ) { progress in
                        _ = continuation.yield(
                            .progress(GlifiStudioOperationProgress(progress))
                        )
                    }
                }
                _ = continuation.yield(
                    .completed(GlifiStudioAnalysisExecutionResult(result))
                )
                continuation.finish()
            } catch {
                continuation.finish(throwing: Self.map(error, operation: .executePlan))
            }
            analysisExecutionDidFinish(operationID)
        }
        activeAnalysisExecutions[operationID] = task
        continuation.onTermination = { @Sendable termination in
            if case .cancelled = termination {
                task.cancel()
            }
        }
        return GlifiStudioAnalysisExecution(
            operationID: operationID,
            events: stream,
            task: task
        )
    }

    /// Computes a bounded deterministic profile of every source in the current generation.
    public func analyzeCorpus(
        options: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioCorpusAnalysisResult {
        try await performOperation(.analyze) {
            return try await GlifiStudioCorpusAnalysisResult(
                engine.analyzeCorpus(in: project, options: options.coreValue)
            )
        }
    }

    /// Compares two explicit, disjoint source groups from the current generation.
    public func compareKeyness(
        targetSourceRevisionIDs: [String],
        referenceSourceRevisionIDs: [String],
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard,
        keynessOptions: GlifiStudioKeynessOptions = .standard
    ) async throws -> GlifiStudioKeynessResult {
        try ensureOpen(operation: .analyze)
        do {
            let target = try targetSourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            let reference = try referenceSourceRevisionIDs.map(
                SourceRevisionID.init(canonicalValue:)
            )
            return try await GlifiStudioKeynessResult(
                engine.compareKeyness(
                    in: project,
                    targetSourceRevisionIDs: target,
                    referenceSourceRevisionIDs: reference,
                    corpusOptions: corpusOptions.coreValue,
                    keynessOptions: keynessOptions.coreValue
                )
            )
        } catch let failure as GlifiFailure where failure.code == "identifier.invalid" {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "keyness.invalid-source-identifier",
                    category: .invalidInput,
                    operation: .analyze,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.keyness.invalid-source-identifier"
                )
            )
        } catch {
            throw Self.map(error, operation: .analyze)
        }
    }

    /// Compares two explicit, disjoint source groups with `corpus-term-similarity-v1`.
    public func compareSimilarity(
        targetSourceRevisionIDs: [String],
        referenceSourceRevisionIDs: [String],
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioCorpusSimilarityResult {
        try ensureOpen(operation: .analyze)
        do {
            let target = try targetSourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            let reference = try referenceSourceRevisionIDs.map(
                SourceRevisionID.init(canonicalValue:)
            )
            return try await GlifiStudioCorpusSimilarityResult(
                engine.compareSimilarity(
                    in: project,
                    targetSourceRevisionIDs: target,
                    referenceSourceRevisionIDs: reference,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        } catch let failure as GlifiFailure where failure.code == "identifier.invalid" {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "corpus-similarity.invalid-source-identifier",
                    category: .invalidInput,
                    operation: .analyze,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.corpus-similarity.invalid-source-identifier"
                )
            )
        } catch {
            throw Self.map(error, operation: .analyze)
        }
    }

    /// Analyzes the document × term association of at least two sources.
    public func analyzeAssociation(
        sourceRevisionIDs: [String],
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioAssociationResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioAssociationResult(
                engine.analyzeAssociation(
                    in: project,
                    sourceRevisionIDs: ids,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Computes per-term dispersion over at least two sources.
    public func analyzeDispersion(
        sourceRevisionIDs: [String],
        partition: [[String]]? = nil,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioDispersionResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            let parts = try partition?.map {
                try $0.map(SourceRevisionID.init(canonicalValue:))
            }
            return try await GlifiStudioDispersionResult(
                engine.analyzeDispersion(
                    in: project,
                    sourceRevisionIDs: ids,
                    partition: parts,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Compares one document metric across at least two disjoint source groups.
    public func compareGroupMetric(
        groups: [[String]],
        metric: GlifiStudioDocumentMetric,
        options: GlifiStudioGroupComparisonOptions = .standard,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioGroupMetricResult {
        try await derivedOperation {
            let ids = try groups.map { try $0.map(SourceRevisionID.init(canonicalValue:)) }
            return try await GlifiStudioGroupMetricResult(
                engine.compareGroupMetric(
                    in: project,
                    groups: ids,
                    metric: metric.coreValue,
                    options: options.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Compares every pair of at least three disjoint source groups.
    public func postHocGroupMetric(
        groups: [[String]],
        metric: GlifiStudioDocumentMetric,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioPostHocResult {
        try await derivedOperation {
            let ids = try groups.map { try $0.map(SourceRevisionID.init(canonicalValue:)) }
            return try await GlifiStudioPostHocResult(
                engine.postHocGroupMetric(
                    in: project,
                    groups: ids,
                    metric: metric.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Computes collocation measures over at least two sources.
    public func analyzeCollocations(
        sourceRevisionIDs: [String],
        options: GlifiStudioCooccurrenceOptions = .standard,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioCollocationResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioCollocationResult(
                engine.analyzeCollocations(
                    in: project,
                    sourceRevisionIDs: ids,
                    options: options.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Correlates two document metrics over at least three sources.
    public func correlateMetrics(
        sourceRevisionIDs: [String],
        first: GlifiStudioDocumentMetric,
        second: GlifiStudioDocumentMetric,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioMetricCorrelationResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioMetricCorrelationResult(
                engine.correlateMetrics(
                    in: project,
                    sourceRevisionIDs: ids,
                    first: first.coreValue,
                    second: second.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Compares two metrics on the same documents of at least two sources.
    public func comparePairedMetrics(
        sourceRevisionIDs: [String],
        first: GlifiStudioDocumentMetric,
        second: GlifiStudioDocumentMetric,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioPairedMetricResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioPairedMetricResult(
                engine.comparePairedMetrics(
                    in: project,
                    sourceRevisionIDs: ids,
                    first: first.coreValue,
                    second: second.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Applies a declared multivariate method to the document × term matrix.
    public func analyzeMultivariate(
        sourceRevisionIDs: [String],
        method: GlifiStudioMultivariateMethod,
        maximumTermCount: Int = 50,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioMultivariateResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioMultivariateResult(
                engine.analyzeMultivariate(
                    in: project,
                    sourceRevisionIDs: ids,
                    method: try method.coreValue(),
                    maximumTermCount: maximumTermCount,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Weighs the document × term matrix with a declared TF, IDF and row normalization.
    public func analyzeTermWeighting(
        sourceRevisionIDs: [String],
        scheme: GlifiStudioTermWeightingScheme,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioTermWeightingResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioTermWeightingResult(
                engine.analyzeTermWeighting(
                    in: project,
                    sourceRevisionIDs: ids,
                    scheme: try scheme.coreValue(),
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Measures `MTLD-bidirectional-v1` per document and over the pooled sequence.
    public func analyzeLexicalDiversity(
        sourceRevisionIDs: [String],
        threshold: Double = 0.72,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioLexicalDiversityResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioLexicalDiversityResult(
                engine.analyzeLexicalDiversity(
                    in: project,
                    sourceRevisionIDs: ids,
                    threshold: threshold,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Observes rank-frequency, spectrum and vocabulary growth and fits `ZipfLogOLS-v1` and
    /// `HeapsLogOLS-v1`.
    public func analyzeLexicalLaws(
        sourceRevisionIDs: [String],
        parameters: GlifiStudioLexicalLawsParameters = .standard,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioLexicalLawsResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioLexicalLawsResult(
                engine.analyzeLexicalLaws(
                    in: project,
                    sourceRevisionIDs: ids,
                    parameters: parameters.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Selects sentences within a declared budget and resolves extracted text and original spans.
    public func analyzeExtractiveSummary(
        sourceRevisionIDs: [String],
        budget: GlifiStudioSummaryBudget = .standard,
        scheme: GlifiStudioTermWeightingScheme = .summaryStandard,
        method: GlifiStudioSummaryScoringMethod = .standard,
        redundancy: GlifiStudioSummaryRedundancy = .standard,
        graphConfiguration: GlifiStudioSummaryGraphConfiguration? = nil,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioExtractiveSummaryResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            let result = try await engine.analyzeExtractiveSummary(
                in: project,
                sourceRevisionIDs: ids,
                budget: try budget.coreValue(),
                scheme: try scheme.coreValue(),
                method: try method.coreValue(),
                redundancy: try redundancy.coreValue(),
                graphConfiguration: graphConfiguration?.coreValue,
                corpusOptions: corpusOptions.coreValue
            )
            let resolved = try await engine.resolveSummarySentences(
                result.value, in: project, corpusOptions: corpusOptions.coreValue)
            return GlifiStudioExtractiveSummaryResult(result, resolved: resolved)
        }
    }

    /// Counts forms, word n-grams or character n-grams and applies declared filters.
    public func analyzeNGramFrequencies(
        sourceRevisionIDs: [String],
        unit: GlifiStudioNGramUnit,
        filter: GlifiStudioTermFilter = .none,
        maximumRowCount: Int = 1_000,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioNGramFrequencyResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioNGramFrequencyResult(
                engine.analyzeNGramFrequencies(
                    in: project,
                    sourceRevisionIDs: ids,
                    unit: try unit.coreValue(),
                    filter: filter.coreValue,
                    maximumRowCount: maximumRowCount,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Ranks documents for a query with `BM25-v1` (`k1=1.2`, `b=0.75` by default).
    public func rankDocumentsBM25(
        sourceRevisionIDs: [String],
        query: String,
        k1: Double = 1.2,
        b: Double = 0.75,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioBM25Result {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioBM25Result(
                engine.rankDocumentsBM25(
                    in: project,
                    sourceRevisionIDs: ids,
                    query: query,
                    parameters: GlifiBM25Parameters(k1: k1, b: b),
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Computes token-window collocations over at least one source.
    public func analyzeWindowCollocations(
        sourceRevisionIDs: [String],
        options: GlifiStudioWindowCooccurrenceOptions = .standard,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioWindowCollocationResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioWindowCollocationResult(
                engine.analyzeWindowCollocations(
                    in: project,
                    sourceRevisionIDs: ids,
                    options: options.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Builds the token-window network over at least one source.
    public func analyzeWindowNetwork(
        sourceRevisionIDs: [String],
        window: GlifiStudioWindowCooccurrenceOptions = .standard,
        minimumLogDice: Double? = nil,
        usesWeightedJointCount: Bool = false,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioWindowNetworkResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioWindowNetworkResult(
                engine.analyzeWindowNetwork(
                    in: project,
                    sourceRevisionIDs: ids,
                    options: GlifiWindowNetworkOptions(
                        window: window.coreValue,
                        minimumLogDice: minimumLogDice,
                        usesWeightedJointCount: usesWeightedJointCount
                    ),
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Computes the term co-occurrence network over at least two sources.
    public func analyzeLexicalNetwork(
        sourceRevisionIDs: [String],
        options: GlifiStudioCooccurrenceOptions = .standard,
        corpusOptions: GlifiStudioCorpusAnalysisOptions = .standard
    ) async throws -> GlifiStudioLexicalNetworkResult {
        try await derivedOperation {
            let ids = try sourceRevisionIDs.map(SourceRevisionID.init(canonicalValue:))
            return try await GlifiStudioLexicalNetworkResult(
                engine.analyzeLexicalNetwork(
                    in: project,
                    sourceRevisionIDs: ids,
                    options: options.coreValue,
                    corpusOptions: corpusOptions.coreValue
                )
            )
        }
    }

    /// Builds the view specifications of the outputs of one plan execution.
    ///
    /// Every specification reads back the persisted Artifact of a step without
    /// recomputation; outputs without a dedicated view are skipped.
    public func visualizations(
        for execution: GlifiStudioAnalysisExecutionResult
    ) async throws -> [GlifiStudioVisualization] {
        try await derivedOperation {
            var visualizations: [GlifiStudioVisualization] = []
            for artifact in execution.artifacts {
                let artifactID = try ArtifactID(canonicalValue: artifact.artifactID)
                switch artifact.outputSchemaIdentifier {
                case GlifiCorpusMultivariateAnalysis.outputSchemaIdentifier:
                    let result = try await GlifiStudioMultivariateResult(
                        engine.storedDerivedResult(
                            GlifiCorpusMultivariateAnalysis.self,
                            artifactID: artifactID,
                            in: project
                        )
                    )
                    if let plot = try GlifiStudioVisualizationBuilder.factorPlot(result) {
                        visualizations.append(plot)
                    }
                    if let tree = try GlifiStudioVisualizationBuilder.dendrogram(result) {
                        visualizations.append(tree)
                    }
                case GlifiWindowNetworkAnalysis.outputSchemaIdentifier:
                    let result = try await GlifiStudioWindowNetworkResult(
                        engine.storedDerivedResult(
                            GlifiWindowNetworkAnalysis.self,
                            artifactID: artifactID,
                            in: project
                        )
                    )
                    visualizations.append(GlifiStudioVisualizationBuilder.network(result))
                case GlifiWindowCollocationAnalysis.outputSchemaIdentifier:
                    let result = try await GlifiStudioWindowCollocationResult(
                        engine.storedDerivedResult(
                            GlifiWindowCollocationAnalysis.self,
                            artifactID: artifactID,
                            in: project
                        )
                    )
                    visualizations.append(
                        GlifiStudioVisualizationBuilder.collocationTable(result))
                default:
                    continue
                }
            }
            return visualizations
        }
    }

    /// Writes a view export (table, specification, provenance manifest) to a new folder.
    ///
    /// The Artifact must belong to the current generation; the folder is staged next to the
    /// destination, verified against its manifest and moved into place in one step.
    public func exportVisualization(
        _ visualization: GlifiStudioVisualization,
        to destinationURL: URL
    ) async throws -> GlifiStudioVisualExportReceipt {
        try ensureOpen(operation: .export)
        let current = await project.snapshot()
        guard
            current.artifacts.contains(where: {
                $0.artifactID.canonicalValue == visualization.artifactID
            })
        else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "visual-export.stale-artifact",
                    category: .staleArtifact,
                    operation: .export,
                    retryDisposition: .newRequest,
                    retainedState: .unchanged,
                    messageKey: "failure.visual-export.stale-artifact"
                ))
        }
        let files = try GlifiStudioVisualExport.bundle(
            visualization,
            projectID: current.projectID.canonicalValue,
            generation: current.generation,
            createdAt: Date()
        )
        _ = try GlifiStudioVisualExport.verify(files)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "visual-export.destination-exists",
                    category: .invalidInput,
                    operation: .export,
                    retryDisposition: .afterCorrection,
                    retainedState: .unchanged,
                    messageKey: "failure.visual-export.destination-exists"
                ))
        }
        let staging = destinationURL.deletingLastPathComponent().appending(
            path: ".glifi-visual-export-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
            for (path, data) in files {
                try data.write(to: staging.appending(path: path), options: .withoutOverwriting)
            }
            try fileManager.moveItem(at: staging, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "visual-export.write-failed",
                    category: .transientIO,
                    operation: .export,
                    retryDisposition: .transientBackoff,
                    retainedState: .unchanged,
                    messageKey: "failure.visual-export.write-failed"
                ))
        }
        return GlifiStudioVisualExportReceipt(
            manifestDigest: GlifiStudioVisualExport.digest(
                files[GlifiStudioVisualExport.manifestFileName] ?? Data()),
            fileCount: files.count
        )
    }

    /// Appends one change to the qualitative history and returns the new projection.
    public func appendQualitativeChange(
        _ change: GlifiStudioQualitativeChange
    ) async throws -> GlifiStudioQualitativeState {
        try await derivedOperation {
            _ = try await engine.appendQualitativeEvent(
                try change.coreValue(),
                recordedAtUnixMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
                in: project
            )
            return GlifiStudioQualitativeState(try await engine.qualitativeState(in: project))
        }
    }

    /// Sentences of the extracted text of a source, for structured coding selection.
    public func textSegments(sourceRevisionID: String) async throws -> [GlifiStudioTextSegment] {
        try await derivedOperation {
            try await engine.textSegments(
                sourceRevisionID: try SourceRevisionID(canonicalValue: sourceRevisionID),
                in: project
            ).map {
                GlifiStudioTextSegment(
                    startUTF8: $0.range.start, endUTF8: $0.range.end, text: $0.text)
            }
        }
    }

    /// Resolves a structured passage selection into one codable interval of the extracted text.
    ///
    /// The selection is either whole sentences, by their position among the segments, or an
    /// interval of characters; the resolved interval always begins and ends on a character
    /// boundary and covers at least one visible character.
    public func passage(
        sourceRevisionID: String,
        selection: GlifiStudioPassageSelection
    ) async throws -> GlifiStudioTextSegment {
        guard
            let resolved = try await passages(
                sourceRevisionID: sourceRevisionID, selections: [selection]
            ).first
        else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "qualitative.invalid-selection",
                    category: .invalidInput,
                    operation: .investigate,
                    retryDisposition: .afterCorrection,
                    retainedState: .unchanged,
                    messageKey: "failure.qualitative.invalid-selection"
                ))
        }
        return resolved
    }

    /// Resolves several selections of the same source, reading the extracted text once.
    ///
    /// The whole call fails when any selection is invalid.
    public func passages(
        sourceRevisionID: String,
        selections: [GlifiStudioPassageSelection]
    ) async throws -> [GlifiStudioTextSegment] {
        try await derivedOperation {
            try await engine.passages(
                sourceRevisionID: try SourceRevisionID(canonicalValue: sourceRevisionID),
                selections: selections.map(\.coreValue),
                in: project
            ).map {
                GlifiStudioTextSegment(
                    startUTF8: $0.range.start, endUTF8: $0.range.end, text: $0.text)
            }
        }
    }

    /// Number of characters of the extracted text, the upper bound of a character selection.
    public func extractedCharacterCount(sourceRevisionID: String) async throws -> Int {
        try await derivedOperation {
            try await engine.extractedCharacterCount(
                sourceRevisionID: try SourceRevisionID(canonicalValue: sourceRevisionID),
                in: project
            )
        }
    }

    /// Projection of the persisted qualitative history.
    public func qualitativeState() async throws -> GlifiStudioQualitativeState {
        try await derivedOperation(admissionOperation: nil) {
            GlifiStudioQualitativeState(try await engine.qualitativeState(in: project))
        }
    }

    /// Computes and persists agreement from the codings of one codebook revision.
    public func assessStoredCodingAgreement(
        codebookID: String,
        codebookRevision: Int,
        coderIDs: [String]
    ) async throws -> GlifiStudioStoredCodingAgreement {
        try await derivedOperation {
            let stored = try await engine.assessStoredCodingAgreement(
                codebookID: codebookID, codebookRevision: codebookRevision, coderIDs: coderIDs,
                in: project)
            return GlifiStudioStoredCodingAgreement(
                agreement: GlifiStudioCodingAgreementResult(stored.agreement),
                ambiguousUnitCount: stored.ambiguousUnitCount)
        }
    }

    /// Computes inter-coder agreement over a caller-supplied nominal coding table.
    public func assessCodingAgreement(
        _ request: GlifiStudioCodingAgreementRequest
    ) async throws -> GlifiStudioCodingAgreementResult {
        try await derivedOperation {
            try await GlifiStudioCodingAgreementResult(
                engine.assessCodingAgreement(in: project, request: request.coreValue)
            )
        }
    }

    /// Applies the common session admission and failure boundary to one operation.
    private func performOperation<Result>(
        _ operation: GlifiOperationKind,
        _ body: () async throws -> Result
    ) async throws -> Result {
        try ensureOpen(operation: operation)
        do {
            return try await body()
        } catch {
            throw Self.map(error, operation: operation)
        }
    }

    private func derivedOperation<Result>(
        admissionOperation: GlifiOperationKind? = .analyze,
        _ body: () async throws -> Result
    ) async throws -> Result {
        try ensureOpen(operation: admissionOperation)
        do {
            return try await body()
        } catch let failure as GlifiFailure where failure.code == "identifier.invalid" {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "derived-analysis.invalid-source-identifier",
                    category: .invalidInput,
                    operation: .analyze,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.derived-analysis.invalid-source-identifier"
                )
            )
        } catch {
            throw Self.map(error, operation: .analyze)
        }
    }

    /// Closes this logical session idempotently and rejects subsequent operations.
    public func close() async {
        isClosed = true
        let tasks = Array(activeAnalysisExecutions.values)
        for task in activeAnalysisExecutions.values {
            task.cancel()
        }
        for task in tasks {
            await task.value
        }
        activeAnalysisExecutions.removeAll(keepingCapacity: false)
    }

    private func analysisExecutionDidFinish(_ operationID: OperationID) {
        activeAnalysisExecutions[operationID] = nil
    }

    private func ensureOpen(operation: GlifiOperationKind? = nil) throws {
        guard !isClosed else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "project.session-closed",
                    category: .invalidInput,
                    operation: .persistProject,
                    retryDisposition: .afterCorrection,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.project.session-closed"
                )
            )
        }
        if let operation {
            try runtimeEnvironment.admit(operation: operation)
        }
    }

    private static func map(_ error: Error, operation: GlifiOperationKind) -> GlifiStudioFailure {
        if let failure = error as? GlifiStudioFailure {
            return failure
        }
        if let failure = error as? GlifiFailure {
            return GlifiStudioFailure(failure)
        }
        if error is CancellationError {
            return GlifiStudioFailure(
                GlifiFailure(
                    code: "operation.cancelled",
                    category: .cancelled,
                    operation: operation,
                    retryDisposition: .newRequest,
                    retainedState: .lastCommittedGeneration,
                    messageKey: "failure.operation.cancelled"
                ))
        }
        return GlifiStudioFailure(
            GlifiFailure(
                code: "internal.unexpected",
                category: .invariantViolation,
                operation: operation,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.internal.unexpected"
            )
        )
    }
}
