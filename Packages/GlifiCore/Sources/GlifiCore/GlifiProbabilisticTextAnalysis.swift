// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A validated sparse bag-of-words table; zero counts never occupy storage.
public struct GlifiDocumentTermTable: Equatable, Sendable {
    /// Canonical vocabulary shared by the rows.
    public let terms: [String]
    /// Sparse count rows, keyed by vocabulary position.
    public let rows: [[Int: Int]]
    /// Exact row totals.
    public let totals: [Int]

    /// Creates a table from documents, retaining an explicit training vocabulary when supplied.
    public init(
        documents: [[String]], vocabulary: [String]? = nil,
        maximumTokens: Int = 2_000_000, maximumVocabulary: Int = 100_000
    ) throws {
        guard maximumTokens >= 0, maximumVocabulary > 0, !documents.isEmpty else {
            throw exploratoryFailure("text-table.invalid-input")
        }
        var total = 0
        for document in documents {
            guard document.count <= maximumTokens - total else {
                throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
            }
            total += document.count
        }
        let terms = vocabulary ?? Array(Set(documents.flatMap { $0 })).sorted()
        guard !terms.isEmpty, !terms.contains(where: \.isEmpty), Set(terms).count == terms.count,
            terms.count <= maximumVocabulary
        else { throw exploratoryFailure("text-table.invalid-vocabulary") }
        let positions = Dictionary(
            uniqueKeysWithValues: terms.enumerated().map { ($0.element, $0.offset) })
        var rows: [[Int: Int]] = []
        for (index, document) in documents.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            var counts: [Int: Int] = [:]
            for (tokenIndex, term) in document.enumerated() {
                if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
                if let position = positions[term] { counts[position, default: 0] += 1 }
            }
            rows.append(counts)
        }
        self.terms = terms
        self.rows = rows
        totals = rows.map { $0.values.reduce(0, +) }
    }

    /// Materializes a bounded dense matrix only for a method that actually requires one.
    public func dense(limits: GlifiExploratoryLimits = .standard) throws -> [[Double]] {
        guard rows.count <= limits.maximumCells / terms.count else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        try Task.checkCancellation()
        return rows.map { row in
            var result = [Double](repeating: 0, count: terms.count)
            for (column, count) in row { result[column] = Double(count) }
            return result
        }
    }
}

/// A fitted multinomial model with immutable training vocabulary and Laplace smoothing.
public struct GlifiNaiveBayesModel: Equatable, Sendable {
    /// Versioned statistical contract.
    public static let identifier = "MultinomialNaiveBayes-Laplace-v1"
    /// Class labels in canonical order.
    public let classes: [String]
    /// Training-only vocabulary.
    public let vocabulary: [String]
    /// Log prior per class.
    public let logPriors: [Double]
    /// Log conditional probabilities, class by term.
    public let logLikelihoods: [[Double]]
    /// Positive symmetric Dirichlet pseudocount.
    public let smoothing: Double
}

/// One prediction; posteriors are model scores, not calibrated confidence.
public struct GlifiNaiveBayesPrediction: Equatable, Sendable {
    /// Winning class, with canonical class-order tie-breaking.
    public let label: String
    /// Class order of every probability.
    public let classes: [String]
    /// Normalized class posteriors.
    public let probabilities: [Double]
    /// Input tokens outside the frozen vocabulary, explicitly ignored.
    public let ignoredTokenCount: Int
}

/// Held-out evaluation; a distinct model and vocabulary are fitted in every fold.
public struct GlifiClassificationEvaluation: Equatable, Sendable {
    /// Labels indexing the confusion matrix.
    public let classes: [String]
    /// Actual class by predicted class.
    public let confusion: [[Int]]
    /// Held-out prediction for each input document.
    public let predictions: [String]
    /// Fraction correctly classified.
    public let accuracy: Double
    /// Fold assigned to each document.
    public let foldAssignments: [Int]
    /// Seed of the stratified shuffle.
    public let seed: UInt64
}

