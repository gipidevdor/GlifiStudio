// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Bounded native KH profiles; both Swift and external JSON use the same execution path.
public enum GlifiStudioKHAnalysis {
    /// Executes the same canonical request, domain failures and result envelope as CLI text-analysis.
    @concurrent public static func execute(
        _ request: GlifiStudioKHAnalysisRequest
    ) async throws(GlifiStudioFailure) -> GlifiStudioTextAnalysisResult {
        try await GlifiStudioTextAnalytics.executeTextAnalysis(.advanced(.kh(request)))
    }
}

extension GlifiStudioKHAnalysisRequest {
    @concurrent func execute() async throws(GlifiStudioFailure) -> (
        String, GlifiStudioKHAnalysisPayload
    ) {
        do {
            try Task.checkCancellation()
            switch self {
            case let .sampleZScores(matrix, axis, policy):
                let result = try GlifiKHMatrixPreparation.sampleZScores(
                    matrix, axis: axis == .rows ? .rows : .columns,
                    constantPolicy: policy == .reject ? .reject : .zeros)
                return (GlifiKHMatrixPreparation.sampleZScoreIdentifier, .matrix(result))
            case let .perThousand(matrix, exposures, policy):
                let result = try GlifiKHMatrixPreparation.perThousand(
                    matrix, exposures: exposures,
                    zeroExposurePolicy: policy == .reject ? .reject : .zeros)
                return (GlifiKHMatrixPreparation.exposureIdentifier, .matrix(result))
            case let .wordContext(levels, targets, contexts):
                let result = try GlifiKHMatrixPreparation.wordContext(
                    levels.map {
                        GlifiKHContextCounts(
                            level: $0.level.core, alpha: $0.alpha,
                            targetCounts: $0.targetCounts, contextCounts: $0.contextCounts)
                    }, targetIDs: targets, contextIDs: contexts)
                return (GlifiKHWordContextResult.identifier, .wordContext(.init(result)))
            case let .correspondenceScaled(matrix, rows, columns):
                try khCorrespondenceAdmission(matrix)
                let analysis = try GlifiMultivariateMethods.correspondenceAnalysis(matrix)
                let result = try GlifiKHMatrixPreparation.correspondenceCoordinates(
                    analysis, rowScaling: rows.core, columnScaling: columns.core)
                return (GlifiKHCorrespondenceCoordinates.identifier, .correspondence(.init(result)))
            case let .ordinalMDS(matrix, dimensions, ties, seed, iterations, tolerance):
                let result = try GlifiExploratoryAnalysis.ordinalMultidimensionalScaling(
                    matrix, dimensions: dimensions, seed: seed,
                    maximumIterations: iterations, tolerance: tolerance, ties: ties.core)
                return (result.methodIdentifier, .mds(.init(result)))
            case let .ordinalMDSSearch(
                matrix, dimensions, ties, starts, seed, iterations, tolerance):
                let result = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
                    matrix, dimensions: dimensions, method: .ordinal, starts: starts, seed: seed,
                    maximumIterations: iterations, tolerance: tolerance, ordinalTies: ties.core)
                return (GlifiMDSSearchResult.identifier, .mdsSearch(.init(result)))
            case let .somPCAInitialization(matrix, width, height):
                let result = try GlifiExploratoryAnalysis.khSelfOrganizingMapPCAInitialization(
                    matrix, width: width, height: height)
                return ("SOM-PCA-linear-unscaled-canonical-v1", .matrix(result))
            case let .somKH(matrix, width, height, first, second, topology, initial, clusters):
                let result = try GlifiExploratoryAnalysis.khSelfOrganizingMap(
                    matrix, width: width, height: height, firstPhase: first?.core,
                    secondPhase: second?.core, topology: topology.core, initialCodebooks: initial,
                    codebookClusterCount: clusters)
                return (result.methodIdentifier, .som(.init(result)))
            case let .collocationScores(input):
                let result = try GlifiKHCollocationAnalysis.scores(input.core())
                return ("KH-collocation-MI3-Z-global-token-window-v1", .collocation(.init(result)))
            case let .termScores(candidates, preprocessing, adjacency, work):
                let result = try GlifiTermExtraction.score(
                    candidates.map {
                        try GlifiTermCandidate(components: $0.components, frequency: $0.frequency)
                    },
                    adjacencyMode: adjacency.core, preprocessingIdentifier: preprocessing,
                    maximumWork: work)
                return (GlifiTermExtractionScores.identifier, .termScores(.init(result)))
            case let .termExtraction(documents, rule, adjacency, work):
                let result = try GlifiTermExtraction.extract(
                    documents.map { try $0.core() }, rule: rule.core(),
                    adjacencyMode: adjacency.core, maximumWork: work)
                return (GlifiTermExtractionScores.identifier, .termExtraction(.init(result)))
            case let .incrementalClassifier(documents, labels, smoothing, prediction):
                try khClassifierAdmission(
                    documents: documents, labels: labels, state: nil, predictions: prediction)
                let state = try GlifiIncrementalNaiveBayes.train(
                    documents: documents, labels: labels, smoothing: smoothing)
                return try khClassifierResult(state, predictionDocuments: prediction)
            case let .continueClassifier(state, documents, labels, prediction):
                try khClassifierAdmission(
                    documents: documents, labels: labels, state: state, predictions: prediction)
                let updated = try GlifiIncrementalNaiveBayes.update(
                    state.core(), documents: documents, labels: labels)
                return try khClassifierResult(updated, predictionDocuments: prediction)
            case let .validateClassifierWithAgreement(documents, labels, folds, seed, smoothing):
                let result = try GlifiNaiveBayes.crossValidateWithAgreement(
                    documents: documents, labels: labels, folds: folds, seed: seed,
                    smoothing: smoothing)
                return (
                    GlifiNaiveBayesAgreementEvaluation.identifier,
                    .classifierAgreement(.init(result))
                )
            }
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch is CancellationError {
            throw textRequestFailure("operation.cancelled", category: "cancelled")
        } catch {
            throw GlifiStudioFailure(
                code: "kh-analysis.failed", category: "invariantViolation", operation: "analyze",
                retryDisposition: "never", retainedState: "unchanged",
                messageKey: "failure.category.invariantViolation")
        }
    }
}

