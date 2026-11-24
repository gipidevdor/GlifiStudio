// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import NaturalLanguage

/// The explicitly selected lexical view used by automatic coding.
public enum GlifiLinguisticBase: String, Codable, Equatable, Sendable {
    /// Existing Italian NFC/lowercase surface forms, without linguistic inference.
    case normalizedSurface = "normalized-surface"
    /// Single-best lemmas supplied by Apple's installed Italian language assets.
    case appleLemma = "apple-lemma"
    /// Native Snowball Italian 3.1.0 stems, not lemmas.
    case italianSnowballStem = "italian-snowball-3.1.0"
}

/// Whether an annotation was requested and whether its provider supplied a value.
public enum GlifiLinguisticAnnotationState: String, Codable, Equatable, Sendable {
    /// The selected configuration does not request this annotation.
    case notRequested
    /// A backend supplied its single-best prediction; accuracy is evaluated separately.
    case resolved
    /// The backend did not supply a prediction; no replacement is fabricated.
    case unknown
}

/// Resource bounds checked before text preparation and while materializing annotations.
public struct GlifiLinguisticLimits: Equatable, Sendable {
    /// Bounded configuration suitable for transient headless requests.
    public static let standard = GlifiLinguisticLimits()
    /// Maximum original text bytes before tokenization or framework assignment.
    public let maximumTextBytes: Int
    /// Maximum emitted lexical tokens.
    public let maximumTokenCount: Int
    /// Maximum bytes in a surface token or one backend annotation.
    public let maximumTokenBytes: Int
    /// Maximum aggregate UTF-8 bytes retained in token fields.
    public let maximumOutputUTF8Bytes: Int

    /// Creates explicit bounds; the pipeline rejects invalid bounds before processing.
    public init(
        maximumTextBytes: Int = 1_048_576, maximumTokenCount: Int = 100_000,
        maximumTokenBytes: Int = 4_096, maximumOutputUTF8Bytes: Int = 16_777_216
    ) {
        self.maximumTextBytes = maximumTextBytes
        self.maximumTokenCount = maximumTokenCount
        self.maximumTokenBytes = maximumTokenBytes
        self.maximumOutputUTF8Bytes = maximumOutputUTF8Bytes
    }
}

/// Reproducibility metadata without claiming an unavailable Apple model version or accuracy.
public struct GlifiLinguisticProvenance: Codable, Equatable, Sendable {
    /// Exactly `it`; this increment does not promote additional languages.
    public let languageTag: String
    /// Locale used only for the explicit normalized lexical view.
    public let localeIdentifier: String
    /// Versioned token boundary contract, distinct from the selected base view.
    public let tokenizationIdentifier: String
    /// Stable implementation identity.
    public let backendIdentifier: String
    /// Version of Glifi's adapter, not an invented Apple asset version.
    public let backendVersion: String
    /// Exact OS version/build reported by the running process.
    public let operatingSystemVersion: String
    /// Apple does not expose the version of its built-in tagging assets; remains nil.
    public let modelVersion: String?
    /// Explicit explanation of the model-version field.
    public let modelVersionPolicy: String
    /// Selected view, never silently substituted when unavailable.
    public let base: GlifiLinguisticBase
    /// Whether Apple lexical-class predictions were requested.
    public let includesPartOfSpeech: Bool
    /// Raw tag vocabulary; no undocumented conversion to Universal POS is performed.
    public let partOfSpeechTagset: String?
    /// Explicit single-best policy; no calibrated confidence is claimed.
    public let predictionPolicy: String
    /// Exact stemming rules, when requested.
    public let stemmingIdentifier: String?

    /// Identity retained when the annotations become input to the coding engine.
    public var codingContractIdentifier: String {
        if base == .normalizedSurface && !includesPartOfSpeech {
            return "it-token-v1.normalized-surface"
        }
        return
            "\(tokenizationIdentifier);base=\(base.rawValue);pos=\(includesPartOfSpeech);backend=\(backendIdentifier);version=\(backendVersion);os=\(operatingSystemVersion)"
    }
}

