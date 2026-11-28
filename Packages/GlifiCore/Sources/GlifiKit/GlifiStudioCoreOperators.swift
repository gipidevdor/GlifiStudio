// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Explicit expert operations that complement the document-driven application paths.
public enum GlifiStudioCoreOperator: String, CaseIterable, Codable, Sendable {
    case svd, truncatedSVD, pca, lsa, nmf, kMeans, hacCutCount, hacCutHeight, silhouette
    case transformCounts, transformBinary, transformPerThousand, transformTFIDF, transpose,
        distances
    case cosine, euclidean, manhattan, jaccard, dice, simpson, weightedJaccard, multisetDice
    case kl, jensenShannon, jensenShannonDistance, hellinger, lidstone
    case degree, pageRank, betweenness, harmonicCloseness, weightedBetweenness, weightedCloseness
    case weakComponents, strongComponents, eigenvector, louvain, modularity
    case communities, graphLayout, minimumSpanningForest
    case lexicalObservation, zipfFit, heapsFit

    /// Input family used by native configuration controls.
    public var family: String {
        switch self {
        case .svd, .truncatedSVD, .pca, .lsa, .nmf, .kMeans, .hacCutCount, .hacCutHeight,
            .silhouette, .transformCounts, .transformBinary, .transformPerThousand,
            .transformTFIDF, .transpose, .distances:
            "matrix"
        case .cosine, .euclidean, .manhattan, .jaccard, .dice, .simpson, .weightedJaccard,
            .multisetDice,
            .kl, .jensenShannon, .jensenShannonDistance, .hellinger, .lidstone:
            "similarity"
        case .degree, .pageRank, .betweenness, .harmonicCloseness, .weightedBetweenness,
            .weightedCloseness, .weakComponents, .strongComponents, .eigenvector, .louvain,
            .modularity, .communities, .graphLayout, .minimumSpanningForest:
            "graph"
        case .lexicalObservation, .zipfFit, .heapsFit: "lexical"
        }
    }
}

/// Snapshot of explicitly entered session data and effective operator parameters.
public struct GlifiStudioCoreOperatorRequest: Codable, Equatable, Sendable {
    /// Selected operation.
    public var operation: GlifiStudioCoreOperator = .svd
    /// Matrix rows or two vector rows, separated by newlines; values use whitespace separators.
    public var numbers = ""
    /// One explicit graph node identity per line.
    public var nodes = ""
    /// Source, target and weight separated by TAB, one edge per line.
    public var edges = ""
    /// One explicit token sequence per line, without implicit linguistic normalization.
    public var documents = ""
    /// Explicit lexical keys of the first set, without implicit normalization.
    public var firstSet = ""
    /// Explicit lexical keys of the second set, without implicit normalization.
    public var secondSet = ""
    /// Space-separated integer assignments or community identities.
    public var assignments = ""
    /// Caller-selected vocabulary growth checkpoints.
    public var checkpoints = ""
    /// Retained rank or factor count.
    public var rank = 2
    /// Cluster count of a cut or k-means.
    public var clusterCount = 2
    /// Explicit random seed.
    public var seed: UInt64 = 0
    /// Number of seeded restarts.
    public var restarts = 3
    /// Iteration ceiling, bounded by this client to 10 000.
    public var maximumIterations = 1_000
    /// Positive stopping tolerance.
    public var tolerance = 1e-10
    /// Truncated-SVD oversampling.
    public var oversampling = 15
    /// PCA standardization choice.
    public var scaled = true
    /// PageRank continuation probability.
    public var damping = 0.85
    /// Inclusive HAC cut height.
    public var maximumHeight = 1.0
    /// Lidstone smoothing parameter.
    public var alpha = 1.0
    /// Explicit distance identity.
    public var distance = "euclidean"
    /// Hierarchical linkage identity.
    public var linkage = "average"
    /// First included rank of a Zipf fit.
    public var firstRank = 1
    /// Last included rank, or nil for the last observed rank.
    public var lastRank: Int?

    /// Native community algorithm selected independently from Louvain.
    public var communityMethod = "fastGreedy"
    /// Modularity resolution gamma of the selected community algorithm.
    public var resolution = 1.0
    /// Walktrap random-walk length.
    public var walkLength = 4
    /// Native two-dimensional graph layout.
    public var layoutMethod = "fruchtermanReingold"
    /// Whether the explicit numeric editor supplies one x/y row per node.
    public var usesInitialPositions = false

    /// Creates editable session parameters with declared defaults.
    public init() {}

