// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Supported tabular containers; legacy binary Excel workbooks are intentionally excluded.
public enum GlifiTabularFormat: String, Codable, CaseIterable, Sendable { case csv, xlsx }

/// Explicit source decoding policy; no lossy replacement or automatic encoding guesses.
public enum GlifiTabularEncoding: String, Codable, CaseIterable, Sendable {
    case utf8, utf16LittleEndian, utf16BigEndian, windows1252
}

/// Delimiter of a CSV source, independent of the system locale.
public enum GlifiTabularDelimiter: String, Codable, CaseIterable, Sendable {
    case comma, semicolon, tab

    var byte: UInt8 {
        switch self {
        case .comma: 44
        case .semicolon: 59
        case .tab: 9
        }
    }
}

/// Bounds checked before parsing, dense row construction and mapped output allocation.
public struct GlifiTabularLimits: Codable, Equatable, Sendable {
    /// Default envelope: 16 MiB, 10,000 rows, 256 columns, 200,000 cells and 1 MiB per cell.
    public static let standard = GlifiTabularLimits()
    /// Maximum original bytes and cumulative UTF-8 text bytes admitted by the mapping.
    public var maximumByteCount: Int
    /// Maximum parsed rows, including the optional header row.
    public var maximumRows: Int
    /// Maximum cells in one row before dense row construction.
    public var maximumColumns: Int
    /// Maximum total cells retained across the admitted table.
    public var maximumCells: Int
    /// Maximum UTF-8 bytes in one decoded cell.
    public var maximumCellBytes: Int

    /// Creates explicit parsing bounds, validated when a parser or mapper admits the request.
    public init(
        maximumByteCount: Int = 16 * 1_024 * 1_024, maximumRows: Int = 10_000,
        maximumColumns: Int = 256, maximumCells: Int = 200_000,
        maximumCellBytes: Int = 1_024 * 1_024
    ) {
        self.maximumByteCount = maximumByteCount
        self.maximumRows = maximumRows
        self.maximumColumns = maximumColumns
        self.maximumCells = maximumCells
        self.maximumCellBytes = maximumCellBytes
    }

    func validate() throws {
        guard (1...64 * 1_024 * 1_024).contains(maximumByteCount),
            (1...100_000).contains(maximumRows), (1...1_024).contains(maximumColumns),
            (1...1_000_000).contains(maximumCells),
            (1...16 * 1_024 * 1_024).contains(maximumCellBytes)
        else { throw tabularFailure("invalid-limits") }
    }
}

/// Fully resolved parsing choices, preserved in the preview for later provenance.
public struct GlifiTabularOptions: Codable, Equatable, Sendable {
    /// Explicit container type, independent of its filename extension.
    public var format: GlifiTabularFormat
    /// Strict CSV character encoding; XLSX uses each XML part’s declared encoding.
    public var encoding: GlifiTabularEncoding
    /// Explicit CSV field separator; not inferred from the current locale.
    public var delimiter: GlifiTabularDelimiter
    /// Whether the first parsed row supplies column labels instead of document data.
    public var hasHeaderRow: Bool
    /// Exact XLSX sheet name, or nil to select the first workbook sheet.
    public var sheetName: String?
    /// Resource envelope enforced before parsing and constructing the mapped output.
    public var limits: GlifiTabularLimits

    /// Creates resolved container, decoding, header, worksheet and resource choices.
    public init(
        format: GlifiTabularFormat = .csv, encoding: GlifiTabularEncoding = .utf8,
        delimiter: GlifiTabularDelimiter = .comma, hasHeaderRow: Bool = true,
        sheetName: String? = nil, limits: GlifiTabularLimits = .standard
    ) {
        self.format = format
        self.encoding = encoding
        self.delimiter = delimiter
        self.hasHeaderRow = hasHeaderRow
        self.sheetName = sheetName
        self.limits = limits
    }
}

/// One source row with its original physical ordinal.
///
/// `number` includes headers; quoted CSV newlines retain physical row positions.
public struct GlifiTabularRow: Codable, Equatable, Sendable {
    /// One-based physical CSV starting line or original XLSX row number.
    public let number: Int
    /// Cells in source-column order; nil identifies an absent XLSX cell.
    public let cells: [String?]
}

