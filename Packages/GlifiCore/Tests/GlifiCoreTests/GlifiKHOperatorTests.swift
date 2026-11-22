// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("MDS classica ricostruisce distanze e autovalori di cmdscale R")
func khClassicalMDSMatchesOracle() throws {
    let distances: [[Double]] = [[0, 1, 2], [1, 0, 1], [2, 1, 0]]
    let result = try GlifiExploratoryAnalysis.multidimensionalScaling(distances, dimensions: 1)
    #expect(result.eigenvalues.count == 3)
    #expect(abs(result.eigenvalues[0] - 2) < 1e-12)
    #expect(result.stress < 1e-24)
    for i in 0..<3 {
        for j in 0..<3 {
            #expect(
                abs(abs(result.coordinates[i][0] - result.coordinates[j][0]) - distances[i][j])
                    < 1e-12)
        }
    }
    // The non-Euclidean triangle has a negative eigenvalue, which must not be discarded.
    let nonEuclidean: [[Double]] = [[0, 1, 3], [1, 0, 1], [3, 1, 0]]
    let negative = try GlifiExploratoryAnalysis.multidimensionalScaling(nonEuclidean, dimensions: 1)
    #expect(abs(negative.eigenvalues[0] - 4.5) < 1e-12)
    #expect(abs((negative.eigenvalues.last ?? 0) + 0.833333333333333) < 1e-12)
}

@Test("Le tre MDS iterative sono riproducibili e non aumentano il proprio obiettivo")
func khIterativeMDSMonotonicity() throws {
    let distances: [[Double]] = [[0, 1, 2, 3], [1, 0, 1, 2], [2, 1, 0, 1], [3, 2, 1, 0]]
    for method in [GlifiMDSMethod.metric, .kruskal, .sammon] {
        let a = try GlifiExploratoryAnalysis.multidimensionalScaling(
            distances, dimensions: 1, method: method, seed: 42)
        let b = try GlifiExploratoryAnalysis.multidimensionalScaling(
            distances, dimensions: 1, method: method, seed: 42)
        #expect(a == b)
        #expect(a.stress.isFinite)
        for pair in zip(a.objectiveHistory, a.objectiveHistory.dropFirst()) {
            #expect(pair.1 <= pair.0)
        }
    }
}

@Test("MDS rifiuta input asimmetrici, non finiti e budget insufficienti")
func khMDSRejectsInvalidInputs() throws {
    for distances in [
        [[0.0, 1], [2, 0]], [[0, -1], [-1, 0]], [[0, Double.nan], [Double.nan, 0]],
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiExploratoryAnalysis.multidimensionalScaling(distances, dimensions: 1)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScaling(
            [[0, 1], [1, 0]], dimensions: 1,
            limits: GlifiExploratoryLimits(maximumCells: 1))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScaling(
            [[0, 0, 1], [0, 0, 1], [1, 1, 0]], dimensions: 1, method: .sammon)
    }
}

@Test("SOM a singola cella coincide con la media e con l'oracolo batch")
func khSOMSingleUnitOracle() throws {
    let matrix: [[Double]] = [[0, 0], [2, 0], [0, 2], [2, 2]]
    let result = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 1, height: 1, seed: 7, epochs: 2)
    #expect(result.prototypes == [[1, 1]])
    #expect(abs(result.quantizationError - 1.4142135623730951) < 1e-12)
    #expect(result.topographicError == 0)
    #expect(result.assignments == [0, 0, 0, 0])
}

@Test("SOM e CLARA separano gruppi e conservano seed e identità dei medoidi")
func khClusteringReproducibility() throws {
    let matrix: [[Double]] = [[0, 0], [0, 1], [1, 0], [10, 10], [10, 11], [11, 10]]
    let a = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 2, height: 1, seed: 7, epochs: 20, finalRadius: 0.1)
    let b = try GlifiExploratoryAnalysis.selfOrganizingMap(
        matrix, width: 2, height: 1, seed: 7, epochs: 20, finalRadius: 0.1)
    #expect(a == b)
    #expect(a.assignments[0] != a.assignments[3])
    let clara = try GlifiExploratoryAnalysis.clara(matrix, clusterCount: 2, seed: 7, sampleSize: 6)
    #expect(abs(clara.objective - 4) < 1e-12)
    #expect(clara.medoids == [0, 3])
    #expect(clara.assignments == [0, 0, 0, 1, 1, 1])
}