/// One lexical token with exact original UTF-8 coordinates and explicitly optional predictions.
public struct GlifiLinguisticToken: Codable, Equatable, Sendable {
    /// Unchanged source substring.
    public let surface: String
    /// NFC/Italian-lowercase view, without changing the source range.
    public let normalized: String
    /// Apple prediction; nil when not requested or unknown, distinguished by lemmaState.
    public let lemma: String?
    /// Snowball stem; never presented as a lemma.
    public let stem: String?
    /// Raw Apple lexical-class prediction, without invented morphological features.
    public let partOfSpeech: String?
    /// Availability of the lemma prediction.
    public let lemmaState: GlifiLinguisticAnnotationState
    /// Availability of the POS prediction.
    public let partOfSpeechState: GlifiLinguisticAnnotationState
    /// Original extracted-text range, measured in UTF-8 bytes.
    public let range: GlifiUTF8Range
    /// Nondecreasing sentence ordinal under the declared tokenization contract.
    public let sentence: Int
    /// Nondecreasing paragraph ordinal under the declared tokenization contract.
    public let paragraph: Int
}

/// Annotated immutable text, with an explicit conversion to the existing coding input contract.
public struct GlifiLinguisticAnnotation: Codable, Equatable, Sendable {
    /// Original text; annotation never rewrites it.
    public let text: String
    /// Ordered, nonoverlapping lexical token observations.
    public let tokens: [GlifiLinguisticToken]
    /// Actual backend, configuration and runtime provenance.
    public let provenance: GlifiLinguisticProvenance

    /// Validates all requested coding annotations, rejecting unknown lemmas or POS as needed.
    public func codingDocument(
        id: String, variables: [String: String] = [:], limits: GlifiLinguisticLimits = .standard
    ) throws
        -> GlifiCodingDocument
    {
        try Task.checkCancellation()
        try validateLinguisticLimits(limits)
        guard text.utf8.count <= limits.maximumTextBytes, tokens.count <= limits.maximumTokenCount
        else {
            throw linguisticPipelineFailure(
                "linguistic.annotation-limit", category: .insufficientResources)
        }
        var codingTokens: [GlifiCodingToken] = []
        codingTokens.reserveCapacity(tokens.count)
        var retainedBytes = 0
        let originalBytes = text.utf8
        var sourceCursor = originalBytes.startIndex
        var sourceOffset = 0
        for token in tokens {
            try Task.checkCancellation()
            guard token.range.start >= sourceOffset, token.range.end > token.range.start,
                token.range.end <= originalBytes.count,
                let start = originalBytes.index(
                    sourceCursor, offsetBy: token.range.start - sourceOffset,
                    limitedBy: originalBytes.endIndex),
                let end = originalBytes.index(
                    start, offsetBy: token.range.end - token.range.start,
                    limitedBy: originalBytes.endIndex),
                originalBytes[start..<end].elementsEqual(token.surface.utf8)
            else { throw linguisticPipelineFailure("linguistic.invalid-token-range") }
            sourceCursor = end
            sourceOffset = token.range.end
            let added = try linguisticRetainedBytes(
                surface: token.surface, normalized: token.normalized, lemma: token.lemma,
                stem: token.stem, pos: token.partOfSpeech,
                maximumTokenBytes: limits.maximumTokenBytes)
            guard added <= limits.maximumOutputUTF8Bytes - retainedBytes else {
                throw linguisticPipelineFailure(
                    "linguistic.output-limit", category: .insufficientResources)
            }
            retainedBytes += added
            let base: String
            switch provenance.base {
            case .normalizedSurface: base = token.normalized
            case .italianSnowballStem:
                guard let stem = token.stem, !stem.isEmpty else {
                    throw linguisticPipelineFailure(
                        "linguistic.missing-stem", category: .insufficientData)
                }
                base = stem
            case .appleLemma:
                guard token.lemmaState == .resolved, let lemma = token.lemma, !lemma.isEmpty else {
                    throw linguisticPipelineFailure(
                        "linguistic.missing-lemma", category: .insufficientData)
                }
                base = lemma
            }
            if provenance.includesPartOfSpeech,
                token.partOfSpeechState != .resolved || token.partOfSpeech?.isEmpty != false
            {
                throw linguisticPipelineFailure(
                    "linguistic.missing-pos", category: .insufficientData)
            }
            codingTokens.append(
                GlifiCodingToken(
                    surface: token.surface, base: base, partOfSpeech: token.partOfSpeech,
                    range: token.range, sentence: token.sentence, paragraph: token.paragraph))
        }
        let document = try GlifiCodingDocument(
            id: id, text: text, tokens: codingTokens, variables: variables,
            linguisticContract: provenance.codingContractIdentifier)
        try Task.checkCancellation()
        return document
    }
}

