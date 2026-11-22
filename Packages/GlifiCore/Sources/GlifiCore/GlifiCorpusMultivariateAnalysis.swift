// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Declared multivariate method applied to the document × term matrix.
public enum GlifiMultivariateMethod: Codable, Equatable, Sendable {
    /// `CA-SVD-v1` on raw counts.
    case correspondence
    /// `PCA-SVD-v1` on relative frequencies, optionally scaled.
    case principalComponents(scaled: Bool)
    /// `LSA-SVD-v1` of rank `k` on `tfidf-raw-log-v1` weights.
    case latentSemantic(rank: Int)
    /// `NMF-Frobenius-v1` of rank `k` on raw counts.
    case nonNegativeFactorization(rank: Int, seed: UInt64, restarts: Int)
    /// `HAC-v1` on relative frequencies with a cut into `k` clusters.
    case hierarchical(linkage: GlifiLinkage, clusterCount: Int)
    /// `KMeans-Lloyd-v1` on relative frequencies.
    case kMeans(clusterCount: Int, seed: UInt64, restarts: Int)

    /// Method identity.
    public var identifier: String {
        switch self {
        case .correspondence: GlifiCorrespondenceResult.identifier
        case .principalComponents: GlifiPrincipalComponentsResult.identifier
        case .latentSemantic: GlifiLatentSemanticResult.identifier
        case .nonNegativeFactorization: GlifiNonNegativeFactorization.identifier
        case .hierarchical: GlifiHierarchicalClustering.identifier
        case .kMeans: GlifiKMeansResult.identifier
        }
    }

    /// Row representation fed to the method.
    public var representationIdentifier: String {
        switch self {
        case .correspondence, .nonNegativeFactorization: "document-term-raw-count-v1"
        case .latentSemantic: "tfidf-raw-log-v1"
        case .principalComponents, .hierarchical, .kMeans: "document-term-relative-frequency-v1"
        }
    }

    /// Canonical descriptor parameters of the method.
    var parameters: [String: GlifiAnalysisValue] {
        var values: [String: GlifiAnalysisValue] = ["method": .text(identifier)]
        switch self {
        case .correspondence:
            break
        case let .principalComponents(scaled):
            values["scaled"] = .boolean(scaled)
        case let .latentSemantic(rank):
            values["rank"] = .integer(Int64(rank))
        case let .nonNegativeFactorization(rank, seed, restarts):
            values["rank"] = .integer(Int64(rank))
            values["seed"] = .text(String(seed))
            values["restarts"] = .integer(Int64(restarts))
        case let .hierarchical(linkage, clusterCount):
            values["linkage"] = .text(linkage.rawValue)
            values["clusterCount"] = .integer(Int64(clusterCount))
        case let .kMeans(clusterCount, seed, restarts):
            values["clusterCount"] = .integer(Int64(clusterCount))
            values["seed"] = .text(String(seed))
            values["restarts"] = .integer(Int64(restarts))
        }
        return values
    }
}

/// Multivariate analysis of the document × term matrix of one corpus profile.
public struct GlifiCorpusMultivariateAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.corpus-multivariate.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-document-term-multivariate-v2"

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Declared method and parameters.
    public let method: GlifiMultivariateMethod
    /// Row representation fed to the method.
    public let representationIdentifier: String
    /// Term selection rule.
    public let termSelectionIdentifier: String
    /// Digest of the analyzed corpus profile.
    public let corpusDigest: String
    /// Documents (rows), canonically ordered.
    public let sourceRevisionIDs: [String]
    /// Selected terms (columns), lexicographically ordered.
    public let terms: [String]
    /// `CA-SVD-v1` result.
    public let correspondence: GlifiCorrespondenceResult?
    /// `PCA-SVD-v1` result.
    public let principalComponents: GlifiPrincipalComponentsResult?
    /// `LSA-SVD-v1` result.
    public let latentSemantic: GlifiLatentSemanticResult?
    /// `NMF-Frobenius-v1` result.
    public let nonNegativeFactorization: GlifiNonNegativeFactorization?
    /// `HAC-v1` tree.
    public let hierarchical: GlifiHierarchicalClustering?
    /// Cluster per document for HAC (cut) or k-means.
    public let clusterAssignments: [Int]?
    /// `KMeans-Lloyd-v1` result.
    public let kMeans: GlifiKMeansResult?
    /// Average silhouette width of the cluster assignments (Rousseeuw 1987), when defined.
    public let averageSilhouette: Double?
}

/// Runs a declared multivariate method on a corpus profile.
public struct GlifiCorpusMultivariateAnalyzer: Sendable {
    /// Largest number of terms kept, chosen by document frequency, then frequency.
    public static let maximumTermCount = 2_000

    /// Creates a stateless analyzer.
    public init() {}

