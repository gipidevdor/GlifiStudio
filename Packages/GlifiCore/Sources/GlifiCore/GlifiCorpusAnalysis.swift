// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Bounded parameters of the deterministic corpus-profile slice.
public struct GlifiCorpusAnalysisOptions: Equatable, Sendable {
    /// Default parameters for the 0.1 analytical seed.
    public static let standard = GlifiCorpusAnalysisOptions(
        validatedDiversityWindowSize: 100,
        ngramSizes: [2, 3],
        maximumDocumentCount: 1_000,
        maximumSourceByteCount: 256 * 1_024 * 1_024,
        maximumVocabularySize: 100_000,
        maximumDistinctNGramCount: 100_000,
        maximumNonZeroCellCount: 500_000
    )

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

    /// Creates canonical non-negative bounds or rejects invalid analytical parameters.
    public init(
        diversityWindowSize: Int,
        ngramSizes: [Int],
        maximumDocumentCount: Int,
        maximumSourceByteCount: Int,
        maximumVocabularySize: Int,
        maximumDistinctNGramCount: Int,
        maximumNonZeroCellCount: Int
    ) throws {
        guard diversityWindowSize > 0,
            ngramSizes.allSatisfy({ (1...5).contains($0) }),
            Set(ngramSizes).count == ngramSizes.count,
            maximumDocumentCount >= 0,
            maximumSourceByteCount >= 0,
            maximumVocabularySize >= 0,
            maximumDistinctNGramCount >= 0,
            maximumNonZeroCellCount >= 0
        else {
            throw GlifiFailure(
                code: "analysis.invalid-options",
                category: .invalidInput,
                operation: .analyze,
                retryDisposition: .afterCorrection,
                retainedState: .lastCommittedGeneration,
                messageKey: "failure.analysis.invalid-options"
            )
        }
        self.init(
            validatedDiversityWindowSize: diversityWindowSize,
            ngramSizes: ngramSizes.sorted(),
            maximumDocumentCount: maximumDocumentCount,
            maximumSourceByteCount: maximumSourceByteCount,
            maximumVocabularySize: maximumVocabularySize,
            maximumDistinctNGramCount: maximumDistinctNGramCount,
            maximumNonZeroCellCount: maximumNonZeroCellCount
        )
    }

    private init(
        validatedDiversityWindowSize: Int,
        ngramSizes: [Int],
        maximumDocumentCount: Int,
        maximumSourceByteCount: Int,
        maximumVocabularySize: Int,
        maximumDistinctNGramCount: Int,
        maximumNonZeroCellCount: Int
    ) {
        diversityWindowSize = validatedDiversityWindowSize
        self.ngramSizes = ngramSizes
        self.maximumDocumentCount = maximumDocumentCount
        self.maximumSourceByteCount = maximumSourceByteCount
        self.maximumVocabularySize = maximumVocabularySize
        self.maximumDistinctNGramCount = maximumDistinctNGramCount
        self.maximumNonZeroCellCount = maximumNonZeroCellCount
    }
}

/// Lexical diversity values with explicit sequence and window contracts.
public struct GlifiLexicalDiversity: Codable, Equatable, Sendable {
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
    /// Type-token ratio, or `nil` when the corpus has no lexical tokens.
    public let ttr: Double?
    /// Mean segmental TTR, or `nil` when no complete window exists.
    public let msttr: Double?
    /// Moving-average TTR, or `nil` when no complete window exists.
    public let mattr: Double?
}

/// Frequency, range, and dispersion of one normalized term.
public struct GlifiCorpusTermStatistics: Codable, Equatable, Sendable {
    /// NFC, Italian-lowercased lexical form.
    public let term: String
    /// Exact number of occurrences across the selected revisions.
    public let frequency: Int
    /// `frequency / lexicalTokenCount`.
    public let relativeFrequency: Double
    /// Number of source revisions containing this term.
    public let documentFrequency: Int
    /// Number of units in the declared partition containing this term.
    public let range: Int
    /// `GriesDP-v1` over the source-revision partition.
    public let griesDP: Double
}

/// One word n-gram row ordered by frequency and then lexical value.
public struct GlifiWordNGram: Codable, Equatable, Sendable {
    /// Ordered normalized forms in the n-gram.
    public let values: [String]
    /// Exact number of occurrences that do not cross document boundaries.
    public let count: Int
}

