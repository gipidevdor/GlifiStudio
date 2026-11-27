# language: it
# SPDX-License-Identifier: BSD-3-Clause
# Six original documents from GlifiProjectCommandTests, BSD-3-Clause; no external corpus.
# Counts and numerical facts authored independently from the explicit document-term table.

@GS-CMP-332 @GS-CMP-337 @GS-SCN-004 @macos @project-variants
Funzionalità: Ogni operazione di progetto mantiene risultati stato e provenienza
  Le analisi persistite riusano la stessa identità dopo riapertura.
  Letture, preparazione, temporale ed export non inventano una cache analitica.

  @phase-nominal
  Schema dello scenario: La variante nominale conserva valori e risultato persistente
    Data la variante completa di progetto "<variante>" sul corpus originale
    Quando eseguo la variante completa di progetto in fase nominale
    Allora il risultato di progetto rispetta i valori JSON <attese>
    E il progetto conserva letture oppure riusa la stessa analisi anche dopo riapertura

    Esempi:
      | variante | attese |
      | corpus | {"documentCount":6,"lexicalTokenCount":40,"typeCount":4,"terms.0.term":"casa","terms.0.frequency":11} |
      | keyness | {"targetTokenCount":18,"referenceTokenCount":22,"terms.$count":4} |
      | similarity | {"targetTypeCount":4,"referenceTypeCount":4,"sharedTypeCount":4,"jaccardSimilarity":1,"diceSimilarity":1,"cosineSimilarity":0.8412444993533733} |
      | association | {"totalObservations":40,"includedDocumentCount":6,"includedTermCount":4,"degreesOfFreedom":15,"chiSquareStatistic":13.232359307359307} |
      | dispersion | {"unitSizes.$sum":40,"unitSizes.$count":3,"equalSizePartition":false} |
      | groupMetric | {"groups.0.documentCount":2,"groups.0.mean":6,"groups.1.mean":6.5,"groups.2.mean":7.5,"contrasts.0.estimate":-1} |
      | postHoc | {"groupCount":3,"welchFamilySize":3,"mannWhitneyFamilySize":3,"pairs.$count":3} |
      | collocations | {"universeSize":6,"evaluatedPairCount":6,"pairs.0.jointCount":6,"pairs.0.logDice":14} |
      | correlate | {"pairCount":6,"pearson.degreesOfFreedom":4,"pearson.coefficient":-0.6891425936092321} |
      | paired | {"pairCount":6,"degreesOfFreedom":5,"meanDifference":6.37281746031746} |
      | network | {"summary.nodeCount":4,"summary.edgeCount":6,"summary.weakComponentCount":1} |
      | multivariate | {"sourceRevisionIDs.$count":6,"terms.$count":4,"axisValues.$sum":4,"axisShares.$sum":1} |
      | weighting | {"terms.$count":4,"documentFrequencies.$sum":23,"cells.$count":23,"cells.$squaredWeightNorms":[1,1,1,1,1,1]} |
      | diversity | {"pooled.tokenCount":40,"documents.$count":6,"threshold":0.65} |
      | laws | {"tokenCount":40,"typeCount":4,"rankFrequency.0.type":"casa","rankFrequency.0.count":11,"rankFrequency.1.count":11} |
      | summarize | {"consumedBudget":3,"selected.$count":3,"sentences.$count":12} |
      | ngrams | {"n":2,"rows.0.components":["casa","casa"],"rows.0.count":5} |
      | bm25 | {"documentCount":6,"averageLength":6.666666666666667,"ranking.$count":6,"bddFirstSourceLength":5,"bddFirstSourceScore":0.19457927425647964} |
      | windowCollocations | {"tokenCount":40,"options.maximumPositionsPerPair":3,"isTruncated":true} |
      | windowNetwork | {"summary.nodeCount":4,"summary.weakComponentCount":1,"usesWeightedJointCount":true} |
      | sourceText | {"text":"Casa casa mare. Luna sole.","byteCount":26} |
      | passages | {"$count":2,"0.text":"Luna sole.","0.startUTF8":16,"0.endUTF8":26,"1.text":"Casa","1.startUTF8":0,"1.endUTF8":4} |
      | characterCount | {"$value":26} |
      | exportVisualization | {"fileCount":3} |
      | prepareInput | {"lexicalTokenCount":40,"vocabularySize":4,"terms.$count":3,"documents.$count":6} |
      | temporal | {"documents.$count":6,"result.buckets.$count":6,"result.buckets.0.aggregate.tokenCount":5,"result.buckets.0.aggregate.terms.0.term":"casa","result.buckets.0.aggregate.terms.0.frequency":2} |

  @phase-invalid-input
  Schema dello scenario: Ogni variante di progetto in fase JSON-invalido conserva lo stato
    Data la variante completa di progetto "<variante>" sul corpus originale
    Quando eseguo la variante completa di progetto in fase JSON-invalido
    Allora la variante di progetto fallisce con codice "command.unknown-field" e categoria "invalidInput"

    Esempi:
      | variante |
      | association |
      | bm25 |
      | characterCount |
      | collocations |
      | corpus |
      | correlate |
      | dispersion |
      | diversity |
      | exportVisualization |
      | groupMetric |
      | keyness |
      | laws |
      | multivariate |
      | network |
      | ngrams |
      | paired |
      | passages |
      | postHoc |
      | prepareInput |
      | similarity |
      | sourceText |
      | summarize |
      | temporal |
      | weighting |
      | windowCollocations |
      | windowNetwork |

  @phase-pre-cancelled
  Schema dello scenario: Ogni variante di progetto in fase precancellata conserva lo stato
    Data la variante completa di progetto "<variante>" sul corpus originale
    Quando eseguo la variante completa di progetto in fase precancellata
    Allora la variante di progetto fallisce con codice "command.cancelled" e categoria "cancelled"

    Esempi:
      | variante |
      | association |
      | bm25 |
      | characterCount |
      | collocations |
      | corpus |
      | correlate |
      | dispersion |
      | diversity |
      | exportVisualization |
      | groupMetric |
      | keyness |
      | laws |
      | multivariate |
      | network |
      | ngrams |
      | paired |
      | passages |
      | postHoc |
      | prepareInput |
      | similarity |
      | sourceText |
      | summarize |
      | temporal |
      | weighting |
      | windowCollocations |
      | windowNetwork |

  @phase-invalid-input
  Schema dello scenario: I metadati contraddittori non possono pubblicare una vista
    Data la variante completa di progetto "exportVisualization" sul corpus originale
    Quando contraddico il metadato sorgente della vista "<campo>"
    Allora l'export contraddittorio conserva progetto e filesystem

    Esempi:
      | campo |
      | analysisNodeID |
      | analysisIdentifier |
      | methodIdentifier |
