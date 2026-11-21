// SPDX-License-Identifier: BSD-3-Clause

import Foundation

// Ponderazione dei termini e BM25 secondo GS-MET-001-07: ogni formula ha un
// identificatore versionato e nessuna variante è implicita.

/// Term-frequency variant of GS-MET-001-07.
public enum GlifiTermFrequencyVariant: String, Codable, CaseIterable, Sendable {
    /// `tf(x)=x`.
    case raw = "TF-raw-v1"
    /// `tf(x)=1` for `x>0`.
    case binary = "TF-binary-v1"
    /// `tf(x)=x/Σ_j x_dj`.
    case l1 = "TF-L1-v1"
    /// `tf(x)=x/max_j x_dj`.
    case max = "TF-max-v1"
    /// `0.5+0.5x/max_j x_dj` for `x>0`.
    case augmented = "TF-augmented-v1"
    /// `1+ln(x)` for `x>0`.
    case sublinear = "TF-sublinear-v1"
}

/// Inverse-document-frequency variant of GS-MET-001-07.
public enum GlifiInverseDocumentFrequencyVariant: String, Codable, CaseIterable, Sendable {
    /// No IDF factor: the weight is the term frequency.
    case none = "IDF-none-v1"
    /// `ln(N/df)`, defined for `0<df≤N`.
    case unsmoothed = "IDF-unsmoothed-v1"
    /// `ln((N+1)/(df+1))+1`.
    case smooth = "IDF-smooth-v1"
}

/// Row normalization applied after TF×IDF, versioned separately.
public enum GlifiRowNormalization: String, Codable, CaseIterable, Sendable {
    /// No normalization.
    case none = "RowNorm-none-v1"
    /// Division by the sum of absolute weights of the row.
    case l1 = "RowNorm-L1-v1"
    /// Division by the Euclidean norm of the row.
    case l2 = "RowNorm-L2-v1"
}

/// Declared weighting scheme.
public struct GlifiTermWeightingScheme: Codable, Equatable, Hashable, Sendable {
    /// Term-frequency variant.
    public let termFrequency: GlifiTermFrequencyVariant
    /// Inverse-document-frequency variant.
    public let inverseDocumentFrequency: GlifiInverseDocumentFrequencyVariant
    /// Row normalization.
    public let normalization: GlifiRowNormalization

    /// Creates a scheme with every variant explicit.
    public init(
        termFrequency: GlifiTermFrequencyVariant,
        inverseDocumentFrequency: GlifiInverseDocumentFrequencyVariant,
        normalization: GlifiRowNormalization
    ) {
        self.termFrequency = termFrequency
        self.inverseDocumentFrequency = inverseDocumentFrequency
        self.normalization = normalization
    }

    /// Combined weighting identity: `TFIDF-v1` when an IDF applies.
    public var combinedIdentifier: String {
        inverseDocumentFrequency == .none ? termFrequency.rawValue : "TFIDF-v1"
    }
}

/// `BM25-v1` parameters, resolved in the descriptor.
public struct GlifiBM25Parameters: Codable, Equatable, Hashable, Sendable {
    /// Robertson–Zaragoza candidate values `k1=1.2`, `b=0.75`.
    public static let standard = GlifiBM25Parameters(k1: 1.2, b: 0.75)

    /// Term-frequency saturation, `k1>0`.
    public let k1: Double
    /// Length normalization, `0≤b≤1`.
    public let b: Double

    /// Creates parameters; validation happens where they are used.
    public init(k1: Double, b: Double) {
        self.k1 = k1
        self.b = b
    }
}

/// Pure implementations of the GS-MET-001-07 formulas over sparse rows.
public enum GlifiTermWeighting {
    /// Maximum columns admitted by the dense document-frequency cache of `weigh`.
    public static let maximumWeightingColumnCount = 1_000_000

    /// Term frequency of one cell given its row sum and row maximum.
    public static func termFrequency(
        _ count: Int,
        rowSum: Int,
        rowMaximum: Int,
        variant: GlifiTermFrequencyVariant
    ) -> Double {
        guard count > 0 else {
            return 0
        }
        let x = Double(count)
        switch variant {
        case .raw: return x
        case .binary: return 1
        case .l1: return x / Double(rowSum)
        case .max: return x / Double(rowMaximum)
        case .augmented: return 0.5 + 0.5 * x / Double(rowMaximum)
        case .sublinear: return 1 + log(x)
        }
    }

