// SPDX-License-Identifier: BSD-3-Clause

import AppKit
import Darwin
import Foundation
import GlifiKit
import Observation
import PDFKit

nonisolated enum StudioStudyReaderSlot: String, CaseIterable, Identifiable, Sendable {
    case first, second
    var id: Self { self }
}

@MainActor struct StudioStudyReading {
    let sourceRevisionID: String
    let source: GlifiStudioSourceText
    let text: String
    let segments: [GlifiStudioTextSegment]
    let characterCount: Int
    let title: String
    let pdf: PDFDocument?
    let pageNumber: Int?
    let highlight: NSRange?
    let navigationID: UUID
}

/// Owns only presentation and editable drafts; the project session verifies every stored anchor.
@MainActor @Observable final class StudioStudyModel {
    var state = GlifiStudioStudyState(projectID: "")
    var hasLoaded = false
    var showsNotebook = false
    var showsComparison = false
    var firstReading: StudioStudyReading?
    var secondReading: StudioStudyReading?
    var selectedExcerptID: String?
    var pendingPassage: GlifiStudioTextSegment?
    var pendingSourceID: String?
    var pendingTitle = ""
    var pendingGroupID = ""
    private(set) var recoveryDraft: GlifiStudioStudyState?
    private(set) var sourceTitles: [String: String] = [:]
    var proposedRestore: GlifiStudioStudyState?
    private(set) var canUndo = false
    private(set) var canRedo = false
    private var committed = GlifiStudioStudyState(projectID: "")
    private var previous: [GlifiStudioStudyState] = []
    private var following: [GlifiStudioStudyState] = []
    private var nativeSelections: [StudioStudyReaderSlot: NSRange] = [:]
    private var readingExcerptIDs: [StudioStudyReaderSlot: String] = [:]
    private var readingRequests: [StudioStudyReaderSlot: UUID] = [:]
    private var lifecycle = UUID()

    var hasChanges: Bool { state != committed }
    var ownershipID: UUID { lifecycle }
    var orderedExcerpts: [GlifiStudioStudyExcerpt] {
        state.order.compactMap { id in state.excerpts.first { $0.id == id } }
    }
    var orderedNotes: [GlifiStudioStudyNote] {
        state.order.compactMap { id in state.notes.first { $0.id == id } }
    }

    func reset() {
        lifecycle = UUID()
        readingRequests = [:]
        nativeSelections = [:]
        readingExcerptIDs = [:]
        state = GlifiStudioStudyState(projectID: "")
        committed = state
        hasLoaded = false
        showsNotebook = false
        showsComparison = false
        firstReading = nil
        secondReading = nil
        selectedExcerptID = nil
        recoveryDraft = nil
        proposedRestore = nil
        sourceTitles = [:]
        clearPendingPassage()
        previous = []
        following = []
        updateHistory()
    }

    func load(session: GlifiStudioProjectSession) async throws {
        let owner = lifecycle
        let next = try await session.studyState()
        try checkCurrent(owner)
        state = next
        committed = next
        hasLoaded = true
        previous = []
        following = []
        updateHistory()
    }

    func save(session: GlifiStudioProjectSession) async throws {
        guard hasLoaded, hasChanges else { return }
        let owner = lifecycle
        let revealsConclusions = state.notes != committed.notes
        let next = try await session.saveStudyState(state, expectedRevision: committed.revision)
        try checkCurrent(owner)
        state = next
        committed = next
        if revealsConclusions, !next.notes.isEmpty { showsNotebook = true }
    }

    func reloadPreservingDraft(session: GlifiStudioProjectSession) async throws {
        let owner = lifecycle
        let next = try await session.studyState()
        try adoptReloadedState(next, expectedOwnership: owner)
    }