/// Complete table admitted within the explicit parsing bounds.
///
/// Views may page the retained rows; parsing never silently truncates them.
public struct GlifiTabularTable: Codable, Equatable, Sendable {
    /// Canonical SHA-256 digest of the exact original bytes, including any byte-order mark.
    public let sourceDigest: String
    /// Exact original container size before character decoding or ZIP expansion.
    public let sourceByteCount: Int
    /// Resolved parsing choices retained with this preview.
    public let options: GlifiTabularOptions
    /// Column labels in source order, with generated labels for missing header values.
    public let columns: [String]
    /// All admitted data rows, excluding the optional header and preserving source order.
    public let rows: [GlifiTabularRow]
    /// XLSX sheet names in workbook order, or an empty list for CSV.
    public let sheetNames: [String]
    /// Actual XLSX sheet used by this preview, or nil for CSV.
    public let selectedSheet: String?
}

/// Target scalar domain of one metadata column.
///
/// Dates require exact Gregorian YYYY-MM-DD syntax.
public enum GlifiTabularValueType: String, Codable, CaseIterable, Sendable {
    case text, integer, decimal, boolean, date
}

/// One explicitly typed value; missing values are represented by absence in the variables map.
public enum GlifiTabularValue: Codable, Equatable, Sendable {
    case text(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case date(String)
}

/// A one-based source column mapped to a named typed variable.
public struct GlifiTabularVariableMapping: Codable, Equatable, Sendable {
    /// One-based original column containing this variable.
    public var column: Int
    /// Unique NFC variable name used as the key in mapped records.
    public var name: String
    /// Required scalar domain; invalid non-missing values follow the invalid-row policy.
    public var type: GlifiTabularValueType
    /// Maps one original column to a named metadata variable with an explicit scalar type.
    public init(column: Int, name: String, type: GlifiTabularValueType = .text) {
        self.column = column
        self.name = name
        self.type = type
    }
}

/// Explicit handling of repeated NFC identifiers, without automatic overwrite.
public enum GlifiTabularDuplicatePolicy: String, Codable, CaseIterable, Sendable {
    case reject, skip, appendRowNumber
}
/// Explicit handling of malformed data rows after container parsing succeeds.
public enum GlifiTabularInvalidRowPolicy: String, Codable, CaseIterable, Sendable {
    case reject, skip
}

/// Explicit row mapping, with no inference from column names or numerical formatting.
public struct GlifiTabularMapping: Codable, Equatable, Sendable {
    /// Distinct one-based columns concatenated in this exact order with two LF separators.
    public var textColumns: [Int]
    /// One-based identifier column, or nil to generate dataset-local row identifiers.
    public var identifierColumn: Int?
    /// Explicit typed metadata columns, independent of the text-column selection.
    public var variables: [GlifiTabularVariableMapping]
    /// Exact cell strings interpreted as missing; no whitespace or case normalization is inferred.
    public var missingValues: [String]
    /// Explicit disposition of duplicate NFC identifiers within the mapped dataset.
    public var duplicatePolicy: GlifiTabularDuplicatePolicy
    /// Whether invalid row widths, absent text or invalid typed values abort or are recorded as skips.
    public var invalidRowPolicy: GlifiTabularInvalidRowPolicy
    /// Selects text, identifiers and typed variables with explicit missing-value and row policies.
    public init(
        textColumns: [Int], identifierColumn: Int? = nil,
        variables: [GlifiTabularVariableMapping] = [], missingValues: [String] = [""],
        duplicatePolicy: GlifiTabularDuplicatePolicy = .reject,
        invalidRowPolicy: GlifiTabularInvalidRowPolicy = .reject
    ) {
        self.textColumns = textColumns
        self.identifierColumn = identifierColumn
        self.variables = variables
        self.missingValues = missingValues
        self.duplicatePolicy = duplicatePolicy
        self.invalidRowPolicy = invalidRowPolicy
    }
}

/// Cell address in the exact original container, identified by its SHA-256 digest.
public struct GlifiTabularCellOrigin: Codable, Equatable, Sendable {
    /// Canonical SHA-256 digest identifying the exact original container.
    public let sourceDigest: String
    /// Original XLSX sheet name, or nil for CSV.
    public let sheet: String?
    /// One-based physical starting line for CSV or original XLSX row number.
    public let row: Int
    /// One-based original cell column, independent of the mapped field order.
    public let column: Int
}

/// Half-open UTF-8 interval in the mapped text, pointing to its original source column.
public struct GlifiTabularTextSegment: Codable, Equatable, Sendable {
    /// One-based original column contributing this mapped-text interval.
    public let column: Int
    /// Inclusive byte offset in the concatenated mapped UTF-8 text.
    public let startUTF8: Int
    /// Exclusive byte offset in the concatenated mapped UTF-8 text.
    public let endUTF8: Int
}

/// One validated logical document ready for transactional project incorporation.
public struct GlifiTabularMappedRecord: Codable, Equatable, Sendable {
    /// NFC identifier unique among the accepted rows of this dataset.
    public let identifier: String
    /// Exact selected cell text joined by two LF separators in mapping order.
    public let text: String
    /// Typed non-missing values keyed by the declared variable names.
    public let variables: [String: GlifiTabularValue]
    /// Original physical CSV starting line or XLSX row number of this document.
    public let rowNumber: Int
    /// UTF-8 intervals resolving every non-missing text contribution to its original column.
    public let textSegments: [GlifiTabularTextSegment]
    /// `text:N`, `identifier`, and `variable:NAME` keys retain their exact cell addresses.
    public let origins: [String: GlifiTabularCellOrigin]
}

/// A deliberately skipped row, without copying potentially sensitive content into diagnostics.
public struct GlifiTabularIssue: Codable, Equatable, Sendable {
    /// Original row number skipped by an explicit duplicate or invalid-row policy.
    public let rowNumber: Int
    /// Stable diagnostic code without cell contents or original filesystem paths.
    public let code: String
}

/// Mapping result with original parsing choices and every explicit skip accounted for.
public struct GlifiTabularMappedDataset: Codable, Equatable, Sendable {
    /// Canonical SHA-256 digest of the original CSV or XLSX bytes.
    public let sourceDigest: String
    /// Exact original byte count before decoding or archive expansion.
    public let sourceByteCount: Int
    /// Resolved parsing configuration used to produce the mapped rows.
    public let options: GlifiTabularOptions
    /// Explicit columns, types and policies applied to this dataset.
    public let mapping: GlifiTabularMapping
    /// Every accepted logical document in original source-row order.
    public let records: [GlifiTabularMappedRecord]
    /// Every explicitly skipped row with its original ordinal and privacy-safe reason.
    public let issues: [GlifiTabularIssue]
}

/// Non-executing, bounded CSV and SpreadsheetML import with explicit mapping semantics.
public enum GlifiTabularImporter {
    /// Parses the complete admitted container and retains exact original row and cell coordinates.
    public static func preview(data: Data, options: GlifiTabularOptions) throws -> GlifiTabularTable
    {
        try Task.checkCancellation()
        try options.limits.validate()
        guard data.count <= options.limits.maximumByteCount else { throw tabularLimit() }
        guard !data.isEmpty else {
            throw tabularFailure("empty-input", category: .insufficientData)
        }
        let parsed: (rows: [GlifiTabularRow], sheets: [String], selected: String?)
        switch options.format {
        case .csv:
            guard options.sheetName == nil else { throw tabularFailure("invalid-sheet") }
            parsed = (try tabularCSV(data, options: options), [], nil)
        case .xlsx:
            guard !data.starts(with: [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) else {
                throw tabularFailure("binary-excel-not-supported", category: .unsupportedFormat)
            }
            do {
                parsed = try GlifiTabularXLSX.read(data, options: options)
            } catch let failure as GlifiFailure {
                guard failure.code.hasPrefix("epub.") else { throw failure }
                throw tabularFailure("invalid-xlsx", category: failure.category)
            }
        }
        guard let first = parsed.rows.first else {
            throw tabularFailure("empty-input", category: .insufficientData)
        }
        let columns: [String]
        let rows: [GlifiTabularRow]
        if options.hasHeaderRow {
            columns = first.cells.enumerated().map { index, value in
                let value = value ?? ""
                return value.isEmpty ? "Colonna \(index + 1)" : value
            }
            rows = Array(parsed.rows.dropFirst())
        } else {
            let width = parsed.rows.map(\.cells.count).max() ?? 0
            columns = (0..<width).map { "Colonna \($0 + 1)" }
            rows = parsed.rows
        }
        guard !columns.isEmpty else { throw tabularFailure("empty-columns") }
        return GlifiTabularTable(
            sourceDigest: tabularDigest(data), sourceByteCount: data.count, options: options,
            columns: columns, rows: rows, sheetNames: parsed.sheets, selectedSheet: parsed.selected)
    }

    /// Produces typed logical documents and accounts for every explicitly skipped source row.
    public static func map(table: GlifiTabularTable, mapping: GlifiTabularMapping) throws
        -> GlifiTabularMappedDataset
    {
        try Task.checkCancellation()
        try validate(table: table, mapping: mapping)
        let missing = Set(mapping.missingValues)
        var identifiers = Set<String>()
        var records: [GlifiTabularMappedRecord] = []
        var issues: [GlifiTabularIssue] = []
        var totalBytes = 0
        for row in table.rows {
            try Task.checkCancellation()
            do {
                guard row.cells.count == table.columns.count else {
                    throw tabularFailure("invalid-row-width", row: row.number)
                }
                var identifier = "r\(row.number)"
                if let column = mapping.identifierColumn {
                    guard let value = row.cells[column - 1], !missing.contains(value),
                        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        value.utf8.count <= 1_024
                    else { throw tabularFailure("missing-identifier", row: row.number) }
                    identifier = value.precomposedStringWithCanonicalMapping
                }
                if identifiers.contains(identifier) {
                    switch mapping.duplicatePolicy {
                    case .reject: throw tabularFailure("duplicate-identifier", row: row.number)
                    case .skip:
                        issues.append(
                            GlifiTabularIssue(rowNumber: row.number, code: "duplicate-identifier"))
                        continue
                    case .appendRowNumber:
                        identifier += "#r\(row.number)"
                        guard !identifiers.contains(identifier) else {
                            throw tabularFailure("duplicate-identifier", row: row.number)
                        }
                    }
                }
                var text = ""
                var segments: [GlifiTabularTextSegment] = []
                var origins: [String: GlifiTabularCellOrigin] = [:]
                func origin(_ column: Int) -> GlifiTabularCellOrigin {
                    GlifiTabularCellOrigin(
                        sourceDigest: table.sourceDigest, sheet: table.selectedSheet,
                        row: row.number, column: column)
                }
                if let column = mapping.identifierColumn { origins["identifier"] = origin(column) }
                for column in mapping.textColumns {
                    origins["text:\(column)"] = origin(column)
                    guard let value = row.cells[column - 1], !missing.contains(value) else {
                        continue
                    }
                    if !text.isEmpty { text += "\n\n" }
                    let start = text.utf8.count
                    guard value.utf8.count <= table.options.limits.maximumByteCount - start else {
                        throw tabularLimit()
                    }
                    text += value
                    segments.append(
                        GlifiTabularTextSegment(
                            column: column, startUTF8: start, endUTF8: text.utf8.count))
                }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw tabularFailure("missing-text", row: row.number)
                }
                var variables: [String: GlifiTabularValue] = [:]
                for variable in mapping.variables {
                    origins["variable:\(variable.name)"] = origin(variable.column)
                    guard let value = row.cells[variable.column - 1], !missing.contains(value)
                    else {
                        continue
                    }
                    variables[variable.name] = try typed(value, as: variable.type, row: row.number)
                }
                guard text.utf8.count <= table.options.limits.maximumByteCount - totalBytes else {
                    throw tabularLimit()
                }
                totalBytes += text.utf8.count
                identifiers.insert(identifier)
                records.append(
                    GlifiTabularMappedRecord(
                        identifier: identifier, text: text, variables: variables,
                        rowNumber: row.number, textSegments: segments, origins: origins))
            } catch let failure as GlifiFailure {
                guard mapping.invalidRowPolicy == .skip, failure.category == .invalidInput,
                    failure.code != "tabular.duplicate-identifier"
                else { throw failure }
                issues.append(GlifiTabularIssue(rowNumber: row.number, code: failure.code))
            }
        }
        guard !records.isEmpty else {
            throw tabularFailure("no-valid-rows", category: .insufficientData)
        }
        return GlifiTabularMappedDataset(
            sourceDigest: table.sourceDigest, sourceByteCount: table.sourceByteCount,
            options: table.options, mapping: mapping, records: records, issues: issues)
    }

