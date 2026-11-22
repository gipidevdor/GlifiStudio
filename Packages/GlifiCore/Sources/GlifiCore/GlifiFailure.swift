// SPDX-License-Identifier: BSD-3-Clause

/// Stable failure categories shared by every headless operation.
public enum GlifiFailureCategory: String, Codable, Sendable, CaseIterable {
    case invalidInput
    case unsupportedFormat
    case insufficientData
    case transientIO
    case authorizationDenied
    case insufficientResources
    case cancelled
    case staleArtifact
    case incompatibleVersion
    case corruption
    case invariantViolation
}

/// Describes when retrying a failed operation can be meaningful.
public enum GlifiRetryDisposition: String, Codable, Sendable {
    case never
    case afterCorrection
    case afterUserAction
    case afterConditionsChange
    case transientBackoff
    case newRequest
}

/// Describes which state remains authoritative after a failure.
public enum GlifiRetainedState: String, Codable, Sendable {
    case unchanged
    case lastCommittedGeneration
    case validatedCheckpoint
    case readOnlyRecovery
    case validityUnknown
}

/// Identifies an operation without exposing paths or corpus content.
public enum GlifiOperationKind: String, Codable, Sendable {
    case serviceStatus
    case importText
    case tokenize
    case profileCollection
    case query
    case plan
    case executePlan
    case investigate
    case export
    case analyze
    case persistProject
}

/// A privacy-safe, localizable failure crossing a GlifiCore boundary.
public struct GlifiFailure: Error, Codable, Equatable, Sendable {
    /// Stable machine-readable code.
    public let code: String
    /// Broad failure category shared by API and CLI.
    public let category: GlifiFailureCategory
    /// Operation that observed the failure.
    public let operation: GlifiOperationKind
    /// Conditions under which a retry is meaningful.
    public let retryDisposition: GlifiRetryDisposition
    /// Authoritative state retained after the failure.
    public let retainedState: GlifiRetainedState
    /// Localization key for human-facing clients.
    public let messageKey: String
    /// Non-sensitive localization arguments.
    public let arguments: [String: String]

    /// Creates a fully classified failure without retaining an underlying error.
    public init(
        code: String,
        category: GlifiFailureCategory,
        operation: GlifiOperationKind,
        retryDisposition: GlifiRetryDisposition,
        retainedState: GlifiRetainedState,
        messageKey: String,
        arguments: [String: String] = [:]
    ) {
        self.code = code
        self.category = category
        self.operation = operation
        self.retryDisposition = retryDisposition
        self.retainedState = retainedState
        self.messageKey = messageKey
        self.arguments = arguments
        assert(
            GlifiFailureTaxonomy.admits(
                category: category, retry: retryDisposition, retained: retainedState),
            "Failure fuori dalla tassonomia GS-API-001 § 8"
        )
    }
}

/// Executable form of the GS-API-001 § 8 failure taxonomy.
public enum GlifiFailureTaxonomy {
    /// Retry dispositions admitted for each category.
    public static let retry: [GlifiFailureCategory: Set<GlifiRetryDisposition>] = [
        .invalidInput: [.afterCorrection],
        .unsupportedFormat: [.afterCorrection],
        .insufficientData: [.afterCorrection],
        .transientIO: [.transientBackoff],
        .authorizationDenied: [.afterUserAction],
        .insufficientResources: [.afterConditionsChange],
        .cancelled: [.newRequest],
        .staleArtifact: [.newRequest],
        .incompatibleVersion: [.never, .afterUserAction],
        .corruption: [.never, .afterUserAction],
        .invariantViolation: [.never],
    ]

    /// Retained states admitted for each category.
    public static let retained: [GlifiFailureCategory: Set<GlifiRetainedState>] = [
        .invalidInput: [.unchanged, .lastCommittedGeneration],
        .unsupportedFormat: [.unchanged, .lastCommittedGeneration],
        .insufficientData: [.unchanged, .lastCommittedGeneration],
        .transientIO: [.unchanged, .lastCommittedGeneration],
        .authorizationDenied: [.unchanged, .lastCommittedGeneration],
        .insufficientResources: [.unchanged, .lastCommittedGeneration, .validatedCheckpoint],
        .cancelled: [.unchanged, .lastCommittedGeneration, .validatedCheckpoint],
        .staleArtifact: [.unchanged, .lastCommittedGeneration],
        .incompatibleVersion: [.unchanged, .readOnlyRecovery],
        .corruption: [.lastCommittedGeneration, .readOnlyRecovery],
        .invariantViolation: [.validityUnknown],
    ]

    /// Canonical retry disposition of a category.
    public static func defaultRetry(_ category: GlifiFailureCategory) -> GlifiRetryDisposition {
        switch category {
        case .invalidInput, .unsupportedFormat, .insufficientData: .afterCorrection
        case .transientIO: .transientBackoff
        case .authorizationDenied: .afterUserAction
        case .insufficientResources: .afterConditionsChange
        case .cancelled, .staleArtifact: .newRequest
        case .incompatibleVersion, .corruption, .invariantViolation: .never
        }
    }

    /// `preferred` when the category admits it, otherwise the category's canonical state.
    public static func defaultRetained(
        _ category: GlifiFailureCategory,
        preferred: GlifiRetainedState = .lastCommittedGeneration
    ) -> GlifiRetainedState {
        if (retained[category] ?? []).contains(preferred) {
            return preferred
        }
        switch category {
        case .invariantViolation: return .validityUnknown
        case .incompatibleVersion, .corruption: return .readOnlyRecovery
        default: return .lastCommittedGeneration
        }
    }

    /// Whether the triple respects the taxonomy.
    public static func admits(
        category: GlifiFailureCategory,
        retry: GlifiRetryDisposition,
        retained: GlifiRetainedState
    ) -> Bool {
        (Self.retry[category] ?? []).contains(retry)
            && (Self.retained[category] ?? []).contains(retained)
    }
}