private func khClassifierResult(
    _ state: GlifiNaiveBayesTrainingState, predictionDocuments: [[String]]
) throws -> (String, GlifiStudioKHAnalysisPayload) {
    guard state.classes.count >= 2 else {
        guard predictionDocuments.isEmpty else {
            throw exploratoryFailureForKHClassifier()
        }
        return (
            GlifiNaiveBayesTrainingState.identifier,
            .incrementalClassifier(
                .init(
                    state: .init(state), model: nil, predictions: nil))
        )
    }
    let model = try state.model()
    let predictions = try GlifiNaiveBayes.predict(predictionDocuments, using: model)
    let result = GlifiStudioClassification(
        labels: predictions.map(\.label), classes: model.classes,
        probabilities: predictions.map(\.probabilities),
        ignoredTokenCounts: predictions.map(\.ignoredTokenCount))
    return (
        GlifiNaiveBayesTrainingState.identifier,
        .incrementalClassifier(
            .init(
                state: .init(state), model: .init(model), predictions: result))
    )
}

private func exploratoryFailureForKHClassifier() -> GlifiStudioFailure {
    textRequestFailure("naive-bayes.insufficient-classes", category: "insufficientData")
}

private func khCorrespondenceAdmission(_ matrix: [[Double]]) throws {
    guard let columns = matrix.first?.count, columns > 0, !matrix.isEmpty,
        matrix.allSatisfy({ $0.count == columns })
    else { throw textRequestFailure("kh-matrix.invalid-shape") }
    var work = 500_000_000
    // Bound the existing SVD and the coordinate projection as one native workflow.
    for factors in [
        [100, max(matrix.count, columns), min(matrix.count, columns), min(matrix.count, columns)],
        [8, matrix.count + columns, min(matrix.count, columns)],
    ] {
        var estimate = 1
        for factor in factors {
            guard factor == 0 || estimate <= work / factor else {
                throw textRequestFailure(
                    "text-analysis.request-limit", category: "insufficientResources")
            }
            estimate *= factor
        }
        work -= estimate
    }
}

