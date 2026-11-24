// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La silhouette coincide con cluster::silhouette di R")
func silhouetteMatchesR() throws {
    let counts: [[Double]] = [
        [4, 2, 0, 1], [1, 3, 2, 0], [0, 1, 5, 2], [2, 0, 1, 3], [3, 1, 1, 1],
    ]
    let profiles = counts.map { row in row.map { $0 / row.reduce(0, +) } }
    let result = try GlifiMultivariateMethods.silhouette(profiles, assignments: [0, 1, 1, 0, 0])
    let expected = [
        0.476787708850394, 0.0916969051728845, 0.228274662963143, 0.310121346791568,
        0.482985513849474,
    ]
    for (value, reference) in zip(result.widths, expected) {
        #expect(abs(value - reference) < 1e-12)
    }
    #expect(abs(result.average - 0.317973227525493) < 1e-12)
}

@Test("Le policy ADR-0026 applicano le soglie di confine dichiarate")
func supportPoliciesApplyDeclaredBoundaries() {
    // Cramér's V con d*=1 (2×k): soglie di Cohen 0,1/0,3/0,5.
    #expect(
        GlifiSupportPolicies.contingency(
            cramersV: 0.5, minimumDimension: 2, monteCarloPValue: 0.01, lowExpectedCellFraction: 0
        ).supportClass == .strong)
    #expect(
        GlifiSupportPolicies.contingency(
            cramersV: 0.5, minimumDimension: 2, monteCarloPValue: 0.02, lowExpectedCellFraction: 0
        ).supportClass == .moderate)
    #expect(
        GlifiSupportPolicies.contingency(
            cramersV: 0.1, minimumDimension: 2, monteCarloPValue: 0.04, lowExpectedCellFraction: 0
        ).supportClass == .weak)
    #expect(
        GlifiSupportPolicies.contingency(
            cramersV: 0.3, minimumDimension: 2, monteCarloPValue: 0.06, lowExpectedCellFraction: 0
        ).supportClass == .insufficient)
    #expect(
        GlifiSupportPolicies.contingency(
            cramersV: 0.3, minimumDimension: 2, monteCarloPValue: 0.01,
            lowExpectedCellFraction: 0.25
        ).supportClass == .caution)
    // d*=4 (5×k): soglie divise per 2, quindi V=0,25 è già «large».
    #expect(
        GlifiSupportPolicies.contingency(
            cramersV: 0.25, minimumDimension: 5, monteCarloPValue: 0.001, lowExpectedCellFraction: 0
        ).supportClass == .strong)

    #expect(
        GlifiSupportPolicies.groupLocation(hedgesG: -0.8, pValue: 0.01, smallestGroupSize: 10)
            .supportClass == .strong)
    #expect(
        GlifiSupportPolicies.groupLocation(hedgesG: 0.8, pValue: 0.03, smallestGroupSize: 10)
            .supportClass == .moderate)
    #expect(
        GlifiSupportPolicies.groupLocation(hedgesG: 0.2, pValue: 0.05, smallestGroupSize: 10)
            .supportClass == .weak)
    #expect(
        GlifiSupportPolicies.groupLocation(hedgesG: 0.19, pValue: 0.001, smallestGroupSize: 10)
            .supportClass == .insufficient)
    #expect(
        GlifiSupportPolicies.groupLocation(hedgesG: 1, pValue: 0.001, smallestGroupSize: 4)
            .supportClass == .caution)

    #expect(
        GlifiSupportPolicies.collocation(jointCount: 5, tScore: 2, npmi: 0.5).supportClass
            == .strong)
    #expect(
        GlifiSupportPolicies.collocation(jointCount: 6, tScore: 3, npmi: 0.25).supportClass
            == .moderate)
    #expect(
        GlifiSupportPolicies.collocation(jointCount: 6, tScore: 3, npmi: 0.1).supportClass == .weak)
    #expect(
        GlifiSupportPolicies.collocation(jointCount: 3, tScore: 2.5, npmi: 0.6).supportClass
            == .caution)
    #expect(
        GlifiSupportPolicies.collocation(jointCount: 2, tScore: 5, npmi: 0.9).supportClass
            == .insufficient)
    #expect(
        GlifiSupportPolicies.collocation(jointCount: 9, tScore: 1.9, npmi: 0.9).supportClass
            == .insufficient)
    #expect(
        GlifiSupportPolicies.collocation(jointCount: 9, tScore: nil, npmi: 0.9).supportClass
            == .insufficient)

    #expect(GlifiSupportPolicies.community(modularity: 0.5, nodeCount: 20).supportClass == .strong)
    #expect(
        GlifiSupportPolicies.community(modularity: 0.3, nodeCount: 20).supportClass == .moderate)
    #expect(
        GlifiSupportPolicies.community(modularity: 0.29, nodeCount: 20).supportClass
            == .insufficient)
    #expect(GlifiSupportPolicies.community(modularity: 0.6, nodeCount: 6).supportClass == .caution)

    #expect(
        GlifiSupportPolicies.clustering(averageSilhouette: 0.71, smallestClusterSize: 3)
            .supportClass == .strong)
    #expect(
        GlifiSupportPolicies.clustering(averageSilhouette: 0.51, smallestClusterSize: 3)
            .supportClass == .moderate)
    #expect(
        GlifiSupportPolicies.clustering(
            averageSilhouette: 0.317973227525493, smallestClusterSize: 2
        ).supportClass == .weak)
    #expect(
        GlifiSupportPolicies.clustering(averageSilhouette: 0.25, smallestClusterSize: 3)
            .supportClass == .insufficient)
    #expect(
        GlifiSupportPolicies.clustering(averageSilhouette: 0.8, smallestClusterSize: 1).supportClass
            == .caution)

    // Regola dell'inerzia media con K=3 assi: media 1/3, dominante da 2/3.
    #expect(
        GlifiSupportPolicies.correspondenceAxis(inertiaShare: 0.7, axisCount: 3, totalInertia: 0.5)
            .supportClass == .strong)
    #expect(
        GlifiSupportPolicies.correspondenceAxis(inertiaShare: 0.4, axisCount: 3, totalInertia: 0.5)
            .supportClass == .moderate)
    #expect(
        GlifiSupportPolicies.correspondenceAxis(inertiaShare: 0.3, axisCount: 3, totalInertia: 0.5)
            .supportClass == .insufficient)
    #expect(
        GlifiSupportPolicies.correspondenceAxis(inertiaShare: 0.7, axisCount: 3, totalInertia: 0.01)
            .supportClass == .caution)

    #expect(GlifiSupportPolicies.similarity(sharedTypeCount: 40).supportClass == .descriptive)
    #expect(GlifiSupportPolicies.similarity(sharedTypeCount: 3).supportClass == .caution)
    let outcome = GlifiSupportPolicies.groupLocation(
        hedgesG: 0.9, pValue: 0.001, smallestGroupSize: 8)
    #expect(outcome.dimensions.map(\.identifier) == ["hedges-g", "p-value", "smallest-group-size"])
}
