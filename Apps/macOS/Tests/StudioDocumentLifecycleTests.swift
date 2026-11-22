// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import GlifiKit
import Observation
import Testing

@MainActor
struct StudioDocumentLifecycleTests {
    @Test(arguments: ["digital.pdf", "book.epub"])
    func richDocumentExtensionsImportAndRestoreCapturedSources(file: String) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "Rich.glifi")
        let fixtureRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../Fixtures/DocumentImport/v1").standardizedFileURL
        let model = StudioHomeModel()
        await model.attachDocument(at: projectURL, needsPackageInitialization: true)
        await model.importSource(at: fixtureRoot.appendingPathComponent(file))
        #expect(model.lastFailure == nil)
        let record = try #require(model.snapshot?.sources.first)
        let expectedFormat: GlifiStudioTextFormat = file.hasSuffix(".pdf") ? .pdf : .epub
        #expect(record.format == expectedFormat)
        #expect(model.snapshot?.sourceCount == 1)
        #expect(model.snapshot?.artifactCount == 1)
        await model.browseSource(record.sourceRevisionID)
        let captured = try #require(model.browsedSourceText)
        #expect(captured.document?.format == expectedFormat)
        model.queryDraft = "normalized:casa"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.isEmpty == false)
        let reopened = StudioHomeModel()
        await reopened.attachDocument(at: projectURL, needsPackageInitialization: false)
        #expect(reopened.lastFailure == nil)
        await reopened.browseSource(record.sourceRevisionID)
        #expect(reopened.browsedSourceText == captured)
    }

    @Test func initializesAnEmptyDocumentPlaceholder() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "New.glifi")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let model = StudioHomeModel()

        await model.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.generation == 0)
        #expect(model.projectURL == destination)
        #expect(
            FileManager.default.fileExists(
                atPath: destination.appending(path: "manifest.json").path))
    }

    @Test func repeatedAttachmentPreservesCommittedSourcesAndQuery() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Repeated.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let projectID = try #require(model.snapshot?.projectID)
        let generation = model.snapshot?.generation
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let queryDigest = model.queryResult?.queryDigest
        let manifestURL = destination.appending(path: "manifest.json")
        let manifestBefore = try Data(contentsOf: manifestURL)

        await model.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.projectID == projectID)
        #expect(model.snapshot?.generation == generation)
        #expect(model.snapshot?.sourceCount == 1)
        #expect(model.queryResult?.queryDigest == queryDigest)
        #expect(try Data(contentsOf: manifestURL) == manifestBefore)
    }

    @Test func staleInitializationFlagOpensAnExistingProject() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Existing.glifi")
        let original = StudioHomeModel()
        await original.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: original, in: root)
        let projectID = try #require(original.snapshot?.projectID)
        let reopened = StudioHomeModel()

        await reopened.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(reopened.lastFailure == nil)
        #expect(reopened.snapshot?.projectID == projectID)
        #expect(reopened.snapshot?.sourceCount == 1)
        reopened.queryDraft = "normalized:fonte"
        await reopened.runQuery()
        #expect(reopened.queryResult?.matches.count == 1)
    }

    @Test func refusesAnIncompleteNonemptyPackageWithoutRemovingItsContents() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Incomplete.glifi")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let sentinelURL = destination.appending(path: "source.txt")
        let sentinel = Data("A committed source must survive.".utf8)
        try sentinel.write(to: sentinelURL)
        let model = StudioHomeModel()

        await model.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(model.lastFailure?.code == "project.invalid-destination")
        #expect(model.snapshot == nil)
        #expect(try Data(contentsOf: sentinelURL) == sentinel)
        #expect(
            !FileManager.default.fileExists(
                atPath: destination.appending(path: "manifest.json").path))
    }

    @Test func refusesARegularFileAndASymbolicLink() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "File.glifi")
        let data = Data("Keep this file.".utf8)
        try data.write(to: file)
        let model = StudioHomeModel()
        await model.attachDocument(at: file, needsPackageInitialization: true)
        #expect(model.lastFailure != nil)
        #expect(try Data(contentsOf: file) == data)

        let target = root.appending(path: "Target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let link = root.appending(path: "Link.glifi")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        await model.attachDocument(at: link, needsPackageInitialization: true)
        #expect(model.lastFailure != nil)
        #expect(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
    }

    @Test func failedOpenPreservesTheUsablePreviousSession() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Valid.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let projectID = try #require(model.snapshot?.projectID)
        let bookmark = model.lastProjectBookmark

        await model.openProject(at: root.appending(path: "Missing.glifi"))

        #expect(model.lastFailure != nil)
        #expect(model.projectURL == destination)
        #expect(model.snapshot?.projectID == projectID)
        #expect(model.lastProjectBookmark == bookmark)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func failedInitializationPreservesTheUsablePreviousSession() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Valid.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let occupied = root.appending(path: "Occupied.glifi")
        try Data("Keep this file.".utf8).write(to: occupied)

        await model.attachDocument(at: occupied, needsPackageInitialization: true)

        #expect(model.lastFailure != nil)
        #expect(model.projectURL == destination)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func successfulSwitchClearsThePreviousAnalysis() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "First.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.queryResult?.matches.count == 1)
        let firstID = model.snapshot?.projectID
        let sourceRevisionID = try #require(model.snapshot?.sources.first?.sourceRevisionID)
        await model.loadCodingSource(sourceRevisionID)
        #expect(model.codingSourceRevisionID == sourceRevisionID)
        #expect(!model.codingSegments.isEmpty)

        await model.attachDocument(
            at: root.appending(path: "Second.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.projectID != firstID)
        #expect(model.snapshot?.sourceCount == 0)
        #expect(model.queryResult == nil)
        #expect(model.lastProfile == nil)
        #expect(model.qualitativeState == nil)
        #expect(model.codingSourceRevisionID == nil)
        #expect(model.codingSegments.isEmpty)
        #expect(model.codingSourceCharacterCount == 0)
    }

    @Test func partialImportPublishesCommittedSourcesAndStopsAtTheFailure() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Partial.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let previousGeneration = try #require(model.snapshot?.generation)
        let previousProfile = try #require(model.lastProfile)
        let committed = root.appending(path: "committed.txt")
        let committedText = "Il campione distingue ogni risultato."
        try Data(committedText.utf8).write(to: committed)
        let invalid = root.appending(path: "invalid.txt")
        try Data([0xFF]).write(to: invalid)
        let unreached = root.appending(path: "unreached.txt")
        try Data("La sentinella resta fuori dal progetto.".utf8).write(to: unreached)

        await model.importSources(at: [committed, invalid, unreached])

        let failure = try #require(model.lastFailure)
        #expect(failure.code == "text.invalid-utf8")
        #expect(failure.category == "invalidInput")
        #expect(failure.operation == "importText")
        #expect(failure.retryDisposition == "afterCorrection")
        #expect(failure.retainedState == "unchanged")
        #expect(model.snapshot?.generation == previousGeneration + 1)
        #expect(model.snapshot?.sourceCount == 2)
        let committedProfile = try #require(model.lastProfile)
        #expect(committedProfile != previousProfile)
        #expect(committedProfile.utf8ByteCount == committedText.utf8.count)
        #expect(committedProfile.topTerms.contains { $0.term == "campione" })
        #expect(model.lastImportedFileName == committed.lastPathComponent)
        #expect(model.importProgressCompleted == 0)
        #expect(model.importProgressTotal == 0)
        #expect(!model.isBusy)
        let committedSnapshot = model.snapshot
        model.queryDraft = "normalized:campione"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
        model.queryDraft = "normalized:sentinella"
        await model.runQuery()
        #expect(model.queryResult?.matches.isEmpty == true)

        let reopened = StudioHomeModel()
        await reopened.attachDocument(at: destination, needsPackageInitialization: false)
        #expect(reopened.lastFailure == nil)
        #expect(reopened.snapshot == committedSnapshot)
        reopened.queryDraft = "normalized:campione"
        await reopened.runQuery()
        #expect(reopened.lastFailure == nil)
        #expect(reopened.queryResult?.matches.count == 1)
    }

    @Test func failureBeforeAnyImportPreservesThePreviousPresentation() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Preserved.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let previousSnapshot = model.snapshot
        let previousProfile = model.lastProfile
        let previousFileName = model.lastImportedFileName
        let previousQueryDigest = model.queryResult?.queryDigest
        let invalid = root.appending(path: "invalid.txt")
        try Data([0xFF]).write(to: invalid)
        let unreached = root.appending(path: "unreached.txt")
        try Data("Un documento che non deve essere importato.".utf8).write(to: unreached)

        await model.importSources(at: [invalid, unreached])

        #expect(model.lastFailure?.code == "text.invalid-utf8")
        #expect(model.snapshot == previousSnapshot)
        #expect(model.lastProfile == previousProfile)
        #expect(model.lastImportedFileName == previousFileName)
        #expect(model.queryResult?.queryDigest == previousQueryDigest)
        #expect(model.importProgressCompleted == 0)
        #expect(model.importProgressTotal == 0)
        #expect(!model.isBusy)
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func successfulBatchPublishesTheLastCommittedProfileAndClearsProgress() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Batch.glifi"), needsPackageInitialization: true)
        let plain = root.appending(path: "first.txt")
        try Data("Una fonte affidabile.".utf8).write(to: plain)
        let markdown = root.appending(path: "last.md")
        try Data("# Campione\n\nUn risultato **riproducibile**.".utf8).write(to: markdown)

        await model.importSources(at: [plain, markdown])

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.generation == 2)
        #expect(model.snapshot?.sourceCount == 2)
        #expect(model.snapshot?.sources.contains { $0.format == .plainText } == true)
        #expect(model.snapshot?.sources.contains { $0.format == .markdown } == true)
        #expect(model.lastProfile?.topTerms.contains { $0.term == "riproducibile" } == true)
        #expect(model.lastImportedFileName == markdown.lastPathComponent)
        #expect(model.importProgressCompleted == 0)
        #expect(model.importProgressTotal == 0)
        #expect(!model.isBusy)
        model.queryDraft = "normalized:riproducibile"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func cancellationKeepsExecutionOwnershipUntilTheConsumerFinishes() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Cancelled.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let observation = ExecutionCancellationObservation()

        _ = withObservationTracking(options: .didSet) {
            model.activeExecutionOperationID
        } onChange: { event in
            guard event.kind == .didSet else { return }
            event.cancel()
            // This callback runs synchronously inside the Main Actor-isolated setter.
            MainActor.assumeIsolated {
                let operationID = model.activeExecutionOperationID
                observation.operationID = operationID
                #expect(operationID != nil)
                #expect(model.isBusy)

                model.cancelExecution()
                model.cancelExecution()

                #expect(model.isBusy)
                #expect(model.activeExecutionOperationID == operationID)
                #expect(model.canCancelExecution)
            }
        }

        await model.executePlan()

        #expect(observation.operationID != nil)
        #expect(!model.isBusy)
        #expect(model.activeExecutionOperationID == nil)
        #expect(!model.canCancelExecution)
        #expect(model.executionProgress == nil)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func nativeReopeningPreservesTheCallingDocumentsState() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Native.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        await model.planInvestigation()
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let previousURL = try #require(model.projectURL)
        let previousSnapshot = try #require(model.snapshot)
        let previousProfile = try #require(model.lastProfile)
        let previousPlan = try #require(model.planResult)
        let previousQuery = try #require(model.queryResult)
        let previousBookmark = try #require(model.lastProjectBookmark)
        var openedURLs: [URL] = []

        await model.reopenLastProject(using: { url in openedURLs.append(url) })

        #expect(model.lastFailure == nil)
        #expect(openedURLs.count == 1)
        #expect(
            openedURLs.first?.resolvingSymlinksInPath().path
                == previousURL.resolvingSymlinksInPath().path)
        #expect(model.projectURL == previousURL)
        #expect(model.snapshot == previousSnapshot)
        #expect(model.lastProfile == previousProfile)
        #expect(model.planResult == previousPlan)
        #expect(model.queryResult == previousQuery)
        #expect(model.lastProjectBookmark == previousBookmark)
        #expect(!model.isBusy)
    }

    @Test func nativeReopeningWithoutABookmarkDoesNotInvokeTheOpener() async {
        let model = StudioHomeModel()
        var openedURLs: [URL] = []

        await model.reopenLastProject(using: { url in openedURLs.append(url) })

        #expect(openedURLs.isEmpty)
        #expect(model.lastFailure?.messageKey == "failure.project.none-open")
        #expect(model.projectURL == nil)
        #expect(model.snapshot == nil)
        #expect(!model.isBusy)
    }

    @Test func failedNativeReopeningPreservesTheUsableCallingDocument() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "PreservedNative.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let previousURL = model.projectURL
        let previousSnapshot = model.snapshot
        let previousProfile = model.lastProfile
        let previousQuery = model.queryResult
        let previousBookmark = try #require(model.lastProjectBookmark)
        var openedURLs: [URL] = []

        await model.reopenLastProject(using: { url in
            openedURLs.append(url)
            throw CocoaError(.fileReadNoPermission)
        })

        #expect(openedURLs.count == 1)
        #expect(model.lastFailure?.messageKey == "failure.project.invalid-package")
        #expect(model.projectURL == previousURL)
        #expect(model.snapshot == previousSnapshot)
        #expect(model.lastProfile == previousProfile)
        #expect(model.queryResult == previousQuery)
        #expect(model.lastProjectBookmark == previousBookmark)
        #expect(!model.isBusy)
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test(arguments: StudioSummaryMethod.allCases)
    func summaryParametersAndSelectedScopeMatchTheKit(method: StudioSummaryMethod) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "SummaryParameters.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: projectURL, needsPackageInitialization: true)
        let first = root.appending(path: "first.txt")
        try Data("La raccolta racconta la lingua. La lingua distingue le fonti.".utf8).write(
            to: first)
        let second = root.appending(path: "second.txt")
        try Data(
            "Il campione conserva una prova. Una prova riproducibile sostiene il campione.".utf8
        )
        .write(to: second)
        await model.importSources(at: [first, second])
        let sources = try #require(model.snapshot?.sources)
        let lastDigest = try #require(model.lastProfile?.contentDigest)
        let selectedID = try #require(
            sources.first { $0.contentDigest == lastDigest }?.sourceRevisionID)
        let otherID = try #require(
            sources.first { $0.sourceRevisionID != selectedID }?.sourceRevisionID)
        model.selectedTargetRevisionIDs = [otherID]
        model.selectedReferenceRevisionIDs = [selectedID]
        model.queryDraft = "normalized:raccolta"
        await model.runQuery()
        let previousQuery = try #require(model.queryResult)
        let previousSource = model.sourceText
        model.textAnalysisScope = .selectedSources
        model.toggleTextAnalysisSource(selectedID)
        model.summaryMethod = method
        switch method {
        case .sentenceTFIDFMean:
            model.summaryBudgetUnit = .sentences
            model.summaryBudgetLimit = 1
            model.summaryRedundancy = .none
        case .centroidCosine:
            model.summaryBudgetUnit = .lexicalTokens
            model.summaryBudgetLimit = 10
            model.summaryRedundancy = .maximalMarginalRelevance
            model.summaryMMRLambda = 0.6
        case .lexRank, .textRank:
            model.summaryBudgetUnit = .characters
            model.summaryBudgetLimit = 70
            model.summaryRedundancy = .none
        case .textRankConfigurable, .lexRankContinuous, .lexRankThreshold:
            model.summaryBudgetUnit = .characters
            model.summaryBudgetLimit = 70
            model.summaryRedundancy = .maximalMarginalRelevance
            model.summaryMMRLambda = 0.7
            model.summaryGraphDamping = 0.7
            model.summaryGraphTolerance = 1e-10
            model.summaryGraphMaximumIterations = 250
            model.summaryGraphSimilarityThreshold = 0.25
        }

        await model.summarizeSources()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastExtractiveSummary)
        let options = try #require(model.lastSummaryOptions)
        #expect(options.scope == .selectedSources)
        #expect(options.sourceRevisionIDs == [selectedID])
        #expect(options.method == method)
        #expect(options.budgetUnit == model.summaryBudgetUnit)
        #expect(options.budgetLimit == model.summaryBudgetLimit)
        #expect(options.redundancy == model.summaryRedundancy)
        if method.supportsGraphConfiguration {
            #expect(
                options.graphConfiguration
                    == GlifiStudioSummaryGraphConfiguration(
                        damping: 0.7, tolerance: 1e-10, maximumIterations: 250,
                        similarityThreshold: 0.25))
            #expect(result.graphDiagnostics?.configuration == options.graphConfiguration)
        } else {
            #expect(options.graphConfiguration == nil)
            #expect(result.graphDiagnostics == nil)
        }
        #expect(options.scheme == .summaryStandard)
        #expect(options.corpusOptions == .standard)
        #expect(result.sourceRevisionIDs == [selectedID])
        #expect(result.methodIdentifier == method.rawValue)
        #expect(result.budget.unit == options.budgetUnit.rawValue)
        #expect(result.budget.limit == options.budgetLimit)
        #expect(result.redundancyPolicy == options.redundancy.rawValue)
        #expect(result.redundancyLambda == options.mmrLambda)
        #expect(model.snapshot?.generation == result.lineage.generation)
        #expect(model.selectedTargetRevisionIDs == [otherID])
        #expect(model.selectedReferenceRevisionIDs == [selectedID])
        #expect(model.queryResult == previousQuery)
        #expect(model.sourceText == previousSource)
        #expect(!model.isBusy)
        let reference = try await GlifiStudioService().openProject(at: projectURL)
        let referenceResult = try await reference.analyzeExtractiveSummary(
            sourceRevisionIDs: [selectedID],
            budget: GlifiStudioSummaryBudget(
                unit: options.budgetUnit.rawValue, limit: options.budgetLimit),
            method: GlifiStudioSummaryScoringMethod(identifier: method.rawValue),
            redundancy: GlifiStudioSummaryRedundancy(
                identifier: options.redundancy.rawValue, lambda: options.mmrLambda),
            graphConfiguration: options.graphConfiguration)
        #expect(result.lineage.artifactID == referenceResult.lineage.artifactID)
        #expect(result.sentences == referenceResult.sentences)
        #expect(result.selected == referenceResult.selected)
        #expect(result.graphDiagnostics == referenceResult.graphDiagnostics)
        await reference.close()
        let committedGeneration = model.snapshot?.generation

        await model.summarizeSources()

        #expect(model.lastFailure == nil)
        #expect(model.lastExtractiveSummary?.lineage.artifactID == result.lineage.artifactID)
        #expect(model.snapshot?.generation == committedGeneration)
        model.summaryBudgetLimit += 1
        #expect(model.lastSummaryOptions == options)
        model.summaryBudgetLimit = options.budgetLimit
        model.textAnalysisScope = .allSources

        await model.summarizeSources()

        #expect(model.lastFailure == nil)
        #expect(model.lastSummaryOptions?.scope == .allSources)
        #expect(
            model.lastExtractiveSummary?.sourceRevisionIDs
                == sources.map(\.sourceRevisionID).sorted())
    }

    @Test func summarySourceUsesOriginalMappingWithoutChangingQueryOrEvidence() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "SummarySource.glifi"), needsPackageInitialization: true)
        let sourceURL = root.appending(path: "source.md")
        let original = "\u{FEFF}Una **città** conserva la [prova](https://example.invalid)."
        try Data(original.utf8).write(to: sourceURL)
        await model.importSource(at: sourceURL)
        model.queryDraft = "normalized:città"
        await model.runQuery()
        await model.executePlan()
        let evidence = try #require(
            model.executionResult?.interpretation.evidence.first { !$0.sourceReferences.isEmpty })
        await model.openEvidenceSource(evidence)
        let previousQuery = try #require(model.queryResult)
        let previousQuerySource = try #require(model.sourceText)
        let previousEvidenceSource = try #require(model.evidenceSourceText)
        let previousEvidenceRanges = model.evidenceSourceRanges
        model.textAnalysisScope = .allSources
        model.summaryBudgetLimit = 1

        await model.summarizeSources()

        #expect(model.lastFailure == nil)
        #expect(model.lastSummaryOptions?.scope == .allSources)
        let result = try #require(model.lastExtractiveSummary)
        let selected = try #require(result.selected.first)
        #expect(selected.text.contains("città"))
        #expect(!selected.text.contains("**"))
        #expect(selected.sentence.startUTF8 == 0)
        #expect(selected.sourceRanges.first?.start == 3)

        await model.openSummarySource(selected)

        #expect(model.lastFailure == nil)
        #expect(model.summarySourceText?.text == original)
        #expect(model.summarySourceRanges == selected.sourceRanges)
        #expect(
            model.focusedSummarySentenceID
                == "\(selected.sentence.sourceRevisionID):\(selected.sentence.sentenceIndex)")
        #expect(model.queryResult == previousQuery)
        #expect(model.sourceText == previousQuerySource)
        #expect(model.evidenceSourceText == previousEvidenceSource)
        #expect(model.evidenceSourceRanges == previousEvidenceRanges)
        var legacyObject = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(selected)) as? [String: Any])
        legacyObject.removeValue(forKey: "sourceRanges")
        let legacy = try JSONDecoder().decode(
            GlifiStudioSelectedSentence.self,
            from: JSONSerialization.data(withJSONObject: legacyObject))

        await model.openSummarySource(legacy)

        #expect(model.lastFailure == nil)
        #expect(model.summarySourceText?.text == original)
        #expect(model.summarySourceRanges.isEmpty)
        model.toggleTextAnalysisSource(selected.sentence.sourceRevisionID)

        await model.attachDocument(
            at: root.appending(path: "Fresh.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.lastExtractiveSummary == nil)
        #expect(model.lastSummaryOptions == nil)
        #expect(model.selectedTextAnalysisSourceRevisionIDs.isEmpty)
        #expect(model.summarySourceText == nil)
        #expect(model.summarySourceRanges.isEmpty)
        #expect(model.focusedSummarySentenceID == nil)
    }

    @Test func summaryFailuresPreserveThePreviousResultWithoutCorrectingParameters() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "SummaryFailure.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        await model.summarizeSources()
        let result = try #require(model.lastExtractiveSummary)
        let options = try #require(model.lastSummaryOptions)
        let committedSnapshot = model.snapshot
        model.textAnalysisScope = .selectedSources

        await model.summarizeSources()

        #expect(model.lastFailure?.code == "summary.insufficient-sources")
        #expect(model.lastExtractiveSummary == result)
        #expect(model.lastSummaryOptions == options)
        #expect(model.snapshot == committedSnapshot)
        model.textAnalysisScope = .allSources
        model.summaryBudgetLimit = 0

        await model.summarizeSources()

        #expect(model.lastFailure?.code == "summary.invalid-budget")
        #expect(model.summaryBudgetLimit == 0)
        #expect(model.lastExtractiveSummary == result)
        #expect(model.lastSummaryOptions == options)
        #expect(model.snapshot == committedSnapshot)
        model.summaryBudgetLimit = 1
        model.summaryRedundancy = .maximalMarginalRelevance
        model.summaryMMRLambda = .nan

        await model.summarizeSources()

        #expect(model.lastFailure?.code == "summary.invalid-redundancy")
        #expect(model.summaryMMRLambda.isNaN)
        #expect(model.lastExtractiveSummary == result)
        #expect(model.lastSummaryOptions == options)
        #expect(model.snapshot == committedSnapshot)
        #expect(!model.isBusy)
    }

    @Test func aSummaryWithoutEligibleSentencesRemainsAnExplicitEmptyResult() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "EmptySummary.glifi"), needsPackageInitialization: true)
        let sourceURL = root.appending(path: "punctuation.txt")
        try Data("...".utf8).write(to: sourceURL)
        await model.importSource(at: sourceURL)

        await model.summarizeSources()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastExtractiveSummary)
        #expect(result.sourceRevisionIDs.count == 1)
        #expect(result.selected.isEmpty)
        #expect(result.consumedBudget == 0)
        #expect(model.lastSummaryOptions != nil)
        #expect(model.snapshot?.generation == result.lineage.generation)
        #expect(!model.isBusy)
    }

    @Test func lexicalLawsCaptureTheSelectedScopeAndRetainThePreviousResultOnFailure()
        async throws
    {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "LexicalLaws.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: projectURL, needsPackageInitialization: true)
        let sources = try await importTexts(
            [
                "sole sole sole luna luna mare vento casa",
                "prova prova fonte fonte testo parola libro",
            ],
            into: model, in: root)
        let selectedID = try #require(sources.first?.sourceRevisionID)
        let otherID = try #require(sources.last?.sourceRevisionID)
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = [selectedID]
        model.queryDraft = "normalized:sole"
        await model.runQuery()
        let previousQuery = model.queryResult
        model.lexicalLawsDraft.checkpointCount = 4
        model.lexicalLawsDraft.usesLastObservedRank = false
        model.lexicalLawsDraft.lastRank = 3
        model.lexicalLawsDraft.rankRowLimit = 2
        let draft = model.lexicalLawsDraft
        let parameters = draft.parameters

        await model.analyzeLexicalLaws(parameters: parameters)

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastLexicalLaws)
        #expect(result.sourceRevisionIDs == [selectedID])
        #expect(result.parameters == parameters)
        #expect(result.rankFrequency.count == 2)
        #expect(result.isRankFrequencyTruncated)
        #expect(result.zipf.fit?.pointCount == 3)
        #expect(model.queryResult == previousQuery)
        let reference = try await GlifiStudioService().openProject(at: projectURL)
        let referenceResult = try await reference.analyzeLexicalLaws(
            sourceRevisionIDs: [selectedID], parameters: parameters)
        #expect(result.lineage.artifactID == referenceResult.lineage.artifactID)
        #expect(result.sourceRevisionIDs == referenceResult.sourceRevisionIDs)
        #expect(result.parameters == referenceResult.parameters)
        #expect(result.tokenCount == referenceResult.tokenCount)
        #expect(result.typeCount == referenceResult.typeCount)
        #expect(result.rankFrequency == referenceResult.rankFrequency)
        #expect(result.spectrum == referenceResult.spectrum)
        #expect(result.growth == referenceResult.growth)
        #expect(result.zipf == referenceResult.zipf)
        #expect(result.heaps == referenceResult.heaps)
        await reference.close()
        let previousSnapshot = model.snapshot
        model.selectedTextAnalysisSourceRevisionIDs = [otherID]
        #expect(model.lastLexicalLaws == result)

        await model.analyzeLexicalLaws(
            parameters: GlifiStudioLexicalLawsParameters(
                checkpointCount: 1, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 2))

        #expect(model.lastFailure?.code == "laws.invalid-checkpoints")
        #expect(model.lastLexicalLaws == result)
        #expect(model.snapshot == previousSnapshot)
        #expect(model.lexicalLawsDraft == draft)
        #expect(!model.isBusy)
        await model.attachDocument(
            at: root.appending(path: "FreshLexicalLaws.glifi"), needsPackageInitialization: true)
        #expect(model.lastFailure == nil)
        #expect(model.lastLexicalLaws == nil)
        #expect(model.lexicalLawsDraft == StudioLexicalLawsDraft())
        #expect(model.textAnalysisScope == .allSources)
        #expect(model.selectedTextAnalysisSourceRevisionIDs.isEmpty)
    }

    @Test func bm25UsesTheSelectedScopeAndPreservesZeroScoresAndQueryState() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "BM25.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: projectURL, needsPackageInitialization: true)
        let sources = try await importTexts(
            ["sole sole luna", "sole luna luna", "pietra pietra"], into: model, in: root)
        model.queryDraft = "normalized:sole"
        await model.runQuery()
        let query = try #require(model.queryResult)
        let querySource = model.sourceText
        let selectedIDs = Array(sources.prefix(2).map(\.sourceRevisionID)).sorted()
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = Set(selectedIDs)
        model.bm25QueryDraft = "SOLE sole estraneo"
        model.bm25K1 = 2.1
        model.bm25B = 0.4

        await model.rankSourcesBM25()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastBM25Ranking)
        let options = try #require(model.lastBM25Options)
        #expect(options.sourceRevisionIDs == selectedIDs)
        #expect(options.scope == .selectedSources)
        #expect(options.query == "SOLE sole estraneo")
        #expect(result.k1 == 2.1)
        #expect(result.b == 0.4)
        #expect(result.queryTerms.map(\.term) == ["estraneo", "sole"])
        #expect(result.queryTerms.first?.isInVocabulary == false)
        #expect(result.queryTerms.first?.documentFrequency == 0)
        let reference = try await GlifiStudioService().openProject(at: projectURL)
        let expected = try await reference.rankDocumentsBM25(
            sourceRevisionIDs: selectedIDs, query: options.query, k1: 2.1, b: 0.4)
        #expect(result.ranking == expected.ranking)
        #expect(result.queryTerms == expected.queryTerms)
        #expect(result.lineage.artifactID == expected.lineage.artifactID)
        await reference.close()
        #expect(model.queryDraft == "normalized:sole")
        #expect(model.queryResult == query)
        #expect(model.sourceText == querySource)
        #expect(model.snapshot?.generation == result.lineage.generation)
        model.textAnalysisScope = .allSources
        model.bm25QueryDraft = "fuorivocabolario"

        await model.rankSourcesBM25()

        let zeroScores = try #require(model.lastBM25Ranking)
        #expect(model.lastFailure == nil)
        #expect(zeroScores.ranking.count == sources.count)
        #expect(zeroScores.ranking.allSatisfy { $0.score == 0 })
        #expect(
            zeroScores.ranking.map(\.sourceRevisionID)
                == sources.map(\.sourceRevisionID).sorted())
        let document = try #require(zeroScores.ranking.first)

        await model.openBM25Source(document)

        #expect(model.lastFailure == nil)
        #expect(model.bm25SourceText?.sourceRevisionID == document.sourceRevisionID)
        #expect(model.queryResult == query)
        #expect(model.sourceText == querySource)
        let generation = model.snapshot?.generation

        await model.rankSourcesBM25()

        #expect(model.lastBM25Ranking?.lineage.artifactID == zeroScores.lineage.artifactID)
        #expect(model.snapshot?.generation == generation)
        #expect(model.bm25SourceText == nil)
        model.bm25QueryDraft = "nuovo testo"
        #expect(model.lastBM25Options?.query == "fuorivocabolario")
    }

    @Test func bm25FailuresPreserveTheRankingAndProjectChangesClearItsState() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "BM25Failure.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.bm25QueryDraft = "fonte"
        await model.rankSourcesBM25()
        let result = try #require(model.lastBM25Ranking)
        let options = try #require(model.lastBM25Options)
        let snapshot = model.snapshot
        model.bm25B = 2

        await model.rankSourcesBM25()

        #expect(model.lastFailure?.code == "bm25.invalid-parameters")
        #expect(model.bm25B == 2)
        #expect(model.lastBM25Ranking == result)
        #expect(model.lastBM25Options == options)
        #expect(model.snapshot == snapshot)
        model.bm25B = 0.75
        model.bm25K1 = .nan

        await model.rankSourcesBM25()

        #expect(model.lastFailure?.code == "bm25.invalid-parameters")
        #expect(model.bm25K1.isNaN)
        #expect(model.lastBM25Ranking == result)
        model.bm25K1 = 1.2
        model.bm25QueryDraft = "  "

        await model.rankSourcesBM25()

        #expect(model.lastFailure?.code == "bm25.empty-query")
        #expect(model.lastBM25Ranking == result)
        #expect(model.lastBM25Options == options)
        #expect(!model.isBusy)
        let document = try #require(result.ranking.first)
        await model.openBM25Source(document)
        #expect(model.lastFailure == nil)
        #expect(model.bm25SourceText != nil)

        await model.attachDocument(
            at: root.appending(path: "BM25Fresh.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.lastBM25Ranking == nil)
        #expect(model.lastBM25Options == nil)
        #expect(model.bm25SourceText == nil)
        #expect(model.bm25QueryDraft.isEmpty)
    }

    @Test(arguments: StudioFrequencyUnit.allCases)
    func frequencyUnitsAndUnicodeFiltersMatchTheKit(unit: StudioFrequencyUnit) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "FrequencyUnits.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: projectURL, needsPackageInitialization: true)
        let sources = try await importTexts(
            ["e\u{0301} à à sole", "materiale escluso"], into: model, in: root)
        let excludedDigest = try #require(model.lastProfile?.contentDigest)
        let selectedID = try #require(
            sources.first { $0.contentDigest != excludedDigest }?.sourceRevisionID)
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = [selectedID]
        model.frequencyUnit = unit
        model.frequencyN = 2
        model.frequencyStopwordsDraft = " À \n\nÀ\r\n"
        model.frequencyMinimumLength = 2

        await model.analyzeFrequencies()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastNGramFrequencies)
        let options = try #require(model.lastFrequencyOptions)
        #expect(options.sourceRevisionIDs == [selectedID])
        #expect(result.sourceRevisionIDs == [selectedID])
        #expect(options.filter.stopwords == ["À", "À"])
        #expect(result.filter.stopwords == ["à"])
        #expect(options.unit.kind == unit.rawValue)
        switch unit {
        case .forms:
            #expect(options.unit.n == 1)
            #expect(result.denominator == 4)
            #expect(result.filter.minimumLength == 2)
        case .words:
            #expect(options.unit.n == 2)
            #expect(result.denominator == 3)
            #expect(result.filter.minimumLength == 1)
        case .characters:
            #expect(options.unit.n == 2)
            #expect(result.denominator == 3)
            #expect(result.filter.minimumLength == 1)
        case .paddedCharacters:
            #expect(options.unit.n == 2)
            #expect(result.denominator == 11)
            #expect(result.filter.minimumLength == 1)
        }
        let reference = try await GlifiStudioService().openProject(at: projectURL)
        let expected = try await reference.analyzeNGramFrequencies(
            sourceRevisionIDs: options.sourceRevisionIDs, unit: options.unit,
            filter: options.filter, maximumRowCount: options.maximumRowCount)
        #expect(result.rows == expected.rows)
        #expect(result.denominator == expected.denominator)
        #expect(result.exclusions == expected.exclusions)
        #expect(result.lineage.artifactID == expected.lineage.artifactID)
        await reference.close()
        #expect(model.snapshot?.generation == result.lineage.generation)
    }

    @Test func frequencyFiltersKeepTheOriginalDenominatorAndEffectiveRequest() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Filtered.glifi"), needsPackageInitialization: true)
        _ = try await importTexts(
            [
                "sempre comune comune condiviso escluso", "sempre comune condiviso condiviso",
                "sempre terzo",
            ], into: model, in: root)
        model.frequencyStopwordsDraft = "comune"
        model.frequencyMinimumLength = 6
        model.frequencyMinimumCount = 3
        model.frequencyMinimumDocumentFrequency = 2
        model.frequencyMaximumDocumentProportion = 0.8

        await model.analyzeFrequencies()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastNGramFrequencies)
        let options = try #require(model.lastFrequencyOptions)
        #expect(result.denominator == 11)
        #expect(result.rows.count == 1)
        #expect(result.rows.first?.components == ["condiviso"])
        #expect(result.rows.first?.count == 3)
        #expect(result.rows.first?.documentFrequency == 2)
        #expect(result.rows.first?.relativeFrequency == 3.0 / 11.0)
        #expect(result.filter == options.filter)
        #expect(result.exclusions.stopwords == 1)
        #expect(result.exclusions.minimumLength == 1)
        #expect(result.exclusions.maximumDocumentProportion == 1)
        let generation = model.snapshot?.generation

        await model.analyzeFrequencies()

        #expect(model.snapshot?.generation == generation)
        #expect(model.lastNGramFrequencies?.lineage.artifactID == result.lineage.artifactID)
        model.frequencyMinimumCount = 99
        #expect(model.lastFrequencyOptions == options)
    }

    @Test func frequencyPaginationExploresEveryReturnedRowAndSeparatesCalculationLimits()
        async throws
    {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Pages.glifi"), needsPackageInitialization: true)
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        let terms = (0..<125).map { "parola\(letters[$0 / 26])\(letters[$0 % 26])" }
        _ = try await importTexts([terms.joined(separator: " ")], into: model, in: root)
        await model.analyzeFrequencies()
        let result = try #require(model.lastNGramFrequencies)
        #expect(result.rows.count == 125)
        #expect(!result.isTruncated)
        #expect(model.frequencyPageCount == 3)
        let generation = model.snapshot?.generation
        var visited: [GlifiStudioNGramFrequencyRow] = []
        for page in 0..<model.frequencyPageCount {
            model.showFrequencyPage(page)
            visited += model.frequencyRowsOnPage
        }
        #expect(visited == result.rows)
        #expect(model.frequencyRowsOnPage.count == 25)
        model.showFrequencyPage(-1)
        model.showFrequencyPage(3)
        #expect(model.frequencyPage == 2)
        #expect(model.snapshot?.generation == generation)
        #expect(model.lastNGramFrequencies == result)
        model.frequencyMaximumRowCount = 60

        await model.analyzeFrequencies()

        let limited = try #require(model.lastNGramFrequencies)
        #expect(limited.isTruncated)
        #expect(limited.distinctUnitCount == 125)
        #expect(limited.denominator == 125)
        #expect(limited.rows == Array(result.rows.prefix(60)))
        #expect(model.frequencyPage == 0)
        #expect(model.frequencyPageCount == 2)
        model.showFrequencyPage(1)
        #expect(model.frequencyRowsOnPage.count == 10)
        model.frequencyStopwordsDraft = terms.joined(separator: "\n")

        await model.analyzeFrequencies()

        #expect(model.lastFailure == nil)
        #expect(model.lastNGramFrequencies?.rows.isEmpty == true)
        #expect(model.lastNGramFrequencies?.isTruncated == false)
        #expect(model.frequencyPage == 0)
        #expect(model.frequencyPageCount == 0)
        #expect(model.frequencyRowsOnPage.isEmpty)
    }

    @Test func mtldPreservesFiniteInfiniteAndMissingValuesAndSelectedScope() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let projectURL = root.appending(path: "MTLD.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: projectURL, needsPackageInitialization: true)
        _ = try await importTexts(
            ["sole sole sole sole", "sole luna mare", "..."], into: model, in: root)
        model.mtldThreshold = 0.5

        await model.analyzeMTLD()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastLexicalDiversity)
        let options = try #require(model.lastMTLDOptions)
        #expect(result.threshold == 0.5)
        #expect(result.documents.count == 3)
        #expect(result.documents.contains { $0.mtld?.value == .positiveInfinity })
        #expect(
            result.documents.contains {
                guard let value = $0.mtld?.value else { return false }
                if case .finite = value { return true }
                return false
            })
        let missing = try #require(result.documents.first { $0.mtld == nil })
        let reference = try await GlifiStudioService().openProject(at: projectURL)
        let expected = try await reference.analyzeLexicalDiversity(
            sourceRevisionIDs: options.sourceRevisionIDs, threshold: 0.5)
        #expect(result.documents == expected.documents)
        #expect(result.pooled == expected.pooled)
        #expect(result.sequencePolicy == expected.sequencePolicy)
        #expect(result.lineage.artifactID == expected.lineage.artifactID)
        await reference.close()
        let generation = model.snapshot?.generation

        await model.analyzeMTLD()

        #expect(model.snapshot?.generation == generation)
        #expect(model.lastLexicalDiversity?.lineage.artifactID == result.lineage.artifactID)
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = [missing.sourceRevisionID]

        await model.analyzeMTLD()

        #expect(model.lastFailure == nil)
        #expect(model.lastLexicalDiversity?.documents.count == 1)
        #expect(model.lastLexicalDiversity?.pooled == nil)
        #expect(model.lastMTLDOptions?.sourceRevisionIDs == [missing.sourceRevisionID])
    }

    @Test func lexicalFailuresPreserveResultsAndChangingProjectsClearsTheLaboratory() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "LexicalFailure.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        await model.analyzeFrequencies()
        await model.analyzeMTLD()
        let frequencies = try #require(model.lastNGramFrequencies)
        let frequencyOptions = model.lastFrequencyOptions
        let diversity = try #require(model.lastLexicalDiversity)
        let mtldOptions = model.lastMTLDOptions
        let snapshot = model.snapshot
        model.frequencyUnit = .words
        model.frequencyN = 0

        await model.analyzeFrequencies()

        #expect(model.lastFailure?.code == "ngrams.invalid-size")
        #expect(model.frequencyN == 0)
        #expect(model.lastNGramFrequencies == frequencies)
        #expect(model.lastFrequencyOptions == frequencyOptions)
        model.frequencyN = 2
        model.frequencyMinimumCount = 0

        await model.analyzeFrequencies()

        #expect(model.lastFailure?.code == "ngrams.invalid-filter")
        #expect(model.frequencyMinimumCount == 0)
        #expect(model.lastNGramFrequencies == frequencies)
        model.mtldThreshold = .nan

        await model.analyzeMTLD()

        #expect(model.lastFailure?.code == "diversity.invalid-threshold")
        #expect(model.mtldThreshold.isNaN)
        #expect(model.lastLexicalDiversity == diversity)
        #expect(model.lastMTLDOptions == mtldOptions)
        #expect(model.snapshot == snapshot)
        #expect(!model.isBusy)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)

        await model.attachDocument(
            at: root.appending(path: "FreshLexical.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.lastNGramFrequencies == nil)
        #expect(model.lastFrequencyOptions == nil)
        #expect(model.frequencyPageCount == 0)
        #expect(model.frequencyPage == 0)
        #expect(model.lastLexicalDiversity == nil)
        #expect(model.lastMTLDOptions == nil)
        #expect(model.selectedTextAnalysisSourceRevisionIDs.isEmpty)
    }

    @Test func exportPreviewPreservesUnicodeAndAcceptsOnlyTheCompleteBoundedFile() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "report.md")
        let original = "\u{FEFF}# Relazione\n\nUna città, un caffè e una prova 👩🏽‍💻."
        try Data(original.utf8).write(to: source)

        #expect(await StudioHomeModel.loadExportPreview(at: source) == original)

        try Data(repeating: 0x61, count: 1_048_576).write(to: source)
        let exact = await StudioHomeModel.loadExportPreview(at: source)
        #expect(exact?.utf8.count == 1_048_576)
        try Data(repeating: 0x61, count: 1_048_577).write(to: source)

        #expect(await StudioHomeModel.loadExportPreview(at: source) == nil)
    }

    @Test func exportPreviewRejectsInvalidAndSpecialFilesWithoutBlocking() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let missing = root.appending(path: "missing.md")
        #expect(await StudioHomeModel.loadExportPreview(at: missing) == nil)
        #expect(await StudioHomeModel.loadExportPreview(at: root) == nil)
        let invalid = root.appending(path: "invalid.md")
        try Data([0xFF]).write(to: invalid)
        #expect(await StudioHomeModel.loadExportPreview(at: invalid) == nil)
        let regular = root.appending(path: "regular.md")
        try Data("An authoritative report.".utf8).write(to: regular)
        let link = root.appending(path: "link.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: regular)
        #expect(await StudioHomeModel.loadExportPreview(at: link) == nil)
        let fifo = root.appending(path: "pipe.md")
        try #require(mkfifo(fifo.path, 0o600) == 0)
        #expect(await StudioHomeModel.loadExportPreview(at: fifo) == nil)
        let remote = try #require(URL(string: "https://example.invalid/report.md"))
        #expect(await StudioHomeModel.loadExportPreview(at: remote) == nil)
    }

    @Test func aPreCancelledExportPreviewReturnsNoContent() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "report.md")
        try Data("A complete report.".utf8).write(to: source)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await StudioHomeModel.loadExportPreview(at: source)
        }

        #expect(await cancelled.value == nil)
    }

    @Test func anExportKeepsItsReceiptAndDisplaysTheExactCommittedMarkdown() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Export.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        await model.executePlan()
        await model.createInvestigationFromExecution()
        _ = try #require(model.investigation)
        let destination = root.appending(path: "Report.glifiexport", directoryHint: .isDirectory)

        await model.exportInvestigation(to: destination)

        #expect(model.lastFailure == nil)
        let receipt = try #require(model.exportReceipt)
        #expect(receipt.reportRevisionID.hasPrefix("report-revision:sha256:"))
        #expect(receipt.manifestDigest.hasPrefix("sha256:"))
        let bytes = try Data(contentsOf: destination.appending(path: "report.md"))
        let report = try #require(String(validating: bytes, as: UTF8.self))
        #expect(model.exportPreviewMarkdown == report)
        #expect(!model.isBusy)
    }

    @Test(arguments: StudioDirectAnalysis.allCases)
    func directAnalysisCancellationRetainsOwnershipResultsAndRetry(
        analysis: StudioDirectAnalysis
    ) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "DirectCancellation.glifi"), needsPackageInitialization: true)
        let sources = try await importTexts(
            ["sole sole luna", "luna mare mare"], into: model, in: root)
        model.bm25QueryDraft = "sole"
        model.selectedTargetRevisionIDs = [try #require(sources.first?.sourceRevisionID)]
        model.selectedReferenceRevisionIDs = [try #require(sources.last?.sourceRevisionID)]
        await runDirectAnalysis(analysis, on: model)
        #expect(model.lastFailure == nil)
        let previousSnapshot = model.snapshot
        let summary = model.lastExtractiveSummary
        let ranking = model.lastBM25Ranking
        let frequencies = model.lastNGramFrequencies
        let diversity = model.lastLexicalDiversity
        let lexicalLaws = model.lastLexicalLaws
        let corpus = model.lastCorpusAnalysis
        let keyness = model.lastKeyness
        let observation = ExecutionCancellationObservation()
        _ = withObservationTracking(options: .didSet) {
            model.canCancelAnalysis
        } onChange: { event in
            guard event.kind == .didSet else { return }
            event.cancel()
            MainActor.assumeIsolated {
                observation.observed = true
                #expect(model.canCancelAnalysis)
                #expect(model.isBusy)
                model.cancelAnalysis()
                model.cancelAnalysis()
                #expect(model.canCancelAnalysis)
                #expect(model.isBusy)
            }
        }

        await runDirectAnalysis(analysis, on: model)

        #expect(observation.observed)
        #expect(model.lastFailure?.code == "operation.cancelled")
        #expect(model.lastFailure?.category == "cancelled")
        #expect(model.lastFailure?.retryDisposition == "newRequest")
        #expect(model.lastFailure?.retainedState == "lastCommittedGeneration")
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
        #expect(model.snapshot == previousSnapshot)
        #expect(model.lastExtractiveSummary == summary)
        #expect(model.lastBM25Ranking == ranking)
        #expect(model.lastNGramFrequencies == frequencies)
        #expect(model.lastLexicalDiversity == diversity)
        #expect(model.lastLexicalLaws == lexicalLaws)
        #expect(model.lastCorpusAnalysis == corpus)
        #expect(model.lastKeyness == keyness)

        await runDirectAnalysis(analysis, on: model)

        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
    }

    @Test func directAnalysisPropagatesCallerCancellationAndPreservesThePreviousResult()
        async throws
    {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "CallerCancellation.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        await model.summarizeSources()
        let previous = try #require(model.lastExtractiveSummary)
        let previousSnapshot = model.snapshot
        let observation = ExecutionCancellationObservation()
        _ = withObservationTracking(options: .didSet) {
            model.isBusy
        } onChange: { event in
            guard event.kind == .didSet else { return }
            event.cancel()
            MainActor.assumeIsolated {
                observation.observed = true
                // Admission runs in the caller before task creation and cancellation registration.
                withUnsafeCurrentTask { $0?.cancel() }
                #expect(model.isBusy)
            }
        }
        let caller = Task { await model.summarizeSources() }

        await caller.value

        #expect(observation.observed)
        #expect(caller.isCancelled)
        #expect(model.lastFailure?.code == "operation.cancelled")
        #expect(model.lastExtractiveSummary == previous)
        #expect(model.snapshot == previousSnapshot)
        #expect(!model.canCancelAnalysis)
        #expect(!model.isBusy)

        await model.summarizeSources()

        #expect(model.lastFailure == nil)
        #expect(!model.canCancelAnalysis)
        #expect(!model.isBusy)
    }

    @Test func lateAnalysisCancellationKeepsTheCommittedResultAndExistingExport() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "LateCancellation.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        await model.executePlan()
        await model.createInvestigationFromExecution()
        await model.exportInvestigation(
            to: root.appending(path: "Export.glifiexport", directoryHint: .isDirectory))
        let receipt = try #require(model.exportReceipt)
        let preview = model.exportPreviewMarkdown
        let previousGeneration = try #require(model.snapshot?.generation)
        model.bm25QueryDraft = "fonte"
        let observation = ExecutionCancellationObservation()
        _ = withObservationTracking(options: .didSet) {
            model.lastBM25Ranking
        } onChange: { event in
            guard event.kind == .didSet else { return }
            event.cancel()
            MainActor.assumeIsolated {
                observation.observed = true
                #expect(model.lastBM25Ranking != nil)
                #expect(model.canCancelAnalysis)
                model.cancelAnalysis()
                model.cancelAnalysis()
                #expect(model.canCancelAnalysis)
                #expect(model.isBusy)
            }
        }

        await model.rankSourcesBM25()

        #expect(observation.observed)
        #expect(model.lastFailure == nil)
        let result = try #require(model.lastBM25Ranking)
        let snapshot = try #require(model.snapshot)
        #expect(snapshot.generation > previousGeneration)
        #expect(snapshot.generation == result.lineage.generation)
        #expect(model.lastBM25Options?.query == "fonte")
        #expect(model.exportReceipt == receipt)
        #expect(model.exportPreviewMarkdown == preview)
        #expect(!model.canCancelAnalysis)
        #expect(!model.isBusy)
    }

    @Test func aDocumentAttachmentRequestedWhileBusyCompletesAfterTheOwnedOperation() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        let originalURL = root.appending(path: "Original.glifi")
        await model.attachDocument(at: originalURL, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        _ = try #require(model.lastProjectBookmark)
        let requestedURL = root.appending(path: "Requested.glifi")
        let candidate = try await GlifiStudioService().createProject(at: requestedURL)
        let requestedID = try await candidate.snapshot().projectID
        await candidate.close()
        let gate = DocumentAttachmentTestGate()
        let opened = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let opening = Task { @MainActor in
            await model.reopenLastProject(using: { _ in
                await gate.hold(entered: opened.continuation)
            })
            opened.continuation.finish()
        }
        defer {
            gate.release()
            opening.cancel()
        }
        var openEvents = opened.stream.makeAsyncIterator()
        try #require(await openEvents.next() == true)
        let requested = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let attaching = Task { @MainActor in
            requested.continuation.yield(true)
            await model.attachDocument(at: requestedURL, needsPackageInitialization: false)
            requested.continuation.finish()
        }
        defer { attaching.cancel() }
        var requestEvents = requested.stream.makeAsyncIterator()
        try #require(await requestEvents.next() == true)
        #expect(model.isBusy)
        #expect(model.projectURL == originalURL)

        gate.release()
        await opening.value
        await attaching.value

        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
        #expect(model.projectURL == requestedURL)
        #expect(model.snapshot?.projectID == requestedID)
    }

    @Test func theLatestWaitingAttachmentSurvivesCancellationOfOlderRequests() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Current.glifi"), needsPackageInitialization: true)
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }
        let obsoleteURL = root.appending(path: "Obsolete.glifi")
        let latestURL = root.appending(path: "Latest.glifi")
        let cancelledURL = root.appending(path: "PreCancelled.glifi")
        let obsolete = try await beginDocumentAttachment(model, at: obsoleteURL, initialize: true)
        defer { obsolete.cancel() }
        let latest = try await beginDocumentAttachment(model, at: latestURL, initialize: true)
        defer { latest.cancel() }
        obsolete.cancel()
        let preCancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await model.attachDocument(at: cancelledURL, needsPackageInitialization: true)
        }
        await preCancelled.value
        #expect(model.isBusy)
        #expect(!FileManager.default.fileExists(atPath: latestURL.path))

        gate.release()
        await opening.value
        await obsolete.value
        await latest.value

        #expect(model.lastFailure == nil)
        #expect(model.projectURL == latestURL)
        #expect(model.snapshot != nil)
        #expect(!FileManager.default.fileExists(atPath: obsoleteURL.path))
        #expect(!FileManager.default.fileExists(atPath: cancelledURL.path))
        #expect(!model.isBusy)
    }

    @Test func cancellingAWaitingAttachmentCreatesNoPackageAndAllowsRetry() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        let originalURL = root.appending(path: "Current.glifi")
        await model.attachDocument(at: originalURL, needsPackageInitialization: true)
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }
        let requestedURL = root.appending(path: "Cancelled.glifi")
        let attaching = try await beginDocumentAttachment(model, at: requestedURL, initialize: true)

        attaching.cancel()
        await attaching.value

        #expect(model.isBusy)
        #expect(model.projectURL == originalURL)
        #expect(model.lastFailure == nil)
        #expect(!FileManager.default.fileExists(atPath: requestedURL.path))
        gate.release()
        await opening.value

        await model.attachDocument(at: requestedURL, needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.projectURL == requestedURL)
        #expect(model.snapshot?.generation == 0)
        #expect(!model.isBusy)
    }

    @Test func returningToTheCurrentDocumentSupersedesAnIntermediateAttachment() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        let originalURL = root.appending(path: "Current.glifi")
        await model.attachDocument(at: originalURL, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let snapshot = model.snapshot
        let query = model.queryResult
        let profile = model.lastProfile
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }
        let intermediateURL = root.appending(path: "Intermediate.glifi")
        let intermediate = try await beginDocumentAttachment(
            model, at: intermediateURL, initialize: true)
        defer { intermediate.cancel() }

        await model.attachDocument(at: originalURL, needsPackageInitialization: false)
        await intermediate.value

        #expect(model.isBusy)
        #expect(model.projectURL == originalURL)
        gate.release()
        await opening.value
        #expect(model.lastFailure == nil)
        #expect(model.snapshot == snapshot)
        #expect(model.queryResult == query)
        #expect(model.lastProfile == profile)
        #expect(!FileManager.default.fileExists(atPath: intermediateURL.path))
    }

    @Test func aFailedDeferredAttachmentPreservesThePreviousUsableSession() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        let originalURL = root.appending(path: "Current.glifi")
        await model.attachDocument(at: originalURL, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let snapshot = model.snapshot
        let profile = model.lastProfile
        let query = model.queryResult
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }
        let attaching = try await beginDocumentAttachment(
            model, at: root.appending(path: "Missing.glifi"), initialize: false)

        gate.release()
        await opening.value
        await attaching.value

        #expect(model.lastFailure != nil)
        #expect(model.projectURL == originalURL)
        #expect(model.snapshot == snapshot)
        #expect(model.lastProfile == profile)
        #expect(model.queryResult == query)
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func closingWaitsForOwnedWorkAndDiscardsWaitingAttachmentsBeforeReopening() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Closing.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let gate = DocumentAttachmentTestGate()
        let entered = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        var cancellationObserved = false
        let opening = Task { @MainActor in
            await model.reopenLastProject(using: { _ in
                await gate.hold(entered: entered.continuation)
                cancellationObserved = Task.isCancelled
            })
            entered.continuation.finish()
        }
        defer {
            gate.release()
            opening.cancel()
        }
        var events = entered.stream.makeAsyncIterator()
        try #require(await events.next() == true)
        let waitingURL = root.appending(path: "MustNotOpen.glifi")
        let attaching = try await beginDocumentAttachment(model, at: waitingURL, initialize: true)
        defer { attaching.cancel() }

        let closing = Task.immediate { @MainActor in await model.closeProject() }
        #expect(model.isBusy)
        #expect(model.snapshot != nil)
        gate.release()
        await closing.value
        await opening.value
        await attaching.value

        #expect(cancellationObserved)
        #expect(!model.isBusy)
        #expect(model.projectURL == nil)
        #expect(model.snapshot == nil)
        #expect(model.lastProfile == nil)
        #expect(model.lastFailure == nil)
        #expect(!FileManager.default.fileExists(atPath: waitingURL.path))
        await model.closeProject()
        let reopenedURL = root.appending(path: "Reopened.glifi")
        await model.attachDocument(at: reopenedURL, needsPackageInitialization: true)
        #expect(model.projectURL == reopenedURL)
        #expect(model.snapshot?.generation == 0)
        #expect(model.lastFailure == nil)
    }

    @Test func reattachmentDuringRepeatedTeardownWaitsForItsTerminalState() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Previous.glifi"), needsPackageInitialization: true)
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }
        let closing = Task.immediate { @MainActor in await model.closeProject() }
        let repeated = Task.immediate { @MainActor in await model.closeProject() }
        let destination = root.appending(path: "Reattached.glifi")
        let attaching = try await beginDocumentAttachment(model, at: destination, initialize: true)
        defer { attaching.cancel() }
        #expect(model.isBusy)
        #expect(!FileManager.default.fileExists(atPath: destination.path))

        gate.release()
        await opening.value
        await closing.value
        await repeated.value
        await attaching.value

        #expect(model.projectURL == destination)
        #expect(model.snapshot?.generation == 0)
        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
    }

    @Test func completedTeardownReleasesTheOperationOwner() async {
        var model: StudioHomeModel? = StudioHomeModel()
        weak let releasedModel = model
        await model?.runCoreAnalysis {}
        await model?.closeProject()
        model = nil
        #expect(releasedModel == nil)
    }

    @Test func documentAttachmentWaitsAcrossDistinctTeardownGenerations() async throws {
        for cancelsAdmission in [false, true] {
            let firstGate = DocumentAttachmentTestGate()
            let secondGate = DocumentAttachmentTestGate()
            let thirdGate = DocumentAttachmentTestGate()
            let entered = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(3))
            var secondFinished = false
            let first = Task.immediate { @MainActor in
                await firstGate.hold(entered: entered.continuation)
            }
            let second = Task.immediate { @MainActor in
                await secondGate.hold(entered: entered.continuation)
                secondFinished = true
            }
            let third = Task.immediate { @MainActor in
                await thirdGate.hold(entered: entered.continuation)
            }
            defer {
                firstGate.release()
                secondGate.release()
                thirdGate.release()
                first.cancel()
                second.cancel()
                third.cancel()
                entered.continuation.finish()
            }
            var entering = entered.stream.makeAsyncIterator()
            for _ in 0..<3 { try #require(await entering.next() == true) }
            let observed = AsyncStream<Int>.makeStream(bufferingPolicy: .bufferingNewest(8))
            var current: Task<Void, Never>? = first
            var generation = 1
            var admissionCount = 0
            var admitted: Bool?
            let waiting = Task.immediate { @MainActor in
                admitted = await studioAdmitAfterLatestOwnedTask(
                    current: {
                        if current != nil { observed.continuation.yield(generation) }
                        return current
                    },
                    admission: {
                        #expect(secondFinished, "Admission preceded completion of the latest task")
                        admissionCount += 1
                        return true
                    })
                observed.continuation.yield(0)
            }
            defer {
                current = nil
                waiting.cancel()
                observed.continuation.finish()
            }
            var observations = observed.stream.makeAsyncIterator()
            try #require(await observations.next() == 1)
            current = second
            generation = 2
            firstGate.release()
            try #require(await observations.next() == 2, "The latest task was not awaited")
            #expect(admissionCount == 0)
            #expect(!secondFinished)

            if cancelsAdmission {
                current = third
                generation = 3
                waiting.cancel()
            } else {
                current = nil
            }
            secondGate.release()
            #expect(await observations.next() == 0, "Cancellation waited for another generation")
            current = nil
            thirdGate.release()
            await waiting.value
            await first.value
            await second.value
            await third.value

            #expect(admissionCount == (cancelsAdmission ? 0 : 1))
            #expect(admitted == (cancelsAdmission ? nil : true))
        }
    }

    private func beginSuspendedReopening(_ model: StudioHomeModel) async throws -> (
        DocumentAttachmentTestGate, Task<Void, Never>
    ) {
        _ = try #require(model.lastProjectBookmark)
        let gate = DocumentAttachmentTestGate()
        let entered = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let opening = Task { @MainActor in
            await model.reopenLastProject(using: { _ in
                await gate.hold(entered: entered.continuation)
            })
            entered.continuation.finish()
        }
        var events = entered.stream.makeAsyncIterator()
        do {
            try #require(await events.next() == true)
        } catch {
            gate.release()
            opening.cancel()
            throw error
        }
        return (gate, opening)
    }

    private func beginDocumentAttachment(
        _ model: StudioHomeModel, at url: URL, initialize: Bool
    ) async throws -> Task<Void, Never> {
        let entered = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let attaching = Task { @MainActor in
            entered.continuation.yield(true)
            await model.attachDocument(at: url, needsPackageInitialization: initialize)
            entered.continuation.finish()
        }
        var events = entered.stream.makeAsyncIterator()
        try #require(await events.next() == true)
        return attaching
    }

    private func runDirectAnalysis(_ analysis: StudioDirectAnalysis, on model: StudioHomeModel)
        async
    {
        switch analysis {
        case .summary: await model.summarizeSources()
        case .bm25: await model.rankSourcesBM25()
        case .frequencies: await model.analyzeFrequencies()
        case .mtld: await model.analyzeMTLD()
        case .lexicalLaws: await model.analyzeLexicalLaws()
        case .corpus: await model.analyzeCorpusNow()
        case .keyness: await model.compareKeynessNow()
        }
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudioMacTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func importSource(into model: StudioHomeModel, in root: URL) async throws {
        let source = root.appending(path: "source.txt")
        try Data("Una fonte italiana affidabile.".utf8).write(to: source)
        await model.importSource(at: source)
        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.sourceCount == 1)
    }

    private func importTexts(
        _ texts: [String], into model: StudioHomeModel, in root: URL
    ) async throws -> [GlifiStudioProjectSource] {
        let urls = try texts.enumerated().map { index, text in
            let url = root.appending(path: "fixture-\(index).txt")
            try Data(text.utf8).write(to: url)
            return url
        }
        await model.importSources(at: urls)
        #expect(model.lastFailure == nil)
        return try #require(model.snapshot?.sources)
    }
}

@MainActor
private final class ExecutionCancellationObservation {
    var operationID: String?
    var observed = false
}

@MainActor
private final class DocumentAttachmentTestGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func hold(entered: AsyncStream<Bool>.Continuation) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            entered.yield(true)
        }
    }

    func release() {
        let waiting = continuation
        continuation = nil
        waiting?.resume()
    }
}

enum StudioDirectAnalysis: CaseIterable, Sendable {
    case summary
    case bm25
    case frequencies
    case mtld
    case lexicalLaws
    case corpus
    case keyness
}
