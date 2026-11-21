// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracolo: R 4.6.0 (svd, prcomp, hclust, kmeans algorithm="Lloyd") con options(digits=15),
// segni canonicalizzati sul primo loading non nullo positivo come in GS-MET-001-10.
private let counts: [[Double]] = [
    [4, 2, 0, 1], [1, 3, 2, 0], [0, 1, 5, 2], [2, 0, 1, 3], [3, 1, 1, 1],
]
private let profiles: [[Double]] = counts.map { row in
    let total = row.reduce(0, +)
    return row.map { $0 / total }
}

private func close(_ left: [Double], _ right: [Double], _ tolerance: Double = 1e-10) -> Bool {
    left.count == right.count && zip(left, right).allSatisfy { abs($0 - $1) <= tolerance }
}

@Test("La SVD di Jacobi coincide con svd() di R e ricostruisce la matrice")
func jacobiSVDMatchesR() throws {
    let svd = try GlifiLinearAlgebra.singularValueDecomposition(counts)
    #expect(
        close(
            svd.singularValues,
            [7.52736380143792, 4.86692838918735, 3.136431881558, 0.90255044605317]))
    #expect(svd.rank == 4)
    for row in counts.indices {
        for column in counts[row].indices {
            let value = (0..<4).reduce(0.0) {
                $0 + svd.u[row][$1] * svd.singularValues[$1] * svd.v[column][$1]
            }
            #expect(abs(value - counts[row][column]) < 1e-12)
        }
    }
    for left in 0..<4 {
        for right in 0..<4 {
            let dot = svd.v.reduce(0.0) { $0 + $1[left] * $1[right] }
            #expect(abs(dot - (left == right ? 1 : 0)) < 1e-12)
        }
    }
    let wide = try GlifiLinearAlgebra.singularValueDecomposition(
        GlifiLinearAlgebra.transpose(counts))
    #expect(close(wide.singularValues, svd.singularValues, 1e-12))
}

@Test("La Correspondence Analysis coincide con R e l'inerzia totale vale χ²/n")
func correspondenceAnalysisMatchesR() throws {
    let result = try GlifiMultivariateMethods.correspondenceAnalysis(counts)
    #expect(
        close(result.singularValues, [0.582087962347697, 0.481743715453175, 0.129814093041135]))
    #expect(abs(result.totalInertia - 0.587755102040816) < 1e-12)
    #expect(abs(result.rowMasses.reduce(0, +) - 1) < 1e-15)
    #expect(
        close(
            result.rowCoordinates.map { $0[0] },
            [
                0.735110435382726, -0.159847625390879, -0.886816799510359, 0.0982521756169196,
                0.386389007841258,
            ]
        )
    )
    #expect(
        close(
            result.rowCoordinates.map { $0[1] },
            [
                -0.134463155476211, -0.794978158726414, 0.091027709306216, 0.780919373975987,
                0.0495621870643861,
            ]
        )
    )
    #expect(
        close(
            result.columnCoordinates.map { $0[0] },
            [0.710591140592413, 0.120318144000686, -0.814908921946921, -0.0877083023438066]
        )
    )
    for axis in 0..<3 {
        #expect(abs(result.rowContributions.reduce(0) { $0 + $1[axis] } - 1) < 1e-12)
        #expect(abs(result.columnContributions.reduce(0) { $0 + $1[axis] } - 1) < 1e-12)
    }
    #expect(result.rowCosines.allSatisfy { abs($0.reduce(0, +) - 1) < 1e-12 })
    let withEmpty = try GlifiMultivariateMethods.correspondenceAnalysis(counts + [[0, 0, 0, 0]])
    #expect(withEmpty.includedRows == [0, 1, 2, 3, 4])
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.correspondenceAnalysis([[1, 2], [0, 0]])
    }
}

