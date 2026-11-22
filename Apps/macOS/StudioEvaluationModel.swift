// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioEvaluationTool: String, CaseIterable, Identifiable, Sendable {
    case temporal, classification, lemmas, boundaries, namedEntities, morphology
    var id: Self { self }
    var titleKey: String { "evaluation.tool.\(rawValue).title" }
    var descriptionKey: String { "evaluation.tool.\(rawValue).description" }
}

nonisolated enum StudioTemporalPrecision: String, CaseIterable, Identifiable, Sendable {
    case missing, civilDate, civilMonth, civilYear, instant
    var id: Self { self }
    var titleKey: String { "evaluation.precision.\(rawValue)" }
}

nonisolated struct StudioTemporalAnnotationDraft: Equatable, Sendable {
    var precision: StudioTemporalPrecision = .missing
    var year = 2024
    var month = 1
    var day = 1
    var instant = ""
    var provenance = "manual.session-v1"
}

nonisolated struct StudioEvaluationFeature: Identifiable, Equatable, Sendable {
    var id = UUID()
    var attribute = ""
    var value = ""
}

nonisolated struct StudioEvaluationObservation: Identifiable, Equatable, Sendable {
    var id = UUID()
    var gold = ""
    var predicted = ""
    var form = ""
    var partOfSpeech = ""
    var goldFeatures: [StudioEvaluationFeature] = []
    var predictedFeatures: [StudioEvaluationFeature] = []
}

nonisolated struct StudioEvaluationEntityDraft: Identifiable, Equatable, Sendable {
    var id = UUID()
    var start = 0
    var end = 0
    var type = ""
}

nonisolated struct StudioEvaluationDocument: Identifiable, Equatable, Sendable {
    var id = UUID()
    var name = ""
    var text = ""
    var goldBoundaries = ""
    var predictedBoundaries = ""
    var goldEntities: [StudioEvaluationEntityDraft] = []
    var predictedEntities: [StudioEvaluationEntityDraft] = []
}

nonisolated struct StudioEvaluationInput: Equatable, Sendable {
    let tool: StudioEvaluationTool
    let zeroPolicy: GlifiStudioEvaluationZeroPolicy
    let observations: [StudioEvaluationObservation]
    let documents: [StudioEvaluationDocument]
    let includesForms: Bool
    let includesPartsOfSpeech: Bool
    let temporalAnnotations: [String: StudioTemporalAnnotationDraft]
    let selectedTerms: String
    let instantBasis: Bool
    let timeZoneIdentifier: String
    let granularity: GlifiStudioTemporalGranularity
    let originYear: Int
    let originMonth: Int
    let originDay: Int
    let bucketWidth: Int
    let bucketCount: Int
    let missingPolicy: GlifiStudioTemporalMissingPolicy
    let outsidePolicy: GlifiStudioTemporalOutsidePolicy
}

nonisolated struct StudioEvaluationRow: Identifiable, Sendable {
    let id: Int
    let values: [String]
}

nonisolated struct StudioEvaluationOutput: Sendable {
    let id: UUID
    let input: StudioEvaluationInput
    let linguistic: GlifiStudioLinguisticEvaluationResult?
    let temporal: GlifiStudioProjectTemporalEvaluation?
    let linguisticRows: [StudioEvaluationRow]
    let encodedLinguisticResult: Data?
    let sourceNumbers: [String: Int]

    var methodIdentifier: String {
        linguistic?.methodIdentifier ?? temporal?.result.methodIdentifier ?? ""
    }

    var columnKeys: [String] {
        if temporal != nil {
            return [
                "evaluation.column.kind", "evaluation.column.start", "evaluation.column.end",
                "evaluation.column.term", "evaluation.column.documents", "evaluation.column.tokens",
                "evaluation.column.frequency", "evaluation.column.df", "evaluation.column.rate",
            ]
        }
        return ["evaluation.column.group", "evaluation.column.metric", "evaluation.column.value"]
    }

    var temporalStride: Int { max(1, temporal?.selectedTerms.count ?? 0) }
    var rowCount: Int {
        guard let temporal else { return linguisticRows.count }
        return temporal.result.buckets.count * temporalStride
            + (temporal.result.missing == nil ? 0 : temporalStride)
    }
}

