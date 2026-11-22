// SPDX-License-Identifier: BSD-3-Clause

import Accelerate
import Foundation
import GlifiCore

// Called only with --text-operators; no project is opened and no shared cache is mutated.
func textOperatorReport() throws -> Report {
    var generator = GlifiSplitMix64(seed: 27)
    let data = (0..<1_000).map { _ in (0..<64).map { _ in Double(generator.next() % 1_000) / 1_000 }
    }
    var measurements: [Measurement] = []
    var checksum = 0.0
    let scalar = measure {
        checksum = 0
        for _ in 0..<10 {
            for row in data {
                checksum += zip(row, data[0]).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
            }
        }
    }
    measurements.append(
        summary(
            "distance-scalar-10000x64", "GS-MET-001-23", "SplitMix64 seed 27", scalar,
            check: String(checksum)))
    let native = measure {
        checksum = 0
        for _ in 0..<10 { for row in data { checksum += vDSP.distanceSquared(row, data[0]) } }
    }
    measurements.append(
        summary(
            "distance-vDSP-10000x64", "GS-MET-001-23", "same data and checksum", native,
            check: String(checksum)))
    let distances = try GlifiTextMatrixOperators.dissimilarities(
        Array(data.prefix(200)), metric: .euclidean)
    var stress = 0.0
    let mds = try measure {
        stress = try GlifiExploratoryAnalysis.multidimensionalScaling(distances, dimensions: 2)
            .stress
    }
    measurements.append(
        summary(
            "mds-classical-200", "GS-MET-001-23", "200 rows, 64 features", mds,
            check: String(stress)))
    var quantization = 0.0
    let som = try measure {
        quantization = try GlifiExploratoryAnalysis.selfOrganizingMap(
            data, width: 5, height: 5, seed: 27, epochs: 20
        ).quantizationError
    }
    measurements.append(
        summary(
            "som-1000x64-grid25-epochs20", "GS-MET-001-23", "same data", som,
            check: String(quantization)))
    let documents = (0..<1_000).map { _ in (0..<100).map { _ in "t\(generator.next() % 500)" } }
    let labels = documents.indices.map { $0.isMultiple(of: 2) ? "A" : "B" }
    var posterior = 0.0
    let classifier = try measure {
        let model = try GlifiNaiveBayes.train(documents: documents, labels: labels)
        posterior = try GlifiNaiveBayes.predict(documents, using: model)[0].probabilities[0]
    }
    measurements.append(
        summary(
            "naive-bayes-train-and-predict-100000-tokens", "GS-MET-001-23",
            "1000 documents, vocabulary 500", classifier, check: String(posterior)))
    var perplexity = 0.0
    let lda = try measure {
        perplexity = try GlifiLatentDirichletAllocation.fit(
            documents: Array(documents.prefix(100)), topicCount: 10, seed: 27,
            burnIn: 20, sampleCount: 5, thinning: 2
        ).trainingPerplexity
    }
    measurements.append(
        summary(
            "lda-10000-tokens-topics10-sweeps30", "GS-MET-001-23", "same documents", lda,
            check: String(perplexity)))
    return Report(
        device: hardwareModel(),
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        thermalStateAtStart: String(describing: ProcessInfo.processInfo.thermalState),
        configuration: "Release, GlifiBenchmark --text-operators", warmUpRuns: 1, samples: 5,
        statistic: "median, min, max wall-clock seconds",
        threshold: "observed baseline, not a release gate",
        measurements: measurements
    )
}
