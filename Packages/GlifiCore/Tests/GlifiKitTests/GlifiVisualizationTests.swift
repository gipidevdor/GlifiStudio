// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiKit

@Test("L'ordine delle foglie coincide con hclust$order di R per ogni linkage")
func dendrogramLeafOrderMatchesR() {
    // Oracolo: Tests/Oracles/R/visualization.R (DENDRO_*_MERGE, DENDRO_*_ORDER).
    let cases: [(merge: [Int], order: [Int])] = [
        (
            [-3, -4, -5, -6, -1, -2, -8, 3, -7, 1, 2, 5, 4, 6],
            [8, 1, 2, 5, 6, 7, 3, 4]
        ),
        (
            [-3, -4, -5, -6, -1, -2, -8, 3, -7, 1, 4, 5, 2, 6],
            [5, 6, 8, 1, 2, 7, 3, 4]
        ),
    ]
    for (merge, order) in cases {
        let leafCount = merge.count / 2 + 1
        // R: -i è la foglia i (1-based), +j la fusione j; GlifiKit: 0..<n foglie, n+s fusioni.
        let encode = { (value: Int) in value < 0 ? -value - 1 : leafCount + value - 1 }
        let merges = stride(from: 0, to: merge.count, by: 2).map {
            GlifiStudioMerge(
                first: encode(merge[$0]), second: encode(merge[$0 + 1]), height: 0, size: 0)
        }
        #expect(
            GlifiStudioVisualizationBuilder.leafOrder(merges: merges, leafCount: leafCount)
                == order.map { $0 - 1 })
    }
}

@Test("La tabella equivalente si esporta in CSV RFC 4180 senza perdita dei valori")
func visualizationTableExportsLosslessCSV() throws {
    let visualization = GlifiStudioVisualization(
        specificationIdentifier: "visual-spec.test.v1",
        family: .collocationTable,
        titleKey: "visual.title.collocation-table",
        artifactID: "artifact:test",
        analysisNodeID: "node:test",
        analysisIdentifier: "test",
        methodIdentifier: "test",
        axes: [],
        requiresEqualAspect: false,
        marks: [],
        table: GlifiStudioVisualTable(
            columns: [
                GlifiStudioVisualColumn(identifier: "node", labelKey: "visual.column.node"),
                GlifiStudioVisualColumn(identifier: "joint", labelKey: "visual.column.joint"),
                GlifiStudioVisualColumn(identifier: "npmi", labelKey: "visual.column.npmi"),
            ],
            rows: [
                GlifiStudioVisualRow(
                    id: "pair:a|b", cells: [.text("mare, \"calmo\""), .integer(3), .decimal(0.1)]),
                GlifiStudioVisualRow(
                    id: "pair:c|d", cells: [.text("porto"), .integer(1), .missing]),
            ]
        ),
        totalObservationCount: 2,
        visibleObservationCount: 2,
        reductionIdentifier: nil,
        layoutIdentifier: nil,
        emphasisIdentifier: nil,
        excludedLabels: [],
        caveatKeys: [],
        summaryKey: "visual.summary.collocation-table",
        summaryArguments: []
    )
    let csv = GlifiStudioVisualizationBuilder.csv(visualization)
    #expect(
        csv
            == "datum,node,joint,npmi\r\npair:a|b,\"mare, \"\"calmo\"\"\",3,0.1\r\npair:c|d,porto,1,\r\n"
    )
}

