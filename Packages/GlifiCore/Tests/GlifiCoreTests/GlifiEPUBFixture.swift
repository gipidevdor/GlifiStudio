// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing
import zlib

struct EPUBFixtureEntry {
    var path: String
    var bytes: Data
    var method: UInt16 = 0
    var flags: UInt16 = 0x0800
    var descriptor = false
    var attributes: UInt32 = 0o100644 << 16
    var crcOverride: UInt32?
    var expandedOverride: Int?
    var compressedOverride: Data?

    init(_ path: String, _ text: String, method: UInt16 = 0) {
        self.path = path
        bytes = Data(text.utf8)
        self.method = method
    }
}

struct EPUBFixtureZIP {
    var data: Data
    let locals: [Int]
    let payloads: [Int]
    let centrals: [Int]
    let centralStart: Int
}

func epubFixtureZIP(_ entries: [EPUBFixtureEntry], reversedDirectory: Bool = false) throws
    -> EPUBFixtureZIP
{
    var data = Data()
    var locals: [Int] = []
    var payloads: [Int] = []
    var records: [(EPUBFixtureEntry, Data, UInt32, UInt16, Int)] = []
    for entry in entries {
        let compressed =
            try entry.compressedOverride
            ?? (entry.method == 8 ? epubFixtureDeflate(entry.bytes) : entry.bytes)
        let crc = entry.crcOverride ?? epubFixtureCRC(entry.bytes)
        let flags = entry.flags | (entry.descriptor ? 8 : 0)
        let expanded = entry.expandedOverride ?? entry.bytes.count
        locals.append(data.count)
        data.epub32(0x0403_4B50)
        data.epub16(20)
        data.epub16(flags)
        data.epub16(entry.method)
        data.epub32(0)
        data.epub32(entry.descriptor ? 0 : crc)
        data.epub32(entry.descriptor ? 0 : UInt32(compressed.count))
        data.epub32(entry.descriptor ? 0 : UInt32(expanded))
        data.epub16(UInt16(entry.path.utf8.count))
        data.epub16(0)
        data.append(contentsOf: entry.path.utf8)
        payloads.append(data.count)
        data.append(compressed)
        if entry.descriptor {
            data.epub32(0x0807_4B50)
            data.epub32(crc)
            data.epub32(UInt32(compressed.count))
            data.epub32(UInt32(expanded))
        }
        records.append((entry, compressed, crc, flags, expanded))
    }
    let centralStart = data.count
    var centrals = [Int](repeating: 0, count: entries.count)
    let order = reversedDirectory ? Array(entries.indices.reversed()) : Array(entries.indices)
    for index in order {
        let (entry, compressed, crc, flags, expanded) = records[index]
        centrals[index] = data.count
        data.epub32(0x0201_4B50)
        data.epub16(0x0314)
        data.epub16(20)
        data.epub16(flags)
        data.epub16(entry.method)
        data.epub32(0)
        data.epub32(crc)
        data.epub32(UInt32(compressed.count))
        data.epub32(UInt32(expanded))
        data.epub16(UInt16(entry.path.utf8.count))
        data.epub16(0)
        data.epub16(0)
        data.epub16(0)
        data.epub16(0)
        data.epub32(entry.attributes)
        data.epub32(UInt32(locals[index]))
        data.append(contentsOf: entry.path.utf8)
    }
    let centralCount = data.count - centralStart
    data.epub32(0x0605_4B50)
    data.epub16(0)
    data.epub16(0)
    data.epub16(UInt16(entries.count))
    data.epub16(UInt16(entries.count))
    data.epub32(UInt32(centralCount))
    data.epub32(UInt32(centralStart))
    data.epub16(0)
    return EPUBFixtureZIP(
        data: data, locals: locals, payloads: payloads, centrals: centrals,
        centralStart: centralStart)
}

func epubFixtureBook(method: UInt16 = 0, version: String = "3.0") -> [EPUBFixtureEntry] {
    [
        EPUBFixtureEntry("mimetype", "application/epub+zip"),
        EPUBFixtureEntry(
            "META-INF/container.xml",
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
            """, method: method),
        EPUBFixtureEntry(
            "OEBPS/package.opf",
            """
            <package xmlns="http://www.idpf.org/2007/opf" version="\(version)"><metadata/><manifest><item id="a" href="text/a.xhtml" media-type="application/xhtml+xml"/><item id="b" href="text/b.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="b"/><itemref idref="a" linear="no"/></spine></package>
            """, method: method),
        EPUBFixtureEntry(
            "OEBPS/text/a.xhtml",
            """
            <html xmlns="http://www.w3.org/1999/xhtml"><head><title>Not body text</title><style>ignored</style></head><body><p>Primo é&nbsp; <strong>mondo</strong> &amp; &#x1F600;</p><script>ignored</script><p>Fine</p></body></html>
            """, method: method),
        EPUBFixtureEntry(
            "OEBPS/text/b.xhtml",
            """
            <html xmlns="http://www.w3.org/1999/xhtml"><body><h1>Secondo É</h1><p>Due</p></body></html>
            """, method: method),
    ]
}

private func epubFixtureDeflate(_ data: Data) throws -> Data {
    var stream = z_stream()
    let status = deflateInit2_(
        &stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8,
        Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard status == Z_OK else { throw NSError(domain: "EPUBFixture", code: Int(status)) }
    defer { deflateEnd(&stream) }
    var buffer = [UInt8](
        repeating: 0, count: max(64, Int(deflateBound(&stream, uLong(data.count)))))
    let produced = try data.withUnsafeBytes { input in
        stream.next_in = UnsafeMutablePointer(
            mutating: input.bindMemory(to: Bytef.self).baseAddress)
        stream.avail_in = uInt(data.count)
        return try buffer.withUnsafeMutableBufferPointer { target in
            stream.next_out = target.baseAddress
            stream.avail_out = uInt(target.count)
            let result = deflate(&stream, Z_FINISH)
            guard result == Z_STREAM_END else {
                throw NSError(domain: "EPUBFixture", code: Int(result))
            }
            return Int(stream.total_out)
        }
    }
    return Data(buffer.prefix(produced))
}

private func epubFixtureCRC(_ data: Data) -> UInt32 {
    var crc = UInt32.max
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 0 ? 0 : 0xEDB8_8320) }
    }
    return ~crc
}

extension Data {
    mutating func epub16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }
    mutating func epub32(_ value: UInt32) {
        epub16(UInt16(truncatingIfNeeded: value))
        epub16(UInt16(truncatingIfNeeded: value >> 16))
    }
    mutating func epubReplace32(_ offset: Int, _ value: UInt32) {
        for index in 0..<4 {
            self[startIndex + offset + index] = UInt8(truncatingIfNeeded: value >> (8 * index))
        }
    }
}
