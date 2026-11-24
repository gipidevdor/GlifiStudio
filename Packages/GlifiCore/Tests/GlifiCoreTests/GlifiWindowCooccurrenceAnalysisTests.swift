// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La finestra simmetrica riproduce i conteggi e le misure calcolati a mano")
func symmetricWindowMatchesHandDerivedTables() throws {
    // «alfa beta alfa gamma», finestra ±1: le coppie ordinate nodo→collocato sono
    // alfa→beta ×2, beta→alfa ×2, alfa→gamma, gamma→alfa: M=6.
    // Totali di riga alfa=3, beta=2, gamma=1; di colonna beta=2, alfa=3, gamma=1.
    // (alfa,beta): a=2, b=3-2=1, c=2-2=0, d=6-2-1-0=3
    // Dice=4/5, Jaccard=2/3, PMI=ln[(2/6)/((3/6)(2/6))]=ln 2,
    // t-score=(2-E)/√2 con E=3·2/6=1, logDice=14+log2(4/5).
    // (alfa,gamma): a=1, b=2, c=0, d=3, Dice=2/4.
    let options = try GlifiWindowCooccurrenceOptions(
        leftSpan: 1,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 100
    )

    let analysis = try GlifiWindowCollocationAnalyzer().analyze(
        [
            try windowSource(
                "alfa beta alfa gamma", revision: "00000000-0000-0000-0000-000000000021")
        ],
        options: options
    )

    #expect(analysis.universeSize == 6)
    #expect(analysis.tokenCount == 4)
    #expect(analysis.pairs.count == 2)
    let beta = try #require(analysis.pairs.first { $0.collocateTerm == "beta" })
    #expect(beta.nodeTerm == "alfa")
    #expect(beta.jointCount == 2)
    #expect(beta.nodeOnlyCount == 1)
    #expect(beta.collocateOnlyCount == 0)
    #expect(beta.neitherCount == 3)
    #expect(abs((beta.dice ?? .nan) - 0.8) < 1e-12)
    #expect(abs((beta.jaccard ?? .nan) - 2.0 / 3.0) < 1e-12)
    #expect(abs((beta.pmi ?? .nan) - log(2.0)) < 1e-12)
    #expect(abs((beta.tScore ?? .nan) - 1.0 / 2.0.squareRoot()) < 1e-12)
    #expect(abs((beta.logDice ?? .nan) - (14 + log2(0.8))) < 1e-12)
    let gamma = try #require(analysis.pairs.first { $0.collocateTerm == "gamma" })
    #expect(gamma.jointCount == 1)
    #expect(gamma.nodeOnlyCount == 2)
    #expect(abs((gamma.dice ?? .nan) - 0.5) < 1e-12)
    #expect(analysis.pairs.first == beta)
}

@Test("La finestra a destra conserva la direzione node→collocato")
func directionalWindowKeepsOrderedPairs() throws {
    // «alfa beta alfa gamma», solo il token successivo: alfa→beta, beta→alfa,
    // alfa→gamma; M=3. (beta→alfa): a=1, b=1-1=0, c=1-1=0, d=3-1=2.
    let options = try GlifiWindowCooccurrenceOptions(
        leftSpan: 0,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 100
    )

    let analysis = try GlifiWindowCollocationAnalyzer().analyze(
        [
            try windowSource(
                "alfa beta alfa gamma", revision: "00000000-0000-0000-0000-000000000022")
        ],
        options: options
    )

    #expect(analysis.universeSize == 3)
    let keys = analysis.pairs.map { "\($0.nodeTerm)>\($0.collocateTerm)" }.sorted()
    #expect(keys == ["alfa>beta", "alfa>gamma", "beta>alfa"])
    let backward = try #require(analysis.pairs.first { $0.nodeTerm == "beta" })
    #expect(backward.jointCount == 1)
    #expect(backward.nodeOnlyCount == 0)
    #expect(backward.collocateOnlyCount == 0)
    #expect(backward.neitherCount == 2)
}

