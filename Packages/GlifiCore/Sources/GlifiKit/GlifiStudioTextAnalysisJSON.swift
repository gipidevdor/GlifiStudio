// SPDX-License-Identifier: BSD-3-Clause

import Foundation

// Grammar and scalar types are checked by JSONDecoder. This preflight bounds nesting and
// rejects duplicate decoded object keys before Foundation can discard their ambiguity.
enum TextAnalysisJSON {
    private struct Scope {
        let opening: UInt8
        var expectsKey: Bool
        var keys: Set<String> = []
    }

    static func check(_ data: Data) throws {
        guard data.count <= GlifiStudioTextAnalysisRequest.maximumRequestBytes else {
            throw textRequestFailure(
                "text-analysis.request-limit", category: "insufficientResources")
        }
        guard !data.isEmpty, String(data: data, encoding: .utf8) != nil else {
            throw textRequestFailure("text-analysis.invalid-request")
        }
        let bytes = Array(data)
        var stack: [Scope] = []
        var index = 0
        while index < bytes.count {
            switch bytes[index] {
            case 0x7B, 0x5B:
                guard stack.count < 32 else {
                    throw textRequestFailure(
                        "text-analysis.depth-limit", category: "insufficientResources")
                }
                stack.append(Scope(opening: bytes[index], expectsKey: bytes[index] == 0x7B))
                index += 1
            case 0x7D, 0x5D:
                guard let scope = stack.popLast(),
                    (scope.opening == 0x7B && bytes[index] == 0x7D)
                        || (scope.opening == 0x5B && bytes[index] == 0x5D)
                else { throw textRequestFailure("text-analysis.invalid-request") }
                index += 1
            case 0x2C:
                if !stack.isEmpty && stack[stack.count - 1].opening == 0x7B {
                    stack[stack.count - 1].expectsKey = true
                }
                index += 1
            case 0x3A:
                if !stack.isEmpty { stack[stack.count - 1].expectsKey = false }
                index += 1
            case 0x22:
                let start = index
                index += 1
                var terminated = false
                while index < bytes.count {
                    if bytes[index] == 0x5C {
                        index += 2
                    } else if bytes[index] == 0x22 {
                        index += 1
                        terminated = true
                        break
                    } else {
                        index += 1
                    }
                }
                guard terminated else { throw textRequestFailure("text-analysis.invalid-request") }
                if !stack.isEmpty && stack[stack.count - 1].opening == 0x7B
                    && stack[stack.count - 1].expectsKey
                {
                    let key = try JSONDecoder().decode(
                        String.self, from: Data(bytes[start..<index]))
                    guard stack[stack.count - 1].keys.insert(key).inserted else {
                        throw textRequestFailure("text-analysis.duplicate-key")
                    }
                    stack[stack.count - 1].expectsKey = false
                }
            default:
                index += 1
            }
        }
        guard stack.isEmpty else { throw textRequestFailure("text-analysis.invalid-request") }
    }
}

// Counts aggregate collections before canonical encoding or running an operator.
// Algorithm-specific work/output budgets remain enforced by the native engine.
struct TextAnalysisBudget {
    private var bytes = GlifiStudioTextAnalysisRequest.maximumRequestBytes
    private var elements = 250_000

    mutating func string(_ value: String) throws {
        let count = value.utf8.count
        guard count <= bytes else { throw limit() }
        bytes -= count
    }

    mutating func strings(_ values: [String]) throws {
        try consume(values.count)
        for value in values { try string(value) }
    }

    mutating func optionalStrings(_ values: [String?]) throws {
        try consume(values.count)
        for value in values {
            if let value { try string(value) }
        }
    }

    mutating func matrix(_ values: [[Double]]) throws {
        guard values.count <= 20_000 else { throw limit() }
        try consume(values.count)
        for row in values {
            try consume(row.count)
            guard row.allSatisfy(\.isFinite) else {
                throw textRequestFailure("text-analysis.non-finite")
            }
        }
    }

    mutating func documents(_ values: [[String]]) throws {
        guard values.count <= 20_000 else { throw limit() }
        try consume(values.count)
        for document in values { try strings(document) }
    }

    mutating func units(_ values: [GlifiStudioAutomaticCodingUnit]) throws {
        guard values.count <= 20_000 else { throw limit() }
        try consume(values.count)
        for unit in values {
            try string(unit.id)
            try string(unit.text)
            try consume(unit.variables.count)
            for (key, value) in unit.variables {
                try string(key)
                try string(value)
            }
        }
    }

    private mutating func consume(_ count: Int) throws {
        guard count <= elements else { throw limit() }
        elements -= count
    }

    private func limit() -> GlifiStudioFailure {
        textRequestFailure("text-analysis.collection-limit", category: "insufficientResources")
    }
}
