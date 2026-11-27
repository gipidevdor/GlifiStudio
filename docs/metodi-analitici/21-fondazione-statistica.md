<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Fondazione statistica e inferenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-21 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.7 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-27 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Selezione del metodo

Un test **DEVE** partire da domanda, unità indipendente, disegno, variabili, ipotesi,
sampling e assunzioni; non dal nome della funzione disponibile. Il risultato
conserva statistica, gradi di libertà, alternativa, p-value, effect size, intervallo
di confidenza, esclusioni e diagnostica applicabili. Un p-value **NON È** la
probabilità che l'ipotesi nulla sia vera.

## Famiglie iniziali

| Famiglia | Dominio e variante richiesta |
| --- | --- |
| Chi-quadrato/G/Fisher | conteggi categoriali secondo GS-MET-001-08 e GS-MET-001-09 |
| `PearsonR-v1` | coppie quantitative finite; `r=Σ(x-x̄)(y-ȳ)/sqrt[Σ(x-x̄)²Σ(y-ȳ)²]`, varianze positive |
| `SpearmanRho-v1` | Pearson sui ranghi medi in presenza di tie; p-value esatto, permutation o asintotico dichiarato |
| t-test | one-sample, paired o independent-Welch come varianti distinte; unità indipendenti e assunzioni diagnosticate |
| Wilcoxon/Mann–Whitney | signed-rank o rank-sum distinti; tie, zeri e metodo esatto/asintotico dichiarati |
| ANOVA | disegno, contrasto, omoscedasticità e post-hoc dichiarati; Welch è variante distinta |
| Kruskal–Wallis | gruppi indipendenti, ranking con tie correction e post-hoc separato |

Il t-test indipendente candidato è Welch, che non assume varianze uguali. Cohen's
`d-pooled-v1` usa invece, soltanto quando motivato,
`s_p=sqrt{[(n_1-1)s_1²+(n_2-1)s_2²]/(n_1+n_2-2)}` e
`d=(x̄_1-x̄_2)/s_p`, con gruppi indipendenti, `n_1,n_2≥2` e `s_p>0`. Effetti paired,
Welch o piccoli campioni richiedono effect size e correzioni distinti.

### Varianti candidate completamente identificate

`WelchT-v1` richiede due campioni indipendenti con `n_1,n_2≥2` e varianze finite
positive:

```text
t = (x̄_1-x̄_2) / sqrt(s_1²/n_1+s_2²/n_2)
ν = (s_1²/n_1+s_2²/n_2)² /
    [(s_1²/n_1)²/(n_1-1)+(s_2²/n_2)²/(n_2-1)]
```

`PairedT-v1` applica il one-sample t-test alle differenze appaiate; coppie incomplete
sono escluse secondo policy dichiarata. `OneSampleT-v1` usa
`t=(x̄-μ₀)/(s/sqrt(n))`, `df=n-1`, con `n≥2` e `s>0`. Alternativa unilaterale o
bilaterale e ipotesi `μ₀` sono persistite.

`MannWhitneyU-v1` assegna midrank al campione pooled e calcola
`U_1=R_1-n_1(n_1+1)/2`; lato del test, forma esatta o asintotica e correzione dei tie
sono espliciti. `WilcoxonSignedRank-v1` rimuove differenze zero secondo la policy
risolta, assegna midrank a `|d_i|` e usa la somma dei ranghi positivi; esatto e
asintotico sono varianti distinte.

`OneWayANOVA-v1` usa
`F=[Σ_g n_g(x̄_g-x̄)²/(k-1)]/[Σ_gΣ_i(x_gi-x̄_g)²/(N-k)]`, richiede gruppi
indipendenti, residui compatibili con il modello e varianza comune per l'inferenza.
`KruskalWallis-v1` usa midrank pooled e
`H=12/[N(N+1)]Σ_g R_g²/n_g-3(N+1)`, con fattore di correzione dei tie dichiarato.
Un risultato omnibus significativo non identifica da solo i gruppi differenti;
post-hoc e relativa famiglia multipla sono nodi separati.

