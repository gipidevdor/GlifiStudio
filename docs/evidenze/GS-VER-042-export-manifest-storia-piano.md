<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-042 — Export ValidationManifest, storia indagine e piano localizzato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-042 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-VAL-001; GS-PROD-001 G3; GS-API-001 |

## Ambito

Chiudere il quarto ValidationManifest Must (export), mostrare la catena eventi
dell'indagine e localizzare stati/applicabilità del piano; aggiornare CMP-012.

## Controlli

1. `Fixtures/Validation/v1/scientific-export-v1.json` V0–V4 `pass`.
2. Sezione storia `eventIDs` e conteggio findings selezionati in UI.
3. Chiavi `plan.status.*` e `plan.applicability.*` in `it`/`en`.
4. CMP-012 → `implemented` con evidenze UI Must.
5. `make quality-static` sul tip.

## Risultato

**Superato** per contratto e wiring. G3 resta candidato finché audit dispositivo e
studi UX non chiudono i blocked G4.

## Limiti

Budget Actions: GS-WVR-004.
