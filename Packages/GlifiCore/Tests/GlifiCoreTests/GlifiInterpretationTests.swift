// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Il profilo descrittivo produce Evidence e Finding content-addressed con lineage completo")
func corpusInterpretationIsStableAndGrounded() throws {
    let revisionID = try sourceRevision("00000000-0000-0000-0000-000000000001")
    let imported = try GlifiTextImporter().importText(
        from: Data("casa mare casa".utf8),
        format: .plainText,
        sourceRevisionID: revisionID
    )
    let analysis = try GlifiCorpusAnalyzer().analyze([imported])
    let plan = try GlifiAnalysisPlanner().plan(
        request: GlifiAnalysisPlanRequest(intent: .understandCollection),
        sourceRootDigest: testDigest("a"),
        configuredLanguageCode: "it",
        sources: [
            try GlifiPlanningSource(
                sourceRevisionID: revisionID,
                format: .plainText,
                byteCount: imported.bytes.count
            )
        ]
    )
    let step = try #require(plan.steps.only)
    let input = GlifiInterpretationArtifactInput(
        planStepIdentifier: step.identifier,
        role: step.role,
        artifactID: try ArtifactID(digest: testDigest("b")),
        analysisNodeID: try AnalysisNodeID(digest: testDigest("c")),
        descriptorDigest: testDigest("d"),
        content: .corpusProfile(analysis)
    )
    let sources = [sourceRecord(revisionID, byteCount: imported.bytes.count)]
    let engine = GlifiInterpretationEngine()
    let first = try engine.interpret(
        planArtifactID: try ArtifactID(digest: testDigest("e")),
        planAnalysisNodeID: try AnalysisNodeID(digest: testDigest("f")),
        plan: plan,
        artifacts: [input],
        sources: sources
    )
    let repeated = try engine.interpret(
        planArtifactID: first.planArtifactID,
        planAnalysisNodeID: first.planAnalysisNodeID,
        plan: plan,
        artifacts: [input],
        sources: sources
    )

    #expect(first == repeated)
    #expect(first.evidence.count == 1)
    #expect(first.findings.count == 1)
    #expect(first.insufficientEvidence == nil)
    #expect(first.evidence[0].artifactIDs == [input.artifactID])
    #expect(first.evidence[0].sourceReferences[0].sourceRevisionID == revisionID)
    #expect(first.evidence[0].sourceReferences[0].ranges[0].count == imported.bytes.count)
    #expect(first.findings[0].evidenceReferences[0].evidenceID == first.evidence[0].id)
    #expect(first.findings[0].assessment.supportClass == .descriptive)
    #expect(first.findings[0].epistemicCategory == .deterministicallyInterpreted)
    #expect(first.findings[0].rankFactors.stability == nil)
    #expect(first.findings[0].rankFactors.novelty == nil)

    let wrongRole = GlifiInterpretationArtifactInput(
        planStepIdentifier: step.identifier,
        role: .target,
        artifactID: input.artifactID,
        analysisNodeID: input.analysisNodeID,
        descriptorDigest: input.descriptorDigest,
        content: input.content
    )
    #expect(throws: GlifiFailure.self) {
        _ = try engine.interpret(
            planArtifactID: first.planArtifactID,
            planAnalysisNodeID: first.planAnalysisNodeID,
            plan: plan,
            artifacts: [wrongRole],
            sources: sources
        )
    }
}

