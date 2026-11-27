// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioWorkspaceTests {
    @Test func submittingAnAmbiguousToolSearchKeepsTheCatalogOpen() {
        let method = StudioCoreMethodRoute.corpus(.pca)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [.themes, .corpusMethods], coreMethods: [method]) == nil)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [.themes], coreMethods: [method, .corpus(.lsa)]) == nil)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [.themes], coreMethods: [method]) == nil)
    }

    @Test func submittingAUniqueOrEmptyToolSearchUsesOnlyTheVisibleResults() {
        let method = StudioCoreMethodRoute.corpus(.pca)
        #expect(StudioToolCatalogDestination.submission(tools: [], coreMethods: []) == nil)
        #expect(
            StudioToolCatalogDestination.submission(tools: [.query], coreMethods: [])
                == .tool(.query))
        #expect(
            StudioToolCatalogDestination.submission(tools: [], coreMethods: [method])
                == .core(method))
        #expect(
            StudioToolCatalogDestination.submission(tools: [.query, .coding], coreMethods: [])
                == nil)
        #expect(
            StudioToolCatalogDestination.submission(
                tools: [], coreMethods: [method, .corpus(.lsa)]) == nil)
    }

    @Test func methodSearchDoesNotPreferItsSingleCoreResultOverMatchingTools() {
        let locale = Locale(identifier: "it_IT")
        let tools = StudioToolDestination.allCases.filter { $0.matches("PageRank", locale: locale) }
        let methods = StudioCoreMethodRoute.allCases.filter {
            $0.matches("PageRank", locale: locale)
        }
        #expect(tools == [.operators])
        #expect(methods == [.operators(.pageRank)])
        #expect(StudioToolCatalogDestination.submission(tools: tools, coreMethods: methods) == nil)
    }

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