/// One non-zero document-term cell and its versioned weights.
public struct GlifiSparseTermCell: Codable, Equatable, Sendable {
    /// Zero-based index into the matrix row identities.
    public let rowIndex: Int
    /// Zero-based index into the matrix vocabulary.
    public let columnIndex: Int
    /// Exact observed document-term count.
    public let count: Int
    /// `TF-raw-v1` value.
    public let tfRaw: Double
    /// `TFIDF-v1` value using `TF-raw-v1` and `IDF-smooth-v1`.
    public let tfidfSmooth: Double
}

/// Canonically ordered sparse document-term matrix.
public struct GlifiSparseTermMatrix: Codable, Equatable, Sendable {
    /// Semantic unit represented by each row.
    public let unitKind: String
    /// Versioned matrix-count contract.
    public let countIdentifier: String
    /// Versioned term-frequency formula.
    public let tfIdentifier: String
    /// Versioned inverse-document-frequency formula.
    public let idfIdentifier: String
    /// Versioned combined weighting formula.
    public let tfidfIdentifier: String
    /// Canonically ordered identity of every row, including empty rows.
    public let rowSourceRevisionIDs: [SourceRevisionID]
    /// Lexicographically ordered normalized vocabulary.
    public let terms: [String]
    /// Non-zero cells ordered by row and then column.
    public let cells: [GlifiSparseTermCell]
}

/// Deterministic analytical profile of a bounded immutable source selection.
public struct GlifiCorpusAnalysis: Codable, Equatable, Sendable {
    /// Versioned aggregate-analysis contract.
    public let analysisIdentifier: String
    /// Digest of semantic inputs, method identities, and resolved parameters.
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
    /// Linguistic contract shared by every analyzed source.
    public let tokenizationContractIdentifier: String
    /// Normalization applied to build lexical forms.
    public let normalizationIdentifier: String
    /// Boundary and unit contract of `ngrams`.
    public let ngramIdentifier: String
    /// Dispersion variant represented by each term row.
    public let dispersionIdentifier: String
    /// Canonically ordered immutable analytical inputs.
    public let sourceRevisionIDs: [SourceRevisionID]
    /// Number of source revisions in the selection.
    public let documentCount: Int
    /// Number of extracted extended grapheme clusters.
    public let characterCount: Int
    /// Number of sentence intervals emitted by the linguistic contract.
    public let sentenceCount: Int
    /// Number of surface tokens admitted to lexical statistics.
    public let lexicalTokenCount: Int
    /// Number of distinct normalized lexical forms.
    public let typeCount: Int
    /// Complete term rows ordered by frequency and then lexical form.
    public let terms: [GlifiCorpusTermStatistics]
    /// Versioned lexical-diversity values.
    public let diversity: GlifiLexicalDiversity
    /// Complete bounded n-gram rows in deterministic order.
    public let ngrams: [GlifiWordNGram]
    /// Sparse document-term count and weighting representation.
    public let matrix: GlifiSparseTermMatrix
}

/// Computes the first D0/D1 corpus profile without presentation or persistence coupling.
public struct GlifiCorpusAnalyzer: Sendable {
    /// Versioned identity of the first Italian corpus-profile implementation.
    public static let analysisIdentifier = "corpus-profile-it-v1"

    private let tokenizer: any GlifiTokenizing

    /// Creates an analyzer with an injectable versioned linguistic service.
    public init(tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()) {
        self.tokenizer = tokenizer
    }

