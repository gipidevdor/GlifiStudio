// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioKHLanguageTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case termScores, termExtraction, incrementalClassifier, continueClassifier
    case validateClassifierWithAgreement, codeCrosstabSignificance
    var id: Self { self }
    var titleKey: String { "kh.language.tool.\(rawValue)" }
    var descriptionKey: String { "kh.language.description.\(rawValue)" }
    var theme: StudioAnalysisTheme {
        switch self {
        case .termScores, .termExtraction: .vocabulary
        case .incrementalClassifier, .continueClassifier, .validateClassifierWithAgreement:
            .classification
        case .codeCrosstabSignificance: .coding
        }
    }
    var usesLabels: Bool {
        self == .incrementalClassifier || self == .continueClassifier
            || self == .validateClassifierWithAgreement || self == .codeCrosstabSignificance
    }
}

nonisolated struct StudioKHTermCandidateDraft: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var components = ""
    var frequency = 1
}

nonisolated struct StudioKHTermTokenDraft: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var surface = ""
    var base = ""
    var partOfSpeech = ""
    var startUTF8 = 0
    var endUTF8 = 0
    var sentence = 0
    var paragraph = 0

    var token: GlifiStudioTermToken {
        GlifiStudioTermToken(
            surface: surface, base: base, partOfSpeech: partOfSpeech.isEmpty ? nil : partOfSpeech,
            startUTF8: startUTF8, endUTF8: endUTF8, sentence: sentence, paragraph: paragraph)
    }
}

nonisolated struct StudioKHLanguageDraft: Codable, Equatable, Sendable {
    var candidates = [StudioKHTermCandidateDraft()]
    var preprocessingIdentifier = ""
    var adjacencyMode: GlifiStudioTermAdjacencyMode = .token
    var maximumWork = 100_000_000
    var annotationSourceID = ""
    var tokens: [StudioKHTermTokenDraft] = []
    var linguisticContract = ""
    var ruleIdentifier = ""
    var allowedPartsOfSpeech = ""
    var ignoredKeys = ""
    var minimumComponents = 2
    var maximumComponents = 64
    var labels: [String: String] = [:]
    var rules = ""
    var smoothing = 1.0
    var folds = 2
    var seed: UInt64 = 0
    var correction: GlifiStudioKHChiSquareCorrection = .automatic
}

nonisolated struct StudioKHLanguageTable: Codable, Identifiable, Sendable {
    let id: String
    let columns: [String]
    let rows: [[String]]
    var literalColumnStart: Int? = nil
}

/// Captured source presentation remains restorable without rerunning an extraction backend.
nonisolated struct StudioKHSourceSnapshot: Codable, Equatable, Sendable {
    struct Document: Codable, Equatable, Sendable {
        let format: GlifiStudioTextFormat
        let originalByteCount: Int
        let originalContentDigest: String
        let extractionContractIdentifier: String
        let backendIdentifier: String
        let metadata: [String: String]
        let capturedJSON: Data
    }

    let sourceRevisionID: String
    let text: String
    let byteCount: Int
    let document: Document?

    init(_ source: GlifiStudioSourceText) throws {
        sourceRevisionID = source.sourceRevisionID
        text = source.text
        byteCount = source.byteCount
        document = try source.document.map { value in
            Document(
                format: value.format, originalByteCount: value.originalByteCount,
                originalContentDigest: value.originalContentDigest,
                extractionContractIdentifier: value.extractionContractIdentifier,
                backendIdentifier: value.backendIdentifier, metadata: value.metadata,
                capturedJSON: try JSONEncoder().encode(value))
        }
    }
}

