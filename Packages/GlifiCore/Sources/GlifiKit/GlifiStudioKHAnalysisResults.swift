// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Caller identities and conditional context means in their original order.
public struct GlifiStudioKHWordContextResult: Encodable, Sendable {
    private let value: GlifiKHWordContextResult
    public var targetIDs: [String] { value.targetIDs }
    public var contextIDs: [String] { value.contextIDs }
    public var supportCounts: [[Int]] { value.supportCounts }
    public var values: [[Double]] { value.values }
    public var levels: [GlifiStudioKHContextLevel] {
        value.levelWeights.map { khContextLevel($0.level) }
    }
    public var weights: [Double] { value.levelWeights.map(\.alpha) }
    init(_ value: GlifiKHWordContextResult) { self.value = value }
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Scaled CA coordinates and the masses and singular values defining their metric.
public struct GlifiStudioKHCorrespondenceResult: Encodable, Sendable {
    private let value: GlifiKHCorrespondenceCoordinates
    public var sourceMethodIdentifier: String { value.sourceMethodIdentifier }
    public var rowScaling: GlifiStudioKHCorrespondenceScaling { khScaling(value.rowScaling) }
    public var columnScaling: GlifiStudioKHCorrespondenceScaling { khScaling(value.columnScaling) }
    public var includedRows: [Int] { value.includedRows }
    public var includedColumns: [Int] { value.includedColumns }
    public var rowMasses: [Double] { value.rowMasses }
    public var columnMasses: [Double] { value.columnMasses }
    public var singularValues: [Double] { value.singularValues }
    public var rowCoordinates: [[Double]] { value.rowCoordinates }
    public var columnCoordinates: [[Double]] { value.columnCoordinates }
    init(_ value: GlifiKHCorrespondenceCoordinates) { self.value = value }
    public func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Both training phases and their continuity, including initialization and final diagnostics.
public struct GlifiStudioKHSOMResult: Encodable, Sendable {
    public let methodIdentifier: String
    public let initializationIdentifier: String
    public let topology: GlifiStudioSOMTopology
    public let width: Int
    public let height: Int
    public let firstPhase: GlifiStudioKHSOMPhase
    public let secondPhase: GlifiStudioKHSOMPhase
    public let initialCodebooks: [[Double]]
    public let firstPhaseCodebooks: [[Double]]
    public let prototypes: [[Double]]
    public let assignments: [Int]
    public let quantizationError: Double
    public let neighborhoodDistortion: Double
    public let topographicError: Double
    public let completedSteps: Int
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
    }
}

/// The two independent KH score definitions; undefined values are omitted rather than fabricated.
public struct GlifiStudioKHCollocationScores: Encodable, Sendable {
    public let mi3MethodIdentifier = GlifiKHCollocationScores.mi3Identifier
    public let zMethodIdentifier = GlifiKHCollocationScores.zIdentifier
    public let mi3: Double?
    public let zScore: Double?
    public let expectedWindowCount: Double?
    init(_ value: GlifiKHCollocationScores) {
        mi3 = value.mi3
        zScore = value.zScore
        expectedWindowCount = value.expectedWindowCount
    }
}

/// Compound ranking retains component segmentation and the independent frequency convention.
public struct GlifiStudioTermScore: Encodable, Sendable {
    public let components: [String]
    public let frequency: Int
    public let lr: Double
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
    public let component: String
    public let leftFrequency: Int
    public let rightFrequency: Int
    public let leftTypeCount: Int
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
    public let adjacencyMode: GlifiStudioTermAdjacencyMode
    public let preprocessingIdentifier: String
    public let independentOccurrenceCount: Int
    public let terms: [GlifiStudioTermScore]
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
    public let documentID: String
    public let components: [String]
    public let tokenStart: Int
    public let tokenEnd: Int
    public let startUTF8: Int
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
    public let rule: GlifiStudioTermExtractionRule
    public let documentIDs: [String]
    public let linguisticContracts: [String]
    public let occurrences: [GlifiStudioTermOccurrence]
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
    public let classes: [String]
    public let vocabulary: [String]
    public let logPriors: [Double]
    public let logLikelihoods: [[Double]]
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
    public let state: GlifiStudioNaiveBayesTrainingState
    public let model: GlifiStudioNaiveBayesModel?
    public let predictions: GlifiStudioClassification?
}

/// Held-out predictions, full confusion matrix, accuracy and nominal kappa on the same units.
public struct GlifiStudioClassifierAgreementEvaluation: Encodable, Sendable {
    public let evaluation: GlifiStudioClassificationEvaluation
    public let predictions: [String]
    public let kappa: Double
    public let observedAgreement: Double
    public let expectedAgreement: Double
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
