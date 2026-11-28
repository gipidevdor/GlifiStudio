# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-337 @GS-CMP-332 @macos @planner-contracts
Funzionalità: Ogni intento pubblico produce un piano spiegabile e uno stato persistente coerente
  Sei fonti sintetiche originali alternano TXT e Markdown.
  Target e riferimento contengono tre fonti distinte ciascuno.
  I contratti dichiarati non vengono ricavati dal risultato del planner.

  Contesto:
    Dato la raccolta originale del planner contiene sei fonti e gruppi tre più tre

  @phase-nominal @executable
  Schema dello scenario: L'intento <intento> seleziona ed esegue soltanto le capability dichiarate
    Dato il planner riceve l'intento "<intento>"
    Quando pianifico la raccolta attraverso GlifiKit
    Allora il piano dichiara stato "<stato>" operazioni JSON <operazioni> e ruoli JSON <ruoli>
    E le nove capability includono JSON <capability> con profilo dipendente "<dipendente>"
    E il piano conserva le sei fonti i gruppi e una sola nuova revisione persistita
    E ripianificare riusa identità contenuto e snapshot del piano
    Quando eseguo il piano attraverso il flusso GlifiKit
    Allora il flusso pubblica progresso monotono e un solo completamento coerente
    E una seconda esecuzione riusa i risultati del planner

    Esempi:
      | intento | stato | operazioni | ruoli | capability | dipendente |
      | understand.collection | ready | ["analyzeCorpus"] | ["scope"] | ["profile"] | no |
      | discover.contents | readyWithCaveats | ["analyzeCorpus","analyzeWindowCollocations"] | ["scope","scope"] | ["profile","collocations"] | no |
      | identify.themes | readyWithCaveats | ["analyzeWindowNetwork","analyzeCorrespondence","clusterDocuments"] | ["scope","scope","scope"] | ["network","correspondence","clustering"] | no |
      | characterize.group | readyWithCaveats | ["analyzeCorpus","analyzeCorpus","analyzeCorpus","compareKeyness"] | ["scope","target","reference","comparison"] | ["profile","keyness"] | no |
      | compare.objects | readyWithCaveats | ["analyzeCorpus","analyzeCorpus","compareKeyness","compareSimilarity","compareGroupMetric"] | ["target","reference","comparison","comparison","comparison"] | ["profile","keyness","similarity","groupMetric"] | sì |
      | explore.relationships | readyWithCaveats | ["analyzeAssociation","analyzeWindowCollocations","analyzeWindowNetwork","analyzeCorrespondence"] | ["scope","scope","scope","scope"] | ["association","collocations","network","correspondence"] | no |
      | find.similar | readyWithCaveats | ["clusterDocuments","compareSimilarity"] | ["scope","comparison"] | ["clustering","similarity"] | no |
      | review.completely | readyWithCaveats | ["analyzeCorpus","analyzeCorpus","analyzeCorpus","compareKeyness","analyzeAssociation","analyzeWindowCollocations","analyzeWindowNetwork","analyzeCorrespondence","clusterDocuments","compareSimilarity","compareGroupMetric"] | ["scope","target","reference","comparison","scope","scope","scope","scope","scope","comparison","comparison"] | ["profile","keyness","association","collocations","network","correspondence","clustering","similarity","groupMetric"] | no |

  @phase-nominal @not-executable
  Schema dello scenario: L'intento <intento> spiega la propria indisponibilità senza commit analitici
    Dato il planner riceve l'intento "<intento>"
    Quando pianifico la raccolta attraverso GlifiKit
    Allora il piano dichiara stato "notExecutable" operazioni JSON [] e ruoli JSON []
    E le nove capability includono JSON [] con profilo dipendente "no"
    E il piano conserva le sei fonti i gruppi e una sola nuova revisione persistita
    E ripianificare riusa identità contenuto e snapshot del piano
    Quando eseguo il piano attraverso il flusso GlifiKit
    Allora il piano indisponibile fallisce senza completamenti e senza nuovi artifact

    Esempi:
      | intento |
      | trace.change |
      | explore.object |
      | search.sources |

  @phase-invalid-input
  Scenario: Un intento non valido non produce neppure un artifact di piano
    Dato il planner riceve l'intento "intent.invalid-bdd-canary"
    Quando pianifico la raccolta attraverso GlifiKit
    Allora la richiesta planner fallisce con codice "planner.invalid-intent" categoria "invalidInput" e retry "afterCorrection"

  @phase-pre-cancelled
  Scenario: Un task già cancellato non pianifica né modifica la raccolta
    Dato il planner riceve l'intento "understand.collection"
    Quando pianifico la raccolta con task già cancellato
    Allora la richiesta planner fallisce con codice "operation.cancelled" categoria "cancelled" e retry "newRequest"
