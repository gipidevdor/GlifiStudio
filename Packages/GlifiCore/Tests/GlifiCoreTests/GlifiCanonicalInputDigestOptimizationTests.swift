// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiBenchmarkTestSupport
import GlifiCore
import Testing

@Test("I digest degli input canonici conservano algebra, ordine, Unicode e missing")
func canonicalInputDigestPreservesCanonicalInputs() throws {
    for query in canonicalInputQueries() {
        let reference = try canonicalInputQueryReference(query)
        #expect(try query.canonicalData() == reference)
        #expect(try query.canonicalDigest() == canonicalInputFormatter(reference))
        #expect(try GlifiQueryAST.decode(reference) == query)
    }
    let first = GlifiQueryNode.term(field: .form, value: "città/β", matchMode: .exact)
    let second = GlifiQueryNode.term(field: .normalized, value: "mare", matchMode: .exact)
    #expect(
        try GlifiQueryAST(root: .and([first, second])).canonicalDigest()
            != GlifiQueryAST(root: .and([second, first])).canonicalDigest())
    // Identity encoding has never validated programmatically constructed nodes.
    let direct = GlifiQueryAST(root: .and([]))
    #expect(
        try direct.canonicalDigest()
            == canonicalInputFormatter(canonicalInputQueryReference(direct)))

    for level in [GlifiMeasurementLevel.nominal, .ordinal, .interval, .ratio] {
        let request = try canonicalInputAgreement(coders: 3, units: 17, level: level)
        let reference = try canonicalInputAgreementReference(request)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        #expect(try encoder.encode(request) == reference)
        #expect(try request.canonicalDigest() == canonicalInputFormatter(reference))
        #expect(
            try JSONDecoder().decode(GlifiCodingAgreementRequest.self, from: reference) == request)
        let reversed = try GlifiCodingAgreementRequest(
            coderIdentifiers: Array(request.coderIdentifiers.reversed()),
            units: request.units.map {
                GlifiCodingUnit(
                    unitIdentifier: $0.unitIdentifier, labels: Array($0.labels.reversed()))
            }, level: level)
        #expect(
            try reversed.canonicalDigest()
                == canonicalInputFormatter(canonicalInputAgreementReference(reversed)))
        #expect(try reversed.canonicalDigest() != request.canonicalDigest())
    }
    let nominal = try canonicalInputAgreement(coders: 2, units: 3, level: .nominal)
    var legacy = try #require(
        JSONSerialization.jsonObject(with: canonicalInputAgreementReference(nominal))
            as? [String: Any])
    legacy.removeValue(forKey: "level")
    let decoded = try JSONDecoder().decode(
        GlifiCodingAgreementRequest.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(decoded.level == .nominal)
    #expect(try decoded.canonicalDigest() == nominal.canonicalDigest())
}

@Test("Gli input canonici preservano i rifiuti tipizzati di decoder e costruttori")
func canonicalInputDigestPreservesExistingFailures() {
    canonicalInputExpectFailure("query.invalid-ast", operation: .query, retainedState: .unchanged) {
        _ = try GlifiQueryAST.decode(Data("{}".utf8))
    }
    canonicalInputExpectFailure(
        "query.invalid-boolean", operation: .query, retainedState: .unchanged
    ) {
        _ = try GlifiQueryAST.decode(GlifiQueryAST(root: .and([])).canonicalData())
    }
    canonicalInputExpectFailure("agreement.invalid-coders") {
        _ = try GlifiCodingAgreementRequest(
            coderIdentifiers: ["same", "same"],
            units: [GlifiCodingUnit(unitIdentifier: "unit", labels: ["x", "y"])])
    }
    canonicalInputExpectFailure("agreement.invalid-units") {
        _ = try GlifiCodingAgreementRequest(
            coderIdentifiers: ["a", "b"],
            units: [GlifiCodingUnit(unitIdentifier: "unit", labels: ["x"])])
    }
    canonicalInputExpectFailure("agreement.non-numeric-label") {
        _ = try GlifiCodingAgreementRequest(
            coderIdentifiers: ["a", "b"],
            units: [GlifiCodingUnit(unitIdentifier: "unit", labels: ["word", nil])],
            level: .interval)
    }
}

