// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("La ricerca e la composizione di SpanMap coincidono con il riferimento lineare completo")
func pipelineOptimizationSpanMap() throws {
    let small = try spanMapLookupFixture(segmentCount: 128, queryCount: 64)
    #expect(try lookupAll(small) == linearLookupAll(small))
    let smallComposition = try spanMapCompositionFixture(segmentCount: 64)
    #expect(
        try smallComposition.outer.composed(after: smallComposition.inner)
            == linearCompose(smallComposition.outer, after: smallComposition.inner))

    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    let lookup = try spanMapLookupFixture(segmentCount: 20_000, queryCount: 1_000)
    try measurePipelineOptimization(
        identifier: "spanmap-construct-20000",
        generator:
            "GlifiSpanMap initializer; 20000 four-byte output segments, four mapping classes; shared COW segment input; complete validation included",
        fixtureDigest: pipelineBenchmarkDigest(lookup.map),
        expected: lookup.map,
        body: {
            try GlifiSpanMap(
                contractIdentifier: lookup.map.contractIdentifier,
                sourceRevisionID: lookup.map.sourceRevisionID,
                inputByteCount: lookup.map.inputByteCount,
                outputByteCount: lookup.map.outputByteCount,
                segments: lookup.map.segments,
                inputSpace: lookup.map.inputSpace,
                outputSpace: lookup.map.outputSpace)
        },
        checksum: { try pipelineBenchmarkDigest($0) }
    )
    let expectedLookup = try linearLookupAll(lookup)
    try measurePipelineOptimization(
        identifier: "spanmap-sparse-20000x1000",
        generator:
            "fixed revision; 20000 four-byte output segments, four mapping classes; 1000 sparse half-open queries; stride 7919",
        fixtureDigest: pipelineBenchmarkDigest(lookup),
        expected: expectedLookup,
        body: { try lookupAll(lookup) },
        checksum: { try pipelineBenchmarkDigest($0) }
    )
    let composition = try spanMapCompositionFixture(segmentCount: 5_000)
    let expectedComposition = try linearCompose(composition.outer, after: composition.inner)
    try measurePipelineOptimization(
        identifier: "spanmap-compose-5000x5000",
        generator:
            "fixed revision; 5000 inner and 5000 outer segments; exact, contributive, derivational and synthetic; sparse and multi-origin ranges",
        fixtureDigest: pipelineBenchmarkDigest(composition),
        expected: expectedComposition,
        body: { try composition.outer.composed(after: composition.inner) },
        checksum: { try pipelineBenchmarkDigest($0) }
    )
}

@Test("SpanMap conserva half-open, coalescenza, campi Codable e round-trip")
func spanMapOptimizationPreservesBoundariesAndEncoding() throws {
    let map = try GlifiSpanMap(
        contractIdentifier: "spanmap-boundaries-v1",
        sourceRevisionID: spanMapOptimizationRevision(),
        inputByteCount: 8, outputByteCount: 8,
        segments: [
            spanMapSegment(0, 2, inputs: [(1, 3)], kind: .exact),
            spanMapSegment(2, 4, inputs: [(3, 5)], kind: .exact),
            spanMapSegment(4, 6, inputs: [], kind: .synthetic),
            spanMapSegment(6, 8, inputs: [(5, 7)], kind: .exact),
        ])
    for (start, end, expected) in [
        (0, 2, [(1, 3)]), (2, 4, [(3, 5)]), (1, 3, [(2, 4)]),
        (4, 6, []), (6, 8, [(5, 7)]), (0, 8, [(1, 7)]),
    ] {
        let query = try GlifiUTF8Range(start: start, end: end)
        #expect(
            try map.sourceRanges(for: query)
                == expected.map { try GlifiUTF8Range(start: $0.0, end: $0.1) })
    }
    let encoded = try spanMapCanonicalData(map)
    #expect(encoded == (try spanMapCanonicalData(LegacySpanMapRecord(map))))
    let keys = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(
        Set(keys.keys) == [
            "contractIdentifier", "sourceRevisionID", "inputSpace", "outputSpace",
            "inputByteCount", "outputByteCount", "segments",
        ])
    let decoded = try JSONDecoder().decode(GlifiSpanMap.self, from: encoded)
    #expect(decoded == map)
    for query in [try GlifiUTF8Range(start: 0, end: 8), try GlifiUTF8Range(start: 1, end: 3)] {
        #expect(try decoded.sourceRanges(for: query) == map.sourceRanges(for: query))
    }
    do {
        _ = try map.sourceRanges(for: GlifiUTF8Range(start: 8, end: 9))
        Issue.record("An out-of-bounds lineage query succeeded")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "text.span-out-of-bounds")
        #expect(failure.category == .invalidInput)
        #expect(failure.operation == .importText)
        #expect(failure.retainedState == .unchanged)
    }
}

