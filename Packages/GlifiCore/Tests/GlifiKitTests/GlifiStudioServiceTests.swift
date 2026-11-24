// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

@Test("GlifiKit espone lo stato senza rivelare il tipo del motore")
func serviceExposesEngineStatus() async {
    let service = GlifiStudioService()

    #expect(await service.status() == .ready)
}

@Test("GlifiKit profila un file senza esporre i tipi interni del motore")
func serviceProfilesAFile() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: "glifi-kit-profile-\(UUID().uuidString).txt")
    try Data("Uno due due.".utf8).write(to: fileURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let profile = try await GlifiStudioService().profileText(at: fileURL, format: .plainText)

    #expect(profile.lexicalTokenCount == 3)
    #expect(profile.typeCount == 2)
    #expect(profile.topTerms.first == GlifiStudioTermFrequency(term: "due", count: 2))
}

@Test("GlifiKit profila Markdown attraverso la rappresentazione estratta")
func serviceProfilesMarkdown() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: "glifi-kit-profile-\(UUID().uuidString).md")
    try Data("# Titolo\nUna **fonte** affidabile.".utf8).write(to: fileURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let profile = try await GlifiStudioService().profileText(at: fileURL, format: .markdown)

    #expect(profile.lexicalTokenCount == 4)
    #expect(profile.typeCount == 4)
    #expect(profile.topTerms.contains(GlifiStudioTermFrequency(term: "fonte", count: 1)))
}

@Test("GlifiKit espone failure tipizzate e localizzabili")
func serviceMapsFailures() async {
    let missingURL = FileManager.default.temporaryDirectory
        .appending(path: "glifi-missing-\(UUID().uuidString).txt")

    do {
        _ = try await GlifiStudioService().profileText(at: missingURL, format: .plainText)
        Issue.record("Era attesa una failure")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "file.unreadable")
        #expect(failure.category == "transientIO")
        #expect(failure.messageKey == "failure.file.unreadable")
    } catch {
        Issue.record("Tipo di errore inatteso")
    }

    do {
        _ = try GlifiStudioCorpusAnalysisOptions(
            diversityWindowSize: 0,
            ngramSizes: [6],
            maximumDocumentCount: 1,
            maximumSourceByteCount: 1,
            maximumVocabularySize: 1,
            maximumDistinctNGramCount: 1,
            maximumNonZeroCellCount: 1
        )
        Issue.record("Erano attese opzioni analitiche non valide")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "analysis.invalid-options")
        #expect(failure.category == "invalidInput")
        #expect(failure.operation == "analyze")
    } catch {
        Issue.record("Tipo di errore inatteso")
    }
}

@Test("GlifiKit crea, importa, riapre e chiude una sessione di progetto")
func serviceProjectSessionRoundTrip() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitProjectTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Progetto.glifi", directoryHint: .isDirectory)
    let sourceURL = root.appending(path: "fonte.txt")
    try Data("Una fonte italiana affidabile.".utf8).write(to: sourceURL)

    let service = GlifiStudioService()
    let session = try await service.createProject(at: projectURL)
    #expect(try await session.snapshot().generation == 0)

    let result = try await session.importText(at: sourceURL, format: .plainText)
    #expect(result.project.generation == 1)
    #expect(result.project.sourceCount == 1)
    #expect(result.project.artifactCount == 0)
    #expect(result.profile.lexicalTokenCount == 4)

    let query = try await session.query("normalized:fonte")
    #expect(query.generation == 1)
    #expect(query.matchedSourceCount == 1)
    #expect(query.matches.count == 1)
    #expect(query.matches[0].match == "fonte")
    #expect(query.matches[0].coordinateSpace == "extractedUTF8")
    #expect(query.matches[0].sourceRanges.count == 1)
    #expect(query.matches[0].sourceRanges[0].start == 4)
    #expect(query.matches[0].sourceRanges[0].end == 9)

    let sourceText = try await session.sourceText(
        sourceRevisionID: query.matches[0].sourceRevisionID
    )
    #expect(sourceText.text == "Una fonte italiana affidabile.")
    #expect(sourceText.byteCount == Data("Una fonte italiana affidabile.".utf8).count)
    let highlight = query.matches[0].sourceRanges[0]
    let utf8 = Array(sourceText.text.utf8)
    #expect(
        String(decoding: utf8[highlight.start..<highlight.end], as: UTF8.self) == "fonte"
    )

    let analysis = try await session.analyzeCorpus()
    #expect(analysis.projectID == result.project.projectID)
    #expect(analysis.sourceGeneration == 1)
    #expect(analysis.generation == 2)
    #expect(analysis.artifactID.hasPrefix("artifact:sha256:"))
    #expect(analysis.analysisNodeID.hasPrefix("analysis-node:sha256:"))
    #expect(analysis.analysisIdentifier == "corpus-profile-it-v1")
    #expect(analysis.corpusDigest.hasPrefix("sha256:"))
    #expect(analysis.documentCount == 1)
    #expect(analysis.lexicalTokenCount == 4)
    #expect(analysis.terms.first?.term == "affidabile")
    #expect(analysis.matrix.cells.count == 4)
    let analyzedSnapshot = try await session.snapshot()
    #expect(analyzedSnapshot.generation == 2)
    #expect(analyzedSnapshot.artifactCount == 1)
    await session.close()

    await #expect(throws: GlifiStudioFailure.self) {
        try await session.snapshot()
    }

    let reopened = try await service.openProject(at: projectURL)
    #expect(try await reopened.snapshot() == analyzedSnapshot)
}