/// Per-device availability, distinct from validation or measured linguistic accuracy.
public struct GlifiLinguisticAvailability: Codable, Equatable, Sendable {
    /// Exactly the requested supported scope, currently Italian only.
    public let languageTag: String
    /// Whether installed assets advertise word lemmas.
    public let hasLemma: Bool
    /// Whether installed assets advertise word lexical classes.
    public let hasPartOfSpeech: Bool
    /// Native Italian stemming does not require downloadable assets.
    public let hasItalianStemming: Bool
    /// OS that supplied these capabilities.
    public let operatingSystemVersion: String
}

/// Native, bounded linguistic views; each call owns its NLTagger and never requests assets.
public enum GlifiLinguisticPipeline {
    /// Checks installed Apple schemes without downloading assets or promoting a language.
    public static func availability(languageTag: String = "it") throws
        -> GlifiLinguisticAvailability
    {
        guard languageTag == "it" else {
            throw linguisticPipelineFailure("linguistic.unsupported-language")
        }
        let schemes = NLTagger.availableTagSchemes(for: .word, language: .italian)
        return GlifiLinguisticAvailability(
            languageTag: languageTag, hasLemma: schemes.contains(.lemma),
            hasPartOfSpeech: schemes.contains(.lexicalClass), hasItalianStemming: true,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString)
    }

    /// Annotates Italian text on the caller's executor; asynchronous facades must leave their actor.
    ///
    /// The surface-only default preserves it-token-v1. Apple requests declare a separate word
    /// segmentation contract. Unknown predictions remain nil and are rejected by codingDocument.
    public static func annotate(
        text: String, languageTag: String = "it", base: GlifiLinguisticBase = .normalizedSurface,
        includePartOfSpeech: Bool = false, limits: GlifiLinguisticLimits = .standard
    ) throws -> GlifiLinguisticAnnotation {
        try Task.checkCancellation()
        try validateLinguisticLimits(limits)
        guard languageTag == "it" else {
            throw linguisticPipelineFailure("linguistic.unsupported-language")
        }
        guard text.utf8.count <= limits.maximumTextBytes else {
            throw linguisticPipelineFailure(
                "linguistic.text-limit", category: .insufficientResources)
        }
        let usesApple = base == .appleLemma || includePartOfSpeech
        let tokens: [GlifiLinguisticToken]
        if usesApple {
            let available = try availability(languageTag: languageTag)
            guard base != .appleLemma || available.hasLemma,
                !includePartOfSpeech || available.hasPartOfSpeech
            else {
                throw linguisticPipelineFailure(
                    "linguistic.unavailable-scheme", category: .insufficientData)
            }
            tokens = try appleTokens(
                text: text, base: base, includePartOfSpeech: includePartOfSpeech, limits: limits)
        } else {
            tokens = try surfaceTokens(text: text, base: base, limits: limits)
        }
        try Task.checkCancellation()
        let provenance = GlifiLinguisticProvenance(
            languageTag: languageTag, localeIdentifier: "it_IT",
            tokenizationIdentifier: usesApple ? "AppleNL-word-it-v1" : "it-token-v1",
            backendIdentifier: usesApple
                ? "com.apple.NaturalLanguage.NLTagger" : "studio.glifi.native",
            backendVersion: "1",
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            modelVersion: nil,
            modelVersionPolicy: usesApple ? "not-exposed-by-system-framework" : "no-model",
            base: base, includesPartOfSpeech: includePartOfSpeech,
            partOfSpeechTagset: includePartOfSpeech ? "Apple-NLTagSchemeLexicalClass" : nil,
            predictionPolicy: usesApple ? "single-best-uncalibrated" : "deterministic-rules",
            stemmingIdentifier: base == .italianSnowballStem ? GlifiItalianStemmer.identifier : nil)
        return GlifiLinguisticAnnotation(text: text, tokens: tokens, provenance: provenance)
    }
}