@Test("Le viste dei risultati estesi proiettano gli Artifact del piano senza ricalcolo")
func serviceProjectsExtendedArtifactsIntoVisualizations() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiKitVisualizationTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "Viste.glifi", directoryHint: .isDirectory)
    )
    let texts = [
        "Il mare calmo bagna il porto e le barche tornano al porto dopo la pesca in mare.",
        "Le barche del porto escono in mare aperto, il mare porta pesca e vento al porto.",
        "La montagna innevata domina la valle; sentieri di montagna salgono dalla valle.",
        "Nella valle il sentiero sale verso la montagna e la neve copre il sentiero.",
    ]
    for (index, text) in texts.enumerated() {
        let url = root.appending(path: "fonte-\(index).txt")
        try Data(text.utf8).write(to: url)
        _ = try await session.importText(at: url, format: .plainText)
    }

    func execute(_ intent: String) async throws -> GlifiStudioAnalysisExecutionResult {
        let execution = try await session.executeAnalysisPlan(
            GlifiStudioAnalysisPlanRequest(intent: intent)
        )
        var completed: GlifiStudioAnalysisExecutionResult?
        for try await event in execution.events {
            if case let .completed(result) = event { completed = result }
        }
        return try #require(completed)
    }

    let themes = try await execute("identify.themes")
    let artifactCount = try await session.snapshot().artifactCount
    let views = try await session.visualizations(for: themes)
    #expect(try await session.snapshot().artifactCount == artifactCount)
    let families = Set(views.map(\.family))
    #expect(families == [.factorPlot, .dendrogram, .network])
    let producedArtifacts = Set(themes.artifacts.map(\.artifactID))
    for view in views {
        #expect(producedArtifacts.contains(view.artifactID))
        #expect(view.visibleObservationCount <= view.totalObservationCount)
        for axis in view.axes {
            #expect(axis.lowerBound <= axis.upperBound)
        }
        let decoded = try JSONDecoder().decode(
            GlifiStudioVisualization.self, from: JSONEncoder().encode(view))
        #expect(decoded == view)
        // CSV: intestazione più una riga per dato; ogni reale torna identico in binary64.
        let lines = GlifiStudioVisualizationBuilder.csv(view).split(
            separator: "\r\n", omittingEmptySubsequences: true)
        #expect(lines.count == view.table.rows.count + 1)
        for (line, row) in zip(lines.dropFirst(), view.table.rows) {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count == row.cells.count + 1 else { continue }
            for (field, cell) in zip(fields.dropFirst(), row.cells) {
                if case let .decimal(value) = cell {
                    #expect(Double(String(field)) == value)
                }
            }
        }
    }

    // Grafico fattoriale: stessi valori dell'Artifact CA, dominio senza clipping, origine inclusa.
    let plot = try #require(views.first { $0.family == .factorPlot })
    let sources = try await session.snapshot().sources.map(\.sourceRevisionID)
    let correspondence = try await session.analyzeMultivariate(
        sourceRevisionIDs: sources.sorted(),
        method: .correspondence
    )
    #expect(correspondence.lineage.artifactID == plot.artifactID)
    #expect(plot.methodIdentifier == "CA-SVD-v1")
    #expect(plot.requiresEqualAspect)
    #expect(plot.caveatKeys.contains("caveat.visual.symmetric-map"))
    #expect(plot.axes.map(\.share) == correspondence.axisShares.prefix(2).map { $0 })
    let pointIDs = plot.marks.map(\.id)
    #expect(pointIDs == plot.table.rows.map(\.id))
    for (index, mark) in plot.marks.enumerated() where mark.series == "documents" {
        #expect(mark.x == correspondence.rowCoordinates[index][0])
        #expect(mark.y == correspondence.rowCoordinates[index][1])
        #expect(mark.sourceRevisionIDs == [mark.label])
    }
    for (position, axis) in plot.axes.enumerated() {
        let values = plot.marks.map { position == 0 ? $0.x : $0.y }
        #expect(axis.lowerBound == min(0, values.min() ?? 0))
        #expect(axis.upperBound == max(0, values.max() ?? 0))
    }

    // Dendrogramma: foglie permutate senza incroci e taglio fra due altezze di fusione.
    let tree = try #require(views.first { $0.family == .dendrogram })
    let leaves = tree.marks.filter { $0.id.hasPrefix("leaf:") }
    #expect(Set(leaves.map(\.label)) == Set(sources))
    #expect(leaves.map(\.x) == leaves.indices.map(Double.init))
    #expect(tree.table.rows.count == sources.count - 1)
    for mark in tree.marks where mark.id.hasSuffix(":bridge") {
        let span = leaves.filter {
            $0.x >= min(mark.x, mark.x2 ?? mark.x) && $0.x <= max(mark.x, mark.x2 ?? mark.x)
        }
        // Le foglie sotto un ponte appartengono tutte alla fusione: nessun incrocio.
        #expect(Set(span.map(\.label)).isSubset(of: Set(mark.sourceRevisionIDs)))
    }
    let heights = tree.table.rows.compactMap { row -> Double? in
        if case let .decimal(value) = row.cells[3] { return value }
        return nil
    }
    let cut = try #require(tree.marks.first { $0.kind == .rule })
    let clusterCount = try #require(Int(cut.label))
    #expect(heights.filter { $0 > cut.y }.count == clusterCount - 1)
    #expect(Set(leaves.map(\.series)).count == clusterCount)

    // Rete: layout circolare dichiarato, archi solo fra nodi visibili, tabella equivalente.
    let network = try #require(views.first { $0.family == .network })
    #expect(network.layoutIdentifier == "layout.circular-community-pagerank.v1")
    #expect(network.caveatKeys.contains("caveat.visual.layout-not-metric"))
    let nodes = network.marks.filter { $0.kind == .point }
    #expect(nodes.map(\.id) == network.table.rows.map(\.id))
    #expect(nodes.count == network.visibleObservationCount)
    for node in nodes {
        #expect(abs(node.x * node.x + node.y * node.y - 1) < 1e-12)
    }
    let nodePoints = Set(nodes.map { "\($0.x),\($0.y)" })
    for edge in network.marks where edge.kind == .segment {
        #expect(nodePoints.contains("\(edge.x),\(edge.y)"))
        #expect(nodePoints.contains("\(edge.x2 ?? .nan),\(edge.y2 ?? .nan)"))
    }

    // Collocazioni: tabella nell'ordine dell'Artifact, senza segni grafici.
    let relationships = try await execute("explore.relationships")
    let relationshipViews = try await session.visualizations(for: relationships)
    let table = try #require(relationshipViews.first { $0.family == .collocationTable })
    #expect(Set(relationships.artifacts.map(\.artifactID)).contains(table.artifactID))
    #expect(table.marks.isEmpty)
    #expect(table.table.rows.count == table.visibleObservationCount)
    if table.visibleObservationCount < table.totalObservationCount {
        #expect(table.reductionIdentifier != nil)
    }
    #expect(Set(table.table.rows.map(\.id)).count == table.table.rows.count)
    #expect(table.table.columns.count == table.table.rows.first?.cells.count)
    await session.close()
}

