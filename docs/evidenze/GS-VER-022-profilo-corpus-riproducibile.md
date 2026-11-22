<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-022 — Profilo corpus riproducibile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-022 |
| Tipo | Evidenza di verifica analitica, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-008, TV-011, TV-029, TV-030, TV-056, TV-064 e TV-073 |

## Ambito

- analisi di tutte le revisioni TXT/Markdown appartenenti a una generazione
  `.glifi` già verificata;
- conteggi di documenti, extended grapheme cluster, frasi, token lessicali e type;
- frequenze assolute/relative, document frequency, range e `GriesDP-v1`;
- `TTR-v1`, `MSTTR-v1`, `MATTR-v1` e n-grammi di parole per documento;
- matrice documento-termine sparsa con `TF-raw-v1`, `IDF-smooth-v1` e
  `TFIDF-v1`;
- ordinamento canonico, digest SHA-256, identità dei metodi, cancellazione e limiti
  prima della materializzazione;
- parità dei valori attraverso GlifiCore, GlifiKit e l'envelope JSON v1 di
  GlifiCLI `analyze`;
- signpost locale `AnalyzeCorpus` privo di contenuti, query, path e identificatori.

## Procedura

1. analizzare in entrambi gli ordini il corpus sintetico `casa casa mare` / `casa
   città` con revisioni fisse e confrontare l'intero risultato;
2. verificare `D=2`, `N=5`, `V=3`, frequenze, document frequency/range e i valori
   GriesDP noti;
3. verificare `TTR=0,6`, `MSTTR=0,75`, `MATTR=0,875`, bigrammi e celle sparse
   TF-IDF entro tolleranza assoluta `1e-12`;
4. ricalcolare lo stesso seed in Python indipendentemente dal codice prodotto;
5. provare fonte vuota e superamento separato dei limiti su documenti, byte,
   vocabolario, n-grammi e celle non-zero;
6. analizzare una generazione persistita, controllarne identità e immutabilità;
7. attraversare GlifiKit e GlifiCLI, quindi costruire entrambe le app in Debug e
   Release mediante `make verify`.

## Risultato osservato

- 50 test Swift complessivi superati: 45 GlifiCore e 5 GlifiKit;
- il reference seed scientifico viene ricalcolato dal gate senza importare
  GlifiCore e coincide entro `1e-12`;
- input permutati producono lo stesso ordine, digest e risultato;
- corpus lessicalmente vuoto conserva `nil` per le metriche non definite;
- ogni limite produce una failure `analyze` stabile e conserva l'ultima
  generazione committata;
- lo smoke JSON restituisce generazione 2, identità di algoritmo, digest, otto
  token, sette type e sette celle sparse sulle fixture TXT/Markdown;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Questa evidenza isolava il risultato bounded in memoria e non provava segmentazione
documentale, streaming/spill su disco, persistenza in AnalysisDescriptor/DAG/Artifact,
deduplicazione o invalidazione. Keyness GTest/effect size/Benjamini-Hochberg,
metadati temporali, Evidence/Finding/Caveat, planner, visualizzazione ed export
restano aperti. Il seed sintetico non sostituisce corpus gold, review scientifica
esterna, fuzzing o benchmark su hardware reale. Persistenza e riuso sono acquisiti
separatamente da [GS-VER-026](GS-VER-026-analisi-persistenti-riusabili.md).

## Esito

**Superato localmente per la slice `corpus-profile-it-v1` bounded attraverso
GlifiCore, GlifiKit e GlifiCLI.** Non promuove l'intero sistema analitico o il
percorso Must 0.1 a feature complete.
