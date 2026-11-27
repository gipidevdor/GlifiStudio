# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @analytical-methods @numerical-oracle
Funzionalità: Metodi analitici con oracoli piccoli e indipendenti
  Richieste leggibili producono conteggi e numeri controllabili a mano.
  I valori decimali usano tolleranza assoluta e relativa 1e-10.

  Schema dello scenario: Distanze euclidee, vettoriali e insiemistiche
    Data la richiesta analitica JSON {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"dissimilarities","matrix":<matrice>,"metric":"<metrica>"}
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "dissimilarities"
    E il valore analitico "result.0.1" è "<distanza>"
    E il valore analitico "result.1.0" è "<distanza>"
    E il valore analitico "result.0.0" è "0"
    E la collezione analitica "result" contiene 2 elementi

    Esempi:
      | metrica   | matrice                 | distanza |
      | euclidean | [[0,0],[3,4]]           | 5        |
      | manhattan | [[0,0],[3,4]]           | 7        |
      | cosine    | [[1,0],[0,1]]           | 1        |
      | jaccard   | [[1,1,0],[0,1,1]]       | 2/3      |
      | dice      | [[1,1,0],[0,1,1]]       | 1/2      |
      | simpson   | [[1,1,0],[1,1,1]]       | 0        |

  Scenario: La standardizzazione usa la deviazione campionaria
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"matrix-zscore","matrix":[[1,2,3],[2,4,6]],"axis":"rows"}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "matrix-zscore"
    E il valore analitico "result.0.0" è "-1"
    E il valore analitico "result.0.1" è "0"
    E il valore analitico "result.0.2" è "1"
    E il valore analitico "result.1.2" è "1"

  Scenario: Una colonna costante diventa zero soltanto con policy esplicita
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"matrix-zscore","matrix":[[1,5],[2,5],[3,5]],"axis":"columns","constantPolicy":"zeros"}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "matrix-zscore"
    E il valore analitico "result.0.0" è "-1"
    E il valore analitico "result.2.0" è "1"
    E il valore analitico "result.0.1" è "0"
    E il valore analitico "result.2.1" è "0"

  Scenario: Il tasso per mille usa l'esposizione esterna completa
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"matrix-per-thousand","matrix":[[2,3],[1,0]],"exposures":[100,2]}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "matrix-per-thousand"
    E il valore analitico "result.0.0" è "20"
    E il valore analitico "result.0.1" è "30"
    E il valore analitico "result.1.0" è "500"
    E il valore analitico "result.1.1" è "0"

  Schema dello scenario: TF e IDF conservano esposizioni e termini ubiquitari
    Data la richiesta analitica JSON {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"document-scores","counts":[[2,3]],"exposures":[10],"documentFrequencies":[1,10],"corpusDocumentCount":10,"mode":"<modo>"}
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "document-scores"
    E il valore analitico "result.inverseDocumentFrequencies.0" è "1"
    E il valore analitico "result.inverseDocumentFrequencies.1" è "0"
    E il valore analitico "result.scores.0" è "<punteggio>"
    E il valore analitico "result.termContributions.0.1" è "<ubiquitario>"

    Esempi:
      | modo           | punteggio | ubiquitario |
      | tf             | 1/2       | 3/10        |
      | tfIdf          | 1/5       | 0           |
      | tfDividedByIdf | 1/2       | 3/10        |

  Scenario: L'associazione documentale distingue probabilità condizionata e marginale
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"word-association","counts":{"jointCount":20,"conditionDocumentCount":40,"termDocumentCount":30,"totalDocumentCount":100}}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "word-association"
    E il valore analitico "result.unconditionalProbability" è "3/10"
    E il valore analitico "result.conditionalProbability" è "1/2"
    E il valore analitico "result.differential" è "1/5"
    E il valore analitico "result.lift" è "5/3"
    E il valore analitico "result.jaccard" è "2/5"

  Scenario: Le collocazioni globali dichiarano i margini dei punteggi
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"kh-collocation","counts":{"jointCount":4,"nodeFrequency":10,"collocateFrequency":20,"corpusTokenCount":1000,"windowSpan":10}}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "kh-collocation"
    E il valore analitico "result.jaccard" è "2/13"
    E il valore analitico "result.dice" è "4/15"
    E il valore analitico "result.tScore" è "1.9"

  Schema dello scenario: Pearson e Yates sono scelte statistiche distinte
    Data la richiesta analitica JSON {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"kh-chi-square","counts":[[1,0],[0,1]],"correction":"<correzione>"}
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "kh-chi-square"
    E il valore analitico "result.statistic" è "<statistica>"
    E il valore analitico "result.expected.0.0" è "1/2"
    E il valore analitico "result.degreesOfFreedom" è "1"
    E la stringa analitica "result.appliedCorrection" è "<correzione>"

    Esempi:
      | correzione | statistica |
      | none       | 2          |
      | yates      | 0          |

  Scenario: La CA della tabella simmetrica conserva masse e inerzia
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"correspondence","matrix":[[4,1],[1,4]]}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "correspondence"
    E il valore analitico "result.totalInertia" è "0.36"
    E il valore analitico "result.rowMasses.0" è "1/2"
    E il valore analitico "result.columnMasses.1" è "1/2"
    E la collezione analitica "result.inertias" contiene 1 elementi

  Scenario: L'MDS classico ricostruisce tre punti collineari
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"mds","matrix":[[0,1,2],[1,0,1],[2,1,0]],"dimensions":1,"method":"classical","seed":7,"maximumIterations":50}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "mds"
    E il valore analitico "result.eigenvalues.0" è "2"
    E il valore analitico "result.stress" è "0"
    E la collezione analitica "result.coordinates" contiene 3 elementi
    E la riesecuzione analitica è identica

  Scenario: Il linkage medio pesa le distanze dei due oggetti già uniti
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"hierarchical","matrix":[[0,1,3],[1,0,2],[3,2,0]],"linkage":"average"}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "hierarchical"
    E il valore analitico "result.heights.0" è "1"
    E il valore analitico "result.heights.1" è "5/2"
    E il valore analitico "result.sizes.1" è "3"

  Scenario: Naive Bayes applica Laplace e ignora soltanto il termine sconosciuto
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"classify","documents":[["rosso"],["blu"]],"labels":["A","B"],"predictionDocuments":[["rosso"],["ignoto"]],"smoothing":1}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "classify"
    E la stringa analitica "result.labels.0" è "A"
    E il valore analitico "result.probabilities.0.0" è "2/3"
    E il valore analitico "result.probabilities.1.0" è "1/2"
    E il valore analitico "result.ignoredTokenCounts.1" è "1"

  Scenario: LDA con un solo tema assegna probabilità unitaria a ogni documento
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"lda","documents":[["rosso"],["blu"]],"topicCount":1,"seed":7,"burnIn":0,"sampleCount":2,"thinning":1}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "lda"
    E il valore analitico "result.documentTopics.0.0" è "1"
    E il valore analitico "result.documentTopics.1.0" è "1"
    E il valore analitico "result.topicTerms.0.0" è "1/2"
    E la collezione analitica "result.vocabulary" contiene 2 elementi
    E la riesecuzione analitica è identica

  Scenario: La frequenza di codifica conta documenti e conserva le occorrenze
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"coding","units":[{"id":"a","text":"casa casa"},{"id":"b","text":"mare"}],"rules":"*Casa\ncasa"}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "coding"
    E il valore analitico "result.frequencies.0" è "1"
    E il valore analitico "result.values.0.0" è "1"
    E il valore analitico "result.values.1.0" è "0"
    E la collezione analitica "result.evidence.0.0" contiene 2 elementi

  Scenario: Una crosstab conserva il denominatore e il gruppo mancante
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"code-crosstab","units":[{"id":"a","text":"casa"},{"id":"b","text":"mare"}],"rules":"*Casa\ncasa","groups":["A",null]}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "code-crosstab"
    E il valore analitico "result.counts.0.0" è "1"
    E il valore analitico "result.sizes.0" è "1"
    E il valore analitico "result.missingCount" è "1"

  Scenario: La foresta minima evita l'arco più costoso del triangolo
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"minimum-spanning-forest","graph":{"nodes":["A","B","C"],"edges":[{"source":"A","target":"B","weight":2},{"source":"B","target":"C","weight":1},{"source":"A","target":"C","weight":4}]}}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "minimum-spanning-forest"
    E il valore analitico "result.totalWeight" è "3"
    E il valore analitico "result.componentCount" è "1"
    E la collezione analitica "result.edges" contiene 2 elementi

  Scenario: La normalizzazione linguistica conserva i byte del testo accentato
    Data la richiesta analitica JSON
      """json
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"linguistic","text":"Città mare."}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "linguistic"
    E la stringa analitica "result.tokens.0.normalized" è "città"
    E il valore analitico "result.tokens.0.startUTF8" è "0"
    E il valore analitico "result.tokens.0.endUTF8" è "6"
    E il valore analitico "result.tokens.1.startUTF8" è "7"
    E la collezione analitica "result.tokens" contiene 2 elementi

  Schema dello scenario: Popolazioni degeneri falliscono senza un risultato numerico fittizio
    Data la richiesta analitica JSON {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"<operazione>","matrix":<matrice>,<parametri>}
    Quando eseguo la richiesta analitica
    Allora la richiesta analitica fallisce con codice "<codice>" e categoria "insufficientData"

    Esempi:
      | operazione      | matrice           | parametri            | codice                       |
      | dissimilarities | [[0,0],[1,0]]     | "metric":"cosine"    | text-matrix.zero-cosine-norm |
      | matrix-zscore   | [[1,1,1]]         | "axis":"rows"        | kh-matrix.constant-vector   |
