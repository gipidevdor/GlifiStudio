// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("AnalysisDescriptor ha round-trip canonico e identità semanticamente sensibile")
func analysisDescriptorIsCanonicalAndSensitive() throws {
    let first = try descriptor(
        named: "profile",
        parameters: [
            "window": .integer(100),
            "label": .text("citta\u{0300}"),
            "threshold": .decimal(-0.0),
        ]
    )
    let second = try descriptor(
        named: "profile",
        parameters: [
            "threshold": .decimal(0.0),
            "label": .text("città"),
            "window": .integer(100),
        ]
    )

    #expect(first == second)
    #expect(try first.canonicalDigest() == second.canonicalDigest())
    #expect(try first.nodeID() == second.nodeID())
    #expect(try first.nodeID().canonicalValue.hasPrefix("analysis-node:sha256:"))

    let encoded = try JSONEncoder().encode(first)
    let decoded = try JSONDecoder().decode(GlifiAnalysisDescriptor.self, from: encoded)
    #expect(decoded == first)
    #expect(try decoded.canonicalDigest() == first.canonicalDigest())

    var future = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    future["schemaIdentifier"] = "studio.glifi.analysis-descriptor.v3"
    let futureData = try JSONSerialization.data(withJSONObject: future)
    try expectGraphFailure(code: "analysis.unsupported-descriptor-version") {
        _ = try JSONDecoder().decode(GlifiAnalysisDescriptor.self, from: futureData)
    }
    // Uno schema v1 che dichiara revisioni, o uno v2 che non le dichiara, sono incoerenti.
    var mislabelled = future
    mislabelled["schemaIdentifier"] = "studio.glifi.analysis-descriptor.v1"
    mislabelled["sourceRevisionIDs"] = ["source-revision:00000000-0000-0000-0000-000000000001"]
    try expectGraphFailure(code: "analysis.unsupported-descriptor-version") {
        _ = try JSONDecoder().decode(
            GlifiAnalysisDescriptor.self,
            from: try JSONSerialization.data(withJSONObject: mislabelled))
    }
    var missing = future
    missing["schemaIdentifier"] = "studio.glifi.analysis-descriptor.v2"
    try expectGraphFailure(code: "analysis.unsupported-descriptor-version") {
        _ = try JSONDecoder().decode(
            GlifiAnalysisDescriptor.self,
            from: try JSONSerialization.data(withJSONObject: missing))
    }

    let changed = try descriptor(
        named: "profile",
        parameters: ["window": .integer(101)]
    )
    #expect(try changed.nodeID() != first.nodeID())

    try expectGraphFailure(code: "analysis.invalid-number") {
        _ = try descriptor(named: "invalid", parameters: ["value": .decimal(.nan)])
    }
}

@Test("Analysis DAG deduplica, ordina, invalida e riusa soltanto rami validi")
func analysisGraphMaintainsExactDependencySemantics() throws {
    let source = try node(named: "source")
    let profile = try node(
        named: "profile",
        dependencies: [try dependency(on: source, artifact: hash("a"))]
    )
    let keyness = try node(
        named: "keyness",
        dependencies: [try dependency(on: profile, artifact: hash("b"))]
    )
    let query = try node(
        named: "query",
        dependencies: [try dependency(on: source, artifact: hash("a"))]
    )
    let independent = try node(named: "independent")

    let graph = try GlifiAnalysisGraph([keyness, source, query, profile, independent, source])
    let repeated = try GlifiAnalysisGraph([independent, profile, source, keyness, query])
    #expect(graph == repeated)
    #expect(
        try JSONDecoder().decode(
            GlifiAnalysisGraph.self,
            from: JSONEncoder().encode(graph)
        ) == graph
    )
    #expect(graph.nodes.count == 5)
    #expect(
        Set(try graph.requiredNodeIDs(for: [keyness.id])) == [source.id, profile.id, keyness.id])
    #expect(Set(try graph.invalidatedNodeIDs(changing: [profile.id])) == [profile.id, keyness.id])

    let artifacts = try [
        artifact(for: source, digest: hash("a")),
        artifact(for: profile, digest: hash("b"), state: .stale),
        artifact(for: keyness, digest: hash("c")),
        artifact(for: query, digest: hash("d")),
        artifact(for: independent, digest: hash("e")),
    ]
    #expect(
        Set(try graph.reusableNodeIDs(from: artifacts))
            == [source.id, query.id, independent.id]
    )
}

