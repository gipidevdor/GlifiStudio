<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Analysis DAG e invalidazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-02 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Modello

La pipeline documentale lineare `S0→S1→S2→S3→S4→S5→S6` resta il modello delle
trasformazioni della fonte. Le analisi successive formano un grafo aciclico diretto
`G = (V, E)`, nel quale un arco `u→v` significa che il valore semantico di `v`
dipende da `u`.

Ogni nodo **DEVE** avere identità, tipo, versione logica, descrittore, stato e
dipendenze ordinate canonicamente. I tipi minimi sono fonte/versione di corpus,
selezione, preprocessing, rappresentazione, trasformazione, statistica, modello e
artefatto di presentazione persistito.

```text
versione corpus → selezione → matrice unità-termine ─┬→ TF-IDF → LSA
                                                     ├→ keyness
                                                     └→ clustering
token/contesti → matrice co-occorrenza ─┬→ associazioni
                                        └→ rete lessicale
tabella contingenza ─┬→ test/effect size
                     └→ Correspondence Analysis
```

## Validità e invalidazione

Un nodo è valido se e soltanto se:

1. il proprio descrittore è valido;
2. tutte le dipendenze esistono e sono valide;
3. i digest delle dipendenze coincidono con quelli registrati;
4. l'implementazione riconosce algoritmo e versione logica;
5. l'artefatto supera i controlli d'integrità del proprio formato.

La modifica di un nodo **DEVE** invalidare transitivamente soltanto i discendenti che
dipendono dal significato modificato. Un cambio di titolo UI non invalida un
conteggio; un cambio di tokenizzazione invalida vocabolario, matrici e discendenti.
La cancellazione di una cache **NON DEVE** eliminare fonti o configurazioni
autorevoli.

## Riutilizzo e pianificazione

Il pianificatore **DEVE**:

- rilevare cicli prima dell'esecuzione;
- riutilizzare nodi validi con identità semantica coincidente;
- eseguire soltanto il sottografo necessario al risultato richiesto;
- propagare cancellazione, errori e backpressure;
- registrare il backend realmente usato e ogni fallback;
- produrre checkpoint atomici per operazioni lunghe quando il metodo lo consente.

Lo scheduling concorrente **NON DEVE** cambiare l'identità o la semantica del
risultato. Le riduzioni dipendenti dall'ordine applicano la politica di
[determinismo](03-determinismo-e-tolleranze.md).

## Scalabilità

Un nodo **DEVE** dichiarare se è streaming, a blocchi, sparso, iterativo o richiede
materializzazione. Le rappresentazioni intermedie **DEVONO** poter essere persistite
e lette selettivamente. Se un algoritmo matematicamente richiede memoria
proporzionale all'intero input, l'implementazione **DEVE** imporre limiti preventivi
e offrire un'alternativa o un errore comprensibile; non deve affidarsi a un crash per
esaurimento memoria.

## Criteri di verifica

- rifiuto di grafi ciclici e riferimenti mancanti;
- invalidazione transitiva esatta su grafi sintetici ramificati;
- riuso osservabile dei nodi non coinvolti;
- equivalenza tra esecuzione completa e ripresa da checkpoint;
- stesso artefatto semantico con ordini di scheduling differenti entro la politica
  numerica dichiarata.

## Profilo implementato `analysis-dag-v1`

La prima struttura GlifiCore accetta candidati bounded, deduplica identità
semanticamente equivalenti, convalida dipendenze e schema, rifiuta riferimenti
mancanti, collisioni, cicli e superamento dei limiti, quindi produce un ordine
topologico deterministico con tie-break su `AnalysisNodeID`.

Il grafo immutabile calcola il sottografo minimo di un risultato, l'insieme esatto
formato da nodi cambiati e discendenti e il riuso selettivo. Un Artifact è
riusabile soltanto se stato, digest del descriptor, schema, digest e catena di
dipendenze coincidono. Graph, node, descriptor e riferimenti Artifact hanno
round-trip validato; indici derivati non sono serializzati e vengono ricostruiti.

I limiti predefiniti sono 10.000 nodi e 50.000 archi. Persistenza transazionale,
checkpoint, scheduling/esecuzione e invalidazione committata nel package restano
fuori da questa slice logica.
