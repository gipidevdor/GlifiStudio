// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Foundation
import SQLite3
import Testing

@testable import GlifiCore

@Test(
    "Le letture del package rifiutano directory simboliche a ogni livello",
    arguments: ["source", "artifact", "descriptor", "investigation"], [0, 1, 2, 3]
)
func projectPackageRejectsLinkedObjectDirectories(kind: String, depth: Int) async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Synthetic source".utf8), format: .plainText)
        let corpus = try await project.importText(imported)
        let artifacts = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "synthetic"),
            descriptor: projectDescriptor(named: "paths", corpusDigest: corpus.sourceRootDigest))
        let artifact = try #require(artifacts.artifacts.first)
        let event = try GlifiInvestigationEvent(
            investigationID: InvestigationID(), predecessorEventID: nil,
            recordedAtUnixMilliseconds: 1, actor: .localPerson,
            payload: .created(
                question: "Synthetic question", languageCode: "it", intent: .understandCollection,
                planArtifactID: artifact.artifactID, interpretationArtifactID: artifact.artifactID,
                availableFindingIDs: [], selectedFindingIDs: []))
        let snapshot = try await project.appendInvestigationEvent(event)
        let paths = [
            "source": try #require(snapshot.sources.first).objectPath,
            "artifact": artifact.objectPath,
            "descriptor": artifact.descriptorObjectPath,
            "investigation": try #require(snapshot.investigationEvents.first).objectPath,
        ]
        let path = try #require(paths[kind])
        let components = path.split(separator: "/")
        let directoryURL = packageURL.appending(
            path: components.prefix(depth + 1).joined(separator: "/"))
        let externalURL = packageURL.deletingLastPathComponent().appending(path: "external")
        let original = try Data(contentsOf: packageURL.appending(path: path))
        let manifest = try Data(contentsOf: packageURL.appending(path: "manifest.json"))
        try FileManager.default.moveItem(at: directoryURL, to: externalURL)
        try FileManager.default.createSymbolicLink(
            at: directoryURL, withDestinationURL: externalURL)

        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Expected rejection of a linked object directory")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.retryDisposition == .never)
        }
        switch kind {
        case "source":
            await #expect(throws: GlifiFailure.self) {
                _ = try await project.sourceData(for: imported.sourceRevisionID)
            }
        case "artifact":
            await #expect(throws: GlifiFailure.self) {
                _ = try await project.artifactData(for: artifact.artifactID)
            }
        case "investigation":
            await #expect(throws: GlifiFailure.self) {
                _ = try await project.investigationEvent(for: event.eventID())
            }
        case "descriptor":
            break
        default:
            Issue.record("Unknown test case")
        }
        #expect(await project.snapshot() == snapshot)
        #expect(try Data(contentsOf: packageURL.appending(path: "manifest.json")) == manifest)
        let externalObject = externalURL.appending(
            path: components.dropFirst(depth + 1).joined(separator: "/"))
        #expect(try Data(contentsOf: externalObject) == original)

        try FileManager.default.removeItem(at: directoryURL)
        try FileManager.default.moveItem(at: externalURL, to: directoryURL)
        #expect(try await GlifiProjectPackage.open(at: packageURL).snapshot() == snapshot)
        #expect(try await project.sourceData(for: imported.sourceRevisionID) == imported.bytes)
    }
}

@Test("Il manifest non accetta hard link anche se i byte sono validi")
func projectPackageRejectsHardLinkedManifest() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let snapshot = await project.snapshot()
        let manifestURL = packageURL.appending(path: "manifest.json")
        let original = try Data(contentsOf: manifestURL)
        let externalURL = packageURL.deletingLastPathComponent().appending(
            path: "manifest-copy.json")
        try FileManager.default.linkItem(at: manifestURL, to: externalURL)
        #expect(throws: GlifiFailure.self) { _ = try GlifiProjectPackage.open(at: packageURL) }
        #expect(throws: GlifiFailure.self) {
            _ = try GlifiProjectPackage.openReadOnlyRecovery(at: packageURL)
        }
        #expect(try Data(contentsOf: externalURL) == original)
        try FileManager.default.removeItem(at: externalURL)
        #expect(try await GlifiProjectPackage.open(at: packageURL).snapshot() == snapshot)
    }
}

@Test(
    "Il writer rifiuta lock non regolari senza modificare la generazione",
    arguments: ["symbolicLink", "danglingLink", "hardLink", "fifo", "directory"]
)
func projectWriterRejectsUnsafeLockFiles(kind: String) async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let snapshot = await project.snapshot()
        let lockURL = packageURL.appending(path: "transactions/.writer.lock")
        let externalURL = packageURL.deletingLastPathComponent().appending(path: "external-lock")
        let original = Data("synthetic lock target".utf8)
        if kind != "danglingLink" {
            try original.write(to: externalURL)
        }
        switch kind {
        case "symbolicLink", "danglingLink":
            try FileManager.default.createSymbolicLink(at: lockURL, withDestinationURL: externalURL)
        case "hardLink":
            try FileManager.default.linkItem(at: externalURL, to: lockURL)
        case "fifo":
            try #require(mkfifo(lockURL.path, 0o600) == 0)
        case "directory":
            try FileManager.default.createDirectory(at: lockURL, withIntermediateDirectories: false)
        default:
            Issue.record("Caso di test sconosciuto")
        }
        let imported = try GlifiTextImporter().importText(
            from: Data("Una fonte sintetica.".utf8), format: .plainText)
        do {
            _ = try await project.importText(imported)
            Issue.record("Era atteso il rifiuto del lock non sicuro")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.code == "project.invalid-writer-lock")
        }
        #expect(await project.snapshot() == snapshot)
        #expect(try await GlifiProjectPackage.open(at: packageURL).snapshot() == snapshot)
        if kind == "danglingLink" {
            #expect(!FileManager.default.fileExists(atPath: externalURL.path))
        } else {
            #expect(try Data(contentsOf: externalURL) == original)
        }
        try FileManager.default.removeItem(at: lockURL)
        let committed = try await project.importText(imported)
        #expect(committed.generation == snapshot.generation + 1)
    }
}

