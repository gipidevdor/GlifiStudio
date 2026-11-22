// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La cronologia dell'indagine è content-addressed, append-only e ramificabile")
func investigationHistoryReplaysBranches() throws {
    let investigationID = InvestigationID(
        uuid: try #require(UUID(uuidString: "81000000-0000-0000-0000-000000000001"))
    )
    let planID = try artifactID("1")
    let interpretationID = try artifactID("2")
    let findingA = try findingID("a")
    let findingB = try findingID("b")
    let created = try GlifiInvestigationEvent(
        investigationID: investigationID,
        predecessorEventID: nil,
        recordedAtUnixMilliseconds: 1_700_000_000_000,
        actor: .localPerson,
        payload: .created(
            question: "Quali caratteristiche emergono?",
            languageCode: "it",
            intent: .understandCollection,
            planArtifactID: planID,
            interpretationArtifactID: interpretationID,
            availableFindingIDs: [findingA, findingB],
            selectedFindingIDs: [findingA, findingB]
        )
    )
    let rootID = try created.eventID()
    #expect(
        try JSONDecoder().decode(
            GlifiInvestigationEvent.self,
            from: JSONEncoder().encode(created)
        ).eventID() == rootID)

    let branchA = try GlifiInvestigationEvent(
        investigationID: investigationID,
        predecessorEventID: rootID,
        recordedAtUnixMilliseconds: 1_700_000_000_100,
        actor: .localPerson,
        payload: .editorialSelectionChanged(
            selectedFindingIDs: [findingA],
            reasonIdentifier: "editorial.focus"
        )
    )
    let branchB = try GlifiInvestigationEvent(
        investigationID: investigationID,
        predecessorEventID: rootID,
        recordedAtUnixMilliseconds: 1_700_000_000_200,
        actor: .localPerson,
        payload: .editorialSelectionChanged(
            selectedFindingIDs: [findingB],
            reasonIdentifier: "editorial.alternative"
        )
    )
    let branchAID = try branchA.eventID()
    let branchBID = try branchB.eventID()
    let events = [rootID: created, branchAID: branchA, branchBID: branchB]

    let first = try GlifiInvestigation(headEventID: branchAID, eventsByID: events)
    let second = try GlifiInvestigation(headEventID: branchBID, eventsByID: events)
    #expect(first.selectedFindingIDs == [findingA])
    #expect(second.selectedFindingIDs == [findingB])
    #expect(first.eventIDs == [rootID, branchAID])
    #expect(second.eventIDs == [rootID, branchBID])
}

@Test("Una selezione editoriale estranea ai finding disponibili viene rifiutata")
func investigationRejectsUnknownFinding() throws {
    let investigationID = InvestigationID()
    let available = try findingID("a")
    let unknown = try findingID("f")
    let root = try GlifiInvestigationEvent(
        investigationID: investigationID,
        predecessorEventID: nil,
        recordedAtUnixMilliseconds: 1,
        actor: .localPerson,
        payload: .created(
            question: "Domanda",
            languageCode: "it",
            intent: .understandCollection,
            planArtifactID: try artifactID("1"),
            interpretationArtifactID: try artifactID("2"),
            availableFindingIDs: [available],
            selectedFindingIDs: [available]
        )
    )
    let rootID = try root.eventID()
    let invalid = try GlifiInvestigationEvent(
        investigationID: investigationID,
        predecessorEventID: rootID,
        recordedAtUnixMilliseconds: 2,
        actor: .localPerson,
        payload: .editorialSelectionChanged(
            selectedFindingIDs: [unknown],
            reasonIdentifier: "editorial.invalid"
        )
    )
    let invalidID = try invalid.eventID()
    #expect(throws: GlifiFailure.self) {
        _ = try GlifiInvestigation(
            headEventID: invalidID,
            eventsByID: [rootID: root, invalidID: invalid]
        )
    }
}

private func artifactID(_ digit: Character) throws -> ArtifactID {
    try ArtifactID(digest: "sha256:" + String(repeating: digit, count: 64))
}

private func findingID(_ digit: Character) throws -> FindingID {
    try FindingID(digest: "sha256:" + String(repeating: digit, count: 64))
}