@Test("GlifiKit confronta due gruppi espliciti senza esporre dettagli del package")
func serviceComparesExplicitSourceGroups() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitKeynessTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Confronto.glifi", directoryHint: .isDirectory)
    let targetURL = root.appending(path: "target.txt")
    let referenceURL = root.appending(path: "reference.txt")
    try Data("casa casa mare".utf8).write(to: targetURL)
    try Data("casa città città".utf8).write(to: referenceURL)

    let session = try await GlifiStudioService().createProject(at: projectURL)
    let first = try await session.importText(at: targetURL, format: .plainText)
    let second = try await session.importText(at: referenceURL, format: .plainText)
    let targetID = try #require(first.project.sources.first?.sourceRevisionID)
    let referenceID = try #require(
        second.project.sources.first(where: { $0.sourceRevisionID != targetID })?
            .sourceRevisionID
    )

    let result = try await session.compareKeyness(
        targetSourceRevisionIDs: [targetID],
        referenceSourceRevisionIDs: [referenceID]
    )

    #expect(result.projectID == second.project.projectID)
    #expect(result.sourceGeneration == 2)
    #expect(result.generation == 5)
    #expect(result.artifactID.hasPrefix("artifact:sha256:"))
    #expect(result.analysisNodeID.hasPrefix("analysis-node:sha256:"))
    #expect(result.comparisonIdentifier == "keyness-gtest-fisher-ha-ci-bh-v2")
    #expect(result.comparisonDigest.hasPrefix("sha256:"))
    #expect(result.targetTokenCount == 3)
    #expect(result.referenceTokenCount == 3)
    #expect(result.terms.map(\.term) == ["città", "mare", "casa"])
    #expect(result.terms.allSatisfy { 0...1 ~= $0.qValue })
    #expect(result.terms.allSatisfy { $0.hasLowExpectedCount })

    do {
        _ = try await session.compareKeyness(
            targetSourceRevisionIDs: ["source-revision:00000000-0000-0000-0000-000000000099"],
            referenceSourceRevisionIDs: [referenceID]
        )
        Issue.record("Era attesa una revisione assente")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "keyness.source-not-found")
        #expect(failure.retainedState == "lastCommittedGeneration")
    }

    do {
        _ = try await session.compareKeyness(
            targetSourceRevisionIDs: ["non-valido"],
            referenceSourceRevisionIDs: [referenceID]
        )
        Issue.record("Era atteso un identificatore non valido")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "keyness.invalid-source-identifier")
        #expect(failure.operation == "analyze")
    }
    let finalSnapshot = try await session.snapshot()
    #expect(finalSnapshot.generation == 5)
    #expect(finalSnapshot.sourceCount == second.project.sourceCount)
    #expect(finalSnapshot.artifactCount == 3)
}

@Test("GlifiKit confronta la similarità di corpus fra due gruppi espliciti")
func serviceComparesCorpusSimilarity() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitSimilarityTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Similarita.glifi", directoryHint: .isDirectory)
    let targetURL = root.appending(path: "target.txt")
    let referenceURL = root.appending(path: "reference.txt")
    // Stessa fixture del confronto keyness: target={casa:2,mare:1},
    // reference={casa:1,città:2}. Valori attesi calcolati indipendentemente:
    // vocabolario unione ordinato [casa,città,mare], vettori relativi
    // [2/3,0,1/3] e [1/3,2/3,0] → coseno=(2/9)/(5/9)=2/5=0,4 esatto;
    // insiemi {casa,mare} e {casa,città} → jaccard=1/3, dice=2/4=0,5 esatti.
    try Data("casa casa mare".utf8).write(to: targetURL)
    try Data("casa città città".utf8).write(to: referenceURL)

    let session = try await GlifiStudioService().createProject(at: projectURL)
    let first = try await session.importText(at: targetURL, format: .plainText)
    let second = try await session.importText(at: referenceURL, format: .plainText)
    let targetID = try #require(first.project.sources.first?.sourceRevisionID)
    let referenceID = try #require(
        second.project.sources.first(where: { $0.sourceRevisionID != targetID })?
            .sourceRevisionID
    )

    let result = try await session.compareSimilarity(
        targetSourceRevisionIDs: [targetID],
        referenceSourceRevisionIDs: [referenceID]
    )

    #expect(result.projectID == second.project.projectID)
    #expect(result.artifactID.hasPrefix("artifact:sha256:"))
    #expect(result.analysisNodeID.hasPrefix("analysis-node:sha256:"))
    #expect(result.comparisonIdentifier == "corpus-term-similarity-v3")
    #expect(result.comparisonDigest.hasPrefix("sha256:"))
    #expect(result.targetTypeCount == 2)
    #expect(result.referenceTypeCount == 2)
    #expect(result.sharedTypeCount == 1)
    #expect(abs(result.cosineSimilarity - 0.4) < 1e-9)
    #expect(abs(result.jaccardSimilarity - 1.0 / 3.0) < 1e-9)
    #expect(abs(result.diceSimilarity - 0.5) < 1e-9)

    let reused = try await session.compareSimilarity(
        targetSourceRevisionIDs: [targetID],
        referenceSourceRevisionIDs: [referenceID]
    )
    #expect(reused.artifactID == result.artifactID)
    #expect(reused.generation == result.generation)

    do {
        _ = try await session.compareSimilarity(
            targetSourceRevisionIDs: ["non-valido"],
            referenceSourceRevisionIDs: [referenceID]
        )
        Issue.record("Era atteso un identificatore non valido")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "corpus-similarity.invalid-source-identifier")
        #expect(failure.operation == "analyze")
    }
}

