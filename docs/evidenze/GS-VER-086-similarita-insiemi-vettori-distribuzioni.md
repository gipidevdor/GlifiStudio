<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-086 — Similarità e distanze su insiemi, vettori e distribuzioni

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-086 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-008 e TV-032 |

## Ambito

- `GlifiSetSimilarity`: `JaccardSet-v1` e `DiceSet-v1` su insiemi finiti, con i
  casi limite dichiarati dalla specifica (entrambi vuoti → `1`, un solo vuoto
  → `0`);
- `GlifiVectorSimilarity`: `Cosine-v1`, `Euclidean-v1` e `Manhattan-v1` su
  vettori reali allineati, con `Cosine-v1` indefinito su un vettore nullo;
- `GlifiProbabilityDivergence`: `KL-v1`, `JSdiv-v1`, `JSdist-v1` e
  `Hellinger-v1` su distribuzioni normalizzate (`Σp=Σq=1`), con KL indefinita
  quando `q_i=0` dove `p_i>0`;
- ogni dominio dichiara la propria precondizione ed è validato prima del
  calcolo: nessuna misura opera silenziosamente fuori dal proprio dominio.

## Procedura

1. verificare Jaccard/Dice sui casi limite espliciti della specifica (insiemi
   entrambi vuoti, un solo insieme vuoto, insiemi identici) e su un caso di
   sovrapposizione parziale con valori calcolabili per frazione esatta;
2. verificare coseno su vettori ortogonali (`0`), identici (`1`) e paralleli
   scalati (`1` indipendentemente dalla norma); verificare Euclidea e
   Manhattan sul triangolo rettangolo 3-4-5 con valori interi esatti;
3. verificare simmetria e disuguaglianza triangolare su una tripla concreta di
   punti per la distanza euclidea;
4. verificare KL, Jensen-Shannon ed Hellinger sull'identità (`p=q` → `0`) e su
   masse puntuali disgiunte a due esiti, dove la forma chiusa è nota:
   `JSdiv=JSdist=Hellinger=1` (il bit/la distanza massima teorica per questo
   spazio a due esiti);
5. verificare che KL fra masse puntuali disgiunte sia esplicitamente
   indefinita (rifiutata) invece di produrre infinito o `NaN`;
6. verificare simmetria di Jensen-Shannon ed Hellinger sulla stessa coppia;
7. verificare failure tipizzate per vettore nullo, dimensioni disallineate,
   distribuzione non normalizzata e probabilità negative.

## Risultato osservato

- tutti i casi limite e i valori a forma chiusa coincidono entro `1e-9` (o
  `1e-12` per i casi a valore esatto) con il calcolo indipendente;
- KL fra masse puntuali disgiunte è rifiutata con `similarity.kl-undefined`
  invece di propagare un valore non finito;
- Jensen-Shannon ed Hellinger restano simmetrici entro `1e-12`;
- la disuguaglianza triangolare euclidea è soddisfatta sulla tripla concreta
  verificata;
- input fuori dominio (vettore nullo, dimensioni disallineate, distribuzione
  non normalizzata o con probabilità negative) sono rifiutati con
  `GlifiFailure` tipizzata senza calcolare un risultato parziale.

## Limiti

Questa evidenza copre soltanto il calcolo bounded in memoria su insiemi,
vettori e distribuzioni forniti direttamente dal chiamante. Non prova
smoothing/rinormalizzazione (trasformazioni dichiaratamente separate), varianti
multiset o pesate di Jaccard/Dice, persistenza in Artifact/DAG, esposizione via
GlifiKit/CLI, un dataset gold per la review scientifica esterna o test di
disuguaglianza triangolare generati in modo esaustivo oltre la tripla
verificata.

## Esito

**Superato localmente per `JaccardSet-v1`, `DiceSet-v1`, `Cosine-v1`,
`Euclidean-v1`, `Manhattan-v1`, `KL-v1`, `JSdiv-v1`, `JSdist-v1` e
`Hellinger-v1` in GlifiCore.** Non promuove RF-036 a feature complete né
sostituisce la review scientifica esterna.
