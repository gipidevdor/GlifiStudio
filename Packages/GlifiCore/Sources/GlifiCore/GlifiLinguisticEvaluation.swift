// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Explicit treatment of a metric with no observations in its denominator.
public enum GlifiEvaluationZeroPolicy: String, Codable, Sendable {
    /// Preserve an undefined metric as `nil`, including averages containing it.
    case undefined
    /// Report zero for undefined metrics; never infer perfect performance.
    case zero
}

/// Exact-match precision, recall and F1 with their reconstructible integer counts.
public struct GlifiEvaluationScore: Codable, Equatable, Sendable {
    /// Correct predictions.
    public let truePositiveCount: Int
    /// Predictions without a matching gold annotation.
    public let falsePositiveCount: Int
    /// Gold annotations without a matching prediction.
    public let falseNegativeCount: Int
    /// `TP / (TP + FP)` under the declared zero policy.
    public let precision: Double?
    /// `TP / (TP + FN)` under the declared zero policy.
    public let recall: Double?
    /// `2TP / (2TP + FP + FN)` under the declared zero policy.
    public let f1: Double?
}

/// Exact token accuracy, also used for exact morphology feature sets.
public struct GlifiEvaluationAccuracy: Codable, Equatable, Sendable {
    /// Number of aligned observations.
    public let observationCount: Int
    /// Exactly matching observations.
    public let correctCount: Int
    /// `correctCount / observationCount` under the declared zero policy.
    public let accuracy: Double?
}

/// Exact lemma errors grouped by a caller-supplied gold form or POS label.
public struct GlifiEvaluationErrorGroup: Codable, Equatable, Sendable {
    /// Canonical group label.
    public let label: String
    /// Gold token count in this group.
    public let observationCount: Int
    /// Tokens with an incorrect lemma in this group.
    public let errorCount: Int
}

/// Exact lemma accuracy and optional error stratification over the same gold tokens.
public struct GlifiLemmaEvaluation: Codable, Equatable, Sendable {
    /// Versioned exact gold-token matching contract.
    public static let identifier = "LinguisticLemmas-exact-v1"
    /// Recorded handling of zero denominators.
    public let zeroPolicy: GlifiEvaluationZeroPolicy
    /// Exact lemma accuracy.
    public let accuracy: GlifiEvaluationAccuracy
    /// Errors per supplied gold surface form, or empty if forms were not supplied.
    public let errorsByForm: [GlifiEvaluationErrorGroup]
    /// Errors per supplied gold POS label, or empty if POS was not supplied.
    public let errorsByPartOfSpeech: [GlifiEvaluationErrorGroup]
}

/// A class or attribute score in canonical label order.
public struct GlifiEvaluationClassScore: Codable, Equatable, Sendable {
    /// Gold/prediction label or morphological attribute.
    public let label: String
    /// Gold support, including incorrect or missing predictions.
    public let support: Int
    /// Exact label or attribute-value matches.
    public let score: GlifiEvaluationScore
}

/// Separately averaged precision, recall and F1; F1 is never recomputed from averaged P/R.
public struct GlifiEvaluationAverage: Codable, Equatable, Sendable {
    /// Mean precision under the declared undefined policy.
    public let precision: Double?
    /// Mean recall under the declared undefined policy.
    public let recall: Double?
    /// Mean class F1 under the declared undefined policy.
    public let f1: Double?
}

/// Single-label classification evaluation on aligned gold tokens (for example POS tags).
public struct GlifiLinguisticClassificationEvaluation: Codable, Equatable, Sendable {
    /// Versioned matching and averaging contract.
    public static let identifier = "LinguisticClassification-exact-v1"
    /// Recorded handling of zero denominators.
    public let zeroPolicy: GlifiEvaluationZeroPolicy
    /// Sorted union of gold and predicted labels.
    public let labels: [String]
    /// Rows are gold labels; columns are predictions, both in `labels` order.
    public let confusionMatrix: [[Int]]
    /// Token accuracy.
    public let accuracy: GlifiEvaluationAccuracy
    /// One-vs-rest scores in label order.
    public let perClass: [GlifiEvaluationClassScore]
    /// Counts summed across all classes before division.
    public let micro: GlifiEvaluationScore
    /// Unweighted mean across every label in the union.
    public let macro: GlifiEvaluationAverage
    /// Gold-support-weighted mean; zero-support labels have zero weight.
    public let weighted: GlifiEvaluationAverage
}

