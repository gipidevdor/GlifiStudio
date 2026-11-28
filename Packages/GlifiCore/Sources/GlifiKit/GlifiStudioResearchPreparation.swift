// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Persistent Italian lexical settings shared by corpus analysis and research tools.
public struct GlifiStudioCorpusPreparation: Codable, Equatable, Sendable {
    /// Explicit normalized-surface, Italian lemma or stemming view.
    public var base: GlifiStudioLinguisticBase
    /// Explicit lexical forms excluded unless included by the user.
    public var stopwords: [String]
    /// Observed terms retained across stopword and grammatical filtering.
    public var includedTerms: [String]
    /// Observed terms explicitly excluded from prepared representations.
    public var excludedTerms: [String]
    /// Observed whitespace-separated expressions retained as lexical units.
    public var compounds: [String]
    /// Raw Apple lexical classes admitted by grammatical filtering.
    public var includedPartsOfSpeech: [String]

    /// Creates explicit research data for validation by the project writer.
    public init(
        base: GlifiStudioLinguisticBase = .normalizedSurface, stopwords: [String] = [],
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

    /// Whether the existing normalized-surface representation remains unchanged.
    public var isIdentity: Bool { (try? core().isIdentity) == true }

    /// Canonical identity of dictionaries, lexical base and the applicable linguistic backend.
    public func digest() throws(GlifiStudioFailure) -> String {
        try researchPresentationOperation { try core().digest() }
    }

    /// Admits dictionaries before an application can submit a persistent state.
    public func validate() throws(GlifiStudioFailure) {
        try researchPresentationOperation { try core().validate() }
    }

    package func core() throws -> GlifiCorpusPreparation {
        guard let base = GlifiLinguisticBase(rawValue: base.rawValue) else {
            throw researchFailure("research.invalid-preparation")
        }
        let configuration = GlifiCorpusPreparation(
            base: base, stopwords: stopwords, includedTerms: includedTerms,
            excludedTerms: excludedTerms, compounds: compounds,
            includedPartsOfSpeech: includedPartsOfSpeech)
        try configuration.validate()
        return configuration
    }

    /// Decoded dictionaries obey the same bounds and conflict rules as native editors.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        base = try fields.decode(GlifiStudioLinguisticBase.self, forKey: .base)
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