@Test("Nuovi package e file autorevoli hanno permessi privati")
func projectPackageCreatesPrivateFiles() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Contenuto sintetico privato.".utf8), format: .plainText)
        let snapshot = try await project.importText(imported)
        let source = try #require(snapshot.sources.first)
        for (url, expected) in [
            (packageURL, 0o700),
            (packageURL.appending(path: "manifest.json"), 0o600),
            (packageURL.appending(path: source.objectPath), 0o600),
            (packageURL.appending(path: "transactions/.writer.lock"), 0o600),
        ] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
            #expect(permissions.intValue & 0o777 == expected)
        }
        #expect(try await GlifiProjectPackage.open(at: packageURL).snapshot() == snapshot)
    }
}

@Test("Il writer non segue link nella directory delle transazioni")
func projectWriterRejectsLinkedTransactionDirectory() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let snapshot = await project.snapshot()
        let transactionsURL = packageURL.appending(path: "transactions")
        let externalURL = packageURL.deletingLastPathComponent().appending(path: "external")
        try FileManager.default.moveItem(at: transactionsURL, to: externalURL)
        try FileManager.default.createSymbolicLink(
            at: transactionsURL, withDestinationURL: externalURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Fonte sintetica.".utf8), format: .plainText)
        await #expect(throws: GlifiFailure.self) { _ = try await project.importText(imported) }
        #expect(await project.snapshot() == snapshot)
        #expect(try FileManager.default.contentsOfDirectory(atPath: externalURL.path).isEmpty)
        try FileManager.default.removeItem(at: transactionsURL)
        try FileManager.default.moveItem(at: externalURL, to: transactionsURL)
        #expect(try await project.importText(imported).generation == snapshot.generation + 1)
    }
}

@Test("Il package .glifi conserva una fonte e riapre la stessa generazione")
func projectPackageRoundTrip() async throws {
    try await withTemporaryProject { packageURL in
        let projectID = ProjectID(
            uuid: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000001"))
        )
        let sourceID = SourceID(
            uuid: try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000002"))
        )
        let revisionID = SourceRevisionID(
            uuid: try #require(UUID(uuidString: "30000000-0000-0000-0000-000000000003"))
        )
        let imported = try GlifiTextImporter().importText(
            from: Data("Una città affidabile.".utf8),
            format: .plainText,
            sourceRevisionID: revisionID
        )
        let project = try GlifiProjectPackage.create(at: packageURL, projectID: projectID)

        let committed = try await project.importText(imported, sourceID: sourceID)
        #expect(committed.generation == 1)
        #expect(committed.sources.count == 1)
        #expect(committed.sources[0].sourceID == sourceID)

        let reopened = try GlifiProjectPackage.open(at: packageURL)
        #expect(await reopened.snapshot() == committed)
        #expect(try await reopened.sourceData(for: revisionID) == imported.bytes)
    }
}

@Test("Un package schema 2 migra in modo additivo prima di accettare la cronologia")
func projectPackageMigratesSchemaTwoForInvestigationHistory() async throws {
    try await withTemporaryProject { packageURL in
        let projectID = ProjectID(
            uuid: try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000099"))
        )
        try createLegacySchemaTwoProject(at: packageURL, projectID: projectID)

        let project = try GlifiProjectPackage.open(at: packageURL)
        #expect(await project.snapshot().investigationEvents.isEmpty)
        let event = try GlifiInvestigationEvent(
            investigationID: InvestigationID(
                uuid: try #require(UUID(uuidString: "80000000-0000-0000-0000-000000000099"))
            ),
            predecessorEventID: nil,
            recordedAtUnixMilliseconds: 1,
            actor: .localPerson,
            payload: .created(
                question: "Domanda migrata",
                languageCode: "it",
                intent: .understandCollection,
                planArtifactID: try ArtifactID(
                    digest: "sha256:" + String(repeating: "1", count: 64)
                ),
                interpretationArtifactID: try ArtifactID(
                    digest: "sha256:" + String(repeating: "2", count: 64)
                ),
                availableFindingIDs: [],
                selectedFindingIDs: []
            )
        )
        let committed = try await project.appendInvestigationEvent(event)
        #expect(committed.investigationEvents.count == 1)

        let manifestData = try Data(contentsOf: packageURL.appending(path: "manifest.json"))
        let manifest = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        #expect(manifest["schemaVersion"] as? Int == 3)
        #expect(manifest["investigationEventCount"] as? Int == 1)
        #expect(try await GlifiProjectPackage.open(at: packageURL).snapshot() == committed)
    }
}

