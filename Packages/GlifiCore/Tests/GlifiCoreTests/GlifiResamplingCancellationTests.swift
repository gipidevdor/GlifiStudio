// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("Il resampling cancella dentro la prima replica e dentro un blocco lungo")
func resamplingCancellationStopsInsideFirstReplica() {
    let sample = Array(repeating: 1.25, count: 10_001)
    let lengths: [Int?] = [nil, 1, 9_000, 10_001]
    for length in lengths {
        var trace: [Int] = []
        #expect(throws: ResamplingCancellationProbeError.self) {
            _ = try cancellationInterval(sample, blockLength: length) { completed in
                trace.append(completed)
                if completed == 8_192 { throw ResamplingCancellationProbeError.stopped }
            }
        }
        #expect(trace == [0, 4_096, 8_192])
    }
}

@Test("Il budget di osservazioni è cumulativo fra repliche brevi e limita ogni intervallo")
func resamplingCancellationBoundsWorkAcrossReplicas() throws {
    let lengths: [Int?] = [nil, 1, 2, 3]
    for length in lengths {
        var trace: [Int] = []
        _ = try cancellationInterval([1, -2, 3], blockLength: length, resampleCount: 3_000) {
            trace.append($0)
        }
        #expect(trace.first == 0)
        #expect(trace.last == 9_000)
        #expect(trace.contains(4_096))
        #expect(trace.contains(8_192))
        #expect(zip(trace, trace.dropFirst()).allSatisfy { $1 >= $0 && $1 - $0 <= 4_096 })
    }
}

@Test("L'ordinamento mantiene checkpoint distinti prima e dopo senza cambiare il backend")
func resamplingCancellationChecksBothSortBoundaries() {
    let lengths: [Int?] = [nil, 1, 2]
    for length in lengths {
        for stopAt in [1, 2] {
            var finalChecks = 0
            #expect(throws: ResamplingCancellationProbeError.self) {
                _ = try cancellationInterval([1, 2, 3], blockLength: length) { completed in
                    if completed == 3 {
                        finalChecks += 1
                        if finalChecks == stopAt { throw ResamplingCancellationProbeError.stopped }
                    }
                }
            }
            #expect(finalChecks == stopAt)
        }
    }
}

@Test("Chunk e checkpoint conservano tutti i bit e metadati dei cicli originali")
func resamplingCancellationPreservesLegacyBitsAcrossChunks() throws {
    let sample: [Double] = (0..<10_001).map { index -> Double in
        let base = Double((index * 37) % 8_192 - 4_096) / 64.0
        let fraction = Double(index % 11) / 256.0
        return base + fraction
    }
    let lengths: [Int?] = [nil, 1, 4_097, 9_000, 10_001]
    let seeds: [UInt64] = [0, .max]
    for length in lengths {
        for seed in seeds {
            let actual = try cancellationInterval(
                sample, blockLength: length, resampleCount: 3, seed: seed, checkpoint: { _ in })
            let expected = cancellationLegacyInterval(
                sample, blockLength: length, resampleCount: 3, seed: seed)
            #expect(actual.estimate.bitPattern == expected.estimate.bitPattern)
            #expect(actual.confidenceLevel.bitPattern == expected.confidenceLevel.bitPattern)
            #expect(actual.lower.bitPattern == expected.lower.bitPattern)
            #expect(actual.upper.bitPattern == expected.upper.bitPattern)
            #expect(actual.resampleCount == expected.resampleCount)
            #expect(actual.generatorIdentifier == expected.generatorIdentifier)
            #expect(actual.seed == expected.seed)
        }
    }
}

