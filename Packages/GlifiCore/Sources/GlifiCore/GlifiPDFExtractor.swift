// SPDX-License-Identifier: BSD-3-Clause

import CoreGraphics
import Foundation
import PDFKit
import Synchronization
import Vision

/// Page-based native extraction; the caller persists the resulting snapshot without rerunning OCR.
enum GlifiPDFExtractor {
    static func extract(_ data: Data, limits: GlifiTextImportLimits) throws
        -> GlifiDocumentExtraction
    {
        try pdfCheckCancellation()
        guard data.count <= limits.maximumByteCount else {
            throw pdfFailure("pdf.byte-limit", .insufficientResources)
        }
        // Require the header at byte zero; leading junk and preambles are not this import profile.
        guard data.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]),
            let document = PDFDocument(data: data)
        else {
            throw pdfFailure("pdf.invalid-document")
        }
        guard !document.isEncrypted, !document.isLocked, document.allowsCopying else {
            throw pdfFailure("pdf.protected-document", .authorizationDenied)
        }
        guard document.pageCount > 0 else {
            throw pdfFailure("pdf.empty-document", .insufficientData)
        }
        guard document.pageCount <= limits.maximumDocumentUnitCount,
            limits.maximumExtractedByteCount > 0, limits.maximumDocumentLocationCount > 0
        else { throw pdfFailure("pdf.document-limit", .insufficientResources) }
        var output = PDFExtractedTextBuilder(limits: limits)
        var digitalPages = 0
        var ocrPages = 0
        var ocrRequests = GlifiPDFOCRExecution.RequestBudget(limits: limits)
        var usedAccurate = false
        var fastPageNumbers: [Int] = []
        let revision = VNRecognizeTextRequest.currentRevision
        for index in 0..<document.pageCount {
            try pdfCheckCancellation()
            try autoreleasepool {
                guard let page = document.page(at: index) else {
                    throw pdfFailure("pdf.invalid-page")
                }
                let digital = canonicalPDFText(page.string ?? "")
                try pdfCheckCancellation()
                if !digital.isEmpty {
                    try output.append(digital, page: index + 1, method: "pdf-text")
                    digitalPages += 1
                    return
                }
                guard ocrPages < limits.maximumOCRPageCount else {
                    throw pdfFailure("pdf.ocr-page-limit", .insufficientResources)
                }
                ocrPages += 1
                let image = try rasterizePDFPage(page, limits: limits)
                try pdfCheckCancellation()
                let level = try recognizePDFPage(
                    image, pageNumber: index + 1, revision: revision,
                    requestBudget: &ocrRequests, output: &output)
                switch level {
                case .accurate: usedAccurate = true
                case .fast: fastPageNumbers.append(index + 1)
                }
            }
        }
        try pdfCheckCancellation()
        guard !output.text.isEmpty else {
            throw pdfFailure("pdf.no-extractable-text", .insufficientData)
        }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osIdentifier = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let pdfVersion =
            Bundle(for: PDFDocument.self).object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "system"
        let effectiveLevel: String
        switch (usedAccurate, !fastPageNumbers.isEmpty) {
        case (false, false): effectiveLevel = "none"
        case (true, false): effectiveLevel = "accurate"
        case (false, true): effectiveLevel = "fast"
        case (true, true): effectiveLevel = "mixed"
        }
        return try GlifiDocumentExtraction(
            text: output.text, locations: output.locations,
            contractIdentifier: "pdfkit-pages-vision-ocr-v2",
            backendIdentifier:
                "PDFKit-\(pdfVersion);Vision-text-r\(revision);OS-\(osIdentifier);OCR-policy-v2;OCR-level-\(effectiveLevel)",
            metadata: [
                "pageCount": String(document.pageCount),
                "documentUnitCount": String(document.pageCount),
                "digitalTextPageCount": String(digitalPages),
                "ocrPageCount": String(ocrPages),
                "pdfKitVersion": pdfVersion,
                "operatingSystemVersion": osIdentifier,
                "operatingSystemBuild": ProcessInfo.processInfo.operatingSystemVersionString,
                "ocrRevision": String(revision),
                "ocrRequestedRecognitionLevel": "accurate",
                "ocrRecognitionLevel": effectiveLevel,
                "ocrRequestCount": String(ocrRequests.requestCount),
                "ocrFallbackPageCount": String(fastPageNumbers.count),
                "ocrFastPageNumbers": fastPageNumbers.map(String.init).joined(separator: ","),
                "ocrProfileIdentifier":
                    "pdf-import-readable-text-accurate-preferred-fast-resource-v2",
                "ocrRequestedLanguages": "it-IT,en-US",
                "ocrAutomaticallyDetectsLanguage": "true",
                "ocrUsesLanguageCorrection": "true",
                "ocrCoordinates": "rendered-crop-box-normalized-bottom-left",
                "ocrReadingOrder": "top-to-bottom-then-left-to-right-v1",
                "ocrRasterProfile": "144dpi-downsampled-4096-edge-pixel-budget-v1",
            ])
    }
}

