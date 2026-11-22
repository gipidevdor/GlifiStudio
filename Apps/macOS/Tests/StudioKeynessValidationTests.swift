// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioKeynessValidationTests {
    @Test(arguments: StudioMalformedKeyness.allCases)
    func rejectsFiniteMalformedDTOsAtThePresentationBoundary(mutation: StudioMalformedKeyness)
        async throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudioKeynessValidation-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Comparison.glifi"), needsPackageInitialization: true)
        var revisionIDs: [String] = []
        for (index, text) in ["città città mare", "mare sole"].enumerated() {
            let url = root.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            let known = Set(model.snapshot?.sources.map(\.sourceRevisionID) ?? [])
            await model.importSource(at: url)
            #expect(model.lastFailure == nil)
            let source = try #require(
                model.snapshot?.sources.first { !known.contains($0.sourceRevisionID) })
            revisionIDs.append(source.sourceRevisionID)
        }
        model.selectedTargetRevisionIDs = [revisionIDs[0]]
        model.selectedReferenceRevisionIDs = [revisionIDs[1]]
        await model.compareKeynessNow()
        #expect(model.lastFailure == nil)
        let valid = try #require(model.lastKeyness)
        let request = try #require(model.lastKeynessRequestOptions)
        try #require(valid.terms.count == 3)
        try await StudioHomeModel.validateKeynessPresentation(valid, options: request)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        var rows = try #require(object["terms"] as? [[String: Any]])
        switch mutation {
        case .targetPopulationMismatch:
            object["targetSourceRevisionIDs"] = ["unexpected-target"]
        case .referencePopulationMismatch:
            object["referenceSourceRevisionIDs"] = ["unexpected-reference"]
        case .overlappingPopulations:
            object["referenceSourceRevisionIDs"] = valid.targetSourceRevisionIDs
        case .emptyTargetPopulation:
            object["targetSourceRevisionIDs"] = [String]()
        case .duplicateTargetRevision:
            object["targetSourceRevisionIDs"] =
                valid.targetSourceRevisionIDs + valid.targetSourceRevisionIDs
        case .confidenceMismatch:
            object["confidenceLevel"] = 0.8
        case .diagnosticThresholdMismatch:
            object["lowExpectedCountThreshold"] = 3.0
        case .zeroTargetTokenTotal:
            object["targetTokenCount"] = 0
        case .zeroReferenceTokenTotal:
            object["referenceTokenCount"] = 0
        case .emptyTerm:
            rows[0]["term"] = ""
        case .duplicateTerm:
            rows[1]["term"] = rows[0]["term"]
        case .reversedTermOrder:
            rows.reverse()
        case .negativeTargetFrequency:
            rows[0]["targetFrequency"] = -1
        case .negativeReferenceFrequency:
            rows[0]["referenceFrequency"] = -1
        case .excessiveTargetFrequency:
            rows[0]["targetFrequency"] = valid.targetTokenCount + 1
        case .excessiveReferenceFrequency:
            rows[0]["referenceFrequency"] = valid.referenceTokenCount + 1
        case .bothFrequenciesZero:
            rows[0]["targetFrequency"] = 0
            rows[0]["referenceFrequency"] = 0
        case .targetFrequencySumMismatch:
            let index = try #require(valid.terms.firstIndex { $0.targetFrequency > 1 })
            rows[index]["targetFrequency"] = valid.terms[index].targetFrequency - 1
        case .targetFrequencySumOverflow:
            object["targetTokenCount"] = Int.max
            rows[0]["targetFrequency"] = Int.max
            rows[1]["targetFrequency"] = Int.max
        case .negativeTargetRelativeFrequency:
            rows[0]["targetRelativeFrequency"] = -0.1
        case .excessiveTargetRelativeFrequency:
            rows[0]["targetRelativeFrequency"] = 1.1
        case .negativeReferenceRelativeFrequency:
            rows[0]["referenceRelativeFrequency"] = -0.1
        case .excessiveReferenceRelativeFrequency:
            rows[0]["referenceRelativeFrequency"] = 1.1
        case .negativeSelectedPValue:
            rows[0]["pValue"] = -0.1
        case .excessiveSelectedPValue:
            rows[0]["pValue"] = 1.1
        case .negativeGTestPValue:
            rows[0]["gTestPValue"] = -0.1
        case .excessiveGTestPValue:
            rows[0]["gTestPValue"] = 1.1
        case .negativeQValue:
            rows[0]["qValue"] = -0.1
        case .excessiveQValue:
            rows[0]["qValue"] = 1.1
        case .negativeGStatistic:
            rows[0]["gStatistic"] = -0.1
        case .invalidDegreesOfFreedom:
            rows[0]["degreesOfFreedom"] = 2
        case .zeroMinimumExpectedCount:
            rows[0]["minimumExpectedCount"] = 0.0
        case .negativeMinimumExpectedCount:
            rows[0]["minimumExpectedCount"] = -1.0
        case .zeroOddsRatio:
            rows[0]["oddsRatioHaldaneAnscombe"] = 0.0
        case .negativeOddsRatio:
            rows[0]["oddsRatioHaldaneAnscombe"] = -1.0
        case .zeroOddsRatioLowerBound:
            rows[0]["oddsRatioLower"] = 0.0
        case .negativeOddsRatioUpperBound:
            rows[0]["oddsRatioUpper"] = -1.0
        case .reversedOddsRatioBounds:
            rows[0]["oddsRatioLower"] = valid.terms[0].oddsRatioUpper
            rows[0]["oddsRatioUpper"] = valid.terms[0].oddsRatioLower
        case .oddsRatioOutsideInterval:
            rows[0]["oddsRatioLower"] = valid.terms[0].oddsRatioHaldaneAnscombe + 1
            rows[0]["oddsRatioUpper"] = valid.terms[0].oddsRatioHaldaneAnscombe + 2
        case .reversedLogRatioBounds:
            rows[0]["log2RatioLower"] = valid.terms[0].log2RatioUpper
            rows[0]["log2RatioUpper"] = valid.terms[0].log2RatioLower
        case .logRatioOutsideInterval:
            rows[0]["log2RatioLower"] = valid.terms[0].log2RatioHaldaneAnscombe + 1
            rows[0]["log2RatioUpper"] = valid.terms[0].log2RatioHaldaneAnscombe + 2
        case .unrelatedHugeUpperBoundMustNotRelaxOddsLowerBound:
            let index = try #require(valid.terms.firstIndex { $0.oddsRatioHaldaneAnscombe < 1 })
            rows[index]["oddsRatioLower"] = 1.0
            rows[index]["oddsRatioUpper"] = 1e308
        case .unrelatedHugeLowerBoundMustNotRelaxLogUpperBound:
            rows[0]["log2RatioHaldaneAnscombe"] = 1_000.0
            rows[0]["log2RatioLower"] = -1e308
            rows[0]["log2RatioUpper"] = 1.0
        case .unknownDirection:
            rows[0]["direction"] = "unknown"
        case .unknownSelectedTest:
            rows[0]["selectedTestIdentifier"] = "PearsonChiSquare-v1"
        case .unknownComparisonProfile:
            object["comparisonIdentifier"] = "keyness-future-v3"
        case .unknownSelectionPolicy:
            object["testSelectionIdentifier"] = "FisherSelection-future-v2"
        case .unknownCorrectionPolicy:
            object["correctionIdentifier"] = "BenjaminiHochberg-future-v2"
        }
        object["terms"] = rows
        let malformed = try JSONDecoder().decode(
            GlifiStudioKeynessResult.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))

        do {
            try await StudioHomeModel.validateKeynessPresentation(malformed, options: request)
            Issue.record("An inconsistent DTO must fail at the production presentation boundary.")
        } catch {
            #expect(error.code == "ui.keyness.invalid-result")
            #expect(error.category == "corruption")
            #expect(error.operation == "analyze")
            #expect(error.retryDisposition == "never")
            #expect(error.retainedState == "lastCommittedGeneration")
            #expect(error.messageKey == "failure.keyness.invalid-result")
        }
    }
}

