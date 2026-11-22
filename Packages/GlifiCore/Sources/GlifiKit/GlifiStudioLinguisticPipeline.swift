// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Explicit lexical views supported by the native Italian linguistic pipeline.
public enum GlifiStudioLinguisticBase: String, Codable, Equatable, Sendable {
    /// Existing normalized surface forms; no inference or model is required.
    case normalizedSurface = "normalized-surface"
    /// Single-best lemmas from installed Apple language assets.
    case appleLemma = "apple-lemma"
    /// Original native implementation of Snowball Italian 3.1.0.
    case italianSnowballStem = "italian-snowball-3.1.0"

    fileprivate var core: GlifiLinguisticBase {
        switch self {
        case .normalizedSurface: .normalizedSurface
        case .appleLemma: .appleLemma
        case .italianSnowballStem: .italianSnowballStem
        }
    }
}

/// Canonical options, with unknown keys and explicit null defaults rejected during decoding.
public struct GlifiStudioLinguisticOptions: Codable, Equatable, Sendable {
    /// Explicitly supported scope; currently exactly `it`.
    public let languageTag: String
    /// Selected surface, lemma or stem view.
    public let base: GlifiStudioLinguisticBase
    /// Requests raw Apple lexical-class tags when available.
    public let includePartOfSpeech: Bool

    /// Versioned semantic identity; runtime/model provenance is retained separately.
    public var methodIdentifier: String {
        linguisticMethodIdentifier(base: base, includePartOfSpeech: includePartOfSpeech)
    }

    /// Creates explicit resolved options without changing the existing automatic-coding default.
    public init(
        languageTag: String = "it", base: GlifiStudioLinguisticBase = .normalizedSurface,
        includePartOfSpeech: Bool = false
    ) {
        self.languageTag = languageTag
        self.base = base
        self.includePartOfSpeech = includePartOfSpeech
    }

    /// Resolves omitted defaults while rejecting unknown keys and explicit null values.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: TextAnalysisKey.self)
        let allowed: Set<String> = ["languageTag", "base", "includePartOfSpeech"]
        guard fields.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
        self.init(
            languageTag: try fields.decode(
                String.self, forKey: TextAnalysisKey("languageTag"), fallback: "it"),
            base: try fields.decode(
                GlifiStudioLinguisticBase.self, forKey: TextAnalysisKey("base"),
                fallback: .normalizedSurface),
            includePartOfSpeech: try fields.decode(
                Bool.self, forKey: TextAnalysisKey("includePartOfSpeech"), fallback: false))
    }
}

/// An annotation can be absent because it was not requested or because the model returned unknown.
public enum GlifiStudioLinguisticAnnotationState: String, Codable, Equatable, Sendable {
    /// The selected configuration does not request this annotation.
    case notRequested
    /// A single-best model prediction exists; this is not a claim of gold accuracy.
    case resolved
    /// No prediction exists; the pipeline does not fabricate a fallback.
    case unknown

    fileprivate init(_ value: GlifiLinguisticAnnotationState) {
        switch value {
        case .notRequested: self = .notRequested
        case .resolved: self = .resolved
        case .unknown: self = .unknown
        }
    }
}

/// Core-free identity and environment of one linguistic computation.
public struct GlifiStudioLinguisticProvenance: Codable, Equatable, Sendable {
    /// Supported language scope.
    public let languageTag: String
    /// Locale for normalized lexical forms.
    public let localeIdentifier: String
    /// Boundary rules actually used.
    public let tokenizationIdentifier: String
    /// Native implementation or Apple framework.
    public let backendIdentifier: String
    /// Glifi adapter revision; not an invented Apple asset version.
    public let backendVersion: String
    /// Exact OS version/build reported at execution.
    public let operatingSystemVersion: String
    /// Unknown for the installed built-in Apple models, explicitly encoded as null.
    public let modelVersion: String?
    /// Explains why no model version is supplied.
    public let modelVersionPolicy: String
    /// Selected lexical view.
    public let base: GlifiStudioLinguisticBase
    /// Whether raw lexical-class predictions were requested.
    public let includesPartOfSpeech: Bool
    /// Apple raw tag vocabulary; no lossy UPOS mapping is implied.
    public let partOfSpeechTagset: String?
    /// Single-best uncalibrated or deterministic-rule policy.
    public let predictionPolicy: String
    /// Exact Snowball rule revision, if requested.
    public let stemmingIdentifier: String?
    /// Identity used by the automatic-coding engine for this input.
    public let codingContractIdentifier: String

