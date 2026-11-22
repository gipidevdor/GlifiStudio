<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Operatori analitici compatibili con le famiglie KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-23 |
| Tipo | Specifica dei contratti numerici e della copertura |
| Versione | 1.5.1 |
| Stato | Profili pubblici implementati; verifica integrata GS-VER-300 in corso |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Ambito richiesto dall'iniziatore; promozione scientifica separata secondo ADR-0031 |
| Documento padre | [GS-MET-001](README.md) |
| Riferimenti | RF-087; ADR-0032; ADR-0035; ADR-0043; GS-DOR-300; GS-VER-160; GS-VER-233; GS-VER-234; GS-VER-300 |

## Scopo e copertura

La richiesta comprende tutte le famiglie analitiche di KH Coder, nella libreria
headless GlifiCore e nella facciata GlifiKit. Il riferimento verificato è il
[manuale ufficiale KH Coder 3](https://khcoder.net/en/manual_en_v3.pdf),
sezioni A.2.5, A.5, A.6 e A.7; il topic model è documentato anche nel
[registro ufficiale delle versioni](https://khcoder.net/versions.html).
Compatibilità funzionale di famiglia e parità numerica con una particolare
versione di KH Coder sono proprietà distinte: tokenizzazione, inizializzazione e
varianti native sono dichiarate, senza sostituire silenziosamente quelle del programma.
Il confronto aggiuntivo del 2026-11-22 riguarda il manuale pubblico del 2016 e il
[sorgente pubblico ufficiale](https://github.com/ko-ichi-h/khcoder), dichiarato non
aggiornato all’edizione corrente; non attesta parità con un’edizione chiusa o futura.
L’ampliamento è autorizzato in [ADR-0035](../adr/0035-completamento-nativo-kh-coder.md).

| Famiglia | Implementazione nella libreria |
| --- | --- |
| Frequenze TF/DF, distribuzioni e filtri | GlifiCorpusAnalyzer; GlifiNGramFrequencyAnalysis; GlifiTermWeighting |
| Ricerca di parole/documenti e KWIC | GlifiQueryParser/Evaluator; sessione GlifiKit esistente |
| Associazione di parole e tabelle di contingenza | GlifiKeynessAnalysis; GlifiContingencyAnalysis; GlifiCollocationAnalysis; MI3/Z KH con TF globali |
| Analisi delle corrispondenze | CA-SVD-v1; coordinate principal, standard e biplot symmetric esplicite |
| MDS classica, metrica, Kruskal, Sammon e SMACOF ordinale | GlifiExploratoryAnalysis; tie primary/secondary e ricerca multi-start con diagnostiche per avvio |
| Clustering gerarchico | HAC esistente per vettori; Lance-Williams per dissimilarità single/complete/average |
| CLARA sui documenti | CLARA-PAM-Euclidean-v1 |
| Reti di co-occorrenza | Reti esistenti; Girvan–Newman, CNM, Walktrap, layout FR/KK e foresta Prim nativi |
| Mappe auto-organizzanti | SOM batch esistente; profilo KH online a due fasi con PCA o codebook espliciti; U-matrix e Ward esistenti |
| Classificazione supervisionata | Naive Bayes multinomiale; stato incrementale transitorio, modello ispezionabile e validazione stratificata con κ |
| Topic model | LDA-collapsed-Gibbs-predictive-mean-v2, selezione K con diagnostiche e document completion; LSA e NMF esistenti |
| Regole automatiche e frequenze dei codici | GlifiCodingRuleSet e matrice multi-label con evidenze UTF-8 |
| Tabelle incrociate e similarità dei codici | crosstab con denominatori/mancanti espliciti; distanze condivise |
| CA, MDS, clustering, rete e SOM dei codici | Stessi operatori numerici sulla matrice documento-codice |
| Matrici documento-parola e documento-codice | Tabella sparsa, trasposizione bounded e matrice binaria dei codici |
| Preparazione e matrice parola-contesto KH A.6.8 | GlifiKHMatrixPreparation: z-score campionario, esposizioni esterne e medie condizionate per livelli dichiarati |
| Rilevanza dei termini composti | GlifiTermExtraction: LR/FLR token/type e candidate da POS preannotati con evidenze UTF-8 |

La riverifica di [GS-VER-234](../evidenze/GS-VER-234-riverifica-correttezza-completezza.md)
ha accertato le lacune della revisione allora esaminata e resta un'evidenza
storica. Il nuovo incremento [GS-DOR-300](../pianificazione/dor-completezza-funzionale-kh.md),
autorizzato da [ADR-0043](../adr/0043-completezza-funzionale-kh-pubblico.md),
introduce implementazioni dedicate per quei profili. La verifica integrata
GS-VER-300 è in corso: la presenza del codice non attesta il suo esito finale,
una validazione esterna V6 o la parità con edizioni KH non pubbliche.

| Profilo pubblico KH | Stato reale del profilo nativo |
| --- | --- |
| Z-score per parola/documento (A.5.9, A.6.2) | `sampleZScores`: asse e politica per vettori costanti espliciti; deviazione standard campionaria |
| Frequenze con lunghezza completa del documento | `GlifiKHMatrixPreparation.perThousand`: denominatori esterni; la trasformazione precedente basata sulla somma delle colonne resta distinta |
| Parola-contesto per livelli e pesi (A.6.8) | `wordContext`: conteggi per unità dichiarate, medie condizionate e somma pesata |
| MDS ordinale e gestione dei tie | Nuovi ingressi con primary predefinito o secondary esplicito; i default delle API precedenti restano secondary |
| SOM KH a due fasi e inizializzazione PCA | Aggiornamenti online continui sugli stessi codebook; PCA lineare o inizializzazione esplicita |
| MI³ e Z con TF globali e span (A.5.6) | `GlifiKHCollocationAnalysis`: corpus e finestra dichiarati, senza margini di opportunità 2×2 |
| Scaling CA | Proiezioni principal, standard e symmetric biplot con esponente di σ dichiarato per righe e colonne |
| Addestramento NB incrementale e κ | Statistiche sufficienti transitorie aggiornabili, ispezione del modello e κ sulle stesse predizioni della CV |
| TermExtract (A.4.4) | LR/FLR su candidate indipendenti, modalità token/type e regole POS su preannotazioni; nessuna certificazione di tokenizzazione inglese o giapponese |

I nuovi profili sono esposti in Core, Kit e nel comando CLI `text-analysis`,
con identificatori propri e stato `candidate`. La copertura riguarda i contratti
pubblici descritti qui, senza attestare identità bitwise con RNG, backend e
versioni R non fissate o completa equivalenza con ogni opzione di KH Coder.

Le nuove primitive sono API di libreria in memoria. Nel lotto originario di
ADR-0032 il planner persistente e l'interfaccia applicativa conservavano le
capacità già registrate: il catalogo non promuove automaticamente funzionalità
post-MVP nel percorso stabile. La successiva [ADR-0034](../adr/0034-riprogettazione-gui-e-laboratorio-avanzato.md)
autorizza un client GUI macOS delle medesime API, con risultati di sessione e
verifica applicativa distinta, senza introdurre persistenza o capability planner.
Non sono introdotti un formato di progetto, un parser CSV, un motore SQL o un
runtime R/Python di prodotto. R è esclusivamente un oracolo di sviluppo.

## Rappresentazioni e distanze

Il vocabolario della tabella documento-termine è ordinato; le righe conservano
l'ordine del chiamante. Conteggi nulli non occupano celle sparse. Il vocabolario
di classificazione è congelato sul training; i token fuori vocabolario sono
ignorati e contati esplicitamente.

Counts, presenza binaria, frequenze per mille e TF-IDF smussata sono trasformazioni
esplicite. Distanze ammesse: Jaccard, Dice, Simpson, coseno, euclidea e Manhattan.
Simpson usa le presenze: `s(A,B)=|A∩B|/min(|A|,|B|)`, `d=1-s`.
Entrambi vuoti danno similarità uno, un solo insieme vuoto zero. È una
dissimilarità simmetrica, non una metrica: può annullarsi per insiemi diversi
inclusi uno nell’altro e non garantisce la disuguaglianza triangolare.
I vettori nulli non hanno distanza coseno e producono failure tipizzata.
Una coppia di colonne entrambe nulle non produce un arco di co-occorrenza.
Ward richiede vettori euclidei secondo GS-MET-001-14: non si applica a una
matrice Jaccard facendo finta che sia euclidea.

### Preparazioni KH e coordinate CA

`KH-sample-z-score-v1` standardizza ciascuna riga oppure colonna:
`z=(x−media)/s`, `s²=Σ(x−media)²/(n−1)`, con almeno due valori per vettore.
`constantPolicy=reject` rifiuta varianza nulla; `zeros` restituisce il vettore
nullo. Il denominatore resta campionario. I riferimenti sono i sorgenti KH di
[MDS delle parole](https://github.com/ko-ichi-h/khcoder/blob/master/kh_lib/gui_window/word_mds.pm)
e [clustering dei documenti](https://github.com/ko-ichi-h/khcoder/blob/master/kh_lib/gui_window/doc_cls.pm).

`KH-per-thousand-external-exposure-v1` calcola `1000*x_ij/exposure_i` su conteggi
finiti non negativi. Il chiamante fornisce l'esposizione completa; le colonne
filtrate non la ricostruiscono. Un'esposizione nulla è rifiutata;
`zeroExposurePolicy=zeros` la ammette soltanto per una riga interamente nulla.

`KH-word-context-conditional-mean-v1` riceve vocabolari separati, anche sovrapposti, `targetIDs`
e `contextIDs`, e conteggi allineati per unità ai livelli `sentence`, `paragraph`,
`h5`…`h1`. Ogni coppia di righe rappresenta la stessa unità del livello dichiarato.
Per livello l e target i, ogni unità con target positivo contribuisce una volta:
`M_ij=Σ_l alpha_l * mean(context_j | target_i>0, livello_l)`.
Senza unità di supporto il contributo è zero. I coefficienti sono finiti,
anche nulli o negativi se dichiarati; la loro somma non viene rinormalizzata.
Ordine degli ID, livelli, pesi e numerosità del supporto sono restituiti.
Il chiamante prepara unità e gerarchia secondo
[KH A.6.8](https://khcoder.net/en/manual_en_v3.pdf); il motore non deduce frasi
o heading da una matrice.

`CA-coordinate-scaling-v1` proietta gli assi della CA esistente conservando
masse, valori singolari e indici delle righe/colonne incluse. Per gli assi con σ
positivo, `principal=D_mass^(−1/2) U σ`, `standard=D_mass^(−1/2) U` e
`symmetric=D_mass^(−1/2) U σ^0.5`; sul lato colonne si usa V.
La scelta è indipendente per righe e colonne. Qui `symmetric` significa biplot
simmetrico: nella [documentazione di R ca](https://cran.r-project.org/web/packages/ca/refman/ca.html)
la mappa `symmetric` usa coordinate principali su entrambi i lati, mentre
`symbiplot` distribuisce σ a metà. Le convenzioni sono distinte.

## MDS

La classica diagonalizza con LAPACK Apple
`B = -1/2 J D² J`, conserva gli autovalori con segno e costruisce
`X_k = U_k sqrt(max(lambda_k, 0))`. Gli assi mancanti sono nulli;
non si trasforma un autovalore negativo nel suo valore assoluto.

Per le quattro varianti storiche le dissimilarità sono scalate prima del calcolo
per limitare overflow; le coordinate
sono riportate nella scala originale. Le quattro varianti storiche richiedono che il quadrato
della scala sia finito e strettamente positivo, coerentemente con il kernel nativo
delle distanze; configurazioni collassate non definiscono Stress-1. La nuova
variante ordinale usa soltanto l’ordine delle dissimilarità e coordinate adimensionali.
La variante metrica minimizza lo stress grezzo
`sum(i<j)(distance(X_i,X_j)-D_ij)²` tramite SMACOF unit-weight.
La variante Kruskal non metrica usa regressione isotona PAVA con disparità uguali per
dissimilarità uguali, proiezione ai minimi quadrati senza riscalare le disparità e Stress-1.
Le parità sono secondary (disparità uguali); il passo usa il gradiente dell'obiettivo
normalizzato e mantiene il backtracking sul medesimo Stress-1.
La variante Sammon minimizza
`sum(i<j)((D_ij-d_ij)²/D_ij) / sum(i<j)D_ij`; richiede D_ij strettamente
positive fuori diagonale. Il gradiente usa backtracking e accetta soltanto passi
non crescenti rispetto al proprio obiettivo.

Per tutti i metodi iterativi: inizializzazione classica con piccola perturbazione
SplitMix64 registrata come default compatibile, oppure configurazione uniforme
centrata casuale con seed esplicito; massimo passi e tolleranza espliciti, storia dell'obiettivo,
numero di passi accettati e convergenza separata dal raggiungimento del limite.
Non si dichiara raggiunto l'ottimo globale di un obiettivo non convesso.

### SMACOF ordinale e ricerca multipla

`MDS-ordinal-SMACOF-secondary-ties-normalized-raw-stress-v1` è distinta dal
metrico e dal Kruskal Stress-1. PAVA aggrega i tie con il loro peso, proietta
le distanze correnti sul cono monotono e riscalare le disparità serve a imporre
`Σ(i<j) δ_ij² = m`, `m=n(n−1)/2`. L’obiettivo è
`Σ(i<j)(d_ij(X)−δ_ij)²/m`. La norma fissa impedisce il collasso banale.
Il passo Guttman per pesi completi unitari è `X_next=B(X)X/n`; le coppie
coincidenti hanno contributo zero. Dopo il passo si ristimano le disparità;
si accettano soltanto obiettivi non crescenti. La variante ammette
scalarità finite anche estreme perché non deve preservare una scala metrica.

Il nuovo ingresso `ordinalMultidimensionalScaling(..., ties:)` offre anche
`MDS-ordinal-SMACOF-primary-ties-normalized-raw-stress-v1`. Primary ammette
disparità distinte nello stesso blocco osservato e ordina le sue coppie per
distanza corrente e identità canonica prima della proiezione isotona. Secondary
conserva invece una disparità comune per blocco. Entrambe mantengono la norma
e l'obiettivo sopra dichiarati. I nuovi tag `mds-ordinal` e `mds-ordinal-search`
risolvono primary; le API precedenti conservano secondary. La terminologia segue
la [documentazione primaria smacof](https://cran.r-project.org/web/packages/smacof/refman/smacof.html),
senza presumere quale versione R sia installata in una distribuzione KH.

`multidimensionalScalingSearch` esegue da 1 a 1.000 configurazioni casuali
reali per un solo metodo iterativo; il metodo classico non è una ricerca.
L’avvio `r` usa `seed &+ UInt64(r)`. Restituisce tutti i risultati, cronologie,
seed e convergenze, più l’indice del minimo; a parità conserva il primo.
Nessuna selezione fra obiettivi di metodi diversi o promessa di ottimo globale.
L’ammissione controlla sia lavoro cumulativo sia celle conservate per tutti gli avvii.

## Reti, comunità e layout

La proiezione delle comunità è non diretta: somma direzioni e archi paralleli,
omette self-loop e pesi nulli, normalizza uniformemente le intensità positive.
Gli isolati restano singleton. Le tre varianti massimizzano, lungo la propria
sequenza, la modularità del grafo originale
`Q=Σ_c[w_in(c)/W − γ(strength(c)/(2W))²]`, con `0<γ≤1000`.
Tie e comunità conservano l’ordine dichiarato dei nodi e il primo massimo.

- `GirvanNewman-inverse-strength-exact-binary64-v2`: ricalcola la edge betweenness
  dopo ogni rimozione. I reciproci delle intensità proiettate sono binary64;
  somme dei costi e accumuli non negativi usano 34 limb UInt64, con confronti
  esatti delle somme rappresentate, senza epsilon che fonda cammini distinti.
  L’uscita è arrotondata nearest-even una sola volta. Normalizzazione, divisioni
  e rapporti fra molteplicità restano binary64: non è aritmetica razionale dei
  pesi originari. Sostituisce v1, che poteva perdere cammini pari per associazione
  delle somme e rompere i tie canonici. L’ammissione conteggia il fattore 34 di
  lavoro e `34*(3N+2E+1)` celle aggiuntive prima dei buffer.
- `ClausetNewmanMoore-weighted-v1`: agglomerazione sparsa con guadagni di
  modularità e heap di candidati; conserva gerarchia e storia dell’obiettivo.
- `Walktrap-weighted-mean-loops-v1`: cammini pesati di lunghezza 1–64,
  self-loop con intensità media incidente e fusioni Ward fra comunità adiacenti.

I layout sono risultati distinti dal grafo e dalle comunità. FR usa repulsione
esatta, attrazione degli archi, `k=sqrt(4/n)` e raffreddamento lineare nel quadrato
`[-1,1]²`. KK usa molle su distanze in hop, passi Newton con backtracking monotono
e distanza virtuale `2*max(1,diametro)` fra componenti: questa estensione non
trasforma distanze irraggiungibili in cammini osservati. I pesi non partecipano ai
layout; direzioni e multiarchi coalescono, loop e archi nulli sono omessi.
Coordinate, seed, iterazioni, arresto e storia energetica KK sono espliciti.
L’ammissione KK somma preparazione all-pairs BFS e iterazioni nello stesso
budget, prima dei buffer. La facciata controlla la cardinalità delle posizioni
prima di convertirle in un nuovo array.

`Prim-minimum-spanning-forest-v1` usa invece i pesi come costi non negativi:
omette loop, prende il minimo costo fra paralleli e conserva costi nulli.
Restituisce la foresta per componenti, archi originali e costo totale; la variante
albero rifiuta grafi vuoti o disconnessi. Nessuna conversione implicita intensità→costo.

## SOM e CLARA

SOM usa una griglia non toroidale, matching euclideo e vicinato gaussiano.
Il default rettangolare conserva `SOM-batch-gaussian-rectangular-v1`. La variante
`SOM-batch-gaussian-hexagonal-odd-row-v1` sposta le righe dispari di mezza cella:
`(x,y)=(colonna+(riga mod 2)/2, riga*sqrt(3)/2)`. La distanza di questa
geometria governa il vicinato e l’errore topografico; i vicini immediati sono
a distanza uno, al massimo quattro nel rettangolo e sei nell’esagono.
Per ogni epoca:
`m_u = sum_i h(u,bmu_i) x_i / sum_i h(u,bmu_i)`.
Il raggio interpola geometricamente da initialRadius a finalRadius, con endpoint
esatti e calcolo logaritmico quando il rapporto non è rappresentabile. L'aggregazione di
somme e popolazioni per unità vincente è algebricamente equivalente alla formula
diretta e viene confrontata con essa entro 1e-12. Si restituiscono prototipi,
assegnazioni, errore di quantizzazione e topografico, epoche e seed.
Norme estreme usano un calcolo stabile; il confronto di convergenza non elimina
una tolleranza positiva mediante un quadrato in underflow. Un riscalamento SOM
si applica solo agli input estremi e solo quando conserva ogni valore; altrimenti
il fit fallisce con `exploratory.numeric-range`, senza prototipi o diagnostiche
zero apparentemente validi. Gli input ordinari mantengono il percorso vDSP.
La mappa non è una proiezione che garantisce distanze globali.
La U-matrix restituisce per ogni unità la mediana delle distanze euclidee dai
codebook immediatamente vicini; ai bordi usa i soli vicini presenti, per una
singola unità restituisce zero. `SOM-codebooks-Ward-v1` compone l’HAC Ward
euclidea già esistente sui prototipi, conservando identità, albero e assegnazioni;
non implementa un diverso aggiornamento SOM o una nuova formula Ward.

### Profilo KH online a due fasi

`SOM-KH-online-inverse-two-phase-hexagonal-v1` e
`SOM-KH-online-inverse-two-phase-rectangular-v1`
ricevono dati già preparati. Z-score ed esposizione sono operazioni precedenti
esplicite. Le due fasi continuano gli stessi codebook: una osservazione per passo
in ordine ciclico, BMU euclidea e aggiornamento gaussiano online. I riferimenti
sono il [SOM pubblico di KH](https://github.com/ko-ichi-h/khcoder/blob/master/kh_lib/plotR/som.pm)
e il [pacchetto R som](https://github.com/cran/som/blob/master/R/som.R).

Per n righe i default sono `L1=2n`, `L2=10n`, learning rate iniziali
`0.05, 0.02`, raggi iniziali `min(width,height)` e `min(3,width,height)`;
la topologia predefinita è esagonale. Ogni fase di L passi usa
`alpha_t=alpha_0*C/(C+t)`, `C=L/100`, e
`radius_t=1+(radius_0−1)*(L−t)/L`, per `t=1…L`.
L'uscita conserva fasi, codebook iniziali/intermedi/finali, assegnazioni,
diagnostiche e U-matrix con la mediana dei vicini immediati. Il parametro
opzionale `codebookClusterCount` aggiunge l'HAC Ward dei codebook con ammissione
cumulativa di lavoro/celle; non cambia l'aggiornamento online o l'identità SOM.

`SOM-PCA-linear-unscaled-canonical-v1` costruisce la griglia da media, primi due
assi PCA e deviazioni standard campionarie, su tick `−2…2`; assegna il primo asse
alla dimensione maggiore. Segni canonici rendono deterministica la scelta;
basi degeneri non hanno un'unica orientazione matematica. Solo questa PCA usa
LAPACK `dgesvd` di Accelerate per preservare anche un secondo asse rappresentabile
su dati con scale molto diverse. È una correzione numerica secondo ADR-0043,
senza attestazione di velocità; workspace e output sono ammessi prima dei buffer.
Codebook forniti dal chiamante usano `SOM-explicit-codebooks-v1` e non avviano PCA.

### CLARA

CLARA estrae campioni senza rimpiazzo, include i migliori medoidi già trovati,
esegue swap PAM miglioranti nel campione e sceglie il minor costo euclideo
sull'intero dataset. Nessuna matrice delle distanze dell'intero dataset è richiesta.
Campioni, dimensione, massimo swap e seed fanno parte del contratto.
Il risultato resta un'approssimazione campionata.

## Classificazione e topic

Naive Bayes usa prior empirici di classe e
`P(w|c) = (count(c,w)+alpha)/(count(c,*)+alpha*V)`, alpha positivo.
Scoring sparso nel dominio logaritmico, normalizzazione log-sum-exp e tie-break
nell'ordine canonico delle classi. I posteriori del modello non sono confidenze calibrate.
La validazione k-fold ricostruisce modello e vocabolario su ciascun training fold,
separa i documenti di test e restituisce matrice di confusione e accuratezza.

`MultinomialNaiveBayes-incremental-counts-v1` conserva in memoria classi,
vocabolario canonico, conteggi di documenti e token per classe e smoothing.
L'aggiornamento unisce nuove classi e termini riallineando i conteggi precedenti;
non richiede il training già accumulato. Lo stato transitorio è distinto dal
modello derivato ispezionabile, che espone prior e likelihood logaritmici.
Uno stato a classe unica può essere continuato; la predizione richiede almeno
due classi. Questi DTO non introducono un file `.knb` o un formato di progetto.

`MultinomialNaiveBayes-stratified-CV-CohenKappa-v1` restituisce le predizioni fuori
fold e `κ=(p_o−p_e)/(1−p_e)` sulle stesse etichette, con accordo osservato/atteso
e seed. Training, modello e predizione hanno ammissione cumulativa. Il riferimento
funzionale è [KH A.6.3–A.6.6](https://khcoder.net/en/manual_en_v3.pdf);
le probabilità non diventano confidenze calibrate.

LDA usa priors simmetrici alpha e beta positivi e la condizionale collassata
`P(z_i=k|rest) proportional (n_dk+alpha)(n_kw+beta)/(n_k+V*beta)`.
Count buffer piatti, scansione documenti/token canonica e SplitMix64 con seed.
I reciproci dei denominatori sono aggiornati soltanto per i topic modificati.
Burn-in, numero di campioni e thinning sono espliciti; theta e phi sono medie
dei campioni trattenuti. La probabilità predittiva usa la media dei prodotti theta*phi sui campioni;
il prodotto delle medie non è equivalente. La perplexity restituita è sul training,
non una valutazione held-out. La selezione del numero di topic è un’operazione
distinta, con diagnostiche esplicite e split di cross-validation dichiarati.
L'integrazione esatta degli stati di un corpus minimo verifica il campionatore
entro 0,02 assoluto; il caso a un topic ha oracolo esatto entro 1e-12.

### Selezione del numero di topic

`LDA-model-selection-training-vocabulary-CV-v1` ammette al massimo 32 K distinti,
ciascuno in 1–1.024, ordina i candidati e conserva score, copertura di ogni fold,
seed e modello scelto. Il default minimizza la perplexity held-out aggregata
come `exp(-Σ logLikelihood / Σ tokenValutati)`, non la media delle perplexity.
Ogni fold ricostruisce il proprio vocabolario di training e congela phi.
Il fold-in dimezza i token noti mantenendo l’ordine originale: prima metà
osservata, seconda valutata; gli OOV sono esclusi e contati. I target non
aggiornano i conteggi. Senza contesto la media Dirichlet simmetrica è analitica;
documenti senza token noti non eseguono sweep. Un test tutto OOV fallisce.
Questi fold servono alla selezione: non sono un test finale indipendente.

Le diagnostiche nominate conservano `nil` e motivo quando non definite:

| Criterio | Definizione e direzione |
| --- | --- |
| CaoJuan2009 | Media dei coseni fra topic, da minimizzare |
| Arun2010 | `Σ(σ_k−q_k)(log σ_k−log q_k)`, con valori singolari di phi e `q_k=Σ_d length_d*theta_dk/max_d length_d`; non sostituisce una JS né normalizza implicitamente i vettori; da minimizzare |
| Deveaud2014 | Somma sulle coppie del half-Jeffreys `0.5*Σ_v(p_v−q_v)(log p_v−log q_v)`, divisa per `K(K−1)` secondo il contratto di riferimento; da massimizzare |
| Griffiths2004 | Log harmonic mean delle likelihood collassate `p(words|assignments)`, valutato in log-domain sui campioni trattenuti; da massimizzare |

Le likelihood sono opt-in e non cambiano la catena o il default del fit.
`folds=0` è ammesso per sole diagnostiche, non per il criterio held-out.
L’ammissione è cumulativa prima di tutti i fit: conteggia Gibbs, accumulo theta
anche per documenti vuoti, phi, predizioni, likelihood richieste, diagnostiche e
fold-in. Celle documento×topic vengono controllate prima della tabella sparsa;
fit e inferenza restano cancellabili, senza risultati parziali pubblicati.
I Gibbs sweep e le predizioni saltano gli indici dei documenti vuoti senza
saltare estrazioni casuali: theta continua a includere tutti i documenti.

## Collocazioni KH e rilevanza dei composti

`GlifiKHCollocationAnalysis` applica [KH A.5.6, pagina 40](https://khcoder.net/en/manual_en_v3.pdf):
`MI3=log2(a³N/(F1F2))`, `p=F2/(N−F1)`, `E=pF1S`,
`Z=(a−E)/sqrt(E(1−p))`. F1 e F2 sono TF globali di due chiavi distinte,
N è l'esposizione completa in token e S il numero di posizioni della finestra,
esclusa quella del nodo. Le finestre sovrapposte possono produrre a maggiore
di F1 o F2. I conteggi devono essere coerenti con corpus, posizioni e massimo
numero di coppie; non sono margini di una tabella 2×2 di opportunità.
MI3 è assente per a nullo; Z è assente senza background o con varianza nulla.
L'uscita espone entrambi gli identificatori e l'aspettativa della finestra.
Non viene applicato smoothing implicito.

`TermExtract-LR-FLR-independent-average1-v1` riceve componenti presegmentati e
frequenza indipendente f di ogni candidata. Le adiacenze sono soltanto interne
alle candidate multiword: token somma le occorrenze pesate da f, type conta i
vicini distinti per lato. Con L componenti,
`LR=(Π_i(left_i+1)(right_i+1))^(1/(2L))` e `FLR=f*LR`.
Le entrate duplicate si aggregano; ogni posizione di un componente ripetuto
contribuisce. f non include un'occorrenza contenuta in una candidata più lunga.
La convenzione segue le formule 3–4 di
[Yumoto, Mori e Nakagawa](https://forest.ynu.ac.jp/Forest/TermExtraction/NL.pdf);
la distinzione type/token e f/TF è discussa da
[Yoshida e Nakagawa](https://aclanthology.org/I05-1024.pdf).

L'estrazione opzionale riceve `GlifiCodingDocument` già annotati e una regola
POS esplicita: run massime, chiavi escluse e minimo/massimo di componenti.
Frasi, paragrafi e gap di fonte non bianchi separano le run. POS assenti
falliscono; run troppo lunghe falliscono senza troncamento. Identità, contratti
linguistici, indici dei token e intervalli UTF-8 esatti sono conservati.
Le chiavi seguono l'uguaglianza canonica Unicode di Swift, senza case folding
o analisi linguistica implicita; le superfici coincidono invece byte per byte
con la fonte. Preannotazioni inglesi, giapponesi o italiane rendono eseguibile
il calcolo: non certificano un tokenizer inglese/giapponese, MeCab o ChaSen.
Il ranking matematico e la qualità dell'estrazione linguistica restano distinti,
coerentemente con il ruolo di TermExtract in [KH A.4.4](https://khcoder.net/en/manual_en_v3.pdf).

Il motore ammette 100.000 candidate/occorrenze, 1.000.000 componenti o token,
64 componenti per candidata e 64 MiB testuali aggregati. Lo stesso budget di
lavoro copre estrazione, conteggi, scoring e ordinamento: default 100.000.000,
massimo 1.000.000.000. Frequenze traboccanti, valori non finiti e cancellazione
impediscono la restituzione di risultati parziali. Kit e CLI applicano prima
i propri limiti di trasporto, più restrittivi.

## Regole di codifica

File bounded a 64 KiB, massimo 256 codici, 1.024 nodi per espressione e profondità
32. Commenti e intestazioni seguono la convenzione KH Coder; il parser produce
un'algebra propria, senza eval o esecuzione di linguaggi host.

Supportati: booleani `and/or/not` e `&/|/!`, `&!` e `|!`, parentesi;
aritmetica `+ - * /`, confronti `> < >= <= == !=`; conteggio per termine,
`lw`, `lc`, `No.`; frasi con `+` senza spazi; `near/seq` con
distanza e confine `b/d`; stringhe letterali tra apici singoli;
variabili esterne e riferimenti `<*Codice>`; vincoli POS, flessione e forma.
Operatori aritmetici e booleani richiedono separazione lessicale.

Il profilo predefinito italiano usa forme di superficie normalizzate; non inventa
lemmi o POS. Annotazioni esplicite possono essere fornite al motore con il loro
contratto linguistico; annotazioni assenti richieste da una regola falliscono.
La pipeline italiana opzionale offre lemmi e POS single-best di Apple Natural
Language installato e stemming Snowball italiano 3.1.0 originale Swift. Stem e
lemma restano distinti; POS usa i tag grezzi Apple, senza inventare feature
morfologiche. Predizioni sconosciute restano `nil` con stato esplicito e fanno
fallire la codifica quando richieste. Fonte, offset UTF-8 e provenienza OS sono
conservati; la versione del modello Apple non esposta resta assente. Disponibilità
non equivale ad accuratezza linguistica; italiano è la sola baseline di questo lotto.
Variabili mancanti, divisione per zero, riferimenti ignoti/ciclici, overflow,
profondità e limiti delle evidenze falliscono senza produrre una matrice parziale.
Gli intervalli UTF-8 decodificati rispettano gli stessi invarianti del costruttore;
le superfici esterne coincidono con i byte sorgenti, non soltanto per equivalenza
canonica Unicode. I qualificatori sono validati in tutti i rami prima della
valutazione; frecce POS/flessione non sono separatori di prossimità. Letterali
numerici non finiti falliscono; una parola numerica resta possibile tra virgolette.
Ogni candidato di prossimità consuma il limite condiviso anche quando scartato,
con cancellazione periodica. Il bound non riparte a ogni codice o documento.
Anche le evidenze aggregate hanno un budget; i riferimenti non ne provocano
un'espansione esponenziale. Una negazione può applicare un codice senza un
intervallo positivo, e questo non viene inventato.

## Prestazioni, verifica e stato

GlifiKit esegue i nuovi operatori con `@concurrent`, fuori dall'actor chiamante,
con errori tipizzati e cancellazione propagata. Il calcolo numerico impiega
LAPACK/vDSP di sistema; limiti per celle, coppie e lavoro vengono controllati prima
delle allocazioni principali. Nessuna accelerazione cambia la formula per inseguire
il solo throughput.

Oracoli R eseguibili, casi esatti, equivalenza della SOM aggregata, test avversari,
parità Core/Kit e benchmark Release sono registrati in [GS-VER-160](../evidenze/GS-VER-160-operatori-analitici-nativi.md).
Le nove varianti revisionate hanno manifest V0–V4 e stato `supported` per il loro
contratto headless secondo ADR-0031; la facciata espone lo stato per identificatore,
con default conservativo `candidate`. [GS-VER-161](../evidenze/GS-VER-161-revisione-scientifica-operatori.md)
registra la revisione tecnica automatica, senza simulare una firma umana.
La review scientifica esterna V6 e le prove su dispositivo restano aperte.

### Limiti dell’ampliamento 2026-11-22

Budget esplorativi standard: 5.000.000 celle per rappresentazione densa,
2.000 oggetti pairwise e 500.000.000 unità stimate di lavoro. Le ricerche
multi-start includono spazio per coordinate e cronologie di tutti gli avvii.
SOM ammette anche il lavoro del vicinato; Ward sui codebook ha ammissione
separata e anticipata nella facciata avanzata. La selezione LDA e il fold-in
ammettono al massimo 20.000 documenti; il fit controlla le celle documento×topic.
Restano i bound della tabella: 2.000.000 token e 100.000 termini.

I grafi hanno bound standard di 2.000 nodi, 100.000 archi, 1.000.000 celle
pairwise e 200.000.000 unità di lavoro; i metodi quadratici hanno ammissione
più restrittiva sui buffer effettivi. La pipeline linguistica standard ammette
1 MiB di testo, 100.000 token, 4.096 byte per token e 16 MiB di campi UTF-8
in output; la codifica aggregata ammette 10.000 unità entro lo stesso MiB.

Gli operatori aggiunti restano `candidate`, anche quando i test locali passano:
non ereditano i manifest delle nove varianti storiche per somiglianza del nome.
[GS-VER-233](../evidenze/GS-VER-233-completamento-kh-coder.md) conserva i mirati
e il gate locale del completamento, superato nel suo perimetro storico.
[GS-VER-234](../evidenze/GS-VER-234-riverifica-correttezza-completezza.md) registra
la successiva riverifica, le correzioni e i limiti KH aperti sulla revisione
allora esaminata. I nuovi profili di ADR-0043 hanno implementazioni dedicate;
la loro verifica integrata è in corso in GS-VER-300. I quattordici nuovi tag
riusano schema 1 e il medesimo comando CLI, secondo GS-API-002.
GUI, persistenza, nuove lingue automatiche, V6 esterno e dispositivi non sono
promossi da questo incremento.

## Riferimenti

- [MDS classica di R](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/cmdscale.html).
- [SOM batch di R](https://stat.ethz.ch/R-manual/R-devel/library/class/html/batchSOM.html).
- [Kohonen 3.0, algoritmo batch](https://www.jstatsoft.org/article/view/v087i07).
- [Blei, Ng e Jordan, Latent Dirichlet Allocation](https://www.jmlr.org/papers/v3/blei03a.html).
- [Apple vDSP distanceSquared](https://developer.apple.com/documentation/accelerate/vdsp/distancesquared(_:_:)-3oub3).

## Riproduzione tramite GlifiKit e CLI

[GS-API-002](../api/02-richieste-analitiche.md) espone gli operatori in memoria con
request tipizzata e digest canonico, anche tramite `text-analysis --request`.
Non cambia formule o manifest scientifici. La parità di trasporto è verificata
separatamente in GS-VER-162; quel lotto non estende planner, UI e persistenza.
L'estensione applicativa successiva segue GS-UX-001-17 e ADR-0034; esiti e limiti
sono registrati in [GS-VER-222](../evidenze/GS-VER-222-riprogettazione-gui.md),
senza modificare formule, varianti o manifest numerici.
