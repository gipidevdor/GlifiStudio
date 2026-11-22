// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Application-facing Gregorian civil date, without an implicit time zone.
public struct GlifiStudioCivilDate: Encodable, Equatable, Sendable {
    /// Gregorian year in `1...9999`.
    public let year: Int
    /// Gregorian month in `1...12`.
    public let month: Int
    /// Validated day of the Gregorian month.
    public let day: Int

    /// Creates a valid Gregorian date and rejects implicit calendar normalization.
    public init(year: Int, month: Int, day: Int) throws(GlifiStudioFailure) {
        self = try mapTemporalFailure {
            try Self(GlifiCivilDate(year: year, month: month, day: day))
        }
    }

    fileprivate init(_ value: GlifiCivilDate) {
        year = value.year
        month = value.month
        day = value.day
    }

    fileprivate var core: GlifiCivilDate {
        get throws { try GlifiCivilDate(year: year, month: month, day: day) }
    }
}

/// Observed precision and type are preserved across the facade.
public enum GlifiStudioTemporalValue: Equatable, Sendable {
    case instant(Date)
    case civilDate(GlifiStudioCivilDate)
    case civilMonth(year: Int, month: Int)
    case civilYear(Int)
    case interval(start: Date, end: Date)
    case uncertainPeriod(lower: GlifiStudioCivilDate, upper: GlifiStudioCivilDate)
    case missing

    fileprivate var core: GlifiTemporalValue {
        get throws {
            switch self {
            case .instant(let value): .instant(value)
            case .civilDate(let value): .civilDate(try value.core)
            case .civilMonth(let year, let month): .civilMonth(year: year, month: month)
            case .civilYear(let year): .civilYear(year)
            case .interval(let start, let end): .interval(start: start, end: end)
            case .uncertainPeriod(let lower, let upper):
                .uncertainPeriod(lower: try lower.core, upper: try upper.core)
            case .missing: .missing
            }
        }
    }
}

/// Calendar basis for civil metadata or instants in an explicit time zone.
public enum GlifiStudioTemporalBasis: Equatable, Sendable {
    case civilDates
    case instants(timeZoneIdentifier: String)

    fileprivate var core: GlifiTemporalBasis {
        switch self {
        case .civilDates: .civilDates
        case .instants(let identifier): .instants(timeZoneIdentifier: identifier)
        }
    }
}

/// Calendar units, rather than elapsed seconds.
public enum GlifiStudioTemporalGranularity: String, Equatable, Sendable {
    case day
    case month
    case year

    fileprivate var core: GlifiTemporalGranularity {
        switch self {
        case .day: .day
        case .month: .month
        case .year: .year
        }
    }
}

/// Explicit handling of missing metadata.
public enum GlifiStudioTemporalMissingPolicy: String, Equatable, Sendable {
    case exclude
    case separate
    case reject

    fileprivate var core: GlifiTemporalMissingPolicy {
        switch self {
        case .exclude: .exclude
        case .separate: .separate
        case .reject: .reject
        }
    }
}

/// Explicit handling of values outside the chosen domain.
public enum GlifiStudioTemporalOutsidePolicy: String, Equatable, Sendable {
    case exclude
    case reject

    fileprivate var core: GlifiTemporalOutsidePolicy {
        switch self {
        case .exclude: .exclude
        case .reject: .reject
        }
    }
}

/// A fully specified, immutable calendar partition.
public struct GlifiStudioTemporalConfiguration: Equatable, Sendable {
    /// Civil dates or instants in an explicit time zone.
    public let basis: GlifiStudioTemporalBasis
    /// Calendar unit used to advance bucket boundaries.
    public let granularity: GlifiStudioTemporalGranularity
    /// Inclusive lower boundary of the first calendar bucket.
    public let origin: GlifiStudioCivilDate
    /// Positive number of calendar units per bucket.
    public let bucketWidth: Int
    /// Number of chronological buckets, including empty buckets.
    public let bucketCount: Int
    /// Declared treatment of missing dates.
    public let missingPolicy: GlifiStudioTemporalMissingPolicy
    /// Declared treatment of observations outside the chosen domain.
    public let outsidePolicy: GlifiStudioTemporalOutsidePolicy

