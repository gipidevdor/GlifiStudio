<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-113 — Intenzioni estese raggiungibili dalle app macOS e iPadOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-113 |
| Tipo | Evidenza di integrazione UI |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task P4 (prima parte) di GS-DOR-002 |

## Ambito

Rende le capability di `planner-v2` raggiungibili dalle app senza nuove superfici di dati:

- il selettore delle intenzioni offre anche `explore.relationships`, `identify.themes` e
  `find.similar`, con titoli localizzati in italiano e inglese;
- la selezione dei gruppi obiettivo e di riferimento compare per tutte le intenzioni che li usano
  (`compare.objects`, `find.similar`, `review.completely`) tramite `usesComparisonGroups`;
- i findings delle famiglie estese sono presentati dalla vista esistente dei findings, che mostra
  messaggio localizzato, argomenti, classe di supporto, dimensioni, motivi e caveat (GS-UX-006):
  sette nuovi messaggi e sette caveat sono nel catalogo (GS-VER-111).

## Procedura e risultato

1. `check-localization.py` valida le nuove chiavi `intent.*` in entrambe le lingue;
2. build Xcode macOS e iPadOS verdi dentro `make verify`;
3. il flusso piano → esecuzione → findings usa le stesse operazioni GlifiKit verificate in
   GS-VER-106 e GS-VER-111.

## Limiti

Non ci sono ancora viste dedicate ai risultati numerici estesi (biplot CA, grafo della rete, tabelle
di collocazione, dendrogramma): i risultati sono raggiungibili come findings e dalla CLI. Queste viste
seguono GS-UX-004 e le specifiche di visualizzazione GS-MET-001-22 in incrementi separati, con verifica
di accessibilità su dispositivo (G4).

## Esito

**Superato localmente: le capability estese sono pianificabili ed eseguibili dalle app e i loro
findings sono presentati con la vista esistente.**
