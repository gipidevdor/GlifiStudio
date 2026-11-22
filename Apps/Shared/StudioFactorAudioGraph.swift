// SPDX-License-Identifier: BSD-3-Clause

import Accessibility
import Foundation
import GlifiKit
import SwiftUI

/// The table, plot and VoiceOver use the same locale, axis titles and rounding.
nonisolated struct StudioVisualizationLabels {
    let locale: Locale
    var bundle: Bundle = .main

    func localized(_ key: String) -> String {
        bundle.localizedString(
            forKey: key, value: nil, table: nil, localizations: [locale.language])
    }

    func format(_ value: Double) -> String {
        value.formatted(.number.locale(locale).precision(.significantDigits(1...4)))
    }

    private func formatted(_ cell: GlifiStudioVisualCell) -> String {
        switch cell {
        case let .text(value): value
        case let .integer(value): value.formatted(.number.locale(locale))
        case let .decimal(value): format(value)
        case .missing: localized("visual.cell.missing")
        }
    }

    func summary(_ visualization: GlifiStudioVisualization) -> String {
        var text = localized(visualization.summaryKey)
        for argument in visualization.summaryArguments {
            let value: String
            if argument.name == "share", case let .decimal(share) = argument.value {
                value = share.formatted(.percent.locale(locale).precision(.fractionLength(1)))
            } else {
                value = formatted(argument.value)
            }
            text = text.replacingOccurrences(of: "{\(argument.name)}", with: value)
        }
        return text
    }

    func axisTitle(_ axis: GlifiStudioVisualAxis) -> String {
        var text = localized(axis.labelKey)
        text = text.replacingOccurrences(
            of: "{axis}", with: (axis.ordinal ?? 0).formatted(.number.locale(locale)))
        let share = axis.share.map {
            $0.formatted(.percent.locale(locale).precision(.fractionLength(1)))
        }
        return text.replacingOccurrences(of: "{share}", with: share ?? "—")
    }

    func seriesName(_ name: String) -> String {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2, let number = Int(parts[1]) {
            return localized("visual.series.\(parts[0])")
                .replacingOccurrences(of: "{n}", with: number.formatted(.number.locale(locale)))
        }
        return localized("visual.series.\(name)")
    }
}

/// Describes discrete observations along the measured axes of a factor plot.
nonisolated struct StudioFactorAudioGraph: AXChartDescriptorRepresentable {
    private let visualization: GlifiStudioVisualization
    private let labels: StudioVisualizationLabels
    private let horizontal: GlifiStudioVisualAxis
    private let vertical: GlifiStudioVisualAxis?

    init?(_ visualization: GlifiStudioVisualization, labels: StudioVisualizationLabels) {
        guard visualization.family == .factorPlot, !visualization.marks.isEmpty,
            (1...2).contains(visualization.axes.count), let horizontal = visualization.axes.first,
            visualization.axes.allSatisfy({
                $0.scaleIdentifier == "linear" && $0.lowerBound.isFinite && $0.upperBound.isFinite
                    && $0.lowerBound < $0.upperBound
            })
        else { return nil }
        self.visualization = visualization
        self.labels = labels
        self.horizontal = horizontal
        vertical = visualization.axes.dropFirst().first
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let groups = Dictionary(grouping: visualization.marks, by: \.series)
        var seen = Set<String>()
        let series = visualization.marks.compactMap { mark -> AXDataSeriesDescriptor? in
            guard seen.insert(mark.series).inserted, let group = groups[mark.series] else {
                return nil
            }
            return AXDataSeriesDescriptor(
                name: labels.seriesName(mark.series), isContinuous: false,
                dataPoints: group.map {
                    AXDataPoint(x: $0.x, y: vertical == nil ? nil : $0.y, label: $0.label)
                })
        }
        return AXChartDescriptor(
            title: labels.localized(visualization.titleKey), summary: labels.summary(visualization),
            xAxis: axis(horizontal), yAxis: vertical.map(axis), series: series)
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        let updated = makeChartDescriptor()
        descriptor.title = updated.title
        descriptor.summary = updated.summary
        descriptor.xAxis = updated.xAxis
        descriptor.yAxis = updated.yAxis
        descriptor.series = updated.series
    }

    private func axis(_ value: GlifiStudioVisualAxis) -> AXNumericDataAxisDescriptor {
        AXNumericDataAxisDescriptor(
            title: labels.axisTitle(value), range: value.lowerBound...value.upperBound,
            gridlinePositions: [], valueDescriptionProvider: labels.format)
    }
}
