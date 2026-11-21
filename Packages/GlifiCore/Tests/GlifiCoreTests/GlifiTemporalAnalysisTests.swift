// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private func civil(_ year: Int, _ month: Int, _ day: Int) throws -> GlifiCivilDate {
    try GlifiCivilDate(year: year, month: month, day: day)
}

private func temporalDocument(
    _ index: Int, _ value: GlifiTemporalValue, count: Int, exposure: Int
) throws -> GlifiTemporalDocument {
    GlifiTemporalDocument(
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(
                UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)))),
        metadataProvenance: "synthetic.date-field-v1", value: value,
        tokenCount: exposure, termCounts: ["casa": count])
}

private func temporalInstant(_ value: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: value))
}

@Test("La serie civile conserva il giorno bisestile, i bordi, i denominatori e il lineage")
func temporalCivilLeapDayCountsAndLineage() throws {
    let configuration = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .day, origin: try civil(2024, 2, 28),
        bucketWidth: 1, bucketCount: 2, missingPolicy: .separate, outsidePolicy: .exclude)
    let documents = try [
        temporalDocument(1, .civilDate(civil(2024, 2, 28)), count: 2, exposure: 10),
        temporalDocument(2, .civilDate(civil(2024, 2, 29)), count: 3, exposure: 5),
        temporalDocument(3, .civilDate(civil(2024, 2, 29)), count: 1, exposure: 10),
        temporalDocument(4, .civilDate(civil(2024, 3, 1)), count: 7, exposure: 7),
        temporalDocument(5, .missing, count: 4, exposure: 8),
        temporalDocument(6, .civilDate(civil(2024, 2, 27)), count: 1, exposure: 1),
    ]
    let result = try GlifiTemporalAnalysis.aggregate(documents, configuration: configuration)
    #expect(
        result
            == (try GlifiTemporalAnalysis.aggregate(
                Array(documents.reversed()), configuration: configuration)))
    #expect(result.buckets.map(\.aggregate.tokenCount) == [10, 15])
    #expect(result.buckets.map(\.aggregate.documentCount) == [1, 2])
    #expect(result.buckets[0].aggregate.terms[0].frequency == 2)
    #expect(result.buckets[0].aggregate.terms[0].perThousandTokenRate == 200)
    let second = result.buckets[1]
    #expect(second.start == .civilDate(try civil(2024, 2, 29)))
    #expect(second.end == .civilDate(try civil(2024, 3, 1)))
    #expect(second.aggregate.terms[0].frequency == 4)
    #expect(second.aggregate.terms[0].documentFrequency == 2)
    #expect(abs(try #require(second.aggregate.terms[0].perThousandTokenRate) - 800.0 / 3) < 1e-12)
    #expect(second.aggregate.terms[0].sourceRevisionIDs == documents[1...2].map(\.sourceRevisionID))
    #expect(
        second.aggregate.lineage.allSatisfy { $0.metadataProvenance == "synthetic.date-field-v1" })
    #expect(result.missing?.tokenCount == 8)
    #expect(result.missing?.terms[0].perThousandTokenRate == 500)
    #expect(
        result.excluded.map(\.reasonIdentifier) == [
            "temporal.after-domain", "temporal.before-domain",
        ])
}

