// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Observation

/// Shared off-actor transport for native workbench snapshots; it never evaluates an algorithm.
nonisolated enum StudioWorkbenchArchiveCodec {
    @concurrent static func encode<Value: Encodable & Sendable>(_ value: Value) async throws -> Data
    {
        try Task.checkCancellation()
        let bytes = try canonicalData(value)
        guard bytes.count <= 8 * 1_048_576 else { throw failure() }
        try Task.checkCancellation()
        return bytes
    }

    static func canonicalData<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func validate<Request: Encodable, Result: Encodable>(
        saved: GlifiStudioSavedAnalysis, command: String, request: Request, result: Result,
        method: String
    ) throws {
        let captured = try GlifiStudioWorkbenchCapture(saved: saved)
        guard captured.command == command, captured.methodIdentifier == method,
            try sameJSON(canonicalData(request), captured.requestJSON),
            try sameJSON(canonicalData(result), captured.resultJSON)
        else { throw failure() }
    }

    static func sameJSON(_ first: Data, _ second: Data) throws -> Bool {
        guard first.count <= 8 * 1_048_576, second.count <= 8 * 1_048_576 else { throw failure() }
        return try JSONSerialization.jsonObject(with: first) as? NSDictionary
            == JSONSerialization.jsonObject(with: second) as? NSDictionary
    }

    static func failure() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "research.invalid-native-archive", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }
}

nonisolated struct StudioResearchSavedValue: Identifiable, Sendable {
    let id: String
    let value: String
}

/// Drafts and captured results for the project's native research-data workspace.
@MainActor @Observable final class StudioResearchModel {
    var state = GlifiStudioResearchState()
    var selectedSourceID = ""
    var selectedSourceIDs: Set<String> = []
    var selectedSubsetID = ""
    var subsetLabel = ""
    var filterFieldID = ""
    var filterValue = ""
    var filterQuery = ""
    var stopwords = ""
    var includedTerms = ""
    var excludedTerms = ""
    var compounds = ""
    var includedPartsOfSpeech = ""
    var values: [String: [String: String]] = [:]
    var hasLoaded = false
    var table: GlifiStudioTabularTable?
    var mappedDataset: GlifiStudioTabularMappedDataset?
    var inputData: Data?
    var filename = ""
    var format: GlifiStudioTabularFormat = .csv
    var encoding: GlifiStudioTabularEncoding = .utf8
    var delimiter: GlifiStudioTabularDelimiter = .comma
    var hasHeaderRow = true
    var sheetName = ""
    var textColumns: Set<Int> = []
    var identifierColumn = 0
    var variableColumns: Set<Int> = []
    var variableNames: [Int: String] = [:]
    var variableTypes: [Int: GlifiStudioTabularValueType] = [:]
    var missingValues = ""
    var duplicatePolicy: GlifiStudioTabularDuplicatePolicy = .reject
    var invalidRowPolicy: GlifiStudioTabularInvalidRowPolicy = .reject
    var savedAnalyses: [GlifiStudioSavedAnalysis] = []
    var selectedSavedID: String?
    var savedTitle = ""
    var derivedClusterCount = 2
    var derivedFieldID = "classification"
    var derivedFieldLabel = ""
    var reportQuestion = ""
    var savedPreview = ""
    var savedValues: [StudioResearchSavedValue] = []
    var savedValuesAreTruncated = false
    var savedClient = "advanced"
    var exportedData: Data?
    private var previewSignature = ""
    private var lifecycle = UUID()

    var optionsSignature: String {
        "\(format.rawValue)|\(encoding.rawValue)|\(delimiter.rawValue)|\(hasHeaderRow)|\(sheetName)"
    }

    var isPreviewCurrent: Bool { table != nil && previewSignature == optionsSignature }

    var importOptions: GlifiStudioTabularOptions {
        GlifiStudioTabularOptions(
            format: format, encoding: encoding, delimiter: delimiter,
            hasHeaderRow: hasHeaderRow, sheetName: sheetName.isEmpty ? nil : sheetName)
    }

    func importMapping() throws -> GlifiStudioTabularMapping {
        guard let table, isPreviewCurrent else { throw Self.failure() }
        let variables = variableColumns.sorted().map { column in
            GlifiStudioTabularVariableMapping(
                column: column,
                name: variableNames[column] ?? table.columns[column - 1],
                type: variableTypes[column] ?? .text)
        }
        return GlifiStudioTabularMapping(
            textColumns: textColumns.sorted(),
            identifierColumn: identifierColumn == 0 ? nil : identifierColumn,
            variables: variables, missingValues: [""] + Self.lines(missingValues),
            duplicatePolicy: duplicatePolicy, invalidRowPolicy: invalidRowPolicy)
    }

