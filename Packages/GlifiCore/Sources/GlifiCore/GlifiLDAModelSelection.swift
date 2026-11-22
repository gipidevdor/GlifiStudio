// SPDX-License-Identifier: BSD-3-Clause

import Accelerate
import Foundation

/// Explicit optimization direction; held-out prediction is the default selection criterion.
public enum GlifiTopicSelectionCriterion: String, Codable, Sendable {
    case heldOutPerplexity
    case caoJuan2009
    case arun2010
    case deveaud2014
    case griffiths2004
}

/// Four named diagnostics with explicit undefined cases instead of fabricated scores.
public struct GlifiLDATuningMetrics: Equatable, Sendable {
    /// Mean pairwise topic cosine similarity, minimized by the named criterion.
    public let caoJuan2009: Double?
    /// Symmetric divergence between singular values and length-weighted topic masses.
    public let arun2010: Double?
    /// Reference half-Jeffreys sum divided by K(K-1), maximized by the named criterion.
    public let deveaud2014: Double?
    /// Log harmonic mean of retained collapsed word likelihoods.
    public let griffiths2004: Double?
    /// Stable reason for each unavailable named metric.
    public let unavailableReasons: [String: String]
}

/// Document-completion prediction under a frozen training vocabulary and topic-word matrix.
public struct GlifiLDAHeldOutScore: Equatable, Sendable {
    /// Versioned document-completion scoring contract.
    public static let identifier = "LDA-document-completion-fixed-phi-Gibbs-v1"
    /// Sum of log posterior-predictive probabilities of scored known tokens.
    public let logLikelihood: Double
    /// Number of known tokens reserved for scoring.
    public let evaluatedTokenCount: Int
    /// Number of known tokens used only as observed fold-in context.
    public let observedTokenCount: Int
    /// Number of original tokens outside the frozen training vocabulary.
    public let ignoredTokenCount: Int
    /// Exponential negative mean held-out log likelihood.
    public let perplexity: Double
}

/// One fitted candidate; fold scores preserve coverage and never reuse training perplexity.
public struct GlifiLDACandidateEvaluation: Equatable, Sendable {
    /// Number of topics fitted by this candidate.
    public let topicCount: Int
    /// Full-corpus training diagnostics with explicit undefined cases.
    public let metrics: GlifiLDATuningMetrics
    /// Token-weighted aggregate held-out perplexity, when folds were requested.
    public let heldOutPerplexity: Double?
    /// Held-out score and vocabulary coverage for every fold in order.
    public let foldScores: [GlifiLDAHeldOutScore]
    /// Full-model in-sample perplexity, distinct from held-out quality.
    public let trainingPerplexity: Double
}

/// Bounded model search, retaining only the selected full model rather than every dense fit.
public struct GlifiLDAModelSelectionResult: Equatable, Sendable {
    /// Versioned selection and training-vocabulary contract.
    public static let identifier = "LDA-model-selection-training-vocabulary-CV-v1"
    /// Metric actually used for selection.
    public let criterion: GlifiTopicSelectionCriterion
    /// Topic count of the selected defined candidate.
    public let selectedTopicCount: Int
    /// Selected model fitted on the complete input corpus.
    public let selectedModel: GlifiLDAResult
    /// Diagnostics of all candidates in ascending topic-count order.
    public let candidates: [GlifiLDACandidateEvaluation]
    /// Fold index per original document, or an empty array without cross-validation.
    public let foldAssignments: [Int]
    /// Seed from which stable fold and fitting seeds were derived.
    public let seed: UInt64
}

