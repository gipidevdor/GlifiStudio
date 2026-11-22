// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

/// Versioned, bounded requests shared by native clients and the command-line client.
///
/// Use `decode(_:)` for external JSON; omitted defaults are resolved before hashing.
public enum GlifiStudioTextAnalysisRequest: Equatable, Sendable, Encodable {
    /// Maximum external and canonical request size in bytes.
    public static let maximumRequestBytes = 1_048_576
    /// Transport schema, independent of the project package format.
    public static let schema = "studio.glifi.text-analysis-request"
    /// Current transport version.
    public static let schemaVersion = 1

    /// Parameters for the mds operator; computation uses the existing native facade.
    case mds(
        matrix: [[Double]], dimensions: Int = 2, method: GlifiStudioMDSMethod = .classical,
        seed: UInt64 = 0, maximumIterations: Int = 300)
    /// Parameters for the som operator; computation uses the existing native facade.
    case som(matrix: [[Double]], width: Int, height: Int, seed: UInt64, epochs: Int = 100)
    /// Parameters for the clara operator; computation uses the existing native facade.
    case clara(matrix: [[Double]], clusterCount: Int, seed: UInt64, sampleSize: Int = 100)
    /// Parameters for the classify operator; computation uses the existing native facade.
    case classify(
        documents: [[String]], labels: [String], predictionDocuments: [[String]],
        smoothing: Double = 1)
    /// Parameters for the validate-classifier operator; computation uses the existing native facade.
    case validateClassifier(documents: [[String]], labels: [String], folds: Int, seed: UInt64)
    /// Parameters for the lda operator; computation uses the existing native facade.
    case lda(
        documents: [[String]], topicCount: Int, seed: UInt64, alpha: Double = 0.1,
        beta: Double = 0.01, burnIn: Int = 100, sampleCount: Int = 20, thinning: Int = 5)
    /// Parameters for the coding operator; computation uses the existing native facade.
    case coding(units: [GlifiStudioAutomaticCodingUnit], rules: String)
    /// Parameters for the code-crosstab operator; computation uses the existing native facade.
    case codeCrosstab(units: [GlifiStudioAutomaticCodingUnit], rules: String, groups: [String?])
    /// Parameters for the dissimilarities operator; computation uses the existing native facade.
    case dissimilarities(matrix: [[Double]], metric: GlifiStudioTextDistance)
    /// Parameters for the correspondence operator; computation uses the existing native facade.
    case correspondence(matrix: [[Double]])
    /// Parameters for the hierarchical operator; computation uses the existing native facade.
    case hierarchical(matrix: [[Double]], linkage: String = "average")
    /// Parameters for the network operator; computation uses the existing native facade.
    case network(
        matrix: [[Double]], labels: [String], minimumJaccard: Double = 0.1,
        maximumEdges: Int = 10_000)

    /// Stable operation tag.
    public var operation: String {
        switch self {
        case .mds: "mds"
        case .som: "som"
        case .clara: "clara"
        case .classify: "classify"
        case .validateClassifier: "validate-classifier"
        case .lda: "lda"
        case .coding: "coding"
        case .codeCrosstab: "code-crosstab"
        case .dissimilarities: "dissimilarities"
        case .correspondence: "correspondence"
        case .hierarchical: "hierarchical"
        case .network: "network"
        }
    }

    /// Decodes an external request without exposing parser causes or source content.
    public static func decode(_ data: Data) throws(GlifiStudioFailure) -> Self {
        do {
            try TextAnalysisJSON.check(data)
            return try JSONDecoder().decode(TextAnalysisWire.self, from: data).value
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw textRequestFailure("text-analysis.invalid-request")
        }
    }