    /// Inverse document frequency for `documentCount` units and document frequency `df`.
    public static func inverseDocumentFrequency(
        documentFrequency df: Int,
        documentCount: Int,
        variant: GlifiInverseDocumentFrequencyVariant
    ) throws -> Double {
        guard documentCount > 0, df >= 0, df <= documentCount else {
            throw weightingFailure("weighting.invalid-document-frequency")
        }
        switch variant {
        case .none:
            return 1
        case .unsmoothed:
            guard df > 0 else {
                throw weightingFailure("weighting.unobserved-term")
            }
            return log(Double(documentCount) / Double(df))
        case .smooth:
            let numerator =
                documentCount == Int.max ? Double(documentCount) + 1 : Double(documentCount + 1)
            let denominator = df == Int.max ? Double(df) + 1 : Double(df + 1)
            return log(numerator / denominator) + 1
        }
    }

    /// Weighted sparse rows: `rows[d]` maps a column to its count.
    public static func weigh(
        rows: [[Int: Int]],
        columnCount: Int,
        scheme: GlifiTermWeightingScheme
    ) throws -> [[Int: Double]] {
        try Task.checkCancellation()
        guard columnCount >= 0 else { throw weightingFailure("weighting.invalid-column") }
        guard columnCount <= maximumWeightingColumnCount else {
            throw derivedAnalysisFailure("weighting.column-limit", category: .insufficientResources)
        }
        var documentFrequency = [Int](repeating: 0, count: columnCount)
        var statistics: [(sum: Int, maximum: Int, positiveCount: Int)] = []
        statistics.reserveCapacity(rows.count)
        for (rowIndex, row) in rows.enumerated() {
            if rowIndex.isMultiple(of: 256) { try Task.checkCancellation() }
            var sum = 0
            var maximum = 0
            var positiveCount = 0
            for (column, count) in row {
                guard count >= 0 else { throw weightingFailure("weighting.negative-count") }
                guard count > 0 else { continue }
                guard column >= 0, column < columnCount else {
                    throw weightingFailure("weighting.invalid-column")
                }
                let addition = sum.addingReportingOverflow(count)
                guard !addition.overflow else { throw weightingFailure("weighting.count-overflow") }
                sum = addition.partialValue
                maximum = max(maximum, count)
                positiveCount += 1
                documentFrequency[column] += 1
            }
            statistics.append((sum, maximum, positiveCount))
        }
        let idf = try documentFrequency.map {
            try inverseDocumentFrequency(
                documentFrequency: $0, documentCount: rows.count,
                variant: scheme.inverseDocumentFrequency)
        }
        return try rows.enumerated().map { rowIndex, row in
            if rowIndex.isMultiple(of: 256) { try Task.checkCancellation() }
            let rowStatistics = statistics[rowIndex]
            var weighted: [Int: Double] = [:]
            weighted.reserveCapacity(rowStatistics.positiveCount)
            func weight(_ count: Int, column: Int) -> Double {
                termFrequency(
                    count, rowSum: rowStatistics.sum, rowMaximum: rowStatistics.maximum,
                    variant: scheme.termFrequency) * idf[column]
            }
            // Unnormalized rows need no ordering or temporary filtered dictionary.
            guard scheme.normalization != .none else {
                for (column, count) in row where count > 0 {
                    weighted[column] = weight(count, column: column)
                }
                return weighted
            }
            let entries = row.compactMap { column, count in
                count > 0 ? (column: column, count: count) : nil
            }.sorted { $0.column < $1.column }
            var norm = 0.0
            for (column, count) in entries {
                let value = weight(count, column: column)
                weighted[column] = value
                switch scheme.normalization {
                case .none: break
                case .l1: norm += abs(value)
                case .l2: norm += value * value
                }
            }
            if scheme.normalization == .l2 { norm = norm.squareRoot() }
            guard norm > 0 else { return weighted }
            return weighted.mapValues { $0 / norm }
        }
    }

