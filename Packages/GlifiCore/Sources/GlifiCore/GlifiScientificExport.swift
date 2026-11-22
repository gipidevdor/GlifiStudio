// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Darwin
import Foundation

/// Scientific file formats emitted by the bounded export pipeline.
public enum GlifiScientificExportFormat: String, Codable, CaseIterable, Equatable, Sendable {
    /// Lossless tabular projections of selected findings and evidence.
    case csv
    /// Canonical machine-readable report revision.
    case json
    /// Escaped human-readable report projection.
    case markdown
    /// Searchable, tagged, archival human-readable report.
    case pdf
}

/// Bounded request for exporting one exact investigation branch.
public struct GlifiScientificExportRequest: Equatable, Sendable {
    /// Exact investigation branch to export.
    public let investigationHeadEventID: InvestigationEventID
    /// Non-empty, unique output formats.
    public let formats: [GlifiScientificExportFormat]
    /// Locale used only by the human-readable projection.
    public let presentationLocaleIdentifier: String
    /// Time zone used only by human-readable presentation metadata.
    public let presentationTimeZoneIdentifier: String

    /// Creates a request supported by the current Italian/English renderer.
    public init(
        investigationHeadEventID: InvestigationEventID,
        formats: [GlifiScientificExportFormat] = [.json, .markdown],
        presentationLocaleIdentifier: String = "it-IT",
        presentationTimeZoneIdentifier: String = "Europe/Rome"
    ) throws {
        let language = presentationLocaleIdentifier.split(separator: "-").first?.lowercased()
        guard !formats.isEmpty,
            formats.count <= GlifiScientificExportFormat.allCases.count,
            Set(formats).count == formats.count,
            language == "it" || language == "en",
            presentationLocaleIdentifier.utf8.count <= 64,
            TimeZone(identifier: presentationTimeZoneIdentifier) != nil,
            presentationTimeZoneIdentifier.utf8.count <= 128
        else {
            throw exportFailure(
                "export.invalid-request",
                category: .invalidInput,
                retainedState: .unchanged
            )
        }
        self.investigationHeadEventID = investigationHeadEventID
        self.formats = formats.sorted { $0.rawValue < $1.rawValue }
        self.presentationLocaleIdentifier = presentationLocaleIdentifier
        self.presentationTimeZoneIdentifier = presentationTimeZoneIdentifier
    }
}

/// Immutable report derived only from one investigation head and its verified interpretation.
public struct GlifiReportRevision: Codable, Equatable, Sendable {
    /// Stable report schema.
    public static let schemaIdentifier = "studio.glifi.report-revision"
    /// Current report schema version.
    public static let schemaVersion = 1

    /// Stable schema encoded with the report.
    public let schemaIdentifier: String
    /// Schema version encoded with the report.
    public let schemaVersion: Int
    /// Content identity of the complete semantic report.
    public let id: ReportRevisionID
    /// Investigation aggregate that owns the source branch.
    public let investigationID: InvestigationID
    /// Exact immutable branch head projected by this report.
    public let investigationHeadEventID: InvestigationEventID
    /// Original research question.
    public let question: String
    /// Language of the original research question.
    public let questionLanguageCode: String
    /// Stable analytical intention.
    public let intent: GlifiAnalyticalIntent
    /// Rule catalog that produced the represented findings.
    public let ruleCatalogIdentifier: String
    /// Editorial ranking contract used by the interpretation.
    public let rankingIdentifier: String
    /// Persisted plan governing the represented results.
    public let planArtifactID: ArtifactID
    /// Persisted interpretation from which the report was projected.
    public let interpretationArtifactID: ArtifactID
    /// Canonically ordered source analysis artifacts.
    public let sourceArtifactIDs: [ArtifactID]
    /// Ordered editorial selection retained even when empty.
    public let selectedFindingIDs: [FindingID]
    /// Selected immutable findings in editorial order.
    public let findings: [GlifiFinding]
    /// Exact evidence closure required by the selected findings.
    public let evidence: [GlifiEvidence]
    /// Explicit valid outcome when the interpretation has no positive finding.
    public let insufficientEvidence: GlifiInsufficientEvidenceOutcome?