@Test("L'accumulo temporale conserva termini nulli e lineage sparso nell'ordine canonico")
func temporalSparseTermsPreserveCanonicalCounts() throws {
    func document(
        _ index: Int, _ value: GlifiTemporalValue, _ exposure: Int, _ counts: [String: Int]
    ) throws -> GlifiTemporalDocument {
        let identity = try temporalDocument(index, value, count: 0, exposure: exposure)
            .sourceRevisionID
        return GlifiTemporalDocument(
            sourceRevisionID: identity, metadataProvenance: "synthetic.sparse-v1",
            value: value, tokenCount: exposure, termCounts: counts)
    }
    let documents = try [
        document(3, .civilYear(2024), 10, ["beta": 2, "alpha": 0]),
        document(1, .civilYear(2024), 5, ["alpha": 1, "beta": 3]),
        document(2, .missing, 4, ["gamma": 4]),
        document(4, .civilYear(2025), 1, ["omega": 1]),
    ]
    let configuration = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .year,
        origin: try civil(2024, 1, 1), bucketWidth: 1, bucketCount: 1,
        missingPolicy: .separate, outsidePolicy: .exclude)
    let result = try GlifiTemporalAnalysis.aggregate(documents, configuration: configuration)
    let aggregate = result.buckets[0].aggregate
    #expect(aggregate.terms.map(\.term) == ["alpha", "beta", "gamma", "omega"])
    #expect(aggregate.terms.map(\.frequency) == [1, 5, 0, 0])
    #expect(aggregate.terms.map(\.documentFrequency) == [1, 2, 0, 0])
    #expect(aggregate.terms[0].sourceRevisionIDs == [documents[1].sourceRevisionID])
    #expect(
        aggregate.terms[1].sourceRevisionIDs == [
            documents[1].sourceRevisionID, documents[0].sourceRevisionID,
        ])
    #expect(
        aggregate.lineage.map(\.sourceRevisionID) == [
            documents[1].sourceRevisionID, documents[0].sourceRevisionID,
        ])
    #expect(aggregate.tokenCount == 15)
    #expect(result.missing?.terms.map(\.frequency) == [0, 0, 4, 0])
    #expect(result.excluded.map(\.lineage.sourceRevisionID) == [documents[3].sourceRevisionID])
    #expect(
        result
            == (try GlifiTemporalAnalysis.aggregate(
                Array(documents.reversed()), configuration: configuration)))
}

@Test("I bucket istante seguono le giornate di calendario anche con 23 o 25 ore")
func temporalInstantBucketsRespectDaylightSaving() throws {
    for (year, month, day, expectedHours, lower, upper) in [
        (2024, 3, 31, 23.0, "2024-03-30T23:00:00Z", "2024-03-31T22:00:00Z"),
        (2024, 10, 27, 25.0, "2024-10-26T22:00:00Z", "2024-10-27T23:00:00Z"),
    ] {
        let start = try temporalInstant(lower)
        let end = try temporalInstant(upper)
        let configuration = GlifiTemporalConfiguration(
            basis: .instants(timeZoneIdentifier: "Europe/Rome"), granularity: .day,
            origin: try civil(year, month, day), bucketWidth: 1, bucketCount: 1,
            missingPolicy: .exclude, outsidePolicy: .exclude)
        let documents = try [
            temporalDocument(1, .instant(start), count: 1, exposure: 2),
            temporalDocument(2, .instant(end.addingTimeInterval(-1)), count: 1, exposure: 3),
            temporalDocument(3, .instant(end), count: 1, exposure: 1),
        ]
        let result = try GlifiTemporalAnalysis.aggregate(documents, configuration: configuration)
        #expect(result.buckets[0].start == .instant(start))
        #expect(result.buckets[0].end == .instant(end))
        #expect(end.timeIntervalSince(start) == expectedHours * 3600)
        #expect(result.buckets[0].aggregate.documentCount == 2)
        #expect(result.buckets[0].aggregate.tokenCount == 5)
        #expect(result.excluded.count == 1)
        #expect(result.excluded[0].reasonIdentifier == "temporal.after-domain")
    }
}

