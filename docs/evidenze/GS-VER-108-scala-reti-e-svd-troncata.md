<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-108 — Scala: cammini con heap, Louvain sparso e SVD troncata per iterazione di sottospazio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-108 |
| Tipo | Evidenza di verifica con oracolo esterno e rifattorizzazione per la scala |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-032, TV-035, TV-054 e TV-073 |

## Ambito

Supera i limiti di scala di GS-VER-101 (Dijkstra O(n²), Louvain su matrice densa) e GS-VER-102
(SVD solo densa entro 250 000 celle):

- Dijkstra con heap binario su `(distanza, nodo)` (`O((V+E) log V)`), estrazione deterministica e
  stessa tolleranza di parità; Louvain e modularità su righe sparse ordinate con le stesse somme,
  quindi gli stessi risultati della versione densa;
- `SVD-SubspaceIteration-v1`: SVD troncata dei `k` valori maggiori per iterazione a blocchi
  `Q ← orth(Aᵀ(AQ))` con blocco iniziale da `SplitMix64-v1` e seed registrato, sovracampionamento
  15, convergenza dei valori di Ritz (radici degli autovalori della Gram `(AQ)ᵀ(AQ)`) e
  Rayleigh–Ritz con Jacobi; operatore CSR su buffer piatti; colonne degeneri sostituite in modo
  deterministico per operatori di rango basso; fino a 5 000 000 di celle;
- `LSA-SVD-v1` sceglie Jacobi entro il limite denso e la SVD troncata oltre, dichiarando il backend
  (`backendIdentifier`) e calcolando il residuo come `√(‖A‖²_F − Σσ²ₖ)`; il limite di termini
  dell'analisi multivariata sale a 2 000 (i metodi densi restano protetti dal limite di Jacobi);
- Jacobi ignora le coppie di colonne numericamente nulle (norma² sotto `1e-28` di `‖A‖²_F`), che
  prima impedivano la convergenza senza cambiare la decomposizione.

## Procedura e risultato

1. grafo casuale igraph `sample_gnm(150, 600)` con pesi (seed 42), letto dai dati di massa di
   `expected.txt`: betweenness pesata (doppia di quella non orientata), closeness armonica e
   componenti coincidono con igraph; la modularità di Louvain non è inferiore di oltre 0,02 a
   `cluster_louvain`; con heap e righe sparse il test passa da 1,45 s a 0,24 s (build di debug)
   senza variazioni di risultato;
2. SVD troncata su una matrice R 150×200 al 5 % (seed 7): primi cinque valori singolari entro
   `1e-10` relativo da `svd()`, primo vettore destro entro `1e-9`, residuo `‖Av − σu‖` sotto `1e-8σ`,
   riproducibilità dal seed; coincidenza con Jacobi sulla matrice 5×4 di riferimento;
3. LSA su 510×500 (255 000 celle) a blocchi diagonali: backend troncato, valori singolari
   `valore·√(righe·colonne)` in forma chiusa entro `1e-9` e residuo pari al terzo valore;
4. suite GlifiCore di 192 test e gate completo `make verify`.

## Limiti

Nella build di debug i cicli numerici costano circa 100 volte più che in release: il test di
correttezza usa matrici moderate, mentre il comportamento su matrici di milioni di celle non ha
ancora un benchmark dedicato in `Benchmarks/`. CA e PCA restano dense.

## Esito

**Superato localmente: cammini, comunità e SVD troncata scalano oltre i limiti precedenti con gli
stessi risultati, verificati contro igraph e R.**
