// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit

/// Resolves source ordinals within the current presentation snapshot.
@MainActor
final class StudioSourceLookup {
    private let sources: [GlifiStudioProjectSource]
    private var remainingLinearWork: Int
    private var positions: [String: Int]?

    init(sources: [GlifiStudioProjectSource]) {
        self.sources = sources
        let budget = sources.count.multipliedReportingOverflow(by: 64)
        remainingLinearWork = budget.overflow ? Int.max : budget.partialValue
    }

    /// Returns the first matching position, preserving snapshot order and missing identities.
    func index(of revisionID: String) -> Int? {
        guard let first = sources.first else { return nil }
        if first.sourceRevisionID == revisionID { return 0 }
        if let positions {
            return positions[revisionID]
        }
        if remainingLinearWork > 0 {
            let position = sources.firstIndex { @Sendable source in
                source.sourceRevisionID == revisionID
            }
            let visited = position.map { $0 + 1 } ?? sources.count
            remainingLinearWork -= min(remainingLinearWork, visited)
            return position
        }
        var index: [String: Int] = [:]
        index.reserveCapacity(sources.count)
        for (position, source) in sources.enumerated()
        where index[source.sourceRevisionID] == nil {
            index[source.sourceRevisionID] = position
        }
        positions = index
        return index[revisionID]
    }
}