    /// Encodes resolved parameters with sorted keys, after enforcing transport budgets.
    public func canonicalData() throws(GlifiStudioFailure) -> Data {
        do {
            var budget = TextAnalysisBudget()
            switch self {
            case let .mds(matrix, _, _, _, _):
                try budget.matrix(matrix)
            case let .som(matrix, _, _, _, _):
                try budget.matrix(matrix)
            case let .clara(matrix, _, _, _):
                try budget.matrix(matrix)
            case let .classify(documents, labels, predictionDocuments, smoothing):
                try budget.documents(documents)
                try budget.strings(labels)
                try budget.documents(predictionDocuments)
                guard smoothing.isFinite else {
                    throw textRequestFailure("text-analysis.non-finite")
                }
            case let .validateClassifier(documents, labels, _, _):
                try budget.documents(documents)
                try budget.strings(labels)
            case let .lda(documents, _, _, alpha, beta, _, _, _):
                try budget.documents(documents)
                guard alpha.isFinite else { throw textRequestFailure("text-analysis.non-finite") }
                guard beta.isFinite else { throw textRequestFailure("text-analysis.non-finite") }
            case let .coding(units, rules):
                try budget.units(units)
                try budget.string(rules)
            case let .codeCrosstab(units, rules, groups):
                try budget.units(units)
                try budget.string(rules)
                try budget.optionalStrings(groups)
            case let .dissimilarities(matrix, _):
                try budget.matrix(matrix)
            case let .correspondence(matrix):
                try budget.matrix(matrix)
            case let .hierarchical(matrix, linkage):
                try budget.matrix(matrix)
                try budget.string(linkage)
            case let .network(matrix, labels, minimumJaccard, _):
                try budget.matrix(matrix)
                try budget.strings(labels)
                guard minimumJaccard.isFinite else {
                    throw textRequestFailure("text-analysis.non-finite")
                }
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(self)
            guard data.count <= Self.maximumRequestBytes else {
                throw textRequestFailure(
                    "text-analysis.request-limit", category: "insufficientResources")
            }
            return data
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw textRequestFailure("text-analysis.invalid-request")
        }
    }

    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: TextAnalysisKey.self)
        guard try fields.decode(String.self, forKey: TextAnalysisKey("schema")) == Self.schema
        else {
            throw textRequestFailure("text-analysis.invalid-schema")
        }
        guard
            try fields.decode(Int.self, forKey: TextAnalysisKey("schemaVersion"))
                == Self.schemaVersion
        else {
            throw textRequestFailure(
                "text-analysis.incompatible-version", category: "incompatibleVersion")
        }
        let operation = try fields.decode(String.self, forKey: TextAnalysisKey("operation"))
        let allowed: Set<String>
        switch operation {
        case "mds":
            allowed = [
                "schema", "schemaVersion", "operation", "matrix", "dimensions", "method", "seed",
                "maximumIterations",
            ]
            self = .mds(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix")),
                dimensions: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("dimensions"), fallback: 2),
                method: try fields.decode(
                    GlifiStudioMDSMethod.self, forKey: TextAnalysisKey("method"),
                    fallback: .classical),
                seed: try fields.decode(UInt64.self, forKey: TextAnalysisKey("seed"), fallback: 0),
                maximumIterations: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("maximumIterations"), fallback: 300)
            )
        case "som":
            allowed = [
                "schema", "schemaVersion", "operation", "matrix", "width", "height", "seed",
                "epochs",
            ]
            self = .som(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix")),
                width: try fields.decode(Int.self, forKey: TextAnalysisKey("width")),
                height: try fields.decode(Int.self, forKey: TextAnalysisKey("height")),
                seed: try fields.decode(UInt64.self, forKey: TextAnalysisKey("seed")),
                epochs: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("epochs"), fallback: 100)
            )
        case "clara":
            allowed = [
                "schema", "schemaVersion", "operation", "matrix", "clusterCount", "seed",
                "sampleSize",
            ]
            self = .clara(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix")),
                clusterCount: try fields.decode(Int.self, forKey: TextAnalysisKey("clusterCount")),
                seed: try fields.decode(UInt64.self, forKey: TextAnalysisKey("seed")),
                sampleSize: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("sampleSize"), fallback: 100)
            )
        case "classify":
            allowed = [
                "schema", "schemaVersion", "operation", "documents", "labels",
                "predictionDocuments", "smoothing",
            ]
            self = .classify(
                documents: try fields.decode([[String]].self, forKey: TextAnalysisKey("documents")),
                labels: try fields.decode([String].self, forKey: TextAnalysisKey("labels")),
                predictionDocuments: try fields.decode(
                    [[String]].self, forKey: TextAnalysisKey("predictionDocuments")),
                smoothing: try fields.decode(
                    Double.self, forKey: TextAnalysisKey("smoothing"), fallback: 1)
            )
        case "validate-classifier":
            allowed = [
                "schema", "schemaVersion", "operation", "documents", "labels", "folds", "seed",
            ]
            self = .validateClassifier(
                documents: try fields.decode([[String]].self, forKey: TextAnalysisKey("documents")),
                labels: try fields.decode([String].self, forKey: TextAnalysisKey("labels")),
                folds: try fields.decode(Int.self, forKey: TextAnalysisKey("folds")),
                seed: try fields.decode(UInt64.self, forKey: TextAnalysisKey("seed"))
            )
        case "lda":
            allowed = [
                "schema", "schemaVersion", "operation", "documents", "topicCount", "seed", "alpha",
                "beta", "burnIn", "sampleCount", "thinning",
            ]
            self = .lda(
                documents: try fields.decode([[String]].self, forKey: TextAnalysisKey("documents")),
                topicCount: try fields.decode(Int.self, forKey: TextAnalysisKey("topicCount")),
                seed: try fields.decode(UInt64.self, forKey: TextAnalysisKey("seed")),
                alpha: try fields.decode(
                    Double.self, forKey: TextAnalysisKey("alpha"), fallback: 0.1),
                beta: try fields.decode(
                    Double.self, forKey: TextAnalysisKey("beta"), fallback: 0.01),
                burnIn: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("burnIn"), fallback: 100),
                sampleCount: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("sampleCount"), fallback: 20),
                thinning: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("thinning"), fallback: 5)
            )
        case "coding":
            allowed = ["schema", "schemaVersion", "operation", "units", "rules"]
            self = .coding(
                units: try fields.decode(
                    [TextAnalysisUnitWire].self, forKey: TextAnalysisKey("units")
                ).map(\.value),
                rules: try fields.decode(String.self, forKey: TextAnalysisKey("rules"))
            )
        case "code-crosstab":
            allowed = ["schema", "schemaVersion", "operation", "units", "rules", "groups"]
            self = .codeCrosstab(
                units: try fields.decode(
                    [TextAnalysisUnitWire].self, forKey: TextAnalysisKey("units")
                ).map(\.value),
                rules: try fields.decode(String.self, forKey: TextAnalysisKey("rules")),
                groups: try fields.decode([String?].self, forKey: TextAnalysisKey("groups"))
            )
        case "dissimilarities":
            allowed = ["schema", "schemaVersion", "operation", "matrix", "metric"]
            self = .dissimilarities(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix")),
                metric: try fields.decode(
                    GlifiStudioTextDistance.self, forKey: TextAnalysisKey("metric"))
            )
        case "correspondence":
            allowed = ["schema", "schemaVersion", "operation", "matrix"]
            self = .correspondence(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix"))
            )
        case "hierarchical":
            allowed = ["schema", "schemaVersion", "operation", "matrix", "linkage"]
            self = .hierarchical(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix")),
                linkage: try fields.decode(
                    String.self, forKey: TextAnalysisKey("linkage"), fallback: "average")
            )
        case "network":
            allowed = [
                "schema", "schemaVersion", "operation", "matrix", "labels", "minimumJaccard",
                "maximumEdges",
            ]
            self = .network(
                matrix: try fields.decode([[Double]].self, forKey: TextAnalysisKey("matrix")),
                labels: try fields.decode([String].self, forKey: TextAnalysisKey("labels")),
                minimumJaccard: try fields.decode(
                    Double.self, forKey: TextAnalysisKey("minimumJaccard"), fallback: 0.1),
                maximumEdges: try fields.decode(
                    Int.self, forKey: TextAnalysisKey("maximumEdges"), fallback: 10_000)
            )
        default:
            throw textRequestFailure("text-analysis.unknown-operation")
        }
        guard fields.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
    }

    /// Writes the resolved, tagged schema.
    ///
    /// Prefer `canonicalData()` at external boundaries.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: TextAnalysisKey.self)
        try fields.encode(Self.schema, forKey: TextAnalysisKey("schema"))
        try fields.encode(Self.schemaVersion, forKey: TextAnalysisKey("schemaVersion"))
        try fields.encode(operation, forKey: TextAnalysisKey("operation"))
        switch self {
        case let .mds(matrix, dimensions, method, seed, maximumIterations):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
            try fields.encode(dimensions, forKey: TextAnalysisKey("dimensions"))
            try fields.encode(method, forKey: TextAnalysisKey("method"))
            try fields.encode(seed, forKey: TextAnalysisKey("seed"))
            try fields.encode(maximumIterations, forKey: TextAnalysisKey("maximumIterations"))
        case let .som(matrix, width, height, seed, epochs):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
            try fields.encode(width, forKey: TextAnalysisKey("width"))
            try fields.encode(height, forKey: TextAnalysisKey("height"))
            try fields.encode(seed, forKey: TextAnalysisKey("seed"))
            try fields.encode(epochs, forKey: TextAnalysisKey("epochs"))
        case let .clara(matrix, clusterCount, seed, sampleSize):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
            try fields.encode(clusterCount, forKey: TextAnalysisKey("clusterCount"))
            try fields.encode(seed, forKey: TextAnalysisKey("seed"))
            try fields.encode(sampleSize, forKey: TextAnalysisKey("sampleSize"))
        case let .classify(documents, labels, predictionDocuments, smoothing):
            try fields.encode(documents, forKey: TextAnalysisKey("documents"))
            try fields.encode(labels, forKey: TextAnalysisKey("labels"))
            try fields.encode(predictionDocuments, forKey: TextAnalysisKey("predictionDocuments"))
            try fields.encode(smoothing, forKey: TextAnalysisKey("smoothing"))
        case let .validateClassifier(documents, labels, folds, seed):
            try fields.encode(documents, forKey: TextAnalysisKey("documents"))
            try fields.encode(labels, forKey: TextAnalysisKey("labels"))
            try fields.encode(folds, forKey: TextAnalysisKey("folds"))
            try fields.encode(seed, forKey: TextAnalysisKey("seed"))
        case let .lda(documents, topicCount, seed, alpha, beta, burnIn, sampleCount, thinning):
            try fields.encode(documents, forKey: TextAnalysisKey("documents"))
            try fields.encode(topicCount, forKey: TextAnalysisKey("topicCount"))
            try fields.encode(seed, forKey: TextAnalysisKey("seed"))
            try fields.encode(alpha, forKey: TextAnalysisKey("alpha"))
            try fields.encode(beta, forKey: TextAnalysisKey("beta"))
            try fields.encode(burnIn, forKey: TextAnalysisKey("burnIn"))
            try fields.encode(sampleCount, forKey: TextAnalysisKey("sampleCount"))
            try fields.encode(thinning, forKey: TextAnalysisKey("thinning"))
        case let .coding(units, rules):
            try fields.encode(units, forKey: TextAnalysisKey("units"))
            try fields.encode(rules, forKey: TextAnalysisKey("rules"))
        case let .codeCrosstab(units, rules, groups):
            try fields.encode(units, forKey: TextAnalysisKey("units"))
            try fields.encode(rules, forKey: TextAnalysisKey("rules"))
            try fields.encode(groups, forKey: TextAnalysisKey("groups"))
        case let .dissimilarities(matrix, metric):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
            try fields.encode(metric, forKey: TextAnalysisKey("metric"))
        case let .correspondence(matrix):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
        case let .hierarchical(matrix, linkage):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
            try fields.encode(linkage, forKey: TextAnalysisKey("linkage"))
        case let .network(matrix, labels, minimumJaccard, maximumEdges):
            try fields.encode(matrix, forKey: TextAnalysisKey("matrix"))
            try fields.encode(labels, forKey: TextAnalysisKey("labels"))
            try fields.encode(minimumJaccard, forKey: TextAnalysisKey("minimumJaccard"))
            try fields.encode(maximumEdges, forKey: TextAnalysisKey("maximumEdges"))
        }
    }
}

