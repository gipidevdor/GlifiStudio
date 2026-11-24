// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test(
    "EPUB stored and DEFLATE archives preserve spine order, Unicode and chapter offsets",
    arguments: [UInt16(0), 8])
func epubImporterSpineUnicode(_ method: UInt16) throws {
    for reverse in [false, true] {
        var entries = epubFixtureBook(method: method)
        if method == 8 { entries[4].descriptor = true }
        let data = try epubFixtureZIP(entries, reversedDirectory: reverse).data
        let result = try GlifiEPUBExtractor.extract(data, limits: .standard)
        let first = "Secondo É\nDue"
        let second = "Primo é\u{00A0} mondo & 😀\nFine"
        #expect(result.text == first + "\n" + second)
        #expect(Array(result.text.utf8).contains(0xCC))
        #expect(result.locations.count == 2)
        #expect(
            result.locations.map(\.resourcePath) == ["OEBPS/text/b.xhtml", "OEBPS/text/a.xhtml"])
        #expect(result.locations[0].range == (try GlifiUTF8Range(start: 0, end: first.utf8.count)))
        #expect(
            result.locations[1].range
                == (try GlifiUTF8Range(start: first.utf8.count + 1, end: result.text.utf8.count)))
        #expect(result.locations.allSatisfy { $0.method == "epub-xhtml" && $0.pageNumber == nil })
        #expect(result.metadata["documentUnitCount"] == "2")
        #expect(result.contractIdentifier == "epub-spine-xhtml-v1")
        #expect(result.backendIdentifier == "foundation-xml-zlib-v1")
    }
}

@Test("EPUB 2 known XHTML entities and UTF-16 are parsed without external DTDs")
func epubImporterXHTML2EntitiesUTF16() throws {
    var entries = epubFixtureBook(version: "2.0")
    let xml = """
        <?xml version='1.0' encoding='UTF-16'?>
        <!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN' 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>
        <html xmlns="http://www.w3.org/1999/xhtml"><body><p>&Eacute;&nbsp;&mdash;&alpha;&ne;&hearts;</p><p><![CDATA[&nbsp; stays literal]]></p></body></html>
        """
    entries[4].bytes = Data([0xFF, 0xFE])
    for unit in xml.utf16 { entries[4].bytes.epub16(unit) }
    let result = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    #expect(result.text.hasPrefix("É\u{00A0}—α≠♥\n&nbsp; stays literal\n"))
    #expect(result.metadata["epubVersion"] == "2.0")
}

@Test("EPUB import reads the shared synthetic fixture without ZIP-order assumptions")
func epubImporterSharedFixture() throws {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    let data = try Data(
        contentsOf: root.appendingPathComponent("Fixtures/DocumentImport/v1/book.epub"))
    let result = try GlifiEPUBExtractor.extract(data, limits: .standard)
    #expect(result.locations.map(\.resourcePath) == ["Book/b.xhtml", "Book/a.xhtml"])
    #expect(result.text == "La casa e il mare.\nUna città.\nLa città e il giardino.")
    #expect(result.metadata["documentUnitCount"] == "2")
    #expect(result.metadata["title"] == "Libro sintetico")
    #expect(result.metadata["language"] == "it")
    #expect(result.metadata["identifier"] == "synthetic-glifi-book")
}

@Test(
    "EPUB entities followed by combining marks preserve scalar-exact NFD text",
    arguments: ["&#x65;\u{0301}", "&amp;\u{0301}"])
func epubImporterScalarEntityMarks(_ reference: String) throws {
    var entries = epubFixtureBook()
    entries[4].bytes = Data(
        ("<html xmlns='http://www.w3.org/1999/xhtml'><body><p>" + reference + "</p></body></html>")
            .utf8)
    let result = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    let expected = reference.hasPrefix("&#") ? "e\u{0301}" : "&\u{0301}"
    #expect(result.text.utf8.starts(with: expected.utf8))
}

@Test(
    "EPUB canonical byte limits exclude a final structural LF and include real chapter separators")
