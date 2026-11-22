<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-075 — Vocabolario matrice e bound opzioni analisi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-075 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-069; GS-VER-070 |

## Ambito

Esporre un campione del vocabolario della matrice sparsa Kit e i bound delle
opzioni `GlifiStudioCorpusAnalysisOptions` / `GlifiStudioKeynessOptions`
effettivamente usate dalle azioni Must.

## Controlli

1. Anteprima `matrix.terms` (fino a 16 forme) oltre al conteggio.
2. Sezione limiti corpus: finestra diversità, n-gram sizes, massimi documenti/
   byte/vocabolario/n-grammi/celle.
3. Sezione limiti keyness: `maximumHypothesisCount` e soglia expected-count.
4. Model conserva `lastCorpusOptions` / `lastKeynessOptions` dopo le azioni.
5. Checklist candidatura G3 aggiornata a GS-VER-035…073.
6. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI/Model e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
