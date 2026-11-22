// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiEvaluationCommandTests {
    @Test(arguments: GlifiStudioEvaluationOperation.allCases)
    func everyCommandMatchesTheNativeOperation(operation: GlifiStudioEvaluationOperation)
        async throws
    {
        let labels = EvaluationLabels(
            gold: ["N", "N", "V", "V", "V"], predicted: ["N", "V", "V", "N", "A"],
            zeroPolicy: .zero)
        let boundaries = EvaluationBoundaries(
            gold: [[2, 5]], predicted: [[2, 6]], utf8Lengths: [8], zeroPolicy: .zero)
        let goldEntities: [[GlifiStudioEvaluationEntity]] = [
            [.init(lowerBound: 0, upperBound: 2, type: "PER")]
        ]
        let predictedEntities: [[GlifiStudioEvaluationEntity]] = [
            [.init(lowerBound: 0, upperBound: 2, type: "ORG")]
        ]
        let lexical = EvaluationLexical(
            documents: [
                .init(id: "second", tokens: ["a", "a", "a", "b"]),
                .init(id: "first-empty", tokens: []),
            ],
            checkpoints: [1, 4], preprocessingIdentifier: "synthetic.keys-preserved-v2")
        switch operation {
        case .classification:
            try await verify(
                operation, parameters: labels,
                result: GlifiStudioLinguisticEvaluation.classification(
                    gold: labels.gold, predicted: labels.predicted, zeroPolicy: .zero))
        case .lemmas:
            let value = EvaluationLemmas(
                gold: ["cane", "andare"], predicted: ["cane", "andato"],
                forms: ["cani", "andavano"], partsOfSpeech: ["N", "V"], zeroPolicy: .zero)
            try await verify(
                operation, parameters: value,
                result: GlifiStudioLinguisticEvaluation.lemmas(
                    gold: value.gold, predicted: value.predicted, forms: value.forms,
                    partsOfSpeech: value.partsOfSpeech, zeroPolicy: .zero))
        case .boundaries:
            try await verify(
                operation, parameters: boundaries,
                result: GlifiStudioLinguisticEvaluation.boundaries(
                    gold: boundaries.gold, predicted: boundaries.predicted,
                    utf8Lengths: boundaries.utf8Lengths, zeroPolicy: .zero))
        case .namedEntities:
            let value = EvaluationEntities(
                gold: goldEntities, predicted: predictedEntities, utf8Lengths: [8],
                zeroPolicy: .zero)
            try await verify(
                operation, parameters: value,
                result: GlifiStudioLinguisticEvaluation.namedEntities(
                    gold: value.gold, predicted: value.predicted,
                    utf8Lengths: value.utf8Lengths, zeroPolicy: .zero))
        case .morphology:
            let value = EvaluationMorphology(
                gold: [["Number": "Sing", "Gender": "Fem"]],
                predicted: [["Number": "Plur", "Gender": "Fem"]], zeroPolicy: .zero)
            try await verify(
                operation, parameters: value,
                result: GlifiStudioLinguisticEvaluation.morphology(
                    gold: value.gold, predicted: value.predicted, zeroPolicy: .zero))
        case .boundariesWithText:
            let value = EvaluationTextBoundaries(
                gold: boundaries.gold, predicted: boundaries.predicted,
                texts: ["è uno.."], zeroPolicy: .zero)
            try await verify(
                operation, parameters: value,
                result: GlifiStudioEvaluationWorkbench.boundaries(
                    gold: value.gold, predicted: value.predicted, texts: value.texts,
                    zeroPolicy: .zero))
        case .namedEntitiesWithText:
            let value = EvaluationTextEntities(
                gold: goldEntities, predicted: predictedEntities,
                texts: ["è uno.."], zeroPolicy: .zero)
            try await verify(
                operation, parameters: value,
                result: GlifiStudioEvaluationWorkbench.namedEntities(
                    gold: value.gold, predicted: value.predicted, texts: value.texts,
                    zeroPolicy: .zero))
        case .temporal:
            let configuration = GlifiStudioTemporalConfiguration(
                basis: .civilDates, granularity: .month,
                origin: try GlifiStudioCivilDate(year: 2024, month: 1, day: 1),
                bucketWidth: 1, bucketCount: 3, missingPolicy: .separate,
                outsidePolicy: .exclude)
            let documents = [
                GlifiStudioTemporalDocument(
                    sourceRevisionID: "source-revision:00000000-0000-0000-0000-000000000002",
                    metadataProvenance: "synthetic.month-v2",
                    value: .civilMonth(year: 2024, month: 2), tokenCount: 10,
                    termCounts: ["casa": 2]),
                GlifiStudioTemporalDocument(
                    sourceRevisionID: "source-revision:00000000-0000-0000-0000-000000000001",
                    metadataProvenance: "synthetic.missing-v2", value: .missing,
                    tokenCount: 0, termCounts: [:]),
            ]
            try await verify(
                operation,
                parameters: EvaluationTemporal(documents: documents, configuration: configuration),
                result: GlifiStudioTextAnalytics.temporalFrequencies(
                    documents, configuration: configuration))
        case .lexicalObserve:
            try await verify(operation, parameters: lexical, result: lexical.observe())
        case .lexicalZipf:
            let observed = try await lexical.observe()
            try await verify(
                operation,
                parameters: EvaluationZipf(observations: lexical, firstRank: 1, lastRank: 2),
                result: GlifiStudioLexicalStatistics.fitZipf(observed, ranks: 1...2))
        case .lexicalHeaps:
            let observed = try await lexical.observe()
            try await verify(
                operation, parameters: lexical,
                result: GlifiStudioLexicalStatistics.fitHeaps(observed))
        case .lexicalSummary:
            let value = EvaluationSummary(
                observations: [1, nil, 3, 6], unitIdentifier: "synthetic.tokens-v2",
                variance: .sample, probabilities: [0.1, 0.9])
            try await verify(
                operation, parameters: value,
                result: GlifiStudioLexicalStatistics.summarize(
                    value.observations, unitIdentifier: value.unitIdentifier,
                    variance: value.variance, probabilities: value.probabilities))
        case .welchANOVA:
            let value = EvaluationWelch(groups: [[3, 4, 5], [6, 7, 9], [1, 2, 2, 4]])
            try await verify(
                operation, parameters: value,
                result: GlifiStudioTextAnalytics.welchOneWayANOVA(value.groups))
        }
    }

    @Test func preservesTemporalTypesAndValidatesCivilDatesWhileDecoding() throws {
        let origin = try GlifiStudioCivilDate(year: 2024, month: 2, day: 29)
        let instant = Date(timeIntervalSinceReferenceDate: 123_456.125)
        let values: [GlifiStudioTemporalValue] = [
            .instant(instant), .civilDate(origin), .civilMonth(year: 2024, month: 2),
            .civilYear(2024), .interval(start: instant, end: instant.addingTimeInterval(1)),
            .uncertainPeriod(lower: origin, upper: origin), .missing,
        ]
        for value in values {
            #expect(
                try JSONDecoder().decode(
                    GlifiStudioTemporalValue.self, from: JSONEncoder().encode(value)) == value)
        }
        #expect(throws: GlifiStudioFailure.self) {
            try JSONDecoder().decode(
                GlifiStudioCivilDate.self, from: Data(#"{"year":2023,"month":2,"day":29}"#.utf8))
        }
    }

    @Test func rejectsUnknownFieldsVersionsDuplicateKeysAndInvalidNativeInput() async throws {
        let request = EvaluationCommandEnvelope(
            schema: GlifiStudioEvaluationCommand.schema, schemaVersion: 1,
            operation: .classification,
            parameters: EvaluationLabels(gold: ["N"], predicted: [], zeroPolicy: .zero))
        let bytes = try CommandJSON.encode(request)
        do {
            _ = try await GlifiStudioEvaluationCommand.execute(json: bytes)
            Issue.record("An unaligned native evaluation was accepted")
        } catch {
            #expect(error.code == "evaluation.alignment-mismatch")
        }
        let text = try #require(String(data: bytes, encoding: .utf8))
        for invalid in [
            text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2"),
            text.replacingOccurrences(
                of: "\"gold\":[\"N\"]", with: "\"gold\":[\"N\"],\"unknown\":1"),
            text.replacingOccurrences(of: "\"gold\":[\"N\"]", with: "\"gold\":[\"N\"],\"gold\":[]"),
        ] {
            await #expect(throws: GlifiStudioFailure.self) {
                try await GlifiStudioEvaluationCommand.execute(json: Data(invalid.utf8))
            }
        }
        let entities = EvaluationCommandEnvelope(
            schema: GlifiStudioEvaluationCommand.schema, schemaVersion: 1,
            operation: .namedEntities,
            parameters: EvaluationEntities(
                gold: [[.init(lowerBound: 0, upperBound: 1, type: "X")]], predicted: [[]],
                utf8Lengths: [1], zeroPolicy: .zero))
        let entityText = try #require(
            String(data: CommandJSON.encode(entities), encoding: .utf8))
        await #expect(throws: GlifiStudioFailure.self) {
            try await GlifiStudioEvaluationCommand.execute(
                json: Data(
                    entityText.replacingOccurrences(
                        of: "\"lowerBound\":0", with: "\"lowerBound\":0,\"unknown\":true"
                    ).utf8))
        }
    }

    @Test func cancellationPrecedesDecodingOrComputation() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioEvaluationCommand.execute(json: Data())
        }
        do {
            _ = try await task.value
            Issue.record("Cancellation was ignored")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        } catch { Issue.record("Unexpected failure: \(error)") }
    }

    private func verify<Parameters: Codable, Result: Encodable>(
        _ operation: GlifiStudioEvaluationOperation, parameters: Parameters, result: Result
    ) async throws {
        let request = EvaluationCommandEnvelope(
            schema: GlifiStudioEvaluationCommand.schema, schemaVersion: 1,
            operation: operation, parameters: parameters)
        let bytes = try CommandJSON.encode(request)
        let observed = try await GlifiStudioEvaluationCommand.execute(json: bytes)
        #expect(observed.json == (try CommandJSON.encode(result)))
        try exportKitCLIParityFixture(
            command: "evaluation", operation: String(describing: operation),
            request: request, result: result)
    }
}