    /// Declares an explicit calendar partition; execution validates its limits and alignment.
    public init(
        basis: GlifiStudioTemporalBasis, granularity: GlifiStudioTemporalGranularity,
        origin: GlifiStudioCivilDate, bucketWidth: Int, bucketCount: Int,
        missingPolicy: GlifiStudioTemporalMissingPolicy,
        outsidePolicy: GlifiStudioTemporalOutsidePolicy
    ) {
        self.basis = basis
        self.granularity = granularity
        self.origin = origin
        self.bucketWidth = bucketWidth
        self.bucketCount = bucketCount
        self.missingPolicy = missingPolicy
        self.outsidePolicy = outsidePolicy
    }

    fileprivate var core: GlifiTemporalConfiguration {
        get throws {
            try GlifiTemporalConfiguration(
                basis: basis.core, granularity: granularity.core, origin: origin.core,
                bucketWidth: bucketWidth, bucketCount: bucketCount,
                missingPolicy: missingPolicy.core, outsidePolicy: outsidePolicy.core)
        }
    }
}

/// Observed document counts and metadata provenance, without project mutations.
public struct GlifiStudioTemporalDocument: Equatable, Sendable {
    /// Exact immutable source revision identity.
    public let sourceRevisionID: String
    /// Caller-supplied provenance of the observed temporal metadata.
    public let metadataProvenance: String
    /// Observed temporal type and precision.
    public let value: GlifiStudioTemporalValue
    /// Observed token exposure, including terms not selected for output.
    public let tokenCount: Int
    /// Non-negative observed term counts, bounded by token exposure.
    public let termCounts: [String: Int]

    /// Creates immutable observed counts for one source revision.
    public init(
        sourceRevisionID: String, metadataProvenance: String,
        value: GlifiStudioTemporalValue, tokenCount: Int, termCounts: [String: Int]
    ) {
        self.sourceRevisionID = sourceRevisionID
        self.metadataProvenance = metadataProvenance
        self.value = value
        self.tokenCount = tokenCount
        self.termCounts = termCounts
    }
}

/// Revision-level provenance for a temporal observation.
public struct GlifiStudioTemporalLineage: Encodable, Equatable, Sendable {
    /// Exact immutable source revision identity.
    public let sourceRevisionID: String
    /// Caller-supplied provenance of the observed temporal metadata.
    public let metadataProvenance: String

    fileprivate init(_ value: GlifiTemporalLineage) {
        sourceRevisionID = value.sourceRevisionID.canonicalValue
        metadataProvenance = value.metadataProvenance
    }
}

/// Counts and descriptive rates retain their denominators and contributors.
public struct GlifiStudioTemporalTermFrequency: Encodable, Equatable, Sendable {
    /// Term identity preserved without implicit normalization.
    public let term: String
    /// Exact observed count in this aggregate.
    public let frequency: Int
    /// Number of contributing documents with a positive term count.
    public let documentFrequency: Int
    /// `1000 * frequency / tokenCount`, or `nil` for zero token exposure.
    public let perThousandTokenRate: Double?
    /// Revisions with a positive term contribution, in canonical identity order.
    public let sourceRevisionIDs: [String]

    fileprivate init(_ value: GlifiTemporalTermFrequency) {
        term = value.term
        frequency = value.frequency
        documentFrequency = value.documentFrequency
        perThousandTokenRate = value.perThousandTokenRate
        sourceRevisionIDs = value.sourceRevisionIDs.map(\.canonicalValue)
    }
}

/// Aggregate values are observed counts; an absent rate is never replaced with zero.
public struct GlifiStudioTemporalAggregate: Encodable, Equatable, Sendable {
    /// Number of documents assigned to this aggregate.
    public let documentCount: Int
    /// Observed token exposure, including terms not selected for output.
    public let tokenCount: Int
    /// Term results in canonical lexical order.
    public let terms: [GlifiStudioTemporalTermFrequency]
    /// Source revisions and observed metadata provenance in canonical identity order.
    public let lineage: [GlifiStudioTemporalLineage]

    fileprivate init(_ value: GlifiTemporalAggregate) {
        documentCount = value.documentCount
        tokenCount = value.tokenCount
        terms = value.terms.map(GlifiStudioTemporalTermFrequency.init)
        lineage = value.lineage.map(GlifiStudioTemporalLineage.init)
    }
}

