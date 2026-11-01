// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioDocumentLifecycleTests {
    @Test func initializesAnEmptyDocumentPlaceholder() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "New.glifi")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let model = StudioHomeModel()

        await model.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.generation == 0)
        #expect(model.projectURL == destination)
        #expect(
            FileManager.default.fileExists(
                atPath: destination.appending(path: "manifest.json").path))
    }

    @Test func repeatedAttachmentPreservesCommittedSourcesAndQuery() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Repeated.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let projectID = try #require(model.snapshot?.projectID)
        let generation = model.snapshot?.generation
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        let queryDigest = model.queryResult?.queryDigest
        let manifestURL = destination.appending(path: "manifest.json")
        let manifestBefore = try Data(contentsOf: manifestURL)

        await model.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.projectID == projectID)
        #expect(model.snapshot?.generation == generation)
        #expect(model.snapshot?.sourceCount == 1)
        #expect(model.queryResult?.queryDigest == queryDigest)
        #expect(try Data(contentsOf: manifestURL) == manifestBefore)
    }

    @Test func staleInitializationFlagOpensAnExistingProject() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Existing.glifi")
        let original = StudioHomeModel()
        await original.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: original, in: root)
        let projectID = try #require(original.snapshot?.projectID)
        let reopened = StudioHomeModel()

        await reopened.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(reopened.lastFailure == nil)
        #expect(reopened.snapshot?.projectID == projectID)
        #expect(reopened.snapshot?.sourceCount == 1)
        reopened.queryDraft = "normalized:fonte"
        await reopened.runQuery()
        #expect(reopened.queryResult?.matches.count == 1)
    }

    @Test func refusesAnIncompleteNonemptyPackageWithoutRemovingItsContents() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Incomplete.glifi")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let sentinelURL = destination.appending(path: "source.txt")
        let sentinel = Data("A committed source must survive.".utf8)
        try sentinel.write(to: sentinelURL)
        let model = StudioHomeModel()

        await model.attachDocument(at: destination, needsPackageInitialization: true)

        #expect(model.lastFailure?.code == "project.invalid-destination")
        #expect(model.snapshot == nil)
        #expect(try Data(contentsOf: sentinelURL) == sentinel)
        #expect(
            !FileManager.default.fileExists(
                atPath: destination.appending(path: "manifest.json").path))
    }

    @Test func refusesARegularFileAndASymbolicLink() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "File.glifi")
        let data = Data("Keep this file.".utf8)
        try data.write(to: file)
        let model = StudioHomeModel()
        await model.attachDocument(at: file, needsPackageInitialization: true)
        #expect(model.lastFailure != nil)
        #expect(try Data(contentsOf: file) == data)

        let target = root.appending(path: "Target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let link = root.appending(path: "Link.glifi")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        await model.attachDocument(at: link, needsPackageInitialization: true)
        #expect(model.lastFailure != nil)
        #expect(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
    }

    @Test func failedOpenPreservesTheUsablePreviousSession() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Valid.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let projectID = try #require(model.snapshot?.projectID)
        let bookmark = model.lastProjectBookmark

        await model.openProject(at: root.appending(path: "Missing.glifi"))

        #expect(model.lastFailure != nil)
        #expect(model.projectURL == destination)
        #expect(model.snapshot?.projectID == projectID)
        #expect(model.lastProjectBookmark == bookmark)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func failedInitializationPreservesTheUsablePreviousSession() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "Valid.glifi")
        let model = StudioHomeModel()
        await model.attachDocument(at: destination, needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        let occupied = root.appending(path: "Occupied.glifi")
        try Data("Keep this file.".utf8).write(to: occupied)

        await model.attachDocument(at: occupied, needsPackageInitialization: true)

        #expect(model.lastFailure != nil)
        #expect(model.projectURL == destination)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.lastFailure == nil)
        #expect(model.queryResult?.matches.count == 1)
    }

    @Test func successfulSwitchClearsThePreviousAnalysis() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = StudioHomeModel()
        await model.attachDocument(
            at: root.appending(path: "First.glifi"), needsPackageInitialization: true)
        try await importSource(into: model, in: root)
        model.queryDraft = "normalized:fonte"
        await model.runQuery()
        #expect(model.queryResult?.matches.count == 1)
        let firstID = model.snapshot?.projectID
        let sourceRevisionID = try #require(model.snapshot?.sources.first?.sourceRevisionID)
        await model.loadCodingSource(sourceRevisionID)
        #expect(model.codingSourceRevisionID == sourceRevisionID)
        #expect(!model.codingSegments.isEmpty)

        await model.attachDocument(
            at: root.appending(path: "Second.glifi"), needsPackageInitialization: true)

        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.projectID != firstID)
        #expect(model.snapshot?.sourceCount == 0)
        #expect(model.queryResult == nil)
        #expect(model.lastProfile == nil)
        #expect(model.qualitativeState == nil)
        #expect(model.codingSourceRevisionID == nil)
        #expect(model.codingSegments.isEmpty)
        #expect(model.codingSourceCharacterCount == 0)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudioMacTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func importSource(into model: StudioHomeModel, in root: URL) async throws {
        let source = root.appending(path: "source.txt")
        try Data("Una fonte italiana affidabile.".utf8).write(to: source)
        await model.importSource(at: source)
        #expect(model.lastFailure == nil)
        #expect(model.snapshot?.sourceCount == 1)
    }
}
