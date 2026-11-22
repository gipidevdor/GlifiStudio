// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiKit
import SwiftUI
import UniformTypeIdentifiers

/// Renders one `GlifiStudioVisualization` as chart, legend, caveats and equivalent table.
///
/// The view draws only the positions, domains and marks declared by the specification
/// (GS-VIZ-001); it never recomputes values. Color is never the only channel: every
/// series also has its own shape, and every mark is reachable from the table and from
/// VoiceOver.
struct StudioVisualizationView: View {
    let visualization: GlifiStudioVisualization
    let selectedMarkID: String?
    /// Project lineage recorded in the provenance manifest.
    var projectID: String?
    var generation: Int?
    let onSelect: (GlifiStudioVisualMark) -> Void

    private static let palette: [Color] = [
        .blue, .orange, .teal, .purple, .pink, .brown, .indigo, .mint, .red, .cyan,
    ]
    private static let shapes = ["circle", "square", "triangle", "diamond", "hexagon"]

    @State private var exportDocument: StudioTextExportDocument?
    @State private var folderDocument: StudioFolderExportDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summaryText)
                .font(.callout)
                .accessibilityAddTraits(.isSummaryElement)
            if !visualization.marks.isEmpty {
                chart
                    .frame(minHeight: 240, idealHeight: 320, maxHeight: 420)
                legend
            }
            metadata
            if !visualization.caveatKeys.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(visualization.caveatKeys, id: \.self) { key in
                        Label(LocalizedStringKey(key), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                }
            }
            table
            Menu("action.export-view", systemImage: "square.and.arrow.up") {
                Button("action.export-view-csv", systemImage: "tablecells") {
                    exportDocument = StudioTextExportDocument(
                        text: GlifiStudioVisualizationBuilder.csv(visualization),
                        contentType: .commaSeparatedText
                    )
                }
                Button("action.export-view-json", systemImage: "curlybraces") {
                    exportDocument = specificationDocument
                }
                if let projectID, let generation {
                    Button("action.export-view-provenance", systemImage: "folder.badge.gearshape") {
                        folderDocument =
                            (try? GlifiStudioVisualExport.bundle(
                                visualization, projectID: projectID, generation: generation,
                                createdAt: Date()
                            )).map(StudioFolderExportDocument.init(files:))
                    }
                }
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: exportDocument?.contentType ?? .commaSeparatedText,
            defaultFilename: exportFileName
        ) { _ in
            exportDocument = nil
        }
        .fileExporter(
            isPresented: Binding(
                get: { folderDocument != nil },
                set: { if !$0 { folderDocument = nil } }
            ),
            document: folderDocument,
            contentType: .folder,
            defaultFilename: exportFileName
        ) { _ in
            folderDocument = nil
        }
    }

    private var exportFileName: String {
        visualization.specificationIdentifier.replacingOccurrences(of: ".", with: "-")
    }

    private var specificationDocument: StudioTextExportDocument? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(visualization) else {
            return nil
        }
        return StudioTextExportDocument(
            text: String(decoding: data, as: UTF8.self) + "\n", contentType: .json)
    }

    // MARK: - Chart

    private var pointMarks: [GlifiStudioVisualMark] {
        visualization.marks.filter { $0.kind == .point }
    }

    private var series: [String] {
        var seen: [String] = []
        for mark in visualization.marks where !seen.contains(mark.series) {
            seen.append(mark.series)
        }
        return seen
    }

    private var chart: some View {
        GeometryReader { geometry in
            let frame = PlotFrame(visualization: visualization, size: geometry.size)
            Canvas { context, _ in
                draw(in: &context, frame: frame)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(LocalizedStringKey(visualization.titleKey))
            .accessibilityValue(summaryText)
            .accessibilityChildren {
                ForEach(pointMarks) { mark in
                    Rectangle()
                        .accessibilityLabel(markDescription(mark))
                        .accessibilityAddTraits(
                            mark.id == selectedMarkID ? [.isButton, .isSelected] : .isButton
                        )
                        .accessibilityAction { onSelect(mark) }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                if let mark = frame.nearestPoint(to: location, among: pointMarks) {
                    onSelect(mark)
                }
            }
        }
    }

    private func draw(in context: inout GraphicsContext, frame: PlotFrame) {
        if visualization.family == .factorPlot, visualization.axes.count == 2 {
            var origin = Path()
            origin.move(to: frame.point(x: 0, y: frame.yDomain.lowerBound))
            origin.addLine(to: frame.point(x: 0, y: frame.yDomain.upperBound))
            origin.move(to: frame.point(x: frame.xDomain.lowerBound, y: 0))
            origin.addLine(to: frame.point(x: frame.xDomain.upperBound, y: 0))
            context.stroke(origin, with: .color(.secondary.opacity(0.4)), lineWidth: 0.5)
        }
        for mark in visualization.marks {
            switch mark.kind {
            case .segment, .rule:
                var path = Path()
                path.move(to: frame.point(x: mark.x, y: mark.y))
                path.addLine(to: frame.point(x: mark.x2 ?? mark.x, y: mark.y2 ?? mark.y))
                let style =
                    mark.kind == .rule
                    ? StrokeStyle(lineWidth: 1, dash: [5, 3])
                    : StrokeStyle(lineWidth: visualization.family == .network ? 0.6 : 1.2)
                context.stroke(
                    path,
                    with: .color(mark.kind == .rule ? .red : .secondary.opacity(0.7)),
                    style: style
                )
            case .point:
                let center = frame.point(x: mark.x, y: mark.y)
                let seriesIndex = series.firstIndex(of: mark.series) ?? 0
                let color = Self.palette[seriesIndex % Self.palette.count]
                let symbol = Self.shape(seriesIndex, center: center, radius: 4.5)
                context.fill(symbol, with: .color(color))
                if mark.id == selectedMarkID {
                    context.stroke(
                        Path(
                            ellipseIn: CGRect(
                                x: center.x - 8, y: center.y - 8, width: 16, height: 16)),
                        with: .color(.primary),
                        lineWidth: 1.5
                    )
                }
                if mark.isEmphasized || mark.id == selectedMarkID {
                    context.draw(
                        Text(mark.label).font(.caption2),
                        at: CGPoint(x: center.x + 6, y: center.y - 6),
                        anchor: .bottomLeading
                    )
                }
            }
        }
    }

    private static func shape(_ index: Int, center: CGPoint, radius: CGFloat) -> Path {
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        switch index % shapes.count {
        case 0: return Path(ellipseIn: rect)
        case 1: return Path(rect.insetBy(dx: 0.5, dy: 0.5))
        default:
            let sides = [3, 4, 6][index % shapes.count - 2]
            let rotation = sides == 4 ? 0 : -Double.pi / 2
            var path = Path()
            for vertex in 0..<sides {
                let angle = rotation + 2 * Double.pi * Double(vertex) / Double(sides)
                let point = CGPoint(
                    x: center.x + radius * CGFloat(cos(angle)),
                    y: center.y + radius * CGFloat(sin(angle))
                )
                if vertex == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        }
    }

    private var legend: some View {
        let pointSeries = series.filter { name in pointMarks.contains { $0.series == name } }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { legendItems(pointSeries) }
            VStack(alignment: .leading, spacing: 4) { legendItems(pointSeries) }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("visual.legend")
    }

    private func legendItems(_ names: [String]) -> some View {
        ForEach(names, id: \.self) { name in
            let index = series.firstIndex(of: name) ?? 0
            HStack(spacing: 4) {
                Canvas { context, size in
                    context.fill(
                        Self.shape(
                            index, center: CGPoint(x: size.width / 2, y: size.height / 2),
                            radius: 4.5),
                        with: .color(Self.palette[index % Self.palette.count])
                    )
                }
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
                Text(seriesName(name))
            }
        }
    }

    // MARK: - Metadata

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(visualization.axes.enumerated()), id: \.offset) { _, axis in
                LabeledContent {
                    Text(
                        "\(format(axis.lowerBound)) – \(format(axis.upperBound))"
                    )
                    .font(.caption.monospacedDigit())
                } label: {
                    Text(axisTitle(axis))
                }
            }
            LabeledContent("visual.observations") {
                Text(
                    "\(visualization.visibleObservationCount.formatted()) / "
                        + visualization.totalObservationCount.formatted()
                )
                .monospacedDigit()
            }
            DisclosureGroup("visual.method") {
                LabeledContent("visual.method") {
                    Text(visualization.methodIdentifier)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                if let layout = visualization.layoutIdentifier {
                    LabeledContent("visual.layout") {
                        Text(layout).font(.caption2.monospaced())
                    }
                }
                if let reduction = visualization.reductionIdentifier {
                    LabeledContent("visual.reduction") {
                        Text(reduction).font(.caption2.monospaced())
                    }
                }
            }
            if !visualization.excludedLabels.isEmpty {
                LabeledContent("visual.excluded") {
                    Text(visualization.excludedLabels.joined(separator: ", "))
                        .font(.caption2)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
        .font(.caption)
    }

    // MARK: - Equivalent table

    private var table: some View {
        let columns = visualization.table.columns
        let marksByID = Dictionary(
            visualization.marks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    ForEach(columns, id: \.identifier) { column in
                        Text(LocalizedStringKey(column.labelKey))
                            .font(.caption.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                Divider()
                ForEach(visualization.table.rows) { row in
                    GridRow {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            cellText(cell)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                    .font(.caption)
                    .fontWeight(row.id == selectedMarkID ? .semibold : .regular)
                    .padding(.vertical, 1)
                    .background(row.id == selectedMarkID ? Color.accentColor.opacity(0.15) : .clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let mark = marksByID[row.id] { onSelect(mark) }
                    }
                    .focusable(marksByID[row.id] != nil)
                    .onKeyPress(.return) {
                        guard let mark = marksByID[row.id] else { return .ignored }
                        onSelect(mark)
                        return .handled
                    }
                    .onKeyPress(.space) {
                        guard let mark = marksByID[row.id] else { return .ignored }
                        onSelect(mark)
                        return .handled
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(marksByID[row.id] != nil ? .isButton : [])
                    .accessibilityAddTraits(row.id == selectedMarkID ? .isSelected : [])
                    .accessibilityAction(named: "action.open-mark-source") {
                        if let mark = marksByID[row.id] { onSelect(mark) }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 280)
        .accessibilityLabel("visual.table")
    }

    @ViewBuilder
    private func cellText(_ cell: GlifiStudioVisualCell) -> some View {
        switch cell {
        case let .text(value):
            Text(value).textSelection(.enabled)
        case let .integer(value):
            Text(value, format: .number).monospacedDigit()
        case let .decimal(value):
            Text(format(value)).monospacedDigit()
        case .missing:
            Text("visual.cell.missing").foregroundStyle(.secondary)
        }
    }

    // MARK: - Text

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.significantDigits(1...4)))
    }

    private func formatted(_ cell: GlifiStudioVisualCell) -> String {
        switch cell {
        case let .text(value): value
        case let .integer(value): value.formatted()
        case let .decimal(value): format(value)
        case .missing: String(localized: "visual.cell.missing")
        }
    }

    private var summaryText: String {
        var text = Self.localized(visualization.summaryKey)
        for argument in visualization.summaryArguments {
            let value: String
            if argument.name == "share", case let .decimal(share) = argument.value {
                value = share.formatted(.percent.precision(.fractionLength(1)))
            } else {
                value = formatted(argument.value)
            }
            text = text.replacingOccurrences(of: "{\(argument.name)}", with: value)
        }
        return text
    }

    private func axisTitle(_ axis: GlifiStudioVisualAxis) -> String {
        var text = Self.localized(axis.labelKey)
        text = text.replacingOccurrences(of: "{axis}", with: (axis.ordinal ?? 0).formatted())
        let share = axis.share.map { $0.formatted(.percent.precision(.fractionLength(1))) }
        return text.replacingOccurrences(of: "{share}", with: share ?? "—")
    }

    private func seriesName(_ name: String) -> String {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2, let number = Int(parts[1]) {
            return Self.localized("visual.series.\(parts[0])")
                .replacingOccurrences(of: "{n}", with: number.formatted())
        }
        return Self.localized("visual.series.\(name)")
    }

    private func markDescription(_ mark: GlifiStudioVisualMark) -> String {
        var parts = [mark.label, seriesName(mark.series)]
        if visualization.axes.count == 2 {
            parts.append("\(format(mark.x)), \(format(mark.y))")
        }
        return parts.joined(separator: ", ")
    }

    private static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

/// Maps data coordinates to view coordinates without clipping the declared domain.
private struct PlotFrame {
    let xDomain: ClosedRange<Double>
    let yDomain: ClosedRange<Double>
    let origin: CGPoint
    let xScale: Double
    let yScale: Double

    init(visualization: GlifiStudioVisualization, size: CGSize) {
        let points = visualization.marks.flatMap { mark in
            [(mark.x, mark.y)] + (mark.x2.map { [($0, mark.y2 ?? mark.y)] } ?? [])
        }
        func domain(_ axis: Int, _ values: [Double]) -> ClosedRange<Double> {
            if visualization.axes.indices.contains(axis) {
                let declared = visualization.axes[axis]
                return declared.lowerBound...declared.upperBound
            }
            return (values.min() ?? -1)...(values.max() ?? 1)
        }
        var x = domain(0, points.map(\.0))
        var y = domain(1, points.map(\.1))
        if visualization.axes.count == 1 {
            y = -1...1
        }
        // Dominio degenere: un intervallo unitario centrato evita divisioni per zero.
        if x.upperBound - x.lowerBound <= 0 { x = (x.lowerBound - 0.5)...(x.upperBound + 0.5) }
        if y.upperBound - y.lowerBound <= 0 { y = (y.lowerBound - 0.5)...(y.upperBound + 0.5) }
        let inset = 28.0
        let width = max(Double(size.width) - 2 * inset, 1)
        let height = max(Double(size.height) - 2 * inset, 1)
        var xScale = width / (x.upperBound - x.lowerBound)
        var yScale = height / (y.upperBound - y.lowerBound)
        if visualization.requiresEqualAspect {
            let common = min(xScale, yScale)
            xScale = common
            yScale = common
        }
        let usedWidth = xScale * (x.upperBound - x.lowerBound)
        let usedHeight = yScale * (y.upperBound - y.lowerBound)
        xDomain = x
        yDomain = y
        origin = CGPoint(
            x: inset + (width - usedWidth) / 2,
            y: inset + (height - usedHeight) / 2 + usedHeight
        )
        self.xScale = xScale
        self.yScale = yScale
    }

    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: origin.x + (x - xDomain.lowerBound) * xScale,
            y: origin.y - (y - yDomain.lowerBound) * yScale
        )
    }

    func nearestPoint(
        to location: CGPoint, among marks: [GlifiStudioVisualMark]
    ) -> GlifiStudioVisualMark? {
        let candidates = marks.map { mark -> (GlifiStudioVisualMark, Double) in
            let p = point(x: mark.x, y: mark.y)
            let dx = Double(p.x - location.x)
            let dy = Double(p.y - location.y)
            return (mark, dx * dx + dy * dy)
        }
        guard let best = candidates.min(by: { $0.1 < $1.1 }), best.1 <= 144 else {
            return nil
        }
        return best.0
    }
}

/// UTF-8 text written by the export panel: CSV of the equivalent table or JSON specification.
struct StudioTextExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText, .json]

    let text: String
    let contentType: UTType

    init(text: String, contentType: UTType) {
        self.text = text
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
        contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Folder of a view export with its provenance manifest.
struct StudioFolderExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.folder]

    let files: [String: Data]

    init(files: [String: Data]) {
        self.files = files
    }

    init(configuration: ReadConfiguration) throws {
        files = (configuration.file.fileWrappers ?? [:]).compactMapValues(\.regularFileContents)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(
            directoryWithFileWrappers: files.mapValues {
                FileWrapper(regularFileWithContents: $0)
            })
    }
}