    /// Projects a report and rejects unresolved or substituted finding/evidence identities.
    public init(
        investigation: GlifiInvestigation,
        interpretation: GlifiAnalysisInterpretation
    ) throws {
        var findingsByID: [FindingID: GlifiFinding] = [:]
        for finding in interpretation.findings {
            guard findingsByID.updateValue(finding, forKey: finding.id) == nil else {
                throw exportFailure("export.invalid-report")
            }
        }
        let selectedFindings = try investigation.selectedFindingIDs.map { findingID in
            guard let finding = findingsByID[findingID] else {
                throw exportFailure("export.finding-not-found", category: .staleArtifact)
            }
            return finding
        }
        let requiredEvidenceIDs = Set(
            selectedFindings.flatMap { finding in
                finding.evidenceReferences.map(\.evidenceID)
            }
        )
        let selectedEvidence = interpretation.evidence.filter {
            requiredEvidenceIDs.contains($0.id)
        }
        guard Set(selectedEvidence.map(\.id)) == requiredEvidenceIDs,
            investigation.intent == interpretation.intent,
            investigation.planArtifactID == interpretation.planArtifactID
        else {
            throw exportFailure("export.lineage-mismatch", category: .staleArtifact)
        }
        let content = Content(
            investigationID: investigation.id,
            investigationHeadEventID: investigation.headEventID,
            question: investigation.question,
            questionLanguageCode: investigation.languageCode,
            intent: investigation.intent,
            ruleCatalogIdentifier: interpretation.ruleCatalogIdentifier,
            rankingIdentifier: interpretation.rankingIdentifier,
            planArtifactID: interpretation.planArtifactID,
            interpretationArtifactID: investigation.interpretationArtifactID,
            sourceArtifactIDs: interpretation.sourceArtifactIDs,
            selectedFindingIDs: investigation.selectedFindingIDs,
            findings: selectedFindings,
            evidence: selectedEvidence,
            insufficientEvidence: interpretation.insufficientEvidence
        )
        try Self.validate(content)
        schemaIdentifier = Self.schemaIdentifier
        schemaVersion = Self.schemaVersion
        id = try Self.identity(for: content)
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

    private struct Content: Codable, Equatable {
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
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, id, investigationID
        case investigationHeadEventID, question, questionLanguageCode, intent
        case ruleCatalogIdentifier, rankingIdentifier, planArtifactID
        case interpretationArtifactID, sourceArtifactIDs, selectedFindingIDs
        case findings, evidence, insufficientEvidence
    }

    /// Decodes and revalidates the complete report identity and evidence closure.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(ReportRevisionID.self, forKey: .id)
        investigationID = try container.decode(InvestigationID.self, forKey: .investigationID)
        investigationHeadEventID = try container.decode(
            InvestigationEventID.self,
            forKey: .investigationHeadEventID
        )
        question = try container.decode(String.self, forKey: .question)
        questionLanguageCode = try container.decode(String.self, forKey: .questionLanguageCode)
        intent = try container.decode(GlifiAnalyticalIntent.self, forKey: .intent)
        ruleCatalogIdentifier = try container.decode(
            String.self,
            forKey: .ruleCatalogIdentifier
        )
        rankingIdentifier = try container.decode(String.self, forKey: .rankingIdentifier)
        planArtifactID = try container.decode(ArtifactID.self, forKey: .planArtifactID)
        interpretationArtifactID = try container.decode(
            ArtifactID.self,
            forKey: .interpretationArtifactID
        )
        sourceArtifactIDs = try container.decode([ArtifactID].self, forKey: .sourceArtifactIDs)
        selectedFindingIDs = try container.decode([FindingID].self, forKey: .selectedFindingIDs)
        findings = try container.decode([GlifiFinding].self, forKey: .findings)
        evidence = try container.decode([GlifiEvidence].self, forKey: .evidence)
        insufficientEvidence = try container.decodeIfPresent(
            GlifiInsufficientEvidenceOutcome.self,
            forKey: .insufficientEvidence
        )
        let content = Content(
            investigationID: investigationID,
            investigationHeadEventID: investigationHeadEventID,
            question: question,
            questionLanguageCode: questionLanguageCode,
            intent: intent,
            ruleCatalogIdentifier: ruleCatalogIdentifier,
            rankingIdentifier: rankingIdentifier,
            planArtifactID: planArtifactID,
            interpretationArtifactID: interpretationArtifactID,
            sourceArtifactIDs: sourceArtifactIDs,
            selectedFindingIDs: selectedFindingIDs,
            findings: findings,
            evidence: evidence,
            insufficientEvidence: insufficientEvidence
        )
        guard schemaIdentifier == Self.schemaIdentifier,
            schemaVersion == Self.schemaVersion,
            id == (try Self.identity(for: content))
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Invalid report revision"
            )
        }
        try Self.validate(content)
    }

    private static func validate(_ content: Content) throws {
        let findingIDs = content.findings.map(\.id)
        let evidenceIDs = content.evidence.map(\.id)
        let requiredEvidenceIDs = Set(
            content.findings.flatMap { $0.evidenceReferences.map(\.evidenceID) }
        )
        let orderedSourceArtifactIDs = content.sourceArtifactIDs.sorted {
            $0.canonicalValue < $1.canonicalValue
        }
        guard !content.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            content.question.utf8.count <= 32_768,
            !content.ruleCatalogIdentifier.isEmpty,
            !content.rankingIdentifier.isEmpty,
            content.selectedFindingIDs == findingIDs,
            Set(findingIDs).count == findingIDs.count,
            Set(evidenceIDs).count == evidenceIDs.count,
            Set(evidenceIDs) == requiredEvidenceIDs,
            Set(content.sourceArtifactIDs).count == content.sourceArtifactIDs.count,
            content.sourceArtifactIDs == orderedSourceArtifactIDs
        else {
            throw exportFailure("export.invalid-report")
        }
    }

    private static func identity(for content: Content) throws -> ReportRevisionID {
        try ReportRevisionID(digest: digest(GlifiExportCanonicalJSON.encode(content)))
    }
}

/// Canonical inventory and provenance contract accompanying every scientific export.
public struct GlifiExportManifest: Codable, Equatable, Sendable {
    /// Stable export-manifest schema.
    public static let schema = "studio.glifi.export-manifest"
    /// Current export-manifest schema version.
    public static let schemaVersion = 1

    /// Stable schema encoded in the manifest.
    public let schema: String
    /// Schema version encoded in the manifest.
    public let schemaVersion: Int
    /// UUID used only for audit and receipt correlation.
    public let exportID: String
    /// RFC 3339 UTC creation time excluded from scientific identity.
    public let createdAt: String
    /// Product and source-build provenance.
    public let software: Software
    /// Anonymous runtime platform provenance.
    public let platform: Platform
    /// Exact project generation exported.
    public let project: Project
    /// Canonical corpus selection and content digests.
    public let corpus: Corpus
    /// Exact analytical artifact and complete descriptor.
    public let analysis: Analysis
    /// Ordered preprocessing chain.
    public let preprocessing: [PreprocessingStep]
    /// Backend and numeric policy.
    public let backend: Backend
    /// Reproducibility class and variability contract.
    public let determinism: Determinism
    /// Explicit exported investigation selection.
    public let selection: Selection
    /// Sorted inventory of payload files, excluding this manifest.
    public let files: [FileRecord]
    /// Complete input lineage and applicable caveats.
    public let provenance: Provenance
    /// Candidate validation reference and evidence identifiers.
    public let validation: Validation
    /// Human-presentation parameters only.
    public let presentation: Presentation

