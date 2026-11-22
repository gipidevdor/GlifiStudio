// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Trasformazioni casuali a seed fisso: ogni segmento copia un intervallo (exact), inserisce byte
// (synthetic), deriva da un intervallo (derivational) o combina due intervalli (contributive).
private struct Transformation {
    let output: [UInt8]
    let map: GlifiSpanMap
}

private func randomTransformation(
    of input: [UInt8],
    random: inout GlifiSplitMix64,
    revision: SourceRevisionID,
    spaces: (GlifiTextCoordinateSpace, GlifiTextCoordinateSpace)
) throws -> Transformation {
    func below(_ bound: Int) -> Int { Int(random.next() % UInt64(max(bound, 1))) }
    func randomRange() throws -> GlifiUTF8Range {
        let start = below(input.count)
        return try GlifiUTF8Range(start: start, end: start + 1 + below(min(4, input.count - start)))
    }
    var output: [UInt8] = []
    var segments: [GlifiSpanMapSegment] = []
    for _ in 0..<(1 + below(8)) {
        let start = output.count
        let kind = below(4)
        var inputs: [GlifiUTF8Range] = []
        let segmentKind: GlifiSpanMappingKind
        switch kind {
        case 0 where !input.isEmpty:
            let range = try randomRange()
            output += input[range.start..<range.end]
            inputs = [range]
            segmentKind = .exact
        case 2 where !input.isEmpty:
            inputs = [try randomRange()]
            output += [0x44, 0x45][0..<(1 + below(2))]
            segmentKind = .derivational
        case 3 where input.count >= 2:
            let first = try randomRange()
            var second = try randomRange()
            while second == first { second = try randomRange() }
            inputs = [first, second]
            output += [0x43]
            segmentKind = .contributive
        default:
            output += [0x53]
            segmentKind = .synthetic
        }
        segments.append(
            GlifiSpanMapSegment(
                outputRange: try GlifiUTF8Range(start: start, end: output.count),
                inputRanges: inputs, kind: segmentKind))
    }
    let map = try GlifiSpanMap(
        contractIdentifier: "test-transform-v1", sourceRevisionID: revision,
        inputByteCount: input.count, outputByteCount: output.count, segments: segments,
        inputSpace: spaces.0, outputSpace: spaces.1)
    return Transformation(output: output, map: map)
}

private func byteSet(_ ranges: [GlifiUTF8Range]) -> Set<Int> {
    Set(ranges.flatMap { Array($0.start..<$0.end) })
}

@Test("La composizione di SpanMap conserva ogni origine e i byte dei tratti exact")
func spanMapCompositionPreservesEveryOrigin() throws {
    var random = GlifiSplitMix64(seed: 0x5EED_0078)
    let revision = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000078")
    var kinds: [GlifiSpanMappingKind: Int] = [:]
    for _ in 0..<500 {
        let source = (0..<(4 + Int(random.next() % 20))).map { _ in UInt8(97 + random.next() % 26) }
        let inner = try randomTransformation(
            of: source, random: &random, revision: revision, spaces: (.sourceBytes, .extractedUTF8))
        let outer = try randomTransformation(
            of: inner.output, random: &random, revision: revision,
            spaces: (.extractedUTF8, .normalizedUTF8))
        let composed = try outer.map.composed(after: inner.map)
        #expect(composed.inputSpace == .sourceBytes)
        #expect(composed.outputSpace == .normalizedUTF8)
        #expect(composed.inputByteCount == source.count)
        #expect(composed.outputByteCount == outer.output.count)
        for (segment, original) in zip(composed.segments, outer.map.segments) {
            kinds[segment.kind, default: 0] += 1
            // Tutte e sole le origini raggiungibili attraverso le due mappe.
            let expected = try original.inputRanges.reduce(into: Set<Int>()) { result, range in
                result.formUnion(byteSet(try inner.map.sourceRanges(for: range)))
            }
            #expect(byteSet(segment.inputRanges) == expected)
            if segment.kind == .exact, let origin = segment.inputRanges.first {
                #expect(
                    Array(outer.output[segment.outputRange.start..<segment.outputRange.end])
                        == Array(source[origin.start..<origin.end]))
            }
            if original.kind == .synthetic { #expect(segment.kind == .synthetic) }
            if original.kind == .derivational { #expect(segment.kind != .exact) }
        }
    }
    // Il generatore esercita tutte le classi composte.
    for kind in [GlifiSpanMappingKind.exact, .contributive, .derivational, .synthetic] {
        #expect((kinds[kind] ?? 0) > 20)
    }
}

@Test("Composizione di mappe incompatibili e contributive con un solo intervallo sono rifiutate")
func spanMapCompositionRejectsIncompatibleMaps() throws {
    let revision = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000079")
    let identity = try GlifiSpanMap(
        contractIdentifier: "identity", sourceRevisionID: revision, inputByteCount: 3,
        outputByteCount: 3,
        segments: [
            GlifiSpanMapSegment(
                outputRange: try GlifiUTF8Range(start: 0, end: 3),
                inputRanges: [try GlifiUTF8Range(start: 0, end: 3)], kind: .exact)
        ])
    // Stesso spazio di ingresso e uscita non collegabile: sourceBytes→extracted dopo se stessa.
    #expect(throws: GlifiFailure.self) { _ = try identity.composed(after: identity) }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiSpanMap(
            contractIdentifier: "bad", sourceRevisionID: revision, inputByteCount: 3,
            outputByteCount: 1,
            segments: [
                GlifiSpanMapSegment(
                    outputRange: try GlifiUTF8Range(start: 0, end: 1),
                    inputRanges: [try GlifiUTF8Range(start: 0, end: 1)], kind: .contributive)
            ])
    }
}
