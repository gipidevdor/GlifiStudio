// SPDX-License-Identifier: BSD-3-Clause

import Foundation

/// A verified passage and the two explicitly different coordinate representations.
public struct GlifiStudyResolvedExcerpt: Sendable {
    /// Frozen passage and editable title.
    public let excerpt: GlifiStudyExcerpt
    /// Complete extracted text addressed by the anchor offsets.
    public let extractedText: String
    /// Source representation addressed by the real contributing source intervals.
    public let sourceText: String
    /// Real contributing source intervals, never inferred PDF rectangles.
    public let sourceRanges: [GlifiStudyRange]
    package let imported: GlifiImportedText
}

/// Verified original document bytes for a native reader.
public struct GlifiStudyOriginal: Sendable {
    /// Immutable source revision.
    public let sourceRevisionID: String
    /// Digest of the exact incorporated bytes.
    public let contentDigest: String
    /// Captured original format.
    public let format: GlifiTextFormat
    /// Exact original bytes, bounded at 64 MiB.
    public let data: Data
}

private struct StudyArtifact: GlifiAnalysisArtifactPayload {
    static let outputSchemaIdentifier = "studio.glifi.artifact.study-state.v1"
    let schemaIdentifier: String
    let schemaVersion: Int
    let analysisNodeID: AnalysisNodeID
    let previousArtifactID: String?
    let state: GlifiStudyState
}

extension GlifiProjectPackage {
    /// Restores the latest verified notebook without creating a revision or re-extracting a source.
    public func studyState() throws -> GlifiStudyState {
        try studyCheckCancellation()
        let history = try studyHistory()
        guard let latest = history.last else {
            return GlifiStudyState(projectID: snapshot().projectID.canonicalValue)
        }
        guard latest.byteCount <= 32 * 1_048_576 + 65_536 else {
            throw studyFailure("study.invalid-history", category: .corruption)
        }
        let data = try artifactData(for: latest.artifactID)
        guard let payload = try? JSONDecoder().decode(StudyArtifact.self, from: data),
            payload.schemaIdentifier == StudyArtifact.outputSchemaIdentifier,
            payload.schemaVersion == 1, payload.analysisNodeID == latest.node.id,
            payload.previousArtifactID == history.dropLast().last?.artifactID.canonicalValue,
            payload.state.revision == history.count,
            latest.node.descriptor.resolvedParameters["contentDigest"]
                == .text(try studyDigest(payload.state))
        else { throw studyFailure("study.invalid-history", category: .corruption) }
        do {
            try validateStudyState(payload.state)
        } catch let failure as GlifiFailure {
            if failure.category == .invalidInput || failure.category == .insufficientData {
                throw studyFailure("study.invalid-history", category: .corruption)
            }
            throw failure
        }
        return payload.state
    }

    /// Appends a complete project-bound notebook after optimistic and source-integrity checks.
    @discardableResult
    public func saveStudyState(_ proposed: GlifiStudyState, expectedRevision: Int) throws
        -> GlifiStudyState
    {
        try studyCheckCancellation()
        let current = try studyState()
        guard proposed.projectID == snapshot().projectID.canonicalValue else {
            throw studyFailure("study.project-mismatch")
        }
        guard current.revision == expectedRevision, proposed.revision == expectedRevision else {
            throw studyFailure("study.stale-revision", category: .staleArtifact)
        }
        guard current.revision < 10_000 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        try proposed.validateResourceBounds()
        let existing = Dictionary(uniqueKeysWithValues: current.excerpts.map { ($0.id, $0.anchor) })
        for excerpt in proposed.excerpts {
            if let anchor = existing[excerpt.id], !studyAnchorsAreIdentical(anchor, excerpt.anchor)
            {
                throw studyFailure("study.immutable-anchor")
            }
        }
        try validateStudyState(proposed)
        var next = proposed
        next.revision += 1
        let previous = try studyHistory().last
        let descriptor = try studyDescriptor(next, previous: previous)
        let payload = StudyArtifact(
            schemaIdentifier: StudyArtifact.outputSchemaIdentifier, schemaVersion: 1,
            analysisNodeID: try descriptor.nodeID(),
            previousArtifactID: previous?.artifactID.canonicalValue, state: next)
        try studyCheckCancellation()
        _ = try storeArtifact(payload, descriptor: descriptor)
        return next
    }

