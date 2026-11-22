// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Versioned machine request for creating a persistent investigation.
public struct GlifiStudioInvestigationCreationRequest: Codable, Equatable, Sendable {
    /// Stable request schema.
    public static let schemaIdentifier = "studio.glifi.api.investigation-create-request"
    /// Current request schema version.
    public static let schemaVersion = 1

    /// Stable schema encoded in machine requests.
    public let schemaIdentifier: String
    /// Schema version encoded in machine requests.
    public let schemaVersion: Int
    /// Original non-empty question.
    public let question: String
    /// Language identifier of the original question.
    public let languageCode: String
    /// Interpretation Artifact from which findings may be selected.
    public let interpretationArtifactID: String
    /// Absent selects every ranked finding; an empty list explicitly selects none.
    public let selectedFindingIDs: [String]?

    /// Creates a schema-versioned presentation request.
    public init(
        question: String,
        languageCode: String = "it",
        interpretationArtifactID: String,
        selectedFindingIDs: [String]? = nil
    ) {
        schemaIdentifier = Self.schemaIdentifier
        schemaVersion = Self.schemaVersion
        self.question = question
        self.languageCode = languageCode
        self.interpretationArtifactID = interpretationArtifactID
        self.selectedFindingIDs = selectedFindingIDs
    }

    func coreValue() throws -> GlifiInvestigationCreationRequest {
        guard schemaIdentifier == Self.schemaIdentifier, schemaVersion == Self.schemaVersion else {
            throw presentationFailure("investigation.request-schema-unsupported")
        }
        return try GlifiInvestigationCreationRequest(
            question: question,
            languageCode: languageCode,
            interpretationArtifactID: ArtifactID(canonicalValue: interpretationArtifactID),
            selectedFindingIDs: try selectedFindingIDs?.map(FindingID.init(canonicalValue:))
        )
    }
}

/// Versioned machine request for appending an editorial-selection branch.
public struct GlifiStudioInvestigationSelectionRequest: Codable, Equatable, Sendable {
    /// Stable request schema.
    public static let schemaIdentifier = "studio.glifi.api.investigation-selection-request"
    /// Current request schema version.
    public static let schemaVersion = 1

    /// Stable schema encoded in machine requests.
    public let schemaIdentifier: String
    /// Schema version encoded in machine requests.
    public let schemaVersion: Int
    /// Canonical InvestigationID string.
    public let investigationID: String
    /// Canonical predecessor InvestigationEventID string.
    public let predecessorEventID: String
    /// Ordered canonical FindingID strings selected for the new head.
    public let selectedFindingIDs: [String]
    /// Stable, non-localized semantic reason.
    public let reasonIdentifier: String

    /// Creates a schema-versioned editorial-selection request.
    public init(
        investigationID: String,
        predecessorEventID: String,
        selectedFindingIDs: [String],
        reasonIdentifier: String
    ) {
        schemaIdentifier = Self.schemaIdentifier
        schemaVersion = Self.schemaVersion
        self.investigationID = investigationID
        self.predecessorEventID = predecessorEventID
        self.selectedFindingIDs = selectedFindingIDs
        self.reasonIdentifier = reasonIdentifier
    }

    func coreValue() throws -> GlifiInvestigationSelectionRequest {
        guard schemaIdentifier == Self.schemaIdentifier, schemaVersion == Self.schemaVersion else {
            throw presentationFailure("investigation.request-schema-unsupported")
        }
        return try GlifiInvestigationSelectionRequest(
            investigationID: InvestigationID(canonicalValue: investigationID),
            predecessorEventID: InvestigationEventID(canonicalValue: predecessorEventID),
            selectedFindingIDs: try selectedFindingIDs.map(FindingID.init(canonicalValue:)),
            reasonIdentifier: reasonIdentifier
        )
    }
}

/// Presentation-independent investigation branch state.
public struct GlifiStudioInvestigation: Codable, Equatable, Identifiable, Sendable {
    /// Canonical InvestigationID string.
    public let id: String
    /// Canonical event identity selecting this branch.
    public let headEventID: String
    /// Original question.
    public let question: String
    /// Language identifier of the original question.
    public let languageCode: String
    /// Stable analytical-intent identifier.
    public let intent: String
    /// Canonical plan ArtifactID string.
    public let planArtifactID: String
    /// Canonical interpretation ArtifactID string.
    public let interpretationArtifactID: String
    /// Ranked available FindingID strings.
    public let availableFindingIDs: [String]
    /// Ordered selected FindingID strings.
    public let selectedFindingIDs: [String]
    /// Ordered root-to-head InvestigationEventID strings.
    public let eventIDs: [String]

    init(_ value: GlifiInvestigation) {
        id = value.id.canonicalValue
        headEventID = value.headEventID.canonicalValue
        question = value.question
        languageCode = value.languageCode
        intent = value.intent.rawValue
        planArtifactID = value.planArtifactID.canonicalValue
        interpretationArtifactID = value.interpretationArtifactID.canonicalValue
        availableFindingIDs = value.availableFindingIDs.map(\.canonicalValue)
        selectedFindingIDs = value.selectedFindingIDs.map(\.canonicalValue)
        eventIDs = value.eventIDs.map(\.canonicalValue)
    }
}

/// Result of a durable investigation-history commit.
public struct GlifiStudioInvestigationResult: Codable, Equatable, Sendable {
    /// Canonical project identity.
    public let projectID: String
    /// Authoritative generation committed by the operation.
    public let generation: Int
    /// Reconstructed branch state.
    public let investigation: GlifiStudioInvestigation

    init(_ value: GlifiProjectInvestigationResult) {
        projectID = value.projectID.canonicalValue
        generation = value.generation
        investigation = GlifiStudioInvestigation(value.investigation)
    }
}

func presentationFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: .invalidInput,
        operation: .investigate,
        retryDisposition: .afterCorrection,
        retainedState: .unchanged,
        messageKey: "failure.\(code)"
    )
}
