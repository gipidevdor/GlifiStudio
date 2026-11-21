// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit

private let lowercaseHexadecimalDigits = Array("0123456789abcdef".utf8)

func isCanonicalSHA256Digest(_ value: String) -> Bool {
    let bytes = value.utf8
    guard bytes.count == 71, bytes.starts(with: "sha256:".utf8) else { return false }
    return bytes.dropFirst(7).allSatisfy { byte in
        (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102)
    }
}

func canonicalSHA256Digest(_ digest: SHA256.Digest) -> String {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(71)
    bytes.append(contentsOf: "sha256:".utf8)
    for byte in digest {
        bytes.append(lowercaseHexadecimalDigits[Int(byte >> 4)])
        bytes.append(lowercaseHexadecimalDigits[Int(byte & 15)])
    }
    return String(decoding: bytes, as: UTF8.self)
}
