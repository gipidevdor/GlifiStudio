// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation
import Testing

@MainActor
struct StudioTermWeightingTests {
    @Test(arguments: StudioWeightingCase.combinations)
    func preservesEverySchemeAndMatchesTheKitResult(configuration: StudioWeightingCase)
        async throws
    {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        let url = root.appending(path: "Weights.glifi")
        await model.attachDocument(at: url, needsPackageInitialization: true)
        let sources = try await importTexts(
            ["città città mare comune", "mare sole comune", "!!!"], into: model, in: root)
        #expect(model.termFrequencyVariant == .raw)
        #expect(model.inverseDocumentFrequencyVariant == .smooth)
        #expect(model.termWeightingNormalization == .none)
        model.termFrequencyVariant = configuration.tf
        model.inverseDocumentFrequencyVariant = configuration.idf
        model.termWeightingNormalization = configuration.normalization

        await model.analyzeTermWeights()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastTermWeighting)
        let options = try #require(model.lastTermWeightingOptions)
        let scheme = configuration.expectedScheme
        let ids = sources.map(\.sourceRevisionID).sorted()
        #expect(options.scope == .allSources)
        #expect(options.sourceRevisionIDs == ids)
        #expect(options.scheme == scheme)
        #expect(options.corpusOptions == .standard)
        let direct = try await GlifiStudioService().openProject(at: url)
        let reference = try await direct.analyzeTermWeighting(
            sourceRevisionIDs: ids, scheme: scheme)
        await direct.close()
        #expect(result.analysisIdentifier == reference.analysisIdentifier)
        #expect(result.scheme == reference.scheme)
        #expect(result.combinedIdentifier == reference.combinedIdentifier)
        #expect(result.sourceRevisionIDs == reference.sourceRevisionIDs)
        #expect(result.terms == reference.terms)
        #expect(result.documentFrequencies == reference.documentFrequencies)
        #expect(result.cells == reference.cells)
        #expect(result.cells.allSatisfy { $0.count > 0 })
        let secondRow = try #require(
            result.sourceRevisionIDs.firstIndex(of: sources[1].sourceRevisionID))
        let cityColumn = try #require(result.terms.firstIndex(of: "città"))
        #expect(!result.cells.contains { $0.rowIndex == secondRow && $0.columnIndex == cityColumn })
        #expect(result.lineage.artifactID == reference.lineage.artifactID)
        #expect(result.lineage.analysisNodeID == reference.lineage.analysisNodeID)
        #expect(result.lineage.generation == model.snapshot?.generation)
        let counts = model.termWeightingObservedCellCounts
        #expect(counts.count == ids.count)
        for (row, id) in ids.enumerated() {
            #expect(counts[row] == result.cells.filter { $0.rowIndex == row }.count)
            if id == sources[2].sourceRevisionID { #expect(counts[row] == 0) }
        }
        model.termFrequencyVariant = .binary
        model.inverseDocumentFrequencyVariant = .none
        model.termWeightingNormalization = .l1
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = [sources[0].sourceRevisionID]
        #expect(model.lastTermWeightingOptions == options)
        #expect(model.lastTermWeighting == result)
        model.termFrequencyVariant = configuration.tf
        model.inverseDocumentFrequencyVariant = configuration.idf
        model.termWeightingNormalization = configuration.normalization
        model.textAnalysisScope = .allSources
        let generation = model.snapshot?.generation

        await model.analyzeTermWeights()

        #expect(model.lastFailure == nil)
        #expect(model.lastTermWeighting?.lineage.artifactID == result.lineage.artifactID)
        #expect(model.snapshot?.generation == generation)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
    }

    @Test func visitsEveryCellAndVocabularyPageInTheKitOrder() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Pages.glifi"), needsPackageInitialization: true)
        let words = (0..<120).map(word)
        _ = try await importTexts(
            [words.joined(separator: " "), words[0], "!!!"], into: model, in: root)
        await model.analyzeTermWeights()
        let result = try #require(model.lastTermWeighting)
        #expect(result.terms.count == 120)
        #expect(result.cells.count == 121)
        #expect(model.termWeightingCellPageSize == 50)
        #expect(model.termWeightingTermPageSize == 50)
        #expect(model.termWeightingCellPageCount == 3)
        #expect(model.termWeightingTermPageCount == 3)
        var cells: [GlifiStudioWeightedTermCell] = []
        var indices: [Int] = []
        for page in 0..<model.termWeightingCellPageCount {
            model.showTermWeightingCellPage(page)
            cells.append(contentsOf: model.cellsOnTermWeightingPage)
        }
        for page in 0..<model.termWeightingTermPageCount {
            model.showTermWeightingTermPage(page)
            indices.append(contentsOf: model.termIndicesOnWeightingPage)
        }
        #expect(cells == result.cells)
        #expect(indices == Array(result.terms.indices))
        #expect(model.termWeightingObservedCellCounts.reduce(0, +) == result.cells.count)
        model.showTermWeightingCellPage(-1)
        model.showTermWeightingCellPage(Int.max)
        model.showTermWeightingTermPage(-1)
        model.showTermWeightingTermPage(Int.max)
        #expect(model.termWeightingCellPage == 2)
        #expect(model.termWeightingTermPage == 2)
        #expect(model.cellsOnTermWeightingPage.count == 21)
        #expect(model.termIndicesOnWeightingPage.count == 20)
        model.showTermWeightingCellPage(0)
        model.showTermWeightingTermPage(0)
        #expect(model.cellsOnTermWeightingPage == Array(result.cells.prefix(50)))
        #expect(model.termIndicesOnWeightingPage == Array(0..<50))

        await model.analyzeTermWeights()

        #expect(model.termWeightingCellPage == 0)
        #expect(model.termWeightingTermPage == 0)
    }

    @Test func distinguishesObservedZeroWeightsFromAbsentCellsAndEmptyVocabulary() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Zeros.glifi"), needsPackageInitialization: true)
        let sources = try await importTexts(
            ["comune comune", "comune", "!!!"], into: model, in: root)
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = Set(sources.prefix(2).map(\.sourceRevisionID))
        model.inverseDocumentFrequencyVariant = .unsmoothed
        model.termWeightingNormalization = .l2

        await model.analyzeTermWeights()

        #expect(model.lastFailure == nil)
        let zeroWeights = try #require(model.lastTermWeighting)
        #expect(zeroWeights.terms == ["comune"])
        #expect(zeroWeights.documentFrequencies == [2])
        #expect(zeroWeights.cells.count == 2)
        #expect(zeroWeights.cells.allSatisfy { $0.count > 0 && $0.weight == 0 })
        #expect(model.termWeightingObservedCellCounts == [1, 1])
        model.selectedTextAnalysisSourceRevisionIDs = [sources[0].sourceRevisionID]
        await model.analyzeTermWeights()
        #expect(model.lastTermWeighting?.documentFrequencies == [1])
        #expect(model.lastTermWeighting?.cells.first?.weight == 0)
        model.selectedTextAnalysisSourceRevisionIDs = [sources[2].sourceRevisionID]

        await model.analyzeTermWeights()

        #expect(model.lastFailure == nil)
        let empty = try #require(model.lastTermWeighting)
        #expect(empty.sourceRevisionIDs == [sources[2].sourceRevisionID])
        #expect(empty.terms.isEmpty)
        #expect(empty.documentFrequencies.isEmpty)
        #expect(empty.cells.isEmpty)
        #expect(model.termWeightingObservedCellCounts == [0])
        #expect(model.termWeightingCellPageCount == 0)
        #expect(model.termWeightingTermPageCount == 0)
        #expect(model.cellsOnTermWeightingPage.isEmpty)
        #expect(model.termIndicesOnWeightingPage.isEmpty)
    }

    @Test func preservesTheEffectiveResultOnFailureAndClearsItForANewProject() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.analyzeTermWeights()
        #expect(model.lastFailure != nil)
        #expect(model.lastTermWeighting == nil)
        await model.attachDocument(
            at: root.appending(path: "Selected.glifi"), needsPackageInitialization: true)
        let sources = try await importTexts(
            ["città città mare", "sole sole"], into: model, in: root)
        model.textAnalysisScope = .selectedSources
        model.selectedTextAnalysisSourceRevisionIDs = [sources[0].sourceRevisionID]
        await model.analyzeTermWeights()
        let result = try #require(model.lastTermWeighting)
        let options = try #require(model.lastTermWeightingOptions)
        let snapshot = model.snapshot
        let counts = model.termWeightingObservedCellCounts
        #expect(result.sourceRevisionIDs == [sources[0].sourceRevisionID])
        #expect(Set(result.terms) == ["città", "mare"])
        model.selectedTextAnalysisSourceRevisionIDs = []

        await model.analyzeTermWeights()

        #expect(model.lastFailure?.code == "weighting.insufficient-sources")
        #expect(model.lastTermWeighting == result)
        #expect(model.lastTermWeightingOptions == options)
        #expect(model.termWeightingObservedCellCounts == counts)
        #expect(model.snapshot == snapshot)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
        model.termFrequencyVariant = .augmented
        model.inverseDocumentFrequencyVariant = .unsmoothed
        model.termWeightingNormalization = .l2

        await model.attachDocument(
            at: root.appending(path: "Fresh.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.lastTermWeighting == nil)
        #expect(model.lastTermWeightingOptions == nil)
        #expect(model.termWeightingObservedCellCounts.isEmpty)
        #expect(model.termWeightingCellPage == 0)
        #expect(model.termWeightingTermPage == 0)
        #expect(model.termFrequencyVariant == .raw)
        #expect(model.inverseDocumentFrequencyVariant == .smooth)
        #expect(model.termWeightingNormalization == .none)
        #expect(model.textAnalysisScope == .allSources)
        #expect(model.selectedTextAnalysisSourceRevisionIDs.isEmpty)
    }

    @Test func cancellationRetainsOwnershipAndThePreviousWeightsUntilTheTerminalResult()
        async throws
    {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Cancelled.glifi"), needsPackageInitialization: true)
        _ = try await importTexts(["città città mare"], into: model, in: root)
        await model.analyzeTermWeights()
        let previous = try #require(model.lastTermWeighting)
        let options = model.lastTermWeightingOptions
        let counts = model.termWeightingObservedCellCounts
        let snapshot = model.snapshot
        let observation = WeightingCancellationObservation()
        _ = withObservationTracking(options: .didSet) {
            model.canCancelAnalysis
        } onChange: { event in
            guard event.kind == .didSet else { return }
            event.cancel()
            MainActor.assumeIsolated {
                observation.observed = true
                #expect(model.isBusy)
                #expect(model.canCancelAnalysis)
                model.cancelAnalysis()
                model.cancelAnalysis()
                #expect(model.isBusy)
                #expect(model.canCancelAnalysis)
            }
        }
        model.termFrequencyVariant = .binary

        await model.analyzeTermWeights()

        #expect(observation.observed)
        #expect(model.lastFailure?.code == "operation.cancelled")
        #expect(model.lastTermWeighting == previous)
        #expect(model.lastTermWeightingOptions == options)
        #expect(model.termWeightingObservedCellCounts == counts)
        #expect(model.snapshot == snapshot)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)

        await model.analyzeTermWeights()

        #expect(model.lastFailure == nil)
        #expect(model.lastTermWeightingOptions?.scheme.termFrequency == "TF-binary-v1")
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
    }

    @Test(arguments: StudioMalformedWeighting.allCases)
    func rejectsMalformedMatricesBeforePublishingPresentationState(
        mutation: StudioMalformedWeighting
    ) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Malformed.glifi"), needsPackageInitialization: true)
        _ = try await importTexts(["città città mare", "mare sole"], into: model, in: root)
        await model.analyzeTermWeights()
        let previous = try #require(model.lastTermWeighting)
        let options = try #require(model.lastTermWeightingOptions)
        let snapshot = model.snapshot
        let counts = model.termWeightingObservedCellCounts
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(previous)) as? [String: Any])
        var cells = try #require(object["cells"] as? [[String: Any]])
        var terms = try #require(object["terms"] as? [String])
        var frequencies = try #require(object["documentFrequencies"] as? [Int])
        try #require(cells.count == 4)
        try #require(terms.count == 3)
        try #require(frequencies.count == 3)
        switch mutation {
        case .negativeRow: cells[0]["rowIndex"] = -1
        case .outOfBoundsRow: cells[0]["rowIndex"] = Int.max
        case .negativeColumn: cells[0]["columnIndex"] = -1
        case .outOfBoundsColumn: cells[0]["columnIndex"] = Int.max
        case .shortDocumentFrequencies: frequencies.removeLast()
        case .longDocumentFrequencies: frequencies.append(1)
        case .zeroDocumentFrequency: frequencies[0] = 0
        case .tooLargeDocumentFrequency: frequencies[0] = previous.sourceRevisionIDs.count + 1
        case .inconsistentDocumentFrequency:
            let shared = try #require(terms.firstIndex(of: "mare"))
            frequencies[shared] = 1
        case .duplicateCell: cells.insert(cells[0], at: 1)
        case .reversedCells: cells.reverse()
        case .zeroCount: cells[0]["count"] = 0
        case .negativeCount: cells[0]["count"] = -1
        case .negativeWeight: cells[0]["weight"] = -0.25
        case .duplicateTerm: terms[1] = terms[0]
        case .reversedTerms: terms.reverse()
        case .emptyTerm: terms[0] = ""
        case .mismatchedSources:
            object["sourceRevisionIDs"] = Array(previous.sourceRevisionIDs.reversed())
        case .mismatchedScheme:
            var scheme = try #require(object["scheme"] as? [String: Any])
            scheme["normalization"] = "RowNorm-L2-v1"
            object["scheme"] = scheme
        case .unobservedVocabularyTerm:
            cells.removeAll { ($0["columnIndex"] as? Int) == 0 }
        }
        object["cells"] = cells
        object["terms"] = terms
        object["documentFrequencies"] = frequencies
        let malformed = try JSONDecoder().decode(
            GlifiStudioTermWeightingResult.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))

        do {
            _ = try await StudioHomeModel.observedTermWeightingCellCounts(
                for: malformed, options: options)
            Issue.record("An inconsistent matrix must produce a typed failure before presentation.")
        } catch {
            #expect(error.code == "ui.weighting.invalid-result")
            #expect(error.category == "corruption")
            #expect(error.operation == "analyze")
            #expect(error.retryDisposition == "never")
            #expect(error.retainedState == "lastCommittedGeneration")
            #expect(error.messageKey == "failure.weighting.invalid-result")
        }

        #expect(model.lastTermWeighting == previous)
        #expect(model.lastTermWeightingOptions == options)
        #expect(model.termWeightingObservedCellCounts == counts)
        #expect(model.snapshot == snapshot)
        #expect(model.termWeightingCellPage == 0)
        #expect(model.termWeightingTermPage == 0)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudioWeightingTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func importTexts(
        _ texts: [String], into model: StudioHomeModel, in root: URL
    ) async throws -> [GlifiStudioProjectSource] {
        var sources: [GlifiStudioProjectSource] = []
        for (index, text) in texts.enumerated() {
            let file = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: file)
            let known = Set(model.snapshot?.sources.map(\.sourceRevisionID) ?? [])
            await model.importSource(at: file)
            #expect(model.lastFailure == nil)
            let added = try #require(
                model.snapshot?.sources.first { !known.contains($0.sourceRevisionID) })
            sources.append(added)
        }
        return sources
    }

    private func word(_ index: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        var value = index
        var suffix = ""
        repeat {
            suffix.append(alphabet[value % alphabet.count])
            value /= alphabet.count
        } while value > 0
        return "termine" + suffix
    }
}