nonisolated struct StudioKHLanguageOutput: Sendable {
    let tool: StudioKHLanguageTool
    let draft: StudioKHLanguageDraft
    let request: GlifiStudioKHAnalysisRequest
    let result: GlifiStudioTextAnalysisResult?
    let methodIdentifier: String
    let capturedPreparation: GlifiStudioCorpusPreparation?
    let encodedRequest: Data
    let encodedResult: Data
    let tables: [StudioKHLanguageTable]
    let metrics: [StudioCorpusField]
    let state: GlifiStudioNaiveBayesTrainingState?
    let projectID: String?
    let generation: Int?
    let sourceRevisionIDs: [String]
    let eligibleSourceRevisionIDs: [String]
    let contentDigests: [String: String]
    let sourceNumbers: [String: Int]
    let annotatedSource: StudioKHSourceSnapshot?
    let completedAt: Date
}

/// Owns explicit linguistic annotations and transient classifier statistics for the native workflow.
@MainActor @Observable final class StudioKHLanguageModel {
    var tool: StudioKHLanguageTool = .termScores
    var draft = StudioKHLanguageDraft()
    private(set) var annotationSource: StudioKHSourceSnapshot?
    private(set) var classifierState: GlifiStudioNaiveBayesTrainingState?
    private(set) var output: StudioKHLanguageOutput?
    private var lifecycle = UUID()
    private var sourceRevision = UUID()

    func reset() {
        lifecycle = UUID()
        sourceRevision = UUID()
        tool = .termScores
        draft = StudioKHLanguageDraft()
        annotationSource = nil
        classifierState = nil
        output = nil
    }

    func loadAnnotationSource(session: GlifiStudioProjectSession) async throws {
        let expectedLifecycle = lifecycle
        let expectedSource = UUID()
        sourceRevision = expectedSource
        let id = draft.annotationSourceID
        let text = try await session.sourceText(sourceRevisionID: id)
        try Self.checkCancellation()
        guard lifecycle == expectedLifecycle, sourceRevision == expectedSource,
            draft.annotationSourceID == id
        else { throw Self.failure(cancelled: true) }
        annotationSource = try StudioKHSourceSnapshot(text)
        draft.tokens = []
    }

    func importClassifierState(from url: URL) async throws {
        let expectedLifecycle = UUID()
        lifecycle = expectedLifecycle
        let state = try await Self.readState(url)
        try Self.checkCancellation()
        guard lifecycle == expectedLifecycle else { throw Self.failure(cancelled: true) }
        classifierState = state
    }

    func encodedClassifierState() async throws -> Data {
        guard let classifierState else { throw Self.failure() }
        let expectedLifecycle = lifecycle
        let encoded = try await Self.encodeState(classifierState)
        try Self.checkCancellation()
        guard lifecycle == expectedLifecycle else { throw Self.failure(cancelled: true) }
        return encoded
    }

    @concurrent private static func encodeState(_ state: GlifiStudioNaiveBayesTrainingState)
        async throws -> Data
    {
        try checkCancellation()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(state)
        try checkCancellation()
        return bytes
    }

    func execute(
        session: GlifiStudioProjectSession, sourceRevisionIDs: [String],
        sourceNumbers: [String: Int], locale: Locale
    ) async throws {
        let execution = UUID()
        lifecycle = execution
        let capturedTool = tool
        let capturedDraft = draft
        let capturedSource = annotationSource
        let capturedState = classifierState
        let next = try await Self.calculate(
            tool: capturedTool, draft: capturedDraft, annotationSource: capturedSource,
            state: capturedState, session: session, ids: sourceRevisionIDs,
            sourceNumbers: sourceNumbers, locale: locale)
        try Self.checkCancellation()
        guard lifecycle == execution else { throw Self.failure(cancelled: true) }
        output = next
        if let state = next.state { classifierState = state }
    }

    nonisolated private struct ArchiveMetric: Codable, Sendable {
        let key: String
        let value: String
    }