    /// Product build provenance without user or device identity.
    public struct Software: Codable, Equatable, Sendable {
        /// Product name.
        public let name: String
        /// Marketing version.
        public let version: String
        /// Build number.
        public let build: String
        /// Source revision when the build provides one.
        public let sourceRevision: String?
    }

    /// Anonymous execution environment used for the export.
    public struct Platform: Codable, Equatable, Sendable {
        /// Operating-system family.
        public let system: String
        /// Operating-system version string.
        public let version: String
        /// Process architecture.
        public let architecture: String
        /// Declared compiler/toolchain baseline.
        public let toolchain: String
    }

    /// Authoritative project generation reference.
    public struct Project: Codable, Equatable, Sendable {
        /// Opaque project identity.
        public let id: String
        /// Monotonic project generation.
        public let generation: Int
        /// Digest of the authoritative generation record.
        public let manifestDigest: String
    }

    /// One immutable source in the canonical corpus selection.
    public struct CorpusSource: Codable, Equatable, Sendable {
        /// Opaque source-revision identity.
        public let id: String
        /// Digest of the exact immutable source bytes.
        public let contentDigest: String
    }

    /// Canonical selected corpus without paths or display names.
    public struct Corpus: Codable, Equatable, Sendable {
        /// Corpus identity used by the analytical descriptor.
        public let id: String
        /// Digest of the canonical ordered source selection.
        public let digest: String
        /// Digest algorithm.
        public let digestAlgorithm: String
        /// Corpus-digest contract version.
        public let digestVersion: Int
        /// Source revisions ordered by opaque identity.
        public let sources: [CorpusSource]
    }

    /// Algorithm identifier and logical version.
    public struct Algorithm: Codable, Equatable, Sendable {
        /// Stable algorithm identifier.
        public let id: String
        /// Logical algorithm version.
        public let version: String
    }

    /// Exported analytical result and its complete semantic descriptor.
    public struct Analysis: Codable, Equatable, Sendable {
        /// Immutable analysis artifact identity.
        public let artifactID: String
        /// Complete descriptor digest.
        public let descriptorDigest: String
        /// Complete validated descriptor.
        public let descriptor: GlifiAnalysisDescriptor
        /// Algorithm identity projected for simple consumers.
        public let algorithm: Algorithm
        /// Fully resolved canonical parameters.
        public let parameters: [String: GlifiAnalysisValue]
    }

    /// One declared preprocessing transformation.
    public struct PreprocessingStep: Codable, Equatable, Sendable {
        /// Stable transformation identifier.
        public let id: String
        /// Logical contract version.
        public let version: String
        /// Canonical parameters, empty only when none apply.
        public let parameters: [String: GlifiAnalysisValue]
        /// Digest of the complete transformation declaration.
        public let digest: String
    }

    /// Runtime backend declaration.
    public struct Backend: Codable, Equatable, Sendable {
        /// Stable backend identifier.
        public let id: String
        /// Logical backend version.
        public let version: String
        /// Exact numeric policy.
        public let numericPolicy: String
        /// Model digest when a model is applicable.
        public let modelDigest: String?
        /// Seed contract when applicable.
        public let seed: String?
    }

    /// Declared reproducibility characteristics.
    public struct Determinism: Codable, Equatable, Sendable {
        /// D0, D1, P1, or N1.
        public let `class`: String
        /// Canonical tolerance declaration when applicable.
        public let tolerances: [String: GlifiAnalysisValue]?
        /// Explicit variability sources, empty for deterministic output.
        public let sourcesOfVariability: [String]
    }

    /// Exact report and investigation selection exported.
    public struct Selection: Codable, Equatable, Sendable {
        /// Stable selection kind.
        public let kind: String
        /// Opaque investigation identity.
        public let investigationID: String
        /// Exact immutable branch head.
        public let investigationHeadEventID: String
        /// Content-addressed report revision.
        public let reportRevisionID: String
        /// Ordered selected findings.
        public let selectedFindingIDs: [String]
        /// Canonical additional filters.
        public let filters: [String]
    }

    /// One generated payload file covered by the manifest.
    public struct FileRecord: Codable, Equatable, Sendable {
        /// Safe generated relative path.
        public let path: String
        /// IANA media type.
        public let mediaType: String
        /// Versioned content schema.
        public let schema: String
        /// Exact byte count.
        public let byteCount: Int
        /// SHA-256 digest of the exact bytes.
        public let sha256: String
    }

    /// Input closure and structured limitations.
    public struct Provenance: Codable, Equatable, Sendable {
        /// Immutable input artifact identities.
        public let inputs: [String]
        /// Digest of the complete canonical lineage declaration.
        public let lineageDigest: String
        /// Applicable caveats without localized prose.
        public let caveats: [GlifiCaveat]
    }

    /// Reference to the applicable machine validation record.
    public struct Validation: Codable, Equatable, Sendable {
        /// Stable validation-manifest identifier.
        public let manifestID: String
        /// Digest of the represented validation declaration.
        public let manifestDigest: String
        /// Experimental, candidate, supported, or suspended.
        public let status: String
        /// Applicable repository evidence identifiers.
        public let evidence: [String]
    }

