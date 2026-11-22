// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiKit
import Testing

@Test("Il manifest dell'export deve concordare con identità, conteggi e caveat della specifica")
func visualExportIntegrityRejectsManifestProvenance() throws {
    let original = try visualExportIntegrityFixture()
    _ = try GlifiStudioVisualExport.verify(original)
    let mutations: [(String, Any)] = [
        ("artifactID", "artifact:unrelated"),
        ("analysisNodeID", "node:unrelated"),
        ("analysisIdentifier", "analysis:unrelated"),
        ("methodIdentifier", "method:unrelated"),
        ("specificationIdentifier", "visual-spec.unrelated.v1"),
        ("totalObservationCount", 999),
        ("visibleObservationCount", 1),
        ("reductionIdentifier", "reduction:unrelated"),
        ("layoutIdentifier", "layout:unrelated"),
        ("caveatKeys", [String]()),
    ]
    for (key, value) in mutations {
        let changed = try visualExportReplacingManifest(original) { $0[key] = value }
        expectVisualExportIntegrityFailure(changed, mutation: key)
    }
}

@Test("L'inventario dell'export rifiuta record duplicati, media type falsi e percorsi alternativi")
func visualExportIntegrityRejectsDuplicateRecords() throws {
    let original = try visualExportIntegrityFixture()
    _ = try GlifiStudioVisualExport.verify(original)
    let manifest = try visualExportJSONObject(
        #require(original[GlifiStudioVisualExport.manifestFileName]))
    let records = try #require(manifest["files"] as? [[String: Any]])
    let first = try #require(records.first)
    let duplicated = try visualExportReplacingManifest(original) {
        $0["files"] = records + [first]
    }
    expectVisualExportIntegrityFailure(duplicated, mutation: "duplicate payload record")
    let mislabeled = try visualExportReplacingManifest(original) {
        $0["files"] = records.map { record in
            var result = record
            result["mediaType"] = "application/octet-stream"
            return result
        }
    }
    expectVisualExportIntegrityFailure(mislabeled, mutation: "incorrect media types")
    let reordered = try visualExportReplacingManifest(original) {
        $0["files"] = Array(records.reversed())
    }
    expectVisualExportIntegrityFailure(reordered, mutation: "noncanonical record order")
    var renamed = original
    renamed["alternate.csv"] = renamed.removeValue(forKey: "view.csv")
    renamed = try visualExportReplacingManifest(renamed) {
        $0["files"] = records.map { record in
            var result = record
            if result["path"] as? String == "view.csv" { result["path"] = "alternate.csv" }
            return result
        }
    }
    expectVisualExportIntegrityFailure(
        renamed, mutation: "alternate payload path with unchanged bytes")
}

@Test("Un CSV alterato resta incoerente anche dopo averne aggiornato dimensione e SHA-256")
func visualExportIntegrityRejectsRehashedCSV() throws {
    let original = try visualExportIntegrityFixture()
    let csvData = try #require(original["view.csv"])
    let csv = try #require(String(data: csvData, encoding: .utf8))
    #expect(csv.contains("1.25"))
    let changed = try visualExportReplacingPayload(
        original, path: "view.csv",
        data: Data(csv.replacingOccurrences(of: "1.25", with: "9.5").utf8))
    expectVisualExportIntegrityFailure(changed, mutation: "changed CSV with matching SHA-256")
}

@Test("Una specifica alterata non può dichiarare la provenienza precedente dopo il rehash")
func visualExportIntegrityRejectsRehashedSpecificationProvenance() throws {
    let original = try visualExportIntegrityFixture()
    for (key, value) in [
        ("artifactID", "artifact:another"), ("analysisNodeID", "node:another"),
        ("analysisIdentifier", "analysis:another"), ("methodIdentifier", "method:another"),
    ] {
        var specification = try visualExportJSONObject(#require(original["view-spec.json"]))
        specification[key] = value
        let changed = try visualExportReplacingPayload(
            original, path: "view-spec.json",
            data: JSONSerialization.data(withJSONObject: specification, options: [.sortedKeys]))
        expectVisualExportIntegrityFailure(changed, mutation: "rehashed specification \(key)")
    }
}

@Test(
    "Specifiche rettangolari, identità uniche e numeri finiti restano necessari con digest coerenti"
)
func visualExportIntegrityRejectsMalformedSpecification() throws {
    let original = try visualExportIntegrityFixture()
    let viewJSON = try visualExportJSONObject(#require(original["view-spec.json"]))
    for mutation in ["short row", "duplicate row", "duplicate column"] {
        var specification = viewJSON
        var table = try #require(specification["table"] as? [String: Any])
        var rows = try #require(table["rows"] as? [[String: Any]])
        var columns = try #require(table["columns"] as? [[String: Any]])
        switch mutation {
        case "short row":
            let cells = try #require(rows[0]["cells"] as? [Any])
            rows[0]["cells"] = Array(cells.dropLast())
        case "duplicate row": rows[1]["id"] = rows[0]["id"]
        case "duplicate column": columns[1]["identifier"] = columns[0]["identifier"]
        default: Issue.record("Unknown malformed fixture")
        }
        table["rows"] = rows
        table["columns"] = columns
        specification["table"] = table
        let bytes = try JSONSerialization.data(
            withJSONObject: specification, options: [.sortedKeys])
        let decoded = try JSONDecoder().decode(GlifiStudioVisualization.self, from: bytes)
        var changed = try visualExportReplacingPayload(
            original, path: "view-spec.json", data: bytes)
        changed = try visualExportReplacingPayload(
            changed, path: "view.csv", data: Data(GlifiStudioVisualizationBuilder.csv(decoded).utf8)
        )
        expectVisualExportIntegrityFailure(changed, mutation: mutation)
    }
    for path in [GlifiStudioVisualExport.manifestFileName, "view-spec.json"] {
        var changed = original
        if path == GlifiStudioVisualExport.manifestFileName {
            changed[path] = Data("{".utf8)
        } else {
            changed = try visualExportReplacingPayload(original, path: path, data: Data("{".utf8))
        }
        expectVisualExportIntegrityFailure(changed, mutation: "malformed JSON \(path)")
    }
    expectVisualExportIntegrityFailure(
        try visualExportReplacingPayload(original, path: "view.csv", data: Data([0xff])),
        mutation: "non-UTF8 CSV with matching digest")
    let factor = try visualExportIntegrityFactorView()
    let factorBundle = try visualExportBundle(factor)
    var nonFinite = try visualExportJSONObject(#require(factorBundle["view-spec.json"]))
    var axes = try #require(nonFinite["axes"] as? [[String: Any]])
    axes[0]["lowerBound"] = "export-non-finite-number"
    nonFinite["axes"] = axes
    let encoded = try JSONSerialization.data(withJSONObject: nonFinite, options: [.sortedKeys])
    let text = try #require(String(data: encoded, encoding: .utf8))
    let changed = try visualExportReplacingPayload(
        factorBundle, path: "view-spec.json",
        data: Data(
            text.replacingOccurrences(of: "\"export-non-finite-number\"", with: "1e999").utf8))
    expectVisualExportIntegrityFailure(changed, mutation: "non-finite axis with matching digest")
}

@Test("Le quattro famiglie dei builder conservano conteggi propri, lineage ed escape CSV")
func visualExportIntegrityPreservesBuilderFamilies() throws {
    let collocationBundle = try visualExportIntegrityFixture()
    let collocation = try JSONDecoder().decode(
        GlifiStudioVisualization.self, from: #require(collocationBundle["view-spec.json"]))
    let factor = try visualExportIntegrityFactorView()
    let dendrogram = try visualExportIntegrityDendrogramView()
    let network = try visualExportIntegrityNetworkView()
    #expect(factor.visibleObservationCount < factor.totalObservationCount)
    #expect(factor.reductionIdentifier == nil)
    #expect(factor.excludedLabels.contains("source:opaque:b"))
    #expect(dendrogram.table.rows.count == 2)
    #expect(dendrogram.visibleObservationCount == 3)
    #expect(network.marks.count > network.table.rows.count)
    #expect(network.marks.contains { $0.lineageClass == .exact })
    #expect(network.marks.allSatisfy { !$0.sourceRevisionIDs.isEmpty })
    let views = [collocation, factor, dendrogram, network]
    #expect(Set(views.map { $0.family.rawValue }).count == 4)
    for view in views {
        let bundle = try visualExportBundle(view)
        let verified = try GlifiStudioVisualExport.verify(bundle)
        let decoded = try JSONDecoder().decode(
            GlifiStudioVisualization.self, from: #require(bundle["view-spec.json"]))
        #expect(decoded == view)
        #expect(verified.artifactID == view.artifactID)
        #expect(verified.visibleObservationCount == view.visibleObservationCount)
        #expect(verified.caveatKeys == view.caveatKeys)
    }
    let csvData = try #require(collocationBundle["view.csv"])
    let csv = try #require(String(data: csvData, encoding: .utf8))
    #expect(csv.contains("\"mare, \"\"calmo\"\"\r\nβ\""))
    #expect(csv.contains("e\u{301}"))
}

@Test("Il contratto v1 accetta identità opache, software storico e JSON equivalente")
func visualExportIntegrityPreservesOpaqueLegacyMetadata() throws {
    let original = try visualExportIntegrityFixture()
    let spec = try JSONSerialization.jsonObject(with: #require(original["view-spec.json"]))
    let formatted = try visualExportReplacingPayload(
        original, path: "view-spec.json",
        data: JSONSerialization.data(withJSONObject: spec, options: [.prettyPrinted, .sortedKeys]))
    for timestamp in [
        "2027-01-15T08:00:00Z", "2027-01-15T08:00:00.125+00:00",
        "2027-01-15t08:00:00.123456789z",
    ] {
        var changed = try visualExportReplacingManifest(formatted) {
            $0["projectID"] = "project:historical-opaque"
            $0["generation"] = 0
            $0["softwareIdentifier"] = "GlifiCore-historical-build"
            $0["createdAt"] = timestamp
        }
        let object = try JSONSerialization.jsonObject(
            with: #require(changed[GlifiStudioVisualExport.manifestFileName]))
        changed[GlifiStudioVisualExport.manifestFileName] = try JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted])
        let verified = try GlifiStudioVisualExport.verify(changed)
        #expect(verified.projectID == "project:historical-opaque")
        #expect(verified.generation == 0)
        #expect(verified.methodIdentifier == "method:opaque")
        #expect(verified.softwareIdentifier == "GlifiCore-historical-build")
        #expect(verified.createdAt == timestamp)
    }
}

private func visualExportIntegrityFixture() throws -> [String: Data] {
    let options = try GlifiStudioWindowCooccurrenceOptions(
        leftSpan: 2, rightSpan: 2, crossesSentences: false, includesSelfPairs: false,
        minimumJointCount: 1, maximumPairCount: 2)
    let optionsJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(options))
    let value: [String: Any] = [
        "lineage": [
            "projectID": "project:opaque", "sourceGeneration": 6, "generation": 7,
            "artifactID": "artifact:opaque", "analysisNodeID": "node:opaque",
        ],
        "analysisIdentifier": "analysis:opaque",
        "tokenizationContractIdentifier": "tokenization:opaque",
        "sourceRevisionIDs": ["source:opaque:first", "source:opaque:second"],
        "contextIdentifier": "window:opaque", "universeIdentifier": "method:opaque",
        "options": optionsJSON, "tokenCount": 20, "universeSize": 20,
        "distinctPairCount": 3, "isTruncated": true,
        "pairs": [
            [
                "nodeTerm": "mare, \"calmo\"\r\nβ", "collocateTerm": "porto",
                "jointCount": 3, "nodeOnlyCount": 4, "collocateOnlyCount": 5, "neitherCount": 8,
                "meanDistance": 1.25, "weightedJointCount": 3,
                "occurrences": [], "occurrencesTruncated": false,
            ],
            [
                "nodeTerm": "e\u{301}", "collocateTerm": "vento",
                "jointCount": 2, "nodeOnlyCount": 4, "collocateOnlyCount": 3, "neitherCount": 11,
                "meanDistance": 2.0, "weightedJointCount": 2,
                "occurrences": [], "occurrencesTruncated": false,
            ],
        ],
    ]
    // Public decoding initializes the DTO; the public builder supplies the valid view.
    let result = try JSONDecoder().decode(
        GlifiStudioWindowCollocationResult.self,
        from: JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]))
    let view = GlifiStudioVisualizationBuilder.collocationTable(result)
    return try GlifiStudioVisualExport.bundle(
        view, projectID: "project:opaque", generation: 7,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000))
}

private func visualExportJSONObject(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func visualExportBundle(_ view: GlifiStudioVisualization) throws -> [String: Data] {
    try GlifiStudioVisualExport.bundle(
        view, projectID: "project:opaque", generation: 7,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000))
}

private func visualExportDecode<Value: Decodable>(
    _ type: Value.Type, object: [String: Any]
) throws -> Value {
    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(
        positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
    return try decoder.decode(
        type, from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
}

private var visualExportLineage: [String: Any] {
    [
        "projectID": "project:opaque", "sourceGeneration": 6, "generation": 7,
        "artifactID": "artifact:opaque", "analysisNodeID": "node:opaque",
    ]
}

private func visualExportIntegrityFactorView() throws -> GlifiStudioVisualization {
    let rowCoordinates: [[Any]] = [[0.25, 0.5], ["Infinity", 0.2]]
    let result = try visualExportDecode(
        GlifiStudioMultivariateResult.self,
        object: [
            "lineage": visualExportLineage, "analysisIdentifier": "analysis:opaque",
            "methodIdentifier": "PCA-SVD-v1", "representationIdentifier": "representation:opaque",
            "sourceRevisionIDs": ["source:opaque:a", "source:opaque:b", "source:opaque:excluded"],
            "terms": ["mare", "excluded-term"], "axisValues": [2.0, 1.0],
            "axisShares": [0.6, 0.4], "rowCoordinates": rowCoordinates,
            "columnCoordinates": [[0.5, -0.25]],
            "excludedSourceRevisionIDs": ["source:opaque:excluded"],
            "excludedTerms": ["excluded-term"],
        ])
    return try #require(try GlifiStudioVisualizationBuilder.factorPlot(result))
}

private func visualExportIntegrityDendrogramView() throws -> GlifiStudioVisualization {
    let result = try visualExportDecode(
        GlifiStudioMultivariateResult.self,
        object: [
            "lineage": visualExportLineage, "analysisIdentifier": "analysis:opaque",
            "methodIdentifier": "HAC-v1", "representationIdentifier": "representation:opaque",
            "sourceRevisionIDs": ["source:opaque:a", "source:opaque:b", "source:opaque:c"],
            "terms": [], "axisValues": [], "axisShares": [], "rowCoordinates": [],
            "columnCoordinates": [], "excludedSourceRevisionIDs": [], "excludedTerms": [],
            "clusterAssignments": [0, 0, 1],
            "merges": [
                ["first": 0, "second": 1, "height": 1.5, "size": 2],
                ["first": 3, "second": 2, "height": 3.0, "size": 3],
            ],
        ])
    return try #require(try GlifiStudioVisualizationBuilder.dendrogram(result))
}

private func visualExportIntegrityNetworkView() throws -> GlifiStudioVisualization {
    let window = try JSONSerialization.jsonObject(
        with: JSONEncoder().encode(GlifiStudioWindowCooccurrenceOptions.standard))
    let nodes: [[String: Any]] = ["mare", "porto"].map { term in
        [
            "term": term, "degree": 1, "weightedDegree": 1.0, "pageRank": 0.5,
            "betweenness": 0.0, "harmonicCloseness": 1.0, "weightedBetweenness": 0.0,
            "weightedHarmonicCloseness": 1.0, "eigenvector": 0.7,
            "weakComponent": 0, "strongComponent": 0, "community": 0,
        ]
    }
    let result = try visualExportDecode(
        GlifiStudioWindowNetworkResult.self,
        object: [
            "lineage": visualExportLineage, "analysisIdentifier": "analysis:opaque",
            "sourceRevisionIDs": ["source:opaque:a"], "graphIdentifier": "method:opaque-network",
            "distanceIdentifier": "hop:opaque", "window": window,
            "usesWeightedJointCount": false, "candidateEdgeCount": 1,
            "summary": [
                "nodeCount": 2, "edgeCount": 1, "weakComponentCount": 1,
                "strongComponentCount": 1, "communityCount": 1, "eigenvectorConverged": true,
            ],
            "nodes": nodes,
            "edges": [
                [
                    "source": "mare", "target": "porto", "weight": 1.0, "jointCount": 1,
                    "supportingSourceRevisionIDs": ["source:opaque:a"],
                    "occurrences": [
                        [
                            "sourceRevisionID": "source:opaque:a", "nodeStart": 0, "nodeEnd": 4,
                            "collocateStart": 5, "collocateEnd": 10, "offset": 1,
                        ]
                    ],
                ]
            ],
        ])
    return GlifiStudioVisualizationBuilder.network(result)
}

private func visualExportReplacingPayload(
    _ files: [String: Data], path: String, data: Data
) throws -> [String: Data] {
    var changed = files
    changed[path] = data
    return try visualExportReplacingManifest(changed) { manifest in
        var records = try #require(manifest["files"] as? [[String: Any]])
        let index = try #require(records.firstIndex { $0["path"] as? String == path })
        records[index]["byteCount"] = data.count
        records[index]["sha256"] =
            "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        manifest["files"] = records
    }
}

private func visualExportReplacingManifest(
    _ files: [String: Data], mutation: (inout [String: Any]) throws -> Void
) throws -> [String: Data] {
    var changed = files
    var manifest = try visualExportJSONObject(
        #require(files[GlifiStudioVisualExport.manifestFileName]))
    try mutation(&manifest)
    changed[GlifiStudioVisualExport.manifestFileName] = try JSONSerialization.data(
        withJSONObject: manifest, options: [.sortedKeys])
    return changed
}

private func expectVisualExportIntegrityFailure(_ files: [String: Data], mutation: String) {
    do {
        _ = try GlifiStudioVisualExport.verify(files)
        Issue.record("Accepted inconsistent visual export: \(mutation)")
    } catch let failure as GlifiStudioFailure {
        #expect(failure.code == "visual-export.integrity-failed")
        #expect(failure.category == "corruption")
        #expect(failure.operation == "export")
        #expect(failure.retryDisposition == "never")
    } catch {
        Issue.record("Unexpected visual export failure for \(mutation): \(error)")
    }
}
