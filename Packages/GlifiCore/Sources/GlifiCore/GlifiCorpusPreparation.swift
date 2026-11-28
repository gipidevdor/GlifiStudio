// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// One versioned Italian lexical configuration shared by project analytical clients.
public struct GlifiCorpusPreparation: Codable, Equatable, Sendable {
    /// Explicit normalized-surface, Italian lemma or stemming view.
    public var base: GlifiLinguisticBase
    /// Explicit lexical forms excluded unless included by the user.
    public var stopwords: [String]
    /// Observed terms retained across stopword and grammatical filtering.
    public var includedTerms: [String]
    /// Observed terms explicitly excluded from prepared representations.
    public var excludedTerms: [String]
    /// Whitespace-separated observed expressions, matched longest-first within a sentence.
    public var compounds: [String]
    /// Raw Apple lexical-class tags; an empty list disables grammatical selection.
    public var includedPartsOfSpeech: [String]

    /// Creates explicit research data for validation by the project writer.
    public init(
        base: GlifiLinguisticBase = .normalizedSurface, stopwords: [String] = [],
        includedTerms: [String] = [], excludedTerms: [String] = [], compounds: [String] = [],
        includedPartsOfSpeech: [String] = []
    ) {
        self.base = base
        self.stopwords = stopwords
        self.includedTerms = includedTerms
        self.excludedTerms = excludedTerms
        self.compounds = compounds
        self.includedPartsOfSpeech = includedPartsOfSpeech
    }

    /// Empty settings preserve the existing Italian normalized-surface token contract.
    public var isIdentity: Bool {
        base == .normalizedSurface && stopwords.isEmpty && includedTerms.isEmpty
            && excludedTerms.isEmpty && compounds.isEmpty && includedPartsOfSpeech.isEmpty
    }

    /// The identity includes the actual Apple runtime whenever linguistic predictions are used.
    public func digest() throws -> String {
        try digest(
            operatingSystemVersion: requiresAppleRuntime
                ? ProcessInfo.processInfo.operatingSystemVersionString : nil)
    }

    package var requiresAppleRuntime: Bool {
        base == .appleLemma || !includedPartsOfSpeech.isEmpty
    }

    /// Verifies historical configurations against their captured runtime, rather than today's OS.
    package func digest(operatingSystemVersion: String?) throws -> String {
        try validate()
        guard
            !requiresAppleRuntime
                || operatingSystemVersion.map({ !$0.isEmpty && $0.utf8.count <= 512 }) == true,
            requiresAppleRuntime || operatingSystemVersion == nil
        else { throw researchFailure("research.invalid-preparation-runtime") }
        struct Identity: Encodable {
            let schema = "studio.glifi.corpus-preparation.v1"
            let base: GlifiLinguisticBase
            let stopwords: [String]
            let includedTerms: [String]
            let excludedTerms: [String]
            let compounds: [String]
            let includedPartsOfSpeech: [String]
            let appleRuntime: String?
        }
        return try researchDigest(
            Identity(
                base: base, stopwords: canonical(stopwords),
                includedTerms: canonical(includedTerms),
                excludedTerms: canonical(excludedTerms), compounds: canonical(compounds),
                includedPartsOfSpeech: Array(Set(includedPartsOfSpeech)).sorted(),
                appleRuntime: operatingSystemVersion))
    }