    /// `BM25-v1` idf: `ln(1+(N−df+0.5)/(df+0.5))`.
    public static func bm25InverseDocumentFrequency(
        documentFrequency df: Int, documentCount: Int
    ) -> Double {
        log(1 + (Double(documentCount - df) + 0.5) / (Double(df) + 0.5))
    }

    /// `BM25-v1` score of each row for the unique query columns.
    ///
    /// Columns outside `0..<columnCount` are out-of-vocabulary terms and contribute zero.
    public static func bm25(
        rows: [[Int: Int]],
        columnCount: Int,
        documentLengths: [Int],
        queryColumns: Set<Int>,
        parameters: GlifiBM25Parameters
    ) throws -> [Double] {
        try bm25(
            rows: rows, columnCount: columnCount, documentLengths: documentLengths,
            queryColumns: queryColumns, parameters: parameters, postingsPolicy: .standard)
    }

    // The allocation policy is internal so tests can exercise bounded fallback without
    // changing the public API or constructing a million-hit fixture.
    static func bm25(
        rows: [[Int: Int]], columnCount: Int, documentLengths: [Int], queryColumns: Set<Int>,
        parameters: GlifiBM25Parameters, postingsPolicy: GlifiBM25PostingsPolicy
    ) throws -> [Double] {
        guard !rows.isEmpty, documentLengths.count == rows.count else {
            throw weightingFailure("bm25.empty-collection")
        }
        guard columnCount >= 0 else { throw weightingFailure("bm25.invalid-column") }
        guard parameters.k1 > 0, parameters.k1.isFinite, parameters.b >= 0, parameters.b <= 1
        else {
            throw weightingFailure("bm25.invalid-parameters")
        }
        try Task.checkCancellation()
        var totalLength = 0
        for (index, length) in documentLengths.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            guard length >= 0 else { throw weightingFailure("bm25.invalid-document-length") }
            let addition = totalLength.addingReportingOverflow(length)
            guard !addition.overflow else { throw weightingFailure("bm25.length-overflow") }
            totalLength = addition.partialValue
        }
        let averageLength = Double(totalLength) / Double(documentLengths.count)
        guard averageLength > 0 else { throw weightingFailure("bm25.empty-collection") }
        let columns = queryColumns.filter { $0 >= 0 && $0 < columnCount }.sorted()
        let lengthFactors = documentLengths.map {
            1 - parameters.b + parameters.b * Double($0) / averageLength
        }
        let postings: GlifiBM25QueryPostings?
        if columns.count >= 128 {
            postings = try GlifiBM25QueryPostings.build(
                rows: rows, columns: columns, policy: postingsPolicy)
        } else {
            postings = nil
        }
        guard let postings else {
            return try bm25Direct(
                rows: rows, columns: columns, lengthFactors: lengthFactors, parameters: parameters)
        }
        var scores = [Double](repeating: 0, count: rows.count)
        for position in columns.indices {
            try Task.checkCancellation()
            let start = postings.offsets[position]
            let end = postings.offsets[position + 1]
            let idf = bm25InverseDocumentFrequency(
                documentFrequency: end - start, documentCount: rows.count)
            for posting in start..<end {
                if posting.isMultiple(of: 256) { try Task.checkCancellation() }
                let row = postings.rowIndices[posting]
                scores[row] += bm25Contribution(
                    frequency: postings.frequencies[posting], idf: idf,
                    lengthFactor: lengthFactors[row], parameters: parameters)
            }
        }
        guard scores.allSatisfy(\.isFinite) else { throw weightingFailure("bm25.non-finite-score") }
        try Task.checkCancellation()
        return scores
    }

    private static func bm25Direct(
        rows: [[Int: Int]], columns: [Int], lengthFactors: [Double],
        parameters: GlifiBM25Parameters
    ) throws -> [Double] {
        var frequencies = [Int](repeating: 0, count: rows.count)
        var scores = [Double](repeating: 0, count: rows.count)
        for column in columns {
            try Task.checkCancellation()
            var documentFrequency = 0
            for (index, row) in rows.enumerated() {
                if index.isMultiple(of: 256) { try Task.checkCancellation() }
                let frequency = row[column] ?? 0
                guard frequency >= 0 else { throw weightingFailure("bm25.negative-count") }
                frequencies[index] = frequency
                if frequency > 0 { documentFrequency += 1 }
            }
            let idf = bm25InverseDocumentFrequency(
                documentFrequency: documentFrequency, documentCount: rows.count)
            for (index, frequency) in frequencies.enumerated() {
                if index.isMultiple(of: 256) { try Task.checkCancellation() }
                guard frequency > 0 else { continue }
                scores[index] += bm25Contribution(
                    frequency: frequency, idf: idf, lengthFactor: lengthFactors[index],
                    parameters: parameters)
            }
        }
        guard scores.allSatisfy(\.isFinite) else { throw weightingFailure("bm25.non-finite-score") }
        try Task.checkCancellation()
        return scores
    }

    private static func bm25Contribution(
        frequency: Int, idf: Double, lengthFactor: Double, parameters: GlifiBM25Parameters
    ) -> Double {
        let f = Double(frequency)
        let numerator = idf * f * (parameters.k1 + 1)
        let denominator = f + parameters.k1 * lengthFactor
        if numerator.isFinite, denominator.isFinite { return numerator / denominator }
        // Preserve the ordinary operation sequence and scale only the overflow path.
        let scale = max(f, parameters.k1)
        let scaledK1 = parameters.k1 / scale
        return (idf * f) * (scaledK1 + 1 / scale)
            / (f / scale + scaledK1 * lengthFactor)
    }

    static func weightingFailure(_ code: String) -> GlifiFailure {
        derivedAnalysisFailure(code)
    }
}