@Test("I produttori canonici misurano quattro scenari espliciti con riferimenti completi")
func canonicalInputDigestOptimizationBenchmarks() throws {
    let smallQueries = ["mare", "città", "e\u{301}/é", "日本語", "quoted\"/β", "line\r\nbreak"].map {
        GlifiQueryAST(root: .term(field: .normalized, value: $0, matchMode: .exact))
    }
    let smallAgreement = try canonicalInputAgreement(coders: 2, units: 16, level: .nominal)
    #expect(
        try smallQueries[0].canonicalDigest()
            == canonicalInputFormatter(canonicalInputQueryReference(smallQueries[0])))
    #expect(
        try smallAgreement.canonicalDigest()
            == canonicalInputFormatter(canonicalInputAgreementReference(smallAgreement)))
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    let largeQuery = GlifiQueryAST(
        root: .and(
            (0..<384).map { index in
                let term = GlifiQueryNode.term(
                    field: .normalized, value: "term-\(index)-città/β", matchMode: .exact)
                return index.isMultiple(of: 7) ? .not(term) : term
            }))
    #expect(try GlifiQueryAST.decode(canonicalInputQueryReference(largeQuery)) == largeQuery)
    for (identifier, queries, calls) in [
        ("canonical-input-query-small", smallQueries, 5_000),
        ("canonical-input-query-composed", [largeQuery], 64),
    ] {
        let referenceBytes = try queries.map(canonicalInputQueryReference)
        let referenceDigests = referenceBytes.map(canonicalInputFormatter)
        let expected = (0..<calls).map { referenceDigests[$0 % referenceDigests.count] }
        try measurePipelineOptimization(
            identifier: identifier,
            generator:
                "Explicit query-ast-v1 fixture pool; complete JSON reference bytes in pool order; "
                + "call i uses query i%\(queries.count); calls=\(calls); canonicalDigest including encoder and SHA-256",
            fixtureDigest: try pipelineBenchmarkDigest(
                CanonicalInputFixture(canonicalInputs: referenceBytes, calls: calls)),
            expected: expected,
            body: { try (0..<calls).map { try queries[$0 % queries.count].canonicalDigest() } },
            checksum: { try pipelineBenchmarkDigest($0) })
    }
    let largeAgreement = try canonicalInputAgreement(coders: 8, units: 2_000, level: .nominal)
    for (identifier, request, calls) in [
        ("canonical-input-agreement-small", smallAgreement, 1_000),
        ("canonical-input-agreement-large", largeAgreement, 16),
    ] {
        let referenceBytes = try canonicalInputAgreementReference(request)
        let referenceDigest = canonicalInputFormatter(referenceBytes)
        try measurePipelineOptimization(
            identifier: identifier,
            generator:
                "Explicit nominal coding table; \(request.coderIdentifiers.count) coders, \(request.units.count) units; "
                + "missing iff (unit+coder)%7==0; UTF-8 labels, ordered coder/unit IDs; calls=\(calls); "
                + "canonicalDigest including encoder and SHA-256",
            fixtureDigest: try pipelineBenchmarkDigest(
                CanonicalInputFixture(canonicalInputs: [referenceBytes], calls: calls)),
            expected: Array(repeating: referenceDigest, count: calls),
            body: { try (0..<calls).map { _ in try request.canonicalDigest() } },
            checksum: { try pipelineBenchmarkDigest($0) })
    }
}

private struct CanonicalInputFixture: Encodable {
    let canonicalInputs: [Data]
    let calls: Int
}

private func canonicalInputQueries() -> [GlifiQueryAST] {
    let uuid = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    let term = GlifiQueryNode.term(field: .form, value: "città/β\"", matchMode: .exact)
    let nodes: [GlifiQueryNode] = [
        .matchAll, term, .term(field: .normalized, value: "e\u{301}/é 日本語", matchMode: .exact),
        .phrase(field: .form, values: ["porto", "mare"], slop: 2),
        .regex(field: .form, pattern: "citt.*", flags: [.caseInsensitive, .canonicalEquivalence]),
        .range(
            field: .init(rawValue: "metadata.anno"),
            value: GlifiQueryRange(
                lower: "2020", upper: "2024", includesLower: true, includesUpper: false)),
        .range(
            field: .documentTitle,
            value: GlifiQueryRange(
                lower: nil, upper: "z", includesLower: false, includesUpper: true)),
        .exists(field: .documentTitle),
        .proximity(
            left: term, right: .not(.matchAll), distance: 3, unit: .surfaceToken, ordered: true),
        .not(term), .and([term, .matchAll]), .or([.matchAll, term]),
        .within(term, scope: .project(ProjectID(uuid: uuid))),
        .within(term, scope: .corpus(CorpusVersionID(uuid: uuid))),
        .within(term, scope: .sourceRevision(SourceRevisionID(uuid: uuid))),
    ]
    return nodes.map { GlifiQueryAST(root: $0) } + [GlifiQueryAST(root: .and(nodes))]
}

