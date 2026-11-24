// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// Closed catalog of project operations shared by native and command-line JSON clients.
public enum GlifiStudioProjectOperation: String, Codable, CaseIterable, Sendable {
    case corpus, keyness, similarity, association, dispersion
    case groupMetric = "group-metric"
    case postHoc = "posthoc"
    case collocations, correlate, paired, multivariate, weighting, diversity, laws, summarize
    case ngrams, bm25
    case windowCollocations = "window-collocations"
    case windowNetwork = "window-network"
    case network
    case sourceText = "source-text"
    case passages
    case characterCount = "character-count"
    case exportVisualization = "export-visualization"
    case prepareInput = "prepare-input"
    case temporal
}

/// Versioned project requests that preserve every public analytical session parameter.
///
/// The project is supplied by the owner of the session; request JSON cannot select another
/// project. Export destinations remain explicit, and the existing export refuses overwrites.
public enum GlifiStudioProjectCommand {
    /// Transport schema, independent from the persistent project format.
    public static let schema = "studio.glifi.project-command-request"
    /// Current request schema version.
    public static let schemaVersion = 1

    /// Decodes one bounded request and calls the same session API used by native clients.
    @concurrent public static func execute(
        json: Data, session: GlifiStudioProjectSession
    ) async throws(GlifiStudioFailure) -> GlifiStudioCommandResult {
        do {
            try Task.checkCancellation()
            let header = try CommandJSON.decode(ProjectCommandHeader.self, from: json)
            guard header.schema == schema else { throw commandFailure("invalid-schema") }
            guard header.schemaVersion == schemaVersion else {
                throw commandFailure("incompatible-version", category: "incompatibleVersion")
            }
            switch header.operation {
            case .corpus:
                let p = try parameters(ProjectCorpusParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeCorpus(options: p.corpusOptions?.value ?? .standard))
            case .keyness:
                let p = try parameters(ProjectKeynessParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.compareKeyness(
                        targetSourceRevisionIDs: p.targetSourceRevisionIDs,
                        referenceSourceRevisionIDs: p.referenceSourceRevisionIDs,
                        corpusOptions: p.corpusOptions?.value ?? .standard,
                        keynessOptions: p.keynessOptions?.value ?? .standard))
            case .similarity:
                let p = try parameters(ProjectComparisonParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.compareSimilarity(
                        targetSourceRevisionIDs: p.targetSourceRevisionIDs,
                        referenceSourceRevisionIDs: p.referenceSourceRevisionIDs,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .association:
                let p = try parameters(ProjectSourcesParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeAssociation(
                        sourceRevisionIDs: p.sourceRevisionIDs,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .dispersion:
                let p = try parameters(ProjectDispersionParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeDispersion(
                        sourceRevisionIDs: p.sourceRevisionIDs, partition: p.partition,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .groupMetric:
                let p = try parameters(ProjectGroupParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.compareGroupMetric(
                        groups: p.groups, metric: p.metric,
                        options: p.options ?? .standard,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .postHoc:
                let p = try parameters(ProjectPostHocParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.postHocGroupMetric(
                        groups: p.groups, metric: p.metric,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .collocations:
                let p = try parameters(ProjectCooccurrenceParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeCollocations(
                        sourceRevisionIDs: p.sourceRevisionIDs, options: p.options ?? .standard,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .correlate:
                let p = try parameters(ProjectMetricsParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.correlateMetrics(
                        sourceRevisionIDs: p.sourceRevisionIDs,
                        first: p.first, second: p.second,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .paired:
                let p = try parameters(ProjectMetricsParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.comparePairedMetrics(
                        sourceRevisionIDs: p.sourceRevisionIDs,
                        first: p.first, second: p.second,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .multivariate:
                let p = try parameters(ProjectMultivariateParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeMultivariate(
                        sourceRevisionIDs: p.sourceRevisionIDs, method: p.method,
                        maximumTermCount: p.maximumTermCount ?? 50,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .weighting:
                let p = try parameters(ProjectWeightingParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeTermWeighting(
                        sourceRevisionIDs: p.sourceRevisionIDs, scheme: p.scheme,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .diversity:
                let p = try parameters(ProjectDiversityParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeLexicalDiversity(
                        sourceRevisionIDs: p.sourceRevisionIDs, threshold: p.threshold ?? 0.72,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .laws:
                let p = try parameters(ProjectLawsParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeLexicalLaws(
                        sourceRevisionIDs: p.sourceRevisionIDs,
                        parameters: p.parameters ?? .standard,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .summarize:
                let p = try parameters(ProjectSummaryParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeExtractiveSummary(
                        sourceRevisionIDs: p.sourceRevisionIDs, budget: p.budget ?? .standard,
                        scheme: p.scheme ?? .summaryStandard, method: p.method ?? .standard,
                        redundancy: p.redundancy ?? .standard,
                        graphConfiguration: p.graphConfiguration,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .ngrams:
                let p = try parameters(ProjectNGramParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeNGramFrequencies(
                        sourceRevisionIDs: p.sourceRevisionIDs, unit: p.unit,
                        filter: p.filter ?? .none, maximumRowCount: p.maximumRowCount ?? 1_000,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .bm25:
                let p = try parameters(ProjectBM25Parameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.rankDocumentsBM25(
                        sourceRevisionIDs: p.sourceRevisionIDs, query: p.query,
                        k1: p.k1 ?? 1.2, b: p.b ?? 0.75,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .windowCollocations:
                let p = try parameters(ProjectWindowParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeWindowCollocations(
                        sourceRevisionIDs: p.sourceRevisionIDs, options: p.options ?? .standard,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .windowNetwork:
                let p = try parameters(ProjectWindowNetworkParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeWindowNetwork(
                        sourceRevisionIDs: p.sourceRevisionIDs, window: p.window ?? .standard,
                        minimumLogDice: p.minimumLogDice,
                        usesWeightedJointCount: p.usesWeightedJointCount ?? false,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .network:
                let p = try parameters(ProjectCooccurrenceParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.analyzeLexicalNetwork(
                        sourceRevisionIDs: p.sourceRevisionIDs, options: p.options ?? .standard,
                        corpusOptions: p.corpusOptions?.value ?? .standard))
            case .sourceText:
                let p = try parameters(ProjectSourceParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.sourceText(sourceRevisionID: p.sourceRevisionID))
            case .passages:
                let p = try parameters(ProjectPassageParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.passages(
                        sourceRevisionID: p.sourceRevisionID, selections: p.selections))
            case .characterCount:
                let p = try parameters(ProjectSourceParameters.self, json)
                return try await GlifiStudioCommandResult(
                    session.extractedCharacterCount(sourceRevisionID: p.sourceRevisionID))
            case .exportVisualization:
                let p = try parameters(ProjectVisualExportParameters.self, json)
                guard !p.destinationPath.isEmpty else {
                    throw commandFailure("invalid-destination")
                }
                return try await GlifiStudioCommandResult(
                    session.exportVisualization(
                        p.visualization, to: URL(fileURLWithPath: p.destinationPath)))
            case .prepareInput:
                let p = try parameters(ProjectInputParameters.self, json)
                return try await GlifiStudioCommandResult(
                    GlifiStudioTextAnalytics.prepareProjectInput(
                        session: session, sourceRevisionIDs: p.sourceRevisionIDs,
                        maximumTermCount: p.maximumTermCount ?? 200,
                        allowsEmptyLexicon: p.allowsEmptyLexicon ?? false))
            case .temporal:
                let p = try parameters(ProjectTemporalParameters.self, json)
                return try await GlifiStudioCommandResult(
                    GlifiStudioEvaluationWorkbench.temporal(
                        session: session, assignments: p.assignments.map(\.valueForEvaluation),
                        terms: p.terms,
                        configuration: p.configuration))
            }
        } catch let failure as GlifiStudioFailure {
            throw failure
        } catch is CancellationError {
            throw commandFailure("cancelled", category: "cancelled")
        } catch {
            throw commandFailure("invalid-request")
        }
    }

    private static func parameters<Value: Codable>(
        _ type: Value.Type, _ json: Data
    ) throws(GlifiStudioFailure) -> Value {
        try CommandJSON.decodeStrict(ProjectCommandEnvelope<Value>.self, from: json).parameters
    }
}

private struct ProjectCommandHeader: Decodable {
    let schema: String
    let schemaVersion: Int
    let operation: GlifiStudioProjectOperation
}

private struct ProjectCommandEnvelope<Parameters: Codable>: Codable {
    let schema: String
    let schemaVersion: Int
    let operation: GlifiStudioProjectOperation
    let parameters: Parameters
}

/// Wire options use the existing validating initializer and preserve omitted native defaults.
private struct ProjectCorpusOptions: Codable {
    let diversityWindowSize: Int?
    let ngramSizes: [Int]?
    let maximumDocumentCount: Int?
    let maximumSourceByteCount: Int?
    let maximumVocabularySize: Int?
    let maximumDistinctNGramCount: Int?
    let maximumNonZeroCellCount: Int?

    var value: GlifiStudioCorpusAnalysisOptions {
        get throws {
            let defaults = GlifiStudioCorpusAnalysisOptions.standard
            return try GlifiStudioCorpusAnalysisOptions(
                diversityWindowSize: diversityWindowSize ?? defaults.diversityWindowSize,
                ngramSizes: ngramSizes ?? defaults.ngramSizes,
                maximumDocumentCount: maximumDocumentCount ?? defaults.maximumDocumentCount,
                maximumSourceByteCount: maximumSourceByteCount ?? defaults.maximumSourceByteCount,
                maximumVocabularySize: maximumVocabularySize ?? defaults.maximumVocabularySize,
                maximumDistinctNGramCount:
                    maximumDistinctNGramCount ?? defaults.maximumDistinctNGramCount,
                maximumNonZeroCellCount: maximumNonZeroCellCount ?? defaults.maximumNonZeroCellCount
            )
        }
    }
}

private struct ProjectKeynessOptions: Codable {
    let maximumHypothesisCount: Int?
    let lowExpectedCountThreshold: Double?
    let confidenceLevel: Double?

    var value: GlifiStudioKeynessOptions {
        get throws {
            let defaults = GlifiStudioKeynessOptions.standard
            return try GlifiStudioKeynessOptions(
                maximumHypothesisCount: maximumHypothesisCount ?? defaults.maximumHypothesisCount,
                lowExpectedCountThreshold:
                    lowExpectedCountThreshold ?? defaults.lowExpectedCountThreshold,
                confidenceLevel: confidenceLevel ?? defaults.confidenceLevel)
        }
    }
}

private struct ProjectCorpusParameters: Codable {
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectSourcesParameters: Codable {
    let sourceRevisionIDs: [String]
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectComparisonParameters: Codable {
    let targetSourceRevisionIDs: [String]
    let referenceSourceRevisionIDs: [String]
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectKeynessParameters: Codable {
    let targetSourceRevisionIDs: [String]
    let referenceSourceRevisionIDs: [String]
    let corpusOptions: ProjectCorpusOptions?
    let keynessOptions: ProjectKeynessOptions?
}

private struct ProjectDispersionParameters: Codable {
    let sourceRevisionIDs: [String]
    let partition: [[String]]?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectGroupParameters: Codable {
    let groups: [[String]]
    let metric: GlifiStudioDocumentMetric
    let options: GlifiStudioGroupComparisonOptions?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectPostHocParameters: Codable {
    let groups: [[String]]
    let metric: GlifiStudioDocumentMetric
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectCooccurrenceParameters: Codable {
    let sourceRevisionIDs: [String]
    let options: GlifiStudioCooccurrenceOptions?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectMetricsParameters: Codable {
    let sourceRevisionIDs: [String]
    let first: GlifiStudioDocumentMetric
    let second: GlifiStudioDocumentMetric
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectMultivariateParameters: Codable {
    let sourceRevisionIDs: [String]
    let method: GlifiStudioMultivariateMethod
    let maximumTermCount: Int?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectWeightingParameters: Codable {
    let sourceRevisionIDs: [String]
    let scheme: GlifiStudioTermWeightingScheme
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectDiversityParameters: Codable {
    let sourceRevisionIDs: [String]
    let threshold: Double?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectLawsParameters: Codable {
    let sourceRevisionIDs: [String]
    let parameters: GlifiStudioLexicalLawsParameters?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectSummaryParameters: Codable {
    let sourceRevisionIDs: [String]
    let budget: GlifiStudioSummaryBudget?
    let scheme: GlifiStudioTermWeightingScheme?
    let method: GlifiStudioSummaryScoringMethod?
    let redundancy: GlifiStudioSummaryRedundancy?
    let graphConfiguration: GlifiStudioSummaryGraphConfiguration?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectNGramParameters: Codable {
    let sourceRevisionIDs: [String]
    let unit: GlifiStudioNGramUnit
    let filter: GlifiStudioTermFilter?
    let maximumRowCount: Int?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectBM25Parameters: Codable {
    let sourceRevisionIDs: [String]
    let query: String
    let k1: Double?
    let b: Double?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectWindowParameters: Codable {
    let sourceRevisionIDs: [String]
    let options: GlifiStudioWindowCooccurrenceOptions?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectWindowNetworkParameters: Codable {
    let sourceRevisionIDs: [String]
    let window: GlifiStudioWindowCooccurrenceOptions?
    let minimumLogDice: Double?
    let usesWeightedJointCount: Bool?
    let corpusOptions: ProjectCorpusOptions?
}

private struct ProjectSourceParameters: Codable {
    let sourceRevisionID: String
}

private struct ProjectPassageParameters: Codable {
    let sourceRevisionID: String
    let selections: [GlifiStudioPassageSelection]
}

private struct ProjectVisualExportParameters: Codable {
    let visualization: GlifiStudioVisualization
    let destinationPath: String
}

private struct ProjectInputParameters: Codable {
    let sourceRevisionIDs: [String]
    let maximumTermCount: Int?
    let allowsEmptyLexicon: Bool?
}

private struct ProjectTemporalParameters: Codable {
    let assignments: [ProjectTemporalAssignment]
    let terms: [String]
    let configuration: GlifiStudioTemporalConfiguration
}

private struct ProjectTemporalAssignment: Codable {
    let sourceRevisionID: String
    let value: GlifiStudioTemporalValue
    let provenance: String

    var valueForEvaluation: GlifiStudioTemporalAssignment {
        .init(sourceRevisionID: sourceRevisionID, value: value, provenance: provenance)
    }
}

private enum ProjectMetric: Codable {
    case lexicalTokenCount
    case termRelativeFrequency(String)

    var value: GlifiStudioDocumentMetric {
        switch self {
        case .lexicalTokenCount: .lexicalTokenCount
        case let .termRelativeFrequency(term): .termRelativeFrequency(term)
        }
    }
}

private enum ProjectMultivariateMethod: Codable {
    case correspondence
    case principalComponents(scaled: Bool)
    case latentSemantic(rank: Int)
    case nonNegativeFactorization(rank: Int, seed: UInt64, restarts: Int)
    case hierarchical(linkage: String, clusterCount: Int)
    case kMeans(clusterCount: Int, seed: UInt64, restarts: Int)

    var value: GlifiStudioMultivariateMethod {
        switch self {
        case .correspondence: .correspondence
        case let .principalComponents(scaled): .principalComponents(scaled: scaled)
        case let .latentSemantic(rank): .latentSemantic(rank: rank)
        case let .nonNegativeFactorization(rank, seed, restarts):
            .nonNegativeFactorization(rank: rank, seed: seed, restarts: restarts)
        case let .hierarchical(linkage, clusterCount):
            .hierarchical(linkage: linkage, clusterCount: clusterCount)
        case let .kMeans(clusterCount, seed, restarts):
            .kMeans(clusterCount: clusterCount, seed: seed, restarts: restarts)
        }
    }
}

extension GlifiStudioDocumentMetric: Codable {
    /// Decodes the complete metric identity, preserving an explicitly supplied lexical key.
    public init(from decoder: any Decoder) throws {
        self = try ProjectMetric(from: decoder).value
    }

    /// Encodes each metric variant; additions to the public enum require a transport mapping.
    public func encode(to encoder: any Encoder) throws {
        let wire: ProjectMetric
        switch self {
        case .lexicalTokenCount: wire = .lexicalTokenCount
        case let .termRelativeFrequency(term): wire = .termRelativeFrequency(term)
        }
        try wire.encode(to: encoder)
    }
}

extension GlifiStudioMultivariateMethod: Codable {
    /// Decodes all method parameters through the same typed choices used by native callers.
    public init(from decoder: any Decoder) throws {
        self = try ProjectMultivariateMethod(from: decoder).value
    }

    /// Encodes every variant without replacing explicit seeds or method parameters.
    public func encode(to encoder: any Encoder) throws {
        let wire: ProjectMultivariateMethod
        switch self {
        case .correspondence: wire = .correspondence
        case let .principalComponents(scaled): wire = .principalComponents(scaled: scaled)
        case let .latentSemantic(rank): wire = .latentSemantic(rank: rank)
        case let .nonNegativeFactorization(rank, seed, restarts):
            wire = .nonNegativeFactorization(rank: rank, seed: seed, restarts: restarts)
        case let .hierarchical(linkage, clusterCount):
            wire = .hierarchical(linkage: linkage, clusterCount: clusterCount)
        case let .kMeans(clusterCount, seed, restarts):
            wire = .kMeans(clusterCount: clusterCount, seed: seed, restarts: restarts)
        }
        try wire.encode(to: encoder)
    }
}

extension GlifiStudioSourceText: Encodable {
    private enum CodingKeys: String, CodingKey { case sourceRevisionID, text, byteCount, document }

    /// Encodes the original immutable source text and its exact UTF-8 byte count.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceRevisionID, forKey: .sourceRevisionID)
        try container.encode(text, forKey: .text)
        try container.encode(byteCount, forKey: .byteCount)
        try container.encodeIfPresent(document, forKey: .document)
    }
}

extension GlifiStudioProjectTextAnalysisInput: Encodable {
    private enum CodingKeys: String, CodingKey {
        case projectID, generation, sourceRevisionIDs, contentDigests, documents, codingUnits
        case terms, vocabularySize, matrix, lexicalTokenCount
    }

    /// Encodes every frozen project input without regenerating tokens or matrix cells.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(generation, forKey: .generation)
        try container.encode(sourceRevisionIDs, forKey: .sourceRevisionIDs)
        try container.encode(contentDigests, forKey: .contentDigests)
        try container.encode(documents, forKey: .documents)
        try container.encode(codingUnits, forKey: .codingUnits)
        try container.encode(terms, forKey: .terms)
        try container.encode(vocabularySize, forKey: .vocabularySize)
        try container.encode(matrix, forKey: .matrix)
        try container.encode(lexicalTokenCount, forKey: .lexicalTokenCount)
    }
}

extension GlifiStudioProjectTemporalEvaluation: Encodable {
    private enum CodingKeys: String, CodingKey {
        case projectID, generation, documents, contentDigests, selectedTerms, result
    }

    /// Encodes the calendar result together with its exact source and annotation snapshot.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(generation, forKey: .generation)
        try container.encode(documents, forKey: .documents)
        try container.encode(contentDigests, forKey: .contentDigests)
        try container.encode(selectedTerms, forKey: .selectedTerms)
        try container.encode(result, forKey: .result)
    }
}