func epubImporterExactCanonicalBudget() throws {
    var entries = epubFixtureBook()
    entries[4].bytes = Data("<html xmlns='http://www.w3.org/1999/xhtml'><body/></html>".utf8)
    entries[3].bytes = Data(
        "<html xmlns='http://www.w3.org/1999/xhtml'><body><p>x</p></body></html>".utf8)
    let data = try epubFixtureZIP(entries).data
    #expect(
        try GlifiEPUBExtractor.extract(
            data, limits: .init(maximumByteCount: data.count, maximumExtractedByteCount: 1)
        ).text == "x")
    try epubExpectFailure(category: .insufficientResources) {
        _ = try GlifiEPUBExtractor.extract(
            data, limits: .init(maximumByteCount: data.count, maximumExtractedByteCount: 0))
    }
    entries[4].bytes = Data(
        "<html xmlns='http://www.w3.org/1999/xhtml'><body><p>y</p></body></html>".utf8)
    let two = try epubFixtureZIP(entries).data
    #expect(
        try GlifiEPUBExtractor.extract(
            two, limits: .init(maximumByteCount: two.count, maximumExtractedByteCount: 3)
        ).text == "y\nx")
    try epubExpectFailure(category: .insufficientResources) {
        _ = try GlifiEPUBExtractor.extract(
            two, limits: .init(maximumByteCount: two.count, maximumExtractedByteCount: 2))
    }
}

@Test("EPUB captures bounded Dublin Core metadata without Unicode normalization")
func epubImporterDublinCoreMetadata() throws {
    var entries = epubFixtureBook()
    let xml = String(decoding: entries[2].bytes, as: UTF8.self)
    let metadata =
        "<metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:title>Titolo é</dc:title><dc:creator>Prima É</dc:creator><dc:creator>Seconda é</dc:creator><dc:language>it</dc:language><dc:identifier>urn:example:book</dc:identifier></metadata>"
    entries[2].bytes = Data(xml.replacingOccurrences(of: "<metadata/>", with: metadata).utf8)
    let result = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    #expect(result.metadata["title"]?.utf8.elementsEqual("Titolo é".utf8) == true)
    #expect(result.metadata["creator"]?.utf8.elementsEqual("Prima É\nSeconda é".utf8) == true)
    #expect(result.metadata["language"] == "it")
    #expect(result.metadata["identifier"] == "urn:example:book")
    for oversized in [
        "<dc:title>" + String(repeating: "x", count: 4_097) + "</dc:title>",
        "<dc:creator>" + String(repeating: "x", count: 4_096)
            + "</dc:creator><dc:creator>x</dc:creator>",
    ] {
        var large = entries
        large[2].bytes = Data(
            xml.replacingOccurrences(
                of: "<metadata/>",
                with: "<metadata xmlns:dc='http://purl.org/dc/elements/1.1/'>" + oversized
                    + "</metadata>"
            ).utf8)
        try epubExpectFailure(category: .insufficientResources) {
            _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(large).data, limits: .standard)
        }
    }
}

@Test(
    "EPUB skips declared font obfuscation without reading font payloads",
    arguments: ["http://www.idpf.org/2008/embedding", "http://ns.adobe.com/pdf/enc#RC"])
func epubImporterFontObfuscation(_ algorithm: String) throws {
    var entries = epubFixtureBook()
    entries[2].bytes = Data(
        String(decoding: entries[2].bytes, as: UTF8.self).replacingOccurrences(
            of: "</manifest>",
            with: "<item id='font' href='fonts/f.otf' media-type='font/otf'/></manifest>"
        ).utf8)
    var font = EPUBFixtureEntry("OEBPS/fonts/f.otf", "OTTO-synthetic-opaque-font")
    // A mismatching unread-font CRC proves that text import never inflates or deobfuscates fonts.
    font.crcOverride = 123
    entries.append(font)
    entries.append(
        EPUBFixtureEntry(
            "META-INF/encryption.xml",
            epubFixtureEncryption(algorithm: algorithm, path: "OEBPS/fonts/f.otf")))
    let result = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    #expect(result.text.hasPrefix("Secondo É\nDue\n"))
    #expect(result.metadata["obfuscatedFontCount"] == "1")
    #expect(result.metadata["obfuscatedFontPolicy"] == "not-rendered-not-deobfuscated")
    for (method, path) in [
        ("urn:unsupported:encryption", "OEBPS/fonts/f.otf"), (algorithm, "OEBPS/text/b.xhtml"),
    ] {
        var hostile = entries
        hostile[hostile.count - 1].bytes = Data(
            epubFixtureEncryption(algorithm: method, path: path).utf8)
        try epubExpectFailure(category: .unsupportedFormat) {
            _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(hostile).data, limits: .standard)
        }
    }
}

