<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Statistiche descrittive e diversità lessicale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-04 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.3.2 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Unità e conteggi fondamentali

Ogni conteggio **DEVE** riferirsi a una versione immutabile del corpus e dichiarare
selezione, preprocessing, lingua e unità. Sono fondamentali:

| Simbolo | Significato |
| --- | --- |
| `D` | numero di documenti distinti nella selezione |
| `C` | numero di caratteri nell'unità Unicode dichiarata |
| `G`, `S` | numero di segmenti e di frasi secondo segmenter e versione dichiarati |
| `N` | numero totale di token inclusi |
| `V` | numero di type distinti secondo la chiave lessicale dichiarata |
| `f(t)` | frequenza assoluta del type `t` |
| `p(t)` | frequenza relativa `f(t)/N`, non definita per `N = 0` |
| `df(t)` | numero di documenti con almeno un'occorrenza di `t` |
| `V_r` | numero di type con frequenza esattamente `r` |

“Carattere” **NON DEVE** essere usato senza scegliere byte, scalar Unicode, code
unit UTF-16 o extended grapheme cluster. La metrica visibile predefinita usa grapheme
cluster; codec e offset possono esporre le altre unità separatamente. Hapax legomena
e dis legomena sono rispettivamente `V_1` e `V_2`.

## Distribuzioni di lunghezza

Lunghezze di documenti, segmenti, frasi e token **DEVONO** dichiarare l'unità.
Il risultato conserva almeno numerosità valida, mancanti, minimo, massimo, media,
mediana, varianza, deviazione standard e quantili richiesti. L'aggregazione **NON
DEVE** mescolare unità o pipeline linguistiche differenti senza segnalarlo.

Per valori finiti `x_1…x_n`:

```text
media = (Σ x_i) / n
varianza popolazione = Σ(x_i - media)² / n
varianza campionaria = Σ(x_i - media)² / (n - 1), definita per n ≥ 2
deviazione standard = sqrt(varianza)
```

Il descrittore sceglie esplicitamente varianza di popolazione o campionaria. La
mediana è il quantile `p = 0,5`. La variante di quantile predefinita è `Q7-v1`:
ordinati `x_(1)…x_(n)`, `h = 1 + (n - 1)p`, `j = floor(h)`, `g = h - j` e
`Q(p) = (1-g)x_(j) + gx_(j+1)`, con estremi `Q(0)=x_(1)` e `Q(1)=x_(n)`.
I quantili approssimati streaming **DEVONO** avere un identificatore diverso e
dichiarare bound o errore empirico.

`GlifiDescriptiveStatistics.summarize` espone `Descriptive-Q7-v1` su un massimo di
1.000.000 osservazioni con unità esplicita. La policy `exclude-and-count-v1`
esclude soltanto i mancanti `nil`, conservandone il conteggio; NaN e infinito
sono input invalidi. Il chiamante sceglie varianza campionaria o di popolazione.
Per zero osservazioni le statistiche sono non definite; per un singleton la
varianza campionaria è non definita e quella di popolazione vale zero.
I quantili conservano l'ordine della richiesta (massimo 1.024 probabilità).
Il calcolo sottrae prima un'origine osservata e riscala poi i residui, preservando
uno spread piccolo anche su un offset grande ed evitando overflow intermedi non
necessari; una varianza finale
non rappresentabile per overflow o underflow fallisce esplicitamente. La facciata
GlifiKit è concorrente e non introduce un nuovo formato di progetto.
L'oracolo indipendente usa `mean`, `var`, `sd` e `quantile(type=7)` di R (GS-VER-168).

L'implementazione ottimizzata conserva un solo buffer dei valori finiti ordinati,
salva estremi, mediana e quantili sui valori originali, quindi riusa il buffer
normalizzandolo in-place senza materializzare un secondo array degli scarti. I
quantili non sono ricostruiti aggiungendo l'origine a scarti arrotondati. Poiché l'origine
è il minimo, tutti gli scarti sono non negativi e limitati dallo scarto del massimo:
la finitezza di quest'ultimo verifica il dominio dell'intera trasformazione.
Ogni scarto normalizzato è calcolato una volta; i due passaggi per media e varianza
leggono gli stessi valori Double, mantenendo sottrazioni, riscalamento e ordine
delle riduzioni della variante verificata.
Quantili, mancanti, denominatori, errori di overflow/underflow e cancellazione
conservano il medesimo contratto. GS-VER-169 raccoglie la verifica dell'invarianza
dei risultati e le misure riproducibili dell'ottimizzazione.

L'ordinamento esatto può usare un conteggio bounded dei bit pattern quando compare
un'inversione nei primi 1.024 valori validi e l'intero input contiene al massimo
256 valori distinti non nulli. Dopo la verifica completa, si ordinano i soli
valori distinti e si riscrive il medesimo buffer con le rispettive molteplicità.
La memoria aggiuntiva del candidato è `O(256)`. La presenza di `+0` o `−0`, il
superamento dei 256 tipi oppure l'assenza dell'inversione preliminare mantengono
l'ordinamento nativo; il fallback riceve il buffer ancora integro e preserva
anche le parità fra zeri con segno. La scelta del percorso lascia invariati tutti
i valori ordinati, Q7 e l'ordine delle riduzioni numeriche.

GS-VER-170 registra il confronto appaiato con fingerprint completi di input e
output e test bitwise contro l'ordinamento nativo, inclusi subnormali, zeri con
segno, cardinalità al bordo e fallback tardivo. Il percorso misurato favorisce i
valori ripetuti; il controllo aggiuntivo può invece aumentare il tempo su input
quasi ordinati. Questa scelta comporta un compromesso misurato e non costituisce
una garanzia universale di maggiore velocità. Limiti di risorse, failure e
cancellazione conservano il contratto della variante.

