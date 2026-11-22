// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import GlifiBenchmarkTestSupport
import Testing
import simd

@testable import GlifiCore

@Test("FR coincide con il riferimento scalare completo e misura workload Release espliciti")
func graphCompletionReleaseBenchmarks() throws {
    try graphLayoutBenchmark(count: 8, iterations: 3, measure: false)
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    for (count, iterations) in [(64, 20), (128, 30)] {
        try graphLayoutBenchmark(count: count, iterations: iterations, measure: true)
    }
}

@Test("FR scalare simmetrico e SIMD2 sono misurati in 21 coppie a ordine alternato")
func graphCompletionPairedFRBenchmarks() throws {
    guard let directory = ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"]
    else {
        return
    }
    #if DEBUG
        throw CompletionPairedBenchmarkFailure.releaseConfigurationRequired
    #else
        for (count, iterations) in [(64, 20), (128, 30)] {
            try measureCompletionFRPairs(count: count, iterations: iterations, directory: directory)
        }
    #endif
}

private enum CompletionPairedBenchmarkFailure: Error {
    case resultMismatch
    case releaseConfigurationRequired
    case invalidClock
}

private struct CompletionPairedSample: Encodable {
    let implementation: String
    let startUptimeNanoseconds: UInt64
    let elapsedNanoseconds: UInt64
}

private struct CompletionFRPair: Encodable {
    let index: Int
    let firstImplementation: String
    let scalarSymmetric: CompletionPairedSample
    let simd2: CompletionPairedSample
    let speedup: Double
}

private struct CompletionFRPairedReport: Encodable {
    let identifier: String
    let generator: String
    let fixtureDigest: String
    let resultDigest: String
    let device: String
    let physicalMemoryBytes: UInt64
    let logicalProcessorCount: Int
    let operatingSystem: String
    let configuration: String
    let thermalStateAtStart: String
    let thermalStateAtEnd: String
    let lowPowerModeAtStart: Bool
    let lowPowerModeAtEnd: Bool
    let loadAverageAtStart: [Double]
    let loadAverageAtEnd: [Double]
    let warmups: [CompletionPairedSample]
    let pairs: [CompletionFRPair]
    let resultChecks: Int
    let scalarSymmetricMedianSeconds: Double
    let simd2MedianSeconds: Double
    let medianPairedSpeedup: Double
    let minimumPairedSpeedup: Double
    let maximumPairedSpeedup: Double
    let simd2FasterPairs: Int
    let scalarSymmetricFasterPairs: Int
    let tiedPairs: Int
    let measurementScope: String
}

