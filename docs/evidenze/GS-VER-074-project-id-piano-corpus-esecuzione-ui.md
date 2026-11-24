<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-074 — Identità progetto su piano, corpus ed esecuzione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-074 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-061; GS-VER-067; GS-VER-070 |

## Ambito

Allineare la trasparenza di `projectID` nelle sezioni piano, analisi corpus ed
esecuzione Must a quanto già esposto per keyness e query.

## Controlli

1. Sezione piano: `plan.project-id` da `GlifiStudioAnalysisPlanResult.projectID`.
2. Sezione corpus: `corpus.analysis.project-id` da
   `GlifiStudioCorpusAnalysisResult.projectID`.
3. Sezione esecuzione: `execution.project-id` da
   `GlifiStudioAnalysisExecutionResult.projectID`.
4. Checklist candidatura G3 aggiornata a GS-VER-035…072.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
