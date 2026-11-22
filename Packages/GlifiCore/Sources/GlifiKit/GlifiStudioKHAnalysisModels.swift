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

/// KH document retrieval weights use base-ten IDF and the declared zero-IDF divisor convention.
public enum GlifiStudioKHDocumentScoreMode: String, Codable, Sendable {
    case tf, tfIdf, tfDividedByIdf
}

/// Automatic correction applies Yates only to a 2×2 table; none always requests Pearson.
public enum GlifiStudioKHChiSquareCorrection: String, Codable, Sendable {
    case automatic, none, yates
}

/// Undefined statistics retain their table dimensions instead of dropping rows or fabricating values.
public enum GlifiStudioKHChiSquareStatus: String, Codable, Sendable {
    case defined, zeroTotal, zeroMarginal, insufficientDimensions
}

/// Aligned target/context counts within one declared aggregation level.
public struct GlifiStudioKHContextCounts: Codable, Equatable, Sendable {
    /// Caller-declared sentence, paragraph or heading aggregation unit.
    public let level: GlifiStudioKHContextLevel
    /// Finite coefficient of this level; omitted input resolves to one.
    public let alpha: Double
    /// Units by target words; a positive count selects its unit once, regardless of TF.
    public let targetCounts: [[Double]]
    /// The same units by context words, aligned row for row with targetCounts.
    public let contextCounts: [[Double]]
    /// Stores aligned count matrices and an explicit level weight for execution-time validation.
    public init(
        level: GlifiStudioKHContextLevel, alpha: Double = 1,
        targetCounts: [[Double]], contextCounts: [[Double]]
    ) {
        self.level = level
        self.alpha = alpha
        self.targetCounts = targetCounts
        self.contextCounts = contextCounts
    }
    /// Decodes the four declared fields, rejecting unknown keys and resolving an omitted alpha to one.
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
    /// Number of sequential observation updates, rather than complete data epochs.
    public let steps: Int
    /// Positive initial coefficient of the inverse-time learning-rate schedule.
    public let initialLearningRate: Double
    /// Positive starting neighborhood radius in grid-distance units, tending linearly to one.
    public let initialRadius: Double
    /// Stores one continuous phase schedule, which the training operator validates before use.
    public init(steps: Int, initialLearningRate: Double, initialRadius: Double) {
        self.steps = steps
        self.initialLearningRate = initialLearningRate
        self.initialRadius = initialRadius
    }
    /// Decodes the three required phase parameters without inferring a schedule.
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
    /// Observed node-collocate pairs within the declared window, including overlapping windows.
    public let jointCount: Int
    /// Node occurrences in the complete corpus before vocabulary filtering.
    public let nodeFrequency: Int
    /// Collocate occurrences in the same complete corpus.
    public let collocateFrequency: Int
    /// Complete corpus token exposure, rather than the number of window opportunities.
    public let corpusTokenCount: Int
    /// Number of admitted offsets around a node occurrence, excluding its own position.
    public let windowSpan: Int
    /// Stores global frequencies and window observations for validation by the score operator.
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
    /// Decodes the five required counts while rejecting unknown input fields.
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

/// Exact document frequencies for a condition and term, permitting their document sets to overlap.
public struct GlifiStudioKHWordAssociationInput: Codable, Equatable, Sendable {
    /// Documents jointly satisfying the condition and containing the term.
    public let jointCount: Int
    /// Documents satisfying the caller-declared condition.
    public let conditionDocumentCount: Int
    /// Documents containing the term across the complete universe.
    public let termDocumentCount: Int
    /// Complete document universe before selecting the condition.
    public let totalDocumentCount: Int

    /// Stores exact document frequencies; execution validates their shared 2×2 universe.
    public init(
        jointCount: Int, conditionDocumentCount: Int, termDocumentCount: Int,
        totalDocumentCount: Int
    ) {
        self.jointCount = jointCount
        self.conditionDocumentCount = conditionDocumentCount
        self.termDocumentCount = termDocumentCount
        self.totalDocumentCount = totalDocumentCount
    }

    /// Rejects unknown keys and explicit null counts without coercing numeric types.
    public init(from decoder: any Decoder) throws {
        let f = try khFields(
            decoder,
            allowed: [
                "jointCount", "conditionDocumentCount", "termDocumentCount", "totalDocumentCount",
            ])
        self.init(
            jointCount: try f.khRequired("jointCount"),
            conditionDocumentCount: try f.khRequired("conditionDocumentCount"),
            termDocumentCount: try f.khRequired("termDocumentCount"),
            totalDocumentCount: try f.khRequired("totalDocumentCount"))
    }