    /// Computes a deterministic corpus profile or fails at a declared bound.
    public func analyze(
        _ sources: [GlifiImportedText],
        options: GlifiCorpusAnalysisOptions = .standard
    ) throws -> GlifiCorpusAnalysis {
        let orderedSources = sources.sorted {
            $0.sourceRevisionID.canonicalValue < $1.sourceRevisionID.canonicalValue
        }
        try validateCorpusSelection(
            documentByteCounts: orderedSources.map(\.bytes.count),
            options: options
        )

        var documents: [[String]] = []
        documents.reserveCapacity(orderedSources.count)
        var characterCount = 0
        var sentenceCount = 0
        var vocabulary: Set<String> = []
        var tokenizationContractIdentifier: String?
        let locale = Locale(identifier: "it_IT")

        for (sourceIndex, source) in orderedSources.enumerated() {
            if sourceIndex.isMultiple(of: 32) { try Task.checkCancellation() }
            let tokenization = try tokenizer.tokenize(source.text)
            if let expectedContract = tokenizationContractIdentifier {
                guard tokenization.contractIdentifier == expectedContract else {
                    throw analysisFailure(
                        "analysis.mixed-tokenization-contracts",
                        category: .invariantViolation
                    )
                }
            } else {
                tokenizationContractIdentifier = tokenization.contractIdentifier
            }
            var terms: [String] = []
            terms.reserveCapacity(tokenization.tokens.count)
            for (tokenIndex, token) in tokenization.tokens.enumerated() {
                if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
                guard token.kind.contributesToLexicalStatistics,
                    let surface = token.range.text(in: source.text)
                else {
                    continue
                }
                let normalized =
                    surface.precomposedStringWithCanonicalMapping.lowercased(with: locale)
                terms.append(normalized)
                vocabulary.insert(normalized)
                guard vocabulary.count <= options.maximumVocabularySize else {
                    throw analysisFailure("analysis.vocabulary-limit-exceeded")
                }
            }
            documents.append(terms)
            characterCount += source.text.count
            sentenceCount += tokenization.sentences.count
        }

        let orderedTerms = vocabulary.sorted()
        let termIndex = Dictionary(
            uniqueKeysWithValues: orderedTerms.enumerated().map {
                ($0.element, $0.offset)
            })
        var perDocumentCounts: [[String: Int]] = []
        perDocumentCounts.reserveCapacity(documents.count)
        var totalCounts: [String: Int] = [:]
        var documentFrequency: [String: Int] = [:]
        var lexicalTokenCount = 0

        for document in documents {
            var counts: [String: Int] = [:]
            for (tokenIndex, term) in document.enumerated() {
                if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
                counts[term, default: 0] += 1
            }
            perDocumentCounts.append(counts)
            lexicalTokenCount += document.count
            for (term, count) in counts {
                totalCounts[term, default: 0] += count
                documentFrequency[term, default: 0] += 1
            }
        }

        let documentLengths = documents.map(\.count)
        var termStatistics: [GlifiCorpusTermStatistics] = []
        termStatistics.reserveCapacity(orderedTerms.count)
        for (termPosition, term) in orderedTerms.enumerated() {
            if termPosition.isMultiple(of: 4_096) { try Task.checkCancellation() }
            let frequency = totalCounts[term, default: 0]
            let frequencies = perDocumentCounts.map { $0[term, default: 0] }
            let range = frequencies.reduce(into: 0) { count, value in
                if value > 0 { count += 1 }
            }
            let relativeFrequency =
                lexicalTokenCount == 0
                ? 0 : Double(frequency) / Double(lexicalTokenCount)
            termStatistics.append(
                GlifiCorpusTermStatistics(
                    term: term,
                    frequency: frequency,
                    relativeFrequency: relativeFrequency,
                    documentFrequency: documentFrequency[term, default: 0],
                    range: range,
                    griesDP: griesDP(
                        frequencies: frequencies,
                        documentLengths: documentLengths,
                        totalFrequency: frequency,
                        totalTokens: lexicalTokenCount
                    )
                )
            )
        }
        termStatistics.sort {
            $0.frequency == $1.frequency ? $0.term < $1.term : $0.frequency > $1.frequency
        }

        var sequence: [String] = []
        sequence.reserveCapacity(lexicalTokenCount)
        for document in documents {
            for (tokenIndex, term) in document.enumerated() {
                if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
                sequence.append(term)
            }
        }
        let diversity = GlifiLexicalDiversity(
            sequencePolicy: "source-revision-order-concatenation-v1",
            windowSize: options.diversityWindowSize,
            ttrIdentifier: "TTR-v1",
            msttrIdentifier: "MSTTR-v1",
            mattrIdentifier: "MATTR-v1",
            ttr: sequence.isEmpty ? nil : Double(vocabulary.count) / Double(sequence.count),
            msttr: try msttr(sequence, windowSize: options.diversityWindowSize),
            mattr: try mattr(sequence, windowSize: options.diversityWindowSize)
        )
        let ngrams = try wordNGrams(documents, options: options)
        let matrix = try sparseMatrix(
            sourceRevisionIDs: orderedSources.map(\.sourceRevisionID),
            orderedTerms: orderedTerms,
            termIndex: termIndex,
            counts: perDocumentCounts,
            documentFrequency: documentFrequency,
            maximumCellCount: options.maximumNonZeroCellCount
        )

        return GlifiCorpusAnalysis(
            analysisIdentifier: Self.analysisIdentifier,
            corpusDigest: try corpusDigest(
                orderedSources,
                options: options,
                tokenizationContractIdentifier: tokenizationContractIdentifier ?? "unavailable"
            ),
            countDeterminismClass: "D0",
            floatingPointDeterminismClass: "D1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            referenceAbsoluteTolerance: 1e-12,
            characterUnitIdentifier: "unicode-extended-grapheme-cluster-v1",
            tokenizationContractIdentifier: tokenizationContractIdentifier ?? "unavailable",
            normalizationIdentifier: "nfc-lowercase-it-v1",
            ngramIdentifier: "word-ngram-document-bounded-v1",
            dispersionIdentifier: "GriesDP-v1",
            sourceRevisionIDs: orderedSources.map(\.sourceRevisionID),
            documentCount: orderedSources.count,
            characterCount: characterCount,
            sentenceCount: sentenceCount,
            lexicalTokenCount: lexicalTokenCount,
            typeCount: vocabulary.count,
            terms: termStatistics,
            diversity: diversity,
            ngrams: ngrams,
            matrix: matrix
        )
    }

