// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

@Test("GlifiKit gestisce codebook, codifiche, memo e accordo dalle codifiche persistite")
func qualitativeServiceCodesAndMeasuresAgreement() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiQualitativeKit-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Q.glifi", directoryHint: .isDirectory)
    let session = try await GlifiStudioService().createProject(at: projectURL)
    let text = "Il mare è calmo. La montagna è alta. Il porto è vicino. La valle è verde."
    let sourceURL = root.appending(path: "f.txt")
    try Data(text.utf8).write(to: sourceURL)
    let source = try #require(
        try await session.importText(at: sourceURL, format: .plainText).project.sources.first)

    _ = try await session.appendQualitativeChange(
        .codebookRevised(
            codebookID: "temi", revision: 1,
            categories: [
                GlifiStudioCodebookCategory(categoryID: "mare", label: "Mare", definition: "Mare."),
                GlifiStudioCodebookCategory(
                    categoryID: "monti", label: "Monti", definition: "Monti."),
            ]))
    // Quattro frasi; c2 dissente sulla terza.
    let sentences = text.components(separatedBy: ". ")
    var offset = 0
    var units: [(Int, Int)] = []
    for sentence in sentences {
        let length = sentence.utf8.count
        units.append((offset, offset + length))
        offset += length + 2
    }
    let first = ["mare", "monti", "mare", "monti"]
    let second = ["mare", "monti", "monti", "monti"]
    for (index, unit) in units.enumerated() {
        for (coder, labels) in [("c1", first), ("c2", second)] {
            _ = try await session.appendQualitativeChange(
                .segmentCoded(
                    sourceRevisionID: source.sourceRevisionID, startUTF8: unit.0, endUTF8: unit.1,
                    codebookID: "temi", codebookRevision: 1, categoryID: labels[index],
                    coderID: coder, origin: "manual"))
        }
    }
    // Un intervallo che taglia «è» (due byte) è rifiutato.
    let accent = try #require(text.utf8.firstIndex(of: 0xC3))
    let middle = text.utf8.distance(from: text.utf8.startIndex, to: accent) + 1
    do {
        _ = try await session.appendQualitativeChange(
            .segmentCoded(
                sourceRevisionID: source.sourceRevisionID, startUTF8: 0, endUTF8: middle,
                codebookID: "temi", codebookRevision: 1, categoryID: "mare", coderID: "c1",
                origin: "manual"))
        Issue.record("intervallo non allineato accettato")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "qualitative.invalid-range")
    }
    let state = try await session.qualitativeState()
    let target = try #require(state.codings.first?.eventID)
    let annotated = try await session.appendQualitativeChange(
        .memoAttached(target: .coding(eventID: target), coderID: "c1", text: "Caso tipico."))
    #expect(annotated.memos.count == 1)
    #expect(annotated.codings.count == 8)

    let stored = try await session.assessStoredCodingAgreement(
        codebookID: "temi", codebookRevision: 1, coderIDs: ["c1", "c2"])
    #expect(stored.ambiguousUnitCount == 0)
    let explicit = try await session.assessCodingAgreement(
        try GlifiStudioCodingAgreementRequest(
            coderIdentifiers: ["c1", "c2"],
            units: units.enumerated().map { index, unit in
                GlifiStudioCodingUnit(
                    unitIdentifier: "\(source.sourceRevisionID)#\(unit.0)-\(unit.1)",
                    labels: [first[index], second[index]])
            }.sorted { $0.unitIdentifier < $1.unitIdentifier }))
    // Stessa tabella: stesso nodo e stesso Artifact, riusato per get-or-store.
    #expect(stored.agreement.lineage.artifactID == explicit.lineage.artifactID)
    #expect(stored.agreement.lineage.analysisNodeID == explicit.lineage.analysisNodeID)
    #expect(stored.agreement.unitCount == 4)
    await session.close()

    // La storia sopravvive alla riapertura.
    let reopened = try await GlifiStudioService().openProject(at: projectURL)
    #expect(try await reopened.qualitativeState() == annotated)
    await reopened.close()
}

@Test("Il testo sorgente conserva il BOM e resta allineato ai byte della fonte")
func sourceTextKeepsByteOrderMarkAligned() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiSourceBOM-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "B.glifi", directoryHint: .isDirectory))
    let url = root.appending(path: "bom.txt")
    try Data([0xEF, 0xBB, 0xBF] + Array("casa".utf8)).write(to: url)
    let source = try #require(
        try await session.importText(at: url, format: .plainText).project.sources.first)
    let loaded = try await session.sourceText(sourceRevisionID: source.sourceRevisionID)
    #expect(loaded.byteCount == 7)
    #expect(loaded.text.utf8.count == loaded.byteCount)
    await session.close()
}

