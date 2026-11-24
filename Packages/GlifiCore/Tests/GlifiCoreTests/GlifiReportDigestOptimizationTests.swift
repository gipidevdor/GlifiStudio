// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("Il report completo conserva identità, contenuto e JSON del riferimento indipendente")
func reportDigestMatchesIndependentContent() throws {
    for (count, emptySelection) in [(0, false), (4, false), (4, true), (128, false)] {
        let fixture = try reportDigestFixture(count: count, emptySelection: emptySelection)
        let reference = try reportDigestReference(fixture)
        let actual = try GlifiReportRevision(
            investigation: fixture.investigation, interpretation: fixture.interpretation)
        #expect(actual == reference.report)
        #expect(actual.id == reference.id)
        #expect(try reportDigestCanonicalJSON(actual) == reference.json)
        #expect(try JSONDecoder().decode(GlifiReportRevision.self, from: reference.json) == actual)
        #expect(actual.investigationHeadEventID == fixture.investigation.headEventID)
        #expect(actual.selectedFindingIDs == fixture.investigation.selectedFindingIDs)
        if count > 0 {
            #expect(actual.findings.count < fixture.interpretation.findings.count)
            #expect(actual.evidence.count < fixture.interpretation.evidence.count)
        } else {
            #expect(actual.insufficientEvidence != nil)
        }
    }
}

@Test("Il decoder del report rifiuta identità, schema e contenuto alterati")
func reportDigestRejectsAlteredReport() throws {
    let fixture = try reportDigestFixture(count: 4)
    let reference = try reportDigestReference(fixture)
    let decoded = try JSONSerialization.jsonObject(with: reference.json)
    let original = try #require(decoded as? [String: Any])
    let replacement = try ReportRevisionID(digest: reportDigestFormatter(Data("altered-id".utf8)))
    let mutations: [(String, Any)] = [
        ("id", replacement.canonicalValue), ("question", "Domanda alterata"),
        ("schemaVersion", 2),
    ]
    for (key, value) in mutations {
        var changed = original
        changed[key] = value
        let bytes = try JSONSerialization.data(withJSONObject: changed, options: [.sortedKeys])
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(GlifiReportRevision.self, from: bytes)
        }
    }

    var reversedSelection = try reportDigestContent(fixture)
    reversedSelection.selectedFindingIDs.reverse()
    var missingEvidence = try reportDigestContent(fixture)
    missingEvidence.evidence = []
    for content in [reversedSelection, missingEvidence] {
        // Recompute the complete identity independently: validation must still reject the report.
        let invalid = try reportDigestReferenceJSON(content)
        do {
            _ = try JSONDecoder().decode(GlifiReportRevision.self, from: invalid.json)
            Issue.record("A rehashed report with inconsistent selection or evidence was accepted")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "export.invalid-report")
        }
    }
}

@Test("Il costruttore pubblico conserva il rifiuto delle Evidence non risolte")
func reportDigestRejectsUnresolvedInput() throws {
    let fixture = try reportDigestFixture(count: 4, withoutEvidence: true)
    do {
        _ = try GlifiReportRevision(
            investigation: fixture.investigation, interpretation: fixture.interpretation)
        Issue.record("A report with unresolved evidence was accepted")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "export.lineage-mismatch")
        #expect(failure.category == .staleArtifact)
    }
}