@Test("GlifiKit persiste e riusa le analisi derivate su gruppi espliciti di fonti")
func serviceDerivesPersistedAnalyses() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitDerivedTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Derivate.glifi", directoryHint: .isDirectory)
    let session = try await GlifiStudioService().createProject(at: projectURL)
    var ids: [String] = []
    for (index, text) in ["alfa beta gamma", "alfa beta", "gamma", "alfa alfa delta delta"]
        .enumerated()
    {
        let fileURL = root.appending(path: "fonte-\(index).txt")
        try Data(text.utf8).write(to: fileURL)
        let imported = try await session.importText(at: fileURL, format: .plainText)
        let known = Set(ids)
        let created = try #require(
            imported.project.sources.first { !known.contains($0.sourceRevisionID) }
        )
        ids.append(created.sourceRevisionID)
    }
    let firstThree = Array(ids.prefix(3))

    let association = try await session.analyzeAssociation(sourceRevisionIDs: firstThree)
    #expect(association.analysisIdentifier == "corpus-document-term-association-v2")
    #expect(association.lineage.artifactID.hasPrefix("artifact:sha256:"))
    #expect(association.includedDocumentCount == 3)
    #expect(association.monteCarloPValue.map { $0 > 0 && $0 <= 1 } == true)
    let reusedAssociation = try await session.analyzeAssociation(sourceRevisionIDs: firstThree)
    #expect(reusedAssociation.lineage.artifactID == association.lineage.artifactID)
    #expect(reusedAssociation.lineage.generation == association.lineage.generation)
    #expect(reusedAssociation.chiSquareStatistic == association.chiSquareStatistic)

    let dispersion = try await session.analyzeDispersion(sourceRevisionIDs: firstThree)
    #expect(dispersion.analysisIdentifier == "corpus-term-dispersion-v2")
    #expect(dispersion.terms.count == 3)
    #expect(!dispersion.equalSizePartition)

    let collocations = try await session.analyzeCollocations(sourceRevisionIDs: firstThree)
    #expect(collocations.selectedTerms == ["alfa", "beta", "gamma"])
    #expect(collocations.pairs.first?.jointCount == 2)
    let network = try await session.analyzeLexicalNetwork(sourceRevisionIDs: firstThree)
    #expect(network.edgeCount == 3)
    #expect(network.analysisIdentifier == "corpus-document-cooccurrence-network-v2")
    let alfaBetaEdge = try #require(
        network.edges.first { $0.source == "alfa" && $0.target == "beta" }
    )
    #expect(alfaBetaEdge.supportingSourceRevisionIDs == Array(ids.prefix(2)).sorted())
    #expect(network.summary.weakComponentCount == 1)
    #expect(network.nodes.count == 3)
    let reusedNetwork = try await session.analyzeLexicalNetwork(sourceRevisionIDs: firstThree)
    #expect(reusedNetwork.lineage.artifactID == network.lineage.artifactID)

    let comparison = try await session.compareGroupMetric(
        groups: [Array(ids.prefix(2)), Array(ids.suffix(2))],
        metric: .lexicalTokenCount
    )
    #expect(comparison.metricIdentifier == "document-lexical-token-count-v1")
    #expect(comparison.groups.map(\.documentCount) == [2, 2])
    #expect(comparison.anova != nil)
    // Lunghezze [3,2] e [1,4], senza tie: ranghi 3,2 → R₁=5, U₁=2=U₂, esatto p=1;
    // Kruskal–Wallis: R=5 e 5, H=12/20·(25/2+25/2)-15=0.
    #expect(comparison.mannWhitney?.methodIdentifier == "exact")
    #expect(comparison.mannWhitney?.u1 == 2)
    #expect(comparison.mannWhitney?.pValue == 1)
    #expect(comparison.kruskalWallis?.degreesOfFreedom == 1)
    #expect(comparison.kruskalWallis?.hStatistic == 0)

    // Lunghezze [3,2,1,4] e frequenze di «alfa» [1/3,1/2,0,1/2]: medie 5/2 e 1/3,
    // Sxy=2/3, Sxx=5, Syy=1/6 → r=(2/3)·√(6/5), df=2.
    let correlation = try await session.correlateMetrics(
        sourceRevisionIDs: ids,
        first: .lexicalTokenCount,
        second: .termRelativeFrequency("alfa")
    )
    #expect(correlation.analysisIdentifier == "document-metric-correlation-v2")
    #expect(correlation.pairCount == 4)
    let pearson = try #require(correlation.pearson)
    #expect(abs(pearson.coefficient - 2.0 / 3.0 * (6.0 / 5.0).squareRoot()) < 1e-12)
    #expect(pearson.degreesOfFreedom == 2)
    let reusedCorrelation = try await session.correlateMetrics(
        sourceRevisionIDs: ids,
        first: .lexicalTokenCount,
        second: .termRelativeFrequency("alfa")
    )
    #expect(reusedCorrelation.lineage.artifactID == correlation.lineage.artifactID)
    #expect(reusedCorrelation.lineage.generation == correlation.lineage.generation)
    do {
        _ = try await session.correlateMetrics(
            sourceRevisionIDs: Array(ids.prefix(2)),
            first: .lexicalTokenCount,
            second: .lexicalTokenCount
        )
        Issue.record("Due fonti non bastano per una correlazione")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "metric-correlation.insufficient-sources")
    }

    // Frequenze di «alfa» [1/3,1/2,0,1/2] e «beta» [1/3,1/2,0,0]: differenze [0,0,0,1/2],
    // d̄=1/8, s_d=1/4, t=1 con ν=3; Wilcoxon scarta tre zeri → asintotico, W⁺=1, z=0, p=1.
    let paired = try await session.comparePairedMetrics(
        sourceRevisionIDs: ids,
        first: .termRelativeFrequency("alfa"),
        second: .termRelativeFrequency("beta")
    )
    #expect(paired.analysisIdentifier == "document-metric-paired-comparison-v1")
    #expect(paired.pairCount == 4)
    #expect(abs(paired.meanDifference - 0.125) < 1e-12)
    #expect(abs(try #require(paired.tStatistic) - 1) < 1e-12)
    #expect(paired.degreesOfFreedom == 3)
    #expect(abs(try #require(paired.standardizedMeanDifference) - 0.5) < 1e-12)
    #expect(paired.droppedZeroCount == 3)
    #expect(paired.wilcoxonMethodIdentifier == "asymptotic-tie-corrected-continuity")
    #expect(paired.wilcoxonPValue == 1)
    let reusedPaired = try await session.comparePairedMetrics(
        sourceRevisionIDs: ids,
        first: .termRelativeFrequency("alfa"),
        second: .termRelativeFrequency("beta")
    )
    #expect(reusedPaired.lineage.artifactID == paired.lineage.artifactID)

    let multivariate = try await session.analyzeMultivariate(
        sourceRevisionIDs: ids,
        method: .correspondence
    )
    #expect(multivariate.methodIdentifier == "CA-SVD-v1")
    #expect(multivariate.terms == ["alfa", "beta", "delta", "gamma"])
    #expect(abs(multivariate.axisShares.reduce(0, +) - 1) < 1e-12)
    #expect(multivariate.rowCoordinates.count == 4)
    let clustering = try await session.analyzeMultivariate(
        sourceRevisionIDs: ids,
        method: .kMeans(clusterCount: 2, seed: 9, restarts: 3)
    )
    #expect(clustering.clusterAssignments?.count == 4)
    #expect(clustering.seed == 9)
    let reusedClustering = try await session.analyzeMultivariate(
        sourceRevisionIDs: ids,
        method: .kMeans(clusterCount: 2, seed: 9, restarts: 3)
    )
    #expect(reusedClustering.lineage.artifactID == clustering.lineage.artifactID)
    do {
        _ = try await session.analyzeMultivariate(
            sourceRevisionIDs: ids,
            method: .hierarchical(linkage: "centroid", clusterCount: 2)
        )
        Issue.record("Il linkage non dichiarato non è stato rifiutato")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "multivariate.invalid-linkage")
    }

    // Gruppi [3,2], [1], [4]: ogni coppia contiene un gruppo di un solo documento,
    // quindi la famiglia Welch è vuota e quella Mann–Whitney ha tre test.
    let postHoc = try await session.postHocGroupMetric(
        groups: [Array(ids.prefix(2)), [ids[2]], [ids[3]]],
        metric: .lexicalTokenCount
    )
    #expect(postHoc.analysisIdentifier == "document-metric-pairwise-posthoc-v2")
    #expect(postHoc.welchFamilySize == 0)
    #expect(postHoc.mannWhitneyFamilySize == 3)
    #expect(postHoc.pairs.count == 3)
    let reusedPostHoc = try await session.postHocGroupMetric(
        groups: [Array(ids.prefix(2)), [ids[2]], [ids[3]]],
        metric: .lexicalTokenCount
    )
    #expect(reusedPostHoc.lineage.artifactID == postHoc.lineage.artifactID)
    #expect(reusedPostHoc.lineage.generation == postHoc.lineage.generation)

    // «alfa beta gamma» + «alfa beta», finestra ±1: 4+2 coppie ordinate, M=6.
    // (alfa,beta): a=2, b=2-2=0, c=3-2=1, d=6-2-0-1=3.
    let window = try GlifiStudioWindowCooccurrenceOptions(
        leftSpan: 1,
        rightSpan: 1,
        crossesSentences: false,
        includesSelfPairs: false,
        minimumJointCount: 1,
        maximumPairCount: 50
    )
    let windowed = try await session.analyzeWindowCollocations(
        sourceRevisionIDs: Array(ids.prefix(2)),
        options: window
    )
    #expect(windowed.analysisIdentifier == "corpus-window-collocation-v2")
    #expect(windowed.universeSize == 6)
    let alfaBeta = try #require(windowed.pairs.first)
    #expect(alfaBeta.nodeTerm == "alfa")
    #expect(alfaBeta.collocateTerm == "beta")
    #expect(alfaBeta.jointCount == 2)
    #expect(alfaBeta.nodeOnlyCount == 0)
    #expect(alfaBeta.collocateOnlyCount == 1)
    #expect(alfaBeta.neitherCount == 3)
    let reusedWindow = try await session.analyzeWindowCollocations(
        sourceRevisionIDs: Array(ids.prefix(2)),
        options: window
    )
    #expect(reusedWindow.lineage.artifactID == windowed.lineage.artifactID)
    #expect(reusedWindow.lineage.generation == windowed.lineage.generation)
    let windowNetwork = try await session.analyzeWindowNetwork(
        sourceRevisionIDs: Array(ids.prefix(2)),
        window: window
    )
    #expect(windowNetwork.analysisIdentifier == "corpus-window-cooccurrence-network-v1")
    #expect(windowNetwork.summary.nodeCount == 3)
    #expect(windowNetwork.edges.allSatisfy { !$0.occurrences.isEmpty })
    let reusedWindowNetwork = try await session.analyzeWindowNetwork(
        sourceRevisionIDs: Array(ids.prefix(2)),
        window: window
    )
    #expect(reusedWindowNetwork.lineage.artifactID == windowNetwork.lineage.artifactID)

    let request = try GlifiStudioCodingAgreementRequest(
        coderIdentifiers: ["c1", "c2"],
        units: [
            GlifiStudioCodingUnit(unitIdentifier: "u1", labels: ["a", "a"]),
            GlifiStudioCodingUnit(unitIdentifier: "u2", labels: ["a", "b"]),
            GlifiStudioCodingUnit(unitIdentifier: "u3", labels: ["b", "b"]),
            GlifiStudioCodingUnit(unitIdentifier: "u4", labels: ["b", "a"]),
        ]
    )
    let agreement = try await session.assessCodingAgreement(request)
    #expect(agreement.fleissKappa.map { abs($0) < 1e-9 } == true)
    #expect(agreement.level == "nominal")
    #expect(agreement.cohen.map { abs($0.kappa) < 1e-9 } == true)
    #expect(agreement.krippendorff.map { abs($0.alpha - 0.125) < 1e-9 } == true)
    let reusedAgreement = try await session.assessCodingAgreement(request)
    #expect(reusedAgreement.lineage.artifactID == agreement.lineage.artifactID)
    #expect(reusedAgreement.lineage.generation == agreement.lineage.generation)
    // Livello a intervallo sugli stessi dati di R (tre codificatori, dieci unità).
    let values: [[String?]] = [
        ["1", "1", nil], ["2", "2", "3"], ["3", "3", "3"], ["3", "3", "3"], ["2", "2", "2"],
        ["1", "2", "3"], ["4", "4", "4"], ["1", "1", "2"], ["2", "2", "2"], [nil, "5", "5"],
    ]
    let interval = try await session.assessCodingAgreement(
        try GlifiStudioCodingAgreementRequest(
            coderIdentifiers: ["c1", "c2", "c3"],
            units: values.enumerated().map {
                GlifiStudioCodingUnit(unitIdentifier: "u\($0.offset)", labels: $0.element)
            },
            level: "interval"
        )
    )
    #expect(abs(try #require(interval.leveledAlpha) - 0.862104187946885) < 1e-12)
    #expect(interval.cohenUnavailableReason == "agreement.requires-two-coders")
    #expect(interval.fleissUnavailableReason == "agreement.missing-judgments")
    #expect(interval.alphaLower != nil)
    do {
        _ = try GlifiStudioCodingAgreementRequest(
            coderIdentifiers: ["c1", "c2"],
            units: [GlifiStudioCodingUnit(unitIdentifier: "u", labels: ["alto", "basso"])],
            level: "ordinal"
        )
        Issue.record("Etichette non numeriche al livello ordinale")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "agreement.non-numeric-label")
    }

    do {
        _ = try await session.analyzeAssociation(sourceRevisionIDs: ["non-valido", firstThree[0]])
        Issue.record("Era atteso un identificatore non valido")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "derived-analysis.invalid-source-identifier")
        #expect(failure.operation == "analyze")
    }
    do {
        _ = try await session.analyzeAssociation(sourceRevisionIDs: [firstThree[0]])
        Issue.record("Era atteso un gruppo insufficiente")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "association.insufficient-sources")
    }

    let reopened = try await GlifiStudioService().openProject(at: projectURL)
    let afterReopen = try await reopened.analyzeAssociation(sourceRevisionIDs: firstThree)
    #expect(afterReopen.lineage.artifactID == association.lineage.artifactID)
}