@Test("La policy keyness ordina per famiglia, espone le cautele e limita i risultati")
func keynessInterpretationUsesExplicitSupportAndRanking() throws {
    let targetID = try sourceRevision("00000000-0000-0000-0000-000000000011")
    let referenceID = try sourceRevision("00000000-0000-0000-0000-000000000012")
    let plan = try comparisonPlan(targetID: targetID, referenceID: referenceID)
    let target = try corpus(text: "alfa alfa beta", revisionID: targetID)
    let reference = try corpus(text: "gamma gamma beta", revisionID: referenceID)
    let comparison = keynessComparison(targetID: targetID, referenceID: referenceID)
    let inputs = try plan.steps.enumerated().map { index, step in
        let content: GlifiInterpretationArtifactContent
        switch step.role {
        case .target:
            content = .corpusProfile(target)
        case .reference:
            content = .corpusProfile(reference)
        case .comparison where step.operation == .compareKeyness:
            content = .keyness(comparison)
        case .comparison where step.operation == .compareSimilarity:
            // Similarità ADR-0025 con 3 tipi condivisi: `caution` senza magnitudine, quindi
            // ordinata dopo i findings keyness.
            content = .supplementary(
                outputSchemaIdentifier: step.outputSchemaIdentifier,
                sourceRevisionIDs: [targetID, referenceID],
                facts: .similarity(sharedTypeCount: 3, cosine: 0.5, jsDistance: 0.4)
            )
        case .comparison:
            // Confronto di gruppo senza Hedges g definito: non eleggibile (ADR-0026).
            content = .supplementary(
                outputSchemaIdentifier: step.outputSchemaIdentifier,
                sourceRevisionIDs: [targetID, referenceID],
                facts: .groupLocation(
                    metricIdentifier: "document-lexical-token-count-v1",
                    hedgesG: nil,
                    pValue: nil,
                    smallestGroupSize: 1
                )
            )
        case .scope:
            Issue.record("Ruolo scope inatteso nel piano comparativo")
            content = .corpusProfile(target)
        }
        return GlifiInterpretationArtifactInput(
            planStepIdentifier: step.identifier,
            role: step.role,
            artifactID: try ArtifactID(digest: testDigest(hexDigit(index + 1))),
            analysisNodeID: try AnalysisNodeID(digest: testDigest(hexDigit(index + 6))),
            descriptorDigest: testDigest(hexDigit(index + 11)),
            content: content
        )
    }
    let sources = [
        sourceRecord(targetID, byteCount: 14),
        sourceRecord(referenceID, byteCount: 16),
    ]
    let engine = GlifiInterpretationEngine()
    let all = try engine.interpret(
        planArtifactID: try ArtifactID(digest: testDigest("a")),
        planAnalysisNodeID: try AnalysisNodeID(digest: testDigest("b")),
        plan: plan,
        artifacts: inputs,
        sources: sources,
        options: try GlifiInterpretationOptions(
            maximumFindingCount: 3,
            moderateMaximumQValue: 0.05,
            strongMaximumQValue: 0.01,
            moderateMinimumAbsoluteLog2Ratio: 1,
            strongMinimumAbsoluteLog2Ratio: 2
        )
    )

    #expect(all.findings.map(\.assessment.supportClass) == [.strong, .moderate, .caution])
    #expect(all.findings.map { $0.messageArguments["term"] } == ["forte", "moderato", "cauto"])
    #expect(all.evidence[2].validity == .limited)
    #expect(all.evidence[2].caveats.contains { $0.severity == .warning })
    #expect(
        all.suppressionSummaries.contains {
            $0.reasonIdentifier == "interpretation.support-insufficient" && $0.count == 1
        }
    )

    let capped = try engine.interpret(
        planArtifactID: all.planArtifactID,
        planAnalysisNodeID: all.planAnalysisNodeID,
        plan: plan,
        artifacts: inputs,
        sources: sources,
        options: try GlifiInterpretationOptions(
            maximumFindingCount: 2,
            moderateMaximumQValue: 0.05,
            strongMaximumQValue: 0.01,
            moderateMinimumAbsoluteLog2Ratio: 1,
            strongMinimumAbsoluteLog2Ratio: 2
        )
    )
    #expect(capped.findings.count == 2)
    // Oltre il limite restano il terzo finding keyness e quello descrittivo di similarità.
    #expect(
        capped.suppressionSummaries.contains {
            $0.reasonIdentifier == "interpretation.finding-limit-exceeded" && $0.count == 2
        }
    )
    #expect(
        all.suppressionSummaries.contains {
            $0.reasonIdentifier == "interpretation.extended-not-eligible" && $0.count == 1
        }
    )
}

