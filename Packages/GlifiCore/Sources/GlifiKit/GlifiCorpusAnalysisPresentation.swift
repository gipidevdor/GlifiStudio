// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Public bounded parameters for a corpus profile requested through GlifiKit.
public struct GlifiStudioCorpusAnalysisOptions: Equatable, Sendable {
    /// Conservative defaults shared by native and headless clients.
    public static let standard = GlifiStudioCorpusAnalysisOptions(.standard)

    let coreValue: GlifiCorpusAnalysisOptions

    /// Number of lexical tokens used by each diversity window.
    public let diversityWindowSize: Int
    /// Canonical set of requested word n-gram sizes.
    public let ngramSizes: [Int]
    /// Largest admitted number of source revisions.
    public let maximumDocumentCount: Int
    /// Largest admitted sum of immutable source bytes.
    public let maximumSourceByteCount: Int
    /// Largest admitted normalized vocabulary.
    public let maximumVocabularySize: Int
    /// Largest admitted set of distinct word n-grams.
    public let maximumDistinctNGramCount: Int
    /// Largest admitted sparse matrix cardinality.
    public let maximumNonZeroCellCount: Int

    /// Creates canonical resource bounds and admits word n-grams of size one through five.
    public init(
        diversityWindowSize: Int,
        ngramSizes: [Int],
        maximumDocumentCount: Int,
        maximumSourceByteCount: Int,
        maximumVocabularySize: Int,
        maximumDistinctNGramCount: Int,
        maximumNonZeroCellCount: Int
    ) throws {
        do {
            self.init(
                try GlifiCorpusAnalysisOptions(
                    diversityWindowSize: diversityWindowSize,
                    ngramSizes: ngramSizes,
                    maximumDocumentCount: maximumDocumentCount,
                    maximumSourceByteCount: maximumSourceByteCount,
                    maximumVocabularySize: maximumVocabularySize,
                    maximumDistinctNGramCount: maximumDistinctNGramCount,
                    maximumNonZeroCellCount: maximumNonZeroCellCount
                )
            )
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        }
    }

    private init(_ value: GlifiCorpusAnalysisOptions) {
        coreValue = value
        diversityWindowSize = value.diversityWindowSize
        ngramSizes = value.ngramSizes
        maximumDocumentCount = value.maximumDocumentCount
        maximumSourceByteCount = value.maximumSourceByteCount
        maximumVocabularySize = value.maximumVocabularySize
        maximumDistinctNGramCount = value.maximumDistinctNGramCount
        maximumNonZeroCellCount = value.maximumNonZeroCellCount
    }
}

/// Versioned lexical-diversity values ready for native or machine clients.
public struct GlifiStudioLexicalDiversity: Codable, Equatable, Sendable {
    /// Canonical ordering and boundary policy applied to the token sequence.
    public let sequencePolicy: String
    /// Number of lexical tokens in each complete or moving window.
    public let windowSize: Int
    /// Exact TTR method variant.
    public let ttrIdentifier: String
    /// Exact MSTTR method variant.
    public let msttrIdentifier: String
    /// Exact MATTR method variant.
    public let mattrIdentifier: String
    /// Type-token ratio, or `nil` when undefined.
    public let ttr: Double?
    /// Mean segmental TTR, or `nil` when no complete window exists.
    public let msttr: Double?
    /// Moving-average TTR, or `nil` when no complete window exists.
    public let mattr: Double?

    init(_ value: GlifiLexicalDiversity) {
        sequencePolicy = value.sequencePolicy
        windowSize = value.windowSize
        ttrIdentifier = value.ttrIdentifier
        msttrIdentifier = value.msttrIdentifier
        mattrIdentifier = value.mattrIdentifier
        ttr = value.ttr
        msttr = value.msttr
        mattr = value.mattr
    }
}

/// Frequency and dispersion values for one normalized term.
public struct GlifiStudioCorpusTerm: Codable, Equatable, Identifiable, Sendable {
    /// Stable row identity derived from the normalized term.
    public var id: String { term }
    /// NFC, Italian-lowercased lexical form.
    public let term: String
    /// Exact number of corpus occurrences.
    public let frequency: Int
    /// Fraction of all included lexical tokens.
    public let relativeFrequency: Double
    /// Number of source revisions containing the term.
    public let documentFrequency: Int
    /// Number of units in the declared partition containing the term.
    public let range: Int
    /// `GriesDP-v1` over source revisions.
    public let griesDP: Double

    init(_ value: GlifiCorpusTermStatistics) {
        term = value.term
        frequency = value.frequency
        relativeFrequency = value.relativeFrequency
        documentFrequency = value.documentFrequency
        range = value.range
        griesDP = value.griesDP
    }
}

/// One word n-gram and its corpus frequency.
public struct GlifiStudioWordNGram: Codable, Equatable, Identifiable, Sendable {
    /// Stable row identity derived from every normalized component.
    public var id: String { values.joined(separator: "\u{1F}") }
    /// Ordered normalized forms in the n-gram.
    public let values: [String]
    /// Exact number of within-document occurrences.
    public let count: Int

    init(_ value: GlifiWordNGram) {
        values = value.values
        count = value.count
    }
}

/// One non-zero coordinate of the sparse document-term matrix.
public struct GlifiStudioSparseTermCell: Codable, Equatable, Sendable {
    /// Zero-based position in the matrix row identities.
    public let rowIndex: Int
    /// Zero-based position in the matrix vocabulary.
    public let columnIndex: Int
    /// Exact observed document-term count.
    public let count: Int
    /// `TF-raw-v1` value.
    public let tfRaw: Double
    /// `TFIDF-v1` value with smoothed inverse document frequency.
    public let tfidfSmooth: Double

