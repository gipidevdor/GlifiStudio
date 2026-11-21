// SPDX-License-Identifier: BSD-3-Clause

/// Internal, bounded allocation policy; smaller limits support deterministic fallback tests.
struct GlifiBM25PostingsPolicy: Sendable {
    static let standard = GlifiBM25PostingsPolicy()
    static let maximumTemporaryByteCount = 32 * 1_024 * 1_024
    static let maximumPostingCount = 1_000_000

    let temporaryByteLimit: Int
    let postingCountLimit: Int

    init(
        temporaryByteLimit: Int = GlifiBM25PostingsPolicy.maximumTemporaryByteCount,
        postingCountLimit: Int = GlifiBM25PostingsPolicy.maximumPostingCount
    ) {
        self.temporaryByteLimit = temporaryByteLimit
        self.postingCountLimit = postingCountLimit
    }
}

/// Query-column-major postings; each column retains ascending input row order.
struct GlifiBM25QueryPostings: Sendable {
    let offsets: [Int]
    let rowIndices: [Int]
    let frequencies: [Int]

    /// Returns nil when the direct evaluator is cheaper or allocation limits are reached.
    ///
    /// No scientific parameter or admitted input domain changes with this choice.
    static func build(
        rows: [[Int: Int]], columns: [Int], policy: GlifiBM25PostingsPolicy
    ) throws -> Self? {
        try Task.checkCancellation()
        guard (128...32_768).contains(columns.count),
            (0...GlifiBM25PostingsPolicy.maximumTemporaryByteCount).contains(
                policy.temporaryByteLimit),
            (0...GlifiBM25PostingsPolicy.maximumPostingCount).contains(policy.postingCountLimit)
        else { return nil }
        // Reserve a conservative 256 bytes/query for the native hash index and all
        // query-sized arrays. The cap covers managed buffers, not whole-process RSS.
        let queryBytes = 256
        guard columns.count <= policy.temporaryByteLimit / queryBytes else { return nil }
        let remaining = policy.temporaryByteLimit - columns.count * queryBytes
        let hitLimit = min(policy.postingCountLimit, remaining / (2 * MemoryLayout<Int>.stride))
        var storedCells = 0
        for (index, row) in rows.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let addition = storedCells.addingReportingOverflow(row.count)
            guard !addition.overflow else { return nil }
            storedCells = addition.partialValue
        }
        guard
            favorsPostings(
                documentCount: rows.count, queryCount: columns.count, storedCellCount: storedCells)
        else { return nil }

        var positions: [Int: Int] = [:]
        positions.reserveCapacity(columns.count)
        for (position, column) in columns.enumerated() { positions[column] = position }
        var documentFrequencies = [Int](repeating: 0, count: columns.count)
        var hitCount = 0
        var visitedCells = 0
        for (rowIndex, row) in rows.enumerated() {
            if rowIndex.isMultiple(of: 256) { try Task.checkCancellation() }
            for (column, frequency) in row {
                if visitedCells.isMultiple(of: 1_024) { try Task.checkCancellation() }
                visitedCells += 1
                guard let position = positions[column] else { continue }
                guard frequency >= 0 else {
                    throw GlifiTermWeighting.weightingFailure("bm25.negative-count")
                }
                guard frequency > 0 else { continue }
                guard hitCount < hitLimit else { return nil }
                hitCount += 1
                documentFrequencies[position] += 1
            }
        }
        var offsets = [Int](repeating: 0, count: columns.count + 1)
        for position in columns.indices {
            if position.isMultiple(of: 256) { try Task.checkCancellation() }
            // Every partial sum is bounded by hitLimit, at most one million.
            offsets[position + 1] = offsets[position] + documentFrequencies[position]
        }
        var rowIndices = [Int](repeating: 0, count: hitCount)
        var frequencies = [Int](repeating: 0, count: hitCount)
        if hitCount > 0 {
            var cursors = Array(offsets.dropLast())
            visitedCells = 0
            for (rowIndex, row) in rows.enumerated() {
                if rowIndex.isMultiple(of: 256) { try Task.checkCancellation() }
                for (column, frequency) in row {
                    if visitedCells.isMultiple(of: 1_024) { try Task.checkCancellation() }
                    visitedCells += 1
                    guard frequency > 0, let position = positions[column] else { continue }
                    let destination = cursors[position]
                    rowIndices[destination] = rowIndex
                    frequencies[destination] = frequency
                    cursors[position] += 1
                }
            }
        }
        try Task.checkCancellation()
        return Self(offsets: offsets, rowIndices: rowIndices, frequencies: frequencies)
    }

    /// Compares D×Q > 4C in full unsigned width, including hypothetical Int.max inputs.
    static func favorsPostings(
        documentCount: Int, queryCount: Int, storedCellCount: Int
    ) -> Bool {
        guard documentCount > 0, queryCount > 0, storedCellCount >= 0 else { return false }
        let direct = UInt64(documentCount).multipliedFullWidth(by: UInt64(queryCount))
        let sparse = UInt64(storedCellCount).multipliedFullWidth(by: 4)
        return direct.high != sparse.high
            ? direct.high > sparse.high : direct.low > sparse.low
    }
}
