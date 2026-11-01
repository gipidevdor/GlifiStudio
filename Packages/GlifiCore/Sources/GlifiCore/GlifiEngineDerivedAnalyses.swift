// SPDX-License-Identifier: BSD-3-Clause

import Foundation

extension GlifiEngine {
    /// Analyzes the document × term association of a group of at least two sources.
    public func analyzeAssociation(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusAssociationAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 2,
                code: "association",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusAssociationAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-association",
                domain: "association-group.v1",
                unit: "document-term-cell.v1",
                representation: "document-term-contingency-table-v1",
                parameters: [:],
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusAssociationAnalyzer().analyze(group.analysis)
            }
        }
    }

    /// Computes per-term dispersion over the documents of a group of at least two sources.
    public func analyzeDispersion(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        partition: [[SourceRevisionID]]? = nil,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusDispersionAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 2,
                code: "dispersion",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusDispersionAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-dispersion",
                domain: "dispersion-group.v1",
                unit: "normalized-term.v1",
                representation: "document-partition-dispersion-table-v1",
                parameters: partition.map { parts in
                    [
                        "partition": .list(
                            parts.map { .list($0.map { .text($0.canonicalValue) }) }
                        )
                    ]
                } ?? [:],
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusDispersionAnalyzer().analyze(
                    group.analysis,
                    partition: partition?.map { $0.map(\.canonicalValue) }
                )
            }
        }
    }

    /// Compares one document metric across at least two disjoint groups of sources.
    public func compareGroupMetric(
        in project: GlifiProjectPackage,
        groups sourceGroups: [[SourceRevisionID]],
        metric: GlifiDocumentMetric,
        options: GlifiGroupComparisonOptions = .standard,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiGroupMetricComparison> {
        try await guardedDerived {
            try Task.checkCancellation()
            guard sourceGroups.count >= 2 else {
                throw derivedAnalysisFailure(
                    "group-comparison.insufficient-groups",
                    category: .insufficientData
                )
            }
            let flattened = sourceGroups.flatMap { $0 }
            guard Set(flattened).count == flattened.count else {
                throw derivedAnalysisFailure("group-comparison.overlapping-groups")
            }
            let snapshot = await project.snapshot()
            var groups: [DerivedCorpusGroup] = []
            for sourceGroup in sourceGroups {
                groups.append(
                    try await derivedCorpusGroup(
                        sourceGroup,
                        minimumCount: 1,
                        code: "group-comparison",
                        snapshot: snapshot,
                        options: corpusOptions,
                        in: project
                    )
                )
            }
            var parameters: [String: GlifiAnalysisValue] = [
                "metricIdentifier": .text(metric.identifier)
            ]
            if case let .termRelativeFrequency(term) = metric {
                parameters["term"] = .text(term)
            }
            parameters["confidenceLevel"] = .decimal(options.confidenceLevel)
            parameters["bootstrapResampleCount"] = .integer(Int64(options.bootstrapResampleCount))
            parameters["permutationMonteCarloCount"] = .integer(
                Int64(options.permutationMonteCarloCount)
            )
            parameters["resamplingSeed"] = .text(String(options.resamplingSeed))
            parameters["contrasts"] = .list(
                options.contrasts.map { .list($0.map { .decimal($0) }) }
            )
            let descriptor = try Self.groupDescriptor(
                GlifiGroupMetricComparison.self,
                artifactType: "studio.glifi.artifact.group-metric-comparison",
                domain: "group-metric-comparison.v1",
                unit: "document.v1",
                representation: "document-metric-group-comparison-table-v1",
                parameters: parameters,
                snapshot: snapshot,
                groups: groups
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiGroupMetricAnalyzer().compare(
                    groups: groups.map(\.analysis),
                    metric: metric,
                    options: options
                )
            }
        }
    }

    /// Compares every pair of at least three disjoint groups on one document metric.
    public func postHocGroupMetric(
        in project: GlifiProjectPackage,
        groups sourceGroups: [[SourceRevisionID]],
        metric: GlifiDocumentMetric,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiPostHocAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            guard sourceGroups.count >= 3 else {
                throw derivedAnalysisFailure(
                    "group-posthoc.insufficient-groups",
                    category: .insufficientData
                )
            }
            let flattened = sourceGroups.flatMap { $0 }
            guard Set(flattened).count == flattened.count else {
                throw derivedAnalysisFailure("group-posthoc.overlapping-groups")
            }
            let snapshot = await project.snapshot()
            var groups: [DerivedCorpusGroup] = []
            for sourceGroup in sourceGroups {
                groups.append(
                    try await derivedCorpusGroup(
                        sourceGroup,
                        minimumCount: 1,
                        code: "group-posthoc",
                        snapshot: snapshot,
                        options: corpusOptions,
                        in: project
                    )
                )
            }
            var parameters: [String: GlifiAnalysisValue] = [
                "metricIdentifier": .text(metric.identifier)
            ]
            if case let .termRelativeFrequency(term) = metric {
                parameters["term"] = .text(term)
            }
            let descriptor = try Self.groupDescriptor(
                GlifiPostHocAnalysis.self,
                artifactType: "studio.glifi.artifact.group-metric-posthoc",
                domain: "group-metric-posthoc.v1",
                unit: "group-pair.v1",
                representation: "pairwise-posthoc-adjusted-table-v1",
                parameters: parameters,
                snapshot: snapshot,
                groups: groups
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiPostHocAnalyzer().compare(
                    groups: groups.map(\.analysis),
                    metric: metric
                )
            }
        }
    }

    /// Computes collocation measures over the documents of a group of at least two sources.
    public func analyzeCollocations(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        options: GlifiCooccurrenceOptions = .standard,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusCollocationAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 2,
                code: "collocation",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusCollocationAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-collocation",
                domain: "collocation-group.v1",
                unit: "normalized-term-pair.v1",
                representation: "document-presence-collocation-table-v1",
                parameters: Self.cooccurrenceParameters(options),
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusCollocationAnalyzer().analyze(group.analysis, options: options)
            }
        }
    }

    /// Correlates two document metrics over a group of at least three sources.
    public func correlateMetrics(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        first: GlifiDocumentMetric,
        second: GlifiDocumentMetric,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiMetricCorrelationAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 3,
                code: "metric-correlation",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            var parameters: [String: GlifiAnalysisValue] = [
                "firstMetricIdentifier": .text(first.identifier),
                "secondMetricIdentifier": .text(second.identifier),
            ]
            if case let .termRelativeFrequency(term) = first {
                parameters["firstTerm"] = .text(term)
            }
            if case let .termRelativeFrequency(term) = second {
                parameters["secondTerm"] = .text(term)
            }
            let descriptor = try Self.groupDescriptor(
                GlifiMetricCorrelationAnalysis.self,
                artifactType: "studio.glifi.artifact.metric-correlation",
                domain: "metric-correlation-group.v1",
                unit: "document.v1",
                representation: "document-metric-correlation-table-v1",
                parameters: parameters,
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiMetricCorrelationAnalyzer().analyze(
                    group.analysis,
                    first: first,
                    second: second
                )
            }
        }
    }

    /// Compares two metrics on the same documents of a group of at least two sources.
    public func comparePairedMetrics(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        first: GlifiDocumentMetric,
        second: GlifiDocumentMetric,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiPairedMetricAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 2,
                code: "paired-comparison",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            var parameters: [String: GlifiAnalysisValue] = [
                "firstMetricIdentifier": .text(first.identifier),
                "secondMetricIdentifier": .text(second.identifier),
                "confidenceLevel": .decimal(0.95),
            ]
            if case let .termRelativeFrequency(term) = first {
                parameters["firstTerm"] = .text(term)
            }
            if case let .termRelativeFrequency(term) = second {
                parameters["secondTerm"] = .text(term)
            }
            let descriptor = try Self.groupDescriptor(
                GlifiPairedMetricAnalysis.self,
                artifactType: "studio.glifi.artifact.paired-metric-comparison",
                domain: "paired-metric-group.v1",
                unit: "document.v1",
                representation: "document-paired-metric-table-v1",
                parameters: parameters,
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiPairedMetricAnalyzer().analyze(
                    group.analysis,
                    first: first,
                    second: second
                )
            }
        }
    }

    /// Applies a declared multivariate method to the document × term matrix of a group.
    public func analyzeMultivariate(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        method: GlifiMultivariateMethod,
        maximumTermCount: Int = 50,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusMultivariateAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 2,
                code: "multivariate",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            var parameters = method.parameters
            parameters["maximumTermCount"] = .integer(Int64(maximumTermCount))
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusMultivariateAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-multivariate",
                domain: "multivariate-group.v1",
                unit: "document-term-matrix.v1",
                representation: method.representationIdentifier,
                parameters: parameters,
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusMultivariateAnalyzer().analyze(
                    group.analysis,
                    method: method,
                    maximumTermCount: maximumTermCount
                )
            }
        }
    }

    /// Weighs the document × term matrix with a declared TF, IDF and row normalization.
    public func analyzeTermWeighting(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        scheme: GlifiTermWeightingScheme,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusTermWeightingAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "weighting",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusTermWeightingAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-term-weighting",
                domain: "term-weighting-group.v1",
                unit: "document-term-matrix.v1",
                representation: scheme.combinedIdentifier,
                parameters: [
                    "termFrequency": .text(scheme.termFrequency.rawValue),
                    "inverseDocumentFrequency": .text(scheme.inverseDocumentFrequency.rawValue),
                    "rowNormalization": .text(scheme.normalization.rawValue),
                    "logarithmBase": .text("e"),
                ],
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusTermWeightingAnalysis(group.analysis, scheme: scheme)
            }
        }
    }

    /// Measures `MTLD-bidirectional-v1` per document and over the pooled sequence.
    public func analyzeLexicalDiversity(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        threshold: Double = GlifiMTLD.standardThreshold,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusLexicalDiversityAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            guard threshold > 0, threshold < 1 else {
                throw derivedAnalysisFailure("diversity.invalid-threshold")
            }
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "diversity",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusLexicalDiversityAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-lexical-diversity",
                domain: "lexical-diversity-group.v1",
                unit: "lexical-token-sequence.v1",
                representation: "it-token-v1-nfc-lowercase-v1",
                parameters: [
                    "threshold": .decimal(threshold),
                    "sequencePolicy": .text("source-revision-order-concatenation-v1"),
                ],
                snapshot: snapshot,
                groups: [group]
            )
            let sequences = try await normalizedSequences(
                descriptor: descriptor, group: group, snapshot: snapshot,
                corpusOptions: corpusOptions, in: project)
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusLexicalDiversityAnalysis(sequences: sequences, threshold: threshold)
            }
        }
    }

    /// Selects the sentences of a group with a declared scoring method within a declared budget.
    public func analyzeExtractiveSummary(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        budget: GlifiSummaryBudget = .standard,
        scheme: GlifiTermWeightingScheme = GlifiCorpusExtractiveSummaryAnalysis.standardScheme,
        method: GlifiSummaryScoringMethod = GlifiCorpusExtractiveSummaryAnalysis.standardMethod,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusExtractiveSummaryAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            guard budget.isValid else {
                throw derivedAnalysisFailure("summary.invalid-budget")
            }
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "summary",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusExtractiveSummaryAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-extractive-summary",
                domain: "extractive-summary-group.v1",
                unit: "sentence.v1",
                representation: method.rawValue,
                parameters: [
                    "budgetUnit": .text(budget.unit.rawValue),
                    "budgetLimit": .integer(Int64(budget.limit)),
                    "termFrequency": .text(scheme.termFrequency.rawValue),
                    "inverseDocumentFrequency": .text(scheme.inverseDocumentFrequency.rawValue),
                    "normalization": .text(scheme.normalization.rawValue),
                    "redundancyPolicy": .text("redundancy.none-v1"),
                    "tieBreak": .text("tie-break.source-position-v1"),
                    "eligibility": .text(method.eligibilityPolicy),
                    "outputOrder": .text("output-order.source-v1"),
                ],
                snapshot: snapshot,
                groups: [group]
            )
            let documents = try await summaryDocuments(
                descriptor: descriptor, group: group, snapshot: snapshot,
                corpusOptions: corpusOptions, in: project)
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusExtractiveSummaryAnalysis(
                    documents: documents, budget: budget, scheme: scheme, method: method)
            }
        }
    }

    /// Resolves the selected sentences of a summary against the stored source texts.
    ///
    /// The payload keeps only intervals: the text is read from the sources of the
    /// current generation and returned unchanged, in source order.
    public func resolveSummarySentences(
        _ summary: GlifiCorpusExtractiveSummaryAnalysis,
        in project: GlifiProjectPackage,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> [GlifiResolvedSummarySentence] {
        try await guardedDerived {
            let selected = summary.selectedSentences
            guard !selected.isEmpty else { return [] }
            let snapshot = await project.snapshot()
            let recordsByID = Dictionary(
                uniqueKeysWithValues: snapshot.sources.map { ($0.sourceRevisionID, $0) }
            )
            let ids = try Array(Set(selected.map(\.sourceRevisionID)))
                .map(SourceRevisionID.init(canonicalValue:))
            let sources = try await importedSources(
                try selectedRecords(ids, recordsByID: recordsByID),
                from: project,
                maximumSourceByteCount: corpusOptions.maximumSourceByteCount
            )
            let textByID = Dictionary(
                uniqueKeysWithValues: sources.map { ($0.sourceRevisionID.canonicalValue, $0.text) }
            )
            return try selected.map { sentence in
                guard let text = textByID[sentence.sourceRevisionID],
                    let resolved = sentence.range.text(in: text)
                else {
                    throw derivedAnalysisFailure(
                        "summary.sentence-range-invalid", category: .invariantViolation)
                }
                return GlifiResolvedSummarySentence(sentence: sentence, text: resolved)
            }
        }
    }

    /// Sentences with normalized tokens of the group, read only if the node is not yet stored.
    private func summaryDocuments(
        descriptor: GlifiAnalysisDescriptor,
        group: DerivedCorpusGroup,
        snapshot: GlifiProjectSnapshot,
        corpusOptions: GlifiCorpusAnalysisOptions,
        in project: GlifiProjectPackage
    ) async throws -> [GlifiSummaryDocument] {
        let nodeID = try descriptor.nodeID()
        guard !snapshot.artifacts.contains(where: { $0.node.id == nodeID }) else {
            return group.sourceRevisionIDs.map {
                GlifiSummaryDocument(sourceRevisionID: $0, sentences: [])
            }
        }
        let recordsByID = Dictionary(
            uniqueKeysWithValues: snapshot.sources.map { ($0.sourceRevisionID, $0) }
        )
        let sources = try await importedSources(
            try selectedRecords(group.sourceRevisionIDs, recordsByID: recordsByID),
            from: project,
            maximumSourceByteCount: corpusOptions.maximumSourceByteCount
        )
        let locale = Locale(identifier: "it_IT")
        return try sources.map { source in
            try Task.checkCancellation()
            let tokenization = try textTokenizer.tokenize(source.text)
            var tokenIndex = 0
            let sentences = tokenization.sentences.map { sentence in
                var terms: [String] = []
                while tokenIndex < tokenization.tokens.count,
                    tokenization.tokens[tokenIndex].range.start < sentence.range.end
                {
                    let token = tokenization.tokens[tokenIndex]
                    tokenIndex += 1
                    guard token.range.start >= sentence.range.start,
                        token.kind.contributesToLexicalStatistics,
                        let surface = token.range.text(in: source.text)
                    else {
                        continue
                    }
                    terms.append(
                        surface.precomposedStringWithCanonicalMapping.lowercased(with: locale))
                }
                return GlifiSummaryCandidateSentence(range: sentence.range, terms: terms)
            }
            return GlifiSummaryDocument(
                sourceRevisionID: source.sourceRevisionID, sentences: sentences)
        }
    }

    /// Counts forms, word n-grams or character n-grams and applies declared filters.
    public func analyzeNGramFrequencies(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        unit: GlifiNGramUnit,
        filter: GlifiTermFilter = .none,
        maximumRowCount: Int = 1_000,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusNGramFrequencyAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            guard filter.isValid, (1...100_000).contains(maximumRowCount) else {
                throw derivedAnalysisFailure("ngrams.invalid-filter")
            }
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "ngrams",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusNGramFrequencyAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-ngram-frequencies",
                domain: "ngram-frequencies-group.v1",
                unit: unit.identifier,
                representation: "it-token-v1-nfc-lowercase-v1",
                parameters: [
                    "n": .integer(Int64(unit.size)),
                    "stopwords": .list(filter.stopwords.map { .text($0) }),
                    "minimumLength": .integer(Int64(filter.minimumLength)),
                    "minimumCount": .integer(Int64(filter.minimumCount)),
                    "minimumDocumentFrequency": .integer(Int64(filter.minimumDocumentFrequency)),
                    "maximumDocumentProportion": .decimal(filter.maximumDocumentProportion),
                    "maximumRowCount": .integer(Int64(maximumRowCount)),
                    "filter": .text("TermFilter-v1"),
                ],
                snapshot: snapshot,
                groups: [group]
            )
            let sequences = try await normalizedSequences(
                descriptor: descriptor, group: group, snapshot: snapshot,
                corpusOptions: corpusOptions, in: project)
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusNGramFrequencyAnalysis(
                    sequences: sequences, unit: unit, filter: filter,
                    maximumRowCount: maximumRowCount)
            }
        }
    }

    /// Normalized lexical sequences of the group, read only if the node is not yet stored.
    private func normalizedSequences(
        descriptor: GlifiAnalysisDescriptor,
        group: DerivedCorpusGroup,
        snapshot: GlifiProjectSnapshot,
        corpusOptions: GlifiCorpusAnalysisOptions,
        in project: GlifiProjectPackage
    ) async throws -> [(SourceRevisionID, [String])] {
        let nodeID = try descriptor.nodeID()
        guard !snapshot.artifacts.contains(where: { $0.node.id == nodeID }) else {
            return []
        }
        let recordsByID = Dictionary(
            uniqueKeysWithValues: snapshot.sources.map { ($0.sourceRevisionID, $0) }
        )
        let sources = try await importedSources(
            try selectedRecords(group.sourceRevisionIDs, recordsByID: recordsByID),
            from: project,
            maximumSourceByteCount: corpusOptions.maximumSourceByteCount
        )
        return try sources.map {
            (
                $0.sourceRevisionID,
                try GlifiQueryTermNormalizer.terms($0.text, tokenizer: textTokenizer)
            )
        }
    }

    /// Ranks the documents of a group with `BM25-v1` for a query text.
    public func rankDocumentsBM25(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        query: String,
        parameters: GlifiBM25Parameters = .standard,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusBM25Analysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            guard query.utf8.count <= 4_096 else {
                throw derivedAnalysisFailure("bm25.query-too-long")
            }
            guard parameters.k1 > 0, parameters.k1.isFinite, parameters.b >= 0,
                parameters.b <= 1
            else {
                throw derivedAnalysisFailure("bm25.invalid-parameters")
            }
            let terms = Array(Set(try GlifiQueryTermNormalizer.terms(query))).sorted()
            guard !terms.isEmpty else {
                throw derivedAnalysisFailure("bm25.empty-query")
            }
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "bm25",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusBM25Analysis.self,
                artifactType: "studio.glifi.artifact.corpus-bm25-ranking",
                domain: "bm25-group.v1",
                unit: "source-revision.v1",
                representation: "document-term-raw-count-v1",
                parameters: [
                    "k1": .decimal(parameters.k1),
                    "b": .decimal(parameters.b),
                    "queryTerms": .list(terms.map { .text($0) }),
                ],
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusBM25Analysis(
                    group.analysis, queryTerms: terms, parameters: parameters)
            }
        }
    }

    /// Computes token-window collocations over a group of at least one source.
    public func analyzeWindowCollocations(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        options: GlifiWindowCooccurrenceOptions = .standard,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiWindowCollocationAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "window-collocation",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiWindowCollocationAnalysis.self,
                artifactType: "studio.glifi.artifact.window-collocation",
                domain: "window-collocation-group.v1",
                unit: "normalized-term-ordered-pair.v1",
                representation: "token-window-collocation-table-v1",
                parameters: Self.windowParameters(options),
                snapshot: snapshot,
                groups: [group]
            )
            // Le fonti si rileggono solo se l'Artifact non è già nella generazione.
            let nodeID = try descriptor.nodeID()
            let isReusable = snapshot.artifacts.contains { $0.node.id == nodeID }
            var sources: [GlifiImportedText] = []
            if !isReusable {
                let recordsByID = Dictionary(
                    uniqueKeysWithValues: snapshot.sources.map { ($0.sourceRevisionID, $0) }
                )
                sources = try await importedSources(
                    try selectedRecords(group.sourceRevisionIDs, recordsByID: recordsByID),
                    from: project,
                    maximumSourceByteCount: corpusOptions.maximumSourceByteCount
                )
            }
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiWindowCollocationAnalyzer(tokenizer: textTokenizer)
                    .analyze(sources, options: options)
            }
        }
    }

    /// Builds the token-window network over a group of at least one source.
    public func analyzeWindowNetwork(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        options: GlifiWindowNetworkOptions = .standard,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiWindowNetworkAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 1,
                code: "window-network",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiWindowNetworkAnalysis.self,
                artifactType: "studio.glifi.artifact.window-network",
                domain: "window-network-group.v1",
                unit: "normalized-term-node.v1",
                representation: "token-window-network-graph-v1",
                parameters: Self.windowNetworkParameters(options),
                snapshot: snapshot,
                groups: [group]
            )
            // Le fonti si rileggono solo se l'Artifact non è già nella generazione.
            let nodeID = try descriptor.nodeID()
            let isReusable = snapshot.artifacts.contains { $0.node.id == nodeID }
            var sources: [GlifiImportedText] = []
            if !isReusable {
                let recordsByID = Dictionary(
                    uniqueKeysWithValues: snapshot.sources.map { ($0.sourceRevisionID, $0) }
                )
                sources = try await importedSources(
                    try selectedRecords(group.sourceRevisionIDs, recordsByID: recordsByID),
                    from: project,
                    maximumSourceByteCount: corpusOptions.maximumSourceByteCount
                )
            }
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiWindowNetworkAnalyzer(tokenizer: textTokenizer)
                    .analyze(sources, options: options)
            }
        }
    }

    /// Computes the term co-occurrence network over a group of at least two sources.
    public func analyzeLexicalNetwork(
        in project: GlifiProjectPackage,
        sourceRevisionIDs: [SourceRevisionID],
        options: GlifiCooccurrenceOptions = .standard,
        corpusOptions: GlifiCorpusAnalysisOptions = .standard
    ) async throws -> GlifiProjectDerivedResult<GlifiCorpusLexicalNetworkAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let group = try await derivedCorpusGroup(
                sourceRevisionIDs,
                minimumCount: 2,
                code: "network",
                snapshot: snapshot,
                options: corpusOptions,
                in: project
            )
            let descriptor = try Self.groupDescriptor(
                GlifiCorpusLexicalNetworkAnalysis.self,
                artifactType: "studio.glifi.artifact.corpus-lexical-network",
                domain: "lexical-network-group.v1",
                unit: "normalized-term.v1",
                representation: "document-presence-cooccurrence-network-v1",
                parameters: Self.cooccurrenceParameters(options),
                snapshot: snapshot,
                groups: [group]
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCorpusLexicalNetworkAnalyzer().analyze(group.analysis, options: options)
            }
        }
    }

    /// Computes inter-coder agreement over a caller-supplied nominal coding table.
    public func assessCodingAgreement(
        in project: GlifiProjectPackage,
        request: GlifiCodingAgreementRequest
    ) async throws -> GlifiProjectDerivedResult<GlifiCodingAgreementAnalysis> {
        try await guardedDerived {
            try Task.checkCancellation()
            let snapshot = await project.snapshot()
            let descriptor = try GlifiAnalysisArtifactDescriptorFactory.derived(
                GlifiCodingAgreementAnalysis.self,
                artifactTypeIdentifier: "studio.glifi.artifact.coding-agreement",
                snapshot: snapshot,
                // L'accordo si calcola sulla tabella fornita dal chiamante: non legge fonti.
                sourceRevisionIDs: [],
                selectionDomain: "coding-agreement-request.v1",
                selectionValues: [try request.canonicalDigest()],
                analyticalUnitIdentifier: "coded-unit.v1",
                representationIdentifier: "coding-agreement-nominal-table-v1",
                resolvedParameters: [:],
                linguisticProfileIdentifiers: [],
                dependencies: []
            )
            return try await derivedArtifact(
                descriptor: descriptor,
                sourceSnapshot: snapshot,
                in: project
            ) {
                try GlifiCodingAgreementAnalyzer().analyze(request)
            }
        }
    }

    private static func cooccurrenceParameters(
        _ options: GlifiCooccurrenceOptions
    ) -> [String: GlifiAnalysisValue] {
        [
            "maximumTermCount": .integer(Int64(options.maximumTermCount)),
            "minimumJointCount": .integer(Int64(options.minimumJointCount)),
            "maximumPairCount": .integer(Int64(options.maximumPairCount)),
        ]
    }

    private static func windowParameters(
        _ options: GlifiWindowCooccurrenceOptions
    ) -> [String: GlifiAnalysisValue] {
        [
            "leftSpan": .integer(Int64(options.leftSpan)),
            "rightSpan": .integer(Int64(options.rightSpan)),
            "crossesSentences": .boolean(options.crossesSentences),
            "includesSelfPairs": .boolean(options.includesSelfPairs),
            "minimumJointCount": .integer(Int64(options.minimumJointCount)),
            "maximumPairCount": .integer(Int64(options.maximumPairCount)),
            "distanceWeighting": .text(options.distanceWeighting.rawValue),
            "maximumPositionsPerPair": .integer(Int64(options.maximumPositionsPerPair)),
        ]
    }

    private static func windowNetworkParameters(
        _ options: GlifiWindowNetworkOptions
    ) -> [String: GlifiAnalysisValue] {
        var parameters = windowParameters(options.window)
        parameters["usesWeightedJointCount"] = .boolean(options.usesWeightedJointCount)
        if let threshold = options.minimumLogDice {
            parameters["minimumLogDice"] = .decimal(threshold)
        }
        return parameters
    }

    private static func groupDescriptor<Value: GlifiDerivedAnalysisResult>(
        _ type: Value.Type,
        artifactType: String,
        domain: String,
        unit: String,
        representation: String,
        parameters: [String: GlifiAnalysisValue],
        snapshot: GlifiProjectSnapshot,
        groups: [DerivedCorpusGroup]
    ) throws -> GlifiAnalysisDescriptor {
        let selection = groups.enumerated().flatMap { index, group in
            group.sourceRevisionIDs.sorted { $0.canonicalValue < $1.canonicalValue }
                .map { "group\(index):\($0.canonicalValue)" }
        }
        let first = groups.first?.analysis
        return try GlifiAnalysisArtifactDescriptorFactory.derived(
            type,
            artifactTypeIdentifier: artifactType,
            snapshot: snapshot,
            // L'analisi legge le revisioni di tutti i gruppi confrontati, e soltanto quelle.
            sourceRevisionIDs: groups.flatMap(\.sourceRevisionIDs),
            selectionDomain: domain,
            selectionValues: selection,
            analyticalUnitIdentifier: unit,
            representationIdentifier: representation,
            resolvedParameters: parameters,
            linguisticProfileIdentifiers: [
                first?.tokenizationContractIdentifier ?? "unavailable",
                first?.normalizationIdentifier ?? "unavailable",
            ],
            dependencies: groups.map(\.dependency)
        )
    }
}