    /// Collects an existing passage selection, preserving its exact immutable UTF-8 provenance.
    public func collectStudyExcerpt(
        sourceRevisionID: String, selection: GlifiPassageSelection, title: String,
        groupID: String? = nil, expectedRevision: Int
    ) async throws -> GlifiStudyState {
        try studyCheckCancellation()
        let state = try studyState()
        guard state.revision == expectedRevision else {
            throw studyFailure("study.stale-revision", category: .staleArtifact)
        }
        guard groupID == nil || state.groups.contains(where: { $0.id == groupID }) else {
            throw studyFailure("study.unknown-group")
        }
        let source = try studySource(sourceRevisionID)
        let passage: (range: GlifiUTF8Range, text: String)
        do {
            passage = try await GlifiEngine().passage(
                sourceRevisionID: source.sourceRevisionID, selection: selection, in: self)
        } catch let failure as GlifiFailure {
            if failure.category == .cancelled {
                throw studyFailure("study.cancelled", category: .cancelled)
            }
            if failure.code == "qualitative.invalid-selection" {
                throw studyFailure("study.invalid-selection")
            }
            throw failure
        } catch is CancellationError {
            throw studyFailure("study.cancelled", category: .cancelled)
        }
        let imported = try importedText(for: source.sourceRevisionID)
        guard passage.text.utf8.count <= 1_048_576 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        let ranges = try imported.spanMap.sourceRanges(for: passage.range).map {
            GlifiStudyRange(startUTF8: $0.start, endUTF8: $0.end)
        }
        let anchor = GlifiStudyAnchor(
            sourceRevisionID: sourceRevisionID, sourceContentDigest: imported.contentDigest,
            representationDigest: studyBytesDigest(Data(imported.text.utf8)),
            extractionContractIdentifier: imported.extractionContractIdentifier,
            startUTF8: passage.range.start, endUTF8: passage.range.end, quote: passage.text,
            sourceRanges: ranges)
        let id = String(try studyDigest(anchor).dropFirst(7))
        var next = state
        if let index = next.excerpts.firstIndex(where: { $0.id == id }) {
            next.excerpts[index].title = title
            next.excerpts[index].groupID = groupID
        } else {
            next.excerpts.append(.init(id: id, title: title, groupID: groupID, anchor: anchor))
            next.order.append(id)
        }
        return try saveStudyState(next, expectedRevision: expectedRevision)
    }

    /// Verifies an anchor and restores captured text and source mapping without rerunning extraction.
    public func resolveStudyExcerpt(excerptID: String) throws -> GlifiStudyResolvedExcerpt {
        let state = try studyState()
        guard let excerpt = state.excerpts.first(where: { $0.id == excerptID }) else {
            throw studyFailure("study.unknown-excerpt")
        }
        let imported = try importedText(
            for: studySource(excerpt.anchor.sourceRevisionID).sourceRevisionID)
        try validateStudyAnchor(excerpt.anchor, imported: imported)
        let original = try imported.sourceRepresentationText
        guard imported.text.utf8.count <= 64 * 1_048_576 - original.utf8.count else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        return GlifiStudyResolvedExcerpt(
            excerpt: excerpt, extractedText: imported.text,
            sourceText: original, sourceRanges: excerpt.anchor.sourceRanges, imported: imported)
    }

    /// Reads verified original bytes for a native viewer, without altering the source.
    public func studyOriginal(sourceRevisionID: String) throws -> GlifiStudyOriginal {
        try studyCheckCancellation()
        let source = try studySource(sourceRevisionID)
        let bytes = try sourceData(for: source.sourceRevisionID)
        try studyCheckCancellation()
        return GlifiStudyOriginal(
            sourceRevisionID: sourceRevisionID, contentDigest: source.contentDigest,
            format: source.format, data: bytes)
    }

