// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test(
    "An accurate success, including no observations, never starts fast",
    arguments: [[], ["accurate"]])
func pdfOCRExecutionAccurateSuccessIsFinal(_ observations: [String]) throws {
    var levels: [GlifiPDFOCRExecution.Level] = []
    let selected = try GlifiPDFOCRExecution.run(checkCancellation: {}) { level in
        levels.append(level)
        return Result<[String], GlifiFailure>.success(observations)
    }
    #expect(selected.level == .accurate)
    #expect(selected.value == observations)
    #expect(levels == [.accurate])
}

@Test("Only a native resource failure admits one fast result and one final append")
func pdfOCRExecutionRecoversNativeResources() throws {
    var levels: [GlifiPDFOCRExecution.Level] = []
    let observedBackendError = NSError(
        domain: "TextRecognition.CRImageReaderError", code: 9,
        userInfo: [NSLocalizedDescriptionKey: "private-canary /Users/private/model"])
    let selected = try GlifiPDFOCRExecution.run(checkCancellation: {}) { level in
        levels.append(level)
        switch level {
        case .accurate:
            return Result<[String], GlifiFailure>.failure(
                GlifiPDFVisionFailure.classify(observedBackendError, code: "pdf.ocr-failed"))
        case .fast:
            return .success(["fast result"])
        }
    }
    var captured: [String] = []
    captured.append(contentsOf: selected.value)
    #expect(captured == ["fast result"])
    #expect(selected.level == .fast)
    #expect(levels == [.accurate, .fast])
}

@Test(
    "Non-resource native failures propagate without a second request",
    arguments: GlifiFailureCategory.allCases.filter { $0 != .insufficientResources })
func pdfOCRExecutionRejectsOtherCategories(_ category: GlifiFailureCategory) throws {
    let expected = ocrExecutionFailure(category)
    var levels: [GlifiPDFOCRExecution.Level] = []
    do {
        let _: GlifiPDFOCRExecution.Selection<String> = try GlifiPDFOCRExecution.run(
            checkCancellation: {}
        ) { level in
            levels.append(level)
            return .failure(expected)
        }
        Issue.record("A non-resource failure was recovered")
    } catch let failure as GlifiFailure {
        #expect(failure == expected)
    }
    #expect(levels == [.accurate])
}

@Test(
    "Thrown preflight and output-limit failures are not native retry results",
    arguments: ["preflight", "output-limit"])
func pdfOCRExecutionThrownResourcesDoNotRecover(_ stage: String) throws {
    let expected = ocrExecutionFailure(.insufficientResources, code: "test.\(stage)")
    var levels: [GlifiPDFOCRExecution.Level] = []
    do {
        let _: GlifiPDFOCRExecution.Selection<String> = try GlifiPDFOCRExecution.run(
            checkCancellation: {}
        ) { level in
            levels.append(level)
            throw expected
        }
        Issue.record("A thrown domain limit was recovered")
    } catch let failure as GlifiFailure {
        #expect(failure == expected)
    }
    #expect(levels == [.accurate])
}

@Test(
    "A failed fast attempt is final, including another resource failure",
    arguments: [GlifiFailureCategory.insufficientResources, .invalidInput, .cancelled])
func pdfOCRExecutionFastFailureIsFinal(_ category: GlifiFailureCategory) throws {
    let expected = ocrExecutionFailure(category, code: "test.fast-failed")
    var levels: [GlifiPDFOCRExecution.Level] = []
    do {
        let _: GlifiPDFOCRExecution.Selection<String> = try GlifiPDFOCRExecution.run(
            checkCancellation: {}
        ) { level in
            levels.append(level)
            return .failure(
                level == .accurate ? ocrExecutionFailure(.insufficientResources) : expected)
        }
        Issue.record("A failed fast attempt was recovered again")
    } catch let failure as GlifiFailure {
        #expect(failure == expected)
    }
    #expect(levels == [.accurate, .fast])
}

@Test(
    "Caller cancellation prevents the next native attempt or selected output",
    arguments: ["before", "between", "after-success"])
func pdfOCRExecutionChecksCancellation(_ timing: String) async throws {
    let task = Task {
        var levels: [GlifiPDFOCRExecution.Level] = []
        if timing == "before" { withUnsafeCurrentTask { $0?.cancel() } }
        do {
            let _: GlifiPDFOCRExecution.Selection<String> = try GlifiPDFOCRExecution.run(
                checkCancellation: {
                    if Task.isCancelled {
                        throw GlifiPDFVisionFailure.classify(
                            CancellationError(), code: "pdf.cancelled")
                    }
                }
            ) { level in
                levels.append(level)
                withUnsafeCurrentTask { $0?.cancel() }
                return timing == "after-success"
                    ? .success("must not be published")
                    : .failure(ocrExecutionFailure(.insufficientResources))
            }
            Issue.record("Cancelled OCR returned a selected result")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "pdf.cancelled")
            #expect(failure.category == .cancelled)
        }
        return levels
    }
    #expect(try await task.value == (timing == "before" ? [] : [.accurate]))
}

@Test(
    "The document request budget admits at most two native calls per allowed OCR page",
    arguments: [0, 1, 128, Int.max])
func pdfOCRExecutionDocumentBudgetPrecedesCalls(_ requestedPages: Int) throws {
    let limits = GlifiTextImportLimits(maximumByteCount: 0, maximumOCRPageCount: requestedPages)
    var budget = GlifiPDFOCRExecution.RequestBudget(limits: limits)
    var nativeCalls = 0
    for page in 0..<limits.maximumOCRPageCount {
        let selected = try GlifiPDFOCRExecution.run(checkCancellation: {}) { level in
            try budget.consume()
            nativeCalls += 1
            return level == .accurate
                ? Result<Int, GlifiFailure>.failure(ocrExecutionFailure(.insufficientResources))
                : .success(page)
        }
        #expect(selected.level == .fast && selected.value == page)
    }
    let expectedMaximum = requestedPages == 0 ? 0 : requestedPages == 1 ? 2 : 256
    #expect(budget.maximumRequestCount == expectedMaximum)
    #expect(budget.requestCount == expectedMaximum && nativeCalls == expectedMaximum)
    var rejectedLevels: [GlifiPDFOCRExecution.Level] = []
    do {
        let _: GlifiPDFOCRExecution.Selection<Int> = try GlifiPDFOCRExecution.run(
            checkCancellation: {}
        ) { level in
            rejectedLevels.append(level)
            try budget.consume()
            nativeCalls += 1
            return .success(-1)
        }
        Issue.record("An exhausted document budget admitted native work")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "pdf.ocr-request-limit")
        #expect(failure.category == .insufficientResources)
    }
    #expect(rejectedLevels == [.accurate])
    #expect(budget.requestCount == expectedMaximum && nativeCalls == expectedMaximum)
}

private func ocrExecutionFailure(
    _ category: GlifiFailureCategory, code: String = "test.native-failure"
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .importText,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.category.\(category.rawValue)")
}
