// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("La costruzione del DAG coincide con Kahn scalare e misura soltanto workload espliciti")
func domainOptimizationGraph() throws {
    for shape in GraphOptimizationShape.allCases {
        let fixture = try graphOptimizationFixture(shape: shape, count: 24)
        let expected = try ScalarOptimizationGraph(fixture.nodes)
        let graph = try GlifiAnalysisGraph(fixture.nodes)
        #expect(graphOptimizationSnapshot(graph) == expected.snapshot)
    }
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    for (shape, count) in [
        (GraphOptimizationShape.independent, 1_000), (.independent, 5_000),
        (.star, 5_000), (.layered, 3_000), (.chain, 1_000),
    ] {
        let fixture = try graphOptimizationFixture(shape: shape, count: count)
        let reference = try ScalarOptimizationGraph(fixture.nodes)
        let expected = try GlifiAnalysisGraph(fixture.nodes)
        guard graphOptimizationSnapshot(expected) == reference.snapshot else {
            throw GraphOptimizationReferenceFailure.invalid("reference-result-mismatch")
        }
        try measurePipelineOptimization(
            identifier: "dag-construction-\(shape.rawValue)-\(count)",
            generator:
                "\(count) prepared valid nodes; \(shape.rawValue) DAG; reversed candidate order; scalar Kahn reference; full graph construction including identity validation",
            fixtureDigest: pipelineBenchmarkDigest(fixture.nodes), expected: expected,
            body: { try GlifiAnalysisGraph(fixture.nodes) },
            checksum: { try pipelineBenchmarkDigest(graphOptimizationSnapshot($0)) })
    }
}

@Test(
    "Permutazioni e round-trip del DAG preservano nodi, spareggi, antenati, invalidazione e riuso")
func analysisGraphOptimizationPreservesFullBehavior() throws {
    let fixture = try graphOptimizationFixture(shape: .layered, count: 24)
    let reference = try ScalarOptimizationGraph(fixture.nodes)
    let ordered = fixture.nodes.sorted { $0.id.canonicalValue < $1.id.canonicalValue }
    let first = try #require(ordered.first)
    let last = try #require(ordered.last)
    let requested = [last.id, first.id, last.id]
    let changed = [first.id, last.id, first.id]
    let firstArtifact = try #require(fixture.artifacts.first)
    let variants = try [
        fixture.artifacts,
        Array(fixture.artifacts.dropFirst()),
        [modifiedGraphReference(firstArtifact, state: .stale)] + fixture.artifacts.dropFirst(),
        [
            modifiedGraphReference(
                firstArtifact, descriptorDigest: graphOptimizationDigest("wrong-descriptor"))
        ]
            + fixture.artifacts.dropFirst(),
        [
            modifiedGraphReference(
                firstArtifact, artifactDigest: graphOptimizationDigest("changed-output"))
        ]
            + fixture.artifacts.dropFirst(),
        [modifiedGraphReference(firstArtifact, outputSchema: "schema.other.v1")]
            + fixture.artifacts.dropFirst(),
    ]
    let permutations = [
        fixture.nodes, Array(fixture.nodes.reversed()),
        Array(fixture.nodes.dropFirst(7)) + fixture.nodes.prefix(7),
        fixture.nodes + [first, last],
    ]
    for candidates in permutations {
        let graph = try GlifiAnalysisGraph(candidates)
        let data = try graphOptimizationCanonicalData(graph)
        let decoded = try JSONDecoder().decode(GlifiAnalysisGraph.self, from: data)
        #expect(decoded == graph)
        #expect(try graphOptimizationCanonicalData(decoded) == data)
        let record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(record.keys) == ["nodes"])
        #expect(graphOptimizationSnapshot(graph) == reference.snapshot)
        for artifacts in variants {
            let expected = try GraphOptimizationBehavior(
                graph: reference.snapshot,
                required: reference.requiredNodeIDs(for: requested),
                invalidated: reference.invalidatedNodeIDs(changing: changed),
                reusable: reference.reusableNodeIDs(from: artifacts))
            let actual = try GraphOptimizationBehavior(
                graph: graphOptimizationSnapshot(graph),
                required: graph.requiredNodeIDs(for: requested),
                invalidated: graph.invalidatedNodeIDs(changing: changed),
                reusable: graph.reusableNodeIDs(from: artifacts))
            #expect(actual == expected)
            #expect(
                try decoded.requiredNodeIDs(for: requested) == expected.required)
            #expect(
                try decoded.invalidatedNodeIDs(changing: changed) == expected.invalidated)
            #expect(try decoded.reusableNodeIDs(from: artifacts) == expected.reusable)
        }
    }
}

