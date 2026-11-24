// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiCore

/// Synthetic metadata and linguistic workloads; fixture generation and checksums are untimed.
func metadataOptimizationMeasurements() throws -> [Measurement] {
    var measurements: [Measurement] = []

    let configuration = GlifiTemporalConfiguration(
        basis: .civilDates, granularity: .month,
        origin: try GlifiCivilDate(year: 2000, month: 1, day: 1), bucketWidth: 1,
        bucketCount: 120, missingPolicy: .separate, outsidePolicy: .exclude)
    let vocabulary = (0..<512).map { "term\($0)" }
    var documents: [GlifiTemporalDocument] = []
    documents.reserveCapacity(20_000)
    for index in 0..<20_000 {
        let identity = UUID(
            uuid: (
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                UInt8((index >> 24) & 255), UInt8((index >> 16) & 255),
                UInt8((index >> 8) & 255), UInt8(index & 255)
            ))
        let bucket = index % 120
        let value: GlifiTemporalValue =
            index.isMultiple(of: 37)
            ? .missing
            : (index.isMultiple(of: 101)
                ? .civilMonth(year: 1999, month: 12)
                : .civilMonth(year: 2000 + bucket / 12, month: bucket % 12 + 1))
        let counts = Dictionary(
            uniqueKeysWithValues: (0..<8).map { offset in
                (
                    vocabulary[(index * 13 + offset * 71) % vocabulary.count],
                    1 + (index + offset) % 5
                )
            })
        documents.append(
            GlifiTemporalDocument(
                sourceRevisionID: SourceRevisionID(uuid: identity),
                metadataProvenance: "synthetic.metadata.optimization-v1", value: value,
                tokenCount: 100, termCounts: counts))
    }
    var generator = GlifiSplitMix64(seed: 171)
    for index in stride(from: documents.count - 1, through: 1, by: -1) {
        documents.swapAt(index, generator.index(below: index + 1))
    }
    var temporalInput = MetadataBenchmarkChecksum()
    temporalInput.add(
        "civilDates/month/origin2000-01-01/width1/buckets120/missingSeparate/outsideExclude")
    for document in documents { temporalInput.add(document) }
    var temporal: GlifiTemporalResult?
    let temporalTimes = try measure {
        temporal = try GlifiTemporalAnalysis.aggregate(documents, configuration: configuration)
    }
    var temporalCheck = MetadataBenchmarkChecksum()
    if let temporal {
        for bucket in temporal.buckets { temporalCheck.add(bucket.aggregate) }
        if let missing = temporal.missing { temporalCheck.add(missing) }
        for exclusion in temporal.excluded {
            temporalCheck.add(exclusion.lineage.sourceRevisionID.canonicalValue)
            temporalCheck.add(exclusion.reasonIdentifier)
        }
    }
    measurements.append(
        summary(
            "temporal-civil-months-20000x8", "GS-MET-001-17",
            "20,000 sources; 120 months; vocabulary 512; 8 counts/source; missing/outside; shuffle SplitMix64 seed171; inputFNV=\(temporalInput.description)",
            temporalTimes, check: temporalCheck.description))

    let attributes = ["Case", "Gender", "Number", "Person", "Tense", "VerbForm"]
    var goldPatterns: [[String: String]] = []
    var predictedPatterns: [[String: String]] = []
    for pattern in 0..<128 {
        let gold = Dictionary(
            uniqueKeysWithValues: attributes.enumerated().map {
                ($0.element, "value\((pattern + $0.offset) % 4)")
            })
        var predicted = gold
        if pattern.isMultiple(of: 3) { predicted["Number"] = "wrong" }
        if pattern.isMultiple(of: 5) { predicted.removeValue(forKey: "Person") }
        if pattern.isMultiple(of: 7) { predicted["Aspect"] = "Perf" }
        goldPatterns.append(gold)
        predictedPatterns.append(predicted)
    }
    let morphologyGold = (0..<50_000).map { goldPatterns[$0 % goldPatterns.count] }
    let morphologyPredicted = (0..<50_000).map { predictedPatterns[$0 % predictedPatterns.count] }
    var morphologyInput = MetadataBenchmarkChecksum()
    for index in morphologyGold.indices {
        morphologyInput.add(morphologyGold[index])
        morphologyInput.add(morphologyPredicted[index])
    }
    var morphology: GlifiMorphologyEvaluation?
    let morphologyTimes = try measure {
        morphology = try GlifiLinguisticEvaluation.morphology(
            gold: morphologyGold, predicted: morphologyPredicted)
    }
    var morphologyCheck = MetadataBenchmarkChecksum()
    if let morphology {
        morphologyCheck.add(morphology.exactSets.observationCount)
        morphologyCheck.add(morphology.exactSets.correctCount)
        for attribute in morphology.perAttribute {
            morphologyCheck.add(attribute.label)
            morphologyCheck.add(attribute.support)
            morphologyCheck.add(attribute.score.truePositiveCount)
            morphologyCheck.add(attribute.score.falsePositiveCount)
            morphologyCheck.add(attribute.score.falseNegativeCount)
        }
    }
    measurements.append(
        summary(
            "linguistic-morphology-50000x6", "GS-MET-001-18",
            "50,000 tokens; 128 repeating feature patterns; 6 gold attributes; wrong/missing/extra predictions; inputFNV=\(morphologyInput.description)",
            morphologyTimes, check: morphologyCheck.description))

    let lemmas = (0..<256).map { "lemma\($0)" }
    let forms = (0..<4_096).map { "form\($0)" }
    let partsOfSpeech = (0..<16).map { "pos\($0)" }
    let lemmaGold = (0..<100_000).map { lemmas[$0 % lemmas.count] }
    let lemmaPredicted = (0..<100_000).map {
        lemmas[($0 + ($0.isMultiple(of: 7) ? 1 : 0)) % lemmas.count]
    }
    let lemmaForms = (0..<100_000).map { forms[$0 % forms.count] }
    let lemmaPOS = (0..<100_000).map { partsOfSpeech[$0 % partsOfSpeech.count] }
    var lemmaInput = MetadataBenchmarkChecksum()
    for index in lemmaGold.indices {
        lemmaInput.add(lemmaGold[index])
        lemmaInput.add(lemmaPredicted[index])
        lemmaInput.add(lemmaForms[index])
        lemmaInput.add(lemmaPOS[index])
    }
    var lemma: GlifiLemmaEvaluation?
    let lemmaTimes = try measure {
        lemma = try GlifiLinguisticEvaluation.lemmaAnalysis(
            gold: lemmaGold, predicted: lemmaPredicted, forms: lemmaForms, partsOfSpeech: lemmaPOS)
    }
    var lemmaCheck = MetadataBenchmarkChecksum()
    if let lemma {
        lemmaCheck.add(lemma.accuracy.observationCount)
        lemmaCheck.add(lemma.accuracy.correctCount)
        for group in lemma.errorsByForm + lemma.errorsByPartOfSpeech {
            lemmaCheck.add(group.label)
            lemmaCheck.add(group.observationCount)
            lemmaCheck.add(group.errorCount)
        }
    }
    measurements.append(
        summary(
            "linguistic-lemma-stratified-100000", "GS-MET-001-18",
            "100,000 tokens; lemma256/form4096/POS16; every seventh prediction wrong; inputFNV=\(lemmaInput.description)",
            lemmaTimes, check: lemmaCheck.description))
    return measurements
}