@Test("Il manifest schema 3 non accetta una radice Investigation mancante")
func projectPackageSchemaThreeRequiresInvestigationRoot() async throws {
    try await withTemporaryProject { packageURL in
        _ = try GlifiProjectPackage.create(at: packageURL)
        let manifestURL = packageURL.appending(path: "manifest.json")
        let data = try Data(contentsOf: manifestURL)
        var manifest = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        manifest.removeValue(forKey: "investigationRootDigest")
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]).write(
            to: manifestURL
        )

        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Era atteso il rifiuto del manifest incompleto")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.code == "project.manifest-invalid")
        }
    }
}

@Test(
    "Prima del commit point resta autorevole la generazione precedente",
    arguments: [
        GlifiProjectCommitInterruption.staged,
        .objectPromoted,
        .databasePrepared,
        .manifestPrepared,
    ]
)
func interruptionBeforeManifestPreservesPreviousGeneration(
    interruption: GlifiProjectCommitInterruption
) async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Prima del commit.".utf8),
            format: .plainText
        )

        await #expect(throws: GlifiFailure.self) {
            try await project.importText(
                imported,
                sourceID: SourceID(),
                interruption: interruption
            )
        }
        let reopened = try GlifiProjectPackage.open(at: packageURL)
        #expect(await reopened.snapshot().generation == 0)
        #expect(await reopened.snapshot().sources.isEmpty)

        let retrySnapshot = try await reopened.importText(imported)
        #expect(retrySnapshot.generation == 1)
        #expect(retrySnapshot.sources.count == 1)
    }
}

@Test(
    "Dopo il commit point la nuova generazione resta autorevole",
    arguments: [
        GlifiProjectCommitInterruption.manifestReplaced,
        .databaseCommitted,
    ]
)
func interruptionAfterManifestPreservesNewGeneration(
    interruption: GlifiProjectCommitInterruption
) async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Dopo il commit.".utf8),
            format: .plainText
        )

        await #expect(throws: GlifiFailure.self) {
            try await project.importText(
                imported,
                sourceID: SourceID(),
                interruption: interruption
            )
        }
        let reopened = try GlifiProjectPackage.open(at: packageURL)
        #expect(await reopened.snapshot().generation == 1)
        #expect(await reopened.snapshot().sources.count == 1)
    }
}

@Test("Un oggetto alterato rende il package corrotto senza modificarlo")
func projectPackageRejectsCorruptedObject() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Integrità".utf8),
            format: .plainText
        )
        let snapshot = try await project.importText(imported)
        let objectURL = packageURL.appending(path: try #require(snapshot.sources.first).objectPath)
        try Data("Alterato".utf8).write(to: objectURL)

        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Il package corrotto non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.retainedState == .readOnlyRecovery)
        }
    }
}

@Test(
    "Il recovery read-only riapre l'ultima generazione precedente interamente verificabile"
)
func projectPackageReadOnlyRecoveryOpensLastVerifiableGeneration() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let firstRevisionID = SourceRevisionID(
            uuid: try #require(UUID(uuidString: "40000000-0000-0000-0000-000000000001"))
        )
        let firstImported = try GlifiTextImporter().importText(
            from: Data("Prima generazione integra.".utf8),
            format: .plainText,
            sourceRevisionID: firstRevisionID
        )
        let afterFirstImport = try await project.importText(firstImported)
        #expect(afterFirstImport.generation == 1)

        let secondImported = try GlifiTextImporter().importText(
            from: Data("Seconda generazione da corrompere.".utf8),
            format: .plainText
        )
        let afterSecondImport = try await project.importText(secondImported)
        #expect(afterSecondImport.generation == 2)

        let corruptedSource = try #require(
            afterSecondImport.sources.first { $0.sourceRevisionID != firstRevisionID }
        )
        let corruptedObjectURL = packageURL.appending(path: corruptedSource.objectPath)
        try Data("Alterato".utf8).write(to: corruptedObjectURL)

        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Il package con l'ultima generazione corrotta non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
        }

        let recovery = try GlifiProjectPackage.openReadOnlyRecovery(at: packageURL)
        #expect(recovery.snapshot.generation == 1)
        #expect(recovery.snapshot.sources.map(\.sourceRevisionID) == [firstRevisionID])
        #expect(try recovery.sourceData(for: firstRevisionID) == firstImported.bytes)

        do {
            _ = try recovery.sourceData(for: corruptedSource.sourceRevisionID)
            Issue.record("Una fonte estranea alla generazione recuperata non è stata rifiutata")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.source-not-found")
        }

        // La generazione corrotta resta intatta: il recovery non riscrive nulla.
        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Il recovery read-only ha alterato il package originale")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
        }
    }
}

@Test(
    "Il recovery read-only fallisce quando il manifest è illeggibile"
)
func projectPackageReadOnlyRecoveryRejectsUnreadableManifest() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        _ = try await project.importText(
            try GlifiTextImporter().importText(
                from: Data("Manifest da corrompere.".utf8),
                format: .plainText
            )
        )
        try Data("non è JSON".utf8).write(to: packageURL.appending(path: "manifest.json"))

        do {
            _ = try GlifiProjectPackage.openReadOnlyRecovery(at: packageURL)
            Issue.record("Il manifest illeggibile non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
        }
    }
}

