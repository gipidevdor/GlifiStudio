// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("Il CSV conserva riferimenti condivisi e ripetuti, ordine, Unicode e protezione formula")
func csvExportOptimizationPreservesDirectReference() throws {
    try csvOptimizationReferenceRegression()
}

@Test("Il CSV deduplica per EvidenceID entro il Finding anche con disposition e reason diverse")
func csvExportOptimizationDeduplicatesEvidenceIdentityOnly() throws {
    let evidence = try csvOptimizationEvidence(index: 204)
    let references = [
        GlifiFindingEvidenceReference(
            evidenceID: evidence.id, disposition: .supporting, reasonIdentifier: nil),
        GlifiFindingEvidenceReference(
            evidenceID: evidence.id, disposition: .contrary, reasonIdentifier: "synthetic.contrary"),
        GlifiFindingEvidenceReference(
            evidenceID: evidence.id, disposition: .excluded, reasonIdentifier: "synthetic.excluded"),
    ]
    let first = try csvOptimizationFinding(index: 20, references: references)
    let second = try csvOptimizationFinding(index: 21, references: Array(references.prefix(1)))
    let report = try csvOptimizationReport(findings: [first, second], evidence: [evidence])
    let actual = try csvOptimizationPayloads(report)
    let expected = try referenceCSV(report)
    #expect(actual == expected)
    let payload = try #require(actual.first { $0.path == "evidence.csv" })
    let text = String(decoding: payload.data, as: UTF8.self)
    let firstID = first.id.canonicalValue
    let secondID = second.id.canonicalValue
    #expect(text.contains(csvOptimizationCell(firstID + "|" + secondID)))
    #expect(text.components(separatedBy: firstID).count - 1 == 1)
    #expect(text.components(separatedBy: secondID).count - 1 == 1)
}

@Test("La selezione vuota produce soli header e le Evidence mancanti restano rifiutate")
func csvExportOptimizationPreservesSelectionClosure() throws {
    let fixture = try csvOptimizationSmallFixture()
    let empty = try csvOptimizationReport(
        findings: fixture.findings, evidence: fixture.evidence, selectedFindingIDs: [])
    let actual = try csvOptimizationPayloads(empty)
    let expected = try referenceCSV(empty)
    #expect(actual == expected)
    #expect(actual.count == 2)
    for payload in actual {
        let text = String(decoding: payload.data, as: UTF8.self)
        #expect(text.components(separatedBy: "\r\n").count == 2)
    }
    do {
        _ = try csvOptimizationReport(findings: fixture.findings, evidence: [])
        Issue.record("An unresolved evidence reference produced a report")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "export.lineage-mismatch")
        #expect(failure.category == .staleArtifact)
    }
}

/// Runs a small reference regression unconditionally, then optional Release measurements.
@Test("Il renderer CSV coincide con il riferimento e misura soltanto workload espliciti")
func pipelineOptimizationCSV() throws {
    try csvOptimizationReferenceRegression()
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    for count in [256, 2_048] {
        let evidence = try (0..<count).map { try csvOptimizationEvidence(index: $0) }
        let findings = try (0..<count).reversed().map { index in
            try csvOptimizationFinding(
                index: index,
                references: (0..<4).map { offset in
                    GlifiFindingEvidenceReference(
                        evidenceID: evidence[(index + offset) % count].id,
                        disposition: .supporting, reasonIdentifier: nil)
                })
        }
        let report = try csvOptimizationReport(
            findings: findings, evidence: Array(evidence.reversed()))
        let expected = try referenceCSV(report)
        try measurePipelineOptimization(
            identifier: "csv-evidence-index-\(count)",
            generator:
                "\(count) findings and evidence; four cyclic references/finding; reversed editorial/evidence order; fixed identities; setup and direct reference excluded",
            fixtureDigest: pipelineBenchmarkDigest(report), expected: expected,
            body: { try csvOptimizationPayloads(report) },
            checksum: { try pipelineBenchmarkDigest($0) })
    }
}

private struct CSVOptimizationPayload: Encodable, Equatable {
    let path: String
    let mediaType: String
    let schema: String
    let data: Data
}

private struct CSVOptimizationFixture {
    let findings: [GlifiFinding]
    let evidence: [GlifiEvidence]
}

