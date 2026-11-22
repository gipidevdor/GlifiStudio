// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Vision

/// Classifies backend errors without blaming valid documents for system-resource failures.
enum GlifiPDFVisionFailure {
    /// The caller supplies a constant context code and preserves its own domain validation failures.
    static func classify(
        _ error: any Error, code: String, isCancelled: Bool = false
    ) -> GlifiFailure {
        let category: GlifiFailureCategory
        if isCancelled || Task.isCancelled || error is CancellationError {
            category = .cancelled
        } else {
            let backendError = error as NSError
            if backendError.domain == VNErrorDomain,
                let visionCode = VNErrorCode(rawValue: backendError.code)
            {
                switch visionCode {
                case .requestCancelled:
                    category = .cancelled
                case .invalidFormat, .invalidImage:
                    category = .invalidInput
                case .notImplemented, .unsupportedRevision, .unsupportedRequest,
                    .unsupportedComputeStage, .unsupportedComputeDevice:
                    category = .unsupportedFormat
                case .turiCoreErrorCode, .OK, .operationFailed, .outOfBoundsError, .invalidOption,
                    .ioError, .missingOption, .internalError, .outOfMemory, .unknownError,
                    .invalidOperation, .invalidArgument, .invalidModel, .dataUnavailable,
                    .timeStampNotFound, .timeout, .resourceUnavailable, .resourceCorrupted:
                    // The built-in recognizer owns its model and request configuration.
                    // These failures do not establish that the source document is malformed.
                    category = .insufficientResources
                @unknown default:
                    category = .insufficientResources
                }
            } else {
                category = .insufficientResources
            }
        }
        return GlifiFailure(
            code: category == .cancelled ? "pdf.cancelled" : code,
            category: category, operation: .importText,
            retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
            retainedState: .unchanged,
            messageKey: "failure.category.\(category.rawValue)")
    }
}
