<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-041 — ValidationManifest query, progress import e preview export

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-041 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-VAL-001; GS-QRY-001; GS-PROD-001 |

## Ambito

Completare i ValidationManifest del nucleo Must con `glifi-query-v1` e migliorare
il feedback UI su import multiplo e anteprima Markdown dell'export.

## Controlli

1. `Fixtures/Validation/v1/glifi-query-v1.json` con V0–V4 `pass`.
2. Gate `check-fixtures.py` richiede il manifesto query.
3. Contatore import `completed/total` nella status bar.
4. Lettura `report.md` dopo export come anteprima locale.
5. `make quality-static` sul tip.

## Risultato

**Superato** per contratto e wiring. Studi UX e `make verify` Xcode restano aperti.

## Limiti

Budget Actions in GS-WVR-004.
