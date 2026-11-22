// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Captures static XHTML body text in the package's declared spine order, without rendering.
enum GlifiEPUBExtractor {
    static func extract(_ data: Data, limits: GlifiTextImportLimits) throws
        -> GlifiDocumentExtraction
    {
        try Task.checkCancellation()
        var archive = try GlifiZIPReader(data, limits: limits)
        guard let mimetype = archive.entry("mimetype"), mimetype.record.lowerBound == 0,
            mimetype.method == 0, mimetype.flags & 8 == 0, mimetype.localExtraCount == 0,
            try archive.read("mimetype") == Data("application/epub+zip".utf8)
        else { throw epubInvalid("epub.invalid-mimetype") }
        guard archive.entry("META-INF/rights.xml") == nil else {
            throw epubUnsupported("epub.encrypted-publication")
        }
        let container = EPUBContainerXML(maximumItems: limits.maximumArchiveEntryCount)
        try epubParse(archive.read("META-INF/container.xml"), delegate: container, limits: limits)
        guard container.rootfiles.count > 0,
            container.rootfiles.count <= limits.maximumArchiveEntryCount
        else {
            throw epubInvalid("epub.invalid-container")
        }
        var renditionPaths = Set<String>()
        for reference in container.rootfiles {
            let path = try epubResourcePath(reference, relativeTo: "")
            guard archive.entry(path) != nil, renditionPaths.insert(path).inserted else {
                throw epubInvalid("epub.invalid-container")
            }
        }
        let packagePath = try epubResourcePath(container.rootfiles[0], relativeTo: "")
        let package = EPUBPackageXML(
            maximumItems: limits.maximumArchiveEntryCount,
            maximumUnits: limits.maximumDocumentUnitCount)
        try epubParse(archive.read(packagePath), delegate: package, limits: limits)
        guard package.manifestCount == 1, package.spineCount == 1, !package.spine.isEmpty,
            package.hasLinearItem
        else { throw epubInvalid("epub.invalid-package") }
        var resources: [String: String] = [:]
        var usedPaths = Set<String>()
        for (id, item) in package.items {
            try Task.checkCancellation()
            let path = try epubResourcePath(item.href, relativeTo: packagePath)
            guard archive.entry(path) != nil, usedPaths.insert(path).inserted else {
                throw epubInvalid("epub.invalid-manifest")
            }
            resources[id] = path
        }
        var obfuscatedFontCount = 0
        if archive.entry("META-INF/encryption.xml") != nil {
            let encryption = EPUBEncryptionXML(maximumItems: limits.maximumArchiveEntryCount)
            try epubParse(
                archive.read("META-INF/encryption.xml"), delegate: encryption, limits: limits)
            guard !encryption.references.isEmpty else {
                throw epubInvalid("epub.invalid-encryption")
            }
            let spinePaths = Set(package.spine.compactMap { resources[$0] })
            let fontPaths = Set(
                package.items.compactMap { id, item in
                    EPUBEncryptionXML.fontMediaTypes.contains(item.mediaType) ? resources[id] : nil
                })
            var seen = Set<String>()
            for reference in encryption.references {
                let path = try epubResourcePath(reference, relativeTo: "")
                guard seen.insert(path).inserted, !spinePaths.contains(path),
                    fontPaths.contains(path)
                else { throw epubUnsupported("epub.encrypted-publication") }
                obfuscatedFontCount += 1
            }
        }
        var output = ""
        var outputBytes = 0
        var locations: [GlifiDocumentTextLocation] = []
        for id in package.spine {
            try Task.checkCancellation()
            guard let item = package.items[id], let path = resources[id] else {
                throw epubInvalid("epub.invalid-spine")
            }
            guard item.mediaType == "application/xhtml+xml" else {
                throw epubUnsupported("epub.unsupported-spine-media")
            }
            let chapter = EPUBTextXML(maximumBytes: limits.maximumExtractedByteCount - outputBytes)
            try epubParse(archive.read(path), delegate: chapter, limits: limits)
            guard chapter.bodyCount == 1 else { throw epubInvalid("epub.invalid-xhtml") }
            let text = chapter.text.result()
            guard !text.isEmpty else { continue }
            let separator = output.isEmpty ? 0 : 1
            let count = text.utf8.count
            guard separator <= limits.maximumExtractedByteCount - outputBytes,
                count <= limits.maximumExtractedByteCount - outputBytes - separator,
                locations.count < limits.maximumDocumentLocationCount
            else { throw epubLimit() }
            if separator > 0 {
                output.append("\n")
                outputBytes += 1
            }
            let start = outputBytes
            output.append(text)
            outputBytes += count
            locations.append(
                try GlifiDocumentTextLocation(
                    range: GlifiUTF8Range(start: start, end: outputBytes),
                    resourcePath: path, method: "epub-xhtml"))
        }
        guard !output.isEmpty else {
            throw documentImportFailure("epub.no-text", category: .insufficientData)
        }
        try Task.checkCancellation()
        var metadata = package.metadataValues
        metadata["documentUnitCount"] = String(package.spine.count)
        metadata["epubVersion"] = package.version
        metadata["packagePath"] = packagePath
        metadata["renditionCount"] = String(container.rootfiles.count)
        metadata["dcValueSeparator"] = "LF"
        if obfuscatedFontCount > 0 {
            metadata["obfuscatedFontCount"] = String(obfuscatedFontCount)
            metadata["obfuscatedFontPolicy"] = "not-rendered-not-deobfuscated"
        }
        return try GlifiDocumentExtraction(
            text: output, locations: locations, contractIdentifier: "epub-spine-xhtml-v1",
            backendIdentifier: "foundation-xml-zlib-v1",
            metadata: metadata)
    }
}

