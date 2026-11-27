// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Synchronization
import Testing

@testable import GlifiCore

@Suite("Corpus cache budgets")
struct GlifiCorpusCacheBudgetTests {
    @Test("Direct corpus reuse retains each current budget", arguments: CorpusCacheBudget.allCases)
    func directCorpusRetainsCurrentBudget(_ budget: CorpusCacheBudget) async throws {
        let root = try corpusCacheBudgetRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (project, _) = try await corpusCacheBudgetProject(in: root)
        let tokenizer = CorpusCacheBudgetTokenizer()
        let engine = GlifiEngine(tokenizer: tokenizer)
        let restrictive = try budget.restrictiveOptions()
        let coldSnapshot = await project.snapshot()

        try await expectCorpusCacheBudgetFailure(budget) {
            _ = try await engine.analyzeCorpus(in: project, options: restrictive)
        }
        #expect(await project.snapshot() == coldSnapshot)

        let initial = try await engine.analyzeCorpus(
            in: project, options: corpusCacheBudgetOptions())
        #expect(initial.analysis.typeCount == 3)
        #expect(initial.analysis.ngrams.count == 3)
        #expect(initial.analysis.matrix.cells.count == 4)
        let warmedSnapshot = await project.snapshot()
        let tokenizationCount = tokenizer.invocationCount

        try await expectCorpusCacheBudgetFailure(budget) {
            _ = try await engine.analyzeCorpus(in: project, options: restrictive)
        }

        #expect(await project.snapshot() == warmedSnapshot)
        #expect(tokenizer.invocationCount == tokenizationCount)
    }

    @Test("Derived corpus groups retain each current budget", arguments: CorpusCacheBudget.allCases)
    func derivedCorpusRetainsCurrentBudget(_ budget: CorpusCacheBudget) async throws {
        let root = try corpusCacheBudgetRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (project, revisions) = try await corpusCacheBudgetProject(in: root)
        let tokenizer = CorpusCacheBudgetTokenizer()
        let engine = GlifiEngine(tokenizer: tokenizer)
        let restrictive = try budget.restrictiveOptions()
        let coldSnapshot = await project.snapshot()

        try await expectCorpusCacheBudgetFailure(budget) {
            _ = try await engine.analyzeAssociation(
                in: project, sourceRevisionIDs: revisions, corpusOptions: restrictive)
        }
        #expect(await project.snapshot() == coldSnapshot)

        _ = try await engine.analyzeAssociation(
            in: project, sourceRevisionIDs: revisions,
            corpusOptions: corpusCacheBudgetOptions())
        let warmedSnapshot = await project.snapshot()
        let tokenizationCount = tokenizer.invocationCount

        try await expectCorpusCacheBudgetFailure(budget) {
            _ = try await engine.analyzeAssociation(
                in: project, sourceRevisionIDs: revisions, corpusOptions: restrictive)
        }

        #expect(await project.snapshot() == warmedSnapshot)
        #expect(tokenizer.invocationCount == tokenizationCount)
    }

    @Test("Exact and larger budgets reuse the same scientific nodes after reopening")
    func sufficientBudgetsPreserveReuseAfterReopening() async throws {
        let root = try corpusCacheBudgetRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let (project, revisions) = try await corpusCacheBudgetProject(in: root)
        let engine = GlifiEngine()
        let original = try await engine.analyzeCorpus(
            in: project, options: corpusCacheBudgetOptions())
        let derived = try await engine.analyzeAssociation(
            in: project, sourceRevisionIDs: revisions,
            corpusOptions: corpusCacheBudgetOptions())
        let before = await project.snapshot()
        let reopened = try GlifiProjectPackage.open(at: root.appending(path: "Corpus.glifi"))
        let tokenizer = CorpusCacheBudgetTokenizer()
        let reopenedEngine = GlifiEngine(tokenizer: tokenizer)

        for limit in [1, 10] {
            let options = try corpusCacheBudgetOptions(
                vocabulary: 3 * limit, ngrams: 3 * limit, cells: 4 * limit)
            let reused = try await reopenedEngine.analyzeCorpus(in: reopened, options: options)
            let reusedDerived = try await reopenedEngine.analyzeAssociation(
                in: reopened, sourceRevisionIDs: revisions, corpusOptions: options)

            #expect(reused.artifactID == original.artifactID)
            #expect(reused.analysisNodeID == original.analysisNodeID)
            #expect(reused.analysis == original.analysis)
            #expect(reusedDerived.artifactID == derived.artifactID)
            #expect(reusedDerived.analysisNodeID == derived.analysisNodeID)
            #expect(reusedDerived.value == derived.value)
            #expect(await reopened.snapshot() == before)
        }
        #expect(tokenizer.invocationCount == 0)
    }

