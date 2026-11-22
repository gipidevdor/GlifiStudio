// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Stable coordinate spaces used by the first text extraction pipeline.
public enum GlifiTextCoordinateSpace: String, Codable, Sendable {
    case sourceBytes
    case extractedUTF8
    case normalizedUTF8
}

/// Strength of the relationship represented by one span-map segment.
public enum GlifiSpanMappingKind: String, Codable, Sendable {
    /// Output bytes are an unchanged contiguous copy of the input bytes.
    case exact
    /// Several input regions contribute to the output without one-to-one inversion.
    case contributive
    /// Output is deterministically derived from the declared input ranges.
    case derivational
    /// Output has no source bytes, for example an inserted structural separator.
    case synthetic
}

/// One ordered mapping from an extracted UTF-8 interval to source-byte intervals.
public struct GlifiSpanMapSegment: Codable, Equatable, Sendable {
    /// Non-empty interval in the output coordinate space.
    public let outputRange: GlifiUTF8Range
    /// Ordered contributing intervals in the input coordinate space.
    public let inputRanges: [GlifiUTF8Range]
    /// Declared relationship between output and input.
    public let kind: GlifiSpanMappingKind

    /// Creates one segment.
    ///
    /// Full structural validation is performed by `GlifiSpanMap`.
    public init(
        outputRange: GlifiUTF8Range,
        inputRanges: [GlifiUTF8Range],
        kind: GlifiSpanMappingKind
    ) {
        self.outputRange = outputRange
        self.inputRanges = inputRanges
        self.kind = kind
    }
}

/// Versioned total map from extracted UTF-8 bytes back to immutable source bytes.
public struct GlifiSpanMap: Codable, Equatable, Sendable {
    /// Stable mapping contract implemented by this representation.
    public let contractIdentifier: String
    /// Source revision owning every input range.
    public let sourceRevisionID: SourceRevisionID
    /// Input coordinate space.
    public let inputSpace: GlifiTextCoordinateSpace
    /// Output coordinate space.
    public let outputSpace: GlifiTextCoordinateSpace
    /// Exact source length, including an optional UTF-8 BOM.
    public let inputByteCount: Int
    /// Exact extracted representation length.
    public let outputByteCount: Int
    /// Ordered segments covering every output byte exactly once.
    public let segments: [GlifiSpanMapSegment]

    private let supportsIndexedLookup: Bool

    private enum CodingKeys: String, CodingKey {
        case contractIdentifier
        case sourceRevisionID
        case inputSpace
        case outputSpace
        case inputByteCount
        case outputByteCount
        case segments
    }

    /// Creates and validates a total, bounded span map.
    public init(
        contractIdentifier: String,
        sourceRevisionID: SourceRevisionID,
        inputByteCount: Int,
        outputByteCount: Int,
        segments: [GlifiSpanMapSegment],
        inputSpace: GlifiTextCoordinateSpace = .sourceBytes,
        outputSpace: GlifiTextCoordinateSpace = .extractedUTF8
    ) throws {
        guard !contractIdentifier.isEmpty,
            inputByteCount >= 0,
            outputByteCount >= 0,
            segments.count <= max(outputByteCount, 1)
        else {
            throw spanMapFailure("text.invalid-span-map")
        }

        var nextOutputOffset = 0
        var supportsIndexedLookup = true
        for segment in segments {
            guard segment.outputRange.start == nextOutputOffset,
                segment.outputRange.end <= outputByteCount,
                segment.inputRanges.allSatisfy({
                    $0.start >= 0 && $0.end <= inputByteCount
                })
            else {
                throw spanMapFailure("text.invalid-span-map")
            }
            switch segment.kind {
            case .exact:
                guard segment.inputRanges.count == 1,
                    segment.inputRanges[0].count == segment.outputRange.count
                else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            case .derivational:
                guard !segment.inputRanges.isEmpty else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            case .contributive:
                guard segment.inputRanges.count >= 2 else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            case .synthetic:
                guard segment.inputRanges.isEmpty else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            }
            // Contiguous coverage implies ordering only when every nested range is nonempty.
            supportsIndexedLookup =
                supportsIndexedLookup && segment.outputRange.end > segment.outputRange.start
            nextOutputOffset = segment.outputRange.end
        }
        guard nextOutputOffset == outputByteCount else {
            throw spanMapFailure("text.invalid-span-map")
        }

        self.contractIdentifier = contractIdentifier
        self.sourceRevisionID = sourceRevisionID
        self.inputSpace = inputSpace
        self.outputSpace = outputSpace
        self.inputByteCount = inputByteCount
        self.outputByteCount = outputByteCount
        self.segments = segments
        self.supportsIndexedLookup = supportsIndexedLookup
    }

