// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation

/// Deterministic two-corpus similarity result with explicit population lineage.
public struct GlifiCorpusSimilarityComparison: Codable, Equatable, Sendable {
    /// Versioned aggregate comparison contract.
    public let comparisonIdentifier: String
    /// Digest of groups, vocabulary construction, and method identities.
    public let comparisonDigest: String
    /// Digest of the target corpus profile.
    public let targetCorpusDigest: String
    /// Digest of the reference corpus profile.
    public let referenceCorpusDigest: String
    /// Canonically ordered target source revisions.
    public let targetSourceRevisionIDs: [SourceRevisionID]
    /// Canonically ordered reference source revisions.
    public let referenceSourceRevisionIDs: [SourceRevisionID]
    /// Distinct normalized terms with non-zero frequency in the target group.
    public let targetTypeCount: Int
    /// Distinct normalized terms with non-zero frequency in the reference group.
    public let referenceTypeCount: Int
    /// Distinct normalized terms present in both groups.
    public let sharedTypeCount: Int
    /// How the two frequency vectors are aligned before the vector measure.
    public let vocabularyIdentifier: String
    /// `Cosine-v1` method identity.
    public let cosineIdentifier: String
    /// `Cosine-v1` value over aligned relative-frequency vectors.
    public let cosineSimilarity: Double
    /// `JaccardSet-v1` method identity.
    public let jaccardIdentifier: String
    /// `JaccardSet-v1` value over the sets of present terms.
    public let jaccardSimilarity: Double
    /// `DiceSet-v1` method identity.
    public let diceIdentifier: String
    /// `DiceSet-v1` value over the sets of present terms.
    public let diceSimilarity: Double
    /// `Euclidean-v1` method identity.
    public let euclideanIdentifier: String
    /// `Euclidean-v1` distance between aligned relative-frequency vectors.
    public let euclideanDistance: Double
    /// `Manhattan-v1` method identity.
    public let manhattanIdentifier: String
    /// `Manhattan-v1` distance between aligned relative-frequency vectors.
    public let manhattanDistance: Double
    /// `Hellinger-v1` method identity.
    public let hellingerIdentifier: String
    /// `Hellinger-v1` distance between the two term distributions.
    public let hellingerDistance: Double
    /// `JSdiv-v1` method identity.
    public let jsDivergenceIdentifier: String
    /// `JSdiv-v1` divergence between the two term distributions.
    public let jsDivergence: Double
    /// `JSdist-v1` method identity.
    public let jsDistanceIdentifier: String
    /// `JSdist-v1` distance between the two term distributions.
    public let jsDistance: Double
    /// `KL-v1` method identity.
    public let klIdentifier: String
    /// `KL-v1(target‖reference)`, `nil` when undefined.
    public let klTargetToReference: Double?
    /// `KL-v1(reference‖target)`, `nil` when undefined.
    public let klReferenceToTarget: Double?
    /// Determinism class for floating-point results.
    public let floatingPointDeterminismClass: String
    /// Versioned numeric precision and ordered-reduction policy.
    public let numericPolicyIdentifier: String
    /// Absolute tolerance applied by the reference seed.
    public let referenceAbsoluteTolerance: Double
    /// `WeightedJaccard-v1` on aligned relative frequencies.
    public let weightedJaccardSimilarity: Double
    /// `MultisetDice-v1` on aligned counts.
    public let multisetDiceSimilarity: Double
    /// Declared smoothing of the smoothed divergences.
    public let smoothingIdentifier: String
    /// Lidstone `α` of the smoothed divergences.
    public let smoothingAlpha: Double
    /// `KL-v1(target‖reference)` after Lidstone smoothing, always defined.
    public let smoothedKLTargetToReference: Double
    /// `KL-v1(reference‖target)` after Lidstone smoothing, always defined.
    public let smoothedKLReferenceToTarget: Double
}

/// Computes bounded corpus-to-corpus similarity from compatible corpus profiles.
public struct GlifiCorpusSimilarityAnalyzer: Sendable {
    /// Versioned identity of this comparison bundle.
    public static let comparisonIdentifier = "corpus-term-similarity-v3"
    /// How the two frequency vectors are aligned: the union of normalized
    /// terms, in canonical ascending order, each corpus contributing its
    /// relative frequency or zero.
    public static let vocabularyIdentifier =
        "corpus-profile-relative-frequency-union-vocabulary-v1"

    /// Creates a stateless corpus-similarity analyzer.
    public init() {}

