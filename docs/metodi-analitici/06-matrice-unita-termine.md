<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Matrice unità-termine

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-06 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-28 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Definizione

Una matrice unità-termine di conteggi è `X ∈ ℕ₀^(m×n)`, dove ogni riga identifica
esattamente un'unità analitica e ogni colonna esattamente un type del vocabolario.
`X_ij` è il numero di occorrenze del termine `j` nell'unità `i`. La matrice
documento-termine è il caso in cui l'unità è un documento.

Le unità ammesse comprendono documento, segmento, autore, categoria, intervallo
temporale e gruppi definiti dall'utente, purché funzione di appartenenza e politica
per appartenenze multiple o mancanti siano esplicite.

## Identità semantica

L'artefatto **DEVE** conservare:

- identità e versione del corpus e della selezione;
- lista ordinata e stabile di `UnitID`, tipo dell'unità e definizione del gruppo;
- lista ordinata di `TermID`, vocabolario e relativa versione;
- tokenizzazione, normalizzazione, lemma/forma, stopword e filtri;
- schema del valore, orientamento, dimensioni e numero di non-zero;
- lineage da riga, colonna e cella alle osservazioni contribuenti.

Righe e colonne vuote **NON DEVONO** essere rimosse silenziosamente. La rimozione è
una trasformazione separata che registra identità escluse e motivo.

## Rappresentazione e accesso

### Preparazione italiana condivisa

Il profilo corpus e le analisi che ne dipendono leggono la configurazione
persistente di [GS-API-005](../api/05-stato-di-ricerca.md). La matrice conta le
basi effettive, comprese le espressioni composte osservate, e non riscrive le
fonti. Il contratto di tokenizzazione comprende il digest canonico della
preparazione; la configurazione vuota mantiene il contratto storico
`it-token-v1`. Un cambiamento semantico produce un nuovo nodo del profilo e
quindi nuove identità per i discendenti: i vecchi artefatti restano storici e
non soddisfano la richiesta con la nuova preparazione. Il riordino o la
duplicazione delle stesse voci lessicali non produce una nuova identità.

I medesimi termini preparati alimentano sequenze lessicali, n-grammi,
diversità, riassunti estrattivi, BM25 e finestre di collocazione/rete.
Gli intervalli di token e composti restano coordinate UTF-8 del testo estratto;
la trasformazione non sostituisce gli intervalli con quelli di lemmi o stem.

### Contratto dello storage

La rappresentazione logica è indipendente dallo storage. CSR, CSC, coordinate,
blocchi persistiti o iteratori sono backend ammessi. Gli zeri impliciti sono zeri
esatti, non valori mancanti. Ordine e tipo degli indici, precisione dei valori,
endianness e formato sono versionati.

Le operazioni **DEVONO** poter leggere righe, colonne e blocchi senza materializzare
l'intera matrice. Costruzione e aggregazione **DEVONO** supportare spill su disco o
merge esterno per input oltre memoria. Una vista lazy **DEVE** produrre gli stessi
valori della materializzazione di riferimento.

## Trasformazioni

Ponderazione, normalizzazione, selezione dei termini, pruning e trasposizione
producono nuovi nodi del DAG. Non modificano la matrice di conteggi autorevole.
Operazioni su matrici di versioni o vocabolari diversi richiedono un allineamento
esplicito che registra unione/intersezione e mapping degli identificatori.

## Invarianti e verifica

- `X_ij ≥ 0` e intero per la matrice di conteggi;
- somma della riga uguale ai token inclusi dell'unità;
- `df(j)` uguale al numero di non-zero nella colonna `j`;
- somma globale uguale a `N` per partizioni disgiunte ed esaustive;
- equivalenza tra costruzione in memoria, streaming e a blocchi;
- round-trip sparso senza alterare valori, identità o ordine canonico;
- risoluzione campionata di celle non-zero verso le occorrenze sorgente.
