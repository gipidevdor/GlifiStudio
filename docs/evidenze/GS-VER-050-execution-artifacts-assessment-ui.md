<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-050 — Artifact di esecuzione e dimensioni assessment in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-050 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-028; GS-VER-030 |

## Ambito

Esporre in UI Must gli Artifact prodotti dall'esecuzione del piano, i metadati
dell'interpretazione (catalogo regole, ranking, suppression) e le dimensioni
valutate dalla SupportPolicy.

## Controlli

1. Sezioni `execution.artifacts` e `execution.interpretation` dopo
   `executionResult`.
2. Dimensioni `assessment.dimensions` con valore e outcome nel dettaglio Finding.
3. Chiavi `execution.*` localizzate `it`/`en`.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI. Runtime Xcode aperto.

## Limiti

Budget Actions: GS-WVR-004.