@Test("La PCA coincide con prcomp di R, con e senza scaling")
func principalComponentsMatchR() throws {
    let result = try GlifiMultivariateMethods.principalComponents(profiles, scaled: false)
    let expectedVariances = [0.108545741318504, 0.0669959227900268, 0.00550992319305703, 0]
    #expect(close(result.variances, expectedVariances, 1e-12))
    #expect(
        close(
            result.loadings.map { $0[0] },
            [0.705266154058181, -0.0151136249327167, -0.708542888582214, 0.0183903594567498]
        )
    )
    #expect(
        close(
            result.scores.map { $0[0] },
            [
                0.362063037356412, -0.165448625507279, -0.479386127806166, 0.0869382071275197,
                0.195833508829514,
            ]
        )
    )
    #expect(abs(result.varianceShares.reduce(0, +) - 1) < 1e-12)
    let shifted = try GlifiMultivariateMethods.principalComponents(
        profiles.map { $0.map { $0 + 10 } },
        scaled: false
    )
    #expect(close(shifted.variances, result.variances, 1e-12))
    let scaled = try GlifiMultivariateMethods.principalComponents(profiles, scaled: true)
    #expect(
        close(scaled.variances, [1.96257028784785, 1.90884757153814, 0.128582140614008, 0], 1e-10))
}

@Test("La LSA tronca al rango richiesto con residuo pari alla norma dei valori scartati")
func latentSemanticAnalysisTruncates() throws {
    let result = try GlifiMultivariateMethods.latentSemanticAnalysis(counts, rank: 2)
    #expect(result.effectiveRank == 2)
    #expect(close(result.singularValues, [7.52736380143792, 4.86692838918735]))
    #expect(abs(result.residualNorm - 3.26370989141564) < 1e-10)
}

@Test("HAC coincide con hclust di R nei quattro linkage")
func hierarchicalClusteringMatchesR() throws {
    // R: merge con indici negativi per i singleton (base 1) e positivi per i passi.
    // Qui i singleton sono 0…4 e il cluster del passo s è 5+s.
    let expected: [(GlifiLinkage, [Double], [[Int]])] = [
        (
            .single, [0.218217890235992, 0.408248290463863, 0.52704627669473, 0.562114065134668],
            [[0, 4], [3, 5], [1, 6], [2, 7]]
        ),
        (
            .complete,
            [0.218217890235992, 0.541895556035288, 0.562114065134668, 0.868599036215379],
            [[0, 4], [3, 5], [1, 2], [6, 7]]
        ),
        (
            .average, [0.218217890235992, 0.475071923249575, 0.562114065134668, 0.673623973980928],
            [[0, 4], [3, 5], [1, 2], [6, 7]]
        ),
        (
            .ward, [0.218217890235992, 0.539449062475125, 0.562114065134668, 0.890963600584298],
            [[0, 4], [3, 5], [1, 2], [6, 7]]
        ),
    ]
    for (linkage, heights, merges) in expected {
        let tree = try GlifiMultivariateMethods.hierarchicalClustering(profiles, linkage: linkage)
        #expect(close(tree.merges.map(\.height), heights, 1e-12))
        #expect(tree.merges.map { [$0.first, $0.second] } == merges)
    }
    let ward = try GlifiMultivariateMethods.hierarchicalClustering(profiles, linkage: .ward)
    let cut = try GlifiMultivariateMethods.cut(ward, pointCount: 5, clusterCount: 2)
    #expect(cut == [0, 1, 1, 0, 0])
    #expect(
        zip(ward.merges.map(\.height), ward.merges.dropFirst().map(\.height)).allSatisfy {
            $0 <= $1
        })
}

@Test("Lloyd coincide con kmeans di R a parità di centri e k-means++ è riproducibile")
func kMeansMatchesR() throws {
    let lloyd = try GlifiMultivariateMethods.lloyd(
        profiles,
        initialCenters: [profiles[0], profiles[2]],
        maximumIterations: 100
    )
    #expect(lloyd.assignments == [0, 1, 1, 0, 0])
    #expect(abs(lloyd.objective - 0.32729828042328) < 1e-12)
    // R stampa i centri per riga: [0,468; 0,151; 0,111; 0,270] e [0,083; 0,313; 0,479; 0,125].
    #expect(
        close(
            lloyd.centers[0],
            [0.468253968253968, 0.150793650793651, 0.111111111111111, 0.26984126984127]))
    #expect(close(lloyd.centers[1], [0.0833333333333333, 0.3125, 0.479166666666667, 0.125]))
    #expect(close(lloyd.centers.map { $0[0] }, [0.468253968253968, 0.0833333333333333]))
    #expect(lloyd.iterations == 2)
    let first = try GlifiMultivariateMethods.kMeans(profiles, clusterCount: 2, seed: 5)
    let second = try GlifiMultivariateMethods.kMeans(profiles, clusterCount: 2, seed: 5)
    #expect(first == second)
    #expect(first.objective <= lloyd.objective + 1e-12)
}

