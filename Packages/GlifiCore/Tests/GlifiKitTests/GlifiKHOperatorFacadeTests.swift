// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit
import Testing

@Test("La facciata headless espone le nuove famiglie senza importare Core")
func khKitOperators() async throws {
    let mds = try await GlifiStudioTextAnalytics.multidimensionalScaling(
        [[0, 1], [1, 0]], dimensions: 1)
    #expect(mds.stress < 1e-24)
    let som = try await GlifiStudioTextAnalytics.selfOrganizingMap(
        [[0], [2]], width: 1, height: 1, seed: 0, epochs: 2)
    #expect(som.prototypes == [[1]])
    let classifier = try await GlifiStudioTextAnalytics.trainClassifier(
        documents: [["rosso"], ["blu"]], labels: ["A", "B"])
    let prediction = try await classifier.predict([["rosso"]])
    #expect(prediction.labels == ["A"])
    let topics = try await GlifiStudioTextAnalytics.topics(
        documents: [["rosso"], ["blu"]], topicCount: 1, seed: 0,
        burnIn: 0, sampleCount: 1, thinning: 1)
    #expect(topics.topicTerms == [[0.5, 0.5]])
    let codes = try await GlifiStudioTextAnalytics.code(
        [GlifiStudioAutomaticCodingUnit(id: "1", text: "casa")], rules: "*Casa\ncasa")
    #expect(codes.values == [[1]])
}

@Test("La facciata conserva errori tipizzati, localizzabili e privi di testo sensibile")
func khKitTypedFailures() async throws {
    do {
        _ = try await GlifiStudioTextAnalytics.code(
            [GlifiStudioAutomaticCodingUnit(id: "private", text: "secret-canary")],
            rules: "*private\n<>missing-->secret-canary")
        Issue.record("Missing variable accepted")
    } catch let failure {
        #expect(failure.code == "coding.missing-variable")
        #expect(failure.category == "insufficientData")
        #expect(failure.arguments.isEmpty)
        #expect(!String(describing: failure).contains("secret-canary"))
    }
}

@Test("Gli stati di validazione sono riferiti al metodo, senza promuovere identificatori ignoti")
func khReviewedMethodStatus() async throws {
    let result = try await GlifiStudioTextAnalytics.multidimensionalScaling(
        [[0, 1, 1], [1, 0, 2], [1, 2, 0]], dimensions: 1, method: .kruskal)
    #expect(
        GlifiStudioTextAnalytics.validationStatus(forMethod: result.methodIdentifier) == "supported"
    )
    #expect(
        GlifiStudioTextAnalytics.validationStatus(forMethod: "unreviewed-method") == "candidate")
    #expect(GlifiStudioTextAnalytics.validationStatus == "candidate")
}
