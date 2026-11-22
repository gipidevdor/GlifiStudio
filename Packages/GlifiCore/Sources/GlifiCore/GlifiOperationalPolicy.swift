// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Declares the privacy boundary for operational data in the 0.1 product.
public enum GlifiTelemetryPolicy {
    /// Glifi Studio doesn't transmit product analytics or operational telemetry.
    public static let allowsRemoteTelemetry = false

    /// Glifi Studio doesn't embed third-party telemetry SDKs.
    public static let allowsThirdPartyTelemetry = false

    /// Diagnostic material is never exported without an explicit user action.
    public static let allowsAutomaticDiagnosticExport = false

    /// Corpus content, queries, excerpts, prompts, and paths aren't diagnostic data.
    public static let allowsCorpusContentInDiagnostics = false
}

/// Describes why work is being performed so the system can schedule it appropriately.
public enum GlifiWorkIntent: String, Sendable, Equatable, CaseIterable {
    case interactive
    case userInitiated
    case utility
    case maintenance
}

/// Represents the thermal signal exposed by the operating system.
public enum GlifiThermalCondition: String, Sendable, Equatable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical

    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .serious
        }
    }
}

/// Represents memory pressure reported by a platform adapter.
public enum GlifiMemoryPressure: String, Sendable, Equatable, CaseIterable {
    case nominal
    case warning
    case critical
}

/// Captures the system conditions relevant to one scheduling decision.
public struct GlifiSystemConditions: Sendable, Equatable {
    /// Whether the person enabled Low Power Mode.
    public let isLowPowerModeEnabled: Bool

    /// The thermal state observed for the current scheduling decision.
    public let thermalCondition: GlifiThermalCondition

    /// The memory-pressure state supplied by the platform adapter.
    public let memoryPressure: GlifiMemoryPressure

    /// Whether the application is active when the decision is made.
    public let isApplicationActive: Bool

    /// Creates an immutable snapshot of the system conditions.
    public init(
        isLowPowerModeEnabled: Bool,
        thermalCondition: GlifiThermalCondition,
        memoryPressure: GlifiMemoryPressure,
        isApplicationActive: Bool
    ) {
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalCondition = thermalCondition
        self.memoryPressure = memoryPressure
        self.isApplicationActive = isApplicationActive
    }

    /// Reads the energy and thermal state without inferring memory pressure.
    ///
    /// A platform adapter supplies memory pressure and application activity from event-driven
    /// system notifications. Defaults are suitable only for bootstrap work.
    public static func current(
        processInfo: ProcessInfo = .processInfo,
        memoryPressure: GlifiMemoryPressure = .nominal,
        isApplicationActive: Bool = true
    ) -> Self {
        Self(
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalCondition: GlifiThermalCondition(processInfo.thermalState),
            memoryPressure: memoryPressure,
            isApplicationActive: isApplicationActive
        )
    }
}

/// Identifies the resource profile selected for a unit of work.
public enum GlifiOperatingProfile: String, Sendable, Equatable {
    case responsive
    case balanced
    case constrained
    case protective
    case suspended
}

/// Mirrors the intent classes used to map work to an Apple quality-of-service class.
public enum GlifiWorkPriority: String, Sendable, Equatable {
    case userInteractive
    case userInitiated
    case utility
    case background
}

/// Provides an enforceable recommendation to the runtime scheduler.
public struct GlifiExecutionRecommendation: Sendable, Equatable {
    /// The operating profile selected by the policy.
    public let profile: GlifiOperatingProfile

    /// The quality-of-service intent that the scheduler must preserve.
    public let priority: GlifiWorkPriority

    /// The largest number of work units the scheduler may run concurrently.
    public let maximumParallelism: Int

    /// Whether the scheduler may admit a new unit of work.
    public let allowsNewWork: Bool

    /// Whether work without a direct user request is allowed.
    public let allowsSpeculativeWork: Bool

    /// Whether existing recoverable work should checkpoint at its next safe boundary.
    public let shouldCheckpoint: Bool

