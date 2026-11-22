// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Completion operators sharing the existing bounded canonical request envelope.
public enum GlifiStudioAdvancedTextAnalysisRequest: Equatable, Sendable, Encodable {
    /// Selects topic count with explicit native diagnostics and held-out folds.
    case ldaSelection(
        documents: [[String]], candidateTopicCounts: [Int], seed: UInt64,
        options: GlifiStudioLDASelectionOptions = .init())
    /// Partitions a declared graph using a versioned community method.
    case communities(
        graph: GlifiStudioGraphInput, method: GlifiStudioGraphCommunityMethod,
        resolution: Double = 1, walkLength: Int = 4)
    /// Computes reproducible two-dimensional graph coordinates.
    case graphLayout(
        graph: GlifiStudioGraphInput, method: GlifiStudioGraphLayoutMethod,
        seed: UInt64 = 0, maximumIterations: Int = 300, tolerance: Double = 1e-6,
        initialPositions: [GlifiStudioGraphPoint]? = nil)
    /// Computes a minimum-cost forest; edge weights are costs, not affinities.
    case minimumSpanningForest(graph: GlifiStudioGraphInput)
    /// Compares seeded iterative MDS starts and retains every run diagnostic.
    case mdsSearch(
        matrix: [[Double]], dimensions: Int = 2,
        method: GlifiStudioMDSMethod = .ordinal, starts: Int = 10, seed: UInt64,
        maximumIterations: Int = 300, tolerance: Double = 1e-8)
    /// Fits explicit SOM geometry and returns U-matrix and optional Ward diagnostics.
    case somAdvanced(
        matrix: [[Double]], width: Int, height: Int, seed: UInt64,
        epochs: Int = 100, topology: GlifiStudioSOMTopology = .rectangular,
        initialRadius: Double = 2, finalRadius: Double = 0.5,
        tolerance: Double = 1e-8, codebookClusterCount: Int? = nil)
    /// Annotates text using declared native linguistic options and runtime provenance.
    case linguistic(text: String, options: GlifiStudioLinguisticOptions = .init())
    /// Inspects locally available Italian linguistic services without downloading assets.
    case linguisticAvailability(languageTag: String = "it")
    /// Evaluates coding rules over native annotations, retaining provenance per unit.
    case linguisticCoding(
        units: [GlifiStudioAutomaticCodingUnit], rules: String,
        options: GlifiStudioLinguisticOptions = .init())

    /// Stable flat operation tag shared by Swift and JSON clients.
    public var operation: String {
        switch self {
        case .ldaSelection: "lda-selection"
        case .communities: "communities"
        case .graphLayout: "graph-layout"
        case .minimumSpanningForest: "minimum-spanning-forest"
        case .mdsSearch: "mds-search"
        case .somAdvanced: "som-advanced"
        case .linguistic: "linguistic"
        case .linguisticAvailability: "linguistic-availability"
        case .linguisticCoding: "linguistic-coding"
        }
    }

