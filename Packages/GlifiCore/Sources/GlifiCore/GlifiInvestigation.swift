// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Stable actor class recorded in cognitive history without storing personal identity.
public enum GlifiInvestigationActor: String, Codable, Equatable, Sendable {
    case localPerson
    case system
}

/// Typed, versioned payload of one immutable investigation-history event.
public enum GlifiInvestigationEventPayload: Codable, Equatable, Sendable {
    /// Establishes the question, analysis lineage, and first editorial selection.
    case created(
        question: String,
        languageCode: String,
        intent: GlifiAnalyticalIntent,
        planArtifactID: ArtifactID,
        interpretationArtifactID: ArtifactID,
        availableFindingIDs: [FindingID],
        selectedFindingIDs: [FindingID]
    )
    /// Produces a new editorial branch from an existing history event.
    case editorialSelectionChanged(
        selectedFindingIDs: [FindingID],
        reasonIdentifier: String
    )
}

/// One immutable cognitive event in an append-only investigation history graph.
public struct GlifiInvestigationEvent: Codable, Equatable, Sendable {
    /// Stable event schema.
    public static let schemaIdentifier = "studio.glifi.investigation-event"
    /// Current event schema version.
    public static let schemaVersion = 1
    private static let maximumFindingCount = 10_000

    /// Stable schema encoded with the event.
    public let schemaIdentifier: String
    /// Event schema version encoded with the event.
    public let schemaVersion: Int
    /// Aggregate that owns this event.
    public let investigationID: InvestigationID
    /// Previous event on this branch, absent only at creation.
    public let predecessorEventID: InvestigationEventID?
    /// Non-negative wall-clock time used for history presentation and audit.
    public let recordedAtUnixMilliseconds: Int64
    /// Privacy-preserving actor class that caused the event.
    public let actor: GlifiInvestigationActor
    /// Typed semantic change carried by the event.
    public let payload: GlifiInvestigationEventPayload

    /// Creates and validates an immutable history event.
    public init(
        investigationID: InvestigationID,
        predecessorEventID: InvestigationEventID?,
        recordedAtUnixMilliseconds: Int64,
        actor: GlifiInvestigationActor,
        payload: GlifiInvestigationEventPayload
    ) throws {
        schemaIdentifier = Self.schemaIdentifier
        schemaVersion = Self.schemaVersion
        self.investigationID = investigationID
        self.predecessorEventID = predecessorEventID
        self.recordedAtUnixMilliseconds = recordedAtUnixMilliseconds
        self.actor = actor
        self.payload = payload
        try validate()
    }

    /// Returns the content identity of this exact canonical event.
    public func eventID() throws -> InvestigationEventID {
        let data = try investigationCanonicalJSON(self)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return try InvestigationEventID(digest: "sha256:\(digest)")
    }

    private enum CodingKeys: String, CodingKey {
        case schemaIdentifier, schemaVersion, investigationID, predecessorEventID
        case recordedAtUnixMilliseconds, actor, payload
    }

    /// Decodes only the supported schema and revalidates every event invariant.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaIdentifier = try container.decode(String.self, forKey: .schemaIdentifier)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        investigationID = try container.decode(InvestigationID.self, forKey: .investigationID)
        predecessorEventID = try container.decodeIfPresent(
            InvestigationEventID.self,
            forKey: .predecessorEventID
        )
        recordedAtUnixMilliseconds = try container.decode(
            Int64.self,
            forKey: .recordedAtUnixMilliseconds
        )
        actor = try container.decode(GlifiInvestigationActor.self, forKey: .actor)
        payload = try container.decode(GlifiInvestigationEventPayload.self, forKey: .payload)
        try validate()
    }

    private func validate() throws {
        guard schemaIdentifier == Self.schemaIdentifier,
            schemaVersion == Self.schemaVersion,
            recordedAtUnixMilliseconds >= 0
        else {
            throw investigationFailure("investigation.invalid-event")
        }
        switch payload {
        case let .created(
            question,
            languageCode,
            _,
            _,
            _,
            availableFindingIDs,
            selectedFindingIDs
        ):
            guard predecessorEventID == nil,
                !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                question.utf8.count <= 32_768,
                validLanguageCode(languageCode),
                availableFindingIDs.count <= Self.maximumFindingCount,
                selectedFindingIDs.count <= Self.maximumFindingCount,
                unique(availableFindingIDs),
                unique(selectedFindingIDs),
                Set(selectedFindingIDs).isSubset(of: Set(availableFindingIDs))
            else {
                throw investigationFailure("investigation.invalid-creation")
            }
        case let .editorialSelectionChanged(selectedFindingIDs, reasonIdentifier):
            guard predecessorEventID != nil,
                selectedFindingIDs.count <= Self.maximumFindingCount,
                unique(selectedFindingIDs),
                !reasonIdentifier.isEmpty,
                reasonIdentifier.utf8.count <= 256
            else {
                throw investigationFailure("investigation.invalid-selection")
            }
        }
    }
}

/// Reconstructed authoritative state at one head of the history graph.
public struct GlifiInvestigation: Equatable, Sendable {
    /// Stable aggregate identity.
    public let id: InvestigationID
    /// Event that selects this exact branch state.
    public let headEventID: InvestigationEventID
    /// Original question retained verbatim.
    public let question: String
    /// BCP 47-style language identifier of the original question.
    public let languageCode: String
    /// Canonical analytical intention independent from localized text.
    public let intent: GlifiAnalyticalIntent
    /// Persisted plan that governed the interpretation.
    public let planArtifactID: ArtifactID
    /// Persisted Evidence/Finding/Caveat result selected by the investigation.
    public let interpretationArtifactID: ArtifactID
    /// Ranked findings available when the investigation was created.
    public let availableFindingIDs: [FindingID]
    /// Ordered editorial subset at this branch head.
    public let selectedFindingIDs: [FindingID]
    /// Ordered root-to-head event path.
    public let eventIDs: [InvestigationEventID]