/// Boundary and derived segmentation-unit exact matching.
public struct GlifiBoundaryEvaluation: Codable, Equatable, Sendable {
    /// Versioned boundary and unit contract.
    public static let identifier = "LinguisticBoundaries-exact-UTF8-v1"
    /// Recorded handling of zero denominators.
    public let zeroPolicy: GlifiEvaluationZeroPolicy
    /// Exact position matching, separately within each document.
    public let boundaries: GlifiEvaluationScore
    /// Exact adjacent intervals derived by adding document endpoints to both partitions.
    public let units: GlifiEvaluationScore
    /// Documents whose declared boundary sets match exactly.
    public let documents: GlifiEvaluationAccuracy
}

/// One named entity; offsets are half-open UTF-8 byte positions in its enclosing document.
public struct GlifiEvaluationEntity: Codable, Equatable, Hashable, Sendable {
    /// Inclusive start byte.
    public let lowerBound: Int
    /// Exclusive end byte; must be greater than `lowerBound`.
    public let upperBound: Int
    /// Declared entity type, compared exactly without case folding.
    public let type: String

    /// Creates an annotation; evaluation validates its range, type and uniqueness.
    public init(lowerBound: Int, upperBound: Int, type: String) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.type = type
    }
}

/// Separate untyped and typed exact-span named entity evaluation.
public struct GlifiNamedEntityEvaluation: Codable, Equatable, Sendable {
    /// Versioned span-matching contract; no partial overlap credit.
    public static let identifier = "LinguisticNER-exact-UTF8-v1"
    /// Recorded handling of zero denominators.
    public let zeroPolicy: GlifiEvaluationZeroPolicy
    /// Matches both endpoints and ignores entity type.
    public let spans: GlifiEvaluationScore
    /// Matches both endpoints and the exact entity type.
    public let typedSpans: GlifiEvaluationScore
}

/// Morphology exact-set accuracy and separate exact attribute-value scores.
public struct GlifiMorphologyEvaluation: Codable, Equatable, Sendable {
    /// Versioned feature-matching contract.
    public static let identifier = "LinguisticMorphology-exact-set-v1"
    /// Recorded handling of zero denominators.
    public let zeroPolicy: GlifiEvaluationZeroPolicy
    /// A token is correct only when its entire feature dictionary equals gold.
    public let exactSets: GlifiEvaluationAccuracy
    /// Attribute union in canonical order; a wrong value contributes both FP and FN.
    public let perAttribute: [GlifiEvaluationClassScore]
}

/// Bounded, deterministic metrics for GS-MET-001-18; no linguistic backend or gold corpus is inferred.
public enum GlifiLinguisticEvaluation {
    /// Maximum aligned observations or annotations per side; checked before result allocations.
    public static let maximumObservationCount = 1_000_000
    /// Maximum distinct class labels or feature attributes; bounds the dense confusion matrix.
    public static let maximumLabelCount = 256
    /// Maximum bytes in one label, lemma or attribute value.
    public static let maximumLabelByteCount = 1_024
    /// Maximum aggregate bytes across label, lemma, form, POS and feature strings in one request.
    public static let maximumTextByteCount = 64 * 1_024 * 1_024