@Test("NMF resta non negativa, riduce l'obiettivo e ricostruisce una matrice di rango esatto")
func nonNegativeFactorizationIsMonotone() throws {
    // X = W₀H₀ con W₀=[[1,0],[0,1],[1,1]] e H₀=[[1,2,0],[0,1,3]]: rango 2 non negativo.
    let exact: [[Double]] = [[1, 2, 0], [0, 1, 3], [1, 3, 3]]
    let result = try GlifiMultivariateMethods.nonNegativeFactorization(
        exact,
        rank: 2,
        seed: 3,
        maximumIterations: 20_000,
        tolerance: 1e-14
    )
    #expect(result.w.allSatisfy { $0.allSatisfy { $0 >= 0 } })
    #expect(result.h.allSatisfy { $0.allSatisfy { $0 >= 0 } })
    #expect(
        zip(result.objectiveHistory, result.objectiveHistory.dropFirst()).allSatisfy {
            $1 <= $0 * (1 + 1e-12)
        })
    #expect(result.objective < 1e-6)
    let repeated = try GlifiMultivariateMethods.nonNegativeFactorization(
        exact,
        rank: 2,
        seed: 3,
        maximumIterations: 20_000,
        tolerance: 1e-14
    )
    #expect(result == repeated)
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.nonNegativeFactorization([[1, -1]], rank: 1, seed: 1)
    }
}

@Test("L'analisi multivariata del corpus riproduce la matrice di R dal testo")
func corpusMultivariateReproducesRMatrix() throws {
    // Termini aa, bb, cc, dd in ordine lessicografico; ogni documento riproduce una riga di
    // `counts`, quindi CA e HAC coincidono con i valori R dei test precedenti.
    func document(_ row: [Double]) -> String {
        zip(["aa", "bb", "cc", "dd"], row).flatMap { term, count in
            Array(repeating: term, count: Int(count))
        }.joined(separator: " ")
    }
    let sources = try counts.enumerated().map { index, row in
        try GlifiTextImporter().importText(
            from: Data(document(row).utf8),
            format: .plainText,
            sourceRevisionID: SourceRevisionID(
                uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000009\(index)"))
            )
        )
    }
    let corpus = try GlifiCorpusAnalyzer().analyze(sources)
    let ca = try GlifiCorpusMultivariateAnalyzer().analyze(corpus, method: .correspondence)
    #expect(ca.terms == ["aa", "bb", "cc", "dd"])
    #expect(ca.representationIdentifier == "document-term-raw-count-v1")
    let values = try #require(ca.correspondence).singularValues
    #expect(close(values, [0.582087962347697, 0.481743715453175, 0.129814093041135]))

    let hac = try GlifiCorpusMultivariateAnalyzer().analyze(
        corpus,
        method: .hierarchical(linkage: .ward, clusterCount: 2)
    )
    #expect(hac.clusterAssignments == [0, 1, 1, 0, 0])
    let heights = try #require(hac.hierarchical).merges.map(\.height)
    #expect(
        close(
            heights, [0.218217890235992, 0.539449062475125, 0.562114065134668, 0.890963600584298],
            1e-12))

    let lsa = try GlifiCorpusMultivariateAnalyzer().analyze(
        corpus, method: .latentSemantic(rank: 2))
    #expect(lsa.representationIdentifier == "tfidf-raw-log-v1")
    #expect(try #require(lsa.latentSemantic).effectiveRank == 2)
    #expect(throws: GlifiFailure.self) {
        try GlifiCorpusMultivariateAnalyzer().analyze(
            corpus, method: .correspondence, maximumTermCount: 1)
    }
}