### ANOVA di Welch headless

`WelchOneWayANOVA-v1` estende il confronto a `k≥2` gruppi indipendenti di popolazioni
normali senza assumere varianze uguali. Ogni gruppo richiede `n_g≥2`, osservazioni
finite e varianza campionaria strettamente positiva; non si escludono osservazioni.
Con `w_g=n_g/s_g²`, `W=Σw_g`, `m=Σw_g x̄_g/W`:

```text
A = Σ_g (1-w_g/W)²/(n_g-1)
F = [Σ_g w_g(x̄_g-m)²/(k-1)] / [1+2(k-2)A/(k²-1)]
df1 = k-1
df2 = (k²-1)/(3A)
p = P(F_df1,df2 ≥ F)
```

Il risultato conserva F, entrambi i gradi di libertà e p; non identifica gruppi
specifici né produce confronti post-hoc impliciti. La primitiva Core lavora in
memoria con costo lineare nelle osservazioni e spazio aggiuntivo lineare nei gruppi.
La richiesta è limitata a 100.000 gruppi e un milione di osservazioni totali;
superamenti falliscono con `statistics.limit-exceeded`. La cancellazione viene
verificata all'ingresso e ogni 1.024 valori nelle scansioni. GlifiKit espone la
stessa variante con `@concurrent` e DTO propri.
Il calcolo sottrae un anchor osservato comune prima di medie e scaling per
preservare piccole variazioni su grandi offset. Una scala comune esatta in
potenze di due evita overflow nei quadrati; se la sottrazione dell'anchor può
eccedere binary64 (valori estremi di segno opposto), un riscalamento preliminare
precede la sottrazione. Intermedi
non rappresentabili falliscono con `statistics.non-finite-result`. Varianze non
positive falliscono con `statistics.non-positive-variance`. L'oracolo è
`stats::oneway.test(var.equal=FALSE)` di R e, per due gruppi, l'identità `F=t_Welch²`.
Una traslazione locale per gruppo precede il calcolo della varianza, prima
della divisione per le stesse scale comuni. Le medie sono poi ricostruite nelle
coordinate comuni per i contrasti: un grande offset fra gruppi non deve
cancellare lo spread interno. Se la sottrazione locale di estremi opposti
trabocca, si sottraggono le coordinate comuni bounded. GS-VER-171 registra un
riferimento Decimal a 80 cifre, trasformazioni di scala/offset e il controesempio
con varianze 1 e 1/3, F circa 2,25×10³⁰ e df2=3,2.
La variante resta `candidate`: questa implementazione non promuove il planner o
la persistenza né sostituisce un ValidationManifest per variante.

Pearson sottrae un anchor osservato separato per variabile prima di medie e
riscalamento in potenze di due; soltanto una sottrazione potenzialmente in overflow
richiede il riscalamento preliminare. Questo conserva piccole variazioni su grandi
offset oltre alla correlazione per dati finiti di scala estrema.
Spearman esatto rifiuta esplicitamente NaN e infinito prima del ranking.

## Intervalli, bootstrap e permutation test

Ogni intervallo di confidenza dichiara parametro, livello, metodo e assunzioni.
`BootstrapPercentile-v1` ricampiona con sostituzione l'unità indipendente `B` volte,
registra PRNG/seed e usa i quantili dichiarati della distribuzione bootstrap. Non è
valido se il resampling rompe dipendenze del disegno.

`MovingBlockBootstrap-v1` concatena blocchi contigui di lunghezza `L`, con
`1≤L≤n`, inizi estratti uniformemente in `0...n-L` e troncamento a `n` osservazioni.
Per ogni blocco il ciclo visita soltanto `min(L,n-drawn)` offset, evitando le visite
inutili della coda finale. Restano invariati numero e ordine delle estrazioni
`SplitMix64-v1`, somme scalari nell'ordine delle osservazioni estratte, ordinamento
delle repliche e quantili di tipo 7; con `L=1` il risultato coincide bit per bit
con il bootstrap indipendente a parità di input, livello, repliche e seed.
Per `L=1`, dopo tutte le validazioni MBB, il calcolo delega al bootstrap indipendente
per evitare il costo del ciclo a blocchi per ogni osservazione. Restano identici
stream casuale, metadati del risultato e checkpoint ogni 1024 repliche, inclusa la
prima; gli errori di validazione MBB precedono la cancellazione come in precedenza.
Le validazioni restano quelle esistenti. La verifica
GS-VER-173 confronta tutti i campi del risultato con il precedente ciclo completo
e un generatore di riferimento indipendente; le misure usano GS-DOR-173.

