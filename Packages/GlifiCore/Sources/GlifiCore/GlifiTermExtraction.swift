// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Which internal component adjacency statistic contributes to LR.
public enum GlifiTermAdjacencyMode: String, Sendable {
    /// Repeated adjacency occurrences, weighted by independent candidate frequency.
    case token
    /// Distinct adjacent component keys on each side.
    case type
}

/// One pre-extracted term and its independent frequency f(CN).
///
/// An occurrence embedded in a larger candidate must not be counted again here.
/// Repeated entries are combined. Keys use Swift's canonical Unicode equality;
/// no case folding, stemming, tokenization or POS annotation is performed.
public struct GlifiTermCandidate: Equatable, Sendable {
    /// Ordered, already segmented lexical component keys.
    public let components: [String]
    /// Positive number of independent occurrences of the complete candidate.
    public let frequency: Int

    /// Creates a bounded candidate without inferring its linguistic structure.
    public init(components: [String], frequency: Int) throws {
        guard !components.isEmpty, components.count <= 64, frequency > 0,
            components.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 4_096 })
        else { throw termExtractionFailure("term-extraction.invalid-candidate") }
        self.components = components
        self.frequency = frequency
    }
}

/// Observed left/right adjacency counts before adding the LR smoothing constant one.
public struct GlifiTermComponentStatistics: Equatable, Sendable {
    /// Caller-supplied lexical key.
    public let component: String
    /// Weighted adjacency occurrences immediately to the left.
    public let leftFrequency: Int
    /// Weighted adjacency occurrences immediately to the right.
    public let rightFrequency: Int
    /// Number of distinct lexical keys immediately to the left.
    public let leftTypeCount: Int
    /// Number of distinct lexical keys immediately to the right.
    public let rightTypeCount: Int
}

/// A term's original independent frequency and the two distinct relevance scores.
public struct GlifiTermScore: Equatable, Sendable {
    /// Ordered candidate components, without a language-dependent join operation.
    public let components: [String]
    /// Aggregated independent frequency, excluding occurrences in larger candidates.
    public let frequency: Int
    /// Geometric mean of the smoothed left and right component adjacency counts.
    public let lr: Double
    /// Independent frequency multiplied by LR.
    public let flr: Double
}

/// LR/FLR observations over caller-declared candidates, without a language-quality claim.
public struct GlifiTermExtractionScores: Equatable, Sendable {
    /// Versioned score definition, including independent frequency and unit exponent.
    public static let identifier = "TermExtract-LR-FLR-independent-average1-v1"
    /// Applied adjacency counting convention.
    public let adjacencyMode: GlifiTermAdjacencyMode
    /// Caller-declared candidate formation and normalization contract.
    public let preprocessingIdentifier: String
    /// Total independent candidate occurrences, with checked integer accumulation.
    public let independentOccurrenceCount: Int
    /// Scores by decreasing FLR, with lexicographic component ties.
    public let terms: [GlifiTermScore]
    /// Unsmoothed observations in lexicographic component order.
    public let components: [GlifiTermComponentStatistics]
}

/// Explicit maximal-POS-run rule for an already annotated document.
///
/// This is a candidate-formation rule, not an English or Japanese tokenizer.
/// Missing POS is rejected. Sentence, paragraph and non-whitespace source gaps
/// split runs; ignored keys and POS outside the admitted set also split runs.
public struct GlifiTermExtractionRule: Equatable, Sendable {
    /// Versioned caller identity of the complete POS/candidate policy.
    public let identifier: String
    /// Exact backend POS labels that may occur in a candidate.
    public let allowedPartsOfSpeech: Set<String>
    /// Explicit excluded component keys; no built-in stopword list is inferred.
    public let ignoredKeys: Set<String>
    /// Minimum admitted maximal-run length; two selects compounds only.
    public let minimumComponents: Int
    /// Maximum admitted maximal-run length; longer runs fail rather than truncate.
    public let maximumComponents: Int

    /// Creates one explicit, bounded candidate-formation rule.
    public init(
        identifier: String, allowedPartsOfSpeech: Set<String>, ignoredKeys: Set<String> = [],
        minimumComponents: Int = 2, maximumComponents: Int = 64
    ) throws {
        guard !identifier.isEmpty, identifier.utf8.count <= 4_096,
            !allowedPartsOfSpeech.isEmpty, allowedPartsOfSpeech.count <= 256,
            allowedPartsOfSpeech.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1_024 }),
            ignoredKeys.count <= 4_096,
            ignoredKeys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 4_096 }),
            minimumComponents >= 1, maximumComponents >= minimumComponents,
            maximumComponents <= 64
        else { throw termExtractionFailure("term-extraction.invalid-rule") }
        self.identifier = identifier
        self.allowedPartsOfSpeech = allowedPartsOfSpeech
        self.ignoredKeys = ignoredKeys
        self.minimumComponents = minimumComponents
        self.maximumComponents = maximumComponents
    }
}