private func csvOptimizationReferenceRegression() throws {
    let fixture = try csvOptimizationSmallFixture()
    let report = try csvOptimizationReport(findings: fixture.findings, evidence: fixture.evidence)
    let actual = try csvOptimizationPayloads(report)
    let expected = try referenceCSV(report)
    #expect(actual == expected)
    #expect(actual.map(\.path) == ["findings.csv", "evidence.csv"])
    #expect(
        actual.map(\.schema) == [
            "studio.glifi.report-findings-csv.v1", "studio.glifi.report-evidence-csv.v1",
        ])
    #expect(actual.allSatisfy { $0.mediaType == "text/csv; charset=utf-8; header=present" })
    #expect(report.findings.map(\.id) == fixture.findings.map(\.id))
    #expect(
        report.evidence.map(\.id)
            == fixture.evidence.enumerated().filter { $0.offset != 1 }.map { $0.element.id })
    let findings = try #require(actual.first { $0.path == "findings.csv" })
    let evidence = try #require(actual.first { $0.path == "evidence.csv" })
    let findingText = String(decoding: findings.data, as: UTF8.self)
    let evidenceText = String(decoding: evidence.data, as: UTF8.self)
    let duplicateReferences = fixture.findings[0].evidenceReferences.map(
        \.evidenceID.canonicalValue
    )
    .joined(separator: "|")
    let orderedFindingIDs = fixture.findings.prefix(2).map(\.id.canonicalValue).joined(
        separator: "|")
    #expect(findingText.contains(csvOptimizationCell(duplicateReferences)))
    #expect(evidenceText.contains(csvOptimizationCell(orderedFindingIDs)))
    #expect(!evidenceText.contains(fixture.evidence[1].id.canonicalValue))
    #expect(findingText.hasSuffix("\r\n"))
    #expect(evidenceText.hasSuffix("\r\n"))
    #expect(findingText.contains("\"'=SOMMA(1,2)\""))
    #expect(findingText.contains("\"città, \"\"già\"\"\nβ\""))
    for raw in ["+città", "-città", "@città", "\tformula", "\rformula"] {
        #expect(evidenceText.contains(csvOptimizationCell(raw)))
    }
}

private func csvOptimizationSmallFixture() throws -> CSVOptimizationFixture {
    let first = try csvOptimizationEvidence(index: 0, kind: "+città")
    let unused = try csvOptimizationEvidence(index: 1, kind: "unselected.synthetic")
    let shared = try csvOptimizationEvidence(index: 2, kind: "-città")
    let firstFinding = try csvOptimizationFinding(
        index: 9, messageKey: "=SOMMA(1,2)",
        references: [shared.id, first.id, shared.id].map {
            GlifiFindingEvidenceReference(
                evidenceID: $0, disposition: .supporting, reasonIdentifier: nil)
        })
    let secondFinding = try csvOptimizationFinding(
        index: 3, messageKey: "città, \"già\"\nβ",
        references: [first.id, shared.id].map {
            GlifiFindingEvidenceReference(
                evidenceID: $0, disposition: .supporting, reasonIdentifier: nil)
        })
    let noReferences = try csvOptimizationFinding(index: 7, references: [])
    let additional = try ["@città", "\tformula", "\rformula"].enumerated().map { offset, kind in
        try csvOptimizationEvidence(index: 10 + offset, kind: kind)
    }
    let extraFinding = try csvOptimizationFinding(
        index: 12,
        references: additional.map {
            GlifiFindingEvidenceReference(
                evidenceID: $0.id, disposition: .supporting, reasonIdentifier: nil)
        })
    return CSVOptimizationFixture(
        findings: [firstFinding, secondFinding, noReferences, extraFinding],
        evidence: [shared, unused, first] + additional)
}

private func csvOptimizationEvidence(index: Int, kind: String = "synthetic.csv") throws
    -> GlifiEvidence
{
    GlifiEvidence(
        id: try EvidenceID(digest: csvOptimizationDigest("evidence-\(index)")),
        kindIdentifier: kind,
        artifactIDs: [try ArtifactID(digest: csvOptimizationDigest("artifact"))],
        analysisNodeID: try AnalysisNodeID(digest: csvOptimizationDigest("node")),
        descriptorDigest: csvOptimizationDigest("descriptor"), methodIdentifiers: ["synthetic.v1"],
        measures: [], uncertaintyIdentifiers: [], effectSizeIdentifiers: [], sourceReferences: [],
        epistemicCategory: .observed, validity: .valid, caveats: [])
}

private func csvOptimizationFinding(
    index: Int, messageKey: String = "finding.synthetic.csv",
    references: [GlifiFindingEvidenceReference]
) throws -> GlifiFinding {
    GlifiFinding(
        id: try FindingID(digest: csvOptimizationDigest("finding-\(index)")),
        familyIdentifier: "synthetic", typeIdentifier: "synthetic.csv",
        subjectIdentifier: "synthetic",
        predicateIdentifier: "observed", objectIdentifier: "synthetic",
        scopeIdentifier: "synthetic",
        directionIdentifier: nil, state: .included, evidenceReferences: references,
        assessment: GlifiEvidenceAssessment(
            policyIdentifier: "synthetic.v1", supportClass: .descriptive, dimensions: [],
            rationaleIdentifiers: []),
        caveats: [], ruleSetIdentifier: "synthetic.v1", messageKey: messageKey,
        messageArguments: ["text": "virgola, apice \" e Unicode città\nβ"],
        rankFactors: GlifiEditorialRankFactors(
            rankingIdentifier: "synthetic.v1", intentRelevance: 1, supportClass: .descriptive,
            effectMagnitude: nil, coverage: nil, stability: nil, novelty: nil,
            nonRedundancy: 1, hasCompleteLineage: true),
        epistemicCategory: .deterministicallyInterpreted)
}

