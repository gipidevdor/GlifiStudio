// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor struct StudioOperatorsTests {
    @Test(arguments: GlifiStudioCoreOperator.allCases)
    func everyNativeExampleRetainsEffectiveInputAndScientificStructure(
        operation: GlifiStudioCoreOperator
    ) async throws {
        let model = StudioOperatorsModel()
        model.request.operation = operation
        model.loadSyntheticExample()
        let submitted = model.request.effective
        try await model.execute()
        let result = try #require(model.result)
        #expect(result.request == submitted)
        #expect(result == (try await GlifiStudioCoreOperators.execute(submitted)))
        #expect(result.validationStatus == "candidate")
        #expect(
            result.tables.allSatisfy { table in
                table.rows.allSatisfy { $0.count == table.columns.count }
            })
        for index in result.tables.indices {
            model.selectedTable = index
            var visited: [Int] = []
            for page in 0..<model.pageCount {
                model.showPage(page)
                visited += model.visibleRows.map(\.id)
            }
            #expect(visited == Array(result.tables[index].rows.indices))
        }
        try verifyScientificStructure(result)
        model.request.numbers = "invalid new draft"
        model.request.nodes = "a different node"
        model.request.documents = "a different document"
        #expect(model.result == result)
        #expect(model.result?.request == submitted)
    }

    @Test func immediateResetRejectsPublicationAndAllowsAnUncancelledRetry() async throws {
        let model = StudioOperatorsModel()
        model.request.operation = .graphLayout
        model.loadSyntheticExample()
        try await model.execute()
        _ = try #require(model.graphPreview)
        var entered = false
        let execution = Task.immediate { @MainActor in
            entered = true
            try await model.execute()
        }
        #expect(entered && !execution.isCancelled)
        model.reset()
        do {
            try await execution.value
            Issue.record("An operator published after reset")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.operation == "analyze")
            #expect(failure.retryDisposition == "newRequest")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(!execution.isCancelled)
        #expect(model.result == nil && model.graphPreview == nil)
        #expect(model.visibleRows.isEmpty && model.page == 0 && model.selectedTable == 0)
        #expect(model.request == GlifiStudioCoreOperatorRequest())
        model.loadSyntheticExample()
        try await model.execute()
        let previous = try #require(model.result)
        let cancelled = Task.immediate { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await model.execute()
        }
        do {
            try await cancelled.value
            Issue.record("A pre-cancelled operator succeeded")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(model.result == previous)
    }

    @Test(arguments: [512, 513])
    func denseGraphPreviewKeepsEveryEdgeInTheCapturedTables(edgeCount: Int) async throws {
        let model = StudioOperatorsModel()
        model.request.operation = .graphLayout
        model.request.maximumIterations = 1
        let nodes = (0..<33).map { "node-\($0)" }
        model.request.nodes = nodes.joined(separator: "\n")
        var edges: [String] = []
        for first in nodes.indices {
            for second in nodes.indices where second > first {
                edges.append("\(nodes[first])\t\(nodes[second])\t1")
            }
        }
        model.request.edges = edges.prefix(edgeCount).joined(separator: "\n")
        try await model.execute()
        let result = try #require(model.result)
        let complete = try #require(result.tables.first { $0.titleKey == "operators.layout-edges" })
        #expect(complete.rows.count == edgeCount)
        #expect(result.request.edges.split(separator: "\n").count == edgeCount)
        if edgeCount == 512 {
            let preview = try #require(model.graphPreview)
            #expect(preview.edges.count == 512)
            #expect(preview.points.map(\.id) == nodes)
        } else {
            #expect(model.graphPreview == nil)
        }
        model.selectedTable = try #require(
            result.tables.firstIndex { $0.titleKey == complete.titleKey })
        var visited: [Int] = []
        for page in 0..<model.pageCount {
            model.showPage(page)
            visited += model.visibleRows.map(\.id)
        }
        #expect(visited == Array(0..<edgeCount))
        #expect(model.result == result)
    }

    private func verifyScientificStructure(_ result: GlifiStudioCoreOperatorResult) throws {
        func values(_ title: String) throws -> [Double] {
            let table = try #require(result.tables.first { $0.titleKey == title })
            return try table.rows.map { row in
                let cell = try #require(row.last)
                switch cell {
                case let .number(value): return value
                case let .integer(value): return Double(value)
                case .text, .localized, .nonFinite:
                    Issue.record("Expected a finite scientific quantity in \(title)")
                    return .nan
                }
            }
        }
        let operation = result.request.operation
        if operation.family == "matrix" {
            let numbers = result.tables.flatMap(\.rows).flatMap { $0 }.compactMap {
                cell -> Double? in
                if case let .number(value) = cell { return value }
                return nil
            }
            #expect(numbers.allSatisfy { $0.isFinite })
            if operation == .svd || operation == .truncatedSVD {
                let singular = try values("operators.singular-values")
                #expect(singular.allSatisfy { $0 >= 0 })
                #expect(zip(singular, singular.dropFirst()).allSatisfy { $0 >= $1 })
                #expect(abs(singular.reduce(0) { $0 + $1 * $1 } - 92) < 1e-8)
            }
            if operation == .pca {
                #expect(abs(try values("operators.variance-shares").reduce(0, +) - 1) < 1e-12)
            }
            if operation == .nmf {
                #expect(try values("operators.matrix-w").allSatisfy { $0 >= 0 })
                #expect(try values("operators.matrix-h").allSatisfy { $0 >= 0 })
            }
            if operation == .transformBinary {
                #expect(try values("operators.matrix") == Array(repeating: 1, count: 8))
            }
            if operation == .transpose {
                #expect(try values("operators.matrix") == [1, 2, 4, 5, 2, 1, 5, 4])
            }
            if operation == .silhouette {
                #expect(try values("operators.widths").allSatisfy { (-1...1).contains($0) })
            }
        } else if operation.family == "similarity" {
            if operation == .lidstone {
                let probabilities = try values("operators.probabilities")
                #expect(probabilities.count == 3)
                #expect(probabilities.allSatisfy { (0...1).contains($0) })
                #expect(abs(probabilities.reduce(0, +) - 1) < 1e-12)
            } else {
                let scalar = try #require(try values("operators.diagnostics").first)
                #expect(scalar.isFinite && scalar >= 0)
                if operation == .jaccard { #expect(scalar == 0.5) }
                if operation == .dice || operation == .simpson {
                    #expect(abs(scalar - 2.0 / 3) < 1e-12)
                }
            }
        } else if operation.family == "graph" {
            if operation == .pageRank {
                let scores = try values("operators.scores")
                #expect(scores.count == 3)
                #expect(scores.allSatisfy { $0 >= 0 })
                #expect(abs(scores.reduce(0, +) - 1) < 1e-12)
            }
            if operation == .weakComponents || operation == .strongComponents {
                let components = try values("operators.components")
                #expect(components.count == 3 && Set(components).count == 1)
            }
            if operation == .graphLayout {
                let positions = try #require(
                    result.tables.first { $0.titleKey == "operators.positions" })
                #expect(
                    positions.rows.compactMap { $0.first } == [.text("A"), .text("B"), .text("C")])
            }
        } else if operation.family == "lexical" {
            let ranks = try #require(
                result.tables.first { $0.titleKey == "operators.rank-frequency" })
            #expect(ranks.rows.count == 4)
            let counts = ranks.rows.compactMap { row -> Int? in
                guard row.count == 3, case let .integer(count) = row[1] else { return nil }
                return count
            }
            #expect(counts.reduce(0, +) == 9)
            let frequencies = try values("operators.rank-frequency")
            #expect(abs(frequencies.reduce(0, +) - 1) < 1e-12)
            let growth = try #require(result.tables.first { $0.titleKey == "operators.growth" })
            #expect(growth.rows.compactMap { $0.first } == [1, 3, 6, 9].map { .integer($0) })
        } else {
            Issue.record("An operator family has no scientific scenario assertion")
        }
    }

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

    @Test func graphPreviewPreservesNodeIdentitiesAndResetsWithTheOutput() async throws {
        let model = StudioOperatorsModel()
        model.request.operation = .graphLayout
        model.loadSyntheticExample()
        try await model.execute()
        let preview = try #require(model.graphPreview)
        #expect(preview.points.map(\.id) == ["A", "B", "C"])
        #expect(preview.edges.count == 3)
        #expect(
            preview.points.allSatisfy {
                preview.domain.contains($0.x) && preview.domain.contains($0.y)
            })
        model.reset()
        #expect(model.graphPreview == nil)
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
            case let .advanced(method):
                #expect(route.activate(on: model) == .advancedAnalysis)
                #expect(model.advancedAnalysis.tool == method)
            case let .linguistics(method):
                #expect(route.activate(on: model) == .linguistics)
                #expect(model.linguistics.tool == method)
            case let .community(method):
                #expect(route.activate(on: model) == .operators)
                #expect(model.operators.request.operation == .communities)
                #expect(model.operators.request.communityMethod == method.rawValue)
            case let .layout(method):
                #expect(route.activate(on: model) == .operators)
                #expect(model.operators.request.layoutMethod == method.rawValue)
            case let .mdsMethod(method):
                #expect(route.activate(on: model) == .advancedAnalysis)
                #expect(model.advancedAnalysis.tool == .mds)
                #expect(model.advancedAnalysis.mdsMethod == method)
            case let .evaluation(method):
                #expect(route.activate(on: model) == .evaluation)
                #expect(model.evaluation.tool == method)
            }
            #expect(route.matches(route.rawName, locale: Locale(identifier: "it")))
        }
    }
}