private struct MetadataBenchmarkChecksum {
    private var value: UInt64 = 14_695_981_039_346_656_037

    var description: String { String(value, radix: 16) }

    mutating func add(_ number: Int) {
        value = (value ^ UInt64(number)) &* 1_099_511_628_211
    }

    mutating func add(_ text: String) {
        for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 1_099_511_628_211 }
        add(text.utf8.count)
    }

    mutating func add(_ features: [String: String]) {
        add(features.count)
        for attribute in features.keys.sorted() {
            add(attribute)
            add(features[attribute] ?? "")
        }
    }

    mutating func add(_ document: GlifiTemporalDocument) {
        add(document.sourceRevisionID.canonicalValue)
        add(document.metadataProvenance)
        add(document.tokenCount)
        add(document.termCounts.count)
        for term in document.termCounts.keys.sorted() {
            add(term)
            add(document.termCounts[term] ?? 0)
        }
        switch document.value {
        case .instant(let date):
            add("instant")
            value = (value ^ date.timeIntervalSinceReferenceDate.bitPattern) &* 1_099_511_628_211
        case .civilDate(let date):
            add("civilDate")
            add(date.year)
            add(date.month)
            add(date.day)
        case .civilMonth(let year, let month):
            add("civilMonth")
            add(year)
            add(month)
        case .civilYear(let year):
            add("civilYear")
            add(year)
        case .interval(let start, let end):
            add("interval")
            value = (value ^ start.timeIntervalSinceReferenceDate.bitPattern) &* 1_099_511_628_211
            value = (value ^ end.timeIntervalSinceReferenceDate.bitPattern) &* 1_099_511_628_211
        case .uncertainPeriod(let lower, let upper):
            add("uncertainPeriod")
            for date in [lower, upper] {
                add(date.year)
                add(date.month)
                add(date.day)
            }
        case .missing:
            add("missing")
        }
    }

    mutating func add(_ aggregate: GlifiTemporalAggregate) {
        add(aggregate.documentCount)
        add(aggregate.tokenCount)
        for term in aggregate.terms {
            add(term.term)
            add(term.frequency)
            add(term.documentFrequency)
            if let rate = term.perThousandTokenRate {
                value = (value ^ rate.bitPattern) &* 1_099_511_628_211
            } else {
                add(0)
            }
            for revision in term.sourceRevisionIDs { add(revision.canonicalValue) }
        }
        for lineage in aggregate.lineage {
            add(lineage.sourceRevisionID.canonicalValue)
            add(lineage.metadataProvenance)
        }
    }
}
