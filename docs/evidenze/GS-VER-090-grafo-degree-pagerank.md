<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-090 — Grafo diretto, Degree/PageRank/Betweenness/HarmonicCloseness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-090 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.1.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-032 e TV-035 |

## Ambito

- `GlifiDirectedGraph`: grafo diretto `G=(V,E)` con nodi tipizzati, archi
  pesati non negativi, self-loop e multi-archi ammessi, validato per identità
  dei nodi, riferimenti degli archi e pesi finiti non negativi;
- `GlifiNetworkAnalysis.degree`: `Degree-v1` e `WeightedDegree-v1` in/out per
  nodo, con self-loop che contribuiscono a entrambi;
- `GlifiNetworkAnalysis.pageRank`: `PageRank-v1` tramite power iteration con
  vettore di teleport uniforme, righe pendenti (`out-weight=0`) sostituite dal
  vettore di teleport secondo la formula dichiarata, damping/tolleranza/
  massimo iterazioni persistiti come parametri;
- `GlifiNetworkAnalysis.betweenness`: `Betweenness-v1` su distanza hop diretta
  non pesata tramite l'algoritmo di Brandes (BFS per sorgente più
  accumulazione della dipendenza in ordine inverso), quota dei cammini minimi
  ripartita proporzionalmente sui pareggi;
- `GlifiNetworkAnalysis.harmonicCloseness`: `HarmonicCloseness-v1` su distanza
  hop diretta non pesata, con contributo esplicitamente zero per i nodi
  irraggiungibili.

## Procedura

1. verificare Degree/WeightedDegree su un piccolo grafo con self-loop
   esplicito, confermando che il self-loop contribuisca sia a in- sia a
   out-degree/peso;
2. verificare PageRank su un ciclo diretto simmetrico a tre nodi: la
   distribuzione uniforme `1/3` è un punto fisso per invarianza di
   rotazione, indipendentemente dal damping o dal codice in prova;
3. verificare PageRank su un grafo privo di archi: tutti i nodi restano al
   vettore di teleport e la convergenza avviene in una sola iterazione, per
   costruzione della formula;
4. verificare PageRank su un grafo a due nodi con un nodo pendente
   risolvendo a mano il sistema lineare `π=(1-d)v+dPᵀπ` con `d=0,85` fino a
   un valore esatto in frazione (`π_a=20/57`, `π_b=37/57`), indipendente
   dall'implementazione della power iteration in prova;
5. verificare la conservazione della massa totale (`Σπ=1`) su un grafo
   asimmetrico con un nodo pendente, come proprietà indipendente dal valore
   specifico dei punteggi;
6. verificare failure tipizzate per nodo duplicato, riferimento a nodo
   ignoto, peso negativo o non finito, grafo vuoto e damping fuori `[0,1)`;
7. verificare Betweenness e HarmonicCloseness sulle due fixture canoniche
   richieste dalla specifica: un percorso diretto a quattro nodi (valori
   interi esatti `Betweenness(b)=Betweenness(c)=2`, estremi a zero;
   `HarmonicCloseness` per frazioni esatte `11/6, 3/2, 1, 0`) e una stella
   bidirezionale a tre foglie (`Betweenness(centro)=6`, foglie a zero;
   `HarmonicCloseness(centro)=3`, foglie a `2`);
8. verificare che un self-loop non introduca un cammino minimo verso se
   stessi e che un grafo vuoto restituisca punteggi vuoti senza errore.

## Risultato osservato

- Degree/WeightedDegree contano correttamente il self-loop su entrambe le
  direzioni;
- PageRank sul ciclo simmetrico converge a `1/3` per ogni nodo entro `1e-9`;
- PageRank senza archi converge in esattamente una iterazione al vettore di
  teleport uniforme;
- il caso a due nodi con nodo pendente coincide entro `1e-6` con la
  soluzione esatta del sistema lineare risolta indipendentemente (un primo
  tentativo di verifica aveva un errore aritmetico nella derivazione a mano,
  non nell'implementazione: corretto e ri-verificato prima di registrare
  questa evidenza);
- la massa totale resta `1` entro `1e-9` sul grafo asimmetrico con nodo
  pendente;
- input non validi sono rifiutati con `GlifiFailure` tipizzata senza
  produrre un risultato parziale;
- Betweenness e HarmonicCloseness coincidono esattamente (entro `1e-12`) con
  i valori attesi sul percorso e sulla stella; un self-loop non genera un
  cammino minimo verso se stessi e il grafo vuoto restituisce punteggi vuoti.

## Limiti

Questa evidenza copre soltanto grafo, Degree/WeightedDegree, PageRank,
Betweenness e HarmonicCloseness bounded in memoria su un grafo fornito
direttamente dal chiamante, con distanza hop non pesata (Betweenness e
HarmonicCloseness non usano i pesi degli archi). Non prova eigenvector
centrality, componenti connesse/deboli/forti, community detection, betweenness
pesata, costruzione del grafo da co-occorrenze testuali con lineage per arco,
persistenza in Artifact/DAG, wiring Kit/CLI, streaming/CSR su grafi grandi o
un dataset gold per la review scientifica esterna. Correspondence Analysis
(GS-MET-001-10) e clustering (GS-MET-001-14) restano fuori ambito perché
richiederebbero un'implementazione di SVD generale non ancora validabile in
modo indipendente in questo ambiente.

## Esito

**Superato localmente per grafo diretto, `Degree-v1`/`WeightedDegree-v1`,
`PageRank-v1`, `Betweenness-v1` e `HarmonicCloseness-v1` in GlifiCore.** Non
promuove RF-039 a feature complete né sostituisce la review scientifica
esterna.
