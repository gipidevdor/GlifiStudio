// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import GlifiKit

enum CLITextAnalysisInput {
    static func read(at url: URL) throws -> Data {
        // The same descriptor is checked and read; special files cannot block the CLI.
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else {
            let openError = errno
            let category: String
            switch openError {
            case EACCES, EPERM:
                category = "authorizationDenied"
            case EMFILE, ENFILE, ENOMEM:
                category = "insufficientResources"
            case ENOENT, ENOTDIR, ELOOP, ENAMETOOLONG:
                category = "invalidInput"
            default:
                category = "transientIO"
            }
            throw failure("text-analysis.request-unreadable", category: category)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw failure("text-analysis.request-unreadable", category: "transientIO")
        }
        guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw failure("text-analysis.request-not-regular", category: "invalidInput")
        }
        let limit = GlifiStudioTextAnalysisRequest.maximumRequestBytes
        guard metadata.st_size >= 0, metadata.st_size <= limit else {
            throw failure("text-analysis.request-limit", category: "insufficientResources")
        }
        do {
            var data = Data()
            while true {
                let chunk =
                    try handle.read(upToCount: min(65_536, limit + 1 - data.count)) ?? Data()
                if chunk.isEmpty { break }
                data.append(chunk)
                guard data.count <= limit else {
                    throw failure("text-analysis.request-limit", category: "insufficientResources")
                }
            }
            return data
        } catch let error as GlifiStudioFailure {
            throw error
        } catch {
            throw failure("text-analysis.request-unreadable", category: "transientIO")
        }
    }

    private static func failure(_ code: String, category: String) -> GlifiStudioFailure {
        let retry: String
        switch category {
        case "insufficientResources": retry = "afterConditionsChange"
        case "authorizationDenied": retry = "afterUserAction"
        case "transientIO": retry = "transientBackoff"
        default: retry = "afterCorrection"
        }
        return GlifiStudioFailure(
            code: code, category: category, operation: "analyze",
            retryDisposition: retry, retainedState: "unchanged",
            messageKey: "failure.category.\(category)")
    }
}
