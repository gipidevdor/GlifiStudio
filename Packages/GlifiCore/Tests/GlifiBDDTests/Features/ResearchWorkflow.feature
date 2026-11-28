# language: it
# SPDX-License-Identifier: BSD-3-Clause
# Original synthetic Italian rows; no external corpus or numerical reference implementation.
# Nominal oracles assert explicit cell addresses, counts, arithmetic and complete retained bytes.

@GS-CMP-332 @GS-CMP-343 @GS-SCN-013 @macos @research-variants
Funzionalità: Le operazioni di ricerca conservano dati preparazione e lavoro avanzato
  CSV, variabili tipizzate e configurazioni italiane mantengono la provenienza originale.
  Gli output acquisiti riaprono senza ricalcolo e raggiungono il rapporto descrittivo.

  @phase-nominal
  Schema dello scenario: Ogni variante nominale verifica dati e provenienza persistenti
    Data la variante di ricerca "<variante>" su tre righe italiane originali
    Quando eseguo la variante di ricerca in fase nominale
    Allora la ricerca verifica dati e provenienza con i fatti JSON <attese>
    E la ricerca riaperta conserva fonti configurazione e output senza nuovi calcoli

    Esempi:
      | variante | attese |
      | state | {"revision":1,"fields.$count":2,"records.$count":3,"subsets.$count":0} |
      | select | {"$count":2} |
      | capture | {"title":"Gruppi sintetici","transportIdentifier":"text-analysis-v1","sourceRevisionIDs.$count":3,"resultSourceRevisionIDs.$count":3,"createdAtUnixMilliseconds":1700000000000} |
      | workbenchCapture | {"title":"Media sintetica","transportIdentifier":"workbench-capture-v1","sourceRevisionIDs.$count":3,"createdAtUnixMilliseconds":1700000000000} |
      | deriveVariable | {"revision":2,"fields.$count":3,"records.$count":3} |
      | saveState | {"revision":2,"fields.$count":2,"records.$count":3,"subsets.$count":1,"preparation.stopwords.$count":2,"preparation.compounds.$count":1} |
      | tabularPreview | {"columns.$count":4,"rows.$count":3,"rows.0.number":2,"rows.0.cells.1":"La città di Roma","rows.2.number":4} |
      | tabularMap | {"records.$count":3,"issues.$count":0,"records.0.identifier":"a","records.0.rowNumber":2,"records.0.textSegments.0.column":2} |
      | tabularImport | {"importedCount":1,"sourceRevisionIDs.$count":1,"issues.$count":0} |
      | tabularSource | {"dataset.records.$count":3,"dataset.records.0.identifier":"a","dataset.mapping.textColumns":[2],"dataset.mapping.identifierColumn":1} |
      | savedList | {"$count":1,"0.title":"Gruppi sintetici","0.sourceRevisionIDs.$count":3} |
      | savedRead | {"title":"Gruppi sintetici","transportIdentifier":"text-analysis-v1","sourceRevisionIDs.$count":3,"resultSourceRevisionIDs.$count":3} |
      | savedRun | {"title":"Gruppi sintetici","transportIdentifier":"text-analysis-v1","sourceRevisionIDs.$count":3,"createdAtUnixMilliseconds":1700000000000} |
      | savedExport | {"schemaIdentifier":"studio.glifi.artifact.saved-research-analysis.v1","schemaVersion":1,"title":"Gruppi sintetici","sourceRevisionIDs.$count":3,"sourceContentDigests.$count":3} |
      | savedInvestigation | {"investigation.selectedFindingIDs.$count":1} |

  @phase-invalid-input
  Schema dello scenario: Ogni variante rifiuta parametri sconosciuti senza cambiare il progetto
    Data la variante di ricerca "<variante>" su tre righe italiane originali
    Quando eseguo la variante di ricerca in fase JSON-invalido
    Allora la ricerca fallisce con codice "command.unknown-field" e categoria "invalidInput" senza modifiche

    Esempi:
      | variante |
      | state |
      | select |
      | capture |
      | workbenchCapture |
      | deriveVariable |
      | saveState |
      | tabularPreview |
      | tabularMap |
      | tabularImport |
      | tabularSource |
      | savedList |
      | savedRead |
      | savedRun |
      | savedExport |
      | savedInvestigation |

  @phase-pre-cancelled
  Schema dello scenario: Ogni variante precancellata conserva l'ultima generazione
    Data la variante di ricerca "<variante>" su tre righe italiane originali
    Quando eseguo la variante di ricerca in fase precancellata
    Allora la ricerca fallisce con codice "command.cancelled" e categoria "cancelled" senza modifiche

    Esempi:
      | variante |
      | state |
      | select |
      | capture |
      | workbenchCapture |
      | deriveVariable |
      | saveState |
      | tabularPreview |
      | tabularMap |
      | tabularImport |
      | tabularSource |
      | savedList |
      | savedRead |
      | savedRun |
      | savedExport |
      | savedInvestigation |

  @research-workflow
  Scenario: Un dataset italiano diventa corpus preparato variabile derivata e rapporto riapribile
    Data la variante di ricerca "state" su tre righe italiane originali
    Quando salvo preparazione italiana e sottoinsieme con filtro testuale e variabili
    E acquisisco il risultato nativo e JSON e ne derivo una variabile tracciata
    Allora revisioni obsolete e risultati incoerenti sono rifiutati senza perdita di lavoro
    Quando collego l'output al planner e al rapporto esportando gli stessi byte
    Allora la riapertura ripristina corpus preparazione selezione variabile e rapporto acquisito

  @research-large-dto
  Scenario: Anteprima e stato grandi rientrano nel flusso di ricerca tramite file JSON
    Data la variante di ricerca "state" su tre righe italiane originali
    Quando trasporto anteprima e stato oltre un MiB tramite file JSON espliciti
    Allora mapping e stato grandi conservano parità nativa provenienza e riapertura
