// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

private let source = SourceRevisionID(
    uuid: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x27)))

/// Appends events to a linear history, chaining each on the current head.
private struct HistoryBuilder {
    var events: [GlifiQualitativeEvent] = []
    var time: Int64 = 1_000

    mutating func append(_ payload: GlifiQualitativeEventPayload) throws -> String {
        time += 1
        let event = try GlifiQualitativeEvent(
            predecessorEventID: try events.last?.eventID(),
            recordedAtUnixMilliseconds: time, payload: payload)
        events.append(event)
        return try event.eventID()
    }

    mutating func code(_ start: Int, _ end: Int, _ category: String, _ coder: String) throws
        -> String
    {
        try append(
            .segmentCoded(
                sourceRevisionID: source, range: try GlifiUTF8Range(start: start, end: end),
                codebookID: "temi", codebookRevision: 1, categoryID: category, coderID: coder,
                origin: .manual))
    }
}

private let revisionOne = [
    GlifiCodebookCategory(categoryID: "mare", label: "Mare", definition: "Riferimenti al mare."),
    GlifiCodebookCategory(
        categoryID: "porto", parentCategoryID: "mare", label: "Porto",
        definition: "Riferimenti al porto."),
    GlifiCodebookCategory(categoryID: "monti", label: "Monti", definition: "Montagna e valli."),
]

@Test("La proiezione ricostruisce codebook, codifiche, ritrattazioni, mapping e memo")
func qualitativeProjectionReplaysHistory() throws {
    var history = HistoryBuilder()
    _ = try history.append(
        .codebookRevised(codebookID: "temi", revision: 1, categories: revisionOne))
    let first = try history.code(0, 4, "mare", "c1")
    _ = try history.code(0, 4, "mare", "c2")
    let wrong = try history.code(5, 9, "monti", "c1")
    _ = try history.append(.codingRetracted(codingEventID: wrong, reasonIdentifier: "errore"))
    _ = try history.code(5, 9, "porto", "c1")
    _ = try history.append(
        .memoAttached(target: .coding(eventID: first), coderID: "c1", text: "Esempio chiaro."))
    _ = try history.append(
        .codebookRevised(
            codebookID: "temi", revision: 2,
            categories: [
                GlifiCodebookCategory(
                    categoryID: "costa", label: "Costa", definition: "Mare e porto."),
                GlifiCodebookCategory(categoryID: "monti", label: "Monti", definition: "Montagna."),
            ]))
    _ = try history.append(
        .categoryMapped(
            codebookID: "temi", fromRevision: 1, toRevision: 2,
            mappings: [
                GlifiCategoryMapping(
                    kind: .merge, fromCategoryIDs: ["mare", "porto"], toCategoryIDs: ["costa"])
            ]))

    let state = try GlifiQualitativeState(events: history.events)
    #expect(state.codebooks["temi"]?.count == 2)
    #expect(state.codings.count == 4)
    #expect(state.activeCodings.count == 3)
    #expect(state.codings.first { $0.eventID == wrong }?.retractionEventID != nil)
    #expect(state.memos.count == 1)
    #expect(state.mappings["temi"]?.first?.to == 2)
    #expect(state.headEventID == (try history.events.last?.eventID()))
    // Le codifiche storiche restano sulla revisione 1: il mapping non le riscrive.
    #expect(state.activeCodings.allSatisfy { $0.codebookRevision == 1 })
    #expect(try GlifiQualitativeState(events: history.events) == state)

    // Identità content-addressed e round-trip JSON.
    for event in history.events {
        let decoded = try JSONDecoder().decode(
            GlifiQualitativeEvent.self, from: JSONEncoder().encode(event))
        #expect(try decoded.eventID() == event.eventID())
    }
}