    func adoptReloadedState(_ next: GlifiStudioStudyState, expectedOwnership: UUID) throws {
        try checkCurrent(expectedOwnership)
        guard !hasLoaded || next.projectID == state.projectID else { throw Self.failure() }
        if hasChanges { recoveryDraft = state }
        state = next
        committed = next
        hasLoaded = true
        previous = []
        following = []
        updateHistory()
    }

    func restoreRecoveryDraft() {
        guard var draft = recoveryDraft, draft.projectID == state.projectID else { return }
        draft.revision = committed.revision
        change { $0 = draft }
        recoveryDraft = nil
    }

    func prepareRestore(at url: URL) async throws {
        let owner = lifecycle
        let next = try await Self.readExport(at: url)
        try checkCurrent(owner)
        guard next.projectID == state.projectID else {
            throw GlifiStudioFailure(
                code: "study.project-mismatch", category: "invalidInput", operation: "investigate",
                retryDisposition: "afterCorrection", retainedState: "unchanged",
                messageKey: "failure.study.project-mismatch")
        }
        proposedRestore = next
    }

    func restoreProposedNotebook(session: GlifiStudioProjectSession) async throws {
        guard var next = proposedRestore, next.projectID == state.projectID else {
            throw Self.failure()
        }
        if hasChanges { recoveryDraft = state }
        next.revision = committed.revision
        change { $0 = next }
        try await save(session: session)
        proposedRestore = nil
    }

    func undo() {
        guard var restored = previous.popLast() else { return }
        following.append(state)
        restored.revision = committed.revision
        state = restored
        updateHistory()
    }

    func redo() {
        guard var restored = following.popLast() else { return }
        previous.append(state)
        restored.revision = committed.revision
        state = restored
        updateHistory()
    }

    func discardDraft() {
        guard hasChanges else { return }
        let old = state
        state = committed
        previous.append(old)
        following = []
        updateHistory()
    }

    func addGroup(title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        change { $0.groups.append(.init(id: UUID().uuidString.lowercased(), title: title)) }
    }

    func renameGroup(id: String, title: String) {
        change { next in
            guard let index = next.groups.firstIndex(where: { $0.id == id }) else { return }
            next.groups[index].title = title
        }
    }

    func removeGroup(id: String) {
        change { next in
            next.groups.removeAll { $0.id == id }
            for index in next.excerpts.indices where next.excerpts[index].groupID == id {
                next.excerpts[index].groupID = nil
            }
            for index in next.notes.indices where next.notes[index].groupID == id {
                next.notes[index].groupID = nil
            }
        }
    }

    func updateExcerpt(id: String, title: String, groupID: String?) {
        change { next in
            guard let index = next.excerpts.firstIndex(where: { $0.id == id }) else { return }
            next.excerpts[index].title = title
            next.excerpts[index].groupID = groupID
        }
    }

    func saveNote(
        id: String?, title: String, text: String, groupID: String?, excerptIDs: [String]
    ) {
        change { next in
            let note = GlifiStudioStudyNote(
                id: id ?? UUID().uuidString.lowercased(), title: title, text: text,
                groupID: groupID, excerptIDs: excerptIDs)
            if let index = next.notes.firstIndex(where: { $0.id == note.id }) {
                next.notes[index] = note
            } else {
                next.notes.append(note)
                next.order.append(note.id)
            }
        }
    }

    func removeObject(id: String) {
        change { next in
            next.excerpts.removeAll { $0.id == id }
            next.notes.removeAll { $0.id == id }
            next.order.removeAll { $0 == id }
            next.comparisonExcerptIDs.removeAll { $0 == id }
            for index in next.notes.indices { next.notes[index].excerptIDs.removeAll { $0 == id } }
        }
        if selectedExcerptID == id { selectedExcerptID = nil }
    }

    func moveObject(id: String, by offset: Int) {
        change { next in
            guard let index = next.order.firstIndex(of: id),
                next.order.indices.contains(index + offset)
            else { return }
            next.order.swapAt(index, index + offset)
        }
    }