@Test("GlifiKit persiste un piano spiegabile da una richiesta JSON minimale")
func servicePlansAnalysisFromStableIntent() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitPlannerTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Piano.glifi", directoryHint: .isDirectory)
    let targetURL = root.appending(path: "target.txt")
    let referenceURL = root.appending(path: "reference.md")
    try Data("casa mare".utf8).write(to: targetURL)
    try Data("# Fonte\ncasa città".utf8).write(to: referenceURL)

    let service = GlifiStudioService()
    let session = try await service.createProject(at: projectURL)
    let first = try await session.importText(at: targetURL, format: .plainText)
    let second = try await session.importText(at: referenceURL, format: .markdown)
    let targetID = try #require(first.project.sources.first?.sourceRevisionID)
    let referenceID = try #require(
        second.project.sources.first(where: { $0.sourceRevisionID != targetID })?
            .sourceRevisionID
    )
    let minimalJSON = Data(
        """
        {"intent":"compare.objects","targetSourceRevisionIDs":["\(targetID)"],"referenceSourceRevisionIDs":["\(referenceID)"]}
        """.utf8
    )
    let request = try JSONDecoder().decode(
        GlifiStudioAnalysisPlanRequest.self,
        from: minimalJSON
    )
    let result = try await session.planAnalysis(request)

    #expect(result.sourceGeneration == 2)
    #expect(result.generation == 3)
    #expect(result.artifactID.hasPrefix("artifact:sha256:"))
    #expect(result.analysisNodeID.hasPrefix("analysis-node:sha256:"))
    #expect(result.plan.intent == "compare.objects")
    #expect(result.plan.status == "readyWithCaveats")
    #expect(result.plan.collectionProfile.configuredLanguageCode == "it")
    // planner-v2: tre passi MVP più similarità e confronto di gruppo (ADR-0025).
    #expect(
        result.plan.steps.map(\.role) == [
            "target", "reference", "comparison", "comparison", "comparison",
        ])
    #expect(result.plan.steps[2].dependencyStepIdentifiers.count == 2)
    #expect(result.plan.decisions.prefix(2).map(\.isIncluded) == [true, true])
    #expect(result.plan.decisions[1].applicability == "conditional")
    #expect(result.plan.decisions.filter(\.isIncluded).count == 4)

    let repeated = try await session.planAnalysis(request)
    #expect(repeated.generation == 3)
    #expect(repeated.artifactID == result.artifactID)
    #expect(try await session.snapshot().artifactCount == 1)
    do {
        _ = try await session.planAnalysis(
            GlifiStudioAnalysisPlanRequest(intent: "intent.non-supportato")
        )
        Issue.record("Era attesa un'intenzione non valida")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "planner.invalid-intent")
        #expect(failure.operation == "plan")
        #expect(failure.retainedState == "lastCommittedGeneration")
    }
    await session.close()

    let reopened = try await service.openProject(at: projectURL)
    let reopenedResult = try await reopened.planAnalysis(request)
    #expect(reopenedResult.artifactID == result.artifactID)
    #expect(reopenedResult.generation == 3)
}

