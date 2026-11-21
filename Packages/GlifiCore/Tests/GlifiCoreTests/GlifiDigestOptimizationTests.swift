// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("Digest, identificatori e descrittori conservano il contratto e misurano workload espliciti")
func domainOptimizationDigest() throws {
    try verifyDigestDomainBoundaries()
    try verifyDigestDescriptorReference()
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }

    let seeds = (0..<256).map { legacyDigest(Data("digest-seed-\($0)".utf8)) }
    let digests = (0..<50_000).map { seeds[$0 % seeds.count] }
    let identifiers = try digests.map { try ArtifactID(digest: $0) }
    try measurePipelineOptimization(
        identifier: "digest-identifiers-50000",
        generator: "50,000 ArtifactID(digest:) values cycling 256 deterministic SHA-256 digests",
        fixtureDigest: pipelineBenchmarkDigest(digests), expected: identifiers,
        body: { try digests.map { try ArtifactID(digest: $0) } },
        checksum: { try pipelineBenchmarkDigest($0) }
    )

    let canonicalValues = digests.map { "artifact:\($0)" }
    try measurePipelineOptimization(
        identifier: "digest-canonical-identifiers-50000",
        generator: "50,000 ArtifactID(canonicalValue:) values with the same deterministic digests",
        fixtureDigest: pipelineBenchmarkDigest(canonicalValues), expected: identifiers,
        body: { try canonicalValues.map { try ArtifactID(canonicalValue: $0) } },
        checksum: { try pipelineBenchmarkDigest($0) }
    )

    let malformedSeeds = try digestDomainCases().filter { !legacyDigestIsValid($0) }
    let malformed = (0..<50_000).map { malformedSeeds[$0 % malformedSeeds.count] }
    let failures = Array(repeating: digestDomainFailure("identifier.invalid-digest"), count: 50_000)
    try measurePipelineOptimization(
        identifier: "digest-malformed-identifiers-50000",
        generator: "50,000 malformed ASCII and Unicode ArtifactID inputs; complete typed failures",
        fixtureDigest: pipelineBenchmarkDigest(malformed), expected: failures,
        body: {
            try malformed.map { value in
                try capturedDigestFailure { _ = try ArtifactID(digest: value) }
            }
        },
        checksum: { try pipelineBenchmarkDigest($0) }
    )

    for large in [false, true] {
        let descriptors = try (0..<1_000).map {
            try optimizationDigestDescriptor(
                index: $0, large: large, selective: $0.isMultiple(of: 2))
        }
        let expected = try descriptors.map(referenceDigestDescriptor)
        try measurePipelineOptimization(
            identifier: "digest-descriptors-\(large ? "large" : "small")-1000",
            generator:
                "1,000 alternating v1/v2 descriptors; canonicalDigest() and nodeID(); \(large ? "32 nested parameters and 8 dependencies" : "one Unicode parameter")",
            fixtureDigest: pipelineBenchmarkDigest(descriptors), expected: expected,
            body: { try descriptors.map(observedDigestDescriptor) },
            checksum: { try pipelineBenchmarkDigest($0) }
        )
    }
}

private enum DigestOptimizationFailure: Error {
    case expectedFailureMissing
}

private enum UnicodeDigestKind: GlifiDigestIdentifierKind {
    static let namespace = "café.分析:🔎"
}

private struct DigestDescriptorResult: Codable, Equatable {
    let digest: String
    let nodeID: String
}

