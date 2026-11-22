// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioLinguisticTests {
    @Test(arguments: StudioLinguisticTool.allCases)
    func eachToolUsesTheCanonicalTransportWithoutAProject(tool: StudioLinguisticTool) async throws {
        let home = StudioHomeModel()
        let model = home.linguistics
        model.tool = tool
        model.loadSyntheticExample()
        await home.runCoreAnalysis { try await model.execute(locale: .init(identifier: "it_IT")) }
        #expect(home.lastFailure == nil)
        #expect(home.snapshot == nil)
        let output = try #require(model.output)
        #expect(output.input.tool == tool)
        #expect(
            try GlifiStudioTextAnalysisRequest.decode(output.canonicalRequest) == output.request)
        let reference = try await GlifiStudioTextAnalytics.executeTextAnalysis(output.request)
        #expect(reference.requestDigest == output.requestDigest)
        #expect(reference.methodIdentifier == output.methodIdentifier)
        #expect(reference.validationStatus == output.validationStatus)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        #expect(try encoder.encode(reference) == output.encodedResult)
        #expect(
            output.tables.allSatisfy { table in
                table.rows.allSatisfy { $0.values.count == table.columns.count }
            })
        #expect(model.visibleRows.count <= StudioLinguisticModel.pageSize)
        #expect(!model.isDraftChanged)
        model.includesPartOfSpeech.toggle()
        #expect(model.isDraftChanged)
        #expect(model.output?.id == output.id)
    }

    @Test func annotationPreservesUnicodeOffsetsStatesAndNativeStems() async throws {
        let model = StudioLinguisticModel()
        model.text = "Citta\u{0300}, città e 👩‍🔬. Mangiando mele."
        model.base = .italianSnowballStem
        try await model.execute(locale: .init(identifier: "it"))
        let output = try #require(model.output)
        guard case let .annotation(value) = output.payload else {
            Issue.record("Expected token annotations")
            return
        }
        #expect(
            value
                == (try await GlifiStudioLinguisticPipeline.annotate(
                    model.text, options: .init(base: .italianSnowballStem))))
        let bytes = Array(model.text.utf8)
        for token in value.tokens {
            #expect(
                String(decoding: bytes[token.startUTF8..<token.endUTF8], as: UTF8.self)
                    == token.surface)
            #expect(token.lemma == nil && token.lemmaState == .notRequested)
            #expect(token.partOfSpeech == nil && token.partOfSpeechState == .notRequested)
        }
        #expect(value.provenance.stemmingIdentifier == "Snowball-Italian-3.1.0")
        #expect(value.provenance.modelVersion == nil)
        model.text = "A new draft"
        #expect(model.isDraftChanged)
        #expect(model.output?.id == output.id)
        model.text = output.input.text
        #expect(!model.isDraftChanged)
    }

    @Test func codingUsesExplicitVariablesAndPreservesCallerIdentitiesAndEvidence() async throws {
        let model = StudioLinguisticModel()
        model.tool = .coding
        model.units = [
            .init(
                identifier: "linguistic.state.unknown", text: "casa città",
                variables: [.init(key: "gruppo", value: "A")]),
            .init(
                identifier: "true", text: "casa mare", variables: [.init(key: "gruppo", value: "B")]
            ),
        ]
        model.rules = "*Selezione\n<>gruppo-->A & casa"
        try await model.execute(locale: .init(identifier: "it"))
        let output = try #require(model.output)
        guard case let .coding(value) = output.payload else {
            Issue.record("Expected annotated coding")
            return
        }
        #expect(value.matrix.documentIDs == ["linguistic.state.unknown", "true"])
        #expect(value.matrix.values == [[1], [0]])
        #expect(value.matrix.evidence[0][0].contains { $0.start == 0 && $0.end == 4 })
        #expect(value.provenanceByUnit.count == model.units.count)
        let firstCell = try #require(output.tables.first?.rows.first?.values.first)
        guard case let .text(identity) = firstCell else {
            Issue.record("Caller identity was converted to a semantic label")
            return
        }
        #expect(identity == "linguistic.state.unknown")
        model.units[0].variables.append(.init(key: "gruppo", value: "B"))
        await #expect(throws: GlifiStudioFailure.self) {
            try await model.execute(locale: .init(identifier: "it"))
        }
        #expect(model.output?.id == output.id)
        #expect(model.output?.input == output.input)
    }

    @Test func installedAppleServicesRemainExplicitAndUnavailableRequestsFailWithoutFallback()
        async throws
    {
        let available = try await GlifiStudioLinguisticPipeline.availability()
        let model = StudioLinguisticModel()
        model.text = "Le ragazze mangiavano mele."
        model.base = .appleLemma
        model.includesPartOfSpeech = true
        if available.hasLemma && available.hasPartOfSpeech {
            try await model.execute(locale: .init(identifier: "it"))
            let output = try #require(model.output)
            guard case let .annotation(value) = output.payload else {
                Issue.record("Expected Apple annotations")
                return
            }
            #expect(value.provenance.base == .appleLemma)
            #expect(value.provenance.includesPartOfSpeech)
            #expect(value.provenance.modelVersion == nil)
            #expect(
                value.tokens.allSatisfy {
                    $0.lemmaState != .notRequested && $0.partOfSpeechState != .notRequested
                })
        } else {
            await #expect(throws: GlifiStudioFailure.self) {
                try await model.execute(locale: .init(identifier: "it"))
            }
            #expect(model.output == nil)
        }
        model.base = .normalizedSurface
        model.includesPartOfSpeech = false
        try await model.execute(locale: .init(identifier: "it"))
        let previous = try #require(model.output)
        model.languageTag = "fr"
        do {
            try await model.execute(locale: .init(identifier: "it"))
            Issue.record("Unsupported language was accepted")
        } catch let failure {
            #expect(failure.category == "invalidInput")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(model.output?.id == previous.id)
    }

    @Test func paginationVisitsAllTokensAndResetPreventsLatePublication() async throws {
        let model = StudioLinguisticModel()
        model.text = Array(repeating: "casa", count: 125).joined(separator: " ")
        try await model.execute(locale: .init(identifier: "it"))
        let output = try #require(model.output)
        #expect(model.pageCount == 3)
        var visited: [Int] = []
        for page in 0..<model.pageCount {
            model.showPage(page)
            visited += model.visibleRows.map(\.id)
        }
        #expect(visited == Array(0..<125))
        model.showPage(-1)
        model.showPage(3)
        #expect(model.page == 2)
        #expect(model.output?.id == output.id)
        model.text = Array(repeating: "città", count: 20_000).joined(separator: " ")
        let execution = Task.immediate { @MainActor in
            try await model.execute(locale: .init(identifier: "it"))
        }
        model.reset()
        do {
            try await execution.value
            Issue.record("An execution published after reset")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(model.output == nil)
        #expect(model.text.isEmpty && model.units.isEmpty)
        #expect(model.visibleRows.isEmpty && model.page == 0)
        model.text = "casa"
        let cancelled = Task.immediate { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await model.execute(locale: .init(identifier: "it"))
        }
        do {
            try await cancelled.value
            Issue.record("Cancelled execution succeeded")
        } catch let failure as GlifiStudioFailure { #expect(failure.category == "cancelled") }
        #expect(model.output == nil)
    }

    @Test func projectCopiesRetainTheirOriginAndChangingProjectsClearsTheWorkbench() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiLinguistic-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = StudioHomeModel()
        await home.attachDocument(
            at: root.appending(path: "First.glifi"), needsPackageInitialization: true)
        let text = root.appending(path: "input.md")
        try Data("# Città\nLa casa conserva parole.".utf8).write(to: text)
        await home.importSources(at: [text])
        #expect(home.lastFailure == nil)
        let ids = try #require(home.snapshot?.sources.map(\.sourceRevisionID))
        let model = home.linguistics
        model.tool = .coding
        await home.runAdvancedAnalysis { session in
            try await model.loadProjectInput(session: session, ids: ids)
        }
        #expect(home.lastFailure == nil)
        let origin = try #require(model.origin)
        #expect(origin.sourceRevisionIDs == ids.sorted())
        #expect(origin.contentDigests.count == ids.count)
        #expect(model.units.map(\.identifier) == ids.sorted())
        #expect(!model.isModifiedProjectCopy)
        model.units[0].text += " mare"
        #expect(model.isModifiedProjectCopy)
        model.rules = "*Casa\ncasa"
        await home.runCoreAnalysis { try await model.execute(locale: .init(identifier: "it")) }
        #expect(home.lastFailure == nil)
        #expect(model.output?.input.origin == origin)
        #expect(model.output?.input.isModifiedProjectCopy == true)
        await home.attachDocument(
            at: root.appending(path: "Next.glifi"), needsPackageInitialization: true)
        #expect(home.lastFailure == nil)
        #expect(model.output == nil && model.origin == nil)
        #expect(model.units.isEmpty && model.rules.isEmpty && model.text.isEmpty)
    }
}