@Test("La decodifica legacy conserva ordine non conforme e risultati del percorso lineare")
func spanMapOptimizationPreservesLegacyDecodedMaps() throws {
    let variants: [[GlifiSpanMapSegment]] = [
        [
            try spanMapSegment(2, 4, inputs: [(10, 12)], kind: .exact),
            try spanMapSegment(0, 2, inputs: [(0, 2)], kind: .exact),
        ],
        [
            try spanMapSegment(0, 4, inputs: [(0, 4)], kind: .exact),
            try spanMapSegment(2, 6, inputs: [(10, 14)], kind: .exact),
        ],
        [
            try spanMapSegment(0, 2, inputs: [(0, 2)], kind: .exact),
            try spanMapSegment(4, 6, inputs: [(10, 12)], kind: .exact),
        ],
    ]
    for segments in variants {
        let legacy = LegacySpanMapRecord(
            contractIdentifier: "spanmap-legacy-v1",
            sourceRevisionID: try spanMapOptimizationRevision(),
            inputSpace: .sourceBytes, outputSpace: .extractedUTF8,
            inputByteCount: 24, outputByteCount: 8, segments: segments)
        let data = try spanMapCanonicalData(legacy)
        let map = try JSONDecoder().decode(GlifiSpanMap.self, from: data)
        #expect(try spanMapCanonicalData(map) == data)
        for (start, end) in [(0, 8), (0, 2), (1, 5), (2, 4), (6, 8)] {
            let range = try GlifiUTF8Range(start: start, end: end)
            #expect(try map.sourceRanges(for: range) == linearSourceRanges(map, for: range))
        }
        let outer = try GlifiSpanMap(
            contractIdentifier: "spanmap-legacy-outer-v1", sourceRevisionID: map.sourceRevisionID,
            inputByteCount: 8, outputByteCount: 4,
            segments: [spanMapSegment(0, 4, inputs: [(0, 8)], kind: .derivational)],
            inputSpace: .extractedUTF8, outputSpace: .normalizedUTF8)
        #expect(try outer.composed(after: map) == linearCompose(outer, after: map))
    }

    // ADR-0042 preserves legacy map geometry with valid intervals, while every
    // decoded nested interval now obeys the range constructor's invariants.
    let valid = try GlifiSpanMap(
        contractIdentifier: "spanmap-nested-v1", sourceRevisionID: spanMapOptimizationRevision(),
        inputByteCount: 4, outputByteCount: 4,
        segments: [spanMapSegment(0, 4, inputs: [], kind: .synthetic)])
    let object = try #require(
        JSONSerialization.jsonObject(with: spanMapCanonicalData(valid)) as? [String: Any])
    for range in [["start": 4, "end": 2], ["start": 2, "end": 2]] {
        var invalid = object
        var segments = try #require(object["segments"] as? [[String: Any]])
        segments[0]["outputRange"] = range
        invalid["segments"] = segments
        let data = try JSONSerialization.data(withJSONObject: invalid)
        #expect(throws: GlifiFailure.self) {
            try JSONDecoder().decode(GlifiSpanMap.self, from: data)
        }
    }
}

private struct SpanMapLookupFixture: Encodable {
    let map: GlifiSpanMap
    let queries: [GlifiUTF8Range]
}

private struct SpanMapCompositionFixture: Encodable {
    let inner: GlifiSpanMap
    let outer: GlifiSpanMap
}

private func spanMapOptimizationRevision() throws -> SourceRevisionID {
    try SourceRevisionID(canonicalValue: "source-revision:00000000-0000-0000-0000-000000000202")
}