    private static func validate(table: GlifiTabularTable, mapping: GlifiTabularMapping) throws {
        try table.options.limits.validate()
        let limits = table.options.limits
        guard table.sourceByteCount >= 0, table.sourceByteCount <= limits.maximumByteCount,
            table.sourceDigest.utf8.count == 71, table.sourceDigest.hasPrefix("sha256:"),
            table.sourceDigest.dropFirst(7).allSatisfy({ "0123456789abcdef".contains($0) }),
            !table.columns.isEmpty, table.columns.count <= limits.maximumColumns,
            table.rows.count <= limits.maximumRows, !mapping.textColumns.isEmpty,
            Set(mapping.textColumns).count == mapping.textColumns.count,
            mapping.textColumns.allSatisfy({ (1...table.columns.count).contains($0) }),
            mapping.identifierColumn.map({ (1...table.columns.count).contains($0) }) ?? true,
            mapping.variables.count <= limits.maximumColumns,
            Set(mapping.variables.map(\.name)).count == mapping.variables.count,
            mapping.variables.allSatisfy({ variable in
                (1...table.columns.count).contains(variable.column)
                    && (1...128).contains(variable.name.utf8.count)
                    && variable.name == variable.name.precomposedStringWithCanonicalMapping
                    && !variable.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !variable.name.unicodeScalars.contains(where: { $0.value < 32 })
            }), mapping.missingValues.count <= 1_000,
            mapping.missingValues.allSatisfy({ $0.utf8.count <= 1_024 })
        else { throw tabularFailure("invalid-mapping") }
        var cells = 0
        var previousRow = 0
        for row in table.rows {
            try Task.checkCancellation()
            guard row.number > previousRow, row.cells.count <= limits.maximumColumns,
                row.cells.count <= limits.maximumCells - cells,
                row.cells.allSatisfy({ ($0?.utf8.count ?? 0) <= limits.maximumCellBytes })
            else { throw tabularFailure("invalid-table") }
            cells += row.cells.count
            previousRow = row.number
        }
    }