private func verifyDigestDomainBoundaries() throws {
    let nodeID = try AnalysisNodeID(digest: "sha256:" + String(repeating: "0", count: 64))
    for value in try digestDomainCases() {
        if legacyDigestIsValid(value) {
            let identifier = try ArtifactID(digest: value)
            #expect(identifier.digest == value)
            #expect(identifier.canonicalValue == "artifact:\(value)")
            #expect(try ArtifactID(canonicalValue: identifier.canonicalValue) == identifier)
            #expect(
                try JSONDecoder().decode(ArtifactID.self, from: JSONEncoder().encode(identifier))
                    == identifier)
            let dependency = try GlifiAnalysisDependency(
                nodeID: nodeID, artifactDigest: value, outputSchemaIdentifier: "schema.test.v1")
            #expect(dependency.artifactDigest == value)
            let artifact = try GlifiAnalysisArtifactReference(
                nodeID: nodeID, descriptorDigest: value, artifactDigest: value,
                outputSchemaIdentifier: "schema.test.v1", state: .valid)
            #expect(artifact.descriptorDigest == value && artifact.artifactDigest == value)
        } else {
            #expect(
                try capturedDigestFailure { _ = try ArtifactID(digest: value) }
                    == digestDomainFailure("identifier.invalid-digest"))
            #expect(
                try capturedDigestFailure {
                    _ = try ArtifactID(canonicalValue: "artifact:\(value)")
                }
                    == digestDomainFailure("identifier.invalid-digest"))
            #expect(
                try capturedDigestFailure {
                    _ = try JSONDecoder().decode(
                        ArtifactID.self, from: JSONEncoder().encode("artifact:\(value)"))
                } == digestDomainFailure("identifier.invalid-digest"))
            #expect(
                try capturedDigestFailure {
                    _ = try GlifiAnalysisDependency(
                        nodeID: nodeID, artifactDigest: value,
                        outputSchemaIdentifier: "schema.test.v1")
                } == digestGraphFailure("analysis.invalid-dependency"))
            for malformedDescriptorDigest in [false, true] {
                #expect(
                    try capturedDigestFailure {
                        _ = try GlifiAnalysisArtifactReference(
                            nodeID: nodeID,
                            descriptorDigest: malformedDescriptorDigest ? value : nodeID.digest,
                            artifactDigest: malformedDescriptorDigest ? nodeID.digest : value,
                            outputSchemaIdentifier: "schema.test.v1", state: .valid)
                    } == digestGraphFailure("analysis.invalid-artifact-reference"))
            }
        }
    }

    let valid = "sha256:" + String(repeating: "abcdef0123456789", count: 4)
    let identifier = try GlifiDigestIdentifier<UnicodeDigestKind>(digest: valid)
    for namespace in [UnicodeDigestKind.namespace, "cafe\u{0301}.分析:🔎"] {
        #expect(
            try GlifiDigestIdentifier<UnicodeDigestKind>(canonicalValue: "\(namespace):\(valid)")
                == identifier)
    }
    #expect(
        try JSONDecoder().decode(
            GlifiDigestIdentifier<UnicodeDigestKind>.self, from: JSONEncoder().encode(identifier))
            == identifier)
    for canonicalValue in [valid, "evidence:\(valid)", "Artifact:\(valid)", "artifact:\(valid):"] {
        #expect(
            try capturedDigestFailure { _ = try ArtifactID(canonicalValue: canonicalValue) }
                == digestDomainFailure("identifier.invalid-digest"))
    }
}

private func digestDomainCases() throws -> [String] {
    let suffix = String(repeating: "a", count: 64)
    var values = "0123456789abcdef".map { "sha256:" + String(repeating: $0, count: 64) }
    values += [
        "sha256:" + suffix, "", "sha256:", "SHA256:" + suffix, "sha256：" + suffix,
        "sha256:" + String(repeating: "a", count: 63), "sha256:" + suffix + "a",
        "sha256:" + String(repeating: "A", count: 64), " sha256:" + suffix,
        "sha256:" + suffix + "\n", "sha256:" + String(repeating: "a", count: 16_384),
    ]
    for number in 0..<128 {
        let scalar = try #require(UnicodeScalar(number))
        let character = String(scalar)
        values.append("sha256:" + character + String(suffix.dropFirst()))
        values.append("sha256:" + String(suffix.dropLast()) + character)
    }
    for character in ["ａ", "Ａ", "𝒂", "é", "a\u{0301}", "😀", "\u{200B}", "\u{FEFF}", "\r\n"] {
        values.append("sha256:" + character + String(suffix.dropFirst()))
        values.append("sha256:" + String(suffix.dropLast()) + character)
    }
    return values
}

private func legacyDigestIsValid(_ value: String) -> Bool {
    value.hasPrefix("sha256:") && value.count == 71
        && value.dropFirst(7).allSatisfy { "0123456789abcdef".contains($0) }
}