private func canonicalInputAgreement(
    coders: Int, units: Int, level: GlifiMeasurementLevel
) throws -> GlifiCodingAgreementRequest {
    try GlifiCodingAgreementRequest(
        coderIdentifiers: (0..<coders).map { "coder-\($0)-β" },
        units: (0..<units).map { unit in
            GlifiCodingUnit(
                unitIdentifier: "unit-\(unit)-città/日本語",
                labels: (0..<coders).map { coder in
                    guard !(unit + coder).isMultiple(of: 7) else { return nil }
                    return level == .nominal
                        ? "città,\"β\"/e\u{301}-\((unit + coder) % 5)"
                        : String((unit + coder) % 5 + 1)
                })
        }, level: level)
}

private func canonicalInputQueryReference(_ query: GlifiQueryAST) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: [
            "schema": query.schema, "schemaVersion": query.schemaVersion,
            "grammarVersion": query.grammarVersion, "root": canonicalInputNodeReference(query.root),
        ], options: [.sortedKeys, .withoutEscapingSlashes])
}

/// Explicit v1 tagged algebra; no production encoder or canonicalData is reused.
private func canonicalInputNodeReference(_ node: GlifiQueryNode) -> [String: Any] {
    func field(_ value: GlifiQueryField) -> String { value.rawValue }
    switch node {
    case .matchAll: return ["type": "matchAll"]
    case let .term(value, text, mode):
        return ["type": "term", "field": field(value), "value": text, "matchMode": mode.rawValue]
    case let .phrase(value, texts, slop):
        return ["type": "phrase", "field": field(value), "values": texts, "slop": slop]
    case let .regex(value, pattern, flags):
        return [
            "type": "regex", "field": field(value), "pattern": pattern,
            "flags": flags.rawValue,
        ]
    case let .range(value, range):
        var bounds: [String: Any] = [
            "includesLower": range.includesLower, "includesUpper": range.includesUpper,
        ]
        if let lower = range.lower { bounds["lower"] = lower }
        if let upper = range.upper { bounds["upper"] = upper }
        return ["type": "range", "field": field(value), "range": bounds]
    case let .exists(value): return ["type": "exists", "field": field(value)]
    case let .proximity(left, right, distance, unit, ordered):
        return [
            "type": "proximity", "left": canonicalInputNodeReference(left),
            "right": canonicalInputNodeReference(right), "distance": distance,
            "unit": unit.rawValue, "ordered": ordered,
        ]
    case let .not(child): return ["type": "not", "child": canonicalInputNodeReference(child)]
    case let .and(children):
        return ["type": "and", "children": children.map(canonicalInputNodeReference)]
    case let .or(children):
        return ["type": "or", "children": children.map(canonicalInputNodeReference)]
    case let .within(child, scope):
        let identity: [String: String]
        switch scope {
        case let .project(id): identity = ["type": "project", "id": id.canonicalValue]
        case let .corpus(id): identity = ["type": "corpus", "id": id.canonicalValue]
        case let .sourceRevision(id):
            identity = ["type": "sourceRevision", "id": id.canonicalValue]
        }
        return ["type": "within", "child": canonicalInputNodeReference(child), "scope": identity]
    }
}

private func canonicalInputAgreementReference(_ request: GlifiCodingAgreementRequest) throws -> Data
{
    let units: [[String: Any]] = request.units.map { unit in
        [
            "unitIdentifier": unit.unitIdentifier,
            "labels": unit.labels.map { label -> Any in label.map { $0 as Any } ?? NSNull() },
        ]
    }
    return try JSONSerialization.data(
        withJSONObject: [
            "coderIdentifiers": request.coderIdentifiers, "units": units,
            "level": request.level.rawValue,
        ],
        options: [.sortedKeys, .withoutEscapingSlashes])
}

private func canonicalInputFormatter(_ bytes: Data) -> String {
    "sha256:" + SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}

private func canonicalInputExpectFailure(
    _ code: String, operation: GlifiOperationKind = .analyze,
    retainedState: GlifiRetainedState = .lastCommittedGeneration,
    body: () throws -> Void
) {
    do {
        try body()
        Issue.record("Expected the established typed input failure")
    } catch let failure as GlifiFailure {
        #expect(
            failure
                == GlifiFailure(
                    code: code, category: .invalidInput, operation: operation,
                    retryDisposition: .afterCorrection, retainedState: retainedState,
                    messageKey: "failure.\(code)"))
    } catch {
        Issue.record("Unexpected input failure: \(error)")
    }
}
