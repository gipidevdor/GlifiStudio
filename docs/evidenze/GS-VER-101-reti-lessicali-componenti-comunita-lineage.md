<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-101 — Reti lessicali con componenti, eigenvector, cammini pesati, comunità e lineage

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-101 |
| Tipo | Evidenza di verifica con oracolo esterno, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-008, TV-029, TV-032, TV-035, TV-054, TV-056 e TV-073 |

## Ambito

Supera i limiti di GS-VER-089, GS-VER-090, GS-VER-092 e GS-VER-094 su reti e co-occorrenze:

- `WeakComponents-v1` (union–find) e `StrongComponents-v1` (Tarjan iterativo);
- `EigenvectorCentrality-v1`: power iteration su `A + I` (lo shift conserva l'autovettore
  dominante ed evita l'oscillazione sui grafi bipartiti), autovalore dal quoziente di Rayleigh;
- `WeightedBetweenness-v1` (Brandes con Dijkstra) e `WeightedHarmonicCloseness-v1`, con
  distanza dichiarata `inverse-weight-distance-v1` (`1/peso`); cammini di pari lunghezza entro
  tolleranza relativa `1e-12` condividono il credito;
- `Louvain-v1` deterministico (ordine dichiarato dei nodi, mossa accettata solo per guadagno
  stretto) e modularità `Q = Σ_c [L_c/m − (d_c/2m)²]`;
- `corpus-window-collocation-v2`: pesatura per distanza dichiarata (`none` o `1/d`), distanza
  media per coppia e **lineage per cella**: le prime posizioni di ogni coppia come intervalli UTF-8
  del nodo e del collocato nella fonte, con indicatore di troncamento;
- `corpus-window-cooccurrence-network-v1` (nuova operazione `analyzeWindowNetwork`, CLI
  `window-network`): grafo non orientato per finestra simmetrica e orientato per finestra
  direzionale, **soglie** dichiarate (conteggio congiunto minimo, `logDice` minimo applicato dopo
  la misura), peso dell'arco dal conteggio grezzo o pesato, archi con posizioni sorgente;
- `corpus-document-cooccurrence-network-v2`: archi con **documenti di supporto** (lineage per
  arco), componenti, eigenvector, cammini pesati e comunità; misure condivise dalle due reti.

## Procedura e risultato

1. eigenvector contro `eigen()` di R 4.6.0 su un grafo pesato a quattro nodi (autovalore
   4,11753166928908 e vettore scalato) e sul cammino bipartito di cinque nodi (autovalore `√3`,
   vettore ½, √3/2, 1, √3/2, ½) entro `1e-10`;
2. betweenness pesata: con a–c di peso 0,25 il cammino minimo passa per b (valore 2, mentre in hop
   è 0); con peso 0,5 i due cammini sono pari e b riceve 1; closeness pesata di a `1 + ½`;
3. componenti: ciclo a→b→c→a con c→d e nodo isolato → due componenti deboli e tre forti;
4. Louvain su due triangoli uniti da un arco ritrova le due comunità con `Q = 5/14`; la
   partizione banale ha `Q = 0`;
5. il test ha rilevato un difetto nel Dijkstra (con distanza ancora infinita il confronto di
   parità risultava vero e la distanza non veniva mai aggiornata), corretto prima del commit;
6. collocazioni v2: su «alfa beta gamma» (±2, `1/d`) la coppia (alfa, gamma) ha distanza media 2,
   peso ½ e posizioni `0..<4`/`10..<15`; il limite di una posizione su due osservazioni produce
   troncamento esplicito;
7. rete a finestra: cammino di tre nodi con autovalore `√2`, autovettore `[1/√2, 1, 1/√2]`,
   betweenness pesata di beta 2; soglia `logDice ≥ 13,5` (entrambe le coppie hanno
   `14 + log2(2/3)`) rifiutata come rete vuota; finestra direzionale con una componente debole e
   tre forti;
8. GlifiKit: rete documentale con documenti di supporto per arco; rete a finestra persistita e
   riusata; `Scripts/verify.sh` verifica posizioni per ogni coppia e arco, documenti di supporto
   pari al conteggio congiunto, generazione finale 21 con 16 Artifact; gate completo.

## Limiti

Le posizioni per coppia sono limitate (al più 100) e la rete documentale resta limitata ai
termini più diffusi; per grafi molto grandi (streaming, CSR) il Dijkstra O(n²) e la matrice densa
di Louvain restano dimensionati per le reti bounded del progetto. Non esiste un oracolo esterno per
Louvain nell'ambiente (R senza `igraph`): la verifica usa partizioni note e la modularità calcolata
a mano.

## Esito

**Superato localmente per componenti, eigenvector, cammini pesati, comunità, soglie e lineage per
cella e per arco, persistiti con parità GlifiCore/Kit/CLI.**