private func epubResourcePath(_ reference: String, relativeTo base: String) throws -> String {
    guard !reference.isEmpty, reference.utf8.count <= 4_096, !reference.hasPrefix("/"),
        !reference.contains(":"), !reference.contains("?"), !reference.contains("#"),
        let decoded = reference.removingPercentEncoding,
        !decoded.hasPrefix("/"), !decoded.contains(":"), !decoded.contains("\\"),
        !decoded.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw epubInvalid("epub.invalid-resource-path") }
    var components = base.split(separator: "/").dropLast().map(String.init)
    for component in decoded.split(separator: "/", omittingEmptySubsequences: false) {
        guard !component.isEmpty else { throw epubInvalid("epub.invalid-resource-path") }
        if component == "." { continue }
        if component == ".." {
            guard !components.isEmpty else { throw epubInvalid("epub.invalid-resource-path") }
            components.removeLast()
        } else {
            components.append(String(component))
        }
    }
    let result = components.joined(separator: "/")
    guard !result.isEmpty, result.utf8.count <= 4_096 else {
        throw epubInvalid("epub.invalid-resource-path")
    }
    return result
}

private class EPUBXML: NSObject, XMLParserDelegate {
    var stack: [(name: String, namespace: String)] = []
    var failure: Error?
    private var nodes = 0

    func start(_ name: String, namespace: String, attributes: [String: String]) throws {}
    func end(_ name: String, namespace: String) throws {}
    func characters(_ string: String) throws {}

    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
    ) {
        do {
            try Task.checkCancellation()
            guard stack.count < 128, nodes < 1_000_000 else { throw epubLimit() }
            guard attributes["xml:base"] == nil else {
                throw epubUnsupported("epub.unsupported-xml-base")
            }
            nodes += 1
            stack.append((name, namespaceURI ?? ""))
            try start(name, namespace: namespaceURI ?? "", attributes: attributes)
        } catch { stop(parser, error) }
    }

    func parser(
        _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
        qualifiedName: String?
    ) {
        do {
            guard stack.last?.name == name, stack.last?.namespace == (namespaceURI ?? "") else {
                throw epubInvalid("epub.invalid-xml")
            }
            try end(name, namespace: namespaceURI ?? "")
            stack.removeLast()
        } catch { stop(parser, error) }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        do {
            try Task.checkCancellation()
            try characters(string)
        } catch { stop(parser, error) }
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        guard let string = String(validating: data, as: UTF8.self) else {
            stop(parser, epubInvalid("epub.invalid-xml"))
            return
        }
        self.parser(parser, foundCharacters: string)
    }

    func parser(
        _ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?
    ) {
        stop(parser, epubInvalid("epub.xml-entity"))
    }

    func parser(
        _ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?,
        systemID: String?
    ) {
        stop(parser, epubInvalid("epub.xml-entity"))
    }

    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?)
        -> Data?
    {
        stop(parser, epubInvalid("epub.xml-entity"))
        return nil
    }

    private func stop(_ parser: XMLParser, _ error: Error) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }
}