/// One independently extracted candidate with exact evidence in the supplied document.
public struct GlifiTermOccurrence: Equatable, Sendable {
    /// Original caller document identity.
    public let documentID: String
    /// Original lexical component keys in order.
    public let components: [String]
    /// Half-open token indices in the caller-supplied token sequence.
    public let tokenRange: Range<Int>
    /// Exact encompassing UTF-8 source interval, including internal whitespace.
    public let range: GlifiUTF8Range
}

/// Source evidence and scores from an explicit rule over existing annotations.
public struct GlifiTermExtractionResult: Equatable, Sendable {
    /// Complete candidate-formation rule, retained without implicit defaults.
    public let rule: GlifiTermExtractionRule
    /// Input document identities in original order, including empty documents.
    public let documentIDs: [String]
    /// Annotation contracts aligned with the input document identities.
    public let linguisticContracts: [String]
    /// Independent occurrences in document/token order.
    public let occurrences: [GlifiTermOccurrence]
    /// Ranked scores over the observed maximal candidates.
    public let scores: GlifiTermExtractionScores
}

/// Bounded native LR and FLR, with no production dependency on TermExtract or a tagger.
public enum GlifiTermExtraction {
    /// Maximum distinct candidates, input candidate records and retained occurrences.
    public static let maximumCandidateCount = 100_000
    /// Maximum component observations or annotated tokens across one request.
    public static let maximumTokenCount = 1_000_000
    /// Aggregate textual input budget, including source text and annotation keys.
    public static let maximumInputBytes = 64 * 1_024 * 1_024
    /// Default budget for validation, adjacency counting, scoring and ordering.
    public static let defaultMaximumWork = 100_000_000
    /// Absolute ceiling for a caller-selected work budget.
    public static let maximumWork = 1_000_000_000

    /// Scores independently counted candidates with adding-one smoothing and exponent 1/(2L).
    ///
    /// Only internal adjacencies of multiword candidates contribute. A repeated
    /// component contributes at every position; a single-word candidate contributes
    /// no adjacency. The frequency factor is f, not TF including nested occurrences.
    public static func score(
        _ candidates: [GlifiTermCandidate], adjacencyMode: GlifiTermAdjacencyMode = .token,
        preprocessingIdentifier: String, maximumWork: Int = defaultMaximumWork
    ) throws -> GlifiTermExtractionScores {
        try Task.checkCancellation()
        let budget = try TermExtractionWorkBudget(maximumWork)
        return try calculate(
            candidates, adjacencyMode: adjacencyMode,
            preprocessingIdentifier: preprocessingIdentifier, budget: budget)
    }

