// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import Synchronization
import Testing

@Suite("BDD subprocess ownership and interruption")
struct BDDSubprocessTests {
    @Test("Normal exit preserves both streams and cleans capture files")
    func capturesOutput() async throws {
        try await withSubprocessDirectory { directory in
            let output = try await BDDSubprocess.run(
                executable: URL(filePath: "/bin/sh"),
                arguments: ["-c", "printf alpha; printf beta >&2; exit 7"], directory: directory)
            #expect(output.status == 7)
            #expect(output.stdout == Data("alpha".utf8))
            #expect(output.stderr == Data("beta".utf8))
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test("Launch failure is typed and removes capture files")
    func failedLaunch() async throws {
        try await withSubprocessDirectory { directory in
            do {
                _ = try await BDDSubprocess.run(
                    executable: directory.appending(path: "missing"), arguments: [],
                    directory: directory)
                Issue.record("A missing executable was accepted")
            } catch let failure as BDDSubprocessFailure {
                #expect(failure == .systemCall("posix-spawn", ENOENT))
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test("Output beyond the byte budget is rejected before reading into memory")
    func rejectsOversizedOutput() async throws {
        try await withSubprocessDirectory { directory in
            await #expect(throws: BDDSubprocessFailure.outputLimitExceeded) {
                try await BDDSubprocess.run(
                    executable: URL(filePath: "/bin/dd"),
                    arguments: ["if=/dev/zero", "bs=1048577", "count=1"], directory: directory)
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test("Preventive cancellation never launches a child")
    func preventsLaunch() async throws {
        try await withSubprocessDirectory { directory in
            let launched = Mutex(false)
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await BDDSubprocess.run(
                    executable: URL(filePath: "/bin/sh"), arguments: ["-c", "exit 0"],
                    directory: directory, onLaunch: { _ in launched.withLock { $0 = true } })
            }
            do {
                _ = try await task.value
                Issue.record("A cancelled subprocess request succeeded")
            } catch is CancellationError {
                #expect(!launched.withLock { $0 })
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test("Cancellation terminates and reaps even a suspended child")
    func cancelsOwnedChild() async throws {
        try await withSubprocessDirectory { directory in
            let (launches, continuation) = AsyncStream<pid_t>.makeStream()
            let task = Task {
                defer { continuation.finish() }
                return try await BDDSubprocess.run(
                    executable: URL(filePath: "/bin/sh"), arguments: ["-c", "exit 99"],
                    directory: directory, terminationGrace: .milliseconds(20),
                    startsSuspended: true,
                    onLaunch: { pid in
                        continuation.yield(pid)
                    })
            }
            var launched: pid_t?
            for await pid in launches {
                launched = pid
                break
            }
            let pid = try #require(launched)
            task.cancel()
            do {
                _ = try await task.value
                Issue.record("Cancellation failed to stop a suspended child")
            } catch is CancellationError {
                expectReaped(pid)
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }

    @Test("Timeout escalates past SIGTERM and reaps the child")
    func timesOutOwnedChild() async throws {
        try await withSubprocessDirectory { directory in
            let launched = Mutex<pid_t?>(nil)
            do {
                _ = try await BDDSubprocess.run(
                    executable: URL(filePath: "/bin/sh"), arguments: ["-c", "exit 99"],
                    directory: directory, timeout: .milliseconds(20),
                    terminationGrace: .milliseconds(20), startsSuspended: true,
                    onLaunch: { pid in launched.withLock { $0 = pid } })
                Issue.record("A suspended child outlived its timeout without failure")
            } catch let failure as BDDSubprocessFailure {
                #expect(failure == .timedOut)
                expectReaped(try #require(launched.withLock { $0 }))
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        }
    }
}

private func expectReaped(_ pid: pid_t) {
    var status: Int32 = 0
    let observed = waitpid(pid, &status, WNOHANG)
    let error = errno
    #expect(observed == -1)
    #expect(error == ECHILD)
}

private func withSubprocessDirectory(
    _ body: (URL) async throws -> Void
) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(
        path: "GlifiBDDProcess-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    try await body(directory)
}