@Test("Naive Bayes coincide con il conteggio multinomiale esatto e congela il vocabolario")
func khNaiveBayesHandOracle() throws {
    let model = try GlifiNaiveBayes.train(
        documents: [["rosso", "rosso"], ["blu"]], labels: ["A", "B"])
    #expect(model.vocabulary == ["blu", "rosso"])
    let predictions = try GlifiNaiveBayes.predict([["rosso"], ["nuovo"]], using: model)
    #expect(predictions[0].label == "A")
    #expect(abs(predictions[0].probabilities[0] - 0.6923076923076923) < 1e-12)
    #expect(abs(predictions[0].probabilities[1] - 0.3076923076923077) < 1e-12)
    #expect(predictions[1].probabilities == [0.5, 0.5])
    #expect(predictions[1].ignoredTokenCount == 1)
}

@Test("Validazione del classificatore stratificata e senza dati di test nel training")
func khNaiveBayesHeldOut() throws {
    let documents = [["rosso", "uno"], ["rosso", "due"], ["blu", "tre"], ["blu", "quattro"]]
    let result = try GlifiNaiveBayes.crossValidate(
        documents: documents, labels: ["A", "A", "B", "B"], folds: 2, seed: 8)
    #expect(result.accuracy == 1)
    #expect(result.confusion == [[2, 0], [0, 2]])
    #expect(throws: GlifiFailure.self) {
        try GlifiNaiveBayes.crossValidate(
            documents: documents, labels: ["A", "A", "B", "B"], folds: 3, seed: 8)
    }
}

@Test("LDA a un topic coincide con il posteriore Dirichlet esatto")
func khLDAAnalyticOracle() throws {
    let result = try GlifiLatentDirichletAllocation.fit(
        documents: [["rosso", "rosso"], ["blu"]], topicCount: 1, seed: 7,
        alpha: 0.1, beta: 1, burnIn: 0, sampleCount: 1, thinning: 1
    )
    #expect(result.documentTopics == [[1], [1]])
    #expect(result.topicTerms == [[0.4, 0.6]])
    #expect(abs(result.trainingPerplexity - 1.90785707092222) < 1e-12)
}

@Test("LDA conserva token, normalizza distribuzioni ed è riproducibile per seed")
func khLDAMultitopicProperties() throws {
    let documents = [Array(repeating: "rosso", count: 10), Array(repeating: "blu", count: 10), []]
    let a = try GlifiLatentDirichletAllocation.fit(
        documents: documents, topicCount: 2, seed: 9, burnIn: 20, sampleCount: 5, thinning: 2)
    let b = try GlifiLatentDirichletAllocation.fit(
        documents: documents, topicCount: 2, seed: 9, burnIn: 20, sampleCount: 5, thinning: 2)
    #expect(a == b)
    #expect(a.assignments.map(\.count) == [10, 10, 0])
    for row in a.topicTerms + a.documentTopics {
        #expect(abs(row.reduce(0, +) - 1) < 1e-12)
        #expect(row.allSatisfy { $0 > 0 && $0.isFinite })
    }
    #expect(a.trainingPerplexity <= 2)
    #expect(throws: GlifiFailure.self) {
        try GlifiLatentDirichletAllocation.fit(
            documents: documents, topicCount: 2, seed: 9,
            limits: GlifiExploratoryLimits(maximumWork: 1))
    }
}

@Test("Matrici di parole e codici condividono distanze, trasformazioni e ordine")
func khMatrixOperators() throws {
    let matrix: [[Double]] = [[2, 1, 0], [0, 1, 2]]
    let distances = try GlifiTextMatrixOperators.dissimilarities(matrix, metric: .jaccard)
    #expect(abs(distances[0][1] - 0.6666666666666666) < 1e-12)
    let cosine = try GlifiTextMatrixOperators.dissimilarities(matrix, metric: .cosine)
    #expect(abs(cosine[0][1] - 0.8) < 1e-12)
    let normalized = try GlifiTextMatrixOperators.transform(matrix, using: .perThousand)
    #expect(abs(normalized[0].reduce(0, +) - 1_000) < 1e-12)
    let transposed = try GlifiTextMatrixOperators.transpose(matrix)
    #expect(transposed == [[2, 0], [1, 1], [0, 2]])
}

