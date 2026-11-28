// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Supported tabular containers; legacy binary Excel workbooks are intentionally excluded.
public enum GlifiStudioTabularFormat: String, Codable, CaseIterable, Sendable { case csv, xlsx }

/// Explicit source decoding policy; no lossy replacement or automatic encoding guesses.
public enum GlifiStudioTabularEncoding: String, Codable, CaseIterable, Sendable {
    case utf8, utf16LittleEndian, utf16BigEndian, windows1252
}

/// Delimiter of a CSV source, independent of the system locale.
public enum GlifiStudioTabularDelimiter: String, Codable, CaseIterable, Sendable {
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
public struct GlifiStudioTabularLimits: Codable, Equatable, Sendable {
    /// Default envelope: 16 MiB, 10,000 rows, 256 columns, 200,000 cells and 1 MiB per cell.
    public static let standard = GlifiStudioTabularLimits()
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

}

/// Fully resolved parsing choices, preserved in the preview for later provenance.
public struct GlifiStudioTabularOptions: Codable, Equatable, Sendable {
    /// Explicit container type, independent of its filename extension.
    public var format: GlifiStudioTabularFormat
    /// Strict CSV character encoding; XLSX uses each XML part’s declared encoding.
    public var encoding: GlifiStudioTabularEncoding
    /// Explicit CSV field separator; not inferred from the current locale.
    public var delimiter: GlifiStudioTabularDelimiter
    /// Whether the first parsed row supplies column labels instead of document data.
    public var hasHeaderRow: Bool
    /// Exact XLSX sheet name, or nil to select the first workbook sheet.
    public var sheetName: String?
    /// Resource envelope enforced before parsing and constructing the mapped output.
    public var limits: GlifiStudioTabularLimits

