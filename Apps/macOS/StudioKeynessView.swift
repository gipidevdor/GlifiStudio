// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI

/// Native comparison sections embedded in the investigation's existing form.
struct StudioKeynessView: View {
    @Bindable var model: StudioHomeModel
    @Environment(\.locale) private var locale
    @State private var requestedPage = 1

    var body: some View {
        Group {
            if let snapshot = model.snapshot, model.selectedIntent.usesComparisonGroups {
                groupsSection(snapshot.sources)
                parametersSection
            }
            if let comparison = model.lastKeyness {
                resultSection(comparison)
                termsSection
                methodSection(comparison)
            }
        }
    }

    private func groupsSection(_ sources: [GlifiStudioProjectSource]) -> some View {
        Section("investigation.compare-groups") {
            Text("keyness.mac.introduction")
                .foregroundStyle(.secondary)
            Text("keyness.mac.groups.help").font(.caption).foregroundStyle(.secondary)
            LabeledContent("keyness.mac.groups.target-count") {
                Text(model.selectedTargetRevisionIDs.count, format: .number)
            }
            LabeledContent("keyness.mac.groups.reference-count") {
                Text(model.selectedReferenceRevisionIDs.count, format: .number)
            }
            if sources.isEmpty {
                Label("keyness.mac.groups.empty", systemImage: "doc.text")
            }
            ForEach(Array(sources.enumerated()), id: \.element.sourceRevisionID) { index, source in
                VStack(alignment: .leading, spacing: 8) {
                    sourceName(index: index, revisionID: source.sourceRevisionID)
                    HStack {
                        Text(source.format == .markdown ? "format.markdown" : "format.plain-text")
                        Text(Int64(source.byteCount), format: .byteCount(style: .file))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    ViewThatFits(in: .horizontal) {
                        HStack { groupActions(for: source.sourceRevisionID, sourceIndex: index) }
                        VStack(alignment: .leading) {
                            groupActions(for: source.sourceRevisionID, sourceIndex: index)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .padding(.vertical, 4)
            }
        }
        .disabled(model.isBusy)
    }

    @ViewBuilder private func groupActions(for revisionID: String, sourceIndex: Int) -> some View {
        Button {
            model.toggleTarget(revisionID)
        } label: {
            Label(
                "group.target",
                systemImage: model.selectedTargetRevisionIDs.contains(revisionID)
                    ? "checkmark.circle.fill" : "circle")
        }
        .accessibilityLabel(
            groupAccessibilityLabel("keyness.mac.group-action.target", sourceIndex: sourceIndex)
        )
        .accessibilityValue(
            Text(model.selectedTargetRevisionIDs.contains(revisionID) ? "common.yes" : "common.no"))
        Button {
            model.toggleReference(revisionID)
        } label: {
            Label(
                "group.reference",
                systemImage: model.selectedReferenceRevisionIDs.contains(revisionID)
                    ? "checkmark.circle.fill" : "circle")
        }
        .accessibilityLabel(
            groupAccessibilityLabel("keyness.mac.group-action.reference", sourceIndex: sourceIndex)
        )
        .accessibilityValue(
            Text(
                model.selectedReferenceRevisionIDs.contains(revisionID) ? "common.yes" : "common.no"
            ))
    }

    private func groupAccessibilityLabel(_ key: String, sourceIndex: Int) -> Text {
        let template = String(localized: String.LocalizationValue(key), locale: locale)
        let number = (sourceIndex + 1).formatted(.number.locale(locale))
        return Text(verbatim: template.replacingOccurrences(of: "{source}", with: number))
    }

    private var parametersSection: some View {
        Section("keyness.mac.parameters") {
            integerField(
                "keyness.options.max-hypotheses", value: $model.keynessMaximumHypothesisCount)
            decimalField(
                "keyness.options.low-expected-threshold",
                value: $model.keynessLowExpectedCountThreshold)
            decimalField("keyness.mac.confidence", value: $model.keynessConfidenceLevel)
            Text("keyness.mac.parameters.help").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("keyness.mac.parameters.details") {
                Text("keyness.mac.family.help")
                Text("keyness.mac.selection.help")
                Text("keyness.mac.confidence.help")
            }
            Button("keyness.mac.action.run", systemImage: "arrow.left.arrow.right") {
                Task { await model.compareKeynessNow() }
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(
                model.selectedTargetRevisionIDs.isEmpty
                    || model.selectedReferenceRevisionIDs.isEmpty)
        }
        .disabled(model.isBusy)
    }

    private func resultSection(_ comparison: GlifiStudioKeynessResult) -> some View {
        Section("keyness.title") {
            Text("keyness.mac.result.context").font(.caption).foregroundStyle(.secondary)
            LabeledContent("keyness.target-tokens") {
                Text(comparison.targetTokenCount, format: .number)
            }
            LabeledContent("keyness.reference-tokens") {
                Text(comparison.referenceTokenCount, format: .number)
            }
            LabeledContent("keyness.term-count") { Text(comparison.terms.count, format: .number) }
            LabeledContent("keyness.mac.confidence.effective") {
                if comparison.confidenceLevel < 1e-6 {
                    Text(
                        comparison.confidenceLevel,
                        format: .percent.notation(.scientific).precision(.significantDigits(1...17))
                    )
                } else {
                    Text(
                        comparison.confidenceLevel,
                        format: .percent.precision(.significantDigits(1...17)))
                }
            }
            DisclosureGroup("keyness.mac.groups.effective") {
                Text("keyness.mac.groups.effective-help").font(.caption).foregroundStyle(.secondary)
                effectiveGroup("group.target", ids: comparison.targetSourceRevisionIDs)
                effectiveGroup("group.reference", ids: comparison.referenceSourceRevisionIDs)
            }
            Text("keyness.mac.interpretation.help").font(.callout)
        }
    }

    private var termsSection: some View {
        Section("keyness.mac.terms.title") {
            Text("keyness.mac.terms.help").font(.caption).foregroundStyle(.secondary)
            pagination
            ForEach(model.keynessTermsOnPage) { term in
                termRow(term)
            }
        }
    }

    private func termRow(_ term: GlifiStudioKeynessTerm) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(term.term).font(.headline).textSelection(.enabled)
            LabeledContent("keyness.direction") {
                Text(directionKey(term.direction))
            }
            valueRow("keyness.log2-ratio", term.log2RatioHaldaneAnscombe)
            intervalRow(
                "keyness.mac.log-ratio.interval", lower: term.log2RatioLower,
                upper: term.log2RatioUpper)
            DisclosureGroup("keyness.mac.term.details") {
                LabeledContent("keyness.target-frequency") {
                    Text(term.targetFrequency, format: .number)
                }
                LabeledContent("keyness.reference-frequency") {
                    Text(term.referenceFrequency, format: .number)
                }
                valueRow("keyness.target-relative", term.targetRelativeFrequency)
                valueRow("keyness.reference-relative", term.referenceRelativeFrequency)
                valueRow("keyness.g-statistic", term.gStatistic)
                LabeledContent("keyness.df") { Text(term.degreesOfFreedom, format: .number) }
                identifierRow("keyness.mac.test.selected", term.selectedTestIdentifier)
                valueRow("keyness.mac.p-value.selected", term.pValue)
                valueRow("keyness.mac.p-value.g-test", term.gTestPValue)
                valueRow("keyness.q-value", term.qValue)
                valueRow("keyness.odds-ratio", term.oddsRatioHaldaneAnscombe)
                intervalRow(
                    "keyness.mac.odds-ratio.interval", lower: term.oddsRatioLower,
                    upper: term.oddsRatioUpper)
                valueRow("keyness.min-expected", term.minimumExpectedCount)
                LabeledContent("keyness.low-expected") {
                    Text(term.hasLowExpectedCount ? "common.yes" : "common.no")
                }
                if term.hasLowExpectedCount {
                    Label("keyness.mac.diagnostic.help", systemImage: "info.circle")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private var pagination: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("frequency.page") {
                Text("\(model.keynessPage + 1) / \(model.keynessPageCount)")
            }
            LabeledContent("frequency.visible-rows") {
                Text(model.keynessTermsOnPage.count, format: .number)
            }
            Text("keyness.mac.page.help").font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { pageButtons }
                VStack(alignment: .leading) { pageButtons }
            }
            LabeledContent("weighting.page.direct") {
                TextField("weighting.page.direct", value: $requestedPage, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onSubmit { selectRequestedPage() }
                Button("weighting.page.go") { selectRequestedPage() }
                    .disabled(requestedPage < 1 || requestedPage > model.keynessPageCount)
            }
        }
        .disabled(model.isBusy)
        .onAppear { requestedPage = model.keynessPage + 1 }
        .onChange(of: model.keynessPage) { _, page in requestedPage = page + 1 }
        .onChange(of: model.keynessPageCount) { _, _ in requestedPage = model.keynessPage + 1 }
    }

    @ViewBuilder private var pageButtons: some View {
        Button("frequency.page.previous", systemImage: "chevron.backward") {
            model.showKeynessPage(model.keynessPage - 1)
        }
        .disabled(model.keynessPage == 0)
        Button("frequency.page.next", systemImage: "chevron.forward") {
            model.showKeynessPage(model.keynessPage + 1)
        }
        .disabled(model.keynessPage + 1 >= model.keynessPageCount)
        Button("weighting.page.last", systemImage: "chevron.forward.to.line") {
            model.showKeynessPage(model.keynessPageCount - 1)
        }
        .disabled(model.keynessPage + 1 >= model.keynessPageCount)
    }

    private func selectRequestedPage() {
        guard requestedPage >= 1, requestedPage <= model.keynessPageCount else { return }
        model.showKeynessPage(requestedPage - 1)
    }

    private func methodSection(_ comparison: GlifiStudioKeynessResult) -> some View {
        Section {
            DisclosureGroup("summary.result.method-lineage") {
                Text("keyness.mac.method.help")
                Text("keyness.mac.selection.help")
                Text("keyness.mac.confidence.help")
                identifierRow("keyness.comparison-id", comparison.comparisonIdentifier)
                identifierRow("keyness.test-id", comparison.testIdentifier)
                identifierRow("keyness.mac.test.selection", comparison.testSelectionIdentifier)
                identifierRow("keyness.mac.test.exact", comparison.exactTestIdentifier)
                identifierRow("keyness.pvalue-id", comparison.pValueIdentifier)
                identifierRow("keyness.correction-id", comparison.correctionIdentifier)
                identifierRow("keyness.log-ratio-id", comparison.logRatioIdentifier)
                identifierRow(
                    "keyness.mac.log-ratio.interval-method", comparison.logRatioIntervalIdentifier)
                identifierRow("keyness.odds-ratio-id", comparison.oddsRatioIdentifier)
                identifierRow(
                    "keyness.mac.odds-ratio.interval-method", comparison.oddsRatioIntervalIdentifier
                )
                identifierRow("keyness.diagnostic-id", comparison.diagnosticIdentifier)
                valueRow("keyness.low-expected-threshold", comparison.lowExpectedCountThreshold)
                identifierRow("keyness.ordering-id", comparison.orderingIdentifier)
                identifierRow("keyness.fp-determinism", comparison.floatingPointDeterminismClass)
                identifierRow("keyness.numeric-policy", comparison.numericPolicyIdentifier)
                valueRow("keyness.tolerance", comparison.referenceAbsoluteTolerance)
                if let options = model.lastKeynessRequestOptions {
                    LabeledContent("keyness.options.max-hypotheses") {
                        Text(options.keynessOptions.maximumHypothesisCount, format: .number)
                    }
                    LabeledContent("keyness.mac.limits.sources") {
                        Text(options.corpusOptions.maximumDocumentCount, format: .number)
                    }
                    LabeledContent("keyness.mac.limits.bytes") {
                        Text(options.corpusOptions.maximumSourceByteCount, format: .number)
                    }
                    LabeledContent("weighting.limits.terms") {
                        Text(options.corpusOptions.maximumVocabularySize, format: .number)
                    }
                    LabeledContent("weighting.limits.cells") {
                        Text(options.corpusOptions.maximumNonZeroCellCount, format: .number)
                    }
                }
                identifierRow("keyness.project-id", comparison.projectID)
                LabeledContent("keyness.source-generation") {
                    Text(comparison.sourceGeneration, format: .number)
                }
                LabeledContent("keyness.generation") {
                    Text(comparison.generation, format: .number)
                }
                identifierRow("keyness.artifact", comparison.artifactID)
                identifierRow("keyness.analysis-node", comparison.analysisNodeID)
                identifierRow("keyness.comparison-digest", comparison.comparisonDigest)
                identifierRow("keyness.target-digest", comparison.targetCorpusDigest)
                identifierRow("keyness.reference-digest", comparison.referenceCorpusDigest)
            }
        }
    }

    private func effectiveGroup(_ title: LocalizedStringKey, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(ids, id: \.self) { sourceName(revisionID: $0) }
        }
    }

    private func sourceName(revisionID: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let index = model.snapshot?.sources.firstIndex(where: {
                $0.sourceRevisionID == revisionID
            }) {
                sourceName(index: index, revisionID: revisionID)
            } else {
                Text("summary.source.label")
                Text(revisionID).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
    }

    private func sourceName(index: Int, revisionID: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("summary.source.label")
                Text(index + 1, format: .number)
            }
            Text(revisionID).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(
                .enabled)
        }
    }

    private func directionKey(_ direction: String) -> LocalizedStringKey {
        switch direction {
        case "target": "keyness.mac.direction.target"
        case "reference": "keyness.mac.direction.reference"
        case "equal": "keyness.mac.direction.equal"
        default: "keyness.mac.direction.unavailable"
        }
    }

    private func integerField(_ key: LocalizedStringKey, value: Binding<Int>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number)
                .multilineTextAlignment(.trailing).frame(maxWidth: 160)
        }
    }

    private func decimalField(_ key: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(key) {
            TextField(key, value: value, format: .number.precision(.significantDigits(1...17)))
                .multilineTextAlignment(.trailing).frame(maxWidth: 160)
        }
    }

    private func valueRow(_ key: LocalizedStringKey, _ value: Double) -> some View {
        LabeledContent(key) {
            Text(value, format: .number.notation(.scientific).precision(.significantDigits(1...17)))
                .textSelection(.enabled)
        }
    }

    private func intervalRow(_ key: LocalizedStringKey, lower: Double, upper: Double) -> some View {
        LabeledContent(key) {
            ViewThatFits(in: .horizontal) {
                HStack { intervalBounds(lower: lower, upper: upper) }
                VStack(alignment: .trailing) { intervalBounds(lower: lower, upper: upper) }
            }
        }
    }

    @ViewBuilder private func intervalBounds(lower: Double, upper: Double) -> some View {
        Text(lower, format: .number.notation(.scientific).precision(.significantDigits(1...17)))
        Text("keyness.mac.interval.to")
        Text(upper, format: .number.notation(.scientific).precision(.significantDigits(1...17)))
    }

    private func identifierRow(_ key: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(key) {
            Text(value).font(.caption.monospaced()).textSelection(.enabled)
        }
    }
}