    /// Captures only the selected method's inputs and controls; inactive fields use defaults.
    public var effective: Self {
        var value = Self()
        value.operation = operation
        switch operation.family {
        case "graph":
            value.nodes = nodes
            value.edges = edges
        case "lexical":
            value.documents = documents
            value.checkpoints = checkpoints
        default:
            if operation == .jaccard || operation == .dice || operation == .simpson {
                value.firstSet = firstSet
                value.secondSet = secondSet
            } else {
                value.numbers = numbers
            }
        }
        switch operation {
        case .truncatedSVD, .nmf:
            value.rank = rank
            value.seed = seed
            value.maximumIterations = maximumIterations
            value.tolerance = tolerance
            if operation == .truncatedSVD {
                value.oversampling = oversampling
            } else {
                value.restarts = restarts
            }
        case .pca: value.scaled = scaled
        case .lsa: value.rank = rank
        case .kMeans:
            value.clusterCount = clusterCount
            value.seed = seed
            value.restarts = restarts
            value.maximumIterations = maximumIterations
        case .hacCutCount, .hacCutHeight:
            value.linkage = linkage
            if operation == .hacCutCount {
                value.clusterCount = clusterCount
            } else {
                value.maximumHeight = maximumHeight
            }
        case .silhouette, .modularity: value.assignments = assignments
        case .distances: value.distance = distance
        case .pageRank, .eigenvector:
            value.tolerance = tolerance
            value.maximumIterations = maximumIterations
            if operation == .pageRank { value.damping = damping }
        case .communities:
            value.communityMethod = communityMethod
            value.resolution = resolution
            if communityMethod == "walktrap" { value.walkLength = walkLength }
        case .graphLayout:
            value.layoutMethod = layoutMethod
            value.seed = seed
            value.maximumIterations = maximumIterations
            value.tolerance = tolerance
            value.usesInitialPositions = usesInitialPositions
            if usesInitialPositions { value.numbers = numbers }
        case .minimumSpanningForest: break
        case .lidstone: value.alpha = alpha
        case .zipfFit:
            value.firstRank = firstRank
            value.lastRank = lastRank
        case .svd, .transformCounts, .transformBinary, .transformPerThousand, .transformTFIDF,
            .transpose, .cosine, .euclidean, .manhattan, .jaccard, .dice, .simpson,
            .weightedJaccard,
            .multisetDice, .kl, .jensenShannon, .jensenShannonDistance, .hellinger,
            .degree, .betweenness, .harmonicCloseness, .weightedBetweenness,
            .weightedCloseness, .weakComponents, .strongComponents, .louvain,
            .lexicalObservation, .heapsFit:
            break
        }
        return value
    }
}

/// Typed cell that preserves undefined and infinite outcomes without invalid JSON numbers.
public enum GlifiStudioOperatorCell: Codable, Equatable, Sendable {
    case number(Double)
    case integer(Int)
    case text(String)
    /// A semantic label emitted by the operator, separate from caller-supplied text.
    case localized(String)
    case nonFinite(String)

    static func measured(_ value: Double) -> Self {
        if value.isFinite { return .number(value) }
        if value.isNaN { return .nonFinite("undefined") }
        return .nonFinite(value > 0 ? "positiveInfinity" : "negativeInfinity")
    }
}

/// One complete, bounded result table; presentation can page its rows independently.
public struct GlifiStudioOperatorTable: Codable, Equatable, Sendable {
    /// Semantic localization key of this table.
    public let titleKey: String
    /// Semantic localization keys of the columns.
    public let columns: [String]
    /// Complete row values in the returned order.
    public let rows: [[GlifiStudioOperatorCell]]
}

/// Session result with the exact input and method identities retained for inspection/export.
public struct GlifiStudioCoreOperatorResult: Encodable, Equatable, Sendable {
    /// Versioned session-DTO schema, distinct from the project format.
    public let schema = "studio.glifi.core-operator-result"
    /// Session-DTO schema version.
    public let schemaVersion = 1
    /// Effective request, independent of later changes to controls.
    public let request: GlifiStudioCoreOperatorRequest
    /// Exact numerical procedures used.
    public let methodIdentifiers: [String]
    /// Conservative client status; does not promote a scientific manifest.
    public let validationStatus: String
    /// Complete tabular observations and diagnostics.
    public let tables: [GlifiStudioOperatorTable]
}

extension GlifiStudioCoreOperatorResult: Decodable {
    private enum CodingKeys: String, CodingKey {
        case schema, schemaVersion, request, methodIdentifiers, validationStatus, tables
    }

    /// Restores a captured result without executing an operator; bounds precede presentation.
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        guard
            try fields.decode(String.self, forKey: .schema) == "studio.glifi.core-operator-result",
            try fields.decode(Int.self, forKey: .schemaVersion) == 1
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .schema, in: fields, debugDescription: "Unsupported operator result schema")
        }
        let request = try fields.decode(GlifiStudioCoreOperatorRequest.self, forKey: .request)
        let methods = try fields.decode([String].self, forKey: .methodIdentifiers)
        let status = try fields.decode(String.self, forKey: .validationStatus)
        let tables = try fields.decode([GlifiStudioOperatorTable].self, forKey: .tables)
        guard !methods.isEmpty, methods.count <= 1_024, tables.count <= 128,
            tables.reduce(0, { $0 + $1.rows.count }) <= 100_000,
            tables.allSatisfy({ table in
                table.columns.count <= 1_024
                    && table.rows.allSatisfy { row in
                        row.count == table.columns.count
                            && row.allSatisfy { cell in
                                switch cell {
                                case let .number(value): value.isFinite
                                case .integer: true
                                case let .text(value), let .localized(value):
                                    value.utf8.count <= 1_048_576
                                case let .nonFinite(value):
                                    ["undefined", "positiveInfinity", "negativeInfinity"].contains(
                                        value)
                                }
                            }
                    }
            })
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .tables, in: fields, debugDescription: "Invalid captured operator tables")
        }
        self.init(
            request: request, methodIdentifiers: methods, validationStatus: status, tables: tables)
    }
}