    /// Extracts maximal runs from existing POS annotations and retains exact source evidence.
    public static func extract(
        _ documents: [GlifiCodingDocument], rule: GlifiTermExtractionRule,
        adjacencyMode: GlifiTermAdjacencyMode = .token,
        maximumWork: Int = defaultMaximumWork
    ) throws -> GlifiTermExtractionResult {
        try Task.checkCancellation()
        let budget = try TermExtractionWorkBudget(maximumWork)
        guard documents.count <= maximumCandidateCount else { throw termExtractionLimit() }
        var remainingBytes = maximumInputBytes
        var tokenCount = 0
        var identities = Set<String>()
        for text in [rule.identifier] + Array(rule.allowedPartsOfSpeech) + Array(rule.ignoredKeys) {
            try consumeText(text, remaining: &remainingBytes, budget: budget)
        }
        for document in documents {
            try budget.consume(1)
            guard document.id.utf8.count <= 4_096,
                document.linguisticContract.utf8.count <= 4_096
            else { throw termExtractionLimit() }
            for text in [document.id, document.linguisticContract, document.text] {
                try consumeText(text, remaining: &remainingBytes, budget: budget)
            }
            guard identities.insert(document.id).inserted,
                document.tokens.count <= maximumTokenCount - tokenCount
            else { throw termExtractionFailure("term-extraction.invalid-documents") }
            tokenCount += document.tokens.count
            for token in document.tokens {
                guard token.base.utf8.count <= 4_096 else { throw termExtractionLimit() }
                try consumeText(token.base, remaining: &remainingBytes, budget: budget)
                guard let pos = token.partOfSpeech, !pos.isEmpty else {
                    throw termExtractionFailure("term-extraction.missing-pos")
                }
                guard pos.utf8.count <= 1_024 else { throw termExtractionLimit() }
                try consumeText(pos, remaining: &remainingBytes, budget: budget)
            }
        }
        var occurrences: [GlifiTermOccurrence] = []
        var frequencies: [[String]: Int] = [:]
        for document in documents {
            try Task.checkCancellation()
            let bytes = Array(document.text.utf8)
            var start: Int?
            var end = 0
            func finishRun() throws {
                guard let first = start else { return }
                defer { start = nil }
                guard end - first >= rule.minimumComponents else { return }
                guard occurrences.count < maximumCandidateCount else { throw termExtractionLimit() }
                let parts = document.tokens[first..<end].map(\.base)
                try budget.consume(parts.reduce(0) { $0 + $1.utf8.count })
                if frequencies[parts] == nil, frequencies.count >= maximumCandidateCount {
                    throw termExtractionLimit()
                }
                frequencies[parts, default: 0] += 1
                occurrences.append(
                    GlifiTermOccurrence(
                        documentID: document.id, components: parts, tokenRange: first..<end,
                        range: try GlifiUTF8Range(
                            start: document.tokens[first].range.start,
                            end: document.tokens[end - 1].range.end)))
            }
            for (index, token) in document.tokens.enumerated() {
                try budget.consume(1)
                if start != nil, index > 0 {
                    let previous = document.tokens[index - 1]
                    if previous.sentence != token.sentence || previous.paragraph != token.paragraph
                    {
                        try finishRun()
                    } else if !(try whitespaceGap(
                        bytes, from: previous.range.end, to: token.range.start, budget: budget))
                    {
                        try finishRun()
                    }
                }
                if let pos = token.partOfSpeech, rule.allowedPartsOfSpeech.contains(pos),
                    !rule.ignoredKeys.contains(token.base)
                {
                    if start == nil { start = index }
                    end = index + 1
                    if let first = start, end - first > rule.maximumComponents {
                        throw termExtractionFailure(
                            "term-extraction.component-limit", .insufficientResources)
                    }
                } else {
                    try finishRun()
                }
            }
            try finishRun()
        }
        let candidates = try frequencies.map {
            try GlifiTermCandidate(components: $0.key, frequency: $0.value)
        }
        let scores = try calculate(
            candidates, adjacencyMode: adjacencyMode,
            preprocessingIdentifier: rule.identifier, budget: budget)
        return GlifiTermExtractionResult(
            rule: rule, documentIDs: documents.map(\.id),
            linguisticContracts: documents.map(\.linguisticContract),
            occurrences: occurrences, scores: scores)
    }

