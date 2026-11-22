// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

// Proiezioni versionate di Artifact immutabili (GS-MET-001-22, GS-VIZ-001): nessuna
// formula analitica è ricalcolata qui; si scelgono soltanto campi, domini, ordine,
// layout e riduzione dichiarati, e si conserva il lineage di ogni segno.

/// Scientific family of one visualization.
public enum GlifiStudioVisualizationFamily: String, Codable, Sendable {
    /// Scatter of row and column coordinates on two axes (CA, PCA, LSA).
    case factorPlot = "factor-plot"
    /// Complete agglomerative tree with its declared cut.
    case dendrogram
    /// Term network with a deterministic layout.
    case network
    /// Ordered table of window collocations.
    case collocationTable = "collocation-table"
}

/// Kind of one visual mark.
public enum GlifiStudioVisualMarkKind: String, Codable, Sendable {
    /// Positioned point.
    case point
    /// Straight segment from `(x, y)` to `(x2, y2)`.
    case segment
    /// Horizontal reference line at `y`.
    case rule
}

/// Lineage class of one mark (GS-MET-001-01).
public enum GlifiStudioVisualLineageClass: String, Codable, Sendable {
    /// The mark is one observation resolvable to exact source positions.
    case exact
    /// The mark aggregates contributions of the listed sources.
    case contributive
    /// The mark is derived by a transformation of the whole population.
    case derivational
}

/// One positional axis with an explicit, unclipped data domain.
public struct GlifiStudioVisualAxis: Codable, Equatable, Sendable {
    /// Stable field identity, such as `axis.1`.
    public let fieldIdentifier: String
    /// Localization key of the axis title.
    public let labelKey: String
    /// 1-based axis ordinal for factor axes.
    public let ordinal: Int?
    /// Share of inertia or variance of a factor axis.
    public let share: Double?
    /// Stable unit identity.
    public let unitIdentifier: String
    /// Scale identity; every current family uses `linear`.
    public let scaleIdentifier: String
    /// Smallest finite value represented, zero included when declared.
    public let lowerBound: Double
    /// Largest finite value represented, zero included when declared.
    public let upperBound: Double
}

/// One mark bound to a datum and to its lineage.
public struct GlifiStudioVisualMark: Codable, Equatable, Identifiable, Sendable {
    /// Stable datum identity shared with the equivalent table row.
    public let id: String
    /// Mark geometry.
    public let kind: GlifiStudioVisualMarkKind
    /// Semantic series used for the redundant color and shape channels.
    public let series: String
    /// Datum label: a term, a source revision or a merge.
    public let label: String
    /// Horizontal position.
    public let x: Double
    /// Vertical position.
    public let y: Double
    /// Horizontal end of a segment.
    public let x2: Double?
    /// Vertical end of a segment.
    public let y2: Double?
    /// Declared magnitude for the size or width channel.
    public let magnitude: Double?
    /// Whether the declared emphasis rule selects this mark for a visible label.
    public let isEmphasized: Bool
    /// Lineage class of the datum.
    public let lineageClass: GlifiStudioVisualLineageClass
    /// Sources reachable from the datum, in canonical order.
    public let sourceRevisionIDs: [String]
}

/// One cell of the equivalent table, formatted only by the client locale.
public enum GlifiStudioVisualCell: Codable, Equatable, Sendable {
    /// Text value.
    case text(String)
    /// Integer value.
    case integer(Int)
    /// Real value.
    case decimal(Double)
    /// Missing or non-applicable value, never rendered as zero.
    case missing
}

/// One column of the equivalent table.
public struct GlifiStudioVisualColumn: Codable, Equatable, Sendable {
    /// Stable column identity.
    public let identifier: String
    /// Localization key of the column title.
    public let labelKey: String
}

/// One row of the equivalent table, bound to the mark with the same identity.
public struct GlifiStudioVisualRow: Codable, Equatable, Identifiable, Sendable {
    /// Datum identity shared with the mark.
    public let id: String
    /// Cells in column order.
    public let cells: [GlifiStudioVisualCell]
}