private func spanMapSegment(
    _ start: Int, _ end: Int, inputs: [(Int, Int)], kind: GlifiSpanMappingKind
) throws -> GlifiSpanMapSegment {
    try GlifiSpanMapSegment(
        outputRange: GlifiUTF8Range(start: start, end: end),
        inputRanges: inputs.map { try GlifiUTF8Range(start: $0.0, end: $0.1) }, kind: kind)
}

private func spanMapLookupFixture(segmentCount: Int, queryCount: Int) throws -> SpanMapLookupFixture
{
    var segments: [GlifiSpanMapSegment] = []
    for index in 0..<segmentCount {
        let output = 4 * index
        let input = 8 * index
        let segment: GlifiSpanMapSegment
        switch index % 4 {
        case 0:
            segment = try spanMapSegment(
                output, output + 4, inputs: [(input, input + 4)], kind: .exact)
        case 1:
            segment = try spanMapSegment(
                output, output + 4, inputs: [(input, input + 1), (input + 2, input + 4)],
                kind: .contributive)
        case 2:
            segment = try spanMapSegment(
                output, output + 4, inputs: [(input + 1, input + 3)], kind: .derivational)
        default: segment = try spanMapSegment(output, output + 4, inputs: [], kind: .synthetic)
        }
        segments.append(segment)
    }
    let map = try GlifiSpanMap(
        contractIdentifier: "spanmap-sparse-fixture-v1",
        sourceRevisionID: spanMapOptimizationRevision(),
        inputByteCount: 8 * segmentCount, outputByteCount: 4 * segmentCount, segments: segments)
    let queries = try (0..<queryCount).map { index in
        let start = (index * 7_919) % (map.outputByteCount - 16)
        return try GlifiUTF8Range(start: start, end: start + 1 + index % 9)
    }
    return SpanMapLookupFixture(map: map, queries: queries)
}

private func spanMapCompositionFixture(segmentCount: Int) throws -> SpanMapCompositionFixture {
    let inner = try spanMapLookupFixture(segmentCount: segmentCount, queryCount: 1).map
    var segments: [GlifiSpanMapSegment] = []
    for index in 0..<segmentCount {
        let start = 4 * index
        let selected = (index * 7) % segmentCount
        let first = 4 * selected
        let second = 4 * ((selected + segmentCount / 2) % segmentCount)
        let segment: GlifiSpanMapSegment
        switch index % 4 {
        case 0:
            segment = try spanMapSegment(
                start, start + 4, inputs: [(first, first + 4)], kind: .exact)
        case 1:
            segment = try spanMapSegment(
                start, start + 4, inputs: [(first, first + 2), (second + 1, second + 3)],
                kind: .contributive)
        case 2:
            segment = try spanMapSegment(
                start, start + 4, inputs: [(first + 1, min(inner.outputByteCount, first + 10))],
                kind: .derivational)
        default: segment = try spanMapSegment(start, start + 4, inputs: [], kind: .synthetic)
        }
        segments.append(segment)
    }
    let outer = try GlifiSpanMap(
        contractIdentifier: "spanmap-compose-fixture-v1", sourceRevisionID: inner.sourceRevisionID,
        inputByteCount: inner.outputByteCount, outputByteCount: 4 * segmentCount,
        segments: segments,
        inputSpace: .extractedUTF8, outputSpace: .normalizedUTF8)
    return SpanMapCompositionFixture(inner: inner, outer: outer)
}

private func lookupAll(_ fixture: SpanMapLookupFixture) throws -> [[GlifiUTF8Range]] {
    try fixture.queries.map { try fixture.map.sourceRanges(for: $0) }
}

private func linearLookupAll(_ fixture: SpanMapLookupFixture) throws -> [[GlifiUTF8Range]] {
    try fixture.queries.map { try linearSourceRanges(fixture.map, for: $0) }
}