private func khClassifierAdmission(
    documents: [[String]], labels: [String], state: GlifiStudioNaiveBayesTrainingState?,
    predictions: [[String]]
) throws {
    try Task.checkCancellation()
    var remaining = 500_000_000
    func debit(_ factors: [Int]) throws {
        var estimate = 1
        for factor in factors {
            guard factor >= 0, factor == 0 || estimate <= remaining / factor else {
                throw textRequestFailure(
                    "text-analysis.request-limit", category: "insufficientResources")
            }
            estimate *= factor
        }
        remaining -= estimate
    }
    func textBytes(_ values: [String]) throws -> Int {
        var bytes = 0
        for (index, value) in values.enumerated() {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
            let count = value.utf8.count
            guard count <= 1_048_576 - bytes else {
                throw textRequestFailure(
                    "text-analysis.request-limit", category: "insufficientResources")
            }
            bytes += count
        }
        return bytes
    }
    func levels(_ count: Int) -> Int {
        count < 2 ? 1 : Int.bitWidth - (count - 1).leadingZeroBitCount
    }
    let oldClasses = state?.classes ?? []
    let oldTerms = state?.vocabulary ?? []
    let oldBytes = try textBytes(oldClasses) + textBytes(oldTerms)
    // Admission of identifiers precedes the hash tables used to estimate the union.
    try debit([oldBytes, 6])
    try debit([try textBytes(labels), 2])
    var tokenCount = 0
    var tokenBytes = 0
    for document in documents {
        tokenCount += document.count
        tokenBytes += try textBytes(document)
    }
    try debit([tokenCount, 3])
    try debit([tokenBytes, 3])
    try debit([documents.count, 3])
    let classes = Set(oldClasses + labels)
    var vocabulary = Set(oldTerms)
    for document in documents { vocabulary.formUnion(document) }
    let k = classes.count
    let v = vocabulary.count
    guard k > 0, v > 0 else { return }
    guard k <= 5_000_000 / v, predictions.count <= 5_000_000 / k else {
        throw textRequestFailure("text-analysis.request-limit", category: "insufficientResources")
    }
    // Restore, reindex, validate, normalize and inspect the model as one workflow.
    try debit([oldClasses.count, oldTerms.count, 3])
    try debit([v, levels(v)])
    try debit([k, levels(k)])
    try debit([k, v, 9])
    try debit([k, 4])
    try debit([v, 4])
    try debit([try textBytes(Array(vocabulary)), 5])
    try debit([predictions.count, 4])
    try debit([predictions.count, k])
    for (index, document) in predictions.enumerated() {
        if index.isMultiple(of: 256) { try Task.checkCancellation() }
        try debit([document.count, k])
        try debit([try textBytes(document), 3])
        let unique = min(v, document.count)
        try debit([unique, levels(unique)])
    }
}

private extension GlifiStudioMDSOrdinalTies {
    var core: GlifiMDSOrdinalTies {
        switch self {
        case .primary: .primary
        case .secondary: .secondary
        }
    }
}
private extension GlifiStudioTermAdjacencyMode {
    var core: GlifiTermAdjacencyMode {
        switch self {
        case .token: .token
        case .type: .type
        }
    }
}
private extension GlifiStudioKHCorrespondenceScaling {
    var core: GlifiKHCorrespondenceScaling {
        switch self {
        case .principal: .principal
        case .standard: .standard
        case .symmetric: .symmetric
        }
    }
}
private extension GlifiStudioKHContextLevel {
    var core: GlifiKHContextLevel {
        switch self {
        case .sentence: .sentence
        case .paragraph: .paragraph
        case .h5: .h5
        case .h4: .h4
        case .h3: .h3
        case .h2: .h2
        case .h1: .h1
        }
    }
}
