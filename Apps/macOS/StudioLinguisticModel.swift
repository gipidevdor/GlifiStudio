// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

nonisolated enum StudioLinguisticTool: String, CaseIterable, Identifiable, Sendable {
    case availability, annotation, coding
    var id: Self { self }
    var titleKey: String { "linguistic.tool.\(rawValue).title" }
    var descriptionKey: String { "linguistic.tool.\(rawValue).description" }
}

nonisolated struct StudioLinguisticVariable: Identifiable, Equatable, Sendable {
    let id = UUID()
    var key = ""
    var value = ""
}

nonisolated struct StudioLinguisticUnit: Identifiable, Equatable, Sendable {
    let id = UUID()
    var identifier = ""
    var text = ""
    var variables: [StudioLinguisticVariable] = []
}

nonisolated struct StudioLinguisticOrigin: Equatable, Sendable {
    let projectID: String
    let generation: Int
    let sourceRevisionIDs: [String]
    let contentDigests: [String]
    let units: [StudioLinguisticUnit]
}

nonisolated struct StudioLinguisticInput: Equatable, Sendable {
    let tool: StudioLinguisticTool
    let languageTag: String
    let base: GlifiStudioLinguisticBase
    let includesPartOfSpeech: Bool
    let text: String
    let units: [StudioLinguisticUnit]
    let rules: String
    let origin: StudioLinguisticOrigin?

    var isModifiedProjectCopy: Bool {
        guard let origin else { return false }
        switch tool {
        case .availability: return false
        case .annotation: return origin.units.count != 1 || origin.units.first?.text != text
        case .coding: return origin.units != units
        }
    }
}

nonisolated enum StudioLinguisticCell: Sendable {
    case text(String)
    case integer(Int)
    case semantic(String)
}

nonisolated struct StudioLinguisticRow: Identifiable, Sendable {
    let id: Int
    let values: [StudioLinguisticCell]
}

nonisolated struct StudioLinguisticTable: Identifiable, Sendable {
    let id: String
    let columns: [String]
    let rows: [StudioLinguisticRow]
}

nonisolated enum StudioLinguisticPayload: Sendable {
    case availability(GlifiStudioLinguisticAvailability)
    case annotation(GlifiStudioLinguisticAnnotation)
    case coding(GlifiStudioAnnotatedCodingResult)

    var provenances: [GlifiStudioLinguisticProvenance] {
        switch self {
        case .availability: []
        case let .annotation(value): [value.provenance]
        case let .coding(value): value.provenanceByUnit
        }
    }
}

nonisolated struct StudioLinguisticOutput: Sendable {
    let id: UUID
    let input: StudioLinguisticInput
    let request: GlifiStudioTextAnalysisRequest
    let canonicalRequest: Data
    let encodedResult: Data
    let methodIdentifier: String
    let requestDigest: String
    let validationStatus: String
    let payload: StudioLinguisticPayload
    let tables: [StudioLinguisticTable]
}

/// Session-only native linguistic tools; computations and canonical transport remain in GlifiKit.
@MainActor @Observable final class StudioLinguisticModel {
    var tool: StudioLinguisticTool = .annotation
    var languageTag = "it"
    var base: GlifiStudioLinguisticBase = .normalizedSurface
    var includesPartOfSpeech = false
    var text = ""
    var units: [StudioLinguisticUnit] = []
    var rules = ""
    private(set) var origin: StudioLinguisticOrigin?
    private(set) var output: StudioLinguisticOutput?
    var selectedTable = 0 {
        didSet { page = 0 }
    }
    private(set) var page = 0
    private var lifecycleID = UUID()
    nonisolated static let pageSize = 50
    nonisolated static let maximumUnits = 200
    nonisolated static let maximumVariables = 256

    var selectedResultTable: StudioLinguisticTable? {
        guard let output, output.tables.indices.contains(selectedTable) else { return nil }
        return output.tables[selectedTable]
    }
    var pageCount: Int {
        max(1, ((selectedResultTable?.rows.count ?? 0) + Self.pageSize - 1) / Self.pageSize)
    }
    var visibleRows: [StudioLinguisticRow] {
        Array(
            (selectedResultTable?.rows ?? []).dropFirst(page * Self.pageSize).prefix(Self.pageSize))
    }
    var isDraftChanged: Bool { output.map { $0.input != capture() } ?? false }
    var isModifiedProjectCopy: Bool { capture().isModifiedProjectCopy }

    func reset() {
        lifecycleID = UUID()
        tool = .annotation
        languageTag = "it"
        base = .normalizedSurface
        includesPartOfSpeech = false
        text = ""
        units = []
        rules = ""
        origin = nil
        output = nil
        selectedTable = 0
        page = 0
    }

    func showPage(_ proposed: Int) {
        guard proposed >= 0, proposed < pageCount else { return }
        page = proposed
    }