GS-VER-176 aggiunge checkpoint prima dell'allocazione delle repliche, dopo le
validazioni, e almeno ogni 4096 osservazioni ricampionate. Il budget è cumulativo
fra repliche brevi e suddivide anche l'interno dei blocchi lunghi senza estrarre
nuovi inizi di blocco. Restano anche i checkpoint ogni 1024 repliche. Un hook
interno espone solo il conteggio diagnostico cumulativo, saturante a `Int.max`, per
iniettare cancellazione deterministica nei test; non modifica i valori calcolati.
Un checkpoint precede e uno segue l'ordinamento, conservando gli operatori
`sorted()` e `sort()` esistenti. L'ordinamento stesso resta non interrompibile e
non viene introdotto un backend alternativo. Il limite di 4096 riguarda il ciclo
di ricampionamento, non la validazione iniziale né l'ordinamento; un calcolo
cancellato non restituisce intervalli parziali. API pubbliche, PRNG, ordine delle
somme, quantili e tutti i metadati restano invariati, inclusa la delega `L=1`.
Il kernel delle repliche è riusato anche da `BootstrapBCa-v1`, che riceve gli
stessi checkpoint durante il ricampionamento. La formula BCa, bias correction,
accelerazione jackknife e probabilità corrette restano invariate; il limite di
lavoro tra checkpoint non viene esteso alle fasi specifiche BCa. Questo riuso è
esplicito nel perimetro di GS-DOR-176 ed è verificato anche contro l'oracolo R
già esistente.

Un permutation test dichiara statistica, gruppo di permutazioni compatibile con
l'ipotesi nulla, alternativa, enumerazione esatta o Monte Carlo, numero di campioni,
seed e correzione del p-value Monte Carlo. L'exchangeability è una precondizione,
non un dettaglio implementativo.

## Confronti multipli

La famiglia di `m` ipotesi **DEVE** essere definita prima dell'interpretazione.

```text
Bonferroni-v1: p_adj_i = min(1, m p_i)

BenjaminiHochberg-v1:
  ordina p_(1)≤…≤p_(m)
  q_(i) = min(1, min_{j≥i} [m p_(j)/j])
  ripristina l'ordine originale
```

Bonferroni controlla il family-wise error rate; BH controlla la false discovery
rate nelle condizioni del metodo. P-value grezzi e corretti **DEVONO** entrambi
restare disponibili. Un'analisi su migliaia di termini **NON DEVE** presentare
p-value non corretti come evidenza conclusiva.

## Effect size

Cramér's V, odds ratio, log ratio e Cohen's d si usano soltanto nei domini definiti
nei rispettivi documenti. Effect size, intervallo d'incertezza e significatività
sono campi separati. Etichette qualitative come “piccolo” o “grande” richiedono una
soglia motivata per il dominio e non sono predefinite.

## Fondazione matematica e backend

La fondazione concettuale `GlifiMath` comprende statistica descrittiva e
inferenziale, algebra lineare, matrici sparse, similarità/distanze, grafi,
ottimizzazione e pseudo-casualità controllata. Non è ancora un target Swift
obbligatorio. Swift, Accelerate, BNNS, Core ML e Metal/MPS sono backend: **NON
DEVONO** definire la semantica scientifica. Ogni backend ha riferimento indipendente,
tolleranze e benchmark end-to-end.

## Revisione numerica delle distribuzioni — GS-VER-319

