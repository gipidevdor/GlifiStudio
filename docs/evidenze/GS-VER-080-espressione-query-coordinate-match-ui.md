<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-080 — Espressione query e coordinate match in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-080 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-062; GS-VER-066 |

## Ambito

Conservare l'espressione Query effettivamente valutata e rendere esplicite
identità e coordinate UTF-8 di ogni `GlifiStudioQueryMatch` nella UI Must.

## Controlli

1. Model conserva `lastQueryExpression` dopo `runQuery`.
2. Sezione risultati: espressione, digest, conteggi e `projectID`/generation.
3. Ogni match espone `id`, `sourceRevisionID`, `coordinateSpace`,
   `startUTF8`, `endUTF8`.
4. Checklist candidatura G3 aggiornata a GS-VER-035…078.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI/Model e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
