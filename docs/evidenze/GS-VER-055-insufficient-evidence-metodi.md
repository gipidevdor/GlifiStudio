<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-055 — InsufficientEvidence dettagliato e metodi Evidence

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-055 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-030 |

## Ambito

Esporre motivi e Caveat di `insufficientEvidence` e i methodIdentifiers delle
Evidence nel dettaglio Finding.

## Controlli

1. Vista Findings con reasons e Caveat severity quando non ci sono Findings.
2. Evidence: fino a 6 `methodIdentifiers` selezionabili.
3. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