@Test("I digest dei report misurano costruzione e decodifica pubbliche soltanto su richiesta")
func reportDigestOptimizationBenchmarks() throws {
    let small = try reportDigestFixture(count: 4)
    let reference = try reportDigestReference(small)
    #expect(
        try GlifiReportRevision(
            investigation: small.investigation, interpretation: small.interpretation)
            == reference.report)
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    for (count, calls) in [(4, 128), (128, 4)] {
        let fixture = try reportDigestFixture(count: count)
        let expected = try reportDigestReference(fixture)
        let input = ReportDigestBenchmarkInput(
            events: fixture.events, eventIDs: fixture.investigation.eventIDs,
            headEventID: fixture.investigation.headEventID,
            interpretation: fixture.interpretation, calls: calls)
        try measurePipelineOptimization(
            identifier: "report-digest-init-findings\(count)-batch\(calls)",
            generator:
                "\(count) available findings, ordered subset excluding index%3==1; "
                + "\(count + 2) evidence including unused and repeated references; two history events; "
                + "Unicode, caveats, typed values and canonical JSON; \(calls) public initializers; in memory",
            fixtureDigest: try pipelineBenchmarkDigest(input),
            expected: Array(repeating: expected.report, count: calls),
            body: {
                try (0..<calls).map { _ in
                    try GlifiReportRevision(
                        investigation: fixture.investigation,
                        interpretation: fixture.interpretation)
                }
            }, checksum: { try pipelineBenchmarkDigest($0) })
        try measurePipelineOptimization(
            identifier: "report-digest-decode-findings\(count)-batch\(calls)",
            generator:
                "Complete reference report JSON for \(count) available findings; "
                + "\(calls) fresh JSONDecoder public decode calls with complete identity/closure validation; in memory",
            fixtureDigest: try pipelineBenchmarkDigest(
                ReportDigestDecodeInput(bytes: expected.json, calls: calls)),
            expected: Array(repeating: expected.report, count: calls),
            body: {
                try (0..<calls).map { _ in
                    try JSONDecoder().decode(GlifiReportRevision.self, from: expected.json)
                }
            }, checksum: { try pipelineBenchmarkDigest($0) })
    }
}

private struct ReportDigestFixture {
    let investigation: GlifiInvestigation
    let interpretation: GlifiAnalysisInterpretation
    let events: [GlifiInvestigationEvent]
}

private struct ReportDigestBenchmarkInput: Encodable {
    let events: [GlifiInvestigationEvent]
    let eventIDs: [InvestigationEventID]
    let headEventID: InvestigationEventID
    let interpretation: GlifiAnalysisInterpretation
    let calls: Int
}

private struct ReportDigestDecodeInput: Encodable {
    let bytes: Data
    let calls: Int
}

private struct ReportDigestReferenceContent: Encodable {
    let investigationID: InvestigationID
    let investigationHeadEventID: InvestigationEventID
    let question: String
    let questionLanguageCode: String
    let intent: GlifiAnalyticalIntent
    let ruleCatalogIdentifier: String
    let rankingIdentifier: String
    let planArtifactID: ArtifactID
    let interpretationArtifactID: ArtifactID
    let sourceArtifactIDs: [ArtifactID]
    var selectedFindingIDs: [FindingID]
    let findings: [GlifiFinding]
    var evidence: [GlifiEvidence]
    let insufficientEvidence: GlifiInsufficientEvidenceOutcome?
}

/// Independent flattened envelope: the semantic content alone determines the report identity.
private struct ReportDigestReferenceEnvelope: Encodable {
    let schemaIdentifier = "studio.glifi.report-revision"
    let schemaVersion = 1
    let id: ReportRevisionID
    let investigationID: InvestigationID
    let investigationHeadEventID: InvestigationEventID
    let question: String
    let questionLanguageCode: String
    let intent: GlifiAnalyticalIntent
    let ruleCatalogIdentifier: String
    let rankingIdentifier: String
    let planArtifactID: ArtifactID
    let interpretationArtifactID: ArtifactID
    let sourceArtifactIDs: [ArtifactID]
    let selectedFindingIDs: [FindingID]
    let findings: [GlifiFinding]
    let evidence: [GlifiEvidence]
    let insufficientEvidence: GlifiInsufficientEvidenceOutcome?

    init(content: ReportDigestReferenceContent, id: ReportRevisionID) {
        self.id = id
        investigationID = content.investigationID
        investigationHeadEventID = content.investigationHeadEventID
        question = content.question
        questionLanguageCode = content.questionLanguageCode
        intent = content.intent
        ruleCatalogIdentifier = content.ruleCatalogIdentifier
        rankingIdentifier = content.rankingIdentifier
        planArtifactID = content.planArtifactID
        interpretationArtifactID = content.interpretationArtifactID
        sourceArtifactIDs = content.sourceArtifactIDs
        selectedFindingIDs = content.selectedFindingIDs
        findings = content.findings
        evidence = content.evidence
        insufficientEvidence = content.insufficientEvidence
    }
}

