// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Sufficient statistics for exact-count continuation without retaining source documents.
public struct GlifiNaiveBayesTrainingState: Equatable, Sendable {
    /// Count-based continuation contract, independent of the project or transport schema.
    public static let identifier = "MultinomialNaiveBayes-incremental-counts-v1"
    /// Unique category labels in strictly increasing canonical order.
    public let classes: [String]
    /// Training vocabulary, expanded and reindexed on subsequent batches.
    public let vocabulary: [String]
    /// Positive observed document count for every category, without smoothing.
    public let documentCounts: [Int]
    /// Exact nonnegative token counts, category by vocabulary position.
    public let tokenCounts: [[Int]]
    /// Positive symmetric pseudocount used when constructing the probability model.
    public let smoothing: Double

    /// Restores transient statistics only after validating identities, counts and resource bounds.
    public init(
        classes: [String], vocabulary: [String], documentCounts: [Int],
        tokenCounts: [[Int]], smoothing: Double = 1,
        limits: GlifiExploratoryLimits = .standard
    ) throws {
        try Task.checkCancellation()
        guard !classes.isEmpty, !vocabulary.isEmpty,
            classes.count == documentCounts.count, classes.count == tokenCounts.count,
            smoothing.isFinite, smoothing > 0
        else { throw exploratoryFailure("naive-bayes.invalid-training-state") }
        var work = limits.maximumWork
        try incrementalWork([classes.count, vocabulary.count], remaining: &work)
        try incrementalCells(classes.count, vocabulary.count, limits: limits)
        try incrementalIdentities(classes + vocabulary, remaining: &work)
        guard incrementalCanonicalIdentities(classes), incrementalCanonicalIdentities(vocabulary),
            !classes.contains(where: \.isEmpty), !vocabulary.contains(where: \.isEmpty),
            vocabulary.count <= 100_000
        else { throw exploratoryFailure("naive-bayes.invalid-training-state") }
        var totalDocuments = 0
        for category in classes.indices {
            if category.isMultiple(of: 256) { try Task.checkCancellation() }
            guard documentCounts[category] > 0,
                tokenCounts[category].count == vocabulary.count
            else { throw exploratoryFailure("naive-bayes.invalid-training-state") }
            totalDocuments = try incrementalCount(totalDocuments, documentCounts[category])
            var tokens = 0
            for (index, count) in tokenCounts[category].enumerated() {
                if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
                guard count >= 0 else {
                    throw exploratoryFailure("naive-bayes.invalid-training-state")
                }
                tokens = try incrementalCount(tokens, count)
            }
        }
        self.classes = classes
        self.vocabulary = vocabulary
        self.documentCounts = documentCounts
        self.tokenCounts = tokenCounts
        self.smoothing = smoothing
    }

