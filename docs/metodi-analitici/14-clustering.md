<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Clustering

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-14 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.3.2 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-28 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |
| Riferimenti | GS-MET-001-23; ADR-0043; GS-DOR-305; GS-VER-305 |

## Contratto comune

L'implementazione ottimizzata in GS-VER-169 conserva le distanze dei cluster
invariati in una tabella triangolare. Single/complete aggiornano soltanto le
relazioni del cluster fuso; Ward ricalcola soltanto le distanze del nuovo
centroide. Average conserva le distanze originali e la stessa somma diretta
ordinata sui membri, evitando variazioni di arrotondamento da ricorrenze.
I pareggi continuano a usare le identità correnti. Le due tabelle condensate
di average occupano al massimo le celle della precedente tabella quadrata;
gli altri linkage ne usano una sola. La ricerca della coppia minima resta
cubica nel caso peggiore; non è dichiarata una complessità quadratica generale.

K-means++ aggiorna incrementalmente il minimo delle distanze dai centri già
scelti; Lloyd calcola una sola distanza per centro e raggruppa i membri in un
solo passaggio. Seed, consumo del PRNG, ordine delle somme, pareggi e numero
di iterazioni restano invariati. Non sono introdotte approssimazioni o
parallelizzazioni delle riduzioni.

Un risultato **DEVE** registrare unità in ingresso, rappresentazione, preprocessing,
metrica/dissimilarità, algoritmo e versione, parametri, inizializzazione, seed,
criterio di arresto, numero di iterazioni, funzione obiettivo e diagnostica. “Cluster”
senza questi elementi non è un artefatto valido.

## Clustering gerarchico agglomerativo

`HAC-v1` parte da cluster singleton e fonde ripetutamente la coppia con
dissimilarità minima; le parità sono risolte dall'ordine canonico delle identità.
La matrice deve essere simmetrica, finita, con diagonale zero. Il linkage è uno tra:

```text
single:   d(A,B) = min_{i∈A,j∈B} d(i,j)
complete: d(A,B) = max_{i∈A,j∈B} d(i,j)
average:  d(A,B) = [Σ_{i∈A,j∈B} d(i,j)] / (|A||B|)
Ward:     incremento della somma dei quadrati intra-cluster dopo la fusione
```

`Ward-v1` seleziona la fusione con incremento
`Δ(A,B)=|A||B|/(|A|+|B|) × ||μ_A-μ_B||₂²` ed è ammesso soltanto per vettori in
spazio euclideo con distanza euclidea quadratica e centroidi definiti. Non può
essere combinato con Jaccard, Manhattan o divergenze. L'output conserva l'intero albero di fusioni, altezze e appartenenze;
un taglio a `k` o a soglia è un'operazione separata.

La riverifica [GS-VER-234](../evidenze/GS-VER-234-riverifica-correttezza-completezza.md)
corregge i casi estremi: distanze single/complete/average recuperano norme
rappresentabili con un calcolo stabile quando il quadrato va in under/overflow.
Ward non pubblica incremento zero per centroidi distinti quando il valore positivo
non è rappresentabile; produce `hac.numeric-range`. Quando solo il quadrato
intermedio trabocca ma Δ è rappresentabile, l’ordine scalato dei prodotti e una
radice stabile recuperano Δ e altezza. Le colonne costanti dei centroidi conservano
il valore originario invece di azzerarlo o introdurre una variazione da divisioni
ripetute. Questa correzione può modificare bit e tie rispetto alla revisione
precedente; non estende retroattivamente le attestazioni di identità storiche.

Il taglio a soglia include tutte le fusioni con altezza minore o uguale alla
soglia, comprese le parità; la soglia è finita e non negativa. Entrambi i tagli
validano l'intero albero, incluse identità attive, dimensioni, altezze finite e
monotone e incrementi Ward, prima di seguirne i riferimenti. Le etichette sono
rinumerate per prima apparizione nell'ordine delle unità in ingresso.

## Profilo KH Ward.D2 su dissimilarità

[ADR-0043](../adr/0043-completezza-funzionale-kh-pubblico.md) autorizza il profilo
separato `KH-hclust-WardD2-dissimilarities-v1`. Riceve una matrice simmetrica,
finita, non negativa con diagonale zero e applica la ricorrenza sui quadrati:

```text
d(A∪B,C)² = [(|A|+|C|)d(A,C)² + (|B|+|C|)d(B,C)² − |C|d(A,B)²]
            / (|A|+|B|+|C|)
```