private func reportDigestReference(_ fixture: ReportDigestFixture) throws -> (
    report: GlifiReportRevision, id: ReportRevisionID, json: Data
) {
    let reference = try reportDigestReferenceJSON(reportDigestContent(fixture))
    let report = try JSONDecoder().decode(GlifiReportRevision.self, from: reference.json)
    return (report, reference.id, reference.json)
}

private func reportDigestReferenceJSON(_ content: ReportDigestReferenceContent) throws -> (
    id: ReportRevisionID, json: Data
) {
    let digest = reportDigestFormatter(try reportDigestCanonicalJSON(content))
    let id = try ReportRevisionID(digest: digest)
    return (
        id, try reportDigestCanonicalJSON(ReportDigestReferenceEnvelope(content: content, id: id))
    )
}

private func reportDigestContent(_ fixture: ReportDigestFixture) throws
    -> ReportDigestReferenceContent
{
    let investigation = fixture.investigation
    let interpretation = fixture.interpretation
    let findings = try investigation.selectedFindingIDs.map { id in
        try #require(interpretation.findings.first { $0.id == id })
    }
    let evidence = interpretation.evidence.filter { item in
        findings.contains { $0.evidenceReferences.contains { $0.evidenceID == item.id } }
    }
    return ReportDigestReferenceContent(
        investigationID: investigation.id, investigationHeadEventID: investigation.headEventID,
        question: investigation.question, questionLanguageCode: investigation.languageCode,
        intent: investigation.intent, ruleCatalogIdentifier: interpretation.ruleCatalogIdentifier,
        rankingIdentifier: interpretation.rankingIdentifier,
        planArtifactID: interpretation.planArtifactID,
        interpretationArtifactID: investigation.interpretationArtifactID,
        sourceArtifactIDs: interpretation.sourceArtifactIDs,
        selectedFindingIDs: investigation.selectedFindingIDs, findings: findings,
        evidence: evidence,
        insufficientEvidence: interpretation.insufficientEvidence)
}