@Test("L'export di una vista scrive tabella, specifica e manifest verificabile con provenienza")
func visualizationExportCarriesVerifiableProvenance() async throws {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiVisualExport-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try await GlifiStudioService().createProject(
        at: root.appending(path: "E.glifi", directoryHint: .isDirectory))
    for (index, text) in [
        "Il mare bagna il porto e le barche tornano al porto dal mare.",
        "La valle e la montagna, sentieri di montagna nella valle.",
        "Il porto sul mare e la montagna sopra la valle.",
    ].enumerated() {
        let url = root.appending(path: "f\(index).txt")
        try Data(text.utf8).write(to: url)
        _ = try await session.importText(at: url, format: .plainText)
    }
    let execution = try await session.executeAnalysisPlan(
        GlifiStudioAnalysisPlanRequest(intent: "identify.themes"))
    var completed: GlifiStudioAnalysisExecutionResult?
    for try await event in execution.events {
        if case let .completed(result) = event { completed = result }
    }
    let views = try await session.visualizations(for: try #require(completed))
    let view = try #require(views.first)
    let snapshot = try await session.snapshot()

    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let bundle = try GlifiStudioVisualExport.bundle(
        view, projectID: snapshot.projectID, generation: snapshot.generation, createdAt: date)
    #expect(
        try GlifiStudioVisualExport.bundle(
            view, projectID: snapshot.projectID, generation: snapshot.generation,
            createdAt: date) == bundle)
    #expect(Set(bundle.keys) == ["view.csv", "view-spec.json", "visual-export-manifest.json"])
    let manifest = try GlifiStudioVisualExport.verify(bundle)
    #expect(manifest.artifactID == view.artifactID)
    #expect(manifest.generation == snapshot.generation)
    #expect(manifest.createdAt == "2027-01-15T08:00:00Z")
    #expect(
        try JSONDecoder().decode(
            GlifiStudioVisualization.self, from: try #require(bundle["view-spec.json"])) == view)
    var tampered = bundle
    tampered["view.csv"] = Data("datum\r\n".utf8)
    #expect(throws: GlifiStudioFailure.self) { _ = try GlifiStudioVisualExport.verify(tampered) }

    let destination = root.appending(path: "vista", directoryHint: .isDirectory)
    let receipt = try await session.exportVisualization(view, to: destination)
    #expect(receipt.fileCount == 3)
    var written: [String: Data] = [:]
    for name in try FileManager.default.contentsOfDirectory(atPath: destination.path) {
        written[name] = try Data(contentsOf: destination.appending(path: name))
    }
    #expect(try GlifiStudioVisualExport.verify(written).artifactID == view.artifactID)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
        .filter { $0.hasPrefix(".glifi-visual-export-") }
    #expect(leftovers.isEmpty)
    await #expect(throws: GlifiStudioFailure.self) {
        _ = try await session.exportVisualization(view, to: destination)
    }

    // Dopo l'importazione di una fonte estranea l'Artifact dichiarato sulle revisioni immutate
    // resta corrente e la vista è ancora esportabile (ADR-0028).
    let extra = root.appending(path: "extra.txt")
    try Data("Una fonte in più.".utf8).write(to: extra)
    _ = try await session.importText(at: extra, format: .plainText)
    let afterImport = try await session.exportVisualization(
        view, to: root.appending(path: "vista-2", directoryHint: .isDirectory))
    #expect(afterImport.manifestDigest.hasPrefix("sha256:"))

    // Una vista che punta a un Artifact non presente nella generazione resta rifiutata.
    var stale = try #require(
        JSONSerialization.jsonObject(with: try JSONEncoder().encode(view)) as? [String: Any])
    stale["artifactID"] = "artifact:sha256:" + String(repeating: "b", count: 64)
    let staleView = try JSONDecoder().decode(
        GlifiStudioVisualization.self,
        from: try JSONSerialization.data(withJSONObject: stale))
    do {
        _ = try await session.exportVisualization(
            staleView, to: root.appending(path: "vista-3", directoryHint: .isDirectory))
        Issue.record("export di un Artifact non corrente accettato")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "visual-export.stale-artifact")
        #expect(failure.category == "staleArtifact")
    }
    await session.close()
}
