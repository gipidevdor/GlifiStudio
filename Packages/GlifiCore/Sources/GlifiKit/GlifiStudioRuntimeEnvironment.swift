// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import Synchronization

/// Presentation-safe thermal conditions, independent from AppKit and Core types.
public enum GlifiStudioThermalCondition: String, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

/// Last memory-pressure signal observed by the platform adapter.
public enum GlifiStudioMemoryPressure: String, Equatable, Sendable {
    case nominal
    case warning
    case critical
}

/// Immutable system signals used for admission without changing scientific parameters.
public struct GlifiStudioSystemConditions: Equatable, Sendable {
    /// Whether Low Power Mode is enabled.
    public let isLowPowerModeEnabled: Bool
    /// Last observed thermal condition.
    public let thermalCondition: GlifiStudioThermalCondition
    /// Last observed memory-pressure condition.
    public let memoryPressure: GlifiStudioMemoryPressure
    /// Whether the application is active.
    public let isApplicationActive: Bool

    /// Preserves the explicit signals supplied by a platform adapter or a test.
    public init(
        isLowPowerModeEnabled: Bool,
        thermalCondition: GlifiStudioThermalCondition,
        memoryPressure: GlifiStudioMemoryPressure,
        isApplicationActive: Bool
    ) {
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalCondition = thermalCondition
        self.memoryPressure = memoryPressure
        self.isApplicationActive = isApplicationActive
    }

    /// Reads energy and thermal state; memory and application activity stay explicit.
    ///
    /// Reading thermal state initializes its notifications before an adapter registers them.
    /// An unknown future thermal state is treated conservatively as serious.
    public static func current(
        memoryPressure: GlifiStudioMemoryPressure,
        isApplicationActive: Bool,
        processInfo: ProcessInfo = .processInfo
    ) -> Self {
        let thermal: GlifiStudioThermalCondition
        switch processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .serious
        }
        return Self(
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalCondition: thermal,
            memoryPressure: memoryPressure,
            isApplicationActive: isApplicationActive
        )
    }

    var coreValue: GlifiSystemConditions {
        let thermal: GlifiThermalCondition
        switch thermalCondition {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        }
        let memory: GlifiMemoryPressure
        switch memoryPressure {
        case .nominal: memory = .nominal
        case .warning: memory = .warning
        case .critical: memory = .critical
        }
        return GlifiSystemConditions(
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            thermalCondition: thermal,
            memoryPressure: memory,
            isApplicationActive: isApplicationActive
        )
    }
}

/// A fixed-size, synchronized snapshot shared by event callbacks and runtime admission.
public final class GlifiStudioSystemConditionsStore: Sendable {
    private let conditions: Mutex<GlifiStudioSystemConditions>

    /// Starts with an explicit snapshot, including any conservative unobserved state.
    public init(_ initialConditions: GlifiStudioSystemConditions) {
        conditions = Mutex(initialConditions)
    }

    /// Reads the latest complete snapshot in O(1), without an actor hop or allocation.
    public func snapshot() -> GlifiStudioSystemConditions {
        conditions.withLock { $0 }
    }

    /// Atomically replaces all signals in O(1), without retaining an event history.
    public func update(_ snapshot: GlifiStudioSystemConditions) {
        conditions.withLock { $0 = snapshot }
    }

    /// Updates energy and activity atomically while preserving concurrent memory signals.
    public func updateEnergyAndActivity(_ snapshot: GlifiStudioSystemConditions) {
        conditions.withLock { current in
            current = GlifiStudioSystemConditions(
                isLowPowerModeEnabled: snapshot.isLowPowerModeEnabled,
                thermalCondition: snapshot.thermalCondition,
                memoryPressure: current.memoryPressure,
                isApplicationActive: snapshot.isApplicationActive
            )
        }
    }

    /// Updates memory pressure atomically while preserving concurrent energy signals.
    public func updateMemoryPressure(_ memoryPressure: GlifiStudioMemoryPressure) {
        conditions.withLock { current in
            current = GlifiStudioSystemConditions(
                isLowPowerModeEnabled: current.isLowPowerModeEnabled,
                thermalCondition: current.thermalCondition,
                memoryPressure: memoryPressure,
                isApplicationActive: current.isApplicationActive
            )
        }
    }

    /// Rejects new long work conservatively after the platform observer is stopped.
    public func markUnavailable() {
        conditions.withLock { current in
            current = GlifiStudioSystemConditions(
                isLowPowerModeEnabled: current.isLowPowerModeEnabled,
                thermalCondition: current.thermalCondition,
                memoryPressure: .critical,
                isApplicationActive: false
            )
        }
    }
}

/// Injected runtime signals shared by a service and its project sessions.
public struct GlifiStudioRuntimeEnvironment: Sendable {
    private let readSnapshot: @Sendable () -> GlifiStudioSystemConditions

    /// Creates a provider whose reads must be bounded, synchronous and free from polling.
    public init(snapshot: @escaping @Sendable () -> GlifiStudioSystemConditions) {
        readSnapshot = snapshot
    }

    /// Creates an environment backed by a synchronized event-driven store.
    public init(store: GlifiStudioSystemConditionsStore) {
        self.init(snapshot: { store.snapshot() })
    }

    /// Compatibility environment for headless clients without application lifecycle signals.
    ///
    /// Energy and thermal state are read at admission; memory is nominal and activity true.
    /// Native applications supply an observed environment instead of this bootstrap policy.
    public static var headless: Self {
        Self {
            .current(memoryPressure: .nominal, isApplicationActive: true)
        }
    }

    /// Returns the latest immutable system conditions without subscribing or scheduling work.
    public func snapshot() -> GlifiStudioSystemConditions {
        readSnapshot()
    }

    func admit(
        operation: GlifiOperationKind,
        intent: GlifiWorkIntent = .userInitiated
    ) throws(GlifiStudioFailure) {
        let retainedState: GlifiRetainedState =
            operation == .profileCollection ? .unchanged : .lastCommittedGeneration
        guard !Task.isCancelled else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "operation.cancelled",
                    category: .cancelled,
                    operation: operation,
                    retryDisposition: .newRequest,
                    retainedState: retainedState,
                    messageKey: "failure.operation.cancelled"
                ))
        }
        let recommendation = GlifiRuntimePolicy.recommendation(
            for: intent, conditions: snapshot().coreValue)
        guard recommendation.allowsNewWork else {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "runtime.admission-denied",
                    category: .insufficientResources,
                    operation: operation,
                    retryDisposition: .afterConditionsChange,
                    retainedState: retainedState,
                    messageKey: "failure.runtime.admission-denied",
                    arguments: ["operatingProfile": recommendation.profile.rawValue]
                ))
        }
    }
}
