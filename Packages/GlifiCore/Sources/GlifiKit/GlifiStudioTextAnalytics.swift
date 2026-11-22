// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Presentation-independent MDS result.
public struct GlifiStudioMDSResult: Encodable, Equatable, Sendable {
    /// Versioned algorithm and stress definition.
    public let methodIdentifier: String
    /// Coordinates in input object order.
    public let coordinates: [[Double]]
    /// Signed classical eigenvalues; empty for iterative methods.
    public let eigenvalues: [Double]
    /// Final method-specific stress.
    public let stress: Double
    /// Initial and accepted objectives.
    public let objectiveHistory: [Double]
    /// Accepted steps.
    public let iterations: Int
    /// Whether tolerance was reached.
    public let converged: Bool
    /// Initialization seed.
    public let seed: UInt64

    init(_ result: GlifiMDSResult) {
        methodIdentifier = result.methodIdentifier
        coordinates = result.coordinates
        eigenvalues = result.eigenvalues
        stress = result.stress
        objectiveHistory = result.objectiveHistory
        iterations = result.iterations
        converged = result.converged
        seed = result.seed
    }
}

/// MDS methods admitted by the application-facing facade.
public enum GlifiStudioMDSMethod: String, Codable, Sendable {
    case classical
    case metric
    case kruskal
    case sammon

    var core: GlifiMDSMethod {
        switch self {
        case .classical: .classical
        case .metric: .metric
        case .kruskal: .kruskal
        case .sammon: .sammon
        }
    }
}

/// Application-facing SOM diagnostics and prototypes.
public struct GlifiStudioSOMResult: Encodable, Equatable, Sendable {
    /// Versioned algorithm.
    public let methodIdentifier: String
    /// Grid width.
    public let width: Int
    /// Grid height.
    public let height: Int
    /// Row-major grid prototypes.
    public let prototypes: [[Double]]
    /// Best unit per input object.
    public let assignments: [Int]
    /// Mean Euclidean quantization error.
    public let quantizationError: Double
    /// Topographic error on the rectangular grid.
    public let topographicError: Double
    /// Completed epochs.
    public let epochs: Int
    /// Whether final prototypes stabilized.
    public let converged: Bool
    /// Initialization seed.
    public let seed: UInt64

    init(_ value: GlifiSOMResult) {
        methodIdentifier = GlifiSOMResult.identifier
        width = value.width
        height = value.height
        prototypes = value.prototypes
        assignments = value.assignments
        quantizationError = value.quantizationError
        topographicError = value.topographicError
        epochs = value.epochs
        converged = value.converged
        seed = value.seed
    }
}

/// Application-facing sampled medoid clustering.
public struct GlifiStudioCLARAResult: Encodable, Equatable, Sendable {
    /// Versioned algorithm.
    public let methodIdentifier: String
    /// Medoid input indexes.
    public let medoids: [Int]
    /// Assignment per input object.
    public let assignments: [Int]
    /// Sum of distances to medoids.
    public let objective: Double
    /// Recorded seed.
    public let seed: UInt64

    init(_ value: GlifiCLARAResult) {
        methodIdentifier = GlifiCLARAResult.identifier
        medoids = value.medoids
        assignments = value.assignments
        objective = value.objective
        seed = value.seed
    }
}

/// Application-facing topic analysis with explicit vocabulary and posterior means.
public struct GlifiStudioLDAResult: Encodable, Equatable, Sendable {
    /// Versioned inference contract.
    public let methodIdentifier: String
    /// Canonical vocabulary.
    public let vocabulary: [String]
    /// Posterior document-topic means.
    public let documentTopics: [[Double]]
    /// Posterior topic-term means.
    public let topicTerms: [[Double]]
    /// Initialization and sampling seed.
    public let seed: UInt64
    /// Posterior-predictive in-sample perplexity.
    public let trainingPerplexity: Double

    init(_ value: GlifiLDAResult) {
        methodIdentifier = GlifiLDAResult.identifier
        vocabulary = value.vocabulary
        documentTopics = value.documentTopics
        topicTerms = value.topicTerms
        seed = value.seed
        trainingPerplexity = value.trainingPerplexity
    }
}