    /// Creates an enforceable scheduling recommendation.
    public init(
        profile: GlifiOperatingProfile,
        priority: GlifiWorkPriority,
        maximumParallelism: Int,
        allowsNewWork: Bool,
        allowsSpeculativeWork: Bool,
        shouldCheckpoint: Bool
    ) {
        self.profile = profile
        self.priority = priority
        self.maximumParallelism = maximumParallelism
        self.allowsNewWork = allowsNewWork
        self.allowsSpeculativeWork = allowsSpeculativeWork
        self.shouldCheckpoint = shouldCheckpoint
    }
}

/// Converts user intent and system pressure into a deterministic scheduling profile.
public enum GlifiRuntimePolicy {
    /// Selects the scheduling profile for one unit of work.
    ///
    /// - Parameters:
    ///   - intent: The user-facing reason for performing the work.
    ///   - conditions: An immutable snapshot of system pressure and app activity.
    ///   - availableProcessorCount: The processor capacity reported by the system.
    /// - Returns: Bounded admission, priority, parallelism, and checkpoint guidance.
    public static func recommendation(
        for intent: GlifiWorkIntent,
        conditions: GlifiSystemConditions,
        availableProcessorCount: Int = ProcessInfo.processInfo.activeProcessorCount
    ) -> GlifiExecutionRecommendation {
        let processorLimit = min(max(availableProcessorCount, 1), 8)
        let priority = priority(for: intent)

        if conditions.memoryPressure == .critical
            || conditions.thermalCondition == .critical
        {
            return GlifiExecutionRecommendation(
                profile: .protective,
                priority: priority,
                maximumParallelism: intent == .interactive ? 1 : 0,
                allowsNewWork: intent == .interactive,
                allowsSpeculativeWork: false,
                shouldCheckpoint: intent != .interactive
            )
        }

        if !conditions.isApplicationActive && intent.isDiscretionary {
            return GlifiExecutionRecommendation(
                profile: .suspended,
                priority: priority,
                maximumParallelism: 0,
                allowsNewWork: false,
                allowsSpeculativeWork: false,
                shouldCheckpoint: true
            )
        }

        if conditions.isLowPowerModeEnabled
            || conditions.thermalCondition == .serious
            || conditions.memoryPressure == .warning
        {
            let acceptsWork = intent == .interactive || intent == .userInitiated
            return GlifiExecutionRecommendation(
                profile: .constrained,
                priority: priority,
                maximumParallelism: acceptsWork ? min(processorLimit, 2) : 0,
                allowsNewWork: acceptsWork,
                allowsSpeculativeWork: false,
                shouldCheckpoint: intent.isDiscretionary
            )
        }

        if conditions.thermalCondition == .fair {
            return GlifiExecutionRecommendation(
                profile: .balanced,
                priority: priority,
                maximumParallelism: max(1, processorLimit / 2),
                allowsNewWork: true,
                allowsSpeculativeWork: false,
                shouldCheckpoint: false
            )
        }

        return GlifiExecutionRecommendation(
            profile: intent == .interactive ? .responsive : .balanced,
            priority: priority,
            maximumParallelism: normalParallelism(for: intent, processorLimit: processorLimit),
            allowsNewWork: true,
            allowsSpeculativeWork: conditions.isApplicationActive,
            shouldCheckpoint: false
        )
    }

    private static func priority(for intent: GlifiWorkIntent) -> GlifiWorkPriority {
        switch intent {
        case .interactive:
            .userInteractive
        case .userInitiated:
            .userInitiated
        case .utility:
            .utility
        case .maintenance:
            .background
        }
    }

    private static func normalParallelism(
        for intent: GlifiWorkIntent,
        processorLimit: Int
    ) -> Int {
        switch intent {
        case .interactive:
            min(processorLimit, 2)
        case .userInitiated:
            processorLimit
        case .utility:
            max(1, processorLimit / 2)
        case .maintenance:
            1
        }
    }
}

private extension GlifiWorkIntent {
    var isDiscretionary: Bool {
        self == .utility || self == .maintenance
    }
}