    /// Compares two corpus profiles built under the same tokenization and
    /// normalization contract.
    ///
    /// Throws when either group has no terms.
    public func compare(
        target: GlifiCorpusAnalysis,
        reference: GlifiCorpusAnalysis
    ) throws -> GlifiCorpusSimilarityComparison {
        try Task.checkCancellation()
        let targetFrequencies = Dictionary(
            uniqueKeysWithValues: target.terms.map { ($0.term, $0.relativeFrequency) }
        )
        let referenceFrequencies = Dictionary(
            uniqueKeysWithValues: reference.terms.map { ($0.term, $0.relativeFrequency) }
        )
        let targetSet = Set(targetFrequencies.keys)
        let referenceSet = Set(referenceFrequencies.keys)
        guard !targetSet.isEmpty, !referenceSet.isEmpty else {
            throw corpusSimilarityFailure(
                "corpus-similarity.empty-group",
                category: .insufficientData
            )
        }

        let vocabulary = targetSet.union(referenceSet).sorted()
        let targetVector = vocabulary.map { targetFrequencies[$0] ?? 0 }
        let referenceVector = vocabulary.map { referenceFrequencies[$0] ?? 0 }
        let cosine = try GlifiVectorSimilarity.cosine(targetVector, referenceVector)
        let jaccard = GlifiSetSimilarity.jaccard(targetSet, referenceSet)
        let dice = GlifiSetSimilarity.dice(targetSet, referenceSet)
        let euclidean = try GlifiVectorSimilarity.euclidean(targetVector, referenceVector)
        let manhattan = try GlifiVectorSimilarity.manhattan(targetVector, referenceVector)
        let hellinger = try GlifiProbabilityDivergence.hellinger(targetVector, referenceVector)
        let jsDivergence = try GlifiProbabilityDivergence.jensenShannonDivergence(
            targetVector,
            referenceVector
        )
        let jsDistance = try GlifiProbabilityDivergence.jensenShannonDistance(
            targetVector,
            referenceVector
        )
        let klForward = try? GlifiProbabilityDivergence.klDivergence(
            targetVector,
            referenceVector
        )
        let klBackward = try? GlifiProbabilityDivergence.klDivergence(
            referenceVector,
            targetVector
        )

        let targetCounts = Dictionary(
            uniqueKeysWithValues: target.terms.map { ($0.term, Double($0.frequency)) })
        let referenceCounts = Dictionary(
            uniqueKeysWithValues: reference.terms.map { ($0.term, Double($0.frequency)) }
        )
        let targetCountVector = vocabulary.map { targetCounts[$0] ?? 0 }
        let referenceCountVector = vocabulary.map { referenceCounts[$0] ?? 0 }
        let smoothedTarget = try GlifiProbabilityDivergence.lidstone(targetCountVector, alpha: 0.5)
        let smoothedReference = try GlifiProbabilityDivergence.lidstone(
            referenceCountVector,
            alpha: 0.5
        )
        return GlifiCorpusSimilarityComparison(
            comparisonIdentifier: Self.comparisonIdentifier,
            comparisonDigest: try comparisonDigest(target: target, reference: reference),
            targetCorpusDigest: target.corpusDigest,
            referenceCorpusDigest: reference.corpusDigest,
            targetSourceRevisionIDs: target.sourceRevisionIDs,
            referenceSourceRevisionIDs: reference.sourceRevisionIDs,
            targetTypeCount: targetSet.count,
            referenceTypeCount: referenceSet.count,
            sharedTypeCount: targetSet.intersection(referenceSet).count,
            vocabularyIdentifier: Self.vocabularyIdentifier,
            cosineIdentifier: GlifiVectorSimilarity.cosineIdentifier,
            cosineSimilarity: cosine,
            jaccardIdentifier: GlifiSetSimilarity.jaccardIdentifier,
            jaccardSimilarity: jaccard,
            diceIdentifier: GlifiSetSimilarity.diceIdentifier,
            diceSimilarity: dice,
            euclideanIdentifier: GlifiVectorSimilarity.euclideanIdentifier,
            euclideanDistance: euclidean,
            manhattanIdentifier: GlifiVectorSimilarity.manhattanIdentifier,
            manhattanDistance: manhattan,
            hellingerIdentifier: GlifiProbabilityDivergence.hellingerIdentifier,
            hellingerDistance: hellinger,
            jsDivergenceIdentifier: GlifiProbabilityDivergence.jsDivergenceIdentifier,
            jsDivergence: jsDivergence,
            jsDistanceIdentifier: GlifiProbabilityDivergence.jsDistanceIdentifier,
            jsDistance: jsDistance,
            klIdentifier: GlifiProbabilityDivergence.klIdentifier,
            klTargetToReference: klForward,
            klReferenceToTarget: klBackward,
            floatingPointDeterminismClass: "D1",
            numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
            referenceAbsoluteTolerance: 1e-9,
            weightedJaccardSimilarity: try GlifiVectorSimilarity.weightedJaccard(
                targetVector,
                referenceVector
            ),
            multisetDiceSimilarity: try GlifiVectorSimilarity.multisetDice(
                targetCountVector,
                referenceCountVector
            ),
            smoothingIdentifier: GlifiProbabilityDivergence.lidstoneIdentifier,
            smoothingAlpha: 0.5,
            smoothedKLTargetToReference: try GlifiProbabilityDivergence.klDivergence(
                smoothedTarget,
                smoothedReference
            ),
            smoothedKLReferenceToTarget: try GlifiProbabilityDivergence.klDivergence(
                smoothedReference,
                smoothedTarget
            )
        )
    }

    private func comparisonDigest(
        target: GlifiCorpusAnalysis,
        reference: GlifiCorpusAnalysis
    ) throws -> String {
        struct DigestInput: Encodable {
            let comparisonIdentifier: String
            let targetCorpusDigest: String
            let referenceCorpusDigest: String
            let vocabularyIdentifier: String
        }
        let value = DigestInput(
            comparisonIdentifier: Self.comparisonIdentifier,
            targetCorpusDigest: target.corpusDigest,
            referenceCorpusDigest: reference.corpusDigest,
            vocabularyIdentifier: Self.vocabularyIdentifier
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let hash = SHA256.hash(data: try encoder.encode(value))
        return "sha256:" + hash.map { String(format: "%02x", $0) }.joined()
    }
}

func corpusSimilarityFailure(
    _ code: String,
    category: GlifiFailureCategory = .invalidInput
) -> GlifiFailure {
    GlifiFailure(
        code: code,
        category: category,
        operation: .analyze,
        retryDisposition: GlifiFailureTaxonomy.defaultRetry(category),
        retainedState: GlifiFailureTaxonomy.defaultRetained(category),
        messageKey: "failure.\(code)"
    )
}
