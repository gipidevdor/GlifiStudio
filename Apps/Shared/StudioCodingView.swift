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
    @State private var agreementRevision: Int?

    var body: some View {
        Form {
            codebookSection
            StudioCodebookManagementView(model: model)
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
        .onChange(of: model.selectedCodebookID) { _, _ in
            selectedCategoryID = nil
            agreementCoders = []
            agreementRevision = nil
        }
        .onChange(of: model.activeCodebook?.revision) { _, _ in
            selectedCategoryID = nil
            agreementCoders = []
            agreementRevision = nil
        }
    }

    // MARK: - Codebook

    private var codebookSection: some View {
        Section("coding.codebook") {
            if let books = model.qualitativeState?.codebooks, books.count > 1 {
                Picker(
                    "coding.management.book",
                    selection: Binding(
                        get: { model.activeCodebook?.codebookID },
                        set: { model.selectedCodebookID = $0 })
                ) {
                    ForEach(books, id: \.codebookID) { book in
                        Text(book.codebookID).tag(Optional(book.codebookID))
                    }
                }
            }
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
            if let codebook = model.activeCodebook {
                Picker("coding.agreement.revision", selection: $agreementRevision) {
                    Text("coding.agreement.latest-revision").tag(Int?.none)
                    ForEach(1...codebook.revision, id: \.self) { revision in
                        Text(revision, format: .number).tag(Optional(revision))
                    }
                }
            }
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
                let revision = agreementRevision
                Task { await model.assessAgreement(coders: coders, revision: revision) }
            }
            .disabled(model.isBusy || agreementCoders.count < 2)
            if let result = model.storedAgreement {
                LabeledContent(
                    "coding.management.book", value: model.storedAgreementCodebookID ?? "")
                if let revision = model.storedAgreementRevision {
                    LabeledContent("coding.agreement.revision") { Text(revision, format: .number) }
                }
                LabeledContent(
                    "coding.agreement.captured-coders",
                    value: result.agreement.coderIdentifiers.joined(separator: ", "))
                if Set(result.agreement.coderIdentifiers) != agreementCoders
                    || model.storedAgreementRevision
                        != (agreementRevision ?? model.activeCodebook?.revision)
                {
                    Label("coding.agreement.draft-changed", systemImage: "info.circle")
                }
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
        model.qualitativeState?.codebooks.first(where: {
            $0.codebookID == model.activeCodebook?.codebookID
        })?.revisions
            .flatMap { $0 }.first { $0.categoryID == categoryID }?.label ?? categoryID
    }

    private func segmentText(for coding: GlifiStudioCoding) -> String {
        model.codingTexts[coding.eventID] ?? "\(coding.startUTF8)–\(coding.endUTF8)"
    }
}

private struct StudioCodebookCategoryDraft: Identifiable {
    let id = UUID()
    var categoryID = ""
    var parentID: String?
    var label = ""
    var definition = ""
    var instructions = ""

    var value: GlifiStudioCodebookCategory {
        GlifiStudioCodebookCategory(
            categoryID: categoryID, parentCategoryID: parentID, label: label,
            definition: definition, instructions: instructions.isEmpty ? nil : instructions)
    }
}

/// Complete, explicit editing of the existing append-only qualitative contracts.
private struct StudioCodebookManagementView: View {
    @Bindable var model: StudioHomeModel
    @State private var bookID = "temi"
    @State private var categories: [StudioCodebookCategoryDraft] = []
    @State private var expandedCategories: Set<UUID> = []
    @FocusState private var focusedCategory: UUID?
    @State private var mappingKind = "rename"
    @State private var fromRevision = 1
    @State private var toRevision = 2
    @State private var fromIDs = ""
    @State private var toIDs = ""
    @State private var memoKind = "source"
    @State private var memoCategory = ""
    @State private var memo = ""

    var body: some View {
        Section {
            DisclosureGroup("coding.management.title") {
                Text("coding.management.explanation").foregroundStyle(.secondary)
                TextField("coding.management.book-id", text: $bookID)
                    .autocorrectionDisabled()
                Button("coding.management.load-current") {
                    guard let book = model.activeCodebook else { return }
                    expandedCategories = []
                    focusedCategory = nil
                    bookID = book.codebookID
                    categories = book.categories.map {
                        StudioCodebookCategoryDraft(
                            categoryID: $0.categoryID,
                            parentID: $0.parentCategoryID, label: $0.label,
                            definition: $0.definition, instructions: $0.instructions ?? "")
                    }
                }
                ForEach($categories) { $category in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedCategories.contains(category.id) },
                            set: { expanded in
                                if expanded {
                                    expandedCategories.insert(category.id)
                                } else {
                                    expandedCategories.remove(category.id)
                                }
                            })
                    ) {
                        TextField("coding.management.category-id", text: $category.categoryID)
                            .autocorrectionDisabled()
                            .focused($focusedCategory, equals: category.id)
                        TextField("coding.category.label", text: $category.label)
                        TextField(
                            "coding.category.definition", text: $category.definition,
                            axis: .vertical)
                        TextField(
                            "coding.management.instructions", text: $category.instructions,
                            axis: .vertical)
                        Picker("coding.management.parent", selection: $category.parentID) {
                            Text("coding.management.no-parent").tag(String?.none)
                            ForEach(
                                categories.filter { $0.id != category.id && !$0.categoryID.isEmpty }
                            ) { parent in
                                Text(parent.label.isEmpty ? parent.categoryID : parent.label).tag(
                                    Optional(parent.categoryID))
                            }
                        }
                        Button("coding.management.remove-draft", role: .destructive) {
                            let identity = category.id
                            categories.removeAll { $0.id == identity }
                            expandedCategories.remove(identity)
                            if focusedCategory == identity { focusedCategory = nil }
                        }
                    } label: {
                        if category.label.isEmpty && category.categoryID.isEmpty {
                            Text("coding.management.new-category")
                        } else {
                            Text(category.label.isEmpty ? category.categoryID : category.label)
                        }
                    }
                }
                Button("coding.management.add-category", systemImage: "plus") {
                    let category = StudioCodebookCategoryDraft()
                    categories.append(category)
                    expandedCategories.insert(category.id)
                    focusedCategory = category.id
                }.disabled(categories.count >= 128)
                Button("coding.management.record-full-revision", systemImage: "checkmark.seal") {
                    let values = categories.map(\.value)
                    let identity = bookID
                    Task { await model.registerCodebookRevision(values, codebookID: identity) }
                }
                .disabled(
                    categories.isEmpty || bookID.isEmpty
                        || categories.contains {
                            $0.categoryID.isEmpty || $0.label.isEmpty || $0.definition.isEmpty
                        })
                mappingEditor
                memoEditor
            }
        }
    }

    private var mappingEditor: some View {
        DisclosureGroup("coding.management.mapping") {
            Text("coding.management.mapping-help").foregroundStyle(.secondary)
            Picker("coding.management.mapping-kind", selection: $mappingKind) {
                Text("coding.management.rename").tag("rename")
                Text("coding.management.merge").tag("merge")
                Text("coding.management.split").tag("split")
            }
            TextField("coding.management.from-revision", value: $fromRevision, format: .number)
            TextField("coding.management.to-revision", value: $toRevision, format: .number)
            TextField("coding.management.from-categories", text: $fromIDs)
            TextField("coding.management.to-categories", text: $toIDs)
            Button("coding.management.record-mapping") {
                let mapping = GlifiStudioCategoryMapping(
                    kind: mappingKind,
                    fromCategoryIDs: fromIDs.split(whereSeparator: \.isWhitespace).map(String.init),
                    toCategoryIDs: toIDs.split(whereSeparator: \.isWhitespace).map(String.init))
                let identity = bookID
                let first = fromRevision
                let last = toRevision
                Task {
                    await model.mapCategories(
                        codebookID: identity, fromRevision: first, toRevision: last,
                        mapping: mapping)
                }
            }.disabled(
                bookID.isEmpty || fromIDs.isEmpty || toIDs.isEmpty || fromRevision < 1
                    || toRevision <= fromRevision)
        }
    }

    private var memoEditor: some View {
        DisclosureGroup("coding.management.memo") {
            TextField("coding.coder", text: $model.coderDraft)
            Picker("coding.management.memo-target", selection: $memoKind) {
                Text("coding.source").tag("source")
                Text("coding.category").tag("category")
            }
            if memoKind == "source" {
                Text("coding.management.memo-source-help").foregroundStyle(.secondary)
                if let source = model.codingSourceRevisionID {
                    Text(source).font(.caption.monospaced()).textSelection(.enabled)
                }
            } else {
                TextField("coding.management.category-id", text: $memoCategory)
            }
            TextField("coding.note", text: $memo, axis: .vertical)
            Button("action.save-note") {
                let target: GlifiStudioMemoTarget
                if memoKind == "source", let source = model.codingSourceRevisionID {
                    target = .source(sourceRevisionID: source)
                } else {
                    target = .category(codebookID: bookID, categoryID: memoCategory)
                }
                let text = memo
                Task {
                    await model.attachNote(to: target, text: text)
                    if model.lastFailure == nil { memo = "" }
                }
            }
            .disabled(
                memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || model.coderDraft.isEmpty
                    || (memoKind == "source"
                        ? model.codingSourceRevisionID == nil
                        : bookID.isEmpty || memoCategory.isEmpty)
            )
            ForEach(
                (model.qualitativeState?.memos ?? []).filter {
                    switch $0.target {
                    case .coding: false
                    case .source, .category: true
                    }
                }, id: \.eventID
            ) { note in
                VStack(alignment: .leading) {
                    switch note.target {
                    case let .source(sourceRevisionID):
                        Text(sourceRevisionID).font(.caption.monospaced())
                    case let .category(codebookID, categoryID):
                        Text(verbatim: "\(codebookID) / \(categoryID)").font(.caption)
                    case .coding: EmptyView()
                    }
                    Label(note.text, systemImage: "note.text")
                    Text(note.coderID).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