    @Test("Zero cardinalities remain valid with zero budgets on cold and warm paths")
    func emptyLexiconAllowsZeroBudgets() async throws {
        let root = try corpusCacheBudgetRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let project = try GlifiProjectPackage.create(at: root.appending(path: "Empty.glifi"))
        _ = try await project.importText(
            GlifiTextImporter().importText(from: Data(), format: .plainText))
        let tokenizer = CorpusCacheBudgetTokenizer()
        let engine = GlifiEngine(tokenizer: tokenizer)
        let options = try corpusCacheBudgetOptions(vocabulary: 0, ngrams: 0, cells: 0)

        let original = try await engine.analyzeCorpus(in: project, options: options)
        let before = await project.snapshot()
        let tokenizationCount = tokenizer.invocationCount
        let reused = try await engine.analyzeCorpus(in: project, options: options)

        #expect(reused.artifactID == original.artifactID)
        #expect(reused.analysis.typeCount == 0)
        #expect(reused.analysis.ngrams.isEmpty)
        #expect(reused.analysis.matrix.cells.isEmpty)
        #expect(await project.snapshot() == before)
        #expect(tokenizer.invocationCount == tokenizationCount)
    }
}

enum CorpusCacheBudget: CaseIterable, Sendable {
    case vocabulary, ngrams, cells

    var failureCode: String {
        switch self {
        case .vocabulary: "analysis.vocabulary-limit-exceeded"
        case .ngrams: "analysis.ngram-limit-exceeded"
        case .cells: "analysis.matrix-limit-exceeded"
        }
    }

    func restrictiveOptions() throws -> GlifiCorpusAnalysisOptions {
        try corpusCacheBudgetOptions(
            vocabulary: self == .vocabulary ? 2 : 10,
            ngrams: self == .ngrams ? 2 : 10,
            cells: self == .cells ? 3 : 10)
    }
}

private func expectCorpusCacheBudgetFailure(
    _ budget: CorpusCacheBudget, operation: () async throws -> Void
) async throws {
    do {
        try await operation()
        Issue.record("The current corpus budget must apply independently of cache history.")
    } catch let failure as GlifiFailure {
        #expect(failure.code == budget.failureCode)
        #expect(failure.category == .insufficientResources)
        #expect(failure.operation == .analyze)
        #expect(failure.retryDisposition == .afterConditionsChange)
        #expect(failure.retainedState == .lastCommittedGeneration)
    }
}

private func corpusCacheBudgetOptions(
    vocabulary: Int = 10, ngrams: Int = 10, cells: Int = 10
) throws -> GlifiCorpusAnalysisOptions {
    try GlifiCorpusAnalysisOptions(
        diversityWindowSize: 2, ngramSizes: [2], maximumDocumentCount: 2,
        maximumSourceByteCount: 1_024, maximumVocabularySize: vocabulary,
        maximumDistinctNGramCount: ngrams, maximumNonZeroCellCount: cells)
}

private func corpusCacheBudgetRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiCorpusCacheBudgetTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    return root
}

private func corpusCacheBudgetProject(in root: URL) async throws -> (
    GlifiProjectPackage, [SourceRevisionID]
) {
    let project = try GlifiProjectPackage.create(at: root.appending(path: "Corpus.glifi"))
    var revisions: [SourceRevisionID] = []
    for text in ["casa casa mare", "casa città"] {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8), format: .plainText)
        _ = try await project.importText(imported)
        revisions.append(imported.sourceRevisionID)
    }
    return (project, revisions)
}

private final class CorpusCacheBudgetTokenizer: GlifiTokenizing {
    private let count = Mutex(0)

    var tokenizationContractIdentifier: String { GlifiItalianTokenizer.contractIdentifier }
    var invocationCount: Int { count.withLock { $0 } }

    func tokenize(_ text: String) throws -> GlifiTokenization {
        count.withLock { $0 += 1 }
        return try GlifiItalianTokenizer().tokenize(text)
    }
}
