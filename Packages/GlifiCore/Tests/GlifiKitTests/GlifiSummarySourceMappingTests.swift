// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@Test("GlifiKit distingue testo estratto e intervalli originali nel riassunto")
func summarySourceMappingCrossesTheKitBoundary() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitSummaryMapping-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "source.md")
    let original = "\u{FEFF}Una **città** è già qui.\n"
    try Data(original.utf8).write(to: source)
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "Kit.glifi"))
    let imported = try await session.importText(at: source, format: .markdown)
    let revision = try #require(imported.project.sources.first?.sourceRevisionID)
    let result = try await session.analyzeExtractiveSummary(sourceRevisionIDs: [revision])
    let selected = try #require(result.selected.first)
    let loaded = try await session.sourceText(sourceRevisionID: revision)

    #expect(loaded.text == original)
    #expect(selected.text == "Una città è già qui.")
    #expect(selected.sentence.startUTF8 == 0)
    #expect(selected.sourceRanges.map(\.start) == [3, 9, 17])
    #expect(selected.sourceRanges.map(\.end) == [7, 15, 30])
    let bytes = Array(loaded.text.utf8)
    let pieces = try selected.sourceRanges.map { range in
        try #require(String(bytes: bytes[range.start..<range.end], encoding: .utf8))
    }
    #expect(pieces.joined() == selected.text)
    let reused = try await session.analyzeExtractiveSummary(sourceRevisionIDs: [revision])
    #expect(reused.lineage.artifactID == result.lineage.artifactID)
    #expect(reused.selected == result.selected)

    let encoded = try JSONEncoder().encode(selected)
    var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    legacy.removeValue(forKey: "sourceRanges")
    let decoded = try JSONDecoder().decode(
        GlifiStudioSelectedSentence.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(decoded.text == selected.text)
    #expect(decoded.sentence == selected.sentence)
    #expect(decoded.sourceRanges.isEmpty)
    #expect(try JSONDecoder().decode(GlifiStudioSelectedSentence.self, from: encoded) == selected)
    await session.close()
}