/// Session-only evaluation drafts and results; evaluation does not install an NLP backend.
@MainActor @Observable final class StudioEvaluationModel {
    var tool: StudioEvaluationTool = .temporal
    var zeroPolicy: GlifiStudioEvaluationZeroPolicy = .undefined
    var observations: [StudioEvaluationObservation] = []
    var documents: [StudioEvaluationDocument] = []
    var includesForms = false
    var includesPartsOfSpeech = false
    var temporalAnnotations: [String: StudioTemporalAnnotationDraft] = [:]
    var selectedTerms = ""
    var instantBasis = false
    var timeZoneIdentifier = "Europe/Rome"
    var granularity: GlifiStudioTemporalGranularity = .month
    var originYear = 2024
    var originMonth = 1
    var originDay = 1
    var bucketWidth = 1
    var bucketCount = 12
    var missingPolicy: GlifiStudioTemporalMissingPolicy = .separate
    var outsidePolicy: GlifiStudioTemporalOutsidePolicy = .exclude
    private(set) var output: StudioEvaluationOutput?
    private(set) var rows: [StudioEvaluationRow] = []
    private(set) var page = 0
    private var pageRequestID = UUID()
    private var lifecycleID = UUID()
    nonisolated static let pageSize = 50
    nonisolated static let maximumObservations = 2_000
    nonisolated static let maximumDocuments = 200
    var pageCount: Int { max(1, ((output?.rowCount ?? 0) + Self.pageSize - 1) / Self.pageSize) }
    var isDraftChanged: Bool {
        guard let output else { return false }
        return capture() != output.input
    }

    func reset() {
        lifecycleID = UUID()
        pageRequestID = UUID()
        output = nil
        rows = []
        page = 0
        observations = []
        documents = []
        temporalAnnotations = [:]
        selectedTerms = ""
    }

    func showPage(_ requested: Int, locale: Locale) async {
        guard requested >= 0, requested < pageCount, let output else { return }
        let request = UUID()
        pageRequestID = request
        let next = await Self.project(output, page: requested, locale: locale)
        guard !Task.isCancelled, pageRequestID == request, self.output?.id == output.id else {
            return
        }
        page = requested
        rows = next
    }

    func executeLinguistic(locale: Locale) async throws {
        let lifecycle = lifecycleID
        let input = capture()
        let next = try await Self.evaluate(input, locale: locale)
        let firstPage = await Self.project(next, page: 0, locale: locale)
        try Self.checkCancellation(isCurrent: lifecycleID == lifecycle)
        pageRequestID = UUID()
        output = next
        page = 0
        rows = firstPage
    }

    func executeTemporal(
        session: GlifiStudioProjectSession, sourceRevisionIDs: [String],
        sourceNumbers: [String: Int], locale: Locale
    ) async throws {
        let lifecycle = lifecycleID
        let input = capture()
        let next = try await Self.aggregate(
            input, session: session, ids: sourceRevisionIDs,
            sourceNumbers: sourceNumbers)
        let firstPage = await Self.project(next, page: 0, locale: locale)
        try Self.checkCancellation(isCurrent: lifecycleID == lifecycle)
        pageRequestID = UUID()
        output = next
        page = 0
        rows = firstPage
    }

    func loadSyntheticExample() {
        guard observations.isEmpty, documents.isEmpty else { return }
        observations = []
        documents = []
        switch tool {
        case .temporal:
            break
        case .classification:
            observations = zip(["N", "N", "V", "V", "V"], ["N", "V", "V", "N", "A"])
                .map { .init(gold: $0, predicted: $1) }
        case .lemmas:
            observations = [
                .init(gold: "cane", predicted: "cane", form: "cani", partOfSpeech: "N"),
                .init(gold: "andare", predicted: "vado", form: "vado", partOfSpeech: "V"),
            ]
            includesForms = true
            includesPartsOfSpeech = true
        case .boundaries:
            documents = [
                .init(
                    name: "example", text: "casa mare", goldBoundaries: "4",
                    predictedBoundaries: "4, 5")
            ]
        case .namedEntities:
            documents = [
                .init(
                    name: "example", text: "Roma è una città.",
                    goldEntities: [.init(start: 0, end: 4, type: "LOC")],
                    predictedEntities: [.init(start: 0, end: 4, type: "ORG")])
            ]
        case .morphology:
            observations = [
                .init(
                    goldFeatures: [.init(attribute: "Number", value: "Sing")],
                    predictedFeatures: [.init(attribute: "Number", value: "Plur")])
            ]
        }
    }

