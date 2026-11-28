// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioWorkspaceTests {
    @Test func discoversMethodsByMultipleWordsWithoutChangingTheQueryLanguage() {
        let locale = Locale(identifier: "it_IT")
        let matches = StudioToolDestination.allCases.filter {
            $0.matches("  ZIPF   Heaps  ", locale: locale)
        }
        #expect(matches == [.lexicalLaws, .operators])
        #expect(StudioToolDestination.query.matches("kwic", locale: locale))
        #expect(StudioToolDestination.classifierValidation.matches("naive k-fold", locale: locale))
        #expect(!StudioToolDestination.query.matches("BM25", locale: locale))
    }

    @Test func browsingAnotherSourceKeepsTheConcordanceAndItsSelection() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiWorkspaceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Workspace.glifi"), needsPackageInitialization: true)
        let first = root.appending(path: "first.txt")
        let second = root.appending(path: "second.md")
        try Data("La casa conserva le parole.".utf8).write(to: first)
        try Data("# Il mare\nUna fonte diversa.".utf8).write(to: second)
        await model.importSources(at: [first, second])
        model.queryDraft = "normalized:casa"
        await model.runQuery()
        let query = try #require(model.queryResult)
        let match = try #require(model.selectedQueryMatch)
        let original = try #require(model.sourceText)
        let other = try #require(
            model.snapshot?.sources.first { $0.sourceRevisionID != match.sourceRevisionID })

        await model.browseSource(other.sourceRevisionID)

        #expect(model.lastFailure == nil)
        #expect(model.browsedSourceText?.sourceRevisionID == other.sourceRevisionID)
        #expect(model.browsedSourceText?.text.contains("mare") == true)
        #expect(model.queryResult == query)
        #expect(model.selectedQueryMatchID == match.id)
        #expect(model.sourceText == original)

        await model.planInvestigation()
        let previousPlan = try #require(model.planResult)
        #expect(!model.isPlanDraftChanged)
        model.selectedIntent = .identifyThemes
        #expect(model.isPlanDraftChanged)
        #expect(model.planResult == previousPlan)

        await model.attachDocument(
            at: root.appending(path: "Another.glifi"), needsPackageInitialization: true)
        #expect(model.lastFailure == nil)
        #expect(model.browsedSourceText == nil)
        #expect(model.queryResult == nil)
    }
}

@MainActor struct StudioThematicWorkflowTests {
    @Test func everyAnalyticalFamilyHasAnExecutableRouteAndLocalizedRole() throws {
        let routes = StudioCoreMethodRoute.allCases
        #expect(Set(routes.map(\.id)).count == routes.count)
        #expect(
            Set(
                routes.compactMap { route -> StudioAdvancedTool? in
                    if case let .advanced(value) = route { return value }
                    return nil
                }) == Set(StudioAdvancedTool.allCases))
        #expect(
            Set(
                routes.compactMap { route -> StudioKHMatrixTool? in
                    if case let .khMatrix(value) = route { return value }
                    return nil
                }) == Set(StudioKHMatrixTool.allCases))
        #expect(
            Set(
                routes.compactMap { route -> StudioKHLanguageTool? in
                    if case let .khLanguage(value) = route { return value }
                    return nil
                }) == Set(StudioKHLanguageTool.allCases))
        let catalogURL = URL(filePath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Shared/Resources/Localizable.xcstrings")
        let catalog = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        for route in routes {
            for key in [
                route.titleKey, route.purposeKey, route.theme.titleKey,
                route.theme.descriptionKey,
            ] {
                let localizations = try #require(
                    strings[key]?["localizations"] as? [String: Any],
                    "Missing context for \(route.id): \(key)")
                for language in ["it", "en"] {
                    let localized = try #require(localizations[language] as? [String: Any])
                    let unit = try #require(localized["stringUnit"] as? [String: Any])
                    let text = try #require(unit["value"] as? String)
                    #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    #expect(text != key)
                }
            }
        }
        #expect(Set(routes.map(\.theme)) == Set(StudioAnalysisTheme.allCases))
        #expect(StudioCoreMethodRoute.corpus(.hierarchical).theme == .structure)
        #expect(StudioCoreMethodRoute.operators(.pageRank).theme == .relationships)
        #expect(StudioCoreMethodRoute.statistics(.cohenKappa).theme == .coding)
        #expect(StudioCoreMethodRoute.evaluation(.lemmas).theme == .validation)
    }
}
