// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation
import Testing

@MainActor
struct StudioKeynessTests {
    @Test(arguments: [0.8, 0.99, 1e-300])
    func preservesTheEffectiveRequestAndMatchesKit(confidence: Double) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        let url = root.appending(path: "Comparison.glifi")
        await model.attachDocument(at: url, needsPackageInitialization: true)
        let ids = try await importTexts(
            ["casa casa mare", "casa città città"], into: model, in: root)
        #expect(model.keynessMaximumHypothesisCount == 100_000)
        #expect(model.keynessLowExpectedCountThreshold == 5)
        #expect(model.keynessConfidenceLevel == 0.95)
        model.selectedTargetRevisionIDs = [ids[0]]
        model.selectedReferenceRevisionIDs = [ids[1]]
        model.keynessMaximumHypothesisCount = 20
        model.keynessLowExpectedCountThreshold = 0
        model.keynessConfidenceLevel = confidence

        await model.compareKeynessNow()

        #expect(model.lastFailure == nil)
        let result = try #require(model.lastKeyness)
        let request = try #require(model.lastKeynessRequestOptions)
        #expect(request.targetSourceRevisionIDs == [ids[0]])
        #expect(request.referenceSourceRevisionIDs == [ids[1]])
        #expect(request.corpusOptions == .standard)
        #expect(request.keynessOptions.maximumHypothesisCount == 20)
        #expect(request.keynessOptions.lowExpectedCountThreshold == 0)
        #expect(request.keynessOptions.confidenceLevel == confidence)
        #expect(model.lastKeynessOptions == request.keynessOptions)
        #expect(result.confidenceLevel == confidence)
        #expect(result.targetTokenCount == 3)
        #expect(result.referenceTokenCount == 3)
        #expect(result.targetSourceRevisionIDs == request.targetSourceRevisionIDs)
        #expect(result.referenceSourceRevisionIDs == request.referenceSourceRevisionIDs)
        #expect(result.terms.allSatisfy { !$0.hasLowExpectedCount })
        #expect(result.terms.allSatisfy { $0.selectedTestIdentifier == "FisherExactTwoSided-v1" })
        #expect(result.generation == model.snapshot?.generation)
        #expect(result.projectID == model.snapshot?.projectID)
        let direct = try await GlifiStudioService().openProject(at: url)
        let reference = try await direct.compareKeyness(
            targetSourceRevisionIDs: request.targetSourceRevisionIDs,
            referenceSourceRevisionIDs: request.referenceSourceRevisionIDs,
            corpusOptions: request.corpusOptions, keynessOptions: request.keynessOptions)
        await direct.close()
        #expect(try comparablePayload(result) == comparablePayload(reference))
        model.selectedTargetRevisionIDs = [ids[1]]
        model.selectedReferenceRevisionIDs = [ids[0]]
        model.keynessMaximumHypothesisCount = 1
        model.keynessLowExpectedCountThreshold = 100
        model.keynessConfidenceLevel = 0.9
        #expect(model.lastKeynessRequestOptions == request)
        #expect(model.lastKeyness == result)
        model.selectedTargetRevisionIDs = [ids[0]]
        model.selectedReferenceRevisionIDs = [ids[1]]
        model.keynessMaximumHypothesisCount = 20
        model.keynessLowExpectedCountThreshold = 0
        model.keynessConfidenceLevel = confidence
        let generation = model.snapshot?.generation

        await model.compareKeynessNow()

