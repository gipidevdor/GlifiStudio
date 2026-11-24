<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-043 — Analisi corpus in UI e ValidationManifest planner

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-043 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-VAL-001; GS-PROD-001 G3; GS-API-001; GS-ANA-001 |

## Ambito

Esporre `analyzeCorpus` nella UI Must delle fonti, chiudere il quinto
ValidationManifest Must (`planner-mvp-v1`) e allineare il catalogo fixture.

## Controlli

1. `StudioHomeModel.analyzeCorpusNow()` chiama GlifiKit e persiste
   `lastCorpusAnalysis` con metriche e top forms.
2. Sezione fonti con `action.analyze-corpus` e chiavi `corpus.analysis.*` /
   `progress.analyzing-corpus` in `it`/`en`.
3. `Fixtures/Validation/v1/planner-mvp-v1.json` V0–V4 `pass` e catalogo a 5
   manifest; `Scripts/check-fixtures.py` richiede l'id planner.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI e contratto ValidationManifest. Runtime Xcode e audit
dispositivo restano aperti (G4).

## Limiti

Budget Actions: GS-WVR-004. `make verify` richiede Xcode 27.