@Test("La tabella d'accordo deriva dalle codifiche e coincide con coding-agreement-v2")
func qualitativeAgreementTableMatchesExplicitTable() throws {
    var history = HistoryBuilder()
    _ = try history.append(
        .codebookRevised(codebookID: "temi", revision: 1, categories: revisionOne))
    let layout: [(Int, Int, String?, String?)] = [
        (0, 4, "mare", "mare"), (5, 9, "porto", "mare"), (10, 14, "monti", "monti"),
        (15, 19, "mare", nil), (20, 24, "porto", "porto"), (25, 29, nil, "monti"),
    ]
    for (start, end, first, second) in layout {
        if let first { _ = try history.code(start, end, first, "c1") }
        if let second { _ = try history.code(start, end, second, "c2") }
    }
    // Unità ambigua: c1 la codifica due volte.
    _ = try history.code(30, 34, "mare", "c1")
    _ = try history.code(30, 34, "monti", "c1")

    let state = try GlifiQualitativeState(events: history.events)
    let (request, ambiguous) = try state.agreementTable(
        codebookID: "temi", codebookRevision: 1, coderIDs: ["c1", "c2"])
    #expect(ambiguous == 1)
    #expect(request.units.count == layout.count)
    let explicit = try GlifiCodingAgreementRequest(
        coderIdentifiers: ["c1", "c2"],
        units: layout.map { start, end, first, second in
            GlifiCodingUnit(
                unitIdentifier: "\(source.canonicalValue)#\(start)-\(end)", labels: [first, second])
        }.sorted { $0.unitIdentifier < $1.unitIdentifier })
    #expect(request == explicit)
    #expect(
        try GlifiCodingAgreementAnalyzer().analyze(request)
            == GlifiCodingAgreementAnalyzer().analyze(explicit))
}

@Test("Invarianti della storia qualitativa rifiutati con codici tipizzati")
func qualitativeHistoryRejectsInvalidChanges() throws {
    func failureCode(_ body: () throws -> Void) -> String? {
        do {
            try body()
            return nil
        } catch let failure as GlifiFailure {
            return failure.code
        } catch {
            return "untyped"
        }
    }
    // Revisione non consecutiva.
    var history = HistoryBuilder()
    _ = try history.append(
        .codebookRevised(codebookID: "temi", revision: 2, categories: revisionOne))
    #expect(
        failureCode { _ = try GlifiQualitativeState(events: history.events) }
            == "qualitative.revision-not-consecutive")
    // Categoria assente nella revisione.
    history = HistoryBuilder()
    _ = try history.append(
        .codebookRevised(codebookID: "temi", revision: 1, categories: revisionOne))
    _ = try history.code(0, 4, "inesistente", "c1")
    #expect(
        failureCode { _ = try GlifiQualitativeState(events: history.events) }
            == "qualitative.unknown-category")
    // Doppia ritrattazione.
    history = HistoryBuilder()
    _ = try history.append(
        .codebookRevised(codebookID: "temi", revision: 1, categories: revisionOne))
    let coding = try history.code(0, 4, "mare", "c1")
    _ = try history.append(.codingRetracted(codingEventID: coding, reasonIdentifier: "errore"))
    _ = try history.append(.codingRetracted(codingEventID: coding, reasonIdentifier: "errore"))
    #expect(
        failureCode { _ = try GlifiQualitativeState(events: history.events) }
            == "qualitative.unknown-coding")
    // Catena interrotta: un evento non si aggancia alla testa.
    history = HistoryBuilder()
    _ = try history.append(
        .codebookRevised(codebookID: "temi", revision: 1, categories: revisionOne))
    let orphan = try GlifiQualitativeEvent(
        predecessorEventID: nil, recordedAtUnixMilliseconds: 5,
        payload: .codebookRevised(codebookID: "altro", revision: 1, categories: revisionOne))
    #expect(
        failureCode { _ = try GlifiQualitativeState(events: history.events + [orphan]) }
            == "qualitative.broken-chain")
    // Gerarchia ciclica, identificatore non valido, testo vuoto, arità del mapping.
    let cyclic = [
        GlifiCodebookCategory(categoryID: "a", parentCategoryID: "b", label: "A", definition: "A."),
        GlifiCodebookCategory(categoryID: "b", parentCategoryID: "a", label: "B", definition: "B."),
    ]
    for payload: GlifiQualitativeEventPayload in [
        .codebookRevised(codebookID: "temi", revision: 1, categories: cyclic),
        .codebookRevised(codebookID: "Temi Maiuscolo", revision: 1, categories: revisionOne),
        .memoAttached(target: .source(sourceRevisionID: source), coderID: "c1", text: "  "),
        .categoryMapped(
            codebookID: "temi", fromRevision: 1, toRevision: 2,
            mappings: [
                GlifiCategoryMapping(kind: .merge, fromCategoryIDs: ["mare"], toCategoryIDs: ["x"])
            ]),
    ] {
        #expect(
            failureCode {
                _ = try GlifiQualitativeEvent(
                    predecessorEventID: nil, recordedAtUnixMilliseconds: 1, payload: payload)
            } == "qualitative.invalid-event")
    }
}