/// A bucket boundary keeps its type through presentation and encoding.
public enum GlifiStudioTemporalBoundary: Encodable, Equatable, Sendable {
    case civilDate(GlifiStudioCivilDate)
    case instant(Date)

    fileprivate init(_ value: GlifiTemporalBoundary) {
        switch value {
        case .civilDate(let date): self = .civilDate(GlifiStudioCivilDate(date))
        case .instant(let date): self = .instant(date)
        }
    }
}

/// Inclusive lower and exclusive upper boundary with source-level lineage.
public struct GlifiStudioTemporalBucket: Encodable, Equatable, Sendable {
    /// Inclusive lower bucket boundary, preserving its temporal type.
    public let start: GlifiStudioTemporalBoundary
    /// Exclusive upper bucket boundary, preserving its temporal type.
    public let end: GlifiStudioTemporalBoundary
    /// Observed counts and token-normalized descriptive rates for this bucket.
    public let aggregate: GlifiStudioTemporalAggregate
}

/// An observation excluded under the selected missing/outside policy.
public struct GlifiStudioTemporalExclusion: Encodable, Equatable, Sendable {
    /// Source revisions and observed metadata provenance in canonical identity order.
    public let lineage: GlifiStudioTemporalLineage
    /// Machine-readable reason for excluding the observed document.
    public let reasonIdentifier: String
}

/// Chronologically ordered, descriptive temporal series.
public struct GlifiStudioTemporalResult: Equatable, Sendable {
    /// Candidate headless contract; no service-quality or external scientific approval is implied.
    public static let validationStatus = "candidate"
    /// Versioned headless calendar aggregation identity.
    public let methodIdentifier: String
    /// All resolved temporal choices used by the aggregation.
    public let configuration: GlifiStudioTemporalConfiguration
    /// Calendar buckets in chronological order, including empty buckets.
    public let buckets: [GlifiStudioTemporalBucket]
    /// Separate missing-date aggregate when the selected policy requests it.
    public let missing: GlifiStudioTemporalAggregate?
    /// Excluded documents and reasons, in canonical source identity order.
    public let excluded: [GlifiStudioTemporalExclusion]

    fileprivate init(_ value: GlifiTemporalResult, configuration: GlifiStudioTemporalConfiguration)
    {
        methodIdentifier = GlifiTemporalResult.identifier
        self.configuration = configuration
        buckets = value.buckets.map {
            .init(start: .init($0.start), end: .init($0.end), aggregate: .init($0.aggregate))
        }
        missing = value.missing.map(GlifiStudioTemporalAggregate.init)
        excluded = value.excluded.map {
            .init(lineage: .init($0.lineage), reasonIdentifier: $0.reasonIdentifier)
        }
    }
}

extension GlifiStudioTextAnalytics {
    /// Aggregates observed term counts in explicit calendar buckets outside the caller's actor.
    @concurrent public static func temporalFrequencies(
        _ documents: [GlifiStudioTemporalDocument], configuration: GlifiStudioTemporalConfiguration
    ) async throws(GlifiStudioFailure) -> GlifiStudioTemporalResult {
        try mapTemporalFailure {
            let core = try documents.map {
                try GlifiTemporalDocument(
                    sourceRevisionID: SourceRevisionID(canonicalValue: $0.sourceRevisionID),
                    metadataProvenance: $0.metadataProvenance, value: $0.value.core,
                    tokenCount: $0.tokenCount, termCounts: $0.termCounts)
            }
            return try GlifiStudioTemporalResult(
                GlifiTemporalAnalysis.aggregate(core, configuration: configuration.core),
                configuration: configuration)
        }
    }
}

private func mapTemporalFailure<Value>(_ body: () throws -> Value) throws(GlifiStudioFailure)
    -> Value
{
    do { return try body() } catch let failure as GlifiFailure {
        throw GlifiStudioFailure(failure)
    } catch is CancellationError {
        throw GlifiStudioFailure(
            code: "operation.cancelled", category: "cancelled", operation: "analyze",
            retryDisposition: "newRequest", retainedState: "unchanged",
            messageKey: "failure.category.cancelled")
    } catch {
        throw GlifiStudioFailure(
            code: "temporal.failed", category: "invalidInput", operation: "analyze",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.category.invalidInput")
    }
}
