// SPDX-License-Identifier: BSD-3-Clause

import Testing

@testable import GlifiCore

@Test("La tassonomia di GS-API-001 § 8 copre ogni categoria e i default sono ammessi")
func failureTaxonomyIsCompleteAndSelfConsistent() {
    let states: [GlifiRetainedState] = [
        .unchanged, .lastCommittedGeneration, .validatedCheckpoint, .readOnlyRecovery,
        .validityUnknown,
    ]
    for category in GlifiFailureCategory.allCases {
        #expect(!(GlifiFailureTaxonomy.retry[category] ?? []).isEmpty)
        #expect(!(GlifiFailureTaxonomy.retained[category] ?? []).isEmpty)
        for preferred in states {
            #expect(
                GlifiFailureTaxonomy.admits(
                    category: category,
                    retry: GlifiFailureTaxonomy.defaultRetry(category),
                    retained: GlifiFailureTaxonomy.defaultRetained(category, preferred: preferred)
                ))
        }
    }
    // Righe normative: esempi puntuali della tabella.
    #expect(GlifiFailureTaxonomy.defaultRetry(.insufficientResources) == .afterConditionsChange)
    #expect(GlifiFailureTaxonomy.defaultRetained(.invariantViolation) == .validityUnknown)
    #expect(GlifiFailureTaxonomy.defaultRetry(.transientIO) == .transientBackoff)
    #expect(
        !GlifiFailureTaxonomy.admits(
            category: .invariantViolation, retry: .never, retained: .unchanged))
}

@Test("Gli helper di failure parametrici restano nella tassonomia per ogni categoria")
func failureHelpersRespectTaxonomyForEveryCategory() {
    for category in GlifiFailureCategory.allCases {
        let failures = [
            derivedAnalysisFailure("test.helper", category: category),
            analysisFailure("test.helper", category: category),
            keynessFailure("test.helper", category: category),
            networkFailure("test.helper", category: category),
            agreementFailure("test.helper", category: category),
            contingencyFailure("test.helper", category: category),
            collocationFailure("test.helper", category: category),
            dispersionFailure("test.helper", category: category),
            linearAlgebraFailure("test.helper", category: category),
            corpusSimilarityFailure("test.helper", category: category),
            similarityFailure("test.helper", category: category),
        ]
        for failure in failures {
            #expect(
                GlifiFailureTaxonomy.admits(
                    category: failure.category, retry: failure.retryDisposition,
                    retained: failure.retainedState))
            #expect(failure.messageKey == "failure.test.helper")
        }
    }
}
