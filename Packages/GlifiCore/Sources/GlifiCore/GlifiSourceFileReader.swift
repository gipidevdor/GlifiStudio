// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation

/// Copies one coordinated external source into an owned, bounded byte snapshot.
enum GlifiSourceFileReader {
    private static let chunkByteCount = 65_536

    static func read(at url: URL, limits: GlifiTextImportLimits) throws -> Data {
        try read(
            at: url, limits: limits, coordinate: coordinateRead,
            readChunk: { try $0.read(upToCount: $1) })
    }

    /// Internal I/O dependencies permit deterministic provider, growth and cancellation checks.
    static func read(
        at url: URL,
        limits: GlifiTextImportLimits,
        coordinate: (URL, (URL) -> Void) throws -> Void,
        readChunk: @escaping (FileHandle, Int) throws -> Data?
    ) throws -> Data {
        do {
            try Task.checkCancellation()
            try validateFileURL(url)
            try rejectExistingNonRegularFile(at: url)
            var result: Result<Data, any Error>?
            try coordinate(url) { coordinatedURL in
                result = Result {
                    try readCoordinatedFile(
                        at: coordinatedURL, limits: limits, readChunk: readChunk)
                }
            }
            try Task.checkCancellation()
            guard let result else { throw unreadableFile() }
            return try result.get()
        } catch let failure as GlifiFailure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw unreadableFile()
        }
    }

    private static func coordinateRead(_ url: URL, accessor: (URL) -> Void) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) {
            accessor($0)
        }
        if let coordinationError { throw coordinationError }
    }

    private static func readCoordinatedFile(
        at url: URL,
        limits: GlifiTextImportLimits,
        readChunk: (FileHandle, Int) throws -> Data?
    ) throws -> Data {
        try Task.checkCancellation()
        try validateFileURL(url)
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else {
            if errno == ELOOP { throw nonRegularFile() }
            throw unreadableFile()
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { throw unreadableFile() }
        guard (status.st_mode & S_IFMT) == S_IFREG else { throw nonRegularFile() }
        guard status.st_size >= 0 else { throw unreadableFile() }
        guard status.st_size <= limits.maximumByteCount else { throw byteLimit(limits) }

        var bytes = Data()
        bytes.reserveCapacity(min(Int(status.st_size), chunkByteCount))
        while true {
            try Task.checkCancellation()
            let remaining = limits.maximumByteCount - bytes.count
            // Add a sentinel only below the chunk bound, so Int.max cannot overflow.
            let requested = remaining >= chunkByteCount ? chunkByteCount : remaining + 1
            guard let chunk = try readChunk(handle, requested), !chunk.isEmpty else { break }
            guard chunk.count <= remaining else { throw byteLimit(limits) }
            bytes.append(chunk)
        }
        try Task.checkCancellation()
        return bytes
    }

    private static func validateFileURL(_ url: URL) throws {
        guard url.isFileURL, !url.path.contains("\0") else { throw nonRegularFile() }
    }

    /// Foundation may open an existing item before invoking its coordination accessor.
    ///
    /// Missing provider placeholders are allowed; the accessor's descriptor remains authoritative.
    private static func rejectExistingNonRegularFile(at url: URL) throws {
        var status = stat()
        if lstat(url.path, &status) == 0 {
            guard (status.st_mode & S_IFMT) == S_IFREG else { throw nonRegularFile() }
        } else if errno != ENOENT && errno != ENOTDIR {
            throw unreadableFile()
        }
    }

    private static func nonRegularFile() -> GlifiFailure {
        GlifiFailure(
            code: "file.not-regular", category: .invalidInput, operation: .importText,
            retryDisposition: .afterCorrection, retainedState: .unchanged,
            messageKey: "failure.file.not-regular")
    }

    private static func unreadableFile() -> GlifiFailure {
        GlifiFailure(
            code: "file.unreadable", category: .transientIO, operation: .importText,
            retryDisposition: .transientBackoff, retainedState: .unchanged,
            messageKey: "failure.file.unreadable")
    }

    private static func byteLimit(_ limits: GlifiTextImportLimits) -> GlifiFailure {
        GlifiFailure(
            code: "text.byte-limit-exceeded", category: .insufficientResources,
            operation: .importText, retryDisposition: .afterConditionsChange,
            retainedState: .unchanged, messageKey: "failure.text.byte-limit-exceeded",
            arguments: ["maximumByteCount": String(limits.maximumByteCount)])
    }
}
