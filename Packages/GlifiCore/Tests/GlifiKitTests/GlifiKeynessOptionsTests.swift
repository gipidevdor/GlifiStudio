// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test func keynessOptionsPreserveTheTwoArgumentInitializerAsAFunctionValue() throws {
    let makeOptions: (Int, Double) throws -> GlifiStudioKeynessOptions =
        GlifiStudioKeynessOptions.init(maximumHypothesisCount:lowExpectedCountThreshold:)
    let legacy = try makeOptions(1_000, 0.25)
    let explicit = try GlifiStudioKeynessOptions(
        maximumHypothesisCount: 1_000, lowExpectedCountThreshold: 0.25, confidenceLevel: 0.95)

    #expect(legacy == explicit)
    #expect(legacy.maximumHypothesisCount == 1_000)
    #expect(legacy.lowExpectedCountThreshold == 0.25)
    #expect(legacy.confidenceLevel == 0.95)
    #expect(GlifiStudioKeynessOptions.standard.confidenceLevel == 0.95)
}

@Test(arguments: [0.8, 0.95, 0.99, 1e-300])
func keynessFacadePreservesConfidenceIdentityAndReuse(confidenceLevel: Double) async throws {
    let fixture = try await keynessOptionsFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let original = try await fixture.session.compareKeyness(
        targetSourceRevisionIDs: [fixture.targetID],
        referenceSourceRevisionIDs: [fixture.referenceID],
        keynessOptions: GlifiStudioKeynessOptions(
            maximumHypothesisCount: 1_000, lowExpectedCountThreshold: 0.25))
    let options = try GlifiStudioKeynessOptions(
        maximumHypothesisCount: 1_000, lowExpectedCountThreshold: 0.25,
        confidenceLevel: confidenceLevel)

    let result = try await fixture.session.compareKeyness(
        targetSourceRevisionIDs: [fixture.targetID],
        referenceSourceRevisionIDs: [fixture.referenceID],
        keynessOptions: options)

    #expect(options.confidenceLevel == confidenceLevel)
    #expect(result.confidenceLevel == confidenceLevel)
    #expect(result.terms.count == 2)
    #expect(result.lowExpectedCountThreshold == 0.25)
    #expect(result.testSelectionIdentifier == "FisherSelection-min-expected-5-v1")
    #expect(result.terms.allSatisfy { $0.selectedTestIdentifier == "FisherExactTwoSided-v1" })
    #expect(result.terms.allSatisfy { !$0.hasLowExpectedCount })
    #expect(result.terms.map(\.term) == original.terms.map(\.term))
    #expect(result.terms.map(\.pValue) == original.terms.map(\.pValue))
    #expect(result.terms.map(\.gTestPValue) == original.terms.map(\.gTestPValue))
    #expect(result.terms.map(\.qValue) == original.terms.map(\.qValue))
    #expect(
        result.terms.map(\.log2RatioHaldaneAnscombe)
            == original.terms.map(\.log2RatioHaldaneAnscombe))
    #expect(
        result.terms.map(\.oddsRatioHaldaneAnscombe)
            == original.terms.map(\.oddsRatioHaldaneAnscombe))
    if confidenceLevel == 0.95 {
        #expect(result.artifactID == original.artifactID)
        #expect(result.comparisonDigest == original.comparisonDigest)
        #expect(result.generation == original.generation)
    } else {
        #expect(result.artifactID != original.artifactID)
        #expect(result.comparisonDigest != original.comparisonDigest)
        #expect(result.terms.map(\.log2RatioLower) != original.terms.map(\.log2RatioLower))
        #expect(result.terms.map(\.oddsRatioUpper) != original.terms.map(\.oddsRatioUpper))
    }
    let repeated = try await fixture.session.compareKeyness(
        targetSourceRevisionIDs: [fixture.targetID],
        referenceSourceRevisionIDs: [fixture.referenceID],
        keynessOptions: options)
    #expect(repeated.artifactID == result.artifactID)
    #expect(repeated.generation == result.generation)
    #expect(repeated.terms == result.terms)
    #expect(try await fixture.session.snapshot().generation == result.generation)
    await fixture.session.close()
}

@Test func keynessOptionsRejectInvalidConfidenceWithoutClamping() {
    for confidenceLevel in [0, 1, -0.1, 1.1, Double.nan, .infinity, -.infinity] {
        do {
            _ = try GlifiStudioKeynessOptions(
                maximumHypothesisCount: 1_000, lowExpectedCountThreshold: 5,
                confidenceLevel: confidenceLevel)
            Issue.record("Invalid confidence must produce the typed options failure.")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.code == "keyness.invalid-options")
            #expect(failure.category == "invalidInput")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "afterCorrection")
            #expect(failure.retainedState == "lastCommittedGeneration")
        } catch {
            Issue.record("The confidence failure must preserve the GlifiKit error type.")
        }
    }
}

@Test func keynessFacadePreservesTheNumericFailureForAnExtremeValidConfidence() async throws {
    let fixture = try await keynessOptionsFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let baseline = try await fixture.session.compareKeyness(
        targetSourceRevisionIDs: [fixture.targetID],
        referenceSourceRevisionIDs: [fixture.referenceID])
    let options = try GlifiStudioKeynessOptions(
        maximumHypothesisCount: 1_000, lowExpectedCountThreshold: 5,
        confidenceLevel: Double(1).nextDown)

    do {
        _ = try await fixture.session.compareKeyness(
            targetSourceRevisionIDs: [fixture.targetID],
            referenceSourceRevisionIDs: [fixture.referenceID], keynessOptions: options)
        Issue.record("The rounded quantile endpoint must retain its typed numeric failure.")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "statistics.invalid-probability")
        #expect(failure.category == "invalidInput")
        #expect(failure.operation == "analyze")
        #expect(failure.retryDisposition == "afterCorrection")
        #expect(failure.retainedState == "lastCommittedGeneration")
    }
    #expect(try await fixture.session.snapshot().generation == baseline.generation)
    await fixture.session.close()
}

private func keynessOptionsFixture() async throws -> (
    root: URL, session: GlifiStudioProjectSession, targetID: String, referenceID: String
) {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitKeynessOptions-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    do {
        let session = try await GlifiStudioService().createProject(
            at: root.appending(path: "Test.glifi"))
        let targetURL = root.appending(path: "target.txt")
        let referenceURL = root.appending(path: "reference.txt")
        try Data("b b".utf8).write(to: targetURL)
        try Data("a a".utf8).write(to: referenceURL)
        let target = try await session.importText(at: targetURL, format: .plainText)
        let targetID = try #require(target.project.sources.first?.sourceRevisionID)
        let reference = try await session.importText(at: referenceURL, format: .plainText)
        let referenceID = try #require(
            reference.project.sources.first { $0.sourceRevisionID != targetID }?.sourceRevisionID)
        return (root, session, targetID, referenceID)
    } catch {
        try? FileManager.default.removeItem(at: root)
        throw error
    }
}