@Test("Artifact e descriptor persistono con DAG e lettura verificati")
func projectPackagePersistsVerifiedAnalysisArtifact() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let initial = await project.snapshot()
        let descriptor = try projectDescriptor(
            named: "profile",
            corpusDigest: initial.sourceRootDigest
        )
        let payload = ProjectTestArtifactPayload(value: "tre token")

        do {
            _ = try await project.storeArtifact(
                ProjectWrongArtifactPayload(value: "schema errato"),
                descriptor: descriptor
            )
            Issue.record("Il payload con schema diverso dal descriptor non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.artifact-schema-mismatch")
            #expect(failure.category == .invalidInput)
        }
        #expect(await project.snapshot() == initial)

        let staleDescriptor = try projectDescriptor(
            named: "stale",
            corpusDigest: "sha256:" + String(repeating: "0", count: 64)
        )
        do {
            _ = try await project.storeArtifact(payload, descriptor: staleDescriptor)
            Issue.record("Il descriptor legato a un altro corpus non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.artifact-corpus-mismatch")
            #expect(failure.category == .staleArtifact)
        }
        #expect(await project.snapshot() == initial)

        let committed = try await project.storeArtifact(payload, descriptor: descriptor)
        #expect(committed.generation == 1)
        #expect(committed.artifacts.count == 1)
        let artifact = try #require(committed.artifacts.first)
        let expectedNodeID = try descriptor.nodeID()
        #expect(artifact.node.id == expectedNodeID)
        #expect(artifact.artifactID.digest == artifact.contentDigest)

        let idempotent = try await project.storeArtifact(payload, descriptor: descriptor)
        #expect(idempotent == committed)

        let reopened = try GlifiProjectPackage.open(at: packageURL)
        #expect(await reopened.snapshot() == committed)
        let persistedData = try await reopened.artifactData(for: artifact.artifactID)
        #expect(
            try JSONDecoder().decode(ProjectTestArtifactPayload.self, from: persistedData)
                == payload
        )
        let graph = try await reopened.analysisGraph()
        #expect(graph.nodes.map(\.id) == [artifact.node.id])
    }
}

@Test("La sostituzione invalida i soli discendenti e un nuovo corpus tutti gli Artifact")
func projectPackageInvalidatesPersistedArtifacts() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let corpusDigest = await project.snapshot().sourceRootDigest
        let rootDescriptor = try projectDescriptor(named: "root", corpusDigest: corpusDigest)
        let firstRoot = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "prima"),
            descriptor: rootDescriptor
        )
        let root = try #require(firstRoot.artifacts.first)
        let childDescriptor = try projectDescriptor(
            named: "child",
            corpusDigest: corpusDigest,
            dependencies: [
                try GlifiAnalysisDependency(
                    nodeID: root.node.id,
                    artifactDigest: root.contentDigest,
                    outputSchemaIdentifier: root.node.descriptor.outputSchemaIdentifier
                )
            ]
        )
        let withChild = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "figlio"),
            descriptor: childDescriptor
        )
        #expect(withChild.artifacts.count == 2)

        let replaced = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "seconda"),
            descriptor: rootDescriptor
        )
        #expect(replaced.artifacts.count == 1)
        #expect(replaced.artifacts.first?.node.id == root.node.id)
        #expect(replaced.artifacts.first?.contentDigest != root.contentDigest)

        let imported = try GlifiTextImporter().importText(
            from: Data("Nuovo corpus".utf8),
            format: .plainText
        )
        let afterImport = try await project.importText(imported)
        #expect(afterImport.artifacts.isEmpty)
        #expect(try await project.analysisGraph().nodes.isEmpty)
    }
}

@Test("Un Artifact alterato rende il package corrotto")
func projectPackageRejectsCorruptedArtifact() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let descriptor = try projectDescriptor(
            named: "corrupt",
            corpusDigest: await project.snapshot().sourceRootDigest
        )
        let snapshot = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "integro"),
            descriptor: descriptor
        )
        let artifact = try #require(snapshot.artifacts.first)
        try Data("alterato".utf8).write(
            to: packageURL.appending(path: artifact.objectPath)
        )

        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Il package con Artifact corrotto non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(failure.category == .corruption)
            #expect(failure.retainedState == .readOnlyRecovery)
        }
    }
}

@Test(
    "Il commit Artifact mantiene l'autorità prima e dopo il commit point",
    arguments: GlifiProjectCommitInterruption.allCases
)
func artifactCommitInterruptionMaintainsAuthority(
    interruption: GlifiProjectCommitInterruption
) async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let descriptor = try projectDescriptor(
            named: "interrupted",
            corpusDigest: await project.snapshot().sourceRootDigest
        )
        await #expect(throws: GlifiFailure.self) {
            try await project.storeArtifact(
                ProjectTestArtifactPayload(value: "risultato"),
                descriptor: descriptor,
                interruption: interruption
            )
        }

        let reopened = try GlifiProjectPackage.open(at: packageURL)
        let snapshot = await reopened.snapshot()
        let isAfterCommitPoint =
            interruption == .manifestReplaced || interruption == .databaseCommitted
        #expect(snapshot.generation == (isAfterCommitPoint ? 1 : 0))
        #expect(snapshot.artifacts.count == (isAfterCommitPoint ? 1 : 0))
        if !isAfterCommitPoint {
            #expect(
                try await reopened.storeArtifact(
                    ProjectTestArtifactPayload(value: "risultato"),
                    descriptor: descriptor
                ).generation == 1
            )
        }
    }
}