@Test("Il payload revalida le identità e le opzioni rifiutano policy non monotone")
func interpretationPayloadFailsClosed() throws {
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiInterpretationOptions(
            maximumFindingCount: -1,
            moderateMaximumQValue: 0.01,
            strongMaximumQValue: 0.05,
            moderateMinimumAbsoluteLog2Ratio: 2,
            strongMinimumAbsoluteLog2Ratio: 1
        )
    }

    let revisionID = try sourceRevision("00000000-0000-0000-0000-000000000021")
    let imported = try GlifiTextImporter().importText(
        from: Data("testo".utf8),
        format: .plainText,
        sourceRevisionID: revisionID
    )
    let analysis = try GlifiCorpusAnalyzer().analyze([imported])
    let plan = try GlifiAnalysisPlanner().plan(
        request: GlifiAnalysisPlanRequest(intent: .understandCollection),
        sourceRootDigest: testDigest("c"),
        configuredLanguageCode: "it",
        sources: [
            try GlifiPlanningSource(
                sourceRevisionID: revisionID,
                format: .plainText,
                byteCount: imported.bytes.count
            )
        ]
    )
    let step = try #require(plan.steps.only)
    let interpretation = try GlifiInterpretationEngine().interpret(
        planArtifactID: try ArtifactID(digest: testDigest("d")),
        planAnalysisNodeID: try AnalysisNodeID(digest: testDigest("e")),
        plan: plan,
        artifacts: [
            GlifiInterpretationArtifactInput(
                planStepIdentifier: step.identifier,
                role: step.role,
                artifactID: try ArtifactID(digest: testDigest("f")),
                analysisNodeID: try AnalysisNodeID(digest: testDigest("1")),
                descriptorDigest: testDigest("2"),
                content: .corpusProfile(analysis)
            )
        ],
        sources: [sourceRecord(revisionID, byteCount: imported.bytes.count)]
    )
    let nodeID = try AnalysisNodeID(digest: testDigest("3"))
    let payload = try GlifiAnalysisInterpretationArtifactPayload(
        analysisNodeID: nodeID,
        interpretation: interpretation
    )
    let encoded = try GlifiArtifactCanonicalJSON.encode(payload)
    #expect(
        try JSONDecoder().decode(
            GlifiAnalysisInterpretationArtifactPayload.self,
            from: encoded
        ) == payload
    )

    var object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    var storedInterpretation = try #require(object["interpretation"] as? [String: Any])
    var evidence = try #require(storedInterpretation["evidence"] as? [[String: Any]])
    evidence[0]["id"] = "evidence:\(testDigest("9"))"
    storedInterpretation["evidence"] = evidence
    object["interpretation"] = storedInterpretation
    let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(
            GlifiAnalysisInterpretationArtifactPayload.self,
            from: tampered
        )
    }
}

private func comparisonPlan(
    targetID: SourceRevisionID,
    referenceID: SourceRevisionID
) throws -> GlifiAnalysisPlan {
    try GlifiAnalysisPlanner().plan(
        request: GlifiAnalysisPlanRequest(
            intent: .compareObjects,
            targetSourceRevisionIDs: [targetID],
            referenceSourceRevisionIDs: [referenceID]
        ),
        sourceRootDigest: testDigest("0"),
        configuredLanguageCode: "it",
        sources: [
            try GlifiPlanningSource(
                sourceRevisionID: targetID,
                format: .plainText,
                byteCount: 14
            ),
            try GlifiPlanningSource(
                sourceRevisionID: referenceID,
                format: .plainText,
                byteCount: 16
            ),
        ]
    )
}

private func corpus(
    text: String,
    revisionID: SourceRevisionID
) throws -> GlifiCorpusAnalysis {
    try GlifiCorpusAnalyzer().analyze([
        try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: revisionID
        )
    ])
}