func linguisticPipelineFailure(_ code: String, category: GlifiFailureCategory = .invalidInput)
    -> GlifiFailure
{
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category), retainedState: .unchanged,
        messageKey: "failure.\(code)")
}

private func validateLinguisticLimits(_ limits: GlifiLinguisticLimits) throws {
    guard (0...(64 * 1_024 * 1_024)).contains(limits.maximumTextBytes),
        (0...2_000_000).contains(limits.maximumTokenCount),
        (1...GlifiItalianStemmer.maximumTokenBytes).contains(limits.maximumTokenBytes),
        (0...(256 * 1_024 * 1_024)).contains(limits.maximumOutputUTF8Bytes)
    else { throw linguisticPipelineFailure("linguistic.invalid-limits") }
}

private func surfaceTokens(
    text: String, base: GlifiLinguisticBase, limits: GlifiLinguisticLimits
) throws -> [GlifiLinguisticToken] {
    let document = try GlifiCodingDocument(id: "linguistic-input", text: text)
    guard document.tokens.count <= limits.maximumTokenCount else {
        throw linguisticPipelineFailure(
            "linguistic.token-count-limit", category: .insufficientResources)
    }
    var tokens: [GlifiLinguisticToken] = []
    tokens.reserveCapacity(document.tokens.count)
    var outputBytes = 0
    for token in document.tokens {
        try Task.checkCancellation()
        try appendLinguisticToken(
            surface: token.surface, lemma: nil, pos: nil, range: token.range,
            sentence: token.sentence, paragraph: token.paragraph, base: base,
            includePartOfSpeech: false, limits: limits, outputBytes: &outputBytes, tokens: &tokens)
    }
    return tokens
}

private func appleTokens(
    text: String, base: GlifiLinguisticBase, includePartOfSpeech: Bool,
    limits: GlifiLinguisticLimits
) throws -> [GlifiLinguisticToken] {
    guard !text.isEmpty else { return [] }
    var schemes: [NLTagScheme] = [.tokenType]
    if base == .appleLemma { schemes.append(.lemma) }
    if includePartOfSpeech { schemes.append(.lexicalClass) }
    // NLTagger queries mutate internal state; this instance never escapes the synchronous call.
    let tagger = NLTagger(tagSchemes: schemes)
    tagger.string = text
    let wholeText = text.startIndex..<text.endIndex
    tagger.setLanguage(.italian, range: wholeText)
    var tokens: [GlifiLinguisticToken] = []
    var outputBytes = 0
    var byteCursor = text.utf8.startIndex
    var byteOffset = 0
    var sentenceEnd = text.startIndex
    var paragraphEnd = text.startIndex
    var sentence = -1
    var paragraph = -1
    var failure: (any Error)?
    tagger.enumerateTags(
        in: wholeText, unit: .word, scheme: includePartOfSpeech ? .lexicalClass : .tokenType,
        options: [.omitPunctuation, .omitWhitespace, .omitOther]
    ) { tag, range in
        do {
            try Task.checkCancellation()
            guard let start = range.lowerBound.samePosition(in: text.utf8),
                let end = range.upperBound.samePosition(in: text.utf8), start >= byteCursor,
                start < end
            else { throw linguisticPipelineFailure("linguistic.invalid-token-range") }
            let startOffset = byteOffset + text.utf8.distance(from: byteCursor, to: start)
            let endOffset = startOffset + text.utf8.distance(from: start, to: end)
            guard endOffset - startOffset <= limits.maximumTokenBytes else {
                throw linguisticPipelineFailure(
                    "linguistic.token-limit", category: .insufficientResources)
            }
            if range.lowerBound >= sentenceEnd {
                sentenceEnd = tagger.tokenRange(at: range.lowerBound, unit: .sentence).upperBound
                sentence += 1
            }
            if range.lowerBound >= paragraphEnd {
                paragraphEnd = tagger.tokenRange(at: range.lowerBound, unit: .paragraph).upperBound
                paragraph += 1
            }
            let lemma: String?
            if base == .appleLemma {
                let (value, lemmaRange) = tagger.tag(
                    at: range.lowerBound, unit: .word, scheme: .lemma)
                guard lemmaRange == range else {
                    throw linguisticPipelineFailure("linguistic.annotation-range-mismatch")
                }
                lemma = value?.rawValue
            } else {
                lemma = nil
            }
            try appendLinguisticToken(
                surface: String(text[range]), lemma: lemma,
                pos: includePartOfSpeech ? tag?.rawValue : nil,
                range: GlifiUTF8Range(start: startOffset, end: endOffset), sentence: sentence,
                paragraph: paragraph, base: base, includePartOfSpeech: includePartOfSpeech,
                limits: limits, outputBytes: &outputBytes, tokens: &tokens)
            byteCursor = end
            byteOffset = endOffset
            return true
        } catch {
            failure = error
            return false
        }
    }
    if let failure { throw failure }
    return tokens
}

