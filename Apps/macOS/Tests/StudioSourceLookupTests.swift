// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioSourceLookupTests {
    @Test func preservesFirstPositionsAndMissingIdentitiesAcrossRepeatedLookups() throws {
        let a = try makeSource(revisionID: "revision-A", sourceID: "source-A")
        let b = try makeSource(revisionID: "revision-B", sourceID: "source-B")
        let duplicateA = try makeSource(revisionID: "revision-A", sourceID: "duplicate-A")
        let c = try makeSource(revisionID: "revision-C", sourceID: "source-C")
        let d = try makeSource(revisionID: "revision-D", sourceID: "source-D")
        let lookup = StudioSourceLookup(sources: [a, b, duplicateA, c])
        let queries = ["revision-A", "revision-B", "revision-C", "unknown"]
        let expected: [Int?] = [0, 1, 3, nil]

        #expect(queries.map { lookup.index(of: $0) } == expected)
        for _ in 0..<1_000 {
            #expect(queries.map { lookup.index(of: $0) } == expected)
        }

        let earlyHits = StudioSourceLookup(sources: [a, b, duplicateA, c])
        for _ in 0..<1_000 {
            #expect(earlyHits.index(of: "revision-A") == 0)
        }
        #expect(earlyHits.index(of: "revision-C") == 3)
        #expect(earlyHits.index(of: "unknown") == nil)

        let reordered = StudioSourceLookup(sources: [c, b, a, duplicateA])
        let reorderedExpected: [Int?] = [2, 1, 0, nil]
        for _ in 0..<1_000 {
            #expect(queries.map { reordered.index(of: $0) } == reorderedExpected)
        }
        #expect(queries.map { lookup.index(of: $0) } == expected)

        let replaced = StudioSourceLookup(sources: [d, b, c])
        #expect(replaced.index(of: "revision-A") == nil)
        #expect(replaced.index(of: "revision-D") == 0)
        #expect(replaced.index(of: "revision-B") == 1)

        let empty = StudioSourceLookup(sources: [])
        for _ in 0..<1_000 {
            #expect(empty.index(of: "revision-A") == nil)
        }
    }

    private func makeSource(revisionID: String, sourceID: String) throws -> GlifiStudioProjectSource
    {
        let object: [String: Any] = [
            "sourceID": sourceID,
            "sourceRevisionID": revisionID,
            "format": "plainText",
            "contentDigest": "sha256:" + String(repeating: "0", count: 64),
            "byteCount": 1,
        ]
        return try JSONDecoder().decode(
            GlifiStudioProjectSource.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }
}