private func keynessComparison(
    targetID: SourceRevisionID,
    referenceID: SourceRevisionID
) -> GlifiKeynessComparison {
    GlifiKeynessComparison(
        comparisonIdentifier: GlifiKeynessAnalyzer.comparisonIdentifier,
        comparisonDigest: testDigest("4"),
        targetCorpusDigest: testDigest("5"),
        referenceCorpusDigest: testDigest("6"),
        targetSourceRevisionIDs: [targetID],
        referenceSourceRevisionIDs: [referenceID],
        targetTokenCount: 100,
        referenceTokenCount: 100,
        testIdentifier: "GTest-v1",
        testSelectionIdentifier: GlifiKeynessAnalyzer.testSelectionIdentifier,
        exactTestIdentifier: "FisherExactTwoSided-v1",
        confidenceLevel: 0.95,
        logRatioIntervalIdentifier: "LogRatioCI-Katz-HA-v1",
        oddsRatioIntervalIdentifier: "OddsRatioCI-Woolf-HA-v1",
        pValueIdentifier: "ChiSquareSurvival-df1-erfc-v1",
        correctionIdentifier: "BenjaminiHochberg-v1",
        oddsRatioIdentifier: "OddsRatio-HA-v1",
        logRatioIdentifier: "LogRatio-HA-v1-base2",
        diagnosticIdentifier: "asymptotic-minimum-expected-count-v1",
        lowExpectedCountThreshold: 5,
        floatingPointDeterminismClass: "D1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
        referenceAbsoluteTolerance: 1e-12,
        orderingIdentifier: "absolute-log-ratio-descending-term-ascending-v1",
        terms: [
            keynessTerm("forte", qValue: 0.001, log2Ratio: 3, lowExpected: false),
            keynessTerm("moderato", qValue: 0.03, log2Ratio: 1.5, lowExpected: false),
            keynessTerm("cauto", qValue: 0.001, log2Ratio: 4, lowExpected: true),
            keynessTerm("escluso", qValue: 0.2, log2Ratio: 5, lowExpected: false),
        ]
    )
}

private func keynessTerm(
    _ term: String,
    qValue: Double,
    log2Ratio: Double,
    lowExpected: Bool
) -> GlifiKeynessTermResult {
    GlifiKeynessTermResult(
        term: term,
        targetFrequency: 20,
        referenceFrequency: 2,
        targetRelativeFrequency: 0.2,
        referenceRelativeFrequency: 0.02,
        gStatistic: 12,
        degreesOfFreedom: 1,
        pValue: min(qValue, 0.001),
        gTestPValue: min(qValue, 0.001),
        selectedTestIdentifier: lowExpected ? "FisherExactTwoSided-v1" : "GTest-v1",
        qValue: qValue,
        oddsRatioHaldaneAnscombe: pow(2, log2Ratio),
        log2RatioHaldaneAnscombe: log2Ratio,
        log2RatioLower: log2Ratio - 1,
        log2RatioUpper: log2Ratio + 1,
        oddsRatioLower: pow(2, log2Ratio - 1),
        oddsRatioUpper: pow(2, log2Ratio + 1),
        direction: .target,
        minimumExpectedCount: lowExpected ? 1 : 10,
        hasLowExpectedCount: lowExpected
    )
}

private func sourceRecord(
    _ revisionID: SourceRevisionID,
    byteCount: Int
) -> GlifiProjectSourceRecord {
    GlifiProjectSourceRecord(
        sourceID: SourceID(),
        sourceRevisionID: revisionID,
        format: .plainText,
        contentDigest: testDigest("8"),
        byteCount: byteCount,
        objectPath: ".objects/test"
    )
}

