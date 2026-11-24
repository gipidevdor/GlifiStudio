// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Declared weight of one observation inside a window.
public enum GlifiDistanceWeighting: String, Codable, Equatable, Sendable {
    /// Every observation weighs 1.
    case none
    /// An observation at token distance `d` weighs `1/d`.
    case inverseDistance
}

/// Explicit window definition of a token co-occurrence analysis.
///
/// The window is measured in lexical tokens around each node token. A window with
/// `leftSpan == rightSpan` is symmetric; any other window is directional and yields
/// ordered node→collocate pairs that are semantically distinct.
public struct GlifiWindowCooccurrenceOptions: Codable, Equatable, Sendable {
    /// Largest supported span on each side.
    public static let maximumSpan = 20
    /// Conservative defaults: symmetric window of four tokens, sentence-bounded.
    public static let standard = GlifiWindowCooccurrenceOptions(
        validatedLeftSpan: 4,
        rightSpan: 4,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 2,
        maximumPairCount: 500,
        distanceWeighting: .none,
        maximumPositionsPerPair: 10
    )

    /// Window chosen by `planner-v2`: symmetric ±4, sentence-bounded, every pair kept.
    public static let standardPlanned = GlifiWindowCooccurrenceOptions(
        validatedLeftSpan: 4,
        rightSpan: 4,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 500,
        distanceWeighting: .none,
        maximumPositionsPerPair: 10
    )

    /// Lexical tokens considered before the node token.
    public let leftSpan: Int
    /// Lexical tokens considered after the node token.
    public let rightSpan: Int
    /// Whether the window may extend across sentence boundaries.
    public let crossesSentences: Bool
    /// Whether a term co-occurring with itself is counted.
    public let includesSelfPairs: Bool
    /// Smallest joint count for a pair to be retained.
    public let minimumJointCount: Int
    /// Largest number of pairs stored in the result.
    public let maximumPairCount: Int
    /// Declared weight of each observation, reported as `weightedJointCount`.
    public let distanceWeighting: GlifiDistanceWeighting
    /// Largest number of source positions kept per pair as lineage (0…100).
    public let maximumPositionsPerPair: Int

    /// Whether the window has the same span on both sides.
    public var isSymmetric: Bool { leftSpan == rightSpan }

    /// Creates a valid window without silently correcting parameters.
    public init(
        leftSpan: Int,
        rightSpan: Int,
        crossesSentences: Bool,
        includesSelfPairs: Bool,
        minimumJointCount: Int,
        maximumPairCount: Int,
        distanceWeighting: GlifiDistanceWeighting = .none,
        maximumPositionsPerPair: Int = 10
    ) throws {
        guard (0...Self.maximumSpan).contains(leftSpan),
            (0...100).contains(maximumPositionsPerPair),
            (0...Self.maximumSpan).contains(rightSpan),
            leftSpan + rightSpan >= 1,
            minimumJointCount >= 1,
            (1...5_000).contains(maximumPairCount)
        else {
            throw derivedAnalysisFailure("window-cooccurrence.invalid-options")
        }
        self.init(
            validatedLeftSpan: leftSpan,
            rightSpan: rightSpan,
            crossesSentences: crossesSentences,
            includesSelfPairs: includesSelfPairs,
            minimumJointCount: minimumJointCount,
            maximumPairCount: maximumPairCount,
            distanceWeighting: distanceWeighting,
            maximumPositionsPerPair: maximumPositionsPerPair
        )
    }

    private init(
        validatedLeftSpan: Int,
        rightSpan: Int,
        crossesSentences: Bool,
        includesSelfPairs: Bool,
        minimumJointCount: Int,
        maximumPairCount: Int,
        distanceWeighting: GlifiDistanceWeighting,
        maximumPositionsPerPair: Int
    ) {
        self.distanceWeighting = distanceWeighting
        self.maximumPositionsPerPair = maximumPositionsPerPair
        leftSpan = validatedLeftSpan
        self.rightSpan = rightSpan
        self.crossesSentences = crossesSentences
        self.includesSelfPairs = includesSelfPairs
        self.minimumJointCount = minimumJointCount
        self.maximumPairCount = maximumPairCount
    }

