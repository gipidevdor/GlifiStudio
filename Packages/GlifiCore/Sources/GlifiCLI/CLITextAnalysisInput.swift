// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import GlifiKit

enum CLITextAnalysisInput {
    static func read(at url: URL) throws -> Data {
        do {
            return try CLIRequestInput.read(at: url)
        } catch {
            let code: String
            switch error {
            case .unreadable: code = "text-analysis.request-unreadable"
            case .notRegular: code = "text-analysis.request-not-regular"
            case .tooLarge: code = "text-analysis.request-limit"
            case .cancelled: code = "operation.cancelled"
            }
            throw GlifiStudioFailure(
                code: code, category: error.category, operation: "analyze",
                retryDisposition: error.retryDisposition, retainedState: "unchanged",
                messageKey: "failure.category.\(error.category)")
        }
    }
}

/// Shares descriptor-based admission and bounded reading across CLI JSON requests.
enum CLIRequestInput {
    enum Failure: Error {
        case unreadable(Int32)
        case notRegular
        case tooLarge
        case cancelled

        var category: String {
            switch self {
            case let .unreadable(code):
                switch code {
                case EACCES, EPERM: "authorizationDenied"
                case EMFILE, ENFILE, ENOMEM: "insufficientResources"
                case ENOENT, ENOTDIR, ELOOP, ENAMETOOLONG: "invalidInput"
                default: "transientIO"
                }
            case .notRegular: "invalidInput"
            case .tooLarge: "insufficientResources"
            case .cancelled: "cancelled"
            }
        }

        var retryDisposition: String {
            switch category {
            case "insufficientResources": "afterConditionsChange"
            case "authorizationDenied": "afterUserAction"
            case "transientIO": "transientBackoff"
            case "cancelled": "newRequest"
            default: "afterCorrection"
            }
        }
    }

    static func read(at url: URL) throws(Failure) -> Data {
        guard !Task.isCancelled else { throw .cancelled }
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else {
            let openError = errno
            if openError == ELOOP { throw .notRegular }
            throw .unreadable(openError)
        }
        defer { close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw .unreadable(errno)
        }
        guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw .notRegular
        }
        let limit = GlifiStudioTextAnalysisRequest.maximumRequestBytes
        guard metadata.st_size >= 0, metadata.st_size <= limit else {
            throw .tooLarge
        }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            guard !Task.isCancelled else { throw .cancelled }
            // The nonempty owned buffer outlives this synchronous read; the byte count
            // never exceeds its capacity or the remaining request budget plus one.
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, min(bytes.count, limit + 1 - data.count))
            }
            if count < 0 {
                let readError = errno
                if readError == EINTR { continue }
                throw .unreadable(readError)
            }
            if count == 0 { return data }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= limit else { throw .tooLarge }
        }
    }
}