    private func capture() -> StudioEvaluationInput {
        .init(
            tool: tool, zeroPolicy: zeroPolicy, observations: observations,
            documents: documents, includesForms: includesForms,
            includesPartsOfSpeech: includesPartsOfSpeech,
            temporalAnnotations: temporalAnnotations, selectedTerms: selectedTerms,
            instantBasis: instantBasis, timeZoneIdentifier: timeZoneIdentifier,
            granularity: granularity, originYear: originYear,
            originMonth: originMonth, originDay: originDay,
            bucketWidth: bucketWidth, bucketCount: bucketCount,
            missingPolicy: missingPolicy, outsidePolicy: outsidePolicy)
    }

    @concurrent private static func evaluate(
        _ input: StudioEvaluationInput, locale: Locale
    ) async throws -> StudioEvaluationOutput {
        try checkCancellation()
        guard input.observations.count <= maximumObservations,
            input.documents.count <= maximumDocuments
        else { throw invalidInput() }
        let result: GlifiStudioLinguisticEvaluationResult
        switch input.tool {
        case .temporal:
            throw invalidInput()
        case .classification:
            result = try await GlifiStudioLinguisticEvaluation.classification(
                gold: input.observations.map(\.gold),
                predicted: input.observations.map(\.predicted),
                zeroPolicy: input.zeroPolicy)
        case .lemmas:
            result = try await GlifiStudioLinguisticEvaluation.lemmas(
                gold: input.observations.map(\.gold),
                predicted: input.observations.map(\.predicted),
                forms: input.includesForms ? input.observations.map(\.form) : nil,
                partsOfSpeech: input.includesPartsOfSpeech
                    ? input.observations.map(\.partOfSpeech) : nil,
                zeroPolicy: input.zeroPolicy)
        case .morphology:
            result = try await GlifiStudioLinguisticEvaluation.morphology(
                gold: input.observations.map { try featureMap($0.goldFeatures) },
                predicted: input.observations.map { try featureMap($0.predictedFeatures) },
                zeroPolicy: input.zeroPolicy)
        case .boundaries:
            result = try await GlifiStudioEvaluationWorkbench.boundaries(
                gold: try input.documents.map { try boundaries($0.goldBoundaries) },
                predicted: try input.documents.map { try boundaries($0.predictedBoundaries) },
                texts: input.documents.map(\.text), zeroPolicy: input.zeroPolicy)
        case .namedEntities:
            let gold = input.documents.map { $0.goldEntities.map { entity($0) } }
            let predicted = input.documents.map { $0.predictedEntities.map { entity($0) } }
            guard gold.reduce(0, { $0 + $1.count }) <= maximumObservations,
                predicted.reduce(0, { $0 + $1.count }) <= maximumObservations
            else { throw invalidInput() }
            result = try await GlifiStudioEvaluationWorkbench.namedEntities(
                gold: gold, predicted: predicted,
                texts: input.documents.map(\.text), zeroPolicy: input.zeroPolicy)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return .init(
            id: UUID(), input: input, linguistic: result, temporal: nil,
            linguisticRows: linguisticRows(result, tool: input.tool, locale: locale),
            encodedLinguisticResult: try encoder.encode(result), sourceNumbers: [:])
    }

    @concurrent private static func aggregate(
        _ input: StudioEvaluationInput, session: GlifiStudioProjectSession,
        ids: [String], sourceNumbers: [String: Int]
    ) async throws -> StudioEvaluationOutput {
        try checkCancellation()
        guard input.tool == .temporal else { throw invalidInput() }
        let origin = try GlifiStudioCivilDate(
            year: input.originYear, month: input.originMonth, day: input.originDay)
        let configuration = GlifiStudioTemporalConfiguration(
            basis: input.instantBasis
                ? .instants(timeZoneIdentifier: input.timeZoneIdentifier) : .civilDates,
            granularity: input.granularity, origin: origin,
            bucketWidth: input.bucketWidth, bucketCount: input.bucketCount,
            missingPolicy: input.missingPolicy, outsidePolicy: input.outsidePolicy)
        let terms = input.selectedTerms.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let assignments = try ids.map { id -> GlifiStudioTemporalAssignment in
            let draft = input.temporalAnnotations[id] ?? .init()
            return .init(
                sourceRevisionID: id, value: try temporalValue(draft), provenance: draft.provenance)
        }
        let result = try await GlifiStudioEvaluationWorkbench.temporal(
            session: session, assignments: assignments, terms: terms,
            configuration: configuration)
        return .init(
            id: UUID(), input: input, linguistic: nil, temporal: result,
            linguisticRows: [], encodedLinguisticResult: nil, sourceNumbers: sourceNumbers)
    }

    nonisolated private static func temporalValue(
        _ draft: StudioTemporalAnnotationDraft
    ) throws(GlifiStudioFailure) -> GlifiStudioTemporalValue {
        switch draft.precision {
        case .missing: return .missing
        case .civilDate:
            return .civilDate(try .init(year: draft.year, month: draft.month, day: draft.day))
        case .civilMonth: return .civilMonth(year: draft.year, month: draft.month)
        case .civilYear: return .civilYear(draft.year)
        case .instant:
            let value = draft.instant
            guard
                value.hasSuffix("Z")
                    || value.range(of: "[+-][0-9]{2}:[0-9]{2}$", options: .regularExpression) != nil
            else {
                throw invalidInput()
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return .instant(date) }
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: value) else { throw invalidInput() }
            return .instant(date)
        }
    }

