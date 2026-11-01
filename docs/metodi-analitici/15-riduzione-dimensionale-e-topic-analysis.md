<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Riduzione dimensionale e topic analysis

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-15 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## SVD e PCA

Per `X ∈ ℝ^(m×n)`, `SVD-v1` produce `X=UΣVᵀ` o la migliore approssimazione
troncata di rango `k` nella norma dichiarata. Registra rango richiesto/effettivo,
valori singolari, residuo, backend e gestione dei sottospazi degeneri.

`PCA-SVD-v1` centra ogni colonna di `X`; l'eventuale scaling alla deviazione standard
campionaria è un parametro separato. Applica SVD alla matrice centrata e restituisce
loadings, scores, varianza spiegata `σ_k²/(m-1)` e quota relativa. Colonne costanti
sono conservate o escluse con diagnostica esplicita. PCA non usa la metrica
chi-quadrato della Correspondence Analysis.

## Latent Semantic Analysis

`LSA-SVD-v1` applica una SVD troncata di rango `k` a una matrice termine-unità con
weighting completamente specificato. Conserva `U_k`, `Σ_k`, `V_k`, convenzione
delle coordinate, vocabolario e lineage. “LSA” non implica automaticamente TF-IDF,
normalizzazione o un valore di `k`.

## Non-negative Matrix Factorization

`NMF-Frobenius-v1` richiede `X≥0` e stima `W≥0`, `H≥0` minimizzando
`||X-WH||_F²`. Algoritmo di aggiornamento, inizializzazione, `k`, seed, restart,
regolarizzazione, tolleranza e iterazioni **DEVONO** essere dichiarati. È P1 e può
convergere a minimi differenti; topic ed etichette restano interpretazioni, non dati
osservati.

## Latent Dirichlet Allocation

LDA è una famiglia probabilistica successiva. Un'implementazione **DEVE** dichiarare
numero di topic, prior `α` e `η/β`, unità e vocabolario, algoritmo d'inferenza,
inizializzazione, seed, iterazioni, burn-in/thinning se applicabili e criteri di
convergenza. Perplexity, likelihood e coherence richiedono variante e split dei dati
espliciti. LDA **NON DEVE** essere l'unico percorso di topic analysis.

Embedding e modelli neurali sono rappresentazioni o backend analitici ulteriori.
**NON DEVONO** sostituire la semantica di LSA, NMF, LDA o delle analisi classiche e
devono registrare modello, versione, pooling, normalizzazione, dimensione, lingua,
precisione e disponibilità hardware.

## MDS e metodi non lineari

MDS **PUÒ** essere introdotto specificando metrica/non metrica, funzione di stress,
inizializzazione e convergenza. t-SNE e UMAP sono estensioni esplorative successive:
non costituiscono fondamento architetturale e devono conservare parametri, seed,
backend e avviso che distanze globali o densità apparenti possono non essere
preservate.

## Verifica

- ricostruzione SVD e ortogonalità entro tolleranza;
- PCA centrata, varianza spiegata e invariance alla traslazione;
- confronto LSA su matrice nota;
- non negatività e obiettivo non crescente per la variante NMF applicabile;
- riproducibilità P1 e separazione train/evaluation per modelli probabilistici;
- lineage da fattori, loadings o topic alle unità e ai termini contribuenti.

## Riferimenti scientifici

- Deerwester et al., [Indexing by Latent Semantic Analysis](https://doi.org/10.1002/%28SICI%291097-4571%28199009%2941%3A6%3C391%3A%3AAID-ASI1%3E3.0.CO%3B2-9), 1990.
- Lee e Seung, [Learning the parts of objects by non-negative matrix factorization](https://doi.org/10.1038/44565), 1999.
- Blei, Ng e Jordan, [Latent Dirichlet Allocation](https://www.jmlr.org/papers/v3/blei03a.html), 2003.

## Varianti native candidate

MDS e LDA sono implementate nella libreria con i contratti, i limiti e lo stato
candidate di [GS-MET-001-23](23-operatori-kh-coder.md). La promozione scientifica
resta separata dall'implementazione.