// MARK: - Persisted analyses

/// One observed cell with a positive count; its weight may be zero.
public struct GlifiWeightedTermCell: Codable, Equatable, Sendable {
    /// Row index into `sourceRevisionIDs`.
    public let rowIndex: Int
    /// Column index into `terms`.
    public let columnIndex: Int
    /// Observed count.
    public let count: Int
    /// Weight under the declared scheme.
    public let weight: Double
}

/// Document × term matrix weighted by a declared scheme.
public struct GlifiCorpusTermWeightingAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-term-weighting.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-term-weighting-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Declared weighting scheme.
    public let scheme: GlifiTermWeightingScheme
    /// Combined weighting identity.
    public let combinedIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Documents (rows), canonically ordered.
    public let sourceRevisionIDs: [String]
    /// Vocabulary (columns), lexicographically ordered.
    public let terms: [String]
    /// Document frequency per term.
    public let documentFrequencies: [Int]
    /// Observed cells ordered by row, then column, including zero weights.
    public let cells: [GlifiWeightedTermCell]

    /// Weighs the matrix of one corpus profile.
    public init(_ analysis: GlifiCorpusAnalysis, scheme: GlifiTermWeightingScheme) throws {
        let counts = GlifiDocumentTermCounts(analysis)
        let weighted = try GlifiTermWeighting.weigh(
            rows: counts.rows, columnCount: counts.terms.count, scheme: scheme)
        var frequencies = Array(repeating: 0, count: counts.terms.count)
        var cells: [GlifiWeightedTermCell] = []
        for (rowIndex, row) in counts.rows.enumerated() {
            for (column, count) in row.sorted(by: { $0.key < $1.key }) where count > 0 {
                frequencies[column] += 1
                cells.append(
                    GlifiWeightedTermCell(
                        rowIndex: rowIndex,
                        columnIndex: column,
                        count: count,
                        weight: weighted[rowIndex][column] ?? 0
                    )
                )
            }
        }
        analysisIdentifier = Self.analysisIdentifier
        self.scheme = scheme
        combinedIdentifier = scheme.combinedIdentifier
        corpusDigest = analysis.corpusDigest
        sourceRevisionIDs = counts.documentIDs.map(\.canonicalValue)
        terms = counts.terms
        documentFrequencies = frequencies
        self.cells = cells
    }
}

/// One query term with its collection statistics.
public struct GlifiBM25QueryTerm: Codable, Equatable, Sendable {
    /// Normalized query term.
    public let term: String
    /// Whether the term belongs to the collection vocabulary.
    public let isInVocabulary: Bool
    /// Documents containing the term.
    public let documentFrequency: Int
    /// `BM25-v1` idf, zero contribution for out-of-vocabulary terms.
    public let inverseDocumentFrequency: Double
}