## Ricchezza e diversità lessicale

Le metriche operano su una sequenza ordinata di `N` token inclusi e sulla funzione
esplicita che mappa token a type. Maiuscole, lemmi, punteggiatura, stopword e token
esclusi sono parte del descrittore.

### TTR-v1

`TTR = V/N` per `N > 0`; non definito per corpus vuoto. È fortemente dipendente
dalla dimensione e **NON DEVE** essere confrontato tra campioni di lunghezza diversa
come misura corretta per la lunghezza.

### MSTTR-v1

Dato `W ≥ 1` e `N ≥ W`, divide la sequenza, dall'inizio, in finestre non sovrapposte
complete di `W` token, scarta la coda incompleta e restituisce la media dei TTR delle
`floor(N/W)` finestre. Ordine, `W` e politica `discard-remainder` sono obbligatori.
Per `N < W` il valore non è definito. Varianti con offset multipli o coda inclusa
ricevono un altro identificatore.

### MATTR-v1

Dato `W ≥ 1` e `N ≥ W`, calcola il TTR di ogni finestra contigua
`[i, i+W)` per `i = 0…N-W` e ne restituisce la media. Per `N < W` il valore non è
definito. La sequenza, `W` e il trattamento dei confini sono persistiti.

### MTLD-bidirectional-v1

Con soglia risolta `τ` tale che `0 < τ < 1` (candidata `0,72`), percorre i token e
chiude un fattore quando il TTR corrente diventa `≤ τ`, quindi azzera i conteggi del
fattore. Per la coda non chiusa aggiunge il fattore parziale
`(1 - TTR_coda)/(1 - τ)`. Il valore direzionale è `N/fattori`; se i fattori sono
zero vale `+∞`. Il risultato è la media dei valori ottenuti sulla sequenza originale
e su quella invertita, con regole IEEE esplicite per `+∞`.

Nel profilo implementato `corpus-lexical-diversity-mtld-v1` (GS-VER-116) il valore è calcolato per
documento e sulla sequenza concatenata in ordine canonico; `+∞` è serializzato come `"+Infinity"`,
perché JSON non rappresenta infiniti.

MSTTR, MATTR e MTLD riducono alcuni effetti della lunghezza ma **NON DEVONO** essere
descritti come indipendenti da campionamento, genere, ordine o preprocessing.

## Frequenze filtrate e n-grammi

Le frequenze e gli n-grammi operano sulle forme lessicali normalizzate del profilo corpus
(`it-token-v1`, NFC, minuscole italiane) e non attraversano il confine del documento.

### `WordNGram-v1`

Sequenze contigue di `n` forme lessicali dentro lo stesso documento, `1 ≤ n ≤ 5`. Il conteggio è il
numero di posizioni iniziali; la document frequency è il numero di documenti con almeno una
occorrenza.

### `CharNGram-graphemes-v1` e `CharNGram-graphemes-padded-v1`

Sequenze contigue di `n` extended grapheme cluster dentro una singola forma lessicale,
`1 ≤ n ≤ 10`. La variante `padded` aggiunge un marcatore di confine `_` (U+005F) all'inizio e alla
fine della forma prima dell'estrazione (Cavnar e Trenkle, 1994), così che prefissi e suffissi
siano distinguibili; `_` non può comparire in una forma lessicale di `it-token-v1`. Una forma più
corta di `n` non produce n-grammi. Nessun n-gramma di caratteri attraversa il confine fra forme.

### Filtri `TermFilter-v1`

I filtri sono parte della richiesta e del descrittore e si applicano, nell'ordine, **dopo** il
conteggio sull'intero testo:

1. `stopwords`: lista esplicita di forme, normalizzata come i token; nessuna lista è implicita.
   Per le frequenze esclude la forma; per `WordNGram-v1` esclude ogni n-gramma che contiene una
   stopword (`stopword-policy.exclude-containing-v1`), senza rimuovere la stopword prima del
   conteggio, perché la rimozione creerebbe adiacenze inesistenti nel testo; per gli n-grammi di
   caratteri esclude quelli estratti da una forma stopword;
2. `minimumLength`: lunghezza minima della forma in grapheme cluster (solo frequenze);
3. `minimumCount` e `minimumDocumentFrequency`: soglie inclusive su conteggio e document frequency;
4. `maximumDocumentProportion`: esclude le righe con `df/D` maggiore della soglia in `(0, 1]`.

Le frequenze relative restano calcolate sul totale delle unità **prima** dei filtri: token
lessicali per le forme, posizioni iniziali di n-gramma per gli n-grammi. Il denominatore è
dichiarato nel risultato insieme al numero di righe escluse da ciascun filtro, attribuite al
primo filtro che le esclude. Le righe
sono ordinate per conteggio decrescente e valore crescente; un limite di righe è una troncatura
dichiarata, non un filtro.

## Verifica

Fixture minime comprendono corpus vuoto, singolo token, tutti token uguali, tutti
distinti, finestre esatte e con coda, Unicode composto e documenti vuoti. Conteggi
interi sono D0; media, varianza e metriche lessicali dichiarano D0 o D1 secondo la
precisione e la strategia di riduzione.

## Riferimenti scientifici

- Cavnar e Trenkle, «N-Gram-Based Text Categorization», *Proceedings of SDAIR-94*, pp. 161–175, 1994.

- Covington e McFall, [Moving-Average Type-Token Ratio](https://doi.org/10.1080/09296171003643098), 2010.
- McCarthy e Jarvis, [MTLD, vocd-D, and HD-D](https://doi.org/10.3758/BRM.42.2.381), 2010.
