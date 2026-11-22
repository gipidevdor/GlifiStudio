// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Explicit KH public profiles, sharing the canonical text-analysis envelope and CLI.
public enum GlifiStudioKHAnalysisRequest: Equatable, Sendable, Encodable {
    /// Sample n−1 standardization with an explicit treatment of constant vectors.
    case sampleZScores(
        matrix: [[Double]], axis: GlifiStudioKHMatrixAxis,
        constantPolicy: GlifiStudioKHConstantPolicy = .reject)
    case perThousand(
        matrix: [[Double]], exposures: [Double],
        zeroExposurePolicy: GlifiStudioKHZeroExposurePolicy = .reject)
    case wordContext(
        levels: [GlifiStudioKHContextCounts], targetIDs: [String], contextIDs: [String])
    case correspondenceScaled(
        matrix: [[Double]], rowScaling: GlifiStudioKHCorrespondenceScaling = .principal,
        columnScaling: GlifiStudioKHCorrespondenceScaling = .principal)
    case ordinalMDS(
        matrix: [[Double]], dimensions: Int = 2, ties: GlifiStudioMDSOrdinalTies = .primary,
        seed: UInt64 = 0, maximumIterations: Int = 300, tolerance: Double = 1e-8)
    case ordinalMDSSearch(
        matrix: [[Double]], dimensions: Int = 2, ties: GlifiStudioMDSOrdinalTies = .primary,
        starts: Int = 10, seed: UInt64 = 0, maximumIterations: Int = 300, tolerance: Double = 1e-8)
    case somPCAInitialization(matrix: [[Double]], width: Int, height: Int)
    case somKH(
        matrix: [[Double]], width: Int, height: Int,
        firstPhase: GlifiStudioKHSOMPhase? = nil, secondPhase: GlifiStudioKHSOMPhase? = nil,
        topology: GlifiStudioSOMTopology = .hexagonal, initialCodebooks: [[Double]]? = nil,
        codebookClusterCount: Int? = nil)
    case collocationScores(GlifiStudioKHCollocationInput)
    case termScores(
        candidates: [GlifiStudioTermCandidate], preprocessingIdentifier: String,
        adjacencyMode: GlifiStudioTermAdjacencyMode = .token, maximumWork: Int = 100_000_000)
    case termExtraction(
        documents: [GlifiStudioTermDocument], rule: GlifiStudioTermExtractionRule,
        adjacencyMode: GlifiStudioTermAdjacencyMode = .token, maximumWork: Int = 100_000_000)
    case incrementalClassifier(
        documents: [[String]], labels: [String], smoothing: Double = 1,
        predictionDocuments: [[String]] = [])
    case continueClassifier(
        state: GlifiStudioNaiveBayesTrainingState, documents: [[String]], labels: [String],
        predictionDocuments: [[String]] = [])
    case validateClassifierWithAgreement(
        documents: [[String]], labels: [String], folds: Int, seed: UInt64, smoothing: Double = 1)

    /// Stable flat tag shared by the native and CLI dispatchers.
    public var operation: String {
        switch self {
        case .sampleZScores: "matrix-zscore"
        case .perThousand: "matrix-per-thousand"
        case .wordContext: "word-context"
        case .correspondenceScaled: "correspondence-scaled"
        case .ordinalMDS: "mds-ordinal"
        case .ordinalMDSSearch: "mds-ordinal-search"
        case .somPCAInitialization: "som-pca-initialization"
        case .somKH: "som-kh"
        case .collocationScores: "kh-collocation"
        case .termScores: "term-scores"
        case .termExtraction: "term-extraction"
        case .incrementalClassifier: "incremental-classifier"
        case .continueClassifier: "continue-classifier"
        case .validateClassifierWithAgreement: "validate-classifier-kappa"
        }
    }