@Test("EPUB keeps preformatted whitespace and ignores hidden content and processing instructions")
func epubImporterXMLLexicalBoundaries() throws {
    var entries = epubFixtureBook()
    entries[4].bytes = Data(
        """
        <?xml
        version='1.0' encoding='UTF-8' standalone='yes'?>
        <?note &unknown; <!DOCTYPE html>?>
        <html xmlns='http://www.w3.org/1999/xhtml'><body>A<div hidden='hidden'>ignored</div>B<pre> X
          Y </pre><p>Fine</p></body></html>
        """.utf8)
    let result = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    #expect(result.text.hasPrefix("AB\n X\n  Y \nFine\n"))
}

@Test("EPUB counts empty spine resources without inventing chapter text")
func epubImporterEmptyUnits() throws {
    var entries = epubFixtureBook()
    entries[4].bytes = Data("<html xmlns='http://www.w3.org/1999/xhtml'><body/></html>".utf8)
    let result = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    #expect(result.locations.count == 1)
    #expect(result.metadata["documentUnitCount"] == "2")
    #expect(result.locations[0].range.start == 0)
    entries[3].bytes = entries[4].bytes
    do {
        _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
        Issue.record("Blank books must not invent text")
    } catch let failure as GlifiFailure { #expect(failure.category == .insufficientData) }
}

@Test("ZIP refuses traversal, aliases, links and encrypted or unsupported members")
func epubImporterHostileZIP() throws {
    for path in ["../evil", "/evil", "a//b", "a/./b", "a/../b", "a\\b", "C:/evil", "a\0b"] {
        try epubExpectFailure {
            _ = try GlifiZIPReader(
                epubFixtureZIP([EPUBFixtureEntry(path, "x")]).data, limits: .standard)
        }
    }
    for names in [["same", "same"], ["Same", "same"], ["café", "café"]] {
        try epubExpectFailure {
            _ = try GlifiZIPReader(
                epubFixtureZIP(names.map { EPUBFixtureEntry($0, "x") }).data, limits: .standard)
        }
    }
    var link = EPUBFixtureEntry("link", "target")
    link.attributes = 0o120777 << 16
    try epubExpectFailure { _ = try GlifiZIPReader(epubFixtureZIP([link]).data, limits: .standard) }
    var encrypted = EPUBFixtureEntry("secret", "x")
    encrypted.flags |= 1
    try epubExpectFailure(category: .unsupportedFormat) {
        _ = try GlifiZIPReader(epubFixtureZIP([encrypted]).data, limits: .standard)
    }
    try epubExpectFailure(category: .unsupportedFormat) {
        _ = try GlifiZIPReader(
            epubFixtureZIP([EPUBFixtureEntry("bzip", "x", method: 12)]).data, limits: .standard)
    }
}

@Test("ZIP validates local/central agreement, checksums, lengths and complete DEFLATE consumption")
func epubImporterZIPIntegrity() throws {
    var mismatch = try epubFixtureZIP([EPUBFixtureEntry("file", "payload")])
    mismatch.data[mismatch.centrals[0] + 16] ^= 1
    try epubExpectFailure { _ = try GlifiZIPReader(mismatch.data, limits: .standard) }
    for method in [UInt16(0), 8] {
        var bad = EPUBFixtureEntry("file", "payload", method: method)
        bad.crcOverride = 123
        var reader = try GlifiZIPReader(epubFixtureZIP([bad]).data, limits: .standard)
        try epubExpectFailure { _ = try reader.read("file") }
    }
    let valid = try epubFixtureZIP([
        EPUBFixtureEntry("file", String(repeating: "x", count: 4_096), method: 8)
    ])
    for expanded in [4_095, 4_097] {
        var bad = valid.data
        bad.epubReplace32(valid.locals[0] + 22, UInt32(expanded))
        bad.epubReplace32(valid.centrals[0] + 24, UInt32(expanded))
        var reader = try GlifiZIPReader(bad, limits: .standard)
        try epubExpectFailure { _ = try reader.read("file") }
    }
    var trailing = valid.data
    // A stored DEFLATE block ending early is rejected even when all advertised sizes agree.
    trailing[valid.payloads[0]] = 0xFF
    var broken = try GlifiZIPReader(trailing, limits: .standard)
    try epubExpectFailure { _ = try broken.read("file") }
    var extended = EPUBFixtureEntry("file", String(repeating: "x", count: 4_096), method: 8)
    extended.compressedOverride = valid.data.subdata(in: valid.payloads[0]..<valid.centralStart)
    extended.compressedOverride?.append(0)
    var extraStreamBytes = try GlifiZIPReader(epubFixtureZIP([extended]).data, limits: .standard)
    try epubExpectFailure { _ = try extraStreamBytes.read("file") }
    for data in [Data(), Data(valid.data.dropLast()), Data(valid.data.prefix(22))] {
        try epubExpectFailure { _ = try GlifiZIPReader(data, limits: .standard) }
    }
}

@Test("ZIP detects overlapping local records, including a header nested inside another payload")
func epubImporterZIPOverlap() throws {
    let member = EPUBFixtureEntry("b", "overlap")
    let inner = try epubFixtureZIP([member])
    var outerMember = EPUBFixtureEntry("a", "")
    outerMember.bytes = inner.data.prefix(inner.centralStart)
    var outer = try epubFixtureZIP([outerMember, member])
    outer.data.epubReplace32(outer.centrals[1] + 42, UInt32(outer.payloads[0]))
    try epubExpectFailure { _ = try GlifiZIPReader(outer.data, limits: .standard) }
}

@Test("EPUB rejects malformed package/spine, nontext spine, DRM and external XML")
func epubImporterPackageAndXMLFailures() throws {
    let valid = epubFixtureBook()
    let xml = String(decoding: valid[2].bytes, as: UTF8.self)
    for malformed in [
        xml.replacingOccurrences(of: "idref=\"b\"", with: "idref=\"missing\""),
        xml.replacingOccurrences(of: "idref=\"a\"", with: "idref=\"b\""),
        xml.replacingOccurrences(of: "id=\"b\"", with: "id=\"a\""),
        xml.replacingOccurrences(of: "href=\"text/b.xhtml\"", with: "href=\"../../outside\""),
        xml.replacingOccurrences(of: "<manifest>", with: "<manifest xml:base=\"http://invalid/\">"),
        "<package xmlns='http://www.idpf.org/2007/opf' version='3.0'><manifest/></package>",
    ] {
        var entries = valid
        entries[2].bytes = Data(malformed.utf8)
        try epubExpectFailure {
            _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
        }
    }
    var media = valid
    media[2].bytes = Data(
        xml.replacingOccurrences(of: "application/xhtml+xml", with: "image/svg+xml").utf8)
    try epubExpectFailure(category: .unsupportedFormat) {
        _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(media).data, limits: .standard)
    }
    var drm = valid
    drm.append(
        EPUBFixtureEntry(
            "META-INF/encryption.xml",
            epubFixtureEncryption(
                algorithm: "http://www.w3.org/2001/04/xmlenc#aes128-cbc", path: "OEBPS/text/a.xhtml"
            )))
    try epubExpectFailure(category: .unsupportedFormat) {
        _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(drm).data, limits: .standard)
    }
    for hostile in [
        "<!DOCTYPE html [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><html xmlns='http://www.w3.org/1999/xhtml'><body>&x;</body></html>",
        "<!DOCTYPE html SYSTEM 'https://invalid.invalid/a.dtd'><html xmlns='http://www.w3.org/1999/xhtml'><body>x</body></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body>&unknown;</body></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body><p>unclosed</body></html>",
        "<?xml version='1.0' extra='UTF-8'?><html xmlns='http://www.w3.org/1999/xhtml'><body>x</body></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body><!DOCTYPE html>x</body></html>",
        "<!DOCTYPE html><!DOCTYPE html><html xmlns='http://www.w3.org/1999/xhtml'><body>x</body></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body>" + String(repeating: "&", count: 20_000)
            + "</body></html>",
    ] {
        var entries = valid
        entries[4].bytes = Data(hostile.utf8)
        try epubExpectFailure {
            _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
        }
    }
}

