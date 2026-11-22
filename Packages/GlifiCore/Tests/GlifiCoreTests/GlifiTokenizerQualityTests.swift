// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import Testing

@testable import GlifiCore

/// Span-level precision, recall and F1 of one layer of boundaries (GS-MET-001-18).
private struct BoundaryAgreement {
    let matched: Int
    let predicted: Int
    let gold: Int

    var precision: Double { predicted == 0 ? 0 : Double(matched) / Double(predicted) }
    var recall: Double { gold == 0 ? 0 : Double(matched) / Double(gold) }
    var f1: Double {
        let denominator = precision + recall
        return denominator == 0 ? 0 : 2 * precision * recall / denominator
    }

    init(predicted: [ClosedRange<Int>], gold: [ClosedRange<Int>]) {
        // Corrispondenza esatta dello span: un confine spostato conta come errore su entrambi i
        // lati, come prescrive GS-MET-001-18, non come mezzo credito.
        let goldSet = Set(gold)
        self.matched = predicted.filter(goldSet.contains).count
        self.predicted = predicted.count
        self.gold = gold.count
    }
}

@Test("La qualità della tokenizzazione non scende sotto la linea di base registrata")
func italianTokenizerMeetsRecordedBaseline() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    for corpus in ["it-gold-v0", "it-gold-v1"] {
        try verifyBaseline(of: corpus, under: root)
    }
}

/// Measures one gold corpus against its recorded baseline.
private func verifyBaseline(of corpus: String, under root: URL) throws {
    let baselineURL = root.appending(path: "Fixtures/Linguistics/\(corpus)/baseline.json")
    let baseline = try JSONDecoder().decode(
        TokenizationBaseline.self, from: try Data(contentsOf: baselineURL))
    let corpusData = try Data(contentsOf: root.appending(path: baseline.corpus))

    // La linea di base vale per un corpus preciso: se il corpus cambia, va rimisurata.
    let digest = SHA256.hash(data: corpusData).map { String(format: "%02x", $0) }.joined()
    #expect("sha256:\(digest)" == baseline.corpusDigest)

    let goldCorpus = try JSONDecoder().decode(GoldCorpus.self, from: corpusData)
    #expect(goldCorpus.cases.count == baseline.observed.caseCount)

    let tokenizer = GlifiItalianTokenizer()
    var tokenPredicted: [ClosedRange<Int>] = []
    var tokenGold: [ClosedRange<Int>] = []
    var sentencePredicted: [ClosedRange<Int>] = []
    var sentenceGold: [ClosedRange<Int>] = []
    for goldCase in goldCorpus.cases {
        let result = try tokenizer.tokenize(goldCase.text)
        // La punteggiatura è un gap indirizzabile, non un token lessicale (GS-LNG-001): la
        // misura confronta le forme lessicali, come fa il conteggio del profilo di corpus.
        tokenPredicted += result.tokens.filter { $0.kind != .punctuation }.map {
            $0.range.start...$0.range.end
        }
        tokenGold += goldCase.tokens.filter { $0.kind != "punctuation" }.map { $0.start...$0.end }
        sentencePredicted += result.sentences.map { $0.range.start...$0.range.end }
        sentenceGold += goldCase.sentences.map { $0.start...$0.end }
    }
    #expect(tokenGold.count == baseline.observed.goldTokenCount)
    #expect(sentenceGold.count == baseline.observed.goldSentenceCount)

    let tokens = BoundaryAgreement(predicted: tokenPredicted, gold: tokenGold)
    let sentences = BoundaryAgreement(predicted: sentencePredicted, gold: sentenceGold)
    // Una regressione fa fallire il gate; un miglioramento chiede di aggiornare la linea di base.
    #expect(tokens.f1 >= baseline.observed.tokenBoundaryF1 - 1e-12)
    #expect(sentences.f1 >= baseline.observed.sentenceBoundaryF1 - 1e-12)
    #expect(tokens.precision >= 0 && tokens.recall >= 0)
    if tokens.f1 > baseline.observed.tokenBoundaryF1 + 1e-12
        || sentences.f1 > baseline.observed.sentenceBoundaryF1 + 1e-12
    {
        let message =
            "La qualità è migliorata (token F1 \(tokens.f1), frasi F1 \(sentences.f1)): "
            + "aggiorna baseline.json, altrimenti la regressione successiva non verrebbe vista."
        Issue.record(Comment(rawValue: message))
    }
}

private struct TokenizationBaseline: Decodable {
    struct Observed: Decodable {
        let caseCount: Int
        let goldTokenCount: Int
        let goldSentenceCount: Int
        let tokenBoundaryF1: Double
        let sentenceBoundaryF1: Double
    }

    let corpus: String
    let corpusDigest: String
    let observed: Observed
}

private struct GoldCorpus: Decodable {
    struct Span: Decodable {
        let start: Int
        let end: Int
        /// Assente nei corpora che annotano soltanto forme lessicali.
        let kind: String?
    }

    struct Case: Decodable {
        let id: String
        let text: String
        let tokens: [Span]
        let sentences: [Span]
    }

    let cases: [Case]
}