        #expect(model.lastFailure == nil)
        #expect(model.lastKeyness?.artifactID == result.artifactID)
        #expect(model.lastKeyness?.analysisNodeID == result.analysisNodeID)
        #expect(model.snapshot?.generation == generation)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
    }

    @Test func keepsFisherSelectionIndependentOfTheDiagnosticThreshold() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Selection.glifi"), needsPackageInitialization: true)
        let target =
            Array(repeating: "casa", count: 30) + ["raro"]
            + Array(repeating: "mare", count: 969)
        let reference =
            Array(repeating: "casa", count: 10)
            + Array(repeating: "mare", count: 990)
        let ids = try await importTexts(
            [target.joined(separator: " "), reference.joined(separator: " ")],
            into: model, in: root)
        model.selectedTargetRevisionIDs = [ids[0]]
        model.selectedReferenceRevisionIDs = [ids[1]]
        model.keynessLowExpectedCountThreshold = 0

        await model.compareKeynessNow()

        #expect(model.lastFailure == nil)
        let first = try #require(model.lastKeyness)
        #expect(
            Set(first.terms.map(\.selectedTestIdentifier)) == [
                "GTest-v1", "FisherExactTwoSided-v1",
            ])
        #expect(first.terms.allSatisfy { !$0.hasLowExpectedCount })
        #expect(first.testSelectionIdentifier == "FisherSelection-min-expected-5-v1")
        let rare = try #require(first.terms.first { $0.term == "raro" })
        #expect(rare.selectedTestIdentifier == "FisherExactTwoSided-v1")
        #expect(rare.pValue != rare.gTestPValue)
        model.keynessLowExpectedCountThreshold = 100

        await model.compareKeynessNow()

        #expect(model.lastFailure == nil)
        let changed = try #require(model.lastKeyness)
        #expect(changed.artifactID != first.artifactID)
        #expect(
            changed.terms.map(\.selectedTestIdentifier) == first.terms.map(\.selectedTestIdentifier)
        )
        #expect(changed.terms.map(\.pValue) == first.terms.map(\.pValue))
        #expect(changed.terms.map(\.gTestPValue) == first.terms.map(\.gTestPValue))
        #expect(changed.terms.map(\.qValue) == first.terms.map(\.qValue))
        #expect(changed.terms.allSatisfy { $0.hasLowExpectedCount })
    }

    @Test func exposesEveryTermWithoutChangingTheMultipleComparisonFamily() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        try await preparePagedComparison(model, in: root)
        let result = try #require(model.lastKeyness)
        let snapshot = model.snapshot
        #expect(result.terms.count == 121)
        #expect(model.keynessPageSize == 50)
        #expect(model.keynessPageCount == 3)
        var rows: [GlifiStudioKeynessTerm] = []
        for page in 0..<model.keynessPageCount {
            model.showKeynessPage(page)
            rows.append(contentsOf: model.keynessTermsOnPage)
        }
        #expect(rows == result.terms)
        #expect(model.keynessTermsOnPage.count == 21)
        model.showKeynessPage(-1)
        model.showKeynessPage(Int.max)
        #expect(model.keynessPage == 2)
        #expect(model.lastKeyness == result)
        #expect(model.snapshot == snapshot)
        model.showKeynessPage(0)
        #expect(model.keynessTermsOnPage == Array(result.terms.prefix(50)))
        model.showKeynessPage(2)

        await model.compareKeynessNow()

        #expect(model.lastFailure == nil)
        #expect(model.keynessPage == 0)
        #expect(model.lastKeyness?.artifactID == result.artifactID)
        #expect(model.snapshot == snapshot)
    }

    @Test(arguments: StudioKeynessFailureCase.allCases)
    func preservesThePreviousResultRequestPageAndSnapshotOnFailure(
        scenario: StudioKeynessFailureCase
    ) async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        try await preparePagedComparison(model, in: root)
        model.showKeynessPage(2)
        let result = try #require(model.lastKeyness)
        let request = model.lastKeynessRequestOptions
        let options = model.lastKeynessOptions
        let corpusOptions = model.lastCorpusOptions
        let snapshot = model.snapshot
        switch scenario {
        case .missingReference: model.selectedReferenceRevisionIDs = []
        case .overlappingGroups:
            model.selectedReferenceRevisionIDs = model.selectedTargetRevisionIDs
        case .hypothesisLimit: model.keynessMaximumHypothesisCount = 120
        case .negativeLimit: model.keynessMaximumHypothesisCount = -1
        case .negativeThreshold: model.keynessLowExpectedCountThreshold = -1
        case .zeroConfidence: model.keynessConfidenceLevel = 0
        case .unitConfidence: model.keynessConfidenceLevel = 1
        case .nanConfidence: model.keynessConfidenceLevel = .nan
        case .infiniteConfidence: model.keynessConfidenceLevel = .infinity
        case .unrepresentableQuantile: model.keynessConfidenceLevel = 1.0.nextDown
        }

        await model.compareKeynessNow()

        #expect(model.lastFailure?.code == scenario.expectedCode)
        #expect(model.lastKeyness == result)
        #expect(model.lastKeynessRequestOptions == request)
        #expect(model.lastKeynessOptions == options)
        #expect(model.lastCorpusOptions == corpusOptions)
        #expect(model.snapshot == snapshot)
        #expect(model.keynessPage == 2)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
    }

    @Test(arguments: [true, false])
    func rejectsTokenlessAndDegeneratePopulationsWhileRetainingThePreviousResult(tokenless: Bool)
        async throws
    {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        try await preparePagedComparison(model, in: root)
        let previous = model.lastKeyness
        let request = model.lastKeynessRequestOptions
        let ids = try await importTexts(
            tokenless ? ["!!!", "mare"] : ["comune", "comune comune"], into: model, in: root)
        model.selectedTargetRevisionIDs = [ids[0]]
        model.selectedReferenceRevisionIDs = [ids[1]]
        let snapshot = model.snapshot

        await model.compareKeynessNow()

        #expect(
            model.lastFailure?.code
                == (tokenless ? "keyness.empty-token-population" : "keyness.degenerate-margin"))
        #expect(model.lastKeyness == previous)
        #expect(model.lastKeynessRequestOptions == request)
        #expect(model.snapshot == snapshot)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)
    }

    @Test func cancellationRetainsOwnershipAndAllowsRetryWithTheSameRequest() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        try await preparePagedComparison(model, in: root)
        model.showKeynessPage(2)
        let result = model.lastKeyness
        let request = model.lastKeynessRequestOptions
        let snapshot = model.snapshot
        let observation = KeynessCancellationObservation()
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

        await model.compareKeynessNow()

        #expect(observation.observed)
        #expect(model.lastFailure?.code == "operation.cancelled")
        #expect(model.lastKeyness == result)
        #expect(model.lastKeynessRequestOptions == request)
        #expect(model.snapshot == snapshot)
        #expect(model.keynessPage == 2)
        #expect(!model.isBusy)
        #expect(!model.canCancelAnalysis)

        await model.compareKeynessNow()

        #expect(model.lastFailure == nil)
        #expect(model.lastKeynessRequestOptions == request)
        #expect(model.lastKeyness?.artifactID == result?.artifactID)
        #expect(model.keynessPage == 0)
    }

    @Test func refusesAComparisonWithoutAProjectAndClearsStateForANewProject() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.compareKeynessNow()
        #expect(model.lastFailure != nil)
        #expect(model.lastKeynessRequestOptions == nil)
        try await preparePagedComparison(model, in: root)
        model.showKeynessPage(2)
        model.keynessMaximumHypothesisCount = 5
        model.keynessLowExpectedCountThreshold = 10
        model.keynessConfidenceLevel = 0.8

        await model.attachDocument(
            at: root.appending(path: "Fresh.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.lastKeyness == nil)
        #expect(model.lastKeynessOptions == nil)
        #expect(model.lastKeynessRequestOptions == nil)
        #expect(model.lastCorpusOptions == nil)
        #expect(model.keynessPage == 0)
        #expect(model.keynessPageCount == 0)
        #expect(model.keynessTermsOnPage.isEmpty)
        #expect(model.keynessMaximumHypothesisCount == 100_000)
        #expect(model.keynessLowExpectedCountThreshold == 5)
        #expect(model.keynessConfidenceLevel == 0.95)
        #expect(model.selectedTargetRevisionIDs.isEmpty)
        #expect(model.selectedReferenceRevisionIDs.isEmpty)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudioKeynessTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func preparePagedComparison(_ model: StudioHomeModel, in root: URL) async throws {
        await model.attachDocument(
            at: root.appending(path: "Pages.glifi"), needsPackageInitialization: true)
        let words = (0..<120).map(word)
        let ids = try await importTexts(
            [
                (["comune"] + words.prefix(60)).joined(separator: " "),
                (["comune"] + words.suffix(60)).joined(separator: " "),
            ], into: model, in: root)
        model.selectedTargetRevisionIDs = [ids[0]]
        model.selectedReferenceRevisionIDs = [ids[1]]
        await model.compareKeynessNow()
        #expect(model.lastFailure == nil)
        _ = try #require(model.lastKeyness)
    }

    private func importTexts(
        _ texts: [String], into model: StudioHomeModel, in root: URL
    ) async throws -> [String] {
        var ids: [String] = []
        for (index, text) in texts.enumerated() {
            let url = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            let known = Set(model.snapshot?.sources.map(\.sourceRevisionID) ?? [])
            await model.importSource(at: url)
            #expect(model.lastFailure == nil)
            let source = try #require(
                model.snapshot?.sources.first { !known.contains($0.sourceRevisionID) })
            ids.append(source.sourceRevisionID)
        }
        return ids
    }

    private func comparablePayload(_ result: GlifiStudioKeynessResult) throws -> Data {
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        // Reuse captures a newer source generation while preserving the same persisted result.
        object.removeValue(forKey: "sourceGeneration")
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
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

nonisolated enum StudioKeynessFailureCase: CaseIterable, Sendable {
    case missingReference
    case overlappingGroups
    case hypothesisLimit
    case negativeLimit
    case negativeThreshold
    case zeroConfidence
    case unitConfidence
    case nanConfidence
    case infiniteConfidence
    case unrepresentableQuantile

    var expectedCode: String {
        switch self {
        case .missingReference: "ui.failure.keyness.missing-groups"
        case .overlappingGroups: "ui.failure.keyness.overlapping-groups"
        case .hypothesisLimit: "keyness.hypothesis-limit-exceeded"
        case .negativeLimit, .negativeThreshold, .zeroConfidence, .unitConfidence,
            .nanConfidence, .infiniteConfidence:
            "keyness.invalid-options"
        case .unrepresentableQuantile: "statistics.invalid-probability"
        }
    }
}

@MainActor
private final class KeynessCancellationObservation {
    var observed = false
}