private final class EPUBContainerXML: EPUBXML {
    var rootfiles: [String] = []
    private var roots = 0
    private let maximumItems: Int
    init(maximumItems: Int) { self.maximumItems = maximumItems }
    override func start(_ name: String, namespace: String, attributes: [String: String]) throws {
        let ns = "urn:oasis:names:tc:opendocument:xmlns:container"
        if stack.count == 1 {
            guard name == "container", namespace == ns, attributes["version"] == "1.0" else {
                throw epubInvalid("epub.invalid-container")
            }
        }
        if namespace == ns, name == "rootfiles" {
            guard stack.count == 2, roots == 0 else { throw epubInvalid("epub.invalid-container") }
            roots += 1
        }
        if namespace == ns, name == "rootfile" {
            guard stack.count == 3, stack[1].name == "rootfiles",
                let path = attributes["full-path"], !path.isEmpty,
                attributes["media-type"] == "application/oebps-package+xml"
            else { throw epubInvalid("epub.invalid-container") }
            guard rootfiles.count < maximumItems else { throw epubLimit() }
            rootfiles.append(path)
        }
    }
}

private final class EPUBPackageXML: EPUBXML {
    struct Item {
        let href: String
        let mediaType: String
    }
    var version = ""
    var items: [String: Item] = [:]
    var spine: [String] = []
    var manifestCount = 0
    var spineCount = 0
    var hasLinearItem = false
    var metadataValues: [String: String] = [:]
    private let maximumItems: Int
    private let maximumUnits: Int
    private var usedSpine = Set<String>()
    private var metadataField: String?
    private var metadataText = ""
    private var metadataTextBytes = 0

    init(maximumItems: Int, maximumUnits: Int) {
        self.maximumItems = maximumItems
        self.maximumUnits = maximumUnits
    }

    override func start(_ name: String, namespace: String, attributes: [String: String]) throws {
        let ns = "http://www.idpf.org/2007/opf"
        if stack.count == 1 {
            guard name == "package", namespace == ns, let value = attributes["version"] else {
                throw epubInvalid("epub.invalid-package")
            }
            guard value == "2.0" || value == "3.0" else {
                throw epubUnsupported("epub.unsupported-version")
            }
            version = value
        }
        if stack.count == 3, stack[1].name == "metadata", stack[1].namespace == ns,
            namespace == "http://purl.org/dc/elements/1.1/",
            ["title", "creator", "language", "identifier"].contains(name)
        {
            metadataField = name
            metadataText = ""
            metadataTextBytes = 0
        }
        guard namespace == ns else { return }
        if name == "manifest" {
            guard stack.count == 2, manifestCount == 0, spineCount == 0 else {
                throw epubInvalid("epub.invalid-manifest")
            }
            manifestCount += 1
        } else if name == "spine" {
            guard stack.count == 2, spineCount == 0, manifestCount == 1 else {
                throw epubInvalid("epub.invalid-spine")
            }
            spineCount += 1
        } else if name == "item" {
            guard stack.count == 3, stack[1].name == "manifest",
                let id = attributes["id"], !id.isEmpty, !id.contains(where: \.isWhitespace),
                let href = attributes["href"], !href.isEmpty,
                let type = attributes["media-type"], !type.isEmpty, items[id] == nil
            else { throw epubInvalid("epub.invalid-manifest") }
            guard items.count < maximumItems else { throw epubLimit() }
            items[id] = Item(href: href, mediaType: type)
        } else if name == "itemref" {
            guard stack.count == 3, stack[1].name == "spine", let id = attributes["idref"],
                !id.isEmpty, usedSpine.insert(id).inserted,
                attributes["linear"] == nil || attributes["linear"] == "yes"
                    || attributes["linear"] == "no"
            else { throw epubInvalid("epub.invalid-spine") }
            guard spine.count < maximumUnits else { throw epubLimit() }
            spine.append(id)
            if attributes["linear"] != "no" { hasLinearItem = true }
        }
    }