@Test("Il motore persiste analisi e keyness sulla generazione verificata")
func enginePersistsVerifiedProjectAnalysis() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let first = try GlifiTextImporter().importText(
            from: Data("casa casa mare".utf8),
            format: .plainText,
            sourceRevisionID: SourceRevisionID(
                uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
            )
        )
        let second = try GlifiTextImporter().importText(
            from: Data("casa città".utf8),
            format: .plainText,
            sourceRevisionID: SourceRevisionID(
                uuid: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
            )
        )
        _ = try await project.importText(first)
        let committed = try await project.importText(second)

        let tokenizer = CountingProjectTokenizer()
        let engine = GlifiEngine(tokenizer: tokenizer)
        let analysisOptions = try GlifiCorpusAnalysisOptions(
            diversityWindowSize: 2,
            ngramSizes: [2],
            maximumDocumentCount: 2,
            maximumSourceByteCount: 1_024,
            maximumVocabularySize: 10,
            maximumDistinctNGramCount: 10,
            maximumNonZeroCellCount: 10
        )
        let result = try await engine.analyzeCorpus(
            in: project,
            options: analysisOptions
        )

        #expect(result.projectID == committed.projectID)
        #expect(result.sourceGeneration == 2)
        #expect(result.generation == 3)
        #expect(result.analysisNodeID.canonicalValue.hasPrefix("analysis-node:sha256:"))
        #expect(result.artifactID.canonicalValue.hasPrefix("artifact:sha256:"))
        #expect(result.analysis.documentCount == 2)
        #expect(result.analysis.lexicalTokenCount == 5)
        #expect(tokenizer.invocationCount == 2)
        let profileData = try await project.artifactData(for: result.artifactID)
        #expect(
            try JSONDecoder().decode(
                GlifiCorpusAnalysisArtifactPayload.self,
                from: profileData
            ).analysis == result.analysis
        )
        var futurePayload = try #require(
            JSONSerialization.jsonObject(with: profileData) as? [String: Any]
        )
        futurePayload["schemaIdentifier"] = "studio.glifi.artifact.corpus-profile.v2"
        let futureData = try JSONSerialization.data(withJSONObject: futurePayload)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                GlifiCorpusAnalysisArtifactPayload.self,
                from: futureData
            )
        }
        let reusedProfile = try await engine.analyzeCorpus(
            in: project,
            options: analysisOptions
        )
        #expect(reusedProfile.sourceGeneration == 3)
        #expect(reusedProfile.generation == 3)
        #expect(reusedProfile.artifactID == result.artifactID)
        #expect(tokenizer.invocationCount == 2)

        let comparison = try await engine.compareKeyness(
            in: project,
            targetSourceRevisionIDs: [first.sourceRevisionID],
            referenceSourceRevisionIDs: [second.sourceRevisionID]
        )
        #expect(comparison.projectID == committed.projectID)
        #expect(comparison.sourceGeneration == 3)
        #expect(comparison.generation == 6)
        #expect(comparison.comparison.targetTokenCount == 3)
        #expect(comparison.comparison.referenceTokenCount == 2)
        #expect(comparison.comparison.terms.count == 3)
        let keynessData = try await project.artifactData(for: comparison.artifactID)
        #expect(
            try JSONDecoder().decode(GlifiKeynessArtifactPayload.self, from: keynessData)
                .comparison == comparison.comparison
        )
        let finalSnapshot = await project.snapshot()
        #expect(finalSnapshot.generation == 6)
        #expect(finalSnapshot.sources == committed.sources)
        #expect(finalSnapshot.artifacts.count == 4)
        #expect(try await project.analysisGraph().nodes.count == 4)
        #expect(tokenizer.invocationCount == 4)

        let reusedComparison = try await engine.compareKeyness(
            in: project,
            targetSourceRevisionIDs: [first.sourceRevisionID],
            referenceSourceRevisionIDs: [second.sourceRevisionID]
        )
        #expect(reusedComparison.sourceGeneration == 6)
        #expect(reusedComparison.generation == 6)
        #expect(reusedComparison.artifactID == comparison.artifactID)
        #expect(await project.snapshot().artifacts.count == 4)
        #expect(tokenizer.invocationCount == 4)

        let reopened = try GlifiProjectPackage.open(at: packageURL)
        let reopenedTokenizer = CountingProjectTokenizer()
        let reopenedEngine = GlifiEngine(tokenizer: reopenedTokenizer)
        let reopenedProfile = try await reopenedEngine.analyzeCorpus(
            in: reopened,
            options: analysisOptions
        )
        let reopenedComparison = try await reopenedEngine.compareKeyness(
            in: reopened,
            targetSourceRevisionIDs: [first.sourceRevisionID],
            referenceSourceRevisionIDs: [second.sourceRevisionID]
        )
        #expect(reopenedProfile.artifactID == result.artifactID)
        #expect(reopenedComparison.artifactID == comparison.artifactID)
        #expect(reopenedTokenizer.invocationCount == 0)
        #expect(await reopened.snapshot().generation == 6)

        let incompatibleOptions = try GlifiCorpusAnalysisOptions(
            diversityWindowSize: 3,
            ngramSizes: [2],
            maximumDocumentCount: 2,
            maximumSourceByteCount: 1_024,
            maximumVocabularySize: 10,
            maximumDistinctNGramCount: 10,
            maximumNonZeroCellCount: 10
        )
        let reopenedSnapshot = await reopened.snapshot()
        let incompatibleDescriptor = try GlifiAnalysisArtifactDescriptorFactory.corpusProfile(
            snapshot: reopenedSnapshot,
            sourceRevisionIDs: reopenedSnapshot.sources.map(\.sourceRevisionID),
            tokenizationContractIdentifier: reopenedTokenizer.tokenizationContractIdentifier,
            options: incompatibleOptions
        )
        _ = try await reopened.storeArtifact(
            GlifiCorpusAnalysisArtifactPayload(
                analysisNodeID: result.analysisNodeID,
                analysis: result.analysis
            ),
            descriptor: incompatibleDescriptor
        )
        do {
            _ = try await reopenedEngine.analyzeCorpus(
                in: reopened,
                options: incompatibleOptions
            )
            Issue.record("Era atteso un payload legato a un altro nodo")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "analysis.payload-node-mismatch")
            #expect(failure.category == .invariantViolation)
        }
    }
}

