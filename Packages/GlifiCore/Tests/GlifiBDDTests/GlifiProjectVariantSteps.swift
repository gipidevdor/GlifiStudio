// SPDX-License-Identifier: BSD-3-Clause

import CucumberSwiftTesting
import Foundation
import GlifiKit
import Testing

@MainActor
private final class BDDProjectVariantWorld {
    var root: URL?
    var session: GlifiStudioProjectSession?
    var sourceIDs: [String] = []
    var request = Data()
    var result: Data?
    var failure: GlifiStudioFailure?
    var baseline: GlifiStudioProjectSnapshot?
    var variant = ""

    private let texts = [
        "Casa casa mare. Luna sole.",
        "Casa mare mare mare. Sole sole luna.",
        "Casa casa casa casa. Mare luna.",
        "Mare mare sole sole sole. Luna casa.",
        "Luna luna luna mare. Sole casa casa.",
        "Sole sole sole sole casa. Mare mare luna.",
    ]

    var projectURL: URL { get throws { try #require(root).appending(path: "Project.glifi") } }
    var destination: URL { get throws { try #require(root).appending(path: "visual-export") } }

    func prepare(_ variant: String) async throws {
        self.variant = variant
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "GlifiBDDProjectVariants-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        root = directory
        let active = try await GlifiStudioService().createProject(at: projectURL)
        session = active
        for (index, text) in texts.enumerated() {
            let url = directory.appending(path: "source-\(index).txt")
            try Data(text.utf8).write(to: url)
            let imported = try await active.importText(at: url, format: .plainText)
            let old = Set(sourceIDs)
            sourceIDs.append(
                try #require(
                    imported.project.sources.first {
                        !old.contains($0.sourceRevisionID)
                    }
                ).sourceRevisionID)
        }
        try #require(sourceIDs.count == 6)
        let operation = try #require(
            GlifiStudioProjectOperation.allCases.first { String(describing: $0) == variant })
        request = try JSONSerialization.data(
            withJSONObject: [
                "schema": GlifiStudioProjectCommand.schema, "schemaVersion": 1,
                "operation": operation.rawValue, "parameters": try await parameters(operation),
            ], options: [.sortedKeys])
        baseline = try await active.snapshot()
    }

    func execute(_ phase: String) async throws {
        result = nil
        failure = nil
        let active = try #require(session)
        var fields = try #require(BDDVariantAssertions.object(request) as? [String: Any])
        if phase == "JSON-invalido" { fields["unexpected_BDD"] = true }
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        do {
            if phase == "precancellata" {
                let task = Task {
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await GlifiStudioProjectCommand.execute(json: data, session: active)
                }
                result = try await task.value.json
            } else {
                try #require(phase == "nominale" || phase == "JSON-invalido")
                result = try await GlifiStudioProjectCommand.execute(json: data, session: active)
                    .json
            }
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    func verifyReuseAndReopening() async throws {
        let active = try #require(session)
        let before = try #require(baseline)
        let original = try #require(result)
        let warmed = try await active.snapshot()
        let originalObject = try BDDVariantAssertions.object(original)
        let persistedIdentity = artifactID(originalObject)
        let mustPersist = ![
            "sourceText", "characterCount", "passages", "prepareInput", "temporal",
            "exportVisualization",
        ].contains(variant)
        if mustPersist {
            let persistedIdentity = try #require(persistedIdentity)
            try #require(!persistedIdentity.isEmpty)
            #expect(warmed.artifactCount > before.artifactCount)
            let repeated = try await GlifiStudioProjectCommand.execute(
                json: request, session: active)
            #expect(artifactID(try BDDVariantAssertions.object(repeated.json)) == persistedIdentity)
            #expect(try scientificBytes(repeated.json) == scientificBytes(original))
            #expect(try await active.snapshot() == warmed)
        } else {
            // Source reads, preparation, temporal evaluation and export have no analytical cache entry.
            #expect(persistedIdentity == nil)
            #expect(warmed == before)
        }
        if variant == "exportVisualization" { try verifyExport() }
        await active.close()
        let reopened = try await GlifiStudioService().openProject(at: projectURL)
        session = reopened
        #expect(try await reopened.snapshot() == warmed)
        if variant != "exportVisualization" {
            let repeated = try await GlifiStudioProjectCommand.execute(
                json: request, session: reopened)
            #expect(try scientificBytes(repeated.json) == scientificBytes(original))
            if let persistedIdentity {
                #expect(
                    artifactID(try BDDVariantAssertions.object(repeated.json)) == persistedIdentity)
            }
            #expect(try await reopened.snapshot() == warmed)
        } else {
            try verifyExport()
        }
        #expect(failure == nil)
    }

    func verifyUnchanged() async throws {
        #expect(try await #require(session).snapshot() == #require(baseline))
        #expect(!FileManager.default.fileExists(atPath: try destination.path))
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: #require(root).path)
                .allSatisfy { !$0.hasPrefix(".glifi-visual-export-") })
    }

    func factObject() throws -> Any {
        let value = try BDDVariantAssertions.object(#require(result))
        guard var fields = value as? [String: Any] else { return value }
        if variant == "bm25" {
            let ranking = try #require(fields["ranking"] as? [[String: Any]])
            let source = try #require(
                ranking.first { $0["sourceRevisionID"] as? String == sourceIDs.first })
            fields["bddFirstSourceScore"] = try #require(source["score"])
            fields["bddFirstSourceLength"] = try #require(source["length"])
        }
        if variant == "summarize" {
            let selected = try #require(fields["selected"] as? [[String: Any]])
            try #require(!selected.isEmpty)
            for excerpt in selected {
                let sentence = try #require(excerpt["sentence"] as? [String: Any])
                let id = try #require(sentence["sourceRevisionID"] as? String)
                let index = try #require(sourceIDs.firstIndex(of: id))
                let bytes = Array(texts[index].utf8)
                let start = try #require(sentence["startUTF8"] as? Int)
                let end = try #require(sentence["endUTF8"] as? Int)
                try #require(start >= 0 && start <= end && end <= bytes.count)
                #expect(
                    String(decoding: bytes[start..<end], as: UTF8.self) == excerpt["text"]
                        as? String)
            }
        }
        return fields
    }

    func exportBoundary(_ field: String) async throws {
        try #require(variant == "exportVisualization")
        result = nil
        failure = nil
        var fields = try #require(BDDVariantAssertions.object(request) as? [String: Any])
        var parameters = try #require(fields["parameters"] as? [String: Any])
        var view = try #require(parameters["visualization"] as? [String: Any])
        view[field] = "unrelated-original-bdd-value"
        parameters["visualization"] = view
        fields["parameters"] = parameters
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        do {
            result = try await GlifiStudioProjectCommand.execute(
                json: data, session: #require(session)
            ).json
        } catch let observed as GlifiStudioFailure {
            failure = observed
        }
    }

    func cleanup() async throws {
        await session?.close()
        session = nil
        if let root { try FileManager.default.removeItem(at: root) }
        root = nil
    }

    private func parameters(_ operation: GlifiStudioProjectOperation) async throws -> [String: Any]
    {
        let ids = sourceIDs
        let groups = [Array(ids[0..<2]), Array(ids[2..<4]), Array(ids[4..<6])]
        let corpus: [String: Any] = [
            "diversityWindowSize": 3, "ngramSizes": [1, 2, 3], "maximumDocumentCount": 20,
            "maximumSourceByteCount": 1_048_576, "maximumVocabularySize": 100,
            "maximumDistinctNGramCount": 500, "maximumNonZeroCellCount": 500,
        ]
        var fields: [String: Any] = ["sourceRevisionIDs": ids, "corpusOptions": corpus]
        switch operation {
        case .corpus: fields = ["corpusOptions": corpus]
        case .keyness, .similarity:
            fields = [
                "targetSourceRevisionIDs": Array(ids[0..<3]),
                "referenceSourceRevisionIDs": Array(ids[3..<6]), "corpusOptions": corpus,
            ]
        case .association: break
        case .dispersion: fields["partition"] = groups
        case .groupMetric, .postHoc:
            fields = [
                "groups": groups, "corpusOptions": corpus,
                "metric": try wire(
                    operation == .groupMetric
                        ? GlifiStudioDocumentMetric.lexicalTokenCount
                        : .termRelativeFrequency("casa")),
            ]
            if operation == .groupMetric {
                fields["options"] = try wire(
                    GlifiStudioGroupComparisonOptions(
                        confidenceLevel: 0.9, bootstrapResampleCount: 50,
                        permutationMonteCarloCount: 50, resamplingSeed: 42,
                        contrasts: [[1, -0.5, -0.5]]))
            }
        case .collocations, .network:
            fields["options"] = try wire(
                GlifiStudioCooccurrenceOptions(
                    maximumTermCount: 4, minimumJointCount: 1, maximumPairCount: 6))
        case .correlate, .paired:
            fields["first"] = try wire(GlifiStudioDocumentMetric.lexicalTokenCount)
            fields["second"] = try wire(GlifiStudioDocumentMetric.termRelativeFrequency("casa"))
        case .multivariate:
            fields["method"] = try wire(
                GlifiStudioMultivariateMethod.principalComponents(scaled: true))
            fields["maximumTermCount"] = 4
        case .weighting:
            fields["scheme"] = try wire(
                GlifiStudioTermWeightingScheme(
                    termFrequency: "TF-sublinear-v1", inverseDocumentFrequency: "IDF-smooth-v1",
                    normalization: "RowNorm-L2-v1"))
        case .diversity: fields["threshold"] = 0.65
        case .laws:
            fields["parameters"] = try wire(
                GlifiStudioLexicalLawsParameters(
                    checkpointCount: 5, zipfFirstRank: 1, zipfLastRank: 4, rankRowLimit: 10))
        case .summarize:
            fields["budget"] = try wire(
                GlifiStudioSummaryBudget(unit: "Budget-sentences-v1", limit: 3))
            fields["scheme"] = try wire(GlifiStudioTermWeightingScheme.summaryStandard)
            fields["method"] = try wire(
                GlifiStudioSummaryScoringMethod(identifier: "TextRankSentence-configurable-v1"))
            fields["redundancy"] = try wire(
                GlifiStudioSummaryRedundancy.maximalMarginalRelevance(lambda: 0.7))
            fields["graphConfiguration"] = try wire(
                GlifiStudioSummaryGraphConfiguration(
                    damping: 0.7, tolerance: 1e-8, maximumIterations: 200, similarityThreshold: 0.2)
            )
        case .ngrams:
            fields["unit"] = try wire(GlifiStudioNGramUnit(kind: "word", n: 2))
            fields["filter"] = try wire(
                GlifiStudioTermFilter(
                    stopwords: ["sole"], minimumLength: 2, minimumCount: 1,
                    minimumDocumentFrequency: 1, maximumDocumentProportion: 1))
            fields["maximumRowCount"] = 20
        case .bm25:
            fields["query"] = "casa mare"
            fields["k1"] = 1.5
            fields["b"] = 0.6
        case .windowCollocations:
            fields["options"] = try wire(
                GlifiStudioWindowCooccurrenceOptions(
                    leftSpan: 1, rightSpan: 2, crossesSentences: true,
                    includesSelfPairs: false, minimumJointCount: 1, maximumPairCount: 10,
                    weightsByInverseDistance: true, maximumPositionsPerPair: 3))
        case .windowNetwork:
            fields["window"] = try wire(
                GlifiStudioWindowCooccurrenceOptions(
                    leftSpan: 2, rightSpan: 1, crossesSentences: false,
                    includesSelfPairs: false, minimumJointCount: 1, maximumPairCount: 8,
                    weightsByInverseDistance: true, maximumPositionsPerPair: 4))
            fields["minimumLogDice"] = 0
            fields["usesWeightedJointCount"] = true
        case .sourceText, .characterCount: fields = ["sourceRevisionID": ids[0]]
        case .passages:
            fields = [
                "sourceRevisionID": ids[0],
                "selections": try wire([
                    GlifiStudioPassageSelection.sentences(first: 1, last: 1),
                    .characters(start: 0, end: 4),
                ]),
            ]
        case .exportVisualization:
            let result = try await #require(session).analyzeMultivariate(
                sourceRevisionIDs: ids, method: .principalComponents(scaled: true),
                maximumTermCount: 4)
            let view = try #require(try GlifiStudioVisualizationBuilder.factorPlot(result))
            fields = ["visualization": try wire(view), "destinationPath": try destination.path]
        case .prepareInput:
            fields = ["sourceRevisionIDs": ids, "maximumTermCount": 3, "allowsEmptyLexicon": true]
        case .temporal:
            let assignments = try ids.enumerated().map { index, id -> [String: Any] in
                [
                    "sourceRevisionID": id,
                    "value": try wire(
                        GlifiStudioTemporalValue.civilMonth(year: 2024, month: index + 1)),
                    "provenance": "bdd-original-month-\(index)",
                ]
            }
            fields = [
                "assignments": assignments, "terms": ["casa", "mare"],
                "configuration": try wire(
                    GlifiStudioTemporalConfiguration(
                        basis: .civilDates, granularity: .month,
                        origin: try .init(year: 2024, month: 1, day: 1), bucketWidth: 1,
                        bucketCount: 6,
                        missingPolicy: .separate, outsidePolicy: .exclude)),
            ]
        }
        return fields
    }