    @discardableResult func addUnit() -> UUID? {
        guard units.count < Self.maximumUnits else { return nil }
        let used = Set(units.map(\.identifier))
        var ordinal = units.count + 1
        while used.contains("unit-\(ordinal)") { ordinal += 1 }
        let unit = StudioLinguisticUnit(identifier: "unit-\(ordinal)")
        units.append(unit)
        return unit.id
    }

    func loadSyntheticExample() {
        text = "Le biblioteche conservano città e parole. I ragazzi leggono libri."
        units = [
            .init(
                identifier: "biblioteca", text: "Cani e libri in biblioteca.",
                variables: [.init(key: "gruppo", value: "A")]),
            .init(
                identifier: "mare", text: "Il mare conserva le parole.",
                variables: [.init(key: "gruppo", value: "B")]),
        ]
        rules = "*Biblioteca\nbiblioteca\n*Mare\nmare"
        origin = nil
    }

    /// Copies explicitly selected extracted texts; subsequent edits are identified as a working copy.
    func loadProjectInput(session: GlifiStudioProjectSession, ids: [String])
        async throws(GlifiStudioFailure)
    {
        let nonce = UUID()
        lifecycleID = nonce
        let selectedTool = tool
        guard selectedTool != .availability,
            selectedTool != .annotation || ids.count == 1
        else { throw Self.invalidInput() }
        let input = try await GlifiStudioTextAnalytics.prepareProjectInput(
            session: session, sourceRevisionIDs: ids, maximumTermCount: 1, allowsEmptyLexicon: true)
        try validateLifecycle(nonce)
        guard tool == selectedTool else { throw Self.cancelled() }
        let copied = input.codingUnits.map { unit in
            StudioLinguisticUnit(
                identifier: unit.id, text: unit.text,
                variables: unit.variables.keys.sorted().map {
                    .init(key: $0, value: unit.variables[$0] ?? "")
                })
        }
        units = copied
        if selectedTool == .annotation { text = copied.first?.text ?? "" }
        origin = StudioLinguisticOrigin(
            projectID: input.projectID, generation: input.generation,
            sourceRevisionIDs: input.sourceRevisionIDs, contentDigests: input.contentDigests,
            units: copied)
    }

    func execute(locale: Locale) async throws(GlifiStudioFailure) {
        let nonce = UUID()
        lifecycleID = nonce
        let next = try await Self.calculate(capture())
        try validateLifecycle(nonce)
        output = next
        selectedTable = 0
        page = 0
    }

    private func capture() -> StudioLinguisticInput {
        StudioLinguisticInput(
            tool: tool, languageTag: languageTag, base: base,
            includesPartOfSpeech: includesPartOfSpeech, text: text, units: units, rules: rules,
            origin: origin)
    }

    private func validateLifecycle(_ nonce: UUID) throws(GlifiStudioFailure) {
        guard lifecycleID == nonce, !Task.isCancelled else { throw Self.cancelled() }
    }

    @concurrent private static func calculate(_ input: StudioLinguisticInput)
        async throws(GlifiStudioFailure) -> StudioLinguisticOutput
    {
        do {
            try Task.checkCancellation()
            let options = GlifiStudioLinguisticOptions(
                languageTag: input.languageTag, base: input.base,
                includePartOfSpeech: input.includesPartOfSpeech)
            let operation: GlifiStudioAdvancedTextAnalysisRequest
            switch input.tool {
            case .availability:
                operation = .linguisticAvailability(languageTag: input.languageTag)
            case .annotation:
                operation = .linguistic(text: input.text, options: options)
            case .coding:
                guard !input.units.isEmpty, input.units.count <= maximumUnits else {
                    throw invalidInput()
                }
                let units = try input.units.map { unit -> GlifiStudioAutomaticCodingUnit in
                    guard !unit.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        unit.variables.count <= maximumVariables
                    else { throw invalidInput() }
                    var variables: [String: String] = [:]
                    for variable in unit.variables {
                        guard !variable.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            variables.updateValue(variable.value, forKey: variable.key) == nil
                        else { throw invalidInput() }
                    }
                    return .init(id: unit.identifier, text: unit.text, variables: variables)
                }
                guard Set(units.map(\.id)).count == units.count else { throw invalidInput() }
                operation = .linguisticCoding(units: units, rules: input.rules, options: options)
            }
            let request = GlifiStudioTextAnalysisRequest.advanced(operation)
            let canonical = try request.canonicalData()
            let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(request)
            let payload = try linguisticPayload(result.payload)
            let tables = try project(payload)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let encoded = try encoder.encode(result)
            try Task.checkCancellation()
            return StudioLinguisticOutput(
                id: UUID(), input: input, request: request,
                canonicalRequest: canonical, encodedResult: encoded,
                methodIdentifier: result.methodIdentifier,
                requestDigest: result.requestDigest, validationStatus: result.validationStatus,
                payload: payload, tables: tables)
        } catch let failure as GlifiStudioFailure { throw failure } catch is CancellationError {
            throw cancelled()
        } catch { throw invalidInput() }
    }

