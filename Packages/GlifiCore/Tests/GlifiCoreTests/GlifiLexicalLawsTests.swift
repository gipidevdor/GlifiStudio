// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracle: Tests/Oracles/Python/lexical_laws.py (LAWS_* rows in expected.txt).
private let lawTexts = [
    "La casa la strada la casa il sole il mare la notte.",
    "Il sole la luna il mare il vento la casa.",
]

private func lawsClose(_ value: Double?, _ reference: Double) -> Bool {
    guard let value else { return false }
    return abs(value - reference) <= 1e-12 * max(1, abs(reference))
}

private func lawSequences() throws -> [(SourceRevisionID, [String])] {
    try lawTexts.enumerated().map { index, text in
        (
            try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index + 1)"),
            text.lowercased().split { !$0.isLetter }.map(String.init)
        )
    }
}

private func expectFit(
    _ law: GlifiLexicalLawFit, _ reference: [Double], residuals: [Double]? = nil
) throws {
    let fit = try #require(law.fit)
    #expect(lawsClose(fit.coefficient, reference[0]))
    #expect(lawsClose(fit.exponent, reference[1]))
    #expect(lawsClose(fit.rSquared, reference[2]))
    #expect(lawsClose(fit.rootMeanSquaredLogError, reference[3]))
    #expect(lawsClose(exp(fit.intercept), fit.coefficient))
    if let residuals {
        #expect(fit.residuals.count == residuals.count)
        for (value, expected) in zip(fit.residuals, residuals) {
            #expect(lawsClose(value, expected))
        }
    }
}

@Test("Osservazioni, ZipfLogOLS-v1 e HeapsLogOLS-v1 coincidono con l'oracolo indipendente")
func lexicalLawsMatchOracle() throws {
    let parameters = GlifiLexicalLawsParameters(
        checkpointCount: 4, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 1_000)
    let value = try GlifiCorpusLexicalLawsAnalysis(
        sequences: lawSequences(), parameters: parameters)
    #expect(value.tokenCount == 22)
    #expect(value.typeCount == 9)
    #expect(value.rankFrequency.map(\.count) == [6, 5, 3, 2, 2, 1, 1, 1, 1])
    #expect(
        value.rankFrequency.map(\.type)
            == ["la", "il", "casa", "mare", "sole", "luna", "notte", "strada", "vento"])
    #expect(value.rankFrequency.map(\.rank) == Array(1...9))
    #expect(!value.isRankFrequencyTruncated)
    #expect(value.spectrum.map(\.frequency) == [1, 2, 3, 5, 6])
    #expect(value.spectrum.map(\.typeCount) == [4, 2, 1, 1, 1])
    #expect(value.growth.map(\.tokenCount) == [6, 11, 17, 22])
    #expect(value.growth.map(\.typeCount) == [3, 6, 8, 9])
    #expect(value.zipf.methodIdentifier == "ZipfLogOLS-v1")
    try expectFit(
        value.zipf,
        [7.53583792524574, 0.960091538527948, 0.926192312143406, 0.183790778711583])
    #expect(value.zipf.fit?.isExponentInModelDomain == true)
    #expect(value.zipf.fit?.pointCount == 9)
    #expect(value.heaps.methodIdentifier == "HeapsLogOLS-v1")
    try expectFit(
        value.heaps,
        [0.694649300131857, 0.852729565174465, 0.968524775400971, 0.0756668276324683],
        residuals: [-0.0649258195242832, 0.111351440820472, 0.0278249236559636, -0.074250544952152])
    #expect(value.heaps.fit?.isExponentInModelDomain == true)
    #expect(value.fitCaveat == "caveat.lexical-law-fit-is-descriptive-v1")

    let ranged = try GlifiLexicalLaws.zipf(value.rankFrequency, firstRank: 2, lastRank: 4)
    try expectFit(
        ranged,
        [12.5510262835143, 1.3178536788091, 0.999007862274515, 0.0118086043152482],
        residuals: [-0.00689796352200256, 0.0166200970610808, -0.00972213353907814])
    #expect(ranged.fit?.firstPredictor == 2)
    #expect(ranged.fit?.lastPredictor == 4)
}

