// SPDX-License-Identifier: BSD-3-Clause

import CoreGraphics
import CoreText
import Dispatch
import Foundation
import PDFKit
import Testing
import Vision

@testable import GlifiCore

@Test("PDF digital text is captured page by page with canonical UTF-8 locations")
func pdfImporterDigitalPagesAndUnicodeLocations() throws {
    let source = try pdfImporterFixture([.text("Prima pagina: città"), .text("Second page 314159")])
    let result = try GlifiPDFExtractor.extract(source, limits: .standard)
    #expect(result.text == "Prima pagina: città\nSecond page 314159")
    #expect(result.locations.count == 2)
    #expect(result.locations.map(\.pageNumber) == [1, 2])
    #expect(result.locations.map(\.method) == ["pdf-text", "pdf-text"])
    #expect(result.locations.allSatisfy { $0.region == nil && $0.confidence == nil })
    #expect(result.locations[0].range.text(in: result.text) == "Prima pagina: città")
    #expect(result.locations[1].range.text(in: result.text) == "Second page 314159")
    #expect(result.locations[1].range.start == "Prima pagina: città\n".utf8.count)
    #expect(result.metadata["documentUnitCount"] == "2")
    #expect(result.metadata["digitalTextPageCount"] == "2")
    #expect(result.metadata["ocrPageCount"] == "0")
    #expect(result.contractIdentifier == "pdfkit-pages-vision-ocr-v2")
    #expect(result.metadata["ocrRequestedRecognitionLevel"] == "accurate")
    #expect(result.metadata["ocrRecognitionLevel"] == "none")
    #expect(result.metadata["ocrRequestCount"] == "0")
    #expect(result.metadata["ocrFallbackPageCount"] == "0")
    #expect(result.metadata["ocrFastPageNumbers"] == "")
    #expect(result.backendIdentifier.hasSuffix(";OCR-policy-v2;OCR-level-none"))
    #expect(result.backendIdentifier.contains("PDFKit-"))
    #expect(result.metadata["operatingSystemVersion"]?.isEmpty == false)
    #expect(
        result.metadata["operatingSystemBuild"]
            == ProcessInfo.processInfo.operatingSystemVersionString)
    #expect(try GlifiPDFExtractor.extract(source, limits: .standard) == result)
    // An OCR budget of zero leaves digital documents usable.
    #expect(
        try GlifiPDFExtractor.extract(
            source, limits: .init(maximumByteCount: source.count, maximumOCRPageCount: 0)
        ).text
            == result.text)
}

@Test("Mixed PDF pages use native OCR only where the digital text layer is absent")
func pdfImporterMixedDigitalAndOCR() throws {
    let source = try pdfImporterFixture([.text("Digital first page"), .image("NATIVE OCR 314159")])
    let document = try #require(PDFDocument(data: source))
    #expect(
        document.page(at: 1)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ?? true)
    let result = try GlifiPDFExtractor.extract(source, limits: .standard)
    #expect(result.text.hasPrefix("Digital first page\n"))
    #expect(result.text.contains("314159"))
    #expect(result.locations.first?.pageNumber == 1)
    #expect(result.locations.first?.method == "pdf-text")
    let ocr = result.locations.filter { $0.method == "pdf-ocr" }
    #expect(!ocr.isEmpty)
    #expect(ocr.allSatisfy { $0.pageNumber == 2 && $0.region != nil && $0.confidence != nil })
    #expect(ocr.allSatisfy { $0.range.text(in: result.text)?.isEmpty == false })
    #expect(ocr.allSatisfy { (0...1).contains($0.confidence ?? -1) })
    #expect(result.metadata["ocrPageCount"] == "1")
    #expect(result.metadata["ocrRequestedLanguages"] == "it-IT,en-US")
    #expect(
        result.metadata["ocrProfileIdentifier"]
            == "pdf-import-readable-text-accurate-preferred-fast-resource-v2")
    #expect(result.metadata["ocrRevision"] == String(VNRecognizeTextRequest.currentRevision))
    #expect(result.metadata["documentUnitCount"] == "2")
    #expect(result.backendIdentifier.contains("Vision-text-r"))
    #expect(result.contractIdentifier == "pdfkit-pages-vision-ocr-v2")
    #expect(result.metadata["ocrRequestedRecognitionLevel"] == "accurate")
    switch result.metadata["ocrRequestCount"] {
    case "1":
        #expect(result.metadata["ocrRecognitionLevel"] == "accurate")
        #expect(result.metadata["ocrFallbackPageCount"] == "0")
        #expect(result.metadata["ocrFastPageNumbers"] == "")
        #expect(result.backendIdentifier.hasSuffix(";OCR-policy-v2;OCR-level-accurate"))
    case "2":
        #expect(result.metadata["ocrRecognitionLevel"] == "fast")
        #expect(result.metadata["ocrFallbackPageCount"] == "1")
        #expect(result.metadata["ocrFastPageNumbers"] == "2")
        #expect(result.backendIdentifier.hasSuffix(";OCR-policy-v2;OCR-level-fast"))
    default:
        Issue.record("One OCR page must consume exactly one or two native requests")
    }
}

