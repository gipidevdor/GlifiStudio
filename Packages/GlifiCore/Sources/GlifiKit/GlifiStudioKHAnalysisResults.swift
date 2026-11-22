// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Caller identities and conditional context means in their original order.
public struct GlifiStudioKHWordContextResult: Encodable, Sendable {
    private let value: GlifiKHWordContextResult
    /// Caller target identities in output row order.
    public var targetIDs: [String] { value.targetIDs }
    /// Caller context-word identities in output column order.
    public var contextIDs: [String] { value.contextIDs }
    /// Levels by targets: number of units with a positive target count at each level.
    public var supportCounts: [[Int]] { value.supportCounts }
    /// Targets by context words: weighted conditional means, with unsupported contributions zero.
    public var values: [[Double]] { value.values }
    /// Selected aggregation levels in the accumulation order retained by the Core result.
    public var levels: [GlifiStudioKHContextLevel] {
        value.levelWeights.map { khContextLevel($0.level) }
    }
    /// Resolved alpha coefficients aligned with levels, including explicit zero or negative weights.
    public var weights: [Double] { value.levelWeights.map(\.alpha) }
    init(_ value: GlifiKHWordContextResult) { self.value = value }
    /// Encodes the original conditional means, identities, levelWeights and support metadata without a wrapper.
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Scaled CA coordinates and the masses and singular values defining their metric.
public struct GlifiStudioKHCorrespondenceResult: Encodable, Sendable {
    private let value: GlifiKHCorrespondenceCoordinates
    /// Versioned identity of the CA decomposition whose axes were reused.
    public var sourceMethodIdentifier: String { value.sourceMethodIdentifier }
    /// Declared row coordinate exponent: principal, standard or square-root symmetric biplot.
    public var rowScaling: GlifiStudioKHCorrespondenceScaling { khScaling(value.rowScaling) }
    /// Declared column coordinate exponent, independently selected from rowScaling.
    public var columnScaling: GlifiStudioKHCorrespondenceScaling { khScaling(value.columnScaling) }
    /// Original input row indices retained after zero-mass exclusion.
    public var includedRows: [Int] { value.includedRows }
    /// Original input column indices retained after zero-mass exclusion.
    public var includedColumns: [Int] { value.includedColumns }
    /// Unchanged row probability masses aligned with includedRows.
    public var rowMasses: [Double] { value.rowMasses }
    /// Unchanged column probability masses aligned with includedColumns.
    public var columnMasses: [Double] { value.columnMasses }
    /// Unchanged positive singular values indexing every returned coordinate axis.
    public var singularValues: [Double] { value.singularValues }
    /// Included rows by retained axes, scaled according to rowScaling.
    public var rowCoordinates: [[Double]] { value.rowCoordinates }
    /// Included columns by retained axes, scaled according to columnScaling.
    public var columnCoordinates: [[Double]] { value.columnCoordinates }
    init(_ value: GlifiKHCorrespondenceCoordinates) { self.value = value }
    /// Encodes the original coordinate projection and metric metadata without adding a transport wrapper.
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Both training phases and their continuity, including initialization and final diagnostics.
public struct GlifiStudioKHSOMResult: Encodable, Sendable {
    /// Versioned online two-phase SOM profile, including its grid topology.
    public let methodIdentifier: String
    /// Versioned PCA-linear or explicit-codebook initialization policy.
    public let initializationIdentifier: String
    /// Non-toroidal rectangular or odd-row hexagonal grid geometry.
    public let topology: GlifiStudioSOMTopology
    /// Number of grid columns in row-major codebook order.
    public let width: Int
    /// Number of grid rows in row-major codebook order.
    public let height: Int
    /// Resolved schedule of the initial continuous training phase.
    public let firstPhase: GlifiStudioKHSOMPhase
    /// Resolved schedule that continues the same internal codebooks after phase one.
    public let secondPhase: GlifiStudioKHSOMPhase
    /// Grid units by input features before training, in original data units.
    public let initialCodebooks: [[Double]]
    /// First-phase output in original data units, before second-phase updates.
    public let firstPhaseCodebooks: [[Double]]
    /// Final grid units by input features, in original data units and row-major order.
    public let prototypes: [[Double]]
    /// Zero-based first minimum-distance grid unit for each input observation.
    public let assignments: [Int]
    /// Mean Euclidean distance to the winning unit, in original data units.
    public let quantizationError: Double
    /// Mean Gaussian-weighted squared distance to all units at diagnostic radius one.
    public let neighborhoodDistortion: Double
    /// Fraction of observations whose two best matching units are not immediate neighbors.
    public let topographicError: Double
    /// Completed observation updates summed over both declared phase schedules.
    public let completedSteps: Int
    /// Median neighbor codebook distances in data units, one value per row-major grid unit.
    public let uMatrix: [Double]
    /// Optional Ward hierarchy and cut of the final codebooks, absent unless requested.
    public let codebookClustering: GlifiStudioSOMCodebookClustering?
    init(_ value: GlifiKHSOMResult) {
        methodIdentifier = value.methodIdentifier
        initializationIdentifier = value.initializationIdentifier
        topology = value.topology == .hexagonal ? .hexagonal : .rectangular
        width = value.width
        height = value.height
        firstPhase = .init(
            steps: value.firstPhase.steps,
            initialLearningRate: value.firstPhase.initialLearningRate,
            initialRadius: value.firstPhase.initialRadius)
        secondPhase = .init(
            steps: value.secondPhase.steps,
            initialLearningRate: value.secondPhase.initialLearningRate,
            initialRadius: value.secondPhase.initialRadius)
        initialCodebooks = value.initialCodebooks
        firstPhaseCodebooks = value.firstPhaseCodebooks
        prototypes = value.prototypes
        assignments = value.assignments
        quantizationError = value.quantizationError
        neighborhoodDistortion = value.neighborhoodDistortion
        topographicError = value.topographicError
        completedSteps = value.completedSteps
        uMatrix = value.uMatrix
        codebookClustering = value.codebookClustering.map(GlifiStudioSOMCodebookClustering.init)
    }
}

/// The two independent KH score definitions; undefined values are omitted rather than fabricated.
public struct GlifiStudioKHCollocationScores: Encodable, Sendable {
    /// Versioned base-two MI3 definition using complete corpus token exposure.
    public let mi3MethodIdentifier = GlifiKHCollocationScores.mi3Identifier
    /// Versioned Z definition using background exposure N-F1 and the declared window span.
    public let zMethodIdentifier = GlifiKHCollocationScores.zIdentifier
    /// Log2(a cubed times N divided by F1F2), omitted when no pair is observed.
    public let mi3: Double?
    /// Binomially standardized window residual, omitted for zero background or variance.
    public let zScore: Double?
    /// Window expectation E used by Z, omitted when background exposure is zero.
    public let expectedWindowCount: Double?
    init(_ value: GlifiKHCollocationScores) {
        mi3 = value.mi3
        zScore = value.zScore
        expectedWindowCount = value.expectedWindowCount
    }
}

/// Compound ranking retains component segmentation and the independent frequency convention.
public struct GlifiStudioTermScore: Encodable, Sendable {
    /// Ordered lexical component keys of the scored candidate.
    public let components: [String]
    /// Aggregated independent candidate frequency, excluding occurrences nested in larger candidates.
    public let frequency: Int
    /// Geometric mean of the add-one smoothed left and right component adjacency counts.
    public let lr: Double
    /// Independent candidate frequency multiplied by LR.
    public let flr: Double
    init(_ value: GlifiTermScore) {
        components = value.components
        frequency = value.frequency
        lr = value.lr
        flr = value.flr
    }
}

/// The observed component adjacency counts before smoothing.
public struct GlifiStudioTermComponentStatistics: Encodable, Sendable {
    /// Caller lexical key whose internal compound adjacencies were counted.
    public let component: String
    /// Frequency-weighted adjacency occurrences immediately to the left, before smoothing.
    public let leftFrequency: Int
    /// Frequency-weighted adjacency occurrences immediately to the right, before smoothing.
    public let rightFrequency: Int
    /// Distinct lexical neighbor keys immediately to the left, before smoothing.
    public let leftTypeCount: Int
    /// Distinct lexical neighbor keys immediately to the right, before smoothing.
    public let rightTypeCount: Int
    init(_ value: GlifiTermComponentStatistics) {
        component = value.component
        leftFrequency = value.leftFrequency
        rightFrequency = value.rightFrequency
        leftTypeCount = value.leftTypeCount
        rightTypeCount = value.rightTypeCount
    }
}

/// Mathematical LR/FLR scores with the caller-declared candidate-formation provenance.
public struct GlifiStudioTermExtractionScores: Encodable, Sendable {
    /// Whether LR uses repeated adjacency occurrences or distinct neighbor keys.
    public let adjacencyMode: GlifiStudioTermAdjacencyMode
    /// Caller provenance of candidate segmentation and lexical normalization.
    public let preprocessingIdentifier: String
    /// Checked total of independent candidate occurrences contributing to the observations.
    public let independentOccurrenceCount: Int
    /// Ranked candidates in decreasing FLR order, with lexicographic component ties.
    public let terms: [GlifiStudioTermScore]
    /// Unsmoothed adjacency observations in lexicographic component order.
    public let components: [GlifiStudioTermComponentStatistics]
    init(_ value: GlifiTermExtractionScores) {
        adjacencyMode = value.adjacencyMode == .token ? .token : .type
        preprocessingIdentifier = value.preprocessingIdentifier
        independentOccurrenceCount = value.independentOccurrenceCount
        terms = value.terms.map(GlifiStudioTermScore.init)
        components = value.components.map(GlifiStudioTermComponentStatistics.init)
    }
}

/// One independent source occurrence; coordinates are half-open in both spaces.
public struct GlifiStudioTermOccurrence: Encodable, Sendable {
    /// Original caller identity of the source document.
    public let documentID: String
    /// Original candidate component keys in source order.
    public let components: [String]
    /// Inclusive index into the caller-supplied token sequence.
    public let tokenStart: Int
    /// Exclusive index into the caller-supplied token sequence.
    public let tokenEnd: Int
    /// Inclusive source byte offset of the complete occurrence.
    public let startUTF8: Int
    /// Exclusive source byte offset, retaining whitespace inside the compound.
    public let endUTF8: Int
    init(_ value: GlifiTermOccurrence) {
        documentID = value.documentID
        components = value.components
        tokenStart = value.tokenRange.lowerBound
        tokenEnd = value.tokenRange.upperBound
        startUTF8 = value.range.start
        endUTF8 = value.range.end
    }
}

/// Exact annotated-source evidence together with the scoring observations.
public struct GlifiStudioTermExtractionResult: Encodable, Sendable {
    /// Complete explicit candidate-formation rule applied to the supplied annotations.
    public let rule: GlifiStudioTermExtractionRule
    /// Input document identities in original order, including documents with no occurrences.
    public let documentIDs: [String]
    /// Annotation provenance aligned with documentIDs.
    public let linguisticContracts: [String]
    /// Independent source occurrences in document and token order.
    public let occurrences: [GlifiStudioTermOccurrence]
    /// Ranked LR/FLR scores and the underlying independent adjacency observations.
    public let scores: GlifiStudioTermExtractionScores
    init(_ value: GlifiTermExtractionResult) {
        rule = .init(
            identifier: value.rule.identifier,
            allowedPartsOfSpeech: value.rule.allowedPartsOfSpeech.sorted(),
            ignoredKeys: value.rule.ignoredKeys.sorted(),
            minimumComponents: value.rule.minimumComponents,
            maximumComponents: value.rule.maximumComponents)
        documentIDs = value.documentIDs
        linguisticContracts = value.linguisticContracts
        occurrences = value.occurrences.map(GlifiStudioTermOccurrence.init)
        scores = GlifiStudioTermExtractionScores(value.scores)
    }
}

/// Inspectable multinomial scores, separate from the sufficient statistics used to update them.
public struct GlifiStudioNaiveBayesModel: Encodable, Sendable {
    /// Canonical class order indexing priors, likelihood rows and prediction probabilities.
    public let classes: [String]
    /// Frozen training vocabulary indexing every conditional-likelihood column.
    public let vocabulary: [String]
    /// Natural logarithm of the empirical training-document prior for each class.
    public let logPriors: [Double]
    /// Class by term natural-log probabilities with the declared symmetric smoothing.
    public let logLikelihoods: [[Double]]
    /// Positive symmetric pseudocount used to convert counts into conditional probabilities.
    public let smoothing: Double
    init(_ value: GlifiNaiveBayesModel) {
        classes = value.classes
        vocabulary = value.vocabulary
        logPriors = value.logPriors
        logLikelihoods = value.logLikelihoods
        smoothing = value.smoothing
    }
}

/// A one-class initial state can be returned and continued before it is ready for prediction.
public struct GlifiStudioIncrementalClassifierResult: Encodable, Sendable {
    /// Exact sufficient statistics that can be supplied to a subsequent continuation request.
    public let state: GlifiStudioNaiveBayesTrainingState
    /// Fitted multinomial scores, absent while only one class has been observed.
    public let model: GlifiStudioNaiveBayesModel?
    /// Scores for requested documents, absent for a one-class state that cannot yet predict.
    public let predictions: GlifiStudioClassification?
}

/// Held-out predictions, full confusion matrix, accuracy and nominal kappa on the same units.
public struct GlifiStudioClassifierAgreementEvaluation: Encodable, Sendable {
    /// Held-out confusion matrix, class order, fold assignments and accuracy from the same predictions.
    public let evaluation: GlifiStudioClassificationEvaluation
    /// Held-out class prediction for every input document in original order.
    public let predictions: [String]
    /// Nominal Cohen kappa computed from the actual and held-out predicted labels.
    public let kappa: Double
    /// Fraction of input documents whose held-out predicted class matches the actual class.
    public let observedAgreement: Double
    /// Sum of products of actual and predicted class proportions on those same documents.
    public let expectedAgreement: Double
    /// Explicit seed used by the stratified fold shuffle.
    public let seed: UInt64
    init(_ value: GlifiNaiveBayesAgreementEvaluation) {
        evaluation = .init(value.evaluation)
        predictions = value.evaluation.predictions
        kappa = value.agreement.kappa
        observedAgreement = value.agreement.observedAgreement
        expectedAgreement = value.agreement.expectedAgreement
        seed = value.evaluation.seed
    }
}

/// Typed native payloads; encoding writes exactly the same fields to the CLI result.
public enum GlifiStudioKHAnalysisPayload: Encodable, Sendable {
    case matrix([[Double]])
    case wordContext(GlifiStudioKHWordContextResult)
    case correspondence(GlifiStudioKHCorrespondenceResult)
    case mds(GlifiStudioMDSResult)
    case mdsSearch(GlifiStudioMDSSearchResult)
    case som(GlifiStudioKHSOMResult)
    case collocation(GlifiStudioKHCollocationScores)
    case termScores(GlifiStudioTermExtractionScores)
    case termExtraction(GlifiStudioTermExtractionResult)
    case incrementalClassifier(GlifiStudioIncrementalClassifierResult)
    case classifierAgreement(GlifiStudioClassifierAgreementEvaluation)
    /// Encodes only the selected result fields, without an additional enum-case or payload wrapper.
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .matrix(value): try value.encode(to: encoder)
        case let .wordContext(value): try value.encode(to: encoder)
        case let .correspondence(value): try value.encode(to: encoder)
        case let .mds(value): try value.encode(to: encoder)
        case let .mdsSearch(value): try value.encode(to: encoder)
        case let .som(value): try value.encode(to: encoder)
        case let .collocation(value): try value.encode(to: encoder)
        case let .termScores(value): try value.encode(to: encoder)
        case let .termExtraction(value): try value.encode(to: encoder)
        case let .incrementalClassifier(value): try value.encode(to: encoder)
        case let .classifierAgreement(value): try value.encode(to: encoder)
        }
    }
}

private func khScaling(_ value: GlifiKHCorrespondenceScaling) -> GlifiStudioKHCorrespondenceScaling
{
    switch value {
    case .principal: .principal
    case .standard: .standard
    case .symmetric: .symmetric
    }
}

private func khContextLevel(_ value: GlifiKHContextLevel) -> GlifiStudioKHContextLevel {
    switch value {
    case .sentence: .sentence
    case .paragraph: .paragraph
    case .h5: .h5
    case .h4: .h4
    case .h3: .h3
    case .h2: .h2
    case .h1: .h1
    }
}