    init(from decoder: any Decoder) throws {
        let f = try decoder.container(keyedBy: TextAnalysisKey.self)
        let operation: String = try f.advancedRequired("operation")
        let fields: Set<String>
        switch operation {
        case "lda-selection":
            fields = ["documents", "candidateTopicCounts", "seed", "options"]
            self = .ldaSelection(
                documents: try f.advancedRequired("documents"),
                candidateTopicCounts: try f.advancedRequired("candidateTopicCounts"),
                seed: try f.advancedRequired("seed"),
                options: try f.advancedDefault("options", .init()))
        case "communities":
            fields = ["graph", "method", "resolution", "walkLength"]
            self = .communities(
                graph: try f.advancedRequired("graph"),
                method: try f.advancedRequired("method"),
                resolution: try f.advancedDefault("resolution", 1),
                walkLength: try f.advancedDefault("walkLength", 4))
        case "graph-layout":
            fields = [
                "graph", "method", "seed", "maximumIterations", "tolerance", "initialPositions",
            ]
            self = .graphLayout(
                graph: try f.advancedRequired("graph"), method: try f.advancedRequired("method"),
                seed: try f.advancedDefault("seed", 0),
                maximumIterations: try f.advancedDefault("maximumIterations", 300),
                tolerance: try f.advancedDefault("tolerance", 1e-6),
                initialPositions: f.contains(TextAnalysisKey("initialPositions"))
                    ? try f.decode(
                        [AdvancedPointWire].self, forKey: TextAnalysisKey("initialPositions")
                    ).map(\.value) : nil)
        case "minimum-spanning-forest":
            fields = ["graph"]
            self = .minimumSpanningForest(graph: try f.advancedRequired("graph"))
        case "mds-search":
            fields = [
                "matrix", "dimensions", "method", "starts", "seed", "maximumIterations",
                "tolerance",
            ]
            self = .mdsSearch(
                matrix: try f.advancedRequired("matrix"),
                dimensions: try f.advancedDefault("dimensions", 2),
                method: try f.advancedDefault("method", .ordinal),
                starts: try f.advancedDefault("starts", 10),
                seed: try f.advancedRequired("seed"),
                maximumIterations: try f.advancedDefault("maximumIterations", 300),
                tolerance: try f.advancedDefault("tolerance", 1e-8))
        case "som-advanced":
            fields = [
                "matrix", "width", "height", "seed", "epochs", "topology", "initialRadius",
                "finalRadius", "tolerance", "codebookClusterCount",
            ]
            self = .somAdvanced(
                matrix: try f.advancedRequired("matrix"), width: try f.advancedRequired("width"),
                height: try f.advancedRequired("height"), seed: try f.advancedRequired("seed"),
                epochs: try f.advancedDefault("epochs", 100),
                topology: try f.advancedDefault("topology", .rectangular),
                initialRadius: try f.advancedDefault("initialRadius", 2),
                finalRadius: try f.advancedDefault("finalRadius", 0.5),
                tolerance: try f.advancedDefault("tolerance", 1e-8),
                codebookClusterCount: f.contains(TextAnalysisKey("codebookClusterCount"))
                    ? try f.decode(Int.self, forKey: TextAnalysisKey("codebookClusterCount")) : nil)
        case "linguistic":
            fields = ["text", "options"]
            self = .linguistic(
                text: try f.advancedRequired("text"),
                options: try f.advancedDefault("options", .init()))
        case "linguistic-availability":
            fields = ["languageTag"]
            self = .linguisticAvailability(languageTag: try f.advancedDefault("languageTag", "it"))
        case "linguistic-coding":
            fields = ["units", "rules", "options"]
            let units = try f.decode([TextAnalysisUnitWire].self, forKey: TextAnalysisKey("units"))
                .map(\.value)
            self = .linguisticCoding(
                units: units, rules: try f.advancedRequired("rules"),
                options: try f.advancedDefault("options", .init()))
        default: throw textRequestFailure("text-analysis.unknown-operation")
        }
        let allowed = fields.union(["schema", "schemaVersion", "operation"])
        guard f.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
    }

    func validate(budget: inout TextAnalysisBudget) throws {
        switch self {
        case let .ldaSelection(documents, candidates, _, options):
            try budget.documents(documents)
            try budget.integers(candidates)
            guard candidates.count <= 32 else {
                throw textRequestFailure(
                    "text-analysis.collection-limit", category: "insufficientResources")
            }
            try finite([options.alpha, options.beta])
        case let .communities(graph, _, resolution, _):
            try budget.graph(graph)
            try finite([resolution])
        case let .graphLayout(graph, _, _, _, tolerance, positions):
            try budget.graph(graph)
            try finite([tolerance])
            if let positions { try budget.points(positions) }
        case let .minimumSpanningForest(graph): try budget.graph(graph)
        case let .mdsSearch(matrix, _, _, _, _, _, tolerance):
            try budget.matrix(matrix)
            try finite([tolerance])
        case let .somAdvanced(matrix, _, _, _, _, _, initial, final, tolerance, _):
            try budget.matrix(matrix)
            try finite([initial, final, tolerance])
        case let .linguistic(text, options):
            try budget.string(text)
            try budget.string(options.languageTag)
        case let .linguisticAvailability(language): try budget.string(language)
        case let .linguisticCoding(units, rules, options):
            try budget.units(units)
            try budget.string(rules)
            try budget.string(options.languageTag)
        }
    }

