// SPDX-License-Identifier: BSD-3-Clause

import AppKit
import Foundation
import GlifiKit
import SwiftUI
import Testing

@MainActor
struct StudioWorkspaceTests {
    private final class BundleAnchor {}

    @Test("Aprire Studio durante un’altra operazione avvia la lettura appena il progetto è libero")
    func studyOpenedDuringAnOperationInitializesAfterItFinishes() async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudyStartup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = root.appending(path: "Studio.glifi")
        let session = try await GlifiStudioService().createProject(at: project)
        let source = root.appending(path: "fonte.txt")
        try Data("Un contenuto importante da studiare.".utf8).write(to: source)
        _ = try await session.importText(at: source, format: .plainText)
        await session.close()
        let home = StudioHomeModel()
        await home.openProject(at: project)
        try #require(home.snapshot != nil)
        let gate = AsyncStream<Void>.makeStream()
        let started = AsyncStream<Void>.makeStream()
        let operation = Task { @MainActor in
            await home.runAdvancedAnalysis { _ in
                started.continuation.yield(())
                for await _ in gate.stream { break }
            }
        }
        defer {
            gate.continuation.finish()
            started.continuation.finish()
            operation.cancel()
        }
        var starting = started.stream.makeAsyncIterator()
        _ = await starting.next()
        try #require(home.isBusy)
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: 1_100, height: 700),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(
            rootView: StudioStudyView(home: home, onImportSources: {}, onOpenProject: {}))
        window.contentView = host
        window.orderBack(nil)
        defer {
            window.contentView = nil
            window.close()
        }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        #expect(!home.study.hasLoaded)
        gate.continuation.finish()
        await operation.value
        for _ in 0..<150 {
            if home.study.hasLoaded, home.study.firstReading != nil, !home.isBusy { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(home.lastFailure == nil)
        #expect(home.study.hasLoaded)
        #expect(home.study.firstReading?.text == "Un contenuto importante da studiare.")
        #expect(!home.isBusy)
        // A later ordinary operation must not reload or replace the current reading.
        let navigation = home.study.firstReading?.navigationID
        await home.runAdvancedAnalysis { _ in }
        try await Task.sleep(for: .milliseconds(100))
        #expect(home.study.firstReading?.navigationID == navigation)
        await home.closeProject()
    }

    @Test(arguments: ["it_IT", "en_US"])
    func dynamicallyComposedLocalizationValuesResolveInTheSelectedLanguage(identifier: String)
        throws
    {
        let italian = identifier == "it_IT"
        let path = try #require(
            Bundle(for: BundleAnchor.self).path(
                forResource: italian ? "it" : "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let locale = Locale(identifier: identifier)
        let alternative = GlifiStudioStatisticsAlternative.twoSided
        let level = "interval"
        let alternativeLabel = String(
            localized: StudioLocalization.value("statistics.alternative.\(alternative.rawValue)"),
            bundle: bundle, locale: locale)
        let levelLabel = String(
            localized: StudioLocalization.value("statistics.level.\(level)"),
            bundle: bundle, locale: locale)
        #expect(alternativeLabel == (italian ? "Bilaterale" : "Two-sided"))
        #expect(levelLabel == (italian ? "Intervallo" : "Interval"))
        let exportFormats = [
            ("json", "JSON"), ("markdown", "Markdown"), ("csv", "CSV"), ("pdf", "PDF/A-2u"),
        ]
        for (format, expectedLabel) in exportFormats {
            #expect(
                String(
                    localized: StudioLocalization.value("export.format.\(format)"),
                    bundle: bundle, locale: locale) == expectedLabel)
        }
        #expect(
            String(localized: "statistics.table.count \(17)", bundle: bundle, locale: locale)
                == (italian ? "Righe corrispondenti: 17" : "Matching rows: 17"))
    }

    @Test(arguments: ["it_IT", "en_US"])
    func dynamicallyComposedKeysMatchNativeRenderingOfTheExpectedText(identifier: String)
        throws
    {
        let bundle = Bundle(for: BundleAnchor.self)
        let italian = identifier == "it_IT"
        let operation = GlifiStudioStatisticsOperation.welchT
        let alternative = GlifiStudioStatisticsAlternative.twoSided
        let operatorMethod = GlifiStudioCoreOperator.pca
        let table = "tokens"
        let validation = "supported"
        let level = "interval"
        let exportFormats = ["json", "markdown", "csv", "pdf"]
        let expected = [
            italian ? "Confrontare due medie · Welch" : "Compare two means · Welch",
            italian
                ? "Due righe, una per ciascuna serie. Nei metodi appaiati i valori nella stessa posizione costituiscono una coppia: lunghezze diverse o dati mancanti non vengono corretti."
                : "Two rows, one per series. For paired methods, values at the same position form a pair: unequal lengths and missing data are not corrected.",
            italian ? "Bilaterale" : "Two-sided",
            italian
                ? "Analisi delle componenti principali (PCA)"
                : "Principal component analysis (PCA)",
            italian ? "Token e annotazioni" : "Tokens and annotations",
            italian
                ? "Supportata nel contratto dichiarato" : "Supported within the stated contract",
            italian ? "Intervallo" : "Interval",
            italian ? "Righe corrispondenti: 17" : "Matching rows: 17",
            "JSON", "Markdown", "CSV", "PDF/A-2u",
        ]
        let content =
            [
                Text(
                    StudioLocalization.key("statistics.operation.\(operation.rawValue)"),
                    bundle: bundle
                ),
                Text(
                    StudioLocalization.key("statistics.input.\(operation.inputKind.rawValue)"),
                    bundle: bundle),
                Text(
                    StudioLocalization.key("statistics.alternative.\(alternative.rawValue)"),
                    bundle: bundle),
                Text(
                    StudioLocalization.key("operators.method.\(operatorMethod.rawValue)"),
                    bundle: bundle),
                Text(StudioLocalization.key("linguistic.table.\(table)"), bundle: bundle),
                Text(StudioLocalization.key("advanced.validation.\(validation)"), bundle: bundle),
                Text(StudioLocalization.key("statistics.level.\(level)"), bundle: bundle),
                // Ordinary localized message arguments remain interpolation, rather than key components.
                Text("statistics.table.count \(17)", bundle: bundle),
            ]
            + exportFormats.map { format in
                Text(StudioLocalization.key("export.format.\(format)"), bundle: bundle)
            }
        let locale = Locale(identifier: identifier)
        try #require(content.count == expected.count)
        for (text, expectedText) in zip(content, expected) {
            let observedSize = try fittingSize(of: text, locale: locale)
            let expectedSize = try fittingSize(of: Text(verbatim: expectedText), locale: locale)
            #expect(observedSize == expectedSize, Comment(rawValue: expectedText))
        }

        // These original constructors intentionally reproduce the interpolation defect.
        // Their fallback geometry must differ from the independently declared translations.
        let unbridgedOperation = Text(
            LocalizedStringKey("statistics.operation.\(operation.rawValue)"), bundle: bundle)
        let unbridgedAlternative = Text(
            LocalizedStringKey("statistics.alternative.\(alternative.rawValue)"), bundle: bundle)
        #expect(
            try fittingSize(of: unbridgedOperation, locale: locale)
                != fittingSize(of: Text(verbatim: expected[0]), locale: locale))
        #expect(
            try fittingSize(of: unbridgedAlternative, locale: locale)
                != fittingSize(of: Text(verbatim: expected[2]), locale: locale))
        for (format, expectedLabel) in zip(exportFormats, expected.suffix(exportFormats.count)) {
            let unbridgedFormat = Text("export.format.\(format)", bundle: bundle)
            #expect(
                try fittingSize(of: unbridgedFormat, locale: locale)
                    != fittingSize(of: Text(verbatim: expectedLabel), locale: locale))
        }
    }

    private func fittingSize(of text: Text, locale: Locale) throws -> NSSize {
        _ = NSApplication.shared
        let host = NSHostingView(
            rootView: text.font(.system(size: 17)).fixedSize()
                .environment(\.locale, locale))
        let size = host.fittingSize
        try #require(
            size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0)
        return size
    }

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