    init(from decoder: any Decoder) throws {
        let f = try decoder.container(keyedBy: TextAnalysisKey.self)
        let operation: String = try f.khRequired("operation")
        let allowed: Set<String>
        switch operation {
        case "matrix-zscore":
            allowed = ["matrix", "axis", "constantPolicy"]
            self = .sampleZScores(
                matrix: try f.khRequired("matrix"), axis: try f.khRequired("axis"),
                constantPolicy: try f.khDefault("constantPolicy", .reject))
        case "matrix-per-thousand":
            allowed = ["matrix", "exposures", "zeroExposurePolicy"]
            self = .perThousand(
                matrix: try f.khRequired("matrix"), exposures: try f.khRequired("exposures"),
                zeroExposurePolicy: try f.khDefault("zeroExposurePolicy", .reject))
        case "word-context":
            allowed = ["levels", "targetIDs", "contextIDs"]
            self = .wordContext(
                levels: try f.khRequired("levels"), targetIDs: try f.khRequired("targetIDs"),
                contextIDs: try f.khRequired("contextIDs"))
        case "correspondence-scaled":
            allowed = ["matrix", "rowScaling", "columnScaling"]
            self = .correspondenceScaled(
                matrix: try f.khRequired("matrix"),
                rowScaling: try f.khDefault("rowScaling", .principal),
                columnScaling: try f.khDefault("columnScaling", .principal))
        case "mds-ordinal", "mds-ordinal-search":
            let matrix: [[Double]] = try f.khRequired("matrix")
            let dimensions = try f.khDefault("dimensions", 2)
            let ties: GlifiStudioMDSOrdinalTies = try f.khDefault("ties", .primary)
            let seed: UInt64 = try f.khDefault("seed", 0)
            let iterations = try f.khDefault("maximumIterations", 300)
            let tolerance = try f.khDefault("tolerance", 1e-8)
            let fields: Set<String> = [
                "matrix", "dimensions", "ties", "seed", "maximumIterations", "tolerance",
            ]
            if operation == "mds-ordinal-search" {
                allowed = fields.union(["starts"])
                self = .ordinalMDSSearch(
                    matrix: matrix, dimensions: dimensions, ties: ties,
                    starts: try f.khDefault("starts", 10),
                    seed: seed, maximumIterations: iterations, tolerance: tolerance)
            } else {
                allowed = fields
                self = .ordinalMDS(
                    matrix: matrix, dimensions: dimensions, ties: ties, seed: seed,
                    maximumIterations: iterations, tolerance: tolerance)
            }
        case "som-pca-initialization":
            allowed = ["matrix", "width", "height"]
            self = .somPCAInitialization(
                matrix: try f.khRequired("matrix"), width: try f.khRequired("width"),
                height: try f.khRequired("height"))
        case "som-kh":
            allowed = [
                "matrix", "width", "height", "firstPhase", "secondPhase", "topology",
                "initialCodebooks", "codebookClusterCount",
            ]
            let matrix: [[Double]] = try f.khRequired("matrix")
            let width: Int = try f.khRequired("width")
            let height: Int = try f.khRequired("height")
            self = .somKH(
                matrix: matrix, width: width, height: height,
                firstPhase: try f.khDefault(
                    "firstPhase",
                    khDefaultPhase(rows: matrix.count, width: width, height: height, first: true)),
                secondPhase: try f.khDefault(
                    "secondPhase",
                    khDefaultPhase(rows: matrix.count, width: width, height: height, first: false)),
                topology: try f.khDefault("topology", .hexagonal),
                initialCodebooks: try f.khOptional("initialCodebooks"),
                codebookClusterCount: try f.khOptional("codebookClusterCount"))
        case "kh-collocation":
            allowed = ["counts"]
            self = .collocationScores(try f.khRequired("counts"))
        case "term-scores":
            allowed = ["candidates", "preprocessingIdentifier", "adjacencyMode", "maximumWork"]
            self = .termScores(
                candidates: try f.khRequired("candidates"),
                preprocessingIdentifier: try f.khRequired("preprocessingIdentifier"),
                adjacencyMode: try f.khDefault("adjacencyMode", .token),
                maximumWork: try f.khDefault("maximumWork", 100_000_000))
        case "term-extraction":
            allowed = ["documents", "rule", "adjacencyMode", "maximumWork"]
            self = .termExtraction(
                documents: try f.khRequired("documents"), rule: try f.khRequired("rule"),
                adjacencyMode: try f.khDefault("adjacencyMode", .token),
                maximumWork: try f.khDefault("maximumWork", 100_000_000))
        case "incremental-classifier":
            allowed = ["documents", "labels", "smoothing", "predictionDocuments"]
            self = .incrementalClassifier(
                documents: try f.khRequired("documents"), labels: try f.khRequired("labels"),
                smoothing: try f.khDefault("smoothing", 1),
                predictionDocuments: try f.khDefault("predictionDocuments", []))
        case "continue-classifier":
            allowed = ["state", "documents", "labels", "predictionDocuments"]
            self = .continueClassifier(
                state: try f.khRequired("state"), documents: try f.khRequired("documents"),
                labels: try f.khRequired("labels"),
                predictionDocuments: try f.khDefault("predictionDocuments", []))
        case "validate-classifier-kappa":
            allowed = ["documents", "labels", "folds", "seed", "smoothing"]
            self = .validateClassifierWithAgreement(
                documents: try f.khRequired("documents"), labels: try f.khRequired("labels"),
                folds: try f.khRequired("folds"),
                seed: try f.khRequired("seed"), smoothing: try f.khDefault("smoothing", 1))
        default: throw textRequestFailure("text-analysis.unknown-operation")
        }
        guard
            f.allKeys.allSatisfy({
                allowed.union(["schema", "schemaVersion", "operation"]).contains($0.stringValue)
            })
        else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
    }