extension GlifiEngine {
    /// Planner-chosen parameters of the ADR-0025 capabilities, declared in the step output.
    static let plannedWindow = GlifiWindowCooccurrenceOptions.standardPlanned

    /// Executes one ADR-0025 plan step with the parameters declared by the capability catalog.
    func executeExtendedStep(
        _ step: GlifiAnalysisPlanStep,
        plan: GlifiAnalysisPlan,
        in project: GlifiProjectPackage
    ) async throws -> (artifactID: ArtifactID, nodeID: AnalysisNodeID) {
        let sources = step.sourceRevisionIDs
        switch step.operation {
        case .analyzeAssociation:
            let result = try await analyzeAssociation(in: project, sourceRevisionIDs: sources)
            return (result.artifactID, result.analysisNodeID)
        case .analyzeWindowCollocations:
            let result = try await analyzeWindowCollocations(
                in: project,
                sourceRevisionIDs: sources,
                options: Self.plannedWindow
            )
            return (result.artifactID, result.analysisNodeID)
        case .analyzeWindowNetwork:
            let result = try await analyzeWindowNetwork(
                in: project,
                sourceRevisionIDs: sources,
                options: GlifiWindowNetworkOptions(
                    window: Self.plannedWindow,
                    minimumLogDice: nil,
                    usesWeightedJointCount: false
                )
            )
            return (result.artifactID, result.analysisNodeID)
        case .analyzeCorrespondence:
            let result = try await analyzeMultivariate(
                in: project,
                sourceRevisionIDs: sources,
                method: .correspondence
            )
            return (result.artifactID, result.analysisNodeID)
        case .clusterDocuments:
            let result = try await analyzeMultivariate(
                in: project,
                sourceRevisionIDs: sources,
                method: .hierarchical(linkage: .ward, clusterCount: min(3, sources.count - 1))
            )
            return (result.artifactID, result.analysisNodeID)
        case .compareSimilarity:
            let result = try await compareSimilarity(
                in: project,
                targetSourceRevisionIDs: plan.targetSourceRevisionIDs,
                referenceSourceRevisionIDs: plan.referenceSourceRevisionIDs
            )
            return (result.artifactID, result.analysisNodeID)
        case .compareGroupMetric:
            let result = try await compareGroupMetric(
                in: project,
                groups: [plan.targetSourceRevisionIDs, plan.referenceSourceRevisionIDs],
                metric: .lexicalTokenCount
            )
            return (result.artifactID, result.analysisNodeID)
        case .analyzeCorpus, .compareKeyness:
            throw analysisArtifactFailure(
                "runtime.plan-operation-unsupported", operation: .executePlan)
        }
    }
}

