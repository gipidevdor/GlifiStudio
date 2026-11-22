<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-054 — Navigazione percorso Must e severità Caveat

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-054 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001 G3; GS-UX-001; GS-ANA-001 |

## Ambito

Rendere navigabile il progresso Must dall'Overview e mostrare la severità dei
Caveat nel dettaglio Finding.

## Controlli

1. Righe progresso Must aprono la sezione correlata con `accessibilityHint`.
2. Caveat espongono `severity` localizzata (`information`/`warning`/`blocking`).
3. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI/a11y strutturale.

## Limiti

Budget Actions: GS-WVR-004. VoiceOver su dispositivo aperto.
