// SPDX-License-Identifier: BSD-3-Clause

import GlifiKit
import SwiftUI

/// Qualitative coding section (GS-UX-001-16): codebook, coding by sentence, review and agreement.
///
/// Every change goes through GlifiKit; the view holds only drafts and selections.
struct StudioCodingView: View {
    /// Structured way of selecting the passage, both available without dragging.
    private enum PassageMode: String, CaseIterable, Identifiable {
        /// Whole sentences, from the selected one through an optional last one.
        case sentences
        /// An interval of characters of the extracted text.
        case characters

        var id: String { rawValue }
    }

    @Bindable var model: StudioHomeModel

    @State private var draftLabel = ""
    @State private var draftDefinition = ""
    @State private var draftCategories: [GlifiStudioCodebookCategory] = []
    @State private var selectedSegmentID: String?
    @State private var lastSegmentID: String?
    @State private var passageMode: PassageMode = .sentences
    @State private var resolvedSelection: GlifiStudioPassageSelection?
    @State private var characterStart = 0
    @State private var characterEnd = 0
    @State private var selectedCategoryID: String?
    @State private var noteDraft = ""
    @State private var noteTargetID: String?
    @State private var agreementCoders: Set<String> = []

    var body: some View {
        Form {
            codebookSection
            if model.activeCodebook != nil {
                codingSection
                codingsSection
                agreementSection
            }
        }
        .formStyle(.grouped)
        .disabled(model.isBusy || model.snapshot == nil)
        .navigationTitle("sidebar.coding")
        .task { await model.loadQualitativeState() }
    }

    // MARK: - Codebook

    private var codebookSection: some View {
        Section("coding.codebook") {
            if let codebook = model.activeCodebook {
                LabeledContent("coding.codebook.revision") {
                    Text(codebook.revision, format: .number).monospacedDigit()
                }
                ForEach(codebook.categories, id: \.categoryID) { category in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.label).font(.headline)
                        Text(category.definition).font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text("coding.codebook.empty").foregroundStyle(.secondary)
            }
            TextField("coding.category.label", text: $draftLabel)
            TextField("coding.category.definition", text: $draftDefinition, axis: .vertical)
            Button("action.add-category", systemImage: "plus") {
                draftCategories.append(
                    GlifiStudioCodebookCategory(
                        categoryID: GlifiStudioCodebookCategory.identifier(forLabel: draftLabel),
                        label: draftLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                        definition: draftDefinition.trimmingCharacters(in: .whitespacesAndNewlines))
                )
                draftLabel = ""
                draftDefinition = ""
            }
            .disabled(
                draftLabel.trimmingCharacters(in: .whitespaces).isEmpty
                    || draftDefinition.trimmingCharacters(in: .whitespaces).isEmpty)
            if !draftCategories.isEmpty {
                ForEach(draftCategories, id: \.categoryID) { category in
                    Label(category.label, systemImage: "plus.circle")
                }
                Button("action.register-revision", systemImage: "checkmark.seal") {
                    let categories = (model.activeCodebook?.categories ?? []) + draftCategories
                    Task {
                        await model.registerCodebookRevision(categories)
                        if model.lastFailure == nil { draftCategories = [] }
                    }
                }
                .disabled(model.isBusy)
            }
        }
    }

    // MARK: - Coding

