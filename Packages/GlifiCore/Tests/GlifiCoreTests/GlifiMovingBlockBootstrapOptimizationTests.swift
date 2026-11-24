// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("Moving-block conserva tutti i bit del ciclo precedente e l'identità i.i.d.")
func movingBlockBoundedLoopMatchesLegacyBits() throws {
    let seeds: [UInt64] = [0, 0x172173, .max]
    for count in [2, 3, 7, 16, 31] {
        let sequence = (0..<count).map { index in
            Double((index * 37) % 113 - 56) / 10 + Double(index % 7) / 64
        }
        let blockLengths = Set([1, count / 2, count - 1, count]).sorted()
        for blockLength in blockLengths {
            for resampleCount in [1, 2, 17, 127] {
                for seed in seeds {
                    for confidenceLevel in [0.5, 0.95, 0.999] {
                        let actual =
                            try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                                sequence, blockLength: blockLength,
                                confidenceLevel: confidenceLevel,
                                resampleCount: resampleCount, seed: seed)
                        let expected = movingBlockLegacyReference(
                            sequence, blockLength: blockLength, confidenceLevel: confidenceLevel,
                            resampleCount: resampleCount, seed: seed)
                        expectMovingBlockBits(actual, expected)
                        if blockLength == 1 {
                            let independent = try GlifiStatisticalFoundation.bootstrapMeanInterval(
                                sequence, confidenceLevel: confidenceLevel,
                                resampleCount: resampleCount, seed: seed)
                            expectMovingBlockBits(actual, independent)
                        }
                    }
                }
            }
        }
    }
}

@Test("Moving-block preserva i bit con coda minima e blocchi quasi grandi quanto n")
func movingBlockBoundedLoopPreservesLongTailBits() throws {
    let sequence: [Double] = (0..<4_096).map { index -> Double in
        let integer = (index * 37) % 8_192 - 4_096
        let base = Double(integer) / 64.0
        let fraction = Double(index % 11) / 256.0
        return base + fraction
    }
    for blockLength in [1, 257, 4_095, 4_096] {
        let actual = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
            sequence, blockLength: blockLength, resampleCount: 17, seed: 0x172173)
        let expected = movingBlockLegacyReference(
            sequence, blockLength: blockLength, confidenceLevel: 0.95,
            resampleCount: 17, seed: 0x172173)
        expectMovingBlockBits(actual, expected)
    }
}

@Test("La delega L=1 conserva metadati e bit anche con zeri con segno e valori subnormali")
func movingBlockSingletonDelegationPreservesAllBits() throws {
    let tiny = Double.leastNonzeroMagnitude
    let fixtures: [[Double]] = [
        [0, -0.0, 0, -0.0],
        [-tiny, 0, tiny, -tiny, tiny],
        [.leastNormalMagnitude, -.leastNormalMagnitude, tiny, -tiny, 0],
        [1e15, -1e15, 1, -1, 0],
    ]
    let seeds: [UInt64] = [0, .max]
    for sequence in fixtures {
        for resampleCount in [1, 17, 513] {
            for seed in seeds {
                for confidenceLevel in [0.5, 0.95] {
                    let actual = try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                        sequence, blockLength: 1, confidenceLevel: confidenceLevel,
                        resampleCount: resampleCount, seed: seed)
                    let expected = movingBlockLegacyReference(
                        sequence, blockLength: 1, confidenceLevel: confidenceLevel,
                        resampleCount: resampleCount, seed: seed)
                    let independent = try GlifiStatisticalFoundation.bootstrapMeanInterval(
                        sequence, confidenceLevel: confidenceLevel,
                        resampleCount: resampleCount, seed: seed)
                    expectMovingBlockBits(actual, expected)
                    expectMovingBlockBits(actual, independent)
                }
            }
        }
    }
}

