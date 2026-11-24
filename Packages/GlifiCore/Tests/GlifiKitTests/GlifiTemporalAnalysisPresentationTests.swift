// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("La facciata temporale conserva conteggi, precisione e revisione contribuente")
func temporalFacadePreservesObservedCounts() async throws {
    let configuration = GlifiStudioTemporalConfiguration(
        basis: .civilDates, granularity: .month,
        origin: try GlifiStudioCivilDate(year: 2024, month: 1, day: 1),
        bucketWidth: 1, bucketCount: 3, missingPolicy: .separate, outsidePolicy: .exclude)
    let revision = "source-revision:00000000-0000-0000-0000-000000000001"
    let document = GlifiStudioTemporalDocument(
        sourceRevisionID: revision, metadataProvenance: "synthetic.month-v1",
        value: .civilMonth(year: 2024, month: 2), tokenCount: 10, termCounts: ["casa": 2])
    let result = try await GlifiStudioTextAnalytics.temporalFrequencies(
        [document], configuration: configuration)
    #expect(result.methodIdentifier == "Temporal-calendar-token-rates-v1")
    #expect(result.configuration == configuration)
    #expect(result.buckets.map(\.aggregate.documentCount) == [0, 1, 0])
    #expect(result.buckets[1].aggregate.terms[0].frequency == 2)
    #expect(result.buckets[1].aggregate.terms[0].perThousandTokenRate == 200)
    #expect(result.buckets[1].aggregate.lineage[0].sourceRevisionID == revision)
    #expect(result.buckets[1].aggregate.lineage[0].metadataProvenance == "synthetic.month-v1")
}

@Test("La facciata temporale propaga la tassonomia per date non valide e revisioni non valide")
func temporalFacadeMapsFailures() async throws {
    #expect(throws: GlifiStudioFailure.self) {
        try GlifiStudioCivilDate(year: 2023, month: 2, day: 29)
    }
    let configuration = GlifiStudioTemporalConfiguration(
        basis: .civilDates, granularity: .year,
        origin: try GlifiStudioCivilDate(year: 2024, month: 1, day: 1),
        bucketWidth: 1, bucketCount: 1, missingPolicy: .reject, outsidePolicy: .reject)
    do {
        _ = try await GlifiStudioTextAnalytics.temporalFrequencies(
            [
                GlifiStudioTemporalDocument(
                    sourceRevisionID: "invalid", metadataProvenance: "synthetic.year-v1",
                    value: .civilYear(2024), tokenCount: 1, termCounts: ["casa": 1])
            ],
            configuration: configuration)
        Issue.record("Invalid source identity was accepted")
    } catch let failure {
        #expect(failure.category == "invalidInput")
    }
}

@Test("La facciata temporale conserva la cancellazione nella tassonomia pubblica")
func temporalFacadeCancellation() async throws {
    let configuration = GlifiStudioTemporalConfiguration(
        basis: .civilDates, granularity: .year,
        origin: try GlifiStudioCivilDate(year: 2024, month: 1, day: 1),
        bucketWidth: 1, bucketCount: 1, missingPolicy: .exclude, outsidePolicy: .reject)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await GlifiStudioTextAnalytics.temporalFrequencies(
            [], configuration: configuration)
    }
    do {
        _ = try await task.value
        Issue.record("Cancellation was ignored")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.category == "cancelled")
        #expect(failure.code == "operation.cancelled")
    }
}