    func canMoveObject(id: String, by offset: Int) -> Bool {
        guard let index = state.order.firstIndex(of: id) else { return false }
        return state.order.indices.contains(index + offset)
    }

    func setInvestigation(_ id: String?) { change { $0.investigationID = id } }

    func setComparison(_ ids: [String]) {
        change { $0.comparisonExcerptIDs = Array(ids.prefix(2)) }
    }

    func reading(_ slot: StudioStudyReaderSlot) -> StudioStudyReading? {
        switch slot {
        case .first: firstReading
        case .second: secondReading
        }
    }

    func excerptID(in slot: StudioStudyReaderSlot) -> String? { readingExcerptIDs[slot] }

    func setNativeSelection(_ range: NSRange, sourceID: String, slot: StudioStudyReaderSlot) {
        guard reading(slot)?.sourceRevisionID == sourceID else { return }
        nativeSelections[slot] = range
    }

    func hasNativeSelection(_ slot: StudioStudyReaderSlot) -> Bool {
        guard let range = nativeSelections[slot] else { return false }
        return range.location != NSNotFound && range.length > 0
    }

    func readSource(
        session: GlifiStudioProjectSession, sourceID: String, slot: StudioStudyReaderSlot
    ) async throws {
        let owner = lifecycle
        let request = UUID()
        readingRequests[slot] = request
        let snapshot = try await Self.readSnapshot(session: session, sourceID: sourceID)
        let pdf: PDFDocument?
        if let data = snapshot.pdfData { pdf = try await Self.makePDF(data) } else { pdf = nil }
        try checkReading(owner, request: request, slot: slot)
        apply(snapshot, pdf: pdf, slot: slot, page: nil, highlight: nil)
        readingExcerptIDs[slot] = nil
        if slot == .first { selectedExcerptID = nil }
    }

    func openExcerpt(
        session: GlifiStudioProjectSession, excerptID: String, slot: StudioStudyReaderSlot
    ) async throws {
        let owner = lifecycle
        let request = UUID()
        readingRequests[slot] = request
        let resolved = try await session.resolveStudyExcerpt(excerptID: excerptID)
        let anchor = resolved.excerpt.anchor
        let snapshot = try await Self.readSnapshot(
            session: session, sourceID: anchor.sourceRevisionID)
        let highlight = try await Self.nativeRange(
            text: snapshot.text, startUTF8: anchor.startUTF8, endUTF8: anchor.endUTF8)
        let page = resolved.document?.locations.first {
            $0.start < anchor.endUTF8 && $0.end > anchor.startUTF8
        }?.pageNumber
        let pdf: PDFDocument?
        if let data = snapshot.pdfData { pdf = try await Self.makePDF(data) } else { pdf = nil }
        try checkReading(owner, request: request, slot: slot)
        apply(snapshot, pdf: pdf, slot: slot, page: page, highlight: highlight)
        readingExcerptIDs[slot] = excerptID
        selectedExcerptID = excerptID
        if slot == .second { showsComparison = true }
    }

    func previewNativeSelection(
        session: GlifiStudioProjectSession, slot: StudioStudyReaderSlot
    ) async throws {
        guard let reading = reading(slot), let range = nativeSelections[slot] else {
            throw Self.failure()
        }
        let owner = lifecycle
        let selection = try await Self.characterSelection(text: reading.text, range: range)
        try checkCurrent(owner)
        try await previewPassage(session: session, slot: slot, selection: selection)
    }

    func previewPassage(
        session: GlifiStudioProjectSession, slot: StudioStudyReaderSlot,
        selection: GlifiStudioPassageSelection
    ) async throws {
        guard let reading = reading(slot) else { throw Self.failure() }
        let owner = lifecycle
        let next = try await session.passage(
            sourceRevisionID: reading.sourceRevisionID, selection: selection)
        try checkCurrent(owner)
        guard self.reading(slot)?.navigationID == reading.navigationID else {
            throw CancellationError()
        }
        pendingPassage = next
        pendingSourceID = reading.sourceRevisionID
        pendingTitle = String(next.text.prefix(80))
        pendingGroupID = ""
    }

