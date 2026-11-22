<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Reti lessicali e di co-occorrenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-16 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.1 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Modello del grafo

Una rete è `G=(V,E)` con identità stabile del grafo, nodi tipizzati, archi tipizzati
e, quando presenti, peso `w:E→ℝ`, direzione e segno. Il descrittore conserva matrice
o eventi di origine, contesto di co-occorrenza, misura di associazione, soglia,
pruning, self-loop, multiarco e aggregazione.

Ogni nodo e arco visualizzato **DEVE** poter risolvere i termini, le unità e le
osservazioni testuali che lo hanno generato. Una soglia non elimina il lineage
dell'artefatto precedente.

## Primitive

- `Degree-v1`: numero di vicini o archi incidenti, distinguendo in/out nei grafi
  diretti e dichiarando il trattamento dei self-loop.
- `WeightedDegree-v1`: somma dei pesi incidenti; pesi negativi richiedono semantica
  separata e non sono ammessi per algoritmi che presuppongono non negatività.
- componenti connesse per grafi non diretti e componenti deboli/forti per diretti.
- `Betweenness-v1`: somma, sulle coppie ammissibili, della quota di cammini minimi
  che attraversano il nodo; normalizzazione e politica per cammini multipli sono
  esplicite.
- `HarmonicCloseness-v1`: `Σ_{u≠v} 1/d(v,u)`, con contributo zero per nodi
  irraggiungibili; eventuale normalizzazione è distinta.
- eigenvector centrality soltanto su matrici compatibili non negative, dichiarando
  orientamento e normalizzazione.
- `PageRank-v1`: trova la distribuzione `π` con somma uno tale che
  `π=(1-d)v+dPᵀπ`, `0≤d<1`; le righe dangling di `P` sono sostituite da `v`.
  Damping, vettore di teleport, norma di convergenza, tolleranza e massimo iterazioni
  sono parametri persistiti.

Community detection **PUÒ** essere introdotta soltanto con algoritmo, versione,
funzione obiettivo, risoluzione, seed e criterio di arresto. Il nome “community” non
identifica un metodo.

## Scalabilità

Il grafo logico è indipendente da liste di adiacenza, CSR o backend Metal. Primitive
esatte devono supportare componenti e degree in streaming/blocchi quando possibile.
Approssimazioni di centralità dichiarano sampling, bound ed errore. Layout grafico e
community sono nodi distinti dal grafo e dalle sue misure.

Il backend CPU di `PageRank-v1` risolve le identità generiche in indici una sola
volta e conserva le adiacenze in righe sparse contigue (CSR). L'ordine degli
indici coincide con quello dichiarato dei nodi; dentro ogni riga resta l'ordine
originario degli archi, inclusi multiarchi, self-loop e pesi nulli. Non viene
introdotto un ordinamento implicito delle identità.

L'iterazione riusa due buffer contigui di punteggi. Riscalamento dei pesi per riga,
contributi degli archi, massa dangling e riduzione della norma L1 conservano
sequenza e operazioni aritmetiche della variante precedente; formula,
teleportazione, criteri di arresto e diagnostica non cambiano. Le prove
di GS-VER-169 confrontano input e output tramite checksum canonici, oltre a
grafi con identità in collisione hash, archi ripetuti, self-loop, pesi estremi,
dangling node e cancellazione. Le misure di prestazione sono evidenze del
backend e non una nuova variante scientifica.

## Verifica

Fixture canoniche comprendono grafo vuoto, singleton, percorso, ciclo, stella,
componenti disconnesse e grafo diretto con dangling node. Si verificano invariance
alla rinomina, somme/normalizzazioni, risultati noti, tie-break e lineage degli archi.
