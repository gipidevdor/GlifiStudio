// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import GlifiKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Package document type for `.glifi` projects (`studio.glifi.project`).
    nonisolated static var glifiProject: UTType {
        UTType(exportedAs: "studio.glifi.project", conformingTo: .package)
    }
}

enum EnginePresentationState: Sendable {
    case checking
    case ready
}

enum StudioBusyState: Sendable, Equatable {
    case idle
    case working(messageKey: String)
}

/// Admits work synchronously after every currently owned task has reached its terminal state.
///
/// The owner clears or replaces its current task before that task completes.
@MainActor
func studioAdmitAfterLatestOwnedTask<Result: Sendable>(
    current: @MainActor () -> Task<Void, Never>?, admission: @MainActor () -> Result
) async -> Result? {
    while let task = current() {
        await task.value
        guard !Task.isCancelled else { return nil }
    }
    guard !Task.isCancelled else { return nil }
    return admission()
}

enum StudioIntentOption: String, CaseIterable, Identifiable, Sendable {
    case understandCollection = "understand.collection"
    case discoverContents = "discover.contents"
    case compareObjects = "compare.objects"
    case exploreRelationships = "explore.relationships"
    case identifyThemes = "identify.themes"
    case findSimilar = "find.similar"
    case searchSources = "search.sources"
    case reviewCompletely = "review.completely"

    var id: String { rawValue }

    var titleKey: String {
        "intent.\(rawValue.replacingOccurrences(of: ".", with: "-"))"
    }

    /// Whether planner-v2 capabilities for this intent use target and reference groups.
    var usesComparisonGroups: Bool {
        switch self {
        case .compareObjects, .findSimilar, .reviewCompletely: true
        case .understandCollection, .discoverContents, .exploreRelationships, .identifyThemes,
            .searchSources:
            false
        }
    }
}

#if os(macOS)
    private struct StudioDocumentAttachmentWaiter {
        let requestID: UUID
        let continuation: CheckedContinuation<Void, Never>
    }

    enum StudioTextAnalysisScope: CaseIterable, Identifiable, Sendable {
        case allSources
        case selectedSources

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .allSources: "summary.scope.all"
            case .selectedSources: "summary.scope.selected"
            }
        }
    }

    /// Editable values stay separate from the parameters captured in a completed result.
    struct StudioLexicalLawsDraft: Equatable, Sendable {
        var checkpointCount = GlifiStudioLexicalLawsParameters.standard.checkpointCount
        var firstRank = GlifiStudioLexicalLawsParameters.standard.zipfFirstRank
        var usesLastObservedRank = true
        var lastRank = 100
        var rankRowLimit = GlifiStudioLexicalLawsParameters.standard.rankRowLimit

        var parameters: GlifiStudioLexicalLawsParameters {
            GlifiStudioLexicalLawsParameters(
                checkpointCount: checkpointCount, zipfFirstRank: firstRank,
                zipfLastRank: usesLastObservedRank ? nil : lastRank, rankRowLimit: rankRowLimit)
        }

        var isValid: Bool {
            (2...10_000).contains(checkpointCount) && firstRank >= 1
                && (usesLastObservedRank || lastRank > firstRank)
                && (1...100_000).contains(rankRowLimit)
        }
    }

    enum StudioSummaryMethod: String, CaseIterable, Identifiable, Sendable {
        case sentenceTFIDFMean = "SentenceTFIDFMean-v1"
        case centroidCosine = "CentroidCosine-v1"
        case lexRank = "LexRankSentence-v1"
        case textRank = "TextRankSentence-v1"
        case textRankConfigurable = "TextRankSentence-configurable-v1"
        case lexRankContinuous = "LexRankSentence-continuous-v1"
        case lexRankThreshold = "LexRankSentence-threshold-v1"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .sentenceTFIDFMean: "summary.method.tfidf-mean"
            case .centroidCosine: "summary.method.centroid-cosine"
            case .lexRank: "summary.method.lexrank"
            case .textRank: "summary.method.textrank"
            case .textRankConfigurable: "summary.method.textrank-configurable"
            case .lexRankContinuous: "summary.method.lexrank-continuous"
            case .lexRankThreshold: "summary.method.lexrank-threshold"
            }
        }

        var supportsGraphConfiguration: Bool {
            switch self {
            case .sentenceTFIDFMean, .centroidCosine, .lexRank, .textRank: false
            case .textRankConfigurable, .lexRankContinuous, .lexRankThreshold: true
            }
        }
    }

    enum StudioSummaryBudgetUnit: String, CaseIterable, Identifiable, Sendable {
        case sentences = "Budget-sentences-v1"
        case lexicalTokens = "Budget-lexical-tokens-v1"
        case characters = "Budget-characters-v1"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .sentences: "summary.budget.sentences"
            case .lexicalTokens: "summary.budget.lexical-tokens"
            case .characters: "summary.budget.characters"
            }
        }
    }

    enum StudioSummaryRedundancy: String, CaseIterable, Identifiable, Sendable {
        case none = "redundancy.none-v1"
        case maximalMarginalRelevance = "MMR-v1"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .none: "summary.redundancy.none"
            case .maximalMarginalRelevance: "summary.redundancy.mmr"
            }
        }
    }

    /// Effective parameters captured independently of later edits to the controls.
    struct StudioSummaryOptions: Equatable, Sendable {
        let scope: StudioTextAnalysisScope
        let sourceRevisionIDs: [String]
        let method: StudioSummaryMethod
        let budgetUnit: StudioSummaryBudgetUnit
        let budgetLimit: Int
        let redundancy: StudioSummaryRedundancy
        let mmrLambda: Double?
        let graphConfiguration: GlifiStudioSummaryGraphConfiguration?
        let scheme: GlifiStudioTermWeightingScheme
        let corpusOptions: GlifiStudioCorpusAnalysisOptions
    }

    struct StudioBM25Options: Equatable, Sendable {
        let scope: StudioTextAnalysisScope
        let sourceRevisionIDs: [String]
        let query: String
        let k1: Double
        let b: Double
        let corpusOptions: GlifiStudioCorpusAnalysisOptions
    }

    enum StudioFrequencyUnit: String, CaseIterable, Identifiable, Sendable {
        case forms = "form"
        case words = "word"
        case characters = "character"
        case paddedCharacters = "character-padded"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .forms: "frequency.unit.forms"
            case .words: "frequency.unit.words"
            case .characters: "frequency.unit.characters"
            case .paddedCharacters: "frequency.unit.padded-characters"
            }
        }
    }

    struct StudioFrequencyOptions: Equatable, Sendable {
        let scope: StudioTextAnalysisScope
        let sourceRevisionIDs: [String]
        let unit: GlifiStudioNGramUnit
        let filter: GlifiStudioTermFilter
        let maximumRowCount: Int
        let corpusOptions: GlifiStudioCorpusAnalysisOptions
    }

    struct StudioMTLDOptions: Equatable, Sendable {
        let scope: StudioTextAnalysisScope
        let sourceRevisionIDs: [String]
        let threshold: Double
        let corpusOptions: GlifiStudioCorpusAnalysisOptions
    }

    enum StudioTermFrequencyVariant: String, CaseIterable, Identifiable, Sendable {
        case raw = "TF-raw-v1"
        case binary = "TF-binary-v1"
        case l1 = "TF-L1-v1"
        case max = "TF-max-v1"
        case augmented = "TF-augmented-v1"
        case sublinear = "TF-sublinear-v1"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .raw: "weighting.tf.raw"
            case .binary: "weighting.tf.binary"
            case .l1: "weighting.tf.l1"
            case .max: "weighting.tf.max"
            case .augmented: "weighting.tf.augmented"
            case .sublinear: "weighting.tf.sublinear"
            }
        }
    }

    enum StudioInverseDocumentFrequencyVariant: String, CaseIterable, Identifiable, Sendable {
        case none = "IDF-none-v1"
        case unsmoothed = "IDF-unsmoothed-v1"
        case smooth = "IDF-smooth-v1"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .none: "weighting.idf.none"
            case .unsmoothed: "weighting.idf.unsmoothed"
            case .smooth: "weighting.idf.smooth"
            }
        }
    }

    enum StudioTermWeightingNormalization: String, CaseIterable, Identifiable, Sendable {
        case none = "RowNorm-none-v1"
        case l1 = "RowNorm-L1-v1"
        case l2 = "RowNorm-L2-v1"

        var id: Self { self }

        var titleKey: String {
            switch self {
            case .none: "weighting.normalization.none"
            case .l1: "weighting.normalization.l1"
            case .l2: "weighting.normalization.l2"
            }
        }
    }

    struct StudioTermWeightingOptions: Equatable, Sendable {
        let scope: StudioTextAnalysisScope
        let sourceRevisionIDs: [String]
        let scheme: GlifiStudioTermWeightingScheme
        let corpusOptions: GlifiStudioCorpusAnalysisOptions
    }

    struct StudioKeynessRequestOptions: Equatable, Sendable {
        let targetSourceRevisionIDs: [String]
        let referenceSourceRevisionIDs: [String]
        let corpusOptions: GlifiStudioCorpusAnalysisOptions
        let keynessOptions: GlifiStudioKeynessOptions
    }
#endif

