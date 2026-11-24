// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiCommandJSONTests {
    @Test func anUnencodableResultUsesTheInternalFailureTaxonomy() {
        do {
            _ = try GlifiStudioCommandResult([Double.nan])
            Issue.record("An invalid numerical result was accepted")
        } catch {
            #expect(error.code == "command.invalid-result")
            #expect(error.category == "invariantViolation")
            #expect(error.retryDisposition == "never")
            #expect(error.retainedState == "validityUnknown")
            #expect(error.arguments.isEmpty)
        }
    }

    @Test func resultEncodingPreservesIntegerExtremesBooleansAndBinary64Values() throws {
        let payload = CommandNumericPayload(
            seed: .max, minimum: .min, enabled: true,
            measurements: [
                -0.0, .leastNonzeroMagnitude, -.leastNonzeroMagnitude,
                .greatestFiniteMagnitude, -.greatestFiniteMagnitude, 1.5,
            ],
            missing: [nil, 0], labels: ["è/uno", "\"citazione\"", "𝄞"], empty: [:])
        let wrapped = try GlifiStudioCommandResult(payload)
        let reencoded = try CommandJSON.encode(wrapped)
        let decoded = try JSONDecoder().decode(CommandNumericPayload.self, from: reencoded)
        #expect(decoded.seed == UInt64.max)
        #expect(decoded.minimum == Int64.min)
        #expect(decoded.enabled)
        #expect(decoded.labels == payload.labels)
        #expect(decoded.missing == payload.missing)
        #expect(decoded.empty.isEmpty)
        #expect(
            decoded.measurements.map(\.bitPattern) == payload.measurements.map(\.bitPattern))
    }

    @Test func strictDecodingRejectsUnknownNestedFieldsWithoutLeakingTheirValues() throws {
        let valid = Data(#"{"members":[{"value":1}],"missing":[null,2]}"#.utf8)
        let decoded = try CommandJSON.decodeStrict(CommandNestedPayload.self, from: valid)
        #expect(decoded.members.map(\.value) == [1])
        #expect(decoded.missing == [nil, 2])
        for json in [
            #"{"members":[{"value":1,"secret-canary":7}],"missing":[]}"#,
            #"{"members":[{"value":1}],"missing":[],"secret-canary":"/private/canary"}"#,
        ] {
            do {
                _ = try CommandJSON.decodeStrict(CommandNestedPayload.self, from: Data(json.utf8))
                Issue.record("An unknown request field was accepted")
            } catch {
                #expect(error.code == "command.unknown-field")
                #expect(error.category == "invalidInput")
                #expect(error.arguments.isEmpty)
                #expect(!error.code.contains("canary"))
            }
        }
    }

    @Test func preflightEnforcesByteDepthAndDecodedDuplicateKeyLimits() throws {
        let maximum = GlifiStudioTextAnalysisRequest.maximumRequestBytes
        var boundary = Data(repeating: 0x20, count: maximum - 2)
        boundary.append(contentsOf: Data("{}".utf8))
        #expect(try CommandJSON.decode([String: Int].self, from: boundary).isEmpty)
        boundary.append(0x20)
        do {
            try CommandJSON.validate(boundary)
            Issue.record("An oversized request was accepted")
        } catch {
            #expect(error.category == "insufficientResources")
            #expect(error.arguments.isEmpty)
        }
        try CommandJSON.validate(
            Data(
                (String(repeating: "[", count: 32) + "0"
                    + String(repeating: "]", count: 32)).utf8))
        #expect(throws: GlifiStudioFailure.self) {
            try CommandJSON.validate(
                Data(
                    (String(repeating: "[", count: 33) + "0"
                        + String(repeating: "]", count: 33)).utf8))
        }
        #expect(throws: GlifiStudioFailure.self) {
            try CommandJSON.decode(
                [String: Int].self, from: Data(#"{"seed":1,"\u0073eed":2}"#.utf8))
        }
        #expect(throws: GlifiStudioFailure.self) {
            try CommandJSON.decode([String: Int].self, from: Data([0xFF]))
        }
    }

    @Test func cancelledJSONEntryPointsPreserveCancellationBeforeMalformedInput() async {
        let statistics = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioStatisticsWorkbench.evaluate(json: Data("{".utf8))
        }
        let operators = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioCoreOperators.execute(json: Data("{".utf8))
        }
        do {
            _ = try await statistics.value
            Issue.record("The statistical JSON entry point ignored cancellation")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retryDisposition == "newRequest")
        } catch { Issue.record("Unexpected failure: \(error)") }
        do {
            _ = try await operators.value
            Issue.record("The operator JSON entry point ignored cancellation")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retryDisposition == "newRequest")
        } catch { Issue.record("Unexpected failure: \(error)") }
    }
}

private struct CommandNumericPayload: Codable {
    let seed: UInt64
    let minimum: Int64
    let enabled: Bool
    let measurements: [Double]
    let missing: [Double?]
    let labels: [String]
    let empty: [String: Double]
}

private struct CommandNestedPayload: Codable {
    struct Member: Codable {
        let value: Int
    }
    let members: [Member]
    let missing: [Double?]
}