@Test("I segmenti di frase sono intervalli codificabili del testo estratto")
func textSegmentsAreCodableSentences() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiSegments-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "S.glifi", directoryHint: .isDirectory))
    let url = root.appending(path: "s.md")
    try Data("# Titolo\n\nIl mare è calmo. La valle è verde!".utf8).write(to: url)
    let source = try #require(
        try await session.importText(at: url, format: .markdown).project.sources.first)
    let segments = try await session.textSegments(sourceRevisionID: source.sourceRevisionID)
    #expect(segments.count >= 2)
    #expect(segments.map(\.startUTF8) == segments.map(\.startUTF8).sorted())
    _ = try await session.appendQualitativeChange(
        .codebookRevised(
            codebookID: "temi", revision: 1,
            categories: [
                GlifiStudioCodebookCategory(
                    categoryID: "luogo", label: "Luogo", definition: "Luoghi.")
            ]))
    // Ogni segmento è accettato come intervallo di codifica.
    for segment in segments {
        _ = try await session.appendQualitativeChange(
            .segmentCoded(
                sourceRevisionID: source.sourceRevisionID, startUTF8: segment.startUTF8,
                endUTF8: segment.endUTF8, codebookID: "temi", codebookRevision: 1,
                categoryID: "luogo", coderID: "c1", origin: "manual"))
    }
    #expect(try await session.qualitativeState().codings.count == segments.count)
    await session.close()
}

@Test("L'identità di categoria derivata dall'etichetta è stabile e valida")
func categoryIdentifierFromLabel() {
    #expect(GlifiStudioCodebookCategory.identifier(forLabel: "Città e Mare") == "citta-e-mare")
    #expect(GlifiStudioCodebookCategory.identifier(forLabel: "  Perché?! ") == "perche")
    #expect(GlifiStudioCodebookCategory.identifier(forLabel: "😀") == "categoria")
    #expect(
        GlifiStudioCodebookCategory.identifier(forLabel: String(repeating: "a", count: 90)).count
            == 64)
}

@Test("La selezione libera risolve passaggi per frasi o per caratteri sui confini di carattere")
func passageSelectionResolvesFreeFormIntervals() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiPassage-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "P.glifi", directoryHint: .isDirectory))
    let text = "Il mare è calmo. La valle è verde. 👨‍👩‍👧 resta in riva."
    let url = root.appending(path: "p.txt")
    try Data(text.utf8).write(to: url)
    let source = try #require(
        try await session.importText(at: url, format: .plainText).project.sources.first)
    let identifier = source.sourceRevisionID
    #expect(try await session.extractedCharacterCount(sourceRevisionID: identifier) == text.count)

    // Un passaggio può coprire più frasi consecutive.
    let segments = try await session.textSegments(sourceRevisionID: identifier)
    #expect(segments.count >= 3)
    let spanning = try await session.passage(
        sourceRevisionID: identifier, selection: .sentences(first: 0, last: 1))
    #expect(spanning.startUTF8 == segments[0].startUTF8)
    #expect(spanning.endUTF8 == segments[1].endUTF8)
    #expect(spanning.text.hasPrefix("Il mare"))
    #expect(spanning.text.hasSuffix("verde."))

    // Un passaggio può essere più piccolo di una frase.
    let fragment = try await session.passage(
        sourceRevisionID: identifier, selection: .characters(start: 3, end: 15))
    #expect(fragment.text == "mare è calmo")
    #expect(fragment.startUTF8 == 3)

    // Una sequenza emoji composta è un solo carattere e resta indivisa.
    let emojiIndex = try #require(text.firstIndex(of: "👨‍👩‍👧"))
    let emojiOffset = text.distance(from: text.startIndex, to: emojiIndex)
    let emoji = try await session.passage(
        sourceRevisionID: identifier,
        selection: .characters(start: emojiOffset, end: emojiOffset + 1))
    #expect(emoji.text == "👨‍👩‍👧")
    #expect(emoji.endUTF8 - emoji.startUTF8 == "👨‍👩‍👧".utf8.count)

    // Ogni passaggio risolto è accettato come intervallo di codifica.
    _ = try await session.appendQualitativeChange(
        .codebookRevised(
            codebookID: "temi", revision: 1,
            categories: [
                GlifiStudioCodebookCategory(
                    categoryID: "luogo", label: "Luogo", definition: "Luoghi.")
            ]))
    for passage in [spanning, fragment, emoji] {
        _ = try await session.appendQualitativeChange(
            .segmentCoded(
                sourceRevisionID: identifier, startUTF8: passage.startUTF8,
                endUTF8: passage.endUTF8, codebookID: "temi", codebookRevision: 1,
                categoryID: "luogo", coderID: "c1", origin: "manual"))
    }
    #expect(try await session.qualitativeState().codings.count == 3)

    // Selezioni vuote, invertite, fuori dal testo o senza caratteri visibili sono rifiutate.
    let rejected: [GlifiStudioPassageSelection] = [
        .sentences(first: 1, last: 0),
        .sentences(first: 0, last: segments.count),
        .sentences(first: -1, last: 0),
        .characters(start: 5, end: 5),
        .characters(start: 0, end: text.count + 1),
        .characters(start: 16, end: 17),
    ]
    for selection in rejected {
        do {
            _ = try await session.passage(sourceRevisionID: identifier, selection: selection)
            Issue.record("selezione non valida accettata: \(selection)")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.code == "qualitative.invalid-selection")
        }
    }
    await session.close()
}
