// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

struct GlifiTabularImportTests {
    @Test("CSV preserva Unicode, newline quotati, coordinate fisiche e valori tipizzati")
    func quotedCSVMappingAndCellProvenance() throws {
        let csv =
            "\u{FEFF}id;testo;eta;giorno;attivo\r\nuno;\"Città 😀\nseconda \"\"riga\"\"\";30;2024-02-29;true\r\ndue;Altro;NA;2025-01-01;0\r\n"
        let data = Data(csv.utf8)
        let table = try GlifiTabularImporter.preview(
            data: data, options: .init(delimiter: .semicolon))
        #expect(table.columns == ["id", "testo", "eta", "giorno", "attivo"])
        #expect(table.rows.map(\.number) == [2, 4])
        let mapped = try GlifiTabularImporter.map(
            table: table,
            mapping: .init(
                textColumns: [2], identifierColumn: 1,
                variables: [
                    .init(column: 3, name: "eta", type: .integer),
                    .init(column: 4, name: "giorno", type: .date),
                    .init(column: 5, name: "attivo", type: .boolean),
                ], missingValues: ["", "NA"]))
        #expect(mapped.records.count == 2)
        #expect(mapped.records[0].text == "Città 😀\nseconda \"riga\"")
        #expect(mapped.records[0].variables["eta"] == .integer(30))
        #expect(mapped.records[0].variables["giorno"] == .date("2024-02-29"))
        #expect(mapped.records[0].variables["attivo"] == .boolean(true))
        #expect(mapped.records[1].variables["eta"] == nil)
        #expect(mapped.records[1].origins["text:2"]?.row == 4)
        #expect(mapped.records[1].origins["variable:eta"]?.column == 3)
        #expect(mapped.records[1].origins["text:2"]?.sourceDigest == table.sourceDigest)
        #expect(mapped.records[0].textSegments[0].endUTF8 == mapped.records[0].text.utf8.count)
        #expect(mapped.sourceDigest == tabularDigest(data))
    }