@Test("Il taglio HAC a soglia include tutte le fusioni a pari altezza")
func hierarchicalHeightCutKeepsTies() throws {
    let tree = try GlifiMultivariateMethods.hierarchicalClustering(
        [[0], [1], [3], [4]], linkage: .single)
    #expect(
        try GlifiMultivariateMethods.cut(tree, pointCount: 4, maximumHeight: 0) == [0, 1, 2, 3])
    #expect(
        try GlifiMultivariateMethods.cut(tree, pointCount: 4, maximumHeight: 1) == [0, 0, 1, 1])
    #expect(
        try GlifiMultivariateMethods.cut(tree, pointCount: 4, maximumHeight: 2) == [0, 0, 0, 0])
    for height in [-1.0, .nan, .infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.cut(tree, pointCount: 4, maximumHeight: height)
        }
    }
}

@Test("Le parità HAC seguono le identità canoniche anche dopo una fusione")
func hierarchicalTiesUseCanonicalClusterIdentities() throws {
    let tree = try GlifiMultivariateMethods.hierarchicalClustering(
        [[0], [1], [2], [3]], linkage: .single)
    #expect(tree.merges.map { [$0.first, $0.second] } == [[0, 1], [2, 3], [4, 5]])
    #expect(tree.merges.map(\.height) == [1, 1, 1])
}

@Test("Il taglio HAC rifiuta alberi corrotti prima di attraversarne le identità")
func hierarchicalCutValidatesTheEntireTree() throws {
    let malformed: [[GlifiMerge]] = [
        [.init(first: -1, second: 1, height: 1, wardIncrement: nil, size: 2)],
        [.init(first: 0, second: 2, height: 1, wardIncrement: nil, size: 2)],
        [.init(first: 0, second: 0, height: 1, wardIncrement: nil, size: 2)],
        [.init(first: 0, second: 1, height: 1, wardIncrement: nil, size: 3)],
        [.init(first: 0, second: 1, height: .nan, wardIncrement: nil, size: 2)],
    ]
    for merges in malformed {
        let tree = GlifiHierarchicalClustering(linkage: .single, merges: merges)
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.cut(tree, pointCount: 2, clusterCount: 2)
        }
    }
    let reused = GlifiHierarchicalClustering(
        linkage: .single,
        merges: [
            .init(first: 0, second: 1, height: 1, wardIncrement: nil, size: 2),
            .init(first: 0, second: 2, height: 2, wardIncrement: nil, size: 2),
        ])
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.cut(reused, pointCount: 3, clusterCount: 1)
    }
    for pointCount in [0, -1, Int.max] {
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.cut(reused, pointCount: pointCount, clusterCount: 1)
        }
    }
    let inconsistentWard = GlifiHierarchicalClustering(
        linkage: .ward,
        merges: [.init(first: 0, second: 1, height: 1, wardIncrement: 4, size: 2)])
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.cut(inconsistentWard, pointCount: 2, clusterCount: 1)
    }
}

@Test("Lloyd rinumera centri e assegnazioni per prima apparizione e rifiuta limiti non validi")
func lloydCanonicalizesAndValidatesLimits() throws {
    let result = try GlifiMultivariateMethods.lloyd(
        [[0], [1], [10]], initialCenters: [[10], [0]], maximumIterations: 10)
    #expect(result.assignments == [0, 0, 1])
    #expect(result.centers == [[0.5], [10]])
    #expect(abs(result.objective - 0.5) < 1e-15)
    for maximumIterations in [0, -1, Int.max] {
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.kMeans(
                [[0], [1]], clusterCount: 1, seed: 0, maximumIterations: maximumIterations)
        }
    }
}

@Test("NMF, HAC e KMeans rifiutano overflow e parametri di arresto non finiti")
func multivariateMethodsRejectUnrepresentableResults() throws {
    for tolerance in [0.0, -1, .nan, .infinity] {
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.nonNegativeFactorization(
                [[1]], rank: 1, seed: 0, tolerance: tolerance)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.nonNegativeFactorization([[1e308]], rank: 1, seed: 0)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiMultivariateMethods.kMeans([[-1e308], [1e308]], clusterCount: 2, seed: 0)
    }
    for linkage in [GlifiLinkage.single, .complete, .average, .ward] {
        #expect(throws: GlifiFailure.self) {
            try GlifiMultivariateMethods.hierarchicalClustering(
                [[-1e308], [1e308]], linkage: linkage)
        }
    }
}