    private static func calculate(
        _ candidates: [GlifiTermCandidate], adjacencyMode: GlifiTermAdjacencyMode,
        preprocessingIdentifier: String, budget: TermExtractionWorkBudget
    ) throws -> GlifiTermExtractionScores {
        guard candidates.count <= maximumCandidateCount, !preprocessingIdentifier.isEmpty else {
            throw termExtractionFailure("term-extraction.invalid-input")
        }
        var remainingBytes = maximumInputBytes
        try consumeText(preprocessingIdentifier, remaining: &remainingBytes, budget: budget)
        var componentCount = 0
        var totalFrequency = 0
        var frequencies: [[String]: Int] = [:]
        var observations: [String: TermComponentAdjacency] = [:]
        for candidate in candidates {
            try budget.consume(1)
            guard candidate.components.count <= maximumTokenCount - componentCount else {
                throw termExtractionLimit()
            }
            componentCount += candidate.components.count
            for component in candidate.components {
                try consumeText(component, remaining: &remainingBytes, budget: budget)
                if observations[component] == nil {
                    observations[component] = TermComponentAdjacency()
                }
            }
            frequencies[candidate.components] = try add(
                frequencies[candidate.components] ?? 0, candidate.frequency)
            totalFrequency = try add(totalFrequency, candidate.frequency)
            for index in candidate.components.indices.dropFirst() {
                try budget.consume(1)
                let left = candidate.components[index - 1]
                let right = candidate.components[index]
                let rightFrequency = try add(
                    observations[left]?.rightFrequency ?? 0, candidate.frequency)
                observations[left, default: TermComponentAdjacency()].rightFrequency =
                    rightFrequency
                observations[left, default: TermComponentAdjacency()].right.insert(right)
                let leftFrequency = try add(
                    observations[right]?.leftFrequency ?? 0, candidate.frequency)
                observations[right, default: TermComponentAdjacency()].leftFrequency = leftFrequency
                observations[right, default: TermComponentAdjacency()].left.insert(left)
            }
        }
        var terms: [GlifiTermScore] = []
        for (parts, frequency) in frequencies {
            try budget.consume(1)
            var logSum = 0.0
            for part in parts {
                try budget.consume(part.utf8.count + 1)
                let value = observations[part] ?? TermComponentAdjacency()
                let left = adjacencyMode == .token ? value.leftFrequency : value.left.count
                let right = adjacencyMode == .token ? value.rightFrequency : value.right.count
                logSum += log1p(Double(left)) + log1p(Double(right))
            }
            let lr = exp(logSum / (2 * Double(parts.count)))
            let flr = Double(frequency) * lr
            guard lr.isFinite, flr.isFinite else {
                throw termExtractionFailure("term-extraction.numeric-overflow")
            }
            terms.append(GlifiTermScore(components: parts, frequency: frequency, lr: lr, flr: flr))
        }
        try terms.sort {
            try budget.consume(1)
            if $0.flr != $1.flr { return $0.flr > $1.flr }
            try budget.consume(
                $0.components.reduce(0) { $0 + $1.utf8.count }
                    + $1.components.reduce(0) { $0 + $1.utf8.count })
            return $0.components.lexicographicallyPrecedes($1.components)
        }
        let componentKeys = try observations.keys.sorted {
            try budget.consume($0.utf8.count + $1.utf8.count + 1)
            return $0 < $1
        }
        var statistics: [GlifiTermComponentStatistics] = []
        for key in componentKeys {
            try budget.consume(1)
            let value = observations[key] ?? TermComponentAdjacency()
            statistics.append(
                GlifiTermComponentStatistics(
                    component: key, leftFrequency: value.leftFrequency,
                    rightFrequency: value.rightFrequency,
                    leftTypeCount: value.left.count, rightTypeCount: value.right.count))
        }
        try Task.checkCancellation()
        return GlifiTermExtractionScores(
            adjacencyMode: adjacencyMode, preprocessingIdentifier: preprocessingIdentifier,
            independentOccurrenceCount: totalFrequency, terms: terms, components: statistics)
    }

    private static func whitespaceGap(
        _ bytes: [UInt8], from start: Int, to end: Int, budget: TermExtractionWorkBudget
    ) throws -> Bool {
        guard start < end else { return true }
        let gap = String(decoding: bytes[start..<end], as: UTF8.self)
        for scalar in gap.unicodeScalars {
            try budget.consume(1)
            guard CharacterSet.whitespacesAndNewlines.contains(scalar) else { return false }
        }
        return true
    }

    private static func consumeText(
        _ text: String, remaining: inout Int, budget: TermExtractionWorkBudget
    ) throws {
        let count = text.utf8.count
        guard count <= remaining else { throw termExtractionLimit() }
        remaining -= count
        try budget.consume(count + 1)
    }

    private static func add(_ first: Int, _ second: Int) throws -> Int {
        let result = first.addingReportingOverflow(second)
        guard !result.overflow else {
            throw termExtractionFailure("term-extraction.frequency-overflow")
        }
        return result.partialValue
    }
}

private struct TermComponentAdjacency {
    var leftFrequency = 0
    var rightFrequency = 0
    var left = Set<String>()
    var right = Set<String>()
}

private final class TermExtractionWorkBudget {
    private var remaining: Int
    private var checkpoint = 0

    init(_ maximumWork: Int) throws {
        guard maximumWork > 0, maximumWork <= GlifiTermExtraction.maximumWork else {
            throw termExtractionFailure("term-extraction.invalid-work-limit")
        }
        remaining = maximumWork
    }

    func consume(_ count: Int) throws {
        guard count <= remaining else {
            throw termExtractionFailure("term-extraction.work-limit", .insufficientResources)
        }
        remaining -= count
        checkpoint = (checkpoint + 1) & 1_023
        if checkpoint == 0 { try Task.checkCancellation() }
    }
}

private func termExtractionLimit() -> GlifiFailure {
    termExtractionFailure("term-extraction.input-limit", .insufficientResources)
}

private func termExtractionFailure(
    _ code: String, _ category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code, category: category, operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: .unchanged, messageKey: "failure.\(code)")
}