/// Table that carries every represented datum, part of the same view.
public struct GlifiStudioVisualTable: Codable, Equatable, Sendable {
    /// Columns in display order.
    public let columns: [GlifiStudioVisualColumn]
    /// Rows in the declared order of the view.
    public let rows: [GlifiStudioVisualRow]
}

/// Named argument of the accessible summary.
public struct GlifiStudioVisualArgument: Codable, Equatable, Sendable {
    /// Placeholder name in the localized template.
    public let name: String
    /// Value formatted by the client locale.
    public let value: GlifiStudioVisualCell
}

/// Serializable view specification of one persisted Artifact.
public struct GlifiStudioVisualization: Codable, Equatable, Identifiable, Sendable {
    /// Stable identity: specification and source Artifact.
    public var id: String { "\(specificationIdentifier)|\(artifactID)" }
    /// Versioned specification identity.
    public let specificationIdentifier: String
    /// Scientific family.
    public let family: GlifiStudioVisualizationFamily
    /// Localization key of the title, phrased as the question answered.
    public let titleKey: String
    /// Source Artifact identity.
    public let artifactID: String
    /// Source semantic node.
    public let analysisNodeID: String
    /// Analysis bundle identity.
    public let analysisIdentifier: String
    /// Method identity kept explicit in detail and provenance.
    public let methodIdentifier: String
    /// Positional axes; empty when positions carry no metric meaning.
    public let axes: [GlifiStudioVisualAxis]
    /// Whether one unit must have the same length on both axes.
    public let requiresEqualAspect: Bool
    /// Marks in drawing order.
    public let marks: [GlifiStudioVisualMark]
    /// Equivalent table.
    public let table: GlifiStudioVisualTable
    /// Observations in the source Artifact.
    public let totalObservationCount: Int
    /// Observations represented by marks or rows.
    public let visibleObservationCount: Int
    /// Declared deterministic reduction, when the view shows a subset.
    public let reductionIdentifier: String?
    /// Declared deterministic layout, when positions are not data.
    public let layoutIdentifier: String?
    /// Declared rule selecting labeled marks.
    public let emphasisIdentifier: String?
    /// Items excluded by the method or by a non-finite value.
    public let excludedLabels: [String]
    /// Caveat keys that change the reading of the view.
    public let caveatKeys: [String]
    /// Localization key of the accessible, non-causal summary.
    public let summaryKey: String
    /// Arguments of the accessible summary.
    public let summaryArguments: [GlifiStudioVisualArgument]
}

/// Deterministic builders of view specifications from Kit results.
public enum GlifiStudioVisualizationBuilder {
    /// Maximum network nodes drawn before the declared reduction applies.
    public static let maximumNetworkNodeCount = 60

