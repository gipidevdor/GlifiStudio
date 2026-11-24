<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-045 — Trasparenza ranking Findings e diversità corpus in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-045 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-030; GS-VER-022 |

## Ambito

Rendere trasparenti in UI Must i fattori di ranking editoriale e la policy di
supporto dei Findings, più le misure di diversità lessicale del profilo corpus.

## Controlli

1. Dettaglio Finding: assessment (`supportClass`, `policyIdentifier`, rationale)
   e sezione ranking (intent, effect, coverage, stability, novelty,
   non-redundancy, lineage).
2. Sezione diversità TTR/MSTTR/MATTR dopo `analyzeCorpus`.
3. Chiavi `finding.ranking.*`, `finding.assessment`, `corpus.diversity.*` in
   `it`/`en`.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI. CMP-018 resta `blocked` finché dataset di ranking e
validazione empirica non sono disponibili.

## Limiti

Budget Actions: GS-WVR-004. Nessun punteggio globale inventato: solo fattori
lessicografici già esposti da GlifiKit.
