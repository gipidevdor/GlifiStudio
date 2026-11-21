<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Similarità e distanze

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-13 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Domini distinti

Una misura **DEVE** dichiarare se opera su insiemi, vettori o distribuzioni di
probabilità. Allineamento delle dimensioni, vocabolario, weighting, normalizzazione
e trattamento dei mancanti sono parte dell'input semantico.

## Insiemi

Per insiemi finiti `A` e `B`:

```text
JaccardSet-v1 = |A∩B| / |A∪B|
DiceSet-v1    = 2|A∩B| / (|A|+|B|)
```

Per due insiemi vuoti entrambe valgono `1`; per un solo insieme vuoto valgono `0`.
Varianti multiset o pesate richiedono altro identificatore.

## Vettori reali

Per vettori allineati `x,y ∈ ℝ^n`:

```text
Cosine-v1    = (x·y) / (||x||₂ ||y||₂), norme entrambe positive
Euclidean-v1 = sqrt[Σ(x_i-y_i)²]
Manhattan-v1 = Σ|x_i-y_i|
```

Il coseno è non definito per un vettore nullo. `1-cosine` **NON DEVE** essere
chiamata metrica senza una variante e una dichiarazione delle proprietà, perché in
generale non soddisfa la disuguaglianza triangolare.

## Distribuzioni di probabilità

La divergenza di Kullback–Leibler (KL), la divergenza/distanza di Jensen–Shannon
(JS) e la distanza di Hellinger operano soltanto su distribuzioni normalizzate.

Siano `p_i,q_i≥0`, `Σp=Σq=1`, `m=(p+q)/2`, con logaritmo base 2:

```text
KL-v1(p||q) = Σ_i p_i log2(p_i/q_i)
JSdiv-v1    = 0,5 KL(p||m) + 0,5 KL(q||m)
JSdist-v1   = sqrt(JSdiv-v1)
Hellinger-v1 = sqrt[Σ_i(sqrt(p_i)-sqrt(q_i))²] / sqrt(2)
```

Il contributo con `p_i=0` è zero. Kullback–Leibler è finita soltanto se `q_i>0` ovunque `p_i>0`;
è direzionale e **NON È** una metrica. JSdiv è una divergenza; la sua radice è la
distanza. Hellinger e JSdist sono metriche nelle condizioni dichiarate. Smoothing e
rinormalizzazione sono trasformazioni separate, mai implicite.

## Proprietà e verifica

### Estremi numerici del backend Double

I vettori reali devono avere componenti finite. Il coseno scala separatamente
ogni vettore per il proprio massimo valore assoluto prima delle riduzioni;
questa trasformazione algebrica preserva il coseno e impedisce overflow di
prodotti e norme. La distanza euclidea accumula la norma con `hypot`, senza
quadrare direttamente componenti grandi o subnormali. Se il valore finale
di Euclidean o Manhattan supera il dominio finito di Double, l'operazione
fallisce con `similarity.numeric-overflow`, senza restituire infinito.

Le varianti non negative `WeightedJaccard-v1` e `MultisetDice-v1` usano una
scala comune per le somme; `Lidstone-v1` scala conteggi e prior prima della
normalizzazione, sommando prima il numeratore quando la somma è finita per
preservare contributi subnormali rappresentabili. Hellinger accumula con `hypot`
le differenze delle radici, evitando l'underflow dei loro quadrati.
L'input nullo resta soggetto alle precondizioni dichiarate:
il riscalamento non introduce smoothing nelle similarità.

KL calcola `log2(p_i) - log2(q_i)` evitando il rapporto che può superare
Double anche quando il logaritmo è finito. JS usa la forma simmetrica positiva,
con `s=p_i+q_i` e `d=|p_i-q_i|/s`:

```text
g(d) = [(1+d)ln(1+d) + (1-d)ln(1-d)] / (4 ln 2)
contributo JSdiv = s × g(d)
g(d) = Σ_(k≥1) d^(2k) / [4 ln 2 × k(2k−1)]
```

Per `d≤1/8` la serie positiva conserva il segnale quadratico vicino
all'identità; altrove il calcolo usa `log1p`, con limite `g(1)=1/2` esplicito.
La norma dei contributi `sqrt(s) × sqrt(g(d))` è accumulata tramite `hypot`.
JSdist non passa per una divergenza già arrotondata: una distanza rappresentabile
resta disponibile anche quando il suo quadrato è subnormale o arrotondato a zero.
JSdiv è il quadrato della stessa norma. Non si materializza una miscela
subnormale arrotondata a zero. Dopo validazione, il clamp del coseno a `[-1,1]`
e quello della norma JS al massimo `1` preservano i limiti teorici contro
l'arrotondamento. L'oracolo eseguibile `Python/similarity.py` usa `Decimal` con
120 cifre sulla formula log-ratio originale, senza condividere trasformazione,
serie o accumulazione del backend. I test verificano l'errore relativo anche
per perturbazioni da `1e-6` a `1e-10`. Identità, disgiunzione, massa di
probabilità e omogeneità delle similarità sono verificate anche con
`Double.greatestFiniteMagnitude` e `Double.leastNonzeroMagnitude`
(GS-VER-168).

Ogni implementazione dichiara range, simmetria e proprietà metriche. Le fixture
coprono identità, disgiunzione, zeri, dimensioni non allineate e probabilità non
normalizzate. Per le distanze metriche si verificano non negatività, identità,
simmetria e disuguaglianza triangolare su casi generati; i risultati sono confrontati
con un'implementazione indipendente entro la tolleranza approvata.
