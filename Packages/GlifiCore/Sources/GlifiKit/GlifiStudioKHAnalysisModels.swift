// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Independent vectors standardized by the preparation operator.
public enum GlifiStudioKHMatrixAxis: String, Codable, Sendable { case rows, columns }
/// Explicit treatment of zero sample variance.
public enum GlifiStudioKHConstantPolicy: String, Codable, Sendable { case reject, zeros }
/// Explicit treatment of zero external row exposure.
public enum GlifiStudioKHZeroExposurePolicy: String, Codable, Sendable { case reject, zeros }
/// Caller-declared aggregation levels; the engine never guesses document boundaries.
public enum GlifiStudioKHContextLevel: String, Codable, Sendable {
    case sentence, paragraph, h5, h4, h3, h2, h1
}
/// Exponent of the CA singular values used by the projection.
public enum GlifiStudioKHCorrespondenceScaling: String, Codable, Sendable {
    case principal, standard, symmetric
}
/// Primary permits different fitted disparities within an observed tie block.
public enum GlifiStudioMDSOrdinalTies: String, Codable, Sendable { case primary, secondary }
/// Whether LR counts adjacency occurrences or distinct neighbors.
public enum GlifiStudioTermAdjacencyMode: String, Codable, Sendable { case token, type }

/// Aligned target/context counts within one declared aggregation level.
public struct GlifiStudioKHContextCounts: Codable, Equatable, Sendable {
    public let level: GlifiStudioKHContextLevel
    public let alpha: Double
    public let targetCounts: [[Double]]
    public let contextCounts: [[Double]]
    public init(
        level: GlifiStudioKHContextLevel, alpha: Double = 1,
        targetCounts: [[Double]], contextCounts: [[Double]]
    ) {
        self.level = level
        self.alpha = alpha
        self.targetCounts = targetCounts
        self.contextCounts = contextCounts
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(decoder, allowed: ["level", "alpha", "targetCounts", "contextCounts"])
        self.init(
            level: try f.khRequired("level"), alpha: try f.khDefault("alpha", 1),
            targetCounts: try f.khRequired("targetCounts"),
            contextCounts: try f.khRequired("contextCounts"))
    }
}

/// One continuous online SOM phase; these are observation updates, not epochs.
public struct GlifiStudioKHSOMPhase: Codable, Equatable, Sendable {
    public let steps: Int
    public let initialLearningRate: Double
    public let initialRadius: Double
    public init(steps: Int, initialLearningRate: Double, initialRadius: Double) {
        self.steps = steps
        self.initialLearningRate = initialLearningRate
        self.initialRadius = initialRadius
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(decoder, allowed: ["steps", "initialLearningRate", "initialRadius"])
        self.init(
            steps: try f.khRequired("steps"),
            initialLearningRate: try f.khRequired("initialLearningRate"),
            initialRadius: try f.khRequired("initialRadius"))
    }
    var core: GlifiKHSOMPhase {
        GlifiKHSOMPhase(
            steps: steps, initialLearningRate: initialLearningRate, initialRadius: initialRadius)
    }
}

/// Global token counts and window observations; the universe differs from a 2×2 window table.
public struct GlifiStudioKHCollocationInput: Codable, Equatable, Sendable {
    public let jointCount: Int
    public let nodeFrequency: Int
    public let collocateFrequency: Int
    public let corpusTokenCount: Int
    public let windowSpan: Int
    public init(
        jointCount: Int, nodeFrequency: Int, collocateFrequency: Int,
        corpusTokenCount: Int, windowSpan: Int
    ) {
        self.jointCount = jointCount
        self.nodeFrequency = nodeFrequency
        self.collocateFrequency = collocateFrequency
        self.corpusTokenCount = corpusTokenCount
        self.windowSpan = windowSpan
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(
            decoder,
            allowed: [
                "jointCount", "nodeFrequency", "collocateFrequency", "corpusTokenCount",
                "windowSpan",
            ])
        self.init(
            jointCount: try f.khRequired("jointCount"),
            nodeFrequency: try f.khRequired("nodeFrequency"),
            collocateFrequency: try f.khRequired("collocateFrequency"),
            corpusTokenCount: try f.khRequired("corpusTokenCount"),
            windowSpan: try f.khRequired("windowSpan"))
    }
    func core() throws -> GlifiKHCollocationInput {
        try GlifiKHCollocationInput(
            jointCount: jointCount, nodeFrequency: nodeFrequency,
            collocateFrequency: collocateFrequency,
            corpusTokenCount: corpusTokenCount, windowSpan: windowSpan)
    }
}

