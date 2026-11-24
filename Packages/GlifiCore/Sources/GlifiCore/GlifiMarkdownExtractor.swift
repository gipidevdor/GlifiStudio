// SPDX-License-Identifier: BSD-3-Clause

import Foundation

struct GlifiExtractedText: Sendable {
    let text: String
    let spanMap: GlifiSpanMap
}

/// Deterministic, non-executing Markdown text extraction for the 0.1 baseline.
struct GlifiMarkdownExtractor: Sendable {
    static let contractIdentifier = "md-extract-v1"

    func extract(
        _ source: String,
        sourceRevisionID: SourceRevisionID,
        sourceByteOffset: Int,
        sourceByteCount: Int
    ) throws -> GlifiExtractedText {
        var parser = MarkdownExtractionParser(
            bytes: Array(source.utf8),
            sourceByteOffset: sourceByteOffset
        )
        let extraction = try parser.extract()
        let text = try strictString(extraction.output)
        let spanMap = try GlifiSpanMap(
            contractIdentifier: Self.contractIdentifier,
            sourceRevisionID: sourceRevisionID,
            inputByteCount: sourceByteCount,
            outputByteCount: extraction.output.count,
            segments: extraction.segments
        )
        return GlifiExtractedText(text: text, spanMap: spanMap)
    }

    private func strictString(_ data: Data) throws -> String {
        guard let text = String(validating: data, as: UTF8.self) else {
            throw GlifiFailure(
                code: "text.invalid-extracted-utf8",
                category: .invariantViolation,
                operation: .importText,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.text.invalid-extracted-utf8"
            )
        }
        return text
    }
}

private struct MarkdownExtractionParser {
    private struct Fence {
        let marker: UInt8
        let length: Int
    }

    let bytes: [UInt8]
    let sourceByteOffset: Int
    var builder: MarkdownSpanBuilder
    private var fence: Fence?
    var isInsideHTMLComment = false
    var remainingLookaheadSteps: Int

    init(bytes: [UInt8], sourceByteOffset: Int) {
        self.bytes = bytes
        self.sourceByteOffset = sourceByteOffset
        builder = MarkdownSpanBuilder(bytes: bytes, sourceByteOffset: sourceByteOffset)
        let (scaledCount, overflow) = bytes.count.multipliedReportingOverflow(by: 4)
        remainingLookaheadSteps = overflow ? Int.max : scaledCount + 1_024
    }

    mutating func extract() throws -> (output: Data, segments: [GlifiSpanMapSegment]) {
        var lineStart = 0
        while lineStart < bytes.count {
            try Task.checkCancellation()
            let lineEnd = try nextLineEnd(after: lineStart)
            let contentEnd = lineContentEnd(start: lineStart, lineEnd: lineEnd)
            try processLine(start: lineStart, end: contentEnd)
            try builder.appendExact(contentEnd..<lineEnd)
            lineStart = lineEnd
        }
        return (builder.output, builder.segments)
    }

    private mutating func processLine(start: Int, end: Int) throws {
        if let fence {
            if isFence(at: start, end: end, matching: fence) {
                self.fence = nil
            } else {
                try builder.appendExact(start..<end)
            }
            return
        }

        if let openingFence = openingFence(at: start, end: end) {
            fence = openingFence
            return
        }
        let contentStart = blockContentStart(at: start, end: end)
        guard contentStart < end else { return }
        if isThematicBreak(start: contentStart, end: end)
            || isTableDelimiter(start: contentStart, end: end)
        {
            return
        }
        if try isLinkDefinition(start: contentStart, end: end) {
            return
        }
        try processInline(start: contentStart, end: end, depth: 0)
    }