    /// Creates resolved container, decoding, header, worksheet and resource choices.
    public init(
        format: GlifiStudioTabularFormat = .csv, encoding: GlifiStudioTabularEncoding = .utf8,
        delimiter: GlifiStudioTabularDelimiter = .comma, hasHeaderRow: Bool = true,
        sheetName: String? = nil, limits: GlifiStudioTabularLimits = .standard
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
public struct GlifiStudioTabularRow: Codable, Equatable, Sendable {
    /// One-based physical CSV starting line or original XLSX row number.
    public let number: Int
    /// Cells in source-column order; nil identifies an absent XLSX cell.
    public let cells: [String?]
}

/// Complete table admitted within the explicit parsing bounds.
///
/// Views may page the retained rows; parsing never silently truncates them.
public struct GlifiStudioTabularTable: Codable, Equatable, Sendable {
    /// Canonical SHA-256 digest of the exact original bytes, including any byte-order mark.
    public let sourceDigest: String
    /// Exact original container size before character decoding or ZIP expansion.
    public let sourceByteCount: Int
    /// Resolved parsing choices retained with this preview.
    public let options: GlifiStudioTabularOptions
    /// Column labels in source order, with generated labels for missing header values.
    public let columns: [String]
    /// All admitted data rows, excluding the optional header and preserving source order.
    public let rows: [GlifiStudioTabularRow]
    /// XLSX sheet names in workbook order, or an empty list for CSV.
    public let sheetNames: [String]
    /// Actual XLSX sheet used by this preview, or nil for CSV.
    public let selectedSheet: String?
}

/// Target scalar domain of one metadata column.
///
/// Dates require exact Gregorian YYYY-MM-DD syntax.
public enum GlifiStudioTabularValueType: String, Codable, CaseIterable, Sendable {
    case text, integer, decimal, boolean, date
}

/// One explicitly typed value; missing values are represented by absence in the variables map.
public enum GlifiStudioTabularValue: Codable, Equatable, Sendable {
    case text(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case date(String)
}

/// A one-based source column mapped to a named typed variable.
public struct GlifiStudioTabularVariableMapping: Codable, Equatable, Sendable {
    /// One-based original column containing this variable.
    public var column: Int
    /// Unique NFC variable name used as the key in mapped records.
    public var name: String
    /// Required scalar domain; invalid non-missing values follow the invalid-row policy.
    public var type: GlifiStudioTabularValueType
    /// Maps one original column to a named metadata variable with an explicit scalar type.
    public init(column: Int, name: String, type: GlifiStudioTabularValueType = .text) {
        self.column = column
        self.name = name
        self.type = type
    }
}

/// Explicit handling of repeated NFC identifiers, without automatic overwrite.
public enum GlifiStudioTabularDuplicatePolicy: String, Codable, CaseIterable, Sendable {
    case reject, skip, appendRowNumber
}
/// Explicit handling of malformed data rows after container parsing succeeds.
public enum GlifiStudioTabularInvalidRowPolicy: String, Codable, CaseIterable, Sendable {
    case reject, skip
}

/// Explicit row mapping, with no inference from column names or numerical formatting.
public struct GlifiStudioTabularMapping: Codable, Equatable, Sendable {
    /// Distinct one-based columns concatenated in this exact order with two LF separators.
    public var textColumns: [Int]
    /// One-based identifier column, or nil to generate dataset-local row identifiers.
    public var identifierColumn: Int?
    /// Explicit typed metadata columns, independent of the text-column selection.
    public var variables: [GlifiStudioTabularVariableMapping]
    /// Exact cell strings interpreted as missing; no whitespace or case normalization is inferred.
    public var missingValues: [String]
    /// Explicit disposition of duplicate NFC identifiers within the mapped dataset.
    public var duplicatePolicy: GlifiStudioTabularDuplicatePolicy
    /// Whether invalid row widths, absent text or invalid typed values abort or are recorded as skips.
    public var invalidRowPolicy: GlifiStudioTabularInvalidRowPolicy
    /// Selects text, identifiers and typed variables with explicit missing-value and row policies.
    public init(
        textColumns: [Int], identifierColumn: Int? = nil,
        variables: [GlifiStudioTabularVariableMapping] = [], missingValues: [String] = [""],
        duplicatePolicy: GlifiStudioTabularDuplicatePolicy = .reject,
        invalidRowPolicy: GlifiStudioTabularInvalidRowPolicy = .reject
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
public struct GlifiStudioTabularCellOrigin: Codable, Equatable, Sendable {
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
public struct GlifiStudioTabularTextSegment: Codable, Equatable, Sendable {
    /// One-based original column contributing this mapped-text interval.
    public let column: Int
    /// Inclusive byte offset in the concatenated mapped UTF-8 text.
    public let startUTF8: Int
    /// Exclusive byte offset in the concatenated mapped UTF-8 text.
    public let endUTF8: Int
}

/// One validated logical document ready for transactional project incorporation.
public struct GlifiStudioTabularMappedRecord: Codable, Equatable, Sendable {
    /// NFC identifier unique among the accepted rows of this dataset.
    public let identifier: String
    /// Exact selected cell text joined by two LF separators in mapping order.
    public let text: String
    /// Typed non-missing values keyed by the declared variable names.
    public let variables: [String: GlifiStudioTabularValue]
    /// Original physical CSV starting line or XLSX row number of this document.
    public let rowNumber: Int
    /// UTF-8 intervals resolving every non-missing text contribution to its original column.
    public let textSegments: [GlifiStudioTabularTextSegment]
    /// `text:N`, `identifier`, and `variable:NAME` keys retain their exact cell addresses.
    public let origins: [String: GlifiStudioTabularCellOrigin]
}

/// A deliberately skipped row, without copying potentially sensitive content into diagnostics.
public struct GlifiStudioTabularIssue: Codable, Equatable, Sendable {
    /// Original row number skipped by an explicit duplicate or invalid-row policy.
    public let rowNumber: Int
    /// Stable diagnostic code without cell contents or original filesystem paths.
    public let code: String
}

/// Mapping result with original parsing choices and every explicit skip accounted for.
public struct GlifiStudioTabularMappedDataset: Codable, Equatable, Sendable {
    /// Canonical SHA-256 digest of the original CSV or XLSX bytes.
    public let sourceDigest: String
    /// Exact original byte count before decoding or archive expansion.
    public let sourceByteCount: Int
    /// Resolved parsing configuration used to produce the mapped rows.
    public let options: GlifiStudioTabularOptions
    /// Explicit columns, types and policies applied to this dataset.
    public let mapping: GlifiStudioTabularMapping
    /// Every accepted logical document in original source-row order.
    public let records: [GlifiStudioTabularMappedRecord]
    /// Every explicitly skipped row with its original ordinal and privacy-safe reason.
    public let issues: [GlifiStudioTabularIssue]
}

/// Core-free native and CLI facade for bounded tabular parsing and explicit row mapping.
public enum GlifiStudioTabularImporter {
    /// Parses the complete admitted container and retains exact original row and cell coordinates.
    @concurrent public static func preview(
        data: Data, options: GlifiStudioTabularOptions
    ) async throws(GlifiStudioFailure) -> GlifiStudioTabularTable {
        do {
            let core: GlifiTabularOptions = try tabularConvert(options)
            return try tabularConvert(GlifiTabularImporter.preview(data: data, options: core))
        } catch { throw tabularMapFailure(error) }
    }

    /// Produces typed logical documents and accounts for every explicitly skipped source row.
    @concurrent public static func map(
        table: GlifiStudioTabularTable, mapping: GlifiStudioTabularMapping
    ) async throws(GlifiStudioFailure) -> GlifiStudioTabularMappedDataset {
        do {
            let coreTable: GlifiTabularTable = try tabularConvert(table)
            let coreMapping: GlifiTabularMapping = try tabularConvert(mapping)
            return try tabularConvert(
                GlifiTabularImporter.map(table: coreTable, mapping: coreMapping))
        } catch { throw tabularMapFailure(error) }
    }
}

/// DTO conversion preserves the versioned JSON contract while keeping Core types out of public API.
private func tabularConvert<A: Encodable, B: Decodable>(_ value: A) throws -> B {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try JSONDecoder().decode(B.self, from: encoder.encode(value))
}

private func tabularMapFailure(_ error: Error) -> GlifiStudioFailure {
    if let failure = error as? GlifiFailure { return GlifiStudioFailure(failure) }
    if error is CancellationError {
        return GlifiStudioFailure(
            code: "tabular.cancelled", category: "cancelled", operation: "importText",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.tabular.cancelled")
    }
    return GlifiStudioFailure(
        code: "tabular.invalid-input", category: "invalidInput", operation: "importText",
        retryDisposition: "afterCorrection", retainedState: "unchanged",
        messageKey: "failure.tabular.invalid-input")
}
