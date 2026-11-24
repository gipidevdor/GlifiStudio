<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Determinismo, riproducibilità e tolleranze

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-03 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Classi

| Codice | Classe | Obbligo |
| --- | --- | --- |
| D0 | Deterministico bitwise | stessi byte su ambiente numerico dichiarato |
| D1 | Deterministico entro tolleranza | stessi valori semantici entro tolleranze e invarianti |
| P1 | Pseudo-casuale riproducibile | stesso risultato con seed, PRNG, inizializzazione e ordine dichiarati |
| N1 | Proceduralmente non deterministico | variabilità dichiarata, misurata e mai presentata come D0/D1 |

Ogni algoritmo **DEVE** dichiarare una classe. D0 è preferito per conteggi interi,
selezioni, ordinamenti e trasformazioni esatte. Algebra lineare parallela e backend
accelerati sono normalmente D1. K-means, NMF e LDA sono P1 se seed e procedura sono
completamente fissati. I modelli generativi di sistema sono N1 salvo garanzia più
forte verificata.

## Politica numerica

Per scalari finiti `a` e `b`, il confronto D1 predefinito è:

```text
|a - b| ≤ atol + rtol × max(|a|, |b|)
```

`atol`, `rtol`, tipo numerico, gestione di `NaN`, infiniti, underflow e overflow
**DEVONO** essere dichiarati per famiglia di metodo; non esiste una tolleranza
universale. Vettori e matrici dichiarano inoltre norma, errore massimo e invarianti
come somma delle masse, ortogonalità o monotonia dell'obiettivo.

## Equivalenze strutturali

- Cluster con etichette permutate sono equivalenti soltanto dopo una
  canonicalizzazione dichiarata.
- Segno di autovettori o vettori singolari **DEVE** essere canonicalizzato oppure
  confrontato modulo segno.
- Fattori con valori singolari degeneri **DEVONO** essere confrontati come sottospazi,
  non elemento per elemento.
- Ordinamenti con valori uguali **DEVONO** usare un tie-breaker stabile basato su
  identità, mai sull'ordine accidentale di una hash table.

## Pseudo-casualità

Un descrittore P1 **DEVE** conservare seed, famiglia e versione del PRNG, strategia
di derivazione dei sottoseed, numero di inizializzazioni e criterio di scelta del
run. Un seed privo dell'identità del generatore non è sufficiente. Parallelismo e
chunking **NON DEVONO** consumare casualità in un ordine implicito; i flussi devono
essere derivati da identità stabili.

## Riduzioni concorrenti

Poiché l'addizione floating-point non è associativa, una riduzione D0/D1 **DEVE**
usare ordine stabile, somma compensata o albero deterministico secondo il contratto.
Il backend accelerato **DEVE** essere confrontato con una baseline di riferimento e
registrato nel descrittore. La maggiore velocità non autorizza tolleranze più ampie
senza revisione scientifica.

## Verifica

Ogni implementazione **DEVE** includere ripetizioni nello stesso processo, processi
separati, ordini di task diversi e backend applicabili. I test D0 confrontano byte o
valori esatti; D1 confronta tolleranze e invarianti; P1 ripete seed noti e almeno un
seed differente; N1 misura distribuzione o stabilità della procedura senza pretendere
uguaglianza dell'output.
