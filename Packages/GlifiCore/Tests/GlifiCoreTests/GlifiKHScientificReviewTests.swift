// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Gli obiettivi MDS coincidono con le formule indipendenti R, comprese le parità")
func khReviewMDSObjectives() throws {
    let delta: [[Double]] = [[0, 1, 1], [1, 0, 2], [1, 2, 0]]
    let coordinates: [[Double]] = [[0], [1], [3]]
    #expect(abs(try mdsObjective(delta, coordinates, .metric) - 4) < 1e-12)
    #expect(abs(try mdsObjective(delta, coordinates, .kruskal) - 0.377964473009227) < 1e-12)
    #expect(abs(try mdsObjective(delta, coordinates, .sammon) - 1) < 1e-12)
    let result = try GlifiExploratoryAnalysis.multidimensionalScaling(
        delta, dimensions: 1, method: .kruskal, seed: 3)
    #expect(result.methodIdentifier == "MDS-nonmetric-secondary-ties-Stress1-v2")
    #expect(abs(try mdsObjective(delta, result.coordinates, .kruskal) - result.stress) < 1e-12)
    let scaled = delta.map { $0.map { $0 * 1e50 } }
    let repeated = try GlifiExploratoryAnalysis.multidimensionalScaling(
        scaled, dimensions: 1, method: .kruskal, seed: 3)
    #expect(abs(result.stress - repeated.stress) < 1e-12)
}

@Test("Stress e autovalori non finiti vengono rifiutati anche se le coordinate sono finite")
func khReviewMDSOutputRange() throws {
    let delta = (0..<6).map { i in (0..<6).map { j in (i < 3) == (j < 3) ? 0.0 : 1.3e154 } }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScaling(delta, dimensions: 1)
    }
    let complete = (0..<4).map { i in (0..<4).map { i == $0 ? 0.0 : 1.3e154 } }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScaling(
            complete, dimensions: 1, method: .metric, maximumIterations: 1)
    }
}

@Test("I riferimenti ai codici sono binari e le parole riservate tra virgolette restano termini")
func khReviewCodingBinaryReferencesAndQuotes() throws {
    let rules = try GlifiCodingRuleSet(
        """
        *Count
        casa
        *Binary
        <*Count> == 1
        *Quoted
        "lw" == 2
        *Length
        lw == 5
        """)
    let result = try rules.evaluate([GlifiCodingDocument(id: "one", text: "casa casa lw lw mare")])
    #expect(result.values == [[1, 1, 1, 1]])
    #expect(result.evidence[0][1].count == 2)
    #expect(result.evidence[0][2].count == 2)
}

@Test("Naive Bayes conserva log-probabilità finite con pseudoconteggio subnormale")
func khReviewNaiveBayesLogDomain() throws {
    let model = try GlifiNaiveBayes.train(
        documents: [["r", "r"], ["b"]], labels: ["A", "B"], smoothing: Double.leastNonzeroMagnitude)
    #expect(model.logLikelihoods.allSatisfy { $0.allSatisfy(\.isFinite) })
    #expect(abs(model.logLikelihoods[0][0] - (-745.133219101941)) < 1e-12)
    let result = try GlifiNaiveBayes.predict([["r"]], using: model)
    #expect(result[0].label == "A")
    #expect(abs(result[0].probabilities.reduce(0, +) - 1) < 1e-12)
}

@Test("SOM su quattro unità coincide con l'oracolo R indipendente su tutti i prototipi")
func khReviewSOMMultipleUnitOracle() throws {
    let matrix: [[Double]] = [[0, 1], [2, 3], [4, 0], [10, 11], [11, 10], [12, 12]]
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 2, height: 2, seed: 27, epochs: 3)
    let reference: [Double] = [
        10.8381241103412, 10.8261333036998, 6.5, 6.16666666666667, 6.5, 6.16666666666667,
        2.16187588965882, 1.50720002963355,
    ]
    #expect(reference.count == result.prototypes.flatMap { $0 }.count)
    for (actual, expected) in zip(result.prototypes.flatMap { $0 }, reference) {
        #expect(abs(actual - expected) < 1e-12)
    }
}

@Test(
    "La perplexity predittiva LDA coincide con l'integrazione esatta, non con il prodotto delle medie"
)
func khReviewLDAPredictivePosterior() throws {
    let result = try GlifiLatentDirichletAllocation.fit(
        documents: [["rosso", "rosso"], ["blu"]], topicCount: 2, seed: 19,
        alpha: 0.1, beta: 1, burnIn: 1000, sampleCount: 10000, thinning: 4)
    #expect(abs(result.trainingPerplexity - 1.57518577227781) < 0.02)
}

@Test("La revisione conserva distanze, ranking e logica su famiglie di input")
func khReviewMetamorphicFamilies() throws {
    for seed in 0..<10 {
        var generator = GlifiSplitMix64(seed: UInt64(seed))
        let points = (0..<8).map { _ in (0..<3).map { _ in Double(generator.next() % 101) / 10 } }
        let distances = try GlifiTextMatrixOperators.dissimilarities(points, metric: .euclidean)
        let result = try GlifiExploratoryAnalysis.multidimensionalScaling(distances, dimensions: 3)
        let reconstructed = try GlifiTextMatrixOperators.dissimilarities(
            result.coordinates, metric: .euclidean)
        for i in points.indices {
            for j in points.indices {
                #expect(
                    abs(distances[i][j] - reconstructed[i][j]) <= 1e-10 * max(1, distances[i][j]))
            }
        }
        let clara = try GlifiExploratoryAnalysis.clara(
            points, clusterCount: 2, seed: UInt64(seed), samples: 2, sampleSize: 8, maximumSwaps: 20
        )
        let repeated = try GlifiExploratoryAnalysis.clara(
            points, clusterCount: 2, seed: UInt64(seed), samples: 2, sampleSize: 8, maximumSwaps: 20
        )
        #expect(clara == repeated)
        var exactCost = 0.0
        for (index, row) in points.enumerated() {
            let medoid = points[clara.medoids[clara.assignments[index]]]
            exactCost += zip(row, medoid).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
                .squareRoot()
        }
        #expect(abs(exactCost - clara.objective) < 1e-12)
        let count = seed + 1
        let terms = Array(repeating: "casa", count: count) + ["mare"]
        let document = try GlifiCodingDocument(id: "unit", text: terms.joined(separator: " "))
        for expression in ["casa & mare", "( mare & casa )", "! ( ! casa | ! mare )"] {
            let coded = try GlifiCodingRuleSet("*C\n" + expression).evaluate([document])
            #expect(coded.values == [[1]])
        }
        let model = try GlifiNaiveBayes.train(documents: [terms, ["solo"]], labels: ["A", "B"])
        let forward = try GlifiNaiveBayes.predict([terms], using: model)
        let reverse = try GlifiNaiveBayes.predict([Array(terms.reversed())], using: model)
        #expect(forward == reverse)
    }
}

@Test("MDS rifiuta underflow delle coordinate e Stress-1 privo di denominatore")
func khReviewMDSUnderflowAndCollapse() throws {
    for method in [GlifiMDSMethod.classical, .metric, .kruskal, .sammon] {
        #expect(throws: GlifiFailure.self) {
            try GlifiExploratoryAnalysis.multidimensionalScaling(
                [[0, 1e-300], [1e-300, 0]], dimensions: 1, method: method)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try mdsObjective([[0, 1], [1, 0]], [[0], [0]], .kruskal)
    }
}
