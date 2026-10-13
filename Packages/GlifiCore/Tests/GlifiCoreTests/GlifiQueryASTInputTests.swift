// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("QueryAST JSON conserva algebra, digest e serializzazione canonica")
func queryASTInputRoundTrips() throws {
    for text in [
        "normalized:città", "casa OR mare AND NOT acqua", "casa BEFORE/2 mare",
        "form:/citt.*/ic", "\"casa sul mare\"~2", "metadata.anno:[2020 TO 2024}",
    ] {
        let original = try GlifiQueryParser().parse(text)
        let data = try original.canonicalData()
        let decoded = try GlifiQueryAST.decode(data)
        #expect(decoded == original)
        #expect(try decoded.canonicalDigest() == original.canonicalDigest())
    }
}

@Test("QueryAST JSON applica i limiti esatti di byte, nodi e profondità")
func queryASTInputEnforcesBoundaries() throws {
    let leaf = GlifiQueryNode.matchAll
    let ast = GlifiQueryAST(root: .and([.not(leaf), leaf]))
    let data = try ast.canonicalData()
    #expect(
        try GlifiQueryAST.decode(
            data, limits: astInputLimits(bytes: data.count, depth: 2, nodes: 4))
            == ast)
    try expectASTFailure(
        data, limits: astInputLimits(bytes: data.count - 1), code: "query.byte-limit-exceeded")
    try expectASTFailure(data, limits: astInputLimits(depth: 1), code: "query.depth-limit-exceeded")
    try expectASTFailure(data, limits: astInputLimits(nodes: 3), code: "query.node-limit-exceeded")
    try expectASTFailure(
        GlifiQueryAST(root: leaf).canonicalData(), limits: astInputLimits(nodes: 0),
        code: "query.node-limit-exceeded")
    #expect(
        try GlifiQueryAST.decode(
            GlifiQueryAST(root: leaf).canonicalData(), limits: astInputLimits(depth: 0)
        ).root == leaf)
}

@Test(
    "Il budget di decodifica copre figli, array, prossimità e scope prima di costruire alberi profondi"
)
func queryASTInputBoundsEveryRecursiveEdge() throws {
    let leaf = GlifiQueryNode.matchAll
    let revision = SourceRevisionID()
    let roots: [GlifiQueryNode] = [
        .not(leaf), .and([leaf, leaf]), .or([leaf, leaf]),
        .within(leaf, scope: .sourceRevision(revision)),
        .proximity(left: leaf, right: leaf, distance: 1, unit: .surfaceToken, ordered: false),
    ]
    for root in roots {
        let data = try GlifiQueryAST(root: root).canonicalData()
        #expect(try GlifiQueryAST.decode(data, limits: astInputLimits(depth: 1)).root == root)
        try expectASTFailure(
            data, limits: astInputLimits(depth: 0), code: "query.depth-limit-exceeded")
    }
    var deep = leaf
    for _ in 0..<200 { deep = .not(deep) }
    try expectASTFailure(
        GlifiQueryAST(root: deep).canonicalData(), code: "query.depth-limit-exceeded")
    let wide = GlifiQueryAST(root: .or(Array(repeating: leaf, count: 1_024)))
    try expectASTFailure(wide.canonicalData(), code: "query.node-limit-exceeded")
}

@Test("QueryAST JSON rifiuta schema, grammatica e input malformato senza contenuto diagnostico")
func queryASTInputRejectsInvalidEnvelopes() throws {
    let data = try GlifiQueryAST(root: .matchAll).canonicalData()
    for (key, value) in [
        ("schema", "unknown" as Any), ("schemaVersion", 2 as Any),
        ("grammarVersion", "unknown" as Any),
    ] {
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json[key] = value
        try expectASTFailure(
            JSONSerialization.data(withJSONObject: json), code: "query.incompatible-ast")
    }
    for invalid in [Data(), Data("ZQXCANARY42".utf8), Data("{}".utf8), Data([0xFF])] {
        try expectASTFailure(invalid, code: "query.invalid-ast")
    }
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    json["root"] = [
        "type": "within", "child": ["type": "matchAll"],
        "scope": ["type": "sourceRevision", "id": "ZQXCANARY42"],
    ]
    try expectASTFailure(JSONSerialization.data(withJSONObject: json), code: "query.invalid-ast")
}

@Test("QueryAST JSON non aggira gli invarianti semantici e i flag regex ammessi")
func queryASTInputRejectsInvalidNodes() throws {
    for (root, code) in [
        (GlifiQueryNode.and([]), "query.invalid-boolean"),
        (.term(field: .form, value: "", matchMode: .exact), "query.invalid-term"),
        (
            .term(field: GlifiQueryField(rawValue: "unknown"), value: "a", matchMode: .exact),
            "query.unknown-field"
        ),
        (.phrase(field: .form, values: ["a"], slop: -1), "query.invalid-phrase"),
        (
            .regex(field: .form, pattern: "a", flags: GlifiRegexFlags(rawValue: 4)),
            "query.regex-rejected"
        ),
        (.regex(field: .form, pattern: "(a+)+", flags: []), "query.regex-rejected"),
    ] {
        try expectASTFailure(GlifiQueryAST(root: root).canonicalData(), code: code)
    }
}

@Test("QueryAST JSON conserva la cancellazione senza convertirla in input non valido")
func queryASTInputPreservesCancellation() async throws {
    let data = try GlifiQueryAST(root: .matchAll).canonicalData()
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiQueryAST.decode(data)
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled decoding succeeded")
    } catch is CancellationError {
        // Cancellation remains distinct from malformed input.
    }
}

private func astInputLimits(
    bytes: Int = 65_536, depth: Int = 32, nodes: Int = 1_024
) -> GlifiQueryLimits {
    GlifiQueryLimits(
        maximumQueryByteCount: bytes, maximumDepth: depth, maximumNodeCount: nodes,
        maximumPhraseTokenCount: 256, maximumProximityDistance: 10_000,
        maximumRegexByteCount: 256, maximumRegexInputByteCount: 4_096,
        maximumSourceCount: 1_000, maximumScannedByteCount: 268_435_456,
        maximumResultCount: 1_000, contextTokenCount: 5)
}

private func expectASTFailure(
    _ data: Data, limits: GlifiQueryLimits = .standard, code: String
) throws {
    do {
        _ = try GlifiQueryAST.decode(data, limits: limits)
        Issue.record("Invalid AST input was accepted")
    } catch let failure as GlifiFailure {
        #expect(failure.code == code)
        #expect(failure.operation == .query)
        #expect(failure.arguments.isEmpty)
        #expect(!String(describing: failure).contains("ZQXCANARY42"))
    }
}
