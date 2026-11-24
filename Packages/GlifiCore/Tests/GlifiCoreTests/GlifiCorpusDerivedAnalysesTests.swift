// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Associazione documento×termine coincide con χ², V e p calcolati per frazioni esatte")
func corpusAssociationMatchesExactTable() throws {
    // Documenti A={casa:2,mare:1} e B={casa:1,città:2}; n=6. Attese
    // A=[1,5;1;0,5], B uguali: χ²=1/6+1+1/2+1/6+1+1/2=10/3, gdl=2,
    // p=exp(-χ²/2) (forma chiusa a due gradi di libertà), V=sqrt(χ²/6).
    let analysis = try derivedCorpus([
        ("casa casa mare", "00000000-0000-0000-0000-000000000021"),
        ("casa città città", "00000000-0000-0000-0000-000000000022"),
    ])

    let result = try GlifiCorpusAssociationAnalyzer().analyze(analysis)

    #expect(abs(result.chiSquareStatistic - 10.0 / 3.0) < 1e-9)
    #expect(result.degreesOfFreedom == 2)
    #expect(abs(result.pValue - exp(-5.0 / 3.0)) < 1e-9)
    #expect(abs(result.cramersV - (5.0 / 9.0).squareRoot()) < 1e-9)
    #expect(result.totalObservations == 6)
    #expect(result.includedDocumentCount == 2)
    #expect(result.includedTermCount == 3)
    #expect(abs(result.lowExpectedCellFraction - 1) < 1e-12)
    #expect(result.topResiduals.count == 6)
    #expect(result.excludedSourceRevisionIDs.isEmpty)

    do {
        let single = try derivedCorpus([("casa mare", "00000000-0000-0000-0000-000000000023")])
        _ = try GlifiCorpusAssociationAnalyzer().analyze(single)
        Issue.record("Un solo documento non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "association.insufficient-table")
    }
}

@Test("Dispersione per termine coincide con DP, norma e Juilland D esatti su due documenti uguali")
func corpusDispersionMatchesExactValues() throws {
    // Due documenti da tre token. casa f=[2,1]: DP=1/6, norma=1/3, D=2/3.
    // città f=[0,2] e mare f=[1,0] (o il suo speculare): DP=1/2, norma=1, D=0.
    let analysis = try derivedCorpus([
        ("casa casa mare", "00000000-0000-0000-0000-000000000021"),
        ("casa città città", "00000000-0000-0000-0000-000000000022"),
    ])

    let result = try GlifiCorpusDispersionAnalyzer().analyze(analysis)

    #expect(result.unitSizes == [3, 3])
    #expect(result.equalSizePartition)
    let rows = Dictionary(uniqueKeysWithValues: result.terms.map { ($0.term, $0) })
    let casa = try #require(rows["casa"])
    #expect(casa.frequency == 3)
    #expect(casa.documentFrequency == 2)
    #expect(abs(casa.griesDP - 1.0 / 6.0) < 1e-9)
    #expect(abs(try #require(casa.griesDPNorm) - 1.0 / 3.0) < 1e-9)
    #expect(abs(try #require(casa.juillandD) - 2.0 / 3.0) < 1e-9)
    for term in ["città", "mare"] {
        let row = try #require(rows[term])
        #expect(abs(row.griesDP - 0.5) < 1e-9)
        #expect(abs(try #require(row.griesDPNorm) - 1) < 1e-9)
        #expect(abs(try #require(row.juillandD)) < 1e-9)
    }
    #expect(result.terms.first?.term == "casa")

    let unequal = try derivedCorpus([
        ("casa casa mare", "00000000-0000-0000-0000-000000000021"),
        ("casa", "00000000-0000-0000-0000-000000000022"),
    ])
    let unequalResult = try GlifiCorpusDispersionAnalyzer().analyze(unequal)
    #expect(!unequalResult.equalSizePartition)
    #expect(unequalResult.terms.allSatisfy { $0.juillandD == nil })
}

@Test("Il confronto fra gruppi riproduce Welch t, ANOVA e la metrica di frequenza relativa")
func groupMetricComparisonMatchesExactValues() throws {
    // Lunghezze dei documenti: g1=[3,4], g2=[3,5]; medie 3,5 e 4; varianze
    // 0,5 e 2. Welch: t=-0,5/sqrt(1,25)=-1/√5, gdl=25/17. ANOVA: SSB=0,25,
    // SSW=2,5, F=0,2 con (1,2) gdl; a df2=2 p=1-t/sqrt(2+t²) con t=√F.
    let first = try derivedCorpus([
        ("casa casa mare", "00000000-0000-0000-0000-000000000031"),
        ("mare mare mare mare", "00000000-0000-0000-0000-000000000032"),
    ])
    let second = try derivedCorpus([
        ("casa città città", "00000000-0000-0000-0000-000000000033"),
        ("città città città città città", "00000000-0000-0000-0000-000000000034"),
    ])

    let lengths = try GlifiGroupMetricAnalyzer().compare(
        groups: [first, second],
        metric: .lexicalTokenCount
    )

    #expect(lengths.groups.map(\.documentCount) == [2, 2])
    #expect(abs(lengths.groups[0].mean - 3.5) < 1e-12)
    #expect(abs(lengths.groups[1].mean - 4) < 1e-12)
    let welch = try #require(lengths.welch)
    let inverseRootFive: Double = 1 / 5.0.squareRoot()
    #expect(abs(welch.statistic + inverseRootFive) < 1e-9)
    #expect(abs(welch.degreesOfFreedom - 25.0 / 17.0) < 1e-9)
    let anova = try #require(lengths.anova)
    #expect(abs(anova.fStatistic - 0.2) < 1e-9)
    #expect(anova.numeratorDegreesOfFreedom == 1)
    #expect(anova.denominatorDegreesOfFreedom == 2)
    let t = 0.2.squareRoot()
    let expectedP: Double = 1 - t / (2 + t * t).squareRoot()
    #expect(abs(anova.pValue - expectedP) < 1e-9)

    // Frequenza relativa di "casa": g1=[2/3,0], g2=[1/3,0] → t=1/√5.
    let term = try GlifiGroupMetricAnalyzer().compare(
        groups: [first, second],
        metric: .termRelativeFrequency("Casa")
    )
    #expect(term.term == "casa")
    #expect(abs(try #require(term.welch).statistic - inverseRootFive) < 1e-9)

    // Con lunghezze [3,4] e [3,5] i tie (3,3) escludono il metodo esatto:
    // ranghi 1,5;1,5;3;4 → R₁=4,5, U₁=1,5, U₂=2,5; media 2, var=(4/12)(5-6/12)=1,5,
    // z=(1,5-2+0,5)/√1,5=0 con correzione di continuità, quindi p=1.
    // Kruskal–Wallis: R=4,5 e 5,5, H=0,6·(4,5²/2+5,5²/2)-15=0,15, C=0,9, H/C=1/6,
    // con df=1 la coda è erfc(√(H/2)).
    // Cohen d: SS=0,5 e 2, s_p²=2,5/2=1,25, d=-0,5/√1,25=-1/√5.
    #expect(abs(try #require(lengths.cohenD) + inverseRootFive) < 1e-12)
    let mannWhitney = try #require(lengths.mannWhitney)
    #expect(mannWhitney.methodIdentifier == "asymptotic-tie-corrected-continuity")
    #expect(mannWhitney.u1 == 1.5)
    #expect(mannWhitney.u2 == 2.5)
    #expect(abs(try #require(mannWhitney.zStatistic)) < 1e-12)
    #expect(abs(mannWhitney.pValue - 1) < 1e-12)
    let kruskal = try #require(lengths.kruskalWallis)
    #expect(abs(kruskal.hStatistic - 0.15) < 1e-12)
    #expect(abs(kruskal.tieCorrection - 0.9) < 1e-12)
    #expect(abs(kruskal.correctedHStatistic - 1.0 / 6.0) < 1e-12)
    #expect(abs(kruskal.pValue - erfc((1.0 / 12.0).squareRoot())) < 1e-9)

    // v5: ε²=(1/6)/3=1/18; J esatto con ν=2 è 1/√π; rank-biserial 2·1,5/4-1=-0,25.
    #expect(abs(try #require(lengths.kruskalWallis).epsilonSquared - 1.0 / 18.0) < 1e-12)
    let standardized = try #require(lengths.standardizedDifference)
    #expect(abs(standardized.cohenD + inverseRootFive) < 1e-12)
    #expect(abs(standardized.correctionFactor - 1 / Double.pi.squareRoot()) < 1e-12)
    #expect(lengths.rankBiserial == -0.25)
    #expect(lengths.contrasts.isEmpty)
    for group in lengths.groups {
        if let lower = group.bcaLower { #expect(lower <= group.mean) }
    }

    // Contrasto [1,-1]: stima -0,5, MSE=2,5/2, SE=√1,25, t=-1/√5 con ν=2,
    // p=1-|t|/√(t²+2)=1-1/√11. Seed e B dichiarati nella richiesta.
    let options = try GlifiGroupComparisonOptions(
        confidenceLevel: 0.9,
        bootstrapResampleCount: 500,
        permutationMonteCarloCount: 999,
        resamplingSeed: 7,
        contrasts: [[1, -1]]
    )
    let contrasted = try GlifiGroupMetricAnalyzer().compare(
        groups: [first, second],
        metric: .lexicalTokenCount,
        options: options
    )
    #expect(contrasted.resamplingSeed == 7)
    #expect(contrasted.bootstrapResampleCount == 500)
    #expect(contrasted.bootstrapConfidenceLevel == 0.9)
    let contrast = try #require(contrasted.contrasts.first)
    #expect(abs(contrast.estimate + 0.5) < 1e-12)
    #expect(abs(contrast.tStatistic + inverseRootFive) < 1e-12)
    #expect(abs(contrast.pValue - (1 - 1 / 11.0.squareRoot())) < 1e-12)
    let invalid = try GlifiGroupMetricAnalyzer().compare(
        groups: [first, second],
        metric: .lexicalTokenCount,
        options: try GlifiGroupComparisonOptions(
            confidenceLevel: 0.95,
            bootstrapResampleCount: 10,
            permutationMonteCarloCount: 10,
            resamplingSeed: 1,
            contrasts: [[1, 1]]
        )
    )
    #expect(invalid.contrasts.isEmpty)
    #expect(invalid.contrastsUnavailableReason == "statistics.invalid-contrast")
    #expect(throws: GlifiFailure.self) {
        try GlifiGroupComparisonOptions(
            confidenceLevel: 1,
            bootstrapResampleCount: 10,
            permutationMonteCarloCount: 10,
            resamplingSeed: 1,
            contrasts: []
        )
    }

    let three = try GlifiGroupMetricAnalyzer().compare(
        groups: [first, second, first],
        metric: .lexicalTokenCount
    )
    #expect(three.welch == nil)
    #expect(three.welchUnavailableReason == "statistics.requires-two-groups")
    #expect(three.anova != nil)
    #expect(three.mannWhitney == nil)
    #expect(three.mannWhitneyUnavailableReason == "statistics.requires-two-groups")
    #expect(three.kruskalWallis?.degreesOfFreedom == 2)
    #expect(three.cohenD == nil)
    #expect(three.cohenDUnavailableReason == "statistics.requires-two-groups")
    #expect(three.permutationUnavailableReason == "statistics.requires-two-groups")
}

@Test("Senza tie il confronto fra gruppi sceglie Mann–Whitney esatto")
func groupMetricComparisonSelectsExactMannWhitney() throws {
    // Lunghezze [3,4] e [5,6]: R₁=3, U₁=0, U₂=4. P(U≤0)=1/C(4,2)=1/6,
    // p bilaterale=2/6.
    let first = try derivedCorpus([
        ("casa casa casa", "00000000-0000-0000-0000-000000000051"),
        ("casa casa casa casa", "00000000-0000-0000-0000-000000000052"),
    ])
    let second = try derivedCorpus([
        ("casa casa casa casa casa", "00000000-0000-0000-0000-000000000053"),
        ("casa casa casa casa casa casa", "00000000-0000-0000-0000-000000000054"),
    ])

    let comparison = try GlifiGroupMetricAnalyzer().compare(
        groups: [first, second],
        metric: .lexicalTokenCount
    )

    // Permutazione esatta: somme delle 6 assegnazioni di [3,4,5,6] → differenze
    // -2,-1,0,0,1,2; osservata -2, bilaterale 2/6.
    let permutation = try #require(comparison.permutation)
    #expect(permutation.strategyIdentifier == "exact")
    #expect(permutation.evaluatedCount == 6)
    #expect(permutation.observedDifference == -2)
    #expect(abs(permutation.pValue - 1.0 / 3.0) < 1e-12)
    #expect(comparison.resamplingSeed == GlifiGroupMetricAnalyzer.resamplingSeed)
    #expect(comparison.generatorIdentifier == "SplitMix64-v1")
    for group in comparison.groups {
        let lower = try #require(group.bootstrapLower)
        let upper = try #require(group.bootstrapUpper)
        #expect(lower <= group.mean)
        #expect(group.mean <= upper)
    }
    let first4 = comparison.groups[0]
    #expect(try #require(first4.bootstrapLower) >= 3)
    #expect(try #require(first4.bootstrapUpper) <= 4)

    let test = try #require(comparison.mannWhitney)
    #expect(test.methodIdentifier == "exact")
    #expect(test.u1 == 0)
    #expect(test.zStatistic == nil)
    #expect(abs(test.pValue - 1.0 / 3.0) < 1e-12)
}

@Test("Collocazioni per presenza nei documenti coincidono con le tabelle e i valori attesi")
func corpusCollocationsMatchExactTables() throws {
    // d1={alfa,beta,gamma}, d2={alfa,beta}, d3={gamma}; M=3.
    // (alfa,beta): a=2,b=0,c=0,d=1 → NPMI=1, Dice=1, logDice=14, t=(2-4/3)/√2.
    // (alfa,gamma): a=1,b=1,c=1,d=0 → Dice=1/2, Jaccard=1/3, logDice=13.
    let analysis = try derivedCorpus([
        ("alfa beta gamma", "00000000-0000-0000-0000-000000000041"),
        ("alfa beta", "00000000-0000-0000-0000-000000000042"),
        ("gamma", "00000000-0000-0000-0000-000000000043"),
    ])

    let result = try GlifiCorpusCollocationAnalyzer().analyze(analysis)

    #expect(result.universeSize == 3)
    #expect(result.selectedTerms == ["alfa", "beta", "gamma"])
    #expect(result.evaluatedPairCount == 3)
    #expect(!result.isTruncated)
    let pairNames: [String] = result.pairs.map { pair in
        pair.firstTerm + "-" + pair.secondTerm
    }
    let expectedNames: [String] = ["alfa-beta", "alfa-gamma", "beta-gamma"]
    #expect(pairNames == expectedNames)
    let first = result.pairs[0]
    #expect(first.jointCount == 2)
    #expect(first.neitherCount == 1)
    #expect(abs(try #require(first.npmi) - 1) < 1e-9)
    #expect(abs(try #require(first.dice) - 1) < 1e-9)
    #expect(abs(try #require(first.logDice) - 14) < 1e-9)
    let expectedTScore: Double = (2.0 - 4.0 / 3.0) / 2.0.squareRoot()
    #expect(abs(try #require(first.tScore) - expectedTScore) < 1e-9)
    let second = result.pairs[1]
    #expect(second.firstOnlyCount == 1)
    #expect(second.secondOnlyCount == 1)
    #expect(abs(try #require(second.dice) - 0.5) < 1e-9)
    #expect(abs(try #require(second.jaccard) - 1.0 / 3.0) < 1e-9)
    #expect(abs(try #require(second.logDice) - 13) < 1e-9)

    do {
        _ = try GlifiCooccurrenceOptions(
            maximumTermCount: 1,
            minimumJointCount: 1,
            maximumPairCount: 10
        )
        Issue.record("Il numero di termini fuori limite non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "cooccurrence.invalid-options")
    }
}

@Test("La rete lessicale calcola grado, betweenness e closeness esatti su un triangolo")
func corpusLexicalNetworkMatchesExactTriangle() throws {
    // Le stesse tre coppie formano un triangolo con pesi 2, 1, 1: grado 2
    // per ogni nodo, pesi 3/3/2, nessun nodo intermedio (betweenness 0) e
    // HarmonicCloseness 2 (due nodi a distanza 1). PageRank somma a 1 e
    // alfa=beta>gamma per simmetria dei pesi.
    let analysis = try derivedCorpus([
        ("alfa beta gamma", "00000000-0000-0000-0000-000000000041"),
        ("alfa beta", "00000000-0000-0000-0000-000000000042"),
        ("gamma", "00000000-0000-0000-0000-000000000043"),
    ])

    let result = try GlifiCorpusLexicalNetworkAnalyzer().analyze(analysis)

    #expect(result.edgeCount == 3)
    #expect(result.pageRankConverged)
    let nodes = Dictionary(uniqueKeysWithValues: result.nodes.map { ($0.term, $0) })
    for term in ["alfa", "beta", "gamma"] {
        let node = try #require(nodes[term])
        #expect(node.degree == 2)
        #expect(node.betweenness == 0)
        #expect(abs(node.harmonicCloseness - 2) < 1e-12)
    }
    #expect(nodes["alfa"]?.weightedDegree == 3)
    #expect(nodes["gamma"]?.weightedDegree == 2)
    let alfa = try #require(nodes["alfa"]).pageRank
    let beta = try #require(nodes["beta"]).pageRank
    let gamma = try #require(nodes["gamma"]).pageRank
    #expect(abs(alfa - beta) < 1e-9)
    #expect(alfa > gamma)
    #expect(abs(alfa + beta + gamma - 1) < 1e-9)
}

@Test("L'accordo fra codificatori coincide con kappa 0 e alpha 1/8 esatti")
func codingAgreementMatchesExactValues() throws {
    // u1=[a,a], u2=[a,b], u3=[b,b], u4=[b,a]: po=pe=0,5 → κ=0; matrice delle
    // coincidenze o_aa=o_bb=o_ab=o_ba=2 → D_o=1/2, D_e=4/7 → α=1/8.
    let request = try GlifiCodingAgreementRequest(
        coderIdentifiers: ["c1", "c2"],
        units: [
            GlifiCodingUnit(unitIdentifier: "u1", labels: ["a", "a"]),
            GlifiCodingUnit(unitIdentifier: "u2", labels: ["a", "b"]),
            GlifiCodingUnit(unitIdentifier: "u3", labels: ["b", "b"]),
            GlifiCodingUnit(unitIdentifier: "u4", labels: ["b", "a"]),
        ]
    )

    let result = try GlifiCodingAgreementAnalyzer().analyze(request)

    #expect(abs(try #require(result.cohen).kappa) < 1e-9)
    #expect(abs(try #require(result.krippendorff).alpha - 0.125) < 1e-9)
    #expect(result.categoryCount == 2)
    #expect(result.missingJudgmentCount == 0)
    #expect(result.requestDigest.hasPrefix("sha256:"))
    #expect(result.requestDigest == (try request.canonicalDigest()))

    let three = try GlifiCodingAgreementRequest(
        coderIdentifiers: ["c1", "c2", "c3"],
        units: [
            GlifiCodingUnit(unitIdentifier: "u1", labels: ["a", "a", nil]),
            GlifiCodingUnit(unitIdentifier: "u2", labels: ["a", "b", "b"]),
        ]
    )
    let threeResult = try GlifiCodingAgreementAnalyzer().analyze(three)
    #expect(threeResult.cohen == nil)
    #expect(threeResult.cohenUnavailableReason == "agreement.requires-two-coders")
    #expect(threeResult.missingJudgmentCount == 1)
    #expect(threeResult.krippendorff != nil)

    do {
        _ = try GlifiCodingAgreementRequest(
            coderIdentifiers: ["c1", "c1"],
            units: [GlifiCodingUnit(unitIdentifier: "u1", labels: ["a", "a"])]
        )
        Issue.record("I codificatori duplicati non sono stati rifiutati")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "agreement.invalid-coders")
    }
    do {
        _ = try GlifiCodingAgreementRequest(
            coderIdentifiers: ["c1", "c2"],
            units: [GlifiCodingUnit(unitIdentifier: "u1", labels: ["a"])]
        )
        Issue.record("Le etichette disallineate non sono state rifiutate")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "agreement.invalid-units")
    }
}

