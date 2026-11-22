// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import Testing

@testable import GlifiKit

@Test(
    "Core e Kit conservano match tardivi e failure dei budget intermedi",
    arguments: [1_002, 100_001])
func queryIntermediateBudgetParity(repetitions: Int) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiQueryBudgetParity-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let text = String(repeating: "a ", count: repetitions) + "b"
    let source = root.appending(path: "synthetic.txt")
    try Data(text.utf8).write(to: source)
    let session = try await GlifiStudioService().createProject(at: root.appending(path: "Q.glifi"))
    do {
        _ = try await session.importText(at: source, format: .plainText)
        let generation = try await session.snapshot().generation
        let imported = try GlifiTextImporter().importText(from: Data(text.utf8), format: .plainText)
        let tokens = try GlifiItalianTokenizer().tokenize(imported.text)
        let ast = try GlifiQueryParser().parse("a BEFORE/0 b")
        if repetitions < GlifiQueryLimits.standard.maximumIntermediateAnchorCount {
            let core = try GlifiQueryEvaluator().evaluate(ast, in: imported, tokenization: tokens)
            let kit = try await session.query("a BEFORE/0 b")
            #expect(core.matchedScope && kit.matchedSourceCount == 1)
            #expect(core.matches.count == 1 && kit.matches.count == 1)
            #expect(kit.matches.map(\.startUTF8) == [repetitions * 2 - 2])
            #expect(kit.matches.map(\.endUTF8) == [repetitions * 2 + 1])
            #expect(core.matches.map { $0.range.start } == kit.matches.map(\.startUTF8))
            #expect(core.matches.map { $0.range.end } == kit.matches.map(\.endUTF8))
            #expect(!core.isTruncated && !kit.isTruncated)
            #expect(try await session.query(canonicalAST: ast.canonicalData()) == kit)
        } else {
            do {
                _ = try GlifiQueryEvaluator().evaluate(ast, in: imported, tokenization: tokens)
                Issue.record("Core accepted an exhausted intermediate-anchor budget")
            } catch let failure as GlifiFailure {
                #expect(failure.code == "query.intermediate-anchor-limit-exceeded")
                #expect(failure.category == .insufficientResources)
            }
            for canonical in [false, true] {
                do {
                    if canonical {
                        _ = try await session.query(canonicalAST: ast.canonicalData())
                    } else {
                        _ = try await session.query("a BEFORE/0 b")
                    }
                    Issue.record("Kit accepted an exhausted intermediate-anchor budget")
                } catch let failure as GlifiStudioFailure {
                    #expect(failure.code == "query.intermediate-anchor-limit-exceeded")
                    #expect(failure.category == "insufficientResources")
                    #expect(failure.retryDisposition == "afterConditionsChange")
                    #expect(failure.operation == "query" && failure.arguments.isEmpty)
                }
            }
        }
        #expect(try await session.snapshot().generation == generation)
        await session.close()
    } catch {
        await session.close()
        throw error
    }
}

// RF-080: GlifiCore e GlifiKit compilano la stessa QueryAST canonica e producono gli stessi
// intervalli nello stesso ordine; app e CLI usano solo `GlifiStudioProjectSession.query`.
private struct QueryFixture: Decodable {
    struct Case: Decodable {
        struct Match: Decodable {
            let start: Int
            let end: Int
        }
        let id: String
        let query: String
        let outcome: String
        let matches: [Match]?
        let failureCode: String?
    }
    let source: String
    let cases: [Case]
}

@Test("Core e Kit producono lo stesso digest, gli stessi intervalli e lo stesso ordine")
func queryParityBetweenCoreAndKit() async throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Fixtures/Query/v1/cases.json")
    let fixture = try JSONDecoder().decode(QueryFixture.self, from: Data(contentsOf: fixtureURL))
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiQueryParity-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceURL = root.appending(path: "fonte.txt")
    try Data(fixture.source.utf8).write(to: sourceURL)
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "Q.glifi", directoryHint: .isDirectory))
    _ = try await session.importText(at: sourceURL, format: .plainText)

    let imported = try GlifiTextImporter().importText(
        from: Data(fixture.source.utf8), format: .plainText)
    let tokenization = try GlifiItalianTokenizer().tokenize(imported.text)
    let generation = try await session.snapshot().generation
    #expect(fixture.cases.count >= 7)
    for testCase in fixture.cases {
        switch testCase.outcome {
        case "succeeded":
            let ast = try GlifiQueryParser().parse(testCase.query)
            let core = try GlifiQueryEvaluator().evaluate(
                ast, in: imported, tokenization: tokenization)
            let kit = try await session.query(testCase.query)
            let astKit = try await session.query(canonicalAST: ast.canonicalData())
            #expect(astKit == kit, "\(testCase.id)")
            #expect(kit.queryDigest == (try ast.canonicalDigest()), "\(testCase.id)")
            let coreRanges = core.matches.map { [$0.range.start, $0.range.end] }
            let kitRanges = kit.matches.map { [$0.startUTF8, $0.endUTF8] }
            #expect(kitRanges == coreRanges, "\(testCase.id)")
            #expect(
                kitRanges == (testCase.matches ?? []).map { [$0.start, $0.end] }, "\(testCase.id)")
        default:
            // Il rifiuto può avvenire in parsing o in validazione della valutazione.
            do {
                _ = try GlifiQueryEvaluator().evaluate(
                    try GlifiQueryParser().parse(testCase.query), in: imported,
                    tokenization: tokenization)
                Issue.record("\(testCase.id): Core ha accettato una query rifiutata")
            } catch let failure as GlifiFailure {
                #expect(failure.code == testCase.failureCode, "\(testCase.id)")
            }
            do {
                _ = try await session.query(testCase.query)
                Issue.record("\(testCase.id): Kit ha accettato una query rifiutata")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == testCase.failureCode, "\(testCase.id)")
            }
        }
    }
    do {
        _ = try await session.query(canonicalAST: Data("ZQXCANARY42".utf8))
        Issue.record("Malformed AST was accepted")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "query.invalid-ast")
        #expect(failure.category == "invalidInput")
        #expect(failure.operation == "query")
        #expect(failure.arguments.isEmpty)
        #expect(!String(describing: failure).contains("ZQXCANARY42"))
    }
    #expect(try await session.snapshot().generation == generation)
    await session.close()
    do {
        _ = try await session.query(canonicalAST: GlifiQueryAST(root: .matchAll).canonicalData())
        Issue.record("Closed session accepted an AST query")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "project.session-closed")
    }
}