private func measureCompletionFRPairs(count: Int, iterations: Int, directory: String) throws {
    let fixture = try completionFRFixture(count: count, iterations: iterations)
    let expectedDigest = try pipelineBenchmarkDigest(fixture.expected)
    let process = ProcessInfo.processInfo
    let thermalAtStart = String(describing: process.thermalState)
    let lowPowerAtStart = process.isLowPowerModeEnabled
    let loadAtStart = completionBenchmarkLoadAverage()
    var checks = 0
    func sample(simd: Bool) throws -> CompletionPairedSample {
        try Task.checkCancellation()
        let start = DispatchTime.now().uptimeNanoseconds
        let value: CompletionLayoutSnapshot
        if simd {
            value = try CompletionLayoutSnapshot(
                simdCompletionFR(fixture.graph, fixture.points, iterations))
        } else {
            value = try CompletionLayoutSnapshot(
                symmetricCompletionFR(fixture.graph, fixture.points, iterations))
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        guard elapsed > 0 else { throw CompletionPairedBenchmarkFailure.invalidClock }
        // Every field and its canonical digest are checked only after stopping the clock.
        guard value == fixture.expected, try pipelineBenchmarkDigest(value) == expectedDigest else {
            throw CompletionPairedBenchmarkFailure.resultMismatch
        }
        checks += 1
        return CompletionPairedSample(
            implementation: simd ? "simd2" : "scalarSymmetric",
            startUptimeNanoseconds: start, elapsedNanoseconds: elapsed)
    }
    let warmups = try [sample(simd: false), sample(simd: true)]
    var pairs: [CompletionFRPair] = []
    for index in 0..<21 {
        let scalar: CompletionPairedSample
        let vector: CompletionPairedSample
        if index.isMultiple(of: 2) {
            scalar = try sample(simd: false)
            vector = try sample(simd: true)
        } else {
            vector = try sample(simd: true)
            scalar = try sample(simd: false)
        }
        pairs.append(
            CompletionFRPair(
                index: index + 1,
                firstImplementation: index.isMultiple(of: 2) ? "scalarSymmetric" : "simd2",
                scalarSymmetric: scalar, simd2: vector,
                speedup: Double(scalar.elapsedNanoseconds) / Double(vector.elapsedNanoseconds)))
    }
    var modelSize = 0
    sysctlbyname("hw.model", nil, &modelSize, nil, 0)
    var model = [CChar](repeating: 0, count: max(modelSize, 1))
    sysctlbyname("hw.model", &model, &modelSize, nil, 0)
    let ratios = pairs.map(\.speedup).sorted()
    let report = CompletionFRPairedReport(
        identifier: "kh-fr-paired-\(count)", generator: fixture.generator,
        fixtureDigest: fixture.digest, resultDigest: expectedDigest,
        device: String(
            decoding: model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self),
        physicalMemoryBytes: process.physicalMemory, logicalProcessorCount: process.processorCount,
        operatingSystem: process.operatingSystemVersionString,
        configuration:
            "SwiftPM Release; 21 sequential pairs; alternating scalar/SIMD2 execution order",
        thermalStateAtStart: thermalAtStart,
        thermalStateAtEnd: String(describing: process.thermalState),
        lowPowerModeAtStart: lowPowerAtStart, lowPowerModeAtEnd: process.isLowPowerModeEnabled,
        loadAverageAtStart: loadAtStart, loadAverageAtEnd: completionBenchmarkLoadAverage(),
        warmups: warmups, pairs: pairs, resultChecks: checks,
        scalarSymmetricMedianSeconds: Double(
            pairs.map { $0.scalarSymmetric.elapsedNanoseconds }.sorted()[10]) / 1e9,
        simd2MedianSeconds: Double(pairs.map { $0.simd2.elapsedNanoseconds }.sorted()[10]) / 1e9,
        medianPairedSpeedup: ratios[10], minimumPairedSpeedup: ratios[0],
        maximumPairedSpeedup: ratios[20],
        simd2FasterPairs: pairs.filter { $0.speedup > 1 }.count,
        scalarSymmetricFasterPairs: pairs.filter { $0.speedup < 1 }.count,
        tiedPairs: pairs.filter { $0.speedup == 1 }.count,
        measurementScope:
            "Complete layout including graph projection and array conversions; fixture, scalar expected output, full equality, SHA-256 and report encoding outside timer. Warm process; no cache flush. Sequential pairs are descriptive, not independent statistical trials or a release threshold."
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let output = URL(fileURLWithPath: directory, isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try (encoder.encode(report) + Data("\n".utf8)).write(
        to: output.appendingPathComponent(report.identifier + ".json"), options: .atomic)
}

private func completionBenchmarkLoadAverage() -> [Double] {
    var values = [Double](repeating: 0, count: 3)
    return getloadavg(&values, 3) == 3 ? values : []
}

private struct CompletionLayoutSnapshot: Equatable, Encodable {
    let methodIdentifier: String
    let nodes: [Int]
    let positions: [GlifiGraphPoint]
    let seed: UInt64
    let iterations: Int
    let converged: Bool
    let energyHistory: [Double]

    init(_ result: GlifiGraphLayoutResult<Int>) {
        methodIdentifier = result.methodIdentifier
        nodes = result.nodes
        positions = result.positions
        seed = result.seed
        iterations = result.iterations
        converged = result.converged
        energyHistory = result.energyHistory
    }
}

private func graphLayoutBenchmark(count: Int, iterations: Int, measure: Bool) throws {
    let fixture = try completionFRFixture(count: count, iterations: iterations)
    let graph = fixture.graph
    let points = fixture.points
    let expected = fixture.expected
    let optimized = try CompletionLayoutSnapshot(
        GlifiNetworkAnalysis.layout(
            graph,
            method: .fruchtermanReingold, seed: 0, maximumIterations: iterations,
            tolerance: 1e-30, initialPositions: points))
    #expect(optimized == expected)
    #expect(try CompletionLayoutSnapshot(simdCompletionFR(graph, points, iterations)) == expected)
    guard measure else { return }
    try measurePipelineOptimization(
        identifier: "kh-fr-scalar-\(count)", generator: fixture.generator,
        fixtureDigest: fixture.digest, expected: expected,
        body: { try CompletionLayoutSnapshot(scalarCompletionFR(graph, points, iterations)) },
        checksum: { try pipelineBenchmarkDigest($0) })
    try measurePipelineOptimization(
        identifier: "kh-fr-symmetric-\(count)", generator: fixture.generator,
        fixtureDigest: fixture.digest, expected: expected,
        body: { try CompletionLayoutSnapshot(symmetricCompletionFR(graph, points, iterations)) },
        checksum: { try pipelineBenchmarkDigest($0) })
    try measurePipelineOptimization(
        identifier: "kh-fr-product-simd2-\(count)", generator: fixture.generator,
        fixtureDigest: fixture.digest, expected: expected,
        body: {
            try CompletionLayoutSnapshot(
                GlifiNetworkAnalysis.layout(
                    graph, method: .fruchtermanReingold, seed: 0,
                    maximumIterations: iterations, tolerance: 1e-30, initialPositions: points))
        }, checksum: { try pipelineBenchmarkDigest($0) })
    try measurePipelineOptimization(
        identifier: "kh-fr-simd2-\(count)", generator: fixture.generator,
        fixtureDigest: fixture.digest, expected: expected,
        body: { try CompletionLayoutSnapshot(simdCompletionFR(graph, points, iterations)) },
        checksum: { try pipelineBenchmarkDigest($0) })
}

private struct CompletionFRFixture {
    let graph: GlifiDirectedGraph<Int>
    let points: [GlifiGraphPoint]
    let expected: CompletionLayoutSnapshot
    let digest: String
    let generator: String
}

private func completionFRFixture(count: Int, iterations: Int) throws -> CompletionFRFixture {
    var edges: [GlifiGraphEdge<Int>] = []
    for node in 0..<count {
        edges.append(GlifiGraphEdge(source: node, target: (node + 1) % count))
        edges.append(GlifiGraphEdge(source: node, target: (node + 7) % count))
    }
    let graph = try GlifiDirectedGraph(nodes: Array(0..<count), edges: edges)
    let points = (0..<count).map { index in
        let angle = Double(index) * 2.399963229728653
        let radius = 0.2 + 0.7 * Double(index + 1) / Double(count)
        return GlifiGraphPoint(x: radius * cos(angle), y: radius * sin(angle))
    }
    let expected = try CompletionLayoutSnapshot(scalarCompletionFR(graph, points, iterations))
    struct Fixture: Encodable {
        let nodes: [Int]
        let endpoints: [[Int]]
        let positions: [GlifiGraphPoint]
        let iterations: Int
    }
    let digest = try pipelineBenchmarkDigest(
        Fixture(
            nodes: graph.nodes,
            endpoints: edges.map { [$0.source, $0.target] }, positions: points,
            iterations: iterations))
    let generator =
        "\(count) nodes; ring and stride-seven edges; fixed golden-angle positions; \(iterations) FR iterations; exact complete scalar reference"
    return CompletionFRFixture(
        graph: graph, points: points, expected: expected,
        digest: digest, generator: generator)
}

/// Direct full ordered-pair reference, independently accumulating each node's repulsion.
private func scalarCompletionFR(
    _ input: GlifiDirectedGraph<Int>, _ initial: [GlifiGraphPoint],
    _ maximumIterations: Int
) throws -> GlifiGraphLayoutResult<Int> {
    try completionLayoutBenchmarkAdmission(input, initial, maximumIterations)
    let graph = try GlifiPreparedCommunityGraph(input, limits: .standard, weighted: false)
    let n = graph.count
    let k = sqrt(4 / Double(n))
    var points = initial
    for iteration in 0..<maximumIterations {
        var dx = [Double](repeating: 0, count: n)
        var dy = dx
        for node in 0..<n {
            for other in 0..<n where node != other {
                var x = points[node].x - points[other].x
                var y = points[node].y - points[other].y
                var distance = hypot(x, y)
                if distance <= 1e-9 {
                    let sign = node > other ? 1.0 : -1.0
                    let angle = Double(node + other + 1) * 2.399963229728653
                    x = sign * cos(angle) * 1e-9
                    y = sign * sin(angle) * 1e-9
                    distance = 1e-9
                }
                let factor = k * k / (distance * distance)
                dx[node] += x * factor
                dy[node] += y * factor
            }
        }
        for edge in graph.edges {
            var x = points[edge.left].x - points[edge.right].x
            var y = points[edge.left].y - points[edge.right].y
            var distance = hypot(x, y)
            if distance <= 1e-9 {
                let angle = Double(edge.left + edge.right + 1) * 2.399963229728653
                x = cos(angle) * 1e-9
                y = sin(angle) * 1e-9
                distance = 1e-9
            }
            let factor = distance / k
            dx[edge.left] -= x * factor
            dy[edge.left] -= y * factor
            dx[edge.right] += x * factor
            dy[edge.right] += y * factor
        }
        let temperature = 0.2 * Double(maximumIterations - iteration) / Double(maximumIterations)
        var largest = 0.0
        for node in 0..<n {
            let distance = hypot(dx[node], dy[node])
            let step = distance > 0 ? min(distance, temperature) / distance : 0
            let next = GlifiGraphPoint(
                x: min(1, max(-1, points[node].x + dx[node] * step)),
                y: min(1, max(-1, points[node].y + dy[node] * step)))
            largest = max(largest, hypot(next.x - points[node].x, next.y - points[node].y))
            points[node] = next
        }
        if largest <= 1e-30 {
            return GlifiGraphLayoutResult(
                methodIdentifier: GlifiGraphLayoutMethod.fruchtermanReingold.rawValue,
                nodes: input.nodes, positions: points, seed: 0, iterations: iteration + 1,
                converged: true, energyHistory: [])
        }
    }
    return GlifiGraphLayoutResult(
        methodIdentifier: GlifiGraphLayoutMethod.fruchtermanReingold.rawValue,
        nodes: input.nodes, positions: points, seed: 0, iterations: maximumIterations,
        converged: false, energyHistory: [])
}

private func completionLayoutBenchmarkAdmission(
    _ input: GlifiDirectedGraph<Int>, _ initial: [GlifiGraphPoint], _ iterations: Int
) throws {
    try admitGraph(input, limits: .standard)
    guard (1...100_000).contains(iterations), initial.count == input.nodes.count,
        initial.allSatisfy({ $0.x.isFinite && $0.y.isFinite && abs($0.x) <= 1 && abs($0.y) <= 1 })
    else { throw graphAlgorithmFailure("network.invalid-layout-positions") }
    try admitGraphWork([iterations, input.nodes.count, input.nodes.count + 32], limits: .standard)
}

/// Frozen SIMD2 benchmark reference; the product is checked against the independent scalar oracle.
private func simdCompletionFR(
    _ input: GlifiDirectedGraph<Int>, _ initial: [GlifiGraphPoint], _ maximumIterations: Int
) throws -> GlifiGraphLayoutResult<Int> {
    try completionLayoutBenchmarkAdmission(input, initial, maximumIterations)
    let graph = try GlifiPreparedCommunityGraph(input, limits: .standard, weighted: false)
    let n = graph.count
    let k = sqrt(4 / Double(n))
    var points = initial.map { SIMD2<Double>($0.x, $0.y) }
    var displacement = Array(repeating: SIMD2<Double>.zero, count: n)
    var completed = maximumIterations
    var converged = false
    for iteration in 0..<maximumIterations {
        try Task.checkCancellation()
        for node in 0..<n { displacement[node] = .zero }
        for left in 0..<n {
            if left.isMultiple(of: 32) { try Task.checkCancellation() }
            for right in 0..<left {
                let (delta, distance) = completionSIMDDifference(
                    points[left], points[right], left, right)
                let force = delta * (k * k / (distance * distance))
                displacement[left] += force
                displacement[right] -= force
            }
        }
        for edge in graph.edges {
            let (delta, distance) = completionSIMDDifference(
                points[edge.left], points[edge.right], edge.left, edge.right)
            let force = delta * (distance / k)
            displacement[edge.left] -= force
            displacement[edge.right] += force
        }
        let temperature = 0.2 * Double(maximumIterations - iteration) / Double(maximumIterations)
        var largest = 0.0
        for node in 0..<n {
            let distance = hypot(displacement[node].x, displacement[node].y)
            let step = distance > 0 ? min(distance, temperature) / distance : 0
            let next = simd_clamp(
                points[node] + displacement[node] * step,
                SIMD2<Double>(repeating: -1), SIMD2<Double>(repeating: 1))
            largest = max(largest, hypot(next.x - points[node].x, next.y - points[node].y))
            points[node] = next
        }
        if largest <= 1e-30 {
            completed = iteration + 1
            converged = true
            break
        }
    }
    return GlifiGraphLayoutResult(
        methodIdentifier: GlifiGraphLayoutMethod.fruchtermanReingold.rawValue,
        nodes: input.nodes, positions: points.map { GlifiGraphPoint(x: $0.x, y: $0.y) }, seed: 0,
        iterations: completed, converged: converged, energyHistory: [])
}

private func completionSIMDDifference(
    _ left: SIMD2<Double>, _ right: SIMD2<Double>,
    _ first: Int, _ second: Int
) -> (SIMD2<Double>, Double) {
    let delta = left - right
    let distance = hypot(delta.x, delta.y)
    if distance > 1e-9 { return (delta, distance) }
    let angle = Double(first + second + 1) * 2.399963229728653
    return (SIMD2<Double>(cos(angle) * 1e-9, sin(angle) * 1e-9), 1e-9)
}

// Frozen scalar-symmetric FR kernel, retained even if the product later adopts SIMD2.
// GlifiGraphLayouts.swift SHA-256: 97100efdf922bb0619c2693343747fb9ee34a08bb7abcfb6cbff5f8aa9e27ed0.
private func symmetricCompletionFR(
    _ input: GlifiDirectedGraph<Int>, _ initial: [GlifiGraphPoint], _ maximumIterations: Int
) throws -> GlifiGraphLayoutResult<Int> {
    try completionLayoutBenchmarkAdmission(input, initial, maximumIterations)
    let graph = try GlifiPreparedCommunityGraph(input, limits: .standard, weighted: false)
    let tolerance = 1e-30
    let n = graph.count
    let k = sqrt(4 / Double(n))
    var points = initial
    var dx = [Double](repeating: 0, count: n)
    var dy = dx
    for iteration in 0..<maximumIterations {
        try Task.checkCancellation()
        for node in 0..<n {
            dx[node] = 0
            dy[node] = 0
        }
        for left in 0..<n {
            if left.isMultiple(of: 32) { try Task.checkCancellation() }
            for right in 0..<left {
                let difference = symmetricCompletionDifference(
                    points[left], points[right], first: left, second: right)
                let force = k * k / (difference.length * difference.length)
                let x = difference.x * force
                let y = difference.y * force
                dx[left] += x
                dy[left] += y
                dx[right] -= x
                dy[right] -= y
            }
        }
        for edge in graph.edges {
            let difference = symmetricCompletionDifference(
                points[edge.left], points[edge.right], first: edge.left, second: edge.right)
            let force = difference.length / k
            let x = difference.x * force
            let y = difference.y * force
            dx[edge.left] -= x
            dy[edge.left] -= y
            dx[edge.right] += x
            dy[edge.right] += y
        }
        let temperature = 0.2 * Double(maximumIterations - iteration) / Double(maximumIterations)
        var largestMove = 0.0
        for node in 0..<n {
            let length = hypot(dx[node], dy[node])
            let step = length > 0 ? min(length, temperature) / length : 0
            let next = GlifiGraphPoint(
                x: min(1, max(-1, points[node].x + dx[node] * step)),
                y: min(1, max(-1, points[node].y + dy[node] * step)))
            largestMove = max(largestMove, hypot(next.x - points[node].x, next.y - points[node].y))
            points[node] = next
        }
        if largestMove <= tolerance {
            try Task.checkCancellation()
            return GlifiGraphLayoutResult(
                methodIdentifier: GlifiGraphLayoutMethod.fruchtermanReingold.rawValue,
                nodes: input.nodes, positions: points, seed: 0,
                iterations: iteration + 1, converged: true, energyHistory: [])
        }
    }
    try Task.checkCancellation()
    return GlifiGraphLayoutResult(
        methodIdentifier: GlifiGraphLayoutMethod.fruchtermanReingold.rawValue,
        nodes: input.nodes, positions: points, seed: 0,
        iterations: maximumIterations, converged: false, energyHistory: [])
}

private func symmetricCompletionDifference(
    _ left: GlifiGraphPoint, _ right: GlifiGraphPoint, first: Int, second: Int
) -> (x: Double, y: Double, length: Double) {
    let x = left.x - right.x
    let y = left.y - right.y
    let length = hypot(x, y)
    if length > 1e-9 { return (x, y, length) }
    let angle = Double(first + second + 1) * 2.399963229728653
    return (cos(angle) * 1e-9, sin(angle) * 1e-9, 1e-9)
}