@Test("La rimozione del manifest dopo un commit lascia il package non riapribile")
func projectPackageRejectsMissingManifestAfterCommit() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let imported = try GlifiTextImporter().importText(
            from: Data("Testo italiano di recovery.".utf8),
            format: .plainText
        )
        _ = try await project.importText(imported)
        #expect(await project.snapshot().generation == 1)

        try FileManager.default.removeItem(at: packageURL.appending(path: "manifest.json"))

        do {
            _ = try GlifiProjectPackage.open(at: packageURL)
            Issue.record("Il package senza manifest non è stato rifiutato")
        } catch let failure as GlifiFailure {
            #expect(
                failure.category == .corruption
                    || failure.category == .transientIO
                    || failure.category == .invalidInput
            )
        }
    }
}

private func withTemporaryProject(
    _ body: (URL) async throws -> Void
) async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiProjectPackageTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    try await body(root.appending(path: "Test.glifi", directoryHint: .isDirectory))
}

private func createLegacySchemaTwoProject(at packageURL: URL, projectID: ProjectID) throws {
    for path in [
        "store", "sources/objects/sha256", "representations/objects/sha256",
        "artifacts/objects/sha256", "artifacts/descriptors/sha256", "history",
        "transactions",
    ] {
        try FileManager.default.createDirectory(
            at: packageURL.appending(path: path, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }
    let emptyRoot = "sha256:4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"
    let recordDigest = "sha256:" + String(repeating: "9", count: 64)
    let manifest = """
        {"artifactCount":0,"artifactRootDigest":"\(emptyRoot)","formatVersion":1,"generation":0,"generationRecordDigest":"\(recordDigest)","minimumReaderVersion":1,"projectID":"\(projectID.canonicalValue)","schema":"studio.glifi.project-manifest","schemaVersion":2,"sourceCount":0,"sourceRootDigest":"\(emptyRoot)"}
        """
    try Data(manifest.utf8).write(to: packageURL.appending(path: "manifest.json"))

    var database: OpaquePointer?
    let databaseURL = packageURL.appending(path: "store/project.sqlite")
    guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
        throw CocoaError(.fileWriteUnknown)
    }
    defer { sqlite3_close(database) }
    let sql = """
        PRAGMA foreign_keys = ON;
        CREATE TABLE project_metadata (
            singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
            project_id TEXT NOT NULL,
            schema_version INTEGER NOT NULL CHECK (schema_version = 2)
        ) STRICT;
        CREATE TABLE generations (
            generation INTEGER PRIMARY KEY CHECK (generation >= 0),
            base_generation INTEGER,
            state TEXT NOT NULL CHECK (state IN ('prepared', 'committed')),
            record_digest TEXT NOT NULL,
            source_root_digest TEXT NOT NULL,
            source_count INTEGER NOT NULL CHECK (source_count >= 0),
            artifact_root_digest TEXT NOT NULL,
            artifact_count INTEGER NOT NULL CHECK (artifact_count >= 0)
        ) STRICT;
        CREATE TABLE source_entries (
            generation INTEGER NOT NULL, source_id TEXT NOT NULL,
            source_revision_id TEXT NOT NULL, format TEXT NOT NULL,
            content_digest TEXT NOT NULL, byte_count INTEGER NOT NULL,
            object_path TEXT NOT NULL, PRIMARY KEY (generation, source_revision_id),
            FOREIGN KEY (generation) REFERENCES generations(generation) ON DELETE CASCADE
        ) STRICT;
        CREATE TABLE artifact_entries (
            generation INTEGER NOT NULL, node_id TEXT NOT NULL, artifact_id TEXT NOT NULL,
            descriptor_digest TEXT NOT NULL, descriptor_byte_count INTEGER NOT NULL,
            descriptor_object_path TEXT NOT NULL, content_digest TEXT NOT NULL,
            byte_count INTEGER NOT NULL, object_path TEXT NOT NULL,
            output_schema_identifier TEXT NOT NULL, PRIMARY KEY (generation, node_id),
            FOREIGN KEY (generation) REFERENCES generations(generation) ON DELETE CASCADE
        ) STRICT;
        INSERT INTO project_metadata VALUES(1, '\(projectID.canonicalValue)', 2);
        INSERT INTO generations VALUES(0, NULL, 'committed', '\(recordDigest)', '\(emptyRoot)', 0, '\(emptyRoot)', 0);
        """
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
        throw CocoaError(.fileWriteUnknown)
    }
}