    @Test("CSV rende espliciti duplicati, mancanti e righe scartate senza commit parziali")
    func duplicateAndInvalidRowPolicies() throws {
        let table = try GlifiTabularImporter.preview(
            data: Data("id,testo,n\na,Primo,1\na,Secondo,2\nb,,3\nc,Terzo,no\nd,Ultimo,4\n".utf8),
            options: .init())
        let mapping = GlifiTabularMapping(
            textColumns: [2], identifierColumn: 1,
            variables: [.init(column: 3, name: "n", type: .integer)],
            duplicatePolicy: .skip, invalidRowPolicy: .skip)
        let mapped = try GlifiTabularImporter.map(table: table, mapping: mapping)
        #expect(mapped.records.map(\.identifier) == ["a", "d"])
        #expect(mapped.issues.map(\.rowNumber) == [3, 4, 5])
        #expect(mapped.issues.count == 3)
        var reject = mapping
        reject.duplicatePolicy = .reject
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.map(table: table, mapping: reject)
        }
        var suffix = mapping
        suffix.duplicatePolicy = .appendRowNumber
        let suffixed = try GlifiTabularImporter.map(table: table, mapping: suffix)
        #expect(suffixed.records.map(\.identifier) == ["a", "a#r3", "d"])
    }

    @Test("CSV rifiuta sintassi malformata e supera i budget prima dell'allocazione")
    func malformedCSVAndResourceLimits() throws {
        for csv in ["a,b\n1,\"non chiuso", "a,b\n1,\"chiuso\"extra", "a,b\n1,no\"quote"] {
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.preview(data: Data(csv.utf8), options: .init())
            }
        }
        for options in [
            GlifiTabularOptions(limits: .init(maximumByteCount: 2)),
            .init(limits: .init(maximumColumns: 1)),
            .init(limits: .init(maximumRows: 1)),
            .init(limits: .init(maximumCells: 3)),
            .init(limits: .init(maximumCellBytes: 1)),
        ] {
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.preview(data: Data("a,b\n1,cc".utf8), options: options)
            }
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.preview(
                data: Data("a\n\"\"\"\"\"\"\"\"\"\"".utf8),
                options: .init(limits: .init(maximumCellBytes: 2)))
        }
    }

    @Test("Encoding espliciti non sostituiscono byte o surrogate malformati")
    func strictEncodings() throws {
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.preview(data: Data([0xFF, 0xFE, 0xFF]), options: .init())
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.preview(
                data: Data([0x00, 0xD8]), options: .init(encoding: .utf16LittleEndian))
        }
        for (encoding, foundation) in [
            (GlifiTabularEncoding.utf16LittleEndian, String.Encoding.utf16LittleEndian),
            (.utf16BigEndian, .utf16BigEndian), (.windows1252, .windowsCP1252),
        ] {
            let data = try #require("testo\nCittà".data(using: foundation))
            let table = try GlifiTabularImporter.preview(
                data: data, options: .init(encoding: encoding))
            #expect(table.rows[0].cells == ["Città"])
        }
    }

    @Test("Mapping valida forma, date gregoriane e numeri finiti senza interpretazioni locali")
    func strictMappingDomains() throws {
        let table = try GlifiTabularImporter.preview(
            data: Data("testo,n\nCittà,2023-02-29\n".utf8), options: .init())
        for mapping in [
            GlifiTabularMapping(textColumns: [0]), .init(textColumns: [1, 1]),
            .init(textColumns: [1], identifierColumn: 3),
            .init(textColumns: [1], variables: [.init(column: 2, name: "n", type: .date)]),
        ] {
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.map(table: table, mapping: mapping)
            }
        }
        for value in ["NaN", "inf", "1e999", "1,5", " 1", "0x1"] {
            let data = Data("testo;n\nCittà;\(value)".utf8)
            let numbers = try GlifiTabularImporter.preview(
                data: data, options: .init(delimiter: .semicolon))
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.map(
                    table: numbers,
                    mapping: .init(
                        textColumns: [1], variables: [.init(column: 2, name: "n", type: .decimal)]))
            }
        }
    }

    @Test("XLSX legge shared strings, rich text, celle sparse e fogli selezionati")
    func xlsxStringsSparseAndSheetSelection() throws {
        let table = try GlifiTabularImporter.preview(
            data: tabularWorkbook(), options: .init(format: .xlsx))
        #expect(table.sheetNames == ["Risposte", "Secondo"])
        #expect(table.selectedSheet == "Risposte")
        #expect(table.columns == ["id", "testo", "gruppo"])
        #expect(table.rows.map(\.number) == [4, 8])
        #expect(table.rows[0].cells == ["a", "Città 😀", nil])
        #expect(table.rows[1].cells == ["b", "Altro testo", "uno"])
        let mapped = try GlifiTabularImporter.map(
            table: table,
            mapping: .init(
                textColumns: [2], identifierColumn: 1,
                variables: [.init(column: 3, name: "gruppo")]))
        #expect(mapped.records[1].origins["text:2"]?.sheet == "Risposte")
        #expect(mapped.records[1].origins["text:2"]?.row == 8)
        #expect(mapped.records[0].variables["gruppo"] == nil)
        let second = try GlifiTabularImporter.preview(
            data: tabularWorkbook(), options: .init(format: .xlsx, sheetName: "Secondo"))
        #expect(second.rows[0].cells == ["Altra risposta"])
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.preview(
                data: tabularWorkbook(), options: .init(format: .xlsx, sheetName: "Assente"))
        }
    }

    @Test("XLSX rifiuta formule, riferimenti esterni, entità XML e celle oltre i limiti")
    func xlsxHostileInputs() throws {
        do {
            _ = try GlifiTabularImporter.preview(
                data: Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]),
                options: .init(format: .xlsx))
            Issue.record("Expected unsupported binary Excel container")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .unsupportedFormat)
            #expect(failure.code == "tabular.binary-excel-not-supported")
        }
        for sheet in [
            "<row r='1'><c r='A1'><f>1+2</f><v>3</v></c></row>",
            "<row r='1'><c r='XFD1'><v>1</v></c></row>",
            "<row r='1'><c r='A1' t='s'><v>999</v></c></row>",
            "<row r='1'><c r='A1' t='e'><v>#REF!</v></c></row>",
        ] {
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.preview(
                    data: tabularWorkbook(sheet: sheet), options: .init(format: .xlsx))
            }
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.preview(
                data: tabularWorkbook(target: "../../outside.xml"), options: .init(format: .xlsx))
        }
        #expect(throws: GlifiFailure.self) {
            try GlifiTabularImporter.preview(
                data: tabularWorkbook(
                    sheetXML:
                        "<!DOCTYPE worksheet [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><worksheet><sheetData><row r='1'><c r='A1' t='inlineStr'><is><t>&secret;</t></is></c></row></sheetData></worksheet>"
                ),
                options: .init(format: .xlsx))
        }
        let external =
            "<?xml version='1.0' encoding='UTF-16'?><!DOCTYPE worksheet [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><worksheet><sheetData><row r='1'><c r='A1' t='inlineStr'><is><t>&secret;</t></is></c></row></sheetData></worksheet>"
        for encoding in [String.Encoding.utf16LittleEndian, .utf16BigEndian] {
            let bytes = try #require(external.data(using: encoding))
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.preview(
                    data: tabularWorkbook(sheetBytes: bytes), options: .init(format: .xlsx))
            }
        }
    }

    @Test("XLSX converte date seriali dichiarate dagli stili senza accettare il 29 febbraio 1900")
    func xlsxExcelDates() throws {
        for (serial, uses1904Dates, expected) in [
            (1, false, "1900-01-01"),
            (61, false, "1900-03-01"), (0, true, "1904-01-01"),
        ] {
            let table = try GlifiTabularImporter.preview(
                data: tabularWorkbook(
                    sheet: "<row r='1'><c r='A1' s='1'><v>\(serial)</v></c></row>",
                    uses1904Dates: uses1904Dates),
                options: .init(format: .xlsx, hasHeaderRow: false))
            #expect(table.rows[0].cells == [expected])
        }
        for serial in ["60", "61.5", "-1", "1e10"] {
            #expect(throws: GlifiFailure.self) {
                try GlifiTabularImporter.preview(
                    data: tabularWorkbook(
                        sheet: "<row r='1'><c r='A1' s='1'><v>\(serial)</v></c></row>"),
                    options: .init(format: .xlsx))
            }
        }
    }

    @Test("La cancellazione interrompe il parsing prima di produrre risultati")
    func cancellation() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try GlifiTabularImporter.preview(
                data: Data("testo\nRisposta".utf8), options: .init())
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {}
    }
}