@Test("Le nuove misure di similarità coincidono con le forme chiuse e KL indefinita è nil")
func corpusSimilarityExtraMeasuresMatchClosedForms() throws {
    // target=[2/3,0,1/3], reference=[1/3,2/3,0] sul vocabolario [casa,città,mare].
    let target = try derivedCorpus([("casa casa mare", "00000000-0000-0000-0000-000000000011")])
    let reference = try derivedCorpus([
        ("casa città città", "00000000-0000-0000-0000-000000000012")
    ])

    let comparison = try GlifiCorpusSimilarityAnalyzer().compare(
        target: target,
        reference: reference
    )

    #expect(abs(comparison.euclideanDistance - 6.0.squareRoot() / 3) < 1e-9)
    #expect(abs(comparison.manhattanDistance - 4.0 / 3.0) < 1e-9)
    let expectedHellinger: Double = (1 - 2.0.squareRoot() / 3).squareRoot()
    #expect(abs(comparison.hellingerDistance - expectedHellinger) < 1e-9)
    #expect(comparison.klTargetToReference == nil)
    #expect(comparison.klReferenceToTarget == nil)
    #expect(abs(comparison.jsDistance * comparison.jsDistance - comparison.jsDivergence) < 1e-9)
    #expect(comparison.jsDivergence > 0 && comparison.jsDivergence <= 1)

    let identical = try GlifiCorpusSimilarityAnalyzer().compare(target: target, reference: target)
    #expect(abs(identical.euclideanDistance) < 1e-12)
    #expect(abs(identical.hellingerDistance) < 1e-9)
    #expect(abs(try #require(identical.klTargetToReference)) < 1e-9)
}