    nonisolated private struct Archive: Codable, Sendable {
        let client: String
        let version: Int
        let tool: StudioKHLanguageTool
        let draft: StudioKHLanguageDraft
        let request: Data
        let result: Data
        let methodIdentifier: String
        let capturedPreparation: GlifiStudioCorpusPreparation?
        let tables: [StudioKHLanguageTable]
        let metrics: [ArchiveMetric]
        let classifierState: GlifiStudioNaiveBayesTrainingState?
        let projectID: String?
        let generation: Int?
        let sourceRevisionIDs: [String]
        let eligibleSourceRevisionIDs: [String]
        let contentDigests: [String: String]
        let sourceNumbers: [String: Int]
        let annotatedSource: StudioKHSourceSnapshot?
        let completedAt: Date
    }

    /// Stores captured settings, classifier state and native tables with the issued output.
    func archiveData() async throws -> Data {
        let expected = lifecycle
        guard let output else { throw Self.failure() }
        let archive = Archive(
            client: "khLanguage", version: 1, tool: output.tool, draft: output.draft,
            request: output.encodedRequest, result: output.encodedResult,
            methodIdentifier: output.methodIdentifier,
            capturedPreparation: output.capturedPreparation, tables: output.tables,
            metrics: output.metrics.map { ArchiveMetric(key: $0.key, value: $0.value) },
            classifierState: output.state, projectID: output.projectID,
            generation: output.generation, sourceRevisionIDs: output.sourceRevisionIDs,
            eligibleSourceRevisionIDs: output.eligibleSourceRevisionIDs,
            contentDigests: output.contentDigests, sourceNumbers: output.sourceNumbers,
            annotatedSource: output.annotatedSource, completedAt: output.completedAt)
        let bytes = try await Self.encodeArchive(archive)
        try Task.checkCancellation()
        guard lifecycle == expected else { throw CancellationError() }
        return bytes
    }

    @concurrent private static func encodeArchive(_ archive: Archive) async throws -> Data {
        try Task.checkCancellation()
        let bytes = try JSONEncoder().encode(archive)
        guard bytes.count <= 8 * 1_048_576 else { throw Self.failure() }
        try Task.checkCancellation()
        return bytes
    }

    /// Restores a scientific result's native presentation without evaluating rules or models.
    @concurrent private static func decodeArchive(
        _ data: Data, saved: GlifiStudioSavedAnalysis
    ) async throws -> (archive: Archive, request: GlifiStudioKHAnalysisRequest) {
        try Task.checkCancellation()
        guard data.count <= 8 * 1_048_576 else { throw Self.failure() }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        let stored = try JSONSerialization.jsonObject(with: archive.result) as? NSDictionary
        let authoritative =
            try JSONSerialization.jsonObject(with: saved.resultJSON) as? NSDictionary
        let decoded = try GlifiStudioTextAnalysisRequest.decode(archive.request)
        guard archive.client == "khLanguage", archive.version == 1,
            archive.request == saved.requestJSON, stored == authoritative,
            archive.methodIdentifier == saved.methodIdentifier,
            archive.sourceRevisionIDs == saved.sourceRevisionIDs,
            archive.sourceRevisionIDs.count == archive.contentDigests.count,
            archive.tables.reduce(0, { $0 + $1.rows.count }) <= 100_000,
            archive.tables.allSatisfy({ table in
                table.rows.allSatisfy { $0.count == table.columns.count }
            }), case let .advanced(.kh(request)) = decoded
        else { throw Self.failure() }
        if let source = archive.annotatedSource {
            guard source.byteCount == source.text.utf8.count,
                archive.sourceRevisionIDs.contains(source.sourceRevisionID),
                source.sourceRevisionID == archive.draft.annotationSourceID
            else { throw Self.failure() }
        }
        if let preparation = archive.capturedPreparation {
            guard try preparation.digest() == saved.preparationDigest else { throw Self.failure() }
        }
        try Task.checkCancellation()
        return (archive, request)
    }