private func projectDescriptor(
    named name: String,
    corpusDigest: String,
    dependencies: [GlifiAnalysisDependency] = [],
    sourceRevisionIDs: [SourceRevisionID]? = nil
) throws -> GlifiAnalysisDescriptor {
    try GlifiAnalysisDescriptor(
        artifactTypeIdentifier: "artifact.\(name)",
        algorithmIdentifier: "algorithm.\(name)",
        algorithmVersion: "1",
        corpusIdentifier: "project-source-root-v1",
        corpusVersionDigest: corpusDigest,
        selectionIdentifier: "selection.all.v1",
        analyticalUnitIdentifier: "source-revision.v1",
        preprocessingIdentifiers: ["extract-v1", "it-token-v1"],
        linguisticProfileIdentifiers: ["it-token-v1"],
        representationIdentifier: "representation.test.v1",
        resolvedParameters: ["resolved": .boolean(true)],
        seedPolicyIdentifier: "none-v1",
        backendIdentifier: "swift-reference-v1",
        numericPolicyIdentifier: "IEEE-754-binary64-ordered-reduction-v1",
        determinismClass: .d1,
        outputSchemaIdentifier: ProjectTestArtifactPayload.outputSchemaIdentifier,
        softwareIdentifier: "GlifiCore-0.1",
        dependencies: dependencies,
        sourceRevisionIDs: sourceRevisionIDs
    )
}

private struct ProjectTestArtifactPayload: GlifiAnalysisArtifactPayload, Equatable {
    static let outputSchemaIdentifier = "studio.glifi.test-artifact.v1"

    let value: String
}

private struct ProjectWrongArtifactPayload: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.wrong-artifact.v1"

    let value: String
}

private final class CountingProjectTokenizer: GlifiTokenizing, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var tokenizationContractIdentifier: String { GlifiItalianTokenizer.contractIdentifier }

    var invocationCount: Int {
        lock.withLock { count }
    }

    func tokenize(_ text: String) throws -> GlifiTokenization {
        lock.withLock { count += 1 }
        return try GlifiItalianTokenizer().tokenize(text)
    }
}

@Test("Il digest di corpus delle revisioni dichiarate è la radice ristretta a quelle revisioni")
func selectiveCorpusVersionDigestRestrictsTheSourceRoot() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let importer = GlifiTextImporter()
        var snapshot = try await project.importText(
            try importer.importText(from: Data("Uno due due.".utf8), format: .plainText))
        let first = try #require(snapshot.sources.first?.sourceRevisionID)
        snapshot = try await project.importText(
            try importer.importText(from: Data("Tre quattro.".utf8), format: .plainText))
        let second = try #require(
            snapshot.sources.map(\.sourceRevisionID).first { $0 != first })

        // Dichiarare tutte le revisioni della generazione restituisce la radice invariata: è la
        // proprietà su cui si appoggia il nuovo invariante del package (ADR-0028).
        #expect(
            try snapshot.corpusVersionDigest(for: [first, second]) == snapshot.sourceRootDigest)
        #expect(
            try snapshot.corpusVersionDigest(for: [second, first]) == snapshot.sourceRootDigest)

        // Un sottoinsieme ha un digest proprio, stabile e diverso da quello della raccolta intera.
        let onlyFirst = try snapshot.corpusVersionDigest(for: [first])
        #expect(onlyFirst != snapshot.sourceRootDigest)
        #expect(onlyFirst != (try snapshot.corpusVersionDigest(for: [second])))
        #expect(onlyFirst.hasPrefix("sha256:"))

        // Il digest di un sottoinsieme non cambia quando si importa una fonte estranea: è ciò che
        // rende riusabili gli Artifact che dipendono soltanto da quelle revisioni.
        let afterImport = try await project.importText(
            try importer.importText(from: Data("Cinque sei.".utf8), format: .plainText))
        #expect(try afterImport.corpusVersionDigest(for: [first]) == onlyFirst)
        #expect(afterImport.sourceRootDigest != snapshot.sourceRootDigest)

        // Dichiarare nessuna revisione è legittimo: l'analisi non legge alcuna fonte.
        #expect(try afterImport.corpusVersionDigest(for: []).hasPrefix("sha256:"))

        // Una revisione estranea alla generazione è rifiutata.
        let unknown = SourceRevisionID(
            uuid: UUID(uuid: (9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9)))
        do {
            _ = try afterImport.corpusVersionDigest(for: [first, unknown])
            Issue.record("revisione estranea accettata")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.source-revision-not-found")
            #expect(failure.retainedState == .lastCommittedGeneration)
        }
    }
}