private func derivedCorpus(_ documents: [(String, String)]) throws -> GlifiCorpusAnalysis {
    let sources = try documents.map { text, revision in
        try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: SourceRevisionID(
                uuid: try #require(UUID(uuidString: revision))
            )
        )
    }
    return try GlifiCorpusAnalyzer().analyze(
        sources,
        options: try GlifiCorpusAnalysisOptions(
            diversityWindowSize: 2,
            ngramSizes: [],
            maximumDocumentCount: max(documents.count, 1),
            maximumSourceByteCount: 1_024,
            maximumVocabularySize: 100,
            maximumDistinctNGramCount: 0,
            maximumNonZeroCellCount: 1_000
        )
    )
}

@Test("La correlazione fra metriche coincide con Pearson e Spearman calcolati a mano")
func metricCorrelationMatchesHandComputation() throws {
    // Documenti «casa mare», «casa mare×3», «casa mare×5»: lunghezze x=[2,4,6],
    // frequenze relative di «casa» y=[1/2,1/4,1/6]. Medie 4 e 11/36:
    // Sxy=-2/3, Sxx=8, Syy=13/216 → r=-2√(3/13), r²=12/13, t=-2√3 con df=1.
    // Con df=1 (Cauchy) p bilaterale=1-(2/π)·atan(|t|). Ranghi opposti: ρ=-1.
    let corpus = try derivedCorpus([
        ("casa mare", "00000000-0000-0000-0000-000000000061"),
        ("casa mare mare mare", "00000000-0000-0000-0000-000000000062"),
        ("casa mare mare mare mare mare", "00000000-0000-0000-0000-000000000063"),
    ])

    let analysis = try GlifiMetricCorrelationAnalyzer().analyze(
        corpus,
        first: .lexicalTokenCount,
        second: .termRelativeFrequency("Casa")
    )

    #expect(analysis.pairCount == 3)
    #expect(analysis.secondTerm == "casa")
    let pearson = try #require(analysis.pearson)
    #expect(abs(pearson.coefficient + 2 * (3.0 / 13.0).squareRoot()) < 1e-12)
    #expect(pearson.degreesOfFreedom == 1)
    let t = try #require(pearson.tStatistic)
    #expect(abs(t + 2 * 3.0.squareRoot()) < 1e-9)
    let expectedP = 1 - 2 / Double.pi * atan(2 * 3.0.squareRoot())
    #expect(abs(pearson.pValue - expectedP) < 1e-9)
    let spearman = try #require(analysis.spearman)
    #expect(spearman.coefficient == -1)
    #expect(spearman.tStatistic == nil)
    #expect(spearman.pValue == 0)
    // v2: con n=3 l'intervallo di Fisher-z non è definito (serve n≥4); il p esatto di
    // Spearman enumera 3! ranghi: P(ρ≤-1)=1/6, bilaterale 1/3.
    #expect(analysis.pearsonInterval == nil)
    #expect(analysis.pearsonIntervalUnavailableReason == "statistics.insufficient-sample-size")
    #expect(abs(try #require(analysis.spearmanExactPValue) - 1.0 / 3.0) < 1e-12)
}

