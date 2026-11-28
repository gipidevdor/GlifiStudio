// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioKHMatrixTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case sampleZScores, perThousand, wordContext, correspondenceScaled
    case collocationScores, wordAssociation, documentScores, hierarchicalWardD2, chiSquare

    var id: Self { self }
    var titleKey: String { "kh.matrix.tool.\(rawValue).title" }
    var descriptionKey: String { "kh.matrix.tool.\(rawValue).description" }
    var theme: StudioAnalysisTheme {
        switch self {
        case .sampleZScores, .perThousand: .preparation
        case .wordContext, .documentScores: .vocabulary
        case .collocationScores, .wordAssociation: .relationships
        case .correspondenceScaled, .hierarchicalWardD2: .structure
        case .chiSquare: .comparison
        }
    }
}

/// Editable numerical cells retain explicit row and column identities.
nonisolated struct StudioKHNumericMatrix: Codable, Equatable, Sendable {
    var values: [[Double]] = [[0, 0], [0, 0]]
    var rowLabels = ["1", "2"]
    var columnLabels = ["1", "2"]

    mutating func resize(rows: Int, columns: Int) {
        guard (1...1_000).contains(rows), (1...1_000).contains(columns) else { return }
        values = (0..<rows).map { row in
            (0..<columns).map { column in
                values.indices.contains(row) && values[row].indices.contains(column)
                    ? values[row][column] : 0
            }
        }
        rowLabels = (0..<rows).map {
            rowLabels.indices.contains($0) ? rowLabels[$0] : String($0 + 1)
        }
        columnLabels = (0..<columns).map {
            columnLabels.indices.contains($0) ? columnLabels[$0] : String($0 + 1)
        }
    }
}

nonisolated struct StudioKHContextDraft: Codable, Identifiable, Sendable {
    var id = UUID()
    var level: GlifiStudioKHContextLevel = .sentence
    var alpha = 1.0
    var targets = StudioKHNumericMatrix()
    var contexts = StudioKHNumericMatrix()
}

nonisolated struct StudioKHMatrixTable: Codable, Identifiable, Sendable {
    let id: String
    let titleKey: String
    let columns: [String]
    let rows: [[String]]
}

nonisolated struct StudioKHMatrixOutput: Sendable {
    let tool: StudioKHMatrixTool
    let methodIdentifier: String
    let validationStatus: String
    let requestDigest: String
    let request: Data
    let result: Data
    let typedResult: GlifiStudioTextAnalysisResult?
    let tables: [StudioKHMatrixTable]
    let provenance: StudioKHMatrixProvenance?
    let rowLabels: [String]
    let columnLabels: [String]
    let draftID: UUID
    let completedAt: Date
}

nonisolated struct StudioKHMatrixProvenance: Codable, Equatable, Sendable {
    let projectID: String
    let generation: Int
    let sourceRevisionIDs: [String]
    let contentDigests: [String]
    let hasManualEdits: Bool
}