@Test("I confini di frase bloccano la finestra salvo richiesta esplicita")
func sentenceBoundariesAreExplicitInWindow() throws {
    let source = try windowSource(
        "uno due. tre quattro.",
        revision: "00000000-0000-0000-0000-000000000023"
    )
    func universe(crossing: Bool) throws -> Int {
        let options = try GlifiWindowCooccurrenceOptions(
            leftSpan: 1,
            rightSpan: 1,
            crossesSentences: crossing,
            includesSelfPairs: false,
            minimumJointCount: 1,
            maximumPairCount: 100
        )
        return try GlifiWindowCollocationAnalyzer().analyze([source], options: options)
            .universeSize
    }

    // Senza attraversamento: uno-due e tre-quattro, 2 ordini ciascuna = 4.
    // Con attraversamento si aggiunge due-tre = 6.
    #expect(try universe(crossing: false) == 4)
    #expect(try universe(crossing: true) == 6)
}

@Test("Le autocoppie e le finestre non valide sono dichiarate, non implicite")
func selfPairsAndInvalidWindowsAreExplicit() throws {
    let source = try windowSource(
        "alfa alfa",
        revision: "00000000-0000-0000-0000-000000000024"
    )
    let excluded = try GlifiWindowCooccurrenceOptions(
        leftSpan: 1,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 10
    )
    let included = try GlifiWindowCooccurrenceOptions(
        leftSpan: 1,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: true,
        minimumJointCount: 1,
        maximumPairCount: 10
    )

    do {
        _ = try GlifiWindowCollocationAnalyzer().analyze([source], options: excluded)
        Issue.record("Senza autocoppie non resta alcuna coppia")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "window-cooccurrence.no-pairs")
    }
    let analysis = try GlifiWindowCollocationAnalyzer().analyze([source], options: included)
    #expect(analysis.universeSize == 2)
    #expect(analysis.pairs.count == 1)
    #expect(analysis.pairs.first?.jointCount == 2)

    do {
        _ = try GlifiWindowCooccurrenceOptions(
            leftSpan: 0,
            rightSpan: 0,
            crossesSentences: false,
            includesSelfPairs: false,
            minimumJointCount: 1,
            maximumPairCount: 10
        )
        Issue.record("Una finestra vuota non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "window-cooccurrence.invalid-options")
    }
}

@Test("La finestra non attraversa i documenti e il risultato è deterministico")
func windowDoesNotCrossDocumentsAndIsDeterministic() throws {
    let first = try windowSource("alfa", revision: "00000000-0000-0000-0000-000000000025")
    let second = try windowSource("beta", revision: "00000000-0000-0000-0000-000000000026")
    let options = try GlifiWindowCooccurrenceOptions(
        leftSpan: 2,
        rightSpan: 2,
        crossesSentences: true,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 10
    )

    do {
        _ = try GlifiWindowCollocationAnalyzer().analyze([first, second], options: options)
        Issue.record("Documenti di un solo token non devono produrre coppie")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "window-cooccurrence.no-pairs")
    }
    let both = try windowSource(
        "alfa beta gamma",
        revision: "00000000-0000-0000-0000-000000000027"
    )
    let one = try GlifiWindowCollocationAnalyzer().analyze([both, first], options: options)
    let two = try GlifiWindowCollocationAnalyzer().analyze([first, both], options: options)
    #expect(one == two)
    #expect(one.sourceRevisionIDs == one.sourceRevisionIDs.sorted())
}

