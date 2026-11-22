// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Measures sparse, dense and mostly-empty calendar aggregation; setup/checksums are untimed.
func temporalRefinementMeasurements() throws -> [Measurement] {
    try [
        temporalRefinementMeasurement(
            identifier: "temporal-refine-sparse-30000x2", documentCount: 30_000,
            termsPerDocument: 2, vocabularyCount: 1_024, bucketCount: 24,
            mostlyEmpty: false, seed: 181),
        temporalRefinementMeasurement(
            identifier: "temporal-refine-dense-6000x128", documentCount: 6_000,
            termsPerDocument: 128, vocabularyCount: 128, bucketCount: 24,
            mostlyEmpty: false, seed: 182),
        temporalRefinementMeasurement(
            identifier: "temporal-refine-empty-missing-20000", documentCount: 20_000,
            termsPerDocument: 0, vocabularyCount: 0, bucketCount: 240,
            mostlyEmpty: true, seed: 183),
    ]
}

private func temporalRefinementMeasurement(
    identifier: String, documentCount: Int, termsPerDocument: Int, vocabularyCount: Int,
    bucketCount: Int, mostlyEmpty: Bool, seed: UInt64
) throws -> Measurement {
    let configuration = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .month,
        origin: try GlifiCivilDate(year: 2000, month: 1, day: 1), bucketWidth: 1,
        bucketCount: bucketCount, missingPolicy: .separate, outsidePolicy: .exclude)
    let vocabulary = (0..<vocabularyCount).map { "refinement-term\($0)" }
    var documents: [GlifiTemporalDocument] = []
    documents.reserveCapacity(documentCount)
    for index in 0..<documentCount {
        let identity = UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                UInt8((index >> 24) & 255), UInt8((index >> 16) & 255),
                UInt8((index >> 8) & 255), UInt8(index & 255)
            ))
        let bucket =
            mostlyEmpty ? (index.isMultiple(of: 2) ? 0 : bucketCount - 1) : index % bucketCount
        let value: GlifiTemporalValue
        if mostlyEmpty ? !index.isMultiple(of: 5) : index.isMultiple(of: 37) {
            value = .missing
        } else if index.isMultiple(of: 101) {
            value = .civilMonth(year: 1999, month: 12)
        } else if index.isMultiple(of: 103) {
            value = .civilMonth(year: 2000 + bucketCount / 12 + 1, month: 1)
        } else {
            value = .civilMonth(year: 2000 + bucket / 12, month: bucket % 12 + 1)
        }
        var counts: [String: Int] = [:]
        counts.reserveCapacity(termsPerDocument)
        for offset in 0..<termsPerDocument {
            counts[vocabulary[(index * 13 + offset * 71) % vocabularyCount]] = (index + offset) % 6
        }
        documents.append(
            GlifiTemporalDocument(
                sourceRevisionID: SourceRevisionID(uuid: identity),
                metadataProvenance: "synthetic.temporal-refinement-v1.field\(index % 3)",
                value: value,
                tokenCount: mostlyEmpty ? index % 17 : max(1, termsPerDocument * 6),
                termCounts: counts))
    }
    var generator = GlifiSplitMix64(seed: seed)
    for index in stride(from: documents.count - 1, through: 1, by: -1) {
        documents.swapAt(index, generator.index(below: index + 1))
    }
    var input = TemporalRefinementChecksum()
    input.add(configuration)
    input.add(documents.count)
    for document in documents { input.add(document) }

    var result: GlifiTemporalResult?
    let times = try measure {
        result = try GlifiTemporalAnalysis.aggregate(documents, configuration: configuration)
    }
    var output = TemporalRefinementChecksum()
    if let result {
        output.add("result")
        output.add(result.configuration)
        output.add(result.buckets.count)
        for bucket in result.buckets {
            output.add(bucket.start)
            output.add(bucket.end)
            output.add(bucket.aggregate)
        }
        if let missing = result.missing {
            output.add("missing-present")
            output.add(missing)
        } else {
            output.add("missing-absent")
        }
        output.add(result.excluded.count)
        for exclusion in result.excluded {
            output.add(exclusion.lineage.sourceRevisionID.canonicalValue)
            output.add(exclusion.lineage.metadataProvenance)
            output.add(exclusion.reasonIdentifier)
        }
    } else {
        output.add("result-absent")
    }
    return summary(
        identifier, "GS-MET-001-17",
        "\(documentCount) sources; \(termsPerDocument) term cells/source; vocabulary\(vocabularyCount); \(bucketCount) months; zero counts/missing/outside; empty-heavy=\(mostlyEmpty); shuffle SplitMix64 seed\(seed); inputFNV=\(input.description)",
        times, check: output.description)
}