    /// Factor plot of CA, PCA or LSA on two axes; `nil` for methods without axes.
    public static func factorPlot(
        _ result: GlifiStudioMultivariateResult,
        firstAxis: Int = 0,
        secondAxis: Int = 1
    ) throws -> GlifiStudioVisualization? {
        let supported = ["CA-SVD-v1", "PCA-SVD-v1", "LSA-SVD-v1"]
        guard supported.contains(result.methodIdentifier), !result.axisValues.isEmpty else {
            return nil
        }
        let axisRange = 0..<result.axisValues.count
        let validAxes =
            result.axisValues.count == 1
            ? firstAxis == 0
            : axisRange.contains(firstAxis) && axisRange.contains(secondAxis)
                && firstAxis != secondAxis
        guard validAxes else {
            throw visualizationFailure("visualization.invalid-axis")
        }
        let isCorrespondence = result.methodIdentifier == "CA-SVD-v1"
        let excludedDocuments = Set(result.excludedSourceRevisionIDs)
        let excludedTerms = Set(result.excludedTerms)
        let documents = result.sourceRevisionIDs.filter { !excludedDocuments.contains($0) }
        let terms = result.terms.filter { !excludedTerms.contains($0) }
        guard documents.count == result.rowCoordinates.count,
            terms.count == result.columnCoordinates.count
        else {
            throw visualizationFailure("visualization.coordinate-shape-mismatch")
        }
        let hasSecondAxis = result.axisValues.count > 1
        let secondIndex = hasSecondAxis ? secondAxis : firstAxis
        var marks: [GlifiStudioVisualMark] = []
        var rows: [GlifiStudioVisualRow] = []
        var nonFinite: [String] = []
        func add(
            prefix: String,
            series: String,
            label: String,
            coordinates: [Double],
            contributions: [Double]?,
            cosines: [Double]?,
            sources: [String],
            count: Int
        ) {
            let x = coordinates[firstAxis]
            let y = hasSecondAxis ? coordinates[secondIndex] : 0
            guard x.isFinite, y.isFinite else {
                nonFinite.append(label)
                return
            }
            // Contributo superiore alla media 1/n su uno dei due assi (Greenacre 2017).
            let threshold = 1 / Double(count)
            let emphasized: Bool
            if let contributions {
                emphasized =
                    contributions[firstAxis] > threshold
                    || (hasSecondAxis && contributions[secondIndex] > threshold)
            } else {
                emphasized = series == "documents"
            }
            let identifier = "\(prefix):\(label)"
            let contribution = contributions.map {
                hasSecondAxis ? $0[firstAxis] + $0[secondIndex] : $0[firstAxis]
            }
            marks.append(
                GlifiStudioVisualMark(
                    id: identifier,
                    kind: .point,
                    series: series,
                    label: label,
                    x: x,
                    y: y,
                    x2: nil,
                    y2: nil,
                    magnitude: contribution,
                    isEmphasized: emphasized,
                    lineageClass: series == "documents" ? .exact : .contributive,
                    sourceRevisionIDs: sources
                )
            )
            let quality = cosines.map {
                hasSecondAxis ? $0[firstAxis] + $0[secondIndex] : $0[firstAxis]
            }
            rows.append(
                GlifiStudioVisualRow(
                    id: identifier,
                    cells: [
                        .text(label),
                        .text(series),
                        .decimal(x),
                        hasSecondAxis ? .decimal(y) : .missing,
                        contribution.map { .decimal($0) } ?? .missing,
                        quality.map { .decimal($0) } ?? .missing,
                    ]
                )
            )
        }
        for (index, document) in documents.enumerated() {
            add(
                prefix: "row",
                series: "documents",
                label: document,
                coordinates: result.rowCoordinates[index],
                contributions: result.rowContributions?[index],
                cosines: result.rowCosines?[index],
                sources: [document],
                count: documents.count
            )
        }
        for (index, term) in terms.enumerated() {
            add(
                prefix: "column",
                series: "terms",
                label: term,
                coordinates: result.columnCoordinates[index],
                contributions: result.columnContributions?[index],
                cosines: nil,
                sources: documents,
                count: terms.count
            )
        }
        let axes = [firstAxis, secondIndex].prefix(hasSecondAxis ? 2 : 1).enumerated().map {
            position, axis in
            let values = marks.map { position == 0 ? $0.x : $0.y }
            return GlifiStudioVisualAxis(
                fieldIdentifier: "axis.\(axis + 1)",
                labelKey: "visual.axis.factor",
                ordinal: axis + 1,
                share: result.axisShares.indices.contains(axis) ? result.axisShares[axis] : nil,
                unitIdentifier: isCorrespondence ? "principal-coordinate" : "score",
                scaleIdentifier: "linear",
                lowerBound: min(0, values.min() ?? 0),
                upperBound: max(0, values.max() ?? 0)
            )
        }
        let plotted = [firstAxis, secondIndex].prefix(hasSecondAxis ? 2 : 1)
        let plottedShare = plotted.reduce(0.0) {
            $0 + (result.axisShares.indices.contains($1) ? result.axisShares[$1] : 0)
        }
        var caveats: [String] = []
        if isCorrespondence {
            caveats.append("caveat.visual.symmetric-map")
        }
        if plottedShare < 0.5 {
            caveats.append("caveat.visual.low-plotted-share")
        }
        if !nonFinite.isEmpty {
            caveats.append("caveat.visual.non-finite-excluded")
        }
        return GlifiStudioVisualization(
            specificationIdentifier: "visual-spec.factor-plot.v1",
            family: .factorPlot,
            titleKey: "visual.title.factor-plot",
            artifactID: result.lineage.artifactID,
            analysisNodeID: result.lineage.analysisNodeID,
            analysisIdentifier: result.analysisIdentifier,
            methodIdentifier: result.methodIdentifier,
            axes: Array(axes),
            requiresEqualAspect: isCorrespondence,
            marks: marks,
            table: GlifiStudioVisualTable(
                columns: [
                    column("label"), column("series"), column("axis-x"), column("axis-y"),
                    column("contribution"), column("quality"),
                ],
                rows: rows
            ),
            totalObservationCount: result.sourceRevisionIDs.count + result.terms.count,
            visibleObservationCount: marks.count,
            reductionIdentifier: nil,
            layoutIdentifier: nil,
            emphasisIdentifier: isCorrespondence
                ? "emphasis.contribution-above-mean.v1" : "emphasis.documents.v1",
            excludedLabels: result.excludedSourceRevisionIDs + result.excludedTerms + nonFinite,
            caveatKeys: caveats,
            summaryKey: "visual.summary.factor-plot",
            summaryArguments: [
                GlifiStudioVisualArgument(name: "documents", value: .integer(documents.count)),
                GlifiStudioVisualArgument(name: "terms", value: .integer(terms.count)),
                GlifiStudioVisualArgument(name: "share", value: .decimal(plottedShare)),
            ]
        )
    }

