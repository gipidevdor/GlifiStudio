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

    @Environment(\.locale) private var locale
    private var labels: StudioVisualizationLabels { StudioVisualizationLabels(locale: locale) }

    private static let palette: [Color] = [
        .blue, .orange, .teal, .purple, .pink, .brown, .indigo, .mint, .red, .cyan,
    ]
    private static let shapes = ["circle", "square", "triangle", "diamond", "hexagon"]

    @State private var exportDocument: StudioTextExportDocument?
    @State private var folderDocument: StudioFolderExportDocument?
    @State private var isPreparingExport = false
    @State private var exportFailed = false
    @State private var preparationTask: Task<Void, Never>?
    @State private var preparationID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(labels.summary(visualization))
                .font(.callout)
                .accessibilityAddTraits(.isSummaryElement)
            if !visualization.marks.isEmpty {
                let series = StudioPlotSeries(visualization.marks)
                chart(series)
                    .frame(minHeight: 240, idealHeight: 320, maxHeight: 420)
                legend(series)
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
                    prepareExport(.csv)
                }
                Button("action.export-view-json", systemImage: "curlybraces") {
                    prepareExport(.json)
                }
                if let projectID, let generation {
                    Button("action.export-view-provenance", systemImage: "folder.badge.gearshape") {
                        prepareExport(.provenance(projectID: projectID, generation: generation))
                    }
                }
            }
            .disabled(isPreparingExport)
            if isPreparingExport { ProgressView("visual.export.preparing") }
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: exportDocument?.contentType ?? .commaSeparatedText,
            defaultFilename: exportFileName
        ) { result in
            reportExportFailure(result)
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
        ) { result in
            reportExportFailure(result)
            folderDocument = nil
        }
        .alert("visual.export.failed", isPresented: $exportFailed) {
            Button("common.ok", role: .cancel) {}
        }
        .onDisappear {
            preparationID = UUID()
            preparationTask?.cancel()
            preparationTask = nil
            isPreparingExport = false
        }
    }

    private var exportFileName: String {
        visualization.specificationIdentifier.replacingOccurrences(of: ".", with: "-")
    }

    private func reportExportFailure(_ result: Result<URL, any Error>) {
        if case let .failure(error) = result, (error as? CocoaError)?.code != .userCancelled {
            exportFailed = true
        }
    }

    private func prepareExport(_ kind: StudioVisualExportKind) {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        let identifier = UUID()
        preparationID = identifier
        preparationTask = Task {
            defer {
                if preparationID == identifier {
                    isPreparingExport = false
                    preparationTask = nil
                }
            }
            do {
                let value = try await StudioVisualExportPreparation.prepare(
                    visualization, kind: kind)
                guard !Task.isCancelled, preparationID == identifier else { return }
                switch value {
                case let .text(text, isJSON):
                    exportDocument = StudioTextExportDocument(
                        text: text, contentType: isJSON ? .json : .commaSeparatedText)
                case let .files(files):
                    folderDocument = StudioFolderExportDocument(files: files)
                }
            } catch is CancellationError {
                return
            } catch {
                if preparationID == identifier { exportFailed = true }
            }
        }
    }

    // MARK: - Chart

    private func chart(_ series: StudioPlotSeries) -> some View {
        GeometryReader { geometry in
            let frame = PlotFrame(visualization: visualization, size: geometry.size)
            let plot = Canvas { context, _ in
                draw(in: &context, frame: frame, series: series)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(LocalizedStringKey(visualization.titleKey))
            .accessibilityValue(labels.summary(visualization))
            .accessibilityChildren {
                ForEach(series.points) { mark in
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
                if let mark = frame.nearestPoint(to: location, among: series.points) {
                    onSelect(mark)
                }
            }
            if let audioGraph = StudioFactorAudioGraph(visualization, labels: labels) {
                plot.accessibilityChartDescriptor(audioGraph)
            } else {
                plot
            }
        }
    }

    private func draw(in context: inout GraphicsContext, frame: PlotFrame, series: StudioPlotSeries)
    {
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
                if mark.id == selectedMarkID {
                    context.stroke(path, with: .color(.primary), lineWidth: 2.5)
                }
            case .point:
                let center = frame.point(x: mark.x, y: mark.y)
                let seriesIndex = series.styleIndex(for: mark.series) ?? 0
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

    private func legend(_ series: StudioPlotSeries) -> some View {
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { legendItems(series) }
            VStack(alignment: .leading, spacing: 4) { legendItems(series) }
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("visual.legend")
        .accessibilityValue(
            series.pointSeries.map(labels.seriesName).formatted(.list(type: .and).locale(locale)))
    }

    private func legendItems(_ series: StudioPlotSeries) -> some View {
        ForEach(series.pointSeries, id: \.self) { name in
            let index = series.styleIndex(for: name) ?? 0
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
                Text(labels.seriesName(name))
            }
        }
    }

    // MARK: - Metadata

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(visualization.axes.enumerated()), id: \.offset) { _, axis in
                LabeledContent {
                    Text(
                        "\(labels.format(axis.lowerBound)) – \(labels.format(axis.upperBound))"
                    )
                    .font(.caption.monospacedDigit())
                } label: {
                    Text(labels.axisTitle(axis))
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
        let selections = visualization.tableSelectionMarks
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
                    tableRow(row, columns: columns, mark: selections[row.id])
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 280)
        .accessibilityLabel("visual.table")
    }

    @ViewBuilder private func tableRow(
        _ row: GlifiStudioVisualRow, columns: [GlifiStudioVisualColumn],
        mark: GlifiStudioVisualMark?
    ) -> some View {
        let selected = mark != nil && mark?.id == selectedMarkID
        let content = GridRow {
            ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                cellText(
                    cell,
                    columnID: columns.indices.contains(index)
                        ? columns[index].identifier : nil
                )
                .frame(minHeight: 44, alignment: .leading)
            }
        }
        .font(.caption)
        .fontWeight(selected ? .semibold : .regular)
        .padding(.vertical, 1)
        .background(selected ? Color.accentColor.opacity(0.15) : .clear)
        .accessibilityElement(children: .combine)
        if let mark {
            content
                .contentShape(Rectangle())
                .onTapGesture { onSelect(mark) }
                .focusable()
                .onKeyPress(.return) {
                    onSelect(mark)
                    return .handled
                }
                .onKeyPress(.space) {
                    onSelect(mark)
                    return .handled
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityAction { onSelect(mark) }
                .accessibilityAction(named: "action.open-mark-source") { onSelect(mark) }
        } else {
            content
        }
    }

    @ViewBuilder
    private func cellText(_ cell: GlifiStudioVisualCell, columnID: String?) -> some View {
        switch cell {
        case let .text(value):
            Text(columnID == "series" ? labels.seriesName(value) : value).textSelection(.enabled)
        case let .integer(value):
            Text(value, format: .number).monospacedDigit()
        case let .decimal(value):
            Text(labels.format(value)).monospacedDigit()
        case .missing:
            Text("visual.cell.missing").foregroundStyle(.secondary)
        }
    }

    // MARK: - Text

    private func markDescription(_ mark: GlifiStudioVisualMark) -> String {
        var parts = [mark.label, labels.seriesName(mark.series)]
        if visualization.axes.count == 1 {
            parts.append(labels.format(mark.x))
        } else if visualization.axes.count == 2 {
            parts.append("\(labels.format(mark.x)), \(labels.format(mark.y))")
        }
        return parts.joined(separator: ", ")
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