    /// Stable method identity derived only from declared semantic options.
    public var methodIdentifier: String {
        linguisticMethodIdentifier(base: base, includePartOfSpeech: includesPartOfSpeech)
    }

    private enum CodingKeys: String, CodingKey {
        case languageTag, localeIdentifier, tokenizationIdentifier, backendIdentifier,
            backendVersion
        case operatingSystemVersion, modelVersion, modelVersionPolicy, base, includesPartOfSpeech
        case partOfSpeechTagset, predictionPolicy, stemmingIdentifier, codingContractIdentifier
    }

    fileprivate init(_ value: GlifiLinguisticProvenance, base: GlifiStudioLinguisticBase) {
        languageTag = value.languageTag
        localeIdentifier = value.localeIdentifier
        tokenizationIdentifier = value.tokenizationIdentifier
        backendIdentifier = value.backendIdentifier
        backendVersion = value.backendVersion
        operatingSystemVersion = value.operatingSystemVersion
        modelVersion = value.modelVersion
        modelVersionPolicy = value.modelVersionPolicy
        self.base = base
        includesPartOfSpeech = value.includesPartOfSpeech
        partOfSpeechTagset = value.partOfSpeechTagset
        predictionPolicy = value.predictionPolicy
        stemmingIdentifier = value.stemmingIdentifier
        codingContractIdentifier = value.codingContractIdentifier
    }

    /// Encodes unavailable model and optional feature metadata explicitly as null.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(languageTag, forKey: .languageTag)
        try fields.encode(localeIdentifier, forKey: .localeIdentifier)
        try fields.encode(tokenizationIdentifier, forKey: .tokenizationIdentifier)
        try fields.encode(backendIdentifier, forKey: .backendIdentifier)
        try fields.encode(backendVersion, forKey: .backendVersion)
        try fields.encode(operatingSystemVersion, forKey: .operatingSystemVersion)
        try fields.encode(modelVersion, forKey: .modelVersion)
        try fields.encode(modelVersionPolicy, forKey: .modelVersionPolicy)
        try fields.encode(base, forKey: .base)
        try fields.encode(includesPartOfSpeech, forKey: .includesPartOfSpeech)
        try fields.encode(partOfSpeechTagset, forKey: .partOfSpeechTagset)
        try fields.encode(predictionPolicy, forKey: .predictionPolicy)
        try fields.encode(stemmingIdentifier, forKey: .stemmingIdentifier)
        try fields.encode(codingContractIdentifier, forKey: .codingContractIdentifier)
    }
}

/// One offset-preserving token without exposing GlifiCore types.
public struct GlifiStudioLinguisticToken: Codable, Equatable, Sendable {
    /// Unchanged source substring.
    public let surface: String
    /// NFC/Italian-lowercase lexical view.
    public let normalized: String
    /// Apple prediction, or null with an explicit state.
    public let lemma: String?
    /// Snowball stem, or null when not requested.
    public let stem: String?
    /// Raw Apple lexical-class prediction, or null with an explicit state.
    public let partOfSpeech: String?
    /// Requested/known distinction for lemma.
    public let lemmaState: GlifiStudioLinguisticAnnotationState
    /// Requested/known distinction for POS.
    public let partOfSpeechState: GlifiStudioLinguisticAnnotationState
    /// Inclusive UTF-8 byte offset in original extracted text.
    public let startUTF8: Int
    /// Exclusive UTF-8 byte offset in original extracted text.
    public let endUTF8: Int
    /// Sentence ordinal under the declared segmentation.
    public let sentence: Int
    /// Paragraph ordinal under the declared segmentation.
    public let paragraph: Int

    private enum CodingKeys: String, CodingKey {
        case surface, normalized, lemma, stem, partOfSpeech, lemmaState, partOfSpeechState
        case startUTF8, endUTF8, sentence, paragraph
    }