    /// Locale and time zone used only by human-readable files.
    public struct Presentation: Codable, Equatable, Sendable {
        /// Locale actually used by the renderer.
        public let locale: String
        /// Time-zone identifier actually used by the renderer.
        public let timeZone: String
    }

    /// Decodes and validates schema, ordering, digests, paths, and descriptor identity.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(String.self, forKey: .schema)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportID = try container.decode(String.self, forKey: .exportID)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        software = try container.decode(Software.self, forKey: .software)
        platform = try container.decode(Platform.self, forKey: .platform)
        project = try container.decode(Project.self, forKey: .project)
        corpus = try container.decode(Corpus.self, forKey: .corpus)
        analysis = try container.decode(Analysis.self, forKey: .analysis)
        preprocessing = try container.decode([PreprocessingStep].self, forKey: .preprocessing)
        backend = try container.decode(Backend.self, forKey: .backend)
        determinism = try container.decode(Determinism.self, forKey: .determinism)
        selection = try container.decode(Selection.self, forKey: .selection)
        files = try container.decode([FileRecord].self, forKey: .files)
        provenance = try container.decode(Provenance.self, forKey: .provenance)
        validation = try container.decode(Validation.self, forKey: .validation)
        presentation = try container.decode(Presentation.self, forKey: .presentation)
        try validate()
    }

    fileprivate init(
        exportID: String,
        createdAt: String,
        software: Software,
        platform: Platform,
        project: Project,
        corpus: Corpus,
        analysis: Analysis,
        preprocessing: [PreprocessingStep],
        backend: Backend,
        determinism: Determinism,
        selection: Selection,
        files: [FileRecord],
        provenance: Provenance,
        validation: Validation,
        presentation: Presentation
    ) throws {
        schema = Self.schema
        schemaVersion = Self.schemaVersion
        self.exportID = exportID
        self.createdAt = createdAt
        self.software = software
        self.platform = platform
        self.project = project
        self.corpus = corpus
        self.analysis = analysis
        self.preprocessing = preprocessing
        self.backend = backend
        self.determinism = determinism
        self.selection = selection
        self.files = files
        self.provenance = provenance
        self.validation = validation
        self.presentation = presentation
        try validate()
    }

    private func validate() throws {
        let filePaths = files.map(\.path)
        let fileNames = Set(filePaths)
        let sourceIDs = corpus.sources.map(\.id)
        let corpusDigestMatches = corpus.digest == (try Self.corpusDigest(corpus))
        let preprocessingDigestsMatch = try preprocessing.allSatisfy { step in
            step.digest == (try Self.preprocessingDigest(step))
        }
        let lineageDigestMatches = provenance.lineageDigest == (try Self.lineageDigest(self))
        let validationDigestMatches =
            validation.manifestDigest == (try Self.validationDigest(self))
        guard schema == Self.schema,
            schemaVersion == Self.schemaVersion,
            UUID(uuidString: exportID) != nil,
            ISO8601DateFormatter().date(from: createdAt) != nil,
            project.generation >= 0,
            isExportDigest(project.manifestDigest),
            isExportDigest(corpus.digest),
            corpus.digestAlgorithm == "SHA-256",
            corpus.digestVersion == 1,
            corpusDigestMatches,
            sourceIDs == sourceIDs.sorted(),
            Set(sourceIDs).count == sourceIDs.count,
            corpus.sources.allSatisfy({ isExportDigest($0.contentDigest) }),
            analysis.descriptorDigest == (try analysis.descriptor.canonicalDigest()),
            analysis.algorithm.id == analysis.descriptor.algorithmIdentifier,
            analysis.algorithm.version == analysis.descriptor.algorithmVersion,
            analysis.parameters == analysis.descriptor.resolvedParameters,
            preprocessingDigestsMatch,
            !files.isEmpty,
            filePaths == filePaths.sorted(),
            Set(filePaths).count == filePaths.count,
            files.allSatisfy({ Self.safeRelativePath($0.path) }),
            files.allSatisfy({ Self.validFileContract($0) }),
            fileNames.contains("findings.csv") == fileNames.contains("evidence.csv"),
            files.allSatisfy({
                $0.byteCount >= 0 && isExportDigest($0.sha256)
                    && !$0.mediaType.isEmpty && !$0.schema.isEmpty
            }),
            files.allSatisfy({ $0.path != "export-manifest.json" }),
            isExportDigest(provenance.lineageDigest),
            lineageDigestMatches,
            provenance.inputs == provenance.inputs.sorted(),
            Set(provenance.inputs).count == provenance.inputs.count,
            isExportDigest(validation.manifestDigest),
            validationDigestMatches,
            validation.manifestID
                == "validation:\(analysis.algorithm.id):\(validation.status)-v1",
            ["experimental", "candidate", "supported", "suspended"].contains(
                validation.status
            ),
            validation.evidence == validation.evidence.sorted(),
            Set(validation.evidence).count == validation.evidence.count,
            TimeZone(identifier: presentation.timeZone) != nil
        else {
            throw exportFailure("export.invalid-manifest")
        }
    }

    private static func safeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("/") && !path.contains("\\")
            && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
                !$0.isEmpty && $0 != "." && $0 != ".."
            }
    }

    private static func validFileContract(_ file: FileRecord) -> Bool {
        let contract: (mediaType: String, schema: String)?
        switch file.path {
        case "evidence.csv":
            contract = (
                "text/csv; charset=utf-8; header=present",
                "studio.glifi.report-evidence-csv.v1"
            )
        case "findings.csv":
            contract = (
                "text/csv; charset=utf-8; header=present",
                "studio.glifi.report-findings-csv.v1"
            )
        case "report.json":
            contract = ("application/json", GlifiReportRevision.schemaIdentifier)
        case "report.md":
            contract = ("text/markdown; charset=utf-8", "studio.glifi.report-markdown.v1")
        case "report.pdf":
            contract = ("application/pdf", "studio.glifi.report-pdf-a2u.v1")
        default:
            contract = nil
        }
        return contract?.mediaType == file.mediaType && contract?.schema == file.schema
    }

    private static func corpusDigest(_ corpus: Corpus) throws -> String {
        struct Input: Encodable {
            let digestVersion: Int
            let sources: [CorpusSource]
        }
        return digest(
            try GlifiExportCanonicalJSON.encode(
                Input(digestVersion: corpus.digestVersion, sources: corpus.sources)
            )
        )
    }

    private static func preprocessingDigest(_ step: PreprocessingStep) throws -> String {
        struct Declaration: Encodable {
            let id: String
            let version: String
            let parameters: [String: GlifiAnalysisValue]
        }
        return digest(
            try GlifiExportCanonicalJSON.encode(
                Declaration(id: step.id, version: step.version, parameters: step.parameters)
            )
        )
    }

    private static func lineageDigest(_ manifest: GlifiExportManifest) throws -> String {
        struct Lineage: Encodable {
            let investigationHeadEventID: String
            let reportRevisionID: String
            let inputs: [String]
        }
        return digest(
            try GlifiExportCanonicalJSON.encode(
                Lineage(
                    investigationHeadEventID: manifest.selection.investigationHeadEventID,
                    reportRevisionID: manifest.selection.reportRevisionID,
                    inputs: manifest.provenance.inputs
                )
            )
        )
    }

    private static func validationDigest(_ manifest: GlifiExportManifest) throws -> String {
        struct Declaration: Encodable {
            let methodIdentifier: String
            let status: String
            let evidence: [String]
        }
        return digest(
            try GlifiExportCanonicalJSON.encode(
                Declaration(
                    methodIdentifier: manifest.analysis.algorithm.id,
                    status: manifest.validation.status,
                    evidence: manifest.validation.evidence
                )
            )
        )
    }
}