    /// Writes the existing versioned envelope with explicit resolved defaults.
    public func encode(to encoder: any Encoder) throws {
        var f = encoder.container(keyedBy: TextAnalysisKey.self)
        try f.advancedEncode("schema", GlifiStudioTextAnalysisRequest.schema)
        try f.advancedEncode("schemaVersion", GlifiStudioTextAnalysisRequest.schemaVersion)
        try f.advancedEncode("operation", operation)
        switch self {
        case let .ldaSelection(documents, candidates, seed, options):
            try f.advancedEncode("documents", documents)
            try f.advancedEncode("candidateTopicCounts", candidates)
            try f.advancedEncode("seed", seed)
            try f.advancedEncode("options", options)
        case let .communities(graph, method, resolution, walkLength):
            try f.advancedEncode("graph", graph)
            try f.advancedEncode("method", method)
            try f.advancedEncode("resolution", resolution)
            try f.advancedEncode("walkLength", walkLength)
        case let .graphLayout(graph, method, seed, iterations, tolerance, positions):
            try f.advancedEncode("graph", graph)
            try f.advancedEncode("method", method)
            try f.advancedEncode("seed", seed)
            try f.advancedEncode("maximumIterations", iterations)
            try f.advancedEncode("tolerance", tolerance)
            if let positions { try f.advancedEncode("initialPositions", positions) }
        case let .minimumSpanningForest(graph): try f.advancedEncode("graph", graph)
        case let .mdsSearch(matrix, dimensions, method, starts, seed, iterations, tolerance):
            try f.advancedEncode("matrix", matrix)
            try f.advancedEncode("dimensions", dimensions)
            try f.advancedEncode("method", method)
            try f.advancedEncode("starts", starts)
            try f.advancedEncode("seed", seed)
            try f.advancedEncode("maximumIterations", iterations)
            try f.advancedEncode("tolerance", tolerance)
        case let .somAdvanced(
            matrix, width, height, seed, epochs, topology, initial, final, tolerance, clusters):
            try f.advancedEncode("matrix", matrix)
            try f.advancedEncode("width", width)
            try f.advancedEncode("height", height)
            try f.advancedEncode("seed", seed)
            try f.advancedEncode("epochs", epochs)
            try f.advancedEncode("topology", topology)
            try f.advancedEncode("initialRadius", initial)
            try f.advancedEncode("finalRadius", final)
            try f.advancedEncode("tolerance", tolerance)
            if let clusters { try f.advancedEncode("codebookClusterCount", clusters) }
        case let .linguistic(text, options):
            try f.advancedEncode("text", text)
            try f.advancedEncode("options", options)
        case let .linguisticAvailability(language): try f.advancedEncode("languageTag", language)
        case let .linguisticCoding(units, rules, options):
            try f.advancedEncode("units", units)
            try f.advancedEncode("rules", rules)
            try f.advancedEncode("options", options)
        }
    }

    @concurrent func execute() async throws(GlifiStudioFailure) -> (
        String, GlifiStudioAdvancedTextAnalysisPayload
    ) {
        switch self {
        case let .ldaSelection(documents, candidates, seed, options):
            let result = try await GlifiStudioLDAModelSelection.select(
                documents: documents, candidateTopicCounts: candidates, seed: seed, options: options
            )
            return (result.methodIdentifier, .ldaSelection(result))
        case let .communities(graph, method, resolution, walkLength):
            let result = try await GlifiStudioGraphAlgorithms.communities(
                graph, method: method, resolution: resolution, walkLength: walkLength)
            return (result.methodIdentifier, .communities(result))
        case let .graphLayout(graph, method, seed, iterations, tolerance, positions):
            let result = try await GlifiStudioGraphAlgorithms.layout(
                graph, method: method,
                seed: seed, maximumIterations: iterations, tolerance: tolerance,
                initialPositions: positions)
            return (result.methodIdentifier, .graphLayout(result))
        case let .minimumSpanningForest(graph):
            let result = try await GlifiStudioGraphAlgorithms.minimumSpanningForest(graph)
            return (result.methodIdentifier, .minimumSpanningForest(result))
        case let .mdsSearch(matrix, dimensions, method, starts, seed, iterations, tolerance):
            let result = try await GlifiStudioExploratoryCompletion.multidimensionalScalingSearch(
                matrix, dimensions: dimensions, method: method, starts: starts, seed: seed,
                maximumIterations: iterations, tolerance: tolerance)
            return (result.methodIdentifier, .mdsSearch(result))
        case let .somAdvanced(
            matrix, width, height, seed, epochs, topology, initial, final, tolerance, clusters):
            let result = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
                matrix, width: width, height: height, seed: seed, epochs: epochs,
                topology: topology,
                initialRadius: initial, finalRadius: final, tolerance: tolerance,
                codebookClusterCount: clusters)
            return (result.map.methodIdentifier, .somAdvanced(result))
        case let .linguistic(text, options):
            let result = try await GlifiStudioLinguisticPipeline.annotate(text, options: options)
            return (result.methodIdentifier, .linguistic(result))
        case let .linguisticAvailability(language):
            let result = try await GlifiStudioLinguisticPipeline.availability(languageTag: language)
            return (result.methodIdentifier, .linguisticAvailability(result))
        case let .linguisticCoding(units, rules, options):
            let result = try await GlifiStudioLinguisticPipeline.codeAnnotated(
                units, rules: rules, options: options)
            return (result.methodIdentifier, .linguisticCoding(result))
        }
    }
}

