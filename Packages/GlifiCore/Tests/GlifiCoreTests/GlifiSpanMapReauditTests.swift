// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La decodifica delle mappe rifiuta segmenti localmente inconsistenti prima del lookup")
func spanMapReauditRejectsLocallyInvalidDecodedSegments() throws {
    let output = try GlifiUTF8Range(start: 0, end: 4)
    let input = try GlifiUTF8Range(start: 0, end: 4)
    let exact = GlifiSpanMapSegment(outputRange: output, inputRanges: [input], kind: .exact)
    let synthetic = GlifiSpanMapSegment(outputRange: output, inputRanges: [], kind: .synthetic)
    let invalid: [(String, Int, Int, GlifiSpanMapSegment)] = [
        ("", 4, 4, exact),
        ("spanmap-reaudit-v1", -1, 4, synthetic),
        ("spanmap-reaudit-v1", 4, -1, exact),
        ("spanmap-reaudit-v1", 4, 3, exact),
        ("spanmap-reaudit-v1", 3, 4, exact),
        (
            "spanmap-reaudit-v1", 4, 4,
            GlifiSpanMapSegment(outputRange: output, inputRanges: [], kind: .exact)
        ),
        (
            "spanmap-reaudit-v1", 4, 4,
            GlifiSpanMapSegment(outputRange: output, inputRanges: [input, input], kind: .exact)
        ),
        (
            "spanmap-reaudit-v1", Int.max, 4,
            GlifiSpanMapSegment(
                outputRange: output,
                inputRanges: [try GlifiUTF8Range(start: Int.max - 1, end: Int.max)], kind: .exact)
        ),
        (
            "spanmap-reaudit-v1", 4, 4,
            GlifiSpanMapSegment(outputRange: output, inputRanges: [], kind: .derivational)
        ),
        (
            "spanmap-reaudit-v1", 4, 4,
            GlifiSpanMapSegment(outputRange: output, inputRanges: [], kind: .contributive)
        ),
        (
            "spanmap-reaudit-v1", 4, 4,
            GlifiSpanMapSegment(outputRange: output, inputRanges: [input], kind: .contributive)
        ),
        (
            "spanmap-reaudit-v1", 4, 4,
            GlifiSpanMapSegment(outputRange: output, inputRanges: [input], kind: .synthetic)
        ),
    ]
    for (index, item) in invalid.enumerated() {
        let data = try spanMapReauditData(
            contractIdentifier: item.0, inputByteCount: item.1, outputByteCount: item.2,
            segments: [item.3])
        do {
            _ = try JSONDecoder().decode(GlifiSpanMap.self, from: data)
            Issue.record("Invalid span-map case \(index) was accepted")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "text.invalid-span-map")
            #expect(failure.category == .invalidInput)
            #expect(failure.operation == .importText)
            #expect(failure.retainedState == .unchanged)
        }
    }
}

@Test("La decodifica conserva mappe legacy valide con più segmenti che byte di output")
func spanMapReauditRetainsDenseLegacyOverlap() throws {
    let range = try GlifiUTF8Range(start: 0, end: 1)
    let segment = GlifiSpanMapSegment(outputRange: range, inputRanges: [range], kind: .exact)
    let data = try spanMapReauditData(
        inputByteCount: 1, outputByteCount: 1, segments: [segment, segment, segment])
    let decoded = try JSONDecoder().decode(GlifiSpanMap.self, from: data)
    #expect(decoded.segments.count > decoded.outputByteCount)
    #expect(try decoded.sourceRanges(for: range) == [range, range, range])
    #expect(try spanMapReauditCanonicalData(decoded) == data)
}

