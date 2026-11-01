// SPDX-License-Identifier: BSD-3-Clause

import Accelerate
import Foundation

/// Explicit distance representation for word, document and code matrices.
public enum GlifiTextDistance: String, Codable, Sendable {
    case jaccard
    case dice
    case cosine
    case euclidean
    case manhattan
}

/// Matrix preparation must be selected explicitly rather than inferred from the distance.
public enum GlifiMatrixTransform: String, Codable, Sendable {
    case counts
    case binary
    case perThousand
    case tfidf
}

/// Common matrix operators usable for words and multi-label codes.
public enum GlifiTextMatrixOperators {
    /// Applies an explicit row transform, preserving all zero rows and column positions.
    public static func transform(
        _ matrix: [[Double]], using transform: GlifiMatrixTransform,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> [[Double]] {
        let width = try validateExploratoryMatrix(matrix, limits: limits)
        guard matrix.allSatisfy({ $0.allSatisfy { $0 >= 0 } }) else {
            throw exploratoryFailure("text-matrix.negative-count")
        }
        let frequencies = (0..<width).map { column in
            matrix.reduce(0) { $0 + ($1[column] > 0 ? 1 : 0) }
        }
        return try matrix.map { row in
            let total = row.reduce(0, +)
            guard total.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
            let transformed = row.indices.map { column in
                switch transform {
                case .counts: return row[column]
                case .binary: return row[column] > 0 ? 1 : 0
                case .perThousand: return total > 0 ? row[column] / total * 1_000 : 0
                case .tfidf:
                    return row[column]
                        * (log(Double(matrix.count + 1) / Double(frequencies[column] + 1)) + 1)
                }
            }
            guard transformed.allSatisfy(\.isFinite) else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            return transformed
        }
    }

    /// Computes symmetric distances; set metrics ignore joint absences and count magnitude.
    public static func dissimilarities(
        _ matrix: [[Double]], metric: GlifiTextDistance,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> [[Double]] {
        let width = try validateExploratoryMatrix(matrix, limits: limits)
        guard matrix.count <= limits.maximumPairwiseObjects,
            matrix.count <= limits.maximumCells / matrix.count
        else { throw exploratoryFailure("exploratory.resource-limit", .insufficientResources) }
        try requireWork([matrix.count, matrix.count, width], limits)
        // Construct presence sets once, outside the all-pairs loop.
        let presence =
            metric == .jaccard || metric == .dice
            ? matrix.map { row in Set(row.indices.filter { row[$0] > 0 }) } : []
        let norms = metric == .cosine ? matrix.map { vDSP.sumOfSquares($0).squareRoot() } : []
        if metric == .cosine, !norms.allSatisfy({ $0.isFinite && $0 > 0 }) {
            throw exploratoryFailure("text-matrix.zero-cosine-norm", .insufficientData)
        }
        var result = Array(
            repeating: Array(repeating: 0.0, count: matrix.count), count: matrix.count)
        for i in matrix.indices {
            try Task.checkCancellation()
            for j in 0..<i {
                let distance: Double
                switch metric {
                case .jaccard: distance = 1 - GlifiSetSimilarity.jaccard(presence[i], presence[j])
                case .dice: distance = 1 - GlifiSetSimilarity.dice(presence[i], presence[j])
                case .cosine:
                    let cosine = vDSP.dot(matrix[i], matrix[j]) / norms[i] / norms[j]
                    guard cosine.isFinite else {
                        throw exploratoryFailure("exploratory.numeric-overflow")
                    }
                    distance = 1 - min(1, max(-1, cosine))
                case .euclidean: distance = vDSP.distanceSquared(matrix[i], matrix[j]).squareRoot()
                case .manhattan:
                    distance = zip(matrix[i], matrix[j]).reduce(0) { $0 + abs($1.0 - $1.1) }
                }
                guard distance.isFinite else {
                    throw exploratoryFailure("exploratory.numeric-overflow")
                }
                result[i][j] = distance
                result[j][i] = distance
            }
        }
        return result
    }

    /// Transposes a bounded matrix, preserving the caller's row and column identity order.
    public static func transpose(
        _ matrix: [[Double]], limits: GlifiExploratoryLimits = .standard
    ) throws -> [[Double]] {
        let width = try validateExploratoryMatrix(matrix, limits: limits)
        return (0..<width).map { column in matrix.map { $0[column] } }
    }
}

extension GlifiTextMatrixOperators {
    /// Clusters a declared dissimilarity matrix with Lance-Williams updates.
    ///
    /// Ward requires Euclidean feature vectors and is deliberately rejected at this boundary.
    public static func hierarchicalClustering(
        dissimilarities: [[Double]], linkage: GlifiLinkage,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiHierarchicalClustering {
        let n = try validateExploratoryMatrix(dissimilarities, limits: limits)
        guard dissimilarities.count == n, n >= 2, n <= limits.maximumPairwiseObjects,
            linkage != .ward
        else { throw exploratoryFailure("hac.invalid-dissimilarities") }
        try requireWork([n, n, n], limits)
        for i in 0..<n {
            guard dissimilarities[i][i] == 0 else {
                throw exploratoryFailure("hac.invalid-dissimilarities")
            }
            for j in 0..<i {
                guard dissimilarities[i][j] >= 0, dissimilarities[i][j] == dissimilarities[j][i]
                else {
                    throw exploratoryFailure("hac.invalid-dissimilarities")
                }
            }
        }
        var distances = dissimilarities
        var active = [Bool](repeating: true, count: n)
        var sizes = [Int](repeating: 1, count: n)
        var identities = Array(0..<n)
        var merges: [GlifiMerge] = []
        for step in 0..<(n - 1) {
            try Task.checkCancellation()
            var best: (left: Int, right: Int, distance: Double)?
            for i in 0..<n where active[i] {
                for j in (i + 1)..<n where active[j] {
                    let candidate = distances[i][j]
                    if best == nil || candidate < (best?.distance ?? .infinity)
                        || (candidate == best?.distance
                            && (
                                min(identities[i], identities[j]), max(identities[i], identities[j])
                            )
                                < (
                                    min(identities[best?.left ?? i], identities[best?.right ?? j]),
                                    max(identities[best?.left ?? i], identities[best?.right ?? j])
                                ))
                    {
                        best = (i, j, candidate)
                    }
                }
            }
            guard let best else { throw exploratoryFailure("hac.invalid-dissimilarities") }
            let i = best.left
            let j = best.right
            merges.append(
                GlifiMerge(
                    first: min(identities[i], identities[j]),
                    second: max(identities[i], identities[j]),
                    height: best.distance, wardIncrement: nil, size: sizes[i] + sizes[j]
                ))
            for other in 0..<n where active[other] && other != i && other != j {
                let value: Double
                switch linkage {
                case .single: value = min(distances[i][other], distances[j][other])
                case .complete: value = max(distances[i][other], distances[j][other])
                case .average:
                    value =
                        distances[i][other] * Double(sizes[i]) / Double(sizes[i] + sizes[j])
                        + distances[j][other] * Double(sizes[j]) / Double(sizes[i] + sizes[j])
                case .ward: throw exploratoryFailure("hac.ward-requires-vectors")
                }
                distances[i][other] = value
                distances[other][i] = value
            }
            sizes[i] += sizes[j]
            identities[i] = n + step
            active[j] = false
        }
        return GlifiHierarchicalClustering(linkage: linkage, merges: merges)
    }

    /// Creates a symmetric directed Jaccard network from columns of a document-word/code matrix.
    public static func cooccurrenceNetwork(
        _ matrix: [[Double]], labels: [String], minimumJaccard: Double = 0.1,
        maximumEdges: Int = 10_000, limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiDirectedGraph<String> {
        let width = try validateExploratoryMatrix(matrix, limits: limits)
        guard labels.count == width, Set(labels).count == width, !labels.contains(where: \.isEmpty),
            minimumJaccard.isFinite, (0...1).contains(minimumJaccard), maximumEdges >= 0,
            maximumEdges <= 1_000_000, matrix.allSatisfy({ $0.allSatisfy { $0 >= 0 } })
        else { throw exploratoryFailure("text-matrix.invalid-network") }
        let columns = try transpose(matrix, limits: limits)
        let distances = try dissimilarities(columns, metric: .jaccard, limits: limits)
        let nonempty = columns.map { $0.contains { $0 > 0 } }
        var pairs: [(i: Int, j: Int, weight: Double)] = []
        for i in 0..<width {
            for j in 0..<i {
                let weight = 1 - distances[i][j]
                if nonempty[i], nonempty[j], weight > 0, weight >= minimumJaccard {
                    pairs.append((j, i, weight))
                }
            }
        }
        pairs.sort { a, b in a.weight == b.weight ? (a.i, a.j) < (b.i, b.j) : a.weight > b.weight }
        let edges = pairs.prefix(maximumEdges).flatMap { pair in
            [
                GlifiGraphEdge(source: labels[pair.i], target: labels[pair.j], weight: pair.weight),
                GlifiGraphEdge(source: labels[pair.j], target: labels[pair.i], weight: pair.weight),
            ]
        }
        return try GlifiDirectedGraph(nodes: labels, edges: edges)
    }
}
