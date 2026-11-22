<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-021 — Markdown e SpanMap

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-021 |
| Tipo | Evidenza di verifica di estrazione e lineage testuale |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-002, TV-003, TV-007, TV-051, TV-060 e TV-073 |

## Ambito

- import strict UTF-8 Markdown con o senza BOM e conservazione dei byte originali;
- estrazione `md-extract-v1` senza esecuzione di HTML, link o codice;
- heading, quote/liste, enfasi, link/immagini, autolink, codice inline/fenced,
  commenti/elementi HTML, entità, separatori e delimiter table;
- `SpanMap` totale `extractedUTF8` → `sourceBytes` con segmenti exact,
  derivational e synthetic validati;
- propagazione di tutti gli intervalli sorgente attraverso query, GlifiKit ed
  envelope JSON CLI;
- limite di 64 MiB, profondità 32, cancellazione cooperativa e budget lineare di
  lookahead contro input avversari;
- selezione TXT/Markdown nel file importer condiviso macOS/iPadOS e localizzazione
  italiana/inglese coerente.

## Procedura

1. estrarre una fixture con struttura block/inline, HTML, codice ed entità e
   confrontare il testo visibile;
2. risolvere una phrase che attraversa enfasi e link in intervalli sorgente
   discontinui e ricostruirne la superficie;
3. verificare BOM ed entità derivational senza falsificare coordinate exact;
4. rifiutare SpanMap incompleti e richieste fuori rappresentazione;
5. sottoporre 10.000 aperture link senza chiusura e osservare la failure bounded;
6. incorporare Markdown in `.glifi`, riaprire, interrogare e verificare coordinate
   estratte e `sourceRanges` sui byte originali;
7. ripetere import/query tramite GlifiCLI e costruire entrambe le app in
   configurazione Debug/Release con `make verify`.

## Risultato osservato

- 46 test Swift complessivi superati: 41 GlifiCore e 5 GlifiKit;
- markup e destinazioni non entrano nel profilo, mentre il contenuto visibile e il
  codice fenced restano analizzabili;
- entità e BOM mantengono la relazione dichiarata verso i byte originali;
- la query CLI sulla fixture restituisce `fonte` in `[14, 19)` extractedUTF8 e
  `[64, 69)` sourceBytes;
- il caso di lookahead avversario termina come `insufficientResources`;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

`md-extract-v1` è una baseline controllata, non ancora una dichiarazione di piena
compatibilità CommonMark. Il document model a blocchi, reference link shortcut,
struttura tabellare completa, normalizzazione con SpanMap composto, streaming e
persistenza content-addressed della rappresentazione restano aperti. La fixture è
un seed sintetico e non sostituisce corpus CommonMark, fuzzing o benchmark su
hardware reale.

## Esito

**Superato localmente per importazione/profilo Markdown, SpanMap e lineage query
attraverso GlifiCore, GlifiKit, GlifiCLI e app condivisa.** Non promuove il document
model o l'intero percorso Must a feature complete.
