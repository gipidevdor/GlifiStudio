<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-102 — SVD, Correspondence Analysis, PCA, LSA, NMF e clustering verificati contro R

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-102 |
| Tipo | Evidenza di verifica con oracolo esterno, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-032, TV-054, TV-056 e TV-073 |

## Ambito

GS-VER-090 e GS-VER-092 escludevano CA, PCA, LSA, NMF e clustering per mancanza di un oracolo
indipendente di validazione della SVD. Con R 4.6.0 disponibile nell'ambiente, questa evidenza li
implementa e verifica:

- `SVD-Jacobi-v1` (`GlifiLinearAlgebra`): SVD sottile a un lato di Hestenes con rotazioni piane
  fino a ortogonalità relativa `1e-15`, trasposizione per matrici larghe, segni canonici sul primo
  loading non nullo positivo (GS-MET-001-10), rango numerico `max(m,n)·ε·σ₁`, limite di celle
  dichiarato;
- `CA-SVD-v1` (GS-MET-001-10): esclusione di righe e colonne a massa nulla, masse, valori
  singolari, inerzie, coordinate principali, contributi e cos² di righe e colonne;
- `PCA-SVD-v1` (GS-MET-001-15): centratura, scaling opzionale con esclusione dichiarata delle
  colonne costanti, varianza `σ²/(m−1)` e quote, loadings e scores;
- `LSA-SVD-v1`: troncamento al rango richiesto (limitato al rango numerico), residuo di Frobenius;
- `NMF-Frobenius-v1`: aggiornamenti moltiplicativi di Lee–Seung, inizializzazione con
  `SplitMix64-v1` e seed, restart, storia dell'obiettivo;
- `HAC-v1` (GS-MET-001-14): single, complete, average e `Ward-v1` (`Δ` e altezza `√(2Δ)`), taglio
  a `k` come operazione separata; `KMeans-Lloyd-v1` con `k-means++-v1`, seed e restart; cluster
  vuoti rifiutati;
- operazione persistita `analyzeMultivariate` (`corpus-document-term-multivariate-v1`) sulla
  matrice documento×termine del profilo corpus, con metodo, rappresentazione
  (`document-term-raw-count-v1`, `document-term-relative-frequency-v1`, `tfidf-raw-log-v1`),
  selezione dei termini e parametri dichiarati; risultato GlifiKit indipendente dal metodo e
  comando CLI `multivariate --method ca|pca|pca-scaled|lsa|nmf|hac|kmeans`.

## Procedura e risultato

Matrice di riferimento 5×4 di conteggi; oracolo R (`svd`, `prcomp`, `chisq.test`, `hclust`,
`kmeans(algorithm = "Lloyd")`):

1. SVD: valori singolari entro `1e-10`, ricostruzione `UΣVᵀ` e ortonormalità di V entro `1e-12`,
   stessi valori sulla trasposta;
2. CA: valori singolari e coordinate principali delle prime due dimensioni di riga e della prima
   di colonna entro `1e-10`; inerzia totale = `χ²/n` = 0,587755102040816; contributi per asse e cos²
   per riga sommano a 1; riga a massa nulla esclusa e registrata;
3. PCA: varianze, loadings e scores della prima componente come `prcomp`; invarianza alla
   traslazione; varianze scalate entro `1e-10`;
4. LSA: rango 2 con residuo 3,26370989141564;
5. HAC: altezze e sequenze di fusione identiche a `hclust` per single, complete, average e
   `ward.D2` (altezza `√(2Δ)`), taglio a due cluster, altezze di Ward monotone;
6. Lloyd dagli stessi centri iniziali: assegnazioni, obiettivo 0,32729828042328, centri e numero
   di passi come `kmeans` (convenzione di R: il passo finale senza cambiamenti è contato); k-means++
   riproducibile dal seed;
7. NMF su una matrice di rango non negativo esatto 2: fattori non negativi, obiettivo non crescente
   a ogni iterazione, ricostruzione con obiettivo < `1e-6`, riproducibilità dal seed;
8. end-to-end: un corpus testuale costruito per riprodurre la stessa matrice dà, tramite
   l'operazione persistita, gli stessi valori singolari CA e le stesse altezze di Ward di R;
9. due difetti trovati dai test e corretti prima del commit: confronto con valore iniziale infinito
   nella ricerca della fusione (NaN) e convenzione di conteggio delle iterazioni di Lloyd;
10. GlifiKit (CA, k-means persistito e riusato, linkage non dichiarato rifiutato);
    `Scripts/verify.sh` con CA e HAC average sul progetto del contract test (generazione finale 23
    con 18 Artifact); gate completo.

## Limiti

La SVD è densa e limitata a 250 000 celle; SVD sparse o randomizzate non sono implementate. NMF non
ha un oracolo esterno nell'ambiente (R senza pacchetti NMF): la verifica usa proprietà
(non negatività, monotonia, ricostruzione esatta). LDA, MDS, t-SNE, UMAP, K-medoids e indici di
validazione dei cluster (silhouette, stabilità) restano fuori ambito.

## Esito

**Superato localmente, con oracolo R, per SVD, CA, PCA, LSA, HAC e k-means, e con verifica di
proprietà per NMF, persistiti con parità GlifiCore/Kit/CLI.**