/// A complete transient result with the identity of both request and method.
public struct GlifiStudioTextAnalysisResult: Encodable, Sendable {
    /// Transport result schema.
    public let schema = "studio.glifi.text-analysis-result"
    /// Result transport version.
    public let schemaVersion = 1
    /// Operator tag.
    public let operation: String
    /// Lowercase SHA-256 of the canonical resolved request.
    public let requestDigest: String
    /// Scientific algorithm identifier, independent of transport version.
    public let methodIdentifier: String
    /// Conservative, method-scoped validation status.
    public let validationStatus: String
    private let payload: TextAnalysisPayload

    fileprivate init(
        request: GlifiStudioTextAnalysisRequest, canonical: Data,
        methodIdentifier: String, payload: TextAnalysisPayload
    ) {
        operation = request.operation
        requestDigest = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        self.methodIdentifier = methodIdentifier
        validationStatus = GlifiStudioTextAnalytics.validationStatus(forMethod: methodIdentifier)
        self.payload = payload
    }

    /// Writes metadata and exactly one result payload.
    public func encode(to encoder: any Encoder) throws {
        var fields = encoder.container(keyedBy: TextAnalysisKey.self)
        try fields.encode(schema, forKey: TextAnalysisKey("schema"))
        try fields.encode(schemaVersion, forKey: TextAnalysisKey("schemaVersion"))
        try fields.encode(operation, forKey: TextAnalysisKey("operation"))
        try fields.encode(requestDigest, forKey: TextAnalysisKey("requestDigest"))
        try fields.encode(methodIdentifier, forKey: TextAnalysisKey("methodIdentifier"))
        try fields.encode(validationStatus, forKey: TextAnalysisKey("validationStatus"))
        try payload.encode(to: fields.superEncoder(forKey: TextAnalysisKey("result")))
    }
}

