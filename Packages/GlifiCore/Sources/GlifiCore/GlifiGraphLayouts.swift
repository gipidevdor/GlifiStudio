// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import simd

/// Two-dimensional native layouts, separate from graph weights and scientific findings.
public enum GlifiGraphLayoutMethod: String, Codable, CaseIterable, Sendable {
    /// Exact pair repulsion and edge attraction, linearly cooled inside [-1,1] squared.
    case fruchtermanReingold = "FruchtermanReingold-unweighted-square-v1"
    /// Hop-distance springs and monotone Newton steps, with explicit virtual component distances.
    case kamadaKawai = "KamadaKawai-hop-component-extension-v1"
}

/// Dimensionless two-dimensional coordinates; initial layout positions must lie in [-1,1] squared.
public struct GlifiGraphPoint: Codable, Equatable, Sendable {
    /// Dimensionless horizontal layout coordinate.
    public let x: Double
    /// Dimensionless vertical layout coordinate.
    public let y: Double

    /// Creates coordinates; a layout validates supplied initial positions before numerical work.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Coordinates in declared node order, with explicit stopping diagnostics.
public struct GlifiGraphLayoutResult<Node: Hashable & Sendable>: Sendable {
    /// Versioned native algorithm and numerical contract.
    public let methodIdentifier: String
    /// Input node identities in declared order, defining all aligned result arrays.
    public let nodes: [Node]
    /// Dimensionless positions aligned with nodes; FR is bounded, KK is centered.
    public let positions: [GlifiGraphPoint]
    /// Recorded seed for initial positions; explicit initial positions take precedence.
    public let seed: UInt64
    /// Completed cooling iterations or accepted Kamada-Kawai Newton steps.
    public let iterations: Int
    /// Whether the method-specific displacement or gradient stopping tolerance was met.
    public let converged: Bool
    /// Monotone spring energy for Kamada–Kawai; empty for force-cooled FR.
    public let energyHistory: [Double]
}

extension GlifiNetworkAnalysis {
    /// Lays out the unweighted positive-edge projection.
    ///
    /// Directions/multiedges coalesce,
    /// loops and zero edges are omitted. Seeded initial positions lie in the square [-1,1]².
    /// Explicit initial positions must lie in that square; final KK coordinates are centered.
    ///
    /// FR uses k=sqrt(4/n), exact pair repulsion and linear temperature cooling.
    /// KK uses hop-distance springs, Newton steps with monotone backtracking, and virtual
    /// distance 2*max(1,diameter) between disconnected components. This extension is explicit:
    /// disconnected graph distances are never presented as observed finite shortest paths.
    public static func layout<Node>(
        _ graph: GlifiDirectedGraph<Node>, method: GlifiGraphLayoutMethod,
        seed: UInt64 = 0, maximumIterations: Int = 300, tolerance: Double = 1e-6,
        initialPositions: [GlifiGraphPoint]? = nil,
        limits: GlifiGraphAlgorithmLimits = .standard
    ) throws -> GlifiGraphLayoutResult<Node> {
        try admitGraph(graph, limits: limits)
        guard (1...100_000).contains(maximumIterations), tolerance.isFinite, tolerance > 0 else {
            throw graphAlgorithmFailure("network.invalid-layout-parameters")
        }
        let n = graph.nodes.count
        if let initialPositions {
            guard initialPositions.count == n,
                initialPositions.allSatisfy({
                    $0.x.isFinite && $0.y.isFinite && abs($0.x) <= 1 && abs($0.y) <= 1
                })
            else { throw graphAlgorithmFailure("network.invalid-layout-positions") }
        }
        switch method {
        case .fruchtermanReingold:
            try admitGraphWork([maximumIterations, n, n + 32], limits: limits)
        case .kamadaKawai:
            try admitGraphPairs(n, limits: limits)
            // All-pairs BFS visits nodes and both ends of each projected edge. Input arc
            // count is a conservative upper bound, available before projection allocation.
            try admitGraphWork(
                phases: [[maximumIterations, n, n + 32], [n, n], [2, n, graph.edges.count]],
                limits: limits)
        }
        let prepared = try GlifiPreparedCommunityGraph(graph, limits: limits, weighted: false)
        var generator = GlifiSplitMix64(seed: seed)
        let initial =
            initialPositions
            ?? (0..<n).map { _ in
                GlifiGraphPoint(
                    x: Double(generator.next() >> 11) / 4_503_599_627_370_496 - 1,
                    y: Double(generator.next() >> 11) / 4_503_599_627_370_496 - 1)
            }
        let output: LayoutOutput
        if n <= 1 {
            output = LayoutOutput(
                points: initial.map { _ in GlifiGraphPoint(x: 0, y: 0) },
                iterations: 0, converged: true, history: [])
        } else {
            switch method {
            case .fruchtermanReingold:
                output = try fruchtermanReingold(
                    prepared, initial: initial,
                    maximumIterations: maximumIterations, tolerance: tolerance)
            case .kamadaKawai:
                output = try kamadaKawai(
                    prepared, initial: initial,
                    maximumIterations: maximumIterations, tolerance: tolerance)
            }
        }
        try Task.checkCancellation()
        return GlifiGraphLayoutResult(
            methodIdentifier: method.rawValue, nodes: graph.nodes, positions: output.points,
            seed: seed, iterations: output.iterations, converged: output.converged,
            energyHistory: output.history)
    }
}

private struct LayoutOutput {
    let points: [GlifiGraphPoint]
    let iterations: Int
    let converged: Bool
    let history: [Double]
}

private func separatedLayoutDifference(
    _ left: GlifiGraphPoint, _ right: GlifiGraphPoint, first: Int, second: Int
) -> (x: Double, y: Double, length: Double) {
    let x = left.x - right.x
    let y = left.y - right.y
    let length = hypot(x, y)
    if length > 1e-9 { return (x, y, length) }
    let angle = Double(first + second + 1) * 2.399963229728653
    return (cos(angle) * 1e-9, sin(angle) * 1e-9, 1e-9)
}

// SIMD2 preserves the scalar accumulation order and avoids evaluating each pair twice.
// Whole-layout alternating benchmarks and complete-result oracles are retained in the tests.
private func fruchtermanReingold(
    _ graph: GlifiPreparedCommunityGraph, initial: [GlifiGraphPoint],
    maximumIterations: Int, tolerance: Double
) throws -> LayoutOutput {
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
                let (delta, distance) = separatedLayoutVectorDifference(
                    points[left], points[right], first: left, second: right)
                let force = delta * (k * k / (distance * distance))
                displacement[left] += force
                displacement[right] -= force
            }
        }
        for edge in graph.edges {
            let (delta, distance) = separatedLayoutVectorDifference(
                points[edge.left], points[edge.right], first: edge.left, second: edge.right)
            let force = delta * (distance / k)
            displacement[edge.left] -= force
            displacement[edge.right] += force
        }
        let temperature = 0.2 * Double(maximumIterations - iteration) / Double(maximumIterations)
        var largestMove = 0.0
        for node in 0..<n {
            let distance = hypot(displacement[node].x, displacement[node].y)
            let step = distance > 0 ? min(distance, temperature) / distance : 0
            let next = simd_clamp(
                points[node] + displacement[node] * step,
                SIMD2<Double>(repeating: -1), SIMD2<Double>(repeating: 1))
            largestMove = max(largestMove, hypot(next.x - points[node].x, next.y - points[node].y))
            points[node] = next
        }
        if largestMove <= tolerance {
            completed = iteration + 1
            converged = true
            break
        }
    }
    return LayoutOutput(
        points: points.map { GlifiGraphPoint(x: $0.x, y: $0.y) },
        iterations: completed, converged: converged, history: [])
}