private struct TemporalRefinementChecksum {
    private var value: UInt64 = 14_695_981_039_346_656_037

    var description: String { String(value, radix: 16) }

    mutating func add(_ number: Int) { addBits(UInt64(bitPattern: Int64(number))) }

    mutating func addBits(_ bits: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            value = (value ^ ((bits >> shift) & 255)) &* 1_099_511_628_211
        }
    }

    mutating func add(_ text: String) {
        add(text.utf8.count)
        for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
    }

    mutating func add(_ date: GlifiCivilDate) {
        add(date.year)
        add(date.month)
        add(date.day)
    }

    mutating func add(_ configuration: GlifiTemporalConfiguration) {
        switch configuration.basis {
        case .civilDates: add("civilDates")
        case .instants(let identifier):
            add("instants")
            add(identifier)
        }
        add(configuration.granularity.rawValue)
        add(configuration.origin)
        add(configuration.bucketWidth)
        add(configuration.bucketCount)
        add(configuration.missingPolicy.rawValue)
        add(configuration.outsidePolicy.rawValue)
    }

    mutating func add(_ boundary: GlifiTemporalBoundary) {
        switch boundary {
        case .civilDate(let date):
            add("civilDate")
            add(date)
        case .instant(let date):
            add("instant")
            addBits(date.timeIntervalSinceReferenceDate.bitPattern)
        }
    }

    mutating func add(_ document: GlifiTemporalDocument) {
        add(document.sourceRevisionID.canonicalValue)
        add(document.metadataProvenance)
        add(document.tokenCount)
        add(document.termCounts.count)
        for term in document.termCounts.keys.sorted() {
            add(term)
            add(document.termCounts[term] ?? 0)
        }
        switch document.value {
        case .instant(let date):
            add("instant")
            addBits(date.timeIntervalSinceReferenceDate.bitPattern)
        case .civilDate(let date):
            add("civilDate")
            add(date)
        case .civilMonth(let year, let month):
            add("civilMonth")
            add(year)
            add(month)
        case .civilYear(let year):
            add("civilYear")
            add(year)
        case .interval(let start, let end):
            add("interval")
            addBits(start.timeIntervalSinceReferenceDate.bitPattern)
            addBits(end.timeIntervalSinceReferenceDate.bitPattern)
        case .uncertainPeriod(let lower, let upper):
            add("uncertainPeriod")
            add(lower)
            add(upper)
        case .missing:
            add("missing")
        }
    }

    mutating func add(_ aggregate: GlifiTemporalAggregate) {
        add(aggregate.documentCount)
        add(aggregate.tokenCount)
        add(aggregate.terms.count)
        for term in aggregate.terms {
            add(term.term)
            add(term.frequency)
            add(term.documentFrequency)
            if let rate = term.perThousandTokenRate {
                add("rate-present")
                addBits(rate.bitPattern)
            } else {
                add("rate-absent")
            }
            add(term.sourceRevisionIDs.count)
            for revision in term.sourceRevisionIDs { add(revision.canonicalValue) }
        }
        add(aggregate.lineage.count)
        for lineage in aggregate.lineage {
            add(lineage.sourceRevisionID.canonicalValue)
            add(lineage.metadataProvenance)
        }
    }
}