    /// Rejects excessive or contradictory dictionaries before tokenization or annotation.
    public func validate() throws {
        for terms in [stopwords, includedTerms, excludedTerms, compounds] {
            guard terms.count <= 10_000,
                terms.allSatisfy({
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && $0.utf8.count <= 4_096
                }), terms.reduce(0, { $0 + $1.utf8.count }) <= 1_048_576
            else { throw researchFailure("research.invalid-preparation") }
        }
        guard compounds.count <= 1_000, includedPartsOfSpeech.count <= 64,
            includedPartsOfSpeech.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }),
            Set(canonical(includedTerms)).isDisjoint(with: canonical(excludedTerms))
        else { throw researchFailure("research.invalid-preparation") }
        for compound in compounds {
            let components = compound.split(whereSeparator: \.isWhitespace)
            guard (2...16).contains(components.count) else {
                throw researchFailure("research.invalid-compound")
            }
            let observed = try GlifiCodingDocument(id: "compound-validation", text: compound)
            guard
                observed.tokens.map({ normalizedTerm($0.surface) })
                    == components.map({ normalizedTerm(String($0)) })
            else { throw researchFailure("research.invalid-compound") }
        }
    }

    /// Produces coding tokens whose ranges still address the exact extracted source text.
    ///
    /// Explicit exclusions win. Inclusions override stopwords and grammatical selection;
    /// they never fabricate absent words. Compounds require observed whitespace-only gaps.
    public func prepare(
        text: String, id: String, variables: [String: String] = [:]
    ) throws -> GlifiCodingDocument {
        try validate()
        try Task.checkCancellation()
        let annotation = try GlifiLinguisticPipeline.annotate(
            text: text, base: base, includePartOfSpeech: !includedPartsOfSpeech.isEmpty,
            limits: GlifiLinguisticLimits(
                maximumTextBytes: 8 * 1_024 * 1_024, maximumTokenCount: 100_000))
        let original = try annotation.codingDocument(id: id, variables: variables)
        let stop = Set(canonical(stopwords))
        let included = Set(canonical(includedTerms))
        let excluded = Set(canonical(excludedTerms))
        let parts = Set(includedPartsOfSpeech)
        var compoundIndex: [String: [[String]]] = [:]
        for compound in canonical(compounds) {
            let components = compound.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let first = components.first else { continue }
            compoundIndex[first, default: []].append(components)
        }
        for key in compoundIndex.keys {
            compoundIndex[key]?.sort {
                $0.count == $1.count
                    ? $0.joined(separator: " ") < $1.joined(separator: " ")
                    : $0.count > $1.count
            }
        }
        let normalized = original.tokens.map { normalizedTerm($0.surface) }
        var output: [GlifiCodingToken] = []
        var index = 0
        var work = 0
        while index < original.tokens.count {
            try Task.checkCancellation()
            let first = original.tokens[index]
            var width = 1
            if let candidates = compoundIndex[normalized[index]] {
                for candidate in candidates where candidate.count <= original.tokens.count - index {
                    work += candidate.count
                    guard work <= 20_000_000 else {
                        throw researchFailure(
                            "research.preparation-work-limit", category: .insufficientResources)
                    }
                    var matches = true
                    for offset in candidate.indices {
                        let token = original.tokens[index + offset]
                        if normalized[index + offset] != candidate[offset]
                            || token.sentence != first.sentence
                            || token.paragraph != first.paragraph
                        {
                            matches = false
                            break
                        }
                        if offset > 0 {
                            let previous = original.tokens[index + offset - 1]
                            if token.range.start > previous.range.end {
                                let gap = try GlifiUTF8Range(
                                    start: previous.range.end, end: token.range.start)
                                guard let gapText = gap.text(in: text),
                                    gapText.allSatisfy(\.isWhitespace)
                                else {
                                    matches = false
                                    break
                                }
                            }
                        }
                    }
                    if matches {
                        width = candidate.count
                        break
                    }
                }
            }
            let selected = original.tokens[index..<(index + width)]
            let normalizedSurface = normalized[index..<(index + width)].joined(separator: " ")
            let selectedBase = selected.map(\.base).joined(separator: " ")
            let baseKey = normalizedTerm(selectedBase)
            let explicitlyExcluded =
                excluded.contains(normalizedSurface) || excluded.contains(baseKey)
            let explicitlyIncluded =
                included.contains(normalizedSurface) || included.contains(baseKey)
            let stopped = stop.contains(normalizedSurface) || stop.contains(baseKey)
            let selectedPOS =
                parts.isEmpty
                || selected.allSatisfy {
                    $0.partOfSpeech.map(parts.contains) == true
                }
            if !explicitlyExcluded && (explicitlyIncluded || (!stopped && selectedPOS)) {
                guard let last = selected.last else {
                    throw researchFailure("research.invalid-preparation")
                }
                let range = try GlifiUTF8Range(start: first.range.start, end: last.range.end)
                guard let surface = range.text(in: text) else {
                    throw researchFailure("research.invalid-preparation")
                }
                let commonPOS =
                    selected.allSatisfy { $0.partOfSpeech == first.partOfSpeech }
                    ? first.partOfSpeech : nil
                output.append(
                    GlifiCodingToken(
                        surface: surface, base: selectedBase, partOfSpeech: commonPOS,
                        range: range, sentence: first.sentence, paragraph: first.paragraph))
            }
            index += width
        }
        let contract =
            isIdentity
            ? original.linguisticContract
            : original.linguisticContract + ";preparation=" + (try digest())
        return try GlifiCodingDocument(
            id: id, text: text, tokens: output, variables: variables, linguisticContract: contract)
    }

    /// Revalidates serialized dictionaries before they can alter a representation.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        base = try fields.decode(GlifiLinguisticBase.self, forKey: .base)
        stopwords = try fields.decode([String].self, forKey: .stopwords)
        includedTerms = try fields.decode([String].self, forKey: .includedTerms)
        excludedTerms = try fields.decode([String].self, forKey: .excludedTerms)
        compounds = try fields.decode([String].self, forKey: .compounds)
        includedPartsOfSpeech = try fields.decode([String].self, forKey: .includedPartsOfSpeech)
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case base, stopwords, includedTerms, excludedTerms, compounds, includedPartsOfSpeech
    }
}