    private var codingSection: some View {
        Section("coding.code") {
            Picker(
                "coding.source",
                selection: Binding(
                    get: { model.codingSourceRevisionID },
                    set: { value in
                        selectedSegmentID = nil
                        lastSegmentID = nil
                        if let value { Task { await model.loadCodingSource(value) } }
                    }
                )
            ) {
                Text("coding.source.none").tag(String?.none)
                ForEach(model.snapshot?.sources ?? [], id: \.sourceRevisionID) { source in
                    Text(source.sourceRevisionID.suffix(12)).tag(Optional(source.sourceRevisionID))
                }
            }
            TextField("coding.coder", text: $model.coderDraft)
            List(model.codingSegments, selection: $selectedSegmentID) { segment in
                Text(segment.text)
                    .lineLimit(3)
                    .tag(segment.id)
                    .accessibilityAddTraits(
                        segment.id == selectedSegmentID ? .isSelected : [])
            }
            .frame(minHeight: 160, maxHeight: 300)
            .accessibilityLabel("coding.segments")
            selectionControls
            passagePreview
            Picker("coding.category", selection: $selectedCategoryID) {
                Text("coding.category.none").tag(String?.none)
                ForEach(model.activeCodebook?.categories ?? [], id: \.categoryID) { category in
                    Text(category.label).tag(Optional(category.categoryID))
                }
            }
            Button("action.code-segment", systemImage: "highlighter") {
                guard let categoryID = selectedCategoryID else { return }
                Task { await model.codeResolvedPassage(categoryID: categoryID) }
            }
            .disabled(
                model.isBusy || resolvedPassage == nil || selectedCategoryID == nil
                    || model.coderDraft.isEmpty)
        }
    }

    /// Selection of the passage, by whole sentences or by character interval, without dragging.
    @ViewBuilder private var selectionControls: some View {
        Picker("coding.selection.mode", selection: $passageMode) {
            Text("coding.selection.mode.sentences").tag(PassageMode.sentences)
            Text("coding.selection.mode.characters").tag(PassageMode.characters)
        }
        .pickerStyle(.segmented)
        switch passageMode {
        case .sentences:
            Picker("coding.selection.last-sentence", selection: $lastSegmentID) {
                Text("coding.selection.last-sentence.same").tag(String?.none)
                ForEach(model.codingSegments) { segment in
                    Text(segment.text).lineLimit(1).tag(Optional(segment.id))
                }
            }
        case .characters:
            LabeledContent("coding.selection.character-count") {
                Text(model.codingSourceCharacterCount, format: .number).monospacedDigit()
            }
            TextField("coding.selection.character-start", value: $characterStart, format: .number)
            TextField("coding.selection.character-end", value: $characterEnd, format: .number)
        }
        Button("action.resolve-passage", systemImage: "text.viewfinder") {
            guard let selection = currentSelection else { return }
            Task {
                await model.resolvePassage(selection)
                resolvedSelection = model.lastFailure == nil ? selection : nil
            }
        }
        .disabled(model.isBusy || currentSelection == nil)
    }

