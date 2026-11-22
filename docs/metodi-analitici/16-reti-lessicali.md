<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Reti lessicali e di co-occorrenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-16 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.2 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-22 |
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

Il backend CPU di `HarmonicCloseness-v1` risolve le identità una sola volta e
conserva i vicini deduplicati in righe CSR. I self-loop sono esclusi, gli
archi paralleli contano una sola connessione e l'ordine dei vicini resta
quello della prima apparizione negli archi. I valori dei pesi non intervengono
nella distanza hop: anche un arco di peso zero resta una connessione.

Ogni BFS riusa coda e distanze intere, ripristinando soltanto le celle visitate;
una sorgente priva di vicini diversi da sé ha punteggio zero. La riduzione
`Σ 1/d` **DEVE** seguire l'ordine dichiarato dei nodi, non l'ordine di visita
BFS, per preservare la sequenza aritmetica. Non viene conservata una matrice
quadratica delle distanze. La complessità peggiore resta `O(V(V+E))` e la
memoria di lavoro `O(V+E)`; non sono introdotte approssimazioni o nuove API.

Le prove di GS-VER-173 confrontano tutti i bit dei punteggi con la precedente
visita generica e le distanze con Floyd–Warshall indipendente su tutti i 4096
digrafi semplici di quattro nodi. Fixture aggiuntive coprono ordine dei nodi
diverso dalla BFS, identità in collisione hash, zeri, archi paralleli,
self-loop, sink e componenti separate. Le misure dei tre generatori sintetici
sono registrate nell'evidenza, senza cambiare lo stato scientifico del metodo.

## Verifica

### Precisione di Betweenness-v1

Il forward di Brandes conserva le addizioni binary64 e l'ordine precedente.
Se una BFS produce un contatore di cammini non finito, soltanto quella BFS
ricostruisce i conteggi dall'ordine di visita e dai predecessori già raccolti.
Il fallback conserva una mantissa binary64 di 53 bit con esponente intero
esteso: non è un contatore BigInt e non promette arrotondamento esatto per
ogni grafo. Il DAG dei cammini minimi limita l'esponente al numero di nodi.

Nel fallback il rapporto delle mantisse viene moltiplicato per `1+δ` prima di
materializzare l'esponente; il prodotto è normalizzato prima della conversione
finale a Double. Una quota non rappresentabile separatamente può così produrre
un contributo subnormale rappresentabile. Sorgenti, predecessori, dipendenze e
punteggi conservano l'ordine; il percorso senza overflow resta invariato.
API, identità del metodo, archi paralleli deduplicati, self-loop esclusi e
connessioni di peso zero non cambiano. GS-VER-174 registra regressioni, oracoli
indipendenti e costi del fallback, senza promozione scientifica.

Il percorso CPU può riusare la CSR e buffer indicizzati per visita, contatori,
dipendenze e punteggi. I predecessori occupano blocchi contigui di capacità pari
al grado entrante: l'append **DEVE** conservare l'ordine originale della BFS,
senza riordinare le riduzioni. Dopo ogni sorgente si azzerano i soli nodi
visitati; gli slot dei predecessori oltre la lunghezza corrente non si leggono.
Lo scratch resta O(V+E), con contatori estesi allocati soltanto se necessari.
GS-VER-177 registra confronti bitwise, reset fra componenti e misure Release.

Fixture canoniche comprendono grafo vuoto, singleton, percorso, ciclo, stella,
componenti disconnesse e grafo diretto con dangling node. Si verificano invariance
alla rinomina, somme/normalizzazioni, risultati noti, tie-break e lineage degli archi.

## Primitive native aggiuntive in memoria

[GS-MET-001-23](23-operatori-kh-coder.md) e
[ADR-0035](../adr/0035-completamento-nativo-kh-coder.md) fissano le nuove
varianti candidate Girvan–Newman a costo inverso dell’intensità, CNM pesata e
Walktrap con self-loop medio e fusioni Ward. Conservano proiezione dichiarata,
risoluzione, tie deterministici, modularità del grafo originale e gerarchia.
La rimozione per edge betweenness è distinta dalla centralità dei nodi esistente.

Fruchterman–Reingold e Kamada–Kawai producono coordinate adimensionali separate
dai grafi; KK dichiara esplicitamente le distanze virtuali fra componenti e la
storia energetica. La foresta Prim interpreta i pesi come costi, conserva costi
nulli e componenti; i pesi non vengono reinterpretati implicitamente come
intensità. Queste API non cambiano la disposizione della UI applicativa.

Budget prima dei buffer quadratici e del lavoro iterativo: 2.000 nodi,
100.000 archi, 1.000.000 celle pairwise e 200.000.000 unità stimate standard,
con limiti effettivi più restrittivi secondo metodo e numero di buffer.
La copertura Core/Kit/CLI è in verifica in
[GS-VER-233](../evidenze/GS-VER-233-completamento-kh-coder.md); questi metodi
non ereditano lo stato scientifico di Louvain o delle centralità precedenti.
