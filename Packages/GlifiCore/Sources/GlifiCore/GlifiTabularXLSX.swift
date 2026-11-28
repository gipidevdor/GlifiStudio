// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Reads a conservative, non-executing XLSX profile through the existing bounded ZIP reader.
enum GlifiTabularXLSX {
    static func read(_ data: Data, options: GlifiTabularOptions) throws
        -> (rows: [GlifiTabularRow], sheets: [String], selected: String?)
    {
        let limits = options.limits
        var archive = try GlifiZIPReader(
            data,
            limits: GlifiTextImportLimits(
                maximumByteCount: limits.maximumByteCount, maximumArchiveEntryCount: 2_048,
                maximumExpandedArchiveByteCount: 64 * 1_024 * 1_024,
                maximumArchiveEntryByteCount: 16 * 1_024 * 1_024))
        guard archive.entry("[Content_Types].xml") != nil,
            !archive.entries.contains(where: { $0.path.lowercased().hasSuffix("vbaproject.bin") })
        else { throw tabularFailure("unsupported-workbook", category: .unsupportedFormat) }
        for entry in archive.entries
        where entry.path.hasSuffix(".rels") && entry.path != "xl/_rels/workbook.xml.rels" {
            try parse(
                archive.read(entry.path), delegate: TabularExternalRelationXML(limits: limits))
        }
        let workbook = TabularWorkbookXML(limits: limits)
        try parse(archive.read("xl/workbook.xml"), delegate: workbook)
        guard !workbook.sheets.isEmpty, workbook.sheets.count <= 256,
            Set(workbook.sheets.map(\.name)).count == workbook.sheets.count
        else { throw tabularFailure("invalid-workbook") }
        let relationships = TabularRelationshipsXML(limits: limits)
        try parse(archive.read("xl/_rels/workbook.xml.rels"), delegate: relationships)
        guard
            let selected = options.sheetName.map({ name in workbook.sheets.first { $0.name == name }
            })
                ?? workbook.sheets.first
        else { throw tabularFailure("invalid-sheet") }
        if let name = options.sheetName, name != selected.name {
            throw tabularFailure("invalid-sheet")
        }
        guard let relation = relationships.values[selected.relationship],
            relation.type.hasSuffix("/worksheet")
        else { throw tabularFailure("invalid-workbook") }
        var shared: [String] = []
        let sharedRelations = relationships.values.values.filter {
            $0.type.hasSuffix("/sharedStrings")
        }
        guard sharedRelations.count <= 1 else { throw tabularFailure("invalid-workbook") }
        if let strings = sharedRelations.first {
            let parser = TabularStringsXML(limits: limits)
            try parse(archive.read(strings.path), delegate: parser)
            shared = parser.values
        }
        var dateStyles = Set<Int>()
        let styleRelations = relationships.values.values.filter { $0.type.hasSuffix("/styles") }
        guard styleRelations.count <= 1 else { throw tabularFailure("invalid-workbook") }
        if let styles = styleRelations.first {
            let parser = TabularStylesXML(limits: limits)
            try parse(archive.read(styles.path), delegate: parser)
            dateStyles = parser.dateStyles
        }
        let sheet = TabularSheetXML(
            limits: limits, shared: shared, dateStyles: dateStyles,
            uses1904Dates: workbook.uses1904Dates)
        try parse(archive.read(relation.path), delegate: sheet)
        guard !sheet.rows.isEmpty else {
            throw tabularFailure("empty-input", category: .insufficientData)
        }
        let width = sheet.rows.map(\.cells.count).max() ?? 0
        guard width <= limits.maximumColumns,
            sheet.rows.count <= limits.maximumCells / max(1, width)
        else { throw tabularLimit() }
        let rows = sheet.rows.map { row in
            GlifiTabularRow(
                number: row.number,
                cells: row.cells + [String?](repeating: nil, count: width - row.cells.count))
        }
        return (rows, workbook.sheets.map(\.name), selected.name)
    }

    private static func parse(_ data: Data, delegate: TabularXML) throws {
        try Task.checkCancellation()
        // XMLParser with external resolution disabled may silently omit an external entity
        // instead of reporting its declaration. Reject DTDs before invoking it, including
        // UTF-16/32 encodings where ASCII declaration bytes are interleaved with zeroes.
        let declaration = Array("<!DOCTYPE".utf8)
        var matched = 0
        for (index, byte) in data.enumerated() {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
            if byte == 0 { continue }
            if byte == declaration[matched] {
                matched += 1
                guard matched < declaration.count else { throw tabularFailure("xml-entity") }
            } else {
                matched = byte == declaration[0] ? 1 : 0
            }
        }
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        let parsed = parser.parse()
        if let failure = delegate.failure { throw failure }
        guard parsed, delegate.stack.isEmpty, delegate.nodes > 0 else {
            throw tabularFailure("invalid-xml")
        }
    }
}