private func windowSource(_ text: String, revision: String) throws -> GlifiImportedText {
    try GlifiTextImporter().importText(
        from: Data(text.utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(uuid: try #require(UUID(uuidString: revision)))
    )
}

@Test("Le collocazioni a finestra conservano posizioni, distanza media e peso 1/d")
func windowCollocationsKeepLineageAndDistanceWeights() throws {
    // «alfa beta gamma», finestra ±2 con peso 1/d: (alfa,gamma) a distanza 2 in una sola
    // direzione conservata (alfa→gamma), peso 1/2; «alfa» occupa i byte 0..<4,
    // «gamma» 10..<15.
    let source = try windowSource(
        "alfa beta gamma",
        revision: "00000000-0000-0000-0000-000000000028"
    )
    let options = try GlifiWindowCooccurrenceOptions(
        leftSpan: 2,
        rightSpan: 2,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 10,
        distanceWeighting: .inverseDistance,
        maximumPositionsPerPair: 5
    )
    let analysis = try GlifiWindowCollocationAnalyzer().analyze([source], options: options)
    #expect(analysis.analysisIdentifier == "corpus-window-collocation-v2")
    let far = try #require(
        analysis.pairs.first { $0.nodeTerm == "alfa" && $0.collocateTerm == "gamma" })
    #expect(far.meanDistance == 2)
    #expect(far.weightedJointCount == 0.5)
    let occurrence = try #require(far.occurrences.first)
    #expect(occurrence.nodeRange == (try GlifiUTF8Range(start: 0, end: 4)))
    #expect(occurrence.collocateRange == (try GlifiUTF8Range(start: 10, end: 15)))
    #expect(occurrence.offset == 2)
    #expect(occurrence.sourceRevisionID == source.sourceRevisionID.canonicalValue)
    #expect(!far.occurrencesTruncated)

    // «alfa beta alfa», ±1, una sola posizione per coppia: alfa→beta osservata due volte
    // (offset +1 e -1), quindi la lista di posizioni è troncata.
    let repeated = try windowSource(
        "alfa beta alfa",
        revision: "00000000-0000-0000-0000-000000000029"
    )
    let bounded = try GlifiWindowCooccurrenceOptions(
        leftSpan: 1,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 10,
        maximumPositionsPerPair: 1
    )
    let pair = try #require(
        try GlifiWindowCollocationAnalyzer().analyze([repeated], options: bounded).pairs.first
    )
    #expect(pair.jointCount == 2)
    #expect(pair.weightedJointCount == 2)
    #expect(pair.occurrences.count == 1)
    #expect(pair.occurrencesTruncated)
}

@Test("La rete a finestra applica soglie, direzione e misure di grafo verificate")
func windowNetworkAppliesThresholdsAndGraphMeasures() throws {
    // «alfa beta gamma», ±1: archi alfa–beta e beta–gamma (cammino di tre nodi).
    // Autovalore √2, autovettore scalato [1/√2, 1, 1/√2]; betweenness pesata di beta = 2.
    let source = try windowSource(
        "alfa beta gamma",
        revision: "00000000-0000-0000-0000-00000000002a"
    )
    let symmetric = try GlifiWindowCooccurrenceOptions(
        leftSpan: 1,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 10
    )
    let network = try GlifiWindowNetworkAnalyzer().analyze(
        [source],
        options: GlifiWindowNetworkOptions(
            window: symmetric,
            minimumLogDice: nil,
            usesWeightedJointCount: false
        )
    )
    #expect(network.graphIdentifier == "symmetric-window-undirected-v1")
    #expect(network.summary.nodeCount == 3)
    #expect(network.summary.edgeCount == 2)
    #expect(network.summary.weakComponentCount == 1)
    #expect(abs((network.summary.eigenvalue ?? .nan) - 2.0.squareRoot()) < 1e-10)
    let beta = try #require(network.nodes.first { $0.term == "beta" })
    #expect(abs(beta.eigenvector - 1) < 1e-10)
    #expect(beta.weightedBetweenness == 2)
    let alfa = try #require(network.nodes.first { $0.term == "alfa" })
    #expect(abs(alfa.eigenvector - 1 / 2.0.squareRoot()) < 1e-10)
    #expect(network.edges.allSatisfy { !$0.occurrences.isEmpty })

    // Entrambe le coppie hanno Dice 2/3, logDice 14+log2(2/3)≈13,415: la soglia 13,5 le
    // esclude tutte e la rete vuota è rifiutata invece di restituire un grafo vuoto.
    do {
        _ = try GlifiWindowNetworkAnalyzer().analyze(
            [source],
            options: GlifiWindowNetworkOptions(
                window: symmetric,
                minimumLogDice: 13.5,
                usesWeightedJointCount: false
            )
        )
        Issue.record("La soglia avrebbe dovuto escludere ogni arco")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "window-network.no-edges")
    }

    // Finestra solo a destra: archi diretti alfa→beta→gamma, una componente debole e tre
    // componenti forti.
    let directional = try GlifiWindowNetworkAnalyzer().analyze(
        [source],
        options: GlifiWindowNetworkOptions(
            window: try GlifiWindowCooccurrenceOptions(
                leftSpan: 0,
                rightSpan: 1,
                crossesSentences: false,
                includesSelfPairs: false,
                minimumJointCount: 1,
                maximumPairCount: 10
            ),
            minimumLogDice: nil,
            usesWeightedJointCount: false
        )
    )
    #expect(directional.graphIdentifier == "directional-window-directed-v1")
    #expect(directional.summary.weakComponentCount == 1)
    #expect(directional.summary.strongComponentCount == 3)
}
