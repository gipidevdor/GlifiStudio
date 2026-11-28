// SPDX-License-Identifier: BSD-3-Clause

import CoreGraphics
import CoreText
import Foundation
import zlib

struct GlifiScientificExportPayload: Sendable {
    let path: String
    let mediaType: String
    let schema: String
    let data: Data
}

enum GlifiScientificExportRenderer {
    static func csvPayloads(_ report: GlifiReportRevision) throws
        -> [GlifiScientificExportPayload]
    {
        let findingsHeader = [
            "ordinal", "finding_id", "message_key", "evidence_ids", "caveat_ids",
            "payload_json",
        ]
        let findingRows = try report.findings.enumerated().map { index, finding in
            [
                String(index + 1),
                finding.id.canonicalValue,
                finding.messageKey,
                finding.evidenceReferences.map(\.evidenceID.canonicalValue).joined(separator: "|"),
                finding.caveats.map(\.identifier).joined(separator: "|"),
                try canonicalJSONString(finding),
            ]
        }

        let evidenceHeader = [
            "ordinal", "evidence_id", "kind", "finding_ids", "artifact_ids", "caveat_ids",
            "payload_json",
        ]
        var findingIDsByEvidence: [EvidenceID: [String]] = [:]
        findingIDsByEvidence.reserveCapacity(report.evidence.count)
        for finding in report.findings {
            guard !finding.evidenceReferences.isEmpty else { continue }
            let findingID = finding.id.canonicalValue
            var referencedEvidence: Set<EvidenceID> = []
            for reference in finding.evidenceReferences
            where referencedEvidence.insert(reference.evidenceID).inserted {
                findingIDsByEvidence[reference.evidenceID, default: []].append(findingID)
            }
        }
        let evidenceRows = try report.evidence.enumerated().map { index, evidence in
            let findingIDs = findingIDsByEvidence[evidence.id] ?? []
            return [
                String(index + 1),
                evidence.id.canonicalValue,
                evidence.kindIdentifier,
                findingIDs.joined(separator: "|"),
                evidence.artifactIDs.map(\.canonicalValue).joined(separator: "|"),
                evidence.caveats.map(\.identifier).joined(separator: "|"),
                try canonicalJSONString(evidence),
            ]
        }

        return [
            GlifiScientificExportPayload(
                path: "findings.csv",
                mediaType: "text/csv; charset=utf-8; header=present",
                schema: "studio.glifi.report-findings-csv.v1",
                data: csvData(header: findingsHeader, rows: findingRows)
            ),
            GlifiScientificExportPayload(
                path: "evidence.csv",
                mediaType: "text/csv; charset=utf-8; header=present",
                schema: "studio.glifi.report-evidence-csv.v1",
                data: csvData(header: evidenceHeader, rows: evidenceRows)
            ),
        ]
    }

    static func pdfPayload(
        _ report: GlifiReportRevision,
        localeIdentifier: String,
        createdAt: Date
    ) throws -> GlifiScientificExportPayload {
        let document = PDFDocumentModel(
            report: report,
            localeIdentifier: localeIdentifier,
            createdAt: createdAt
        )
        return GlifiScientificExportPayload(
            path: "report.pdf",
            mediaType: "application/pdf",
            schema: "studio.glifi.report-pdf-a2u.v1",
            data: try renderPDF(document)
        )
    }