@Test("GlifiKit esegue il piano con uno stream bounded e un solo terminale")
func serviceExecutesAnalysisPlanWithProgress() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitExecutionTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Esecuzione.glifi", directoryHint: .isDirectory)
    let targetURL = root.appending(path: "target.txt")
    let referenceURL = root.appending(path: "reference.txt")
    try Data("casa casa mare".utf8).write(to: targetURL)
    try Data("casa città città".utf8).write(to: referenceURL)

    let session = try await GlifiStudioService().createProject(at: projectURL)
    let first = try await session.importText(at: targetURL, format: .plainText)
    let second = try await session.importText(at: referenceURL, format: .plainText)
    let targetID = try #require(first.project.sources.first?.sourceRevisionID)
    let referenceID = try #require(
        second.project.sources.first(where: { $0.sourceRevisionID != targetID })?
            .sourceRevisionID
    )
    let request = GlifiStudioAnalysisPlanRequest(
        intent: "compare.objects",
        targetSourceRevisionIDs: [targetID],
        referenceSourceRevisionIDs: [referenceID]
    )
    let execution = try await session.executeAnalysisPlan(request)
    do {
        _ = try await session.executeAnalysisPlan(request)
        Issue.record("Era atteso il limite di una esecuzione attiva")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "runtime.operation-limit-exceeded")
        #expect(failure.category == "insufficientResources")
        #expect(failure.operation == "executePlan")
        #expect(failure.arguments["maximumActiveOperationCount"] == "1")
    }
    var progress: [GlifiStudioOperationProgress] = []
    var completions: [GlifiStudioAnalysisExecutionResult] = []
    for try await event in execution.events {
        switch event {
        case let .progress(value):
            progress.append(value)
        case let .completed(value):
            completions.append(value)
        }
    }

    let result = try #require(completions.only)
    #expect(result.operationID == execution.operationID)
    #expect(result.sourceGeneration == 2)
    #expect(result.generation == 9)
    #expect(result.terminalState == "completedWithCaveats")
    #expect(result.operatingProfile == "balanced" || result.operatingProfile == "constrained")
    #expect(result.completedWorkUnits == result.estimatedWorkUnits)
    #expect(
        result.artifacts.map(\.role) == [
            "target", "reference", "comparison", "comparison", "comparison",
        ])
    #expect(result.interpretationArtifactID.hasPrefix("artifact:sha256:"))
    #expect(result.interpretationAnalysisNodeID.hasPrefix("analysis-node:sha256:"))
    #expect(result.interpretation.planArtifactID == result.planArtifactID)
    #expect(result.interpretation.sourceArtifactIDs.count == 5)
    // Similarità con un solo tipo condiviso: finding `caution` (ADR-0026).
    #expect(result.interpretation.findings.count == 1)
    #expect(result.interpretation.insufficientEvidence == nil)
    #expect(progress.map(\.revision) == Array(0...9))
    #expect(progress.allSatisfy { $0.operationID == execution.operationID })
    #expect(progress.last?.phase == "finalizing")
    #expect(progress.last?.completed == 1)
    #expect(progress.last?.total == 1)
    #expect(try await session.snapshot().artifactCount == 7)

    execution.cancel()
    await session.close()
    await #expect(throws: GlifiStudioFailure.self) {
        _ = try await session.executeAnalysisPlan(request)
    }
}

