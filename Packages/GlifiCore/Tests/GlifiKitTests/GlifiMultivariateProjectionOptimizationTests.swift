// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import GlifiCore
import Testing

@testable import GlifiKit

@Test("La proiezione CA conserva appartenenza, ordine e DTO completo del riferimento")
func multivariateProjectionPreservesMembershipSemantics() throws {
    let cases: [(rows: Int, columns: Int, includedRows: [Int], includedColumns: [Int])] = [
        (0, 0, [], []),
        (5, 4, [], []),
        (5, 4, Array(0..<5), Array(0..<4)),
        (7, 6, [5, 1, 3], [4, 0, 2]),
        (7, 6, [5, 1, 1, 3, 5], [4, 0, 4, 2, 0]),
        (7, 6, [-1, 7, 100, 5, 1], [-1, 6, 100, 4, 0]),
        (7, 6, [Int.min, 1, Int.max, 5], [Int.max, 4, Int.min, 0]),
    ]
    for item in cases {
        let result = try projectionOptimizationFixture(
            rows: item.rows, columns: item.columns,
            includedRows: item.includedRows, includedColumns: item.includedColumns,
            reversedLabels: true)
        try projectionOptimizationAssertReference(result)
        let actual = GlifiStudioMultivariateResult(result)
        #expect(
            actual.excludedSourceRevisionIDs
                == result.value.sourceRevisionIDs.enumerated().compactMap { index, identifier in
                    item.includedRows.contains(index) ? nil : identifier
                })
        #expect(
            actual.excludedTerms
                == result.value.terms.enumerated().compactMap { index, term in
                    item.includedColumns.contains(index) ? nil : term
                })
    }
}

@Test("La proiezione non CA conserva tutti i campi e la serializzazione del riferimento")
func multivariateProjectionPreservesNonCorrespondence() throws {
    try projectionOptimizationAssertReference(
        projectionOptimizationFixture(rows: 17, columns: 13, principalComponents: true))
}

/// Keeps a complete small reference regression active without enabling large measurements.
@Test("La proiezione Kit coincide con il riferimento e misura soltanto workload espliciti")
func domainOptimizationProjection() throws {
    try projectionOptimizationAssertReference(
        projectionOptimizationFixture(
            rows: 16, columns: 12, includedRows: [1, 4, 7, 10, 13],
            includedColumns: [0, 3, 6, 9]))
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    let scenarios: [(identifier: String, rows: Int, columns: Int, sparse: Bool, pca: Bool)] = [
        ("projection-ca-small", 16, 12, false, false),
        ("projection-ca-1024", 1_024, 2_000, false, false),
        ("projection-ca-4096", 4_096, 2_000, false, false),
        ("projection-ca-8192", 8_192, 2_000, false, false),
        ("projection-ca-8192-sparse", 8_192, 2_000, true, false),
        ("projection-pca-control", 8_192, 2_000, false, true),
    ]
    for item in scenarios {
        let includedRows = (0..<item.rows).filter { item.sparse ? $0 % 10 == 0 : $0 % 10 != 0 }
        let includedColumns = (0..<item.columns).filter {
            item.sparse ? $0 % 10 == 0 : $0 % 10 != 0
        }
        let result = try projectionOptimizationFixture(
            rows: item.rows, columns: item.columns,
            includedRows: includedRows, includedColumns: includedColumns,
            principalComponents: item.pca)
        let expected = try projectionOptimizationReference(result)
        let fixtureDigest = try pipelineBenchmarkDigest(
            ProjectionOptimizationFixtureIdentity(
                lineage: GlifiStudioDerivedLineage(result), value: result.value))
        try measurePipelineOptimization(
            identifier: item.identifier,
            generator:
                "Prebuilt Core result; \(item.rows) rows, \(item.columns) columns, two axes; \(item.pca ? "PCA control" : item.sparse ? "CA about 10% included" : "CA about 90% included"); fixed identities; full Kit DTO initialization only; no numerical kernel",
            fixtureDigest: fixtureDigest, expected: expected,
            body: { GlifiStudioMultivariateResult(result) },
            checksum: { try pipelineBenchmarkDigest($0) })
    }
}

private struct ProjectionOptimizationFixtureIdentity: Encodable {
    let lineage: GlifiStudioDerivedLineage
    let value: GlifiCorpusMultivariateAnalysis
}

