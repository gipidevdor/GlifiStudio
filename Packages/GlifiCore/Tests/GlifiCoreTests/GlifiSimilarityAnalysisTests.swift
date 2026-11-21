// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Jaccard e Dice rispettano i casi limite degli insiemi e i valori esatti attesi")
func setSimilarityMatchesSpecifiedCases() throws {
    let empty = Set<String>()
    #expect(GlifiSetSimilarity.jaccard(empty, empty) == 1)
    #expect(GlifiSetSimilarity.dice(empty, empty) == 1)

    let nonEmpty: Set<String> = ["a", "b"]
    #expect(GlifiSetSimilarity.jaccard(nonEmpty, empty) == 0)
    #expect(GlifiSetSimilarity.dice(nonEmpty, empty) == 0)
    #expect(GlifiSetSimilarity.jaccard(empty, nonEmpty) == 0)

    #expect(GlifiSetSimilarity.jaccard(nonEmpty, nonEmpty) == 1)
    #expect(GlifiSetSimilarity.dice(nonEmpty, nonEmpty) == 1)

    let a: Set<String> = ["a", "b", "c"]
    let b: Set<String> = ["b", "c", "d"]
    #expect(abs(GlifiSetSimilarity.jaccard(a, b) - 0.5) < 1e-12)
    #expect(abs(GlifiSetSimilarity.dice(a, b) - (2.0 / 3.0)) < 1e-9)
}

@Test("Coseno, euclidea e Manhattan coincidono con i valori attesi su vettori noti")
func vectorSimilarityMatchesKnownValues() throws {
    #expect(try abs(GlifiVectorSimilarity.cosine([1, 0], [0, 1])) < 1e-12)
    #expect(try abs(GlifiVectorSimilarity.cosine([1, 2, 3], [1, 2, 3]) - 1) < 1e-12)
    // Vettore parallelo (scalato): coseno = 1 indipendentemente dalla norma.
    #expect(try abs(GlifiVectorSimilarity.cosine([1, 2, 3], [2, 4, 6]) - 1) < 1e-9)

    // Triangolo 3-4-5.
    #expect(try abs(GlifiVectorSimilarity.euclidean([0, 0], [3, 4]) - 5) < 1e-12)
    #expect(try abs(GlifiVectorSimilarity.manhattan([0, 0], [3, 4]) - 7) < 1e-12)

    do {
        _ = try GlifiVectorSimilarity.cosine([0, 0], [1, 1])
        Issue.record("Il vettore nullo non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "similarity.zero-vector")
    }
    do {
        _ = try GlifiVectorSimilarity.euclidean([1, 2], [1, 2, 3])
        Issue.record("La dimensione disallineata non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "similarity.dimension-mismatch")
    }

    // Simmetria e disuguaglianza triangolare su un caso concreto.
    let x: [Double] = [0, 0]
    let y: [Double] = [3, 0]
    let z: [Double] = [3, 4]
    let xy = try GlifiVectorSimilarity.euclidean(x, y)
    let yx = try GlifiVectorSimilarity.euclidean(y, x)
    let yz = try GlifiVectorSimilarity.euclidean(y, z)
    let xz = try GlifiVectorSimilarity.euclidean(x, z)
    #expect(abs(xy - yx) < 1e-12)
    #expect(xz <= xy + yz + 1e-9)
}

@Test("KL, Jensen-Shannon ed Hellinger coincidono con i casi noti in forma chiusa")
func probabilityDivergenceMatchesClosedFormCases() throws {
    let uniform: [Double] = [0.5, 0.5]
    #expect(try abs(GlifiProbabilityDivergence.klDivergence(uniform, uniform)) < 1e-12)
    #expect(
        try abs(GlifiProbabilityDivergence.jensenShannonDivergence(uniform, uniform)) < 1e-12
    )
    #expect(try abs(GlifiProbabilityDivergence.hellinger(uniform, uniform)) < 1e-12)

    // Masse puntuali disgiunte su due esiti: caso estremo con forma chiusa nota.
    let pointA: [Double] = [1, 0]
    let pointB: [Double] = [0, 1]
    // KL(pointA‖pointB) è indefinita: q_2=0 dove p_2... in realtà p_1=1>0 e q_1=0.
    do {
        _ = try GlifiProbabilityDivergence.klDivergence(pointA, pointB)
        Issue.record("La KL indefinita non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "similarity.kl-undefined")
    }
    // JS(pointA,pointB) = 1 bit esatto: m=[0.5,0.5], KL(p‖m)=KL(q‖m)=log2(2)=1.
    let jsDivergence = try GlifiProbabilityDivergence.jensenShannonDivergence(pointA, pointB)
    #expect(abs(jsDivergence - 1) < 1e-9)
    let jsDistance = try GlifiProbabilityDivergence.jensenShannonDistance(pointA, pointB)
    #expect(abs(jsDistance - 1) < 1e-9)
    // Hellinger fra masse puntuali disgiunte è il massimo teorico, esattamente 1.
    let hellingerDistance = try GlifiProbabilityDivergence.hellinger(pointA, pointB)
    #expect(abs(hellingerDistance - 1) < 1e-9)

    // Simmetria di JS ed Hellinger.
    #expect(
        try abs(
            GlifiProbabilityDivergence.jensenShannonDivergence(pointA, pointB)
                - GlifiProbabilityDivergence.jensenShannonDivergence(pointB, pointA)
        ) < 1e-12
    )
    #expect(
        try abs(
            GlifiProbabilityDivergence.hellinger(pointA, pointB)
                - GlifiProbabilityDivergence.hellinger(pointB, pointA)
        ) < 1e-12
    )

    do {
        _ = try GlifiProbabilityDivergence.klDivergence([0.5, 0.6], uniform)
        Issue.record("La distribuzione non normalizzata non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "similarity.not-normalized")
    }
    do {
        _ = try GlifiProbabilityDivergence.hellinger([1, 0, 0], uniform)
        Issue.record("La dimensione disallineata non è stata rifiutata")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "similarity.dimension-mismatch")
    }
}

