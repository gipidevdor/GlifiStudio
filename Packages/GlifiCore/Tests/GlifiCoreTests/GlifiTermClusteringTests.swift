// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("HAC raggruppa i profili dei termini con geometria, identità e fonti corrette")
func termClusteringUsesUnitSumTermProfiles() throws {
    let rows = [[8, 4, 0, 0], [2, 1, 0, 0], [0, 0, 3, 9]]
    let terms = ["aa", "bb", "cc", "dd"]
    let sources = try rows.enumerated().map { index, row in
        let text = zip(terms, row).flatMap { term, count in
            Array(repeating: term, count: count)
        }.joined(separator: " ")
        return try GlifiTextImporter().importText(
            from: Data(text.utf8), format: .plainText,
            sourceRevisionID: SourceRevisionID(
                uuid: #require(UUID(uuidString: "00000000-0000-0000-0000-00000000009\(index)"))))
    }
    let corpus = try GlifiCorpusAnalyzer().analyze(sources)
    for linkage in [GlifiLinkage.single, .complete, .average, .ward] {
        let method = GlifiMultivariateMethod.hierarchicalTerms(linkage: linkage, clusterCount: 2)
        let result = try GlifiCorpusMultivariateAnalyzer().analyze(corpus, method: method)
        #expect(result.representationIdentifier == "term-document-relative-frequency-v1")
        #expect(result.terms == terms)
        #expect(result.clusterAssignments == [0, 0, 1, 1])
        #expect(result.averageSilhouette == 1)
        #expect(
            result.termSourceRevisionIDs == [
                Array(result.sourceRevisionIDs.prefix(2)),
                Array(result.sourceRevisionIDs.prefix(2)),
                [result.sourceRevisionIDs[2]], [result.sourceRevisionIDs[2]],
            ])
        let tree = try #require(result.hierarchical)
        #expect(tree.merges.map(\.first) == [0, 2, 4])
        #expect(tree.merges.map(\.second) == [1, 3, 5])
        #expect(tree.merges.prefix(2).allSatisfy { $0.height == 0 })
        // Two duplicate profiles (0.8, 0.2, 0), two (0, 0, 1).
        let expectedHeight = (linkage == .ward ? 3.36 : 1.68).squareRoot()
        #expect(abs(try #require(tree.merges.last).height - expectedHeight) < 1e-12)
        #expect(method.parameters["clusterUnit"] == .text("terms"))
        #expect(
            try JSONDecoder().decode(
                GlifiCorpusMultivariateAnalysis.self, from: JSONEncoder().encode(result)
            )
            .termSourceRevisionIDs == result.termSourceRevisionIDs)
    }
    #expect(
        GlifiMultivariateMethod.hierarchical(linkage: .ward, clusterCount: 2)
            .parameters["clusterUnit"] == nil)
    #expect(throws: GlifiFailure.self) {
        try GlifiCorpusMultivariateAnalyzer().analyze(
            corpus, method: .hierarchicalTerms(linkage: .ward, clusterCount: 5))
    }
}
