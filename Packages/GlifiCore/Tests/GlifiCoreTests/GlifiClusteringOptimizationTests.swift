// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("HAC ottimizzato conserva esattamente il riferimento diretto per seed, linkage e tie")
func hierarchicalOptimizationMatchesDirectReference() throws {
    for seed in 1...12 {
        var generator = GlifiSplitMix64(seed: UInt64(seed))
        let points: [[Double]] = (0..<16).map { _ in
            (0..<4).map { _ in Double(generator.index(below: 16)) / 4 }
        }
        for linkage in [GlifiLinkage.single, .complete, .average, .ward] {
            let actual = try GlifiMultivariateMethods.hierarchicalClustering(
                points, linkage: linkage)
            let reference = directHierarchicalReference(points, linkage: linkage)
            #expect(actual == reference)
        }
    }
}

// Independent direct definition: every candidate is recomputed from its members.
// This deliberately does not use cached distances, recurrence updates or active slots.
private func directHierarchicalReference(
    _ points: [[Double]], linkage: GlifiLinkage
) -> GlifiHierarchicalClustering {
    let count = points.count
    func squared(_ left: [Double], _ right: [Double]) -> Double {
        zip(left, right).reduce(0.0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
    }
    var clusters: [(id: Int, members: [Int])] = points.indices.map { ($0, [$0]) }
    var merges: [GlifiMerge] = []
    for step in 0..<(count - 1) {
        var best = (left: 0, right: 1, value: Double.infinity)
        var identities = (Int.max, Int.max)
        for left in clusters.indices {
            for right in (left + 1)..<clusters.count {
                let a = clusters[left].members
                let b = clusters[right].members
                let value: Double
                switch linkage {
                case .single, .complete:
                    let distances = a.flatMap { row in
                        b.map { squared(points[row], points[$0]).squareRoot() }
                    }
                    value = linkage == .single ? (distances.min() ?? 0) : (distances.max() ?? 0)
                case .average:
                    value =
                        a.reduce(0.0) { total, row in
                            total
                                + b.reduce(0.0) {
                                    $0 + squared(points[row], points[$1]).squareRoot()
                                }
                        } / Double(a.count * b.count)
                case .ward:
                    func centroid(_ members: [Int]) -> [Double] {
                        points[0].indices.map { column in
                            members.reduce(0.0) { $0 + points[$1][column] / Double(members.count) }
                        }
                    }
                    value =
                        Double(a.count) * Double(b.count) / Double(a.count + b.count)
                        * squared(centroid(a), centroid(b))
                }
                let pair = (
                    min(clusters[left].id, clusters[right].id),
                    max(clusters[left].id, clusters[right].id)
                )
                if value < best.value || (value == best.value && pair < identities) {
                    best = (left, right, value)
                    identities = pair
                }
            }
        }
        let members = clusters[best.left].members + clusters[best.right].members
        merges.append(
            .init(
                first: identities.0, second: identities.1,
                height: linkage == .ward ? (2 * best.value).squareRoot() : best.value,
                wardIncrement: linkage == .ward ? best.value : nil, size: members.count))
        clusters.remove(at: best.right)
        clusters[best.left] = (count + step, members)
    }
    return .init(linkage: linkage, merges: merges)
}