private class TabularXML: NSObject, XMLParserDelegate {
    let limits: GlifiTabularLimits
    var stack: [String] = []
    var nodes = 0
    var failure: Error?
    init(limits: GlifiTabularLimits) { self.limits = limits }
    func start(_ name: String, attributes: [String: String]) throws {}
    func end(_ name: String) throws {}
    func characters(_ text: String) throws {}

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String]
    ) {
        do {
            try Task.checkCancellation()
            guard stack.count < 64, nodes < 1_000_000 else { throw tabularLimit() }
            nodes += 1
            guard attributeDict["xml:base"] == nil else { throw tabularFailure("invalid-xml") }
            stack.append(elementName)
            try start(elementName, attributes: attributeDict)
        } catch { abort(parser, error) }
    }
    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        do {
            guard stack.last == elementName else { throw tabularFailure("invalid-xml") }
            try end(elementName)
            stack.removeLast()
        } catch { abort(parser, error) }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        do {
            try Task.checkCancellation()
            try characters(string)
        } catch { abort(parser, error) }
    }
    func parser(_ parser: XMLParser, foundCDATA cdataBlock: Data) {
        guard let text = String(validating: cdataBlock, as: UTF8.self) else {
            abort(parser, tabularFailure("invalid-xml"))
            return
        }
        self.parser(parser, foundCharacters: text)
    }
    func parser(
        _ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?
    ) { abort(parser, tabularFailure("xml-entity")) }
    func parser(
        _ parser: XMLParser, foundExternalEntityDeclarationWithName name: String,
        publicID: String?, systemID: String?
    ) { abort(parser, tabularFailure("xml-entity")) }
    func parser(
        _ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String,
        publicID: String?, systemID: String?, notationName: String?
    ) { abort(parser, tabularFailure("xml-entity")) }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?)
        -> Data?
    {
        abort(parser, tabularFailure("xml-entity"))
        return nil
    }
    func abort(_ parser: XMLParser, _ error: Error) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }
}

private final class TabularWorkbookXML: TabularXML {
    struct Sheet {
        let name: String
        let relationship: String
    }
    var sheets: [Sheet] = []
    var uses1904Dates = false
    override func start(_ name: String, attributes: [String: String]) throws {
        if stack.count == 1, name != "workbook" { throw tabularFailure("invalid-workbook") }
        if name == "workbookPr", let flag = attributes["date1904"] {
            guard ["0", "1", "true", "false"].contains(flag) else {
                throw tabularFailure("invalid-workbook")
            }
            uses1904Dates = flag == "1" || flag == "true"
        }
        if name == "sheet", stack.dropLast().last == "sheets" {
            guard sheets.count < 256, let label = attributes["name"], !label.isEmpty,
                label.utf8.count <= 1_024, let relationship = attributes["r:id"],
                !relationship.isEmpty
            else { throw tabularFailure("invalid-workbook") }
            sheets.append(Sheet(name: label, relationship: relationship))
        }
    }
}