    /// Produces deterministic project-bound JSON or a readable personal notebook.
    public func exportStudy(format: GlifiStudyExportFormat = .json) throws -> Data {
        let state = try studyState()
        switch format {
        case .json: return try studyData(GlifiStudyExport(state: state))
        case .markdown:
            var lines = [
                "# Taccuino di studio", "",
                "Annotazioni personali; non costituiscono evidenze scientifiche.", "",
            ]
            let excerpts = Dictionary(uniqueKeysWithValues: state.excerpts.map { ($0.id, $0) })
            let notes = Dictionary(uniqueKeysWithValues: state.notes.map { ($0.id, $0) })
            let orderedExcerpts = state.order.filter { excerpts[$0] != nil }
            let labels = Dictionary(
                uniqueKeysWithValues: orderedExcerpts.enumerated().map {
                    ($0.element, $0.offset + 1)
                })
            let groups = Dictionary(uniqueKeysWithValues: state.groups.map { ($0.id, $0.title) })
            var renderedBytes = lines.reduce(0) { $0 + $1.utf8.count + 1 }
            func append(_ rows: [String]) throws {
                for row in rows {
                    guard row.utf8.count < 64 * 1_048_576 - renderedBytes else {
                        throw studyFailure("study.resource-limit", category: .insufficientResources)
                    }
                    renderedBytes += row.utf8.count + 1
                }
                lines += rows
            }
            for id in state.order {
                try studyCheckCancellation()
                if let excerpt = excerpts[id] {
                    guard let number = labels[id] else {
                        throw studyFailure("study.invalid-state", category: .invariantViolation)
                    }
                    try append([
                        "## Passaggio \(number) · \(excerpt.title)", "",
                        "> " + excerpt.anchor.quote.replacingOccurrences(of: "\n", with: "\n> "),
                        "",
                        "Gruppo: " + (excerpt.groupID.flatMap { groups[$0] } ?? "Senza gruppo"), "",
                        "<details><summary>Provenienza</summary>", "",
                        "Fonte: \(excerpt.anchor.sourceRevisionID)",
                        "Intervallo UTF-8 estratto: \(excerpt.anchor.startUTF8)..<\(excerpt.anchor.endUTF8)",
                        "Digest: \(excerpt.anchor.sourceContentDigest)", "", "</details>", "",
                    ])
                }
                if let note = notes[id] {
                    let links = try note.excerptIDs.map { linkedID in
                        guard let number = labels[linkedID], let linked = excerpts[linkedID] else {
                            throw studyFailure("study.invalid-state", category: .invariantViolation)
                        }
                        return "[\(number)] \(linked.title)"
                    }.joined(separator: ", ")
                    try append([
                        "## \(note.title)", "", note.text, "",
                        "Gruppo: " + (note.groupID.flatMap { groups[$0] } ?? "Senza gruppo"), "",
                        "Passaggi collegati: " + links, "",
                    ])
                }
            }
            return Data(lines.joined(separator: "\n").utf8)
        }
    }

    private func studySource(_ id: String) throws -> GlifiProjectSourceRecord {
        guard
            let source = snapshot().sources.first(where: {
                $0.sourceRevisionID.canonicalValue == id
            })
        else { throw studyFailure("study.unknown-source") }
        guard source.byteCount <= 64 * 1_048_576 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        return source
    }

    private func validateStudyState(_ state: GlifiStudyState) throws {
        try studyCheckCancellation()
        guard state.projectID == snapshot().projectID.canonicalValue else {
            throw studyFailure("study.project-mismatch")
        }
        try state.validate()
        if let id = state.investigationID {
            guard
                snapshot().investigationEvents.contains(where: {
                    $0.investigationID.canonicalValue == id
                })
            else { throw studyFailure("study.unknown-investigation") }
        }
        let grouped = Dictionary(grouping: state.excerpts, by: { $0.anchor.sourceRevisionID })
        for sourceID in grouped.keys.sorted() {
            try studyCheckCancellation()
            let source = try studySource(sourceID)
            let imported = try importedText(for: source.sourceRevisionID)
            for excerpt in grouped[sourceID] ?? [] {
                try validateStudyAnchor(excerpt.anchor, imported: imported)
            }
        }
    }

    private func validateStudyAnchor(_ anchor: GlifiStudyAnchor, imported: GlifiImportedText) throws
    {
        try studyCheckCancellation()
        guard anchor.sourceContentDigest == imported.contentDigest,
            anchor.representationDigest == studyBytesDigest(Data(imported.text.utf8)),
            anchor.extractionContractIdentifier == imported.extractionContractIdentifier,
            let range = try? GlifiUTF8Range(start: anchor.startUTF8, end: anchor.endUTF8),
            let quote = studyCharacterAlignedText(range, in: imported.text),
            quote.utf8.elementsEqual(anchor.quote.utf8),
            try imported.spanMap.sourceRanges(for: range).map({
                GlifiStudyRange(startUTF8: $0.start, endUTF8: $0.end)
            }) == anchor.sourceRanges
        else { throw studyFailure("study.invalid-anchor") }
    }