Le altezze sono radici delle dissimilarità aggiornate. La scelta della coppia
minima e i tie seguono le identità correnti canoniche. La scalatura per potenze
di due evita overflow intermedi evitabili. Dopo la scalatura, i quadrati
positivi iniziali e aggiornati **DEVONO** essere normali: valori subnormali
possono quantizzare distanze distinte nello stesso quadrato e creare un falso
tie. Zeri sono ammessi soltanto per distanze realmente nulle. Quadrati positivi
nulli/subnormali o altezze non rappresentabili producono `kh-ward.numeric-range`.
Il superamento dei limiti di oggetti, celle o lavoro produce invece
`kh-ward.resource-limit`, categoria `insufficientResources`.
Il profilo ammette le dissimilarità
Jaccard/cosine usate dal flusso KH pubblico come compatibilità algebrica;
**NON DEVE** chiamare le altezze incrementi della varianza. `wardIncrement` è
sempre assente. Non garantisce gli stessi tie interni di ogni versione R.
Il Ward vettoriale sopra specificato resta distinto e conserva i divieti esistenti.
La verifica R indipendente e i limiti cumulativi della baseline sono registrati
in GS-VER-300. La successiva rifinitura dei controlli di range e categoria delle
failure segue GS-DOR-305; [GS-VER-305](../evidenze/GS-VER-305-rifinitura-kh.md)
registra il nuovo gate locale superato. L'identificatore matematico v1 resta invariato; la correzione
rifiuta casi che prima potevano restituire fusioni numericamente ambigue,
senza estendere le attestazioni storiche o promuovere la variante.

## K-means

`KMeans-Lloyd-v1` minimizza `Σ_i ||x_i-μ_{c_i}||₂²` per `1≤k≤n`, usando iterazioni
di assegnazione al centroide più vicino e ricalcolo dei centroidi. Il descrittore
specifica standardizzazione, `k`, inizializzazione (`k-means++` candidata), PRNG,
seed, restart, massimo iterazioni, tolleranza relativa dell'obiettivo e politica dei
cluster vuoti. `k-means++-v1`, se scelto, estrae il primo centro uniformemente tra
le unità e i successivi con probabilità proporzionale alla distanza euclidea
quadratica dal centro già scelto più vicino. Il run scelto minimizza l'obiettivo,
con tie-break deterministico. È P1 e non accetta distanze arbitrarie.

La variante in libreria usa stabilità delle assegnazioni e limite esplicito di
iterazioni (`1…100.000`), rifiuta cluster vuoti e canonicalizza insieme centri ed
etichette per prima apparizione. Overflow delle distanze o dell'obiettivo produce
failure tipizzata; i limiti di celle e lavoro sono controllati prima dei restart.

## K-medoids

K-medoids **PUÒ** supportare una metrica generica, ma l'artefatto deve identificare
l'algoritmo concreto, per esempio `PAM-v1`, inizializzazione e swap. Non è sinonimo
di k-means e non ne condivide necessariamente l'obiettivo.

## Validazione e limiti

Silhouette, stabilità bootstrap o altri indici sono artefatti separati con formula e
sampling versionati. Non stabiliscono da soli il “vero” numero di cluster. Una
visualizzazione non deve nascondere punti non assegnati, cluster vuoti o arresto per
limite.

### Silhouette euclidea

Per un punto `i` non singleton, `a(i)` è la media delle distanze euclidee dagli
altri membri del proprio cluster; `b(i)` è il minimo, sugli altri cluster,
della distanza media dai rispettivi membri. Il coefficiente è
`s(i)=(b(i)-a(i))/max(a(i),b(i))`; se entrambe le medie sono zero vale zero.
Un singleton ha coefficiente zero. La silhouette complessiva è la media
aritmetica dei coefficienti, nell'ordine dei punti in ingresso; richiede
almeno due punti e due cluster non vuoti.

Il raffinamento candidato GS-DOR-172 preindicizza i membri in spazio lineare,
conservando l'ordine originale dei membri e l'ordine crescente delle etichette
dei cluster, incluse etichette intere non consecutive. Non richiede una cache
quadratica delle distanze. Il percorso ordinario **DEVE** conservare la
sequenza delle distanze e delle somme della formula diretta.

