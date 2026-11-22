// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor struct StudioOperatorsTests {
    @Test func assessesAnExplicitHistoricalRevisionAndRetainsItsIdentityOnFailure() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiAgreementRevision-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Test.glifi"), needsPackageInitialization: true)
        let text = root.appending(path: "source.txt")
        try Data("Casa. Mare.".utf8).write(to: text)
        await model.importSources(at: [text])
        let source = try #require(model.snapshot?.sources.first?.sourceRevisionID)
        await model.loadCodingSource(source)
        let categories: [GlifiStudioCodebookCategory] = [
            .init(categoryID: "a", label: "Casa", definition: "Abitazione"),
            .init(categoryID: "b", label: "Mare", definition: "Paesaggio"),
        ]
        await model.registerCodebookRevision(categories, codebookID: "research")
        for (index, category) in categories.enumerated() {
            await model.resolvePassage(.sentences(first: index, last: index))
            for coder in ["first", "second"] {
                model.coderDraft = coder
                await model.codeResolvedPassage(categoryID: category.categoryID)
                #expect(model.lastFailure == nil)
            }
        }
        await model.registerCodebookRevision(categories, codebookID: "research")
        #expect(model.activeCodebook?.revision == 2)
        await model.assessAgreement(coders: ["first", "second"], revision: 1)
        #expect(model.lastFailure == nil)
        let result = try #require(model.storedAgreement)
        #expect(result.agreement.unitCount == 2)
        #expect(model.storedAgreementRevision == 1)
        #expect(model.storedAgreementCodebookID == "research")
        await model.assessAgreement(coders: ["first", "second"], revision: 3)
        #expect(model.lastFailure != nil)
        #expect(model.storedAgreement == result)
        #expect(model.storedAgreementRevision == 1)
    }

    @Test func recordsCompleteCodebooksMappingsAndCategoryMemosWithoutReplacingHistory()
        async throws
    {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiCodebooks-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "Test.glifi"), needsPackageInitialization: true)
        await model.registerCodebookRevision(
            [
                .init(
                    categoryID: "old", label: "Tema", definition: "Definizione",
                    instructions: "Istruzioni")
            ], codebookID: "research")
        #expect(model.lastFailure == nil)
        await model.registerCodebookRevision(
            [
                .init(
                    categoryID: "new", label: "Tema aggiornato",
                    definition: "Definizione aggiornata")
            ], codebookID: "research")
        await model.mapCategories(
            codebookID: "research", fromRevision: 1, toRevision: 2,
            mapping: .init(kind: "rename", fromCategoryIDs: ["old"], toCategoryIDs: ["new"]))
        #expect(model.lastFailure == nil)
        model.coderDraft = "reviewer"
        await model.attachNote(
            to: GlifiStudioMemoTarget.category(codebookID: "research", categoryID: "new"),
            text: "Nota sintetica")
        #expect(model.lastFailure == nil)
        let book = try #require(model.qualitativeState?.codebooks.first)
        #expect(book.revisions.count == 2)
        #expect(book.revisions.first?.first?.instructions == "Istruzioni")
        #expect(model.activeCodebook?.codebookID == "research")
        #expect(model.qualitativeState?.memos.first?.text == "Nota sintetica")
        await model.registerCodebookRevision(
            [
                .init(categoryID: "other", label: "Altro", definition: "Altro tema")
            ], codebookID: "second")
        #expect(model.qualitativeState?.codebooks.count == 2)
        #expect(model.activeCodebook?.codebookID == "second")
        model.selectedCodebookID = "research"
        #expect(model.activeCodebook?.revision == 2)
        await model.attachDocument(
            at: root.appending(path: "Next.glifi"), needsPackageInitialization: true)
        #expect(model.selectedCodebookID == nil)
        #expect(model.qualitativeState == nil)
    }

    @Test func retainsFrozenOutputAfterFailureAndClearsItOnReset() async throws {
        let model = StudioOperatorsModel()
        model.loadSyntheticExample()
        try await model.execute()
        let output = try #require(model.result)
        model.request.numbers = "invalid"
        await #expect(throws: GlifiStudioFailure.self) { try await model.execute() }
        #expect(model.result == output)
        #expect(model.result?.request != model.request.effective)
        model.reset()
        #expect(model.result == nil)
        #expect(model.request == GlifiStudioCoreOperatorRequest())
    }

    @Test func pagesCompleteOutputWithoutDuplicatingOrDroppingRows() async throws {
        let model = StudioOperatorsModel()
        model.request.operation = .transpose
        model.request.numbers = Array(1...125).map(String.init).joined(separator: " ")
        try await model.execute()
        #expect(model.pageCount == 3)
        var ids: [Int] = []
        for page in 0..<model.pageCount {
            model.showPage(page)
            ids += model.visibleRows.map(\.id)
        }
        #expect(ids == Array(0..<125))
        model.showPage(-1)
        model.showPage(3)
        #expect(model.page == 2)
    }

    @Test func everyCatalogEntryActivatesItsConcreteWorkbench() {
        let model = StudioHomeModel()
        let routes = StudioCoreMethodRoute.allCases
        #expect(Set(routes.map(\.id)).count == routes.count)
        for route in routes {
            switch route {
            case let .operators(method):
                #expect(route.activate(on: model) == .operators)
                #expect(model.operators.request.operation == method)
            case let .corpus(method):
                #expect(route.activate(on: model) == .corpusMethods)
                #expect(model.corpusMethods.tool == method)
            case let .statistics(method):
                #expect(route.activate(on: model) == .statistics)
                #expect(model.statistics.operation == method)
            case let .evaluation(method):
                #expect(route.activate(on: model) == .evaluation)
                #expect(model.evaluation.tool == method)
            }
            #expect(route.matches(route.rawName, locale: Locale(identifier: "it")))
        }
    }
}