    fileprivate init(_ value: GlifiLinguisticToken) {
        surface = value.surface
        normalized = value.normalized
        lemma = value.lemma
        stem = value.stem
        partOfSpeech = value.partOfSpeech
        lemmaState = GlifiStudioLinguisticAnnotationState(value.lemmaState)
        partOfSpeechState = GlifiStudioLinguisticAnnotationState(value.partOfSpeechState)
        startUTF8 = value.range.start
        endUTF8 = value.range.end
        sentence = value.sentence
        paragraph = value.paragraph
    }

    /// Writes null for unknown or unrequested annotations, retaining the distinct state fields.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(surface, forKey: .surface)
        try fields.encode(normalized, forKey: .normalized)
        try fields.encode(lemma, forKey: .lemma)
        try fields.encode(stem, forKey: .stem)
        try fields.encode(partOfSpeech, forKey: .partOfSpeech)
        try fields.encode(lemmaState, forKey: .lemmaState)
        try fields.encode(partOfSpeechState, forKey: .partOfSpeechState)
        try fields.encode(startUTF8, forKey: .startUTF8)
        try fields.encode(endUTF8, forKey: .endUTF8)
        try fields.encode(sentence, forKey: .sentence)
        try fields.encode(paragraph, forKey: .paragraph)
    }
}

/// Complete transient annotations with original text and exact provenance.
public struct GlifiStudioLinguisticAnnotation: Codable, Equatable, Sendable {
    /// Semantic method identity, distinct from installed model availability.
    public var methodIdentifier: String { provenance.methodIdentifier }
    /// Original, unmodified text.
    public let text: String
    /// Ordered lexical observations.
    public let tokens: [GlifiStudioLinguisticToken]
    /// Configuration, backend, runtime and model-version availability.
    public let provenance: GlifiStudioLinguisticProvenance

    fileprivate init(_ value: GlifiLinguisticAnnotation, base: GlifiStudioLinguisticBase) {
        text = value.text
        tokens = value.tokens.map(GlifiStudioLinguisticToken.init)
        provenance = GlifiStudioLinguisticProvenance(value.provenance, base: base)
    }
}

/// Per-device capability probe, never a claim of linguistic accuracy.
public struct GlifiStudioLinguisticAvailability: Codable, Equatable, Sendable {
    /// Versioned capability-probe identity; not a scientific support status.
    public var methodIdentifier: String { "Linguistic-Italian-availability-v1" }
    /// Supported language scope.
    public let languageTag: String
    /// Whether installed assets advertise word lemmas.
    public let hasLemma: Bool
    /// Whether installed assets advertise word lexical classes.
    public let hasPartOfSpeech: Bool
    /// Native stemming is available without assets.
    public let hasItalianStemming: Bool
    /// Runtime that supplied the availability response.
    public let operatingSystemVersion: String

    fileprivate init(_ value: GlifiLinguisticAvailability) {
        languageTag = value.languageTag
        hasLemma = value.hasLemma
        hasPartOfSpeech = value.hasPartOfSpeech
        hasItalianStemming = value.hasItalianStemming
        operatingSystemVersion = value.operatingSystemVersion
    }
}

/// Automatic-coding matrix plus the actual linguistic provenance of each input unit, in order.
public struct GlifiStudioAnnotatedCodingResult: Encodable, Equatable, Sendable {
    /// Exact coding-rule revision combined with the requested linguistic view.
    public let methodIdentifier: String
    /// Existing binary document-code matrix, frequencies and positive evidence.
    public let matrix: GlifiStudioCodingMatrix
    /// One provenance record per matrix document, without dropping OS/model information.
    public let provenanceByUnit: [GlifiStudioLinguisticProvenance]
}

