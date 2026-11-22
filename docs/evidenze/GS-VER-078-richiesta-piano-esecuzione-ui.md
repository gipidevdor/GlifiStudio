<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-078 — Richiesta piano ed esecuzione in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-078 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-068; GS-VER-074; GS-VER-077 |

## Ambito

Conservare ed esporre la `GlifiStudioAnalysisPlanRequest` effettivamente inviata
alle azioni Must di piano e di esecuzione (intento, budget, scope e gruppi).

## Controlli

1. Model conserva `lastPlanRequest` in `planInvestigation` e `executePlan`.
2. Sezione `plan.request` visibile anche senza `planResult` (solo execute).
3. Conteggio e elenco revisioni di scope/target/reference oltre al budget.
4. Checklist candidatura G3 aggiornata a GS-VER-035…076.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI/Model e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