    func collect(session: GlifiStudioProjectSession) async throws {
        guard let passage = pendingPassage, let sourceID = pendingSourceID else {
            throw Self.failure()
        }
        let owner = lifecycle
        try await save(session: session)
        try checkCurrent(owner)
        let before = state
        let next = try await session.collectStudyExcerpt(
            sourceRevisionID: sourceID,
            selection: .bytes(start: passage.startUTF8, end: passage.endUTF8),
            title: pendingTitle, groupID: pendingGroupID.isEmpty ? nil : pendingGroupID,
            expectedRevision: committed.revision)
        try checkCurrent(owner)
        previous.append(before)
        following = []
        state = next
        committed = next
        selectedExcerptID =
            next.excerpts.first {
                $0.anchor.sourceRevisionID == sourceID && $0.anchor.startUTF8 == passage.startUTF8
                    && $0.anchor.endUTF8 == passage.endUTF8
            }?.id
        showsNotebook = true
        clearPendingPassage()
        updateHistory()
    }

    func clearPendingPassage() {
        pendingPassage = nil
        pendingSourceID = nil
        pendingTitle = ""
        pendingGroupID = ""
    }

    func export(session: GlifiStudioProjectSession, format: GlifiStudioStudyExportFormat)
        async throws
        -> Data
    {
        let owner = lifecycle
        try await save(session: session)
        let bytes = try await session.exportStudy(format: format)
        try checkCurrent(owner)
        return bytes
    }

    private func change(_ mutation: (inout GlifiStudioStudyState) -> Void) {
        var next = state
        mutation(&next)
        guard next != state else { return }
        previous.append(state)
        if previous.count > 100 { previous.removeFirst() }
        following = []
        state = next
        updateHistory()
    }

    private func updateHistory() {
        canUndo = !previous.isEmpty
        canRedo = !following.isEmpty
    }

    private func checkCurrent(_ owner: UUID) throws {
        guard !Task.isCancelled, lifecycle == owner else { throw CancellationError() }
    }

    private func checkReading(_ owner: UUID, request: UUID, slot: StudioStudyReaderSlot) throws {
        try checkCurrent(owner)
        guard readingRequests[slot] == request else { throw CancellationError() }
    }

    private func apply(
        _ snapshot: ReadingSnapshot, pdf: PDFDocument?, slot: StudioStudyReaderSlot,
        page: Int?, highlight: NSRange?
    ) {
        let next = StudioStudyReading(
            sourceRevisionID: snapshot.source.sourceRevisionID, source: snapshot.source,
            text: snapshot.text, segments: snapshot.segments,
            characterCount: snapshot.characterCount, title: snapshot.title,
            pdf: pdf, pageNumber: page, highlight: highlight, navigationID: UUID())
        switch slot {
        case .first: firstReading = next
        case .second: secondReading = next
        }
        nativeSelections[slot] = nil
        sourceTitles[snapshot.source.sourceRevisionID] = snapshot.title
        clearPendingPassage()
    }

    nonisolated private struct ReadingSnapshot: Sendable {
        let source: GlifiStudioSourceText
        let text: String
        let segments: [GlifiStudioTextSegment]
        let characterCount: Int
        let title: String
        let pdfData: Data?
    }