extension GlifiEngine {
    /// Decodes an ADR-0025 plan output and extracts the facts of its ADR-0026 policy.
    func supplementaryContent(
        operation: GlifiPlannedOperation,
        outputSchemaIdentifier: String,
        data: Data,
        expectedNodeID: AnalysisNodeID
    ) throws -> GlifiInterpretationArtifactContent {
        func derived<Value: GlifiDerivedAnalysisResult>(_ type: Value.Type) throws -> Value {
            let payload: GlifiDerivedAnalysisArtifactPayload<Value> = try decodeArtifact(data)
            guard payload.analysisNodeID == expectedNodeID else {
                throw analysisArtifactFailure(
                    "interpretation.input-node-mismatch",
                    operation: .executePlan
                )
            }
            return payload.result
        }
        func identifiers(_ values: [String]) throws -> [SourceRevisionID] {
            try values.map(SourceRevisionID.init(canonicalValue:))
        }
        let sources: [SourceRevisionID]
        let facts: GlifiSupplementaryFacts
        switch operation {
        case .analyzeAssociation:
            let value = try derived(GlifiCorpusAssociationAnalysis.self)
            sources = try identifiers(value.sourceRevisionIDs)
            facts = .association(
                cramersV: value.cramersV,
                minimumDimension: min(value.includedDocumentCount, value.includedTermCount),
                monteCarloPValue: value.monteCarloPValue,
                lowExpectedCellFraction: value.lowExpectedCellFraction
            )
        case .analyzeWindowCollocations:
            let value = try derived(GlifiWindowCollocationAnalysis.self)
            sources = try identifiers(value.sourceRevisionIDs)
            facts = .collocations(
                value.pairs.map {
                    GlifiCollocationFact(
                        node: $0.nodeTerm,
                        collocate: $0.collocateTerm,
                        jointCount: $0.jointCount,
                        tScore: $0.tScore,
                        npmi: $0.npmi,
                        logDice: $0.logDice
                    )
                }
            )
        case .analyzeWindowNetwork:
            let value = try derived(GlifiWindowNetworkAnalysis.self)
            sources = try identifiers(value.sourceRevisionIDs)
            facts = .network(
                modularity: value.summary.modularity,
                communityCount: value.summary.communityCount,
                nodeCount: value.summary.nodeCount
            )
        case .analyzeCorrespondence:
            let value = try derived(GlifiCorpusMultivariateAnalysis.self)
            sources = try identifiers(value.sourceRevisionIDs)
            guard let ca = value.correspondence else {
                throw analysisArtifactFailure(
                    "interpretation.input-family-mismatch", operation: .executePlan)
            }
            facts = .correspondence(inertias: ca.inertias, totalInertia: ca.totalInertia)
        case .clusterDocuments:
            let value = try derived(GlifiCorpusMultivariateAnalysis.self)
            sources = try identifiers(value.sourceRevisionIDs)
            let assignments = value.clusterAssignments ?? []
            let sizes = Dictionary(grouping: assignments, by: { $0 }).values.map(\.count)
            facts = .clustering(
                clusterCount: sizes.count,
                averageSilhouette: value.averageSilhouette,
                smallestClusterSize: sizes.min() ?? 0
            )
        case .compareSimilarity:
            let payload: GlifiCorpusSimilarityArtifactPayload = try decodeArtifact(data)
            guard payload.analysisNodeID == expectedNodeID else {
                throw analysisArtifactFailure(
                    "interpretation.input-node-mismatch",
                    operation: .executePlan
                )
            }
            let comparison = payload.comparison
            sources = comparison.targetSourceRevisionIDs + comparison.referenceSourceRevisionIDs
            facts = .similarity(
                sharedTypeCount: comparison.sharedTypeCount,
                cosine: comparison.cosineSimilarity,
                jsDistance: comparison.jsDistance
            )
        case .compareGroupMetric:
            let value = try derived(GlifiGroupMetricComparison.self)
            sources = try identifiers(value.groups.flatMap(\.sourceRevisionIDs))
            facts = .groupLocation(
                metricIdentifier: value.metricIdentifier,
                hedgesG: value.standardizedDifference?.hedgesG,
                pValue: value.welch?.pValue ?? value.mannWhitney?.pValue,
                smallestGroupSize: value.groups.map(\.documentCount).min() ?? 0
            )
        case .analyzeCorpus, .compareKeyness:
            throw analysisArtifactFailure(
                "interpretation.input-family-mismatch", operation: .executePlan)
        }
        return .supplementary(
            outputSchemaIdentifier: outputSchemaIdentifier,
            sourceRevisionIDs: sources,
            facts: facts
        )
    }
}
