// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiKit

@Test("Advanced SOM rejects the cumulative fit and Ward workflow before iterative work")
func khRefinementStudioSOMWorkflowAdmission() async throws {
    // The old independent reservations admitted about 289M fit work and 216M
    // Ward work separately. Shared rows keep fixture setup small; this call is
    // added only after the cumulative production preflight has been installed.
    let matrix = [[Double]](repeating: [0], count: 240_000)
    do {
        _ = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
            matrix, width: 600, height: 1, seed: 0, epochs: 1, codebookClusterCount: 2)
        Issue.record("The complete SOM workflow exceeded its shared 500M budget")
    } catch {
        #expect(error.code == "exploratory.resource-limit")
        #expect(error.category == "insufficientResources")
        #expect(error.retainedState == "unchanged")
    }
}

@Test("The advanced SOM facade preserves the complete Gaussian update for remote units")
func khRefinementStudioBatchGaussianMapping() async throws {
    let result = try await GlifiStudioExploratoryCompletion.selfOrganizingMap(
        [[0], [1]], width: 8, height: 1, seed: 0, epochs: 1,
        initialRadius: 0.5, finalRadius: 0.5)
    #expect(abs(result.map.prototypes[6][0] / 2.7894680920908113e-10 - 1) < 2e-13)
    #expect(result.map.methodIdentifier == "SOM-batch-gaussian-rectangular-v1")
    #expect(result.uMatrix.count == 8)
    #expect(result.codebookClustering == nil)
}
