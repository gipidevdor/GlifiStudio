// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Jaccard pesato, Dice multinsieme e KL con Lidstone coincidono con i valori a mano")
func weightedSimilaritiesMatchHandValues() throws {
    // Vocabolario [casa, città, mare]; frequenze relative [2/3,0,1/3] e [1/3,2/3,0]:
    // Σmin=1/3, Σmax=5/3 → Ruzicka 1/5. Conteggi [2,0,1] e [1,2,0]: Dice 2·1/6 = 1/3.
    #expect(
        abs(
            try GlifiVectorSimilarity.weightedJaccard(
                [2.0 / 3, 0, 1.0 / 3], [1.0 / 3, 2.0 / 3, 0]) - 0.2) < 1e-12)
    #expect(abs(try GlifiVectorSimilarity.multisetDice([2, 0, 1], [1, 2, 0]) - 1.0 / 3.0) < 1e-12)
    // Lidstone α=½, V=3: (c+½)/(N+3/2); KL-v1 è espressa in bit (log2).
    let smoothed = try GlifiProbabilityDivergence.lidstone([2, 0, 1], alpha: 0.5)
    #expect(zip(smoothed, [2.5 / 4.5, 0.5 / 4.5, 1.5 / 4.5]).allSatisfy { abs($0 - $1) < 1e-15 })
    let other = try GlifiProbabilityDivergence.lidstone([1, 2, 0], alpha: 0.5)
    let expected = zip(smoothed, other).reduce(0.0) { $0 + $1.0 * log2($1.0 / $1.1) }
    #expect(abs(try GlifiProbabilityDivergence.klDivergence(smoothed, other) - expected) < 1e-12)
    #expect(throws: GlifiFailure.self) {
        try GlifiProbabilityDivergence.lidstone([1, 2], alpha: 0)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiVectorSimilarity.weightedJaccard([0, 0], [0, 0])
    }
}

@Test("Le distanze metriche rispettano la disuguaglianza triangolare su tutte le terne")
func metricDistancesSatisfyTriangleInequality() throws {
    // Dodici distribuzioni su cinque categorie generate da SplitMix64 (seed 17), con zeri:
    // si verificano tutte le 220 terne per Euclidea, Manhattan, Hellinger e JS-distanza.
    var generator = GlifiSplitMix64(seed: 17)
    let vectors: [[Double]] = (0..<12).map { _ in
        let raw = (0..<5).map { _ -> Double in
            let value = Double(generator.next() >> 11) / Double(1 << 53)
            return value < 0.2 ? 0 : value
        }
        let total = max(raw.reduce(0, +), 1e-9)
        return raw.map { $0 / total }
    }
    let distances: [([Double], [Double]) throws -> Double] = [
        GlifiVectorSimilarity.euclidean,
        GlifiVectorSimilarity.manhattan,
        GlifiProbabilityDivergence.hellinger,
        GlifiProbabilityDivergence.jensenShannonDistance,
    ]
    var checked = 0
    for distance in distances {
        for a in 0..<12 {
            for b in (a + 1)..<12 {
                for c in (b + 1)..<12 {
                    let ab = try distance(vectors[a], vectors[b])
                    let bc = try distance(vectors[b], vectors[c])
                    let ac = try distance(vectors[a], vectors[c])
                    #expect(ac <= ab + bc + 1e-12)
                    #expect(ab <= ac + bc + 1e-12)
                    #expect(bc <= ab + ac + 1e-12)
                    checked += 1
                }
            }
        }
    }
    #expect(checked == 4 * 220)
}

@Test("La dispersione su partizione dichiarata coincide con la primitiva sulle parti sommate")
func declaredPartitionDispersionMatchesPrimitive() throws {
    let sources = try [
        ("casa mare casa", "00000000-0000-0000-0000-0000000000a1"),
        ("mare", "00000000-0000-0000-0000-0000000000a2"),
        ("casa casa sole", "00000000-0000-0000-0000-0000000000a3"),
    ].map { text, revision in
        try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: SourceRevisionID(uuid: try #require(UUID(uuidString: revision)))
        )
    }
    let corpus = try GlifiCorpusAnalyzer().analyze(sources)
    let ids = corpus.matrix.rowSourceRevisionIDs.map(\.canonicalValue)
    // Parti: {d1,d2} (4 token: casa 2, mare 2) e {d3} (3 token: casa 2, sole 1).
    let result = try GlifiCorpusDispersionAnalyzer().analyze(
        corpus,
        partition: [[ids[0], ids[1]], [ids[2]]]
    )
    #expect(result.partitionIdentifier == "declared-partition-v1")
    #expect(result.unitSizes == [4, 3])
    let casa = try #require(result.terms.first { $0.term == "casa" })
    let direct = try GlifiDispersionAnalysis.dispersion(
        try GlifiDispersionPartition(unitSizes: [4, 3], unitFrequencies: [2, 2])
    )
    #expect(abs(casa.griesDP - direct.griesDP) < 1e-15)
    #expect(casa.documentFrequency == 2)
    #expect(throws: GlifiFailure.self) {
        try GlifiCorpusDispersionAnalyzer().analyze(corpus, partition: [[ids[0]], [ids[1]]])
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiCorpusDispersionAnalyzer().analyze(corpus, partition: [ids])
    }
}

@Test("Il validatore della xref accetta offset coerenti e rifiuta un offset spostato")
func crossReferenceValidatorDetectsShift() throws {
    let head = "%PDF-1.3\n1 0 obj\n<<>>\nendobj\n"
    let second = "2 0 obj\n<<>>\nendobj\n"
    func field(_ value: Int) -> String { String(format: "%010d", value) }
    func document(secondOffset: Int) -> Data {
        let xrefStart = (head + second).utf8.count
        return Data(
            (head + second + "xref\n0 3\n0000000000 65535 f \n\(field(9)) 00000 n \n"
                + "\(field(secondOffset)) 00000 n \ntrailer\n<< /Size 3 >>\nstartxref\n"
                + "\(xrefStart)\n%%EOF\n").utf8
        )
    }
    let valid = head.utf8.count
    #expect(
        GlifiScientificExportRenderer.validateCrossReferenceTable(document(secondOffset: valid)))
    #expect(
        !GlifiScientificExportRenderer.validateCrossReferenceTable(
            document(secondOffset: valid + 1)))
}

@Test("Il bootstrap a blocchi con L=1 coincide con il bootstrap i.i.d.")
func movingBlockBootstrapReducesToIID() throws {
    let sequence: [Double] = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3]
    let blocks = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
        sequence,
        blockLength: 1,
        resampleCount: 800,
        seed: 21
    )
    let independent = try GlifiStatisticalFoundation.bootstrapMeanInterval(
        sequence,
        resampleCount: 800,
        seed: 21
    )
    #expect(blocks == independent)
    let wide = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
        sequence,
        blockLength: 3,
        resampleCount: 800,
        seed: 21
    )
    #expect(wide.lower <= wide.estimate)
    #expect(wide.upper >= wide.estimate)
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
            sequence,
            blockLength: 11,
            seed: 1
        )
    }
}