    private func studyHistory() throws -> [GlifiProjectArtifactRecord] {
        let history = snapshot().artifacts.filter {
            $0.node.descriptor.artifactTypeIdentifier == "studio.glifi.artifact.study-state"
        }
        .sorted { studyRevision($0) < studyRevision($1) }
        guard history.count <= 10_000 else {
            throw studyFailure("study.resource-limit", category: .insufficientResources)
        }
        for (index, record) in history.enumerated() {
            try studyCheckCancellation()
            let d = record.node.descriptor
            guard studyRevision(record) == index + 1,
                d.outputSchemaIdentifier == StudyArtifact.outputSchemaIdentifier,
                d.algorithmIdentifier == "study-state-append-v1", d.algorithmVersion == "1",
                d.sourceRevisionIDs == [],
                d.corpusIdentifier == snapshot().projectID.canonicalValue,
                d.corpusVersionDigest == (try snapshot().corpusVersionDigest(for: [])),
                d.dependencies.count == (index == 0 ? 0 : 1)
            else { throw studyFailure("study.invalid-history", category: .corruption) }
            if index > 0 {
                let previous = history[index - 1]
                guard d.dependencies.first?.nodeID == previous.node.id,
                    d.dependencies.first?.artifactDigest == previous.contentDigest,
                    d.dependencies.first?.outputSchemaIdentifier
                        == StudyArtifact.outputSchemaIdentifier
                else { throw studyFailure("study.invalid-history", category: .corruption) }
            }
        }
        return history
    }

    private func studyDescriptor(_ state: GlifiStudyState, previous: GlifiProjectArtifactRecord?)
        throws -> GlifiAnalysisDescriptor
    {
        let snapshot = snapshot()
        let dependencies =
            try previous.map {
                [
                    try GlifiAnalysisDependency(
                        nodeID: $0.node.id, artifactDigest: $0.contentDigest,
                        outputSchemaIdentifier: StudyArtifact.outputSchemaIdentifier)
                ]
            } ?? []
        return try GlifiAnalysisDescriptor(
            artifactTypeIdentifier: "studio.glifi.artifact.study-state",
            algorithmIdentifier: "study-state-append-v1", algorithmVersion: "1",
            corpusIdentifier: snapshot.projectID.canonicalValue,
            corpusVersionDigest: snapshot.corpusVersionDigest(for: []),
            selectionIdentifier: "project-notebook",
            analyticalUnitIdentifier: "manual-study-state", preprocessingIdentifiers: [],
            linguisticProfileIdentifiers: [],
            representationIdentifier: "immutable-passages-and-manual-notes-v1",
            resolvedParameters: [
                "revision": .integer(Int64(state.revision)),
                "contentDigest": .text(try studyDigest(state)),
            ],
            seedPolicyIdentifier: "no-randomness", backendIdentifier: "studio.glifi.native",
            numericPolicyIdentifier: "typed-json-v1",
            determinismClass: .d0, outputSchemaIdentifier: StudyArtifact.outputSchemaIdentifier,
            softwareIdentifier: "GlifiStudio-study-v1", dependencies: dependencies,
            sourceRevisionIDs: [])
    }
}

private func studyRevision(_ record: GlifiProjectArtifactRecord) -> Int64 {
    if case let .integer(value) = record.node.descriptor.resolvedParameters["revision"] {
        return value
    }
    return -1
}

package func studyCheckCancellation() throws {
    if Task.isCancelled { throw studyFailure("study.cancelled", category: .cancelled) }
}

private func studyCharacterAlignedText(_ range: GlifiUTF8Range, in text: String) -> String? {
    let bytes = text.utf8
    guard range.end <= bytes.count,
        let lower = bytes.index(bytes.startIndex, offsetBy: range.start, limitedBy: bytes.endIndex),
        let upper = bytes.index(bytes.startIndex, offsetBy: range.end, limitedBy: bytes.endIndex),
        let start = lower.samePosition(in: text), let end = upper.samePosition(in: text)
    else { return nil }
    return String(text[start..<end])
}

private func studyAnchorsAreIdentical(_ first: GlifiStudyAnchor, _ second: GlifiStudyAnchor) -> Bool
{
    first.sourceRevisionID.utf8.elementsEqual(second.sourceRevisionID.utf8)
        && first.sourceContentDigest.utf8.elementsEqual(second.sourceContentDigest.utf8)
        && first.representationIdentifier.utf8.elementsEqual(second.representationIdentifier.utf8)
        && first.representationDigest.utf8.elementsEqual(second.representationDigest.utf8)
        && first.extractionContractIdentifier.utf8.elementsEqual(
            second.extractionContractIdentifier.utf8)
        && first.startUTF8 == second.startUTF8 && first.endUTF8 == second.endUTF8
        && first.quote.utf8.elementsEqual(second.quote.utf8)
        && first.sourceRanges == second.sourceRanges
}