@Test("Jensen-Shannon conserva il segnale quadratico vicino a distribuzioni identiche")
func jensenShannonNearIdentityMatchesHighPrecision() throws {
    // Independent Decimal(120) evaluation of the defining log-ratio formula on the
    // exact binary64 inputs, without the implementation's delta transformation or series.
    let references: [(Double, Double, Double)] = [
        (1e-6, 7.2134752044676603902078015e-13, 8.4932180028936384238403436e-7),
        (1e-7, 7.2134752008554752118363581e-15, 8.4932180007671269074793027e-8),
        (1e-8, 7.2134752368939389538913915e-17, 8.4932180219831510892370232e-9),
        (1e-9, 7.2134751968511134913282227e-19, 8.4932179984097390948138442e-10),
        (1e-10, 7.2134763981360956371182477e-21, 8.4932187056121989617249406e-11),
    ]
    for (epsilon, divergence, distance) in references {
        let p = [0.5, 0.5]
        let q = [0.5 + epsilon, 0.5 - epsilon]
        let observedDivergence = try GlifiProbabilityDivergence.jensenShannonDivergence(p, q)
        let observedDistance = try GlifiProbabilityDivergence.jensenShannonDistance(p, q)
        #expect(abs(observedDivergence - divergence) <= divergence * 1e-12)
        #expect(abs(observedDistance - distance) <= distance * 1e-12)
        #expect(
            abs(try GlifiProbabilityDivergence.jensenShannonDistance(q, p) - distance)
                <= distance * 1e-12)
    }
}

@Test("Jensen-Shannon conserva distanze rappresentabili con contributi subnormali")
func jensenShannonSubnormalDistanceRemainsDefined() throws {
    let tiny = Double.leastNonzeroMagnitude
    // Two disjoint tails contribute tiny/2 each; accumulating each product first
    // would round both to zero although their sum and the distance are representable.
    let p = [1, tiny, 0]
    let q = [1, 0, tiny]
    let divergence = try GlifiProbabilityDivergence.jensenShannonDivergence(p, q)
    let distance = try GlifiProbabilityDivergence.jensenShannonDistance(p, q)
    #expect(divergence == tiny)
    #expect(abs(distance / tiny.squareRoot() - 1) <= 1e-12)
    let oneTail = try GlifiProbabilityDivergence.jensenShannonDistance([1, tiny], [1, 0])
    #expect(abs(oneTail / (tiny.squareRoot() / 2.0.squareRoot()) - 1) <= 1e-12)
}

@Test("Hellinger e Lidstone conservano contributi subnormali con risultati rappresentabili")
func probabilityTransformsPreserveRepresentableSubnormals() throws {
    let tiny = Double.leastNonzeroMagnitude
    let distance = try GlifiProbabilityDivergence.hellinger([1, tiny], [1, 2 * tiny])
    // The unit coordinate cancels; the remaining closed-form root difference is finite
    // even though its square is smaller than the least representable positive Double.
    let expected = ((2 * tiny).squareRoot() - tiny.squareRoot()) / 2.0.squareRoot()
    #expect(distance > 0)
    #expect(abs(distance / expected - 1) <= 1e-12)
    // (tiny + tiny)/(2 + 3*tiny) rounds to tiny. Scaling the two numerator
    // addends independently would underflow both halves before adding them.
    let smoothed = try GlifiProbabilityDivergence.lidstone([2, tiny], alpha: tiny)
    #expect(smoothed == [1, tiny])
}