    nonisolated private static func featureMap(
        _ features: [StudioEvaluationFeature]
    ) throws(GlifiStudioFailure) -> [String: String] {
        guard features.count <= 256, Set(features.map(\.attribute)).count == features.count else {
            throw invalidInput()
        }
        return Dictionary(uniqueKeysWithValues: features.map { ($0.attribute, $0.value) })
    }

    nonisolated private static func boundaries(_ text: String) throws(GlifiStudioFailure) -> [Int] {
        guard text.utf8.count <= 64 * 1_024 else { throw invalidInput() }
        let parts = text.split { $0.isWhitespace || $0 == "," }
        guard parts.count <= maximumObservations else { throw invalidInput() }
        return try parts.map { (value) throws(GlifiStudioFailure) -> Int in
            guard let number = Int(value) else { throw invalidInput() }
            return number
        }
    }

    nonisolated private static func entity(_ draft: StudioEvaluationEntityDraft)
        -> GlifiStudioEvaluationEntity
    {
        .init(lowerBound: draft.start, upperBound: draft.end, type: draft.type)
    }

    nonisolated private static func linguisticRows(
        _ value: GlifiStudioLinguisticEvaluationResult, tool: StudioEvaluationTool, locale: Locale
    ) -> [StudioEvaluationRow] {
        var rows: [StudioEvaluationRow] = []
        func append(_ group: String, _ metric: String, _ number: Double?) {
            rows.append(
                .init(
                    id: rows.count,
                    values: [
                        group, localized(metric, locale),
                        number.map { $0.formatted(.number.locale(locale)) }
                            ?? localized("evaluation.undefined", locale),
                    ]))
        }
        func count(_ group: String, _ metric: String, _ number: Int) {
            rows.append(
                .init(
                    id: rows.count,
                    values: [
                        group, localized(metric, locale), number.formatted(.number.locale(locale)),
                    ]))
        }
        func score(_ group: String, _ score: GlifiStudioEvaluationScore) {
            count(group, "evaluation.metric.tp", score.truePositiveCount)
            count(group, "evaluation.metric.fp", score.falsePositiveCount)
            count(group, "evaluation.metric.fn", score.falseNegativeCount)
            append(group, "evaluation.metric.precision", score.precision)
            append(group, "evaluation.metric.recall", score.recall)
            append(group, "evaluation.metric.f1", score.f1)
        }
        if let accuracy = value.accuracy {
            let group = localized("evaluation.overall", locale)
            count(group, "evaluation.metric.observations", accuracy.observationCount)
            count(group, "evaluation.metric.correct", accuracy.correctCount)
            append(group, "evaluation.metric.accuracy", accuracy.accuracy)
        }
        if let overall = value.score {
            let group: String
            switch tool {
            case .classification: group = "evaluation.micro"
            case .boundaries: group = "evaluation.boundaries"
            case .namedEntities: group = "evaluation.untyped-spans"
            case .temporal, .lemmas, .morphology: group = "evaluation.overall"
            }
            score(localized(group, locale), overall)
        }
        if let exact = value.exactUnitScore {
            score(
                localized(
                    tool == .namedEntities ? "evaluation.typed-spans" : "evaluation.exact-units",
                    locale), exact)
        }
        for item in value.perClass {
            count(item.label, "evaluation.metric.support", item.support)
            score(item.label, item.score)
        }
        for (key, average) in [
            ("evaluation.macro", value.macro), ("evaluation.weighted", value.weighted),
        ] {
            if let average {
                let group = localized(key, locale)
                append(group, "evaluation.metric.precision", average.precision)
                append(group, "evaluation.metric.recall", average.recall)
                append(group, "evaluation.metric.f1", average.f1)
            }
        }
        for (row, values) in value.confusionMatrix.enumerated() {
            for (column, number) in values.enumerated() {
                count(
                    "\(value.labels[row]) → \(value.labels[column])", "evaluation.metric.confusion",
                    number)
            }
        }
        for (key, groups) in [
            ("evaluation.by-form", value.errorsByForm),
            ("evaluation.by-pos", value.errorsByPartOfSpeech),
        ] {
            for item in groups {
                let group = "\(localized(key, locale)): \(item.label)"
                count(group, "evaluation.metric.observations", item.observationCount)
                count(group, "evaluation.metric.errors", item.errorCount)
            }
        }
        return rows
    }