/// Receipt returned only after every export byte and digest has been verified.
public struct GlifiExportReceipt: Codable, Equatable, Sendable {
    /// Audit UUID shared with the manifest.
    public let exportID: String
    /// Content identity of the exported report revision.
    public let reportRevisionID: ReportRevisionID
    /// Digest of the exact canonical manifest bytes.
    public let manifestDigest: String
    /// Number of generated payload files, excluding the manifest.
    public let fileCount: Int
}

struct GlifiExportEnvironment: Equatable, Sendable {
    let software: GlifiExportManifest.Software
    let platform: GlifiExportManifest.Platform

    static var current: Self {
        #if os(macOS)
            let system = "macOS"
        #elseif os(iOS)
            let system = "iPadOS"
        #else
            let system = "unknown"
        #endif
        #if arch(arm64)
            let architecture = "arm64"
        #elseif arch(x86_64)
            let architecture = "x86_64"
        #else
            let architecture = "unknown"
        #endif
        return Self(
            software: .init(
                name: "Glifi Studio",
                version: "0.1.0",
                build: "1",
                sourceRevision: nil
            ),
            platform: .init(
                system: system,
                version: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: architecture,
                toolchain: "Apple Swift 6.4 / Xcode 27"
            )
        )
    }
}

enum GlifiExportInterruption: String, Sendable, CaseIterable {
    case payloadsWritten
    case manifestWritten
    case stagingValidated
    case destinationCommitted
}

enum GlifiExportInterruptionBehavior: Sendable {
    case throwFailure
    case invoke(@Sendable () -> Never)
}

struct GlifiScientificExporter: Sendable {
    static let manifestFileName = "export-manifest.json"
    static let maximumFileByteCount = 67_108_864