    /// Decodes only valid windows.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            leftSpan: container.decode(Int.self, forKey: .leftSpan),
            rightSpan: container.decode(Int.self, forKey: .rightSpan),
            crossesSentences: container.decode(Bool.self, forKey: .crossesSentences),
            includesSelfPairs: container.decode(Bool.self, forKey: .includesSelfPairs),
            minimumJointCount: container.decode(Int.self, forKey: .minimumJointCount),
            maximumPairCount: container.decode(Int.self, forKey: .maximumPairCount),
            distanceWeighting: container.decodeIfPresent(
                GlifiDistanceWeighting.self,
                forKey: .distanceWeighting
            ) ?? .none,
            maximumPositionsPerPair: container.decodeIfPresent(
                Int.self,
                forKey: .maximumPositionsPerPair
            ) ?? 10
        )
    }

    private enum CodingKeys: String, CodingKey {
        case leftSpan, rightSpan, crossesSentences, includesSelfPairs
        case minimumJointCount, maximumPairCount, distanceWeighting, maximumPositionsPerPair
    }
}

/// One observation of a pair, resolvable to exact source positions.
public struct GlifiWindowOccurrence: Codable, Equatable, Sendable {
    /// Source revision containing the observation.
    public let sourceRevisionID: String
    /// UTF-8 interval of the node token in the extracted text.
    public let nodeRange: GlifiUTF8Range
    /// UTF-8 interval of the collocate token in the extracted text.
    public let collocateRange: GlifiUTF8Range
    /// Signed token offset of the collocate from the node.
    public let offset: Int
}

/// One ordered node→collocate pair with its 2×2 table over the pair universe.
public struct GlifiWindowCollocationPair: Codable, Equatable, Sendable {
    /// Node term whose window is inspected.
    public let nodeTerm: String
    /// Term observed inside the window of the node.
    public let collocateTerm: String
    /// Ordered pairs node→collocate (`a`).
    public let jointCount: Int
    /// Ordered pairs with this node and another collocate (`b`).
    public let nodeOnlyCount: Int
    /// Ordered pairs with another node and this collocate (`c`).
    public let collocateOnlyCount: Int
    /// Ordered pairs with neither (`d`).
    public let neitherCount: Int
    /// `PMI-v1`.
    public let pmi: Double?
    /// `NPMI-v1`.
    public let npmi: Double?
    /// `Dice-v1`.
    public let dice: Double?
    /// `Jaccard-v1`.
    public let jaccard: Double?
    /// `t-score-v1`.
    public let tScore: Double?
    /// `logDice-v1`.
    public let logDice: Double?
    /// Mean absolute token distance of the observations.
    public let meanDistance: Double
    /// Sum of observation weights under the declared distance weighting.
    public let weightedJointCount: Double
    /// First observations in source order, bounded by `maximumPositionsPerPair`.
    public let occurrences: [GlifiWindowOccurrence]
    /// Whether more observations exist than the stored occurrences.
    public let occurrencesTruncated: Bool
}

/// Window-based collocation measures over the tokens of a group of sources.
public struct GlifiWindowCollocationAnalysis: GlifiDerivedAnalysisResult {
    /// Stable artifact payload schema.
    public static let outputSchemaIdentifier = "studio.glifi.artifact.window-collocation.v2"
    /// Versioned identity of this analysis bundle.
    public static let analysisIdentifier = "corpus-window-collocation-v2"
    /// Bound on distinct node→collocate pairs held in memory.
    public static let maximumDistinctPairCount = 1_000_000

    /// Method identity serialized with the result.
    public let analysisIdentifier: String
    /// Tokenization contract that produced the token sequences.
    public let tokenizationContractIdentifier: String
    /// Canonically ordered analyzed documents.
    public let sourceRevisionIDs: [String]
    /// Context definition: window of lexical tokens inside one document.
    public let contextIdentifier: String
    /// Definition of the opportunities `M` counted by the 2×2 tables.
    public let universeIdentifier: String
    /// Window and thresholds applied.
    public let options: GlifiWindowCooccurrenceOptions
    /// Lexical tokens across all analyzed documents.
    public let tokenCount: Int
    /// Ordered node→collocate observations `M`.
    public let universeSize: Int
    /// Distinct ordered pairs observed before thresholds and symmetry folding.
    public let distinctPairCount: Int
    /// Whether retained pairs exceeded `options.maximumPairCount`.
    public let isTruncated: Bool
    /// Retained pairs ordered by joint count, then `logDice-v1`, then terms.
    public let pairs: [GlifiWindowCollocationPair]
}

