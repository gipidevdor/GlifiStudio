# language: it
# SPDX-License-Identifier: BSD-3-Clause
# Original annotations and arithmetic facts; repository BSD-3-Clause. No external benchmark examples copied.

@GS-CMP-332 @GS-CMP-337 @GS-SCN-003 @macos @evaluation-variants
Funzionalità: Tutte le valutazioni espongono denominatori e risultati controllabili
  Accuratezza, confini, span, frequenze e modelli descrittivi hanno attese indipendenti.

  @phase-nominal
  Schema dello scenario: La valutazione nominale mantiene conteggi e valori attesi
    Data la valutazione completa "<variante>" con annotazioni originali
    Quando eseguo la valutazione completa in fase nominale
    Allora la valutazione completa rispetta i valori JSON <attese>
    E la valutazione completa si ripete identica

    Esempi:
      | variante | attese |
      | classification | {"accuracy.observationCount":5,"accuracy.correctCount":2,"accuracy.accuracy":0.4,"labels":["A","N","V"],"confusionMatrix":[[0,0,0],[0,1,1],[1,1,1]]} |
      | lemmas | {"accuracy.observationCount":2,"accuracy.correctCount":1,"accuracy.accuracy":0.5} |
      | boundaries | {"score.truePositiveCount":1,"score.falsePositiveCount":1,"score.falseNegativeCount":1,"score.f1":0.5,"exactUnitScore.truePositiveCount":1} |
      | boundariesWithText | {"score.truePositiveCount":1,"score.f1":0.5,"exactUnitScore.truePositiveCount":1} |
      | namedEntities | {"score.truePositiveCount":1,"score.f1":1,"exactUnitScore.truePositiveCount":0,"exactUnitScore.f1":0} |
      | namedEntitiesWithText | {"score.truePositiveCount":1,"score.f1":1,"exactUnitScore.truePositiveCount":0,"exactUnitScore.f1":0} |
      | morphology | {"accuracy.observationCount":1,"accuracy.correctCount":0,"accuracy.accuracy":0} |
      | temporal | {"buckets.$count":3,"buckets.1.aggregate.documentCount":1,"buckets.1.aggregate.tokenCount":10,"buckets.1.aggregate.terms.0.frequency":2,"buckets.1.aggregate.terms.0.perThousandTokenRate":200,"missing.documentCount":1} |
      | lexicalObserve | {"documentTokenCounts":[0,4],"tokenCount":4,"typeCount":2,"rankFrequency.0.term":"a","rankFrequency.0.count":3,"growth.1.typeCount":2} |
      | lexicalZipf | {"coefficient":4,"exponent":1,"points.0.observed":4,"points.1.observed":2,"diagnosticOnly":true} |
      | lexicalHeaps | {"coefficient":1,"exponent":0.7924812503605781,"points.0.observed":1,"points.1.observed":3,"diagnosticOnly":true} |
      | lexicalSummary | {"validCount":3,"missingCount":1,"mean":3.3333333333333335,"median":3,"variance":6.333333333333333,"quantiles.0.value":1.4,"quantiles.1.value":5.4} |
      | welchANOVA | {"fStatistic":0,"pValue":1,"numeratorDegreesOfFreedom":2,"denominatorDegreesOfFreedom":4} |

  @phase-invalid-input
  Schema dello scenario: Ogni valutazione in fase JSON-invalido restituisce una failure senza risultato
    Data la valutazione completa "<variante>" con annotazioni originali
    Quando eseguo la valutazione completa in fase JSON-invalido
    Allora la valutazione completa fallisce con codice "command.unknown-field" e categoria "invalidInput"

    Esempi:
      | variante |
      | boundaries |
      | boundariesWithText |
      | classification |
      | lemmas |
      | lexicalHeaps |
      | lexicalObserve |
      | lexicalSummary |
      | lexicalZipf |
      | morphology |
      | namedEntities |
      | namedEntitiesWithText |
      | temporal |
      | welchANOVA |

  @phase-pre-cancelled
  Schema dello scenario: Ogni valutazione in fase precancellata restituisce una failure senza risultato
    Data la valutazione completa "<variante>" con annotazioni originali
    Quando eseguo la valutazione completa in fase precancellata
    Allora la valutazione completa fallisce con codice "operation.cancelled" e categoria "cancelled"

    Esempi:
      | variante |
      | boundaries |
      | boundariesWithText |
      | classification |
      | lemmas |
      | lexicalHeaps |
      | lexicalObserve |
      | lexicalSummary |
      | lexicalZipf |
      | morphology |
      | namedEntities |
      | namedEntitiesWithText |
      | temporal |
      | welchANOVA |

  @phase-invalid-input
  Schema dello scenario: Un confine interno a un carattere UTF8 non diventa una misura
    Data la valutazione completa "<variante>" con annotazioni originali
    Quando eseguo la valutazione completa in fase confine-UTF8-invalido
    Allora la valutazione completa fallisce con codice "evaluation.invalid-source-input" e categoria "invalidInput"

    Esempi:
      | variante |
      | boundariesWithText |
      | namedEntitiesWithText |
