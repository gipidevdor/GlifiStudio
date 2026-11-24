// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("GTest, Fisher selezionato, IC ed effect size coincidono con il caso noto e con R")
func keynessProducesSpecifiedValues() throws {
    let target = try corpusProfile(
        text: "casa casa mare",
        revision: "00000000-0000-0000-0000-000000000001"
    )
    let reference = try corpusProfile(
        text: "casa città città",
        revision: "00000000-0000-0000-0000-000000000002"
    )

    let comparison = try GlifiKeynessAnalyzer().compare(
        target: target,
        reference: reference
    )
    let repeated = try GlifiKeynessAnalyzer().compare(
        target: target,
        reference: reference
    )

    #expect(comparison == repeated)
    #expect(comparison.comparisonIdentifier == "keyness-gtest-fisher-ha-ci-bh-v2")
    #expect(comparison.testSelectionIdentifier == "FisherSelection-min-expected-5-v1")
    #expect(comparison.exactTestIdentifier == "FisherExactTwoSided-v1")
    #expect(comparison.confidenceLevel == 0.95)
    #expect(comparison.comparisonDigest.hasPrefix("sha256:"))
    #expect(comparison.testIdentifier == "GTest-v1")
    #expect(comparison.correctionIdentifier == "BenjaminiHochberg-v1")
    #expect(comparison.oddsRatioIdentifier == "OddsRatio-HA-v1")
    #expect(comparison.logRatioIdentifier == "LogRatio-HA-v1-base2")
    #expect(comparison.targetTokenCount == 3)
    #expect(comparison.referenceTokenCount == 3)
    #expect(comparison.terms.map(\.term) == ["città", "mare", "casa"])

    let city = comparison.terms[0]
    #expect(city.targetFrequency == 0)
    #expect(city.referenceFrequency == 2)
    #expect(abs(city.gStatistic - 3.8190850097688767) < 1e-12)
    // Oracolo: Tests/Oracles/R/keyness.R (KEYNESS_SMALL_*); il G-test resta registrato.
    #expect(abs(city.gTestPValue - 0.0506719023469901) < 1e-12)
    #expect(city.selectedTestIdentifier == "FisherExactTwoSided-v1")
    #expect(abs(city.pValue - 0.4) < 1e-12)
    #expect(abs(city.qValue - 1) < 1e-12)
    #expect(abs(city.log2RatioLower - (-6.21954751439024)) < 1e-12)
    #expect(abs(city.log2RatioUpper - 1.57569132461552) < 1e-12)
    #expect(abs(city.oddsRatioLower - 0.00236889077053129) < 1e-12)
    #expect(abs(city.oddsRatioUpper - 3.1014257250293) < 1e-12)
    #expect(abs(city.log2RatioHaldaneAnscombe - (-2.321928094887362)) < 1e-12)
    #expect(abs(city.oddsRatioHaldaneAnscombe - 0.0857142857142857) < 1e-12)
    #expect(city.direction == .reference)
    #expect(city.minimumExpectedCount == 1)
    #expect(city.hasLowExpectedCount)

    let sea = comparison.terms[1]
    #expect(abs(sea.gTestPValue - 0.2076622768584) < 1e-12)
    #expect(abs(sea.pValue - 1) < 1e-12)
    #expect(abs(sea.log2RatioLower - (-2.57719663458431)) < 1e-12)
    #expect(abs(sea.log2RatioUpper - 5.74712163602663) < 1e-12)
    #expect(abs(sea.oddsRatioLower - 0.116075647756033) < 1e-12)
    #expect(abs(sea.oddsRatioUpper - 151.969860526436) < 1e-10)
    #expect(sea.direction == .target)
    let house = comparison.terms[2]
    #expect(abs(house.gTestPValue - 0.409725824063315) < 1e-12)
    #expect(abs(house.pValue - 1) < 1e-12)
    #expect(abs(house.qValue - 1) < 1e-12)
    #expect(abs(house.log2RatioLower - (-1.39159718331577)) < 1e-12)
    #expect(abs(house.log2RatioUpper - 2.86552837164818) < 1e-12)
    #expect(abs(house.oddsRatioLower - 0.158649266806663) < 1e-12)
    #expect(abs(house.oddsRatioUpper - 48.6358968939905) < 1e-11)
    #expect(house.direction == .target)
}

