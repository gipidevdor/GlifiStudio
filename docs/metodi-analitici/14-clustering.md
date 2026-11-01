<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Clustering

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-14 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Contratto comune

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

## K-means

`KMeans-Lloyd-v1` minimizza `Σ_i ||x_i-μ_{c_i}||₂²` per `1≤k≤n`, usando iterazioni
di assegnazione al centroide più vicino e ricalcolo dei centroidi. Il descrittore
specifica standardizzazione, `k`, inizializzazione (`k-means++` candidata), PRNG,
seed, restart, massimo iterazioni, tolleranza relativa dell'obiettivo e politica dei
cluster vuoti. `k-means++-v1`, se scelto, estrae il primo centro uniformemente tra
le unità e i successivi con probabilità proporzionale alla distanza euclidea
quadratica dal centro già scelto più vicino. Il run scelto minimizza l'obiettivo,
con tie-break deterministico. È P1 e non accetta distanze arbitrarie.

## K-medoids

K-medoids **PUÒ** supportare una metrica generica, ma l'artefatto deve identificare
l'algoritmo concreto, per esempio `PAM-v1`, inizializzazione e swap. Non è sinonimo
di k-means e non ne condivide necessariamente l'obiettivo.

## Validazione e limiti

Silhouette, stabilità bootstrap o altri indici sono artefatti separati con formula e
sampling versionati. Non stabiliscono da soli il “vero” numero di cluster. Una
visualizzazione non deve nascondere punti non assegnati, cluster vuoti o arresto per
limite.

## Verifica

Fixture includono singleton, duplicati, parità, cluster separati, scale differenti e
input degenere. Si verificano monotonia delle fusioni quando prevista, obiettivo non
crescente per Lloyd, riproducibilità del seed, equivalenza delle etichette dopo
canonicalizzazione e confronto con implementazione indipendente.

## Varianti native candidate

CLARA-PAM e SOM batch completano le famiglie di clustering della libreria secondo
[GS-MET-001-23](23-operatori-kh-coder.md). Restano candidate; Ward su dissimilarità
non euclidee continua a essere rifiutato.
