// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A Gregorian civil date, without a time zone or an implicit instant (GS-MET-001-17).
public struct GlifiCivilDate: Equatable, Comparable, Sendable {
    /// Gregorian year in `1...9999`.
    public let year: Int
    /// Month in `1...12`.
    public let month: Int
    /// Valid day of the selected month.
    public let day: Int

    /// Rejects invalid dates, including normalized dates such as February 30.
    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month),
            (1...Self.daysInMonth(year: year, month: month)).contains(day)
        else { throw temporalFailure("temporal.invalid-civil-date") }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Orders civil dates chronologically without assigning a time zone.
    public static func < (left: Self, right: Self) -> Bool {
        if left.year != right.year { return left.year < right.year }
        if left.month != right.month { return left.month < right.month }
        return left.day < right.day
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        if month == 2 {
            return year.isMultiple(of: 400) || (year.isMultiple(of: 4) && !year.isMultiple(of: 100))
                ? 29 : 28
        }
        return [4, 6, 9, 11].contains(month) ? 30 : 31
    }

    fileprivate var ordinal: Int {
        let prior = year - 1
        let beforeYear = prior * 365 + prior / 4 - prior / 100 + prior / 400
        let beforeMonth = (1..<month).reduce(0) { $0 + Self.daysInMonth(year: year, month: $1) }
        return beforeYear + beforeMonth + day - 1
    }

    fileprivate func adding(_ amount: Int, unit: GlifiTemporalGranularity) throws -> Self {
        switch unit {
        case .year:
            return try Self(year: year + amount, month: month, day: day)
        case .month:
            let index = (year - 1) * 12 + month - 1 + amount
            return try Self(year: index / 12 + 1, month: index % 12 + 1, day: day)
        case .day:
            let target = ordinal + amount
            var lower = year
            var upper = 9999
            while lower < upper {
                let middle = (lower + upper + 1) / 2
                let first = try Self(year: middle, month: 1, day: 1).ordinal
                if first <= target { lower = middle } else { upper = middle - 1 }
            }
            var remaining = target - (try Self(year: lower, month: 1, day: 1).ordinal)
            var month = 1
            while month <= 12, remaining >= Self.daysInMonth(year: lower, month: month) {
                remaining -= Self.daysInMonth(year: lower, month: month)
                month += 1
            }
            return try Self(year: lower, month: month, day: remaining + 1)
        }
    }
}

/// Observed temporal type and precision.
///
/// Intervals and uncertainty are never silently imputed.
public enum GlifiTemporalValue: Equatable, Sendable {
    case instant(Date)
    case civilDate(GlifiCivilDate)
    case civilMonth(year: Int, month: Int)
    case civilYear(Int)
    case interval(start: Date, end: Date)
    case uncertainPeriod(lower: GlifiCivilDate, upper: GlifiCivilDate)
    case missing
}

/// Time basis; civil dates are never localized or converted into instants.
public enum GlifiTemporalBasis: Equatable, Sendable {
    case civilDates
    case instants(timeZoneIdentifier: String)
}

/// Calendar step, distinct from a fixed number of elapsed seconds.
public enum GlifiTemporalGranularity: String, Equatable, Sendable {
    case day
    case month
    case year
}

/// Missing observations can remain visible as a separate aggregate.
public enum GlifiTemporalMissingPolicy: String, Equatable, Sendable {
    case exclude
    case separate
    case reject
}

/// Observations outside the explicit half-open domain are excluded or rejected.
public enum GlifiTemporalOutsidePolicy: String, Equatable, Sendable {
    case exclude
    case reject
}

/// Fully resolved calendar partition for `Temporal-calendar-token-rates-v1`.
public struct GlifiTemporalConfiguration: Equatable, Sendable {
    /// Civil dates or instants in an explicit time zone.
    public let basis: GlifiTemporalBasis
    /// Calendar unit used to advance bucket boundaries.
    public let granularity: GlifiTemporalGranularity
    /// First lower boundary; month/year buckets require a first day/first month.
    public let origin: GlifiCivilDate
    /// Positive number of calendar units in every bucket.
    public let bucketWidth: Int
    /// Number of buckets, including empty ones.
    public let bucketCount: Int
    /// Declared treatment of missing dates.
    public let missingPolicy: GlifiTemporalMissingPolicy
    /// Declared treatment of observations outside the chosen domain.
    public let outsidePolicy: GlifiTemporalOutsidePolicy

