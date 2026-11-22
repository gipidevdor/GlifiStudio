<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Operatori analitici compatibili con le famiglie KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-23 |
| Tipo | Specifica dei contratti numerici e della copertura |
| Versione | 1.2.0 |
| Stato | Contratti revisionati; supporto numerico per variante |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Ambito richiesto dall'iniziatore; promozione scientifica separata secondo ADR-0031 |
| Documento padre | [GS-MET-001](README.md) |
| Riferimenti | RF-087; ADR-0032; GS-VER-160 |

## Scopo e copertura

La richiesta comprende tutte le famiglie analitiche di KH Coder, nella libreria
headless GlifiCore e nella facciata GlifiKit. Il riferimento verificato è il
[manuale ufficiale KH Coder 3](https://khcoder.net/en/manual_en_v3.pdf),
sezioni A.2.5, A.5, A.6 e A.7; il topic model è documentato anche nel
[registro ufficiale delle versioni](https://khcoder.net/versions.html).
Compatibilità funzionale di famiglia e parità numerica con una particolare
versione di KH Coder sono proprietà distinte: tokenizzazione, inizializzazione e
varianti native sono dichiarate, senza sostituire silenziosamente quelle del programma.

| Famiglia | Implementazione nella libreria |
| --- | --- |
| Frequenze TF/DF, distribuzioni e filtri | GlifiCorpusAnalyzer; GlifiNGramFrequencyAnalysis; GlifiTermWeighting |
| Ricerca di parole/documenti e KWIC | GlifiQueryParser/Evaluator; sessione GlifiKit esistente |
| Associazione di parole e tabelle di contingenza | GlifiKeynessAnalysis; GlifiContingencyAnalysis; GlifiCollocationAnalysis |
| Analisi delle corrispondenze | CA-SVD-v1 esistente; facciata anche su tabelle di parole e codici |
| MDS classica, Kruskal e Sammon | GlifiExploratoryAnalysis.multidimensionalScaling |
| Clustering gerarchico | HAC esistente per vettori; Lance-Williams per dissimilarità single/complete/average |
| CLARA sui documenti | CLARA-PAM-Euclidean-v1 |
| Reti di co-occorrenza | Reti lessicali esistenti; rete Jaccard anche dalle colonne di una matrice di codici |
| Mappe auto-organizzanti | SOM-batch-gaussian-rectangular-v1 |
| Classificazione supervisionata | MultinomialNaiveBayes-Laplace-v1 con validazione stratificata |
| Topic model | LDA-collapsed-Gibbs-symmetric-v1; LSA e NMF esistenti |
| Regole automatiche e frequenze dei codici | GlifiCodingRuleSet e matrice multi-label con evidenze UTF-8 |
| Tabelle incrociate e similarità dei codici | crosstab con denominatori/mancanti espliciti; distanze condivise |
| CA, MDS, clustering, rete e SOM dei codici | Stessi operatori numerici sulla matrice documento-codice |
| Matrici documento-parola, parola-contesto, documento-codice | Tabella sparsa, trasposizione bounded e matrice binaria dei codici |

Le nuove primitive sono API di libreria in memoria. Il planner persistente e
l'interfaccia applicativa conservano le capacità già registrate: il nuovo
catalogo non promuove automaticamente funzionalità post-MVP nel percorso stabile.
Non sono introdotti un formato di progetto, un parser CSV, un motore SQL o un
runtime R/Python di prodotto. R è esclusivamente un oracolo di sviluppo.

## Rappresentazioni e distanze

Il vocabolario della tabella documento-termine è ordinato; le righe conservano
l'ordine del chiamante. Conteggi nulli non occupano celle sparse. Il vocabolario
di classificazione è congelato sul training; i token fuori vocabolario sono
ignorati e contati esplicitamente.

Counts, presenza binaria, frequenze per mille e TF-IDF smussata sono trasformazioni
esplicite. Distanze ammesse: Jaccard, Dice, coseno, euclidea e Manhattan.
I vettori nulli non hanno distanza coseno e producono failure tipizzata.
Una coppia di colonne entrambe nulle non produce un arco di co-occorrenza.
Ward richiede vettori euclidei secondo GS-MET-001-14: non si applica a una
matrice Jaccard facendo finta che sia euclidea.

## MDS

La classica diagonalizza con LAPACK Apple
`B = -1/2 J D² J`, conserva gli autovalori con segno e costruisce
`X_k = U_k sqrt(max(lambda_k, 0))`. Gli assi mancanti sono nulli;
non si trasforma un autovalore negativo nel suo valore assoluto.

Le dissimilarità sono scalate prima del calcolo per limitare overflow; le coordinate
sono riportate nella scala originale. Tutte le varianti richiedono che il quadrato
della scala sia finito e strettamente positivo, coerentemente con il kernel nativo
delle distanze; configurazioni collassate non definiscono Stress-1.
La variante metrica minimizza lo stress grezzo
`sum(i<j)(distance(X_i,X_j)-D_ij)²` tramite SMACOF unit-weight.
La variante non metrica usa regressione isotona PAVA con disparità uguali per
dissimilarità uguali, proiezione ai minimi quadrati senza riscalare le disparità e Stress-1.
Le parità sono secondary (disparità uguali); il passo usa il gradiente dell'obiettivo
normalizzato e mantiene il backtracking sul medesimo Stress-1.
La variante Sammon minimizza
`sum(i<j)((D_ij-d_ij)²/D_ij) / sum(i<j)D_ij`; richiede D_ij strettamente
positive fuori diagonale. Il gradiente usa backtracking e accetta soltanto passi
non crescenti rispetto al proprio obiettivo.

Per tutti i metodi iterativi: inizializzazione classica con piccola perturbazione
SplitMix64 registrata, massimo passi e tolleranza espliciti, storia dell'obiettivo,
numero di passi accettati e convergenza separata dal raggiungimento del limite.
Non si dichiara raggiunto l'ottimo globale di un obiettivo non convesso.

## SOM e CLARA

SOM usa una griglia rettangolare non toroidale, matching euclideo e vicinato gaussiano.
Per ogni epoca:
`m_u = sum_i h(u,bmu_i) x_i / sum_i h(u,bmu_i)`.
Il raggio decade geometricamente da initialRadius a finalRadius. L'aggregazione di
somme e popolazioni per unità vincente è algebricamente equivalente alla formula
diretta e viene confrontata con essa entro 1e-12. Si restituiscono prototipi,
assegnazioni, errore di quantizzazione e topografico, epoche e seed.
La mappa non è una proiezione che garantisce distanze globali.

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

LDA usa priors simmetrici alpha e beta positivi e la condizionale collassata
`P(z_i=k|rest) proportional (n_dk+alpha)(n_kw+beta)/(n_k+V*beta)`.
Count buffer piatti, scansione documenti/token canonica e SplitMix64 con seed.
I reciproci dei denominatori sono aggiornati soltanto per i topic modificati.
Burn-in, numero di campioni e thinning sono espliciti; theta e phi sono medie
dei campioni trattenuti. La probabilità predittiva usa la media dei prodotti theta*phi sui campioni;
il prodotto delle medie non è equivalente. La perplexity restituita è sul training,
non una valutazione held-out. Il numero di topic non viene scelto sul test.
L'integrazione esatta degli stati di un corpus minimo verifica il campionatore
entro 0,02 assoluto; il caso a un topic ha oracolo esatto entro 1e-12.

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
Variabili mancanti, divisione per zero, riferimenti ignoti/ciclici, overflow,
profondità e limiti delle evidenze falliscono senza produrre una matrice parziale.
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
separatamente in GS-VER-162; planner, UI e persistenza non sono estesi.