    private func griesDP(
        frequencies: [Int],
        documentLengths: [Int],
        totalFrequency: Int,
        totalTokens: Int
    ) -> Double {
        guard totalFrequency > 0, totalTokens > 0 else { return 0 }
        return 0.5
            * zip(frequencies, documentLengths).reduce(0.0) { result, pair in
                result
                    + abs(
                        Double(pair.0) / Double(totalFrequency)
                            - Double(pair.1) / Double(totalTokens)
                    )
            }
    }

    private func msttr(_ sequence: [String], windowSize: Int) throws -> Double? {
        guard sequence.count >= windowSize else { return nil }
        var total = 0.0
        var windowCount = 0
        var start = 0
        while start + windowSize <= sequence.count {
            if start.isMultiple(of: 4_096) { try Task.checkCancellation() }
            total += Double(Set(sequence[start..<(start + windowSize)]).count) / Double(windowSize)
            windowCount += 1
            start += windowSize
        }
        return total / Double(windowCount)
    }

    private func mattr(_ sequence: [String], windowSize: Int) throws -> Double? {
        guard sequence.count >= windowSize else { return nil }
        var counts: [String: Int] = [:]
        for term in sequence.prefix(windowSize) { counts[term, default: 0] += 1 }
        var total = Double(counts.count) / Double(windowSize)
        guard sequence.count > windowSize else { return total }
        for start in 1...(sequence.count - windowSize) {
            if start.isMultiple(of: 4_096) { try Task.checkCancellation() }
            let removed = sequence[start - 1]
            if counts[removed] == 1 {
                counts.removeValue(forKey: removed)
            } else {
                counts[removed, default: 0] -= 1
            }
            counts[sequence[start + windowSize - 1], default: 0] += 1
            total += Double(counts.count) / Double(windowSize)
        }
        return total / Double(sequence.count - windowSize + 1)
    }