@MainActor
@Observable
final class StudioHomeModel {
    private(set) var engineState: EnginePresentationState = .checking
    private(set) var busyState: StudioBusyState = .idle
    private(set) var lastFailure: GlifiStudioFailure?
    private(set) var projectURL: URL?
    private(set) var snapshot: GlifiStudioProjectSnapshot?
    private(set) var lastProfile: GlifiStudioTextProfile?
    private(set) var lastCorpusAnalysis: GlifiStudioCorpusAnalysisResult?
    private(set) var lastCorpusOptions: GlifiStudioCorpusAnalysisOptions?
    private(set) var lastKeyness: GlifiStudioKeynessResult?
    private(set) var lastKeynessOptions: GlifiStudioKeynessOptions?
    private(set) var lastImportedFileName: String?
    private(set) var importProgressCompleted: Int = 0
    private(set) var importProgressTotal: Int = 0
    private(set) var planResult: GlifiStudioAnalysisPlanResult?
    private(set) var executionResult: GlifiStudioAnalysisExecutionResult?
    private(set) var executionProgress: GlifiStudioOperationProgress?
    private(set) var visualizations: [GlifiStudioVisualization] = []
    private(set) var qualitativeState: GlifiStudioQualitativeState?
    var selectedCodebookID: String? {
        didSet {
            storedAgreement = nil
            storedAgreementCodebookID = nil
            storedAgreementRevision = nil
        }
    }
    private(set) var codingSegments: [GlifiStudioTextSegment] = []
    private(set) var codingSourceRevisionID: String?
    private(set) var codingSourceCharacterCount = 0
    private(set) var codingPassage: GlifiStudioTextSegment?
    private(set) var codingTexts: [String: String] = [:]
    private(set) var storedAgreement: GlifiStudioStoredCodingAgreement?
    private(set) var storedAgreementCodebookID: String?
    private(set) var storedAgreementRevision: Int?
    var coderDraft = "c1"
    private(set) var selectedVisualMarkID: String?
    private(set) var investigation: GlifiStudioInvestigation?
    private(set) var investigationHeads: [GlifiStudioInvestigation] = []
    private(set) var lastInvestigationProjectID: String?
    private(set) var lastInvestigationGeneration: Int?
    private(set) var lastInvestigationCreationRequest: GlifiStudioInvestigationCreationRequest?
    private(set) var lastInvestigationSelectionRequest: GlifiStudioInvestigationSelectionRequest?
    private(set) var lastPlanRequest: GlifiStudioAnalysisPlanRequest?
    private(set) var queryResult: GlifiStudioProjectQueryResult?
    private(set) var lastQueryExpression: String?
    private(set) var selectedQueryMatchID: String?
    private(set) var sourceText: GlifiStudioSourceText?
    private(set) var browsedSourceText: GlifiStudioSourceText?
    private(set) var evidenceSourceText: GlifiStudioSourceText?
    private(set) var evidenceSourceRanges: [GlifiStudioUTF8Range] = []
    private(set) var focusedEvidenceID: String?
    private(set) var exportReceipt: GlifiStudioExportReceipt?
    private(set) var exportPreviewMarkdown: String?
    private(set) var lastExportRequest: GlifiStudioScientificExportRequest?
    private(set) var selectedFindingID: String?
    private(set) var editorialSelectedFindingIDs: Set<String> = []
    private(set) var lastProjectBookmark: Data?

    var projectNameDraft = String(localized: "project.default-name")
    var questionDraft = String(localized: "investigation.default-question")
    var selectedIntent: StudioIntentOption = .understandCollection
    var queryDraft = ""
    var selectedTargetRevisionIDs: Set<String> = []
    var selectedReferenceRevisionIDs: Set<String> = []

    #if os(macOS)
        let advancedAnalysis = StudioAdvancedAnalysisModel()
        let corpusMethods = StudioCorpusMethodsModel()
        let statistics = StudioStatisticsModel()
        let evaluation = StudioEvaluationModel()
        let operators = StudioOperatorsModel()
        let linguistics = StudioLinguisticModel()
        var textAnalysisScope: StudioTextAnalysisScope = .allSources
        var selectedTextAnalysisSourceRevisionIDs: Set<String> = []
        var summaryMethod: StudioSummaryMethod = .sentenceTFIDFMean
        var summaryBudgetUnit: StudioSummaryBudgetUnit = .sentences
        var summaryBudgetLimit = 3
        var summaryRedundancy: StudioSummaryRedundancy = .none
        var summaryMMRLambda = 0.5
        var summaryGraphDamping = GlifiStudioSummaryGraphConfiguration.standard.damping
        var summaryGraphTolerance = GlifiStudioSummaryGraphConfiguration.standard.tolerance
        var summaryGraphMaximumIterations = GlifiStudioSummaryGraphConfiguration.standard
            .maximumIterations
        var summaryGraphSimilarityThreshold = GlifiStudioSummaryGraphConfiguration.standard
            .similarityThreshold
        private(set) var lastExtractiveSummary: GlifiStudioExtractiveSummaryResult?
        private(set) var lastSummaryOptions: StudioSummaryOptions?
        private(set) var summarySourceText: GlifiStudioSourceText?
        private(set) var summarySourceRanges: [GlifiStudioUTF8Range] = []
        private(set) var focusedSummarySentenceID: String?
        var bm25QueryDraft = ""
        var bm25K1 = 1.2
        var bm25B = 0.75
        private(set) var lastBM25Ranking: GlifiStudioBM25Result?
        private(set) var lastBM25Options: StudioBM25Options?
        private(set) var bm25SourceText: GlifiStudioSourceText?
        var frequencyUnit: StudioFrequencyUnit = .forms
        var frequencyN = 2
        var frequencyStopwordsDraft = ""
        var frequencyMinimumLength = 1
        var frequencyMinimumCount = 1
        var frequencyMinimumDocumentFrequency = 1
        var frequencyMaximumDocumentProportion = 1.0
        var frequencyMaximumRowCount = 1_000
        private(set) var lastNGramFrequencies: GlifiStudioNGramFrequencyResult?
        private(set) var lastFrequencyOptions: StudioFrequencyOptions?
        private(set) var frequencyPage = 0
        let frequencyPageSize = 50
        var mtldThreshold = 0.72
        private(set) var lastLexicalDiversity: GlifiStudioLexicalDiversityResult?
        private(set) var lastMTLDOptions: StudioMTLDOptions?
        var lexicalLawsDraft = StudioLexicalLawsDraft()
        private(set) var lastLexicalLaws: GlifiStudioLexicalLawsResult?
        var termFrequencyVariant: StudioTermFrequencyVariant = .raw
        var inverseDocumentFrequencyVariant: StudioInverseDocumentFrequencyVariant = .smooth
        var termWeightingNormalization: StudioTermWeightingNormalization = .none
        private(set) var lastTermWeighting: GlifiStudioTermWeightingResult?
        private(set) var lastTermWeightingOptions: StudioTermWeightingOptions?
        private(set) var termWeightingObservedCellCounts: [Int] = []
        private(set) var termWeightingCellPage = 0
        private(set) var termWeightingTermPage = 0
        let termWeightingCellPageSize = 50
        let termWeightingTermPageSize = 50
        var keynessMaximumHypothesisCount = 100_000
        var keynessLowExpectedCountThreshold = 5.0
        var keynessConfidenceLevel = 0.95
        private(set) var lastKeynessRequestOptions: StudioKeynessRequestOptions?
        private(set) var keynessPage = 0
        let keynessPageSize = 50
    #endif

    private let service: GlifiStudioService
    private var session: GlifiStudioProjectSession?
    private var activeExecution: GlifiStudioAnalysisExecution?
    #if os(macOS)
        private var activeOperationTask: Task<Void, Never>?
        private var activeAnalysisTask: Task<Void, any Error>?
        private var projectClosingTask: Task<Void, Never>?
        private var isClosingProject = false
        private var latestDocumentAttachmentID: UUID?
        private var documentAttachmentWaiter: StudioDocumentAttachmentWaiter?
    #endif
    private var securityScopedProjectURL: URL?

    #if os(macOS)
        /// Drains owned work before releasing the session and its security-scoped access.
        func closeProject() async {
            if let projectClosingTask {
                await projectClosingTask.value
                return
            }
            isClosingProject = true
            latestDocumentAttachmentID = nil
            let waiting = documentAttachmentWaiter
            documentAttachmentWaiter = nil
            waiting?.continuation.resume()
            let operation = activeOperationTask
            operation?.cancel()
            activeAnalysisTask?.cancel()
            activeExecution?.cancel()
            let closing = Task { @MainActor [self] in
                defer {
                    isClosingProject = false
                    projectClosingTask = nil
                }
                await operation?.value
                await session?.close()
                session = nil
                activeExecution = nil
                securityScopedProjectURL?.stopAccessingSecurityScopedResource()
                securityScopedProjectURL = nil
                projectURL = nil
                snapshot = nil
                clearAnalysisState()
            }
            projectClosingTask = closing
            await closing.value
        }
    #endif

    init(service: GlifiStudioService = GlifiStudioService()) {
        self.service = service
    }

    isolated deinit {
        securityScopedProjectURL?.stopAccessingSecurityScopedResource()
    }

    var isBusy: Bool {
        if case .working = busyState {
            return true
        }
        return false
    }

    /// Localized message of the last failure, with the category as declared fallback.
    ///
    /// Un codice senza messaggio proprio non deve mai mostrare la chiave grezza all'utente: in
    /// quel caso si usa il messaggio della categoria, che resta vero per ogni codice della stessa
    /// classe (GS-API-001 § 8).
    var failureMessage: LocalizedStringKey? {
        guard let failure = lastFailure else { return nil }
        return Self.localizedFailureMessage(
            messageKey: failure.messageKey, category: failure.category)
    }

    static func localizedFailureMessage(
        messageKey: String,
        category: String
    ) -> LocalizedStringKey {
        let absent = "\u{0}assente"
        let localized = Bundle.main.localizedString(forKey: messageKey, value: absent, table: nil)
        return LocalizedStringKey(localized == absent ? "failure.category.\(category)" : messageKey)
    }

    var findings: [GlifiStudioFinding] {
        executionResult?.interpretation.findings ?? []
    }

    var insufficientEvidence: GlifiStudioInsufficientEvidenceOutcome? {
        executionResult?.interpretation.insufficientEvidence
    }

    var selectedFinding: GlifiStudioFinding? {
        guard let selectedFindingID else {
            return findings.first
        }
        return findings.first { $0.id == selectedFindingID } ?? findings.first
    }

    var evidenceForSelectedFinding: [GlifiStudioEvidence] {
        guard let finding = selectedFinding else {
            return []
        }
        let ids = Set(finding.evidenceReferences.map(\.evidenceID))
        return (executionResult?.interpretation.evidence ?? []).filter { ids.contains($0.id) }
    }

    func evidenceDisposition(for evidenceID: String) -> String? {
        selectedFinding?.evidenceReferences.first { $0.evidenceID == evidenceID }?.disposition
    }