@Test("La correlazione fra metriche richiede tre documenti e variabilità")
func metricCorrelationRejectsInsufficientData() throws {
    let two = try derivedCorpus([
        ("casa mare", "00000000-0000-0000-0000-000000000064"),
        ("casa mare mare", "00000000-0000-0000-0000-000000000065"),
    ])
    do {
        _ = try GlifiMetricCorrelationAnalyzer().analyze(
            two,
            first: .lexicalTokenCount,
            second: .lexicalTokenCount
        )
        Issue.record("Due documenti non bastano")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "metric-correlation.insufficient-documents")
    }

    let constant = try derivedCorpus([
        ("casa mare", "00000000-0000-0000-0000-000000000066"),
        ("mare casa", "00000000-0000-0000-0000-000000000067"),
        ("casa casa", "00000000-0000-0000-0000-000000000068"),
    ])
    let analysis = try GlifiMetricCorrelationAnalyzer().analyze(
        constant,
        first: .lexicalTokenCount,
        second: .termRelativeFrequency("casa")
    )
    #expect(analysis.pearson == nil)
    #expect(analysis.pearsonUnavailableReason == "statistics.non-positive-variance")
    #expect(analysis.spearman == nil)
}

@Test("Il post-hoc confronta ogni coppia e corregge ciascuna famiglia con Bonferroni e BH")
func postHocAdjustsEachFamily() throws {
    // Lunghezze g1=[3,4], g2=[5,6], g3=[1,2]; varianze 0,5, Welch con df=2 e
    // p=1-|t|/√(t²+2):
    // (1,2) t=-2√2 e (1,3) t=2√2 → a=1-2/√5; (2,3) t=4√2 → b=1-4/√17.
    // Bonferroni m=3: [3a,3a,3b]. BH: ordinati b,a,a → 3b, 3a/2, a; minimo da destra
    // → [a, a, 3b]. Mann–Whitney esatto: U₁=0,4,4, ogni p=1/3; Bonferroni 1, BH 1/3.
    let groups = try [
        derivedCorpus([
            ("casa casa casa", "00000000-0000-0000-0000-000000000071"),
            ("casa casa casa casa", "00000000-0000-0000-0000-000000000072"),
        ]),
        derivedCorpus([
            ("casa casa casa casa casa", "00000000-0000-0000-0000-000000000073"),
            ("casa casa casa casa casa casa", "00000000-0000-0000-0000-000000000074"),
        ]),
        derivedCorpus([
            ("casa", "00000000-0000-0000-0000-000000000075"),
            ("casa casa", "00000000-0000-0000-0000-000000000076"),
        ]),
    ]

    let analysis = try GlifiPostHocAnalyzer().compare(groups: groups, metric: .lexicalTokenCount)

    let a = 1 - 2 / 5.0.squareRoot()
    let b = 1 - 4 / 17.0.squareRoot()
    #expect(analysis.analysisIdentifier == "document-metric-pairwise-posthoc-v2")
    #expect(analysis.groupCount == 3)
    #expect(analysis.welchFamilySize == 3)
    #expect(analysis.mannWhitneyFamilySize == 3)
    #expect(
        analysis.pairs.map { [$0.firstGroupIndex, $0.secondGroupIndex] } == [
            [0, 1], [0, 2], [1, 2],
        ])
    #expect(analysis.pairs.map(\.meanDifference) == [-2, 2, 4])
    let welch = try analysis.pairs.map { try #require($0.welch) }
    let expectedRaw = [a, a, b]
    let expectedBonferroni = [3 * a, 3 * a, 3 * b]
    let expectedHochberg = [a, a, 3 * b]
    for index in 0..<3 {
        #expect(abs(welch[index].pValue - expectedRaw[index]) < 1e-9)
        #expect(abs(welch[index].bonferroniPValue - expectedBonferroni[index]) < 1e-9)
        #expect(abs(welch[index].benjaminiHochbergPValue - expectedHochberg[index]) < 1e-9)
    }
    #expect(abs((analysis.pairs[0].welchStatistic ?? .nan) + 2 * 2.0.squareRoot()) < 1e-9)
    // Procedure specifiche, verificate contro R in GlifiPostHocStatisticsTests: qui si
    // controlla che il nodo persistito le riporti per coppia senza alterarle.
    // Tukey: MSE=0,5 e n=2 → q=|diff|/0,5, cioè 4, 4 e 8, con ν=N-k=3.
    let samples: [[Double]] = [[3, 4], [5, 6], [1, 2]]
    let tukey = try GlifiStatisticalFoundation.tukeyHSD(samples)
    let gamesHowell = try GlifiStatisticalFoundation.gamesHowell(samples)
    let dunn = try GlifiStatisticalFoundation.dunn(samples)
    #expect(analysis.pairs.map { $0.tukey?.statistic } == [4, 4, 8])
    for (index, pair) in analysis.pairs.enumerated() {
        #expect(pair.tukey?.pValue == tukey[index].pValue)
        #expect(pair.tukey?.degreesOfFreedom == 3)
        #expect(pair.gamesHowell?.pValue == gamesHowell[index].pValue)
        #expect(pair.dunn?.statistic == dunn[index].statistic)
        #expect(pair.dunn?.bonferroniPValue == min(1, 3 * dunn[index].pValue))
        // Varianze 0,5 in ogni gruppo: s_p=√0,5, d=diff/√0,5; J esatto per ν=2.
        let difference = try #require(pair.standardizedDifference)
        #expect(abs(difference.cohenD - pair.meanDifference / 0.5.squareRoot()) < 1e-12)
        #expect(abs(difference.correctionFactor - exp(lgamma(1) - log(1) - lgamma(0.5))) < 1e-12)
    }
    // Rank-biserial da U₁=0,4,4 su 2×2: -1, 1, 1.
    #expect(analysis.pairs.map(\.rankBiserial) == [-1, 1, 1])
    #expect(analysis.tukeyUnavailableReason == nil)
    #expect(analysis.pairs.map(\.mannWhitneyU1) == [0, 4, 4])
    for pair in analysis.pairs {
        let test = try #require(pair.mannWhitney)
        #expect(pair.mannWhitneyMethodIdentifier == "exact")
        #expect(abs(test.pValue - 1.0 / 3.0) < 1e-12)
        #expect(test.bonferroniPValue == 1)
        #expect(abs(test.benjaminiHochbergPValue - 1.0 / 3.0) < 1e-12)
    }
}

