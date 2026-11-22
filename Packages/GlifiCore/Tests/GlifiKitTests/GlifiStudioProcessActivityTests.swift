// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore
import Synchronization
import Testing

@testable import GlifiKit

private final class ActivityCounts: Sendable {
    private let state = Mutex((began: 0, ended: 0))

    var snapshot: (began: Int, ended: Int) { state.withLock { $0 } }

    var provider: GlifiStudioActivityProvider {
        GlifiStudioActivityProvider {
            self.state.withLock { $0.began += 1 }
            return GlifiStudioProcessActivity {
                self.state.withLock { $0.ended += 1 }
            }
        }
    }
}

private enum ActivityTestFailure: Error { case expected }

@Test("Un'attività termina una volta sola anche con chiusure concorrenti")
func processActivityEndsExactlyOnce() async {
    let counts = ActivityCounts()
    let activity = counts.provider.begin()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<100 { group.addTask { activity.end() } }
    }
    #expect(counts.snapshot.began == 1)
    #expect(counts.snapshot.ended == 1)
}

@Test("La chiusura reentrante non trattiene il lock dell'attività")
func processActivityAllowsReentrantCleanup() {
    let holder = Mutex<GlifiStudioProcessActivity?>(nil)
    let endings = Mutex(0)
    let activity = GlifiStudioProcessActivity {
        endings.withLock { $0 += 1 }
        holder.withLock { $0 }?.end()
    }
    holder.withLock { $0 = activity }
    activity.end()
    holder.withLock { $0 = nil }
    #expect(endings.withLock { $0 } == 1)
}

@Test("La fine dell'attività precede il risultato e conserva la failure originale")
func processActivityPreservesResultAndFailure() async throws {
    let counts = ActivityCounts()
    let value = await counts.provider.perform { 42 }
    #expect(value == 42)
    #expect(counts.snapshot.began == 1)
    #expect(counts.snapshot.ended == 1)
    do {
        _ = try await counts.provider.perform { () async throws -> Int in
            throw ActivityTestFailure.expected
        }
        Issue.record("The expected activity failure was swallowed")
    } catch ActivityTestFailure.expected {
        #expect(counts.snapshot.began == 2)
        #expect(counts.snapshot.ended == 2)
    }
}

@Test("La cancellazione di un'operazione sospesa rilascia l'attività senza attesa attiva")
func processActivityEndsOnCancellation() async throws {
    let counts = ActivityCounts()
    let (started, continuation) = AsyncStream.makeStream(of: Bool.self)
    let task = Task {
        try await counts.provider.perform {
            continuation.yield(true)
            try await Task.sleep(for: .seconds(60))
            return 1
        }
    }
    for await _ in started { break }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    continuation.finish()
    #expect(counts.snapshot.began == 1)
    #expect(counts.snapshot.ended == 1)
}

@Test("Il piano richiesto possiede un'attività finita e la rilascia prima del completamento")
func processActivityCoversOwnedPlanExecution() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiProcessActivity-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let engine = GlifiEngine()
    let project = try await engine.createProject(at: root.appending(path: "Activity.glifi"))
    let counts = ActivityCounts()
    let session = GlifiStudioProjectSession(
        engine: engine, project: project, runtimeEnvironment: activityEnvironment(),
        activityProvider: counts.provider)
    let source = root.appending(path: "source.txt")
    try Data("Una fonte italiana. Una seconda frase della fonte.".utf8).write(to: source)
    _ = try await session.importText(at: source, format: .plainText)
    #expect(counts.snapshot.began == 0)
    let execution = try await session.executeAnalysisPlan(.init(intent: "understand.collection"))
    var completed = false
    for try await event in execution.events {
        if case .completed = event {
            completed = true
            #expect(counts.snapshot.began == 1)
            #expect(counts.snapshot.ended == 1)
        }
    }
    #expect(completed)
    await session.close()
    #expect(counts.snapshot.began == 1)
    #expect(counts.snapshot.ended == 1)
}

@Test("L'admission negata non apre attività di processo")
func processActivityDoesNotCoverRejectedWork() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiRejectedActivity-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let engine = GlifiEngine()
    let project = try await engine.createProject(at: root.appending(path: "Activity.glifi"))
    let counts = ActivityCounts()
    let session = GlifiStudioProjectSession(
        engine: engine, project: project, runtimeEnvironment: activityEnvironment(critical: true),
        activityProvider: counts.provider)
    do {
        _ = try await session.executeAnalysisPlan(.init(intent: "understand.collection"))
        Issue.record("Critical admission unexpectedly succeeded")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "runtime.admission-denied")
    }
    await session.close()
    #expect(counts.snapshot.began == 0)
    #expect(counts.snapshot.ended == 0)
}

private func activityEnvironment(critical: Bool = false) -> GlifiStudioRuntimeEnvironment {
    GlifiStudioRuntimeEnvironment {
        GlifiStudioSystemConditions(
            isLowPowerModeEnabled: false, thermalCondition: .nominal,
            memoryPressure: critical ? .critical : .nominal, isApplicationActive: true)
    }
}