    /// Uses the same empirical priors and Laplace likelihoods as the batch model.
    public func model(
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiNaiveBayesModel {
        try Task.checkCancellation()
        guard classes.count >= 2 else {
            throw exploratoryFailure("naive-bayes.insufficient-classes", .insufficientData)
        }
        try incrementalCells(classes.count, vocabulary.count, limits: limits)
        var work = limits.maximumWork
        try incrementalWork([classes.count, vocabulary.count, 2], remaining: &work)
        let mass = Double(vocabulary.count) * smoothing
        guard mass.isFinite else { throw exploratoryFailure("naive-bayes.invalid-smoothing") }
        let complementaryMass = Double(vocabulary.count - 1) * smoothing
        let totalDocuments = try documentCounts.reduce(0) { try incrementalCount($0, $1) }
        var likelihoods: [[Double]] = []
        for category in classes.indices {
            try Task.checkCancellation()
            let total = try tokenCounts[category].reduce(0) { try incrementalCount($0, $1) }
            let denominator = Double(total) + mass
            let logDenominator = log(denominator)
            let values = tokenCounts[category].map {
                naiveBayesLogLikelihood(
                    $0, total: total, smoothing: smoothing,
                    complementaryMass: complementaryMass,
                    denominator: denominator, logDenominator: logDenominator)
            }
            guard values.allSatisfy(\.isFinite) else {
                throw exploratoryFailure("exploratory.numeric-overflow")
            }
            likelihoods.append(values)
        }
        return GlifiNaiveBayesModel(
            classes: classes, vocabulary: vocabulary,
            logPriors: documentCounts.map { naiveBayesLogPrior($0, total: totalDocuments) },
            logLikelihoods: likelihoods, smoothing: smoothing)
    }
}

/// Incremental multinomial training with canonical class/vocabulary expansion.
public enum GlifiIncrementalNaiveBayes {
    /// Creates sufficient statistics, admitting an initial batch with only one category.
    public static func train(
        documents: [[String]], labels: [String], smoothing: Double = 1,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiNaiveBayesTrainingState {
        try accumulate(
            nil, documents: documents, labels: labels, smoothing: smoothing, limits: limits)
    }

    /// Returns a new immutable state; previously fitted models remain unchanged.
    public static func update(
        _ state: GlifiNaiveBayesTrainingState, documents: [[String]], labels: [String],
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiNaiveBayesTrainingState {
        try accumulate(
            state, documents: documents, labels: labels, smoothing: state.smoothing, limits: limits)
    }

    private static func accumulate(
        _ state: GlifiNaiveBayesTrainingState?, documents: [[String]], labels: [String],
        smoothing: Double, limits: GlifiExploratoryLimits
    ) throws -> GlifiNaiveBayesTrainingState {
        try Task.checkCancellation()
        guard labels.count == documents.count, !labels.contains(where: \.isEmpty),
            smoothing.isFinite, smoothing > 0, state != nil || !documents.isEmpty
        else { throw exploratoryFailure("naive-bayes.invalid-training") }
        guard documents.count <= limits.maximumCells else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        var work = limits.maximumWork
        try incrementalWork([documents.count], remaining: &work)
        try incrementalIdentities(labels, remaining: &work)
        if let state {
            try incrementalCells(state.classes.count, state.vocabulary.count, limits: limits)
            try incrementalWork([state.classes.count, state.vocabulary.count], remaining: &work)
            try incrementalIdentities(state.classes, remaining: &work)
            try incrementalIdentities(state.vocabulary, remaining: &work)
        }
        var tokenCount = 0
        var tokenBytes = 0
        var vocabulary = Set(state?.vocabulary ?? [])
        for (index, document) in documents.enumerated() {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            guard document.count <= 2_000_000 - tokenCount else {
                throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
            }
            tokenCount += document.count
            try incrementalWork([document.count], remaining: &work)
            for (tokenIndex, token) in document.enumerated() {
                if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
                guard !token.isEmpty else {
                    throw exploratoryFailure("text-table.invalid-vocabulary")
                }
                let bytes = token.utf8.count
                guard bytes <= 67_108_864 - tokenBytes else {
                    throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
                }
                tokenBytes += bytes
                try incrementalWork([bytes], remaining: &work)
                vocabulary.insert(token)
                guard vocabulary.count <= 100_000 else {
                    throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
                }
            }
        }
        guard !vocabulary.isEmpty else { throw exploratoryFailure("text-table.invalid-vocabulary") }
        let classKeys = Set((state?.classes ?? []) + labels)
        try incrementalCells(classKeys.count, vocabulary.count, limits: limits)
        try incrementalWork(
            [vocabulary.count, incrementalSortLevels(vocabulary.count)], remaining: &work)
        try incrementalWork(
            [classKeys.count, incrementalSortLevels(classKeys.count)], remaining: &work)
        let terms = vocabulary.sorted()
        let classes = classKeys.sorted()
        try incrementalWork([classes.count, terms.count, 3], remaining: &work)
        try incrementalWork([tokenCount], remaining: &work)
        let classPositions = Dictionary(uniqueKeysWithValues: classes.enumerated().map { ($1, $0) })
        let termPositions = Dictionary(uniqueKeysWithValues: terms.enumerated().map { ($1, $0) })
        var counts = Array(repeating: [Int](repeating: 0, count: terms.count), count: classes.count)
        var documentCounts = [Int](repeating: 0, count: classes.count)
        if let state {
            for (category, label) in state.classes.enumerated() {
                try Task.checkCancellation()
                guard let destination = classPositions[label] else {
                    throw exploratoryFailure("naive-bayes.invalid-training-state")
                }
                documentCounts[destination] = state.documentCounts[category]
                for (term, name) in state.vocabulary.enumerated() {
                    if term.isMultiple(of: 4_096) { try Task.checkCancellation() }
                    guard let column = termPositions[name] else {
                        throw exploratoryFailure("naive-bayes.invalid-training-state")
                    }
                    counts[destination][column] = state.tokenCounts[category][term]
                }
            }
        }
        for index in documents.indices {
            if index.isMultiple(of: 256) { try Task.checkCancellation() }
            guard let category = classPositions[labels[index]] else {
                throw exploratoryFailure("naive-bayes.invalid-training-state")
            }
            documentCounts[category] = try incrementalCount(documentCounts[category], 1)
            for (tokenIndex, token) in documents[index].enumerated() {
                if tokenIndex.isMultiple(of: 4_096) { try Task.checkCancellation() }
                guard let column = termPositions[token] else {
                    throw exploratoryFailure("naive-bayes.invalid-training-state")
                }
                counts[category][column] = try incrementalCount(counts[category][column], 1)
            }
        }
        return try GlifiNaiveBayesTrainingState(
            classes: classes, vocabulary: terms, documentCounts: documentCounts,
            tokenCounts: counts, smoothing: smoothing,
            limits: GlifiExploratoryLimits(
                maximumCells: limits.maximumCells,
                maximumPairwiseObjects: limits.maximumPairwiseObjects,
                maximumWork: work))
    }
}

/// Held-out evaluation and nominal chance-corrected agreement on the same predictions.
public struct GlifiNaiveBayesAgreementEvaluation: Equatable, Sendable {
    /// Held-out evaluation and agreement composition, without changing the fitted model.
    public static let identifier = "MultinomialNaiveBayes-stratified-CV-CohenKappa-v1"
    /// Confusion matrix, accuracy, held-out labels and stratified fold assignments.
    public let evaluation: GlifiClassificationEvaluation
    /// Observed/expected agreement and nominal kappa over those same held-out labels.
    public let agreement: GlifiCohenKappaResult
}

extension GlifiNaiveBayes {
    /// Fits within each fold only and evaluates the resulting predictions against their actual labels.
    public static func crossValidateWithAgreement(
        documents: [[String]], labels: [String], folds: Int, seed: UInt64,
        smoothing: Double = 1, limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiNaiveBayesAgreementEvaluation {
        try Task.checkCancellation()
        // Charge the agreement scan as well as the existing cross-validation phases.
        var work = limits.maximumWork
        try incrementalWork([documents.count, 4], remaining: &work)
        let reducedLimits = GlifiExploratoryLimits(
            maximumCells: limits.maximumCells,
            maximumPairwiseObjects: limits.maximumPairwiseObjects,
            maximumWork: work)
        let evaluation = try crossValidate(
            documents: documents, labels: labels, folds: folds, seed: seed,
            smoothing: smoothing, limits: reducedLimits)
        try Task.checkCancellation()
        return try GlifiNaiveBayesAgreementEvaluation(
            evaluation: evaluation,
            agreement: GlifiAgreementAnalysis.cohenKappa(
                rater1: labels, rater2: evaluation.predictions))
    }
}

private func incrementalCells(_ rows: Int, _ columns: Int, limits: GlifiExploratoryLimits) throws {
    guard columns > 0, rows <= limits.maximumCells / columns else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
}

private func incrementalCount(_ a: Int, _ b: Int) throws -> Int {
    let (value, overflow) = a.addingReportingOverflow(b)
    guard !overflow else { throw exploratoryFailure("naive-bayes.count-overflow") }
    return value
}

private func incrementalWork(_ factors: [Int], remaining: inout Int) throws {
    var estimate = 1
    for factor in factors {
        guard factor >= 0, factor == 0 || estimate <= remaining / factor else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        estimate *= factor
    }
    remaining -= estimate
}

private func incrementalIdentities(_ values: [String], remaining: inout Int) throws {
    var bytes = 0
    for (index, value) in values.enumerated() {
        if index.isMultiple(of: 4_096) { try Task.checkCancellation() }
        let count = value.utf8.count
        guard count <= 67_108_864 - bytes else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        bytes += count
        try incrementalWork([count], remaining: &remaining)
    }
}

private func incrementalCanonicalIdentities(_ values: [String]) -> Bool {
    guard !values.isEmpty else { return false }
    for index in values.indices.dropFirst() {
        guard values[index - 1] < values[index] else { return false }
    }
    return true
}

private func incrementalSortLevels(_ count: Int) -> Int {
    count < 2 ? 1 : Int.bitWidth - (count - 1).leadingZeroBitCount
}