/// Application-facing document and its external variables for automated coding.
public struct GlifiStudioAutomaticCodingUnit: Encodable, Equatable, Sendable {
    /// Stable caller identity.
    public let id: String
    /// Extracted text.
    public let text: String
    /// External grouping or selection variables.
    public let variables: [String: String]

    /// Creates a coding unit without changing project data.
    public init(id: String, text: String, variables: [String: String] = [:]) {
        self.id = id
        self.text = text
        self.variables = variables
    }
}

/// Application-facing multi-label coding matrix with source evidence.
public struct GlifiStudioCodingMatrix: Equatable, Sendable {
    private let coreValue: GlifiCodingMatrix
    /// Input identities.
    public let documentIDs: [String]
    /// Code names in file order.
    public let codes: [String]
    /// Binary document-code matrix.
    public let values: [[Int]]
    /// Applied document counts per code.
    public let frequencies: [Int]
    /// UTF-8 positive evidence per document/code.
    public let evidence: [[[GlifiStudioUTF8Range]]]

    init(_ value: GlifiCodingMatrix) {
        coreValue = value
        documentIDs = value.documentIDs
        codes = value.codes
        values = value.values
        frequencies = value.frequencies
        evidence = value.evidence.map { $0.map { $0.map { GlifiStudioUTF8Range($0) } } }
    }
}

/// Application-facing prediction batch, with a frozen training vocabulary.
public struct GlifiStudioClassification: Encodable, Equatable, Sendable {
    /// Winning labels in document order.
    public let labels: [String]
    /// Class order of posterior columns.
    public let classes: [String]
    /// Model posteriors, not calibrated confidence.
    public let probabilities: [[Double]]
    /// Unknown token counts in input document order.
    public let ignoredTokenCounts: [Int]
}

/// An opaque, reusable classifier; prediction does not refit its vocabulary.
public struct GlifiStudioTextClassifier: Sendable {
    private let model: GlifiNaiveBayesModel

    init(_ model: GlifiNaiveBayesModel) { self.model = model }

    /// Scores documents outside the caller's actor and preserves cancellation.
    @concurrent public func predict(_ documents: [[String]]) async throws(GlifiStudioFailure)
        -> GlifiStudioClassification
    {
        try mapTextAnalysisFailure {
            let predictions = try GlifiNaiveBayes.predict(documents, using: model)
            return GlifiStudioClassification(
                labels: predictions.map(\.label), classes: model.classes,
                probabilities: predictions.map(\.probabilities),
                ignoredTokenCounts: predictions.map(\.ignoredTokenCount)
            )
        }
    }
}

/// Native headless operators; CPU work always leaves the caller's actor.
public enum GlifiStudioTextAnalytics {
    /// Computes classical, metric, Kruskal or Sammon MDS from explicit dissimilarities.
    @concurrent public static func multidimensionalScaling(
        _ distances: [[Double]], dimensions: Int = 2, method: GlifiStudioMDSMethod = .classical,
        seed: UInt64 = 0, maximumIterations: Int = 300
    ) async throws(GlifiStudioFailure) -> GlifiStudioMDSResult {
        try mapTextAnalysisFailure {
            try GlifiStudioMDSResult(
                GlifiExploratoryAnalysis.multidimensionalScaling(
                    distances, dimensions: dimensions, method: method.core, seed: seed,
                    maximumIterations: maximumIterations
                ))
        }
    }

    /// Fits a seeded batch self-organizing map.
    @concurrent public static func selfOrganizingMap(
        _ matrix: [[Double]], width: Int, height: Int, seed: UInt64, epochs: Int = 100
    ) async throws(GlifiStudioFailure) -> GlifiStudioSOMResult {
        try mapTextAnalysisFailure {
            try GlifiStudioSOMResult(
                GlifiExploratoryAnalysis.selfOrganizingMap(
                    matrix, width: width, height: height, seed: seed, epochs: epochs
                ))
        }
    }

