// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import Testing

@testable import GlifiCore

@Test("La codifica SHA-256 conserva i vettori noti e tutti i valori di byte del formatter")
func canonicalDigestEncodingPreservesSHA256Bytes() {
    let vectors: [(Data, String)] = [
        (Data(), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        (Data("abc".utf8), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
    ]
    for (input, hexadecimal) in vectors {
        #expect(canonicalSHA256Digest(SHA256.hash(data: input)) == "sha256:\(hexadecimal)")
    }
    var coveredBytes = Set<UInt8>()
    for byte in UInt8.min...UInt8.max {
        let digest = SHA256.hash(data: Data(repeating: byte, count: 257))
        coveredBytes.formUnion(digest)
        let expected = "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
        let actual = canonicalSHA256Digest(digest)
        #expect(actual == expected)
        #expect(actual.utf8.count == 71)
        #expect(isCanonicalSHA256Digest(actual))
    }
    #expect(coveredBytes == Set(UInt8.min...UInt8.max))
}

@Test("Il validatore UTF-8 accetta esattamente il linguaggio del controllo Character originale")
func canonicalDigestValidationPreservesASCIILanguage() throws {
    let suffix = String(repeating: "a", count: 64)
    var values = [
        "", "sha256:", "SHA256:" + suffix, "sha256：" + suffix, "sha256:" + suffix,
        "sha256:" + String(repeating: "0123456789abcdef", count: 4),
        "sha256:" + String(repeating: "a", count: 63), "sha256:" + suffix + "a",
        "sha256:" + String(repeating: "a\u{0301}", count: 64),
        "sha256:" + String(repeating: "a", count: 16_384),
    ]
    for position in [0, 31, 63] {
        for number in 0..<128 {
            let scalar = try #require(UnicodeScalar(number))
            values.append(
                "sha256:" + String(repeating: "a", count: position) + String(scalar)
                    + String(repeating: "a", count: 63 - position))
        }
        for symbol in ["ａ", "𝒂", "a\u{0301}", "😀", "\u{200B}", "\u{FEFF}", "\r\n"] {
            values.append(
                "sha256:" + String(repeating: "a", count: position) + symbol
                    + String(repeating: "a", count: 63 - position))
        }
    }
    for value in values {
        let expected =
            value.hasPrefix("sha256:") && value.count == 71
            && value.dropFirst(7).allSatisfy { "0123456789abcdef".contains($0) }
        #expect(isCanonicalSHA256Digest(value) == expected)
        #expect(isCanonicalSHA256Digest(NSString(string: value) as String) == expected)
    }
}
