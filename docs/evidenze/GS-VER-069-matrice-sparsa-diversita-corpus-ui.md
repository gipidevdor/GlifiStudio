<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-069 — Matrice sparsa e diversità corpus in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-069 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-046; GS-VER-067 |

## Ambito

Esporre i contratti della matrice sparsa Kit (`count`/`tf`/`idf`/`tfidf`,
revisioni riga, celle campione), l'unità di carattere, le revisioni sorgente
analizzate e gli identificatori MSTTR/MATTR nella UI Must.

## Controlli

1. Sezione `corpus.analysis.matrix` con identificatori e anteprima celle.
2. `characterUnitIdentifier`, `sourceRevisionIDs`, `msttrIdentifier`,
   `mattrIdentifier` visibili dopo `analyzeCorpus`.
3. Checklist candidatura G3 aggiornata a GS-VER-035…069.
4. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
