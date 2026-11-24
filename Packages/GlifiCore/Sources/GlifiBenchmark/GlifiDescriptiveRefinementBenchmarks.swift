// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Bounded descriptive workloads with complete bitwise input/output fingerprints.
func descriptiveRefinementMeasurements() throws -> [Measurement] {
    let probabilities = [0.0, 0.01, 0.25, 0.5, 0.75, 0.99, 1]
    var measurements: [Measurement] = []
    do {
        let values: [Double?] = (0..<500_000).map { index in
            index.isMultiple(of: 17) ? nil : 1e12 + Double(index % 31) / 8
        }
        measurements.append(
            try descriptiveRefinementMeasurement(
                "descriptive-refinement-repeated-500000",
                "31 repeated values at origin 1e12 with step 1/8; every 17th observation missing",
                values: values, probabilities: probabilities))
    }
    do {
        var generator = GlifiSplitMix64(seed: 170)
        let values: [Double?] = (0..<500_000).map { _ in
            Double(generator.next() >> 11) / Double(1 << 53) * 1e6 - 5e5
        }
        measurements.append(
            try descriptiveRefinementMeasurement(
                "descriptive-refinement-continuous-500000",
                "SplitMix64 seed 170; 500000 finite continuous draws in [-500000,500000)",
                values: values, probabilities: probabilities))
    }
    do {
        let prefixCount = 499_744
        var values: [Double?] = (0..<500_000).map { index in
            if index < prefixCount {
                return 1 + Double(index * 256 / prefixCount) / 8
            }
            return 33 + Double(index - prefixCount) / 8
        }
        // One adjacent inversion at the center; the 257th distinct value appears
        // only after almost the entire input has been visited.
        values.swapAt(prefixCount / 2 - 1, prefixCount / 2)
        measurements.append(
            try descriptiveRefinementMeasurement(
                "descriptive-refinement-late-cardinality-fallback-500000",
                "499744 observations in 256 ascending nonzero blocks, then 256 new values; "
                    + "one adjacent inversion at the midpoint; 257th type appears at position499745",
                values: values, probabilities: probabilities))
    }
    do {
        let sparse: [Double?] = (0..<500_000).map { index in
            index.isMultiple(of: 1_024) ? Double(index % 31) / 8 : nil
        }
        let empty = [Double?](repeating: nil, count: 500_000)
        var input = DescriptiveRefinementChecksum()
        input.appendInput(sparse, probabilities: probabilities)
        input.appendInput(empty, probabilities: probabilities)
        var sparseResult: GlifiDescriptiveSummary?
        var emptyResult: GlifiDescriptiveSummary?
        let times = try measure {
            sparseResult = try GlifiDescriptiveStatistics.summarize(
                sparse, unitIdentifier: "synthetic-observation-v1", variance: .sample,
                probabilities: probabilities)
            emptyResult = try GlifiDescriptiveStatistics.summarize(
                empty, unitIdentifier: "synthetic-observation-v1", variance: .sample,
                probabilities: probabilities)
        }
        var output = DescriptiveRefinementChecksum()
        if let sparseResult { output.append(sparseResult) }
        if let emptyResult { output.append(emptyResult) }
        measurements.append(
            summary(
                "descriptive-refinement-sparse-and-empty-500000", "GS-MET-001-04",
                "two requests: every 1024th observation finite, then all 500000 missing; "
                    + "inputFNV64=\(input.canonicalValue)", times,
                check:
                    "sparseValidCount=\(sparseResult?.validCount ?? 0); "
                    + "emptyValidCount=\(emptyResult?.validCount ?? 0); "
                    + "outputFNV64=\(output.canonicalValue)"))
    }
    return measurements
}

private func descriptiveRefinementMeasurement(
    _ identifier: String, _ generator: String,
    values: [Double?], probabilities: [Double]
) throws -> Measurement {
    var input = DescriptiveRefinementChecksum()
    input.appendInput(values, probabilities: probabilities)
    var result: GlifiDescriptiveSummary?
    let times = try measure {
        result = try GlifiDescriptiveStatistics.summarize(
            values, unitIdentifier: "synthetic-observation-v1", variance: .sample,
            probabilities: probabilities)
    }
    var output = DescriptiveRefinementChecksum()
    if let result { output.append(result) }
    return summary(
        identifier, "GS-MET-001-04", generator + "; inputFNV64=\(input.canonicalValue)", times,
        check:
            "validCount=\(result?.validCount ?? 0); missingCount=\(result?.missingCount ?? 0); "
            + "outputFNV64=\(output.canonicalValue)")
}

private struct DescriptiveRefinementChecksum {
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

    mutating func append(_ optional: Double?) {
        append(UInt64(optional == nil ? 0 : 1))
        if let optional { append(optional.bitPattern) }
    }

    mutating func appendInput(_ values: [Double?], probabilities: [Double]) {
        append("synthetic-observation-v1")
        append(GlifiVarianceConvention.sample.rawValue)
        append(UInt64(values.count))
        for value in values { append(value) }
        append(UInt64(probabilities.count))
        for probability in probabilities { append(probability.bitPattern) }
    }

    mutating func append(_ summary: GlifiDescriptiveSummary) {
        append(summary.methodIdentifier)
        append(summary.unitIdentifier)
        append(summary.missingPolicyIdentifier)
        append(summary.varianceConvention.rawValue)
        append(UInt64(summary.validCount))
        append(UInt64(summary.missingCount))
        append(summary.minimum)
        append(summary.maximum)
        append(summary.mean)
        append(summary.median)
        append(summary.variance)
        append(summary.standardDeviation)
        append(UInt64(summary.quantiles.count))
        for quantile in summary.quantiles {
            append(quantile.probability.bitPattern)
            append(quantile.value)
        }
    }
}