    func export(
        snapshot: GlifiProjectSnapshot,
        investigation: GlifiInvestigation,
        interpretationRecord: GlifiProjectArtifactRecord,
        interpretation: GlifiAnalysisInterpretation,
        request: GlifiScientificExportRequest,
        to destinationURL: URL,
        environment: GlifiExportEnvironment = .current,
        exportID: UUID = UUID(),
        createdAt: Date = Date(),
        interruption: GlifiExportInterruption? = nil,
        interruptionBehavior: GlifiExportInterruptionBehavior = .throwFailure
    ) throws -> GlifiExportReceipt {
        let report = try GlifiReportRevision(
            investigation: investigation,
            interpretation: interpretation
        )
        let destination = destinationURL.standardizedFileURL
        let fileManager = FileManager.default
        try validateDestination(destination)
        let staging = destination.deletingLastPathComponent().appending(
            path: ".\(destination.lastPathComponent).exporting-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        do {
            try fileManager.createDirectory(
                at: staging,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
            var payloads: [GlifiScientificExportPayload] = []
            for format in request.formats {
                switch format {
                case .csv:
                    payloads += try GlifiScientificExportRenderer.csvPayloads(report)
                case .json:
                    payloads.append(
                        GlifiScientificExportPayload(
                            path: "report.json",
                            mediaType: "application/json",
                            schema: GlifiReportRevision.schemaIdentifier,
                            data: try GlifiExportCanonicalJSON.encode(report)
                        )
                    )
                case .markdown:
                    payloads.append(
                        GlifiScientificExportPayload(
                            path: "report.md",
                            mediaType: "text/markdown; charset=utf-8",
                            schema: "studio.glifi.report-markdown.v1",
                            data: Data(
                                markdown(
                                    report,
                                    localeIdentifier: request.presentationLocaleIdentifier
                                ).utf8
                            )
                        )
                    )
                case .pdf:
                    payloads.append(
                        try GlifiScientificExportRenderer.pdfPayload(
                            report,
                            localeIdentifier: request.presentationLocaleIdentifier,
                            createdAt: createdAt
                        )
                    )
                }
            }
            for payload in payloads {
                guard payload.data.count <= Self.maximumFileByteCount else {
                    throw exportFailure(
                        "export.file-too-large",
                        category: .insufficientResources,
                        retainedState: .unchanged
                    )
                }
                try payload.data.write(
                    to: staging.appending(path: payload.path),
                    options: .withoutOverwriting
                )
            }
            try interruptIfRequested(.payloadsWritten, interruption, behavior: interruptionBehavior)
            let records = payloads.map {
                GlifiExportManifest.FileRecord(
                    path: $0.path,
                    mediaType: $0.mediaType,
                    schema: $0.schema,
                    byteCount: $0.data.count,
                    sha256: digest($0.data)
                )
            }.sorted { $0.path < $1.path }
            let manifest = try makeManifest(
                snapshot: snapshot,
                investigation: investigation,
                report: report,
                interpretationRecord: interpretationRecord,
                interpretation: interpretation,
                files: records,
                request: request,
                environment: environment,
                exportID: exportID,
                createdAt: createdAt
            )
            let manifestData = try GlifiExportCanonicalJSON.encode(manifest)
            guard manifestData.count <= GlifiProjectPackage.maximumManifestByteCount else {
                throw exportFailure(
                    "export.manifest-too-large",
                    category: .insufficientResources,
                    retainedState: .unchanged
                )
            }
            try manifestData.write(
                to: staging.appending(path: Self.manifestFileName),
                options: .withoutOverwriting
            )
            try interruptIfRequested(.manifestWritten, interruption, behavior: interruptionBehavior)
            let verified = try Self.verifyExport(at: staging)
            guard verified.exportID == exportID.uuidString.lowercased(),
                verified.files == records
            else {
                throw exportFailure("export.verification-failed")
            }
            try interruptIfRequested(
                .stagingValidated,
                interruption,
                behavior: interruptionBehavior
            )
            try fileManager.moveItem(at: staging, to: destination)
            try interruptIfRequested(
                .destinationCommitted,
                interruption,
                behavior: interruptionBehavior
            )
            return GlifiExportReceipt(
                exportID: manifest.exportID,
                reportRevisionID: report.id,
                manifestDigest: digest(manifestData),
                fileCount: records.count
            )
        } catch let failure as GlifiFailure {
            try? fileManager.removeItem(at: staging)
            throw failure
        } catch {
            try? fileManager.removeItem(at: staging)
            throw exportFailure(
                "export.io-failed",
                category: .transientIO,
                retryDisposition: .transientBackoff,
                retainedState: .unchanged
            )
        }
    }

    static func verifyExport(at exportURL: URL) throws -> GlifiExportManifest {
        let directory: GlifiPackageDirectory
        do {
            directory = try GlifiPackageDirectory(at: exportURL)
        } catch {
            throw exportFailure("export.invalid-directory", category: .invalidInput)
        }
        let data = try readFile(
            manifestFileName, in: directory,
            maximumByteCount: GlifiProjectPackage.maximumManifestByteCount,
            failureCode: "export.invalid-manifest"
        )
        let manifest: GlifiExportManifest
        do {
            manifest = try JSONDecoder().decode(GlifiExportManifest.self, from: data)
        } catch let failure as GlifiFailure {
            throw failure
        } catch {
            throw exportFailure("export.invalid-manifest")
        }
        guard try GlifiExportCanonicalJSON.encode(manifest) == data else {
            throw exportFailure("export.noncanonical-manifest", category: .corruption)
        }
        let expectedNames = Set(manifest.files.map(\.path) + [manifestFileName])
        let actualNames = try Set(
            FileManager.default.contentsOfDirectory(
                at: exportURL,
                includingPropertiesForKeys: nil,
                options: []
            ).map(\.lastPathComponent)
        )
        guard expectedNames == actualNames else {
            throw exportFailure("export.unexpected-file")
        }
        var verifiedReport: GlifiReportRevision?
        var csvDataByPath: [String: Data] = [:]
        for record in manifest.files {
            let fileData = try readFile(
                record.path, in: directory,
                maximumByteCount: maximumFileByteCount,
                expectedByteCount: record.byteCount,
                failureCode: "export.invalid-file"
            )
            guard digest(fileData) == record.sha256 else {
                throw exportFailure("export.digest-mismatch", category: .corruption)
            }
            if record.path == "report.json" {
                let report = try JSONDecoder().decode(GlifiReportRevision.self, from: fileData)
                guard report.id.canonicalValue == manifest.selection.reportRevisionID,
                    report.investigationID.canonicalValue == manifest.selection.investigationID,
                    report.investigationHeadEventID.canonicalValue
                        == manifest.selection.investigationHeadEventID,
                    report.interpretationArtifactID.canonicalValue
                        == manifest.analysis.artifactID,
                    report.selectedFindingIDs.map(\.canonicalValue)
                        == manifest.selection.selectedFindingIDs
                else {
                    throw exportFailure("export.report-mismatch", category: .corruption)
                }
                verifiedReport = report
            } else if record.path == "report.pdf" {
                try GlifiScientificExportRenderer.validatePDF(fileData)
            } else if record.path.hasSuffix(".csv") {
                csvDataByPath[record.path] = fileData
            }
        }
        if let verifiedReport {
            for payload in try GlifiScientificExportRenderer.csvPayloads(verifiedReport)
            where expectedNames.contains(payload.path) {
                guard csvDataByPath[payload.path] == payload.data else {
                    throw exportFailure("export.csv-report-mismatch", category: .corruption)
                }
            }
        }
        return manifest
    }

    static func readFile(
        _ relativePath: String,
        in directory: GlifiPackageDirectory,
        maximumByteCount: Int,
        expectedByteCount: Int? = nil,
        failureCode: String
    ) throws -> Data {
        do {
            guard maximumByteCount >= 0,
                expectedByteCount.map({ $0 >= 0 && $0 <= maximumByteCount }) ?? true
            else {
                throw exportFailure(failureCode)
            }
            let handle = try directory.openFile(relativePath: relativePath)
            defer { try? handle.close() }
            var status = stat()
            guard fstat(handle.fileDescriptor, &status) == 0,
                (status.st_mode & S_IFMT) == S_IFREG,
                status.st_nlink == 1,
                status.st_size >= 0,
                status.st_size <= maximumByteCount,
                expectedByteCount.map({ status.st_size == $0 }) ?? true
            else {
                throw exportFailure(failureCode)
            }
            let byteCount = Int(status.st_size)
            var data = Data()
            while true {
                let remaining = byteCount - data.count
                let chunk = try handle.read(upToCount: min(remaining, 65_535) + 1) ?? Data()
                if chunk.isEmpty { break }
                guard chunk.count <= remaining else { throw exportFailure(failureCode) }
                data.append(chunk)
            }
            var finalStatus = stat()
            guard data.count == byteCount,
                fstat(handle.fileDescriptor, &finalStatus) == 0,
                finalStatus.st_size == status.st_size,
                finalStatus.st_nlink == 1
            else {
                throw exportFailure(failureCode)
            }
            return data
        } catch {
            throw exportFailure(failureCode)
        }
    }

    private func makeManifest(
        snapshot: GlifiProjectSnapshot,
        investigation: GlifiInvestigation,
        report: GlifiReportRevision,
        interpretationRecord: GlifiProjectArtifactRecord,
        interpretation: GlifiAnalysisInterpretation,
        files: [GlifiExportManifest.FileRecord],
        request: GlifiScientificExportRequest,
        environment: GlifiExportEnvironment,
        exportID: UUID,
        createdAt: Date
    ) throws -> GlifiExportManifest {
        let descriptor = interpretationRecord.node.descriptor
        let sources = snapshot.sources.map {
            GlifiExportManifest.CorpusSource(
                id: $0.sourceRevisionID.canonicalValue,
                contentDigest: $0.contentDigest
            )
        }.sorted { $0.id < $1.id }
        struct CorpusDigestInput: Encodable {
            let digestVersion: Int
            let sources: [GlifiExportManifest.CorpusSource]
        }
        let corpusDigest = digest(
            try GlifiExportCanonicalJSON.encode(
                CorpusDigestInput(digestVersion: 1, sources: sources)
            )
        )
        let preprocessing = try descriptor.preprocessingIdentifiers.map { identifier in
            struct Declaration: Encodable {
                let id: String
                let version: String
                let parameters: [String: GlifiAnalysisValue]
            }
            let declaration = Declaration(id: identifier, version: "1", parameters: [:])
            return GlifiExportManifest.PreprocessingStep(
                id: declaration.id,
                version: declaration.version,
                parameters: declaration.parameters,
                digest: digest(try GlifiExportCanonicalJSON.encode(declaration))
            )
        }
        let caveats = canonicalCaveats(report)
        let lineageInputs = Array(
            Set(
                [investigation.interpretationArtifactID, investigation.planArtifactID]
                    + interpretation.sourceArtifactIDs
                    + report.evidence.flatMap(\.artifactIDs)
            )
        ).sorted { $0.canonicalValue < $1.canonicalValue }.map(\.canonicalValue)
        struct Lineage: Encodable {
            let investigationHeadEventID: String
            let reportRevisionID: String
            let inputs: [String]
        }
        let lineageDigest = digest(
            try GlifiExportCanonicalJSON.encode(
                Lineage(
                    investigationHeadEventID: investigation.headEventID.canonicalValue,
                    reportRevisionID: report.id.canonicalValue,
                    inputs: lineageInputs
                )
            )
        )
        let validationEvidence = ["GS-VER-030", "GS-VER-031", "GS-VER-032"]
        struct ValidationDeclaration: Encodable {
            let methodIdentifier: String
            let status: String
            let evidence: [String]
        }
        let validationDeclaration = ValidationDeclaration(
            methodIdentifier: descriptor.algorithmIdentifier,
            status: "candidate",
            evidence: validationEvidence
        )
        return try GlifiExportManifest(
            exportID: exportID.uuidString.lowercased(),
            createdAt: Self.timestamp(createdAt),
            software: environment.software,
            platform: environment.platform,
            project: .init(
                id: snapshot.projectID.canonicalValue,
                generation: snapshot.generation,
                manifestDigest: snapshot.generationRecordDigest
            ),
            corpus: .init(
                id: descriptor.corpusIdentifier,
                digest: corpusDigest,
                digestAlgorithm: "SHA-256",
                digestVersion: 1,
                sources: sources
            ),
            analysis: .init(
                artifactID: interpretationRecord.artifactID.canonicalValue,
                descriptorDigest: interpretationRecord.descriptorDigest,
                descriptor: descriptor,
                algorithm: .init(
                    id: descriptor.algorithmIdentifier,
                    version: descriptor.algorithmVersion
                ),
                parameters: descriptor.resolvedParameters
            ),
            preprocessing: preprocessing,
            backend: .init(
                id: descriptor.backendIdentifier,
                version: "1",
                numericPolicy: descriptor.numericPolicyIdentifier,
                modelDigest: nil,
                seed: descriptor.seedPolicyIdentifier == "none-v1"
                    ? nil : descriptor.seedPolicyIdentifier
            ),
            determinism: .init(
                class: descriptor.determinismClass.rawValue,
                tolerances: descriptor.determinismClass == .d0 ? nil : [:],
                sourcesOfVariability: []
            ),
            selection: .init(
                kind: "investigation-report",
                investigationID: investigation.id.canonicalValue,
                investigationHeadEventID: investigation.headEventID.canonicalValue,
                reportRevisionID: report.id.canonicalValue,
                selectedFindingIDs: investigation.selectedFindingIDs.map(\.canonicalValue),
                filters: []
            ),
            files: files,
            provenance: .init(
                inputs: lineageInputs,
                lineageDigest: lineageDigest,
                caveats: caveats
            ),
            validation: .init(
                manifestID: "validation:\(descriptor.algorithmIdentifier):candidate-v1",
                manifestDigest: digest(
                    try GlifiExportCanonicalJSON.encode(validationDeclaration)
                ),
                status: validationDeclaration.status,
                evidence: validationDeclaration.evidence
            ),
            presentation: .init(
                locale: request.presentationLocaleIdentifier,
                timeZone: request.presentationTimeZoneIdentifier
            )
        )
    }

    private func validateDestination(_ destination: URL) throws {
        let fileManager = FileManager.default
        guard destination.isFileURL,
            !destination.lastPathComponent.isEmpty,
            destination.lastPathComponent != ".",
            destination.lastPathComponent != "..",
            !fileManager.fileExists(atPath: destination.path)
        else {
            throw exportFailure("export.destination-exists", category: .invalidInput)
        }
        let parent = destination.deletingLastPathComponent()
        let values = try parent.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw exportFailure("export.invalid-destination", category: .invalidInput)
        }
    }