    func restoreArchive(_ data: Data, saved: GlifiStudioSavedAnalysis) async throws {
        let expected = UUID()
        lifecycle = expected
        let decoded = try await Self.decodeArchive(data, saved: saved)
        let archive = decoded.archive
        let request = decoded.request
        try Task.checkCancellation()
        guard lifecycle == expected else { throw CancellationError() }
        reset()
        tool = archive.tool
        draft = archive.draft
        annotationSource = archive.annotatedSource
        classifierState = archive.classifierState
        output = StudioKHLanguageOutput(
            tool: archive.tool, draft: archive.draft, request: request, result: nil,
            methodIdentifier: archive.methodIdentifier,
            capturedPreparation: archive.capturedPreparation,
            encodedRequest: archive.request, encodedResult: archive.result,
            tables: archive.tables,
            metrics: archive.metrics.map { StudioCorpusField(key: $0.key, value: $0.value) },
            state: archive.classifierState, projectID: archive.projectID,
            generation: archive.generation, sourceRevisionIDs: archive.sourceRevisionIDs,
            eligibleSourceRevisionIDs: archive.eligibleSourceRevisionIDs,
            contentDigests: archive.contentDigests, sourceNumbers: archive.sourceNumbers,
            annotatedSource: archive.annotatedSource, completedAt: archive.completedAt)
    }

    @concurrent private static func readState(_ url: URL) async throws
        -> GlifiStudioNaiveBayesTrainingState
    {
        let attributes = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = attributes.fileSize,
            size <= GlifiStudioTextAnalysisRequest.maximumRequestBytes
        else {
            throw failure()
        }
        try checkCancellation()
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= GlifiStudioTextAnalysisRequest.maximumRequestBytes else {
            throw failure()
        }
        try checkCancellation()
        let decoded: GlifiStudioNaiveBayesTrainingState
        do {
            decoded = try JSONDecoder().decode(GlifiStudioNaiveBayesTrainingState.self, from: bytes)
        } catch let decodingFailure as GlifiStudioFailure {
            try checkCancellation()
            throw decodingFailure
        } catch {
            try checkCancellation()
            throw failure()
        }
        let validation = try await GlifiStudioKHAnalysis.execute(
            .continueClassifier(
                state: decoded, documents: [], labels: [], predictionDocuments: []))
        guard case let .advanced(.kh(.incrementalClassifier(result))) = validation.payload else {
            throw failure()
        }
        return result.state
    }