private func separatedLayoutVectorDifference(
    _ left: SIMD2<Double>, _ right: SIMD2<Double>, first: Int, second: Int
) -> (SIMD2<Double>, Double) {
    let delta = left - right
    let distance = hypot(delta.x, delta.y)
    if distance > 1e-9 { return (delta, distance) }
    let angle = Double(first + second + 1) * 2.399963229728653
    return (SIMD2<Double>(cos(angle) * 1e-9, sin(angle) * 1e-9), 1e-9)
}

private func layoutHopDistances(_ graph: GlifiPreparedCommunityGraph) throws -> ([[Int]], Double) {
    let n = graph.count
    var distances = Array(repeating: Array(repeating: -1, count: n), count: n)
    var diameter = 1
    for start in 0..<n {
        try Task.checkCancellation()
        var queue = [start]
        var head = 0
        distances[start][start] = 0
        while head < queue.count {
            let node = queue[head]
            head += 1
            for neighbor in graph.adjacency[node] where distances[start][neighbor.node] < 0 {
                let distance = distances[start][node] + 1
                distances[start][neighbor.node] = distance
                diameter = max(diameter, distance)
                queue.append(neighbor.node)
            }
        }
    }
    for row in 0..<n {
        for column in 0..<n where distances[row][column] < 0 {
            distances[row][column] = 2 * diameter
        }
    }
    return (distances, Double(diameter))
}

