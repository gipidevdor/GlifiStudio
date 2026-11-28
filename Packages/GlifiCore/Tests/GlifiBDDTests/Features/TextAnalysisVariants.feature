# language: it
# SPDX-License-Identifier: BSD-3-Clause
# Synthetic requests: Fixtures/TextAnalysis/v1/cases.json (BSD-3-Clause); expected facts authored here.
# All 63 reviewed cases run unchanged; five additional constant/two-point inputs are original.

@GS-CMP-332 @GS-CMP-337 @GS-SCN-006 @macos @text-variants
Funzionalità: Tutte le varianti di analisi testuale conservano valori e failure espliciti
  Le attese sono conteggi, probabilità, geometrie o fatti matematici indipendenti.

  @phase-nominal
  Schema dello scenario: La variante testuale nominale rispetta il proprio oracolo
    Data la variante testuale "<variante>" usa la fixture originale "<fixture>"
    Quando eseguo la variante testuale in fase nominale
    Allora il risultato testuale rispetta i valori JSON <attese>
    E gli invarianti quantitativi testuali coincidono con gli input
    E la variante testuale si ripete senza cambiare il risultato

    Esempi:
      | variante | fixture | attese |
      | mds | mds-classical | {"result.coordinates.$count":3,"result.coordinates.0.$count":1,"result.stress":0} |
      | mds | mds-metric | {"result.coordinates.$centroid":[0],"result.stress":0} |
      | mds | mds-kruskal | {"result.coordinates.$centroid":[0],"result.stress":0} |
      | mds | mds-sammon | {"result.coordinates.$centroid":[0],"result.stress":0} |
      | som | som | {"result.width":1,"result.height":1,"result.assignments":[0,0],"result.topographicError":0} |
      | clara | clara | {"result.medoids.$count":2,"result.assignments.$count":4,"result.objective":2} |
      | classify | classify | {"result.labels":["A","A"],"result.probabilities":[[0.6666666666666666,0.3333333333333333],[0.5,0.5]],"result.ignoredTokenCounts":[0,1]} |
      | validate-classifier | validate-classifier | {"result.accuracy":1,"result.confusion":[[2,0],[0,2]],"result.foldAssignments.$count":4} |
      | lda | lda | {"result.documentTopics":[[1],[1]],"result.topicTerms":[[0.5,0.5]],"result.trainingPerplexity":2} |
      | coding | coding | {"result.values":[[1],[0]],"result.frequencies":[1],"result.evidence.0.0.0.start":0,"result.evidence.0.0.0.end":4} |
      | code-crosstab | code-crosstab | {"result.groups":["x"],"result.counts":[[1]],"result.sizes":[1],"result.missingCount":1} |
      | dissimilarities | dissimilarities | {"result":[[0,1],[1,0]],"methodIdentifier":"Text-distance-cosine-v1"} |
      | correspondence | correspondence | {"result.includedRows":[0,1],"result.rowMasses":[0.5,0.5],"result.totalInertia":0.36} |
      | hierarchical | hierarchical | {"result.linkage":"average","result.heights":[1,2.5],"result.sizes":[2,3]} |
      | network | network | {"result.nodes":["a","b"],"result.endpoints":[[0,1]],"result.weights":[0.5]} |
      | communities | community-edgeBetweenness | {"result.communityCount":1,"result.modularity":0,"result.membership":[0,0,0]} |
      | communities | community-fastGreedy | {"result.nodes":["A","B","C"],"result.communityCount":1,"result.modularity":0} |
      | communities | community-walktrap | {"result.communityCount":1,"result.modularity":0,"result.membership":[0,0,0]} |
      | graph-layout | layout-fruchtermanReingold | {"result.positions.$insideUnitSquare":true,"result.nodes":["A","B","C"],"methodIdentifier":"FruchtermanReingold-unweighted-square-v1"} |
      | graph-layout | layout-kamadaKawai | {"result.nodes":["A","B","C"],"result.positions.$centroid":[0,0],"result.seed":7} |
      | minimum-spanning-forest | prim-forest | {"result.edges.$count":2,"result.componentCount":1,"result.totalWeight":3} |
      | dissimilarities | distance-simpson | {"result":[[0,0],[0,0]],"methodIdentifier":"Text-distance-simpson-v1"} |
      | mds | mds-ordinal | {"result.coordinates.$centroid":[0],"methodIdentifier":"MDS-ordinal-SMACOF-secondary-ties-normalized-raw-stress-v1"} |
      | mds-search | mds-search | {"result.runs.$count":3,"result.runs.0.coordinates.$centroid":[0],"result.runs.0.seed":7,"result.runs.1.seed":8,"result.runs.2.seed":9} |
      | som-advanced | som-hexagonal | {"result.topology":"hexagonal","result.map.width":2,"result.map.height":2,"result.codebookClustering.assignments.$distinctCount":2} |
      | lda-selection | lda-selection | {"result.candidates.$count":2,"result.candidates.0.topicCount":1,"result.candidates.0.trainingPerplexity":2,"result.foldAssignments.$count":4} |
      | linguistic | linguistic-normalized | {"result.tokens.$count":3,"result.tokens.1.normalized":"ragazze","result.tokens.1.startUTF8":3,"result.tokens.1.endUTF8":10} |
      | linguistic | linguistic-stemming | {"result.tokens.1.stem":"ragazz","result.tokens.1.startUTF8":3,"result.tokens.1.endUTF8":10} |
      | linguistic-availability | linguistic-availability | {"result.languageTag":"it","result.hasItalianStemming":true} |
      | linguistic-coding | linguistic-coding | {"result.matrix.values":[[1]],"result.matrix.frequencies":[1],"result.matrix.evidence.0.0.0.start":3,"result.matrix.evidence.0.0.0.end":10} |
      | matrix-zscore | kh-zscore-rows | {"result":[[-1,0,1],[-1,0,1]]} |
      | matrix-zscore | kh-zscore-columns | {"result":[[-1,0],[0,0],[1,0]]} |
      | matrix-per-thousand | kh-external-exposure | {"result":[[20,30],[500,0]]} |
      | word-context | kh-context | {"result.targetIDs":["a","b"],"result.contextIDs":["x","y"],"result.supportCounts":[[2,2]],"result.values":[[4,6],[8,12]]} |
      | correspondence-scaled | kh-ca-principal | {"result.rowScaling":"principal","result.columnScaling":"standard","result.rowMasses":[0.5,0.5],"result.singularValues.0":0.5} |
      | correspondence-scaled | kh-ca-symmetric | {"result.rowScaling":"symmetric","result.columnScaling":"symmetric","result.singularValues.0":0.5,"result.rowMasses":[0.5,0.5]} |
      | mds-ordinal | kh-ordinal-primary | {"result.coordinates.$centroid":[0],"methodIdentifier":"MDS-ordinal-SMACOF-primary-ties-normalized-raw-stress-v1"} |
      | mds-ordinal | kh-ordinal-secondary | {"result.coordinates.$centroid":[0],"methodIdentifier":"MDS-ordinal-SMACOF-secondary-ties-normalized-raw-stress-v1"} |
      | mds-ordinal-search | kh-ordinal-search | {"result.runs.0.coordinates.$centroid":[0],"result.runs.0.methodIdentifier":"MDS-ordinal-SMACOF-primary-ties-normalized-raw-stress-v1","result.runs.0.seed":300,"result.runs.1.seed":301,"result.runs.2.seed":302} |
      | som-pca-initialization | kh-pca-init | {"result":[[-2],[2],[6]],"methodIdentifier":"SOM-PCA-linear-unscaled-canonical-v1"} |
      | som-kh | kh-som-hexagonal | {"result.completedSteps":12,"result.topographicError":0,"result.initialCodebooks":[[0],[4]],"result.assignments.$count":3} |
      | som-kh | kh-som-rectangular | {"result.topology":"rectangular","result.completedSteps":12,"result.topographicError":0,"result.codebookClustering.assignments":[0,0]} |
      | som-kh | kh-som-defaults | {"result.width":2,"result.height":1,"result.topographicError":0} |
      | kh-collocation | kh-global-collocation | {"result.mi3":8.321928094887362,"result.mutualInformation":4.321928094887363} |
      | kh-collocation | kh-undefined-collocation | {"result.$has:mi3":false,"result.$has:mutualInformation":false,"result.$has:zScore":false} |
      | term-scores | kh-term-scores-token | {"result.independentOccurrenceCount":2,"result.terms.0.components":["a","a"],"result.terms.0.frequency":2,"result.terms.0.lr":3,"result.terms.0.flr":6} |
      | term-scores | kh-term-scores-type | {"result.terms.0.lr":2,"result.terms.0.flr":4,"result.terms.0.frequency":2} |
      | term-extraction | kh-term-extract-english | {"result.occurrences.$count":2,"result.occurrences.0.startUTF8":0,"result.occurrences.0.endUTF8":11,"result.scores.terms.0.frequency":2,"result.scores.terms.0.lr":1.7320508075688772} |
      | term-extraction | kh-term-extract-japanese | {"result.occurrences.0.startUTF8":0,"result.occurrences.0.endUTF8":12,"result.scores.terms.0.frequency":1,"result.scores.terms.0.lr":1.4142135623730951} |
      | incremental-classifier | kh-incremental-initial | {"result.state.classes":["A"],"result.state.vocabulary":["a"],"result.state.documentCounts":[1],"result.state.tokenCounts":[[2]]} |
      | continue-classifier | kh-incremental-continue | {"result.state.documentCounts":[1,1],"result.state.tokenCounts":[[2,0],[0,1]],"result.predictions.labels":["A","B","A"]} |
      | validate-classifier-kappa | kh-classifier-kappa | {"result.evaluation.accuracy":1,"result.kappa":1,"result.observedAgreement":1,"result.expectedAgreement":0.5} |
      | word-association | kh-word-association | {"result.unconditionalProbability":0.3,"result.conditionalProbability":0.5,"result.differential":0.2,"result.lift":1.6666666666666667,"result.isPositiveAssociation":true} |
      | word-association | kh-word-association-overlap | {"result.unconditionalProbability":0.9,"result.conditionalProbability":0.875,"result.differential":-0.025,"result.isPositiveAssociation":false} |
      | document-scores | kh-document-score-tf | {"result.scores":[0.6,0.3],"result.termContributions":[[0.1,0.2,0.3],[0.1,0.2,0]]} |
      | document-scores | kh-document-score-tfIdf | {"result.mode":"tfIdf","result.scores":[0.16020599913279626,0.16020599913279626],"result.termContributions.0.2":0} |
      | document-scores | kh-document-score-tfDividedByIdf | {"result.mode":"tfDividedByIdf","result.scores":[1.0643856189774725,0.7643856189774725],"result.termContributions.0.2":0.3} |
      | kh-hierarchical-ward-d2 | kh-ward-d2 | {"result.objectCount":3,"result.heights.0":0.5,"result.sizes":[2,3]} |
      | kh-chi-square | kh-chi-square-yates | {"result.statistic":0,"result.pValue":1,"result.degreesOfFreedom":1} |
      | kh-chi-square | kh-chi-square-pearson | {"result.statistic":2,"result.pValue":0.15729920705028516,"result.degreesOfFreedom":1} |
      | kh-chi-square | kh-chi-square-degenerate | {"result.status":"zeroMarginal","result.$has:statistic":false,"result.$has:pValue":false} |
      | code-crosstab-significance | kh-code-crosstab-yates | {"result.groupSizes":[2,2],"result.excludedDocumentCount":1,"result.counts":[[1,2,0],[2,2,0]],"result.significance.0.test.statistic":0} |
      | code-crosstab-significance | kh-code-crosstab-three-groups | {"result.groupSizes":[2,2,2],"result.counts":[[0],[1],[2]],"result.significance.0.test.statistic":4,"result.significance.0.test.degreesOfFreedom":2} |
      | som | bdd-som-constant | {"result.prototypes":[[0,0]],"result.assignments":[0,0],"result.quantizationError":0} |
      | som-advanced | bdd-som-advanced-constant | {"result.topology":"hexagonal","result.map.prototypes":[[0],[0],[0],[0]],"result.map.quantizationError":0,"result.uMatrix":[0,0,0,0]} |
      | mds-search | bdd-mds-search-two-points | {"result.runs.$count":3,"result.runs.0.coordinates.$count":2,"result.runs.0.stress":0} |
      | mds-ordinal | bdd-mds-ordinal-two-points | {"result.coordinates.$count":2,"result.coordinates.0.$count":1,"result.stress":0,"result.seed":300} |
      | mds-ordinal-search | bdd-mds-ordinal-search-two-points | {"result.runs.$count":3,"result.runs.0.coordinates.$count":2,"result.runs.0.stress":0} |

  @phase-invalid-input
  Schema dello scenario: Ogni variante testuale in fase JSON-invalido conserva la failure
    Data la variante testuale "<variante>" usa la fixture originale "<fixture>"
    Quando eseguo la variante testuale in fase JSON-invalido
    Allora la variante testuale fallisce con codice "text-analysis.unknown-field" e categoria "invalidInput"

    Esempi:
      | variante | fixture |
      | clara | clara |
      | classify | classify |
      | code-crosstab | code-crosstab |
      | code-crosstab-significance | kh-code-crosstab-yates |
      | coding | coding |
      | communities | community-fastGreedy |
      | continue-classifier | kh-incremental-continue |
      | correspondence | correspondence |
      | correspondence-scaled | kh-ca-principal |
      | dissimilarities | dissimilarities |
      | document-scores | kh-document-score-tf |
      | graph-layout | layout-kamadaKawai |
      | hierarchical | hierarchical |
      | incremental-classifier | kh-incremental-initial |
      | kh-chi-square | kh-chi-square-yates |
      | kh-collocation | kh-global-collocation |
      | kh-hierarchical-ward-d2 | kh-ward-d2 |
      | lda | lda |
      | lda-selection | lda-selection |
      | linguistic | linguistic-normalized |
      | linguistic-availability | linguistic-availability |
      | linguistic-coding | linguistic-coding |
      | matrix-per-thousand | kh-external-exposure |
      | matrix-zscore | kh-zscore-rows |
      | mds | mds-classical |
      | mds-ordinal | kh-ordinal-primary |
      | mds-ordinal-search | kh-ordinal-search |
      | mds-search | mds-search |
      | minimum-spanning-forest | prim-forest |
      | network | network |
      | som | som |
      | som-advanced | som-hexagonal |
      | som-kh | kh-som-hexagonal |
      | som-pca-initialization | kh-pca-init |
      | term-extraction | kh-term-extract-english |
      | term-scores | kh-term-scores-token |
      | validate-classifier | validate-classifier |
      | validate-classifier-kappa | kh-classifier-kappa |
      | word-association | kh-word-association |
      | word-context | kh-context |

  @phase-pre-cancelled
  Schema dello scenario: Ogni variante testuale in fase precancellata conserva la failure
    Data la variante testuale "<variante>" usa la fixture originale "<fixture>"
    Quando eseguo la variante testuale in fase precancellata
    Allora la variante testuale fallisce con codice "operation.cancelled" e categoria "cancelled"

    Esempi:
      | variante | fixture |
      | clara | clara |
      | classify | classify |
      | code-crosstab | code-crosstab |
      | code-crosstab-significance | kh-code-crosstab-yates |
      | coding | coding |
      | communities | community-fastGreedy |
      | continue-classifier | kh-incremental-continue |
      | correspondence | correspondence |
      | correspondence-scaled | kh-ca-principal |
      | dissimilarities | dissimilarities |
      | document-scores | kh-document-score-tf |
      | graph-layout | layout-kamadaKawai |
      | hierarchical | hierarchical |
      | incremental-classifier | kh-incremental-initial |
      | kh-chi-square | kh-chi-square-yates |
      | kh-collocation | kh-global-collocation |
      | kh-hierarchical-ward-d2 | kh-ward-d2 |
      | lda | lda |
      | lda-selection | lda-selection |
      | linguistic | linguistic-normalized |
      | linguistic-availability | linguistic-availability |
      | linguistic-coding | linguistic-coding |
      | matrix-per-thousand | kh-external-exposure |
      | matrix-zscore | kh-zscore-rows |
      | mds | mds-classical |
      | mds-ordinal | kh-ordinal-primary |
      | mds-ordinal-search | kh-ordinal-search |
      | mds-search | mds-search |
      | minimum-spanning-forest | prim-forest |
      | network | network |
      | som | som |
      | som-advanced | som-hexagonal |
      | som-kh | kh-som-hexagonal |
      | som-pca-initialization | kh-pca-init |
      | term-extraction | kh-term-extract-english |
      | term-scores | kh-term-scores-token |
      | validate-classifier | validate-classifier |
      | validate-classifier-kappa | kh-classifier-kappa |
      | word-association | kh-word-association |
      | word-context | kh-context |
