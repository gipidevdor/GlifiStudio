// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Synchronization

/// One finite activity; ending it repeatedly, including during cleanup, is harmless.
final class GlifiStudioProcessActivity: Sendable {
    private enum State {
        #if os(macOS)
            case foundation(any NSObjectProtocol)
        #endif
        case custom(@Sendable () -> Void)
        case finished
    }

    private let state: Mutex<State>

    init(end: @escaping @Sendable () -> Void) {
        state = Mutex(.custom(end))
    }

    #if os(macOS)
        private init(token: sending any NSObjectProtocol) {
            state = Mutex(.foundation(token))
        }
    #endif

    static func beginUserInitiated() -> GlifiStudioProcessActivity {
        #if os(macOS)
            return GlifiStudioProcessActivity(
                token: ProcessInfo.processInfo.beginActivity(
                    options: .userInitiatedAllowingIdleSystemSleep,
                    reason: "Execute a user-requested Glifi Studio analysis plan"))
        #else
            return GlifiStudioProcessActivity(end: {})
        #endif
    }

    func end() {
        let callback: (@Sendable () -> Void)? = state.withLock { state in
            switch state {
            #if os(macOS)
                case let .foundation(token):
                    state = .finished
                    ProcessInfo.processInfo.endActivity(token)
                    return nil
            #endif
            case let .custom(end):
                state = .finished
                return end
            case .finished:
                return nil
            }
        }
        callback?()
    }

    deinit {
        end()
    }
}

/// Injectable ownership boundary for an operation explicitly requested by the user.
struct GlifiStudioActivityProvider: Sendable {
    let begin: @Sendable () -> GlifiStudioProcessActivity

    static let system = GlifiStudioActivityProvider(
        begin: { GlifiStudioProcessActivity.beginUserInitiated() })

    func perform<Result: Sendable>(
        _ operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        let activity = begin()
        defer { activity.end() }
        return try await operation()
    }
}
