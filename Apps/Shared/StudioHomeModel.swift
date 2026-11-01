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
    private(set) var codingSegments: [GlifiStudioTextSegment] = []
    private(set) var codingSourceRevisionID: String?
    private(set) var codingSourceCharacterCount = 0
    private(set) var codingPassage: GlifiStudioTextSegment?
    private(set) var codingTexts: [String: String] = [:]
    private(set) var storedAgreement: GlifiStudioStoredCodingAgreement?
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

    private let service: GlifiStudioService
    private var session: GlifiStudioProjectSession?
    private var activeExecution: GlifiStudioAnalysisExecution?
    private var securityScopedProjectURL: URL?

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
        await run(messageKey: "progress.creating-project") {
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
        guard projectURL?.standardizedFileURL != url.standardizedFileURL || session == nil else {
            return
        }
        if needsPackageInitialization,
            !FileManager.default.fileExists(atPath: url.appending(path: "manifest.json").path)
        {
            await run(messageKey: "progress.creating-project") {
                try await initializePackage(at: url, allowsEmptyPlaceholder: true)
            }
        } else {
            await openProject(at: url)
        }
    }

    func openProject(at url: URL) async {
        await run(messageKey: "progress.opening-project") {
            let accessGranted = url.startAccessingSecurityScopedResource()
            do {
                let opened = try await service.openProject(at: url)
                try await activateSession(opened, at: url, accessGranted: accessGranted)
            } catch {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
                throw error
            }
        }
    }

    func reopenLastProject() async {
        guard let lastProjectBookmark else {
            lastFailure = presentationFailure(messageKey: "failure.project.none-open")
            return
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
            let url = try URL(
                resolvingBookmarkData: lastProjectBookmark,
                options: resolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            await openProject(at: url)
        } catch {
            lastFailure = presentationFailure(messageKey: "failure.project.invalid-package")
        }
    }

    func importSource(at url: URL) async {
        await importSources(at: [url])
    }

    func importSources(at urls: [URL]) async {
        await run(messageKey: "progress.importing") {
            let active = try requireSession()
            importProgressTotal = urls.count
            importProgressCompleted = 0
            var lastResult: GlifiStudioProjectImportResult?
            for url in urls {
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let format: GlifiStudioTextFormat =
                    ["md", "markdown"].contains(url.pathExtension.lowercased())
                    ? .markdown : .plainText
                lastResult = try await active.importText(at: url, format: format)
                lastImportedFileName = url.lastPathComponent
                importProgressCompleted += 1
            }
            if let lastResult {
                snapshot = lastResult.project
                lastProfile = lastResult.profile
            }
            importProgressTotal = 0
            importProgressCompleted = 0
        }
    }

    func planInvestigation() async {
        await run(messageKey: "progress.planning") {
            let active = try requireSession()
            let request = makePlanRequest()
            lastPlanRequest = request
            let planned = try await active.planAnalysis(request)
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
        await run(messageKey: "progress.executing") {
            let active = try requireSession()
            let request = makePlanRequest()
            lastPlanRequest = request
            let execution = try await active.executeAnalysisPlan(request)
            activeExecution = execution
            defer { activeExecution = nil }
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
        activeExecution = nil
        executionProgress = nil
        busyState = .idle
    }

    func createInvestigationFromExecution() async {
        await run(messageKey: "progress.investigating") {
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
        await run(messageKey: "progress.investigating") {
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
        await run(messageKey: "progress.revising-selection") {
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
        await run(messageKey: "progress.querying") {
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
        selectedQueryMatchID = match.id
        await run(messageKey: "progress.loading-source") {
            let active = try requireSession()
            sourceText = try await active.sourceText(sourceRevisionID: match.sourceRevisionID)
        }
    }

    func openEvidenceSource(_ evidence: GlifiStudioEvidence) async {
        await run(messageKey: "progress.loading-source") {
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
        selectedVisualMarkID = mark.id
        guard let sourceRevisionID = mark.sourceRevisionIDs.first else {
            return
        }
        await run(messageKey: "progress.loading-source") {
            let active = try requireSession()
            evidenceSourceText = try await active.sourceText(sourceRevisionID: sourceRevisionID)
            // Il lineage contributivo raggiunge il documento, non posizioni esatte.
            evidenceSourceRanges = []
            focusedEvidenceID = nil
        }
    }

    // MARK: - Codifica qualitativa (GS-UX-001-16)

    /// Latest revision of the working codebook, empty when none exists.
    var activeCodebook:
        (codebookID: String, revision: Int, categories: [GlifiStudioCodebookCategory])?
    {
        guard let codebook = qualitativeState?.codebooks.first,
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
        await run(messageKey: "progress.loading-coding") {
            let active = try requireSession()
            qualitativeState = try await active.qualitativeState()
            try await refreshCodingTexts(active)
        }
    }

    func loadCodingSource(_ sourceRevisionID: String) async {
        await run(messageKey: "progress.loading-source") {
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
        await run(messageKey: "progress.loading-source") {
            let active = try requireSession()
            codingPassage = nil
            codingPassage = try await active.passage(
                sourceRevisionID: sourceRevisionID, selection: selection)
        }
    }

    /// Registers the next codebook revision with the given categories.
    func registerCodebookRevision(_ categories: [GlifiStudioCodebookCategory]) async {
        let codebookID = activeCodebook?.codebookID ?? "temi"
        let revision = (activeCodebook?.revision ?? 0) + 1
        await appendQualitative(
            .codebookRevised(codebookID: codebookID, revision: revision, categories: categories))
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

    func assessAgreement(coders: [String]) async {
        guard let codebook = activeCodebook else { return }
        await run(messageKey: "progress.assessing-agreement") {
            storedAgreement = try await requireSession().assessStoredCodingAgreement(
                codebookID: codebook.codebookID, codebookRevision: codebook.revision,
                coderIDs: coders)
        }
    }

    private func appendQualitative(_ change: GlifiStudioQualitativeChange) async {
        await run(messageKey: "progress.recording-coding") {
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

    func analyzeCorpusNow() async {
        await run(messageKey: "progress.analyzing-corpus") {
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
        await run(messageKey: "progress.comparing-keyness") {
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
            let keynessOptions = GlifiStudioKeynessOptions.standard
            let result = try await active.compareKeyness(
                targetSourceRevisionIDs: target,
                referenceSourceRevisionIDs: reference,
                corpusOptions: corpusOptions,
                keynessOptions: keynessOptions
            )
            snapshot = try await active.snapshot()
            lastKeyness = result
            lastKeynessOptions = keynessOptions
            lastCorpusOptions = corpusOptions
        }
    }

    func exportInvestigation(to destinationDirectory: URL) async {
        await run(messageKey: "progress.exporting") {
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
            if let data = try? Data(contentsOf: markdownURL),
                let text = String(data: data, encoding: .utf8)
            {
                exportPreviewMarkdown = text
            } else {
                exportPreviewMarkdown = nil
            }
        }
    }

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

    private func initializePackage(at url: URL, allowsEmptyPlaceholder: Bool) async throws {
        let accessGranted = url.startAccessingSecurityScopedResource()
        do {
            if allowsEmptyPlaceholder {
                await Task.detached(priority: .userInitiated) {
                    Self.removeEmptyDocumentPlaceholder(at: url)
                }.value
            }
            let created = try await service.createProject(at: url)
            try await activateSession(created, at: url, accessGranted: accessGranted)
        } catch {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
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
        accessGranted: Bool
    ) async throws {
        let candidateSnapshot: GlifiStudioProjectSnapshot
        let heads: [GlifiStudioInvestigation]
        do {
            candidateSnapshot = try await candidate.snapshot()
            heads = try await candidate.investigationHeads()
        } catch {
            await candidate.close()
            throw error
        }
        await closeSession()
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
    }

    private func requireSession() throws -> GlifiStudioProjectSession {
        guard let session else {
            throw presentationFailure(messageKey: "failure.project.none-open")
        }
        return session
    }

    private func clearAnalysisState() {
        lastProfile = nil
        qualitativeState = nil
        codingSegments = []
        codingSourceRevisionID = nil
        codingSourceCharacterCount = 0
        codingPassage = nil
        codingTexts = [:]
        storedAgreement = nil
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
            let creationOptions: URL.BookmarkCreationOptions = [
                .withSecurityScope, .minimalBookmark,
            ]
        #else
            let creationOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        lastProjectBookmark = try? url.bookmarkData(
            options: creationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func closeSession() async {
        activeExecution?.cancel()
        activeExecution = nil
        await session?.close()
        session = nil
        securityScopedProjectURL?.stopAccessingSecurityScopedResource()
        securityScopedProjectURL = nil
    }

    private func run(messageKey: String, operation: () async throws -> Void) async {
        guard !isBusy else { return }
        busyState = .working(messageKey: messageKey)
        lastFailure = nil
        defer { busyState = .idle }
        do {
            try await operation()
        } catch let failure as GlifiStudioFailure {
            lastFailure = failure
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
