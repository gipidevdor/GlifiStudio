// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Versioned envelopes preserve the native command bytes without pretending they are text requests.
package enum GlifiWorkbenchCaptureEnvelope {
    package struct Request: Codable, Sendable {
        package let schema: String
        package let schemaVersion: Int
        package let command: String
        package let operation: String
        package let payloadJSON: Data
        package init(command: String, operation: String, payloadJSON: Data) {
            schema = "studio.glifi.workbench-capture-request"
            schemaVersion = 1
            self.command = command
            self.operation = operation
            self.payloadJSON = payloadJSON
        }
    }
    package struct Result: Codable, Sendable {
        package let schema: String
        package let schemaVersion: Int
        package let command: String
        package let operation: String
        package let requestDigest: String
        package let methodIdentifier: String
        package let capturePolicyIdentifier: String
        package let payloadJSON: Data
        package init(
            command: String, operation: String, requestJSON: Data,
            methodIdentifier: String, payloadJSON: Data
        ) {
            schema = "studio.glifi.workbench-capture-result"
            schemaVersion = 1
            self.command = command
            self.operation = operation
            requestDigest = SHA256.hash(data: requestJSON).map { String(format: "%02x", $0) }
                .joined()
            self.methodIdentifier = methodIdentifier
            capturePolicyIdentifier = "captured-output-not-reexecuted-v1"
            self.payloadJSON = payloadJSON
        }
    }

    package static func validate(requestJSON: Data, resultJSON: Data, methodIdentifier: String)
        throws
    {
        let request = try JSONDecoder().decode(Request.self, from: requestJSON)
        let result = try JSONDecoder().decode(Result.self, from: resultJSON)
        let rawRequest = try JSONDecoder().decode(RawRequest.self, from: request.payloadJSON)
        let rawResult = try JSONDecoder().decode(RawResult.self, from: result.payloadJSON)
        guard request.schema == "studio.glifi.workbench-capture-request",
            request.schemaVersion == 1,
            result.schema == "studio.glifi.workbench-capture-result", result.schemaVersion == 1,
            ["statistics", "operator", "evaluation"].contains(request.command),
            request.command == result.command, request.operation == result.operation,
            rawRequest.operation == request.operation, !request.operation.isEmpty,
            request.payloadJSON.count <= 1_048_576, result.payloadJSON.count <= 8 * 1_048_576,
            !methodIdentifier.isEmpty, methodIdentifier.utf8.count <= 4_096,
            result.methodIdentifier == methodIdentifier,
            result.capturePolicyIdentifier == "captured-output-not-reexecuted-v1",
            result.requestDigest
                == SHA256.hash(data: requestJSON).map({ String(format: "%02x", $0) }).joined()
        else { throw savedResearchFailure("research.invalid-workbench-capture") }
        switch request.command {
        case "statistics":
            guard rawResult.request?.operation == request.operation,
                rawResult.methodIdentifier == methodIdentifier, rawResult.requestDigest != nil
            else { throw savedResearchFailure("research.invalid-workbench-capture") }
        case "operator":
            guard rawResult.schema == "studio.glifi.core-operator-result",
                rawResult.schemaVersion == 1,
                rawResult.request?.operation == request.operation,
                rawResult.validationStatus == "candidate",
                let methods = rawResult.methodIdentifiers, !methods.isEmpty,
                methods.allSatisfy({ !$0.isEmpty }),
                methods.joined(separator: " + ") == methodIdentifier
            else { throw savedResearchFailure("research.invalid-workbench-capture") }
        case "evaluation":
            guard rawRequest.schema == "studio.glifi.evaluation-command-request",
                rawRequest.schemaVersion == 1,
                rawResult.methodIdentifier == methodIdentifier
            else { throw savedResearchFailure("research.invalid-workbench-capture") }
        default: throw savedResearchFailure("research.incompatible-capture-transport")
        }
    }
}

private struct RawRequest: Decodable {
    let schema: String?
    let schemaVersion: Int?
    let operation: String
}

private struct RawResult: Decodable {
    let schema: String?
    let schemaVersion: Int?
    let request: RawRequest?
    let requestDigest: String?
    let methodIdentifier: String?
    let methodIdentifiers: [String]?
    let validationStatus: String?
}
