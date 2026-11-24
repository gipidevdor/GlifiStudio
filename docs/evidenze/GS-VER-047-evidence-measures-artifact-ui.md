<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-047 — Misure Evidence e lineage Artifact in UI Must

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-047 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-API-001; CMP-012 |

## Ambito

Esporre le misure tipizzate delle Evidence nel dettaglio Finding, l'Artifact del
confronto keyness e allineare CMP-012 alle superfici UI Must recenti.

## Controlli

1. Finding → Evidence: `validity`, fino a 8 misure, caveat low-expected-count.
2. Keyness: `artifactID` selezionabile.
3. CMP-012: code `Apps/Shared/StudioHome*` ed evidenze GS-VER-043…046.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI e tracciabilità CMP. Runtime Xcode aperto.

## Limiti

Budget Actions: GS-WVR-004.