    nonisolated private static func linguisticPayload(_ payload: GlifiStudioTextAnalysisPayload)
        throws(GlifiStudioFailure) -> StudioLinguisticPayload
    {
        switch payload {
        case let .advanced(value):
            switch value {
            case let .linguisticAvailability(value): .availability(value)
            case let .linguistic(value): .annotation(value)
            case let .linguisticCoding(value): .coding(value)
            case .ldaSelection, .communities, .graphLayout, .minimumSpanningForest, .mdsSearch,
                .somAdvanced:
                throw invalidInput()
            }
        case .mds, .som, .clara, .classify, .validateClassifier, .lda, .coding, .codeCrosstab,
            .dissimilarities, .correspondence, .hierarchical, .network:
            throw invalidInput()
        }
    }

    nonisolated private static func project(_ payload: StudioLinguisticPayload) throws
        -> [StudioLinguisticTable]
    {
        func rows(_ values: [[StudioLinguisticCell]]) -> [StudioLinguisticRow] {
            values.enumerated().map { .init(id: $0.offset, values: $0.element) }
        }
        switch payload {
        case let .availability(value):
            return [
                .init(
                    id: "availability", columns: ["capability", "available"],
                    rows: rows([
                        [
                            .semantic("linguistic.capability.lemma"),
                            .semantic("common.\(value.hasLemma ? "yes" : "no")"),
                        ],
                        [
                            .semantic("linguistic.capability.pos"),
                            .semantic("common.\(value.hasPartOfSpeech ? "yes" : "no")"),
                        ],
                        [
                            .semantic("linguistic.capability.stem"),
                            .semantic("common.\(value.hasItalianStemming ? "yes" : "no")"),
                        ],
                    ]))
            ]
        case let .annotation(value):
            let observations = try value.tokens.enumerated().map { index, token in
                try Task.checkCancellation()
                return StudioLinguisticRow(
                    id: index,
                    values: [
                        .integer(index + 1), .text(token.surface), .text(token.normalized),
                        token.lemma.map(StudioLinguisticCell.text)
                            ?? .semantic("linguistic.missing"),
                        token.stem.map(StudioLinguisticCell.text)
                            ?? .semantic("linguistic.missing"),
                        token.partOfSpeech.map(StudioLinguisticCell.text)
                            ?? .semantic("linguistic.missing"),
                        .semantic("linguistic.state.\(token.lemmaState.rawValue)"),
                        .semantic("linguistic.state.\(token.partOfSpeechState.rawValue)"),
                        .integer(token.startUTF8), .integer(token.endUTF8),
                        .integer(token.sentence), .integer(token.paragraph),
                    ])
            }
            return [
                .init(
                    id: "tokens",
                    columns: [
                        "index", "surface", "normalized", "lemma", "stem", "pos", "lemma-state",
                        "pos-state", "start", "end", "sentence", "paragraph",
                    ], rows: observations)
            ]
        case let .coding(value):
            let matrix = value.matrix
            guard matrix.values.count == matrix.documentIDs.count,
                matrix.evidence.count == matrix.documentIDs.count,
                value.provenanceByUnit.count == matrix.documentIDs.count
            else { throw invalidInput() }
            var cells: [StudioLinguisticRow] = []
            var evidence: [StudioLinguisticRow] = []
            for (unit, identifier) in matrix.documentIDs.enumerated() {
                try Task.checkCancellation()
                guard matrix.values.indices.contains(unit), matrix.evidence.indices.contains(unit),
                    matrix.values[unit].count == matrix.codes.count,
                    matrix.evidence[unit].count == matrix.codes.count
                else { throw invalidInput() }
                for (code, label) in matrix.codes.enumerated() {
                    cells.append(
                        .init(
                            id: cells.count,
                            values: [
                                .text(identifier), .text(label),
                                .integer(matrix.values[unit][code]),
                            ]))
                    for range in matrix.evidence[unit][code] {
                        evidence.append(
                            .init(
                                id: evidence.count,
                                values: [
                                    .text(identifier), .text(label), .integer(range.start),
                                    .integer(range.end),
                                ]))
                    }
                }
            }
            guard matrix.frequencies.count == matrix.codes.count else { throw invalidInput() }
            return [
                .init(id: "matrix", columns: ["unit", "code", "value"], rows: cells),
                .init(
                    id: "frequencies", columns: ["code", "frequency"],
                    rows: rows(
                        zip(matrix.codes, matrix.frequencies).map { [.text($0), .integer($1)] })),
                .init(id: "evidence", columns: ["unit", "code", "start", "end"], rows: evidence),
            ]
        }
    }

    nonisolated private static func invalidInput() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "linguistic-workbench.invalid-input", category: "invalidInput",
            operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }
    nonisolated private static func cancelled() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "operation.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled")
    }
}