    /// Evaluates single-label predictions in gold token order; lengths must match exactly.
    public static func classification(
        gold: [String], predicted: [String], zeroPolicy: GlifiEvaluationZeroPolicy = .undefined
    ) throws -> GlifiLinguisticClassificationEvaluation {
        try validateAlignment(gold.count, predicted.count)
        try validateTextBudget([gold, predicted])
        var labelSet = Set<String>()
        for index in gold.indices {
            try checkpoint(index)
            try validateLabel(gold[index])
            try validateLabel(predicted[index])
            labelSet.insert(gold[index])
            labelSet.insert(predicted[index])
            guard labelSet.count <= maximumLabelCount else {
                throw evaluationFailure("evaluation.limit-exceeded")
            }
        }
        let labels = labelSet.sorted()
        let positions = Dictionary(
            uniqueKeysWithValues: labels.enumerated().map { ($0.element, $0.offset) })
        var matrix = Array(repeating: Array(repeating: 0, count: labels.count), count: labels.count)
        var correct = 0
        for index in gold.indices {
            try checkpoint(index)
            guard let row = positions[gold[index]], let column = positions[predicted[index]] else {
                throw evaluationFailure("evaluation.invalid-label")
            }
            matrix[row][column] += 1
            if row == column { correct += 1 }
        }
        let classes = labels.indices.map { index in
            let support = matrix[index].reduce(0, +)
            let predictedCount = matrix.reduce(0) { $0 + $1[index] }
            return GlifiEvaluationClassScore(
                label: labels[index], support: support,
                score: score(
                    matrix[index][index], predictedCount - matrix[index][index],
                    support - matrix[index][index], zeroPolicy)
            )
        }
        return GlifiLinguisticClassificationEvaluation(
            zeroPolicy: zeroPolicy, labels: labels, confusionMatrix: matrix,
            accuracy: accuracy(correct, gold.count, zeroPolicy), perClass: classes,
            micro: score(correct, gold.count - correct, gold.count - correct, zeroPolicy),
            macro: average(classes, weighted: false, zeroPolicy: zeroPolicy),
            weighted: average(classes, weighted: true, zeroPolicy: zeroPolicy)
        )
    }

    /// Exact lemma accuracy on aligned gold tokens; no token alignment or normalization is inferred.
    public static func lemmas(
        gold: [String], predicted: [String], zeroPolicy: GlifiEvaluationZeroPolicy = .undefined
    ) throws -> GlifiEvaluationAccuracy {
        try validateAlignment(gold.count, predicted.count)
        try validateTextBudget([gold, predicted])
        var correct = 0
        for index in gold.indices {
            try checkpoint(index)
            if gold[index] == predicted[index] { correct += 1 }
        }
        return accuracy(correct, gold.count, zeroPolicy)
    }

    /// Evaluates exact lemmas and error counts stratified by optional aligned gold forms/POS.
    ///
    /// Each supplied stratum array must match the gold-token length. No predicted POS,
    /// unknown grouping label or guessed token alignment substitutes for gold annotations.
    public static func lemmaAnalysis(
        gold: [String], predicted: [String], forms: [String]? = nil, partsOfSpeech: [String]? = nil,
        zeroPolicy: GlifiEvaluationZeroPolicy = .undefined
    ) throws -> GlifiLemmaEvaluation {
        var textCollections = [gold, predicted]
        if let forms { textCollections.append(forms) }
        if let partsOfSpeech { textCollections.append(partsOfSpeech) }
        try validateTextBudget(textCollections)
        try validateAlignment(gold.count, predicted.count)
        if let forms { try validateAlignment(gold.count, forms.count) }
        if let partsOfSpeech { try validateAlignment(gold.count, partsOfSpeech.count) }
        var correct = 0
        var formCounts: [String: (Int, Int)] = [:]
        var partOfSpeechCounts: [String: (Int, Int)] = [:]
        for index in gold.indices {
            try checkpoint(index)
            let matches = gold[index] == predicted[index]
            if matches { correct += 1 }
            if let forms {
                var value = formCounts[forms[index]] ?? (0, 0)
                value.0 += 1
                if !matches { value.1 += 1 }
                formCounts[forms[index]] = value
            }
            if let partsOfSpeech {
                var value = partOfSpeechCounts[partsOfSpeech[index]] ?? (0, 0)
                value.0 += 1
                if !matches { value.1 += 1 }
                partOfSpeechCounts[partsOfSpeech[index]] = value
            }
        }
        func groups(_ counts: [String: (Int, Int)]) -> [GlifiEvaluationErrorGroup] {
            return counts.keys.sorted().map { label in
                let value = counts[label] ?? (0, 0)
                return GlifiEvaluationErrorGroup(
                    label: label, observationCount: value.0, errorCount: value.1)
            }
        }
        return GlifiLemmaEvaluation(
            zeroPolicy: zeroPolicy, accuracy: accuracy(correct, gold.count, zeroPolicy),
            errorsByForm: groups(formCounts), errorsByPartOfSpeech: groups(partOfSpeechCounts))
    }