    @concurrent private static func project(
        _ output: StudioEvaluationOutput, page: Int, locale: Locale
    ) async -> [StudioEvaluationRow] {
        let first = page * pageSize
        let last = min(output.rowCount, first + pageSize)
        guard first < last else { return [] }
        guard let temporal = output.temporal else {
            return Array(output.linguisticRows[first..<last])
        }
        var rows: [StudioEvaluationRow] = []
        let stride = output.temporalStride
        let bucketRows = temporal.result.buckets.count * stride
        let missingRows = temporal.result.missing == nil ? 0 : stride
        for index in first..<last {
            if Task.isCancelled { return [] }
            if index < bucketRows {
                let bucket = temporal.result.buckets[index / stride]
                rows.append(
                    temporalRow(
                        id: index, aggregate: bucket.aggregate, termIndex: index % stride,
                        kind: "evaluation.bucket", start: boundary(bucket.start),
                        end: boundary(bucket.end), locale: locale))
            } else if index < bucketRows + missingRows, let missing = temporal.result.missing {
                rows.append(
                    temporalRow(
                        id: index, aggregate: missing, termIndex: index - bucketRows,
                        kind: "evaluation.missing", start: "", end: "", locale: locale))
            }
        }
        return rows
    }

    nonisolated private static func temporalRow(
        id: Int, aggregate: GlifiStudioTemporalAggregate, termIndex: Int,
        kind: String, start: String, end: String, locale: Locale
    ) -> StudioEvaluationRow {
        let term = aggregate.terms.indices.contains(termIndex) ? aggregate.terms[termIndex] : nil
        let rate =
            term.map { term in
                term.perThousandTokenRate.map { $0.formatted(.number.locale(locale)) }
                    ?? localized("evaluation.undefined", locale)
            } ?? ""
        return .init(
            id: id,
            values: [
                localized(kind, locale), start, end, term?.term ?? "",
                aggregate.documentCount.formatted(.number.locale(locale)),
                aggregate.tokenCount.formatted(.number.locale(locale)),
                term.map { $0.frequency.formatted(.number.locale(locale)) } ?? "",
                term.map { $0.documentFrequency.formatted(.number.locale(locale)) } ?? "",
                rate,
            ])
    }

    nonisolated private static func boundary(_ value: GlifiStudioTemporalBoundary) -> String {
        switch value {
        case .civilDate(let date):
            return String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
        case .instant(let date):
            return date.ISO8601Format()
        }
    }

    nonisolated private static func localized(_ key: String, _ locale: Locale) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    nonisolated private static func invalidInput() -> GlifiStudioFailure {
        .init(
            code: "evaluation.invalid-client-input", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }

    nonisolated private static func checkCancellation(isCurrent: Bool = true)
        throws(GlifiStudioFailure)
    {
        guard !Task.isCancelled, isCurrent else {
            throw GlifiStudioFailure(
                code: "operation.cancelled", category: "cancelled", operation: "analyze",
                retryDisposition: "newRequest", retainedState: "unchanged",
                messageKey: "failure.category.cancelled")
        }
    }
}