    /// Dendrogram of an HAC tree with the cut that yields the stored clusters.
    public static func dendrogram(
        _ result: GlifiStudioMultivariateResult
    ) throws -> GlifiStudioVisualization? {
        guard let merges = result.merges else {
            return nil
        }
        let leaves = result.sourceRevisionIDs
        let leafCount = leaves.count
        guard leafCount >= 2, merges.count == leafCount - 1 else {
            throw visualizationFailure("visualization.merge-shape-mismatch")
        }
        for (step, merge) in merges.enumerated() {
            let limit = leafCount + step
            guard merge.first >= 0, merge.first < limit, merge.second >= 0,
                merge.second < limit, merge.first != merge.second
            else {
                throw visualizationFailure("visualization.merge-shape-mismatch")
            }
        }
        let order = leafOrder(merges: merges, leafCount: leafCount)
        var position = [Int: Double]()
        for (index, leaf) in order.enumerated() {
            position[leaf] = Double(index)
        }
        var height = [Int: Double]()
        for leaf in 0..<leafCount {
            height[leaf] = 0
        }
        let assignments = result.clusterAssignments
        var marks: [GlifiStudioVisualMark] = []
        var descendants = [Int: [Int]]()
        for leaf in 0..<leafCount {
            descendants[leaf] = [leaf]
        }
        var rows: [GlifiStudioVisualRow] = []
        for (step, merge) in merges.enumerated() {
            let node = leafCount + step
            let firstX = position[merge.first] ?? 0
            let secondX = position[merge.second] ?? 0
            let firstY = height[merge.first] ?? 0
            let secondY = height[merge.second] ?? 0
            let members = ((descendants[merge.first] ?? []) + (descendants[merge.second] ?? []))
                .sorted()
            descendants[node] = members
            position[node] = (firstX + secondX) / 2
            height[node] = merge.height
            let sources = members.map { leaves[$0] }
            let geometry: [(String, Double, Double, Double, Double)] = [
                ("first", firstX, firstY, firstX, merge.height),
                ("second", secondX, secondY, secondX, merge.height),
                ("bridge", firstX, merge.height, secondX, merge.height),
            ]
            for (part, x, y, x2, y2) in geometry {
                marks.append(
                    GlifiStudioVisualMark(
                        id: "merge:\(step + 1):\(part)",
                        kind: .segment,
                        series: "merges",
                        label: "\(step + 1)",
                        x: x,
                        y: y,
                        x2: x2,
                        y2: y2,
                        magnitude: nil,
                        isEmphasized: false,
                        lineageClass: .contributive,
                        sourceRevisionIDs: sources
                    )
                )
            }
            rows.append(
                GlifiStudioVisualRow(
                    id: "merge:\(step + 1)",
                    cells: [
                        .integer(step + 1),
                        .text(nodeLabel(merge.first, leaves: leaves)),
                        .text(nodeLabel(merge.second, leaves: leaves)),
                        .decimal(merge.height),
                        .integer(merge.size),
                    ]
                )
            )
        }
        for (index, leaf) in order.enumerated() {
            let cluster = assignments.flatMap { $0.indices.contains(leaf) ? $0[leaf] : nil }
            marks.append(
                GlifiStudioVisualMark(
                    id: "leaf:\(leaves[leaf])",
                    kind: .point,
                    series: cluster.map { "cluster.\($0 + 1)" } ?? "documents",
                    label: leaves[leaf],
                    x: Double(index),
                    y: 0,
                    x2: nil,
                    y2: nil,
                    magnitude: nil,
                    isEmphasized: true,
                    lineageClass: .exact,
                    sourceRevisionIDs: [leaves[leaf]]
                )
            )
        }
        var caveats: [String] = []
        let heights = merges.map(\.height)
        if zip(heights, heights.dropFirst()).contains(where: { $0 > $1 }) {
            caveats.append("caveat.visual.non-monotone-heights")
        }
        let clusterCount = Set(assignments ?? []).count
        if clusterCount >= 2, clusterCount < leafCount {
            // Il taglio a k gruppi cade fra la fusione n−k e la successiva: punto medio.
            let lower = heights[leafCount - clusterCount - 1]
            let upper = heights[leafCount - clusterCount]
            if lower == upper {
                caveats.append("caveat.visual.tied-cut-height")
            }
            marks.append(
                GlifiStudioVisualMark(
                    id: "cut:\(clusterCount)",
                    kind: .rule,
                    series: "cut",
                    label: "\(clusterCount)",
                    x: 0,
                    y: (lower + upper) / 2,
                    x2: Double(leafCount - 1),
                    y2: (lower + upper) / 2,
                    magnitude: nil,
                    isEmphasized: true,
                    lineageClass: .derivational,
                    sourceRevisionIDs: leaves
                )
            )
        }
        let maximumHeight = heights.max() ?? 0
        return GlifiStudioVisualization(
            specificationIdentifier: "visual-spec.dendrogram.v1",
            family: .dendrogram,
            titleKey: "visual.title.dendrogram",
            artifactID: result.lineage.artifactID,
            analysisNodeID: result.lineage.analysisNodeID,
            analysisIdentifier: result.analysisIdentifier,
            methodIdentifier: result.methodIdentifier,
            axes: [
                GlifiStudioVisualAxis(
                    fieldIdentifier: "leaf-order",
                    labelKey: "visual.axis.leaf-order",
                    ordinal: nil,
                    share: nil,
                    unitIdentifier: "ordinal",
                    scaleIdentifier: "linear",
                    lowerBound: 0,
                    upperBound: Double(leafCount - 1)
                ),
                GlifiStudioVisualAxis(
                    fieldIdentifier: "merge-height",
                    labelKey: "visual.axis.merge-height",
                    ordinal: nil,
                    share: nil,
                    unitIdentifier: "linkage-height",
                    scaleIdentifier: "linear",
                    lowerBound: 0,
                    upperBound: maximumHeight
                ),
            ],
            requiresEqualAspect: false,
            marks: marks,
            table: GlifiStudioVisualTable(
                columns: [
                    column("step"), column("first"), column("second"), column("height"),
                    column("size"),
                ],
                rows: rows
            ),
            totalObservationCount: leafCount,
            visibleObservationCount: leafCount,
            reductionIdentifier: nil,
            layoutIdentifier: "layout.dendrogram-first-child-left.v1",
            emphasisIdentifier: nil,
            excludedLabels: [],
            caveatKeys: caveats,
            summaryKey: "visual.summary.dendrogram",
            summaryArguments: [
                GlifiStudioVisualArgument(name: "documents", value: .integer(leafCount)),
                GlifiStudioVisualArgument(name: "clusters", value: .integer(clusterCount)),
                GlifiStudioVisualArgument(name: "height", value: .decimal(maximumHeight)),
            ]
        )
    }

