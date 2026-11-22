// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Preserves the shared stateless text-analysis failure contract.
func mapTextAnalysisFailure<Value>(
    _ body: () throws -> Value
) throws(GlifiStudioFailure) -> Value {
    do { return try body() } catch let failure as GlifiFailure {
        throw GlifiStudioFailure(failure)
    } catch is CancellationError {
        throw GlifiStudioFailure(
            code: "operation.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled"
        )
    } catch {
        throw GlifiStudioFailure(
            code: "analysis.failed", category: "insufficientData", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.insufficientData"
        )
    }
}
