// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

// Oracolo: Tests/Oracles/R/diversity.R (righe MTLD_* di expected.txt).
private let letters = ["a", "b", "c", "d", "e", "f"]
private let pseudoRandomIndexes = [
    2, 2, 1, 1, 5, 4, 6, 4, 5, 6, 6, 6, 6, 5, 3, 5, 3, 5, 2, 1, 6, 6, 3, 3, 3, 2, 4, 5, 2, 3, 2, 2,
    3, 2, 1, 4, 1, 4, 4, 5, 1, 5, 4, 2, 5, 4, 6, 3, 1, 6, 4, 6, 5, 2, 1, 1, 4, 3, 4, 6, 6, 5, 6, 6,
    6, 5, 6, 1, 3, 4, 3, 6, 3, 3, 4, 3, 3, 4, 3, 4, 3, 5, 6, 4, 1, 1, 1, 2, 4, 3, 3, 6, 5, 5, 1, 1,
    6, 5, 1, 2, 6, 1, 3, 2, 2, 3, 4, 5, 5, 4, 5, 4, 5, 6, 2, 1, 3, 1, 1, 4, 4, 2, 4, 2, 3, 3, 1, 5,
    2, 1, 6, 1, 6, 1, 5, 2, 3, 2, 3, 4, 3, 1, 2, 1, 5, 5, 2, 3, 4, 3, 1, 6, 2, 2, 4, 2, 5, 5, 6, 3,
    5, 5, 6, 5, 4, 6, 5, 2, 5, 4, 5, 3, 1, 4, 5, 1, 4, 2, 4, 2, 4, 3, 4, 1, 6, 3, 6, 3, 1, 3, 5, 1,
    1, 2, 4, 1, 1, 4, 3, 4,
]

private func close(_ value: GlifiExtendedNonNegative?, _ reference: Double) -> Bool {
    guard let value, case let .finite(actual) = value else { return false }
    return abs(actual - reference) <= 1e-12 * max(1, abs(reference))
}

@Test("MTLD-bidirectional-v1 coincide con l'implementazione indipendente in R")
func mtldMatchesR() throws {
    let handWorked = "a b a c a b d a e b a c f a b a".split(separator: " ").map(String.init)
    let value = try #require(try GlifiMTLD.measure(handWorked, threshold: 0.72))
    #expect(close(value.forward, 5.33333333333333))
    #expect(close(value.backward, 5.53086419753086))
    #expect(close(value.value, 5.4320987654321))
    #expect(value.tokenCount == 16)
    #expect(close(try GlifiMTLD.measure(handWorked, threshold: 0.5)?.value, 9.77777777777778))
    let pseudoRandom = pseudoRandomIndexes.map { letters[$0 - 1] }
    #expect(close(try GlifiMTLD.measure(pseudoRandom, threshold: 0.72)?.value, 4.25724637681159))
    let constant = Array(repeating: "x", count: 7)
    #expect(close(try GlifiMTLD.measure(constant, threshold: 0.72)?.value, 2.33333333333333))
}

@Test("MTLD: +∞ senza fattori, sequenza vuota non definita, soglia fuori da (0,1) rifiutata")
func mtldEdgeCasesAndEncoding() throws {
    let distinct = try #require(try GlifiMTLD.measure(["a", "b", "c"], threshold: 0.72))
    #expect(distinct.forward == .positiveInfinity)
    #expect(distinct.value == .positiveInfinity)
    #expect(distinct.value.doubleValue == .infinity)
    #expect(try GlifiMTLD.measure([], threshold: 0.72) == nil)
    for threshold in [0.0, 1.0, -0.1, .nan] {
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiMTLD.measure(["a"], threshold: threshold)
        }
    }
    let encoded = try JSONEncoder().encode(distinct)
    #expect(String(decoding: encoded, as: UTF8.self).contains("\"+Infinity\""))
    #expect(try JSONDecoder().decode(GlifiMTLDValue.self, from: encoded) == distinct)
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(
            GlifiExtendedNonNegative.self, from: Data("\"Infinity\"".utf8))
    }
}

@Test("La diversità MTLD si persiste per documento e sulla sequenza concatenata")
func lexicalDiversityIsPersistedAndReused() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiLexicalDiversity-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let engine = GlifiEngine()
    var ids: [SourceRevisionID] = []
    for (index, text) in ["A b a C a b d a e b a c f a b a.", "Uno due tre.", "..."].enumerated() {
        let imported = try GlifiTextImporter().importText(
            from: Data(text.utf8),
            format: .plainText,
            sourceRevisionID: try SourceRevisionID(
                canonicalValue: "source-revision:00000000-0000-0000-0000-00000000000\(index + 1)")
        )
        _ = try await project.importText(imported)
        ids.append(imported.sourceRevisionID)
    }
    let result = try await engine.analyzeLexicalDiversity(in: project, sourceRevisionIDs: ids)
    let reused = try await engine.analyzeLexicalDiversity(in: project, sourceRevisionIDs: ids)
    #expect(reused.artifactID == result.artifactID)
    let documents = result.value.documents
    #expect(documents.map(\.sourceRevisionID) == ids.map(\.canonicalValue))
    // Normalizzazione del profilo: maiuscole ridotte, punteggiatura esclusa.
    #expect(close(documents[0].mtld?.value, 5.4320987654321))
    #expect(documents[1].mtld?.value == .positiveInfinity)
    #expect(documents[2].mtld == nil)
    #expect(result.value.pooled?.tokenCount == 19)
    #expect(result.value.threshold == 0.72)
    await #expect(throws: GlifiFailure.self) {
        _ = try await engine.analyzeLexicalDiversity(
            in: project, sourceRevisionIDs: ids, threshold: 1)
    }
}