    private func artifactID(_ value: Any) -> String? {
        guard let object = value as? [String: Any] else { return nil }
        return object["artifactID"] as? String
            ?? (object["lineage"] as? [String: Any])?["artifactID"] as? String
    }

    private func scientificBytes(_ data: Data) throws -> Data {
        var object = try BDDVariantAssertions.object(data)
        if var fields = object as? [String: Any] {
            fields.removeValue(forKey: "sourceGeneration")
            fields.removeValue(forKey: "generation")
            if var lineage = fields["lineage"] as? [String: Any] {
                lineage.removeValue(forKey: "sourceGeneration")
                lineage.removeValue(forKey: "generation")
                fields["lineage"] = lineage
            }
            object = fields
        }
        return try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
    }

    private func verifyExport() throws {
        let directory = try destination
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        try #require(
            Set(names) == ["view.csv", "view-spec.json", GlifiStudioVisualExport.manifestFileName])
        var files: [String: Data] = [:]
        for name in names { files[name] = try Data(contentsOf: directory.appending(path: name)) }
        _ = try GlifiStudioVisualExport.verify(files)
        let fields = try #require(BDDVariantAssertions.object(request) as? [String: Any])
        let parameters = try #require(fields["parameters"] as? [String: Any])
        let expected = try #require(parameters["visualization"] as? NSDictionary)
        let specificationBytes = try #require(files["view-spec.json"])
        let specification = try BDDVariantAssertions.object(specificationBytes)
        let actual = try #require(specification as? NSDictionary)
        #expect(actual == expected)
    }

    private func wire<Value: Encodable>(_ value: Value) throws -> Any {
        try BDDVariantAssertions.object(BDDVariantAssertions.encode(value))
    }
}

