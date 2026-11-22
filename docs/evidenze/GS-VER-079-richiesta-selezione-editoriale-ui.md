<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-079 — Richiesta selezione editoriale in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-079 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-068; GS-VER-077 |

## Ambito

Esporre la richiesta Kit versionata di revisione della selezione editoriale
(`GlifiStudioInvestigationSelectionRequest`) e aggiornare `projectID` /
`generation` del commit risultante.

## Controlli

1. Model conserva `lastInvestigationSelectionRequest` dopo
   `reviseInvestigationSelection`.
2. Sezione `investigation.selection-request` con schema, predecessore, motivo e
   Finding selezionati.
3. Commit aggiorna `lastInvestigationProjectID` / `lastInvestigationGeneration`.
4. Checklist candidatura G3 aggiornata a GS-VER-035…077.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI/Model e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