private func appendLinguisticToken(
    surface: String, lemma: String?, pos: String?, range: GlifiUTF8Range,
    sentence: Int, paragraph: Int, base: GlifiLinguisticBase, includePartOfSpeech: Bool,
    limits: GlifiLinguisticLimits, outputBytes: inout Int, tokens: inout [GlifiLinguisticToken]
) throws {
    guard tokens.count < limits.maximumTokenCount,
        surface.utf8.count <= limits.maximumTokenBytes,
        lemma.map({ !$0.isEmpty && $0.utf8.count <= limits.maximumTokenBytes }) ?? true,
        pos.map({ !$0.isEmpty && $0.utf8.count <= limits.maximumTokenBytes }) ?? true
    else {
        throw linguisticPipelineFailure("linguistic.token-limit", category: .insufficientResources)
    }
    let normalized = surface.precomposedStringWithCanonicalMapping.lowercased(
        with: Locale(identifier: "it_IT"))
    let stem = base == .italianSnowballStem ? try GlifiItalianStemmer.stem(surface) : nil
    let added = try linguisticRetainedBytes(
        surface: surface, normalized: normalized, lemma: lemma, stem: stem, pos: pos,
        maximumTokenBytes: limits.maximumTokenBytes)
    guard added <= limits.maximumOutputUTF8Bytes - outputBytes else {
        throw linguisticPipelineFailure("linguistic.output-limit", category: .insufficientResources)
    }
    outputBytes += added
    tokens.append(
        GlifiLinguisticToken(
            surface: surface, normalized: normalized, lemma: lemma, stem: stem, partOfSpeech: pos,
            lemmaState: base == .appleLemma ? (lemma == nil ? .unknown : .resolved) : .notRequested,
            partOfSpeechState: includePartOfSpeech
                ? (pos == nil ? .unknown : .resolved) : .notRequested,
            range: range, sentence: sentence, paragraph: paragraph))
}

private func linguisticRetainedBytes(
    surface: String, normalized: String, lemma: String?, stem: String?, pos: String?,
    maximumTokenBytes: Int
) throws -> Int {
    let surfaceBytes = surface.utf8.count
    let normalizedBytes = normalized.utf8.count
    let lemmaBytes = lemma?.utf8.count ?? 0
    let stemBytes = stem?.utf8.count ?? 0
    let posBytes = pos?.utf8.count ?? 0
    guard surfaceBytes > 0, normalizedBytes > 0,
        surfaceBytes <= maximumTokenBytes, normalizedBytes <= maximumTokenBytes,
        lemmaBytes <= maximumTokenBytes, stemBytes <= maximumTokenBytes,
        posBytes <= maximumTokenBytes
    else {
        throw linguisticPipelineFailure("linguistic.token-limit", category: .insufficientResources)
    }
    // Five individually bounded fields; their sum cannot overflow Int.
    return surfaceBytes + normalizedBytes + lemmaBytes + stemBytes + posBytes
}