private final class TabularStylesXML: TabularXML {
    var dateStyles = Set<Int>()
    private var formatIDs: [Int] = []
    private var customFormats: [Int: String] = [:]
    override func start(_ name: String, attributes: [String: String]) throws {
        if name == "numFmt", stack.dropLast().last == "numFmts" {
            guard customFormats.count < 4_096, let id = Int(attributes["numFmtId"] ?? ""),
                let format = attributes["formatCode"], format.utf8.count <= 4_096,
                customFormats[id] == nil
            else { throw tabularFailure("invalid-styles") }
            customFormats[id] = format
        }
        if name == "xf", stack.dropLast().last == "cellXfs" {
            guard formatIDs.count < 65_536, let id = Int(attributes["numFmtId"] ?? "0") else {
                throw tabularFailure("invalid-styles")
            }
            formatIDs.append(id)
        }
    }
    override func end(_ name: String) throws {
        if name == "styleSheet" {
            for (index, id) in formatIDs.enumerated() {
                if (14...17).contains(id) {
                    dateStyles.insert(index)
                    continue
                }
                guard let raw = customFormats[id] else { continue }
                // Recognize only date-only formats. Quoted literals and bracket directives do not
                // contribute tokens; time-bearing or ambiguous formats remain raw numeric cells.
                var tokens = ""
                var quoted = false
                var bracket = false
                var escaped = false
                for scalar in raw.unicodeScalars {
                    if escaped {
                        escaped = false
                        continue
                    }
                    if scalar == "\\" {
                        escaped = true
                        continue
                    }
                    if scalar == "\"" {
                        quoted.toggle()
                        continue
                    }
                    if scalar == "[" {
                        bracket = true
                        continue
                    }
                    if scalar == "]" {
                        bracket = false
                        continue
                    }
                    if !quoted && !bracket { tokens.unicodeScalars.append(scalar) }
                }
                let format = tokens.lowercased()
                if format.contains("y"), format.contains("d"), !format.contains("h"),
                    !format.contains("s"), !format.contains("0"), !format.contains("#"),
                    !raw.lowercased().contains("[h"), !raw.lowercased().contains("[s"),
                    !raw.lowercased().contains("[m")
                {
                    dateStyles.insert(index)
                }
            }
        }
    }
}

private final class TabularRelationshipsXML: TabularXML {
    struct Relation {
        let path: String
        let type: String
    }
    var values: [String: Relation] = [:]
    override func start(_ name: String, attributes: [String: String]) throws {
        if stack.count == 1, name != "Relationships" { throw tabularFailure("invalid-workbook") }
        guard name == "Relationship" else { return }
        guard values.count < 2_048, let id = attributes["Id"], !id.isEmpty, values[id] == nil,
            let type = attributes["Type"], let target = attributes["Target"],
            attributes["TargetMode"] == nil || attributes["TargetMode"] == "Internal",
            !target.isEmpty, target.utf8.count <= 4_096, !target.contains("\\"),
            !target.contains(":"), !target.contains("?"), !target.contains("#"),
            !target.contains("%"), !target.unicodeScalars.contains(where: { $0.value < 32 })
        else { throw tabularFailure("invalid-relationship") }
        let path = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
        guard
            path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".."
            })
        else { throw tabularFailure("invalid-relationship") }
        values[id] = Relation(path: path, type: type)
    }
}

private final class TabularExternalRelationXML: TabularXML {
    override func start(_ name: String, attributes: [String: String]) throws {
        if name == "Relationship", let mode = attributes["TargetMode"], mode != "Internal" {
            throw tabularFailure("external-relationship", category: .unsupportedFormat)
        }
    }
}

private final class TabularStringsXML: TabularXML {
    var values: [String] = []
    private var current = ""
    private var totalBytes = 0
    override func start(_ name: String, attributes: [String: String]) throws {
        if stack.count == 1, name != "sst" { throw tabularFailure("invalid-workbook") }
        if name == "si" { current = "" }
    }
    override func characters(_ text: String) throws {
        guard stack.last == "t", stack.contains("si"), !stack.contains("rPh") else { return }
        let count = text.utf8.count
        guard count <= limits.maximumCellBytes - current.utf8.count,
            count <= 32 * 1_024 * 1_024 - totalBytes
        else { throw tabularLimit() }
        current += text
        totalBytes += count
    }
    override func end(_ name: String) throws {
        if name == "si" {
            guard values.count < limits.maximumCells else { throw tabularLimit() }
            values.append(current)
        }
    }
}