@Test("Keyness rifiuta gruppi sovrapposti, degeneri e famiglie oltre limite")
func keynessRejectsInvalidPopulations() throws {
    let target = try corpusProfile(
        text: "casa mare",
        revision: "00000000-0000-0000-0000-000000000001"
    )
    let overlapping = try corpusProfile(
        text: "casa città",
        revision: "00000000-0000-0000-0000-000000000001"
    )
    try expectKeynessFailure(code: "keyness.overlapping-groups") {
        _ = try GlifiKeynessAnalyzer().compare(target: target, reference: overlapping)
    }

    let empty = try corpusProfile(
        text: "",
        revision: "00000000-0000-0000-0000-000000000002"
    )
    try expectKeynessFailure(code: "keyness.empty-token-population") {
        _ = try GlifiKeynessAnalyzer().compare(target: target, reference: empty)
    }

    let singleTypeTarget = try corpusProfile(
        text: "casa casa",
        revision: "00000000-0000-0000-0000-000000000003"
    )
    let singleTypeReference = try corpusProfile(
        text: "casa",
        revision: "00000000-0000-0000-0000-000000000004"
    )
    try expectKeynessFailure(code: "keyness.degenerate-margin") {
        _ = try GlifiKeynessAnalyzer().compare(
            target: singleTypeTarget,
            reference: singleTypeReference
        )
    }

    let reference = try corpusProfile(
        text: "casa città",
        revision: "00000000-0000-0000-0000-000000000005"
    )
    try expectKeynessFailure(code: "keyness.hypothesis-limit-exceeded") {
        _ = try GlifiKeynessAnalyzer().compare(
            target: target,
            reference: reference,
            options: try GlifiKeynessOptions(
                maximumHypothesisCount: 2,
                lowExpectedCountThreshold: 5
            )
        )
    }
    try expectKeynessFailure(code: "keyness.invalid-options") {
        _ = try GlifiKeynessOptions(
            maximumHypothesisCount: -1,
            lowExpectedCountThreshold: .nan
        )
    }
}

private func corpusProfile(text: String, revision: String) throws -> GlifiCorpusAnalysis {
    let imported = try GlifiTextImporter().importText(
        from: Data(text.utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(UUID(uuidString: revision))
        )
    )
    return try GlifiCorpusAnalyzer().analyze(
        [imported],
        options: try GlifiCorpusAnalysisOptions(
            diversityWindowSize: 2,
            ngramSizes: [],
            maximumDocumentCount: 1,
            maximumSourceByteCount: 4_096,
            maximumVocabularySize: 10,
            maximumDistinctNGramCount: 0,
            maximumNonZeroCellCount: 10
        )
    )
}

private func expectKeynessFailure(
    code: String,
    _ operation: () throws -> Void
) throws {
    do {
        try operation()
        Issue.record("Era attesa la failure \(code)")
    } catch let failure as GlifiFailure {
        #expect(failure.code == code)
        #expect(failure.operation == .analyze)
    }
}

@Test("Con attese almeno 5 la regola di Cochran conserva il G-test e gli IC coincidono con R")
func keynessKeepsGTestForLargeExpectedCounts() throws {
    let target = try corpusProfile(
        text: Array(repeating: "x", count: 30).joined(separator: " ") + " "
            + Array(repeating: "y", count: 970).joined(separator: " "),
        revision: "00000000-0000-0000-0000-000000000011"
    )
    let reference = try corpusProfile(
        text: Array(repeating: "x", count: 10).joined(separator: " ") + " "
            + Array(repeating: "y", count: 990).joined(separator: " "),
        revision: "00000000-0000-0000-0000-000000000012"
    )
    let comparison = try GlifiKeynessAnalyzer().compare(target: target, reference: reference)
    let x = try #require(comparison.terms.first { $0.term == "x" })
    // Oracolo: Tests/Oracles/R/keyness.R (KEYNESS_LARGE).
    #expect(x.selectedTestIdentifier == "GTest-v1")
    #expect(abs(x.pValue - 0.00108943170022443) < 1e-12)
    #expect(x.pValue == x.gTestPValue)
    #expect(abs(x.log2RatioLower - 0.534603271450417) < 1e-12)
    #expect(abs(x.log2RatioUpper - 2.54223655811783) < 1e-12)
    #expect(abs(x.oddsRatioLower - 1.46213583146596) < 1e-12)
    #expect(abs(x.oddsRatioUpper - 6.01106246008735) < 1e-12)
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiKeynessOptions(
            maximumHypothesisCount: 10, lowExpectedCountThreshold: 5, confidenceLevel: 1)
    }
}