    func reset() {
        lifecycle = UUID()
        state = GlifiStudioResearchState()
        selectedSourceID = ""
        selectedSourceIDs = []
        selectedSubsetID = ""
        subsetLabel = ""
        filterFieldID = ""
        filterValue = ""
        filterQuery = ""
        values = [:]
        stopwords = ""
        includedTerms = ""
        excludedTerms = ""
        compounds = ""
        includedPartsOfSpeech = ""
        hasLoaded = false
        table = nil
        mappedDataset = nil
        inputData = nil
        filename = ""
        format = .csv
        encoding = .utf8
        delimiter = .comma
        hasHeaderRow = true
        sheetName = ""
        missingValues = ""
        duplicatePolicy = .reject
        invalidRowPolicy = .reject
        textColumns = []
        variableColumns = []
        variableNames = [:]
        variableTypes = [:]
        identifierColumn = 0
        savedAnalyses = []
        selectedSavedID = nil
        savedPreview = ""
        savedValues = []
        savedValuesAreTruncated = false
        savedClient = "advanced"
        savedTitle = ""
        derivedFieldID = "classification"
        derivedFieldLabel = ""
        reportQuestion = ""
        exportedData = nil
        previewSignature = ""
    }

    func load(session: GlifiStudioProjectSession) async throws {
        let expected = lifecycle
        let loaded = try await session.researchState()
        let saved = try await session.savedAnalyses()
        try checkCurrent(expected)
        apply(loaded)
        savedAnalyses = saved
        hasLoaded = true
    }

    func save(session: GlifiStudioProjectSession) async throws {
        let expected = lifecycle
        let next = try stateForSaving()
        let saved = try await session.saveResearchState(next, expectedRevision: state.revision)
        try checkCurrent(expected)
        apply(saved)
    }

    func stateForSaving() throws -> GlifiStudioResearchState {
        var next = state
        next.preparation.stopwords = Self.lines(stopwords)
        next.preparation.includedTerms = Self.lines(includedTerms)
        next.preparation.excludedTerms = Self.lines(excludedTerms)
        next.preparation.compounds = Self.lines(compounds)
        next.preparation.includedPartsOfSpeech = Self.lines(includedPartsOfSpeech)
        for (sourceID, fields) in values {
            var record =
                next.records.first { $0.sourceRevisionID == sourceID }
                ?? GlifiStudioResearchRecord(sourceRevisionID: sourceID, values: [:])
            for field in next.fields {
                if let text = fields[field.id] {
                    if field.type == .text, text.isEmpty, record.values[field.id] == .text("") {
                        continue
                    }
                    let replacement = try Self.value(text, type: field.type)
                    if record.values[field.id] != replacement {
                        if let legacy = record.derivationArtifactID {
                            var producers = record.derivationArtifactIDs ?? [:]
                            for key in record.values.keys where producers[key] == nil {
                                producers[key] = legacy
                            }
                            record.derivationArtifactIDs = producers
                            record.derivationArtifactID = nil
                        }
                        record.origins.removeValue(forKey: field.id)
                        record.derivationArtifactIDs?.removeValue(forKey: field.id)
                    }
                    record.values[field.id] = replacement
                }
            }
            next.records.removeAll { $0.sourceRevisionID == sourceID }
            next.records.append(record)
        }
        return next
    }

    func addField() {
        var ordinal = state.fields.count + 1
        while state.fields.contains(where: { $0.id == "field-\(ordinal)" }) { ordinal += 1 }
        state.fields.append(
            GlifiStudioResearchField(id: "field-\(ordinal)", label: "", type: .text))
    }

    func removeField(_ id: String) {
        state.fields.removeAll { $0.id == id }
        for index in state.records.indices {
            state.records[index].values.removeValue(forKey: id)
            state.records[index].origins.removeValue(forKey: id)
            state.records[index].derivationArtifactIDs?.removeValue(forKey: id)
        }
        for sourceID in values.keys { values[sourceID]?.removeValue(forKey: id) }
    }

    func addSubset() {
        guard !selectedSourceIDs.isEmpty,
            !subsetLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        let id = UUID().uuidString.lowercased()
        state.subsets.append(
            GlifiStudioResearchSubset(
                id: id, label: subsetLabel, sourceRevisionIDs: selectedSourceIDs.sorted()))
        selectedSubsetID = id
        subsetLabel = ""
    }