    private mutating func processInline(start: Int, end: Int, depth: Int) throws {
        guard depth <= 32 else {
            throw markdownFailure(
                "text.markdown-depth-limit-exceeded", category: .insufficientResources)
        }
        var index = start
        while index < end {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }

            if isInsideHTMLComment {
                if let closing = try findSequence([45, 45, 62], from: index, end: end) {
                    index = closing + 3
                    isInsideHTMLComment = false
                } else {
                    return
                }
                continue
            }
            if hasSequence([60, 33, 45, 45], at: index, end: end) {
                if let closing = try findSequence(
                    [45, 45, 62],
                    from: index + 4,
                    end: end
                ) {
                    index = closing + 3
                } else {
                    isInsideHTMLComment = true
                    return
                }
                continue
            }
            if bytes[index] == 92,
                index + 1 < end,
                isEscapable(bytes[index + 1])
            {
                try builder.appendExact((index + 1)..<(index + 2))
                index += 2
                continue
            }
            if bytes[index] == 96 {
                let runLength = markerRun(at: index, marker: 96, end: end)
                if let closing = try findMarkerRun(
                    marker: 96,
                    length: runLength,
                    from: index + runLength,
                    end: end
                ) {
                    try builder.appendExact((index + runLength)..<closing)
                    index = closing + runLength
                    continue
                }
            }
            if bytes[index] == 91
                || (bytes[index] == 33 && index + 1 < end && bytes[index + 1] == 91),
                let link = try link(at: index, end: end)
            {
                try processInline(start: link.labelStart, end: link.labelEnd, depth: depth + 1)
                index = link.end
                continue
            }
            if bytes[index] == 60,
                let construct = try angleConstruct(at: index, end: end)
            {
                if let visibleRange = construct.visibleRange {
                    try builder.appendExact(visibleRange)
                }
                index = construct.end
                continue
            }
            if bytes[index] == 38, let entity = decodedEntity(at: index, end: end) {
                try builder.appendDerived(entity.value, from: index..<entity.end)
                index = entity.end
                continue
            }
            if let delimiter = emphasisDelimiter(at: index, end: end),
                let closing = try findMarkerRun(
                    marker: delimiter.marker,
                    length: delimiter.length,
                    from: index + delimiter.length,
                    end: end
                )
            {
                try processInline(
                    start: index + delimiter.length,
                    end: closing,
                    depth: depth + 1
                )
                index = closing + delimiter.length
                continue
            }

            try builder.appendExact(index..<(index + 1))
            index += 1
        }
    }

    private mutating func nextLineEnd(after start: Int) throws -> Int {
        var index = start
        while index < bytes.count, bytes[index] != 10, bytes[index] != 13 {
            if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
            index += 1
        }
        if index < bytes.count, bytes[index] == 13 {
            index += 1
            if index < bytes.count, bytes[index] == 10 { index += 1 }
        } else if index < bytes.count {
            index += 1
        }
        return index
    }

    private func lineContentEnd(start: Int, lineEnd: Int) -> Int {
        guard lineEnd > start else { return lineEnd }
        if bytes[lineEnd - 1] == 10 {
            return lineEnd >= start + 2 && bytes[lineEnd - 2] == 13 ? lineEnd - 2 : lineEnd - 1
        }
        return bytes[lineEnd - 1] == 13 ? lineEnd - 1 : lineEnd
    }

    private func blockContentStart(at start: Int, end: Int) -> Int {
        var index = start
        var didStrip = false

        while true {
            let candidate = skippingUpToThreeSpaces(from: index, end: end)
            if candidate < end, bytes[candidate] == 62 {
                index = candidate + 1
                if index < end, isHorizontalWhitespace(bytes[index]) { index += 1 }
                didStrip = true
                continue
            }
            index = didStrip ? candidate : index
            break
        }

        let candidate = skippingUpToThreeSpaces(from: index, end: end)
        var hashes = candidate
        while hashes < end, bytes[hashes] == 35, hashes - candidate < 6 {
            hashes += 1
        }
        if hashes > candidate,
            hashes < end,
            isHorizontalWhitespace(bytes[hashes])
        {
            index = hashes + 1
            didStrip = true
        }

        let listCandidate = skippingUpToThreeSpaces(from: index, end: end)
        if listCandidate + 1 < end,
            [UInt8(42), 43, 45].contains(bytes[listCandidate]),
            isHorizontalWhitespace(bytes[listCandidate + 1])
        {
            index = listCandidate + 2
            didStrip = true
        } else {
            var cursor = listCandidate
            while cursor < end, isASCIIDigit(bytes[cursor]), cursor - listCandidate < 9 {
                cursor += 1
            }
            if cursor > listCandidate,
                cursor + 1 < end,
                bytes[cursor] == 46 || bytes[cursor] == 41,
                isHorizontalWhitespace(bytes[cursor + 1])
            {
                index = cursor + 2
                didStrip = true
            }
        }

        if didStrip,
            index + 2 < end,
            bytes[index] == 91,
            bytes[index + 2] == 93,
            [UInt8(32), 88, 120].contains(bytes[index + 1])
        {
            index += 3
            if index < end, isHorizontalWhitespace(bytes[index]) { index += 1 }
        }
        return didStrip ? index : start
    }

    private func openingFence(at start: Int, end: Int) -> Fence? {
        let index = skippingUpToThreeSpaces(from: start, end: end)
        guard index < end, bytes[index] == 96 || bytes[index] == 126 else { return nil }
        let count = markerRun(at: index, marker: bytes[index], end: end)
        return count >= 3 ? Fence(marker: bytes[index], length: count) : nil
    }

    private func isFence(at start: Int, end: Int, matching fence: Fence) -> Bool {
        let index = skippingUpToThreeSpaces(from: start, end: end)
        guard markerRun(at: index, marker: fence.marker, end: end) >= fence.length else {
            return false
        }
        var cursor = index
        while cursor < end, bytes[cursor] == fence.marker { cursor += 1 }
        return bytes[cursor..<end].allSatisfy(isHorizontalWhitespace)
    }

    private func isThematicBreak(start: Int, end: Int) -> Bool {
        var marker: UInt8?
        var count = 0
        for byte in bytes[start..<end] where !isHorizontalWhitespace(byte) {
            guard [UInt8(42), 45, 95].contains(byte) else { return false }
            if let marker, marker != byte { return false }
            marker = byte
            count += 1
        }
        return count >= 3
    }

    private func isTableDelimiter(start: Int, end: Int) -> Bool {
        var hyphens = 0
        var hasPipe = false
        for byte in bytes[start..<end] where !isHorizontalWhitespace(byte) {
            switch byte {
            case 45: hyphens += 1
            case 124: hasPipe = true
            case 58: continue
            default: return false
            }
        }
        return hasPipe && hyphens >= 3
    }

    private mutating func isLinkDefinition(start: Int, end: Int) throws -> Bool {
        guard start < end, bytes[start] == 91,
            let closing = try findUnescaped(93, from: start + 1, end: end)
        else {
            return false
        }
        return closing + 1 < end && bytes[closing + 1] == 58
    }

    private mutating func link(
        at start: Int,
        end: Int
    ) throws -> (labelStart: Int, labelEnd: Int, end: Int)? {
        let bracket = bytes[start] == 33 ? start + 1 : start
        guard bracket < end, bytes[bracket] == 91,
            let labelEnd = try findUnescaped(93, from: bracket + 1, end: end)
        else {
            return nil
        }
        let suffix = labelEnd + 1
        if suffix < end, bytes[suffix] == 40,
            let closing = try findBalancedParenthesis(from: suffix, end: end)
        {
            return (bracket + 1, labelEnd, closing + 1)
        }
        if suffix < end, bytes[suffix] == 91,
            let closing = try findUnescaped(93, from: suffix + 1, end: end)
        {
            return (bracket + 1, labelEnd, closing + 1)
        }
        return nil
    }

    private mutating func angleConstruct(
        at start: Int,
        end: Int
    ) throws -> (visibleRange: Range<Int>?, end: Int)? {
        guard let closing = try findUnescaped(62, from: start + 1, end: end) else { return nil }
        let inner = (start + 1)..<closing
        guard !inner.isEmpty else { return nil }
        let value = String(decoding: bytes[inner], as: UTF8.self)
        if value.hasPrefix("http://") || value.hasPrefix("https://") || value.contains("@") {
            let visibleStart = value.hasPrefix("mailto:") ? start + 8 : start + 1
            return (visibleStart..<closing, closing + 1)
        }
        let first = bytes[inner.lowerBound]
        if first == 47 || first == 33 || first == 63 || isASCIIAlpha(first) {
            return (nil, closing + 1)
        }
        return nil
    }

    private func decodedEntity(at start: Int, end: Int) -> (value: String, end: Int)? {
        let limit = min(end, start + 16)
        guard let semicolon = bytes[(start + 1)..<limit].firstIndex(of: 59) else { return nil }
        let body = String(decoding: bytes[(start + 1)..<semicolon], as: UTF8.self)
        let value: String?
        switch body {
        case "amp": value = "&"
        case "lt": value = "<"
        case "gt": value = ">"
        case "quot": value = "\""
        case "apos", "#39": value = "'"
        default:
            if body.hasPrefix("#x") || body.hasPrefix("#X") {
                value = unicodeEntity(String(body.dropFirst(2)), radix: 16)
            } else if body.hasPrefix("#") {
                value = unicodeEntity(String(body.dropFirst()), radix: 10)
            } else {
                value = nil
            }
        }
        return value.map { ($0, semicolon + 1) }
    }

    private func unicodeEntity(_ digits: String, radix: Int) -> String? {
        guard !digits.isEmpty,
            let value = UInt32(digits, radix: radix),
            value != 0,
            !(0xD800...0xDFFF).contains(value),
            let scalar = UnicodeScalar(value)
        else {
            return nil
        }
        return String(scalar)
    }

    private func emphasisDelimiter(at start: Int, end: Int) -> (marker: UInt8, length: Int)? {
        let marker = bytes[start]
        guard marker == 42 || marker == 95 || marker == 126 else { return nil }
        let run = markerRun(at: start, marker: marker, end: end)
        let length = marker == 126 ? 2 : min(run, 3)
        guard run >= length,
            start + length < end,
            !isHorizontalWhitespace(bytes[start + length])
        else {
            return nil
        }
        if marker == 95,
            start > 0,
            start + length < bytes.count,
            isASCIIAlphanumeric(bytes[start - 1]),
            isASCIIAlphanumeric(bytes[start + length])
        {
            return nil
        }
        return (marker, length)
    }

    private mutating func findBalancedParenthesis(from opening: Int, end: Int) throws -> Int? {
        var index = opening + 1
        var depth = 1
        while index < end {
            try consumeLookaheadStep()
            if bytes[index] == 92 {
                index = min(index + 2, end)
                continue
            }
            if bytes[index] == 40 { depth += 1 }
            if bytes[index] == 41 {
                depth -= 1
                if depth == 0 { return index }
            }
            index += 1
        }
        return nil
    }

    private mutating func findMarkerRun(
        marker: UInt8,
        length: Int,
        from start: Int,
        end: Int
    ) throws -> Int? {
        var index = start
        while index + length <= end {
            try consumeLookaheadStep()
            if bytes[index] == 92 {
                index += 2
                continue
            }
            if bytes[index] == marker,
                markerRun(at: index, marker: marker, end: end) >= length
            {
                return index
            }
            index += 1
        }
        return nil
    }

    private mutating func findUnescaped(_ byte: UInt8, from start: Int, end: Int) throws -> Int? {
        var index = start
        while index < end {
            try consumeLookaheadStep()
            if bytes[index] == 92 {
                index += 2
                continue
            }
            if bytes[index] == byte { return index }
            index += 1
        }
        return nil
    }

    private mutating func findSequence(
        _ sequence: [UInt8],
        from start: Int,
        end: Int
    ) throws -> Int? {
        var index = start
        while index + sequence.count <= end {
            try consumeLookaheadStep()
            if hasSequence(sequence, at: index, end: end) { return index }
            index += 1
        }
        return nil
    }

    private func hasSequence(_ sequence: [UInt8], at start: Int, end: Int) -> Bool {
        guard start >= 0, start + sequence.count <= end else { return false }
        return bytes[start..<(start + sequence.count)].elementsEqual(sequence)
    }

    private func markerRun(at start: Int, marker: UInt8, end: Int) -> Int {
        guard start < end else { return 0 }
        var index = start
        while index < end, bytes[index] == marker { index += 1 }
        return index - start
    }

    private func skippingUpToThreeSpaces(from start: Int, end: Int) -> Int {
        var index = start
        while index < end, index - start < 3, bytes[index] == 32 { index += 1 }
        return index
    }

    private func isEscapable(_ byte: UInt8) -> Bool {
        byte >= 33 && byte <= 126 && !isASCIIAlphanumeric(byte)
    }

    private func isHorizontalWhitespace(_ byte: UInt8) -> Bool {
        byte == 32 || byte == 9
    }

    private func isASCIIAlpha(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte)
    }

    private func isASCIIDigit(_ byte: UInt8) -> Bool {
        (48...57).contains(byte)
    }

    private func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        isASCIIAlpha(byte) || isASCIIDigit(byte)
    }

    private mutating func consumeLookaheadStep() throws {
        guard remainingLookaheadSteps > 0 else {
            throw markdownFailure(
                "text.markdown-complexity-limit-exceeded",
                category: .insufficientResources
            )
        }
        remainingLookaheadSteps -= 1
        if remainingLookaheadSteps.isMultiple(of: 4_096) {
            try Task.checkCancellation()
        }
    }
}