@Test("GlifiKit espone l'interpretazione descrittiva con valori tagged validati")
func servicePresentsGroundedCorpusInterpretation() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitInterpretationTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Interpretazione.glifi", directoryHint: .isDirectory)
    let sourceURL = root.appending(path: "fonte.txt")
    let sourceData = Data("uno due due".utf8)
    try sourceData.write(to: sourceURL)

    let session = try await GlifiStudioService().createProject(at: projectURL)
    _ = try await session.importText(at: sourceURL, format: .plainText)
    let execution = try await session.executeAnalysisPlan(
        GlifiStudioAnalysisPlanRequest(intent: "understand.collection")
    )
    var completed: GlifiStudioAnalysisExecutionResult?
    for try await event in execution.events {
        if case let .completed(result) = event { completed = result }
    }
    let result = try #require(completed)
    let evidence = try #require(result.interpretation.evidence.only)
    let finding = try #require(result.interpretation.findings.only)
    let tokenCount = try #require(
        evidence.measures.first { $0.identifier == "collection.lexical-token-count" }
    )

    #expect(result.interpretation.insufficientEvidence == nil)
    #expect(finding.messageKey == "finding.collection-profile.summary")
    #expect(finding.assessment.supportClass == "descriptive")
    #expect(finding.evidenceReferences.only?.evidenceID == evidence.id)
    #expect(evidence.sourceReferences.only?.ranges.only?.start == 0)
    #expect(evidence.sourceReferences.only?.ranges.only?.end == sourceData.count)
    #expect(tokenCount.value.type == "integer")
    #expect(tokenCount.value.integerValue == 3)
    #expect(tokenCount.value.decimalValue == nil)
    let encoded = try JSONEncoder().encode(result)
    #expect(
        try JSONDecoder().decode(
            GlifiStudioAnalysisExecutionResult.self,
            from: encoded
        ) == result
    )
    #expect(throws: (any Error).self) {
        _ = try JSONDecoder().decode(
            GlifiStudioEvidenceValue.self,
            from: Data(
                """
                {"type":"integer","integerValue":3,"decimalValue":3.0}
                """.utf8
            )
        )
    }
    await session.close()
}