    /// Network of a token-window graph with a deterministic circular layout.
    public static func network(
        _ result: GlifiStudioWindowNetworkResult
    ) -> GlifiStudioVisualization {
        network(
            artifactID: result.lineage.artifactID,
            analysisNodeID: result.lineage.analysisNodeID,
            analysisIdentifier: result.analysisIdentifier,
            graphIdentifier: result.graphIdentifier,
            nodes: result.nodes,
            edges: result.edges,
            summary: result.summary
        )
    }

    /// Network of a document co-occurrence graph with a deterministic circular layout.
    public static func network(
        _ result: GlifiStudioLexicalNetworkResult
    ) -> GlifiStudioVisualization {
        network(
            artifactID: result.lineage.artifactID,
            analysisNodeID: result.lineage.analysisNodeID,
            analysisIdentifier: result.analysisIdentifier,
            graphIdentifier: result.graphIdentifier,
            nodes: result.nodes,
            edges: result.edges,
            summary: result.summary
        )
    }

    /// Table of window collocations in the order stored by the Artifact.
    public static func collocationTable(
        _ result: GlifiStudioWindowCollocationResult
    ) -> GlifiStudioVisualization {
        let rows = result.pairs.map { pair in
            GlifiStudioVisualRow(
                id: "pair:\(pair.nodeTerm)|\(pair.collocateTerm)",
                cells: [
                    .text(pair.nodeTerm),
                    .text(pair.collocateTerm),
                    .integer(pair.jointCount),
                    optional(pair.logDice),
                    optional(pair.tScore),
                    optional(pair.npmi),
                    .decimal(pair.meanDistance),
                ]
            )
        }
        var caveats: [String] = []
        if result.isTruncated {
            caveats.append("caveat.visual.truncated-pairs")
        }
        return GlifiStudioVisualization(
            specificationIdentifier: "visual-spec.collocation-table.v1",
            family: .collocationTable,
            titleKey: "visual.title.collocation-table",
            artifactID: result.lineage.artifactID,
            analysisNodeID: result.lineage.analysisNodeID,
            analysisIdentifier: result.analysisIdentifier,
            methodIdentifier: result.universeIdentifier,
            axes: [],
            requiresEqualAspect: false,
            marks: [],
            table: GlifiStudioVisualTable(
                columns: [
                    column("node"), column("collocate"), column("joint"), column("log-dice"),
                    column("t-score"), column("npmi"), column("mean-distance"),
                ],
                rows: rows
            ),
            totalObservationCount: result.distinctPairCount,
            visibleObservationCount: rows.count,
            reductionIdentifier: result.isTruncated
                ? "reduction.stored-pair-limit.v1"
                : rows.count < result.distinctPairCount ? "reduction.artifact-thresholds.v1" : nil,
            layoutIdentifier: nil,
            emphasisIdentifier: nil,
            excludedLabels: [],
            caveatKeys: caveats,
            summaryKey: "visual.summary.collocation-table",
            summaryArguments: [
                GlifiStudioVisualArgument(name: "pairs", value: .integer(rows.count)),
                GlifiStudioVisualArgument(
                    name: "distinct", value: .integer(result.distinctPairCount)),
                GlifiStudioVisualArgument(name: "tokens", value: .integer(result.tokenCount)),
            ]
        )
    }

