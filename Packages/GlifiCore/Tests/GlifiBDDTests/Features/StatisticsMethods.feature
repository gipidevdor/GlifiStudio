# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-337 @GS-CMP-332 @macos @statistics-complete
Funzionalità: Tutte le varianti del laboratorio statistics mantengono il contratto osservabile
  Fixture sintetiche originali; nessun dataset esterno riprodotto.
  Le attese numeriche usano tolleranza assoluta/relativa 1e-10.
  Le partizioni sono verificate indipendentemente dalla numerazione dei gruppi.

  @phase-nominal
  Schema dello scenario: <variante> conserva la richiesta e le attese indipendenti
    Dato il caso statistico "<variante>" usa JSON <richiesta>
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il risultato completo conserva la variante "<variante>"
    E le attese statistiche indipendenti sono JSON <attese>

    Esempi:
      | variante | richiesta | attese |
      | alphaInterval | {"values":[[0,0],[1,1],[0,0],[1,1]],"parameters":{"measurementLevel":"interval","resampleCount":64,"seed":337}} | {"metrics":{"lower":1,"upper":1,"resample-count":64}} |
      | alphaNominal | {"categories":[["A","A"],["B","B"],["A",null]]} | {"metrics":{"observed-disagreement":0,"alpha":1,"included-units":2}} |
      | alphaNumeric | {"values":[[0,0],[1,1],[0,null]],"parameters":{"measurementLevel":"interval"}} | {"metrics":{"alpha":1,"pairable-values":4,"included-units":2}} |
      | anova | {"values":[[0,1,2],[0,1,2],[0,1,2]]} | {"metrics":{"f-statistic":0,"numerator-df":2,"denominator-df":6,"p-value":1}} |
      | benjaminiHochberg | {"values":[[0.01,0.04,0.2]]} | {"metrics":{},"rowCount":3,"cells":{"0,2":0.03,"1,2":0.06,"2,2":0.2}} |
      | blockBootstrap | {"values":[[1,2,3]],"parameters":{"blockLength":3,"resampleCount":32,"seed":337}} | {"metrics":{"estimate":2,"lower":2,"upper":2,"resample-count":32}} |
      | bonferroni | {"values":[[0.01,0.04,0.2]]} | {"metrics":{},"rowCount":3,"cells":{"0,2":0.03,"1,2":0.12,"2,2":0.6}} |
      | bootstrapBCa | {"values":[[-1,0,1]],"parameters":{"confidenceLevel":0.999,"resampleCount":256,"seed":337}} | {"metrics":{"estimate":0,"acceleration":0,"lower":-1,"upper":1,"resample-count":256}} |
      | bootstrapMean | {"values":[[7,7,7]],"parameters":{"resampleCount":32,"seed":337}} | {"metrics":{"estimate":7,"lower":7,"upper":7,"resample-count":32}} |
      | cohenD | {"values":[[0,1,2],[0,1,2]]} | {"metrics":{"cohen-d":0,"pooled-standard-deviation":1}} |
      | cohenKappa | {"categories":[["A","A"],["B","B"],["A","A"],["B","B"]]} | {"metrics":{"observed-agreement":1,"expected-agreement":0.5,"kappa":1,"unit-count":4}} |
      | contingency | {"values":[[2,2],[2,2]]} | {"metrics":{"chi-square":0,"degrees-of-freedom":1,"p-value":1,"cramers-v":0},"rowCount":4,"cells":{"0,2":0,"3,2":0}} |
      | descriptive | {"values":[[1,2,3,null]]} | {"metrics":{"valid-count":3,"missing-count":1,"mean":2,"median":2,"variance":1,"standard-deviation":1},"rowCount":3,"cells":{"0,1":1.5,"1,1":2,"2,1":2.5}} |
      | dunn | {"values":[[0,1,2],[0,1,2]]} | {"metrics":{},"rowCount":1,"cells":{"0,0":1,"0,1":2,"0,2":0,"0,3":0,"0,5":1}} |
      | epsilonSquared | {"parameters":{"statistic":3,"firstCount":7}} | {"metrics":{"epsilon-squared":0.5}} |
      | fPValue | {"parameters":{"statistic":1,"degreesOfFreedom":1,"secondDegreesOfFreedom":1}} | {"metrics":{"p-value":0.5}} |
      | fisherExact | {"values":[[1,1],[1,1]]} | {"metrics":{"p-value":1,"table-probability":0.6666666666666666,"odds-ratio":1}} |
      | fleissKappa | {"categories":[["A","A","A"],["B","B","B"]]} | {"metrics":{"observed-agreement":1,"expected-agreement":0.5,"kappa":1}} |
      | gamesHowell | {"values":[[0,1,2],[0,1,2]]} | {"metrics":{},"rowCount":1,"cells":{"0,0":1,"0,1":2,"0,2":0,"0,3":0,"0,5":1}} |
      | hedgesG | {"values":[[0,1,2],[0,1,2]]} | {"metrics":{"cohen-d":0,"hedges-g":0,"correction-factor":0.7978845608028654}} |
      | kruskalWallis | {"values":[[1,2,3],[1,2,3],[1,2,3]]} | {"metrics":{"h-statistic":0,"corrected-h":0,"degrees-of-freedom":2,"p-value":1}} |
      | mannWhitney | {"values":[[1,2],[3,4]],"parameters":{"exact":true}} | {"metrics":{"u-first":0,"u-second":4,"p-value":0.3333333333333333,"rank-biserial":-1}} |
      | monteCarloChiSquare | {"values":[[2,2],[2,2]],"parameters":{"resampleCount":32,"seed":337}} | {"metrics":{"chi-square":0,"p-value":1,"simulation-count":32}} |
      | normalCDF | {"parameters":{"statistic":0}} | {"metrics":{"value":0.5}} |
      | normalDensity | {"parameters":{"statistic":0}} | {"metrics":{"value":0.3989422804014327}} |
      | normalQuantile | {"parameters":{"probability":0.5}} | {"metrics":{"value":0}} |
      | oneSampleT | {"values":[[-1,0,1]]} | {"metrics":{"mean":0,"standard-deviation":1,"statistic":0,"degrees-of-freedom":2,"p-value":1}} |
      | pairedT | {"values":[[1,3,5],[2,3,4]]} | {"metrics":{"mean":0,"standard-deviation":1,"statistic":0,"degrees-of-freedom":2,"p-value":1}} |
      | pearson | {"values":[[-1,0,1],[1,-2,1]]} | {"metrics":{"coefficient":0,"t-statistic":0,"sample-count":3,"degrees-of-freedom":1,"p-value":1}} |
      | pearsonInterval | {"parameters":{"coefficient":0,"firstCount":7,"confidenceLevel":0.6826894921370859}} | {"metrics":{"lower":-0.46211715726000974,"upper":0.46211715726000974}} |
      | permutation | {"values":[[0,1],[2,3]],"parameters":{"exact":true}} | {"metrics":{"observed-difference":-2,"evaluated-count":6,"extreme-count":2,"p-value":0.3333333333333333}} |
      | plannedContrasts | {"values":[[0,1,2],[0,1,2]],"parameters":{"contrasts":[[1,-1]]}} | {"metrics":{},"rowCount":1,"cells":{"0,1":0,"0,3":0,"0,4":4,"0,5":1,"0,6":1,"0,7":1}} |
      | rangeCDF | {"parameters":{"statistic":0,"groupCount":2,"degreesOfFreedom":1}} | {"metrics":{"value":0}} |
      | rangeQuantile | {"parameters":{"probability":0.5,"groupCount":2,"degreesOfFreedom":1}} | {"metrics":{"value":1.4142135623730951}} |
      | rangeTail | {"parameters":{"statistic":0,"groupCount":2,"degreesOfFreedom":1}} | {"metrics":{"value":1}} |
      | rankBiserial | {"parameters":{"statistic":0,"firstCount":2,"secondCount":2}} | {"metrics":{"rank-biserial":-1}} |
      | spearman | {"values":[[1,2,3,4],[2,4,1,3]]} | {"metrics":{"coefficient":0,"t-statistic":0,"sample-count":4,"p-value":1}} |
      | spearmanExact | {"values":[[1,2,3],[1,2,3]]} | {"metrics":{"p-value":0.3333333333333333}} |
      | tPValue | {"parameters":{"statistic":1,"degreesOfFreedom":1}} | {"metrics":{"p-value":0.5}} |
      | tQuantile | {"parameters":{"probability":0.75,"degreesOfFreedom":1}} | {"metrics":{"value":1}} |
      | tukey | {"values":[[0,1,2],[0,1,2]]} | {"metrics":{},"rowCount":1,"cells":{"0,0":1,"0,1":2,"0,2":0,"0,3":0,"0,5":1}} |
      | welchANOVA | {"values":[[0,1,2],[0,1,2],[0,1,2]]} | {"metrics":{"f-statistic":0,"numerator-df":2,"denominator-df":4,"p-value":1}} |
      | welchT | {"values":[[0,1,2],[0,1,2]]} | {"metrics":{"statistic":0,"degrees-of-freedom":4,"p-value":1}} |
      | wilcoxon | {"values":[[1,2,3],[0,0,0]],"parameters":{"exact":true}} | {"metrics":{"positive-rank-sum":6,"negative-rank-sum":0,"ranked-count":3,"p-value":0.25}} |

  @phase-invalid-input
  Schema dello scenario: <variante> rifiuta il JSON con campo ignoto senza pubblicare un risultato
    Dato il caso statistico "<variante>" usa JSON {}
    E la richiesta completa contiene un campo JSON non ammesso
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il caso completo fallisce con codice "command.unknown-field" e categoria "invalidInput" e stato "unchanged"

    Esempi:
      | variante |
      | alphaInterval |
      | alphaNominal |
      | alphaNumeric |
      | anova |
      | benjaminiHochberg |
      | blockBootstrap |
      | bonferroni |
      | bootstrapBCa |
      | bootstrapMean |
      | cohenD |
      | cohenKappa |
      | contingency |
      | descriptive |
      | dunn |
      | epsilonSquared |
      | fPValue |
      | fisherExact |
      | fleissKappa |
      | gamesHowell |
      | hedgesG |
      | kruskalWallis |
      | mannWhitney |
      | monteCarloChiSquare |
      | normalCDF |
      | normalDensity |
      | normalQuantile |
      | oneSampleT |
      | pairedT |
      | pearson |
      | pearsonInterval |
      | permutation |
      | plannedContrasts |
      | rangeCDF |
      | rangeQuantile |
      | rangeTail |
      | rankBiserial |
      | spearman |
      | spearmanExact |
      | tPValue |
      | tQuantile |
      | tukey |
      | welchANOVA |
      | welchT |
      | wilcoxon |

  @phase-pre-cancelled
  Schema dello scenario: <variante> rispetta la cancellazione prima di decodificare e calcolare
    Dato il caso statistico "<variante>" usa JSON {}
    Quando eseguo il caso completo con task già cancellato
    Allora il caso completo fallisce con codice "command.cancelled" e categoria "cancelled" e stato "unchanged"

    Esempi:
      | variante |
      | alphaInterval |
      | alphaNominal |
      | alphaNumeric |
      | anova |
      | benjaminiHochberg |
      | blockBootstrap |
      | bonferroni |
      | bootstrapBCa |
      | bootstrapMean |
      | cohenD |
      | cohenKappa |
      | contingency |
      | descriptive |
      | dunn |
      | epsilonSquared |
      | fPValue |
      | fisherExact |
      | fleissKappa |
      | gamesHowell |
      | hedgesG |
      | kruskalWallis |
      | mannWhitney |
      | monteCarloChiSquare |
      | normalCDF |
      | normalDensity |
      | normalQuantile |
      | oneSampleT |
      | pairedT |
      | pearson |
      | pearsonInterval |
      | permutation |
      | plannedContrasts |
      | rangeCDF |
      | rangeQuantile |
      | rangeTail |
      | rankBiserial |
      | spearman |
      | spearmanExact |
      | tPValue |
      | tQuantile |
      | tukey |
      | welchANOVA |
      | welchT |
      | wilcoxon |

  @phase-invalid-input @domain-edge
  Schema dello scenario: <variante> rifiuta il dominio degenere dichiarato
    Dato il caso statistico "<variante>" usa JSON <richiesta>
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il caso completo fallisce con codice "<codice>" e categoria "<categoria>" e stato "<stato>"

    Esempi:
      | variante | richiesta | codice | categoria | stato |
      | oneSampleT | {"values":[[1,1,1]]} | statistics.non-positive-variance | insufficientData | lastCommittedGeneration |
      | pairedT | {"values":[[1,2],[1]]} | statistics.paired-length-mismatch | invalidInput | lastCommittedGeneration |
      | normalQuantile | {"parameters":{"probability":0}} | statistics.invalid-probability | invalidInput | lastCommittedGeneration |
      | bootstrapBCa | {"values":[[7,7,7]],"parameters":{"resampleCount":32}} | statistics.bca-undefined | insufficientData | lastCommittedGeneration |
      | cohenKappa | {"categories":[["A",null],["B","B"]]} | statistics.workbench.complete-two-raters-required | invalidInput | unchanged |
      | fisherExact | {"values":[[-1,1],[1,1]]} | statistics.workbench.invalid-count | invalidInput | unchanged |
      | rangeQuantile | {"parameters":{"probability":0}} | statistics.invalid-probability | invalidInput | lastCommittedGeneration |

  @phase-nominal @affine-extremes
  Schema dello scenario: <variante> conserva l'inferenza alle scale e agli offset rappresentabili
    Dato il caso statistico "<variante>" usa JSON <richiesta>
    Quando eseguo il caso completo attraverso GlifiKit JSON
    Allora il risultato completo conserva la variante "<variante>"
    E le attese statistiche indipendenti sono JSON <attese>

    Esempi:
      | variante | richiesta | attese |
      | oneSampleT | {"values":[[1e+308,0]]} | {"metrics":{"mean":5e+307,"standard-deviation":7.071067811865475e+307,"statistic":1,"p-value":0.5}} |
      | cohenD | {"values":[[1e+308,0],[0,-1e+308]]} | {"metrics":{"cohen-d":1.4142135623730951,"pooled-standard-deviation":7.071067811865475e+307}} |
      | permutation | {"values":[[1000000000000.0,1000000000001.0],[1000000000002.0,1000000000003.0]],"parameters":{"exact":true}} | {"metrics":{"observed-difference":-2,"extreme-count":2,"p-value":0.3333333333333333}} |
