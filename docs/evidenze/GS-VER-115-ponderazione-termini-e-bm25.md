<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-115 — Varianti TF, IDF, normalizzazioni di riga e BM25-v1

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-115 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task Q1 di GS-DOR-003 |

## Ambito

Completa RF-030 secondo GS-MET-001-07:

- `GlifiTermWeighting`: `TF-raw-v1`, `TF-binary-v1`, `TF-L1-v1`, `TF-max-v1`, `TF-augmented-v1`,
  `TF-sublinear-v1`; `IDF-none-v1`, `IDF-unsmoothed-v1`, `IDF-smooth-v1`; `RowNorm-none-v1`,
  `RowNorm-L1-v1`, `RowNorm-L2-v1`; `BM25-v1` con precondizioni `N>0`, `avgdl>0`, `k1>0`,
  `0≤b≤1`;
- Artifact persistiti e riusabili `corpus-term-weighting-v1` e `corpus-bm25-ranking-v1`, con
  schema, parametri e base del logaritmo nel descrittore;
- `analyzeTermWeighting` e `rankDocumentsBM25` in GlifiKit, comandi `glifi weighting` e
  `glifi bm25` con envelope JSON v1.

## Procedura e risultato

1. `termFrequencyVariantsMatchR`: le sei varianti TF su una matrice 4×4 con una riga vuota
   coincidono con le formule indipendenti di `Tests/Oracles/R/weighting.R` entro `1e-12` relativo;
2. `inverseDocumentFrequencyAndBM25MatchR`: IDF non smussata e smussata, TF sublineare × IDF non
   smussata normalizzata L2, TF aumentata × IDF smussata normalizzata L1, idf BM25 e punteggi
   BM25 per `(k1, b) = (1,2; 0,75)` e `(2; 0)` coincidono con R; una colonna fuori vocabolario
   contribuisce zero e la riga vuota ha punteggio zero;
3. `weightingInvariantsAndPreconditions`: righe L1 e L2 non vuote a norma uno, riga vuota nulla,
   `df=N` (IDF non smussata 0, smussata 1, idf BM25 positiva e finita), rifiuto tipizzato di
   `df=0` per la variante non smussata, di `k1≤0` e di una collezione senza token;
4. `termWeightingAndBM25ArePersistedAndReused`: gli Artifact sono riusati per get-or-store; query
   con maiuscole, ripetizioni e ordine diversi producono lo stesso nodo; il termine fuori
   vocabolario è conservato con `isInVocabulary=false`; il ranking è decrescente con spareggio
   per identità; una query senza token lessicali fallisce con `bm25.empty-query`;
5. contract test CLI in `verify.sh`: `weighting` con L2 produce righe a norma uno; `bm25` ordina
   i documenti e segnala il termine fuori vocabolario;
6. `make check-oracles` rilegge le righe `TF_*`, `IDF_*`, `TFIDF_*`, `BM25_*` e le collega ai
   letterali dei test.

## Limiti

La normalizzazione di riga opera sui pesi TF×IDF; varianti come la normalizzazione pivotata o
BM25F richiedono nuovi identificatori. BM25 è un punteggio di ranking, non una probabilità.

## Esito

**Superato localmente: RF-030 è completo per le varianti definite da GS-MET-001-07.**
