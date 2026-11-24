<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Progetto, corpus e indagine

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-02 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-16 |
| Approvazione | Relazioni approvate; prima slice di persistenza decisa da ADR-0021 |
| Documento padre | [GS-UX-001](README.md) |

## Relazioni fondamentali

```text
Project
├── fonti e documenti
├── schemi e metadati
├── 0..* Corpus
└── 0..* Investigation
       ├── Question + 1..* AnalyticalIntent
       ├── 1..* riferimento a Corpus/versione/selezione
       ├── 1..* revisione di AnalysisPlan → AnalysisDAG
       ├── Evidence → Finding ↔ Caveat
       ├── InvestigationHistory
       └── selezione editoriale → Report
```

`Project`, `Corpus` e `Investigation` sono concetti normativi. ADR-0021 fissa la
prima rappresentazione persistente della storia; Corpus completo e ulteriori
eventi dell'indagine restano decisioni implementative aperte.

## Project

Il progetto Glifi Studio è il contenitore persistente e il confine di proprietà,
sicurezza, configurazione e compatibilità. Conserva fonti o riferimenti, documenti,
metadati, configurazioni linguistiche, corpus, indagini e artefatti. Un progetto
**NON DEVE** coincidere con una finestra, una cartella o un pathname.

## Corpus

Un corpus è una vista logica e versionata su documenti o segmenti appartenenti allo
stesso progetto. Dichiara selezione, unità analitica, schema dei metadati, inclusioni,
esclusioni e ordinamento semantico. Più corpus possono riferirsi alle stesse fonti
senza duplicarle. Una modifica che cambia l'appartenenza produce una nuova versione
e non riscrive il lineage delle evidenze precedenti.

## Investigation

L'indagine è l'unità cognitiva del percorso di ricerca. Deve poter associare:

- domanda originale e interpretazione canonica;
- obiettivo e intenzioni analitiche;
- corpus, versioni o selezioni studiate;
- revisioni del piano analitico e relativo DAG;
- evidenze, findings e caveat;
- approfondimenti eseguiti o proposti;
- cronologia navigabile e diramazioni;
- note, materiali conservati e selezione per la relazione.

Un'indagine appartiene a un solo progetto. Può confrontare più corpus o selezioni
compatibili dello stesso progetto; un confronto tra progetti richiede un contratto
esplicito futuro su identità, autorizzazioni e portabilità.

## Concetti associati

| Concetto | Semantica minima |
| --- | --- |
| `Question` | Testo originale, lingua, autore, tempo e interpretazione canonica versionata |
| `AnalyticalIntent` | Obiettivo tipizzato indipendente dalla frase localizzata |
| `AnalysisPlan` | Decisione riproducibile su che cosa calcolare e perché |
| `AnalysisDAG` | Dipendenze computazionali effettive del piano secondo GS-MET-001-02 |
| `Evidence` | Osservazione o risultato derivato da un metodo definito |
| `Finding` | Proposizione comprensibile sostenuta da evidenze |
| `Caveat` | Limite applicabile a dato, evidenza, finding o piano |
| `SourceReference` | Riferimento risolvibile a documento, segmento, occorrenza o regione |
| `MethodDescription` | Descrizione localizzabile di metodo, variante, parametri e limiti |
| `InvestigationHistory` | Grafo persistente degli eventi cognitivi e analitici |
| `Report` | Proiezione editoriale versionata, non fonte di verità autonoma |

## Invarianti

- Un `Finding` persistito ha almeno un'evidenza risolvibile oppure è marcato come
  nota o ipotesi della persona, mai come risultato del sistema.
- Cambiare domanda, corpus o parametro non altera retroattivamente evidenze già
  identificate: crea una nuova revisione o diramazione.
- Stato della finestra, selezione corrente e contenuto persistente dell'indagine
  restano livelli distinti.
- Titoli e testi localizzati non costituiscono identità persistenti.
- Eliminare una vista ricostruibile non elimina le evidenze o le fonti autorevoli.