@Test("Regole: booleani, conteggi, variabili e riferimenti producono codifica multilabel")
func khCodingRulesArithmeticAndReferences() throws {
    let rules = try GlifiCodingRuleSet(
        """
        # Synthetic test, not a third-party rule file.
        *Presenza
        casa | mare
        *Ripetizione
        casa + mare >= 3
        *Esclusione
        <*Presenza> &! città
        *Gruppo
        <>gruppo-->A & ( lw / 2 >= 1 )
        *Secondo
        No. == 2
        """)
    let first = try GlifiCodingDocument(
        id: "1", text: "Casa casa mare.", variables: ["gruppo": "A"])
    let second = try GlifiCodingDocument(id: "2", text: "Mare e città.", variables: ["gruppo": "B"])
    let result = try rules.evaluate([first, second])
    #expect(result.values == [[1, 1, 1, 1, 0], [1, 0, 0, 0, 1]])
    #expect(result.frequencies == [2, 1, 1, 1, 1])
    #expect(result.evidence[0][0].map { $0.text(in: first.text) } == ["Casa", "casa", "mare"])
    let crosstab = try result.crosstab(groups: ["A", nil])
    #expect(crosstab.counts == [[1, 1, 1, 1, 0]])
    #expect(crosstab.missing == 1)
}

@Test("Regole: near, seq, frasi e confini di frase e paragrafo")
func khCodingRulesProximityAndBoundaries() throws {
    let rules = try GlifiCodingRuleSet(
        """
        *Frase
        casa+mare
        *Ordine
        seq(casa-mare)[2]
        *FraseSolo
        near(casa-mare)[b0]
        *Paragrafo
        near(casa-mare)[d0]
        *Stringa
        'casa mare'
        """)
    let result = try rules.evaluate([
        GlifiCodingDocument(id: "1", text: "casa mare"),
        GlifiCodingDocument(id: "2", text: "casa. mare"),
        GlifiCodingDocument(id: "3", text: "mare.\n\ncasa"),
    ])
    #expect(result.values == [[1, 1, 1, 1, 1], [1, 1, 0, 1, 0], [0, 0, 0, 0, 0]])
}

@Test("Regole rifiutano cicli, variabili o annotazioni mancanti e divisione per zero")
func khCodingRulesFailClosed() throws {
    for source in ["*A\n<*A>", "*A\n<*B>", "*A\n( casa", "*A\n'casa", "*A\nnear(casa-casa)"] {
        if source.contains("near") {
            let rules = try GlifiCodingRuleSet(source)
            #expect(throws: GlifiFailure.self) {
                try rules.evaluate([GlifiCodingDocument(id: "1", text: "casa")])
            }
        } else {
            #expect(throws: GlifiFailure.self) { try GlifiCodingRuleSet(source) }
        }
    }
    for source in ["*A\ncasa / 0 > 1", "*A\n<>missing-->x", "*A\ncasa-->Noun"] {
        let rules = try GlifiCodingRuleSet(source)
        #expect(throws: GlifiFailure.self) {
            try rules.evaluate([GlifiCodingDocument(id: "1", text: "casa")])
        }
    }
}

@Test("Regole accettano annotazioni esplicite senza inventare lemma o POS")
func khCodingRulesExplicitLinguistics() throws {
    let text = "corre"
    let token = GlifiCodingToken(
        surface: text, base: "correre", partOfSpeech: "Verb", inflection: "V",
        range: try GlifiUTF8Range(start: 0, end: 5), sentence: 0, paragraph: 0)
    let document = try GlifiCodingDocument(
        id: "1", text: text, tokens: [token], linguisticContract: "test-lemma-v1")
    let result = try GlifiCodingRuleSet("*A\ncorrere-->Verb=>corre\n*B\ncorrere->V").evaluate([
        document
    ])
    #expect(result.values == [[1, 1]])
}

@Test("Gli operatori osservano la cancellazione prima del lavoro numerico")
func khOperatorsCancellation() async throws {
    let task = Task {
        try await Task.sleep(for: .milliseconds(10))
        return try GlifiExploratoryAnalysis.selfOrganizingMap(
            [[0], [1]], width: 2, height: 1, seed: 0)
    }
    task.cancel()
    do {
        _ = try await task.value
        Issue.record("Cancellation ignored")
    } catch is CancellationError {}
}

