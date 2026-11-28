# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-337 @GS-CMP-332 @macos @operator-complete
Funzionalità: Tutte le varianti del laboratorio operator mantengono il contratto osservabile
  Fixture sintetiche originali; nessun dataset esterno riprodotto.
  Le attese numeriche usano tolleranza assoluta/relativa 1e-10.
  Le partizioni ignorano la numerazione dei gruppi; KL e Jensen–Shannon usano bit (GS-MET-001-13).

  @phase-nominal
  Schema dello scenario: <variante> conserva la richiesta e le attese indipendenti
    Dato il caso operatore "<variante>" usa JSON <richiesta>
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il risultato completo conserva la variante "<variante>"
    E le attese degli operatori indipendenti sono JSON <attese>

    Esempi:
      | variante | richiesta | attese |
      | betweenness | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t2\\nB\\tC\\t4"} | {"tables":{"operators.scores":{"rowCount":3,"cells":{"0,1":0,"1,1":1,"2,1":0}}}} |
      | communities | {"nodes":"A\\nB\\nC\\nD","edges":"A\\tB\\t2\\nC\\tD\\t2"} | {"tables":{"operators.communities":{"rowCount":4,"cells":{}}},"diagnostics":{"operators.modularity":0.5,"operators.community-count":2},"partition":{"table":"operators.communities","groups":[[0,1],[2,3]]}} |
      | cosine | {"numbers":"1 0\\n0 1"} | {"diagnostics":{"operators.value":0}} |
      | degree | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t2\\nB\\tC\\t4"} | {"tables":{"operators.degrees":{"rowCount":3,"cells":{"0,1":0,"0,2":1,"0,3":0,"0,4":2,"1,1":1,"1,2":1,"1,3":2,"1,4":4,"2,1":1,"2,2":0,"2,3":4,"2,4":0}}}} |
      | dice | {"firstSet":"a b","secondSet":"b c"} | {"diagnostics":{"operators.value":0.5}} |
      | distances | {"numbers":"0 0\\n3 4","distance":"euclidean"} | {"tables":{"operators.matrix":{"rowCount":4,"cells":{"0,2":0,"1,2":5,"2,2":5,"3,2":0}}}} |
      | eigenvector | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t1\\nB\\tC\\t1\\nC\\tA\\t1"} | {"tables":{"operators.scores":{"rowCount":3,"cells":{"0,1":1,"1,1":1,"2,1":1}}},"diagnostics":{"operators.eigenvalue":1}} |
      | euclidean | {"numbers":"0 0\\n3 4"} | {"diagnostics":{"operators.value":5}} |
      | graphLayout | {"nodes":"A\\nB","edges":"A\\tB\\t1","layoutMethod":"kamadaKawai","usesInitialPositions":true,"numbers":"-.5 0\\n.5 0"} | {"tables":{"operators.positions":{"rowCount":2,"cells":{"0,0":"A","0,1":-0.5,"0,2":0,"1,0":"B","1,1":0.5,"1,2":0}}},"diagnostics":{"operators.iterations":0,"operators.converged":"operators.boolean.true"}} |
      | hacCutCount | {"numbers":"0\\n1\\n10\\n11","clusterCount":2,"maximumHeight":1} | {"tables":{"operators.merges":{"rowCount":3,"cells":{"0,2":1,"1,2":1,"2,2":10}}},"partition":{"table":"operators.assignments","groups":[[0,1],[2,3]]}} |
      | hacCutHeight | {"numbers":"0\\n1\\n10\\n11","clusterCount":2,"maximumHeight":1} | {"tables":{"operators.merges":{"rowCount":3,"cells":{"0,2":1,"1,2":1,"2,2":10}}},"partition":{"table":"operators.assignments","groups":[[0,1],[2,3]]}} |
      | harmonicCloseness | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t2\\nB\\tC\\t4"} | {"tables":{"operators.scores":{"rowCount":3,"cells":{"0,1":1.5,"1,1":1,"2,1":0}}}} |
      | heapsFit | {"documents":"a b c d","checkpoints":"1 2 4"} | {"diagnostics":{"operators.coefficient":1,"operators.exponent":1,"operators.r-squared":1,"operators.rmse":0}} |
      | hellinger | {"numbers":"1 0\\n0 1"} | {"diagnostics":{"operators.value":1}} |
      | jaccard | {"firstSet":"a b","secondSet":"b c"} | {"diagnostics":{"operators.value":0.3333333333333333}} |
      | jensenShannon | {"numbers":"1 0\\n0 1"} | {"diagnostics":{"operators.value":1}} |
      | jensenShannonDistance | {"numbers":"1 0\\n0 1"} | {"diagnostics":{"operators.value":1}} |
      | kMeans | {"numbers":"0 0\\n0 0\\n10 10\\n10 10","clusterCount":2,"seed":337} | {"tables":{"operators.assignments":{"rowCount":4,"cells":{}}},"diagnostics":{"operators.objective":0},"partition":{"table":"operators.assignments","groups":[[0,1],[2,3]]}} |
      | kl | {"numbers":".5 .5\\n.25 .75"} | {"diagnostics":{"operators.value":0.2075187496394219}} |
      | lexicalObservation | {"documents":"a a b c\\nb d","checkpoints":"1 3 6"} | {"tables":{"operators.rank-frequency":{"rowCount":4,"cells":{"0,0":"a","0,1":2,"1,0":"b","1,1":2}},"operators.growth":{"rowCount":3,"cells":{"0,1":1,"1,1":2,"2,1":4}}}} |
      | lidstone | {"numbers":"0 2","alpha":1} | {"tables":{"operators.probabilities":{"rowCount":2,"cells":{"0,1":0.25,"1,1":0.75}}}} |
      | louvain | {"nodes":"A\\nB\\nC\\nD","edges":"A\\tB\\t2\\nC\\tD\\t2"} | {"tables":{"operators.communities":{"rowCount":4,"cells":{}}},"diagnostics":{"operators.modularity":0.5,"operators.community-count":2},"partition":{"table":"operators.communities","groups":[[0,1],[2,3]]}} |
      | lsa | {"numbers":"3 0\\n0 2","rank":1} | {"tables":{"operators.singular-values":{"rowCount":2,"cells":{"0,1":3,"1,1":2}}},"diagnostics":{"operators.rank":1,"operators.residual-norm":2}} |
      | manhattan | {"numbers":"0 0\\n3 4"} | {"diagnostics":{"operators.value":7}} |
      | minimumSpanningForest | {"nodes":"A\\nB\\nC\\nD","edges":"A\\tB\\t0\\nA\\tC\\t3\\nB\\tC\\t1"} | {"tables":{"operators.forest-edges":{"rowCount":2,"cells":{"0,2":0,"1,2":1}}},"diagnostics":{"operators.total-cost":1,"operators.component-count":2}} |
      | modularity | {"nodes":"A\\nB\\nC\\nD","edges":"A\\tB\\t2\\nC\\tD\\t2","assignments":"0 0 1 1"} | {"diagnostics":{"operators.modularity":0.5}} |
      | multisetDice | {"numbers":"1 2\\n2 1"} | {"diagnostics":{"operators.value":0.6666666666666666}} |
      | nmf | {"numbers":"1 2\\n2 4","rank":1,"seed":337,"restarts":1,"maximumIterations":100,"tolerance":1e-12} | {"tables":{"operators.matrix-w":{"rowCount":2,"cells":{}},"operators.matrix-h":{"rowCount":2,"cells":{}}},"diagnostics":{"operators.objective":0}} |
      | pageRank | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t1\\nB\\tC\\t1\\nC\\tA\\t1"} | {"tables":{"operators.scores":{"rowCount":3,"cells":{"0,1":0.3333333333333333,"1,1":0.3333333333333333,"2,1":0.3333333333333333}}}} |
      | pca | {"numbers":"-1 -2\\n0 0\\n1 2","scaled":false} | {"tables":{"operators.means":{"rowCount":2,"cells":{"0,1":0,"1,1":0}},"operators.variances":{"rowCount":2,"cells":{"0,1":5,"1,1":0}},"operators.variance-shares":{"rowCount":2,"cells":{"0,1":1,"1,1":0}}}} |
      | silhouette | {"numbers":"0\\n0\\n10\\n10","assignments":"0 0 1 1"} | {"tables":{"operators.widths":{"rowCount":4,"cells":{"0,1":1,"1,1":1,"2,1":1,"3,1":1}}},"diagnostics":{"operators.average":1}} |
      | simpson | {"firstSet":"a b","secondSet":"a b c"} | {"diagnostics":{"operators.value":1}} |
      | strongComponents | {"nodes":"A\\nB\\nC\\nD","edges":"A\\tB\\t1\\nB\\tA\\t1\\nB\\tC\\t1"} | {"tables":{"operators.components":{"rowCount":4,"cells":{}}},"diagnostics":{"operators.component-count":3},"partition":{"table":"operators.components","groups":[[0,1],[2],[3]]}} |
      | svd | {"numbers":"3 0\\n0 2"} | {"tables":{"operators.singular-values":{"rowCount":2,"cells":{"0,1":3,"1,1":2}}},"diagnostics":{"operators.rank":2}} |
      | transformBinary | {"numbers":"2 0\\n1 3"} | {"tables":{"operators.matrix":{"rowCount":4,"cells":{"0,2":1,"1,2":0,"2,2":1,"3,2":1}}}} |
      | transformCounts | {"numbers":"2 0\\n1 3"} | {"tables":{"operators.matrix":{"rowCount":4,"cells":{"0,2":2,"1,2":0,"2,2":1,"3,2":3}}}} |
      | transformPerThousand | {"numbers":"2 0\\n1 3"} | {"tables":{"operators.matrix":{"rowCount":4,"cells":{"0,2":1000,"1,2":0,"2,2":250,"3,2":750}}}} |
      | transformTFIDF | {"numbers":"1 1\\n1 0"} | {"tables":{"operators.matrix":{"rowCount":4,"cells":{"0,2":1,"1,2":1.4054651081081644,"2,2":1,"3,2":0}}}} |
      | transpose | {"numbers":"1 2 3\\n4 5 6"} | {"tables":{"operators.matrix":{"rowCount":6,"cells":{"0,2":1,"1,2":4,"2,2":2,"3,2":5,"4,2":3,"5,2":6}}}} |
      | truncatedSVD | {"numbers":"3 0\\n0 2","rank":1,"oversampling":1} | {"tables":{"operators.singular-values":{"rowCount":1,"cells":{"0,1":3}}},"diagnostics":{"operators.rank":1}} |
      | weakComponents | {"nodes":"A\\nB\\nC\\nD","edges":"A\\tB\\t1\\nB\\tC\\t1"} | {"tables":{"operators.components":{"rowCount":4,"cells":{}}},"diagnostics":{"operators.component-count":2},"partition":{"table":"operators.components","groups":[[0,1,2],[3]]}} |
      | weightedBetweenness | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t2\\nB\\tC\\t4"} | {"tables":{"operators.scores":{"rowCount":3,"cells":{"0,1":0,"1,1":1,"2,1":0}}}} |
      | weightedCloseness | {"nodes":"A\\nB\\nC","edges":"A\\tB\\t2\\nB\\tC\\t4"} | {"tables":{"operators.scores":{"rowCount":3,"cells":{"0,1":3.3333333333333335,"1,1":4,"2,1":0}}}} |
      | weightedJaccard | {"numbers":"1 2\\n2 1"} | {"diagnostics":{"operators.value":0.5}} |
      | zipfFit | {"documents":"a a a a b b","firstRank":1,"lastRank":2} | {"diagnostics":{"operators.coefficient":4,"operators.exponent":1,"operators.r-squared":1,"operators.rmse":0}} |

  @phase-invalid-input
  Schema dello scenario: <variante> rifiuta il JSON con campo ignoto senza pubblicare un risultato
    Dato il caso operatore "<variante>" usa JSON {}
    E la richiesta completa contiene un campo JSON non ammesso
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il caso completo fallisce con codice "command.unknown-field" e categoria "invalidInput" e stato "unchanged"

    Esempi:
      | variante |
      | betweenness |
      | communities |
      | cosine |
      | degree |
      | dice |
      | distances |
      | eigenvector |
      | euclidean |
      | graphLayout |
      | hacCutCount |
      | hacCutHeight |
      | harmonicCloseness |
      | heapsFit |
      | hellinger |
      | jaccard |
      | jensenShannon |
      | jensenShannonDistance |
      | kMeans |
      | kl |
      | lexicalObservation |
      | lidstone |
      | louvain |
      | lsa |
      | manhattan |
      | minimumSpanningForest |
      | modularity |
      | multisetDice |
      | nmf |
      | pageRank |
      | pca |
      | silhouette |
      | simpson |
      | strongComponents |
      | svd |
      | transformBinary |
      | transformCounts |
      | transformPerThousand |
      | transformTFIDF |
      | transpose |
      | truncatedSVD |
      | weakComponents |
      | weightedBetweenness |
      | weightedCloseness |
      | weightedJaccard |
      | zipfFit |

  @phase-pre-cancelled
  Schema dello scenario: <variante> rispetta la cancellazione prima di decodificare e calcolare
    Dato il caso operatore "<variante>" usa JSON {}
    Quando eseguo il caso completo con task già cancellato
    Allora il caso completo fallisce con codice "command.cancelled" e categoria "cancelled" e stato "unchanged"

    Esempi:
      | variante |
      | betweenness |
      | communities |
      | cosine |
      | degree |
      | dice |
      | distances |
      | eigenvector |
      | euclidean |
      | graphLayout |
      | hacCutCount |
      | hacCutHeight |
      | harmonicCloseness |
      | heapsFit |
      | hellinger |
      | jaccard |
      | jensenShannon |
      | jensenShannonDistance |
      | kMeans |
      | kl |
      | lexicalObservation |
      | lidstone |
      | louvain |
      | lsa |
      | manhattan |
      | minimumSpanningForest |
      | modularity |
      | multisetDice |
      | nmf |
      | pageRank |
      | pca |
      | silhouette |
      | simpson |
      | strongComponents |
      | svd |
      | transformBinary |
      | transformCounts |
      | transformPerThousand |
      | transformTFIDF |
      | transpose |
      | truncatedSVD |
      | weakComponents |
      | weightedBetweenness |
      | weightedCloseness |
      | weightedJaccard |
      | zipfFit |

  @phase-invalid-input @domain-edge
  Schema dello scenario: <variante> rifiuta il dominio degenere dichiarato
    Dato il caso operatore "<variante>" usa JSON <richiesta>
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il caso completo fallisce con codice "<codice>" e categoria "<categoria>" e stato "<stato>"

    Esempi:
      | variante | richiesta | codice | categoria | stato |
      | cosine | {"numbers":"0 0\\n1 0"} | similarity.zero-vector | insufficientData | lastCommittedGeneration |
      | kl | {"numbers":"1 0\\n0 1"} | similarity.kl-undefined | insufficientData | lastCommittedGeneration |
      | transformCounts | {"numbers":"-1 0\\n1 2"} | text-matrix.negative-count | invalidInput | unchanged |
      | nmf | {"numbers":"1 2\\n2 4","rank":0} | nmf.invalid-parameters | invalidInput | lastCommittedGeneration |
      | graphLayout | {"nodes":"A\\nB","edges":"A\\tB\\t1","layoutMethod":"not-a-layout"} | operators.invalid-input | invalidInput | unchanged |
      | heapsFit | {"documents":"a a a","checkpoints":"1 2 3"} | lexical-distribution.fit-outside-model-domain | insufficientData | unchanged |