@Test("GlifiKit conserva indagine, selezioni ramificate e storia dopo una nuova importazione")
func servicePersistsInvestigationHistoryAcrossImportAndReopen() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitInvestigationTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let projectURL = root.appending(path: "Indagine.glifi", directoryHint: .isDirectory)
    let firstSourceURL = root.appending(path: "prima.txt")
    let secondSourceURL = root.appending(path: "seconda.txt")
    try Data("uno due due".utf8).write(to: firstSourceURL)
    try Data("tre quattro".utf8).write(to: secondSourceURL)

    let service = GlifiStudioService()
    let session = try await service.createProject(at: projectURL)
    _ = try await session.importText(at: firstSourceURL, format: .plainText)
    let execution = try await session.executeAnalysisPlan(
        GlifiStudioAnalysisPlanRequest(intent: "understand.collection")
    )
    var completed: GlifiStudioAnalysisExecutionResult?
    for try await event in execution.events {
        if case let .completed(result) = event { completed = result }
    }
    let result = try #require(completed)
    let findingID = try #require(result.interpretation.findings.only?.id)
    let created = try await session.createInvestigation(
        GlifiStudioInvestigationCreationRequest(
            question: "Che cosa caratterizza questa raccolta?",
            interpretationArtifactID: result.interpretationArtifactID
        )
    )
    #expect(created.investigation.languageCode == "it")
    #expect(created.investigation.selectedFindingIDs == [findingID])
    #expect(created.investigation.eventIDs.count == 1)

    let firstBranch = try await session.reviseInvestigationSelection(
        GlifiStudioInvestigationSelectionRequest(
            investigationID: created.investigation.id,
            predecessorEventID: created.investigation.headEventID,
            selectedFindingIDs: [],
            reasonIdentifier: "editorial.omit"
        )
    )
    let secondBranch = try await session.reviseInvestigationSelection(
        GlifiStudioInvestigationSelectionRequest(
            investigationID: created.investigation.id,
            predecessorEventID: created.investigation.headEventID,
            selectedFindingIDs: [findingID],
            reasonIdentifier: "editorial.retain"
        )
    )
    #expect(firstBranch.investigation.selectedFindingIDs.isEmpty)
    #expect(secondBranch.investigation.selectedFindingIDs == [findingID])
    #expect(try await session.investigationHeads().count == 2)

    let exportURL = root.appending(
        path: "Relazione.glifiexport",
        directoryHint: .isDirectory
    )
    let exportReceipt = try await session.exportInvestigation(
        GlifiStudioScientificExportRequest(
            investigationHeadEventID: secondBranch.investigation.headEventID
        ),
        to: exportURL
    )
    #expect(exportReceipt.reportRevisionID.hasPrefix("report-revision:sha256:"))
    #expect(exportReceipt.manifestDigest.hasPrefix("sha256:"))
    #expect(exportReceipt.fileCount == 2)
    #expect(
        FileManager.default.fileExists(
            atPath: exportURL.appending(path: "export-manifest.json").path
        )
    )

    let beforeImport = try await session.snapshot()
    let imported = try await session.importText(at: secondSourceURL, format: .plainText)
    // ADR-0028: le analisi dichiarate sulle revisioni immutate sopravvivono all'importazione,
    // mentre piano e interpretazione, che dipendono dall'intera generazione, sono invalidati.
    #expect(imported.project.artifactCount > 0)
    #expect(imported.project.artifactCount < beforeImport.artifactCount)
    #expect(imported.project.investigationEventCount == 3)
    await session.close()

    let reopened = try await service.openProject(at: projectURL)
    let heads = try await reopened.investigationHeads()
    #expect(heads.count == 2)
    #expect(
        Set(heads.map(\.headEventID))
            == Set([
                firstBranch.investigation.headEventID,
                secondBranch.investigation.headEventID,
            ]))
    #expect(try await reopened.snapshot().investigationEventCount == 3)
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}