/// Typed KH matrix workflows; auxiliary universes stay explicit rather than inferred from a subset.
@MainActor @Observable final class StudioKHMatrixModel {
    var tool: StudioKHMatrixTool = .sampleZScores {
        didSet { if tool != oldValue { draftID = UUID() } }
    }
    var matrix = StudioKHNumericMatrix() { didSet { draftID = UUID() } }
    var maximumTerms = 50 { didSet { draftID = UUID() } }
    var axis: GlifiStudioKHMatrixAxis = .columns { didSet { draftID = UUID() } }
    var constantPolicy: GlifiStudioKHConstantPolicy = .reject { didSet { draftID = UUID() } }
    var zeroExposurePolicy: GlifiStudioKHZeroExposurePolicy = .reject {
        didSet { draftID = UUID() }
    }
    var rowScaling: GlifiStudioKHCorrespondenceScaling = .principal { didSet { draftID = UUID() } }
    var columnScaling: GlifiStudioKHCorrespondenceScaling = .principal {
        didSet { draftID = UUID() }
    }
    var scoreMode: GlifiStudioKHDocumentScoreMode = .tf { didSet { draftID = UUID() } }
    var correction: GlifiStudioKHChiSquareCorrection = .automatic { didSet { draftID = UUID() } }
    var exposures = [0.0, 0.0] { didSet { draftID = UUID() } }
    var documentFrequencies = [0, 0] { didSet { draftID = UUID() } }
    var corpusDocumentCount = 0 { didSet { draftID = UUID() } }
    var jointCount = 0 { didSet { draftID = UUID() } }
    var nodeFrequency = 0 { didSet { draftID = UUID() } }
    var collocateFrequency = 0 { didSet { draftID = UUID() } }
    var corpusTokenCount = 0 { didSet { draftID = UUID() } }
    var windowSpan = 2 { didSet { draftID = UUID() } }
    var conditionDocumentCount = 0 { didSet { draftID = UUID() } }
    var termDocumentCount = 0 { didSet { draftID = UUID() } }
    var totalDocumentCount = 0 { didSet { draftID = UUID() } }
    var contextLevels = [StudioKHContextDraft()] { didSet { draftID = UUID() } }
    var contextTargetIDs = ["target-1", "target-2"] { didSet { draftID = UUID() } }
    var contextIDs = ["context-1", "context-2"] { didSet { draftID = UUID() } }
    var nodeTerm = "" { didSet { draftID = UUID() } }
    var collocateTerm = "" { didSet { draftID = UUID() } }
    var windowRadius = 1 { didSet { draftID = UUID() } }
    var conditionSourceIDs: Set<String> = [] { didSet { draftID = UUID() } }
    var usesCorpusAuxiliary = false { didSet { draftID = UUID() } }
    var distance: GlifiStudioTextDistance = .jaccard { didSet { draftID = UUID() } }
    var clustersTerms = false { didSet { draftID = UUID() } }
    private(set) var input: GlifiStudioProjectTextAnalysisInput?
    private(set) var output: StudioKHMatrixOutput?
    private var revision = UUID()
    private var draftID = UUID()
    private var preparedExposures: [Double] = []
    private var preparedFrequencies: [Int] = []
    private var capturedDraft: ArchiveDraft?

    func outputMatchesDraft(_ value: StudioKHMatrixOutput) -> Bool { value.draftID == draftID }

    var capturedPreparation: GlifiStudioCorpusPreparation? { capturedDraft?.input?.preparation }

    func reset() {
        revision = UUID()
        input = nil
        output = nil
        capturedDraft = nil
        preparedExposures = []
        preparedFrequencies = []
        matrix = StudioKHNumericMatrix()
        exposures = [0, 0]
        documentFrequencies = [0, 0]
        corpusDocumentCount = 0
        jointCount = 0
        nodeFrequency = 0
        collocateFrequency = 0
        corpusTokenCount = 0
        conditionDocumentCount = 0
        termDocumentCount = 0
        totalDocumentCount = 0
        nodeTerm = ""
        collocateTerm = ""
        usesCorpusAuxiliary = false
        conditionSourceIDs = []
        contextLevels = [StudioKHContextDraft()]
        contextTargetIDs = ["target-1", "target-2"]
        contextIDs = ["context-1", "context-2"]
    }

