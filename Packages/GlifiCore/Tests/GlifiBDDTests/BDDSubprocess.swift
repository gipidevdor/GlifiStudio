// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation

struct BDDSubprocessOutput: Sendable {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

enum BDDSubprocessFailure: Error, Equatable {
    case cancelled
    case timedOut
    case invalidConfiguration
    case launchFailed
    case fileIO
    case outputLimitExceeded
    case terminationFailed
}

enum BDDSubprocess {
    /// Owns the child until termination and file closure, including when its caller is cancelled.
    static func run(
        executable: URL, arguments: [String], directory: URL,
        timeout: Duration = .seconds(20), terminationGrace: Duration = .seconds(1)
    ) async throws(BDDSubprocessFailure) -> BDDSubprocessOutput {
        let execution = BDDSubprocessExecution(
            executable: executable, arguments: arguments, directory: directory,
            timeout: timeout, terminationGrace: terminationGrace)
        let result = await withTaskCancellationHandler {
            await execution.run()
        } onCancel: {
            // This bridge owns no process or files. The operation waits for the actor's teardown.
            Task { await execution.cancel() }
        }
        return try result.get()
    }
}

private actor BDDSubprocessExecution {
    private let executable: URL
    private let arguments: [String]
    private let directory: URL
    private let timeout: Duration
    private let terminationGrace: Duration
    private let stdoutURL: URL
    private let stderrURL: URL
    private var process: Process?
    private var stdout: FileHandle?
    private var stderr: FileHandle?
    private var continuation:
        CheckedContinuation<
            Result<BDDSubprocessOutput, BDDSubprocessFailure>, Never
        >?
    private var stopReason: BDDSubprocessFailure?
    private var finished = false
    private var deadlineTask: Task<Void, Never>?
    private var escalationTask: Task<Void, Never>?

    init(
        executable: URL, arguments: [String], directory: URL, timeout: Duration,
        terminationGrace: Duration
    ) {
        self.executable = executable
        self.arguments = arguments
        self.directory = directory
        self.timeout = timeout
        self.terminationGrace = terminationGrace
        stdoutURL = directory.appending(path: "stdout-\(UUID().uuidString)")
        stderrURL = directory.appending(path: "stderr-\(UUID().uuidString)")
    }

    func run() async -> Result<BDDSubprocessOutput, BDDSubprocessFailure> {
        guard timeout > .zero, terminationGrace > .zero else {
            return .failure(.invalidConfiguration)
        }
        guard !Task.isCancelled, stopReason == nil else { return .failure(.cancelled) }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            do {
                try Data().write(to: stdoutURL)
                try Data().write(to: stderrURL)
                stdout = try FileHandle(forWritingTo: stdoutURL)
                stderr = try FileHandle(forWritingTo: stderrURL)
            } catch {
                finish(.failure(.fileIO))
                return
            }
            let child = Process()
            child.executableURL = executable
            child.arguments = arguments
            child.currentDirectoryURL = directory
            child.standardInput = FileHandle.nullDevice
            child.standardOutput = stdout
            child.standardError = stderr
            child.terminationHandler = { [weak self] child in
                // Foundation's completion only forwards an event; the actor owns finalization.
                Task { await self?.didTerminate(child) }
            }
            process = child
            do { try child.run() } catch {
                finish(.failure(.launchFailed))
                return
            }
            // Both timer tasks belong to this actor and are cancelled before it resumes the caller.
            deadlineTask = Task { [weak self, timeout] in
                do { try await Task.sleep(for: timeout) } catch { return }
                await self?.stop(.timedOut)
            }
        }
    }

    func cancel() { stop(.cancelled) }

    private func stop(_ reason: BDDSubprocessFailure) {
        guard !finished else { return }
        if let process, !process.isRunning { return }
        stopReason = stopReason ?? reason
        guard let process else { return }
        process.terminate()
        guard escalationTask == nil else { return }
        escalationTask = Task { [weak self, terminationGrace] in
            do { try await Task.sleep(for: terminationGrace) } catch { return }
            await self?.forceTermination()
        }
    }

    private func forceTermination() {
        guard !finished, let process, process.isRunning else { return }
        if Darwin.kill(process.processIdentifier, SIGKILL) != 0, errno != ESRCH {
            // Retain the error, but never release files while an owned child is still alive.
            stopReason = .terminationFailed
        }
    }

    private func didTerminate(_ child: Process) {
        guard !finished, process === child else { return }
        child.waitUntilExit()
        if let stopReason {
            finish(.failure(stopReason))
            return
        }
        do {
            let output = try BDDSubprocessOutput(
                status: child.terminationStatus,
                stdout: readOutput(at: stdoutURL), stderr: readOutput(at: stderrURL))
            finish(.success(output))
        } catch let failure as BDDSubprocessFailure {
            finish(.failure(failure))
        } catch {
            finish(.failure(.fileIO))
        }
    }

    private func readOutput(at url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= 1_048_576 else {
            throw BDDSubprocessFailure.outputLimitExceeded
        }
        return try Data(contentsOf: url)
    }

    private func finish(_ proposed: Result<BDDSubprocessOutput, BDDSubprocessFailure>) {
        guard !finished else { return }
        finished = true
        deadlineTask?.cancel()
        escalationTask?.cancel()
        deadlineTask = nil
        escalationTask = nil
        var result = proposed
        for handle in [stdout, stderr].compactMap({ $0 }) {
            do { try handle.close() } catch { result = .failure(.fileIO) }
        }
        stdout = nil
        stderr = nil
        process?.terminationHandler = nil
        process = nil
        let completion = continuation
        continuation = nil
        completion?.resume(returning: result)
    }
}
