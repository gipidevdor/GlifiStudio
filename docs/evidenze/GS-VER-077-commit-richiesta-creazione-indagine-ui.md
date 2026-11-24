<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-077 — Commit e richiesta creazione indagine in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-077 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-068; GS-VER-074; GS-VER-076 |

## Ambito

Esporre `projectID` e `generation` del commit Kit
`GlifiStudioInvestigationResult` e la richiesta versionata di creazione
indagine usata dall'azione Must.

## Controlli

1. Model conserva `lastInvestigationProjectID` / `lastInvestigationGeneration`
   dopo `createInvestigation`.
2. Model conserva `lastInvestigationCreationRequest` (schema, lingua, Artifact,
   Finding selezionati o selezione implicita).
3. Sezioni `investigation.saved` e `investigation.creation-request` in UI.
4. Checklist candidatura G3 aggiornata a GS-VER-035…075.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI/Model e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