    /// Matches boundary byte offsets within aligned documents, then exact derived intervals.
    ///
    /// Offsets must be unique and within `0...utf8Length`. Endpoints, when explicitly
    /// supplied, participate in boundary scoring; derived units always add both endpoints.
    /// Document lengths alone do not verify Unicode scalar boundaries: callers supply
    /// offsets already validated against the same immutable source text.
    public static func boundaries(
        gold: [[Int]], predicted: [[Int]], utf8Lengths: [Int],
        zeroPolicy: GlifiEvaluationZeroPolicy = .undefined
    ) throws -> GlifiBoundaryEvaluation {
        try validateDocuments(gold.count, predicted.count, utf8Lengths)
        try validateAnnotationCounts(gold.map(\.count), predicted.map(\.count))
        var boundaryCounts = (0, 0, 0)
        var unitCounts = (0, 0, 0)
        var correctDocuments = 0
        for index in gold.indices {
            try checkpoint(index)
            let expected = try boundarySet(gold[index], length: utf8Lengths[index])
            let actual = try boundarySet(predicted[index], length: utf8Lengths[index])
            addMatches(expected, actual, to: &boundaryCounts)
            addMatches(
                intervals(expected, length: utf8Lengths[index]),
                intervals(actual, length: utf8Lengths[index]), to: &unitCounts)
            if expected == actual { correctDocuments += 1 }
        }
        return GlifiBoundaryEvaluation(
            zeroPolicy: zeroPolicy,
            boundaries: score(boundaryCounts.0, boundaryCounts.1, boundaryCounts.2, zeroPolicy),
            units: score(unitCounts.0, unitCounts.1, unitCounts.2, zeroPolicy),
            documents: accuracy(correctDocuments, gold.count, zeroPolicy)
        )
    }

    /// Evaluates exact named-entity spans with and without the type, separately by document.
    ///
    /// Nonempty half-open ranges must fit the document's declared UTF-8 length. Duplicate
    /// endpoint pairs within one annotation set fail, including conflicting types.
    /// Nested spans are allowed; partial overlap receives no match credit.
    public static func namedEntities(
        gold: [[GlifiEvaluationEntity]], predicted: [[GlifiEvaluationEntity]], utf8Lengths: [Int],
        zeroPolicy: GlifiEvaluationZeroPolicy = .undefined
    ) throws -> GlifiNamedEntityEvaluation {
        try validateDocuments(gold.count, predicted.count, utf8Lengths)
        try validateAnnotationCounts(gold.map(\.count), predicted.map(\.count))
        var remainingBytes = maximumTextByteCount
        for documents in [gold, predicted] {
            for (documentIndex, entities) in documents.enumerated() {
                try checkpoint(documentIndex)
                for (entityIndex, entity) in entities.enumerated() {
                    try checkpoint(entityIndex)
                    try consumeLabel(entity.type, remainingBytes: &remainingBytes)
                }
            }
        }
        var spanCounts = (0, 0, 0)
        var typedCounts = (0, 0, 0)
        for index in gold.indices {
            try checkpoint(index)
            let expected = try entitySet(gold[index], length: utf8Lengths[index])
            let actual = try entitySet(predicted[index], length: utf8Lengths[index])
            addMatches(
                Set(expected.map { $0.lowerBound..<$0.upperBound }),
                Set(actual.map { $0.lowerBound..<$0.upperBound }), to: &spanCounts)
            addMatches(expected, actual, to: &typedCounts)
        }
        return GlifiNamedEntityEvaluation(
            zeroPolicy: zeroPolicy,
            spans: score(spanCounts.0, spanCounts.1, spanCounts.2, zeroPolicy),
            typedSpans: score(typedCounts.0, typedCounts.1, typedCounts.2, zeroPolicy)
        )
    }