    init(_ value: GlifiSparseTermCell) {
        rowIndex = value.rowIndex
        columnIndex = value.columnIndex
        count = value.count
        tfRaw = value.tfRaw
        tfidfSmooth = value.tfidfSmooth
    }
}

/// Canonically ordered sparse matrix with explicit method identities.
public struct GlifiStudioSparseTermMatrix: Codable, Equatable, Sendable {
    /// Semantic unit represented by one row.
    public let unitKind: String
    /// Versioned matrix-count contract.
    public let countIdentifier: String
    /// Versioned term-frequency formula.
    public let tfIdentifier: String
    /// Versioned inverse-document-frequency formula.
    public let idfIdentifier: String
    /// Versioned combined weighting formula.
    public let tfidfIdentifier: String
    /// Canonically ordered source revisions, including empty rows.
    public let rowSourceRevisionIDs: [String]
    /// Lexicographically ordered normalized vocabulary.
    public let terms: [String]
    /// Non-zero coordinates ordered by row and column.
    public let cells: [GlifiStudioSparseTermCell]

    init(_ value: GlifiSparseTermMatrix) {
        unitKind = value.unitKind
        countIdentifier = value.countIdentifier
        tfIdentifier = value.tfIdentifier
        idfIdentifier = value.idfIdentifier
        tfidfIdentifier = value.tfidfIdentifier
        rowSourceRevisionIDs = value.rowSourceRevisionIDs.map(\.canonicalValue)
        terms = value.terms
        cells = value.cells.map(GlifiStudioSparseTermCell.init)
    }
}

/// Complete deterministic corpus profile for one verified project generation.
public struct GlifiStudioCorpusAnalysisResult: Codable, Equatable, Sendable {
    /// Stable project identity.
    public let projectID: String
    /// Exact source generation captured by the operation.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the Artifact.
    public let generation: Int
    /// Immutable persisted Artifact identity.
    public let artifactID: String
    /// Semantic producer identity.
    public let analysisNodeID: String
    /// Versioned aggregate-analysis contract.
    public let analysisIdentifier: String
    /// Digest of semantic inputs, methods, and parameters.
    public let corpusDigest: String
    /// Determinism class for integer counts.
    public let countDeterminismClass: String
    /// Determinism class for floating-point reductions.
    public let floatingPointDeterminismClass: String
    /// Versioned numeric precision and reduction policy.
    public let numericPolicyIdentifier: String
    /// Absolute tolerance applied by the reference seed.
    public let referenceAbsoluteTolerance: Double
    /// Unicode unit used by `characterCount`.
    public let characterUnitIdentifier: String
    /// Linguistic contract shared by all analyzed sources.
    public let tokenizationContractIdentifier: String
    /// Versioned normalization applied to lexical forms.
    public let normalizationIdentifier: String
    /// Boundary and unit contract used by n-grams.
    public let ngramIdentifier: String
    /// Dispersion formula represented by term rows.
    public let dispersionIdentifier: String
    /// Canonically ordered analytical inputs.
    public let sourceRevisionIDs: [String]
    /// Number of source revisions in the selection.
    public let documentCount: Int
    /// Number of extracted extended grapheme clusters.
    public let characterCount: Int
    /// Number of sentence intervals.
    public let sentenceCount: Int
    /// Number of tokens included in lexical statistics.
    public let lexicalTokenCount: Int
    /// Number of distinct normalized lexical forms.
    public let typeCount: Int
    /// Complete term statistics in deterministic order.
    public let terms: [GlifiStudioCorpusTerm]
    /// Versioned lexical-diversity values.
    public let diversity: GlifiStudioLexicalDiversity
    /// Complete bounded word n-grams.
    public let ngrams: [GlifiStudioWordNGram]
    /// Sparse document-term count and weighting representation.
    public let matrix: GlifiStudioSparseTermMatrix

    init(_ result: GlifiProjectCorpusAnalysisResult) {
        let analysis = result.analysis
        projectID = result.projectID.canonicalValue
        sourceGeneration = result.sourceGeneration
        generation = result.generation
        artifactID = result.artifactID.canonicalValue
        analysisNodeID = result.analysisNodeID.canonicalValue
        analysisIdentifier = analysis.analysisIdentifier
        corpusDigest = analysis.corpusDigest
        countDeterminismClass = analysis.countDeterminismClass
        floatingPointDeterminismClass = analysis.floatingPointDeterminismClass
        numericPolicyIdentifier = analysis.numericPolicyIdentifier
        referenceAbsoluteTolerance = analysis.referenceAbsoluteTolerance
        characterUnitIdentifier = analysis.characterUnitIdentifier
        tokenizationContractIdentifier = analysis.tokenizationContractIdentifier
        normalizationIdentifier = analysis.normalizationIdentifier
        ngramIdentifier = analysis.ngramIdentifier
        dispersionIdentifier = analysis.dispersionIdentifier
        sourceRevisionIDs = analysis.sourceRevisionIDs.map(\.canonicalValue)
        documentCount = analysis.documentCount
        characterCount = analysis.characterCount
        sentenceCount = analysis.sentenceCount
        lexicalTokenCount = analysis.lexicalTokenCount
        typeCount = analysis.typeCount
        terms = analysis.terms.map(GlifiStudioCorpusTerm.init)
        diversity = GlifiStudioLexicalDiversity(analysis.diversity)
        ngrams = analysis.ngrams.map(GlifiStudioWordNGram.init)
        matrix = GlifiStudioSparseTermMatrix(analysis.matrix)
    }
}