    func evidenceDispositionReason(for evidenceID: String) -> String? {
        selectedFinding?.evidenceReferences.first { $0.evidenceID == evidenceID }?.reasonIdentifier
    }

    var selectedQueryMatch: GlifiStudioQueryMatch? {
        guard let selectedQueryMatchID else {
            return queryResult?.matches.first
        }
        return queryResult?.matches.first { $0.id == selectedQueryMatchID }
            ?? queryResult?.matches.first
    }

    var canCancelExecution: Bool {
        activeExecution != nil
    }

    #if os(macOS)
        var canCancelAnalysis: Bool {
            activeAnalysisTask != nil || activeExecution != nil
        }

        /// Requests cancellation while leaving cleanup to the task that owns the operation.
        func cancelAnalysis() {
            activeAnalysisTask?.cancel()
            activeExecution?.cancel()
        }
    #endif

    var activeExecutionOperationID: String? {
        activeExecution?.operationID
    }

    var mustPathHasProject: Bool { snapshot != nil }
    var mustPathHasSources: Bool { (snapshot?.sourceCount ?? 0) > 0 }
    var mustPathHasPlanOrCorpus: Bool { planResult != nil || lastCorpusAnalysis != nil }
    var mustPathHasQuery: Bool { queryResult != nil }
    var mustPathHasFindings: Bool { !findings.isEmpty || insufficientEvidence != nil }
    var mustPathHasInvestigation: Bool { investigation != nil }
    var mustPathHasExport: Bool { exportReceipt != nil }

    /// A displayed plan keeps its original scope when navigation changes the draft intent.
    var isPlanDraftChanged: Bool {
        guard let plan = planResult?.plan else { return false }
        let request = makePlanRequest()
        return plan.intent != request.intent
            || plan.targetSourceRevisionIDs != request.targetSourceRevisionIDs
            || plan.referenceSourceRevisionIDs != request.referenceSourceRevisionIDs
            || plan.resolvedScopeSourceRevisionIDs.sorted()
                != (snapshot?.sources.map(\.sourceRevisionID).sorted() ?? [])
    }

    func prepare() async {
        let status = await service.status()
        guard !Task.isCancelled else {
            return
        }
        switch status {
        case .ready:
            engineState = .ready
        }
    }

    func createProject() async {
        await run(messageKey: "progress.creating-project") { [self] in
            let root = try Self.projectsRoot()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let sanitized = Self.sanitizeFileName(projectNameDraft)
            let url = root.appending(path: "\(sanitized).glifi", directoryHint: .isDirectory)
            try await initializePackage(at: url, allowsEmptyPlaceholder: false)
        }
    }

    func attachDocument(at url: URL?, needsPackageInitialization: Bool) async {
        guard let url else {
            return
        }
        #if os(macOS)
            guard
                let requestID = await studioAdmitAfterLatestOwnedTask(
                    current: { projectClosingTask },
                    admission: { [self] in
                        let requestID = UUID()
                        latestDocumentAttachmentID = requestID
                        let superseded = documentAttachmentWaiter
                        documentAttachmentWaiter = nil
                        superseded?.continuation.resume()
                        return requestID
                    })
            else { return }
            defer { finishDocumentAttachment(requestID) }
            while documentAttachmentIsCurrent(requestID) {
                guard projectURL?.standardizedFileURL != url.standardizedFileURL || session == nil
                else { return }
                await waitForDocumentAttachmentIdle(requestID)
                guard documentAttachmentIsCurrent(requestID) else { return }
                guard projectURL?.standardizedFileURL != url.standardizedFileURL || session == nil
                else { return }
                let admitted: Bool
                if needsPackageInitialization,
                    !FileManager.default.fileExists(
                        atPath: url.appending(path: "manifest.json").path)
                {
                    admitted = await run(
                        messageKey: "progress.creating-project", documentAttachmentID: requestID
                    ) { [self] in
                        try await initializePackage(
                            at: url, allowsEmptyPlaceholder: true,
                            documentAttachmentID: requestID)
                    }
                } else {
                    admitted = await openProject(at: url, documentAttachmentID: requestID)
                }
                if admitted { return }
            }
        #else
            guard projectURL?.standardizedFileURL != url.standardizedFileURL || session == nil
            else {
                return
            }
            if needsPackageInitialization,
                !FileManager.default.fileExists(atPath: url.appending(path: "manifest.json").path)
            {
                await run(messageKey: "progress.creating-project") { [self] in
                    try await initializePackage(at: url, allowsEmptyPlaceholder: true)
                }
            } else {
                await openProject(at: url)
            }
        #endif
    }

    func openProject(at url: URL) async {
        _ = await openProject(at: url, documentAttachmentID: nil)
    }

    private func openProject(at url: URL, documentAttachmentID: UUID?) async -> Bool {
        await run(
            messageKey: "progress.opening-project", documentAttachmentID: documentAttachmentID
        ) { [self] in
            guard documentAttachmentIsCurrent(documentAttachmentID) else { return }
            let accessGranted = url.startAccessingSecurityScopedResource()
            do {
                let opened = try await service.openProject(at: url)
                try await activateSession(
                    opened, at: url, accessGranted: accessGranted,
                    documentAttachmentID: documentAttachmentID)
            } catch {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
                guard documentAttachmentIsCurrent(documentAttachmentID) else { return }
                throw error
            }
        }
    }

    #if os(macOS)
        private func waitForDocumentAttachmentIdle(_ requestID: UUID) async {
            while isBusy, documentAttachmentIsCurrent(requestID) {
                await withTaskCancellationHandler {
                    await withCheckedContinuation { continuation in
                        guard isBusy, documentAttachmentIsCurrent(requestID) else {
                            continuation.resume()
                            return
                        }
                        let superseded = documentAttachmentWaiter
                        documentAttachmentWaiter = StudioDocumentAttachmentWaiter(
                            requestID: requestID, continuation: continuation)
                        superseded?.continuation.resume()
                    }
                } onCancel: {
                    // Cancellation can arrive off actor; this bounded hop only releases its own wait.
                    Task { @MainActor in finishDocumentAttachment(requestID) }
                }
            }
        }

        private func finishDocumentAttachment(_ requestID: UUID) {
            if latestDocumentAttachmentID == requestID {
                latestDocumentAttachmentID = nil
            }
            if documentAttachmentWaiter?.requestID == requestID {
                let waiting = documentAttachmentWaiter
                documentAttachmentWaiter = nil
                waiting?.continuation.resume()
            }
        }
    #endif

    private func documentAttachmentIsCurrent(_ requestID: UUID?) -> Bool {
        #if os(macOS)
            guard let requestID else { return true }
            return !Task.isCancelled && latestDocumentAttachmentID == requestID
        #else
            return true
        #endif
    }