@Test(
    "La coda DAG mantiene limiti, collisioni, errori di dipendenza e priorità della failure ciclica"
)
func analysisGraphOptimizationPreservesFailureContracts() throws {
    let fixture = try graphOptimizationFixture(shape: .star, count: 2)
    let root = try #require(fixture.nodes.first { $0.descriptor.dependencies.isEmpty })
    let child = try #require(fixture.nodes.first { !$0.descriptor.dependencies.isEmpty })
    let emptyLimits = try GlifiAnalysisGraphLimits(maximumNodeCount: 0, maximumEdgeCount: 0)
    #expect(try GlifiAnalysisGraph([], limits: emptyLimits).topologicalNodeIDs.isEmpty)
    expectOptimizationGraphFailure(
        [root], limits: emptyLimits, code: "analysis.graph-limit-exceeded",
        category: .insufficientResources, retry: .afterConditionsChange)
    expectOptimizationGraphFailure(
        [root, root],
        limits: try GlifiAnalysisGraphLimits(maximumNodeCount: 1, maximumEdgeCount: 0),
        code: "analysis.graph-limit-exceeded", category: .insufficientResources,
        retry: .afterConditionsChange)
    expectOptimizationGraphFailure(
        [root, child],
        limits: try GlifiAnalysisGraphLimits(maximumNodeCount: 2, maximumEdgeCount: 0),
        code: "analysis.graph-limit-exceeded", category: .insufficientResources,
        retry: .afterConditionsChange)
    expectOptimizationGraphFailure([child], code: "analysis.missing-dependency")

    let wrongSchema = try GlifiAnalysisNode(
        descriptor: graphOptimizationDescriptor(
            index: 99, shape: .star,
            dependencies: [
                GlifiAnalysisDependency(
                    nodeID: root.id, artifactDigest: graphOptimizationDigest("payload-0"),
                    outputSchemaIdentifier: "schema.other.v1")
            ]))
    expectOptimizationGraphFailure(
        [root, wrongSchema], code: "analysis.dependency-schema-mismatch")
    let collision = GlifiAnalysisNode(uncheckedID: root.id, descriptor: wrongSchema.descriptor)
    expectOptimizationGraphFailure(
        [root, collision], code: "analysis.node-id-collision", category: .invariantViolation,
        retry: .never, retained: .validityUnknown)

    let fakeA = try AnalysisNodeID(digest: graphOptimizationDigest("fake-a"))
    let fakeB = try AnalysisNodeID(digest: graphOptimizationDigest("fake-b"))
    let cycleA = try GlifiAnalysisNode(
        uncheckedID: fakeA,
        descriptor: graphOptimizationDescriptor(
            index: 100, shape: .chain,
            dependencies: [
                GlifiAnalysisDependency(
                    nodeID: fakeB, artifactDigest: graphOptimizationDigest("payload-b"),
                    outputSchemaIdentifier: graphOptimizationSchema)
            ]))
    let cycleB = try GlifiAnalysisNode(
        uncheckedID: fakeB,
        descriptor: graphOptimizationDescriptor(
            index: 101, shape: .chain,
            dependencies: [
                GlifiAnalysisDependency(
                    nodeID: fakeA, artifactDigest: graphOptimizationDigest("payload-a"),
                    outputSchemaIdentifier: graphOptimizationSchema)
            ]))
    // Cycle validation precedes semantic identity validation in the existing constructor.
    expectOptimizationGraphFailure([cycleA, cycleB], code: "analysis.cyclic-graph")
    expectOptimizationGraphFailure(
        [GlifiAnalysisNode(uncheckedID: fakeA, descriptor: root.descriptor)],
        code: "analysis.node-identity-mismatch")
    let valid = try GlifiAnalysisGraph([root, child])
    let duplicatedArtifacts = fixture.artifacts + fixture.artifacts.prefix(1)
    do {
        _ = try valid.reusableNodeIDs(from: duplicatedArtifacts)
        Issue.record("Duplicate artifact references were accepted")
    } catch let failure as GlifiFailure {
        expectOptimizationGraphFailureContract(failure, code: "analysis.duplicate-artifact")
    }
    for action in [0, 1] {
        do {
            if action == 0 {
                _ = try valid.requiredNodeIDs(for: [fakeA])
            } else {
                _ = try valid.invalidatedNodeIDs(changing: [fakeA])
            }
            Issue.record("An unknown node was accepted")
        } catch let failure as GlifiFailure {
            expectOptimizationGraphFailureContract(failure, code: "analysis.node-not-found")
        }
    }
}

