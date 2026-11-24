// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private func bulkMultivariate(_ key: String) throws -> [Double] {
    let file = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Oracles/expected.txt")
    let line = try #require(
        try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
            .first { $0.hasPrefix("multivariate:\(key) ") }
    )
    return line.split(separator: " ").dropFirst().compactMap { Double($0) }
}

@Test("La SVD troncata su 150×200 sparsa coincide con svd() di R")
func truncatedSVDMatchesRDecomposition() throws {
    // Oracolo: multivariate.R, matrice 150×200 con il 5 % di celle Poisson (seed 7).
    let triplets = try bulkMultivariate("INFO_BULK_SVD_TRIPLETS")
    var matrix = [[Double]](repeating: [Double](repeating: 0, count: 200), count: 150)
    for index in stride(from: 0, to: triplets.count, by: 3) {
        matrix[Int(triplets[index])][Int(triplets[index + 1])] = triplets[index + 2]
    }
    let result = try GlifiLinearAlgebra.truncatedSingularValueDecomposition(matrix, rank: 5)
    let expected = try bulkMultivariate("INFO_BULK_SVD_VALUES")
    for axis in 0..<5 {
        #expect(abs(result.singularValues[axis] - expected[axis]) <= 1e-10 * expected[axis])
    }
    let firstVector = try bulkMultivariate("INFO_BULK_SVD_V1")
    for column in 0..<200 {
        #expect(abs(result.v[column][0] - firstVector[column]) < 1e-9)
    }
    // Residuo ||A v - σ u|| per ogni tripletta conservata.
    for axis in 0..<5 {
        var residual = 0.0
        for row in 0..<150 {
            let image = (0..<200).reduce(0.0) { $0 + matrix[row][$1] * result.v[$1][axis] }
            residual += pow(image - result.singularValues[axis] * result.u[row][axis], 2)
        }
        #expect(residual.squareRoot() < 1e-8 * result.singularValues[axis])
    }
    let repeated = try GlifiLinearAlgebra.truncatedSingularValueDecomposition(matrix, rank: 5)
    #expect(repeated == result)
    #expect(throws: GlifiFailure.self) {
        try GlifiLinearAlgebra.truncatedSingularValueDecomposition(matrix, rank: 0)
    }
}

@Test("La SVD troncata coincide con Jacobi sulla matrice di riferimento 5×4")
func truncatedSVDMatchesJacobiOnSmallMatrix() throws {
    let counts: [[Double]] = [
        [4, 2, 0, 1], [1, 3, 2, 0], [0, 1, 5, 2], [2, 0, 1, 3], [3, 1, 1, 1],
    ]
    let full = try GlifiLinearAlgebra.singularValueDecomposition(counts)
    let truncated = try GlifiLinearAlgebra.truncatedSingularValueDecomposition(counts, rank: 2)
    for axis in 0..<2 {
        #expect(abs(truncated.singularValues[axis] - full.singularValues[axis]) < 1e-12)
        for column in 0..<4 {
            #expect(abs(truncated.v[column][axis] - full.v[column][axis]) < 1e-10)
        }
    }
}

@Test("La LSA passa alla SVD troncata oltre il limite di Jacobi con lo stesso risultato")
func latentSemanticAnalysisSwitchesBackendBeyondDenseBound() throws {
    // Matrice 510×500 (255 000 celle, oltre il limite denso di 250 000): blocchi diagonali
    // di valore 3, 2 e 1 su 170 righe × 166-167 colonne, quindi σ₁ > σ₂ > σ₃ in forma chiusa:
    // σ = valore · √(righe · colonne) del blocco.
    let blocks: [(rows: Range<Int>, columns: Range<Int>, value: Double)] = [
        (0..<170, 0..<167, 3), (170..<340, 167..<334, 2), (340..<510, 334..<500, 1),
    ]
    var matrix = [[Double]](repeating: [Double](repeating: 0, count: 500), count: 510)
    for block in blocks {
        for row in block.rows { for column in block.columns { matrix[row][column] = block.value } }
    }
    let result = try GlifiMultivariateMethods.latentSemanticAnalysis(matrix, rank: 2)
    #expect(result.backendIdentifier == "SVD-SubspaceIteration-v1")
    let expected = blocks.map { $0.value * Double($0.rows.count * $0.columns.count).squareRoot() }
    #expect(abs(result.singularValues[0] - expected[0]) < 1e-9 * expected[0])
    #expect(abs(result.singularValues[1] - expected[1]) < 1e-9 * expected[1])
    #expect(abs(result.residualNorm - expected[2]) < 1e-6 * expected[2])
    let small = try GlifiMultivariateMethods.latentSemanticAnalysis([[1, 0], [0, 2]], rank: 1)
    #expect(small.backendIdentifier == "SVD-Jacobi-v1")
    #expect(abs(small.residualNorm - 1) < 1e-12)
}

@Test("CA e PCA con backend troncato coincidono con Jacobi, già verificato contro R")
func truncatedCorrespondenceAndPCAMatchDense() throws {
    let counts: [[Double]] = [
        [4, 2, 0, 1], [1, 3, 2, 0], [0, 1, 5, 2], [2, 0, 1, 3], [3, 1, 1, 1],
    ]
    let dense = try GlifiMultivariateMethods.correspondenceAnalysis(counts)
    // Limite denso 0: forza la SVD troncata sui primi due assi.
    let truncated = try GlifiMultivariateMethods.correspondenceAnalysis(
        counts,
        denseCellLimit: 0,
        truncatedAxisCount: 2
    )
    #expect(dense.backendIdentifier == "SVD-Jacobi-v1")
    #expect(truncated.backendIdentifier == "SVD-SubspaceIteration-v1")
    #expect(abs(truncated.totalInertia - 0.587755102040816) < 1e-12)
    for axis in 0..<2 {
        #expect(abs(truncated.singularValues[axis] - dense.singularValues[axis]) < 1e-10)
        for row in 0..<5 {
            #expect(
                abs(truncated.rowCoordinates[row][axis] - dense.rowCoordinates[row][axis]) < 1e-9)
            #expect(abs(truncated.rowCosines[row][axis] - dense.rowCosines[row][axis]) < 1e-9)
        }
    }
    let profiles = counts.map { row in row.map { $0 / row.reduce(0, +) } }
    let pca = try GlifiMultivariateMethods.principalComponents(profiles, scaled: false)
    let truncatedPCA = try GlifiMultivariateMethods.principalComponents(
        profiles,
        scaled: false,
        denseCellLimit: 0,
        truncatedComponentCount: 2
    )
    #expect(truncatedPCA.backendIdentifier == "SVD-SubspaceIteration-v1")
    for component in 0..<2 {
        #expect(abs(truncatedPCA.variances[component] - pca.variances[component]) < 1e-12)
        #expect(abs(truncatedPCA.varianceShares[component] - pca.varianceShares[component]) < 1e-10)
    }
}
