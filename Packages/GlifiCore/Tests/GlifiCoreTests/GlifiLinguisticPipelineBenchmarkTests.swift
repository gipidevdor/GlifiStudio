// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import GlifiBenchmarkTestSupport
import Testing

@testable import GlifiCore

@Test("Il benchmark linguistico misura soltanto workload Release espliciti con risultati completi")
func linguisticPipelinePerformanceWorkloads() throws {
    guard ProcessInfo.processInfo.environment["GLIFI_PIPELINE_BENCHMARK_DIRECTORY"] != nil else {
        return
    }
    // Independently checked by the official Snowball generated-JavaScript reference.
    let vocabulary = [
        "divano", "mangiando", "guardandogli", "accomodarci", "crocchi", "crocchio", "l'acqua",
        "quest'anno",
    ]
    let stems = ["divan", "mang", "guard", "accomod", "crocc", "crocc", "acqua", "anno"]
    let words = (0..<32_768).map { vocabulary[$0 % vocabulary.count] }
    let expectedStems = (0..<32_768).map { stems[$0 % stems.count] }
    try measurePipelineOptimization(
        identifier: "linguistic-italian-stemming-32768",
        generator:
            "32,768 synthetic words cycling eight independently checked Snowball 3.1.0 cases",
        fixtureDigest: pipelineBenchmarkDigest(words), expected: expectedStems,
        body: { try words.map { try GlifiItalianStemmer.stem($0) } },
        checksum: { try pipelineBenchmarkDigest($0) })

    let text = String(repeating: "Le ragazze mangiavano mele. ", count: 2_048)
    let availability = try GlifiLinguisticPipeline.availability()
    let cases: [(String, GlifiLinguisticBase, Bool)] =
        [
            ("surface", .normalizedSurface, false), ("snowball", .italianSnowballStem, false),
        ]
        + (availability.hasLemma && availability.hasPartOfSpeech
            ? [("apple-lemma-pos", .appleLemma, true)] : [])
    for (name, base, pos) in cases {
        let expected = try GlifiLinguisticPipeline.annotate(
            text: text, base: base, includePartOfSpeech: pos)
        #expect(expected.tokens.count == 8_192)
        try measurePipelineOptimization(
            identifier: "linguistic-italian-\(name)-8192",
            generator:
                "2,048 repetitions of fixed synthetic Italian text; 8,192 lexical tokens; full pipeline including segmentation, lexical views and metadata",
            fixtureDigest: pipelineBenchmarkDigest(Data(text.utf8)), expected: expected,
            body: {
                try GlifiLinguisticPipeline.annotate(
                    text: text, base: base, includePartOfSpeech: pos)
            },
            checksum: { try pipelineBenchmarkDigest($0) })
    }
}