nonisolated struct StudioWeightingCase: Sendable {
    let tf: StudioTermFrequencyVariant
    let idf: StudioInverseDocumentFrequencyVariant
    let normalization: StudioTermWeightingNormalization
    let expectedScheme: GlifiStudioTermWeightingScheme

    static var combinations: [Self] {
        var cases: [Self] = []
        let frequencies: [(StudioTermFrequencyVariant, String)] = [
            (.raw, "TF-raw-v1"), (.binary, "TF-binary-v1"), (.l1, "TF-L1-v1"),
            (.max, "TF-max-v1"), (.augmented, "TF-augmented-v1"), (.sublinear, "TF-sublinear-v1"),
        ]
        let inverseFrequencies: [(StudioInverseDocumentFrequencyVariant, String)] = [
            (.none, "IDF-none-v1"), (.unsmoothed, "IDF-unsmoothed-v1"), (.smooth, "IDF-smooth-v1"),
        ]
        let normalizations: [(StudioTermWeightingNormalization, String)] = [
            (.none, "RowNorm-none-v1"), (.l1, "RowNorm-L1-v1"), (.l2, "RowNorm-L2-v1"),
        ]
        for (tf, tfID) in frequencies {
            for (idf, idfID) in inverseFrequencies {
                for (normalization, normalizationID) in normalizations {
                    cases.append(
                        Self(
                            tf: tf, idf: idf, normalization: normalization,
                            expectedScheme: GlifiStudioTermWeightingScheme(
                                termFrequency: tfID, inverseDocumentFrequency: idfID,
                                normalization: normalizationID)))
                }
            }
        }
        return cases
    }
}

nonisolated enum StudioMalformedWeighting: CaseIterable, Sendable {
    case negativeRow
    case outOfBoundsRow
    case negativeColumn
    case outOfBoundsColumn
    case shortDocumentFrequencies
    case longDocumentFrequencies
    case zeroDocumentFrequency
    case tooLargeDocumentFrequency
    case inconsistentDocumentFrequency
    case duplicateCell
    case reversedCells
    case zeroCount
    case negativeCount
    case negativeWeight
    case duplicateTerm
    case reversedTerms
    case emptyTerm
    case mismatchedSources
    case mismatchedScheme
    case unobservedVocabularyTerm
}

@MainActor
private final class WeightingCancellationObservation {
    var observed = false
}
