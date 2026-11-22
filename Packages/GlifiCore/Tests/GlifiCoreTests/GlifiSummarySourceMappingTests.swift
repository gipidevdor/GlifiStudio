// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("Il riassunto mappa le frasi estratte sugli originali Markdown e UTF-8 con BOM")
func summarySourceMappingPreservesOriginalIntervals() async throws {
    let fixtures: [(GlifiTextFormat, String, String, [(Int, Int)], Bool)] = [
        (.plainText, "\u{FEFF}Città già qui.", "Città già qui.", [(3, 19)], true),
        (
            .markdown, "\u{FEFF}Una **città** è già qui.\n", "Una città è già qui.",
            [(3, 7), (9, 15), (17, 30)], true
        ),
        (.markdown, "Una città &amp; una fonte.", "Una città & una fonte.", [(0, 27)], false),
    ]
    for (format, original, expectedText, expectedIntervals, isExactText) in fixtures {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiSummaryMapping-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = try GlifiProjectPackage.create(at: root.appending(path: "Mapping.glifi"))
        let revision = try SourceRevisionID(
            canonicalValue: "source-revision:00000000-0000-0000-0000-000000000001")
        let imported = try GlifiTextImporter().importText(
            from: Data(original.utf8), format: format, sourceRevisionID: revision)
        _ = try await project.importText(imported)
        let engine = GlifiEngine()
        let result = try await engine.analyzeExtractiveSummary(
            in: project, sourceRevisionIDs: [revision])
        let resolved = try #require(
            try await engine.resolveSummarySentences(result.value, in: project).first)

        #expect(resolved.text == expectedText)
        #expect(resolved.sentence.range.start == 0)
        let expectedRanges = try expectedIntervals.map {
            try GlifiUTF8Range(start: $0.0, end: $0.1)
        }
        #expect(resolved.sourceRanges == expectedRanges)
        let originalFragments = resolved.sourceRanges.compactMap { $0.text(in: original) }.joined()
        if isExactText {
            #expect(originalFragments == expectedText)
        } else {
            // A decoded Markdown entity contributes its original spelling, not the extracted byte.
            #expect(originalFragments == original)
            #expect(originalFragments != expectedText)
        }
        #expect(resolved.sentence.range.text(in: original) != expectedText)

        let generation = await project.snapshot().generation
        let reused = try await engine.analyzeExtractiveSummary(
            in: project, sourceRevisionIDs: [revision])
        #expect(reused.artifactID == result.artifactID)
        #expect(await project.snapshot().generation == generation)
        #expect(
            try await engine.resolveSummarySentences(reused.value, in: project) == [resolved])

        let encoded = try JSONEncoder().encode(resolved)
        var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "sourceRanges")
        let decoded = try JSONDecoder().decode(
            GlifiResolvedSummarySentence.self,
            from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.text == resolved.text)
        #expect(decoded.sentence == resolved.sentence)
        #expect(decoded.sourceRanges.isEmpty)
        #expect(
            try JSONDecoder().decode(GlifiResolvedSummarySentence.self, from: encoded) == resolved)
    }
}