private final class TabularSheetXML: TabularXML {
    let shared: [String]
    let dateStyles: Set<Int>
    let uses1904Dates: Bool
    var rows: [GlifiTabularRow] = []
    private var cells: [String?] = []
    private var rowNumber = 0
    private var column = 0
    private var type = ""
    private var styleIndex = 0
    private var value = ""
    private var occupied = Set<Int>()
    private var cellCount = 0
    init(
        limits: GlifiTabularLimits, shared: [String], dateStyles: Set<Int>, uses1904Dates: Bool
    ) {
        self.shared = shared
        self.dateStyles = dateStyles
        self.uses1904Dates = uses1904Dates
        super.init(limits: limits)
    }
    override func start(_ name: String, attributes: [String: String]) throws {
        if stack.count == 1, name != "worksheet" { throw tabularFailure("invalid-workbook") }
        if name == "row", stack.dropLast().last == "sheetData" {
            guard let number = Int(attributes["r"] ?? ""), number > rowNumber,
                number <= 1_048_576, rows.count < limits.maximumRows
            else { throw tabularFailure("invalid-row") }
            rowNumber = number
            cells = []
            occupied = []
        }
        if name == "c", stack.dropLast().last == "row" {
            guard let reference = attributes["r"] else { throw tabularFailure("invalid-cell") }
            let location = try cellReference(reference)
            guard location.row == rowNumber, location.column <= limits.maximumColumns,
                occupied.insert(location.column).inserted, cellCount < limits.maximumCells
            else { throw tabularLimit() }
            cellCount += 1
            column = location.column
            type = attributes["t"] ?? "n"
            guard let style = Int(attributes["s"] ?? "0"), style >= 0 else {
                throw tabularFailure("invalid-styles")
            }
            styleIndex = style
            value = ""
            if cells.count < column {
                cells += [String?](repeating: nil, count: column - cells.count)
            }
        }
        if name == "f" {
            throw tabularFailure(
                "formula-not-supported", category: .unsupportedFormat, row: rowNumber)
        }
        if name == "mergeCell" {
            throw tabularFailure("merged-cells-not-supported", category: .unsupportedFormat)
        }
    }
    override func characters(_ text: String) throws {
        guard stack.contains("c"),
            stack.last == "v" || (stack.last == "t" && !stack.contains("rPh"))
        else { return }
        guard text.utf8.count <= limits.maximumCellBytes - value.utf8.count else {
            throw tabularLimit()
        }
        value += text
    }
    override func end(_ name: String) throws {
        if name == "c" {
            guard column > 0, column <= cells.count else { throw tabularFailure("invalid-cell") }
            switch type {
            case "s":
                guard let index = Int(value), shared.indices.contains(index) else {
                    throw tabularFailure("invalid-shared-string", row: rowNumber)
                }
                cells[column - 1] = shared[index]
            case "inlineStr", "str", "d": cells[column - 1] = value
            case "n":
                guard value.isEmpty || (Double(value)?.isFinite ?? false) else {
                    throw tabularFailure("invalid-numeric-cell", row: rowNumber)
                }
                cells[column - 1] =
                    value.isEmpty
                    ? nil
                    : (dateStyles.contains(styleIndex) ? try dateValue(value) : value)
            case "b":
                guard value == "0" || value == "1" else { throw tabularFailure("invalid-cell") }
                cells[column - 1] = value == "1" ? "true" : "false"
            case "e": throw tabularFailure("error-cell", row: rowNumber)
            default: throw tabularFailure("unsupported-cell-type", category: .unsupportedFormat)
            }
        }
        if name == "row" { rows.append(GlifiTabularRow(number: rowNumber, cells: cells)) }
    }
    private func cellReference(_ reference: String) throws -> (row: Int, column: Int) {
        guard reference.utf8.count <= 16 else { throw tabularFailure("invalid-cell") }
        var column = 0
        var digits = ""
        for byte in reference.utf8 {
            if (65...90).contains(byte), digits.isEmpty {
                guard column <= 16_384 else { throw tabularLimit() }
                column = column * 26 + Int(byte - 64)
            } else if (48...57).contains(byte) {
                digits.append(Character(UnicodeScalar(byte)))
            } else {
                throw tabularFailure("invalid-cell")
            }
        }
        guard column > 0, let row = Int(digits), row > 0 else {
            throw tabularFailure("invalid-cell")
        }
        return (row, column)
    }

    private func dateValue(_ value: String) throws -> String {
        guard let serial = Double(value), serial.isFinite, serial.rounded(.down) == serial,
            serial >= 0, serial <= 2_958_465, uses1904Dates || serial != 60
        else { throw tabularFailure("unsupported-excel-date", row: rowNumber) }
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(secondsFromGMT: 0) else {
            throw tabularFailure("invalid-calendar")
        }
        calendar.timeZone = zone
        let components =
            uses1904Dates
            ? DateComponents(year: 1904, month: 1, day: 1)
            : DateComponents(year: 1899, month: 12, day: 31)
        let correction = !uses1904Dates && serial > 60 ? 1 : 0
        guard let base = calendar.date(from: components),
            let date = calendar.date(byAdding: .day, value: Int(serial) - correction, to: base)
        else { throw tabularFailure("unsupported-excel-date", row: rowNumber) }
        let result = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = result.year, let month = result.month, let day = result.day,
            (1...9999).contains(year)
        else { throw tabularFailure("unsupported-excel-date", row: rowNumber) }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