    private func wordNGrams(
        _ documents: [[String]],
        options: GlifiCorpusAnalysisOptions
    ) throws -> [GlifiWordNGram] {
        var counts: [[String]: Int] = [:]
        for document in documents {
            for size in options.ngramSizes where document.count >= size {
                for start in 0...(document.count - size) {
                    if start.isMultiple(of: 4_096) { try Task.checkCancellation() }
                    let values = Array(document[start..<(start + size)])
                    if counts[values] == nil,
                        counts.count >= options.maximumDistinctNGramCount
                    {
                        throw analysisFailure("analysis.ngram-limit-exceeded")
                    }
                    counts[values, default: 0] += 1
                }
            }
        }
        return counts.map(GlifiWordNGram.init(values:count:)).sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.values.lexicographicallyPrecedes($1.values)
        }
    }

    private func sparseMatrix(
        sourceRevisionIDs: [SourceRevisionID],
        orderedTerms: [String],
        termIndex: [String: Int],
        counts: [[String: Int]],
        documentFrequency: [String: Int],
        maximumCellCount: Int
    ) throws -> GlifiSparseTermMatrix {
        var cells: [GlifiSparseTermCell] = []
        for (rowIndex, row) in counts.enumerated() {
            guard cells.count <= maximumCellCount,
                row.count <= maximumCellCount - cells.count
            else {
                throw analysisFailure("analysis.matrix-limit-exceeded")
            }
            for (cellPosition, cell) in row.sorted(by: { $0.key < $1.key }).enumerated() {
                if cellPosition.isMultiple(of: 4_096) { try Task.checkCancellation() }
                let (term, count) = cell
                guard let columnIndex = termIndex[term] else {
                    throw analysisFailure(
                        "analysis.matrix-invariant", category: .invariantViolation)
                }
                let idf =
                    log(
                        Double(counts.count + 1)
                            / Double(documentFrequency[term, default: 0] + 1)
                    ) + 1
                cells.append(
                    GlifiSparseTermCell(
                        rowIndex: rowIndex,
                        columnIndex: columnIndex,
                        count: count,
                        tfRaw: Double(count),
                        tfidfSmooth: Double(count) * idf
                    )
                )
            }
        }
        return GlifiSparseTermMatrix(
            unitKind: "sourceRevision",
            countIdentifier: "document-term-count-v1",
            tfIdentifier: "TF-raw-v1",
            idfIdentifier: "IDF-smooth-v1",
            tfidfIdentifier: "TFIDF-v1",
            rowSourceRevisionIDs: sourceRevisionIDs,
            terms: orderedTerms,
            cells: cells
        )
    }

    private func corpusDigest(
        _ sources: [GlifiImportedText],
        options: GlifiCorpusAnalysisOptions,
        tokenizationContractIdentifier: String
    ) throws -> String {
        struct DigestInput: Encodable {
            let analysisIdentifier: String
            let tokenizationContractIdentifier: String
            let normalizationIdentifier: String
            let numericPolicyIdentifier: String
            let sequencePolicy: String
            let diversityWindowSize: Int
            let ngramSizes: [Int]
            let sources: [DigestSource]
        }
        struct DigestSource: Encodable {
            let sourceRevisionID: String
            let contentDigest: String
            let extractionContractIdentifier: String
        }
        let value = DigestInput(
            analysisIdentifier: Self.analysisIdentifier,
            tokenizationContractIdentifier: tokenizationContractIdentifier,
            normalizationIdentifier: "nfc-lowercase-it-v1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            sequencePolicy: "source-revision-order-concatenation-v1",
            diversityWindowSize: options.diversityWindowSize,
            ngramSizes: options.ngramSizes,
            sources: sources.map {
                DigestSource(
                    sourceRevisionID: $0.sourceRevisionID.canonicalValue,
                    contentDigest: $0.contentDigest,
                    extractionContractIdentifier: $0.extractionContractIdentifier
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let hash = SHA256.hash(data: try encoder.encode(value))
        return "sha256:" + hash.map { String(format: "%02x", $0) }.joined()
    }
}

func validateCorpusSelection(
    documentByteCounts: [Int],
    options: GlifiCorpusAnalysisOptions
) throws {
    guard !documentByteCounts.isEmpty else {
        throw analysisFailure("analysis.empty-selection", category: .insufficientData)
    }
    guard documentByteCounts.count <= options.maximumDocumentCount else {
        throw analysisFailure("analysis.document-limit-exceeded")
    }
    var sourceByteCount = 0
    for byteCount in documentByteCounts {
        guard byteCount >= 0,
            sourceByteCount <= options.maximumSourceByteCount,
            byteCount <= options.maximumSourceByteCount - sourceByteCount
        else {
            throw analysisFailure("analysis.byte-limit-exceeded")
        }
        sourceByteCount += byteCount
    }
}

func analysisFailure(
    _ code: String,
    category: GlifiFailureCategory = .insufficientResources
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}