    /// Declares all choices without consulting the current locale, calendar or time zone.
    public init(
        basis: GlifiTemporalBasis, granularity: GlifiTemporalGranularity,
        origin: GlifiCivilDate, bucketWidth: Int, bucketCount: Int,
        missingPolicy: GlifiTemporalMissingPolicy, outsidePolicy: GlifiTemporalOutsidePolicy
    ) {
        self.basis = basis
        self.granularity = granularity
        self.origin = origin
        self.bucketWidth = bucketWidth
        self.bucketCount = bucketCount
        self.missingPolicy = missingPolicy
        self.outsidePolicy = outsidePolicy
    }
}

/// An immutable source contribution, with observed metadata provenance and token exposure.
public struct GlifiTemporalDocument: Equatable, Sendable {
    /// Exact immutable source revision identity.
    public let sourceRevisionID: SourceRevisionID
    /// Caller-supplied provenance of the observed temporal metadata.
    public let metadataProvenance: String
    /// Observed temporal type and precision.
    public let value: GlifiTemporalValue
    /// Total observed tokens, including terms not selected for output.
    public let tokenCount: Int
    /// Non-negative observed frequencies; their sum cannot exceed `tokenCount`.
    public let termCounts: [String: Int]

    /// Creates immutable observed counts for one source revision.
    public init(
        sourceRevisionID: SourceRevisionID, metadataProvenance: String,
        value: GlifiTemporalValue, tokenCount: Int, termCounts: [String: Int]
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.metadataProvenance = metadataProvenance
        self.value = value
        self.tokenCount = tokenCount
        self.termCounts = termCounts
    }
}

/// Exact source revision and metadata provenance used to assign a document.
public struct GlifiTemporalLineage: Equatable, Sendable {
    /// Exact immutable source revision identity.
    public let sourceRevisionID: SourceRevisionID
    /// Caller-supplied provenance of the observed temporal metadata.
    public let metadataProvenance: String
}

/// Exact counts and a descriptive token-normalized rate for one term.
public struct GlifiTemporalTermFrequency: Equatable, Sendable {
    /// Term identity preserved without implicit normalization.
    public let term: String
    /// Exact observed count in this aggregate.
    public let frequency: Int
    /// Number of contributing documents with a positive term count.
    public let documentFrequency: Int
    /// `1000 * frequency / tokenCount`; undefined when the bucket has no token exposure.
    public let perThousandTokenRate: Double?
    /// Source revisions contributing a positive frequency, in canonical identity order.
    public let sourceRevisionIDs: [SourceRevisionID]
}

/// Aggregated observations; no uncertainty or estimated trend is attached to raw counts.
public struct GlifiTemporalAggregate: Equatable, Sendable {
    /// Number of documents assigned to this aggregate.
    public let documentCount: Int
    /// Observed token exposure, including terms not selected for output.
    public let tokenCount: Int
    /// Term results in canonical lexical order.
    public let terms: [GlifiTemporalTermFrequency]
    /// Source revisions and observed metadata provenance in canonical identity order.
    public let lineage: [GlifiTemporalLineage]
}

/// A boundary preserves its civil/instant type.
public enum GlifiTemporalBoundary: Equatable, Sendable {
    case civilDate(GlifiCivilDate)
    case instant(Date)
}

/// Calendar bucket with inclusive lower and exclusive upper boundary.
public struct GlifiTemporalBucket: Equatable, Sendable {
    /// Inclusive lower bucket boundary, preserving its temporal type.
    public let start: GlifiTemporalBoundary
    /// Exclusive upper bucket boundary, preserving its temporal type.
    public let end: GlifiTemporalBoundary
    /// Observed counts and token-normalized descriptive rates for this bucket.
    public let aggregate: GlifiTemporalAggregate
}