/// Native diagnostics and leakage-free, seeded selection of the topic count.
public enum GlifiLDAModelSelection {
    /// Computes the four named diagnostics without substituting undefined values.
    ///
    /// Cao is mean cosine similarity. Deveaud is the reference half-Jeffreys sum divided
    /// by K(K-1), not Jensen-Shannon divergence. Arun uses singular values and document
    /// topic masses divided by the maximum document length, matching the named contract.
    /// Griffiths is the log harmonic mean of retained collapsed word likelihoods.
    public static func metrics(
        topicTerms: [[Double]], documentTopics: [[Double]], documentLengths: [Int],
        logWordLikelihoods: [Double] = [], limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiLDATuningMetrics {
        try Task.checkCancellation()
        let vocabulary = try validateExploratoryMatrix(topicTerms, limits: limits)
        let topics = topicTerms.count
        guard !documentTopics.isEmpty, documentTopics.count == documentLengths.count,
            documentLengths.allSatisfy({ $0 >= 0 }),
            documentTopics.count <= limits.maximumCells / topics,
            documentTopics.allSatisfy({ $0.count == topics }),
            topicTerms.allSatisfy({ $0.allSatisfy { $0 >= 0 } }),
            documentTopics.allSatisfy({ $0.allSatisfy { $0.isFinite && $0 >= 0 } }),
            topicTerms.allSatisfy({ abs($0.reduce(0, +) - 1) <= 1e-8 }),
            documentTopics.allSatisfy({ abs($0.reduce(0, +) - 1) <= 1e-8 }),
            logWordLikelihoods.count <= 10_000,
            logWordLikelihoods.allSatisfy(\.isFinite)
        else { throw exploratoryFailure("lda-selection.invalid-metrics") }
        try requireWork([topics, topics, vocabulary], limits)
        var unavailable: [String: String] = [:]
        var cao: Double?
        var deveaud: Double?
        if topics > 1 {
            let norms = topicTerms.map { vDSP.sumOfSquares($0).squareRoot() }
            var cosine = 0.0
            var divergence = 0.0
            var positive = true
            for left in 0..<(topics - 1) {
                try Task.checkCancellation()
                for right in (left + 1)..<topics {
                    cosine += min(
                        1,
                        max(
                            0,
                            vDSP.dot(topicTerms[left], topicTerms[right]) / norms[left]
                                / norms[right]))
                    for term in 0..<vocabulary {
                        let a = topicTerms[left][term]
                        let b = topicTerms[right][term]
                        if a == b { continue }
                        if a > 0, b > 0 {
                            divergence += 0.5 * (a - b) * (log(a) - log(b))
                        } else {
                            positive = false
                        }
                    }
                }
            }
            let pairs = Double(topics) * Double(topics - 1) / 2
            cao = cosine / pairs
            if positive, divergence.isFinite {
                deveaud = divergence / (2 * pairs)
            } else {
                unavailable["deveaud2014"] = "non-positive-topic-probability"
            }
        } else {
            unavailable["caoJuan2009"] = "requires-multiple-topics"
            unavailable["deveaud2014"] = "requires-multiple-topics"
        }
        var arun: Double?
        if topics <= vocabulary, let maximumLength = documentLengths.max(), maximumLength > 0 {
            let singular = try ldaSingularValues(topicTerms, limits: limits)
            var masses = [Double](repeating: 0, count: topics)
            for document in documentTopics.indices {
                if document.isMultiple(of: 256) { try Task.checkCancellation() }
                let weight = Double(documentLengths[document]) / Double(maximumLength)
                for topic in 0..<topics {
                    masses[topic] += weight * documentTopics[document][topic]
                }
            }
            let minimumSingular =
                (singular.first ?? 0) * Double(max(topics, vocabulary)) * Double.ulpOfOne
            if singular.count == topics, singular.allSatisfy({ $0 > minimumSingular }),
                masses.allSatisfy({ $0 > 0 && $0.isFinite })
            {
                let score = zip(singular, masses).reduce(0.0) {
                    $0 + ($1.0 - $1.1) * (log($1.0) - log($1.1))
                }
                if score.isFinite {
                    arun = max(0, score)
                } else {
                    unavailable["arun2010"] = "numeric-overflow"
                }
            } else {
                unavailable["arun2010"] = "rank-deficient-topic-matrix"
            }
        } else {
            unavailable["arun2010"] =
                "requires-topics-not-exceeding-vocabulary-and-nonempty-documents"
        }
        var griffiths: Double?
        if let minimum = logWordLikelihoods.min() {
            // -log(mean(exp(-log L))) evaluated after centering at the largest exponent.
            let sum = logWordLikelihoods.reduce(0.0) { $0 + exp(minimum - $1) }
            let score = minimum - log(sum / Double(logWordLikelihoods.count))
            if score.isFinite {
                griffiths = score
            } else {
                unavailable["griffiths2004"] = "numeric-overflow"
            }
        } else {
            unavailable["griffiths2004"] = "retained-log-likelihoods-required"
        }
        return GlifiLDATuningMetrics(
            caoJuan2009: cao, arun2010: arun, deveaud2014: deveaud,
            griffiths2004: griffiths, unavailableReasons: unavailable)
    }

    /// Uses a fresh training vocabulary per fold.
    ///
    /// Each held-out document is split in
    /// known-token order into an observed first half and a scored second half.
    /// Unknown tokens are counted and excluded explicitly; an all-OOV evaluation fails.
    public static func select(
        documents: [[String]], candidateTopicCounts: [Int], seed: UInt64,
        criterion: GlifiTopicSelectionCriterion = .heldOutPerplexity, folds: Int = 5,
        alpha: Double = 0.1, beta: Double = 0.01, burnIn: Int = 100,
        sampleCount: Int = 20, thinning: Int = 5,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiLDAModelSelectionResult {
        try Task.checkCancellation()
        guard !candidateTopicCounts.isEmpty, candidateTopicCounts.count <= 32,
            Set(candidateTopicCounts).count == candidateTopicCounts.count,
            candidateTopicCounts.allSatisfy({ (1...1_024).contains($0) }),
            documents.count <= 20_000,
            folds == 0 || (folds >= 2 && folds <= documents.count),
            criterion != .heldOutPerplexity || folds >= 2,
            (0...10_000).contains(burnIn), (1...10_000).contains(sampleCount),
            (1...1_000).contains(thinning), alpha.isFinite, alpha > 0,
            beta.isFinite, beta > 0
        else { throw exploratoryFailure("lda-selection.invalid-parameters") }
        let table = try GlifiDocumentTermTable(documents: documents)
        let tokens = table.totals.reduce(0, +)
        let sweeps = burnIn + sampleCount * thinning
        var remainingWork = limits.maximumWork
        // Across all folds, full and training fits see at most F copies of the corpus;
        // their dense phi accumulators have F+1 vocabularies. Admit all candidates
        // before starting any fit, including empty-document theta accumulation.
        let fittedCopies = max(1, folds)
        for topics in candidateTopicCounts {
            try ldaAdmitWork([tokens, topics, sweeps, fittedCopies], remaining: &remainingWork)
            try ldaAdmitWork(
                [documents.count, topics, sampleCount, fittedCopies], remaining: &remainingWork)
            try ldaAdmitWork(
                [table.terms.count, topics, sampleCount, folds + 1], remaining: &remainingWork)
            try ldaAdmitWork(
                [tokens, topics, sampleCount, fittedCopies], remaining: &remainingWork)
            try ldaAdmitWork([table.terms.count, topics, sampleCount], remaining: &remainingWork)
            try ldaAdmitWork([topics, topics, table.terms.count, 3], remaining: &remainingWork)
            try ldaAdmitWork([documents.count, topics], remaining: &remainingWork)
            if folds > 0 {
                try ldaAdmitWork([tokens, topics, sweeps], remaining: &remainingWork)
                try ldaAdmitWork([documents.count, topics, sampleCount], remaining: &remainingWork)
                try ldaAdmitWork([tokens, topics], remaining: &remainingWork)
                try ldaAdmitWork([table.terms.count, topics, folds], remaining: &remainingWork)
            }
        }
        var generator = GlifiSplitMix64(seed: seed)
        var shuffled = Array(documents.indices)
        for index in shuffled.indices {
            shuffled.swapAt(index, index + generator.index(below: shuffled.count - index))
        }
        var assignments = [Int](repeating: 0, count: documents.count)
        if folds > 0 {
            for (position, document) in shuffled.enumerated() {
                assignments[document] = position % folds
            }
        }
        var evaluations: [GlifiLDACandidateEvaluation] = []
        var selected: GlifiLDAResult?
        var selectedCount = 0
        var selectedScore: Double?
        for topics in candidateTopicCounts.sorted() {
            try Task.checkCancellation()
            let model = try GlifiLatentDirichletAllocation.fit(
                documents: documents, topicCount: topics, seed: ldaSeed(seed, topics),
                alpha: alpha, beta: beta, burnIn: burnIn, sampleCount: sampleCount,
                thinning: thinning, retainLogLikelihoods: true, limits: limits)
            let diagnostics = try metrics(
                topicTerms: model.topicTerms, documentTopics: model.documentTopics,
                documentLengths: table.totals, logWordLikelihoods: model.sampleLogWordLikelihoods,
                limits: limits)
            var scores: [GlifiLDAHeldOutScore] = []
            if folds > 0 {
                for fold in 0..<folds {
                    try Task.checkCancellation()
                    let training = documents.indices.filter { assignments[$0] != fold }
                    let heldOut = documents.indices.filter { assignments[$0] == fold }
                    let trainingModel = try GlifiLatentDirichletAllocation.fit(
                        documents: training.map { documents[$0] }, topicCount: topics,
                        seed: ldaSeed(seed, topics, fold), alpha: alpha, beta: beta,
                        burnIn: burnIn, sampleCount: sampleCount, thinning: thinning, limits: limits
                    )
                    scores.append(
                        try heldOutScore(
                            documents: heldOut.map { documents[$0] }, model: trainingModel,
                            seed: ldaSeed(seed, topics, fold, 1), burnIn: burnIn,
                            sampleCount: sampleCount, thinning: thinning, limits: limits))
                }
            }
            let evaluated = scores.reduce(0) { $0 + $1.evaluatedTokenCount }
            let logLikelihood = scores.reduce(0.0) { $0 + $1.logLikelihood }
            let perplexity = evaluated > 0 ? exp(-logLikelihood / Double(evaluated)) : nil
            let evaluation = GlifiLDACandidateEvaluation(
                topicCount: topics, metrics: diagnostics, heldOutPerplexity: perplexity,
                foldScores: scores, trainingPerplexity: model.trainingPerplexity)
            evaluations.append(evaluation)
            let score: Double?
            let minimize: Bool
            switch criterion {
            case .heldOutPerplexity:
                score = perplexity
                minimize = true
            case .caoJuan2009:
                score = diagnostics.caoJuan2009
                minimize = true
            case .arun2010:
                score = diagnostics.arun2010
                minimize = true
            case .deveaud2014:
                score = diagnostics.deveaud2014
                minimize = false
            case .griffiths2004:
                score = diagnostics.griffiths2004
                minimize = false
            }
            if let score, score.isFinite,
                selectedScore == nil
                    || (minimize
                        ? score < (selectedScore ?? score) : score > (selectedScore ?? score))
            {
                selectedScore = score
                selected = model
                selectedCount = topics
            }
        }
        guard let selected else {
            throw exploratoryFailure("lda-selection.no-defined-candidate", .insufficientData)
        }
        return GlifiLDAModelSelectionResult(
            criterion: criterion, selectedTopicCount: selectedCount, selectedModel: selected,
            candidates: evaluations, foldAssignments: folds > 0 ? assignments : [], seed: seed)
    }

    /// Fold-in samples only observed tokens; scored tokens never update document-topic counts.
    public static func heldOutScore(
        documents: [[String]], model: GlifiLDAResult, seed: UInt64,
        burnIn: Int = 100, sampleCount: Int = 20, thinning: Int = 5,
        limits: GlifiExploratoryLimits = .standard
    ) throws -> GlifiLDAHeldOutScore {
        try Task.checkCancellation()
        guard (0...10_000).contains(burnIn), (1...10_000).contains(sampleCount),
            (1...1_000).contains(thinning), !model.topicTerms.isEmpty,
            model.alpha.isFinite, model.alpha > 0, documents.count <= 20_000
        else { throw exploratoryFailure("lda-selection.invalid-fold-in") }
        let topics = model.topicTerms.count
        guard !model.vocabulary.isEmpty,
            model.topicTerms.allSatisfy({ $0.count == model.vocabulary.count }),
            model.topicTerms.allSatisfy({ $0.allSatisfy { $0 > 0 && $0.isFinite } }),
            topics <= limits.maximumCells / model.vocabulary.count
        else { throw exploratoryFailure("lda-selection.invalid-model") }
        let table = try GlifiDocumentTermTable(documents: documents, vocabulary: model.vocabulary)
        let sweeps = burnIn + sampleCount * thinning
        let knownTokens = table.totals.reduce(0, +)
        guard knownTokens > 0 else {
            throw exploratoryFailure("lda-selection.no-held-out-vocabulary", .insufficientData)
        }
        let contextTokens = table.totals.reduce(0) { $0 + $1 / 2 }
        let sampledDocuments = table.totals.filter { $0 >= 2 }.count
        var remainingWork = limits.maximumWork
        try ldaAdmitWork([contextTokens, topics, sweeps], remaining: &remainingWork)
        try ldaAdmitWork([sampledDocuments, topics, sampleCount], remaining: &remainingWork)
        try ldaAdmitWork([knownTokens, topics], remaining: &remainingWork)
        try ldaAdmitWork([model.vocabulary.count, topics], remaining: &remainingWork)
        let positions = Dictionary(
            uniqueKeysWithValues: model.vocabulary.enumerated().map { ($0.element, $0.offset) })
        let wordTopics = model.vocabulary.indices.map { word in model.topicTerms.map { $0[word] } }
        var generator = GlifiSplitMix64(seed: seed)
        var likelihood = 0.0
        var evaluated = 0
        var observed = 0
        var ignored = 0
        for document in documents {
            try Task.checkCancellation()
            let words = document.compactMap { positions[$0] }
            ignored += document.count - words.count
            guard !words.isEmpty else { continue }
            let boundary = words.count / 2
            let context = Array(words.prefix(boundary))
            let targets = words.dropFirst(boundary)
            observed += context.count
            evaluated += targets.count
            var assignments = context.map { _ in generator.index(below: topics) }
            var counts = [Int](repeating: 0, count: topics)
            for topic in assignments { counts[topic] += 1 }
            var theta = [Double](repeating: 0, count: topics)
            var cumulative = [Double](repeating: 0, count: topics)
            if context.isEmpty {
                // With no observed words the symmetric Dirichlet mean is analytic.
                theta = [Double](repeating: 1 / Double(topics), count: topics)
            } else {
                for sweep in 0..<sweeps {
                    try Task.checkCancellation()
                    for token in context.indices {
                        if token.isMultiple(of: 1_024) { try Task.checkCancellation() }
                        counts[assignments[token]] -= 1
                        var mass = 0.0
                        for topic in 0..<topics {
                            mass +=
                                (Double(counts[topic]) + model.alpha)
                                * wordTopics[context[token]][topic]
                            cumulative[topic] = mass
                        }
                        guard mass > 0, mass.isFinite else {
                            throw exploratoryFailure("exploratory.numeric-overflow")
                        }
                        let draw = Double(generator.next() >> 11) / 9_007_199_254_740_992 * mass
                        let next = cumulative.firstIndex { draw < $0 } ?? topics - 1
                        assignments[token] = next
                        counts[next] += 1
                    }
                    if sweep >= burnIn, (sweep - burnIn + 1).isMultiple(of: thinning) {
                        let denominator = Double(context.count) + Double(topics) * model.alpha
                        for topic in 0..<topics {
                            theta[topic] +=
                                (Double(counts[topic]) + model.alpha) / denominator
                                / Double(sampleCount)
                        }
                    }
                }
            }
            var frequencies: [Int: Int] = [:]
            for word in targets { frequencies[word, default: 0] += 1 }
            for (word, count) in frequencies.sorted(by: { $0.key < $1.key }) {
                let probability = vDSP.dot(theta, wordTopics[word])
                guard probability > 0, probability.isFinite else {
                    throw exploratoryFailure("exploratory.numeric-overflow")
                }
                likelihood += Double(count) * log(probability)
            }
        }
        guard evaluated > 0 else {
            throw exploratoryFailure("lda-selection.no-held-out-vocabulary", .insufficientData)
        }
        let perplexity = exp(-likelihood / Double(evaluated))
        guard likelihood.isFinite, perplexity.isFinite else {
            throw exploratoryFailure("exploratory.numeric-overflow")
        }
        return GlifiLDAHeldOutScore(
            logLikelihood: likelihood, evaluatedTokenCount: evaluated,
            observedTokenCount: observed, ignoredTokenCount: ignored, perplexity: perplexity)
    }
}

private func ldaSeed(_ seed: UInt64, _ topic: Int, _ fold: Int = 0, _ stage: Int = 0) -> UInt64 {
    var generator = GlifiSplitMix64(
        seed: seed &+ UInt64(topic) &* 0x9E3779B97F4A7C15
            &+ UInt64(fold) &* 0xBF58476D1CE4E5B9 &+ UInt64(stage) &* 0x94D049BB133111EB)
    return generator.next()
}

package func ldaAdmitWork(_ factors: [Int], remaining: inout Int) throws {
    var work = 1
    for factor in factors {
        guard factor >= 0, work == 0 || factor <= remaining / work else {
            throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
        }
        work *= factor
    }
    remaining -= work
}

private func ldaSingularValues(
    _ input: [[Double]], limits: GlifiExploratoryLimits
) throws -> [Double] {
    let rows = input.count
    let columns = input[0].count
    guard rows <= 1_024, columns <= 100_000, rows <= limits.maximumCells / columns else {
        throw exploratoryFailure("exploratory.resource-limit", .insufficientResources)
    }
    try requireWork([rows, rows, columns], limits)
    var matrix = (0..<columns).flatMap { column in input.map { $0[column] } }
    var values = [Double](repeating: 0, count: min(rows, columns))
    var jobU: Int8 = 78
    var jobV: Int8 = 78
    var m = __LAPACK_int(rows)
    var n = __LAPACK_int(columns)
    var leading = m
    var leadingU: __LAPACK_int = 1
    var leadingV: __LAPACK_int = 1
    var dummyU = [0.0]
    var dummyV = [0.0]
    var info: __LAPACK_int = 0
    var size: __LAPACK_int = -1
    var query = 0.0
    dgesvd_(
        &jobU, &jobV, &m, &n, &matrix, &leading, &values, &dummyU, &leadingU,
        &dummyV, &leadingV, &query, &size, &info)
    guard info == 0, query.isFinite, query >= 1, query <= Double(limits.maximumCells) else {
        throw exploratoryFailure("lda-selection.svd-workspace")
    }
    size = __LAPACK_int(query.rounded(.up))
    var workspace = [Double](repeating: 0, count: Int(size))
    try Task.checkCancellation()
    dgesvd_(
        &jobU, &jobV, &m, &n, &matrix, &leading, &values, &dummyU, &leadingU,
        &dummyV, &leadingV, &workspace, &size, &info)
    guard info == 0, values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
        throw exploratoryFailure("lda-selection.svd-failed")
    }
    return values
}