    private func markdown(_ report: GlifiReportRevision, localeIdentifier: String) -> String {
        let italian = localeIdentifier.lowercased().hasPrefix("it")
        let title = italian ? "Relazione di indagine" : "Investigation report"
        let question = italian ? "Domanda" : "Question"
        let findings = italian ? "Risultati selezionati" : "Selected findings"
        let evidence = italian ? "Evidenze" : "Evidence"
        let caveats = italian ? "Limiti" : "Caveats"
        let noFindings =
            italian
            ? "Nessun risultato positivo selezionato."
            : "No positive finding selected."
        var lines = [
            "# \(title)",
            "",
            "## \(question)",
            "",
            escapeMarkdown(report.question),
            "",
            "## \(findings)",
            "",
        ]
        if report.findings.isEmpty {
            lines.append(noFindings)
        } else {
            for finding in report.findings {
                lines.append(
                    "- `\(finding.id.canonicalValue)` — `\(finding.messageKey)`"
                )
            }
        }
        lines += ["", "## \(evidence)", ""]
        if report.evidence.isEmpty {
            lines.append("—")
        } else {
            for item in report.evidence {
                lines.append("- `\(item.id.canonicalValue)` — `\(item.kindIdentifier)`")
            }
        }
        lines += ["", "## \(caveats)", ""]
        let reportCaveats = canonicalCaveats(report)
        if reportCaveats.isEmpty {
            lines.append("—")
        } else {
            for caveat in reportCaveats {
                lines.append("- `\(caveat.identifier)` (\(caveat.severity.rawValue))")
            }
        }
        lines += [
            "",
            "---",
            "",
            "`\(report.id.canonicalValue)`  ",
            "`\(report.investigationHeadEventID.canonicalValue)`",
            "",
        ]
        return lines.joined(separator: "\n")
    }