@Test("Il post-hoc richiede almeno tre gruppi e riduce la famiglia ai test disponibili")
func postHocRequiresThreeGroupsAndShrinksFamily() throws {
    let single = try derivedCorpus([("casa", "00000000-0000-0000-0000-000000000077")])
    let pair = try derivedCorpus([
        ("casa casa", "00000000-0000-0000-0000-000000000078"),
        ("casa casa casa", "00000000-0000-0000-0000-000000000079"),
    ])
    do {
        _ = try GlifiPostHocAnalyzer().compare(groups: [single, pair], metric: .lexicalTokenCount)
        Issue.record("Due gruppi non sono un post-hoc")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "group-posthoc.insufficient-groups")
    }

    let other = try derivedCorpus([
        ("casa casa casa casa", "00000000-0000-0000-0000-00000000007a"),
        ("casa casa casa casa casa", "00000000-0000-0000-0000-00000000007b"),
    ])
    let analysis = try GlifiPostHocAnalyzer().compare(
        groups: [single, pair, other],
        metric: .lexicalTokenCount
    )
    // Solo la coppia (2,3) ha n≥2 in entrambi i gruppi: la famiglia Welch ha m=1,
    // quindi le p corrette coincidono con la grezza.
    #expect(analysis.welchFamilySize == 1)
    // Un gruppo di un solo documento: Tukey resta valido (MSE su N-k>0), Games–Howell no.
    #expect(analysis.pairs[0].tukey != nil)
    #expect(analysis.gamesHowellUnavailableReason == "statistics.insufficient-sample-size")
    #expect(analysis.pairs[0].gamesHowell == nil)
    #expect(analysis.pairs[0].welch == nil)
    #expect(analysis.pairs[0].welchUnavailableReason == "statistics.insufficient-sample-size")
    let only = try #require(analysis.pairs[2].welch)
    #expect(only.bonferroniPValue == only.pValue)
    #expect(only.benjaminiHochbergPValue == only.pValue)
}