/// Computes window-based collocations from imported sources.
public struct GlifiWindowCollocationAnalyzer: Sendable {
    private let tokenizer: any GlifiTokenizing

    /// Creates an analyzer with an injectable versioned linguistic service.
    public init(tokenizer: any GlifiTokenizing = GlifiItalianTokenizer()) {
        self.tokenizer = tokenizer
    }

    /// Analyzes the term pairs that co-occur inside the declared window.
    public func analyze(
        _ sources: [GlifiImportedText],
        options: GlifiWindowCooccurrenceOptions = .standard
    ) throws -> GlifiWindowCollocationAnalysis {
        guard !sources.isEmpty else {
            throw derivedAnalysisFailure(
                "window-cooccurrence.insufficient-sources",
                category: .insufficientData
            )
        }
        let ordered = sources.sorted {
            $0.sourceRevisionID.canonicalValue < $1.sourceRevisionID.canonicalValue
        }
        var contract: String?
        var sequences: [Sequence] = []
        for source in ordered {
            try Task.checkCancellation()
            let tokenization = try tokenizer.tokenize(source.text)
            if let expected = contract {
                guard tokenization.contractIdentifier == expected else {
                    throw derivedAnalysisFailure(
                        "window-cooccurrence.mixed-tokenization-contracts",
                        category: .invariantViolation
                    )
                }
            } else {
                contract = tokenization.contractIdentifier
            }
            sequences.append(
                Self.sequence(
                    of: source.text,
                    tokenization,
                    sourceRevisionID: source.sourceRevisionID.canonicalValue
                )
            )
        }
        let tally = try count(sequences, options: options)
        guard tally.universe > 0 else {
            throw derivedAnalysisFailure(
                "window-cooccurrence.no-pairs",
                category: .insufficientData
            )
        }
        var rows = try pairs(from: tally, options: options)
        rows.sort {
            if $0.jointCount != $1.jointCount { return $0.jointCount > $1.jointCount }
            let left = $0.logDice ?? -.infinity
            let right = $1.logDice ?? -.infinity
            if left != right { return left > right }
            if $0.nodeTerm != $1.nodeTerm { return $0.nodeTerm < $1.nodeTerm }
            return $0.collocateTerm < $1.collocateTerm
        }
        return GlifiWindowCollocationAnalysis(
            analysisIdentifier: GlifiWindowCollocationAnalysis.analysisIdentifier,
            tokenizationContractIdentifier: contract ?? "unavailable",
            sourceRevisionIDs: ordered.map(\.sourceRevisionID.canonicalValue),
            contextIdentifier: "token-window-within-document-v1",
            universeIdentifier: "ordered-node-collocate-pairs-v1",
            options: options,
            tokenCount: sequences.reduce(0) { $0 + $1.terms.count },
            universeSize: tally.universe,
            distinctPairCount: tally.joint.count,
            isTruncated: rows.count > options.maximumPairCount,
            pairs: Array(rows.prefix(options.maximumPairCount))
        )
    }

    /// Lexical terms of one document with their sentence indexes.
    struct Sequence {
        var terms: [String]
        var sentenceIndexes: [Int]
        var ranges: [GlifiUTF8Range]
        var sourceRevisionID: String
    }

    struct Tally {
        var joint: [PairKey: Int] = [:]
        var distanceTotals: [PairKey: Int] = [:]
        var weighted: [PairKey: Double] = [:]
        var occurrences: [PairKey: [GlifiWindowOccurrence]] = [:]
        var nodeTotals: [String: Int] = [:]
        var collocateTotals: [String: Int] = [:]
        var universe = 0
    }

    struct PairKey: Hashable {
        let node: String
        let collocate: String
    }

