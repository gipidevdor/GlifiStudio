// SPDX-License-Identifier: BSD-3-Clause

/// Bounded selection between native OCR levels; only returned backend failures admit recovery.
enum GlifiPDFOCRExecution {
    enum Level: String, Sendable {
        case accurate
        case fast
    }

    struct Selection<Value> {
        let value: Value
        let level: Level
    }

    /// The public limits clamp OCR pages to 128, making the derived request ceiling at most 256.
    struct RequestBudget {
        let maximumRequestCount: Int
        private(set) var requestCount = 0

        init(limits: GlifiTextImportLimits) {
            maximumRequestCount = limits.maximumOCRPageCount * 2
        }

        mutating func consume() throws {
            guard requestCount < maximumRequestCount else {
                throw GlifiFailure(
                    code: "pdf.ocr-request-limit", category: .insufficientResources,
                    operation: .importText, retryDisposition: .afterConditionsChange,
                    retainedState: .unchanged, messageKey: "failure.category.insufficientResources")
            }
            requestCount += 1
        }
    }

    /// Preflight and validation errors must be thrown, never returned as a backend failure.
    static func run<Value>(
        checkCancellation: () throws -> Void,
        attempt: (Level) throws -> Result<Value, GlifiFailure>
    ) throws -> Selection<Value> {
        try checkCancellation()
        switch try attempt(.accurate) {
        case let .success(value):
            try checkCancellation()
            return Selection(value: value, level: .accurate)
        case let .failure(failure):
            guard failure.category == .insufficientResources else { throw failure }
        }
        try checkCancellation()
        switch try attempt(.fast) {
        case let .success(value):
            try checkCancellation()
            return Selection(value: value, level: .fast)
        case let .failure(failure):
            throw failure
        }
    }
}