    override func characters(_ string: String) throws {
        guard metadataField != nil else { return }
        let count = string.utf8.count
        guard count <= 4_096 - metadataTextBytes else { throw epubLimit() }
        metadataText.append(string)
        metadataTextBytes += count
    }

    override func end(_ name: String, namespace: String) throws {
        guard stack.count == 3, metadataField == name,
            namespace == "http://purl.org/dc/elements/1.1/"
        else { return }
        let previous = metadataValues[name]
        let prefixBytes = previous.map { $0.utf8.count + 1 } ?? 0
        guard metadataTextBytes <= 4_096 - prefixBytes else { throw epubLimit() }
        metadataValues[name] = previous.map { $0 + "\n" + metadataText } ?? metadataText
        metadataField = nil
        metadataText = ""
        metadataTextBytes = 0
    }
}

/// Font obfuscation is metadata only for static text import: font bytes are never read.
private final class EPUBEncryptionXML: EPUBXML {
    static let fontMediaTypes: Set<String> = [
        "font/otf", "font/ttf", "font/woff", "font/woff2", "font/collection",
        "application/vnd.ms-opentype", "application/font-sfnt", "application/font-woff",
        "application/x-font-ttf", "application/x-font-opentype", "application/x-font-truetype",
    ]
    private static let algorithms: Set<String> = [
        "http://www.idpf.org/2008/embedding", "http://ns.adobe.com/pdf/enc#RC",
    ]
    var references: [String] = []
    private let maximumItems: Int
    private var algorithm: String?
    private var reference: String?
    private var active = false

    init(maximumItems: Int) { self.maximumItems = maximumItems }

    override func start(_ name: String, namespace: String, attributes: [String: String]) throws {
        let enc = "http://www.w3.org/2001/04/xmlenc#"
        if stack.count == 1 {
            guard name == "encryption",
                namespace == "urn:oasis:names:tc:opendocument:xmlns:container"
            else {
                throw epubInvalid("epub.invalid-encryption")
            }
        }
        guard namespace == enc else { return }
        if name == "EncryptedData" {
            guard stack.count == 2, !active else { throw epubInvalid("epub.invalid-encryption") }
            guard references.count < maximumItems else { throw epubLimit() }
            active = true
            algorithm = nil
            reference = nil
        } else if name == "EncryptionMethod" {
            guard active, stack.count == 3, algorithm == nil,
                let value = attributes["Algorithm"], Self.algorithms.contains(value)
            else { throw epubUnsupported("epub.encrypted-publication") }
            algorithm = value
        } else if name == "CipherReference" {
            guard active, stack.count == 4, stack[2].name == "CipherData",
                stack[2].namespace == enc, reference == nil,
                let value = attributes["URI"], !value.isEmpty
            else { throw epubInvalid("epub.invalid-encryption") }
            reference = value
        } else if name == "CipherValue" {
            throw epubUnsupported("epub.encrypted-publication")
        }
    }

    override func end(_ name: String, namespace: String) throws {
        if name == "EncryptedData", namespace == "http://www.w3.org/2001/04/xmlenc#" {
            guard active, algorithm != nil, let reference else {
                throw epubInvalid("epub.invalid-encryption")
            }
            references.append(reference)
            active = false
        }
    }
}

private struct EPUBText {
    var output = ""
    var byteCount = 0
    var pendingSpace = false
    var pendingBreak = false
    let maximumBytes: Int

    mutating func append(_ text: String, preserving: Bool) throws {
        for (index, scalar) in text.unicodeScalars.enumerated() {
            if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
            if !preserving, scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" {
                pendingSpace = !output.isEmpty && !pendingBreak && !output.hasSuffix("\n")
                continue
            }
            if pendingBreak {
                try add("\n")
                pendingBreak = false
                pendingSpace = false
            }
            if pendingSpace {
                try add(" ")
                pendingSpace = false
            }
            try add(String(scalar))
        }
    }

    mutating func boundary(_ newline: Bool) throws {
        pendingSpace = false
        guard !output.isEmpty else { return }
        if newline {
            if !output.hasSuffix("\n") { pendingBreak = true }
        } else if !pendingBreak, !output.hasSuffix("\n") {
            pendingSpace = true
        }
    }

    func result() -> String {
        output
    }

    private mutating func add(_ string: String) throws {
        let count = string.utf8.count
        guard count <= maximumBytes - byteCount else { throw epubLimit() }
        output.append(string)
        byteCount += count
    }
}

