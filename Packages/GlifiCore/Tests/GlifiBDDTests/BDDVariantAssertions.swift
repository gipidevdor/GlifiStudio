// SPDX-License-Identifier: BSD-3-Clause

import CoreFoundation
import Foundation
import GlifiKit
import Testing

/// Assertions over declared fixture facts; this helper does not compute analytical reference outputs.
enum BDDVariantAssertions {
    static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func object(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func expectFacts(_ source: Any, json: String) throws {
        let facts = try #require(try object(Data(json.utf8)) as? [String: Any])
        try #require(!facts.isEmpty)
        for path in facts.keys.sorted() {
            let expected = try #require(facts[path])
            try expectEquivalent(value(source, at: path), expected, path: path)
        }
    }

    static func value(_ source: Any, at path: String) throws -> Any {
        var current = source
        for part in path.split(separator: ".") {
            if part == "$value" {
                continue
            } else if part == "$squaredWeightNorms" {
                let cells = try #require(current as? [[String: Any]])
                var sums: [Int: Double] = [:]
                for cell in cells {
                    let row = try #require(cell["rowIndex"] as? Int)
                    let weight = try #require(cell["weight"] as? Double)
                    try #require(row >= 0 && row < 200 && weight.isFinite)
                    sums[row, default: 0] += weight * weight
                }
                current = sums.keys.sorted().map { sums[$0, default: 0] }
            } else if part == "$count" {
                current = try #require(current as? [Any]).count
            } else if part == "$distinctCount" {
                let values = try #require(current as? [NSNumber])
                try #require(values.allSatisfy { $0.doubleValue == Double($0.intValue) })
                current = Set(values.map(\.intValue)).count
            } else if part.hasPrefix("$has:") {
                let fields = try #require(current as? [String: Any])
                current = fields[String(part.dropFirst(5))] != nil
            } else if part == "$sum" {
                let values = try #require(current as? [NSNumber])
                try #require(values.allSatisfy { CFGetTypeID($0) != CFBooleanGetTypeID() })
                current = values.reduce(0) { $0 + $1.doubleValue }
            } else if part == "$centroid" {
                if let points = current as? [[String: Double]] {
                    try #require(!points.isEmpty)
                    let xs = try points.map { try #require($0["x"]) }
                    let ys = try points.map { try #require($0["y"]) }
                    current = [
                        xs.reduce(0, +) / Double(points.count),
                        ys.reduce(0, +) / Double(points.count),
                    ]
                } else {
                    let rows = try #require(current as? [[Double]])
                    let first = try #require(rows.first)
                    try #require(!first.isEmpty && rows.allSatisfy { $0.count == first.count })
                    current = first.indices.map { column in
                        rows.reduce(0) { $0 + $1[column] } / Double(rows.count)
                    }
                }
            } else if part == "$insideUnitSquare" {
                let points = try #require(current as? [[String: Double]])
                try #require(!points.isEmpty)
                current = try points.allSatisfy {
                    let x = try #require($0["x"])
                    let y = try #require($0["y"])
                    return x.isFinite && y.isFinite && abs(x) <= 1 && abs(y) <= 1
                }
            } else if let dictionary = current as? [String: Any] {
                current = try #require(dictionary[String(part)], Comment(rawValue: path))
            } else {
                let values = try #require(current as? [Any], Comment(rawValue: path))
                let index = try #require(Int(part))
                try #require(values.indices.contains(index), Comment(rawValue: path))
                current = values[index]
            }
        }
        return current
    }

    static func expectEquivalent(_ actual: Any, _ expected: Any, path: String = "result") throws {
        if expected is NSNull {
            #expect(actual is NSNull, Comment(rawValue: path))
        } else if let expected = expected as? NSNumber {
            let actual = try #require(actual as? NSNumber, Comment(rawValue: path))
            let expectedBoolean = CFGetTypeID(expected) == CFBooleanGetTypeID()
            try #require((CFGetTypeID(actual) == CFBooleanGetTypeID()) == expectedBoolean)
            if expectedBoolean {
                #expect(actual.boolValue == expected.boolValue, Comment(rawValue: path))
            } else {
                let reference = expected.doubleValue
                let observed = actual.doubleValue
                try #require(reference.isFinite)
                #expect(observed.isFinite, Comment(rawValue: path))
                #expect(
                    abs(observed - reference) <= 1e-12 + 1e-12 * abs(reference),
                    Comment(rawValue: path))
            }
        } else if let expected = expected as? String {
            #expect(try #require(actual as? String) == expected, Comment(rawValue: path))
        } else if let expected = expected as? [Any] {
            let actual = try #require(actual as? [Any], Comment(rawValue: path))
            try #require(actual.count == expected.count, Comment(rawValue: path))
            for index in expected.indices {
                try expectEquivalent(actual[index], expected[index], path: "\(path).\(index)")
            }
        } else {
            let expected = try #require(expected as? [String: Any])
            let actual = try #require(actual as? [String: Any], Comment(rawValue: path))
            for key in expected.keys.sorted() {
                try expectEquivalent(
                    #require(actual[key]), #require(expected[key]), path: "\(path).\(key)")
            }
        }
    }

    static func expectFailure(
        _ failure: GlifiStudioFailure?, result: Data?, code: String, category: String,
        retainedState: String = "unchanged", operation: String = "analyze"
    ) throws {
        let failure = try #require(failure)
        #expect(failure.code == code)
        #expect(failure.category == category)
        #expect(failure.operation == operation)
        #expect(failure.retainedState == retainedState)
        #expect(
            failure.retryDisposition == (category == "cancelled" ? "newRequest" : "afterCorrection")
        )
        #expect(failure.arguments.isEmpty)
        #expect(result == nil)
    }
}