    private static func typed(_ text: String, as type: GlifiTabularValueType, row: Int) throws
        -> GlifiTabularValue
    {
        switch type {
        case .text: return .text(text)
        case .integer:
            if let value = Int64(text), String(value) == text { return .integer(value) }
        case .decimal:
            if !text.isEmpty, text == text.trimmingCharacters(in: .whitespacesAndNewlines),
                text.utf8.allSatisfy({
                    (48...57).contains($0) || [43, 45, 46, 69, 101].contains($0)
                }),
                let value = Double(text), value.isFinite
            {
                return .decimal(value == 0 ? 0 : value)
            }
        case .boolean:
            switch text {
            case "true", "1": return .boolean(true)
            case "false", "0": return .boolean(false)
            default: break
            }
        case .date:
            let bytes = Array(text.utf8)
            if bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
                bytes.enumerated().allSatisfy({ index, byte in
                    index == 4 || index == 7 || (48...57).contains(byte)
                }), let year = Int(text.prefix(4)), let month = Int(text.dropFirst(5).prefix(2)),
                let day = Int(text.suffix(2)), (1...9999).contains(year), (1...12).contains(month)
            {
                let leap =
                    year.isMultiple(of: 4)
                    && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
                let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
                if (1...days[month - 1]).contains(day) { return .date(text) }
            }
        }
        throw tabularFailure("invalid-variable-value", row: row)
    }
}

func tabularDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func tabularFailure(
    _ code: String, category: GlifiFailureCategory = .invalidInput, row: Int? = nil
) -> GlifiFailure {
    GlifiFailure(
        code: "tabular.\(code)", category: category, operation: .importText,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.tabular.\(code)",
        arguments: row.map { ["row": String($0)] } ?? [:])
}

func tabularLimit() -> GlifiFailure {
    tabularFailure("resource-limit", category: .insufficientResources)
}

private func tabularCSV(_ data: Data, options: GlifiTabularOptions) throws -> [GlifiTabularRow] {
    let encoding: String.Encoding
    switch options.encoding {
    case .utf8: encoding = .utf8
    case .utf16LittleEndian: encoding = .utf16LittleEndian
    case .utf16BigEndian: encoding = .utf16BigEndian
    case .windows1252: encoding = .windowsCP1252
    }
    let decoded =
        options.encoding == .utf8
        ? String(validating: data, as: UTF8.self) : String(data: data, encoding: encoding)
    guard var text = decoded,
        text.data(using: encoding, allowLossyConversion: false) == data
    else {
        throw tabularFailure("invalid-encoding")
    }
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    guard !text.unicodeScalars.contains(where: { $0.value == 0 }),
        text.utf8.count <= options.limits.maximumByteCount * 3
    else { throw tabularFailure("invalid-encoding") }
    let bytes = Array(text.utf8)
    var cursor = 0
    var physicalRow = 1
    var rowStart = 1
    var cell = Data()
    var cells: [String?] = []
    var rows: [GlifiTabularRow] = []
    var totalCells = 0
    enum State: Equatable { case start, unquoted, quoted, closed }
    var state = State.start
    func finishCell() throws {
        guard cells.count < options.limits.maximumColumns,
            totalCells < options.limits.maximumCells,
            let value = String(validating: cell, as: UTF8.self)
        else { throw tabularLimit() }
        cells.append(value)
        totalCells += 1
        cell.removeAll(keepingCapacity: true)
    }
    func finishRow() throws {
        try finishCell()
        guard rows.count < options.limits.maximumRows else { throw tabularLimit() }
        rows.append(GlifiTabularRow(number: rowStart, cells: cells))
        cells.removeAll(keepingCapacity: true)
        state = .start
    }
    while cursor < bytes.count {
        if cursor.isMultiple(of: 4_096) { try Task.checkCancellation() }
        let byte = bytes[cursor]
        let newline = byte == 10 || byte == 13
        if state == .quoted {
            if byte == 34 {
                if cursor + 1 < bytes.count, bytes[cursor + 1] == 34 {
                    guard cell.count < options.limits.maximumCellBytes else { throw tabularLimit() }
                    cell.append(34)
                    cursor += 2
                    continue
                }
                state = .closed
            } else {
                guard cell.count < options.limits.maximumCellBytes else { throw tabularLimit() }
                cell.append(byte)
                if byte == 10
                    || (byte == 13 && (cursor + 1 == bytes.count || bytes[cursor + 1] != 10))
                {
                    physicalRow += 1
                }
            }
        } else if byte == options.delimiter.byte {
            try finishCell()
            state = .start
        } else if newline {
            try finishRow()
            if byte == 13, cursor + 1 < bytes.count, bytes[cursor + 1] == 10 { cursor += 1 }
            physicalRow += 1
            rowStart = physicalRow
        } else if byte == 34 {
            guard state == .start else { throw tabularFailure("invalid-csv", row: physicalRow) }
            state = .quoted
        } else {
            guard state != .closed else { throw tabularFailure("invalid-csv", row: physicalRow) }
            guard cell.count < options.limits.maximumCellBytes else { throw tabularLimit() }
            cell.append(byte)
            state = .unquoted
        }
        cursor += 1
    }
    guard state != .quoted else { throw tabularFailure("invalid-csv", row: physicalRow) }
    if !cell.isEmpty || !cells.isEmpty || state != .start { try finishRow() }
    return rows
}
