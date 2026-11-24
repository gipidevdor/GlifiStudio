// SPDX-License-Identifier: BSD-3-Clause

import GlifiCore

/// Presentation-independent corpus-similarity comparison for one project generation.
public struct GlifiStudioCorpusSimilarityResult: Codable, Equatable, Sendable {
    /// Stable project identity.
    public let projectID: String
    /// Exact source generation captured before comparison.
    public let sourceGeneration: Int
    /// Authoritative generation that reaches the Artifact.
    public let generation: Int
    /// Immutable persisted Artifact identity.
    public let artifactID: String
    /// Semantic producer identity.
    public let analysisNodeID: String
    /// Versioned aggregate comparison contract.
    public let comparisonIdentifier: String
    /// Digest of both populations and method identities.
    public let comparisonDigest: String
    /// Digest of the target population profile.
    public let targetCorpusDigest: String
    /// Digest of the reference population profile.
    public let referenceCorpusDigest: String
    /// Canonically ordered target source revisions.
    public let targetSourceRevisionIDs: [String]
    /// Canonically ordered reference source revisions.
    public let referenceSourceRevisionIDs: [String]
    /// Distinct normalized terms with non-zero frequency in the target group.
    public let targetTypeCount: Int
    /// Distinct normalized terms with non-zero frequency in the reference group.
    public let referenceTypeCount: Int
    /// Distinct normalized terms present in both groups.
    public let sharedTypeCount: Int
    /// How the two frequency vectors are aligned.
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
    /// Determinism class of floating-point results.
    public let floatingPointDeterminismClass: String
    /// Versioned numeric policy.
    public let numericPolicyIdentifier: String
    /// Absolute tolerance applied by the reference seed.
    public let referenceAbsoluteTolerance: Double
    /// `WeightedJaccard-v1`.
    public let weightedJaccardSimilarity: Double
    /// `MultisetDice-v1`.
    public let multisetDiceSimilarity: Double
    /// Declared smoothing identity.
    public let smoothingIdentifier: String
    /// Lidstone `α`.
    public let smoothingAlpha: Double
    /// Smoothed `KL(target‖reference)`.
    public let smoothedKLTargetToReference: Double
    /// Smoothed `KL(reference‖target)`.
    public let smoothedKLReferenceToTarget: Double

    init(_ result: GlifiProjectSimilarityResult) {
        let comparison = result.comparison
        projectID = result.projectID.canonicalValue
        sourceGeneration = result.sourceGeneration
        generation = result.generation
        artifactID = result.artifactID.canonicalValue
        analysisNodeID = result.analysisNodeID.canonicalValue
        comparisonIdentifier = comparison.comparisonIdentifier
        comparisonDigest = comparison.comparisonDigest
        targetCorpusDigest = comparison.targetCorpusDigest
        referenceCorpusDigest = comparison.referenceCorpusDigest
        targetSourceRevisionIDs = comparison.targetSourceRevisionIDs.map(\.canonicalValue)
        referenceSourceRevisionIDs = comparison.referenceSourceRevisionIDs.map(\.canonicalValue)
        targetTypeCount = comparison.targetTypeCount
        referenceTypeCount = comparison.referenceTypeCount
        sharedTypeCount = comparison.sharedTypeCount
        vocabularyIdentifier = comparison.vocabularyIdentifier
        cosineIdentifier = comparison.cosineIdentifier
        cosineSimilarity = comparison.cosineSimilarity
        jaccardIdentifier = comparison.jaccardIdentifier
        jaccardSimilarity = comparison.jaccardSimilarity
        diceIdentifier = comparison.diceIdentifier
        diceSimilarity = comparison.diceSimilarity
        euclideanIdentifier = comparison.euclideanIdentifier
        euclideanDistance = comparison.euclideanDistance
        manhattanIdentifier = comparison.manhattanIdentifier
        manhattanDistance = comparison.manhattanDistance
        hellingerIdentifier = comparison.hellingerIdentifier
        hellingerDistance = comparison.hellingerDistance
        jsDivergenceIdentifier = comparison.jsDivergenceIdentifier
        jsDivergence = comparison.jsDivergence
        jsDistanceIdentifier = comparison.jsDistanceIdentifier
        jsDistance = comparison.jsDistance
        klIdentifier = comparison.klIdentifier
        klTargetToReference = comparison.klTargetToReference
        klReferenceToTarget = comparison.klReferenceToTarget
        floatingPointDeterminismClass = comparison.floatingPointDeterminismClass
        numericPolicyIdentifier = comparison.numericPolicyIdentifier
        referenceAbsoluteTolerance = comparison.referenceAbsoluteTolerance
        weightedJaccardSimilarity = comparison.weightedJaccardSimilarity
        multisetDiceSimilarity = comparison.multisetDiceSimilarity
        smoothingIdentifier = comparison.smoothingIdentifier
        smoothingAlpha = comparison.smoothingAlpha
        smoothedKLTargetToReference = comparison.smoothedKLTargetToReference
        smoothedKLReferenceToTarget = comparison.smoothedKLReferenceToTarget
    }
}
