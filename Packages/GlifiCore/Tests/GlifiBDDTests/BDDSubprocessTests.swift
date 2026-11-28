// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Testing

private struct BDDProcessFixture: Sendable {
    let directory: URL
    var readyFile: URL { directory.appending(path: "ready") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDDProcess-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    func cleanup() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func reportCleanupFailure() {
        do { try cleanup() } catch { Issue.record(error) }
    }

    func waitUntilReady() async throws -> Int32 {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: readyFile.path) {
                let value = try String(contentsOf: readyFile, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return try #require(Int32(value))
            }
            await Task.yield()
        }
        Issue.record("The synthetic child never published its readiness handshake")
        throw BDDProcessFixtureFailure.handshakeMissing
    }
}

private enum BDDProcessFixtureFailure: Error { case handshakeMissing }

// The child publishes readiness atomically after installing its signal policy. The sleep is the
// deliberately blocked workload, never a delay used to guess whether the process has started.
private let blockedBDDProcessScript = """
    trap '' TERM
    printf '%s\\n' "$$" > "$1.tmp"
    /bin/mv "$1.tmp" "$1"
    exec /bin/sleep 600
    """

@Test("Il runner dei sottoprocessi conserva exit status e flussi separati")
func bddSubprocessCapturesBothStreams() async throws {
    let fixture = try BDDProcessFixture()
    defer { fixture.reportCleanupFailure() }
    let result = try await BDDSubprocess.run(
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "printf output; printf diagnostic >&2; exit 7"],
        directory: fixture.directory)
    #expect(result.status == 7)
    #expect(result.stdout == Data("output".utf8))
    #expect(result.stderr == Data("diagnostic".utf8))
    try fixture.cleanup()
}

@Test("La cancellazione preventiva non avvia il programma né apre file di output")
func bddSubprocessDoesNotLaunchWhenCancelled() async throws {
    let fixture = try BDDProcessFixture()
    defer { fixture.reportCleanupFailure() }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await BDDSubprocess.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf launched"], directory: fixture.directory)
    }
    let result = await task.result
    #expect(result.failure as? BDDSubprocessFailure == .cancelled)
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).isEmpty)
    try fixture.cleanup()
}

@Test("La cancellazione termina e raccoglie anche un figlio che ignora SIGTERM")
func bddSubprocessCancellationReapsItsChild() async throws {
    let fixture = try BDDProcessFixture()
    defer { fixture.reportCleanupFailure() }
    let task = Task {
        try await BDDSubprocess.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", blockedBDDProcessScript, "bdd-fixture", fixture.readyFile.path],
            directory: fixture.directory, terminationGrace: .milliseconds(20))
    }
    let pid: Int32
    do { pid = try await fixture.waitUntilReady() } catch {
        task.cancel()
        _ = await task.result
        throw error
    }
    task.cancel()
    let result = await task.result
    #expect(result.failure as? BDDSubprocessFailure == .cancelled)
    #expect(Darwin.kill(pid, 0) == -1 && errno == ESRCH)
    try fixture.cleanup()
}

@Test("La deadline termina e raccoglie anche un figlio che ignora SIGTERM")
func bddSubprocessDeadlineReapsItsChild() async throws {
    let fixture = try BDDProcessFixture()
    defer { fixture.reportCleanupFailure() }
    let task = Task {
        try await BDDSubprocess.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", blockedBDDProcessScript, "bdd-fixture", fixture.readyFile.path],
            directory: fixture.directory, timeout: .seconds(2), terminationGrace: .milliseconds(20))
    }
    let pid: Int32
    do { pid = try await fixture.waitUntilReady() } catch {
        task.cancel()
        _ = await task.result
        throw error
    }
    let result = await task.result
    #expect(result.failure as? BDDSubprocessFailure == .timedOut)
    #expect(Darwin.kill(pid, 0) == -1 && errno == ESRCH)
    try fixture.cleanup()
}

@Test("Un errore di avvio chiude i file e restituisce una failure tipizzata")
func bddSubprocessLaunchFailureClosesFiles() async throws {
    let fixture = try BDDProcessFixture()
    defer { fixture.reportCleanupFailure() }
    await #expect(throws: BDDSubprocessFailure.launchFailed) {
        try await BDDSubprocess.run(
            executable: fixture.directory.appending(path: "absent"), arguments: [],
            directory: fixture.directory)
    }
    try fixture.cleanup()
}

@Test("L'output oltre budget viene rifiutato prima di caricarlo in memoria")
func bddSubprocessRejectsOversizedOutput() async throws {
    let fixture = try BDDProcessFixture()
    defer { fixture.reportCleanupFailure() }
    await #expect(throws: BDDSubprocessFailure.outputLimitExceeded) {
        try await BDDSubprocess.run(
            executable: URL(fileURLWithPath: "/bin/dd"),
            arguments: ["if=/dev/zero", "bs=1048577", "count=1"], directory: fixture.directory)
    }
    try fixture.cleanup()
}

extension Result {
    fileprivate var failure: Failure? {
        switch self {
        case .success: nil
        case let .failure(error): error
        }
    }
}
