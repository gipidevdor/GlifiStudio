<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-068 — Richiesta export e progresso query Must in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-068 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-046; GS-VER-059 |

## Ambito

Esporre la richiesta scientifica di export (schema, head event, locale, fuso,
formati) e includere la Query nel progresso percorso Must in Overview.

## Controlli

1. Model conserva `lastExportRequest`; sezione `export.request` in UI.
2. Overview: riga `home.must-progress.query` con `mustPathHasQuery`.
3. Checklist candidatura G3 aggiornata a GS-VER-035…068.
4. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
