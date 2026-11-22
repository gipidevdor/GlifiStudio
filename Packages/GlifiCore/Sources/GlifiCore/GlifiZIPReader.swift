// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import zlib

/// A bounded, non-extracting ZIP reader for the EPUB OCF stored/DEFLATE profile.
struct GlifiZIPReader {
    struct Entry {
        let path: String
        let method: UInt16
        let flags: UInt16
        let crc: UInt32
        let expandedCount: Int
        let payload: Range<Int>
        let record: Range<Int>
        let localExtraCount: Int
        let isDirectory: Bool
    }

    let entries: [Entry]
    private let data: Data
    private let positions: [String: Int]
    private var remainingExpandedBytes: Int

    init(_ data: Data, limits: GlifiTextImportLimits) throws {
        try Task.checkCancellation()
        guard data.count <= limits.maximumByteCount else { throw zipLimit() }
        let parsed = try Self.directory(data, limits: limits)
        entries = parsed
        positions = Dictionary(
            uniqueKeysWithValues: parsed.enumerated().map { ($0.element.path, $0.offset) })
        self.data = data
        remainingExpandedBytes = limits.maximumExpandedArchiveByteCount
    }

    func entry(_ path: String) -> Entry? {
        guard let index = positions[path], entries[index].path.utf8.elementsEqual(path.utf8) else {
            return nil
        }
        return entries[index]
    }

    /// Charges repeated reads as work as well; no cache can bypass the expansion budget.
    mutating func read(_ path: String) throws -> Data {
        try Task.checkCancellation()
        guard let entry = entry(path), !entry.isDirectory else { throw zipInvalid() }
        guard entry.expandedCount <= remainingExpandedBytes else { throw zipLimit() }
        remainingExpandedBytes -= entry.expandedCount
        return try Self.payload(entry, in: data)
    }