@Test("LDA Gibbs coincide entro tolleranza con l'integrazione esatta di tutti gli stati")
func khLDAEnumeratedPosteriorOracle() throws {
    let result = try GlifiLatentDirichletAllocation.fit(
        documents: [["rosso", "rosso"], ["blu"]], topicCount: 2, seed: 19,
        alpha: 0.1, beta: 1, burnIn: 1_000, sampleCount: 10_000, thinning: 4
    )
    for row in result.documentTopics { for value in row { #expect(abs(value - 0.5) < 0.02) } }
    for row in result.topicTerms {
        #expect(abs(row[0] - 0.453333333333333) < 0.02)
        #expect(abs(row[1] - 0.546666666666667) < 0.02)
    }
}

@Test("Regole ostili, profondità e riferimenti espansivi restano bounded")
func khCodingAdversarialBounds() throws {
    #expect(throws: GlifiFailure.self) {
        try GlifiCodingRuleSet(
            "*A\n" + String(repeating: "( ", count: 40) + "casa"
                + String(repeating: " )", count: 40))
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiCodingRuleSet("*A\n" + String(repeating: "casa | ", count: 1_024) + "casa")
    }
    var text = "*A0\ncasa\n"
    for index in 1..<20 { text += "*A\(index)\n<*A\(index - 1)> + <*A\(index - 1)>\n" }
    let rules = try GlifiCodingRuleSet(text)
    let result = try rules.evaluate([GlifiCodingDocument(id: "1", text: "casa")])
    #expect(result.values[0].allSatisfy { $0 == 1 })
    #expect(result.evidence[0].allSatisfy { $0.count == 1 })
}

@Test("Clustering su dissimilarità coincide con hclust R e alimenta una rete di codici")
func khDissimilarityClusteringAndCodeNetwork() throws {
    let points: [[Double]] = [[0], [1], [4]]
    let distances = try GlifiTextMatrixOperators.dissimilarities(points, metric: .euclidean)
    for linkage in [GlifiLinkage.single, .complete, .average] {
        let tree = try GlifiTextMatrixOperators.hierarchicalClustering(
            dissimilarities: distances, linkage: linkage)
        #expect(tree.merges[0].height == 1)
        let expected = linkage == .single ? 3.0 : linkage == .complete ? 4.0 : 3.5
        #expect(tree.merges[1].height == expected)
        #expect(
            try GlifiMultivariateMethods.cut(tree, pointCount: 3, clusterCount: 2) == [0, 0, 1])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTextMatrixOperators.hierarchicalClustering(
            dissimilarities: distances, linkage: .ward)
    }
    let graph = try GlifiTextMatrixOperators.cooccurrenceNetwork(
        [[1, 1], [1, 0]], labels: ["A", "B"])
    #expect(graph.edges.count == 2)
    #expect(graph.edges.allSatisfy { $0.weight == 0.5 })
}

@Test("SOM aggregata coincide con la formula batch diretta su ogni prototipo")
func khSOMGroupedMatchesDirectFormula() throws {
    let data: [[Double]] = [[0, 1], [2, 3], [4, 0], [10, 11], [11, 10], [12, 12]]
    var random = GlifiSplitMix64(seed: 27)
    var prototypes = (0..<4).map { _ in data[random.index(below: data.count)] }
    for epoch in 0..<3 {
        let radius = 2 * pow(0.25, Double(epoch) / 2)
        func squared(_ a: [Double], _ b: [Double]) -> Double {
            zip(a, b).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
        }
        let winners = data.map { row in
            prototypes.indices.min {
                let a = squared(row, prototypes[$0])
                let b = squared(row, prototypes[$1])
                return a == b ? $0 < $1 : a < b
            } ?? 0
        }
        prototypes = prototypes.indices.map { unit in
            var sum = [0.0, 0.0]
            var total = 0.0
            for (index, row) in data.enumerated() {
                let winner = winners[index]
                let dx = Double(unit % 2 - winner % 2)
                let dy = Double(unit / 2 - winner / 2)
                let weight = exp(-(dx * dx + dy * dy) / (2 * radius * radius))
                total += weight
                for column in 0..<2 { sum[column] += weight * row[column] }
            }
            return sum.map { $0 / total }
        }
    }
    let native = try GlifiExploratoryAnalysis.selfOrganizingMap(
        data, width: 2, height: 2, seed: 27, epochs: 3)
    for (a, b) in zip(native.prototypes.flatMap { $0 }, prototypes.flatMap { $0 }) {
        #expect(abs(a - b) < 1e-12)
    }
}

@Test("Una coppia di codici mai applicati non forma un arco di co-occorrenza")
func khNetworkDoesNotConnectEmptyColumns() throws {
    let graph = try GlifiTextMatrixOperators.cooccurrenceNetwork(
        [[0, 0, 1]], labels: ["A", "B", "C"], minimumJaccard: 0)
    #expect(graph.edges.isEmpty)
}

@Test("Gli estremi numerici non diventano risultati finiti ma falsi")
func khNumericExtremesFailClosed() throws {
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.multidimensionalScaling(
            [[0, 1e200], [1e200, 0]], dimensions: 1)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiExploratoryAnalysis.selfOrganizingMap(
            [[0], [1]], width: 1, height: 1, seed: 0, finalRadius: 1e-300)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTextMatrixOperators.transform(
            [[Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude]], using: .perThousand)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTextMatrixOperators.dissimilarities([[1e200], [1e200]], metric: .cosine)
    }
}