    /// Validates each decoded segment while retaining locally valid legacy map geometry.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contractIdentifier = try container.decode(String.self, forKey: .contractIdentifier)
        sourceRevisionID = try container.decode(SourceRevisionID.self, forKey: .sourceRevisionID)
        inputSpace = try container.decode(GlifiTextCoordinateSpace.self, forKey: .inputSpace)
        outputSpace = try container.decode(GlifiTextCoordinateSpace.self, forKey: .outputSpace)
        inputByteCount = try container.decode(Int.self, forKey: .inputByteCount)
        outputByteCount = try container.decode(Int.self, forKey: .outputByteCount)
        segments = try container.decode([GlifiSpanMapSegment].self, forKey: .segments)
        guard !contractIdentifier.isEmpty, inputByteCount >= 0, outputByteCount >= 0 else {
            throw spanMapFailure("text.invalid-span-map")
        }
        let decodedInputByteCount = inputByteCount
        for segment in segments {
            guard segment.outputRange.end <= outputByteCount,
                segment.inputRanges.allSatisfy({ $0.end <= decodedInputByteCount })
            else {
                throw spanMapFailure("text.invalid-span-map")
            }
            switch segment.kind {
            case .exact:
                guard segment.inputRanges.count == 1,
                    segment.inputRanges[0].count == segment.outputRange.count
                else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            case .derivational:
                guard !segment.inputRanges.isEmpty else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            case .contributive:
                guard segment.inputRanges.count >= 2 else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            case .synthetic:
                guard segment.inputRanges.isEmpty else {
                    throw spanMapFailure("text.invalid-span-map")
                }
            }
        }
        supportsIndexedLookup = Self.segmentsSupportIndexedLookup(segments)
    }

    /// Resolves every source interval contributing to one extracted interval.
    ///
    /// Ordered segments use binary bounds; nonconforming legacy decoding retains linear traversal.
    public func sourceRanges(for outputRange: GlifiUTF8Range) throws -> [GlifiUTF8Range] {
        guard outputRange.end <= outputByteCount else {
            throw spanMapFailure("text.span-out-of-bounds")
        }
        var result: [GlifiUTF8Range] = []
        for segment in overlappingSegments(for: outputRange) {
            let lower = max(outputRange.start, segment.outputRange.start)
            let upper = min(outputRange.end, segment.outputRange.end)
            guard lower < upper else { continue }

            switch segment.kind {
            case .exact:
                let source = segment.inputRanges[0]
                let relativeStart = lower - segment.outputRange.start
                let relativeEnd = upper - segment.outputRange.start
                try append(
                    GlifiUTF8Range(
                        start: source.start + relativeStart,
                        end: source.start + relativeEnd
                    ),
                    to: &result
                )
            case .derivational, .contributive:
                for inputRange in segment.inputRanges {
                    try append(inputRange, to: &result)
                }
            case .synthetic:
                continue
            }
        }
        return result
    }

    /// Composes `self` (C→B) after `inner` (B→A) into a map C→A preserving every origin.
    ///
    /// The composed class is the weakest met along the path in the order
    /// `exact` < `contributive` < `derivational`; an `exact` path stays exact only when its
    /// origins form one interval of the same length. A segment without origins is `synthetic`.
    public func composed(after inner: GlifiSpanMap) throws -> GlifiSpanMap {
        guard inputSpace == inner.outputSpace,
            inputByteCount == inner.outputByteCount,
            sourceRevisionID == inner.sourceRevisionID
        else {
            throw GlifiFailure(
                code: "text.incompatible-span-maps",
                category: .invalidInput,
                operation: .importText,
                retryDisposition: .afterCorrection,
                retainedState: .unchanged,
                messageKey: "failure.text.incompatible-span-maps"
            )
        }
        func strength(_ kind: GlifiSpanMappingKind) -> Int {
            switch kind {
            case .exact: 0
            case .contributive: 1
            case .derivational, .synthetic: 2
            }
        }
        var composedSegments: [GlifiSpanMapSegment] = []
        composedSegments.reserveCapacity(segments.count)
        for segment in segments {
            var origins: [GlifiUTF8Range] = []
            var weakest = strength(segment.kind)
            for range in segment.inputRanges {
                for piece in inner.overlappingSegments(for: range) {
                    let lower = max(range.start, piece.outputRange.start)
                    let upper = min(range.end, piece.outputRange.end)
                    guard lower < upper else { continue }
                    switch piece.kind {
                    case .exact:
                        let base = piece.inputRanges[0].start - piece.outputRange.start
                        try append(
                            GlifiUTF8Range(start: base + lower, end: base + upper), to: &origins)
                    case .contributive, .derivational:
                        weakest = max(weakest, strength(piece.kind))
                        for origin in piece.inputRanges where !origins.contains(origin) {
                            try append(origin, to: &origins)
                        }
                    case .synthetic:
                        continue
                    }
                }
            }
            let kind: GlifiSpanMappingKind
            if origins.isEmpty {
                kind = .synthetic
            } else if weakest == 0, origins.count == 1,
                origins[0].count == segment.outputRange.count
            {
                kind = .exact
            } else if weakest <= 1, origins.count >= 2 {
                kind = .contributive
            } else {
                kind = .derivational
            }
            composedSegments.append(
                GlifiSpanMapSegment(
                    outputRange: segment.outputRange, inputRanges: origins, kind: kind))
        }
        return try GlifiSpanMap(
            contractIdentifier: "\(contractIdentifier)∘\(inner.contractIdentifier)",
            sourceRevisionID: sourceRevisionID,
            inputByteCount: inner.inputByteCount,
            outputByteCount: outputByteCount,
            segments: composedSegments,
            inputSpace: inner.inputSpace,
            outputSpace: outputSpace
        )
    }

    private static func segmentsSupportIndexedLookup(_ segments: [GlifiSpanMapSegment]) -> Bool {
        var previousEnd: Int?
        for segment in segments {
            let range = segment.outputRange
            guard range.start < range.end else { return false }
            if let previousEnd, range.start < previousEnd { return false }
            previousEnd = range.end
        }
        return true
    }

    private func overlappingSegments(for range: GlifiUTF8Range) -> ArraySlice<GlifiSpanMapSegment> {
        guard supportsIndexedLookup else { return segments[...] }
        guard range.start < range.end else { return segments[0..<0] }

        var lower = 0
        var upper = segments.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if segments[middle].outputRange.end <= range.start {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        let first = lower
        upper = segments.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if segments[middle].outputRange.start < range.end {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return segments[first..<lower]
    }

    private func append(_ range: GlifiUTF8Range, to result: inout [GlifiUTF8Range]) throws {
        guard let last = result.last, last.end == range.start else {
            result.append(range)
            return
        }
        result[result.count - 1] = try GlifiUTF8Range(start: last.start, end: range.end)
    }
}

private func spanMapFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: .invalidInput,
        operation: .importText,
        retryDisposition: .afterCorrection,
        retainedState: .unchanged,
        messageKey: "failure.\(code)"
    )
}