private func kamadaKawai(
    _ graph: GlifiPreparedCommunityGraph, initial: [GlifiGraphPoint],
    maximumIterations: Int, tolerance: Double
) throws -> LayoutOutput {
    let (distances, diameter) = try layoutHopDistances(graph)
    let n = graph.count
    var points = initial
    // Deterministically separate coincident inputs before the differentiable spring objective.
    for node in 0..<n {
        if (0..<node).contains(where: { points[$0] == points[node] }) {
            let angle = Double(node + 1) * 2.399963229728653
            points[node] = GlifiGraphPoint(
                x: points[node].x + 1e-5 * cos(angle), y: points[node].y + 1e-5 * sin(angle))
        }
    }
    func localEnergy(_ node: Int, at point: GlifiGraphPoint) -> Double {
        var value = 0.0
        for other in 0..<n where other != node {
            let distance = Double(distances[node][other])
            let residual =
                hypot(point.x - points[other].x, point.y - points[other].y) - distance / diameter
            value += 0.5 * residual * residual / (distance * distance)
        }
        return value
    }
    func derivatives(_ node: Int) -> (x: Double, y: Double, xx: Double, yy: Double, xy: Double) {
        var gx = 0.0
        var gy = 0.0
        var xx = 0.0
        var yy = 0.0
        var xy = 0.0
        for other in 0..<n where other != node {
            let distance = Double(distances[node][other])
            let stiffness = 1 / (distance * distance)
            let desired = distance / diameter
            let dx = points[node].x - points[other].x
            let dy = points[node].y - points[other].y
            let length = max(1e-12, hypot(dx, dy))
            let cube = length * length * length
            gx += stiffness * dx * (1 - desired / length)
            gy += stiffness * dy * (1 - desired / length)
            xx += stiffness * (1 - desired * dy * dy / cube)
            yy += stiffness * (1 - desired * dx * dx / cube)
            xy += stiffness * desired * dx * dy / cube
        }
        return (gx, gy, xx, yy, xy)
    }
    var energy = (0..<n).reduce(0.0) { $0 + localEnergy($1, at: points[$1]) } / 2
    var history = [energy]
    var completed = 0
    var converged = false
    for _ in 0..<maximumIterations {
        try Task.checkCancellation()
        var selected = 0
        var largest = -1.0
        for node in 0..<n {
            if node.isMultiple(of: 32) { try Task.checkCancellation() }
            let gradient = derivatives(node)
            let magnitude = hypot(gradient.x, gradient.y)
            if magnitude > largest {
                largest = magnitude
                selected = node
            }
        }
        if largest <= tolerance {
            converged = true
            break
        }
        let derivative = derivatives(selected)
        let determinant = derivative.xx * derivative.yy - derivative.xy * derivative.xy
        var sx = -derivative.x
        var sy = -derivative.y
        if determinant.isFinite, abs(determinant) > 1e-12 {
            let nx = (derivative.xy * derivative.y - derivative.yy * derivative.x) / determinant
            let ny = (derivative.xy * derivative.x - derivative.xx * derivative.y) / determinant
            if nx.isFinite, ny.isFinite, nx * derivative.x + ny * derivative.y < 0 {
                sx = nx
                sy = ny
            }
        }
        let length = hypot(sx, sy)
        if length > 1 {
            sx /= length
            sy /= length
        }
        let oldLocal = localEnergy(selected, at: points[selected])
        var step = 1.0
        var accepted = false
        for _ in 0..<32 {
            let candidate = GlifiGraphPoint(
                x: points[selected].x + step * sx, y: points[selected].y + step * sy)
            let candidateEnergy = localEnergy(selected, at: candidate)
            if candidateEnergy.isFinite, candidateEnergy < oldLocal {
                points[selected] = candidate
                energy += candidateEnergy - oldLocal
                history.append(max(0, energy))
                completed += 1
                accepted = true
                break
            }
            step *= 0.5
        }
        if !accepted { break }
    }
    let meanX = points.reduce(0) { $0 + $1.x } / Double(n)
    let meanY = points.reduce(0) { $0 + $1.y } / Double(n)
    points = points.map { GlifiGraphPoint(x: $0.x - meanX, y: $0.y - meanY) }
    guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), history.allSatisfy(\.isFinite)
    else {
        throw graphAlgorithmFailure("network.numeric-range")
    }
    return LayoutOutput(
        points: points, iterations: completed, converged: converged, history: history)
}