@Test("La partizione indicizzata conserva mancanti, esclusioni e bucket vuoti su input riordinato")
func temporalIndexedPartitionsPreserveMissingAndExclusions() throws {
    func document(
        _ index: Int, _ value: GlifiTemporalValue, _ exposure: Int, _ counts: [String: Int]
    ) throws -> GlifiTemporalDocument {
        let identity = try temporalDocument(index, value, count: 0, exposure: exposure)
            .sourceRevisionID
        return GlifiTemporalDocument(
            sourceRevisionID: identity, metadataProvenance: "synthetic.indexed-v1.\(index)",
            value: value, tokenCount: exposure, termCounts: counts)
    }
    let documents = try [
        document(50, .civilMonth(year: 2024, month: 3), 6, ["b": 5]),
        document(5, .missing, 3, ["b": 2, "only-missing": 1]),
        document(90, .missing, 0, ["zero": 0]),
        document(20, .civilMonth(year: 2024, month: 1), 2, ["a": 1]),
        document(12, .civilMonth(year: 2023, month: 12), 4, ["a": 4]),
        document(2, .civilMonth(year: 2024, month: 4), 1, ["outside": 1]),
    ]
    for policy in [GlifiTemporalMissingPolicy.exclude, .separate] {
        let configuration = GlifiTemporalConfiguration(
            basis: .civilDates, granularity: .month,
            origin: try civil(2024, 1, 1), bucketWidth: 1, bucketCount: 3,
            missingPolicy: policy, outsidePolicy: .exclude)
        let result = try GlifiTemporalAnalysis.aggregate(documents, configuration: configuration)
        #expect(
            result
                == (try GlifiTemporalAnalysis.aggregate(
                    Array(documents.reversed()), configuration: configuration)))
        #expect(result.buckets.map(\.aggregate.documentCount) == [1, 0, 1])
        #expect(result.buckets.map(\.aggregate.tokenCount) == [2, 0, 6])
        #expect(
            result.buckets[0].aggregate.lineage.map(\.sourceRevisionID) == [
                documents[3].sourceRevisionID
            ])
        #expect(
            result.buckets[2].aggregate.lineage.map(\.sourceRevisionID) == [
                documents[0].sourceRevisionID
            ])
        #expect(
            result.buckets[1].aggregate.terms.allSatisfy {
                $0.frequency == 0 && $0.perThousandTokenRate == nil
            })
        if policy == .separate {
            #expect(result.missing?.documentCount == 2)
            #expect(result.missing?.tokenCount == 3)
            #expect(result.missing?.terms.map(\.frequency) == [0, 2, 1, 0, 0])
            #expect(
                result.missing?.lineage.map(\.sourceRevisionID) == [
                    documents[1].sourceRevisionID, documents[2].sourceRevisionID,
                ])
            #expect(
                result.excluded.map(\.lineage.sourceRevisionID) == [
                    documents[5].sourceRevisionID, documents[4].sourceRevisionID,
                ])
        } else {
            #expect(result.missing == nil)
            #expect(
                result.excluded.map(\.lineage.sourceRevisionID) == [
                    documents[5].sourceRevisionID, documents[1].sourceRevisionID,
                    documents[4].sourceRevisionID, documents[2].sourceRevisionID,
                ])
        }
        do {
            let invalid = try document(15, .civilMonth(year: 2023, month: 12), 1, ["a": -1])
            _ = try GlifiTemporalAnalysis.aggregate([invalid], configuration: configuration)
            Issue.record("Expected validation before outside-domain exclusion")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "temporal.invalid-count")
        }
    }
}

@Test("La precisione del metadato non viene affinata implicitamente")
func temporalPrecisionIsNotInvented() throws {
    let yearly = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .year, origin: try civil(2023, 1, 1),
        bucketWidth: 2, bucketCount: 2, missingPolicy: .exclude, outsidePolicy: .reject)
    let documents = try [
        temporalDocument(1, .civilYear(2024), count: 1, exposure: 1),
        temporalDocument(2, .civilMonth(year: 2025, month: 8), count: 1, exposure: 1),
    ]
    let result = try GlifiTemporalAnalysis.aggregate(documents, configuration: yearly)
    #expect(result.buckets.map(\.aggregate.documentCount) == [1, 1])
    #expect(result.buckets[1].end == .civilDate(try civil(2027, 1, 1)))
    let monthly = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .month, origin: try civil(2024, 1, 1),
        bucketWidth: 1, bucketCount: 3, missingPolicy: .exclude, outsidePolicy: .exclude)
    #expect(throws: GlifiFailure.self) {
        try GlifiTemporalAnalysis.aggregate([documents[0]], configuration: monthly)
    }
    let month = try temporalDocument(3, .civilMonth(year: 2024, month: 2), count: 2, exposure: 10)
    let series = try GlifiTemporalAnalysis.aggregate([month], configuration: monthly)
    #expect(series.buckets.map(\.aggregate.documentCount) == [0, 1, 0])
    #expect(series.buckets[0].aggregate.terms[0].perThousandTokenRate == nil)
    #expect(series.buckets[1].aggregate.terms[0].perThousandTokenRate == 200)
    #expect(series.buckets[2].end == .civilDate(try civil(2024, 4, 1)))
}