/// Sparse multinomial training, prediction and leakage-free cross-validation.
public enum GlifiNaiveBayes {
    /// Fits empirical class priors and smoothed term likelihoods from training data only.
    public static func train(
        documents: [[String]], labels: [String], smoothing: Double = 1,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiNaiveBayesModel {
        guard documents.count == labels.count, !labels.isEmpty, !labels.contains(where: \.isEmpty),
            smoothing.isFinite, smoothing > 0
        else { throw exploratoryFailure("naive-bayes.invalid-training") }
        try Task.checkCancellation()
        guard documents.count <= limits.maximumCells else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        var remainingWork = limits.maximumWork
        try admitClassifierWork([documents.count], remaining: &remainingWork)
        let tokenCount = try classifierTokenCount(documents)
        try admitClassifierWork([tokenCount], remaining: &remainingWork)
        let identities = try classifierTrainingIdentities(
            documents: documents, labels: labels, remaining: &remainingWork, limits: limits)
        let classes = identities.classes
        guard classes.count >= 2 else {
            throw exploratoryFailure("naive-bayes.insufficient-classes", .insufficientData)
        }
        guard classes.count <= limits.maximumCells / identities.terms.count else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        try admitClassifierWork(
            [classes.count, identities.terms.count, 2], remaining: &remainingWork)
        let table = try GlifiDocumentTermTable(documents: documents, vocabulary: identities.terms)
        let positions = Dictionary(
            uniqueKeysWithValues: classes.enumerated().map { ($0.element, $0.offset) })
        var counts = Array(
            repeating: Array(repeating: 0, count: table.terms.count), count: classes.count)
        var classTotals = [Int](repeating: 0, count: classes.count)
        var classDocuments = [Int](repeating: 0, count: classes.count)
        for index in documents.indices {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            guard let category = positions[labels[index]] else { continue }
            classDocuments[category] += 1
            classTotals[category] += table.totals[index]
            for (term, count) in table.rows[index] { counts[category][term] += count }
        }
        let priorMass = Double(table.terms.count) * smoothing
        guard priorMass.isFinite else { throw exploratoryFailure("naive-bayes.invalid-smoothing") }
        let complementaryMass = Double(table.terms.count - 1) * smoothing
        let likelihoods = try classes.indices.map { category in
            try Task.checkCancellation()
            let total = classTotals[category]
            let denominator = Double(total) + priorMass
            let logDenominator = log(denominator)
            return counts[category].map {
                naiveBayesLogLikelihood(
                    $0, total: total, smoothing: smoothing,
                    complementaryMass: complementaryMass,
                    denominator: denominator, logDenominator: logDenominator)
            }
        }
        guard likelihoods.allSatisfy({ $0.allSatisfy(\.isFinite) }) else {
            throw exploratoryFailure("exploratory.numeric-overflow")
        }
        return GlifiNaiveBayesModel(
            classes: classes, vocabulary: table.terms,
            logPriors: classDocuments.map { naiveBayesLogPrior($0, total: documents.count) },
            logLikelihoods: likelihoods, smoothing: smoothing
        )
    }

    /// Scores a batch using one vocabulary lookup, sparse counts and log-sum-exp normalization.
    public static func predict(
        _ documents: [[String]], using model: GlifiNaiveBayesModel,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> [GlifiNaiveBayesPrediction] {
        guard !documents.isEmpty else { return [] }
        try Task.checkCancellation()
        guard !model.classes.isEmpty,
            documents.count <= limits.maximumCells / model.classes.count
        else { throw exploratoryFailure("exploratory.resource-limit", .insufficientResources) }
        let tokenCount = try classifierTokenCount(documents)
        var remainingWork = limits.maximumWork
        try admitClassifierWork([documents.count], remaining: &remainingWork)
        try admitClassifierWork([tokenCount, model.classes.count], remaining: &remainingWork)
        try admitClassifierWork([documents.count, model.classes.count], remaining: &remainingWork)
        try admitClassifierPredictionPreparation(
            documents, vocabulary: model.vocabulary, remaining: &remainingWork, limits: limits)
        let table = try GlifiDocumentTermTable(documents: documents, vocabulary: model.vocabulary)
        return try documents.indices.map { index in
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let ordered = table.rows[index].sorted { $0.key < $1.key }
            let scores = model.classes.indices.map { category in
                ordered.reduce(model.logPriors[category]) {
                    $0 + Double($1.value) * model.logLikelihoods[category][$1.key]
                }
            }
            guard let maximum = scores.max(), maximum.isFinite else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            let weights = scores.map { exp($0 - maximum) }
            let total = weights.reduce(0, +)
            let winner = scores.firstIndex(of: maximum) ?? 0
            return GlifiNaiveBayesPrediction(
                label: model.classes[winner], classes: model.classes,
                probabilities: weights.map { $0 / total },
                ignoredTokenCount: documents[index].count - table.totals[index]
            )
        }
    }

    /// Runs deterministic stratified k-fold validation, without vocabulary leakage.
    public static func crossValidate(
        documents: [[String]], labels: [String], folds: Int, seed: UInt64,
        smoothing: Double = 1, limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiClassificationEvaluation {
        guard labels.count == documents.count, folds >= 2, folds <= documents.count else {
            throw exploratoryFailure("naive-bayes.invalid-folds")
        }
        try Task.checkCancellation()
        guard documents.count <= limits.maximumCells else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        var remainingWork = limits.maximumWork
        // Admit raw string scans and hashing before building either identity set.
        let labelBytes = try admitClassifierStringBytes(
            labels, passes: 2, remaining: &remainingWork)
        let tokenCount = try classifierTokenCount(documents)
        let tokenBytes = try admitClassifierStringBytes(
            documents.joined(), passes: 2, remaining: &remainingWork)
        let categorySet = Set(labels)
        let categoryBytes = try admitClassifierStringBytes(
            categorySet, passes: 1, remaining: &remainingWork)
        let categorySortLevels =
            categorySet.count < 2
            ? 0 : Int.bitWidth - (categorySet.count - 1).leadingZeroBitCount
        try admitClassifierWork(
            [categorySet.count, categorySortLevels], remaining: &remainingWork)
        try admitClassifierWork(
            [categoryBytes, categorySortLevels], remaining: &remainingWork)
        let classes = categorySet.sorted()
        guard classes.count >= 2 else {
            throw exploratoryFailure("naive-bayes.insufficient-classes", .insufficientData)
        }
        guard !labels.contains(where: \.isEmpty), smoothing.isFinite, smoothing > 0 else {
            throw exploratoryFailure("naive-bayes.invalid-training")
        }
        guard classes.count <= limits.maximumCells / classes.count,
            documents.count <= limits.maximumCells
        else { throw exploratoryFailure("exploratory.resource-limit", .insufficientResources) }
        try requireWork([tokenCount], limits)
        try requireWork([documents.count, classes.count], limits)
        // This vocabulary is used only for conservative resource admission. Every fold
        // still learns its own vocabulary exclusively from its training documents.
        let globalVocabulary = Set(documents.joined())
        let vocabularyCount = globalVocabulary.count
        guard vocabularyCount <= 100_000 else {
            throw exploratoryFailure("text-table.invalid-vocabulary")
        }
        let vocabularyBytes = try admitClassifierStringBytes(
            globalVocabulary, passes: 1, remaining: &remainingWork)
        try admitClassifierWork([documents.count, classes.count], remaining: &remainingWork)
        try admitClassifierWork([documents.count, folds, 2], remaining: &remainingWork)
        try admitClassifierWork([tokenCount, folds], remaining: &remainingWork)
        try admitClassifierWork(
            [classes.count, vocabularyCount, folds, 2], remaining: &remainingWork)
        try admitClassifierWork([tokenCount, classes.count], remaining: &remainingWork)
        try admitClassifierWork([documents.count, classes.count], remaining: &remainingWork)
        try admitClassifierWork([classes.count, classes.count], remaining: &remainingWork)
        // Every training vocabulary is a subset of this admission-only upper bound.
        // Reserve table validation/lookups in both phases, repeated training-token hashing,
        // canonical training-vocabulary sorting, and each held-out document's sparse sorting.
        let vocabularySortLevels =
            vocabularyCount < 2
            ? 0 : Int.bitWidth - (vocabularyCount - 1).leadingZeroBitCount
        try admitClassifierWork([folds, 6, vocabularyCount], remaining: &remainingWork)
        try admitClassifierWork([folds, 4, vocabularyBytes], remaining: &remainingWork)
        try admitClassifierWork([folds, 2, tokenBytes], remaining: &remainingWork)
        try admitClassifierWork([folds, 2, labelBytes], remaining: &remainingWork)
        try admitClassifierWork([folds, classes.count], remaining: &remainingWork)
        try admitClassifierWork([folds, categoryBytes], remaining: &remainingWork)
        try admitClassifierWork(
            [folds, classes.count, categorySortLevels], remaining: &remainingWork)
        try admitClassifierWork(
            [folds, categoryBytes, categorySortLevels], remaining: &remainingWork)
        try admitClassifierWork(
            [folds, vocabularyCount, vocabularySortLevels], remaining: &remainingWork)
        try admitClassifierWork(
            [folds, vocabularyBytes, vocabularySortLevels], remaining: &remainingWork)
        try admitClassifierWork([tokenBytes], remaining: &remainingWork)
        for (index, document) in documents.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            let nonzeroUpperBound = min(document.count, vocabularyCount)
            let levels =
                nonzeroUpperBound < 2
                ? 0 : Int.bitWidth - (nonzeroUpperBound - 1).leadingZeroBitCount
            try admitClassifierWork([nonzeroUpperBound, levels], remaining: &remainingWork)
        }
        var generator = GlifiSplitMix64(seed: seed)
        var assignments = [Int](repeating: 0, count: documents.count)
        for label in classes {
            try Task.checkCancellation()
            var indices = labels.indices.filter { labels[$0] == label }
            guard indices.count >= folds else {
                throw exploratoryFailure("naive-bayes.insufficient-fold-support", .insufficientData)
            }
            for i in indices.indices {
                indices.swapAt(i, i + generator.index(below: indices.count - i))
            }
            for (position, index) in indices.enumerated() { assignments[index] = position % folds }
        }
        var predictions = [String](repeating: "", count: documents.count)
        for fold in 0..<folds {
            try Task.checkCancellation()
            let training = documents.indices.filter { assignments[$0] != fold }
            let heldOut = documents.indices.filter { assignments[$0] == fold }
            let model = try train(
                documents: training.map { documents[$0] }, labels: training.map { labels[$0] },
                smoothing: smoothing, limits: limits
            )
            let scored = try predict(heldOut.map { documents[$0] }, using: model, limits: limits)
            for (index, prediction) in zip(heldOut, scored) {
                predictions[index] = prediction.label
            }
        }
        let positions = Dictionary(
            uniqueKeysWithValues: classes.enumerated().map { ($0.element, $0.offset) })
        var confusion = Array(
            repeating: Array(repeating: 0, count: classes.count), count: classes.count)
        var correct = 0
        for index in documents.indices {
            if let actual = positions[labels[index]], let predicted = positions[predictions[index]]
            {
                confusion[actual][predicted] += 1
                if actual == predicted { correct += 1 }
            }
        }
        return GlifiClassificationEvaluation(
            classes: classes, confusion: confusion, predictions: predictions,
            accuracy: Double(correct) / Double(documents.count), foldAssignments: assignments,
            seed: seed
        )
    }
}

/// Computes a class prior without rounding a dominant exact-count proportion to one.
func naiveBayesLogPrior(_ count: Int, total: Int) -> Double {
    if count > total / 2 {
        let complement = total - count
        return complement == 0 ? 0 : log1p(-Double(complement) / Double(total))
    }
    return log(Double(count) / Double(total))
}

/// Preserves small exact-count complements when the smoothed probability exceeds one half.
///
/// The ordinary path retains the original difference-of-logs evaluation.
func naiveBayesLogLikelihood(
    _ count: Int, total: Int, smoothing: Double, complementaryMass: Double,
    denominator: Double, logDenominator: Double
) -> Double {
    let complement = Double(total - count) + complementaryMass
    if complement == 0 { return 0 }
    if complement < denominator / 2 {
        let fraction = complement / denominator
        return fraction == 0 ? 0 : log1p(-fraction)
    }
    return log(Double(count) + smoothing) - logDenominator
}

private func classifierTrainingIdentities(
    documents: [[String]], labels: [String], remaining: inout Int,
    limits: GlifiExploratoryLimits
) throws -> (terms: [String], classes: [String]) {
    // Reserve raw hashing and lookups before either identity set or the sparse table.
    let labelBytes = try admitClassifierStringBytes(labels, passes: 2, remaining: &remaining)
    let tokenBytes = try admitClassifierStringBytes(
        documents.joined(), passes: 2, remaining: &remaining)
    guard labelBytes <= 67_108_864, tokenBytes <= 67_108_864 - labelBytes else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    var vocabulary = Set<String>()
    for (index, token) in documents.joined().enumerated() {
        if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
        guard !token.isEmpty else { throw exploratoryFailure("text-table.invalid-vocabulary") }
        vocabulary.insert(token)
        guard vocabulary.count <= 100_000 else {
            throw exploratoryFailure("text-table.invalid-vocabulary")
        }
    }
    guard !vocabulary.isEmpty else { throw exploratoryFailure("text-table.invalid-vocabulary") }
    let categories = Set(labels)
    guard categories.count <= limits.maximumCells / vocabulary.count else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    let vocabularyBytes = try admitClassifierStringBytes(
        vocabulary, passes: 2, remaining: &remaining)
    let categoryBytes = try admitClassifierStringBytes(
        categories, passes: 1, remaining: &remaining)
    try admitClassifierWork([vocabulary.count, 3], remaining: &remaining)
    try admitClassifierWork([categories.count], remaining: &remaining)
    for (count, bytes) in [(vocabulary.count, vocabularyBytes), (categories.count, categoryBytes)] {
        let levels = count < 2 ? 0 : Int.bitWidth - (count - 1).leadingZeroBitCount
        try admitClassifierWork([count, levels], remaining: &remaining)
        try admitClassifierWork([bytes, levels], remaining: &remaining)
    }
    try Task.checkCancellation()
    return (vocabulary.sorted(), categories.sorted())
}

private func classifierTokenCount(_ documents: [[String]]) throws -> Int {
    var count = 0
    for (index, document) in documents.enumerated() {
        if index.isMultiple(of: 256) { try Task.checkCancellation() }
        guard document.count <= 2_000_000 - count else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        count += document.count
    }
    return count
}

private func admitClassifierStringBytes<S: Sequence>(
    _ strings: S, passes: Int, remaining: inout Int
) throws -> Int where S.Element == String {
    var total = 0
    for (index, value) in strings.enumerated() {
        if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
        let count = value.utf8.count
        try admitClassifierWork([count, passes], remaining: &remaining)
        let (updated, overflow) = total.addingReportingOverflow(count)
        guard !overflow else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        total = updated
    }
    return total
}

private func admitClassifierPredictionPreparation(
    _ documents: [[String]], vocabulary: [String], remaining: inout Int,
    limits: GlifiExploratoryLimits
) throws {
    guard !vocabulary.isEmpty, vocabulary.count <= 100_000 else {
        throw exploratoryFailure("text-table.invalid-vocabulary")
    }
    guard vocabulary.count <= limits.maximumCells else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    // The table validates every vocabulary entry, checks uniqueness and builds its lookup.
    try admitClassifierWork([vocabulary.count, 3], remaining: &remaining)
    for (index, term) in vocabulary.enumerated() {
        if index.isMultiple(of: 1_024) { try Task.checkCancellation() }
        try admitClassifierWork([term.utf8.count, 2], remaining: &remaining)
    }
    for (index, document) in documents.enumerated() {
        if index.isMultiple(of: 256) { try Task.checkCancellation() }
        let nonzeroUpperBound = min(document.count, vocabulary.count)
        let sortLevels =
            nonzeroUpperBound < 2
            ? 0 : Int.bitWidth - (nonzeroUpperBound - 1).leadingZeroBitCount
        try admitClassifierWork([nonzeroUpperBound, sortLevels], remaining: &remaining)
        for (tokenIndex, token) in document.enumerated() {
            if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
            try admitClassifierWork([token.utf8.count], remaining: &remaining)
        }
    }
}

private func admitClassifierWork(_ factors: [Int], remaining: inout Int) throws {
    var estimate = 1
    for factor in factors {
        guard factor >= 0, factor == 0 || estimate <= remaining / factor else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        estimate *= factor
    }
    remaining -= estimate
}

/// Collapsed-Gibbs topic model with an explicit, immutable vocabulary.
public struct GlifiLDAResult: Equatable, Sendable {
    /// Versioned inference contract.
    public static let identifier = "LDA-collapsed-Gibbs-predictive-mean-v2"
    /// Vocabulary in canonical order.
    public let vocabulary: [String]
    /// Posterior mean topic proportions per document.
    public let documentTopics: [[Double]]
    /// Posterior mean term probabilities per topic.
    public let topicTerms: [[Double]]
    /// Final topic assignment per token, preserving input document/token order.
    public let assignments: [[Int]]
    /// Seed used for initialization and sampling.
    public let seed: UInt64
    /// Burn-in sweeps.
    public let burnIn: Int
    /// Retained posterior samples.
    public let sampleCount: Int
    /// Sweeps between retained samples.
    public let thinning: Int
    /// Symmetric document-topic prior.
    public let alpha: Double
    /// Symmetric topic-term prior.
    public let beta: Double
    /// In-sample posterior-predictive perplexity; never a held-out quality estimate.
    public let trainingPerplexity: Double
    /// Retained collapsed word log likelihoods, only when explicitly requested.
    public let sampleLogWordLikelihoods: [Double]
}

/// Sparse-token LDA with flat count buffers and an explicit operation budget.
public enum GlifiLatentDirichletAllocation {
    /// Fits LDA, averaging probabilities over retained Gibbs samples rather than one final state.
    public static func fit(
        documents: [[String]], topicCount: Int, seed: UInt64,
        alpha: Double = 0.1, beta: Double = 0.01,
        burnIn: Int = 100, sampleCount: Int = 20, thinning: Int = 5,
        retainLogLikelihoods: Bool = false,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiLDAResult {
        try Task.checkCancellation()
        guard (1...1_024).contains(topicCount), alpha.isFinite, beta.isFinite,
            alpha > 0, beta > 0, (0...10_000).contains(burnIn),
            (1...10_000).contains(sampleCount), (1...1_000).contains(thinning),
            (Double(topicCount) * alpha).isFinite
        else { throw exploratoryFailure("lda.invalid-parameters") }
        // Reject impossible dense document-topic storage before building the sparse table.
        guard documents.count <= limits.maximumCells / topicCount else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        let table = try GlifiDocumentTermTable(documents: documents)
        let vocabularyCount = table.terms.count
        let tokenCount = table.totals.reduce(0, +)
        guard (Double(vocabularyCount) * beta).isFinite else {
            throw exploratoryFailure("lda.invalid-parameters")
        }
        guard tokenCount > 0 else {
            throw exploratoryFailure("lda.empty-corpus", .insufficientData)
        }
        guard topicCount <= limits.maximumCells / max(documents.count, vocabularyCount) else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        let sweeps = burnIn + sampleCount * thinning
        var remainingWork = limits.maximumWork
        try ldaAdmitWork([tokenCount, topicCount, sweeps], remaining: &remainingWork)
        try ldaAdmitWork([documents.count, topicCount, sampleCount], remaining: &remainingWork)
        try ldaAdmitWork([vocabularyCount, topicCount, sampleCount], remaining: &remainingWork)
        try ldaAdmitWork([tokenCount, topicCount, sampleCount], remaining: &remainingWork)
        if retainLogLikelihoods {
            try ldaAdmitWork([vocabularyCount, topicCount, sampleCount], remaining: &remainingWork)
        }
        let positions = Dictionary(
            uniqueKeysWithValues: table.terms.enumerated().map { ($0.element, $0.offset) })
        let words = documents.map { $0.compactMap { positions[$0] } }
        // Empty documents contribute a posterior theta, but no Gibbs token updates.
        // Retain their output rows while keeping sweep work bounded by tokenCount.
        let activeDocuments = words.indices.filter { !words[$0].isEmpty }
        var generator = GlifiSplitMix64(seed: seed)
        var assignments = words.map { $0.map { _ in generator.index(below: topicCount) } }
        var documentCounts = [Int](repeating: 0, count: documents.count * topicCount)
        var termCounts = [Int](repeating: 0, count: vocabularyCount * topicCount)
        var totals = [Int](repeating: 0, count: topicCount)
        for document in words.indices {
            for token in words[document].indices {
                let topic = assignments[document][token]
                documentCounts[document * topicCount + topic] += 1
                termCounts[words[document][token] * topicCount + topic] += 1
                totals[topic] += 1
            }
        }
        var theta = Array(
            repeating: Array(repeating: 0.0, count: topicCount), count: documents.count)
        var phi = Array(repeating: Array(repeating: 0.0, count: vocabularyCount), count: topicCount)
        let priorMass = Double(vocabularyCount) * beta
        var inverseTotals = totals.map { 1 / (Double($0) + priorMass) }
        // Only observed cells are retained: posterior prediction is E[theta*phi],
        // which cannot be recovered by multiplying E[theta] and E[phi].
        let observed = table.rows.map { $0.sorted { $0.key < $1.key } }
        var predictions = observed.map { [Double](repeating: 0, count: $0.count) }
        var probabilities = [Double](repeating: 0, count: topicCount)
        var logWordLikelihoods: [Double] = []
        if retainLogLikelihoods { logWordLikelihoods.reserveCapacity(sampleCount) }
        for sweep in 0..<sweeps {
            try Task.checkCancellation()
            for document in activeDocuments {
                for token in words[document].indices {
                    if token.isMultiple(of: 1_024) { try Task.checkCancellation() }
                    let word = words[document][token]
                    let old = assignments[document][token]
                    let rowOffset = document * topicCount
                    let wordOffset = word * topicCount
                    documentCounts[rowOffset + old] -= 1
                    termCounts[wordOffset + old] -= 1
                    totals[old] -= 1
                    inverseTotals[old] = 1 / (Double(totals[old]) + priorMass)
                    var sum = 0.0
                    for topic in 0..<topicCount {
                        let value =
                            (Double(documentCounts[rowOffset + topic]) + alpha)
                            * (Double(termCounts[wordOffset + topic]) + beta)
                            * inverseTotals[topic]
                        sum += value
                        probabilities[topic] = sum
                    }
                    guard sum.isFinite, sum > 0 else {
                        throw exploratoryFailure("exploratory.numeric-overflow")
                    }
                    let draw = Double(generator.next() >> 11) / 9_007_199_254_740_992 * sum
                    let topic = probabilities.firstIndex { draw < $0 } ?? topicCount - 1
                    assignments[document][token] = topic
                    documentCounts[rowOffset + topic] += 1
                    termCounts[wordOffset + topic] += 1
                    totals[topic] += 1
                    inverseTotals[topic] = 1 / (Double(totals[topic]) + priorMass)
                }
            }
            if sweep >= burnIn, (sweep - burnIn + 1).isMultiple(of: thinning) {
                if retainLogLikelihoods {
                    var likelihood = 0.0
                    let logBeta: Double = lgamma(beta)
                    let logMass: Double = lgamma(priorMass)
                    for topic in 0..<topicCount {
                        likelihood += logMass - lgamma(Double(totals[topic]) + priorMass)
                        for word in 0..<vocabularyCount {
                            let count = termCounts[word * topicCount + topic]
                            if count > 0 { likelihood += lgamma(Double(count) + beta) - logBeta }
                        }
                    }
                    guard likelihood.isFinite else {
                        throw exploratoryFailure("exploratory.numeric-overflow")
                    }
                    logWordLikelihoods.append(likelihood)
                }
                for document in words.indices {
                    let denominator = Double(words[document].count) + Double(topicCount) * alpha
                    for topic in 0..<topicCount {
                        theta[document][topic] +=
                            (Double(documentCounts[document * topicCount + topic]) + alpha)
                            / denominator / Double(sampleCount)
                    }
                }
                for document in activeDocuments {
                    let documentDenominator =
                        Double(words[document].count) + Double(topicCount) * alpha
                    for (position, cell) in observed[document].enumerated() {
                        var prediction = 0.0
                        for topic in 0..<topicCount {
                            let theta =
                                (Double(documentCounts[document * topicCount + topic]) + alpha)
                                / documentDenominator
                            let phi =
                                (Double(termCounts[cell.key * topicCount + topic]) + beta)
                                * inverseTotals[topic]
                            prediction += theta * phi
                        }
                        predictions[document][position] += prediction / Double(sampleCount)
                    }
                }
                for topic in 0..<topicCount {
                    let denominator = Double(totals[topic]) + Double(vocabularyCount) * beta
                    for word in 0..<vocabularyCount {
                        phi[topic][word] +=
                            (Double(termCounts[word * topicCount + topic]) + beta) / denominator
                            / Double(sampleCount)
                    }
                }
            }
        }
        var logLikelihood = 0.0
        for document in observed.indices {
            for (position, cell) in observed[document].enumerated() {
                logLikelihood += Double(cell.value) * log(predictions[document][position])
            }
        }
        let perplexity = exp(-logLikelihood / Double(tokenCount))
        guard perplexity.isFinite else { throw exploratoryFailure("exploratory.numeric-overflow") }
        return GlifiLDAResult(
            vocabulary: table.terms, documentTopics: theta, topicTerms: phi,
            assignments: assignments,
            seed: seed, burnIn: burnIn, sampleCount: sampleCount, thinning: thinning,
            alpha: alpha, beta: beta, trainingPerplexity: perplexity,
            sampleLogWordLikelihoods: logWordLikelihoods
        )
    }
}