private struct ProjectionOptimizationAnalysisInput: Encodable {
    let analysisIdentifier = GlifiCorpusMultivariateAnalysis.analysisIdentifier
    let method: GlifiMultivariateMethod
    let representationIdentifier: String
    let termSelectionIdentifier = "synthetic.projection-fixture.v1"
    let corpusDigest: String
    let sourceRevisionIDs: [String]
    let terms: [String]
    let correspondence: ProjectionOptimizationCorrespondenceInput?
    let principalComponents: ProjectionOptimizationPrincipalInput?
}

private struct ProjectionOptimizationCorrespondenceInput: Encodable {
    let includedRows: [Int]
    let includedColumns: [Int]
    let rowMasses: [Double]
    let columnMasses: [Double]
    let singularValues = [0.5, 0.25]
    let inertias = [0.25, 0.0625]
    let totalInertia = 0.5
    let rowCoordinates: [[Double]]
    let columnCoordinates: [[Double]]
    let rowContributions: [[Double]]
    let columnContributions: [[Double]]
    let rowCosines: [[Double]]
    let columnCosines: [[Double]]
    let backendIdentifier = "synthetic.precomputed-ca.v1"
}

private struct ProjectionOptimizationPrincipalInput: Encodable {
    let scaled = true
    let excludedConstantColumns: [Int]
    let means: [Double]
    let variances = [0.5, 0.25]
    let varianceShares = [2.0 / 3, 1.0 / 3]
    let loadings: [[Double]]
    let scores: [[Double]]
    let backendIdentifier = "synthetic.precomputed-pca.v1"
}

private func projectionOptimizationFixture(
    rows: Int,
    columns: Int,
    includedRows: [Int]? = nil,
    includedColumns: [Int]? = nil,
    reversedLabels: Bool = false,
    principalComponents: Bool = false
) throws -> GlifiProjectDerivedResult<GlifiCorpusMultivariateAnalysis> {
    let rowIndexes = includedRows ?? Array(0..<rows)
    let columnIndexes = includedColumns ?? Array(0..<columns)
    let sources = (0..<rows).map {
        "source-revision:00000000-0000-0000-0000-" + String(format: "%012d", $0)
    }
    let terms = (0..<columns).map { String(format: "%06d", $0) + "-città-β" }
    func coordinates(_ count: Int) -> [[Double]] {
        (0..<count).map { index in
            [Double(index % 17 - 8) / 16, Double(index % 13 - 6) / 8]
        }
    }
    func diagnostics(_ count: Int) -> [[Double]] {
        (0..<count).map { index in
            [Double(index % 7 + 1) / 16, Double(index % 5 + 1) / 8]
        }
    }
    let correspondence = ProjectionOptimizationCorrespondenceInput(
        includedRows: rowIndexes, includedColumns: columnIndexes,
        rowMasses: Array(repeating: 1 / Double(max(rowIndexes.count, 1)), count: rowIndexes.count),
        columnMasses: Array(
            repeating: 1 / Double(max(columnIndexes.count, 1)), count: columnIndexes.count),
        rowCoordinates: coordinates(rowIndexes.count),
        columnCoordinates: coordinates(columnIndexes.count),
        rowContributions: diagnostics(rowIndexes.count),
        columnContributions: diagnostics(columnIndexes.count),
        rowCosines: diagnostics(rowIndexes.count), columnCosines: diagnostics(columnIndexes.count))
    let excludedConstantColumns = columns >= 2 ? [1] : []
    let principal = ProjectionOptimizationPrincipalInput(
        excludedConstantColumns: excludedConstantColumns,
        means: (0..<columns).map { Double($0) / 16 },
        loadings: coordinates(columns - excludedConstantColumns.count), scores: coordinates(rows))
    let method: GlifiMultivariateMethod =
        principalComponents ? .principalComponents(scaled: true) : .correspondence
    let input = ProjectionOptimizationAnalysisInput(
        method: method, representationIdentifier: method.representationIdentifier,
        corpusDigest: pipelineBenchmarkDigest(Data("projection-fixture-206".utf8)),
        sourceRevisionIDs: reversedLabels ? Array(sources.reversed()) : sources,
        terms: reversedLabels ? Array(terms.reversed()) : terms,
        correspondence: principalComponents ? nil : correspondence,
        principalComponents: principalComponents ? principal : nil)
    // Core's Codable contract constructs already materialized data without executing a kernel.
    let value = try JSONDecoder().decode(
        GlifiCorpusMultivariateAnalysis.self, from: JSONEncoder().encode(input))
    return try GlifiProjectDerivedResult(
        projectID: ProjectID(canonicalValue: "project:00000000-0000-0000-0000-000000000206"),
        sourceGeneration: 17, generation: 18,
        artifactID: ArtifactID(digest: pipelineBenchmarkDigest(Data("artifact-206".utf8))),
        analysisNodeID: AnalysisNodeID(digest: pipelineBenchmarkDigest(Data("node-206".utf8))),
        value: value)
}