    /// Builds the declared representation and applies `method`.
    public func analyze(
        _ analysis: GlifiCorpusAnalysis,
        method: GlifiMultivariateMethod,
        maximumTermCount: Int = 50
    ) throws -> GlifiCorpusMultivariateAnalysis {
        try Task.checkCancellation()
        guard (2...Self.maximumTermCount).contains(maximumTermCount) else {
            throw derivedAnalysisFailure("multivariate.invalid-term-count", category: .invalidInput)
        }
        let counts = GlifiDocumentTermCounts(analysis)
        guard counts.documentIDs.count >= 2 else {
            throw derivedAnalysisFailure(
                "multivariate.insufficient-documents",
                category: .insufficientData
            )
        }
        let selected = analysis.terms.sorted {
            if $0.documentFrequency != $1.documentFrequency {
                return $0.documentFrequency > $1.documentFrequency
            }
            if $0.frequency != $1.frequency { return $0.frequency > $1.frequency }
            return $0.term < $1.term
        }.prefix(maximumTermCount).map(\.term).sorted()
        guard selected.count >= 2 else {
            throw derivedAnalysisFailure(
                "multivariate.insufficient-terms", category: .insufficientData)
        }
        let columnByTerm = Dictionary(
            uniqueKeysWithValues: counts.terms.enumerated().map { ($1, $0) })
        let raw: [[Double]] = counts.rows.map { row in
            selected.map { term in Double(columnByTerm[term].flatMap { row[$0] } ?? 0) }
        }
        let lengths = counts.documentLengths
        func relative() throws -> [[Double]] {
            guard lengths.allSatisfy({ $0 > 0 }) else {
                throw derivedAnalysisFailure(
                    "multivariate.empty-document",
                    category: .insufficientData
                )
            }
            return zip(raw, lengths).map { row, length in row.map { $0 / Double(length) } }
        }
        var correspondence: GlifiCorrespondenceResult?
        var principal: GlifiPrincipalComponentsResult?
        var latent: GlifiLatentSemanticResult?
        var factorization: GlifiNonNegativeFactorization?
        var hierarchical: GlifiHierarchicalClustering?
        var clusters: [Int]?
        var kMeans: GlifiKMeansResult?
        var silhouetteSource: [[Double]]?
        switch method {
        case .correspondence:
            correspondence = try GlifiMultivariateMethods.correspondenceAnalysis(raw)
        case let .principalComponents(scaled):
            principal = try GlifiMultivariateMethods.principalComponents(
                try relative(), scaled: scaled)
        case let .latentSemantic(rank):
            // tfidf-raw-log-v1: tf grezza × ln(N/df) sul sottoinsieme di documenti analizzato.
            let documents = Double(raw.count)
            let idf = selected.indices.map { column in
                let frequency = raw.filter { $0[column] > 0 }.count
                return frequency > 0 ? log(documents / Double(frequency)) : 0
            }
            let weighted = raw.map { row in row.indices.map { row[$0] * idf[$0] } }
            latent = try GlifiMultivariateMethods.latentSemanticAnalysis(weighted, rank: rank)
        case let .nonNegativeFactorization(rank, seed, restarts):
            factorization = try GlifiMultivariateMethods.nonNegativeFactorization(
                raw,
                rank: rank,
                seed: seed,
                restarts: restarts
            )
        case let .hierarchical(linkage, clusterCount):
            let points = try relative()
            let tree = try GlifiMultivariateMethods.hierarchicalClustering(points, linkage: linkage)
            hierarchical = tree
            silhouetteSource = points
            clusters = try GlifiMultivariateMethods.cut(
                tree,
                pointCount: points.count,
                clusterCount: clusterCount
            )
        case let .kMeans(clusterCount, seed, restarts):
            let points = try relative()
            silhouetteSource = points
            let result = try GlifiMultivariateMethods.kMeans(
                points,
                clusterCount: clusterCount,
                seed: seed,
                restarts: restarts
            )
            kMeans = result
            clusters = result.assignments
        }
        var silhouette: Double?
        if let points = silhouetteSource, let clusters {
            do {
                silhouette = try GlifiMultivariateMethods.silhouette(
                    points, assignments: clusters
                ).average
            } catch let failure as GlifiFailure
                where failure.code == "clustering.silhouette-undefined"
            {
                silhouette = nil
            }
        }
        return GlifiCorpusMultivariateAnalysis(
            analysisIdentifier: GlifiCorpusMultivariateAnalysis.analysisIdentifier,
            method: method,
            representationIdentifier: method.representationIdentifier,
            termSelectionIdentifier: "top-document-frequency-then-frequency-v1",
            corpusDigest: analysis.corpusDigest,
            sourceRevisionIDs: counts.documentIDs.map(\.canonicalValue),
            terms: selected,
            correspondence: correspondence,
            principalComponents: principal,
            latentSemantic: latent,
            nonNegativeFactorization: factorization,
            hierarchical: hierarchical,
            clusterAssignments: clusters,
            kMeans: kMeans,
            averageSilhouette: silhouette
        )
    }
}