private final class EPUBTextXML: EPUBXML {
    var text: EPUBText
    var bodyCount = 0
    private var bodyDepth: Int?
    private var suppressed: [Int] = []
    private var preserveDepth: Int?
    private static let blocks: Set<String> = [
        "p", "div", "section", "article", "aside", "blockquote", "header", "footer",
        "h1", "h2", "h3", "h4", "h5", "h6", "li", "ul", "ol", "dl", "dt", "dd",
        "table", "tr", "figure", "figcaption", "address", "pre", "hr",
    ]

    init(maximumBytes: Int) { text = EPUBText(maximumBytes: maximumBytes) }

    override func start(_ name: String, namespace: String, attributes: [String: String]) throws {
        let xhtml = "http://www.w3.org/1999/xhtml"
        if stack.count == 1 {
            guard name == "html", namespace == xhtml else {
                throw epubInvalid("epub.invalid-xhtml")
            }
        }
        if name == "base", namespace == xhtml {
            throw epubUnsupported("epub.unsupported-xhtml-base")
        }
        if name == "body", namespace == xhtml {
            guard stack.count == 2, bodyCount == 0 else { throw epubInvalid("epub.invalid-xhtml") }
            bodyCount += 1
            bodyDepth = stack.count
        }
        guard bodyDepth != nil else { return }
        guard namespace == xhtml else { throw epubUnsupported("epub.unsupported-xhtml-content") }
        if name == "script" || name == "style" || attributes["hidden"] != nil {
            suppressed.append(stack.count)
        }
        guard suppressed.isEmpty else { return }
        if Self.blocks.contains(name) || name == "br" { try text.boundary(true) }
        if name == "td" || name == "th" { try text.boundary(false) }
        if preserveDepth == nil, name == "pre" || attributes["xml:space"] == "preserve" {
            preserveDepth = stack.count
        }
    }

    override func end(_ name: String, namespace: String) throws {
        let wasSuppressed = !suppressed.isEmpty
        if suppressed.last == stack.count { suppressed.removeLast() }
        if bodyDepth != nil, !wasSuppressed {
            if Self.blocks.contains(name) { try text.boundary(true) }
            if name == "td" || name == "th" { try text.boundary(false) }
        }
        if preserveDepth == stack.count { preserveDepth = nil }
        if bodyDepth == stack.count { bodyDepth = nil }
    }

    override func characters(_ string: String) throws {
        if bodyDepth != nil, suppressed.isEmpty {
            try text.append(string, preserving: preserveDepth != nil)
        }
    }
}

private func epubParse(_ data: Data, delegate: EPUBXML, limits: GlifiTextImportLimits) throws {
    try Task.checkCancellation()
    let prepared = try epubXMLBytes(
        data, maximumBytes: limits.maximumArchiveEntryByteCount,
        xhtmlEntities: delegate is EPUBTextXML)
    let parser = XMLParser(data: prepared)
    parser.shouldProcessNamespaces = true
    parser.shouldResolveExternalEntities = false
    parser.externalEntityResolvingPolicy = .never
    parser.delegate = delegate
    let parsed = parser.parse()
    if let error = delegate.failure { throw error }
    try Task.checkCancellation()
    guard parsed, delegate.stack.isEmpty else { throw epubInvalid("epub.invalid-xml") }
}

