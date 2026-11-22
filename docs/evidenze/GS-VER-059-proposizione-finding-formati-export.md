<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-059 — Proposizione Finding tipizzata e formati export in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-059 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-032 |

## Ambito

Esporre la struttura tipizzata della proposizione Finding (type/subject/
predicate/object/scope/direction, argomenti messaggio) e i formati di export
Must (JSON/Markdown/CSV/PDF) nella UI.

## Controlli

1. Sezione proposizione: ID, famiglia, slot tipizzati, rule set, messageArguments.
2. Export: elenco formati allineato a `exportInvestigation`.
3. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
