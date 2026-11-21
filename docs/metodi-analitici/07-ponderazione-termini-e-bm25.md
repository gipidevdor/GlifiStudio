<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Ponderazione dei termini e BM25

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-07 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.1 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Convenzioni

Sia `x_dt ≥ 0` la frequenza del termine `t` nell'unità `d`, `N` il numero di unità
e `df_t` il numero di unità con `x_dt > 0`. Tutte le varianti usano logaritmo
naturale. Un termine assente produce peso zero salvo formula che dichiari
esplicitamente il contrario.

## Term frequency

| ID variante | Formula per `x = x_dt` |
| --- | --- |
| `TF-raw-v1` | `tf(x)=x` |
| `TF-binary-v1` | `tf(x)=1` se `x>0`, altrimenti `0` |
| `TF-L1-v1` | `tf(x)=x/Σ_j x_dj`; riga vuota tutta zero |
| `TF-max-v1` | `tf(x)=x/max_j x_dj`; riga vuota tutta zero |
| `TF-augmented-v1` | `0,5+0,5x/max_j x_dj` se `x>0`, altrimenti `0` |
| `TF-sublinear-v1` | `1+ln(x)` se `x>0`, altrimenti `0` |

Il nome “TF normalizzato” senza una delle varianti o una formula equivalente
versionata **NON DEVE** essere persistito.

## IDF e TF-IDF

Le varianti iniziali sono:

```text
IDF-unsmoothed-v1(t) = ln(N / df_t), definita per N>0 e 0<df_t≤N
IDF-smooth-v1(t)     = ln((N + 1) / (df_t + 1)) + 1, per N>0
TFIDF-v1(d,t)        = TF_variant(d,t) × IDF_variant(t)
```

`df_t=0` può esistere soltanto per un vocabolario esterno; la variante unsmoothed
lo rifiuta, quella smoothed lo calcola ma conserva che il termine non è osservato.
Una successiva normalizzazione L1 o L2 della riga è un parametro separato e
versionato. Formula TF, formula IDF, smoothing, base del logaritmo e normalizzazione
**DEVONO** essere nel descrittore.

## BM25-v1

Per una query `q` e un'unità di retrieval `d`:

```text
idf(t) = ln(1 + (N - df_t + 0,5) / (df_t + 0,5))
score(d,q) = Σ_{t∈unique(q)} idf(t) ×
             [f(t,d)(k1+1)] /
             [f(t,d) + k1(1-b+b|d|/avgdl)]
```

Precondizioni: `N>0`, `avgdl>0`, `k1>0`, `0≤b≤1`. I candidati iniziali
`k1=1,2` e `b=0,75` **DEVONO** essere risolti nel descrittore. `|d|` conta i token
inclusi dopo lo stesso preprocessing dell'indice. Termini assenti o non nel
vocabolario contribuiscono zero. `BM25-v1` ignora la molteplicità del termine nella
query; una saturazione della query o BM25F richiedono altra variante.

BM25 produce un punteggio di ranking, non una probabilità e non una distanza.
Parità di punteggio usano un tie-break stabile su `UnitID`.

## Scalabilità e verifica

Le trasformazioni devono operare su righe, colonne o posting list sparse. Le fixture
coprono righe vuote, `df=N`, termine esterno, unità molto corte/lunghe e confronti
con un'implementazione indipendente. Sono invarianti: binary in `{0,1}`, righe L1
non vuote con somma uno, TF-IDF nullo dove TF è nullo e BM25 finito nelle
precondizioni.

## Profilo implementato

GlifiCore implementa tutte le varianti TF, `IDF-unsmoothed-v1`, `IDF-smooth-v1` e `BM25-v1` con
questi identificatori aggiuntivi, necessari perché nessuna scelta resti implicita:

- `IDF-none-v1`: nessun fattore IDF; il peso è la variante TF e l'identità combinata è la variante
  TF stessa, non `TFIDF-v1`;
- `RowNorm-none-v1`, `RowNorm-L1-v1` (somma dei valori assoluti) e `RowNorm-L2-v1` (norma
  euclidea), applicate dopo TF×IDF; una riga nulla resta nulla;
- logaritmo naturale per TF sublineare, IDF e BM25.

Le operazioni persistite sono `corpus-term-weighting-v1` (matrice documento × termine ponderata) e
`corpus-bm25-ranking-v1`, in cui la query è normalizzata con lo stesso tokenizer e la stessa
normalizzazione del profilo corpus e ridotta ai termini unici; i termini fuori vocabolario sono
conservati con contributo zero (GS-VER-115).

## Dominio numerico e implementazione bounded

`weigh` accetta conteggi interi non negativi e al massimo 1.000.000 colonne,
prima di allocare la cache densa delle frequenze documentali. Il limite è
superiore al vocabolario del profilo corpus standard. Le configurazioni custom
restano soggette al budget specifico della ponderazione; il superamento produce
`weighting.column-limit` (`insufficientResources`). Colonne positive fuori
intervallo, conteggi negativi e overflow della somma di riga producono failure
tipizzate, senza risultato parziale. Le celle a zero restano omesse.

La visita dei conteggi condivide validazione, frequenze documentali, somma e
massimo di riga. Le righe senza normalizzazione evitano l'ordinamento; le altre
riducono la norma nell'ordine crescente delle colonne, conservando la sequenza
aritmetica e i pesi di `TFIDF-v1`. Il calcolo IDF smoothed evita l'addizione
intera che può traboccare al limite di `Int`.

BM25 rifiuta lunghezze negative, somma delle lunghezze non rappresentabile e
conteggi negativi osservati nella query. Le formule ordinarie conservano
l'ordine delle operazioni; se numeratore o denominatore non sono finiti, il
contributo viene riscalato con `max(f,k1)` prima della divisione. Questo conserva
il limite finito per `k1` estremo, evitando punteggi nulli o NaN causati soltanto
dagli intermedi. Un punteggio finale non finito produce failure tipizzata.
Un buffer di conteggi per documento è riutilizzato a ogni colonna query per
DF e score, mantenendo le somme nell’ordine delle colonne e memoria extra
`O(N)`, senza cache documento × query o proporzionale al vocabolario.
Il confronto indipendente Decimal a 400 cifre include questi casi (GS-VER-170).
La cancellazione è osservata prima del lavoro e durante le scansioni.

## Riferimento scientifico

- Robertson e Zaragoza, [The Probabilistic Relevance Framework: BM25 and Beyond](https://doi.org/10.1561/1500000019), 2009.
