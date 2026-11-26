// SPDX-License-Identifier: BSD-3-Clause

import CryptoKit
import Foundation
import GlifiCore

struct DistributionBenchmarkReport: Encodable {
    let device: String
    let operatingSystem: String
    let physicalMemoryBytes: UInt64
    let thermalStateAtStart: String
    let thermalStateAtEnd: String
    let lowPowerModeAtStart: Bool
    let lowPowerModeAtEnd: Bool
    let executableSHA256: String
    let harnessSHA256: String
    let configuration: String
    let warmUpRuns: Int
    let samples: Int
    let cachePolicy: String
    let measurements: [DistributionBenchmarkMeasurement]
}

struct DistributionBenchmarkMeasurement: Encodable {
    let identifier: String
    let callsPerSample: Int
    let inputSHA256: String
    let outputSHA256: String
    let outputBitPatterns: [String]
    let medianSecondsPerCall: Double
    let minimumSecondsPerCall: Double
    let maximumSecondsPerCall: Double
    let rawSamplesSecondsPerCall: [Double]
    let validation: String
}

private struct DistributionArguments: Encodable {
    let value: Double
    let firstDegrees: Double
    let secondDegrees: Double
}

private struct AssociationSignature: Encodable {
    let statistic: Double
    let degreesOfFreedom: Int
    let pValue: Double
    let cramersV: Double
    let residuals: [[Double?]]
    let excludedRows: [Int]
    let excludedColumns: [Int]

    init(_ value: GlifiContingencyAssociation) {
        statistic = value.chiSquareStatistic
        degreesOfFreedom = value.degreesOfFreedom
        pValue = value.pValue
        cramersV = value.cramersV
        residuals = value.standardizedResiduals
        excludedRows = value.excludedRowIndices
        excludedColumns = value.excludedColumnIndices
    }
}

private enum DistributionBenchmarkFailure: Error {
    case emptyInput, inconsistentResult, sourcesChanged
}