nonisolated enum StudioMalformedKeyness: CaseIterable, Sendable {
    case targetPopulationMismatch
    case referencePopulationMismatch
    case overlappingPopulations
    case emptyTargetPopulation
    case duplicateTargetRevision
    case confidenceMismatch
    case diagnosticThresholdMismatch
    case zeroTargetTokenTotal
    case zeroReferenceTokenTotal
    case emptyTerm
    case duplicateTerm
    case reversedTermOrder
    case negativeTargetFrequency
    case negativeReferenceFrequency
    case excessiveTargetFrequency
    case excessiveReferenceFrequency
    case bothFrequenciesZero
    case targetFrequencySumMismatch
    case targetFrequencySumOverflow
    case negativeTargetRelativeFrequency
    case excessiveTargetRelativeFrequency
    case negativeReferenceRelativeFrequency
    case excessiveReferenceRelativeFrequency
    case negativeSelectedPValue
    case excessiveSelectedPValue
    case negativeGTestPValue
    case excessiveGTestPValue
    case negativeQValue
    case excessiveQValue
    case negativeGStatistic
    case invalidDegreesOfFreedom
    case zeroMinimumExpectedCount
    case negativeMinimumExpectedCount
    case zeroOddsRatio
    case negativeOddsRatio
    case zeroOddsRatioLowerBound
    case negativeOddsRatioUpperBound
    case reversedOddsRatioBounds
    case oddsRatioOutsideInterval
    case reversedLogRatioBounds
    case logRatioOutsideInterval
    case unrelatedHugeUpperBoundMustNotRelaxOddsLowerBound
    case unrelatedHugeLowerBoundMustNotRelaxLogUpperBound
    case unknownDirection
    case unknownSelectedTest
    case unknownComparisonProfile
    case unknownSelectionPolicy
    case unknownCorrectionPolicy
}
