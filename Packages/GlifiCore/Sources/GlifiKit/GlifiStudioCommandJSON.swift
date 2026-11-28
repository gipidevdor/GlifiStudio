// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// A complete GlifiKit result that can cross a JSON transport without changing its values.
public struct GlifiStudioCommandResult: Encodable, Sendable {
    /// Sorted-key JSON of the original result, including exact integer identities and seeds.
    public let json: Data
    private let value: CommandJSONValue

    init<Value: Encodable>(_ value: Value) throws(GlifiStudioFailure) {
        do {
            json = try CommandJSON.encode(value)
            self.value = try JSONDecoder().decode(CommandJSONValue.self, from: json)
        } catch {
            throw commandFailure("invalid-result", category: "invariantViolation")
        }
    }

    /// Encodes the original object rather than a base64 representation of its bytes.
    public func encode(to encoder: any Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// Shared decoding for CLI and native JSON entry points; file access stays in the client.
enum CommandJSON {
    static func validate(
        _ json: Data, maximumByteCount: Int = GlifiStudioTextAnalysisRequest.maximumRequestBytes
    ) throws(GlifiStudioFailure) {
        guard !Task.isCancelled else { throw commandFailure("cancelled", category: "cancelled") }
        do {
            try TextAnalysisJSON.check(json, maximumByteCount: maximumByteCount)
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw commandFailure("invalid-request")
        }
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type, from json: Data,
        maximumByteCount: Int = GlifiStudioTextAnalysisRequest.maximumRequestBytes
    ) throws(GlifiStudioFailure) -> Value {
        try validate(json, maximumByteCount: maximumByteCount)
        do {
            return try JSONDecoder().decode(type, from: json)
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw commandFailure("invalid-request")
        }
    }

    /// Existing Codable request DTOs are transported intact; unknown input keys never disappear.
    static func decodeStrict<Value: Codable>(
        _ type: Value.Type, from json: Data,
        maximumByteCount: Int = GlifiStudioTextAnalysisRequest.maximumRequestBytes
    ) throws(GlifiStudioFailure) -> Value {
        let value = try decode(type, from: json, maximumByteCount: maximumByteCount)
        let canonical = try encode(value)
        do {
            let original = try JSONSerialization.jsonObject(
                with: json, options: [.fragmentsAllowed])
            let resolved = try JSONSerialization.jsonObject(
                with: canonical, options: [.fragmentsAllowed])
            guard preservesKeys(original, resolved) else {
                throw commandFailure("unknown-field")
            }
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw commandFailure("invalid-request")
        }
        return value
    }

    /// Canonicalizes captured output without changing exact integers or signed zero.
    static func canonicalize(_ json: Data, maximumByteCount: Int) throws(GlifiStudioFailure) -> Data
    {
        do {
            try TextAnalysisJSON.check(json, maximumByteCount: maximumByteCount)
            return try encode(JSONDecoder().decode(CommandJSONValue.self, from: json))
        } catch let failure as GlifiStudioFailure { throw failure } catch {
            throw commandFailure("invalid-json-value")
        }
    }

    static func encode<Value: Encodable>(_ value: Value) throws(GlifiStudioFailure) -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(value)
        } catch {
            throw commandFailure("invalid-json-value")
        }
    }

    private static func preservesKeys(_ original: Any, _ resolved: Any) -> Bool {
        if let original = original as? [String: Any] {
            guard let resolved = resolved as? [String: Any] else { return false }
            return original.allSatisfy { key, value in
                guard let counterpart = resolved[key] else { return false }
                return preservesKeys(value, counterpart)
            }
        }
        if let original = original as? [Any] {
            guard let resolved = resolved as? [Any], original.count == resolved.count else {
                return false
            }
            return zip(original, resolved).allSatisfy { preservesKeys($0, $1) }
        }
        return true
    }
}

extension GlifiStudioStatisticsWorkbench {
    /// Decodes the same request DTO used by native callers and evaluates it without CLI defaults.
    @concurrent public static func evaluate(json: Data)
        async throws(GlifiStudioFailure) -> GlifiStudioStatisticsResult
    {
        try await evaluate(CommandJSON.decodeStrict(GlifiStudioStatisticsRequest.self, from: json))
    }
}

extension GlifiStudioCoreOperators {
    /// Decodes the same request DTO used by native callers and executes it without CLI defaults.
    @concurrent public static func execute(json: Data)
        async throws(GlifiStudioFailure) -> GlifiStudioCoreOperatorResult
    {
        try await execute(CommandJSON.decodeStrict(GlifiStudioCoreOperatorRequest.self, from: json))
    }
}

func commandFailure(_ code: String, category: String = "invalidInput") -> GlifiStudioFailure {
    let category = GlifiFailureCategory(rawValue: category) ?? .invariantViolation
    return GlifiStudioFailure(
        GlifiFailure(
            code: "command.\(code)", category: category, operation: .analyze,
            retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
            retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
            messageKey: "failure.category.\(category.rawValue)"))
}

private indirect enum CommandJSONValue: Codable, Sendable {
    case object([String: CommandJSONValue])
    case array([CommandJSONValue])
    case string(String)
    case boolean(Bool)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case number(Double)
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self), value == 0, value.sign == .minus {
            self = .number(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(UInt64.self) {
            self = .unsignedInteger(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: Self].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([Self].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .boolean(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .unsignedInteger(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