    func validate(budget: inout TextAnalysisBudget) throws {
        switch self {
        case let .sampleZScores(matrix, _, _), let .correspondenceScaled(matrix, _, _),
            let .ordinalMDS(matrix, _, _, _, _, _), let .ordinalMDSSearch(matrix, _, _, _, _, _, _),
            let .somPCAInitialization(matrix, _, _):
            try budget.matrix(matrix)
        case let .perThousand(matrix, exposures, _):
            try budget.matrix(matrix)
            try budget.matrix([exposures])
        case let .wordContext(levels, targets, contexts):
            try budget.strings(targets)
            try budget.strings(contexts)
            guard levels.count <= 7 else {
                throw textRequestFailure(
                    "text-analysis.request-limit", category: "insufficientResources")
            }
            for level in levels {
                try budget.matrix(level.targetCounts)
                try budget.matrix(level.contextCounts)
                try khFinite([level.alpha])
            }
        case let .somKH(matrix, _, _, first, second, _, initial, _):
            try budget.matrix(matrix)
            if let initial { try budget.matrix(initial) }
            for phase in [first, second].compactMap({ $0 }) {
                try khFinite([phase.initialLearningRate, phase.initialRadius])
            }
        case .collocationScores: break
        case let .termScores(candidates, preprocessing, _, _):
            try budget.string(preprocessing)
            try budget.collectionCount(candidates.count)
            for candidate in candidates { try budget.strings(candidate.components) }
        case let .termExtraction(documents, rule, _, _):
            try budget.string(rule.identifier)
            try budget.strings(rule.allowedPartsOfSpeech)
            try budget.strings(rule.ignoredKeys)
            guard rule.allowedPartsOfSpeech.count <= 256, rule.ignoredKeys.count <= 4_096 else {
                throw textRequestFailure(
                    "text-analysis.request-limit", category: "insufficientResources")
            }
            try budget.collectionCount(documents.count)
            for document in documents {
                try budget.string(document.id)
                try budget.string(document.text)
                try budget.string(document.linguisticContract)
                try budget.collectionCount(document.tokens.count)
                for token in document.tokens {
                    try budget.string(token.surface)
                    try budget.string(token.base)
                    if let pos = token.partOfSpeech { try budget.string(pos) }
                }
            }
        case let .incrementalClassifier(documents, labels, smoothing, prediction):
            try budget.documents(documents)
            try budget.strings(labels)
            try budget.documents(prediction)
            try khFinite([smoothing])
        case let .continueClassifier(state, documents, labels, prediction):
            try budget.documents(documents)
            try budget.strings(labels)
            try budget.documents(prediction)
            try budget.strings(state.classes)
            try budget.strings(state.vocabulary)
            try budget.integers(state.documentCounts)
            try budget.collectionCount(state.tokenCounts.count)
            for row in state.tokenCounts { try budget.integers(row) }
            try khFinite([state.smoothing])
        case let .validateClassifierWithAgreement(documents, labels, _, _, smoothing):
            try budget.documents(documents)
            try budget.strings(labels)
            try khFinite([smoothing])
        }
        switch self {
        case let .ordinalMDS(_, _, _, _, _, tolerance),
            let .ordinalMDSSearch(_, _, _, _, _, _, tolerance):
            try khFinite([tolerance])
        case .sampleZScores, .perThousand, .wordContext, .correspondenceScaled,
            .somPCAInitialization,
            .somKH, .collocationScores, .termScores, .termExtraction, .incrementalClassifier,
            .continueClassifier,
            .validateClassifierWithAgreement:
            break
        }
    }