    @concurrent private static func readSnapshot(
        session: GlifiStudioProjectSession, sourceID: String
    ) async throws -> ReadingSnapshot {
        let source = try await session.sourceText(sourceRevisionID: sourceID)
        let count = try await session.extractedCharacterCount(sourceRevisionID: sourceID)
        let text: String
        if count > 0 {
            text = try await session.passage(
                sourceRevisionID: sourceID, selection: .characters(start: 0, end: count)
            ).text
        } else {
            text = ""
        }
        let segments = try await session.textSegments(sourceRevisionID: sourceID)
        var title =
            source.document?.metadata["title"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        if title.isEmpty {
            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) {
                line, _, _, stop in
                let candidate = String((line ?? "").prefix(80)).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    title = candidate
                    stop = true
                }
            }
        }
        let data: Data?
        if source.document?.format == .pdf {
            data = try await session.studyOriginal(sourceRevisionID: sourceID).data
        } else {
            data = nil
        }
        try Task.checkCancellation()
        return ReadingSnapshot(
            source: source, text: text, segments: segments, characterCount: count,
            title: String(title.prefix(80)), pdfData: data)
    }

    @concurrent private static func makePDF(_ data: Data) async throws -> sending PDFDocument {
        try Task.checkCancellation()
        guard let document = PDFDocument(data: data) else { throw failure() }
        return document
    }

    @concurrent private static func readExport(at url: URL) async throws -> GlifiStudioStudyState {
        let maximum = 32 * 1_048_576 + 65_536
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        }
        guard descriptor >= 0 else { throw invalidExport() }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var before = stat()
        guard fstat(descriptor, &before) == 0, before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
            before.st_size >= 0
        else { throw invalidExport() }
        guard before.st_size <= Int64(maximum) else { throw invalidExport(resourceLimit: true) }
        var bytes = Data()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: min(65_536, maximum - bytes.count + 1)),
                !chunk.isEmpty
            else { break }
            guard chunk.count <= maximum - bytes.count else {
                throw invalidExport(resourceLimit: true)
            }
            bytes.append(chunk)
        }
        var after = stat()
        guard fstat(descriptor, &after) == 0, before.st_dev == after.st_dev,
            before.st_ino == after.st_ino, before.st_size == after.st_size,
            before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
            before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
            before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
            before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec,
            bytes.count == Int(before.st_size)
        else { throw invalidExport() }
        return try GlifiStudioStudyExport.decode(json: bytes).state
    }

    nonisolated private static func invalidExport(resourceLimit: Bool = false) -> GlifiStudioFailure
    {
        GlifiStudioFailure(
            code: resourceLimit ? "study.resource-limit" : "study.invalid-export",
            category: resourceLimit ? "insufficientResources" : "invalidInput",
            operation: "investigate",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: resourceLimit
                ? "failure.study.resource-limit" : "failure.study.invalid-export")
    }

    @concurrent static func characterSelection(text: String, range: NSRange) async throws
        -> GlifiStudioPassageSelection
    {
        try Task.checkCancellation()
        let count = text.utf16.count
        guard range.location != NSNotFound, range.location >= 0, range.length > 0,
            range.length <= count, range.location <= count - range.length,
            let bounds = Range(range, in: text),
            text.indices.contains(bounds.lowerBound),
            bounds.upperBound == text.endIndex || text.indices.contains(bounds.upperBound)
        else { throw failure() }
        return .characters(
            start: text.distance(from: text.startIndex, to: bounds.lowerBound),
            end: text.distance(from: text.startIndex, to: bounds.upperBound))
    }

    @concurrent private static func nativeRange(text: String, startUTF8: Int, endUTF8: Int)
        async throws -> NSRange
    {
        try Task.checkCancellation()
        guard startUTF8 >= 0, endUTF8 > startUTF8, endUTF8 <= text.utf8.count,
            let start = text.utf8.index(text.utf8.startIndex, offsetBy: startUTF8).samePosition(
                in: text),
            let end = text.utf8.index(text.utf8.startIndex, offsetBy: endUTF8).samePosition(
                in: text)
        else { throw failure() }
        return NSRange(start..<end, in: text)
    }

    nonisolated static func failure() -> GlifiStudioFailure {
        GlifiStudioFailure(
            code: "study.invalid-selection", category: "invalidInput", operation: "investigate",
            retryDisposition: "afterCorrection", retainedState: "unchanged",
            messageKey: "failure.study.invalid-selection")
    }
}