@Test("EPUB enforces source, archive, expanded, unit, location, XML-depth and text budgets")
func epubImporterBudgets() throws {
    let bytes = try epubFixtureZIP(epubFixtureBook()).data
    for limits in [
        GlifiTextImportLimits(maximumByteCount: 10),
        .init(maximumByteCount: bytes.count, maximumArchiveEntryCount: 4),
        .init(maximumByteCount: bytes.count, maximumExpandedArchiveByteCount: 100),
        .init(maximumByteCount: bytes.count, maximumArchiveEntryByteCount: 100),
        .init(maximumByteCount: bytes.count, maximumDocumentUnitCount: 1),
        .init(maximumByteCount: bytes.count, maximumDocumentLocationCount: 1),
        .init(maximumByteCount: bytes.count, maximumExtractedByteCount: 5),
    ] {
        try epubExpectFailure(category: .insufficientResources) {
            _ = try GlifiEPUBExtractor.extract(bytes, limits: limits)
        }
    }
    var entries = epubFixtureBook()
    entries[4].bytes = Data(
        ("<html xmlns='http://www.w3.org/1999/xhtml'><body>"
            + String(repeating: "<div>", count: 130) + "x" + String(repeating: "</div>", count: 130)
            + "</body></html>").utf8)
    try epubExpectFailure(category: .insufficientResources) {
        _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
    }
    var reader = try GlifiZIPReader(
        epubFixtureZIP([EPUBFixtureEntry("file", "1234567890")]).data,
        limits: .init(maximumByteCount: 10_000, maximumExpandedArchiveByteCount: 10))
    #expect(try reader.read("file") == Data("1234567890".utf8))
    try epubExpectFailure(category: .insufficientResources) { _ = try reader.read("file") }
}