    @concurrent private static func calculate(
        tool: StudioKHLanguageTool, draft: StudioKHLanguageDraft,
        annotationSource: StudioKHSourceSnapshot?, state: GlifiStudioNaiveBayesTrainingState?,
        session: GlifiStudioProjectSession, ids: [String], sourceNumbers: [String: Int],
        locale: Locale
    ) async throws -> StudioKHLanguageOutput {
        try checkCancellation()
        let request: GlifiStudioKHAnalysisRequest
        var projectID: String?
        var generation: Int?
        var effectiveIDs: [String] = []
        var contentDigests: [String: String] = [:]
        var annotatedSource: StudioKHSourceSnapshot?
        var capturedPreparation: GlifiStudioCorpusPreparation?
        switch tool {
        case .termScores:
            guard !draft.candidates.isEmpty, draft.candidates.count <= 10_000 else {
                throw failure()
            }
            request = .termScores(
                candidates: draft.candidates.map {
                    GlifiStudioTermCandidate(
                        components: $0.components.split(whereSeparator: \.isWhitespace).map(
                            String.init),
                        frequency: $0.frequency)
                }, preprocessingIdentifier: draft.preprocessingIdentifier,
                adjacencyMode: draft.adjacencyMode, maximumWork: draft.maximumWork)
        case .termExtraction:
            guard let annotationSource,
                annotationSource.sourceRevisionID == draft.annotationSourceID,
                ids.contains(annotationSource.sourceRevisionID), !draft.tokens.isEmpty
            else { throw failure() }
            let snapshot = try await session.snapshot()
            guard
                let original = snapshot.sources.first(where: {
                    $0.sourceRevisionID == annotationSource.sourceRevisionID
                })
            else { throw failure() }
            projectID = snapshot.projectID
            generation = snapshot.generation
            effectiveIDs = [original.sourceRevisionID]
            contentDigests[original.sourceRevisionID] = original.contentDigest
            annotatedSource = annotationSource
            request = .termExtraction(
                documents: [
                    GlifiStudioTermDocument(
                        id: annotationSource.sourceRevisionID, text: annotationSource.text,
                        tokens: draft.tokens.map(\.token),
                        linguisticContract: draft.linguisticContract)
                ],
                rule: GlifiStudioTermExtractionRule(
                    identifier: draft.ruleIdentifier,
                    allowedPartsOfSpeech: lines(draft.allowedPartsOfSpeech),
                    ignoredKeys: lines(draft.ignoredKeys),
                    minimumComponents: draft.minimumComponents,
                    maximumComponents: draft.maximumComponents),
                adjacencyMode: draft.adjacencyMode, maximumWork: draft.maximumWork)
        case .incrementalClassifier, .continueClassifier, .validateClassifierWithAgreement,
            .codeCrosstabSignificance:
            let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
                session: session, sourceRevisionIDs: ids, allowsEmptyLexicon: true)
            projectID = input.projectID
            capturedPreparation = input.preparation
            generation = input.generation
            effectiveIDs = input.sourceRevisionIDs
            contentDigests = Dictionary(
                uniqueKeysWithValues: zip(input.sourceRevisionIDs, input.contentDigests))
            let labels = input.sourceRevisionIDs.map {
                draft.labels[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            if tool == .codeCrosstabSignificance {
                request = .codeCrosstabSignificance(
                    units: input.codingUnits, rules: draft.rules,
                    groups: labels.map { $0.isEmpty ? nil : $0 }, correction: draft.correction)
            } else if tool == .validateClassifierWithAgreement {
                guard !labels.contains(where: \.isEmpty) else { throw failure() }
                request = .validateClassifierWithAgreement(
                    documents: input.documents, labels: labels, folds: draft.folds,
                    seed: draft.seed, smoothing: draft.smoothing)
            } else {
                let training = labels.indices.filter { !labels[$0].isEmpty }
                let prediction = labels.indices.filter { labels[$0].isEmpty }
                guard !training.isEmpty else { throw failure() }
                let documents = training.map { input.documents[$0] }
                let classes = training.map { labels[$0] }
                let predictions = prediction.map { input.documents[$0] }
                if tool == .continueClassifier {
                    guard let state else { throw failure() }
                    request = .continueClassifier(
                        state: state, documents: documents, labels: classes,
                        predictionDocuments: predictions)
                } else {
                    request = .incrementalClassifier(
                        documents: documents, labels: classes, smoothing: draft.smoothing,
                        predictionDocuments: predictions)
                }
            }
        }
        let result = try await GlifiStudioKHAnalysis.execute(request)
        try checkCancellation()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(result)
        let encodedRequest = try GlifiStudioTextAnalysisRequest.advanced(.kh(request))
            .canonicalData()
        let projection = try project(
            result, draft: draft, ids: ids.sorted(),
            sourceNumbers: sourceNumbers, locale: locale)
        return StudioKHLanguageOutput(
            tool: tool, draft: draft, request: request, result: result,
            methodIdentifier: result.methodIdentifier,
            capturedPreparation: capturedPreparation,
            encodedRequest: encodedRequest,
            encodedResult: encoded,
            tables: projection.tables, metrics: projection.metrics, state: projection.state,
            projectID: projectID, generation: generation, sourceRevisionIDs: effectiveIDs,
            eligibleSourceRevisionIDs: tool == .termScores ? [] : ids.sorted(),
            contentDigests: contentDigests,
            sourceNumbers: sourceNumbers.filter { effectiveIDs.contains($0.key) },
            annotatedSource: annotatedSource,
            completedAt: Date())
    }

    nonisolated private static func lines(_ value: String) -> [String] {
        value.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    nonisolated private static func checkCancellation() throws {
        if Task.isCancelled { throw failure(cancelled: true) }
    }

    nonisolated private static func failure(cancelled: Bool = false) -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: cancelled ? "operation.cancelled" : "ui.kh-language.invalid-input",
            category: cancelled ? "cancelled" : "invalidInput", operation: "analyze",
            retryDisposition: cancelled ? "newRequest" : "afterCorrection",
            retainedState: "unchanged",
            messageKey: cancelled ? "failure.category.cancelled" : "failure.category.invalidInput")
    }