private func sourceRevision(_ value: String) throws -> SourceRevisionID {
    SourceRevisionID(uuid: try #require(UUID(uuidString: value)))
}

private func testDigest(_ character: Character) -> String {
    "sha256:" + String(repeating: character, count: 64)
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}

/// One distinct hexadecimal digit for synthetic digests (`0…15`).
private func hexDigit(_ value: Int) -> Character {
    Array("0123456789abcdef")[value % 16]
}

@Test("Le famiglie estese producono findings con le classi ADR-0026 e sopprimono i non eleggibili")
func extendedFamiliesProduceADR0026Findings() throws {
    let ids = try [
        "00000000-0000-0000-0000-000000000031", "00000000-0000-0000-0000-000000000032",
        "00000000-0000-0000-0000-000000000033",
    ].map(sourceRevision)
    let plan = try GlifiAnalysisPlanner().plan(
        request: GlifiAnalysisPlanRequest(intent: .exploreRelationships),
        sourceRootDigest: testDigest("0"),
        configuredLanguageCode: "it",
        sources: ids.map {
            try GlifiPlanningSource(sourceRevisionID: $0, format: .plainText, byteCount: 20)
        }
    )
    #expect(
        plan.steps.map(\.operation) == [
            .analyzeAssociation, .analyzeWindowCollocations, .analyzeWindowNetwork,
            .analyzeCorrespondence,
        ])
    // Associazione V=0,6 (d*=1) con p=0,001: strong. Collocazioni: (a=6, t=3, NPMI 0,6) strong,
    // (a=3, t=2,1, NPMI 0,3) caution per bassa frequenza, (a=2) non eleggibile.
    // Rete Q=0,35 con 12 nodi: moderate. CA con inerzie 0,5/0,3/0,2 (K=3): solo il primo asse
    // supera la media 1/3 senza raggiungere 2/3, quindi moderate; gli altri non sono eleggibili.
    let facts: [GlifiSupplementaryFacts] = [
        .association(
            cramersV: 0.6,
            minimumDimension: 2,
            monteCarloPValue: 0.001,
            lowExpectedCellFraction: 0
        ),
        .collocations([
            GlifiCollocationFact(
                node: "casa", collocate: "mare", jointCount: 6, tScore: 3, npmi: 0.6, logDice: 13),
            GlifiCollocationFact(
                node: "casa", collocate: "sole", jointCount: 3, tScore: 2.1, npmi: 0.3, logDice: 12),
            GlifiCollocationFact(
                node: "casa", collocate: "vento", jointCount: 2, tScore: 1.9, npmi: 0.4, logDice: 11
            ),
        ]),
        .network(modularity: 0.35, communityCount: 3, nodeCount: 12),
        .correspondence(inertias: [0.5, 0.3, 0.2], totalInertia: 1),
    ]
    let inputs = try zip(plan.steps, facts).enumerated().map { index, entry in
        GlifiInterpretationArtifactInput(
            planStepIdentifier: entry.0.identifier,
            role: entry.0.role,
            artifactID: try ArtifactID(digest: testDigest(hexDigit(index + 1))),
            analysisNodeID: try AnalysisNodeID(digest: testDigest(hexDigit(index + 6))),
            descriptorDigest: testDigest(hexDigit(index + 11)),
            content: .supplementary(
                outputSchemaIdentifier: entry.0.outputSchemaIdentifier,
                sourceRevisionIDs: ids,
                facts: entry.1
            )
        )
    }
    let result = try GlifiInterpretationEngine().interpret(
        planArtifactID: try ArtifactID(digest: testDigest("a")),
        planAnalysisNodeID: try AnalysisNodeID(digest: testDigest("b")),
        plan: plan,
        artifacts: inputs,
        sources: ids.map { sourceRecord($0, byteCount: 20) }
    )

    let classes = result.findings.map {
        "\($0.familyIdentifier)=\($0.assessment.supportClass.rawValue)"
    }
    #expect(
        classes.sorted() == [
            "finding-family.collocation.v1=caution", "finding-family.collocation.v1=strong",
            "finding-family.contingency.v1=strong", "finding-family.correspondence.v1=moderate",
            "finding-family.lexical-network.v1=moderate",
        ])
    #expect(result.evidence.count == 5)
    #expect(result.insufficientEvidence == nil)
    let caution = try #require(result.findings.first { $0.assessment.supportClass == .caution })
    #expect(caution.caveats.contains { $0.identifier == "caveat.caution.low-frequency" })
    #expect(caution.messageKey == "finding.collocation.pair")
    #expect(caution.messageArguments["collocate"] == "sole")
    let strongAssociation = try #require(
        result.findings.first { $0.familyIdentifier == "finding-family.contingency.v1" })
    #expect(
        strongAssociation.assessment.policyIdentifier == "support-policy.contingency-cramersv-v1")
    #expect(strongAssociation.assessment.dimensions.map(\.identifier).first == "cramers-v")
    #expect(result.findings.prefix(2).allSatisfy { $0.assessment.supportClass == .strong })
}