    /// Equivalent table as RFC 4180 CSV with locale-independent values.
    ///
    /// The header carries the stable column identities; a leading `datum` column
    /// keeps the datum identity shared with the marks. Reals use the shortest
    /// representation that round-trips to the same binary64 value; missing cells
    /// are empty fields, never zero.
    public static func csv(_ visualization: GlifiStudioVisualization) -> String {
        let header = ["datum"] + visualization.table.columns.map(\.identifier)
        var lines = [header.map(csvField).joined(separator: ",")]
        for row in visualization.table.rows {
            let cells = row.cells.map { cell -> String in
                switch cell {
                case let .text(value): csvField(value)
                case let .integer(value): String(value)
                case let .decimal(value): value.isFinite ? "\(value)" : ""
                case .missing: ""
                }
            }
            lines.append(([csvField(row.id)] + cells).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
        else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Leaf order that places the first child left of the second at every merge.
    static func leafOrder(merges: [GlifiStudioMerge], leafCount: Int) -> [Int] {
        guard !merges.isEmpty else {
            return Array(0..<leafCount)
        }
        var order: [Int] = []
        var stack = [leafCount + merges.count - 1]
        while let node = stack.popLast() {
            if node < leafCount {
                order.append(node)
            } else {
                let merge = merges[node - leafCount]
                stack.append(merge.second)
                stack.append(merge.first)
            }
        }
        return order
    }

    private static func network(
        artifactID: String,
        analysisNodeID: String,
        analysisIdentifier: String,
        graphIdentifier: String,
        nodes: [GlifiStudioNetworkNode],
        edges: [GlifiStudioNetworkEdge],
        summary: GlifiStudioNetworkSummary
    ) -> GlifiStudioVisualization {
        // Riduzione: i nodi con PageRank più alto (spareggio lessicografico).
        let ranked = nodes.sorted {
            $0.pageRank != $1.pageRank ? $0.pageRank > $1.pageRank : $0.term < $1.term
        }
        let visible = Array(ranked.prefix(maximumNetworkNodeCount))
        let placed = visible.sorted {
            if $0.community != $1.community {
                return $0.community < $1.community
            }
            return $0.pageRank != $1.pageRank ? $0.pageRank > $1.pageRank : $0.term < $1.term
        }
        var positions = [String: (Double, Double)]()
        for (index, node) in placed.enumerated() {
            let angle = 2 * Double.pi * Double(index) / Double(max(placed.count, 1))
            positions[node.term] = (cos(angle), sin(angle))
        }
        var supportingSources = [String: Set<String>]()
        var marks: [GlifiStudioVisualMark] = []
        var visibleEdgeCount = 0
        for edge in edges {
            guard let from = positions[edge.source], let to = positions[edge.target] else {
                continue
            }
            visibleEdgeCount += 1
            supportingSources[edge.source, default: []].formUnion(edge.supportingSourceRevisionIDs)
            supportingSources[edge.target, default: []].formUnion(edge.supportingSourceRevisionIDs)
            marks.append(
                GlifiStudioVisualMark(
                    id: "edge:\(edge.source)|\(edge.target)",
                    kind: .segment,
                    series: "edges",
                    label: "\(edge.source) – \(edge.target)",
                    x: from.0,
                    y: from.1,
                    x2: to.0,
                    y2: to.1,
                    magnitude: edge.weight,
                    isEmphasized: false,
                    lineageClass: edge.occurrences.isEmpty ? .contributive : .exact,
                    sourceRevisionIDs: edge.supportingSourceRevisionIDs.sorted()
                )
            )
        }
        var rows: [GlifiStudioVisualRow] = []
        let emphasisCount = min(placed.count, 12)
        let emphasized = Set(ranked.prefix(emphasisCount).map(\.term))
        for node in placed {
            guard let point = positions[node.term] else {
                continue
            }
            let identifier = "node:\(node.term)"
            marks.append(
                GlifiStudioVisualMark(
                    id: identifier,
                    kind: .point,
                    series: "community.\(node.community + 1)",
                    label: node.term,
                    x: point.0,
                    y: point.1,
                    x2: nil,
                    y2: nil,
                    magnitude: node.pageRank,
                    isEmphasized: emphasized.contains(node.term),
                    lineageClass: .contributive,
                    sourceRevisionIDs: (supportingSources[node.term] ?? []).sorted()
                )
            )
            rows.append(
                GlifiStudioVisualRow(
                    id: identifier,
                    cells: [
                        .text(node.term),
                        .integer(node.community + 1),
                        .integer(node.degree),
                        .decimal(node.weightedDegree),
                        .decimal(node.pageRank),
                        .decimal(node.weightedBetweenness),
                        .decimal(node.eigenvector),
                    ]
                )
            )
        }
        var caveats = ["caveat.visual.layout-not-metric"]
        if visible.count < nodes.count {
            caveats.append("caveat.visual.network-reduced")
        }
        return GlifiStudioVisualization(
            specificationIdentifier: "visual-spec.network.v1",
            family: .network,
            titleKey: "visual.title.network",
            artifactID: artifactID,
            analysisNodeID: analysisNodeID,
            analysisIdentifier: analysisIdentifier,
            methodIdentifier: graphIdentifier,
            axes: [],
            requiresEqualAspect: true,
            marks: marks,
            table: GlifiStudioVisualTable(
                columns: [
                    column("term"), column("community"), column("degree"),
                    column("weighted-degree"), column("page-rank"), column("betweenness"),
                    column("eigenvector"),
                ],
                rows: rows
            ),
            totalObservationCount: nodes.count,
            visibleObservationCount: placed.count,
            reductionIdentifier: visible.count < nodes.count ? "reduction.top-pagerank.v1" : nil,
            layoutIdentifier: "layout.circular-community-pagerank.v1",
            emphasisIdentifier: "emphasis.top-pagerank-12.v1",
            excludedLabels: [],
            caveatKeys: caveats,
            summaryKey: "visual.summary.network",
            summaryArguments: [
                GlifiStudioVisualArgument(name: "nodes", value: .integer(placed.count)),
                GlifiStudioVisualArgument(name: "total", value: .integer(nodes.count)),
                GlifiStudioVisualArgument(name: "edges", value: .integer(visibleEdgeCount)),
                GlifiStudioVisualArgument(
                    name: "communities",
                    value: summary.communityCount.map { .integer($0) } ?? .missing
                ),
            ]
        )
    }

    private static func nodeLabel(_ node: Int, leaves: [String]) -> String {
        node < leaves.count ? leaves[node] : "#\(node - leaves.count + 1)"
    }

    private static func column(_ identifier: String) -> GlifiStudioVisualColumn {
        GlifiStudioVisualColumn(identifier: identifier, labelKey: "visual.column.\(identifier)")
    }

    private static func optional(_ value: Double?) -> GlifiStudioVisualCell {
        guard let value, value.isFinite else {
            return .missing
        }
        return .decimal(value)
    }

    private static func visualizationFailure(_ code: String) -> GlifiStudioFailure {
        GlifiStudioFailure(
            GlifiFailure(
                code: code,
                category: .invariantViolation,
                operation: .analyze,
                retryDisposition: .never,
                retainedState: .validityUnknown,
                messageKey: "failure.\(code)"
            )
        )
    }
}
