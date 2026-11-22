// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore
import Testing

@testable import GlifiKit

struct GlifiTextAnalysisFailureContractTests {
    @Test func successfulValuesPreserveIdentityAndRunOnce() throws {
        let original = AnalysisFailureContractValue()
        var calls = 0
        let result = try mapTextAnalysisFailure {
            calls += 1
            return original
        }
        #expect(result === original)
        #expect(calls == 1)
    }

    @Test func cancellationCheckingRemainsTheAnalysisBodysResponsibility() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try mapTextAnalysisFailure { Task.isCancelled }
        }
        #expect(try await task.value)
    }

    @Test func coreFailuresPreserveEveryField() {
        let core = GlifiFailure(
            code: "synthetic.capacity-limit", category: .insufficientResources,
            operation: .executePlan, retryDisposition: .afterConditionsChange,
            retainedState: .lastCommittedGeneration,
            messageKey: "failure.category.insufficientResources",
            arguments: ["operatingProfile": "protective"])
        do {
            let _: Int = try mapTextAnalysisFailure { throw core }
            Issue.record("The original domain failure was swallowed")
        } catch {
            #expect(
                error
                    == GlifiStudioFailure(
                        code: "synthetic.capacity-limit", category: "insufficientResources",
                        operation: "executePlan", retryDisposition: "afterConditionsChange",
                        retainedState: "lastCommittedGeneration",
                        messageKey: "failure.category.insufficientResources",
                        arguments: ["operatingProfile": "protective"]))
        }
    }

    @Test func cancellationRetainsTheCompleteAnalysisContract() {
        do {
            let _: Int = try mapTextAnalysisFailure { throw CancellationError() }
            Issue.record("Cancellation was swallowed")
        } catch {
            #expect(
                error
                    == GlifiStudioFailure(
                        code: "operation.cancelled", category: "cancelled", operation: "analyze",
                        retryDisposition: "newRequest", retainedState: "unchanged",
                        messageKey: "failure.category.cancelled"))
        }
    }

    @Test func unknownErrorsUseTheExistingFallbackWithoutPrivateDetails() {
        let canary = "private-analysis-canary"
        do {
            let _: Int = try mapTextAnalysisFailure {
                throw SyntheticAnalysisFailure.privateDetail(canary)
            }
            Issue.record("An unknown failure was swallowed")
        } catch {
            #expect(error == Self.unknownFailure)
            #expect(!String(describing: error).contains(canary))
        }
    }

    @Test func studioFailuresRetainTheExistingUnknownErrorPath() {
        let canary = "private-studio-canary"
        let original = GlifiStudioFailure(
            code: "synthetic.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled", arguments: ["detail": canary])
        do {
            let _: Int = try mapTextAnalysisFailure { throw original }
            Issue.record("An unexpected facade failure was swallowed")
        } catch {
            #expect(error == Self.unknownFailure)
            #expect(!String(describing: error).contains(canary))
        }
    }

    private static var unknownFailure: GlifiStudioFailure {
        GlifiStudioFailure(
            code: "analysis.failed", category: "insufficientData", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.insufficientData")
    }
}

private final class AnalysisFailureContractValue {}

private enum SyntheticAnalysisFailure: Error {
    case privateDetail(String)
}
