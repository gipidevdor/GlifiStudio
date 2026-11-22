// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit
import Testing

@Test("Canonical request identity preserves exact Unicode source bytes and offsets")
func textAnalysisReauditUnicodeIdentity() async throws {
    var digests: [String] = []
    for text in ["é", "e\u{301}"] {
        let request = GlifiStudioTextAnalysisRequest.advanced(.linguistic(text: text))
        let result = try await GlifiStudioTextAnalytics.executeTextAnalysis(
            json: request.canonicalData())
        guard case let .advanced(.linguistic(annotation)) = result.payload else {
            Issue.record("Unexpected linguistic result family")
            continue
        }
        let token = try #require(annotation.tokens.first)
        #expect(annotation.text.utf8.elementsEqual(text.utf8))
        #expect(token.surface.utf8.elementsEqual(text.utf8))
        #expect(token.normalized == "é")
        #expect(token.startUTF8 == 0)
        #expect(token.endUTF8 == text.utf8.count)
        digests.append(result.requestDigest)
    }
    try #require(digests.count == 2)
    #expect(digests[0] != digests[1])
}