/// Removes only known XHTML external doctypes and resolves a closed entity set.
///
/// No DTD, external identifier or user-defined entity reaches XMLParser.
private func epubXMLBytes(_ data: Data, maximumBytes: Int, xhtmlEntities: Bool) throws -> Data {
    guard data.count <= maximumBytes else { throw epubLimit() }
    let bytes = Array(data)
    let source: String
    let sourceEncoding: String
    if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF])
        || bytes.starts(with: [0, 0x3C, 0, 0x3F]) || bytes.starts(with: [0x3C, 0, 0x3F, 0])
    {
        let little = bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0x3C, 0, 0x3F, 0])
        let skip = bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) ? 2 : 0
        guard (bytes.count - skip).isMultiple(of: 2) else { throw epubInvalid("epub.invalid-xml") }
        var units: [UInt16] = []
        units.reserveCapacity((bytes.count - skip) / 2)
        for offset in stride(from: skip, to: bytes.count, by: 2) {
            if offset.isMultiple(of: 4_096) { try Task.checkCancellation() }
            units.append(
                little
                    ? UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
                    : UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1]))
        }
        guard let decoded = String(validating: units, as: UTF16.self) else {
            throw epubInvalid("epub.invalid-xml")
        }
        source = decoded
        sourceEncoding = little ? "utf-16le" : "utf-16be"
    } else {
        let payload = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? bytes.dropFirst(3) : bytes[...]
        guard let decoded = String(validating: payload, as: UTF8.self) else {
            throw epubInvalid("epub.invalid-xml")
        }
        source = decoded
        sourceEncoding = "utf-8"
    }
    var result = ""
    var count = 0
    func append(_ value: String) throws {
        guard value.utf8.count <= maximumBytes * 2 - count else { throw epubLimit() }
        result.append(value)
        count += value.utf8.count
    }
    var cursor = source.startIndex
    let scalars = source.unicodeScalars
    func starts(_ marker: String) -> Bool { scalars[cursor...].starts(with: marker.unicodeScalars) }
    var steps = 0
    var sawRoot = false
    var sawDoctype = false
    while cursor < source.endIndex {
        if steps.isMultiple(of: 1_024) { try Task.checkCancellation() }
        steps += 1
        let tail = source[cursor...]
        if starts("<!--") || starts("<![CDATA[") {
            let marker = starts("<!--") ? "-->" : "]]>"
            guard let end = tail.range(of: marker, options: .literal) else {
                throw epubInvalid("epub.invalid-xml")
            }
            try append(String(source[cursor..<end.upperBound]))
            cursor = end.upperBound
        } else if starts("<?xml"),
            scalars[cursor...].dropFirst(5).first.map({
                $0 == " " || $0 == "\t" || $0 == "\r" || $0 == "\n"
            }) == true
        {
            guard cursor == source.startIndex, let end = tail.range(of: "?>", options: .literal)
            else {
                throw epubInvalid("epub.invalid-xml")
            }
            try epubDeclaration(String(source[cursor..<end.upperBound]), encoding: sourceEncoding)
            cursor = end.upperBound
        } else if starts("<?") {
            guard let end = tail.range(of: "?>", options: .literal) else {
                throw epubInvalid("epub.invalid-xml")
            }
            try append(String(source[cursor..<end.upperBound]))
            cursor = end.upperBound
        } else if starts("<!DOCTYPE") {
            guard let end = scalars[cursor...].firstIndex(of: ">") else {
                throw epubInvalid("epub.invalid-xml")
            }
            let after = scalars.index(after: end)
            let declaration = String(source[cursor..<after])
            guard xhtmlEntities, !sawRoot, !sawDoctype, epubKnownDoctype(declaration) else {
                throw epubInvalid("epub.xml-entity")
            }
            sawDoctype = true
            cursor = after
        } else if starts("<!ENTITY") || starts("<!ELEMENT") || starts("<!ATTLIST") {
            throw epubInvalid("epub.xml-entity")
        } else if scalars[cursor] == "&" {
            let nameStart = scalars.index(after: cursor)
            var semicolon = nameStart
            var scanned = 0
            while semicolon < source.endIndex, scalars[semicolon] != ";", scanned <= 32 {
                scanned += String(scalars[semicolon]).utf8.count
                semicolon = scalars.index(after: semicolon)
            }
            guard semicolon < source.endIndex, scanned <= 32, scalars[semicolon] == ";" else {
                throw epubInvalid("epub.xml-entity")
            }
            let name = String(source[nameStart..<semicolon])
            let after = scalars.index(after: semicolon)
            if name.hasPrefix("#") || ["amp", "lt", "gt", "quot", "apos"].contains(name) {
                try append(String(source[cursor..<after]))
            } else if xhtmlEntities, let code = EPUBEntities.values[name] {
                try append("&#\(code);")
            } else {
                throw epubInvalid("epub.xml-entity")
            }
            cursor = after
        } else {
            if scalars[cursor] == "<", !starts("<?") { sawRoot = true }
            try append(String(scalars[cursor]))
            cursor = scalars.index(after: cursor)
        }
    }
    return Data(result.utf8)
}