private struct PDFExtractedTextBuilder {
    let limits: GlifiTextImportLimits
    var text = ""
    var locations: [GlifiDocumentTextLocation] = []
    private var byteCount = 0

    init(limits: GlifiTextImportLimits) { self.limits = limits }

    mutating func append(
        _ value: String, page: Int, method: String,
        region: GlifiDocumentRegion? = nil, confidence: Double? = nil
    ) throws {
        guard !value.isEmpty else { return }
        let separator = text.isEmpty ? 0 : 1
        let bytes = value.utf8.count
        guard separator <= limits.maximumExtractedByteCount - byteCount,
            bytes <= limits.maximumExtractedByteCount - byteCount - separator,
            locations.count < limits.maximumDocumentLocationCount
        else { throw pdfFailure("pdf.extracted-text-limit", .insufficientResources) }
        if separator > 0 {
            text.append("\n")
            byteCount += 1
        }
        let start = byteCount
        text.append(value)
        byteCount += bytes
        locations.append(
            try GlifiDocumentTextLocation(
                range: GlifiUTF8Range(start: start, end: byteCount), pageNumber: page,
                method: method, region: region, confidence: confidence))
    }
}

private func canonicalPDFText(_ value: String) -> String {
    value.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func rasterizePDFPage(_ page: PDFPage, limits: GlifiTextImportLimits) throws -> CGImage {
    let bounds = page.bounds(for: .cropBox)
    guard bounds.minX.isFinite, bounds.minY.isFinite, bounds.maxX.isFinite, bounds.maxY.isFinite,
        bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0,
        let reference = page.pageRef
    else { throw pdfFailure("pdf.invalid-page-bounds") }
    guard limits.maximumOCRPixelCount > 0 else {
        throw pdfFailure("pdf.ocr-pixel-limit", .insufficientResources)
    }
    let rotation = ((page.rotation % 360) + 360) % 360
    guard [0, 90, 180, 270].contains(rotation) else {
        throw pdfFailure("pdf.invalid-page-rotation")
    }
    let turned = rotation == 90 || rotation == 270
    let pageWidth = turned ? bounds.height : bounds.width
    let pageHeight = turned ? bounds.width : bounds.height
    let scale = min(2, 4_096 / pageWidth, 4_096 / pageHeight)
    guard scale.isFinite, scale > 0 else { throw pdfFailure("pdf.invalid-page-bounds") }
    let desiredWidth = max(1, min(4_096, Int(ceil(pageWidth * scale))))
    let desiredHeight = max(1, min(4_096, Int(ceil(pageHeight * scale))))
    let desiredPixels = desiredWidth * desiredHeight
    let reduction = min(1, sqrt(Double(limits.maximumOCRPixelCount) / Double(desiredPixels)))
    let width = max(1, Int((Double(desiredWidth) * reduction).rounded(.down)))
    let height = max(1, Int((Double(desiredHeight) * reduction).rounded(.down)))
    guard width <= limits.maximumOCRPixelCount / height else {
        throw pdfFailure("pdf.ocr-pixel-limit", .insufficientResources)
    }
    try pdfCheckCancellation()
    // Dimensions are at most 4096; one RGBA bitmap is at most the admitted pixel count × 4.
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw pdfFailure("pdf.ocr-bitmap-unavailable", .insufficientResources) }
    let target = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(target)
    context.concatenate(
        reference.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
    context.drawPDFPage(reference)
    try pdfCheckCancellation()
    guard let image = context.makeImage() else {
        throw pdfFailure("pdf.ocr-bitmap-unavailable", .insufficientResources)
    }
    return image
}

private func recognizePDFPage(
    _ image: CGImage, pageNumber: Int, revision: Int,
    requestBudget: inout GlifiPDFOCRExecution.RequestBudget,
    output: inout PDFExtractedTextBuilder
) throws -> GlifiPDFOCRExecution.Level {
    let selected = try GlifiPDFOCRExecution.run(checkCancellation: pdfCheckCancellation) { level in
        try autoreleasepool {
            try performPDFOCRAttempt(
                image, level: level, revision: revision, requestBudget: &requestBudget)
        }
    }
    let observations = selected.value
    guard observations.count <= output.limits.maximumDocumentLocationCount - output.locations.count
    else {
        throw pdfFailure("pdf.location-limit", .insufficientResources)
    }
    var ordered: [(index: Int, observation: VNRecognizedTextObservation)] = []
    ordered.reserveCapacity(observations.count)
    for (index, observation) in observations.enumerated() {
        if index.isMultiple(of: 1_024) { try pdfCheckCancellation() }
        let box = observation.boundingBox
        guard box.minX.isFinite, box.minY.isFinite, box.maxX.isFinite, box.maxY.isFinite,
            box.width.isFinite, box.height.isFinite
        else {
            throw pdfFailure("pdf.ocr-invalid-observation")
        }
        ordered.append((index, observation))
    }
    var comparisons = 0
    try ordered.sort {
        comparisons += 1
        if comparisons.isMultiple(of: 1_024) { try pdfCheckCancellation() }
        let left = $0.observation.boundingBox
        let right = $1.observation.boundingBox
        if left.maxY != right.maxY { return left.maxY > right.maxY }
        if left.minX != right.minX { return left.minX < right.minX }
        return $0.index < $1.index
    }
    for item in ordered {
        try pdfCheckCancellation()
        guard let candidate = item.observation.topCandidates(1).first else { continue }
        let text = canonicalPDFText(candidate.string)
        guard !text.isEmpty else { continue }
        let box = item.observation.boundingBox.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !box.isNull, box.width > 0, box.height > 0 else {
            throw pdfFailure("pdf.ocr-invalid-observation")
        }
        let region = try GlifiDocumentRegion(
            x: box.minX, y: box.minY, width: box.width, height: box.height)
        let confidence = Double(candidate.confidence)
        guard confidence.isFinite, (0...1).contains(confidence) else {
            throw pdfFailure("pdf.ocr-invalid-observation")
        }
        try output.append(
            text, page: pageNumber, method: "pdf-ocr", region: region, confidence: confidence)
    }
    return selected.level
}

private func performPDFOCRAttempt(
    _ image: CGImage, level: GlifiPDFOCRExecution.Level, revision: Int,
    requestBudget: inout GlifiPDFOCRExecution.RequestBudget
) throws -> Result<[VNRecognizedTextObservation], GlifiFailure> {
    try pdfCheckCancellation()
    let request = VNRecognizeTextRequest()
    request.revision = revision
    switch level {
    case .accurate: request.recognitionLevel = .accurate
    case .fast: request.recognitionLevel = .fast
    }
    request.recognitionLanguages = ["it-IT", "en-US"]
    request.usesLanguageCorrection = true
    request.automaticallyDetectsLanguage = true
    do {
        let supported = try request.supportedRecognitionLanguages()
        guard request.recognitionLanguages.allSatisfy({ supported.contains($0) }) else {
            throw pdfFailure("pdf.ocr-language-unavailable", .unsupportedFormat)
        }
    } catch let failure as GlifiFailure {
        throw failure
    } catch {
        throw GlifiPDFVisionFailure.classify(error, code: "pdf.ocr-unavailable")
    }
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    return try GlifiPDFCancellationProbe.withCurrentTask { probe in
        request.progressHandler = { request, _, _ in
            if probe.isCancelled { request.cancel() }
        }
        defer { request.progressHandler = { _, _, _ in } }
        try pdfCheckCancellation()
        try requestBudget.consume()
        do {
            try handler.perform([request])
        } catch {
            return .failure(
                GlifiPDFVisionFailure.classify(
                    error, code: "pdf.ocr-failed", isCancelled: probe.isCancelled))
        }
        try pdfCheckCancellation()
        return .success(request.results ?? [])
    }
}

/// A borrowed task handle is accessed only under the mutex and only during its lexical lifetime.
///
/// Invalidation waits for an in-flight read; late Vision callbacks see nil instead of a stale handle.
final class GlifiPDFCancellationProbe: Sendable {
    /// The handle is borrowed by withUnsafeCurrentTask and only inspected while holding
    /// currentTask's lock.
    ///
    /// Invalidation clears it before that lexical borrow can end.
    private struct BorrowedTask: @unchecked Sendable {
        let handle: UnsafeCurrentTask
    }

    private let currentTask: Mutex<BorrowedTask?>

    private init(_ task: UnsafeCurrentTask?) {
        currentTask = Mutex(task.map { BorrowedTask(handle: $0) })
    }

    var isCancelled: Bool { currentTask.withLock { $0?.handle.isCancelled ?? false } }

    private func invalidate() { currentTask.withLock { $0 = nil } }

    static func withCurrentTask<Result>(_ body: (GlifiPDFCancellationProbe) throws -> Result)
        rethrows -> Result
    {
        try withUnsafeCurrentTask { task in
            let probe = GlifiPDFCancellationProbe(task)
            defer { probe.invalidate() }
            return try body(probe)
        }
    }
}

private func pdfCheckCancellation() throws {
    if Task.isCancelled { throw pdfFailure("pdf.cancelled", .cancelled) }
}

private func pdfFailure(
    _ code: String, _ category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .importText,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category), retainedState: .unchanged,
        messageKey: "failure.category.\(category.rawValue)")
}