    private static func directory(_ data: Data, limits: GlifiTextImportLimits) throws -> [Entry] {
        guard data.count >= 22 else { throw zipInvalid() }
        let earliest = max(0, data.count - 65_557)
        var end: Int?
        for offset in stride(from: data.count - 22, through: earliest, by: -1) {
            if offset.isMultiple(of: 4_096) { try Task.checkCancellation() }
            if try zip32(data, offset) == 0x0605_4B50,
                offset + 22 + Int(try zip16(data, offset + 20)) == data.count
            {
                end = offset
                break
            }
        }
        guard let end else { throw zipInvalid() }
        let disk = try zip16(data, end + 4)
        let directoryDisk = try zip16(data, end + 6)
        let diskEntries = try zip16(data, end + 8)
        let count = try zip16(data, end + 10)
        let centralSize = try zip32(data, end + 12)
        let centralOffset = try zip32(data, end + 16)
        guard disk == 0, directoryDisk == 0, diskEntries == count else {
            throw zipUnsupported()
        }
        guard count != .max, centralSize != .max, centralOffset != .max else {
            throw zipUnsupported()
        }
        guard count > 0, Int(count) <= limits.maximumArchiveEntryCount else { throw zipLimit() }
        let start = Int(centralOffset)
        guard start <= end, Int(centralSize) == end - start else { throw zipInvalid() }
        var cursor = start
        var expanded = 0
        var aliases = Set<String>()
        var result: [Entry] = []
        result.reserveCapacity(Int(count))
        for _ in 0..<count {
            try Task.checkCancellation()
            guard cursor <= end - 46, try zip32(data, cursor) == 0x0201_4B50 else {
                throw zipInvalid()
            }
            let needed = try zip16(data, cursor + 6)
            let flags = try zip16(data, cursor + 8)
            let method = try zip16(data, cursor + 10)
            let crc = try zip32(data, cursor + 16)
            let compressed = try zip32(data, cursor + 20)
            let uncompressed = try zip32(data, cursor + 24)
            let nameCount = Int(try zip16(data, cursor + 28))
            let extraCount = Int(try zip16(data, cursor + 30))
            let commentCount = Int(try zip16(data, cursor + 32))
            let entryDisk = try zip16(data, cursor + 34)
            let attributes = try zip32(data, cursor + 38)
            let localOffset = try zip32(data, cursor + 42)
            guard compressed != .max, uncompressed != .max, localOffset != .max, entryDisk == 0
            else {
                throw zipUnsupported()
            }
            guard flags & 0x2041 == 0 else { throw zipUnsupported() }
            guard needed <= 20, flags & ~UInt16(0x080E) == 0, method == 0 || method == 8,
                method != 0 || flags & 6 == 0
            else { throw zipUnsupported() }
            let recordEnd = cursor + 46 + nameCount + extraCount + commentCount
            guard nameCount > 0, recordEnd <= end else { throw zipInvalid() }
            let name = zipSlice(data, (cursor + 46)..<(cursor + 46 + nameCount))
            guard let path = String(validating: name, as: UTF8.self) else { throw zipInvalid() }
            try zipPath(path)
            let alias = path.precomposedStringWithCanonicalMapping.folding(
                options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            guard aliases.insert(alias).inserted else { throw zipInvalid() }
            try zipExtra(
                data, (cursor + 46 + nameCount)..<(cursor + 46 + nameCount + extraCount), name: name
            )
            let kind = (attributes >> 16) & 0xF000
            let directory = path.hasSuffix("/")
            guard kind == 0 || kind == 0x8000 || kind == 0x4000,
                !directory || (kind != 0x8000),
                directory || (kind != 0x4000 && attributes & 0x10 == 0)
            else { throw zipInvalid() }
            guard !directory || (compressed == 0 && uncompressed == 0 && method == 0 && crc == 0)
            else { throw zipInvalid() }
            guard Int(uncompressed) <= limits.maximumArchiveEntryByteCount,
                Int(uncompressed) <= limits.maximumExpandedArchiveByteCount - expanded
            else { throw zipLimit() }
            expanded += Int(uncompressed)
            let local = Int(localOffset)
            guard local <= start - 30, try zip32(data, local) == 0x0403_4B50,
                try zip16(data, local + 4) == needed,
                try zip16(data, local + 6) == flags,
                try zip16(data, local + 8) == method,
                try zip32(data, local + 10) == zip32(data, cursor + 12)
            else { throw zipInvalid() }
            let localNameCount = Int(try zip16(data, local + 26))
            let localExtraCount = Int(try zip16(data, local + 28))
            let payloadStart = local + 30 + localNameCount + localExtraCount
            guard localNameCount == nameCount, payloadStart <= start,
                zipSlice(data, (local + 30)..<(local + 30 + localNameCount)) == name,
                Int(compressed) <= start - payloadStart
            else { throw zipInvalid() }
            try zipExtra(data, (local + 30 + localNameCount)..<payloadStart, name: name)
            let localCRC = try zip32(data, local + 14)
            let localCompressed = try zip32(data, local + 18)
            let localExpanded = try zip32(data, local + 22)
            let known =
                localCRC == crc && localCompressed == compressed && localExpanded == uncompressed
            let deferred = localCRC == 0 && localCompressed == 0 && localExpanded == 0
            let payloadEnd = payloadStart + Int(compressed)
            var localEnd = payloadEnd
            if flags & 8 != 0 {
                guard known || deferred else { throw zipInvalid() }
                localEnd = try zipDescriptor(
                    data, offset: payloadEnd, before: start, crc: crc,
                    compressed: compressed, expanded: uncompressed)
            } else {
                guard known else { throw zipInvalid() }
            }
            guard method != 0 || compressed == uncompressed else { throw zipInvalid() }
            result.append(
                Entry(
                    path: path, method: method, flags: flags, crc: crc,
                    expandedCount: Int(uncompressed), payload: payloadStart..<payloadEnd,
                    record: local..<localEnd, localExtraCount: localExtraCount,
                    isDirectory: directory))
            cursor = recordEnd
        }
        guard cursor == end else { throw zipInvalid() }
        let ranges = result.map(\.record).sorted { $0.lowerBound < $1.lowerBound }
        for index in 1..<ranges.count {
            guard ranges[index - 1].upperBound <= ranges[index].lowerBound else {
                throw zipInvalid()
            }
        }
        return result
    }

    private static func payload(_ entry: Entry, in data: Data) throws -> Data {
        var output = Data()
        output.reserveCapacity(entry.expandedCount)
        var checksum = crc32(0, nil, 0)
        if entry.method == 0 {
            var offset = entry.payload.lowerBound
            while offset < entry.payload.upperBound {
                try Task.checkCancellation()
                let end = min(entry.payload.upperBound, offset + 32_768)
                let chunk = zipSlice(data, offset..<end)
                checksum = chunk.withUnsafeBytes {
                    crc32(checksum, $0.bindMemory(to: Bytef.self).baseAddress, uInt(chunk.count))
                }
                output.append(chunk)
                offset = end
            }
        } else {
            guard entry.payload.count <= Int(uInt.max) else { throw zipLimit() }
            var stream = z_stream()
            let initialized = inflateInit2_(
                &stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            guard initialized == Z_OK else { throw zipLimit() }
            defer { inflateEnd(&stream) }
            try data.withUnsafeBytes { input in
                guard let base = input.bindMemory(to: Bytef.self).baseAddress else {
                    throw zipInvalid()
                }
                stream.next_in = UnsafeMutablePointer(
                    mutating: base.advanced(by: entry.payload.lowerBound))
                stream.avail_in = uInt(entry.payload.count)
                var buffer = [UInt8](repeating: 0, count: 32_768)
                while true {
                    try Task.checkCancellation()
                    let available = min(buffer.count, entry.expandedCount - output.count + 1)
                    let previousInput = stream.total_in
                    let status = buffer.withUnsafeMutableBufferPointer { target in
                        stream.next_out = target.baseAddress
                        stream.avail_out = uInt(available)
                        return inflate(&stream, Z_NO_FLUSH)
                    }
                    let produced = available - Int(stream.avail_out)
                    guard produced <= entry.expandedCount - output.count else { throw zipInvalid() }
                    if produced > 0 {
                        checksum = buffer.withUnsafeBufferPointer {
                            crc32(checksum, $0.baseAddress, uInt(produced))
                        }
                        output.append(contentsOf: buffer.prefix(produced))
                    }
                    if status == Z_STREAM_END {
                        guard stream.total_in == entry.payload.count,
                            output.count == entry.expandedCount
                        else {
                            throw zipInvalid()
                        }
                        break
                    }
                    if status == Z_MEM_ERROR { throw zipLimit() }
                    guard status == Z_OK, produced > 0 || stream.total_in > previousInput else {
                        throw zipInvalid()
                    }
                }
            }
        }
        guard output.count == entry.expandedCount, UInt32(truncatingIfNeeded: checksum) == entry.crc
        else { throw zipInvalid() }
        try Task.checkCancellation()
        return output
    }
}

private func zip16(_ data: Data, _ offset: Int) throws -> UInt16 {
    guard offset >= 0, data.count >= 2, offset <= data.count - 2 else { throw zipInvalid() }
    return UInt16(data[data.startIndex + offset]) | UInt16(data[data.startIndex + offset + 1]) << 8
}

private func zip32(_ data: Data, _ offset: Int) throws -> UInt32 {
    UInt32(try zip16(data, offset)) | UInt32(try zip16(data, offset + 2)) << 16
}

private func zipSlice(_ data: Data, _ range: Range<Int>) -> Data {
    data.subdata(in: (data.startIndex + range.lowerBound)..<(data.startIndex + range.upperBound))
}

private func zipPath(_ path: String) throws {
    guard !path.isEmpty, path.utf8.count <= 4_096, !path.hasPrefix("/"), !path.contains("\\"),
        !path.contains(":"),
        !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw zipInvalid() }
    var components = path.split(separator: "/", omittingEmptySubsequences: false)
    if path.hasSuffix("/") { components.removeLast() }
    guard !components.isEmpty, components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
    else { throw zipInvalid() }
}

private func zipExtra(_ data: Data, _ range: Range<Int>, name: Data) throws {
    var offset = range.lowerBound
    while offset < range.upperBound {
        guard offset <= range.upperBound - 4 else { throw zipInvalid() }
        let tag = try zip16(data, offset)
        let count = Int(try zip16(data, offset + 2))
        guard count <= range.upperBound - offset - 4 else { throw zipInvalid() }
        if tag == 1 || tag == 0x9901 { throw zipUnsupported() }
        if tag == 0x7075 {
            guard count >= 5, data[data.startIndex + offset + 4] == 1,
                zipSlice(data, (offset + 9)..<(offset + 4 + count)) == name
            else { throw zipUnsupported() }
            let checksum = name.withUnsafeBytes {
                crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(name.count))
            }
            guard UInt32(truncatingIfNeeded: checksum) == (try zip32(data, offset + 5)) else {
                throw zipInvalid()
            }
        }
        offset += 4 + count
    }
}

private func zipDescriptor(
    _ data: Data, offset: Int, before end: Int, crc: UInt32, compressed: UInt32, expanded: UInt32
) throws -> Int {
    for signatureCount in [4, 0] {
        let start = offset + signatureCount
        guard start <= end - 12 else { continue }
        if signatureCount == 4, try zip32(data, offset) != 0x0807_4B50 { continue }
        if try zip32(data, start) == crc, try zip32(data, start + 4) == compressed,
            try zip32(data, start + 8) == expanded
        {
            return start + 12
        }
    }
    throw zipInvalid()
}

private func zipInvalid() -> GlifiFailure { documentImportFailure("epub.invalid-zip") }
private func zipUnsupported() -> GlifiFailure {
    documentImportFailure("epub.unsupported-zip", category: .unsupportedFormat)
}
private func zipLimit() -> GlifiFailure {
    documentImportFailure("epub.archive-limit", category: .insufficientResources)
}
