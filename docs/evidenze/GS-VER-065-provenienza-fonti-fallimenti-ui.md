<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-065 — Provenienza fonti e fallimenti strutturati in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-065 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-DAT-001; GS-API-001; GS-PROD-001 G3; GS-VER-035 |

## Ambito

Esporre digest/byte/ID delle revisioni fonte e del profilo importato, l'ID
progetto, e i campi strutturali di `GlifiStudioFailure` (code, category,
operation, retryDisposition, retainedState) nella status bar Must.

## Controlli

1. Sezione fonti: `sourceID`, `contentDigest`, `byteCount` per revisione.
2. Profilo import: `contentDigest`, `utf8ByteCount`, `surfaceTokenCount`.
3. Progetto: `projectID`.
4. Model conserva `lastFailure`; status bar mostra i campi macchina.
5. Chiavi localizzate `it`/`en`; `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
