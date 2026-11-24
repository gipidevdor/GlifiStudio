<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-081 — Ordine n-grammi e byte fonte Evidence in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-081 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-046; GS-VER-058 |

## Ambito

Esporre l'ordine (`values.count`) degli n-grammi corpus Kit e i metadati byte
della fonte Evidence aperta (`GlifiStudioSourceText.byteCount` e range).

## Controlli

1. Ogni n-gramma mostra ordine oltre alla frequenza.
2. Sezione fonte Evidence: revisione, byte totali e range aperti.
3. Checklist candidatura G3 aggiornata a GS-VER-035…079.
4. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