    /// Fits sampled Euclidean medoids without constructing a full-data distance matrix.
    @concurrent public static func clara(
        _ matrix: [[Double]], clusterCount: Int, seed: UInt64, sampleSize: Int = 100
    ) async throws(GlifiStudioFailure) -> GlifiStudioCLARAResult {
        try mapTextAnalysisFailure {
            try GlifiStudioCLARAResult(
                GlifiExploratoryAnalysis.clara(
                    matrix, clusterCount: clusterCount, seed: seed, sampleSize: sampleSize
                ))
        }
    }

    /// Fits an immutable sparse multinomial classifier.
    @concurrent public static func trainClassifier(
        documents: [[String]], labels: [String], smoothing: Double = 1
    ) async throws(GlifiStudioFailure) -> GlifiStudioTextClassifier {
        try mapTextAnalysisFailure {
            try GlifiStudioTextClassifier(
                GlifiNaiveBayes.train(documents: documents, labels: labels, smoothing: smoothing))
        }
    }

    /// Fits Gibbs LDA with explicit priors, burn-in and posterior sample averaging.
    @concurrent public static func topics(
        documents: [[String]], topicCount: Int, seed: UInt64,
        alpha: Double = 0.1, beta: Double = 0.01,
        burnIn: Int = 100, sampleCount: Int = 20, thinning: Int = 5
    ) async throws(GlifiStudioFailure) -> GlifiStudioLDAResult {
        try mapTextAnalysisFailure {
            try GlifiStudioLDAResult(
                GlifiLatentDirichletAllocation.fit(
                    documents: documents, topicCount: topicCount, seed: seed,
                    alpha: alpha, beta: beta, burnIn: burnIn, sampleCount: sampleCount,
                    thinning: thinning
                ))
        }
    }

    /// Compiles and evaluates multi-label coding rules over immutable text units.
    @concurrent public static func code(
        _ units: [GlifiStudioAutomaticCodingUnit], rules: String
    ) async throws(GlifiStudioFailure) -> GlifiStudioCodingMatrix {
        try mapTextAnalysisFailure {
            let compiled = try GlifiCodingRuleSet(rules)
            let documents = try units.map {
                try GlifiCodingDocument(id: $0.id, text: $0.text, variables: $0.variables)
            }
            return try GlifiStudioCodingMatrix(compiled.evaluate(documents))
        }
    }
}

private func mapTextAnalysisFailure<Value>(
    _ body: () throws -> Value
) throws(GlifiStudioFailure) -> Value {
    do { return try body() } catch let failure as GlifiFailure {
        throw GlifiStudioFailure(failure)
    } catch is CancellationError {
        throw GlifiStudioFailure(
            code: "operation.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled"
        )
    } catch {
        throw GlifiStudioFailure(
            code: "analysis.failed", category: "insufficientData", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.insufficientData"
        )
    }
}

/// Shared distance choices for document, word and code matrices.
public enum GlifiStudioTextDistance: String, Codable, Sendable {
    case jaccard
    case dice
    case cosine
    case euclidean
    case manhattan

    var core: GlifiTextDistance {
        switch self {
        case .jaccard: .jaccard
        case .dice: .dice
        case .cosine: .cosine
        case .euclidean: .euclidean
        case .manhattan: .manhattan
        }
    }
}

/// Classification evaluation using training-only vocabulary in each held-out fold.
public struct GlifiStudioClassificationEvaluation: Encodable, Equatable, Sendable {
    /// Class order.
    public let classes: [String]
    /// Actual by predicted counts.
    public let confusion: [[Int]]
    /// Held-out accuracy.
    public let accuracy: Double
    /// Fold per input row.
    public let foldAssignments: [Int]

    init(_ value: GlifiClassificationEvaluation) {
        classes = value.classes
        confusion = value.confusion
        accuracy = value.accuracy
        foldAssignments = value.foldAssignments
    }
}