@Test("Le validazioni precedono l'hook e la cancellazione pubblica resta CancellationError")
func resamplingCancellationPreservesValidationPrecedence() async {
    let invalid: [([Double], Int?, Double, Int, String)] = [
        ([1], nil, 1, 0, "statistics.insufficient-sample-size"),
        ([1], 1, 1, 0, "statistics.invalid-block-length"),
        ([1, 2], 0, 0.95, 1, "statistics.invalid-block-length"),
        ([1, .infinity], 2, 1, 0, "statistics.non-finite-value"),
        ([1, 2], nil, 1, 0, "statistics.invalid-resampling-parameters"),
        ([1, 2], 1, 1, 0, "statistics.invalid-resampling-parameters"),
    ]
    for (sample, length, confidence, count, code) in invalid {
        var checkpoints = 0
        do {
            _ = try cancellationInterval(
                sample, blockLength: length, confidenceLevel: confidence, resampleCount: count
            ) { _ in
                checkpoints += 1
                throw ResamplingCancellationProbeError.stopped
            }
            Issue.record("Expected the original validation failure before the checkpoint")
        } catch let failure as GlifiFailure {
            #expect(failure.code == code)
        } catch {
            Issue.record("Unexpected error instead of a validation failure: \(error)")
        }
        #expect(checkpoints == 0)
    }
    let lengths: [Int?] = [nil, 1, 2]
    for length in lengths {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            if let length {
                return try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
                    [1, 2, 3], blockLength: length, resampleCount: 1, seed: 0)
            }
            return try GlifiStatisticalFoundation.bootstrapMeanInterval(
                [1, 2, 3], resampleCount: 1, seed: 0)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

@Test("BCa riusa il kernel cancellabile conservando la precedenza della validazione pubblica")
func resamplingCancellationBCaPreservesPublicPrecedence() async {
    let valid = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
            [1, 2, 4], resampleCount: 17, seed: 176)
    }
    await #expect(throws: CancellationError.self) { try await valid.value }

    let invalid = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try GlifiStatisticalFoundation.bootstrapMeanBCaInterval(
            [1, .infinity, 4], resampleCount: 17, seed: 176)
    }
    do {
        _ = try await invalid.value
        Issue.record("Expected non-finite BCa input to fail before cancellation")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "statistics.non-finite-value")
        #expect(failure.category == .invalidInput)
    } catch {
        Issue.record("Expected BCa validation to precede cancellation, received \(error)")
    }
}

private enum ResamplingCancellationProbeError: Error {
    case stopped
}

private func cancellationInterval(
    _ sample: [Double], blockLength: Int?, confidenceLevel: Double = 0.95,
    resampleCount: Int = 1, seed: UInt64 = 176, checkpoint: (Int) throws -> Void
) throws -> GlifiBootstrapInterval {
    if let blockLength {
        return try GlifiStatisticalFoundation.movingBlockBootstrapMeanInterval(
            sample, blockLength: blockLength, confidenceLevel: confidenceLevel,
            resampleCount: resampleCount, seed: seed, checkpoint: checkpoint)
    }
    return try GlifiStatisticalFoundation.bootstrapMeanInterval(
        sample, confidenceLevel: confidenceLevel, resampleCount: resampleCount, seed: seed,
        checkpoint: checkpoint)
}

/// Literal pre-chunk draw and sum loops, with the previously verified SplitMix64 stream.
private func cancellationLegacyInterval(
    _ sample: [Double], blockLength: Int?, resampleCount: Int, seed: UInt64
) -> GlifiBootstrapInterval {
    var generator = GlifiSplitMix64(seed: seed)
    var means: [Double] = []
    for _ in 0..<resampleCount {
        var total = 0.0
        if let blockLength {
            var drawn = 0
            while drawn < sample.count {
                let start = generator.index(below: sample.count - blockLength + 1)
                let take = min(blockLength, sample.count - drawn)
                for offset in 0..<take { total += sample[start + offset] }
                drawn += take
            }
        } else {
            for _ in sample.indices { total += sample[generator.index(below: sample.count)] }
        }
        means.append(total / Double(sample.count))
    }
    means.sort()
    let tail = (1 - 0.95) / 2
    func quantile(_ probability: Double) -> Double {
        let position = Double(means.count - 1) * probability
        let index = Int(position.rounded(.down))
        let next = min(index + 1, means.count - 1)
        return means[index] + (position - Double(index)) * (means[next] - means[index])
    }
    return GlifiBootstrapInterval(
        estimate: sample.reduce(0, +) / Double(sample.count), confidenceLevel: 0.95,
        lower: quantile(tail), upper: quantile(1 - tail), resampleCount: resampleCount,
        generatorIdentifier: "SplitMix64-v1", seed: seed)
}