@Test("L'invariante del package accetta un Artifact legato alle sole revisioni dichiarate")
func projectPackageAcceptsArtifactsBoundToDeclaredRevisions() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let importer = GlifiTextImporter()
        _ = try await project.importText(
            try importer.importText(from: Data("Uno due due.".utf8), format: .plainText))
        let snapshot = try await project.importText(
            try importer.importText(from: Data("Tre quattro.".utf8), format: .plainText))
        let revisions = snapshot.sources.map(\.sourceRevisionID)
        let chosen = try #require(revisions.first)

        // Un Artifact che dichiara un sottoinsieme, con il digest di quel sottoinsieme, è valido
        // anche se il digest radice della raccolta è un altro (ADR-0028).
        let selective = try projectDescriptor(
            named: "selettivo",
            corpusDigest: try snapshot.corpusVersionDigest(for: [chosen]),
            sourceRevisionIDs: [chosen]
        )
        #expect(selective.corpusVersionDigest != snapshot.sourceRootDigest)
        let stored = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "selettivo"), descriptor: selective)
        #expect(stored.artifacts.count == 1)

        // Un Artifact che non dichiara nulla resta legato all'intera generazione.
        let whole = try projectDescriptor(
            named: "intero", corpusDigest: snapshot.sourceRootDigest)
        #expect(
            try await project.storeArtifact(
                ProjectTestArtifactPayload(value: "intero"), descriptor: whole
            ).artifacts.count == 2)

        // Il digest deve essere quello delle revisioni dichiarate, non la radice della raccolta.
        let mismatched = try projectDescriptor(
            named: "incoerente",
            corpusDigest: snapshot.sourceRootDigest,
            sourceRevisionIDs: [chosen]
        )
        do {
            _ = try await project.storeArtifact(
                ProjectTestArtifactPayload(value: "incoerente"), descriptor: mismatched)
            Issue.record("Il digest della raccolta intera è stato accettato per un sottoinsieme")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.artifact-corpus-mismatch")
            #expect(failure.category == .staleArtifact)
        }

        // Una revisione estranea alla generazione non è dichiarabile.
        let unknown = SourceRevisionID(
            uuid: UUID(uuid: (7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7)))
        let foreign = try projectDescriptor(
            named: "estraneo",
            corpusDigest: try snapshot.corpusVersionDigest(for: [chosen]),
            sourceRevisionIDs: [unknown]
        )
        do {
            _ = try await project.storeArtifact(
                ProjectTestArtifactPayload(value: "estraneo"), descriptor: foreign)
            Issue.record("Una revisione estranea alla generazione è stata accettata")
        } catch let failure as GlifiFailure {
            #expect(failure.code == "project.artifact-corpus-mismatch")
        }

        // La riapertura rivalida entrambe le forme con lo stesso invariante.
        let reopened = try await GlifiProjectPackage.open(at: packageURL).snapshot()
        #expect(reopened.artifacts.count == 2)
    }
}

@Test("Un'importazione conserva gli Artifact legati a revisioni immutate e la loro catena")
func projectPackageRetainsArtifactsUnaffectedByAnImport() async throws {
    try await withTemporaryProject { packageURL in
        let project = try GlifiProjectPackage.create(at: packageURL)
        let importer = GlifiTextImporter()
        let firstSnapshot = try await project.importText(
            try importer.importText(from: Data("Uno due due.".utf8), format: .plainText))
        let kept = try #require(firstSnapshot.sources.first?.sourceRevisionID)

        // Un Artifact dichiarato sulla prima revisione, con un figlio che ne dipende.
        let parentDescriptor = try projectDescriptor(
            named: "padre",
            corpusDigest: try firstSnapshot.corpusVersionDigest(for: [kept]),
            sourceRevisionIDs: [kept]
        )
        let withParent = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "padre"), descriptor: parentDescriptor)
        let parent = try #require(withParent.artifacts.first)
        let childDescriptor = try projectDescriptor(
            named: "figlio",
            corpusDigest: try withParent.corpusVersionDigest(for: [kept]),
            dependencies: [
                try GlifiAnalysisDependency(
                    nodeID: parent.node.id,
                    artifactDigest: parent.contentDigest,
                    outputSchemaIdentifier: parent.node.descriptor.outputSchemaIdentifier
                )
            ],
            sourceRevisionIDs: [kept]
        )
        _ = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "figlio"), descriptor: childDescriptor)
        // Un Artifact che non dichiara revisioni dipende dall'intera generazione.
        let wholeSnapshot = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "intero"),
            descriptor: try projectDescriptor(
                named: "intero",
                corpusDigest: (await project.snapshot()).sourceRootDigest))
        #expect(wholeSnapshot.artifacts.count == 3)

        // L'importazione di una fonte estranea conserva padre e figlio, invalida l'Artifact
        // legato all'intera generazione.
        let afterImport = try await project.importText(
            try importer.importText(from: Data("Tre quattro.".utf8), format: .plainText))
        let survivors = Set(afterImport.artifacts.map(\.node.descriptor.artifactTypeIdentifier))
        #expect(survivors == ["artifact.padre", "artifact.figlio"])
        #expect(afterImport.artifacts.count == 2)
        #expect(try await project.analysisGraph().nodes.count == 2)

        // Lo stato sopravvive alla riapertura: il trasporto è persistito, non ricostruito.
        let reopened = try await GlifiProjectPackage.open(at: packageURL).snapshot()
        #expect(reopened.artifacts.map(\.node.id) == afterImport.artifacts.map(\.node.id))

        // Un figlio resta invalidato quando il padre non sopravvive.
        let orphanParent = try projectDescriptor(
            named: "padre-intero", corpusDigest: reopened.sourceRootDigest)
        let withOrphanParent = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "padre-intero"), descriptor: orphanParent)
        let orphan = try #require(
            withOrphanParent.artifacts.first {
                $0.node.descriptor.artifactTypeIdentifier == "artifact.padre-intero"
            })
        let orphanChild = try projectDescriptor(
            named: "figlio-orfano",
            corpusDigest: try withOrphanParent.corpusVersionDigest(for: [kept]),
            dependencies: [
                try GlifiAnalysisDependency(
                    nodeID: orphan.node.id,
                    artifactDigest: orphan.contentDigest,
                    outputSchemaIdentifier: orphan.node.descriptor.outputSchemaIdentifier
                )
            ],
            sourceRevisionIDs: [kept]
        )
        _ = try await project.storeArtifact(
            ProjectTestArtifactPayload(value: "figlio-orfano"), descriptor: orphanChild)
        let afterSecondImport = try await project.importText(
            try importer.importText(from: Data("Cinque sei.".utf8), format: .plainText))
        let remaining = Set(
            afterSecondImport.artifacts.map(\.node.descriptor.artifactTypeIdentifier))
        #expect(remaining == ["artifact.padre", "artifact.figlio"])
    }
}