Righe vuote o di dimensione differente, valori non finiti e superamenti dei
budget standard di celle/lavoro **DEVONO** produrre failure tipizzate, con
controlli di dimensione senza overflow. La cancellazione **DEVE** interrompere
anche indicizzazione e riduzioni. Quando un intermedio va in overflow o
underflow, il recupero numerico **DEVE** conservare le medie scalate fino al
rapporto finale; una distanza realmente non rappresentabile resta una failure
tipizzata. La verifica e le misure del raffinamento sono registrate in
[GS-VER-172](../evidenze/GS-VER-172-query-sparse-e-silhouette.md).

Il kernel candidato valida al massimo 5.000.000 celle e stima il lavoro come
`A×(n−1)×p`, dove `A` è il numero di punti in cluster non singleton e `p` il
numero di dimensioni, entro 500.000.000 unità di lavoro. La partizione composta
soltanto da singleton restituisce zeri dopo la validazione; non viene
addebitato un calcolo delle distanze che non avviene. Il chiamante del profilo
corpus converte in silhouette assente soltanto
`clustering.silhouette-undefined`; cancellazione e altre failure si propagano.

Il percorso ordinario senza controlli numerici per coordinata è ammesso
soltanto dopo una prova conservativa sull'input già validato:
`minULP(nonzero)≥2×sqrt(Double.leastNormalMagnitude)` e
`maxAbs≤sqrt(Double.max/(8p))`. Gli zeri non abbassano la prima stima. Questi
vincoli garantiscono quadrati non nulli normali e somma dei quadrati finita;
entro il limite di celle anche somme e medie delle distanze sono
rappresentabili. Negli altri casi resta il percorso con rilevazione degli
intermedi estremi. Soglie e valori adiacenti **DEVONO** essere verificati con fixture
dedicate, senza modificare la formula o le riduzioni.

## Verifica

Fixture includono singleton, duplicati, parità, cluster separati, scale differenti e
input degenere. Si verificano monotonia delle fusioni quando prevista, obiettivo non
crescente per Lloyd, riproducibilità del seed, equivalenza delle etichette dopo
canonicalizzazione e confronto con implementazione indipendente.

## Varianti native candidate

CLARA-PAM e SOM batch completano le famiglie di clustering della libreria secondo
[GS-MET-001-23](23-operatori-kh-coder.md). Restano candidate. Il Ward di varianza su dissimilarità
non euclidee continua a essere rifiutato; il profilo KH algebrico esplicito
segue il contratto distinto sopra indicato.

## Unità del clustering nel profilo corpus

Il profilo documentale `document-term-relative-frequency-v1` conserva la
normalizzazione di ciascun documento sulla propria esposizione dichiarata.
Il nuovo profilo delle parole `term-document-relative-frequency-v1` usa
invece un vettore per termine selezionato. Data la matrice dei conteggi
`N[d,t]`, la coordinata del termine `t` nel documento `d` è:

```text
x[t,d] = N[d,t] / Σ_e N[e,t]
```

Il denominatore è positivo e finito. Ogni profilo di termine ha somma uno:
una diversa frequenza totale della parola non diventa automaticamente una
distanza maggiore. Il profilo non equivale alla trasposizione delle frequenze
relative documentali e non introduce una distanza Jaccard/cosine implicita.
La geometria è euclidea; single, complete, average e Ward riusano `HAC-v1`
e i vincoli Ward già definiti sopra. Il profilo KH Ward.D2 algebrico rimane
un'operazione distinta su dissimilarità esplicite.

La selezione usa frequenza documentale decrescente, poi frequenza totale e
ordine lessicografico per risolvere le parità; il sottoinsieme selezionato
viene ordinato lessicograficamente prima del calcolo. Il descriptor registra
`clusterUnit=terms`, rappresentazione, linkage, numero di gruppi e limite di
termini. Le appartenenze e i figli dell'albero si riferiscono all'ordine dei
termini, mentre l'elenco delle revisioni sorgente resta l'ordine dei documenti.

Per ogni foglia termine, il risultato **DEVE** conservare i soli documenti con
conteggio positivo. Il lineage della foglia è contributivo; l'identità del
termine non **DEVE** essere usata come `SourceRevisionID`. Una fusione unisce
le fonti dei due rami senza duplicati. Il taglio della vista è distinto dal
taglio persistito nel risultato, come specificato in GS-VIZ-001.
[GS-VER-342](../evidenze/GS-VER-342-flussi-tematici-e-dendrogrammi.md).