private func normalizedTerm(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping.lowercased(with: Locale(identifier: "it_IT"))
        .split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

private func canonical(_ values: [String]) -> [String] {
    Array(Set(values.map(normalizedTerm))).sorted()
}

/// Bridges prepared bases to the existing analyzers without rewriting observed source text.
package struct GlifiPreparedCorpusTokenizer: GlifiTokenizing {
    package let preparation: GlifiCorpusPreparation
    package let tokenizationContractIdentifier: String
    package var availableQueryFields: [GlifiQueryField] {
        var fields: [GlifiQueryField] = []
        if preparation.base == .appleLemma { fields.append(.lemma) }
        if !preparation.includedPartsOfSpeech.isEmpty { fields.append(.partOfSpeech) }
        return fields
    }

    package init(preparation: GlifiCorpusPreparation) throws {
        self.preparation = preparation
        tokenizationContractIdentifier = "it-token-v1;preparation=" + (try preparation.digest())
    }

    package func tokenize(_ text: String) throws -> GlifiTokenization {
        let observed = try GlifiItalianTokenizer().tokenize(text)
        let prepared = try preparation.prepare(text: text, id: "prepared-corpus-source")
        return GlifiTokenization(
            contractIdentifier: tokenizationContractIdentifier, languageConfiguration: .italian,
            sourceUTF8Length: text.utf8.count,
            tokens: prepared.tokens.map {
                GlifiSurfaceToken(
                    range: $0.range, kind: .word, analysisForm: $0.base,
                    lemma: preparation.base == .appleLemma ? $0.base : nil,
                    partOfSpeech: $0.partOfSpeech)
            }, sentences: observed.sentences, availableQueryFields: availableQueryFields)
    }

    /// A query never loses explicitly written terms because of corpus exclusion filters.
    package func queryTokenization(_ text: String, field: GlifiQueryField) throws
        -> GlifiTokenization
    {
        var lexical = preparation
        lexical.stopwords = []
        lexical.includedTerms = []
        lexical.excludedTerms = []
        lexical.includedPartsOfSpeech = []
        if field != .normalized { lexical.base = .normalizedSurface }
        return try GlifiPreparedCorpusTokenizer(preparation: lexical).tokenize(text)
    }
}

extension GlifiEngine {
    /// Resolves a snapshot of the project preparation while preserving injectable default tokenizers.
    package func researchTokenizer(in project: GlifiProjectPackage) async throws
        -> any GlifiTokenizing
    {
        let preparation = try await project.researchState().preparation
        if preparation.isIdentity { return textTokenizer }
        return try GlifiPreparedCorpusTokenizer(preparation: preparation)
    }
}