private func projectionOptimizationAssertReference(
    _ result: GlifiProjectDerivedResult<GlifiCorpusMultivariateAnalysis>
) throws {
    let expected = try projectionOptimizationReference(result)
    let actual = GlifiStudioMultivariateResult(result)
    #expect(actual == expected)
    let actualJSON = try projectionOptimizationCanonicalJSON(actual)
    let expectedJSON = try projectionOptimizationCanonicalJSON(expected)
    #expect(actualJSON == expectedJSON)
    #expect(pipelineBenchmarkDigest(actualJSON) == pipelineBenchmarkDigest(expectedJSON))
    #expect(
        try JSONDecoder().decode(GlifiStudioMultivariateResult.self, from: actualJSON) == expected)
}

private func projectionOptimizationCanonicalJSON(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

// This complete DTO reference preserves the original Array.contains membership definition.
// It checks projection equivalence, not the scientific validity of synthetic coordinates.
private struct ProjectionOptimizationReference: Encodable {
    let lineage: GlifiStudioDerivedLineage
    let analysisIdentifier: String
    let methodIdentifier: String
    let representationIdentifier: String
    let sourceRevisionIDs: [String]
    let terms: [String]
    let axisValues: [Double]
    let axisShares: [Double]
    let rowCoordinates: [[Double]]
    let columnCoordinates: [[Double]]
    let rowContributions: [[Double]]?
    let columnContributions: [[Double]]?
    let rowCosines: [[Double]]?
    let excludedSourceRevisionIDs: [String]
    let excludedTerms: [String]
    let clusterAssignments: [Int]? = nil
    let merges: [GlifiStudioMerge]? = nil
    let objective: Double? = nil
    let iterations: Int? = nil
    let converged: Bool? = nil
    let seed: UInt64? = nil
    let residualNorm: Double? = nil
    let backendIdentifier: String?
}

private enum ProjectionOptimizationReferenceFailure: Error {
    case unsupportedFixture
}

private func projectionOptimizationReference(
    _ result: GlifiProjectDerivedResult<GlifiCorpusMultivariateAnalysis>
) throws -> GlifiStudioMultivariateResult {
    let value = result.value
    let axisValues: [Double]
    let axisShares: [Double]
    let rows: [[Double]]
    let columns: [[Double]]
    let excludedDocuments: [String]
    let excludedTerms: [String]
    let backendIdentifier: String
    if let ca = value.correspondence {
        axisValues = ca.inertias
        axisShares = ca.inertias.map { $0 / ca.totalInertia }
        rows = ca.rowCoordinates
        columns = ca.columnCoordinates
        excludedDocuments = value.sourceRevisionIDs.indices
            .filter { !ca.includedRows.contains($0) }.map { value.sourceRevisionIDs[$0] }
        excludedTerms = value.terms.indices
            .filter { !ca.includedColumns.contains($0) }.map { value.terms[$0] }
        backendIdentifier = ca.backendIdentifier
    } else if let pca = value.principalComponents {
        axisValues = pca.variances
        axisShares = pca.varianceShares
        rows = pca.scores
        columns = pca.loadings
        excludedDocuments = []
        excludedTerms = pca.excludedConstantColumns.map { value.terms[$0] }
        backendIdentifier = pca.backendIdentifier
    } else {
        throw ProjectionOptimizationReferenceFailure.unsupportedFixture
    }
    let reference = ProjectionOptimizationReference(
        lineage: GlifiStudioDerivedLineage(result), analysisIdentifier: value.analysisIdentifier,
        methodIdentifier: value.method.identifier,
        representationIdentifier: value.representationIdentifier,
        sourceRevisionIDs: value.sourceRevisionIDs, terms: value.terms,
        axisValues: axisValues, axisShares: axisShares, rowCoordinates: rows,
        columnCoordinates: columns, rowContributions: value.correspondence?.rowContributions,
        columnContributions: value.correspondence?.columnContributions,
        rowCosines: value.correspondence?.rowCosines,
        excludedSourceRevisionIDs: excludedDocuments, excludedTerms: excludedTerms,
        backendIdentifier: backendIdentifier)
    return try JSONDecoder().decode(
        GlifiStudioMultivariateResult.self, from: projectionOptimizationCanonicalJSON(reference))
}