@Test("A rotated digital page preserves text and the original page number")
func pdfImporterRotatedDigitalPage() throws {
    let data = try pdfImporterFixture([.text("Rotated PDF 271828")])
    let document = try #require(PDFDocument(data: data))
    let page = try #require(document.page(at: 0))
    page.rotation = 90
    let rotated = try #require(document.dataRepresentation())
    let result = try GlifiPDFExtractor.extract(rotated, limits: .standard)
    #expect(result.text == "Rotated PDF 271828")
    #expect(result.locations.map(\.pageNumber) == [1])
    #expect(result.locations.map(\.method) == ["pdf-text"])
}

@Test("Malformed and password-protected PDFs produce private typed import failures")
func pdfImporterRejectsMalformedAndProtectedInput() throws {
    for source in [
        Data(), Data("secret-canary-not-a-pdf".utf8), Data("%PDF-1.7\ntruncated".utf8),
        Data(" \n%PDF-1.7\ntruncated".utf8), Data("prefix%PDF-1.7\ntruncated".utf8),
    ] {
        do {
            _ = try GlifiPDFExtractor.extract(source, limits: .standard)
            Issue.record("Malformed PDF was accepted")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "pdf.invalid-document")
            #expect(failure.category == .invalidInput)
            #expect(failure.operation == .importText && failure.retainedState == .unchanged)
            #expect(failure.arguments.isEmpty)
            #expect(!String(describing: failure).contains("secret-canary"))
        }
    }
    let protected = try pdfImporterFixture(
        [.text("Protected synthetic page")], password: "synthetic-password")
    #expect(try #require(PDFDocument(data: protected)).isEncrypted)
    do {
        _ = try GlifiPDFExtractor.extract(protected, limits: .standard)
        Issue.record("Encrypted PDF was accepted")
    } catch let failure as GlifiFailure {
        #expect(failure.category == .authorizationDenied)
        #expect(failure.retryDisposition == .afterUserAction)
        #expect(failure.operation == .importText && failure.retainedState == .unchanged)
        #expect(failure.arguments.isEmpty)
        #expect(!String(describing: failure).contains("synthetic-password"))
    }
}

@Test("PDF byte, page, extracted-text, location and OCR admissions are cumulative")
func pdfImporterResourceAdmissions() throws {
    let digital = try pdfImporterFixture([.text("First page"), .text("Second page")])
    for limits in [
        GlifiTextImportLimits(maximumByteCount: digital.count - 1),
        .init(maximumByteCount: digital.count, maximumDocumentUnitCount: 1),
        .init(maximumByteCount: digital.count, maximumExtractedByteCount: 12),
        .init(maximumByteCount: digital.count, maximumDocumentLocationCount: 1),
    ] {
        do {
            _ = try GlifiPDFExtractor.extract(digital, limits: limits)
            Issue.record("A limited PDF extraction was accepted")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .insufficientResources)
            #expect(failure.retryDisposition == .afterConditionsChange)
            #expect(failure.retainedState == .unchanged && failure.arguments.isEmpty)
        }
    }
    let image = try pdfImporterFixture([.image("NATIVE OCR 314159")])
    for limits in [
        GlifiTextImportLimits(maximumByteCount: image.count, maximumOCRPageCount: 0),
        .init(maximumByteCount: image.count, maximumOCRPixelCount: 0),
    ] {
        #expect(throws: GlifiFailure.self) { try GlifiPDFExtractor.extract(image, limits: limits) }
    }
}

@Test("Blank pages never invent an OCR result")
func pdfImporterBlankPageHasNoExtractableText() throws {
    let source = try pdfImporterFixture([.blank])
    do {
        _ = try GlifiPDFExtractor.extract(source, limits: .standard)
        Issue.record("A blank PDF acquired invented text")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "pdf.no-extractable-text")
        #expect(failure.category == .insufficientData)
    }
}

