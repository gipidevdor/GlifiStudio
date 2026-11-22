// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Application-facing SOM geometry without an engine type in its public contract.
public enum GlifiStudioSOMTopology: String, Codable, Sendable {
    case rectangular
    case hexagonal

    var core: GlifiSOMTopology {
        switch self {
        case .rectangular: .rectangular
        case .hexagonal: .hexagonal
        }
    }
}

/// Complete reproducible diagnostics of an iterative MDS multistart search.
public struct GlifiStudioMDSSearchResult: Encodable, Equatable, Sendable {
    /// Versioned search and selection contract.
    public let methodIdentifier: String
    /// Complete runs in seed order, including runs that reached their iteration bound.
    public let runs: [GlifiStudioMDSResult]
    /// Earliest run with the minimum final objective.
    public let chosenRun: Int
    /// Selected result; the encoded representation retains `runs` and `chosenRun`.
    public var best: GlifiStudioMDSResult { runs[chosenRun] }

    init(_ value: GlifiMDSSearchResult) {
        methodIdentifier = GlifiMDSSearchResult.identifier
        runs = value.runs.map(GlifiStudioMDSResult.init)
        chosenRun = value.chosenRun
    }
}

/// Euclidean Ward composition over the row-major SOM prototypes.
public struct GlifiStudioSOMCodebookClustering: Encodable, Equatable, Sendable {
    /// Versioned composition contract.
    public let methodIdentifier: String
    /// Child identities: `0..<n` are units and `n+step` are merged clusters.
    public let children: [[Int]]
    /// Merge heights from the existing Ward implementation.
    public let heights: [Double]
    /// Ward increase in within-cluster squared error for every merge.
    public let wardIncrements: [Double?]
    /// Size of each merged cluster.
    public let sizes: [Int]
    /// Cluster of every unit in row-major order.
    public let assignments: [Int]

    init(_ value: GlifiSOMCodebookClustering) {
        methodIdentifier = GlifiSOMCodebookClustering.identifier
        children = value.tree.merges.map { [$0.first, $0.second] }
        heights = value.tree.merges.map(\.height)
        wardIncrements = value.tree.merges.map(\.wardIncrement)
        sizes = value.tree.merges.map(\.size)
        assignments = value.assignments
    }
}

/// SOM prototypes and topology-specific diagnostics, prepared without an application view.
public struct GlifiStudioAdvancedSOMResult: Encodable, Equatable, Sendable {
    /// Complete fitted map with its geometry-specific method identifier.
    public let map: GlifiStudioSOMResult
    /// Grid geometry used for fitting, topographic error and U-matrix neighbors.
    public let topology: GlifiStudioSOMTopology
    /// Median Euclidean distance to actual neighboring units, in row-major order.
    public let uMatrix: [Double]
    /// Optional Ward composition over codebooks, retaining unit identities.
    public let codebookClustering: GlifiStudioSOMCodebookClustering?
}

/// Bounded exploratory operations executed away from the caller's actor.
public enum GlifiStudioExploratoryCompletion {
    /// Searches actual seeded random configurations and retains every run's diagnostics.
    @concurrent public static func multidimensionalScalingSearch(
        _ dissimilarities: [[Double]], dimensions: Int = 2,
        method: GlifiStudioMDSMethod = .ordinal, starts: Int = 10, seed: UInt64,
        maximumIterations: Int = 300, tolerance: Double = 1e-8
    ) async throws(GlifiStudioFailure) -> GlifiStudioMDSSearchResult {
        try mapExploratoryCompletionFailure {
            try GlifiStudioMDSSearchResult(
                GlifiExploratoryAnalysis.multidimensionalScalingSearch(
                    dissimilarities, dimensions: dimensions, method: method.core, starts: starts,
                    seed: seed, maximumIterations: maximumIterations, tolerance: tolerance))
        }
    }

    /// Fits a batch SOM and computes its U-matrix and optional codebook Ward clustering.
    @concurrent public static func selfOrganizingMap(
        _ matrix: [[Double]], width: Int, height: Int, seed: UInt64, epochs: Int = 100,
        topology: GlifiStudioSOMTopology = .rectangular,
        initialRadius: Double = 2, finalRadius: Double = 0.5, tolerance: Double = 1e-8,
        codebookClusterCount: Int? = nil
    ) async throws(GlifiStudioFailure) -> GlifiStudioAdvancedSOMResult {
        try mapExploratoryCompletionFailure {
            guard width > 0, height > 0, width <= 1_024, height <= 1_024,
                width <= 1_024 / height
            else { throw exploratoryFailure("exploratory.invalid-parameters") }
            // Reserve fit, U-matrix and optional Ward in the same workflow budget,
            // before allocating normalized data or paying for an iterative map fit.
            try admitBatchSOMResources(
                rows: matrix.count, columns: matrix.first?.count ?? 0,
                units: width * height, epochs: epochs, includeCodebookAnalysis: true,
                clusterCount: codebookClusterCount, limits: .standard)
            let map = try GlifiExploratoryAnalysis.selfOrganizingMap(
                matrix, width: width, height: height, seed: seed, epochs: epochs,
                initialRadius: initialRadius, finalRadius: finalRadius, tolerance: tolerance,
                topology: topology.core)
            let uMatrix = try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(map)
            let clustering = try codebookClusterCount.map {
                try GlifiStudioSOMCodebookClustering(
                    GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
                        map, clusterCount: $0))
            }
            return GlifiStudioAdvancedSOMResult(
                map: GlifiStudioSOMResult(map), topology: topology, uMatrix: uMatrix,
                codebookClustering: clustering)
        }
    }
}

private func mapExploratoryCompletionFailure<Value>(
    _ body: () throws -> Value
) throws(GlifiStudioFailure) -> Value {
    do { return try body() } catch let failure as GlifiFailure {
        throw GlifiStudioFailure(failure)
    } catch is CancellationError {
        throw GlifiStudioFailure(
            code: "operation.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled")
    } catch {
        throw GlifiStudioFailure(
            code: "analysis.failed", category: "insufficientData", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.insufficientData")
    }
}