    #if os(macOS)
        /// Dispatches reopening through the native document action without replacing this session.
        func reopenLastProject(using opener: @escaping @MainActor (URL) async throws -> Void) async
        {
            await run(messageKey: "progress.opening-project") { [self] in
                let url = try resolvedLastProjectURL()
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    try await opener(url)
                } catch {
                    throw presentationFailure(messageKey: "failure.project.invalid-package")
                }
            }
        }
    #else
        func reopenLastProject() async {
            do {
                await openProject(at: try resolvedLastProjectURL())
            } catch {
                lastFailure = error
            }
        }
    #endif

    private func resolvedLastProjectURL() throws(GlifiStudioFailure) -> URL {
        guard let lastProjectBookmark else {
            throw presentationFailure(messageKey: "failure.project.none-open")
        }
        var isStale = false
        do {
            #if os(macOS)
                let resolutionOptions: URL.BookmarkResolutionOptions = [
                    .withoutUI, .withSecurityScope,
                ]
            #else
                let resolutionOptions: URL.BookmarkResolutionOptions = [.withoutUI]
            #endif
            return try URL(
                resolvingBookmarkData: lastProjectBookmark,
                options: resolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw presentationFailure(messageKey: "failure.project.invalid-package")
        }
    }

    func importSource(at url: URL) async {
        await importSources(at: [url])
    }

    func importSources(at urls: [URL]) async {
        await run(messageKey: "progress.importing") { [self] in
            let active = try requireSession()
            importProgressTotal = urls.count
            importProgressCompleted = 0
            defer {
                importProgressTotal = 0
                importProgressCompleted = 0
            }
            for url in urls {
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let format: GlifiStudioTextFormat =
                    GlifiStudioTextFormat(rawValue: url.pathExtension.lowercased())
                    ?? (["md", "markdown"].contains(url.pathExtension.lowercased())
                        ? .markdown : .plainText)
                let result = try await active.importText(at: url, format: format)
                snapshot = result.project
                lastProfile = result.profile
                lastImportedFileName = url.lastPathComponent
                importProgressCompleted += 1
            }
        }
    }

    func planInvestigation() async {
        await run(messageKey: "progress.planning") { [self] in
            let active = try requireSession()
            let request = makePlanRequest()
            let planned = try await active.planAnalysis(request)
            lastPlanRequest = request
            planResult = planned
            executionResult = nil
            executionProgress = nil
            visualizations = []
            selectedVisualMarkID = nil
            investigation = nil
            lastInvestigationProjectID = nil
            lastInvestigationGeneration = nil
            lastInvestigationCreationRequest = nil
            lastInvestigationSelectionRequest = nil
            exportReceipt = nil
            lastExportRequest = nil
            selectedFindingID = nil
        }
    }

    func executePlan() async {
        await run(messageKey: "progress.executing") { [self] in
            let active = try requireSession()
            let request = makePlanRequest()
            lastPlanRequest = request
            let execution = try await active.executeAnalysisPlan(request)
            activeExecution = execution
            defer {
                activeExecution = nil
                executionProgress = nil
            }
            for try await event in execution.events {
                switch event {
                case let .progress(progress):
                    executionProgress = progress
                case let .completed(result):
                    executionResult = result
                    executionProgress = nil
                    visualizations = try await active.visualizations(for: result)
                    selectedVisualMarkID = nil
                    snapshot = try await active.snapshot()
                    selectedFindingID = result.interpretation.findings.first?.id
                    editorialSelectedFindingIDs = Set(result.interpretation.findings.map(\.id))
                }
            }
        }
    }

    func cancelExecution() {
        activeExecution?.cancel()
    }

    func createInvestigationFromExecution() async {
        await run(messageKey: "progress.investigating") { [self] in
            let active = try requireSession()
            guard let executionResult else {
                throw presentationFailure(messageKey: "failure.investigation.missing-execution")
            }
            let selected =
                editorialSelectedFindingIDs.isEmpty
                ? nil
                : Array(editorialSelectedFindingIDs).sorted()
            let request = GlifiStudioInvestigationCreationRequest(
                question: questionDraft,
                languageCode: "it",
                interpretationArtifactID: executionResult.interpretationArtifactID,
                selectedFindingIDs: selected
            )
            let result = try await active.createInvestigation(request)
            lastInvestigationCreationRequest = request
            lastInvestigationSelectionRequest = nil
            lastInvestigationProjectID = result.projectID
            lastInvestigationGeneration = result.generation
            investigation = result.investigation
            editorialSelectedFindingIDs = Set(result.investigation.selectedFindingIDs)
            investigationHeads = try await active.investigationHeads()
            snapshot = try await active.snapshot()
        }
    }

    func selectInvestigationHead(_ head: GlifiStudioInvestigation) {
        investigation = head
        editorialSelectedFindingIDs = Set(head.selectedFindingIDs)
    }

    func refreshInvestigationHeads() async {
        await run(messageKey: "progress.investigating") { [self] in
            let active = try requireSession()
            investigationHeads = try await active.investigationHeads()
            if let current = investigation {
                investigation =
                    investigationHeads.first { $0.headEventID == current.headEventID }
                    ?? investigationHeads.first
            } else {
                investigation = investigationHeads.first
            }
            if let investigation {
                editorialSelectedFindingIDs = Set(investigation.selectedFindingIDs)
            }
        }
    }

    func reviseEditorialSelection() async {
        await run(messageKey: "progress.revising-selection") { [self] in
            let active = try requireSession()
            guard let investigation else {
                throw presentationFailure(messageKey: "failure.export.missing-investigation")
            }
            let request = GlifiStudioInvestigationSelectionRequest(
                investigationID: investigation.id,
                predecessorEventID: investigation.headEventID,
                selectedFindingIDs: Array(editorialSelectedFindingIDs).sorted(),
                reasonIdentifier: "editorial.focus"
            )
            let result = try await active.reviseInvestigationSelection(request)
            lastInvestigationSelectionRequest = request
            lastInvestigationProjectID = result.projectID
            lastInvestigationGeneration = result.generation
            self.investigation = result.investigation
            editorialSelectedFindingIDs = Set(result.investigation.selectedFindingIDs)
            investigationHeads = try await active.investigationHeads()
            snapshot = try await active.snapshot()
        }
    }

    func runQuery() async {
        await run(messageKey: "progress.querying") { [self] in
            let active = try requireSession()
            let trimmed = queryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw presentationFailure(messageKey: "failure.query.empty")
            }
            let result = try await active.query(trimmed)
            queryResult = result
            lastQueryExpression = trimmed
            selectedQueryMatchID = result.matches.first?.id
            sourceText = nil
            if let match = result.matches.first {
                sourceText = try await active.sourceText(sourceRevisionID: match.sourceRevisionID)
            }
        }
    }

    func selectQueryMatch(_ match: GlifiStudioQueryMatch) async {
        #if os(macOS)
            await run(messageKey: "progress.loading-source") { [self] in
                let active = try requireSession()
                let source = try await active.sourceText(sourceRevisionID: match.sourceRevisionID)
                selectedQueryMatchID = match.id
                sourceText = source
            }
        #else
            selectedQueryMatchID = match.id
            await run(messageKey: "progress.loading-source") { [self] in
                let active = try requireSession()
                sourceText = try await active.sourceText(sourceRevisionID: match.sourceRevisionID)
            }
        #endif
    }

    func browseSource(_ sourceRevisionID: String) async {
        await run(messageKey: "progress.loading-source") { [self] in
            browsedSourceText = try await requireSession().sourceText(
                sourceRevisionID: sourceRevisionID)
        }
    }

    func openEvidenceSource(_ evidence: GlifiStudioEvidence) async {
        await run(messageKey: "progress.loading-source") { [self] in
            let active = try requireSession()
            guard let reference = evidence.sourceReferences.first else {
                throw presentationFailure(messageKey: "failure.evidence.missing-source")
            }
            evidenceSourceText = try await active.sourceText(
                sourceRevisionID: reference.sourceRevisionID
            )
            evidenceSourceRanges = reference.ranges
            focusedEvidenceID = evidence.id
        }
    }

    /// Views whose source Artifact supports the Evidence of `finding`.
    func visualizations(for finding: GlifiStudioFinding) -> [GlifiStudioVisualization] {
        let evidenceIDs = Set(finding.evidenceReferences.map(\.evidenceID))
        let artifactIDs = Set(
            (executionResult?.interpretation.evidence ?? [])
                .filter { evidenceIDs.contains($0.id) }
                .flatMap(\.artifactIDs)
        )
        return visualizations.filter { artifactIDs.contains($0.artifactID) }
    }

    /// Selects one datum of a view and opens its first reachable source.
    func selectVisualMark(_ mark: GlifiStudioVisualMark) async {
        #if os(macOS)
            await run(messageKey: "progress.loading-source") { [self] in
                guard let sourceRevisionID = mark.sourceRevisionIDs.first else {
                    selectedVisualMarkID = mark.id
                    clearEvidenceSource()
                    return
                }
                let active = try requireSession()
                let source = try await active.sourceText(sourceRevisionID: sourceRevisionID)
                selectedVisualMarkID = mark.id
                evidenceSourceText = source
                // Contributive lineage reaches the document without claiming exact positions.
                evidenceSourceRanges = []
                focusedEvidenceID = nil
            }
        #else
            selectedVisualMarkID = mark.id
            guard let sourceRevisionID = mark.sourceRevisionIDs.first else {
                return
            }
            await run(messageKey: "progress.loading-source") { [self] in
                let active = try requireSession()
                evidenceSourceText = try await active.sourceText(sourceRevisionID: sourceRevisionID)
                // Il lineage contributivo raggiunge il documento, non posizioni esatte.
                evidenceSourceRanges = []
                focusedEvidenceID = nil
            }
        #endif
    }

    // MARK: - Codifica qualitativa (GS-UX-001-16)

    /// Latest revision of the working codebook, empty when none exists.
    var activeCodebook:
        (codebookID: String, revision: Int, categories: [GlifiStudioCodebookCategory])?
    {
        guard let codebooks = qualitativeState?.codebooks,
            let codebook = codebooks.first(where: { $0.codebookID == selectedCodebookID })
                ?? codebooks.first,
            let categories = codebook.revisions.last
        else {
            return nil
        }
        return (codebook.codebookID, codebook.revisions.count, categories)
    }

    /// Distinct coders with at least one coding.
    var knownCoders: [String] {
        Array(Set(qualitativeState?.codings.map(\.coderID) ?? [])).sorted()
    }

    func loadQualitativeState() async {
        await run(messageKey: "progress.loading-coding") { [self] in
            let active = try requireSession()
            qualitativeState = try await active.qualitativeState()
            try await refreshCodingTexts(active)
        }
    }

    func loadCodingSource(_ sourceRevisionID: String) async {
        await run(messageKey: "progress.loading-source") { [self] in
            let active = try requireSession()
            codingPassage = nil
            codingSegments = try await active.textSegments(sourceRevisionID: sourceRevisionID)
            codingSourceCharacterCount = try await active.extractedCharacterCount(
                sourceRevisionID: sourceRevisionID)
            codingSourceRevisionID = sourceRevisionID
            qualitativeState = try await active.qualitativeState()
            try await refreshCodingTexts(active)
        }
    }

    /// Resolves a structured passage selection and keeps it as the passage to code.
    func resolvePassage(_ selection: GlifiStudioPassageSelection) async {
        guard let sourceRevisionID = codingSourceRevisionID else { return }
        await run(messageKey: "progress.loading-source") { [self] in
            let active = try requireSession()
            codingPassage = nil
            codingPassage = try await active.passage(
                sourceRevisionID: sourceRevisionID, selection: selection)
        }
    }

    /// Registers the next codebook revision with the given categories.
    func registerCodebookRevision(_ categories: [GlifiStudioCodebookCategory]) async {
        let codebookID = activeCodebook?.codebookID ?? "temi"
        await registerCodebookRevision(categories, codebookID: codebookID)
    }

    /// Appends a full revision without replacing earlier category definitions.
    func registerCodebookRevision(_ categories: [GlifiStudioCodebookCategory], codebookID: String)
        async
    {
        let revision =
            (qualitativeState?.codebooks.first { $0.codebookID == codebookID }?.revisions.count ?? 0)
            + 1
        await appendQualitative(
            .codebookRevised(codebookID: codebookID, revision: revision, categories: categories))
        if lastFailure == nil {
            selectedCodebookID = codebookID
            storedAgreement = nil
        }
    }

    /// Records an explicit category relationship between two retained revisions.
    func mapCategories(
        codebookID: String, fromRevision: Int, toRevision: Int, mapping: GlifiStudioCategoryMapping
    ) async {
        await appendQualitative(
            .categoryMapped(
                codebookID: codebookID, fromRevision: fromRevision, toRevision: toRevision,
                mappings: [mapping]))
    }

    /// Attaches a memo to a source, category or coding through the same event history.
    func attachNote(to target: GlifiStudioMemoTarget, text: String) async {
        await appendQualitative(.memoAttached(target: target, coderID: coderDraft, text: text))
    }

    /// Records the resolved passage under one category.
    func codeResolvedPassage(categoryID: String) async {
        guard let passage = codingPassage else { return }
        await code(passage, categoryID: categoryID)
    }

    func code(_ segment: GlifiStudioTextSegment, categoryID: String) async {
        guard let codebook = activeCodebook, let sourceRevisionID = codingSourceRevisionID else {
            return
        }
        await appendQualitative(
            .segmentCoded(
                sourceRevisionID: sourceRevisionID, startUTF8: segment.startUTF8,
                endUTF8: segment.endUTF8, codebookID: codebook.codebookID,
                codebookRevision: codebook.revision, categoryID: categoryID,
                coderID: coderDraft, origin: "manual"))
    }

    func retractCoding(_ eventID: String, reason: String) async {
        await appendQualitative(.codingRetracted(codingEventID: eventID, reasonIdentifier: reason))
    }

    func attachNote(to eventID: String, text: String) async {
        await appendQualitative(
            .memoAttached(target: .coding(eventID: eventID), coderID: coderDraft, text: text))
    }

    func assessAgreement(coders: [String], revision: Int? = nil) async {
        guard let codebook = activeCodebook else { return }
        let requestedRevision = revision ?? codebook.revision
        await run(messageKey: "progress.assessing-agreement") { [self] in
            let active = try requireSession()
            let result = try await active.assessStoredCodingAgreement(
                codebookID: codebook.codebookID, codebookRevision: requestedRevision,
                coderIDs: coders)
            let updatedSnapshot = try await active.snapshot()
            storedAgreement = result
            storedAgreementCodebookID = codebook.codebookID
            storedAgreementRevision = requestedRevision
            snapshot = updatedSnapshot
        }
    }

    private func appendQualitative(_ change: GlifiStudioQualitativeChange) async {
        await run(messageKey: "progress.recording-coding") { [self] in
            let active = try requireSession()
            do {
                qualitativeState = try await active.appendQualitativeChange(change)
            } catch let failure as GlifiStudioFailure
                where failure.code == "qualitative.stale-history"
            {
                // Storia cambiata nel frattempo: si ricarica lo stato e si segnala la ripetizione.
                qualitativeState = try await active.qualitativeState()
                try await refreshCodingTexts(active)
                throw failure
            }
            try await refreshCodingTexts(active)
        }
    }

    /// Resolves the passage of every coding of the loaded source, for the review list.
    private func refreshCodingTexts(_ active: GlifiStudioProjectSession) async throws {
        guard let sourceRevisionID = codingSourceRevisionID else {
            codingTexts = [:]
            return
        }
        let codings = (qualitativeState?.codings ?? []).filter {
            $0.sourceRevisionID == sourceRevisionID
        }
        guard !codings.isEmpty else {
            codingTexts = [:]
            return
        }
        let resolved = try await active.passages(
            sourceRevisionID: sourceRevisionID,
            selections: codings.map { .bytes(start: $0.startUTF8, end: $0.endUTF8) })
        codingTexts = Dictionary(
            zip(codings.map(\.eventID), resolved.map(\.text)), uniquingKeysWith: { _, last in last }
        )
    }

    func clearEvidenceSource() {
        evidenceSourceText = nil
        evidenceSourceRanges = []
        focusedEvidenceID = nil
    }

    #if os(macOS)
        func toggleTextAnalysisSource(_ sourceRevisionID: String) {
            if selectedTextAnalysisSourceRevisionIDs.contains(sourceRevisionID) {
                selectedTextAnalysisSourceRevisionIDs.remove(sourceRevisionID)
            } else {
                selectedTextAnalysisSourceRevisionIDs.insert(sourceRevisionID)
            }
        }

        func summarizeSources() async {
            await runAnalysis(messageKey: "progress.summarizing") { [self] in
                let active = try requireSession()
                let sourceRevisionIDs = scopedTextAnalysisSourceRevisionIDs()
                let lambda: Double?
                switch summaryRedundancy {
                case .none: lambda = nil
                case .maximalMarginalRelevance: lambda = summaryMMRLambda
                }
                let graphConfiguration: GlifiStudioSummaryGraphConfiguration? =
                    summaryMethod.supportsGraphConfiguration
                    ? GlifiStudioSummaryGraphConfiguration(
                        damping: summaryGraphDamping, tolerance: summaryGraphTolerance,
                        maximumIterations: summaryGraphMaximumIterations,
                        similarityThreshold: summaryGraphSimilarityThreshold)
                    : nil
                let options = StudioSummaryOptions(
                    scope: textAnalysisScope, sourceRevisionIDs: sourceRevisionIDs,
                    method: summaryMethod, budgetUnit: summaryBudgetUnit,
                    budgetLimit: summaryBudgetLimit, redundancy: summaryRedundancy,
                    mmrLambda: lambda, graphConfiguration: graphConfiguration,
                    scheme: .summaryStandard, corpusOptions: .standard)
                let result = try await active.analyzeExtractiveSummary(
                    sourceRevisionIDs: options.sourceRevisionIDs,
                    budget: GlifiStudioSummaryBudget(
                        unit: options.budgetUnit.rawValue, limit: options.budgetLimit),
                    scheme: options.scheme,
                    method: GlifiStudioSummaryScoringMethod(identifier: options.method.rawValue),
                    redundancy: GlifiStudioSummaryRedundancy(
                        identifier: options.redundancy.rawValue, lambda: options.mmrLambda),
                    graphConfiguration: options.graphConfiguration,
                    corpusOptions: options.corpusOptions)
                let updatedSnapshot = try await active.snapshot()
                lastExtractiveSummary = result
                lastSummaryOptions = options
                snapshot = updatedSnapshot
                clearSummarySource()
            }
        }

        func openSummarySource(_ selected: GlifiStudioSelectedSentence) async {
            await run(messageKey: "progress.loading-source") { [self] in
                let active = try requireSession()
                let source = try await active.sourceText(
                    sourceRevisionID: selected.sentence.sourceRevisionID)
                summarySourceText = source
                summarySourceRanges = selected.sourceRanges
                focusedSummarySentenceID =
                    "\(selected.sentence.sourceRevisionID):\(selected.sentence.sentenceIndex)"
            }
        }

        func clearSummarySource() {
            summarySourceText = nil
            summarySourceRanges = []
            focusedSummarySentenceID = nil
        }

        func rankSourcesBM25() async {
            await runAnalysis(messageKey: "progress.ranking-bm25") { [self] in
                let active = try requireSession()
                let options = StudioBM25Options(
                    scope: textAnalysisScope,
                    sourceRevisionIDs: scopedTextAnalysisSourceRevisionIDs(),
                    query: bm25QueryDraft, k1: bm25K1, b: bm25B, corpusOptions: .standard)
                let result = try await active.rankDocumentsBM25(
                    sourceRevisionIDs: options.sourceRevisionIDs,
                    query: options.query, k1: options.k1, b: options.b,
                    corpusOptions: options.corpusOptions)
                let updatedSnapshot = try await active.snapshot()
                lastBM25Ranking = result
                lastBM25Options = options
                snapshot = updatedSnapshot
                clearBM25Source()
            }
        }

        func openBM25Source(_ document: GlifiStudioBM25RankedDocument) async {
            await run(messageKey: "progress.loading-source") { [self] in
                bm25SourceText = try await requireSession().sourceText(
                    sourceRevisionID: document.sourceRevisionID)
            }
        }

        func clearBM25Source() {
            bm25SourceText = nil
        }

        func analyzeFrequencies() async {
            await runAnalysis(messageKey: "progress.analyzing-frequencies") { [self] in
                let active = try requireSession()
                let size: Int
                let minimumLength: Int
                switch frequencyUnit {
                case .forms:
                    size = 1
                    minimumLength = frequencyMinimumLength
                case .words, .characters, .paddedCharacters:
                    size = frequencyN
                    minimumLength = 1
                }
                let stopwords = frequencyStopwordsDraft.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let options = StudioFrequencyOptions(
                    scope: textAnalysisScope,
                    sourceRevisionIDs: scopedTextAnalysisSourceRevisionIDs(),
                    unit: GlifiStudioNGramUnit(kind: frequencyUnit.rawValue, n: size),
                    filter: GlifiStudioTermFilter(
                        stopwords: stopwords, minimumLength: minimumLength,
                        minimumCount: frequencyMinimumCount,
                        minimumDocumentFrequency: frequencyMinimumDocumentFrequency,
                        maximumDocumentProportion: frequencyMaximumDocumentProportion),
                    maximumRowCount: frequencyMaximumRowCount, corpusOptions: .standard)
                let result = try await active.analyzeNGramFrequencies(
                    sourceRevisionIDs: options.sourceRevisionIDs,
                    unit: options.unit, filter: options.filter,
                    maximumRowCount: options.maximumRowCount, corpusOptions: options.corpusOptions)
                let updatedSnapshot = try await active.snapshot()
                lastNGramFrequencies = result
                lastFrequencyOptions = options
                snapshot = updatedSnapshot
                frequencyPage = 0
            }
        }

        var frequencyPageCount: Int {
            let count = lastNGramFrequencies?.rows.count ?? 0
            return (count + frequencyPageSize - 1) / frequencyPageSize
        }

        var frequencyRowsOnPage: [GlifiStudioNGramFrequencyRow] {
            guard let result = lastNGramFrequencies else { return [] }
            return Array(
                result.rows.dropFirst(frequencyPage * frequencyPageSize).prefix(frequencyPageSize))
        }

        func showFrequencyPage(_ page: Int) {
            guard page >= 0, page < frequencyPageCount else { return }
            frequencyPage = page
        }

        func analyzeMTLD() async {
            await runAnalysis(messageKey: "progress.analyzing-mtld") { [self] in
                let active = try requireSession()
                let options = StudioMTLDOptions(
                    scope: textAnalysisScope,
                    sourceRevisionIDs: scopedTextAnalysisSourceRevisionIDs(),
                    threshold: mtldThreshold, corpusOptions: .standard)
                let result = try await active.analyzeLexicalDiversity(
                    sourceRevisionIDs: options.sourceRevisionIDs,
                    threshold: options.threshold, corpusOptions: options.corpusOptions)
                let updatedSnapshot = try await active.snapshot()
                lastLexicalDiversity = result
                lastMTLDOptions = options
                snapshot = updatedSnapshot
            }
        }

        func analyzeLexicalLaws(parameters: GlifiStudioLexicalLawsParameters = .standard) async {
            await runAnalysis(messageKey: "progress.analyzing-lexical-laws") { [self] in
                let active = try requireSession()
                let result = try await active.analyzeLexicalLaws(
                    sourceRevisionIDs: scopedTextAnalysisSourceRevisionIDs(),
                    parameters: parameters, corpusOptions: .standard)
                let updatedSnapshot = try await active.snapshot()
                lastLexicalLaws = result
                snapshot = updatedSnapshot
            }
        }

        /// Shares operation ownership, cancellation and error presentation with direct analyses.
        func runAdvancedAnalysis(
            _ operation: @escaping @MainActor (GlifiStudioProjectSession) async throws -> Void
        ) async {
            await runAnalysis(messageKey: "advanced.progress") { [self] in
                try await operation(requireSession())
            }
        }

        /// Owns a session-independent analytical task with the same cancellation contract.
        func runCoreAnalysis(
            _ operation: @escaping @MainActor () async throws -> Void
        ) async {
            await runAnalysis(messageKey: "core-features.progress", operation: operation)
        }

        /// Publishes the refreshed project only after the operation has validated its output.
        func runCorpusAnalysis(
            _ operation:
                @escaping @MainActor (GlifiStudioProjectSession) async throws
                -> GlifiStudioProjectSnapshot
        ) async {
            await runAnalysis(messageKey: "core-features.progress") { [self] in
                snapshot = try await operation(requireSession())
            }
        }

        func analyzeTermWeights() async {
            await runAnalysis(messageKey: "progress.analyzing-term-weighting") { [self] in
                let active = try requireSession()
                let options = StudioTermWeightingOptions(
                    scope: textAnalysisScope,
                    sourceRevisionIDs: scopedTextAnalysisSourceRevisionIDs(),
                    scheme: GlifiStudioTermWeightingScheme(
                        termFrequency: termFrequencyVariant.rawValue,
                        inverseDocumentFrequency: inverseDocumentFrequencyVariant.rawValue,
                        normalization: termWeightingNormalization.rawValue),
                    corpusOptions: .standard)
                let result = try await active.analyzeTermWeighting(
                    sourceRevisionIDs: options.sourceRevisionIDs, scheme: options.scheme,
                    corpusOptions: options.corpusOptions)
                let updatedSnapshot = try await active.snapshot()
                let observedCounts = try await Self.observedTermWeightingCellCounts(
                    for: result, options: options)
                lastTermWeighting = result
                lastTermWeightingOptions = options
                termWeightingObservedCellCounts = observedCounts
                snapshot = updatedSnapshot
                termWeightingCellPage = 0
                termWeightingTermPage = 0
            }
        }

        @concurrent
        nonisolated static func observedTermWeightingCellCounts(
            for result: GlifiStudioTermWeightingResult, options: StudioTermWeightingOptions
        ) async throws(GlifiStudioFailure) -> [Int] {
            let invalidResult = GlifiStudioFailure(
                code: "ui.weighting.invalid-result", category: "corruption", operation: "analyze",
                retryDisposition: "never", retainedState: "lastCommittedGeneration",
                messageKey: "failure.weighting.invalid-result")
            let ids = result.sourceRevisionIDs
            let limits = options.corpusOptions
            guard !ids.isEmpty, ids.count <= limits.maximumDocumentCount,
                ids == options.sourceRevisionIDs, ids == ids.sorted(),
                ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count,
                result.scheme == options.scheme,
                result.terms.count <= limits.maximumVocabularySize,
                result.documentFrequencies.count == result.terms.count,
                result.cells.count <= limits.maximumNonZeroCellCount
            else { throw invalidResult }
            for index in result.terms.indices {
                guard !result.terms[index].isEmpty,
                    index == 0 || result.terms[index - 1] < result.terms[index],
                    result.documentFrequencies[index] >= 1,
                    result.documentFrequencies[index] <= ids.count
                else { throw invalidResult }
            }
            var counts = [Int](repeating: 0, count: ids.count)
            var observedDocumentFrequencies = [Int](repeating: 0, count: result.terms.count)
            var previousRow = -1
            var previousColumn = -1
            for cell in result.cells {
                guard cell.rowIndex >= 0, cell.rowIndex < ids.count,
                    cell.columnIndex >= 0, cell.columnIndex < result.terms.count,
                    cell.count > 0, cell.weight.isFinite, cell.weight >= 0,
                    cell.rowIndex > previousRow
                        || (cell.rowIndex == previousRow && cell.columnIndex > previousColumn)
                else { throw invalidResult }
                counts[cell.rowIndex] += 1
                observedDocumentFrequencies[cell.columnIndex] += 1
                previousRow = cell.rowIndex
                previousColumn = cell.columnIndex
            }
            guard observedDocumentFrequencies == result.documentFrequencies else {
                throw invalidResult
            }
            return counts
        }

        var termWeightingCellPageCount: Int {
            let count = lastTermWeighting?.cells.count ?? 0
            return (count + termWeightingCellPageSize - 1) / termWeightingCellPageSize
        }

        var termWeightingTermPageCount: Int {
            let count = lastTermWeighting?.terms.count ?? 0
            return (count + termWeightingTermPageSize - 1) / termWeightingTermPageSize
        }

        var cellsOnTermWeightingPage: [GlifiStudioWeightedTermCell] {
            guard let result = lastTermWeighting else { return [] }
            return Array(
                result.cells.dropFirst(termWeightingCellPage * termWeightingCellPageSize)
                    .prefix(termWeightingCellPageSize))
        }

        var termIndicesOnWeightingPage: [Int] {
            guard let result = lastTermWeighting else { return [] }
            let start = termWeightingTermPage * termWeightingTermPageSize
            let end = min(result.terms.count, start + termWeightingTermPageSize)
            guard start < end else { return [] }
            return Array(start..<end)
        }

        func showTermWeightingCellPage(_ page: Int) {
            guard page >= 0, page < termWeightingCellPageCount else { return }
            termWeightingCellPage = page
        }

        func showTermWeightingTermPage(_ page: Int) {
            guard page >= 0, page < termWeightingTermPageCount else { return }
            termWeightingTermPage = page
        }

        private func scopedTextAnalysisSourceRevisionIDs() -> [String] {
            switch textAnalysisScope {
            case .allSources: (snapshot?.sources.map(\.sourceRevisionID) ?? []).sorted()
            case .selectedSources: selectedTextAnalysisSourceRevisionIDs.sorted()
            }
        }
    #endif

    func analyzeCorpusNow() async {
        await runAnalysis(messageKey: "progress.analyzing-corpus") { [self] in
            let active = try requireSession()
            let options = GlifiStudioCorpusAnalysisOptions.standard
            let result = try await active.analyzeCorpus(options: options)
            snapshot = try await active.snapshot()
            lastCorpusAnalysis = result
            lastCorpusOptions = options
            lastProfile = nil
        }
    }

    func compareKeynessNow() async {
        await runAnalysis(messageKey: "progress.comparing-keyness") { [self] in
            let active = try requireSession()
            let target = Array(selectedTargetRevisionIDs).sorted()
            let reference = Array(selectedReferenceRevisionIDs).sorted()
            guard !target.isEmpty, !reference.isEmpty else {
                throw presentationFailure(messageKey: "failure.keyness.missing-groups")
            }
            let overlap = Set(target).intersection(reference)
            guard overlap.isEmpty else {
                throw presentationFailure(messageKey: "failure.keyness.overlapping-groups")
            }
            let corpusOptions = GlifiStudioCorpusAnalysisOptions.standard
            #if os(macOS)
                let keynessOptions = try GlifiStudioKeynessOptions(
                    maximumHypothesisCount: keynessMaximumHypothesisCount,
                    lowExpectedCountThreshold: keynessLowExpectedCountThreshold,
                    confidenceLevel: keynessConfidenceLevel)
                let request = StudioKeynessRequestOptions(
                    targetSourceRevisionIDs: target, referenceSourceRevisionIDs: reference,
                    corpusOptions: corpusOptions, keynessOptions: keynessOptions)
            #else
                let keynessOptions = GlifiStudioKeynessOptions.standard
            #endif
            let result = try await active.compareKeyness(
                targetSourceRevisionIDs: target,
                referenceSourceRevisionIDs: reference,
                corpusOptions: corpusOptions,
                keynessOptions: keynessOptions
            )
            let updatedSnapshot = try await active.snapshot()
            #if os(macOS)
                try await Self.validateKeynessPresentation(result, options: request)
            #endif
            snapshot = updatedSnapshot
            lastKeyness = result
            lastKeynessOptions = keynessOptions
            lastCorpusOptions = corpusOptions
            #if os(macOS)
                lastKeynessRequestOptions = request
                keynessPage = 0
            #endif
        }
    }

    #if os(macOS)
        var keynessPageCount: Int {
            let count = lastKeyness?.terms.count ?? 0
            return (count + keynessPageSize - 1) / keynessPageSize
        }

        var keynessTermsOnPage: [GlifiStudioKeynessTerm] {
            guard let result = lastKeyness else { return [] }
            return Array(
                result.terms.dropFirst(keynessPage * keynessPageSize).prefix(keynessPageSize))
        }

        func showKeynessPage(_ page: Int) {
            guard page >= 0, page < keynessPageCount else { return }
            keynessPage = page
        }

        @concurrent
        nonisolated static func validateKeynessPresentation(
            _ result: GlifiStudioKeynessResult, options: StudioKeynessRequestOptions
        ) async throws(GlifiStudioFailure) {
            let invalidResult = GlifiStudioFailure(
                code: "ui.keyness.invalid-result", category: "corruption", operation: "analyze",
                retryDisposition: "never", retainedState: "lastCommittedGeneration",
                messageKey: "failure.keyness.invalid-result")
            let target = result.targetSourceRevisionIDs
            let reference = result.referenceSourceRevisionIDs
            let targetSet = Set(target)
            let referenceSet = Set(reference)
            let limits = options.corpusOptions
            guard !target.isEmpty, !reference.isEmpty,
                target == options.targetSourceRevisionIDs,
                reference == options.referenceSourceRevisionIDs,
                target == target.sorted(), reference == reference.sorted(),
                target.allSatisfy({ !$0.isEmpty }), reference.allSatisfy({ !$0.isEmpty }),
                targetSet.count == target.count, referenceSet.count == reference.count,
                targetSet.isDisjoint(with: referenceSet),
                target.count <= limits.maximumDocumentCount,
                reference.count <= limits.maximumDocumentCount,
                result.confidenceLevel == options.keynessOptions.confidenceLevel,
                result.confidenceLevel.isFinite,
                result.confidenceLevel > 0, result.confidenceLevel < 1,
                result.lowExpectedCountThreshold
                    == options.keynessOptions.lowExpectedCountThreshold,
                result.lowExpectedCountThreshold.isFinite, result.lowExpectedCountThreshold >= 0,
                result.targetTokenCount > 0, result.referenceTokenCount > 0,
                !result.terms.isEmpty,
                result.terms.count <= options.keynessOptions.maximumHypothesisCount,
                result.comparisonIdentifier == "keyness-gtest-fisher-ha-ci-bh-v2",
                result.testIdentifier == "GTest-v1",
                result.testSelectionIdentifier == "FisherSelection-min-expected-5-v1",
                result.exactTestIdentifier == "FisherExactTwoSided-v1",
                result.correctionIdentifier == "BenjaminiHochberg-v1",
                result.logRatioIntervalIdentifier == "LogRatioCI-Katz-HA-v1",
                result.oddsRatioIntervalIdentifier == "OddsRatioCI-Woolf-HA-v1",
                result.pValueIdentifier == "ChiSquareSurvival-df1-erfc-v1",
                result.oddsRatioIdentifier == "OddsRatio-HA-v1",
                result.logRatioIdentifier == "LogRatio-HA-v1-base2",
                result.diagnosticIdentifier == "asymptotic-minimum-expected-count-v1",
                result.floatingPointDeterminismClass == "D1",
                result.numericPolicyIdentifier == "IEEE-754-binary64-ordered-reduction-v1",
                result.referenceAbsoluteTolerance == 1e-12,
                result.orderingIdentifier == "absolute-log-ratio-descending-term-ascending-v1"
            else { throw invalidResult }
            var terms = Set<String>()
            terms.reserveCapacity(result.terms.count)
            var targetTotal = 0
            var referenceTotal = 0
            var targetTypeCount = 0
            var referenceTypeCount = 0
            var previousMagnitude: Double?
            var previousTerm = ""
            for row in result.terms {
                guard !row.term.isEmpty, terms.insert(row.term).inserted,
                    row.targetFrequency >= 0, row.targetFrequency <= result.targetTokenCount,
                    row.referenceFrequency >= 0,
                    row.referenceFrequency <= result.referenceTokenCount,
                    row.targetFrequency > 0 || row.referenceFrequency > 0,
                    row.targetRelativeFrequency.isFinite,
                    row.targetRelativeFrequency >= 0, row.targetRelativeFrequency <= 1,
                    row.referenceRelativeFrequency.isFinite,
                    row.referenceRelativeFrequency >= 0, row.referenceRelativeFrequency <= 1,
                    row.pValue.isFinite, row.pValue >= 0, row.pValue <= 1,
                    row.gTestPValue.isFinite, row.gTestPValue >= 0, row.gTestPValue <= 1,
                    row.qValue.isFinite, row.qValue >= 0, row.qValue <= 1,
                    row.gStatistic.isFinite, row.gStatistic >= 0, row.degreesOfFreedom == 1,
                    row.minimumExpectedCount.isFinite, row.minimumExpectedCount > 0,
                    row.log2RatioHaldaneAnscombe.isFinite,
                    row.log2RatioLower.isFinite, row.log2RatioUpper.isFinite,
                    row.log2RatioLower <= row.log2RatioUpper,
                    row.oddsRatioHaldaneAnscombe.isFinite, row.oddsRatioHaldaneAnscombe > 0,
                    row.oddsRatioLower.isFinite, row.oddsRatioLower > 0,
                    row.oddsRatioUpper.isFinite, row.oddsRatioUpper > 0,
                    row.oddsRatioLower <= row.oddsRatioUpper,
                    row.direction == "target" || row.direction == "reference"
                        || row.direction == "equal",
                    row.selectedTestIdentifier == "GTest-v1"
                        || row.selectedTestIdentifier == "FisherExactTwoSided-v1",
                    keynessIntervalContains(
                        row.log2RatioHaldaneAnscombe,
                        lower: row.log2RatioLower, upper: row.log2RatioUpper),
                    keynessIntervalContains(
                        row.oddsRatioHaldaneAnscombe,
                        lower: row.oddsRatioLower, upper: row.oddsRatioUpper)
                else { throw invalidResult }
                let magnitude = abs(row.log2RatioHaldaneAnscombe)
                if let previousMagnitude {
                    guard
                        magnitude < previousMagnitude
                            || (magnitude == previousMagnitude && previousTerm < row.term)
                    else { throw invalidResult }
                }
                previousMagnitude = magnitude
                previousTerm = row.term
                let nextTarget = targetTotal.addingReportingOverflow(row.targetFrequency)
                let nextReference = referenceTotal.addingReportingOverflow(row.referenceFrequency)
                guard !nextTarget.overflow, !nextReference.overflow,
                    nextTarget.partialValue <= result.targetTokenCount,
                    nextReference.partialValue <= result.referenceTokenCount
                else { throw invalidResult }
                targetTotal = nextTarget.partialValue
                referenceTotal = nextReference.partialValue
                if row.targetFrequency > 0 { targetTypeCount += 1 }
                if row.referenceFrequency > 0 { referenceTypeCount += 1 }
                guard targetTypeCount <= limits.maximumVocabularySize,
                    referenceTypeCount <= limits.maximumVocabularySize
                else { throw invalidResult }
            }
            guard targetTotal == result.targetTokenCount,
                referenceTotal == result.referenceTokenCount
            else { throw invalidResult }
        }

        nonisolated private static func keynessIntervalContains(
            _ point: Double, lower: Double, upper: Double
        ) -> Bool {
            // A distant opposite endpoint must not enlarge the rounding allowance of this side.
            let lowerTolerance = max(1e-12, 8 * max(point.ulp, lower.ulp))
            let upperTolerance = max(1e-12, 8 * max(point.ulp, upper.ulp))
            return (point >= lower || lower - point <= lowerTolerance)
                && (point <= upper || point - upper <= upperTolerance)
        }
    #endif

    func exportInvestigation(to destinationDirectory: URL) async {
        await run(messageKey: "progress.exporting") { [self] in
            let active = try requireSession()
            guard let investigation else {
                throw presentationFailure(messageKey: "failure.export.missing-investigation")
            }
            let accessGranted = destinationDirectory.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    destinationDirectory.stopAccessingSecurityScopedResource()
                }
            }
            let request = GlifiStudioScientificExportRequest(
                investigationHeadEventID: investigation.headEventID,
                formats: ["json", "markdown", "csv", "pdf"]
            )
            lastExportRequest = request
            exportReceipt = try await active.exportInvestigation(
                request,
                to: destinationDirectory
            )
            snapshot = try await active.snapshot()
            let markdownURL = destinationDirectory.appending(path: "report.md")
            #if os(macOS)
                exportPreviewMarkdown = await Self.loadExportPreview(at: markdownURL)
            #else
                if let data = try? Data(contentsOf: markdownURL),
                    let text = String(data: data, encoding: .utf8)
                {
                    exportPreviewMarkdown = text
                } else {
                    exportPreviewMarkdown = nil
                }
            #endif
        }
    }

    #if os(macOS)
        /// Loads an optional, complete UTF-8 preview with a one-MiB input budget.
        @concurrent
        nonisolated static func loadExportPreview(at url: URL) async -> String? {
            guard url.isFileURL, !Task.isCancelled else { return nil }
            // Foundation keeps the NUL-terminated path alive until the synchronous open returns.
            let descriptor = url.withUnsafeFileSystemRepresentation { fileSystemPath in
                guard let fileSystemPath else { return Int32(-1) }
                return Darwin.open(fileSystemPath, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            }
            guard descriptor >= 0 else { return nil }
            defer { _ = Darwin.close(descriptor) }
            let maximumByteCount = 1_048_576
            var initial = stat()
            guard fstat(descriptor, &initial) == 0,
                initial.st_mode & S_IFMT == S_IFREG,
                initial.st_size >= 0, initial.st_size <= off_t(maximumByteCount)
            else { return nil }
            var data = Data()
            data.reserveCapacity(Int(initial.st_size))
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while true {
                guard !Task.isCancelled else { return nil }
                let capacity = min(buffer.count, maximumByteCount + 1 - data.count)
                // The bounded buffer remains alive and writable for this synchronous POSIX read.
                let count = buffer.withUnsafeMutableBytes { bytes in
                    Darwin.read(descriptor, bytes.baseAddress, capacity)
                }
                if count < 0 {
                    if errno == EINTR { continue }
                    return nil
                }
                if count == 0 { break }
                data.append(contentsOf: buffer.prefix(count))
                guard data.count <= maximumByteCount else { return nil }
            }
            var final = stat()
            guard !Task.isCancelled, fstat(descriptor, &final) == 0,
                final.st_mode & S_IFMT == S_IFREG,
                final.st_size == initial.st_size, data.count == Int(initial.st_size)
            else { return nil }
            let text = String(validating: data, as: UTF8.self)
            return Task.isCancelled ? nil : text
        }
    #endif

    func reportOpenFailure() {
        lastFailure = presentationFailure(messageKey: "failure.project.invalid-package")
    }

    func selectFinding(id: String) {
        selectedFindingID = id
        clearEvidenceSource()
    }

    func toggleEditorialSelection(id: String) {
        if editorialSelectedFindingIDs.contains(id) {
            editorialSelectedFindingIDs.remove(id)
        } else {
            editorialSelectedFindingIDs.insert(id)
        }
    }

    func toggleTarget(_ revisionID: String) {
        if selectedTargetRevisionIDs.contains(revisionID) {
            selectedTargetRevisionIDs.remove(revisionID)
        } else {
            selectedTargetRevisionIDs.insert(revisionID)
            selectedReferenceRevisionIDs.remove(revisionID)
        }
    }

    func toggleReference(_ revisionID: String) {
        if selectedReferenceRevisionIDs.contains(revisionID) {
            selectedReferenceRevisionIDs.remove(revisionID)
        } else {
            selectedReferenceRevisionIDs.insert(revisionID)
            selectedTargetRevisionIDs.remove(revisionID)
        }
    }

    private func makePlanRequest() -> GlifiStudioAnalysisPlanRequest {
        GlifiStudioAnalysisPlanRequest(
            intent: selectedIntent.rawValue,
            scopeSourceRevisionIDs: [],
            targetSourceRevisionIDs: Array(selectedTargetRevisionIDs).sorted(),
            referenceSourceRevisionIDs: Array(selectedReferenceRevisionIDs).sorted()
        )
    }

    private func initializePackage(
        at url: URL, allowsEmptyPlaceholder: Bool, documentAttachmentID: UUID? = nil
    ) async throws {
        guard documentAttachmentIsCurrent(documentAttachmentID) else { return }
        let accessGranted = url.startAccessingSecurityScopedResource()
        do {
            if allowsEmptyPlaceholder {
                await Task.detached(priority: .userInitiated) {
                    Self.removeEmptyDocumentPlaceholder(at: url)
                }.value
            }
            guard documentAttachmentIsCurrent(documentAttachmentID) else {
                throw CancellationError()
            }
            let created = try await service.createProject(at: url)
            try await activateSession(
                created, at: url, accessGranted: accessGranted,
                documentAttachmentID: documentAttachmentID)
        } catch {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            guard documentAttachmentIsCurrent(documentAttachmentID) else { return }
            throw error
        }
    }

    /// Removes only an empty system-created directory, atomically refusing files and contents.
    nonisolated private static func removeEmptyDocumentPlaceholder(at url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "glifi" else {
            return
        }
        // rmdir refuses nonempty directories and symbolic links, including a concurrent fill.
        _ = url.withUnsafeFileSystemRepresentation { fileSystemPath in
            fileSystemPath.map { rmdir($0) }
        }
    }

    /// Commits presentation state only after every read of the candidate session succeeds.
    private func activateSession(
        _ candidate: GlifiStudioProjectSession,
        at url: URL,
        accessGranted: Bool,
        documentAttachmentID: UUID? = nil
    ) async throws {
        let candidateSnapshot: GlifiStudioProjectSnapshot
        let heads: [GlifiStudioInvestigation]
        do {
            guard documentAttachmentIsCurrent(documentAttachmentID) else {
                throw CancellationError()
            }
            candidateSnapshot = try await candidate.snapshot()
            heads = try await candidate.investigationHeads()
            guard documentAttachmentIsCurrent(documentAttachmentID) else {
                throw CancellationError()
            }
        } catch {
            await candidate.close()
            throw error
        }
        #if os(macOS)
            let previousSession = session
            let previousSecurityScope = securityScopedProjectURL
            activeExecution?.cancel()
            activeExecution = nil
        #else
            await closeSession()
        #endif
        session = candidate
        securityScopedProjectURL = accessGranted ? url : nil
        projectURL = url
        rememberProject(url)
        clearAnalysisState()
        snapshot = candidateSnapshot
        investigationHeads = heads
        investigation = heads.first
        if let investigation {
            editorialSelectedFindingIDs = Set(investigation.selectedFindingIDs)
        }
        #if os(macOS)
            await previousSession?.close()
            previousSecurityScope?.stopAccessingSecurityScopedResource()
        #endif
    }

    private func requireSession() throws -> GlifiStudioProjectSession {
        guard let session else {
            throw presentationFailure(messageKey: "failure.project.none-open")
        }
        return session
    }

    private func clearAnalysisState() {
        #if os(macOS)
            advancedAnalysis.reset()
            corpusMethods.reset()
            statistics.reset()
            evaluation.reset()
            operators.reset()
            linguistics.reset()
            textAnalysisScope = .allSources
            selectedTextAnalysisSourceRevisionIDs = []
            summaryMethod = .sentenceTFIDFMean
            summaryBudgetUnit = .sentences
            summaryBudgetLimit = 3
            summaryRedundancy = .none
            summaryMMRLambda = 0.5
            summaryGraphDamping = GlifiStudioSummaryGraphConfiguration.standard.damping
            summaryGraphTolerance = GlifiStudioSummaryGraphConfiguration.standard.tolerance
            summaryGraphMaximumIterations =
                GlifiStudioSummaryGraphConfiguration.standard.maximumIterations
            summaryGraphSimilarityThreshold =
                GlifiStudioSummaryGraphConfiguration.standard.similarityThreshold
            lastExtractiveSummary = nil
            lastSummaryOptions = nil
            clearSummarySource()
            bm25QueryDraft = ""
            bm25K1 = 1.2
            bm25B = 0.75
            lastBM25Ranking = nil
            lastBM25Options = nil
            clearBM25Source()
            frequencyUnit = .forms
            frequencyN = 2
            frequencyStopwordsDraft = ""
            frequencyMinimumLength = 1
            frequencyMinimumCount = 1
            frequencyMinimumDocumentFrequency = 1
            frequencyMaximumDocumentProportion = 1
            frequencyMaximumRowCount = 1_000
            lastNGramFrequencies = nil
            lastFrequencyOptions = nil
            frequencyPage = 0
            mtldThreshold = 0.72
            lastLexicalDiversity = nil
            lastMTLDOptions = nil
            lastLexicalLaws = nil
            lexicalLawsDraft = StudioLexicalLawsDraft()
            termFrequencyVariant = .raw
            inverseDocumentFrequencyVariant = .smooth
            termWeightingNormalization = .none
            lastTermWeighting = nil
            lastTermWeightingOptions = nil
            termWeightingObservedCellCounts = []
            termWeightingCellPage = 0
            termWeightingTermPage = 0
            keynessMaximumHypothesisCount = 100_000
            keynessLowExpectedCountThreshold = 5
            keynessConfidenceLevel = 0.95
            lastKeynessRequestOptions = nil
            keynessPage = 0
        #endif
        lastProfile = nil
        qualitativeState = nil
        selectedCodebookID = nil
        codingSegments = []
        codingSourceRevisionID = nil
        codingSourceCharacterCount = 0
        codingPassage = nil
        codingTexts = [:]
        storedAgreement = nil
        storedAgreementCodebookID = nil
        storedAgreementRevision = nil
        lastImportedFileName = nil
        planResult = nil
        executionResult = nil
        executionProgress = nil
        visualizations = []
        selectedVisualMarkID = nil
        investigation = nil
        investigationHeads = []
        lastInvestigationProjectID = nil
        lastInvestigationGeneration = nil
        lastInvestigationCreationRequest = nil
        lastInvestigationSelectionRequest = nil
        lastPlanRequest = nil
        queryResult = nil
        lastQueryExpression = nil
        selectedQueryMatchID = nil
        sourceText = nil
        browsedSourceText = nil
        evidenceSourceText = nil
        evidenceSourceRanges = []
        focusedEvidenceID = nil
        exportReceipt = nil
        exportPreviewMarkdown = nil
        lastExportRequest = nil
        lastCorpusAnalysis = nil
        lastCorpusOptions = nil
        lastKeyness = nil
        lastKeynessOptions = nil
        selectedFindingID = nil
        selectedTargetRevisionIDs = []
        selectedReferenceRevisionIDs = []
        editorialSelectedFindingIDs = []
        importProgressCompleted = 0
        importProgressTotal = 0
        lastFailure = nil
    }

    private func rememberProject(_ url: URL) {
        #if os(macOS)
            let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
            let creationOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        lastProjectBookmark = try? url.bookmarkData(
            options: creationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    #if !os(macOS)
        private func closeSession() async {
            activeExecution?.cancel()
            activeExecution = nil
            await session?.close()
            session = nil
            securityScopedProjectURL?.stopAccessingSecurityScopedResource()
            securityScopedProjectURL = nil
        }
    #endif

    /// Owns the direct-analysis task and forwards caller cancellation until its terminal outcome.
    private func runAnalysis(
        messageKey: String,
        operation: @escaping @MainActor () async throws -> Void
    ) async {
        #if os(macOS)
            await run(messageKey: messageKey) { [self] in
                let task = Task { @MainActor in try await operation() }
                activeAnalysisTask = task
                defer { activeAnalysisTask = nil }
                try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
            }
        #else
            await run(messageKey: messageKey, operation: operation)
        #endif
    }

    @discardableResult
    private func run(
        messageKey: String, documentAttachmentID: UUID? = nil,
        operation: @escaping @MainActor () async throws -> Void
    ) async -> Bool {
        #if os(macOS)
            guard !isClosingProject else { return false }
        #endif
        guard !isBusy, documentAttachmentIsCurrent(documentAttachmentID) else { return false }
        busyState = .working(messageKey: messageKey)
        lastFailure = nil
        #if os(macOS)
            let task = Task { @MainActor [self] in
                defer {
                    activeOperationTask = nil
                    busyState = .idle
                    let waiting = documentAttachmentWaiter
                    documentAttachmentWaiter = nil
                    waiting?.continuation.resume()
                }
                await performOperation(operation)
            }
            activeOperationTask = task
            await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
        #else
            defer { busyState = .idle }
            await performOperation(operation)
        #endif
        return true
    }

    private func performOperation(_ operation: () async throws -> Void) async {
        do {
            try Task.checkCancellation()
            try await operation()
        } catch let failure as GlifiStudioFailure {
            lastFailure = failure
        } catch is CancellationError {
            lastFailure = GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "present",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        } catch {
            lastFailure = presentationFailure(messageKey: "failure.internal.unexpected")
        }
    }

    private func presentationFailure(messageKey: String) -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "ui.\(messageKey)",
            category: "invalidInput",
            operation: "present",
            retryDisposition: "afterCorrection",
            retainedState: "lastCommittedGeneration",
            messageKey: messageKey
        )
    }

    private static func projectsRoot() throws -> URL {
        let base = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appending(path: "Glifi Studio", directoryHint: .isDirectory)
    }

    private static func sanitizeFileName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = String(
            trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let collapsed =
            filtered
            .split(whereSeparator: { $0 == "-" || $0 == " " })
            .joined(separator: "-")
        return collapsed.isEmpty ? "Progetto" : String(collapsed.prefix(64))
    }
}