/// Runs only public production APIs; binary provenance is paired with an external build manifest.
func distributionBenchmarkReport() throws -> DistributionBenchmarkReport {
    let harness = URL(filePath: #filePath)
    let harnessHash = try distributionDataDigest(Data(contentsOf: harness))
    let executable = URL(filePath: CommandLine.arguments[0]).standardizedFileURL
    let binaryHash = try distributionDataDigest(Data(contentsOf: executable))
    let thermal = String(describing: ProcessInfo.processInfo.thermalState)
    let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var measurements: [DistributionBenchmarkMeasurement] = []
    let ordinary = [0.001, 0.025, 0.1, 0.5.nextDown, 0.5, 0.5.nextUp, 0.9, 0.975, 0.999]
    let extreme = [
        Double.leastNonzeroMagnitude, Double.leastNormalMagnitude, 1e-300, 1e-100, 1e-16,
        1.0.nextDown,
    ]
    for (identifier, probabilities) in [("normal-ordinary", ordinary), ("normal-extreme", extreme)]
    {
        let expected = try probabilities.map(GlifiDistributionFunctions.normalQuantile)
        measurements.append(
            try distributionMeasure(
                identifier, input: probabilities, expected: expected, repeats: 4_096,
                output: { try distributionDigest($0) }, bits: expected.map(distributionBits)
            ) { try GlifiDistributionFunctions.normalQuantile(probabilities[$0]) })
    }
    let tInputs = [0.001, 0.2, 1.0, 3, 10, 100, 1e100].flatMap { statistic in
        [0.5, 1.0, 7, 40, 1_000].map {
            DistributionArguments(value: statistic, firstDegrees: $0, secondDegrees: 0)
        }
    }
    func tValue(_ index: Int) throws -> Double {
        try GlifiStatisticalFoundation.tDistributionPValue(
            statistic: tInputs[index].value, degreesOfFreedom: tInputs[index].firstDegrees,
            alternative: .twoSided)
    }
    let tExpected = try tInputs.indices.map(tValue)
    measurements.append(
        try distributionMeasure(
            "t-upper-tail", input: tInputs, expected: tExpected, repeats: 1_024,
            output: { try distributionDigest($0) }, bits: tExpected.map(distributionBits),
            body: tValue))
    let fInputs = [0.001, 0.2, 1.0, 3, 10, 100].flatMap { statistic in
        [0.5, 1.0, 7, 40, 1_000].map {
            DistributionArguments(value: statistic, firstDegrees: $0, secondDegrees: 13)
        }
    }
    func fValue(_ index: Int) throws -> Double {
        try GlifiStatisticalFoundation.fDistributionUpperTailPValue(
            statistic: fInputs[index].value,
            numeratorDegreesOfFreedom: fInputs[index].firstDegrees,
            denominatorDegreesOfFreedom: fInputs[index].secondDegrees)
    }
    let fExpected = try fInputs.indices.map(fValue)
    measurements.append(
        try distributionMeasure(
            "f-upper-tail", input: fInputs, expected: fExpected, repeats: 1_024,
            output: { try distributionDigest($0) }, bits: fExpected.map(distributionBits),
            body: fValue))
    let quantiles = [0.025, 0.5, 0.975].flatMap { probability in
        [1.0, 7, 40, 1_000].map {
            DistributionArguments(value: probability, firstDegrees: $0, secondDegrees: 0)
        }
    }
    func tQuantile(_ index: Int) throws -> Double {
        try GlifiStatisticalFoundation.tQuantile(
            quantiles[index].value, degreesOfFreedom: quantiles[index].firstDegrees)
    }
    let quantileExpected = try quantiles.indices.map(tQuantile)
    measurements.append(
        try distributionMeasure(
            "t-quantile", input: quantiles, expected: quantileExpected, repeats: 128,
            output: { try distributionDigest($0) }, bits: quantileExpected.map(distributionBits),
            body: tQuantile))
    let counts = [
        [[12, 8], [7, 13]],
        (0..<4).map { row in (0..<4).map { column in 5 + (row * 7 + column * 3) % 19 } },
        (0..<12).map { row in (0..<12).map { column in 5 + (row * 17 + column * 11) % 31 } },
    ]
    let tables = try counts.map { cells in
        try GlifiContingencyTable(
            rowLabels: cells.indices.map { "r\($0)" },
            columnLabels: cells[0].indices.map { "c\($0)" },
            cells: cells)
    }
    let associationExpected = try tables.map(GlifiContingencyAnalysis.associate)
    measurements.append(
        try distributionMeasure(
            "contingency-association", input: counts, expected: associationExpected, repeats: 2_048,
            output: { try distributionDigest($0.map(AssociationSignature.init)) }, bits: []
        ) { try GlifiContingencyAnalysis.associate(tables[$0]) })
    for vocabularySize in [512, 4_096] {
        let target = try distributionCorpus(vocabularySize, reference: false)
        let reference = try distributionCorpus(vocabularySize, reference: true)
        let analyzer = GlifiKeynessAnalyzer()
        let expected = try analyzer.compare(target: target, reference: reference)
        guard expected.terms.count == vocabularySize else {
            throw DistributionBenchmarkFailure.inconsistentResult
        }
        measurements.append(
            try distributionMeasure(
                "keyness-\(vocabularySize)-terms",
                input: [target.corpusDigest, reference.corpusDigest],
                expected: [expected], repeats: vocabularySize == 512 ? 8 : 2,
                output: { try distributionDigest($0) }, bits: []
            ) { _ in try analyzer.compare(target: target, reference: reference) })
    }
    guard try distributionDataDigest(Data(contentsOf: harness)) == harnessHash,
        try distributionDataDigest(Data(contentsOf: executable)) == binaryHash
    else { throw DistributionBenchmarkFailure.sourcesChanged }
    return DistributionBenchmarkReport(
        device: hardwareModel(),
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        thermalStateAtStart: thermal,
        thermalStateAtEnd: String(describing: ProcessInfo.processInfo.thermalState),
        lowPowerModeAtStart: lowPower,
        lowPowerModeAtEnd: ProcessInfo.processInfo.isLowPowerModeEnabled,
        executableSHA256: binaryHash, harnessSHA256: harnessHash,
        configuration: "Release, GlifiBenchmark --distribution-performance",
        warmUpRuns: 1, samples: 7,
        cachePolicy:
            "warm process; input preparation and complete equality checks outside timer; binary/source build manifest supplied by runner",
        measurements: measurements)
}

private func distributionMeasure<Input: Encodable, Value: Equatable>(
    _ identifier: String, input: Input, expected: [Value], repeats: Int,
    output: ([Value]) throws -> String, bits: [String], body: (Int) throws -> Value
) throws -> DistributionBenchmarkMeasurement {
    guard let first = expected.first else { throw DistributionBenchmarkFailure.emptyInput }
    let count = expected.count * repeats
    var observed = [Value](repeating: first, count: count)
    var samples: [Double] = []
    for pass in 0..<8 {
        let start = DispatchTime.now().uptimeNanoseconds
        for repetition in 0..<repeats {
            for index in expected.indices {
                observed[repetition * expected.count + index] = try body(index)
            }
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9 / Double(count)
        for index in observed.indices {
            guard observed[index] == expected[index % expected.count] else {
                throw DistributionBenchmarkFailure.inconsistentResult
            }
        }
        if pass > 0 { samples.append(elapsed) }
    }
    let sorted = samples.sorted()
    return DistributionBenchmarkMeasurement(
        identifier: identifier, callsPerSample: count,
        inputSHA256: try distributionDigest(input), outputSHA256: try output(expected),
        outputBitPatterns: bits, medianSecondsPerCall: sorted[sorted.count / 2],
        minimumSecondsPerCall: sorted[0], maximumSecondsPerCall: sorted[sorted.count - 1],
        rawSamplesSecondsPerCall: samples,
        validation:
            "every returned value compared completely with the untimed reference; all eight batches checked"
    )
}

private func distributionCorpus(_ vocabularySize: Int, reference: Bool) throws
    -> GlifiCorpusAnalysis
{
    let text = (0..<vocabularySize).flatMap { index -> [String] in
        var number = index
        var letters = [UInt8]("term".utf8)
        for _ in 0..<4 {
            letters.append(97 + UInt8(number % 26))
            number /= 26
        }
        let term = String(decoding: letters, as: UTF8.self)
        let frequency = 10 + (reference ? index * 7 + 3 : index * 3 + 1) % 11
        return [String](repeating: term, count: frequency)
    }.joined(separator: " ")
    let revision = try SourceRevisionID(
        canonicalValue: reference
            ? "source-revision:00000000-0000-0000-0000-000000000902"
            : "source-revision:00000000-0000-0000-0000-000000000901")
    let imported = try GlifiTextImporter().importText(
        from: Data(text.utf8), format: .plainText, sourceRevisionID: revision)
    let options = try GlifiCorpusAnalysisOptions(
        diversityWindowSize: 32, ngramSizes: [], maximumDocumentCount: 1,
        maximumSourceByteCount: 2_000_000, maximumVocabularySize: vocabularySize,
        maximumDistinctNGramCount: 0, maximumNonZeroCellCount: vocabularySize)
    return try GlifiCorpusAnalyzer().analyze([imported], options: options)
}

private func distributionDigest<Value: Encodable>(_ value: Value) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return distributionDataDigest(try encoder.encode(value))
}

private func distributionDataDigest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func distributionBits(_ value: Double) -> String {
    String(value.bitPattern, radix: 16)
}