    static func validatePDF(_ data: Data) throws {
        guard let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider),
            !document.isEncrypted,
            (1...512).contains(document.numberOfPages),
            let catalog = document.catalog
        else {
            throw rendererFailure("export.pdf-invalid")
        }
        var structureTree: CGPDFDictionaryRef?
        var markInfo: CGPDFDictionaryRef?
        var metadataStream: CGPDFStreamRef?
        var metadataFormat = CGPDFDataFormat.raw
        var isMarked: CGPDFBoolean = 0
        guard CGPDFDictionaryGetDictionary(catalog, "StructTreeRoot", &structureTree),
            structureTree != nil,
            CGPDFDictionaryGetDictionary(catalog, "MarkInfo", &markInfo),
            let markInfo,
            CGPDFDictionaryGetBoolean(markInfo, "Marked", &isMarked),
            isMarked != 0,
            CGPDFDictionaryGetStream(catalog, "Metadata", &metadataStream),
            let metadataStream,
            let metadata = CGPDFStreamCopyData(metadataStream, &metadataFormat) as Data?,
            let metadataXML = String(data: metadata, encoding: .utf8),
            metadataXML.contains("<pdfaid:part>2</pdfaid:part>"),
            metadataXML.contains("<pdfaid:conformance>U</pdfaid:conformance>")
        else {
            throw rendererFailure("export.pdf-nonconforming")
        }
    }

    private static func canonicalJSONString(_ value: some Encodable) throws -> String {
        String(decoding: try GlifiExportCanonicalJSON.encode(value), as: UTF8.self)
    }

    private static func csvData(header: [String], rows: [[String]]) -> Data {
        let lines = ([header] + rows).map { row in
            row.map(csvCell).joined(separator: ",")
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func csvCell(_ rawValue: String) -> String {
        let value: String
        if let first = rawValue.first, "=+-@".contains(first) || first == "\t" || first == "\r" {
            value = "'" + rawValue
        } else {
            value = rawValue
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

private extension GlifiScientificExportRenderer {
    struct PDFDocumentModel {
        let title: String
        let languageCode: String
        let subject: String
        let createdAtString: String
        let blocks: [PDFBlock]

        init(report: GlifiReportRevision, localeIdentifier: String, createdAt: Date) {
            let italian = localeIdentifier.lowercased().hasPrefix("it")
            title = italian ? "Relazione di indagine" : "Investigation report"
            languageCode = italian ? "it" : "en"
            subject =
                italian
                ? "Relazione scientifica verificabile di Glifi Studio"
                : "Verifiable scientific report from Glifi Studio"
            createdAtString = ISO8601DateFormatter().string(from: createdAt)

            var values = [
                PDFBlock(text: title, style: .title, tag: .header1),
                PDFBlock(text: italian ? "Domanda" : "Question", style: .heading, tag: .header2),
                PDFBlock(text: report.question, style: .body, tag: .paragraph),
                PDFBlock(
                    text: italian ? "Risultati selezionati" : "Selected findings",
                    style: .heading,
                    tag: .header2
                ),
            ]
            if report.findings.isEmpty {
                values.append(
                    PDFBlock(
                        text: italian
                            ? "Nessun risultato positivo selezionato."
                            : "No positive finding selected.",
                        style: .body,
                        tag: .paragraph
                    )
                )
            } else {
                values += report.findings.enumerated().map { index, finding in
                    PDFBlock(
                        text:
                            "\(index + 1). \(GlifiSavedResearchReport.findingText(finding, italian: italian))\n\(displayIdentifier(finding.id.canonicalValue))",
                        style: .listItem,
                        tag: .listItem
                    )
                }
            }
            values.append(
                PDFBlock(text: italian ? "Evidenze" : "Evidence", style: .heading, tag: .header2)
            )
            if report.evidence.isEmpty {
                values.append(PDFBlock(text: "-", style: .body, tag: .paragraph))
            } else {
                values += report.evidence.enumerated().map { index, evidence in
                    PDFBlock(
                        text:
                            "\(index + 1). \(evidence.kindIdentifier)\n\(displayIdentifier(evidence.id.canonicalValue))",
                        style: .listItem,
                        tag: .listItem
                    )
                }
            }

            let caveats = canonicalCaveats(report)
            values.append(
                PDFBlock(text: italian ? "Limiti" : "Caveats", style: .heading, tag: .header2)
            )
            if caveats.isEmpty {
                values.append(PDFBlock(text: "-", style: .body, tag: .paragraph))
            } else {
                values += caveats.map { caveat in
                    PDFBlock(
                        text:
                            "\(GlifiSavedResearchReport.caveatText(caveat, italian: italian)) | \(caveat.scope.rawValue) | \(caveat.severity.rawValue)\n"
                            + "\(italian ? "Origine" : "Origin"): \(displayIdentifier(caveat.originIdentifier))",
                        style: .listItem,
                        tag: .listItem
                    )
                }
            }

            values += [
                PDFBlock(
                    text: italian ? "Tracciabilità" : "Traceability",
                    style: .heading,
                    tag: .header2
                ),
                PDFBlock(
                    text: [
                        "Report: \(report.id.canonicalValue)",
                        "Investigation: \(report.investigationID.canonicalValue)",
                        "Head: \(report.investigationHeadEventID.canonicalValue)",
                        "Interpretation: \(report.interpretationArtifactID.canonicalValue)",
                        "Created: \(createdAtString)",
                    ].joined(separator: "\n"),
                    style: .code,
                    tag: .code
                ),
            ]
            blocks = values
        }
    }

    struct PDFBlock {
        enum Style {
            case title
            case heading
            case body
            case listItem
            case code
        }

        let text: String
        let style: Style
        let tag: CGPDFTagType
    }

    static func renderPDF(_ document: PDFDocumentModel) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw rendererFailure("export.pdf-consumer-failed")
        }
        var mediaBox = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let metadata: [CFString: Any] = [
            kCGPDFContextTitle: document.title,
            kCGPDFContextAuthor: "Glifi Studio",
            kCGPDFContextSubject: document.subject,
            kCGPDFContextCreator: "Glifi Studio / Core Graphics",
            kCGPDFContextCreatePDFA: true,
        ]
        guard
            let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                metadata as CFDictionary
            )
        else {
            throw rendererFailure("export.pdf-context-failed")
        }
        let documentElement = CGPDFStructureElement(
            tagType: .document,
            attributes: .init(
                title: document.title,
                language: Locale.Language(identifier: document.languageCode)
            )
        )
        guard context.addStructureTreeRootChild(documentElement) == 0 else {
            throw rendererFailure("export.pdf-structure-failed")
        }

        let layout = PDFLayout(mediaBox: mediaBox)
        let pageInfo: CFDictionary = withUnsafeBytes(of: &mediaBox) { bytes in
            [kCGPDFContextMediaBox: Data(bytes)] as CFDictionary
        }
        var pageNumber = 0
        var cursorY = layout.top

        func beginPage() {
            pageNumber += 1
            context.beginPDFPage(pageInfo)
            context.setFillColor(CGColor(gray: 0.12, alpha: 1))
            cursorY = layout.top
        }

        func endPage() {
            context.beginNonStructuralMarkedContentSequence(.artifact)
            drawFooter(
                pageNumber: pageNumber,
                reportTitle: document.title,
                context: context,
                layout: layout
            )
            context.endMarkedContentSequence()
            context.endPDFPage()
        }

        beginPage()
        for block in document.blocks {
            var offset = 0
            let attributed = attributedString(block, languageCode: document.languageCode)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let blockElement = CGPDFStructureElement(
                tagType: block.tag,
                attributes: .init(
                    language: Locale.Language(identifier: document.languageCode),
                    actualText: block.text
                )
            )
            guard documentElement.addChild(blockElement) == 0 else {
                throw rendererFailure("export.pdf-structure-failed")
            }
            while offset < attributed.length {
                let availableHeight = cursorY - layout.bottom
                if availableHeight < layout.minimumBlockHeight {
                    endPage()
                    beginPage()
                    continue
                }
                let remaining = CFRange(location: offset, length: attributed.length - offset)
                let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter,
                    remaining,
                    nil,
                    CGSize(width: layout.contentWidth, height: .greatestFiniteMagnitude),
                    nil
                )
                let frameHeight = min(ceil(suggested.height) + 2, availableHeight)
                let rect = CGRect(
                    x: layout.left,
                    y: cursorY - frameHeight,
                    width: layout.contentWidth,
                    height: frameHeight
                )
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: offset, length: 0),
                    CGPath(rect: rect, transform: nil),
                    nil
                )
                let visible = CTFrameGetVisibleStringRange(frame)
                guard visible.length > 0 else {
                    throw rendererFailure("export.pdf-layout-failed")
                }
                guard let markedContent = context.beginMarkedContentSequence(block.tag) else {
                    throw rendererFailure("export.pdf-structure-failed")
                }
                CTFrameDraw(frame, context)
                context.endMarkedContentSequence()
                guard blockElement.addMarkedContentItem(markedContent) == 0 else {
                    throw rendererFailure("export.pdf-structure-failed")
                }
                offset += visible.length
                cursorY -= frameHeight + layout.blockSpacing
                if offset < attributed.length {
                    endPage()
                    beginPage()
                }
            }
        }
        endPage()
        context.closePDF()

        let data = try promotePDFAToUnicode(output as Data)
        guard data.starts(with: Data("%PDF-".utf8)), data.count > 512 else {
            throw rendererFailure("export.pdf-invalid")
        }
        guard validateCrossReferenceTable(data) else {
            throw rendererFailure("export.pdf-invalid-xref")
        }
        return data
    }

    struct PDFLayout {
        let left: CGFloat = 54
        let right: CGFloat = 54
        let bottom: CGFloat = 58
        let top: CGFloat
        let contentWidth: CGFloat
        let blockSpacing: CGFloat = 10
        let minimumBlockHeight: CGFloat = 32

        init(mediaBox: CGRect) {
            top = mediaBox.height - 54
            contentWidth = mediaBox.width - left - right
        }
    }

    static func attributedString(_ block: PDFBlock, languageCode: String) -> NSAttributedString {
        let size: CGFloat
        let fontRole: CTFontUIFontType
        switch block.style {
        case .title:
            size = 25
            fontRole = .emphasizedSystem
        case .heading:
            size = 16
            fontRole = .emphasizedSystem
        case .body:
            size = 11
            fontRole = .system
        case .listItem:
            size = 10.5
            fontRole = .system
        case .code:
            size = 8.5
            fontRole = .userFixedPitch
        }
        let font =
            CTFontCreateUIFontForLanguage(fontRole, size, languageCode as CFString)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                gray: 0.12,
                alpha: 1
            ),
            NSAttributedString.Key(kCTLanguageAttributeName as String): languageCode,
        ]
        return NSAttributedString(string: block.text, attributes: attributes)
    }

    static func drawFooter(
        pageNumber: Int,
        reportTitle: String,
        context: CGContext,
        layout: PDFLayout
    ) {
        let footer = "Glifi Studio  |  \(reportTitle)  |  \(pageNumber)"
        let footerFont =
            CTFontCreateUIFontForLanguage(.smallSystem, 8, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): footerFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                gray: 0.45,
                alpha: 1
            ),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: footer, attributes: attributes)
        )
        context.textPosition = CGPoint(x: layout.left, y: 31)
        CTLineDraw(line, context)
    }

    static func canonicalCaveats(_ report: GlifiReportRevision) -> [GlifiCaveat] {
        let values =
            report.evidence.flatMap(\.caveats)
            + report.findings.flatMap(\.caveats)
            + (report.insufficientEvidence?.caveats ?? [])
        var seen = Set<String>()
        return values.sorted {
            ($0.identifier, $0.scope.rawValue, $0.originIdentifier)
                < ($1.identifier, $1.scope.rawValue, $1.originIdentifier)
        }.filter {
            let key = [
                $0.identifier,
                $0.severity.rawValue,
                $0.scope.rawValue,
                $0.causeIdentifier,
                $0.consequenceIdentifier,
                $0.actionIdentifier ?? "",
                $0.originIdentifier,
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    static func displayIdentifier(_ value: String) -> String {
        value.replacingOccurrences(of: ":sha256:", with: ":sha256:\n")
    }

    // Quartz builds the PDF/A-2u payload requested above but emits the generic
    // level-B XMP marker. Normalize only that marker and repair its bounded
    // stream/xref envelope; any unexpected PDF layout still fails closed.
    static func promotePDFAToUnicode(_ source: Data) throws -> Data {
        let metadataMarker = Data("/Type /Metadata".utf8)
        let streamMarker = Data("stream\n".utf8)
        let endStreamMarker = Data("\nendstream".utf8)
        guard
            let metadataRange = source.range(of: metadataMarker),
            let streamRange = source.range(
                of: streamMarker,
                in: metadataRange.upperBound..<source.endIndex
            ),
            let endStreamRange = source.range(
                of: endStreamMarker,
                in: streamRange.upperBound..<source.endIndex
            )
        else {
            throw rendererFailure("export.pdf-metadata-failed")
        }

        let compressedRange = streamRange.upperBound..<endStreamRange.lowerBound
        let compressedMetadata = Data(source[compressedRange])
        var metadata = try inflatePDFMetadata(compressedMetadata)
        let baseline = Data("<pdfaid:conformance>B</pdfaid:conformance>".utf8)
        let unicode = Data("<pdfaid:conformance>U</pdfaid:conformance>".utf8)
        guard
            let conformanceRange = metadata.range(of: baseline),
            metadata.range(of: baseline, in: conformanceRange.upperBound..<metadata.endIndex) == nil
        else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        metadata.replaceSubrange(conformanceRange, with: unicode)

        let revisedMetadata = try deflatePDFMetadata(metadata)
        var result = source
        result.replaceSubrange(compressedRange, with: revisedMetadata)
        try updateMetadataLength(
            in: &result,
            metadataRange: metadataRange,
            streamRange: streamRange,
            length: revisedMetadata.count
        )
        try updateCrossReferenceTable(
            in: &result,
            shiftedAfter: endStreamRange.lowerBound,
            by: revisedMetadata.count - compressedMetadata.count
        )
        return result
    }

    static func updateMetadataLength(
        in data: inout Data,
        metadataRange: Range<Data.Index>,
        streamRange: Range<Data.Index>,
        length: Int
    ) throws {
        let marker = Data("/Length ".utf8)
        guard
            let markerRange = data.range(
                of: marker,
                in: metadataRange.lowerBound..<streamRange.lowerBound
            )
        else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        let valueStart = markerRange.upperBound
        var valueEnd = valueStart
        while valueEnd < data.endIndex, data[valueEnd].isASCIIDigit {
            valueEnd += 1
        }
        let valueRange = valueStart..<valueEnd
        let encoded = try fixedWidthDecimal(length, width: valueRange.count)
        data.replaceSubrange(valueRange, with: encoded)
    }

}

extension GlifiScientificExportRenderer {
    /// Checks that `startxref` points to the table and every in-use entry points to its object.
    ///
    /// Each entry `k` with type `n` must reference the byte where `k 0 obj` starts; a single
    /// shifted offset makes the document unreadable for strict consumers (GS-VER-093).
    static func validateCrossReferenceTable(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        guard let startRange = data.range(of: Data("startxref".utf8), options: .backwards) else {
            return false
        }
        var cursor = startRange.upperBound
        while cursor < bytes.count, bytes[cursor] == 0x0A || bytes[cursor] == 0x0D {
            cursor += 1
        }
        var digits = ""
        while cursor < bytes.count, (0x30...0x39).contains(bytes[cursor]) {
            digits.append(Character(UnicodeScalar(bytes[cursor])))
            cursor += 1
        }
        guard let xref = Int(digits), xref + 4 <= bytes.count,
            String(decoding: bytes[xref..<(xref + 4)], as: UTF8.self) == "xref"
        else {
            return false
        }
        let tail = String(decoding: bytes[xref...], as: UTF8.self)
        var lines = tail.split(omittingEmptySubsequences: true) { $0 == "\n" || $0 == "\r" }
            .map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "xref" else { return false }
        lines.removeFirst()
        var objectNumber = 0
        var remaining = 0
        for line in lines {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            if remaining == 0 {
                guard fields.count == 2, let first = Int(fields[0]), let count = Int(fields[1])
                else {
                    break
                }
                objectNumber = first
                remaining = count
                continue
            }
            guard fields.count == 3, let offset = Int(fields[0]) else { return false }
            if fields[2] == "n" {
                let header = Array("\(objectNumber) 0 obj".utf8)
                guard offset >= 0, offset + header.count <= bytes.count,
                    Array(bytes[offset..<(offset + header.count)]) == header
                else {
                    return false
                }
            }
            objectNumber += 1
            remaining -= 1
        }
        return remaining == 0
    }

    static func updateCrossReferenceTable(
        in data: inout Data,
        shiftedAfter boundary: Int,
        by delta: Int
    ) throws {
        let marker = Data("\nxref\n".utf8)
        guard let markerRange = data.range(of: marker) else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        let xrefStart = markerRange.lowerBound + 1
        var lineStart = markerRange.upperBound
        while lineStart < data.endIndex,
            let newline = data[lineStart..<data.endIndex].firstIndex(of: 0x0A)
        {
            let contentEnd =
                newline > lineStart && data[newline - 1] == 0x0D
                ? newline - 1 : newline
            let lineRange = lineStart..<contentEnd
            // Una voce xref è "oooooooooo ggggg n" seguita da SP+LF, CR+LF o SP+CR.
            // Senza terminatore misura 18 o 19 byte: confrontare con 20 non trovava mai
            // alcuna voce e lasciava gli offset non traslati.
            if (18...19).contains(lineRange.count),
                data[lineStart + 10] == 0x20,
                data[lineStart + 16] == 0x20,
                data[lineStart + 17] == 0x6E,
                data[lineStart..<lineStart + 10].allSatisfy(\.isASCIIDigit),
                let offset = Int(String(decoding: data[lineStart..<lineStart + 10], as: UTF8.self)),
                offset >= boundary
            {
                data.replaceSubrange(
                    lineStart..<lineStart + 10,
                    with: try fixedWidthDecimal(offset + delta, width: 10)
                )
            }
            lineStart = newline + 1
        }

        let startXrefMarker = Data("startxref\n".utf8)
        guard
            let startXrefRange = data.range(
                of: startXrefMarker,
                in: xrefStart..<data.endIndex
            ),
            let newline = data[startXrefRange.upperBound..<data.endIndex].firstIndex(of: 0x0A)
        else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        let valueRange = startXrefRange.upperBound..<newline
        data.replaceSubrange(
            valueRange,
            with: try fixedWidthDecimal(xrefStart, width: valueRange.count)
        )
    }
}

private extension GlifiScientificExportRenderer {
    static func fixedWidthDecimal(_ value: Int, width: Int) throws -> Data {
        guard value >= 0 else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        let rawValue = String(value)
        guard rawValue.count <= width else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        return Data((String(repeating: "0", count: width - rawValue.count) + rawValue).utf8)
    }

    static func inflatePDFMetadata(_ source: Data) throws -> Data {
        var capacity = max(source.count * 4, 4_096)
        while capacity <= 1_048_576 {
            var output = Data(count: capacity)
            var outputCount = uLong(capacity)
            let status = output.withUnsafeMutableBytes { outputBytes in
                source.withUnsafeBytes { sourceBytes in
                    uncompress(
                        outputBytes.bindMemory(to: Bytef.self).baseAddress,
                        &outputCount,
                        sourceBytes.bindMemory(to: Bytef.self).baseAddress,
                        uLong(source.count)
                    )
                }
            }
            if status == Z_OK {
                output.removeSubrange(Int(outputCount)..<output.endIndex)
                return output
            }
            guard status == Z_BUF_ERROR else {
                throw rendererFailure("export.pdf-metadata-failed")
            }
            capacity *= 2
        }
        throw rendererFailure("export.pdf-metadata-failed")
    }

    static func deflatePDFMetadata(_ source: Data) throws -> Data {
        var output = Data(count: Int(compressBound(uLong(source.count))))
        var outputCount = uLong(output.count)
        let status = output.withUnsafeMutableBytes { outputBytes in
            source.withUnsafeBytes { sourceBytes in
                compress2(
                    outputBytes.bindMemory(to: Bytef.self).baseAddress,
                    &outputCount,
                    sourceBytes.bindMemory(to: Bytef.self).baseAddress,
                    uLong(source.count),
                    Z_BEST_SPEED
                )
            }
        }
        guard status == Z_OK else {
            throw rendererFailure("export.pdf-metadata-failed")
        }
        output.removeSubrange(Int(outputCount)..<output.endIndex)
        return output
    }

    static func rendererFailure(_ code: String) -> GlifiFailure {
        GlifiFailure(
            code: code,
            category: .invariantViolation,
            operation: .export,
            retryDisposition: .never,
            retainedState: .validityUnknown,
            messageKey: "failure.\(code)"
        )
    }
}

private extension UInt8 {
    var isASCIIDigit: Bool { (0x30...0x39).contains(self) }
}