    func prepareInput(session: GlifiStudioProjectSession, sourceRevisionIDs: [String]) async throws
    {
        let capturedRevision = revision
        let prepared = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: sourceRevisionIDs,
            maximumTermCount: maximumTerms)
        let auxiliary = try await Self.prepareAuxiliary(prepared)
        try Task.checkCancellation()
        guard revision == capturedRevision else { throw CancellationError() }
        input = prepared
        matrix = StudioKHNumericMatrix(
            values: prepared.matrix, rowLabels: prepared.sourceRevisionIDs,
            columnLabels: prepared.terms)
        exposures = auxiliary.exposures
        documentFrequencies = auxiliary.frequencies
        preparedExposures = auxiliary.exposures
        preparedFrequencies = auxiliary.frequencies
        corpusDocumentCount = prepared.documents.count
        totalDocumentCount = prepared.documents.count
        corpusTokenCount = prepared.lexicalTokenCount
        nodeTerm = prepared.terms.first ?? ""
        collocateTerm = prepared.terms.dropFirst().first ?? nodeTerm
        conditionSourceIDs = []
        usesCorpusAuxiliary = true
    }

    /// Auxiliary arrays resize with manually edited matrix dimensions without fabricating exposures.
    func alignAuxiliaryDimensions() {
        exposures = matrix.values.indices.map { exposures.indices.contains($0) ? exposures[$0] : 0 }
        documentFrequencies = matrix.columnLabels.indices.map {
            documentFrequencies.indices.contains($0) ? documentFrequencies[$0] : 0
        }
        usesCorpusAuxiliary = false
    }

    func makeRequest() async throws -> GlifiStudioKHAnalysisRequest {
        switch tool {
        case .sampleZScores:
            return .sampleZScores(matrix: matrix.values, axis: axis, constantPolicy: constantPolicy)
        case .perThousand:
            return .perThousand(
                matrix: matrix.values, exposures: exposures, zeroExposurePolicy: zeroExposurePolicy)
        case .correspondenceScaled:
            return .correspondenceScaled(
                matrix: matrix.values, rowScaling: rowScaling, columnScaling: columnScaling)
        case .documentScores:
            return .documentScores(
                counts: matrix.values, exposures: exposures,
                documentFrequencies: documentFrequencies,
                corpusDocumentCount: corpusDocumentCount, mode: scoreMode)
        case .hierarchicalWardD2:
            if usesCorpusAuxiliary, let input {
                let points =
                    clustersTerms
                    ? input.terms.indices.map { column in input.matrix.map { $0[column] } }
                    : input.matrix
                return try await .hierarchicalWardD2(
                    dissimilarities: GlifiStudioTextAnalytics.dissimilarities(
                        points, metric: distance))
            }
            return .hierarchicalWardD2(dissimilarities: matrix.values)
        case .chiSquare:
            let counts = try matrix.values.map { row in
                try row.map { value in
                    guard value.isFinite, value >= 0, value.rounded() == value,
                        let count = Int(exactly: value)
                    else { throw Self.invalidInput() }
                    return count
                }
            }
            return .chiSquare(counts: counts, correction: correction)
        case .wordContext:
            return .wordContext(
                levels: contextLevels.map {
                    GlifiStudioKHContextCounts(
                        level: $0.level, alpha: $0.alpha,
                        targetCounts: $0.targets.values, contextCounts: $0.contexts.values)
                }, targetIDs: contextTargetIDs, contextIDs: contextIDs)
        case .collocationScores:
            if usesCorpusAuxiliary, let input {
                return .collocationScores(
                    try await Self.corpusCollocation(
                        input, node: nodeTerm, collocate: collocateTerm, radius: windowRadius))
            }
            return .collocationScores(
                .init(
                    jointCount: jointCount, nodeFrequency: nodeFrequency,
                    collocateFrequency: collocateFrequency,
                    corpusTokenCount: corpusTokenCount, windowSpan: windowSpan))
        case .wordAssociation:
            if usesCorpusAuxiliary, let input {
                return .wordAssociation(
                    try await Self.corpusAssociation(
                        input, term: nodeTerm, condition: conditionSourceIDs))
            }
            return .wordAssociation(
                .init(
                    jointCount: jointCount, conditionDocumentCount: conditionDocumentCount,
                    termDocumentCount: termDocumentCount, totalDocumentCount: totalDocumentCount))
        }
    }

    func execute(locale: Locale = .current) async throws {
        let capturedRevision = revision
        let archiveDraft = ArchiveDraft(self)
        let capturedTool = tool
        let capturedDraftID = draftID
        let labels: (rows: [String], columns: [String])
        switch tool {
        case .wordContext: labels = (contextTargetIDs, contextIDs)
        case .hierarchicalWardD2 where usesCorpusAuxiliary:
            labels = (clustersTerms ? input?.terms ?? [] : input?.sourceRevisionIDs ?? [], [])
        case .hierarchicalWardD2, .sampleZScores, .perThousand, .correspondenceScaled,
            .documentScores, .chiSquare, .collocationScores, .wordAssociation:
            labels = (matrix.rowLabels, matrix.columnLabels)
        }
        let effectiveInput: GlifiStudioProjectTextAnalysisInput?
        switch tool {
        case .wordContext: effectiveInput = nil
        case .collocationScores, .wordAssociation, .hierarchicalWardD2:
            effectiveInput = usesCorpusAuxiliary ? input : nil
        case .sampleZScores, .perThousand, .correspondenceScaled, .documentScores, .chiSquare:
            effectiveInput = input
        }
        let usesEditedMatrix: Bool
        switch tool {
        case .sampleZScores, .perThousand, .correspondenceScaled, .documentScores, .chiSquare:
            usesEditedMatrix = true
        case .wordContext, .collocationScores, .wordAssociation, .hierarchicalWardD2:
            usesEditedMatrix = false
        }
        let provenance = effectiveInput.map {
            StudioKHMatrixProvenance(
                projectID: $0.projectID, generation: $0.generation,
                sourceRevisionIDs: $0.sourceRevisionIDs, contentDigests: $0.contentDigests,
                hasManualEdits: usesEditedMatrix
                    && (matrix.values != $0.matrix
                        || matrix.rowLabels != $0.sourceRevisionIDs
                        || matrix.columnLabels != $0.terms
                        || ((tool == .perThousand || tool == .documentScores)
                            && exposures != preparedExposures)
                        || (tool == .documentScores
                            && (documentFrequencies != preparedFrequencies
                                || corpusDocumentCount != $0.documents.count)))
            )
        }
        let request = try await makeRequest()
        let result = try await GlifiStudioKHAnalysis.execute(request)
        let presentation = try await Self.present(
            result, request: request, tool: capturedTool, locale: locale,
            rowLabels: labels.rows, columnLabels: labels.columns,
            provenance: provenance, draftID: capturedDraftID)
        try Task.checkCancellation()
        guard revision == capturedRevision else { throw CancellationError() }
        output = presentation
        capturedDraft = archiveDraft
    }

    nonisolated private struct ArchiveDraft: Codable, Sendable {
        let tool: StudioKHMatrixTool
        let matrix: StudioKHNumericMatrix
        let maximumTerms: Int
        let axis: GlifiStudioKHMatrixAxis
        let constantPolicy: GlifiStudioKHConstantPolicy
        let zeroExposurePolicy: GlifiStudioKHZeroExposurePolicy
        let rowScaling: GlifiStudioKHCorrespondenceScaling
        let columnScaling: GlifiStudioKHCorrespondenceScaling
        let scoreMode: GlifiStudioKHDocumentScoreMode
        let correction: GlifiStudioKHChiSquareCorrection
        let exposures: [Double]
        let documentFrequencies: [Int]
        let corpusDocumentCount: Int
        let jointCount: Int
        let nodeFrequency: Int
        let collocateFrequency: Int
        let corpusTokenCount: Int
        let windowSpan: Int
        let conditionDocumentCount: Int
        let termDocumentCount: Int
        let totalDocumentCount: Int
        let contextLevels: [StudioKHContextDraft]
        let contextTargetIDs: [String]
        let contextIDs: [String]
        let nodeTerm: String
        let collocateTerm: String
        let windowRadius: Int
        let conditionSourceIDs: Set<String>
        let usesCorpusAuxiliary: Bool
        let distance: GlifiStudioTextDistance
        let clustersTerms: Bool
        let input: GlifiStudioProjectTextAnalysisInput?
        let preparedExposures: [Double]
        let preparedFrequencies: [Int]

        @MainActor init(_ model: StudioKHMatrixModel) {
            tool = model.tool
            matrix = model.matrix
            maximumTerms = model.maximumTerms
            axis = model.axis
            constantPolicy = model.constantPolicy
            zeroExposurePolicy = model.zeroExposurePolicy
            rowScaling = model.rowScaling
            columnScaling = model.columnScaling
            scoreMode = model.scoreMode
            correction = model.correction
            exposures = model.exposures
            documentFrequencies = model.documentFrequencies
            corpusDocumentCount = model.corpusDocumentCount
            jointCount = model.jointCount
            nodeFrequency = model.nodeFrequency
            collocateFrequency = model.collocateFrequency
            corpusTokenCount = model.corpusTokenCount
            windowSpan = model.windowSpan
            conditionDocumentCount = model.conditionDocumentCount
            termDocumentCount = model.termDocumentCount
            totalDocumentCount = model.totalDocumentCount
            contextLevels = model.contextLevels
            contextTargetIDs = model.contextTargetIDs
            contextIDs = model.contextIDs
            nodeTerm = model.nodeTerm
            collocateTerm = model.collocateTerm
            windowRadius = model.windowRadius
            conditionSourceIDs = model.conditionSourceIDs
            usesCorpusAuxiliary = model.usesCorpusAuxiliary
            distance = model.distance
            clustersTerms = model.clustersTerms
            input = model.input
            preparedExposures = model.preparedExposures
            preparedFrequencies = model.preparedFrequencies
        }
    }

    nonisolated private struct Archive: Codable, Sendable {
        let client: String
        let version: Int
        let draft: ArchiveDraft
        let methodIdentifier: String
        let validationStatus: String
        let requestDigest: String
        let request: Data
        let result: Data
        let tables: [StudioKHMatrixTable]
        let provenance: StudioKHMatrixProvenance?
        let rowLabels: [String]
        let columnLabels: [String]
        let completedAt: Date
    }

    /// Captures the effective settings and native tables separately from scientific authority.
    func archiveData() async throws -> Data {
        let expected = revision
        guard let output, let capturedDraft else { throw Self.invalidInput() }
        let archive = Archive(
            client: "khMatrix", version: 1, draft: capturedDraft,
            methodIdentifier: output.methodIdentifier,
            validationStatus: output.validationStatus,
            requestDigest: output.requestDigest, request: output.request, result: output.result,
            tables: output.tables, provenance: output.provenance,
            rowLabels: output.rowLabels, columnLabels: output.columnLabels,
            completedAt: output.completedAt)
        let bytes = try await Self.encodeArchive(archive)
        try Task.checkCancellation()
        guard revision == expected else { throw CancellationError() }
        return bytes
    }

    @concurrent private static func encodeArchive(_ archive: Archive) async throws -> Data {
        try Task.checkCancellation()
        let bytes = try JSONEncoder().encode(archive)
        guard bytes.count <= 8 * 1_048_576 else { throw Self.invalidInput() }
        try Task.checkCancellation()
        return bytes
    }

    /// Restores the saved native view without invoking a numerical operator.
    @concurrent private static func decodeArchive(
        _ data: Data, saved: GlifiStudioSavedAnalysis
    ) async throws -> Archive {
        try Task.checkCancellation()
        guard data.count <= 8 * 1_048_576 else { throw Self.invalidInput() }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        let result = try JSONSerialization.jsonObject(with: archive.result) as? NSDictionary
        let authoritative =
            try JSONSerialization.jsonObject(with: saved.resultJSON) as? NSDictionary
        guard archive.client == "khMatrix", archive.version == 1,
            archive.request == saved.requestJSON, result == authoritative,
            archive.methodIdentifier == saved.methodIdentifier,
            archive.requestDigest == authoritative?["requestDigest"] as? String,
            archive.tables.reduce(0, { $0 + $1.rows.count }) <= 100_000,
            archive.tables.allSatisfy({ table in
                table.rows.allSatisfy { $0.count == table.columns.count }
            }), archive.rowLabels.count <= 10_000, archive.columnLabels.count <= 10_000,
            archive.draft.matrix.values.count <= 1_000,
            archive.draft.matrix.values.allSatisfy({ row in
                row.count == archive.draft.matrix.columnLabels.count && row.allSatisfy(\.isFinite)
            }), archive.draft.matrix.rowLabels.count == archive.draft.matrix.values.count
        else { throw Self.invalidInput() }
        _ = try GlifiStudioTextAnalysisRequest.decode(archive.request)
        if let provenance = archive.provenance {
            guard provenance.sourceRevisionIDs == saved.sourceRevisionIDs,
                provenance.sourceRevisionIDs.count == provenance.contentDigests.count
            else { throw Self.invalidInput() }
        }
        if let input = archive.draft.input {
            guard input.sourceRevisionIDs.count == input.documents.count,
                input.matrix.count == input.documents.count,
                input.matrix.allSatisfy({ $0.count == input.terms.count }),
                input.sourceRevisionIDs.count <= 200, input.terms.count <= 1_000,
                archive.provenance == nil || input.preparationDigest == saved.preparationDigest
            else { throw Self.invalidInput() }
        }
        try Task.checkCancellation()
        return archive
    }

    func restoreArchive(_ data: Data, saved: GlifiStudioSavedAnalysis) async throws {
        let expected = UUID()
        revision = expected
        let archive = try await Self.decodeArchive(data, saved: saved)
        try Task.checkCancellation()
        guard revision == expected else { throw CancellationError() }
        reset()
        let draft = archive.draft
        tool = draft.tool
        matrix = draft.matrix
        maximumTerms = draft.maximumTerms
        axis = draft.axis
        constantPolicy = draft.constantPolicy
        zeroExposurePolicy = draft.zeroExposurePolicy
        rowScaling = draft.rowScaling
        columnScaling = draft.columnScaling
        scoreMode = draft.scoreMode
        correction = draft.correction
        exposures = draft.exposures
        documentFrequencies = draft.documentFrequencies
        corpusDocumentCount = draft.corpusDocumentCount
        jointCount = draft.jointCount
        nodeFrequency = draft.nodeFrequency
        collocateFrequency = draft.collocateFrequency
        corpusTokenCount = draft.corpusTokenCount
        windowSpan = draft.windowSpan
        conditionDocumentCount = draft.conditionDocumentCount
        termDocumentCount = draft.termDocumentCount
        totalDocumentCount = draft.totalDocumentCount
        contextLevels = draft.contextLevels
        contextTargetIDs = draft.contextTargetIDs
        contextIDs = draft.contextIDs
        nodeTerm = draft.nodeTerm
        collocateTerm = draft.collocateTerm
        windowRadius = draft.windowRadius
        conditionSourceIDs = draft.conditionSourceIDs
        usesCorpusAuxiliary = draft.usesCorpusAuxiliary
        distance = draft.distance
        clustersTerms = draft.clustersTerms
        input = draft.input
        preparedExposures = draft.preparedExposures
        preparedFrequencies = draft.preparedFrequencies
        capturedDraft = draft
        output = StudioKHMatrixOutput(
            tool: draft.tool, methodIdentifier: archive.methodIdentifier,
            validationStatus: archive.validationStatus, requestDigest: archive.requestDigest,
            request: archive.request, result: archive.result, typedResult: nil,
            tables: archive.tables, provenance: archive.provenance,
            rowLabels: archive.rowLabels, columnLabels: archive.columnLabels,
            draftID: draftID, completedAt: archive.completedAt)
    }

    @concurrent private static func prepareAuxiliary(
        _ input: GlifiStudioProjectTextAnalysisInput
    ) async throws -> (exposures: [Double], frequencies: [Int]) {
        var frequencies = [Int](repeating: 0, count: input.terms.count)
        for row in input.matrix {
            try Task.checkCancellation()
            for column in row.indices where row[column] > 0 { frequencies[column] += 1 }
        }
        return (input.documents.map { Double($0.count) }, frequencies)
    }

    @concurrent private static func corpusAssociation(
        _ input: GlifiStudioProjectTextAnalysisInput, term: String, condition: Set<String>
    ) async throws -> GlifiStudioKHWordAssociationInput {
        var joint = 0
        var conditionCount = 0
        var termCount = 0
        for index in input.documents.indices {
            try Task.checkCancellation()
            let contains = input.documents[index].contains(term)
            let selected = condition.contains(input.sourceRevisionIDs[index])
            if contains { termCount += 1 }
            if selected { conditionCount += 1 }
            if contains && selected { joint += 1 }
        }
        return .init(
            jointCount: joint, conditionDocumentCount: conditionCount,
            termDocumentCount: termCount, totalDocumentCount: input.documents.count)
    }

    @concurrent private static func corpusCollocation(
        _ input: GlifiStudioProjectTextAnalysisInput, node: String, collocate: String, radius: Int
    ) async throws -> GlifiStudioKHCollocationInput {
        guard (1...100).contains(radius), !node.isEmpty, !collocate.isEmpty else {
            throw invalidInput()
        }
        var joint = 0
        var first = 0
        var second = 0
        for tokens in input.documents {
            try Task.checkCancellation()
            for index in tokens.indices {
                if tokens[index] == collocate { second += 1 }
                guard tokens[index] == node else { continue }
                first += 1
                for neighbor in max(0, index - radius)...min(tokens.count - 1, index + radius)
                where neighbor != index && tokens[neighbor] == collocate {
                    joint += 1
                }
            }
        }
        return .init(
            jointCount: joint, nodeFrequency: first, collocateFrequency: second,
            corpusTokenCount: input.lexicalTokenCount, windowSpan: 2 * radius)
    }

    nonisolated static func invalidInput() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "ui.kh-matrix.invalid-input", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "kh.matrix.invalid-input")
    }

    @concurrent private static func present(
        _ result: GlifiStudioTextAnalysisResult, request: GlifiStudioKHAnalysisRequest,
        tool: StudioKHMatrixTool, locale: Locale, rowLabels: [String], columnLabels: [String],
        provenance: StudioKHMatrixProvenance?, draftID: UUID
    ) async throws -> StudioKHMatrixOutput {
        guard case let .advanced(.kh(payload)) = result.payload else { throw invalidInput() }
        func number(_ value: Double?) -> String {
            value.map { $0.formatted(.number.precision(.significantDigits(1...12)).locale(locale)) }
                ?? "—"
        }
        func table(
            _ id: String, _ matrix: [[Double]], rows: [String]? = nil, columns: [String]? = nil
        ) -> StudioKHMatrixTable {
            let labels = rows ?? rowLabels
            let headers = columns ?? columnLabels
            return StudioKHMatrixTable(
                id: id, titleKey: "kh.matrix.result.\(id)",
                columns: ["kh.matrix.row"]
                    + (matrix.first?.indices.map {
                        headers.indices.contains($0) ? headers[$0] : String($0 + 1)
                    } ?? []),
                rows: matrix.enumerated().map {
                    [labels.indices.contains($0.offset) ? labels[$0.offset] : String($0.offset + 1)]
                        + $0.element.map { number($0) }
                })
        }
        func metrics(_ values: [(String, Double?)]) -> StudioKHMatrixTable {
            StudioKHMatrixTable(
                id: "metrics", titleKey: "kh.matrix.result.metrics",
                columns: ["kh.matrix.metric", "kh.matrix.value"],
                rows: values.map { ["kh.matrix.metric.\($0.0)", number($0.1)] })
        }
        let tables: [StudioKHMatrixTable]
        switch payload {
        case let .matrix(values): tables = [table("matrix", values)]
        case let .wordContext(value):
            tables = [
                table("context", value.values),
                table(
                    "support", value.supportCounts.map { $0.map(Double.init) },
                    rows: value.levels.map { "kh.matrix.level.\($0.rawValue)" },
                    columns: value.targetIDs),
            ]
        case let .correspondence(value):
            tables = [
                table(
                    "rows", value.rowCoordinates,
                    rows: value.includedRows.map {
                        rowLabels.indices.contains($0) ? rowLabels[$0] : String($0 + 1)
                    }, columns: []),
                table(
                    "columns", value.columnCoordinates,
                    rows: value.includedColumns.map {
                        columnLabels.indices.contains($0) ? columnLabels[$0] : String($0 + 1)
                    }, columns: []),
            ]
        case let .collocation(value):
            tables = [
                metrics([
                    ("mi3", value.mi3), ("z", value.zScore),
                    ("expected", value.expectedWindowCount),
                    ("mi", value.mutualInformation), ("t", value.tScore),
                    ("jaccard", value.jaccard),
                    ("dice", value.dice), ("logLikelihood", value.logLikelihood),
                ])
            ]
        case let .wordAssociation(value):
            tables = [
                metrics([
                    ("unconditional", value.unconditionalProbability),
                    ("conditional", value.conditionalProbability),
                    ("differential", value.differential), ("lift", value.lift),
                    ("jaccard", value.jaccard),
                    ("ochiai", value.ochiai),
                ])
            ]
        case let .documentScores(value):
            tables = [
                table("contributions", value.termContributions),
                table("scores", value.scores.map { [$0] }, columns: ["kh.matrix.value"]),
            ]
        case let .legacyClustering(value):
            tables = [
                StudioKHMatrixTable(
                    id: "units", titleKey: "kh.matrix.result.units",
                    columns: ["kh.matrix.row", "kh.matrix.unit"],
                    rows: rowLabels.enumerated().map { [String($0.offset + 1), $0.element] }),
                StudioKHMatrixTable(
                    id: "tree", titleKey: "kh.matrix.result.tree",
                    columns: [
                        "kh.matrix.merge", "kh.matrix.first", "kh.matrix.second",
                        "kh.matrix.height", "kh.matrix.size",
                    ],
                    rows: value.children.enumerated().map { index, children in
                        [
                            String(index + 1), String(children[0] + 1), String(children[1] + 1),
                            number(value.heights[index]), String(value.sizes[index]),
                        ]
                    }),
            ]
        case let .chiSquare(value):
            tables =
                [
                    metrics([
                        ("chiSquare", value.statistic), ("pValue", value.pValue),
                        ("df", Double(value.degreesOfFreedom)),
                    ])
                ]
                + [
                    ("expected", value.expected), ("pearson", value.pearsonResiduals),
                    ("standardized", value.standardizedResiduals),
                ].map { id, values in
                    StudioKHMatrixTable(
                        id: id, titleKey: "kh.matrix.result.\(id)",
                        columns: ["kh.matrix.row"]
                            + (values.first?.indices.map {
                                columnLabels.indices.contains($0)
                                    ? columnLabels[$0] : String($0 + 1)
                            } ?? []),
                        rows: values.enumerated().map {
                            [
                                rowLabels.indices.contains($0.offset)
                                    ? rowLabels[$0.offset] : String($0.offset + 1)
                            ] + $0.element.map(number)
                        })
                }
        case .mds, .mdsSearch, .som, .codeCrosstabSignificance, .termScores, .termExtraction,
            .incrementalClassifier, .classifierAgreement:
            throw invalidInput()
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        func localized(_ key: String) -> String {
            String(localized: String.LocalizationValue(key), bundle: .main, locale: locale)
        }
        let localizedTables = tables.map { value in
            let allHeaders = ["metrics", "tree", "units"].contains(value.id)
            let columns = value.columns.enumerated().map { index, label in
                allHeaders || index == 0 || (value.id == "scores" && index == 1)
                    ? localized(label) : label
            }
            let rows: [[String]]
            if value.id == "metrics" || value.id == "support" {
                rows = value.rows.map { row in
                    row.enumerated().map { $0.offset == 0 ? localized($0.element) : $0.element }
                }
            } else {
                rows = value.rows
            }
            return StudioKHMatrixTable(
                id: value.id, titleKey: value.titleKey,
                columns: columns, rows: rows)
        }
        return try StudioKHMatrixOutput(
            tool: tool, methodIdentifier: result.methodIdentifier,
            validationStatus: result.validationStatus, requestDigest: result.requestDigest,
            request: GlifiStudioTextAnalysisRequest.advanced(.kh(request)).canonicalData(),
            result: encoder.encode(result), typedResult: result, tables: localizedTables,
            provenance: provenance, rowLabels: rowLabels, columnLabels: columnLabels,
            draftID: draftID, completedAt: .now)
    }
}