    nonisolated private static func project(
        _ result: GlifiStudioTextAnalysisResult,
        draft: StudioKHLanguageDraft, ids: [String], sourceNumbers: [String: Int], locale: Locale
    ) throws -> (
        tables: [StudioKHLanguageTable], metrics: [StudioCorpusField],
        state: GlifiStudioNaiveBayesTrainingState?
    ) {
        guard case let .advanced(.kh(payload)) = result.payload else { throw failure() }
        var tables: [StudioKHLanguageTable] = []
        var metrics: [StudioCorpusField] = []
        var state: GlifiStudioNaiveBayesTrainingState?
        func number(_ value: Double?) -> String {
            value.map { $0.formatted(.number.locale(locale).precision(.significantDigits(1...9))) }
                ?? String(localized: "visual.cell.missing", locale: locale)
        }
        func scoreTable(_ scores: GlifiStudioTermExtractionScores) -> StudioKHLanguageTable {
            StudioKHLanguageTable(
                id: "scores", columns: ["term", "frequency", "lr", "flr"],
                rows:
                    scores.terms.map {
                        [
                            $0.components.joined(separator: " · "), String($0.frequency),
                            number($0.lr), number($0.flr),
                        ]
                    })
        }
        func componentTable(_ scores: GlifiStudioTermExtractionScores) -> StudioKHLanguageTable {
            StudioKHLanguageTable(
                id: "components",
                columns: [
                    "component", "left-frequency", "right-frequency", "left-types", "right-types",
                ],
                rows: scores.components.map {
                    [
                        $0.component, String($0.leftFrequency), String($0.rightFrequency),
                        String($0.leftTypeCount), String($0.rightTypeCount),
                    ]
                })
        }
        func status(_ test: GlifiStudioKHChiSquareResult?) -> String {
            let key =
                "kh.language.chi-square-status.\(test?.status.rawValue ?? "insufficient-groups")"
            return String(localized: String.LocalizationValue(key), locale: locale)
        }
        func sourceLabel(_ id: String) -> String { sourceNumbers[id].map(String.init) ?? id }
        switch payload {
        case let .termScores(value):
            tables = [scoreTable(value), componentTable(value)]
            metrics = [
                .init(
                    key: "independent-occurrences", value: String(value.independentOccurrenceCount))
            ]
        case let .termExtraction(value):
            tables = [
                scoreTable(value.scores), componentTable(value.scores),
                StudioKHLanguageTable(
                    id: "occurrences", columns: ["source", "term", "start", "end"],
                    rows:
                        value.occurrences.map {
                            [
                                sourceLabel($0.documentID), $0.components.joined(separator: " · "),
                                String($0.startUTF8), String($0.endUTF8),
                            ]
                        }),
            ]
        case let .incrementalClassifier(value):
            state = value.state
            metrics = [
                .init(key: "classes", value: value.state.classes.joined(separator: ", ")),
                .init(key: "vocabulary", value: String(value.state.vocabulary.count)),
            ]
            tables = [
                StudioKHLanguageTable(
                    id: "training", columns: ["class", "documents"],
                    rows:
                        value.state.classes.enumerated().map {
                            [$0.element, String(value.state.documentCounts[$0.offset])]
                        })
            ]
            if let predictions = value.predictions {
                let predictionIDs = ids.filter {
                    (draft.labels[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                tables.append(
                    StudioKHLanguageTable(
                        id: "predictions",
                        columns: ["source", "prediction", "probabilities", "ignored-tokens"],
                        rows:
                            predictions.labels.indices.map { index in
                                [
                                    predictionIDs.indices.contains(index)
                                        ? sourceLabel(predictionIDs[index]) : String(index + 1),
                                    predictions.labels[index],
                                    predictions.classes.enumerated().map {
                                        "\($0.element): \(number(predictions.probabilities[index][$0.offset]))"
                                    }.joined(separator: "; "),
                                    String(predictions.ignoredTokenCounts[index]),
                                ]
                            }))
            }
        case let .classifierAgreement(value):
            metrics = [
                .init(key: "kappa", value: number(value.kappa)),
                .init(key: "accuracy", value: number(value.evaluation.accuracy)),
                .init(key: "observed-agreement", value: number(value.observedAgreement)),
                .init(key: "expected-agreement", value: number(value.expectedAgreement)),
            ]
            tables = [
                StudioKHLanguageTable(
                    id: "held-out", columns: ["source", "actual", "prediction", "fold"],
                    rows:
                        value.predictions.indices.map { index in
                            let id = ids.indices.contains(index) ? ids[index] : ""
                            return [
                                sourceLabel(id), draft.labels[id] ?? "", value.predictions[index],
                                String(value.evaluation.foldAssignments[index]),
                            ]
                        }),
                StudioKHLanguageTable(
                    id: "confusion", columns: ["actual"] + value.evaluation.classes,
                    rows:
                        value.evaluation.confusion.enumerated().map {
                            [value.evaluation.classes[$0.offset]] + $0.element.map(String.init)
                        }, literalColumnStart: 1),
            ]
        case let .codeCrosstabSignificance(value):
            metrics = [.init(key: "excluded-documents", value: String(value.excludedDocumentCount))]
            tables = [
                StudioKHLanguageTable(
                    id: "crosstab", columns: ["group", "documents"] + value.codes,
                    rows:
                        value.groups.indices.map {
                            [value.groups[$0], String(value.groupSizes[$0])]
                                + value.counts[$0].map(String.init)
                        }, literalColumnStart: 2),
                StudioKHLanguageTable(
                    id: "significance",
                    columns: ["code", "statistic", "p-value", "df", "status", "correction"],
                    rows:
                        value.significance.map {
                            [
                                $0.code, number($0.test?.statistic), number($0.test?.pValue),
                                $0.test.map { String($0.degreesOfFreedom) } ?? "—",
                                status($0.test),
                                $0.test?.appliedCorrection.map { value in
                                    String(
                                        localized: String.LocalizationValue(
                                            "kh.language.correction.\(value.rawValue)"),
                                        locale: locale)
                                } ?? "—",
                            ]
                        }),
            ]
            var cellRows: [[String]] = []
            for code in value.significance {
                guard let test = code.test else { continue }
                for group in value.groups.indices {
                    for presence in 0..<2 {
                        cellRows.append([
                            code.code, value.groups[group],
                            String(
                                localized: String.LocalizationValue(
                                    presence == 0 ? "kh.language.present" : "kh.language.absent"),
                                locale: locale),
                            String(code.counts[group][presence]),
                            number(test.expected[group][presence]),
                            number(test.pearsonResiduals[group][presence]),
                            number(test.standardizedResiduals[group][presence]),
                        ])
                    }
                }
            }
            tables.append(
                StudioKHLanguageTable(
                    id: "residuals",
                    columns: [
                        "code", "group", "presence", "observed", "expected", "pearson-residual",
                        "standardized-residual",
                    ], rows: cellRows))
        case .matrix, .wordContext, .correspondence, .mds, .mdsSearch, .som, .collocation,
            .wordAssociation, .documentScores, .legacyClustering, .chiSquare:
            throw failure()
        }
        return (tables, metrics, state)
    }
}
