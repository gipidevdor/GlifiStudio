// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

struct GlifiProjectCommandTests {
    @Test("Ogni richiesta di progetto conserva integralmente l'esito delle API native")
    func everyProjectOperationMatchesTheNativeSession() async throws {
        let fixture = try await ProjectCommandFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let verificationID = UUID().uuidString
        for operation in GlifiStudioProjectOperation.allCases {
            var parameters = try Self.parameters(operation, sourceIDs: fixture.sourceIDs)
            if operation == .exportVisualization {
                let result = try await fixture.session.analyzeMultivariate(
                    sourceRevisionIDs: fixture.sourceIDs,
                    method: .principalComponents(scaled: true), maximumTermCount: 4)
                parameters.visualization = try #require(
                    try GlifiStudioVisualizationBuilder.factorPlot(result)
                        as GlifiStudioVisualization?)
                parameters.destinationPath = fixture.root.appending(path: "transport-export").path
            }
            if operation == .recutVisualization {
                let result = try await fixture.session.analyzeMultivariate(
                    sourceRevisionIDs: fixture.sourceIDs,
                    method: .hierarchicalTerms(linkage: "average", clusterCount: 2),
                    maximumTermCount: 4)
                let visualization = try GlifiStudioVisualizationBuilder.dendrogram(result)
                parameters.visualization = visualization
                parameters.clusterCount = 3
            }
            let request = ProjectCommandTestRequest(operation: operation, parameters: parameters)
            let referenceURL = fixture.root.appending(path: "Reference.glifi")
            try FileManager.default.copyItem(at: fixture.projectURL, to: referenceURL)
            let projectSnapshot = try Self.exportSnapshotIfRequested(
                fixture.projectURL, operation: operation, verificationID: verificationID)
            let reference = try await GlifiStudioService().openProject(at: referenceURL)
            let nativeExportURL = Self.nativeExportURL(
                fixture.root, verificationID: verificationID)
            if operation == .exportVisualization {
                try FileManager.default.createDirectory(
                    at: nativeExportURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
            }
            let expected = try await Self.nativeResult(
                operation, parameters: parameters, session: reference,
                nativeExportURL: nativeExportURL)
            await reference.close()
            try FileManager.default.removeItem(at: referenceURL)
            let actual = try await GlifiStudioProjectCommand.execute(
                json: JSONEncoder().encode(request), session: fixture.session)
            if operation == .exportVisualization {
                let expectedReceipt = try JSONDecoder().decode(
                    GlifiStudioVisualExportReceipt.self, from: expected.json)
                let actualReceipt = try JSONDecoder().decode(
                    GlifiStudioVisualExportReceipt.self, from: actual.json)
                #expect(actualReceipt.fileCount == expectedReceipt.fileCount)
                let expectedFiles = try Self.exportedFiles(nativeExportURL)
                let actualFiles = try Self.exportedFiles(
                    fixture.root.appending(path: "transport-export"))
                _ = try GlifiStudioVisualExport.verify(expectedFiles)
                _ = try GlifiStudioVisualExport.verify(actualFiles)
                #expect(expectedFiles["view.csv"] == actualFiles["view.csv"])
                #expect(expectedFiles["view-spec.json"] == actualFiles["view-spec.json"])
            } else {
                #expect(actual.json == expected.json, "Operation: \(operation.rawValue)")
            }
            try exportKitCLIParityFixture(
                command: "project-call", operation: String(describing: operation),
                request: request, result: expected, projectURL: projectSnapshot,
                visualExportURL: operation == .exportVisualization ? nativeExportURL : nil)
        }
        await fixture.session.close()
    }