private enum GraphOptimizationShape: String, CaseIterable {
    case independent, star, layered, chain
}

private let graphOptimizationSchema = "studio.glifi.test-graph-output.v1"

private struct GraphOptimizationFixture {
    let nodes: [GlifiAnalysisNode]
    let artifacts: [GlifiAnalysisArtifactReference]
}

private struct GraphOptimizationSnapshot: Encodable, Equatable {
    let nodes: [GlifiAnalysisNode]
    let topologicalNodeIDs: [AnalysisNodeID]
}

private struct GraphOptimizationBehavior: Encodable, Equatable {
    let graph: GraphOptimizationSnapshot
    let required: [AnalysisNodeID]
    let invalidated: [AnalysisNodeID]
    let reusable: [AnalysisNodeID]
}

private func graphOptimizationSnapshot(_ graph: GlifiAnalysisGraph) -> GraphOptimizationSnapshot {
    GraphOptimizationSnapshot(nodes: graph.nodes, topologicalNodeIDs: graph.topologicalNodeIDs)
}

private func graphOptimizationFixture(
    shape: GraphOptimizationShape, count: Int
) throws -> GraphOptimizationFixture {
    var nodes: [GlifiAnalysisNode] = []
    var artifacts: [GlifiAnalysisArtifactReference] = []
    let width = min(64, max(3, count / 4))
    for index in 0..<count {
        let parents: [Int]
        switch shape {
        case .independent: parents = []
        case .star: parents = index == 0 ? [] : [0]
        case .chain: parents = index == 0 ? [] : [index - 1]
        case .layered:
            if index < width {
                parents = []
            } else {
                let previous = (index / width - 1) * width
                let position = index % width
                parents = Array(
                    Set([position, (position + 1) % width, (position + width / 2) % width])
                ).sorted().map { previous + $0 }
            }
        }
        let dependencies = try parents.map { parent in
            try GlifiAnalysisDependency(
                nodeID: nodes[parent].id,
                artifactDigest: graphOptimizationDigest("payload-\(parent)"),
                outputSchemaIdentifier: graphOptimizationSchema)
        }
        let descriptor = try graphOptimizationDescriptor(
            index: index, shape: shape, dependencies: dependencies)
        let node = try GlifiAnalysisNode(descriptor: descriptor)
        nodes.append(node)
        artifacts.append(
            try GlifiAnalysisArtifactReference(
                nodeID: node.id, descriptorDigest: descriptor.canonicalDigest(),
                artifactDigest: graphOptimizationDigest("payload-\(index)"),
                outputSchemaIdentifier: graphOptimizationSchema, state: .valid))
    }
    return GraphOptimizationFixture(nodes: Array(nodes.reversed()), artifacts: artifacts)
}

private func graphOptimizationDescriptor(
    index: Int, shape: GraphOptimizationShape, dependencies: [GlifiAnalysisDependency]
) throws -> GlifiAnalysisDescriptor {
    try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.graph-optimization-v1",
        algorithmIdentifier: "algorithm.graph-optimization-v1", algorithmVersion: "1",
        corpusIdentifier: "corpus.graph-optimization-v1",
        corpusVersionDigest: graphOptimizationDigest("corpus"),
        selectionIdentifier: "selection.all.v1",
        analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: ["test-preprocessing-v1"],
        linguisticProfileIdentifiers: ["it-token-v1"],
        representationIdentifier: "representation.test.v1",
        resolvedParameters: ["index": .integer(Int64(index)), "shape": .text(shape.rawValue)],
        seedPolicyIdentifier: "none-v1", backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1", determinismClass: .d1,
        outputSchemaIdentifier: graphOptimizationSchema, softwareIdentifier: "GlifiCore-0.1",
        dependencies: dependencies)
}

