<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-063 — Stato terminale e progresso esecuzione in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-063 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-050; GS-VER-028 |

## Ambito

Esporre in UI Must i metadati terminali dell'esecuzione del piano (stato,
profilo operativo, parallelismo, unità di lavoro, generazioni, operation ID) e
il dettaglio del progresso (fase, unità, qualità stima, passo corrente), oltre
ai nodi di analisi e agli schemi degli Artifact prodotti.

## Controlli

1. Sezione `execution.progress` con fase, unità, estimateQuality, planStep,
   operationID.
2. Sezione `execution.terminal` con terminalState, planStatus, operatingProfile,
   parallelism, work units, generation/sourceGeneration, operationID.
3. Artifact: plan/interpretation analysis node; per artifact: planStep, schema,
   analysisNode.
4. Chiavi `execution.*` localizzate `it`/`en`.
5. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode e audit dispositivo aperti.