private func csvOptimizationReport(
    findings: [GlifiFinding], evidence: [GlifiEvidence], selectedFindingIDs: [FindingID]? = nil
) throws -> GlifiReportRevision {
    let plan = try ArtifactID(digest: csvOptimizationDigest("plan"))
    let artifact = try ArtifactID(digest: csvOptimizationDigest("artifact"))
    let event = try GlifiInvestigationEvent(
        investigationID: InvestigationID(
            canonicalValue: "investigation:00000000-0000-0000-0000-000000000204"),
        predecessorEventID: nil, recordedAtUnixMilliseconds: 0, actor: .localPerson,
        payload: .created(
            question: "Domanda sintetica CSV", languageCode: "it", intent: .understandCollection,
            planArtifactID: plan, interpretationArtifactID: artifact,
            availableFindingIDs: findings.map(\.id),
            selectedFindingIDs: selectedFindingIDs ?? findings.map(\.id)))
    let eventID = try event.eventID()
    let investigation = try GlifiInvestigation(headEventID: eventID, eventsByID: [eventID: event])
    let interpretation = GlifiAnalysisInterpretation(
        ruleCatalogIdentifier: "synthetic.v1", rankingIdentifier: "synthetic.v1",
        intent: .understandCollection, planArtifactID: plan,
        planAnalysisNodeID: try AnalysisNodeID(digest: csvOptimizationDigest("node")),
        sourceArtifactIDs: [artifact], evidence: evidence, findings: findings,
        suppressionSummaries: [], insufficientEvidence: nil)
    return try GlifiReportRevision(investigation: investigation, interpretation: interpretation)
}

private func csvOptimizationPayloads(_ report: GlifiReportRevision) throws
    -> [CSVOptimizationPayload]
{
    try GlifiScientificExportRenderer.csvPayloads(report).map {
        CSVOptimizationPayload(
            path: $0.path, mediaType: $0.mediaType, schema: $0.schema, data: $0.data)
    }
}

// Direct reference preserves the original filter/contains definition and CSV contract.
private func referenceCSV(_ report: GlifiReportRevision) throws -> [CSVOptimizationPayload] {
    let findingRows = try report.findings.enumerated().map { ordinal, finding in
        [
            String(ordinal + 1), finding.id.canonicalValue, finding.messageKey,
            finding.evidenceReferences.map(\.evidenceID.canonicalValue).joined(separator: "|"),
            finding.caveats.map(\.identifier).joined(separator: "|"),
            String(decoding: try GlifiExportCanonicalJSON.encode(finding), as: UTF8.self),
        ]
    }
    let evidenceRows = try report.evidence.enumerated().map { ordinal, evidence in
        [
            String(ordinal + 1), evidence.id.canonicalValue, evidence.kindIdentifier,
            report.findings.filter { finding in
                finding.evidenceReferences.contains { $0.evidenceID == evidence.id }
            }.map(\.id.canonicalValue).joined(separator: "|"),
            evidence.artifactIDs.map(\.canonicalValue).joined(separator: "|"),
            evidence.caveats.map(\.identifier).joined(separator: "|"),
            String(decoding: try GlifiExportCanonicalJSON.encode(evidence), as: UTF8.self),
        ]
    }
    return [
        CSVOptimizationPayload(
            path: "findings.csv", mediaType: "text/csv; charset=utf-8; header=present",
            schema: "studio.glifi.report-findings-csv.v1",
            data: csvOptimizationData(
                header: [
                    "ordinal", "finding_id", "message_key", "evidence_ids", "caveat_ids",
                    "payload_json",
                ],
                rows: findingRows)),
        CSVOptimizationPayload(
            path: "evidence.csv", mediaType: "text/csv; charset=utf-8; header=present",
            schema: "studio.glifi.report-evidence-csv.v1",
            data: csvOptimizationData(
                header: [
                    "ordinal", "evidence_id", "kind", "finding_ids", "artifact_ids", "caveat_ids",
                    "payload_json",
                ],
                rows: evidenceRows)),
    ]
}

private func csvOptimizationData(header: [String], rows: [[String]]) -> Data {
    let lines = ([header] + rows).map { $0.map(csvOptimizationCell).joined(separator: ",") }
    return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
}

private func csvOptimizationCell(_ raw: String) -> String {
    let protected: String
    if let first = raw.first, "=+-@".contains(first) || first == "\t" || first == "\r" {
        protected = "'" + raw
    } else {
        protected = raw
    }
    return "\"" + protected.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

private func csvOptimizationDigest(_ label: String) -> String {
    pipelineBenchmarkDigest(Data(label.utf8))
}