@Test("Analysis DAG rifiuta dipendenze mancanti, cicli e budget superati")
func analysisGraphRejectsInvalidDefinitions() throws {
    let unknown = try AnalysisNodeID(digest: hash("f"))
    let missing = try node(
        named: "missing",
        dependencies: [
            try GlifiAnalysisDependency(
                nodeID: unknown,
                artifactDigest: hash("a"),
                outputSchemaIdentifier: "schema.unknown.v1"
            )
        ]
    )
    try expectGraphFailure(code: "analysis.missing-dependency") {
        _ = try GlifiAnalysisGraph([missing])
    }

    let placeholder = try AnalysisNodeID(digest: hash("0"))
    let provisionalA = try node(
        named: "cycle-a",
        outputSchema: "schema.a.v1",
        dependencies: [
            try GlifiAnalysisDependency(
                nodeID: placeholder,
                artifactDigest: hash("b"),
                outputSchemaIdentifier: "schema.b.v1"
            )
        ]
    )
    let provisionalB = try node(
        named: "cycle-b",
        outputSchema: "schema.b.v1",
        dependencies: [
            try GlifiAnalysisDependency(
                nodeID: placeholder,
                artifactDigest: hash("a"),
                outputSchemaIdentifier: "schema.a.v1"
            )
        ]
    )
    let cycleA = try node(
        named: "cycle-a",
        outputSchema: "schema.a.v1",
        dependencies: [
            try GlifiAnalysisDependency(
                nodeID: provisionalB.id,
                artifactDigest: hash("b"),
                outputSchemaIdentifier: "schema.b.v1"
            )
        ]
    )
    let cycleB = try node(
        named: "cycle-b",
        outputSchema: "schema.b.v1",
        dependencies: [
            try GlifiAnalysisDependency(
                nodeID: provisionalA.id,
                artifactDigest: hash("a"),
                outputSchemaIdentifier: "schema.a.v1"
            )
        ]
    )
    #expect(cycleA.id == provisionalA.id)
    #expect(cycleB.id == provisionalB.id)
    try expectGraphFailure(code: "analysis.cyclic-graph") {
        _ = try GlifiAnalysisGraph([cycleA, cycleB])
    }

    let root = try node(named: "root")
    try expectGraphFailure(code: "analysis.graph-limit-exceeded") {
        _ = try GlifiAnalysisGraph(
            [root],
            limits: GlifiAnalysisGraphLimits(maximumNodeCount: 0, maximumEdgeCount: 0)
        )
    }
    try expectGraphFailure(code: "analysis.invalid-graph-limits") {
        _ = try GlifiAnalysisGraphLimits(maximumNodeCount: -1, maximumEdgeCount: 0)
    }
}

private func node(
    named name: String,
    outputSchema: String? = nil,
    dependencies: [GlifiAnalysisDependency] = []
) throws -> GlifiAnalysisNode {
    try GlifiAnalysisNode(
        descriptor: descriptor(
            named: name,
            outputSchema: outputSchema,
            dependencies: dependencies
        )
    )
}

private func descriptor(
    named name: String,
    outputSchema: String? = nil,
    parameters: [String: GlifiAnalysisValue] = ["resolved": .boolean(true)],
    dependencies: [GlifiAnalysisDependency] = [],
    sourceRevisionIDs: [SourceRevisionID]? = nil
) throws -> GlifiAnalysisDescriptor {
    try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.\(name)",
        algorithmIdentifier: "algorithm.\(name)",
        algorithmVersion: "1",
        corpusIdentifier: "corpus:test",
        corpusVersionDigest: hash("1"),
        selectionIdentifier: "selection.all.v1",
        analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: ["extract-v1", "it-token-v1"],
        linguisticProfileIdentifiers: ["it-token-v1"],
        representationIdentifier: "representation.test.v1",
        resolvedParameters: parameters,
        seedPolicyIdentifier: "none-v1",
        backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
        determinismClass: .d1,
        outputSchemaIdentifier: outputSchema ?? "schema.\(name).v1",
        softwareIdentifier: "GlifiCore-0.1",
        dependencies: dependencies,
        sourceRevisionIDs: sourceRevisionIDs
    )
}

private func dependency(
    on node: GlifiAnalysisNode,
    artifact: String
) throws -> GlifiAnalysisDependency {
    try GlifiAnalysisDependency(
        nodeID: node.id,
        artifactDigest: artifact,
        outputSchemaIdentifier: node.descriptor.outputSchemaIdentifier
    )
}

private func artifact(
    for node: GlifiAnalysisNode,
    digest: String,
    state: GlifiAnalysisArtifactState = .valid
) throws -> GlifiAnalysisArtifactReference {
    try GlifiAnalysisArtifactReference(
        nodeID: node.id,
        descriptorDigest: node.descriptor.canonicalDigest(),
        artifactDigest: digest,
        outputSchemaIdentifier: node.descriptor.outputSchemaIdentifier,
        state: state
    )
}