/// Off-actor native linguistic views and annotated automatic coding without project mutation.
public enum GlifiStudioLinguisticPipeline {
    /// Returns only installed capabilities; no assets or models are downloaded.
    @concurrent public static func availability(
        languageTag: String = "it"
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticAvailability {
        try mapLinguisticFailure {
            try Task.checkCancellation()
            return try GlifiStudioLinguisticAvailability(
                GlifiLinguisticPipeline.availability(languageTag: languageTag))
        }
    }

    /// Annotates bounded Italian text off the caller's actor, preserving original UTF-8 offsets.
    @concurrent public static func annotate(
        _ text: String, options: GlifiStudioLinguisticOptions = .init()
    ) async throws(GlifiStudioFailure) -> GlifiStudioLinguisticAnnotation {
        try mapLinguisticFailure {
            let value = try GlifiLinguisticPipeline.annotate(
                text: text, languageTag: options.languageTag, base: options.base.core,
                includePartOfSpeech: options.includePartOfSpeech)
            try Task.checkCancellation()
            let result = GlifiStudioLinguisticAnnotation(value, base: options.base)
            try Task.checkCancellation()
            return result
        }
    }

    /// Applies one explicit linguistic configuration and rule set, keeping per-unit provenance.
    ///
    /// Aggregate input is bounded to 1 MiB and 10,000 units; annotations retain the Core's
    /// aggregate token and output bounds. Unknown requested lemmas/POS abort without a matrix.
    @concurrent public static func codeAnnotated(
        _ units: [GlifiStudioAutomaticCodingUnit], rules: String,
        options: GlifiStudioLinguisticOptions = .init()
    ) async throws(GlifiStudioFailure) -> GlifiStudioAnnotatedCodingResult {
        try mapLinguisticFailure {
            try Task.checkCancellation()
            guard !units.isEmpty else { throw textRequestFailure("linguistic.invalid-unit") }
            guard units.count <= 10_000 else {
                throw textRequestFailure("linguistic.unit-limit", category: "insufficientResources")
            }
            var remainingInput = GlifiLinguisticLimits.standard.maximumTextBytes
            for unit in units {
                guard !unit.id.isEmpty, unit.id.utf8.count <= 4_096, unit.variables.count <= 256
                else {
                    throw textRequestFailure("linguistic.invalid-unit")
                }
                for value in [unit.id, unit.text] + unit.variables.flatMap({ [$0.key, $0.value] }) {
                    guard value.utf8.count <= remainingInput else {
                        throw textRequestFailure(
                            "linguistic.text-limit", category: "insufficientResources")
                    }
                    remainingInput -= value.utf8.count
                }
            }
            let compiled = try GlifiCodingRuleSet(rules)
            var documents: [GlifiCodingDocument] = []
            var provenance: [GlifiStudioLinguisticProvenance] = []
            documents.reserveCapacity(units.count)
            provenance.reserveCapacity(units.count)
            var remainingTokens = GlifiLinguisticLimits.standard.maximumTokenCount
            var remainingOutput = GlifiLinguisticLimits.standard.maximumOutputUTF8Bytes
            for unit in units {
                try Task.checkCancellation()
                let result = try GlifiLinguisticPipeline.annotate(
                    text: unit.text, languageTag: options.languageTag, base: options.base.core,
                    includePartOfSpeech: options.includePartOfSpeech,
                    limits: .init(
                        maximumTokenCount: remainingTokens, maximumOutputUTF8Bytes: remainingOutput)
                )
                documents.append(try result.codingDocument(id: unit.id, variables: unit.variables))
                provenance.append(
                    GlifiStudioLinguisticProvenance(result.provenance, base: options.base))
                remainingTokens -= result.tokens.count
                for token in result.tokens {
                    remainingOutput -=
                        token.surface.utf8.count + token.normalized.utf8.count
                        + (token.lemma?.utf8.count ?? 0) + (token.stem?.utf8.count ?? 0)
                        + (token.partOfSpeech?.utf8.count ?? 0)
                }
            }
            let matrix = try GlifiStudioCodingMatrix(compiled.evaluate(documents))
            try Task.checkCancellation()
            return GlifiStudioAnnotatedCodingResult(
                methodIdentifier: GlifiCodingRuleSet.identifier + "+" + options.methodIdentifier,
                matrix: matrix, provenanceByUnit: provenance)
        }
    }
}

private func linguisticMethodIdentifier(
    base: GlifiStudioLinguisticBase, includePartOfSpeech: Bool
) -> String {
    "Linguistic-Italian-\(base.rawValue)\(includePartOfSpeech ? "-ApplePOS" : "")-v1"
}

private func mapLinguisticFailure<Value>(
    _ body: () throws -> Value
) throws(GlifiStudioFailure) -> Value {
    do { return try body() } catch let failure as GlifiStudioFailure { throw failure } catch let
        failure as GlifiFailure
    { throw GlifiStudioFailure(failure) } catch is CancellationError {
        throw textRequestFailure("operation.cancelled", category: "cancelled")
    } catch {
        throw textRequestFailure("linguistic.failed", category: "insufficientData")
    }
}
