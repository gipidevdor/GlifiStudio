<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-062 — Digest e generazione query in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-062 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-QRY-001; GS-PROD-001 G3; GS-VER-041 |

## Ambito

Esporre digest QueryAST, generazione e conteggio fonti corrispondenti nei
risultati query Must.

## Controlli

1. Sezione risultati: `queryDigest`, `generation`, `matchedSourceCount`.
2. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
