// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import Testing

@MainActor
struct StudioSelectionConsistencyTests {
    @Test func aRejectedQuerySelectionPreservesItsSourceAndAllowsRetry() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = fixture.model
        let previousID = model.selectedQueryMatchID
        let previousSource = model.sourceText
        let previousQuery = model.queryResult
        let previousSnapshot = model.snapshot
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }

        await model.selectQueryMatch(fixture.otherMatch)

        #expect(model.isBusy)
        #expect(model.lastFailure == nil)
        #expect(model.selectedQueryMatchID == previousID)
        #expect(model.sourceText == previousSource)
        #expect(model.selectedQueryMatch?.sourceRevisionID == model.sourceText?.sourceRevisionID)
        #expect(model.queryResult == previousQuery)
        #expect(model.snapshot == previousSnapshot)
        gate.release()
        await opening.value

        await model.selectQueryMatch(fixture.otherMatch)

        #expect(!model.isBusy)
        #expect(model.lastFailure == nil)
        #expect(model.selectedQueryMatchID == fixture.otherMatch.id)
        #expect(model.sourceText == fixture.otherSource)
        #expect(model.selectedQueryMatch?.sourceRevisionID == model.sourceText?.sourceRevisionID)
        #expect(model.queryResult == previousQuery)
        #expect(model.snapshot == previousSnapshot)
    }

    @Test func aFailedQuerySelectionPreservesItsSourceAndAllowsRetry() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = fixture.model
        let previousID = model.selectedQueryMatchID
        let previousSource = model.sourceText
        let previousQuery = model.queryResult
        let previousSnapshot = model.snapshot
        let originalBytes = Data(fixture.otherSource.text.utf8)
        let sourceObject = try sourceObjectURL(
            containing: originalBytes, in: fixture.projectURL)
        defer { try? originalBytes.write(to: sourceObject, options: .atomic) }
        var corruptedBytes = originalBytes
        try #require(!corruptedBytes.isEmpty)
        corruptedBytes[corruptedBytes.startIndex] ^= 1
        try corruptedBytes.write(to: sourceObject, options: .atomic)

        await model.selectQueryMatch(fixture.otherMatch)

        #expect(model.lastFailure?.code == "project.object-digest-mismatch")
        #expect(model.lastFailure?.category == "corruption")
        #expect(model.lastFailure?.retainedState == "readOnlyRecovery")
        #expect(!model.isBusy)
        #expect(model.selectedQueryMatchID == previousID)
        #expect(model.sourceText == previousSource)
        #expect(model.selectedQueryMatch?.sourceRevisionID == model.sourceText?.sourceRevisionID)
        #expect(model.queryResult == previousQuery)
        #expect(model.snapshot == previousSnapshot)
        try originalBytes.write(to: sourceObject, options: .atomic)

        await model.selectQueryMatch(fixture.otherMatch)

        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
        #expect(model.selectedQueryMatchID == fixture.otherMatch.id)
        #expect(model.sourceText == fixture.otherSource)
        #expect(model.selectedQueryMatch?.sourceRevisionID == model.sourceText?.sourceRevisionID)
        #expect(model.queryResult == previousQuery)
        #expect(model.snapshot == previousSnapshot)
    }

    @Test func rejectedVisualSelectionsPreserveTheirSourceAndAllowRetry() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = fixture.model
        let selection = try await prepareVisualSelection(in: fixture)
        let ungrounded = try makeMark(id: "mark:ungrounded", sourceRevisionIDs: [])
        let previousSource = model.evidenceSourceText
        let previousRanges = model.evidenceSourceRanges
        let previousFocus = model.focusedEvidenceID
        let previousSnapshot = model.snapshot
        let (gate, opening) = try await beginSuspendedReopening(model)
        defer {
            gate.release()
            opening.cancel()
        }

        await model.selectVisualMark(selection.otherMark)

        #expect(model.isBusy)
        #expect(model.lastFailure == nil)
        #expect(model.selectedVisualMarkID == selection.currentMark.id)
        #expect(model.evidenceSourceText == previousSource)
        #expect(model.evidenceSourceRanges == previousRanges)
        #expect(model.focusedEvidenceID == previousFocus)

        await model.selectVisualMark(ungrounded)

        #expect(model.isBusy)
        #expect(model.lastFailure == nil)
        #expect(model.selectedVisualMarkID == selection.currentMark.id)
        #expect(model.evidenceSourceText == previousSource)
        #expect(model.evidenceSourceRanges == previousRanges)
        #expect(model.focusedEvidenceID == previousFocus)
        #expect(model.snapshot == previousSnapshot)
        gate.release()
        await opening.value

        await model.selectVisualMark(selection.otherMark)

        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
        #expect(model.selectedVisualMarkID == selection.otherMark.id)
        #expect(model.evidenceSourceText == selection.otherSource)
        #expect(model.evidenceSourceRanges.isEmpty)
        #expect(model.focusedEvidenceID == nil)
        #expect(model.snapshot == previousSnapshot)
    }

    @Test func aFailedVisualSelectionPreservesItsSourceAndAllowsRetry() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = fixture.model
        let selection = try await prepareVisualSelection(in: fixture)
        let previousSource = model.evidenceSourceText
        let previousRanges = model.evidenceSourceRanges
        let previousFocus = model.focusedEvidenceID
        let previousSnapshot = model.snapshot
        let originalBytes = Data(selection.otherSource.text.utf8)
        let sourceObject = try sourceObjectURL(
            containing: originalBytes, in: fixture.projectURL)
        defer { try? originalBytes.write(to: sourceObject, options: .atomic) }
        var corruptedBytes = originalBytes
        try #require(!corruptedBytes.isEmpty)
        corruptedBytes[corruptedBytes.startIndex] ^= 1
        try corruptedBytes.write(to: sourceObject, options: .atomic)

        await model.selectVisualMark(selection.otherMark)

        #expect(model.lastFailure?.code == "project.object-digest-mismatch")
        #expect(model.lastFailure?.category == "corruption")
        #expect(model.lastFailure?.retainedState == "readOnlyRecovery")
        #expect(!model.isBusy)
        #expect(model.selectedVisualMarkID == selection.currentMark.id)
        #expect(model.evidenceSourceText == previousSource)
        #expect(model.evidenceSourceRanges == previousRanges)
        #expect(model.focusedEvidenceID == previousFocus)
        #expect(model.snapshot == previousSnapshot)
        try originalBytes.write(to: sourceObject, options: .atomic)

        await model.selectVisualMark(selection.otherMark)

        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
        #expect(model.selectedVisualMarkID == selection.otherMark.id)
        #expect(model.evidenceSourceText == selection.otherSource)
        #expect(model.evidenceSourceRanges.isEmpty)
        #expect(model.focusedEvidenceID == nil)
        #expect(model.snapshot == previousSnapshot)
    }

    @Test func anAdmittedMarkWithoutSourcesClearsThePreviousEvidenceContext() async throws {
        let fixture = try await makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let model = fixture.model
        _ = try await prepareVisualSelection(in: fixture)
        let previousSnapshot = model.snapshot
        let ungrounded = try makeMark(id: "mark:ungrounded", sourceRevisionIDs: [])

        await model.selectVisualMark(ungrounded)

        #expect(model.lastFailure == nil)
        #expect(!model.isBusy)
        #expect(model.selectedVisualMarkID == ungrounded.id)
        #expect(model.evidenceSourceText == nil)
        #expect(model.evidenceSourceRanges.isEmpty)
        #expect(model.focusedEvidenceID == nil)
        #expect(model.snapshot == previousSnapshot)
    }

    private func makeFixture() async throws -> SelectionConsistencyFixture {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "GlifiStudioSelectionTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        do {
            let projectURL = root.appending(path: "Selection.glifi")
            let model = StudioHomeModel()
            await model.attachDocument(at: projectURL, needsPackageInitialization: true)
            try #require(model.lastFailure == nil)
            let texts = ["Fonte breve.", "Un contesto più lungo precede la fonte conclusiva."]
            let urls = try texts.enumerated().map { index, text in
                let url = root.appending(path: "source-\(index).txt")
                try Data(text.utf8).write(to: url)
                return url
            }
            await model.importSources(at: urls)
            try #require(model.lastFailure == nil)
            model.queryDraft = "normalized:fonte"
            await model.runQuery()
            try #require(model.lastFailure == nil)
            let matches = try #require(model.queryResult?.matches)
            try #require(matches.count == 2)
            let current = try #require(model.selectedQueryMatch)
            let other = try #require(
                matches.first { $0.sourceRevisionID != current.sourceRevisionID })
            try #require(current.sourceRanges != other.sourceRanges)
            let source = try #require(model.sourceText)
            try #require(source.sourceRevisionID == current.sourceRevisionID)
            let session = try await GlifiStudioService().openProject(at: projectURL)
            let otherSource = try await session.sourceText(sourceRevisionID: other.sourceRevisionID)
            await session.close()
            return SelectionConsistencyFixture(
                root: root, projectURL: projectURL, model: model,
                otherMatch: other, otherSource: otherSource)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    private func beginSuspendedReopening(_ model: StudioHomeModel) async throws -> (
        SelectionConsistencyGate, Task<Void, Never>
    ) {
        _ = try #require(model.lastProjectBookmark)
        let gate = SelectionConsistencyGate()
        let entered = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let opening = Task { @MainActor in
            await model.reopenLastProject(using: { _ in
                await gate.hold(entered: entered.continuation)
            })
            entered.continuation.finish()
        }
        var events = entered.stream.makeAsyncIterator()
        do {
            try #require(await events.next() == true)
        } catch {
            gate.release()
            opening.cancel()
            throw error
        }
        return (gate, opening)
    }

    private func prepareVisualSelection(in fixture: SelectionConsistencyFixture) async throws -> (
        currentMark: GlifiStudioVisualMark,
        otherMark: GlifiStudioVisualMark,
        otherSource: GlifiStudioSourceText
    ) {
        let model = fixture.model
        await model.executePlan()
        try #require(model.lastFailure == nil)
        let evidence = try #require(
            model.executionResult?.interpretation.evidence.first {
                $0.sourceReferences.first?.ranges.isEmpty == false
            })
        let reference = try #require(evidence.sourceReferences.first)
        let currentMark = try makeMark(
            id: "mark:current", sourceRevisionIDs: [reference.sourceRevisionID])
        let sources = [try #require(model.sourceText), fixture.otherSource]
        let otherSource = try #require(
            sources.first { $0.sourceRevisionID != reference.sourceRevisionID })
        let otherMark = try makeMark(
            id: "mark:other", sourceRevisionIDs: [otherSource.sourceRevisionID])
        await model.selectVisualMark(currentMark)
        try #require(model.lastFailure == nil)
        await model.openEvidenceSource(evidence)
        try #require(model.lastFailure == nil)
        try #require(model.selectedVisualMarkID == currentMark.id)
        try #require(model.evidenceSourceText?.sourceRevisionID == reference.sourceRevisionID)
        try #require(!model.evidenceSourceRanges.isEmpty)
        try #require(model.focusedEvidenceID == evidence.id)
        return (currentMark, otherMark, otherSource)
    }

    private func makeMark(id: String, sourceRevisionIDs: [String]) throws -> GlifiStudioVisualMark {
        let object: [String: Any] = [
            "id": id, "kind": "point", "series": "selection-fixture", "label": id,
            "x": 0, "y": 0, "isEmphasized": false, "lineageClass": "contributive",
            "sourceRevisionIDs": sourceRevisionIDs,
        ]
        return try JSONDecoder().decode(
            GlifiStudioVisualMark.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }

    private func sourceObjectURL(containing expected: Data, in projectURL: URL) throws -> URL {
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: projectURL.appending(path: "sources"),
                includingPropertiesForKeys: [.isRegularFileKey]))
        var candidates: [URL] = []
        for case let url as URL in enumerator {
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
                try Data(contentsOf: url) == expected
            {
                candidates.append(url)
            }
        }
        try #require(candidates.count == 1)
        return try #require(candidates.first)
    }
}

@MainActor
private struct SelectionConsistencyFixture {
    let root: URL
    let projectURL: URL
    let model: StudioHomeModel
    let otherMatch: GlifiStudioQueryMatch
    let otherSource: GlifiStudioSourceText
}

@MainActor
private final class SelectionConsistencyGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func hold(entered: AsyncStream<Bool>.Continuation) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            entered.yield(true)
        }
    }

    func release() {
        let waiting = continuation
        continuation = nil
        waiting?.resume()
    }
}