private func graphOptimizationDigest(_ value: String) -> String {
    pipelineBenchmarkDigest(Data(value.utf8))
}

private func modifiedGraphReference(
    _ original: GlifiAnalysisArtifactReference,
    state: GlifiAnalysisArtifactState = .valid,
    descriptorDigest: String? = nil, artifactDigest: String? = nil, outputSchema: String? = nil
) throws -> GlifiAnalysisArtifactReference {
    try GlifiAnalysisArtifactReference(
        nodeID: original.nodeID, descriptorDigest: descriptorDigest ?? original.descriptorDigest,
        artifactDigest: artifactDigest ?? original.artifactDigest,
        outputSchemaIdentifier: outputSchema ?? original.outputSchemaIdentifier, state: state)
}

private func expectOptimizationGraphFailure(
    _ candidates: [GlifiAnalysisNode], limits: GlifiAnalysisGraphLimits = .standard, code: String,
    category: GlifiFailureCategory = .invalidInput,
    retry: GlifiRetryDisposition = .afterCorrection,
    retained: GlifiRetainedState = .lastCommittedGeneration
) {
    do {
        _ = try GlifiAnalysisGraph(candidates, limits: limits)
        Issue.record("An invalid graph was accepted")
    } catch let failure as GlifiFailure {
        expectOptimizationGraphFailureContract(
            failure, code: code, category: category, retry: retry, retained: retained)
    } catch {
        Issue.record("An unexpected graph failure type escaped")
    }
}

private func expectOptimizationGraphFailureContract(
    _ failure: GlifiFailure, code: String,
    category: GlifiFailureCategory = .invalidInput,
    retry: GlifiRetryDisposition = .afterCorrection,
    retained: GlifiRetainedState = .lastCommittedGeneration
) {
    #expect(failure.code == code)
    #expect(failure.category == category)
    #expect(failure.operation == .analyze)
    #expect(failure.retryDisposition == retry)
    #expect(failure.retainedState == retained)
    #expect(failure.messageKey == "failure.\(code)")
    #expect(failure.arguments.isEmpty)
}

private func graphOptimizationCanonicalData(_ graph: GlifiAnalysisGraph) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(graph)
}

private enum GraphOptimizationReferenceFailure: Error {
    case invalid(String)
}

// Frozen scalar Kahn reference from GlifiAnalysisGraph.swift before GS-DOR-205.
// Source SHA-256: 06e1ebb213c428a2d2ea5f6f5e154d18be4aabcf373a80a448faf8e3693f6c47.
// This implementation-equivalence reference includes the previous identity and graph checks.
private struct ScalarOptimizationGraph {
    let snapshot: GraphOptimizationSnapshot
    private let nodeByID: [AnalysisNodeID: GlifiAnalysisNode]
    private let childrenByID: [AnalysisNodeID: [AnalysisNodeID]]