private enum TextAnalysisPayload: Encodable, Sendable {
    case mds(GlifiStudioMDSResult)
    case som(GlifiStudioSOMResult)
    case clara(GlifiStudioCLARAResult)
    case classify(GlifiStudioClassification)
    case validateClassifier(GlifiStudioClassificationEvaluation)
    case lda(GlifiStudioLDAResult)
    case coding(GlifiStudioCodingMatrix)
    case codeCrosstab(GlifiStudioCodeCrosstab)
    case dissimilarities([[Double]])
    case correspondence(GlifiStudioMatrixCorrespondence)
    case hierarchical(GlifiStudioMatrixClustering)
    case network(GlifiStudioMatrixNetwork)

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .mds(value): try value.encode(to: encoder)
        case let .som(value): try value.encode(to: encoder)
        case let .clara(value): try value.encode(to: encoder)
        case let .classify(value): try value.encode(to: encoder)
        case let .validateClassifier(value): try value.encode(to: encoder)
        case let .lda(value): try value.encode(to: encoder)
        case let .coding(value): try value.encode(to: encoder)
        case let .codeCrosstab(value): try value.encode(to: encoder)
        case let .dissimilarities(value): try value.encode(to: encoder)
        case let .correspondence(value): try value.encode(to: encoder)
        case let .hierarchical(value): try value.encode(to: encoder)
        case let .network(value): try value.encode(to: encoder)
        }
    }
}