/// Typed completion results for native clients and the canonical JSON envelope.
public enum GlifiStudioAdvancedTextAnalysisPayload: Encodable, Sendable {
    /// Selects topic count with explicit native diagnostics and held-out folds.
    case ldaSelection(GlifiStudioLDAModelSelectionResult)
    /// Partitions a declared graph using a versioned community method.
    case communities(GlifiStudioGraphCommunityResult)
    /// Computes reproducible two-dimensional graph coordinates.
    case graphLayout(GlifiStudioGraphLayoutResult)
    /// Computes a minimum-cost forest; edge weights are costs, not affinities.
    case minimumSpanningForest(GlifiStudioMinimumSpanningForest)
    /// Compares seeded iterative MDS starts and retains every run diagnostic.
    case mdsSearch(GlifiStudioMDSSearchResult)
    /// Fits explicit SOM geometry and returns U-matrix and optional Ward diagnostics.
    case somAdvanced(GlifiStudioAdvancedSOMResult)
    case linguistic(GlifiStudioLinguisticAnnotation)
    /// Inspects locally available Italian linguistic services without downloading assets.
    case linguisticAvailability(GlifiStudioLinguisticAvailability)
    /// Evaluates coding rules over native annotations, retaining provenance per unit.
    case linguisticCoding(GlifiStudioAnnotatedCodingResult)

    /// Encodes exactly the selected numerical or linguistic result.
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .ldaSelection(result): try result.encode(to: encoder)
        case let .communities(result): try result.encode(to: encoder)
        case let .graphLayout(result): try result.encode(to: encoder)
        case let .minimumSpanningForest(result): try result.encode(to: encoder)
        case let .mdsSearch(result): try result.encode(to: encoder)
        case let .somAdvanced(result): try result.encode(to: encoder)
        case let .linguistic(result): try result.encode(to: encoder)
        case let .linguisticAvailability(result): try result.encode(to: encoder)
        case let .linguisticCoding(result): try result.encode(to: encoder)
        }
    }
}

private struct AdvancedPointWire: Decodable {
    let value: GlifiStudioGraphPoint
    init(from decoder: any Decoder) throws {
        let f = try decoder.container(keyedBy: TextAnalysisKey.self)
        guard f.allKeys.allSatisfy({ $0.stringValue == "x" || $0.stringValue == "y" }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
        value = GlifiStudioGraphPoint(
            x: try f.advancedRequired("x"), y: try f.advancedRequired("y"))
    }
}

private func finite(_ values: [Double]) throws {
    guard values.allSatisfy(\.isFinite) else {
        throw textRequestFailure("text-analysis.non-finite")
    }
}

private extension KeyedDecodingContainer where Key == TextAnalysisKey {
    func advancedRequired<Value: Decodable>(_ name: String) throws -> Value {
        try decode(Value.self, forKey: TextAnalysisKey(name))
    }
    func advancedDefault<Value: Decodable>(_ name: String, _ fallback: Value) throws -> Value {
        try decode(Value.self, forKey: TextAnalysisKey(name), fallback: fallback)
    }
}

private extension KeyedEncodingContainer where Key == TextAnalysisKey {
    mutating func advancedEncode<Value: Encodable>(_ name: String, _ value: Value) throws {
        try encode(value, forKey: TextAnalysisKey(name))
    }
}