@Test("Un'analisi dichiarata su fonti immutate è riusata dopo l'importazione di una fonte estranea")
func serviceReusesAnalysesAcrossUnrelatedImports() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitSelectiveReuse-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "Riuso.glifi", directoryHint: .isDirectory))
    var ids: [String] = []
    for (index, text) in ["alfa beta gamma", "alfa beta", "gamma delta"].enumerated() {
        let fileURL = root.appending(path: "fonte-\(index).txt")
        try Data(text.utf8).write(to: fileURL)
        let imported = try await session.importText(at: fileURL, format: .plainText)
        let known = Set(ids)
        ids.append(
            try #require(imported.project.sources.first { !known.contains($0.sourceRevisionID) })
                .sourceRevisionID)
    }
    let group = Array(ids.prefix(2))
    let association = try await session.analyzeAssociation(sourceRevisionIDs: group)
    let weighting = try await session.analyzeTermWeighting(
        sourceRevisionIDs: group,
        scheme: GlifiStudioTermWeightingScheme(
            termFrequency: "TF-sublinear-v1", inverseDocumentFrequency: "IDF-smooth-v1",
            normalization: "RowNorm-L2-v1"))
    let generationBefore = try await session.snapshot().generation
    let artifactsBefore = try await session.snapshot().artifactCount

    // Una fonte estranea al gruppo non tocca le revisioni dichiarate da quelle analisi.
    let extra = root.appending(path: "estranea.txt")
    try Data("epsilon zeta".utf8).write(to: extra)
    let afterImport = try await session.importText(at: extra, format: .plainText)
    #expect(afterImport.project.generation == generationBefore + 1)
    #expect(afterImport.project.artifactCount == artifactsBefore)

    // Ripetere le stesse analisi non ricalcola nulla: stesso Artifact, nessuna generazione nuova.
    let reusedAssociation = try await session.analyzeAssociation(sourceRevisionIDs: group)
    #expect(reusedAssociation.lineage.artifactID == association.lineage.artifactID)
    #expect(reusedAssociation.lineage.analysisNodeID == association.lineage.analysisNodeID)
    let reusedWeighting = try await session.analyzeTermWeighting(
        sourceRevisionIDs: group,
        scheme: GlifiStudioTermWeightingScheme(
            termFrequency: "TF-sublinear-v1", inverseDocumentFrequency: "IDF-smooth-v1",
            normalization: "RowNorm-L2-v1"))
    #expect(reusedWeighting.lineage.artifactID == weighting.lineage.artifactID)
    #expect(try await session.snapshot().generation == afterImport.project.generation)

    // Un'analisi che include la fonte nuova è invece un nodo diverso, calcolato ora.
    let widened = try await session.analyzeAssociation(sourceRevisionIDs: group + [ids[2]])
    #expect(widened.lineage.artifactID != association.lineage.artifactID)
    await session.close()
}