private func digestDomainFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code, category: .invalidInput, operation: .analyze,
        retryDisposition: .afterCorrection, retainedState: .unchanged, messageKey: "failure.\(code)"
    )
}

private func digestGraphFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code, category: .invalidInput, operation: .analyze,
        retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
        messageKey: "failure.\(code)")
}

private func capturedDigestFailure(_ body: () throws -> Void) throws -> GlifiFailure {
    do {
        try body()
        throw DigestOptimizationFailure.expectedFailureMissing
    } catch let failure as GlifiFailure {
        return failure
    }
}

private func verifyDigestDescriptorReference() throws {
    for (input, expected) in [
        ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
    ] {
        let digest = legacyDigest(Data(input.utf8))
        #expect(digest == "sha256:\(expected)")
        #expect(try ArtifactID(digest: digest).digest == digest)
    }
    for large in [false, true] {
        for selective in [false, true] {
            let descriptor = try optimizationDigestDescriptor(
                index: 7, large: large, selective: selective)
            #expect(
                try observedDigestDescriptor(descriptor) == referenceDigestDescriptor(descriptor))
            let decoded = try JSONDecoder().decode(
                GlifiAnalysisDescriptor.self, from: canonicalDigestJSON(descriptor))
            #expect(decoded == descriptor)
            #expect(try observedDigestDescriptor(decoded) == referenceDigestDescriptor(descriptor))
        }
    }
    let legacy = try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "corpus-profile", algorithmIdentifier: "corpus-profile-it-v1",
        algorithmVersion: "1.0.0", corpusIdentifier: "corpus.golden",
        corpusVersionDigest: "sha256:" + String(repeating: "a", count: 64),
        selectionIdentifier: "selection.all.v1", analyticalUnitIdentifier: "document",
        preprocessingIdentifiers: ["it-token-v1"], linguisticProfileIdentifiers: ["it-v1"],
        representationIdentifier: "counts-v1", resolvedParameters: ["soglia": .integer(3)],
        seedPolicyIdentifier: "no-seed", backendIdentifier: "swift",
        numericPolicyIdentifier: "double-v1",
        determinismClass: .d0, outputSchemaIdentifier: "studio.glifi.corpus-profile.v1",
        softwareIdentifier: "glificore-0.1", dependencies: [])
    #expect(
        try legacy.canonicalDigest()
            == "sha256:760dd96a1d0cacc83a72dc2e1a9b9662253b74f1af8a93f0c924402efb468e3d")
    #expect(
        try legacy.nodeID().canonicalValue
            == "analysis-node:sha256:4df18da1aebd9326390164965dbdfd2fad9951da7f7d3a4cb5659252ffde168f"
    )
    #expect(try observedDigestDescriptor(legacy) == referenceDigestDescriptor(legacy))
}

private func optimizationDigestDescriptor(index: Int, large: Bool, selective: Bool) throws
    -> GlifiAnalysisDescriptor
{
    var parameters: [String: GlifiAnalysisValue] = [
        "citta\u{0300}": .text("L'acqua / città, \"分析\" 👨‍👩‍👧\n\(index)")
    ]
    if large {
        for parameter in 0..<32 {
            parameters["parameter-\(parameter)"] = .object([
                "name": .text("citta\u{0300}/\(parameter)"),
                "values": .list((0..<8).map { .integer(Int64(index + parameter + $0)) }),
            ])
        }
    }
    let dependencies = try (0..<(large ? 8 : 0)).map { dependency in
        try GlifiAnalysisDependency(
            nodeID: AnalysisNodeID(digest: legacyDigest(Data("parent-\(dependency)".utf8))),
            artifactDigest: legacyDigest(Data("artifact-\(dependency)".utf8)),
            outputSchemaIdentifier: "schema.parent.\(dependency).v1")
    }
    let revision = SourceRevisionID(
        uuid: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7)))
    return try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.digest-benchmark",
        algorithmIdentifier: "algorithm.digest-benchmark",
        algorithmVersion: "1", corpusIdentifier: "corpus.synthetic",
        corpusVersionDigest: "sha256:" + String(repeating: "1", count: 64),
        selectionIdentifier: "selection.all.v1", analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: ["extract-v1", "it-token-v1"],
        linguisticProfileIdentifiers: ["it-v1"],
        representationIdentifier: "counts-v1", resolvedParameters: parameters,
        seedPolicyIdentifier: "none-v1", backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1", determinismClass: .d0,
        outputSchemaIdentifier: "schema.digest-benchmark.v1", softwareIdentifier: "GlifiCore-0.1",
        dependencies: Array(dependencies.reversed()),
        sourceRevisionIDs: selective ? [revision] : nil)
}