private func epubDeclaration(_ declaration: String, encoding: String) throws {
    guard declaration.utf8.count <= 1_024 else { throw epubLimit() }
    let pattern =
        #"\A<\?xml[ \t\r\n]+version[ \t\r\n]*=[ \t\r\n]*(['"])1\.0\1(?:[ \t\r\n]+encoding[ \t\r\n]*=[ \t\r\n]*(['"])([A-Za-z][A-Za-z0-9._-]*)\2)?(?:[ \t\r\n]+standalone[ \t\r\n]*=[ \t\r\n]*(['"])(?:yes|no)\4)?[ \t\r\n]*\?>\z"#
    let regex = try NSRegularExpression(pattern: pattern)
    guard
        let match = regex.firstMatch(
            in: declaration, range: NSRange(declaration.startIndex..., in: declaration))
    else {
        throw epubInvalid("epub.invalid-xml")
    }
    if let range = Range(match.range(at: 3), in: declaration) {
        let declared = declaration[range].lowercased()
        guard declared == encoding || (declared == "utf-16" && encoding.hasPrefix("utf-16")) else {
            throw epubUnsupported("epub.unsupported-xml-encoding")
        }
    }
}

private func epubXMLSpace(_ value: Character) -> Bool {
    value == " " || value == "\t" || value == "\r" || value == "\n"
}

private func epubKnownDoctype(_ declaration: String) -> Bool {
    guard declaration.utf8.count <= 1_024, !declaration.contains("["), !declaration.contains("]")
    else { return false }
    let inner = declaration.dropFirst(9).dropLast()
    var index = inner.startIndex
    var tokens: [String] = []
    var quoted: [Bool] = []
    while index < inner.endIndex {
        while index < inner.endIndex, epubXMLSpace(inner[index]) {
            index = inner.index(after: index)
        }
        if index == inner.endIndex { break }
        let quote = inner[index]
        if quote == "\"" || quote == "'" {
            index = inner.index(after: index)
            let start = index
            while index < inner.endIndex, inner[index] != quote {
                index = inner.index(after: index)
            }
            guard index < inner.endIndex else { return false }
            tokens.append(String(inner[start..<index]))
            quoted.append(true)
            index = inner.index(after: index)
        } else {
            let start = index
            while index < inner.endIndex, !epubXMLSpace(inner[index]) {
                index = inner.index(after: index)
            }
            tokens.append(String(inner[start..<index]))
            quoted.append(false)
        }
        guard tokens.count <= 4 else { return false }
        guard index == inner.endIndex || epubXMLSpace(inner[index]) else { return false }
    }
    if tokens == ["html"], quoted == [false] { return true }
    guard tokens.count == 4, tokens[0] == "html", tokens[1] == "PUBLIC",
        quoted == [false, false, true, true]
    else { return false }
    let known = [
        "-//W3C//DTD XHTML 1.0 Strict//EN": "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd",
        "-//W3C//DTD XHTML 1.0 Transitional//EN":
            "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd",
        "-//W3C//DTD XHTML 1.1//EN": "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd",
    ]
    return known[tokens[2]] == tokens[3]
}