@Test("Le policy di mancanti, dominio e tipo temporale sono fail-closed")
func temporalPoliciesAreExplicit() throws {
    for policy in [GlifiTemporalMissingPolicy.exclude, .separate, .reject] {
        let configuration = GlifiTemporalConfiguration(
            basis: .civilDates, granularity: .day, origin: try civil(2024, 1, 1),
            bucketWidth: 1, bucketCount: 1, missingPolicy: policy, outsidePolicy: .reject)
        let missing = try temporalDocument(1, .missing, count: 0, exposure: 0)
        if policy == .reject {
            #expect(throws: GlifiFailure.self) {
                try GlifiTemporalAnalysis.aggregate([missing], configuration: configuration)
            }
        } else {
            let result = try GlifiTemporalAnalysis.aggregate(
                [missing], configuration: configuration)
            #expect(result.missing?.documentCount == (policy == .separate ? 1 : nil))
            #expect(result.excluded.count == (policy == .exclude ? 1 : 0))
        }
        for value in [
            GlifiTemporalValue.civilDate(try civil(2024, 1, 2)),
            .instant(Date(timeIntervalSince1970: 0)),
            .interval(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1)),
            .uncertainPeriod(lower: try civil(2024, 1, 1), upper: try civil(2024, 1, 2)),
        ] {
            #expect(throws: GlifiFailure.self) {
                try GlifiTemporalAnalysis.aggregate(
                    [temporalDocument(2, value, count: 0, exposure: 0)],
                    configuration: configuration)
            }
        }
    }
}

@Test("Il calendario gregoriano rifiuta date normalizzate e confini locali inesistenti")
func temporalCalendarValidation() throws {
    #expect(throws: GlifiFailure.self) { try civil(1900, 2, 29) }
    #expect(try civil(2000, 2, 29) < civil(2000, 3, 1))
    for (year, month, day) in [(0, 1, 1), (10000, 1, 1), (2024, 13, 1), (2024, 2, 30)] {
        #expect(throws: GlifiFailure.self) { try civil(year, month, day) }
    }
    for zone in ["invalid/time-zone", "Pacific/Apia"] {
        let configuration = GlifiTemporalConfiguration(
            basis: .instants(timeZoneIdentifier: zone), granularity: .day,
            origin: try civil(2011, 12, 30), bucketWidth: 1, bucketCount: 1,
            missingPolicy: .exclude, outsidePolicy: .exclude)
        #expect(throws: GlifiFailure.self) {
            try GlifiTemporalAnalysis.aggregate([], configuration: configuration)
        }
    }
}

@Test("La serie temporale rifiuta revisioni duplicate, esposizione incoerente e overflow")
func temporalCountsRejectInvalidInputs() throws {
    let configuration = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .year, origin: try civil(2024, 1, 1),
        bucketWidth: 1, bucketCount: 1, missingPolicy: .exclude, outsidePolicy: .reject)
    let document = try temporalDocument(1, .civilYear(2024), count: 1, exposure: 1)
    #expect(throws: GlifiFailure.self) {
        try GlifiTemporalAnalysis.aggregate([document, document], configuration: configuration)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTemporalAnalysis.aggregate(
            [temporalDocument(2, .civilYear(2024), count: 2, exposure: 1)],
            configuration: configuration)
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiTemporalAnalysis.aggregate(
            [
                temporalDocument(2, .civilYear(2024), count: Int.max, exposure: Int.max),
                temporalDocument(3, .civilYear(2024), count: 1, exposure: 1),
            ], configuration: configuration)
    }
    let zero = try temporalDocument(2, .civilYear(2024), count: 0, exposure: 0)
    let result = try GlifiTemporalAnalysis.aggregate([zero], configuration: configuration)
    #expect(result.buckets[0].aggregate.terms[0].perThousandTokenRate == nil)
}

@Test("L'aggregazione temporale osserva la cancellazione prima di produrre la serie")
func temporalCancellationPropagates() async throws {
    let configuration = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .year, origin: try civil(2024, 1, 1),
        bucketWidth: 1, bucketCount: 1, missingPolicy: .exclude, outsidePolicy: .reject)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiTemporalAnalysis.aggregate([], configuration: configuration)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
