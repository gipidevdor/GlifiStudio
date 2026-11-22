// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private func closeDistribution(_ actual: Double, _ expected: Double) -> Bool {
    abs(actual - expected) <= 1e-12 * max(1, abs(expected))
}

@Test("Distribuzione lessicale: spectrum, tie stabili e crescita rispettano conteggi e ordine")
func lexicalDistributionObservations() throws {
    let documents: [GlifiLexicalSequence] = [
        .init(id: "b", tokens: ["è", "a", "è"]),
        .init(id: "empty", tokens: []),
        .init(id: "a", tokens: ["b", "a", "c"]),
    ]
    let result = try GlifiLexicalDistributionAnalysis.observe(
        documents, checkpoints: [1, 3, 4, 6], preprocessingIdentifier: "explicit-keys-v1")
    #expect(result.documentIDs == ["b", "empty", "a"])
    #expect(result.documentTokenCounts == [3, 0, 3])
    #expect(result.rankFrequency.map(\.term) == ["a", "è", "b", "c"])
    #expect(result.rankFrequency.map(\.rank) == [1, 2, 3, 4])
    #expect(result.rankFrequency.map(\.count) == [2, 2, 1, 1])
    #expect(result.spectrum.map(\.frequency) == [1, 2])
    #expect(result.spectrum.map(\.typeCount) == [2, 2])
    #expect(result.spectrum.reduce(0) { $0 + $1.typeCount } == result.typeCount)
    #expect(result.spectrum.reduce(0) { $0 + $1.typeCount * $1.frequency } == result.tokenCount)
    #expect(result.growth.map(\.typeCount) == [1, 2, 3, 4])
    #expect(closeDistribution(result.rankFrequency.map(\.relativeFrequency).reduce(0, +), 1))
    let reordered = try GlifiLexicalDistributionAnalysis.observe(
        documents.reversed(), checkpoints: [1, 3, 4, 6], preprocessingIdentifier: "explicit-keys-v1"
    )
    #expect(reordered.rankFrequency == result.rankFrequency)
    #expect(reordered.spectrum == result.spectrum)
    #expect(reordered.growth != result.growth)
    #expect(
        try JSONDecoder().decode(
            GlifiLexicalDistribution.self, from: JSONEncoder().encode(result)) == result)
}

@Test("ZipfLogOLS-v1 e HeapsLogOLS-v1 coincidono con stats::lm indipendente")
func lexicalPowerFitsMatchR() throws {
    // Tests/Oracles/R/lexical_distributions.R, ZIPF and HEAPS.
    let tokens = zip(["a", "b", "c", "d", "e"], [20, 9, 6, 4, 3]).flatMap {
        Array(repeating: $0.0, count: $0.1)
    }
    let distribution = try GlifiLexicalDistributionAnalysis.observe(
        [.init(id: "doc", tokens: tokens)], checkpoints: [], preprocessingIdentifier: "keys-v1")
    let zipf = try GlifiLexicalDistributionAnalysis.fitZipf(distribution, ranks: 1...5)
    #expect(zipf.methodIdentifier == "ZipfLogOLS-v1")
    #expect(zipf.diagnosticOnly)
    #expect(closeDistribution(zipf.coefficient, 20.319882051385))
    #expect(closeDistribution(zipf.exponent, 1.16728684267648))
    #expect(closeDistribution(try #require(zipf.logRSquared), 0.997543525586883))
    #expect(closeDistribution(zipf.logRMSE, 0.032925682370414))
    let residuals = [
        -0.0158675445816196, -0.00527365689346665, 0.0625553208574271,
        -0.0071022892038708, -0.0343118301784701,
    ]
    for (point, expected) in zip(zipf.points, residuals) {
        #expect(closeDistribution(point.logResidual, expected))
        #expect(closeDistribution(log(Double(point.observed) / point.predicted), expected))
    }
    let heaps = try GlifiLexicalDistributionAnalysis.fitHeaps(
        zip([1, 4, 9, 16], [1, 2, 3, 4]).map { .init(tokenCount: $0.0, typeCount: $0.1) })
    #expect(heaps.methodIdentifier == "HeapsLogOLS-v1")
    #expect(closeDistribution(heaps.coefficient, 1))
    #expect(closeDistribution(heaps.exponent, 0.5))
    #expect(closeDistribution(try #require(heaps.logRSquared), 1))
    #expect(heaps.logRMSE < 1e-12)
    for prefixes in [[2, 4, 8], [10, 20, 30]] {
        let proportional = try GlifiLexicalDistributionAnalysis.fitHeaps(
            prefixes.map { .init(tokenCount: $0, typeCount: $0 / 2) })
        #expect(proportional.exponent == 1)
        #expect(closeDistribution(proportional.coefficient, 0.5))
    }
    let subset = try GlifiLexicalDistributionAnalysis.fitZipf(distribution, ranks: 2...4)
    #expect(subset.points.map(\.x) == [2, 3, 4])
    #expect(subset.coefficient != zipf.coefficient)
}