    /// Writes resolved defaults to the existing text-analysis schema; prefer canonicalData at boundaries.
    public func encode(to encoder: any Encoder) throws {
        var f = encoder.container(keyedBy: TextAnalysisKey.self)
        try f.encode(GlifiStudioTextAnalysisRequest.schema, forKey: TextAnalysisKey("schema"))
        try f.encode(
            GlifiStudioTextAnalysisRequest.schemaVersion, forKey: TextAnalysisKey("schemaVersion"))
        try f.encode(operation, forKey: TextAnalysisKey("operation"))
        switch self {
        case let .sampleZScores(matrix, axis, policy):
            try f.khEncode("matrix", matrix)
            try f.khEncode("axis", axis)
            try f.khEncode("constantPolicy", policy)
        case let .perThousand(matrix, exposures, policy):
            try f.khEncode("matrix", matrix)
            try f.khEncode("exposures", exposures)
            try f.khEncode("zeroExposurePolicy", policy)
        case let .wordContext(levels, targets, contexts):
            try f.khEncode("levels", levels)
            try f.khEncode("targetIDs", targets)
            try f.khEncode("contextIDs", contexts)
        case let .correspondenceScaled(matrix, rows, columns):
            try f.khEncode("matrix", matrix)
            try f.khEncode("rowScaling", rows)
            try f.khEncode("columnScaling", columns)
        case let .ordinalMDS(matrix, dimensions, ties, seed, iterations, tolerance):
            try f.khMDS(
                matrix, dimensions: dimensions, ties: ties, seed: seed, iterations: iterations,
                tolerance: tolerance)
        case let .ordinalMDSSearch(matrix, dimensions, ties, starts, seed, iterations, tolerance):
            try f.khMDS(
                matrix, dimensions: dimensions, ties: ties, seed: seed, iterations: iterations,
                tolerance: tolerance)
            try f.khEncode("starts", starts)
        case let .somPCAInitialization(matrix, width, height):
            try f.khEncode("matrix", matrix)
            try f.khEncode("width", width)
            try f.khEncode("height", height)
        case let .somKH(matrix, width, height, first, second, topology, initial, clusters):
            try f.khEncode("matrix", matrix)
            try f.khEncode("width", width)
            try f.khEncode("height", height)
            try f.khEncode("topology", topology)
            try f.khEncode(
                "firstPhase",
                first
                    ?? khDefaultPhase(rows: matrix.count, width: width, height: height, first: true)
            )
            try f.khEncode(
                "secondPhase",
                second
                    ?? khDefaultPhase(
                        rows: matrix.count, width: width, height: height, first: false))
            if let initial { try f.khEncode("initialCodebooks", initial) }
            if let clusters { try f.khEncode("codebookClusterCount", clusters) }
        case let .collocationScores(counts): try f.khEncode("counts", counts)
        case let .termScores(candidates, preprocessing, adjacency, work):
            try f.khEncode("candidates", candidates)
            try f.khEncode("preprocessingIdentifier", preprocessing)
            try f.khEncode("adjacencyMode", adjacency)
            try f.khEncode("maximumWork", work)
        case let .termExtraction(documents, rule, adjacency, work):
            try f.khEncode("documents", documents)
            try f.khEncode("rule", rule)
            try f.khEncode("adjacencyMode", adjacency)
            try f.khEncode("maximumWork", work)
        case let .incrementalClassifier(documents, labels, smoothing, prediction):
            try f.khEncode("documents", documents)
            try f.khEncode("labels", labels)
            try f.khEncode("smoothing", smoothing)
            try f.khEncode("predictionDocuments", prediction)
        case let .continueClassifier(state, documents, labels, prediction):
            try f.khEncode("state", state)
            try f.khEncode("documents", documents)
            try f.khEncode("labels", labels)
            try f.khEncode("predictionDocuments", prediction)
        case let .validateClassifierWithAgreement(documents, labels, folds, seed, smoothing):
            try f.khEncode("documents", documents)
            try f.khEncode("labels", labels)
            try f.khEncode("folds", folds)
            try f.khEncode("seed", seed)
            try f.khEncode("smoothing", smoothing)
        }
    }
}

private func khDefaultPhase(rows: Int, width: Int, height: Int, first: Bool)
    -> GlifiStudioKHSOMPhase
{
    GlifiStudioKHSOMPhase(
        steps: rows * (first ? 2 : 10), initialLearningRate: first ? 0.05 : 0.02,
        initialRadius: Double(first ? min(width, height) : min(3, min(width, height))))
}

private func khFinite(_ values: [Double]) throws {
    guard values.allSatisfy(\.isFinite) else {
        throw textRequestFailure("text-analysis.non-finite")
    }
}

extension KeyedEncodingContainer where Key == TextAnalysisKey {
    mutating func khEncode<T: Encodable>(_ name: String, _ value: T) throws {
        try encode(value, forKey: TextAnalysisKey(name))
    }
    mutating func khMDS(
        _ matrix: [[Double]], dimensions: Int, ties: GlifiStudioMDSOrdinalTies,
        seed: UInt64, iterations: Int, tolerance: Double
    ) throws {
        try khEncode("matrix", matrix)
        try khEncode("dimensions", dimensions)
        try khEncode("ties", ties)
        try khEncode("seed", seed)
        try khEncode("maximumIterations", iterations)
        try khEncode("tolerance", tolerance)
    }
}