    /// Replays one branch and rejects missing, cyclic, or cross-investigation history.
    public init(
        headEventID: InvestigationEventID,
        eventsByID: [InvestigationEventID: GlifiInvestigationEvent]
    ) throws {
        var reversed: [(InvestigationEventID, GlifiInvestigationEvent)] = []
        var visited = Set<InvestigationEventID>()
        var cursor: InvestigationEventID? = headEventID
        while let eventID = cursor {
            guard visited.insert(eventID).inserted, let event = eventsByID[eventID] else {
                throw investigationFailure("investigation.invalid-history")
            }
            reversed.append((eventID, event))
            cursor = event.predecessorEventID
        }
        let branch = reversed.reversed()
        guard let first = branch.first,
            case let .created(
                question,
                languageCode,
                intent,
                planArtifactID,
                interpretationArtifactID,
                availableFindingIDs,
                initialSelection
            ) = first.1.payload,
            branch.allSatisfy({ $0.1.investigationID == first.1.investigationID })
        else {
            throw investigationFailure("investigation.invalid-history")
        }
        var selection = initialSelection
        for (_, event) in branch.dropFirst() {
            guard case let .editorialSelectionChanged(nextSelection, _) = event.payload,
                Set(nextSelection).isSubset(of: Set(availableFindingIDs))
            else {
                throw investigationFailure("investigation.invalid-history")
            }
            selection = nextSelection
        }
        id = first.1.investigationID
        self.headEventID = headEventID
        self.question = question
        self.languageCode = languageCode
        self.intent = intent
        self.planArtifactID = planArtifactID
        self.interpretationArtifactID = interpretationArtifactID
        self.availableFindingIDs = availableFindingIDs
        selectedFindingIDs = selection
        eventIDs = branch.map(\.0)
    }
}

/// Validated request that establishes one persistent investigation.
public struct GlifiInvestigationCreationRequest: Equatable, Sendable {
    private static let maximumFindingCount = 10_000
    /// Non-empty original question.
    public let question: String
    /// Language identifier of the original question.
    public let languageCode: String
    /// Current interpretation from which findings can be selected.
    public let interpretationArtifactID: ArtifactID
    /// `nil` selects all ranked findings; an empty array explicitly selects none.
    public let selectedFindingIDs: [FindingID]?

    /// Creates a bounded request without silently normalizing content or identity.
    public init(
        question: String,
        languageCode: String = "it",
        interpretationArtifactID: ArtifactID,
        selectedFindingIDs: [FindingID]? = nil
    ) throws {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            question.utf8.count <= 32_768,
            validLanguageCode(languageCode),
            selectedFindingIDs.map({ $0.count <= Self.maximumFindingCount }) ?? true,
            selectedFindingIDs.map(unique) ?? true
        else {
            throw investigationFailure("investigation.invalid-request", category: .invalidInput)
        }
        self.question = question
        self.languageCode = languageCode
        self.interpretationArtifactID = interpretationArtifactID
        self.selectedFindingIDs = selectedFindingIDs
    }
}

/// Validated request that appends an editorial-selection branch.
public struct GlifiInvestigationSelectionRequest: Equatable, Sendable {
    private static let maximumFindingCount = 10_000
    /// Investigation to revise.
    public let investigationID: InvestigationID
    /// Existing head from which the new branch continues.
    public let predecessorEventID: InvestigationEventID
    /// Ordered editorial subset for the new head.
    public let selectedFindingIDs: [FindingID]
    /// Stable semantic reason, never localized presentation text.
    public let reasonIdentifier: String

    /// Creates a bounded editorial-selection request.
    public init(
        investigationID: InvestigationID,
        predecessorEventID: InvestigationEventID,
        selectedFindingIDs: [FindingID],
        reasonIdentifier: String
    ) throws {
        guard selectedFindingIDs.count <= Self.maximumFindingCount,
            unique(selectedFindingIDs), !reasonIdentifier.isEmpty,
            reasonIdentifier.utf8.count <= 256
        else {
            throw investigationFailure("investigation.invalid-request", category: .invalidInput)
        }
        self.investigationID = investigationID
        self.predecessorEventID = predecessorEventID
        self.selectedFindingIDs = selectedFindingIDs
        self.reasonIdentifier = reasonIdentifier
    }
}

/// One committed investigation head with explicit project-generation lineage.
public struct GlifiProjectInvestigationResult: Equatable, Sendable {
    /// Project that owns the investigation.
    public let projectID: ProjectID
    /// Authoritative generation committed by the event.
    public let generation: Int
    /// Reconstructed state at the committed head.
    public let investigation: GlifiInvestigation
}

private func investigationCanonicalJSON(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
}

private func unique<T: Hashable>(_ values: [T]) -> Bool {
    Set(values).count == values.count
}

private func validLanguageCode(_ value: String) -> Bool {
    guard !value.isEmpty, value.utf8.count <= 64,
        value.first != "-", value.last != "-", !value.contains("--")
    else { return false }
    return value.utf8.allSatisfy { byte in
        (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
            || byte == 45
    }
}

private func investigationFailure(
    _ code: String,
    category: GlifiFailureCategory = .invariantViolation
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .investigate,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category, preferred: .unchanged),
        messageKey: "failure.\(code)"
    )
}