@Test("Distribuzioni e fit rifiutano input ambigui, impossibili e modelli fuori dominio")
func lexicalDistributionValidation() throws {
    let empty = try GlifiLexicalDistributionAnalysis.observe(
        [], checkpoints: [], preprocessingIdentifier: "keys-v1")
    #expect(empty.tokenCount == 0 && empty.typeCount == 0 && empty.spectrum.isEmpty)
    for checkpoints in [[0], [2, 1], [1, 1], [3]] {
        #expect(throws: GlifiFailure.self) {
            try GlifiLexicalDistributionAnalysis.observe(
                [.init(id: "doc", tokens: ["a", "a"])],
                checkpoints: checkpoints, preprocessingIdentifier: "keys-v1")
        }
    }
    for documents: [GlifiLexicalSequence] in [
        [.init(id: "", tokens: [])],
        [.init(id: "d", tokens: []), .init(id: "d", tokens: [])],
        [.init(id: "d", tokens: [""])],
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiLexicalDistributionAnalysis.observe(
                documents, checkpoints: [], preprocessingIdentifier: "keys-v1")
        }
    }
    let flat = try GlifiLexicalDistributionAnalysis.observe(
        [.init(id: "d", tokens: ["a", "b"])], checkpoints: [], preprocessingIdentifier: "keys-v1")
    #expect(throws: GlifiFailure.self) {
        try GlifiLexicalDistributionAnalysis.fitZipf(flat, ranks: 1...2)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiLexicalDistributionAnalysis.fitZipf(flat, ranks: 1...1)
    }
    for points: [GlifiVocabularyGrowthPoint] in [
        [], [.init(tokenCount: 1, typeCount: 1)],
        [.init(tokenCount: 1, typeCount: 1), .init(tokenCount: 2, typeCount: 1)],
        [.init(tokenCount: 1, typeCount: 2), .init(tokenCount: 2, typeCount: 2)],
        [.init(tokenCount: 5, typeCount: 1), .init(tokenCount: 6, typeCount: 4)],
    ] {
        #expect(throws: GlifiFailure.self) { try GlifiLexicalDistributionAnalysis.fitHeaps(points) }
    }
}

@Test("Statistiche descrittive: missing espliciti, Q7 e varianza campionaria contro R")
func descriptiveStatisticsMatchR() throws {
    // Tests/Oracles/R/lexical_distributions.R, DESCRIPTIVE.
    let summary = try GlifiDescriptiveStatistics.summarize(
        [1, nil, 2, 4, 8, nil, 10], unitIdentifier: "grapheme-count-v1", variance: .sample,
        probabilities: [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1])
    #expect(summary.validCount == 5 && summary.missingCount == 2)
    #expect(summary.mean == 5 && summary.median == 4)
    #expect(closeDistribution(try #require(summary.variance), 15))
    #expect(closeDistribution(try #require(summary.standardDeviation), 3.87298334620742))
    for (quantile, expected) in zip(summary.quantiles, [1.0, 1.4, 2, 4, 8, 9.2, 10]) {
        #expect(closeDistribution(try #require(quantile.value), expected))
    }
    let population = try GlifiDescriptiveStatistics.summarize(
        [1, 2, 4, 8, 10], unitIdentifier: "grapheme-count-v1", variance: .population)
    #expect(closeDistribution(try #require(population.variance), 12))
    #expect(
        try JSONDecoder().decode(
            GlifiDescriptiveSummary.self, from: JSONEncoder().encode(summary)) == summary)
}

@Test("Statistiche descrittive: vuoto, singleton, input non finiti e overflow espliciti")
func descriptiveStatisticsDegenerateInputs() throws {
    let empty = try GlifiDescriptiveStatistics.summarize(
        [nil], unitIdentifier: "tokens-v1", variance: .sample)
    #expect(empty.validCount == 0 && empty.missingCount == 1)
    #expect(empty.mean == nil && empty.median == nil && empty.variance == nil)
    let single = try GlifiDescriptiveStatistics.summarize(
        [3], unitIdentifier: "tokens-v1", variance: .sample)
    #expect(single.mean == 3 && single.median == 3 && single.variance == nil)
    let large = try GlifiDescriptiveStatistics.summarize(
        [1e200, 1e200], unitIdentifier: "finite-v1", variance: .population)
    #expect(large.mean == 1e200 && large.variance == 0)
    for values: [Double?] in [
        [.nan], [.infinity], [-1e200, 1e200], [-1e-200, 1e-200], [0, .leastNonzeroMagnitude],
    ] {
        #expect(throws: GlifiFailure.self) {
            try GlifiDescriptiveStatistics.summarize(
                values, unitIdentifier: "finite-v1", variance: .sample)
        }
    }
    for probability in [-0.1, 1.1, .nan] {
        #expect(throws: GlifiFailure.self) {
            try GlifiDescriptiveStatistics.summarize(
                [1], unitIdentifier: "tokens-v1", variance: .population,
                probabilities: [probability])
        }
    }
}