/// An independently observed compound; nested occurrences must not be counted twice.
public struct GlifiStudioTermCandidate: Codable, Equatable, Sendable {
    public let components: [String]
    public let frequency: Int
    public init(components: [String], frequency: Int) {
        self.components = components
        self.frequency = frequency
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(decoder, allowed: ["components", "frequency"])
        self.init(
            components: try f.khRequired("components"), frequency: try f.khRequired("frequency"))
    }
}

/// A caller-annotated lexical token, retaining exact UTF-8 source coordinates.
public struct GlifiStudioTermToken: Codable, Equatable, Sendable {
    public let surface: String
    public let base: String
    public let partOfSpeech: String?
    public let startUTF8: Int
    public let endUTF8: Int
    public let sentence: Int
    public let paragraph: Int
    public init(
        surface: String, base: String, partOfSpeech: String? = nil,
        startUTF8: Int, endUTF8: Int, sentence: Int = 0, paragraph: Int = 0
    ) {
        self.surface = surface
        self.base = base
        self.partOfSpeech = partOfSpeech
        self.startUTF8 = startUTF8
        self.endUTF8 = endUTF8
        self.sentence = sentence
        self.paragraph = paragraph
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(
            decoder,
            allowed: [
                "surface", "base", "partOfSpeech", "startUTF8", "endUTF8", "sentence", "paragraph",
            ])
        self.init(
            surface: try f.khRequired("surface"), base: try f.khRequired("base"),
            partOfSpeech: try f.khOptional("partOfSpeech"),
            startUTF8: try f.khRequired("startUTF8"), endUTF8: try f.khRequired("endUTF8"),
            sentence: try f.khDefault("sentence", 0), paragraph: try f.khDefault("paragraph", 0))
    }
    func core() throws -> GlifiCodingToken {
        try GlifiCodingToken(
            surface: surface, base: base, partOfSpeech: partOfSpeech,
            range: GlifiUTF8Range(start: startUTF8, end: endUTF8), sentence: sentence,
            paragraph: paragraph)
    }
}

/// A preannotated document; no tokenizer or language model is silently selected.
public struct GlifiStudioTermDocument: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let tokens: [GlifiStudioTermToken]
    public let linguisticContract: String
    public init(
        id: String, text: String, tokens: [GlifiStudioTermToken], linguisticContract: String
    ) {
        self.id = id
        self.text = text
        self.tokens = tokens
        self.linguisticContract = linguisticContract
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(decoder, allowed: ["id", "text", "tokens", "linguisticContract"])
        self.init(
            id: try f.khRequired("id"), text: try f.khRequired("text"),
            tokens: try f.khRequired("tokens"),
            linguisticContract: try f.khRequired("linguisticContract"))
    }
    func core() throws -> GlifiCodingDocument {
        try GlifiCodingDocument(
            id: id, text: text, tokens: tokens.map { try $0.core() },
            linguisticContract: linguisticContract)
    }
}

