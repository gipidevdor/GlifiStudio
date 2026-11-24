// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Explicit input of the non-persisting file profile operation shared with command-line clients.
public struct GlifiStudioProfileRequest: Codable, Equatable, Sendable {
    /// User-authorized local path; it is never included in failure diagnostics.
    public let sourcePath: String
    /// Explicit source format, independent from the filename extension.
    public let format: GlifiStudioTextFormat

    /// Creates an immutable request without accessing the file.
    public init(sourcePath: String, format: GlifiStudioTextFormat) {
        self.sourcePath = sourcePath
        self.format = format
    }
}

extension GlifiStudioService {
    /// Profiles a file from the same bounded JSON request accepted by the CLI.
    public func profileText(json: Data) async throws(GlifiStudioFailure) -> GlifiStudioTextProfile {
        let request = try CommandJSON.decodeStrict(GlifiStudioProfileRequest.self, from: json)
        guard !request.sourcePath.isEmpty else { throw commandFailure("invalid-source-path") }
        do {
            return try await profileText(
                at: URL(fileURLWithPath: request.sourcePath), format: request.format)
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch {
            throw commandFailure("unexpected-profile-failure", category: "invariantViolation")
        }
    }
}