    /// Resolved passage, shown before it is recorded, aligned to character boundaries.
    @ViewBuilder private var passagePreview: some View {
        if let passage = resolvedPassage {
            VStack(alignment: .leading, spacing: 2) {
                Text("coding.passage").font(.caption).foregroundStyle(.secondary)
                Text(passage.text).font(.callout)
                Text(verbatim: "\(passage.startUTF8)–\(passage.endUTF8)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("coding.passage.none").foregroundStyle(.secondary)
        }
    }

    /// Resolved passage, only while it still describes the selection shown in the controls.
    private var resolvedPassage: GlifiStudioTextSegment? {
        guard let passage = model.codingPassage, resolvedSelection == currentSelection else {
            return nil
        }
        return passage
    }

    /// Selection requested by the current controls, absent when it cannot be built.
    private var currentSelection: GlifiStudioPassageSelection? {
        switch passageMode {
        case .sentences:
            guard
                let first = model.codingSegments.firstIndex(where: { $0.id == selectedSegmentID })
            else {
                return nil
            }
            let last =
                model.codingSegments.firstIndex(where: { $0.id == lastSegmentID }) ?? first
            return .sentences(first: first, last: last)
        case .characters:
            return .characters(start: characterStart, end: characterEnd)
        }
    }

    // MARK: - Review

    private var codingsSection: some View {
        Section("coding.codings") {
            let codings = model.qualitativeState?.codings ?? []
            if codings.isEmpty {
                Text("coding.codings.empty").foregroundStyle(.secondary)
            }
            ForEach(codings, id: \.eventID) { coding in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(label(for: coding.categoryID)).font(.headline)
                        Spacer()
                        Text(
                            LocalizedStringKey(
                                coding.retractionEventID == nil
                                    ? "coding.state.active" : "coding.state.retracted")
                        )
                        .font(.caption)
                        .foregroundStyle(coding.retractionEventID == nil ? .primary : .secondary)
                    }
                    Text(segmentText(for: coding)).font(.callout).lineLimit(2)
                    LabeledContent("coding.coder") {
                        Text(coding.coderID).font(.caption.monospaced())
                    }
                    let notes = (model.qualitativeState?.memos ?? []).filter {
                        $0.target == .coding(eventID: coding.eventID)
                    }
                    ForEach(notes, id: \.eventID) { note in
                        Label(note.text, systemImage: "note.text").font(.caption)
                    }
                    if coding.retractionEventID == nil {
                        HStack {
                            Menu("action.retract-coding") {
                                Button("coding.reason.error") {
                                    Task {
                                        await model.retractCoding(coding.eventID, reason: "errore")
                                    }
                                }
                                Button("coding.reason.revision") {
                                    Task {
                                        await model.retractCoding(
                                            coding.eventID, reason: "revisione-categoria")
                                    }
                                }
                            }
                            Button("action.add-note", systemImage: "note.text.badge.plus") {
                                noteTargetID = coding.eventID
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    if noteTargetID == coding.eventID {
                        TextField("coding.note", text: $noteDraft, axis: .vertical)
                        Button("action.save-note") {
                            let text = noteDraft
                            Task {
                                await model.attachNote(to: coding.eventID, text: text)
                                if model.lastFailure == nil {
                                    noteDraft = ""
                                    noteTargetID = nil
                                }
                            }
                        }
                        .disabled(noteDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    // MARK: - Agreement

    private var agreementSection: some View {
        Section("coding.agreement") {
            ForEach(model.knownCoders, id: \.self) { coder in
                Toggle(
                    coder,
                    isOn: Binding(
                        get: { agreementCoders.contains(coder) },
                        set: {
                            if $0 {
                                agreementCoders.insert(coder)
                            } else {
                                agreementCoders.remove(coder)
                            }
                        }
                    ))
            }
            Button("action.assess-agreement", systemImage: "person.2") {
                let coders = agreementCoders.sorted()
                Task { await model.assessAgreement(coders: coders) }
            }
            .disabled(model.isBusy || agreementCoders.count < 2)
            if let result = model.storedAgreement {
                LabeledContent("coding.agreement.units") {
                    Text(result.agreement.unitCount, format: .number).monospacedDigit()
                }
                LabeledContent("coding.agreement.ambiguous") {
                    Text(result.ambiguousUnitCount, format: .number).monospacedDigit()
                }
                if let alpha = result.agreement.krippendorff?.alpha {
                    LabeledContent("coding.agreement.alpha") {
                        Text(alpha, format: .number.precision(.fractionLength(3))).monospacedDigit()
                    }
                }
                if let kappa = result.agreement.cohen?.kappa {
                    LabeledContent("coding.agreement.kappa") {
                        Text(kappa, format: .number.precision(.fractionLength(3))).monospacedDigit()
                    }
                }
                if result.ambiguousUnitCount > 0 {
                    Label("coding.agreement.ambiguous-explained", systemImage: "info.circle")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Helpers

    private func label(for categoryID: String) -> String {
        model.qualitativeState?.codebooks.first?.revisions
            .flatMap { $0 }.first { $0.categoryID == categoryID }?.label ?? categoryID
    }

    private func segmentText(for coding: GlifiStudioCoding) -> String {
        model.codingTexts[coding.eventID] ?? "\(coding.startUTF8)–\(coding.endUTF8)"
    }
}
