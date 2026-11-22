// SPDX-License-Identifier: BSD-3-Clause

import Accessibility
import Foundation
import GlifiKit
import Testing

struct StudioFactorAudioGraphTests {
    private let labels = StudioVisualizationLabels(locale: Locale(identifier: "it_IT"))

    private final class BundleAnchor {}

    @Test func chartUsesTheRequestedCatalogLanguageAndNumericRegion() throws {
        let bundle = Bundle(for: BundleAnchor.self)
        let plot = try specification()
        for (identifier, name, title, fraction) in [
            ("it_IT", "Documenti", "Asse 1", "1,5"),
            ("en_US", "Documents", "Axis 1", "1.5"),
        ] {
            let localized = StudioVisualizationLabels(
                locale: Locale(identifier: identifier), bundle: bundle)
            let graph = try #require(StudioFactorAudioGraph(plot, labels: localized))
            let descriptor = graph.makeChartDescriptor()
            let axis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
            #expect(descriptor.series.first?.name == name)
            #expect(axis.title.hasPrefix(title))
            #expect(axis.valueDescriptionProvider(1.5) == fraction)
        }
    }

    @Test func builtPlotsNameTheQuantityExplainedByTheirAxes() throws {
        let bundle = Bundle(for: BundleAnchor.self)
        for (method, italian, english) in [
            ("CA-SVD-v1", "inerzia totale", "total inertia"),
            ("PCA-SVD-v1", "varianza totale", "total variance"),
            ("LSA-SVD-v1", "quadrati dei valori singolari", "squared singular values"),
        ] {
            let json = """
                {"lineage":{"projectID":"p","sourceGeneration":0,"generation":1,"artifactID":"a","analysisNodeID":"n"},
                 "analysisIdentifier":"fixture","methodIdentifier":"\(method)","representationIdentifier":"fixture",
                 "sourceRevisionIDs":["doc"],"terms":["term"],"axisValues":[1],"axisShares":[0.25],
                 "rowCoordinates":[[-1]],"columnCoordinates":[[1]],"excludedSourceRevisionIDs":[],"excludedTerms":[]}
                """
            let result = try JSONDecoder().decode(
                GlifiStudioMultivariateResult.self, from: Data(json.utf8))
            let built = try GlifiStudioVisualizationBuilder.factorPlot(result)
            let plot = try #require(built)
            let lowShareKey = "caveat.visual.low-plotted-share"
            #expect(plot.caveatKeys.contains(lowShareKey))
            for (language, quantity, warning) in [
                (
                    "it", italian,
                    "La quota complessiva rappresentata dagli assi è inferiore al 50%."
                ),
                ("en", english, "The combined share represented by the plotted axes is below 50%."),
            ] {
                let labels = StudioVisualizationLabels(
                    locale: Locale(identifier: language), bundle: bundle)
                let graph = try #require(StudioFactorAudioGraph(plot, labels: labels))
                let summary = try #require(graph.makeChartDescriptor().summary)
                #expect(summary.contains(quantity))
                #expect(summary.contains("25"))
                #expect(!summary.contains("{"))
                #expect(labels.localized(lowShareKey) == warning)
            }
        }
    }

    @Test func preservesValuesSeriesAndDeclaredAxesWhenThePlotChanges() throws {
        let plot = try specification()
        let representation = try #require(StudioFactorAudioGraph(plot, labels: labels))
        let descriptor = representation.makeChartDescriptor()
        #expect(descriptor.series.map(\.isContinuous) == [false, false])
        #expect(descriptor.series.map { $0.dataPoints.map(\.label) } == [["A", "B"], ["porto"]])
        #expect(descriptor.series.map(\.name) == ["documents", "terms"].map(labels.seriesName))
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.range == -3...2)
        #expect(xAxis.valueDescriptionProvider(1.5) == "1,5")
        #expect(descriptor.yAxis?.range == -1...4)
        let point = try #require(descriptor.series.first?.dataPoints.first)
        #expect(point.xValue.__number == -2)
        #expect(point.yValue?.__number == 0)