extension GlifiStudioTextAnalytics {
    /// Computes a shared distance matrix for words, documents or codes.
    @concurrent public static func dissimilarities(
        _ matrix: [[Double]], metric: GlifiStudioTextDistance
    ) async throws(GlifiStudioFailure) -> [[Double]] {
        try mapTextAnalysisFailure {
            try GlifiTextMatrixOperators.dissimilarities(matrix, metric: metric.core)
        }
    }

    /// Evaluates the classifier using deterministic stratified held-out folds.
    @concurrent public static func validateClassifier(
        documents: [[String]], labels: [String], folds: Int, seed: UInt64
    ) async throws(GlifiStudioFailure) -> GlifiStudioClassificationEvaluation {
        try mapTextAnalysisFailure {
            try GlifiStudioClassificationEvaluation(
                GlifiNaiveBayes.crossValidate(
                    documents: documents, labels: labels, folds: folds, seed: seed
                ))
        }
    }
}

/// Grouped code counts retain denominators and the count of missing group values.
public struct GlifiStudioCodeCrosstab: Encodable, Equatable, Sendable {
    /// Canonical group labels.
    public let groups: [String]
    /// Group by code counts.
    public let counts: [[Int]]
    /// Document denominators per group.
    public let sizes: [Int]
    /// Documents with no group value.
    public let missingCount: Int
}

extension GlifiStudioCodingMatrix {
    /// Aggregates the binary code matrix without treating missing groups as zero counts.
    public func crosstab(groups: [String?]) throws(GlifiStudioFailure) -> GlifiStudioCodeCrosstab {
        try mapTextAnalysisFailure {
            let result = try coreValue.crosstab(groups: groups)
            return GlifiStudioCodeCrosstab(
                groups: result.groups, counts: result.counts, sizes: result.sizes,
                missingCount: result.missing
            )
        }
    }
}

/// Full correspondence-analysis diagnostics for a word or code contingency matrix.
public struct GlifiStudioMatrixCorrespondence: Encodable, Equatable, Sendable {
    /// Versioned method.
    public let methodIdentifier: String
    /// Included input row indexes, excluding zero mass.
    public let includedRows: [Int]
    /// Included input column indexes.
    public let includedColumns: [Int]
    /// Row masses.
    public let rowMasses: [Double]
    /// Column masses.
    public let columnMasses: [Double]
    /// Principal inertias.
    public let inertias: [Double]
    /// Total inertia, including axes not displayed.
    public let totalInertia: Double
    /// Row principal coordinates.
    public let rowCoordinates: [[Double]]
    /// Column principal coordinates.
    public let columnCoordinates: [[Double]]
    /// Row contributions.
    public let rowContributions: [[Double]]
    /// Column contributions.
    public let columnContributions: [[Double]]
    /// Row representation quality.
    public let rowCosines: [[Double]]
    /// Column representation quality.
    public let columnCosines: [[Double]]

    init(_ value: GlifiCorrespondenceResult) {
        methodIdentifier = GlifiCorrespondenceResult.identifier
        includedRows = value.includedRows
        includedColumns = value.includedColumns
        rowMasses = value.rowMasses
        columnMasses = value.columnMasses
        inertias = value.inertias
        totalInertia = value.totalInertia
        rowCoordinates = value.rowCoordinates
        columnCoordinates = value.columnCoordinates
        rowContributions = value.rowContributions
        columnContributions = value.columnContributions
        rowCosines = value.rowCosines
        columnCosines = value.columnCosines
    }
}

/// A clustering tree with merge identities using the same convention as the engine.
public struct GlifiStudioMatrixClustering: Encodable, Equatable, Sendable {
    /// Linkage used.
    public let linkage: String
    /// Child identities, two per merge; original rows are 0..<n, merges n+step.
    public let children: [[Int]]
    /// Merge dissimilarities.
    public let heights: [Double]
    /// Cluster sizes after every merge.
    public let sizes: [Int]
}

