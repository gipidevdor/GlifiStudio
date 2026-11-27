// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Synchronization

struct BDDSubprocessOutput: Sendable {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

enum BDDSubprocessFailure: Error, Equatable {
    case invalidInput
    case allocationFailed
    case systemCall(String, Int32)
    case timedOut
}

/// Owns one child from spawn through waitpid, including cancellation and forced termination.
enum BDDSubprocess {
    static func run(
        executable: URL, arguments: [String], directory: URL,
        timeout: Duration = .seconds(30), terminationGrace: Duration = .milliseconds(250),
        startsSuspended: Bool = false,
        onLaunch: @escaping @Sendable (pid_t) -> Void = { _ in }
    ) async throws -> BDDSubprocessOutput {
        guard timeout > .zero, terminationGrace >= .zero else {
            throw BDDSubprocessFailure.invalidInput
        }
        try Task.checkCancellation()
        let control = BDDSubprocessControl()
        return try await withTaskCancellationHandler {
            try await Task.detached {
                try execute(
                    executable: executable, arguments: arguments, directory: directory,
                    timeout: timeout, terminationGrace: terminationGrace,
                    startsSuspended: startsSuspended, onLaunch: onLaunch, control: control)
            }.value
        } onCancel: {
            control.cancel()
        }
    }

    private static func execute(
        executable: URL, arguments: [String], directory: URL,
        timeout: Duration, terminationGrace: Duration, startsSuspended: Bool,
        onLaunch: @Sendable (pid_t) -> Void, control: BDDSubprocessControl
    ) throws -> BDDSubprocessOutput {
        if control.isCancelled { throw CancellationError() }
        let captureDirectory = directory.appending(
            path: "capture-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: captureDirectory, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.removeItem(at: captureDirectory)
        }
        let outputURL = captureDirectory.appending(path: "stdout")
        let errorURL = captureDirectory.appending(path: "stderr")
        var actions: posix_spawn_file_actions_t?
        try check(posix_spawn_file_actions_init(&actions), operation: "file-actions-init")
        defer { posix_spawn_file_actions_destroy(&actions) }
        try check(
            posix_spawn_file_actions_addchdir(&actions, directory.path), operation: "chdir")
        try check(
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0),
            operation: "open-stdin")
        for (descriptor, url) in [(STDOUT_FILENO, outputURL), (STDERR_FILENO, errorURL)] {
            try check(
                posix_spawn_file_actions_addopen(
                    &actions, descriptor, url.path, O_WRONLY | O_CREAT | O_EXCL, 0o600),
                operation: "open-output")
        }
        var attributes: posix_spawnattr_t?
        try check(posix_spawnattr_init(&attributes), operation: "attributes-init")
        defer { posix_spawnattr_destroy(&attributes) }
        var mask = sigset_t()
        sigemptyset(&mask)
        try check(posix_spawnattr_setsigmask(&attributes, &mask), operation: "signal-mask")
        var defaults = sigset_t()
        sigemptyset(&defaults)
        sigaddset(&defaults, SIGTERM)
        try check(
            posix_spawnattr_setsigdefault(&attributes, &defaults), operation: "signal-defaults")
        let flags =
            POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_CLOEXEC_DEFAULT
            // A stopped child makes the escalation regression independent of shell startup timing.
            | (startsSuspended ? POSIX_SPAWN_START_SUSPENDED : 0)
        try check(posix_spawnattr_setflags(&attributes, Int16(flags)), operation: "spawn-flags")
        let environment = ProcessInfo.processInfo.environment.sorted { $0.key < $1.key }.map {
            "\($0.key)=\($0.value)"
        }
        var pid: pid_t = 0
        try withStrings([executable.path] + arguments) { argumentPointers in
            try withStrings(environment) { environmentPointers in
                if control.isCancelled { throw CancellationError() }
                try check(
                    posix_spawn(
                        &pid, executable.path, &actions, &attributes,
                        argumentPointers, environmentPointers), operation: "posix-spawn")
            }
        }
        onLaunch(pid)
        let status = try awaitExit(
            pid, timeout: timeout, terminationGrace: terminationGrace, control: control)
        // Match Foundation.Process's status for both normal exits and terminating signals.
        let signal = status & 0x7F
        return try BDDSubprocessOutput(
            status: signal == 0 ? (status >> 8) & 0xFF : signal,
            stdout: Data(contentsOf: outputURL), stderr: Data(contentsOf: errorURL))
    }

    private static func awaitExit(
        _ pid: pid_t, timeout: Duration, terminationGrace: Duration,
        control: BDDSubprocessControl
    ) throws -> Int32 {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var stop: BDDSubprocessStop?
        var escalation: ContinuousClock.Instant?
        var didEscalate = false
        while true {
            var status: Int32 = 0
            let observed = waitpid(pid, &status, WNOHANG)
            if observed == pid {
                switch stop {
                case .cancelled: throw CancellationError()
                case .timedOut: throw BDDSubprocessFailure.timedOut
                case nil: return status
                }
            }
            if observed == -1 {
                if errno == EINTR { continue }
                // Ownership is no longer established; never signal a potentially reused PID.
                throw BDDSubprocessFailure.systemCall("waitpid", errno)
            }
            let now = clock.now
            if stop == nil {
                if control.isCancelled {
                    stop = .cancelled
                } else if now >= deadline {
                    stop = .timedOut
                }
                if stop != nil {
                    // The child has not been reaped, so this PID cannot have been recycled.
                    _ = kill(pid, SIGTERM)
                    escalation = now.advanced(by: terminationGrace)
                }
            }
            if let escalation, now >= escalation, !didEscalate {
                _ = kill(pid, SIGKILL)
                didEscalate = true
            }
            // Cancellation wakes the monitor immediately; polling also observes ordinary exit.
            _ = control.wake.wait(timeout: .now() + .milliseconds(10))
        }
    }

    private static func check(_ result: Int32, operation: String) throws {
        guard result == 0 else { throw BDDSubprocessFailure.systemCall(operation, result) }
    }

    private static func withStrings<Result>(
        _ values: [String], _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
    ) throws -> Result {
        guard !values.contains(where: { $0.utf8.contains(0) }) else {
            throw BDDSubprocessFailure.invalidInput
        }
        var pointers = values.map { value in value.withCString { strdup($0) } }
        defer { for pointer in pointers { free(pointer) } }
        guard pointers.allSatisfy({ $0 != nil }) else {
            throw BDDSubprocessFailure.allocationFailed
        }
        pointers.append(nil)
        return try pointers.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { throw BDDSubprocessFailure.allocationFailed }
            return try body(base)
        }
    }
}

private enum BDDSubprocessStop {
    case cancelled
    case timedOut
}

private final class BDDSubprocessControl: Sendable {
    private let cancellation = Mutex(false)
    let wake = DispatchSemaphore(value: 0)

    var isCancelled: Bool { cancellation.withLock { $0 } }

    func cancel() {
        cancellation.withLock { $0 = true }
        wake.signal()
    }
}