private func hash(_ character: Character) -> String {
    "sha256:" + String(repeating: character, count: 64)
}

private func expectGraphFailure(code: String, _ operation: () throws -> Void) throws {
    do {
        try operation()
        Issue.record("Era attesa la failure \(code)")
    } catch let failure as GlifiFailure {
        #expect(failure.code == code)
        #expect(failure.operation == .analyze)
    }
}

@Test("Il descrittore v2 dichiara le revisioni senza cambiare l'identità dei descrittori v1")
func selectiveDescriptorDeclaresSourceRevisionsAndPreservesV1Identity() throws {
    // Valore d'oro calcolato prima dell'introduzione della v2 (ADR-0028): un descrittore che non
    // dichiara revisioni deve conservare esattamente l'identità che aveva, altrimenti i package
    // esistenti non si aprirebbero più.
    let legacy = try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "corpus-profile",
        algorithmIdentifier: "corpus-profile-it-v1",
        algorithmVersion: "1.0.0",
        corpusIdentifier: "corpus.golden",
        corpusVersionDigest: "sha256:" + String(repeating: "a", count: 64),
        selectionIdentifier: "selection.all.v1",
        analyticalUnitIdentifier: "document",
        preprocessingIdentifiers: ["it-token-v1"],
        linguisticProfileIdentifiers: ["it-v1"],
        representationIdentifier: "counts-v1",
        resolvedParameters: ["soglia": .integer(3)],
        seedPolicyIdentifier: "no-seed",
        backendIdentifier: "swift",
        numericPolicyIdentifier: "double-v1",
        determinismClass: .d0,
        outputSchemaIdentifier: "studio.glifi.corpus-profile.v1",
        softwareIdentifier: "glificore-0.1",
        dependencies: []
    )
    #expect(legacy.sourceRevisionIDs == nil)
    #expect(legacy.descriptorSchemaIdentifier == "studio.glifi.analysis-descriptor.v1")
    #expect(
        try legacy.nodeID().canonicalValue
            == "analysis-node:sha256:"
            + "4df18da1aebd9326390164965dbdfd2fad9951da7f7d3a4cb5659252ffde168f")
    #expect(
        try legacy.canonicalDigest()
            == "sha256:760dd96a1d0cacc83a72dc2e1a9b9662253b74f1af8a93f0c924402efb468e3d")

    // Dichiarare le revisioni produce un descrittore v2 e un nodo diverso, ricalcolato una volta.
    let first = SourceRevisionID(
        uuid: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)))
    let second = SourceRevisionID(
        uuid: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)))
    let selective = try descriptor(named: "profile", sourceRevisionIDs: [second, first])
    let unaware = try descriptor(named: "profile")
    #expect(selective.descriptorSchemaIdentifier == "studio.glifi.analysis-descriptor.v2")
    #expect(try selective.nodeID() != unaware.nodeID())
    // Le revisioni dichiarate sono ordinate canonicamente, non nell'ordine di chiamata.
    #expect(selective.sourceRevisionIDs == [first, second])
    #expect(
        try descriptor(named: "profile", sourceRevisionIDs: [first, second]).nodeID()
            == selective.nodeID())
    // Dichiarare nessuna revisione è diverso dal non dichiararle affatto.
    let independent = try descriptor(named: "profile", sourceRevisionIDs: [])
    #expect(independent.sourceRevisionIDs == [])
    #expect(try independent.nodeID() != unaware.nodeID())
    try expectGraphFailure(code: "analysis.duplicate-source-revision") {
        _ = try descriptor(named: "profile", sourceRevisionIDs: [first, first])
    }

    // Round-trip: la forma serializzata dichiara la v2 e si rilegge identica.
    let encoded = try JSONEncoder().encode(selective)
    let payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(payload["schemaIdentifier"] as? String == "studio.glifi.analysis-descriptor.v2")
    #expect(
        payload["sourceRevisionIDs"] as? [String]
            == [first.canonicalValue, second.canonicalValue])
    #expect(try JSONDecoder().decode(GlifiAnalysisDescriptor.self, from: encoded) == selective)
    // Un descrittore v1 non emette affatto il campo.
    let legacyPayload = try #require(
        JSONSerialization.jsonObject(with: try JSONEncoder().encode(unaware)) as? [String: Any])
    #expect(legacyPayload["sourceRevisionIDs"] == nil)
    #expect(legacyPayload["schemaIdentifier"] as? String == "studio.glifi.analysis-descriptor.v1")
}
