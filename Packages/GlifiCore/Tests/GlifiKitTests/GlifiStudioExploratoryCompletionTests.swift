// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import Testing

@testable import GlifiKit

@Test("Exploratory facade preserves every multistart run and its encoded diagnostics")
func studioCompletionMDSSearchParity() async throws {
    let distances: [[Double]] = [[0, 1, 3, 2], [1, 0, 2, 4], [3, 2, 0, 1], [2, 4, 1, 0]]
    let facade = try await GlifiStudioExploratoryCompletion.multidimensionalScalingSearch(
        distances, starts: 3, seed: 27, maximumIterations: 30)
    let core = try GlifiExploratoryAnalysis.multidimensionalScalingSearch(
        distances, starts: 3, seed: 27, maximumIterations: 30)
    #expect(facade.runs == core.runs.map(GlifiStudioMDSResult.init))
    #expect(facade.chosenRun == core.chosenRun)
    #expect(facade.best == GlifiStudioMDSResult(core.best))
    let encoded = try JSONEncoder().encode(facade)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let runs = try #require(object["runs"] as? [[String: Any]])
    #expect(runs.count == 3)
    #expect(
        runs.allSatisfy {
            $0["seed"] != nil && $0["objectiveHistory"] != nil && $0["converged"] != nil
        })
    #expect(object["chosenRun"] as? Int == core.chosenRun)
}

@Test("Advanced SOM facade preserves topology, U-matrix and all Ward diagnostics")
func studioCompletionAdvancedSOMParity() async throws {
    let data: [[Double]] = [[0, 1], [2, 3], [4, 0], [10, 11], [11, 10], [12, 12]]
    let facade = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
        data, width: 3, height: 2, seed: 27, epochs: 4, topology: .hexagonal,
        codebookClusterCount: 2)
    let map = try GlifiExploratoryAnalysis.selfOrganizingMap(
        data, width: 3, height: 2, seed: 27, epochs: 4, topology: .hexagonal)
    let clustering = try GlifiExploratoryAnalysis.clusterSelfOrganizingMapCodebooks(
        map, clusterCount: 2)
    #expect(facade.map == GlifiStudioSOMResult(map))
    #expect(facade.map.methodIdentifier == map.methodIdentifier)
    #expect(facade.topology == .hexagonal)
    #expect(facade.uMatrix == (try GlifiExploratoryAnalysis.selfOrganizingMapUMatrix(map)))
    let ward = try #require(facade.codebookClustering)
    #expect(ward.children == clustering.tree.merges.map { [$0.first, $0.second] })
    #expect(ward.wardIncrements == clustering.tree.merges.map(\.wardIncrement))
    #expect(ward.heights == clustering.tree.merges.map(\.height))
    #expect(ward.sizes == clustering.tree.merges.map(\.size))
    #expect(ward.assignments == clustering.assignments)
    let object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(facade)) as? [String: Any])
    #expect(object["topology"] as? String == "hexagonal")
    #expect((object["uMatrix"] as? [Double])?.count == 6)
    #expect(object["codebookClustering"] != nil)
}

@Test("Advanced SOM facade preserves the legacy rectangular default")
func studioCompletionRectangularCompatibility() async throws {
    let data: [[Double]] = [[0], [1], [4], [5]]
    let advanced = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
        data, width: 2, height: 2, seed: 12, epochs: 3)
    let original = try await GlifiStudioTextAnalytics.selfOrganizingMap(
        data, width: 2, height: 2, seed: 12, epochs: 3)
    #expect(advanced.map == original)
    #expect(advanced.topology == .rectangular)
    #expect(advanced.codebookClustering == nil)
}

@Test("Exploratory facade preserves typed domain failures and rejects overflowing geometry")
func studioCompletionTypedFailures() async throws {
    do {
        _ = try await GlifiStudioExploratoryCompletion.multidimensionalScalingSearch(
            [[0, 1], [2, 0]], dimensions: 1, starts: 1, seed: 0)
        Issue.record("Asymmetric distances were accepted")
    } catch {
        #expect(error.category == "invalidInput")
        #expect(error.retainedState == "unchanged")
        #expect(error.code == "mds.invalid-distances")
    }
    do {
        _ = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
            [[0], [1]], width: Int.max, height: Int.max, seed: 0, codebookClusterCount: 1)
        Issue.record("Overflowing grid was accepted")
    } catch {
        #expect(error.code == "exploratory.invalid-parameters")
    }
    do {
        _ = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
            [[0], [1]], width: 2, height: 1, seed: 0, codebookClusterCount: 3)
        Issue.record("Invalid cluster count was accepted")
    } catch {
        #expect(error.code == "exploratory.invalid-parameters")
    }
    do {
        _ = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
            [[0], [1]], width: 32, height: 32, seed: 0, epochs: 1, codebookClusterCount: 2)
        Issue.record("Over-budget codebook composition was accepted")
    } catch {
        #expect(error.code == "exploratory.resource-limit")
        #expect(error.category == "insufficientResources")
    }
}

@Test("Exploratory facade maps cancellation without launching an unstructured task")
func studioCompletionTypedCancellation() async throws {
    for operation in 0..<2 {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            if operation == 0 {
                _ = try await GlifiStudioExploratoryCompletion.multidimensionalScalingSearch(
                    [[0, 1], [1, 0]], dimensions: 1, starts: 1, seed: 0)
            } else {
                _ = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
                    [[0], [1]], width: 2, height: 1, seed: 0, topology: .hexagonal)
            }
        }
        do {
            try await task.value
            Issue.record("Cancellation was ignored")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.code == "operation.cancelled")
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        }
    }
}