private func reportDigestFixture(
    count: Int, emptySelection: Bool = false, withoutEvidence: Bool = false
) throws -> ReportDigestFixture {
    let plan = try ArtifactID(digest: reportDigestSeed("plan"))
    let artifact = try ArtifactID(digest: reportDigestSeed("interpretation"))
    let sources = try ["source-a", "source-b"].map { try ArtifactID(digest: reportDigestSeed($0)) }
        .sorted { $0.canonicalValue < $1.canonicalValue }
    let node = try AnalysisNodeID(digest: reportDigestSeed("node"))
    let caveat = GlifiCaveat(
        identifier: "caveat.synthetic.report", severity: .warning, scope: .interpretation,
        causeIdentifier: "synthetic.fixture", consequenceIdentifier: "synthetic.only",
        actionIdentifier: nil, originIdentifier: "synthetic.report.v1")
    let evidence = try (0..<(count == 0 ? 0 : count + 2)).map { index in
        GlifiEvidence(
            id: try EvidenceID(digest: reportDigestSeed("evidence-\(index)")),
            kindIdentifier: "synthetic.report", artifactIDs: sources, analysisNodeID: node,
            descriptorDigest: reportDigestSeed("descriptor"), methodIdentifiers: ["synthetic.v1"],
            measures: [
                .init(
                    identifier: "count", value: .integer(Int64(index)),
                    unitIdentifier: "observations"),
                .init(
                    identifier: "score", value: .decimal(Double(index % 31) / 8),
                    unitIdentifier: nil),
                .init(
                    identifier: "text", value: .text("città e\u{301}/é 日本語 👩‍🔬"), unitIdentifier: nil),
                .init(
                    identifier: "flag", value: .boolean(index.isMultiple(of: 2)),
                    unitIdentifier: nil),
            ],
            uncertaintyIdentifiers: ["synthetic.no-inference"], effectSizeIdentifiers: [],
            sourceReferences: [], epistemicCategory: .observed, validity: .valid, caveats: [caveat])
    }
    let findings = try (0..<count).map { index in
        GlifiFinding(
            id: try FindingID(digest: reportDigestSeed("finding-\(index)")),
            familyIdentifier: "synthetic", typeIdentifier: "synthetic.report",
            subjectIdentifier: "corpus",
            predicateIdentifier: "observed", objectIdentifier: "synthetic",
            scopeIdentifier: "corpus",
            directionIdentifier: nil, state: .included,
            evidenceReferences: [index, (index + 1) % count, index].map { ordinal in
                GlifiFindingEvidenceReference(
                    evidenceID: evidence[ordinal].id, disposition: .supporting,
                    reasonIdentifier: nil)
            },
            assessment: .init(
                policyIdentifier: "synthetic.v1", supportClass: .descriptive, dimensions: [],
                rationaleIdentifiers: ["synthetic.fixture"]),
            caveats: [caveat], ruleSetIdentifier: "synthetic.v1",
            messageKey: "finding.synthetic.report",
            messageArguments: ["index": String(index), "text": "virgola, apice \" e città\r\nβ/é"],
            rankFactors: .init(
                rankingIdentifier: "synthetic.v1", intentRelevance: 1, supportClass: .descriptive,
                effectMagnitude: Double(index % 17) / 8, coverage: 0.5, stability: nil,
                novelty: nil,
                nonRedundancy: 1, hasCompleteLineage: true),
            epistemicCategory: .deterministicallyInterpreted)
    }
    let selected: [FindingID] =
        emptySelection
        ? []
        : (0..<count)
            .map { ($0 * 37) % count }.filter { $0 % 3 != 1 }.map { findings[$0].id }
    let investigationID = try InvestigationID(
        canonicalValue: "investigation:00000000-0000-0000-0000-000000000179")
    let creation = try GlifiInvestigationEvent(
        investigationID: investigationID, predecessorEventID: nil, recordedAtUnixMilliseconds: 0,
        actor: .localPerson,
        payload: .created(
            question: "Domanda sintetica: città e\u{301}/é, 日本語 👩‍🔬?", languageCode: "it",
            intent: .understandCollection, planArtifactID: plan, interpretationArtifactID: artifact,
            availableFindingIDs: findings.map(\.id), selectedFindingIDs: findings.map(\.id)))
    let creationID = try creation.eventID()
    let selection = try GlifiInvestigationEvent(
        investigationID: investigationID, predecessorEventID: creationID,
        recordedAtUnixMilliseconds: 1,
        actor: .localPerson,
        payload: .editorialSelectionChanged(
            selectedFindingIDs: selected, reasonIdentifier: "synthetic.ordered-selection.v1"))
    let head = try selection.eventID()
    let investigation = try GlifiInvestigation(
        headEventID: head, eventsByID: [creationID: creation, head: selection])
    let insufficient: GlifiInsufficientEvidenceOutcome? =
        count == 0
        ? .init(
            reasonIdentifiers: ["synthetic.no-observations"], caveats: [caveat],
            messageKey: "finding.synthetic.insufficient", messageArguments: ["scope": "città/β"])
        : nil
    let interpretation = GlifiAnalysisInterpretation(
        ruleCatalogIdentifier: "synthetic.v1", rankingIdentifier: "synthetic.v1",
        intent: .understandCollection, planArtifactID: plan, planAnalysisNodeID: node,
        sourceArtifactIDs: sources, evidence: withoutEvidence ? [] : Array(evidence.reversed()),
        findings: Array(findings.reversed()), suppressionSummaries: [],
        insufficientEvidence: insufficient)
    return ReportDigestFixture(
        investigation: investigation, interpretation: interpretation, events: [creation, selection])
}

private func reportDigestSeed(_ value: String) -> String {
    reportDigestFormatter(Data(value.utf8))
}

private func reportDigestFormatter(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func reportDigestCanonicalJSON(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}
