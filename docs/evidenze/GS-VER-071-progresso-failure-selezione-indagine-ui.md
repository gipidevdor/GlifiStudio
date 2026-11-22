<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-071 — Progresso esecuzione, argomenti failure e selezione indagine

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-071 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-063; GS-VER-065 |

## Ambito

Esporre `revision` e `analysisNodeID` del progresso di esecuzione, gli
`arguments` strutturati di `GlifiStudioFailure` e gli ID Finding selezionati
dell'indagine nella UI Must.

## Controlli

1. Sezione progresso: `execution.progress.revision` e
   `execution.progress.analysis-node`.
2. Status bar: argomenti macchina del failure quando presenti.
3. Storia indagine: elenco `selectedFindingIDs` oltre al conteggio.
4. Checklist candidatura G3 aggiornata a GS-VER-035…071.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
