// SPDX-License-Identifier: BSD-3-Clause

import AppKit
import Dispatch
import Foundation
import GlifiKit

enum StudioMacRuntimeEvent: Sendable {
    case energyOrActivityChanged
    case memoryPressure(GlifiStudioMemoryPressure)
    case terminating
}

@MainActor
protocol StudioMacRuntimeEventSource: AnyObject {
    func readEnergyAndActivity() -> GlifiStudioSystemConditions
    func start(_ receive: @escaping @MainActor @Sendable (StudioMacRuntimeEvent) -> Void)
    func stop()
}

/// Owns passive system observers and publishes fixed-size runtime snapshots without polling.
@MainActor
final class StudioMacRuntimeMonitor {
    let environment: GlifiStudioRuntimeEnvironment

    private let source: any StudioMacRuntimeEventSource
    private let store: GlifiStudioSystemConditionsStore
    private var isObserving = false
    private var observationRevision: UInt64 = 0

    /// Reads thermal state before registration; memory remains unobserved until an event.
    init(source: any StudioMacRuntimeEventSource = StudioMacSystemRuntimeEvents()) {
        self.source = source
        let initial = source.readEnergyAndActivity()
        let store = GlifiStudioSystemConditionsStore(
            GlifiStudioSystemConditions(
                isLowPowerModeEnabled: initial.isLowPowerModeEnabled,
                thermalCondition: initial.thermalCondition,
                memoryPressure: .warning,
                isApplicationActive: initial.isApplicationActive
            ))
        self.store = store
        environment = GlifiStudioRuntimeEnvironment(store: store)
    }

    isolated deinit {
        stop()
    }

    /// Registers once and refreshes signals after registration to close the setup window.
    func start() {
        guard !isObserving else { return }
        store.updateEnergyAndActivity(source.readEnergyAndActivity())
        store.updateMemoryPressure(.warning)
        observationRevision &+= 1
        let revision = observationRevision
        isObserving = true
        source.start { [weak self] event in
            guard let self, self.isObserving, self.observationRevision == revision else { return }
            switch event {
            case .energyOrActivityChanged:
                self.store.updateEnergyAndActivity(self.source.readEnergyAndActivity())
            case let .memoryPressure(pressure):
                self.store.updateMemoryPressure(pressure)
            case .terminating:
                self.stop()
            }
        }
        guard isObserving, observationRevision == revision else { return }
        store.updateEnergyAndActivity(source.readEnergyAndActivity())
    }

    /// Cancels observers idempotently and rejects work if an injected service outlives them.
    func stop() {
        guard isObserving else {
            store.markUnavailable()
            return
        }
        isObserving = false
        observationRevision &+= 1
        source.stop()
        store.markUnavailable()
    }
}

/// AppKit remains at the application boundary; no native app lifecycle enters GlifiCore.
@MainActor
private final class StudioMacSystemRuntimeEvents: StudioMacRuntimeEventSource {
    private let notifications = NotificationCenter.default
    private var observers: [any NSObjectProtocol] = []
    private var pressureSource: (any DispatchSourceMemoryPressure)?

    isolated deinit {
        stop()
    }

    func readEnergyAndActivity() -> GlifiStudioSystemConditions {
        .current(memoryPressure: .warning, isApplicationActive: NSApplication.shared.isActive)
    }

    func start(_ receive: @escaping @MainActor @Sendable (StudioMacRuntimeEvent) -> Void) {
        guard observers.isEmpty, pressureSource == nil else { return }
        for name in [
            Notification.Name.NSProcessInfoPowerStateDidChange,
            ProcessInfo.thermalStateDidChangeNotification,
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
        ] {
            observers.append(
                notifications.addObserver(forName: name, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated { receive(.energyOrActivityChanged) }
                })
        }
        observers.append(
            notifications.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { receive(.terminating) }
            })
        let pressure = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical], queue: .main)
        pressureSource = pressure
        pressure.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let events = self?.pressureSource?.data else { return }
                let state: GlifiStudioMemoryPressure
                if events.contains(.critical) {
                    state = .critical
                } else if events.contains(.warning) {
                    state = .warning
                } else if events == .normal {
                    state = .nominal
                } else {
                    state = .warning
                }
                receive(.memoryPressure(state))
            }
        }
        pressure.activate()
    }

    func stop() {
        for observer in observers {
            notifications.removeObserver(observer)
        }
        observers.removeAll(keepingCapacity: false)
        pressureSource?.setEventHandler(handler: nil)
        pressureSource?.cancel()
        pressureSource = nil
    }
}