private func linearSourceRanges(_ map: GlifiSpanMap, for query: GlifiUTF8Range) throws
    -> [GlifiUTF8Range]
{
    var result: [GlifiUTF8Range] = []
    for segment in map.segments {
        let lower = max(query.start, segment.outputRange.start)
        let upper = min(query.end, segment.outputRange.end)
        guard lower < upper else { continue }
        switch segment.kind {
        case .exact:
            let input = segment.inputRanges[0]
            try appendLinearOrigin(
                GlifiUTF8Range(
                    start: input.start + lower - segment.outputRange.start,
                    end: input.start + upper - segment.outputRange.start), to: &result)
        case .contributive, .derivational:
            for input in segment.inputRanges { try appendLinearOrigin(input, to: &result) }
        case .synthetic: break
        }
    }
    return result
}

private func linearCompose(_ outer: GlifiSpanMap, after inner: GlifiSpanMap) throws -> GlifiSpanMap
{
    var segments: [GlifiSpanMapSegment] = []
    for segment in outer.segments {
        var origins: [GlifiUTF8Range] = []
        var weakest = linearMappingStrength(segment.kind)
        for range in segment.inputRanges {
            for piece in inner.segments {
                let lower = max(range.start, piece.outputRange.start)
                let upper = min(range.end, piece.outputRange.end)
                guard lower < upper else { continue }
                switch piece.kind {
                case .exact:
                    let base = piece.inputRanges[0].start - piece.outputRange.start
                    try appendLinearOrigin(
                        GlifiUTF8Range(start: base + lower, end: base + upper), to: &origins)
                case .contributive, .derivational:
                    weakest = max(weakest, linearMappingStrength(piece.kind))
                    for input in piece.inputRanges where !origins.contains(input) {
                        try appendLinearOrigin(input, to: &origins)
                    }
                case .synthetic: break
                }
            }
        }
        let kind: GlifiSpanMappingKind
        if origins.isEmpty {
            kind = .synthetic
        } else if weakest == 0, origins.count == 1, origins[0].count == segment.outputRange.count {
            kind = .exact
        } else if weakest <= 1, origins.count >= 2 {
            kind = .contributive
        } else {
            kind = .derivational
        }
        segments.append(
            GlifiSpanMapSegment(outputRange: segment.outputRange, inputRanges: origins, kind: kind))
    }
    return try GlifiSpanMap(
        contractIdentifier: "\(outer.contractIdentifier)∘\(inner.contractIdentifier)",
        sourceRevisionID: outer.sourceRevisionID, inputByteCount: inner.inputByteCount,
        outputByteCount: outer.outputByteCount, segments: segments,
        inputSpace: inner.inputSpace, outputSpace: outer.outputSpace)
}

private func linearMappingStrength(_ kind: GlifiSpanMappingKind) -> Int {
    switch kind {
    case .exact: 0
    case .contributive: 1
    case .derivational, .synthetic: 2
    }
}

private func appendLinearOrigin(_ range: GlifiUTF8Range, to result: inout [GlifiUTF8Range]) throws {
    if let last = result.last, last.end == range.start {
        result[result.count - 1] = try GlifiUTF8Range(start: last.start, end: range.end)
    } else {
        result.append(range)
    }
}

private func spanMapCanonicalData(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private struct LegacySpanMapRecord: Codable {
    let contractIdentifier: String
    let sourceRevisionID: SourceRevisionID
    let inputSpace: GlifiTextCoordinateSpace
    let outputSpace: GlifiTextCoordinateSpace
    let inputByteCount: Int
    let outputByteCount: Int
    let segments: [GlifiSpanMapSegment]

    init(
        contractIdentifier: String, sourceRevisionID: SourceRevisionID,
        inputSpace: GlifiTextCoordinateSpace, outputSpace: GlifiTextCoordinateSpace,
        inputByteCount: Int, outputByteCount: Int, segments: [GlifiSpanMapSegment]
    ) {
        self.contractIdentifier = contractIdentifier
        self.sourceRevisionID = sourceRevisionID
        self.inputSpace = inputSpace
        self.outputSpace = outputSpace
        self.inputByteCount = inputByteCount
        self.outputByteCount = outputByteCount
        self.segments = segments
    }

    init(_ map: GlifiSpanMap) {
        self.init(
            contractIdentifier: map.contractIdentifier, sourceRevisionID: map.sourceRevisionID,
            inputSpace: map.inputSpace, outputSpace: map.outputSpace,
            inputByteCount: map.inputByteCount, outputByteCount: map.outputByteCount,
            segments: map.segments)
    }
}