@Test("La varianza descrittiva conserva lo spread piccolo su un offset grande")
func descriptiveVariancePreservesOffsetInvariance() throws {
    for offset in [0.0, 1e12, 1e15, -1e15] {
        let summary = try GlifiDescriptiveStatistics.summarize(
            [offset, offset + 1], unitIdentifier: "finite-v1", variance: .population)
        #expect(summary.variance == 0.25)
        #expect(summary.standardDeviation == 0.5)
        #expect(summary.mean == offset + 0.5)
    }
}

@Test("La normalizzazione descrittiva in-place conserva Q7 originali e fixture bitwise")
func descriptiveInPlacePreservesOriginalQuantiles() throws {
    let wide = try GlifiDescriptiveStatistics.summarize(
        [-1e16, 1], unitIdentifier: "finite-v1", variance: .sample,
        probabilities: [1, 0, 0.75, 0.5])
    #expect(wide.minimum == -1e16 && wide.maximum == 1)
    #expect(wide.median == -5e15)
    #expect(wide.quantiles.map(\.value) == [1, -1e16, -2_499_999_999_999_999, -5e15])
    // A round trip through (value-origin)+origin would turn the observed maximum 1 into 0.
    let fixture = try GlifiDescriptiveStatistics.summarize(
        [1, nil, 2, 4, 8, nil, 10], unitIdentifier: "grapheme-count-v1", variance: .sample,
        probabilities: [0, 0.1, 0.25, 0.5, 0.75, 0.9, 1])
    let expectedMean = 5.0
    let expectedVariance = 15.000000000000002
    let expectedDeviation = 3.872983346207417
    let expectedQuantiles = [1.0, 1.4, 2, 4, 8, 9.2, 10]
    #expect(fixture.validCount == 5 && fixture.missingCount == 2)
    #expect(fixture.mean?.bitPattern == expectedMean.bitPattern)
    #expect(fixture.variance?.bitPattern == expectedVariance.bitPattern)
    #expect(fixture.standardDeviation?.bitPattern == expectedDeviation.bitPattern)
    #expect(
        fixture.quantiles.map { $0.value?.bitPattern }
            == expectedQuantiles.map { Optional($0.bitPattern) })
}

@Test("L'ordinamento descrittivo bounded coincide bitwise con sort anche ai fallback")
func descriptiveBoundedSortMatchesNativeBitwise() throws {
    let tiny = Double.leastNonzeroMagnitude
    let fixtures: [[Double]] = [
        [], [1], [1, 1, 1], [0.0, -0.0, 0.0, -0.0], [1, -0.0, 0.0, -1],
        [tiny, -tiny, 2 * tiny, -2 * tiny, .leastNormalMagnitude, -.leastNormalMagnitude],
        [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, 1, -1],
    ]
    for fixture in fixtures {
        var observed = fixture
        try GlifiDescriptiveStatistics.sortFiniteValues(&observed)
        #expect(observed.map(\.bitPattern) == fixture.sorted().map(\.bitPattern))
    }
    for seed in 0..<8 {
        for typeCount in [1, 2, 31, 255, 256, 257, 512] {
            var generator = GlifiSplitMix64(seed: UInt64(seed))
            var values = (1...typeCount).reversed().map(Double.init)
            values += (values.count..<4_096).map { _ in
                Double(generator.index(below: typeCount) + 1)
            }
            let expected = values.sorted().map(\.bitPattern)
            try GlifiDescriptiveStatistics.sortFiniteValues(&values)
            #expect(values.map(\.bitPattern) == expected)
        }
    }
    // A new type after a long low-cardinality candidate must fall back on the
    // unmodified buffer, including a signed-zero tie introduced in the tail.
    var late = (0..<8_192).map { Double($0 % 256 + 1) }
    late += [257, -0.0, 0.0]
    let expectedLate = late.sorted().map(\.bitPattern)
    try GlifiDescriptiveStatistics.sortFiniteValues(&late)
    #expect(late.map(\.bitPattern) == expectedLate)
    // An inversion beyond the probe never authorizes the counted candidate.
    var nearlySorted = (0..<7_936).map { 1 + Double($0 * 256 / 7_936) / 8 }
    nearlySorted.swapAt(3_967, 3_968)
    nearlySorted += (0..<256).map { 33 + Double($0) / 8 }
    let expectedNearlySorted = nearlySorted.sorted().map(\.bitPattern)
    try GlifiDescriptiveStatistics.sortFiniteValues(&nearlySorted)
    #expect(nearlySorted.map(\.bitPattern) == expectedNearlySorted)
}

@Test("L'ordinamento descrittivo bounded conserva la cancellazione")
func descriptiveBoundedSortObservesCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        var values = [2.0, 1]
        try GlifiDescriptiveStatistics.sortFiniteValues(&values)
        return values
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

@Test("Conteggi lessicali e descrittive rispettano la cancellazione")
func lexicalStatisticsCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiLexicalDistributionAnalysis.observe(
            [.init(id: "d", tokens: ["a"])], checkpoints: [1], preprocessingIdentifier: "keys-v1")
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
