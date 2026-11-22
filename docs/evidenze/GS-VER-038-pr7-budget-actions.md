<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-038 — Compensazione locale PR #7 con budget Actions esaurito

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-038 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-WVR-004; PR #7 |

## Ambito

Registrare che i fallimenti CI della PR #7 sono dovuti al budget Actions e che i
gate statici locali sul tip sono verdi.

## Controlli

1. Annotazioni check-run: “Actions budget is preventing further use” su
   `static-quality`, `format-check` e `app-store-baseline` (zero step).
2. `make quality-static` superato sul tip del branch.

## Risultato

**Superato** come compensazione documentale. Non sostituisce `make verify` su
Xcode 27 né i workflow remoti dopo il ripristino del budget.

## Limiti

Deroga GS-WVR-004 con scadenza 2026-09-22.