/// Unicode assignments from the W3C XHTML/HTML 4 entity repertoire; no external DTD is read.
private enum EPUBEntities {
    static let values: [String: UInt32] = {
        let assignments = """
            nbsp=160 iexcl=161 cent=162 pound=163 curren=164 yen=165 brvbar=166 sect=167 uml=168 copy=169 ordf=170 laquo=171 not=172 shy=173 reg=174 macr=175 deg=176 plusmn=177 sup2=178 sup3=179 acute=180 micro=181 para=182 middot=183 cedil=184 sup1=185 ordm=186 raquo=187 frac14=188 frac12=189 frac34=190 iquest=191
            Agrave=192 Aacute=193 Acirc=194 Atilde=195 Auml=196 Aring=197 AElig=198 Ccedil=199 Egrave=200 Eacute=201 Ecirc=202 Euml=203 Igrave=204 Iacute=205 Icirc=206 Iuml=207 ETH=208 Ntilde=209 Ograve=210 Oacute=211 Ocirc=212 Otilde=213 Ouml=214 times=215 Oslash=216 Ugrave=217 Uacute=218 Ucirc=219 Uuml=220 Yacute=221 THORN=222 szlig=223
            agrave=224 aacute=225 acirc=226 atilde=227 auml=228 aring=229 aelig=230 ccedil=231 egrave=232 eacute=233 ecirc=234 euml=235 igrave=236 iacute=237 icirc=238 iuml=239 eth=240 ntilde=241 ograve=242 oacute=243 ocirc=244 otilde=245 ouml=246 divide=247 oslash=248 ugrave=249 uacute=250 ucirc=251 uuml=252 yacute=253 thorn=254 yuml=255
            OElig=338 oelig=339 Scaron=352 scaron=353 Yuml=376 fnof=402 circ=710 tilde=732
            Alpha=913 Beta=914 Gamma=915 Delta=916 Epsilon=917 Zeta=918 Eta=919 Theta=920 Iota=921 Kappa=922 Lambda=923 Mu=924 Nu=925 Xi=926 Omicron=927 Pi=928 Rho=929 Sigma=931 Tau=932 Upsilon=933 Phi=934 Chi=935 Psi=936 Omega=937
            alpha=945 beta=946 gamma=947 delta=948 epsilon=949 zeta=950 eta=951 theta=952 iota=953 kappa=954 lambda=955 mu=956 nu=957 xi=958 omicron=959 pi=960 rho=961 sigmaf=962 sigma=963 tau=964 upsilon=965 phi=966 chi=967 psi=968 omega=969 thetasym=977 upsih=978 piv=982
            ensp=8194 emsp=8195 thinsp=8201 zwnj=8204 zwj=8205 lrm=8206 rlm=8207 ndash=8211 mdash=8212 lsquo=8216 rsquo=8217 sbquo=8218 ldquo=8220 rdquo=8221 bdquo=8222 dagger=8224 Dagger=8225 bull=8226 hellip=8230 permil=8240 prime=8242 Prime=8243 lsaquo=8249 rsaquo=8250 oline=8254 frasl=8260 euro=8364
            image=8465 weierp=8472 real=8476 trade=8482 alefsym=8501 larr=8592 uarr=8593 rarr=8594 darr=8595 harr=8596 crarr=8629 lArr=8656 uArr=8657 rArr=8658 dArr=8659 hArr=8660
            forall=8704 part=8706 exist=8707 empty=8709 nabla=8711 isin=8712 notin=8713 ni=8715 prod=8719 sum=8721 minus=8722 lowast=8727 radic=8730 prop=8733 infin=8734 ang=8736 and=8743 or=8744 cap=8745 cup=8746 int=8747 there4=8756 sim=8764 cong=8773 asymp=8776 ne=8800 equiv=8801 le=8804 ge=8805 sub=8834 sup=8835 nsub=8836 sube=8838 supe=8839 oplus=8853 otimes=8855 perp=8869 sdot=8901
            lceil=8968 rceil=8969 lfloor=8970 rfloor=8971 lang=9001 rang=9002 loz=9674 spades=9824 clubs=9827 hearts=9829 diams=9830
            """
        return Dictionary(
            uniqueKeysWithValues: assignments.split(whereSeparator: \.isWhitespace).compactMap {
                item in
                let fields = item.split(separator: "=")
                guard fields.count == 2, let code = UInt32(fields[1]) else { return nil }
                return (String(fields[0]), code)
            })
    }()
}

private func epubInvalid(_ code: String) -> GlifiFailure { documentImportFailure(code) }
private func epubUnsupported(_ code: String) -> GlifiFailure {
    documentImportFailure(code, category: .unsupportedFormat)
}
private func epubLimit() -> GlifiFailure {
    documentImportFailure("epub.resource-limit", category: .insufficientResources)
}