private func tabularWorkbook(
    sheet: String? = nil, target: String = "worksheets/sheet1.xml", sheetXML: String? = nil,
    uses1904Dates: Bool = false, sheetBytes: Data? = nil
) throws -> Data {
    let rows =
        sheet ?? """
            <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="inlineStr"><is><t>gruppo</t></is></c></row>
            <row r="4"><c r="A4" t="inlineStr"><is><t>a</t></is></c><c r="B4" t="s"><v>2</v></c></row>
            <row r="8"><c r="A8" t="inlineStr"><is><t>b</t></is></c><c r="B8" t="inlineStr"><is><t>Altro testo</t></is></c><c r="C8" t="inlineStr"><is><t>uno</t></is></c></row>
            """
    var entries: [EPUBFixtureEntry] = [
        .init("[Content_Types].xml", "<Types/>"),
        .init(
            "xl/workbook.xml",
            "<workbook xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'><workbookPr date1904='\(uses1904Dates ? "1" : "0")'/><sheets><sheet name='Risposte' r:id='r1'/><sheet name='Secondo' r:id='r2'/></sheets></workbook>"
        ),
        .init(
            "xl/_rels/workbook.xml.rels",
            "<Relationships><Relationship Id='r1' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet' Target='\(target)'/><Relationship Id='r2' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet' Target='worksheets/sheet2.xml'/><Relationship Id='s' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings' Target='sharedStrings.xml'/><Relationship Id='styles' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles' Target='styles.xml'/></Relationships>"
        ),
        .init(
            "xl/styles.xml",
            "<styleSheet><cellXfs><xf numFmtId='0'/><xf numFmtId='14'/></cellXfs></styleSheet>"),
        .init(
            "xl/sharedStrings.xml",
            "<sst><si><t>id</t></si><si><t>testo</t></si><si><r><t>Città </t></r><r><t>😀</t></r></si></sst>"
        ),
        .init(
            "xl/worksheets/sheet1.xml",
            sheetXML ?? "<worksheet><sheetData>\(rows)</sheetData></worksheet>"),
        .init(
            "xl/worksheets/sheet2.xml",
            "<worksheet><sheetData><row r='1'><c r='A1' t='inlineStr'><is><t>testo</t></is></c></row><row r='2'><c r='A2' t='inlineStr'><is><t>Altra risposta</t></is></c></row></sheetData></worksheet>"
        ),
    ]
    if let sheetBytes,
        let index = entries.firstIndex(where: { $0.path == "xl/worksheets/sheet1.xml" })
    {
        entries[index].bytes = sheetBytes
    }
    return try epubFixtureZIP(entries).data
}