    init(_ candidates: [GlifiAnalysisNode], limits: GlifiAnalysisGraphLimits = .standard) throws {
        guard limits.maximumNodeCount >= 0, limits.maximumEdgeCount >= 0,
            candidates.count <= limits.maximumNodeCount
        else { throw GraphOptimizationReferenceFailure.invalid("analysis.graph-limit-exceeded") }
        var byID: [AnalysisNodeID: GlifiAnalysisNode] = [:]
        for candidate in candidates {
            if let existing = byID[candidate.id] {
                guard existing == candidate else {
                    throw GraphOptimizationReferenceFailure.invalid("analysis.node-id-collision")
                }
            } else {
                byID[candidate.id] = candidate
            }
        }
        let edgeCount = byID.values.reduce(0) { $0 + $1.descriptor.dependencies.count }
        guard edgeCount <= limits.maximumEdgeCount else {
            throw GraphOptimizationReferenceFailure.invalid("analysis.graph-limit-exceeded")
        }
        var children: [AnalysisNodeID: [AnalysisNodeID]] = [:]
        var indegree = Dictionary(uniqueKeysWithValues: byID.keys.map { ($0, 0) })
        for node in byID.values {
            for dependency in node.descriptor.dependencies {
                guard let parent = byID[dependency.nodeID] else {
                    throw GraphOptimizationReferenceFailure.invalid("analysis.missing-dependency")
                }
                guard parent.descriptor.outputSchemaIdentifier == dependency.outputSchemaIdentifier
                else {
                    throw GraphOptimizationReferenceFailure.invalid(
                        "analysis.dependency-schema-mismatch")
                }
                children[dependency.nodeID, default: []].append(node.id)
                indegree[node.id, default: 0] += 1
            }
        }
        var ready = indegree.filter { $0.value == 0 }.map(\.key).sorted(by: scalarGraphIDOrder)
        var order: [AnalysisNodeID] = []
        while let next = ready.first {
            ready.removeFirst()
            order.append(next)
            for child in children[next, default: []].sorted(by: scalarGraphIDOrder) {
                indegree[child, default: 0] -= 1
                if indegree[child] == 0 {
                    ready.append(child)
                    ready.sort(by: scalarGraphIDOrder)
                }
            }
        }
        guard order.count == byID.count else {
            throw GraphOptimizationReferenceFailure.invalid("analysis.cyclic-graph")
        }
        for node in byID.values {
            guard try node.descriptor.nodeID() == node.id else {
                throw GraphOptimizationReferenceFailure.invalid("analysis.node-identity-mismatch")
            }
        }
        snapshot = GraphOptimizationSnapshot(
            nodes: byID.values.sorted { scalarGraphIDOrder($0.id, $1.id) },
            topologicalNodeIDs: order)
        nodeByID = byID
        childrenByID = children.mapValues { $0.sorted(by: scalarGraphIDOrder) }
    }

    func requiredNodeIDs(for requested: [AnalysisNodeID]) throws -> [AnalysisNodeID] {
        var required = Set<AnalysisNodeID>()
        var pending = requested
        while let next = pending.popLast() {
            guard let node = nodeByID[next] else {
                throw GraphOptimizationReferenceFailure.invalid("analysis.node-not-found")
            }
            if required.insert(next).inserted {
                pending.append(contentsOf: node.descriptor.dependencies.map(\.nodeID))
            }
        }
        return snapshot.topologicalNodeIDs.filter(required.contains)
    }

    func invalidatedNodeIDs(changing changed: [AnalysisNodeID]) throws -> [AnalysisNodeID] {
        var invalidated = Set<AnalysisNodeID>()
        var pending = changed
        while let next = pending.popLast() {
            guard nodeByID[next] != nil else {
                throw GraphOptimizationReferenceFailure.invalid("analysis.node-not-found")
            }
            if invalidated.insert(next).inserted {
                pending.append(contentsOf: childrenByID[next, default: []])
            }
        }
        return snapshot.topologicalNodeIDs.filter(invalidated.contains)
    }

    func reusableNodeIDs(from artifacts: [GlifiAnalysisArtifactReference]) throws
        -> [AnalysisNodeID]
    {
        var artifactsByNode: [AnalysisNodeID: GlifiAnalysisArtifactReference] = [:]
        for artifact in artifacts {
            guard artifactsByNode.updateValue(artifact, forKey: artifact.nodeID) == nil else {
                throw GraphOptimizationReferenceFailure.invalid("analysis.duplicate-artifact")
            }
        }
        var reusable = Set<AnalysisNodeID>()
        for nodeID in snapshot.topologicalNodeIDs {
            guard let node = nodeByID[nodeID], let artifact = artifactsByNode[nodeID],
                artifact.state == .valid,
                artifact.descriptorDigest == (try node.descriptor.canonicalDigest()),
                artifact.outputSchemaIdentifier == node.descriptor.outputSchemaIdentifier,
                node.descriptor.dependencies.allSatisfy({
                    reusable.contains($0.nodeID)
                        && artifactsByNode[$0.nodeID]?.artifactDigest == $0.artifactDigest
                })
            else { continue }
            reusable.insert(nodeID)
        }
        return snapshot.topologicalNodeIDs.filter(reusable.contains)
    }
}

private func scalarGraphIDOrder(_ lhs: AnalysisNodeID, _ rhs: AnalysisNodeID) -> Bool {
    lhs.canonicalValue < rhs.canonicalValue
}