I nuclei beta e gamma sono implementazioni Swift originali delle relazioni
matematiche DLMF 8.17.4/22/23, 8.7.1 e 8.9.2. Le frazioni vengono valutate
dal fondo con profondità raddoppiate e confronto fra approssimazioni successive;
la serie gamma usa somma compensata. Non vengono incorporati sorgenti,
coefficienti o testi di Numerical Recipes, Acklam, R o DLMF. DLMF resta una
fonte matematica con condizioni editoriali proprie, distinte dalla licenza
BSD del codice originale.

Il nucleo beta calcola separatamente i logaritmi di `x` e `1-x` a partire dai
log-odds: evita che un rapporto arrotondato a uno cancelli l'informazione
per t e F vicini a zero e che il quadrato di t trabocchi nelle code. `expm1`
preserva i complementi piccoli. Le frazioni beta hanno al massimo 2.048 livelli;
la serie e la frazione gamma sono limitate rispettivamente a 16.384 termini e
livelli. I confronti delle frazioni usano otto epsilon binary64, la serie un
epsilon relativo al totale. Mancata convergenza o intermedi non rappresentabili
falliscono con `statistics.non-finite-result`; input invalidi non producono
probabilità fittizie.

Il quantile normale inverte la legge in un bracket bounded `[0,40]` sulla
magnitudine: `erf` conserva precisione intorno alla mediana, mentre la coda
logaritmica usa la frazione matematica DLMF 7.9.1 da magnitudine 8, con 64 livelli.
Non usa coefficienti di approssimazione importati. GS-VER-325 restringe il bracket
con al massimo dodici proposte Halley protette e un controllo dei segni nei
vicini binary64; la scelta finale usa sempre bisezione. Le derivate servono
soltanto a proporre passi finiti interni al bracket, con fallback invariato.
Il limite complessivo di 200 iterazioni e
l'arresto su estremi binary64 adiacenti coprono anche probabilità subnormali
positive. Il quantile t valida anche la finitezza dei gradi di libertà prima
della scorciatoia per la mediana. Il log-gamma di sistema usa `lgamma_r` con
storage locale del segno: l'SDK Apple documenta `lgamma` come non thread-safe.
Tutte le chiamate del motore transitano per il wrapper reentrante.

GS-VER-324 calcola il quantile della keyness una sola volta dopo le medesime
ammissioni e il checkpoint iniziale, prima del ciclo dei termini; risultati
completi e digest restano identici nel confronto Release. Le proposte di
accoppiamento beta/gamma GS-VER-326 sono state scartate per beneficio non
stabile: i loro sorgenti restano quelli della baseline verificata.

Le differenze di arrotondamento della normale restano nel contratto D1,
senza cambiare formule, failure, tolleranze o revisione numerica `2`.
Il confronto comprende monotonia campionaria, code subnormali, mediana,
confine della coda e consumatori BCa/effect-size. La verifica non costituisce
una prova di monotonia universale di ogni implementazione libm.

La variante scientifica e gli schemi payload restano invariati. La revisione
algoritmo nel descrittore passa a `2` per keyness e per `corpus-association`,
`group-metric-comparison`, `group-metric-posthoc`, `metric-correlation` e
`paired-metric-comparison`: i risultati della revisione precedente rimangono
leggibili, ma non sono riusati per la richiesta corrente. Le altre famiglie
conservano la revisione e l'identità precedenti.

La griglia indipendente comprende 72 code t, 392 code F e 63 code chi-quadrato,
con confronto relativo `1e-9` senza floor assoluto; zero di riferimento richiede
zero esatto. Dieci riferimenti `qnorm` nelle code usano tolleranza assoluta
`2e-13`. Restano attivi gli oracoli e le tolleranze precedenti. Questo controllo
non certifica ogni combinazione possibile dei parametri né una licenza su
implementazioni esterne.

## Stabilità inferenziale alle unità e agli estremi — GS-VER-328

