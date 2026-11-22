// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Synthetic bounded observations for before/after lexical allocation measurements.
func lexicalOptimizationMeasurements() throws -> [Measurement] {
    let vocabulary = (0..<20_000).map { "forma-\($0)" }
    var generator = GlifiSplitMix64(seed: 168)
    let documents = (0..<500).map { document in
        GlifiLexicalSequence(
            id: "synthetic-\(document)",
            tokens: (0..<1_000).map { offset in
                let position = document * 1_000 + offset
                let index =
                    position < vocabulary.count
                    ? position : generator.index(below: vocabulary.count)
                return vocabulary[index]
            })
    }
    let checkpoints = Array(stride(from: 1_000, through: 500_000, by: 1_000))
    var observationInput = LexicalInputChecksum()
    observationInput.append("synthetic-identity-v1")
    for document in documents {
        observationInput.append(document.id)
        observationInput.append(UInt64(document.tokens.count))
        for token in document.tokens { observationInput.append(token) }
    }
    for checkpoint in checkpoints { observationInput.append(UInt64(checkpoint)) }
    var distribution: GlifiLexicalDistribution?
    let observationTimes = try measure {
        distribution = try GlifiLexicalDistributionAnalysis.observe(
            documents, checkpoints: checkpoints,
            preprocessingIdentifier: "synthetic-identity-v1")
    }
    let rankChecksum = distribution?.rankFrequency.reduce(0.0) {
        $0 + Double($1.rank) * Double($1.count)
    }
    var measurements = [
        summary(
            "lexical-observe-500000-tokens-20000-types", "GS-MET-001-05",
            "SplitMix64 seed 168, 500 documents x 1000 tokens, seeded vocabulary prefix, 500 checkpoints; "
                + "inputFNV64=\(observationInput.canonicalValue)",
            observationTimes,
            check:
                "tokenCount=\(distribution?.tokenCount ?? 0); typeCount=\(distribution?.typeCount ?? 0); "
                + "growthCount=\(distribution?.growth.count ?? 0); rankChecksum=\(rankChecksum ?? 0)"
        )
    ]

    let growth = (1...100_000).map { index in
        let tokens = index * 8
        return GlifiVocabularyGrowthPoint(
            tokenCount: tokens, typeCount: Int(Double(tokens).squareRoot()))
    }
    var growthInput = LexicalInputChecksum()
    for point in growth {
        growthInput.append(UInt64(point.tokenCount))
        growthInput.append(UInt64(point.typeCount))
    }
    var heaps: GlifiLogPowerFit?
    let fitTimes = try measure {
        heaps = try GlifiLexicalDistributionAnalysis.fitHeaps(growth)
    }
    let fitChecksum = heaps?.points.reduce(0.0) { $0 + $1.predicted + $1.logResidual }
    measurements.append(
        summary(
            "lexical-heaps-log-ols-100000-points", "GS-MET-001-05",
            "N=8,16,...,800000; observed types=floor(sqrt(N)); no extrapolation; "
                + "inputFNV64=\(growthInput.canonicalValue)",
            fitTimes,
            check:
                "pointCount=\(heaps?.points.count ?? 0); typeCount=\(growth.last?.typeCount ?? 0); "
                + "coefficient=\(heaps?.coefficient ?? 0); exponent=\(heaps?.exponent ?? 0); "
                + "fitChecksum=\(fitChecksum ?? 0)"))

    let values: [Double?] = (0..<500_000).map { index in
        index.isMultiple(of: 17) ? nil : 1e12 + Double(index % 31) / 8
    }
    var descriptiveInput = LexicalInputChecksum()
    descriptiveInput.append("synthetic-observation-v1")
    descriptiveInput.append("sample")
    for value in values {
        descriptiveInput.append(value == nil ? 0 : 1)
        if let value { descriptiveInput.append(value.bitPattern) }
    }
    for probability in [0.0, 0.01, 0.25, 0.5, 0.75, 0.99, 1] {
        descriptiveInput.append(probability.bitPattern)
    }
    var description: GlifiDescriptiveSummary?
    let descriptiveTimes = try measure {
        description = try GlifiDescriptiveStatistics.summarize(
            values, unitIdentifier: "synthetic-observation-v1", variance: .sample,
            probabilities: [0, 0.01, 0.25, 0.5, 0.75, 0.99, 1])
    }
    let descriptiveChecksum = description?.quantiles.reduce(0.0) { $0 + ($1.value ?? 0) }
    measurements.append(
        summary(
            "descriptive-q7-500000-with-missing", "GS-MET-001-04",
            "31 repeated values at origin 1e12 with step 1/8; every 17th observation missing; "
                + "inputFNV64=\(descriptiveInput.canonicalValue)",
            descriptiveTimes,
            check:
                "validCount=\(description?.validCount ?? 0); missingCount=\(description?.missingCount ?? 0); "
                + "typeCount=31; mean=\(description?.mean ?? 0); variance=\(description?.variance ?? 0); "
                + "quantileChecksum=\(descriptiveChecksum ?? 0)"))
    return measurements
}

private struct LexicalInputChecksum {
    private var value: UInt64 = 14_695_981_039_346_656_037

    var canonicalValue: String { String(value, radix: 16) }

    mutating func append(_ integer: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            value = (value ^ ((integer >> shift) & 255)) &* 1_099_511_628_211
        }
    }

    mutating func append(_ text: String) {
        append(UInt64(text.utf8.count))
        for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
    }
}