    /// Normalizes lexical tokens exactly as the corpus profile does and
    /// assigns each token to the sentence that contains it.
    static func sequence(
        of text: String,
        _ tokenization: GlifiTokenization,
        sourceRevisionID: String = ""
    ) -> Sequence {
        let locale = Locale(identifier: "it_IT")
        var terms: [String] = []
        var sentenceIndexes: [Int] = []
        var ranges: [GlifiUTF8Range] = []
        var sentence = 0
        for token in tokenization.tokens {
            guard token.kind.contributesToLexicalStatistics,
                let surface = token.range.text(in: text)
            else {
                continue
            }
            while sentence < tokenization.sentences.count - 1,
                tokenization.sentences[sentence].range.end <= token.range.start
            {
                sentence += 1
            }
            terms.append(surface.precomposedStringWithCanonicalMapping.lowercased(with: locale))
            sentenceIndexes.append(sentence)
            ranges.append(token.range)
        }
        return Sequence(
            terms: terms,
            sentenceIndexes: sentenceIndexes,
            ranges: ranges,
            sourceRevisionID: sourceRevisionID
        )
    }

    private func count(
        _ sequences: [Sequence],
        options: GlifiWindowCooccurrenceOptions
    ) throws -> Tally {
        var tally = Tally()
        for sequence in sequences {
            let terms = sequence.terms
            for node in terms.indices {
                if node.isMultiple(of: 4_096) { try Task.checkCancellation() }
                let lower = max(0, node - options.leftSpan)
                let upper = min(terms.count - 1, node + options.rightSpan)
                guard lower <= upper else { continue }
                for other in lower...upper where other != node {
                    if !options.crossesSentences,
                        sequence.sentenceIndexes[node] != sequence.sentenceIndexes[other]
                    {
                        continue
                    }
                    if !options.includesSelfPairs, terms[node] == terms[other] { continue }
                    let key = PairKey(node: terms[node], collocate: terms[other])
                    if tally.joint[key] == nil,
                        tally.joint.count >= GlifiWindowCollocationAnalysis.maximumDistinctPairCount
                    {
                        throw derivedAnalysisFailure("window-cooccurrence.pair-limit-exceeded")
                    }
                    tally.joint[key, default: 0] += 1
                    let distance = abs(other - node)
                    tally.distanceTotals[key, default: 0] += distance
                    tally.weighted[key, default: 0] +=
                        options.distanceWeighting == .inverseDistance ? 1 / Double(distance) : 1
                    if tally.occurrences[key, default: []].count < options.maximumPositionsPerPair {
                        tally.occurrences[key, default: []].append(
                            GlifiWindowOccurrence(
                                sourceRevisionID: sequence.sourceRevisionID,
                                nodeRange: sequence.ranges[node],
                                collocateRange: sequence.ranges[other],
                                offset: other - node
                            )
                        )
                    }
                    tally.nodeTotals[key.node, default: 0] += 1
                    tally.collocateTotals[key.collocate, default: 0] += 1
                    tally.universe += 1
                }
            }
        }
        return tally
    }

    private func pairs(
        from tally: Tally,
        options: GlifiWindowCooccurrenceOptions
    ) throws -> [GlifiWindowCollocationPair] {
        var rows: [GlifiWindowCollocationPair] = []
        for (key, joint) in tally.joint {
            guard joint >= options.minimumJointCount else { continue }
            // A symmetric window counts every pair in both orders: keep one of them.
            if options.isSymmetric, key.node > key.collocate { continue }
            let nodeTotal = tally.nodeTotals[key.node] ?? 0
            let collocateTotal = tally.collocateTotals[key.collocate] ?? 0
            let counts = try GlifiCooccurrenceCounts(
                jointCount: joint,
                firstOnlyCount: nodeTotal - joint,
                secondOnlyCount: collocateTotal - joint,
                neitherCount: tally.universe - nodeTotal - collocateTotal + joint
            )
            let measures = GlifiCollocationAnalysis.measures(counts)
            rows.append(
                GlifiWindowCollocationPair(
                    nodeTerm: key.node,
                    collocateTerm: key.collocate,
                    jointCount: joint,
                    nodeOnlyCount: counts.firstOnlyCount,
                    collocateOnlyCount: counts.secondOnlyCount,
                    neitherCount: counts.neitherCount,
                    pmi: measures.pmi,
                    npmi: measures.npmi,
                    dice: measures.dice,
                    jaccard: measures.jaccard,
                    tScore: measures.tScore,
                    logDice: measures.logDice,
                    meanDistance: Double(tally.distanceTotals[key] ?? 0) / Double(joint),
                    weightedJointCount: tally.weighted[key] ?? 0,
                    occurrences: tally.occurrences[key] ?? [],
                    occurrencesTruncated: joint > (tally.occurrences[key]?.count ?? 0)
                )
            )
        }
        return rows
    }
}