private struct MarkdownSpanBuilder {
    let bytes: [UInt8]
    let sourceByteOffset: Int
    var output = Data()
    var segments: [GlifiSpanMapSegment] = []

    mutating func appendExact(_ range: Range<Int>) throws {
        guard !range.isEmpty else { return }
        let outputStart = output.count
        output.append(contentsOf: bytes[range])
        let outputRange = try GlifiUTF8Range(start: outputStart, end: output.count)
        let inputRange = try GlifiUTF8Range(
            start: sourceByteOffset + range.lowerBound,
            end: sourceByteOffset + range.upperBound
        )
        if let previous = segments.last,
            previous.kind == .exact,
            previous.outputRange.end == outputRange.start,
            previous.inputRanges.count == 1,
            previous.inputRanges[0].end == inputRange.start
        {
            segments[segments.count - 1] = GlifiSpanMapSegment(
                outputRange: try GlifiUTF8Range(
                    start: previous.outputRange.start,
                    end: outputRange.end
                ),
                inputRanges: [
                    try GlifiUTF8Range(
                        start: previous.inputRanges[0].start,
                        end: inputRange.end
                    )
                ],
                kind: .exact
            )
        } else {
            segments.append(
                GlifiSpanMapSegment(
                    outputRange: outputRange,
                    inputRanges: [inputRange],
                    kind: .exact
                )
            )
        }
    }

    mutating func appendDerived(_ value: String, from range: Range<Int>) throws {
        guard !value.isEmpty, !range.isEmpty else { return }
        let outputStart = output.count
        output.append(contentsOf: value.utf8)
        segments.append(
            GlifiSpanMapSegment(
                outputRange: try GlifiUTF8Range(start: outputStart, end: output.count),
                inputRanges: [
                    try GlifiUTF8Range(
                        start: sourceByteOffset + range.lowerBound,
                        end: sourceByteOffset + range.upperBound
                    )
                ],
                kind: .derivational
            )
        )
    }
}

private func markdownFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .importText,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.\(code)"
    )
}