/// Undirected matrix network, listing each edge exactly once.
public struct GlifiStudioMatrixNetwork: Encodable, Equatable, Sendable {
    /// Node order.
    public let nodes: [String]
    /// Node index pair per undirected edge.
    public let endpoints: [[Int]]
    /// Jaccard weight per edge.
    public let weights: [Double]
}

extension GlifiStudioTextAnalytics {
    /// Conservative fallback for methods without a reviewed identifier.
    public static let validationStatus = "candidate"

    /// Uses the existing CA engine for a word or code table and retains all its diagnostics.
    @concurrent public static func correspondenceAnalysis(
        _ matrix: [[Double]]
    ) async throws(GlifiStudioFailure) -> GlifiStudioMatrixCorrespondence {
        try mapTextAnalysisFailure {
            _ = try validateExploratoryMatrix(matrix, limits: .standard)
            return try GlifiStudioMatrixCorrespondence(
                GlifiMultivariateMethods.correspondenceAnalysis(matrix))
        }
    }

    /// Clusters a dissimilarity matrix; Ward remains an operation over Euclidean vectors.
    @concurrent public static func hierarchicalClustering(
        dissimilarities: [[Double]], linkage: String
    ) async throws(GlifiStudioFailure) -> GlifiStudioMatrixClustering {
        try mapTextAnalysisFailure {
            guard let parsed = GlifiLinkage(rawValue: linkage) else {
                throw exploratoryFailure("hac.invalid-linkage")
            }
            let tree = try GlifiTextMatrixOperators.hierarchicalClustering(
                dissimilarities: dissimilarities, linkage: parsed)
            return GlifiStudioMatrixClustering(
                linkage: linkage, children: tree.merges.map { [$0.first, $0.second] },
                heights: tree.merges.map(\.height), sizes: tree.merges.map(\.size)
            )
        }
    }

    /// Computes the Jaccard network of columns of a document-word or document-code matrix.
    @concurrent public static func cooccurrenceNetwork(
        _ matrix: [[Double]], labels: [String], minimumJaccard: Double = 0.1,
        maximumEdges: Int = 10_000
    ) async throws(GlifiStudioFailure) -> GlifiStudioMatrixNetwork {
        try mapTextAnalysisFailure {
            let graph = try GlifiTextMatrixOperators.cooccurrenceNetwork(
                matrix, labels: labels, minimumJaccard: minimumJaccard, maximumEdges: maximumEdges
            )
            let positions = Dictionary(
                uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) })
            let edges = graph.edges.filter {
                (positions[$0.source] ?? 0) < (positions[$0.target] ?? 0)
            }
            return GlifiStudioMatrixNetwork(
                nodes: graph.nodes,
                endpoints: edges.map { [positions[$0.source] ?? 0, positions[$0.target] ?? 0] },
                weights: edges.map(\.weight)
            )
        }
    }
}

extension GlifiStudioTextAnalytics {
    /// Returns the method-scoped validation status recorded by the executable manifests.
    public static func validationStatus(forMethod identifier: String) -> String {
        switch identifier {
        case "MDS-classical-LAPACK-v1", "MDS-metric-SMACOF-v1",
            "MDS-nonmetric-secondary-ties-Stress1-v2", "MDS-Sammon-v1",
            "SOM-batch-gaussian-rectangular-v1", "CLARA-PAM-Euclidean-v1",
            "MultinomialNaiveBayes-Laplace-v1", "LDA-collapsed-Gibbs-predictive-mean-v2",
            "KH-coding-compatible-v2":
            "supported"
        default:
            "candidate"
        }
    }
}

extension GlifiStudioCodingMatrix: Encodable {
    /// Encodes public matrix data without the engine's private representation.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: TextAnalysisKey.self)
        try fields.encode(documentIDs, forKey: TextAnalysisKey("documentIDs"))
        try fields.encode(codes, forKey: TextAnalysisKey("codes"))
        try fields.encode(values, forKey: TextAnalysisKey("values"))
        try fields.encode(frequencies, forKey: TextAnalysisKey("frequencies"))
        try fields.encode(evidence, forKey: TextAnalysisKey("evidence"))
    }
}