@Test("PDF cancellation is typed before native parsing")
func pdfImporterCancellationPrecedesParsing() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiPDFExtractor.extract(Data("not-a-pdf".utf8), limits: .standard)
    }
    do {
        _ = try await task.value
        Issue.record("A cancelled PDF import completed")
    } catch let failure as GlifiFailure {
        #expect(failure.category == .cancelled && failure.retryDisposition == .newRequest)
        #expect(failure.operation == .importText && failure.retainedState == .unchanged)
        #expect(failure.arguments.isEmpty)
    }
}

@Test("Vision callbacks query the caller task across queues and ignore expired handles")
func pdfImporterCancellationProbeLifetime() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return GlifiPDFCancellationProbe.withCurrentTask { probe in
            #expect(DispatchQueue.global().sync { probe.isCancelled })
            return probe
        }
    }
    let expired = await task.value
    #expect(!expired.isCancelled)
    #expect(!DispatchQueue.global().sync { expired.isCancelled })
}

private enum PDFImporterPageFixture {
    case text(String)
    case image(String)
    case blank
}

private func pdfImporterFixture(_ pages: [PDFImporterPageFixture], password: String? = nil) throws
    -> Data
{
    let data = NSMutableData()
    let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
    var mediaBox = CGRect(x: 0, y: 0, width: 640, height: 300)
    let info: CFDictionary? = password.map {
        [kCGPDFContextUserPassword: $0, kCGPDFContextOwnerPassword: "synthetic-owner"]
            as CFDictionary
    }
    let context = try #require(CGContext(consumer: consumer, mediaBox: &mediaBox, info))
    for page in pages {
        context.beginPDFPage(nil)
        switch page {
        case let .text(text):
            pdfImporterDrawText(text, context: context)
        case let .image(text):
            let image = try pdfImporterRasterFixture(text)
            context.draw(image, in: mediaBox)
        case .blank:
            break
        }
        context.endPDFPage()
    }
    context.closePDF()
    return data as Data
}

private func pdfImporterRasterFixture(_ text: String) throws -> CGImage {
    let context = try #require(
        CGContext(
            data: nil, width: 640, height: 300, bitsPerComponent: 8, bytesPerRow: 640 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 640, height: 300))
    pdfImporterDrawText(text, context: context)
    return try #require(context.makeImage())
}

private func pdfImporterDrawText(_ text: String, context: CGContext) {
    let font = CTFontCreateWithName("Helvetica" as CFString, 42, nil)
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
                    gray: 0, alpha: 1),
            ]))
    context.textPosition = CGPoint(x: 30, y: 140)
    CTLineDraw(line, context)
}

@Test("Informative OCR profile measurements use one synthetic image and retain full outputs")
func pdfImporterOCRProfileMeasurements() throws {
    guard let path = ProcessInfo.processInfo.environment["GLIFI_PDF_OCR_BENCHMARK_DIRECTORY"] else {
        return
    }
    let image = try pdfImporterRasterFixture("NATIVE OCR 314159")
    let clock = ContinuousClock()
    var samples: [String: [Double]] = ["fast": [], "accurate": []]
    var outputs: [String: [[String]]] = [:]
    for run in -1..<5 {
        let levels: [VNRequestTextRecognitionLevel] =
            run.isMultiple(of: 2) ? [.accurate, .fast] : [.fast, .accurate]
        for level in levels {
            let request = VNRecognizeTextRequest()
            request.revision = VNRecognizeTextRequest.currentRevision
            request.recognitionLevel = level
            request.recognitionLanguages = ["it-IT", "en-US"]
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let key = level == .accurate ? "accurate" : "fast"
            let start = clock.now
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            let elapsed = start.duration(to: clock.now).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            let strings = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            #expect(strings.joined(separator: " ").contains("314159"))
            if run >= 0 {
                samples[key, default: []].append(seconds)
                outputs[key, default: []].append(strings)
            }
        }
    }
    let payload: [String: Any] = [
        "fixture": "synthetic-640x300-Helvetica42-native-ocr-digits-v1",
        "profile": "pdf-import-readable-text-accurate-v1",
        "warmups": 1, "samplesPerLevel": 5, "wallSeconds": samples, "recognizedStrings": outputs,
        "requestRevision": VNRecognizeTextRequest.currentRevision,
        "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
        "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
        "activeProcessorCount": ProcessInfo.processInfo.activeProcessorCount,
        "measurementScope":
            "VNImageRequestHandler construction and perform; fixture/results outside timer",
        "claim":
            "Informative synthetic measurements; no energy, real-corpus or isolated-throughput claim.",
    ]
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted])
        .write(to: directory.appendingPathComponent("pdf-ocr-profile.json"), options: .atomic)
}
