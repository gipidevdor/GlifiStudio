// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing

@testable import GlifiCore

@Test("La similarità di corpus coincide con i valori esatti calcolati indipendentemente")
func corpusSimilarityMatchesIndependentComputation() throws {
    // target={casa:2,mare:1}, reference={casa:1,città:2}: stessa fixture del
    // confronto keyness. Vocabolario unione ordinato [casa,città,mare],
    // vettori di frequenza relativa [2/3,0,1/3] e [1/3,2/3,0]:
    // coseno=(2/9)/(5/9)=2/5=0,4 esatto. Insiemi {casa,mare} e {casa,città}:
    // jaccard=1/3, dice=2·1/(2+2)=0,5 esatti.
    let target = try corpusProfileForSimilarity(
        text: "casa casa mare",
        revision: "00000000-0000-0000-0000-000000000011"
    )
    let reference = try corpusProfileForSimilarity(
        text: "casa città città",
        revision: "00000000-0000-0000-0000-000000000012"
    )

    let comparison = try GlifiCorpusSimilarityAnalyzer().compare(
        target: target,
        reference: reference
    )
    let repeated = try GlifiCorpusSimilarityAnalyzer().compare(
        target: target,
        reference: reference
    )

    #expect(comparison == repeated)
    #expect(comparison.comparisonIdentifier == "corpus-term-similarity-v3")
    #expect(comparison.comparisonDigest.hasPrefix("sha256:"))
    #expect(comparison.targetTypeCount == 2)
    #expect(comparison.referenceTypeCount == 2)
    #expect(comparison.sharedTypeCount == 1)
    #expect(abs(comparison.cosineSimilarity - 0.4) < 1e-9)
    #expect(abs(comparison.jaccardSimilarity - 1.0 / 3.0) < 1e-9)
    #expect(abs(comparison.diceSimilarity - 0.5) < 1e-9)
    // v3: Ruzicka 1/5 e Dice multinsieme 1/3 (valori derivati in GlifiLimitClosureTests).
    #expect(abs(comparison.weightedJaccardSimilarity - 0.2) < 1e-12)
    #expect(abs(comparison.multisetDiceSimilarity - 1.0 / 3.0) < 1e-12)
    #expect(comparison.smoothingAlpha == 0.5)
    #expect(comparison.smoothedKLTargetToReference > 0)
}

@Test("Corpus identici producono similarità massima su ogni misura")
func corpusSimilarityIsMaximalForIdenticalCorpora() throws {
    let profile = try corpusProfileForSimilarity(
        text: "casa mare fiume",
        revision: "00000000-0000-0000-0000-000000000013"
    )

    let comparison = try GlifiCorpusSimilarityAnalyzer().compare(
        target: profile,
        reference: profile
    )

    #expect(abs(comparison.cosineSimilarity - 1) < 1e-9)
    #expect(abs(comparison.jaccardSimilarity - 1) < 1e-9)
    #expect(abs(comparison.diceSimilarity - 1) < 1e-9)
    #expect(comparison.sharedTypeCount == comparison.targetTypeCount)
}

@Test("Un gruppo privo di termini viene rifiutato con failure tipizzata")
func corpusSimilarityRejectsEmptyGroup() throws {
    let target = try corpusProfileForSimilarity(
        text: "casa mare",
        revision: "00000000-0000-0000-0000-000000000014"
    )
    let empty = try corpusProfileForSimilarity(
        text: "",
        revision: "00000000-0000-0000-0000-000000000015"
    )

    do {
        _ = try GlifiCorpusSimilarityAnalyzer().compare(target: target, reference: empty)
        Issue.record("Il gruppo privo di termini non è stato rifiutato")
    } catch let failure as GlifiFailure {
        #expect(failure.code == "corpus-similarity.empty-group")
    }
}

private func corpusProfileForSimilarity(
    text: String,
    revision: String
) throws -> GlifiCorpusAnalysis {
    let imported = try GlifiTextImporter().importText(
        from: Data(text.utf8),
        format: .plainText,
        sourceRevisionID: SourceRevisionID(
            uuid: try #require(UUID(uuidString: revision))
        )
    )
    return try GlifiCorpusAnalyzer().analyze(
        [imported],
        options: try GlifiCorpusAnalysisOptions(
            diversityWindowSize: 2,
            ngramSizes: [],
            maximumDocumentCount: 1,
            maximumSourceByteCount: 1_024,
            maximumVocabularySize: 10,
            maximumDistinctNGramCount: 0,
            maximumNonZeroCellCount: 10
        )
    )
}