        let singleAxis = try specification(axisCount: 1)
        let updated = try #require(StudioFactorAudioGraph(singleAxis, labels: labels))
        updated.updateChartDescriptor(descriptor)
        #expect(descriptor.yAxis == nil)
        #expect(descriptor.series.flatMap(\.dataPoints).allSatisfy { $0.yValue == nil })
    }

    @Test func plotAndLegendPreserveFirstSeenStylesIncludingNonPointMarks() throws {
        let points = try specification().marks
        let segment = try JSONDecoder().decode(
            GlifiStudioVisualMark.self,
            from: Data(point("edge", series: "edges", x: 0, y: 0, kind: "segment").utf8))
        let index = StudioPlotSeries([segment] + points)
        #expect(index.points == points)
        #expect(index.pointSeries == ["documents", "terms"])
        #expect(index.styleIndex(for: "edges") == 0)
        #expect(index.styleIndex(for: "documents") == 1)
        #expect(index.styleIndex(for: "terms") == 2)
        #expect(index.styleIndex(for: "missing") == nil)
    }

    @Test func mergeRowsResolveToTheBridgeWithItsDescendants() throws {
        let bridge = point(
            "merge:1:bridge", series: "merges", x: 1, y: 2, kind: "segment",
            lineage: "contributive", sources: ["A", "B"])
        let marks = [bridge, point("leaf:A", series: "documents", x: 0, y: 0)]
        let rowIDs = ["merge:1", "merge:10", "leaf:A"]
        let tree = try specification(family: "dendrogram", marks: marks, rowIDs: rowIDs)
        let selected = try #require(tree.tableSelectionMarks["merge:1"])
        #expect(selected.id == "merge:1:bridge")
        #expect(selected.lineageClass == .contributive)
        #expect(selected.sourceRevisionIDs == ["A", "B"])
        #expect(tree.tableSelectionMarks["leaf:A"]?.id == "leaf:A")
        #expect(tree.tableSelectionMarks["merge:10"] == nil)
        let other = try specification(family: "network", marks: marks, rowIDs: rowIDs)
        #expect(other.tableSelectionMarks["merge:1"] == nil)
    }

    @Test func omitsGraphsWithoutMetricData() throws {
        for family in ["network", "dendrogram", "collocation-table"] {
            let plot = try specification(family: family)
            #expect(StudioFactorAudioGraph(plot, labels: labels) == nil)
        }
        let empty = try specification(includePoints: false)
        let constant = try specification(upperBound: -3)
        #expect(StudioFactorAudioGraph(empty, labels: labels) == nil)
        #expect(StudioFactorAudioGraph(constant, labels: labels) == nil)
    }

    private func specification(
        family: String = "factor-plot", axisCount: Int = 2, upperBound: Int = 2,
        includePoints: Bool = true, marks: [String]? = nil, rowIDs: [String] = []
    ) throws -> GlifiStudioVisualization {
        let axes = [
            axis(ordinal: 1, lower: -3, upper: upperBound),
            axis(ordinal: 2, lower: -1, upper: 4),
        ].prefix(axisCount)
        let points =
            includePoints
            ? [
                point("A", series: "documents", x: -2, y: 0),
                point("porto", series: "terms", x: 1, y: 4),
                point("B", series: "documents", x: 2, y: -1),
            ] : []
        let effectiveMarks = marks ?? points
        let rows = rowIDs.map { #"{"id":"\#($0)","cells":[]}"# }
        let json = """
            {"specificationIdentifier":"visual-spec.factor-plot.v1","family":"\(family)",
             "titleKey":"visual.title.factor-plot","artifactID":"fixture","analysisNodeID":"node",
             "analysisIdentifier":"fixture","methodIdentifier":"PCA-SVD-v1",
             "axes":[\(axes.joined(separator: ","))],"requiresEqualAspect":true,
             "marks":[\(effectiveMarks.joined(separator: ","))],"table":{"columns":[],"rows":[\(rows.joined(separator: ","))]},
             "totalObservationCount":\(effectiveMarks.count),"visibleObservationCount":\(effectiveMarks.count),
             "excludedLabels":[],"caveatKeys":[],"summaryKey":"visual.summary.factor-plot","summaryArguments":[]}
            """
        return try JSONDecoder().decode(GlifiStudioVisualization.self, from: Data(json.utf8))
    }

    private func axis(ordinal: Int, lower: Int, upper: Int) -> String {
        """
        {"fieldIdentifier":"axis.\(ordinal)","labelKey":"visual.axis.factor","ordinal":\(ordinal),
         "unitIdentifier":"score","scaleIdentifier":"linear","lowerBound":\(lower),"upperBound":\(upper)}
        """
    }

    private func point(
        _ label: String, series: String, x: Int, y: Int, kind: String = "point",
        lineage: String = "exact", sources: [String] = []
    ) -> String {
        let revisions = sources.map { #""\#($0)""# }.joined(separator: ",")
        return """
            {"id":"\(label)","kind":"\(kind)","series":"\(series)","label":"\(label)","x":\(x),"y":\(y),
             "isEmphasized":false,"lineageClass":"\(lineage)","sourceRevisionIDs":[\(revisions)]}
            """
    }
}