    /// Evaluates exact morphology dictionaries on aligned gold tokens.
    ///
    /// Missing attributes remain absent. A wrong value is both a false positive and a
    /// false negative for its attribute. No linguistic schema or normalization is inferred.
    public static func morphology(
        gold: [[String: String]], predicted: [[String: String]],
        zeroPolicy: GlifiEvaluationZeroPolicy = .undefined
    ) throws -> GlifiMorphologyEvaluation {
        try validateAlignment(gold.count, predicted.count)
        try validateAnnotationCounts(gold.map(\.count), predicted.map(\.count))
        var remainingBytes = maximumTextByteCount
        for documents in [gold, predicted] {
            for (index, attributes) in documents.enumerated() {
                try checkpoint(index)
                guard attributes.count <= maximumLabelCount else {
                    throw evaluationFailure("evaluation.limit-exceeded")
                }
                for (attribute, value) in attributes {
                    try consumeLabel(attribute, remainingBytes: &remainingBytes)
                    try consumeLabel(value, remainingBytes: &remainingBytes)
                }
            }
        }
        var counts: [String: (Int, Int, Int)] = [:]
        var correct = 0
        for index in gold.indices {
            try checkpoint(index)
            var exactSet = gold[index].count == predicted[index].count
            // Visit gold attributes and then prediction-only attributes. The final
            // output is sorted once; no temporary Set or per-token sort is necessary.
            for (attribute, expected) in gold[index] {
                let actual = predicted[index][attribute]
                var value = counts[attribute] ?? (0, 0, 0)
                if expected == actual {
                    value.0 += 1
                } else {
                    exactSet = false
                    if actual != nil { value.1 += 1 }
                    value.2 += 1
                }
                counts[attribute] = value
                guard counts.count <= maximumLabelCount else {
                    throw evaluationFailure("evaluation.limit-exceeded")
                }
            }
            for attribute in predicted[index].keys where gold[index][attribute] == nil {
                exactSet = false
                var value = counts[attribute] ?? (0, 0, 0)
                value.1 += 1
                counts[attribute] = value
                guard counts.count <= maximumLabelCount else {
                    throw evaluationFailure("evaluation.limit-exceeded")
                }
            }
            if exactSet { correct += 1 }
        }
        return GlifiMorphologyEvaluation(
            zeroPolicy: zeroPolicy, exactSets: accuracy(correct, gold.count, zeroPolicy),
            perAttribute: counts.keys.sorted().map { attribute in
                let value = counts[attribute] ?? (0, 0, 0)
                return GlifiEvaluationClassScore(
                    label: attribute, support: value.0 + value.2,
                    score: score(value.0, value.1, value.2, zeroPolicy))
            }
        )
    }

    private static func quotient(
        _ numerator: Int, _ denominator: Int, _ policy: GlifiEvaluationZeroPolicy
    ) -> Double? {
        denominator > 0 ? Double(numerator) / Double(denominator) : (policy == .zero ? 0 : nil)
    }

    private static func score(_ tp: Int, _ fp: Int, _ fn: Int, _ policy: GlifiEvaluationZeroPolicy)
        -> GlifiEvaluationScore
    {
        GlifiEvaluationScore(
            truePositiveCount: tp, falsePositiveCount: fp, falseNegativeCount: fn,
            precision: quotient(tp, tp + fp, policy), recall: quotient(tp, tp + fn, policy),
            f1: quotient(2 * tp, 2 * tp + fp + fn, policy))
    }

    private static func accuracy(_ correct: Int, _ total: Int, _ policy: GlifiEvaluationZeroPolicy)
        -> GlifiEvaluationAccuracy
    {
        GlifiEvaluationAccuracy(
            observationCount: total, correctCount: correct,
            accuracy: quotient(correct, total, policy))
    }

    private static func average(
        _ classes: [GlifiEvaluationClassScore], weighted: Bool,
        zeroPolicy: GlifiEvaluationZeroPolicy
    ) -> GlifiEvaluationAverage {
        func mean(_ keyPath: KeyPath<GlifiEvaluationScore, Double?>) -> Double? {
            var sum = 0.0
            var total = 0
            for value in classes {
                let weight = weighted ? value.support : 1
                guard weight > 0 else { continue }
                guard let metric = value.score[keyPath: keyPath] else { return nil }
                sum += Double(weight) * metric
                total += weight
            }
            return total > 0 ? sum / Double(total) : (zeroPolicy == .zero ? 0 : nil)
        }
        return GlifiEvaluationAverage(
            precision: mean(\.precision), recall: mean(\.recall), f1: mean(\.f1))
    }