/// One ranked retrieval unit.
public struct GlifiBM25RankedDocument: Codable, Equatable, Sendable {
    /// Retrieval unit.
    public let sourceRevisionID: String
    /// Included lexical tokens `|d|`.
    public let length: Int
    /// `BM25-v1` score: a ranking value, not a probability.
    public let score: Double
}

/// `BM25-v1` ranking of the documents of one corpus profile for a query.
public struct GlifiCorpusBM25Analysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-bm25-ranking.v1"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-bm25-ranking-v1"
    /// Versioned ranking formula.
    public static let methodIdentifier = "BM25-v1"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Ranking formula.
    public let methodIdentifier: String
    /// Resolved parameters.
    public let parameters: GlifiBM25Parameters
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Unique normalized query terms in lexicographic order.
    public let queryTerms: [GlifiBM25QueryTerm]
    /// Number of retrieval units `N`.
    public let documentCount: Int
    /// Average unit length `avgdl`.
    public let averageLength: Double
    /// Units by decreasing score, ties by `SourceRevisionID`.
    public let ranking: [GlifiBM25RankedDocument]

    /// Ranks the documents of one corpus profile for already normalized query terms.
    public init(
        _ analysis: GlifiCorpusAnalysis,
        queryTerms: [String],
        parameters: GlifiBM25Parameters
    ) throws {
        let unique = Array(Set(queryTerms)).sorted()
        guard !unique.isEmpty else {
            throw GlifiTermWeighting.weightingFailure("bm25.empty-query")
        }
        let counts = GlifiDocumentTermCounts(analysis)
        let lengths = counts.documentLengths
        let columnByTerm = Dictionary(
            uniqueKeysWithValues: counts.terms.enumerated().map { ($0.element, $0.offset) })
        let scores = try GlifiTermWeighting.bm25(
            rows: counts.rows,
            columnCount: counts.terms.count,
            documentLengths: lengths,
            queryColumns: Set(unique.compactMap { columnByTerm[$0] }),
            parameters: parameters
        )
        analysisIdentifier = Self.analysisIdentifier
        methodIdentifier = Self.methodIdentifier
        self.parameters = parameters
        corpusDigest = analysis.corpusDigest
        documentCount = counts.rows.count
        averageLength = Double(lengths.reduce(0, +)) / Double(lengths.count)
        self.queryTerms = unique.map { term in
            guard let column = columnByTerm[term] else {
                return GlifiBM25QueryTerm(
                    term: term, isInVocabulary: false, documentFrequency: 0,
                    inverseDocumentFrequency: 0)
            }
            let df = counts.rows.filter { ($0[column] ?? 0) > 0 }.count
            return GlifiBM25QueryTerm(
                term: term,
                isInVocabulary: true,
                documentFrequency: df,
                inverseDocumentFrequency: GlifiTermWeighting.bm25InverseDocumentFrequency(
                    documentFrequency: df, documentCount: counts.rows.count)
            )
        }
        ranking = counts.documentIDs.indices.map {
            GlifiBM25RankedDocument(
                sourceRevisionID: counts.documentIDs[$0].canonicalValue,
                length: lengths[$0],
                score: scores[$0]
            )
        }.sorted {
            $0.score != $1.score
                ? $0.score > $1.score : $0.sourceRevisionID < $1.sourceRevisionID
        }
    }
}

/// Normalizes query text with the tokenizer and normalization of the corpus profile.
public enum GlifiQueryTermNormalizer {
    /// Lexical tokens of `text`, NFC and lowercased with the Italian locale.
    public static func terms(
        _ text: String,
        tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()
    ) throws -> [String] {
        let locale = Locale(identifier: "it_IT")
        return try tokenizer.tokenize(text).tokens.compactMap { token in
            guard token.kind.contributesToLexicalStatistics,
                let surface = token.range.text(in: text)
            else {
                return nil
            }
            return surface.precomposedStringWithCanonicalMapping.lowercased(with: locale)
        }
    }
}
