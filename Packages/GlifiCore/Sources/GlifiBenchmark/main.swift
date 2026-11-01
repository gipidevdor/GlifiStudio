// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

// Benchmark di scala riproducibile (Benchmarks/README.md): dati generati da SplitMix64 con seed
// dichiarati, un warm-up, cinque campioni, mediana e intervallo; soglie non ancora fissate
// (da confermare in G4, ADR-0024). Eseguire con `swift run -c release GlifiBenchmark`.

struct Measurement: Encodable {
    let identifier: String
    let requirement: String
    let generator: String
    let medianSeconds: Double
    let minimumSeconds: Double
    let maximumSeconds: Double
    let check: String
}

struct Report: Encodable {
    let device: String
    let operatingSystem: String
    let thermalStateAtStart: String
    let configuration: String
    let warmUpRuns: Int
    let samples: Int
    let statistic: String
    let threshold: String
    let measurements: [Measurement]
}

func hardwareModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var buffer = [CChar](repeating: 0, count: max(size, 1))
    sysctlbyname("hw.model", &buffer, &size, nil, 0)
    return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

func measure(_ body: () throws -> Void) rethrows -> [Double] {
    try body()
    return try (0..<5).map { _ in
        let start = DispatchTime.now().uptimeNanoseconds
        try body()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
    }
}

func summary(
    _ identifier: String,
    _ requirement: String,
    _ generator: String,
    _ times: [Double],
    check: String
) -> Measurement {
    let sorted = times.sorted()
    return Measurement(
        identifier: identifier,
        requirement: requirement,
        generator: generator,
        medianSeconds: sorted[sorted.count / 2],
        minimumSeconds: sorted.first ?? 0,
        maximumSeconds: sorted.last ?? 0,
        check: check
    )
}

func uniform(_ generator: inout GlifiSplitMix64) -> Double {
    Double(generator.next() >> 11) / Double(1 << 53)
}

if CommandLine.arguments.contains("--text-operators") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(textOperatorReport()) + Data("\n".utf8))
    exit(0)
}

let thermal: String = {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: "nominal"
    case .fair: "fair"
    case .serious: "serious"
    case .critical: "critical"
    @unknown default: "unknown"
    }
}()

// 1. SVD troncata su 2 000 × 2 500 (5 milioni di celle, 1 % non nulle).
var matrixGenerator = GlifiSplitMix64(seed: 1)
var matrix = [[Double]](repeating: [Double](repeating: 0, count: 2_500), count: 2_000)
for _ in 0..<50_000 {
    matrix[matrixGenerator.index(below: 2_000)][matrixGenerator.index(below: 2_500)] =
        Double(matrixGenerator.index(below: 9) + 1)
}
var decomposition: GlifiSingularValueDecomposition?
let svdTimes = try measure {
    decomposition = try GlifiLinearAlgebra.truncatedSingularValueDecomposition(matrix, rank: 10)
}
var residual = 0.0
if let decomposition {
    for row in 0..<2_000 {
        var image = 0.0
        for column in 0..<2_500 where matrix[row][column] != 0 {
            image += matrix[row][column] * decomposition.v[column][0]
        }
        residual += pow(image - decomposition.singularValues[0] * decomposition.u[row][0], 2)
    }
}

// 2. Cammini pesati su 2 000 nodi e 8 000 archi non orientati.
var graphGenerator = GlifiSplitMix64(seed: 2)
var edges: [GlifiGraphEdge<Int>] = []
for _ in 0..<8_000 {
    let source = graphGenerator.index(below: 2_000)
    let target = graphGenerator.index(below: 2_000)
    let weight = 0.1 + 4.9 * uniform(&graphGenerator)
    edges.append(GlifiGraphEdge(source: source, target: target, weight: weight))
    edges.append(GlifiGraphEdge(source: target, target: source, weight: weight))
}
let graph = try GlifiDirectedGraph(nodes: Array(0..<2_000), edges: edges)
var betweennessTotal = 0.0
let pathTimes = measure {
    betweennessTotal = GlifiNetworkAnalysis.weightedBetweenness(graph).scores.values.reduce(0, +)
}

// 3. Louvain su 20 000 nodi e 80 000 archi.
var communityGenerator = GlifiSplitMix64(seed: 3)
var communityEdges: [GlifiGraphEdge<Int>] = []
for _ in 0..<80_000 {
    let source = communityGenerator.index(below: 20_000)
    // Archi locali (blocchi da 200 nodi) con probabilità 0,9: struttura di comunità nota.
    let target =
        uniform(&communityGenerator) < 0.9
        ? source / 200 * 200 + communityGenerator.index(below: 200)
        : communityGenerator.index(below: 20_000)
    communityEdges.append(GlifiGraphEdge(source: source, target: target))
    communityEdges.append(GlifiGraphEdge(source: target, target: source))
}
let communityGraph = try GlifiDirectedGraph(nodes: Array(0..<20_000), edges: communityEdges)
var modularity = 0.0
let louvainTimes = try measure {
    modularity = try GlifiNetworkAnalysis.louvain(communityGraph).modularity
}