@Test("Moving-block conserva il rifiuto degli input invalidi e la cancellazione")
func movingBlockBoundedLoopPreservesFailures() async {
    for blockLength in [0, 4] {
        #expect(throws: GlifiFailure.self) {
            try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                [1, 2, 3], blockLength: blockLength, seed: 0)
        }
    }
    #expect(throws: GlifiFailure.self) {
        try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
            [1, .infinity], blockLength: 1, seed: 0)
    }
    for blockLength in [1, 2, 3] {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                [1, 2, 3], blockLength: blockLength, resampleCount: 17, seed: 0)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
    let invalidCases: [([Double], Double, Int, String)] = [
        ([1], 1, 0, "statistics.invalid-block-length"),
        ([1, .infinity], 1, 0, "statistics.non-finite-value"),
        ([1, 2], 1, 0, "statistics.invalid-resampling-parameters"),
    ]
    for (sequence, confidenceLevel, resampleCount, code) in invalidCases {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                sequence, blockLength: 1, confidenceLevel: confidenceLevel,
                resampleCount: resampleCount, seed: 0)
        }
        do {
            _ = try await task.value
            Issue.record("Expected the original MBB validation failure before cancellation")
        } catch let failure as GlifiFailure {
            #expect(failure.code == code)
        } catch {
            Issue.record("Expected an MBB validation failure, received \(error)")
        }
    }
}

private func expectMovingBlockBits(
    _ actual: GlifiBootstrapInterval, _ expected: GlifiBootstrapInterval
) {
    #expect(actual.estimate.bitPattern == expected.estimate.bitPattern)
    #expect(actual.confidenceLevel.bitPattern == expected.confidenceLevel.bitPattern)
    #expect(actual.lower.bitPattern == expected.lower.bitPattern)
    #expect(actual.upper.bitPattern == expected.upper.bitPattern)
    #expect(actual.resampleCount == expected.resampleCount)
    #expect(actual.generatorIdentifier == expected.generatorIdentifier)
    #expect(actual.seed == expected.seed)
}

/// The previous full-block traversal, with independent generator and quantile implementations.
private func movingBlockLegacyReference(
    _ sequence: [Double], blockLength: Int, confidenceLevel: Double,
    resampleCount: Int, seed: UInt64
) -> GlifiBootstrapInterval {
    var generator = MovingBlockReferenceGenerator(state: seed)
    var means: [Double] = []
    for _ in 0..<resampleCount {
        var total = 0.0
        var drawn = 0
        while drawn < sequence.count {
            let start = generator.index(below: sequence.count - blockLength + 1)
            for offset in 0..<blockLength where drawn < sequence.count {
                total += sequence[start + offset]
                drawn += 1
            }
        }
        means.append(total / Double(sequence.count))
    }
    means.sort()
    let tail = (1 - confidenceLevel) / 2
    func quantile(_ probability: Double) -> Double {
        let position = Double(means.count - 1) * probability
        let index = Int(position.rounded(.down))
        let next = min(index + 1, means.count - 1)
        return means[index] + (position - Double(index)) * (means[next] - means[index])
    }
    return GlifiBootstrapInterval(
        estimate: sequence.reduce(0, +) / Double(sequence.count),
        confidenceLevel: confidenceLevel, lower: quantile(tail), upper: quantile(1 - tail),
        resampleCount: resampleCount, generatorIdentifier: "SplitMix64-v1", seed: seed)
}

private struct MovingBlockReferenceGenerator {
    var state: UInt64

    mutating func index(below bound: Int) -> Int {
        let width = UInt64(bound)
        let threshold = (0 &- width) % width
        while true {
            state &+= 0x9E37_79B9_7F4A_7C15
            var bits = state
            bits = (bits ^ (bits >> 30)) &* 0xBF58_476D_1CE4_E5B9
            bits = (bits ^ (bits >> 27)) &* 0x94D0_49BB_1331_11EB
            bits ^= bits >> 31
            if bits >= threshold { return Int(bits % width) }
        }
    }
}