/// Bounded facade over the existing numerical, graph and lexical operators.
public enum GlifiStudioCoreOperators {
    /// Maximum input size for each explicit text editor.
    public static let maximumInputBytes = 1_048_576
    /// Explicit matrix budget of this interactive client.
    public static let maximumMatrixCells = 40_000
    /// Maximum matrix rows and columns, bounding quadratic interactive operations.
    public static let maximumMatrixDimension = 200
    /// Explicit graph-node budget of this interactive client.
    public static let maximumGraphNodes = 256
    /// Explicit graph-edge budget of this interactive client.
    public static let maximumGraphEdges = 4_096

    /// Runs an existing core procedure outside the caller's actor, without project mutation.
    @concurrent public static func execute(
        _ draft: GlifiStudioCoreOperatorRequest
    ) async throws(GlifiStudioFailure) -> GlifiStudioCoreOperatorResult {
        do {
            try Task.checkCancellation()
            let request = draft.effective
            for text in [
                request.numbers, request.nodes, request.edges, request.documents,
                request.assignments, request.checkpoints, request.firstSet, request.secondSet,
            ] {
                guard text.utf8.count <= maximumInputBytes else { throw invalid(resource: true) }
            }
            if [.truncatedSVD, .nmf, .kMeans, .pageRank, .eigenvector, .graphLayout].contains(
                request.operation)
            {
                guard (1...10_000).contains(request.maximumIterations) else { throw invalid() }
            }
            let result: (methods: [String], tables: [GlifiStudioOperatorTable])
            switch request.operation.family {
            case "matrix": result = try matrix(request)
            case "graph": result = try await graph(request)
            case "lexical": result = try lexical(request)
            case "similarity": result = try similarity(request)
            default: throw invalid()
            }
            try Task.checkCancellation()
            return GlifiStudioCoreOperatorResult(
                request: request, methodIdentifiers: result.methods,
                validationStatus: "candidate", tables: result.tables)
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch is CancellationError {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        } catch {
            throw invalid()
        }
    }

    private static func matrix(_ request: GlifiStudioCoreOperatorRequest) throws
        -> (methods: [String], tables: [GlifiStudioOperatorTable])
    {
        let values = try numericRows(request.numbers)
        switch request.operation {
        case .svd, .truncatedSVD:
            let result =
                request.operation == .svd
                ? try GlifiLinearAlgebra.singularValueDecomposition(values)
                : try GlifiLinearAlgebra.truncatedSingularValueDecomposition(
                    values, rank: request.rank, oversampling: request.oversampling,
                    seed: request.seed, tolerance: request.tolerance,
                    maximumIterations: request.maximumIterations)
            return (
                [
                    request.operation == .svd
                        ? GlifiSingularValueDecomposition.identifier
                        : GlifiLinearAlgebra.truncatedIdentifier
                ],
                [
                    vectorTable("operators.singular-values", result.singularValues),
                    matrixTable("operators.matrix-u", result.u),
                    matrixTable("operators.matrix-v", result.v),
                    metrics([
                        ("operators.rank", .integer(result.rank)),
                        ("operators.iterations", .integer(result.sweeps)),
                    ]),
                ]
            )
        case .pca:
            let result = try GlifiMultivariateMethods.principalComponents(
                values, scaled: request.scaled)
            return (
                [GlifiPrincipalComponentsResult.identifier, result.backendIdentifier],
                [
                    matrixTable("operators.scores", result.scores),
                    matrixTable("operators.loadings", result.loadings),
                    vectorTable("operators.variance-shares", result.varianceShares),
                    vectorTable("operators.means", result.means),
                    vectorTable("operators.variances", result.variances),
                    integerTable("operators.excluded-columns", result.excludedConstantColumns),
                ]
            )
        case .lsa:
            let result = try GlifiMultivariateMethods.latentSemanticAnalysis(
                values, rank: request.rank)
            return (
                [GlifiLatentSemanticResult.identifier, result.backendIdentifier],
                [
                    matrixTable("operators.row-coordinates", result.rowCoordinates),
                    matrixTable("operators.column-coordinates", result.columnCoordinates),
                    vectorTable("operators.singular-values", result.allSingularValues),
                    metrics([
                        ("operators.rank", .integer(result.effectiveRank)),
                        ("operators.residual-norm", .measured(result.residualNorm)),
                    ]),
                ]
            )
        case .nmf:
            let result = try GlifiMultivariateMethods.nonNegativeFactorization(
                values, rank: request.rank, seed: request.seed, restarts: request.restarts,
                maximumIterations: request.maximumIterations, tolerance: request.tolerance)
            return (
                [
                    GlifiNonNegativeFactorization.identifier,
                    GlifiNonNegativeFactorization.updateIdentifier,
                ],
                [
                    matrixTable("operators.matrix-w", result.w),
                    matrixTable("operators.matrix-h", result.h),
                    vectorTable("operators.objective-history", result.objectiveHistory),
                    metrics([
                        ("operators.objective", .measured(result.objective)),
                        ("operators.iterations", .integer(result.iterations)),
                        (
                            "operators.converged",
                            .localized("operators.boolean.\(result.converged)")
                        ),
                        ("operators.chosen-restart", .integer(result.chosenRestart)),
                    ]),
                ]
            )
        case .kMeans:
            let result = try GlifiMultivariateMethods.kMeans(
                values, clusterCount: request.clusterCount, seed: request.seed,
                restarts: request.restarts, maximumIterations: request.maximumIterations)
            return (
                [GlifiKMeansResult.identifier, GlifiKMeansResult.initializationIdentifier],
                [
                    integerTable("operators.assignments", result.assignments),
                    matrixTable("operators.centers", result.centers),
                    metrics([
                        ("operators.objective", .measured(result.objective)),
                        ("operators.iterations", .integer(result.iterations)),
                        (
                            "operators.converged",
                            .localized("operators.boolean.\(result.converged)")
                        ),
                    ]),
                ]
            )
        case .hacCutCount, .hacCutHeight:
            guard let linkage = GlifiLinkage(rawValue: request.linkage) else { throw invalid() }
            let tree = try GlifiMultivariateMethods.hierarchicalClustering(values, linkage: linkage)
            let assignments =
                request.operation == .hacCutCount
                ? try GlifiMultivariateMethods.cut(
                    tree, pointCount: values.count, clusterCount: request.clusterCount)
                : try GlifiMultivariateMethods.cut(
                    tree, pointCount: values.count, maximumHeight: request.maximumHeight)
            return (
                [GlifiHierarchicalClustering.identifier],
                [
                    integerTable("operators.assignments", assignments),
                    GlifiStudioOperatorTable(
                        titleKey: "operators.merges",
                        columns: [
                            "operators.first", "operators.second", "operators.height",
                            "operators.size",
                        ],
                        rows: tree.merges.map {
                            [
                                .integer($0.first), .integer($0.second), .measured($0.height),
                                .integer($0.size),
                            ]
                        }),
                ]
            )
        case .silhouette:
            let assignments = try integers(request.assignments)
            let result = try GlifiMultivariateMethods.silhouette(values, assignments: assignments)
            return (
                ["Silhouette-v1"],
                [
                    vectorTable("operators.widths", result.widths),
                    metrics([("operators.average", .measured(result.average))]),
                ]
            )
        case .transformCounts, .transformBinary, .transformPerThousand, .transformTFIDF:
            let transform: GlifiMatrixTransform
            switch request.operation {
            case .transformCounts: transform = .counts
            case .transformBinary: transform = .binary
            case .transformPerThousand: transform = .perThousand
            case .transformTFIDF: transform = .tfidf
            case .svd, .truncatedSVD, .pca, .lsa, .nmf, .kMeans, .hacCutCount, .hacCutHeight,
                .silhouette, .transpose, .distances, .cosine, .euclidean, .manhattan, .jaccard,
                .dice, .simpson, .weightedJaccard, .multisetDice, .kl, .jensenShannon,
                .jensenShannonDistance, .hellinger, .lidstone, .degree, .pageRank, .betweenness,
                .harmonicCloseness, .weightedBetweenness, .weightedCloseness, .weakComponents,
                .strongComponents, .eigenvector, .louvain, .modularity, .communities, .graphLayout,
                .minimumSpanningForest, .lexicalObservation,
                .zipfFit, .heapsFit:
                throw invalid()
            }
            return (
                ["matrix-transform.\(transform.rawValue)"],
                [
                    matrixTable(
                        "operators.matrix",
                        try GlifiTextMatrixOperators.transform(values, using: transform))
                ]
            )
        case .transpose:
            return (
                ["matrix-transpose"],
                [matrixTable("operators.matrix", try GlifiTextMatrixOperators.transpose(values))]
            )
        case .distances:
            guard let distance = GlifiTextDistance(rawValue: request.distance) else {
                throw invalid()
            }
            return (
                ["distance.\(request.distance)"],
                [
                    matrixTable(
                        "operators.matrix",
                        try GlifiTextMatrixOperators.dissimilarities(values, metric: distance))
                ]
            )
        case .cosine, .euclidean, .manhattan, .jaccard, .dice, .simpson, .weightedJaccard,
            .multisetDice,
            .kl, .jensenShannon, .jensenShannonDistance, .hellinger, .lidstone, .degree,
            .pageRank, .betweenness, .harmonicCloseness, .weightedBetweenness, .weightedCloseness,
            .weakComponents, .strongComponents, .eigenvector, .louvain, .modularity, .communities,
            .graphLayout, .minimumSpanningForest,
            .lexicalObservation, .zipfFit, .heapsFit:
            throw invalid()
        }
    }

    private static func similarity(_ request: GlifiStudioCoreOperatorRequest) throws
        -> (methods: [String], tables: [GlifiStudioOperatorTable])
    {
        if request.operation == .jaccard || request.operation == .dice
            || request.operation == .simpson
        {
            let first = Set(request.firstSet.split(whereSeparator: \.isWhitespace).map(String.init))
            let second = Set(
                request.secondSet.split(whereSeparator: \.isWhitespace).map(String.init))
            let value =
                request.operation == .jaccard
                ? GlifiSetSimilarity.jaccard(first, second)
                : request.operation == .dice
                    ? GlifiSetSimilarity.dice(first, second)
                    : GlifiSetSimilarity.simpson(first, second)
            return (
                [
                    request.operation == .jaccard
                        ? GlifiSetSimilarity.jaccardIdentifier
                        : request.operation == .dice
                            ? GlifiSetSimilarity.diceIdentifier
                            : GlifiSetSimilarity.simpsonIdentifier
                ], [metrics([("operators.value", .measured(value))])]
            )
        }
        let values = try numericRows(request.numbers)
        guard let first = values.first, request.operation == .lidstone || values.count == 2 else {
            throw invalid()
        }
        let second = values.count > 1 ? values[1] : []
        let value: Double
        let identifier: String
        switch request.operation {
        case .cosine:
            value = try GlifiVectorSimilarity.cosine(first, second)
            identifier = GlifiVectorSimilarity.cosineIdentifier
        case .euclidean:
            value = try GlifiVectorSimilarity.euclidean(first, second)
            identifier = GlifiVectorSimilarity.euclideanIdentifier
        case .manhattan:
            value = try GlifiVectorSimilarity.manhattan(first, second)
            identifier = GlifiVectorSimilarity.manhattanIdentifier
        case .jaccard, .dice, .simpson: throw invalid()
        case .weightedJaccard:
            value = try GlifiVectorSimilarity.weightedJaccard(first, second)
            identifier = GlifiVectorSimilarity.weightedJaccardIdentifier
        case .multisetDice:
            value = try GlifiVectorSimilarity.multisetDice(first, second)
            identifier = GlifiVectorSimilarity.multisetDiceIdentifier
        case .kl:
            value = try GlifiProbabilityDivergence.klDivergence(first, second)
            identifier = GlifiProbabilityDivergence.klIdentifier
        case .jensenShannon:
            value = try GlifiProbabilityDivergence.jensenShannonDivergence(first, second)
            identifier = GlifiProbabilityDivergence.jsDivergenceIdentifier
        case .jensenShannonDistance:
            value = try GlifiProbabilityDivergence.jensenShannonDistance(first, second)
            identifier = GlifiProbabilityDivergence.jsDistanceIdentifier
        case .hellinger:
            value = try GlifiProbabilityDivergence.hellinger(first, second)
            identifier = GlifiProbabilityDivergence.hellingerIdentifier
        case .lidstone:
            guard values.count == 1 else { throw invalid() }
            return (
                [GlifiProbabilityDivergence.lidstoneIdentifier],
                [
                    vectorTable(
                        "operators.probabilities",
                        try GlifiProbabilityDivergence.lidstone(first, alpha: request.alpha))
                ]
            )
        case .svd, .truncatedSVD, .pca, .lsa, .nmf, .kMeans, .hacCutCount, .hacCutHeight,
            .silhouette, .transformCounts, .transformBinary, .transformPerThousand,
            .transformTFIDF, .transpose, .distances, .degree, .pageRank, .betweenness,
            .harmonicCloseness, .weightedBetweenness, .weightedCloseness, .weakComponents,
            .strongComponents, .eigenvector, .louvain, .modularity, .communities, .graphLayout,
            .minimumSpanningForest, .lexicalObservation,
            .zipfFit, .heapsFit:
            throw invalid()
        }
        return ([identifier], [metrics([("operators.value", .measured(value))])])
    }

    private static func graph(_ request: GlifiStudioCoreOperatorRequest) async throws
        -> (methods: [String], tables: [GlifiStudioOperatorTable])
    {
        let nodes = lines(request.nodes)
        let edgeLines = lines(request.edges)
        guard !nodes.isEmpty, nodes.count <= maximumGraphNodes, edgeLines.count <= maximumGraphEdges
        else { throw invalid(resource: true) }
        let edges = try edgeLines.map { line -> GlifiGraphEdge<String> in
            let values = line.split(separator: "\t", omittingEmptySubsequences: false).map(
                String.init)
            guard values.count == 3 else { throw invalid() }
            return GlifiGraphEdge(
                source: values[0], target: values[1], weight: try number(values[2]))
        }
        if [.communities, .graphLayout, .minimumSpanningForest].contains(request.operation) {
            return try await advancedGraph(
                request,
                input: .init(
                    nodes: nodes,
                    edges: edges.map {
                        GlifiStudioGraphArc(source: $0.source, target: $0.target, weight: $0.weight)
                    }))
        }
        let graph = try GlifiDirectedGraph(nodes: nodes, edges: edges)
        var methods: [String] = []
        var tables: [GlifiStudioOperatorTable] = []
        func scores(_ title: String, _ values: [String: Double]) -> GlifiStudioOperatorTable {
            GlifiStudioOperatorTable(
                titleKey: title, columns: ["operators.node", "operators.value"],
                rows: nodes.map { [.text($0), .measured(values[$0] ?? 0)] })
        }
        switch request.operation {
        case .degree:
            let value = GlifiNetworkAnalysis.degree(graph)
            methods = [
                GlifiDegreeResult<String>.degreeIdentifier,
                GlifiDegreeResult<String>.weightedDegreeIdentifier,
            ]
            tables = [
                GlifiStudioOperatorTable(
                    titleKey: "operators.degrees",
                    columns: [
                        "operators.node", "operators.in-degree", "operators.out-degree",
                        "operators.weighted-in", "operators.weighted-out",
                    ],
                    rows: nodes.map {
                        [
                            .text($0), .integer(value.inDegree[$0] ?? 0),
                            .integer(value.outDegree[$0] ?? 0),
                            .measured(value.weightedInDegree[$0] ?? 0),
                            .measured(value.weightedOutDegree[$0] ?? 0),
                        ]
                    })
            ]
        case .pageRank:
            let value = try GlifiNetworkAnalysis.pageRank(
                graph, damping: request.damping, tolerance: request.tolerance,
                maximumIterations: request.maximumIterations)
            methods = [GlifiPageRankResult<String>.identifier]
            tables = [
                scores("operators.scores", value.scores),
                metrics([
                    ("operators.iterations", .integer(value.iterations)),
                    ("operators.converged", .localized("operators.boolean.\(value.converged)")),
                ]),
            ]
        case .betweenness:
            methods = [GlifiBetweennessResult<String>.identifier]
            tables = [scores("operators.scores", GlifiNetworkAnalysis.betweenness(graph).scores)]
        case .harmonicCloseness:
            methods = [GlifiHarmonicClosenessResult<String>.identifier]
            tables = [
                scores("operators.scores", GlifiNetworkAnalysis.harmonicCloseness(graph).scores)
            ]
        case .weightedBetweenness:
            methods = [
                "WeightedBetweenness-v1", GlifiNetworkAnalysis.inverseWeightDistanceIdentifier,
            ]
            tables = [
                scores("operators.scores", GlifiNetworkAnalysis.weightedBetweenness(graph).scores)
            ]
        case .weightedCloseness:
            methods = [
                "WeightedHarmonicCloseness-v1",
                GlifiNetworkAnalysis.inverseWeightDistanceIdentifier,
            ]
            tables = [
                scores(
                    "operators.scores", GlifiNetworkAnalysis.weightedHarmonicCloseness(graph).scores
                )
            ]
        case .weakComponents, .strongComponents:
            let value =
                request.operation == .weakComponents
                ? GlifiNetworkAnalysis.weakComponents(graph)
                : GlifiNetworkAnalysis.strongComponents(graph)
            methods = [
                request.operation == .weakComponents
                    ? GlifiComponentsResult<String>.weakIdentifier
                    : GlifiComponentsResult<String>.strongIdentifier
            ]
            tables = [
                GlifiStudioOperatorTable(
                    titleKey: "operators.components",
                    columns: ["operators.node", "operators.component"],
                    rows: nodes.map { [.text($0), .integer(value.componentByNode[$0] ?? 0)] }),
                metrics([("operators.component-count", .integer(value.componentCount))]),
            ]
        case .eigenvector:
            let value = try GlifiNetworkAnalysis.eigenvectorCentrality(
                graph, tolerance: request.tolerance, maximumIterations: request.maximumIterations)
            methods = [GlifiEigenvectorResult<String>.identifier]
            tables = [
                scores("operators.scores", value.scores),
                metrics([
                    ("operators.eigenvalue", .measured(value.eigenvalue)),
                    ("operators.iterations", .integer(value.iterations)),
                    ("operators.converged", .localized("operators.boolean.\(value.converged)")),
                ]),
            ]
        case .louvain:
            let value = try GlifiNetworkAnalysis.louvain(graph)
            methods = [GlifiCommunityResult<String>.identifier]
            tables = [
                GlifiStudioOperatorTable(
                    titleKey: "operators.communities",
                    columns: ["operators.node", "operators.community"],
                    rows: nodes.map { [.text($0), .integer(value.communityByNode[$0] ?? 0)] }),
                metrics([
                    ("operators.modularity", .measured(value.modularity)),
                    ("operators.community-count", .integer(value.communityCount)),
                ]),
            ]
        case .modularity:
            let labels = try integers(request.assignments)
            guard labels.count == nodes.count, labels.allSatisfy({ $0 >= 0 }) else {
                throw invalid()
            }
            methods = ["Modularity-v1"]
            tables = [
                metrics([
                    (
                        "operators.modularity",
                        .measured(
                            GlifiNetworkAnalysis.modularity(
                                graph,
                                communityByNode: Dictionary(
                                    uniqueKeysWithValues: zip(nodes, labels))))
                    )
                ])
            ]
        case .communities, .graphLayout, .minimumSpanningForest: throw invalid()
        case .svd, .truncatedSVD, .pca, .lsa, .nmf, .kMeans, .hacCutCount, .hacCutHeight,
            .silhouette, .transformCounts, .transformBinary, .transformPerThousand,
            .transformTFIDF, .transpose, .distances, .cosine, .euclidean, .manhattan, .jaccard,
            .dice, .simpson, .weightedJaccard, .multisetDice, .kl, .jensenShannon,
            .jensenShannonDistance, .hellinger, .lidstone, .lexicalObservation, .zipfFit,
            .heapsFit:
            throw invalid()
        }
        return (methods, tables)
    }

    private static func advancedGraph(
        _ request: GlifiStudioCoreOperatorRequest, input: GlifiStudioGraphInput
    ) async throws -> (methods: [String], tables: [GlifiStudioOperatorTable]) {
        let limits = GlifiStudioGraphAlgorithmLimits(
            maximumNodeCount: maximumGraphNodes, maximumEdgeCount: maximumGraphEdges,
            maximumPairwiseCells: maximumGraphNodes * maximumGraphNodes,
            maximumWork: 20_000_000)
        if request.operation == .communities {
            guard let method = GlifiStudioGraphCommunityMethod(rawValue: request.communityMethod)
            else { throw invalid() }
            let result = try await GlifiStudioGraphAlgorithms.communities(
                input, method: method, resolution: request.resolution,
                walkLength: request.walkLength, limits: limits)
            return (
                [result.methodIdentifier, result.projectionIdentifier],
                [
                    membershipTable(
                        result.nodes, result.membership, title: "operators.communities",
                        column: "operators.community"),
                    GlifiStudioOperatorTable(
                        titleKey: "operators.community-merges",
                        columns: ["operators.first", "operators.second", "operators.size"],
                        rows: result.merges.map {
                            [.integer($0.left), .integer($0.right), .integer($0.size)]
                        }),
                    arcTable("operators.removed-edges", result.removedEdges),
                    vectorTable("operators.modularity-history", result.modularityHistory),
                    metrics([
                        ("operators.modularity", .measured(result.modularity)),
                        ("operators.community-count", .integer(result.communityCount)),
                        ("operators.resolution", .measured(result.resolution)),
                    ]),
                ]
            )
        }
        if request.operation == .graphLayout {
            guard let method = GlifiStudioGraphLayoutMethod(rawValue: request.layoutMethod) else {
                throw invalid()
            }
            let positions: [GlifiStudioGraphPoint]?
            if request.usesInitialPositions {
                let rows = try numericRows(request.numbers, maximumRows: maximumGraphNodes)
                guard rows.count == input.nodes.count, rows.allSatisfy({ $0.count == 2 }) else {
                    throw invalid()
                }
                positions = rows.map { .init(x: $0[0], y: $0[1]) }
            } else {
                positions = nil
            }
            let result = try await GlifiStudioGraphAlgorithms.layout(
                input, method: method, seed: request.seed,
                maximumIterations: request.maximumIterations, tolerance: request.tolerance,
                initialPositions: positions, limits: limits)
            return (
                [result.methodIdentifier],
                [
                    GlifiStudioOperatorTable(
                        titleKey: "operators.positions",
                        columns: ["operators.node", "operators.x", "operators.y"],
                        rows: zip(result.nodes, result.positions).map {
                            [.text($0.0), .measured($0.1.x), .measured($0.1.y)]
                        }),
                    arcTable("operators.layout-edges", input.edges.filter { $0.weight > 0 }),
                    vectorTable("operators.energy-history", result.energyHistory),
                    metrics([
                        ("operators.iterations", .integer(result.iterations)),
                        (
                            "operators.converged",
                            .localized("operators.boolean.\(result.converged)")
                        ),
                    ]),
                ]
            )
        }
        guard request.operation == .minimumSpanningForest else { throw invalid() }
        let result = try await GlifiStudioGraphAlgorithms.minimumSpanningForest(
            input, limits: limits)
        return (
            [result.methodIdentifier],
            [
                arcTable("operators.forest-edges", result.edges),
                membershipTable(
                    result.nodes, result.membership, title: "operators.components",
                    column: "operators.component"),
                metrics([
                    ("operators.total-cost", .measured(result.totalWeight)),
                    ("operators.component-count", .integer(result.componentCount)),
                ]),
            ]
        )
    }

    private static func membershipTable(
        _ nodes: [String], _ memberships: [Int], title: String, column: String
    ) -> GlifiStudioOperatorTable {
        GlifiStudioOperatorTable(
            titleKey: title, columns: ["operators.node", column],
            rows: zip(nodes, memberships).map { [.text($0.0), .integer($0.1)] })
    }

    private static func arcTable(_ title: String, _ arcs: [GlifiStudioGraphArc])
        -> GlifiStudioOperatorTable
    {
        GlifiStudioOperatorTable(
            titleKey: title, columns: ["operators.source", "operators.target", "operators.weight"],
            rows: arcs.map { [.text($0.source), .text($0.target), .measured($0.weight)] })
    }

    private static func lexical(_ request: GlifiStudioCoreOperatorRequest) throws
        -> (methods: [String], tables: [GlifiStudioOperatorTable])
    {
        let documents = lines(request.documents).enumerated().map {
            GlifiLexicalSequence(
                id: "input-\($0.offset + 1)",
                tokens: $0.element.split(whereSeparator: \.isWhitespace).map(String.init))
        }
        guard documents.reduce(0, { $0 + $1.tokens.count }) <= 100_000 else {
            throw invalid(resource: true)
        }
        let distribution = try GlifiLexicalDistributionAnalysis.observe(
            documents, checkpoints: try integers(request.checkpoints),
            preprocessingIdentifier: "caller-explicit-lexical-keys-v1")
        var tables: [GlifiStudioOperatorTable] = [
            GlifiStudioOperatorTable(
                titleKey: "operators.rank-frequency",
                columns: ["operators.term", "operators.count", "operators.relative-frequency"],
                rows: distribution.rankFrequency.map {
                    [.text($0.term), .integer($0.count), .measured($0.relativeFrequency)]
                }),
            GlifiStudioOperatorTable(
                titleKey: "operators.spectrum",
                columns: ["operators.frequency", "operators.types"],
                rows: distribution.spectrum.map {
                    [.integer($0.frequency), .integer($0.typeCount)]
                }),
            GlifiStudioOperatorTable(
                titleKey: "operators.growth", columns: ["operators.tokens", "operators.types"],
                rows: distribution.growth.map { [.integer($0.tokenCount), .integer($0.typeCount)] }),
        ]
        var methods = [distribution.methodIdentifier]
        if request.operation == .zipfFit || request.operation == .heapsFit {
            let fit: GlifiLogPowerFit
            if request.operation == .zipfFit {
                let last = request.lastRank ?? distribution.rankFrequency.count
                guard request.firstRank <= last else { throw invalid() }
                fit = try GlifiLexicalDistributionAnalysis.fitZipf(
                    distribution, ranks: request.firstRank...last)
            } else {
                fit = try GlifiLexicalDistributionAnalysis.fitHeaps(distribution.growth)
            }
            methods.append(fit.methodIdentifier)
            tables.append(
                metrics([
                    ("operators.coefficient", .measured(fit.coefficient)),
                    ("operators.exponent", .measured(fit.exponent)),
                    (
                        "operators.r-squared",
                        fit.logRSquared.map(GlifiStudioOperatorCell.measured)
                            ?? .nonFinite("undefined")
                    ), ("operators.rmse", .measured(fit.logRMSE)),
                ]))
            tables.append(
                GlifiStudioOperatorTable(
                    titleKey: "operators.fit-points",
                    columns: [
                        "operators.x", "operators.observed", "operators.predicted",
                        "operators.residual",
                    ],
                    rows: fit.points.map {
                        [
                            .integer($0.x), .integer($0.observed), .measured($0.predicted),
                            .measured($0.logResidual),
                        ]
                    }))
        }
        return (methods, tables)
    }

    private static func numericRows(_ text: String, maximumRows: Int = maximumMatrixDimension)
        throws -> [[Double]]
    {
        let rows = try lines(text).map {
            try $0.split(whereSeparator: \.isWhitespace).map { try number(String($0)) }
        }
        guard rows.count <= maximumRows,
            (rows.first?.count ?? 0) <= maximumMatrixDimension
        else { throw invalid(resource: true) }
        guard let width = rows.first?.count, width > 0, rows.count <= maximumMatrixCells / width,
            rows.allSatisfy({ $0.count == width })
        else { throw invalid() }
        return rows
    }

    private static func number(_ text: String) throws -> Double {
        guard let value = GlifiStudioEditorDecimal.parse(text)
        else { throw invalid() }
        return value
    }

    private static func integers(_ text: String) throws -> [Int] {
        try text.split(whereSeparator: \.isWhitespace).map {
            guard let value = Int($0) else { throw invalid() }
            return value
        }
    }

    private static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func matrixTable(_ key: String, _ values: [[Double]]) -> GlifiStudioOperatorTable
    {
        GlifiStudioOperatorTable(
            titleKey: key, columns: ["operators.row", "operators.column", "operators.value"],
            rows: values.enumerated().flatMap { row, values in
                values.enumerated().map { column, value in
                    [.integer(row + 1), .integer(column + 1), .measured(value)]
                }
            })
    }

    private static func vectorTable(_ key: String, _ values: [Double]) -> GlifiStudioOperatorTable {
        GlifiStudioOperatorTable(
            titleKey: key, columns: ["operators.index", "operators.value"],
            rows: values.enumerated().map { [.integer($0.offset + 1), .measured($0.element)] })
    }

    private static func integerTable(_ key: String, _ values: [Int]) -> GlifiStudioOperatorTable {
        GlifiStudioOperatorTable(
            titleKey: key, columns: ["operators.index", "operators.value"],
            rows: values.enumerated().map { [.integer($0.offset + 1), .integer($0.element)] })
    }

    private static func metrics(_ values: [(String, GlifiStudioOperatorCell)])
        -> GlifiStudioOperatorTable
    {
        GlifiStudioOperatorTable(
            titleKey: "operators.diagnostics", columns: ["operators.measure", "operators.value"],
            rows: values.map { [.localized($0.0), $0.1] })
    }

    private static func invalid(resource: Bool = false) -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "operators.invalid-input",
            category: resource ? "insufficientResources" : "invalidInput", operation: "analyze",
            retryDisposition: resource ? "afterConditionsChange" : "afterCorrection",
            retainedState: "unchanged", messageKey: "failure.core-operators.input")
    }
}