/// Explicit POS runs and exclusion keys used to form independent compounds.
public struct GlifiStudioTermExtractionRule: Codable, Equatable, Sendable {
    public let identifier: String
    public let allowedPartsOfSpeech: [String]
    public let ignoredKeys: [String]
    public let minimumComponents: Int
    public let maximumComponents: Int
    public init(
        identifier: String, allowedPartsOfSpeech: [String], ignoredKeys: [String] = [],
        minimumComponents: Int = 2, maximumComponents: Int = 64
    ) {
        self.identifier = identifier
        self.allowedPartsOfSpeech = allowedPartsOfSpeech
        self.ignoredKeys = ignoredKeys
        self.minimumComponents = minimumComponents
        self.maximumComponents = maximumComponents
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(
            decoder,
            allowed: [
                "identifier", "allowedPartsOfSpeech", "ignoredKeys", "minimumComponents",
                "maximumComponents",
            ])
        self.init(
            identifier: try f.khRequired("identifier"),
            allowedPartsOfSpeech: try f.khRequired("allowedPartsOfSpeech"),
            ignoredKeys: try f.khDefault("ignoredKeys", []),
            minimumComponents: try f.khDefault("minimumComponents", 2),
            maximumComponents: try f.khDefault("maximumComponents", 64))
    }
    func core() throws -> GlifiTermExtractionRule {
        try GlifiTermExtractionRule(
            identifier: identifier, allowedPartsOfSpeech: Set(allowedPartsOfSpeech),
            ignoredKeys: Set(ignoredKeys), minimumComponents: minimumComponents,
            maximumComponents: maximumComponents)
    }
}

/// Serializable transient sufficient statistics; this does not change the project format.
public struct GlifiStudioNaiveBayesTrainingState: Codable, Equatable, Sendable {
    public let classes: [String]
    public let vocabulary: [String]
    public let documentCounts: [Int]
    public let tokenCounts: [[Int]]
    public let smoothing: Double
    public init(
        classes: [String], vocabulary: [String], documentCounts: [Int],
        tokenCounts: [[Int]], smoothing: Double = 1
    ) {
        self.classes = classes
        self.vocabulary = vocabulary
        self.documentCounts = documentCounts
        self.tokenCounts = tokenCounts
        self.smoothing = smoothing
    }
    public init(from decoder: any Decoder) throws {
        let f = try khFields(
            decoder,
            allowed: ["classes", "vocabulary", "documentCounts", "tokenCounts", "smoothing"])
        self.init(
            classes: try f.khRequired("classes"), vocabulary: try f.khRequired("vocabulary"),
            documentCounts: try f.khRequired("documentCounts"),
            tokenCounts: try f.khRequired("tokenCounts"),
            smoothing: try f.khDefault("smoothing", 1))
    }
    init(_ state: GlifiNaiveBayesTrainingState) {
        self.init(
            classes: state.classes, vocabulary: state.vocabulary,
            documentCounts: state.documentCounts,
            tokenCounts: state.tokenCounts, smoothing: state.smoothing)
    }
    func core() throws -> GlifiNaiveBayesTrainingState {
        try GlifiNaiveBayesTrainingState(
            classes: classes, vocabulary: vocabulary, documentCounts: documentCounts,
            tokenCounts: tokenCounts, smoothing: smoothing)
    }
}

func khFields(
    _ decoder: any Decoder, allowed: Set<String>
) throws -> KeyedDecodingContainer<TextAnalysisKey> {
    let fields = try decoder.container(keyedBy: TextAnalysisKey.self)
    guard fields.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw textRequestFailure("text-analysis.unknown-field")
    }
    return fields
}

extension KeyedDecodingContainer where Key == TextAnalysisKey {
    func khRequired<T: Decodable>(_ name: String) throws -> T {
        try decode(T.self, forKey: TextAnalysisKey(name))
    }
    func khDefault<T: Decodable>(_ name: String, _ fallback: T) throws -> T {
        contains(TextAnalysisKey(name)) ? try khRequired(name) : fallback
    }
    func khOptional<T: Decodable>(_ name: String) throws -> T? {
        contains(TextAnalysisKey(name)) ? try decode(T.self, forKey: TextAnalysisKey(name)) : nil
    }
}