    func filteredSources(session: GlifiStudioProjectSession) async throws -> [String] {
        let expected = lifecycle
        let field = state.fields.first { $0.id == filterFieldID }
        let filter = GlifiStudioResearchFilter(
            subsetID: selectedSubsetID.isEmpty ? nil : selectedSubsetID,
            fieldID: field?.id,
            value: try field.map { try Self.value(filterValue, type: $0.type) },
            query: filterQuery.isEmpty ? nil : filterQuery)
        let selected = try await session.selectResearchSources(filter)
        try checkCurrent(expected)
        selectedSourceIDs = Set(selected)
        return selected
    }

    func classLabels(fieldID: String) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: state.records.compactMap { record in
                record.values[fieldID]?.codingValue.map { (record.sourceRevisionID, $0) }
            })
    }

    enum VariableUse {
        case classification, groupComparison, codeCrosstab

        var client: String {
            switch self {
            case .classification, .codeCrosstab: "advanced"
            case .groupComparison: "corpusMethods"
            }
        }
    }

    /// Connects the saved variable to an existing editor without replacing the person's rules.
    func useVariable(fieldID: String, for destination: VariableUse, in home: StudioHomeModel) {
        let labels = classLabels(fieldID: fieldID)
        switch destination {
        case .classification:
            home.advancedAnalysis.labels = labels
            home.advancedAnalysis.tool = .classification
            home.khLanguage.draft.labels = labels
        case .groupComparison:
            home.corpusMethods.draft.groupLabels = labels
            home.corpusMethods.draft.tool = .groupMetrics
        case .codeCrosstab:
            home.advancedAnalysis.labels = labels
            home.advancedAnalysis.tool = .codeCrosstab
        }
    }

    func temporalAnnotations(fieldID: String) -> [String: StudioTemporalAnnotationDraft] {
        var annotations: [String: StudioTemporalAnnotationDraft] = [:]
        for record in state.records {
            guard let value = record.values[fieldID], case let .date(date) = value else { continue }
            let components = date.split(separator: "-").compactMap { Int($0) }
            guard components.count == 3 else { continue }
            annotations[record.sourceRevisionID] = StudioTemporalAnnotationDraft(
                precision: .civilDate, year: components[0], month: components[1],
                day: components[2],
                provenance: "research-metadata-v1;field=\(fieldID);revision=\(state.revision)")
        }
        return annotations
    }

    func setInput(data: Data, filename: String) {
        inputData = data
        self.filename = filename
        format = filename.lowercased().hasSuffix(".xlsx") ? .xlsx : .csv
        if filename.lowercased().hasSuffix(".tsv") { delimiter = .tab }
        sheetName = ""
        table = nil
        mappedDataset = nil
        textColumns = []
        variableColumns = []
        variableNames = [:]
        variableTypes = [:]
        identifierColumn = 0
        previewSignature = ""
    }

    func preview() async throws {
        guard let inputData else { throw Self.failure() }
        let expected = lifecycle
        let options = importOptions
        let signature = optionsSignature
        let next = try await GlifiStudioTabularImporter.preview(data: inputData, options: options)
        try checkCurrent(expected)
        previewSignature = signature
        table = next
        mappedDataset = nil
        textColumns = textColumns.filter { $0 > 0 && $0 <= next.columns.count }
        variableColumns = variableColumns.filter { $0 > 0 && $0 <= next.columns.count }
        if identifierColumn > next.columns.count { identifierColumn = 0 }
    }

    func map() async throws {
        guard let table, isPreviewCurrent else { throw Self.failure() }
        let expected = lifecycle
        let mapping = try importMapping()
        let next = try await GlifiStudioTabularImporter.map(table: table, mapping: mapping)
        try checkCurrent(expected)
        mappedDataset = next
    }

    func selectSaved(_ entry: GlifiStudioSavedAnalysis) async throws {
        let expected = lifecycle
        let rawResult = try await Self.resultData(entry)
        let preview = try await Self.previewJSON(rawResult)
        let projected = try await Self.resultValues(rawResult)
        let client = try await Self.presentationClient(entry.presentationJSON)
        try checkCurrent(expected)
        selectedSavedID = entry.id
        savedPreview = preview
        savedValues = projected.rows
        savedValuesAreTruncated = projected.truncated
        savedClient = client
    }

    private func apply(_ loaded: GlifiStudioResearchState) {
        state = loaded
        stopwords = loaded.preparation.stopwords.joined(separator: "\n")
        includedTerms = loaded.preparation.includedTerms.joined(separator: "\n")
        excludedTerms = loaded.preparation.excludedTerms.joined(separator: "\n")
        compounds = loaded.preparation.compounds.joined(separator: "\n")
        includedPartsOfSpeech = loaded.preparation.includedPartsOfSpeech.joined(separator: "\n")
        values = Dictionary(
            uniqueKeysWithValues: loaded.records.map { record in
                (record.sourceRevisionID, record.values.mapValues(Self.text))
            })
    }

    private func checkCurrent(_ expected: UUID) throws {
        try Task.checkCancellation()
        guard lifecycle == expected else { throw CancellationError() }
    }

    nonisolated static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    nonisolated static func text(_ value: GlifiStudioResearchValue) -> String {
        switch value {
        case .missing: ""
        case let .text(value): value
        case let .number(value): String(value)
        case let .boolean(value): value ? "true" : "false"
        case let .date(value): value
        }
    }

    nonisolated static func value(
        _ text: String, type: GlifiStudioResearchFieldType
    ) throws -> GlifiStudioResearchValue {
        if text.isEmpty { return .missing }
        switch type {
        case .text: return .text(text)
        case .number:
            guard let number = Double(text), number.isFinite else { throw failure() }
            return .number(number)
        case .boolean:
            guard text == "true" || text == "false" else { throw failure() }
            return .boolean(text == "true")
        case .date: return .date(text)
        }
    }

    @concurrent static func readInput(at url: URL) async throws -> Data {
        let maximum = 64 * 1_024 * 1_024
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var bytes = Data()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: min(64 * 1_024, maximum + 1 - bytes.count))
            guard let chunk, !chunk.isEmpty else { break }
            bytes.append(chunk)
            guard bytes.count <= maximum else { throw failure() }
        }
        return bytes
    }

    @concurrent private static func previewJSON(_ bytes: Data) async throws -> String {
        try Task.checkCancellation()
        return String(decoding: bytes.prefix(65_536), as: UTF8.self)
    }

    @concurrent private static func resultData(_ entry: GlifiStudioSavedAnalysis) async throws
        -> Data
    {
        try Task.checkCancellation()
        if entry.transportIdentifier == "workbench-capture-v1" {
            return try GlifiStudioWorkbenchCapture(saved: entry).resultJSON
        }
        return entry.resultJSON
    }

    @concurrent private static func presentationClient(_ bytes: Data?) async throws -> String {
        guard let bytes else { return "" }
        try Task.checkCancellation()
        let fields = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        return fields?["client"] as? String ?? "advanced"
    }

    @concurrent private static func resultValues(_ bytes: Data) async throws -> (
        rows: [StudioResearchSavedValue], truncated: Bool
    ) {
        try Task.checkCancellation()
        let value = try JSONSerialization.jsonObject(with: bytes)
        var rows: [StudioResearchSavedValue] = []
        var truncated = false
        func visit(_ value: Any, path: String, depth: Int) throws {
            try Task.checkCancellation()
            guard depth <= 32, rows.count < 512 else {
                truncated = true
                return
            }
            if let dictionary = value as? [String: Any] {
                for key in dictionary.keys.sorted() {
                    guard rows.count < 512 else {
                        truncated = true
                        break
                    }
                    if let child = dictionary[key] {
                        try visit(
                            child, path: path.isEmpty ? key : "\(path).\(key)", depth: depth + 1)
                    }
                }
            } else if let array = value as? [Any] {
                for (index, child) in array.enumerated() {
                    guard rows.count < 512 else {
                        truncated = true
                        break
                    }
                    try visit(child, path: "\(path)[\(index + 1)]", depth: depth + 1)
                }
            } else if let number = value as? NSNumber {
                rows.append(StudioResearchSavedValue(id: path, value: number.stringValue))
            } else if let text = value as? String {
                rows.append(StudioResearchSavedValue(id: path, value: String(text.prefix(4_096))))
            } else if value is NSNull {
                rows.append(StudioResearchSavedValue(id: path, value: "—"))
            }
        }
        try visit(value, path: "", depth: 0)
        return (rows, truncated)
    }

    nonisolated private static func failure() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "ui.research.invalid-input", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "research.invalid-input", arguments: [:])
    }
}