@Test("EPUB refuses the wrong mimetype and honors cancellation before ZIP/XML work")
func epubImporterMimetypeAndCancellation() async throws {
    for mutation in 0..<3 {
        var entries = epubFixtureBook()
        switch mutation {
        case 0: entries[0].method = 8
        case 1: entries[0].bytes.append(0x20)
        case 2: entries.swapAt(0, 1)
        default: break
        }
        try epubExpectFailure {
            _ = try GlifiEPUBExtractor.extract(epubFixtureZIP(entries).data, limits: .standard)
        }
    }
    let data = try epubFixtureZIP(epubFixtureBook(method: 8)).data
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiEPUBExtractor.extract(data, limits: .standard)
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

private func epubFixtureEncryption(algorithm: String, path: String) -> String {
    "<encryption xmlns='urn:oasis:names:tc:opendocument:xmlns:container' xmlns:enc='http://www.w3.org/2001/04/xmlenc#'><enc:EncryptedData><enc:EncryptionMethod Algorithm='\(algorithm)'/><enc:CipherData><enc:CipherReference URI='\(path)'/></enc:CipherData></enc:EncryptedData></encryption>"
}

private func epubExpectFailure(category: GlifiFailureCategory? = nil, _ body: () throws -> Void)
    throws
{
    do {
        try body()
        Issue.record("An invalid EPUB/ZIP was accepted")
    } catch let failure as GlifiFailure {
        if let category { #expect(failure.category == category) }
        #expect(failure.operation == .importText)
        #expect(failure.retainedState == .unchanged)
    }
}