    func core() throws -> GlifiCooccurrenceCounts {
        guard jointCount >= 0, conditionDocumentCount >= 0, termDocumentCount >= 0,
            totalDocumentCount >= 0, conditionDocumentCount <= totalDocumentCount,
            termDocumentCount <= totalDocumentCount, jointCount <= conditionDocumentCount,
            jointCount <= termDocumentCount,
            termDocumentCount - jointCount <= totalDocumentCount - conditionDocumentCount
        else { throw textRequestFailure("kh-word-association.invalid-counts") }
        return try GlifiCooccurrenceCounts(
            jointCount: jointCount, firstOnlyCount: conditionDocumentCount - jointCount,
            secondOnlyCount: termDocumentCount - jointCount,
            neitherCount: totalDocumentCount - conditionDocumentCount
                - (termDocumentCount - jointCount))
    }
}

/// An independently observed compound; nested occurrences must not be counted twice.
public struct GlifiStudioTermCandidate: Codable, Equatable, Sendable {
    /// Ordered lexical keys already segmented by the caller, without an inferred join operation.
    public let components: [String]
    /// Positive independent occurrences of this complete candidate, excluding nested occurrences.
    public let frequency: Int
    /// Stores a declared candidate and its independent frequency without inferring linguistic structure.
    public init(components: [String], frequency: Int) {
        self.components = components
        self.frequency = frequency
    }
    /// Decodes the required component sequence and frequency, rejecting unknown keys.
    public init(from decoder: any Decoder) throws {
        let f = try khFields(decoder, allowed: ["components", "frequency"])
        self.init(
            components: try f.khRequired("components"), frequency: try f.khRequired("frequency"))
    }
}

/// A caller-annotated lexical token, retaining exact UTF-8 source coordinates.
public struct GlifiStudioTermToken: Codable, Equatable, Sendable {
    /// Exact token surface whose UTF-8 bytes must match the indicated source interval.
    public let surface: String
    /// Caller-supplied lexical key used for candidate formation, without automatic lemmatization.
    public let base: String
    /// Exact backend POS label, or nil when unavailable; extraction requiring POS then fails.
    public let partOfSpeech: String?
    /// Inclusive byte offset of the token in the original document text.
    public let startUTF8: Int
    /// Exclusive byte offset of the token in the original document text.
    public let endUTF8: Int
    /// Zero-based caller sentence identity used to prevent cross-sentence compounds.
    public let sentence: Int
    /// Zero-based caller paragraph identity used to prevent cross-paragraph compounds.
    public let paragraph: Int
    /// Stores explicit lexical annotations and half-open source offsets for later validation.
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
    /// Decodes token evidence, preserving an absent or null POS and omitted boundary identities as zero.
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
    /// Caller document identity retained in every extracted occurrence.
    public let id: String
    /// Original source text used to validate exact UTF-8 surfaces and evidence intervals.
    public let text: String
    /// Caller-annotated tokens in source order, without an implicit tokenizer or tagger.
    public let tokens: [GlifiStudioTermToken]
    /// Caller provenance identifying how lexical keys and POS annotations were produced.
    public let linguisticContract: String
    /// Stores a source document and its declared annotations without selecting a language backend.
    public init(
        id: String, text: String, tokens: [GlifiStudioTermToken], linguisticContract: String
    ) {
        self.id = id
        self.text = text
        self.tokens = tokens
        self.linguisticContract = linguisticContract
    }
    /// Decodes the four required document fields, rejecting unknown input keys.
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
    /// Caller versioned identity of the complete candidate-formation policy.
    public let identifier: String
    /// Exact POS labels admitted into a maximal candidate run.
    public let allowedPartsOfSpeech: [String]
    /// Explicit excluded lexical keys that split runs, with no inferred stopword list.
    public let ignoredKeys: [String]
    /// Minimum admitted maximal-run length; the default two selects compounds.
    public let minimumComponents: Int
    /// Maximum admitted maximal-run length; longer runs fail rather than truncate.
    public let maximumComponents: Int
    /// Stores explicit POS and exclusion policies, defaulting compound lengths to two through 64.
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
    /// Decodes the declared rule and resolves only omitted exclusions and component bounds to defaults.
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
    /// Unique class labels in the canonical order required when restoring Core statistics.
    public let classes: [String]
    /// Unique training terms in canonical order, including newly learned terms after continuation.
    public let vocabulary: [String]
    /// Positive training-document totals aligned with classes, including empty documents.
    public let documentCounts: [Int]
    /// Nonnegative exact integer counts indexed by class and then vocabulary position.
    public let tokenCounts: [[Int]]
    /// Positive symmetric pseudocount retained across all updates, defaulting to one.
    public let smoothing: Double
    /// Stores transient sufficient statistics for validation before restoration or continuation.
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
    /// Decodes only the declared statistics, resolving an omitted smoothing value to one.
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