    @Test("Il trasporto rifiuta parametri sconosciuti, versioni e opzioni invalide")
    func invalidProjectCommandsDoNotMutateTheProject() async throws {
        let fixture = try await ProjectCommandFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let requests = [
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":1,
             "operation":"corpus","parameters":{},"unknown":1}
            """,
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":1,
             "operation":"corpus","parameters":{"sourceRevisionIDs":[]}}
            """,
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":1,
             "operation":"corpus","parameters":{"corpusOptions":{"unknown":2}}}
            """,
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":1,
             "operation":"corpus","parameters":{"corpusOptions":{"diversityWindowSize":0}}}
            """,
            """
            {"schema":"other","schemaVersion":1,"operation":"corpus","parameters":{}}
            """,
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":2,
             "operation":"corpus","parameters":{}}
            """,
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":1,
             "operation":"source-text","parameters":{}}
            """,
            """
            {"schema":"studio.glifi.project-command-request","schemaVersion":1,
             "operation":"missing","parameters":{}}
            """,
        ]
        for request in requests {
            await #expect(throws: GlifiStudioFailure.self) {
                try await GlifiStudioProjectCommand.execute(
                    json: Data(request.utf8), session: fixture.session)
            }
            #expect(try await fixture.session.snapshot() == before)
        }
        await fixture.session.close()
    }

    @Test("Le varianti multivariate e le metriche mantengono tutti i parametri Codable")
    func analyticalChoicesHaveExhaustiveRoundTrips() throws {
        let metrics: [GlifiStudioDocumentMetric] = [
            .lexicalTokenCount, .termRelativeFrequency("città"),
        ]
        for metric in metrics {
            #expect(
                try JSONDecoder().decode(
                    GlifiStudioDocumentMetric.self, from: JSONEncoder().encode(metric)) == metric)
        }
        let methods: [GlifiStudioMultivariateMethod] = [
            .correspondence, .principalComponents(scaled: false),
            .principalComponents(scaled: true),
            .latentSemantic(rank: 3),
            .nonNegativeFactorization(rank: 2, seed: UInt64.max, restarts: 2),
            .hierarchical(linkage: "average", clusterCount: 3),
            .hierarchicalTerms(linkage: "ward", clusterCount: 2),
            .kMeans(clusterCount: 3, seed: UInt64.max, restarts: 4),
        ]
        for method in methods {
            #expect(
                try JSONDecoder().decode(
                    GlifiStudioMultivariateMethod.self, from: JSONEncoder().encode(method))
                    == method)
        }
    }

    @Test("HAC dei termini conserva identità, fonti contribuenti e parità del trasporto")
    func termClusteringPreservesUnitsAndProjectTransport() async throws {
        let fixture = try await ProjectCommandFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let method = GlifiStudioMultivariateMethod.hierarchicalTerms(
            linkage: "average", clusterCount: 2)
        let result = try await fixture.session.analyzeMultivariate(
            sourceRevisionIDs: fixture.sourceIDs, method: method, maximumTermCount: 4)
        #expect(result.clusterUnitKindIdentifier == "terms")
        #expect(result.clusterUnitIdentifiers == result.terms)
        #expect(result.terms.count == 4)
        #expect(result.clusterAssignments?.count == result.terms.count)
        #expect(result.merges?.count == result.terms.count - 1)
        #expect(result.clusterUnitSourceRevisionIDs?.count == result.terms.count)
        #expect(result.representationIdentifier == "term-document-relative-frequency-v1")
        let documentResult = try await fixture.session.analyzeMultivariate(
            sourceRevisionIDs: fixture.sourceIDs,
            method: .hierarchical(linkage: "average", clusterCount: 2), maximumTermCount: 4)
        #expect(documentResult.clusterUnitKindIdentifier == "documents")
        #expect(documentResult.clusterUnitIdentifiers == documentResult.sourceRevisionIDs)
        #expect(documentResult.clusterUnitSourceRevisionIDs == nil)
        #expect(documentResult.lineage.artifactID != result.lineage.artifactID)
        let reopened = try await fixture.session.analyzeMultivariate(
            sourceRevisionIDs: fixture.sourceIDs.reversed(), method: method, maximumTermCount: 4)
        #expect(reopened.lineage.artifactID == result.lineage.artifactID)
        #expect(reopened.clusterAssignments == result.clusterAssignments)
        #expect(reopened.clusterUnitSourceRevisionIDs == result.clusterUnitSourceRevisionIDs)
        var parameters = try Self.parameters(.multivariate, sourceIDs: fixture.sourceIDs)
        parameters.multivariateMethod = method
        parameters.corpusOptions = nil
        let request = ProjectCommandTestRequest(operation: .multivariate, parameters: parameters)
        let actual = try await GlifiStudioProjectCommand.execute(
            json: JSONEncoder().encode(request), session: fixture.session)
        let expected = try GlifiStudioCommandResult(reopened)
        #expect(actual.json == expected.json)
        let snapshot = try Self.exportSnapshotIfRequested(
            fixture.projectURL, operation: .multivariate, verificationID: UUID().uuidString)
        try exportKitCLIParityFixture(
            command: "project-call", operation: "multivariate", request: request,
            result: expected, projectURL: snapshot, variant: "terms")
        var oldJSON = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(documentResult))
                as? [String: Any])
        oldJSON.removeValue(forKey: "clusterUnitSourceRevisionIDs")
        let old = try JSONDecoder().decode(
            GlifiStudioMultivariateResult.self,
            from: JSONSerialization.data(withJSONObject: oldJSON))
        #expect(old == documentResult)
        await fixture.session.close()
    }

    @Test("La cancellazione delle richieste di progetto resta tipizzata e non muta i dati")
    func cancellationPrecedesProjectMutation() async throws {
        let fixture = try await ProjectCommandFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try await fixture.session.snapshot()
        let request = ProjectCommandTestRequest(
            operation: .corpus, parameters: .init())
        let json = try JSONEncoder().encode(request)
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await GlifiStudioProjectCommand.execute(json: json, session: fixture.session)
        }
        do {
            _ = try await operation.value
            Issue.record("Cancelled project command published a result")
        } catch let failure as GlifiStudioFailure {
            #expect(failure.category == "cancelled")
            #expect(failure.retainedState == "unchanged")
        }
        #expect(try await fixture.session.snapshot() == before)
        await fixture.session.close()
    }

    @Test(
        "Il trasporto del taglio include le parità e rifiuta selettori invalidi senza mutare il progetto"
    )
    func recutVisualizationSupportsInclusiveHeightAndRejectsInvalidCuts() async throws {
        let fixture = try await ProjectCommandFixture.create()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let result = try await fixture.session.analyzeMultivariate(
            sourceRevisionIDs: fixture.sourceIDs,
            method: .hierarchicalTerms(linkage: "average", clusterCount: 2), maximumTermCount: 4)
        let visualization = try #require(try GlifiStudioVisualizationBuilder.dendrogram(result))
        let tree = try #require(visualization.dendrogramTree)
        let height = try #require(tree.merges.first?.height)
        let before = try await fixture.session.snapshot()
        var parameters = ProjectCommandTestParameters()
        parameters.visualization = visualization
        parameters.maximumHeight = height
        let request = ProjectCommandTestRequest(
            operation: .recutVisualization, parameters: parameters)
        let expected = try GlifiStudioCommandResult(
            GlifiStudioVisualizationBuilder.recutDendrogram(visualization, height: height))
        let actual = try await GlifiStudioProjectCommand.execute(
            json: JSONEncoder().encode(request), session: fixture.session)
        #expect(actual.json == expected.json)
        let recut = try JSONDecoder().decode(GlifiStudioVisualization.self, from: actual.json)
        #expect(recut.artifactID == visualization.artifactID)
        #expect(recut.analysisNodeID == visualization.analysisNodeID)
        #expect(recut.dendrogramTree == visualization.dendrogramTree)
        let retained = tree.merges.prefix { $0.height <= height }.count
        #expect(
            Set(recut.marks.filter { $0.kind == .point }.map(\.series)).count
                == tree.leafIdentifiers.count - retained)
        let snapshot = try Self.exportSnapshotIfRequested(
            fixture.projectURL, operation: .recutVisualization, verificationID: UUID().uuidString)
        try exportKitCLIParityFixture(
            command: "project-call", operation: "recutVisualization", request: request,
            result: expected, projectURL: snapshot, variant: "height")
        let invalidCuts: [(Int?, Double?)] = [
            (nil, nil), (2, height), (0, nil), (tree.leafIdentifiers.count + 1, nil), (nil, -1),
        ]
        for (clusterCount, maximumHeight) in invalidCuts {
            var invalid = parameters
            invalid.clusterCount = clusterCount
            invalid.maximumHeight = maximumHeight
            let invalidRequest = ProjectCommandTestRequest(
                operation: .recutVisualization, parameters: invalid)
            var expectedFailure: GlifiStudioFailure?
            do {
                _ = try GlifiStudioVisualizationBuilder.recutDendrogram(
                    visualization, clusterCount: clusterCount, height: maximumHeight)
                Issue.record("Invalid native dendrogram cut was accepted")
            } catch let failure { expectedFailure = failure }
            do {
                _ = try await GlifiStudioProjectCommand.execute(
                    json: JSONEncoder().encode(invalidRequest), session: fixture.session)
                Issue.record("Invalid transported dendrogram cut was accepted")
            } catch let failure as GlifiStudioFailure {
                #expect(failure.code == expectedFailure?.code)
                #expect(failure.category == expectedFailure?.category)
                #expect(failure.category == "invalidInput")
                #expect(failure.retryDisposition == "afterCorrection")
                #expect(failure.retainedState == "unchanged")
            }
            #expect(try await fixture.session.snapshot() == before)
        }
        await fixture.session.close()
    }

    private static func parameters(
        _ operation: GlifiStudioProjectOperation, sourceIDs ids: [String]
    ) throws -> ProjectCommandTestParameters {
        var p = ProjectCommandTestParameters()
        let groups = [Array(ids[0..<2]), Array(ids[2..<4]), Array(ids[4..<6])]
        switch operation {
        case .corpus:
            p.corpusOptions = .init()
        case .keyness:
            p.targetSourceRevisionIDs = Array(ids[0..<3])
            p.referenceSourceRevisionIDs = Array(ids[3..<6])
            p.corpusOptions = .init()
            p.keynessOptions = .init()
        case .similarity:
            p.targetSourceRevisionIDs = Array(ids[0..<3])
            p.referenceSourceRevisionIDs = Array(ids[3..<6])
            p.corpusOptions = .init()
        case .association:
            p.sourceRevisionIDs = ids
            p.corpusOptions = .init()
        case .dispersion:
            p.sourceRevisionIDs = ids
            p.partition = groups
            p.corpusOptions = .init()
        case .groupMetric:
            p.groups = groups
            p.metric = .lexicalTokenCount
            p.options = try .init(
                confidenceLevel: 0.9, bootstrapResampleCount: 50,
                permutationMonteCarloCount: 50, resamplingSeed: 42,
                contrasts: [[1, -0.5, -0.5]])
            p.corpusOptions = .init()
        case .postHoc:
            p.groups = groups
            p.metric = .termRelativeFrequency("casa")
            p.corpusOptions = .init()
        case .collocations, .network:
            p.sourceRevisionIDs = ids
            p.cooccurrenceOptions = try .init(
                maximumTermCount: 4, minimumJointCount: 1, maximumPairCount: 6)
            p.corpusOptions = .init()
        case .correlate, .paired:
            p.sourceRevisionIDs = ids
            p.first = .lexicalTokenCount
            p.second = .termRelativeFrequency("casa")
            p.corpusOptions = .init()
        case .multivariate:
            p.sourceRevisionIDs = ids
            p.multivariateMethod = .principalComponents(scaled: true)
            p.maximumTermCount = 4
            p.corpusOptions = .init()
        case .weighting:
            p.sourceRevisionIDs = ids
            p.scheme = .init(
                termFrequency: "TF-sublinear-v1", inverseDocumentFrequency: "IDF-smooth-v1",
                normalization: "RowNorm-L2-v1")
            p.corpusOptions = .init()
        case .diversity:
            p.sourceRevisionIDs = ids
            p.threshold = 0.65
            p.corpusOptions = .init()
        case .laws:
            p.sourceRevisionIDs = ids
            p.lawParameters = .init(
                checkpointCount: 5, zipfFirstRank: 1, zipfLastRank: 4, rankRowLimit: 10)
            p.corpusOptions = .init()
        case .summarize:
            p.sourceRevisionIDs = ids
            p.budget = .init(unit: "Budget-sentences-v1", limit: 3)
            p.scheme = .summaryStandard
            p.summaryMethod = .init(identifier: "TextRankSentence-configurable-v1")
            p.redundancy = .maximalMarginalRelevance(lambda: 0.7)
            p.graphConfiguration = .init(
                damping: 0.7, tolerance: 1e-8, maximumIterations: 200, similarityThreshold: 0.2)
            p.corpusOptions = .init()
        case .ngrams:
            p.sourceRevisionIDs = ids
            p.unit = .init(kind: "word", n: 2)
            p.filter = .init(
                stopwords: ["sole"], minimumLength: 2, minimumCount: 1,
                minimumDocumentFrequency: 1, maximumDocumentProportion: 1)
            p.maximumRowCount = 20
            p.corpusOptions = .init()
        case .bm25:
            p.sourceRevisionIDs = ids
            p.query = "casa mare"
            p.k1 = 1.5
            p.b = 0.6
            p.corpusOptions = .init()
        case .windowCollocations:
            p.sourceRevisionIDs = ids
            p.windowOptions = try .init(
                leftSpan: 1, rightSpan: 2, crossesSentences: true,
                includesSelfPairs: false, minimumJointCount: 1, maximumPairCount: 10,
                weightsByInverseDistance: true, maximumPositionsPerPair: 3)
            p.corpusOptions = .init()
        case .windowNetwork:
            p.sourceRevisionIDs = ids
            p.window = try .init(
                leftSpan: 2, rightSpan: 1, crossesSentences: false,
                includesSelfPairs: false, minimumJointCount: 1, maximumPairCount: 8,
                weightsByInverseDistance: true, maximumPositionsPerPair: 4)
            p.minimumLogDice = 0
            p.usesWeightedJointCount = true
            p.corpusOptions = .init()
        case .sourceText, .characterCount:
            p.sourceRevisionID = ids[0]
        case .passages:
            p.sourceRevisionID = ids[0]
            p.selections = [.sentences(first: 1, last: 1), .characters(start: 0, end: 4)]
        case .exportVisualization, .recutVisualization:
            break
        case .prepareInput:
            p.sourceRevisionIDs = ids
            p.maximumTermCount = 3
            p.allowsEmptyLexicon = true
        case .temporal:
            p.assignments = ids.enumerated().map {
                .init(
                    sourceRevisionID: $0.element,
                    value: .civilMonth(year: 2024, month: $0.offset + 1),
                    provenance: "manual.synthetic.\($0.offset)")
            }
            p.terms = ["casa", "mare"]
            p.configuration = .init(
                basis: .civilDates, granularity: .month,
                origin: try .init(year: 2024, month: 1, day: 1), bucketWidth: 1, bucketCount: 6,
                missingPolicy: .separate, outsidePolicy: .exclude)
        }
        return p
    }

    private static func nativeResult(
        _ operation: GlifiStudioProjectOperation, parameters p: ProjectCommandTestParameters,
        session: GlifiStudioProjectSession, nativeExportURL: URL
    ) async throws -> GlifiStudioCommandResult {
        let corpus = try p.corpusOptions?.value ?? .standard
        switch operation {
        case .corpus:
            return try await GlifiStudioCommandResult(session.analyzeCorpus(options: corpus))
        case .keyness:
            return try await GlifiStudioCommandResult(
                session.compareKeyness(
                    targetSourceRevisionIDs: #require(p.targetSourceRevisionIDs),
                    referenceSourceRevisionIDs: #require(p.referenceSourceRevisionIDs),
                    corpusOptions: corpus, keynessOptions: #require(p.keynessOptions).value))
        case .similarity:
            return try await GlifiStudioCommandResult(
                session.compareSimilarity(
                    targetSourceRevisionIDs: #require(p.targetSourceRevisionIDs),
                    referenceSourceRevisionIDs: #require(p.referenceSourceRevisionIDs),
                    corpusOptions: corpus))
        case .association:
            return try await GlifiStudioCommandResult(
                session.analyzeAssociation(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), corpusOptions: corpus))
        case .dispersion:
            return try await GlifiStudioCommandResult(
                session.analyzeDispersion(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), partition: p.partition,
                    corpusOptions: corpus))
        case .groupMetric:
            return try await GlifiStudioCommandResult(
                session.compareGroupMetric(
                    groups: #require(p.groups), metric: #require(p.metric),
                    options: #require(p.options), corpusOptions: corpus))
        case .postHoc:
            return try await GlifiStudioCommandResult(
                session.postHocGroupMetric(
                    groups: #require(p.groups), metric: #require(p.metric), corpusOptions: corpus))
        case .collocations:
            return try await GlifiStudioCommandResult(
                session.analyzeCollocations(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    options: #require(p.cooccurrenceOptions), corpusOptions: corpus))
        case .correlate:
            return try await GlifiStudioCommandResult(
                session.correlateMetrics(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    first: #require(p.first), second: #require(p.second), corpusOptions: corpus))
        case .paired:
            return try await GlifiStudioCommandResult(
                session.comparePairedMetrics(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    first: #require(p.first), second: #require(p.second), corpusOptions: corpus))
        case .multivariate:
            return try await GlifiStudioCommandResult(
                session.analyzeMultivariate(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    method: #require(p.multivariateMethod),
                    maximumTermCount: #require(p.maximumTermCount), corpusOptions: corpus))
        case .weighting:
            return try await GlifiStudioCommandResult(
                session.analyzeTermWeighting(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), scheme: #require(p.scheme),
                    corpusOptions: corpus))
        case .diversity:
            return try await GlifiStudioCommandResult(
                session.analyzeLexicalDiversity(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    threshold: #require(p.threshold),
                    corpusOptions: corpus))
        case .laws:
            return try await GlifiStudioCommandResult(
                session.analyzeLexicalLaws(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    parameters: #require(p.lawParameters), corpusOptions: corpus))
        case .summarize:
            return try await GlifiStudioCommandResult(
                session.analyzeExtractiveSummary(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), budget: #require(p.budget),
                    scheme: #require(p.scheme), method: #require(p.summaryMethod),
                    redundancy: #require(p.redundancy), graphConfiguration: p.graphConfiguration,
                    corpusOptions: corpus))
        case .ngrams:
            return try await GlifiStudioCommandResult(
                session.analyzeNGramFrequencies(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), unit: #require(p.unit),
                    filter: #require(p.filter), maximumRowCount: #require(p.maximumRowCount),
                    corpusOptions: corpus))
        case .bm25:
            return try await GlifiStudioCommandResult(
                session.rankDocumentsBM25(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), query: #require(p.query),
                    k1: #require(p.k1), b: #require(p.b), corpusOptions: corpus))
        case .windowCollocations:
            return try await GlifiStudioCommandResult(
                session.analyzeWindowCollocations(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    options: #require(p.windowOptions),
                    corpusOptions: corpus))
        case .windowNetwork:
            return try await GlifiStudioCommandResult(
                session.analyzeWindowNetwork(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs), window: #require(p.window),
                    minimumLogDice: p.minimumLogDice,
                    usesWeightedJointCount: #require(p.usesWeightedJointCount as Bool?),
                    corpusOptions: corpus))
        case .network:
            return try await GlifiStudioCommandResult(
                session.analyzeLexicalNetwork(
                    sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    options: #require(p.cooccurrenceOptions), corpusOptions: corpus))
        case .sourceText:
            return try await GlifiStudioCommandResult(
                session.sourceText(sourceRevisionID: #require(p.sourceRevisionID)))
        case .passages:
            return try await GlifiStudioCommandResult(
                session.passages(
                    sourceRevisionID: #require(p.sourceRevisionID),
                    selections: #require(p.selections)))
        case .characterCount:
            return try await GlifiStudioCommandResult(
                session.extractedCharacterCount(sourceRevisionID: #require(p.sourceRevisionID)))
        case .exportVisualization:
            return try await GlifiStudioCommandResult(
                session.exportVisualization(#require(p.visualization), to: nativeExportURL))
        case .recutVisualization:
            return try GlifiStudioCommandResult(
                GlifiStudioVisualizationBuilder.recutDendrogram(
                    #require(p.visualization), clusterCount: p.clusterCount, height: p.maximumHeight
                ))
        case .prepareInput:
            return try await GlifiStudioCommandResult(
                GlifiStudioTextAnalytics.prepareProjectInput(
                    session: session, sourceRevisionIDs: #require(p.sourceRevisionIDs),
                    maximumTermCount: #require(p.maximumTermCount),
                    allowsEmptyLexicon: #require(p.allowsEmptyLexicon as Bool?)))
        case .temporal:
            return try await GlifiStudioCommandResult(
                GlifiStudioEvaluationWorkbench.temporal(
                    session: session, assignments: #require(p.assignments).map(\.native),
                    terms: #require(p.terms), configuration: #require(p.configuration)))
        }
    }

    private static func exportSnapshotIfRequested(
        _ projectURL: URL, operation: GlifiStudioProjectOperation, verificationID: String
    ) throws -> URL? {
        guard let path = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"]
        else {
            return nil
        }
        let directory = URL(fileURLWithPath: path).appending(path: "projects/\(verificationID)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: "\(operation).glifi")
        try FileManager.default.copyItem(at: projectURL, to: destination)
        return destination
    }

    private static func nativeExportURL(_ root: URL, verificationID: String) -> URL {
        if let path = ProcessInfo.processInfo.environment["GLIFI_KIT_CLI_PARITY_DIRECTORY"] {
            return URL(fileURLWithPath: path).appending(
                path: "exports/\(verificationID)/exportVisualization")
        }
        return root.appending(path: "native-export")
    }

    private static func exportedFiles(_ root: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        for name in ["view.csv", "view-spec.json", GlifiStudioVisualExport.manifestFileName] {
            files[name] = try Data(contentsOf: root.appending(path: name))
        }
        return files
    }
}

private struct ProjectCommandFixture {
    let root: URL
    let projectURL: URL
    let session: GlifiStudioProjectSession
    let sourceIDs: [String]

    static func create() async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiProjectCommand-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        do {
            let projectURL = root.appending(path: "Commands.glifi")
            let session = try await GlifiStudioService().createProject(at: projectURL)
            let documents = [
                "Casa casa mare. Luna sole.",
                "Casa mare mare mare. Sole sole luna.",
                "Casa casa casa casa. Mare luna.",
                "Mare mare sole sole sole. Luna casa.",
                "Luna luna luna mare. Sole casa casa.",
                "Sole sole sole sole casa. Mare mare luna.",
            ]
            var sourceIDs: [String] = []
            for (index, text) in documents.enumerated() {
                let url = root.appending(path: "source-\(index).txt")
                try Data(text.utf8).write(to: url)
                let result = try await session.importText(at: url, format: .plainText)
                let previous = Set(sourceIDs)
                sourceIDs.append(
                    try #require(
                        result.project.sources.first { !previous.contains($0.sourceRevisionID) }?
                            .sourceRevisionID))
            }
            return .init(root: root, projectURL: projectURL, session: session, sourceIDs: sourceIDs)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}

private struct ProjectCommandTestRequest: Encodable {
    let schema = GlifiStudioProjectCommand.schema
    let schemaVersion = GlifiStudioProjectCommand.schemaVersion
    let operation: GlifiStudioProjectOperation
    let parameters: ProjectCommandTestParameters
}

private struct ProjectCommandTestCorpusOptions: Encodable {
    let diversityWindowSize = 3
    let ngramSizes = [1, 2, 3]
    let maximumDocumentCount = 20
    let maximumSourceByteCount = 1_048_576
    let maximumVocabularySize = 100
    let maximumDistinctNGramCount = 500
    let maximumNonZeroCellCount = 500

    var value: GlifiStudioCorpusAnalysisOptions {
        get throws {
            try .init(
                diversityWindowSize: diversityWindowSize, ngramSizes: ngramSizes,
                maximumDocumentCount: maximumDocumentCount,
                maximumSourceByteCount: maximumSourceByteCount,
                maximumVocabularySize: maximumVocabularySize,
                maximumDistinctNGramCount: maximumDistinctNGramCount,
                maximumNonZeroCellCount: maximumNonZeroCellCount)
        }
    }
}

private struct ProjectCommandTestKeynessOptions: Encodable {
    let maximumHypothesisCount = 100
    let lowExpectedCountThreshold = 3.0
    let confidenceLevel = 0.9

    var value: GlifiStudioKeynessOptions {
        get throws {
            try .init(
                maximumHypothesisCount: maximumHypothesisCount,
                lowExpectedCountThreshold: lowExpectedCountThreshold,
                confidenceLevel: confidenceLevel)
        }
    }
}

private struct ProjectCommandTestTemporalAssignment: Encodable {
    let sourceRevisionID: String
    let value: GlifiStudioTemporalValue
    let provenance: String

    var native: GlifiStudioTemporalAssignment {
        .init(sourceRevisionID: sourceRevisionID, value: value, provenance: provenance)
    }
}

private struct ProjectCommandTestParameters: Encodable {
    var sourceRevisionIDs: [String]?
    var targetSourceRevisionIDs: [String]?
    var referenceSourceRevisionIDs: [String]?
    var corpusOptions: ProjectCommandTestCorpusOptions?
    var keynessOptions: ProjectCommandTestKeynessOptions?
    var partition: [[String]]?
    var groups: [[String]]?
    var metric: GlifiStudioDocumentMetric?
    var options: GlifiStudioGroupComparisonOptions?
    var cooccurrenceOptions: GlifiStudioCooccurrenceOptions?
    var first: GlifiStudioDocumentMetric?
    var second: GlifiStudioDocumentMetric?
    var multivariateMethod: GlifiStudioMultivariateMethod?
    var maximumTermCount: Int?
    var scheme: GlifiStudioTermWeightingScheme?
    var threshold: Double?
    var lawParameters: GlifiStudioLexicalLawsParameters?
    var budget: GlifiStudioSummaryBudget?
    var summaryMethod: GlifiStudioSummaryScoringMethod?
    var redundancy: GlifiStudioSummaryRedundancy?
    var graphConfiguration: GlifiStudioSummaryGraphConfiguration?
    var unit: GlifiStudioNGramUnit?
    var filter: GlifiStudioTermFilter?
    var maximumRowCount: Int?
    var query: String?
    var k1: Double?
    var b: Double?
    var windowOptions: GlifiStudioWindowCooccurrenceOptions?
    var window: GlifiStudioWindowCooccurrenceOptions?
    var minimumLogDice: Double?
    var usesWeightedJointCount: Bool?
    var sourceRevisionID: String?
    var selections: [GlifiStudioPassageSelection]?
    var visualization: GlifiStudioVisualization?
    var clusterCount: Int?
    var maximumHeight: Double?
    var destinationPath: String?
    var allowsEmptyLexicon: Bool?
    var assignments: [ProjectCommandTestTemporalAssignment]?
    var terms: [String]?
    var configuration: GlifiStudioTemporalConfiguration?

    private enum CodingKeys: String, CodingKey {
        case sourceRevisionIDs, targetSourceRevisionIDs, referenceSourceRevisionIDs, corpusOptions
        case keynessOptions, partition, groups, metric, options, first, second, maximumTermCount
        case scheme, threshold, budget, redundancy, graphConfiguration, unit, filter,
            maximumRowCount
        case query, k1, b, window, minimumLogDice, usesWeightedJointCount, sourceRevisionID,
            selections
        case visualization, clusterCount, maximumHeight, destinationPath, allowsEmptyLexicon,
            assignments, terms, configuration
        case method, parameters
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(sourceRevisionIDs, forKey: .sourceRevisionIDs)
        try c.encodeIfPresent(targetSourceRevisionIDs, forKey: .targetSourceRevisionIDs)
        try c.encodeIfPresent(referenceSourceRevisionIDs, forKey: .referenceSourceRevisionIDs)
        try c.encodeIfPresent(corpusOptions, forKey: .corpusOptions)
        try c.encodeIfPresent(keynessOptions, forKey: .keynessOptions)
        try c.encodeIfPresent(partition, forKey: .partition)
        try c.encodeIfPresent(groups, forKey: .groups)
        try c.encodeIfPresent(metric, forKey: .metric)
        if let options { try c.encode(options, forKey: .options) }
        if let cooccurrenceOptions { try c.encode(cooccurrenceOptions, forKey: .options) }
        if let windowOptions { try c.encode(windowOptions, forKey: .options) }
        try c.encodeIfPresent(first, forKey: .first)
        try c.encodeIfPresent(second, forKey: .second)
        if let multivariateMethod { try c.encode(multivariateMethod, forKey: .method) }
        if let summaryMethod { try c.encode(summaryMethod, forKey: .method) }
        try c.encodeIfPresent(maximumTermCount, forKey: .maximumTermCount)
        try c.encodeIfPresent(scheme, forKey: .scheme)
        try c.encodeIfPresent(threshold, forKey: .threshold)
        try c.encodeIfPresent(lawParameters, forKey: .parameters)
        try c.encodeIfPresent(budget, forKey: .budget)
        try c.encodeIfPresent(redundancy, forKey: .redundancy)
        try c.encodeIfPresent(graphConfiguration, forKey: .graphConfiguration)
        try c.encodeIfPresent(unit, forKey: .unit)
        try c.encodeIfPresent(filter, forKey: .filter)
        try c.encodeIfPresent(maximumRowCount, forKey: .maximumRowCount)
        try c.encodeIfPresent(query, forKey: .query)
        try c.encodeIfPresent(k1, forKey: .k1)
        try c.encodeIfPresent(b, forKey: .b)
        try c.encodeIfPresent(window, forKey: .window)
        try c.encodeIfPresent(minimumLogDice, forKey: .minimumLogDice)
        try c.encodeIfPresent(usesWeightedJointCount, forKey: .usesWeightedJointCount)
        try c.encodeIfPresent(sourceRevisionID, forKey: .sourceRevisionID)
        try c.encodeIfPresent(selections, forKey: .selections)
        try c.encodeIfPresent(visualization, forKey: .visualization)
        try c.encodeIfPresent(clusterCount, forKey: .clusterCount)
        try c.encodeIfPresent(maximumHeight, forKey: .maximumHeight)
        try c.encodeIfPresent(destinationPath, forKey: .destinationPath)
        try c.encodeIfPresent(allowsEmptyLexicon, forKey: .allowsEmptyLexicon)
        try c.encodeIfPresent(assignments, forKey: .assignments)
        try c.encodeIfPresent(terms, forKey: .terms)
        try c.encodeIfPresent(configuration, forKey: .configuration)
    }
}