extension GlifiStudioTextAnalytics {
    /// Executes external JSON off the caller's actor through the same typed native path.
    @concurrent public static func executeTextAnalysis(
        json data: Data
    ) async throws(GlifiStudioFailure) -> GlifiStudioTextAnalysisResult {
        try await executeTextAnalysis(GlifiStudioTextAnalysisRequest.decode(data))
    }

    /// Executes a resolved request with bounded resources and no project mutation.
    @concurrent public static func executeTextAnalysis(
        _ request: GlifiStudioTextAnalysisRequest
    ) async throws(GlifiStudioFailure) -> GlifiStudioTextAnalysisResult {
        guard !Task.isCancelled else {
            throw textRequestFailure("operation.cancelled", category: "cancelled")
        }
        let canonical = try request.canonicalData()
        let result: GlifiStudioTextAnalysisResult
        switch request {
        case let .mds(matrix, dimensions, method, seed, maximumIterations):
            let value = try await multidimensionalScaling(
                matrix, dimensions: dimensions, method: method, seed: seed,
                maximumIterations: maximumIterations)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: value.methodIdentifier, payload: .mds(value))
        case let .som(matrix, width, height, seed, epochs):
            let value = try await selfOrganizingMap(
                matrix, width: width, height: height, seed: seed, epochs: epochs)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: value.methodIdentifier, payload: .som(value))
        case let .clara(matrix, clusterCount, seed, sampleSize):
            let value = try await clara(
                matrix, clusterCount: clusterCount, seed: seed, sampleSize: sampleSize)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: value.methodIdentifier, payload: .clara(value))
        case let .classify(documents, labels, predictionDocuments, smoothing):
            let value = try await trainClassifier(
                documents: documents, labels: labels, smoothing: smoothing
            ).predict(predictionDocuments)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: GlifiNaiveBayesModel.identifier, payload: .classify(value))
        case let .validateClassifier(documents, labels, folds, seed):
            let value = try await validateClassifier(
                documents: documents, labels: labels, folds: folds, seed: seed)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: "MultinomialNaiveBayes-stratified-CV-v1",
                payload: .validateClassifier(value))
        case let .lda(documents, topicCount, seed, alpha, beta, burnIn, sampleCount, thinning):
            let value = try await topics(
                documents: documents, topicCount: topicCount, seed: seed, alpha: alpha, beta: beta,
                burnIn: burnIn, sampleCount: sampleCount, thinning: thinning)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: value.methodIdentifier, payload: .lda(value))
        case let .coding(units, rules):
            let value = try await code(units, rules: rules)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: GlifiCodingRuleSet.identifier, payload: .coding(value))
        case let .codeCrosstab(units, rules, groups):
            let value = try await code(units, rules: rules).crosstab(groups: groups)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: "KH-coding-binary-crosstab-v1", payload: .codeCrosstab(value))
        case let .dissimilarities(matrix, metric):
            let value = try await dissimilarities(matrix, metric: metric)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: "Text-distance-\(metric.rawValue)-v1",
                payload: .dissimilarities(value))
        case let .correspondence(matrix):
            let value = try await correspondenceAnalysis(matrix)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: value.methodIdentifier, payload: .correspondence(value))
        case let .hierarchical(matrix, linkage):
            let value = try await hierarchicalClustering(dissimilarities: matrix, linkage: linkage)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: "HAC-dissimilarities-\(linkage)-v1", payload: .hierarchical(value)
            )
        case let .network(matrix, labels, minimumJaccard, maximumEdges):
            let value = try await cooccurrenceNetwork(
                matrix, labels: labels, minimumJaccard: minimumJaccard, maximumEdges: maximumEdges)
            result = GlifiStudioTextAnalysisResult(
                request: request, canonical: canonical,
                methodIdentifier: "Column-Jaccard-network-v1", payload: .network(value))
        }
        guard !Task.isCancelled else {
            throw textRequestFailure("operation.cancelled", category: "cancelled")
        }
        return result
    }
}