    private static func validateAlignment(_ goldCount: Int, _ predictionCount: Int) throws {
        try Task.checkCancellation()
        guard goldCount == predictionCount else {
            throw evaluationFailure("evaluation.alignment-mismatch")
        }
        guard goldCount <= maximumObservationCount else {
            throw evaluationFailure("evaluation.limit-exceeded")
        }
    }

    private static func validateDocuments(_ goldCount: Int, _ predictedCount: Int, _ lengths: [Int])
        throws
    {
        try validateAlignment(goldCount, predictedCount)
        guard lengths.count == goldCount, lengths.allSatisfy({ $0 >= 0 }) else {
            throw evaluationFailure("evaluation.invalid-document-length")
        }
    }

    private static func validateAnnotationCounts(_ goldCounts: [Int], _ predictedCounts: [Int])
        throws
    {
        for counts in [goldCounts, predictedCounts] {
            var total = 0
            for (index, count) in counts.enumerated() {
                try checkpoint(index)
                guard count <= maximumObservationCount - total else {
                    throw evaluationFailure("evaluation.limit-exceeded")
                }
                total += count
            }
        }
    }

    private static func validateLabel(_ label: String) throws {
        guard !label.isEmpty, label.utf8.count <= maximumLabelByteCount else {
            throw evaluationFailure("evaluation.invalid-label")
        }
    }

    private static func consumeLabel(_ label: String, remainingBytes: inout Int) throws {
        let byteCount = label.utf8.count
        guard byteCount > 0, byteCount <= maximumLabelByteCount else {
            throw evaluationFailure("evaluation.invalid-label")
        }
        guard byteCount <= remainingBytes else {
            throw evaluationFailure("evaluation.limit-exceeded")
        }
        remainingBytes -= byteCount
    }

    private static func validateTextBudget(_ collections: [[String]]) throws {
        var remainingBytes = maximumTextByteCount
        for values in collections {
            guard values.count <= maximumObservationCount else {
                throw evaluationFailure("evaluation.limit-exceeded")
            }
            for (index, value) in values.enumerated() {
                try checkpoint(index)
                try consumeLabel(value, remainingBytes: &remainingBytes)
            }
        }
    }

    private static func boundarySet(_ values: [Int], length: Int) throws -> Set<Int> {
        var result = Set<Int>()
        for (index, value) in values.enumerated() {
            try checkpoint(index)
            guard value >= 0, value <= length, result.insert(value).inserted else {
                throw evaluationFailure("evaluation.invalid-boundary")
            }
        }
        return result
    }

    private static func intervals(_ boundaries: Set<Int>, length: Int) -> Set<Range<Int>> {
        let values = boundaries.union([0, length]).sorted()
        return Set(zip(values, values.dropFirst()).map { $0..<$1 })
    }

    private static func entitySet(_ values: [GlifiEvaluationEntity], length: Int) throws -> Set<
        GlifiEvaluationEntity
    > {
        var spans = Set<Range<Int>>()
        for (index, value) in values.enumerated() {
            try checkpoint(index)
            try validateLabel(value.type)
            guard value.lowerBound >= 0, value.upperBound > value.lowerBound,
                value.upperBound <= length,
                spans.insert(value.lowerBound..<value.upperBound).inserted
            else { throw evaluationFailure("evaluation.invalid-entity") }
        }
        return Set(values)
    }

    private static func addMatches<Value: Hashable>(
        _ gold: Set<Value>, _ predicted: Set<Value>, to counts: inout (Int, Int, Int)
    ) {
        let correct = gold.intersection(predicted).count
        counts.0 += correct
        counts.1 += predicted.count - correct
        counts.2 += gold.count - correct
    }

    private static func checkpoint(_ index: Int) throws {
        if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
    }
}

private func evaluationFailure(_ code: String) -> GlifiFailure {
    GlifiFailure(
        code: code, category: .invalidInput, operation: .analyze,
        retryDisposition: .afterCorrection, retainedState: .lastCommittedGeneration,
        messageKey: "failure.\(code)")
}