`PermutationMeanDifference-v1` confronta le assegnazioni in coordinate centrate
su un'osservazione e scalate in potenze di due. La tolleranza numerica resta
relativa `1e-12`, applicata allo span centrato invece che a un floor assoluto
o all'offset delle osservazioni. Trasformazioni affini positive che conservano osservazioni e differenze alla
precisione dichiarata **NON DEVONO** cambiare alternative, tie, conteggio estremo
o p-value. Il requisito non include trasformazioni che, pur producendo valori
finiti, fanno collassare dati distinti già per arrotondamento. Il valore
osservato viene riportato nell'unità originale. Le ammissioni della strategia
esatta o Monte Carlo precedono preparazione, allocazioni e checkpoint nuovi;
assegnazioni, PRNG e correzione Monte Carlo conservano il contratto esistente.

`OneSampleT-v1`, `PairedT-v1` e `CohenD-pooled-v1` centrano le osservazioni prima
di calcolare i momenti e usano scale esatte in potenze di due. Medie degli
scarti e somme dei quadrati usano accumulazione compensata. Le deviazioni e i
contrasti vengono ripristinati soltanto al confine: un quadrato intermedio in
overflow o underflow non deve azzerare t/d quando deviazione e risultato finali
sono rappresentabili. Differenze appaiate non rappresentabili falliscono prima
del ranking, senza creare tie fra infiniti.

Bootstrap indipendente e a blocchi conservano le somme ordinate sui dati
ordinari. Se il massimo assoluto e la numerosità possono fare traboccare una
somma, si riscalano gli input in potenze di due prima delle stesse estrazioni.
La soglia conservativa max/(2n) conserva margine per gli arrotondamenti delle
somme ordinate ai conteggi ammessi; il solo limite matematico max/n non basta.
Una costante grande mantiene esattamente il proprio valore, senza saltare
estrazioni o checkpoint. Stima, leave-one-out e repliche devono essere finite.
BCa riusa media/jackknife stabili e calcola l'accelerazione su scarti centrati e
normalizzati prima dei cubi: la scala della variabile non definisce l'intervallo.

Q7 conserva il percorso aritmetico ordinario, inclusi i bit degli zeri con
segno. Per estremi finiti opposti, se la sottrazione trabocca, conserva gli
endpoint e usa la combinazione convessa della definizione invece di
materializzare una differenza infinita. I controlli quantitativi e le
tolleranze precedenti rimangono attivi. Intermedi non rappresentabili nella
normalizzazione, inclusa la perdita di un contributo non nullo per underflow,
e output finali non rappresentabili falliscono con `statistics.non-finite-result`;
non vengono sostituiti con zero, clamp o risultati parzialmente NaN.

I nuovi passaggi lineari verificano la cancellazione almeno ogni 1.024 valori,
dopo le validazioni applicabili. Lo stream casuale e i checkpoint diagnostici
del ricampionamento a 4.096 osservazioni restano quelli dichiarati sopra.
Nessun formato persistente cambia. La revisione produttore passa a `3` soltanto
per `group-metric-comparison`, `group-metric-posthoc` e
`paired-metric-comparison`, che possono riusare permutazioni, d o t errati.
Anche frequenze relative ammissibili vicine a uno possono avere spread tanto
piccoli che la media arrotondata altera sensibilmente il t: il dominio bounded
non giustifica il riuso della revisione paired precedente. Accordo bootstrap,
associazione, correlazione, keyness e altre famiglie conservano le revisioni
precedenti. Storici e schemi
rimangono leggibili.

## Verifica

Dataset di riferimento coprono risultati noti, estremi, `NaN`, overflow, campioni
piccoli, tie e assunzioni violate. Property test verificano invarianti; reference
test confrontano almeno un'implementazione indipendente; simulation test controllano
errore di tipo I, coverage o potenza quando appropriato.

## Riferimento scientifico

- Benjamini e Hochberg, [Controlling the False Discovery Rate](https://doi.org/10.1111/j.2517-6161.1995.tb02031.x), 1995.
- Welch, [On the Comparison of Several Mean Values: An Alternative Approach](https://doi.org/10.2307/2332579), 1951;
  [contratto dell'oracolo R](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/oneway.test.html).