private struct TextAnalysisWire: Decodable {
    let value: GlifiStudioTextAnalysisRequest
    init(from decoder: any Decoder) throws {
        value = try GlifiStudioTextAnalysisRequest(from: decoder)
    }
}

private struct TextAnalysisUnitWire: Decodable {
    let value: GlifiStudioAutomaticCodingUnit
    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: TextAnalysisKey.self)
        let allowed: Set<String> = ["id", "text", "variables"]
        guard fields.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw textRequestFailure("text-analysis.unknown-field")
        }
        value = GlifiStudioAutomaticCodingUnit(
            id: try fields.decode(String.self, forKey: TextAnalysisKey("id")),
            text: try fields.decode(String.self, forKey: TextAnalysisKey("text")),
            variables: try fields.decode(
                [String: String].self, forKey: TextAnalysisKey("variables"), fallback: [:]))
    }
}

struct TextAnalysisKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

extension KeyedDecodingContainer where Key == TextAnalysisKey {
    func decode<Value: Decodable>(_ type: Value.Type, forKey key: Key, fallback: Value) throws
        -> Value
    {
        contains(key) ? try decode(type, forKey: key) : fallback
    }
}

func textRequestFailure(_ code: String, category: String = "invalidInput") -> GlifiStudioFailure {
    let retry: String
    switch category {
    case "insufficientResources": retry = "afterConditionsChange"
    case "cancelled": retry = "newRequest"
    case "incompatibleVersion": retry = "never"
    default: retry = "afterCorrection"
    }
    return GlifiStudioFailure(
        code: code, category: category, operation: "analyze",
        retryDisposition: retry, retainedState: "unchanged",
        messageKey: "failure.category.\(category)")
}