@MainActor
private var projectVariantWorld: BDDProjectVariantWorld {
    Scenario.state(BDDProjectVariantWorld.init)
}

@MainActor
func registerProjectVariantSteps() {
    AfterScenario { _ in try await projectVariantWorld.cleanup() }
    Given("la variante completa di progetto {string} sul corpus originale") { match, _ in
        try await projectVariantWorld.prepare(match.first(\.string))
    }
    When("eseguo la variante completa di progetto in fase {word}") { match, _ in
        try await projectVariantWorld.execute(match.first(\.word))
    }
    Then(#/^il risultato di progetto rispetta i valori JSON (.+)$/#) { match, _ in
        #expect(projectVariantWorld.failure == nil)
        try BDDVariantAssertions.expectFacts(
            projectVariantWorld.factObject(),
            json: String(match.1))
    }
    Then("il progetto conserva letture oppure riusa la stessa analisi anche dopo riapertura") {
        _, _ in
        try await projectVariantWorld.verifyReuseAndReopening()
    }
    Then("la variante di progetto fallisce con codice {string} e categoria {string}") { match, _ in
        try BDDVariantAssertions.expectFailure(
            projectVariantWorld.failure, result: projectVariantWorld.result,
            code: match[\.string, index: 0], category: match[\.string, index: 1])
        try await projectVariantWorld.verifyUnchanged()
    }
    When("contraddico il metadato sorgente della vista {string}") { match, _ in
        try await projectVariantWorld.exportBoundary(match.first(\.string))
    }
    Then("l'export contraddittorio conserva progetto e filesystem") { _, _ in
        try BDDVariantAssertions.expectFailure(
            projectVariantWorld.failure, result: projectVariantWorld.result,
            code: "visual-export.source-mismatch", category: "invalidInput", operation: "export")
        try await projectVariantWorld.verifyUnchanged()
    }
}
