<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-039 — Salto KWIC→fonte e teste di indagine in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-039 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001 passi 5–8; GS-API-001; GS-VER-035 |

## Ambito

Estendere il percorso Must UI con caricamento testo fonte da revisione
immutabile, evidenziazione UTF-8, teste di indagine multiple, cancellazione
esecuzione e import multiplo.

## Controlli

1. `GlifiStudioProjectSession.sourceText(sourceRevisionID:)` in GlifiKit.
2. Contract test Kit: highlight `fonte` sugli offset sorgente.
3. UI: selezione match KWIC, pane fonte, heads, cancel, multi-import.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring e contratto. Runtime VoiceOver/dispositivo e
`make verify` Xcode restano aperti.

## Limiti

Budget Actions remoto ancora in GS-WVR-004.