// 4. Riuso selettivo dopo l'importazione di una fonte estranea (ADR-0028).
// Una misura di prodotto, non di algoritmo: confronta il costo dell'analisi a freddo con quello
// della stessa analisi ripetuta dopo che è arrivata una fonte che non la riguarda.
func selectiveReuseMeasurement() async throws -> (
    coldSeconds: Double, reuseTimes: [Double], check: String
) {
    let root = FileManager.default.temporaryDirectory.appending(
        path: "GlifiReuseBenchmark-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }

    // Corpus sintetico: 40 documenti di 400 forme da un vocabolario di 200, seed dichiarato.
    var generator = GlifiSplitMix64(seed: 4)
    let vocabulary = (0..<200).map { "forma\($0)" }
    func document() -> Data {
        var words: [String] = []
        for _ in 0..<400 { words.append(vocabulary[generator.index(below: vocabulary.count)]) }
        return Data(words.joined(separator: " ").utf8)
    }
    let project = try GlifiProjectPackage.create(
        at: root.appending(path: "Scala.glifi", directoryHint: .isDirectory))
    let importer = GlifiTextImporter()
    var revisions: [SourceRevisionID] = []
    for _ in 0..<40 {
        let snapshot = try await project.importText(
            try importer.importText(from: document(), format: .plainText))
        let known = Set(revisions)
        if let added = snapshot.sources.map(\.sourceRevisionID).first(where: { !known.contains($0) }
        ) {
            revisions.append(added)
        }
    }
    let group = Array(revisions.prefix(20))
    let engine = GlifiEngine()

    let coldStart = ContinuousClock.now
    let cold = try await engine.analyzeAssociation(in: project, sourceRevisionIDs: group)
    let coldSeconds =
        Double(
            (ContinuousClock.now - coldStart).components.attoseconds) / 1e18
        + Double((ContinuousClock.now - coldStart).components.seconds)

    var reuseTimes: [Double] = []
    var identical = true
    var retained = 0
    for index in 0..<6 {
        // Ogni campione importa una fonte estranea al gruppo e ripete la stessa analisi.
        let afterImport = try await project.importText(
            try importer.importText(from: document(), format: .plainText))
        retained = afterImport.artifacts.count
        let start = ContinuousClock.now
        let repeated = try await engine.analyzeAssociation(in: project, sourceRevisionIDs: group)
        let elapsed = ContinuousClock.now - start
        identical = identical && repeated.artifactID == cold.artifactID
        // Il primo giro è di riscaldamento, come per le altre misure.
        if index > 0 {
            reuseTimes.append(
                Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        }
    }
    let ratio = reuseTimes.isEmpty ? 0 : coldSeconds / (reuseTimes.sorted()[reuseTimes.count / 2])
    return (
        coldSeconds, reuseTimes.sorted(),
        "stesso Artifact riusato: \(identical); Artifact conservati dopo l'importazione: "
            + "\(retained); rapporto freddo/riuso: \(ratio)"
    )
}

let reuse = try await selectiveReuseMeasurement()

let report = Report(
    device: hardwareModel(),
    operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
    thermalStateAtStart: thermal,
    configuration: "swift run -c release GlifiBenchmark",
    warmUpRuns: 1,
    samples: 5,
    statistic: "median, min, max wall-clock seconds",
    threshold: "none: observed baseline, to be confirmed in G4 (ADR-0024)",
    measurements: [
        summary(
            "svd-subspace-iteration-2000x2500-rank10",
            "RF-038, GS-MET-001-15",
            "SplitMix64 seed 1, 50 000 draws of counts 1…9",
            svdTimes,
            check:
                "residual ||Av1 - s1 u1|| / s1 = \((residual.squareRoot()) / (decomposition?.singularValues[0] ?? 1))"
        ),
        summary(
            "weighted-betweenness-2000-nodes-8000-edges",
            "RF-039, GS-MET-001-16",
            "SplitMix64 seed 2, weights uniform in [0.1, 5]",
            pathTimes,
            check: "sum of betweenness = \(betweennessTotal)"
        ),
        summary(
            "louvain-20000-nodes-80000-edges",
            "RF-039, GS-MET-001-16",
            "SplitMix64 seed 3, blocks of 200 nodes with 0.9 local edges",
            louvainTimes,
            check: "modularity = \(modularity)"
        ),
        summary(
            "selective-reuse-after-unrelated-import",
            "RF-011, GS-MET-001-02, ADR-0028",
            "SplitMix64 seed 4, 40 documenti di 400 forme su vocabolario 200, gruppo di 20",
            reuse.reuseTimes,
            check: "analisi a freddo \(reuse.coldSeconds) s; " + reuse.check
        ),
    ]
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
// Output strutturato: solo il documento JSON su standard output.
FileHandle.standardOutput.write(try encoder.encode(report) + Data("\n".utf8))