private func observedDigestDescriptor(_ descriptor: GlifiAnalysisDescriptor) throws
    -> DigestDescriptorResult
{
    try DigestDescriptorResult(
        digest: descriptor.canonicalDigest(), nodeID: descriptor.nodeID().canonicalValue)
}

private func referenceDigestDescriptor(_ descriptor: GlifiAnalysisDescriptor) throws
    -> DigestDescriptorResult
{
    try DigestDescriptorResult(
        digest: legacyDigest(canonicalDigestJSON(descriptor)),
        nodeID: "analysis-node:"
            + legacyDigest(canonicalDigestJSON(DigestIdentityReference(descriptor: descriptor))))
}

private func canonicalDigestJSON(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private func legacyDigest(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private struct DigestIdentityReference: Encodable {
    let descriptor: GlifiAnalysisDescriptor

    private enum CodingKeys: String, CodingKey {
        case domain, artifactTypeIdentifier, algorithmIdentifier, algorithmVersion, corpusIdentifier
        case corpusVersionDigest, selectionIdentifier, analyticalUnitIdentifier,
            preprocessingIdentifiers
        case linguisticProfileIdentifiers, representationIdentifier, resolvedParameters,
            seedPolicyIdentifier
        case backendIdentifier, numericPolicyIdentifier, determinismClass, outputSchemaIdentifier
        case softwareIdentifier, inputs, sourceRevisionIDs
    }

    private struct Input: Encodable {
        let artifactDigest: String
        let outputSchemaIdentifier: String
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("glifi.analysis-node.v1", forKey: .domain)
        try container.encode(descriptor.artifactTypeIdentifier, forKey: .artifactTypeIdentifier)
        try container.encode(descriptor.algorithmIdentifier, forKey: .algorithmIdentifier)
        try container.encode(descriptor.algorithmVersion, forKey: .algorithmVersion)
        try container.encode(descriptor.corpusIdentifier, forKey: .corpusIdentifier)
        try container.encode(descriptor.corpusVersionDigest, forKey: .corpusVersionDigest)
        try container.encode(descriptor.selectionIdentifier, forKey: .selectionIdentifier)
        try container.encode(descriptor.analyticalUnitIdentifier, forKey: .analyticalUnitIdentifier)
        try container.encode(descriptor.preprocessingIdentifiers, forKey: .preprocessingIdentifiers)
        try container.encode(
            descriptor.linguisticProfileIdentifiers, forKey: .linguisticProfileIdentifiers)
        try container.encode(descriptor.representationIdentifier, forKey: .representationIdentifier)
        try container.encode(descriptor.resolvedParameters, forKey: .resolvedParameters)
        try container.encode(descriptor.seedPolicyIdentifier, forKey: .seedPolicyIdentifier)
        try container.encode(descriptor.backendIdentifier, forKey: .backendIdentifier)
        try container.encode(descriptor.numericPolicyIdentifier, forKey: .numericPolicyIdentifier)
        try container.encode(descriptor.determinismClass, forKey: .determinismClass)
        try container.encode(descriptor.outputSchemaIdentifier, forKey: .outputSchemaIdentifier)
        try container.encode(descriptor.softwareIdentifier, forKey: .softwareIdentifier)
        let inputs = descriptor.dependencies.map {
            Input(
                artifactDigest: $0.artifactDigest, outputSchemaIdentifier: $0.outputSchemaIdentifier
            )
        }.sorted {
            ($0.artifactDigest, $0.outputSchemaIdentifier) < (
                $1.artifactDigest, $1.outputSchemaIdentifier
            )
        }
        try container.encode(inputs, forKey: .inputs)
        try container.encodeIfPresent(
            descriptor.sourceRevisionIDs?.map(\.canonicalValue), forKey: .sourceRevisionIDs)
    }
}
