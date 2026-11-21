// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioMacRuntimeMonitorTests {
    @Test func snapshotsBeforeObservationAndHandlesSignalsWithoutPolling() {
        let source = FakeStudioMacRuntimeEvents()
        let monitor = StudioMacRuntimeMonitor(source: source)
        #expect(source.readCount == 1)
        #expect(monitor.environment.snapshot().memoryPressure == .warning)
        monitor.start()
        monitor.start()
        #expect(source.startCount == 1)
        #expect(source.readCount == 3)
        #expect(source.didReadBeforeStarting)
        source.emit(.memoryPressure(.nominal))
        #expect(monitor.environment.snapshot().memoryPressure == .nominal)
        source.conditions = monitorTestConditions(lowPower: true, thermal: .serious, active: false)
        source.emit(.energyOrActivityChanged)
        let snapshot = monitor.environment.snapshot()
        #expect(snapshot.isLowPowerModeEnabled)
        #expect(snapshot.thermalCondition == .serious)
        #expect(!snapshot.isApplicationActive)
        #expect(snapshot.memoryPressure == .nominal)
        source.emit(.memoryPressure(.critical))
        source.emit(.energyOrActivityChanged)
        #expect(monitor.environment.snapshot().memoryPressure == .critical)
        monitor.stop()
        monitor.stop()
        #expect(source.stopCount == 1)
        #expect(monitor.environment.snapshot().memoryPressure == .critical)
        #expect(!monitor.environment.snapshot().isApplicationActive)
    }

    @Test func ignoresCallbacksAfterStopAndFromPreviousObservation() {
        let source = FakeStudioMacRuntimeEvents()
        let monitor = StudioMacRuntimeMonitor(source: source)
        monitor.start()
        let previous = source.handlers[0]
        monitor.stop()
        previous(.memoryPressure(.nominal))
        #expect(monitor.environment.snapshot().memoryPressure == .critical)
        monitor.start()
        #expect(source.startCount == 2)
        #expect(monitor.environment.snapshot().memoryPressure == .warning)
        source.emit(.memoryPressure(.critical))
        previous(.memoryPressure(.nominal))
        previous(.terminating)
        #expect(monitor.environment.snapshot().memoryPressure == .critical)
        #expect(source.stopCount == 1)
        source.emit(.memoryPressure(.nominal))
        #expect(monitor.environment.snapshot().memoryPressure == .nominal)
        source.emit(.terminating)
        #expect(source.stopCount == 2)
        #expect(monitor.environment.snapshot().memoryPressure == .critical)
    }

    @Test func teardownReleasesObservationAndLeavesSurvivingServiceConservative() {
        let source = FakeStudioMacRuntimeEvents()
        var monitor: StudioMacRuntimeMonitor? = StudioMacRuntimeMonitor(source: source)
        weak let weakMonitor = monitor
        let environment = monitor?.environment
        monitor?.start()
        monitor = nil
        #expect(weakMonitor == nil)
        #expect(source.stopCount == 1)
        #expect(environment?.snapshot().memoryPressure == .critical)
        #expect(environment?.snapshot().isApplicationActive == false)
        source.emit(.memoryPressure(.nominal))
        #expect(environment?.snapshot().memoryPressure == .critical)
    }
}

@MainActor
private final class FakeStudioMacRuntimeEvents: StudioMacRuntimeEventSource {
    var conditions = monitorTestConditions()
    private(set) var readCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var didReadBeforeStarting = false
    private(set) var handlers: [@MainActor @Sendable (StudioMacRuntimeEvent) -> Void] = []

    func readEnergyAndActivity() -> GlifiStudioSystemConditions {
        readCount += 1
        return conditions
    }

    func start(_ receive: @escaping @MainActor @Sendable (StudioMacRuntimeEvent) -> Void) {
        didReadBeforeStarting = readCount > 0
        startCount += 1
        handlers.append(receive)
    }

    func stop() { stopCount += 1 }

    func emit(_ event: StudioMacRuntimeEvent) { handlers.last?(event) }
}

private func monitorTestConditions(
    lowPower: Bool = false, thermal: GlifiStudioThermalCondition = .nominal, active: Bool = true
) -> GlifiStudioSystemConditions {
    GlifiStudioSystemConditions(
        isLowPowerModeEnabled: lowPower, thermalCondition: thermal,
        memoryPressure: .nominal, isApplicationActive: active)
}
