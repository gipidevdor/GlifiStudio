// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing
import Vision

@testable import GlifiCore

@Test(
    "Vision resource and runtime failures do not imply invalid PDF input",
    arguments: [
        VNErrorCode.turiCoreErrorCode, .OK, .operationFailed, .outOfBoundsError, .invalidOption,
        .ioError, .missingOption, .internalError, .outOfMemory, .unknownError, .invalidOperation,
        .invalidArgument, .invalidModel, .dataUnavailable, .timeStampNotFound, .timeout,
        .resourceUnavailable, .resourceCorrupted,
    ])
func pdfVisionResourceFailureClassification(_ backendCode: VNErrorCode) {
    let failure = GlifiPDFVisionFailure.classify(
        NSError(domain: VNErrorDomain, code: backendCode.rawValue),
        code: "pdf.ocr-failed", isCancelled: false)
    #expect(failure.category == .insufficientResources)
    #expect(failure.retryDisposition == .afterConditionsChange)
    #expect(failure.code == "pdf.ocr-failed")
    expectPDFVisionFailureBoundary(failure)
}

@Test(
    "Unsupported Vision capabilities remain distinct from document validation",
    arguments: [
        VNErrorCode.notImplemented, .unsupportedRevision, .unsupportedRequest,
        .unsupportedComputeStage, .unsupportedComputeDevice,
    ])
func pdfVisionUnsupportedFailureClassification(_ backendCode: VNErrorCode) {
    let failure = GlifiPDFVisionFailure.classify(
        NSError(domain: VNErrorDomain, code: backendCode.rawValue),
        code: "pdf.ocr-unavailable", isCancelled: false)
    #expect(failure.category == .unsupportedFormat)
    #expect(failure.retryDisposition == .afterCorrection)
    #expect(failure.code == "pdf.ocr-unavailable")
    expectPDFVisionFailureBoundary(failure)
}

@Test(
    "Positive Vision invalid-image and invalid-format errors retain input classification",
    arguments: [VNErrorCode.invalidImage, .invalidFormat])
func pdfVisionInvalidImageFailureClassification(_ backendCode: VNErrorCode) {
    let failure = GlifiPDFVisionFailure.classify(
        NSError(domain: VNErrorDomain, code: backendCode.rawValue),
        code: "pdf.ocr-failed", isCancelled: false)
    #expect(failure.category == .invalidInput)
    #expect(failure.retryDisposition == .afterCorrection)
    expectPDFVisionFailureBoundary(failure)
}

@Test(
    "Language-query and recognition context codes survive backend failures",
    arguments: ["pdf.ocr-unavailable", "pdf.ocr-failed"])
func pdfVisionFailurePreservesContextCode(_ contextCode: String) {
    let failure = GlifiPDFVisionFailure.classify(
        NSError(domain: VNErrorDomain, code: VNErrorCode.resourceUnavailable.rawValue),
        code: contextCode, isCancelled: false)
    #expect(failure.code == contextCode)
    #expect(failure.messageKey == "failure.category.insufficientResources")
    expectPDFVisionFailureBoundary(failure)
}

@Test("Caller, Swift and Vision cancellation take priority over backend classifications")
func pdfVisionCancellationFailurePriority() {
    let failures = [
        GlifiPDFVisionFailure.classify(
            NSError(domain: VNErrorDomain, code: VNErrorCode.invalidImage.rawValue),
            code: "pdf.ocr-failed", isCancelled: true),
        GlifiPDFVisionFailure.classify(
            CancellationError(), code: "pdf.ocr-unavailable", isCancelled: false),
        GlifiPDFVisionFailure.classify(
            NSError(domain: VNErrorDomain, code: VNErrorCode.requestCancelled.rawValue),
            code: "pdf.ocr-failed", isCancelled: false),
    ]
    for failure in failures {
        #expect(failure.code == "pdf.cancelled")
        #expect(failure.category == .cancelled)
        #expect(failure.retryDisposition == .newRequest)
        expectPDFVisionFailureBoundary(failure)
    }
}

@Test("Caller-task cancellation cannot be suppressed by an explicit false probe")
func pdfVisionFailureReadsCallerTaskCancellation() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        let error = NSError(domain: VNErrorDomain, code: VNErrorCode.invalidImage.rawValue)
        return [
            GlifiPDFVisionFailure.classify(error, code: "pdf.ocr-failed"),
            GlifiPDFVisionFailure.classify(error, code: "pdf.ocr-failed", isCancelled: false),
        ]
    }
    for failure in await task.value {
        #expect(failure.category == .cancelled)
        #expect(failure.code == "pdf.cancelled")
        expectPDFVisionFailureBoundary(failure)
    }
}

@Test("Unknown and non-Vision errors fail closed without numeric-code domain confusion")
func pdfVisionUnknownAndForeignDomainFailures() {
    let errors = [
        NSError(domain: VNErrorDomain, code: 987_654_321),
        NSError(domain: "TextRecognition.CRImageReaderError", code: 9),
        NSError(domain: "SyntheticBackend", code: VNErrorCode.requestCancelled.rawValue),
        NSError(domain: "SyntheticBackend", code: VNErrorCode.invalidImage.rawValue),
        NSError(domain: "SyntheticBackend", code: VNErrorCode.unsupportedComputeDevice.rawValue),
    ]
    for error in errors {
        let failure = GlifiPDFVisionFailure.classify(
            error, code: "pdf.ocr-failed", isCancelled: false)
        #expect(failure.category == .insufficientResources)
        #expect(failure.retryDisposition == .afterConditionsChange)
        #expect(failure.code == "pdf.ocr-failed")
        expectPDFVisionFailureBoundary(failure)
    }
}

@Test("Public Vision failures never retain backend descriptions, paths or underlying errors")
func pdfVisionFailureDiscardsBackendCanaries() throws {
    let contentCanary = "PRIVATE-OCR-CONTENT-937A"
    let pathCanary = "/synthetic/private-source-63BE.pdf"
    let underlying = NSError(
        domain: "SyntheticUnderlying", code: 42,
        userInfo: [NSLocalizedDescriptionKey: contentCanary, NSFilePathErrorKey: pathCanary])
    let error = NSError(
        domain: VNErrorDomain, code: VNErrorCode.operationFailed.rawValue,
        userInfo: [
            NSLocalizedDescriptionKey: contentCanary, NSFilePathErrorKey: pathCanary,
            NSUnderlyingErrorKey: underlying,
        ])
    let failure = GlifiPDFVisionFailure.classify(
        error, code: "pdf.ocr-failed", isCancelled: false)
    let encoded = String(decoding: try JSONEncoder().encode(failure), as: UTF8.self)
    #expect(!encoded.contains(contentCanary))
    #expect(!encoded.contains(pathCanary))
    #expect(!encoded.contains("SyntheticUnderlying"))
    #expect(!encoded.contains(VNErrorDomain))
    #expect(failure.category == .insufficientResources)
    expectPDFVisionFailureBoundary(failure)
}

private func expectPDFVisionFailureBoundary(_ failure: GlifiFailure) {
    #expect(failure.operation == .importText)
    #expect(failure.retainedState == .unchanged)
    #expect(failure.arguments.isEmpty)
    #expect(
        GlifiFailureTaxonomy.admits(
            category: failure.category, retry: failure.retryDisposition,
            retained: failure.retainedState))
}