/// A source excluded under an explicit policy, with a machine-readable reason.
public struct GlifiTemporalExclusion: Equatable, Sendable {
    /// Source revisions and observed metadata provenance in canonical identity order.
    public let lineage: GlifiTemporalLineage
    /// `temporal.missing-date`, `temporal.before-domain` or `temporal.after-domain`.
    public let reasonIdentifier: String
}

/// Calendar series in chronological order, plus missing observations and exclusions.
public struct GlifiTemporalResult: Equatable, Sendable {
    /// Versioned headless calendar aggregation identity.
    public static let identifier = "Temporal-calendar-token-rates-v1"
    /// All resolved temporal choices used by the aggregation.
    public let configuration: GlifiTemporalConfiguration
    /// Calendar buckets in chronological order, including empty buckets.
    public let buckets: [GlifiTemporalBucket]
    /// Separate missing-date aggregate when the selected policy requests it.
    public let missing: GlifiTemporalAggregate?
    /// Excluded documents and reasons, in canonical source identity order.
    public let excluded: [GlifiTemporalExclusion]
}

/// Exact bounded temporal aggregation from observed document counts (GS-MET-001-17).
public enum GlifiTemporalAnalysis {
    /// Partitions documents without imputing a date, converting civil values to instants,
    /// or interpreting changes in counts as an inferential trend.
    ///
    /// At most 100,000 documents, 10,000 buckets and 1,000,000 output term cells are admitted.
    /// Work is `O(D log D + D log B + B V + C)` for D documents, B buckets, V terms and C counts.
    public static func aggregate(
        _ documents: [GlifiTemporalDocument], configuration: GlifiTemporalConfiguration
    ) throws -> GlifiTemporalResult {
        guard configuration.bucketCount > 0, configuration.bucketWidth > 0 else {
            throw temporalFailure("temporal.invalid-partition")
        }
        guard configuration.bucketCount <= 10_000, configuration.bucketWidth <= 10_000,
            documents.count <= 100_000
        else { throw temporalFailure("temporal.resource-limit", .insufficientResources) }
        switch configuration.granularity {
        case .day: break
        case .month:
            guard configuration.origin.day == 1 else {
                throw temporalFailure("temporal.unaligned-origin")
            }
        case .year:
            guard configuration.origin.day == 1, configuration.origin.month == 1 else {
                throw temporalFailure("temporal.unaligned-origin")
            }
        }
        try Task.checkCancellation()
        let order = try canonicalOrder(documents)
        var identifiers: Set<SourceRevisionID> = []
        var vocabulary: Set<String> = []
        var countCells = 0
        var byteCount = 0
        var processedCounts = 0
        for (index, documentIndex) in order.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let document = documents[documentIndex]
            guard identifiers.insert(document.sourceRevisionID).inserted,
                !document.metadataProvenance.isEmpty,
                document.metadataProvenance.utf8.count <= 4096,
                document.tokenCount >= 0, document.termCounts.count <= 10_000
            else { throw temporalFailure("temporal.invalid-document") }
            byteCount = try checkedAdd(byteCount, document.metadataProvenance.utf8.count)
            guard byteCount <= 64 * 1024 * 1024 else {
                throw temporalFailure("temporal.resource-limit", .insufficientResources)
            }
            countCells = try checkedAdd(countCells, document.termCounts.count)
            guard countCells <= 1_000_000 else {
                throw temporalFailure("temporal.resource-limit", .insufficientResources)
            }
            var total = 0
            for (term, count) in document.termCounts {
                if processedCounts.isMultiple(of: 256) { try Task.checkCancellation() }
                processedCounts += 1
                guard !term.isEmpty, term.utf8.count <= 4096, count >= 0 else {
                    throw temporalFailure("temporal.invalid-count")
                }
                byteCount = try checkedAdd(byteCount, term.utf8.count)
                guard byteCount <= 64 * 1024 * 1024 else {
                    throw temporalFailure("temporal.resource-limit", .insufficientResources)
                }
                total = try checkedAdd(total, count)
                vocabulary.insert(term)
                guard vocabulary.count <= 10_000 else {
                    throw temporalFailure("temporal.resource-limit", .insufficientResources)
                }
            }
            guard total <= document.tokenCount else {
                throw temporalFailure("temporal.invalid-exposure")
            }
        }
        let terms = vocabulary.sorted()
        let termPositions = Dictionary(
            uniqueKeysWithValues: terms.enumerated().map { ($0.element, $0.offset) })
        let aggregateCount =
            configuration.bucketCount + (configuration.missingPolicy == .separate ? 1 : 0)
        guard terms.count <= 10_000,
            terms.isEmpty || aggregateCount <= 1_000_000 / terms.count
        else { throw temporalFailure("temporal.resource-limit", .insufficientResources) }
        var civilBoundaries = [configuration.origin]
        for index in 0..<configuration.bucketCount {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            guard let previous = civilBoundaries.last else {
                throw temporalFailure("temporal.invalid-boundaries")
            }
            civilBoundaries.append(
                try previous.adding(configuration.bucketWidth, unit: configuration.granularity))
        }
        let boundaries: [GlifiTemporalBoundary]
        let positions: [Double]
        switch configuration.basis {
        case .civilDates:
            boundaries = civilBoundaries.map(GlifiTemporalBoundary.civilDate)
            positions = civilBoundaries.map { Double($0.ordinal) }
        case .instants(let identifier):
            guard let zone = TimeZone(identifier: identifier) else {
                throw temporalFailure("temporal.invalid-time-zone")
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let dates = try civilBoundaries.enumerated().map { index, value in
                if index.isMultiple(of: 256) { try Task.checkCancellation() }
                let components = DateComponents(
                    calendar: calendar, timeZone: zone,
                    year: value.year, month: value.month, day: value.day,
                    hour: 0, minute: 0, second: 0)
                guard let candidate = calendar.date(from: components),
                    let date = calendar.nextDate(
                        after: candidate.addingTimeInterval(-172_800), matching: components,
                        matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward),
                    calendar.component(.year, from: date) == value.year,
                    calendar.component(.month, from: date) == value.month,
                    calendar.component(.day, from: date) == value.day,
                    calendar.component(.hour, from: date) == 0
                else { throw temporalFailure("temporal.nonexistent-boundary") }
                return date
            }
            boundaries = dates.map(GlifiTemporalBoundary.instant)
            positions = dates.map(\.timeIntervalSinceReferenceDate)
        }
        guard zip(positions, positions.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw temporalFailure("temporal.invalid-boundaries")
        }
        var assignments = [[Int]](repeating: [], count: configuration.bucketCount)
        var missing: [Int] = []
        var excluded: [GlifiTemporalExclusion] = []
        for (index, documentIndex) in order.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let document = documents[documentIndex]
            if document.value == .missing {
                switch configuration.missingPolicy {
                case .exclude:
                    excluded.append(exclusion(document, reason: "temporal.missing-date"))
                case .separate: missing.append(documentIndex)
                case .reject: throw temporalFailure("temporal.missing-date", .insufficientData)
                }
                continue
            }
            let position = try position(document.value, configuration: configuration)
            guard let first = positions.first, let last = positions.last else {
                throw temporalFailure("temporal.invalid-boundaries")
            }
            if position < first || position >= last {
                let reason = position < first ? "temporal.before-domain" : "temporal.after-domain"
                if configuration.outsidePolicy == .reject { throw temporalFailure(reason) }
                excluded.append(exclusion(document, reason: reason))
                continue
            }
            var lower = 0
            var upper = positions.count - 1
            while lower + 1 < upper {
                let middle = (lower + upper) / 2
                if position < positions[middle] { upper = middle } else { lower = middle }
            }
            assignments[lower].append(documentIndex)
        }
        var buckets: [GlifiTemporalBucket] = []
        for index in assignments.indices {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            buckets.append(
                GlifiTemporalBucket(
                    start: boundaries[index], end: boundaries[index + 1],
                    aggregate: try summarize(
                        assignments[index], documents: documents, terms: terms,
                        termPositions: termPositions)))
        }
        return GlifiTemporalResult(
            configuration: configuration, buckets: buckets,
            missing: configuration.missingPolicy == .separate
                ? try summarize(
                    missing, documents: documents, terms: terms, termPositions: termPositions)
                : nil,
            excluded: excluded)
    }

    private static func canonicalOrder(_ documents: [GlifiTemporalDocument]) throws -> [Int] {
        // Render each canonical key once and release the temporary key array when
        // this helper returns, before validation and output aggregates overlap in memory.
        let keys = try documents.enumerated().map { index, document in
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            return document.sourceRevisionID.canonicalValue
        }
        let order = documents.indices.sorted { keys[$0] < keys[$1] }
        try Task.checkCancellation()
        return order
    }

    private static func position(
        _ value: GlifiTemporalValue, configuration: GlifiTemporalConfiguration
    ) throws -> Double {
        switch value {
        case .instant(let date):
            guard case .instants = configuration.basis, date.timeIntervalSinceReferenceDate.isFinite
            else {
                throw temporalFailure("temporal.incompatible-basis")
            }
            return date.timeIntervalSinceReferenceDate
        case .civilDate(let date):
            guard configuration.basis == .civilDates else {
                throw temporalFailure("temporal.incompatible-basis")
            }
            return Double(date.ordinal)
        case .civilMonth(let year, let month):
            guard configuration.basis == .civilDates, configuration.granularity != .day else {
                throw temporalFailure("temporal.insufficient-precision")
            }
            return Double(try GlifiCivilDate(year: year, month: month, day: 1).ordinal)
        case .civilYear(let year):
            guard configuration.basis == .civilDates, configuration.granularity == .year else {
                throw temporalFailure("temporal.insufficient-precision")
            }
            return Double(try GlifiCivilDate(year: year, month: 1, day: 1).ordinal)
        case .interval, .uncertainPeriod:
            throw temporalFailure("temporal.unsupported-assignment")
        case .missing:
            throw temporalFailure("temporal.missing-date", .insufficientData)
        }
    }

    private static func summarize(
        _ indices: [Int], documents: [GlifiTemporalDocument], terms: [String],
        termPositions: [String: Int]
    ) throws -> GlifiTemporalAggregate {
        var tokenCount = 0
        var counts = [Int](repeating: 0, count: terms.count)
        var contributors = [[SourceRevisionID]](repeating: [], count: terms.count)
        var processedCounts = 0
        for (index, documentIndex) in indices.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let document = documents[documentIndex]
            tokenCount = try checkedAdd(tokenCount, document.tokenCount)
            for (term, count) in document.termCounts where count > 0 {
                if processedCounts.isMultiple(of: 256) { try Task.checkCancellation() }
                processedCounts += 1
                guard let position = termPositions[term] else {
                    throw temporalFailure("temporal.invalid-count")
                }
                counts[position] = try checkedAdd(counts[position], count)
                contributors[position].append(document.sourceRevisionID)
            }
        }
        let frequencies = try terms.enumerated().map { index, term in
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let frequency = counts[index]
            let revisions = contributors[index]
            return GlifiTemporalTermFrequency(
                term: term, frequency: frequency, documentFrequency: revisions.count,
                perThousandTokenRate: tokenCount > 0
                    ? Double(frequency) / Double(tokenCount) * 1000 : nil,
                sourceRevisionIDs: revisions)
        }
        return GlifiTemporalAggregate(
            documentCount: indices.count, tokenCount: tokenCount, terms: frequencies,
            lineage: indices.map { documentIndex in
                let document = documents[documentIndex]
                return .init(
                    sourceRevisionID: document.sourceRevisionID,
                    metadataProvenance: document.metadataProvenance
                )
            })
    }

    private static func exclusion(_ document: GlifiTemporalDocument, reason: String)
        -> GlifiTemporalExclusion
    {
        GlifiTemporalExclusion(
            lineage: .init(
                sourceRevisionID: document.sourceRevisionID,
                metadataProvenance: document.metadataProvenance),
            reasonIdentifier: reason)
    }

    private static func checkedAdd(_ left: Int, _ right: Int) throws -> Int {
        let (sum, overflow) = left.addingReportingOverflow(right)
        guard !overflow else { throw temporalFailure("temporal.count-overflow") }
        return sum
    }
}

private func temporalFailure(
    _ code: String, _ category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: .unchanged, messageKey: "failure.category.\(category.rawValue)")
}
