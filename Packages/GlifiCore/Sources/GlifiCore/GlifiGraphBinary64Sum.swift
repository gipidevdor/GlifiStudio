// SPDX-License-Identifier: BSD-3-Clause

/// Exact nonnegative sums of represented binary64 values, on the grid 2^-1074.
///
/// A fixed 2,176-bit unsigned expansion covers every finite binary64 value and
/// the sum of at most Int.max such values. Arrays have a fixed bound and use COW;
/// graph admission accounts for all live accumulators and their heap snapshots.
struct GlifiGraphBinary64Sum: Comparable, Sendable {
    static let wordCount = 34
    private var words = [UInt64](repeating: 0, count: GlifiGraphBinary64Sum.wordCount)

    init() {}

    init(_ value: Double) throws {
        try add(value)
    }

    func adding(_ value: Double) throws -> Self {
        var result = self
        try result.add(value)
        return result
    }

    func adding(_ other: Self) throws -> Self {
        var result = self
        for index in 0..<Self.wordCount {
            try result.addWord(other.words[index], at: index)
        }
        return result
    }

    private mutating func add(_ value: Double) throws {
        guard value.isFinite, value >= 0 else {
            throw graphAlgorithmFailure("network.numeric-range")
        }
        if value == 0 { return }
        let bits = value.bitPattern
        let rawExponent = Int((bits >> 52) & 0x7ff)
        let fraction = bits & 0x000f_ffff_ffff_ffff
        let significand = rawExponent == 0 ? fraction : fraction | (UInt64(1) << 52)
        // Subnormals already use the 2^-1074 grid; normal exponent one has the
        // same significand offset. No floating arithmetic participates in packing.
        let shift = rawExponent == 0 ? 0 : rawExponent - 1
        let word = shift / 64
        let offset = shift % 64
        try addWord(significand << offset, at: word)
        if offset > 11 { try addWord(significand >> (64 - offset), at: word + 1) }
    }

    private mutating func addWord(_ value: UInt64, at start: Int) throws {
        if value == 0 { return }
        var index = start
        var carry = value
        while carry != 0 {
            guard index < Self.wordCount else {
                throw graphAlgorithmFailure("network.numeric-range")
            }
            let (sum, overflow) = words[index].addingReportingOverflow(carry)
            words[index] = sum
            carry = overflow ? 1 : 0
            index += 1
        }
    }

    static func == (left: Self, right: Self) -> Bool {
        left.words == right.words
    }

    static func < (left: Self, right: Self) -> Bool {
        for index in (0..<Self.wordCount).reversed() where left.words[index] != right.words[index] {
            return left.words[index] < right.words[index]
        }
        return false
    }

    /// Rounds once, to nearest with ties to even; positive overflow becomes infinity.
    var rounded: Double {
        guard let word = words.lastIndex(where: { $0 != 0 }) else { return 0 }
        let leading = word * 64 + 63 - words[word].leadingZeroBitCount
        if leading < 52 { return Double(bitPattern: words[0]) }
        var exponent = leading - 1_074
        if exponent > 1_023 { return .infinity }
        let shift = leading - 52
        var significand = bitsStarting(at: shift) & 0x001f_ffff_ffff_ffff
        if shift > 0, bit(at: shift - 1),
            hasBits(below: shift - 1) || !significand.isMultiple(of: 2)
        {
            significand += 1
            if significand == UInt64(1) << 53 {
                significand >>= 1
                exponent += 1
                if exponent > 1_023 { return .infinity }
            }
        }
        return Double(
            bitPattern: (UInt64(exponent + 1_023) << 52)
                | (significand & 0x000f_ffff_ffff_ffff))
    }

    private func bitsStarting(at bit: Int) -> UInt64 {
        let index = bit / 64
        let offset = bit % 64
        var value = words[index] >> offset
        if offset != 0, index + 1 < Self.wordCount {
            value |= words[index + 1] << (64 - offset)
        }
        return value
    }

    private func bit(at bit: Int) -> Bool {
        words[bit / 64] & (UInt64(1) << (bit % 64)) != 0
    }

    private func hasBits(below bit: Int) -> Bool {
        let count = bit / 64
        if words.prefix(count).contains(where: { $0 != 0 }) { return true }
        let remainder = bit % 64
        return remainder != 0 && words[count] & ((UInt64(1) << remainder) - 1) != 0
    }
}
