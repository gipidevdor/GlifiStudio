// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Exposes the public application-facing contract for GlifiCore.
public struct GlifiStudioService: Sendable {
    private let engine: GlifiEngine
    private let runtimeEnvironment: GlifiStudioRuntimeEnvironment

    /// Creates a service with explicit platform signals or the headless bootstrap policy.
    public init(runtimeEnvironment: GlifiStudioRuntimeEnvironment = .headless) {
        engine = GlifiEngine()
        self.runtimeEnvironment = runtimeEnvironment
    }

    /// Returns a presentation-independent description of the engine state.
    public func status() async -> GlifiStudioStatus {
        let engineStatus = await engine.status()

        switch engineStatus {
        case .ready:
            return .ready
        }
    }

    /// Profiles one user-authorized UTF-8 file using the same GlifiCore path as headless clients.
    public func profileText(
        at url: URL,
        format: GlifiStudioTextFormat
    ) async throws -> GlifiStudioTextProfile {
        try runtimeEnvironment.admit(operation: .profileCollection)
        do {
            let profile = try await engine.profileText(
                at: url,
                format: format.coreValue
            )
            return GlifiStudioTextProfile(profile)
        } catch let failure as GlifiFailure {
            throw GlifiStudioFailure(failure)
        } catch {
            throw GlifiStudioFailure(
                GlifiFailure(
                    code: "internal.unexpected",
                    category: .invariantViolation,
                    operation: .profileCollection,
                    retryDisposition: .never,
                    retainedState: .validityUnknown,
                    messageKey: "failure.internal.unexpected"
                )
            )
        }
    }

    /// Creates and opens an empty `.glifi` project at a user-authorized destination.
    public func createProject(at url: URL) async throws -> GlifiStudioProjectSession {
        do {
            let project = try await engine.createProject(at: url)
            return GlifiStudioProjectSession(
                engine: engine, project: project, runtimeEnvironment: runtimeEnvironment)
        } catch {
            throw map(error, operation: .persistProject)
        }
    }

    /// Opens an existing `.glifi` project after complete integrity verification.
    public func openProject(at url: URL) async throws -> GlifiStudioProjectSession {
        do {
            let project = try await engine.openProject(at: url)
            return GlifiStudioProjectSession(
                engine: engine, project: project, runtimeEnvironment: runtimeEnvironment)
        } catch {
            throw map(error, operation: .persistProject)
        }
    }

    private func map(_ error: Error, operation: GlifiOperationKind) -> GlifiStudioFailure {
        if let failure = error as? GlifiFailure {
            return GlifiStudioFailure(failure)
        }
        return GlifiStudioFailure(
            GlifiFailure(
                code: "internal.unexpected",
                category: .invariantViolation,
                operation: operation,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.internal.unexpected"
            )
        )
    }
}