@Test("Leggi lessicali: troncamento, fit non definiti e parametri fuori dominio")
func lexicalLawsEdgeCases() throws {
    let truncated = try GlifiCorpusLexicalLawsAnalysis(
        sequences: lawSequences(),
        parameters: GlifiLexicalLawsParameters(
            checkpointCount: 2, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 3))
    #expect(truncated.rankFrequency.count == 3)
    #expect(truncated.isRankFrequencyTruncated)
    #expect(truncated.zipf.fit?.pointCount == 9)
    #expect(truncated.growth.map(\.tokenCount) == [11, 22])

    let id = try SourceRevisionID(
        canonicalValue: "source-revision:00000000-0000-0000-0000-000000000009")
    let single = try GlifiCorpusLexicalLawsAnalysis(
        sequences: [(id, ["x", "x", "x"])], parameters: .standard)
    #expect(single.zipf.fit == nil)
    #expect(single.zipf.unavailableReason == "fit.insufficient-points")
    #expect(single.growth.map(\.tokenCount) == [1, 2, 3])
    #expect(single.heaps.fit?.exponent == 0)
    #expect(single.heaps.fit?.rSquared == nil)
    #expect(single.heaps.fit?.isExponentInModelDomain == false)

    let empty = try GlifiCorpusLexicalLawsAnalysis(sequences: [(id, [])], parameters: .standard)
    #expect(empty.growth.isEmpty)
    #expect(empty.zipf.fit == nil)
    #expect(empty.heaps.fit == nil)

    #expect(try GlifiLexicalLaws.checkpoints(tokenCount: 3, count: 5) == [1, 2, 3])
    #expect(try GlifiLexicalLaws.checkpoints(tokenCount: 10, count: 3) == [4, 7, 10])
    #expect(
        try GlifiLexicalLaws.checkpoints(tokenCount: Int.max, count: 2)
            == [Int.max / 2 + 1, Int.max])
    for parameters in [
        GlifiLexicalLawsParameters(
            checkpointCount: 1, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 1),
        GlifiLexicalLawsParameters(
            checkpointCount: 2, zipfFirstRank: 0, zipfLastRank: nil, rankRowLimit: 1),
        GlifiLexicalLawsParameters(
            checkpointCount: 2, zipfFirstRank: 3, zipfLastRank: 3, rankRowLimit: 1),
        GlifiLexicalLawsParameters(
            checkpointCount: 2, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 0),
    ] {
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiCorpusLexicalLawsAnalysis(
                sequences: lawSequences(), parameters: parameters)
        }
    }
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiCorpusLexicalLawsAnalysis(sequences: [], parameters: .standard)
    }
}

@Test("Le leggi lessicali si persistono sul gruppo e si riusano")
func lexicalLawsArePersistedAndReused() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiLexicalLaws-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    var ids: [SourceRevisionID] = []
    for (index, text) in lawTexts.enumerated() {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index + 1)")
        )
        _ = try await project.importText(imported)
        ids.append(imported.sourceRevisionID)
    }
    let parameters = GlifiLexicalLawsParameters(
        checkpointCount: 4, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 1_000)
    let result = try await engine.analyzeLexicalLaws(
        in: project, sourceRevisionIDs: ids, parameters: parameters)
    let reused = try await engine.analyzeLexicalLaws(
        in: project, sourceRevisionIDs: ids, parameters: parameters)
    #expect(reused.artifactID == result.artifactID)
    let changed = try await engine.analyzeLexicalLaws(in: project, sourceRevisionIDs: ids)
    #expect(changed.artifactID != result.artifactID)
    // Profile normalization: lowercase keys with punctuation excluded.
    #expect(result.value.sourceRevisionIDs == ids.map(\.canonicalValue))
    #expect(result.value.rankFrequency.map(\.count) == [6, 5, 3, 2, 2, 1, 1, 1, 1])
    #expect(result.value.growth.map(\.typeCount) == [3, 6, 8, 9])
    try expectFit(
        result.value.heaps,
        [0.694649300131857, 0.852729565174465, 0.968524775400971, 0.0756668276324683])
    await #expect(throws: GlifiFailure.self) {
        _ = try await engine.analyzeLexicalLaws(
            in: project, sourceRevisionIDs: ids,
            parameters: GlifiLexicalLawsParameters(
                checkpointCount: 0, zipfFirstRank: 1, zipfLastRank: nil, rankRowLimit: 1))
    }
}