@Test("Lookup e composizione validi conservano gli estremi Int senza overflow di traslazione")
func spanMapReauditPreservesMaximumRepresentableOffsets() throws {
    let revision = try spanMapReauditRevision()
    let sourceEnd = try GlifiUTF8Range(start: Int.max - 4, end: Int.max)
    let output = try GlifiUTF8Range(start: 0, end: 4)
    let positive = try GlifiSpanMap(
        contractIdentifier: "spanmap-positive-offset-v1", sourceRevisionID: revision,
        inputByteCount: Int.max, outputByteCount: 4,
        segments: [GlifiSpanMapSegment(outputRange: output, inputRanges: [sourceEnd], kind: .exact)]
    )
    let decoded = try JSONDecoder().decode(
        GlifiSpanMap.self, from: spanMapReauditCanonicalData(positive))
    #expect(
        try decoded.sourceRanges(for: GlifiUTF8Range(start: 3, end: 4))
            == [GlifiUTF8Range(start: Int.max - 1, end: Int.max)])

    let outerOutput = try GlifiUTF8Range(start: 0, end: 2)
    let positiveOuter = try GlifiSpanMap(
        contractIdentifier: "spanmap-positive-outer-v1", sourceRevisionID: revision,
        inputByteCount: 4, outputByteCount: 2,
        segments: [
            GlifiSpanMapSegment(
                outputRange: outerOutput, inputRanges: [GlifiUTF8Range(start: 2, end: 4)],
                kind: .exact)
        ], inputSpace: .extractedUTF8, outputSpace: .normalizedUTF8)
    #expect(
        try positiveOuter.composed(after: decoded).sourceRanges(for: outerOutput)
            == [GlifiUTF8Range(start: Int.max - 2, end: Int.max)])

    let negative = try GlifiSpanMap(
        contractIdentifier: "spanmap-negative-offset-v1", sourceRevisionID: revision,
        inputByteCount: 4, outputByteCount: Int.max,
        segments: [
            GlifiSpanMapSegment(
                outputRange: GlifiUTF8Range(start: 0, end: Int.max - 4), inputRanges: [],
                kind: .synthetic),
            GlifiSpanMapSegment(outputRange: sourceEnd, inputRanges: [output], kind: .exact),
        ])
    let negativeDecoded = try JSONDecoder().decode(
        GlifiSpanMap.self, from: spanMapReauditCanonicalData(negative))
    let selected = try GlifiUTF8Range(start: Int.max - 2, end: Int.max)
    #expect(
        try negativeDecoded.sourceRanges(for: selected) == [GlifiUTF8Range(start: 2, end: 4)])
    let negativeOuter = try GlifiSpanMap(
        contractIdentifier: "spanmap-negative-outer-v1", sourceRevisionID: revision,
        inputByteCount: Int.max, outputByteCount: 2,
        segments: [
            GlifiSpanMapSegment(outputRange: outerOutput, inputRanges: [selected], kind: .exact)
        ], inputSpace: .extractedUTF8, outputSpace: .normalizedUTF8)
    #expect(
        try negativeOuter.composed(after: negativeDecoded).sourceRanges(for: outerOutput)
            == [GlifiUTF8Range(start: 2, end: 4)])
}

private func spanMapReauditRevision() throws -> SourceRevisionID {
    try SourceRevisionID(canonicalValue: "source-revision:00000000-0000-0000-0000-000000000234")
}

private func spanMapReauditData(
    contractIdentifier: String = "spanmap-reaudit-v1", inputByteCount: Int,
    outputByteCount: Int, segments: [GlifiSpanMapSegment]
) throws -> Data {
    try spanMapReauditCanonicalData(
        SpanMapReauditRecord(
            contractIdentifier: contractIdentifier, sourceRevisionID: spanMapReauditRevision(),
            inputSpace: .sourceBytes, outputSpace: .extractedUTF8,
            inputByteCount: inputByteCount, outputByteCount: outputByteCount, segments: segments))
}

private func spanMapReauditCanonicalData(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private struct SpanMapReauditRecord: Encodable {
    let contractIdentifier: String
    let sourceRevisionID: SourceRevisionID
    let inputSpace: GlifiTextCoordinateSpace
    let outputSpace: GlifiTextCoordinateSpace
    let inputByteCount: Int
    let outputByteCount: Int
    let segments: [GlifiSpanMapSegment]
}