    private func canonicalCaveats(_ report: GlifiReportRevision) -> [GlifiCaveat] {
        let values =
            report.evidence.flatMap(\.caveats)
            + report.findings.flatMap(\.caveats)
            + (report.insufficientEvidence?.caveats ?? [])
        var seen = Set<String>()
        return values.sorted {
            ($0.identifier, $0.scope.rawValue, $0.originIdentifier)
                < ($1.identifier, $1.scope.rawValue, $1.originIdentifier)
        }.filter {
            let key = [
                $0.identifier,
                $0.severity.rawValue,
                $0.scope.rawValue,
                $0.causeIdentifier,
                $0.consequenceIdentifier,
                $0.actionIdentifier ?? "",
                $0.originIdentifier,
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func interruptIfRequested(
        _ point: GlifiExportInterruption,
        _ requested: GlifiExportInterruption?,
        behavior: GlifiExportInterruptionBehavior
    ) throws {
        guard point == requested else { return }
        switch behavior {
        case .throwFailure:
            break
        case .invoke(let action):
            action()
        }
        throw exportFailure(
            "export.simulated-interruption",
            category: .transientIO,
            retryDisposition: .transientBackoff,
            retainedState: point == .destinationCommitted ? .validatedCheckpoint : .unchanged
        )
    }
}

enum GlifiExportCanonicalJSON {
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

private func escapeMarkdown(_ value: String) -> String {
    let special = "\\`*_{}[]<>()#+-.!|>"
    return value.reduce(into: "") { result, character in
        if special.contains(character) { result.append("\\") }
        result.append(character)
    }
}

private func digest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func isExportDigest(_ value: String) -> Bool {
    guard value.hasPrefix("sha256:"), value.count == 71 else { return false }
    return value.dropFirst(7).allSatisfy { "0123456789abcdef".contains($0) }
}

private func exportFailure(
    _ code: String,
    category: GlifiFailureCategory = .invariantViolation,
    retryDisposition: GlifiRetryDisposition? = nil,
    retainedState: GlifiRetainedState = .validityUnknown
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .export,
        retryDisposition: retryDisposition ?? GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: retainedState),
        messageKey: "failure.\(code)"
    )
}
