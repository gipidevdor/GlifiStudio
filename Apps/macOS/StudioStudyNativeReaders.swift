// SPDX-License-Identifier: BSD-3-Clause

import AppKit
import PDFKit
import SwiftUI

/// Native selection is read-only; the Kit remains the authority for resolving the passage.
struct StudioStudyTextReader: NSViewRepresentable {
    @ScaledMetric(relativeTo: .body) private var textSize = NSFont.preferredFont(
        forTextStyle: .body
    ).pointSize
    let reading: StudioStudyReading
    let accessibilityTitle: String
    let onSelection: (NSRange) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelection: onSelection) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        guard let text = scroll.documentView as? NSTextView else { return scroll }
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = false
        text.allowsUndo = false
        text.usesFindBar = true
        text.font = .preferredFont(forTextStyle: .body)
        text.textColor = .labelColor
        text.backgroundColor = .textBackgroundColor
        text.textContainerInset = NSSize(width: 20, height: 20)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.delegate = context.coordinator
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? NSTextView else { return }
        context.coordinator.onSelection = onSelection
        text.setAccessibilityLabel(accessibilityTitle)
        let font = NSFont.systemFont(ofSize: textSize)
        if text.font != font { text.font = font }
        guard context.coordinator.navigationID != reading.navigationID else { return }
        context.coordinator.isUpdating = true
        text.string = reading.text
        context.coordinator.navigationID = reading.navigationID
        if let range = reading.highlight, NSMaxRange(range) <= (reading.text as NSString).length {
            text.setSelectedRange(range)
            text.scrollRangeToVisible(range)
        } else {
            text.setSelectedRange(NSRange(location: 0, length: 0))
            text.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        context.coordinator.isUpdating = false
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        (scroll.documentView as? NSTextView)?.delegate = nil
        scroll.documentView = nil
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var onSelection: (NSRange) -> Void
        var navigationID: UUID?
        var isUpdating = false

        init(onSelection: @escaping (NSRange) -> Void) { self.onSelection = onSelection }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating, let text = notification.object as? NSTextView else { return }
            onSelection(text.selectedRange())
        }
    }
}

/// Displays the verified archived PDF.
///
/// A page jump never invents text geometry.
struct StudioStudyPDFReader: NSViewRepresentable {
    let document: PDFDocument
    let pageNumber: Int?
    let navigationID: UUID
    let accessibilityTitle: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        view.setAccessibilityLabel(accessibilityTitle)
        if view.document !== document { view.document = document }
        guard context.coordinator.navigationID != navigationID else { return }
        context.coordinator.navigationID = navigationID
        if let pageNumber, pageNumber > 0, pageNumber <= document.pageCount,
            let page = document.page(at: pageNumber - 1)
        {
            view.go(to: page)
        }
    }

    static func dismantleNSView(_ view: PDFView, coordinator: Coordinator) {
        view.document = nil
    }

    @MainActor final class Coordinator {
        var navigationID: UUID?
    }
}
